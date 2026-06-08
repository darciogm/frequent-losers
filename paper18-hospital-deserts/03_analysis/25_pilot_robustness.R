#!/usr/bin/env Rscript
# 25_pilot_robustness.R
#
# Robustness do piloto S5 antes de comprometer dias com R1 (NLP).
# Roda 4 estimações Sun-Abraham extras:
#
# (a) Heterogeneity por tipo de hospital fechado:
#     (a1) gname_general (closures tp_unid=05): 24 munis E1-tratados
#     (a2) gname_specialized (tp_unid=07): 105 munis E1-tratados
#     Hipótese: efeito de magnitude maior em especializado (substituição
#     de cuidado especializado é mecanismo da explicação alternativa).
#
# (b) Excluir pandemia (2020-2021) do painel — sanity de que o resultado
#     sobrevive sem o gap.
#
# Outcomes: travel_burden_km + icsap_per1k. Exposure: E1.
#
# Outputs:
# - 04_logs/25_robustness.json
# - 04_figures/fig_es_robustness.pdf (4 painéis)
# - 01_manuscript/tables/tab_es_robustness.tex

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(jsonlite)
  library(patchwork)
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

PANEL <- file.path(INTER, "staggered_panel.parquet")
EXP_FILE <- file.path(INTER, "exposure_panel.parquet")
CLO_FILE <- file.path(INTER, "hospital_closures_exogenous.parquet")

cat("==== begin pilot robustness ====\n")
t0 <- Sys.time()

panel <- as.data.table(read_parquet(PANEL))

# ---- carregar exposure × tipo de hospital ----
exp_raw <- as.data.table(read_parquet(EXP_FILE))
clo <- as.data.table(read_parquet(CLO_FILE))
clo <- clo[exogenous == TRUE, .(CNES, tp_unid)]
exp_typed <- merge(exp_raw[exposed_emb == TRUE], clo, by = "CNES")

# ---- gname por tipo ----
g_general <- exp_typed[tp_unid == "05",
                       .(g_general = min(year_closure)), by = codmun_6]
g_specialized <- exp_typed[tp_unid == "07",
                           .(g_specialized = min(year_closure)), by = codmun_6]
g_other <- exp_typed[tp_unid != "05" & tp_unid != "07",
                     .(g_other = min(year_closure)), by = codmun_6]

cat("munis E1-tratados via geral (05):", nrow(g_general), "\n")
cat("munis E1-tratados via especializado (07):", nrow(g_specialized), "\n")
cat("munis E1-tratados via outros tipos:", nrow(g_other), "\n")

# overlap (munis tratados via mais de um tipo)
overlap_gs <- intersect(g_general$codmun_6, g_specialized$codmun_6)
cat("overlap geral × especializado:", length(overlap_gs), "munis\n")

# ---- helper SunAb ----
run_sa <- function(d, yname, gname_var) {
  setnames(d, gname_var, "gn", skip_absent = TRUE)
  d[, gn_use := ifelse(is.na(gn) | gn == 0, 10000L, as.integer(gn))]
  d <- d[is.finite(get(yname))]

  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) { cat("ERRO sunab:", conditionMessage(e), "\n"); NULL })
  setnames(d, "gn", gname_var, skip_absent = TRUE)
  if (is.null(m)) return(NULL)

  agg <- summary(m, agg = "att")
  cf_simple <- as.numeric(coef(agg)[1])
  se_simple <- as.numeric(se(agg)[1])

  cf_all <- coef(m); se_all <- se(m)
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
       n_treated = d[gn_use < 10000, uniqueN(muni_id)])
}

# ---- (a1) HETEROGENEITY: geral (05) ----
panel_general <- copy(panel)
# manter apenas munis tratados por geral OU controles puros (g_emb == 0)
# excluir munis que foram E1-tratados por outro tipo
exclude_other <- union(g_specialized$codmun_6, g_other$codmun_6)
exclude_other <- setdiff(exclude_other, g_general$codmun_6)  # quem é só geral fica
panel_general <- panel_general[!codmun_6 %in% exclude_other]
panel_general <- merge(panel_general, g_general, by = "codmun_6", all.x = TRUE)
cat("\n--- (a1) heterogeneity GERAL (tp_unid=05) ---\n")
cat("painel rows:", nrow(panel_general), "  munis:", panel_general[, uniqueN(muni_id)], "\n")

# ---- (a2) HETEROGENEITY: especializado (07) ----
panel_special <- copy(panel)
exclude_other_s <- union(g_general$codmun_6, g_other$codmun_6)
exclude_other_s <- setdiff(exclude_other_s, g_specialized$codmun_6)
panel_special <- panel_special[!codmun_6 %in% exclude_other_s]
panel_special <- merge(panel_special, g_specialized, by = "codmun_6", all.x = TRUE)
cat("\n--- (a2) heterogeneity ESPECIALIZADO (tp_unid=07) ---\n")
cat("painel rows:", nrow(panel_special), "  munis:", panel_special[, uniqueN(muni_id)], "\n")

# ---- (b) exclude pandemic ----
panel_nopand <- panel[!year %in% c(2020L, 2021L)]
cat("\n--- (b) excluir pandemia 2020-2021 ---\n")
cat("painel rows:", nrow(panel_nopand), "(orig", nrow(panel), ")\n")

# ---- run estimations ----
results <- list()
specs <- list(
  list(label = "Travel × E1, hospital geral (05)",
       data = panel_general, y = "travel_burden_km", g = "g_general", key = "tb_general"),
  list(label = "Travel × E1, hospital especializado (07)",
       data = panel_special, y = "travel_burden_km", g = "g_specialized", key = "tb_special"),
  list(label = "ICSAP × E1, hospital geral (05)",
       data = panel_general, y = "icsap_per1k", g = "g_general", key = "icsap_general"),
  list(label = "ICSAP × E1, hospital especializado (07)",
       data = panel_special, y = "icsap_per1k", g = "g_specialized", key = "icsap_special"),
  list(label = "Travel × E1, sem pandemia (2010-19+22-24)",
       data = panel_nopand, y = "travel_burden_km", g = "g_emb", key = "tb_nopand"),
  list(label = "ICSAP × E1, sem pandemia",
       data = panel_nopand, y = "icsap_per1k", g = "g_emb", key = "icsap_nopand")
)

for (sp in specs) {
  cat(sprintf("\n=== %s ===\n", sp$label))
  res <- run_sa(sp$data, sp$y, sp$g)
  if (!is.null(res)) {
    cat(sprintf("  ATT_simple = %+.3f  SE = %.3f  n_treated = %d\n",
                res$att, res$se, res$n_treated))
    if (!is.null(res$es) && nrow(res$es) > 0) {
      cat("  Event-study (e ≥ 0):\n")
      pos <- res$es[e >= 0 & e <= 8]
      for (i in seq_len(nrow(pos))) {
        sig <- ifelse(abs(pos$cf[i])/max(pos$se[i], 1e-9) > 2.58, "***",
               ifelse(abs(pos$cf[i])/max(pos$se[i], 1e-9) > 1.96, "**",
               ifelse(abs(pos$cf[i])/max(pos$se[i], 1e-9) > 1.64, "*", "")))
        cat(sprintf("    e=%+d  ATT=%+8.3f  SE=%6.3f  %s\n",
                    pos$e[i], pos$cf[i], pos$se[i], sig))
      }
    }
    results[[sp$key]] <- list(
      label = sp$label,
      att = res$att, se = res$se, n_treated = res$n_treated,
      es_e = if (!is.null(res$es)) res$es$e else NULL,
      es_cf = if (!is.null(res$es)) res$es$cf else NULL,
      es_se = if (!is.null(res$es)) res$es$se else NULL
    )
  }
}

# ---- panel of event-study plots (4 main: heterogeneity travel + ICSAP × geral/special) ----
make_es_plot <- function(r, title) {
  if (is.null(r$es_e)) return(ggplot() + ggtitle(paste(title, "(empty)")))
  d <- data.table(e = r$es_e, cf = r$es_cf, se = r$es_se)
  d[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se)]
  d <- d[e >= -7 & e <= 7]
  ggplot(d, aes(x = e, y = cf)) +
    geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = "gray60", linewidth = 0.3, linetype = "dotted") +
    geom_pointrange(aes(ymin = lo, ymax = hi), color = "#1f77b4",
                    linewidth = 0.6, size = 0.4) +
    geom_line(color = "#1f77b4", linewidth = 0.4, alpha = 0.6) +
    labs(x = "Years since closure", y = "ATT(e)", title = title) +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(size = 9, hjust = 0))
}

p1 <- make_es_plot(results$tb_general,    "Travel × geral (05)")
p2 <- make_es_plot(results$tb_special,    "Travel × especializado (07)")
p3 <- make_es_plot(results$icsap_general, "ICSAP × geral (05)")
p4 <- make_es_plot(results$icsap_special, "ICSAP × especializado (07)")

panel_fig <- (p1 | p2) / (p3 | p4)
ggsave(file.path(FIG_DIR, "fig_es_robustness.pdf"), panel_fig,
       width = 11, height = 7, device = "pdf")
cat("\nwrote", file.path(FIG_DIR, "fig_es_robustness.pdf"), "\n")

# ---- save JSON ----
write(toJSON(results, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "25_robustness.json"))
cat("wrote", file.path(LOG_DIR, "25_robustness.json"), "\n")

# ---- LaTeX table ----
tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Pilot robustness of the event-study results: heterogeneity by closed-hospital type and exclusion of the pandemic gap.}",
  "\\label{tab:es-robustness}",
  "\\small",
  "\\begin{tabular}{llrrr}",
  "\\toprule",
  "Specification & Outcome & ATT (simple) & SE & $N_{\\text{treated}}$ \\\\",
  "\\midrule"
)
for (key in c("tb_general", "tb_special", "tb_nopand",
              "icsap_general", "icsap_special", "icsap_nopand")) {
  if (key %in% names(results)) {
    r <- results[[key]]
    tab <- c(tab, sprintf("%s & & $%+.3f$ & %.3f & %d \\\\",
                          gsub("_", "\\\\_", r$label), r$att, r$se, r$n_treated))
  }
}
tab <- c(tab, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_es_robustness.tex"))
cat("wrote", file.path(TAB_DIR, "tab_es_robustness.tex"), "\n")

cat(sprintf("\n==== done ==== elapsed %.1fs\n",
            as.numeric(Sys.time() - t0, units = "secs")))
