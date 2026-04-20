# ============================================================================
# 43_pregao_typesplit_ht.R — Sprint 12: type-split HT bounds for Pregão G65
# ============================================================================
# Sprint 6 (37_pregao_htbounds.R) delivered AGGREGATE HT bounds on F_c in
# Pregão G65. This sprint extends to TYPE-SPECIFIC bounds (F_c^SME and
# F_c^NonSME) and delivers the Pregão counterpart to the Convite CPV
# asymmetric analysis.
#
# Identification strategy:
#   Under individual rationality (H1), each bidder's final bid is at or
#   above their cost:
#         b_it >= c_it
#   Taking the CDF:
#         F_c^type(c) = Pr(c <= c | type) <= Pr(b <= c | type) = G_b^type(c)
#   So the empirical CDF of final bids of type k gives a POINTWISE UPPER
#   BOUND on the cost CDF of type k. This is ONE-SIDED but directly
#   interpretable and requires only H1 (no auxiliary equilibrium
#   assumptions).
#
#   For type-asymmetric auctions with soft-close and observable bid trail,
#   a tighter two-sided bound is available via H2 (Haile-Tamer 2003 +
#   extension to asymmetric). That extension is deferred to future work;
#   the one-sided bound suffices for the primitive-invariance test (which
#   is the paper's core identification check).
#
# Primitive-invariance test (type k):
#   Under the model, F_c^k is primitive and invariant across the regime
#   break. The UPPER BOUNDS G_b^k_Pre and G_b^k_Post should also be close
#   (same model, same truncation of bids at c). Large divergence =>
#   either F_c^k changed (entry/exit of marginal firms) or the upper
#   bound's slackness varies across regimes.
#
# Outputs:
#   output/tables/tab_v2_ht_typesplit.csv         — per-type per-period stats
#   output/tables/tab_v2_ht_typesplit_ks.csv      — KS tests of invariance
#   output/figures/fig_v2_ht_typesplit_pre.pdf    — G_b bounds at Pre
#   output/figures/fig_v2_ht_typesplit_stability.pdf  — Pre vs Post by type
#   output/figures/fig_v2_ht_vs_cpv_types.pdf     — Pregão HT vs Convite CPV
#   logs/43_pregao_typesplit_ht.log
# ============================================================================

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils_v2.R"), local = TRUE)

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(ggplot2)
  library(scales)
})

setDTthreads(12)
log_msg("=== 43_pregao_typesplit_ht.R — type-split HT bounds ===")
log_mem("startup")

theme_pub <- function() {
  theme_bw(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
          strip.background = element_rect(fill = "grey95", color = "black",
                                          linewidth = 0.3),
          legend.position = "bottom", legend.title = element_blank(),
          plot.title = element_text(size = 10, face = "bold"))
}
save_pub <- function(p, fn, w = 7.0, h = 4.0) {
  ggsave(file.path(V2_FIGS, fn), p, width = w, height = h, device = cairo_pdf)
  log_msg("  saved ", fn)
}

# ============================================================================
# 1. LOAD PREGÃO G65 AND COLLAPSE TO FIRM-AUCTION FINAL BIDS
# ============================================================================
log_msg("Loading Pregão G65 bid-level data...")
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_pregao.parquet")))
bl <- bl[g65 == 1L]

# Data-structure note: in the source bid_level_with_prices.parquet,
# ref_price is populated only on the WINNER row of each auction (losers
# carry NaN). Propagate the winner's ref_price to all rows of the same
# auction before the collapse.
log_msg("Propagating ref_price from winner row to all bidders per auction...")
au_ref <- bl[, .(ref_auc = max(ref_price, na.rm = TRUE)),
             by = .(numerodaoc, codigoitem)]
au_ref[is.infinite(ref_auc), ref_auc := NA_real_]
bl <- merge(bl, au_ref, by = c("numerodaoc", "codigoitem"))
log_msg(sprintf("  auctions with non-NA ref after propagation: %s / %s (%.1f%%)",
                format(sum(!is.na(unique(bl[, .(numerodaoc, codigoitem, ref_auc)])$ref_auc)),
                       big.mark = ","),
                format(nrow(unique(bl[, .(numerodaoc, codigoitem)])), big.mark = ","),
                100 * mean(!is.na(unique(bl[, .(numerodaoc, codigoitem, ref_auc)])$ref_auc))))

# Final bid per firm per auction: use MIN bid (= firm's final willingness
# to go below). Simpler than trimming; outliers (R$0.01 placeholders) are
# handled by the b_norm > 0.01 filter downstream.
fa <- bl[, .(
    bid_final = min(bid_price, na.rm = TRUE),
    won       = max(won, na.rm = TRUE),
    sme       = max(sme_proxy, na.rm = TRUE),
    ref       = first(ref_auc)   # propagated auction-level ref
  ), by = .(numerodaoc, codigoitem, codigofornecedor, Pre, pharma)]

fa[, b_norm := bid_final / ref]

n0 <- nrow(fa)
fa <- fa[is.finite(bid_final) & bid_final > 0 &
         is.finite(ref) & ref > 0 &
         b_norm > 0.01 & b_norm < 2]
log_msg(sprintf("  firm-auction final bids (propagated ref): %s (dropped %.1f%%)",
                format(nrow(fa), big.mark = ","),
                100 * (1 - nrow(fa) / n0)))

# Period and type labels
fa[, period_lbl := fifelse(Pre == 1L, "Pre", "Post")]
fa[, sme_lbl    := fifelse(sme  == 1L, "SME", "NonSME")]

# N per auction (for reporting)
au <- fa[, .(N = .N), by = .(numerodaoc, codigoitem)]
fa <- merge(fa, au, by = c("numerodaoc", "codigoitem"))
fa <- fa[N >= 2L]

# Summary
cell_summary <- fa[, .(
    n_bidders = .N,
    n_auctions = uniqueN(paste(numerodaoc, codigoitem)),
    mean_b  = round(mean(b_norm), 4),
    median_b = round(median(b_norm), 4)
  ), by = .(period_lbl, sme_lbl)][order(period_lbl, sme_lbl)]
log_msg("Per cell summary (Pregão G65 final bids):")
print(cell_summary)

# ============================================================================
# 2. UPPER BOUND ON F_c^type VIA H1 (b >= c)
# ============================================================================
# F_c^type_UB(c) = G_b^type(c), empirical CDF of final bids of type k
# Evaluated on a common grid

grid_c <- seq(0.005, 1.5, length.out = 500)
ecdf_on_grid <- function(x) {
  if (length(x) < 20) return(rep(NA_real_, length(grid_c)))
  ec <- ecdf(x)
  ec(grid_c)
}

bounds <- list()
for (per in c("Pre", "Post")) {
  for (typ in c("SME", "NonSME")) {
    sub <- fa[period_lbl == per & sme_lbl == typ, b_norm]
    Fc_UB <- ecdf_on_grid(sub)
    bounds[[paste(per, typ, sep = "/")]] <- data.table(
      period_lbl = per,
      sme_lbl    = typ,
      c_grid     = grid_c,
      Fc_UB      = Fc_UB,
      n_bidders  = length(sub)
    )
  }
}
bounds_tab <- rbindlist(bounds, use.names = TRUE)

# ============================================================================
# 3. PRIMITIVE-INVARIANCE TEST (PRE vs POST) PER TYPE
# ============================================================================
log_msg("")
log_msg("Primitive-invariance test (KS) of F_c^type_UB across Pre/Post:")

ks_tests <- list()
for (typ in c("SME", "NonSME")) {
  b_pre  <- fa[period_lbl == "Pre"  & sme_lbl == typ, b_norm]
  b_post <- fa[period_lbl == "Post" & sme_lbl == typ, b_norm]
  if (length(b_pre) < 100 || length(b_post) < 100) next
  ks <- suppressWarnings(ks.test(b_pre, b_post))
  ks_tests[[typ]] <- data.table(
    type = typ,
    n_pre = length(b_pre),
    n_post = length(b_post),
    mean_pre = round(mean(b_pre), 4),
    mean_post = round(mean(b_post), 4),
    shift = round(mean(b_post) - mean(b_pre), 4),
    shift_pct = round(100 * (mean(b_post) - mean(b_pre)) / mean(b_pre), 1),
    KS_D = round(unname(ks$statistic), 3),
    KS_p = signif(unname(ks$p.value), 3)
  )
}
ks_tab <- rbindlist(ks_tests, use.names = TRUE)
print(ks_tab)
fwrite(ks_tab, file.path(V2_TABLES, "tab_v2_ht_typesplit_ks.csv"))

# ============================================================================
# 4. FIGURES
# ============================================================================
# Figure 1: G_b^type (= F_c^type upper bound) at Pre period
fig_pre <- ggplot(bounds_tab[period_lbl == "Pre" & !is.na(Fc_UB)],
                  aes(x = c_grid, y = Fc_UB,
                      color = sme_lbl, linetype = sme_lbl)) +
  geom_line(linewidth = 0.6) +
  scale_color_manual(values = c("SME" = "black", "NonSME" = "grey40")) +
  scale_linetype_manual(values = c("SME" = "solid", "NonSME" = "dashed")) +
  coord_cartesian(xlim = c(0, 1.2)) +
  scale_x_continuous(labels = percent_format()) +
  labs(x = "Cost / reference price",
       y = "Upper bound on F(c)",
       title = "Pregão G65 — type-specific upper bound on F_c at Pre",
       subtitle = "Empirical CDF of final bids by type (upper bound under H1: b >= c)") +
  theme_pub()
save_pub(fig_pre, "fig_v2_ht_typesplit_pre.pdf", w = 7.0, h = 4.0)

# Figure 2: Pre vs Post by type (primitive invariance visual)
fig_stab <- ggplot(bounds_tab[!is.na(Fc_UB)],
                   aes(x = c_grid, y = Fc_UB,
                       color = period_lbl, linetype = period_lbl)) +
  geom_line(linewidth = 0.6) +
  facet_wrap(~ sme_lbl) +
  scale_color_manual(values = c("Pre" = "grey20", "Post" = "grey60")) +
  scale_linetype_manual(values = c("Pre" = "solid", "Post" = "dashed")) +
  coord_cartesian(xlim = c(0, 1.2)) +
  scale_x_continuous(labels = percent_format()) +
  labs(x = "Cost / reference price",
       y = "Upper bound on F(c)",
       title = "Pregão G65 — primitive-invariance check by type",
       subtitle = "Under the model, within-type upper bound on F_c should be invariant across regimes") +
  theme_pub()
save_pub(fig_stab, "fig_v2_ht_typesplit_stability.pdf", w = 7.5, h = 4.0)

# ============================================================================
# 5. COMPARISON WITH CONVITE CPV (cross-modality validation)
# ============================================================================
if (file.exists(file.path(V2_DATA, "convite_cpv_costs.parquet"))) {
  conv <- as.data.table(read_parquet(file.path(V2_DATA, "convite_cpv_costs.parquet")))
  conv <- conv[is.finite(c_norm) & c_norm > 0.001 & c_norm < 1.5]

  # Convite point estimate CDFs
  conv_ecdf <- list()
  for (per in c("Pre", "Post")) {
    for (typ in c("SME", "NonSME")) {
      c_vals <- conv[period_lbl == per & sme_lbl == typ, c_norm]
      if (length(c_vals) < 50) next
      ec <- ecdf(c_vals)
      conv_ecdf[[paste(per, typ, sep = "/")]] <- data.table(
        modality = "Convite (CPV point)",
        period_lbl = per,
        sme_lbl    = typ,
        c_grid     = grid_c,
        Fc         = ec(grid_c)
      )
    }
  }
  conv_tab <- rbindlist(conv_ecdf, use.names = TRUE)

  pregao_tab <- bounds_tab[!is.na(Fc_UB),
                           .(modality = "Pregão (HT upper bound)",
                             period_lbl, sme_lbl, c_grid, Fc = Fc_UB)]

  combined <- rbind(conv_tab, pregao_tab, use.names = TRUE)

  # Plot: both modalities side by side, facet on period × type
  fig_cross <- ggplot(combined[period_lbl == "Pre"],
                      aes(x = c_grid, y = Fc,
                          color = modality, linetype = modality)) +
    geom_line(linewidth = 0.5) +
    facet_wrap(~ sme_lbl) +
    scale_color_manual(values = c("Convite (CPV point)"   = "black",
                                  "Pregão (HT upper bound)" = "grey40")) +
    scale_linetype_manual(values = c("Convite (CPV point)"   = "solid",
                                     "Pregão (HT upper bound)" = "dashed")) +
    coord_cartesian(xlim = c(0, 1.2)) +
    scale_x_continuous(labels = percent_format()) +
    labs(x = "Cost / reference price",
         y = "F(c)",
         title = "Cross-modality validation at Pre: Convite CPV point vs Pregão HT upper bound",
         subtitle = "Under common structural primitives, HT upper bound should LIE ABOVE CPV point (cost <= bid)") +
    theme_pub()
  save_pub(fig_cross, "fig_v2_ht_vs_cpv_types.pdf", w = 7.5, h = 4.0)
}

# ============================================================================
# 6. SUMMARY TABLE FOR MANUSCRIPT
# ============================================================================
mean_bids <- fa[, .(
    n_bidders = .N,
    mean_b    = round(mean(b_norm), 4),
    median_b  = round(median(b_norm), 4)
  ), by = .(period_lbl, sme_lbl)][order(period_lbl, sme_lbl)]

fwrite(mean_bids, file.path(V2_TABLES, "tab_v2_ht_typesplit.csv"))
log_msg("Per-cell means (final bids, normalized):")
print(mean_bids)

# LaTeX table: type-split HT headline
sink(file.path(V2_TABLES, "tab_v2_ht_typesplit.tex"))
cat("% Auto-generated by 43_pregao_typesplit_ht.R\n")
cat("\\begin{tabular}{llrrr}\n\\toprule\n")
cat("Period & Type & $n$ bidders & Mean $b/ref$ & KS Pre vs Post \\\\\n\\midrule\n")
for (i in seq_len(nrow(mean_bids))) {
  row_i <- mean_bids[i]
  per_i <- as.character(row_i$period_lbl)
  typ_i <- as.character(row_i$sme_lbl)
  n_i   <- row_i$n_bidders
  mb_i  <- row_i$mean_b
  if (nrow(ks_tab) > 0 && per_i == "Post") {
    ks_row <- ks_tab[type == typ_i]
    ks_entry <- if (nrow(ks_row) > 0) {
      sprintf("$D=%.3f$, $p=%.2g$", ks_row$KS_D[1], ks_row$KS_p[1])
    } else "--"
  } else {
    ks_entry <- "--"
  }
  cat(per_i, "&", typ_i, "&",
      format(n_i, big.mark = ","), "&",
      sprintf("%.3f", mb_i), "&",
      ks_entry, "\\\\\n")
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()

# ============================================================================
# 7. INTERPRETATION
# ============================================================================
log_msg("")
log_msg("=================================================================")
log_msg("INTERPRETATION:")
log_msg("=================================================================")
for (typ in c("SME", "NonSME")) {
  if (!typ %in% ks_tab$type) next
  row <- ks_tab[type == typ]
  log_msg(sprintf("  %s:", typ))
  log_msg(sprintf("    Pre  mean b/ref = %.4f (n = %s)",
                  row$mean_pre, format(row$n_pre, big.mark = ",")))
  log_msg(sprintf("    Post mean b/ref = %.4f (n = %s)",
                  row$mean_post, format(row$n_post, big.mark = ",")))
  log_msg(sprintf("    Shift (upper bound on cost shift) = %+.4f (%+.1f%%)",
                  row$shift, row$shift_pct))
  log_msg(sprintf("    KS test: D = %.3f, p = %.3g", row$KS_D, row$KS_p))
  verdict <- if (abs(row$shift) < 0.02) {
    "consistent with primitive invariance (shift < 2% of ref)"
  } else if (typ == "SME") {
    "upward shift consistent with marginal-SME entry"
  } else {
    "non-SME shift — may reflect selection into Pregão G65 bidding"
  }
  log_msg(sprintf("    Verdict: %s", verdict))
}
log_msg("=================================================================")
log_mem("final")
log_msg("=== 43_pregao_typesplit_ht.R: DONE ===")
