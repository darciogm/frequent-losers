# ============================================================================
# fig_detection_paradox.R — The Detection Paradox visualization
# Shows: FL bids cluster tight → low CV → variance screen says "competitive"
#        → but prices are 6.4% higher
# ============================================================================

cat("=== fig_detection_paradox.R ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

library(ggplot2)

# ---- Panel data ----
# Two panels side by side:
# Left: Within-tender bid CV (FL vs non-FL) — FL has LOWER CV
# Right: Conditional price (FL vs non-FL) — FL has HIGHER price
# The juxtaposition IS the paradox

panel_data <- data.table(
  panel = factor(rep(c("A. What variance screens see",
                        "B. What actually happens to prices"), each = 2),
                 levels = c("A. What variance screens see",
                            "B. What actually happens to prices")),
  group = rep(c("FL-present\ntenders", "FL-absent\ntenders"), 2),
  value = c(0.57, 1.65,     # Within-tender CV: FL vs non-FL
            6.4, 0.0),       # Conditional price premium (%)
  label = c("CV = 0.57", "CV = 1.65",
            "+6.4%", "baseline"),
  fill  = rep(c("#e74c3c", "#3498db"), 2)
)

# ---- Build figure ----
p <- ggplot(panel_data, aes(x = group, y = value, fill = group)) +
  geom_col(width = 0.55, show.legend = FALSE) +
  geom_text(aes(label = label), vjust = -0.5, size = 4.2, fontface = "bold",
            color = c("#e74c3c", "#3498db", "#e74c3c", "#3498db")) +
  facet_wrap(~panel, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = c("FL-present\ntenders" = "#e74c3c",
                                "FL-absent\ntenders"  = "#3498db")) +
  labs(x = NULL, y = NULL,
       caption = paste0("Left: within-tender coefficient of variation of bids. ",
                        "FL bids cluster tightly above the winner (\u03c3_c/\u03c3_g = 0.72), ",
                        "making variance-based screens classify FL tenders as competitive.\n",
                        "Right: conditional log-price difference (OLS with item + year + PBU FE). ",
                        "Despite looking competitive to dispersion screens, ",
                        "FL-present tenders have 6.4% higher prices.")) +
  theme_minimal(base_size = 13) +
  theme(
    strip.text = element_text(face = "bold", size = 12, hjust = 0),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = 11),
    axis.text.y = element_text(size = 10),
    plot.caption = element_text(size = 8.5, color = "gray40", hjust = 0,
                                lineheight = 1.3, margin = margin(t = 12)),
    plot.margin = margin(15, 15, 10, 15),
    panel.spacing = unit(2, "cm")
  )

ggsave(file.path(OUT_FIG, "fig_detection_paradox_panels.pdf"),
       p, width = 9, height = 4.5, device = cairo_pdf)
cat("  Saved: fig_detection_paradox_panels.pdf\n")
cat("  Done.\n")
