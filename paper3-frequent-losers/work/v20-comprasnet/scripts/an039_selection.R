#!/usr/bin/env Rscript
# ============================================================================
# an039_selection.R  --  AN-039 selection mechanism federal
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Purpose: replicate BEC AN-039 (Test 1: selection mechanism).
# Federal port using bid_level_full_year + item_level_panel.
#
# BEC reference: full-FE coefficient +3.55 (SE 0.23, p < 10^-55).
# ============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(duckdb); library(DBI)
})

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

cat("[AN-039] selection mechanism (federal)\n")

PANEL  <- file.path(ROOT, "data/processed_comprasnet/bid_level_full_year.parquet")
ITEM   <- file.path(ROOT, "data/processed_comprasnet/item_level_panel.parquet")
FP     <- file.path(ROOT, "data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet")
THRESH <- 32L

# ---- Identify FL firms (federal) -----------------------------------------
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")

fl_firms <- dbGetQuery(con, sprintf("
  SELECT códigofornecedor AS firm_id
  FROM '%s'
  WHERE tenders_count >= %d
", FP, THRESH))
setDT(fl_firms)
cat(sprintf("  FL firms (always-loser AND tenders_count >= %d): %s\n",
            THRESH, format(nrow(fl_firms), big.mark = ",")))

# ---- Treated items: any participation by an FL firm ---------------------
cat("  computing treated items (any FL participation) ...\n")
dbExecute(con, "DROP TABLE IF EXISTS fl_firms_t")
dbWriteTable(con, "fl_firms_t", fl_firms)
treated <- dbGetQuery(con, sprintf("
  SELECT DISTINCT numerodaoc, códigoitem, year
  FROM '%s' bl
  WHERE bl.códigofornecedor IN (SELECT firm_id FROM fl_firms_t)
", PANEL))
setDT(treated)
treated[, is_treated := 1L]
cat(sprintf("    treated items: %s\n", format(nrow(treated), big.mark = ",")))

# ---- Item-level panel + treatment flag ----------------------------------
cat("  joining treatment flag onto item-level panel ...\n")
item_dt <- as.data.table(read_parquet(ITEM))
item_dt[, codigoitem := `códigoitem`]; item_dt[, `códigoitem` := NULL]

# Numeric coercion
item_dt[, valor_item := as.numeric(valor_item)]
item_dt[, n_firms    := as.integer(n_firms)]
item_dt[, year       := as.integer(year)]
item_dt[, log_price  := log(valor_item)]
item_dt <- item_dt[is.finite(log_price) & n_firms > 0L]

# join treated set
treated[, codigoitem := `códigoitem`]; treated[, `códigoitem` := NULL]
setkey(treated, numerodaoc, codigoitem, year)
setkey(item_dt, numerodaoc, codigoitem, year)
item_dt[treated, is_treated_item := i.is_treated]
item_dt[is.na(is_treated_item), is_treated_item := 0L]

n_total   <- nrow(item_dt)
n_treated <- sum(item_dt$is_treated_item)
cat(sprintf("    item-level panel: %s rows (%d treated, %d non-treated)\n",
            format(n_total, big.mark = ","),
            n_treated, n_total - n_treated))

# ---- Build cell features --------------------------------------------------
# Cell: (codigo_ug, item-stem, year, modality)
# Take a coarser item stem (first 8 chars) so cells with single item codes do not dominate
item_dt[, item_stem := substr(codigoitem, 1, 12)]
item_dt[, cell_id   := paste(codigo_ug, item_stem, year, po_phase_code, sep = "_")]

# Compute cell_FL_share BEFORE restricting to non-treated
item_dt[, cell_n        := .N, by = cell_id]
item_dt[, cell_n_treated := sum(is_treated_item), by = cell_id]
item_dt[, cell_FL_share  := cell_n_treated / cell_n]

# Quartiles of cell_FL_share (continuous cell-level intensity)
cell_share <- unique(item_dt[, .(cell_id, cell_FL_share)])
qs <- quantile(cell_share$cell_FL_share, c(0.25, 0.50, 0.75))
cat(sprintf("  cell_FL_share distribution: Q1=%.4f Q2=%.4f Q3=%.4f\n", qs[1], qs[2], qs[3]))

# ---- Restrict to non-treated; run regression ------------------------------
dat <- item_dt[is_treated_item == 0L]
cat(sprintf("\n  regression sample: %s non-treated items\n",
            format(nrow(dat), big.mark = ",")))

# Non-treated mean log_price by cell_FL_share band.
# Bands tuned for the federal distribution: many zeros + a positive right tail.
dat[, qfl := fcase(
  cell_FL_share == 0,                 "B0_zero",
  cell_FL_share <= 0.05,              "B1_low",
  cell_FL_share <= 0.20,              "B2_mid",
  cell_FL_share <= 0.50,              "B3_high",
  default = "B4_top"
)]
desc <- dat[, .(mean_log_price = mean(log_price, na.rm = TRUE), n = .N), by = qfl]
setorder(desc, qfl)
cat("  Non-treated log_price by cell_FL_share band:\n")
print(desc)

cat("\n  Regression: log_price ~ cell_FL_share | cell FE\n")
m1 <- feols(log_price ~ cell_FL_share, data = dat,
            cluster = ~cell_id)
m2 <- feols(log_price ~ cell_FL_share | codigo_ug + item_stem + year + po_phase_code,
            data = dat, cluster = ~cell_id)
print(etable(m1, m2, headers = c("no FE", "full FE"), tex = FALSE,
             se.below = TRUE, digits = 4))

ct1 <- coeftable(m1); ct2 <- coeftable(m2)
b1 <- ct1["cell_FL_share", "Estimate"]; se1 <- ct1["cell_FL_share", "Std. Error"]; p1 <- ct1["cell_FL_share", "Pr(>|t|)"]
b2 <- ct2["cell_FL_share", "Estimate"]; se2 <- ct2["cell_FL_share", "Std. Error"]; p2 <- ct2["cell_FL_share", "Pr(>|t|)"]

cat(sprintf("\n  Headline:\n    no FE     coef = %+.4f  SE %.4f  p = %.4g\n",
            b1, se1, p1))
cat(sprintf("    full FE   coef = %+.4f  SE %.4f  p = %.4g\n", b2, se2, p2))

# ---- Save ----------------------------------------------------------------
out_dir <- file.path(ROOT, "work/v20-comprasnet/output/an039_comprasnet")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
results <- list(
  source                  = "comprasnet",
  threshold               = THRESH,
  n_total_items           = n_total,
  n_treated_items         = n_treated,
  n_nontreated_items      = n_total - n_treated,
  band_zero_mean_log_price = as.numeric(desc[qfl == "B0_zero", mean_log_price]),
  band_top_mean_log_price  = as.numeric(desc[qfl == "B4_top", mean_log_price]),
  band_delta_top_zero      = as.numeric(desc[qfl == "B4_top", mean_log_price] - desc[qfl == "B0_zero", mean_log_price]),
  coef_nofe               = b1, se_nofe = se1, p_nofe = p1,
  coef_fullfe             = b2, se_fullfe = se2, p_fullfe = p2,
  n_cells                 = uniqueN(dat$cell_id),
  generated_at            = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
)

fmt_val <- function(v) {
  if (is.numeric(v) && length(v) == 1L) {
    if (is.na(v)) "null"
    else if (is.finite(v) && (abs(v) < 1e-3 || abs(v) >= 1e5)) sprintf("%.4e", v)
    else sprintf("%.6f", v)
  } else if (is.character(v)) sprintf('"%s"', v)
  else as.character(v)
}
lines <- sapply(names(results), function(k) sprintf('  "%s": %s', k, fmt_val(results[[k]])))
writeLines(c("{", paste(lines, collapse = ",\n"), "}"),
           file.path(out_dir, "an039_results.json"))
write.csv(as.data.frame(results), file.path(out_dir, "an039_results.csv"), row.names = FALSE)
cat(sprintf("\n  -> %s/\n", out_dir))

dbDisconnect(con, shutdown = TRUE)
