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
plot_df[, comp_short := factor(comp_short, levels = rev(comp_short))]
print(plot_df)

x_top <- max(plot_df$pct, plot_df$ci_hi, na.rm = TRUE)
x_bot <- min(plot_df$pct, plot_df$ci_lo, na.rm = TRUE)
x_pad <- 0.08 * (x_top - x_bot)
plot_df[, near_zero := comp_short == "Within-firm pricing"]

p <- ggplot(plot_df, aes(pct, comp_short)) +
  geom_vline(xintercept = 0, color = "grey20", linewidth = 0.4) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi),
                orientation = "y", width = 0.14,
                color = "grey25", linewidth = 0.45) +
  geom_point(aes(fill = near_zero),
             shape = 21, size = 3.0, color = "grey15", stroke = 0.55) +
  scale_fill_manual(values = c(`TRUE` = "white", `FALSE` = "grey55"),
                    guide = "none") +
  annotate("text",
           x = x_top - x_pad, y = "Within-firm pricing",
           label = "near zero", hjust = 1, vjust = -0.9,
           size = 3.2, fontface = "italic", family = "serif",
           color = "black") +
  scale_x_continuous(breaks = pretty_breaks(n = 7),
                     labels = function(x) sprintf("%+.0f", x),
                     limits = c(x_bot - x_pad, x_top + x_pad)) +
  labs(x = "Admin-minus-litigated price gap (percent)",
       y = NULL) +
  theme_classic(base_size = 11, base_family = "serif") +
  theme(panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3),
        axis.line.x  = element_line(color = "grey20", linewidth = 0.4),
        axis.line.y  = element_blank(),
        axis.ticks   = element_line(color = "grey20", linewidth = 0.3),
        axis.text    = element_text(color = "black"),
        axis.title.x = element_text(margin = margin(t = 8)),
        plot.margin  = margin(8, 12, 6, 8))

ggsave(OUT_FIG, p, width = 6.6, height = 2.7, device = cairo_pdf)
cat("wrote:", OUT_FIG, "\n")
