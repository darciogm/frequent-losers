#!/usr/bin/env Rscript
# 30_event_study_final.R
#
# S5 final híbrido — Sun-Abraham event-studies nos 5 painéis:
#   F5_main (60 closures, filtro estatístico) — main estimation
#   F6_v2   (51 closures, motivo NLP-documentado) — robustness com mecanismo
#   F6_admin / F6_falencia / F6_fiscal — heterogeneity por motivo
#
# Outcomes:
#   travel_burden_km (primary)
#   icsap_per1k      (secondary)
#
# Exposures:
#   E1 (g_emb) — embedding-based
#   E2 (g_km)  — km-based alternative exposure rule (só no F5_main para o paper main)
#
# Outputs:
#   04_logs/30_es_final_results.json
#   04_figures/fig_es_final_main.pdf       — F5×E1 e F5×E2 (4 painéis)
#   04_figures/fig_es_final_robustness.pdf — F6_v2×E1 (2 painéis)
#   04_figures/fig_es_final_heterogeneity.pdf — admin/falencia/fiscal × outcome (6 painéis)
#   01_manuscript/tables/tab_es_final.tex     — síntese completa

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

cat("==== begin S5 final hybrid event-study ====\n")
t0 <- Sys.time()

# ---- helper SunAb ----
run_sunab <- function(panel, yname, gname_col) {
  d <- panel[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(get(gname_col)) | get(gname_col) == 0,
                        10000L, as.integer(get(gname_col)))]

  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) {
                  cat("ERRO sunab:", conditionMessage(e), "\n"); NULL
                })
  if (is.null(m)) return(NULL)

  agg <- summary(m, agg = "att")
  cf_simple <- as.numeric(coef(agg)[1])
  se_simple <- as.numeric(se(agg)[1])

  cf_all <- coef(m); se_all <- se(m)
  # fixest::sunab aggregates cohort×time into single "year::<e>" coefs
  # where e is the relative event time (can be negative).
  sa_match <- regmatches(names(cf_all),
                         regexec("^year::(-?[0-9]+)$", names(cf_all)))
  sa_df <- do.call(rbind, lapply(seq_along(sa_match), function(i) {
    m_i <- sa_match[[i]]
    if (length(m_i) == 2) {
      data.table(e = as.integer(m_i[2]),
                 cf = cf_all[i], se = se_all[i])
    } else NULL
  }))
  if (!is.null(sa_df) && nrow(sa_df) > 0 && anyDuplicated(sa_df$e)) {
    sa_df <- sa_df[, .(cf = mean(cf), se = sqrt(mean(se^2))), by = e][order(e)]
  } else if (!is.null(sa_df)) {
    sa_df <- sa_df[order(e), .(e, cf, se)]
  }
  list(att = cf_simple, se = se_simple, es = sa_df,
       n_treated = d[gn_use < 10000, uniqueN(muni_id)],
       n_obs = nrow(d))
}

# ---- specs ----
panels <- list(
  F5_main     = file.path(INTER, "staggered_panel_F5_main.parquet"),
  F6_v2       = file.path(INTER, "staggered_panel_F6_v2.parquet"),
  F6_human_validated = file.path(INTER, "staggered_panel_F6_human_validated.parquet"),
  F6_admin    = file.path(INTER, "staggered_panel_F6_admin.parquet"),
  F6_falencia = file.path(INTER, "staggered_panel_F6_falencia.parquet"),
  F6_fiscal   = file.path(INTER, "staggered_panel_F6_fiscal.parquet")
)
outcomes <- c("travel_burden_km", "icsap_per1k")
exposures <- c("g_emb", "g_km")

# Estimar tudo. Para painéis hetero (admin/falencia/fiscal), só E1.
results <- list()
for (pname in names(panels)) {
  cat(sprintf("\n========= panel: %s =========\n", pname))
  if (!file.exists(panels[[pname]])) {
    cat("missing panel file; skip\n")
    next
  }
  panel <- as.data.table(read_parquet(panels[[pname]]))
  cat(sprintf("rows: %d  munis: %d\n", nrow(panel), panel[, uniqueN(muni_id)]))

  exps_to_run <- if (pname %in% c("F5_main", "F6_v2")) exposures else "g_emb"
  for (yname in outcomes) {
    for (gn in exps_to_run) {
      key <- sprintf("%s__%s__%s", pname, yname, gn)
      cat(sprintf("\n--- %s ---\n", key))
      r <- run_sunab(panel, yname, gn)
      if (!is.null(r)) {
        cat(sprintf("  ATT=%+.3f  SE=%.3f  n_treated=%d\n",
                    r$att, r$se, r$n_treated))
        if (!is.null(r$es) && nrow(r$es) > 0) {
          pos <- r$es[e >= 0 & e <= 6]
          cat("  ATT(e=0..6):", paste(sprintf("%+.2f", pos$cf), collapse = " "), "\n")
        }
        results[[key]] <- list(
          panel = pname, yname = yname, exposure = gn,
          att = r$att, se = r$se, n_treated = r$n_treated, n_obs = r$n_obs,
          es_e = if (!is.null(r$es)) r$es$e else NULL,
          es_cf = if (!is.null(r$es)) r$es$cf else NULL,
          es_se = if (!is.null(r$es)) r$es$se else NULL
        )
      }
    }
  }
}

# ---- save JSON ----
write(toJSON(results, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "30_es_final_results.json"))
cat("wrote", file.path(LOG_DIR, "30_es_final_results.json"), "\n")

# ---- helper: plot ES ----
plot_es <- function(r, title, ylim = NULL) {
  if (is.null(r$es_e)) return(ggplot() + ggtitle(paste(title, "(empty)")))
  d <- data.table(e = r$es_e, cf = r$es_cf, se = r$es_se)
  d[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se)]
  d <- d[e >= -7 & e <= 7]
  p <- ggplot(d, aes(x = e, y = cf)) +
    geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = "gray60", linewidth = 0.3, linetype = "dotted") +
    geom_pointrange(aes(ymin = lo, ymax = hi), color = "#1f77b4",
                    linewidth = 0.6, size = 0.4) +
    geom_line(color = "#1f77b4", linewidth = 0.4, alpha = 0.6) +
    labs(x = "Years since closure", y = "ATT(e)", title = title) +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(size = 9, hjust = 0))
  if (!is.null(ylim)) p <- p + coord_cartesian(ylim = ylim)
  p
}

# ---- panel: main (F5 × outcome × exposure) ----
p_main <- list()
for (yn in outcomes) {
  for (gn in exposures) {
    key <- sprintf("F5_main__%s__%s", yn, gn)
    if (key %in% names(results)) {
      title <- sprintf("%s — %s",
                       ifelse(yn == "travel_burden_km", "Travel (km)", "ICSAP per 1k"),
                       ifelse(gn == "g_emb", "E1 embedding", "E2 km alternative"))
      p_main[[key]] <- plot_es(results[[key]], title)
    }
  }
}
fig_main <- (p_main[[1]] | p_main[[2]]) / (p_main[[3]] | p_main[[4]])
fig_main <- fig_main + plot_annotation(
  title = "Main estimation (F5_main, 60 closures): event-study by exposure",
  theme = theme(plot.title = element_text(size = 11)))
ggsave(file.path(FIG_DIR, "fig_es_final_main.pdf"), fig_main,
       width = 11, height = 7, device = "pdf")
cat("wrote fig_es_final_main.pdf\n")

# ---- panel: robustness (F6_v2 × outcome × E1) ----
p_rob <- list()
for (yn in outcomes) {
  key <- sprintf("F6_v2__%s__g_emb", yn)
  if (key %in% names(results)) {
    title <- sprintf("F6_v2 (51 docs) — %s — E1",
                     ifelse(yn == "travel_burden_km", "Travel (km)", "ICSAP per 1k"))
    p_rob[[key]] <- plot_es(results[[key]], title)
  }
}
fig_rob <- p_rob[[1]] | p_rob[[2]]
fig_rob <- fig_rob + plot_annotation(
  title = "Robustness — closures with NLP-documented motive",
  theme = theme(plot.title = element_text(size = 11)))
ggsave(file.path(FIG_DIR, "fig_es_final_robustness.pdf"), fig_rob,
       width = 11, height = 4, device = "pdf")
cat("wrote fig_es_final_robustness.pdf\n")

# ---- panel: heterogeneity (admin × falencia × fiscal) ----
p_het <- list()
for (mot in c("F6_admin", "F6_falencia", "F6_fiscal")) {
  for (yn in outcomes) {
    key <- sprintf("%s__%s__g_emb", mot, yn)
    if (key %in% names(results)) {
      label_y <- ifelse(yn == "travel_burden_km", "Travel (km)", "ICSAP per 1k")
      label_m <- gsub("F6_", "", mot)
      title <- sprintf("%s — %s", label_m, label_y)
      p_het[[key]] <- plot_es(results[[key]], title)
    }
  }
}
fig_het <- (p_het[[1]] | p_het[[2]]) / (p_het[[3]] | p_het[[4]]) / (p_het[[5]] | p_het[[6]])
fig_het <- fig_het + plot_annotation(
  title = "Heterogeneity by closure motive (E1 embedding exposure)",
  theme = theme(plot.title = element_text(size = 11)))
ggsave(file.path(FIG_DIR, "fig_es_final_heterogeneity.pdf"), fig_het,
       width = 11, height = 10, device = "pdf")
cat("wrote fig_es_final_heterogeneity.pdf\n")

# ---- LaTeX table ----
panel_label <- function(p) {
  switch(p,
    F5_main     = "F5 Main (statistical filter)",
    F6_v2       = "F6 v2 (NLP-documented)",
    F6_human_validated = "F6 sensitivity (drop fragile labels)",
    F6_admin    = "  $\\hookrightarrow$ administrativo",
    F6_falencia = "  $\\hookrightarrow$ falencia",
    F6_fiscal   = "  $\\hookrightarrow$ fiscal", p)
}
tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{F5 measurement-sample event-study ATT estimates (Sun-Abraham): F5 statistical filter, F6 NLP-documented robustness, and heterogeneity by closure motive. Outcomes: travel burden (km) and ICSAP rate (per 1{,}000 hab). Share-based flow exposure (E1) primary; km-based exposure (E2) as an alternative exposure rule for F5 measurement only. Cluster-robust SE at municipality level. Panel 2010--2024 with pandemic gap 2020--2021 included.}",
  "\\label{tab:es-final}",
  "\\small",
  "\\begin{tabular}{llrrr}",
  "\\toprule",
  "Sample & Outcome / Exposure & ATT & SE & $N_{\\text{treated}}$ \\\\",
  "\\midrule"
)
for (pname in names(panels)) {
  for (yn in outcomes) {
    for (gn in exposures) {
      key <- sprintf("%s__%s__%s", pname, yn, gn)
      if (key %in% names(results)) {
        r <- results[[key]]
        sample <- panel_label(pname)
        outc <- paste(ifelse(yn == "travel_burden_km", "Travel (km)", "ICSAP per 1k"),
                      "/", ifelse(gn == "g_emb", "E1", "E2 alt."))
        # adicionar significância
        z <- abs(r$att / max(r$se, 1e-9))
        sig <- ifelse(z > 2.58, "$^{***}$", ifelse(z > 1.96, "$^{**}$",
                ifelse(z > 1.64, "$^{*}$", "")))
        tab <- c(tab, sprintf("%s & %s & $%+.3f$%s & %.3f & %d \\\\",
                              sample, outc, r$att, sig, r$se, r$n_treated))
      }
    }
  }
  if (pname %in% c("F5_main", "F6_v2")) tab <- c(tab, "\\addlinespace")
}
tab <- c(tab, "\\bottomrule",
  "\\multicolumn{5}{l}{\\footnotesize $^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01.} \\\\",
  "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_es_final.tex"))
cat("wrote tab_es_final.tex\n")

cat(sprintf("\n==== done ==== elapsed %.1fs\n",
            as.numeric(Sys.time() - t0, units = "secs")))
