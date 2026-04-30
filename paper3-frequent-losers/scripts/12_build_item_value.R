# ============================================================================
# 12_build_item_value.R — Item-level value dataset for Strategy 1 (RDD at R$80k)
# Paper 3 v14: Frequent Losers in Public Procurement
#
# Two-phase pipeline:
#
# Phase 1 — Raw bid-level parquet conversion.
#   For each source CSV: convert to parquet preserving ALL columns
#   (all_varchar=true). One parquet per source, cached. Re-running skips
#   already-converted files.
#
# Phase 2 — Item-level aggregation.
#   Read all bid-level parquets, union them (all 22 LANCES files share the
#   same schema; BEC_bid_to_bid has a slightly different one and is handled
#   separately if present). Aggregate to (numerodaoc, codigoitem) level
#   computing item_value = qty × ref_unit_price, modality, year, FL flag.
#
# Sources (auto-detected):
#   - LANCES_1.csv ... LANCES_22.csv (paper2-me-epp/data/raw/CSV/CSV/) —
#     22 semesters, 2009-2019.
#   - BEC_bid_to_bid.csv (paper6 Darcio/DarcioHenrik) — 2017 supplementary.
#
# Outputs:
#   - data/processed/intermediate/bid_level_<tag>.parquet (all cols, per src)
#   - data/processed/bid_level_full_v14.parquet (union, LANCES schema)
#   - data/processed/item_value_panel.parquet (item-level, with FL flag)
# ============================================================================

cat("=== 12_build_item_value.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(duckdb); library(DBI); library(arrow); library(data.table)
})

BASE      <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
INTER_DIR <- file.path(BASE, "data", "processed", "intermediate")
BID_OUT   <- file.path(BASE, "data", "processed", "bid_level_full_v14.parquet")
ITEM_OUT  <- file.path(BASE, "data", "processed", "item_value_panel.parquet")
dir.create(INTER_DIR, recursive = TRUE, showWarnings = FALSE)

LANCES_DIR <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/raw/CSV/CSV"

SRC_LANCES <- lapply(1:22, function(i) {
  list(
    path  = file.path(LANCES_DIR, sprintf("LANCES_%d.csv", i)),
    tag   = sprintf("lances_%02d", i),
    delim = ",",
    family = "lances"
  )
})

SRC_BIDTOBID <- list(
  list(
    path  = file.path("/home/darciogm1/projetos/bitter-pills",
      "paper6-procure/Darcio/data/DarcioHenrik/data/Licitações do Estado de SP",
      "BEC_bid_to_bid.csv"),
    tag   = "bid_to_bid_2017",
    delim = ",",
    family = "bid_to_bid"
  )
)

ALL_SOURCES <- c(SRC_LANCES, SRC_BIDTOBID)

# ---- Disk-presence check (skip Dropbox online-only stubs) -----------------
is_present <- function(p) {
  if (!file.exists(p)) return(FALSE)
  if (file.size(p) < 128) return(FALSE)
  con <- file(p, "rb"); on.exit(close(con))
  bytes <- readBin(con, what = "raw", n = 128)
  any(bytes != as.raw(0))
}

cat("\n  Source-presence audit:\n")
present_sources <- list()
for (src in ALL_SOURCES) {
  ok <- is_present(src$path)
  size_gb <- if (file.exists(src$path)) round(file.size(src$path) / 1e9, 2) else NA
  cat(sprintf("    [%s] %s  %s  (%.2f GB)\n",
              if (ok) "OK" else "  ", src$tag, basename(src$path),
              ifelse(is.na(size_gb), 0, size_gb)))
  if (ok) present_sources <- c(present_sources, list(src))
}
cat(sprintf("\n  %d/%d sources available on disk.\n",
            length(present_sources), length(ALL_SOURCES)))

if (length(present_sources) == 0) stop("No sources available.")

# ---- DuckDB ---------------------------------------------------------------
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

# ============================================================================
# PHASE 1 — Convert each CSV to parquet with ALL columns preserved
# ============================================================================
cat("\n--- Phase 1: CSV → parquet (preserving all columns) ---\n")

convert_one <- function(src) {
  out_path <- file.path(INTER_DIR, sprintf("bid_level_%s.parquet", src$tag))

  if (file.exists(out_path) && file.size(out_path) > 1000) {
    cat(sprintf("    [%s] cached (%s rows in %s)\n",
                src$tag,
                format(dbGetQuery(con, sprintf(
                  "SELECT COUNT(*) AS n FROM read_parquet('%s')", out_path))$n,
                  big.mark = ","),
                basename(out_path)))
    return(out_path)
  }

  cat(sprintf("    [%s] converting %s ...\n", src$tag, basename(src$path)))

  # Read with all_varchar=true to preserve every column safely. Address
  # bleeds into numeric fields and other dirty rows are tolerated via
  # ignore_errors=true. parallel=false is required for null_padding+quoted.
  read_args <- sprintf(paste0(
    "delim='%s', header=true, sample_size=-1, strict_mode=false, ",
    "null_padding=true, parallel=false, ignore_errors=true, all_varchar=true"
  ), src$delim)

  copy_q <- sprintf("
    COPY (SELECT * FROM read_csv('%s', %s))
    TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy')
  ", src$path, read_args, out_path)

  ok <- tryCatch({ dbExecute(con, copy_q); TRUE },
                 error = function(e) {
                   cat(sprintf("    [%s] ERROR: %s\n", src$tag,
                               conditionMessage(e)))
                   FALSE
                 })
  if (!ok) return(NULL)

  n_out <- dbGetQuery(con, sprintf(
    "SELECT COUNT(*) AS n FROM read_parquet('%s')", out_path))$n
  cat(sprintf("    [%s] wrote %s rows\n", src$tag, format(n_out, big.mark=",")))
  out_path
}

bid_paths <- list(lances = character(), bid_to_bid = character())
for (src in present_sources) {
  p <- convert_one(src)
  if (!is.null(p)) bid_paths[[src$family]] <- c(bid_paths[[src$family]], p)
}

cat(sprintf("\n  Phase 1 done. LANCES parquets: %d, BEC_bid_to_bid parquets: %d\n",
            length(bid_paths$lances), length(bid_paths$bid_to_bid)))

# ============================================================================
# PHASE 2 — Item-level aggregation
# ============================================================================
cat("\n--- Phase 2: aggregate to item level ---\n")

# 2a. LANCES family: schema is "Quantidade Item Vencedor" (winner qty),
# "Valor Unitário Referência" (ref unit price), "Flag Vencedor" (winner flag).
# All 22 files supposedly share the schema, so a direct UNION over the
# parquet list works.
#
# We keep ALL columns from the raw bid-level data via ANY_VALUE() for fields
# constant within (numerodaoc, codigoitem), aggregating multi-firm fields by
# count/max as appropriate.

agg_lances_q <- function(paths, out_tag) {
  if (length(paths) == 0) return(NULL)
  src_list_sql <- paste(sprintf("'%s'", paths), collapse = ", ")

  # Detect actual columns present in the first parquet (so we can safely
  # ANY_VALUE() what's there; fall back gracefully if a column is missing).
  cols <- dbGetQuery(con, sprintf("
    DESCRIBE SELECT * FROM read_parquet([%s]) LIMIT 1
  ", src_list_sql))$column_name
  cat(sprintf("  [%s] %d columns detected\n", out_tag, length(cols)))

  # Identify candidate columns for canonical fields
  pick <- function(candidates) {
    hit <- intersect(candidates, cols)
    if (length(hit) == 0) return(NULL)
    hit[1]
  }

  c_oc       <- pick(c("Numero da OC"))
  c_item     <- pick(c("Código Item"))
  c_pbu      <- pick(c("Código Unidade Compradora"))
  c_modal    <- pick(c("Descrição Procedimento Compra"))
  c_mesano   <- pick(c("Mês Ano Encerramento"))
  c_qty      <- pick(c("Quantidade Item Vencedor",
                       "Quantidade Fornecedor Vencedor",
                       "Quantidade de Item",
                       "Quantidade Negociada"))
  c_ref      <- pick(c("Valor Unitário Referência"))
  c_firm     <- pick(c("Código Fornecedor"))
  c_winflag  <- pick(c("Flag Vencedor"))

  required <- list(c_oc, c_item, c_modal, c_mesano, c_qty, c_ref, c_firm)
  if (any(sapply(required, is.null))) {
    cat("    Missing required columns:\n")
    cat("      OC=", c_oc, " item=", c_item, " modal=", c_modal,
        " mesano=", c_mesano, " qty=", c_qty, " ref=", c_ref,
        " firm=", c_firm, "\n")
    return(NULL)
  }

  # Build the aggregation query. We keep ALL columns of the raw parquet
  # via ANY_VALUE() — this preserves every field in the source schema in
  # case downstream analyses need them.
  passthrough_cols <- setdiff(cols, c(c_oc, c_item))
  pt_sql <- paste(sprintf('ANY_VALUE("%s") AS "%s"', passthrough_cols,
                          passthrough_cols),
                  collapse = ",\n    ")

  # Winner flag: use "Flag Vencedor" if present, otherwise infer from qty
  winflag_sql <- if (!is.null(c_winflag)) {
    sprintf('TRY_CAST("%s" AS INTEGER)', c_winflag)
  } else {
    sprintf('CASE WHEN TRY_CAST(REPLACE("%s", \',\', \'.\') AS DOUBLE) > 0 THEN 1 ELSE 0 END',
            c_qty)
  }

  agg_q <- sprintf("
CREATE OR REPLACE TEMP TABLE item_panel_%s AS
WITH src AS (
  SELECT *,
         %s AS _won_flag,
         TRY_CAST(REPLACE(\"%s\", ',', '.') AS DOUBLE) AS _qty,
         TRY_CAST(REPLACE(\"%s\", ',', '.') AS DOUBLE) AS _ref_unit_price
  FROM read_parquet([%s])
)
SELECT
  \"%s\"  AS numerodaoc,
  \"%s\"  AS codigoitem,
  %s,
  ANY_VALUE(_qty)             AS qty,
  ANY_VALUE(_ref_unit_price)  AS ref_unit_price,
  ANY_VALUE(_qty) * ANY_VALUE(_ref_unit_price) AS item_value,
  CAST(SUBSTR(ANY_VALUE(\"%s\"), 4, 4) AS INTEGER) AS year,
  CASE
    WHEN UPPER(ANY_VALUE(\"%s\")) = 'CONVITE' THEN 1
    WHEN UPPER(ANY_VALUE(\"%s\")) IN ('PREGÃO ELETRÔNICO', 'PREGAO ELETRONICO',
                                      'PREGÃO', 'PREGAO') THEN 3
    ELSE NULL
  END                                     AS modality,
  COUNT(DISTINCT \"%s\")                   AS n_firms,
  COUNT(*)                                AS n_bids,
  MAX(CASE WHEN _won_flag = 1 THEN \"%s\" ELSE NULL END) AS winner_code,
  ANY_VALUE(\"%s\")                        AS pbu_code
FROM src
GROUP BY numerodaoc, codigoitem
",
    out_tag,
    winflag_sql, c_qty, c_ref, src_list_sql,
    c_oc, c_item,
    pt_sql,
    c_mesano,
    c_modal, c_modal,
    c_firm, c_firm, c_pbu
  )

  cat(sprintf("    [%s] running aggregation...\n", out_tag))
  dbExecute(con, agg_q)

  n <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM item_panel_%s",
                               out_tag))$n
  cat(sprintf("    [%s] item-level rows: %s\n", out_tag, format(n, big.mark=",")))
  paste0("item_panel_", out_tag)
}

tab_lances    <- agg_lances_q(bid_paths$lances,    "lances")
tab_bid_to_bid <- agg_lances_q(bid_paths$bid_to_bid, "bid_to_bid")

# 2b. Combine the two families into a single panel. Use LANCES as the
# primary; BEC_bid_to_bid is supplementary (2017 only) and may have items
# not in LANCES (or vice versa). Use LEFT JOIN preference: prefer LANCES
# rows when both have the same (numerodaoc, codigoitem).
tabs <- Filter(function(x) !is.null(x), list(tab_lances, tab_bid_to_bid))
if (length(tabs) == 0) stop("Phase 2 produced no panels.")

union_q <- if (length(tabs) == 1) {
  sprintf("CREATE OR REPLACE TEMP TABLE item_panel AS SELECT * FROM %s", tabs[[1]])
} else {
  # Both panels' schemas may differ (different passthrough columns); align
  # on canonical columns only for the union step.
  canon <- "numerodaoc, codigoitem, qty, ref_unit_price, item_value, year, modality, n_firms, n_bids, winner_code, pbu_code"
  sprintf("
CREATE OR REPLACE TEMP TABLE item_panel AS
SELECT %s, 'lances' AS source FROM %s
UNION ALL
SELECT %s, 'bid_to_bid' AS source FROM %s
", canon, tabs[[1]], canon, tabs[[2]])
}
dbExecute(con, union_q)

# Dedupe (numerodaoc, codigoitem): prefer lances rows
dbExecute(con, "
CREATE OR REPLACE TEMP TABLE item_panel_dedup AS
SELECT * EXCLUDE (rn) FROM (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY numerodaoc, codigoitem
    ORDER BY CASE WHEN source = 'lances' THEN 0 ELSE 1 END,
             year DESC, n_bids DESC
  ) AS rn
  FROM item_panel
) WHERE rn = 1
")

n_dedup <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM item_panel_dedup")$n
cat(sprintf("\n  Item panel rows after dedup: %s\n", format(n_dedup, big.mark=",")))

cat("\n  Year coverage:\n")
print(dbGetQuery(con, "
  SELECT year, COUNT(*) AS n FROM item_panel_dedup
  GROUP BY year ORDER BY year
"))

cat("\n  Modality breakdown:\n")
print(dbGetQuery(con, "
  SELECT modality, COUNT(*) AS n,
         ROUND(quantile_cont(item_value, 0.50), 2) AS median_value,
         ROUND(quantile_cont(item_value, 0.95), 2) AS p95_value
  FROM item_panel_dedup WHERE modality IN (1, 3) AND item_value > 0
  GROUP BY modality ORDER BY modality
"))

cat("\n  Sample around R$80,000 cap (Strategy 1 RDD):\n")
print(dbGetQuery(con, "
  SELECT
    SUM(CASE WHEN item_value BETWEEN 60000 AND 80000 THEN 1 ELSE 0 END) AS just_below,
    SUM(CASE WHEN item_value BETWEEN 80000 AND 100000 THEN 1 ELSE 0 END) AS just_above,
    SUM(CASE WHEN item_value BETWEEN 70000 AND 90000 THEN 1 ELSE 0 END) AS tight_band,
    SUM(CASE WHEN item_value BETWEEN 40000 AND 120000 THEN 1 ELSE 0 END) AS wide_band
  FROM item_panel_dedup WHERE modality IN (1, 3)
"))

cat("\n  Sample around R$176,000 cap (post-2018 Decreto 9.412):\n")
print(dbGetQuery(con, "
  SELECT year >= 2018 AS post2018,
    SUM(CASE WHEN item_value BETWEEN 132000 AND 176000 THEN 1 ELSE 0 END) AS just_below,
    SUM(CASE WHEN item_value BETWEEN 176000 AND 220000 THEN 1 ELSE 0 END) AS just_above
  FROM item_panel_dedup WHERE modality IN (1, 3)
  GROUP BY post2018 ORDER BY post2018
"))

# ---- Merge FL flag --------------------------------------------------------
cat("\n  Merging FL flag from LOSERS_rebuilt.parquet...\n")
losers_path <- file.path(BASE, "data/processed/LOSERS_rebuilt.parquet")
dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE losers AS
  SELECT
    numerodaoc,
    CAST(\"códigoitem\" AS VARCHAR) AS codigoitem,
    losers_count
  FROM read_parquet('%s')
", losers_path))

dbExecute(con, "
CREATE OR REPLACE TEMP TABLE item_panel_fl AS
SELECT
  i.*,
  COALESCE(l.losers_count, 0) AS losers_count,
  CASE WHEN COALESCE(l.losers_count, 0) > 0 THEN 1 ELSE 0 END AS has_fl
FROM item_panel_dedup i
LEFT JOIN losers l USING (numerodaoc, codigoitem)
")

cat("  FL prevalence by modality:\n")
print(dbGetQuery(con, "
  SELECT modality, COUNT(*) AS n_items, SUM(has_fl) AS n_fl,
         ROUND(AVG(has_fl) * 100, 2) AS fl_share_pct
  FROM item_panel_fl WHERE modality IN (1, 3)
  GROUP BY modality ORDER BY modality
"))

# ---- Write outputs --------------------------------------------------------
dbExecute(con, sprintf("
COPY (SELECT * FROM item_panel_fl)
TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy')
", ITEM_OUT))

n_final <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM read_parquet('%s')",
                                   ITEM_OUT))$n
cat(sprintf("\n  Saved item panel: %s  (rows: %s)\n", ITEM_OUT,
            format(n_final, big.mark = ",")))

# Also write the unioned bid-level (LANCES only — BEC_bid_to_bid has a
# different schema and is kept as separate intermediate parquet).
if (length(bid_paths$lances) > 0) {
  src_list_sql <- paste(sprintf("'%s'", bid_paths$lances), collapse = ", ")
  dbExecute(con, sprintf("
    COPY (SELECT * FROM read_parquet([%s]))
    TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy')
  ", src_list_sql, BID_OUT))
  n_bid <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM read_parquet('%s')",
                                   BID_OUT))$n
  cat(sprintf("  Saved bid-level (LANCES union): %s  (rows: %s)\n",
              BID_OUT, format(n_bid, big.mark = ",")))
}

dbDisconnect(con, shutdown = TRUE)
cat("\n  Done.\n")
