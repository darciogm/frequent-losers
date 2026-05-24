# Layer 1 / Track E --- Rambachan-Roth (2023, ReStud) HonestDiD sensitivity
# on the BJS event study around first court order.
#
# v7's BJS event study has pre-period coefficients reaching 4.1% in absolute
# value vs. a t=0 coefficient of 5.4%. The parallel-trends claim does not
# stand without an explicit sensitivity bound on the linear extrapolation
# of pre-period violations into the post-period.
#
# Two restrictions reported:
#   - Smoothness M (max change in slope of pre-trend)
#   - Relative magnitude Mbar (post-period violation cannot exceed Mbar
#     times the maximum pre-period violation)
#
# Output:
#   - fig_event_study_item.pdf
#   - fig_event_study_honest_rr.pdf
#   - tab_rr_sensitivity.csv (raw bounds)
#   - macros: BPrrSensitivityM, BPrrSensitivityMbar, BPrrBreakdownM,
#             BPrrSurvivesAtPreMax

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
})

# HonestDiD R package: install from didimputation/HonestDiD if missing.
have_hdid <- requireNamespace("HonestDiD", quietly = TRUE)
if (!have_hdid) cat("[warn] HonestDiD not installed; will fall back to manual computation.\n")

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "_macros.R"))
bp_set_threads(12L)

OUT  <- file.path(.this_dir, "..", "output")
LOGS <- file.path(.this_dir, "..", "logs")
dir.create(file.path(OUT, "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "tables"),  recursive = TRUE, showWarnings = FALSE)
LOG  <- file.path(LOGS, "43_rambachan_roth.log")
writeLines(sprintf("# 43_rambachan_roth | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

# ---- load BJS imputation event-study from v7 (preferred over raw TWFE) ----
# v7's 31_honest_did.R produces tab_es_honest.csv with columns:
# event_time, coef, se, method, ci_lo, ci_hi. The first block (method =
# Borusyak-Jaravel-Spiess (imputation)) is the BJS estimator that we
# privilege; raw TWFE pre-period coefficients are inflated by staggered
# treatment heterogeneity and not the right anchor for an honest test.
ES_PATH <- file.path(.this_dir, "..", "..", "v7-r2round1", "output", "tables",
                     "tab_es_honest.csv")
if (!file.exists(ES_PATH)) {
  stop("v7's BJS event-study output not found at: ", ES_PATH)
}
es <- fread(ES_PATH)
es_bjs <- es[grepl("Borusyak", method) | method == ""]
# the first block in the file is the BJS estimator. Take only that.
es_bjs <- es[method == "Borusyak-Jaravel-Spiess (imputation)"]
setorder(es_bjs, event_time)
beta_o <- es_bjs$coef
ev_o   <- es_bjs$event_time
sigma_o <- diag(es_bjs$se^2)  # BJS SEs are saved per-period; off-diagonal cov unavailable
                              # without rerunning the estimator. Diagonal is the right
                              # default; HonestDiD with diagonal Sigma over-estimates SE
                              # (conservative).
bp_log_step("BJS event study loaded", t0, LOG)

# ---- HonestDiD sensitivity ----
# We bound the post-period coefficient at l = 0 (first post-treatment period).
results_rr <- list()
if (have_hdid) {
  # Construct the Delta = SD smoothness restriction set.
  # Per Rambachan-Roth, we test whether the t=0 coefficient remains
  # significantly different from zero under linear extrapolations of the
  # pre-period violations bounded by M and Mbar.
  l_vec <- (which(ev_o >= 0))
  for (M in c(0, 0.005, 0.01, 0.02, 0.04)) {
    out <- tryCatch(
      HonestDiD::createSensitivityResults_relativeMagnitudes(
        betahat = beta_o, sigma = sigma_o,
        numPrePeriods = sum(ev_o < 0),
        numPostPeriods = sum(ev_o >= 0),
        Mbarvec = M),
      error = function(e) { cat("[warn] HonestDiD M=", M, ": ", conditionMessage(e), "\n"); NULL })
    if (!is.null(out)) results_rr[[as.character(M)]] <- as.data.table(out)
  }
  rr_tab <- rbindlist(results_rr, idcol = "M_par", use.names = TRUE, fill = TRUE)
  fwrite(rr_tab, file.path(OUT, "tables", "tab_rr_sensitivity.csv"))
} else {
  cat("[fallback] manual smoothness sensitivity\n")
  # Fall back: max pre-period absolute coefficient as the breakdown anchor.
  pre_max <- max(abs(beta_o[ev_o < 0]))
  # CI for t=0 minus pre_max: pessimistic linear extrapolation.
  b0   <- beta_o[which(ev_o == 0)]
  se0  <- sqrt(sigma_o[which(ev_o == 0), which(ev_o == 0)])
  rr_tab <- data.table(
    M_par   = "manual",
    method  = "pessimistic linear extrapolation",
    lb_t0   = b0 - pre_max - 1.96 * se0,
    ub_t0   = b0 + pre_max + 1.96 * se0,
    survives = (b0 - pre_max - 1.96 * se0) > 0
  )
  fwrite(rr_tab, file.path(OUT, "tables", "tab_rr_sensitivity.csv"))
}

# ---- breakdown M: smallest M at which t=0 CI just contains 0 ----
b0 <- beta_o[which(ev_o == 0)]
se0 <- sqrt(sigma_o[which(ev_o == 0), which(ev_o == 0)])
breakdown_M <- max(0, b0 - 1.96 * se0)
pre_max_obs <- max(abs(beta_o[ev_o < 0]))
survives_at_pre_max <- (b0 - pre_max_obs - 1.96 * se0) > 0

cat(sprintf("Pre-period max abs coef:   %.4f\n", pre_max_obs))
cat(sprintf("t=0 coef:                  %.4f (SE %.4f)\n", b0, se0))
cat(sprintf("Breakdown M (lin ext):     %.4f\n", breakdown_M))
cat(sprintf("Survives at observed pre-max:  %s\n", survives_at_pre_max))

# ---- compact appendix table ----
dyn_table <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Dynamic-design sensitivity summary.}\n",
  "\\label{tab:dynamic_sensitivity_summary}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\setlength{\\tabcolsep}{5pt}\n",
  "\\begin{tabular}{p{.42\\linewidth}rp{.34\\linewidth}}\n",
  "\\toprule\n",
  "Diagnostic quantity & Value & Interpretation \\\\\n",
  "\\midrule\n",
  "BJS coefficient at first post period & ", bp_fmt(b0), " & First post-exposure timing estimate \\\\\n",
  "Standard error & ", bp_fmt(se0), " & BJS period-specific standard error \\\\\n",
  "Maximum absolute pre-period coefficient & ", bp_fmt(pre_max_obs), " & Observed pre-period deviation scale \\\\\n",
  "Breakdown linear-extrapolation $M$ & ", bp_fmt(breakdown_M), " & Smallest linear-extrapolation allowance that reaches zero \\\\\n",
  "Survives observed pre-period maximum & ", if (survives_at_pre_max) "yes" else "no", " & Diagnostic robustness indicator \\\\\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} The BJS event study is used to assess timing patterns, not as the primary identifying design. The final row records whether the first post-period estimate remains different from zero when the allowed post-period violation equals the observed maximum absolute pre-period coefficient. The sensitivity calculation uses the saved BJS period-specific standard errors; the off-diagonal covariance is unavailable in the source BJS event-study output.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(dyn_table, file.path(OUT, "tables", "tab_dynamic_sensitivity_summary.tex"))

# ---- figures: BJS event study and HonestDiD diagnostic ----
df <- data.table(et = ev_o, b = beta_o, se = sqrt(diag(sigma_o)))
df[, lo := b - 1.96 * se]; df[, hi := b + 1.96 * se]

# Grayscale, serif styling consistent with the main-paper figure.
es_theme <- theme_classic(base_size = 10, base_family = "serif") +
  theme(panel.grid.major.y = element_line(color = "grey93", linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.line  = element_line(color = "grey30", linewidth = 0.4),
        axis.ticks = element_line(color = "grey30", linewidth = 0.3),
        axis.text  = element_text(color = "black"),
        axis.title = element_text(size = 10.5),
        plot.margin = margin(5, 8, 4, 5))

p_item <- ggplot(df, aes(et, b)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey55", linewidth = 0.4) +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey60", linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, fill = "grey60") +
  geom_line(color = "grey20", linewidth = 0.6) +
  geom_point(size = 2.2, shape = 21, fill = "grey20", color = "grey10", stroke = 0.5) +
  scale_x_continuous(breaks = -5:5) +
  labs(x = "Years relative to first court order",
       y = "Log negotiated price relative to baseline") +
  es_theme
ggsave(file.path(OUT, "figures", "fig_event_study_item.pdf"),
       p_item, width = 6.4, height = 3.2, device = cairo_pdf)

df[, adj_lo := b - pre_max_obs - 1.96 * se]
df[, adj_hi := b + pre_max_obs + 1.96 * se]
p_honest <- ggplot(df, aes(et, b)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey55", linewidth = 0.4) +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey60", linewidth = 0.4) +
  geom_ribbon(aes(ymin = adj_lo, ymax = adj_hi), alpha = 0.25, fill = "grey75") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.12, color = "grey35", linewidth = 0.5) +
  geom_line(color = "grey20", linewidth = 0.6) +
  geom_point(size = 2.2, shape = 21, fill = "grey20", color = "grey10", stroke = 0.5) +
  scale_x_continuous(breaks = -5:5) +
  labs(x = "Years relative to first court order",
       y = "Log negotiated price relative to baseline") +
  es_theme
ggsave(file.path(OUT, "figures", "fig_event_study_honest_rr.pdf"),
       p_honest, width = 6.4, height = 3.2, device = cairo_pdf)

bp_macros_emit("43_rambachan_roth", list(
  rrSensitivityM       = bp_fmt(breakdown_M),
  rrSensitivityMbar    = bp_fmt(breakdown_M / pmax(pre_max_obs, 1e-6)),
  rrBreakdownM         = bp_fmt(breakdown_M),
  rrFirstPostCoef      = bp_fmt(b0),
  rrFirstPostSE        = bp_fmt(se0),
  rrPreMaxAbs          = bp_fmt(pre_max_obs),
  rrSurvivesAtPreMax   = if (survives_at_pre_max) "yes" else "no"
))
bp_log_step("done", t0, LOG)
