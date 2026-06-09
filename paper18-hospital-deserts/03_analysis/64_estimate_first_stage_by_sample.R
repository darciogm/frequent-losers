#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(ggplot2)
})

script <- "64_estimate_first_stage_by_sample"
root <- normalizePath(file.path(dirname(sub("--file=", "", commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
proc <- file.path(root, "02_data", "processed")
tab_dir <- file.path(root, "01_manuscript", "tables")
fig_dir <- file.path(root, "04_figures")
log_dir <- file.path(root, "04_logs")
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% args
outs <- c(
  file.path(tab_dir, "table_first_stage_by_sample.tex"),
  file.path(fig_dir, "fig_first_stage_f5.pdf"),
  file.path(fig_dir, "fig_first_stage_pnash_psych.pdf"),
  file.path(fig_dir, "fig_first_stage_nonpsych_f5.pdf"),
  file.path(fig_dir, "fig_first_stage_failed_f5.pdf")
)
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(log_dir, sprintf("%s_%s.log", script, stamp))
log_con <- file(log_file, open = "wt")
sink(log_con, split = TRUE)
on.exit({ sink(); close(log_con) }, add = TRUE)

cat(sprintf("runtime_header={\"script\":\"%s\",\"timestamp\":\"%s\",\"git_sha\":\"%s\",\"seed\":[]}\n",
            script, format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
            tryCatch(system2("git", c("rev-parse", "HEAD"), cwd = root, stdout = TRUE, stderr = FALSE)[1], error = function(e) "unknown")))
cat(sprintf("package_versions={\"R\":\"%s\",\"fixest\":\"%s\",\"arrow\":\"%s\",\"data.table\":\"%s\",\"ggplot2\":\"%s\"}\n",
            getRversion(), as.character(packageVersion("fixest")), as.character(packageVersion("arrow")),
            as.character(packageVersion("data.table")), as.character(packageVersion("ggplot2"))))

if (any(file.exists(outs)) && !force) {
  cat("outputs already exist; use --force to overwrite\n")
  quit(status = 0)
}

panel_path <- file.path(proc, "first_stage_sample_panels.parquet")
if (!file.exists(panel_path)) stop("missing ", panel_path)

d <- as.data.table(read_parquet(panel_path))
d <- d[is.finite(travel_burden_km)]
d[, sample_label := fifelse(sample_id == "f5_economically_meaningful_closures", "Full F5 closures",
                     fifelse(sample_id == "pnash_psychiatric_closures", "PNASH psychiatric closures",
                     fifelse(sample_id == "nonpsychiatric_f5_closures", "Nonpsychiatric F5 closures",
                     "Failed-F5 predecline closures")))]
d[, rule_label := fifelse(exposure_rule == "flow", "Flow", "Distance")]
d[, gn := fifelse(g >= 10000L, 10000L, as.integer(g))]

estimate_one <- function(sample, rule) {
  x <- d[sample_id == sample & exposure_rule == rule]
  n_tr <- uniqueN(x[gn < 10000]$codmun_6)
  cohorts <- uniqueN(x[gn < 10000]$gn)
  if (n_tr < 3 || cohorts < 2) {
    return(list(summary = data.table(sample_id = sample, exposure_rule = rule, att = NA_real_, se = NA_real_,
                                     lo = NA_real_, hi = NA_real_, p_pre = NA_real_, n_tr = n_tr,
                                     cohorts = cohorts),
                es = data.table()))
  }
  m <- feols(travel_burden_km ~ sunab(gn, year) | muni_id + year, x, cluster = "muni_id")
  a <- summary(m, agg = "att")
  att <- as.numeric(coef(a)[1])
  se <- as.numeric(se(a)[1])
  cf <- coef(m)
  ss <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i) {
    if (length(mm[[i]]) == 2) data.table(rel_year = as.integer(mm[[i]][2]), estimate = cf[i], se = ss[i]) else NULL
  }))
  if (nrow(es)) {
    es <- es[is.finite(estimate) & is.finite(se) & se > 0]
    es[, `:=`(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se,
              sample_id = sample, exposure_rule = rule)]
  }
  pre <- es[rel_year <= -2 & rel_year >= -6]
  p_pre <- if (nrow(pre) > 0) 1 - pchisq(sum((pre$estimate / pre$se)^2), nrow(pre)) else NA_real_
  list(summary = data.table(sample_id = sample, exposure_rule = rule, att = att, se = se,
                            lo = att - 1.96 * se, hi = att + 1.96 * se,
                            p_pre = p_pre, n_tr = n_tr, cohorts = cohorts),
       es = es)
}

samples <- c("f5_economically_meaningful_closures", "pnash_psychiatric_closures",
             "nonpsychiatric_f5_closures", "failed_f5_predecline_closures")
rules <- c("flow", "distance")
fits <- list()
for (s in samples) for (r in rules) fits[[paste(s, r, sep = "_")]] <- estimate_one(s, r)
summ <- rbindlist(lapply(fits, `[[`, "summary"), fill = TRUE)
es <- rbindlist(lapply(fits, `[[`, "es"), fill = TRUE)
summ[, sample_label := fifelse(sample_id == "f5_economically_meaningful_closures", "Full F5 closures",
                        fifelse(sample_id == "pnash_psychiatric_closures", "PNASH psychiatric closures",
                        fifelse(sample_id == "nonpsychiatric_f5_closures", "Nonpsychiatric F5 closures",
                        "Failed-F5 predecline closures")))]
summ[, rule_label := fifelse(exposure_rule == "flow", "Flow", "Distance")]
es[, sample_label := fifelse(sample_id == "f5_economically_meaningful_closures", "Full F5 closures",
                      fifelse(sample_id == "pnash_psychiatric_closures", "PNASH psychiatric closures",
                      fifelse(sample_id == "nonpsychiatric_f5_closures", "Nonpsychiatric F5 closures",
                      "Failed-F5 predecline closures")))]
es[, rule_label := fifelse(exposure_rule == "flow", "Flow", "Distance")]
write_csv_arrow(summ, file.path(proc, "first_stage_by_sample_estimates.csv"))
write_parquet(es, file.path(proc, "first_stage_by_sample_eventstudy.parquet"))

fmt_num <- function(x) ifelse(is.na(x), "--", sprintf("%+.2f", x))
fmt_p <- function(x) ifelse(is.na(x), "--", sprintf("%.2f", x))
lines <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Travel-burden first stages by closure sample}",
  "\\label{tab:first-stage-by-sample}",
  "\\small",
  "\\begin{tabular}{llrrrrr}",
  "\\toprule",
  "Sample & Exposure rule & ATT & 95\\% CI & Pre-trend $p$ & Exposed munis & Cohorts \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(summ))) {
  r <- summ[i]
  ci <- ifelse(is.na(r$lo), "--", sprintf("[%+.2f, %+.2f]", r$lo, r$hi))
  lines <- c(lines, sprintf("%s & %s & %s & %s & %s & %d & %d \\\\",
                            r$sample_label, r$rule_label, fmt_num(r$att), ci, fmt_p(r$p_pre), r$n_tr, r$cohorts))
}
lines <- c(
  lines,
  "\\bottomrule",
  "\\multicolumn{7}{p{0.92\\textwidth}}{\\footnotesize Notes: Outcome is average inpatient travel burden in kilometers. The first stage validates realized utilization links to the closing provider; it does not distinguish substitution, composition change, or lost care. Failed-F5 estimates are diagnostic only.}\\\\",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(lines, file.path(tab_dir, "table_first_stage_by_sample.tex"))

plot_one <- function(sample, file) {
  pdat <- es[sample_id == sample & rel_year >= -6 & rel_year <= 8]
  if (!nrow(pdat)) return(NULL)
  g <- ggplot(pdat, aes(rel_year, estimate, color = rule_label, fill = rule_label)) +
    geom_hline(yintercept = 0, color = "gray55", linetype = "dashed", linewidth = 0.35) +
    geom_vline(xintercept = -0.5, color = "gray55", linetype = "dotted", linewidth = 0.35) +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, color = NA) +
    geom_line(linewidth = 0.55) +
    geom_point(size = 1.4) +
    scale_color_manual(values = c("Flow" = "#0072B2", "Distance" = "#D55E00")) +
    scale_fill_manual(values = c("Flow" = "#0072B2", "Distance" = "#D55E00")) +
    labs(x = "Years since closure", y = "Travel-burden ATT (km)", color = NULL, fill = NULL,
         title = unique(pdat$sample_label)[1]) +
    theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(), legend.position = "bottom")
  ggsave(file, g, width = 6.4, height = 4.2)
}
plot_one("f5_economically_meaningful_closures", file.path(fig_dir, "fig_first_stage_f5.pdf"))
plot_one("pnash_psychiatric_closures", file.path(fig_dir, "fig_first_stage_pnash_psych.pdf"))
plot_one("nonpsychiatric_f5_closures", file.path(fig_dir, "fig_first_stage_nonpsych_f5.pdf"))
plot_one("failed_f5_predecline_closures", file.path(fig_dir, "fig_first_stage_failed_f5.pdf"))

cat("summary_rows=", nrow(summ), "\n")
cat("eventstudy_rows=", nrow(es), "\n")
cat(sprintf("runtime_seconds=%.2f peak_rss_proxy_gb=NA\n", proc.time()[["elapsed"]]))
