# =============================================================================
# 13_map_litigation_total.R — Choropleth: total litigation cases by municipality (SP)
# Bitter Pills to Swallow — v4 (R)
# Output: v4/pub/figures/fig_00d_litigation_total_map.pdf (6.5x5in, cairo PDF)
# =============================================================================

cat("=== 13_map_litigation_total.R ===\n")
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

library(haven)
library(sf)
library(geobr)

# --- Output directory ---------------------------------------------------------
PUB_FIG <- file.path(V4, "pub", "figures")
dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

# --- 1. Shapefile (IBGE via geobr) -------------------------------------------
cat("\n--- Downloading SP municipality shapefile (geobr) ---\n")
sp_mun <- geobr::read_municipality(code_muni = "SP", year = 2010)
cat(sprintf("  Shapefile: %d municipalities\n", nrow(sp_mun)))

# --- 2. Litigation data -------------------------------------------------------
cat("\n--- Loading litigation data ---\n")
lit_path <- file.path(BASE, "..", "supporting", "exploratory",
                      "Mapa_SP_Casos_jud_INSPER.dta")
lit <- haven::read_dta(lit_path)
lit$code_muni <- as.integer(lit$CD_GEOCMU)
cat(sprintf("  Litigation rows: %d\n", nrow(lit)))
cat(sprintf("  jud_total summary:\n"))
print(summary(lit$jud_total))

# --- 3. Merge with shapefile --------------------------------------------------
sp_merged <- merge(sp_mun, lit[, c("code_muni", "jud_total")],
                   by = "code_muni", all.x = TRUE)
cat(sprintf("  Municipalities with litigation data: %d\n",
            sum(!is.na(sp_merged$jud_total))))

# --- 4. Choropleth map --------------------------------------------------------
cat("\n--- Generating choropleth map (total cases) ---\n")

p <- ggplot(sp_merged) +
  geom_sf(aes(fill = jud_total), color = "gray70", linewidth = 0.1) +
  scale_fill_gradient(
    low  = "white",
    high = "gray20",
    name = "Total cases\n(2009\u20132019)",
    na.value = "gray95",
    labels = scales::comma
  ) +
  theme_void(base_size = 9) +
  theme(
    legend.position    = c(0.15, 0.25),
    legend.title       = element_text(size = 8),
    legend.text        = element_text(size = 7),
    legend.key.height  = unit(0.8, "cm"),
    legend.key.width   = unit(0.4, "cm"),
    plot.title         = element_blank()
  )

# Save (6.5 x 5 in, cairo PDF)
out_path <- file.path(PUB_FIG, "fig_00d_litigation_total_map.pdf")
ggsave(out_path, p, width = 6.5, height = 5, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out_path))

cat("=== 13_map_litigation_total.R complete ===\n")
