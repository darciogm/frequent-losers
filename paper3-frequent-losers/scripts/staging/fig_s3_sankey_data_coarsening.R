# Sankey-style alluvial: what survives the coarsening from bid layer to award
# layer. Bid-distribution features collapse; award-record fields survive; AUC
# bars on right show the screening statistic's discriminating power matches.
# Output: staging_figures/fig_s3_sankey_data_coarsening.pdf

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tibble)
})

# Build a stylized 2-stage flow: bid-layer features -> "coarsening" gate ->
# award-layer fields. Width of each flow encodes informativeness (relative to
# the full Imhof pipeline AUC contribution).

flows <- tribble(
  ~feature,                          ~stage,         ~survives, ~weight,
  "Within-tender CV",                "Bid layer",    "lost",     5,
  "Within-tender skewness",          "Bid layer",    "lost",     4,
  "Within-tender kurtosis",          "Bid layer",    "lost",     4,
  "Bid spread",                      "Bid layer",    "lost",     5,
  "Second-low ratio",                "Bid layer",    "lost",     4,
  "Winner identity",                 "Award layer",  "survives", 6,
  "Participant identity",            "Award layer",  "survives", 8,
  "Item code",                       "Award layer",  "survives", 5,
  "Negotiated price",                "Award layer",  "survives", 6
) |>
  mutate(
    fill_color = case_when(
      survives == "lost"     ~ "#a0a0a0",
      survives == "survives" ~ "#2c5f8a"
    ),
    feature = factor(feature, levels = feature)
  )

# Manual rectangle plot rather than alluvial, simpler visual.
flows <- flows |> mutate(
  y_top    = cumsum(weight) - weight,
  y_bottom = cumsum(weight),
  x_start  = ifelse(stage == "Bid layer", 0, 6),
  x_end    = ifelse(stage == "Bid layer", 2, 8)
)

p <- ggplot() +
  # bid-layer block
  geom_rect(data = flows |> filter(stage == "Bid layer"),
            aes(xmin = x_start, xmax = x_end,
                ymin = -y_bottom, ymax = -y_top, fill = fill_color),
            color = "white", linewidth = 0.4) +
  # award-layer block
  geom_rect(data = flows |> filter(stage == "Award layer"),
            aes(xmin = x_start, xmax = x_end,
                ymin = -y_bottom, ymax = -y_top, fill = fill_color),
            color = "white", linewidth = 0.4) +
  # text labels
  geom_text(data = flows,
            aes(x = (x_start + x_end) / 2,
                y = -(y_top + y_bottom) / 2,
                label = feature),
            color = "white", size = 2.7, family = "sans", fontface = "bold") +
  # coarsening gate
  annotate("rect", xmin = 3, xmax = 5, ymin = -28, ymax = -16,
           fill = "#dfc27d", alpha = 0.75) +
  annotate("text", x = 4, y = -22,
           label = "Data\ncoarsening",
           color = "#5a4a1a", size = 4.5, fontface = "bold", family = "sans") +
  # arrows: lost
  annotate("segment", x = 2.05, xend = 2.95, y = -5, yend = -19,
           color = "#a0a0a0", linewidth = 0.6, linetype = "dashed",
           arrow = arrow(length = unit(0.16, "cm"))) +
  annotate("segment", x = 2.05, xend = 2.95, y = -22, yend = -22,
           color = "#a0a0a0", linewidth = 0.6, linetype = "dashed",
           arrow = arrow(length = unit(0.16, "cm"))) +
  # arrows: survives
  annotate("segment", x = 5.05, xend = 5.95, y = -22, yend = -22,
           color = "#2c5f8a", linewidth = 1.0,
           arrow = arrow(length = unit(0.18, "cm"))) +
  annotate("segment", x = 5.05, xend = 5.95, y = -22, yend = -38,
           color = "#2c5f8a", linewidth = 1.0,
           arrow = arrow(length = unit(0.18, "cm"))) +
  # AUC labels right side
  annotate("label", x = 9.6, y = -10,
           label = "Imhof full pipeline\nAUC = 0.888\n(needs full bid layer)",
           hjust = 0, size = 3.2, color = "#888", family = "sans",
           label.size = 0.3, fill = "#f5f5f5") +
  annotate("label", x = 9.6, y = -32,
           label = "Screening statistic\nAUC = 0.903\n(award layer only)",
           hjust = 0, size = 3.2, color = "#1a3a5c", family = "sans",
           fontface = "bold", label.size = 0.3, fill = "#eaf2f9") +
  scale_fill_identity() +
  scale_x_continuous(limits = c(-1.2, 14), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0.05, 0)) +
  annotate("text", x = 1, y = 1.5, label = "Bid layer",
           color = "#5c5c5c", fontface = "bold", size = 4.2, family = "sans") +
  annotate("text", x = 7, y = 1.5, label = "Award layer (survives)",
           color = "#1a3a5c", fontface = "bold", size = 4.2, family = "sans") +
  labs(
    title = "What survives the coarsening from bid layer to award layer",
    subtitle = "Five within-tender bid features are lost; four award-record fields survive.\nThe screening statistic operates on what survives — and reaches comparable AUC.",
    caption = "Block widths encode relative informativeness; colours: grey = lost, blue = survives."
  ) +
  theme_void(base_size = 11, base_family = "sans") +
  theme(
    plot.title    = element_text(face = "bold", size = 13, color = "#1a3a5c",
                                 hjust = 0, margin = margin(b = 6, l = 14)),
    plot.subtitle = element_text(size = 10, color = "grey30",
                                 hjust = 0, margin = margin(b = 8, l = 14)),
    plot.caption  = element_text(size = 8.5, color = "grey45",
                                 hjust = 0, margin = margin(t = 8, l = 14)),
    plot.margin   = margin(14, 14, 14, 14)
  )

out <- "work/v15-editor/staging_figures/fig_s3_sankey_data_coarsening.pdf"
ggsave(out, p, width = 9.4, height = 5.6, device = cairo_pdf)
cat(sprintf("wrote %s\n", out))
