#!/usr/bin/env Rscript
# Task G: heterogeneity of the PNASH closure effect by baseline community
# mental-health (CAPS) facility presence in the flow-exposed catchment.
#
# Referee concern: inpatient psychiatric admissions fall ~69% yet mortality does
# not rise -- did community/outpatient CAPS capacity absorb displaced patients?
# We can only observe FACILITY COUNT (CNES TP_UNID=70), not beds/SRT/outpatient
# production, and CAPS coverage ends in 2016. So this is a coarse, suggestive
# proxy, and with ~104 treated munis split two ways power is very limited.
#
# Design mirrors 56_heterogeneity_dependence_revision.R: split-sample,
# pop-weighted Sun-Abraham (sunab) with muni + year FE, cluster by muni,
# aggregate to a single ATT per subgroup.
#
# Split: own-municipality baseline CAPS facility count at closure_year-1
# (latest available year capped at 2016 for the 2017 cohort). HIGH = any CAPS
# present (>=1); LOW = none (0). Median is 0 so above/below-median is degenerate;
# any-vs-none is the only non-trivial binary split at this N.

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
})

setFixest_nthreads(8)

args <- commandArgs(trailingOnly = FALSE)
trailing <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% trailing
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
PROC <- file.path(ROOT, "02_data", "processed")
APPDX <- file.path(ROOT, "01_manuscript", "tables_appendix")
LOG <- file.path(ROOT, "04_logs")
dir.create(APPDX, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(LOG, "caps_heterogeneity_20260609.log")
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()

# --- telemetry header ---
cat("=== telemetry ===\n")
cat("script: 03_analysis/86_caps_heterogeneity.R\n")
cat("started:", format(started, "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("hostname:", Sys.info()[["nodename"]], "\n")
cat("R:", R.version.string, "\n")
cat("nproc(detect):", parallel::detectCores(), " fixest_nthreads: 8\n")
mem <- tryCatch(system("free -h | awk 'NR==2{print $2\" total, \"$7\" avail\"}'", intern = TRUE),
                error = function(e) NA_character_)
cat("ram:", paste(mem, collapse = " "), "\n")
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
cat("git_sha:", paste(git_sha, collapse = " "), "\n")
cat("packages:", paste(c(
  paste0("arrow=", as.character(packageVersion("arrow"))),
  paste0("data.table=", as.character(packageVersion("data.table"))),
  paste0("fixest=", as.character(packageVersion("fixest")))
), collapse = "; "), "\n")
cat("=================\n\n")

csv_out <- file.path(PROC, "caps_heterogeneity.csv")
tex_out <- file.path(APPDX, "table_caps_heterogeneity.tex")

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------
panel <- as.data.table(read_parquet(file.path(PROC, "revision_pnash48_panel.parquet")))
panel[, codmun_6 := as.character(codmun_6)]
# gn = treatment cohort year; never-treated -> 10000 (the standard sunab "control" code).
panel[, gn := fifelse(is.na(g_emb) | g_emb == 0L, 10000L, as.integer(g_emb))]

caps <- as.data.table(read_parquet(file.path(PROC, "cnes_caps_cir_municipality_year.parquet")))
caps[, municipality := as.character(municipality)]
CAPS_LAST_YEAR <- max(caps$year)            # 2016
cat("CAPS coverage:", min(caps$year), "-", CAPS_LAST_YEAR,
    "| treated munis:", panel[gn < 10000, uniqueN(codmun_6)], "\n")

# Treated municipalities (the flow-exposed PNASH catchment = the panel treated set;
# verified that pnash_psychiatric_closures flow_exposed == these 104 munis).
treated <- unique(panel[gn < 10000, .(codmun_6, g_emb = as.integer(g_emb))])

# Baseline own-municipality CAPS at closure_year-1; cap measurement year at the
# last available CAPS year (2016) for any cohort whose t-1 exceeds coverage and
# flag it. Here max(g_emb)=2017 so t-1=2016 is in-coverage: 0 capped, but the
# guard is kept honest and explicit.
treated[, caps_meas_year := pmin(g_emb - 1L, CAPS_LAST_YEAR)]
treated[, caps_year_capped := (g_emb - 1L) > CAPS_LAST_YEAR]
treated <- merge(treated, caps[, .(codmun_6 = municipality, year, caps_facilities)],
                 by.x = c("codmun_6", "caps_meas_year"), by.y = c("codmun_6", "year"),
                 all.x = TRUE)
# CAPS facility count: NA only if genuinely absent from the CAPS file. We do NOT
# impute. (Verified all 104 present.) Treat NA as "unknown", excluded from split.
treated[, has_baseline_caps := caps_facilities >= 1]

cat("\n=== baseline CAPS facility count (own muni, closure_year-1) ===\n")
print(treated[, .N, by = caps_facilities][order(caps_facilities)])
cat("capped at", CAPS_LAST_YEAR, "(t-1 beyond coverage):", sum(treated$caps_year_capped), "\n")
cat("NA (absent from CAPS file):", sum(is.na(treated$caps_facilities)), "\n")
n_high <- treated[has_baseline_caps == TRUE, .N]
n_low  <- treated[has_baseline_caps == FALSE, .N]
cat(sprintf("SPLIT (any CAPS present): HIGH=%d  LOW=%d  (median count=%g -> above/below-median degenerate)\n",
            n_high, n_low, median(treated$caps_facilities, na.rm = TRUE)))

high_munis <- treated[has_baseline_caps == TRUE, codmun_6]
low_munis  <- treated[has_baseline_caps == FALSE, codmun_6]

# ---------------------------------------------------------------------------
# Split-sample pop-weighted Sun-Abraham ATT
# ---------------------------------------------------------------------------
estimate_group <- function(y, subgroup_munis, label) {
  d <- panel[(gn >= 10000) | (codmun_6 %in% subgroup_munis)]
  d <- d[is.finite(get(y)) & is.finite(pop) & pop > 0]
  n_tr <- d[gn < 10000, uniqueN(codmun_6)]
  fail <- function(msg) data.table(outcome = y, subgroup = label, n_treated = n_tr,
                                   att = NA_real_, se = NA_real_, ci_lo = NA_real_,
                                   ci_hi = NA_real_, baseline_rate = NA_real_, status = msg)
  if (n_tr < 3) return(fail("too few treated municipalities"))
  fit <- tryCatch(
    feols(as.formula(sprintf("%s ~ sunab(gn, year) | codmun_6 + year", y)),
          d, cluster = "codmun_6", weights = ~pop, warn = FALSE, notes = FALSE),
    error = function(e) e)
  if (inherits(fit, "error")) return(fail(fit$message))
  a <- tryCatch(summary(fit, agg = "att"), error = function(e) e)
  if (inherits(a, "error")) return(fail(a$message))
  att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  base <- d[gn < 10000 & year < gn & is.finite(pop) & pop > 0]
  baseline <- if (nrow(base)) weighted.mean(base[[y]], base$pop, na.rm = TRUE) else NA_real_
  data.table(outcome = y, subgroup = label, n_treated = n_tr,
             att = att, se = se, ci_lo = att - 1.96 * se, ci_hi = att + 1.96 * se,
             baseline_rate = baseline, status = "ok")
}

outcomes <- c("suicide_per100k", "selfharm_per100k", "psych_adm_per1k")
groups <- list(
  list(label = "High baseline CAPS (any present)", munis = high_munis),
  list(label = "Low baseline CAPS (none)",         munis = low_munis),
  list(label = "All treated",                      munis = c(high_munis, low_munis))
)

parts <- list()
for (y in outcomes) for (g in groups)
  parts[[length(parts) + 1]] <- estimate_group(y, g$munis, g$label)
res <- rbindlist(parts, fill = TRUE)

outcome_label <- c(suicide_per100k = "Suicide (per 100k)",
                   selfharm_per100k = "Self-harm (per 100k)",
                   psych_adm_per1k = "Psych. admissions (per 1k)")
res[, outcome_pretty := outcome_label[outcome]]

cat("\n=== subgroup ATT estimates ===\n")
print(res[, .(outcome, subgroup, n_treated, att = round(att, 3),
              se = round(se, 3), ci_lo = round(ci_lo, 3), ci_hi = round(ci_hi, 3),
              status)])

# Tidy CSV as specified: outcome, subgroup, n_treated, att, se, ci_lo, ci_hi
fwrite(res[, .(outcome, subgroup, n_treated, att, se, ci_lo, ci_hi,
               baseline_rate, status)], csv_out)
cat("\nwrote:", csv_out, "rows=", nrow(res), "\n")

# ---------------------------------------------------------------------------
# Informativeness check: is the High-vs-Low difference detectable for any outcome?
# Reported descriptively (independent-sample z on the two subgroup ATTs).
# ---------------------------------------------------------------------------
cat("\n=== High-vs-Low differential (descriptive z-test on subgroup ATTs) ===\n")
diff_tbl <- list()
for (y in outcomes) {
  hi <- res[outcome == y & subgroup == "High baseline CAPS (any present)"]
  lo <- res[outcome == y & subgroup == "Low baseline CAPS (none)"]
  if (nrow(hi) && nrow(lo) && is.finite(hi$att) && is.finite(lo$att) &&
      is.finite(hi$se) && is.finite(lo$se)) {
    d <- hi$att - lo$att
    sed <- sqrt(hi$se^2 + lo$se^2)
    z <- d / sed
    p <- 2 * pnorm(-abs(z))
    cat(sprintf("  %-26s diff(High-Low)=%+.3f  se=%.3f  z=%+.2f  p=%.3f\n",
                outcome_label[y], d, sed, z, p))
    diff_tbl[[y]] <- data.table(outcome = y, diff = d, se_diff = sed, z = z, p = p)
  } else {
    cat(sprintf("  %-26s diff not computable (degenerate/NA subgroup)\n", outcome_label[y]))
  }
}
diff_dt <- rbindlist(diff_tbl, fill = TRUE)

# ---------------------------------------------------------------------------
# LaTeX appendix table (booktabs + threeparttable), standalone \input fragment.
# Produced regardless: a clean "no detectable differential (underpowered)" table
# is itself informative.
# ---------------------------------------------------------------------------
fmt  <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmt2 <- function(x) ifelse(is.finite(x), sprintf("%.2f", x), "--")

ord_groups <- c("High baseline CAPS (any present)", "Low baseline CAPS (none)", "All treated")
body <- c()
for (y in outcomes) {
  body <- c(body, sprintf("\\multicolumn{5}{l}{\\textit{%s}}\\\\", outcome_label[y]))
  for (gl in ord_groups) {
    r <- res[outcome == y & subgroup == gl]
    if (!nrow(r)) next
    ci <- if (is.finite(r$ci_lo)) sprintf("[%s, %s]", fmt(r$ci_lo), fmt(r$ci_hi)) else "--"
    body <- c(body, sprintf("\\quad %s & %d & %s & %s & %s \\\\",
                            gl, r$n_treated, fmt(r$att),
                            if (is.finite(r$se)) fmt2(r$se) else "--", ci))
  }
}

tex <- c(
  "% Auto-generated by 03_analysis/86_caps_heterogeneity.R -- do not edit by hand.",
  "\\begin{table}[!htbp]\\centering",
  "\\begin{threeparttable}",
  "\\caption{Closure effect by baseline community mental-health (CAPS) facility presence in the exposed catchment}",
  "\\label{tab:caps-heterogeneity}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  "Subgroup & Treated munis. & ATT & SE & 95\\% CI \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  "\\item \\textit{Notes.} Population-weighted Sun--Abraham (2021) event-study ATT estimates with",
  "municipality and year fixed effects; standard errors clustered by municipality and",
  "95\\% confidence intervals. Each subgroup keeps all never-treated municipalities and only",
  "the treated municipalities in that subgroup. Treated municipalities are the flow-exposed",
  "PNASH closure catchment ($N=104$). The split is on \\emph{baseline community mental-health",
  "(CAPS) facility presence}: a municipality is ``High'' if it had at least one CAPS",
  "establishment (CNES \\texttt{TP\\_UNID}=70) in the year before closure and ``Low'' otherwise;",
  sprintf("at baseline %d treated municipalities had a CAPS and %d had none. CAPS data are a", n_high, n_low),
  "\\emph{facility count}, not beds, residential (SRT) capacity, or outpatient production, and",
  "national CAPS coverage ends in 2016. With $\\sim$104 treated municipalities split two ways,",
  "statistical power is very limited; these estimates are descriptive/suggestive, not decisive,",
  "and the design observes inpatient care and mortality but cannot fully verify whether outpatient",
  "care absorbed displaced patients.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")

cat("\n=== verdict inputs ===\n")
cat("n_high:", n_high, " n_low:", n_low, "\n")
if (nrow(diff_dt)) {
  cat("any High-vs-Low differential with p<0.05?:",
      any(is.finite(diff_dt$p) & diff_dt$p < 0.05), "\n")
}
cat("\npeak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
