#!/usr/bin/env Rscript
# 44_theta_sweep.R
#
# Path2-rest #S1 (parecer Major S1): continuous theta sensitivity sweep.
# Re-define E1 exposure for theta in {0.01, 0.02, ..., 0.20} e re-estima
# o ATT Sun-Abraham para travel burden e ICSAP. Reporta o "breakdown
# theta" — maior theta que mantém significância.
#
# Output: 04_logs/44_theta_sweep.json
#         04_figures/fig_theta_sweep.pdf

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
  library(jsonlite); library(ggplot2)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
FIG_DIR <- file.path(ROOT, "04_figures")

cat("==== begin theta sweep ====\n")

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
expo  <- as.data.table(read_parquet(file.path(INTER, "exposure_panel.parquet")))
exo   <- as.data.table(read_parquet(file.path(INTER, "hospital_closures_exogenous.parquet")))
exo60 <- exo[exogenous == TRUE, .(CNES, year_closure_h = year_closure)]
expo  <- merge(expo, exo60, by = "CNES")  # restrict to 60 exogenous

# Para cada theta: para cada município, year_closure mínimo entre os hospitais
# em que share_emb > theta
build_g_theta <- function(expo, theta) {
  d <- expo[share_emb > theta]
  d[, .(g_theta = min(year_closure)), by = .(codmun_6 = codmun_6)]
}

run_att <- function(panel_aug, yname) {
  d <- panel_aug[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(g_theta) | g_theta == 0, 10000L, as.integer(g_theta))]
  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) NULL)
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]),
       se  = as.numeric(se(agg)[1]),
       n_treated = d[gn_use < 10000, uniqueN(muni_id)])
}

theta_grid <- seq(0.01, 0.20, by = 0.01)
results <- list()

panel[, codmun_6 := as.character(codmun_6)]
expo[, codmun_6  := as.character(codmun_6)]

for (theta in theta_grid) {
  treat <- build_g_theta(expo, theta)
  d <- merge(panel[, !c("g_theta"), with = FALSE], treat,
             by = "codmun_6", all.x = TRUE)
  for (yn in c("travel_burden_km", "icsap_per1k")) {
    r <- run_att(d, yn)
    if (is.null(r)) next
    z <- r$att / r$se
    results[[sprintf("%.02f__%s", theta, yn)]] <- list(
      theta = theta, outcome = yn,
      n_treated = r$n_treated,
      att = r$att, se = r$se, z = z,
      pvalue_two_sided = 2 * (1 - pnorm(abs(z))),
      significant_05 = abs(z) >= 1.96
    )
    cat(sprintf("  theta=%.2f | %-18s | n_t=%3d | ATT=%+7.3f | SE=%5.3f | z=%5.2f | sig: %s\n",
                theta, yn, r$n_treated, r$att, r$se, z,
                ifelse(abs(z) >= 1.96, "YES", "no")))
  }
}

# breakdown theta — maior theta com p<0.05 (para travel)
breakdown_theta <- list()
for (yn in c("travel_burden_km", "icsap_per1k")) {
  bd <- NA
  for (theta in theta_grid) {
    k <- sprintf("%.02f__%s", theta, yn)
    if (!is.null(results[[k]]) && results[[k]]$significant_05) {
      bd <- theta
    }
  }
  breakdown_theta[[yn]] <- bd
  cat(sprintf("breakdown theta (last sig at p<0.05) for %s: %s\n", yn,
              ifelse(is.na(bd), "NEVER SIG", as.character(bd))))
}

out <- list(
  theta_grid = theta_grid,
  results = results,
  breakdown_theta = breakdown_theta
)
write(toJSON(out, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "44_theta_sweep.json"))

# Plot
df <- rbindlist(lapply(results, function(x) {
  data.table(theta = x$theta, outcome = x$outcome,
             att = x$att, se = x$se, n_treated = x$n_treated)
}))
df[, lo := att - 1.96 * se]
df[, hi := att + 1.96 * se]
df[, outcome := factor(outcome,
                        levels = c("travel_burden_km", "icsap_per1k"),
                        labels = c("Travel burden (km)", "ICSAP per 1,000"))]

p <- ggplot(df, aes(x = theta, y = att)) +
  geom_hline(yintercept = 0, color = "gray50", linetype = "dashed") +
  geom_vline(xintercept = 0.05, color = "red", linetype = "dotted",
             linewidth = 0.4) +
  geom_pointrange(aes(ymin = lo, ymax = hi), color = "#1f77b4",
                  size = 0.3, linewidth = 0.5) +
  geom_line(color = "#1f77b4", alpha = 0.5) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 1) +
  labs(x = expression(paste("Threshold ", theta)),
       y = "ATT (Sun-Abraham, simple)",
       title = expression(paste("ATT sensitivity to ", theta,
                                 " (E1 exposure threshold)"))) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(FIG_DIR, "fig_theta_sweep.pdf"), p,
       width = 7, height = 6, device = "pdf")
cat("wrote fig_theta_sweep.pdf and 44_theta_sweep.json\n")
