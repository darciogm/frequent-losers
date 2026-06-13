#!/usr/bin/env Rscript
# O9_caps_capacity_heterogeneity.R
#
# COMPLEMENTS (does not duplicate) 03_analysis/86_caps_heterogeneity.R. That
# script split the PNASH closure catchment by baseline CAPS *facility presence*
# (any vs none, CNES TP_UNID=70) and estimated pop-weighted Sun-Abraham ATTs by
# subgroup. This script reuses 86's baseline-CAPS split logic and conventions and
# EXTENDS it by bringing OUTPATIENT PRODUCTION in as both (i) a moderator
# (baseline outpatient MH production / CAPS per-100k as an additional capacity
# split) and (ii) an outcome (does outpatient production respond, and does the
# response differ by baseline capacity?).
#
# ====================== EXPLORATORY FRAMING (read me) ======================
# Baseline capacity is observed only coarsely: CAPS data are FACILITY COUNTS
# (not beds/SRT/outpatient production) and national CAPS coverage ends in 2016.
# With ~104 treated municipalities split two ways, power is very limited. Every
# estimate here is EXPLORATORY/SUGGESTIVE, not decisive. CIs are reported wide
# and honestly; we do not overclaim. If a subgroup is underpowered the script
# logs it and the table notes say so.
# ===========================================================================
#
# Estimator contract (matches 86 / 75): pop-weighted Sun-Abraham
#   feols(y ~ sunab(gn, year) | muni_id + year, cluster = "muni_id", weights = ~pop)
#   never-treated (g_emb == 0 | NA) recoded to sentinel 10000. Each subgroup keeps
#   all never-treated munis + only its own treated munis. ATT = agg "att".
#   Given small N a simple post x high interaction is also reported as a backstop.
#
# Outputs:
#   01_manuscript/tables_appendix/table_caps_capacity_heterogeneity.tex
#   04_figures_appendix/fig_caps_capacity_heterogeneity.pdf
#   04_logs/outpatient/caps_capacity_heterogeneity_<YYYYMMDD>.log
#
# Usage: Rscript 03_analysis/O9_caps_capacity_heterogeneity.R [--force]

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
for (d in c(APPDX, FIGA, LOGDIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

STAMP   <- format(Sys.time(), "%Y%m%d")
LOGF    <- file.path(LOGDIR, sprintf("caps_capacity_heterogeneity_%s.log", STAMP))
OUT_TEX <- file.path(APPDX, "table_caps_capacity_heterogeneity.tex")
OUT_FIG <- file.path(FIGA, "fig_caps_capacity_heterogeneity.pdf")

sink(LOGF, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
say <- function(...) cat(sprintf(...), "\n")

say("=== telemetry ===")
say("script: 03_analysis/O9_caps_capacity_heterogeneity.R")
say("started: %s", format(started, "%Y-%m-%d %H:%M:%S %Z"))
say("hostname: %s | R: %s", Sys.info()[["nodename"]], R.version.string)
say("fixest_nthreads: 4 | dt_threads: 4")
say("complements: 03_analysis/86_caps_heterogeneity.R (reuses its baseline-CAPS split conventions)")
say("=================")

# --------------------------------------------------------------------------
# Inputs. The staggered panel + CAPS file are required (also used by 86). The
# outpatient panel is OPTIONAL: if absent, the outpatient-production extensions
# are skipped but the core CAPS-capacity heterogeneity still runs. If the
# *required* staggered panel is missing, log + quit(0).
# --------------------------------------------------------------------------
STAG  <- file.path(INTER, "staggered_panel_pnash48_ext.parquet")
CAPSF <- file.path(PROC, "cnes_caps_cir_municipality_year.parquet")
PSY   <- file.path(INTER, "psych_outcomes_panel.parquet")  # carries psych_adm_per1k
OMH   <- file.path(OMHDIR, "catchment_outpatient_event_panel.parquet")

if (!file.exists(STAG) || !file.exists(CAPSF)) {
  if (!file.exists(STAG)) say("MISSING INPUT: %s", STAG)
  if (!file.exists(CAPSF)) say("MISSING INPUT: %s", CAPSF)
  say("Required inputs absent -> nothing to estimate. Quitting gracefully (status 0).")
  quit(save = "no", status = 0)
}
if (file.exists(OUT_TEX) && file.exists(OUT_FIG) && !force) {
  say("outputs exist, skipping (use --force)")
  quit(save = "no", status = 0)
}

# --------------------------------------------------------------------------
# Panel + never-treated recode (exactly as 86).
# --------------------------------------------------------------------------
panel <- as.data.table(read_parquet(STAG))
panel[, codmun_6 := as.character(codmun_6)]
panel[, gn := fifelse(is.na(g_emb) | g_emb == 0L, 10000L, as.integer(g_emb))]

# psych_adm_per1k lives in psych_outcomes_panel (as in 75); merge if available.
if ("psych_adm_per1k" %in% names(panel)) {
  say("psych_adm_per1k present in staggered panel")
} else if (file.exists(PSY)) {
  po <- as.data.table(read_parquet(PSY))
  po[, codmun_6 := as.character(codmun_6)]
  panel <- merge(panel, po[, .(codmun_6, year, psych_adm_per1k)],
                 by = c("codmun_6", "year"), all.x = TRUE)
  say("merged psych_adm_per1k from %s", basename(PSY))
} else {
  say("psych_adm_per1k unavailable -> inpatient outcome will be skipped")
}

# Optional outpatient panel: merge residence-basis MH production by muni-year.
have_omh <- FALSE
omh_proc_col <- NULL
if (file.exists(OMH)) {
  omh <- as.data.table(read_parquet(OMH))
  omh[, codmun_6 := as.character(codmun_6)]
  if ("basis" %in% names(omh)) omh <- omh[basis == "residence"]
  # 'total_mh_procedures_per1k' is the name the O6/O7 panel actually emits; it must
  # be in the alias list (as in O8) or the outpatient moderator+outcome silently drop.
  proc_aliases <- c("outpatient_mh_procedures_per1k", "total_mh_procedures_per1k",
                    "outpatient_mh_proc_per1k", "outpatient_procedures_per1k",
                    "mh_procedures_per1k")
  hit <- intersect(proc_aliases, names(omh))
  if (length(hit)) {
    omh_proc_col <- "outpatient_mh_procedures_per1k"
    setnames(omh, hit[1], omh_proc_col)
    raas_col <- intersect(c("raas_psychosocial_actions_per1k"), names(omh))
    keep <- c("codmun_6", "year", omh_proc_col, raas_col)
    panel <- merge(panel, unique(omh[, ..keep]), by = c("codmun_6", "year"), all.x = TRUE)
    have_omh <- TRUE
    say("merged outpatient production (%s%s) from %s",
        omh_proc_col, if (length(raas_col)) "+raas" else "", basename(OMH))
  } else {
    say("outpatient panel present but no recognizable procedures column -> outpatient extensions skipped")
  }
} else {
  say("outpatient panel absent -> outpatient-production moderator/outcome skipped (core CAPS split still runs)")
}

# --------------------------------------------------------------------------
# Baseline CAPS capacity at closure_year-1 (reuse of 86's logic), capped at the
# last CAPS year. Then derive capacity MODERATORS:
#   (A) CAPS facility presence (any vs none)       -- as in 86
#   (B) CAPS per 100k pop at t-1 (median split)    -- new continuous capacity
#   (C) baseline outpatient MH procedures per1k    -- new (only if OMH present)
# --------------------------------------------------------------------------
caps <- as.data.table(read_parquet(CAPSF))
caps[, municipality := as.character(municipality)]
CAPS_LAST_YEAR <- max(caps$year)
say("CAPS coverage: %d-%d | treated munis: %d", min(caps$year), CAPS_LAST_YEAR,
    panel[gn < 10000, uniqueN(codmun_6)])

treated <- unique(panel[gn < 10000, .(codmun_6, g_emb = as.integer(g_emb))])
# baseline pop at t-1 (from the panel) for per-100k normalization.
basepop <- panel[gn < 10000, .(codmun_6, year, pop)]
treated <- merge(treated, basepop, by.x = c("codmun_6"), by.y = c("codmun_6"),
                 allow.cartesian = TRUE)
treated <- treated[year == g_emb - 1L, .(codmun_6, g_emb, base_pop = pop)]
treated <- unique(treated)

treated[, caps_meas_year := pmin(g_emb - 1L, CAPS_LAST_YEAR)]
treated[, caps_year_capped := (g_emb - 1L) > CAPS_LAST_YEAR]
treated <- merge(treated, caps[, .(codmun_6 = municipality, year, caps_facilities)],
                 by.x = c("codmun_6", "caps_meas_year"), by.y = c("codmun_6", "year"),
                 all.x = TRUE)
treated[, has_baseline_caps := caps_facilities >= 1]                       # (A)
treated[, caps_per100k := fifelse(is.finite(base_pop) & base_pop > 0,
                                  1e5 * pmax(caps_facilities, 0) / base_pop, NA_real_)]

# (C) baseline outpatient production at t-1, if OMH merged.
if (have_omh && !is.null(omh_proc_col)) {
  bo <- panel[gn < 10000, .(codmun_6, year, op = get(omh_proc_col))]
  bo <- merge(treated[, .(codmun_6, g_emb)], bo, by = "codmun_6")
  bo <- bo[year == g_emb - 1L, .(codmun_6, base_outpatient = op)]
  treated <- merge(treated, unique(bo), by = "codmun_6", all.x = TRUE)
}

cat("\n=== baseline capacity distribution (treated, closure_year-1) ===\n")
print(treated[, .N, by = caps_facilities][order(caps_facilities)])
say("CAPS per100k: median=%.3f (treated, finite)", median(treated$caps_per100k, na.rm = TRUE))
if ("base_outpatient" %in% names(treated))
  say("baseline outpatient proc/1k: median=%.3f (treated, finite)",
      median(treated$base_outpatient, na.rm = TRUE))

# Build split-membership sets for each moderator. Median split for continuous
# capacity (HIGH = >= median); any-vs-none for facility presence.
mods <- list()
mods[["CAPS facility presence (any vs none)"]] <- list(
  high = treated[has_baseline_caps == TRUE, codmun_6],
  low  = treated[has_baseline_caps == FALSE, codmun_6])
{
  med <- median(treated$caps_per100k, na.rm = TRUE)
  if (is.finite(med) && treated[is.finite(caps_per100k), .N] >= 6) {
    mods[["CAPS per 100k (median split)"]] <- list(
      high = treated[is.finite(caps_per100k) & caps_per100k >= med, codmun_6],
      low  = treated[is.finite(caps_per100k) & caps_per100k <  med, codmun_6])
  } else say("CAPS per100k split degenerate/underpowered -> omitted")
}
if ("base_outpatient" %in% names(treated)) {
  med <- median(treated$base_outpatient, na.rm = TRUE)
  if (is.finite(med) && treated[is.finite(base_outpatient), .N] >= 6) {
    mods[["Baseline outpatient MH prod. (median split)"]] <- list(
      high = treated[is.finite(base_outpatient) & base_outpatient >= med, codmun_6],
      low  = treated[is.finite(base_outpatient) & base_outpatient <  med, codmun_6])
  } else say("baseline-outpatient split degenerate/underpowered -> omitted")
}
say("moderators in play: %s", paste(names(mods), collapse = " | "))

# --------------------------------------------------------------------------
# Outcomes: inpatient psych admissions, suicide, self-harm (from staggered
# panel) + outpatient production (if merged).
# --------------------------------------------------------------------------
outcome_label <- c(
  psych_adm_per1k                = "Psych. admissions (per 1k)",
  outpatient_mh_procedures_per1k = "Outpatient MH procedures (per 1k)",
  suicide_per100k                = "Suicide (per 100k)",
  selfharm_per100k               = "Self-harm (per 100k)")
outcomes <- intersect(names(outcome_label), names(panel))
say("outcomes: %s", paste(outcomes, collapse = ", "))

# --------------------------------------------------------------------------
# Split-sample pop-weighted Sun-Abraham ATT (mirrors 86::estimate_group),
# plus a simple post x high interaction backstop for small-N transparency.
# --------------------------------------------------------------------------
estimate_group <- function(y, subgroup_munis, label) {
  d <- panel[(gn >= 10000) | (codmun_6 %in% subgroup_munis)]
  d <- d[is.finite(get(y)) & is.finite(pop) & pop > 0]
  n_tr <- d[gn < 10000, uniqueN(codmun_6)]
  fail <- function(msg) data.table(outcome = y, subgroup = label, n_treated = n_tr,
                                   att = NA_real_, se = NA_real_, ci_lo = NA_real_,
                                   ci_hi = NA_real_, baseline_rate = NA_real_, status = msg)
  if (n_tr < 3) return(fail("underpowered: <3 treated municipalities"))
  fit <- tryCatch(
    feols(as.formula(sprintf("%s ~ sunab(gn, year) | codmun_6 + year", y)),
          d, cluster = "codmun_6", weights = ~pop, warn = FALSE, notes = FALSE),
    error = function(e) e)
  if (inherits(fit, "error")) return(fail(fit$message))
  a <- tryCatch(summary(fit, agg = "att"), error = function(e) e)
  if (inherits(a, "error")) return(fail(a$message))
  att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  base <- d[gn < 10000 & year < gn & is.finite(get(y)) & is.finite(pop) & pop > 0]
  baseline <- if (nrow(base)) weighted.mean(base[[y]], base$pop, na.rm = TRUE) else NA_real_
  data.table(outcome = y, subgroup = label, n_treated = n_tr,
             att = att, se = se, ci_lo = att - 1.96 * se, ci_hi = att + 1.96 * se,
             baseline_rate = baseline, status = if (n_tr < 8) "ok (underpowered)" else "ok")
}

# simple post x high interaction (backstop): post = year >= gn (treated only),
# high = membership in the high subgroup. Reported descriptively.
estimate_interaction <- function(y, mod) {
  hi <- mod$high; lo <- mod$low
  d <- panel[codmun_6 %in% c(hi, lo)]
  d <- d[is.finite(get(y)) & is.finite(pop) & pop > 0 & gn < 10000]
  if (d[, uniqueN(codmun_6)] < 6) return(data.table(coef = NA_real_, se = NA_real_, p = NA_real_, status = "underpowered"))
  d[, post := as.integer(year >= gn)]
  d[, high := as.integer(codmun_6 %in% hi)]
  fit <- tryCatch(feols(as.formula(sprintf("%s ~ post * high | codmun_6 + year", y)),
                        d, cluster = "codmun_6", weights = ~pop, warn = FALSE, notes = FALSE),
                  error = function(e) e)
  if (inherits(fit, "error")) return(data.table(coef = NA_real_, se = NA_real_, p = NA_real_, status = fit$message))
  cf <- coef(fit); s <- se(fit); pv <- pvalue(fit)
  ix <- which(names(cf) == "post:high")
  if (!length(ix)) return(data.table(coef = NA_real_, se = NA_real_, p = NA_real_, status = "no interaction term"))
  data.table(coef = as.numeric(cf[ix]), se = as.numeric(s[ix]), p = as.numeric(pv[ix]), status = "ok")
}

parts <- list(); inter <- list()
for (mname in names(mods)) {
  m <- mods[[mname]]
  for (y in outcomes) {
    parts[[length(parts) + 1]] <- cbind(moderator = mname,
      estimate_group(y, m$high, sprintf("High: %s", mname)))
    parts[[length(parts) + 1]] <- cbind(moderator = mname,
      estimate_group(y, m$low,  sprintf("Low: %s",  mname)))
    ii <- estimate_interaction(y, m)
    inter[[length(inter) + 1]] <- cbind(moderator = mname, outcome = y, ii)
  }
}
# all-treated reference rows (per outcome).
all_tr <- unique(unlist(lapply(mods, function(m) c(m$high, m$low))))
for (y in outcomes)
  parts[[length(parts) + 1]] <- cbind(moderator = "All treated (reference)",
    estimate_group(y, all_tr, "All treated"))

res   <- rbindlist(parts, fill = TRUE)
inter <- rbindlist(inter, fill = TRUE)
res[, outcome_pretty := outcome_label[outcome]]

cat("\n=== subgroup ATT estimates (pop-weighted Sun-Abraham) ===\n")
print(res[, .(moderator, outcome = outcome_pretty, subgroup = sub(":.*", "", subgroup),
              n_treated, att = round(att, 3), ci_lo = round(ci_lo, 3),
              ci_hi = round(ci_hi, 3), status)])

cat("\n=== post x high interaction backstop (descriptive) ===\n")
print(inter[, .(moderator, outcome = outcome_label[outcome], coef = round(coef, 3),
                se = round(se, 3), p = round(p, 3), status)])

# High-vs-Low descriptive z-test (as in 86), per moderator x outcome.
cat("\n=== High-vs-Low differential (descriptive z on subgroup ATTs) ===\n")
diff_tbl <- list()
for (mname in names(mods)) for (y in outcomes) {
  hi <- res[moderator == mname & outcome == y & grepl("^High", subgroup)]
  lo <- res[moderator == mname & outcome == y & grepl("^Low",  subgroup)]
  if (nrow(hi) && nrow(lo) && is.finite(hi$att) && is.finite(lo$att) && is.finite(hi$se) && is.finite(lo$se)) {
    dd <- hi$att - lo$att; sed <- sqrt(hi$se^2 + lo$se^2); z <- dd / sed; p <- 2 * pnorm(-abs(z))
    say("  [%s | %s] diff(H-L)=%+.3f se=%.3f z=%+.2f p=%.3f", mname, outcome_label[y], dd, sed, z, p)
    diff_tbl[[paste(mname, y)]] <- data.table(moderator = mname, outcome = y, diff = dd, se_diff = sed, z = z, p = p)
  } else say("  [%s | %s] diff not computable (degenerate/NA subgroup)", mname, outcome_label[y])
}
diff_dt <- rbindlist(diff_tbl, fill = TRUE)

# --------------------------------------------------------------------------
# Figure: subgroup ATT +/- 95% CI, faceted by outcome, colored by High/Low,
# panelled across moderators. Honest wide CIs; exploratory.
# --------------------------------------------------------------------------
pdt <- res[moderator != "All treated (reference)" & is.finite(att)]
if (nrow(pdt)) {
  pdt[, grp := fifelse(grepl("^High", subgroup), "High capacity", "Low capacity")]
  pdt[, outcome_f := factor(outcome_label[outcome], levels = unname(outcome_label[outcomes]))]
  pdt[, mod_f := factor(moderator, levels = names(mods))]
  pd <- position_dodge(width = 0.5)
  g <- ggplot(pdt, aes(x = mod_f, y = att, color = grp, group = grp)) +
    geom_hline(yintercept = 0, color = "gray55", linewidth = 0.4, linetype = "dashed") +
    geom_pointrange(aes(ymin = ci_lo, ymax = ci_hi), position = pd, linewidth = 0.5, size = 0.35) +
    facet_wrap(~ outcome_f, scales = "free_y") +
    scale_color_manual(values = c("High capacity" = "#0072B2", "Low capacity" = "#D55E00"), name = NULL) +
    labs(x = NULL, y = "Subgroup ATT (pop-weighted Sun--Abraham)",
         title = "Closure effect by baseline mental-health capacity (exploratory)",
         subtitle = "~104 treated munis split two ways: wide CIs, suggestive only") +
    theme_minimal(base_size = 8.5) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(size = 10, hjust = 0),
          plot.subtitle = element_text(size = 8, hjust = 0, color = "gray55"),
          axis.text.x = element_text(angle = 18, hjust = 1, size = 6.5),
          legend.position = "top", strip.text = element_text(size = 8))
  ggsave(OUT_FIG, g, width = 7.4, height = 5.4, device = "pdf")
  say("wrote: %s", OUT_FIG)
} else {
  say("no finite subgroup ATTs -> figure not written")
}

# --------------------------------------------------------------------------
# LaTeX appendix table (booktabs + threeparttable, as in 86).
# --------------------------------------------------------------------------
fmt  <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmt2 <- function(x) ifelse(is.finite(x), sprintf("%.2f", x), "--")

body <- c()
for (y in outcomes) {
  body <- c(body, sprintf("\\multicolumn{5}{l}{\\textit{%s}}\\\\", outcome_label[y]))
  for (mname in names(mods)) {
    for (side in c("High", "Low")) {
      r <- res[moderator == mname & outcome == y & grepl(sprintf("^%s", side), subgroup)]
      if (!nrow(r)) next
      ci  <- if (is.finite(r$ci_lo)) sprintf("[%s, %s]", fmt(r$ci_lo), fmt(r$ci_hi)) else "--"
      under <- grepl("underpowered", r$status)
      lab <- sprintf("%s -- %s%s", side, mname, if (under) " (underpow.)" else "")
      body <- c(body, sprintf("\\quad %s & %d & %s & %s & %s \\\\",
                              lab, r$n_treated, fmt(r$att),
                              if (is.finite(r$se)) fmt2(r$se) else "--", ci))
    }
  }
  rall <- res[moderator == "All treated (reference)" & outcome == y]
  if (nrow(rall)) {
    ci <- if (is.finite(rall$ci_lo)) sprintf("[%s, %s]", fmt(rall$ci_lo), fmt(rall$ci_hi)) else "--"
    body <- c(body, sprintf("\\quad %s & %d & %s & %s & %s \\\\",
                            "All treated (reference)", rall$n_treated, fmt(rall$att),
                            if (is.finite(rall$se)) fmt2(rall$se) else "--", ci))
  }
}

any_sig <- if (nrow(diff_dt)) any(is.finite(diff_dt$p) & diff_dt$p < 0.05) else FALSE
power_note <- if (any_sig) {
  "At least one High-vs-Low differential is detectable at $p<0.05$; given the small treated sample this is still suggestive, not decisive."
} else {
  "No High-vs-Low differential is detectable at conventional levels: the split is \\emph{underpowered} and we draw no conclusion about whether baseline capacity moderates the closure effect."
}

tex <- c(
  "% Auto-generated by 03_analysis/O9_caps_capacity_heterogeneity.R -- do not edit by hand.",
  "% Complements 03_analysis/86_caps_heterogeneity.R; extends it with outpatient production as moderator + outcome.",
  "\\begin{table}[!htbp]\\centering",
  "\\begin{threeparttable}",
  "\\caption{Closure effect by baseline mental-health capacity, with outpatient production (exploratory)}",
  "\\label{tab:caps-capacity-heterogeneity}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  "Subgroup & Treated munis. & ATT & SE & 95\\% CI \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  "\\item \\textit{Notes.} \\textbf{Exploratory.} Population-weighted Sun--Abraham (2021) event-study ATT",
  "estimates with municipality and year fixed effects; standard errors clustered by municipality and 95\\%",
  "confidence intervals. Each subgroup keeps all never-treated municipalities and only the treated",
  "municipalities in that subgroup; ``All treated (reference)'' pools them. This table complements",
  "Table~\\ref{tab:caps-heterogeneity} (baseline CAPS facility presence) by adding capacity moderators",
  "(CAPS per 100k population at $t-1$; baseline outpatient MH production where observed) and outpatient",
  "production as an outcome. Baseline capacity is measured coarsely: CAPS data are \\emph{facility counts}",
  "(not beds, SRT, or production) with national coverage ending in 2016, so per-100k and presence splits",
  "are proxies. With $\\sim$104 treated municipalities split two ways, statistical power is very limited;",
  "subgroups flagged ``(underpow.)'' have $<8$ treated municipalities. ",
  power_note,
  "These estimates are descriptive/suggestive, not decisive.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, OUT_TEX)
say("wrote: %s", OUT_TEX)

say("\n=== verdict ===")
say("moderators estimated: %d | outcomes: %d", length(mods), length(outcomes))
say("any High-vs-Low differential p<0.05: %s (if FALSE -> underpowered, no claim)", any_sig)
say("runtime_seconds: %.2f", as.numeric(difftime(Sys.time(), started, units = "secs")))
say("done")
