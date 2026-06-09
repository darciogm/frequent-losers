#!/usr/bin/env Rscript
# 83_preclosure_timing_tests.R
# Transparent selection-into-timing tests for the PNASH staggered DiD (N=48 closures).
#
# Question: is closure TIMING predicted by pre-existing local conditions or trends?
# If observables/pre-trends have ~no predictive power, that is consistent with
# as-good-as-random timing given the institutional (PNASH inspection-cycle) setting.
# Reported honestly: with N=48 a null is weak evidence, not proof.
#
# DVs: (a) closure_year (continuous, OLS); (b) early_closure = 1{closure_year < median};
#      (c) PNASH_exact_pm1 = within_pm1_year_of_pnash_cycle (strict-window indicator).
# Predictors (all standardized mean0/sd1 so coefs are comparable):
#   - catchment pre-trends (slope vs year, pre-period years<g): suicide, self-harm,
#     psych admissions, total admissions, travel burden;
#   - closure-level scalars: pre-closure admission decline %, baseline suicide rate,
#     baseline self-harm rate, baseline psych admissions, baseline CAPS facilities,
#     baseline log population, baseline log GDP.
#
# Models: (i) one-predictor-at-a-time OLS of closure_year on each standardized predictor;
#         (ii) ONE parsimonious joint model (<=5 predictors) for closure_year (OLS, F-test)
#              and re-run for early_closure (LPM/logit, Wald/LR chi2).
#
# Outputs:
#   02_data/processed/preclosure_timing_tests.csv
#   01_manuscript/tables_appendix/table_preclosure_timing_tests.tex
#   04_logs/preclosure_timing_tests_20260609.log
# Cache-aware: skips if CSV+TEX exist unless --force.

suppressMessages({
  library(arrow); library(data.table); library(fixest)
})
setFixest_nthreads(8); setDTthreads(8)

# ---- paths / args ----
args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args
ROOT  <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
EVENT_PARQ <- file.path(ROOT, "02_data/processed/pnash_event_level_dataset.parquet")
PANEL_PARQ <- file.path(ROOT, "02_data/processed/revision_pnash48_panel.parquet")
EDGES_PARQ <- file.path(ROOT, "02_data/intermediate/bipartite_edges.parquet")
OUT_CSV    <- file.path(ROOT, "02_data/processed/preclosure_timing_tests.csv")
OUT_TEX    <- file.path(ROOT, "01_manuscript/tables_appendix/table_preclosure_timing_tests.tex")
LOG_DIR    <- file.path(ROOT, "04_logs")
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(OUT_TEX), showWarnings = FALSE, recursive = TRUE)
LOG_FILE   <- file.path(LOG_DIR, "preclosure_timing_tests_20260609.log")

# ---- telemetry ----
con_log <- file(LOG_FILE, open = "wt")
log_msg <- function(...) {
  m <- sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(..., collapse = ""))
  cat(m, "\n"); cat(m, "\n", file = con_log); flush(con_log)
}
rss_gb <- function() {
  st <- tryCatch(readLines(sprintf("/proc/%d/status", Sys.getpid())), error = function(e) "")
  v  <- grep("^VmRSS:", st, value = TRUE)
  if (length(v)) sprintf("%.2f", as.numeric(gsub("[^0-9]", "", v)) / 1e6) else "NA"
}
t0 <- Sys.time()
log_msg("=== 83_preclosure_timing_tests ===")
log_msg("host=", Sys.info()[["nodename"]], " R=", R.version.string)
log_msg("threads: fixest=8 data.table=8  cores=", parallel::detectCores(),
        " RAM_free_GB=", tryCatch(sprintf("%.1f", as.numeric(system("awk '/MemAvailable/{print $2}' /proc/meminfo", intern=TRUE))/1e6), error=function(e) "NA"))

if (file.exists(OUT_CSV) && file.exists(OUT_TEX) && !FORCE) {
  log_msg("Outputs exist and --force not set; skipping.")
  quit(save = "no", status = 0)
}

# ============================================================================
# LOAD
# ============================================================================
e <- as.data.table(read_parquet(EVENT_PARQ))
p <- as.data.table(read_parquet(PANEL_PARQ))
be <- as.data.table(read_parquet(EDGES_PARQ))
log_msg("event-level n=", nrow(e), "  closure_year=", min(e$closure_year), "-", max(e$closure_year),
        "  median=", median(e$closure_year))
log_msg("panel rows=", nrow(p), " munis=", uniqueN(p$codmun_6), " years=", min(p$year), "-", max(p$year))
log_msg("RSS_GB=", rss_gb())

# ============================================================================
# CATCHMENT MAP  (mirror of 50_build_master_sample_table.py exposure_pairs:
#   patient-flow share rule, threshold theta=0.05, denom = pre-year admissions)
# Catchment(closure) = {muni : hospital is >=5% of its admissions in t-1}
#                      UNION {hospital's own municipality}, restricted to panel.
# ============================================================================
log_msg("--- building per-closure catchments (flow share>=0.05 + hospital muni) ---")
catch_list <- vector("list", nrow(e))
for (i in seq_len(nrow(e))) {
  cn <- e$CNES[i]; yc <- e$closure_year[i]; yp <- yc - 1L
  tot <- be[year == yp, .(denom = sum(n_internacoes)), by = codmun_6]
  toh <- be[year == yp & CNES == cn, .(num = sum(n_internacoes)), by = codmun_6]
  m   <- merge(tot, toh, by = "codmun_6", all.x = TRUE)
  m[is.na(num), num := 0]; m[, share := num / denom]
  cm  <- unique(c(m[share >= 0.05]$codmun_6, e$municipality[i]))
  cm  <- intersect(cm, p$codmun_6)
  catch_list[[i]] <- data.table(closure_id = i, CNES = cn, closure_year = yc, codmun_6 = cm)
}
catch <- rbindlist(catch_list)
log_msg("catchment muni-closure pairs=", nrow(catch),
        "  closures with >=1 panel muni=", uniqueN(catch$closure_id), " of ", nrow(e))

# ============================================================================
# PER-CLOSURE PRE-PERIOD TRENDS (slope vs year over years < closure_year)
#   pop-weighted catchment yearly mean -> OLS slope. NA if <3 distinct pre-years.
# ============================================================================
# NOTE: panel's psych_adm_per1k is only populated from 2015 onward, so it is
# uncomputable as a pre-trend for every cohort (g in 2012-2017). n_psych_adm
# (raw psychiatric admission count, all years) IS the psychiatric-admissions
# volume series -> normalize per 1k pop for a comparable rate. The panel carries
# no separate TOTAL-admissions series, so the total-admissions trend is NA here.
trend_vars <- c(
  suicide_trend     = "suicide_per100k",
  selfharm_trend    = "selfharm_per100k",
  psychadm_trend    = "n_psych_adm",       # raw psych admission count -> per-1k below
  totaladm_trend    = "__total_adm_NA__",  # no total-admissions series in panel
  travel_trend      = "travel_burden_km")

slope_of <- function(yr, val) {
  ok <- is.finite(yr) & is.finite(val)
  if (sum(ok) < 3 || length(unique(yr[ok])) < 3) return(NA_real_)
  xx <- yr[ok] - mean(yr[ok]); den <- sum(xx * xx)
  if (den <= 0) return(NA_real_)
  sum(xx * (val[ok] - mean(val[ok]))) / den
}

setkey(p, codmun_6)
trends <- data.table(closure_id = seq_len(nrow(e)))
for (nm in names(trend_vars)) trends[, (nm) := NA_real_]

for (i in seq_len(nrow(e))) {
  yc <- e$closure_year[i]
  cm <- catch[closure_id == i]$codmun_6
  if (!length(cm)) next
  sub <- p[codmun_6 %in% cm & year < yc]
  if (!nrow(sub)) next
  for (nm in names(trend_vars)) {
    v  <- trend_vars[[nm]]
    if (!v %in% names(sub)) next                 # e.g. total-admissions: no series -> NA
    if (nm == "psychadm_trend") {
      # catchment psychiatric-admission RATE per 1k: sum(adm)/sum(pop)*1000 per year
      agg <- sub[!is.na(get(v)) & !is.na(pop),
                 .(m = 1000 * sum(get(v)) / sum(pop)), by = year][order(year)]
    } else {
      # pop-weighted catchment mean per pre-year
      agg <- sub[!is.na(get(v)) & !is.na(pop),
                 .(m = sum(get(v) * pop) / sum(pop)), by = year][order(year)]
    }
    trends[closure_id == i, (nm) := slope_of(agg$year, agg$m)]
  }
}
log_msg("per-closure trend non-missing counts (of 48):")
for (nm in names(trend_vars)) log_msg(sprintf("   %-16s %d", nm, sum(!is.na(trends[[nm]]))))

# ============================================================================
# ASSEMBLE PREDICTOR MATRIX (closure-level, N=48)
# ============================================================================
D <- copy(e)
D[, closure_id := seq_len(.N)]
D <- merge(D, trends, by = "closure_id", all.x = TRUE)

D[, early_closure_bin := as.integer(closure_year < median(closure_year))]  # < 2014
D[, pnash_pm1 := as.integer(within_pm1_year_of_pnash_cycle)]
D[, base_lpop := log(pmax(pre_closure_population, 1))]
D[, base_lgdp := log(pmax(pre_closure_municipal_gdp, 1))]

# raw predictor columns with human labels and sign notes (for closure_year DV)
pred_def <- list(
  list(var="suicide_trend",  lab="Pre-closure suicide trend (catchment)",  note="positive coef => later closure"),
  list(var="selfharm_trend", lab="Pre-closure self-harm trend (catchment)",note="positive coef => later closure"),
  list(var="psychadm_trend", lab="Pre-closure psych-admissions trend",     note="positive coef => later closure"),
  list(var="totaladm_trend", lab="Pre-closure total-admissions trend",     note="positive coef => later closure"),
  list(var="travel_trend",   lab="Pre-closure travel-burden trend",        note="positive coef => later closure"),
  list(var="pre_volume_decline_pct",                       lab="Pre-closure admission decline (\\%)", note="positive coef => later closure"),
  list(var="pre_closure_suicide_rate_exposed_catchment",  lab="Baseline suicide rate (catchment)",   note="positive coef => later closure"),
  list(var="pre_closure_selfharm_rate_exposed_catchment", lab="Baseline self-harm rate (catchment)", note="positive coef => later closure"),
  list(var="pre_closure_psychiatric_admissions",          lab="Baseline psychiatric admissions",     note="positive coef => later closure"),
  list(var="pre_closure_caps_facilities_hospital_municipality", lab="Baseline CAPS facilities",       note="positive coef => later closure"),
  list(var="base_lpop", lab="Baseline log population", note="positive coef => later closure"),
  list(var="base_lgdp", lab="Baseline log GDP",        note="positive coef => later closure")
)
pred_vars <- sapply(pred_def, `[[`, "var")
pred_labs <- setNames(sapply(pred_def, `[[`, "lab"),  pred_vars)
pred_note <- setNames(sapply(pred_def, `[[`, "note"), pred_vars)

# standardize (mean0/sd1) -> *_z ; sd computed on non-missing, NA kept as NA
zname <- function(v) paste0(v, "_z")
for (v in pred_vars) {
  x <- as.numeric(D[[v]]); s <- sd(x, na.rm = TRUE)
  D[, (zname(v)) := if (is.finite(s) && s > 0) (x - mean(x, na.rm = TRUE)) / s else NA_real_]
}

# ============================================================================
# MODEL (i): one-predictor-at-a-time OLS of closure_year on standardized predictor
# ============================================================================
log_msg("--- Model (i): one-at-a-time OLS, DV=closure_year ---")
RES <- list()
add <- function(dv, model, predictor, coef, se, p, n, note) {
  RES[[length(RES)+1]] <<- data.table(
    dv=dv, model=model, predictor=predictor,
    coef=ifelse(is.na(coef),NA,round(coef,4)),
    se=ifelse(is.na(se),NA,round(se,4)),
    p=ifelse(is.na(p),NA,round(p,4)),
    n=n, note=note)
}

for (v in pred_vars) {
  zz <- zname(v)
  ok <- is.finite(D[[zz]])
  n  <- sum(ok)
  if (n < 5 || sd(D[[zz]][ok]) == 0) {
    log_msg(sprintf("   %-50s SKIP (n=%d usable)", v, n))
    add("closure_year", "one_at_a_time", pred_labs[[v]], NA, NA, NA, n,
        paste0(pred_note[[v]], "; insufficient variation/coverage"))
    next
  }
  m  <- lm(reformulate(zz, "closure_year"), data = D[ok])
  sm <- summary(m)$coefficients
  co <- sm[zz, "Estimate"]; se <- sm[zz, "Std. Error"]; pv <- sm[zz, "Pr(>|t|)"]
  log_msg(sprintf("   %-50s beta=%+.3f se=%.3f p=%.3f n=%d", v, co, se, pv, n))
  add("closure_year", "one_at_a_time", pred_labs[[v]], co, se, pv, n, pred_note[[v]])
}

# ============================================================================
# MODEL (ii): parsimonious JOINT model (<=5 predictors) for closure_year
# Pick predictors that are (a) fully covered (N=48) and (b) substantively the
# leading selection-into-timing channels, to avoid overfit with N=48.
# Chosen: admission decline, baseline psych admissions, baseline CAPS, base log pop,
#         base log GDP -- but base log pop/GDP only have 14 obs, so we keep the
#         four FULL-coverage scalars and add the best-covered catchment trend.
# Implementation: rank candidate full/near-full predictors by univariate |t| and
# take the top set with N>=40 to keep a complete-case sample large.
# ============================================================================
log_msg("--- Model (ii): parsimonious joint model, DV=closure_year ---")
# coverage of standardized predictors
zcov <- sapply(pred_vars, function(v) sum(is.finite(D[[zname(v)]])))
log_msg("standardized predictor coverage (of 48):")
for (v in pred_vars) log_msg(sprintf("   %-50s %d", v, zcov[[v]]))

# candidate pool = predictors with >=40 non-missing (keeps complete-case N high)
pool <- names(zcov)[zcov >= 40]
log_msg("joint-model candidate pool (coverage>=40): ", paste(pool, collapse=", "))

# rank pool by univariate |t| from model (i) and cap at 5
uni <- rbindlist(RES)[model=="one_at_a_time"]
uni[, abs_t := abs(coef/se)]
rank_lab <- uni[predictor %in% pred_labs[pool]][order(-abs_t)]$predictor
top_lab  <- head(rank_lab, 5)
top_var  <- names(pred_labs)[match(top_lab, pred_labs)]
log_msg("joint predictors (top<=5 by univariate |t|): ", paste(top_var, collapse=", "))

ztop <- zname(top_var)
DD   <- D[complete.cases(D[, ..ztop])]
log_msg("joint complete-case n=", nrow(DD))

mj  <- lm(reformulate(ztop, "closure_year"), data = DD)
smj <- summary(mj)
fst <- smj$fstatistic
fval<- unname(fst["value"]); fdf1<- unname(fst["numdf"]); fdf2<- unname(fst["dendf"])
fp  <- pf(fval, fdf1, fdf2, lower.tail = FALSE)
adjr2 <- smj$adj.r.squared
log_msg(sprintf("JOINT (closure_year): F(%d,%d)=%.3f p=%.4f adjR2=%.4f n=%d",
                fdf1, fdf2, fval, fp, adjr2, nrow(DD)))

cj <- as.data.table(smj$coefficients, keep.rownames="term")[term != "(Intercept)"]
for (k in seq_len(nrow(cj))) {
  v <- sub("_z$", "", cj$term[k])
  add("closure_year", "joint", pred_labs[[v]], cj$Estimate[k], cj$`Std. Error`[k],
      cj$`Pr(>|t|)`[k], nrow(DD), pred_note[[v]])
}
add("closure_year", "joint_Ftest", "JOINT F-test", fval, NA, fp, nrow(DD),
    sprintf("F(%d,%d); adjR2=%.4f", fdf1, fdf2, adjr2))

# ---- TREND-ONLY joint model: directly test that catchment PRE-TRENDS do not
#      jointly predict timing. Use the covered catchment trends (drop the 0-cov
#      total-admissions trend). This is the key test for "timing not driven by
#      pre-existing local trends". Lower N (complete-case over trend slopes). ----
trend_z <- zname(c("suicide_trend", "selfharm_trend", "psychadm_trend", "travel_trend"))
trend_z <- trend_z[sapply(trend_z, function(z) sum(is.finite(D[[z]])) >= 20)]
if (length(trend_z) >= 2) {
  DT <- D[complete.cases(D[, ..trend_z])]
  mt <- lm(reformulate(trend_z, "closure_year"), data = DT)
  st <- summary(mt); ft <- st$fstatistic
  ftv <- unname(ft["value"]); ftd1 <- unname(ft["numdf"]); ftd2 <- unname(ft["dendf"])
  ftp <- pf(ftv, ftd1, ftd2, lower.tail = FALSE)
  log_msg(sprintf("TREND-ONLY JOINT (closure_year): F(%d,%d)=%.3f p=%.4f adjR2=%.4f n=%d  preds=%s",
                  ftd1, ftd2, ftv, ftp, st$adj.r.squared, nrow(DT),
                  paste(sub("_z$","",trend_z), collapse=",")))
  ct <- as.data.table(st$coefficients, keep.rownames="term")[term != "(Intercept)"]
  for (k in seq_len(nrow(ct))) {
    v <- sub("_z$", "", ct$term[k])
    add("closure_year", "joint_trends", pred_labs[[v]], ct$Estimate[k], ct$`Std. Error`[k],
        ct$`Pr(>|t|)`[k], nrow(DT), pred_note[[v]])
  }
  add("closure_year", "joint_trends_Ftest", "JOINT F-test (pre-trends only)", ftv, NA, ftp, nrow(DT),
      sprintf("F(%d,%d); adjR2=%.4f", ftd1, ftd2, st$adj.r.squared))
}

# ============================================================================
# MODEL (ii) repeated for DV = early_closure (LPM + logit, Wald/LR chi2)
# ============================================================================
log_msg("--- Model (ii): joint model, DV=early_closure (LPM + logit) ---")
# LPM joint F (same predictors)
mlpm <- lm(reformulate(ztop, "early_closure_bin"), data = DD)
slpm <- summary(mlpm); flpm <- slpm$fstatistic
flpm_v <- unname(flpm["value"]); flpm_p <- pf(flpm_v, flpm["numdf"], flpm["dendf"], lower.tail=FALSE)
log_msg(sprintf("EARLY LPM joint F(%d,%d)=%.3f p=%.4f adjR2=%.4f",
                unname(flpm["numdf"]), unname(flpm["dendf"]), flpm_v, flpm_p, slpm$adj.r.squared))
clpm <- as.data.table(slpm$coefficients, keep.rownames="term")[term != "(Intercept)"]
for (k in seq_len(nrow(clpm))) {
  v <- sub("_z$","",clpm$term[k])
  add("early_closure", "joint_LPM", pred_labs[[v]], clpm$Estimate[k], clpm$`Std. Error`[k],
      clpm$`Pr(>|t|)`[k], nrow(DD), "LPM; positive coef => more likely early")
}

# logit + LR chi2 vs null
mlog0 <- glm(early_closure_bin ~ 1, data = DD, family = binomial())
mlog1 <- suppressWarnings(glm(reformulate(ztop, "early_closure_bin"), data = DD, family = binomial()))
ll0 <- as.numeric(logLik(mlog0)); ll1 <- as.numeric(logLik(mlog1))
lr  <- 2*(ll1-ll0); df <- length(ztop); lr_p <- pchisq(lr, df, lower.tail=FALSE)
mcf <- 1 - ll1/ll0
fitr <- range(fitted(mlog1))
log_msg(sprintf("EARLY logit LR chi2(%d)=%.3f p=%.4f McFaddenR2=%.4f fitted=[%.3f,%.3f]",
                df, lr, lr_p, mcf, fitr[1], fitr[2]))
add("early_closure", "joint_logit_LRtest", "JOINT LR chi2", lr, NA, lr_p, nrow(DD),
    sprintf("LR chi2(%d); McFaddenR2=%.4f", df, mcf))

# ============================================================================
# DV (c): PNASH exact +/-1 strict window (37/11 split). Perfect-separation risk.
# LPM joint (separation-safe) + logit with separation diagnostic.
# ============================================================================
log_msg("--- DV (c): PNASH exact +/-1 (within_pm1), 37/11 split ---")
log_msg("pnash_pm1 table: ", paste(c(table(D$pnash_pm1)), collapse="/"),
        "  (0=outside, 1=within)")
# LPM joint on full sample (N=48) with the same standardized predictors that are
# fully covered; restrict to top_var with coverage 48 to keep N=48.
zfull <- zname(top_var[zcov[top_var] >= 48])
if (length(zfull) >= 1) {
  Dpm <- D[complete.cases(D[, ..zfull])]
  mpm <- lm(reformulate(zfull, "pnash_pm1"), data = Dpm)
  spm <- summary(mpm); fpm <- spm$fstatistic
  fpm_v <- unname(fpm["value"]); fpm_p <- pf(fpm_v, fpm["numdf"], fpm["dendf"], lower.tail=FALSE)
  log_msg(sprintf("PNASH-pm1 LPM joint F(%d,%d)=%.3f p=%.4f n=%d (predictors: %s)",
                  unname(fpm["numdf"]), unname(fpm["dendf"]), fpm_v, fpm_p, nrow(Dpm),
                  paste(top_var[zcov[top_var]>=48], collapse=",")))
  add("pnash_pm1", "joint_LPM_Ftest", "JOINT F-test (LPM)", fpm_v, NA, fpm_p, nrow(Dpm),
      sprintf("F(%d,%d); within_pm1 37/11; LPM used (perfect-separation risk in logit)",
              unname(fpm["numdf"]), unname(fpm["dendf"])))
  # logit separation diagnostic
  mpl <- suppressWarnings(glm(reformulate(zfull, "pnash_pm1"), data = Dpm, family = binomial()))
  fr  <- range(fitted(mpl))
  sep <- (fr[1] < 1e-4) || (fr[2] > 1-1e-4)
  log_msg(sprintf("PNASH-pm1 logit fitted range=[%.4f,%.4f] separation_flag=%s", fr[1], fr[2], sep))
} else {
  log_msg("PNASH-pm1: no fully-covered standardized predictor; reporting NA.")
  add("pnash_pm1", "joint_LPM_Ftest", "JOINT F-test (LPM)", NA, NA, NA, NA,
      "uncomputable: no fully-covered standardized predictor")
}

# ============================================================================
# WRITE CSV
# ============================================================================
out <- rbindlist(RES, fill = TRUE)
fwrite(out, OUT_CSV)
log_msg("wrote ", OUT_CSV, " (", nrow(out), " rows)")

# ============================================================================
# WRITE LATEX (booktabs + threeparttable, standalone \input fragment)
# Panel A: one-at-a-time (closure_year). Panel B: joint model (closure_year) + F.
# ============================================================================
fmt <- function(x, d=3) ifelse(is.na(x), "--", formatC(x, format="f", digits=d))
stars <- function(p) ifelse(is.na(p), "", ifelse(p<0.01,"***", ifelse(p<0.05,"**", ifelse(p<0.10,"*",""))))

A <- out[dv=="closure_year" & model=="one_at_a_time"]
B <- out[dv=="closure_year" & model=="joint"]
BF <- out[dv=="closure_year" & model=="joint_Ftest"]
BT <- out[dv=="closure_year" & model=="joint_trends"]
BTF <- out[dv=="closure_year" & model=="joint_trends_Ftest"]
EARLY_LR <- out[dv=="early_closure" & model=="joint_logit_LRtest"]
PM_F     <- out[dv=="pnash_pm1"  & model=="joint_LPM_Ftest"]

tex <- c(
"% Auto-generated by 03_analysis/83_preclosure_timing_tests.R -- do not edit by hand.",
"\\begin{table}[!htbp]\\centering",
"\\caption{Pre-closure timing tests: is closure timing predicted by pre-existing local conditions or trends?}",
"\\label{tab:preclosure-timing-tests}",
"\\begin{threeparttable}",
"\\small",
"\\begin{tabular}{lccc}",
"\\toprule",
"Standardized predictor & Coef. & Std.\\ err. & $p$-value \\\\",
"\\midrule",
"\\multicolumn{4}{l}{\\emph{Panel A. One-predictor-at-a-time OLS, DV $=$ closure year}}\\\\",
"\\addlinespace")
for (k in seq_len(nrow(A))) {
  tex <- c(tex, sprintf("%s & %s%s & %s & %s \\\\",
    A$predictor[k], fmt(A$coef[k]), stars(A$p[k]), fmt(A$se[k]), fmt(A$p[k])))
}
tex <- c(tex,
"\\addlinespace",
"\\midrule",
"\\multicolumn{4}{l}{\\emph{Panel B. Parsimonious joint OLS, DV $=$ closure year}}\\\\",
"\\addlinespace")
for (k in seq_len(nrow(B))) {
  tex <- c(tex, sprintf("%s & %s%s & %s & %s \\\\",
    B$predictor[k], fmt(B$coef[k]), stars(B$p[k]), fmt(B$se[k]), fmt(B$p[k])))
}
tex <- c(tex,
"\\addlinespace",
"\\midrule",
"\\multicolumn{4}{l}{\\emph{Panel C. Pre-trends-only joint OLS, DV $=$ closure year}}\\\\",
"\\addlinespace")
for (k in seq_len(nrow(BT))) {
  tex <- c(tex, sprintf("%s & %s%s & %s & %s \\\\",
    BT$predictor[k], fmt(BT$coef[k]), stars(BT$p[k]), fmt(BT$se[k]), fmt(BT$p[k])))
}
tex <- c(tex,
"\\addlinespace",
"\\midrule",
sprintf("\\multicolumn{4}{l}{\\textbf{Joint $F$-test, Panel~B (closure year): $F(%s)=%s$, $p=%s$; adj.\\ $R^2=%s$; $N=%d$.}}\\\\",
        gsub("F\\((.*)\\);.*","\\1", BF$note),
        fmt(BF$coef,2), fmt(BF$p), gsub(".*adjR2=","", BF$note), BF$n),
sprintf("\\multicolumn{4}{l}{\\textbf{Joint $F$-test, Panel~C pre-trends (closure year): $F(%s)=%s$, $p=%s$; adj.\\ $R^2=%s$; $N=%d$.}}\\\\",
        gsub("F\\((.*)\\);.*","\\1", BTF$note),
        fmt(BTF$coef,2), fmt(BTF$p), gsub(".*adjR2=","", BTF$note), BTF$n),
sprintf("\\multicolumn{4}{l}{\\textbf{Joint test (early vs.\\ late closure): LR $\\chi^2=%s$, $p=%s$; $N=%d$.}}\\\\",
        fmt(EARLY_LR$coef,2), fmt(EARLY_LR$p), EARLY_LR$n),
sprintf("\\multicolumn{4}{l}{Joint test (PNASH exact $\\pm1$ window, LPM): $F=%s$, $p=%s$; $N=%s$.}\\\\",
        fmt(PM_F$coef,2), fmt(PM_F$p), ifelse(is.na(PM_F$n),"--",as.character(PM_F$n))),
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}[flushleft]\\footnotesize",
"\\item \\textit{Notes.} Unit of observation is the closure event ($N=48$). All predictors are standardized to mean~0 and standard deviation~1, so coefficients are directly comparable in standard-deviation units; a positive coefficient on the closure-year DV means the predictor is associated with a \\emph{later} closure. Catchment pre-trends are per-closure linear slopes (population-weighted catchment mean regressed on year) over the pre-period years $t<g$; closures in the earliest cohort have only two pre-years and so receive a missing slope (reported as `--' / dropped from the joint model). The total-admissions trend is not reported because the municipality--year panel carries no total-admissions series. Baseline catchment suicide/self-harm rates, population, and GDP are available for a subset of events; Panel~B is therefore restricted to the fully covered standardized scalars (top predictors by univariate $|t|$, capped to avoid overfitting at $N=48$) and Panel~C reports a complementary joint specification using only the catchment pre-trends, which directly tests whether timing is driven by pre-existing local trends. The early-vs-late dummy equals one if the closure year is below the sample median (2014); the PNASH exact $\\pm1$ indicator (37 within / 11 outside) is modeled by a linear probability model because the logit suffers perfect separation. ${}^{*}p<0.10$, ${}^{**}p<0.05$, ${}^{***}p<0.01$.",
"\\item \\textit{Power caveat.} With $N=48$ these tests are low-powered. A failure to reject predictability of timing is \\emph{consistent with} as-good-as-random closure timing given the PNASH inspection-cycle institutional setting, but it is not proof of unconfoundedness.",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{table}")
writeLines(tex, OUT_TEX)
log_msg("wrote ", OUT_TEX, " (", length(tex), " lines)")

log_msg("HEADLINE closure_year joint: F(", fdf1, ",", fdf2, ")=", round(fval,3), " p=", round(fp,4))
log_msg("HEADLINE early_closure joint: LR chi2(", df, ")=", round(lr,3), " p=", round(lr_p,4))
log_msg("elapsed=", round(as.numeric(difftime(Sys.time(), t0, units="secs")),1), "s  RSS_GB=", rss_gb())
log_msg("=== DONE ===")
close(con_log)
