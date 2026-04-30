# ============================================================================
# 15_first_time_fl.R — First-time-FL behavioral test (R-side, data.table)
# Paper 3 v14: Strategy 3
#
# Hypothesis: if FL firms are cover bidders (deliberately calibrated bids),
# their behavior should differ from non-FL always-losers ALREADY ON THEIR
# FIRST TENDER. On the first appearance, no selection on outcome is possible
# — no losses to learn from. Behavioral differences detected on the first
# bid cannot be artifact of survivor bias.
#
# Implementation:
#   1. DuckDB just to extract a slim bid-level table: firm_code, OC, item,
#      mes_ano, bid_price, ref_price, modal_str, won_flag (raw VARCHAR for
#      prices, cast in R).
#   2. R-side data.table for all ranking, filtering, merging, and modeling.
#      Avoids DuckDB type-promotion issues across heterogeneous LANCES
#      schemas in the union.
#
# Outcome variables (per firm × first item):
#   y1: log(bid_price / ref_price)        relative-to-reference markup
#   y2: log(bid_price / item_winner_bid)  loss-margin (markup over winner)
#   y3: log(bid_price / item_min_bid)     bid relative to lowest bid in item
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

if (!file.exists(BID)) stop("Run 12_build_item_value.R first.")

# ---- Load FL classification -----------------------------------------------
fls <- as.data.table(read_parquet(FP))
setnames(fls, "códigofornecedor", "firm_code")
THRESH <- 14L
fls[, is_fl          := as.integer(always_loser == 1L & tenders_count >  THRESH)]
fls[, is_loser_below := as.integer(always_loser == 1L & tenders_count <= THRESH)]
cat(sprintf("  Always-losers: %s | FL: %s | below-threshold: %s\n",
            format(sum(fls$always_loser == 1, na.rm=TRUE), big.mark=","),
            format(sum(fls$is_fl == 1, na.rm=TRUE), big.mark=","),
            format(sum(fls$is_loser_below == 1, na.rm=TRUE), big.mark=",")))

# ---- DuckDB: extract slim bid-level for always-losers only ----------------
cat("\n  Extracting bid-level rows for always-loser firms only ...\n")

al_codes <- fls[always_loser == 1L, unique(firm_code)]
cat(sprintf("  Always-loser firm codes: %s\n", format(length(al_codes), big.mark=",")))

# Materialize codes as a tiny parquet for DuckDB join
al_path <- file.path(BASE, "data/processed/intermediate/al_codes.parquet")
write_parquet(data.table(firm_code = al_codes), al_path)

con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

extract_q <- sprintf("
COPY (
  SELECT
    CAST(\"Código Fornecedor\"           AS VARCHAR) AS firm_code,
    CAST(\"Numero da OC\"                AS VARCHAR) AS numerodaoc,
    CAST(\"Código Item\"                 AS VARCHAR) AS codigoitem,
    CAST(\"Mês Ano Encerramento\"        AS VARCHAR) AS mes_ano,
    CAST(\"Valor Unitário Proposta\"     AS VARCHAR) AS bid_price_str,
    CAST(\"Valor Unitário Referência\"   AS VARCHAR) AS ref_price_str,
    CAST(\"Flag Vencedor\"               AS VARCHAR) AS won_str,
    CAST(\"Descrição Procedimento Compra\" AS VARCHAR) AS modal_str
  FROM read_parquet('%s', union_by_name=true)
  WHERE \"Código Fornecedor\" IN (
    SELECT firm_code FROM read_parquet('%s')
  )
) TO '/tmp/p3_al_bids.parquet' (FORMAT PARQUET, COMPRESSION 'snappy')
", BID, al_path)
dbExecute(con, extract_q)
dbDisconnect(con, shutdown = TRUE)

cat("  Extracted slim bid-level for always-losers.\n")

# ---- R-side: load + cast prices --------------------------------------------
bids <- as.data.table(read_parquet("/tmp/p3_al_bids.parquet"))
cat(sprintf("  Loaded %s bid-level rows (always-loser firms).\n",
            format(nrow(bids), big.mark = ",")))

# Cast prices: handle both Brazilian-decimal and US-decimal formats
to_double <- function(x) {
  x[is.na(x) | x == ""] <- NA
  # Replace comma with dot for Brazilian format
  x <- gsub(",", ".", x, fixed = TRUE)
  as.numeric(x)
}

bids[, bid_price := to_double(bid_price_str)]
bids[, ref_price := to_double(ref_price_str)]
bids[, won       := suppressWarnings(as.integer(won_str))]
bids[, year      := suppressWarnings(as.integer(substr(mes_ano, 4, 4)))]
bids[, month     := suppressWarnings(as.integer(substr(mes_ano, 1, 2)))]
bids[, yyyymm    := year * 12L + month]
bids[, modality  := fifelse(toupper(modal_str) == "CONVITE", 1L,
                    fifelse(toupper(modal_str) %in%
                            c("PREGÃO ELETRÔNICO", "PREGAO ELETRONICO"), 3L,
                            NA_integer_))]

cat("  Price validity:\n")
cat(sprintf("    bid_price > 0:  %s rows\n",
            format(sum(bids$bid_price > 0, na.rm=TRUE), big.mark=",")))
cat(sprintf("    ref_price > 0:  %s rows\n",
            format(sum(bids$ref_price > 0, na.rm=TRUE), big.mark=",")))
cat(sprintf("    both valid:      %s rows\n",
            format(sum(bids$bid_price > 0 & bids$ref_price > 0, na.rm=TRUE),
                   big.mark = ",")))

# ---- Stage A: each firm × earliest tender-item -----------------------------
# NB: ref_price is missing for ~70% of bids (sparse field in BEC). We
# require bid_price > 0 only and use winner-relative metrics as primary
# outcomes; ref_price-relative metrics are computed where available.
cat("\n  Stage A: each firm × earliest valid-priced tender-item ...\n")
v <- bids[bid_price > 0 & !is.na(yyyymm)]
setkey(v, firm_code, yyyymm, numerodaoc, codigoitem)
ff <- v[, .SD[1], by = firm_code]
cat(sprintf("  Firm-first valid: %s rows\n", format(nrow(ff), big.mark = ",")))
cat(sprintf("    of which with ref_price: %s\n",
            format(sum(!is.na(ff$ref_price) & ff$ref_price > 0), big.mark=",")))

# ---- Stage B: per-item statistics across ALL bids (not just always-losers) -
# This needs the full bid-level data. Re-extract item-level stats from raw.
cat("\n  Stage B: item-level statistics from full bid-level ...\n")
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

# Restrict item_stats to first-tenders only (smaller computation)
keys_path <- file.path(BASE, "data/processed/intermediate/first_tender_keys.parquet")
write_parquet(ff[, .(numerodaoc, codigoitem)], keys_path)

stats_q <- sprintf("
COPY (
  WITH all_bids AS (
    SELECT
      CAST(\"Numero da OC\"            AS VARCHAR) AS numerodaoc,
      CAST(\"Código Item\"             AS VARCHAR) AS codigoitem,
      CAST(\"Valor Unitário Proposta\" AS VARCHAR) AS bid_price_str,
      CAST(\"Flag Vencedor\"           AS VARCHAR) AS won_str
    FROM read_parquet('%s', union_by_name=true)
    WHERE (\"Numero da OC\", \"Código Item\") IN (
      SELECT numerodaoc, codigoitem FROM read_parquet('%s')
    )
  ),
  cast_bids AS (
    SELECT numerodaoc, codigoitem,
           TRY_CAST(REPLACE(bid_price_str, ',', '.') AS DOUBLE) AS bp,
           TRY_CAST(won_str AS INTEGER) AS won
    FROM all_bids
    WHERE bid_price_str IS NOT NULL
  )
  SELECT numerodaoc, codigoitem,
         MIN(bp)                                                AS item_min_bid,
         MAX(CASE WHEN won = 1 THEN bp ELSE NULL END)           AS item_winner_bid,
         COUNT(*)                                                AS item_n_bids
  FROM cast_bids WHERE bp IS NOT NULL AND bp > 0
  GROUP BY numerodaoc, codigoitem
) TO '/tmp/p3_item_stats.parquet' (FORMAT PARQUET, COMPRESSION 'snappy')
", BID, keys_path)
dbExecute(con, stats_q)
dbDisconnect(con, shutdown = TRUE)

it <- as.data.table(read_parquet("/tmp/p3_item_stats.parquet"))
cat(sprintf("  Item-stats rows: %s\n", format(nrow(it), big.mark=",")))

# ---- Stage C: merge FL flag + item stats ----------------------------------
ff <- merge(ff, fls[, .(firm_code, always_loser, tenders_count, is_fl,
                        is_loser_below)],
            by = "firm_code", all.x = TRUE)
ff[, always_loser   := fifelse(is.na(always_loser), 0L, always_loser)]
ff[, is_fl          := fifelse(is.na(is_fl), 0L, is_fl)]
ff[, is_loser_below := fifelse(is.na(is_loser_below), 0L, is_loser_below)]
ff <- merge(ff, it, by = c("numerodaoc", "codigoitem"), all.x = TRUE)

cat(sprintf("\n  After merges: %s rows\n", format(nrow(ff), big.mark=",")))
cat(sprintf("    always_loser=1:  %s\n",
            format(sum(ff$always_loser == 1, na.rm=TRUE), big.mark=",")))
cat(sprintf("    is_fl=1:         %s\n",
            format(sum(ff$is_fl == 1, na.rm=TRUE), big.mark=",")))
cat(sprintf("    is_loser_below=1: %s\n",
            format(sum(ff$is_loser_below == 1, na.rm=TRUE), big.mark=",")))

# ---- Stage D: panel for analysis (always-losers, ≥2 bids/item) -----------
# Primary panel: requires bid_price > 0 and item with ≥2 bids.
# Secondary panel (for ref-relative outcomes): also requires ref_price > 0.
panel <- ff[always_loser == 1L & item_n_bids >= 2L & bid_price > 0]
cat(sprintf("\n  Analysis panel (always-loser, ≥2 bids/item): %s firms\n",
            format(nrow(panel), big.mark=",")))
cat(sprintf("    FL: %s   |  Below-threshold: %s\n",
            format(sum(panel$is_fl == 1, na.rm=TRUE), big.mark=","),
            format(sum(panel$is_loser_below == 1, na.rm=TRUE), big.mark=",")))

panel[, log_bid_ref    := fifelse(!is.na(ref_price) & ref_price > 0,
                                    log(bid_price / ref_price), NA_real_)]
panel[, log_bid_winner := fifelse(item_winner_bid > 0,
                                   log(bid_price / item_winner_bid),
                                   NA_real_)]
panel[, log_bid_min    := fifelse(item_min_bid > 0,
                                   log(bid_price / item_min_bid),
                                   NA_real_)]
panel[, item_f := factor(codigoitem)]
panel[, year_f := factor(year)]
panel[, fl     := is_fl]

# ---- Descriptive comparison ------------------------------------------------
cat("\n  Descriptive: bid distribution at FIRST tender, by FL status:\n")
desc <- panel[!is.na(log_bid_ref), .(
  n             = .N,
  mean_log_b_r  = round(mean(log_bid_ref, na.rm=TRUE), 4),
  med_log_b_r   = round(median(log_bid_ref, na.rm=TRUE), 4),
  sd_log_b_r    = round(sd(log_bid_ref, na.rm=TRUE), 4),
  mean_log_b_w  = round(mean(log_bid_winner, na.rm=TRUE), 4),
  mean_log_b_m  = round(mean(log_bid_min, na.rm=TRUE), 4)
), by = .(fl)]
print(desc)

# ---- Spec 1: log(bid/ref) ~ FL --------------------------------------------
# Skipped if ref_price is structurally missing for always-losers (BEC export
# artifact: always-loser firms participate exclusively in tender types
# where reference prices are not exported).
n_with_ref <- sum(!is.na(panel$log_bid_ref))
cat(sprintf("\n--- Spec 1: log(bid/ref) ~ FL  (n with ref = %d) ---\n",
            n_with_ref))
m1 <- if (n_with_ref >= 100) {
  tryCatch(
    feols(log_bid_ref ~ fl | item_f + year_f,
          data = panel[!is.na(log_bid_ref)], cluster = ~item_f),
    error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })
} else {
  cat("  Skipped: ref_price structurally missing for always-losers in BEC.\n")
  NULL
}
if (!is.null(m1)) print(coeftable(m1))

# ---- Spec 2: log(bid/winner) ~ FL -----------------------------------------
cat("\n--- Spec 2: log(bid/winner) ~ FL + item_FE + year_FE ---\n")
m2 <- tryCatch(
  feols(log_bid_winner ~ fl | item_f + year_f,
        data = panel[!is.na(log_bid_winner)], cluster = ~item_f),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })
if (!is.null(m2)) print(coeftable(m2))

# ---- Spec 3: log(bid/min_bid) ~ FL -----------------------------------------
cat("\n--- Spec 3: log(bid/min_bid) ~ FL + item_FE + year_FE ---\n")
m3 <- tryCatch(
  feols(log_bid_min ~ fl | item_f + year_f,
        data = panel[!is.na(log_bid_min)], cluster = ~item_f),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })
if (!is.null(m3)) print(coeftable(m3))

# ---- Spec 4: with modality interaction (using log_bid_winner) ------------
cat("\n--- Spec 4: log(bid/winner) ~ FL × modality + item_FE + year_FE ---\n")
m4 <- tryCatch(
  feols(log_bid_winner ~ fl * i(modality) | item_f + year_f,
        data = panel[!is.na(modality) & !is.na(log_bid_winner)],
        cluster = ~item_f),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })
if (!is.null(m4)) print(coeftable(m4))

# ---- Save summary ----------------------------------------------------------
extract_coef <- function(m, name) {
  if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  if (!"fl" %in% rownames(ct)) return(NULL)
  data.table(
    spec = name,
    coef = ct["fl", "Estimate"],
    se   = ct["fl", "Std. Error"],
    pval = ct["fl", "Pr(>|t|)"],
    n    = m$nobs
  )
}

summary_dt <- rbindlist(list(
  extract_coef(m1, "log_bid_over_ref"),
  extract_coef(m2, "log_bid_over_winner"),
  extract_coef(m3, "log_bid_over_min")
), fill = TRUE)

fwrite(summary_dt, file.path(OUT, "first_time_fl_summary.csv"))
cat("\n  ===== Headline first-time-FL coefficients =====\n")
print(summary_dt[, .(spec, coef = round(coef, 4), se = round(se, 4),
                     pval = round(pval, 4), n = format(n, big.mark = ","))])

cat("\n  Done.\n")
