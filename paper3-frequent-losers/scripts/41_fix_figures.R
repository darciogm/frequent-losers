# ============================================================================
# 41_fix_figures.R — regenerate 3 figures with disciplined subtitles
# Paper 3 v14 / Path A+ Action (cosmetic cleanup)
#
# Source figures had subtitles that contradicted the CLAUDE.md disciplinary
# language (CO-AUTHOR EDIT 2026-04-30). This script regenerates them from
# the same CSVs the original scripts produced, with corrected subtitles.
#
# Targets:
#   output/first_time_fl_matching/fig_matching.pdf   (from script 30)
#   output/imhof_full/fig_imhof_comparison.pdf       (from script 31)
#   output/auc_direct_cade/fig_auc_direct_cade.pdf   (from script 33)
# ============================================================================

cat("=== 41_fix_figures.R: regenerate 3 figures with disciplined subtitles ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(data.table); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)

# ---- Figure 1: matched first-time-FL ------------------------------------
m_path <- file.path(BASE, "output/first_time_fl_matching/matched_results.csv")
if (file.exists(m_path)) {
  m <- fread(m_path)
  m[, ci_lo := coef - 1.96 * se]
  m[, ci_hi := coef + 1.96 * se]
  m[, spec_label := fcase(
    spec == "unconditional", "Unconditional\n(item × year FE)",
    spec == "cem_matched",   "CEM matched\n(item × year × modality)",
    spec == "ps_matched",    "PS matched\n(propensity score on log winner)"
  )]
  m[, spec_label := factor(spec_label,
                            levels = c("Unconditional\n(item × year FE)",
                                        "CEM matched\n(item × year × modality)",
                                        "PS matched\n(propensity score on log winner)"))]

  p <- ggplot(m, aes(x = spec_label, y = coef)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray60") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15) +
    geom_point(size = 4, color = "#d73027") +
    geom_text(aes(label = sprintf("%+.3f (p=%.2f)", coef, pval)),
              vjust = -1.5, size = 3.5) +
    labs(x = NULL,
         y = "FL coefficient on log(bid / winner) at first tender",
         title = "First-tender FL premium attenuates under matching on observables",
         subtitle = sprintf(
           "Unconditional %+.2f → CEM %+.2f → PS-matched %+.2f (n.s.); sample trimmed at |log(b/w)| ≤ 5",
           m$coef[m$spec=="unconditional"],
           m$coef[m$spec=="cem_matched"],
           m$coef[m$spec=="ps_matched"])) +
    theme_bw()

  ggsave(file.path(BASE, "output/first_time_fl_matching/fig_matching.pdf"),
         p, width = 7.5, height = 5, device = cairo_pdf)
  cat("  Wrote: output/first_time_fl_matching/fig_matching.pdf\n")
}

# ---- Figure 2: Imhof comparison -----------------------------------------
i_path <- file.path(BASE, "output/imhof_full/imhof_full_results.csv")
if (file.exists(i_path)) {
  ir <- fread(i_path)
  ir[, model_label := fcase(
    model == "fl_alone",                "FL flag alone (binary, participation-only)",
    model == "tenders_alone",           "log(1+tenders_count) (continuous, participation-only)",
    model == "imhof_cv_only",           "Imhof CV only (v13 strawman)",
    model == "imhof_full",              "Imhof FULL pipeline (5 within-tender features)",
    model == "imhof_full_plus_fl",      "FL flag + Imhof FULL (combined)",
    model == "imhof_full_plus_tenders", "log(1+tenders) + Imhof FULL (combined)"
  )]
  ir[, model_label := factor(model_label, levels = rev(c(
    "Imhof CV only (v13 strawman)",
    "Imhof FULL pipeline (5 within-tender features)",
    "FL flag alone (binary, participation-only)",
    "log(1+tenders_count) (continuous, participation-only)",
    "FL flag + Imhof FULL (combined)",
    "log(1+tenders) + Imhof FULL (combined)"
  )))]
  ir[, family := fcase(
    grepl("Imhof CV|Imhof FULL pipeline", model_label, fixed = FALSE), "Bid-distribution",
    grepl("FL flag alone|tenders_count\\) \\(", model_label),           "Participation-only",
    default = "Combined"
  )]

  p <- ggplot(ir, aes(y = model_label, x = auc, color = family)) +
    geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray60") +
    geom_vline(xintercept = 0.85, linetype = "dashed", color = "gray60") +
    geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.15,
                   orientation = "y") +
    geom_point(size = 3.5) +
    geom_text(aes(label = sprintf("%.3f", auc)), vjust = -1.4, size = 3.3) +
    scale_color_manual(values = c("Bid-distribution" = "#5b8aa6",
                                   "Participation-only" = "#d73027",
                                   "Combined" = "#762a83")) +
    scale_x_continuous(limits = c(0.5, 1.0), breaks = seq(0.5, 1, 0.1)) +
    labs(x = "AUC against 193 CADE-cobidder labels (5-fold CV)",
         y = NULL,
         title = "Loser-side concentration vs full Imhof–Wallimann pipeline",
         subtitle = "Comparable AUC at different data costs; combination gains 5–7 points (95% CIs overlap pairwise within data-envelope class)",
         color = "Data envelope") +
    theme_bw() + theme(legend.position = "bottom")

  ggsave(file.path(BASE, "output/imhof_full/fig_imhof_comparison.pdf"),
         p, width = 10, height = 5.2, device = cairo_pdf)
  cat("  Wrote: output/imhof_full/fig_imhof_comparison.pdf\n")
}

# ---- Figure 3: AUC against direct CADE ----------------------------------
a_path <- file.path(BASE, "output/auc_direct_cade/auc_direct_cade.csv")
if (file.exists(a_path)) {
  ar <- fread(a_path)
  ar[, label_short := fcase(
    label == "all_direct_CADE",                "Direct CADE (all 47, BEC universe)",
    label == "post2019_direct_CADE",           "Direct CADE post-2019 (BEC universe)",
    label == "pre2020_direct_CADE",            "Direct CADE pre-2020 (BEC universe)",
    label == "AL_direct_CADE",                 "Direct CADE ∩ always-loser (n=7)",
    label == "AL_direct_post2019_CADE_strict", "Direct CADE ∩ AL post-2019 (n=5)",
    label == "AL_193_cobidders_v13",           "193 cobidders (always-loser pool)"
  )]
  ar[, label_short := factor(label_short, levels = c(
    "193 cobidders (always-loser pool)",
    "Direct CADE ∩ always-loser (n=7)",
    "Direct CADE ∩ AL post-2019 (n=5)",
    "Direct CADE (all 47, BEC universe)",
    "Direct CADE pre-2020 (BEC universe)",
    "Direct CADE post-2019 (BEC universe)"
  ))]

  p <- ggplot(ar, aes(y = label_short, x = auc, color = score, shape = score)) +
    geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray60") +
    geom_vline(xintercept = 0.85, linetype = "dashed", color = "gray60") +
    geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.15,
                   orientation = "y",
                   position = position_dodge(width = 0.4)) +
    geom_point(size = 3, position = position_dodge(width = 0.4)) +
    geom_text(aes(label = sprintf("%.3f", auc)), vjust = -1.0, size = 3,
              position = position_dodge(width = 0.4)) +
    scale_color_manual(values = c("is_fl" = "#d73027",
                                   "tenders_count" = "#5b8aa6")) +
    scale_x_continuous(limits = c(0.3, 1.0), breaks = seq(0.3, 1, 0.1)) +
    labs(x = "AUC against CADE ground truth (with 95% CI)",
         y = NULL,
         title = "Structural scope of the screen: cobidders vs direct CADE defendants",
         subtitle = "AUC 0.91 against 193 cobidders (always-loser pool); AUC 0.49 against 47 direct defendants (BEC universe). The screen targets the loser-side of the bidding pool by construction.",
         color = "Score", shape = "Score") +
    theme_bw() + theme(legend.position = "bottom")

  ggsave(file.path(BASE, "output/auc_direct_cade/fig_auc_direct_cade.pdf"),
         p, width = 10.5, height = 5.5, device = cairo_pdf)
  cat("  Wrote: output/auc_direct_cade/fig_auc_direct_cade.pdf\n")
}

cat("\n  Done.\n")
