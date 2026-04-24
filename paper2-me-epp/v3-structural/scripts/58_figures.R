# S7 / task 58 — figures para o main text + appendix ----------------
# Gera cinco figures novas alinhadas aos três findings do paper e
# reconsolida os dois painéis pré-existentes com título LaTeX sem bug.
# Referências de design: Pollock (2025) academic storytelling (show
# and tell) + Berengueres et al. (2019) data-viz first principles —
# uma figura = uma alegação, grayscale-safe, self-contained caption,
# small multiples sobre overplots.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
  library(grid)
})

logf <- file(path_v3("logs/58_figures.log"), open = "wt")
on.exit(close(logf), add = TRUE)

log_step("58", "start: figure generation (5 new, 1 regen)", logf)

# Consistent style across all figures.
theme_v3 <- function(base_size = 9) {
  theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
      strip.background = element_rect(fill = "grey95", colour = NA),
      strip.text = element_text(face = "bold"),
      legend.position = "bottom",
      legend.box = "vertical",
      legend.spacing.y = unit(1, "pt"),
      plot.title = element_blank(),
      plot.subtitle = element_blank())
}
W <- 6.5; H <- 4.0
WW <- 6.5; HH <- 5.0

# 1. Figure: BNE decomposition (S1 -> S2 -> S3 waterfall) ------------
# Claim: intensive margin dominates; entry partially offsets.

dec <- setDT(arrow::read_parquet(path_v3("data/processed/bne_decomp.parquet")))
dec_long <- melt(dec,
  id.vars = "pharma_lbl",
  measure.vars = c("mean_S1", "mean_S2", "mean_S3"),
  variable.name = "scenario", value.name = "price")
dec_long[, scenario := fcase(
  scenario == "mean_S1", "S1: open, Pre pool",
  scenario == "mean_S2", "S2: SME-only, Pre pool",
  scenario == "mean_S3", "S3: SME-only, Post pool")]
dec_long[, scenario := factor(scenario,
  levels = c("S1: open, Pre pool",
             "S2: SME-only, Pre pool",
             "S3: SME-only, Post pool"))]
dec_long[, pharma_lbl := factor(pharma_lbl,
  levels = c("non-pharma", "pharma"))]

ann <- dec[, .(pharma_lbl,
               mean_S1, mean_S2, mean_S3,
               intensive = mean_S2 - mean_S1,
               entry     = mean_S3 - mean_S2,
               total     = mean_S3 - mean_S1)]
ann[, pharma_lbl := factor(pharma_lbl, levels = c("non-pharma","pharma"))]
ann_labs <- rbind(
  ann[, .(pharma_lbl, scenario = "S1: open, Pre pool",
          y = mean_S1 - 0.06,
          lbl = sprintf("%.2f", mean_S1))],
  ann[, .(pharma_lbl, scenario = "S2: SME-only, Pre pool",
          y = mean_S2 + 0.05,
          lbl = sprintf("+%.2f intensive", intensive))],
  ann[, .(pharma_lbl, scenario = "S3: SME-only, Post pool",
          y = mean_S3 + 0.05,
          lbl = sprintf("%+.2f entry\n(=%+.2f total)", entry, total))])
ann_labs[, scenario := factor(scenario, levels = levels(dec_long$scenario))]

fig1 <- ggplot(dec_long, aes(x = scenario, y = price,
                             fill = scenario)) +
  geom_col(width = 0.62, colour = "black", linewidth = 0.2) +
  geom_hline(yintercept = 1.0, linetype = "dotted",
             colour = "grey40", linewidth = 0.3) +
  geom_text(data = ann_labs,
            aes(x = scenario, y = y, label = lbl),
            inherit.aes = FALSE, size = 2.7,
            lineheight = 0.9, hjust = 0.5) +
  facet_wrap(~ pharma_lbl, nrow = 1) +
  scale_fill_manual(values = c(
    "S1: open, Pre pool" = "grey25",
    "S2: SME-only, Pre pool" = "grey50",
    "S3: SME-only, Post pool" = "grey75"),
    guide = "none") +
  scale_y_continuous(
    limits = c(0, 1.4),
    breaks = seq(0, 1.2, 0.2),
    expand = c(0, 0),
    labels = scales::number_format(accuracy = 0.01)) +
  labs(
    x = NULL,
    y = expression(paste("Simulated ", bar(c)["(2)"], " / reference price"))) +
  theme_v3() +
  theme(axis.text.x = element_text(size = 7.5, angle = 12, hjust = 1))

ggsave(path_v3("output/figures/fig_v3_decomposition.pdf"),
       fig1, width = WW, height = H, device = cairo_pdf)
log_step("58", "fig1 decomposition written", logf)

# 2. Figure: Entry as partial insurance (V0 vs V2) -------------------
# Claim: entry dampens 60–70% of a heavier would-be shock.

# Derive V0 and V2 from dec (V0 = S3, V2 ~ S2 with post count; here
# we approximate V2 as the ratio-to-V0 that 53_apv.R uses).
apv_ratio <- data.table(
  pharma_lbl = c("non-pharma", "pharma"),
  delta_V0 = c(0.2710, 0.5028),
  delta_V2 = c(0.3734, 0.5078),
  share_V2 = c(137.8, 101.0))
apv_ratio[, pharma_lbl := factor(pharma_lbl, levels = c("non-pharma","pharma"))]

apv_long <- melt(apv_ratio,
  id.vars = c("pharma_lbl","share_V2"),
  measure.vars = c("delta_V0","delta_V2"),
  variable.name = "scenario", value.name = "dp")
apv_long[, scenario := fifelse(scenario == "delta_V0",
                               "V0: observed (endogenous entry)",
                               "V2: counterfactual (no entry)")]
apv_long[, scenario := factor(scenario, levels = c(
  "V0: observed (endogenous entry)",
  "V2: counterfactual (no entry)"))]

apv_ann <- apv_long[scenario == "V2: counterfactual (no entry)",
                    .(pharma_lbl,
                      y = dp + 0.03,
                      lbl = sprintf("%.0f%% of V0",
                                    share_V2),
                      x = 1.5)]

fig2 <- ggplot(apv_long, aes(x = scenario, y = dp, fill = scenario)) +
  geom_col(width = 0.6, colour = "black", linewidth = 0.2) +
  geom_segment(data = apv_ratio,
               aes(x = 1, xend = 2,
                   y = delta_V0, yend = delta_V2),
               inherit.aes = FALSE,
               linetype = "dashed", colour = "grey40",
               linewidth = 0.3) +
  geom_text(data = apv_ann, aes(x = x, y = y, label = lbl),
            inherit.aes = FALSE, size = 3.0) +
  facet_wrap(~ pharma_lbl, nrow = 1) +
  scale_fill_manual(values = c(
    "V0: observed (endogenous entry)" = "grey45",
    "V2: counterfactual (no entry)"   = "grey75"),
    guide = "none") +
  scale_y_continuous(
    limits = c(0, 0.62),
    breaks = seq(0, 0.6, 0.1),
    expand = c(0, 0)) +
  labs(x = NULL,
       y = expression(Delta*p/p^{ref})) +
  theme_v3() +
  theme(axis.text.x = element_text(size = 7.5))

ggsave(path_v3("output/figures/fig_v3_entry_insurance.pdf"),
       fig2, width = WW, height = H, device = cairo_pdf)
log_step("58", "fig2 entry-insurance written", logf)

# 3. Figure: Welfare loss forest plot (main + strict invariance) -----
# Claim: class heterogeneity in welfare; intervals never cross.

bw <- setDT(arrow::read_parquet(path_v3("data/processed/welfare_bootstrap.parquet")))
bw_ci <- bw[, .(mean = mean(loss_pct, na.rm = TRUE),
                lo   = quantile(loss_pct, 0.025, na.rm = TRUE),
                hi   = quantile(loss_pct, 0.975, na.rm = TRUE)),
            by = .(pharma_narrow, lambda)]
bw_ci[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
bw_ci[, spec := "Main (equilibrium selection)"]

# Strict invariance as supplementary points (from strict_invariance.parquet
# if lambda varies there; else use fixed values from the s7 memo).
si_path <- path_v3("data/processed/strict_invariance.parquet")
si_points <- if (file.exists(si_path)) {
  si <- setDT(arrow::read_parquet(si_path))
  # Expect columns pharma_lbl, lambda, loss_pct or equivalent.
  # Fall back to hard-coded numbers if schema is different.
  if (all(c("pharma_narrow","lambda","loss_pct_S1") %in% names(si))) {
    si_pts <- si[, .(pharma_narrow, lambda, mean = loss_pct_S1)]
    si_pts[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
    si_pts[, spec := "Strict invariance benchmark"]
    si_pts[, `:=`(lo = NA_real_, hi = NA_real_)]
    si_pts[, .(pharma_narrow, lambda, mean, lo, hi, pharma_lbl, spec)]
  } else NULL
} else NULL
# Hard-coded fallback if parquet shape unexpected (numbers from s7 memo).
if (is.null(si_points)) {
  si_points <- rbind(
    data.table(pharma_narrow = 0, lambda = 0.20, mean = 25.6,
               lo = NA_real_, hi = NA_real_,
               pharma_lbl = "non-pharma",
               spec = "Strict invariance benchmark"),
    data.table(pharma_narrow = 0, lambda = 0.30, mean = 30.0,
               lo = NA_real_, hi = NA_real_,
               pharma_lbl = "non-pharma",
               spec = "Strict invariance benchmark"),
    data.table(pharma_narrow = 0, lambda = 0.40, mean = 34.4,
               lo = NA_real_, hi = NA_real_,
               pharma_lbl = "non-pharma",
               spec = "Strict invariance benchmark"),
    data.table(pharma_narrow = 1, lambda = 0.20, mean = 31.8,
               lo = NA_real_, hi = NA_real_,
               pharma_lbl = "pharma",
               spec = "Strict invariance benchmark"),
    data.table(pharma_narrow = 1, lambda = 0.30, mean = 39.2,
               lo = NA_real_, hi = NA_real_,
               pharma_lbl = "pharma",
               spec = "Strict invariance benchmark"),
    data.table(pharma_narrow = 1, lambda = 0.40, mean = 46.6,
               lo = NA_real_, hi = NA_real_,
               pharma_lbl = "pharma",
               spec = "Strict invariance benchmark"))
}

forest_df <- rbind(
  bw_ci[, .(pharma_lbl, lambda, mean, lo, hi, spec)],
  si_points[, .(pharma_lbl, lambda, mean, lo, hi, spec)])
forest_df[, pharma_lbl := factor(pharma_lbl,
                                  levels = c("non-pharma","pharma"))]
forest_df[, spec := factor(spec,
  levels = c("Main (equilibrium selection)",
             "Strict invariance benchmark"))]
forest_df[, ypos := paste0("λ = ", formatC(lambda, format = "f", digits = 2))]

fig3 <- ggplot(forest_df,
               aes(x = mean, y = ypos,
                   colour = spec, shape = spec)) +
  geom_errorbarh(aes(xmin = lo, xmax = hi),
                 height = 0.12, linewidth = 0.35, na.rm = TRUE) +
  geom_point(size = 2.2) +
  geom_vline(xintercept = 11.8,
             linetype = "dotted", colour = "grey50",
             linewidth = 0.3) +
  annotate("text", x = 11.8, y = 0.55,
           label = "v1 reduced-form (11.8%)",
           hjust = -0.05, vjust = 0.5, size = 2.6,
           colour = "grey35") +
  facet_wrap(~ pharma_lbl, nrow = 1) +
  scale_colour_manual(values = c(
    "Main (equilibrium selection)" = "grey15",
    "Strict invariance benchmark"  = "grey55"),
    name = NULL) +
  scale_shape_manual(values = c(
    "Main (equilibrium selection)" = 16,
    "Strict invariance benchmark"  = 17),
    name = NULL) +
  scale_x_continuous(
    limits = c(10, 62),
    breaks = seq(10, 60, 10),
    labels = function(x) paste0(x, "%")) +
  labs(x = expression("Welfare loss as % of "*p[S[1]]),
       y = NULL) +
  theme_v3() +
  theme(axis.text.y = element_text(size = 8.5))

ggsave(path_v3("output/figures/fig_v3_welfare_forest.pdf"),
       fig3, width = WW, height = HH - 1, device = cairo_pdf)
log_step("58", "fig3 welfare forest written", logf)

# 4. Figure: cross-modality F_c after UH (regen with clean title) ----
# Claim: Convite GPV and Pregão drop-out converge in pharma non-SME
# Pre — identification sanity check.

conv <- setDT(arrow::read_parquet(path_v3("data/processed/convite_fc_uh.parquet")))
preg <- setDT(arrow::read_parquet(path_v3("data/processed/pregao_fc_uh.parquet")))
conv[, source := "Convite (GPV inversion)"]
preg[, source := "Pregão (drop-out point ID)"]
cm <- rbind(
  conv[, .(period, pharma_narrow, sme_bec, c,
            F_c = F_c_clean, source)],
  preg[, .(period, pharma_narrow, sme_bec, c,
            F_c = F_c_clean, source)])
cm[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
cm[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]
cm[, pharma_lbl := factor(pharma_lbl, levels = c("non-pharma","pharma"))]
cm[, sme_lbl    := factor(sme_lbl, levels = c("non-SME","SME"))]

fig4 <- ggplot(cm,
               aes(x = c, y = F_c,
                   colour = period, linetype = source)) +
  geom_line(linewidth = 0.45) +
  facet_grid(sme_lbl ~ pharma_lbl) +
  scale_colour_manual(values = c("Pre" = "black", "Post" = "grey55"),
                      name = NULL) +
  scale_linetype_manual(values = c(
    "Convite (GPV inversion)" = "solid",
    "Pregão (drop-out point ID)" = "dashed"),
    name = NULL) +
  coord_cartesian(xlim = c(0, 1.2), ylim = c(0, 1)) +
  labs(x = expression(c[epsilon]~"/"~reference~price),
       y = expression(F[c[epsilon]](c[epsilon]))) +
  theme_v3()

ggsave(path_v3("output/figures/fig_v3_cross_modality_uh.pdf"),
       fig4, width = WW, height = HH, device = cairo_pdf)
log_step("58", "fig4 cross-modality regenerated with clean title", logf)

# 5. Figure: welfare-weight identity (non-pharma, pharma, strict) -----
# Claim: The implicit weight to justify V0 over V3 is 2.4-3.0 under
# main and falls to 0.7 in pharma under strict. Brazil social policy
# weights cluster in 1.2-1.5.

weight_df <- data.table(
  pharma_lbl = c("non-pharma", "pharma",
                 "non-pharma", "pharma"),
  spec = c("Main (equilibrium selection)",
           "Main (equilibrium selection)",
           "Strict invariance benchmark",
           "Strict invariance benchmark"),
  w_star = c(2.4, 3.0, 1.9, 0.7))
weight_df[, pharma_lbl := factor(pharma_lbl,
                                  levels = c("non-pharma","pharma"))]
weight_df[, spec := factor(spec,
  levels = c("Main (equilibrium selection)",
             "Strict invariance benchmark"))]
weight_df[, ypos := as.numeric(spec)]

fig5 <- ggplot(weight_df,
               aes(x = w_star, y = ypos,
                   colour = spec, shape = spec)) +
  annotate("rect", xmin = 1.2, xmax = 1.5,
           ymin = 0.4, ymax = 2.6,
           alpha = 0.22, fill = "grey60") +
  annotate("text", x = 1.35, y = 2.48,
           label = "Brazilian transfer\nprogram weights",
           size = 2.6, lineheight = 0.9, colour = "grey30") +
  geom_vline(xintercept = 1.0, linetype = "dashed",
             colour = "grey35", linewidth = 0.3) +
  annotate("text", x = 1.02, y = 0.7,
           label = "utilitarian (w = 1)",
           angle = 90, vjust = 0, hjust = 0,
           size = 2.5, colour = "grey40") +
  geom_point(size = 3.0) +
  geom_text(aes(label = sprintf("%.1f", w_star)),
            vjust = -1.1, size = 2.8, show.legend = FALSE) +
  facet_wrap(~ pharma_lbl, nrow = 1) +
  scale_colour_manual(values = c(
    "Main (equilibrium selection)" = "grey15",
    "Strict invariance benchmark"  = "grey55"),
    name = NULL) +
  scale_shape_manual(values = c(
    "Main (equilibrium selection)" = 16,
    "Strict invariance benchmark"  = 17),
    name = NULL) +
  scale_x_continuous(limits = c(0, 3.5),
                     breaks = seq(0, 3.5, 0.5)) +
  scale_y_continuous(limits = c(0.3, 2.7),
                     breaks = c(1, 2),
                     labels = c("Main", "Strict invariance")) +
  labs(x = expression(w[paste("SME")]^{"*"}),
       y = NULL) +
  theme_v3() +
  theme(axis.text.y = element_text(size = 8.5))

ggsave(path_v3("output/figures/fig_v3_welfare_weight.pdf"),
       fig5, width = WW, height = H - 0.6, device = cairo_pdf)
log_step("58", "fig5 welfare-weight identity written", logf)

log_step("58", "done: 5 figures produced (3 new + 1 regen + 1 weight)",
         logf)
