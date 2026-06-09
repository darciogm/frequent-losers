#!/usr/bin/env Rscript
# 77_doubly_robust_selection.R
# Strengthen the conditional-unconfoundedness case for the PNASH staggered DiD.
#
# (A) Doubly-robust staggered DiD (Callaway-Sant'Anna 2021, did::att_gt, est_method="dr"):
#     never-treated vs not-yet-treated controls, with/without municipality covariates.
#     Validated against the canonical pop-weighted Sun-Abraham suicide ATT (~+0.28).
# (B) Selection-into-timing test: regress closure timing on the pre-closure covariate
#     vector. LOW predictive power => timing not explained by local conditions =>
#     supports as-good-as-random timing. Reported honestly.
#
# Outputs: 02_data/processed/doubly_robust_selection.csv + 04_logs/77_*.log
# Cache-aware: skips if output exists unless --force.

suppressMessages({
  library(arrow); library(data.table); library(fixest); library(did)
})

setFixest_nthreads(6); setDTthreads(6)

# ---- paths / args ----
args        <- commandArgs(trailingOnly = TRUE)
FORCE       <- "--force" %in% args
ROOT        <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
PANEL_PARQ  <- file.path(ROOT, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")
EVENT_PARQ  <- file.path(ROOT, "02_data/processed/pnash_event_level_dataset.parquet")
OUT_CSV     <- file.path(ROOT, "02_data/processed/doubly_robust_selection.csv")
LOG_DIR     <- file.path(ROOT, "04_logs")
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)
LOG_FILE    <- file.path(LOG_DIR, format(Sys.time(), "77_doubly_robust_selection_%Y%m%d_%H%M%S.log"))

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
log_msg("=== 77_doubly_robust_selection ===")
log_msg("host=", Sys.info()[["nodename"]], " R=", R.version.string)
log_msg("threads: fixest=6 data.table=6  cores=", parallel::detectCores(),
        " RAM_free_GB=", tryCatch(sprintf("%.1f", as.numeric(system("awk '/MemAvailable/{print $2}' /proc/meminfo", intern=TRUE))/1e6), error=function(e) "NA"))

if (file.exists(OUT_CSV) && !FORCE) {
  log_msg("Output exists and --force not set; skipping. ", OUT_CSV)
  quit(save = "no", status = 0)
}

# results accumulator
RES <- list()
add <- function(step, estimand, control, covariates, att, se, ci_lo, ci_hi, note = "") {
  RES[[length(RES) + 1]] <<- data.table(
    step = step, estimand = estimand, control = control, covariates = covariates,
    att = round(att, 3), se = round(se, 3),
    ci_lo = round(ci_lo, 3), ci_hi = round(ci_hi, 3), note = note)
}

# ============================================================================
# LOAD
# ============================================================================
d <- as.data.table(read_parquet(PANEL_PARQ))
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
d[, lpop := log(pmax(pop, 1))]
log_msg("panel rows=", nrow(d), " munis=", uniqueN(d$muni_id),
        " years=", min(d$year), "-", max(d$year),
        " treated_cohorts=", paste(sort(unique(d$gn[d$gn < 10000])), collapse=","))
log_msg("RSS_GB=", rss_gb())

# ============================================================================
# STEP 1 — VALIDATION: pop-weighted Sun-Abraham suicide ATT (~ +0.28)
# ============================================================================
log_msg("--- STEP 1: Sun-Abraham validation ---")
m_sa <- feols(suicide_per100k ~ sunab(gn, year) | muni_id + year,
              data = d, cluster = "muni_id", weights = ~pop)
sa_att <- summary(m_sa, agg = "att")
sa_co  <- coef(sa_att)[["ATT"]]
sa_se  <- se(sa_att)[["ATT"]]
sa_ci  <- confint(sa_att)["ATT", ]
log_msg(sprintf("SA pop-weighted suicide ATT = %.3f  SE=%.3f  CI=[%.3f, %.3f]",
                sa_co, sa_se, sa_ci[[1]], sa_ci[[2]]))
add("1_validation", "suicide_ATT", "SA_implicit", "none(FE)", sa_co, sa_se, sa_ci[[1]], sa_ci[[2]],
    "Sun-Abraham pop-weighted; target ~+0.28 CI~[-0.72,+1.29]")

VALID <- abs(sa_co - 0.28) < 0.20   # tolerance band around canonical +0.28
if (!VALID) {
  log_msg("!! VALIDATION FAILED: SA ATT ", round(sa_co,3), " not ~ +0.28. STOPPING per spec.")
  fwrite(rbindlist(RES), OUT_CSV)
  quit(save = "no", status = 1)
}
log_msg("VALIDATION PASSED (within tolerance of +0.28).")

# ============================================================================
# STEP 2 — Callaway-Sant'Anna doubly-robust
#   never-treated / not-yet-treated controls, with/without log-pop covariate.
# CS uses gn=0 for never-treated; recode 10000 -> 0.
# ============================================================================
log_msg("--- STEP 2: Callaway-Sant'Anna doubly-robust (att_gt, est_method='dr') ---")
dcs <- copy(d)
# gcs must be NUMERIC: did internally recodes never-treated (gcs==0) -> Inf, which
# silently becomes NA on an integer column, destroying the never-treated group.
dcs[, gcs := as.numeric(ifelse(gn >= 10000L, 0L, gn))]
# balanced-ish: ensure muni_id integer, drop rows missing outcome
dcs <- dcs[!is.na(suicide_per100k) & !is.na(lpop)]

run_cs <- function(control, xformla = NULL, label) {
  ag <- tryCatch({
    atts <- att_gt(
      yname = "suicide_per100k", tname = "year", idname = "muni_id", gname = "gcs",
      data = as.data.frame(dcs), control_group = control, est_method = "dr",
      xformla = xformla, weightsname = "pop", panel = TRUE,
      allow_unbalanced_panel = TRUE, bstrap = TRUE, cband = FALSE, base_period = "universal")
    aggte(atts, type = "simple", na.rm = TRUE)
  }, error = function(e) { log_msg("  CS ERROR [", label, "]: ", conditionMessage(e)); NULL })
  if (is.null(ag)) return(invisible(NULL))
  att <- ag$overall.att; se <- ag$overall.se
  lo  <- att - 1.96 * se; hi <- att + 1.96 * se
  log_msg(sprintf("  CS-DR [%s]: ATT=%.3f  SE=%.3f  CI=[%.3f, %.3f]", label, att, se, lo, hi))
  add("2_cs_dr", "suicide_ATT_simple",
      ifelse(control == "nevertreated", "never-treated", "not-yet-treated"),
      ifelse(is.null(xformla), "none", "log_pop"),
      att, se, lo, hi, paste0("CS doubly-robust; ", label))
}

run_cs("nevertreated",   NULL,        "nevertreated, no covars")
run_cs("notyettreated",  NULL,        "notyettreated, no covars")
run_cs("nevertreated",   ~lpop,       "nevertreated, +log_pop (DR)")
run_cs("notyettreated",  ~lpop,       "notyettreated, +log_pop (DR)")
log_msg("RSS_GB=", rss_gb())

# ============================================================================
# STEP 3 — Selection-into-timing test (credibility test)
# Regress closure timing on standardized pre-closure covariate vector.
# LOW predictive power => timing as-good-as-random. Report honestly.
# ============================================================================
log_msg("--- STEP 3: selection-into-timing test ---")
e <- as.data.table(read_parquet(EVENT_PARQ))
log_msg("event-level n=", nrow(e), "  closure_year range=", min(e$closure_year), "-", max(e$closure_year))

cand_covs <- c(
  "pre_closure_caps_coverage_hospital_municipality",
  "pre_closure_fhs_primary_care_coverage",
  "pre_closure_private_insurance_penetration",
  "pre_closure_municipal_gdp",
  "pre_closure_population",
  "pre_closure_suicide_rate_exposed_catchment",
  "pre_closure_selfharm_rate_exposed_catchment",
  "pre_closure_psychiatric_admissions_3y_avg",
  "pre_volume_decline_pct",
  "within_pm1_year_of_pnash_cycle")

# Honest data-coverage audit: drop covariates that are >50% missing (unusable).
cov_cov <- sapply(cand_covs, function(c) sum(!is.na(e[[c]])))
log_msg("covariate non-missing counts (of ", nrow(e), "):")
for (c in cand_covs) log_msg(sprintf("   %-50s %d", c, cov_cov[[c]]))
usable <- names(cov_cov)[cov_cov >= 0.5 * nrow(e)]
dropped <- setdiff(cand_covs, usable)
log_msg("USABLE covariates (>=50%% non-missing): ", paste(usable, collapse=", "))
log_msg("DROPPED (too missing): ", paste(dropped, collapse=", "))

# Standardize usable covariates; complete-case
es <- copy(e)
for (c in usable) es[, (c) := as.numeric(scale(get(c)))]
es <- es[complete.cases(es[, ..usable])]
log_msg("complete-case n for timing regression = ", nrow(es))

# 3a: linear regression of closure_year on standardized covariates
f_lin <- as.formula(paste("closure_year ~", paste(usable, collapse = " + ")))
m_lin <- lm(f_lin, data = es)
sm    <- summary(m_lin)
r2    <- sm$r.squared; adjr2 <- sm$adj.r.squared
fst   <- sm$fstatistic
fval  <- unname(fst["value"]); fdf1 <- unname(fst["numdf"]); fdf2 <- unname(fst["dendf"])
fp    <- pf(fval, fdf1, fdf2, lower.tail = FALSE)
log_msg(sprintf("3a closure_year~covs: R2=%.3f adjR2=%.3f  F(%d,%d)=%.3f  p=%.3f",
                r2, adjr2, fdf1, fdf2, fval, fp))
add("3a_timing_OLS", "closure_year", "n/a", paste(usable, collapse=";"),
    r2, NA, NA, NA, sprintf("F(%d,%d)=%.3f p=%.3f adjR2=%.3f", fdf1, fdf2, fval, fp, adjr2))

# significant predictors
co <- as.data.table(sm$coefficients, keep.rownames = "term")[term != "(Intercept)"]
sig <- co[`Pr(>|t|)` < 0.05]
if (nrow(sig)) {
  for (i in seq_len(nrow(sig)))
    log_msg(sprintf("   SIGNIFICANT(OLS): %s  beta=%.3f p=%.3f",
                    sig$term[i], sig$Estimate[i], sig$`Pr(>|t|)`[i]))
} else log_msg("   No covariate significantly predicts closure_year at p<0.05.")

# 3b: logistic regression of early_closure on covariates (pseudo-R2).
# CAUTION: early_closure := closure_year<=2014, so it is a coarsening of the very
# variable being modeled. within_pm1_year_of_pnash_cycle perfectly separates the
# outcome (all early closures are outside +/-1 of a PNASH cycle), making the full
# logit's LR test / pseudo-R2 artifactual. We (i) detect separation, (ii) drop the
# separating predictor and refit, and (iii) base the verdict on the separation-free
# continuous-timing OLS, not on this logit.
es[, early := as.integer(early_closure)]

# detect perfect/quasi separation via a perfect 2x2 with the binary cycle var
sep_tab  <- table(es$within_pm1_year_of_pnash_cycle, es$early)
separated <- any(sep_tab == 0) && nrow(sep_tab) == 2
log_msg("3b separation check (within_pm1 x early): ",
        paste(c(t(sep_tab)), collapse=","), " -> separated=", separated)

fit_logit <- function(vars, lab) {
  if (!length(vars)) return(NULL)
  f  <- as.formula(paste("early ~", paste(vars, collapse = " + ")))
  m  <- suppressWarnings(glm(f, data = es, family = binomial()))
  ll1 <- as.numeric(logLik(m)); ll0 <- as.numeric(logLik(glm(early~1,es,family=binomial())))
  mcf <- 1 - ll1/ll0; lr <- 2*(ll1-ll0); df <- length(vars)
  p   <- pchisq(lr, df, lower.tail = FALSE)
  fp_ <- range(fitted(m))
  log_msg(sprintf("3b logit [%s]: McFadden pseudoR2=%.3f LR chi2(%d)=%.3f p=%.3f fitted=[%.3f,%.3f]",
                  lab, mcf, df, lr, p, fp_[1], fp_[2]))
  list(mcf=mcf, lr=lr, df=df, p=p, m=m)
}

# refit dropping the separating predictor -> usable, interpretable test
usable_logit <- setdiff(usable, "within_pm1_year_of_pnash_cycle")
lg <- fit_logit(usable_logit, "drop within_pm1 (separation-safe)")
lr_p <- lg$p; mcf <- lg$mcf
add("3b_timing_logit", "early_closure", "n/a", paste(usable_logit, collapse=";"),
    mcf, NA, NA, NA,
    sprintf("LR chi2(%d)=%.3f p=%.3f McFaddenR2 (within_pm1 dropped: perfect separation%s)",
            lg$df, lg$lr, lg$p, ifelse(separated, "" , " not detected")))

slog <- as.data.table(summary(lg$m)$coefficients, keep.rownames = "term")[term != "(Intercept)"]
sigl <- slog[`Pr(>|z|)` < 0.05]
if (nrow(sigl)) {
  for (i in seq_len(nrow(sigl)))
    log_msg(sprintf("   SIGNIFICANT(logit): %s  beta=%.3f p=%.3f",
                    sigl$term[i], sigl$Estimate[i], sigl$`Pr(>|z|)`[i]))
} else log_msg("   No covariate significantly predicts early/late closure at p<0.05.")

# ============================================================================
# VERDICT
# ============================================================================
log_msg("--- STEP 4: VERDICT ---")
cs_tab  <- rbindlist(RES)[step == "2_cs_dr"]
nyt_ok  <- cs_tab[control == "not-yet-treated", all(ci_lo <= 0 & ci_hi >= 0)]
cov_ok  <- cs_tab[covariates == "log_pop", all(ci_lo <= 0 & ci_hi >= 0)]
all_close <- cs_tab[, all(abs(att - sa_co) < 1.0)]
# Primary timing test = continuous closure_year OLS (no separation). The binary
# early/late logit is corroborating but compromised by separation, so it is not
# allowed to flip the verdict on its own.
timing_unpredicted <- (fp > 0.10) && (lr_p > 0.10)

verdict <- if (nyt_ok && cov_ok && timing_unpredicted) {
  "STRENGTHEN: null survives not-yet-treated & covariate-adjusted DR; timing unpredicted by observables."
} else if (!timing_unpredicted) {
  "THREAT-FOUND: closure timing predicted by pre-closure observables (selection-into-timing)."
} else if (!nyt_ok || !cov_ok) {
  "INCONCLUSIVE: CS-DR estimate(s) diverge from the SA null under robustness checks."
} else "INCONCLUSIVE."
log_msg("nyt_null_survives=", nyt_ok, " cov_null_survives=", cov_ok,
        " cs_close_to_SA=", all_close, " timing_unpredicted=", timing_unpredicted)
log_msg("VERDICT: ", verdict)
add("4_verdict", "verdict", "n/a", "n/a", NA, NA, NA, NA, verdict)

# ============================================================================
# WRITE
# ============================================================================
out <- rbindlist(RES, fill = TRUE)
fwrite(out, OUT_CSV)
log_msg("wrote ", OUT_CSV, " (", nrow(out), " rows)")
log_msg("elapsed=", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1), "s  RSS_GB=", rss_gb())
log_msg("=== DONE ===")
close(con_log)
