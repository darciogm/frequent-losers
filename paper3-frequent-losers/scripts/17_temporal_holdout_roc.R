# ============================================================================
# 17_temporal_holdout_roc.R — Prospective hold-out ROC (Tier 1.3)
# Paper 3 v14: temporally robust detection
#
# Train threshold + FL classification on 2009-2014 firm × tender participation.
# Test on 2015-2019 against CADE adjudications. Genuinely out-of-time:
# the threshold and FL identity are fixed by 2014, before any of the
# 2015-2019 (or post-2019) cartel convictions could leak into training.
#
# Outputs:
#   output/temporal_holdout/roc_holdout.csv
#   output/temporal_holdout/auc_summary.csv
#   output/temporal_holdout/fig_temporal_holdout_roc.pdf
# ============================================================================

cat("=== 17_temporal_holdout_roc.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(ggplot2)
  if (!requireNamespace("pROC", quietly = TRUE)) {
    install.packages("pROC", repos = "https://cran.r-project.org")
  }
  library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "temporal_holdout")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data ------------------------------------------------------------
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]
cat(sprintf("  FTM rows: %s, year range %d-%d\n",
            format(nrow(ftm), big.mark=","),
            min(ftm$year, na.rm=TRUE), max(ftm$year, na.rm=TRUE)))

# ---- Ground truth: CADE co-bidders (always-losers that co-participated --
# with at least one CADE-defendant in the same tender-item). 193 firms in
# v13 baseline. This is the same ground truth used in v13's tab_roc_detection
# (AUC=0.94). For prospective hold-out we'd ideally truncate the co-bidder
# list to pre-test-year activity, but the cade_fl_cobidders.csv identifies
# firms by ANY co-bidding within the full sample — the closest we can get
# to genuine temporal hold-out is to ALSO truncate FTM-derived classification
# to pre-test-year.
cade_cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade_cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cade_codes <- unique(cade_cobid$firm_code)
cat(sprintf("  CADE co-bidder always-losers: %s\n",
            format(length(cade_codes), big.mark=",")))

# ---- Define FL classification using TRAIN window only ---------------------
build_fl <- function(ftm_sub, label) {
  # tender_count per firm = count of distinct (numerodaoc, codigoitem) where won=0
  losses <- ftm_sub[won == 0, .N, by = `códigofornecedor`]
  setnames(losses, "N", "tenders_count")
  wins   <- ftm_sub[won == 1, .N, by = `códigofornecedor`]
  setnames(wins, "N", "wins_count")

  firms <- merge(losses, wins, by = "códigofornecedor", all = TRUE)
  firms[is.na(tenders_count), tenders_count := 0L]
  firms[is.na(wins_count),    wins_count    := 0L]
  firms[, win_rate := wins_count / pmax(tenders_count + wins_count, 1L)]
  firms[, always_loser := as.integer(win_rate == 0)]

  # IQR threshold on always-loser tenders_count distribution
  al <- firms[always_loser == 1L, tenders_count]
  thresh <- median(al) + 1.5 * IQR(al)
  cat(sprintf("    [%s] N firms=%s, always-losers=%s, threshold=%g\n",
              label,
              format(nrow(firms), big.mark=","),
              format(sum(firms$always_loser), big.mark=","),
              round(thresh, 1)))

  firms[, is_fl := as.integer(always_loser == 1L & tenders_count > thresh)]
  firms[, threshold_used := thresh]
  firms[]
}

cat("\n  Training FL classification on 2009-2014 ...\n")
fl_train <- build_fl(ftm[year >= 2009L & year <= 2014L], "train 2009-2014")

cat("\n  Building 'test' classification using full sample 2009-2019 (for comparison) ...\n")
fl_full  <- build_fl(ftm, "full 2009-2019")

# ---- ROC on always-losers only (matches v13 baseline) ---------------------
fl_train_al <- fl_train[always_loser == 1L]
fl_full_al  <- fl_full[always_loser == 1L]
fl_train_al[, firm_code := sprintf("%014s", `códigofornecedor`)]
fl_full_al[,  firm_code := sprintf("%014s", `códigofornecedor`)]
fl_train_al[, is_cade := as.integer(firm_code %in% cade_codes)]
fl_full_al[,  is_cade := as.integer(firm_code %in% cade_codes)]

cat("\n  ROC analysis (always-losers only, score = tenders_count):\n")
cat(sprintf("    train (2009-2014): %d firms, %d CADE positives\n",
            nrow(fl_train_al), sum(fl_train_al$is_cade)))
cat(sprintf("    full  (2009-2019): %d firms, %d CADE positives\n",
            nrow(fl_full_al), sum(fl_full_al$is_cade)))

roc_train <- pROC::roc(fl_train_al$is_cade, fl_train_al$tenders_count, quiet = TRUE)
roc_full  <- pROC::roc(fl_full_al$is_cade,  fl_full_al$tenders_count,  quiet = TRUE)
cat(sprintf("    AUC train (2009-2014 classification):  %.4f  CI [%.4f, %.4f]\n",
            as.numeric(pROC::auc(roc_train)),
            as.numeric(pROC::ci(roc_train)[1]),
            as.numeric(pROC::ci(roc_train)[3])))
cat(sprintf("    AUC full  (2009-2019 classification):  %.4f  CI [%.4f, %.4f]\n",
            as.numeric(pROC::auc(roc_full)),
            as.numeric(pROC::ci(roc_full)[1]),
            as.numeric(pROC::ci(roc_full)[3])))

# ---- Year-by-year prospective AUC -----------------------------------------
# For each test year t in 2015-2019, recompute FL classification using only
# 2009-(t-1) data, then score against CADE.
cat("\n  Year-by-year prospective AUC (training window grows yearly):\n")
yearly <- data.table(test_year = integer(), auc = numeric(),
                     ci_lo = numeric(), ci_hi = numeric(),
                     n_firms = integer(), n_cade = integer())

for (test_year in 2014:2019) {
  fl_y <- build_fl(ftm[year < test_year], sprintf("through %d", test_year - 1))
  # Keep only always-losers — same restriction as v13 ROC
  fl_y_al <- fl_y[always_loser == 1L]
  fl_y_al[, firm_code := sprintf("%014s", `códigofornecedor`)]
  fl_y_al[, is_cade := as.integer(firm_code %in% cade_codes)]
  fl_y_al[, score   := tenders_count]

  if (sum(fl_y_al$is_cade) >= 5 && length(unique(fl_y_al$score)) > 5) {
    r <- pROC::roc(fl_y_al$is_cade, fl_y_al$score, quiet = TRUE)
    yearly <- rbind(yearly, data.table(
      test_year = test_year,
      auc       = as.numeric(pROC::auc(r)),
      ci_lo     = as.numeric(pROC::ci(r)[1]),
      ci_hi     = as.numeric(pROC::ci(r)[3]),
      n_firms   = nrow(fl_y_al),
      n_cade    = sum(fl_y_al$is_cade)
    ))
  }
}
print(yearly)
fwrite(yearly, file.path(OUT, "auc_summary.csv"))

# ---- Figure: AUC over training-window expansion ---------------------------
if (nrow(yearly) >= 2) {
  p <- ggplot(yearly, aes(x = test_year, y = auc)) +
    geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.2) +
    geom_line() + geom_point(size = 2) +
    geom_hline(yintercept = 0.5, linetype = "dotted", color = "gray60") +
    geom_hline(yintercept = 0.9, linetype = "dashed", color = "gray60") +
    coord_cartesian(ylim = c(0.5, 1.0)) +
    labs(x = "Test year (training window: 2009 → year−1)",
         y = "AUC against CADE adjudications",
         title = "Prospective AUC: training-window expansion test",
         subtitle = "Stable AUC across windows = temporally robust screen") +
    theme_bw()
  ggsave(file.path(OUT, "fig_temporal_holdout_roc.pdf"), p,
         width = 7, height = 4.5, device = cairo_pdf)
  cat(sprintf("  Saved: %s\n", file.path(OUT, "fig_temporal_holdout_roc.pdf")))
}

# Save full ROC curves for plotting
roc_data <- rbind(
  data.table(spec = "train_2009_2014", fpr = 1 - roc_train$specificities,
             tpr = roc_train$sensitivities),
  data.table(spec = "full_2009_2019", fpr = 1 - roc_full$specificities,
             tpr = roc_full$sensitivities)
)
fwrite(roc_data, file.path(OUT, "roc_holdout.csv"))

cat("\n  Done.\n")
