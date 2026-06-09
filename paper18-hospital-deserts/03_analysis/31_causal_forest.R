#!/usr/bin/env Rscript
# 31_causal_forest.R
#
# R3 Causal Forest (Athey-Wager 2019, grf::causal_forest) — heterogeneidade
# ML do efeito do fechamento de hospital sobre travel burden e ICSAP, por
# características pré-tratamento dos municípios.
#
# Especificação cross-section first-difference:
#   Outcome Y_m = mean(outcome[2018:2023]) - mean(outcome[2010:2015])
#   Treatment W_m = 1 se m foi E1-exposto a algum closure F5 (com gname dentro
#   de [2012, 2018]), 0 caso contrário (controle nunca-tratado em E1).
#   Pre/post janelas excluem 2016/2017 (transição) e 2020/2021 (pandemia).
#
#   Features X_m: iso_emb, iso_km, divergence_z, log_pop, log_pib,
#                 R96-R99_fraction (ICD-10 R96-R99 share dos óbitos),
#                 UF dummies, regional indicators.
#
# Outputs:
#   04_logs/31_cf_results.json
#   04_figures/fig_cate_by_dim.pdf  (CATE plots por dim_feature)
#   04_figures/fig_var_importance.pdf
#   01_manuscript/tables/tab_cf.tex (ATE + variable importance ranking)

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(grf)
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

cat("==== begin causal forest (R3) ====\n")
t0 <- Sys.time()

# ---- carregar painel staggered F5 measurement ----
panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
cat("painel rows:", nrow(panel), "\n")

# ---- cross-section first-difference ----
PRE_YRS  <- 2010:2015
POST_YRS <- 2018:2023

cs_outcome <- function(panel, yname) {
  pre <- panel[year %in% PRE_YRS & is.finite(get(yname)),
               .(pre_mean = mean(get(yname))), by = muni_id]
  post <- panel[year %in% POST_YRS & is.finite(get(yname)),
                .(post_mean = mean(get(yname))), by = muni_id]
  d <- merge(pre, post, by = "muni_id", all = TRUE)
  d[, `:=`(delta = post_mean - pre_mean)]
  d
}
delta_tb <- cs_outcome(panel, "travel_burden_km")
setnames(delta_tb, c("pre_mean", "post_mean", "delta"),
         c("tb_pre", "tb_post", "delta_tb"))
delta_icsap <- cs_outcome(panel, "icsap_per1k")
setnames(delta_icsap, c("pre_mean", "post_mean", "delta"),
         c("icsap_pre", "icsap_post", "delta_icsap"))

# ---- treatment ----
treat <- panel[, .(treated = max(as.integer(g_emb > 0)),
                   gname = max(g_emb)), by = muni_id]
# manter apenas tratados que foram tratados em [2012, 2018] (excluir 2022-23
# pois post-pandemic complica pre/post)
treat[, treated := ifelse(treated == 1 & gname >= 2012 & gname <= 2018, 1, 0)]

# ---- features X ----
# divergence_z, iso_emb, iso_km de divergence_panel.parquet
div <- as.data.table(read_parquet(file.path(INTER, "divergence_panel.parquet")))
cat("divergence_panel cols:", paste(names(div), collapse = ", "), "\n")

# pop, pib log: usar média do pre-period
pop_pib <- panel[year %in% PRE_YRS,
                  .(pop_log_pre = mean(pop_log, na.rm = TRUE),
                    pib_log_pre = mean(pib_log, na.rm = TRUE),
                    uf = first(uf),
                    codmun_6 = first(codmun_6)),
                  by = muni_id]

# R96-R99 fraction — use municipality-year SIM quality panel built from raw CAUSABAS
simq <- as.data.table(read_parquet(file.path(INTER, "sim_quality_panel.parquet")))
r99 <- simq[year %in% c(2010:2015, 2018:2023),
            .(r99_frac = sum(n_r96_r99, na.rm = TRUE) /
                         sum(n_total_deaths, na.rm = TRUE)),
            by = codmun_6]

# ---- merge tudo ----
df <- merge(pop_pib, delta_tb, by = "muni_id", all.x = TRUE)
df <- merge(df, delta_icsap, by = "muni_id", all.x = TRUE)
df <- merge(df, treat, by = "muni_id", all.x = TRUE)
df <- merge(df, div[, .(codmun_6, divergence_z, iso_emb_z, iso_km_z)],
            by = "codmun_6", all.x = TRUE)
df <- merge(df, r99, by = "codmun_6", all.x = TRUE)

cat("merged rows:", nrow(df), "\n")
cat("treated:", sum(df$treated == 1, na.rm = TRUE), "\n")
cat("pure controls:", sum(df$treated == 0, na.rm = TRUE), "\n")

# ---- filtrar para munis com features completas ----
needed <- c("delta_tb", "delta_icsap", "treated",
            "iso_emb_z", "iso_km_z", "divergence_z",
            "pop_log_pre", "pib_log_pre", "r99_frac")
df_clean <- df[complete.cases(df[, ..needed])]
cat("complete cases:", nrow(df_clean),
    " (treated:", sum(df_clean$treated == 1),
    " controls:", sum(df_clean$treated == 0), ")\n")

# UF dummies
uf_dum <- model.matrix(~ uf - 1, data = df_clean)
colnames(uf_dum) <- gsub("^uf", "uf_", colnames(uf_dum))

# ---- features matrix X ----
X <- as.matrix(cbind(
  iso_emb     = df_clean$iso_emb_z,
  iso_km      = df_clean$iso_km_z,
  divergence  = df_clean$divergence_z,
  log_pop     = df_clean$pop_log_pre,
  log_pib     = df_clean$pib_log_pre,
  r99_frac    = df_clean$r99_frac,
  uf_dum
))
cat("X shape:", dim(X), "\n")

# ---- run causal forest para cada outcome ----
run_cf <- function(Y, W, X, label) {
  cat(sprintf("\n--- %s ---\n", label))
  set.seed(42)
  cf <- causal_forest(X, Y, W, num.trees = 4000, honesty = TRUE)

  ate <- average_treatment_effect(cf, target.sample = "all")
  cat(sprintf("ATE: %+.3f  SE: %.3f  Z: %.2f\n",
              ate[1], ate[2], ate[1] / ate[2]))

  # variable importance
  vi <- variable_importance(cf)
  vi_dt <- data.table(feature = colnames(X), importance = as.numeric(vi))
  vi_dt <- vi_dt[order(-importance)]
  cat("Top 10 features by importance:\n")
  print(vi_dt[1:10])

  # CATE estimates
  tau_hat <- predict(cf)$predictions
  list(ate = ate[1], se_ate = ate[2],
       vi = vi_dt, tau_hat = tau_hat,
       cf_object = cf)
}

results <- list()
results$tb <- run_cf(df_clean$delta_tb, df_clean$treated, X, "Travel burden Δ")
results$icsap <- run_cf(df_clean$delta_icsap, df_clean$treated, X, "ICSAP Δ")

# ---- Best Linear Projection (Athey-Wager): β_X identifica heterogeneity por feature ----
best_proj <- function(cf, X_dt, label) {
  cat(sprintf("\n--- BLP %s ---\n", label))
  blp <- best_linear_projection(cf, X)
  print(blp)
  blp
}
blp_tb <- best_proj(results$tb$cf_object, X, "Travel")
blp_icsap <- best_proj(results$icsap$cf_object, X, "ICSAP")

# ---- save JSON ----
serialize_cf <- function(r) {
  list(
    ate = r$ate, se_ate = r$se_ate,
    vi_top = list(features = r$vi$feature[1:15],
                   importance = r$vi$importance[1:15])
  )
}
out <- list(
  travel_burden = serialize_cf(results$tb),
  icsap = serialize_cf(results$icsap)
)
write(toJSON(out, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "31_cf_results.json"))
cat("wrote 31_cf_results.json\n")

# ---- plots: CATE by key dim ----
plot_cate_by <- function(tau_hat, x_var, x_label, title) {
  d <- data.table(x = x_var, tau = tau_hat)
  d <- d[order(x)]
  ggplot(d, aes(x = x, y = tau)) +
    geom_point(alpha = 0.18, size = 0.4, color = "#1f77b4") +
    geom_smooth(method = "loess", se = TRUE, color = "#1f77b4", linewidth = 0.7) +
    geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4, linetype = "dashed") +
    labs(x = x_label, y = "CATE (predicted)", title = title) +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank())
}

cate_plots_tb <- (
  plot_cate_by(results$tb$tau_hat, df_clean$iso_emb_z,
               "iso_emb (z-score)", "Travel CATE by iso_emb") |
  plot_cate_by(results$tb$tau_hat, df_clean$divergence_z,
               "divergence (z-score)", "Travel CATE by divergence")
) / (
  plot_cate_by(results$tb$tau_hat, df_clean$pop_log_pre,
               "log(pop)", "Travel CATE by log(pop)") |
  plot_cate_by(results$tb$tau_hat, df_clean$r99_frac,
               "R99 fraction", "Travel CATE by R99 frac")
)
ggsave(file.path(FIG_DIR, "fig_cate_travel.pdf"), cate_plots_tb,
       width = 10, height = 7, device = "pdf")
cat("wrote fig_cate_travel.pdf\n")

cate_plots_icsap <- (
  plot_cate_by(results$icsap$tau_hat, df_clean$iso_emb_z,
               "iso_emb (z-score)", "ICSAP CATE by iso_emb") |
  plot_cate_by(results$icsap$tau_hat, df_clean$divergence_z,
               "divergence (z-score)", "ICSAP CATE by divergence")
) / (
  plot_cate_by(results$icsap$tau_hat, df_clean$pop_log_pre,
               "log(pop)", "ICSAP CATE by log(pop)") |
  plot_cate_by(results$icsap$tau_hat, df_clean$r99_frac,
               "R99 fraction", "ICSAP CATE by R99 frac")
)
ggsave(file.path(FIG_DIR, "fig_cate_icsap.pdf"), cate_plots_icsap,
       width = 10, height = 7, device = "pdf")
cat("wrote fig_cate_icsap.pdf\n")

# ---- variable importance plot ----
vi_plot <- function(vi_dt, label) {
  d <- vi_dt[1:12][order(importance)]
  d[, feature := factor(feature, levels = feature)]
  ggplot(d, aes(x = importance, y = feature)) +
    geom_segment(aes(xend = 0, yend = feature), color = "gray70", linewidth = 0.4) +
    geom_point(color = "#1f77b4", size = 2.2) +
    labs(x = "Variable importance", y = "", title = label) +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank())
}
fig_vi <- vi_plot(results$tb$vi, "Travel burden") |
          vi_plot(results$icsap$vi, "ICSAP")
ggsave(file.path(FIG_DIR, "fig_var_importance.pdf"), fig_vi,
       width = 10, height = 4.5, device = "pdf")
cat("wrote fig_var_importance.pdf\n")

# ---- LaTeX table com ATE + top features ----
tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Causal Forest (Athey-Wager 2019) — average treatment effect (ATE) and top features by variable importance for the heterogeneity of hospital-closure exposure (E1) on travel burden and ICSAP.}",
  "\\label{tab:cf}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Travel burden (\\Delta km) & ICSAP (\\Delta per 1k) \\\\",
  "\\midrule",
  sprintf("ATE & $%+.3f$ (%.3f) & $%+.3f$ (%.3f) \\\\",
          results$tb$ate, results$tb$se_ate,
          results$icsap$ate, results$icsap$se_ate),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Top 5 features by variable importance:}} \\\\")
for (k in 1:5) {
  tab <- c(tab, sprintf("%d. %s & %.3f & %.3f \\\\",
                         k,
                         gsub("_", "\\\\_", results$tb$vi$feature[k]),
                         results$tb$vi$importance[k],
                         results$icsap$vi$importance[
                           match(results$tb$vi$feature[k], results$icsap$vi$feature)
                         ]))
}
tab <- c(tab, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_cf.tex"))
cat("wrote tab_cf.tex\n")

cat(sprintf("\n==== done ==== elapsed %.1fs\n",
            as.numeric(Sys.time() - t0, units = "secs")))
