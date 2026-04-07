#!/usr/bin/env Rscript
# ============================================================================
# 08_event_study.R — Identification defense figure
#
# Purpose: produce the event study figure that defends the close-bid RD
#   identification strategy. Two panels:
#   (A) Year-over-year growth in log employment around the auction year, with
#       RD coefficients at k ∈ {-1, 0, +1, +2, +3}. The pre-treatment values
#       (k = -1) should be ≈ 0; treatment effect should appear at k ≥ 0.
#   (B) Cumulative effect on log employment relative to t-1 baseline, with
#       RD coefficients at k ∈ {-2, 0, +1, +2, +3}. k = -1 is baseline (=0).
#
# Same panels for log payroll.
#
# Input:  02_data/final/rd_pilot_pregao_firmyear_sample.parquet
# Output: 04_figures/rd_pregao_event_study_yoy.pdf
#         04_figures/rd_pregao_event_study_cumulative.pdf
#         02_data/intermediate/rd_event_study_table.csv
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rdrobust)
})

BASE        <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
SAMPLE_PATH <- file.path(BASE, "02_data/final/rd_pilot_pregao_firmyear_sample.parquet")
FIG_DIR     <- file.path(BASE, "04_figures")
OUT_DIR     <- file.path(BASE, "02_data/intermediate")
TABLE_PATH  <- file.path(OUT_DIR, "rd_event_study_table.csv")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

cat("Event study — Pregão firm-year, identification defense\n")
cat("Run at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat(strrep("=", 70), "\n")

dt <- as.data.table(read_parquet(SAMPLE_PATH))
cat("  rows:", format(nrow(dt), big.mark = ","), "\n")
cat("  unique firms:", format(length(unique(dt$cnpj_raiz)), big.mark = ","), "\n")
dt[, cluster_firm := .GRP, by = cnpj_raiz]

# ─────────────────────────────────────────────────────────────────────
# RD runner
# ─────────────────────────────────────────────────────────────────────
run_rd <- function(y_name) {
  idx <- is.finite(dt[[y_name]])
  if (sum(idx) < 500) {
    return(data.table(y = y_name, coef = NA_real_, se = NA_real_,
                      n_L = NA_integer_, n_R = NA_integer_, h = NA_real_))
  }
  fit <- tryCatch(
    rdrobust(y = dt[[y_name]][idx], x = dt$running[idx], c = 0,
             cluster = dt$cluster_firm[idx],
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) NULL
  )
  if (is.null(fit)) {
    return(data.table(y = y_name, coef = NA_real_, se = NA_real_,
                      n_L = NA_integer_, n_R = NA_integer_, h = NA_real_))
  }
  data.table(y = y_name,
             coef = fit$coef[1, 1], se = fit$se[1, 1],
             coef_rb = fit$coef[3, 1], se_rb = fit$se[3, 1],
             n_L = fit$N_h[1], n_R = fit$N_h[2], h = fit$bws[1, 1])
}

# ─────────────────────────────────────────────────────────────────────
# Panel A — Year-over-year growth rates
# ─────────────────────────────────────────────────────────────────────
cat("\n[Panel A] Year-over-year growth — log employment\n")

yoy_emp <- rbindlist(lapply(
  c("dlog_emp_yoy_tm1", "dlog_emp_yoy_t0", "dlog_emp_yoy_tp1",
    "dlog_emp_yoy_tp2", "dlog_emp_yoy_tp3"),
  run_rd
))
yoy_emp[, k := c(-1, 0, 1, 2, 3)]
yoy_emp[, outcome := "log emp YoY"]
print(yoy_emp[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

cat("\n[Panel A'] Year-over-year growth — log payroll\n")
yoy_pay <- rbindlist(lapply(
  c("dlog_payroll_yoy_tm1", "dlog_payroll_yoy_t0", "dlog_payroll_yoy_tp1",
    "dlog_payroll_yoy_tp2", "dlog_payroll_yoy_tp3"),
  run_rd
))
yoy_pay[, k := c(-1, 0, 1, 2, 3)]
yoy_pay[, outcome := "log payroll YoY"]
print(yoy_pay[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

# ─────────────────────────────────────────────────────────────────────
# Panel B — Cumulative event study (normalized to t-1 = 0)
# ─────────────────────────────────────────────────────────────────────
cat("\n[Panel B] Cumulative effect on log employment (t-1 baseline)\n")

cum_emp <- rbindlist(lapply(
  c("dlog_emp_cum_tm2", "dlog_emp_cum_t0",
    "dlog_emp_cum_tp1", "dlog_emp_cum_tp2", "dlog_emp_cum_tp3"),
  run_rd
))
cum_emp[, k := c(-2, 0, 1, 2, 3)]
cum_emp[, outcome := "log emp cumulative"]
print(cum_emp[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

# Persist table
results <- rbindlist(list(yoy_emp, yoy_pay, cum_emp), fill = TRUE)
fwrite(results, TABLE_PATH)
cat("\n[written]", TABLE_PATH, "\n")

# ─────────────────────────────────────────────────────────────────────
# Plot — Panel A (YoY growth)
# ─────────────────────────────────────────────────────────────────────
plot_event_study <- function(dt_yoy, ylab, title, outfile,
                             pre_color = "gray60", post_color = "black") {
  pdf(outfile, width = 8, height = 5)
  op <- par(mar = c(5, 5, 4, 2), las = 1)

  dt_yoy[, lo := coef - 1.96 * se]
  dt_yoy[, hi := coef + 1.96 * se]
  ylim <- range(c(dt_yoy$lo, dt_yoy$hi, 0), na.rm = TRUE)
  ylim <- ylim + c(-1, 1) * 0.05 * diff(ylim)

  plot(dt_yoy$k, dt_yoy$coef,
       type = "n",
       xlim = c(-1.5, 3.5), ylim = ylim,
       xlab = "Year relative to close-bid auction (k)",
       ylab = ylab,
       main = title,
       xaxt = "n")
  axis(1, at = -1:3,
       labels = c("t-1\n(placebo)", "t0\n(impact)",
                  "t+1", "t+2", "t+3"))
  abline(h = 0, lty = 2, col = "gray70")
  abline(v = -0.5, lty = 3, col = "gray70")

  # Pre-period (k = -1) in gray
  pre <- dt_yoy[k == -1]
  points(pre$k, pre$coef, pch = 1, cex = 1.5, col = pre_color, lwd = 2)
  segments(pre$k, pre$lo, pre$k, pre$hi, col = pre_color, lwd = 2)

  # Post-period (k ≥ 0) in black
  post <- dt_yoy[k >= 0]
  points(post$k, post$coef, pch = 16, cex = 1.5, col = post_color)
  segments(post$k, post$lo, post$k, post$hi, col = post_color, lwd = 2)

  legend("topright",
         legend = c("Placebo (pre-treatment)", "Treatment effect"),
         pch = c(1, 16), col = c(pre_color, post_color),
         bg = "white", inset = 0.02, cex = 0.9)

  par(op); dev.off()
  cat("[written]", outfile, "\n")
}

plot_event_study(
  yoy_emp,
  ylab = "RD coef on YoY dlog employment",
  title = "Pregão firm-year RD: dynamic effect on employment growth",
  outfile = file.path(FIG_DIR, "rd_pregao_event_study_yoy_emp.pdf")
)

plot_event_study(
  yoy_pay,
  ylab = "RD coef on YoY dlog payroll",
  title = "Pregão firm-year RD: dynamic effect on payroll growth",
  outfile = file.path(FIG_DIR, "rd_pregao_event_study_yoy_payroll.pdf")
)

# ─────────────────────────────────────────────────────────────────────
# Plot — Panel B (Cumulative)
# ─────────────────────────────────────────────────────────────────────
plot_cumulative <- function(dt_cum, ylab, title, outfile) {
  # Insert k = -1 anchor at zero (by construction)
  anchor <- data.table(y = "anchor_tm1", coef = 0, se = 0,
                       coef_rb = 0, se_rb = 0,
                       n_L = NA, n_R = NA, h = NA, k = -1, outcome = "")
  d <- rbind(dt_cum, anchor, fill = TRUE)
  setorder(d, k)
  d[, lo := coef - 1.96 * se]
  d[, hi := coef + 1.96 * se]

  pdf(outfile, width = 8, height = 5)
  op <- par(mar = c(5, 5, 4, 2), las = 1)

  ylim <- range(c(d$lo, d$hi, 0), na.rm = TRUE)
  ylim <- ylim + c(-1, 1) * 0.05 * diff(ylim)

  plot(d$k, d$coef,
       type = "n",
       xlim = c(-2.5, 3.5), ylim = ylim,
       xlab = "Year relative to close-bid auction (k)",
       ylab = ylab,
       main = title,
       xaxt = "n")
  axis(1, at = -2:3,
       labels = c("t-2", "t-1\n(baseline)", "t0", "t+1", "t+2", "t+3"))
  abline(h = 0, lty = 2, col = "gray70")
  abline(v = -0.5, lty = 3, col = "gray70")

  # Connect lines
  lines(d$k, d$coef, col = "gray40", lwd = 1.2)

  # Pre-period in gray
  pre <- d[k <= -1]
  points(pre$k, pre$coef, pch = 1, cex = 1.5, col = "gray60", lwd = 2)
  segments(pre$k, pre$lo, pre$k, pre$hi, col = "gray60", lwd = 2)

  # Post-period in black
  post <- d[k >= 0]
  points(post$k, post$coef, pch = 16, cex = 1.5, col = "black")
  segments(post$k, post$lo, post$k, post$hi, col = "black", lwd = 2)

  par(op); dev.off()
  cat("[written]", outfile, "\n")
}

plot_cumulative(
  cum_emp,
  ylab = "RD coef on cumulative dlog employment",
  title = "Pregão firm-year RD: cumulative effect on log employment",
  outfile = file.path(FIG_DIR, "rd_pregao_event_study_cumulative_emp.pdf")
)

cat("\nDone.\n")
