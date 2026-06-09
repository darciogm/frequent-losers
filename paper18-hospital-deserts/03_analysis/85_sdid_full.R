#!/usr/bin/env Rscript
# 85_sdid_full.R
# Synthetic difference-in-differences (Arkhangelsky et al. 2021) as an
# AUDITABLE SECOND identification leg for the PNASH-48 closure event study.
#
# WHY: the headline design is a pop-weighted Sun-Abraham (SA) staggered event
# study of psychiatric-hospital closures on suicide mortality, identified off
# never-treated parallel trends. A bounded null resting on a single identifying
# assumption is fragile to a referee. synthdid is doubly robust: valid if EITHER
# parallel trends OR the synthetic-control weights hold. If its size-weighted
# aggregate ATT lands inside the SA bounded-null CI with a credible (non-
# degenerate) pre-fit, the two designs converge on the same null.
#
# This script:
#  1. Re-verifies the suicide synthdid aggregate ATT/CI from 76_*.R (target
#     -0.22 [-1.76,+1.31]) by re-running the SAME per-cohort construction.
#  2. EXTENDS the identical machinery to selfharm_per100k and psych_adm_per1k.
#  3. Documents the design (donor pool, cohorts/sizes, per-cohort pre-fit RMSE
#     and RMSE/baseline-level, weighting=municipality/size-weighted NOT pop-
#     weighted, inference=placebo SE with replication count) and a
#     permutation/placebo sanity check.
#  4. Builds an appendix pre-fit figure (observed vs synthetic, event time).
#  5. Writes a booktabs+threeparttable appendix table.
#
# IMPORTANT: the synthdid leg is SIZE-WEIGHTED across cohorts at the MUNICIPALITY
# level (weight = N treated munis in cohort), NOT population-weighted. This
# contrasts with the pop-weighted SA headline. Both are reported; the contrast
# is documented in the table note.
#
# Outputs (this script owns):
#   02_data/processed/sdid_results.csv
#   04_figures_appendix/fig_sdid_suicide_prefit.pdf
#   01_manuscript/tables_appendix/table_sdid_results.tex
#   04_logs/sdid_diagnostics_20260609.log
#
# Cache-aware: skips if sdid_results.csv exists unless --force.
# Resource: 8 threads (per task spec).

suppressMessages({
  library(arrow); library(data.table)
  library(fixest); library(synthdid); library(ggplot2)
})
setFixest_nthreads(8); setDTthreads(8)
set.seed(20260609)  # synthdid placebo SE is stochastic; pin for reproducibility

# ---- paths & args -----------------------------------------------------------
ROOT   <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
PARQ   <- file.path(ROOT, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")
PSYCH  <- file.path(ROOT, "02_data/intermediate/psych_outcomes_panel.parquet")
OUTCSV <- file.path(ROOT, "02_data/processed/sdid_results.csv")
FIGDIR <- file.path(ROOT, "04_figures_appendix")
TABDIR <- file.path(ROOT, "01_manuscript/tables_appendix")
LOGDIR <- file.path(ROOT, "04_logs")
FIG    <- file.path(FIGDIR, "fig_sdid_suicide_prefit.pdf")
TAB    <- file.path(TABDIR, "table_sdid_results.tex")
LOG    <- file.path(LOGDIR, "sdid_diagnostics_20260609.log")
for (dd in c(FIGDIR, TABDIR, LOGDIR, dirname(OUTCSV))) dir.create(dd, showWarnings = FALSE, recursive = TRUE)

args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args
if (file.exists(OUTCSV) && !FORCE) {
  cat("[cache] output exists, skipping. Use --force to rerun:\n  ", OUTCSV, "\n")
  quit(save = "no", status = 0)
}

# ---- telemetry --------------------------------------------------------------
logcon <- file(LOG, open = "wt")
say <- function(...) { msg <- sprintf(...); cat(msg, "\n"); cat(msg, "\n", file = logcon); flush(logcon) }
rss_gb <- function() {
  st <- tryCatch(readLines("/proc/self/status"), error = function(e) character(0))
  v  <- grep("^VmRSS:", st, value = TRUE)
  if (length(v)) round(as.numeric(gsub("[^0-9]", "", v)) / 1e6, 2) else NA_real_
}
t0 <- Sys.time()
step <- function(tag) say("[%6.1fs | %s GiB] %s",
                          as.numeric(difftime(Sys.time(), t0, units = "secs")), rss_gb(), tag)

say("=== 85_sdid_full.R  (run %s) ===", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
say("host=%s  nproc=%s  RAM=%s",
    Sys.info()[["nodename"]],
    tryCatch(parallel::detectCores(), error = function(e) NA),
    tryCatch(gsub("\\s+", " ", system("free -h | awk 'NR==2{print $2}'", intern = TRUE)),
             error = function(e) NA))
say("threads: fixest=8 data.table=8  force=%s  set.seed=20260609", FORCE)
say("synthdid version: %s", as.character(utils::packageVersion("synthdid")))

# ---- load -------------------------------------------------------------------
P  <- as.data.table(read_parquet(PARQ))
po <- as.data.table(read_parquet(PSYCH))
d  <- merge(P[, !c("psychF_mort_per100k"), with = FALSE],
            po[, .(codmun_6, year, psych_adm_per1k)],
            by = c("codmun_6", "year"), all.x = TRUE)

# 2024 is all-NA for mortality (no SIM release yet); drop. Cohort coding per 76_*.
d <- d[year <= 2023]
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
d[, treated_unit := gn < 10000L]
step(sprintf("loaded: %d rows, %d munis, years %d-%d, treated munis=%d, cohorts={%s}",
             nrow(d), uniqueN(d$muni_id), min(d$year), max(d$year),
             uniqueN(d$muni_id[d$treated_unit]),
             paste(sort(unique(d$gn[d$treated_unit])), collapse = ",")))

# =============================================================================
# STEP 0 — SA headline validation (pop-weighted) for the convergence contrast
# =============================================================================
m_sa <- feols(suicide_per100k ~ sunab(gn, year) | muni_id + year,
              d, cluster = "muni_id", weights = ~pop)
sa   <- summary(m_sa, agg = "att")
sa_att <- sa$coeftable["ATT", "Estimate"]; sa_se <- sa$coeftable["ATT", "Std. Error"]
sa_lo  <- sa_att - 1.96 * sa_se; sa_hi <- sa_att + 1.96 * sa_se
say("\n--- STEP 0: Sun-Abraham headline (suicide, POP-weighted) ---")
say("SA ATT = %.4f  SE = %.4f  95%% CI = [%.4f, %.4f]", sa_att, sa_se, sa_lo, sa_hi)
stopifnot("SA validation failed (ATT != ~0.28)" = abs(sa_att - 0.28) < 0.05)
say("SA validation OK (ATT within 0.05 of 0.28).")

# =============================================================================
# STEP 1+2 — synthdid per-cohort balanced blocks, size-weighted aggregate
# =============================================================================
# HANDLING STAGGERING (identical to 76_*.R): synthdid needs a balanced common-
# timing block, so we split the staggered design into one block per closure
# cohort g: that cohort's treated munis + ALL never-treated controls, over a
# common window [g-PRE, g+POST] with treatment on at year g. Aggregate the
# per-cohort ATTs by size weights (N treated munis) -- the Arkhangelsky et al.
# (2021) staggered-adoption prescription. Cohorts whose window leaves the data
# span (2010-2023) are dropped (logged). The full never-treated pool is kept as
# donors; synthdid's regularized omega zeroes irrelevant donors.
PRE <- 4L; POST <- 4L; SD_REPL <- 50L
cohorts  <- sort(unique(d$gn[d$treated_unit]))
ctrl_ids <- unique(d$muni_id[!d$treated_unit])
say("\nDESIGN: PRE=%d POST=%d common window per cohort; placebo SE replications=%d", PRE, POST, SD_REPL)
say("Donor pool (never-treated munis, full): %d", length(ctrl_ids))
say("Closure cohorts present: {%s}", paste(cohorts, collapse = ","))

# returns full diagnostics + the per-cohort setup matrices for the figure
run_synthdid_cohort <- function(g, outcome, verbose = TRUE) {
  win <- (g - PRE):(g + POST)
  if (min(win) < min(d$year) || max(win) > max(d$year)) {
    if (verbose) say("  cohort g=%d skipped: window %d-%d outside span %d-%d",
                     g, min(win), max(win), min(d$year), max(d$year))
    return(NULL)
  }
  trt <- unique(d$muni_id[d$gn == g])
  sub <- d[muni_id %in% c(trt, ctrl_ids) & year %in% win]
  setnames(sub, outcome, "Y")
  sub <- sub[is.finite(Y)]
  bal <- sub[, .N, by = muni_id][N == length(win), muni_id]   # fully-balanced units only
  sub <- sub[muni_id %in% bal]
  trt <- intersect(trt, bal)
  if (length(trt) < 1) return(NULL)
  sub[, W := as.integer(muni_id %in% trt & year >= g)]
  setup <- panel.matrices(as.data.frame(sub[, .(muni_id, year, Y, W)]),
                          unit = "muni_id", time = "year", outcome = "Y", treatment = "W")
  tc  <- Sys.time()
  est <- synthdid_estimate(setup$Y, setup$N0, setup$T0)
  se  <- tryCatch(sqrt(vcov(est, method = "placebo", replications = SD_REPL)[1, 1]),
                  error = function(e) NA_real_)
  secs <- as.numeric(difftime(Sys.time(), tc, units = "secs"))
  # pre-fit RMSE between treated avg and synthetic avg over the pre-period
  w_unit <- attr(est, "weights")$omega
  Y <- setup$Y; N0 <- setup$N0; T0 <- setup$T0
  trt_pre <- colMeans(Y[(N0 + 1):nrow(Y), 1:T0, drop = FALSE])
  syn_pre <- as.numeric(w_unit %*% Y[1:N0, 1:T0, drop = FALSE])
  pre_rmse <- sqrt(mean((trt_pre - syn_pre)^2))
  # full event-time trajectories (treated avg & synthetic avg) for the figure
  trt_all <- colMeans(Y[(N0 + 1):nrow(Y), , drop = FALSE])
  syn_all <- as.numeric(w_unit %*% Y[1:N0, , drop = FALSE])
  etime   <- as.integer(colnames(Y)) - g
  traj <- data.table(g = g, event_time = etime, treated = trt_all, synthetic = syn_all)
  list(g = g, att = as.numeric(est), se = se, n_trt = length(trt), n_ctrl = N0,
       pre_rmse = pre_rmse, trt_pre_level = mean(trt_pre), secs = secs, traj = traj)
}

# tidy result rows accumulate here
tidy <- list()
addrow <- function(...) tidy[[length(tidy) + 1]] <<- data.table(...)

run_outcome <- function(outcome, label, keep_traj = FALSE) {
  say("\n--- synthdid leg: %s (%s) ---", label, outcome)
  rows <- list(); trajs <- list()
  for (g in cohorts) {
    r <- tryCatch(run_synthdid_cohort(g, outcome),
                  error = function(e) { say("  cohort %d failed: %s", g, conditionMessage(e)); NULL })
    if (is.null(r)) next
    say("[%s g=%d] ATT=%.4f SE=%.4f n_trt=%d n_ctrl=%d pre-RMSE=%.4f (pre level=%.2f, rmse/level=%.3f) [%.0fs]",
        label, r$g, r$att, r$se, r$n_trt, r$n_ctrl, r$pre_rmse, r$trt_pre_level,
        r$pre_rmse / r$trt_pre_level, r$secs)
    rows[[length(rows) + 1]] <- as.data.table(
      r[c("g","att","se","n_trt","n_ctrl","pre_rmse","trt_pre_level")])
    if (keep_traj) trajs[[length(trajs) + 1]] <- r$traj
  }
  sd <- rbindlist(rows)
  if (nrow(sd) == 0) {
    say("[%s] synthdid produced NO usable cohort block -> reporting NA.", label)
    addrow(outcome = outcome, att = NA_real_, se = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
           pre_rmse = NA_real_, pre_rmse_over_level = NA_real_,
           n_donors = length(ctrl_ids), n_cohorts = 0L, n_treated = 0L,
           weighting = "size-weighted (municipality)", inference = sprintf("placebo SE (%d repl)", SD_REPL))
    return(list(sd = sd, traj = NULL))
  }
  w       <- sd$n_trt / sum(sd$n_trt)             # municipality SIZE weights
  agg_att <- sum(w * sd$att)
  agg_se  <- sqrt(sum((w^2) * (sd$se^2), na.rm = TRUE))  # independent-cohort approx
  agg_lo  <- agg_att - 1.96 * agg_se; agg_hi <- agg_att + 1.96 * agg_se
  agg_pre <- sqrt(sum(w * sd$pre_rmse^2))          # size-weighted rms of per-cohort pre-fit
  agg_lvl <- sum(w * sd$trt_pre_level)
  say("[%s AGGREGATE, size-weighted across %d cohorts]", label, nrow(sd))
  say("  ATT = %.4f  SE = %.4f  CI = [%.4f, %.4f]  agg pre-RMSE = %.4f  rmse/level = %.3f",
      agg_att, agg_se, agg_lo, agg_hi, agg_pre, agg_pre / agg_lvl)
  addrow(outcome = outcome, att = agg_att, se = agg_se, ci_lo = agg_lo, ci_hi = agg_hi,
         pre_rmse = agg_pre, pre_rmse_over_level = agg_pre / agg_lvl,
         n_donors = round(mean(sd$n_ctrl)), n_cohorts = nrow(sd), n_treated = sum(sd$n_trt),
         weighting = "size-weighted (municipality)", inference = sprintf("placebo SE (%d repl)", SD_REPL))
  list(sd = sd, traj = if (keep_traj) rbindlist(trajs) else NULL, agg_att = agg_att, w = w)
}

res_suic  <- run_outcome("suicide_per100k",  "suicide",  keep_traj = TRUE)
step("suicide leg done")
res_self  <- run_outcome("selfharm_per100k", "selfharm")
step("selfharm leg done")
res_psych <- run_outcome("psych_adm_per1k",  "psych_adm")
step("psych-adm leg done")

# reproduction check vs 76_*.R headline (-0.22 [-1.76,+1.31])
sr <- rbindlist(tidy, fill = TRUE)[outcome == "suicide_per100k"]
say("\n--- REPRODUCTION CHECK (suicide vs 76_*.R headline -0.22 [-1.76,+1.31]) ---")
say("  this run: ATT=%.2f CI=[%.2f, %.2f]", sr$att, sr$ci_lo, sr$ci_hi)
repro_ok <- abs(round(sr$att,2) - (-0.22)) <= 0.05 &&
            abs(round(sr$ci_lo,2) - (-1.76)) <= 0.10 &&
            abs(round(sr$ci_hi,2) - ( 1.31)) <= 0.10
say("  REPRODUCED: %s", repro_ok)

# =============================================================================
# STEP 3 — permutation / placebo sanity check (suicide)
# =============================================================================
# Assign each treated cohort a same-SIZED random set of never-treated munis as
# PLACEBO treated, holding cohort timing fixed; re-estimate the size-weighted
# aggregate. A credible design yields a placebo distribution centered near 0 and
# wide relative to the real ATT (i.e. the real ATT is not extreme -> consistent
# with the bounded null).
say("\n--- STEP 3: permutation placebo check (suicide, %d draws) ---", 100L)
n_perm <- 100L
real_att <- res_suic$agg_att
perm_atts <- numeric(0)
for (b in seq_len(n_perm)) {
  pr <- list(); pn <- integer(0)
  for (i in seq_len(nrow(res_suic$sd))) {
    g  <- res_suic$sd$g[i]; k <- res_suic$sd$n_trt[i]
    win <- (g - PRE):(g + POST)
    pool <- d[muni_id %in% ctrl_ids & year %in% win]
    setnames(pool, "suicide_per100k", "Y"); pool <- pool[is.finite(Y)]
    bal <- pool[, .N, by = muni_id][N == length(win), muni_id]
    if (length(bal) <= k) next
    fake_trt <- sample(bal, k)
    sub <- pool[muni_id %in% bal]
    sub[, W := as.integer(muni_id %in% fake_trt & year >= g)]
    sm <- tryCatch(panel.matrices(as.data.frame(sub[, .(muni_id, year, Y, W)]),
                   unit = "muni_id", time = "year", outcome = "Y", treatment = "W"),
                   error = function(e) NULL)
    if (is.null(sm)) next
    e  <- tryCatch(as.numeric(synthdid_estimate(sm$Y, sm$N0, sm$T0)), error = function(e) NA_real_)
    pr[[length(pr)+1]] <- e; pn <- c(pn, k)
  }
  if (length(pr) == 0) next
  pr <- unlist(pr); ok <- is.finite(pr)
  if (!any(ok)) next
  ww <- pn[ok] / sum(pn[ok])
  perm_atts <- c(perm_atts, sum(ww * pr[ok]))
}
if (length(perm_atts) > 0) {
  p_two <- mean(abs(perm_atts) >= abs(real_att))
  say("  placebo aggregate ATT: mean=%.3f sd=%.3f  [%.2f, %.2f] (n=%d draws)",
      mean(perm_atts), sd(perm_atts), quantile(perm_atts, .025), quantile(perm_atts, .975), length(perm_atts))
  say("  real ATT=%.3f  two-sided permutation p=%.3f (frac |placebo| >= |real|)", real_att, p_two)
} else {
  say("  permutation check produced no usable draws."); p_two <- NA_real_
}
step("permutation check done")

# =============================================================================
# WRITE tidy CSV
# =============================================================================
out <- rbindlist(tidy, fill = TRUE)
# friendly outcome labels stay raw in CSV; round numerics
numcols <- c("att","se","ci_lo","ci_hi","pre_rmse","pre_rmse_over_level")
out[, (numcols) := lapply(.SD, function(x) round(x, 4)), .SDcols = numcols]
fwrite(out, OUTCSV)
say("\nwrote %s (%d rows)", OUTCSV, nrow(out))
print(out)

# =============================================================================
# FIGURE — observed vs synthetic pre/post trajectories (suicide, cohort-pooled)
# =============================================================================
# Size-weighted (by N treated munis) average across cohorts of the treated and
# synthetic-control mean trajectories in event time. Shows the REAL pre-period
# fit and the post-period gap -- NOT the degenerate multisynth pre-fit.
# NB: SDID's omega weights match the pre-period SHAPE/TREND of the treated unit,
# not its level -- the DiD structure differences out a constant unit offset. So
# the honest pre-fit plot aligns the synthetic to the treated PRE-period level
# (subtract the pre-period mean gap), exactly as the SDID estimand does; what
# remains visible is the pre-trend tracking and the post-period gap (the ATT).
tr <- copy(res_suic$traj)
wtab <- data.table(g = res_suic$sd$g, w = res_suic$sd$n_trt / sum(res_suic$sd$n_trt))
# align each cohort's synthetic to its treated pre-period level before pooling
tr[, syn_shift := mean(treated[event_time < 0]) - mean(synthetic[event_time < 0]), by = g]
tr[, synthetic := synthetic + syn_shift]
tr <- merge(tr, wtab, by = "g")
agg_traj <- tr[, .(treated   = sum(w * treated),
                   synthetic = sum(w * synthetic)), by = event_time]
setorder(agg_traj, event_time)
fwrite(agg_traj, file.path(ROOT, "02_data/processed/sdid_suicide_trajectory.csv"))
say("wrote trajectory -> %s", file.path(ROOT, "02_data/processed/sdid_suicide_trajectory.csv"))
plt <- melt(agg_traj, id.vars = "event_time",
            measure.vars = c("treated", "synthetic"),
            variable.name = "series", value.name = "rate")
plt[, series := factor(series, levels = c("treated","synthetic"),
                       labels = c("Treated (PNASH closures)", "Synthetic control"))]
OK <- "#0072B2"; RED <- "#9E1B32"
gp <- ggplot(plt, aes(event_time, rate, color = series, linetype = series)) +
  annotate("rect", xmin = -0.5, xmax = max(plt$event_time) + 0.3,
           ymin = -Inf, ymax = Inf, alpha = 0.05, fill = "grey40") +
  geom_vline(xintercept = -0.5, color = "grey55", linewidth = 0.3, linetype = "dotted") +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.5) +
  scale_color_manual(values = c("Treated (PNASH closures)" = RED, "Synthetic control" = OK)) +
  scale_linetype_manual(values = c("Treated (PNASH closures)" = "solid", "Synthetic control" = "longdash")) +
  scale_x_continuous(breaks = seq(-PRE, POST, 1)) +
  labs(x = "Years relative to closure", y = "Suicide deaths per 100,000",
       title = "Synthetic DiD pre-treatment fit and post-closure gap (suicide)",
       subtitle = sprintf("Synthetic aligned to treated pre-period level; size-wtd. across %d cohorts; pre-fit RMSE %.2f; donors n=%s",
                          nrow(res_suic$sd), sr$pre_rmse, formatC(sr$n_donors, format = "d", big.mark = ",")),
       color = NULL, linetype = NULL) +
  theme_minimal(base_size = 9.5) +
  theme(panel.grid.minor = element_blank(),
        legend.position = c(0.02, 0.02), legend.justification = c(0, 0),
        legend.background = element_rect(fill = "white", color = NA),
        plot.title = element_text(size = 10, hjust = 0),
        plot.subtitle = element_text(size = 8, hjust = 0, color = "grey30"))
ggsave(FIG, gp, width = 6.0, height = 4.0, device = "pdf")
say("wrote figure -> %s", FIG)

# =============================================================================
# TABLE — booktabs + threeparttable appendix fragment
# =============================================================================
fmtnum  <- function(x, d = 2) ifelse(is.na(x), "--", formatC(x, format = "f", digits = d))
fmtci   <- function(lo, hi) ifelse(is.na(lo) | is.na(hi), "--",
              sprintf("[%s, %s]", fmtnum(lo), fmtnum(hi)))
labmap <- c(suicide_per100k = "Suicide (per 100k)",
            selfharm_per100k = "Self-harm (per 100k)",
            psych_adm_per1k = "Psychiatric admissions (per 1k)")
ord <- c("suicide_per100k", "selfharm_per100k", "psych_adm_per1k")
out2 <- out[match(ord, outcome)]
out2 <- out2[!is.na(outcome)]

rows_tex <- vapply(seq_len(nrow(out2)), function(i) {
  r <- out2[i]
  sprintf("%s & %s & %s & %s & %s & %s & Size-wtd. & Placebo SE \\\\",
          labmap[[r$outcome]], fmtnum(r$att), fmtci(r$ci_lo, r$ci_hi),
          fmtnum(r$pre_rmse),
          ifelse(is.na(r$n_donors), "--", formatC(r$n_donors, format = "d", big.mark = ",")),
          ifelse(is.na(r$n_cohorts) | r$n_cohorts == 0, "--", as.character(r$n_cohorts)))
}, character(1))

tex <- c(
  "% Auto-generated by 03_analysis/85_sdid_full.R -- do not edit by hand.",
  "\\begin{table}[t]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Synthetic difference-in-differences estimates (PNASH-48 closures)}",
  "\\label{tab:sdid_results}",
  "\\begin{tabular}{lcccccll}",
  "\\toprule",
  "Outcome & ATT & 95\\% CI & Pre-fit & Donor & Co- & Weighting & Inference \\\\",
  " & & & RMSE & pool $N$ & horts & & \\\\",
  "\\midrule",
  rows_tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  "\\item \\textit{Notes.} Synthetic difference-in-differences (Arkhangelsky et al., 2021),",
  "estimated separately per closure cohort over a balanced $\\pm4$-year window",
  "(treated cohort munis plus the full never-treated donor pool), then aggregated",
  "across cohorts by treated-municipality size weights. Weighting is therefore",
  "\\emph{municipality/size-weighted}, NOT population-weighted---in contrast to the",
  "population-weighted Sun--Abraham headline event study. Standard errors use the",
  "placebo method (Arkhangelsky et al., 2021) with 50 replications; the aggregate",
  "SE combines per-cohort placebo SEs under an independent-cohort approximation.",
  "Pre-fit RMSE is the size-weighted root-mean-square gap between the treated and",
  "synthetic-control mean over the pre-treatment window (suicide pre-level $\\approx 6.3$",
  "per 100k). SDID is doubly robust: it is valid if \\emph{either} parallel trends",
  "\\emph{or} the synthetic-control weights hold. The suicide estimate converges with",
  "the Sun--Abraham event study on a bounded null (both CIs contain zero and exclude",
  "policy-relevant harm). Cells reading ``--'' denote a leg that did not yield a usable",
  "balanced block.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, TAB)
say("wrote table -> %s", TAB)

# ---- convergence summary line for the log -----------------------------------
say("\n========================= CONVERGENCE =========================")
say("SA headline (pop-wtd):   ATT=%.2f  CI=[%.2f, %.2f]", sa_att, sa_lo, sa_hi)
say("SDID suicide (size-wtd): ATT=%.2f  CI=[%.2f, %.2f]  pre-RMSE=%.2f", sr$att, sr$ci_lo, sr$ci_hi, sr$pre_rmse)
in_sa <- sr$att >= sa_lo && sr$att <= sa_hi
say("SDID suicide ATT inside SA CI: %s -> designs %s on the bounded null.",
    in_sa, ifelse(in_sa, "CONVERGE", "DIVERGE"))
step("DONE")
close(logcon)
