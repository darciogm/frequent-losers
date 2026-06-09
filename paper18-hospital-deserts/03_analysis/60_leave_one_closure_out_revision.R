#!/usr/bin/env Rscript
# Leave-one-closure-catchment-out influence diagnostics for the PNASH sample.

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = FALSE)
trailing <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% trailing
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC <- file.path(ROOT, "02_data", "processed")
TAB <- file.path(ROOT, "01_manuscript", "tables")
FIG <- file.path(ROOT, "04_figures")
LOG <- file.path(ROOT, "04_logs")
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG, showWarnings = FALSE, recursive = TRUE)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(LOG, sprintf("60_leave_one_closure_out_revision_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
cat("script: 60_leave_one_closure_out_revision.R\n")
cat("started:", format(started, "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("force:", force, "\n")
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
cat("git_sha:", paste(git_sha, collapse = " "), "\n")
cat("R:", R.version.string, "\n")
cat("packages:", paste(c(
  paste0("arrow=", as.character(packageVersion("arrow"))),
  paste0("data.table=", as.character(packageVersion("data.table"))),
  paste0("fixest=", as.character(packageVersion("fixest"))),
  paste0("ggplot2=", as.character(packageVersion("ggplot2")))
), collapse = "; "), "\n")

csv_out <- file.path(PROC, "leave_one_closure_out_revision.csv")
tex_out <- file.path(TAB, "table_closure_level_inference.tex")
fig_suicide <- file.path(FIG, "fig_leave_one_closure_out_suicide.pdf")
fig_selfharm <- file.path(FIG, "fig_leave_one_closure_out_selfharm.pdf")
outs <- c(csv_out, tex_out, fig_suicide, fig_selfharm)
if (!force && any(file.exists(outs))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(outs[file.exists(outs)], collapse = ", "))
}

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
panel[, `:=`(
  codmun_6 = as.character(codmun_6),
  year = as.integer(year),
  gn = fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))
)]

exposure_file <- file.path(PROC, "exposure_variants_long.parquet")
if (file.exists(exposure_file)) {
  exposure <- as.data.table(read_parquet(exposure_file))
  exposure <- exposure[
    sample_id == "pnash48" &
      exposure_definition == "flow_all_admissions" &
      exposure_window == "yminus1" &
      treated_005 == TRUE,
    .(CNES = as.character(cnes),
      closure_year = as.integer(closure_year),
      codmun_6 = as.character(municipality),
      share = as.numeric(share),
      numerator = as.numeric(numerator))
  ]
} else {
  exposure <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))
  pnash_events <- as.data.table(read_parquet(file.path(PROC, "pnash_event_level_dataset.parquet")))
  exposure[, `:=`(CNES = as.character(CNES), codmun_6 = as.character(codmun_6))]
  pnash_events[, CNES := as.character(CNES)]
  exposure <- exposure[pnash_events[, .(CNES, closure_year)], on = "CNES", nomatch = 0]
  exposure <- exposure[exposed_emb == TRUE,
                       .(CNES, closure_year = as.integer(closure_year),
                         codmun_6, share = as.numeric(share_emb),
                         numerator = as.numeric(n_aih_pre))]
}

events <- unique(exposure[, .(CNES, closure_year)])
event_meta_file <- file.path(PROC, "pnash_event_level_dataset.parquet")
if (file.exists(event_meta_file)) {
  meta <- as.data.table(read_parquet(event_meta_file))
  meta[, `:=`(CNES = as.character(CNES), hospital_municipality = as.character(municipality))]
  events <- meta[, .(CNES, closure_year = as.integer(closure_year), hospital_municipality)][
    events, on = .(CNES, closure_year)
  ]
} else {
  events[, hospital_municipality := NA_character_]
}
events[, closure_id := paste0(CNES, "_", closure_year)]
exposure <- events[, .(CNES, closure_year, closure_id)][exposure, on = .(CNES, closure_year)]

cat("panel rows:", nrow(panel), " municipalities:", panel[, uniqueN(codmun_6)],
    " treated municipalities:", panel[gn < 10000, uniqueN(codmun_6)], "\n")
cat("PNASH closures with exposed catchments:", events[, uniqueN(closure_id)],
    " exposure pairs:", nrow(exposure),
    " exposed municipalities:", exposure[, uniqueN(codmun_6)], "\n")

estimate <- function(dat, y) {
  d <- dat[is.finite(get(y)) & is.finite(pop) & pop > 0]
  fit <- feols(
    as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y)),
    data = d,
    cluster = "muni_id",
    weights = ~pop,
    warn = FALSE,
    notes = FALSE
  )
  a <- summary(fit, agg = "att")
  att <- as.numeric(coef(a)[1])
  se <- as.numeric(se(a)[1])
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       n_obs = nobs(fit), n_treated = d[gn < 10000, uniqueN(codmun_6)])
}

outcomes <- data.table(
  outcome = c("suicide_per100k", "selfharm_per100k"),
  outcome_label = c("Suicide", "Self-harm")
)

baseline <- rbindlist(lapply(outcomes$outcome, function(y) {
  est <- estimate(panel, y)
  data.table(
    outcome = y,
    closure_id = "baseline",
    CNES = NA_character_,
    closure_year = NA_integer_,
    hospital_municipality = NA_character_,
    omitted_exposed_municipalities = 0L,
    omitted_municipality_closure_pairs = 0L,
    mean_omitted_share = NA_real_,
    att = est$att,
    se = est$se,
    lo = est$lo,
    hi = est$hi,
    n_obs = est$n_obs,
    n_treated = est$n_treated
  )
}))
baseline <- outcomes[baseline, on = "outcome"]

loo <- rbindlist(lapply(seq_len(nrow(events)), function(i) {
  ev <- events[i]
  omit <- exposure[closure_id == ev$closure_id]
  omitted_munis <- unique(omit$codmun_6)
  dat <- panel[!codmun_6 %in% omitted_munis]
  rbindlist(lapply(outcomes$outcome, function(y) {
    est <- tryCatch(estimate(dat, y), error = function(e) e)
    if (inherits(est, "error")) {
      cat("FAILED:", ev$closure_id, y, est$message, "\n")
      return(data.table(
        outcome = y,
        closure_id = ev$closure_id,
        CNES = ev$CNES,
        closure_year = ev$closure_year,
        hospital_municipality = ev$hospital_municipality,
        omitted_exposed_municipalities = length(omitted_munis),
        omitted_municipality_closure_pairs = nrow(omit),
        mean_omitted_share = mean(omit$share, na.rm = TRUE),
        att = NA_real_, se = NA_real_, lo = NA_real_, hi = NA_real_,
        n_obs = nrow(dat), n_treated = dat[gn < 10000, uniqueN(codmun_6)]
      ))
    }
    data.table(
      outcome = y,
      closure_id = ev$closure_id,
      CNES = ev$CNES,
      closure_year = ev$closure_year,
      hospital_municipality = ev$hospital_municipality,
      omitted_exposed_municipalities = length(omitted_munis),
      omitted_municipality_closure_pairs = nrow(omit),
      mean_omitted_share = mean(omit$share, na.rm = TRUE),
      att = est$att,
      se = est$se,
      lo = est$lo,
      hi = est$hi,
      n_obs = est$n_obs,
      n_treated = est$n_treated
    )
  }))
}))
loo <- outcomes[loo, on = "outcome"]

base_lookup <- baseline[, .(outcome, baseline_att = att, baseline_se = se)]
res <- rbindlist(list(baseline, loo), fill = TRUE)
res <- base_lookup[res, on = "outcome"]
res[, `:=`(
  delta_att = att - baseline_att,
  abs_delta_att = abs(att - baseline_att),
  ci_excludes_zero = is.finite(lo) & is.finite(hi) & (lo > 0 | hi < 0)
)]
res[closure_id == "baseline", `:=`(delta_att = 0, abs_delta_att = 0)]
loo <- res[closure_id != "baseline"]
setcolorder(res, c(
  "outcome", "outcome_label", "closure_id", "CNES", "closure_year",
  "hospital_municipality", "omitted_exposed_municipalities",
  "omitted_municipality_closure_pairs", "mean_omitted_share",
  "att", "se", "lo", "hi", "baseline_att", "baseline_se",
  "delta_att", "abs_delta_att", "ci_excludes_zero", "n_obs", "n_treated"
))
fwrite(res, csv_out)
cat("wrote:", csv_out, " rows=", nrow(res), "\n")

summ <- loo[is.finite(att), .(
  baseline_att = unique(baseline_att),
  baseline_se = unique(baseline_se),
  min_att = min(att),
  max_att = max(att),
  max_abs_delta = max(abs_delta_att),
  most_influential_closure = closure_id[which.max(abs_delta_att)],
  most_influential_year = closure_year[which.max(abs_delta_att)],
  most_influential_omitted_munis = omitted_exposed_municipalities[which.max(abs_delta_att)],
  most_influential_att = att[which.max(abs_delta_att)],
  any_ci_excludes_zero = any(ci_excludes_zero, na.rm = TRUE),
  closures_checked = .N
), by = .(outcome, outcome_label)]

fmt <- function(x, digits = 2) ifelse(is.finite(x), formatC(x, format = "f", digits = digits), "--")
latex_escape <- function(x) {
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  gsub("([_&%$#{}])", "\\\\\\1", x, perl = TRUE)
}
rows <- summ[, sprintf(
  "%s & %s & [%s, %s] & %s & %s & %s & %s & %s \\\\",
  latex_escape(outcome_label),
  fmt(baseline_att),
  fmt(min_att),
  fmt(max_att),
  fmt(max_abs_delta),
  latex_escape(most_influential_closure),
  most_influential_year,
  most_influential_omitted_munis,
  ifelse(any_ci_excludes_zero, "yes", "no")
)]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Closure-catchment influence diagnostics}",
  "\\label{tab:closure-level-inference}",
  "\\small",
  "\\resizebox{\\textwidth}{!}{%",
  "\\begin{tabular}{lccccccc}",
  "\\toprule",
  "Outcome & Baseline ATT & Leave-one-out range & Max $|\\Delta|$ & Most influential closure & Year & Omitted munis & Any CI excludes 0 \\\\",
  "\\midrule",
  rows,
  "\\bottomrule",
  "\\multicolumn{8}{p{0.96\\textwidth}}{\\footnotesize Notes: The diagnostic re-estimates the population-weighted Sun--Abraham headline specification after omitting, one PNASH closure at a time, all municipalities exposed to that closure by the patient-flow rule ($\\theta=0.05$, all SUS admissions in year $-1$). Exact closure-catchment clustering is not well-defined in this panel because some municipalities can be exposed to more than one closing hospital and never-treated controls have no closure catchment. The table therefore reports leave-one-closure-catchment-out influence rather than a clustered standard error at the closure level.}\\\\",
  "\\end{tabular}",
  "}%",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")

plot_one <- function(y, path, title) {
  d <- copy(loo[outcome == y & is.finite(att)])
  b <- baseline[outcome == y, att]
  d[, label := paste0(CNES, " (", closure_year, ")")]
  d <- d[order(att)]
  d[, label := factor(label, levels = label)]
  ggplot(d, aes(x = label, y = att)) +
    geom_hline(yintercept = 0, color = "gray55", linewidth = 0.35, linetype = "dashed") +
    geom_hline(yintercept = b, color = "#D55E00", linewidth = 0.45) +
    geom_pointrange(aes(ymin = lo, ymax = hi), color = "#0072B2", linewidth = 0.35, size = 0.25) +
    coord_flip() +
    labs(x = "Omitted PNASH closure catchment", y = "Leave-one-out ATT",
         title = title) +
    theme_minimal(base_size = 8.5) +
    theme(panel.grid.minor = element_blank(),
          axis.text.y = element_text(size = 5.5),
          plot.title = element_text(size = 10))
  ggsave(path, width = 6.2, height = 7.4, device = "pdf")
  cat("wrote:", path, "\n")
}

plot_one("suicide_per100k", fig_suicide, "Suicide: leave-one-closure-catchment-out")
plot_one("selfharm_per100k", fig_selfharm, "Self-harm: leave-one-closure-catchment-out")

print(summ)
cat("failed leave-one-out rows:", loo[!is.finite(att), .N], "\n")
w <- warnings()
if (!is.null(w)) {
  cat("warnings_recorded:\n")
  print(w)
} else {
  cat("warnings_recorded: none\n")
}
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
