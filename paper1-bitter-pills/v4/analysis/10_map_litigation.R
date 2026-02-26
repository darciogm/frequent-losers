# =============================================================================
# 10_map_litigation.R — Choropleth: health litigation per 1,000 inhabitants (SP)
# Bitter Pills to Swallow — v4 (R)
# Output: v4/pub/figures/fig_00_litigation_map.pdf (6.5x5in, cairo PDF)
# =============================================================================

cat("=== 10_map_litigation.R ===\n")
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
library(sidrar)

# --- Output directory ---------------------------------------------------------
PUB_FIG <- file.path(V4, "pub", "figures")
dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

# --- 1. Shapefile (IBGE via geobr) -------------------------------------------
cat("\n--- Downloading SP municipality shapefile (geobr) ---\n")
sp_mun <- geobr::read_municipality(code_muni = "SP", year = 2010)
cat(sprintf("  Shapefile: %d municipalities\n", nrow(sp_mun)))

# --- 2. Population from IBGE/SIDRA (table 6579) ------------------------------
cat("\n--- Downloading population data (SIDRA table 6579) ---\n")
pop_raw <- sidrar::get_sidra(
  x     = 6579,
  variable = 9324,
  period = "2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019",
  geo    = "City",
  geo.filter = list("State" = 35)
)
cat(sprintf("  Population rows: %d\n", nrow(pop_raw)))

# Compute mean population per municipality (2009-2019)
pop <- data.frame(
  code_muni = as.integer(substr(pop_raw[["Município (Código)"]], 1, 7)),
  pop       = as.numeric(pop_raw[["Valor"]])
)
pop <- aggregate(pop ~ code_muni, data = pop, FUN = mean, na.rm = TRUE)
names(pop)[2] <- "pop_mean"
cat(sprintf("  Unique municipalities with pop data: %d\n", nrow(pop)))

# --- 3. Litigation data -------------------------------------------------------
cat("\n--- Loading litigation data ---\n")
lit_path <- file.path(BASE, "..", "supporting", "exploratory",
                      "Mapa_SP_Casos_jud_INSPER.dta")
lit <- haven::read_dta(lit_path)
cat(sprintf("  Litigation rows: %d\n", nrow(lit)))
cat(sprintf("  Variables: %s\n", paste(names(lit), collapse = ", ")))

# Ensure CD_GEOCMU is integer (7-digit IBGE code)
lit$code_muni <- as.integer(lit$CD_GEOCMU)

# --- 4. Merge and compute rate ------------------------------------------------
cat("\n--- Merging data ---\n")
# Merge litigation + population
merged <- merge(lit, pop, by = "code_muni", all.x = TRUE)
merged$cases_per_1k <- merged$jud_total / merged$pop_mean * 1000
cat(sprintf("  Merged rows: %d\n", nrow(merged)))
cat(sprintf("  Missing pop_mean: %d\n", sum(is.na(merged$pop_mean))))
cat(sprintf("  cases_per_1k summary:\n"))
print(summary(merged$cases_per_1k))

# Merge with shapefile
sp_merged <- merge(sp_mun, merged[, c("code_muni", "jud_total", "pop_mean",
                                       "cases_per_1k")],
                   by = "code_muni", all.x = TRUE)
cat(sprintf("  Shapefile rows after merge: %d\n", nrow(sp_merged)))

# --- 5. Choropleth map --------------------------------------------------------
cat("\n--- Generating choropleth map ---\n")

p <- ggplot(sp_merged) +
  geom_sf(aes(fill = cases_per_1k), color = "gray70", linewidth = 0.1) +
  scale_fill_gradient(
    low  = "white",
    high = "gray20",
    name = "Cases per\n1,000 inhab.",
    na.value = "gray95"
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
out_path <- file.path(PUB_FIG, "fig_00_litigation_map.pdf")
ggsave(out_path, p, width = 6.5, height = 5, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out_path))

# --- Summary ------------------------------------------------------------------
cat(sprintf("\n=== 10_map_litigation.R complete ===\n"))
cat(sprintf("  Municipalities in shapefile: %d\n", nrow(sp_mun)))
cat(sprintf("  Municipalities with litigation data: %d\n",
            sum(!is.na(sp_merged$cases_per_1k))))
cat(sprintf("  Output: %s\n", out_path))
