#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
TAB_DIR <- file.path(ROOT, "01_manuscript", "tables")

cat("==== begin policy magnitude ====\n")

es <- fromJSON(file.path(LOG_DIR, "30_es_final_results.json"), simplifyVector = TRUE)
exp <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))
pop <- as.data.table(read_parquet(file.path(INTER, "pop_municipal_2015_2025.parquet")))
pop[, codmun_6 := substr(cod_mun, 1, 6)]

f5_travel <- es$F5_main__travel_burden_km__g_emb
f5_icsap <- es$F5_main__icsap_per1k__g_emb

affected <- exp[exposed_emb == TRUE, .(affected_munis = uniqueN(codmun_6)), by = .(CNES, year_closure)]
affected_pop <- merge(exp[exposed_emb == TRUE, .(CNES, year_closure, codmun_6)],
                      pop[, .(codmun_6, year = ano, pop)],
                      by.x = c("codmun_6", "year_closure"), by.y = c("codmun_6", "year"),
                      all.x = TRUE)
affected_pop <- affected_pop[, .(affected_population = sum(pop, na.rm = TRUE)), by = .(CNES, year_closure)]
closure_panel <- merge(affected, affected_pop, by = c("CNES", "year_closure"))

mean_affected_pop <- mean(closure_panel$affected_population, na.rm = TRUE)
mean_affected_munis <- mean(closure_panel$affected_munis, na.rm = TRUE)
extra_icsap_per_closure_year <- (f5_icsap$att / 1000) * mean_affected_pop

payload <- list(
  travel_att_km = f5_travel$att,
  icsap_att_per_1k = f5_icsap$att,
  mean_affected_population_per_closure = mean_affected_pop,
  mean_affected_munis_per_closure = mean_affected_munis,
  extra_icsap_admissions_per_closure_year = extra_icsap_per_closure_year,
  lives_lost_translation = NULL,
  note = "No lives-lost translation is reported because the amenable-mortality sensitivity did not deliver a defensible causal mortality estimate."
)
write(toJSON(payload, auto_unbox = TRUE, pretty = TRUE), file.path(LOG_DIR, "48_policy_magnitude.json"))

tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Per-closure policy magnitudes implied by the F5 main E1 estimates. The ICSAP translation uses the mean affected population among E1-exposed municipalities for each closure. No lives-lost translation is reported because the paper does not identify a causal mortality effect.}",
  "\\label{tab:welfare-per-closure}",
  "\\small",
  "\\begin{tabular}{lr}",
  "\\toprule",
  "Quantity & Value \\\\",
  "\\midrule",
  sprintf("Travel ATT (km) & %+.2f \\\\", f5_travel$att),
  sprintf("ICSAP ATT (per 1{,}000) & %+.3f \\\\", f5_icsap$att),
  sprintf("Mean affected municipalities per closure & %.2f \\\\", mean_affected_munis),
  sprintf("Mean affected population per closure & %.0f \\\\", mean_affected_pop),
  sprintf("Implied extra ICSAP admissions per closure-year & %+.1f \\\\", extra_icsap_per_closure_year),
  "Lives-lost translation & not reported \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(tab, file.path(TAB_DIR, "tab_welfare_per_closure.tex"))

cat("done\n")
