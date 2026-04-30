# ============================================================================
# 12_build_item_value.R — Item-level value dataset for Strategy 1 (RDD at R$80k)
# Paper 3 v14 (provisional): Frequent Losers in Public Procurement
#
# Builds a per-item dataset with:
#   - item_value = qty × ref_price (Brazilian comma-decimal converted)
#   - modality (1=convite, 3=pregão)
#   - year, PBU, item code, OC number, winner code, n_firms, n_bids
#   - FL flag (item has at least one FL participant)
#
# Sources (auto-detected — only files physically present on disk are processed;
# Dropbox online-only stubs are skipped):
#   1. paper6 BEC_bid_to_bid.csv (1.5 GB; 2017 only). Always available.
#   2. LANCES_1.csv ... LANCES_22.csv (Dropbox; ~1.5 GB each; 22 semesters
#      covering 2009-2019). Available only after user marks "always keep on
#      this device" in Dropbox.
#
# Outputs:
#   - data/processed/intermediate/item_value_<source>.parquet (per-source)
#   - data/processed/item_value_panel.parquet (union)
#
# Used by: 13_rdd_cap.R (Strategy 1)
# ============================================================================

cat("=== 12_build_item_value.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(duckdb); library(DBI); library(arrow); library(data.table)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
INTER_DIR <- file.path(BASE, "data", "processed", "intermediate")
OUT       <- file.path(BASE, "data", "processed", "item_value_panel.parquet")
dir.create(INTER_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- Source registry ------------------------------------------------------
# Each source: path + schema_id (which column name set to use)
SRC_BIDTOBID <- list(
  path     = file.path("/home/darciogm1/projetos/bitter-pills",
    "paper6-procure/Darcio/data/DarcioHenrik/data/Licitações do Estado de SP",
    "BEC_bid_to_bid.csv"),
  schema   = "bid_to_bid",
  tag      = "bid_to_bid_2017",
  delim    = ","
)

LANCES_DIR <- "/mnt/c/Users/dgeni/Dropbox/Servidor Belem/Documents/Dados BEC/BEC_Final/DATABASE/CSV"
SRC_LANCES <- lapply(1:22, function(i) {
  list(
    path   = file.path(LANCES_DIR, sprintf("LANCES_%d.csv", i)),
    schema = "lances",
    tag    = sprintf("lances_%02d", i),
    delim  = ";"
  )
})

ALL_SOURCES <- c(list(SRC_BIDTOBID), SRC_LANCES)

# ---- Disk-presence check (skip Dropbox online-only stubs) -----------------
# Read the first 128 bytes. Dropbox stubs are all-NUL; real CSVs have ASCII
# header bytes. Robust to filenames with spaces and Unicode (where shelling
# out to `stat` fails).
is_present <- function(p) {
  if (!file.exists(p)) return(FALSE)
  if (file.size(p) < 128) return(FALSE)
  con <- file(p, "rb")
  on.exit(close(con))
  bytes <- readBin(con, what = "raw", n = 128)
  any(bytes != as.raw(0))   # any non-null byte → real content
}

cat("\n  Source-presence audit:\n")
present_sources <- list()
for (src in ALL_SOURCES) {
  ok <- is_present(src$path)
  size_gb <- if (file.exists(src$path)) round(file.size(src$path) / 1e9, 2) else NA
  cat(sprintf("    [%s] %s  %s  (%s GB)\n",
              if (ok) "✓" else "·",
              src$tag,
              basename(src$path),
              format(size_gb, nsmall = 2)))
  if (ok) present_sources <- c(present_sources, list(src))
}
cat(sprintf("\n  %d source(s) available on disk; %d not yet downloaded.\n",
            length(present_sources), length(ALL_SOURCES) - length(present_sources)))

if (length(present_sources) == 0) {
  stop("No sources available on disk. Mark Dropbox files as 'always keep on this device' first.")
}

# ---- Column name mapping per schema --------------------------------------
# Returns a SQL expression that produces canonical columns from raw CSV.
canonical_select <- function(schema) {
  if (schema == "bid_to_bid") {
    list(
      numerodaoc       = '"Numero da OC"',
      codigoitem       = '"Código Item"',
      pbu_code         = '"Código Unidade Compradora"',
      modality_str     = '"Descrição Procedimento Compra"',
      mes_ano          = '"Mês Ano Encerramento"',
      qty_raw          = '"Quantidade de Item"',
      ref_unit_price_raw = '"Valor Unitário Referência"',
      firm_code        = '"Código Fornecedor"',
      won_flag_raw     = '"Flag Vencedor"'
    )
  } else if (schema == "lances") {
    list(
      numerodaoc       = '"numerodaoc"',
      codigoitem       = '"códigoitem"',
      pbu_code         = '"códigounidadecompradora"',
      modality_str     = '"descriçãoprocedimentocompra"',
      mes_ano          = '"mêsanoencerramento"',
      qty_raw          = '"quantidadeitemvencedor"',
      ref_unit_price_raw = '"valorunitárioreferência"',
      firm_code        = '"códigofornecedor"',
      won_flag_raw     = '"flagvencedor"'
    )
  } else stop("Unknown schema: ", schema)
}

# ---- Per-source processor -------------------------------------------------
process_source <- function(src, con) {
  out_path <- file.path(INTER_DIR, sprintf("item_value_%s.parquet", src$tag))

  if (file.exists(out_path)) {
    cat(sprintf("    [%s] cached (%s)\n", src$tag, basename(out_path)))
    return(out_path)
  }

  cat(sprintf("    [%s] processing %s...\n", src$tag, basename(src$path)))
  cols <- canonical_select(src$schema)

  # Read args: all_varchar avoids type-sniff failures on dirty rows.
  read_args <- sprintf(
    "delim='%s', header=true, sample_size=-1, strict_mode=false, null_padding=true, parallel=false, ignore_errors=true, all_varchar=true",
    src$delim
  )

  agg_q <- sprintf("
COPY (
  WITH src AS (
    SELECT
      %s AS numerodaoc,
      %s AS codigoitem,
      %s AS pbu_code,
      %s AS modality_str,
      %s AS mes_ano,
      TRY_CAST(REPLACE(%s, ',', '.') AS DOUBLE) AS qty,
      TRY_CAST(REPLACE(%s, ',', '.') AS DOUBLE) AS ref_unit_price,
      %s AS firm_code,
      TRY_CAST(%s AS INTEGER) AS won_flag
    FROM read_csv('%s', %s)
  ),
  agg AS (
    SELECT
      numerodaoc,
      codigoitem,
      ANY_VALUE(pbu_code)        AS pbu_code,
      ANY_VALUE(modality_str)     AS modality_str,
      CAST(SUBSTR(ANY_VALUE(mes_ano), 4, 4) AS INTEGER) AS year,
      CASE
        WHEN UPPER(ANY_VALUE(modality_str)) = 'CONVITE' THEN 1
        WHEN UPPER(ANY_VALUE(modality_str)) IN ('PREGÃO ELETRÔNICO',
                                                'PREGAO ELETRONICO',
                                                'PREGÃO',
                                                'PREGAO') THEN 3
        ELSE NULL
      END AS modality,
      MAX(qty)                                                   AS qty,
      MAX(ref_unit_price)                                        AS ref_unit_price,
      MAX(qty) * MAX(ref_unit_price)                             AS item_value,
      COUNT(DISTINCT firm_code)                                  AS n_firms,
      COUNT(*)                                                   AS n_bids,
      MAX(CASE WHEN won_flag = 1 THEN firm_code ELSE NULL END)   AS winner_code
    FROM src
    GROUP BY numerodaoc, codigoitem
  )
  SELECT * FROM agg WHERE item_value IS NOT NULL AND item_value > 0
) TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy')",
    cols$numerodaoc, cols$codigoitem, cols$pbu_code, cols$modality_str,
    cols$mes_ano, cols$qty_raw, cols$ref_unit_price_raw, cols$firm_code,
    cols$won_flag_raw, src$path, read_args, out_path
  )

  ok <- tryCatch({ dbExecute(con, agg_q); TRUE },
                 error = function(e) {
                   cat(sprintf("    [%s] ERROR: %s\n", src$tag, conditionMessage(e)))
                   FALSE
                 })

  if (!ok) return(NULL)

  n_out <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM read_parquet('%s')",
                                   out_path))$n
  cat(sprintf("    [%s] wrote %s items\n", src$tag, format(n_out, big.mark = ",")))
  out_path
}

# ---- Process all available sources ----------------------------------------
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

cat("\n  Processing sources:\n")
inter_paths <- character()
for (src in present_sources) {
  p <- process_source(src, con)
  if (!is.null(p)) inter_paths <- c(inter_paths, p)
}

if (length(inter_paths) == 0) stop("No sources processed successfully.")

# ---- UNION + dedupe (later sources override earlier ones) -----------------
cat("\n  Union all intermediate parquets and dedup on (numerodaoc, codigoitem)...\n")
src_list_sql <- paste(sprintf("'%s'", inter_paths), collapse = ", ")
union_q <- sprintf("
CREATE OR REPLACE TEMP TABLE item_panel_raw AS
SELECT * FROM read_parquet([%s])
", src_list_sql)
dbExecute(con, union_q)

dbExecute(con, "
CREATE OR REPLACE TEMP TABLE item_panel AS
SELECT *
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY numerodaoc, codigoitem
                            ORDER BY year DESC, n_bids DESC) AS rn
  FROM item_panel_raw
) WHERE rn = 1
")

n_raw <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM item_panel_raw")$n
n_dedup <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM item_panel")$n
cat(sprintf("  Union rows: %s  →  unique items: %s\n",
            format(n_raw, big.mark = ","), format(n_dedup, big.mark = ",")))

cat("\n  Year coverage:\n")
print(dbGetQuery(con, "
  SELECT year, COUNT(*) AS n FROM item_panel GROUP BY year ORDER BY year
"))

cat("\n  Modality breakdown:\n")
print(dbGetQuery(con, "
  SELECT modality, COUNT(*) AS n, AVG(item_value) AS mean_value
  FROM item_panel WHERE modality IN (1, 3) GROUP BY modality ORDER BY modality
"))

cat("\n  Sample around R$80,000 cap (relevant for Strategy 1 RDD):\n")
print(dbGetQuery(con, "
  SELECT
    SUM(CASE WHEN item_value BETWEEN 60000 AND 80000 THEN 1 ELSE 0 END) AS just_below,
    SUM(CASE WHEN item_value BETWEEN 80000 AND 100000 THEN 1 ELSE 0 END) AS just_above,
    SUM(CASE WHEN item_value BETWEEN 70000 AND 90000 THEN 1 ELSE 0 END) AS tight_band,
    SUM(CASE WHEN item_value BETWEEN 40000 AND 120000 THEN 1 ELSE 0 END) AS wide_band
  FROM item_panel WHERE modality IN (1, 3)
"))

cat("\n  Sample around R$176,000 cap (post-2018 Decreto 9.412):\n")
print(dbGetQuery(con, "
  SELECT
    SUM(CASE WHEN item_value BETWEEN 132000 AND 176000 THEN 1 ELSE 0 END) AS just_below,
    SUM(CASE WHEN item_value BETWEEN 176000 AND 220000 THEN 1 ELSE 0 END) AS just_above
  FROM item_panel WHERE modality IN (1, 3) AND year >= 2018
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
  i.* EXCLUDE (rn),
  COALESCE(l.losers_count, 0) AS losers_count,
  CASE WHEN COALESCE(l.losers_count, 0) > 0 THEN 1 ELSE 0 END AS has_fl
FROM item_panel i
LEFT JOIN losers l USING (numerodaoc, codigoitem)
")

cat("  FL prevalence by modality:\n")
print(dbGetQuery(con, "
  SELECT modality, COUNT(*) AS n_items, SUM(has_fl) AS n_fl,
         ROUND(AVG(has_fl) * 100, 2) AS fl_share_pct
  FROM item_panel_fl WHERE modality IN (1, 3)
  GROUP BY modality ORDER BY modality
"))

# ---- Write final output ---------------------------------------------------
dbExecute(con, sprintf("
COPY (SELECT * FROM item_panel_fl)
TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy')
", OUT))

n_final <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM read_parquet('%s')", OUT))$n
cat(sprintf("\n  Saved: %s  (rows: %s)\n", OUT, format(n_final, big.mark = ",")))

dbDisconnect(con, shutdown = TRUE)
cat("  Done.\n")

# ---- User-facing reminder if LANCES still missing -------------------------
n_avail <- length(present_sources)
n_total <- length(ALL_SOURCES)
if (n_avail < n_total) {
  cat(sprintf("\n  NOTE: %d/%d LANCES files are still Dropbox stubs.\n",
              n_total - n_avail, n_total))
  cat("        To download: in Windows Explorer, navigate to\n")
  cat("        C:\\Users\\dgeni\\Dropbox\\Servidor Belem\\Documents\\Dados BEC\\BEC_Final\\DATABASE\\CSV\\\n")
  cat("        Select all LANCES_*.csv → right-click → 'Always keep on this device'\n")
  cat("        Then re-run this script — already-processed files will be skipped via cache.\n")
}
