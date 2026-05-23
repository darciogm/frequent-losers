#!/usr/bin/env Rscript
# ============================================================================
# an004b_threshold_sensitivity.R
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Sweep FL threshold from 14 to 200 on the federal panel and look at
# where AUC against cobidders peaks. The default 32 (median+1.5*IQR
# federal) may not be where the signal sits. BEC's 14 is also IQR-driven
# but the BEC distribution is more compact.
#
# Output: work/v20-comprasnet/output/an004_threshold_sensitivity/
# ============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC)
})

# Resolve ROOT
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

cat("[AN-004b] Federal threshold sensitivity\n")

# Load federal always-loser pool + cobidder set
fp <- as.data.table(read_parquet(
  file.path(ROOT, "data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet")))
suppressWarnings(fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))])
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]

cobid <- as.data.table(read_parquet(
  file.path(ROOT, "data/processed_comprasnet/cade_link_v1/cobidders_federal.parquet")))
suppressWarnings(cobid[, firm_code := sprintf("%014.0f", as.numeric(firm_id))])
cobid_codes <- unique(cobid$firm_code)

al[, is_cobidder := as.integer(firm_code %in% cobid_codes)]
al[, log_tc := log1p(tenders_count)]
cat(sprintf("  pool: %d  positives: %d\n", nrow(al), sum(al$is_cobidder)))

# Sweep thresholds. BEC equivalent is 14 (n FL = 2735); federal IQR gave 32.
# Test BEC-equivalent threshold of 14 (will give lots of FLs in federal pool),
# IQR threshold 32, then thresholds at higher percentiles.
quants <- c(0.50, 0.60, 0.70, 0.75, 0.80, 0.85, 0.90, 0.92, 0.94, 0.95,
            0.96, 0.97, 0.98, 0.99)
qvals  <- quantile(al$tenders_count, quants)
thresholds <- sort(unique(c(14L, 32L, ceiling(qvals))))

# Also include log_tc continuous AUC as benchmark (threshold-agnostic)
roc_c <- pROC::roc(al$is_cobidder, al$log_tc, quiet = TRUE)
auc_c <- as.numeric(pROC::auc(roc_c))
ci_c  <- as.numeric(pROC::ci(roc_c))
cat(sprintf("  CONTINUOUS log_tc AUC = %.4f [%.4f, %.4f]\n",
            auc_c, ci_c[1], ci_c[3]))

cat(sprintf("\n  %6s  %8s  %7s  %22s\n", "thresh", "n_fl", "n_pos", "AUC binary [CI]"))
cat(sprintf("  %6s  %8s  %7s  %22s\n", "------", "----", "-----", "-----------------"))
rows <- list()
for (thr in thresholds) {
  al[, fl_binary := as.integer(tenders_count >= thr)]
  n_fl <- sum(al$fl_binary)
  if (n_fl < 10L || n_fl > nrow(al) - 10L) next
  roc_b <- pROC::roc(al$is_cobidder, al$fl_binary, quiet = TRUE)
  auc_b <- as.numeric(pROC::auc(roc_b))
  ci_b  <- as.numeric(pROC::ci(roc_b))
  cat(sprintf("  %6d  %8d  %7d  %.4f [%.4f, %.4f]\n",
              thr, n_fl, sum(al$fl_binary * al$is_cobidder),
              auc_b, ci_b[1], ci_b[3]))
  rows[[length(rows) + 1L]] <- data.table(
    threshold = thr, n_fl = n_fl,
    n_positives_in_fl = sum(al$fl_binary * al$is_cobidder),
    auc = auc_b, ci_lo = ci_b[1], ci_hi = ci_b[3]
  )
}

out_dir <- file.path(ROOT, "work/v20-comprasnet/output/an004_threshold_sensitivity")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
res <- rbindlist(rows)
res[, gap_to_continuous := auc_c - auc]
fwrite(res, file.path(out_dir, "threshold_sensitivity.csv"))
cat(sprintf("\n  → %s/threshold_sensitivity.csv\n", out_dir))
cat(sprintf("  Continuous-AUC benchmark = %.4f (gap row shows how far each binary lags)\n",
            auc_c))
cat(sprintf("\n  Best binary threshold by AUC: %d (AUC=%.4f, gap=%.4f)\n",
            res[which.max(auc), threshold],
            res[which.max(auc), auc],
            res[which.max(auc), gap_to_continuous]))
