#!/usr/bin/env Rscript
# Fixed-effect sensitivity table for mortality, travel, and psychiatric admissions.

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
log_file <- file.path(LOG, sprintf("54_fe_sensitivity_revision_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
cat("script: 54_fe_sensitivity_revision.R\n")
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

csv_out <- file.path(PROC, "fe_sensitivity_revision.csv")
tex_out <- file.path(TAB, "tab_fe_sensitivity_revision.tex")
if (!force && any(file.exists(c(csv_out, tex_out)))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(c(csv_out, tex_out)[file.exists(c(csv_out, tex_out))], collapse = ", "))
}

macro_region <- function(uf) {
  fifelse(uf %in% c("AC", "AP", "AM", "PA", "RO", "RR", "TO"), "North",
  fifelse(uf %in% c("AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE"), "Northeast",
  fifelse(uf %in% c("DF", "GO", "MT", "MS"), "Center-West",
  fifelse(uf %in% c("ES", "MG", "RJ", "SP"), "Southeast",
  fifelse(uf %in% c("PR", "RS", "SC"), "South", NA_character_)))))
}

panel_file <- file.path(PROC, "revision_pnash48_panel.parquet")
if (!file.exists(panel_file)) {
  panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
  psych <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
  psych <- psych[, .(codmun_6 = as.character(codmun_6), year = as.integer(year), psych_adm_per1k)]
  panel[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]
  panel <- merge(panel, psych, by = c("codmun_6", "year"), all.x = TRUE)
} else {
  panel <- as.data.table(read_parquet(panel_file))
}
panel[, `:=`(
  gn = fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb)),
  macroregion = macro_region(uf),
  year_center = as.numeric(year - 2010)
)]
panel[, `:=`(
  uf_year = interaction(uf, year, drop = TRUE),
  macro_year = interaction(macroregion, year, drop = TRUE)
)]

outcomes <- list(
  suicide_per100k = list(label = "Suicide mortality", weight = TRUE, scale = "per 100,000"),
  selfharm_per100k = list(label = "Self-harm mortality", weight = TRUE, scale = "per 100,000"),
  travel_burden_km = list(label = "Travel burden", weight = FALSE, scale = "km"),
  psych_adm_per1k = list(label = "Psychiatric admissions", weight = FALSE, scale = "per 1,000")
)
specs <- list(
  "Municipality and year FE" = "%s ~ sunab(gn, year) | muni_id + year",
  "Municipality and state-year FE" = "%s ~ sunab(gn, year) | muni_id + uf_year",
  "Municipality and macroregion-year FE" = "%s ~ sunab(gn, year) | muni_id + macro_year",
  "State-specific linear trends" = "%s ~ sunab(gn, year) + uf:year_center | muni_id + year",
  "Macroregion-specific linear trends" = "%s ~ sunab(gn, year) + macroregion:year_center | muni_id + year"
)

estimate <- function(y, spec_name, spec_tpl, wt) {
  d <- panel[is.finite(get(y))]
  if (wt) d <- d[is.finite(pop) & pop > 0]
  fml <- as.formula(sprintf(spec_tpl, y))
  fit <- tryCatch({
    if (wt) feols(fml, d, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
    else feols(fml, d, cluster = "muni_id", warn = FALSE, notes = FALSE)
  }, error = function(e) e)
  if (inherits(fit, "error")) {
    cat("FAILED:", y, "|", spec_name, "|", fit$message, "\n")
    return(data.table(outcome = y, spec = spec_name, att = NA_real_, se = NA_real_,
                      lo = NA_real_, hi = NA_real_, p = NA_real_, n_obs = nrow(d),
                      n_treated = d[gn < 10000, uniqueN(muni_id)], status = fit$message))
  }
  a <- summary(fit, agg = "att")
  att <- as.numeric(coef(a)[1])
  se <- as.numeric(se(a)[1])
  data.table(outcome = y, spec = spec_name, att = att, se = se,
             lo = att - 1.96 * se, hi = att + 1.96 * se,
             p = 2 * (1 - pnorm(abs(att / se))), n_obs = nobs(fit),
             n_treated = d[gn < 10000, uniqueN(muni_id)], status = "ok")
}

res <- rbindlist(lapply(names(outcomes), function(y) {
  rbindlist(lapply(names(specs), function(s) estimate(y, s, specs[[s]], outcomes[[y]]$weight)))
}), fill = TRUE)
res[, `:=`(
  outcome_label = vapply(outcome, function(x) outcomes[[x]]$label, character(1)),
  scale = vapply(outcome, function(x) outcomes[[x]]$scale, character(1))
)]
spec_short <- c(
  "Municipality and year FE" = "Muni + year",
  "Municipality and state-year FE" = "Muni + state-year",
  "Municipality and macroregion-year FE" = "Muni + region-year",
  "State-specific linear trends" = "State trends",
  "Macroregion-specific linear trends" = "Region trends"
)
outcome_short <- c(
  "Suicide mortality" = "Suicide",
  "Self-harm mortality" = "Self-harm",
  "Travel burden" = "Travel",
  "Psychiatric admissions" = "Psych adm."
)
scale_short <- c(
  "per 100,000" = "per 100k",
  "per 1,000" = "per 1k",
  "km" = "km"
)
fwrite(res, csv_out)
cat("wrote:", csv_out, " rows=", nrow(res), "\n")

fmt <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmt_ci <- function(lo, hi) ifelse(is.finite(lo) & is.finite(hi), sprintf("[%+.2f, %+.2f]", lo, hi), "--")
rows <- res[, sprintf("%s & %s & %s & %s & %s & %s & %s \\\\",
                      outcome_short[outcome_label], spec_short[spec], scale_short[scale],
                      fmt(att), fmt_ci(lo, hi),
                      ifelse(is.finite(p), sprintf("%.3f", p), "--"),
                      ifelse(status == "ok", as.character(n_treated), "failed"))]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Fixed-effect sensitivity of event-study ATT estimates}",
  "\\label{tab:fe-sensitivity-revision}",
  "\\small",
  "\\resizebox{\\textwidth}{!}{%",
  "\\begin{tabular}{lllcccc}",
  "\\toprule",
  "Outcome & Specification & Scale & ATT & 95\\% CI & $p$-value & Treated \\\\",
  "\\midrule",
  rows,
  "\\bottomrule",
  "\\end{tabular}",
  "}%",
  "\\vspace{0.3em}",
  "\\begin{minipage}{0.96\\textwidth}\\footnotesize Notes: Sun--Abraham specifications on the PNASH psychiatric-closure panel. Mortality rows are population weighted; travel and psychiatric-admission rows are municipality weighted. Standard errors are clustered by municipality.\\end{minipage}",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")
cat("failed rows:", res[status != "ok", .N], "\n")
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
