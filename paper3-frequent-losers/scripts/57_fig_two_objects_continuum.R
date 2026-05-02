# Two-objects continuum (β vs β^ov), grayscale, submission style.
# Output: output/figures/fig_two_objects_continuum.pdf

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tibble)
})

src <- "output/item_level_scope_match/item_level_scope_match.csv"
df_anchor <- read.csv(src, stringsAsFactors = FALSE)

strictness <- c(
  baseline_fe        = 0.00,
  overlap_cell_att   = 0.55,
  overlap_ref_att    = 0.65,
  ps_att_trimmed     = 1.00
)
label_short <- c(
  baseline_fe        = "Broad sample (β)",
  overlap_cell_att   = "Overlap cell",
  overlap_ref_att    = "+ ref-price bins",
  ps_att_trimmed     = "PS-trimmed (β^ov)"
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

smooth <- approx(df$strictness, df$coef_pct, n = 200) |> as_tibble()
smooth_lo <- approx(df$strictness, df$lo, n = 200) |> as_tibble()
smooth_hi <- approx(df$strictness, df$hi, n = 200) |> as_tibble()
smooth$lo <- smooth_lo$y
smooth$hi <- smooth_hi$y

# Per-point label positioning placed in clear zones — no overlap with the
# curve. Coordinates are absolute (data-space).
labels_df <- tibble(
  label = c("'Broad sample ('*beta*')'",
            "'Overlap cell'",
            "'+ ref-price bins'",
            "'PS-trimmed ('*beta^{ov}*')'"),
  x     = c(0.02, 0.46, 0.74, 0.99),
  y     = c(11.5, -2.5, -2.5, -33.5),
  hjust = c(0.0,  1.0,  0.0,   1.0),
  point_x = c(0.00, 0.55, 0.65, 1.00),
  point_y = c(6.36, -9.72, -9.69, -30.67)
)

p <- ggplot() +
  geom_hline(yintercept = 0, color = "gray45", linetype = "dashed", linewidth = 0.4) +
  geom_ribbon(data = smooth, aes(x, ymin = lo, ymax = hi),
              fill = "gray70", alpha = 0.35) +
  geom_line(data = smooth, aes(x, y), color = "black", linewidth = 0.9) +
  geom_point(data = df, aes(strictness, coef_pct, size = sample_share),
             color = "black", fill = "white", shape = 21, stroke = 1.0) +
  geom_segment(data = labels_df,
               aes(x = x, xend = point_x, y = y, yend = point_y),
               color = "gray60", linewidth = 0.25, linetype = "solid") +
  geom_text(data = labels_df,
            aes(x = x, y = y, label = label, hjust = hjust),
            size = 3.0, color = "black", family = "sans",
            vjust = 0.5, parse = TRUE) +
  scale_size_continuous(range = c(2.5, 5.5), guide = "none") +
  scale_x_continuous(
    breaks = df$strictness,
    labels = sprintf("%.0f%%", 100 * df$sample_share),
    expand = expansion(add = c(0.07, 0.10)),
    name   = "Sample retained (% of broad sample)"
  ) +
  scale_y_continuous(
    breaks = c(-30, -20, -10, 0, 10),
    labels = function(x) sprintf("%+d%%", x),
    limits = c(-37, 16),
    expand = c(0, 0),
    name   = "Conditional log-price coefficient"
  ) +
  labs(x = "Sample retained (% of broad sample)",
       y = "Conditional log-price coefficient",
       title    = NULL,
       subtitle = NULL,
       caption  = NULL) +
  theme_bw(base_size = 11, base_family = "sans") +
  theme(
    panel.grid.minor = element_blank(),
    axis.title       = element_text(size = 10, color = "black"),
    plot.margin      = margin(8, 12, 8, 10)
  )

dir.create("work/v13/output/figures", showWarnings = FALSE, recursive = TRUE)
out <- "work/v13/output/figures/fig_two_objects_continuum.pdf"
ggsave(out, p, width = 6.5, height = 4.2, device = cairo_pdf)
cat(sprintf("wrote %s\n", out))
