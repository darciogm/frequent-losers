# ============================================================================
# 37_pregao_htbounds.R — Sprint 6: Haile-Tamer bounds for Pregão G65
# ============================================================================
# Extends the structural decomposition from Convite (FPSB, CPV point ID)
# to Pregão eletrônico (iterative descending reverse auction with soft
# close), which comprises 84% of Group-65 procurement VALUE in the sample
# even though Convite has slightly more auctions by count.
#
# Why Haile-Tamer (2003) rather than CPV:
#   Pregão is iterative descending, bidders observe the current best bid,
#   and the auction closes when no new bid arrives within 5 minutes
#   ("tempo aleatório" / soft close). This is NOT first-price sealed-bid,
#   so the GPV inverse does not apply. Haile-Tamer treats the game as
#   an *incomplete model* and recovers BOUNDS on the cost distribution
#   using only two weak rationality assumptions:
#
#   H1 (individual rationality): no bidder bids BELOW own cost.
#       => b_i >= c_i for all i
#   H2 (incomplete-dominance):  no bidder drops out while still willing
#       to underbid the current best. At close, the winner's bid is at
#       or below the second-lowest type's cost (the would-be winner if
#       current winner dropped out).
#       => b_(1) <= c_(2)
#
# Implication for procurement order statistics:
#       F_{c_(2)}(c)  <=  F_{b_(1)}(c)  <=  F_{c_(1)}(c)
#
# From order-statistic identities we recover bounds on F_c:
#   Lower bound (from H1 via winner's bid):
#       F_LB(c) = 1 - (1 - F_{b_(1)}(c))^{1/N}
#   Upper bound (from H2 via second-lowest type):
#       F_UB(c) solves  F_{b_(1)}(c) = 1 - (1-F_UB)^N - N*F_UB*(1-F_UB)^{N-1}
#                                       (numerically)
#
# The bounds are tight when (b_(1), b_(2)) are close (competitive auctions)
# and loose when the gap is large (thin markets).
#
# Primary deliverables:
#   (i)  HT bounds on F_c per stratum (Pre vs Post, by N-bin)
#   (ii) Test: do the bounds shift post-March 2018 in a direction
#        consistent with the Convite structural story?
#   (iii) Magnitude comparison with Convite CPV results
#
# Outputs:
#   data/processed/pregao_htbounds.parquet       — per-auction (b_1, b_2, N, F bounds)
#   output/tables/tab_v2_pregao_ht_summary.csv   — winning bid dist per stratum
#   output/tables/tab_v2_pregao_ht_shift.csv     — Pre vs Post shift test
#   output/figures/fig_v2_ht_bounds_pre.pdf      — F_c bounds at Pre
#   output/figures/fig_v2_ht_stability.pdf       — bounds Pre vs Post
#   output/figures/fig_v2_ht_vs_convite.pdf      — bounds vs Convite CPV
#   logs/37_pregao_htbounds.log
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
log_msg("=== 37_pregao_htbounds.R — Haile-Tamer bounds for Pregão ===")
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
# 1. LOAD AND PREPARE PREGÃO G65
# ============================================================================
log_msg("Loading Pregão G65 bid-level data...")
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_pregao.parquet")))
bl <- bl[g65 == 1L]
log_msg(sprintf("  G65 Pregão bid rows: %s", format(nrow(bl), big.mark = ",")))

# Collapse iterative trail to firm-auction level.
# In Pregão a firm may submit many bids in the iterative phase; we take
# its FINAL (lowest) standing bid per auction as its equilibrium offer.
fa <- bl[, .(
    bid   = min(bid_price, na.rm = TRUE),   # firm's best/final stand
    won   = max(won, na.rm = TRUE),
    sme   = max(sme_proxy, na.rm = TRUE),
    ref   = mean(ref_price, na.rm = TRUE),
    n_iter = .N
  ), by = .(numerodaoc, codigoitem, codigofornecedor, Pre, pharma)]

log_msg(sprintf("  firm-auction rows: %s", format(nrow(fa), big.mark = ",")))

# Per-auction summary: N, (b_(1), b_(2)), ref, composition
au <- fa[order(bid), .(
    N      = .N,
    n_A    = sum(sme == 1L),
    n_B    = sum(sme == 0L),
    b1     = bid[1],                # minimum (winning bid)
    b2     = if (.N >= 2L) bid[2] else NA_real_,
    b1_type = sme[1],               # type of winner (1 = SME, 0 = non-SME)
    ref    = mean(ref, na.rm = TRUE)
  ),
  by = .(numerodaoc, codigoitem, Pre, pharma)]

# Filters
au[, b1_norm := b1 / ref]
au[, b2_norm := b2 / ref]
n0 <- nrow(au)
au <- au[N >= 2L & is.finite(ref) & ref > 0 &
         b1_norm > 0.005 & b1_norm < 2 &
         is.finite(b2_norm) & b2_norm > 0.005 & b2_norm < 2]
log_msg(sprintf("  auctions after filter (N>=2, valid b1/b2): %s (dropped %.1f%%)",
                format(nrow(au), big.mark = ","),
                100 * (1 - nrow(au) / n0)))

au[, period_lbl := fifelse(Pre == 1L, "Pre", "Post")]
au[, winner_lbl := fifelse(b1_type == 1L, "SME_win", "NonSME_win")]
au[, N_bin := fifelse(N == 2L, "N=2",
              fifelse(N == 3L, "N=3",
               fifelse(N == 4L, "N=4", "N>=5")))]

# ============================================================================
# 2. HAILE-TAMER BOUNDS ON F_c  (symmetric-aggregate version)
# ============================================================================
# Per stratum (period, N-bin), compute:
#   F_{b_(1)} empirically on a common grid
#   Lower bound on F_c:  F_LB = 1 - (1 - F_{b_(1)})^{1/N}
#   Upper bound on F_c:  numerically invert
#       F_{b_(1)}(c) = 1 - (1-F)^N - N*F*(1-F)^{N-1}
#       i.e., F_{c_(2)}(c) = F_{b_(1)}(c) with second-order-statistic form
#
# For N-bin "N>=5" we use the mean N in that bin for the power.

grid_c <- seq(0.005, 1.5, length.out = 500)

empirical_cdf <- function(x, grid) {
  ec <- ecdf(x)
  ec(grid)
}

ht_lower <- function(F_b1_vec, N_eff) {
  # F_LB = 1 - (1 - F_{b_(1)})^{1/N}
  pmax(0, 1 - (1 - pmin(F_b1_vec, 1))^(1/N_eff))
}

ht_upper <- function(F_b1_vec, N_eff) {
  # Invert: F_{b_(1)}(c) = 1 - (1-F)^N - N*F*(1-F)^{N-1}
  # Solve for F given F_{b_(1)} at each grid point.
  sapply(F_b1_vec, function(fb1) {
    if (fb1 <= 0) return(0)
    if (fb1 >= 1) return(1)
    obj <- function(F) {
      Fc2_pred <- 1 - (1 - F)^N_eff - N_eff * F * (1 - F)^(N_eff - 1)
      Fc2_pred - fb1
    }
    # Bracket [0,1]; use uniroot
    tryCatch(uniroot(obj, c(0, 1), tol = 1e-6)$root,
             error = function(e) NA_real_)
  })
}

log_msg("Computing HT bounds per (period, N-bin) stratum...")
ht_list <- list()
for (per in c("Pre", "Post")) {
  for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
    sub <- au[period_lbl == per & N_bin == Nb]
    if (nrow(sub) < 200) next
    # Effective N for this bin
    N_eff <- mean(sub$N)
    # Empirical F_{b_(1)} on the grid
    Fb1 <- empirical_cdf(sub$b1_norm, grid_c)
    # HT bounds
    F_LB <- ht_lower(Fb1, N_eff)
    F_UB <- ht_upper(Fb1, N_eff)
    ht_list[[paste(per, Nb, sep = "/")]] <- data.table(
      period_lbl = per,
      N_bin      = Nb,
      N_eff      = round(N_eff, 2),
      n_auc      = nrow(sub),
      c_grid     = grid_c,
      Fb1        = Fb1,
      F_LB       = F_LB,
      F_UB       = F_UB
    )
    log_msg(sprintf("  %s/%s: n_auc=%d, N_eff=%.2f, median(F_LB)=%.3f, median(F_UB)=%.3f",
                    per, Nb, nrow(sub), N_eff,
                    median(F_LB, na.rm = TRUE),
                    median(F_UB, na.rm = TRUE)))
  }
}
ht_full <- rbindlist(ht_list, use.names = TRUE, fill = TRUE)

# ============================================================================
# 3. WINNING-BID SHIFT TEST: Pre vs Post
# ============================================================================
# If F_c is primitive-invariant (aggregate, not type-split), we'd expect
# F_{b_(1)}^Pre and F_{b_(1)}^Post to coincide. They shouldn't (the policy
# shifts WHO bids). The question is whether the shift is CONSISTENT with
# Convite CPV: marginal SMEs entering and non-SMEs excluded.

log_msg("")
log_msg("Winning-bid shift test (Pre vs Post, by N-bin):")
shift_tab <- au[, .(
    n_auc       = .N,
    mean_b1norm = round(mean(b1_norm, na.rm = TRUE), 4),
    median_b1norm = round(median(b1_norm, na.rm = TRUE), 4),
    sd_b1norm   = round(sd(b1_norm, na.rm = TRUE), 4),
    sme_win_pct = round(100 * mean(b1_type == 1L), 1)
  ), by = .(period_lbl, N_bin)][order(period_lbl, N_bin)]
print(shift_tab)
fwrite(shift_tab, file.path(V2_TABLES, "tab_v2_pregao_ht_summary.csv"))

# Pre vs Post shift in each N-bin
shift_delta <- list()
for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
  a <- au[period_lbl == "Pre"  & N_bin == Nb, b1_norm]
  b <- au[period_lbl == "Post" & N_bin == Nb, b1_norm]
  if (length(a) < 50 || length(b) < 50) next
  ks <- suppressWarnings(ks.test(a, b))
  shift_delta[[Nb]] <- data.table(
    N_bin      = Nb,
    n_pre      = length(a),
    n_post     = length(b),
    mean_pre   = round(mean(a), 4),
    mean_post  = round(mean(b), 4),
    shift      = round(mean(b) - mean(a), 4),
    shift_pct  = round(100 * (mean(b) - mean(a)) / mean(a), 1),
    KS_D       = round(unname(ks$statistic), 3),
    KS_p       = signif(unname(ks$p.value), 3)
  )
}
shift_delta_tab <- rbindlist(shift_delta, use.names = TRUE)
log_msg("")
log_msg("Winning-bid distribution shift (Post - Pre):")
print(shift_delta_tab)
fwrite(shift_delta_tab, file.path(V2_TABLES, "tab_v2_pregao_ht_shift.csv"))

# ============================================================================
# 4. FIGURES
# ============================================================================
# Figure 1: HT bounds on F_c at Pre period, by N-bin
ht_pre <- ht_full[period_lbl == "Pre"]
fig_pre_ht <- ggplot(ht_pre) +
  geom_ribbon(aes(x = c_grid, ymin = F_LB, ymax = F_UB,
                  group = N_bin, fill = N_bin), alpha = 0.25) +
  geom_line(aes(x = c_grid, y = (F_LB + F_UB) / 2, color = N_bin),
            linewidth = 0.5) +
  coord_cartesian(xlim = c(0, 1.2)) +
  scale_x_continuous(labels = percent_format()) +
  scale_fill_grey(start = 0.2, end = 0.7) +
  scale_color_grey(start = 0.2, end = 0.7) +
  labs(x = "Cost / reference price", y = "F(c/ref)",
       title = "Haile-Tamer bounds on cost distribution at Pre (Pregão G65)",
       subtitle = "Band: [F_LB, F_UB] under H1+H2. Line: midpoint. Tighter at low N.") +
  theme_pub()
save_pub(fig_pre_ht, "fig_v2_ht_bounds_pre.pdf", w = 7.5, h = 4.2)

# Figure 2: HT bounds Pre vs Post (stability)
fig_ht_stab <- ggplot(ht_full) +
  geom_ribbon(aes(x = c_grid, ymin = F_LB, ymax = F_UB,
                  fill = period_lbl), alpha = 0.3) +
  geom_line(aes(x = c_grid, y = (F_LB + F_UB) / 2, color = period_lbl,
                linetype = period_lbl), linewidth = 0.5) +
  facet_wrap(~ N_bin, scales = "free") +
  scale_fill_manual(values = c("Pre" = "grey30", "Post" = "grey70")) +
  scale_color_manual(values = c("Pre" = "grey20", "Post" = "grey50")) +
  scale_linetype_manual(values = c("Pre" = "solid", "Post" = "dashed")) +
  scale_x_continuous(labels = percent_format()) +
  coord_cartesian(xlim = c(0, 1.2)) +
  labs(x = "Cost / reference price", y = "F(c/ref)",
       title = "HT cost-distribution bounds: Pre vs Post (Pregão G65)",
       subtitle = "Aggregate bounds; type-split extension is follow-up work") +
  theme_pub()
save_pub(fig_ht_stab, "fig_v2_ht_stability.pdf", w = 7.5, h = 5.2)

# Figure 3: Pregão vs Convite comparison
# Load Convite CPV costs to overlay
if (file.exists(file.path(V2_DATA, "convite_cpv_costs.parquet"))) {
  conv <- as.data.table(read_parquet(file.path(V2_DATA, "convite_cpv_costs.parquet")))
  conv_clean <- conv[is.finite(c_norm) & c_norm > 0.001 & c_norm < 1.5]

  # Compute ECDFs for overlay
  conv_pre  <- data.table(c = conv_clean[period_lbl == "Pre",  c_norm])
  conv_post <- data.table(c = conv_clean[period_lbl == "Post", c_norm])

  # Aggregate HT mid (across N-bins) weighted by auctions
  ht_agg <- ht_full[, .(
      F_mid = sum(((F_LB + F_UB)/2) * n_auc) / sum(n_auc),
      F_LB  = sum(F_LB * n_auc) / sum(n_auc),
      F_UB  = sum(F_UB * n_auc) / sum(n_auc)
    ), by = .(period_lbl, c_grid)]
  setnames(ht_agg, "period_lbl", "period")

  # Build comparison plot
  p_df <- rbindlist(list(
    data.table(c = conv_pre$c,  source = "Convite CPV", period = "Pre"),
    data.table(c = conv_post$c, source = "Convite CPV", period = "Post")
  ))

  fig_vs <- ggplot() +
    stat_ecdf(data = p_df, aes(x = c, color = period, linetype = source),
              linewidth = 0.5) +
    geom_ribbon(data = ht_agg,
                aes(x = c_grid, ymin = F_LB, ymax = F_UB, fill = period),
                alpha = 0.2) +
    geom_line(data = ht_agg,
              aes(x = c_grid, y = F_mid, color = period, linetype = "Pregão HT"),
              linewidth = 0.5) +
    scale_x_continuous(labels = percent_format(), limits = c(0, 1.2)) +
    scale_color_manual(values = c("Pre" = "black", "Post" = "grey40")) +
    scale_fill_manual(values = c("Pre" = "grey30", "Post" = "grey70")) +
    scale_linetype_manual(values = c("Convite CPV" = "solid", "Pregão HT" = "dotted")) +
    labs(x = "Cost / reference price", y = "F(c/ref)",
         title = "Convite (CPV point-ID) vs Pregão (HT bounds)",
         subtitle = "Cross-modality validation: similar magnitudes would corroborate the structural story") +
    theme_pub()
  save_pub(fig_vs, "fig_v2_ht_vs_convite.pdf", w = 7.5, h = 4.5)
}

# ============================================================================
# 5. SAVE OUTPUTS
# ============================================================================
out_pq <- file.path(V2_DATA, "pregao_htbounds.parquet")
write_parquet(ht_full, out_pq)
log_msg(sprintf("Saved HT bounds panel: %s (%s rows, %.1f MB)",
                out_pq, format(nrow(ht_full), big.mark = ","),
                file.info(out_pq)$size / 1024^2))

# Summary at the end
log_msg("")
log_msg("================================================================")
log_msg("PREGÃO HT SUMMARY")
log_msg("================================================================")
log_msg(sprintf("  Pregão G65 auctions in structural sample: %s",
                format(nrow(au), big.mark = ",")))
log_msg(sprintf("  Mean winning bid (b/ref) Pre:  %.4f",
                mean(au[period_lbl == "Pre",  b1_norm], na.rm = TRUE)))
log_msg(sprintf("  Mean winning bid (b/ref) Post: %.4f",
                mean(au[period_lbl == "Post", b1_norm], na.rm = TRUE)))
log_msg(sprintf("  Post - Pre shift: %+.4f (%+.1f%%)",
                mean(au[period_lbl == "Post", b1_norm], na.rm = TRUE) -
                  mean(au[period_lbl == "Pre",  b1_norm], na.rm = TRUE),
                100 * (mean(au[period_lbl == "Post", b1_norm], na.rm = TRUE) -
                       mean(au[period_lbl == "Pre",  b1_norm], na.rm = TRUE)) /
                       mean(au[period_lbl == "Pre",  b1_norm], na.rm = TRUE)))
log_msg("================================================================")

log_mem("final")
log_msg("=== 37_pregao_htbounds.R: DONE ===")
