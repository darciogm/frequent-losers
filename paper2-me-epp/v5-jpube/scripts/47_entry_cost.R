# ----------------------------------------------------------------------
# Calibrate the entry cost κ^k via the zero-profit condition at the
# entry margin. For each type, expected profit per entry:
#   κ^k = P(win|k) · E[π | k wins]
# where π = c_(2) - c_(1) (Vickrey-equivalent; revenue equivalence
# under IPV). κ is MC-estimated: draw costs under the observed entry
# profile, compute the winner's profit, attribute by type (SME winner
# gets π; non-SME winner → SME contributes 0). κ is the unconditional
# mean profit across draws; by construction this equals P(win) × E[π|win]
# without double-counting.
#
# Output: tab_v3_entry_cost.tex with κ^SME and κ^non-SME in R$ (ref-price
# scale) by pharma.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/47_entry_cost.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("47", "start: entry cost calibration", logf)

# Sample of F_c: all-bidders (winner + loser), not only losers. In
# In BEC Pregão the winners final bid ≈ true c_(2), that is, overstates
# c_win but not by much; losers-only, by contrast, removes the tail
# entire left. All-bidders is the correction direcional (Hong-Shum
# 2003 combined; Turnbull NPMLE fica in S5).
fc <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period = 'Pre'
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

entry <- dbGetQuery(con, sprintf("
  SELECT pharma_narrow, AVG(n_sme_bid) AS n_sme,
         AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod = 'pregao' AND period = 'Pre'
  GROUP BY 1
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()

# Median ref_price by pharma to convert ref-units → R$. Use
# bids_uh_cleaned because already load ref_price e pharma_narrow, e
# g65_keys lacks pharma_narrow. Median instead of mean: heavy right tail
# ref_price is heavy-tailed (non-pharma: mean 4.8k vs median 14).
ref_med <- dbGetQuery(con, sprintf("
  SELECT pharma_narrow, MEDIAN(ref_price) AS ref_med
  FROM read_parquet('%s')
  WHERE mod = 'pregao' AND period = 'Pre'
  GROUP BY 1
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

set.seed(20260423)

sim_profit <- function(fc_sme, fc_ns, n_sme, n_ns, B = 5000) {
  # NA in auctions invalids (n<2); 0 in auctions where o outro tipo
  # venceu. This deixa mean(profit_sme, na.rm=TRUE) = κ marginal por
  # construction (zero-contribution of the auctions that SME perdeu) sem
  # duplicar P(win) explicitamente.
  profit_sme <- rep(NA_real_, B)
  profit_ns  <- rep(NA_real_, B)
  for (b in seq_len(B)) {
    n_s  <- rpois(1, lambda = n_sme)
    n_n  <- rpois(1, lambda = n_ns)
    if (n_s + n_n < 2) next
    c_s <- if (n_s > 0) sample(fc_sme, n_s, replace = TRUE) else numeric()
    c_n <- if (n_n > 0) sample(fc_ns,  n_n, replace = TRUE) else numeric()
    all_costs <- c(c_s, c_n)
    types     <- c(rep("SME", n_s), rep("non-SME", n_n))
    ord <- order(all_costs)
    winner_type <- types[ord[1]]
    c_1 <- all_costs[ord[1]]
    c_2 <- all_costs[ord[2]]
    prof <- max(0, c_2 - c_1)  # winner profit = price − cost
    # Zero for o tipo that perdeu, prof for o that venceu. Assim
    # mean(profit_*, na.rm=TRUE) = P(win) × E[π|win] by construction.
    if (winner_type == "SME") {
      profit_sme[b] <- prof
      profit_ns[b]  <- 0
    } else {
      profit_sme[b] <- 0
      profit_ns[b]  <- prof
    }
  }
  list(sme = profit_sme, ns = profit_ns)
}

rows <- list()
for (ph in c(0, 1)) {
  fc_sme <- fc[pharma_narrow == ph & sme_bec == 1, c]
  fc_ns  <- fc[pharma_narrow == ph & sme_bec == 0, c]
  if (length(fc_sme) < 50 || length(fc_ns) < 50) next
  n_sme  <- entry[pharma_narrow == ph, n_sme]
  n_ns   <- entry[pharma_narrow == ph, n_nonsme]
  ref_m  <- ref_med[pharma_narrow == ph, ref_med]
  yes <- sim_profit(fc_sme, fc_ns, n_sme, n_ns)
  # P(win) = fraction of auctions valids in that o tipo venceu.
  p_win_sme <- mean(sim$sme > 0, na.rm = TRUE)
  p_win_ns  <- mean(sim$ns  > 0, na.rm = TRUE)
  # E[π | win] = mean conditional a vencer (includes only auctions
  # effectivemente vencidas by the tipo).
  E_pi_sme <- mean(sim$sme[sim$sme > 0], na.rm = TRUE)
  E_pi_ns  <- mean(sim$ns[ sim$ns  > 0], na.rm = TRUE)
  # κ marginal = P(win) × E[π | win]. Equivalente à mean não-
  # conditional (construction above garante os zeros in the tipo that perdeu).
  kappa_sme <- mean(sim$sme, na.rm = TRUE)
  kappa_ns  <- mean(sim$ns,  na.rm = TRUE)
  rows[[length(rows) + 1]] <- date.table(
    pharma_lbl = fifelse(ph == 1, "pharma", "non-pharma"),
    ref_med    = round(ref_m, 2),
    n_sme_bar  = round(n_sme, 2),
    n_ns_bar   = round(n_ns, 2),
    p_win_sme  = round(p_win_sme, 3),
    p_win_ns   = round(p_win_ns, 3),
    E_pi_sme_given_win = round(E_pi_sme, 4),
    E_pi_ns_given_win  = round(E_pi_ns, 4),
    kappa_sme_ref_units = round(kappa_sme, 4),
    kappa_ns_ref_units  = round(kappa_ns, 4),
    kappa_sme_BRL = round(kappa_sme * ref_m, 2),
    kappa_ns_BRL  = round(kappa_ns * ref_m, 2))
}
res <- rbindlist(rows)

cat("\n--- entry cost calibration (Pre-policy, UH-clean F_c) ---\n",
    file = logf)
sink(logf, append = TRUE); print(res); sink()

tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Entry cost $\\kappa^k$ calibration by type and pharma (Pre-policy)}",
  "\\label{tab:v3_entry_cost}",
  "\\small",
  "\\begin{tabular}{lrrrrrrr}",
  "\\toprule",
  " & & \\multicolumn{2}{c}{$P(\\text{win}|k)$} & \\multicolumn{2}{c}{$\\bar\\pi \\mid \\text{win}$ (ref-units)} & \\multicolumn{2}{c}{$\\kappa^k$ (R\\$)} \\\\",
  "\\cmidrule(lr){3-4}\\cmidrule(lr){5-6}\\cmidrule(lr){7-8}",
  "Class & $\\tilde p^{\\text{ref}}$ (R\\$) & SME & non-SME & SME & non-SME & SME & non-SME \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %.2f & %.3f & %.3f & %.4f & %.4f & %.2f & %.2f \\\\",
    r$pharma_lbl, r$ref_med,
    r$p_win_sme, r$p_win_ns,
    r$E_pi_sme_given_win, r$E_pi_ns_given_win,
    r$kappa_sme_BRL, r$kappa_ns_BRL))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Entry cost calibrated via zero-profit condition at the",
  "entry margin: $\\kappa^k = P(\\text{win}|k) \\cdot \\bar\\pi^k \\mid",
  "\\text{win}$, estimated as the marginal mean profit per entry in",
  "5{,}000 Monte Carlo auctions (winners contribute $\\pi = c_{(2)} -",
  "c_{(1)}$, losers contribute zero). Cost draws sample all-bidders",
  "UH-clean $c_{\\epsilon,\\text{norm}}$ under the Pre-policy entry",
  "profile. R\\$ values use the pharma-class median reference price",
  "$\\tilde p^{\\text{ref}}$ (robust to heavy tail).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_entry_cost.tex"))

log_step("47", "done", logf)
