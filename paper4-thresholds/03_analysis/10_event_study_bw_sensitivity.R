#!/usr/bin/env Rscript
# ============================================================================
# 10_event_study_bw_sensitivity.R — Bandwidth sensitivity of trend breaks
#
# Purpose: confirm that the trend-break estimates (k=0 placebo subtracted from
#   k=0 impact) are stable across bandwidths {0.005, 0.01, 0.02, 0.05}.
#   Tests both employment YoY (trend break) and survival (DiD level effect).
#
# Estimands:
#   - Employment trend break: coef(dlog_emp_yoy_t0) − coef(dlog_emp_yoy_tm1)
#     at fixed bandwidth h
#   - Survival DiD: coef(survived_tp1) − coef(survived_tm1) at fixed h
#
# Inputs:
#   02_data/final/rd_pilot_pregao_firmyear_sample.parquet
#
# Outputs:
#   02_data/intermediate/rd_event_study_bw_table.csv
#   stdout text report
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rdrobust)
})

BASE        <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
PREGAO_PATH <- file.path(BASE, "02_data/final/rd_pilot_pregao_firmyear_sample.parquet")
TABLE_PATH  <- file.path(BASE, "02_data/intermediate/rd_event_study_bw_table.csv")

cat("Bandwidth sensitivity — event study trend breaks\n")
cat("Run at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat(strrep("=", 70), "\n\n")

dt <- as.data.table(read_parquet(PREGAO_PATH))
dt[, cluster_id := .GRP, by = cnpj_raiz]
cat("Sample:", format(nrow(dt), big.mark = ","), "rows\n\n")

# Q4 sample
q4_cutoff <- quantile(dt$log_ref_price, 0.75, na.rm = TRUE)
q4 <- dt[!is.na(log_ref_price) & log_ref_price > q4_cutoff]
q4[, cluster_id := .GRP, by = cnpj_raiz]
cat("Q4 sample:", format(nrow(q4), big.mark = ","), "rows\n\n")

# ─────────────────────────────────────────────────────────────────────
fixed_h <- function(d, y_name, h) {
  idx <- is.finite(d[[y_name]])
  if (sum(idx) < 200) return(list(coef = NA, se = NA, n_L = NA, n_R = NA))
  fit <- tryCatch(
    rdrobust(y = d[[y_name]][idx], x = d$running[idx], c = 0, h = h,
             cluster = d$cluster_id[idx],
             kernel = "triangular", p = 1),
    error = function(e) NULL)
  if (is.null(fit)) return(list(coef = NA, se = NA, n_L = NA, n_R = NA))
  list(coef = fit$coef[1, 1], se = fit$se[1, 1],
       n_L = fit$N_h[1], n_R = fit$N_h[2])
}

# ─────────────────────────────────────────────────────────────────────
# Trend break: coef(t0_yoy) - coef(tm1_yoy)
# DiD survival: coef(survived_tp1) - coef(survived_tm1)
# Compute at each bandwidth, also report SE (delta method approximation
# = sqrt(se_t0^2 + se_tm1^2 + ...) — assuming independence; conservative)
# ─────────────────────────────────────────────────────────────────────

bws <- c(0.005, 0.0075, 0.010, 0.015, 0.020, 0.030, 0.050)

run_panel <- function(d, sample_label) {
  cat(strrep("─", 70), "\n")
  cat(sample_label, "\n")
  cat(strrep("─", 70), "\n")

  results <- rbindlist(lapply(bws, function(h) {
    yoy_tm1 <- fixed_h(d, "dlog_emp_yoy_tm1", h)
    yoy_t0  <- fixed_h(d, "dlog_emp_yoy_t0",  h)
    yoy_tp1 <- fixed_h(d, "dlog_emp_yoy_tp1", h)
    surv_tm1 <- fixed_h(d, "survived_tm1", h)
    surv_t0  <- fixed_h(d, "survived_t0",  h)
    surv_tp1 <- fixed_h(d, "survived_tp1", h)

    # Trend break in emp YoY: t0 - tm1
    tb_coef <- yoy_t0$coef - yoy_tm1$coef
    tb_se <- sqrt(yoy_t0$se^2 + yoy_tm1$se^2)

    # DiD in survival: tp1 - tm1
    did_coef <- surv_tp1$coef - surv_tm1$coef
    did_se <- sqrt(surv_tp1$se^2 + surv_tm1$se^2)

    data.table(
      sample = sample_label, h = h,
      yoy_tm1 = yoy_tm1$coef,
      yoy_t0 = yoy_t0$coef,
      yoy_tp1 = yoy_tp1$coef,
      trend_break = tb_coef, tb_se = tb_se,
      surv_tm1 = surv_tm1$coef,
      surv_tp1 = surv_tp1$coef,
      did_surv = did_coef, did_se = did_se,
      n_eff = mean(c(yoy_t0$n_L, yoy_t0$n_R), na.rm = TRUE)
    )
  }))

  # Pretty print
  cat(sprintf("\n  %6s %10s %10s %10s %12s %10s %10s %12s %8s\n",
              "h", "yoy_tm1", "yoy_t0", "yoy_tp1", "trend_break",
              "surv_tm1", "surv_tp1", "DiD_surv", "n_eff"))
  for (i in 1:nrow(results)) {
    r <- results[i]
    cat(sprintf("  %6.4f %+10.4f %+10.4f %+10.4f %+10.4f%s %+10.4f %+10.4f %+10.4f%s %8.0f\n",
                r$h, r$yoy_tm1, r$yoy_t0, r$yoy_tp1,
                r$trend_break,
                ifelse(abs(r$trend_break) > 1.96 * r$tb_se, "*", " "),
                r$surv_tm1, r$surv_tp1,
                r$did_surv,
                ifelse(abs(r$did_surv) > 1.96 * r$did_se, "*", " "),
                r$n_eff))
  }
  cat("\n  * = |coef| > 1.96 × SE (conservative pseudo-z, assuming independence)\n\n")
  results
}

full <- run_panel(dt, "FULL pregão sample")
q4_res <- run_panel(q4, "Q4 (largest contracts)")

all_res <- rbindlist(list(full, q4_res))
fwrite(all_res, TABLE_PATH)
cat("[written]", TABLE_PATH, "\n\n")

# Summary
cat(strrep("=", 70), "\n")
cat("SUMMARY\n")
cat(strrep("=", 70), "\n")
cat("Trend break (emp YoY at impact, t0 - t-1) is the causal effect estimate\n")
cat("on the impact year, net of pre-trend.\n\n")
cat("DiD survival (tp1 - tm1) is the survival rescue estimate.\n\n")
cat("Both should be POSITIVE and STABLE across bandwidths if the rescue\n")
cat("story holds.\n\n")

cat("Done.\n")
