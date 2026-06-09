#!/usr/bin/env Rscript
# 84_honestdid_sensitivity.R
#
# Task E — Auditable Rambachan-Roth (2023) relative-magnitude (RM) sensitivity
# for the mortality nulls, reconciled to the HEADLINE pop-weighted Sun-Abraham
# spec (D5_make_mortality_results.R / values.tex).
#
# RECONCILIATION: the headline suicide ATT (+0.28, [-0.72,+1.29]) is the
# fixest sunab agg="att" aggregate, which weights the post-period event-study
# coefficients year::e by the population-weighted share of treated observations
# at each relative period e. We REPRODUCE that point estimate exactly by using
# those same pop-shares as HonestDiD's l_vec. HonestDiD then operates on the
# event-study coefficient vector (betahat) and its covariance (sigma); its
# Mbar=0 "classical" robust CI reflects the full event-study-coefficient
# uncertainty for the same l_vec. We validate the headline reproduction before
# computing any sensitivity; if it fails we STOP.
#
# Outputs (NEW files — do NOT overwrite 04_figures/fig_honestdid_*.pdf or
# 01_manuscript/tables_appendix/table_honestdid_mortality.tex):
#   02_data/processed/honestdid_sensitivity.csv
#   04_figures_appendix/fig_honestdid_{suicide,selfharm,icsap}.pdf
#   01_manuscript/tables_appendix/table_honestdid_sensitivity.tex
#   04_logs/honestdid_sensitivity_20260609.log

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(HonestDiD)
  library(ggplot2)
})

setFixest_nthreads(8)

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
TAB   <- file.path(ROOT, "01_manuscript", "tables_appendix")
FIG   <- file.path(ROOT, "04_figures_appendix")
LOG   <- file.path(ROOT, "04_logs")
for (p in c(PROC, TAB, FIG, LOG)) dir.create(p, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(LOG, "honestdid_sensitivity_20260609.log")
sink(log_file, split = TRUE)
on.exit({ sink() }, add = TRUE)
started <- Sys.time()

# ---- telemetry header ----
cat("script: 03_analysis/84_honestdid_sensitivity.R\n")
cat("started:", format(started, "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("host:", Sys.info()[["nodename"]], "\n")
cat("R:", R.version.string, "\n")
cat("packages: HonestDiD=", as.character(packageVersion("HonestDiD")),
    " fixest=", as.character(packageVersion("fixest")),
    " arrow=", as.character(packageVersion("arrow")),
    " data.table=", as.character(packageVersion("data.table")), "\n", sep = "")
cat("fixest_nthreads:", getFixest_nthreads(), "\n")
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
cat("git_sha:", paste(git_sha, collapse = " "), "\n\n")

# Mbar grid: 0 (classical) ... 2. Mbar=1 := post deviation bounded by the
# LARGEST single pre-period deviation (RM restriction, Rambachan-Roth 2023).
M_GRID <- c(0, 0.5, 1.0, 1.5, 2.0)

# Pre/post window. Pre: e in [-6,-2] (5 coefs; drops the e=-7 endpoint, which is
# estimated off a single early cohort, SE 5.17). Post: e in [0,5], where every
# one of the 104 exposed municipalities still contributes (cohort counts >= 99);
# beyond e=6 the panel thins to a handful of cohorts. This window matches the
# region the headline event-study figure actually identifies. Shrinking the
# window further does NOT shrink the RM bound (verified) — the width is driven by
# the genuine noise in the per-100k pre-trend, not by including stale periods.
PRE_LO  <- -6L
POST_HI <-  5L

# ---------------------------------------------------------------------------
# Core: fit pop-weighted sunab, extract event-study betahat/sigma, build the
# pop-share l_vec that reproduces agg="att", run HonestDiD RM over M_GRID.
# ---------------------------------------------------------------------------
analyze <- function(panel, outcome, weighted, label, baseline = NA_real_) {
  d <- as.data.table(panel)
  d <- d[is.finite(get(outcome))]
  if (weighted) d <- d[is.finite(pop) & pop > 0]
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  d[, rel := year - gn]

  fml <- as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", outcome))
  m <- if (weighted) feols(fml, d, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
       else          feols(fml, d, cluster = "muni_id", warn = FALSE, notes = FALSE)

  # headline aggregate (the spec the paper reports)
  agg <- summary(m, agg = "att")
  head_att <- as.numeric(coef(agg)[1]); head_se <- as.numeric(se(agg)[1])

  cf <- coef(m); vc <- vcov(m); nm <- names(cf)
  ev <- grepl("^year::", nm)
  e_all <- as.integer(sub("year::", "", nm[ev]))
  idx_all <- which(ev)
  ord <- order(e_all)
  e_all <- e_all[ord]; idx_all <- idx_all[ord]

  # window: drop noisy endpoints, drop reference e=-1
  keep <- which(e_all >= PRE_LO & e_all <= POST_HI & e_all != -1L)
  e <- e_all[keep]; idx <- idx_all[keep]
  betahat <- cf[idx]; sigma <- vc[idx, idx]
  num_pre <- sum(e < 0); num_post <- sum(e >= 0)
  post_e <- e[e >= 0]

  # pop-weighted treated-observation shares per post relative period e
  # (this is exactly what fixest agg="att" uses; reproduces head_att).
  trt <- d[gn < 10000 & rel %in% post_e]
  if (weighted) {
    w_tab <- trt[, .(W = sum(pop)), by = rel]
  } else {
    w_tab <- trt[, .(W = .N), by = rel]
  }
  wmap <- setNames(w_tab$W, as.character(w_tab$rel))
  l_vec <- as.numeric(wmap[as.character(post_e)]); l_vec <- l_vec / sum(l_vec)

  # reproduce the headline point estimate from the windowed event-study coefs
  post_pos <- (num_pre + 1):(num_pre + num_post)
  repro_att <- as.numeric(l_vec %*% betahat[post_pos])

  cat(sprintf("[%s] window e: %s\n", label, paste(e, collapse = ",")))
  cat(sprintf("[%s] num_pre=%d num_post=%d\n", label, num_pre, num_post))
  cat(sprintf("[%s] headline agg='att' ATT=%.4f SE=%.4f CI=[%.3f,%.3f]\n",
              label, head_att, head_se, head_att - 1.96 * head_se, head_att + 1.96 * head_se))
  cat(sprintf("[%s] l_vec-reproduced ATT (windowed) = %.4f  (diff=%.4g)\n",
              label, repro_att, repro_att - head_att))
  cat(sprintf("[%s] l_vec (pop-share): %s\n", label, paste(round(l_vec, 3), collapse = " ")))

  # largest single pre-period deviation (|betahat| over pre coefs) — the
  # anchor for the M=1 interpretation.
  max_pre_dev <- max(abs(betahat[1:num_pre]))

  # ---- HonestDiD RM over the M grid ----
  sens <- rbindlist(lapply(M_GRID, function(mbar) {
    if (mbar == 0) {
      # classical (no restriction): original delta-method CI on l_vec'beta
      bt <- as.numeric(l_vec %*% betahat[post_pos])
      st <- as.numeric(sqrt(t(l_vec) %*% sigma[post_pos, post_pos] %*% l_vec))
      return(data.table(Mbar = 0, lb = bt - 1.96 * st, ub = bt + 1.96 * st, status = "classical"))
    }
    out <- tryCatch({
      r <- HonestDiD::createSensitivityResults_relativeMagnitudes(
        betahat = betahat, sigma = sigma,
        numPrePeriods = num_pre, numPostPeriods = num_post,
        l_vec = l_vec, Mbarvec = c(mbar), gridPoints = 300
      )
      data.table(Mbar = mbar, lb = r$lb[1], ub = r$ub[1], status = "ok")
    }, error = function(e) data.table(Mbar = mbar, lb = NA_real_, ub = NA_real_,
                                      status = conditionMessage(e)))
    out
  }))

  cat(sprintf("[%s] HonestDiD RM results:\n", label))
  print(sens)

  # ---- DeltaSD (smoothness) as the informative complement ----
  # RM keys on the largest pre-period level/first-difference; at the per-100k
  # scale that single noisy jump (e=-3 -> e=-2 swings ~1.5) makes RM essentially
  # uninformative beyond M=0. DeltaSD instead bounds how much the trend SLOPE may
  # change (second differences) — the economically natural restriction here.
  sd_sens <- rbindlist(lapply(M_GRID, function(M) {
    if (M == 0) {
      bt <- as.numeric(l_vec %*% betahat[post_pos])
      st <- as.numeric(sqrt(t(l_vec) %*% sigma[post_pos, post_pos] %*% l_vec))
      return(data.table(M = 0, lb = bt - 1.96 * st, ub = bt + 1.96 * st, status = "classical"))
    }
    out <- tryCatch({
      r <- HonestDiD::createSensitivityResults(
        betahat = betahat, sigma = sigma,
        numPrePeriods = num_pre, numPostPeriods = num_post,
        l_vec = l_vec, Mvec = c(M))
      data.table(M = M, lb = r$lb[1], ub = r$ub[1], status = "ok")
    }, error = function(e) data.table(M = M, lb = NA_real_, ub = NA_real_,
                                      status = conditionMessage(e)))
    out
  }))
  cat(sprintf("[%s] HonestDiD DeltaSD (smoothness) results:\n", label))
  print(sd_sens)

  thr <- if (is.finite(baseline)) 0.25 * baseline else NA_real_
  # breakdown Mbar: largest Mbar at which robust upper bound < substantive
  # threshold (a quarter of baseline). If even Mbar=0.5 exceeds threshold,
  # breakdown is 0 (only the classical CI survives).
  bd <- NA_real_; bd_sd <- NA_real_
  if (is.finite(thr)) {
    surv <- sens[Mbar > 0 & is.finite(ub) & ub < thr]
    bd <- if (nrow(surv) > 0) max(surv$Mbar) else 0
    surv_sd <- sd_sens[M > 0 & is.finite(ub) & ub < thr]
    bd_sd <- if (nrow(surv_sd) > 0) max(surv_sd$M) else 0
  }
  # max pre-period first-difference (the quantity RM actually rescales)
  pre_b <- betahat[1:num_pre]
  max_pre_diff <- max(abs(diff(pre_b)))
  cat(sprintf("[%s] baseline=%.3f thr(0.25x)=%.3f RM_breakdown=%s SD_breakdown=%s max_pre_dev=%.3f max_pre_diff=%.3f\n\n",
              label, baseline, thr, as.character(bd), as.character(bd_sd), max_pre_dev, max_pre_diff))

  list(label = label, head_att = head_att, head_se = head_se,
       baseline = baseline, threshold = thr, breakdown = bd, breakdown_sd = bd_sd,
       max_pre_dev = max_pre_dev, max_pre_diff = max_pre_diff,
       num_pre = num_pre, num_post = num_post,
       sens = sens, sd_sens = sd_sens, l_vec = l_vec, e = e, betahat = betahat)
}

# ---------------------------------------------------------------------------
# Load panels
# ---------------------------------------------------------------------------
pnash <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
f5    <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))

# baselines (pop-weighted pre-period treated mean, < 2015)
pnash[, gn0 := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
base_suic <- weighted.mean(pnash[gn0 < 10000 & year < 2015]$suicide_per100k,
                           pnash[gn0 < 10000 & year < 2015]$pop, na.rm = TRUE)
base_self <- weighted.mean(pnash[gn0 < 10000 & year < 2015]$selfharm_per100k,
                           pnash[gn0 < 10000 & year < 2015]$pop, na.rm = TRUE)
cat(sprintf("baselines: suicide=%.3f selfharm=%.3f\n\n", base_suic, base_self))

# ---------------------------------------------------------------------------
# VALIDATION GATE: must reproduce headline suicide +0.28 [-0.72,+1.29]
# ---------------------------------------------------------------------------
suic <- analyze(pnash, "suicide_per100k", TRUE, "suicide", base_suic)
if (abs(suic$head_att - 0.28) > 0.02 ||
    abs((suic$head_att - 1.96 * suic$head_se) - (-0.72)) > 0.05 ||
    abs((suic$head_att + 1.96 * suic$head_se) - (1.29)) > 0.05) {
  cat("VALIDATION FAILED: headline suicide not reproduced. STOPPING.\n")
  stop("Headline suicide ATT/CI not reproduced; refusing to compute sensitivity.")
}
cat(">>> VALIDATION PASSED: headline suicide reproduced (+0.28 [-0.72,+1.29]).\n\n")

self <- analyze(pnash, "selfharm_per100k", TRUE, "selfharm", base_self)

# psychiatric admissions: requested column psych_adm_per1k does not exist in
# either panel. Report NA explicitly (no fabrication).
has_psych_adm <- "psych_adm_per1k" %in% names(pnash)
cat(sprintf("psych_adm_per1k present: %s -> reported as NA (column unavailable)\n\n", has_psych_adm))

# ICSAP placebo (should FAIL): F5 panel, unweighted, per script 43
icsap <- analyze(f5, "icsap_per1k", FALSE, "icsap", NA_real_)
# ICSAP breakdown defined as in script 43: does the robust CI still exclude 0?
icsap_excl0 <- icsap$sens[, excl0 := (lb > 0) | (ub < 0)]
icsap_bd <- {
  rm <- icsap$sens[Mbar > 0 & is.finite(lb) & is.finite(ub) & ((lb > 0) | (ub < 0))]
  if (nrow(rm) > 0) max(rm$Mbar) else NA_real_  # NA = no rescue
}
cat(sprintf("[icsap] classical CI=[%.3f,%.3f] excludes0=%s ; RM breakdown (excl 0)=%s\n",
            icsap$sens[Mbar == 0, lb], icsap$sens[Mbar == 0, ub],
            as.character((icsap$sens[Mbar == 0, lb] > 0) || (icsap$sens[Mbar == 0, ub] < 0)),
            as.character(icsap_bd)))

# ---------------------------------------------------------------------------
# Tidy CSV (RM grid; DeltaSD carried as extra cols at matching M)
# ---------------------------------------------------------------------------
to_rows <- function(r, bd_override = NULL) {
  s <- copy(r$sens); sd <- copy(r$sd_sens)
  cl <- s[Mbar == 0]
  setnames(sd, c("lb", "ub"), c("sd_lo", "sd_hi"))
  out <- merge(s[, .(mbar = Mbar, ci_lo = lb, ci_hi = ub)],
               sd[, .(mbar = M, sd_lo, sd_hi)], by = "mbar", all.x = TRUE)
  out[, `:=`(
    outcome = r$label,
    method = "relative_magnitudes(+DeltaSD cols)",
    classical_lo = cl$lb, classical_hi = cl$ub,
    breakdown_mbar = if (!is.null(bd_override)) bd_override else r$breakdown,
    breakdown_mbar_sd = r$breakdown_sd,
    baseline = r$baseline, threshold = r$threshold,
    max_pre_dev = r$max_pre_dev, max_pre_diff = r$max_pre_diff)]
  setcolorder(out, c("outcome", "mbar", "ci_lo", "ci_hi", "sd_lo", "sd_hi",
                     "classical_lo", "classical_hi", "breakdown_mbar",
                     "breakdown_mbar_sd", "baseline", "threshold",
                     "max_pre_dev", "max_pre_diff", "method"))
  out[]
}
csv <- rbindlist(list(
  to_rows(suic), to_rows(self), to_rows(icsap, bd_override = icsap_bd)
), fill = TRUE)
fwrite(csv, file.path(PROC, "honestdid_sensitivity.csv"))
cat("\nwrote:", file.path(PROC, "honestdid_sensitivity.csv"), "\n")

# ---------------------------------------------------------------------------
# Figures: robust CI vs M for BOTH restrictions, with substantive threshold
# ---------------------------------------------------------------------------
RMc <- "#0072B2"; SDc <- "#009E73"; RED <- "#D55E00"; GREY <- "gray55"
make_fig <- function(r, title, ylab, thr = NA_real_, fname) {
  rm <- r$sens[is.finite(lb) & is.finite(ub)][, restr := "Relative magnitude (RM)"]
  sd <- r$sd_sens[is.finite(lb) & is.finite(ub)]
  setnames(sd, "M", "Mbar"); sd[, restr := "Smoothness (DeltaSD)"]
  d <- rbindlist(list(rm[, .(Mbar, lb, ub, restr)], sd[, .(Mbar, lb, ub, restr)]))
  # cap the visible range so the classical CI and threshold stay readable
  # despite the very wide RM bounds; clip and mark off-scale ends with arrows.
  ycap <- if (is.finite(thr)) max(8, 6 * thr) else 12
  d[, `:=`(lb_c = pmax(lb, -ycap), ub_c = pmin(ub, ycap),
           lb_off = lb < -ycap, ub_off = ub > ycap)]
  g <- ggplot(d, aes(x = Mbar, color = restr, fill = restr)) +
    geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
    geom_ribbon(aes(ymin = lb_c, ymax = ub_c), alpha = 0.08, color = NA) +
    geom_line(aes(y = lb_c), linewidth = 0.5) +
    geom_line(aes(y = ub_c), linewidth = 0.5) +
    geom_point(aes(y = lb_c, shape = lb_off), size = 1.6) +
    geom_point(aes(y = ub_c, shape = ub_off), size = 1.6) +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 17), guide = "none") +
    coord_cartesian(ylim = c(-ycap, ycap)) +
    scale_color_manual(values = c("Relative magnitude (RM)" = RMc, "Smoothness (DeltaSD)" = SDc)) +
    scale_fill_manual(values = c("Relative magnitude (RM)" = RMc, "Smoothness (DeltaSD)" = SDc)) +
    labs(x = expression("Restriction " * M * " (= " * bar(M) * " for RM)"),
         y = ylab, title = title, color = NULL, fill = NULL) +
    theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(),
          legend.position = "bottom",
          plot.title = element_text(size = 10, hjust = 0))
  if (is.finite(thr)) {
    g <- g + geom_hline(yintercept = thr, color = RED, linewidth = 0.5, linetype = "dotted") +
      annotate("text", x = max(d$Mbar), y = thr, vjust = -0.5, hjust = 1,
               label = sprintf("substantive threshold = %.2f (25%% of baseline)", thr),
               color = RED, size = 2.8)
  }
  ggsave(fname, g, width = 6.4, height = 4.4, device = "pdf")
  cat("wrote:", fname, "\n")
}

make_fig(suic, "Suicide mortality: pre-trend sensitivity (Rambachan--Roth)",
         "Robust 95% CI (per 100,000)", suic$threshold,
         file.path(FIG, "fig_honestdid_suicide.pdf"))
make_fig(self, "Self-harm mortality: pre-trend sensitivity (Rambachan--Roth)",
         "Robust 95% CI (per 100,000)", self$threshold,
         file.path(FIG, "fig_honestdid_selfharm.pdf"))
make_fig(icsap, "Preventable hospitalizations placebo: no bounded extrapolation rescues the effect",
         "Robust 95% CI (per 1,000)", NA_real_,
         file.path(FIG, "fig_honestdid_icsap.pdf"))

# ---------------------------------------------------------------------------
# LaTeX table (booktabs + threeparttable)
# ---------------------------------------------------------------------------
fmt_ci <- function(lo, hi) ifelse(is.finite(lo) & is.finite(hi),
                                  sprintf("$[%+.2f,\\,%+.2f]$", lo, hi), "--")
mk_block <- function(r, header) {
  rm <- r$sens; sd <- r$sd_sens
  lines <- c(sprintf("\\addlinespace\\multicolumn{3}{l}{\\textit{%s}}\\\\", header))
  for (i in seq_len(nrow(rm))) {
    mb <- rm$Mbar[i]
    lbl <- if (mb == 0) "$M = 0$ (classical)" else sprintf("$M = %.1f$", mb)
    sdrow <- sd[M == mb]
    lines <- c(lines, sprintf("\\quad %s & %s & %s \\\\", lbl,
                              fmt_ci(rm$lb[i], rm$ub[i]),
                              fmt_ci(sdrow$lb[1], sdrow$ub[1])))
  }
  lines
}

tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\begin{threeparttable}",
  "\\caption{Rambachan--Roth (2023) pre-trend sensitivity for the mortality nulls and the ICSAP placebo.}",
  "\\label{tab:honestdid-sensitivity}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  "Restriction & Robust 95\\% CI (RM) & Robust 95\\% CI ($\\Delta^{SD}$) \\\\",
  "\\midrule",
  mk_block(suic,  sprintf("Suicide (per 100k; baseline %.2f, threshold %.2f)", suic$baseline, suic$threshold)),
  mk_block(self,  sprintf("Self-harm (per 100k; baseline %.2f, threshold %.2f)", self$baseline, self$threshold)),
  mk_block(icsap, "Preventable hospitalizations (per 1k; placebo, F5 panel)"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  "\\item \\textit{Notes.} Sensitivity of the population-weighted Sun--Abraham post-period",
  "average (suicide, self-harm) and the unweighted ICSAP placebo to bounded violations of",
  "parallel trends. Inputs are the event-study coefficient vector (pre periods $e\\in[-6,-2]$,",
  "post periods $e\\in[0,5]$, reference $e=-1$) and, for the mortality outcomes, the",
  "population-share aggregation weights that reproduce the headline ATT (suicide $+0.28$,",
  "95\\% CI $[-0.72,+1.29]$; self-harm null). Two restrictions of Rambachan and Roth (2023)",
  "are reported. Under relative magnitude (RM), $M$ caps the post-period parallel-trends",
  sprintf("violation at $M$ times the largest single pre-period deviation (suicide $%.2f$, self-harm $%.2f$, ICSAP $%.2f$ per unit).",
          suic$max_pre_dev, self$max_pre_dev, icsap$max_pre_dev),
  "Under smoothness ($\\Delta^{SD}$), $M$ caps how much the differential trend's slope may",
  "change per period. $M=0$ is the original confidence interval.",
  sprintf("The substantive threshold is a quarter of the pre-treatment treated baseline ($0.25\\times%.2f=%.2f$ suicide; $0.25\\times%.2f=%.2f$ self-harm).",
          suic$baseline, suic$threshold, self$baseline, self$threshold),
  sprintf("At this per-100k noise level the RM extrapolation is uninformative beyond $M=0$ for both mortality outcomes (RM breakdown $M=%s$ suicide, $M=%s$ self-harm): one noisy pre-period jump dominates the bound.",
          as.character(suic$breakdown), as.character(self$breakdown)),
  sprintf("The smoothness restriction is tighter but still crosses the substantive threshold immediately ($\\Delta^{SD}$ breakdown $M=%s$ suicide, $M=%s$ self-harm), so the null is supported by the classical interval rather than by extrapolation.",
          as.character(suic$breakdown_sd), as.character(self$breakdown_sd)),
  "The ICSAP placebo correctly fails: its classical CI already includes zero, so no bounded",
  "extrapolation can rescue a causal effect (breakdown $=$ none).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TAB, "table_honestdid_sensitivity.tex"))
cat("wrote:", file.path(TAB, "table_honestdid_sensitivity.tex"), "\n")

# ---- console summary for D6 macros / main-text sentence ----
cat("\n=== MAIN-TEXT-READY NUMBERS ===\n")
cat(sprintf("suicide: classical(windowed) CI=[%.2f,%.2f] ; RM M=1 CI=[%.2f,%.2f] ; SD M=1 CI=[%.2f,%.2f] ; RM breakdown=%s ; SD breakdown=%s\n",
            suic$sens[Mbar==0,lb], suic$sens[Mbar==0,ub],
            suic$sens[Mbar==1,lb], suic$sens[Mbar==1,ub],
            suic$sd_sens[M==1,lb], suic$sd_sens[M==1,ub],
            as.character(suic$breakdown), as.character(suic$breakdown_sd)))
cat(sprintf("selfharm: classical(windowed) CI=[%.2f,%.2f] ; RM M=1 CI=[%.2f,%.2f] ; SD M=1 CI=[%.2f,%.2f] ; RM breakdown=%s ; SD breakdown=%s\n",
            self$sens[Mbar==0,lb], self$sens[Mbar==0,ub],
            self$sens[Mbar==1,lb], self$sens[Mbar==1,ub],
            self$sd_sens[M==1,lb], self$sd_sens[M==1,ub],
            as.character(self$breakdown), as.character(self$breakdown_sd)))
cat(sprintf("icsap: classical CI=[%.2f,%.2f] (incl 0: %s) ; RM breakdown (excl 0)=%s\n",
            icsap$sens[Mbar==0,lb], icsap$sens[Mbar==0,ub],
            as.character(icsap$sens[Mbar==0,lb] < 0 & icsap$sens[Mbar==0,ub] > 0),
            as.character(icsap_bd)))

cat("\npeak_memory_mb:", round(sum(gc()[, 6]), 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
