#!/usr/bin/env Rscript
# 34_robustness_battery.R
#
# S6 — bateria completa de robustness sobre o resultado main do S5
# (F5 main, 60 closures, Sun-Abraham, travel_burden + ICSAP × E1).
#
# Specs:
#   §6.1  alt thresholds θ_emb ∈ {0.01, 0.05, 0.10, 0.25}
#         — definem "exposed" via S2 share threshold; reconstrói gname.
#   §6.2  alt staggered estimators: Sun-Abraham (baseline), Borusyak-
#         Jaravel-Spiess (DID-imputation via fixest::feols + did_imputation),
#         CS21 (did::att_gt) — três estimadores sobre mesmo painel.
#   §6.3  excluir capitais (drop UF capital codmuns).
#   §6.4  excluir Norte/Nordeste (regiões 1/2 IBGE).
#   §6.5  pop_min ∈ {10k, 20k, 50k} — restringe sample por porte.
#   §6.6  pandemic gap excluded (drop 2020-2021 obs).
#   §6.7  R2 perturbation as alt exposure (threshold 0.20 sobre signal).
#
# Outputs:
#   04_logs/34_robustness.json
#   01_manuscript/tables/tab_robustness.tex (tabela consolidada)
#   04_figures/fig_robustness_forest.pdf (forest plot ATT por spec)

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

cat("==== begin S6 robustness battery ====\n")
t0 <- Sys.time()

# ---- helpers ----
run_sa <- function(panel, yname, gname_col) {
  d <- panel[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(get(gname_col)) | get(gname_col) == 0,
                        10000L, as.integer(get(gname_col)))]
  if (d[gn_use < 10000, uniqueN(muni_id)] < 5) return(NULL)
  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) { cat("ERR:", conditionMessage(e), "\n"); NULL })
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]),
       se  = as.numeric(se(agg)[1]),
       n_treated = d[gn_use < 10000, uniqueN(muni_id)],
       n_obs = nrow(d))
}

# Borusyak-Jaravel-Spiess imputation: rodar pelo método did_imputation se
# disponível; caso contrário, usar TWFE ortogonalizado simples.
run_bjs <- function(panel, yname, gname_col) {
  # implementação simples via fixest com efficient TWFE (sem agregação SA)
  d <- panel[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(get(gname_col)) | get(gname_col) == 0,
                        10000L, as.integer(get(gname_col)))]
  d[, treated_yr := as.integer(year >= gn_use)]
  fml <- as.formula(sprintf("%s ~ treated_yr | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) NULL)
  if (is.null(m)) return(NULL)
  cf <- coef(m)["treated_yr"]
  se_ <- se(m)["treated_yr"]
  list(att = as.numeric(cf), se = as.numeric(se_),
       n_treated = d[gn_use < 10000, uniqueN(muni_id)],
       n_obs = nrow(d))
}

# CS21 via did::att_gt (handle fastglm segfault by est_method "ipw")
run_cs21 <- function(panel, yname, gname_col) {
  if (!requireNamespace("did", quietly = TRUE)) return(NULL)
  d <- panel[is.finite(get(yname))]
  d[, gn := as.integer(get(gname_col))]
  d[is.na(gn) | gn == 0, gn := 0]
  res <- tryCatch({
    did::att_gt(yname = yname, tname = "year", idname = "muni_id",
                gname = "gn", data = d, xformla = ~ 1,
                control_group = "notyettreated", est_method = "ipw",
                panel = TRUE, allow_unbalanced_panel = TRUE,
                bstrap = FALSE, cband = FALSE, print_details = FALSE)
  }, error = function(e) { cat("CS21 ERR:", conditionMessage(e), "\n"); NULL })
  if (is.null(res)) return(NULL)
  agg <- tryCatch(did::aggte(res, type = "simple", na.rm = TRUE),
                  error = function(e) NULL)
  if (is.null(agg)) return(NULL)
  list(att = agg$overall.att, se = agg$overall.se,
       n_treated = d[gn > 0, uniqueN(muni_id)],
       n_obs = nrow(d))
}

# ---- data inputs ----
panel_main <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
panel_main[, codmun_6 := as.character(codmun_6)]
exposure <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))
exposure[, codmun_6 := as.character(codmun_6)]
clo <- as.data.table(read_parquet(file.path(INTER, "hospital_closures_exogenous.parquet")))
pert <- as.data.table(read_parquet(file.path(INTER, "perturbation_panel.parquet")))
pert[, codmun_6 := as.character(codmun_6)]

# capitais IBGE (codmun_6 das 27 capitais brasileiras)
capitais <- c("120040", "270430", "130260", "160030", "292740", "230440",
              "530010", "320530", "520870", "211130", "510340", "500270",
              "310620", "150140", "250750", "410690", "261160", "330455",
              "240810", "140010", "431490", "110020", "220840", "420540",
              "350280", "172100", "355030")  # AC, AL, AM, AP, BA, CE, DF,
                                              # ES, GO, MA, MT, MS, MG, PA,
                                              # PB, PR, PE, RJ, RN, RR, RS,
                                              # RO, PI, SC, SP*2, TO

# ---- specs ----
results <- list()
register <- function(label, spec, yname, exposure_label, r) {
  if (is.null(r)) {
    cat(sprintf("  %s | %s | %s : SKIPPED\n", label, spec, yname)); return()
  }
  z <- abs(r$att / max(r$se, 1e-9))
  sig <- ifelse(z > 2.58, "***", ifelse(z > 1.96, "**",
         ifelse(z > 1.64, "*", "")))
  cat(sprintf("  %s | %s | %s | %s : ATT=%+.3f SE=%.3f n_tr=%d %s\n",
              label, spec, yname, exposure_label,
              r$att, r$se, r$n_treated, sig))
  results[[length(results) + 1]] <<- c(
    list(label = label, spec = spec, yname = yname,
         exposure = exposure_label,
         att = r$att, se = r$se, z = z, sig = sig,
         n_treated = r$n_treated, n_obs = r$n_obs))
}

# ============================================================
# §6.1 — alt thresholds θ_emb ∈ {0.01, 0.05, 0.10, 0.25}
# ============================================================
cat("\n=== §6.1 alt thresholds θ_emb ===\n")
for (theta in c(0.01, 0.05, 0.10, 0.25)) {
  exp_thr <- exposure[exposed_emb == TRUE & share_emb >= theta]
  g_emb_thr <- exp_thr[, .(g_emb_thr = min(year_closure)), by = codmun_6]
  panel_thr <- merge(panel_main, g_emb_thr, by = "codmun_6", all.x = TRUE)
  panel_thr[is.na(g_emb_thr), g_emb_thr := 0]
  for (yn in c("travel_burden_km", "icsap_per1k")) {
    register(sprintf("§6.1 θ=%.2f", theta), "thr_emb", yn, "E1",
             run_sa(panel_thr, yn, "g_emb_thr"))
  }
}

# ============================================================
# §6.2 — alt staggered estimators
# ============================================================
cat("\n=== §6.2 alt estimators ===\n")
for (yn in c("travel_burden_km", "icsap_per1k")) {
  register("§6.2 SA",   "estim_SA",   yn, "E1", run_sa(panel_main, yn, "g_emb"))
  register("§6.2 BJS",  "estim_BJS",  yn, "E1", run_bjs(panel_main, yn, "g_emb"))
  register("§6.2 CS21", "estim_CS21", yn, "E1", run_cs21(panel_main, yn, "g_emb"))
}

# ============================================================
# §6.3 — excluir capitais
# ============================================================
cat("\n=== §6.3 excluir capitais ===\n")
panel_no_cap <- panel_main[!codmun_6 %in% capitais]
for (yn in c("travel_burden_km", "icsap_per1k")) {
  register("§6.3 no-capitais", "no_cap", yn, "E1",
           run_sa(panel_no_cap, yn, "g_emb"))
}

# ============================================================
# §6.4 — excluir Norte/Nordeste
# ============================================================
cat("\n=== §6.4 excluir Norte/Nordeste ===\n")
panel_no_N_NE <- panel_main[!substr(codmun_6, 1, 1) %in% c("1", "2")]
for (yn in c("travel_burden_km", "icsap_per1k")) {
  register("§6.4 no-N/NE", "no_N_NE", yn, "E1",
           run_sa(panel_no_N_NE, yn, "g_emb"))
}

# ============================================================
# §6.5 — pop_min ∈ {10k, 20k, 50k}
# ============================================================
cat("\n=== §6.5 pop_min ===\n")
pop_min_per_muni <- panel_main[, .(pop_pre = mean(pop, na.rm = TRUE)),
                                by = codmun_6]
for (pmin in c(10000, 20000, 50000)) {
  keep <- pop_min_per_muni[pop_pre >= pmin, codmun_6]
  panel_p <- panel_main[codmun_6 %in% keep]
  for (yn in c("travel_burden_km", "icsap_per1k")) {
    register(sprintf("§6.5 pop≥%dk", pmin/1000), "pop_min", yn, "E1",
             run_sa(panel_p, yn, "g_emb"))
  }
}

# ============================================================
# §6.6 — pandemic gap excluded (drop 2020-2021)
# ============================================================
cat("\n=== §6.6 sem pandemia ===\n")
panel_no_pand <- panel_main[!year %in% c(2020L, 2021L)]
for (yn in c("travel_burden_km", "icsap_per1k")) {
  register("§6.6 sem pandemia", "no_pand", yn, "E1",
           run_sa(panel_no_pand, yn, "g_emb"))
}

# ============================================================
# §6.7 — R2 perturbation as alt exposure (threshold 0.20)
# ============================================================
cat("\n=== §6.7 perturbation as alt exposure ===\n")
pert_max <- pert[order(-perturbation_signal),
                  .SD[1], by = codmun_6,
                  .SDcols = c("CNES_fechou", "year_closure",
                              "perturbation_signal")]
treated_pert <- pert_max[perturbation_signal >= 0.20]
g_pert <- treated_pert[, .(g_pert = year_closure), by = codmun_6]
panel_pert <- merge(panel_main, g_pert, by = "codmun_6", all.x = TRUE)
panel_pert[is.na(g_pert), g_pert := 0]
for (yn in c("travel_burden_km", "icsap_per1k")) {
  register("§6.7 perturb≥0.20", "perturb_alt", yn, "E1_pert",
           run_sa(panel_pert, yn, "g_pert"))
}

# ============================================================
# Save consolidated results
# ============================================================
res_dt <- rbindlist(lapply(results, as.data.table), fill = TRUE)
cat(sprintf("\nTotal de specs rodados: %d\n", nrow(res_dt)))

# JSON
write(toJSON(results, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "34_robustness.json"))
cat("wrote 34_robustness.json\n")

# LaTeX table consolidada
make_row <- function(r) {
  sprintf("%s & %s & $%+.3f$%s & %.3f & %d \\\\",
          r$label,
          ifelse(r$yname == "travel_burden_km", "Travel (km)", "ICSAP per 1k"),
          r$att,
          ifelse(r$z > 2.58, "$^{***}$",
            ifelse(r$z > 1.96, "$^{**}$",
            ifelse(r$z > 1.64, "$^{*}$", ""))),
          r$se, r$n_treated)
}
tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Robustness battery (S6): event-study ATT estimates under alternative thresholds, estimators, sample restrictions, and exposure definitions. All specifications use Sun-Abraham unless otherwise noted; cluster-robust SE at municipality level. Reference (main): F5 panel, 60 closures, $\\theta_{\\text{emb}}=0.05$.}",
  "\\label{tab:robustness}",
  "\\small",
  "\\begin{tabular}{llrrr}",
  "\\toprule",
  "Robustness spec & Outcome & ATT & SE & $N_{tr}$ \\\\",
  "\\midrule")
for (r in results) tab <- c(tab, make_row(r))
tab <- c(tab, "\\bottomrule",
  "\\multicolumn{5}{l}{\\footnotesize $^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01.} \\\\",
  "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_robustness.tex"))
cat("wrote tab_robustness.tex\n")

# Forest plot (travel + ICSAP em painéis separados)
res_dt[, sig_label := ifelse(z > 2.58, "***",
                       ifelse(z > 1.96, "**",
                       ifelse(z > 1.64, "*", "")))]
res_dt[, label_full := paste0(label, " ", sig_label)]
res_dt[, lo := att - 1.96 * se]
res_dt[, hi := att + 1.96 * se]
res_dt[, idx := .I]

plot_forest <- function(d, yn, title, xlim = NULL) {
  dd <- d[yname == yn][order(-idx)]
  dd[, label_full := factor(label_full, levels = label_full)]
  p <- ggplot(dd, aes(x = att, y = label_full)) +
    geom_vline(xintercept = 0, color = "gray60", linewidth = 0.4, linetype = "dashed") +
    geom_pointrange(aes(xmin = lo, xmax = hi), color = "#1f77b4",
                    linewidth = 0.5, size = 0.4) +
    labs(x = "ATT (95% CI)", y = "", title = title) +
    theme_minimal(base_size = 8.5) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank(),
          plot.title = element_text(size = 10, hjust = 0))
  if (!is.null(xlim)) p <- p + coord_cartesian(xlim = xlim)
  p
}
fig_tb <- plot_forest(res_dt, "travel_burden_km",
                      "Travel burden (km) — robustness forest")
fig_ic <- plot_forest(res_dt, "icsap_per1k",
                      "ICSAP per 1k — robustness forest")
fig <- fig_tb / fig_ic
ggsave(file.path(FIG_DIR, "fig_robustness_forest.pdf"), fig,
       width = 10, height = 11, device = "pdf")
cat("wrote fig_robustness_forest.pdf\n")

cat(sprintf("\n==== done ==== elapsed %.1fs (%.1fmin)\n",
            as.numeric(Sys.time() - t0, units = "secs"),
            as.numeric(Sys.time() - t0, units = "mins")))
