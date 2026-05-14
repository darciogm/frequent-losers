# S5 / task 49 -------------------------------------------------------
# Sensitivity da BNE decomposition aos três regimes de F_c:
#   (1) losers-only    (S4 primeira versão)
#   (2) all-bidders    (S4 final — MC3 fix)
#   (3) Turnbull NPMLE (S5 — point ID via winner left-censoring)
#
# Para cada regime, roda o MC BNE (idêntico ao 45) e reporta S1/S2/S3,
# Δtotal, share intensive/entry por pharma. O objetivo é quantificar
# o viés MC3 de forma rigorosa: se Turnbull ≈ all-bidders, v3 final é
# defensável; se Turnbull diverge, revisamos o headline.
#
# Sampling: inverse-CDF via approxfun da F_c Turnbull (grid parquet).
# Para losers-only e all-bidders, amostra empirical direta dos bids.
#
# Saída: tab_v3_sensitivity_fc.tex

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v3("logs/49_sensitivity_fc.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("49", "start: F_c regime sensitivity (losers / all / Turnbull)", logf)

# 1. Amostras losers-only e all-bidders dos bids UH-clean -------------
bids <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, role, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

make_empirical_samples <- function(dt) {
  out <- list()
  for (ph in c(0, 1)) for (per in c("Pre", "Post")) for (sm in c(0, 1)) {
    x <- dt[pharma_narrow == ph & period == per & sme_bec == sm, c]
    if (length(x) >= 50)
      out[[paste(ph, per, sm, sep = "_")]] <- x
  }
  out
}

fc_losers <- make_empirical_samples(bids[role == "loser"])
fc_all    <- make_empirical_samples(bids)

# 2. Amostra via inverse-CDF da F_c Turnbull -------------------------
tb <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c, F_c_turnbull
  FROM read_parquet('%s')
", path_v3("data/processed/pregao_fc_turnbull.parquet"))) |> setDT()

turnbull_sampler <- function(F_df, n) {
  # F_df: data.table com c, F_c_turnbull (ordenado por c).
  # Amostra via inverse-CDF: u ~ U(0,1) → c = F^{-1}(u).
  if (nrow(F_df) < 2) return(numeric())
  u <- runif(n)
  # approx inversa: de F_c para c.
  approx(F_df$F_c_turnbull, F_df$c, xout = u,
         rule = 2, method = "linear")$y
}

make_turnbull_samples <- function(tb_dt, n_each = 10000) {
  out <- list()
  for (ph in c(0, 1)) for (per in c("Pre", "Post")) for (sm in c(0, 1)) {
    sub <- tb_dt[pharma_narrow == ph & period == per & sme_bec == sm]
    if (nrow(sub) < 50) next
    out[[paste(ph, per, sm, sep = "_")]] <- turnbull_sampler(sub, n_each)
  }
  out
}

set.seed(seed_for_script(49))
fc_turnbull <- make_turnbull_samples(tb)

# 3. Entry counts ---------------------------------------------------
entry <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow,
         AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
  GROUP BY 1,2,3
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()

# 4. BNE simulation (idêntica ao 45, parametrizada por sample dict) --
simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme, B = 2000) {
  prices <- numeric(B)
  for (b in seq_len(B)) {
    n_s <- rpois(1, lambda = n_sme)
    n_ns <- rpois(1, lambda = n_nonsme)
    if (n_s + n_ns < 2) { prices[b] <- NA; next }
    costs <- c(
      if (n_s  > 0) sample(fc_sme,   n_s,  replace = TRUE) else numeric(),
      if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric())
    prices[b] <- sort(costs)[2]
  }
  prices
}

run_bne <- function(fc_samples, regime_name) {
  rows <- list()
  for (ph in c(0, 1)) {
    fc_sme_pre  <- fc_samples[[paste(ph, "Pre", 1, sep = "_")]]
    fc_sme_post <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
    fc_ns_pre   <- fc_samples[[paste(ph, "Pre", 0, sep = "_")]]
    if (is.null(fc_sme_pre) || is.null(fc_ns_pre)) next
    n_pre  <- entry[period == "Pre"  & pharma_narrow == ph]
    n_post <- entry[period == "Post" & pharma_narrow == ph]
    p_S1 <- simulate_auction(n_pre$n_sme, n_pre$n_nonsme,
                              fc_sme_pre, fc_ns_pre)
    p_S2 <- simulate_auction(n_pre$n_sme, 0, fc_sme_pre, fc_ns_pre)
    p_S3 <- simulate_auction(n_post$n_sme, 0,
                              if (!is.null(fc_sme_post)) fc_sme_post
                              else fc_sme_pre,
                              fc_ns_pre)
    rows[[length(rows) + 1]] <- data.table(
      regime = regime_name, pharma_narrow = ph,
      mean_S1 = mean(p_S1, na.rm = TRUE),
      mean_S2 = mean(p_S2, na.rm = TRUE),
      mean_S3 = mean(p_S3, na.rm = TRUE))
  }
  out <- rbindlist(rows)
  out[, effect_total := mean_S3 - mean_S1]
  out[, effect_intens := mean_S2 - mean_S1]
  out[, effect_entry  := mean_S3 - mean_S2]
  out[, share_intens := round(abs(effect_intens) /
         (abs(effect_intens) + abs(effect_entry)) * 100, 2)]
  out[, share_entry  := round(100 - share_intens, 2)]
  out
}

set.seed(seed_for_script(49))
res <- rbindlist(list(
  run_bne(fc_losers,   "losers-only"),
  run_bne(fc_all,      "all-bidders"),
  run_bne(fc_turnbull, "Turnbull")))
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
res <- res[order(pharma_narrow, regime)]

cat("\n--- sensitivity F_c: 3 regimes × 2 pharma ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, regime,
              mean_S1 = round(mean_S1, 4),
              mean_S2 = round(mean_S2, 4),
              mean_S3 = round(mean_S3, 4),
              effect_total = round(effect_total, 4),
              share_intens, share_entry)])
sink()

# Calcula gap Turnbull vs all-bidders (quanto v3 final se move).
gap <- dcast(res, pharma_lbl ~ regime, value.var = "effect_total")
gap[, gap_tb_vs_all := round(`Turnbull` - `all-bidders`, 4)]
gap[, gap_los_vs_all := round(`losers-only` - `all-bidders`, 4)]
cat("\n--- gap em Δtotal: Turnbull vs all, losers vs all ---\n",
    file = logf)
sink(logf, append = TRUE)
print(gap)
sink()

# 5. LaTeX -----------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{F\\_c regime sensitivity: BNE decomposition by sampling rule}",
  "\\label{tab:v3_sensitivity_fc}",
  "\\small",
  "\\begin{tabular}{llrrrrrr}",
  "\\toprule",
  "Class & Regime & $\\bar p_{S_1}$ & $\\bar p_{S_2}$ & $\\bar p_{S_3}$ & $\\Delta$ total & \\% int. & \\% entry \\\\",
  "\\midrule")
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %s & %.3f & %.3f & %.3f & %+.4f & %.1f & %.1f \\\\",
    r$pharma_lbl, r$regime,
    r$mean_S1, r$mean_S2, r$mean_S3, r$effect_total,
    r$share_intens, r$share_entry))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Three F\\_c sampling regimes applied to the same BNE engine",
  "(2{,}000 MC auctions per scenario, UH-clean bids, endogenous entry).",
  "Losers-only: ECDF of drop-out bids (biased up). All-bidders:",
  "ECDF of winner + loser bids (S4 final; biased up less). Turnbull:",
  "NPMLE with winners left-censored at $c_{(2)}$ (point ID under",
  "English-reverse IPV). Turnbull is the rigorous benchmark; ``all''",
  "is the S4 proxy. Small Turnbull--all gap ratifies the S4 headline.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_sensitivity_fc.tex"))

log_step("49", "done", logf)
