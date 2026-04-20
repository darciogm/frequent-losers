# ============================================================================
# 35_cpv_asymmetric.R — Sprint 3: Campo-Perrigne-Vuong (2003) asymmetric GPV
# ============================================================================
# Refines the pilot in 34_gpv_convite.R to treat SME and non-SME as
# *asymmetric* bidder types co-competing in the same auction, following
# Campo, Perrigne & Vuong (2003, IER) "Asymmetry in First-Price Auctions
# with Affiliated Private Values" and Athey, Levin & Seira (2011, QJE)
# for procurement.
#
# Also fixes a procurement-vs-purchase formula bug in 34: we were using
# c = b - G/g (purchase) instead of c = b - (1-G)/g (procurement). The
# procurement formula follows from maximizing (b-c) * (1-G(b))^{N-1}:
#
#     FOC: (1 - G(b)) = (b - c) * (N - 1) * g(b)
#     =>   c = b - (1 - G(b)) / ((N - 1) * g(b))
#
# Under asymmetry with n_A type-A and n_B = N - n_A type-B bidders, the
# type-k inverse bid function (for procurement) is:
#
#     c_k = b - 1 / { n_A^* * g_A(b)/(1-G_A(b)) + n_B^* * g_B(b)/(1-G_B(b)) }
#
# where n_A^* = n_A - 1 if k=A else n_A, and similarly for B. This reduces
# to the standard symmetric procurement GPV when G_A = G_B.
#
# Outputs:
#   data/processed/convite_cpv_costs.parquet     — bidder-auction pseudo-costs
#   output/tables/tab_v2_cpv_summary.{tex,csv}   — by type × period
#   output/tables/tab_v2_cpv_stability.csv       — KS test Pre vs Post
#   output/figures/fig_v2_cpv_costs_pre.pdf      — F_c^A vs F_c^B at Pre
#   output/figures/fig_v2_cpv_stability.pdf      — F_c^type Pre vs Post
#   output/figures/fig_v2_cpv_markup.pdf         — markup density
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
log_msg("=== 35_cpv_asymmetric.R — CPV asymmetric GPV ===")
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
# 1. LOAD AND PREPARE
# ============================================================================
log_msg("Loading Convite G65 bid-level data...")
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
bl <- bl[g65 == 1L]
log_msg(sprintf("  G65 Convite bid rows: %s", format(nrow(bl), big.mark = ",")))

# Firm-auction collapse (99.9% of Convite firms bid once)
fa <- bl[, .(
    bid   = min(bid_price, na.rm = TRUE),
    won   = max(won, na.rm = TRUE),
    sme   = max(sme_proxy, na.rm = TRUE),
    ref   = mean(ref_price, na.rm = TRUE),
    n_rep = .N
  ),
  by = .(numerodaoc, codigoitem, codigofornecedor, data_oc_numb, Pre, pharma)]

# Auction composition: n_A (SME) and n_B (non-SME) per auction
au_comp <- fa[, .(
    N   = .N,
    n_A = sum(sme == 1L),   # SME count
    n_B = sum(sme == 0L),   # non-SME count
    ref = mean(ref, na.rm = TRUE)
  ), by = .(numerodaoc, codigoitem, Pre)]
log_msg(sprintf("  auctions: %s", format(nrow(au_comp), big.mark = ",")))
log_msg(sprintf("  auctions with both types (mixed): %s (%.1f%%)",
                format(sum(au_comp$n_A >= 1 & au_comp$n_B >= 1), big.mark = ","),
                100 * mean(au_comp$n_A >= 1 & au_comp$n_B >= 1)))

# Merge composition back
fa <- merge(fa, au_comp[, .(numerodaoc, codigoitem, N, n_A, n_B)],
            by = c("numerodaoc", "codigoitem"))

# Filter: N>=2, positive bids, 0.005 < b/ref < 2 (same as 34)
fa[, b_norm := bid / ref]
n0 <- nrow(fa)
fa <- fa[N >= 2L & is.finite(bid) & bid > 0 & is.finite(ref) & ref > 0 &
         b_norm > 0.005 & b_norm < 2]
log_msg(sprintf("  after filter: %s rows (dropped %.1f%%)",
                format(nrow(fa), big.mark = ","), 100 * (1 - nrow(fa) / n0)))

# Stratification
fa[, period_lbl := fifelse(Pre == 1L, "Pre", "Post")]
fa[, sme_lbl    := fifelse(sme  == 1L, "SME", "NonSME")]
fa[, N_bin      := fifelse(N == 2L, "N=2",
                   fifelse(N == 3L, "N=3",
                    fifelse(N == 4L, "N=4", "N>=5")))]

# ============================================================================
# 2. ASYMMETRIC GPV KERNEL ESTIMATION PER STRATUM
# ============================================================================
# For each (period, N_bin), we estimate:
#   G_A, g_A  from SME bids in this stratum
#   G_B, g_B  from non-SME bids in this stratum
# We then evaluate both (G_A, g_A) and (G_B, g_B) at EACH observed bid price
# (regardless of who submitted the bid). The CPV inversion uses all four.
#
# Evaluation grid: union of b_norm range for the stratum. Kernel density via
# R's density() with Gaussian kernel and Silverman bandwidth. Interpolate
# at observed bid values via approx().
#
# Boundary handling: restrict density evaluation to [p5, p95] of observed
# b_norm per type to avoid unstable tails. Clip g_k at 1e-8 (lower bound).

estimate_type_cdf <- function(x, grid_n = 512) {
  # Gaussian kernel density + ECDF for a single type's bid pool
  if (length(x) < 50) return(NULL)
  x <- x[is.finite(x) & x > 0]
  h <- 1.06 * sd(x) * length(x)^(-1/5)
  if (!is.finite(h) || h <= 0) h <- 0.01
  # Density on a regular grid spanning [min, max]
  dens <- density(x, bw = h, n = grid_n, from = min(x), to = max(x),
                  kernel = "gaussian")
  # ECDF
  x_sorted <- sort(x)
  list(
    grid = dens$x,
    dens = dens$y,
    cdf  = ecdf(x_sorted),
    support = c(min(x), max(x)),
    n    = length(x)
  )
}

eval_g_G <- function(fit, b) {
  # Return (g, G) evaluated at vector b; 0/1 outside support
  g <- rep(1e-8, length(b))
  G <- rep(NA_real_, length(b))
  in_supp <- b >= fit$support[1] & b <= fit$support[2]
  g[in_supp] <- pmax(approx(fit$grid, fit$dens, xout = b[in_supp], rule = 2)$y,
                     1e-8)
  G[in_supp] <- fit$cdf(b[in_supp])
  G[b < fit$support[1]] <- 0
  G[b > fit$support[2]] <- 1
  list(g = g, G = G)
}

log_msg("Estimating type-conditional densities per (period, N_bin) stratum...")

fa_cpv <- data.table()
for (per in c("Pre", "Post")) {
  for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
    sub <- fa[period_lbl == per & N_bin == Nb]
    if (nrow(sub) < 400) next

    b_A <- sub[sme == 1L, b_norm]
    b_B <- sub[sme == 0L, b_norm]

    fit_A <- estimate_type_cdf(b_A)
    fit_B <- estimate_type_cdf(b_B)
    if (is.null(fit_A) || is.null(fit_B)) {
      log_msg(sprintf("  skip %s/%s — insufficient data per type (nA=%d, nB=%d)",
                      per, Nb, length(b_A), length(b_B)))
      next
    }

    # Evaluate BOTH densities at EVERY observed bid (regardless of type)
    eA <- eval_g_G(fit_A, sub$b_norm)
    eB <- eval_g_G(fit_B, sub$b_norm)

    sub[, `:=`(
      g_A = eA$g, G_A = eA$G,
      g_B = eB$g, G_B = eB$G
    )]

    # Hazard for each type at each bid
    sub[, hazA := g_A / pmax(1 - G_A, 1e-6)]
    sub[, hazB := g_B / pmax(1 - G_B, 1e-6)]

    # Type-specific adjusted opponent counts
    # For type-A bidder: n_A^* = n_A - 1; n_B^* = n_B
    # For type-B bidder: n_A^* = n_A;     n_B^* = n_B - 1
    sub[, `:=`(
      n_A_star = fifelse(sme == 1L, n_A - 1L, n_A),
      n_B_star = fifelse(sme == 1L, n_B,     n_B - 1L)
    )]
    sub[, denom := n_A_star * hazA + n_B_star * hazB]
    sub[, denom := pmax(denom, 1e-6)]

    # CPV inversion — in normalized units (b_norm)
    sub[, c_norm := b_norm - 1 / denom]
    sub[, markup_norm := b_norm - c_norm]  # = 1/denom

    # Convert back to level (R$)
    sub[, c_hat  := c_norm * ref]
    sub[, markup := markup_norm * ref]

    log_msg(sprintf("  %s/%s: nA=%d nB=%d | median markup (norm)=%.3f | eq_viol=%.2f%%",
                    per, Nb, fit_A$n, fit_B$n,
                    median(sub$markup_norm, na.rm = TRUE),
                    100 * mean(sub$c_norm > sub$b_norm, na.rm = TRUE)))

    fa_cpv <- rbind(fa_cpv, sub, fill = TRUE)
  }
}

log_msg(sprintf("CPV-estimated firm-auctions: %s",
                format(nrow(fa_cpv), big.mark = ",")))
log_mem("after CPV")

# Equilibrium-violation audit (c > b should NEVER happen under correct GPV)
eq_viol <- fa_cpv[, .(
    n = .N,
    pct_c_gt_b = round(100 * mean(c_hat > bid, na.rm = TRUE), 2),
    pct_c_neg  = round(100 * mean(c_hat < 0, na.rm = TRUE), 2),
    pct_c_norm_neg = round(100 * mean(c_norm < 0, na.rm = TRUE), 2)
  ), by = .(period_lbl, sme_lbl, N_bin)][order(period_lbl, sme_lbl, N_bin)]
log_msg("")
log_msg("Equilibrium-violation audit:")
print(eq_viol)

# ============================================================================
# 3. SUMMARY STATS
# ============================================================================
# Clean: keep c_norm in (0, 1) — reasonable pseudo-costs for procurement
fa_clean <- fa_cpv[is.finite(c_norm) & c_norm > 0.001 & c_norm < 1.5]
log_msg(sprintf("Clean subset: %s (%.1f%% of CPV-estimated)",
                format(nrow(fa_clean), big.mark = ","),
                100 * nrow(fa_clean) / nrow(fa_cpv)))

cost_sum <- fa_clean[, .(
    n            = .N,
    mean_cnorm   = round(mean(c_norm), 3),
    median_cnorm = round(median(c_norm), 3),
    sd_cnorm     = round(sd(c_norm), 3),
    median_bnorm = round(median(b_norm), 3),
    median_mkp   = round(median(markup_norm), 3),
    mkp_pct      = round(100 * median(markup_norm / b_norm), 1)
  ), by = .(period_lbl, sme_lbl)][order(period_lbl, sme_lbl)]
log_msg("Cost distribution summary (c/ref units):")
print(cost_sum)
fwrite(cost_sum, file.path(V2_TABLES, "tab_v2_cpv_summary.csv"))

sink(file.path(V2_TABLES, "tab_v2_cpv_summary.tex"))
cat("% Auto-generated by 35_cpv_asymmetric.R\n")
cat("\\begin{tabular}{llrrrrrr}\n\\toprule\n")
cat("Period & Type & $n$ & $\\bar{c}/ref$ & med $c/ref$ & sd $c/ref$ &",
    "med mkp/ref & mkp\\% \\\\\n\\midrule\n")
for (i in seq_len(nrow(cost_sum))) {
  with(cost_sum[i], cat(
    period_lbl, "&", sme_lbl, "&",
    format(n, big.mark = ","), "&",
    sprintf("%.3f", mean_cnorm), "&",
    sprintf("%.3f", median_cnorm), "&",
    sprintf("%.3f", sd_cnorm), "&",
    sprintf("%.3f", median_mkp), "&",
    sprintf("%.1f\\%%", mkp_pct), "\\\\\n"))
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()

# Stability test (KS)
stability <- data.table()
for (typ in c("SME", "NonSME")) {
  a <- fa_clean[period_lbl == "Pre"  & sme_lbl == typ, c_norm]
  b <- fa_clean[period_lbl == "Post" & sme_lbl == typ, c_norm]
  if (length(a) < 50 || length(b) < 50) next
  ks <- suppressWarnings(ks.test(a, b))
  stability <- rbind(stability, data.table(
    type = typ,
    n_pre = length(a), n_post = length(b),
    mean_pre  = round(mean(a), 3),
    mean_post = round(mean(b), 3),
    shift     = round(mean(b) - mean(a), 3),
    KS_D      = round(unname(ks$statistic), 3),
    KS_p      = signif(unname(ks$p.value), 3)
  ))
}
log_msg("")
log_msg("Stability test: primitive F_c should be invariant across periods")
print(stability)
fwrite(stability, file.path(V2_TABLES, "tab_v2_cpv_stability.csv"))

# ============================================================================
# 4. FIGURES
# ============================================================================
# Figure 1: F_c^A vs F_c^B at Pre period
d_pre <- fa_clean[period_lbl == "Pre"]
fig_pre <- ggplot(d_pre, aes(x = c_norm, color = sme_lbl, linetype = sme_lbl)) +
  stat_ecdf(linewidth = 0.6) +
  scale_color_manual(values = c("SME" = "black", "NonSME" = "grey40")) +
  scale_linetype_manual(values = c("SME" = "solid", "NonSME" = "dashed")) +
  scale_x_continuous(labels = percent_format(),
                     limits = c(0, quantile(d_pre$c_norm, 0.98, na.rm = TRUE))) +
  labs(x = "Pseudo-cost / ref price  (c/ref)",
       y = "Cumulative distribution F(c/ref)",
       title = "Asymmetric GPV (CPV 2003): recovered cost distributions at Pre",
       subtitle = "Type-asymmetric equilibrium; bids from both SME and non-SME in same auction") +
  theme_pub()
save_pub(fig_pre, "fig_v2_cpv_costs_pre.pdf", w = 7.0, h = 4.2)

# Figure 2: Stability Pre vs Post by type
fig_stab <- ggplot(fa_clean, aes(x = c_norm,
                                 color = period_lbl, linetype = period_lbl)) +
  stat_ecdf(linewidth = 0.6) +
  facet_wrap(~ sme_lbl) +
  scale_color_manual(values = c("Pre" = "grey20", "Post" = "grey60")) +
  scale_linetype_manual(values = c("Pre" = "solid", "Post" = "dashed")) +
  scale_x_continuous(labels = percent_format(),
                     limits = c(0, quantile(fa_clean$c_norm, 0.98, na.rm = TRUE))) +
  labs(x = "Pseudo-cost / ref price", y = "F(c/ref)",
       title = "Stability of asymmetric-GPV cost distributions across regimes",
       subtitle = "Under CPV, within-type F_c is primitive → should be invariant Pre vs Post") +
  theme_pub()
save_pub(fig_stab, "fig_v2_cpv_stability.pdf", w = 7.5, h = 4.0)

# Figure 3: Markup density by type × period
fig_mkp <- ggplot(fa_clean[markup_norm > 0 & markup_norm < 1],
                  aes(x = markup_norm, linetype = period_lbl, color = sme_lbl)) +
  geom_density(linewidth = 0.5, adjust = 1.2) +
  scale_color_manual(values = c("SME" = "black", "NonSME" = "grey40")) +
  scale_linetype_manual(values = c("Pre" = "solid", "Post" = "dashed")) +
  scale_x_continuous(labels = percent_format()) +
  labs(x = "Implied markup (b − c) / ref", y = "Density",
       title = "CPV-implied markup, by period × bidder type",
       subtitle = "Markup = 1 / { n_A* · haz_A + n_B* · haz_B } after normalization") +
  theme_pub()
save_pub(fig_mkp, "fig_v2_cpv_markup.pdf", w = 7.0, h = 4.0)

# ============================================================================
# 5. SAVE
# ============================================================================
out_pq <- file.path(V2_DATA, "convite_cpv_costs.parquet")
write_parquet(fa_cpv, out_pq)
log_msg(sprintf("Saved CPV pseudo-cost panel: %s (%s rows, %.1f MB)",
                out_pq, format(nrow(fa_cpv), big.mark = ","),
                file.info(out_pq)$size / 1024^2))

log_mem("final")
log_msg("=== 35_cpv_asymmetric.R: DONE ===")
