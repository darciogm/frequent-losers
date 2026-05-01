# ============================================================================
# 55_structural_modal_split.R — P2 structural estimation by modality
# Paper 3 v14 / Major 1 deliverables R3
#
# Question: does Regime 1 (uniform high-dispersion cover bidding) emerge in
# convite-only items, or is Regime 2 (truncated-normal low-dispersion) the
# selected regime in BOTH modalities?
#
# Procedure:
#   1. Load bid-level v14 + item_value_panel for modality
#   2. Compute log_spread = log(bid) - log(winner_bid) for losing FL bids
#   3. For each modal subsample (convite=1 vs pregão=3):
#      - Fit Regime 1: uniform[0, delta_hat]
#      - Fit Regime 2: truncated normal(eps, sigma_c) on positive spreads
#      - BIC compare; report selected regime + sigma_c/sigma_g ratio
#
# Output: output/structural_modal/structural_modal.csv
# ============================================================================

cat("=== 55_structural_modal_split.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(duckdb); library(DBI)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "structural_modal")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load FL classification ------------------------------------------------
fp <- as.data.table(read_parquet(file.path(BASE,"data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
THRESH <- 14L
fp[, is_fl := as.integer(always_loser == 1L & tenders_count > THRESH)]
fl_codes <- fp[is_fl == 1L, firm_code]
cat(sprintf("  FL firms: %s\n", format(length(fl_codes), big.mark=",")))

# ---- Pull bid-level with modality via DuckDB --------------------------------
cat("\n  Pulling bid-level data with modality from DuckDB ...\n")
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

bid_path <- file.path(BASE, "data/processed/bid_level_full_v14.parquet")

# Step 1: get winner bid per item
dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE winners AS
  SELECT
    CAST(\"Numero da OC\" AS VARCHAR) AS numerodaoc,
    CAST(\"Código Item\"  AS VARCHAR) AS codigoitem,
    MIN(TRY_CAST(REPLACE(CAST(\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE)) AS win_price
  FROM read_parquet('%s', union_by_name=true)
  WHERE TRY_CAST(CAST(\"Flag Vencedor\" AS VARCHAR) AS INTEGER) = 1
    AND TRY_CAST(REPLACE(CAST(\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) > 0
  GROUP BY numerodaoc, codigoitem
", bid_path))

# Step 2: pull losing bids with FL flag and modality
dbExecute(con, "CREATE OR REPLACE TEMP TABLE fl_codes_tbl (firm_code VARCHAR)")
dbWriteTable(con, "fl_codes_tbl",
             data.table(firm_code = fl_codes), overwrite = TRUE)

dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE losers AS
  SELECT
    CAST(b.\"Numero da OC\" AS VARCHAR) AS numerodaoc,
    CAST(b.\"Código Item\"  AS VARCHAR) AS codigoitem,
    CAST(b.\"Código Fornecedor\" AS VARCHAR) AS firm_code,
    TRY_CAST(REPLACE(CAST(b.\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) AS bid_price,
    CASE
      WHEN UPPER(b.\"Descrição Procedimento Compra\") = 'CONVITE' THEN 1
      WHEN UPPER(b.\"Descrição Procedimento Compra\") IN
        ('PREGÃO ELETRÔNICO','PREGAO ELETRONICO','PREGÃO','PREGAO') THEN 3
      ELSE NULL
    END AS modality,
    CASE WHEN b.\"Código Fornecedor\" IN
      (SELECT firm_code FROM fl_codes_tbl) THEN 1 ELSE 0 END AS is_fl
  FROM read_parquet('%s', union_by_name=true) b
  WHERE TRY_CAST(CAST(b.\"Flag Vencedor\" AS VARCHAR) AS INTEGER) = 0
    AND TRY_CAST(REPLACE(CAST(b.\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) > 0
", bid_path))

# Merge winners
dbExecute(con, "
  CREATE OR REPLACE TEMP TABLE losers_with_win AS
  SELECT l.*, w.win_price
  FROM losers l
  INNER JOIN winners w
    ON l.numerodaoc = w.numerodaoc AND l.codigoitem = w.codigoitem
  WHERE w.win_price > 0
")

bid_data <- as.data.table(dbGetQuery(con, "
  SELECT bid_price, win_price, is_fl, modality
  FROM losers_with_win
  WHERE modality IS NOT NULL
"))
dbDisconnect(con, shutdown = TRUE)
cat(sprintf("  Loaded %s bid-level losing rows with modality\n",
            format(nrow(bid_data), big.mark = ",")))

bid_data[, log_bid := log(bid_price)]
bid_data[, log_win := log(win_price)]
bid_data[, log_spread := log_bid - log_win]

# ---- Per-modality structural estimation ----------------------------------
fit_regimes <- function(d, mod_label) {
  cat(sprintf("\n=== %s (n=%s) ===\n", mod_label, format(nrow(d), big.mark = ",")))

  genuine <- d[is_fl == 0L]
  fl <- d[is_fl == 1L]
  fl_pos <- fl[log_spread > 0 & is.finite(log_spread)]
  nonfl_pos <- genuine[log_spread > 0 & is.finite(log_spread)]

  cat(sprintf("  N genuine: %s; N FL: %s; N FL above-winner: %s\n",
              format(nrow(genuine), big.mark=","),
              format(nrow(fl), big.mark=","),
              format(nrow(fl_pos), big.mark=",")))

  if (nrow(fl_pos) < 100) {
    cat("    Insufficient FL above-winner observations\n")
    return(NULL)
  }

  # Stage 1: Genuine bid distribution (sigma_g)
  if (nrow(genuine) >= 100) {
    sigma_g <- sd(genuine$log_bid)
  } else {
    sigma_g <- NA_real_
  }

  # Regime 1: Uniform[0, delta]
  delta_hat <- as.numeric(quantile(fl_pos$log_spread, 0.99))
  n_r1 <- nrow(fl_pos)
  ll_r1 <- -n_r1 * log(delta_hat)
  bic_r1 <- -2 * ll_r1 + 1 * log(n_r1)

  # Regime 2: Normal(eps, sigma_c^2)
  eps_hat <- mean(fl_pos$log_spread)
  sig_c <- sd(fl_pos$log_spread)
  ll_r2 <- sum(dnorm(fl_pos$log_spread, eps_hat, sig_c, log = TRUE))
  bic_r2 <- -2 * ll_r2 + 2 * log(n_r1)

  selected <- if (bic_r1 < bic_r2) "Regime 1" else "Regime 2"
  delta_bic <- bic_r2 - bic_r1

  cat(sprintf("  R1: delta=%.4f, LL=%.1f, BIC=%.1f\n",
              delta_hat, ll_r1, bic_r1))
  cat(sprintf("  R2: eps=%.4f, sigma_c=%.4f, LL=%.1f, BIC=%.1f\n",
              eps_hat, sig_c, ll_r2, bic_r2))
  cat(sprintf("  Selected: %s (delta_BIC = %.0f)\n",
              selected, delta_bic))
  cat(sprintf("  sigma_c/sigma_g ratio: %.3f\n",
              sig_c / sigma_g))

  data.table(
    modality      = mod_label,
    n_genuine     = nrow(genuine),
    n_fl          = nrow(fl),
    n_fl_pos      = nrow(fl_pos),
    sigma_g       = sigma_g,
    delta_hat_r1  = delta_hat,
    loglik_r1     = ll_r1,
    bic_r1        = bic_r1,
    eps_hat_r2    = eps_hat,
    sigma_c_r2    = sig_c,
    loglik_r2     = ll_r2,
    bic_r2        = bic_r2,
    selected      = selected,
    delta_bic     = delta_bic,
    sig_c_to_sig_g_ratio = sig_c / sigma_g
  )
}

results <- rbindlist(list(
  fit_regimes(bid_data,                          "full_sample"),
  fit_regimes(bid_data[modality == 1L],          "convite_only"),
  fit_regimes(bid_data[modality == 3L],          "pregao_only")
), fill = TRUE)

fwrite(results, file.path(OUT, "structural_modal.csv"))
cat(sprintf("\n  Wrote: %s\n", file.path(OUT, "structural_modal.csv")))
print(results[, .(modality, n_fl_pos, selected, delta_bic,
                   sig_c_to_sig_g_ratio = round(sig_c_to_sig_g_ratio, 3))])

cat("\n  Done.\n")
