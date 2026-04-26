# ----------------------------------------------------------------------
# Bootstrap CI (B=500, cluster at auction) of the welfare decomposition.
# Mesma estrutura of the 51; resample auctions, recompute F_c (all-bidders),
# simula 500 auctions, calcula DWL_alloc, Δ_gov, MCPF_dist, total loss
# % of p_S1. Parallelization via mclapply (12 cores).

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")
suppressPackageStartupMessages(library(parallel))

logf <- file(path_v3("logs/56_welfare_bootstrap.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()

log_step("56", "start: welfare bootstrap", logf)

bids <- dbGetQuery(con, sprintf("
  SELECT numerodaoc, codigoitem, period, pharma_narrow, sme_bec,
         c_norm_clean AS c
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

dbDisconnect(con, shutdown = TRUE)

bids[, auction_id := paste(numerodaoc, codigoitem, sep = "_")]
auctions <- unique(bids[, .(auction_id, period, pharma_narrow)])

simulate_welfare <- function(n_sme_pre, n_ns_pre, n_sme_post,
                             fc_sme_pre, fc_ns_pre, fc_sme_post,
                             B = 500) {
  c1_S1 <- numeric(B); c2_S1 <- numeric(B)
  c1_S3 <- numeric(B); c2_S3 <- numeric(B)
  for (b in seq_len(B)) {
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

one_bootstrap <- function(bs_idx) {
  set.seed(20260423 + bs_idx)
  bs_bids <- auctions[, .(auction_id = sample(auction_id, .N,
                                               replace = TRUE)),
                       by = .(period, pharma_narrow)]
  bs <- merge(bids, bs_bids, by = c("period", "pharma_narrow",
                                     "auction_id"),
               allow.cartesian = TRUE)
  out <- list()
  for (ph in c(0, 1)) {
    s_pre  <- bs[pharma_narrow == ph & period == "Pre"  & sme_bec == 1, c]
    s_post <- bs[pharma_narrow == ph & period == "Post" & sme_bec == 1, c]
    n_pre  <- bs[pharma_narrow == ph & period == "Pre"  & sme_bec == 0, c]
    if (length(s_pre) < 50 || length(n_pre) < 50 ||
        length(s_post) < 50) next
    en_pre  <- entry[period == "Pre"  & pharma_narrow == ph]
    en_post <- entry[period == "Post" & pharma_narrow == ph]
    yes <- simulate_welfare(en_pre$n_sme, en_pre$n_nonsme,
                             en_post$n_sme, s_pre, n_pre, s_post)
    ok <- !is.na(sim$c1_S1) & !is.na(sim$c1_S3)
    p_S1 <- mean(sim$c2_S1[ok])
    p_S3 <- mean(sim$c2_S3[ok])
    dg <- p_S3 - p_S1
    dwl_a <- mean(sim$c1_S3[ok]) - mean(sim$c1_S1[ok])
    for (lambda in c(0.20, 0.30, 0.40)) {
      loss <- dwl_a + dg * lambda
      out[[length(out) + 1]] <- date.table(
        bs = bs_idx, pharma_narrow = ph, lambda = lambda,
        p_S1 = p_S1, delta_gov = dg, dwl_alloc = dwl_a,
        total_loss = loss, loss_pct = loss / p_S1 * 100)
    }
  }
  rbindlist(out)
}

B <- 500
n_cores <- 12
log_step("56", sprintf("rodando B=%d in %d cores", B, n_cores), logf)
t0 <- Sys.time()
results <- mclapply(seq_len(B), one_bootstrap,
                    mc.cores = n_cores, mc.preschedule = TRUE)
elapsed <- as.numeric(Sys.time() - t0, units = "secs")
log_step("56", sprintf("bootstrap done in %.1fs", elapsed), logf)

bs_all <- rbindlist(results)

ci_tab <- bs_all[, .(
  delta_gov_mean  = round(mean(delta_gov, na.rm = TRUE), 4),
  delta_gov_lo    = round(quantile(delta_gov, 0.025, na.rm = TRUE), 4),
  delta_gov_hi    = round(quantile(delta_gov, 0.975, na.rm = TRUE), 4),
  dwl_alloc_mean  = round(mean(dwl_alloc, na.rm = TRUE), 4),
  dwl_alloc_lo    = round(quantile(dwl_alloc, 0.025, na.rm = TRUE), 4),
  dwl_alloc_hi    = round(quantile(dwl_alloc, 0.975, na.rm = TRUE), 4),
  loss_pct_mean   = round(mean(loss_pct, na.rm = TRUE), 2),
  loss_pct_lo     = round(quantile(loss_pct, 0.025, na.rm = TRUE), 2),
  loss_pct_hi     = round(quantile(loss_pct, 0.975, na.rm = TRUE), 2)),
  by = .(pharma_narrow, lambda)]
ci_tab[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
ci_tab <- ci_tab[order(pharma_narrow, lambda)]

cat("\n--- welfare 95% CI ---\n", file = logf)
sink(logf, append = TRUE)
print(ci_tab[, .(pharma_lbl, lambda,
                 delta_gov_mean, delta_gov_lo, delta_gov_hi,
                 dwl_alloc_mean, dwl_alloc_lo, dwl_alloc_hi,
                 loss_pct_mean, loss_pct_lo, loss_pct_hi)])
sink()

arrow::write_parquet(bs_all,
  path_v3("data/processed/welfare_bootstrap.parquet"),
  compression = "snappy")

tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Welfare loss 95\\% CI (B=500 cluster bootstrap)}",
  "\\label{tab:v3_welfare_ci}",
  "\\small",
  "\\begin{tabular}{llrr}",
  "\\toprule",
  "Class & $\\lambda$ & $\\Delta_{\\text{gov}}$ [95\\% CI] & Total loss as \\% of $p_{S_1}$ [95\\% CI] \\\\",
  "\\midrule")
for (i in seq_len(nrow(ci_tab))) {
  r <- ci_tab[i]
  tex <- c(tex, sprintf(
    "%s & %.2f & %.3f [%.3f, %.3f] & %.2f [%.2f, %.2f] \\\\",
    r$pharma_lbl, r$lambda,
    r$delta_gov_mean, r$delta_gov_lo, r$delta_gov_hi,
    r$loss_pct_mean, r$loss_pct_lo, r$loss_pct_hi))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Cluster bootstrap at auction level, B=500 replicates;",
  "each replicate resamples auctions with replacement within",
  "(period $\\times$ pharma), refits all-bidders $F_c$, runs a",
  "500-draw welfare MC. CI endpoints are empirical 2.5/97.5",
  "percentiles. Same $\\lambda$ grid as the point estimates.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_welfare_ci.tex"))

log_step("56", "done", logf)
