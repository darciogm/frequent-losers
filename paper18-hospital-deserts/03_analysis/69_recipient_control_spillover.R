#!/usr/bin/env Rscript
# =====================================================================
# 69_recipient_control_spillover.R
# Spillover bias-bound for the staggered DiD mortality null (referee #1).
#
# THREAT: when a psychiatric hospital h closes, displaced patients are
# redirected to a substitute hospital h'. If h' also serves never-treated
# CONTROL municipalities, those controls get partially treated in the SAME
# direction (congestion, disrupted continuity) -> treated-vs-control
# contrast is attenuated TOWARD the null. Donut/health-region dropping is
# necessary but not sufficient; this sharpens it with REVEALED post-closure
# redirection (admission flows), not geography.
#
# TEST: re-estimate the canonical pop-weighted Sun-Abraham ATT for
# suicide_per100k and selfharm_per100k after DROPPING never-treated control
# munis that are revealed RECIPIENTS of redirected volume. If the estimate
# is stable, spillover is not masking a positive effect. If it moves UP,
# that is a finding.
#
# Recipient flags come from 69_recipient_control_spillover.py (DuckDB flow
# construction). This script applies the share-rise threshold, drops
# recipient controls, re-fits, and runs a threshold sensitivity.
#
# Cache-aware (--force). Telemetry per monorepo convention. 4 threads.
# =====================================================================

suppressMessages({
  library(arrow); library(data.table); library(fixest)
})
setDTthreads(4); setFixest_nthreads(4)

ROOT  <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
PANEL <- file.path(ROOT, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")
FLOW  <- file.path(ROOT, "02_data/intermediate/recipient_control_flow.parquet")
OUT   <- file.path(ROOT, "02_data/processed/recipient_control_spillover.csv")
LOG   <- file.path(ROOT, "04_logs/69_recipient_control_spillover.log")

args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args

PRIMARY_THRESH <- 0.01            # >1pp share rise = revealed recipient (primary)
SENS_THRESH    <- c(0.0, 0.02, 0.05)  # sensitivity to the share-rise cutoff

# --- telemetry --------------------------------------------------------
logf <- function(...) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), sprintf(...))
  cat(msg, "\n"); cat(msg, "\n", file = LOG, append = TRUE)
}
mem_rss <- function() {
  tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()),
           intern = TRUE)) / 1024, 1), error = function(e) NA)
}

if (file.exists(OUT) && !FORCE) {
  logf("cache hit %s; skip (use --force)", OUT); quit(save = "no")
}
cat("", file = LOG, append = TRUE)
logf("=== START host=%s nproc=%s RAM=%s ===",
     Sys.info()[["nodename"]], system("nproc", intern = TRUE),
     gsub("\\n.*", "", system("free -h | awk 'NR==2{print $2}'", intern = TRUE)))
logf("primary thresh=%.2f, sensitivity=%s", PRIMARY_THRESH,
     paste(SENS_THRESH, collapse = ","))

# --- data -------------------------------------------------------------
d <- as.data.table(read_parquet(PANEL))
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, g_emb)]
flow <- as.data.table(read_parquet(FLOW))   # codmun_6, n_closures_recip, max_delta_share
logf("panel rows=%d munis=%d | flow recipient candidates=%d | RSS=%sMB",
     nrow(d), uniqueN(d$codmun_6), nrow(flow), mem_rss())

ctrl_munis <- unique(d[gn == 10000L, codmun_6])
treat_munis <- unique(d[gn != 10000L, codmun_6])
logf("treated munis=%d | never-treated controls=%d", length(treat_munis), length(ctrl_munis))

# --- estimator --------------------------------------------------------
fit_att <- function(dat, y) {
  f <- as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y))
  m <- feols(f, dat, cluster = "muni_id", weights = ~pop)
  s <- summary(m, agg = "att")$coeftable
  est <- s[1, 1]; se <- s[1, 2]
  list(att = est, se = se, lo = est - 1.96 * se, hi = est + 1.96 * se,
       p = s[1, 4], nobs = m$nobs)
}

# drop recipient controls at a given threshold; keep ALL treated + clean controls
drop_recipients <- function(dat, thresh) {
  recip <- flow[max_delta_share > thresh, codmun_6]
  recip_ctrl <- intersect(recip, ctrl_munis)   # only controls can be dropped
  list(data = dat[!(gn == 10000L & codmun_6 %in% recip_ctrl)],
       n_recip_ctrl = length(recip_ctrl),
       n_clean_ctrl = length(ctrl_munis) - length(recip_ctrl))
}

# --- baseline (all controls) -----------------------------------------
res <- list()
for (y in c("suicide_per100k", "selfharm_per100k")) {
  b <- fit_att(d, y)
  res[[length(res) + 1]] <- data.table(
    outcome = y, spec = "baseline_all_controls", thresh = NA_real_,
    n_recip_ctrl_dropped = 0L, n_clean_ctrl = length(ctrl_munis),
    att = b$att, se = b$se, ci_lo = b$lo, ci_hi = b$hi, pval = b$p, nobs = b$nobs)
  logf("BASELINE %-16s ATT=%.2f SE=%.2f CI[%.2f,%.2f] N=%d",
       y, b$att, b$se, b$lo, b$hi, b$nobs)
}

# --- primary: drop revealed-recipient controls -----------------------
dp <- drop_recipients(d, PRIMARY_THRESH)
logf("PRIMARY thresh=%.2f: dropped %d recipient controls; %d clean controls remain",
     PRIMARY_THRESH, dp$n_recip_ctrl, dp$n_clean_ctrl)
for (y in c("suicide_per100k", "selfharm_per100k")) {
  b <- fit_att(dp$data, y)
  res[[length(res) + 1]] <- data.table(
    outcome = y, spec = "drop_recipient_controls", thresh = PRIMARY_THRESH,
    n_recip_ctrl_dropped = dp$n_recip_ctrl, n_clean_ctrl = dp$n_clean_ctrl,
    att = b$att, se = b$se, ci_lo = b$lo, ci_hi = b$hi, pval = b$p, nobs = b$nobs)
  logf("DROP-RECIP %-16s ATT=%.2f SE=%.2f CI[%.2f,%.2f] N=%d",
       y, b$att, b$se, b$lo, b$hi, b$nobs)
}

# --- sensitivity to the share-rise threshold -------------------------
for (th in SENS_THRESH) {
  ds <- drop_recipients(d, th)
  for (y in c("suicide_per100k", "selfharm_per100k")) {
    b <- fit_att(ds$data, y)
    res[[length(res) + 1]] <- data.table(
      outcome = y, spec = "sensitivity_thresh", thresh = th,
      n_recip_ctrl_dropped = ds$n_recip_ctrl, n_clean_ctrl = ds$n_clean_ctrl,
      att = b$att, se = b$se, ci_lo = b$lo, ci_hi = b$hi, pval = b$p, nobs = b$nobs)
  }
  logf("SENS thresh=%.2f dropped=%d clean=%d | suicide ATT=%.2f selfharm ATT=%.2f",
       th, ds$n_recip_ctrl, ds$n_clean_ctrl,
       res[[length(res) - 1]]$att, res[[length(res)]]$att)
}

# --- write ------------------------------------------------------------
out <- rbindlist(res)
num <- c("att", "se", "ci_lo", "ci_hi", "pval", "thresh")
out[, (num) := lapply(.SD, function(x) round(x, 2)), .SDcols = num]
fwrite(out, OUT)
logf("wrote %s (%d rows) | RSS=%sMB | DONE", OUT, nrow(out), mem_rss())
print(out)
