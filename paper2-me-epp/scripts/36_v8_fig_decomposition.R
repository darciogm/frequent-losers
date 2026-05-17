# ============================================================================
# Paper 2 v8 — Regenerate fig_decomposition.pdf with corrected labels
# Source: v7-jpube-tight/scripts/58_figures.R (adapted)
# Reads:  v7-jpube-tight/data/processed/bne_decomp.parquet
# Writes: v8-jpube/output/figures/fig_decomposition.pdf
#
# Why this script exists: the v8 manuscript uses prose labels
# "lost competitive-discipline component" and "protected-pool offset",
# but the original figure labels read "intensive" and "entry"---a
# misalignment that contradicts the §3.4 paragraph stating the offset
# is not pure entry. This regeneration fixes the labels.
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(arrow); library(ggplot2)
})

PROJ_ROOT <- getwd()
DEC_PARQ  <- file.path(PROJ_ROOT, "v7-jpube-tight/data/processed/bne_decomp.parquet")
OUT_FIG   <- file.path(PROJ_ROOT, "v8-jpube/output/figures/fig_decomposition.pdf")
stopifnot(file.exists(DEC_PARQ))

dec <- setDT(arrow::read_parquet(DEC_PARQ))
cat("Loaded bne_decomp:\n"); print(dec)

# ---- Theme matching v7 figure ----------------------------------------------
theme_v3 <- function(base_size = 9) {
  theme_bw(base_size = base_size) +
    theme(panel.grid.minor = element_blank(),
          strip.text = element_text(face = "bold"),
          legend.position = "bottom",
          legend.box = "vertical",
          legend.spacing.y = unit(1, "pt"),
          plot.title = element_blank(),
          plot.subtitle = element_blank())
}
W <- 6.5; H <- 4.0

# ---- Build long-form + annotations -----------------------------------------
dec_long <- melt(dec,
  id.vars = "pharma_lbl",
  measure.vars = c("mean_S1", "mean_S2", "mean_S3"),
  variable.name = "scenario", value.name = "price")
dec_long[, scenario := fcase(
  scenario == "mean_S1", "S1: open, Pre pool",
  scenario == "mean_S2", "S2: SME-only, Pre pool",
  scenario == "mean_S3", "S3: SME-only, Post pool")]
dec_long[, scenario := factor(scenario,
  levels = c("S1: open, Pre pool",
             "S2: SME-only, Pre pool",
             "S3: SME-only, Post pool"))]
dec_long[, pharma_lbl := factor(pharma_lbl, levels = c("non-pharma", "pharma"))]

ann <- dec[, .(pharma_lbl,
               mean_S1, mean_S2, mean_S3,
               disc  = mean_S2 - mean_S1,
               offset = mean_S3 - mean_S2,
               total = mean_S3 - mean_S1)]
ann[, pharma_lbl := factor(pharma_lbl, levels = c("non-pharma", "pharma"))]

ann_labs <- rbind(
  ann[, .(pharma_lbl, scenario = "S1: open, Pre pool",
          y = mean_S1 - 0.06,
          lbl = sprintf("%.2f", mean_S1),
          col = "white")],
  ann[, .(pharma_lbl, scenario = "S2: SME-only, Pre pool",
          y = mean_S2 + 0.05,
          lbl = sprintf("+%.2f lost discipline", disc),
          col = "black")],
  ann[, .(pharma_lbl, scenario = "S3: SME-only, Post pool",
          y = mean_S3 + 0.05,
          lbl = sprintf("%+.2f protected-pool offset\n(=%+.2f total)", offset, total),
          col = "black")])
ann_labs[, scenario := factor(scenario, levels = levels(dec_long$scenario))]

fig <- ggplot(dec_long, aes(x = scenario, y = price, fill = scenario)) +
  geom_col(width = 0.62, colour = "black", linewidth = 0.2) +
  geom_hline(yintercept = 1.0, linetype = "dotted", colour = "grey40", linewidth = 0.3) +
  geom_text(data = ann_labs,
            aes(x = scenario, y = y, label = lbl, colour = col),
            inherit.aes = FALSE, size = 2.7,
            lineheight = 0.9, hjust = 0.5) +
  scale_colour_identity() +
  facet_wrap(~ pharma_lbl, nrow = 1) +
  scale_fill_manual(values = c(
    "S1: open, Pre pool" = "grey25",
    "S2: SME-only, Pre pool" = "grey50",
    "S3: SME-only, Post pool" = "grey75"),
    guide = "none") +
  scale_y_continuous(
    limits = c(0, 1.4),
    breaks = seq(0, 1.2, 0.2),
    expand = c(0, 0),
    labels = scales::number_format(accuracy = 0.01)) +
  labs(
    x = NULL,
    y = expression(paste("Simulated ", bar(c)[(2)], " / reference price"))) +
  theme_v3() +
  theme(axis.text.x = element_text(size = 7.5, angle = 12, hjust = 1))

dir.create(dirname(OUT_FIG), recursive = TRUE, showWarnings = FALSE)
ggsave(OUT_FIG, fig, width = W, height = H, device = cairo_pdf)
cat("Saved:", OUT_FIG, "\n")
