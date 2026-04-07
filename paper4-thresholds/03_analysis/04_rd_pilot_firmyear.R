#!/usr/bin/env Rscript
# ============================================================================
# 04_rd_pilot_firmyear.R — Pivot 1 RD pilot at firm × year level
#
# Purpose: Re-run the Caminho 1 pilot using the firm-year aggregation from
#   04_rd_pilot_firmyear_prep.py. Each firm-year is a single observation,
#   treated as narrow winner if its closest auction in that year was a win.
#
# Compare against the results of 03_rd_pilot.R to see whether the null in
# growth outcomes was driven by double-counting in the firm × auction panel.
#
# Input:  02_data/final/rd_pilot_firmyear_sample.parquet
# Output: 02_data/intermediate/rd_pilot_firmyear_results.txt
#         02_data/intermediate/rd_pilot_firmyear_table.csv
#         04_figures/rd_pilot_firmyear_{main,event_study,density}.pdf
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rdrobust)
  library(rddensity)
})

BASE        <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
SAMPLE_PATH <- file.path(BASE, "02_data/final/rd_pilot_firmyear_sample.parquet")
FIG_DIR     <- file.path(BASE, "04_figures")
OUT_DIR     <- file.path(BASE, "02_data/intermediate")
REPORT_PATH <- file.path(OUT_DIR, "rd_pilot_firmyear_results.txt")
TABLE_PATH  <- file.path(OUT_DIR, "rd_pilot_firmyear_table.csv")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

.sink <- file(REPORT_PATH, open = "wt")
log <- function(...) {
  msg <- paste0(..., collapse = "")
  cat(msg, "\n")
  cat(msg, "\n", file = .sink)
}

log("RD firm-year pilot — Paper 4 / Caminho 1 / Pivot 1")
log("Run at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log(strrep("=", 70))

# ─────────────────────────────────────────────────────────────────────
dt <- as.data.table(read_parquet(SAMPLE_PATH))
log("  rows (firm-years): ", format(nrow(dt), big.mark = ","))
log("  unique firms: ", format(length(unique(dt$cnpj_raiz)), big.mark = ","))
log("  treat share: ", sprintf("%.1f%%", 100 * mean(dt$treat)))

# Cluster at FIRM level (same firm across years is correlated)
dt[, cluster_id := .GRP, by = cnpj_raiz]
log("  clusters (firms): ", length(unique(dt$cluster_id)))

# Dual clustering alternative: item_class
dt[, cluster_item := as.integer(item_class)]
dt[is.na(cluster_item), cluster_item := 0L]

# ─────────────────────────────────────────────────────────────────────
# 1. Density test
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("1. DENSITY TEST")
log(strrep("─", 70))

dens <- rddensity(dt$running, c = 0)
log("  T: ", sprintf("%.3f", dens$test$t_jk),
    "  p: ", sprintf("%.4f", dens$test$p_jk),
    "  h_L: ", sprintf("%.4f", dens$h$left),
    "  h_R: ", sprintf("%.4f", dens$h$right))

tryCatch({
  pdf(file.path(FIG_DIR, "rd_pilot_firmyear_density.pdf"),
      width = 7, height = 5)
  rdplotdensity(dens, dt$running,
                plotRange = c(-0.05, 0.05), plotN = 25,
                title = "Density of running variable (firm-year)",
                xlabel = "Running variable (−MV)", ylabel = "Density")
  dev.off()
  log("  [written] rd_pilot_firmyear_density.pdf")
}, error = function(e) log("  [warn] density plot: ", conditionMessage(e)))

# ─────────────────────────────────────────────────────────────────────
# RD runner — uses FIRM clustering as baseline
# ─────────────────────────────────────────────────────────────────────
run_rd <- function(y_name, label) {
  idx <- is.finite(dt[[y_name]])
  if (sum(idx) < 500) {
    log(sprintf("  %-28s  [skip, N=%d]", label, sum(idx)))
    return(NULL)
  }
  x <- dt$running[idx]
  y <- dt[[y_name]][idx]
  cl <- dt$cluster_id[idx]

  fit <- tryCatch(
    rdrobust(y = y, x = x, c = 0, cluster = cl,
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) {
      log("    [error] ", label, ": ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(fit)) return(NULL)

  h <- fit$bws[1, 1]; n_L <- fit$N_h[1]; n_R <- fit$N_h[2]
  coef <- fit$coef[1, 1]; se <- fit$se[1, 1]; p <- fit$pv[1, 1]
  coef_rb <- fit$coef[3, 1]; se_rb <- fit$se[3, 1]; p_rb <- fit$pv[3, 1]

  log(sprintf("  %-28s  h=%.4f  N=%d+%d", label, h, n_L, n_R))
  log(sprintf("    conv.   : coef=%+.4f  (SE=%.4f)  p=%.4f",
              coef, se, p))
  log(sprintf("    robust  : coef=%+.4f  (SE=%.4f)  p=%.4f",
              coef_rb, se_rb, p_rb))

  list(y = y_name, label = label, h = h, n_L = n_L, n_R = n_R,
       coef = coef, se = se, p = p,
       coef_rb = coef_rb, se_rb = se_rb, p_rb = p_rb)
}

results <- list()

# ─────────────────────────────────────────────────────────────────────
# 2. Employment at t-1, t, t+1, t+2
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("2. LOG EMPLOYMENT — dynamic")
log(strrep("─", 70))

for (lbl in c("log_emp_tm1", "log_emp_t0", "log_emp_tp1", "log_emp_tp2")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 3. Payroll and wages
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("3. PAYROLL AND WAGES")
log(strrep("─", 70))

for (lbl in c("log_payroll_tm1", "log_payroll_t0",
              "log_payroll_tp1", "log_payroll_tp2",
              "log_avg_wage_tm1", "log_avg_wage_tp1")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 4. Growth rates (first differences)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("4. GROWTH RATES (first diffs)")
log(strrep("─", 70))

for (lbl in c("dlog_emp_tp1_tm1", "dlog_emp_tp2_tm1",
              "dlog_payroll_tp1_tm1")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 5. Hires, separations, survival, revolving-door
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("5. HIRES, SURVIVAL, REVOLVING-DOOR")
log(strrep("─", 70))

for (lbl in c("n_hires_year_tp1", "n_separations_year_tp1",
              "survived_tp1", "survived_tp2",
              "n_hires_from_public_tp1",
              "share_hires_from_public_tp1")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 6. Balance tests
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("6. BALANCE TESTS")
log(strrep("─", 70))

balance_vars <- c("log_emp_tm1", "log_payroll_tm1", "log_avg_wage_tm1",
                  "share_female_tm1", "avg_age_tm1",
                  "share_university_tm1", "share_managerial_tm1")
for (lbl in balance_vars) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 7. Heterogeneity by firm size (using log_emp_tm1 quartiles)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("7. HETEROGENEITY BY BASELINE FIRM SIZE (log_emp_tm1 quartiles)")
log(strrep("─", 70))

run_subgroup <- function(y_name, mask, label) {
  mask[is.na(mask)] <- FALSE
  idx <- mask & is.finite(dt[[y_name]])
  idx[is.na(idx)] <- FALSE
  if (sum(idx) < 500) {
    log(sprintf("  %-30s  [skip, N=%d]", label, sum(idx)))
    return(NULL)
  }
  fit <- tryCatch(
    rdrobust(y = dt[[y_name]][idx], x = dt$running[idx], c = 0,
             cluster = dt$cluster_id[idx],
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) { log("    [err] ", conditionMessage(e)); NULL })
  if (is.null(fit)) return(NULL)
  log(sprintf("  %-30s  h=%.4f N=%d+%d  coef=%+.4f (SE=%.4f) p=%.4f",
              label, fit$bws[1,1], fit$N_h[1], fit$N_h[2],
              fit$coef[1,1], fit$se[1,1], fit$pv[1,1]))
  list(y = y_name, label = label, h = fit$bws[1,1],
       n_L = fit$N_h[1], n_R = fit$N_h[2],
       coef = fit$coef[1,1], se = fit$se[1,1], p = fit$pv[1,1],
       coef_rb = fit$coef[3,1], se_rb = fit$se[3,1], p_rb = fit$pv[3,1])
}

baseline_emp <- dt$log_emp_tm1
qs <- quantile(baseline_emp, c(0.25, 0.50, 0.75), na.rm = TRUE)
log(sprintf("  Quartile cutoffs of log_emp_tm1: Q1=%.2f Q2=%.2f Q3=%.2f",
            qs[1], qs[2], qs[3]))

for (y in c("log_emp_tp1", "dlog_emp_tp1_tm1", "survived_tp1")) {
  log(sprintf("  --- outcome: %s ---", y))
  r1 <- run_subgroup(y, baseline_emp <= qs[1], paste0(y, " [Q1 smallest]"))
  r2 <- run_subgroup(y, baseline_emp > qs[1] & baseline_emp <= qs[2],
                     paste0(y, " [Q2]"))
  r3 <- run_subgroup(y, baseline_emp > qs[2] & baseline_emp <= qs[3],
                     paste0(y, " [Q3]"))
  r4 <- run_subgroup(y, baseline_emp > qs[3], paste0(y, " [Q4 largest]"))
  for (r in list(r1, r2, r3, r4)) {
    if (!is.null(r)) results[[length(results) + 1]] <- r
  }
}

# ─────────────────────────────────────────────────────────────────────
# 8. Bandwidth sensitivity on log_emp_tp1 and dlog_emp_tp1_tm1
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("8. BANDWIDTH SENSITIVITY")
log(strrep("─", 70))

run_fixed_h <- function(y_name, h, label) {
  idx <- is.finite(dt[[y_name]])
  fit <- tryCatch(
    rdrobust(y = dt[[y_name]][idx], x = dt$running[idx], c = 0, h = h,
             cluster = dt$cluster_id[idx],
             kernel = "triangular", p = 1),
    error = function(e) NULL)
  if (is.null(fit)) return(invisible())
  log(sprintf("    %-25s  h=%.4f  coef=%+.4f (SE=%.4f) N=%d+%d p=%.4f",
              label, h, fit$coef[1,1], fit$se[1,1],
              fit$N_h[1], fit$N_h[2], fit$pv[1,1]))
}

for (y in c("log_emp_tp1", "dlog_emp_tp1_tm1", "survived_tp1")) {
  log(sprintf("  --- %s ---", y))
  for (h in c(0.005, 0.01, 0.02, 0.03, 0.05)) {
    run_fixed_h(y, h, y)
  }
}

# ─────────────────────────────────────────────────────────────────────
# 9. RD main plot
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("9. FIGURES")
log(strrep("─", 70))

tryCatch({
  idx <- is.finite(dt$log_emp_tp1)
  pdf(file.path(FIG_DIR, "rd_pilot_firmyear_main.pdf"), width = 8, height = 6)
  rdplot(y = dt$log_emp_tp1[idx], x = dt$running[idx], c = 0,
         nbins = c(25, 25), binselect = "esmv",
         x.label = "Running variable (−MV)",
         y.label = "log(1+emp) at t+1",
         title = "Firm-year RD: log employment at t+1")
  dev.off()
  log("  [written] rd_pilot_firmyear_main.pdf")
}, error = function(e) log("  [err] main plot: ", conditionMessage(e)))

tryCatch({
  idx <- is.finite(dt$survived_tp1)
  pdf(file.path(FIG_DIR, "rd_pilot_firmyear_survival.pdf"),
      width = 8, height = 6)
  rdplot(y = dt$survived_tp1[idx], x = dt$running[idx], c = 0,
         nbins = c(25, 25), binselect = "esmv",
         x.label = "Running variable (−MV)",
         y.label = "P(survive at t+1)",
         title = "Firm-year RD: survival at t+1")
  dev.off()
  log("  [written] rd_pilot_firmyear_survival.pdf")
}, error = function(e) log("  [err] survival plot: ", conditionMessage(e)))

# ─────────────────────────────────────────────────────────────────────
# Event study figure
# ─────────────────────────────────────────────────────────────────────
event <- rbindlist(lapply(results, function(r) {
  if (is.null(r)) return(NULL)
  if (!grepl("^log_emp_t[mp0]", r$label)) return(NULL)
  k <- sub("log_emp_", "", r$label)
  k_num <- switch(k, tm1 = -1, t0 = 0, tp1 = 1, tp2 = 2, NA_real_)
  if (is.na(k_num)) return(NULL)
  data.table(k = k_num, coef = r$coef, se = r$se,
             lo = r$coef - 1.96 * r$se, hi = r$coef + 1.96 * r$se)
}))

tryCatch({
  if (nrow(event) > 0) {
    pdf(file.path(FIG_DIR, "rd_pilot_firmyear_event_study.pdf"),
        width = 7, height = 5)
    op <- par(mar = c(5, 5, 4, 2))
    plot(event$k, event$coef, type = "p", pch = 16, cex = 1.3,
         ylim = range(c(event$lo, event$hi, 0)) * 1.1,
         xlab = "Years relative to close-bid auction (k)",
         ylab = "RD coefficient on log(1+emp)",
         main = "Firm-year RD: dynamic effect on log employment",
         xaxt = "n")
    axis(1, at = event$k,
         labels = paste0("t", ifelse(event$k >= 0, "+", ""), event$k))
    segments(event$k, event$lo, event$k, event$hi, lwd = 2)
    abline(h = 0, lty = 2, col = "gray50")
    par(op)
    dev.off()
    log("  [written] rd_pilot_firmyear_event_study.pdf")
  }
}, error = function(e) log("  [err] event study: ", conditionMessage(e)))

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
