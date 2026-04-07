#!/usr/bin/env Rscript
# ============================================================================
# 03_rd_pilot.R — Pilot RD estimation for Paper 4 / Caminho 1
#
# Purpose: validate the close-bid RD design as a local-randomization
#          quasi-experiment on RAIS-based firm outcomes (Caminho 1).
#
# Inputs:
#   02_data/final/rd_pilot_sample.parquet  (from 03_rd_pilot_prep.py)
#
# Outputs:
#   04_figures/rd_pilot_main.pdf          RD plot of main outcome
#   04_figures/rd_pilot_event_study.pdf   Dynamic effects
#   04_figures/rd_pilot_density.pdf       CJM density test
#   02_data/intermediate/rd_pilot_results.txt  text report
#   02_data/intermediate/rd_pilot_table.csv    tidy table
#
# Usage:
#   Rscript 03_analysis/03_rd_pilot.R
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rdrobust)
  library(rddensity)
})

# ─────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────
BASE         <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
SAMPLE_PATH  <- file.path(BASE, "02_data/final/rd_pilot_sample.parquet")
FIG_DIR      <- file.path(BASE, "04_figures")
OUT_DIR      <- file.path(BASE, "02_data/intermediate")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

REPORT_PATH  <- file.path(OUT_DIR, "rd_pilot_results.txt")
TABLE_PATH   <- file.path(OUT_DIR, "rd_pilot_table.csv")

# ─────────────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────────────
.sink <- file(REPORT_PATH, open = "wt")
log <- function(...) {
  msg <- paste0(..., collapse = "")
  cat(msg, "\n")
  cat(msg, "\n", file = .sink)
}

log("RD pilot — Paper 4 / Caminho 1")
log("Run at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log(strrep("=", 70))

# ─────────────────────────────────────────────────────────────────────
# Load analysis sample
# ─────────────────────────────────────────────────────────────────────
log("\n[load] reading ", SAMPLE_PATH)
dt <- as.data.table(read_parquet(SAMPLE_PATH))
log("  rows: ", format(nrow(dt), big.mark = ","))
log("  cols: ", ncol(dt))
log("  treat (won) share: ", sprintf("%.1f%%", 100 * mean(dt$treat)))

# Cluster SEs at the item-class level (faster than auction-level and more
# appropriate given that item-class is the relevant unit of similar products
# across auctions). Paper 3 uses ~item_f clustering — same convention.
dt[, cluster_id := as.integer(item_class)]
dt[is.na(cluster_id), cluster_id := 0L]
log("  unique item_class clusters: ", length(unique(dt$cluster_id)))

# ─────────────────────────────────────────────────────────────────────
# 1. Density test (CJM / rddensity)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("1. DENSITY TEST — Cattaneo-Jansson-Ma")
log(strrep("─", 70))

dens <- rddensity(dt$running, c = 0)
log("  T (stat): ", sprintf("%.3f", dens$test$t_jk))
log("  p-value : ", sprintf("%.4f", dens$test$p_jk))
log("  h (left): ", sprintf("%.4f", dens$h$left),
    "   h (right): ", sprintf("%.4f", dens$h$right))

tryCatch({
  pdf(file.path(FIG_DIR, "rd_pilot_density.pdf"), width = 7, height = 5)
  plt <- rdplotdensity(dens, dt$running,
                       plotRange = c(-0.05, 0.05),
                       plotN = 25, type = "both",
                       title = "Density of running variable (MV flipped)",
                       xlabel = "Running variable (|MV|, + = won)",
                       ylabel = "Density")
  dev.off()
  log("  [written] rd_pilot_density.pdf")
}, error = function(e) {
  log("  [warn] density plot failed: ", conditionMessage(e))
})

# ─────────────────────────────────────────────────────────────────────
# 2. Main RD: log employment at t+1
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("2. MAIN RD — log employment at t+1 (n_employees_3112)")
log(strrep("─", 70))

run_rd <- function(y_name, label, cluster = TRUE) {
  idx <- is.finite(dt[[y_name]])
  x <- dt$running[idx]
  y <- dt[[y_name]][idx]
  cl <- if (cluster) dt$cluster_id[idx] else NULL

  fit <- tryCatch(
    rdrobust(y = y, x = x, c = 0, cluster = cl,
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) {
      log("    [error] ", conditionMessage(e))
      return(NULL)
    }
  )
  if (is.null(fit)) return(NULL)

  h    <- fit$bws[1, 1]
  coef <- fit$coef[1, 1]
  se   <- fit$se[1, 1]
  z    <- fit$z[1, 1]
  p    <- fit$pv[1, 1]
  # Robust (bias-corrected) inference
  coef_rb <- fit$coef[3, 1]
  se_rb   <- fit$se[3, 1]
  p_rb    <- fit$pv[3, 1]
  n_left  <- fit$N_h[1]
  n_right <- fit$N_h[2]

  log(sprintf("  %-20s  h=%.4f  N_L=%d  N_R=%d",
              label, h, n_left, n_right))
  log(sprintf("    conventional : coef=%+.4f  (SE=%.4f)  p=%.4f",
              coef, se, p))
  log(sprintf("    robust-bc    : coef=%+.4f  (SE=%.4f)  p=%.4f",
              coef_rb, se_rb, p_rb))

  list(y = y_name, label = label,
       h = h, n_left = n_left, n_right = n_right,
       coef = coef, se = se, p = p,
       coef_rb = coef_rb, se_rb = se_rb, p_rb = p_rb)
}

results <- list()

# Primary outcomes: log employment dynamics
for (k in c("tm1", "t0", "tp1", "tp2")) {
  lbl <- paste0("log_emp_", k)
  r <- run_rd(lbl, paste0("log emp ", k))
  results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 3. Payroll and wage outcomes
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("3. PAYROLL & WAGE — log(payroll + 1), log(avg_wage + 1)")
log(strrep("─", 70))

for (lbl in c("log_payroll_tm1", "log_payroll_t0",
              "log_payroll_tp1", "log_payroll_tp2",
              "log_avg_wage_tm1", "log_avg_wage_tp1")) {
  if (lbl %in% names(dt)) {
    r <- run_rd(lbl, lbl)
    results[[length(results) + 1]] <- r
  }
}

# ─────────────────────────────────────────────────────────────────────
# 4. Growth rates (first-difference in log employment)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("4. GROWTH RATES — Δlog emp (relative to t-1)")
log(strrep("─", 70))

for (lbl in c("dlog_emp_tp1_tm1", "dlog_emp_tp2_tm1")) {
  r <- run_rd(lbl, lbl)
  results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 5. Hiring, separations, survival
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("5. HIRES, SEPARATIONS, SURVIVAL, REVOLVING-DOOR")
log(strrep("─", 70))

for (lbl in c("n_hires_year_tp1", "n_separations_year_tp1",
              "survived_tp1", "survived_tp2",
              "n_hires_from_public_tp1",
              "share_hires_from_public_tp1")) {
  if (lbl %in% names(dt)) {
    r <- run_rd(lbl, lbl)
    results[[length(results) + 1]] <- r
  }
}

# ─────────────────────────────────────────────────────────────────────
# 6. Balance tests (pre-treatment covariates)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("6. BALANCE TESTS — pre-treatment covariates (should ≈ 0)")
log(strrep("─", 70))

balance_vars <- c("log_emp_tm1", "log_payroll_tm1", "log_avg_wage_tm1",
                  "share_female_tm1", "avg_age_tm1", "avg_escolaridade_tm1",
                  "share_university_tm1", "share_managerial_tm1",
                  "was_incumbent", "was_last_bid")
for (lbl in balance_vars) {
  if (lbl %in% names(dt)) {
    r <- run_rd(lbl, lbl)
    results[[length(results) + 1]] <- r
  }
}

# ─────────────────────────────────────────────────────────────────────
# 7. Bandwidth sensitivity for main outcome (log_emp_tp1)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("7. BANDWIDTH SENSITIVITY — log_emp_tp1 at fixed h")
log(strrep("─", 70))

run_fixed_h <- function(y_name, h) {
  idx <- is.finite(dt[[y_name]])
  x <- dt$running[idx]
  y <- dt[[y_name]][idx]
  cl <- dt$cluster_id[idx]
  fit <- rdrobust(y = y, x = x, c = 0, h = h, cluster = cl,
                  kernel = "triangular", p = 1)
  log(sprintf("    h=%.4f  coef=%+.4f  SE=%.4f  N=%d+%d  p=%.4f",
              h, fit$coef[1, 1], fit$se[1, 1],
              fit$N_h[1], fit$N_h[2], fit$pv[1, 1]))
}

for (h in c(0.005, 0.01, 0.015, 0.02, 0.03, 0.05)) {
  tryCatch(run_fixed_h("log_emp_tp1", h),
           error = function(e) log("    [err] ", conditionMessage(e)))
}

# ─────────────────────────────────────────────────────────────────────
# 8. Donut-hole RD
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("8. DONUT-HOLE — drop |r| < τ, re-estimate log_emp_tp1")
log(strrep("─", 70))

for (tau in c(0.0005, 0.001, 0.002)) {
  keep <- abs(dt$running) >= tau & is.finite(dt$log_emp_tp1)
  if (sum(keep) < 1000) next
  fit <- rdrobust(y = dt$log_emp_tp1[keep], x = dt$running[keep], c = 0,
                  cluster = dt$cluster_id[keep],
                  kernel = "triangular", p = 1, bwselect = "mserd")
  log(sprintf("    τ=%.4f  coef=%+.4f  SE=%.4f  h=%.4f  N=%d+%d",
              tau, fit$coef[1, 1], fit$se[1, 1], fit$bws[1, 1],
              fit$N_h[1], fit$N_h[2]))
}

# ─────────────────────────────────────────────────────────────────────
# 9. Main RD plot
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("9. FIGURES — RD plot for log_emp_tp1")
log(strrep("─", 70))

tryCatch({
  idx <- is.finite(dt$log_emp_tp1)
  pdf(file.path(FIG_DIR, "rd_pilot_main.pdf"), width = 8, height = 6)
  rdplot(y = dt$log_emp_tp1[idx], x = dt$running[idx], c = 0,
         nbins = c(30, 30), binselect = "esmv",
         x.label = "Running variable (flipped margin of victory)",
         y.label = "log(1 + employment) at t+1",
         title = "RD pilot: log employment at t+1")
  dev.off()
  log("  [written] rd_pilot_main.pdf")
}, error = function(e) log("  [err] rd plot: ", conditionMessage(e)))

# ─────────────────────────────────────────────────────────────────────
# 10. Event study figure — log_emp effect by k
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("10. EVENT STUDY FIGURE — log_emp effect at t-1, t, t+1, t+2")
log(strrep("─", 70))

event <- rbindlist(lapply(results, function(r) {
  if (is.null(r)) return(NULL)
  if (!grepl("^log emp t", r$label)) return(NULL)
  k <- sub("log emp ", "", r$label)
  k_num <- switch(k, tm1 = -1, t0 = 0, tp1 = 1, tp2 = 2, NA_real_)
  if (is.na(k_num)) return(NULL)
  data.table(k = k_num, coef = r$coef, se = r$se,
             lo = r$coef - 1.96 * r$se, hi = r$coef + 1.96 * r$se)
}))

tryCatch({
  pdf(file.path(FIG_DIR, "rd_pilot_event_study.pdf"), width = 7, height = 5)
  op <- par(mar = c(5, 5, 4, 2))
  plot(event$k, event$coef,
       type = "p", pch = 16, cex = 1.3,
       ylim = range(c(event$lo, event$hi, 0)) * 1.1,
       xlab = "Years relative to close-bid auction (k)",
       ylab = "RD coefficient on log(1 + employment)",
       main = "Dynamic effect of narrow win on log employment",
       xaxt = "n")
  axis(1, at = event$k, labels = paste0("t", ifelse(event$k >= 0, "+", ""), event$k))
  segments(event$k, event$lo, event$k, event$hi, lwd = 2)
  abline(h = 0, lty = 2, col = "gray50")
  par(op)
  dev.off()
  log("  [written] rd_pilot_event_study.pdf")
}, error = function(e) log("  [err] event study: ", conditionMessage(e)))

# ─────────────────────────────────────────────────────────────────────
# Persist results table
# ─────────────────────────────────────────────────────────────────────
results_dt <- rbindlist(lapply(results, function(r) {
  if (is.null(r)) return(NULL)
  as.data.table(r)
}), fill = TRUE)
fwrite(results_dt, TABLE_PATH)
log("\n[written] ", TABLE_PATH)

log("\nDone.")
close(.sink)
cat("\n[written]", REPORT_PATH, "\n")
