#!/usr/bin/env Rscript
# 24b_event_study_cs21.R
#
# Event-study sobre fechamentos hospitalares.
#
# **Piloto via Sun-Abraham (fixest::sunab)** — não-fastglm, robusto. CS21
# (did::att_gt) com est_method∈{dr, reg} segfalha na versão atual do pacote
# fastglm em R 4.5; avaliar fix em S5 final. Sun-Abraham é equivalente para
# painel staggered sob hipóteses similares (no antecipação, controle nyt).
#
# Especificação Sun-Abraham:
#   y_it = sum_{e ≠ -1} δ_e × 1{rel_t == e} + α_i + γ_t + ε_it
#   onde δ_e é o ATT(e) (estimador SA agrega CS-style por coorte).
#
# Outcomes: travel_burden_km (primary), icsap_per1k (secondary).
# Exposures (gnames): g_emb (E1) e g_km (E2 placebo).
#
# Outputs:
# - 04_logs/24b_es_results.json
# - 04_figures/fig_es_<outcome>_<gname>.pdf  (×4)
# - 01_manuscript/tables/tab_es_pilot.tex

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else {
  normalizePath(getwd())
}
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
FIG_DIR <- file.path(ROOT, "04_figures")
TAB_DIR <- file.path(ROOT, "01_manuscript", "tables")
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)

PANEL <- file.path(INTER, "staggered_panel.parquet")
cat("==== begin Sun-Abraham event-study (piloto) ====\n")
t0 <- Sys.time()

panel <- as.data.table(read_parquet(PANEL))
cat("rows do painel:", nrow(panel), "  munis:", panel[, uniqueN(muni_id)], "\n")

# ---- helper ----
run_sunab <- function(panel, yname, gname_col, label) {
  d <- panel[is.finite(get(yname))]

  # gname (treatment cohort year): 0 = nunca tratado. Sun-Abraham usa
  # +Inf ou um valor grande para never-treated.
  d[, gname_use := ifelse(get(gname_col) == 0, 10000, get(gname_col))]

  cat(sprintf("\n--- %s ---\n", label))
  cat("rows:", nrow(d), "  munis:", d[, uniqueN(muni_id)], "\n")
  cat("treated cohorts:", paste(sort(unique(d[gname_use < 10000, gname_use])), collapse = ", "), "\n")
  cat("treated munis:", d[gname_use < 10000, uniqueN(muni_id)],
      "  never-treated:", d[gname_use == 10000, uniqueN(muni_id)], "\n")

  # Sun-Abraham via fixest
  fml <- as.formula(sprintf("%s ~ sunab(gname_use, year) | muni_id + year", yname))
  m <- tryCatch(
    feols(fml, data = d, cluster = "muni_id"),
    error = function(e) { cat("ERRO sunab:", conditionMessage(e), "\n"); NULL }
  )
  if (is.null(m)) return(NULL)

  # extrair event-study coefs
  agg <- summary(m, agg = "att")        # ATT médio simples
  cf_simple <- coef(agg)
  se_simple <- se(agg)
  att_simple <- as.numeric(cf_simple[1])
  se_simple_v <- as.numeric(se_simple[1])

  agg_dyn <- summary(m, agg = c("ATT" = "year::[^:]+"))  # workaround para event-study
  # alternativa robusta: extrair coefs por relative time direto
  cf_all <- coef(m)
  se_all <- se(m)
  # Sun-Abraham gera coefs no formato "year::<g>::<t>": agregamos por (t-g)
  cf_names <- names(cf_all)
  sa_match <- regmatches(cf_names, regexec("^year::([0-9]+)::([0-9]+)$", cf_names))
  sa_df <- do.call(rbind, lapply(seq_along(sa_match), function(i) {
    m_i <- sa_match[[i]]
    if (length(m_i) == 3) {
      data.table(name = cf_names[i], g = as.integer(m_i[2]),
                 t = as.integer(m_i[3]), e = as.integer(m_i[3]) - as.integer(m_i[2]),
                 cf = cf_all[i], se = se_all[i])
    } else NULL
  }))

  if (is.null(sa_df) || nrow(sa_df) == 0) {
    # tentar padrão alternativo
    sa_match <- regmatches(cf_names, regexec("^year::(-?[0-9]+)$", cf_names))
    sa_df <- do.call(rbind, lapply(seq_along(sa_match), function(i) {
      m_i <- sa_match[[i]]
      if (length(m_i) == 2) {
        data.table(name = cf_names[i], e = as.integer(m_i[2]),
                   cf = cf_all[i], se = se_all[i])
      } else NULL
    }))
  }

  list(
    att_simple = att_simple,
    se_simple = se_simple_v,
    es_df = sa_df,
    n_obs = nrow(d),
    n_treated = d[gname_use < 10000, uniqueN(muni_id)]
  )
}

# ---- run all 4 specs ----
results <- list()
for (yname in c("travel_burden_km", "icsap_per1k")) {
  for (gname_col in c("g_emb", "g_km")) {
    label <- sprintf("%s × %s", yname, gname_col)
    res <- run_sunab(panel, yname, gname_col, label)
    if (!is.null(res)) {
      key <- paste0(yname, "__", gname_col)
      cat(sprintf("  ATT_simple = %+.3f  SE = %.3f  n_treated = %d\n",
                  res$att_simple, res$se_simple, res$n_treated))
      results[[key]] <- res
    }
  }
}

# ---- event-study plots ----
plot_es <- function(es_df, label, file_pdf) {
  if (is.null(es_df) || nrow(es_df) == 0) return(NULL)
  if (!"e" %in% names(es_df)) return(NULL)
  d <- copy(es_df)
  # se houver duplicatas por e (devido a múltiplos g), agregar via média ponderada
  if (anyDuplicated(d$e)) {
    d <- d[, .(cf = mean(cf), se = sqrt(mean(se^2))), by = e]
  }
  d[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se)]
  d <- d[order(e)]
  d <- d[e >= -7 & e <= 7]
  p <- ggplot(d, aes(x = e, y = cf)) +
    geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = "gray60", linewidth = 0.3, linetype = "dotted") +
    geom_pointrange(aes(ymin = lo, ymax = hi), color = "#1f77b4",
                    linewidth = 0.7, size = 0.5) +
    geom_line(color = "#1f77b4", linewidth = 0.4, alpha = 0.6) +
    labs(x = "Years since closure (e)", y = expression(ATT(e)),
         title = label) +
    theme_minimal(base_size = 11) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(size = 11, hjust = 0))
  ggsave(file_pdf, p, width = 6.5, height = 4, device = "pdf")
  p
}

for (key in names(results)) {
  parts <- strsplit(key, "__")[[1]]
  yname <- parts[1]; gname_col <- parts[2]
  short_g <- ifelse(gname_col == "g_emb", "embedding (E1)", "km only (E2 placebo)")
  short_y <- ifelse(yname == "travel_burden_km", "Travel burden (km)", "ICSAP per 1k")
  label <- paste0(short_y, " — exposure: ", short_g)
  file_pdf <- file.path(FIG_DIR, paste0("fig_es_", yname, "_", gname_col, ".pdf"))
  plot_es(results[[key]]$es_df, label, file_pdf)
  cat("wrote", file_pdf, "\n")
}

# ---- JSON dump ----
serialize_res <- function(r) {
  list(
    att_simple = r$att_simple,
    se_simple = r$se_simple,
    n_obs = r$n_obs,
    n_treated = r$n_treated,
    es_e = r$es_df$e,
    es_cf = r$es_df$cf,
    es_se = r$es_df$se
  )
}
serialized <- lapply(results, serialize_res)
write(toJSON(serialized, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "24b_es_results.json"))
cat("wrote", file.path(LOG_DIR, "24b_es_results.json"), "\n")

# ---- LaTeX table ----
tab_lines <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Pilot Sun-Abraham event-study ATT estimates: hospital closures via embedding-based exposure (E1) vs km-based exposure (E2, placebo). $N=60$ closures, panel 2010--2024.}",
  "\\label{tab:es-pilot}",
  "\\small",
  "\\begin{tabular}{llrrr}",
  "\\toprule",
  "Outcome & Exposure & ATT (simple) & SE & $N_{\\text{treated}}$ \\\\",
  "\\midrule"
)
for (key in names(results)) {
  parts <- strsplit(key, "__")[[1]]
  yname <- parts[1]; gname_col <- parts[2]
  ynice <- ifelse(yname == "travel_burden_km", "Travel burden (km)", "ICSAP per 1k")
  gnice <- ifelse(gname_col == "g_emb", "E1 (embedding)", "E2 (km, placebo)")
  r <- results[[key]]
  tab_lines <- c(tab_lines, sprintf(
    "%s & %s & $%+.3f$ & %.3f & %d \\\\",
    ynice, gnice, r$att_simple, r$se_simple, r$n_treated
  ))
}
tab_lines <- c(tab_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{table}"
)
writeLines(tab_lines, file.path(TAB_DIR, "tab_es_pilot.tex"))
cat("wrote", file.path(TAB_DIR, "tab_es_pilot.tex"), "\n")

cat(sprintf("\n==== done ==== elapsed %.1fs\n",
            as.numeric(Sys.time() - t0, units = "secs")))
