#!/usr/bin/env Rscript
# ============================================================================
# 09_event_study_diagnostics.R — Three diagnostic event studies
#
# Purpose: diagnose the +4.5% pre-trend in pregão employment found by 08.
#   (a) survival event study — does the −4.5pp survival effect also have a
#       pre-trend?
#   (b) Q4 (largest contracts) event study — does the pre-trend disappear in
#       big contracts (where treatment is large)?
#   (c) convite event study as falsification — convite has zero average
#       effect; does it ALSO have zero pre-trend? If yes, the pregão
#       pre-trend is real selection (not a design artifact).
#
# Inputs:
#   02_data/final/rd_pilot_pregao_firmyear_sample.parquet
#   02_data/final/rd_pilot_firmyear_sample.parquet  (convite)
#
# Outputs:
#   04_figures/rd_event_study_survival.pdf
#   04_figures/rd_event_study_q4.pdf
#   04_figures/rd_event_study_convite.pdf
#   02_data/intermediate/rd_event_study_diagnostics_table.csv
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rdrobust)
})

BASE         <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
PREGAO_PATH  <- file.path(BASE, "02_data/final/rd_pilot_pregao_firmyear_sample.parquet")
CONVITE_PATH <- file.path(BASE, "02_data/final/rd_pilot_firmyear_sample.parquet")
FIG_DIR      <- file.path(BASE, "04_figures")
OUT_DIR      <- file.path(BASE, "02_data/intermediate")
TABLE_PATH   <- file.path(OUT_DIR, "rd_event_study_diagnostics_table.csv")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

cat("Event study diagnostics — pregão pre-trend investigation\n")
cat("Run at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat(strrep("=", 70), "\n\n")

# ─────────────────────────────────────────────────────────────────────
# Helper: RD on a vector with running variable + cluster
# ─────────────────────────────────────────────────────────────────────
run_rd <- function(y, x, cluster, label) {
  idx <- is.finite(y)
  if (sum(idx) < 300) {
    return(data.table(label = label, coef = NA_real_, se = NA_real_,
                      n_L = NA_integer_, n_R = NA_integer_, h = NA_real_))
  }
  fit <- tryCatch(
    rdrobust(y = y[idx], x = x[idx], c = 0,
             cluster = cluster[idx],
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) NULL)
  if (is.null(fit)) {
    return(data.table(label = label, coef = NA_real_, se = NA_real_,
                      n_L = NA_integer_, n_R = NA_integer_, h = NA_real_))
  }
  data.table(label = label,
             coef = fit$coef[1, 1], se = fit$se[1, 1],
             coef_rb = fit$coef[3, 1], se_rb = fit$se[3, 1],
             n_L = fit$N_h[1], n_R = fit$N_h[2], h = fit$bws[1, 1])
}

# ─────────────────────────────────────────────────────────────────────
# Event-study runner: takes a data.table and a list of outcomes with k
# ─────────────────────────────────────────────────────────────────────
event_study <- function(dt, outcome_pattern, k_values, panel_label) {
  res <- rbindlist(lapply(seq_along(k_values), function(i) {
    k <- k_values[i]
    yname <- outcome_pattern[i]
    if (!yname %in% names(dt)) {
      return(data.table(label = paste(panel_label, yname),
                        coef = NA_real_, se = NA_real_,
                        n_L = NA_integer_, n_R = NA_integer_, h = NA_real_,
                        k = k))
    }
    r <- run_rd(dt[[yname]], dt$running, dt$cluster_id,
                paste(panel_label, yname))
    r[, k := k]
    r
  }))
  res
}

# ─────────────────────────────────────────────────────────────────────
# (a) SURVIVAL event study — pregão
# ─────────────────────────────────────────────────────────────────────
cat("[A] Survival event study — pregão\n")
pregao <- as.data.table(read_parquet(PREGAO_PATH))
pregao[, cluster_id := .GRP, by = cnpj_raiz]

surv_pregao <- event_study(
  pregao,
  outcome_pattern = c("survived_tm2", "survived_tm1", "survived_t0",
                      "survived_tp1", "survived_tp2", "survived_tp3"),
  k_values = c(-2, -1, 0, 1, 2, 3),
  panel_label = "PREGAO survival"
)
print(surv_pregao[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

# ─────────────────────────────────────────────────────────────────────
# (b) Q4 (largest contracts) — pregão employment + survival
# ─────────────────────────────────────────────────────────────────────
cat("\n[B] Q4 (largest contracts) restricted event study — pregão\n")
q4_cutoff <- quantile(pregao$log_ref_price, 0.75, na.rm = TRUE)
cat("  Q4 cutoff (log ref_price):", round(q4_cutoff, 2), "\n")
q4 <- pregao[!is.na(log_ref_price) & log_ref_price > q4_cutoff]
cat("  Q4 sample size:", format(nrow(q4), big.mark = ","), "\n")

q4[, cluster_id := .GRP, by = cnpj_raiz]

q4_emp_yoy <- event_study(
  q4,
  outcome_pattern = c("dlog_emp_yoy_tm1", "dlog_emp_yoy_t0",
                      "dlog_emp_yoy_tp1", "dlog_emp_yoy_tp2",
                      "dlog_emp_yoy_tp3"),
  k_values = c(-1, 0, 1, 2, 3),
  panel_label = "PREGAO Q4 emp YoY"
)
cat("  Q4 emp YoY event study:\n")
print(q4_emp_yoy[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

q4_surv <- event_study(
  q4,
  outcome_pattern = c("survived_tm2", "survived_tm1", "survived_t0",
                      "survived_tp1", "survived_tp2", "survived_tp3"),
  k_values = c(-2, -1, 0, 1, 2, 3),
  panel_label = "PREGAO Q4 survival"
)
cat("  Q4 survival event study:\n")
print(q4_surv[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

# ─────────────────────────────────────────────────────────────────────
# (c) CONVITE falsification event study — emp YoY and survival
# ─────────────────────────────────────────────────────────────────────
cat("\n[C] Convite falsification event study\n")
convite <- as.data.table(read_parquet(CONVITE_PATH))
convite[, cluster_id := .GRP, by = cnpj_raiz]
cat("  convite firm-year sample:", format(nrow(convite), big.mark = ","), "rows\n")

con_emp_yoy <- event_study(
  convite,
  outcome_pattern = c("dlog_emp_yoy_tm1", "dlog_emp_yoy_t0",
                      "dlog_emp_yoy_tp1", "dlog_emp_yoy_tp2",
                      "dlog_emp_yoy_tp3"),
  k_values = c(-1, 0, 1, 2, 3),
  panel_label = "CONVITE emp YoY"
)
cat("  Convite emp YoY:\n")
print(con_emp_yoy[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

con_surv <- event_study(
  convite,
  outcome_pattern = c("survived_tm2", "survived_tm1", "survived_t0",
                      "survived_tp1", "survived_tp2", "survived_tp3"),
  k_values = c(-2, -1, 0, 1, 2, 3),
  panel_label = "CONVITE survival"
)
cat("  Convite survival:\n")
print(con_surv[, .(k, coef, se, coef_rb, se_rb, n_L, n_R, h)])

# ─────────────────────────────────────────────────────────────────────
# Persist
# ─────────────────────────────────────────────────────────────────────
all_res <- rbindlist(list(
  cbind(surv_pregao,    panel = "A: pregao survival"),
  cbind(q4_emp_yoy,     panel = "B: pregao Q4 emp YoY"),
  cbind(q4_surv,        panel = "B: pregao Q4 survival"),
  cbind(con_emp_yoy,    panel = "C: convite emp YoY"),
  cbind(con_surv,       panel = "C: convite survival")
), fill = TRUE)
fwrite(all_res, TABLE_PATH)
cat("\n[written]", TABLE_PATH, "\n")

# ─────────────────────────────────────────────────────────────────────
# Plotting
# ─────────────────────────────────────────────────────────────────────
plot_event <- function(dt_es, ylab, title, outfile,
                       hline = 0, anchor_k = NULL) {
  pdf(outfile, width = 8, height = 5)
  op <- par(mar = c(5, 5, 4, 2), las = 1)
  dt_es[, lo := coef - 1.96 * se]
  dt_es[, hi := coef + 1.96 * se]
  ylim <- range(c(dt_es$lo, dt_es$hi, hline), na.rm = TRUE)
  ylim <- ylim + c(-1, 1) * 0.05 * diff(ylim)

  plot(dt_es$k, dt_es$coef,
       type = "n",
       xlim = range(dt_es$k) + c(-0.5, 0.5),
       ylim = ylim,
       xlab = "Year relative to close-bid auction (k)",
       ylab = ylab,
       main = title,
       xaxt = "n")
  axis(1, at = sort(unique(dt_es$k)),
       labels = paste0("t", ifelse(sort(unique(dt_es$k)) >= 0, "+",
                                   ""), sort(unique(dt_es$k))))
  abline(h = hline, lty = 2, col = "gray70")
  abline(v = -0.5, lty = 3, col = "gray70")

  pre <- dt_es[k < 0]
  post <- dt_es[k >= 0]
  lines(dt_es$k, dt_es$coef, col = "gray50", lwd = 1.2)
  if (nrow(pre) > 0) {
    points(pre$k, pre$coef, pch = 1, cex = 1.5, col = "gray50", lwd = 2)
    segments(pre$k, pre$lo, pre$k, pre$hi, col = "gray50", lwd = 2)
  }
  points(post$k, post$coef, pch = 16, cex = 1.5)
  segments(post$k, post$lo, post$k, post$hi, lwd = 2)

  par(op); dev.off()
  cat("[written]", outfile, "\n")
}

plot_event(
  surv_pregao,
  ylab = "RD coef on P(survive)",
  title = "Pregao firm-year RD: survival event study",
  outfile = file.path(FIG_DIR, "rd_event_study_survival.pdf")
)

plot_event(
  q4_emp_yoy,
  ylab = "RD coef on YoY dlog employment",
  title = "Pregao firm-year RD: emp growth (Q4 largest contracts only)",
  outfile = file.path(FIG_DIR, "rd_event_study_q4_emp.pdf")
)

plot_event(
  q4_surv,
  ylab = "RD coef on P(survive)",
  title = "Pregao firm-year RD: survival (Q4 largest contracts only)",
  outfile = file.path(FIG_DIR, "rd_event_study_q4_survival.pdf")
)

plot_event(
  con_emp_yoy,
  ylab = "RD coef on YoY dlog employment",
  title = "Convite firm-year RD: emp growth (falsification)",
  outfile = file.path(FIG_DIR, "rd_event_study_convite_emp.pdf")
)

plot_event(
  con_surv,
  ylab = "RD coef on P(survive)",
  title = "Convite firm-year RD: survival (falsification)",
  outfile = file.path(FIG_DIR, "rd_event_study_convite_survival.pdf")
)

cat("\nDone.\n")
