#!/usr/bin/env Rscript
# 70_lococor_displacement.R
#
# Referee #5 mechanical-displacement check, estimation step.
#
# THREAT: a closing psychiatric hospital is where some inpatients die. When it
# shuts, in-facility deaths among its catchment mechanically disappear from
# recorded mortality -- a negative shock at treatment onset that could offset a
# true positive behavioral effect and manufacture a spurious null. Outcomes are
# coded at municipality of RESIDENCE, which mutes but may not kill this.
#
# TEST: re-run the canonical pop-weighted Sun-Abraham event study on
# OUT-OF-HOSPITAL suicide/self-harm deaths only (place of occurrence LOCOCOR!=1,
# built in 65a). If the null holds out-of-hospital, those deaths cannot be the
# ones the closing hospital was absorbing -> mechanical displacement ruled out.
#
# VALIDATION GATE: rebuild the TOTAL (in+out) suicide rate from LOCOCOR counts,
# run the canonical spec, must reproduce ATT ~ +0.28, CI ~ [-0.72,+1.29]. If not,
# construction is off -> stop.
#
# Canonical spec (identical to D6_make_values.R est()):
#   gn = ifelse(is.na(g_emb)|g_emb==0, 10000L, g_emb)
#   feols(<y> ~ sunab(gn, year) | muni_id + year, d, cluster="muni_id", weights=~pop)
#   summary(., agg="att")
#
# Output: 02_data/processed/lococor_displacement.csv + 04_logs/65_*.log
# Parallel job running -> 4 threads.

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})
setDTthreads(4); setFixest_nthreads(4)

args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
LOGD  <- file.path(ROOT, "04_logs")
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(LOGD, showWarnings = FALSE, recursive = TRUE)
OUT   <- file.path(PROC, "lococor_displacement.csv")
LOGF  <- file.path(LOGD, "70_lococor_displacement.log")

PANEL  <- file.path(INTER, "staggered_panel_pnash48_ext.parquet")
COUNTS <- file.path(INTER, "lococor_counts.parquet")

con <- file(LOGF, open = "wt")
say <- function(...) {
  msg <- sprintf("%s %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), sprintf(...))
  cat(msg, "\n"); writeLines(msg, con)
}
mem <- function() tryCatch(sprintf("%.2fGB", as.numeric(lobstr::mem_used()) / 1e9),
                           error = function(e) "NA")

say("host=%s threads=4 (setDT/setFixest) | force=%s",
    Sys.info()[["nodename"]], FORCE)

if (file.exists(OUT) && !FORCE) {
  say("output exists, skipping (use --force): %s", OUT)
  close(con); quit(save = "no")
}

# ----------------------------------------------------------------------------
# Load panel (canonical keys/weights) and LOCOCOR counts; merge on codmun_6,year
# ----------------------------------------------------------------------------
t0 <- Sys.time()
P  <- as.data.table(read_parquet(PANEL))
say("panel loaded: %d rows, %d munis, years %d-%d | mem=%s",
    nrow(P), uniqueN(P$codmun_6), min(P$year), max(P$year), mem())

C  <- as.data.table(read_parquet(COUNTS))
# panel keys are character codmun_6; ensure match
C[, codmun_6 := sprintf("%06d", as.integer(codmun_6))]
P[, codmun_6 := sprintf("%06d", as.integer(codmun_6))]

d <- merge(P, C, by = c("codmun_6", "year"), all.x = TRUE)
# muni-years with no suicide/self-harm death rows in LOCOCOR table => true zeros
for (cc in c("n_suicide_in","n_suicide_out","n_selfharm_in","n_selfharm_out"))
  d[is.na(get(cc)), (cc) := 0L]

# rebuilt rates per 100k using the PANEL's pop (canonical denominator)
# NULL where pop missing (pre-2015 etc.), exactly as canonical rates behave
d[, n_suicide_tot  := n_suicide_in  + n_suicide_out]
d[, n_selfharm_tot := n_selfharm_in + n_selfharm_out]
d[, suicide_tot_per100k     := fifelse(pop > 0, 1e5 * n_suicide_tot  / pop, NA_real_)]
d[, suicide_outhosp_per100k := fifelse(pop > 0, 1e5 * n_suicide_out  / pop, NA_real_)]
d[, suicide_inhosp_per100k  := fifelse(pop > 0, 1e5 * n_suicide_in   / pop, NA_real_)]
d[, selfharm_outhosp_per100k:= fifelse(pop > 0, 1e5 * n_selfharm_out / pop, NA_real_)]
d[, selfharm_inhosp_per100k := fifelse(pop > 0, 1e5 * n_selfharm_in  / pop, NA_real_)]

# ----------------------------------------------------------------------------
# Canonical estimator (copied to match D6_make_values.R::est, wt=TRUE branch)
# ----------------------------------------------------------------------------
est <- function(dd, yn) {
  x <- dd[is.finite(get(yn)) & is.finite(pop)]
  x[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  w <- x$pop
  m <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
             x, cluster = "muni_id", weights = w)
  a <- summary(m, agg = "att")
  att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  base <- weighted.mean(x[gn < 10000 & year < 2015][[yn]],
                        x[gn < 10000 & year < 2015]$pop, na.rm = TRUE)
  # pre-trend joint test on event-time leads -6..-2 (matches D6)
  cf <- coef(m); s <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]),
                                         cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]
  pre <- es[e <= -2 & e >= -6]
  W <- sum((pre$cf / pre$se)^2); ppre <- 1 - pchisq(W, nrow(pre))
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       base = base, ppre = ppre, n = nrow(x),
       ntr = x[gn < 10000, uniqueN(muni_id)])
}

fmt <- function(x) sprintf("%+.2f", x)
row <- function(lbl, r) data.table(
  outcome = lbl, att = round(r$att, 2), se = round(r$se, 2),
  ci_lo = round(r$lo, 2), ci_hi = round(r$hi, 2),
  pretrend_p = round(r$ppre, 2), baseline = round(r$base, 2),
  n_obs = r$n, n_treated_munis = r$ntr)

# ----------------------------------------------------------------------------
# VALIDATION GATE: rebuilt TOTAL suicide vs canonical panel suicide_per100k
# ----------------------------------------------------------------------------
say("=== VALIDATION ===")
r_tot  <- est(d, "suicide_tot_per100k")
r_canon <- est(d, "suicide_per100k")  # the panel's own column, for reference
say("rebuilt TOTAL suicide   ATT=%s SE=%.2f CI=[%s,%s] ppre=%.2f",
    fmt(r_tot$att), r_tot$se, fmt(r_tot$lo), fmt(r_tot$hi), r_tot$ppre)
say("panel column suicide    ATT=%s SE=%.2f CI=[%s,%s] (reference)",
    fmt(r_canon$att), r_canon$se, fmt(r_canon$lo), fmt(r_canon$hi))

TARGET_ATT <- 0.28
if (abs(r_tot$att - TARGET_ATT) > 0.05) {
  say("FAIL: rebuilt total ATT %s deviates from canonical +0.28 by >0.05. Construction off. STOPPING.",
      fmt(r_tot$att))
  close(con); quit(save = "no", status = 1)
}
say("PASS: rebuilt total suicide ATT %s matches canonical +0.28 (|diff|<=0.05)", fmt(r_tot$att))

# ----------------------------------------------------------------------------
# MAIN: out-of-hospital event studies (+ in-hospital for context)
# ----------------------------------------------------------------------------
say("=== OUT-OF-HOSPITAL EVENT STUDIES ===")
r_suic_out <- est(d, "suicide_outhosp_per100k")
r_self_out <- est(d, "selfharm_outhosp_per100k")
r_suic_in  <- est(d, "suicide_inhosp_per100k")
r_self_in  <- est(d, "selfharm_inhosp_per100k")

say("suicide  OUT-of-hosp ATT=%s SE=%.2f CI=[%s,%s] ppre=%.2f base=%.2f",
    fmt(r_suic_out$att), r_suic_out$se, fmt(r_suic_out$lo), fmt(r_suic_out$hi),
    r_suic_out$ppre, r_suic_out$base)
say("selfharm OUT-of-hosp ATT=%s SE=%.2f CI=[%s,%s] ppre=%.2f base=%.2f",
    fmt(r_self_out$att), r_self_out$se, fmt(r_self_out$lo), fmt(r_self_out$hi),
    r_self_out$ppre, r_self_out$base)
say("suicide  IN-hosp     ATT=%s SE=%.2f CI=[%s,%s] base=%.2f (context)",
    fmt(r_suic_in$att), r_suic_in$se, fmt(r_suic_in$lo), fmt(r_suic_in$hi), r_suic_in$base)
say("selfharm IN-hosp     ATT=%s SE=%.2f CI=[%s,%s] base=%.2f (context)",
    fmt(r_self_in$att), r_self_in$se, fmt(r_self_in$lo), fmt(r_self_in$hi), r_self_in$base)

# ----------------------------------------------------------------------------
# Baseline in-hospital SHARE among treated catchments, pre-period (mechanically
# displaceable component). Pop-weighted, treated munis, year<2015.
# ----------------------------------------------------------------------------
db <- d[!is.na(g_emb) & g_emb != 0 & year < g_emb & pop > 0]
suic_in  <- sum(db$n_suicide_in);  suic_tot  <- sum(db$n_suicide_tot)
self_in  <- sum(db$n_selfharm_in); self_tot  <- sum(db$n_selfharm_tot)
share_suic <- 100 * suic_in / suic_tot
share_self <- 100 * self_in / self_tot
say("baseline (treated, pre-closure) in-hospital share: suicide=%.2f%% (%d/%d)  selfharm=%.2f%% (%d/%d)",
    share_suic, suic_in, suic_tot, share_self, self_in, self_tot)

# ----------------------------------------------------------------------------
# Write CSV
# ----------------------------------------------------------------------------
res <- rbindlist(list(
  row("suicide_total_rebuilt",   r_tot),
  row("suicide_panel_reference", r_canon),
  row("suicide_outhosp",         r_suic_out),
  row("suicide_inhosp",          r_suic_in),
  row("selfharm_outhosp",        r_self_out),
  row("selfharm_inhosp",         r_self_in)
))
res[, baseline_inhosp_share_pct := NA_real_]
res[outcome %in% c("suicide_outhosp","suicide_inhosp"),  baseline_inhosp_share_pct := round(share_suic, 2)]
res[outcome %in% c("selfharm_outhosp","selfharm_inhosp"), baseline_inhosp_share_pct := round(share_self, 2)]
res[, validation_pass := abs(r_tot$att - TARGET_ATT) <= 0.05]
fwrite(res, OUT)
say("wrote %s (%d rows)", OUT, nrow(res))

# verdict
suic_null_survives <- (r_suic_out$lo < 0 & r_suic_out$hi > 0)
say("=== VERDICT ===")
say("out-of-hospital suicide ATT=%s, CI=[%s,%s] -> null %s",
    fmt(r_suic_out$att), fmt(r_suic_out$lo), fmt(r_suic_out$hi),
    if (suic_null_survives) "SURVIVES (displacement ruled out)" else "DOES NOT survive (concern)")
say("DONE elapsed=%.1fs mem=%s", as.numeric(difftime(Sys.time(), t0, units = "secs")), mem())
close(con)
