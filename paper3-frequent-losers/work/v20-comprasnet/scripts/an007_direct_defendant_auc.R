#!/usr/bin/env Rscript
# ============================================================================
# an007_direct_defendant_auc.R  —  AN-007 AUC vs direct CADE defendants
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Purpose: replicate AN-007 (firm-level AUC of FL classifier against
# direct CADE defendants, not cobidders). BEC value reported in paper:
# AUC ≈ 0.49 with N=47 directs. This test is positioned in the paper as
# "boundary confirmation, not discrimination test" — loser-side rank
# cannot rank winners.
#
# Federal pool: 19 direct-defendant estabs across 14 CADE raízes
# (cade_link_v1, BEC reuse only). N is even smaller than BEC; expect
# CI ≈ [0.35, 0.65] with point estimate near 0.5.
#
# Usage:
#   Rscript work/v20-comprasnet/scripts/an007_direct_defendant_auc.R bec
#   Rscript work/v20-comprasnet/scripts/an007_direct_defendant_auc.R comprasnet
# ============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC)
})

args   <- commandArgs(trailingOnly = TRUE)
source <- if (length(args) > 0 && args[1] %in% c("bec","comprasnet")) {
  args[1]
} else {
  stop("usage: an007_direct_defendant_auc.R {bec|comprasnet}")
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

cat(sprintf("[AN-007] source=%s\n", source))

# Pool: ALL firms (universe), not just always-losers, because direct
# defendants include winners. Use firm_loss_stats for the universe.
if (source == "bec") {
  fls_path  <- file.path(ROOT, "data/processed/firm_loss_stats.parquet")
  fp_path   <- file.path(ROOT, "data/processed/FREQ_PARTICIP_rebuilt.parquet")
  thresh    <- 14L
  # Direct defendants = the firms in cade_bec_crossmatch (47 CADE-positive firms).
  directs_csv <- file.path(ROOT, "data/processed/cade_bec_crossmatch.csv")
  directs <- fread(directs_csv)
  directs[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
  direct_codes <- unique(directs$firm_code)
} else {
  fls_path  <- file.path(ROOT, "data/processed_comprasnet/firm_loss_stats.parquet")
  fp_path   <- file.path(ROOT, "data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet")
  thresh    <- 32L
  # Federal directs = the firm_ids in direct_defendants_federal.parquet.
  directs <- as.data.table(read_parquet(
    file.path(ROOT, "data/processed_comprasnet/cade_link_v1/direct_defendants_federal.parquet")))
  suppressWarnings(directs[, firm_code := sprintf("%014.0f", as.numeric(firm_id))])
  direct_codes <- unique(directs$firm_code)
}

cat(sprintf("  threshold = %d\n", thresh))
cat(sprintf("  N direct defendants = %d\n", length(direct_codes)))

# Universe: all firms
fls <- as.data.table(read_parquet(fls_path))
suppressWarnings(fls[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))])
universe <- fls[, .(firm_code, total_participations, total_wins, win_rate, always_loser)]

# Add tenders_count from FREQ_PARTICIP (for log_tc continuous classifier)
fp <- as.data.table(read_parquet(fp_path))
suppressWarnings(fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))])
universe <- merge(universe, fp[, .(firm_code, tenders_count)],
                  by = "firm_code", all.x = TRUE)
universe[is.na(tenders_count), tenders_count := 0L]

# Classifier features
universe[, fl_binary  := as.integer(always_loser == 1L & tenders_count >= thresh)]
universe[, log_tc     := log1p(tenders_count)]
universe[, is_direct  := as.integer(firm_code %in% direct_codes)]

cat(sprintf("  universe size: %d firms\n", nrow(universe)))
cat(sprintf("  direct defendants found in universe: %d (of %d declared)\n",
            sum(universe$is_direct), length(direct_codes)))
cat(sprintf("  FL classifier positives in universe: %d\n", sum(universe$fl_binary)))

if (sum(universe$is_direct) == 0L) {
  stop("no direct defendants found in universe — check CNPJ-format match")
}

# Direct defendants are mostly WINNERS in the paper interpretation.
# Show overlap with always-loser status as sanity:
n_direct_al <- sum(universe$is_direct == 1L & universe$always_loser == 1L)
n_direct_w  <- sum(universe$is_direct == 1L & universe$always_loser == 0L)
cat(sprintf("  among directs: %d always-loser, %d non-AL (winners)\n",
            n_direct_al, n_direct_w))

# AUC firm-level
roc_b <- pROC::roc(universe$is_direct, universe$fl_binary, quiet = TRUE)
roc_c <- pROC::roc(universe$is_direct, universe$log_tc,    quiet = TRUE)
auc_b <- as.numeric(pROC::auc(roc_b))
auc_c <- as.numeric(pROC::auc(roc_c))
ci_b  <- as.numeric(pROC::ci(roc_b))
ci_c  <- as.numeric(pROC::ci(roc_c))

cat(sprintf("\n  AUC FL%d binary   vs DIRECTS = %.4f [%.4f, %.4f]\n",
            thresh, auc_b, ci_b[1], ci_b[3]))
cat(sprintf("  AUC log_tc cont.  vs DIRECTS = %.4f [%.4f, %.4f]\n",
            auc_c, ci_c[1], ci_c[3]))
cat("  Expected near 0.5 (boundary confirmation: loser-side ranks cannot rank winners)\n")

# Output
out_dir <- file.path(ROOT, "work/v20-comprasnet/output", paste0("an007_", source))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

results <- list(
  source              = source,
  threshold           = thresh,
  universe_size       = nrow(universe),
  n_directs_declared  = length(direct_codes),
  n_directs_in_universe = sum(universe$is_direct),
  n_directs_al        = n_direct_al,
  n_directs_winner    = n_direct_w,
  auc_binary          = auc_b,
  ci_binary_lo        = ci_b[1], ci_binary_hi = ci_b[3],
  auc_continuous      = auc_c,
  ci_cont_lo          = ci_c[1], ci_cont_hi  = ci_c[3],
  generated_at        = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)

json_path <- file.path(out_dir, "an007_results.json")
fmt_val <- function(v) {
  if (is.numeric(v) && length(v) == 1L) {
    if (is.finite(v) && (abs(v) < 1e-3 || abs(v) >= 1e5)) sprintf("%.4e", v)
    else sprintf("%.6f", v)
  } else if (is.character(v)) sprintf('"%s"', v)
  else as.character(v)
}
lines <- sapply(names(results), function(k) sprintf('  "%s": %s', k, fmt_val(results[[k]])))
writeLines(c("{", paste(lines, collapse = ",\n"), "}"), json_path)
cat(sprintf("\n  → %s\n", json_path))

csv_path <- file.path(out_dir, "an007_results.csv")
write.csv(as.data.frame(results), csv_path, row.names = FALSE)
cat(sprintf("  → %s\n", csv_path))
