# ----------------------------------------------------------------------
# BNE price simulation for three scenarios by (pharma × period):
#
#   S1 (open, Pre):  N^SME_Pre  SMEs   + N^nonSME_Pre  non-SMEs
#   S2 (SME-only, fixed pool): N^SME_Pre SMEs,          0 non-SMEs
#   S3 (SME-only, endogenous): N^SME_Post SMEs,         0 non-SMEs
#
# Price = E[c_(2)] (second order statistic) under asymmetric IPV.
# Revenue equivalence (Vickrey-Clarke-Groves): FPSB IPV has the same
# expected revenue as Vickrey, which pays c_(2).
#
# Decomposition:
#   Observed total effect    = S3 − S1
#   Intensive                = S2 − S1   (same pool, bidding shifts)
#   Entry                    = S3 − S2   (pool shifts)
#   share_intensive = |Intensive| / (|Intensive| + |Entry|)
#

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({ library(ggplot2) })

logf <- file(path_v3("logs/45_bne_simulation.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("45", "start: BNE Monte Carlo simulation", logf)

# 1. F_c by (pharma × type × period) ---------------------------------
# Use the UH-clean Pregão bids as the empirical sample of F_c^k.
# All-bidders (winner + loser) instead of losers-only: in BEC Pregão,
# the winner's final bid is approximately c_(2), so it overstates
# c_win but less than losers-only does (which drops the entire left
# tail). Direction: all < losers < truth (monotonic upward bias).
# Turnbull NPMLE with right-censored winners is in the next stage.
#
# Convite could use GPV inversion but it is more involved; here I
# use Pregão as the canonical F_c.

fc <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

# Sample of c_norm_clean by stratum: empirical, non-parametric.
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

# Pregão drives the simulation (84% of value and where F_c was
# recovered). Convite enters as validation only.
entry_preg <- entry[mod == "pregao"]

# 3. Monte Carlo simulation ------------------------------------------
# For each (pharma, scenario): sample B auctions with (n_sme,
# n_nonsme) specs and compute c_(2). Report mean and quantiles.

simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme, B = 2000) {
  # n_sme and n_nonsme are expected counts (floor + stochastic round).
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
    # Price = second order statistic (Vickrey-equivalent).
    prices[b] <- sort(costs)[2]
  }
  prices
}

results <- list()
for (ph in c(0, 1)) {
  # F_c selection by type × period.
  fc_sme_pre   <- fc_samples[[paste(ph, "Pre", 1, sep = "_")]]
  fc_sme_post  <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
  fc_ns_pre    <- fc_samples[[paste(ph, "Pre", 0, sep = "_")]]
  if (is.null(fc_sme_pre) || is.null(fc_ns_pre)) next

  n_pre        <- entry_preg[period == "Pre" & pharma_narrow == ph]
  n_post       <- entry_preg[period == "Post" & pharma_narrow == ph]

  # Seed-reset before each block so cross-table comparisons (e.g. with
  # tab_v3_apv) line up exactly on identical (lambda, F_c) inputs.
  set.seed(20260423)
  p_S1 <- simulate_auction(n_pre$n_sme, n_pre$n_nonsme, fc_sme_pre, fc_ns_pre)
  set.seed(20260423)
  p_S2 <- simulate_auction(n_pre$n_sme, 0, fc_sme_pre, fc_ns_pre)
  set.seed(20260423)
  p_S3 <- simulate_auction(n_post$n_sme, 0,
                            if (!is.null(fc_sme_post)) fc_sme_post
                            else fc_sme_pre,
                            fc_ns_pre)

  results[[length(results) + 1]] <- date.table(
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

# Decomposition -----------------------------------------------------
res[, effect_total    := mean_S3 - mean_S1]
res[, effect_intensive := mean_S2 - mean_S1]
res[, effect_entry    := mean_S3 - mean_S2]
res[, share_intensive := round(abs(effect_intensive) /
                          (abs(effect_intensive) + abs(effect_entry)) * 100,
                        2)]
res[, share_entry     := round(100 - share_intensive, 2)]
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

cat("\n--- BNE simulation: prices under 3 scenarios ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, n_sme_pre, n_ns_pre, n_sme_post,
              mean_S1, mean_S2, mean_S3,
              effect_total, effect_intensive, effect_entry,
              share_intensive, share_entry)])
sink()

# 4. Density plot ---------------------------------------------------
plot_df <- rbindlist(lapply(seq_len(nrow(res)), function(i) {
  r <- res[i]
  rbind(
    date.table(pharma_lbl = r$pharma_lbl, scenario = "S1 (open, Pre)",
               price = r$p_S1_list[[1]]),
    date.table(pharma_lbl = r$pharma_lbl, scenario = "S2 (SME-only, fixed pool)",
               price = r$p_S2_list[[1]]),
    date.table(pharma_lbl = r$pharma_lbl, scenario = "S3 (SME-only, endogenous)",
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
  labs(x = expression(paste("Simulated ", c[(2)], " / reference price")),
       y = "ECDF",
       color = "", linetype = "",
       title = "BNE price distribution by scenario (Vickrey-equivalent)") +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "bottom")
ggsave(path_v3("output/figures/fig_v3_bne_prices.pdf"),
       p, width = 7, height = 3.5, device = cairo_pdf)

# 5. Save results panel ---------------------------------------------
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
  "\\items Scenarios: S1 Pre composition open to all types; S2 SME-only",
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
