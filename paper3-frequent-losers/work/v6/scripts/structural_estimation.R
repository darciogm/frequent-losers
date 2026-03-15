# ==========================================================================
# structural_estimation.R — M1: Structural parameter estimation (FIXED)
# ==========================================================================
cat("=== Structural Estimation (M1) ===\n")
suppressPackageStartupMessages({library(data.table);library(arrow);library(fixest)})
setDTthreads(16L)
OUT <- "work/v6/tables"

cat("Loading bid_level_analysis.parquet...\n")
bl <- as.data.table(read_parquet("v3/data/processed/bid_level_analysis.parquet"))
cat("Total rows:", formatC(nrow(bl), big.mark=","), "\n")

# Get winning price per tender from WINNERS' bid_price
winners <- bl[won == 1L & !is.na(bid_price) & bid_price > 0,
              .(win_price = min(bid_price)), by=.(oc_code, item_code)]
cat("Tenders with winners:", formatC(nrow(winners), big.mark=","), "\n")

# Get losing bids with valid prices, merge with winning price
losers <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
losers <- merge(losers, winners, by=c("oc_code","item_code"), all.x=FALSE)
losers[, log_bid := log(bid_price)]
losers[, log_win := log(win_price)]
losers[, log_spread := log_bid - log_win]
losers[, year := as.integer(sub(".*/", "", month_year))]
cat("Matched losers:", formatC(nrow(losers), big.mark=","), "\n")
cat("FL losers:", formatC(sum(losers$is_fl == 1L), big.mark=","), "\n")

# ── STAGE 1: Genuine bids ────────────────────────────────────────
cat("\n--- Stage 1: Genuine bids ---\n")
genuine <- losers[is_fl == 0L]
cat("N:", formatC(nrow(genuine), big.mark=","), "\n")
m_g <- feols(log_bid ~ 1 | item_code + year, data=genuine, lean=TRUE)
sigma_g <- sd(residuals(m_g))
mu_g <- mean(genuine$log_bid)
r2_g <- fitstat(m_g, "r2")[[1]]
cat("  mu_g:", round(mu_g, 4), "sigma_g:", round(sigma_g, 4), "R2:", round(r2_g, 4), "\n")
rm(m_g); gc(verbose=FALSE)

# ── STAGE 2: Cover bids ──────────────────────────────────────────
cat("\n--- Stage 2: FL bids ---\n")
fl <- losers[is_fl == 1L]
fl_pos <- fl[log_spread > 0 & is.finite(log_spread)]
nonfl_pos <- genuine[log_spread > 0 & is.finite(log_spread)]
cat("  FL above win:", formatC(nrow(fl_pos), big.mark=","),
    "(", round(100*nrow(fl_pos)/nrow(fl), 1), "%)\n")
cat("  FL mean spread:", round(mean(fl_pos$log_spread), 4), "\n")
cat("  FL SD spread:", round(sd(fl_pos$log_spread), 4), "\n")
cat("  Non-FL mean spread:", round(mean(nonfl_pos$log_spread), 4), "\n")
cat("  Non-FL SD spread:", round(sd(nonfl_pos$log_spread), 4), "\n")

# Regime 1: Uniform[0, delta]
delta_hat <- as.numeric(quantile(fl_pos$log_spread, 0.99))
delta_med <- median(fl_pos$log_spread)
n_r1 <- nrow(fl_pos)
ll_r1 <- -n_r1 * log(delta_hat)
bic_r1 <- -2*ll_r1 + 1*log(n_r1)
ks_r1 <- ks.test(fl_pos$log_spread / delta_hat, "punif")
cat("\n  R1: delta=", round(delta_hat, 4), "LL=", round(ll_r1, 1),
    "BIC=", round(bic_r1, 1), "KS=", round(ks_r1$statistic, 4), "\n")

# Regime 2: Normal(epsilon, sigma_c^2)
eps_hat <- mean(fl_pos$log_spread)
sig_c <- sd(fl_pos$log_spread)
ll_r2 <- sum(dnorm(fl_pos$log_spread, eps_hat, sig_c, log=TRUE))
bic_r2 <- -2*ll_r2 + 2*log(n_r1)
ks_r2 <- ks.test(fl_pos$log_spread, "pnorm", eps_hat, sig_c)
cat("  R2: eps=", round(eps_hat, 4), "sig_c=", round(sig_c, 4),
    "LL=", round(ll_r2, 1), "BIC=", round(bic_r2, 1),
    "KS=", round(ks_r2$statistic, 4), "\n")

selected <- if(bic_r1 < bic_r2) "Regime 1 (Complementary)" else "Regime 2 (Coordinated)"
cat("\n  Selected:", selected, "\n")
cat("  Delta BIC:", round(bic_r2 - bic_r1, 1), "\n")

# Implied markup
tp <- losers[, .(lp = log(first(win_price)), has_fl = as.integer(any(is_fl == 1L))),
             by = .(oc_code, item_code)]
raw_gap <- tp[has_fl == 1, mean(lp)] - tp[has_fl == 0, mean(lp)]
pct_mk <- 100 * (exp(raw_gap) - 1)
cv_ratio <- (sd(fl_pos$log_spread)/abs(mean(fl_pos$log_spread))) /
            (sd(nonfl_pos$log_spread)/abs(mean(nonfl_pos$log_spread)))
cat("  Markup:", round(pct_mk, 1), "%\n")
cat("  CV ratio:", round(cv_ratio, 3), "\n")

# Bootstrap (100 reps)
cat("\n--- Bootstrap (100 reps) ---\n")
set.seed(42)
tids <- unique(fl_pos[, .(oc_code, item_code)])
b_d <- b_e <- b_s <- numeric(100)
for(b in 1:100) {
  bt <- tids[sample(.N, .N, replace=TRUE)]
  bfl <- fl_pos[bt, on=.(oc_code, item_code), nomatch=NULL, allow.cartesian=TRUE]
  if(nrow(bfl) > 50) {
    b_d[b] <- as.numeric(quantile(bfl$log_spread, 0.99))
    b_e[b] <- mean(bfl$log_spread)
    b_s[b] <- sd(bfl$log_spread)
  } else b_d[b] <- b_e[b] <- b_s[b] <- NA
}
se_d <- sd(b_d, na.rm=TRUE); se_e <- sd(b_e, na.rm=TRUE); se_s <- sd(b_s, na.rm=TRUE)
ci_d <- quantile(b_d, c(.025,.975), na.rm=TRUE)
ci_e <- quantile(b_e, c(.025,.975), na.rm=TRUE)
ci_s <- quantile(b_s, c(.025,.975), na.rm=TRUE)
cat("  SE(delta):", round(se_d, 4), "SE(eps):", round(se_e, 4), "SE(sig_c):", round(se_s, 4), "\n")

# ── Save CSV ─────────────────────────────────────────────────────
write.csv(data.frame(
  param = c("mu_g","sigma_g","r2_genuine","n_genuine","n_fl",
            "delta_hat","se_delta","ci_delta_lo","ci_delta_hi","delta_median",
            "loglik_r1","bic_r1","ks_r1",
            "epsilon_hat","se_epsilon","ci_eps_lo","ci_eps_hi",
            "sigma_c","se_sigma_c","ci_sigc_lo","ci_sigc_hi",
            "loglik_r2","bic_r2","ks_r2",
            "selected","delta_bic","cv_ratio","pct_markup"),
  value = c(mu_g, sigma_g, r2_g, nrow(genuine), nrow(fl),
            delta_hat, se_d, ci_d[1], ci_d[2], delta_med,
            ll_r1, bic_r1, ks_r1$statistic,
            eps_hat, se_e, ci_e[1], ci_e[2],
            sig_c, se_s, ci_s[1], ci_s[2],
            ll_r2, bic_r2, ks_r2$statistic,
            ifelse(bic_r1 < bic_r2, 1, 2), bic_r2-bic_r1, cv_ratio, pct_mk)
), file.path(OUT, "structural_params.csv"), row.names=FALSE)

cat("\n=== DONE ===\n")
