#!/usr/bin/env Rscript
# Network-spillover mortality sensitivities for the PNASH causal sample.

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
PROC <- file.path(ROOT, "02_data", "processed")
TAB <- file.path(ROOT, "01_manuscript", "tables")
LOG <- file.path(ROOT, "04_logs")
dir.create(LOG, showWarnings = FALSE, recursive = TRUE)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(LOG, sprintf("73_jhe_spillover_sensitivity_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
cat("script: 73_jhe_spillover_sensitivity.R\n")
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

csv_out <- file.path(PROC, "spillover_sensitivity_estimates.csv")
tex_out <- file.path(TAB, "table_spillover_sensitivity.tex")
if (!force && any(file.exists(c(csv_out, tex_out)))) {
  stop("Refusing to overwrite existing outputs without --force")
}

panel <- as.data.table(read_parquet(file.path(PROC, "revision_pnash48_panel.parquet")))
flags <- as.data.table(read_parquet(file.path(PROC, "spillover_control_flags.parquet")))
panel[, codmun_6 := as.character(codmun_6)]
flags[, codmun_6 := as.character(codmun_6)]
panel <- flags[panel, on = "codmun_6"]
for (v in c("same_cir_as_closure_catchment", "shared_pre_referral_hub",
            "shared_substitute_hospital", "high_flow_similarity_to_treated",
            "contaminated_control_any")) {
  if (v == "shared_pre_referral_hub" && !"shared_pre_referral_hub" %in% names(panel) &&
      "same_top_referral_hub" %in% names(panel)) {
    panel[, shared_pre_referral_hub := same_top_referral_hub]
  }
  panel[is.na(get(v)), (v) := FALSE]
}
panel[, gn := as.integer(gn)]

rules <- data.table(
  rule = c("Baseline", "Exclude same-CIR controls", "Exclude shared-hub controls",
           "Exclude shared-substitute controls", "Exclude high-flow-similarity controls",
           "Exclude any network-contaminated controls"),
  flag = c(NA_character_, "same_cir_as_closure_catchment", "shared_pre_referral_hub",
           "shared_substitute_hospital", "high_flow_similarity_to_treated",
           "contaminated_control_any")
)
outcomes <- data.table(
  outcome = c("suicide_per100k", "selfharm_per100k"),
  label = c("Suicide", "Self-harm")
)

estimate <- function(d, y) {
  dd <- d[is.finite(get(y)) & is.finite(pop) & pop > 0]
  fit <- feols(
    as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y)),
    data = dd,
    cluster = "muni_id",
    weights = ~pop,
    warn = FALSE,
    notes = FALSE
  )
  a <- summary(fit, agg = "att")
  att <- as.numeric(coef(a)[1])
  se <- as.numeric(se(a)[1])
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       n_obs = nobs(fit),
       n_treated = dd[gn < 10000, uniqueN(codmun_6)],
       n_controls = dd[gn == 10000, uniqueN(codmun_6)])
}

rows <- rbindlist(lapply(seq_len(nrow(rules)), function(i) {
  r <- rules[i]
  d <- copy(panel)
  removed <- 0L
  if (!is.na(r$flag)) {
    removed <- d[gn == 10000 & get(r$flag) == TRUE, uniqueN(codmun_6)]
    d <- d[!(gn == 10000 & get(r$flag) == TRUE)]
  }
  rbindlist(lapply(seq_len(nrow(outcomes)), function(j) {
    y <- outcomes[j]
    est <- tryCatch(estimate(d, y$outcome), error = function(e) e)
    if (inherits(est, "error")) {
      cat("FAILED:", r$rule, y$outcome, est$message, "\n")
      return(data.table(rule = r$rule, flag = r$flag, outcome = y$outcome,
                        outcome_label = y$label, removed_controls = removed,
                        att = NA_real_, se = NA_real_, lo = NA_real_, hi = NA_real_,
                        n_obs = nrow(d), n_treated = d[gn < 10000, uniqueN(codmun_6)],
                        n_controls = d[gn == 10000, uniqueN(codmun_6)],
                        status = paste("failed:", est$message)))
    }
    data.table(rule = r$rule, flag = r$flag, outcome = y$outcome,
               outcome_label = y$label, removed_controls = removed,
               att = est$att, se = est$se, lo = est$lo, hi = est$hi,
               n_obs = est$n_obs, n_treated = est$n_treated,
               n_controls = est$n_controls, status = "ok")
  }))
}), fill = TRUE)
fwrite(rows, csv_out)
cat("wrote:", csv_out, "rows:", nrow(rows), "\n")

fmt <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmtci <- function(lo, hi) ifelse(is.finite(lo) & is.finite(hi),
                                 sprintf("[%+.2f, %+.2f]", lo, hi), "--")
tex_rows <- rows[, sprintf(
  "%s & %s & %d & %d & %s & %s \\\\",
  rule, outcome_label, removed_controls, n_controls, fmt(att), fmtci(lo, hi)
)]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Mortality sensitivity to network-contaminated controls}",
  "\\label{tab:spillover-sensitivity}",
  "\\small",
  "\\resizebox{\\textwidth}{!}{%",
  "\\begin{tabular}{llrrrr}",
  "\\toprule",
  "Specification & Outcome & Controls removed & Controls kept & ATT & 95\\% CI \\\\",
  "\\midrule",
  tex_rows,
  "\\bottomrule",
  "\\multicolumn{6}{p{0.92\\textwidth}}{\\footnotesize Notes: The baseline uses the PNASH psychiatric causal sample. Sensitivity rows drop never-treated controls flagged by the pre-existing network-spillover diagnostics: same health-region proxy, shared referral hub, shared substitute hospital, high flow similarity, or any such link. Mortality estimates are population-weighted Sun--Abraham ATT estimates with municipality and year fixed effects and municipality-clustered standard errors.}\\\\",
  "\\end{tabular}",
  "}%",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
