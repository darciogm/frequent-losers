# S4 / task 45 -------------------------------------------------------
# Simulação de preços sob BNE para três cenários por (pharma × período):
#
#   S1 (open, Pre):  N^SME_Pre  SMEs   + N^nonSME_Pre  non-SMEs
#   S2 (SME-only, fixed pool): N^SME_Pre SMEs,          0 non-SMEs
#   S3 (SME-only, endogenous): N^SME_Post SMEs,         0 non-SMEs
#
# Preço = E[c_(2)] (segunda ordem estatística) sob IPV assimétrico.
# Justificativa: revenue equivalence (Vickrey-Clarke-Groves) —
# FPSB IPV tem mesma expected revenue que Vickrey (que paga c_(2)).
#
# Decomposição:
#   Efeito total observado = S3 − S1
#   Intensive               = S2 − S1   (mesmo pool, bidding muda)
#   Entry                   = S3 − S2   (pool muda)
#   share_intensive = |Intensive| / (|Intensive| + |Entry|)
#
# Input: F_c UH-clean de S3 + entry counts de S4.1

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({ library(ggplot2) })

logf <- file(path_v3("logs/45_bne_simulation.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("45", "start: BNE Monte Carlo simulation", logf)

# 1. F_c por (pharma × tipo × período) -------------------------------
# Uso os bids UH-clean do Pregão como amostra empírica de F_c^k.
# Amostra all-bidders (winner + loser) em vez de losers-only: em
# Pregão BEC o bid final do winner ≈ c_(2), overstates c_win mas
# menos do que losers-only remove (a cauda esquerda inteira).
# Direction: all < losers < truth (viés monotônico para cima).
# Turnbull NPMLE com right-censored winners fica em S5.
#
# Para o Convite, poderia usar GPV-inverted mas é mais complexo —
# opto por usar Pregão como canonical F_c.

fc <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

# Amostra de c_norm_clean por estrato: empírica, não paramétrica.
fc_samples <- list()
for (ph in c(0, 1)) {
  for (per in c("Pre", "Post")) {
    for (sm in c(0, 1)) {
      x <- fc[pharma_narrow == ph & period == per & sme_bec == sm, c]
      if (length(x) < 50) next
      fc_samples[[paste(ph, per, sm, sep = "_")]] <- x
    }
  }
}

# 2. Entry counts ----------------------------------------------------
entry <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow,
         AVG(n_sme_bid)    AS n_sme,
         AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod IN ('convite','pregao')
  GROUP BY 1,2,3
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()

# Foco em Pregão para simulação (84% do valor e onde a F_c foi
# recuperada). Convite entra como validação.
entry_preg <- entry[mod == "pregao"]

# 3. Simulação Monte Carlo -------------------------------------------
# Para cada (pharma, cenário): amostra B auctions com (n_sme, n_nonsme)
# specs e calcula c_(2). Reporta média e quantis.

simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme, B = 2000) {
  # n_sme e n_nonsme são esperados (floor + stochastic round).
  prices <- numeric(B)
  for (b in seq_len(B)) {
    n_s <- rpois(1, lambda = n_sme)
    n_ns <- rpois(1, lambda = n_nonsme)
    if (n_s + n_ns < 2) {
      prices[b] <- NA
      next
    }
    costs <- c(
      if (n_s  > 0) sample(fc_sme,   n_s,  replace = TRUE) else numeric(),
      if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric())
    # Preço = segunda ordem estatística (Vickrey-equivalente).
    prices[b] <- sort(costs)[2]
  }
  prices
}

set.seed(20260423)

results <- list()
for (ph in c(0, 1)) {
  # Seleção de F_c por tipo × período.
  fc_sme_pre   <- fc_samples[[paste(ph, "Pre", 1, sep = "_")]]
  fc_sme_post  <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
  fc_ns_pre    <- fc_samples[[paste(ph, "Pre", 0, sep = "_")]]
  if (is.null(fc_sme_pre) || is.null(fc_ns_pre)) next

  n_pre        <- entry_preg[period == "Pre" & pharma_narrow == ph]
  n_post       <- entry_preg[period == "Post" & pharma_narrow == ph]

  # S1: open, Pre composition
  p_S1 <- simulate_auction(n_pre$n_sme, n_pre$n_nonsme, fc_sme_pre, fc_ns_pre)
  # S2: SME-only, Pre pool (same SMEs, no non-SMEs)
  p_S2 <- simulate_auction(n_pre$n_sme, 0, fc_sme_pre, fc_ns_pre)
  # S3: SME-only, Post pool (endogenous entry)
  p_S3 <- simulate_auction(n_post$n_sme, 0,
                            if (!is.null(fc_sme_post)) fc_sme_post
                            else fc_sme_pre,
                            fc_ns_pre)

  results[[length(results) + 1]] <- data.table(
    pharma_narrow = ph,
    n_sme_pre   = round(n_pre$n_sme, 2),
    n_ns_pre    = round(n_pre$n_nonsme, 2),
    n_sme_post  = round(n_post$n_sme, 2),
    mean_S1 = round(mean(p_S1, na.rm = TRUE), 4),
    mean_S2 = round(mean(p_S2, na.rm = TRUE), 4),
    mean_S3 = round(mean(p_S3, na.rm = TRUE), 4),
    med_S1 = round(median(p_S1, na.rm = TRUE), 4),
    med_S2 = round(median(p_S2, na.rm = TRUE), 4),
    med_S3 = round(median(p_S3, na.rm = TRUE), 4),
    p_S1_list = list(p_S1),
    p_S2_list = list(p_S2),
    p_S3_list = list(p_S3))
}
res <- rbindlist(results)

# Decomposição ------------------------------------------------------
res[, effect_total    := mean_S3 - mean_S1]
res[, effect_intensive := mean_S2 - mean_S1]
res[, effect_entry    := mean_S3 - mean_S2]
res[, share_intensive := round(abs(effect_intensive) /
                          (abs(effect_intensive) + abs(effect_entry)) * 100,
                        2)]
res[, share_entry     := round(100 - share_intensive, 2)]
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

cat("\n--- BNE simulation: preços sob 3 cenários ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, n_sme_pre, n_ns_pre, n_sme_post,
              mean_S1, mean_S2, mean_S3,
              effect_total, effect_intensive, effect_entry,
              share_intensive, share_entry)])
sink()

# 4. Gráfico de densidades ------------------------------------------
plot_df <- rbindlist(lapply(seq_len(nrow(res)), function(i) {
  r <- res[i]
  rbind(
    data.table(pharma_lbl = r$pharma_lbl, scenario = "S1 (open, Pre)",
               price = r$p_S1_list[[1]]),
    data.table(pharma_lbl = r$pharma_lbl, scenario = "S2 (SME-only, fixed pool)",
               price = r$p_S2_list[[1]]),
    data.table(pharma_lbl = r$pharma_lbl, scenario = "S3 (SME-only, endogenous)",
               price = r$p_S3_list[[1]]))
}))
plot_df <- plot_df[is.finite(price)]

p <- ggplot(plot_df, aes(x = price, color = scenario, linetype = scenario)) +
  stat_ecdf(linewidth = 0.4) +
  facet_wrap(~ pharma_lbl, nrow = 1) +
  scale_color_manual(values = c("S1 (open, Pre)" = "black",
                                 "S2 (SME-only, fixed pool)" = "grey40",
                                 "S3 (SME-only, endogenous)" = "grey65")) +
  coord_cartesian(xlim = c(0, 1.5)) +
  labs(x = "Simulated c_(2) / reference price",
       y = "ECDF",
       color = "", linetype = "",
       title = "BNE price distribution by scenario (Vickrey-equivalent)") +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "bottom")
ggsave(path_v3("output/figures/fig_v3_bne_prices.pdf"),
       p, width = 7, height = 3.5, device = cairo_pdf)

# 5. Salva panel de resultados --------------------------------------
res[, c("p_S1_list", "p_S2_list", "p_S3_list") := NULL]
arrow::write_parquet(res,
  path_v3("data/processed/bne_decomp.parquet"),
  compression = "snappy")

# 6. LaTeX ----------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{BNE price decomposition: intensive vs entry margin (UH-clean $F_c$)}",
  "\\label{tab:v3_bne_decomp}",
  "\\small",
  "\\begin{tabular}{lrrrrrrrrr}",
  "\\toprule",
  " & \\multicolumn{3}{c}{Entry profile} & \\multicolumn{3}{c}{Prices $\\bar c_{(2)}$} & \\multicolumn{3}{c}{Decomp.} \\\\",
  "\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}\\cmidrule(lr){8-10}",
  "Class & $N^{\\text{SME}}_{\\text{Pre}}$ & $N^{\\neg}_{\\text{Pre}}$ & $N^{\\text{SME}}_{\\text{Post}}$ & S1 & S2 & S3 & $\\Delta$ total & \\% int. & \\% entry \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %.2f & %.2f & %.2f & %.3f & %.3f & %.3f & %+.4f & %.1f & %.1f \\\\",
    r$pharma_lbl, r$n_sme_pre, r$n_ns_pre, r$n_sme_post,
    r$mean_S1, r$mean_S2, r$mean_S3, r$effect_total,
    r$share_intensive, r$share_entry))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Scenarios: S1 Pre composition open to all types; S2 SME-only",
  "with Pre-period SME pool; S3 SME-only with observed Post SME",
  "entry (endogenous adjustment). Prices are mean $c_{(2)}$ from 2{,}000",
  "Monte Carlo auctions under Vickrey-equivalent IPV with UH-clean",
  "cost distributions sampled from all Preg\\~ao bidders (winners plus",
  "losers) to attenuate the upward bias of a losers-only ECDF.",
  "Intensive share = $|S_2 - S_1| / (|S_2-S_1| + |S_3-S_2|)$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_bne_decomp.tex"))

log_step("45", "done", logf)
