#!/usr/bin/env Rscript
# ============================================================================
# an014_leakage_audit.R  —  AN-014 leakage audit (drop chain)
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Purpose: replicate the leakage drop chain reported in the paper for
# BEC AN-014:
#   raw item-level AUC: 0.995
#   → CV out-of-fold at firm level: 0.891
#   → temporal holdout: 0.864
#
# Federal panel: report the same 3 numbers (or as close as we can get
# given that bid-level item rank info is not in the participants CSV).
#
# Three measures:
#   M1 IN-SAMPLE firm-level AUC = AN-004 figure (one number per panel).
#   M2 CV OUT-OF-FOLD at firm-level: 5-fold random partition of pool;
#      for each fold, hold out 20% and compute AUC on hold-out using
#      the SAME classifier (FL binary OR log_tc continuous) computed
#      on the full pool. Mean ± SD across folds.
#   M3 TEMPORAL HOLDOUT = AN-006 figure (train 2013-2016, test = all-
#      period cobidders).
#
# Output: work/v20-comprasnet/output/an014_{bec,comprasnet}/an014_results.{json,csv}
# ============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(duckdb); library(DBI)
})

args   <- commandArgs(trailingOnly = TRUE)
source <- if (length(args) > 0 && args[1] %in% c("bec","comprasnet")) {
  args[1]
} else {
  stop("usage: an014_leakage_audit.R {bec|comprasnet}")
}

script_path <- (function() {
  cargs <- commandArgs(trailingOnly = FALSE)
  hit <- grep("--file=", cargs, value = TRUE)
  if (length(hit) > 0L) sub("--file=", "", hit[1]) else NA_character_
})()
ROOT <- if (!is.na(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", "..", ".."), mustWork = FALSE)
} else {
  getwd()
}
if (!file.exists(file.path(ROOT, "scripts", "00_master.R"))) ROOT <- getwd()
setwd(ROOT)

cat(sprintf("[AN-014] source=%s\n", source))

auc_with_ci <- function(labels, scores) {
  if (length(unique(labels)) < 2L) return(list(auc = NA_real_, ci = c(NA, NA, NA)))
  if (sum(labels) < 3L)             return(list(auc = NA_real_, ci = c(NA, NA, NA)))
  r <- pROC::roc(labels, scores, quiet = TRUE)
  list(auc = as.numeric(pROC::auc(r)),
       ci  = as.numeric(pROC::ci(r)))
}

# ---- Load data common to both --------------------------------------------
if (source == "bec") {
  fp_path  <- file.path(ROOT, "data/processed/FREQ_PARTICIP_rebuilt.parquet")
  cobid_csv <- file.path(ROOT, "data/processed/cade_fl_cobidders.csv")
  thresh   <- 14L
  fp <- as.data.table(read_parquet(fp_path))
  fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
  al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
  cobid <- fread(cobid_csv)
  cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
  cobid_codes <- unique(cobid$firm_code)
} else {
  fp_path  <- file.path(ROOT, "data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet")
  cobid_parq <- file.path(ROOT, "data/processed_comprasnet/cade_link_v1/cobidders_federal.parquet")
  thresh   <- 32L
  fp <- as.data.table(read_parquet(fp_path))
  suppressWarnings(fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))])
  al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
  cobid <- as.data.table(read_parquet(cobid_parq))
  suppressWarnings(cobid[, firm_code := sprintf("%014.0f", as.numeric(firm_id))])
  cobid_codes <- unique(cobid$firm_code)
}

al[, fl_binary   := as.integer(tenders_count >= thresh)]
al[, log_tc      := log1p(tenders_count)]
al[, is_cobidder := as.integer(firm_code %in% cobid_codes)]

cat(sprintf("\n  panel-wide pool: %s firms; positives: %d\n",
            format(nrow(al), big.mark = ","), sum(al$is_cobidder)))

# ============================================================================
# M1 — In-sample AUC (=AN-004 number)
# ============================================================================
cat("\n  M1: in-sample firm-level AUC\n")
m1_b <- auc_with_ci(al$is_cobidder, al$fl_binary)
m1_c <- auc_with_ci(al$is_cobidder, al$log_tc)
cat(sprintf("    AUC FL%d binary  = %.4f [%.4f, %.4f]\n",
            thresh, m1_b$auc, m1_b$ci[1], m1_b$ci[3]))
cat(sprintf("    AUC log_tc cont = %.4f [%.4f, %.4f]\n",
            m1_c$auc, m1_c$ci[1], m1_c$ci[3]))

# ============================================================================
# M2 — 5-fold CV out-of-fold at firm level
# ============================================================================
cat("\n  M2: 5-fold CV out-of-fold (random firm-level partition)\n")
set.seed(42L)
al[, fold := sample(rep(1:5, length.out = nrow(al)))]
cv_auc_b <- numeric(5L); cv_auc_c <- numeric(5L)
for (k in 1:5) {
  hold <- al[fold == k]
  if (sum(hold$is_cobidder) < 3L) {
    cv_auc_b[k] <- NA; cv_auc_c[k] <- NA; next
  }
  cv_auc_b[k] <- auc_with_ci(hold$is_cobidder, hold$fl_binary)$auc
  cv_auc_c[k] <- auc_with_ci(hold$is_cobidder, hold$log_tc)$auc
}
m2_b_mean <- mean(cv_auc_b, na.rm = TRUE)
m2_c_mean <- mean(cv_auc_c, na.rm = TRUE)
m2_b_sd   <- sd(cv_auc_b, na.rm = TRUE)
m2_c_sd   <- sd(cv_auc_c, na.rm = TRUE)
cat(sprintf("    AUC FL%d binary  = %.4f (SD %.4f) across folds [", thresh, m2_b_mean, m2_b_sd))
cat(paste(sprintf("%.3f", cv_auc_b), collapse = ", ")); cat("]\n")
cat(sprintf("    AUC log_tc cont = %.4f (SD %.4f) across folds [", m2_c_mean, m2_c_sd))
cat(paste(sprintf("%.3f", cv_auc_c), collapse = ", ")); cat("]\n")

# ============================================================================
# M3 — Temporal holdout (federal only — requires year-stamped panel)
# ============================================================================
m3_b <- list(auc = NA_real_, ci = c(NA, NA, NA))
m3_c <- list(auc = NA_real_, ci = c(NA, NA, NA))
thresh_train <- NA_integer_
if (source == "comprasnet") {
  cat("\n  M3: temporal holdout (train 2013-2016 classifier, all-period cobidder GT)\n")
  con <- dbConnect(duckdb())
  dbExecute(con, "PRAGMA threads=12; PRAGMA memory_limit='14GB'")
  PANEL <- file.path(ROOT, "data/processed_comprasnet/bid_level_full_year.parquet")
  train_stats <- dbGetQuery(con, sprintf("
    SELECT
      códigofornecedor AS firm_code,
      CASE WHEN SUM(flagvencedor) = 0 THEN 1 ELSE 0 END AS always_loser_train,
      SUM(CASE WHEN flagvencedor = 0 THEN 1 ELSE 0 END) AS tenders_count_train
    FROM '%s'
    WHERE year BETWEEN 2013 AND 2016
    GROUP BY códigofornecedor
  ", PANEL))
  dbDisconnect(con, shutdown = TRUE)
  setDT(train_stats)
  al_train <- train_stats[always_loser_train == 1L]
  qts <- quantile(al_train$tenders_count_train, c(0.25, 0.5, 0.75))
  thresh_train <- as.integer(qts[2] + 1.5 * (qts[3] - qts[1]))
  al_train[, fl_binary_train := as.integer(tenders_count_train >= thresh_train)]
  al_train[, log_tc_train    := log1p(tenders_count_train)]
  al_train[, is_cobidder := as.integer(firm_code %in% cobid_codes)]
  cat(sprintf("    train pool (AL-train): %s firms, %d positives, thresh=%d\n",
              format(nrow(al_train), big.mark = ","),
              sum(al_train$is_cobidder), thresh_train))
  m3_b <- auc_with_ci(al_train$is_cobidder, al_train$fl_binary_train)
  m3_c <- auc_with_ci(al_train$is_cobidder, al_train$log_tc_train)
  cat(sprintf("    AUC FL%d binary  = %.4f [%.4f, %.4f]\n",
              thresh_train, m3_b$auc, m3_b$ci[1], m3_b$ci[3]))
  cat(sprintf("    AUC log_tc cont = %.4f [%.4f, %.4f]\n",
              m3_c$auc, m3_c$ci[1], m3_c$ci[3]))
} else {
  cat("\n  M3: temporal holdout SKIPPED for BEC (year-stamped panel not built here)\n")
  cat("       see scripts/27_strict_prospective_holdout.R for canonical BEC version\n")
}

# ============================================================================
# Drop chain summary
# ============================================================================
cat("\n  === DROP CHAIN (AUC binary | continuous) ===\n")
cat(sprintf("  M1 in-sample:       %.4f | %.4f\n", m1_b$auc, m1_c$auc))
cat(sprintf("  M2 5-fold CV mean:  %.4f | %.4f\n", m2_b_mean, m2_c_mean))
if (!is.na(m3_b$auc)) {
  cat(sprintf("  M3 temporal:        %.4f | %.4f\n", m3_b$auc, m3_c$auc))
  cat(sprintf("  drop M1→M2:         %.4f | %.4f\n",
              m1_b$auc - m2_b_mean, m1_c$auc - m2_c_mean))
  cat(sprintf("  drop M2→M3:         %.4f | %.4f\n",
              m2_b_mean - m3_b$auc, m2_c_mean - m3_c$auc))
}

# ---- Save ----------------------------------------------------------------
out_dir <- file.path(ROOT, "work/v20-comprasnet/output", paste0("an014_", source))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

results <- list(
  source             = source,
  threshold          = thresh,
  pool_size          = nrow(al),
  n_positives        = sum(al$is_cobidder),
  m1_auc_binary      = m1_b$auc,
  m1_auc_continuous  = m1_c$auc,
  m2_auc_binary_mean = m2_b_mean,
  m2_auc_binary_sd   = m2_b_sd,
  m2_auc_cont_mean   = m2_c_mean,
  m2_auc_cont_sd     = m2_c_sd,
  m3_auc_binary      = m3_b$auc,
  m3_auc_continuous  = m3_c$auc,
  threshold_train    = thresh_train,
  generated_at       = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)

json_path <- file.path(out_dir, "an014_results.json")
fmt_val <- function(v) {
  if (is.numeric(v) && length(v) == 1L) {
    if (is.na(v)) "null"
    else if (is.finite(v) && (abs(v) < 1e-3 || abs(v) >= 1e5)) sprintf("%.4e", v)
    else sprintf("%.6f", v)
  } else if (is.character(v)) sprintf('"%s"', v)
  else as.character(v)
}
lines <- sapply(names(results), function(k) sprintf('  "%s": %s', k, fmt_val(results[[k]])))
writeLines(c("{", paste(lines, collapse = ",\n"), "}"), json_path)
cat(sprintf("\n  → %s\n", json_path))

csv_path <- file.path(out_dir, "an014_results.csv")
write.csv(as.data.frame(results), csv_path, row.names = FALSE)
cat(sprintf("  → %s\n", csv_path))
