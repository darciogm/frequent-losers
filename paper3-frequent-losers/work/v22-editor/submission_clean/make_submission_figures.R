#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tibble)
})

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

# CO-AUTHOR EDIT (JLEO R&R Subprompt 3): relabel layers — routine award record vs costly recovered bid record; "data coarsening"->"information coarsening".
# Figure 1: information layers.
total_height <- 24
n_bid <- 5
n_award <- 4
row_h_bid <- total_height / n_bid
row_h_award <- total_height / n_award

bid <- tibble(
  feature = c("Within-tender CV", "Within-tender skewness",
              "Within-tender kurtosis", "Bid spread",
              "Second-low ratio"),
  i = 1:n_bid
) |>
  mutate(y_top = (i - 1) * row_h_bid,
         y_bottom = i * row_h_bid,
         x_start = 0, x_end = 2)

award <- tibble(
  feature = c("Winner identity", "Participant identity",
              "Item code", "Negotiated price"),
  i = 1:n_award
) |>
  mutate(y_top = (i - 1) * row_h_award,
         y_bottom = i * row_h_award,
         x_start = 6, x_end = 8)

gate_xmin <- 3.0
gate_xmax <- 5.0
gate_ymin <- total_height / 2 - 4
gate_ymax <- total_height / 2 + 4

bid_arrows <- tibble(
  x_from = 2.05, x_to = 2.95,
  y_from = c(2, total_height - 2),
  y_to = c(gate_ymin + 1.5, gate_ymax - 1.5)
)

award_arrows <- tibble(
  x_from = 5.05, x_to = 5.95,
  y_from = c(gate_ymin + 1.5, gate_ymax - 1.5),
  y_to = c(2, total_height - 2)
)

p1 <- ggplot() +
  geom_rect(data = bid,
            aes(xmin = x_start, xmax = x_end,
                ymin = -y_bottom, ymax = -y_top),
            fill = "white", color = "black", linewidth = 0.45) +
  geom_text(data = bid,
            aes(x = (x_start + x_end) / 2,
                y = -(y_top + y_bottom) / 2,
                label = feature),
            size = 2.7, family = "sans", color = "black") +
  geom_rect(data = award,
            aes(xmin = x_start, xmax = x_end,
                ymin = -y_bottom, ymax = -y_top),
            fill = "gray82", color = "black", linewidth = 0.45) +
  geom_text(data = award,
            aes(x = (x_start + x_end) / 2,
                y = -(y_top + y_bottom) / 2,
                label = feature),
            size = 2.85, family = "sans", color = "black") +
  annotate("rect",
           xmin = gate_xmin, xmax = gate_xmax,
           ymin = -gate_ymax, ymax = -gate_ymin,
           fill = "gray45", color = "black", linewidth = 0.5) +
  annotate("text",
           x = (gate_xmin + gate_xmax) / 2,
           y = -(gate_ymin + gate_ymax) / 2,
           label = "Information\ncoarsening",
           color = "white", size = 3.2, fontface = "bold",
           family = "sans", lineheight = 0.95) +
  geom_segment(data = bid_arrows,
               aes(x = x_from, xend = x_to,
                   y = -y_from, yend = -y_to),
               color = "gray45", linewidth = 0.5, linetype = "22",
               arrow = arrow(length = unit(0.16, "cm"))) +
  geom_segment(data = award_arrows,
               aes(x = x_from, xend = x_to,
                   y = -y_from, yend = -y_to),
               color = "black", linewidth = 0.8,
               arrow = arrow(length = unit(0.18, "cm"))) +
  annotate("text", x = 1, y = 1.3,
           label = "Costly recovered\nbid record",
           fontface = "bold", size = 3.4, family = "sans",
           lineheight = 0.95) +
  annotate("text", x = 7, y = 1.3,
           label = "Routine award\nrecord",
           fontface = "bold", size = 3.4, family = "sans",
           lineheight = 0.95) +
  annotate("text",
           x = 1, y = -(total_height + 1.2),
           label = "Bid-distribution forensics (requires recovered bid record)",
           size = 2.9, family = "sans", color = "gray35",
           fontface = "italic") +
  annotate("text",
           x = 1, y = -(total_height + 2.6),
           label = "AUC = 0.888  [0.865, 0.911]",
           size = 3.0, family = "sans", color = "gray25") +
  annotate("text",
           x = 7, y = -(total_height + 1.2),
           label = "Award-layer triage score (routine record only)",
           size = 2.9, family = "sans", color = "black",
           fontface = "italic") +
  annotate("text",
           x = 7, y = -(total_height + 2.6),
           label = "AUC = 0.903  [0.884, 0.923]",
           size = 3.0, family = "sans", color = "black",
           fontface = "bold") +
  scale_x_continuous(limits = c(-0.3, 8.3), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-(total_height + 4), 3.2),
                     expand = c(0, 0)) +
  labs(title = NULL, subtitle = NULL, caption = NULL) +
  theme_void(base_size = 11, base_family = "sans") +
  theme(plot.margin = margin(8, 10, 8, 10))

ggsave("output/figures/fig_data_coarsening.pdf", p1,
       width = 7.0, height = 4.6, device = cairo_pdf)

# Figure 2: temporal holdout AUC. Values match Appendix D.4.
yearly <- tibble(
  test_year = 2014:2019,
  auc = c(0.819, 0.817, 0.851, 0.862, 0.897, 0.922),
  ci_lo = c(0.779, 0.776, 0.821, 0.832, 0.877, 0.912),
  ci_hi = c(0.860, 0.858, 0.881, 0.891, 0.918, 0.933)
)

p2 <- ggplot(yearly, aes(x = test_year, y = auc)) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.2) +
  geom_line() +
  geom_point(size = 2) +
  geom_hline(yintercept = 0.5, linetype = "dotted", color = "gray60") +
  geom_hline(yintercept = 0.9, linetype = "dashed", color = "gray60") +
  coord_cartesian(ylim = c(0.5, 1.0)) +
  labs(x = "Test year (training window: 2009 to year-1)",
       y = "AUC against adjudication-anchored cobidder labels",
       title = "Temporal holdout: training-window expansion test",
       subtitle = "Rolling-origin temporal holdout") +
  theme_bw()

ggsave("output/figures/fig_temporal_holdout_roc.pdf", p2,
       width = 7, height = 4.5, device = cairo_pdf)

