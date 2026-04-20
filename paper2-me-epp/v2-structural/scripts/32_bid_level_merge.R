# ============================================================================
# 32_bid_level_merge.R — v2-structural sprint 0
# ============================================================================
# Build the bid-level analytical dataset for the structural pipeline.
#
# Inputs:
#   (1) bid-level:   paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet
#                    (39.96M bids, 2009-2019, schema: numerodaoc, códigoitem,
#                     códigofornecedor, descriçãoprocedimentocompra, bid_price,
#                     won, negot_price, ref_price, etc.)
#   (2) Paper-2 keys: /tmp/p2_keys.parquet  (built by _extract_p2_keys.py)
#                    (902,273 POIs in Sep 2016 - Aug 2019 window, with
#                     codigogrupo, codigoclasse, data_oc_numb)
#   (3) Firms_final: paper3-frequent-losers/data/processed/Firms_final.parquet
#                    (39,632 firm registry entries with CNAE, porte_empresa,
#                     fornec_enquad — used as per-bidder SME proxy).
#
# Outputs (in v2-structural/data/processed/):
#   - bid_level_convite.parquet  — Convite subset (G65 + 76 controls, 18m)
#   - bid_level_pregao.parquet   — Pregão subset (G65 + 76 controls, 18m)
#   - bid_level_merged.parquet   — union of the above (for joint descriptives)
#
# Each output row = one bid. Columns:
#   numerodaoc, codigoitem, codigofornecedor (bidder CNPJ), bid_price,
#   won (0/1 winner flag), negot_price, ref_price,
#   modality,                                    # CONVITE / PREGÃO
#   codigogrupo, codigoclasse, data_oc_numb,      # from Paper 2 keyset
#   g65 (1 if codigogrupo==65),
#   Pre (1 if data_oc_numb < 698 = March 2018),
#   pharma (1 if codigoclasse == 6531),
#   porte_bidder, enquad_bidder, cnae_bidder,    # from Firms_final
#   sme_proxy (1 if porte_empresa in '01' OR enquad in {1,2}; imperfect!)
#
# Gap documented: true per-auction self-declared me_epp flag is NOT in the
# bid-level source. `sme_proxy` uses firm-registry classification as a
# constant-over-time proxy. S1 decision: either re-extract raw CSV to get
# bid-level me_epp, or accept firm-registry SME as structural feature.
# ============================================================================

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils_v2.R"), local = TRUE)

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

log_msg("=== 32_bid_level_merge.R — sprint 0 ===")
log_mem("startup")

# ---- ensure keyset exists --------------------------------------------------
ensure_p2_keys()
log_msg("keyset: ", P2_KEYS_CACHE)

# ---- do all the work in DuckDB (out-of-core, saturates 12 threads) --------
with_duckdb(function(con) {

  log_msg("Building merged bid-level table in DuckDB...")

  # Base join: bid-level ⨝ p2_keys → get (group, class, date) per bid.
  # INNER JOIN restricts to the 18-month Paper-2 window + its item universe.
  dbExecute(con, sprintf("
    CREATE OR REPLACE TABLE base AS
    SELECT
      b.numerodaoc,
      b.códigoitem                       AS codigoitem,
      b.códigofornecedor                 AS codigofornecedor,
      b.bid_price,
      b.won::INTEGER                     AS won,
      b.negot_price,
      b.ref_price,
      b.descriçãoprocedimentocompra      AS modality,
      b.códigounidadecompradora          AS codigopbu,
      b.mêsanoencerramento               AS mes_ano,
      k.codigogrupo,
      k.codigoclasse,
      k.data_oc_numb
    FROM read_parquet('%s') b
    INNER JOIN read_parquet('%s') k
      ON b.numerodaoc = k.numerodaoc
     AND b.códigoitem = k.codigoitem
  ", BID_LEVEL_SRC, P2_KEYS_CACHE))

  n_base <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM base")$n
  log_msg(sprintf("  base bid-level rows (G65 + 76 controls, 18m window): %s",
                  format(n_base, big.mark = ",")))

  # Add firm-level SME proxy from Firms_final.
  # Classification rule (policy-proxy; imperfect — documented as S1 gap):
  #   LC 123/2006 defines SME as ME (revenue <= R$360k) OR EPP (revenue <= R$4.8M).
  #   Receita Federal porte_empresa coding:
  #     '00' = não informado
  #     '01' = ME
  #     '03' = EPP
  #     '05' = demais (médio/grande)
  #   We code sme_proxy = 1 if porte_empresa in {'01', '03'} (ME + EPP),
  #     OR fornec_enquad in {1, 2} (BEC SME codes).
  #   sme_proxy = 0 otherwise (demais, NA => conservative 0).
  #   Note: the *canonical* per-auction me_epp is a self-declaration in BEC
  #   that the bid-level source lacks; sme_proxy is a firm-registry proxy.
  dbExecute(con, sprintf("
    CREATE OR REPLACE TABLE firms_reg AS
    SELECT
      códigofornecedor                                AS codigofornecedor,
      porte_empresa                                   AS porte_bidder,
      TRY_CAST(fornec_enquad AS INTEGER)              AS enquad_bidder,
      secao_cnae                                      AS secao_bidder,
      cnae_resum_code                                 AS cnae_resum_bidder,
      fornec_estado_SP                                AS in_sp,
      CASE
        WHEN porte_empresa IN ('01', '03') THEN 1
        WHEN TRY_CAST(fornec_enquad AS INTEGER) IN (1, 2) THEN 1
        ELSE 0
      END                                             AS sme_proxy
    FROM read_parquet('%s')
  ", FIRMS_SRC))

  n_firms <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM firms_reg")$n
  log_msg(sprintf("  firms_reg: %s rows", format(n_firms, big.mark = ",")))

  # Final merged table with derived flags.
  dbExecute(con, "
    CREATE OR REPLACE TABLE merged AS
    SELECT
      b.numerodaoc,
      b.codigoitem,
      b.codigopbu,
      b.codigofornecedor,
      b.bid_price,
      b.won,
      b.negot_price,
      b.ref_price,
      b.modality,
      b.mes_ano,
      b.codigogrupo,
      b.codigoclasse,
      b.data_oc_numb,
      CASE WHEN b.codigogrupo = 65      THEN 1 ELSE 0 END AS g65,
      CASE WHEN b.data_oc_numb < 698    THEN 1 ELSE 0 END AS Pre,
      CASE WHEN b.codigoclasse = 6531   THEN 1 ELSE 0 END AS pharma,
      f.porte_bidder,
      f.enquad_bidder,
      f.secao_bidder,
      f.cnae_resum_bidder,
      f.in_sp,
      COALESCE(f.sme_proxy, 0) AS sme_proxy
    FROM base b
    LEFT JOIN firms_reg f USING (codigofornecedor)
  ")

  # Sanity: bidders without firm-registry match
  n_unmatched <- dbGetQuery(con, "
    SELECT COUNT(*) AS n FROM merged WHERE porte_bidder IS NULL
  ")$n
  n_total <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM merged")$n
  log_msg(sprintf("  bidders w/o firm-registry match: %s / %s (%.1f%%)",
                  format(n_unmatched, big.mark = ","),
                  format(n_total,     big.mark = ","),
                  100 * n_unmatched / n_total))

  # ---- split by modality and write --------------------------------------
  out_convite <- file.path(V2_DATA, "bid_level_convite.parquet")
  out_pregao  <- file.path(V2_DATA, "bid_level_pregao.parquet")
  out_merged  <- file.path(V2_DATA, "bid_level_merged.parquet")

  dir.create(V2_DATA, showWarnings = FALSE, recursive = TRUE)

  dbExecute(con, sprintf("
    COPY (SELECT * FROM merged WHERE modality = '%s')
    TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy');
  ", MODALITY_CONVITE, out_convite))

  dbExecute(con, sprintf("
    COPY (SELECT * FROM merged WHERE modality = '%s')
    TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy');
  ", MODALITY_PREGAO, out_pregao))

  dbExecute(con, sprintf("
    COPY (SELECT * FROM merged WHERE modality IN ('%s', '%s'))
    TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy');
  ", MODALITY_CONVITE, MODALITY_PREGAO, out_merged))

  # ---- diagnostics ------------------------------------------------------
  log_msg("")
  log_msg("=== Diagnostics ===")

  diag <- dbGetQuery(con, "
    SELECT modality,
           CASE WHEN g65 = 1 THEN 'G65' ELSE 'Controls' END AS arm,
           Pre,
           COUNT(*)                                        AS n_bids,
           COUNT(DISTINCT numerodaoc||'/'||codigoitem)     AS n_auctions,
           COUNT(DISTINCT codigofornecedor)                AS n_firms,
           ROUND(SUM(CAST(sme_proxy AS INT))*100.0/COUNT(*), 2) AS pct_sme,
           ROUND(SUM(won)*100.0/NULLIF(COUNT(DISTINCT numerodaoc||'/'||codigoitem), 0), 2) AS pct_with_winner
    FROM merged
    WHERE modality IN ('CONVITE', 'PRE\u0047\u00c3O ELETR\u00d4NICO')
    GROUP BY modality, arm, Pre
    ORDER BY modality, arm, Pre
  ")
  print(diag)

  # Per-auction bid distribution
  log_msg("")
  log_msg("=== Bid count distribution per auction (Convite vs Pregão, G65) ===")
  dist <- dbGetQuery(con, "
    WITH pa AS (
      SELECT modality, g65, numerodaoc, codigoitem,
             COUNT(*)                         AS n_bids_au,
             COUNT(DISTINCT codigofornecedor) AS n_firms_au
      FROM merged
      WHERE g65 = 1 AND modality IN ('CONVITE', 'PRE\u0047\u00c3O ELETR\u00d4NICO')
      GROUP BY modality, g65, numerodaoc, codigoitem
    )
    SELECT modality,
           COUNT(*)                     AS n_auctions,
           ROUND(AVG(n_firms_au), 2)    AS mean_firms,
           ROUND(MEDIAN(n_firms_au), 2) AS median_firms,
           ROUND(AVG(n_bids_au), 2)     AS mean_bids,
           MAX(n_bids_au)               AS max_bids,
           SUM(CASE WHEN n_firms_au = 1 THEN 1 ELSE 0 END) AS single_firm_auctions,
           SUM(CASE WHEN n_firms_au = 2 THEN 1 ELSE 0 END) AS two_firm_auctions,
           SUM(CASE WHEN n_firms_au >= 5 THEN 1 ELSE 0 END) AS five_plus_firm_auctions
    FROM pa
    GROUP BY modality ORDER BY modality
  ")
  print(dist)

  # File sizes + row counts for final outputs
  log_msg("")
  log_msg("=== Output files ===")
  for (p in c(out_convite, out_pregao, out_merged)) {
    n <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM read_parquet('%s')", p))$n
    sz <- file.info(p)$size / 1024^2
    log_msg(sprintf("  %s: %s rows, %.1f MB",
                    basename(p), format(n, big.mark = ","), sz))
  }
})

log_mem("final")
log_msg("=== 32_bid_level_merge.R: DONE ===")
