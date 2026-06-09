#!/usr/bin/env Rscript
# Raw means diagnostics for the AEJ-style robustness package.

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = FALSE)
trailing <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% trailing
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC <- file.path(ROOT, "02_data", "processed")
FIG <- file.path(ROOT, "04_figures")
LOG <- file.path(ROOT, "04_logs")
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG, showWarnings = FALSE, recursive = TRUE)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file <- file.path(LOG, sprintf("53_raw_means_revision_%s.log", stamp))
sink(log_file, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)

started <- Sys.time()
cat("script: 53_raw_means_revision.R\n")
cat("started:", format(started, "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("force:", force, "\n")
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_)
cat("git_sha:", paste(git_sha, collapse = " "), "\n")
cat("R:", R.version.string, "\n")
cat("packages:", paste(c(
  paste0("arrow=", as.character(packageVersion("arrow"))),
  paste0("data.table=", as.character(packageVersion("data.table"))),
  paste0("ggplot2=", as.character(packageVersion("ggplot2")))
), collapse = "; "), "\n")

panel_out <- file.path(PROC, "revision_pnash48_panel.parquet")
exposure_out <- file.path(PROC, "revision_exposure_dependence.parquet")
fig_out <- c(
  file.path(FIG, "fig_raw_means_suicide_revision.pdf"),
  file.path(FIG, "fig_raw_means_selfharm_revision.pdf"),
  file.path(FIG, "fig_raw_means_travel_revision.pdf"),
  file.path(FIG, "fig_raw_means_psych_admissions_revision.pdf")
)
outputs <- c(panel_out, exposure_out, fig_out)
if (!force && any(file.exists(outputs))) {
  stop("Refusing to overwrite existing outputs without --force: ",
       paste(outputs[file.exists(outputs)], collapse = ", "))
}

macro_region <- function(uf) {
  fifelse(uf %in% c("AC", "AP", "AM", "PA", "RO", "RR", "TO"), "North",
  fifelse(uf %in% c("AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE"), "Northeast",
  fifelse(uf %in% c("DF", "GO", "MT", "MS"), "Center-West",
  fifelse(uf %in% c("ES", "MG", "RJ", "SP"), "Southeast",
  fifelse(uf %in% c("PR", "RS", "SC"), "South", NA_character_)))))
}

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
psych <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
psych <- psych[, .(codmun_6 = as.character(codmun_6), year = as.integer(year), psych_adm_per1k, n_psych_adm)]
panel[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]
panel <- merge(panel, psych, by = c("codmun_6", "year"), all.x = TRUE)
panel[, `:=`(
  treated_ever = !is.na(g_emb) & g_emb > 0,
  gn = fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb)),
  macroregion = macro_region(uf)
)]
write_parquet(panel, panel_out)
cat("wrote:", panel_out, " rows=", nrow(panel), " cols=", ncol(panel), "\n")

expo <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))
expo[, codmun_6 := as.character(codmun_6)]
dep <- expo[exposed_emb == TRUE,
            .(baseline_exposure_share = max(share_emb, na.rm = TRUE),
              baseline_psych_episode_count = max(n_aih_pre, na.rm = TRUE),
              first_closure_year = min(year_closure, na.rm = TRUE),
              n_exposing_closures = uniqueN(CNES)),
            by = codmun_6]
write_parquet(dep, exposure_out)
cat("wrote:", exposure_out, " rows=", nrow(dep), "\n")

weighted_mean <- function(x, w) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  weighted.mean(x[ok], w[ok])
}

raw_means <- function(d, y, weighted = FALSE) {
  d <- copy(d)[is.finite(get(y))]
  if (weighted && "pop" %in% names(d)) {
    out <- d[, .(mean = weighted_mean(get(y), pop), n_muni = uniqueN(muni_id)),
             by = .(year, group = fifelse(treated_ever, "Ever exposed", "Never exposed"))]
  } else {
    out <- d[, .(mean = mean(get(y), na.rm = TRUE), n_muni = uniqueN(muni_id)),
             by = .(year, group = fifelse(treated_ever, "Ever exposed", "Never exposed"))]
  }
  out[order(year, group)]
}

plot_raw <- function(d, y, label, outfile, weighted = FALSE) {
  rm <- raw_means(d, y, weighted)
  p <- ggplot(rm, aes(year, mean, color = group)) +
    geom_vline(xintercept = c(2012, 2017), color = "gray75", linewidth = 0.25, linetype = "dotted") +
    geom_line(linewidth = 0.65) +
    geom_point(size = 1.25) +
    scale_color_manual(values = c("Ever exposed" = "#0072B2", "Never exposed" = "gray45")) +
    labs(x = "Calendar year", y = label, color = NULL) +
    theme_minimal(base_size = 9.5) +
    theme(panel.grid.minor = element_blank(), legend.position = "bottom")
  ggsave(outfile, p, width = 5.8, height = 3.8, device = "pdf")
  cat("wrote:", outfile, " weighted=", weighted, "\n")
}

plot_raw(panel, "suicide_per100k", "Suicide deaths per 100,000", fig_out[1], TRUE)
plot_raw(panel, "selfharm_per100k", "Self-harm deaths per 100,000", fig_out[2], TRUE)
plot_raw(panel, "travel_burden_km", "Mean travel burden (km)", fig_out[3], FALSE)
plot_raw(panel, "psych_adm_per1k", "Psychiatric admissions per 1,000", fig_out[4], FALSE)

cat("treated municipalities:", panel[treated_ever == TRUE, uniqueN(muni_id)], "\n")
cat("never-exposed municipalities:", panel[treated_ever == FALSE, uniqueN(muni_id)], "\n")
cat("peak_memory_mb:", round(gc()[, "max used"][2] * 8 / 1024^2, 1), "\n")
cat("runtime_seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2), "\n")
