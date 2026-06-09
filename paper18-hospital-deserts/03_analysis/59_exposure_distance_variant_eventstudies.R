#!/usr/bin/env Rscript
# Event-study estimates for exposure and distance measurement variants.

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
})
options(warn = 1)

args <- commandArgs(trailingOnly = FALSE)
trailing <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% trailing
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
PROC <- file.path(ROOT, "02_data", "processed")
TAB <- file.path(ROOT, "01_manuscript", "tables")
LOG <- file.path(ROOT, "04_logs")
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG, showWarnings = FALSE, recursive = TRUE)

csv_out <- file.path(PROC, "exposure_distance_variant_eventstudies.csv")
tex_out <- file.path(TAB, "table_exposure_distance_variant_eventstudies.tex")
if (!force && any(file.exists(c(csv_out, tex_out)))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(c(csv_out, tex_out)[file.exists(c(csv_out, tex_out))], collapse = ", "))
}

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(LOG, sprintf("59_exposure_distance_variant_eventstudies_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
cat("script: 59_exposure_distance_variant_eventstudies.R\n")
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

panel_path <- file.path(PROC, "revision_pnash48_panel.parquet")
exp_path <- file.path(PROC, "exposure_variants_long.parquet")
dist_path <- file.path(PROC, "distance_benchmark_exposures.parquet")
for (p in c(panel_path, exp_path, dist_path)) {
  if (!file.exists(p)) stop("Required input missing: ", p)
}

panel <- as.data.table(read_parquet(panel_path))
panel[, `:=`(
  codmun_6 = as.character(codmun_6),
  year = as.integer(year),
  muni_id = as.integer(muni_id)
)]

expv <- as.data.table(read_parquet(exp_path))
expv[, `:=`(
  municipality = as.character(municipality),
  closure_year = as.integer(closure_year),
  variant_family = "flow",
  variant_id = paste(exposure_definition, exposure_window, "theta005", sep = "__"),
  variant_label = paste0(exposure_definition, " / ", exposure_window)
)]
exp_treat <- expv[sample_id == "pnash48" & treated_005 == TRUE,
                  .(codmun_6 = municipality,
                    closure_year,
                    variant_family,
                    variant_id,
                    variant_label)]

dist <- as.data.table(read_parquet(dist_path))
dist[, `:=`(
  municipality = as.character(municipality),
  closure_year = as.integer(closure_year),
  variant_family = "distance",
  variant_id = paste0(benchmark_rule, "__distance_exposed"),
  variant_label = benchmark_rule
)]
dist_treat <- dist[sample_id == "pnash48" & distance_exposed == TRUE,
                   .(codmun_6 = municipality,
                     closure_year,
                     variant_family,
                     variant_id,
                     variant_label)]

variant_events <- rbindlist(list(exp_treat, dist_treat), use.names = TRUE)
variant_events <- unique(variant_events[!is.na(codmun_6) & !is.na(closure_year)])
variant_cohorts <- variant_events[, .(
  gn_variant = min(closure_year),
  n_municipality_closure_pairs = .N
), by = .(variant_family, variant_id, variant_label, codmun_6)]
variant_meta <- variant_cohorts[, .(
  n_treated_municipalities = uniqueN(codmun_6),
  n_municipality_closure_pairs = sum(n_municipality_closure_pairs),
  first_cohort = min(gn_variant),
  last_cohort = max(gn_variant)
), by = .(variant_family, variant_id, variant_label)]
variant_meta[, n_never_treated_municipalities := uniqueN(panel$codmun_6) - n_treated_municipalities]
setorder(variant_meta, variant_family, variant_id)
cat("variants:", nrow(variant_meta), "\n")
print(variant_meta)

outcomes <- list(
  suicide_per100k = list(label = "Suicide mortality", scale = "per 100,000", weighted = TRUE),
  selfharm_per100k = list(label = "Self-harm mortality", scale = "per 100,000", weighted = TRUE),
  travel_burden_km = list(label = "Travel burden", scale = "km", weighted = FALSE)
)
min_treated <- 20L
min_never_treated <- 20L

estimate_variant <- function(meta_row, outcome) {
  family <- meta_row$variant_family
  vid <- meta_row$variant_id
  vlab <- meta_row$variant_label
  n_treated <- as.integer(meta_row$n_treated_municipalities)
  n_never <- as.integer(meta_row$n_never_treated_municipalities)
  pairs <- as.integer(meta_row$n_municipality_closure_pairs)
  first_cohort <- as.integer(meta_row$first_cohort)
  last_cohort <- as.integer(meta_row$last_cohort)
  ylab <- outcomes[[outcome]]$label
  scale <- outcomes[[outcome]]$scale
  weighted <- outcomes[[outcome]]$weighted

  base <- data.table(
    variant_family = family,
    variant_id = vid,
    variant_label = vlab,
    outcome = outcome,
    outcome_label = ylab,
    scale = scale,
    att = NA_real_,
    se = NA_real_,
    lo = NA_real_,
    hi = NA_real_,
    p_value = NA_real_,
    n_obs = NA_integer_,
    n_treated_municipalities = n_treated,
    n_never_treated_municipalities = n_never,
    n_municipality_closure_pairs = pairs,
    first_cohort = first_cohort,
    last_cohort = last_cohort,
    status = NA_character_
  )
  if (n_treated < min_treated) {
    base[, status := sprintf("too few treated municipalities (<%d)", min_treated)]
    return(base)
  }
  if (n_never < min_never_treated) {
    base[, status := sprintf("too few never-treated controls (<%d)", min_never_treated)]
    return(base)
  }

  cohorts <- variant_cohorts[variant_id == vid, .(codmun_6, gn_variant)]
  d <- merge(copy(panel), cohorts, by = "codmun_6", all.x = TRUE)
  d[is.na(gn_variant), gn_variant := 10000L]
  d[, gn_variant := as.integer(gn_variant)]
  d <- d[is.finite(get(outcome))]
  if (weighted) d <- d[is.finite(pop) & pop > 0]
  base[, n_obs := nrow(d)]
  if (nrow(d) == 0L) {
    base[, status := "no usable observations"]
    return(base)
  }

  fml <- as.formula(sprintf("%s ~ sunab(gn_variant, year) | muni_id + year", outcome))
  fit <- tryCatch({
    if (weighted) {
      feols(fml, d, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
    } else {
      feols(fml, d, cluster = "muni_id", warn = FALSE, notes = FALSE)
    }
  }, error = function(e) e)

  if (inherits(fit, "error")) {
    base[, status := paste("failed:", fit$message)]
    cat("FAILED:", vid, "|", outcome, "|", fit$message, "\n")
    return(base)
  }

  att <- tryCatch(summary(fit, agg = "att"), error = function(e) e)
  if (inherits(att, "error")) {
    base[, status := paste("failed att aggregation:", att$message)]
    cat("FAILED ATT:", vid, "|", outcome, "|", att$message, "\n")
    return(base)
  }

  b <- as.numeric(coef(att)[1])
  s <- as.numeric(se(att)[1])
  if (!is.finite(b) || !is.finite(s)) {
    base[, status := "failed: non-finite ATT or SE"]
    return(base)
  }
  base[, `:=`(
    att = b,
    se = s,
    lo = b - 1.96 * s,
    hi = b + 1.96 * s,
    p_value = 2 * (1 - pnorm(abs(b / s))),
    n_obs = nobs(fit),
    status = "ok"
  )]
  base
}

results <- rbindlist(lapply(seq_len(nrow(variant_meta)), function(i) {
  m <- variant_meta[i]
  rbindlist(lapply(names(outcomes), function(y) estimate_variant(m, y)), fill = TRUE)
}), fill = TRUE)
setorder(results, variant_family, variant_id, outcome)
fwrite(results, csv_out)
cat("wrote:", csv_out, " rows=", nrow(results), "\n")
cat("status counts:\n")
print(results[, .N, by = status])

latex_escape <- function(x) {
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([_&%$#{}])", "\\\\\\1", x, perl = TRUE)
  x
}
fmt <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmt_ci <- function(lo, hi) ifelse(is.finite(lo) & is.finite(hi), sprintf("[%+.2f, %+.2f]", lo, hi), "--")
status_short <- function(x) {
  fifelse(x == "ok", "ok",
          fifelse(grepl("never-treated", x), "too few controls",
                  fifelse(grepl("treated municipalities", x), "too few treated", "failed")))
}

table_rows <- results[, sprintf(
  "%s & %s & %s & %s & %s & %s & %s & %s \\\\",
  latex_escape(variant_family),
  latex_escape(variant_label),
  latex_escape(outcome_label),
  as.character(n_treated_municipalities),
  fmt(att),
  fmt_ci(lo, hi),
  ifelse(is.finite(p_value), sprintf("%.3f", p_value), "--"),
  latex_escape(status_short(status))
)]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Event-study estimates under exposure and distance measurement variants}",
  "\\label{tab:exposure-distance-variant-eventstudies}",
  "\\scriptsize",
  "\\resizebox{\\textwidth}{!}{%",
  "\\begin{tabular}{lllrrrrl}",
  "\\toprule",
  "Family & Variant & Outcome & Treated munis & ATT & 95\\% CI & $p$-value & Status \\\\",
  "\\midrule",
  table_rows,
  "\\bottomrule",
  "\\multicolumn{8}{p{0.96\\textwidth}}{\\footnotesize Notes: Each row re-estimates a Sun--Abraham event-study with municipality and year fixed effects. Cohorts are the earliest closure year assigned to each municipality by the variant rule; never-treated municipalities are coded as cohort 10000. Mortality outcomes are population weighted and travel-burden estimates are municipality weighted. Standard errors are clustered by municipality. Variants with fewer than 20 treated municipalities or fewer than 20 never-treated controls are reported as status rows rather than estimated.}\\\\",
  "\\end{tabular}",
  "}%",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")

ok <- results[status == "ok"]
if (nrow(ok)) {
  cat("key ok results by outcome:\n")
  print(ok[, .(
    min_att = min(att),
    median_att = median(att),
    max_att = max(att),
    n_ok = .N
  ), by = outcome])
}
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
