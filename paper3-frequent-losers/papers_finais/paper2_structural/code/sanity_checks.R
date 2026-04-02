# ==========================================================================
# sanity_checks.R — F1: QQ-plot, F2: Bootstrap CI for σ_c/σ_g,
#                   F3: Random placebo FL assignment
#
# Requires: v3/data/processed/bid_level_analysis.parquet
# Outputs:  images/fig_qqplot_regime2.pdf
#           work/v6/tables/bootstrap_ratio_ci.csv
#           work/v6/tables/placebo_results.csv
# ==========================================================================
cat("=== Sanity Checks (F1-F3) ===\n")
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})
setDTthreads(16L)
BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT_T <- file.path(BASE, "papers_finais/paper2_structural/work/v6/tables")
OUT_F <- file.path(BASE, "papers_finais/paper2_structural/manuscript/images")

# ── Load data ─────────────────────────────────────────────────────
cat("Loading bid-level data...\n")
bl <- as.data.table(read_parquet(file.path(BASE, "v3/data/processed/bid_level_analysis.parquet")))

winners <- bl[won == 1L & !is.na(bid_price) & bid_price > 0,
              .(win_price = min(bid_price)), by = .(oc_code, item_code)]

losers <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
losers <- merge(losers, winners, by = c("oc_code", "item_code"), all.x = FALSE)
losers[, log_spread := log(bid_price) - log(win_price)]

fl_pos <- losers[is_fl == 1L & log_spread > 0 & is.finite(log_spread)]
nonfl_pos <- losers[is_fl == 0L & log_spread > 0 & is.finite(log_spread)]

rm(bl, winners); gc(verbose = FALSE)  # free raw data after subsetting

# Slim down losers for F3 — only keep columns needed later
# (firm_id, oc_code, item_code, is_fl, log_spread)
losers_cols <- c("firm_id", "oc_code", "item_code", "is_fl", "log_spread")
losers <- losers[log_spread > 0 & is.finite(log_spread),
                 ..losers_cols]
gc(verbose = FALSE)

eps_hat <- mean(fl_pos$log_spread)
sig_c <- sd(fl_pos$log_spread)
sig_g <- sd(nonfl_pos$log_spread)
cat("eps_hat:", round(eps_hat, 4), "sig_c:", round(sig_c, 4),
    "sig_g:", round(sig_g, 4), "\n")
cat("Ratio:", round(sig_c / sig_g, 4), "\n")

# ══════════════════════════════════════════════════════════════════
# F1: QQ-Plot — FL bids vs fitted truncated normal (Regime 2)
# ══════════════════════════════════════════════════════════════════
cat("\n=== F1: QQ-Plot ===\n")

# Theoretical quantiles from N(eps_hat, sig_c^2) truncated at 0
n_qq <- min(nrow(fl_pos), 5000)  # subsample for clean plot
set.seed(42)
qq_sample <- sort(sample(fl_pos$log_spread, n_qq))
p_seq <- (seq_len(n_qq) - 0.5) / n_qq

# Truncated normal quantiles: inverse CDF of TN(eps, sig_c, 0, Inf)
alpha_trunc <- -eps_hat / sig_c
Phi_alpha <- pnorm(alpha_trunc)
theoretical_q <- eps_hat + sig_c * qnorm(Phi_alpha + p_seq * (1 - Phi_alpha))

# Also compute standard normal quantiles for comparison
normal_q <- qnorm(p_seq, mean = eps_hat, sd = sig_c)

pdf(file.path(OUT_F, "fig_qqplot_regime2.pdf"), width = 7, height = 6)
par(mar = c(4.5, 4.5, 2, 1))
plot(theoretical_q, qq_sample,
     pch = 16, cex = 0.3, col = rgb(0, 0, 0, 0.3),
     xlab = "Theoretical quantiles (truncated normal)",
     ylab = "Observed FL bid log-spread",
     main = "QQ-Plot: FL Bids vs. Fitted Regime 2 Distribution",
     cex.lab = 1.1, cex.main = 1.1)
abline(0, 1, col = "red", lwd = 2)

# Add 95% envelope via simulation
set.seed(2026)
n_sim <- 200
envelope <- matrix(NA, n_sim, n_qq)
for (s in seq_len(n_sim)) {
  sim_draws <- rnorm(n_qq, eps_hat, sig_c)
  sim_draws <- sim_draws[sim_draws > 0]
  if (length(sim_draws) >= n_qq * 0.8) {
    envelope[s, seq_len(min(length(sim_draws), n_qq))] <-
      sort(sim_draws[seq_len(min(length(sim_draws), n_qq))])
  }
}
env_lo <- apply(envelope, 2, quantile, 0.025, na.rm = TRUE)
env_hi <- apply(envelope, 2, quantile, 0.975, na.rm = TRUE)
lines(theoretical_q, env_lo, col = "blue", lty = 2)
lines(theoretical_q, env_hi, col = "blue", lty = 2)
legend("bottomright",
       legend = c("45-degree line", "95% simulation envelope"),
       col = c("red", "blue"), lty = c(1, 2), lwd = c(2, 1),
       bty = "n", cex = 0.9)
dev.off()
cat("QQ-plot saved to", file.path(OUT_F, "fig_qqplot_regime2.pdf"), "\n")

# KS test for completeness
# CDF of TN(mu, sigma, lower=0): F(x) = [Phi((x-mu)/sigma) - Phi(-mu/sigma)] / [1 - Phi(-mu/sigma)]
ks_trunc <- ks.test(fl_pos$log_spread, function(x) {
  (pnorm((x - eps_hat) / sig_c) - Phi_alpha) / (1 - Phi_alpha)
})
cat("KS statistic (truncated normal):", round(ks_trunc$statistic, 4), "\n")

# ══════════════════════════════════════════════════════════════════
# F2: Bootstrap CI for σ_c / σ_g
# ══════════════════════════════════════════════════════════════════
cat("\n=== F2: Bootstrap CI for dispersion ratio ===\n")

set.seed(42)
B <- 1000
tids_fl <- unique(fl_pos[, .(oc_code, item_code)])
tids_nonfl <- unique(nonfl_pos[, .(oc_code, item_code)])

# Pre-set keys for faster joins
setkey(fl_pos, oc_code, item_code)
setkey(nonfl_pos, oc_code, item_code)

boot_ratio <- numeric(B)
boot_sigc <- numeric(B)
boot_sigg <- numeric(B)

for (b in seq_len(B)) {
  # Resample tenders with replacement (cluster bootstrap).
  # allow.cartesian = TRUE is correct here: if a tender is drawn K times,
  # the join replicates its bids K times (proper cluster bootstrap).
  idx_fl <- sample(nrow(tids_fl), nrow(tids_fl), replace = TRUE)
  bt_fl <- tids_fl[idx_fl]
  bfl <- fl_pos[bt_fl, on = .(oc_code, item_code), nomatch = NULL, allow.cartesian = TRUE]

  idx_nonfl <- sample(nrow(tids_nonfl), nrow(tids_nonfl), replace = TRUE)
  bt_nonfl <- tids_nonfl[idx_nonfl]
  bnfl <- nonfl_pos[bt_nonfl, on = .(oc_code, item_code), nomatch = NULL, allow.cartesian = TRUE]

  if (nrow(bfl) > 100 & nrow(bnfl) > 100) {
    boot_sigc[b] <- sd(bfl$log_spread)
    boot_sigg[b] <- sd(bnfl$log_spread)
    boot_ratio[b] <- boot_sigc[b] / boot_sigg[b]
  } else {
    boot_ratio[b] <- boot_sigc[b] <- boot_sigg[b] <- NA
  }
  if (b %% 200 == 0) { cat("  Bootstrap rep", b, "/", B, "\n"); gc(verbose = FALSE) }
}

ratio_ci <- quantile(boot_ratio, c(0.025, 0.5, 0.975), na.rm = TRUE)
sigc_ci <- quantile(boot_sigc, c(0.025, 0.975), na.rm = TRUE)
sigg_ci <- quantile(boot_sigg, c(0.025, 0.975), na.rm = TRUE)

cat("Dispersion ratio: ", round(sig_c / sig_g, 4), "\n")
cat("  95% CI: [", round(ratio_ci[1], 4), ",", round(ratio_ci[3], 4), "]\n")
cat("  Median: ", round(ratio_ci[2], 4), "\n")
cat("  SE:     ", round(sd(boot_ratio, na.rm = TRUE), 4), "\n")
cat("  CI includes 1.0:", ratio_ci[3] >= 1.0, "\n")

write.csv(data.frame(
  param = c("ratio_point", "ratio_lo", "ratio_median", "ratio_hi",
            "ratio_se", "sigc_lo", "sigc_hi", "sigg_lo", "sigg_hi",
            "ci_includes_one"),
  value = c(sig_c / sig_g, ratio_ci[1], ratio_ci[2], ratio_ci[3],
            sd(boot_ratio, na.rm = TRUE),
            sigc_ci[1], sigc_ci[2], sigg_ci[1], sigg_ci[2],
            as.integer(ratio_ci[3] >= 1.0))
), file.path(OUT_T, "bootstrap_ratio_ci.csv"), row.names = FALSE)
cat("Bootstrap results saved.\n")

# ══════════════════════════════════════════════════════════════════
# F3: Random Placebo — assign FL labels to 2,735 random firms
# ══════════════════════════════════════════════════════════════════
cat("\n=== F3: Random Placebo ===\n")
gc(verbose = FALSE)  # reclaim memory from F2

# Get unique FL firms and their count
fl_firms <- unique(fl_pos$firm_id)
n_fl <- length(fl_firms)
all_firms <- unique(losers$firm_id)
non_fl_firms <- setdiff(all_firms, fl_firms)
cat("Real FL firms:", n_fl, "\n")
cat("Available non-FL firms:", length(non_fl_firms), "\n")

# Pre-index losers by firm_id for faster subsetting
setkey(losers, firm_id)

set.seed(2026)
n_placebo <- 100  # number of placebo draws
placebo_ratios <- numeric(n_placebo)
placebo_ks <- numeric(n_placebo)
placebo_pairwise <- numeric(n_placebo)

for (p in seq_len(n_placebo)) {
  # Random "FL" assignment
  fake_fl <- sample(non_fl_firms, min(n_fl, length(non_fl_firms)),
                    replace = FALSE)
  fake_fl_bids <- losers[firm_id %in% fake_fl]
  fake_nonfl_bids <- losers[!firm_id %in% fake_fl]

  if (nrow(fake_fl_bids) > 50) {
    fake_sigc <- sd(fake_fl_bids$log_spread)
    fake_sigg <- sd(fake_nonfl_bids$log_spread)
    placebo_ratios[p] <- fake_sigc / fake_sigg

    # KS test (subsample both sides for speed if large)
    n_ks_max <- 50000L
    fl_samp <- if (nrow(fake_fl_bids) > n_ks_max) fake_fl_bids[sample(.N, n_ks_max)]$log_spread else fake_fl_bids$log_spread
    nfl_samp <- if (nrow(fake_nonfl_bids) > n_ks_max) fake_nonfl_bids[sample(.N, n_ks_max)]$log_spread else fake_nonfl_bids$log_spread
    ks_p <- ks.test(fl_samp, nfl_samp)
    placebo_ks[p] <- ks_p$statistic

    # Pairwise product (subsample for speed)
    subs <- fake_fl_bids[sample(.N, min(.N, 5000))]
    # Within-tender pairwise product (vectorized: avoids combn explosion)
    # Identity: mean(r_i * r_j) for i<j = (sum(r)^2 - sum(r^2)) / (N*(N-1))
    pp <- subs[, {
      if (.N >= 2) {
        resids <- log_spread - mean(log_spread)
        sr <- sum(resids)
        sr2 <- sum(resids^2)
        nn <- .N
        .(pp = (sr^2 - sr2) / (nn * (nn - 1L)))
      } else {
        .(pp = NA_real_)
      }
    }, by = .(oc_code, item_code)]
    placebo_pairwise[p] <- mean(pp$pp, na.rm = TRUE)
  } else {
    placebo_ratios[p] <- placebo_ks[p] <- placebo_pairwise[p] <- NA
  }
  if (p %% 20 == 0) { cat("  Placebo rep", p, "/", n_placebo, "\n"); gc(verbose = FALSE) }
}

cat("\nPlacebo results (", n_placebo, "draws):\n")
cat("  Mean ratio (fake σ_c / σ_g):", round(mean(placebo_ratios, na.rm = TRUE), 4), "\n")
cat("  SD ratio:", round(sd(placebo_ratios, na.rm = TRUE), 4), "\n")
cat("  Real ratio:", round(sig_c / sig_g, 4), "\n")
cat("  % placebo ratios < real ratio:", round(100 * mean(placebo_ratios < (sig_c / sig_g), na.rm = TRUE), 1), "%\n")
cat("  Mean placebo KS:", round(mean(placebo_ks, na.rm = TRUE), 4), "\n")
cat("  Real KS:", round(ks_trunc$statistic, 4), "\n")

write.csv(data.frame(
  param = c("real_ratio", "placebo_mean_ratio", "placebo_sd_ratio",
            "pct_below_real", "real_ks", "placebo_mean_ks",
            "placebo_mean_pairwise", "n_placebo"),
  value = c(sig_c / sig_g,
            mean(placebo_ratios, na.rm = TRUE),
            sd(placebo_ratios, na.rm = TRUE),
            100 * mean(placebo_ratios < (sig_c / sig_g), na.rm = TRUE),
            ks_trunc$statistic,
            mean(placebo_ks, na.rm = TRUE),
            mean(placebo_pairwise, na.rm = TRUE),
            n_placebo)
), file.path(OUT_T, "placebo_results.csv"), row.names = FALSE)

cat("\nPlacebo results saved.\n")
cat("=== ALL SANITY CHECKS DONE ===\n")
