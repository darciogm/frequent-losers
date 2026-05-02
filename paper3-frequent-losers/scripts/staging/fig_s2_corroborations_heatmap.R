# 3x3 corroborations heatmap: which reading of β is consistent with which
# independent piece of evidence. Pure logical-visual schema.
# Output: staging_figures/fig_s2_corroborations_heatmap.pdf

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tibble)
})

readings <- c("Treatment-effect", "Pure-confound", "Screening-value")

corroborations <- c(
  "Cartel-adjacency validation\n(AUC 0.748 / 0.864 vs random)",
  "Continuous dose-response\n(DeLong p < 10⁻³)",
  "Sensitivity bounds\n(RV = 17.5%, δ̂ = 261.6)"
)

# 3x3 consistency matrix.
# Rows = corroborations, Columns = readings of β.
# Code: 2 = consistent, 0 = silent, -1 = inconsistent.
consistency <- tribble(
  ~corroboration,    ~reading,            ~code, ~symbol, ~status,
  corroborations[1], readings[1],         -1,    "✗", "Inconsistent",
  corroborations[1], readings[2],          0,    "—", "Silent",
  corroborations[1], readings[3],          2,    "✓", "Consistent",
  corroborations[2], readings[1],          0,    "—", "Silent",
  corroborations[2], readings[2],         -1,    "✗", "Inconsistent",
  corroborations[2], readings[3],          2,    "✓", "Consistent",
  corroborations[3], readings[1],          1,    "±", "Partial",
  corroborations[3], readings[2],          1,    "±", "Partial",
  corroborations[3], readings[3],          2,    "✓", "Consistent"
) |>
  mutate(
    corroboration = factor(corroboration, levels = rev(corroborations)),
    reading       = factor(reading, levels = readings)
  )

cols <- c(
  "Inconsistent" = "#c44e52",
  "Silent"       = "#bdbdbd",
  "Partial"      = "#dfc27d",
  "Consistent"   = "#3a7a4f"
)

p <- ggplot(consistency, aes(reading, corroboration, fill = status)) +
  geom_tile(color = "white", linewidth = 1.5) +
  geom_text(aes(label = symbol), color = "white",
            size = 9, family = "sans", fontface = "bold") +
  scale_fill_manual(values = cols, name = NULL,
                    breaks = c("Consistent", "Partial", "Silent", "Inconsistent")) +
  scale_x_discrete(position = "top",
                   labels = function(x) gsub(" ", "\n", x)) +
  labs(
    title = "Three independent corroborations privilege the screening-value reading of β",
    subtitle = "The middle column (pure-confound) and the left (treatment-effect) each fail at least one test;\nonly the right column carries three consistencies.",
    x = NULL, y = NULL,
    caption = "Cells encode: ✓ consistent, ± partial, — silent, ✗ inconsistent. See §7.2."
  ) +
  theme_minimal(base_size = 11, base_family = "sans") +
  theme(
    plot.title    = element_text(face = "bold", size = 13, color = "#1a3a5c"),
    plot.subtitle = element_text(size = 10, color = "grey30", margin = margin(b = 14)),
    plot.caption  = element_text(size = 8.5, color = "grey45"),
    axis.text.x   = element_text(face = "bold", size = 11, color = "#1a3a5c", lineheight = 0.9),
    axis.text.y   = element_text(size = 9.5, color = "grey20", lineheight = 1.1, hjust = 1),
    panel.grid    = element_blank(),
    legend.position = "bottom",
    legend.text   = element_text(size = 9),
    legend.key.size = unit(0.5, "cm"),
    plot.margin   = margin(14, 18, 12, 14)
  )

out <- "work/v15-editor/staging_figures/fig_s2_corroborations_heatmap.pdf"
ggsave(out, p, width = 8.4, height = 4.8, device = cairo_pdf)
cat(sprintf("wrote %s\n", out))
