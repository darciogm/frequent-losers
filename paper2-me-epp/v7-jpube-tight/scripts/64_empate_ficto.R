# S4 / task 64 -------------------------------------------------------
# V4 (empate ficto): direito de cobertura LC 123/2006 arts. 44–45.
# Quando best SME cost X cai dentro de banda de 5% acima do best
# non-SME cost Y (i.e., Y < X ≤ 1.05 * Y) em Pregão, a MPE tem o
# direito de cobrir o lance do líder não-MPE; governo paga Y.
#
# Diferença mecânica vs. V3 (preferência contínua de scoring):
#   V3 multiplica o lance MPE por (1-k) para seleção do vencedor,
#       desconto contínuo; governo paga lance efetivo (Vickrey).
#   V4 dispara só dentro da banda discreta de 5%; governo paga
#       o lance do líder não-MPE (não o lance da MPE).
#
# Predições de §8.4 a serem testadas pela simulação:
#   (i)   E[price_V4] - E[price_S1] ≤ E[price_V3] - E[price_S1] (ambos ≈ 0)
#   (ii)  MPE win-rate sob V4 ≤ MPE win-rate sob V3 (V3 ≈ 21.4% NP / 17.6% PH)
#   (iii) MCPF distortion zero por construção (gov paga Y, que é c_(2) do
#         regime aberto restrito a non-SMEs como leader; comparação fina abaixo)
#   (iv)  DWL_alloc = E[X - Y | empate fires AND Y < X] × Pr(empate fires e Y < X)
#         Cota superior: 0.05 * E[Y] * Pr(empate fires); segunda ordem.
#
# Inputs: bids_uh_cleaned.parquet (F_c por tipo × período) + entry_rates.parquet.
# Output: data/processed/empate_ficto.parquet + tab_v4_empate.tex.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v3("logs/64_empate_ficto.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("64", "start: V4 (empate ficto) Monte Carlo", logf)

EMPATE_BAND <- 0.05  # LC 123/2006 art. 44, modalidade Pregão
LAMBDA      <- 0.30  # MCPF benchmark (Ballard-Shoven-Whalley)
B           <- 3000  # MC draws per (pharma) cell, matches preference grid B

# 1. F_c por (pharma × tipo × período = Pre) — mesma fonte que 45 -----
fc <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

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

# 2. Arrival rates Pregão Pre ----------------------------------------
entry <- dbGetQuery(con, sprintf("
  SELECT mod, period, pharma_narrow,
         AVG(n_sme_bid)    AS n_sme,
         AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod IN ('convite','pregao')
  GROUP BY 1,2,3
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()
entry_preg_pre <- entry[mod == "pregao" & period == "Pre"]

# 3. Simulação V4 -----------------------------------------------------
# Para cada draw em Pregão Pre composition:
#   - Sample n_s ~ Pois(lambda_SME), n_ns ~ Pois(lambda_nonSME).
#   - Sample costs por tipo.
#   - Compute c_(2) baseline (S1): segunda menor entre todos.
#   - Compute MPE-leader X = min(c_sme), non-MPE-leader Y = min(c_ns).
#   - V4:
#       * Se Y < X ≤ (1 + EMPATE_BAND)*Y: empate fires. MPE wins, gov paga Y.
#         Production cost = X. DWL_alloc = X - Y. Gov outlay = Y.
#       * Caso contrário: standard. Winner = lowest cost. Gov paga c_(2). DWL_alloc = 0.
#   - MCPF distortion = lambda * (E[gov outlay V4] - E[gov outlay S1]).
#     E[gov outlay S1] = E[c_(2)]; sob V4 quando empate fires, gov paga Y
#     (que pode ser menor ou maior que c_(2) original). Vou medir empiricamente.

simulate_v4 <- function(n_sme_lambda, n_ns_lambda, fc_sme, fc_ns, B = 3000) {
  v_priceS1   <- rep(NA_real_,    B)
  v_priceV4   <- rep(NA_real_,    B)
  v_fires     <- rep(NA_integer_, B)
  v_smeWinS1  <- rep(NA_integer_, B)
  v_smeWinV4  <- rep(NA_integer_, B)
  v_dwl       <- rep(NA_real_,    B)
  v_X         <- rep(NA_real_,    B)
  v_Y         <- rep(NA_real_,    B)

  for (b in seq_len(B)) {
    n_s  <- rpois(1, lambda = n_sme_lambda)
    n_ns <- rpois(1, lambda = n_ns_lambda)
    if (n_s + n_ns < 2) next

    c_s  <- if (n_s  > 0) sample(fc_sme, n_s,  replace = TRUE) else numeric()
    c_ns <- if (n_ns > 0) sample(fc_ns,  n_ns, replace = TRUE) else numeric()
    all_costs <- c(c_s, c_ns)
    types     <- c(rep("SME", n_s), rep("nonSME", n_ns))

    sorted_idx <- order(all_costs)
    winner_S1  <- types[sorted_idx[1]]                # standard winner under open
    c_2        <- all_costs[sorted_idx[2]]            # price_S1 (Vickrey-equivalent)

    X <- if (n_s  > 0) min(c_s)  else Inf  # best SME cost
    Y <- if (n_ns > 0) min(c_ns) else Inf  # best non-SME cost

    fires_b <- as.integer(n_s > 0 && n_ns > 0 && X > Y && X <= (1 + EMPATE_BAND) * Y)

    if (fires_b == 1) {
      pV4 <- Y
      winner_V4 <- "SME"
      dwl_b <- X - Y
    } else {
      pV4 <- c_2
      winner_V4 <- winner_S1
      dwl_b <- 0
    }

    v_priceS1[b]  <- c_2
    v_priceV4[b]  <- pV4
    v_fires[b]    <- fires_b
    v_smeWinS1[b] <- as.integer(winner_S1 == "SME")
    v_smeWinV4[b] <- as.integer(winner_V4 == "SME")
    v_dwl[b]      <- dwl_b
    v_X[b]        <- X
    v_Y[b]        <- Y
  }

  data.table(
    price_S1    = v_priceS1,
    price_V4    = v_priceV4,
    fires       = v_fires,
    sme_wins_S1 = v_smeWinS1,
    sme_wins_V4 = v_smeWinV4,
    dwl_alloc   = v_dwl,
    X           = v_X,
    Y           = v_Y)
}

set.seed(seed_for_script(64))

results <- list()
for (ph in c(0, 1)) {
  fc_sme_pre <- fc_samples[[paste(ph, "Pre", 1, sep = "_")]]
  fc_ns_pre  <- fc_samples[[paste(ph, "Pre", 0, sep = "_")]]
  if (is.null(fc_sme_pre) || is.null(fc_ns_pre)) next

  n_pre <- entry_preg_pre[pharma_narrow == ph]

  sim <- simulate_v4(n_pre$n_sme, n_pre$n_nonsme, fc_sme_pre, fc_ns_pre, B = B)
  sim <- sim[!is.na(price_S1)]

  mean_p_S1 <- mean(sim$price_S1)
  mean_p_V4 <- mean(sim$price_V4)
  delta_V4  <- mean_p_V4 - mean_p_S1
  fire_rate <- mean(sim$fires)
  sme_win_S1 <- mean(sim$sme_wins_S1) * 100
  sme_win_V4 <- mean(sim$sme_wins_V4) * 100
  dwl_mean  <- mean(sim$dwl_alloc)
  mcpf_dist <- LAMBDA * delta_V4
  total_loss <- dwl_mean + mcpf_dist
  loss_pct  <- 100 * total_loss / mean_p_S1

  results[[length(results) + 1]] <- data.table(
    pharma_narrow = ph,
    pharma_lbl    = fifelse(ph == 1, "pharma", "non-pharma"),
    n_sme_pre     = round(n_pre$n_sme, 2),
    n_ns_pre      = round(n_pre$n_nonsme, 2),
    mean_p_S1     = round(mean_p_S1, 4),
    mean_p_V4     = round(mean_p_V4, 4),
    delta_V4_vs_S1 = round(delta_V4, 4),
    fire_rate     = round(fire_rate * 100, 1),
    sme_win_S1_pct = round(sme_win_S1, 1),
    sme_win_V4_pct = round(sme_win_V4, 1),
    sme_win_gain_pp = round(sme_win_V4 - sme_win_S1, 1),
    dwl_alloc     = round(dwl_mean, 4),
    mcpf_dist     = round(mcpf_dist, 4),
    total_loss    = round(total_loss, 4),
    loss_pct_S1   = round(loss_pct, 2))
}
res <- rbindlist(results)

cat("\n--- V4 empate ficto: BNE Monte Carlo (band =", EMPATE_BAND * 100, "%, lambda =", LAMBDA, ") ---\n", file = logf)
sink(logf, append = TRUE); print(res); sink()

# 4. Output parquet ---------------------------------------------------
arrow::write_parquet(res, path_v3("data/processed/empate_ficto.parquet"))
log_step("64", sprintf("wrote empate_ficto.parquet (%d rows)", nrow(res)), logf)

# 5. Output table tab_v4_empate.tex ----------------------------------
tab_path <- path_v3("output/tables/tab_v4_empate.tex")

fmt_pp_signed <- function(x) {
  s <- if (x >= 0) "+" else "-"
  sprintf("%s%.4f", s, abs(x))
}

rows <- vapply(seq_len(nrow(res)), function(i) {
  r <- res[i]
  sprintf("%s & %.3f & %s & %.1f\\%% & %.1f\\%% \\(\\to\\) %.1f\\%% (\\(+\\)%.1f pp) & %.4f & %.2f\\%% \\\\",
          r$pharma_lbl,
          r$mean_p_S1,
          fmt_pp_signed(r$delta_V4_vs_S1),
          r$fire_rate,
          r$sme_win_S1_pct,
          r$sme_win_V4_pct,
          r$sme_win_gain_pp,
          r$dwl_alloc,
          r$loss_pct_S1)
}, character(1))

tab_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  sprintf("\\caption{V4 \\emph{empate ficto} (LC 123/2006 arts.~44--45, Preg\\~ao): structural quantification of the right-to-match.}"),
  "\\label{tab:v4_empate}",
  "\\small",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\begin{tabular}{lrcrlrr}",
  "\\toprule",
  "Class & $\\bar p_{S_1}$ & $\\Delta p$ vs $S_1$ & Empate fires & SME win-rate $S_1 \\to V_4$ & DWL$_{\\text{alloc}}$ & Welfare loss \\\\",
  "\\midrule",
  rows,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  sprintf("\\item BNE Monte Carlo, $B = %d$ draws per (pharma) cell at Pre-period Preg\\~ao composition.", B),
  sprintf("Empate ficto fires iff $Y < X \\le (1+%g)\\cdot Y$ where $X = \\min$ SME cost, $Y = \\min$ non-SME cost.", EMPATE_BAND),
  "On firing: SME wins (matches leader); government pays $Y$ (leader's bid); allocative wedge $= X - Y > 0$.",
  "MCPF distortion $= \\lambda \\cdot \\mathbb{E}[\\Delta_{\\text{gov}}]$ at $\\lambda = 0.30$.",
  "Welfare loss $= $ DWL$_{\\text{alloc}} + $ MCPF dist., reported as percent of $p_{S_1}$.",
  "All values from \\texttt{empate\\_ficto.parquet}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")

writeLines(tab_lines, tab_path)
log_step("64", sprintf("wrote tab_v4_empate.tex"), logf)

log_step("64", "done", logf)
