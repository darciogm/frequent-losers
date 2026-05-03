# S5 / task 53 -------------------------------------------------------
# APV (Alternative Policy Variants) — compara quatro contrafactuais
# na BNE engine para mostrar o range de efeitos de política:
#
#   V0 = v3 main: 100% set-aside, endogenous Post SME pool.
#   V1 = partial: 50% auctions SME-only (Post pool) + 50% open (Pre pool).
#   V2 = entry-isolated: SME-only com N^SME = N^SME_Pre (sem entry).
#   V3 = price preference 10%: open com SMEs recebendo bid × 0.9.
#
# Baseline comparison = S1 (open, Pre) observado.
# Reporta: price, Δ vs baseline, share vs V0.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v3("logs/53_apv.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("53", "start: alternative policy variants", logf)

bids <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

entry <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow,
         AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod = 'pregao' GROUP BY 1,2,3
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()

fc <- list()
for (ph in c(0, 1)) for (per in c("Pre","Post")) for (sm in c(0, 1)) {
  x <- bids[pharma_narrow == ph & period == per & sme_bec == sm, c]
  if (length(x) >= 50) fc[[paste(ph, per, sm, sep = "_")]] <- x
}

# Simulate single auction with arbitrary (n_sme, n_nonsme, fc draws,
# sme_discount for price preference).
simulate_one <- function(n_sme, n_nonsme, fc_sme, fc_nonsme,
                         sme_discount = 1.0) {
  n_s <- rpois(1, lambda = n_sme)
  n_ns <- rpois(1, lambda = n_nonsme)
  if (n_s + n_ns < 2) return(NA_real_)
  c_s <- if (n_s  > 0) sample(fc_sme,    n_s,  replace = TRUE) else numeric()
  c_n <- if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric()
  # Price preference: SME bids são avaliados com desconto para
  # determinar winner, mas o governo paga o c_(2) *actual*
  # (Vickrey-equivalent: winner pays what second bidder would need
  # to match, em bid real). Quando há preference, o "second bidder"
  # já está com effective different do actual, então pago o threshold
  # que o winner ainda ganharia: actual_second se winner SME paga o
  # actual-equivalent do non-SME boundary.
  c_s_eff <- c_s * sme_discount
  all_eff    <- c(c_s_eff, c_n)
  all_actual <- c(c_s,     c_n)
  ord <- order(all_eff)
  # Vickrey: price paid = segunda effective, mas "traduzida" pelo
  # winner's preference. Se winner é SME, ele podia ter bidado até
  # c_(2) effective / sme_discount sem perder → pay esse valor
  # actual; se winner é non-SME, payment = c_(2) effective actual
  # (non-SME não tem discount, então effective = actual).
  is_sme_winner <- ord[1] <= n_s
  c2_eff <- all_eff[ord[2]]
  if (is_sme_winner) {
    c2_eff / sme_discount
  } else {
    c2_eff
  }
}

simulate_B <- function(f, B = 2000) {
  replicate(B, f())
}

run_apv <- function(ph) {
  s_pre  <- fc[[paste(ph, "Pre",  1, sep = "_")]]
  s_post <- fc[[paste(ph, "Post", 1, sep = "_")]]
  n_pre  <- fc[[paste(ph, "Pre",  0, sep = "_")]]
  n_pol  <- entry[period == "Pre"  & pharma_narrow == ph]
  n_post <- entry[period == "Post" & pharma_narrow == ph]
  if (is.null(s_pre) || is.null(n_pre)) return(NULL)

  # Baseline S1 = open, Pre pool.
  p_S1 <- simulate_B(function()
    simulate_one(n_pol$n_sme, n_pol$n_nonsme, s_pre, n_pre))
  # V0 = v3 main: SME-only + Post endogenous pool.
  p_V0 <- simulate_B(function()
    simulate_one(n_post$n_sme, 0,
                 if (!is.null(s_post)) s_post else s_pre, n_pre))
  # V1 = partial 50/50.
  p_V1 <- simulate_B(function() {
    if (runif(1) < 0.5)
      simulate_one(n_pol$n_sme, n_pol$n_nonsme, s_pre, n_pre)
    else
      simulate_one(n_post$n_sme, 0,
                   if (!is.null(s_post)) s_post else s_pre, n_pre)
  })
  # V2 = entry-isolated: SME-only but with Pre SME pool.
  p_V2 <- simulate_B(function()
    simulate_one(n_pol$n_sme, 0, s_pre, n_pre))
  # V3 = open with 10% SME price preference.
  p_V3 <- simulate_B(function()
    simulate_one(n_pol$n_sme, n_pol$n_nonsme, s_pre, n_pre,
                 sme_discount = 0.9))

  m <- function(x) mean(x, na.rm = TRUE)
  base <- m(p_S1)
  out <- data.table(
    pharma_narrow = ph,
    mean_S1 = base,
    mean_V0 = m(p_V0), delta_V0 = m(p_V0) - base,
    mean_V1 = m(p_V1), delta_V1 = m(p_V1) - base,
    mean_V2 = m(p_V2), delta_V2 = m(p_V2) - base,
    mean_V3 = m(p_V3), delta_V3 = m(p_V3) - base)
  out
}

set.seed(seed_for_script(53))
res <- rbindlist(lapply(c(0, 1), run_apv))
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

# Relative share: cada V em % do delta_V0.
res[, share_V1_of_V0 := round(delta_V1 / delta_V0 * 100, 1)]
res[, share_V2_of_V0 := round(delta_V2 / delta_V0 * 100, 1)]
res[, share_V3_of_V0 := round(delta_V3 / delta_V0 * 100, 1)]

cat("\n--- APV: 4 counterfactuals × 2 pharma ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, mean_S1 = round(mean_S1, 4),
              mean_V0 = round(mean_V0, 4), delta_V0 = round(delta_V0, 4),
              delta_V1 = round(delta_V1, 4), delta_V2 = round(delta_V2, 4),
              delta_V3 = round(delta_V3, 4),
              share_V1 = share_V1_of_V0, share_V2 = share_V2_of_V0,
              share_V3 = share_V3_of_V0)])
sink()

# LaTeX --------------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Alternative Policy Variants (APV) — counterfactual price effects}",
  "\\label{tab:v3_apv}",
  "\\small",
  "\\begin{tabular}{lrrrrr}",
  "\\toprule",
  "Class & $\\bar p_{S_1}$ & V0 (v3) & V1 (50\\%) & V2 (no entry) & V3 (10\\% pref.) \\\\",
  "\\midrule")
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %.3f & %+.4f & %+.4f [%.1f\\%%] & %+.4f [%.1f\\%%] & %+.4f [%.1f\\%%] \\\\",
    r$pharma_lbl, r$mean_S1, r$delta_V0,
    r$delta_V1, r$share_V1_of_V0,
    r$delta_V2, r$share_V2_of_V0,
    r$delta_V3, r$share_V3_of_V0))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Price $\\Delta$ relative to observed $S_1$ (open, Pre pool).",
  "V0 = full 100\\% SME set-aside with endogenous Post pool (main text).",
  "V1 = partial 50/50 mix. V2 = SME-only but Pre pool (isolates intensive",
  "margin). V3 = open auction with 10\\% price preference for SMEs.",
  "Bracketed values are each variant's $\\Delta$ as \\% of V0's $\\Delta$,",
  "so V1 = 50\\% means ``half the v3 effect''.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_apv.tex"))

log_step("53", "done", logf)
