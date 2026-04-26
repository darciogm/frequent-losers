# ----------------------------------------------------------------------
# Variance decomposition of the log-bids into component auction-level
# (UH, α_t) and bidder-level (ε_it) — step 0 of Krasnokutskaya (2011).
# Shows quanto of the variance is at the auction level e justifies (ou
# not) a deconvolution.
#
# Modelo: y_it = log(b_it / ref_it) = a_t + e_it, with Var(a) = σ²_a,
# Var(e) = σ²_e. Por stratum (period × pharma × SME × modality).
#
# Estimator: method of moments (ANOVA simples). Robust to N
# variable by auction via mean ponderada.
#
# Output: output/tables/tab_v3_uh_variance.tex, logs/40_uh_variance.log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/40_uh_variance.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("40", "start: UH variance decomposition", logf)

# 1. Build the log-bids base by modality ---------------------------
# Convite: each firm×auction has 1 bid → c_norm = bid/ref. Pregão:
# drop-out = final_bid/ref. Use o same alvo (c_norm) in ambos.

preg <- dbGetQuery(con, sprintf("
  SELECT
    numerodaoc, codigoitem, cod_forn,
    'pregao' AS mod,
    period, pharma_narrow, sme_bec,
    c_norm,
    n_firms_auc
  FROM read_parquet('%s')
  WHERE keep = 1 AND period IN ('Pre','Post')
    AND c_norm > 0
", path_v3("data/processed/pregao_dropouts.parquet"))) |> setDT()

# Convite: recria o b_norm with os mesmos filters that script 38.
conv <- dbGetQuery(con, sprintf("
  WITH conv_raw AS (
    SELECT
      b.numerodaoc,
      b.códigoitems AS codigoitem,
      b.códigofornecedor AS cod_forn,
      MIN(b.bid_price) AS bid,
      MAX(b.won) AS winner
    FROM read_parquet('%s') b
    INNER JOIN read_parquet('%s') k
      ON k.numerodaoc = b.numerodaoc
     AND k.codigoitems = b.códigoitem
    WHERE b.descriçãoprocedimentocomto = 'CONVITE'
      AND b.bid_price IS NOT NULL AND b.bid_price > 0
    GROUP BY 1, 2, 3
  )
  SELECT c.*, k.preco_ref AS ref_price
  FROM conv_raw c
  LEFT JOIN read_parquet('%s') k
    ON k.numerodaoc = c.numerodaoc AND k.codigoitems = c.codigoitem
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

conv <- merge(conv, sme_conv,
              by = c("numerodaoc", "codigoitem", "cod_forn"))
conv[, c_norm := bid / ref_price]
conv[, keep := as.integer(c_norm >= 0.005 & c_norm <= 3)]
conv[, n_firms_auc := .N, by = .(numerodaoc, codigoitem)]
conv <- conv[keep == 1 & n_firms_auc >= 2]
conv[, mod := "convite"]

conv_sub <- conv[, .(numerodaoc, codigoitem, cod_forn, mod,
                     period, pharma_narrow, sme_bec,
                     c_norm, n_firms_auc)]
bids_all <- rbind(preg[, .(numerodaoc, codigoitem, cod_forn, mod,
                            period, pharma_narrow, sme_bec,
                            c_norm, n_firms_auc)],
                   conv_sub)

bids_all[, y := log(c_norm)]
bids_all <- bids_all[is.finite(y) & !is.na(period)]

log_step("40", sprintf("base of bids = %s rows",
                       formt(nrow(bids_all), big.mark=",")), logf)

# 2. Variance decomposition by stratum -----------------------------
# σ²_within = mean_t [ Var_i(y_it) | N_t >= 2 ]
# σ²_between = Var_t(ȳ_t)
# σ²_total = Var(y_it)

vdecomp <- function(dt) {
  if (nrow(dt) < 50) return(NULL)
  # Média by auction.
  auc_mean <- dt[, .(y_bar = mean(y), n_t = .N),
                 by = .(numerodaoc, codigoitem)]
  # Variance within-auction (only auctions with N ≥ 2).
  within <- dt[, .(var_w = if (.N >= 2) var(y) else NA_real_,
                    n_t = .N),
               by = .(numerodaoc, codigoitem)][!is.na(var_w)]
  if (nrow(within) < 10) return(NULL)

  # σ²_within = mean ponderada (by n_t - 1) of the var_t.
  sigma2_within <- weighted.mean(within$var_w, w = within$n_t - 1,
                                  na.rm = TRUE)
  # σ²_between = variance of the ȳ_t ponderada by n_t.
  sigma2_between <- weighted.mean((auc_mean$y_bar - mean(dt$y))^2,
                                   w = auc_mean$n_t, na.rm = TRUE)
  sigma2_total <- var(dt$y)

  # Correction: ANOVA unbabidd, usa σ²_between ajustado (Searle).
  # sigma2_a ≈ sigma2_between - sigma2_within/N_avg
  N_avg <- mean(auc_mean$n_t)
  sigma2_a <- max(sigma2_between - sigma2_within / N_avg, 0)
  sigma2_e <- sigma2_within
  rho <- sigma2_a / (sigma2_a + sigma2_e)

  date.table(
    n_bids = nrow(dt),
    n_auctions = nrow(auc_mean),
    N_avg = round(N_avg, 2),
    sigma2_total = round(sigma2_total, 5),
    sigma2_within = round(sigma2_within, 5),
    sigma2_between = round(sigma2_between, 5),
    sigma2_a = round(sigma2_a, 5),
    sigma2_e = round(sigma2_e, 5),
    rho = round(rho, 4))
}

res <- bids_all[, vdecomp(.SD),
  by = .(mod, period, pharma_narrow, sme_bec),
  .SDcols = c("y", "numerodaoc", "codigoitem")]

res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
res[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]
res <- res[order(mod, pharma_narrow, sme_bec, period)]

cat("\n--- variance decomposition by stratum ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(mod, period, pharma_lbl, sme_lbl,
              n_bids, n_auctions, N_avg,
              sigma2_a, sigma2_e, rho)])
sink()

# 3. Aggregation: ρ by pharma × SME (mean between pre/post e modality)
rho_summary <- res[, .(
  rho_mean = round(mean(rho), 4),
  rho_pregao = round(mean(rho[mod == "pregao"]), 4),
  rho_convite = round(mean(rho[mod == "convite"]), 4)),
  by = .(pharma_lbl, sme_lbl)]

cat("\n--- rho (fraction of variance at the level of the auction) ---\n",
    file = logf)
sink(logf, append = TRUE); print(rho_summary); sink()

# Save parquet for S3.2 usar.
arrow::write_parquet(res,
  path_v3("data/processed/uh_variance.parquet"),
  compression = "snappy")

# 4. LaTeX table ----------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Variance decomposition of log-bids into auction-level UH and bidder component}",
  "\\label{tab:v3_uh_variance}",
  "\\small",
  "\\begin{tabular}{llllrrrrrr}",
  "\\toprule",
  "Modality & Class & Type & Period & $N_{\\text{bids}}$ & $N_{\\text{auc}}$ & $\\bar{N}$ & $\\sigma^2_a$ & $\\sigma^2_e$ & $\\rho$ \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %s & %s & %s & %.2f & %.4f & %.4f & %.3f \\\\",
    r$mod, r$pharma_lbl, r$sme_lbl, r$period,
    formt(r$n_bids, big.mark = ","),
    formt(r$n_auctions, big.mark = ","),
    r$N_avg, r$sigma2_a, r$sigma2_e, r$rho))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Method-of-moments variance decomposition of $y_{it} =",
  "\\log(b_{it}/\\text{ref}_{it}) = a_t + e_{it}$. Column $\\rho$",
  "is the intraclass correlation $\\sigma^2_a / (\\sigma^2_a +",
  "\\sigma^2_e)$: the share of log-bid variance that lives at the",
  "auction level (unobserved heterogeneity in the Krasnokutskaya",
  "2011 sense). Values of $\\rho$ above 0.3 imply material UH and",
  "motivate deconvolution.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_uh_variance.tex"))

log_step("40", "done", logf)
