#!/usr/bin/env Rscript
# ============================================================================
# an001_zero_win_rank.R  —  AN-001 zero-win-rate rank concentration
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Purpose: confirm that the loser-side concentration concept survives in
# the federal panel. AN-001 in the BEC paper documents that firms with
# zero wins (always-losers) account for a disproportionately large
# share of FL participations — the conceptual sanity check that the
# distribution of tenders_count among always-losers has a heavy upper
# tail (defining "frequent losers" as a meaningful set).
#
# Reports for each panel:
#   - share of firms that are always-losers (win_rate = 0)
#   - share of always-losers that exceed FL threshold
#   - distribution of tenders_count among always-losers (quantiles)
#   - Gini coefficient of tenders_count concentration
# ============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table)
})

args   <- commandArgs(trailingOnly = TRUE)
source <- if (length(args) > 0 && args[1] %in% c("bec","comprasnet")) {
  args[1]
} else {
  stop("usage: an001_zero_win_rank.R {bec|comprasnet}")
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

cat(sprintf("[AN-001] source=%s\n", source))

if (source == "bec") {
  fls_path <- file.path(ROOT, "data/processed/firm_loss_stats.parquet")
  fp_path  <- file.path(ROOT, "data/processed/FREQ_PARTICIP_rebuilt.parquet")
  thresh   <- 14L
} else {
  fls_path <- file.path(ROOT, "data/processed_comprasnet/firm_loss_stats.parquet")
  fp_path  <- file.path(ROOT, "data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet")
  thresh   <- 32L
}

fls <- as.data.table(read_parquet(fls_path))
fp  <- as.data.table(read_parquet(fp_path))

n_firms     <- nrow(fls)
n_al        <- sum(fls$always_loser == 1L)
share_al    <- n_al / n_firms

al_tc <- fp$tenders_count
n_fl  <- sum(al_tc >= thresh)
share_fl_of_al <- n_fl / n_al

# Quantiles of tenders_count distribution among always-losers
qprobs <- c(0.50, 0.75, 0.90, 0.95, 0.99, 0.999, 1.00)
qvals  <- quantile(al_tc, qprobs)

# Gini of concentration (how unequally are losses distributed across always-losers)
gini <- function(x) {
  x <- sort(x)
  n <- length(x)
  if (n < 2L) return(NA_real_)
  2 * sum(seq_len(n) * x) / (n * sum(x)) - (n + 1) / n
}
g <- gini(al_tc)

# Output
cat(sprintf("  universe size:               %s firms\n",
            format(n_firms, big.mark = ",")))
cat(sprintf("  always-losers (win_rate=0):  %s (%.1f%%)\n",
            format(n_al, big.mark = ","), 100 * share_al))
cat(sprintf("  FL%d count (tc >= %d):        %s (%.1f%% of always-losers)\n",
            thresh, thresh, format(n_fl, big.mark = ","),
            100 * share_fl_of_al))
cat(sprintf("  tenders_count quantiles among always-losers:\n"))
for (i in seq_along(qprobs)) {
  cat(sprintf("    p%05.1f = %d\n", 100 * qprobs[i], as.integer(qvals[i])))
}
cat(sprintf("  Gini coefficient of tenders_count: %.4f\n", g))

# Save
out_dir <- file.path(ROOT, "work/v20-comprasnet/output", paste0("an001_", source))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

results <- list(
  source           = source,
  threshold        = thresh,
  n_firms          = n_firms,
  n_always_loser   = n_al,
  share_al         = share_al,
  n_fl             = n_fl,
  share_fl_of_al   = share_fl_of_al,
  q50_tc           = as.integer(qvals[1]),
  q75_tc           = as.integer(qvals[2]),
  q90_tc           = as.integer(qvals[3]),
  q95_tc           = as.integer(qvals[4]),
  q99_tc           = as.integer(qvals[5]),
  q999_tc          = as.integer(qvals[6]),
  q100_tc          = as.integer(qvals[7]),
  gini_tc          = g,
  generated_at     = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)

json_path <- file.path(out_dir, "an001_results.json")
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

csv_path <- file.path(out_dir, "an001_results.csv")
write.csv(as.data.frame(results), csv_path, row.names = FALSE)
cat(sprintf("  → %s\n", csv_path))
