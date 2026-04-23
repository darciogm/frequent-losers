# S5 / task 48 -------------------------------------------------------
# Turnbull (1976) NPMLE para F_c^k no Pregão sob descending-clock IPV,
# corrigindo o winner left-censoring que o S4 trata com all-bidders.
# Losers: observações puntuais em c_norm_clean. Winners: left-censored
# em c_(2)_auction = min(c_norm_clean dos losers do mesmo auction).
#
# Algoritmo (EM self-consistency, Turnbull 1976):
#   1. Nodes = união dos point obs + upper bounds.
#   2. Start: f_k = ECDF empirical de losers.
#   3. E-step: cada winner redistribui massa nos nodes ≤ upper_i
#      proporcionalmente ao f atual.
#   4. M-step: f ← (soma massas expected) / N.
#   5. Iterar até convergência (max_abs_diff < 1e-5 ou 100 iter).
#
# Saída: pregao_fc_turnbull.parquet (mesmo schema de pregao_fc.parquet)

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/48_turnbull_fc.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("48", "start: Turnbull NPMLE per stratum", logf)

# 1. Pull: losers point + winner upper bounds por auction --------------
bids <- dbGetQuery(con, sprintf("
  SELECT numerodaoc, codigoitem, period, pharma_narrow, sme_bec, role,
         c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

log_step("48", sprintf("bids = %s rows",
                       format(nrow(bids), big.mark = ",")), logf)

# c_(2) por auction = min entre losers (point ID). Se o auction só tem
# winner sem loser visível, skip (raro).
c2 <- bids[role == "loser", .(c2 = min(c)),
           by = .(numerodaoc, codigoitem, period, pharma_narrow)]

# Winners recebem upper bound c_(2).
winners <- merge(
  bids[role == "winner"],
  c2, by = c("numerodaoc", "codigoitem", "period", "pharma_narrow"),
  all.x = FALSE)

losers <- bids[role == "loser"]

log_step("48", sprintf("winners com c_(2) válido = %s; losers = %s",
                       format(nrow(winners), big.mark = ","),
                       format(nrow(losers),  big.mark = ",")), logf)

# 2. Turnbull EM por estrato -------------------------------------------
turnbull_fit <- function(point_obs, upper_bounds, max_iter = 100,
                         tol = 1e-5) {
  # Edge cases.
  if (length(point_obs) == 0 && length(upper_bounds) == 0) return(NULL)
  if (length(point_obs) < 20) return(NULL)

  nodes <- sort(unique(c(point_obs, upper_bounds)))
  K <- length(nodes)

  # Inicialização com ECDF dos losers.
  F_init <- ecdf(point_obs)(nodes)
  f <- diff(c(0, F_init))
  # Evita zeros duros (começo).
  f <- f + 1e-8
  f <- f / sum(f)

  # Índices de cada upper_bound nos nodes.
  upper_idx <- findInterval(upper_bounds, nodes, all.inside = TRUE)
  # Índices de cada point_obs nos nodes (match exato).
  pt_idx <- match(point_obs, nodes)
  E_pt <- tabulate(pt_idx, nbins = K)

  n_total <- length(point_obs) + length(upper_bounds)
  max_u <- max(upper_idx)
  # Cumulative f (para divisão rápida).
  for (it in seq_len(max_iter)) {
    cf <- cumsum(f)
    # Para cada winner i, a prob. massa esperada no node k é
    #   f[k] / cf[upper_idx[i]]  se k ≤ upper_idx[i]; 0 senão.
    # Vetorização: para cada k, somar sobre winners cujo upper_idx >= k,
    # a fração 1/cf[upper_idx].
    # tabulate(upper_idx, K) dá contagem de winners com upper_idx=k.
    # Precisamos de sum_{i: upper_idx_i >= k} 1/cf[upper_idx_i].
    # Equivalente: seja w[u] = # winners com upper_idx = u; então
    # sum_{u=k}^{K} w[u]/cf[u]. Usa cumsum reverso.
    w_by_u <- tabulate(upper_idx, nbins = K)
    inv_cf <- ifelse(cf > 0, 1 / cf, 0)
    tail_sum <- rev(cumsum(rev(w_by_u * inv_cf)))
    E_win <- f * tail_sum

    f_new <- (E_pt + E_win) / n_total
    # Renormalizar para lidar com underflow numérico.
    f_new <- f_new / sum(f_new)
    delta <- max(abs(f_new - f))
    f <- f_new
    if (delta < tol) break
  }
  list(nodes = nodes, f = f, F_c = cumsum(f), iter = it, delta = delta)
}

c_grid <- seq(0.005, 2, by = 0.005)

rows <- list()
for (per in c("Pre", "Post")) {
  for (ph in c(0, 1)) {
    for (sm in c(0, 1)) {
      lose_c <- losers[period == per & pharma_narrow == ph & sme_bec == sm, c]
      win_c2 <- winners[period == per & pharma_narrow == ph & sme_bec == sm, c2]
      fit <- turnbull_fit(lose_c, win_c2)
      if (is.null(fit)) next
      F_grid <- approx(fit$nodes, fit$F_c, xout = c_grid,
                       method = "constant", f = 1, rule = 2)$y
      rows[[length(rows) + 1]] <- data.table(
        period = per, pharma_narrow = ph, sme_bec = sm,
        c = c_grid, F_c_turnbull = F_grid,
        n_losers = length(lose_c), n_winners = length(win_c2),
        iter = fit$iter, delta = fit$delta)
    }
  }
}
fc_tb <- rbindlist(rows)

cat("\n--- Turnbull NPMLE: convergência por estrato ---\n", file = logf)
sink(logf, append = TRUE)
print(unique(fc_tb[, .(period, pharma_narrow, sme_bec, n_losers, n_winners,
                        iter, delta = signif(delta, 3))]))
sink()

arrow::write_parquet(fc_tb,
  path_v3("data/processed/pregao_fc_turnbull.parquet"),
  compression = "snappy")

# 3. Resumo: median/p75 Turnbull vs losers-only vs all-bidders --------
# Carrega os outros dois para comparação.
preg_all <- bids[, .(sample = "all-bidders",
                      c50 = round(quantile(c, 0.50), 4),
                      c75 = round(quantile(c, 0.75), 4)),
                  by = .(period, pharma_narrow, sme_bec)]
preg_los <- bids[role == "loser",
                 .(sample = "losers-only",
                   c50 = round(quantile(c, 0.50), 4),
                   c75 = round(quantile(c, 0.75), 4)),
                 by = .(period, pharma_narrow, sme_bec)]

get_q <- function(c, F_c, q) approx(F_c, c, xout = q, rule = 2)$y
preg_tb <- fc_tb[, .(sample = "Turnbull",
                     c50 = round(get_q(c, F_c_turnbull, 0.5), 4),
                     c75 = round(get_q(c, F_c_turnbull, 0.75), 4)),
                 by = .(period, pharma_narrow, sme_bec)]

cmp <- rbindlist(list(preg_los, preg_all, preg_tb))
cmp[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
cmp[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]
cmp <- cmp[order(pharma_narrow, sme_bec, period, sample)]

cat("\n--- c_50, c_75 por sample (losers / all-bidders / Turnbull) ---\n",
    file = logf)
sink(logf, append = TRUE)
print(cmp[, .(pharma_lbl, sme_lbl, period, sample, c50, c75)])
sink()

# 4. LaTeX: tabela de comparação de mediana ---------------------------
cmp_wide <- dcast(cmp, pharma_lbl + sme_lbl + period ~ sample,
                  value.var = c("c50", "c75"))
setnames(cmp_wide,
  c("c50_all-bidders", "c50_losers-only", "c50_Turnbull",
    "c75_all-bidders", "c75_losers-only", "c75_Turnbull"),
  c("c50_all", "c50_lose", "c50_tb", "c75_all", "c75_lose", "c75_tb"))
cmp_wide <- cmp_wide[order(pharma_lbl, sme_lbl, period)]

tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Turnbull NPMLE vs losers-only vs all-bidders: $F_c^k$ quantiles}",
  "\\label{tab:v3_turnbull_fc}",
  "\\small",
  "\\begin{tabular}{lllrrrrrr}",
  "\\toprule",
  " & & & \\multicolumn{3}{c}{$c_{0.5}$} & \\multicolumn{3}{c}{$c_{0.75}$} \\\\",
  "\\cmidrule(lr){4-6}\\cmidrule(lr){7-9}",
  "Class & Type & Period & losers & all & Turn. & losers & all & Turn. \\\\",
  "\\midrule")
for (i in seq_len(nrow(cmp_wide))) {
  r <- cmp_wide[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f \\\\",
    r$pharma_lbl, r$sme_lbl, r$period,
    r$c50_lose, r$c50_all, r$c50_tb,
    r$c75_lose, r$c75_all, r$c75_tb))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Losers-only uses only drop-out bids (upward-biased: misses",
  "the lowest cost per auction). All-bidders adds winners as if",
  "their final bid were a point observation (downward-biased: winner",
  "final bid $\\ge$ true cost). Turnbull (1976) NPMLE treats winners",
  "as left-censored in $c_{(2)}$ (true upper bound), iterating EM",
  "self-consistency until convergence. Turnbull is expected to lie",
  "between losers-only and all-bidders.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_turnbull_fc.tex"))

log_step("48", "done", logf)
