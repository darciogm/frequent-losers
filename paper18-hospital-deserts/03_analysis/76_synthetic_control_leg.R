#!/usr/bin/env Rscript
# 76_synthetic_control_leg.R
# Second identification leg for the PNASH-48 closure event study.
#
# WHY: the paper's causal core is a staggered Sun-Abraham (SA) event study of
# psychiatric-hospital closures on suicide mortality, identified off
# never-treated parallel trends. A referee discounts a bounded null resting on
# one assumption. Synthetic control (augsynth::multisynth) and synthetic-DiD
# (synthdid) identify off MATCHING pre-treatment trajectories. Convergence
# across designs with different identifying assumptions = real credibility.
# synthdid is doubly robust (Arkhangelsky et al. 2021): valid if EITHER
# parallel trends OR the SC weights are right.
#
# Steps:
#  1. VALIDATE: reproduce canonical SA ATT (~+0.28, CI ~[-0.72,+1.29]).
#  2. multisynth (staggered SC): pooled ATT, pre-fit RMSE, jackknife CI,
#     event-study plot. Repeat for selfharm as secondary.
#  3. synthdid: per-cohort balanced blocks (treated cohort + never-treated),
#     placebo SE, size-weighted aggregate. Report ATT, SE, pre-fit.
#  4. VERDICT: honest read incl. pre-fit quality.
#
# Cache-aware: skips if output exists unless --force.
# Resource: 6 threads (repo budget).

suppressMessages({
  library(duckdb); library(DBI)
  library(data.table)
  library(fixest)
})
setFixest_nthreads(6); setDTthreads(6)
set.seed(20260608)  # synthdid placebo SE is stochastic; pin for reproducibility

# ---- paths & args -----------------------------------------------------------
ROOT   <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
PARQ   <- file.path(ROOT, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")
OUTCSV <- file.path(ROOT, "02_data/processed/synthetic_control_leg.csv")
FIGDIR <- file.path(ROOT, "04_figures")
LOGDIR <- file.path(ROOT, "04_logs")
FIG    <- file.path(FIGDIR, "fig_synthetic_control_es.pdf")
dir.create(LOGDIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIGDIR, showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(OUTCSV), showWarnings = FALSE, recursive = TRUE)

args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args

if (file.exists(OUTCSV) && !FORCE) {
  cat("[cache] output exists, skipping. Use --force to rerun:\n  ", OUTCSV, "\n")
  quit(save = "no", status = 0)
}

# ---- telemetry --------------------------------------------------------------
LOG <- file.path(LOGDIR, sprintf("76_synthetic_control_leg_%s.log",
                                 format(Sys.time(), "%Y%m%d_%H%M%S")))
logcon <- file(LOG, open = "wt")
say <- function(...) {
  msg <- sprintf(...)
  cat(msg, "\n")
  cat(msg, "\n", file = logcon); flush(logcon)
}
rss_gb <- function() {
  st <- tryCatch(readLines("/proc/self/status"), error = function(e) character(0))
  v  <- grep("^VmRSS:", st, value = TRUE)
  if (length(v)) round(as.numeric(gsub("[^0-9]", "", v)) / 1e6, 2) else NA_real_
}
t0 <- Sys.time()
step <- function(tag) say("[%5.1fs | %s GiB] %s",
                          as.numeric(difftime(Sys.time(), t0, units = "secs")),
                          rss_gb(), tag)

say("=== 76_synthetic_control_leg.R ===")
say("host=%s  nproc=%s  RAM=%s",
    Sys.info()[["nodename"]],
    tryCatch(parallel::detectCores(), error = function(e) NA),
    tryCatch(gsub("\\s+", " ", system("free -h | awk 'NR==2{print $2}'", intern = TRUE)),
             error = function(e) NA))
say("threads: fixest=6 data.table=6  force=%s", FORCE)

# ---- load -------------------------------------------------------------------
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=6")
d <- as.data.table(dbGetQuery(con, sprintf(
  "SELECT codmun_6, uf, year, g_emb, muni_id, suicide_per100k,
          selfharm_per100k, pop, travel_burden_km, icsap_per1k
   FROM read_parquet('%s')", PARQ)))
dbDisconnect(con, shutdown = TRUE)

# 2024 is all-NA (no mortality release yet); drop. Cohort coding per spec.
d <- d[year <= 2023]
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
d[, treated_unit := gn < 10000L]
# post-onset 0/1 indicator for multisynth
d[, treated_indicator := as.integer(treated_unit & year >= gn)]
step(sprintf("loaded: %d rows, %d munis, years %d-%d, treated munis=%d, cohorts={%s}",
             nrow(d), uniqueN(d$muni_id), min(d$year), max(d$year),
             uniqueN(d$muni_id[d$treated_unit]),
             paste(sort(unique(d$gn[d$treated_unit])), collapse = ",")))

# Collect results across all steps for the CSV.
results <- list()
add <- function(...) results[[length(results) + 1]] <<- data.table(...)

# =============================================================================
# STEP 1 — VALIDATE canonical Sun-Abraham ATT
# =============================================================================
m_sa <- feols(suicide_per100k ~ sunab(gn, year) | muni_id + year,
              d, cluster = "muni_id", weights = ~pop)
sa   <- summary(m_sa, agg = "att")
sa_att <- sa$coeftable["ATT", "Estimate"]
sa_se  <- sa$coeftable["ATT", "Std. Error"]
sa_lo  <- sa_att - 1.96 * sa_se
sa_hi  <- sa_att + 1.96 * sa_se
say("\n--- STEP 1: Sun-Abraham validation (suicide) ---")
say("SA ATT = %.2f  SE = %.2f  95%% CI = [%.2f, %.2f]", sa_att, sa_se, sa_lo, sa_hi)
add(step = "SA_validation", outcome = "suicide_per100k", method = "sunab",
    att = round(sa_att, 2), se = round(sa_se, 2),
    ci_lo = round(sa_lo, 2), ci_hi = round(sa_hi, 2),
    pre_rmse = NA_real_, n_treated = uniqueN(d$muni_id[d$treated_unit]),
    note = "canonical pop-weighted")

VALID <- abs(sa_att - 0.28) < 0.05
if (!VALID) {
  say("!! VALIDATION FAILED: ATT %.2f != ~0.28. STOPPING.", sa_att)
  fwrite(rbindlist(results), OUTCSV); close(logcon)
  quit(save = "no", status = 1)
}
say("VALIDATION OK (ATT within 0.05 of 0.28).")
step("step1 done")

# =============================================================================
# STEP 2 — staggered synthetic control (augsynth::multisynth)
# =============================================================================
suppressMessages(library(augsynth))

run_multisynth <- function(outcome, label) {
  dd <- copy(d)
  setnames(dd, outcome, "Y")
  dd <- dd[!is.na(Y)]
  # multisynth handles staggered timing via the post-onset 0/1 indicator.
  ms <- multisynth(Y ~ treated_indicator, unit = muni_id, time = year,
                   data = dd, n_leads = 6, n_lags = 8)
  sm <- summary(ms)
  # Pooled (Average) ATT across post periods, with jackknife SE/CI.
  att_tab <- as.data.table(sm$att)
  pooled  <- att_tab[Level == "Average" & is.na(Time)]
  if (nrow(pooled) == 0) pooled <- att_tab[Level == "Average"][.N]
  p_att <- pooled$Estimate[1]; p_se <- pooled$Std.Error[1]
  p_lo  <- p_att - 1.96 * p_se; p_hi <- p_att + 1.96 * p_se
  # Pre-treatment fit. NB: multisynth's pooled "Average" pre-period gaps are ~0
  # by construction (the optimizer balances pre-treatment), so they are NOT an
  # honest fit metric. The honest metric is augsynth's pre-period L2 imbalance:
  #   global_l2        = absolute RMSE-like pre-period imbalance of the synthetic
  #   scaled_global_l2 = that imbalance relative to a uniform-weight (raw avg)
  #                      comparison; <1 = SC beats naive average, >1 = worse.
  pre_rmse  <- sm$global_l2          # per-period root pre-fit imbalance
  scaled    <- sm$scaled_global_l2
  pre_level <- mean(dd[treated_unit == TRUE & year < gn, Y], na.rm = TRUE)
  list(ms = ms, att_tab = att_tab, p_att = p_att, p_se = p_se,
       p_lo = p_lo, p_hi = p_hi, pre_rmse = pre_rmse, scaled = scaled,
       pre_level = pre_level, label = label, outcome = outcome)
}

say("\n--- STEP 2: multisynth (staggered SC) ---")
ms_suic <- run_multisynth("suicide_per100k", "suicide")
say("[suicide] multisynth pooled ATT = %.2f  SE = %.2f  CI = [%.2f, %.2f]",
    ms_suic$p_att, ms_suic$p_se, ms_suic$p_lo, ms_suic$p_hi)
say("[suicide] pre-fit: global_l2 = %.2f  scaled_global_l2 = %.2f  (treated pre level = %.2f, l2/level = %.2f)",
    ms_suic$pre_rmse, ms_suic$scaled, ms_suic$pre_level, ms_suic$pre_rmse / ms_suic$pre_level)
add(step = "multisynth", outcome = "suicide_per100k", method = "augsynth::multisynth",
    att = round(ms_suic$p_att, 2), se = round(ms_suic$p_se, 2),
    ci_lo = round(ms_suic$p_lo, 2), ci_hi = round(ms_suic$p_hi, 2),
    pre_rmse = round(ms_suic$pre_rmse, 2),
    n_treated = uniqueN(d$muni_id[d$treated_unit]),
    note = sprintf("scaled_l2=%.2f pre_level=%.2f l2/level=%.2f",
                   ms_suic$scaled, ms_suic$pre_level, ms_suic$pre_rmse / ms_suic$pre_level))

ms_self <- run_multisynth("selfharm_per100k", "selfharm")
say("[selfharm] multisynth pooled ATT = %.2f  SE = %.2f  CI = [%.2f, %.2f]  pre-RMSE = %.2f",
    ms_self$p_att, ms_self$p_se, ms_self$p_lo, ms_self$p_hi, ms_self$pre_rmse)
add(step = "multisynth", outcome = "selfharm_per100k", method = "augsynth::multisynth",
    att = round(ms_self$p_att, 2), se = round(ms_self$p_se, 2),
    ci_lo = round(ms_self$p_lo, 2), ci_hi = round(ms_self$p_hi, 2),
    pre_rmse = round(ms_self$pre_rmse, 2),
    n_treated = uniqueN(d$muni_id[d$treated_unit]),
    note = "secondary outcome")
step("step2 done")

# event-study plot (pooled, suicide)
ok_plot <- tryCatch({
  es <- ms_suic$att_tab[Level == "Average" & !is.na(Time)]
  setorder(es, Time)
  pdf(FIG, width = 7, height = 4.5)
  plot(es$Time, es$Estimate, type = "b", pch = 19,
       xlab = "Years relative to closure", ylab = "ATT (suicide per 100k)",
       main = "multisynth pooled event study (PNASH-48)")
  abline(h = 0, lty = 2); abline(v = -0.5, lty = 3, col = "grey50")
  if (!is.null(es$Std.Error)) {
    arrows(es$Time, es$Estimate - 1.96 * es$Std.Error,
           es$Time, es$Estimate + 1.96 * es$Std.Error,
           angle = 90, code = 3, length = 0.03, col = "grey40")
  }
  dev.off(); TRUE
}, error = function(e) { say("plot skipped: %s", conditionMessage(e)); FALSE })
if (ok_plot) say("event-study figure -> %s", FIG)

# =============================================================================
# STEP 3 — synthetic-DiD (synthdid), per-cohort blocks + size-weighted aggregate
# =============================================================================
suppressMessages(library(synthdid))
say("\n--- STEP 3: synthdid (per-cohort balanced blocks) ---")

# HANDLING STAGGERING: synthdid needs a balanced common-timing block, so we
# CANNOT feed it the staggered panel directly. Instead we split the staggered
# design into one common-timing block per closure cohort g: that cohort's
# treated munis + ALL never-treated controls, over a common window [g-PRE,g+POST]
# with treatment turning on at year g. Each block is a clean synthdid problem.
# We then aggregate the per-cohort ATTs by size weights (N treated) -- the
# Arkhangelsky et al. (2021) prescription for staggered adoption. Cohorts whose
# window falls outside the data span (2010-2023) are dropped (logged).
# The full never-treated pool is kept as donors; synthdid's regularized omega
# zeroes out irrelevant donors, so a large pool is fine and more stable than a
# random subset. Placebo SE replications are capped (SD_REPL) for tractability
# over the ~5,460-unit donor pool.
PRE <- 4L; POST <- 4L; SD_REPL <- 50L
cohorts <- sort(unique(d$gn[d$treated_unit]))
ctrl_ids <- unique(d$muni_id[!d$treated_unit])

run_synthdid_cohort <- function(g, outcome) {
  win <- (g - PRE):(g + POST)
  if (min(win) < min(d$year) || max(win) > max(d$year)) {
    say("  cohort g=%d skipped: window %d-%d outside data span %d-%d",
        g, min(win), max(win), min(d$year), max(d$year)); return(NULL)
  }
  trt <- unique(d$muni_id[d$gn == g])
  sub <- d[muni_id %in% c(trt, ctrl_ids) & year %in% win]
  setnames(sub, outcome, "Y")
  sub <- sub[!is.na(Y)]
  # require fully balanced units across the window
  bal <- sub[, .N, by = muni_id][N == length(win), muni_id]
  sub <- sub[muni_id %in% bal]
  trt <- intersect(trt, bal)
  if (length(trt) < 1) return(NULL)
  sub[, W := as.integer(muni_id %in% trt & year >= g)]
  setup <- panel.matrices(as.data.frame(sub[, .(muni_id, year, Y, W)]),
                          unit = "muni_id", time = "year",
                          outcome = "Y", treatment = "W")
  tc <- Sys.time()
  est <- synthdid_estimate(setup$Y, setup$N0, setup$T0)
  se  <- tryCatch(sqrt(vcov(est, method = "placebo", replications = SD_REPL)[1, 1]),
                  error = function(e) NA_real_)
  secs <- as.numeric(difftime(Sys.time(), tc, units = "secs"))
  # pre-fit: RMSE between treated avg and synthetic avg over pre-period
  w_unit <- attr(est, "weights")$omega
  Y <- setup$Y; N0 <- setup$N0; T0 <- setup$T0
  trt_pre <- colMeans(Y[(N0 + 1):nrow(Y), 1:T0, drop = FALSE])
  syn_pre <- as.numeric(w_unit %*% Y[1:N0, 1:T0, drop = FALSE])
  pre_rmse <- sqrt(mean((trt_pre - syn_pre)^2))
  list(g = g, att = as.numeric(est), se = se, n_trt = length(trt),
       n_ctrl = N0, pre_rmse = pre_rmse,
       trt_pre_level = mean(trt_pre), secs = secs)
}

sd_rows <- list()
for (g in cohorts) {
  r <- tryCatch(run_synthdid_cohort(g, "suicide_per100k"),
                error = function(e) { say("  cohort %d failed: %s", g, conditionMessage(e)); NULL })
  if (is.null(r)) next
  say("[synthdid g=%d] ATT=%.2f SE=%.2f n_trt=%d n_ctrl=%d pre-RMSE=%.2f (pre level=%.2f) [%.0fs]",
      r$g, r$att, r$se, r$n_trt, r$n_ctrl, r$pre_rmse, r$trt_pre_level, r$secs)
  sd_rows[[length(sd_rows) + 1]] <- as.data.table(r[c("g","att","se","n_trt","n_ctrl","pre_rmse","trt_pre_level")])
}
sd <- rbindlist(sd_rows)

if (nrow(sd) > 0) {
  # size-weighted aggregate ATT; SE via weighted combination of placebo SEs
  w <- sd$n_trt / sum(sd$n_trt)
  agg_att <- sum(w * sd$att)
  # conservative aggregate SE: sqrt(sum(w^2 * se^2)) (independent-cohort approx)
  agg_se  <- sqrt(sum((w^2) * (sd$se^2), na.rm = TRUE))
  agg_lo  <- agg_att - 1.96 * agg_se; agg_hi <- agg_att + 1.96 * agg_se
  agg_pre <- sqrt(sum(w * sd$pre_rmse^2))  # rms of per-cohort pre-fit
  say("\n[synthdid AGGREGATE, size-weighted across %d cohorts]", nrow(sd))
  say("  ATT = %.2f  SE = %.2f  CI = [%.2f, %.2f]  agg pre-RMSE = %.2f",
      agg_att, agg_se, agg_lo, agg_hi, agg_pre)
  add(step = "synthdid_agg", outcome = "suicide_per100k",
      method = "synthdid size-weighted across cohorts",
      att = round(agg_att, 2), se = round(agg_se, 2),
      ci_lo = round(agg_lo, 2), ci_hi = round(agg_hi, 2),
      pre_rmse = round(agg_pre, 2), n_treated = sum(sd$n_trt),
      note = sprintf("PRE=%d POST=%d cohorts={%s}", PRE, POST,
                     paste(sd$g, collapse = ",")))
  for (i in seq_len(nrow(sd))) {
    add(step = "synthdid_cohort", outcome = "suicide_per100k", method = "synthdid",
        att = round(sd$att[i], 2), se = round(sd$se[i], 2),
        ci_lo = round(sd$att[i] - 1.96 * sd$se[i], 2),
        ci_hi = round(sd$att[i] + 1.96 * sd$se[i], 2),
        pre_rmse = round(sd$pre_rmse[i], 2), n_treated = sd$n_trt[i],
        note = sprintf("cohort g=%d n_ctrl=%d", sd$g[i], sd$n_ctrl[i]))
  }
} else {
  say("synthdid produced no usable cohort blocks.")
  agg_att <- NA; agg_se <- NA; agg_pre <- NA
}
step("step3 done")

# =============================================================================
# STEP 4 — VERDICT
# =============================================================================
say("\n========================= STEP 4: VERDICT =========================")
say("Design           ATT     SE     95%% CI            pre-fit RMSE")
say("Sun-Abraham      %5.2f  %5.2f  [%5.2f, %5.2f]     --",
    sa_att, sa_se, sa_lo, sa_hi)
say("multisynth       %5.2f  %5.2f  [%5.2f, %5.2f]     %.2f",
    ms_suic$p_att, ms_suic$p_se, ms_suic$p_lo, ms_suic$p_hi, ms_suic$pre_rmse)
if (nrow(sd) > 0)
  say("synthdid (agg)   %5.2f  %5.2f  [%5.2f, %5.2f]     %.2f",
      agg_att, agg_se, agg_lo, agg_hi, agg_pre)

# Pre-fit quality flags. Two failure modes, not one:
#  POOR  -> synthetic can't track the treated pre-period (RMSE large vs level).
#  DEGENERATE/OVERFIT -> pre-fit RMSE is ~0. With a 5,461-unit donor pool, only
#    ~7 pre-periods, and augsynth's intercept-shift, multisynth drives pre-period
#    imbalance to ~0 mechanically (in-sample interpolation), NOT by finding a
#    real comparison trajectory. A ~0 pre-fit on noisy small-area per-100k rates
#    is implausible and is a RED FLAG, not a credential. So a near-zero fit must
#    NOT be sold as convergence.
ms_scaled <- ms_suic$scaled
ms_ratio  <- ms_suic$pre_rmse / ms_suic$pre_level
say("\nPre-fit diagnostics (suicide):")
say("  multisynth global_l2 = %.4f  scaled_global_l2 = %.4f  global_l2/level = %.4f",
    ms_suic$pre_rmse, ms_scaled, ms_ratio)
ms_degenerate <- ms_ratio < 0.02   # essentially-perfect pre-fit => overfit
ms_poor       <- ms_ratio > 0.5
if (ms_degenerate)
  say("  -> multisynth pre-fit is DEGENERATE (~0): in-sample overfit, NOT credible evidence.")
sd_ratio <- if (nrow(sd) > 0) agg_pre / mean(sd$trt_pre_level) else NA_real_
if (nrow(sd) > 0)
  say("  synthdid pre-RMSE/level = %.2f  (per-cohort %s)",
      sd_ratio, paste(sprintf("g%d=%.2f", sd$g, sd$pre_rmse / sd$trt_pre_level),
                      collapse=" "))

# Convergence: do the SC ATTs land inside the SA CI and stay a bounded null?
in_sa_ci <- function(x) !is.na(x) && x >= sa_lo & x <= sa_hi
ms_conv <- in_sa_ci(ms_suic$p_att)
sd_conv <- if (nrow(sd) > 0) in_sa_ci(agg_att) else NA
# synthdid pre-fit credible if non-degenerate AND not poor.
sd_good <- nrow(sd) > 0 && !is.na(sd_ratio) && sd_ratio > 0.02 && sd_ratio < 0.5

# Honest verdict. The synthdid leg carries the weight because it has a credible,
# non-degenerate pre-fit; the multisynth leg's near-zero fit is discounted.
verdict <- if (sd_good && sd_conv) {
  paste0("STRENGTHEN (via synthdid) — synthdid agg ATT=", round(agg_att,2),
         " sits inside the SA bounded-null CI with a credible pre-fit (RMSE/level=",
         round(sd_ratio,2), "); convergence across designs with different ",
         "identifying assumptions. NB: multisynth pre-fit is degenerate (~0, ",
         "overfit) and is reported but NOT treated as evidence.")
} else if (sd_good && !sd_conv) {
  "INCONCLUSIVE — credible synthdid pre-fit but ATT diverges from SA bounded null"
} else if (ms_degenerate) {
  "INCONCLUSIVE — multisynth pre-fit degenerate (overfit); rely on synthdid leg"
} else {
  "INCONCLUSIVE / FAIL — synthetic pre-fit not interpretable"
}
say("\nVERDICT: %s", verdict)
add(step = "verdict", outcome = "suicide_per100k", method = "comparison",
    att = if (nrow(sd) > 0) round(agg_att, 2) else round(ms_suic$p_att, 2),
    se = if (nrow(sd) > 0) round(agg_se, 2) else NA_real_,
    ci_lo = if (nrow(sd) > 0) round(agg_lo, 2) else NA_real_,
    ci_hi = if (nrow(sd) > 0) round(agg_hi, 2) else NA_real_,
    pre_rmse = if (nrow(sd) > 0) round(agg_pre, 2) else round(ms_suic$pre_rmse, 2),
    n_treated = uniqueN(d$muni_id[d$treated_unit]), note = verdict)

# ---- write ------------------------------------------------------------------
out <- rbindlist(results, fill = TRUE)
fwrite(out, OUTCSV)
say("\nwrote %s (%d rows)", OUTCSV, nrow(out))
step("DONE")
close(logcon)
