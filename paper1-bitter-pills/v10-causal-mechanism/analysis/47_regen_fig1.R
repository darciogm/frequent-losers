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

read_macro_num <- function(name) {
  v <- readLines(VALUES)
  pat <- sprintf("renewcommand\\{\\\\BP%s\\}\\{(.+?)\\}", name)
  m <- regmatches(v, regexec(pat, v))
  vals <- vapply(m, function(x) if (length(x) > 1) x[2] else NA_character_,
                 character(1))
  vals <- vals[!is.na(vals)]
  if (length(vals) == 0) {
    pat <- sprintf("providecommand\\{\\\\BP%s\\}\\{(.+?)\\}", name)
    m <- regmatches(v, regexec(pat, v))
    vals <- vapply(m, function(x) if (length(x) > 1) x[2] else NA_character_,
                   character(1))
    vals <- vals[!is.na(vals)]
  }
  if (length(vals) == 0) stop(sprintf("Macro BP%s not found", name))
  raw <- tail(vals, 1)
  as.numeric(gsub("[^0-9.+-]", "", raw))
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
obs_log    <- read_macro_num("utgObsLogGap")
obs_pct    <- (exp(obs_log) - 1) * 100

plot_df <- data.table(
  comp_short = c("Observed gap", "Quantity / scale",
                 "Within-firm pricing", "Supplier composition"),
  pct        = c(obs_pct, mech_pct, within_pct, comp_pct),
  ci_lo      = c(obs_lo, mech_lo, within_lo, comp_lo),
  ci_hi      = c(obs_hi, mech_hi, within_hi, comp_hi)
)
row_order <- plot_df$comp_short
plot_df[, comp_short := factor(comp_short, levels = rev(row_order))]
plot_df[, near_zero := comp_short == "Within-firm pricing"]
plot_df[, row_type := fifelse(comp_short == "Observed gap", "Observed",
                       fifelse(near_zero, "Within-firm", "Component"))]
print(plot_df)

x_top <- max(plot_df$pct, plot_df$ci_hi, na.rm = TRUE)
x_bot <- min(plot_df$pct, plot_df$ci_lo, na.rm = TRUE)
x_rng <- x_top - x_bot
x_lo  <- x_bot - 0.06 * x_rng
x_hi  <- x_top + 0.10 * x_rng

# "near zero" sits just past the right end of the within-firm interval.
near_x <- min(within_hi + 0.035 * x_rng, x_hi - 0.20 * x_rng)

p <- ggplot(plot_df, aes(pct, comp_short)) +
  # separate the observed total (top row) from its three components
  geom_hline(yintercept = 3.5, linetype = "dotted",
             color = "grey70", linewidth = 0.35) +
  geom_vline(xintercept = 0, color = "grey25", linewidth = 0.55) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi),
                orientation = "y", width = 0.0,
                color = "grey30", linewidth = 0.85) +
  geom_point(aes(fill = row_type, shape = row_type),
             size = 4.1, color = "grey10", stroke = 0.85) +
  scale_fill_manual(values = c("Observed" = "grey10",
                               "Component" = "grey55",
                               "Within-firm" = "white"),
                    guide = "none") +
  scale_shape_manual(values = c("Observed" = 21,
                                "Component" = 21,
                                "Within-firm" = 23),
                     guide = "none") +
  annotate("text",
           x = near_x, y = "Within-firm pricing",
           label = "near zero", hjust = 0, vjust = 0.52,
           size = 3.35, fontface = "italic", family = "serif",
           color = "grey15") +
  scale_x_continuous(breaks = pretty_breaks(n = 6),
                     labels = function(x) sprintf("%+.0f", x),
                     expand = expansion(mult = 0),
                     limits = c(x_lo, x_hi)) +
  labs(x = "Administrative − litigated price gap (percent)",
       y = NULL) +
  theme_classic(base_size = 12, base_family = "serif") +
  theme(panel.grid.major.x = element_line(color = "grey91", linewidth = 0.35),
        panel.grid.minor.x = element_blank(),
        axis.line.x  = element_line(color = "grey25", linewidth = 0.55),
        axis.line.y  = element_blank(),
        axis.ticks.y = element_blank(),
        axis.ticks.x = element_line(color = "grey25", linewidth = 0.35),
        axis.text.x  = element_text(color = "black", size = 11.5),
        axis.text.y  = element_text(color = "black", size = 12.5, hjust = 0),
        axis.title.x = element_text(size = 12.5, margin = margin(t = 9)),
        plot.margin  = margin(8, 16, 6, 8))

ggsave(OUT_FIG, p, width = 6.8, height = 2.75, device = cairo_pdf)
cat("wrote:", OUT_FIG, "\n")
