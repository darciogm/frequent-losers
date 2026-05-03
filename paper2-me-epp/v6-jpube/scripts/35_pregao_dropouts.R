# S2 / task 35 -------------------------------------------------------
# Pregão G65: extrai o drop-out price (menor lance) por firma×leilão,
# identifica vencedor vs perdedores, normaliza por preço-ref. Sob
# English-reverse IPV (botão descendente), é estratégia fracamente
# dominante cada firma sair do leilão quando o preço atinge seu custo
# — logo o drop-out do perdedor = custo. Ponto de partida da
# identificação de Hong-Shum (2003) e Athey-Haile (2002).
#
# Paper3 bid_level_with_prices.parquet tem os lances iterativos com
# bid_price + flag de vencedor. Média 3.5 bids por firma×leilão em
# Pregão G65 — dados são ricos o suficiente para point-ID.
#
# Saídas:
#   data/processed/pregao_dropouts.parquet
#   logs/35_pregao_dropouts.log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v3("logs/35_pregao_dropouts.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("35", "start: Pregão drop-outs (point-ID input)", logf)

bid_prices_path <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet"
keys_path       <- path_v3("data/processed/g65_keys.parquet")
sme_path        <- path_v3("data/processed/bid_level_sme_pharma_g65.parquet")

# 1. Lances iterativos Pregão G65 -----------------------------------
# bid_level_with_prices tem 62% ref_price NULL (merge incompleto do
# paper3). Pego final_bid (menor lance) + won por firma×leilão direto
# do bid-level, e o ref_price vem do g65_keys.parquet (auction×item
# level, cópia do Paper2 CSV cru). Essa ordem evita perder 60% da
# amostra por falha de merge no paper3.
log_step("35", "agrego bid_level → firma×leilão (drop-out + won)", logf)

drop <- dbGetQuery(con, sprintf("
  WITH pregao AS (
    SELECT
      b.numerodaoc,
      b.códigoitem         AS codigoitem,
      b.códigofornecedor   AS cod_forn,
      b.bid_price,
      b.won
    FROM read_parquet('%s') b
    INNER JOIN read_parquet('%s') k
      ON k.numerodaoc = b.numerodaoc
     AND k.codigoitem = b.códigoitem
    WHERE b.descriçãoprocedimentocompra = 'PREGÃO ELETRÔNICO'
      AND b.bid_price IS NOT NULL
      AND b.bid_price > 0
  ),
  agg AS (
    SELECT
      numerodaoc, codigoitem, cod_forn,
      MIN(bid_price) AS final_bid,
      MAX(won)       AS winner,
      COUNT(*)       AS n_iterations
    FROM pregao
    GROUP BY 1, 2, 3
  )
  SELECT
    a.*,
    k.preco_ref   AS ref_price
  FROM agg a
  LEFT JOIN read_parquet('%s') k
    ON k.numerodaoc = a.numerodaoc
   AND k.codigoitem = a.codigoitem
", bid_prices_path, keys_path, keys_path)) |> setDT()

log_step("35", sprintf("firm×auction rows = %s",
                       format(nrow(drop), big.mark = ",")), logf)

# 2. Enriquecimento com SME + pharma + período ------------------------
sme <- dbGetQuery(con, sprintf("
  SELECT DISTINCT
    numerodaoc, codigoitem, cod_forn, mod, period,
    sme_porte, sme_bec, sme_flag, pharma_narrow, pharma_broad,
    codigoclasse, data_oc_numb
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
", sme_path)) |> setDT()

log_step("35", sprintf("sme rows = %s", format(nrow(sme), big.mark = ",")), logf)

m <- merge(drop, sme,
           by = c("numerodaoc", "codigoitem", "cod_forn"),
           all.x = TRUE)

log_step("35", sprintf("merged rows = %s  (match pct = %.2f)",
                       format(nrow(m), big.mark = ","),
                       mean(!is.na(m$sme_bec)) * 100), logf)

# Filtros básicos e normalização
m <- m[!is.na(sme_bec) & !is.na(ref_price) & !is.na(final_bid)]
m[, c_norm := final_bid / ref_price]

# Tratamento de outliers: mantém [0.005, 3] como v2. Fora disso é
# quase certeza erro de entrada (R$0.01 ou ref_price errado).
m[, keep := as.integer(c_norm >= 0.005 & c_norm <= 3)]
m[, role := fifelse(winner == 1, "winner", "loser")]

cat("\n--- filtros ---\n", file = logf)
sink(logf, append = TRUE)
print(m[, .(n_total = .N,
            n_keep  = sum(keep),
            pct_kept = round(mean(keep) * 100, 2))])

cat("\n--- role × period × pharma × SME (c_norm: mean, sd, p25, p50, p75) ---\n")
print(m[keep == 1 & role == "loser",
  .(bids = .N,
    mean_cnorm = round(mean(c_norm), 4),
    p25 = round(quantile(c_norm, 0.25), 4),
    p50 = round(quantile(c_norm, 0.50), 4),
    p75 = round(quantile(c_norm, 0.75), 4)),
  by = .(period, pharma_narrow, sme_bec)][order(period, pharma_narrow, sme_bec)])

cat("\n--- winners only: c_norm dá upper bound no custo do vencedor ---\n")
print(m[keep == 1 & role == "winner",
  .(winners = .N,
    mean_cnorm = round(mean(c_norm), 4),
    p25 = round(quantile(c_norm, 0.25), 4),
    p50 = round(quantile(c_norm, 0.50), 4),
    p75 = round(quantile(c_norm, 0.75), 4)),
  by = .(period, pharma_narrow, sme_bec)][order(period, pharma_narrow, sme_bec)])
sink()

# 3. Order statistics por leilão (para HT bounds e APV check) ---------
# Preciso de b_(1), b_(2) normalizados — vou passar junto no parquet.
log_step("35", "calculando order statistics do leilão", logf)

m[, `:=`(
  n_firms_auc    = .N,
  n_sme_auc      = sum(sme_bec),
  n_nonsme_auc   = sum(1L - sme_bec)
), by = .(numerodaoc, codigoitem)]

# Ordena e marca o rank do final_bid dentro do leilão.
setorder(m, numerodaoc, codigoitem, final_bid)
m[, rank_bid := seq_len(.N), by = .(numerodaoc, codigoitem)]

# Preenche b_(1), b_(2) por leilão:
aux <- m[keep == 1,
  .(b1 = final_bid[rank_bid == 1][1],
    b2 = final_bid[rank_bid == 2][1]),
  by = .(numerodaoc, codigoitem)]
aux[, `:=`(b1_norm = b1 / NA, b2_norm = b2 / NA)]   # placeholder

m <- merge(m, aux, by = c("numerodaoc", "codigoitem"), all.x = TRUE)
m[, b1_norm := b1 / ref_price]
m[, b2_norm := b2 / ref_price]

out_cols <- c("numerodaoc", "codigoitem", "cod_forn",
              "final_bid", "ref_price", "c_norm",
              "winner", "role", "rank_bid",
              "n_iterations", "keep",
              "mod", "period", "data_oc_numb", "codigoclasse",
              "pharma_narrow", "pharma_broad",
              "sme_porte", "sme_bec", "sme_flag",
              "n_firms_auc", "n_sme_auc", "n_nonsme_auc",
              "b1", "b2", "b1_norm", "b2_norm")

arrow::write_parquet(m[, ..out_cols],
  path_v3("data/processed/pregao_dropouts.parquet"),
  compression = "snappy")

log_step("35", "done", logf)
