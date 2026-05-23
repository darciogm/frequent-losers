#!/usr/bin/env Rscript
# ============================================================================
# an004_cobidder_auc.R  —  AN-004 firm-level AUC FL vs CADE cobidders
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Purpose: replicate AN-004 (firm-level AUC of FL classifier against
# CADE-anchored cobidder set) on the federal ComprasNet panel built
# in Stage 1b/1c. Also provides a BEC validation pass so that the
# Python-based linkage script does not silently diverge from the
# canonical R+pROC stack used by `scripts/36_gate_d1_harmonized.R`.
#
# BEC baseline (canonical, from \valAUCFLfirm in paper):
#   FL14 firm-level AUC = 0.924
#
# Usage:
#   Rscript work/v20-comprasnet/scripts/an004_cobidder_auc.R bec
#   Rscript work/v20-comprasnet/scripts/an004_cobidder_auc.R comprasnet
#
# FL convention: tenders_count >= threshold (commits bd504b5, 67aa4eb).
# ============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC)
})

args   <- commandArgs(trailingOnly = TRUE)
source <- if (length(args) > 0 && args[1] %in% c("bec","comprasnet")) {
  args[1]
} else {
  stop("usage: an004_cobidder_auc.R {bec|comprasnet}")
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

cat(sprintf("[AN-004] source=%s  root=%s\n", source, ROOT))

# ---- Paths and convention -----------------------------------------------
if (source == "bec") {
  fp_path    <- file.path(ROOT, "data/processed/FREQ_PARTICIP_rebuilt.parquet")
  cobid_csv  <- file.path(ROOT, "data/processed/cade_fl_cobidders.csv")
  cobid_parq <- NA_character_
  thresh     <- 14L
} else {
  fp_path    <- file.path(ROOT, "data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet")
  cobid_csv  <- NA_character_
  cobid_parq <- file.path(ROOT, "data/processed_comprasnet/cade_link_v1/cobidders_federal.parquet")
  thresh     <- 32L
}
cat(sprintf("  FL threshold (tenders_count >=): %d\n", thresh))

# ---- Load always-losers --------------------------------------------------
stopifnot(file.exists(fp_path))
fp <- as.data.table(read_parquet(fp_path))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
cat(sprintf("  always-loser pool: %d firms\n", nrow(al)))

# ---- Load cobidder set ---------------------------------------------------
if (source == "bec") {
  stopifnot(file.exists(cobid_csv))
  cobid <- fread(cobid_csv)
  cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
} else {
  stopifnot(file.exists(cobid_parq))
  cobid <- as.data.table(read_parquet(cobid_parq))
  cobid[, firm_code := sprintf("%014.0f", as.numeric(firm_id))]
}
cobid_codes <- unique(cobid$firm_code)
cat(sprintf("  cobidder set: %d distinct firm codes\n", length(cobid_codes)))

# ---- Build classifier features ------------------------------------------
al[, fl_binary   := as.integer(tenders_count >= thresh)]
al[, log_tc      := log1p(tenders_count)]
al[, is_cobidder := as.integer(firm_code %in% cobid_codes)]
cat(sprintf("  positives in pool (cobidders ∩ always-losers): %d\n",
            sum(al$is_cobidder)))
cat(sprintf("  FL%d count in pool (tenders_count >= %d):       %d\n",
            thresh, thresh, sum(al$fl_binary)))

if (sum(al$is_cobidder) == 0L) {
  stop("zero positives in pool — AN-004 undefined for this panel")
}
if (sum(al$fl_binary) == 0L || sum(al$fl_binary) == nrow(al)) {
  stop("degenerate fl_binary classifier — all 0 or all 1")
}

# ---- AUC firm-level ------------------------------------------------------
roc_b <- pROC::roc(al$is_cobidder, al$fl_binary, quiet = TRUE)
roc_c <- pROC::roc(al$is_cobidder, al$log_tc,    quiet = TRUE)
auc_b <- as.numeric(pROC::auc(roc_b))
auc_c <- as.numeric(pROC::auc(roc_c))
ci_b  <- as.numeric(pROC::ci(roc_b))
ci_c  <- as.numeric(pROC::ci(roc_c))
delong <- pROC::roc.test(roc_b, roc_c, method = "delong")

cat(sprintf("\n  AUC FL%d binary   = %.4f [%.4f, %.4f]\n",
            thresh, auc_b, ci_b[1], ci_b[3]))
cat(sprintf("  AUC log_tc cont. = %.4f [%.4f, %.4f]\n",
            auc_c, ci_c[1], ci_c[3]))
cat(sprintf("  DeLong Z = %+.3f  p = %.4g  (continuous - binary direction)\n",
            as.numeric(delong$statistic), delong$p.value))

# ---- Output --------------------------------------------------------------
out_dir <- file.path(ROOT, "work/v20-comprasnet/output", paste0("an004_", source))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

results <- list(
  source                  = source,
  threshold               = thresh,
  pool_size_always_losers = nrow(al),
  positives_cobidders     = sum(al$is_cobidder),
  n_fl_binary_in_pool     = sum(al$fl_binary),
  auc_binary              = auc_b,
  ci_binary_lo            = ci_b[1], ci_binary_hi = ci_b[3],
  auc_continuous          = auc_c,
  ci_cont_lo              = ci_c[1], ci_cont_hi   = ci_c[3],
  delong_z                = as.numeric(delong$statistic),
  delong_p                = delong$p.value,
  generated_at            = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)

# JSON without jsonlite — hand-formatted
json_path <- file.path(out_dir, "an004_results.json")
fmt_val <- function(v) {
  if (is.numeric(v) && length(v) == 1L) {
    if (is.finite(v) && (abs(v) < 1e-3 || abs(v) >= 1e5)) sprintf("%.4e", v)
    else sprintf("%.6f", v)
  } else if (is.character(v)) {
    sprintf('"%s"', v)
  } else if (is.logical(v)) {
    if (v) "true" else "false"
  } else {
    as.character(v)
  }
}
lines <- sapply(names(results), function(k) {
  sprintf('  "%s": %s', k, fmt_val(results[[k]]))
})
writeLines(c("{", paste(lines, collapse = ",\n"), "}"), json_path)
cat(sprintf("\n  → %s\n", json_path))

# Also write a flat CSV for easy comparison BEC vs ComprasNet
csv_path <- file.path(out_dir, "an004_results.csv")
write.csv(as.data.frame(results), csv_path, row.names = FALSE)
cat(sprintf("  → %s\n", csv_path))
