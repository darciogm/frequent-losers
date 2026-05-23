# Data-coarsening diagram (bid layer → award layer, grayscale).
# Output: work/v13/output/figures/fig_data_coarsening.pdf

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tibble)
})

# Common block geometry.
total_height <- 24       # total height for both blocks (we keep them equal)
n_bid    <- 5
n_award  <- 4
row_h_bid    <- total_height / n_bid
row_h_award  <- total_height / n_award

bid_features <- c("Within-tender CV",
                  "Within-tender skewness",
                  "Within-tender kurtosis",
                  "Bid spread",
                  "Second-low ratio")
award_fields <- c("Winner identity",
                  "Participant identity",
                  "Item code",
                  "Negotiated price")

bid <- tibble(
  feature  = bid_features,
  i        = 1:n_bid
) |> mutate(
  y_top    = (i - 1) * row_h_bid,
  y_bottom = i * row_h_bid,
  x_start  = 0, x_end = 2,
  fill     = "white"
)

award <- tibble(
  feature  = award_fields,
  i        = 1:n_award
) |> mutate(
  y_top    = (i - 1) * row_h_award,
  y_bottom = i * row_h_award,
  x_start  = 6, x_end = 8,
  fill     = "gray80"
)

# Coarsening gate (centred vertically with respect to the blocks).
gate_xmin <- 3.0; gate_xmax <- 5.0
gate_ymin <- total_height / 2 - 4
gate_ymax <- total_height / 2 + 4

# Lost arrows (bid → gate).
bid_arrows <- tibble(
  x_from = 2.05, x_to = 2.95,
  y_from = c(2,                  total_height - 2),
  y_to   = c(gate_ymin + 1.5,    gate_ymax - 1.5)
)

# Survives arrows (gate → award).
award_arrows <- tibble(
  x_from = 5.05, x_to = 5.95,
  y_from = c(gate_ymin + 1.5, gate_ymax - 1.5),
  y_to   = c(2,                  total_height - 2)
)

p <- ggplot() +
  # bid block
  geom_rect(data = bid,
            aes(xmin = x_start, xmax = x_end,
                ymin = -y_bottom, ymax = -y_top),
            fill = "white", color = "black", linewidth = 0.45) +
  geom_text(data = bid,
            aes(x = (x_start + x_end) / 2,
                y = -(y_top + y_bottom) / 2,
                label = feature),
            size = 2.7, family = "sans", color = "black") +
  # award block
  geom_rect(data = award,
            aes(xmin = x_start, xmax = x_end,
                ymin = -y_bottom, ymax = -y_top),
            fill = "gray82", color = "black", linewidth = 0.45) +
  geom_text(data = award,
            aes(x = (x_start + x_end) / 2,
                y = -(y_top + y_bottom) / 2,
                label = feature),
            size = 2.85, family = "sans", color = "black") +
  # coarsening gate
  annotate("rect",
           xmin = gate_xmin, xmax = gate_xmax,
           ymin = -gate_ymax, ymax = -gate_ymin,
           fill = "gray45", color = "black", linewidth = 0.5) +
  annotate("text",
           x = (gate_xmin + gate_xmax) / 2,
           y = -(gate_ymin + gate_ymax) / 2,
           label = "Data\ncoarsening",
           color = "white", size = 3.2, fontface = "bold",
           family = "sans", lineheight = 0.95) +
  # lost arrows (dashed)
  geom_segment(data = bid_arrows,
               aes(x = x_from, xend = x_to,
                   y = -y_from, yend = -y_to),
               color = "gray45", linewidth = 0.5, linetype = "22",
               arrow = arrow(length = unit(0.16, "cm"))) +
  # survives arrows (solid)
  geom_segment(data = award_arrows,
               aes(x = x_from, xend = x_to,
                   y = -y_from, yend = -y_to),
               color = "black", linewidth = 0.8,
               arrow = arrow(length = unit(0.18, "cm"))) +
  # column headers
  annotate("text", x = 1, y = 1.3,
           label = "Bid layer (lost)",
           fontface = "bold", size = 3.6, family = "sans") +
  annotate("text", x = 7, y = 1.3,
           label = "Award layer (survives)",
           fontface = "bold", size = 3.6, family = "sans") +
  # AUC captions directly below each block
  annotate("text",
           x = 1, y = -(total_height + 1.2),
           label = "Imhof full pipeline (requires bid layer)",
           size = 2.9, family = "sans", color = "gray35",
           fontface = "italic") +
  annotate("text",
           x = 1, y = -(total_height + 2.6),
           label = "AUC = 0.888  [0.865, 0.911]",
           size = 3.0, family = "sans", color = "gray25") +
  annotate("text",
           x = 7, y = -(total_height + 1.2),
           label = "Screening statistic (award layer only)",
           size = 2.9, family = "sans", color = "black",
           fontface = "italic") +
  annotate("text",
           x = 7, y = -(total_height + 2.6),
           label = "AUC = 0.921  [0.914, 0.928]",
           size = 3.0, family = "sans", color = "black",
           fontface = "bold") +
  scale_x_continuous(limits = c(-0.3, 8.3), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-(total_height + 4), 2.5),
                     expand = c(0, 0)) +
  labs(title = NULL, subtitle = NULL, caption = NULL) +
  theme_void(base_size = 11, base_family = "sans") +
  theme(plot.margin = margin(8, 10, 8, 10))

dir.create("work/v13/output/figures", showWarnings = FALSE, recursive = TRUE)
out <- "work/v13/output/figures/fig_data_coarsening.pdf"
ggsave(out, p, width = 7.0, height = 4.6, device = cairo_pdf)
cat(sprintf("wrote %s\n", out))
