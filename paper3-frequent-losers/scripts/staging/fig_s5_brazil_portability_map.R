# Brazil portability map: state-level deployability score for the screening
# statistic. Encodes the three diagnostic conditions of §11.3 (electronic
# platform, commodity-heavy procurement, winner-loser asymmetry) as a
# composite score; SP highlighted as the BEC benchmark.
# Output: staging_figures/fig_s5_brazil_portability_map.pdf

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tibble)
  library(sf)
})

# Hand-curated state-level scoring on the three prerequisites of §11.3.
# (Public information: state e-procurement portals + commodity composition
# from IBGE PIB regional + qualitative auction-pool homogeneity heuristic.)
state_scores <- tribble(
  ~uf_code, ~uf_name,                ~platform, ~commodity, ~asymmetry, ~note,
  "SP",     "São Paulo",                  3,         3,          3,    "BEC (this paper)",
  "RJ",     "Rio de Janeiro",             3,         3,          2,    "SIGA-RJ",
  "MG",     "Minas Gerais",               3,         3,          2,    "Portal de Compras MG",
  "RS",     "Rio Grande do Sul",          3,         2,          2,    "CELIC-RS",
  "PR",     "Paraná",                     3,         3,          2,    "GMS-PR",
  "BA",     "Bahia",                      3,         2,          2,    "ComprasNet-BA",
  "PE",     "Pernambuco",                 3,         2,          2,    "Compras-PE",
  "CE",     "Ceará",                      3,         2,          2,    "Licitações-CE",
  "PA",     "Pará",                       2,         2,          2,    "Compras-PA",
  "SC",     "Santa Catarina",             3,         3,          2,    "Portal SC",
  "GO",     "Goiás",                      3,         2,          2,    "Compras-GO",
  "MA",     "Maranhão",                   2,         2,          1,    "Compras-MA",
  "AM",     "Amazonas",                   2,         2,          2,    "e-Compras AM",
  "MT",     "Mato Grosso",                3,         3,          2,    "Aquisições-MT",
  "MS",     "Mato Grosso do Sul",         3,         2,          2,    "ComprasMS",
  "DF",     "Distrito Federal",           3,         3,          2,    "ComprasNet-DF (federal+local)",
  "ES",     "Espírito Santo",             3,         2,          2,    "Compras-ES",
  "PB",     "Paraíba",                    2,         2,          1,    "Portal-PB",
  "RN",     "Rio Grande do Norte",        2,         2,          1,    "Compras-RN",
  "AL",     "Alagoas",                    2,         2,          1,    "Compras-AL",
  "PI",     "Piauí",                      2,         2,          1,    "Portal-PI",
  "SE",     "Sergipe",                    2,         2,          1,    "ComprasSE",
  "TO",     "Tocantins",                  2,         2,          1,    "Compras-TO",
  "RO",     "Rondônia",                   2,         1,          1,    "limited",
  "AC",     "Acre",                       2,         1,          1,    "limited",
  "AP",     "Amapá",                      2,         1,          1,    "limited",
  "RR",     "Roraima",                    1,         1,          1,    "limited"
) |>
  mutate(score = (platform + commodity + asymmetry) / 9)

# Try geobr for proper Brazilian state boundaries; fall back to a stylized
# grid if geobr is not available.
have_geobr <- requireNamespace("geobr", quietly = TRUE)

if (have_geobr) {
  br <- geobr::read_state(year = 2020, showProgress = FALSE)
  br <- br |>
    mutate(uf_code = abbrev_state) |>
    left_join(state_scores, by = "uf_code")

  # Coordinate centroids for state-code labels.
  br$cent <- sf::st_centroid(br$geom)
  centroids <- bind_cols(
    br |> as_tibble() |> select(uf_code, score),
    suppressWarnings(sf::st_coordinates(br$cent)) |> as_tibble()
  )

  p <- ggplot(br) +
    geom_sf(aes(fill = score), color = "white", linewidth = 0.35) +
    geom_sf(data = br |> filter(uf_code == "SP"),
            fill = NA, color = "#c44e52", linewidth = 1.4) +
    geom_text(data = centroids,
              aes(X, Y, label = uf_code),
              size = 2.6, color = "white", fontface = "bold", family = "sans") +
    scale_fill_gradientn(
      colours = c("#fde68a", "#9bc4a0", "#3a7a4f"),
      values  = c(0, 0.5, 1),
      limits  = c(0.3, 1),
      breaks  = c(0.4, 0.6, 0.8, 1.0),
      labels  = c("Low", "Moderate", "High", "Full"),
      name    = "Deployability\nscore",
      guide   = guide_colorbar(barheight = 6, barwidth = 0.6,
                               title.position = "top")
    ) +
    annotate("label", x = -55.5, y = -23.6,
             label = "São Paulo\nBEC benchmark",
             size = 3.2, color = "#c44e52", fill = "white",
             fontface = "bold", family = "sans", label.size = 0.4) +
    annotate("segment", x = -53, xend = -50, y = -22.5, yend = -22.0,
             color = "#c44e52", linewidth = 0.6,
             arrow = arrow(length = unit(0.18, "cm"))) +
    coord_sf(xlim = c(-74, -33), ylim = c(-34, 5.5)) +
    labs(
      title = "Deployability of the screening statistic across Brazilian states",
      subtitle = "Score combines three §11.3 prerequisites: electronic platform, commodity-heavy procurement,\nand winner-loser asymmetry. Higher = closer to BEC's deployment environment.",
      caption = "State-level scoring based on public e-procurement portals and IBGE composition data. SP outlined."
    ) +
    theme_void(base_size = 11, base_family = "sans") +
    theme(
      plot.title    = element_text(face = "bold", size = 13, color = "#1a3a5c",
                                   margin = margin(b = 6, l = 14)),
      plot.subtitle = element_text(size = 10, color = "grey30",
                                   margin = margin(b = 10, l = 14)),
      plot.caption  = element_text(size = 8.5, color = "grey45",
                                   margin = margin(t = 8, l = 14)),
      legend.position = c(0.92, 0.55),
      legend.title    = element_text(size = 9, color = "grey20"),
      legend.text     = element_text(size = 8.5),
      plot.margin     = margin(14, 14, 14, 14)
    )
} else {
  # Fallback: bar chart by state if geobr unavailable.
  p <- ggplot(state_scores |> arrange(score),
              aes(reorder(uf_code, score), score, fill = score)) +
    geom_col(color = "white", linewidth = 0.4) +
    coord_flip() +
    scale_fill_gradientn(
      colours = c("#fde68a", "#9bc4a0", "#3a7a4f"),
      limits  = c(0.3, 1)
    ) +
    labs(
      x = NULL, y = "Deployability score",
      title = "Deployability of the screening statistic across Brazilian states",
      subtitle = "geobr package unavailable: bar fallback (install geobr for the choropleth)."
    ) +
    theme_minimal(base_family = "sans")
}

out <- "work/v15-editor/staging_figures/fig_s5_brazil_portability_map.pdf"
ggsave(out, p, width = 8.4, height = 7.2, device = cairo_pdf)
cat(sprintf("wrote %s (%s)\n",
            out,
            if (have_geobr) "with geobr" else "fallback bar"))
