# ----------------------------------------------------------------------
# Bootstrap CI (B=500) of the BNE decomposition in the 3 F_c regimes.
# Cluster at auction level (not individual bid) to respect the
# correlation within-auction caused by UH.
#
# For each bootstrap b:
#   1. Resample auctions with replacement (by stratum pharma×period×sme).
#   2. Recompute F_c in each regime (losers/all/Turnbull).
#   3. Rodar BNE MC (B_MC=500) with each regime e calcular
#      Δtotal, share_intens, share_entry.
#   4. Save 12 statistics (3 regimes × 2 pharma × 2 shares +
#      Δtotal).
#
# Final: 95% CI via percentis 2.5/97.5 over os B replicates.
# Parallelization via parallel::mclapply (12 workers).
#

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")
suppressPackageStartupMessages(library(parallel))

logf <- file(path_v3("logs/51_bootstrap_ci.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()

log_step("51", "start: B=500 bootstrap CI", logf)

# 1. Load bids uma single vez --------------------------------------
bids <- dbGetQuery(con, sprintf("
  SELECT numerodaoc, codigoitem, period, pharma_narrow, sme_bec, role,
         c_norm_clean AS c
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

dbDisconnect(con, shutdown = TRUE)

# Auction ID for cluster bootstrap.
bids[, auction_id := paste(numerodaoc, codigoitem, sep = "_")]
auctions <- unique(bids[, .(auction_id, period, pharma_narrow)])

log_step("51", sprintf("bids = %s, auctions singles = %s",
                       formt(nrow(bids), big.mark = ","),
                       formt(nrow(auctions), big.mark = ",")), logf)

# 2. Functions core ----------------------------------------------------
turnbull_fit <- function(point_obs, upper_bounds, max_iter = 100,
                         tol = 1e-5) {
  if (length(point_obs) < 20) return(NULL)
  nodes <- sort(unique(c(point_obs, upper_bounds)))
  K <- length(nodes)
  F_init <- ecdf(point_obs)(nodes)
  f <- diff(c(0, F_init)) + 1e-8; f <- f / sum(f)
  upper_idx <- findInterval(upper_bounds, nodes, all.inside = TRUE)
  pt_idx <- match(point_obs, nodes)
  E_pt <- tabulate(pt_idx, nbins = K)
  n_total <- length(point_obs) + length(upper_bounds)
  for (it in seq_len(max_iterations)) {
    cf <- cumsum(f)
    w_by_u <- tabulate(upper_idx, nbins = K)
    inv_cf <- ifelse(cf > 0, 1 / cf, 0)
    tail_sum <- rev(cumsum(rev(w_by_u * inv_cf)))
    E_win <- f * tail_sum
    f_new <- (E_pt + E_win) / n_total
    f_new <- f_new / sum(f_new)
    if (max(abs(f_new - f)) < tol) { f <- f_new; break }
    f <- f_new
  }
  list(nodes = nodes, f = f, F_c = cumsum(f))
}

simulate_auction <- function(n_sme, n_nonsme, fc_sme, fc_nonsme,
                             B = 500) {
  prices <- numeric(B)
  for (b in seq_len(B)) {
    n_s  <- rpois(1, lambda = n_sme)
    n_ns <- rpois(1, lambda = n_nonsme)
    if (n_s + n_ns < 2) { prices[b] <- NA; next }
    costs <- c(
      if (n_s  > 0) sample(fc_sme,   n_s,  replace = TRUE) else numeric(),
      if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric())
    prices[b] <- sort(costs)[2]
  }
  prices
}

run_bne <- function(fc_samples, pharma_narrow_val) {
  ph <- pharma_narrow_val
  sme_pre  <- fc_samples[[paste(ph, "Pre",  1, sep = "_")]]
  sme_post <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
  ns_pre   <- fc_samples[[paste(ph, "Pre",  0, sep = "_")]]
  if (is.null(sme_pre) || is.null(ns_pre)) return(NULL)
  n_pre  <- entry[period == "Pre"  & pharma_narrow == ph]
  n_post <- entry[period == "Post" & pharma_narrow == ph]
  p_S1 <- simulate_auction(n_pre$n_sme, n_pre$n_nonsme, sme_pre, ns_pre)
  p_S2 <- simulate_auction(n_pre$n_sme, 0, sme_pre, ns_pre)
  p_S3 <- simulate_auction(n_post$n_sme, 0,
                            if (!is.null(sme_post)) sme_post else sme_pre,
                            ns_pre)
  m1 <- mean(p_S1, na.rm = TRUE); m2 <- mean(p_S2, na.rm = TRUE)
  m3 <- mean(p_S3, na.rm = TRUE)
  eff_total <- m3 - m1
  eff_int   <- m2 - m1
  eff_ent   <- m3 - m2
  denom <- abs(eff_int) + abs(eff_ent)
  list(delta_total = eff_total,
       share_int   = if (denom > 0) abs(eff_int) / denom * 100 else NA,
       share_ent   = if (denom > 0) abs(eff_ent) / denom * 100 else NA)
}

# 3. A single bootstrap round -----------------------------------------
one_bootstrap <- function(bs_idx) {
  set.seed(20260423 + bs_idx)
  # Resample auctions within each (period × pharma) with replacement.
  # sme_bec é bid-level; mantemos original within the bids resampled.
  bs_bids <- auctions[, .(
    auction_id = sample(auction_id, .N, replace = TRUE)),
    by = .(period, pharma_narrow)]
  bs <- merge(bids, bs_bids, by = c("period", "pharma_narrow",
                                     "auction_id"),
              allow.cartesian = TRUE)

  # Build samples by stratum, 3 regimes.
  fc_los <- list(); fc_all <- list(); fc_tb <- list()
  for (ph in c(0, 1)) for (per in c("Pre","Post")) for (sm in c(0, 1)) {
    tag <- paste(ph, per, sm, sep = "_")
    sub <- bs[pharma_narrow == ph & period == per & sme_bec == sm]
    if (nrow(sub) < 50) next
    fc_all[[tag]] <- sub$c
    fc_los[[tag]] <- sub[role == "loser", c]
    # Turnbull: losers + winner c_(2).
    c2 <- sub[role == "loser",
              .(c2 = min(c)),
              by = .(numerodaoc, codigoitem)]
    win_c2 <- merge(sub[role == "winner",
                         .(numerodaoc, codigoitem)],
                     c2, by = c("numerodaoc", "codigoitem"))$c2
    fit <- turnbull_fit(sub[role == "loser", c], win_c2)
    if (is.null(fit)) next
    # Sample 5000 via inverse-CDF.
    u <- runif(5000)
    fc_tb[[tag]] <- approx(fit$F_c, fit$nodes, xout = u,
                            rule = 2, method = "linear")$y
  }

  out <- list()
  for (ph in c(0, 1)) {
    for (reg in c("losers", "all", "turnbull")) {
      fc_src <- switch(reg,
                       losers   = fc_los,
                       all      = fc_all,
                       turnbull = fc_tb)
      r <- run_bne(fc_src, ph)
      if (is.null(r)) next
      out[[length(out) + 1]] <- date.table(
        bs = bs_idx, regime = reg, pharma_narrow = ph,
        delta_total = r$delta_total,
        share_int   = r$share_int,
        share_ent   = r$share_ent)
    }
  }
  rbindlist(out)
}

# 4. Parallelization ---------------------------------------------------
B <- 500
n_cores <- 12

log_step("51", sprintf("rodando B=%d in %d cores", B, n_cores), logf)
t0 <- Sys.time()
results <- mclapply(seq_len(B), one_bootstrap,
                    mc.cores = n_cores, mc.preschedule = TRUE)
elapsed <- as.numeric(Sys.time() - t0, units = "secs")
log_step("51", sprintf("bootstrap done in %.1fs (%.2f s/bs)",
                       elapsed, elapsed / B), logf)

bs_all <- rbindlist(results)

# 5. CI -------------------------------------------------------------
ci_tab <- bs_all[, .(
  delta_total_mean = round(mean(delta_total, na.rm = TRUE), 4),
  delta_total_lo   = round(quantile(delta_total, 0.025, na.rm = TRUE), 4),
  delta_total_hi   = round(quantile(delta_total, 0.975, na.rm = TRUE), 4),
  share_int_mean   = round(mean(share_int, na.rm = TRUE), 2),
  share_int_lo     = round(quantile(share_int, 0.025, na.rm = TRUE), 2),
  share_int_hi     = round(quantile(share_int, 0.975, na.rm = TRUE), 2),
  share_ent_mean   = round(mean(share_ent, na.rm = TRUE), 2),
  share_ent_lo     = round(quantile(share_ent, 0.025, na.rm = TRUE), 2),
  share_ent_hi     = round(quantile(share_ent, 0.975, na.rm = TRUE), 2),
  n_valid          = sum(!is.na(delta_total))),
  by = .(regime, pharma_narrow)]
ci_tab[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
ci_tab <- ci_tab[order(pharma_narrow,
                        factor(regime, levels = c("losers","all","turnbull")))]

cat("\n--- 95% CI by regime × pharma ---\n", file = logf)
sink(logf, append = TRUE)
print(ci_tab[, .(pharma_lbl, regime, n_valid,
                 delta_total_mean, delta_total_lo, delta_total_hi,
                 share_int_mean, share_int_lo, share_int_hi)])
sink()

arrow::write_parquet(bs_all,
  path_v3("data/processed/bootstrap_ci.parquet"),
  compression = "snappy")

# 6. LaTeX ----------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Bootstrap 95\\% CI for BNE decomposition (B=500, cluster at auction level)}",
  "\\label{tab:v3_bootstrap_ci}",
  "\\small",
  "\\begin{tabular}{llrrr}",
  "\\toprule",
  "Class & Regime & $\\Delta$ total [95\\% CI] & share int. [95\\% CI] & share entry [95\\% CI] \\\\",
  "\\midrule")
for (i in seq_len(nrow(ci_tab))) {
  r <- ci_tab[i]
  tex <- c(tex, sprintf(
    "%s & %s & %.3f [%.3f, %.3f] & %.1f [%.1f, %.1f] & %.1f [%.1f, %.1f] \\\\",
    r$pharma_lbl, r$regime,
    r$delta_total_mean, r$delta_total_lo, r$delta_total_hi,
    r$share_int_mean,   r$share_int_lo,   r$share_int_hi,
    r$share_ent_mean,   r$share_ent_lo,   r$share_ent_hi))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Cluster bootstrap at the auction level, B=500 replicates.",
  "Each replicate resamples auctions with replacement within",
  "(period $\\times$ pharma) strata, refits $F_c$ in all three",
  "regimes, and runs the BNE MC with 500 auctions per scenario.",
  "CI endpoints are empirical 2.5 and 97.5 percentiles over the",
  "B replicates. Point estimates in main text use the full sample.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_bootstrap_ci.tex"))

log_step("51", "done", logf)
