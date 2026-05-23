#!/usr/bin/env Rscript
# Discrimination ladder figure for sec06 (Imhof comparison).
# Output: figures/fig_discrimination_ladder.pdf
#
# Values are taken from values.tex (\valImhofFLBin, \valImhofFLcont,
# \valImhofFull, \valImhofComboCont and their CIs). Update both files
# in tandem if the underlying numbers change.

suppressPackageStartupMessages({
  library(ggplot2)
})

dat <- data.frame(
  model = factor(c(
    "Frequent-loser flag\n(award layer, binary)",
    "Participation intensity\n(award layer, continuous)",
    "Bid-distribution benchmark\n(Imhof-Wallimann)",
    "Combined\n(award + bid layer)"
  ), levels = c(
    "Combined\n(award + bid layer)",
    "Bid-distribution benchmark\n(Imhof-Wallimann)",
    "Participation intensity\n(award layer, continuous)",
    "Frequent-loser flag\n(award layer, binary)"
  )),
  layer = c("Award layer", "Award layer", "Bid layer", "Combined"),
  auc   = c(0.921, 0.884, 0.888, 0.962),
  lo    = c(0.914, 0.860, 0.865, 0.954),
  hi    = c(0.928, 0.908, 0.911, 0.969)
)

p <- ggplot(dat, aes(x = auc, y = model, color = layer)) +
  geom_segment(aes(x = lo, xend = hi, yend = model), linewidth = 1.2) +
  geom_point(size = 3.2) +
  geom_text(aes(label = sprintf("%.3f", auc)),
            hjust = -0.45, vjust = 0.4, size = 3.5, color = "black") +
  scale_color_manual(values = c(
    "Award layer" = "#1f78b4",
    "Bid layer"   = "#e31a1c",
    "Combined"    = "#33a02c"
  )) +
  scale_x_continuous(limits = c(0.83, 1.00),
                     breaks = seq(0.85, 1.00, 0.05)) +
  labs(
    x = "AUC against adjudication-anchored cobidder labels (5-fold CV)",
    y = NULL,
    color = "Information layer"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(hjust = 1, lineheight = 0.9)
  )

ggsave("figures/fig_discrimination_ladder.pdf", p,
       width = 6.6, height = 3.3, units = "in", device = "pdf")
cat("wrote figures/fig_discrimination_ladder.pdf\n")
