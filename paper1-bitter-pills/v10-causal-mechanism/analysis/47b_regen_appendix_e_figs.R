# 47b_regen_appendix_e_figs.R --- standalone regeneration of Appendix E
# figures (E.1 BJS event study, E.2 Honest-DiD sensitivity) from the cached
# v7 BJS event-study output. Mirrors the figure code in 43_rambachan_roth.R
# but reads only tab_es_honest.csv, so it does not load /tmp/v4_prepared.rds
# and does not emit macros or rewrite values.tex. No estimate is changed.

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
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

OUT     <- file.path(.this_dir, "..", "output")
ES_PATH <- file.path(.this_dir, "..", "..", "v7-r2round1", "output", "tables",
                     "tab_es_honest.csv")
if (!file.exists(ES_PATH)) stop("v7 BJS event-study output not found: ", ES_PATH)

es     <- fread(ES_PATH)
es_bjs <- es[method == "Borusyak-Jaravel-Spiess (imputation)"]
setorder(es_bjs, event_time)
beta_o <- es_bjs$coef
ev_o   <- es_bjs$event_time
se_o   <- es_bjs$se
pre_max_obs <- max(abs(beta_o[ev_o < 0]))

df <- data.table(et = ev_o, b = beta_o, se = se_o)
df[, lo := b - 1.96 * se]; df[, hi := b + 1.96 * se]
df[, adj_lo := b - pre_max_obs - 1.96 * se]
df[, adj_hi := b + pre_max_obs + 1.96 * se]

# Grayscale, serif styling consistent with the main-paper figure.
es_theme <- theme_classic(base_size = 10, base_family = "serif") +
  theme(panel.grid.major.y = element_line(color = "grey93", linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.line  = element_line(color = "grey30", linewidth = 0.4),
        axis.ticks = element_line(color = "grey30", linewidth = 0.3),
        axis.text  = element_text(color = "black"),
        axis.title = element_text(size = 10.5),
        plot.margin = margin(5, 8, 4, 5))

p_item <- ggplot(df, aes(et, b)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey55", linewidth = 0.4) +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey60", linewidth = 0.4) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, fill = "grey60") +
  geom_line(color = "grey20", linewidth = 0.6) +
  geom_point(size = 2.2, shape = 21, fill = "grey20", color = "grey10", stroke = 0.5) +
  scale_x_continuous(breaks = -5:5) +
  labs(x = "Years relative to first court order",
       y = "Log negotiated price relative to baseline") +
  es_theme
ggsave(file.path(OUT, "figures", "fig_event_study_item.pdf"),
       p_item, width = 6.4, height = 3.2, device = cairo_pdf)

p_honest <- ggplot(df, aes(et, b)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey55", linewidth = 0.4) +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey60", linewidth = 0.4) +
  geom_ribbon(aes(ymin = adj_lo, ymax = adj_hi), alpha = 0.25, fill = "grey75") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.12, color = "grey35", linewidth = 0.5) +
  geom_line(color = "grey20", linewidth = 0.6) +
  geom_point(size = 2.2, shape = 21, fill = "grey20", color = "grey10", stroke = 0.5) +
  scale_x_continuous(breaks = -5:5) +
  labs(x = "Years relative to first court order",
       y = "Log negotiated price relative to baseline") +
  es_theme
ggsave(file.path(OUT, "figures", "fig_event_study_honest_rr.pdf"),
       p_honest, width = 6.4, height = 3.2, device = cairo_pdf)

cat("wrote: fig_event_study_item.pdf, fig_event_study_honest_rr.pdf\n")
