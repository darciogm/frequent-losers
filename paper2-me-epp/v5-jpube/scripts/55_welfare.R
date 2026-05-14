# ----------------------------------------------------------------------
# Welfare decomposition of the SME-only set-aside. Two welfare-loss
# pieces:
#
#   DWL_alloc = E[c_(1)^{S3} - c_(1)^{S1}]
#      extra production cost: the SME winner may not be the
#      lowest-cost bidder in the full pool.
#
#   MCPF_dist = Δ_gov · λ
#      tax distortion: each extra R$ of government outlay costs
#      (1+λ) in welfare terms (λ = marginal cost of public funds).
#
#   Total welfare loss = DWL_alloc + MCPF_dist, reported as % of
#   the baseline open-regime price p_S1.
#
# Sensitivity over λ ∈ {0.20, 0.30, 0.40}; all-bidders F_c regime.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/55_welfare.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("55", "start: welfare decomp with MCPF", logf)

bids <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

entry <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow,
         AVG(n_sme_bid) AS n_sme, AVG(n_nonsme_bid) AS n_nonsme
  FROM read_parquet('%s')
  WHERE mod = 'pregao' GROUP BY 1,2
", path_v3("data/processed/entry_rates.parquet"))) |> setDT()

fc <- list()
for (ph in c(0, 1)) for (per in c("Pre","Post")) for (sm in c(0, 1)) {
  x <- bids[pharma_narrow == ph & period == per & sme_bec == sm, c]
  if (length(x) >= 50) fc[[paste(ph, per, sm, sep = "_")]] <- x
}

# Simulate B auctions e retorna vetores: c1_S1, c2_S1, c1_S3, c2_S3
simulate_welfare <- function(n_sme_pre, n_ns_pre, n_sme_post,
                             fc_sme_pre, fc_ns_pre, fc_sme_post,
                             B = 5000) {
  c1_S1 <- numeric(B); c2_S1 <- numeric(B)
  c1_S3 <- numeric(B); c2_S3 <- numeric(B)
  for (b in seq_len(B)) {
    # S1 open, Pre pool
    n_s_pre  <- rpois(1, lambda = n_sme_pre)
    n_n_pre  <- rpois(1, lambda = n_ns_pre)
    n_s_post <- rpois(1, lambda = n_sme_post)
    if (n_s_pre + n_n_pre < 2 || n_s_post < 2) {
      c1_S1[b] <- NA; c2_S1[b] <- NA
      c1_S3[b] <- NA; c2_S3[b] <- NA
      next
    }
    c_pre <- c(
      if (n_s_pre > 0) sample(fc_sme_pre, n_s_pre, replace = TRUE)
      else numeric(),
      if (n_n_pre > 0) sample(fc_ns_pre,  n_n_pre, replace = TRUE)
      else numeric())
    s_pre <- sort(c_pre)
    c1_S1[b] <- s_pre[1]; c2_S1[b] <- s_pre[2]

    c_post <- sample(fc_sme_post, n_s_post, replace = TRUE)
    s_post <- sort(c_post)
    c1_S3[b] <- s_post[1]; c2_S3[b] <- s_post[2]
  }
  list(c1_S1 = c1_S1, c2_S1 = c2_S1, c1_S3 = c1_S3, c2_S3 = c2_S3)
}

sims <- list()
for (ph in c(0, 1)) {
  s_pre   <- fc[[paste(ph, "Pre",  1, sep = "_")]]
  s_post  <- fc[[paste(ph, "Post", 1, sep = "_")]]
  n_pre   <- fc[[paste(ph, "Pre",  0, sep = "_")]]
  en_pre  <- entry[period == "Pre"  & pharma_narrow == ph]
  en_post <- entry[period == "Post" & pharma_narrow == ph]
  if (is.null(s_pre) || is.null(n_pre) || is.null(s_post)) next
  set.seed(20260423)
  sims[[as.character(ph)]] <- simulate_welfare(
    en_pre$n_sme, en_pre$n_nonsme, en_post$n_sme,
    s_pre, n_pre, s_post)
}

# Welfare decomposition under multiple λ ------------------------------
# Grid awideda for cobrir o consenso MCPF [0.15, 0.45] e atender
# referee JPubE (BSW 1985 is US-based and from the 1970s; sensitivity is
# requirement editorial).
lambdas <- c(0.15, 0.20, 0.30, 0.40, 0.45)

rows <- list()
for (ph in c(0, 1)) {
  yes <- sims[[as.character(ph)]]
  if (is.null(sim)) next
  ok <- !is.na(sim$c1_S1) & !is.na(sim$c1_S3)
  mean_p_S1  <- mean(sim$c2_S1[ok])
  mean_p_S3  <- mean(sim$c2_S3[ok])
  delta_gov  <- mean_p_S3 - mean_p_S1
  mean_c1_S1 <- mean(sim$c1_S1[ok])
  mean_c1_S3 <- mean(sim$c1_S3[ok])
  dwl_alloc  <- mean_c1_S3 - mean_c1_S1
  # Producer-surplus change implicit (= Δ_gov - DWL_alloc).
  transfer   <- delta_gov - dwl_alloc
  for (lambda in lambdas) {
    mcpf_dist   <- delta_gov * lambda
    total_loss  <- dwl_alloc + mcpf_dist
    loss_pct_S1 <- total_loss / mean_p_S1 * 100
    rows[[length(rows) + 1]] <- data.table(
      pharma_narrow = ph, lambda = lambda,
      mean_p_S1 = round(mean_p_S1, 4),
      delta_gov = round(delta_gov, 4),
      dwl_alloc = round(dwl_alloc, 4),
      transfer  = round(transfer, 4),
      mcpf_dist = round(mcpf_dist, 4),
      total_loss = round(total_loss, 4),
      loss_pct_S1 = round(loss_pct_S1, 2))
  }
}
res <- rbindlist(rows)
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
res <- res[order(pharma_narrow, lambda)]

cat("\n--- welfare decomposition (all-bidders F_c) ---\n", file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, lambda, mean_p_S1, delta_gov,
              dwl_alloc, transfer, mcpf_dist, total_loss,
              loss_pct_S1)])
sink()

# LaTeX --------------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Welfare decomposition: allocative DWL + MCPF distortion, by $\\lambda$}",
  "\\label{tab:v3_welfare}",
  "\\small",
  "\\begin{tabular}{llrrrrrr}",
  "\\toprule",
  "Class & $\\lambda$ & $\\bar p_{S_1}$ & $\\Delta_{\\text{gov}}$ & DWL$_{\\text{alloc}}$ & MCPF dist. & Total loss & \\% of $p_{S_1}$ \\\\",
  "\\midrule")
for (i in seq_len(nrow(res))) {
  r <- res[i]
  tex <- c(tex, sprintf(
    "%s & %.2f & %.3f & %.3f & %.3f & %.3f & %.3f & %.2f \\\\",
    r$pharma_lbl, r$lambda,
    r$mean_p_S1, r$delta_gov,
    r$dwl_alloc, r$mcpf_dist,
    r$total_loss, r$loss_pct_S1))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Per-auction welfare decomposition, 5{,}000 MC draws under",
  "all-bidders UH-clean $F_c$. $\\Delta_{\\text{gov}} = p_{S_3} -",
  "p_{S_1}$ is the government's extra payment; DWL$_{\\text{alloc}}",
  "= c_{(1)}^{S_3} - c_{(1)}^{S_1}$ is the extra production cost",
  "from allocating the auction to a possibly non-optimal SME bidder.",
  "MCPF distortion $= \\Delta_{\\text{gov}} \\cdot \\lambda$: each R\\$",
  "additional gasto by the governo load $\\lambda$ in distor\\c{c}\\~ao",
  "tribut\\'aria. Total loss = DWL + MCPF; reportada como \\% do",
  "baseline $p_{S_1}$ (open, Pre pool).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_welfare.tex"))

arrow::write_parquet(res,
  path_v3("data/processed/welfare_decomp.parquet"),
  compression = "snappy")

log_step("55", "done", logf)
