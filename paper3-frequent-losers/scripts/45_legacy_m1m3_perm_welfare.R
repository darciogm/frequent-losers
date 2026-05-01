# ============================================================================
# 45_legacy_m1m3_perm_welfare.R — re-run M1/M2/M3, dyadic permutation null,
# and welfare bounds back-of-envelope from current data
# Paper 3 v14
#
# Outputs:
#   output/legacy_constants/m1m3_results.csv
#   output/legacy_constants/dyadic_permutation.csv
#   output/legacy_constants/welfare_bounds.csv
# ============================================================================

cat("=== 45_legacy_m1m3_perm_welfare.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "legacy_constants")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- M1, M2, M3 from /tmp prepared dataset ------------------------------
dt <- readRDS("/tmp/p3_prepared.rds")
cat(sprintf("\n  Loaded %s rows from /tmp/p3_prepared.rds\n",
            format(nrow(dt), big.mark=",")))

# M1: log(n_firms_excl + 1) ~ losers + convite | item + year + pbu
cat("\n  M1: Competitive displacement (FL on log(n_genuine+1))\n")
dt[, log_n_genuine := log(n_firms_excl + 1)]
m1 <- feols(log_n_genuine ~ losers + convite | item_f + year_f + pbu_f,
            data = dt, cluster = ~item_f, fixef.rm = "none")
ct1 <- coeftable(m1)
m1_coef <- ct1["losers","Estimate"]; m1_se <- ct1["losers","Std. Error"]
m1_p    <- ct1["losers","Pr(>|t|)"]
cat(sprintf("    losers coef = %+.4f (SE %.4f, p = %.4g)  N = %s\n",
            m1_coef, m1_se, m1_p, format(m1$nobs, big.mark=",")))

# M2: price_ratio ~ losers + convite | item + year + pbu
cat("\n  M2: Reference price calibration\n")
d_m2 <- dt[!is.na(price_ratio) & !is.na(lneg_price)]
cat(sprintf("    valid price_ratio: %s\n", format(nrow(d_m2), big.mark=",")))
m2 <- feols(price_ratio ~ losers + convite | item_f + year_f + pbu_f,
            data = d_m2, cluster = ~item_f, fixef.rm = "none")
ct2 <- coeftable(m2)
m2_coef <- ct2["losers","Estimate"]; m2_se <- ct2["losers","Std. Error"]
m2_p    <- ct2["losers","Pr(>|t|)"]
cat(sprintf("    losers coef = %+.4f (SE %.4f, p = %.4g)  N = %s\n",
            m2_coef, m2_se, m2_p, format(m2$nobs, big.mark=",")))

# M3: market-year panel, lagged price predicts FL entry
cat("\n  M3: Reverse causality (lagged price -> FL entry)\n")
dt[, market_id := paste0(pbu_code, "_", item_group)]
panel <- dt[, .(
  fl_present = max(losers, na.rm = TRUE),
  mean_log_price = mean(lneg_price, na.rm = TRUE),
  n_obs = .N
), by = .(market_id, year)]
setkey(panel, market_id, year)
panel[, log_price_lag := shift(mean_log_price, 1L, type = "lag"),
      by = market_id]
d_m3 <- panel[!is.na(log_price_lag) & is.finite(log_price_lag) &
                !is.na(fl_present)]
cat(sprintf("    market-year panel: %s rows\n",
            format(nrow(d_m3), big.mark=",")))
d_m3[, market_id_f := factor(market_id)]
d_m3[, year_f      := factor(year)]
m3 <- feols(fl_present ~ log_price_lag | market_id_f + year_f,
            data = d_m3, cluster = ~market_id_f, fixef.rm = "none")
ct3 <- coeftable(m3)
m3_coef <- ct3["log_price_lag","Estimate"]
m3_se   <- ct3["log_price_lag","Std. Error"]
m3_p    <- ct3["log_price_lag","Pr(>|t|)"]
cat(sprintf("    log_price_lag coef = %+.4f (SE %.4f, p = %.4g)  N = %s\n",
            m3_coef, m3_se, m3_p, format(m3$nobs, big.mark=",")))

m_dt <- data.table(
  metric = c("m1_coef","m1_se","m1_p","m1_n",
             "m2_coef","m2_se","m2_p","m2_n",
             "m3_coef","m3_se","m3_p","m3_n"),
  value  = c(m1_coef, m1_se, m1_p, m1$nobs,
             m2_coef, m2_se, m2_p, m2$nobs,
             m3_coef, m3_se, m3_p, m3$nobs)
)
fwrite(m_dt, file.path(OUT, "m1m3_results.csv"))
cat(sprintf("\n  Wrote %s\n", file.path(OUT, "m1m3_results.csv")))

# ---- Dyadic permutation: observed vs null mean --------------------------
cat("\n  Dyadic permutation: 1,000-iter stratified test on FL-winner pairs\n")
fp <- as.data.table(read_parquet(file.path(BASE,"data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm <- as.data.table(read_parquet(file.path(BASE,"data/processed/firm_tender_map.parquet")))
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]

THRESH <- 14L
fp[, is_fl := as.integer(always_loser == 1L & tenders_count > THRESH)]
fl_codes <- fp[is_fl == 1L, firm_code]
al_codes <- fp[always_loser == 1L, firm_code]

winners <- ftm[won == 1L, .(oc_item_key, winner = firm_code)]
losers_long <- ftm[won == 0L, .(oc_item_key, loser = firm_code)]
loser_winner <- merge(losers_long, winners, by = "oc_item_key",
                       allow.cartesian = TRUE)

# Observed: pairs (loser, winner) where loser is FL, count shared
obs_pairs <- loser_winner[loser %in% fl_codes,
                           .N, by = .(loser, winner)]
obs_pairs_5plus <- nrow(obs_pairs[N >= 5L])
cat(sprintf("    Observed FL-winner pairs >= 5 shared: %d\n",
            obs_pairs_5plus))

# Permutation null: shuffle FL labels within always-losers, count pairs
set.seed(20260430)
n_iter <- 1000L
null_5plus <- integer(n_iter)
fp_al <- fp[always_loser == 1L]
n_fl  <- sum(fp_al$is_fl == 1)
for (it in seq_len(n_iter)) {
  perm_fl <- sample(fp_al$firm_code, n_fl)
  pairs <- loser_winner[loser %in% perm_fl, .N, by = .(loser, winner)]
  null_5plus[it] <- nrow(pairs[N >= 5L])
}
null_mean <- mean(null_5plus)
null_sd   <- sd(null_5plus)
p_emp     <- mean(null_5plus >= obs_pairs_5plus)
cat(sprintf("    Null mean (1,000 iter): %.1f (SD %.1f)  empirical p = %.4f\n",
            null_mean, null_sd, p_emp))

# Top-10 FL-winner pairs: average shared count
obs_top10 <- mean(head(obs_pairs[order(-N)]$N, 10L))
null_top10 <- numeric(n_iter)
for (it in seq_len(n_iter)) {
  perm_fl <- sample(fp_al$firm_code, n_fl)
  pairs <- loser_winner[loser %in% perm_fl, .N, by = .(loser, winner)]
  null_top10[it] <- mean(head(pairs[order(-N)]$N, 10L))
}
top10_null_mean <- mean(null_top10)
top10_p <- mean(null_top10 >= obs_top10)
cat(sprintf("    Observed top-10 mean: %.1f  Null mean: %.1f  p = %.4f\n",
            obs_top10, top10_null_mean, top10_p))

perm_dt <- data.table(
  metric = c("dyadic_obs_5plus","dyadic_null_mean_5plus",
             "dyadic_null_sd_5plus","dyadic_p_5plus",
             "dyadic_obs_top10","dyadic_null_mean_top10","dyadic_p_top10"),
  value  = c(obs_pairs_5plus, null_mean, null_sd, p_emp,
             obs_top10, top10_null_mean, top10_p)
)
fwrite(perm_dt, file.path(OUT, "dyadic_permutation.csv"))
cat(sprintf("\n  Wrote %s\n", file.path(OUT, "dyadic_permutation.csv")))

# ---- Welfare bounds (0.3-0.9% of spending) ------------------------------
cat("\n  Welfare bounds back-of-envelope\n")
# Total BEC spending (sum lneg_price * qty across sample)
# Approximation using `bid_unit_price_negot_min` if available
if ("bid_unit_price_negot_min" %in% names(dt)) {
  dt[, neg_price := exp(lneg_price)]
  total_spending <- sum(dt$neg_price, na.rm = TRUE)
  fl_spending    <- sum(dt[losers == 1L]$neg_price, na.rm = TRUE)
  cat(sprintf("    Total BEC spending (sum exp(lneg_price)): R$ %.2e\n",
              total_spending))
  cat(sprintf("    FL-present spending: R$ %.2e (%.1f%% of total)\n",
              fl_spending, 100 * fl_spending / total_spending))

  # Welfare gain bounds: integration of FL coefficient over FL-present
  # spending, with low and high coefficients (cross-fit 0.036 vs OLS 0.064).
  beta_low  <- 0.036  # cross-fit
  beta_high <- 0.064  # OLS general+PBU
  # Welfare overcharge fraction = (exp(beta) - 1) on FL-present, then
  # divide by total spending.
  ovr_low  <- (exp(beta_low)  - 1) * fl_spending / total_spending
  ovr_high <- (exp(beta_high) - 1) * fl_spending / total_spending
  cat(sprintf("    Welfare gain bounds: %.2f%% to %.2f%% of total spending\n",
              100 * ovr_low, 100 * ovr_high))

  # FL-present spending in BRL terms
  cat(sprintf("    FL spending share: %.2f%% (gives ~R$%.0fM lower bound, ~R$%.0fM upper bound)\n",
              100 * fl_spending / total_spending,
              ovr_low * total_spending / 1e6,
              ovr_high * total_spending / 1e6))

  welf_dt <- data.table(
    metric = c("total_spending_brl", "fl_spending_brl", "fl_share",
               "beta_low", "beta_high",
               "welfare_low_pct_of_total", "welfare_high_pct_of_total",
               "welfare_low_brl", "welfare_high_brl"),
    value  = c(total_spending, fl_spending, fl_spending/total_spending,
               beta_low, beta_high,
               100 * ovr_low, 100 * ovr_high,
               ovr_low * total_spending, ovr_high * total_spending)
  )
} else {
  cat("    bid_unit_price_negot_min not available; skipping spending sums\n")
  welf_dt <- data.table(metric=character(), value=numeric())
}
fwrite(welf_dt, file.path(OUT, "welfare_bounds.csv"))
cat(sprintf("\n  Wrote %s\n", file.path(OUT, "welfare_bounds.csv")))

cat("\n  Done.\n")
