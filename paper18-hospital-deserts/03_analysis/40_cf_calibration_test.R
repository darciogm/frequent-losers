#!/usr/bin/env Rscript
# 40_cf_calibration_test.R
#
# Path2-rest #5 (parecer Major #5): adicionar formal heterogeneity test
# ao Causal Forest do script 31. Usa grf::test_calibration que reporta:
#   - mean.forest.prediction (overall ATE estimate)
#   - differential.forest.prediction (DTEP, t-stat para heterogeneity)
#
# Se DTEP p-value < 0.05, forest detecta heterogeneity real (não noise).
# Caso contrário, the variable importance ranking deve ser interpretada
# com cautela.

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(grf); library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")

cat("==== begin CF calibration test ====\n")
t0 <- Sys.time()

# Replicar o setup do 31_causal_forest.R
panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
PRE_YRS  <- 2010:2015
POST_YRS <- 2018:2023

cs_outcome <- function(panel, yname) {
  pre <- panel[year %in% PRE_YRS & is.finite(get(yname)),
               .(pre_mean = mean(get(yname))), by = muni_id]
  post <- panel[year %in% POST_YRS & is.finite(get(yname)),
                .(post_mean = mean(get(yname))), by = muni_id]
  d <- merge(pre, post, by = "muni_id", all = TRUE)
  d[, delta := post_mean - pre_mean]
  d
}
delta_tb <- cs_outcome(panel, "travel_burden_km")
setnames(delta_tb, c("pre_mean", "post_mean", "delta"),
         c("tb_pre", "tb_post", "delta_tb"))
delta_icsap <- cs_outcome(panel, "icsap_per1k")
setnames(delta_icsap, c("pre_mean", "post_mean", "delta"),
         c("icsap_pre", "icsap_post", "delta_icsap"))

treat <- panel[, .(treated = max(as.integer(g_emb > 0)),
                   gname = max(g_emb)), by = muni_id]
treat[, treated := ifelse(treated == 1 & gname >= 2012 & gname <= 2018, 1, 0)]

div <- as.data.table(read_parquet(file.path(INTER, "divergence_panel.parquet")))
pop_pib <- panel[year %in% PRE_YRS,
                  .(pop_log_pre = mean(pop_log, na.rm = TRUE),
                    pib_log_pre = mean(pib_log, na.rm = TRUE),
                    uf = first(uf),
                    codmun_6 = first(codmun_6)),
                  by = muni_id]
mort <- as.data.table(read_parquet(file.path(INTER, "amenable_mortality.parquet")))
r99 <- mort[year %in% c(2010:2015, 2018:2023),
            .(r99_frac = sum(n_age_unknown, na.rm = TRUE) /
                         sum(n_total, na.rm = TRUE)),
            by = codmun_6]

df <- merge(pop_pib, delta_tb, by = "muni_id", all.x = TRUE)
df <- merge(df, delta_icsap, by = "muni_id", all.x = TRUE)
df <- merge(df, treat, by = "muni_id", all.x = TRUE)
df <- merge(df, div[, .(codmun_6, divergence_z, iso_emb_z, iso_km_z)],
            by = "codmun_6", all.x = TRUE)
df <- merge(df, r99, by = "codmun_6", all.x = TRUE)

needed <- c("delta_tb", "delta_icsap", "treated",
            "iso_emb_z", "iso_km_z", "divergence_z",
            "pop_log_pre", "pib_log_pre", "r99_frac")
df_clean <- df[complete.cases(df[, ..needed])]
cat(sprintf("complete cases: %d (treated: %d, controls: %d)\n",
            nrow(df_clean),
            sum(df_clean$treated == 1),
            sum(df_clean$treated == 0)))

uf_dum <- model.matrix(~ uf - 1, data = df_clean)
colnames(uf_dum) <- gsub("^uf", "uf_", colnames(uf_dum))
X <- as.matrix(cbind(
  iso_emb     = df_clean$iso_emb_z,
  iso_km      = df_clean$iso_km_z,
  divergence  = df_clean$divergence_z,
  log_pop     = df_clean$pop_log_pre,
  log_pib     = df_clean$pib_log_pre,
  r99_frac    = df_clean$r99_frac,
  uf_dum
))

run_calibration <- function(Y, W, X, label) {
  cat(sprintf("\n--- %s ---\n", label))
  set.seed(42)
  cf <- causal_forest(X, Y, W, num.trees = 4000, honesty = TRUE)

  ate <- average_treatment_effect(cf, target.sample = "all")
  cat(sprintf("ATE: %+.3f  SE: %.3f  Z: %.2f\n",
              ate[1], ate[2], ate[1] / ate[2]))

  # Calibration test (Athey-Wager 2019 §4.2)
  # If forest is well-calibrated:
  #  - mean.forest.prediction coef should be ~1 (forest ATE matches overall)
  #  - differential.forest.prediction coef should be > 0 if heterogeneity
  #    exists, with t-stat indicating significance
  cal <- test_calibration(cf)
  cat("Calibration test:\n"); print(cal)

  # Best linear projection
  blp <- best_linear_projection(cf, X)
  blp_summary <- summary(blp)

  # extract DTEP coefficient and p-value
  mfp_est  <- cal["mean.forest.prediction", "Estimate"]
  mfp_se   <- cal["mean.forest.prediction", "Std. Error"]
  dtep_est <- cal["differential.forest.prediction", "Estimate"]
  dtep_se  <- cal["differential.forest.prediction", "Std. Error"]
  dtep_t   <- cal["differential.forest.prediction", "t value"]
  dtep_p   <- cal["differential.forest.prediction", "Pr(>t)"]

  list(
    ate = ate[1], se_ate = ate[2],
    mfp_estimate = mfp_est, mfp_se = mfp_se,
    dtep_estimate = dtep_est, dtep_se = dtep_se,
    dtep_t = dtep_t, dtep_p_value = dtep_p
  )
}

results <- list()
results$tb <- run_calibration(df_clean$delta_tb, df_clean$treated, X, "Travel burden Δ")
results$icsap <- run_calibration(df_clean$delta_icsap, df_clean$treated, X, "ICSAP Δ")

write(toJSON(results, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "40_cf_calibration.json"))
cat("\nwrote 40_cf_calibration.json\n")

cat(sprintf("==== done %.0fs ====\n", as.numeric(Sys.time() - t0, units = "secs")))
