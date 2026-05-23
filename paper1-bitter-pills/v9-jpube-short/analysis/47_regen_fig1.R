# 47_regen_fig1.R --- standalone Fig 1 regeneration using cached B=499 CIs.
# Reads point estimates and IC95 from values.tex; rebuilds the headline
# figure with the v8.1 serif-font polish without re-running the cluster
# bootstrap (which hits a fixest FE-cache slowdown for this dataset).

suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
  library(scales)
})

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()

VALUES  <- file.path(.this_dir, "..", "manuscript", "paper", "values.tex")
OUT_FIG <- file.path(.this_dir, "..", "output", "figures",
                     "fig_sourcing_vs_pricing.pdf")

read_macro_pct <- function(name) {
  v <- readLines(VALUES)
  pat <- sprintf("renewcommand\\{\\\\BP%s\\}\\{(.+?)\\}", name)
  m <- regmatches(v, regexec(pat, v))
  vals <- vapply(m, function(x) if (length(x) > 1) x[2] else NA_character_,
                 character(1))
  vals <- vals[!is.na(vals)]
  if (length(vals) == 0) stop(sprintf("Macro BP%s not found", name))
  raw <- tail(vals, 1)
  as.numeric(gsub("%", "", gsub("\\\\%", "", raw)))
}

mech_pct   <- read_macro_pct("utgMechanicalCone")
within_pct <- read_macro_pct("utgWithinFirmOffset")
comp_pct   <- read_macro_pct("utgCompositionResidual")
mech_lo    <- read_macro_pct("utgMechCIlow")
mech_hi    <- read_macro_pct("utgMechCIhigh")
within_lo  <- read_macro_pct("utgWithinCIlow")
within_hi  <- read_macro_pct("utgWithinCIhigh")
comp_lo    <- read_macro_pct("utgCompCIlow")
comp_hi    <- read_macro_pct("utgCompCIhigh")
obs_lo     <- read_macro_pct("utgObsCIlow")
obs_hi     <- read_macro_pct("utgObsCIhigh")

# Observed point estimate: from naive log gap -0.259 (admin minus lit).
# (exp(-0.259) - 1) * 100 = -22.8%; this matches values.tex prose.
obs_pct <- (exp(-0.259) - 1) * 100

plot_df <- data.table(
  comp_short = c("Observed", "Mechanical C1\n(quantity)",
                 "Within-firm\n(no markup)", "Composition\n(sourcing)"),
  pct        = c(obs_pct, mech_pct, within_pct, comp_pct),
  ci_lo      = c(obs_lo, mech_lo, within_lo, comp_lo),
  ci_hi      = c(obs_hi, mech_hi, within_hi, comp_hi)
)
plot_df[, comp_short := factor(comp_short, levels = comp_short)]
print(plot_df)

fill_pal    <- c("grey55", "grey75", "white", "grey75")
outline_pal <- c("grey25", "grey25", "black", "grey25")
linew_pal   <- c(0.4, 0.4, 1.4, 0.4)

y_top <- max(plot_df$pct, plot_df$ci_hi, na.rm = TRUE)
y_bot <- min(plot_df$pct, plot_df$ci_lo, na.rm = TRUE)
y_pad <- 0.05 * (y_top - y_bot)

p <- ggplot(plot_df, aes(comp_short, pct)) +
  geom_col(width = 0.58,
           fill = fill_pal, color = outline_pal, linewidth = linew_pal) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                width = 0.16, color = "grey15", linewidth = 0.45) +
  geom_hline(yintercept = 0, color = "grey20", linewidth = 0.4) +
  annotate("text", x = 3, y = y_top * 0.62,
           label = "no within-firm\nmarkup",
           size = 3.4, fontface = "italic", family = "serif",
           lineheight = 0.95, color = "black") +
  annotate("segment",
           x = 3, xend = 3,
           y = y_top * 0.45,
           yend = plot_df$ci_hi[3] + y_pad,
           color = "black", linewidth = 0.4,
           arrow = arrow(length = unit(0.14, "cm"), type = "closed")) +
  scale_y_continuous(breaks = pretty_breaks(n = 6),
                     labels = function(x) sprintf("%+.0f", x)) +
  labs(x = NULL,
       y = "Admin-minus-litigated log price gap (percent)") +
  theme_classic(base_size = 11, base_family = "serif") +
  theme(panel.grid.major.y = element_line(color = "grey92", linewidth = 0.3),
        axis.line.x  = element_line(color = "grey20", linewidth = 0.4),
        axis.line.y  = element_line(color = "grey20", linewidth = 0.4),
        axis.ticks   = element_line(color = "grey20", linewidth = 0.3),
        axis.text    = element_text(color = "black"),
        axis.title.y = element_text(margin = margin(r = 8)),
        plot.margin  = margin(10, 14, 6, 8))

ggsave(OUT_FIG, p, width = 6.8, height = 4.2, device = cairo_pdf)
cat("wrote:", OUT_FIG, "\n")
