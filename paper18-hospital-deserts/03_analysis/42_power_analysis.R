#!/usr/bin/env Rscript
# 42_power_analysis.R
#
# Path2-rest #B1 (parecer Major B1): power calculation formal para os
# sub-samples especializado vs geral. Reporta MDE para travel burden e
# ICSAP a 80% power, alpha=0.05, two-sided, e n_treated mínimo para
# detectar o efeito observado.
#
# Output: 04_logs/42_power_analysis.json

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")

cat("==== begin power analysis ====\n")

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
exo   <- as.data.table(read_parquet(file.path(INTER, "hospital_closures_exogenous.parquet")))
expo  <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))

exo60 <- exo[exogenous == TRUE]
cat(sprintf("exogenous closures: %d  (specialized=%d  general=%d)\n",
            nrow(exo60), exo60[tp_unid == "07", .N], exo60[tp_unid == "05", .N]))

# Identificar municípios E1-treated por tipo de hospital
expo_treated <- expo[exposed_emb == TRUE]
expo_treated <- merge(expo_treated, exo60[, .(CNES, tp_unid, exogenous)],
                      by = "CNES", all.x = TRUE)
expo_treated <- expo_treated[exogenous == TRUE]
cat(sprintf("E1-treated munis (exogenous closures only): %d\n",
            expo_treated[, uniqueN(codmun_6)]))

mun_spec <- expo_treated[tp_unid == "07", unique(codmun_6)]
mun_gen  <- expo_treated[tp_unid == "05", unique(codmun_6)]
cat(sprintf("  specialized closure exposure: %d unique munis\n", length(mun_spec)))
cat(sprintf("  general closure exposure    : %d unique munis\n", length(mun_gen)))

run_att <- function(d, yname) {
  d <- d[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) {cat("ERR:", conditionMessage(e), "\n"); NULL})
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]),
       se  = as.numeric(se(agg)[1]),
       n_treated = d[gn_use < 10000, uniqueN(muni_id)])
}

# Para criar sub-amostras: manter never-treated controls + treated do tipo desejado
make_subsample <- function(panel, mun_keep) {
  # treated of correct type + all never-treated (g_emb missing/0)
  treated <- panel[codmun_6 %in% mun_keep]
  controls <- panel[is.na(g_emb) | g_emb == 0]
  rbindlist(list(treated, controls))
}

# MDE = (z_{1-alpha/2} + z_{1-beta}) * SE
# alpha=0.05 two-sided, beta=0.20 → 1.96 + 0.84 = 2.80
mde_factor <- qnorm(0.975) + qnorm(0.80)
cat(sprintf("MDE multiplier (alpha=.05, beta=.20): %.4f\n", mde_factor))

results <- list()

samples <- list(
  F5_full = panel,
  F5_spec = make_subsample(panel, mun_spec),
  F5_gen  = make_subsample(panel, mun_gen)
)

for (sn in names(samples)) {
  d <- samples[[sn]]
  if (nrow(d) == 0) next
  for (yn in c("travel_burden_km", "icsap_per1k")) {
    r <- run_att(d, yn)
    if (is.null(r)) next
    mde <- mde_factor * r$se
    n_min <- if (abs(r$att) > 1e-6) {
      ceiling(r$n_treated * (mde / abs(r$att))^2)
    } else NA_integer_
    key <- sprintf("%s__%s", sn, yn)
    results[[key]] <- list(
      sample = sn, outcome = yn,
      n_treated = r$n_treated,
      att = r$att, se = r$se,
      mde_80pct_two_sided = mde,
      ratio_att_to_mde = abs(r$att) / mde,
      n_min_to_detect_observed_effect = n_min,
      detected_at_80pct = abs(r$att) >= mde
    )
    cat(sprintf("  %-8s | %-18s | n_treated=%3d | ATT=%+7.3f | SE=%5.3f | MDE80=%5.3f | ATT/MDE=%4.2f | n_min=%s\n",
                sn, yn, r$n_treated, r$att, r$se, mde,
                abs(r$att)/mde, n_min))
  }
}

write(toJSON(results, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "42_power_analysis.json"))
cat("wrote 42_power_analysis.json\n")
