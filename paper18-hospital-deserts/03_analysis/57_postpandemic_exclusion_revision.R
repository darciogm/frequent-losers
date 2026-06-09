#!/usr/bin/env Rscript
# Exclude post-pandemic closure cohorts where present and re-estimate headline rows.

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
log_file <- file.path(LOG, sprintf("57_postpandemic_exclusion_revision_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
cat("script: 57_postpandemic_exclusion_revision.R\n")
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

csv_out <- file.path(PROC, "postpandemic_exclusion_revision.csv")
tex_out <- file.path(TAB, "tab_postpandemic_exclusion_revision.tex")
if (!force && any(file.exists(c(csv_out, tex_out)))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(c(csv_out, tex_out)[file.exists(c(csv_out, tex_out))], collapse = ", "))
}

estimate <- function(panel_path, sample_label, y, outcome_label, wt = TRUE) {
  d0 <- as.data.table(read_parquet(panel_path))
  d0[, gn := fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  cohorts_present <- sort(unique(d0[gn < 10000, gn]))
  post_munis <- d0[gn %in% 2022:2023, unique(muni_id)]
  d <- d0[!(muni_id %in% post_munis)]
  d[, gn := fifelse(gn %in% 2022:2023, 10000L, gn)]
  d <- d[is.finite(get(y))]
  if (wt) d <- d[is.finite(pop) & pop > 0]
  fit <- tryCatch({
    if (wt) feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y)),
                  d, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
    else feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y)),
               d, cluster = "muni_id", warn = FALSE, notes = FALSE)
  }, error = function(e) e)
  if (inherits(fit, "error")) {
    return(data.table(sample = sample_label, outcome = outcome_label, att = NA_real_, se = NA_real_,
                      lo = NA_real_, hi = NA_real_, n_treated = d[gn < 10000, uniqueN(muni_id)],
                      excluded_municipalities = length(post_munis),
                      cohorts_present = paste(cohorts_present, collapse = ", "),
                      status = fit$message))
  }
  a <- summary(fit, agg = "att")
  att <- as.numeric(coef(a)[1])
  se <- as.numeric(se(a)[1])
  data.table(sample = sample_label, outcome = outcome_label, att = att, se = se,
             lo = att - 1.96 * se, hi = att + 1.96 * se,
             n_treated = d[gn < 10000, uniqueN(muni_id)],
             excluded_municipalities = length(post_munis),
             cohorts_present = paste(cohorts_present, collapse = ", "),
             status = "ok")
}

samples <- list(
  "PNASH psychiatric closures" = "staggered_panel_pnash48_ext.parquet",
  "All psychiatric closures" = "staggered_panel_psymax60_ext.parquet"
)
outcomes <- list(
  suicide_per100k = "Suicide",
  selfharm_per100k = "Self-harm",
  travel_burden_km = "Travel burden"
)

res <- rbindlist(lapply(names(samples), function(s) {
  path <- file.path(INTER, samples[[s]])
  rbindlist(lapply(names(outcomes), function(y) estimate(path, s, y, outcomes[[y]], wt = y != "travel_burden_km")))
}), fill = TRUE)
fwrite(res, csv_out)
cat("wrote:", csv_out, " rows=", nrow(res), "\n")

fmt <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
sample_short <- c(
  "PNASH psychiatric closures" = "PNASH psych.",
  "All psychiatric closures" = "All psych."
)
cohort_label <- function(x) {
  vals <- as.integer(trimws(unlist(strsplit(x, ","))))
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0) return("--")
  runs <- split(vals, cumsum(c(TRUE, diff(vals) != 1)))
  paste(vapply(runs, function(v) {
    if (length(v) == 1) as.character(v) else sprintf("%d--%d", min(v), max(v))
  }, character(1)), collapse = "; ")
}
rows <- res[, sprintf("%s & %s & %s & [%s, %s] & %s & %s & %s \\\\",
                      sample_short[sample], outcome, fmt(att), fmt(lo), fmt(hi),
                      n_treated, excluded_municipalities, cohort_label(cohorts_present))]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Robustness excluding 2022--2023 closure cohorts}",
  "\\label{tab:postpandemic-exclusion-revision}",
  "\\small",
  "\\resizebox{\\textwidth}{!}{%",
  "\\begin{tabular}{llccccc}",
  "\\toprule",
  "Sample & Outcome & ATT & 95\\% CI & Treated & Excluded & Cohorts \\\\",
  "\\midrule",
  rows,
  "\\bottomrule",
  "\\end{tabular}",
  "}%",
  "\\vspace{0.3em}",
  "\\begin{minipage}{0.96\\textwidth}\\footnotesize Notes: Rows drop municipalities whose first assigned closure cohort is 2022 or 2023 when such cohorts are present. The PNASH panel contains no 2022--2023 treated cohorts in the current generated file, so that row is an explicit no-change audit.\\end{minipage}",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")
cat("post-pandemic exclusions by sample:\n")
print(res[, .(excluded_municipalities = max(excluded_municipalities), cohorts_present = first(cohorts_present)), by = sample])
cat("failed rows:", res[status != "ok", .N], "\n")
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
