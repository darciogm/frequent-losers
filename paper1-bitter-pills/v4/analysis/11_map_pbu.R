# Point map: Public Buyer Units (PBUs) in São Paulo state
# Output: v4/pub/figures/fig_00b_pbu_map.pdf (6.5x5in, cairo PDF)

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

# Output directory
PUB_FIG <- file.path(V4, "pub", "figures")
dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

# 1. Shapefile (IBGE via geobr)
cat("\n--- Downloading SP municipality shapefile (geobr) ---\n")
sp_mun <- geobr::read_municipality(code_muni = "SP", year = 2010)
cat(sprintf("  Shapefile: %d municipalities\n", nrow(sp_mun)))

# 2. PBU location data
cat("\n--- Loading PBU location data ---\n")
pbu_path <- file.path(BASE, "..", "data", "geocoding", "shapefiles",
                      "sp_municipios", "pbu_location.dta")
pbu <- haven::read_dta(pbu_path)
cat(sprintf("  PBU rows: %d\n", nrow(pbu)))
cat(sprintf("  Unique cities: %d\n", length(unique(pbu$pbu_city_descr))))

# Convert to sf point geometry (WGS84)
pbu_sf <- st_as_sf(pbu, coords = c("pbu_longit", "pbu_latit"), crs = 4326)
cat(sprintf("  PBU points created: %d\n", nrow(pbu_sf)))

# 3. Point map (publication-ready)
cat("\n--- Generating PBU point map ---\n")

p <- ggplot() +
  geom_sf(data = sp_mun, fill = "gray95", color = "gray75", linewidth = 0.08) +
  geom_sf(data = pbu_sf, shape = 16, size = 1.8, color = "gray20") +
  theme_void(base_size = 9) +
  theme(plot.title = element_blank())

# Save (6.5 x 5 in, cairo PDF). Manuscript references this as
# fig_00b_litigation_pbu_map.pdf (paired with fig_00b_admin_pbu_map.pdf from
# 15_admin_figures.R). Keep the legacy fig_00b_pbu_map.pdf alias too, since
# older drafts and v4 internal references still use the short name.
out_path  <- file.path(PUB_FIG, "fig_00b_litigation_pbu_map.pdf")
out_alias <- file.path(PUB_FIG, "fig_00b_pbu_map.pdf")
ggsave(out_path,  p, width = 6.5, height = 5, device = cairo_pdf)
ggsave(out_alias, p, width = 6.5, height = 5, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out_path))
cat(sprintf("  Saved: %s\n", out_alias))

# Summary
cat(sprintf("\n11_map_pbu.R complete\n"))
cat(sprintf("  Municipalities in shapefile: %d\n", nrow(sp_mun)))
cat(sprintf("  PBU points plotted: %d\n", nrow(pbu_sf)))
cat(sprintf("  Output: %s\n", out_path))
