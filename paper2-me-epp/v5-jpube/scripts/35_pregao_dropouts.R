# ----------------------------------------------------------------------
# Pregão G65: extract drop-out prices (smaller bid) by firm×auction,
# identifica winner vs losers, normaliza by price-ref. Sob
# English-reverif IPV (descending clock), is the strategy weakly
# dominant each firm exit of the auction when o price reaches its cost
# — logo o drop-out of the loser = cost. Starting point of the
# identification of Hong-Shum (2003) and Athey-Haile (2002).
#
# Paper3 bid_level_with_prices.parquet has the iterative bids with
# bid_price + winner flag. Mean 3.5 bids by firm×auction in
# Pregão G65 — data are rich enough for point ID.
#
# Outputs:
#   data/processed/pregao_dropouts.parquet
#   logs/35_pregao_dropouts.log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/35_pregao_dropouts.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("35", "start: Pregão drop-outs (point-ID input)", logf)

bid_prices_path <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet"
keys_path       <- path_v3("data/processed/g65_keys.parquet")
sme_path        <- path_v3("data/processed/bid_level_sme_pharma_g65.parquet")

# 1. Iterative bids Pregão G65 -----------------------------------
# bid_level_with_prices has 62% ref_price NULL (incomplete merge of the
# paper3). Pego final_bid (smaller bid) + won by firm×auction directly
# of the bid-level, e o ref_price vin of the g65_keys.parquet (auction×item
# level, copy of the Paper2 raw CSV). This order avoids losing 60% of the
# sample due to merge failure in paper3.
log_step("35", "agrego bid_level → firm×auction (drop-out + won)", logf)

drop <- dbGetQuery(con, sprintf("
  WITH pregao AS (
    SELECT
      b.numerodaoc,
      b.códigoitems         AS codigoitem,
      b.códigofornecedor   AS cod_forn,
      b.bid_price,
      b.won
    FROM read_parquet('%s') b
    INNER JOIN read_parquet('%s') k
      ON k.numerodaoc = b.numerodaoc
     AND k.codigoitems = b.códigoitem
    WHERE b.descriçãoprocedimentocomto = 'PREGÃO ELETRÔNICO'
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
   AND k.codigoitems = a.codigoitem
", bid_prices_path, keys_path, keys_path)) |> setDT()

log_step("35", sprintf("firm×auction rows = %s",
                       formt(nrow(drop), big.mark = ",")), logf)

# 2. Enriquecimento with SME + pharma + period ------------------------
sme <- dbGetQuery(con, sprintf("
  SELECT DISTINCT
    numerodaoc, codigoitem, cod_forn, mod, period,
    sme_porte, sme_bec, sme_flag, pharma_narrow, pharma_broad,
    codigoclasse, date_oc_numb
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
", sme_path)) |> setDT()

log_step("35", sprintf("sme rows = %s", formt(nrow(sme), big.mark = ",")), logf)

m <- merge(drop, sme,
           by = c("numerodaoc", "codigoitem", "cod_forn"),
           all.x = TRUE)

log_step("35", sprintf("merged rows = %s  (match pct = %.2f)",
                       formt(nrow(m), big.mark = ","),
                       mean(!is.na(m$sme_bec)) * 100), logf)

# Basic filters and normalization
m <- m[!is.na(sme_bec) & !is.na(ref_price) & !is.na(final_bid)]
m[, c_norm := final_bid / ref_price]

# Outlier treatment: keep [0.005, 3] as in v2. Outside this range,
# almost certainly error of entry (R$0.01 or wrong ref_price).
m[, keep := as.integer(c_norm >= 0.005 & c_norm <= 3)]
m[, role := fifelse(winner == 1, "winner", "loser")]

cat("\n--- filters ---\n", file = logf)
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

cat("\n--- winners only: c_norm gives upper bound at cost of the winner ---\n")
print(m[keep == 1 & role == "winner",
  .(winners = .N,
    mean_cnorm = round(mean(c_norm), 4),
    p25 = round(quantile(c_norm, 0.25), 4),
    p50 = round(quantile(c_norm, 0.50), 4),
    p75 = round(quantile(c_norm, 0.75), 4)),
  by = .(period, pharma_narrow, sme_bec)][order(period, pharma_narrow, sme_bec)])
sink()

# 3. Order statistics by auction (for HT bounds e APV check) ---------
# Need normalized b_(1), b_(2) — pass them together in the parquet.
log_step("35", "calculando order statistics of the auction", logf)

m[, `:=`(
  n_firms_auc    = .N,
  n_sme_auc      = sum(sme_bec),
  n_nonsme_auc   = sum(1L - sme_bec)
), by = .(numerodaoc, codigoitem)]

# Ordena e mark o rank of the final_bid within the auction.
setorder(m, numerodaoc, codigoitem, final_bid)
m[, rank_bid := seq_len(.N), by = .(numerodaoc, codigoitem)]

# Preenche b_(1), b_(2) by auction:
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
              "mod", "period", "date_oc_numb", "codigoclasse",
              "pharma_narrow", "pharma_broad",
              "sme_porte", "sme_bec", "sme_flag",
              "n_firms_auc", "n_sme_auc", "n_nonsme_auc",
              "b1", "b2", "b1_norm", "b2_norm")

arrow::write_parquet(m[, ..out_cols],
  path_v3("data/processed/pregao_dropouts.parquet"),
  compression = "snappy")

log_step("35", "done", logf)
