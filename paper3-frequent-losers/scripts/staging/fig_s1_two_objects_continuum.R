# Two-objects plot: β vs β^ov along the overlap-restriction continuum.
# Substitutes the bare 4-row table with a continuous curve carrying CIs.
# Output: staging_figures/fig_s1_two_objects_continuum.pdf

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tibble)
})

# Read the four anchored points.
src <- "output/item_level_scope_match/item_level_scope_match.csv"
df_anchor <- read.csv(src, stringsAsFactors = FALSE)

# Map specs to a "strictness of overlap" axis (0 = broad sample, 1 = PS-trimmed).
strictness <- c(
  baseline_fe        = 0.00,
  overlap_cell_att   = 0.55,
  overlap_ref_att    = 0.65,
  ps_att_trimmed     = 1.00
)

label_short <- c(
  baseline_fe        = "Broad sample",
  overlap_cell_att   = "Overlap cell",
  overlap_ref_att    = "+ ref-price bins",
  ps_att_trimmed     = "PS-trimmed"
)

df <- df_anchor |>
  mutate(
    strictness = strictness[spec],
    label      = label_short[spec],
    coef_pct   = 100 * coef,
    lo         = 100 * (coef - 1.96 * se),
    hi         = 100 * (coef + 1.96 * se),
    sample_share = n / max(n)
  ) |>
  arrange(strictness)

# Smooth-line interpolation between anchors for visual continuum.
smooth <- approx(df$strictness, df$coef_pct, n = 200) |> as_tibble()
smooth_lo <- approx(df$strictness, df$lo, n = 200) |> as_tibble()
smooth_hi <- approx(df$strictness, df$hi, n = 200) |> as_tibble()
smooth$lo <- smooth_lo$y
smooth$hi <- smooth_hi$y

p <- ggplot() +
  geom_hline(yintercept = 0, color = "grey60", linetype = "dotted") +
  geom_ribbon(data = smooth, aes(x, ymin = lo, ymax = hi),
              fill = "#2c5f8a", alpha = 0.18) +
  geom_line(data = smooth, aes(x, y), color = "#2c5f8a", linewidth = 1.2) +
  geom_point(data = df, aes(strictness, coef_pct, size = sample_share),
             color = "#1a3a5c", fill = "white", shape = 21, stroke = 1.6) +
  geom_text(data = df, aes(strictness, coef_pct, label = label),
            vjust = -2.2, hjust = c(0, 0.5, 0.5, 1), size = 3.6,
            family = "sans", fontface = "plain", color = "#1a3a5c") +
  scale_size_continuous(range = c(3, 7), guide = "none") +
  scale_x_continuous(
    breaks = df$strictness,
    labels = sprintf("%.0f%%", 100 * df$sample_share),
    expand = expansion(add = c(0.06, 0.10))
  ) +
  scale_y_continuous(
    breaks = c(-30, -20, -10, 0, 10),
    labels = function(x) sprintf("%+d%%", x)
  ) +
  labs(
    x = "Sample retained (% of broad sample)",
    y = "Conditional log-price coefficient",
    title = "Two empirical objects, one continuum",
    subtitle = expression(paste(
      "Broad-sample ", beta, " (left) vs. overlap-restricted ",
      beta^{ov}, " (right). Sign reverses as overlap restriction strips deployment sorting."
    )),
    caption = "Bands: 95% CI. Anchored at 4 specifications from tab_item_level_scope_match."
  ) +
  theme_minimal(base_size = 11, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 14, color = "#1a3a5c"),
    plot.subtitle    = element_text(size = 10.5, color = "grey25", margin = margin(b = 12)),
    plot.caption     = element_text(size = 8.5, color = "grey45"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "grey92"),
    panel.grid.major.y = element_line(color = "grey92"),
    axis.title       = element_text(size = 10, color = "grey25"),
    axis.text        = element_text(color = "grey30"),
    plot.margin      = margin(14, 18, 12, 14)
  )

out <- "work/v15-editor/staging_figures/fig_s1_two_objects_continuum.pdf"
ggsave(out, p, width = 7.6, height = 4.8, device = cairo_pdf)
cat(sprintf("wrote %s\n", out))
