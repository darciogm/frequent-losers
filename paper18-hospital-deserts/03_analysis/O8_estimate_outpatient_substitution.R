#!/usr/bin/env Rscript
# O8_estimate_outpatient_substitution.R
#
# Sun-Abraham event studies on OUTPATIENT mental-health production, on the SAME
# PNASH psychiatric causal sample / g_emb / event-time support as the headline
# inpatient script (75_psych_admissions_result.R). Asks the referee's question:
# after a PNASH psychiatric closure, does community/outpatient MH production rise
# enough to offset the ~69% inpatient admissions decline?
#
# ====================== INTERPRETATION GUARDRAILS ==========================
# These estimates are OUTPATIENT PRODUCTION, not patient-level substitution. We
# observe administrative procedure/action counts by municipality, not whether a
# specific displaced inpatient received outpatient care. Two bases are reported:
#   - basis = 'residence' : production attributed to the patient's municipality
#                           of residence (the only basis that can speak, weakly,
#                           to substitution for the exposed population).
#   - basis = 'provider'  : production attributed to the providing municipality
#                           (a supply/location measure). NEVER read provider-basis
#                           as patient-level substitution.
# If pre-trends fail (joint pre-period p < 0.10) the estimate is NOT causal -- the
# script emits a WARNING and the result is flagged. If production rises, we report
# the ratio of the outpatient ATT to the inpatient psych_adm decline on a common
# per-1k procedure scale, with heavy caveats (different units of care, no patient
# linkage). If nothing rises, we state plainly: no outpatient offset detected in
# these administrative measures.
# ===========================================================================
#
# Estimator contract (matches 75_psych_admissions_result.R / 86_caps_heterogeneity.R):
#   feols(y ~ sunab(gn, year) | muni_id + year, cluster = "muni_id", weights = ~pop)
#   never-treated (g_emb == 0 | NA) recoded to sentinel 10000 before sunab().
#   Event window for plots e in [-7, +8]. Pandemic years (2020-2021) included by
#   default; a pandemic-excluded robustness variant is also estimated.
#
# Outputs:
#   01_manuscript/tables_appendix/table_outpatient_substitution_eventstudy.tex
#   04_figures_appendix/fig_outpatient_substitution_eventstudy.pdf
#   02_data/processed/outpatient_mental_health/outpatient_substitution_results.csv
#   04_logs/outpatient/outpatient_substitution_<YYYYMMDD>.log
#
# Usage: Rscript 03_analysis/O8_estimate_outpatient_substitution.R [--force]

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(ggplot2)
})
setFixest_nthreads(4); setDTthreads(4)

args <- commandArgs(trailingOnly = FALSE)
trailing <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% trailing
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())

INTER  <- file.path(ROOT, "02_data", "intermediate")
PROC   <- file.path(ROOT, "02_data", "processed")
OMHDIR <- file.path(PROC, "outpatient_mental_health")
APPDX  <- file.path(ROOT, "01_manuscript", "tables_appendix")
FIGA   <- file.path(ROOT, "04_figures_appendix")
LOGDIR <- file.path(ROOT, "04_logs", "outpatient")
for (d in c(OMHDIR, APPDX, FIGA, LOGDIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

STAMP   <- format(Sys.time(), "%Y%m%d")
LOGF    <- file.path(LOGDIR, sprintf("outpatient_substitution_%s.log", STAMP))
OUT_CSV <- file.path(OMHDIR, "outpatient_substitution_results.csv")
OUT_TEX <- file.path(APPDX, "table_outpatient_substitution_eventstudy.tex")
OUT_FIG <- file.path(FIGA, "fig_outpatient_substitution_eventstudy.pdf")

sink(LOGF, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
say <- function(...) cat(sprintf(...), "\n")

say("=== telemetry ===")
say("script: 03_analysis/O8_estimate_outpatient_substitution.R")
say("started: %s", format(started, "%Y-%m-%d %H:%M:%S %Z"))
say("hostname: %s | R: %s", Sys.info()[["nodename"]], R.version.string)
say("fixest_nthreads: 4 | dt_threads: 4")
say("=================")

# --------------------------------------------------------------------------
# Defensive input handling: the upstream outpatient panel may not exist yet.
# Missing input -> log + quit(status = 0). Never fabricate results.
# --------------------------------------------------------------------------
PANEL    <- file.path(OMHDIR, "catchment_outpatient_event_panel.parquet")
RES_ALT  <- file.path(OMHDIR, "outpatient_mh_municipality_year.parquet")           # residence
PROV_ALT <- file.path(OMHDIR, "outpatient_mh_provider_municipality_year.parquet")  # provider

if (!file.exists(PANEL)) {
  say("MISSING INPUT: %s", PANEL)
  if (file.exists(RES_ALT) || file.exists(PROV_ALT))
    say("note: alternate municipality-year files exist but the assembled event panel is required; build it upstream first.")
  say("Outpatient event panel not produced upstream yet -> nothing to estimate.")
  say("Quitting gracefully (status 0). Re-run after the upstream panel is built.")
  quit(save = "no", status = 0)
}

if (file.exists(OUT_CSV) && file.exists(OUT_TEX) && file.exists(OUT_FIG) && !force) {
  say("outputs exist, skipping (use --force)")
  quit(save = "no", status = 0)
}

# --------------------------------------------------------------------------
# Load panel
# --------------------------------------------------------------------------
d <- as.data.table(read_parquet(PANEL))
say("panel rows: %d  cols: %s", nrow(d), paste(names(d), collapse = ", "))

# muni_id may be absent -> create as .GRP over codmun_6 (stable per the contract).
if (!"muni_id" %in% names(d)) {
  d[, codmun_6 := as.character(codmun_6)]
  setorder(d, codmun_6)
  d[, muni_id := .GRP, by = codmun_6]
  say("muni_id absent -> created as .GRP over codmun_6")
}
# never-treated recode (exactly as 24b / 75 / 86): g_emb == 0 | NA -> sentinel 10000.
d[, gn := fifelse(is.na(g_emb) | g_emb == 0L, 10000L, as.integer(g_emb))]
if (!"pandemic" %in% names(d)) {
  d[, pandemic := year %in% c(2020L, 2021L)]
  say("pandemic flag absent -> derived as year in {2020,2021}")
}

# file-families provenance + SIGTAP-pending outcome set: prefer an in-panel
# 'families' column; otherwise read the build sidecar. The sidecar is the
# long-format outpatient_mh_panel_summary.csv (section,key,value) emitted by the
# upstream builder -- it carries 'families_used' (e.g. "sia_pa|raas_ps") and
# 'sigtap_pending_outcomes' (the fine MH categories that are intentionally zero
# offline until SIGTAP procedure descriptions land). We read both from it so the
# results rows can be labelled without hand-coding.
fam_col <- intersect(c("file_families", "families", "family"), names(d))
sigtap_pending <- character(0)  # outcome stems known-zero offline (SIGTAP later)
if (length(fam_col)) {
  families_str <- paste(sort(unique(na.omit(as.character(d[[fam_col[1]]])))), collapse = "|")
} else {
  families_str <- "unknown"
  # accept either the current panel summary or the legacy build-summary name.
  sm <- Filter(file.exists, file.path(OMHDIR,
        c("outpatient_mh_panel_summary.csv", "outpatient_mh_build_summary.csv")))
  if (length(sm)) {
    # the summary is two stacked sections separated by a blank line; fill=TRUE +
    # blank.lines.skip keeps fread from stopping early at the section break.
    s <- tryCatch(fread(sm[1], fill = TRUE, blank.lines.skip = TRUE),
                  error = function(e) NULL)
    if (!is.null(s)) {
      # long format (section,key,value): pull keys directly.
      if (all(c("key", "value") %in% names(s))) {
        kv <- function(k) { v <- s[key == k, value]; if (length(v)) v[1] else NA_character_ }
        fv <- kv("families_used"); if (is.na(fv)) fv <- kv("residence_eligible_families")
        if (!is.na(fv)) families_str <- fv
        sp <- kv("sigtap_pending_outcomes")
        if (!is.na(sp)) sigtap_pending <- trimws(strsplit(sp, "[|]")[[1]])
      } else if ("families" %in% names(s)) {  # wide/legacy fallback
        families_str <- paste(unique(s$families), collapse = "|")
      }
    }
  }
}
say("file families: %s", families_str)
say("SIGTAP-pending (known-zero offline) outcome stems: %s",
    if (length(sigtap_pending)) paste(sigtap_pending, collapse = ", ") else "(none declared)")

# --------------------------------------------------------------------------
# Outcomes to estimate (graceful skip of any absent column).
# --------------------------------------------------------------------------
outcome_label <- c(
  outpatient_mh_procedures_per1k     = "Outpatient MH procedures (per 1k)",
  caps_procedures_per1k              = "CAPS procedures (per 1k)",
  raas_psychosocial_actions_per1k    = "RAAS psychosocial actions (per 1k)",
  psychiatric_consults_per1k         = "Psychiatric consultations (per 1k)",
  mh_value_per_capita                = "MH spending (per capita)",
  n_mh_caps_providers                = "MH/CAPS providers (count)"
)
# Tolerate plausible upstream naming variants for the headline procedures column.
# Order matters: the populated 'total_mh_procedures_per1k' must win over absent
# variants so the headline outcome is actually estimated.
proc_aliases <- c("outpatient_mh_procedures_per1k", "total_mh_procedures_per1k",
                  "outpatient_mh_proc_per1k", "outpatient_procedures_per1k",
                  "mh_procedures_per1k")
if (!"outpatient_mh_procedures_per1k" %in% names(d)) {
  hit <- intersect(proc_aliases, names(d))
  if (length(hit)) { setnames(d, hit[1], "outpatient_mh_procedures_per1k"); say("aliased %s -> outpatient_mh_procedures_per1k", hit[1]) }
}
# Provider count: prefer the populated 'n_cnes_mh_providers' over 'n_caps_providers'
# (the latter is intentionally zero offline, SIGTAP-pending). Order reflects that.
prov_aliases <- c("n_mh_caps_providers", "n_cnes_mh_providers", "n_mh_providers",
                  "mh_caps_providers", "n_caps_providers")
if (!"n_mh_caps_providers" %in% names(d)) {
  hit <- intersect(prov_aliases, names(d))
  if (length(hit)) { setnames(d, hit[1], "n_mh_caps_providers"); say("aliased %s -> n_mh_caps_providers", hit[1]) }
}
outcomes <- intersect(names(outcome_label), names(d))
if (!length(outcomes)) {
  say("MISSING: none of the expected outcome columns present in the panel -> nothing to estimate.")
  quit(save = "no", status = 0)
}
say("estimating outcomes: %s", paste(outcomes, collapse = ", "))

# inpatient comparator (for the offset ratio), if carried in the panel.
has_inpatient <- "psych_adm_per1k" %in% names(d)
say("inpatient comparator (psych_adm_per1k) in panel: %s", has_inpatient)

# bases present
bases <- if ("basis" %in% names(d)) intersect(c("residence", "provider"), unique(as.character(d$basis))) else "residence"
if (!"basis" %in% names(d)) { d[, basis := "residence"]; say("basis column absent -> assuming single 'residence' basis") }
say("bases: %s", paste(bases, collapse = ", "))

# Map an outcome column (possibly aliased) back to its build-summary stem so we
# can tell a SIGTAP-pending fine category from a generic no-variation outcome.
# n_mh_caps_providers is the aliased name for n_caps_providers (SIGTAP-pending);
# outpatient_mh_procedures_per1k aliases total_mh_procedures_per1k (populated).
outcome_stem <- function(yn) {
  stem <- sub("_per1k$|_per_capita$", "", yn)
  if (yn == "n_mh_caps_providers") stem <- "n_caps_providers"  # alias -> build stem
  stem
}
is_sigtap_pending <- function(yn) outcome_stem(yn) %in% sigtap_pending

# Pre-feols variation guard. feols on a constant/zero dependent variable throws
# "The dependent variable is a constant ...". We detect that BEFORE estimating so
# we can emit a clean, single, typed status row instead of leaking the raw error.
# Returns: a list with $constant (logical) and $reason ("all_zero" | "constant" |
# "ok"), evaluated on the estimation sample (finite outcome, valid pop weight).
variation_guard <- function(dt, yn) {
  v <- dt[is.finite(get(yn)) & is.finite(pop) & pop > 0, get(yn)]
  if (!length(v)) return(list(constant = TRUE, reason = "constant"))
  if (all(v == 0)) return(list(constant = TRUE, reason = "all_zero"))
  if (length(unique(v)) <= 1L) return(list(constant = TRUE, reason = "constant"))
  list(constant = FALSE, reason = "ok")
}

# Year span of an outcome's estimation sample (finite outcome, valid pop weight),
# available even when feols is not run -- used to populate `years` on every row.
sample_year_span <- function(dt, yn) {
  yr <- dt[is.finite(get(yn)) & is.finite(pop) & pop > 0, year]
  if (!length(yr)) return(NA_character_)
  rg <- range(yr, na.rm = TRUE); sprintf("%d-%d", rg[1], rg[2])
}

# --------------------------------------------------------------------------
# Core Sun-Abraham estimator (mirrors 75_psych_admissions_result.R::est_full).
#   - pop-weighted by default (wt = TRUE); unweighted variant available.
#   - ATT = post-average of the SA event coefficients (agg = "att").
#   - pre-trend p = joint chi-sq test of pre-period leads e in [-6, -2] == 0
#     (e = -1 is the omitted reference; matches the headline pre-window).
#   - baseline = pop-weighted pre-period level among treated munis (year < gn).
# --------------------------------------------------------------------------
est_sa <- function(dt, yn, wt = TRUE, drop_pandemic = FALSE) {
  d2 <- copy(dt)
  if (drop_pandemic) d2 <- d2[pandemic == FALSE]
  d2 <- d2[is.finite(get(yn)) & (!wt | (is.finite(pop) & pop > 0))]
  n_tr <- d2[gn < 10000, uniqueN(muni_id)]
  if (n_tr < 3 || d2[gn == 10000, uniqueN(muni_id)] < 1)
    return(list(ok = FALSE, n_treated = n_tr, msg = "too few treated/controls"))
  w <- if (wt) d2$pop else NULL
  m <- tryCatch(
    feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
          d2, cluster = "muni_id", weights = w, warn = FALSE, notes = FALSE),
    error = function(e) e)
  if (inherits(m, "error")) return(list(ok = FALSE, n_treated = n_tr, msg = conditionMessage(m)))
  agg <- tryCatch(summary(m, agg = "att"), error = function(e) e)
  if (inherits(agg, "error")) return(list(ok = FALSE, n_treated = n_tr, msg = conditionMessage(agg)))
  att <- as.numeric(coef(agg)[1]); se <- as.numeric(se(agg)[1])

  cf <- coef(m); s <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]

  pre <- es[e <= -2 & e >= -6]
  if (nrow(pre) > 0) { W <- sum((pre$cf / pre$se)^2); pretrend_p <- 1 - pchisq(W, nrow(pre)) } else pretrend_p <- NA_real_

  base_rows <- d2[gn < 10000 & year < gn & is.finite(get(yn))]
  base <- if (nrow(base_rows)) {
    if (wt) weighted.mean(base_rows[[yn]], base_rows$pop, na.rm = TRUE) else mean(base_rows[[yn]], na.rm = TRUE)
  } else NA_real_

  # year span of the estimation sample actually fed to feols (treated + controls).
  years <- range(d2$year, na.rm = TRUE)
  list(ok = TRUE, att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       pretrend_p = pretrend_p, base = base, n_treated = n_tr,
       years = sprintf("%d-%d", years[1], years[2]), es = es, msg = "ok")
}

# --------------------------------------------------------------------------
# Run every (outcome x basis), pop-weighted (headline) + unweighted variant,
# + pandemic-excluded robustness on the headline weighting.
# --------------------------------------------------------------------------
rows <- list(); es_store <- list()
for (b in bases) {
  db <- d[basis == b]
  for (yn in outcomes) {
    yr_span <- sample_year_span(db, yn)
    # --- pre-feols variation guard ------------------------------------------
    # Fine MH categories (caps_procedures, psychiatric_consults, psychotherapy,
    # alcohol_drug, n_caps_providers) are intentionally all-zero offline: they
    # need SIGTAP procedure descriptions that aren't available yet. Detect any
    # constant/zero outcome here and emit ONE typed status row -- never call
    # feols (which would otherwise leak "The dependent variable is a constant").
    vg <- variation_guard(db, yn)
    if (isTRUE(vg$constant)) {
      st <- if (vg$reason == "all_zero" && is_sigtap_pending(yn)) "all_zero_sigtap_pending"
            else if (vg$reason == "all_zero") "all_zero_no_variation"
            else "constant_no_variation"
      n_tr0 <- db[gn < 10000 & is.finite(get(yn)) & is.finite(pop) & pop > 0, uniqueN(muni_id)]
      say("[%s | %s] CONSTANT -> %s (no feols)", yn, b, st)
      rows[[length(rows) + 1]] <- data.table(
        outcome = yn, basis = b, weighting = "pop-weighted", pandemic = "included",
        att = NA_real_, ci_low = NA_real_, ci_high = NA_real_, pretrend_p = NA_real_,
        baseline_mean = NA_real_, n_treated = n_tr0, years = yr_span,
        families = families_str, status = st)
      next  # skip both weighting variants and the pandemic-excluded robustness
    }
    # --- estimable outcome: pop-weighted + unweighted, pandemic included -----
    for (wt in c(TRUE, FALSE)) {
      r <- est_sa(db, yn, wt = wt, drop_pandemic = FALSE)
      wlab <- if (wt) "pop-weighted" else "unweighted"
      if (!isTRUE(r$ok)) {
        say("[%s | %s | %s] SKIP: %s", yn, b, wlab, r$msg)
        rows[[length(rows) + 1]] <- data.table(
          outcome = yn, basis = b, weighting = wlab, pandemic = "included",
          att = NA_real_, ci_low = NA_real_, ci_high = NA_real_, pretrend_p = NA_real_,
          baseline_mean = NA_real_, n_treated = r$n_treated, years = yr_span,
          families = families_str, status = r$msg)
        next
      }
      warn_pt <- is.finite(r$pretrend_p) && r$pretrend_p < 0.10
      if (warn_pt) say("WARNING pre-trend FAILS (p=%.3f) for [%s | %s | %s] -> DO NOT interpret causally.",
                       r$pretrend_p, yn, b, wlab)
      say("[%s | %s | %s] ATT=%+.3f CI[%+.3f,%+.3f] pre-p=%.3f base=%.3f n_tr=%d",
          yn, b, wlab, r$att, r$lo, r$hi, r$pretrend_p, r$base, r$n_treated)
      rows[[length(rows) + 1]] <- data.table(
        outcome = yn, basis = b, weighting = wlab, pandemic = "included",
        att = r$att, ci_low = r$lo, ci_high = r$hi, pretrend_p = r$pretrend_p,
        baseline_mean = r$base, n_treated = r$n_treated, years = r$years,
        families = families_str, status = if (warn_pt) "pretrend_fail" else "ok")
      # store event-study path for the figure (pop-weighted, included pandemic).
      if (wt) es_store[[paste(b, yn, sep = "__")]] <- r$es
    }
    # pandemic-excluded robustness (pop-weighted only).
    rpx <- est_sa(db, yn, wt = TRUE, drop_pandemic = TRUE)
    if (isTRUE(rpx$ok)) {
      rows[[length(rows) + 1]] <- data.table(
        outcome = yn, basis = b, weighting = "pop-weighted", pandemic = "excl-2020-2021",
        att = rpx$att, ci_low = rpx$lo, ci_high = rpx$hi, pretrend_p = rpx$pretrend_p,
        baseline_mean = rpx$base, n_treated = rpx$n_treated, years = rpx$years,
        families = families_str, status = "ok")
    }
  }
}
res <- rbindlist(rows, fill = TRUE)
# Safeguard: exactly one row per (outcome, basis, weighting, pandemic-variant).
# Guards against any accidental double-append upstream of this point.
setorder(res, outcome, basis, weighting, pandemic)
res <- unique(res, by = c("outcome", "basis", "weighting", "pandemic"))

# --------------------------------------------------------------------------
# Offset check vs the inpatient psych_adm decline (heavy caveats).
# Compare the residence-basis, pop-weighted, pandemic-included outpatient
# procedures ATT against the inpatient decline on the same per-1k scale.
# ratio = outpatient procedure rise / |inpatient procedure fall|. This is a
# crude, unit-mismatched comparison (an outpatient procedure != an averted
# admission), reported only to bound plausibility.
# --------------------------------------------------------------------------
inpatient_att <- NA_real_
if (has_inpatient) {
  rin <- est_sa(d[basis == "residence"], "psych_adm_per1k", wt = TRUE)
  if (isTRUE(rin$ok)) { inpatient_att <- rin$att; say("inpatient psych_adm ATT (residence, pop-wt) = %+.3f", inpatient_att) }
}
offset_note <- "no inpatient comparator available"
head_proc <- res[outcome == "outpatient_mh_procedures_per1k" & basis == "residence" &
                 weighting == "pop-weighted" & pandemic == "included"]
if (nrow(head_proc) && is.finite(head_proc$att)) {
  if (head_proc$att > 0 && is.finite(inpatient_att) && inpatient_att < 0) {
    ratio <- head_proc$att / abs(inpatient_att)
    offset_note <- sprintf("outpatient procedure ATT rises (%+.3f/1k); ratio to |inpatient decline| = %.2f (CAVEAT: unit-mismatched, no patient linkage)", head_proc$att, ratio)
    say("OFFSET: %s", offset_note)
  } else if (head_proc$att > 0) {
    offset_note <- sprintf("outpatient procedures rise (%+.3f/1k) but inpatient comparator unavailable/positive -> ratio not computed", head_proc$att)
    say("OFFSET: %s", offset_note)
  } else {
    offset_note <- "no outpatient offset detected: outpatient procedure production does not rise after closure in these administrative measures"
    say("OFFSET: %s", offset_note)
  }
}

# --------------------------------------------------------------------------
# Machine-readable CSV (contract column order first, extras appended).
# --------------------------------------------------------------------------
csv <- res[, .(outcome, basis, att, ci_low, ci_high, pretrend_p, baseline_mean,
               n_treated, years, families, weighting, pandemic, status)]
fwrite(csv, OUT_CSV)
say("wrote: %s (rows=%d)", OUT_CSV, nrow(csv))

# --------------------------------------------------------------------------
# Event-study figure: facet by outcome, residence basis primary; pop-weighted,
# pandemic included; window e in [-7, +8]. Mirrors 75/24b house style.
# --------------------------------------------------------------------------
OK <- "#0072B2"; GREY <- "gray55"
prim_basis <- if ("residence" %in% bases) "residence" else bases[1]
fig_parts <- list()
for (yn in outcomes) {
  esdt <- es_store[[paste(prim_basis, yn, sep = "__")]]
  if (is.null(esdt) || !nrow(esdt)) next
  dd <- copy(esdt[e >= -7 & e <= 8])
  dd[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se, outcome = outcome_label[yn])]
  fig_parts[[yn]] <- dd
}
if (length(fig_parts)) {
  fdt <- rbindlist(fig_parts, fill = TRUE)
  fdt[, outcome := factor(outcome, levels = unname(outcome_label[outcomes]))]
  g <- ggplot(fdt, aes(e, cf)) +
    geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, fill = OK) +
    geom_pointrange(aes(ymin = lo, ymax = hi), color = OK, linewidth = 0.5, size = 0.32) +
    geom_line(color = OK, linewidth = 0.4, alpha = 0.55) +
    facet_wrap(~ outcome, scales = "free_y") +
    scale_x_continuous(breaks = seq(-6, 8, 2)) +
    labs(x = "Years since closure", y = "ATT (residence basis, pop-weighted)",
         title = "Outpatient mental-health production after PNASH psychiatric closure",
         subtitle = "Administrative production, not patient-level substitution; residence basis shown") +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(size = 10, hjust = 0),
          plot.subtitle = element_text(size = 8, hjust = 0, color = GREY),
          strip.text = element_text(size = 8))
  ggsave(OUT_FIG, g, width = 7.2, height = 5.0, device = "pdf")
  say("wrote: %s", OUT_FIG)
} else {
  say("no event-study paths available -> figure not written")
}

# --------------------------------------------------------------------------
# LaTeX appendix table (booktabs house style; one row per outcome x basis,
# headline weighting = pop-weighted, pandemic included).
# --------------------------------------------------------------------------
fmt  <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmtp <- function(x) ifelse(is.finite(x), sprintf("%.3f", x), "--")
fmt2 <- function(x) ifelse(is.finite(x), sprintf("%.2f", x), "--")

head_res <- res[weighting == "pop-weighted" & pandemic == "included"]
body <- c()
for (b in bases) {
  basis_lab <- if (b == "residence") "Residence basis (patient municipality)" else "Provider basis (supply location)"
  body <- c(body, sprintf("\\multicolumn{7}{l}{\\textit{%s}}\\\\", basis_lab))
  for (yn in outcomes) {
    r <- head_res[outcome == yn & basis == b]
    if (!nrow(r)) next
    ci  <- if (is.finite(r$ci_low)) sprintf("[%s, %s]", fmt(r$ci_low), fmt(r$ci_high)) else "--"
    ptp <- if (is.finite(r$pretrend_p)) {
      if (r$pretrend_p < 0.10) sprintf("%s$^{\\dagger}$", fmtp(r$pretrend_p)) else fmtp(r$pretrend_p)
    } else "--"
    body <- c(body, sprintf("\\quad %s & %s & %s & %s & %s & %d & %s \\\\",
                            outcome_label[yn], fmt(r$att), ci, ptp,
                            fmt2(r$baseline_mean), r$n_treated, r$years))
  }
}

tex <- c(
  "% Auto-generated by 03_analysis/O8_estimate_outpatient_substitution.R -- do not edit by hand.",
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Outpatient mental-health production after PNASH psychiatric closure (Sun--Abraham event study)}",
  "\\label{tab:outpatient-substitution-es}",
  "\\small",
  "\\begin{tabular}{lrrrrrr}",
  "\\toprule",
  "Outcome & ATT & 95\\% CI & Pre-trend $p$ & Pre-base & $N_{\\text{tr}}$ & Years \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\multicolumn{7}{p{0.96\\textwidth}}{\\footnotesize \\textit{Notes.} Population-weighted Sun--Abraham (2021)",
  "event-study ATT (post-period average of event coefficients) with municipality and year fixed effects;",
  "standard errors clustered by municipality; pandemic years 2020--2021 included (a pandemic-excluded variant",
  "is in the companion CSV). Pre-trend $p$ is the joint $\\chi^2$ test that pre-period leads ($e\\in[-6,-2]$)",
  "equal zero; $\\dagger$ marks $p<0.10$, for which the estimate is \\emph{not} interpreted causally.",
  "\\emph{Residence basis} attributes production to the patient's municipality of residence; \\emph{provider",
  "basis} attributes it to the providing municipality and is a supply/location measure -- it must \\emph{not}",
  "be read as patient-level substitution. These are administrative \\emph{production} counts (procedures,",
  "actions, consultations, spending, provider counts), not verified patient-level substitution. With the",
  "small treated catchment, estimates are suggestive. ATT and base on each outcome's native per-1k / per-capita scale.",
  sprintf("Offset assessment: %s", gsub("([&%%_#$])", "\\\\\\1", offset_note)),
  "}\\\\",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(tex, OUT_TEX)
say("wrote: %s", OUT_TEX)

# --------------------------------------------------------------------------
# Verdict block for the log.
# --------------------------------------------------------------------------
say("\n=== verdict ===")
any_rise <- nrow(head_res[is.finite(att) & att > 0 & status == "ok"]) > 0
any_pt_fail <- nrow(head_res[is.finite(pretrend_p) & pretrend_p < 0.10]) > 0
say("any outcome rises (pop-wt, included, clean): %s", any_rise)
say("any pre-trend failure (p<0.10) in headline rows: %s  (if TRUE, those rows are NOT causal)", any_pt_fail)
say("offset: %s", offset_note)
say("runtime_seconds: %.2f", as.numeric(difftime(Sys.time(), started, units = "secs")))
say("done")
