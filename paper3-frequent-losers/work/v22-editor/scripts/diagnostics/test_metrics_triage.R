#!/usr/bin/env Rscript
# Toy tests for metrics_triage.R -- deterministic, dependency-free.
# Run: Rscript scripts/diagnostics/test_metrics_triage.R
# Exits non-zero on any failure (so `make diagnostics` catches regressions).

here <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else getwd()
}
SRC <- normalizePath(file.path(here(), "..", "utils", "metrics_triage.R"))
source(SRC)

fails <- 0L
ok <- function(cond, msg) {
  status <- if (isTRUE(cond)) "PASS" else { fails <<- fails + 1L; "FAIL" }
  cat(sprintf("[%s] %s\n", status, msg))
}
near <- function(a, b, tol = 1e-9) is.finite(a) && is.finite(b) && abs(a - b) <= tol

# --- known example -----------------------------------------------------------
# 6 firms; higher score = higher risk. Positives at scores 0.9, 0.6, 0.4.
lab <- c(1, 0, 1, 0, 1, 0)
sc  <- c(0.9, 0.8, 0.6, 0.5, 0.4, 0.1)
# ranking by score desc: 0.9(+),0.8(-),0.6(+),0.5(-),0.4(+),0.1(-)

# precision@k / recall@k at k=2 -> top2 = {0.9+, 0.8-} -> 1 TP
ok(near(precision_at_k(lab, sc, 2), 1/2), "precision@2 == 0.5")
ok(near(recall_at_k(lab, sc, 2), 1/3),    "recall@2 == 1/3 (1 of 3 positives)")
# k=4 -> top4 = {+,-,+,-} -> 2 TP
ok(near(precision_at_k(lab, sc, 4), 2/4), "precision@4 == 0.5")
ok(near(recall_at_k(lab, sc, 4), 2/3),    "recall@4 == 2/3")
ok(false_positives_at_k(lab, sc, 4) == 2, "fp@4 == 2")
ok(false_negatives_at_k(lab, sc, 4) == 1, "fn@4 == 1")
ok(near(lift_at_k(lab, sc, 2), (1/2)/(3/6)), "lift@2 == 1.0 (precision/baserate)")
ok(near(cost_per_true_positive(lab, sc, 4, 1), 4/2), "cost_per_tp@4 == 2")

# AUC: count concordant positive>negative pairs / (n1*n0)=9.
# pairs where pos score > neg score: 0.9>{0.8,0.5,0.1}=3; 0.6>{0.5,0.1}=2; 0.4>{0.1}=1 => 6/9
ok(near(roc_auc(lab, sc), 6/9), "roc_auc == 6/9")

# Average precision: precisions at the 3 positive ranks are 1/1, 2/3, 3/5;
# AP = mean over positives of precision-at-that-positive (delta-recall = 1/3 each)
ap_expected <- (1/1 + 2/3 + 3/5) / 3
ok(near(average_precision(lab, sc), ap_expected), "average_precision == (1 + 2/3 + 3/5)/3")

# --- deterministic tie handling ---------------------------------------------
# All-tied scores: ranking falls back to original order -> top2 = rows 1,2.
lab_t <- c(1, 0, 0, 1)
sc_t  <- c(5, 5, 5, 5)
ok(precision_at_k(lab_t, sc_t, 2) == 1/2, "tie: precision@2 deterministic (orig order)")
ok(roc_auc(lab_t, sc_t) == 0.5, "tie: all-equal scores -> AUC 0.5 (midranks)")
r1 <- precision_at_k(lab_t, sc_t, 2); r2 <- precision_at_k(lab_t, sc_t, 2)
ok(identical(r1, r2), "tie: repeated call identical (deterministic)")

# --- higher_is_risk flip -----------------------------------------------------
ok(near(roc_auc(lab, sc, higher_is_risk = FALSE), 3/9), "flip: AUC complements to 3/9")

# --- bootstrap returns expected columns & is seed-reproducible ---------------
bc <- bootstrap_metric_ci(lab, sc, roc_auc, B = 200L, seed = 123L)
ok(all(c("estimate","ci_lo","ci_hi","B","seed","n_valid") %in% names(bc)),
   "bootstrap: has expected columns")
ok(near(bc$estimate, 6/9), "bootstrap: point estimate matches roc_auc")
bc2 <- bootstrap_metric_ci(lab, sc, roc_auc, B = 200L, seed = 123L)
ok(identical(bc$ci_lo, bc2$ci_lo) && identical(bc$ci_hi, bc2$ci_hi),
   "bootstrap: same seed -> identical CI")

# --- missing labels produce informative error -------------------------------
err <- tryCatch({ roc_auc(c(1, NA, 0), c(0.3, 0.2, 0.1)); "no_error" },
                error = function(e) conditionMessage(e))
ok(grepl("missing label", err, ignore.case = TRUE), "missing label -> informative error")

# --- split generators sanity -------------------------------------------------
sp <- leave_one_case_out_splits(c("A","A","B","C","C"))
ok(length(sp) == 3L, "LOCO: one fold per case")
ok(all(sp[[1]]$test == c(1,2)), "LOCO: case A test rows correct")
ro <- rolling_origin_splits(c(2010,2011,2012,2013))
ok(length(ro) == 3L && ro[[1]]$origin == 2010, "rolling-origin: 3 expanding folds")
gv <- grouped_cv_splits(rep(letters[1:10], each = 2), k = 5L, seed = 1L)
ok(length(gv) == 5L, "grouped CV: 5 folds")

cat(sprintf("\n==== metrics_triage tests: %d failure(s) ====\n", fails))
if (fails > 0L) quit(status = 1L)
cat("ALL TESTS PASSED.\n")
