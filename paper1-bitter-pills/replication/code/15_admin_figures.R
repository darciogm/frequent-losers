# 5 figures for administrative demand cases
# Analogs of fig_00/00b/00c/00d/00e for administrative (purchase_type == 1)
# Output: v4/pub/figures/fig_00{_,b_,c_,d_,e_}admin_*.pdf

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
library(arrow)

# Output directory
# PUB_FIG defined in utils.R
# dir.create(PUB_FIG, recursive = TRUE, showWarnings = FALSE)

FIG_W <- 6.5
FIG_H <- 5

# Shared data loading
cat("\n--- Downloading SP municipality shapefile (geobr) ---\n")
sp_mun <- geobr::read_municipality(code_muni = "SP", year = 2010)
cat(sprintf("  Shapefile: %d municipalities\n", nrow(sp_mun)))

cat("\n--- Downloading population data (SIDRA table 6579) ---\n")
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

cat("\n--- Loading BEC procurement data ---\n")
dt <- as.data.table(arrow::read_parquet(
  DATA_RAW,
  col_select = c("pbu_ibge_cod_cidade", "pbu_code", "pbu_latit", "pbu_longit",
                  "pbu_descr", "purchase_type")
))

# Admin purchases per municipality
adm_mun <- dt[purchase_type == 1,
              .(n_admin = .N),
              by = .(code_muni = as.integer(pbu_ibge_cod_cidade))]
cat(sprintf("  Admin purchases: %d in %d municipalities\n",
            sum(adm_mun$n_admin), nrow(adm_mun)))

# Total purchases per municipality
all_mun <- dt[, .(total_purchases = .N),
              by = .(code_muni = as.integer(pbu_ibge_cod_cidade))]

# Admin purchases per PBU (for point map)
adm_pbu <- dt[purchase_type == 1,
              .(n_admin = .N),
              by = .(pbu_code, pbu_latit, pbu_longit, pbu_descr)]
adm_pbu <- adm_pbu[!is.na(pbu_latit) & !is.na(pbu_longit)]
cat(sprintf("  Admin PBUs with coordinates: %d / %d\n",
            nrow(adm_pbu), uniqueN(dt[purchase_type == 1]$pbu_code)))

# Figure 1: Admin per 1,000 inhabitants (analog of fig_00_litigation_map)
cat("\n--- Figure 1: Admin per 1,000 inhabitants ---\n")

merged1 <- merge(adm_mun, pop, by = "code_muni", all.x = TRUE)
merged1$admin_per_1k <- merged1$n_admin / merged1$pop_mean * 1000
sp_map1 <- merge(sp_mun, merged1[, c("code_muni", "admin_per_1k")],
                 by = "code_muni", all.x = TRUE)

p1 <- ggplot(sp_map1) +
  geom_sf(aes(fill = admin_per_1k), color = "gray70", linewidth = 0.1) +
  scale_fill_gradient(
    low  = "white",
    high = "gray20",
    name = "Admin. per\n1,000 inhab.",
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

out1 <- file.path(PUB_FIG, "fig_00_admin_map.pdf")
ggsave(out1, p1, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out1))

# Figure 2: PBU point map with admin volume (analog of fig_00b_pbu_map)
cat("\n--- Figure 2: Admin PBU point map ---\n")

adm_pbu_sf <- st_as_sf(adm_pbu, coords = c("pbu_longit", "pbu_latit"), crs = 4326)

p2 <- ggplot() +
  geom_sf(data = sp_mun, fill = "gray95", color = "gray75", linewidth = 0.08) +
  geom_sf(data = adm_pbu_sf, aes(size = n_admin), shape = 16, color = "gray20") +
  scale_size_continuous(
    name   = "Admin.\npurchases",
    range  = c(1, 6),
    breaks = scales::pretty_breaks(4)
  ) +
  theme_void(base_size = 9) +
  theme(
    legend.position    = c(0.15, 0.25),
    legend.title       = element_text(size = 8),
    legend.text        = element_text(size = 7),
    plot.title         = element_blank()
  )

out2 <- file.path(PUB_FIG, "fig_00b_admin_pbu_map.pdf")
ggsave(out2, p2, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out2))

# Figure 3: Admin vs Litigated comparison table (analog of fig_00c_purchase_types)
cat("\n--- Figure 3: Admin vs Litigated comparison table ---\n")

tbl <- data.frame(
  feature = rep(c("Origin", "Source of funds", "Quantity",
                   "Delivery time", "Threat of punishment"), each = 2),
  type    = rep(c("Administrative", "Litigated"), times = 5),
  value   = c(
    "SES/SP request",       "Court order",
    "Diverted budget",      "Diverted budget",
    "Small",                "Small",
    "Short",                "Short",
    "None",                 "Potential punishment"
  ),
  stringsAsFactors = FALSE
)

# Column layout
ROW_W <- 1.8
COL_W <- 1.5
row_x <- ROW_W / 2
col_x <- ROW_W + COL_W * (0.5 + 0:1)
type_x <- setNames(col_x, c("Administrative", "Litigated"))

tbl$x <- type_x[tbl$type]
tbl$y <- match(tbl$feature, rev(c("Origin", "Source of funds", "Quantity",
                                    "Delivery time", "Threat of punishment")))

tbl$fill <- ifelse(tbl$value %in% c("Court order", "Potential punishment"),
                   "diff", "shared")

header <- data.frame(
  x     = col_x,
  y     = max(tbl$y) + 1,
  label = c("Administrative", "Litigated"),
  stringsAsFactors = FALSE
)

row_labels <- data.frame(
  x     = row_x,
  y     = sort(unique(tbl$y)),
  label = rev(c("Origin", "Source of funds", "Quantity",
                 "Delivery time", "Threat of punishment")),
  stringsAsFactors = FALSE
)

fill_vals <- c("shared" = "gray92", "diff" = "gray75")

p3 <- ggplot() +
  geom_tile(data = tbl,
            aes(x = x, y = y, fill = fill),
            width = COL_W, color = "gray70", linewidth = 0.3) +
  geom_text(data = tbl,
            aes(x = x, y = y, label = value),
            size = 2.8, color = "black") +
  geom_tile(data = header,
            aes(x = x, y = y),
            width = COL_W, fill = "gray85", color = "gray70", linewidth = 0.3) +
  geom_text(data = header,
            aes(x = x, y = y, label = label),
            size = 3, fontface = "bold", color = "black") +
  geom_tile(data = row_labels,
            aes(x = x, y = y),
            width = ROW_W, fill = "white", color = "gray70", linewidth = 0.3) +
  geom_text(data = row_labels,
            aes(x = x, y = y, label = label),
            size = 2.8, fontface = "bold", color = "black") +
  geom_tile(data = data.frame(x = row_x, y = max(tbl$y) + 1),
            aes(x = x, y = y),
            width = ROW_W, fill = "gray85", color = "gray70", linewidth = 0.3) +
  scale_fill_manual(values = fill_vals, guide = "none") +
  scale_x_continuous(expand = expansion(mult = 0.01)) +
  scale_y_continuous(expand = expansion(mult = 0.05)) +
  coord_cartesian(clip = "off") +
  theme_void(base_size = 9) +
  theme(plot.margin = margin(5, 10, 5, 10))

out3 <- file.path(PUB_FIG, "fig_00c_admin_types.pdf")
ggsave(out3, p3, width = FIG_W, height = 2.5, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out3))

# Figure 4: Total admin purchases per municipality (analog of fig_00d)
cat("\n--- Figure 4: Total admin purchases ---\n")

sp_map4 <- merge(sp_mun, adm_mun[, c("code_muni", "n_admin")],
                 by = "code_muni", all.x = TRUE)

p4 <- ggplot(sp_map4) +
  geom_sf(aes(fill = n_admin), color = "gray70", linewidth = 0.1) +
  scale_fill_gradient(
    low  = "white",
    high = "gray20",
    name = "Total admin.\npurchases\n(2009\u20132019)",
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

out4 <- file.path(PUB_FIG, "fig_00d_admin_total_map.pdf")
ggsave(out4, p4, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out4))

# Figure 5: Admin / total purchases ratio (analog of fig_00e)
cat("\n--- Figure 5: Admin / total purchases ratio ---\n")

merged5 <- merge(adm_mun, all_mun, by = "code_muni", all.x = TRUE)
merged5$ratio <- merged5$n_admin / merged5$total_purchases
sp_map5 <- merge(sp_mun, merged5[, c("code_muni", "ratio")],
                 by = "code_muni", all.x = TRUE)

p5 <- ggplot(sp_map5) +
  geom_sf(aes(fill = ratio), color = "gray70", linewidth = 0.1) +
  scale_fill_gradient(
    low  = "white",
    high = "gray20",
    name = "Admin. /\nTotal purch.",
    na.value = "gray95",
    labels = scales::percent_format(accuracy = 1)
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

out5 <- file.path(PUB_FIG, "fig_00e_admin_ratio_map.pdf")
ggsave(out5, p5, width = FIG_W, height = FIG_H, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", out5))

# SUMMARY
cat("\n15_admin_figures.R complete\n")
cat(sprintf("  5 figures saved to %s\n", PUB_FIG))
