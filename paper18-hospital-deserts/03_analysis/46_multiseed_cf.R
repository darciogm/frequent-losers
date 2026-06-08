#!/usr/bin/env Rscript
# 46_multiseed_cf.R
#
# Path2-rest #S4 (parecer Major S4): multi-seed sensitivity for the CF
# ATE. Estratégia: o ATT Sun-Abraham (E1, share-based) é INVARIANTE a
# seed por construção (script 41 documenta isso). O que varia é o
# feature iso_emb usado no CF. Simulamos a variabilidade injetando
# ruído gaussiano calibrado para a estabilidade observada
# (Pearson rho=0.77 em pair-distance) e re-rodando o CF B=10 vezes.
#
# Output: 04_logs/46_multiseed_cf.json

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(grf); library(jsonlite)
})

set.seed(42)

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")

cat("==== begin multi-seed CF sensitivity ====\n")

# Replicar setup do 31_causal_forest.R / 40_cf_calibration_test.R
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
                    uf = first(uf), codmun_6 = first(codmun_6)),
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
cat(sprintf("complete cases: %d\n", nrow(df_clean)))

# Calibrar nível de ruído ao Pearson rho=0.77 observado entre seeds
# para pair-distance: rho_target=0.77 implica var(ruido)/var(sinal) = (1-rho)/rho
# = (1-0.77)/0.77 = 0.299. Em SD: 0.547 (i.e. ruído tem ~55% do SD do sinal)
RHO_OBS <- 0.77
noise_ratio <- sqrt((1 - RHO_OBS) / RHO_OBS)
cat(sprintf("noise SD ratio (sigma_noise/sigma_signal): %.3f\n", noise_ratio))

iso_emb_sd <- sd(df_clean$iso_emb_z, na.rm = TRUE)
div_sd     <- sd(df_clean$divergence_z, na.rm = TRUE)
cat(sprintf("iso_emb_z sd: %.3f  divergence_z sd: %.3f\n", iso_emb_sd, div_sd))

run_cf <- function(df_clean, perturb_iso = FALSE) {
  d <- copy(df_clean)
  if (perturb_iso) {
    d[, iso_emb_z := iso_emb_z + rnorm(.N, sd = noise_ratio * iso_emb_sd)]
    d[, divergence_z := iso_emb_z - iso_km_z]
  }
  uf_dum <- model.matrix(~ uf - 1, data = d)
  colnames(uf_dum) <- gsub("^uf", "uf_", colnames(uf_dum))
  X <- as.matrix(cbind(
    iso_emb     = d$iso_emb_z,
    iso_km      = d$iso_km_z,
    divergence  = d$divergence_z,
    log_pop     = d$pop_log_pre,
    log_pib     = d$pib_log_pre,
    r99_frac    = d$r99_frac,
    uf_dum
  ))
  res <- list()
  for (yn in c("delta_tb", "delta_icsap")) {
    Y <- d[[yn]]; W <- d$treated
    cf <- causal_forest(X, Y, W, num.trees = 1500, honesty = TRUE)
    ate <- average_treatment_effect(cf, target.sample = "all")
    res[[yn]] <- list(ate = ate[1], se = ate[2])
  }
  res
}

# Baseline
cat("baseline run...\n")
base_res <- run_cf(df_clean, perturb_iso = FALSE)
for (yn in names(base_res)) {
  cat(sprintf("  %s: ATE=%+.3f  SE=%.3f\n", yn,
              base_res[[yn]]$ate, base_res[[yn]]$se))
}

# Multi-seed simulado
B <- 10
sim <- list()
for (b in 1:B) {
  set.seed(100 + b)
  cat(sprintf("perturbed run %d/%d...\n", b, B))
  r <- run_cf(df_clean, perturb_iso = TRUE)
  for (yn in names(r)) {
    sim[[length(sim) + 1]] <- list(b = b, outcome = yn,
                                    ate = r[[yn]]$ate,
                                    se = r[[yn]]$se)
  }
}

sim_df <- rbindlist(lapply(sim, as.data.table))
summary_by_outcome <- sim_df[, .(mean_ate = mean(ate),
                                   sd_ate = sd(ate),
                                   min_ate = min(ate),
                                   max_ate = max(ate)), by = outcome]
print(summary_by_outcome)

out <- list(
  rho_observed = RHO_OBS,
  noise_sd_ratio = noise_ratio,
  baseline = base_res,
  perturbed_runs = sim,
  summary = as.list(summary_by_outcome)
)
write(toJSON(out, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "46_multiseed_cf.json"))
cat("wrote 46_multiseed_cf.json\n")
