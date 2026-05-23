#!/usr/bin/env Rscript
# ============================================================================
# an040_mechanism.R  --  AN-040 within-cell mechanism (federal)
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Purpose: replicate BEC AN-040 (Test 2: within-cell mechanism).
#
# BEC reference:
#   - feols(winner_vs_ref ~ losers | overlap_cell), with and without
#     log(n_firms) control.
#   - Without n_firms: -0.048 (SE 0.004, p < 10^-30).
#   - With n_firms:    +0.008 (n.s.) -- mechanism operates through
#     bidder-count channel.
#   - M1 revalidated: log(n_firms) ~ losers = +0.507 (~66% more bidders).
#   - Bidder-count threshold finding: sparse (1-3 bidders) Delta = +0.092
#     (selection regime); dense (11+) Delta = -0.015 (mechanism regime).
#
# Federal port:
#   - winner_vs_ref proxy: log(valor_item) -- relative to cell mean via FE.
#   - losers: is_treated_item from AN-039 (>=1 FL participation).
#   - overlap_cell: same as AN-039 (codigo_ug, item-stem, year, modality).
#   - With + without log(n_firms).
#   - Bidder-count threshold split.
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

cat("[AN-040] within-cell mechanism (federal)\n")

PANEL  <- file.path(ROOT, "data/processed_comprasnet/bid_level_full_year.parquet")
ITEM   <- file.path(ROOT, "data/processed_comprasnet/item_level_panel.parquet")
FP     <- file.path(ROOT, "data/processed_comprasnet/FREQ_PARTICIP_rebuilt.parquet")
THRESH <- 32L

con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")

# Recompute treated items (same construct as AN-039)
fl_firms <- dbGetQuery(con, sprintf(
  "SELECT códigofornecedor AS firm_id FROM '%s' WHERE tenders_count >= %d",
  FP, THRESH))
setDT(fl_firms)
dbWriteTable(con, "fl_firms_t", fl_firms, overwrite = TRUE)
treated <- dbGetQuery(con, sprintf("
  SELECT DISTINCT numerodaoc, códigoitem, year
  FROM '%s' bl
  WHERE bl.códigofornecedor IN (SELECT firm_id FROM fl_firms_t)
", PANEL))
setDT(treated)
treated[, codigoitem := `códigoitem`]; treated[, `códigoitem` := NULL]
treated[, is_treated := 1L]

# Load item-level panel
item_dt <- as.data.table(read_parquet(ITEM))
item_dt[, codigoitem := `códigoitem`]; item_dt[, `códigoitem` := NULL]
item_dt[, valor_item := as.numeric(valor_item)]
item_dt[, n_firms    := as.integer(n_firms)]
item_dt[, year       := as.integer(year)]
item_dt[, log_price  := log(valor_item)]
item_dt[, log_n_firms := log(n_firms)]
item_dt[, unit_price := valor_item / pmax(quantidade_item, 1e-6)]
item_dt[, log_unit_price := log(unit_price)]
item_dt <- item_dt[is.finite(log_price) & is.finite(log_unit_price)
                   & quantidade_item > 0 & n_firms > 0L]

setkey(treated, numerodaoc, codigoitem, year)
setkey(item_dt, numerodaoc, codigoitem, year)
item_dt[treated, losers := i.is_treated]
item_dt[is.na(losers), losers := 0L]

item_dt[, item_stem := substr(codigoitem, 1, 12)]
item_dt[, cell_id   := paste(codigo_ug, item_stem, year, po_phase_code, sep = "_")]

cat(sprintf("  item-level panel: %s rows  treated=%d  non-treated=%d\n",
            format(nrow(item_dt), big.mark = ","),
            sum(item_dt$losers), nrow(item_dt) - sum(item_dt$losers)))

dbDisconnect(con, shutdown = TRUE)

# ---- Main regressions ----------------------------------------------------
# We run two specifications:
# (1) raw log_price -- compares to BEC AN-040 directionally
# (2) log_unit_price (= log(valor/qty)) -- mitigates cell heterogeneity
#     when quantity varies inside (UG, item-stem) cells.
# Within-cell FE absorbs level differences; finer item-code FE absorbs
# product-type heterogeneity.

cat("\n  Spec 1: log_price ~ losers | cell, with/without log(n_firms)\n")
m_a <- feols(log_price ~ losers | cell_id, data = item_dt, cluster = ~cell_id)
m_b <- feols(log_price ~ losers + log_n_firms | cell_id,
             data = item_dt, cluster = ~cell_id)
print(etable(m_a, m_b, headers = c("no log_n_firms", "with log_n_firms"),
             tex = FALSE, se.below = TRUE, digits = 4))

cat("\n  Spec 2 (unit price): log_unit_price ~ losers | cell\n")
m_a2 <- feols(log_unit_price ~ losers | cell_id,
              data = item_dt, cluster = ~cell_id)
m_b2 <- feols(log_unit_price ~ losers + log_n_firms | cell_id,
              data = item_dt, cluster = ~cell_id)
print(etable(m_a2, m_b2, headers = c("unit no log_n_firms", "unit with log_n_firms"),
             tex = FALSE, se.below = TRUE, digits = 4))

# n_firms ~ losers (M1 revalidation)
cat("\n  M1 revalidation: log(n_firms) ~ losers | cell\n")
m_c <- feols(log_n_firms ~ losers | cell_id, data = item_dt, cluster = ~cell_id)
print(etable(m_c, tex = FALSE, se.below = TRUE, digits = 4))

# Bidder-count threshold split: sparse vs dense tenders
cat("\n  Bidder-count split: log_price ~ losers | cell, by n_firms bucket\n")
item_dt[, nfb := fcase(
  n_firms <= 3,                  "1-3",
  n_firms <= 6,                  "4-6",
  n_firms <= 10,                 "7-10",
  default                        = "11+"
)]
splits <- list()
for (band in c("1-3", "4-6", "7-10", "11+")) {
  d <- item_dt[nfb == band]
  if (nrow(d) < 5000) next
  m <- feols(log_price ~ losers | cell_id, data = d, cluster = ~cell_id)
  ct <- coeftable(m)
  b  <- ct["losers", "Estimate"]
  se <- ct["losers", "Std. Error"]
  p  <- ct["losers", "Pr(>|t|)"]
  cat(sprintf("    band %5s  n=%9s  coef=%+.4f  SE=%.4f  p=%.4g\n",
              band, format(nrow(d), big.mark = ","), b, se, p))
  splits[[band]] <- list(n = nrow(d), coef = b, se = se, p = p)
}

# Extract coefs
ct_a <- coeftable(m_a)
ct_b <- coeftable(m_b)
ct_c <- coeftable(m_c)
b_a <- ct_a["losers", "Estimate"]; se_a <- ct_a["losers", "Std. Error"]; p_a <- ct_a["losers", "Pr(>|t|)"]
b_b <- ct_b["losers", "Estimate"]; se_b <- ct_b["losers", "Std. Error"]; p_b <- ct_b["losers", "Pr(>|t|)"]
b_lnf <- ct_b["log_n_firms", "Estimate"]; se_lnf <- ct_b["log_n_firms", "Std. Error"]
b_c <- ct_c["losers", "Estimate"]; se_c <- ct_c["losers", "Std. Error"]; p_c <- ct_c["losers", "Pr(>|t|)"]

cat(sprintf("\n  Headline (federal):\n"))
cat(sprintf("    log_price       ~ losers (no n_firms)  : %+.4f  SE %.4f  p = %.4g\n", b_a, se_a, p_a))
cat(sprintf("    log_price       ~ losers + log_n_firms : %+.4f  SE %.4f  p = %.4g\n", b_b, se_b, p_b))
cat(sprintf("    coef on log_n_firms                    : %+.4f  SE %.4f\n", b_lnf, se_lnf))
cat(sprintf("    log_n_firms     ~ losers               : %+.4f  SE %.4f  p = %.4g\n", b_c, se_c, p_c))

ct_a2 <- coeftable(m_a2); ct_b2 <- coeftable(m_b2)
b_a2 <- ct_a2["losers", "Estimate"]; se_a2 <- ct_a2["losers", "Std. Error"]; p_a2 <- ct_a2["losers", "Pr(>|t|)"]
b_b2 <- ct_b2["losers", "Estimate"]; se_b2 <- ct_b2["losers", "Std. Error"]; p_b2 <- ct_b2["losers", "Pr(>|t|)"]
cat(sprintf("    log_unit_price  ~ losers (no n_firms)  : %+.4f  SE %.4f  p = %.4g\n", b_a2, se_a2, p_a2))
cat(sprintf("    log_unit_price  ~ losers + log_n_firms : %+.4f  SE %.4f  p = %.4g\n", b_b2, se_b2, p_b2))

# ---- Save ----------------------------------------------------------------
out_dir <- file.path(ROOT, "work/v20-comprasnet/output/an040_comprasnet")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
results <- list(
  source        = "comprasnet",
  threshold     = THRESH,
  n_items       = nrow(item_dt),
  n_treated     = sum(item_dt$losers),
  coef_no_nfirms      = b_a, se_no_nfirms      = se_a, p_no_nfirms      = p_a,
  coef_with_nfirms    = b_b, se_with_nfirms    = se_b, p_with_nfirms    = p_b,
  coef_log_n_firms    = b_lnf, se_log_n_firms  = se_lnf,
  coef_n_firms_on_losers = b_c, se_n_firms_on_losers = se_c, p_n_firms_on_losers = p_c,
  coef_unit_no_nfirms   = b_a2, se_unit_no_nfirms   = se_a2, p_unit_no_nfirms   = p_a2,
  coef_unit_with_nfirms = b_b2, se_unit_with_nfirms = se_b2, p_unit_with_nfirms = p_b2,
  band_1_3_coef       = if (!is.null(splits[["1-3"]])) splits[["1-3"]]$coef else NA_real_,
  band_4_6_coef       = if (!is.null(splits[["4-6"]])) splits[["4-6"]]$coef else NA_real_,
  band_7_10_coef      = if (!is.null(splits[["7-10"]])) splits[["7-10"]]$coef else NA_real_,
  band_11plus_coef    = if (!is.null(splits[["11+"]])) splits[["11+"]]$coef else NA_real_,
  generated_at        = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
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
           file.path(out_dir, "an040_results.json"))
write.csv(as.data.frame(results), file.path(out_dir, "an040_results.csv"), row.names = FALSE)
cat(sprintf("\n  -> %s/\n", out_dir))
