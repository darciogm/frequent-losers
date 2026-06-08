#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2); library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
FIG_DIR <- file.path(ROOT, "04_figures")
TAB_DIR <- file.path(ROOT, "01_manuscript", "tables")

log_json <- file.path(LOG_DIR, "47_spillover_donut_conley.json")
blocked_md <- file.path(LOG_DIR, "blocked_47.md")
set.seed(42)

cat("==== begin spillover / donut / Conley ====\n")

haversine_km <- function(lat1, lon1, lat2, lon2) {
  r <- 6371
  to_rad <- pi / 180
  dlat <- (lat2 - lat1) * to_rad
  dlon <- (lon2 - lon1) * to_rad
  a <- sin(dlat / 2)^2 + cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  2 * r * asin(pmin(1, sqrt(a)))
}

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
cent <- as.data.table(read_parquet(file.path(INTER, "municipios_centroids.parquet")))[, .(codmun_6 = cod_mun_6, lat, lon)]
panel <- merge(panel, cent, by = "codmun_6", all.x = TRUE)

treated_munis <- unique(panel[g_emb > 0, .(codmun_6, lat, lon)])
all_munis <- unique(panel[, .(codmun_6, muni_id, lat, lon, g_emb)])

dist_to_treated <- sapply(seq_len(nrow(all_munis)), function(i) {
  if (all_munis$g_emb[i] > 0) return(0)
  min(haversine_km(all_munis$lat[i], all_munis$lon[i], treated_munis$lat, treated_munis$lon))
})
all_munis[, dist_to_nearest_treated_km := dist_to_treated]
panel <- merge(panel, all_munis[, .(codmun_6, dist_to_nearest_treated_km)], by = "codmun_6", all.x = TRUE)

run_sa <- function(d, yname, add_near = FALSE) {
  d <- d[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  if (add_near) {
    fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) + i(year, near_control) | muni_id + year", yname))
  } else {
    fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  }
  feols(fml, data = d, cluster = ~muni_id)
}

extract_att <- function(m, cutoff) {
  agg_cl <- summary(m, agg = "att")
  att <- as.numeric(coef(agg_cl)[1])
  se_cluster <- as.numeric(se(agg_cl)[1])
  se_conley <- tryCatch({
    agg_conley <- summary(m, agg = "att", vcov = vcov_conley(lat = "lat", lon = "lon", cutoff = cutoff))
    as.numeric(se(agg_conley)[1])
  }, error = function(e) NA_real_)
  list(att = att, se_cluster = se_cluster, se_conley = se_conley)
}

radii <- c(50, 100, 200)
outcomes <- c("travel_burden_km", "icsap_per1k")
rows <- list()

for (r in radii) {
  cat(sprintf("\n--- radius %dkm ---\n", r))
  d_donut <- panel[g_emb > 0 | dist_to_nearest_treated_km > r]
  d_near <- copy(panel)
  d_near[, near_control := as.integer(g_emb == 0 & dist_to_nearest_treated_km <= r)]
  for (y in outcomes) {
    m_donut <- run_sa(d_donut, y, add_near = FALSE)
    a_donut <- extract_att(m_donut, r)
    m_near <- run_sa(d_near, y, add_near = TRUE)
    a_near <- extract_att(m_near, r)
    rows[[length(rows) + 1]] <- data.table(
      radius_km = r,
      outcome = y,
      n_treated = d_donut[g_emb > 0, uniqueN(muni_id)],
      n_controls_kept = d_donut[g_emb == 0, uniqueN(muni_id)],
      donut_att = a_donut$att,
      donut_se_cluster = a_donut$se_cluster,
      donut_se_conley = a_donut$se_conley,
      near_group_att = a_near$att,
      near_group_se_cluster = a_near$se_cluster,
      near_group_se_conley = a_near$se_conley
    )
    cat(sprintf("  %-18s donut=%+.3f (%.3f) conley=%.3f near=%+.3f (%.3f)\n",
                y, a_donut$att, a_donut$se_cluster, a_donut$se_conley, a_near$att, a_near$se_cluster))
  }
}

res <- rbindlist(rows)
write(toJSON(list(results = res), auto_unbox = TRUE, pretty = TRUE), log_json)

res_travel <- res[outcome == "travel_burden_km"]
res_travel[, donut_lo := donut_att - 1.96 * donut_se_cluster]
res_travel[, donut_hi := donut_att + 1.96 * donut_se_cluster]
res_travel[, near_lo := near_group_att - 1.96 * near_group_se_cluster]
res_travel[, near_hi := near_group_att + 1.96 * near_group_se_cluster]

fig <- ggplot(res_travel, aes(x = factor(radius_km), group = 1)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4, color = "gray60") +
  geom_point(aes(y = donut_att), size = 2.2, color = "#1b9e77") +
  geom_line(aes(y = donut_att), color = "#1b9e77") +
  geom_errorbar(aes(ymin = donut_lo, ymax = donut_hi), width = 0.1, color = "#1b9e77") +
  geom_point(aes(y = near_group_att), size = 2.2, color = "#d95f02") +
  geom_line(aes(y = near_group_att, group = 1), color = "#d95f02") +
  geom_errorbar(aes(ymin = near_lo, ymax = near_hi), width = 0.1, color = "#d95f02") +
  labs(x = "Donut / near-control radius (km)", y = "Travel ATT", title = "Spillover diagnostics for travel burden") +
  theme_minimal(base_size = 10)
ggsave(file.path(FIG_DIR, "fig_spillover_eventstudy.pdf"), fig, width = 7, height = 4.5)

tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Spillover diagnostics for the F5 main sample. Donut specifications keep all treated municipalities and exclude controls within the stated radius of any treated municipality. The near-control specification retains all municipalities but allows controls inside the radius to follow a separate year-specific path. Conley standard errors use centroid coordinates and the same radius as the donut cutoff.}",
  "\\label{tab:donut-spillover}",
  "\\small",
  "\\begin{tabular}{llrrrrrr}",
  "\\toprule",
  "Radius & Outcome & Donut ATT & Cluster SE & Conley SE & Near-group ATT & Cluster SE & Conley SE \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(res))) {
  rr <- res[i]
  ylab <- ifelse(rr$outcome == "travel_burden_km", "Travel (km)", "ICSAP per 1k")
  tab <- c(tab, sprintf("%d km & %s & $%+.3f$ & %.3f & %.3f & $%+.3f$ & %.3f & %.3f \\\\",
                        rr$radius_km, ylab, rr$donut_att, rr$donut_se_cluster, rr$donut_se_conley,
                        rr$near_group_att, rr$near_group_se_cluster, rr$near_group_se_conley))
}
tab <- c(tab, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_donut_spillover.tex"))

writeLines(
  c(
    "# Blocked step 47",
    "",
    "This script used `fixest::vcov_conley` for centroid-based Conley standard errors.",
    "No road-network spillover geometry was available, so all radii are centroid-to-centroid haversine distances."
  ),
  blocked_md
)

cat("done\n")
