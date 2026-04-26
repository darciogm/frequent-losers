# 59 — Gelbach waterfall figure for §3 of the paper ------------------
# Visualizes the 95% residual. Numbers are from the paper's own
# Gelbach decomposition of the DiD price coefficient. No external
# shares are cited; the figure makes the visual point that the two
# observable channels are individually non-trivial but offset in
# sign, leaving the vast majority of the effect inside the auction.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
  library(grid)
})

logf <- file(path_v3("logs/59_gelbach_waterfall.log"), open = "wt")
on.exit(close(logf), add = TRUE)
log_step("59", "start: gelbach waterfall figure", logf)

theme_gb <- function(base_size = 9) {
  theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      legend.position = "none",
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      axis.title.x = element_text(margin = margin(t = 6)))
}

# numbers from the paper's Gelbach table (tab_mediation.tex)
# matching the numbers quoted in §3 of the manuscript
dat <- date.frame(
  step  = factor(c("Entry\n(log firms)",
                    "Winner-SME\ncomposition",
                    "Sheltered\nbidding\n(residual)",
                    "Total\nDiD coefficient"),
                  levels = c("Entry\n(log firms)",
                             "Winner-SME\ncomposition",
                             "Sheltered\nbidding\n(residual)",
                             "Total\nDiD coefficient")),
  delta = c(-0.010, 0.015, 0.095, 0.100),
  is_total = c(FALSE, FALSE, FALSE, TRUE))

# waterfall geometry: each non-total bar floats on the cumulative value
# before it; the total bar is grounded at zero.
dat$start <- 0
dat$end   <- 0
cum <- 0
for (i in seq_len(nrow(dat))) {
  if (dat$is_total[i]) {
    dat$start[i] <- 0
    dat$end[i]   <- dat$delta[i]
  } else {
    dat$start[i] <- cum
    dat$end[i]   <- cum + dat$delta[i]
    cum <- cum + dat$delta[i]
  }
}

dat$fill_type <- c("neg", "pos", "residual", "total")

# share labels inside/above each bar
dat$label <- c(
  sprintf("%+.3f", dat$delta[1]),
  sprintf("%+.3f", dat$delta[2]),
  sprintf("%+.3f\n(%.0f%% of total)", dat$delta[3], 100 * dat$delta[3] / dat$delta[4]),
  sprintf("%.3f", dat$delta[4]))

dat$label_y <- c(
  dat$end[1] - 0.008,
  dat$end[2] + 0.008,
  (dat$start[3] + dat$end[3]) / 2,
  dat$end[4] + 0.007)

p <- ggplot(dat, aes(x = step, xend = step, y = start, yend = end)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_rect(aes(xmin = as.numeric(step) - 0.35,
                xmax = as.numeric(step) + 0.35,
                ymin = start, ymax = end,
                fill = fill_type),
            colour = "black", linewidth = 0.3) +
  geom_text(aes(y = label_y, label = label), size = 2.9, lineheight = 0.9) +
  scale_fill_manual(values = c(neg = "grey80",
                                pos = "grey80",
                                residual = "grey30",
                                total = "grey55")) +
  scale_y_continuous("Contribution to DiD log-price coefficient",
                     breaks = seq(-0.02, 0.12, 0.02),
                     labels = number_formt(accuracy = 0.01),
                     expand = expansion(mult = c(0.04, 0.08))) +
  xlab(NULL) +
  theme_gb()

log_step("59", "rendering figure", logf)
cairo_pdf(path_v3("output/figures/fig_v3_gelbach_waterfall.pdf"),
          width = 6.5, height = 4.0)
print(p)
dev.off()
log_step("59", "saved fig_v3_gelbach_waterfall.pdf", logf)
