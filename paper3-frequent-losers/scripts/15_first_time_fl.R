# ============================================================================
# 15_first_time_fl.R — First-time-FL behavioral test
# Paper 3 v14: Strategy 3
#
# Hypothesis: if FL firms are cover bidders (deliberately calibrated bids),
# their behavior should differ from non-FL always-losers ALREADY ON THEIR
# FIRST TENDER. On the first appearance, there is no selection on outcome
# possible — no losses to learn from. Behavioral differences detected on
# the first bid cannot be artifact of survivor bias.
#
# Sample: each firm × earliest (numerodaoc, codigoitem) ever observed.
# For comparison: FL firms vs non-FL always-losers (firms with win_rate==0
# but tender_count below the FL threshold).
#
# Outcome variables (per firm × first item):
#   y1: log(bid_price / ref_price)        relative-to-reference markup
#   y2: log(bid_price / min_bid_in_item)  loss-margin (markup over winner)
#   y3: bid rank within item (1 = lowest, k = k-th lowest)
#   y4: bid_price (raw)
#
# Specs: regress y on FL_indicator + item × year fixed effects, cluster at
# item level. Test whether FL coefficient differs from zero.
#
# Robustness: restrict to first item with ≥3 bids; restrict to convite vs
# pregão separately; restrict to item categories with substantial volume.
# ============================================================================

cat("=== 15_first_time_fl.R: Strategy 3 — first-time-FL behavioral test ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(duckdb); library(DBI); library(arrow); library(data.table); library(fixest)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
BID  <- file.path(BASE, "data/processed/bid_level_full_v14.parquet")
FP   <- file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")
OUT  <- file.path(BASE, "output/first_time_fl")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(BID)) stop("Run 12_build_item_value.R first to build bid-level parquet.")

con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

# ---- Load FL classification (always-loser pool with tender counts) -------
cat("  Loading FREQ_PARTICIP_rebuilt (always-loser firms + tenders_count)...\n")
fls <- as.data.table(read_parquet(FP))
cat(sprintf("  Always-losers in FREQ_PARTICIP_rebuilt: %s rows\n",
            format(nrow(fls), big.mark = ",")))

# FL firms: always-loser AND tenders_count > IQR threshold (=14 in v13)
THRESH <- 14L
fls[, is_fl          := as.integer(always_loser == 1L & tenders_count >  THRESH)]
fls[, is_loser_below := as.integer(always_loser == 1L & tenders_count <= THRESH)]

cat(sprintf("  FL firms (always-loser & tenders > %d): %s\n", THRESH,
            format(sum(fls$is_fl, na.rm = TRUE), big.mark = ",")))
cat(sprintf("  Below-threshold always-losers: %s\n",
            format(sum(fls$is_loser_below, na.rm = TRUE), big.mark = ",")))

# ---- Pull bid-level data with prices for analysis sample -------------------
# We need: firm_code, numerodaoc, codigoitem, mes_ano, bid_price, ref_price
# All in the LANCES bid-level parquet.

cat("\n  Inspecting bid-level schema for column names...\n")
schema <- dbGetQuery(con, sprintf(
  "DESCRIBE SELECT * FROM read_parquet('%s') LIMIT 1", BID))$column_name

# Field detection helper
pick <- function(candidates) {
  hit <- intersect(candidates, schema)
  if (length(hit) == 0) NULL else hit[1]
}

c_oc      <- pick(c("Numero da OC"))
c_item    <- pick(c("Código Item"))
c_firm    <- pick(c("Código Fornecedor"))
c_mes     <- pick(c("Mês Ano Encerramento"))
c_bid     <- pick(c("Valor Unitário Proposta"))
c_ref     <- pick(c("Valor Unitário Referência"))
c_winflag <- pick(c("Flag Vencedor"))
c_modal   <- pick(c("Descrição Procedimento Compra"))

req <- list(c_oc, c_item, c_firm, c_mes, c_bid, c_ref)
if (any(sapply(req, is.null))) {
  cat("  Missing required column. Found:\n")
  cat("   oc=",c_oc," item=",c_item," firm=",c_firm," mes=",c_mes,
      " bid=",c_bid," ref=",c_ref,"\n")
  stop("Required bid-level fields missing.")
}

# ---- Stage A: identify each firm's earliest (numerodaoc, codigoitem) ------
cat("\n  Stage A: finding each firm's first tender-item...\n")

# Stage A: pull firm × earliest tender keys WITHOUT filtering on price
# (some files store prices as DOUBLE in union, which breaks REPLACE; we
# filter price validity in Stage D after the merge).
stage_a_q <- sprintf("
CREATE OR REPLACE TEMP TABLE firm_first AS
WITH bids AS (
  SELECT
    \"%s\"  AS firm_code,
    \"%s\"  AS numerodaoc,
    \"%s\"  AS codigoitem,
    \"%s\"  AS mes_ano,
    CAST(SUBSTR(\"%s\", 4, 4) AS INTEGER) * 12 +
      CAST(SUBSTR(\"%s\", 1, 2) AS INTEGER) AS yyyymm,
    \"%s\" AS bid_price_raw,
    \"%s\" AS ref_price_raw,
    \"%s\" AS modal_str
  FROM read_parquet('%s', union_by_name=true)
  WHERE \"%s\" IS NOT NULL
),
ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY firm_code
                            ORDER BY yyyymm, numerodaoc, codigoitem) AS rn
  FROM bids
)
SELECT firm_code, numerodaoc, codigoitem, yyyymm, mes_ano,
       bid_price_raw, ref_price_raw, modal_str
FROM ranked WHERE rn = 1
", c_firm, c_oc, c_item, c_mes, c_mes, c_mes, c_bid, c_ref, c_modal,
   BID, c_firm)
dbExecute(con, stage_a_q)

n_first <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM firm_first")$n
cat(sprintf("  Firm-first rows: %s\n", format(n_first, big.mark=",")))

# ---- Stage B: compute item-level reference (winner price, n_bids, min bid) -
cat("\n  Stage B: computing per-item statistics for each first item...\n")
stage_b_q <- sprintf("
CREATE OR REPLACE TEMP TABLE item_stats AS
WITH bids AS (
  SELECT
    \"%s\"  AS numerodaoc,
    \"%s\"  AS codigoitem,
    TRY_CAST(REPLACE(CAST(\"%s\" AS VARCHAR), ',', '.') AS DOUBLE) AS bid_price,
    TRY_CAST(CAST(\"%s\" AS VARCHAR) AS INTEGER) AS won
  FROM read_parquet('%s', union_by_name=true)
  WHERE bid_price IS NOT NULL AND bid_price > 0
)
SELECT numerodaoc, codigoitem,
       MIN(bid_price)            AS item_min_bid,
       MAX(CASE WHEN won = 1 THEN bid_price ELSE NULL END) AS item_winner_bid,
       COUNT(*)                   AS item_n_bids,
       COUNT(DISTINCT 1)          AS item_n_obs
FROM bids
GROUP BY numerodaoc, codigoitem
", c_oc, c_item, c_bid, c_winflag, BID)
dbExecute(con, stage_b_q)

# ---- Stage C: assemble first-tender × FL flag ------------------------------
cat("\n  Stage C: merging FL classifications and item stats...\n")

# Write fls (FREQ_PARTICIP_rebuilt + FL flags) to a parquet so DuckDB can
# join cleanly without registration quirks.
fls_path <- file.path(BASE, "data/processed/intermediate/fls_for_merge.parquet")
setnames(fls, "códigofornecedor", "firm_code")
write_parquet(fls[, .(firm_code, always_loser, tenders_count, is_fl,
                      is_loser_below)],
              fls_path)

dbExecute(con, sprintf("
CREATE OR REPLACE TEMP TABLE first_panel AS
SELECT
  ff.firm_code, ff.numerodaoc, ff.codigoitem, ff.yyyymm, ff.mes_ano,
  TRY_CAST(REPLACE(CAST(ff.bid_price_raw AS VARCHAR), ',', '.') AS DOUBLE) AS bid_price,
  TRY_CAST(REPLACE(CAST(ff.ref_price_raw AS VARCHAR), ',', '.') AS DOUBLE) AS ref_price,
  ff.modal_str,
  it.item_min_bid, it.item_winner_bid, it.item_n_bids,
  COALESCE(fls.always_loser, 0)    AS always_loser,
  fls.tenders_count,
  COALESCE(fls.is_fl, 0)           AS is_fl,
  COALESCE(fls.is_loser_below, 0)  AS is_loser_below,
  CAST(SUBSTR(ff.mes_ano, 4, 4) AS INTEGER) AS year,
  CASE
    WHEN UPPER(ff.modal_str) = 'CONVITE' THEN 1
    WHEN UPPER(ff.modal_str) IN ('PREGÃO ELETRÔNICO', 'PREGAO ELETRONICO') THEN 3
    ELSE NULL
  END AS modality
FROM firm_first ff
LEFT JOIN item_stats it USING (numerodaoc, codigoitem)
LEFT JOIN read_parquet('%s') fls ON ff.firm_code = fls.firm_code
", fls_path))

cat("  Merge stats from DuckDB:\n")
print(dbGetQuery(con, "
  SELECT COUNT(*) AS total,
         SUM(always_loser) AS n_always_loser,
         SUM(is_fl) AS n_fl,
         SUM(is_loser_below) AS n_below
  FROM first_panel
"))

# ---- Stage D: pull to R for fixest analysis -------------------------------
panel <- as.data.table(dbGetQuery(con, "
  SELECT * FROM first_panel
  WHERE always_loser = 1
    AND ref_price > 0 AND bid_price > 0
    AND item_n_bids >= 2
"))

cat(sprintf("\n  First-tender panel (always-losers only, ≥2 bids/item): %s firms\n",
            format(nrow(panel), big.mark=",")))
cat(sprintf("    FL: %s   |  Below-threshold loser: %s\n",
            format(sum(panel$is_fl == 1, na.rm=TRUE), big.mark=","),
            format(sum(panel$is_loser_below == 1, na.rm=TRUE), big.mark=",")))

# ---- Outcome construction --------------------------------------------------
panel[, log_bid_ref     := log(bid_price / ref_price)]
panel[, log_bid_winner  := fifelse(item_winner_bid > 0,
                                    log(bid_price / item_winner_bid), NA_real_)]
panel[, log_bid_min     := fifelse(item_min_bid > 0,
                                    log(bid_price / item_min_bid), NA_real_)]
panel[, item_f          := factor(codigoitem)]
panel[, year_f          := factor(year)]
panel[, fl              := is_fl]

# ---- Descriptive comparison ------------------------------------------------
cat("\n  Descriptive: bid distribution at FIRST tender, by FL status:\n")
desc <- panel[!is.na(log_bid_ref), .(
  n             = .N,
  mean_log_b_r  = round(mean(log_bid_ref, na.rm=TRUE), 4),
  med_log_b_r   = round(median(log_bid_ref, na.rm=TRUE), 4),
  sd_log_b_r    = round(sd(log_bid_ref, na.rm=TRUE), 4)
), by = .(fl)]
print(desc)

# ---- Spec 1: log(bid/ref) ~ FL --------------------------------------------
cat("\n--- Spec 1: log(bid/ref) ~ FL + item_FE + year_FE ---\n")
m1 <- feols(log_bid_ref ~ fl | item_f + year_f, data = panel,
            cluster = ~item_f)
print(coeftable(m1))

cat("\n  Same with modality interaction:\n")
m1m <- feols(log_bid_ref ~ fl + i(fl, modality, ref = 1) | item_f + year_f,
             data = panel[!is.na(modality)], cluster = ~item_f)
print(coeftable(m1m))

# ---- Spec 2: log(bid/winner) ~ FL -----------------------------------------
cat("\n--- Spec 2: log(bid/winner) ~ FL + item_FE + year_FE ---\n")
m2 <- tryCatch(
  feols(log_bid_winner ~ fl | item_f + year_f,
        data = panel[!is.na(log_bid_winner)], cluster = ~item_f),
  error = function(e) NULL)
if (!is.null(m2)) print(coeftable(m2))

# ---- Spec 3: log(bid/min) ~ FL --------------------------------------------
cat("\n--- Spec 3: log(bid/min_bid) ~ FL + item_FE + year_FE ---\n")
m3 <- tryCatch(
  feols(log_bid_min ~ fl | item_f + year_f,
        data = panel[!is.na(log_bid_min)], cluster = ~item_f),
  error = function(e) NULL)
if (!is.null(m3)) print(coeftable(m3))

# ---- Save summary ----------------------------------------------------------
extract_coef <- function(m, name) {
  if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  if (!"fl" %in% rownames(ct)) return(NULL)
  data.table(
    spec  = name,
    coef  = ct["fl", "Estimate"],
    se    = ct["fl", "Std. Error"],
    pval  = ct["fl", "Pr(>|t|)"],
    n     = m$nobs
  )
}

summary_dt <- rbindlist(list(
  extract_coef(m1,  "log_bid_over_ref"),
  extract_coef(m2,  "log_bid_over_winner"),
  extract_coef(m3,  "log_bid_over_min")
), fill = TRUE)

fwrite(summary_dt, file.path(OUT, "first_time_fl_summary.csv"))
cat("\n  ===== Headline first-time-FL coefficients =====\n")
print(summary_dt[, .(spec, coef = round(coef, 4), se = round(se, 4),
                     pval = round(pval, 4), n = format(n, big.mark = ","))])

dbDisconnect(con, shutdown = TRUE)
cat("\n  Done.\n")
