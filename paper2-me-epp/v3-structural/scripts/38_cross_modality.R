# S2 / task 38 -------------------------------------------------------
# Compara F_c recuperado em Convite (GPV point-ID em FPSB) com o F_c
# recuperado em Pregão (drop-out point-ID em English-reverse) + HT
# bounds. Se os dois se sobrepõem, o modelo estrutural resiste ao
# teste de modalidade — argumento central para ReStud/QJE.
#
# Em v2 esse painel (fig_v2_ht_vs_convite.pdf, script 37 linha ~332)
# quebrou por erro de scoping no ggplot. Aqui refaço limpo.
#
# GPV em Convite (Guerre-Perrigne-Vuong 2000) para procurement:
#   c_i = b_i - (1 - G(b_i)) / ((N - 1) * g(b_i))
# onde G e g são CDF e densidade dos lances no estrato.
#
# Saídas:
#   data/processed/convite_fc.parquet  — F_c^k Convite (GPV)
#   output/tables/tab_v3_cross_modality.tex
#   output/figures/fig_v3_cross_modality.pdf

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({ library(ggplot2) })

logf <- file(path_v3("logs/38_cross_modality.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("38", "start: cross-modality Convite vs Pregão", logf)

# 1. Convite bid-level -----------------------------------------------
# bid_level_with_prices tem bid_price; ref_price vem de g65_keys.
bid_prices_path <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet"
keys_path       <- path_v3("data/processed/g65_keys.parquet")
sme_path        <- path_v3("data/processed/bid_level_sme_pharma_g65.parquet")

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
      ON k.numerodaoc = b.numerodaoc
     AND k.codigoitem = b.códigoitem
    WHERE b.descriçãoprocedimentocompra = 'CONVITE'
      AND b.bid_price IS NOT NULL
      AND b.bid_price > 0
    GROUP BY 1, 2, 3
  )
  SELECT c.*, k.preco_ref AS ref_price
  FROM conv_raw c
  LEFT JOIN read_parquet('%s') k
    ON k.numerodaoc = c.numerodaoc AND k.codigoitem = c.codigoitem
", bid_prices_path, keys_path, keys_path)) |> setDT()

log_step("38", sprintf("Convite firm×auction = %s",
                       format(nrow(conv), big.mark = ",")), logf)

# Join com SME + pharma + período.
sme_conv <- dbGetQuery(con, sprintf("
  SELECT DISTINCT
    numerodaoc, codigoitem, cod_forn,
    period, pharma_narrow, sme_bec
  FROM read_parquet('%s')
  WHERE mod = 'convite' AND period IN ('Pre','Post')
", sme_path)) |> setDT()

conv <- merge(conv, sme_conv,
              by = c("numerodaoc", "codigoitem", "cod_forn"))
conv[, b_norm := bid / ref_price]
conv[, keep := as.integer(b_norm >= 0.005 & b_norm <= 3)]
conv[, n_firms_auc := .N, by = .(numerodaoc, codigoitem)]

conv_ok <- conv[keep == 1 & n_firms_auc >= 2]
log_step("38", sprintf("Convite filtered = %s",
                       format(nrow(conv_ok), big.mark = ",")), logf)

# 2. GPV inversion em Convite ---------------------------------------
# Estratifico por (period, pharma, sme_bec, N-bin).
conv_ok[, n_bin := fcase(
  n_firms_auc == 2, "2",
  n_firms_auc == 3, "3",
  n_firms_auc == 4, "4",
  n_firms_auc >= 5, "5+",
  default = NA_character_)]

gpv_invert <- function(b, N_val, h_factor = 1) {
  b <- b[!is.na(b) & b > 0]
  n <- length(b)
  if (n < 50) return(NULL)
  # Silverman bandwidth em log-bids.
  h <- h_factor * 1.06 * sd(b) * n^(-1/5)
  # Density and CDF via kernel-smoothed empirical.
  dens <- density(b, bw = h, n = 512, from = min(b) * 0.5, to = max(b) * 1.2)
  g_fun <- approxfun(dens$x, dens$y, rule = 2)
  F_emp <- ecdf(b)
  c_hat <- b - (1 - F_emp(b)) / ((N_val - 1) * g_fun(b))
  # Trim obs onde g(b) é quase zero (rabo longo).
  ok <- is.finite(c_hat) & c_hat > 0 & c_hat < b
  data.table(b_norm = b[ok], c_norm = c_hat[ok])
}

c_grid <- seq(0.005, 2, by = 0.005)

conv_fc_rows <- list()
for (per in c("Pre", "Post")) {
  for (ph in c(0, 1)) {
    for (sm in c(0, 1)) {
      for (nb in c("2", "3", "4", "5+")) {
        sub <- conv_ok[period == per & pharma_narrow == ph &
                       sme_bec == sm & n_bin == nb]
        if (nrow(sub) < 100) next
        N_val <- mean(sub$n_firms_auc)
        inv <- gpv_invert(sub$b_norm, N_val)
        if (is.null(inv) || nrow(inv) < 50) next
        F_c <- ecdf(inv$c_norm)(c_grid)
        conv_fc_rows[[length(conv_fc_rows) + 1]] <- data.table(
          c = c_grid, F_c = F_c,
          period = per, pharma_narrow = ph, sme_bec = sm,
          n_bin = nb, n = nrow(sub), N_mean = N_val)
      }
    }
  }
}
conv_fc <- rbindlist(conv_fc_rows)

# Agrega cross-N com peso proporcional ao n.
conv_fc_agg <- conv_fc[,
  .(F_c = sum(F_c * n) / sum(n), n = sum(n)),
  by = .(period, pharma_narrow, sme_bec, c)]
conv_fc_agg[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
conv_fc_agg[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]
conv_fc_agg[, source     := "Convite CPV"]

arrow::write_parquet(conv_fc_agg,
  path_v3("data/processed/convite_fc.parquet"),
  compression = "snappy")

# 3. Carrega o F_c Pregão (losers point-ID) e bounds HT -------------
preg_fc <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c, F_c,
         pharma_lbl, sme_lbl
  FROM read_parquet('%s')
  WHERE method = 'losers_point' AND period IN ('Pre','Post')
", path_v3("data/processed/pregao_fc.parquet"))) |> setDT()
preg_fc[, source := "Pregão drop-out"]

ht <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, c, F_LB, F_UB, pharma_lbl
  FROM read_parquet('%s')
  WHERE period IN ('Pre','Post')
", path_v3("data/processed/pregao_ht_bounds.parquet"))) |> setDT()

# 4. Painel de overlay ----------------------------------------------
# Um painel por pharma × SME-type × período (2 × 2 × 2 = 8).
fc_merged <- rbind(
  conv_fc_agg[, .(period, pharma_lbl, sme_lbl, c, F_c, source)],
  preg_fc[,    .(period, pharma_lbl, sme_lbl, c, F_c, source)])

# Add HT band (pharma-level, não separa SME) como banda comum.
fc_merged[, panel := paste(pharma_lbl, sme_lbl, sep = " / ")]
ht[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

p <- ggplot() +
  geom_ribbon(data = ht,
              aes(x = c, ymin = F_LB, ymax = F_UB, fill = period),
              alpha = 0.18) +
  geom_line(data = fc_merged,
            aes(x = c, y = F_c, color = period, linetype = source),
            linewidth = 0.42) +
  facet_grid(sme_lbl ~ pharma_lbl) +
  scale_color_manual(values = c("Pre" = "black", "Post" = "grey40")) +
  scale_fill_manual (values = c("Pre" = "grey30", "Post" = "grey70")) +
  scale_linetype_manual(values = c(
    "Convite CPV"       = "solid",
    "Pregão drop-out" = "dashed")) +
  coord_cartesian(xlim = c(0, 1.5), ylim = c(0, 1)) +
  labs(x = "c / reference price", y = expression(F[c](c)),
       color = "", fill = "", linetype = "",
       title = "Cross-modality validation: Convite CPV vs Preg\\~ao drop-out (with HT band)") +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "bottom",
        legend.box = "vertical")

ggsave(path_v3("output/figures/fig_v3_cross_modality.pdf"),
       p, width = 8, height = 5.2, device = cairo_pdf)

# 5. Tabela: median F_c por modalidade × estrato ----------------------
med_tab <- rbind(
  conv_fc_agg[, .(
    source = "Convite (GPV)",
    c_p50 = round(approx(F_c, c, xout = 0.5, rule = 2)$y, 4),
    c_p75 = round(approx(F_c, c, xout = 0.75, rule = 2)$y, 4)),
  by = .(pharma_lbl, sme_lbl, period)],
  preg_fc[, .(
    source = "Pregão (drop-out)",
    c_p50 = round(approx(F_c, c, xout = 0.5, rule = 2)$y, 4),
    c_p75 = round(approx(F_c, c, xout = 0.75, rule = 2)$y, 4)),
  by = .(pharma_lbl, sme_lbl, period)])

med_tab <- med_tab[order(pharma_lbl, sme_lbl, period, source)]

cat("\n--- median F_c por modalidade ---\n", file = logf)
sink(logf, append = TRUE); print(med_tab); sink()

tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Cross-modality $F_c$ quantiles: Convite CPV vs Preg\\~ao drop-out}",
  "\\label{tab:v3_cross_modality}",
  "\\small",
  "\\begin{tabular}{lllll rr}",
  "\\toprule",
  "Class & Type & Period & Modality & Source & $c_{0.50}$ & $c_{0.75}$ \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(med_tab))) {
  r <- med_tab[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %s & & %.3f & %.3f \\\\",
    r$pharma_lbl, r$sme_lbl, r$period, r$source,
    r$c_p50, r$c_p75))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Cost quantile estimates (c / ref) from two independent",
  "structural strategies: Guerre-Perrigne-Vuong inversion on",
  "Convite sealed-bid auctions, and English-reverse drop-out",
  "point-ID on Preg\\~ao iterative auctions. Convergence of the two",
  "across strata is a cross-modality specification test for the",
  "structural model.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_cross_modality.tex"))

log_step("38", "done", logf)
