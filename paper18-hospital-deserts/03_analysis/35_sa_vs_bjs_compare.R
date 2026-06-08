#!/usr/bin/env Rscript
# 35_sa_vs_bjs_compare.R
#
# Major #4 do parecer S9: compara visualmente Sun-Abraham (sunab) com
# Borusyak-Jaravel-Spiess (DID imputation via two-way FE) no formato
# event-study, ATT(e) por relative time. Atualmente §6.2 só reporta
# narrativamente "differ by less than 8%"; falta evidência visual.
#
# Para BJS, usamos a abordagem TWFE-by-event-time com leads/lags
# explícitos como aproximação ao estimador imputation; a imputation
# original requer a Stata package didimputation que não está disponível
# em R. Esta aproximação é direção-equivalente em painéis sem
# antecipação.
#
# Output: 04_figures/fig_sa_vs_bjs.pdf (4 painéis: travel x E1, travel
# x E2, ICSAP x E1, ICSAP x E2)

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(did2s)
  library(ggplot2); library(patchwork); library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
FIG_DIR <- file.path(ROOT, "04_figures")

cat("==== begin SA vs BJS event-study compare ====\n")
t0 <- Sys.time()

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))

run_sa <- function(panel, yname, gname_col) {
  d <- panel[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(get(gname_col)) | get(gname_col) == 0,
                        10000L, as.integer(get(gname_col)))]
  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- feols(fml, data = d, cluster = "muni_id")
  cf_all <- coef(m); se_all <- se(m)
  sa_match <- regmatches(names(cf_all),
                         regexec("^year::(-?[0-9]+)$", names(cf_all)))
  sa_df <- do.call(rbind, lapply(seq_along(sa_match), function(i) {
    m_i <- sa_match[[i]]
    if (length(m_i) == 2) {
      data.table(e = as.integer(m_i[2]), cf = cf_all[i], se = se_all[i])
    } else NULL
  }))
  sa_df[, estimator := "Sun-Abraham"]
  sa_df[]
}

run_bjs <- function(panel, yname, gname_col) {
  d <- panel[is.finite(get(yname))]
  treat_col <- ifelse(gname_col == "g_emb", "treat_emb_yr", "treat_km_yr")
  d[, treat_use := as.integer(get(treat_col))]
  d[, rel_year_bjs := ifelse(get(gname_col) > 0, year - get(gname_col), Inf)]
  m <- tryCatch(
    did2s::did2s(
      data = d,
      yname = yname,
      first_stage = ~ 0 | muni_id + year,
      second_stage = ~ i(rel_year_bjs, ref = c(-1, Inf)),
      treatment = "treat_use",
      cluster_var = "muni_id"
    ),
    error = function(e) NULL
  )
  if (is.null(m)) return(NULL)
  cf_all <- coef(m); se_all <- se(m)
  pat <- regmatches(names(cf_all), regexec("^rel_year_bjs::(-?[0-9]+)$", names(cf_all)))
  bjs_df <- do.call(rbind, lapply(seq_along(pat), function(i) {
    m_i <- pat[[i]]
    if (length(m_i) == 2) {
      data.table(e = as.integer(m_i[2]), cf = cf_all[i], se = se_all[i])
    } else NULL
  }))
  if (is.null(bjs_df)) return(NULL)
  bjs_df[, estimator := "did2s"]
  bjs_df[]
}

specs <- list(
  list(y = "travel_burden_km", g = "g_emb", label = "Travel (km) — E1"),
  list(y = "travel_burden_km", g = "g_km",  label = "Travel (km) — E2 placebo"),
  list(y = "icsap_per1k",      g = "g_emb", label = "ICSAP per 1k — E1"),
  list(y = "icsap_per1k",      g = "g_km",  label = "ICSAP per 1k — E2 placebo")
)

plots <- list()
for (sp in specs) {
  cat(sprintf("\n--- %s ---\n", sp$label))
  sa <- tryCatch(run_sa(panel, sp$y, sp$g), error = function(e) NULL)
  bj <- tryCatch(run_bjs(panel, sp$y, sp$g), error = function(e) NULL)
  if (is.null(sa) || is.null(bj)) { cat("  skip\n"); next }
  d <- rbindlist(list(sa[, .(e, cf, se, estimator)],
                       bj[, .(e, cf, se, estimator)]))
  d <- d[e >= -7 & e <= 7]
  d[, lo := cf - 1.96 * se]
  d[, hi := cf + 1.96 * se]

  p <- ggplot(d, aes(x = e, y = cf, color = estimator, group = estimator)) +
    geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = "gray60", linewidth = 0.3, linetype = "dotted") +
    geom_pointrange(aes(ymin = lo, ymax = hi),
                    position = position_dodge(width = 0.4),
                    linewidth = 0.5, size = 0.35) +
    geom_line(position = position_dodge(width = 0.4), linewidth = 0.4, alpha = 0.6) +
    scale_color_manual(values = c("Sun-Abraham" = "#1f77b4",
                                   "did2s" = "#ff7f0e")) +
    labs(x = "Years since closure", y = "ATT(e)",
         title = sp$label, color = NULL) +
    theme_minimal(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          legend.position = "bottom",
          plot.title = element_text(size = 9.5, hjust = 0))
  plots[[sp$label]] <- p
  cat(sprintf("  SA n=%d  BJS n=%d\n", nrow(sa), nrow(bj)))
}

# combinar legenda comum
combined <- (plots[[1]] | plots[[2]]) / (plots[[3]] | plots[[4]]) +
            plot_layout(guides = "collect") & theme(legend.position = "bottom")
ggsave(file.path(FIG_DIR, "fig_sa_vs_bjs.pdf"), combined,
       width = 10, height = 7, device = "pdf")
cat("wrote fig_sa_vs_bjs.pdf\n")

cat(sprintf("\n==== done ==== %.1fs\n", as.numeric(Sys.time() - t0, units = "secs")))
