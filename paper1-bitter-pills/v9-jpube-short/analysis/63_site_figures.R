# 63_site_figures.R --- site-only enrichment figures for the AN pages.
# Reads canonical numbers from the paper's values.tex (single source of truth,
# no hardcoding) and renders four color-blind-safe figures into the MkDocs
# assets dir. These do NOT enter the paper (exhibits stay <=5); they enrich the
# documentation site. Producers of the underlying numbers: scripts 48/50/60.

suppressPackageStartupMessages({ library(ggplot2) })

.this_dir <- tryCatch(normalizePath(dirname(sys.frame(1)$ofile)), error = function(e) getwd())
args <- commandArgs(trailingOnly = FALSE); fa <- grep("^--file=", args, value = TRUE)
if (length(fa)) .this_dir <- normalizePath(dirname(sub("^--file=", "", fa[1])))

VALUES <- normalizePath(file.path(.this_dir, "..", "manuscript", "paper", "values.tex"))
OUT    <- normalizePath(file.path(.this_dir, "..", "..", "docs", "assets", "figures"))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
vlines <- readLines(VALUES)

# Read the last \renewcommand{\BP<name>}{<val>} and return the numeric part.
mac <- function(name) {
  pat <- sprintf("\\\\renewcommand\\{\\\\BP%s\\}\\{(.*)\\}", name)
  hits <- regmatches(vlines, regexec(pat, vlines))
  vals <- vapply(hits, function(x) if (length(x) == 2) x[2] else NA_character_, "")
  raw  <- tail(vals[!is.na(vals)], 1)
  if (length(raw) == 0) stop(sprintf("macro BP%s not found", name))
  num <- gsub("\\\\%|~pp|~M|\\\\\\$|\\{,\\}|\\s|\\+", "", raw)  # strip %, pp, $, thousands, +
  as.numeric(num)
}

INSPER <- "#C8102E"; GREY <- "grey55"; INK <- "grey15"
wrap <- function(s, w = 92) paste(strwrap(s, width = w), collapse = "\n")
base_theme <- theme_minimal(base_family = "serif", base_size = 13) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        axis.title = element_text(size = 12),
        plot.caption = element_text(size = 9, colour = "grey40", hjust = 0))

# ---------------------------------------------------------------------------
# (1) AN-003/AN-004 : within firm-buyer-item coefficient by subsample (forest)
# ---------------------------------------------------------------------------
fr <- data.frame(
  label = c("Above-median quantity", "SUS formulary", "Later period (2016-2019)",
            "All triples (baseline)", "Below-median quantity",
            "Non-formulary", "Earlier period (2009-2015)"),
  coef  = c(mac("wfRobAboveQtyCoef"), mac("wfRobSUSCoef"), mac("wfRobLaterCoef"),
            mac("wfRobAllCoef"), mac("wfRobBelowQtyCoef"),
            mac("wfRobNonSUSCoef"), mac("wfRobEarlyCoef")),
  se    = c(mac("wfRobAboveQtySE"), mac("wfRobSUSSE"), mac("wfRobLaterSE"),
            mac("wfRobAllSE"), mac("wfRobBelowQtySE"),
            mac("wfRobNonSUSSE"), mac("wfRobEarlySE")),
  grp   = c("Deep market", "Deep market", "Deep market", "Baseline",
            "Thin / early", "Thin / early", "Thin / early")
)
fr$label <- factor(fr$label, levels = rev(fr$label))
fr$lo <- fr$coef - 1.96 * fr$se; fr$hi <- fr$coef + 1.96 * fr$se
pal <- c("Deep market" = GREY, "Baseline" = INK, "Thin / early" = INSPER)

p1 <- ggplot(fr, aes(coef, label, colour = grp)) +
  geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.22, linewidth = 0.6) +
  geom_point(size = 2.8) +
  geom_text(aes(label = sprintf("%+.3f", coef)), vjust = -1.1, size = 3.4, show.legend = FALSE) +
  scale_colour_manual(values = pal, name = NULL) +
  labs(x = "Administrative − litigated within-firm coefficient (log price)",
       y = NULL,
       caption = wrap("Within firm-buyer-item triples; 95% CI, PBU-clustered. Positive = administrative dearer. The deep-market null does not extend to the thin/early cells.")) +
  base_theme + theme(legend.position = "top")
ggsave(file.path(OUT, "fig_within_firm_forest_v9.png"), p1, width = 7.6, height = 4.9, dpi = 150, bg = "white")

# ---------------------------------------------------------------------------
# (2) AN-001 : urgent-vs-ordinary coefficients (four outcomes)
# ---------------------------------------------------------------------------
uo <- data.frame(
  label = c("Negotiated price (log)", "Reference price (log)",
            "No. bidders (log)", "Tender success (pp)"),
  coef  = c(mac("negCoef"), mac("refCoef"), mac("firmsCoef"), mac("successCoef")),
  se    = c(mac("negSE"),   mac("refSE"),   mac("firmsSE"),   mac("successSE"))
)
uo$label <- factor(uo$label, levels = rev(uo$label))
uo$lo <- uo$coef - 1.96 * uo$se; uo$hi <- uo$coef + 1.96 * uo$se
uo$dir <- ifelse(uo$coef >= 0, "higher / more", "lower / fewer")

p2 <- ggplot(uo, aes(coef, label)) +
  geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.18, colour = GREY, linewidth = 0.6) +
  geom_point(aes(colour = dir), size = 2.8, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%+.3f", coef)), vjust = -1.1, size = 3.4) +
  scale_colour_manual(values = c("higher / more" = INSPER, "lower / fewer" = INK)) +
  labs(x = "Urgent − ordinary coefficient (item + year + PBU FE)", y = NULL,
       caption = wrap("Log coefficients for price/reference/bidders; pp (LPM) for tender success. 95% CI, PBU-clustered.")) +
  base_theme
ggsave(file.path(OUT, "fig_urgent_coefplot_v9.png"), p2, width = 7.6, height = 3.9, dpi = 150, bg = "white")

# ---------------------------------------------------------------------------
# (3) AN-002 : naive gap vs Lee selection bounds
# ---------------------------------------------------------------------------
naive <- mac("utgPointNaive"); blo <- mac("utgBoundLow"); bhi <- mac("utgBoundHigh")
lee <- data.frame(label = factor(c("Naive estimate", "Selection-bounded (Lee)"),
                                  levels = c("Selection-bounded (Lee)", "Naive estimate")))
p3 <- ggplot() +
  geom_vline(xintercept = 0, colour = "grey70", linetype = "dashed") +
  annotate("segment", x = blo, xend = bhi, y = 1, yend = 1, colour = INSPER, linewidth = 6, alpha = .85) +
  annotate("point", x = naive, y = 2, colour = INK, size = 3.4) +
  annotate("text", x = (blo + bhi) / 2, y = 1, label = sprintf("[%.1f%%, %.1f%%]", blo, bhi),
           vjust = -1.4, size = 3.6, colour = INSPER) +
  annotate("text", x = naive, y = 2, label = sprintf("%.1f%%", naive), vjust = -1.2, size = 3.6, colour = INK) +
  scale_y_continuous(breaks = c(1, 2), labels = c("Selection-bounded (Lee)", "Naive estimate"),
                     limits = c(0.5, 2.6)) +
  labs(x = "Litigated-over-administrative price gap (%)", y = NULL,
       caption = wrap("Lee trimming bounds within item × year × PBU strata. Selection bounds the gap below the naive estimate but leaves it positive.")) +
  base_theme
ggsave(file.path(OUT, "fig_lee_bounds_interval_v9.png"), p3, width = 7.6, height = 3.3, dpi = 150, bg = "white")

# ---------------------------------------------------------------------------
# (4) AN-006 : cross-regime reallocation vs within-regime baseline churn
# ---------------------------------------------------------------------------
ws <- data.frame(
  label = c("Within-regime\nbaseline (placebo)", "Cross-regime\n(litigated vs admin)"),
  jac   = c(mac("wfChurnBaselineJaccard"), mac("winnerSwitchJaccardMean")),
  grp   = c("baseline", "cross")
)
ws$label <- factor(ws$label, levels = ws$label)
p4 <- ggplot(ws, aes(label, jac, fill = grp)) +
  geom_col(width = 0.55, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.3f", jac)), vjust = -0.6, size = 4) +
  scale_fill_manual(values = c("baseline" = GREY, "cross" = INSPER)) +
  scale_y_continuous(limits = c(0, 0.45), expand = expansion(mult = c(0, .08))) +
  labs(x = NULL, y = "Mean winner-set Jaccard similarity",
       caption = wrap(sprintf("Cross-regime overlap (%.3f) falls below within-regime churn (%.3f): reallocation exceeds normal turnover by %.3f.",
                         ws$jac[2], ws$jac[1], ws$jac[1] - ws$jac[2]))) +
  base_theme + theme(panel.grid.major.x = element_blank())
ggsave(file.path(OUT, "fig_winner_churn_v9.png"), p4, width = 6.4, height = 4.0, dpi = 150, bg = "white")

cat("Wrote 4 site figures to", OUT, "\n"); print(list.files(OUT, pattern = "_v9\\.png$"))
