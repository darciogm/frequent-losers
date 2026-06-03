#!/usr/bin/env Rscript
# =============================================================================
# Appendix B — Platform-survival / hazard audit for frequent losers
#
# Question: do frequent-loser COBIDDERS persist on the BEC platform differently
# from other frequent losers (consistent with an exit-margin where ordinary
# losers exit after repeated losses but role-valuable losing participants
# persist)?
#
# DISCIPLINE
#  - "Survival" = continued BEC PARTICIPATION over years since first activity.
#    It is NOT legal-entity survival and does NOT prove cartel conduct.
#  - Right-censoring: firms active in 2019 (last panel year) are censored.
#  - Group status (cobidder / FL14 / direct defendant) uses FULL-SAMPLE labels,
#    so every group comparison is a DESCRIPTIVE RETROSPECTIVE survival profile,
#    NOT a timing-disciplined causal hazard. One timing-disciplined spec uses a
#    lagged to-date FL score.
#  - Direct CADE defendants reported/handled SEPARATELY (never pooled into FL).
#
# Build path: paper3-frequent-losers root, R + DuckDB.
# =============================================================================

set.seed(20260603L)

suppressMessages({
  library(duckdb); library(DBI); library(data.table)
  library(survival); library(ggplot2); library(sandwich); library(lmtest)
})

t0 <- Sys.time()
host <- Sys.info()[["nodename"]]
cat(sprintf("[telemetry] host=%s start=%s seed=20260603\n",
            host, format(t0, "%Y-%m-%d %H:%M:%S")))
cat(sprintf("[telemetry] survival=%s data.table=%s duckdb=%s ggplot2=%s\n",
            packageVersion("survival"), packageVersion("data.table"),
            packageVersion("duckdb"), packageVersion("ggplot2")))

ROOT  <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
DATA  <- file.path(ROOT, "data/processed")
OUT   <- file.path(ROOT, "work/v22-editor/outputs")
DIR_CACHE <- file.path(OUT, "cache")
DIR_TAB   <- file.path(OUT, "tables/appendix")
DIR_FIG   <- file.path(OUT, "figures/appendix")
for (d in c(DIR_CACHE, DIR_TAB, DIR_FIG, file.path(OUT,"logs"))) dir.create(d, recursive=TRUE, showWarnings=FALSE)

PANEL_FIRST_YEAR <- 2009L
PANEL_LAST_YEAR  <- 2019L   # right-censoring boundary

step <- function(msg) cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), msg))
mem  <- function() cat(sprintf("[mem] RSS=%.2f GB\n",
          as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern=TRUE))/1e6))

# helper: latex escape + write a simple booktabs-style table
write_tex <- function(df, path, caption, label, digits=3) {
  num <- sapply(df, is.numeric)
  d <- df
  for (j in which(num)) d[[j]] <- formatC(d[[j]], format="f", digits=digits, big.mark="")
  d[] <- lapply(d, function(x){ x <- as.character(x)
                                x <- gsub("([_%&#])","\\\\\\1", x)
                                x <- gsub("NA","--", x); x })
  hdr <- gsub("([_%&#])","\\\\\\1", names(df))
  con <- file(path, "w")
  writeLines(c(
    "\\begin{table}[htbp]\\centering",
    sprintf("\\caption{%s}", caption),
    sprintf("\\label{%s}", label),
    sprintf("\\begin{tabular}{%s}", paste(rep("l", ncol(df)), collapse="")),
    "\\toprule",
    paste(hdr, collapse=" & "), "\\\\ \\midrule"
  ), con)
  for (i in seq_len(nrow(d)))
    writeLines(paste(paste(unlist(d[i,]), collapse=" & "), "\\\\"), con)
  writeLines(c("\\bottomrule","\\end{tabular}","\\end{table}"), con)
  close(con)
}

# =============================================================================
# STEP 0 — labels: always-loser universe, FL14, cobidders, direct defendants
# =============================================================================
step("STEP 0: load firm-level labels")

fp <- as.data.table(read_parquet_tbl <- {
  con <- dbConnect(duckdb())
  x <- dbGetQuery(con, sprintf(
    "SELECT códigofornecedor AS cf, tenders_count, always_loser
       FROM read_parquet('%s/FREQ_PARTICIP_rebuilt.parquet')", DATA))
  dbDisconnect(con, shutdown=TRUE); x
})
fp[, cf := sprintf("%014.0f", as.numeric(cf))]
fp[, always_loser := as.integer(always_loser)]
fp[, FL14 := as.integer(tenders_count >= 14L)]
stopifnot(all(fp$always_loser == 1L))   # universe is the 16,843 always-losers
cat(sprintf("[labels] always-loser universe N=%d ; FL14 N=%d\n",
            nrow(fp), sum(fp$FL14)))

cob <- fread(file.path(DATA, "cade_fl_cobidders.csv"), colClasses="character")
cob[, cf := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobidders <- unique(cob$cf)
cat(sprintf("[labels] CADE FL cobidders N=%d\n", length(cobidders)))

cm <- fread(file.path(DATA, "cade_bec_crossmatch.csv"), colClasses="character")
cm[, cf := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_defendants <- unique(cm$cf)
LARGEST_CASE <- "08700.004617/2013-41"   # trens_metros, 16 defendants (largest by count)
big_case_defendants <- unique(cm[processo == LARGEST_CASE, cf])
cat(sprintf("[labels] direct CADE defendants N=%d ; largest-case defendants N=%d\n",
            length(direct_defendants), length(big_case_defendants)))

fp[, cobidder         := as.integer(cf %in% cobidders)]
fp[, direct_defendant := as.integer(cf %in% direct_defendants)]

# Cobidders that are ALSO direct defendants are reported separately, not as cobidders.
fp[direct_defendant == 1L, cobidder := 0L]

# group (full-sample / retrospective): primary = FL cobidder vs FL non-cobidder;
#   secondary = FL vs non-FL among always-losers; defendants separate.
fp[, group := fifelse(direct_defendant == 1L, "direct_defendant",
               fifelse(FL14 == 1L & cobidder == 1L, "FL_cobidder",
                fifelse(FL14 == 1L & cobidder == 0L, "FL_noncobidder",
                                                     "nonFL_alwaysloser")))]
cat("[labels] group counts (full-sample, retrospective):\n")
print(fp[, .N, by=group][order(-N)])

# =============================================================================
# STEP 7 — Firm-year survival panel
# =============================================================================
step("STEP 7: build firm-year participation panel (DuckDB)")

con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")
dbWriteTable(con, "univ", data.frame(cf = fp$cf), overwrite=TRUE)

# firm x year participations + wins, restricted to always-loser universe
fy <- dbGetQuery(con, sprintf("
  SELECT m.cf AS cf,
         CAST(SUBSTR(m.numerodaoc,12,4) AS INTEGER) AS year,
         COUNT(*)            AS participations_it,
         SUM(CAST(m.won AS INTEGER)) AS wins_it
  FROM (
    SELECT printf('%%014.0f', CAST(códigofornecedor AS DOUBLE)) AS cf,
           numerodaoc, won
    FROM read_parquet('%s/firm_tender_map.parquet')
  ) m
  JOIN univ u ON u.cf = m.cf
  WHERE CAST(SUBSTR(m.numerodaoc,12,4) AS INTEGER) BETWEEN %d AND %d
  GROUP BY 1,2", DATA, PANEL_FIRST_YEAR, PANEL_LAST_YEAR))
dbDisconnect(con, shutdown=TRUE)

setDT(fy)
fy[, wins_it := as.integer(wins_it)]
cat(sprintf("[panel] observed active firm-years=%d ; firms with activity=%d\n",
            nrow(fy), uniqueN(fy$cf)))
mem()

# Some universe firms may have zero rows in the 2009-2019 firm_tender_map (year
# parse / coverage). Keep panel to firms that have >=1 active year (survival is
# undefined for never-active firms). Report the drop.
active_firms <- unique(fy$cf)
dropped <- setdiff(fp$cf, active_firms)
cat(sprintf("[panel] universe firms with NO active firm-year in panel (dropped): %d\n",
            length(dropped)))

# Build a balanced firm x year grid over each firm's first..last active span?
# We need first_year_active / last_year_active to define exit. Build a full
# 2009-2019 grid per active firm so cumulative + active_years_to_date are exact.
grid <- CJ(cf = active_firms, year = PANEL_FIRST_YEAR:PANEL_LAST_YEAR)
panel <- merge(grid, fy, by=c("cf","year"), all.x=TRUE)
panel[is.na(participations_it), participations_it := 0L]
panel[is.na(wins_it),           wins_it := 0L]
panel[, active_it := as.integer(participations_it > 0L)]

setorder(panel, cf, year)
panel[, cumulative_participations_to_date := cumsum(participations_it), by=cf]
panel[, cumulative_wins_to_date           := cumsum(wins_it),           by=cf]
panel[, zero_win_to_date    := as.integer(cumulative_wins_to_date == 0L)]
panel[, score_to_date       := log1p(cumulative_participations_to_date)]
panel[, active_years_to_date := cumsum(active_it), by=cf]

# first/last active year (firm-level, full-sample within panel)
firstlast <- panel[active_it == 1L, .(first_year_active = min(year),
                                      last_year_active  = max(year)), by=cf]
panel <- merge(panel, firstlast, by="cf", all.x=TRUE)

# restrict the panel to a firm's life: from first_year_active onward (firm is
# "at risk" only after it appears). Years before first activity are not at risk.
panel <- panel[year >= first_year_active]

# merge firm-level labels
panel <- merge(panel, fp[, .(cf, tenders_count, FL14, cobidder, direct_defendant, group)],
               by="cf", all.x=TRUE)

# cohort = first_year_active
panel[, cohort := first_year_active]

# to-date FL flag (TIMING-DISCIPLINED, lagged): firm is "FL to date" once its
# cumulative participations reach 14, using only information up to year t-1.
panel[, cum_part_lag := shift(cumulative_participations_to_date, 1L, fill=0L), by=cf]
panel[, FL14_todate_lag := as.integer(cum_part_lag >= 14L)]

cat(sprintf("[panel] final panel firm-years=%d ; firms=%d ; years %d-%d\n",
            nrow(panel), uniqueN(panel$cf), PANEL_FIRST_YEAR, PANEL_LAST_YEAR))

fwrite(panel, file.path(DIR_CACHE, "firm_year_survival_panel.csv"))
step("STEP 7 done -> outputs/cache/firm_year_survival_panel.csv")
mem()

# =============================================================================
# STEP 8 — Exit + right-censoring (multiple definitions)
# =============================================================================
step("STEP 8: exit-event definitions + right-censoring")

# firm-level duration & censoring (baseline)
panel <- as.data.table(as.data.frame(panel))   # rebuild clean data.table (guard against invalid selfref)
fl <- unique(panel[, c("cf","first_year_active","last_year_active"), with=FALSE], by="cf")
fl <- setDT(as.data.frame(fl))   # fresh data.table for by-reference :=
fl[, platform_duration := last_year_active - first_year_active + 1L]
# BASELINE exit: event iff last active year < 2019 (else right-censored at 2019)
fl[, censored := as.integer(last_year_active == PANEL_LAST_YEAR)]
fl[, exit_event := 1L - censored]
fl[, exit_year := fifelse(exit_event == 1L, last_year_active, NA_integer_)]
fl <- merge(fl, fp[, .(cf, FL14, cobidder, direct_defendant, group)], by="cf", all.x=TRUE)

# ---- discrete-time exit hazard panel (BASELINE) ----
# risk set: active firm-years not previously exited. A firm is "at risk" each
# active year. exit_event_it = 1 in its last active year IF that year < 2019.
# We model exit on the firm's ACTIVE years (the spell of activity), censoring at
# 2019. Inactive interior gap-years are intermittent participation, not exit
# under the baseline (last-year) definition.
haz_base <- panel[active_it == 1L]   # already carries first/last_year_active
haz_base <- merge(haz_base, fl[, .(cf, censored)], by="cf", all.x=TRUE)
haz_base[, exit_event_it := as.integer(year == last_year_active & censored == 0L)]
# drop the censored firms' final year as a non-event still in risk set (correct:
# they are at risk in 2019 but do not exit -> exit_event_it=0). Keep them.

# ---- ALT exit definitions for sensitivity (firm-level event/censor accounting) ----
# Def A (baseline): last active year < 2019.
# Def B (1-year inactivity): exit at first year t where active_t=1 & active_{t+1}=0,
#        requires observing t+1; firms whose only inactivity is the 2019 boundary
#        are censored; look-ahead excludes the last panel year (2019) from events.
# Def C (2-year inactivity): exit needs active_t & inactive_{t+1} & inactive_{t+2};
#        events only definable up to t<=2017 (look-ahead 2 yrs); 2018-2019 excluded.
exit_def_summary <- function() {
  out <- list()
  # Def A
  out[["A_last_active_lt_2019"]] <- list(
    risk = uniqueN(fl$cf),
    events = sum(fl$exit_event),
    censored = sum(fl$censored),
    yrs_excluded = "none (censor at 2019)")
  # Build active matrix for B/C
  setorder(panel, cf, year)
  p <- copy(panel)
  p[, active_next  := shift(active_it, 1L, type="lead"), by=cf]
  p[, active_next2 := shift(active_it, 2L, type="lead"), by=cf]
  # Def B: first active year with active_next==0 and year<=2018 (need year+1 observed)
  pb <- p[active_it == 1L & year <= (PANEL_LAST_YEAR-1L)]
  evB <- pb[active_next == 0L, .(exit_year = min(year)), by=cf]
  riskB <- uniqueN(p[active_it==1L]$cf)
  out[["B_1yr_inactivity"]] <- list(
    risk = riskB, events = nrow(evB),
    censored = riskB - nrow(evB),
    yrs_excluded = "2019 (no t+1 observed)")
  # Def C: active_t & inactive_{t+1} & inactive_{t+2}, year<=2017
  pc <- p[active_it == 1L & year <= (PANEL_LAST_YEAR-2L)]
  evC <- pc[active_next == 0L & active_next2 == 0L, .(exit_year = min(year)), by=cf]
  riskC <- uniqueN(p[active_it==1L]$cf)
  out[["C_2yr_inactivity"]] <- list(
    risk = riskC, events = nrow(evC),
    censored = riskC - nrow(evC),
    yrs_excluded = "2018-2019 (no t+1,t+2 observed)")
  list(summary = out, evB = evB, evC = evC)
}
ed <- exit_def_summary()

tabB_exit <- rbindlist(lapply(names(ed$summary), function(k){
  s <- ed$summary[[k]]
  data.table(exit_definition = k, risk_set = s$risk, events = s$events,
             censored = s$censored, years_excluded_lookahead = s$yrs_excluded)
}))
tabB_exit[, limitation :=
  "Survival = platform participation, not legal-entity survival; right-censored at 2019; full-sample group labels are retrospective/descriptive."]
fwrite(tabB_exit, file.path(DIR_TAB, "table_B_exit_definition_sensitivity.csv"))
write_tex(tabB_exit, file.path(DIR_TAB, "table_B_exit_definition_sensitivity.tex"),
  caption="Exit-event definitions, risk sets, and right-censoring (always-loser universe).",
  label="tab:B_exit_def", digits=0)
print(tabB_exit)
step("STEP 8 done")

# =============================================================================
# STEP 10 — Kaplan-Meier (descriptive retrospective)
# =============================================================================
step("STEP 10: Kaplan-Meier survival curves")

# KM on platform duration; event = exit (baseline), censor at 2019.
# Groups = FL_cobidder / FL_noncobidder / nonFL_alwaysloser. Defendants excluded
# from KM (reported separately).
km_dat <- fl[group != "direct_defendant"]
km_dat[, grp := factor(group, levels=c("FL_cobidder","FL_noncobidder","nonFL_alwaysloser"))]
surv_obj <- Surv(time = km_dat$platform_duration, event = km_dat$exit_event)
km_fit <- survfit(surv_obj ~ grp, data = km_dat)
km_med <- summary(km_fit)$table
cat("[KM] median platform durations + n:\n"); print(km_med[, c("records","events","median")])
lr <- survdiff(surv_obj ~ grp, data = km_dat)
lr_chisq <- lr$chisq
lr_df <- length(lr$n) - 1L
lr_p <- pchisq(lr_chisq, df=lr_df, lower.tail=FALSE)
cat(sprintf("[KM] log-rank chisq=%.3f df=%d p=%.3e\n", lr_chisq, lr_df, lr_p))

# tidy KM steps for ggplot
km_df <- data.table(
  time    = km_fit$time,
  surv    = km_fit$surv,
  lower   = km_fit$lower,
  upper   = km_fit$upper,
  strata  = rep(names(km_fit$strata), km_fit$strata))
km_df[, group := gsub("grp=", "", strata)]
lab_map <- c(FL_cobidder="FL cobidders (CADE-linked)",
             FL_noncobidder="FL non-cobidders",
             nonFL_alwaysloser="Non-FL always-losers")
km_df[, glab := lab_map[group]]

p <- ggplot(km_df, aes(x=time, y=surv, color=glab, fill=glab)) +
  geom_step(linewidth=0.9) +
  geom_ribbon(aes(ymin=lower, ymax=upper), alpha=0.12, color=NA) +
  scale_x_continuous(breaks=1:11, name="Years since first BEC activity") +
  scale_y_continuous(limits=c(0,1), name="Share still participating (KM survival)") +
  labs(color=NULL, fill=NULL,
       title="Platform participation survival of always-loser firms",
       subtitle=sprintf("Right-censored at 2019. Log-rank p=%.2e. Full-sample group labels are descriptive/retrospective.\nSurvival = continued BEC participation, NOT legal-entity survival; does not prove cartel conduct.", lr_p)) +
  theme_minimal(base_size=11) +
  theme(legend.position="bottom", plot.subtitle=element_text(size=8))

ggsave(file.path(DIR_FIG, "fig_B_survival_curves_frequent_losers.pdf"),
       p, width=7.5, height=5.2, device=cairo_pdf)
step("STEP 10 done -> figures/appendix/fig_B_survival_curves_frequent_losers.pdf")

# =============================================================================
# STEP 11 — Discrete-time exit hazard (cloglog) — BASELINE
# =============================================================================
step("STEP 11: discrete-time hazard (cloglog)")

H <- copy(haz_base)
H[, year_f   := factor(year)]
# duration since first activity = the discrete-time BASELINE HAZARD shape.
# NOTE: cohort = year - duration + 1, so {duration, year} already spans cohort;
# adding a separate cohort FE causes quasi-complete separation on the
# last-year-exit outcome. We therefore use duration FE + calendar-year FE.
H[, dur := year - first_year_active + 1L]
H[, dur_f := factor(dur)]
# group dummies (defendants excluded from main hazard; reported separately)
H[, FL_cobidder    := as.integer(group == "FL_cobidder")]
H[, FL_noncobidder := as.integer(group == "FL_noncobidder")]
H[, is_defendant   := as.integer(group == "direct_defendant")]
Hm <- H[is_defendant == 0L]   # main hazard sample: 3 groups, defendants out
cat(sprintf("[hazard] main risk-set firm-years=%d ; firms=%d ; events=%d\n",
            nrow(Hm), uniqueN(Hm$cf), sum(Hm$exit_event_it)))

# cloglog discrete-time hazard. Baseline category = nonFL_alwaysloser.
# Baseline hazard = duration FE (dur_f) + calendar-year FE (year_f).
# NOTE: cumulative_participations_to_date is INTENTIONALLY excluded from the
# cloglog: under the baseline "last-active-year = exit" outcome it grows
# monotonically with survival and induces (quasi-)complete separation
# (divergent coefficients). The duration FE (dur_f) already absorbs the tenure
# baseline. We therefore report cloglog with {dur_f, year_f} as the baseline
# hazard, and the LPM below (which is robust to separation) additionally
# includes cumulative_participations_to_date as a transparency check.
fit_cll <- glm(exit_event_it ~ FL_cobidder + FL_noncobidder + dur_f + year_f,
               family = binomial(link = "cloglog"), data = Hm,
               control = list(maxit = 100))
cat(sprintf("[hazard] cloglog converged=%s\n", fit_cll$converged))
# firm-clustered SE
vc <- sandwich::vcovCL(fit_cll, cluster = Hm$cf)
ct <- lmtest::coeftest(fit_cll, vcov. = vc)

key <- c("FL_cobidder","FL_noncobidder")
haz_tab <- data.table(
  term   = key,
  coef   = ct[key, "Estimate"],
  se     = ct[key, "Std. Error"],
  z      = ct[key, "z value"],
  p      = ct[key, "Pr(>|z|)"],
  hazard_ratio = exp(ct[key, "Estimate"]))   # cloglog: exp(coef) ~ hazard ratio
haz_tab[, N_firm_years := nrow(Hm)]
haz_tab[, N_firms      := uniqueN(Hm$cf)]
haz_tab[, N_events     := sum(Hm$exit_event_it)]
haz_tab[, model        := "cloglog discrete-time (dur+year FE), firm-clustered SE"]
cat("[hazard] cloglog key coefficients (firm-clustered):\n"); print(haz_tab[, .(term,coef,se,z,p,hazard_ratio)])

# LPM robustness (separation-proof; adds cumulative participations as control)
fit_lpm <- lm(exit_event_it ~ FL_cobidder + FL_noncobidder +
                cumulative_participations_to_date + dur_f + year_f, data = Hm)
vc_lpm <- sandwich::vcovCL(fit_lpm, cluster = Hm$cf)
ct_lpm <- lmtest::coeftest(fit_lpm, vcov. = vc_lpm)
lpm_tab <- data.table(term=key, coef=ct_lpm[key,"Estimate"], se=ct_lpm[key,"Std. Error"],
                      p=ct_lpm[key,"Pr(>|t|)"],
                      hazard_ratio=NA_real_, model="LPM (incl. cum. participations), firm-clustered")
cat("[hazard] LPM key coefficients (firm-clustered):\n"); print(lpm_tab)

# TIMING-DISCIPLINED spec: replace full-sample FL/cobidder with lagged to-date FL.
# (cobidder identity is intrinsically full-sample; here we discipline the FL margin.)
fit_td <- glm(exit_event_it ~ FL14_todate_lag + dur_f + year_f,
              family = binomial(link="cloglog"), data = Hm,
              control = list(maxit = 100))
vc_td <- sandwich::vcovCL(fit_td, cluster = Hm$cf)
ct_td <- lmtest::coeftest(fit_td, vcov.=vc_td)
td_tab <- data.table(term="FL14_todate_lag",
                     coef=ct_td["FL14_todate_lag","Estimate"],
                     se=ct_td["FL14_todate_lag","Std. Error"],
                     p=ct_td["FL14_todate_lag","Pr(>|z|)"],
                     hazard_ratio=exp(ct_td["FL14_todate_lag","Estimate"]),
                     model="cloglog timing-disciplined (lagged to-date FL)")

haz_out <- rbind(
  haz_tab[, .(term, coef, se, z, p, hazard_ratio, N_firm_years, N_firms, N_events, model)],
  lpm_tab[, .(term, coef, se, z=NA_real_, p, hazard_ratio,
              N_firm_years=nrow(Hm), N_firms=uniqueN(Hm$cf),
              N_events=sum(Hm$exit_event_it), model)],
  td_tab[, .(term, coef, se, z=NA_real_, p, hazard_ratio,
             N_firm_years=nrow(Hm), N_firms=uniqueN(Hm$cf),
             N_events=sum(Hm$exit_event_it), model)],
  fill=TRUE)
haz_out[, interpretation := fifelse(grepl("cobidder|todate", term) & coef < 0,
          "HR<1: lower exit hazard -> persists longer (supports exit-margin)",
          fifelse(grepl("cobidder|todate", term) & coef > 0,
          "HR>1: higher exit hazard -> exits faster (contradicts exit-margin)", ""))]
fwrite(haz_out, file.path(DIR_TAB, "table_B_discrete_time_hazard.csv"))
write_tex(haz_out[, .(term, coef, se, p, hazard_ratio, N_firm_years, N_firms, N_events)],
  file.path(DIR_TAB, "table_B_discrete_time_hazard.tex"),
  caption="Discrete-time exit hazard (cloglog), always-loser universe. Lower hazard ratio for FL cobidders supports the persistence/exit-margin mechanism. Firm-clustered SE.",
  label="tab:B_hazard", digits=3)
step("STEP 11 done -> tables/appendix/table_B_discrete_time_hazard.{csv,tex}")

# =============================================================================
# STEP 12 — Cox proportional-hazards (duration model) + PH check
# =============================================================================
step("STEP 12: Cox PH model")
cox_dat <- km_dat   # 3 groups, defendants excluded
cox_dat[, grp := relevel(factor(group), ref="nonFL_alwaysloser")]
cox_fit <- coxph(Surv(platform_duration, exit_event) ~ grp + cohort_f2,
                 data = cox_dat[, .(platform_duration, exit_event, grp,
                                    cohort_f2 = factor(first_year_active))])
cox_sm <- summary(cox_fit)
ph <- tryCatch(cox.zph(cox_fit), error=function(e) NULL)
cox_tab <- data.table(
  term = rownames(cox_sm$coefficients),
  coef = cox_sm$coefficients[,"coef"],
  HR   = cox_sm$coefficients[,"exp(coef)"],
  se   = cox_sm$coefficients[,"se(coef)"],
  p    = cox_sm$coefficients[,"Pr(>|z|)"])
cox_tab <- cox_tab[grepl("^grp", term)]
if (!is.null(ph)) {
  ph_global_p <- ph$table["GLOBAL","p"]
  cox_tab[, PH_global_p := ph_global_p]
} else cox_tab[, PH_global_p := NA_real_]
fwrite(cox_tab, file.path(DIR_TAB, "table_B_cox_duration_model.csv"))
cat("[cox] group HRs:\n"); print(cox_tab)
step("STEP 12 done -> tables/appendix/table_B_cox_duration_model.csv")

# =============================================================================
# STEP 13 — Survival summary (THE main Appendix-B table)
# =============================================================================
step("STEP 13: survival summary table")

# baseline exit hazard per group = events / total active firm-years at risk
risk_by_grp <- H[, .(active_firm_years = .N,
                     events = sum(exit_event_it)), by=group]
risk_by_grp[, baseline_exit_hazard := events / active_firm_years]

# adjusted HR per group from cloglog (FL_cobidder, FL_noncobidder; baseline=nonFL)
adj_hr <- data.table(
  group = c("nonFL_alwaysloser","FL_noncobidder","FL_cobidder"),
  adjusted_hazard_ratio = c(1.0,
    haz_tab[term=="FL_noncobidder", hazard_ratio],
    haz_tab[term=="FL_cobidder",    hazard_ratio]))

summ <- fl[, .(N_firms = .N,
               mean_first_active_year = mean(first_year_active),
               mean_active_years      = mean(last_year_active - first_year_active + 1L),
               mean_last_active_year  = mean(last_year_active),
               exit_share_before_2019 = mean(exit_event),
               right_censored_share   = mean(censored),
               median_platform_duration = as.numeric(median(platform_duration))),
           by=group]
# mean active YEARS (distinct active years) — more honest than span; add it
act_years <- panel[active_it==1L, .(mean_distinct_active_years =
                     uniqueN(year)), by=.(cf, group)][, .(mean_distinct_active_years=mean(mean_distinct_active_years)), by=group]
summ <- merge(summ, act_years, by="group", all.x=TRUE)
summ <- merge(summ, risk_by_grp[, .(group, baseline_exit_hazard)], by="group", all.x=TRUE)
summ <- merge(summ, adj_hr, by="group", all.x=TRUE)

ord <- c("nonFL_alwaysloser","FL_noncobidder","FL_cobidder","direct_defendant")
summ[, group := factor(group, levels=ord)]
setorder(summ, group)
setcolorder(summ, c("group","N_firms","mean_first_active_year","mean_active_years",
                    "mean_distinct_active_years","mean_last_active_year",
                    "exit_share_before_2019","right_censored_share",
                    "median_platform_duration","baseline_exit_hazard",
                    "adjusted_hazard_ratio"))
fwrite(summ, file.path(DIR_TAB, "table_B_survival_summary.csv"))
write_tex(summ, file.path(DIR_TAB, "table_B_survival_summary.tex"),
  caption="Platform-participation survival summary by group (always-loser universe; direct CADE defendants reported separately). Survival = continued BEC participation; right-censored at 2019; full-sample group labels are descriptive/retrospective. Does not prove cartel conduct.",
  label="tab:B_survival_summary", digits=3)
cat("[summary] main Appendix-B table:\n"); print(summ)
step("STEP 13 done -> tables/appendix/table_B_survival_summary.{csv,tex}")

# =============================================================================
# STEP 14 — Sensitivity
# =============================================================================
step("STEP 14: sensitivity analyses")

run_hazard_hr <- function(haz_panel, label, var="FL_cobidder") {
  d <- copy(haz_panel)
  d[, year_f := factor(year)]
  d[, dur_f := factor(year - first_year_active + 1L)]
  if (uniqueN(d[[var]]) < 2L || sum(d$exit_event_it[d[[var]]==1L])==0L)
    return(data.table(scenario=label, term=var, coef=NA_real_, se=NA_real_,
                      p=NA_real_, hazard_ratio=NA_real_, N_firms=uniqueN(d$cf),
                      events=sum(d$exit_event_it), note="degenerate/no events"))
  f <- tryCatch(glm(as.formula(sprintf(
        "exit_event_it ~ %s + FL_noncobidder + dur_f + year_f", var)),
        family=binomial(link="cloglog"), data=d, control=list(maxit=100)),
        error=function(e) NULL)
  if (is.null(f)) return(data.table(scenario=label, term=var, coef=NA_real_,
        se=NA_real_, p=NA_real_, hazard_ratio=NA_real_, N_firms=uniqueN(d$cf),
        events=sum(d$exit_event_it), note="fit failed"))
  v <- tryCatch(sandwich::vcovCL(f, cluster=d$cf), error=function(e) vcov(f))
  cc <- lmtest::coeftest(f, vcov.=v)
  data.table(scenario=label, term=var, coef=cc[var,1], se=cc[var,2],
             p=cc[var,4], hazard_ratio=exp(cc[var,1]),
             N_firms=uniqueN(d$cf), events=sum(d$exit_event_it), note="")
}

sens <- list()

# S0 baseline (for reference)
sens[["baseline"]] <- run_hazard_hr(Hm, "S0_baseline")

# S1: alt exit def B (1-yr inactivity) — rebuild exit_event_it on active years
mk_haz_altdef <- function(ev_dt, lastyr_allowed) {
  d <- panel[active_it==1L]                       # already carries `group`
  d <- merge(d, ev_dt[, .(cf, exit_year)], by="cf", all.x=TRUE)
  # at-risk active years up to exit (inclusive) or end; event at exit_year
  d <- d[year <= lastyr_allowed]
  d[, exit_event_it := as.integer(!is.na(exit_year) & year == exit_year)]
  d[, FL_cobidder := as.integer(group=="FL_cobidder")]
  d[, FL_noncobidder := as.integer(group=="FL_noncobidder")]
  d[group != "direct_defendant"]
}
hB <- mk_haz_altdef(ed$evB, PANEL_LAST_YEAR-1L)
sens[["altdef_B_1yr"]] <- run_hazard_hr(hB, "S1_exitdef_1yr_inactivity")
hC <- mk_haz_altdef(ed$evC, PANEL_LAST_YEAR-2L)
sens[["altdef_C_2yr"]] <- run_hazard_hr(hC, "S2_exitdef_2yr_inactivity")

# S3: exclude late cohorts (first_active > 2016)
late_cf <- fl[first_year_active > 2016L, cf]
sens[["excl_late_cohorts"]] <- run_hazard_hr(Hm[!cf %in% late_cf], "S3_excl_late_cohorts_first>2016")

# S4: exclude largest CADE case cobidder classification.
# Reclassify cobidders whose CADE link runs ONLY through the largest case
# (08700.004617/2013-41) back to FL_noncobidder. We approximate the "largest-case
# cobidders" as cobidders that co-participated in tenders touching the largest
# case's defendants; excluding those from the cobidder group.
con <- dbConnect(duckdb()); dbExecute(con,"PRAGMA threads=12")
dbWriteTable(con,"bigdef", data.frame(cf=big_case_defendants), overwrite=TRUE)
big_tenders <- dbGetQuery(con, sprintf("
  SELECT DISTINCT numerodaoc FROM read_parquet('%s/firm_tender_map.parquet')
  WHERE printf('%%014.0f', CAST(códigofornecedor AS DOUBLE)) IN (SELECT cf FROM bigdef)", DATA))
dbWriteTable(con,"bigt", big_tenders, overwrite=TRUE)
cob_bigcase <- dbGetQuery(con, sprintf("
  SELECT DISTINCT printf('%%014.0f', CAST(códigofornecedor AS DOUBLE)) AS cf
  FROM read_parquet('%s/firm_tender_map.parquet') m
  JOIN bigt t ON t.numerodaoc = m.numerodaoc", DATA))$cf
dbDisconnect(con, shutdown=TRUE)
cob_bigcase <- intersect(cob_bigcase, cobidders)
cat(sprintf("[sens] cobidders linked to largest case (reclassified): %d of %d\n",
            length(cob_bigcase), length(cobidders)))
Hm_excl <- copy(Hm)
Hm_excl[cf %in% cob_bigcase & group=="FL_cobidder",
        `:=`(group="FL_noncobidder", FL_cobidder=0L, FL_noncobidder=1L)]
sens[["excl_largest_case"]] <- run_hazard_hr(Hm_excl, "S4_excl_largest_case_cobidders")

# S5: to-date FL score instead of full-sample FL14 (timing-disciplined FL margin)
sens[["todate_FL"]] <- {
  d <- copy(Hm); d[, year_f:=factor(year)]
  d[, dur_f:=factor(year - first_year_active + 1L)]
  f <- glm(exit_event_it ~ FL14_todate_lag + dur_f + year_f,
           family=binomial(link="cloglog"), data=d, control=list(maxit=100))
  v <- sandwich::vcovCL(f, cluster=d$cf); cc <- lmtest::coeftest(f, vcov.=v)
  data.table(scenario="S5_todate_FL_margin", term="FL14_todate_lag",
             coef=cc["FL14_todate_lag",1], se=cc["FL14_todate_lag",2],
             p=cc["FL14_todate_lag",4], hazard_ratio=exp(cc["FL14_todate_lag",1]),
             N_firms=uniqueN(d$cf), events=sum(d$exit_event_it), note="")
}

sens_tab <- rbindlist(sens, fill=TRUE)
fwrite(sens_tab, file.path(DIR_TAB, "table_B_survival_sensitivity.csv"))
cat("[sensitivity]:\n"); print(sens_tab)
step("STEP 14 done -> tables/appendix/table_B_survival_sensitivity.csv")

# =============================================================================
# WRAP
# =============================================================================
fl_cob_hr  <- haz_tab[term=="FL_cobidder", hazard_ratio]
fl_cob_p   <- haz_tab[term=="FL_cobidder", p]
fl_cob_co  <- haz_tab[term=="FL_cobidder", coef]
verdict <- if (is.na(fl_cob_p)) "C" else if (fl_cob_co < 0 & fl_cob_p < 0.10) "A" else
           if (fl_cob_co > 0 & fl_cob_p < 0.10) "E" else "B"
cat(sprintf("\n[VERDICT] FL_cobidder cloglog coef=%.4f HR=%.4f p=%.3g -> %s\n",
            fl_cob_co, fl_cob_hr, fl_cob_p, verdict))
cat(sprintf("[telemetry] total runtime=%.1f min\n",
            as.numeric(difftime(Sys.time(), t0, units="mins"))))
mem()
step("ALL DONE")
