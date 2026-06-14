#!/usr/bin/env Rscript
# D6_make_values.R
#
# Single source of truth for every computed number in the manuscript.
# Recomputes data-inventory figures (DuckDB) and all estimation results
# (fixest on the pop-backfilled *_ext panels), and writes
# 01_manuscript/values.tex as \newcommand macros, each with a % src: comment.
# Run after D1-D5. The manuscript \input{values.tex} and uses \val* macros;
# no number is hand-typed in the prose.

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(duckdb); library(DBI)
})

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
OUT   <- file.path(ROOT, "01_manuscript", "values.tex")

LINES <- character(0)
v <- function(name, value, src) LINES[[length(LINES) + 1L]] <<-
  sprintf("\\newcommand{\\%s}{%s}%% src: %s", name, value, src)
sgn  <- function(x, d = 2) sprintf("%+.*f", d, x)          # signed, d decimals
num  <- function(x, d = 2) sprintf("%.*f", d, x)           # unsigned
comma <- function(x) gsub(",", "{,}", formatC(x, format = "d", big.mark = ","))  # math-safe thousands sep

# ============================ DATA INVENTORY (DuckDB) ============================
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=10")
q <- function(s) dbGetQuery(con, s)
EDG <- sprintf("read_parquet('%s')", file.path(INTER, "bipartite_edges.parquet"))
MAS <- sprintf("read_parquet('%s')", file.path(INTER, "hospital_master.parquet"))
EXP <- sprintf("read_parquet('%s')", file.path(INTER, "exposure_panel.parquet"))
CLO <- sprintf("read_parquet('%s')", file.path(INTER, "hospital_closures_exogenous.parquet"))

adm <- q(sprintf("SELECT SUM(n_internacoes) t, COUNT(DISTINCT codmun_6) m, COUNT(DISTINCT CNES) h FROM %s", EDG))
v("valNadmissions", sprintf("%.1f", adm$t / 1e6), "D6: SUM(n_internacoes) bipartite_edges, millions")
v("valNmunisGraph", comma(adm$m), "D6: distinct residence munis in bipartite_edges")
v("valNhospGraph",  comma(adm$h), "D6: distinct hospitals in bipartite_edges")

cb <- q(sprintf("
  SELECT SUM(CASE WHEN e.codmun_6 <> m.codmun_6_modal THEN e.n_internacoes ELSE 0 END)*100.0/SUM(e.n_internacoes) pct
  FROM %s e JOIN %s m USING (CNES)", EDG, MAS))
v("valCrossBorderPct", num(cb$pct, 1), "D6: volume-weighted share admissions outside residence muni")

mis <- q(sprintf("SELECT
    SUM((exposed_emb AND exposed_km)::int) n_both,
    SUM((exposed_emb AND NOT exposed_km)::int) miss,
    SUM((NOT exposed_emb AND exposed_km)::int) fals,
    SUM((exposed_emb OR exposed_km)::int) uni FROM %s", EXP))
v("valNboth",       comma(mis$n_both), "D6: muni-closure pairs flagged by both rules")
v("valNmissed",     comma(mis$miss), "D6: flow-only pairs (distance misses)")
v("valNfalse",      comma(mis$fals), "D6: distance-only pairs (distance false-flags)")
v("valNunionPairs", comma(mis$uni),  "D6: pairs flagged by either rule")
v("valNmisclass",   comma(mis$miss + mis$fals), "D6: misclassified = missed + false")

clo <- q(sprintf("SELECT
    SUM(exogenous::int) exo,
    SUM((exogenous AND tp_unid='07')::int) spec,
    SUM((exogenous AND tp_unid='05')::int) genr FROM %s", CLO))
v("valNexoClosures",  comma(clo$exo),  "D6: exogenous closures (F1-F5)")
v("valNspecClosures", comma(clo$spec), "D6: specialized (tp_unid=07) exogenous closures")
v("valNgenClosures",  comma(clo$genr), "D6: general (tp_unid=05) exogenous closures")

pn <- ("(year_closure BETWEEN 2006 AND 2009 OR year_closure BETWEEN 2010 AND 2013 OR year_closure BETWEEN 2014 AND 2017)")
cs <- q(sprintf("SELECT
    SUM((f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07' AND %s)::int) pnash,
    SUM((f1_window AND f2_type AND f3_beds AND f4_mass AND tp_unid='07')::int) psymax FROM %s", pn, CLO))
v("valNclosuresPnash",  comma(cs$pnash),  "D6: PNASH-anchored psychiatric closures (primary sample)")
v("valNclosuresPsymax", comma(cs$psymax), "D6: all psychiatric closures, F5 relaxed (robustness)")

# ---- intro worked example (footnote): CNES 2082683, closed 2016 ----
eg <- q(sprintf("SELECT
    SUM(n_aih_pre) FILTER(WHERE exposed_emb) adm,
    COUNT(*) FILTER(WHERE exposed_emb) n,
    COUNT(*) FILTER(WHERE exposed_emb AND dist_km BETWEEN 36 AND 107) far,
    MAX(dist_km) FILTER(WHERE exposed_emb) khi,
    MEDIAN(dist_km) FILTER(WHERE exposed_emb) kmed FROM %s WHERE CNES='2082683'", EXP))
v("valEgAdm",   comma(eg$adm),        "D6: CNES 2082683 admissions from E1-exposed munis")
v("valEgMunis", comma(eg$n),          "D6: CNES 2082683 E1-exposed municipalities")
v("valEgFar",   comma(eg$far),        "D6: of which 36-107 km away")
v("valEgKmHi",  num(eg$khi, 0),       "D6: CNES 2082683 max E1 distance (km)")
v("valEgKmMed", num(eg$kmed, 0),      "D6: CNES 2082683 median E1 distance (km)")

# ---- closure filter cascade (App. A, Table tab:filter) ----
fc <- q(sprintf("SELECT COUNT(*) f0,
    SUM(f1_window::int) f1,
    SUM((f1_window AND f2_type)::int) f2,
    SUM((f1_window AND f2_type AND f3_beds)::int) f3,
    SUM((f1_window AND f2_type AND f3_beds AND f4_mass)::int) f4,
    SUM(exogenous::int) f5 FROM %s", CLO))
# LaTeX command names cannot contain digits -> spelled-out suffixes
fk <- c(f0 = "valFiltZero", f1 = "valFiltOne", f2 = "valFiltTwo",
        f3 = "valFiltThree", f4 = "valFiltFour", f5 = "valFiltFive")
for (k in names(fk)) v(fk[[k]], comma(fc[[k]]), sprintf("D6: filter cascade %s surviving", toupper(k)))
f6 <- q(sprintf("SELECT COUNT(*) n FROM read_parquet('%s') WHERE motivo_v2 IN ('administrativo','fiscal','falencia')",
                file.path(INTER, "closures_classified_v2.parquet")))
v("valFiltSix", comma(f6$n), "D6: F6 NLP-documented robustness sub-sample")

# ---- SIM deaths in window (Data, App.) ----
sim_files <- unlist(lapply(2010:2023, function(y) Sys.glob(file.path(INTER, "..", "raw", "sim", sprintf("do*%d.parquet", y)))))
sim_sql <- paste0("[", paste(sprintf("'%s'", sim_files), collapse = ", "), "]")
dd <- q(sprintf("SELECT COUNT(*) n FROM read_parquet(%s, union_by_name=true)
   WHERE CAUSABAS IS NOT NULL AND CODMUNRES IS NOT NULL AND DTOBITO IS NOT NULL
     AND LENGTH(DTOBITO)=8 AND CAST(SUBSTR(DTOBITO,5,4) AS INTEGER) BETWEEN 2010 AND 2023", sim_sql))
v("valNdeaths", sprintf("%.1f", dd$n / 1e6), "D6: SIM deaths 2010-2023, millions")

# ---- cross-section sample sizes (App. C) ----
nx <- q(sprintf("SELECT COUNT(DISTINCT codmun_6) n FROM read_parquet('%s')",
                file.path(INTER, "staggered_panel_F5_main.parquet")))
v("valNmunisDiverg", comma(nx$n), "D6: municipalities in panel / divergence map")
n10 <- q(sprintf("SELECT COUNT(*) n FROM (SELECT codmun_6, AVG(pop) mp FROM read_parquet('%s')
   WHERE pop IS NOT NULL GROUP BY codmun_6) WHERE mp >= 10000",
                 file.path(INTER, "staggered_panel_F5_main.parquet")))
v("valNmunisTenk", comma(n10$n), "D6: municipalities with mean pop >= 10k (cross-section subset)")
dbDisconnect(con, shutdown = TRUE)

# ============================ ESTIMATES (fixest) ============================
est <- function(panel, yn, wt = FALSE, caps_excl = FALSE, drop_pand = FALSE, twfe = FALSE,
                cohort = "g_emb") {
  d <- as.data.table(read_parquet(file.path(INTER, panel)))
  d <- d[is.finite(get(yn)) & (!wt | is.finite(pop))]
  d[, gn := ifelse(is.na(get(cohort)) | get(cohort) == 0, 10000L, as.integer(get(cohort)))]
  if (drop_pand) d <- d[!(year %in% c(2020, 2021))]
  if (caps_excl) {
    caps <- c("120040","270430","160030","130260","292740","230440","530010","320530",
              "520870","211130","510340","500270","310620","150140","250750","410690",
              "261160","221100","330455","240810","431490","110020","140010","420540",
              "355030","280030","172100")
    d <- d[!codmun_6 %in% caps]
  }
  w <- if (wt) d$pop else NULL
  if (twfe) {
    d[, post := as.integer(gn < 10000 & year >= gn)]
    m <- feols(as.formula(sprintf("%s ~ post | muni_id + year", yn)), d, cluster = "muni_id", weights = w)
    return(list(att = coef(m)["post"], se = se(m)["post"]))
  }
  m <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)), d, cluster = "muni_id", weights = w)
  a <- summary(m, agg = "att"); att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  base <- if (wt) weighted.mean(d[gn < 10000 & year < 2015][[yn]], d[gn < 10000 & year < 2015]$pop, na.rm = TRUE)
          else    mean(d[gn < 10000 & year < 2015][[yn]], na.rm = TRUE)
  cf <- coef(m); s <- se(m); mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]
  pre <- es[e <= -2 & e >= -6]; W <- sum((pre$cf / pre$se)^2)
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se, base = base,
       ub = 100 * (att + 1.96 * se) / base, p = 1 - pchisq(W, nrow(pre)),
       ntr = d[gn < 10000, uniqueN(muni_id)], es = es)
}

P <- "staggered_panel_pnash48_ext.parquet"
emit <- function(pre, r, src, bound = TRUE) {
  v(paste0(pre, "Att"), sgn(r$att), src); v(paste0(pre, "Se"), num(r$se), src)
  v(paste0(pre, "Lo"), sgn(r$lo), src);   v(paste0(pre, "Hi"), sgn(r$hi), src)
  v(paste0(pre, "Ppre"), num(r$p), src)
  if (bound) v(paste0(pre, "BoundPct"), sprintf("%+.0f", r$ub), src)
}
su_w <- est(P, "suicide_per100k", TRUE);  emit("valSuicW", su_w, "D6: pnash48_ext suicide WLS")
v("valSuicBaseline", num(su_w$base), "D6: pnash48_ext suicide pre-period treated baseline (pop-wtd)")
su_o <- est(P, "suicide_per100k", FALSE); emit("valSuicO", su_o, "D6: pnash48_ext suicide OLS")
se_w <- est(P, "selfharm_per100k", TRUE); emit("valSelfW", se_w, "D6: pnash48_ext self-harm WLS")
tr   <- est(P, "travel_burden_km", FALSE); emit("valTrav", tr, "D6: pnash48_ext travel first stage", bound = FALSE)
v("valTravAbs", num(abs(tr$att), 1), "D6: |travel ATT| for 'falls X km' phrasing")

# ---- F5 first-stage travel burden: flow (g_emb) vs distance (g_km) (Results 5.2) ----
trFf <- est("staggered_panel_F5_main.parquet", "travel_burden_km", FALSE, cohort = "g_emb")
trFd <- est("staggered_panel_F5_main.parquet", "travel_burden_km", FALSE, cohort = "g_km")
v("valTravFFiveFlow", num(trFf$att, 2), "D6: F5 travel first stage, flow exposure (g_emb)")
v("valTravFFiveDist", num(trFd$att, 2), "D6: F5 travel first stage, distance exposure (g_km)")

# ---- suicide upper-CI scaled to deaths/year (matches tab:main-mortality-scaled-bounds) ----
dP <- as.data.table(read_parquet(file.path(INTER, P)))
bb <- dP[!is.na(g_emb) & g_emb != 0 & year < g_emb & is.finite(suicide_per100k) & is.finite(pop) & pop > 0]
popyr <- bb[, .(mp = mean(pop, na.rm = TRUE)), by = muni_id][, sum(mp)]
v("valSuicDeathsYr", num(su_w$hi / 1e5 * popyr, 0),
  "D6: suicide upper-CI (95%) scaled to deaths/year across exposed catchments")
v("valSuicBaseDeathsYr", num(su_w$base / 1e5 * popyr, 0),
  "D6: baseline suicide deaths/year across exposed catchments (rate x pop)")
v("valSuicAttDeathsYr", num(su_w$att / 1e5 * popyr, 0),
  "D6: point-estimate suicide deaths/year (ATT scaled across exposed catchments)")
v("valExposedPopM", num(popyr / 1e6, 1),
  "D6: exposed-catchment population, millions (pop-weighted mean over treated munis)")
v("valSelfBaseline", num(se_w$base),
  "D6: pnash48_ext self-harm pre-period treated baseline (pop-wtd)")
v("valSelfDeathsYr", num(se_w$hi / 1e5 * popyr, 0),
  "D6: self-harm upper-CI (95%) scaled to deaths/year across exposed catchments")
ic   <- est(P, "icsap_per1k", FALSE);      emit("valIcsap", ic, "D6: pnash48_ext ICSAP (non-identified)", bound = FALSE)
icpre <- ic$es[order(e)]
v("valIcsapPreFive",  sgn(icpre[e == -5]$cf), "D6: ICSAP pre-coef e=-5")
v("valIcsapPreFour",  sgn(icpre[e == -4]$cf), "D6: ICSAP pre-coef e=-4")
v("valIcsapPreThree", sgn(icpre[e == -3]$cf), "D6: ICSAP pre-coef e=-3")
v("valNtrPnash", as.character(su_w$ntr), "D6: pnash48 exposed munis")

# robustness
sp <- est("staggered_panel_spec07_ext.parquet",   "suicide_per100k", TRUE); emit("valSuicSpec",   sp, "D6: spec07_ext suicide WLS")
pm <- est("staggered_panel_psymax60_ext.parquet", "suicide_per100k", TRUE); emit("valSuicPsymax", pm, "D6: psymax60_ext suicide WLS")
v("valNtrSpec", as.character(sp$ntr), "D6: spec07 exposed munis")
v("valNtrPsymax", as.character(pm$ntr), "D6: psymax60 exposed munis")
dp <- est(P, "suicide_per100k", TRUE, drop_pand = TRUE)
v("valSuicDropPandAtt", sgn(dp$att), "D6: suicide WLS dropping 2020-21"); v("valSuicDropPandSe", num(dp$se), "D6")
nc <- est(P, "suicide_per100k", TRUE, caps_excl = TRUE)
v("valSuicNoCapAtt", sgn(nc$att), "D6: suicide WLS excl. 27 capitals"); v("valSuicNoCapSe", num(nc$se), "D6")
tw <- est(P, "suicide_per100k", TRUE, twfe = TRUE)
v("valSuicTwfeAtt", sgn(tw$att), "D6: suicide WLS naive TWFE"); v("valSuicTwfeSe", num(tw$se), "D6")

# ---- leave-one-closure-out suicide ATT range (Robustness; from script 60 output) ----
loo <- fread(file.path(ROOT, "02_data", "processed", "leave_one_closure_out_revision.csv"))
loos <- loo[outcome == "suicide_per100k" & closure_id != "baseline" & is.finite(att)]
v("valLooLo", sgn(min(loos$att)), "D6: leave-one-closure-out suicide ATT min")
v("valLooHi", sgn(max(loos$att)), "D6: leave-one-closure-out suicide ATT max")

# ---- identification-hardening batch (scripts 61-65) ----
PROC <- file.path(ROOT, "02_data", "processed")

ar <- fread(file.path(PROC, "anticipation_renorm.csv"))
v("valSuicReNormThree", sgn(ar[outcome == "suicide_per100k" & refp == -3 & weighted == TRUE]$att),
  "D6: suicide WLS ATT re-normalized to e=-3 (script 61, anticipation)")

rc <- fread(file.path(PROC, "recipient_control_spillover.csv"))
rcs <- rc[outcome == "suicide_per100k" & spec == "drop_recipient_controls"]
v("valSuicRecipAtt", sgn(rcs$att), "D6: suicide WLS ATT dropping revealed-recipient controls (script 64)")
v("valSuicRecipLo", sgn(rcs$ci_lo), "D6: script 64")
v("valSuicRecipHi", sgn(rcs$ci_hi), "D6: script 64")
v("valNrecipDropped", comma(rcs$n_recip_ctrl_dropped), "D6: revealed-recipient controls dropped (script 64)")
v("valNcleanCtrl",    comma(rcs$n_clean_ctrl), "D6: clean never-treated controls retained (script 64)")

lc <- fread(file.path(PROC, "lococor_displacement.csv"))
lco <- lc[outcome == "suicide_outhosp"]
v("valSuicOutHospAtt", sgn(lco$att), "D6: out-of-hospital suicide WLS ATT (script 65, displacement)")
v("valSuicOutHospLo", sgn(lco$ci_lo), "D6: script 65")
v("valSuicOutHospHi", sgn(lco$ci_hi), "D6: script 65")
v("valInHospShare", num(lco$baseline_inhosp_share_pct, 0), "D6: in-hospital share of pre-period suicide deaths, pct (script 65)")

gb <- fread(file.path(PROC, "goodman_bacon_suicide.csv"))
v("valBaconNeverPct",  num(100 * gb[comparison_group == "Treated vs Untreated"]$weight, 1),
  "D6: Goodman-Bacon weight on never-treated comparisons, pct (script 63)")
v("valBaconForbidPct", num(100 * gb[comparison_group == "Later vs Earlier Treated"]$weight, 1),
  "D6: Goodman-Bacon weight on forbidden already-treated comparisons, pct (script 63)")

ip <- fread(file.path(PROC, "illdefined_placebo.csv"))
ipr <- ip[grepl("R96", outcome)]
v("valIllDefAtt",  sgn(ipr$att), "D6: R96-R99 ill-defined-cause placebo ATT (script 62)")
v("valIllDefBase", num(ipr$base, 0), "D6: R96-R99 pre-period base rate per 100k (script 62)")

# ---- specification curve summary (script 80) ----
spc <- fread(file.path(PROC, "spec_curve_suicide.csv"))
v("valNspecCurve", as.character(nrow(spc)), "D6: number of specifications in the suicide spec curve (script 80)")
pref <- spc[group != "Weighting" & !grepl("Naive", label)]
v("valSpecBandLo", sgn(min(pref$att)), "D6: spec-curve suicide ATT min, design-based family (script 80)")
v("valSpecBandHi", sgn(max(pref$att)), "D6: spec-curve suicide ATT max, design-based family (script 80)")

# ---- PNASH de-accreditation cross (Portaria SAS 1727/2016; setting 2.2) ----
p17   <- fread(file.path(ROOT, "02_data", "raw", "pnash", "pnash1727_cnes.csv"))
clo48 <- as.data.table(read_parquet(file.path(ROOT, "02_data", "processed", "pnash_event_level_dataset.parquet")))
clo48[, cnes7 := trimws(as.character(CNES))]
p17[, cnes7 := trimws(as.character(cnes))]
v("valPnashDescred",    as.character(clo48[cnes7 %in% p17[anexo == "II", cnes7], uniqueN(cnes7)]),
  "D6: PNASH closures in Anexo II de-accreditation list (Portaria SAS 1727/2016)")
v("valPnashClassified", as.character(clo48[cnes7 %in% p17[anexo == "I", cnes7], uniqueN(cnes7)]),
  "D6: PNASH closures classified in Anexo I yet closed (Portaria SAS 1727/2016)")

# ---- identification: synthetic-DiD second leg (auditable, script 85) + doubly-robust/selection (script 77) ----
# Source the SDID macros from the fully-documented script 85 (sdid_results.csv) so the
# in-text one-liner and the appendix table_sdid_results.tex report identical bounds.
sdr   <- fread(file.path(PROC, "sdid_results.csv"))
sdsui <- sdr[outcome == "suicide_per100k"]
sdslf <- sdr[outcome == "selfharm_per100k"]
v("valSdidAtt", sgn(sdsui$att), "D6: synthetic-DiD aggregate suicide ATT (script 85)")
v("valSdidLo",  sgn(sdsui$ci_lo), "D6: script 85 sdid_results.csv")
v("valSdidHi",  sgn(sdsui$ci_hi), "D6: script 85 sdid_results.csv")
v("valSdidSelfAtt", sgn(sdslf$att), "D6: synthetic-DiD aggregate self-harm ATT (script 85)")
v("valSdidSelfLo",  sgn(sdslf$ci_lo), "D6: script 85 sdid_results.csv")
v("valSdidSelfHi",  sgn(sdslf$ci_hi), "D6: script 85 sdid_results.csv")
v("valSdidDonors",  comma(as.integer(sdsui$n_donors)), "D6: SDID never-treated donor pool (script 85)")
v("valSdidCohorts", as.character(as.integer(sdsui$n_cohorts)), "D6: SDID usable closure cohorts (script 85)")
v("valSdidPreRmse", num(sdsui$pre_rmse, 2), "D6: SDID suicide pre-fit RMSE (script 85)")
v("valSdidPreRmseLevel", num(sdsui$pre_rmse_over_level, 2), "D6: SDID suicide pre-fit RMSE/baseline level (script 85)")

dr <- fread(file.path(PROC, "doubly_robust_selection.csv"))
nyt <- dr[step == "2_cs_dr" & control == "not-yet-treated" & covariates == "none"]
cov <- dr[step == "2_cs_dr" & control == "never-treated" & covariates == "log_pop"]
v("valCsNotYetAtt", sgn(as.numeric(nyt$att)), "D6: CS doubly-robust, not-yet-treated controls (script 77)")
v("valCsDrCovAtt",  sgn(as.numeric(cov$att)), "D6: CS doubly-robust, covariate-adjusted (script 77)")
tim <- dr[step == "3a_timing_OLS"]
mm <- regmatches(tim$note, regexec("F\\(([0-9,]+)\\)=([0-9.]+) p=([0-9.]+)", tim$note))[[1]]
v("valSelTimingF", num(as.numeric(mm[3]), 2), "D6: selection-into-timing joint F (script 77)")
v("valSelTimingP", num(as.numeric(mm[4]), 2), "D6: selection-into-timing joint-test p (script 77)")

# ---- featured first stage: inpatient psychiatric admissions, Poisson count (script 75) ----
pa <- fread(file.path(PROC, "psych_admissions_result.csv"))
v("valPsychAdmPct",    num(abs(pa$pct), 0),               "D6: psych-admission Poisson-count ATT, |%| (script 75)")
v("valPsychAdmLo",     num(abs(pa$ci_hi), 0),             "D6: |% effect| lower magnitude = |upper CI| (script 75)")
v("valPsychAdmHi",     num(abs(pa$ci_lo), 0),             "D6: |% effect| upper magnitude = |lower CI| (script 75)")
v("valPsychAdmImpact", num(abs(pa$impact_pct), 0),        "D6: impact-year (e=0) % drop (script 75)")
v("valPsychAdmStable", num(abs(pa$stable_pct), 0),        "D6: stabilized (e=3..5) % drop (script 75)")
v("valPsychAdmMaxPre", num(pa$max_pre_dev_pct, 0),        "D6: largest pre-period deviation, % (script 75)")
v("valPsychAdmHonestM",num(pa$honest_rm_breakdown_M, 1),  "D6: HonestDiD relative-magnitudes breakdown M (script 75)")
v("valPsychAdmBase",   num(pa$base, 1),                   "D6: psych-admission pre-period treated baseline per 1,000, 2015+ (script 75)")
v("valPsychAdmPpre",   num(pa$pretrend_p),                "D6: psych-admission joint pre-trend Wald p (script 75)")

# ---- embedding vs km pair-distance correlation (App. embedding) ----
emb <- as.data.table(read_parquet(file.path(INTER, "embeddings_munmun_proj.parquet")))
cen <- as.data.table(read_parquet(file.path(INTER, "municipios_centroids.parquet")))[, .(cod_mun_6, lat, lon)]
emb <- merge(emb, cen, by = "cod_mun_6")
dim_cols <- grep("^dim_", names(emb), value = TRUE)
M <- as.matrix(emb[, ..dim_cols])
set.seed(42); N <- 5000
i <- sample(nrow(emb), N, replace = TRUE); j <- sample(nrow(emb), N, replace = TRUE)
ok <- i != j; i <- i[ok]; j <- j[ok]
d_emb <- sqrt(rowSums((M[i, ] - M[j, ])^2))
hav <- function(la1, lo1, la2, lo2) {
  R <- 6371; dla <- (la2 - la1) * pi / 180; dlo <- (lo2 - lo1) * pi / 180
  a <- sin(dla / 2)^2 + cos(la1 * pi / 180) * cos(la2 * pi / 180) * sin(dlo / 2)^2
  2 * R * asin(pmin(1, sqrt(a)))
}
d_km <- hav(emb$lat[i], emb$lon[i], emb$lat[j], emb$lon[j])
v("valEmbKmCorr", num(cor(d_emb, d_km), 2), "D6: Pearson corr embedding-dist vs km, 5000 pairs, seed 42")

# ============================ IDENTIFICATION UPGRADE (scripts 81, 83, 86) ============================
# Strict PNASH exact-window robustness (script 81 -> pnash_strict_window_results.csv)
sw <- fread(file.path(PROC, "pnash_strict_window_results.csv"))
swr <- function(samp, out) sw[sample == samp & outcome == out]
strictN <- swr("PNASH_strict", "suicide_per100k")
v("valNclosuresPnashStrict", as.character(as.integer(strictN$n_closures)), "D6: closures within exact +/-1yr of nearest PNASH cycle (script 81)")
v("valNexposedPnashStrict",  as.character(as.integer(strictN$n_exposed)), "D6: flow-exposed munis, strict PNASH sample (script 81)")
ss <- swr("PNASH_strict", "suicide_per100k")
v("valSuicStrictAtt", sgn(ss$att), "D6: suicide ATT, strict PNASH exact-window sample (script 81)")
v("valSuicStrictLo",  sgn(ss$ci_lo), "D6: script 81")
v("valSuicStrictHi",  sgn(ss$ci_hi), "D6: script 81")
sf <- swr("PNASH_strict", "selfharm_per100k")
v("valSelfStrictAtt", sgn(sf$att), "D6: self-harm ATT, strict PNASH exact-window sample (script 81)")
v("valSelfStrictLo",  sgn(sf$ci_lo), "D6: script 81")
v("valSelfStrictHi",  sgn(sf$ci_hi), "D6: script 81")

# Pre-closure timing predictor tests (script 83 -> preclosure_timing_tests.csv)
tt <- fread(file.path(PROC, "preclosure_timing_tests.csv"))
v("valTimingJointP",  num(tt[model == "joint_Ftest", as.numeric(p)], 2), "D6: closure-year joint baseline-covariate F-test p, N=48 (script 83)")
v("valTimingTrendP",  num(tt[model == "joint_trends_Ftest", as.numeric(p)], 2), "D6: closure-year joint pre-trend F-test p, N=34 (script 83)")
v("valTimingEarlyP",  num(tt[model == "joint_logit_LRtest", as.numeric(p)], 2), "D6: early-closure logit joint LR-test p (script 83)")

# CAPS baseline heterogeneity (script 86 -> caps_heterogeneity.csv)
ch <- fread(file.path(PROC, "caps_heterogeneity.csv"))
v("valCapsHetHighN", as.character(ch[outcome == "suicide_per100k" & subgroup %like% "High", as.integer(n_treated)]), "D6: treated munis with any baseline CAPS (script 86)")
v("valCapsHetLowN",  as.character(ch[outcome == "suicide_per100k" & subgroup %like% "Low",  as.integer(n_treated)]), "D6: treated munis with no baseline CAPS (script 86)")

# Outpatient MH production substitution (script O8 -> outpatient_substitution_results.csv).
# Headline row: outpatient procedures, residence basis, pop-weighted, pandemic included.
op  <- fread(file.path(PROC, "outpatient_mental_health", "outpatient_substitution_results.csv"))
oph <- op[outcome == "outpatient_mh_procedures_per1k" & basis == "residence" &
          weighting == "pop-weighted" & pandemic == "included"]
v("valOutpatProcAtt",  num(oph$att, 1),           "D6: outpatient MH procedures ATT /1k, residence pop-wt (script O8)")
v("valOutpatProcLo",   sgn(oph$ci_low, 1),        "D6: script O8")
v("valOutpatProcHi",   sgn(oph$ci_high, 1),       "D6: script O8")
v("valOutpatProcBase", num(oph$baseline_mean, 1), "D6: outpatient MH procedures pre-baseline /1k (script O8)")
# CAPS-specific (SIA 030108 psychosocial block) substitution outcome.
opc <- op[outcome == "caps_procedures_per1k" & basis == "residence" &
          weighting == "pop-weighted" & pandemic == "included"]
v("valCapsProcAtt",  num(opc$att, 1),     "D6: CAPS/SIA-psychosocial procedures ATT /1k, residence pop-wt (script O8)")
v("valCapsProcLo",   sgn(opc$ci_low, 1),  "D6: script O8")
v("valCapsProcHi",   sgn(opc$ci_high, 1), "D6: script O8")

writeLines(c("% Auto-generated by 03_analysis/D6_make_values.R — do not hand-edit.",
             "% Every manuscript number resolves here; rerun D6 to refresh.", "", LINES), OUT)
cat("wrote", OUT, "with", length(LINES), "macros\n")
