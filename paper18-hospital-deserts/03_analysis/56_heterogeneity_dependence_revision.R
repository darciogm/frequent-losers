#!/usr/bin/env Rscript
# Heterogeneity by baseline flow dependence.

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
log_file <- file.path(LOG, sprintf("56_heterogeneity_dependence_revision_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
started <- Sys.time()
cat("script: 56_heterogeneity_dependence_revision.R\n")
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

csv_out <- file.path(PROC, "heterogeneity_dependence_revision.csv")
tex_out <- file.path(TAB, "tab_heterogeneity_dependence_revision.tex")
fig_out <- file.path(FIG, "fig_heterogeneity_dependence_revision.pdf")
if (!force && any(file.exists(c(csv_out, tex_out, fig_out)))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(c(csv_out, tex_out, fig_out)[file.exists(c(csv_out, tex_out, fig_out))], collapse = ", "))
}

panel_file <- file.path(PROC, "revision_pnash48_panel.parquet")
panel <- if (file.exists(panel_file)) {
  as.data.table(read_parquet(panel_file))
} else {
  as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
}
panel[, `:=`(codmun_6 = as.character(codmun_6),
             gn = fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb)))]

dep_file <- file.path(PROC, "revision_exposure_dependence.parquet")
if (file.exists(dep_file)) {
  dep <- as.data.table(read_parquet(dep_file))
} else {
  expo <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))
  expo[, codmun_6 := as.character(codmun_6)]
  dep <- expo[exposed_emb == TRUE,
              .(baseline_exposure_share = max(share_emb, na.rm = TRUE),
                baseline_psych_episode_count = max(n_aih_pre, na.rm = TRUE)),
              by = codmun_6]
}
dep <- dep[is.finite(baseline_exposure_share)]
dep[, share_quartile := cut(
  baseline_exposure_share,
  breaks = unique(quantile(baseline_exposure_share, probs = seq(0, 1, 0.25), na.rm = TRUE)),
  include.lowest = TRUE, labels = FALSE
)]
dep[, count_quartile := cut(
  baseline_psych_episode_count,
  breaks = unique(quantile(baseline_psych_episode_count, probs = seq(0, 1, 0.25), na.rm = TRUE)),
  include.lowest = TRUE, labels = FALSE
)]

estimate_group <- function(y, group_var, group_value, label) {
  subgroup_munis <- dep[get(group_var) == group_value, codmun_6]
  d <- panel[(gn >= 10000) | (codmun_6 %in% subgroup_munis)]
  d <- d[is.finite(get(y)) & is.finite(pop) & pop > 0]
  if (d[gn < 10000, uniqueN(muni_id)] < 3) {
    return(data.table(outcome = y, subgroup = label, att = NA_real_, se = NA_real_,
                      lo = NA_real_, hi = NA_real_, n_treated = d[gn < 10000, uniqueN(muni_id)],
                      baseline_rate = NA_real_, status = "too few treated municipalities"))
  }
  fit <- tryCatch(feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y)),
                        d, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE),
                  error = function(e) e)
  if (inherits(fit, "error")) {
    return(data.table(outcome = y, subgroup = label, att = NA_real_, se = NA_real_,
                      lo = NA_real_, hi = NA_real_, n_treated = d[gn < 10000, uniqueN(muni_id)],
                      baseline_rate = NA_real_, status = fit$message))
  }
  a <- summary(fit, agg = "att")
  att <- as.numeric(coef(a)[1])
  se <- as.numeric(se(a)[1])
  base <- d[gn < 10000 & year < gn & is.finite(pop) & pop > 0]
  baseline <- if (nrow(base)) weighted.mean(base[[y]], base$pop, na.rm = TRUE) else NA_real_
  data.table(outcome = y, subgroup = label, att = att, se = se,
             lo = att - 1.96 * se, hi = att + 1.96 * se,
             n_treated = d[gn < 10000, uniqueN(muni_id)],
             baseline_rate = baseline, status = "ok")
}

parts <- list()
for (q in sort(unique(na.omit(dep$share_quartile)))) {
  parts[[length(parts) + 1]] <- estimate_group("suicide_per100k", "share_quartile", q, sprintf("Exposure share Q%d", q))
  parts[[length(parts) + 1]] <- estimate_group("selfharm_per100k", "share_quartile", q, sprintf("Exposure share Q%d", q))
}
for (q in sort(unique(na.omit(dep$count_quartile)))) {
  parts[[length(parts) + 1]] <- estimate_group("suicide_per100k", "count_quartile", q, sprintf("Episode count Q%d", q))
  parts[[length(parts) + 1]] <- estimate_group("selfharm_per100k", "count_quartile", q, sprintf("Episode count Q%d", q))
}
res <- rbindlist(parts, fill = TRUE)
res[, outcome_label := fifelse(outcome == "suicide_per100k", "Suicide", "Self-harm")]
fwrite(res, csv_out)
cat("wrote:", csv_out, " rows=", nrow(res), "\n")

fmt <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmt2 <- function(x) ifelse(is.finite(x), sprintf("%.2f", x), "--")
rows <- res[, sprintf("%s & %s & %s & [%s, %s] & %s & %s \\\\",
                      outcome_label, subgroup, fmt(att), fmt(lo), fmt(hi),
                      n_treated, fmt2(baseline_rate))]
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Heterogeneity by baseline dependence. Each row keeps never-treated municipalities and treated municipalities in the listed dependence quartile. Dependence is measured using the existing pre-closure patient-flow exposure file. Mortality estimates are population-weighted Sun--Abraham ATT estimates with municipality and year fixed effects.}",
  "\\label{tab:heterogeneity-dependence-revision}",
  "\\small",
  "\\begin{tabular}{llcccc}",
  "\\toprule",
  "Outcome & Subgroup & ATT & 95\\% CI & Treated municipalities & Baseline rate \\\\",
  "\\midrule",
  rows,
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(tex, tex_out)
cat("wrote:", tex_out, "\n")

plot_data <- res[status == "ok" & grepl("Exposure share", subgroup)]
p <- ggplot(plot_data, aes(att, subgroup, xmin = lo, xmax = hi, color = outcome_label)) +
  geom_vline(xintercept = 0, color = "gray55", linetype = "dashed", linewidth = 0.35) +
  geom_pointrange(position = position_dodge(width = 0.55), linewidth = 0.55, size = 0.35) +
  scale_color_manual(values = c("Suicide" = "#0072B2", "Self-harm" = "#D55E00")) +
  labs(x = "ATT, deaths per 100,000", y = NULL, color = NULL) +
  theme_minimal(base_size = 9.5) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom")
ggsave(fig_out, p, width = 6.2, height = 3.8, device = "pdf")
cat("wrote:", fig_out, "\n")
cat("failed rows:", res[status != "ok", .N], "\n")
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
