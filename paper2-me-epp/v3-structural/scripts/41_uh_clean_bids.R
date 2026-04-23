# S3 / task 41 -------------------------------------------------------
# Shrinkage BLP para separar y_it = a_t + e_it em UH auction-level
# (a_t) e componente bidder-specific (e_it). Método dos momentos +
# best linear predictor:
#
#   â_t = σ²_a · N_t / (σ²_a · N_t + σ²_e) · (ȳ_t - μ̄_y)
#   ê_it = y_it - â_t
#
# Isso é a versão semi-paramétrica de Krasnokutskaya (2011): assume
# a_t e e_it gaussianos (BLP é ótimo sob Gauss; aceito como
# aproximação). O full Kotlarski vem no script 43 como robustez.
#
# Saída: data/processed/bids_uh_cleaned.parquet

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/41_uh_clean_bids.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("41", "start: BLP shrinkage UH cleaning", logf)

# 1. Base unificada Convite + Pregão ---------------------------------
preg <- dbGetQuery(con, sprintf("
  SELECT
    numerodaoc, codigoitem, cod_forn,
    'pregao' AS mod,
    period, pharma_narrow, sme_bec,
    c_norm, n_firms_auc,
    ref_price, final_bid AS raw_bid, role
  FROM read_parquet('%s')
  WHERE keep = 1 AND period IN ('Pre','Post')
    AND c_norm > 0
", path_v3("data/processed/pregao_dropouts.parquet"))) |> setDT()

# Convite (mesmo pull que script 38/40)
conv <- dbGetQuery(con, sprintf("
  WITH conv_raw AS (
    SELECT
      b.numerodaoc,
      b.códigoitem AS codigoitem,
      b.códigofornecedor AS cod_forn,
      MIN(b.bid_price) AS bid,
      MAX(b.won) AS winner
    FROM read_parquet('%s') b
    INNER JOIN read_parquet('%s') k
      ON k.numerodaoc = b.numerodaoc AND k.codigoitem = b.códigoitem
    WHERE b.descriçãoprocedimentocompra = 'CONVITE'
      AND b.bid_price IS NOT NULL AND b.bid_price > 0
    GROUP BY 1, 2, 3
  )
  SELECT c.*, k.preco_ref AS ref_price
  FROM conv_raw c
  LEFT JOIN read_parquet('%s') k
    ON k.numerodaoc = c.numerodaoc AND k.codigoitem = c.codigoitem
",
  "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet",
  path_v3("data/processed/g65_keys.parquet"),
  path_v3("data/processed/g65_keys.parquet"))) |> setDT()

sme_conv <- dbGetQuery(con, sprintf("
  SELECT DISTINCT numerodaoc, codigoitem, cod_forn,
         period, pharma_narrow, sme_bec
  FROM read_parquet('%s')
  WHERE mod = 'convite' AND period IN ('Pre','Post')
", path_v3("data/processed/bid_level_sme_pharma_g65.parquet"))) |> setDT()

conv <- merge(conv, sme_conv, by = c("numerodaoc", "codigoitem", "cod_forn"))
conv[, c_norm := bid / ref_price]
conv[, keep := as.integer(c_norm >= 0.005 & c_norm <= 3)]
conv[, n_firms_auc := .N, by = .(numerodaoc, codigoitem)]
conv <- conv[keep == 1 & n_firms_auc >= 2]
conv[, mod := "convite"]
conv[, role := fifelse(winner == 1, "winner", "loser")]
conv[, raw_bid := bid]

bids <- rbind(
  preg[, .(numerodaoc, codigoitem, cod_forn, mod,
            period, pharma_narrow, sme_bec,
            c_norm, n_firms_auc, ref_price, raw_bid, role)],
  conv[, .(numerodaoc, codigoitem, cod_forn, mod,
            period, pharma_narrow, sme_bec,
            c_norm, n_firms_auc, ref_price, raw_bid, role)])

bids[, y := log(c_norm)]
bids <- bids[is.finite(y)]

log_step("41", sprintf("bids = %s rows",
                       format(nrow(bids), big.mark = ",")), logf)

# 2. Carrega σ²_a, σ²_e por estrato ----------------------------------
vdec <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow, sme_bec, sigma2_a, sigma2_e
  FROM read_parquet('%s')
", path_v3("data/processed/uh_variance.parquet"))) |> setDT()

# Fallback: se σ²_a < 0.01 (pouca UH ou sample pequeno), zera
# shrinkage e mantém raw.
vdec[, sigma2_a_eff := pmax(sigma2_a, 0.001)]

bids <- merge(bids, vdec,
              by = c("mod", "period", "pharma_narrow", "sme_bec"),
              all.x = TRUE)

# 3. Média geral e média por leilão ---------------------------------
bids[, mu_y := mean(y, na.rm = TRUE),
     by = .(mod, period, pharma_narrow, sme_bec)]
bids[, y_bar := mean(y, na.rm = TRUE),
     by = .(numerodaoc, codigoitem)]
bids[, n_t := .N, by = .(numerodaoc, codigoitem)]

# 4. BLP estimate de â_t --------------------------------------------
# â_t = (σ²_a · N_t) / (σ²_a · N_t + σ²_e) · (ȳ_t - μ̄)
bids[, a_hat := (sigma2_a_eff * n_t) /
                (sigma2_a_eff * n_t + sigma2_e) *
                (y_bar - mu_y)]
bids[, y_clean := y - a_hat]
bids[, c_norm_clean := exp(y_clean)]

# 5. Sanity: variância do residual clean deve bater com σ²_e --------
check <- bids[, .(
  var_raw = round(var(y), 4),
  var_clean = round(var(y_clean), 4),
  sigma2_e_target = round(mean(sigma2_e), 4),
  var_a_hat = round(var(a_hat), 4),
  sigma2_a_target = round(mean(sigma2_a), 4)),
  by = .(mod, period, pharma_narrow, sme_bec)]

cat("\n--- sanity: var(y) vs var(y_clean) vs σ²_e target ---\n",
    file = logf)
sink(logf, append = TRUE); print(check); sink()

# 6. Salva --------------------------------------------------------
out <- bids[, .(numerodaoc, codigoitem, cod_forn, mod,
                 period, pharma_narrow, sme_bec,
                 c_norm, c_norm_clean,
                 y, y_clean, a_hat,
                 n_firms_auc, ref_price, raw_bid, role)]

arrow::write_parquet(out,
  path_v3("data/processed/bids_uh_cleaned.parquet"),
  compression = "snappy")

log_step("41", "done", logf)
