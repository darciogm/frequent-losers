#!/usr/bin/env Rscript
# 33_event_study_with_perturbation.R
#
# S5 com R2 — re-roda Sun-Abraham usando perturbation_signal (R2) como
# treatment intensity contínuo, em vez de exposed_emb binário.
#
# Especificação 1 (binary thresholded): município m é tratado se
#   max(perturbation_signal, by closure) > THRESHOLD (e.g. 0.10)
#
# Especificação 2 (intensity-weighted): rodar Sun-Abraham padrão com binary
#   exposure (igual S5 final), mas adicionar como weight em feols. Não
#   trivial em fixest::sunab; usar split por quartil de perturbação como
#   alternative.
#
# Outputs:
#   04_logs/33_es_perturbation_results.json
#   04_figures/fig_es_perturbation_thresholds.pdf
#   01_manuscript/tables/tab_es_perturbation.tex

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
  library(ggplot2); library(jsonlite); library(patchwork)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
FIG_DIR <- file.path(ROOT, "04_figures")
TAB_DIR <- file.path(ROOT, "01_manuscript", "tables")

cat("==== begin S5 with perturbation as treatment intensity ====\n")
t0 <- Sys.time()

# ---- ler perturbation panel ----
pert <- as.data.table(read_parquet(file.path(INTER, "perturbation_panel.parquet")))
cat(sprintf("perturbation rows: %d  munis únicos: %d  closures únicos: %d\n",
            nrow(pert), pert[, uniqueN(codmun_6)], pert[, uniqueN(CNES_fechou)]))

# ---- agregação por município: max signal entre closures que afetaram m,
# year_closure correspondente
pert_max <- pert[order(-perturbation_signal),
                  .SD[1], by = codmun_6,
                  .SDcols = c("CNES_fechou", "year_closure", "year_pre",
                              "perturbation_signal", "z_signal")]
cat("munis com algum signal:", nrow(pert_max), "\n")

# ---- ler painel base (F5_main) ----
panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
panel[, codmun_6 := as.character(codmun_6)]
pert_max[, codmun_6 := as.character(codmun_6)]

# ---- thresholds para definir tratado ----
THRESHOLDS <- c(0.05, 0.10, 0.20)

run_sunab <- function(panel, yname, gname_col) {
  d <- panel[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(get(gname_col)) | get(gname_col) == 0,
                        10000L, as.integer(get(gname_col)))]
  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) { cat("ERR:", conditionMessage(e), "\n"); NULL })
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]),
       se  = as.numeric(se(agg)[1]),
       n_treated = d[gn_use < 10000, uniqueN(muni_id)])
}

results <- list()
for (thr in THRESHOLDS) {
  cat(sprintf("\n--- threshold %.2f ---\n", thr))
  treated_codmuns <- pert_max[perturbation_signal >= thr, codmun_6]
  cat(sprintf("treated munis com signal >= %.2f: %d\n", thr, length(treated_codmuns)))

  # construir gname novo: para munis tratados (signal >= thr), gname = year_closure
  # do CNES com maior signal; demais = 0
  panel_thr <- copy(panel)
  panel_thr[, g_pert := 0L]
  for (cm in treated_codmuns) {
    yc <- pert_max[codmun_6 == cm, year_closure]
    if (length(yc) > 0) panel_thr[codmun_6 == cm, g_pert := as.integer(yc[1])]
  }

  for (yn in c("travel_burden_km", "icsap_per1k")) {
    r <- run_sunab(panel_thr, yn, "g_pert")
    if (!is.null(r)) {
      cat(sprintf("  %s: ATT=%+.3f SE=%.3f n_tr=%d\n",
                  yn, r$att, r$se, r$n_treated))
      results[[sprintf("thr%.2f_%s", thr, yn)]] <- list(
        threshold = thr, outcome = yn,
        att = r$att, se = r$se, n_treated = r$n_treated)
    }
  }
}

# ---- também rodar com quartil de perturbation como alternative ----
cat("\n--- por quartil de perturbation_signal ---\n")
qs <- quantile(pert_max$perturbation_signal,
               probs = c(0.5, 0.75, 0.9), na.rm = TRUE)
cat(sprintf("p50=%.4f p75=%.4f p90=%.4f\n", qs[1], qs[2], qs[3]))

# ---- save JSON ----
write(toJSON(results, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "33_es_perturbation_results.json"))
cat("wrote 33_es_perturbation_results.json\n")

# ---- LaTeX table ----
tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Event-study (Sun-Abraham) with treatment defined by counterfactual graph perturbation: threshold variants.}",
  "\\label{tab:es-perturbation}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  "Threshold & Outcome & ATT & SE & $N_{tr}$ \\\\",
  "\\midrule")
for (key in names(results)) {
  r <- results[[key]]
  tab <- c(tab, sprintf("$\\geq %.2f$ & %s & $%+.3f$ & %.3f & %d \\\\",
                         r$threshold,
                         ifelse(r$outcome == "travel_burden_km", "Travel (km)", "ICSAP per 1k"),
                         r$att, r$se, r$n_treated))
}
tab <- c(tab, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_es_perturbation.tex"))
cat("wrote tab_es_perturbation.tex\n")

cat(sprintf("\n==== done ==== elapsed %.1fs\n",
            as.numeric(Sys.time() - t0, units = "secs")))
