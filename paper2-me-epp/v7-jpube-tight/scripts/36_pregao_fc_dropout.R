# S2 / task 36 -------------------------------------------------------
# Estima F_c^k (k = SME / non-SME) em Pregão a partir dos drop-outs
# (final bids dos perdedores) sob a interpretação English-reverse IPV:
# cada perdedor sai do leilão quando o preço atinge seu custo, logo
# c_loser = final_bid_loser. Essa é a identificação point de
# Hong-Shum (2003) / Athey-Haile (2002).
#
# Importante: sob IPV assimétrico, a estratégia "sair no custo" ainda
# é fracamente dominante para cada bidder independentemente do tipo
# dos rivais — então podemos estimar F_c^SME e F_c^nonSME pelos drop
# outs de cada tipo separadamente.
#
# Reporto duas ECDFs por estrato:
#   losers-only : point ID (recomendado — viés pequeno, só falta o
#                 menor custo, que é o vencedor)
#   all-bidders : inclui vencedor; dá upper bound one-sided em F_c
#                 (vencedor parou antes de chegar no custo dele)
#
# Primitive-invariance test: KS de F_c^nonSME_Pre vs F_c^nonSME_Post
# por pharma — a condição identificadora do paper.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

suppressPackageStartupMessages({
  library(ggplot2)
})

logf <- file(path_v3("logs/36_pregao_fc_dropout.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("36", "start: F_c estimation from drop-outs", logf)

m <- dbGetQuery(con, sprintf("
  SELECT * FROM read_parquet('%s')
  WHERE keep = 1 AND period IN ('Pre','Post')
", path_v3("data/processed/pregao_dropouts.parquet"))) |> setDT()

log_step("36", sprintf("n = %s firm×auction (janela 18m)",
                       format(nrow(m), big.mark = ",")), logf)

# 1. ECDF por estrato ------------------------------------------------
# grid comum para c_norm: 0.005 até 2.0 com passo 0.005
c_grid <- seq(0.005, 2, by = 0.005)

ecdf_stratum <- function(x) {
  x <- x[!is.na(x)]
  f <- ecdf(x)
  f(c_grid)
}

# losers (point ID)
f_lose <- m[role == "loser",
  .(F_c = list(ecdf_stratum(c_norm)),
    n   = .N),
  by = .(period, pharma_narrow, sme_bec)]
f_lose[, method := "losers_point"]

# all bidders (one-sided bound)
f_all <- m[, .(F_c = list(ecdf_stratum(c_norm)),
               n   = .N),
           by = .(period, pharma_narrow, sme_bec)]
f_all[, method := "all_bound"]

fc_panel <- rbind(f_lose, f_all)

# Expande cada lista para long format
fc_long <- fc_panel[, .(c = c_grid, F_c = F_c[[1]]),
                    by = .(period, pharma_narrow, sme_bec, method, n)]
fc_long[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
fc_long[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]

arrow::write_parquet(fc_long,
  path_v3("data/processed/pregao_fc.parquet"),
  compression = "snappy")

# 2. Sumário por estrato: mean, p50, p75, p90 -------------------------
sum_tab <- m[role == "loser",
  .(n_losers   = .N,
    mean_c     = round(mean(c_norm), 4),
    p50_c      = round(quantile(c_norm, 0.50), 4),
    p75_c      = round(quantile(c_norm, 0.75), 4),
    p90_c      = round(quantile(c_norm, 0.90), 4),
    pct_above1 = round(mean(c_norm > 1) * 100, 2)),
  by = .(period, pharma_narrow, sme_bec)]
sum_tab[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
sum_tab[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]
sum_tab <- sum_tab[order(pharma_narrow, sme_bec, period)]

cat("\n--- losers-only F_c summary (point ID) ---\n", file = logf)
sink(logf, append = TRUE); print(sum_tab); sink()

# 3. Shift test: F_c^k_Pre vs F_c^k_Post (primitive invariance) ------
ks_panel <- m[role == "loser",
  .(x = list(c_norm)),
  by = .(period, pharma_narrow, sme_bec)]

ks_res <- list()
for (pharma_lbl in c(0, 1)) {
  for (sme_lbl in c(0, 1)) {
    pre  <- ks_panel[period == "Pre"  &
                     pharma_narrow == pharma_lbl &
                     sme_bec == sme_lbl, x][[1]]
    post <- ks_panel[period == "Post" &
                     pharma_narrow == pharma_lbl &
                     sme_bec == sme_lbl, x][[1]]
    if (is.null(pre) || is.null(post) || length(pre) < 50 || length(post) < 50) next
    kt <- suppressWarnings(ks.test(pre, post))
    ks_res[[length(ks_res) + 1]] <- data.table(
      pharma_narrow = pharma_lbl,
      sme_bec       = sme_lbl,
      n_pre         = length(pre),
      n_post        = length(post),
      D             = round(unname(kt$statistic), 4),
      pval          = signif(unname(kt$p.value), 3),
      mean_pre      = round(mean(pre), 4),
      mean_post     = round(mean(post), 4),
      shift         = round(mean(post) - mean(pre), 4))
  }
}
ks_tab <- rbindlist(ks_res)
ks_tab[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
ks_tab[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]

cat("\n--- KS shift test (Pre vs Post) por pharma × type ---\n", file = logf)
sink(logf, append = TRUE); print(ks_tab[, .(pharma_lbl, sme_lbl, n_pre, n_post,
                                             D, pval, mean_pre, mean_post, shift)])
sink()

# 4. LaTeX table -----------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Preg\\~ao drop-out costs $F_c^k$ by stratum (point ID)}",
  "\\label{tab:v3_pregao_fc_summary}",
  "\\small",
  "\\begin{tabular}{llllrrrrr}",
  "\\toprule",
  "Class & Type & Period & N losers & Mean & p50 & p75 & p90 & \\% $>$ ref \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(sum_tab))) {
  r <- sum_tab[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %s & %.4f & %.4f & %.4f & %.4f & %.2f \\\\",
    r$pharma_lbl, r$sme_lbl, r$period,
    format(r$n_losers, big.mark = ","),
    r$mean_c, r$p50_c, r$p75_c, r$p90_c, r$pct_above1))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Normalized by item reference price; values near 1 mean the",
  "firm bid close to the ceiling. Under English-reverse IPV, each loser",
  "drops out at its cost, so the ECDF of losers' drop-outs is a point",
  "estimate of $F_c^k$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_pregao_fc_summary.tex"))

# 5. Figure: F_c by stratum (losers point ID) ------------------------
fig_df <- fc_long[method == "losers_point"]
fig_df[, panel := paste(pharma_lbl, sme_lbl, sep = " / ")]

p <- ggplot(fig_df, aes(x = c, y = F_c, color = period)) +
  geom_line(linewidth = 0.5) +
  facet_wrap(~ panel, nrow = 2) +
  scale_color_manual(values = c("Pre" = "black", "Post" = "grey50")) +
  labs(x = "c / reference price", y = expression(F[c](c)),
       title = "Preg\\~ao drop-out cost distributions (point ID)",
       color = "") +
  coord_cartesian(xlim = c(0, 1.5)) +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "bottom")

ggsave(path_v3("output/figures/fig_v3_pregao_fc_by_stratum.pdf"),
       p, width = 7, height = 5, device = cairo_pdf)

log_step("36", "done", logf)
