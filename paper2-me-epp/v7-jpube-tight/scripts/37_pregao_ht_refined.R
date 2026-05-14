# S2 / task 37 -------------------------------------------------------
# Bounds Haile-Tamer (2003) refinados para Pregão. Comparados com a
# identificação point via drop-outs (script 36), a banda HT serve de
# sanidade: o F_c estimado por point-ID deve cair dentro da banda
# [F_LB, F_UB]. Se cair fora, ou o modelo English-reverse não vale
# (firmas não estavam saindo no custo) ou há problema de dados.
#
# HT bounds no FPSB (Haile-Tamer 2003, sec 3):
#   Lower: F_LB(c) = 1 - (1 - F_b1(c))^{1/N}
#   Upper: F_UB(c) = F_b2(c)  (distribuição de b_(2) serve como upper)
# em que F_b1, F_b2 são as CDFs do primeiro e segundo menor lance.
#
# No Pregão, final bids ≠ lances iniciais, então as bounds são tight
# quando a dispersão entre b_(1) e b_(2) é pequena (competição forte).
#
# Saídas:
#   data/processed/pregao_ht_bounds.parquet
#   output/tables/tab_v3_pregao_ht_refined.tex
#   output/figures/fig_v3_pregao_ht_bands.pdf

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

suppressPackageStartupMessages({ library(ggplot2) })

logf <- file(path_v3("logs/37_pregao_ht_refined.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("37", "start: Pregão HT bounds refinados", logf)

# Trabalho a nível auction (uma row por numerodaoc × codigoitem).
# Extraio b_(1) e b_(2) normalizados pelo ref_price. Stratifico por
# período e pharma. Para SME vs non-SME preciso ter os dois tipos
# competindo no mesmo leilão — relaxo isso para asymmetric bounds em
# S3.

au <- dbGetQuery(con, sprintf("
  SELECT DISTINCT
    numerodaoc, codigoitem,
    period, pharma_narrow,
    n_firms_auc, n_sme_auc, n_nonsme_auc,
    b1_norm, b2_norm
  FROM read_parquet('%s')
  WHERE keep = 1
    AND period IN ('Pre','Post')
    AND n_firms_auc >= 2
    AND b1_norm IS NOT NULL
    AND b2_norm IS NOT NULL
    AND b1_norm > 0 AND b1_norm <= 3
    AND b2_norm > 0 AND b2_norm <= 3
", path_v3("data/processed/pregao_dropouts.parquet"))) |> setDT()

log_step("37", sprintf("auctions = %s", format(nrow(au), big.mark = ",")), logf)

# N-bin: 2, 3, 4, 5+
au[, n_bin := fcase(
  n_firms_auc == 2,  "2",
  n_firms_auc == 3,  "3",
  n_firms_auc == 4,  "4",
  n_firms_auc >= 5,  "5+",
  default = NA_character_)]

# Grid comum ----------------------------------------------------------
c_grid <- seq(0.005, 2, by = 0.005)

# 1. HT bounds por estrato -------------------------------------------
# Por (period, pharma, n_bin): CDFs empíricas de b_(1), b_(2).
# Lower bound F_LB(c) = 1 - (1 - F_b1(c))^{1/N}
# Upper bound F_UB(c) = F_b2(c) (Haile-Tamer 2003, eq 3.2)

bound_stratum <- function(b1, b2, N_val) {
  F_b1 <- ecdf(b1)(c_grid)
  F_b2 <- ecdf(b2)(c_grid)
  F_LB <- 1 - (1 - F_b1)^(1 / N_val)
  F_UB <- F_b2
  data.table(c = c_grid, F_LB = F_LB, F_UB = F_UB,
             F_b1 = F_b1, F_b2 = F_b2)
}

# Para o N_val no bounds, uso N médio por estrato (≈ razoável quando
# N-bin é estreito).
panel <- au[!is.na(n_bin),
  .(n = .N,
    N_mean = mean(n_firms_auc),
    b1 = list(b1_norm),
    b2 = list(b2_norm)),
  by = .(period, pharma_narrow, n_bin)]

rows <- list()
for (i in seq_len(nrow(panel))) {
  r <- panel[i]
  bd <- bound_stratum(r$b1[[1]], r$b2[[1]], r$N_mean)
  bd[, `:=`(period = r$period, pharma_narrow = r$pharma_narrow,
            n_bin  = r$n_bin, n = r$n, N_mean = r$N_mean)]
  rows[[i]] <- bd
}
ht <- rbindlist(rows)

# Agregação cross-N weighted por n_auctions.
ht_agg <- ht[, .(
    F_LB = sum(F_LB * n) / sum(n),
    F_UB = sum(F_UB * n) / sum(n),
    F_mid = sum(((F_LB + F_UB) / 2) * n) / sum(n),
    n = sum(n)),
  by = .(period, pharma_narrow, c)]
ht_agg[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

arrow::write_parquet(ht_agg,
  path_v3("data/processed/pregao_ht_bounds.parquet"),
  compression = "snappy")

# 2. Sanity check: point-ID F_c cai dentro das bounds? ---------------
fc <- dbGetQuery(con, sprintf("
  SELECT * FROM read_parquet('%s')
  WHERE method = 'losers_point' AND sme_bec = 0
", path_v3("data/processed/pregao_fc.parquet"))) |> setDT()
# sme_bec=0 para comparar com HT aggregate (que não separa por tipo)
# — o aggregate de ambos os tipos é mais comparável ao mix dos bounds.

# Agrega F_c non-SME + SME pesado (reproduz o aggregate sobre bidders).
fc_all <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, c,
         SUM(F_c * n) / SUM(n) AS F_c_agg,
         SUM(n) AS n
  FROM read_parquet('%s')
  WHERE method = 'losers_point'
  GROUP BY period, pharma_narrow, c
", path_v3("data/processed/pregao_fc.parquet"))) |> setDT()

check <- merge(fc_all, ht_agg[, .(period, pharma_narrow, c, F_LB, F_UB)],
               by = c("period", "pharma_narrow", "c"))
check[, inside := as.integer(F_c_agg >= F_LB - 1e-6 &
                              F_c_agg <= F_UB + 1e-6)]

pct_inside <- check[, .(pct_inside = round(mean(inside) * 100, 2),
                         n = .N),
                    by = .(period, pharma_narrow)]
pct_inside[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

cat("\n--- sanity: % dos pontos do F_c point-ID dentro das HT bounds ---\n",
    file = logf)
sink(logf, append = TRUE); print(pct_inside); sink()

# 3. Tabela de sumário: F_c^median e bounds por estrato --------------
summary_pts <- c(0.25, 0.5, 0.75, 0.9)
sum_rows <- list()
for (p in summary_pts) {
  # Para cada estrato, encontra o c tal que F_c ≈ p (interp linear).
  for (per in c("Pre", "Post")) {
    for (ph in c(0, 1)) {
      sub <- ht_agg[period == per & pharma_narrow == ph]
      if (nrow(sub) < 20) next
      c_ub <- approx(sub$F_UB, sub$c, xout = p, rule = 2)$y
      c_lb <- approx(sub$F_LB, sub$c, xout = p, rule = 2)$y
      sum_rows[[length(sum_rows) + 1]] <- data.table(
        period = per, pharma_narrow = ph, q = p,
        c_lower = round(c_ub, 4),   # F_UB → menor c para atingir p
        c_upper = round(c_lb, 4))   # F_LB → maior c para atingir p
    }
  }
}
sum_tab <- rbindlist(sum_rows)
sum_tab[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
sum_tab <- sum_tab[order(pharma_narrow, period, q)]

cat("\n--- HT-implied quantis de F_c (c_lower = HT tight, c_upper = loose) ---\n",
    file = logf)
sink(logf, append = TRUE); print(sum_tab); sink()

# 4. Gráfico com bounds + overlay do point-ID -----------------------
plot_df <- merge(
  ht_agg[, .(period, pharma_lbl, c, F_LB, F_UB)],
  fc_all[, .(period, pharma_lbl = fifelse(pharma_narrow == 1,
                                          "pharma", "non-pharma"),
             c, F_c_agg)],
  by = c("period", "pharma_lbl", "c"), all.x = TRUE)

p <- ggplot(plot_df, aes(x = c)) +
  geom_ribbon(aes(ymin = F_LB, ymax = F_UB, fill = period),
              alpha = 0.25) +
  geom_line(aes(y = F_c_agg, color = period), linewidth = 0.45) +
  facet_wrap(~ pharma_lbl, nrow = 1) +
  scale_color_manual(values = c("Pre" = "black",  "Post" = "grey40")) +
  scale_fill_manual (values = c("Pre" = "grey30", "Post" = "grey70")) +
  labs(x = "c / reference price", y = expression(F[c](c)),
       title = "Preg\\~ao HT bounds vs point-ID drop-out cost CDF",
       color = "", fill = "") +
  coord_cartesian(xlim = c(0, 1.5), ylim = c(0, 1)) +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "bottom")

ggsave(path_v3("output/figures/fig_v3_pregao_ht_bands.pdf"),
       p, width = 7, height = 3.5, device = cairo_pdf)

# 5. LaTeX table ------------------------------------------------------
tab_wide <- dcast(sum_tab,
  pharma_lbl + period ~ q,
  value.var = c("c_lower", "c_upper"))

tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Haile-Tamer bounds on $F_c$, Preg\\~ao, by pharma and period}",
  "\\label{tab:v3_pregao_ht_refined}",
  "\\small",
  "\\begin{tabular}{llrrrrrrrr}",
  "\\toprule",
  " & & \\multicolumn{2}{c}{$q{=}0.25$} & \\multicolumn{2}{c}{$q{=}0.50$} & \\multicolumn{2}{c}{$q{=}0.75$} & \\multicolumn{2}{c}{$q{=}0.90$} \\\\",
  "\\cmidrule(lr){3-4}\\cmidrule(lr){5-6}\\cmidrule(lr){7-8}\\cmidrule(lr){9-10}",
  "Class & Period & LB & UB & LB & UB & LB & UB & LB & UB \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(tab_wide))) {
  r <- tab_wide[i]
  tex <- c(tex, sprintf(
    "%s & %s & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f \\\\",
    r$pharma_lbl, r$period,
    r$c_lower_0.25, r$c_upper_0.25,
    r$c_lower_0.5,  r$c_upper_0.5,
    r$c_lower_0.75, r$c_upper_0.75,
    r$c_lower_0.9,  r$c_upper_0.9))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Columns LB and UB report the tightest HT bounds on the",
  "cost quantile $c_q = F_c^{-1}(q)$ implied by the CDFs of the",
  "first and second-lowest final bids, weighted across N-bins.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_pregao_ht_refined.tex"))

log_step("37", "done", logf)
