#!/usr/bin/env Rscript
# ============================================================================
# 06_rd_pregao_pilot.R — RD pilot on PREGÃO (Pivot 4)
#
# Purpose: test whether the null growth results from the convite pilot
#   (scripts 03, 04) persist when we use pregão, which has no contract-size
#   cap and therefore much larger treatment stakes.
#
# Input:  02_data/final/rd_pilot_pregao_sample.parquet
# Output: 02_data/intermediate/rd_pregao_results.txt
#         02_data/intermediate/rd_pregao_table.csv
#         04_figures/rd_pregao_{main,density,event_study,survival}.pdf
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rdrobust)
  library(rddensity)
})

BASE        <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
SAMPLE_PATH <- file.path(BASE, "02_data/final/rd_pilot_pregao_sample.parquet")
FIG_DIR     <- file.path(BASE, "04_figures")
OUT_DIR     <- file.path(BASE, "02_data/intermediate")
REPORT_PATH <- file.path(OUT_DIR, "rd_pregao_results.txt")
TABLE_PATH  <- file.path(OUT_DIR, "rd_pregao_table.csv")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

.sink <- file(REPORT_PATH, open = "wt")
log <- function(...) {
  msg <- paste0(..., collapse = "")
  cat(msg, "\n"); cat(msg, "\n", file = .sink)
}

log("RD pilot PREGÃO — Paper 4 / Pivot 4")
log("Run at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log(strrep("=", 70))

# ─────────────────────────────────────────────────────────────────────
dt <- as.data.table(read_parquet(SAMPLE_PATH))
log("  raw rows: ", format(nrow(dt), big.mark = ","))

# Donut hole: drop exact ties (|running| ≈ 0) which are a discreteness mass
# point in pregão (winner and runner-up converging to identical prices in the
# open phase). These are not real "narrow contests" and corrupt the density
# test plus distort RD coefficients.
n_ties <- sum(abs(dt$running) < 1e-6)
log("  exact-tie rows (|running| < 1e-6): ", format(n_ties, big.mark = ","),
    sprintf(" (%.1f%%)", 100 * n_ties / nrow(dt)))
dt <- dt[abs(running) >= 1e-6]
log("  rows after donut: ", format(nrow(dt), big.mark = ","))
log("  unique firms: ", format(length(unique(dt$cnpj_raiz)), big.mark = ","))
log("  unique auctions: ",
    format(length(unique(dt$auction_item)), big.mark = ","))
log("  treat (won) share: ", sprintf("%.1f%%", 100 * mean(dt$treat)))

# Cluster at firm level (firms repeat across auctions and years); tested also
# at pbu_code level as robustness
dt[, cluster_firm := .GRP, by = cnpj_raiz]
dt[, cluster_pbu := .GRP, by = pbu_code]
log("  firm clusters: ", length(unique(dt$cluster_firm)))
log("  pbu clusters: ", length(unique(dt$cluster_pbu)))

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
  pdf(file.path(FIG_DIR, "rd_pregao_density.pdf"), width = 7, height = 5)
  rdplotdensity(dens, dt$running,
                plotRange = c(-0.05, 0.05), plotN = 25,
                title = "Density of running variable — pregão",
                xlabel = "Running variable (−MV)", ylabel = "Density")
  dev.off()
  log("  [written] rd_pregao_density.pdf")
}, error = function(e) log("  [warn] density plot: ", conditionMessage(e)))

# ─────────────────────────────────────────────────────────────────────
# RD runner
# ─────────────────────────────────────────────────────────────────────
run_rd <- function(y_name, label, cluster_col = "cluster_firm") {
  idx <- is.finite(dt[[y_name]])
  if (sum(idx) < 500) { log(sprintf("  %-28s [skip N=%d]", label, sum(idx))); return(NULL) }
  fit <- tryCatch(
    rdrobust(y = dt[[y_name]][idx], x = dt$running[idx], c = 0,
             cluster = dt[[cluster_col]][idx],
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) { log("  [err] ", label, ": ", conditionMessage(e)); NULL })
  if (is.null(fit)) return(NULL)
  log(sprintf("  %-28s  h=%.4f  N=%d+%d", label, fit$bws[1,1],
              fit$N_h[1], fit$N_h[2]))
  log(sprintf("    conv.  : coef=%+.4f (SE=%.4f) p=%.4f",
              fit$coef[1,1], fit$se[1,1], fit$pv[1,1]))
  log(sprintf("    robust : coef=%+.4f (SE=%.4f) p=%.4f",
              fit$coef[3,1], fit$se[3,1], fit$pv[3,1]))
  list(y = y_name, label = label,
       h = fit$bws[1,1], n_L = fit$N_h[1], n_R = fit$N_h[2],
       coef = fit$coef[1,1], se = fit$se[1,1], p = fit$pv[1,1],
       coef_rb = fit$coef[3,1], se_rb = fit$se[3,1], p_rb = fit$pv[3,1])
}

results <- list()

# ─────────────────────────────────────────────────────────────────────
# 2. Employment, payroll, wages
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("2. LOG EMPLOYMENT — dynamic")
log(strrep("─", 70))
for (lbl in c("log_emp_tm1", "log_emp_t0", "log_emp_tp1", "log_emp_tp2")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

log("\n", strrep("─", 70))
log("3. LOG PAYROLL, WAGES")
log(strrep("─", 70))
for (lbl in c("log_payroll_tm1", "log_payroll_tp1", "log_payroll_tp2",
              "log_avg_wage_tm1", "log_avg_wage_tp1")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 4. Growth rates
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("4. GROWTH RATES")
log(strrep("─", 70))
for (lbl in c("dlog_emp_tp1_tm1", "dlog_emp_tp2_tm1",
              "dlog_payroll_tp1_tm1")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 5. Hires, survival, revolving door
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("5. HIRES, SURVIVAL, REVOLVING DOOR")
log(strrep("─", 70))
for (lbl in c("n_hires_year_tp1", "n_separations_year_tp1",
              "survived_tp1", "survived_tp2",
              "n_hires_from_public_tp1", "share_hires_from_public_tp1")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 6. Balance tests
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("6. BALANCE TESTS")
log(strrep("─", 70))
for (lbl in c("log_emp_tm1", "log_payroll_tm1", "log_avg_wage_tm1",
              "share_female_tm1", "avg_age_tm1",
              "share_university_tm1", "share_managerial_tm1")) {
  r <- run_rd(lbl, lbl); results[[length(results) + 1]] <- r
}

# ─────────────────────────────────────────────────────────────────────
# 7. Heterogeneity by log ref price (contract size)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("7. HETEROGENEITY BY CONTRACT SIZE (log_ref_price quartiles)")
log(strrep("─", 70))
rp <- dt$log_ref_price
rp[is.na(rp)] <- median(rp, na.rm = TRUE)
qs <- quantile(rp, c(0.25, 0.50, 0.75), na.rm = TRUE)
log(sprintf("  Ref-price quartile cutoffs (log): Q1=%.2f Q2=%.2f Q3=%.2f",
            qs[1], qs[2], qs[3]))

run_subset <- function(y_name, mask, label) {
  mask[is.na(mask)] <- FALSE
  idx <- mask & is.finite(dt[[y_name]])
  idx[is.na(idx)] <- FALSE
  if (sum(idx) < 500) { log(sprintf("  %-30s [skip N=%d]", label, sum(idx))); return(NULL) }
  fit <- tryCatch(
    rdrobust(y = dt[[y_name]][idx], x = dt$running[idx], c = 0,
             cluster = dt$cluster_firm[idx],
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) { log("  [err] ", conditionMessage(e)); NULL })
  if (is.null(fit)) return(NULL)
  log(sprintf("  %-30s  h=%.4f N=%d+%d coef=%+.4f (SE=%.4f) p=%.4f",
              label, fit$bws[1,1], fit$N_h[1], fit$N_h[2],
              fit$coef[1,1], fit$se[1,1], fit$pv[1,1]))
  list(y = y_name, label = label, h = fit$bws[1,1],
       n_L = fit$N_h[1], n_R = fit$N_h[2],
       coef = fit$coef[1,1], se = fit$se[1,1], p = fit$pv[1,1],
       coef_rb = fit$coef[3,1], se_rb = fit$se[3,1], p_rb = fit$pv[3,1])
}

for (y in c("log_emp_tp1", "dlog_emp_tp1_tm1", "survived_tp1",
            "log_payroll_tp1")) {
  log(sprintf("  --- outcome: %s ---", y))
  masks <- list(
    list(rp <= qs[1], "Q1 smallest"),
    list(rp > qs[1] & rp <= qs[2], "Q2"),
    list(rp > qs[2] & rp <= qs[3], "Q3"),
    list(rp > qs[3], "Q4 largest")
  )
  for (m in masks) {
    r <- run_subset(y, m[[1]], paste0(y, " [", m[[2]], "]"))
    if (!is.null(r)) results[[length(results) + 1]] <- r
  }
}

# ─────────────────────────────────────────────────────────────────────
# 8. Bandwidth sensitivity
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("8. BANDWIDTH SENSITIVITY")
log(strrep("─", 70))

run_fixed_h <- function(y_name, h, label) {
  idx <- is.finite(dt[[y_name]])
  fit <- tryCatch(
    rdrobust(y = dt[[y_name]][idx], x = dt$running[idx], c = 0, h = h,
             cluster = dt$cluster_firm[idx],
             kernel = "triangular", p = 1), error = function(e) NULL)
  if (is.null(fit)) return(invisible())
  log(sprintf("    %-25s h=%.4f coef=%+.4f (SE=%.4f) N=%d+%d p=%.4f",
              label, h, fit$coef[1,1], fit$se[1,1],
              fit$N_h[1], fit$N_h[2], fit$pv[1,1]))
}

for (y in c("log_emp_tp1", "dlog_emp_tp1_tm1", "survived_tp1",
            "log_payroll_tp1")) {
  log(sprintf("  --- %s ---", y))
  for (h in c(0.005, 0.01, 0.02, 0.05)) run_fixed_h(y, h, y)
}

# ─────────────────────────────────────────────────────────────────────
# 9. Figures
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("9. FIGURES")
log(strrep("─", 70))

for (pair in list(
  c("log_emp_tp1", "log(1+emp) at t+1", "rd_pregao_main.pdf"),
  c("survived_tp1", "P(survive at t+1)", "rd_pregao_survival.pdf"),
  c("dlog_emp_tp1_tm1", "dlog emp (t+1 − t-1)", "rd_pregao_growth.pdf")
)) {
  y <- pair[1]; ylab <- pair[2]; fn <- pair[3]
  tryCatch({
    idx <- is.finite(dt[[y]])
    pdf(file.path(FIG_DIR, fn), width = 8, height = 6)
    rdplot(y = dt[[y]][idx], x = dt$running[idx], c = 0,
           nbins = c(25, 25), binselect = "esmv",
           x.label = "Running variable (−MV)", y.label = ylab,
           title = paste0("Pregão RD: ", y))
    dev.off()
    log("  [written] ", fn)
  }, error = function(e) log("  [err] ", fn, ": ", conditionMessage(e)))
}

# Event study for log emp
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
    pdf(file.path(FIG_DIR, "rd_pregao_event_study.pdf"), width = 7, height = 5)
    op <- par(mar = c(5, 5, 4, 2))
    plot(event$k, event$coef, type = "p", pch = 16, cex = 1.3,
         ylim = range(c(event$lo, event$hi, 0)) * 1.1,
         xlab = "Years relative to close-bid auction",
         ylab = "RD coefficient on log(1+emp)",
         main = "Pregão RD: dynamic effect on log employment",
         xaxt = "n")
    axis(1, at = event$k,
         labels = paste0("t", ifelse(event$k >= 0, "+", ""), event$k))
    segments(event$k, event$lo, event$k, event$hi, lwd = 2)
    abline(h = 0, lty = 2, col = "gray50")
    par(op); dev.off()
    log("  [written] rd_pregao_event_study.pdf")
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
