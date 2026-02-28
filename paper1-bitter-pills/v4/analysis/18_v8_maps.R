# =============================================================================
# 18_v8_maps.R — V8 Maps: Ordinary Demand + Enhanced Admin + Comparison Panel
# Bitter Pills to Swallow — v4 (R)
#
# Produces:
#   1. Ordinary demand maps (per capita, total, ratio) — NEW
#   2. Enhanced admin maps (SIRGAS 2000, quintile breaks, scale bar) — v8
#   3. Enhanced litigated maps (same) — v8
#   4. Comparison panel: litigated | admin | ordinary (same color scale) — NEW
#
# Output: v4/pub/figures/fig_map_*_v8.pdf
# =============================================================================

cat("=== 18_v8_maps.R — V8 Maps ===\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
t_start <- proc.time()

# --- Boilerplate: find script dir, source utils ---
.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "utils.R"))

library(sf)
library(geobr)
library(sidrar)
library(arrow)
library(patchwork)

# ggspatial for scale bar & north arrow
if (!requireNamespace("ggspatial", quietly = TRUE)) {
  install.packages("ggspatial", repos = "https://cloud.r-project.org", quiet = TRUE)
}
library(ggspatial)

# --- Hardware detection -------------------------------------------------------
n_cores <- parallel::detectCores(logical = TRUE)
setDTthreads(n_cores)
cat(sprintf("  Cores: %d | data.table threads: %d\n", n_cores, n_cores))

# --- Output directory ---------------------------------------------------------
PUB_FIG <- file.path(V4, "pub", "figures")
dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

FIG_W <- 7      # double-column width
FIG_H <- 5.5

# =============================================================================
# 1. LOAD SHARED DATA
# =============================================================================
cat("\n--- Loading shared data ---\n")
t0 <- proc.time()

# 1a. SP municipality shapefile (geobr → SIRGAS 2000 / UTM 23S)
cat("  Downloading SP municipality shapefile (geobr)...\n")
sp_mun <- geobr::read_municipality(code_muni = "SP", year = 2010)
sp_mun <- sf::st_transform(sp_mun, 31983)  # SIRGAS 2000 / UTM Zone 23S
cat(sprintf("  Shapefile: %d municipalities, CRS: EPSG:31983\n", nrow(sp_mun)))

# 1b. Population from IBGE/SIDRA (table 6579, 2009-2019 mean)
cat("  Downloading population data (SIDRA table 6579)...\n")
pop_raw <- sidrar::get_sidra(
  x     = 6579,
  variable = 9324,
  period = "2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019",
  geo    = "City",
  geo.filter = list("State" = 35)
)
pop <- data.frame(
  code_muni = as.integer(substr(pop_raw[["Município (Código)"]], 1, 7)),
  pop       = as.numeric(pop_raw[["Valor"]])
)
pop <- aggregate(pop ~ code_muni, data = pop, FUN = mean, na.rm = TRUE)
names(pop)[2] <- "pop_mean"
cat(sprintf("  Unique municipalities with pop data: %d\n", nrow(pop)))

# 1c. BEC procurement data — aggregate by municipality and purchase type
cat("  Loading BEC procurement data...\n")
dt <- as.data.table(arrow::read_parquet(
  DATA_RAW,
  col_select = c("pbu_ibge_cod_cidade", "purchase_type")
))

# Counts by municipality × type
mun_counts <- dt[, .(n = .N), by = .(code_muni = as.integer(pbu_ibge_cod_cidade),
                                      purchase_type)]
mun_total  <- dt[, .(total = .N), by = .(code_muni = as.integer(pbu_ibge_cod_cidade))]

# Separate by type
lit_mun <- mun_counts[purchase_type == 2, .(code_muni, n_litigated = n)]
adm_mun <- mun_counts[purchase_type == 1, .(code_muni, n_admin = n)]
ord_mun <- mun_counts[purchase_type == 0, .(code_muni, n_ordinary = n)]

cat(sprintf("  Litigated purchases: %s in %d municipalities\n",
            format(sum(lit_mun$n_litigated), big.mark = ","), nrow(lit_mun)))
cat(sprintf("  Administrative purchases: %s in %d municipalities\n",
            format(sum(adm_mun$n_admin), big.mark = ","), nrow(adm_mun)))
cat(sprintf("  Ordinary purchases: %s in %d municipalities\n",
            format(sum(ord_mun$n_ordinary), big.mark = ","), nrow(ord_mun)))

# Build combined municipality-level data
mun_data <- Reduce(function(a, b) merge(a, b, by = "code_muni", all = TRUE),
                   list(mun_total, lit_mun, adm_mun, ord_mun))
mun_data <- merge(mun_data, pop, by = "code_muni", all.x = TRUE)

# Per capita rates (per 1,000 inhabitants)
mun_data[, lit_per_1k := n_litigated / pop_mean * 1000]
mun_data[, adm_per_1k := n_admin / pop_mean * 1000]
mun_data[, ord_per_1k := n_ordinary / pop_mean * 1000]

# Ratios (share of total)
mun_data[, lit_ratio := n_litigated / total]
mun_data[, adm_ratio := n_admin / total]
mun_data[, ord_ratio := n_ordinary / total]

elapsed <- (proc.time() - t0)[["elapsed"]]
cat(sprintf("  Data loading: %.1f sec\n", elapsed))

# =============================================================================
# 2. MAP THEME AND HELPERS
# =============================================================================

# Quintile break function — returns a factor with 5 categories + NA
make_quintile_var <- function(x, lab_prefix = "") {
  vals <- x[!is.na(x) & x > 0]
  if (length(vals) < 10) return(factor(rep(NA, length(x))))
  brks <- unique(quantile(vals, probs = seq(0, 1, 0.2), na.rm = TRUE))
  if (length(brks) < 3) return(factor(rep(NA, length(x))))
  # Generate nice labels
  labs <- character(length(brks) - 1)
  for (i in seq_along(labs)) {
    lo <- brks[i]; hi <- brks[i + 1]
    if (max(vals, na.rm = TRUE) > 100) {
      labs[i] <- paste0(format(round(lo), big.mark = ","), "\u2013",
                        format(round(hi), big.mark = ","))
    } else {
      labs[i] <- paste0(sprintf("%.1f", lo), "\u2013", sprintf("%.1f", hi))
    }
  }
  cut(x, breaks = brks, labels = labs, include.lowest = TRUE, right = TRUE)
}

# 5-level grayscale palette (lightest to darkest)
pal_quintile <- c("gray90", "gray70", "gray50", "gray30", "gray10")

# Base choropleth function
plot_choropleth_v8 <- function(sf_data, fill_var, legend_title,
                               use_quintile = TRUE, label_fmt = NULL,
                               fig_width = FIG_W, fig_height = FIG_H) {
  if (use_quintile) {
    sf_data$fill_cat <- make_quintile_var(sf_data[[fill_var]])
    n_levels <- nlevels(sf_data$fill_cat)
    pal <- pal_quintile[seq_len(n_levels)]

    p <- ggplot(sf_data) +
      geom_sf(aes(fill = fill_cat), color = "gray70", linewidth = 0.1) +
      scale_fill_manual(
        values   = pal,
        name     = legend_title,
        na.value = "white",
        drop     = FALSE
      )
  } else {
    p <- ggplot(sf_data) +
      geom_sf(aes(fill = .data[[fill_var]]), color = "gray70", linewidth = 0.1) +
      scale_fill_gradient(
        low      = "white",
        high     = "gray20",
        name     = legend_title,
        na.value = "white",
        labels   = if (!is.null(label_fmt)) label_fmt else waiver()
      )
  }

  p <- p +
    annotation_scale(
      location = "br", width_hint = 0.2,
      line_width = 0.5, height = unit(0.15, "cm"),
      text_cex = 0.6, pad_x = unit(0.3, "cm"), pad_y = unit(0.3, "cm")
    ) +
    annotation_north_arrow(
      location = "tr", which_north = "true",
      height = unit(0.8, "cm"), width = unit(0.6, "cm"),
      pad_x = unit(0.3, "cm"), pad_y = unit(0.3, "cm"),
      style = north_arrow_minimal(text_size = 6)
    ) +
    theme_void(base_size = 11) +
    theme(
      legend.position    = c(0.15, 0.28),
      legend.title       = element_text(size = 9, face = "bold"),
      legend.text        = element_text(size = 8),
      legend.key.height  = unit(0.45, "cm"),
      legend.key.width   = unit(0.5, "cm"),
      plot.title         = element_blank(),
      plot.margin        = margin(2, 2, 2, 2)
    )

  p
}

# =============================================================================
# 3. ORDINARY DEMAND MAPS (NEW)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("ORDINARY DEMAND MAPS\n")
cat(strrep("=", 60), "\n")

sp_ord <- merge(sp_mun, mun_data[, .(code_muni, n_ordinary, ord_per_1k, ord_ratio)],
                by = "code_muni", all.x = TRUE)

# 3a. Ordinary per 1,000 inhabitants
cat("\n  Map 1: Ordinary per 1,000 inhabitants\n")
p_ord_pc <- plot_choropleth_v8(sp_ord, "ord_per_1k",
                                "Ordinary per\n1,000 inhab.")
out <- file.path(PUB_FIG, "fig_map_ordinary_per_capita_v8.pdf")
ggsave(out, p_ord_pc, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# 3b. Total ordinary purchases
cat("  Map 2: Total ordinary purchases\n")
p_ord_tot <- plot_choropleth_v8(sp_ord, "n_ordinary",
                                 "Total ordinary\npurchases")
out <- file.path(PUB_FIG, "fig_map_ordinary_total_v8.pdf")
ggsave(out, p_ord_tot, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# 3c. Ordinary / total ratio
cat("  Map 3: Ordinary / total purchases ratio\n")
p_ord_rat <- plot_choropleth_v8(sp_ord, "ord_ratio",
                                 "Ordinary /\nTotal purch.")
out <- file.path(PUB_FIG, "fig_map_ordinary_ratio_v8.pdf")
ggsave(out, p_ord_rat, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# =============================================================================
# 4. ENHANCED ADMIN DEMAND MAPS (v8 — SIRGAS + quintile breaks)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("ENHANCED ADMINISTRATIVE DEMAND MAPS (v8)\n")
cat(strrep("=", 60), "\n")

sp_adm <- merge(sp_mun, mun_data[, .(code_muni, n_admin, adm_per_1k, adm_ratio)],
                by = "code_muni", all.x = TRUE)

# 4a. Admin per 1,000 inhabitants
cat("\n  Map 4: Admin per 1,000 inhabitants\n")
p_adm_pc <- plot_choropleth_v8(sp_adm, "adm_per_1k",
                                "Admin. per\n1,000 inhab.")
out <- file.path(PUB_FIG, "fig_map_admin_per_capita_v8.pdf")
ggsave(out, p_adm_pc, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# 4b. Total admin purchases
cat("  Map 5: Total admin purchases\n")
p_adm_tot <- plot_choropleth_v8(sp_adm, "n_admin",
                                 "Total admin.\npurchases")
out <- file.path(PUB_FIG, "fig_map_admin_total_v8.pdf")
ggsave(out, p_adm_tot, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# 4c. Admin / total ratio
cat("  Map 6: Admin / total purchases ratio\n")
p_adm_rat <- plot_choropleth_v8(sp_adm, "adm_ratio",
                                 "Admin. /\nTotal purch.")
out <- file.path(PUB_FIG, "fig_map_admin_ratio_v8.pdf")
ggsave(out, p_adm_rat, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# =============================================================================
# 5. ENHANCED LITIGATED DEMAND MAPS (v8 — SIRGAS + quintile breaks)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("ENHANCED LITIGATED DEMAND MAPS (v8)\n")
cat(strrep("=", 60), "\n")

sp_lit <- merge(sp_mun, mun_data[, .(code_muni, n_litigated, lit_per_1k, lit_ratio)],
                by = "code_muni", all.x = TRUE)

# 5a. Litigated per 1,000 inhabitants
cat("\n  Map 7: Litigated per 1,000 inhabitants\n")
p_lit_pc <- plot_choropleth_v8(sp_lit, "lit_per_1k",
                                "Litigated per\n1,000 inhab.")
out <- file.path(PUB_FIG, "fig_map_litigated_per_capita_v8.pdf")
ggsave(out, p_lit_pc, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# 5b. Total litigated purchases
cat("  Map 8: Total litigated purchases\n")
p_lit_tot <- plot_choropleth_v8(sp_lit, "n_litigated",
                                 "Total litigated\npurchases")
out <- file.path(PUB_FIG, "fig_map_litigated_total_v8.pdf")
ggsave(out, p_lit_tot, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# 5c. Litigated / total ratio
cat("  Map 9: Litigated / total purchases ratio\n")
p_lit_rat <- plot_choropleth_v8(sp_lit, "lit_ratio",
                                 "Litigated /\nTotal purch.")
out <- file.path(PUB_FIG, "fig_map_litigated_ratio_v8.pdf")
ggsave(out, p_lit_rat, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("    Saved: %s\n", out))

# =============================================================================
# 6. COMPARISON PANEL: PER CAPITA (litigated | admin | ordinary)
# =============================================================================
cat("\n", strrep("=", 60), "\n")
cat("COMPARISON PANEL MAP\n")
cat(strrep("=", 60), "\n")

# Build combined data for common scale
all_pc <- c(mun_data$lit_per_1k, mun_data$adm_per_1k, mun_data$ord_per_1k)
all_pc <- all_pc[!is.na(all_pc) & all_pc > 0]
common_brks <- unique(quantile(all_pc, probs = seq(0, 1, 0.2), na.rm = TRUE))

# Generate common labels
common_labs <- character(length(common_brks) - 1)
for (i in seq_along(common_labs)) {
  common_labs[i] <- paste0(sprintf("%.1f", common_brks[i]), "\u2013",
                           sprintf("%.1f", common_brks[i + 1]))
}

# Apply common breaks to each type
sp_lit$pc_cat <- cut(sp_lit$lit_per_1k, breaks = common_brks,
                     labels = common_labs, include.lowest = TRUE)
sp_adm$pc_cat <- cut(sp_adm$adm_per_1k, breaks = common_brks,
                     labels = common_labs, include.lowest = TRUE)
sp_ord$pc_cat <- cut(sp_ord$ord_per_1k, breaks = common_brks,
                     labels = common_labs, include.lowest = TRUE)

n_lvl <- length(common_labs)
pal_common <- pal_quintile[seq_len(n_lvl)]

make_panel <- function(sf_data, panel_title) {
  ggplot(sf_data) +
    geom_sf(aes(fill = pc_cat), color = "gray70", linewidth = 0.05) +
    scale_fill_manual(
      values   = pal_common,
      name     = "Purchases per\n1,000 inhab.",
      na.value = "white",
      drop     = FALSE
    ) +
    labs(title = panel_title) +
    theme_void(base_size = 9) +
    theme(
      plot.title         = element_text(hjust = 0.5, size = 10, face = "bold"),
      legend.position    = "none",
      plot.margin        = margin(2, 2, 2, 2)
    )
}

p_panel_lit <- make_panel(sp_lit, "Litigated")
p_panel_adm <- make_panel(sp_adm, "Administrative")
p_panel_ord <- make_panel(sp_ord, "Ordinary")

# Extract legend from one panel
p_legend <- ggplot(sp_lit) +
  geom_sf(aes(fill = pc_cat), color = "gray70", linewidth = 0.05) +
  scale_fill_manual(values = pal_common, name = "Purchases per\n1,000 inhab.",
                    na.value = "white", drop = FALSE) +
  theme_void(base_size = 9) +
  theme(legend.position = "bottom",
        legend.title = element_text(size = 9, face = "bold"),
        legend.text = element_text(size = 8))

# Compose panel
p_comparison <- (p_panel_lit | p_panel_adm | p_panel_ord) +
  plot_layout(ncol = 3, guides = "collect") &
  theme(legend.position = "bottom",
        legend.title = element_text(size = 9, face = "bold"),
        legend.text = element_text(size = 8))

out <- file.path(PUB_FIG, "fig_map_panel_comparison_v8.pdf")
ggsave(out, p_comparison, width = 10, height = 4.5, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out))

# =============================================================================
# 7. SUMMARY
# =============================================================================
elapsed_total <- (proc.time() - t_start)[["elapsed"]]
cat("\n", strrep("=", 60), "\n")
cat("18_v8_maps.R COMPLETE\n")
cat(strrep("=", 60), "\n")
cat(sprintf("  Total time: %.1f sec\n", elapsed_total))
cat(sprintf("  Maps generated: 10\n"))
cat(sprintf("    Ordinary: 3 (per capita, total, ratio)\n"))
cat(sprintf("    Admin (enhanced): 3 (per capita, total, ratio)\n"))
cat(sprintf("    Litigated (enhanced): 3 (per capita, total, ratio)\n"))
cat(sprintf("    Comparison panel: 1 (3×1 per capita)\n"))
cat(sprintf("  Output: %s\n", PUB_FIG))
cat(sprintf("  CRS: EPSG:31983 (SIRGAS 2000 / UTM Zone 23S)\n"))
cat(sprintf("  Breaks: quintile (5 categories)\n"))
