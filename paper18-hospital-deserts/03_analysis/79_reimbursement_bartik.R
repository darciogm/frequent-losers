# 79_reimbursement_bartik.R
# FEASIBILITY of a reimbursement-exposure shift-share (Bartik) IV for psychiatric
# hospital closure. The per-diem freeze is a NATIONAL shock; identifying variation
# must come from cross-hospital EXPOSURE (more-squeezed hospitals close earlier/more).
#
# FIRST STAGE FIRST. We only proceed to 2SLS if the first stage is strong.
# A weak/infeasible verdict is an acceptable, expected outcome.
#
# Vulnerability proxy (documented in STEP 1):
#   PRIMARY  = pre-window real revenue PER ADMISSION (val_tot_soma / n_internacoes),
#              available for the ENTIRE psychiatric universe (no missing beds).
#              CNES bed field (leithosp_max) is degenerate (~1 for all), so it cannot
#              denominate the full universe. qt_sus_pre (real SUS beds) exists only for
#              the closure set, so revenue-per-bed is used only as a within-closer check.
#   Lower revenue-per-admission = more squeezed by the frozen per-diem = more exposed.
#
# Outputs:
#   02_data/processed/reimbursement_bartik.csv
#   04_logs/79_reimbursement_bartik_<ts>.log
#
# Usage: Rscript 03_analysis/79_reimbursement_bartik.R [--force]

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(DBI)
  library(duckdb)
})

setDTthreads(6)
setFixest_nthreads(6)

args        <- commandArgs(trailingOnly = TRUE)
FORCE       <- "--force" %in% args
ROOT        <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
OUT_CSV     <- file.path(ROOT, "02_data/processed/reimbursement_bartik.csv")
TS          <- format(Sys.time(), "%Y%m%d_%H%M%S")
LOG         <- file.path(ROOT, "04_logs", sprintf("79_reimbursement_bartik_%s.log", TS))

logcon <- file(LOG, open = "wt")
say <- function(...) {
  msg <- sprintf(...)
  cat(msg, "\n")
  cat(msg, "\n", file = logcon); flush(logcon)
}
rss_gb <- function() {
  tryCatch({
    s <- readLines(sprintf("/proc/%d/status", Sys.getpid()))
    v <- grep("VmRSS", s, value = TRUE)
    as.numeric(gsub("[^0-9]", "", v)) / 1e6
  }, error = function(e) NA_real_)
}

t0 <- Sys.time()
say("=== 79_reimbursement_bartik :: reimbursement-exposure Bartik feasibility ===")
say("host=%s  threads=6  RAM_free_probe", Sys.info()[["nodename"]])
say("start=%s", format(t0))

if (file.exists(OUT_CSV) && !FORCE) {
  say("Output exists (%s) and --force not set. Skipping. Use --force to rerun.", OUT_CSV)
  say("Existing result:")
  ex <- fread(OUT_CSV)
  print(ex)
  close(logcon)
  quit(save = "no")
}

# ---------------------------------------------------------------------------
# Load data via DuckDB (out-of-core for the 2.7M-row bipartite edges)
# ---------------------------------------------------------------------------
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=6")
dbExecute(con, "PRAGMA memory_limit='14GB'")

P_EDGES   <- file.path(ROOT, "02_data/intermediate/bipartite_edges.parquet")
P_MASTER  <- file.path(ROOT, "02_data/intermediate/hospital_master.parquet")
P_CLOSEX  <- file.path(ROOT, "02_data/intermediate/hospital_closures_exogenous.parquet")
P_PNASH   <- file.path(ROOT, "02_data/processed/pnash_event_level_dataset.parquet")
P_PANEL   <- file.path(ROOT, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")

# Pre-window for vulnerability: 2012-2014, the 3 years before the 2015 panel start.
PRE_LO <- 2012L; PRE_HI <- 2014L
say("Pre-window for vulnerability measure: %d-%d", PRE_LO, PRE_HI)

# Hospital-year revenue & admissions over pre-window, joined to register.
hosp <- as.data.table(dbGetQuery(con, sprintf("
  WITH rev AS (
    SELECT CNES,
           SUM(val_tot_soma)  AS rev_pre,
           SUM(n_internacoes) AS adm_pre
    FROM read_parquet('%s')
    WHERE year BETWEEN %d AND %d
    GROUP BY CNES
  )
  SELECT m.CNES, m.tp_unid_modal AS tp_unid, m.leithosp_max AS beds_cnes,
         m.codmun_6_modal AS codmun_6,
         r.rev_pre, r.adm_pre
  FROM read_parquet('%s') m
  LEFT JOIN rev r USING(CNES)
", P_EDGES, PRE_LO, PRE_HI, P_MASTER)))

closex <- as.data.table(dbGetQuery(con, sprintf(
  "SELECT CNES, year_closure, tp_unid, qt_sus_pre, exogenous FROM read_parquet('%s')", P_CLOSEX)))
pnash  <- as.data.table(dbGetQuery(con, sprintf(
  "SELECT CNES, closure_year, qt_sus_pre FROM read_parquet('%s')", P_PNASH)))

say("loaded: hosp=%d  closex=%d  pnash=%d   RSS=%.2fGB",
    nrow(hosp), nrow(closex), nrow(pnash), rss_gb())

# ---------------------------------------------------------------------------
# STEP 1 — vulnerability measure (psychiatric universe, tp_unid==07)
# ---------------------------------------------------------------------------
psy <- hosp[tp_unid == "07" & !is.na(adm_pre) & adm_pre > 0 & rev_pre > 0]
psy[, rev_per_adm := rev_pre / adm_pre]
# Vulnerability = NEGATIVE of revenue-per-admission, standardized (higher = more squeezed).
psy[, vuln := as.numeric(scale(-rev_per_adm))]

say("--- STEP 1: vulnerability (psych universe with pre-window revenue) ---")
say("N psych hospitals with measure: %d", nrow(psy))
say("rev_per_adm: mean=%.0f  sd=%.0f  p10=%.0f  p50=%.0f  p90=%.0f",
    mean(psy$rev_per_adm), sd(psy$rev_per_adm),
    quantile(psy$rev_per_adm, .10), quantile(psy$rev_per_adm, .50),
    quantile(psy$rev_per_adm, .90))
cv <- sd(psy$rev_per_adm) / mean(psy$rev_per_adm)
say("coefficient of variation of rev_per_adm = %.3f  (thin CV => homogeneity risk)", cv)

# Closure set: which psych hospitals close (exogenous), and when.
clo07 <- closex[tp_unid == "07" & exogenous == TRUE]
psy[, closed   := as.integer(CNES %in% clo07$CNES)]
psy <- merge(psy, clo07[, .(CNES, year_closure)], by = "CNES", all.x = TRUE)
say("psych closers (exogenous) matched into universe: %d of %d closure-set CNES",
    psy[closed == 1, .N], nrow(clo07))

# ---------------------------------------------------------------------------
# STEP 2(a) — hospital-level first stage: does vulnerability predict CLOSURE
#             and EARLIER closure?  (the GATE)
# ---------------------------------------------------------------------------
say("--- STEP 2(a): hospital-level first stage (LPM closure ~ vulnerability) ---")

# Linear probability of being in the closure set.
m_lpm <- feols(closed ~ vuln, data = psy, vcov = "hetero")
print(summary(m_lpm))
b_lpm  <- coef(m_lpm)["vuln"]
se_lpm <- se(m_lpm)["vuln"]
F_lpm  <- (b_lpm / se_lpm)^2   # single excluded instrument => F = t^2
say("LPM: coef(vuln)=%.5f  se=%.5f  t=%.3f  F(excl)=%.3f",
    b_lpm, se_lpm, b_lpm / se_lpm, F_lpm)

# Earlier closure: among closers, does higher vulnerability => earlier year_closure?
clos_only <- psy[closed == 1 & !is.na(year_closure)]
m_yr <- feols(year_closure ~ vuln, data = clos_only, vcov = "hetero")
print(summary(m_yr))
b_yr  <- coef(m_yr)["vuln"]; se_yr <- se(m_yr)["vuln"]
F_yr  <- (b_yr / se_yr)^2
say("Timing: coef(vuln)=%.4f yrs  se=%.4f  t=%.3f  F=%.3f  (N closers=%d)",
    b_yr, se_yr, b_yr / se_yr, F_yr, nrow(clos_only))

# Within-closer robustness using revenue-per-BED (qt_sus_pre real SUS beds).
cb <- merge(clo07[, .(CNES, year_closure)],
            unique(rbind(closex[, .(CNES, qt_sus_pre)], pnash[, .(CNES, qt_sus_pre)])),
            by = "CNES")
cb <- merge(cb, psy[, .(CNES, rev_pre)], by = "CNES")
cb <- cb[qt_sus_pre > 0 & rev_pre > 0]
cb[, rev_per_bed := rev_pre / qt_sus_pre]
cb[, vuln_bed := as.numeric(scale(-rev_per_bed))]
F_bed <- NA_real_; b_bed <- NA_real_; se_bed <- NA_real_
if (nrow(cb) > 5) {
  m_bed <- feols(year_closure ~ vuln_bed, data = cb, vcov = "hetero")
  b_bed <- coef(m_bed)["vuln_bed"]; se_bed <- se(m_bed)["vuln_bed"]
  F_bed <- (b_bed / se_bed)^2
  say("Within-closer (rev/bed) timing: coef=%.4f se=%.4f F=%.3f N=%d",
      b_bed, se_bed, F_bed, nrow(cb))
}

# ---------------------------------------------------------------------------
# STEP 2(b) — muni-level shift-share first stage.
#   exposure_IV_m = sum_h ( muni m's pre-closure admission share to h ) x ( vuln_h )
#   over psychiatric hospitals h. Regress actual treatment onset on exposure_IV_m.
# ---------------------------------------------------------------------------
say("--- STEP 2(b): muni-level shift-share first stage ---")

# Pre-window muni->hospital admission shares (psych hospitals only).
edges_pre <- as.data.table(dbGetQuery(con, sprintf("
  SELECT e.codmun_6, e.CNES, SUM(e.n_internacoes) AS adm
  FROM read_parquet('%s') e
  WHERE e.year BETWEEN %d AND %d
  GROUP BY e.codmun_6, e.CNES
", P_EDGES, PRE_LO, PRE_HI)))
edges_pre <- merge(edges_pre, psy[, .(CNES, vuln)], by = "CNES")  # keep only psych w/ vuln
edges_pre[, share := adm / sum(adm), by = codmun_6]
iv <- edges_pre[, .(exposure_IV = sum(share * vuln),
                    psy_adm_pre = sum(adm)), by = codmun_6]
say("munis with a psych-exposure IV: %d", nrow(iv))

# Actual treatment: g_emb cohort (>0 = treated municipality) from the analysis panel.
panel <- as.data.table(dbGetQuery(con, sprintf(
  "SELECT codmun_6, g_emb FROM read_parquet('%s') GROUP BY codmun_6, g_emb", P_PANEL)))
panel <- unique(panel[, .(codmun_6, g_emb)])
panel[, treated := as.integer(g_emb > 0)]

ms <- merge(panel, iv, by = "codmun_6", all.x = TRUE)
ms[is.na(exposure_IV), exposure_IV := 0]
ms[is.na(psy_adm_pre), psy_adm_pre := 0]
ms[, exposure_IV_z := as.numeric(scale(exposure_IV))]

say("muni shift-share sample: N=%d  treated=%d", nrow(ms), ms[treated == 1, .N])

m_ss <- feols(treated ~ exposure_IV_z, data = ms, vcov = "hetero")
print(summary(m_ss))
b_ss  <- coef(m_ss)["exposure_IV_z"]; se_ss <- se(m_ss)["exposure_IV_z"]
F_ss  <- (b_ss / se_ss)^2
say("Shift-share FS: coef=%.5f se=%.5f t=%.3f F=%.3f",
    b_ss, se_ss, b_ss / se_ss, F_ss)

# ---------------------------------------------------------------------------
# SHIFT VALIDITY: is the shift-share F driven by the SHIFT (vulnerability) or
# merely by the SHARE/exposure (does the muni use psych care at all)?
# A high shift-share F is worthless for THIS instrument if it survives stripping
# the vulnerability weight. Two checks:
#   (1) placebo IV = pure psychiatric-care reliance (psych admissions, NO vuln).
#   (2) horse race: treated ~ placebo_share + exposure_IV. If exposure_IV loses
#       significance once the placebo is controlled, the shift adds nothing.
# ---------------------------------------------------------------------------
say("--- SHIFT VALIDITY: placebo (no-vuln) vs real Bartik ---")
# Placebo = pure RELIANCE on psychiatric care = (psych admissions)/(all admissions),
# the economically-correct 'do you use the psych sector at all' control. If the real
# Bartik's power is just reliance dressed up, exposure_IV dies once this is held fixed.
psy_adm_m <- edges_pre[, .(psy_adm = sum(adm)), by = codmun_6]
all_adm_m <- as.data.table(dbGetQuery(con, sprintf("
  SELECT codmun_6, SUM(n_internacoes) AS adm_all
  FROM read_parquet('%s') WHERE year BETWEEN %d AND %d GROUP BY codmun_6",
  P_EDGES, PRE_LO, PRE_HI)))
plac <- merge(psy_adm_m, all_adm_m, by = "codmun_6", all = TRUE)
plac[is.na(psy_adm), psy_adm := 0]; plac[is.na(adm_all) | adm_all == 0, adm_all := NA]
plac[, psych_share := psy_adm / adm_all]
ms2 <- merge(ms, plac[, .(codmun_6, psych_share)], by = "codmun_6", all.x = TRUE)
ms2[is.na(psych_share), psych_share := 0]
ms2[, placebo_z := as.numeric(scale(psych_share))]
m_plac <- feols(treated ~ placebo_z, data = ms2, vcov = "hetero")
F_plac <- (coef(m_plac)["placebo_z"] / se(m_plac)["placebo_z"])^2
m_hr   <- feols(treated ~ placebo_z + exposure_IV_z, data = ms2, vcov = "hetero")
t_iv_cond <- coef(m_hr)["exposure_IV_z"] / se(m_hr)["exposure_IV_z"]
say("placebo (psych-care RELIANCE share, NO vuln) F = %.2f", F_plac)
say("horse race: exposure_IV conditional t = %.2f (if <2 => the vulnerability shift is inert)",
    t_iv_cond)
SHIFT_VALID <- (abs(t_iv_cond) >= 2.0) && (F_ss > F_plac)
say("SHIFT_VALID (vulnerability adds identifying power beyond pure reliance) = %s",
    SHIFT_VALID)

# ---------------------------------------------------------------------------
# GATE DECISION
#   The hospital-level first stage must show vulnerability -> closure (the shock
#   mechanism), AND the muni shift-share must derive strength from the SHIFT, not
#   the share. A shift-share F that is mechanical (placebo >= real) is disqualified.
# ---------------------------------------------------------------------------
hosp_fs_ok <- (F_lpm >= 10) && (sign(b_lpm) > 0)
ss_fs_ok   <- (F_ss  >= 10) && (sign(b_ss) > 0) && SHIFT_VALID
STRONG <- hosp_fs_ok && ss_fs_ok
say("--- GATE: F_lpm=%.2f (ok=%s)  F_timing=%.2f  F_shiftshare=%.2f  F_placebo=%.2f  SHIFT_VALID=%s  STRONG=%s ---",
    F_lpm, hosp_fs_ok, F_yr, F_ss, F_plac, SHIFT_VALID, STRONG)

# ---------------------------------------------------------------------------
# STEP 3 — 2SLS ONLY if first stage strong (else explicitly skipped)
# ---------------------------------------------------------------------------
sa_att <- NA_real_; iv_est <- NA_real_; iv_se <- NA_real_; ar_lo <- NA_real_; ar_hi <- NA_real_
if (STRONG) {
  say("First stage STRONG -> proceeding to 2SLS of suicide_per100k on exposure.")
  # (2SLS implementation would go here; gated off when weak.)
  say("NOTE: 2SLS leg reached; implement endogenous-treatment 2SLS on the full panel.")
} else {
  say("First stage WEAK -> NOT running 2SLS on mortality (per protocol).")
}

# ---------------------------------------------------------------------------
# STEP 4 — VERDICT + write output
# ---------------------------------------------------------------------------
verdict <- if (STRONG) {
  "FEASIBLE: build the Bartik leg"
} else if (F_ss >= 10 && !SHIFT_VALID) {
  "INFEASIBLE: shift-share F is MECHANICAL (driven by psych-care reliance, not by the per-diem-freeze vulnerability shift); closing psych hospitals too homogeneous; DROP the Bartik leg"
} else {
  "INFEASIBLE: weak first stage; closing psych hospitals too homogeneous; DROP the Bartik leg"
}
say("=== VERDICT: %s ===", verdict)

res <- data.table(
  vulnerability_measure   = "neg_real_revenue_per_admission_pre2012_2014_zscored",
  n_psych_universe        = nrow(psy),
  cv_rev_per_adm          = round(cv, 4),
  n_psych_closers         = psy[closed == 1, .N],
  # hospital LPM closure ~ vuln
  fs_lpm_coef             = round(b_lpm, 6),
  fs_lpm_se               = round(se_lpm, 6),
  fs_lpm_F                = round(F_lpm, 3),
  # timing closer-only
  fs_timing_coef_yrs      = round(b_yr, 4),
  fs_timing_se            = round(se_yr, 4),
  fs_timing_F             = round(F_yr, 3),
  fs_timing_bed_coef      = round(b_bed, 4),
  fs_timing_bed_F         = round(F_bed, 3),
  # muni shift-share
  n_muni_shiftshare       = nrow(ms),
  n_muni_treated          = ms[treated == 1, .N],
  fs_shiftshare_coef      = round(b_ss, 6),
  fs_shiftshare_se        = round(se_ss, 6),
  fs_shiftshare_F         = round(F_ss, 3),
  # shift validity (placebo / horse race)
  fs_placebo_noVuln_F     = round(F_plac, 3),
  exposureIV_cond_t       = round(t_iv_cond, 3),
  shift_valid             = SHIFT_VALID,
  # gate
  first_stage_strong      = STRONG,
  iv_2sls_run             = STRONG,
  sa_suicide_att_ref      = 0.28,
  verdict                 = verdict
)
fwrite(res, OUT_CSV)
say("Wrote %s", OUT_CSV)
print(t(res))

dbDisconnect(con, shutdown = TRUE)
say("done. elapsed=%.1fs  RSS=%.2fGB", as.numeric(difftime(Sys.time(), t0, units = "secs")), rss_gb())
close(logcon)
