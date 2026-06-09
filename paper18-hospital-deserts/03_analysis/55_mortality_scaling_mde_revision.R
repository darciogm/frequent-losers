#!/usr/bin/env Rscript
# Mortality scaling and minimum detectable effect calculations.

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
})

args <- commandArgs(trailingOnly = FALSE)
trailing <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% trailing
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC <- file.path(ROOT, "02_data", "processed")
TAB <- file.path(ROOT, "01_manuscript", "tables")
LOG <- file.path(ROOT, "04_logs")
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG, showWarnings = FALSE, recursive = TRUE)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(LOG, sprintf("55_mortality_scaling_mde_revision_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
cat("script: 55_mortality_scaling_mde_revision.R\n")
cat("started:", format(started, "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("force:", force, "\n")
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
cat("git_sha:", paste(git_sha, collapse = " "), "\n")
cat("R:", R.version.string, "\n")
cat("packages:", paste(c(
  paste0("arrow=", as.character(packageVersion("arrow"))),
  paste0("data.table=", as.character(packageVersion("data.table"))),
  paste0("fixest=", as.character(packageVersion("fixest")))
), collapse = "; "), "\n")

csv_out <- file.path(PROC, "mortality_scaling_mde_revision.csv")
tex_out <- file.path(TAB, "tab_mortality_scaling_mde_revision.tex")
if (!force && any(file.exists(c(csv_out, tex_out)))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(c(csv_out, tex_out)[file.exists(c(csv_out, tex_out))], collapse = ", "))
}

panel_file <- file.path(PROC, "revision_pnash48_panel.parquet")
if (file.exists(panel_file)) {
  panel <- as.data.table(read_parquet(panel_file))
} else {
  panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
  psych <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
  psych <- psych[, .(codmun_6 = as.character(codmun_6), year = as.integer(year), n_psych_adm)]
  panel[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]
  panel <- merge(panel, psych, by = c("codmun_6", "year"), all.x = TRUE)
}
panel[, gn := fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]

estimate <- function(y) {
  d <- panel[is.finite(get(y)) & is.finite(pop) & pop > 0]
  fit <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y)),
               d, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
  a <- summary(fit, agg = "att")
  att <- as.numeric(coef(a)[1])
  se <- as.numeric(se(a)[1])
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se, n_obs = nobs(fit))
}

weighted_mean <- function(x, w) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  weighted.mean(x[ok], w[ok])
}

scale_outcome <- function(y, label) {
  est <- estimate(y)
  base <- panel[gn < 10000 & year < gn & is.finite(get(y)) & is.finite(pop) & pop > 0]
  baseline_rate <- weighted_mean(base[[y]], base$pop)
  baseline_pop_year <- base[, .(pop = mean(pop, na.rm = TRUE)), by = muni_id][, sum(pop, na.rm = TRUE)]
  baseline_psych_adm_year <- base[is.finite(n_psych_adm), .(psych = mean(n_psych_adm, na.rm = TRUE)), by = muni_id][, sum(psych, na.rm = TRUE)]
  implied_deaths <- est$att / 100000 * baseline_pop_year
  implied_lo <- est$lo / 100000 * baseline_pop_year
  implied_hi <- est$hi / 100000 * baseline_pop_year
  per_1000_adm <- if (is.finite(baseline_psych_adm_year) && baseline_psych_adm_year > 0) {
    implied_deaths / baseline_psych_adm_year * 1000
  } else NA_real_
  mde <- (qnorm(0.975) + qnorm(0.8)) * est$se
  data.table(
    outcome = label,
    baseline_rate_per100k = baseline_rate,
    att_per100k = est$att,
    lo_per100k = est$lo,
    hi_per100k = est$hi,
    implied_deaths_per_year = implied_deaths,
    implied_deaths_lo = implied_lo,
    implied_deaths_hi = implied_hi,
    deaths_per_1000_preclosure_psych_admissions = per_1000_adm,
    percent_of_baseline = 100 * est$att / baseline_rate,
    upper_ci_percent_of_baseline = 100 * est$hi / baseline_rate,
    mde_per100k = mde,
    baseline_population_year = baseline_pop_year,
    baseline_psych_admissions_year = baseline_psych_adm_year,
    n_obs = est$n_obs
  )
}

res <- rbindlist(list(
  scale_outcome("suicide_per100k", "Suicide"),
  scale_outcome("selfharm_per100k", "Self-harm")
))
fwrite(res, csv_out)
cat("wrote:", csv_out, " rows=", nrow(res), "\n")

fmt <- function(x, digits = 2) ifelse(is.finite(x), formatC(x, format = "f", digits = digits, big.mark = ","), "--")
rows <- res[, sprintf("%s & %s & %s & [%s, %s] & %s & %s & %s \\\\",
                      outcome,
                      fmt(baseline_rate_per100k, 2),
                      fmt(att_per100k, 2),
                      fmt(lo_per100k, 2),
                      fmt(hi_per100k, 2),
                      fmt(implied_deaths_per_year, 1),
                      fmt(deaths_per_1000_preclosure_psych_admissions, 2),
                      fmt(mde_per100k, 2))]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Scaling mortality estimates. ATT estimates are population-weighted Sun--Abraham effects for PNASH psychiatric closures. Implied deaths multiply the per-100,000 estimate by the average pre-closure exposed-municipality population. Psychiatric admissions are SUS episodes, not unique patients. MDE is the two-sided 5\\% significance, 80\\% power minimum detectable effect using the estimated standard error.}",
  "\\label{tab:mortality-scaling-mde-revision}",
  "\\small",
  "\\begin{tabular}{lcccccc}",
  "\\toprule",
  "Outcome & Baseline rate & ATT & 95\\% CI & Deaths/year & Deaths/1,000 psych admissions & MDE \\\\",
  "\\midrule",
  rows,
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")
cat("baseline note: psychiatric admissions are episodes, not persons.\n")
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
