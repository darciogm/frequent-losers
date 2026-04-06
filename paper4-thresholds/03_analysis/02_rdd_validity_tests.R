#!/usr/bin/env Rscript
# ============================================================================
# 02_rdd_validity_tests.R
# RDD Validity Tests for "Beneath the Surface"
#
# Tests:
#   1. McCrary/Cattaneo-Jansson-Ma density test (rddensity)
#   2. rdrobust with CCT bandwidth (data-driven)
#   3. Covariate balance at threshold
#   4. Placebo cutoffs
#   5. Donut-hole RDD
#   6. Summary statistics
#   7. Sample attrition table
#
# Output: tables and figures to Paper_eth_v2/
# ============================================================================

library(arrow)
library(fixest)
library(data.table)
library(rddensity)
library(rdrobust)

setFixest_nthreads(8)

OUT_DIR <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds/01_manuscript/Paper_eth_v2"

# ── Load data ──
cat("Loading data...\n")
df <- as.data.table(read_parquet(
  "/home/darciogm1/projetos/bitter-pills/paper4-thresholds/02_data/final/df_convite_winner_looser.parquet"
))
df[, flagvencedor := as.integer(flagvencedor)]
df[, MV := as.numeric(MV)]
cat(sprintf("  Full dataset: %s rows\n", format(nrow(df), big.mark = ",")))


# ============================================================================
# TEST 1: McCrary/Cattaneo-Jansson-Ma Density Test
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("TEST 1: DENSITY TEST (Cattaneo, Jansson & Ma, 2020)\n")
cat(strrep("=", 70), "\n\n")

# Use MV as running variable, cutoff at 0
mv_valid <- df[!is.na(MV) & MV != 0 & abs(MV) < 0.10, MV]
cat(sprintf("  Observations for density test (|MV| < 0.10): %s\n",
            format(length(mv_valid), big.mark = ",")))

density_test <- rddensity(mv_valid, c = 0)
cat("\n  ── rddensity results ──\n")
cat(sprintf("  T-statistic:  %.4f\n", density_test$test$t_jk))
cat(sprintf("  P-value:      %.4f\n", density_test$test$p_jk))
cat(sprintf("  N left:       %d\n", density_test$N$eff_l))
cat(sprintf("  N right:      %d\n", density_test$N$eff_r))
cat(sprintf("  BW left:      %.4f\n", density_test$h$left))
cat(sprintf("  BW right:     %.4f\n", density_test$h$right))

if (density_test$test$p_jk < 0.05) {
  cat("\n  ⚠ DENSITY DISCONTINUITY DETECTED (p < 0.05)\n")
  cat("  Interpretation: potential manipulation of running variable at cutoff.\n")
} else {
  cat("\n  ✓ No evidence of density discontinuity (p >= 0.05)\n")
  cat("  Interpretation: no evidence of manipulation at cutoff.\n")
}

# Save density plot
pdf(file.path(OUT_DIR, "fig_density_test.pdf"), width = 8, height = 5)
rdplotdensity(density_test, mv_valid,
              title = "",
              xlabel = "Margin of Victory (MV)",
              ylabel = "Density",
              plotN = 25)
dev.off()
cat("  Plot saved: fig_density_test.pdf\n")


# ============================================================================
# TEST 2: rdrobust with CCT data-driven bandwidth
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("TEST 2: RDROBUST WITH CCT BANDWIDTH\n")
cat(strrep("=", 70), "\n\n")

# Prepare data for rdrobust (needs outcome ~ running variable)
outcomes_rd <- list(
  list(var = "won_t_minus_1_market", label = "Incumbent (market)"),
  list(var = "last",                 label = "Last Bid"),
  list(var = "cumprof_won_120_market_item_std", label = "Backlog 120d (market, std)")
)

rd_results <- list()
for (spec in outcomes_rd) {
  drd <- df[!is.na(get(spec$var)) & !is.na(MV) & MV != 0]

  rd <- tryCatch(
    rdrobust(y = drd[[spec$var]], x = drd$MV, c = 0,
             kernel = "triangular", bwselect = "mserd"),
    error = function(e) { cat(sprintf("  ERROR [%s]: %s\n", spec$label, e$message)); NULL }
  )

  if (!is.null(rd)) {
    cat(sprintf("  ── %s ──\n", spec$label))
    cat(sprintf("    CCT Bandwidth (h):  %.5f\n", rd$bws[1, 1]))
    cat(sprintf("    Bias BW (b):        %.5f\n", rd$bws[1, 2]))
    cat(sprintf("    Coefficient:        %.4f\n", rd$coef[1]))
    cat(sprintf("    Robust SE:          %.4f\n", rd$se[3]))
    cat(sprintf("    Robust t:           %.2f\n", rd$z[3]))
    cat(sprintf("    Robust p:           %.4f\n", rd$pv[3]))
    cat(sprintf("    N left / right:     %d / %d\n", rd$N_h[1], rd$N_h[2]))
    cat(sprintf("    N effective:        %d\n", sum(rd$N_h)))
    cat("\n")

    rd_results[[spec$label]] <- data.table(
      outcome  = spec$label,
      variable = spec$var,
      bw_cct   = rd$bws[1, 1],
      coef     = rd$coef[1],
      se_conv  = rd$se[1],
      se_rob   = rd$se[3],
      t_rob    = rd$z[3],
      p_rob    = rd$pv[3],
      n_left   = rd$N_h[1],
      n_right  = rd$N_h[2],
      ci_lower = rd$ci[3, 1],
      ci_upper = rd$ci[3, 2]
    )

    # Save rdplot
    pdf(file.path(OUT_DIR, sprintf("fig_rdplot_%s.pdf", spec$var)), width = 8, height = 5)
    rdplot(y = drd[[spec$var]], x = drd$MV, c = 0,
           nbins = c(20, 20), p = 1,
           title = "",
           x.label = "Margin of Victory",
           y.label = spec$label)
    dev.off()
    cat(sprintf("    Plot saved: fig_rdplot_%s.pdf\n\n", spec$var))
  }
}

rd_table <- rbindlist(rd_results)
cat("\n  ── Summary: rdrobust CCT estimates ──\n")
print(rd_table[, .(outcome, bw_cct = round(bw_cct, 4),
                    coef = round(coef, 4), se_rob = round(se_rob, 4),
                    t_rob = round(t_rob, 2), p_rob = round(p_rob, 4),
                    N = n_left + n_right)])


# ============================================================================
# TEST 3: COVARIATE BALANCE AT THRESHOLD
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("TEST 3: COVARIATE BALANCE\n")
cat(strrep("=", 70), "\n\n")

covariates <- list(
  list(var = "age",          label = "Firm Age"),
  list(var = "limited_firm", label = "Limited Liability"),
  list(var = "equal_mun",    label = "Same Municipality")
)

balance_results <- list()
for (cov in covariates) {
  if (!cov$var %in% names(df)) {
    cat(sprintf("  %s: NOT FOUND\n", cov$var))
    next
  }

  d_bal <- df[!is.na(get(cov$var)) & !is.na(MV) & MV != 0]
  d_bal[, year_f := as.factor(year)]
  d_bal[, mkt_f  := as.factor(market_item)]

  # BW = 0.01 with FE
  d_bw <- d_bal[abs(MV) < 0.01]

  fit_nofe <- feols(as.formula(paste(cov$var, "~ flagvencedor * MV")),
                    data = d_bw, vcov = "hetero", lean = TRUE)
  fit_fe   <- feols(as.formula(paste(cov$var, "~ flagvencedor * MV | year_f + mkt_f")),
                    data = d_bw, cluster = "mkt_f", lean = TRUE)

  ct_nofe <- coeftable(fit_nofe)
  ct_fe   <- coeftable(fit_fe)
  idx_nofe <- which(rownames(ct_nofe) == "flagvencedor")
  idx_fe   <- which(rownames(ct_fe) == "flagvencedor")

  cat(sprintf("  ── %s ──\n", cov$label))
  cat(sprintf("    No FE:   coef=%.4f  SE=%.4f  t=%.2f  N=%s\n",
              ct_nofe[idx_nofe, 1], ct_nofe[idx_nofe, 2], ct_nofe[idx_nofe, 3],
              format(nrow(d_bw), big.mark = ",")))
  cat(sprintf("    With FE: coef=%.4f  SE=%.4f  t=%.2f  N=%s\n",
              ct_fe[idx_fe, 1], ct_fe[idx_fe, 2], ct_fe[idx_fe, 3],
              format(nrow(d_bw), big.mark = ",")))

  # Also rdrobust
  rd_cov <- tryCatch(
    rdrobust(y = d_bal[[cov$var]], x = d_bal$MV, c = 0, bwselect = "mserd"),
    error = function(e) NULL
  )
  if (!is.null(rd_cov)) {
    cat(sprintf("    rdrobust: coef=%.4f  rob.SE=%.4f  rob.t=%.2f  rob.p=%.4f  BW=%.4f\n",
                rd_cov$coef[1], rd_cov$se[3], rd_cov$z[3], rd_cov$pv[3], rd_cov$bws[1,1]))
  }
  cat("\n")

  balance_results[[cov$label]] <- data.table(
    covariate = cov$label,
    coef_nofe = ct_nofe[idx_nofe, 1],
    se_nofe   = ct_nofe[idx_nofe, 2],
    coef_fe   = ct_fe[idx_fe, 1],
    se_fe     = ct_fe[idx_fe, 2],
    n         = nrow(d_bw),
    mean_dv   = mean(d_bw[[cov$var]], na.rm = TRUE)
  )
}

bal_table <- rbindlist(balance_results)
cat("  ── Balance summary ──\n")
print(bal_table[, .(covariate, coef_fe = round(coef_fe, 4), se_fe = round(se_fe, 4),
                     n = format(n, big.mark = ","), mean_dv = round(mean_dv, 3))])


# ============================================================================
# TEST 4: PLACEBO CUTOFFS
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("TEST 4: PLACEBO CUTOFFS\n")
cat(strrep("=", 70), "\n\n")

placebo_cutoffs <- c(-0.03, -0.02, -0.01, -0.005,
                      0.005,  0.01,  0.02,  0.03)

run_placebo <- function(outcome, cutoff, bw = 0.01) {
  d <- df[!is.na(get(outcome)) & !is.na(MV) & MV != 0 &
            abs(MV - cutoff) < bw]
  if (nrow(d) < 200) return(NULL)

  d[, treat := as.integer(MV < cutoff)]
  d[, mv_centered := MV - cutoff]
  d[, year_f := as.factor(year)]
  d[, mkt_f  := as.factor(market_item)]

  fit <- tryCatch(
    feols(as.formula(paste(outcome, "~ treat * mv_centered | year_f + mkt_f")),
          data = d, cluster = "mkt_f", lean = TRUE),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)

  ct <- coeftable(fit)
  idx <- which(rownames(ct) == "treat")
  if (length(idx) == 0) return(NULL)

  data.table(
    outcome = outcome,
    cutoff  = cutoff,
    coef    = ct[idx, 1],
    se      = ct[idx, 2],
    tstat   = ct[idx, 3],
    pval    = ct[idx, 4],
    n       = nrow(d)
  )
}

for (outvar in c("won_t_minus_1_market", "last")) {
  plac <- rbindlist(Filter(Negate(is.null), lapply(placebo_cutoffs, function(c) {
    run_placebo(outvar, c, bw = 0.01)
  })))
  cat(sprintf("  Placebo cutoffs — %s:\n", outvar))
  if (nrow(plac) > 0) {
    print(plac[, .(cutoff, coef = round(coef, 4), se = round(se, 4),
                    t = round(tstat, 2), p = round(pval, 3),
                    n = format(n, big.mark = ","))])
  }
  cat("\n")
}


# ============================================================================
# TEST 5: DONUT-HOLE RDD
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("TEST 5: DONUT-HOLE RDD\n")
cat(strrep("=", 70), "\n\n")

donut_holes <- c(0, 0.0005, 0.001, 0.002, 0.003, 0.005)

run_donut <- function(outcome, donut, bw = 0.02) {
  d <- df[!is.na(get(outcome)) & !is.na(MV) & MV != 0 &
            abs(MV) < bw & abs(MV) >= donut]
  if (nrow(d) < 200) return(NULL)

  d[, year_f := as.factor(year)]
  d[, mkt_f  := as.factor(market_item)]

  fit <- tryCatch(
    feols(as.formula(paste(outcome, "~ flagvencedor * MV | year_f + mkt_f")),
          data = d, cluster = "mkt_f", lean = TRUE),
    error = function(e) NULL
  )
  if (is.null(fit)) return(NULL)

  ct <- coeftable(fit)
  idx <- which(rownames(ct) == "flagvencedor")
  if (length(idx) == 0) return(NULL)

  data.table(
    outcome = outcome,
    donut   = donut,
    coef    = ct[idx, 1],
    se      = ct[idx, 2],
    tstat   = ct[idx, 3],
    n       = nrow(d)
  )
}

for (outvar in c("won_t_minus_1_market", "last")) {
  don <- rbindlist(Filter(Negate(is.null), lapply(donut_holes, function(h) {
    run_donut(outvar, h, bw = 0.02)
  })))
  cat(sprintf("  Donut-hole — %s (BW=0.02):\n", outvar))
  if (nrow(don) > 0) {
    print(don[, .(donut, coef = round(coef, 4), se = round(se, 4),
                   t = round(tstat, 2), n = format(n, big.mark = ","))])
  }
  cat("\n")
}


# ============================================================================
# TEST 6: SUMMARY STATISTICS
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("TEST 6: SUMMARY STATISTICS\n")
cat(strrep("=", 70), "\n\n")

summ_vars <- c("MV", "flagvencedor", "won_t_minus_1_market", "last",
               "cumprof_won_120_market_item_std", "share_won90_market_item",
               "age", "limited_firm", "equal_mun")

summ <- rbindlist(lapply(summ_vars, function(v) {
  if (!v %in% names(df)) return(NULL)
  x <- df[[v]]
  x <- x[!is.na(x)]
  data.table(
    variable = v,
    n        = length(x),
    mean     = mean(x),
    sd       = sd(x),
    p25      = quantile(x, 0.25),
    median   = quantile(x, 0.50),
    p75      = quantile(x, 0.75)
  )
}))

cat("  Full sample summary statistics:\n")
print(summ[, .(variable, n = format(n, big.mark = ","),
               mean = round(mean, 3), sd = round(sd, 3),
               p25 = round(p25, 3), median = round(median, 3),
               p75 = round(p75, 3))])


# ============================================================================
# TEST 7: SAMPLE ATTRITION TABLE
# ============================================================================
cat("\n", strrep("=", 70), "\n")
cat("TEST 7: SAMPLE ATTRITION\n")
cat(strrep("=", 70), "\n\n")

cat(sprintf("  Raw bids (full parquet):                     %s\n",
            format(nrow(df), big.mark = ",")))
cat(sprintf("  Non-missing MV:                              %s\n",
            format(sum(!is.na(df$MV)), big.mark = ",")))
cat(sprintf("  MV != 0:                                     %s\n",
            format(sum(!is.na(df$MV) & df$MV != 0), big.mark = ",")))

for (bw in c(0.10, 0.05, 0.02, 0.01, 0.005)) {
  n <- sum(!is.na(df$MV) & df$MV != 0 & abs(df$MV) < bw)
  cat(sprintf("  |MV| < %.3f:                                 %s\n",
              bw, format(n, big.mark = ",")))
}

# By outcome availability within BW=0.02
d02 <- df[!is.na(MV) & MV != 0 & abs(MV) < 0.02]
cat(sprintf("\n  Within BW=0.02 (N=%s):\n", format(nrow(d02), big.mark = ",")))
for (v in c("won_t_minus_1_market", "last", "cumprof_won_120_market_item_std",
            "share_won90_market_item", "age", "limited_firm", "equal_mun")) {
  if (v %in% names(d02)) {
    cat(sprintf("    %s: %s non-missing\n", v,
                format(sum(!is.na(d02[[v]])), big.mark = ",")))
  }
}

cat("\n", strrep("=", 70), "\n")
cat("ALL TESTS COMPLETE\n")
cat(strrep("=", 70), "\n")
