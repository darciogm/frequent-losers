# ============================================================================
# 12_build_item_value.R — Item-level value dataset for Strategy 1 (RDD at R$80k)
# Paper 3 v14 (provisional): Frequent Losers in Public Procurement
#
# Builds a per-item dataset with:
#   - item_value = qty × ref_price (Brazilian comma-decimal converted)
#   - modality (1=convite, 3=pregão; matches the proc_compra coding in
#     BEC_bid_to_bid.csv)
#   - year, PBU, item code, OC number
#   - FL flag (item has at least one FL participant)
#
# Source: paper6 BEC_bid_to_bid.csv (1.5 GB raw; bid-level COM quantidade)
# Output: data/processed/item_value_panel.parquet
#
# Used by: 13_rdd_cap.R (Strategy 1)
# ============================================================================

cat("=== 12_build_item_value.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(duckdb); library(DBI); library(arrow); library(data.table)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
SRC  <- file.path("/home/darciogm1/projetos/bitter-pills",
  "paper6-procure/Darcio/data/DarcioHenrik/data/Licitações do Estado de SP",
  "BEC_bid_to_bid.csv")
OUT  <- file.path(BASE, "data", "processed", "item_value_panel.parquet")

con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

cat("  Source:", SRC, "\n")
cat("  Output:", OUT, "\n")

# ---- Inspect source -------------------------------------------------------
read_args <- "delim=',', header=true, sample_size=-1, strict_mode=false, null_padding=true, parallel=false, ignore_errors=true, all_varchar=true"
n_raw <- dbGetQuery(con, sprintf("
  SELECT COUNT(*) AS n
  FROM read_csv('%s', %s)
", SRC, read_args))$n
cat("  Source rows (bid-level):", format(n_raw, big.mark=","), "\n")

# ---- Aggregate to item level + value computation --------------------------
# Item-level: one row per (numerodaoc, códigoitem). Take MAX of qty and ref
# (constant within item). Modality from "Descrição Procedimento Compra".
# Year from "Mês Ano Encerramento" (format MM/YYYY).

cat("  Aggregating bid-level → item-level with value...\n")

agg_query <- sprintf("
CREATE OR REPLACE TEMP TABLE item_panel AS
WITH src AS (
  SELECT
    \"Numero da OC\"                       AS numerodaoc,
    \"Código Item\"                        AS codigoitem,
    \"Código Unidade Compradora\"          AS pbu_code,
    \"Descrição Procedimento Compra\"      AS modality_str,
    \"Mês Ano Encerramento\"               AS mes_ano,
    TRY_CAST(REPLACE(CAST(\"Quantidade de Item\" AS VARCHAR), ',', '.') AS DOUBLE)        AS qty,
    TRY_CAST(REPLACE(CAST(\"Valor Unitário Referência\" AS VARCHAR), ',', '.') AS DOUBLE) AS ref_unit_price,
    \"Código Fornecedor\"                  AS firm_code,
    TRY_CAST(\"Flag Vencedor\" AS DOUBLE)                AS won_flag
  FROM read_csv('%s', %s)
)
SELECT
  numerodaoc,
  codigoitem,
  ANY_VALUE(pbu_code)                                     AS pbu_code,
  ANY_VALUE(modality_str)                                  AS modality_str,
  CAST(SUBSTR(ANY_VALUE(mes_ano), 4, 4) AS INTEGER)        AS year,
  CASE
    WHEN UPPER(ANY_VALUE(modality_str)) = 'CONVITE' THEN 1
    WHEN UPPER(ANY_VALUE(modality_str)) = 'PREGÃO ELETRÔNICO' THEN 3
    WHEN UPPER(ANY_VALUE(modality_str)) = 'PREGAO ELETRONICO' THEN 3
    ELSE NULL
  END                                                       AS modality,
  MAX(qty)                                                  AS qty,
  MAX(ref_unit_price)                                       AS ref_unit_price,
  MAX(qty) * MAX(ref_unit_price)                            AS item_value,
  COUNT(DISTINCT firm_code)                                 AS n_firms,
  COUNT(*)                                                  AS n_bids,
  MAX(CASE WHEN won_flag = 1 THEN firm_code ELSE NULL END)  AS winner_code
FROM src
GROUP BY numerodaoc, codigoitem
", SRC, read_args)

dbExecute(con, agg_query)

agg_n <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM item_panel")$n
cat("  Item-level rows:", format(agg_n, big.mark=","), "\n")

cat("  Modality breakdown:\n")
print(dbGetQuery(con, "
  SELECT modality_str, modality, COUNT(*) AS n
  FROM item_panel
  GROUP BY modality_str, modality ORDER BY n DESC
"))

cat("\n  item_value distribution (R$):\n")
print(dbGetQuery(con, "
  SELECT
    quantile_cont(item_value, 0.10) AS p10,
    quantile_cont(item_value, 0.25) AS p25,
    quantile_cont(item_value, 0.50) AS p50,
    quantile_cont(item_value, 0.75) AS p75,
    quantile_cont(item_value, 0.90) AS p90,
    quantile_cont(item_value, 0.95) AS p95,
    quantile_cont(item_value, 0.99) AS p99
  FROM item_panel WHERE item_value IS NOT NULL AND item_value > 0
"))

cat("\n  Items in tight bandwidth around R$80,000:\n")
print(dbGetQuery(con, "
  SELECT
    SUM(CASE WHEN item_value BETWEEN 60000 AND 80000 THEN 1 ELSE 0 END) AS just_below,
    SUM(CASE WHEN item_value BETWEEN 80000 AND 100000 THEN 1 ELSE 0 END) AS just_above,
    SUM(CASE WHEN item_value BETWEEN 70000 AND 90000 THEN 1 ELSE 0 END) AS tight_band,
    SUM(CASE WHEN item_value BETWEEN 40000 AND 120000 THEN 1 ELSE 0 END) AS wide_band
  FROM item_panel WHERE item_value > 0
"))

cat("\n  Modality × year × bandwidth (±20% of R$80k = R$64k–R$96k):\n")
print(dbGetQuery(con, "
  SELECT modality, year, COUNT(*) AS n
  FROM item_panel
  WHERE item_value BETWEEN 64000 AND 96000 AND modality IN (1, 3)
  GROUP BY modality, year ORDER BY year, modality
"))

# ---- Merge FL flag --------------------------------------------------------
cat("\n  Merging FL flag from LOSERS_rebuilt.parquet...\n")
losers_path <- file.path(BASE, "data/processed/LOSERS_rebuilt.parquet")

merge_query <- sprintf("
CREATE OR REPLACE TEMP TABLE losers AS
SELECT
  numerodaoc,
  CAST(\"códigoitem\" AS VARCHAR) AS codigoitem,
  losers_count
FROM read_parquet('%s')
", losers_path)
dbExecute(con, merge_query)

dbExecute(con, "
CREATE OR REPLACE TEMP TABLE item_panel_fl AS
SELECT
  i.*,
  COALESCE(l.losers_count, 0) AS losers_count,
  CASE WHEN COALESCE(l.losers_count, 0) > 0 THEN 1 ELSE 0 END AS has_fl
FROM item_panel i
LEFT JOIN losers l USING (numerodaoc, codigoitem)
")

cat("  FL prevalence by modality:\n")
print(dbGetQuery(con, "
  SELECT modality, COUNT(*) AS n_items, SUM(has_fl) AS n_fl, AVG(has_fl) AS fl_share
  FROM item_panel_fl WHERE modality IN (1, 3) AND item_value > 0
  GROUP BY modality ORDER BY modality
"))

# ---- Write output ---------------------------------------------------------
cat("\n  Writing item-value panel to parquet...\n")
write_query <- sprintf("
COPY (
  SELECT * FROM item_panel_fl
  WHERE item_value IS NOT NULL AND item_value > 0
) TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy')
", OUT)
dbExecute(con, write_query)

n_out <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM read_parquet('%s')", OUT))$n
cat("  Saved:", OUT, " (rows:", format(n_out, big.mark=","), ")\n")

dbDisconnect(con, shutdown = TRUE)
cat("  Done.\n")
