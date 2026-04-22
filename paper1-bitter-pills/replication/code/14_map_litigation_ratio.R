# Choropleth: litigation cases / total purchases (SP)
# Output: v4/pub/figures/fig_00e_litigation_ratio_map.pdf (6.5x5in, cairo PDF)

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
library(arrow)

# Output directory
# PUB_FIG defined in utils.R
# dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

# 1. Shapefile (IBGE via geobr)
cat("\n--- Downloading SP municipality shapefile (geobr) ---\n")
sp_mun <- geobr::read_municipality(code_muni = "SP", year = 2010)
cat(sprintf("  Shapefile: %d municipalities\n", nrow(sp_mun)))

# 2. Litigation data
cat("\n--- Loading litigation data ---\n")
lit_path <- file.path(BASE, "..", "supporting", "exploratory",
                      "Mapa_SP_Casos_jud_INSPER.dta")
lit <- haven::read_dta(lit_path)
lit$code_muni <- as.integer(lit$CD_GEOCMU)
cat(sprintf("  Litigation rows: %d\n", nrow(lit)))

# 3. Total purchases per municipality from BEC data
cat("\n--- Computing total purchases per municipality ---\n")
dt <- as.data.table(arrow::read_parquet(
  DATA_RAW, col_select = c("pbu_ibge_cod_cidade", "purchase_type")
))
purch <- dt[, .(total_purchases = .N), by = .(code_muni = as.integer(pbu_ibge_cod_cidade))]
cat(sprintf("  Municipalities with purchases: %d\n", nrow(purch)))

# 4. Merge and compute ratio
cat("\n--- Merging data ---\n")
merged <- merge(lit[, c("code_muni", "jud_total")], purch, by = "code_muni", all = TRUE)
merged$ratio <- merged$jud_total / merged$total_purchases

cat(sprintf("  Municipalities with both lit + purchases: %d\n",
            sum(!is.na(merged$ratio))))
cat("  Ratio summary (cases / purchases):\n")
print(summary(merged$ratio[!is.na(merged$ratio)]))

# Merge with shapefile
sp_merged <- merge(sp_mun, merged[, c("code_muni", "ratio")],
                   by = "code_muni", all.x = TRUE)

# 5. Choropleth map
cat("\n--- Generating choropleth map (litigation / purchases ratio) ---\n")

p <- ggplot(sp_merged) +
  geom_sf(aes(fill = ratio), color = "gray70", linewidth = 0.1) +
  scale_fill_gradient(
    low  = "white",
    high = "gray20",
    name = "Cases /\nPurchases",
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
out_path <- file.path(PUB_FIG, "fig_00e_litigation_ratio_map.pdf")
ggsave(out_path, p, width = 6.5, height = 5, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out_path))

