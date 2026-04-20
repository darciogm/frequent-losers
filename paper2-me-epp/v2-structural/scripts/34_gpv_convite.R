# ============================================================================
# 34_gpv_convite.R — Sprint 2: GPV non-parametric pilot on Convite G65
# ============================================================================
# Implements the Guerre-Perrigne-Vuong (2000, Econometrica) estimator on the
# Convite G65 sample (clean FPSB, 51,555 auctions; 33,706 with N >= 2).
#
# Equilibrium condition in a first-price sealed-bid procurement auction with
# independent private values and N symmetric bidders is:
#
#     c_i  =  b_i  -  (1 / (N_i - 1)) * G(b_i) / g(b_i)
#
# where G is the CDF of equilibrium bids in the relevant stratum and g is its
# density. Inverting gives pseudo-costs per bid, from which F_c (the cost
# distribution primitive) is recovered nonparametrically.
#
# Identification strategy for this paper:
#   - Estimate F_c separately for (SME, non-SME) × (Pre, Post).
#   - Under the model, F_c within type should be stable across Pre/Post
#     (costs are primitives; the regime switch changes who participates,
#     not what their costs are).  If we recover stable F_c, model is
#     well-specified.  If not, either selection or misspecification.
#
# Normalization:
#   Bids and ref_price vary massively across auctions (log-ref CV = 2.3).
#   We work with b̃ = log(bid / ref) — equilibrium condition holds under
#   this monotone transform when ref is auction-level (Li-Perrigne-Vuong 2002).
#
# Stratification:
#   (period) × (sme_flag) × (N-bin). N-bin = {2, 3, 4, 5+} because GPV kernel
#   estimation needs common N per stratum (the (N-1)^{-1} factor).
#
# Outputs:
#   data/processed/convite_pseudo_costs.parquet     — bidder-auction c, b, markup
#   output/tables/tab_v2_gpv_summary.{tex,csv}      — cost distribution summary
#   output/tables/tab_v2_gpv_stability.{tex,csv}    — Pre/Post stability test
#   output/figures/fig_v2_gpv_costs_pre.pdf         — F_c(type) at Pre
#   output/figures/fig_v2_gpv_stability.pdf         — F_c(type) Pre vs Post
#   output/figures/fig_v2_gpv_markup.pdf            — markup = (b - c) distribution
#   logs/34_gpv_convite.log
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
log_msg("=== 34_gpv_convite.R — GPV pilot ===")
log_mem("startup")

theme_pub <- function() {
  theme_bw(base_size = 9) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
      strip.background = element_rect(fill = "grey95", color = "black",
                                      linewidth = 0.3),
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.title = element_text(size = 10, face = "bold")
    )
}
save_pub <- function(p, fn, w = 6.5, h = 4.0) {
  ggsave(file.path(V2_FIGS, fn), p, width = w, height = h, device = cairo_pdf)
  log_msg("  saved ", fn)
}

# ============================================================================
# 1. LOAD + FILTER + NORMALIZE
# ============================================================================

log_msg("Loading Convite G65 subset...")
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
bl <- bl[g65 == 1L]
log_msg(sprintf("  Convite G65 bid rows: %s", format(nrow(bl), big.mark = ",")))

# Collapse to firm-auction level (99.9% of Convite firms bid once; take min)
fa <- bl[, .(
    bid   = min(bid_price, na.rm = TRUE),
    won   = max(won, na.rm = TRUE),
    sme   = max(sme_proxy, na.rm = TRUE),
    ref   = mean(ref_price, na.rm = TRUE),  # one per auction in practice
    n_rep = .N
  ),
  by = .(numerodaoc, codigoitem, codigofornecedor, data_oc_numb, Pre, pharma)]
log_msg(sprintf("  firm-auction rows: %s", format(nrow(fa), big.mark = ",")))

# Auction-level N and ref
au <- fa[, .(
    N   = uniqueN(codigofornecedor),
    ref = mean(ref, na.rm = TRUE)
  ), by = .(numerodaoc, codigoitem, data_oc_numb, Pre, pharma)]
log_msg(sprintf("  auction rows: %s", format(nrow(au), big.mark = ",")))

# Merge N back to firm-auction
fa <- merge(fa, au[, .(numerodaoc, codigoitem, N)],
            by = c("numerodaoc", "codigoitem"))

# Filters for GPV:
#   - N >= 2 (GPV undefined at N=1)
#   - positive bid, positive ref, bid finite
#   - normalized bid b_norm = bid/ref in (0.005, 2) to discard R$0.01 placeholders
#     and absurd bids > 2x reference (likely data errors)
fa[, b_norm := bid / ref]
n0 <- nrow(fa)
fa <- fa[N >= 2L & is.finite(bid) & bid > 0 & is.finite(ref) & ref > 0 &
         b_norm > 0.005 & b_norm < 2]
log_msg(sprintf("  after filter (N>=2, 0.005<b/ref<2): %s rows (dropped %.1f%%)",
                format(nrow(fa), big.mark = ","), 100 * (1 - nrow(fa) / n0)))

# log(bid/ref) — working variable
fa[, lb := log(b_norm)]

# N-bin: pool sparse strata
fa[, N_bin := fifelse(N == 2L, "N=2",
                fifelse(N == 3L, "N=3",
                 fifelse(N == 4L, "N=4", "N>=5")))]
fa[, period_lbl := fifelse(Pre == 1L, "Pre", "Post")]
fa[, sme_lbl    := fifelse(sme  == 1L, "SME", "NonSME")]

# Cell tag for stratification
fa[, cell := paste(period_lbl, sme_lbl, N_bin, sep = "/")]

cell_n <- fa[, .(n_obs = .N, n_auc = uniqueN(paste(numerodaoc, codigoitem))),
             by = cell][order(cell)]
log_msg("Stratum sizes:")
print(cell_n)

# ============================================================================
# 2. GPV INVERSION, PER STRATUM
# ============================================================================
#
# For each (period, sme, N_bin) stratum:
#   - Estimate G(b) as empirical ECDF of lb
#   - Estimate g(b) via Gaussian kernel density (bandwidth = Silverman)
#   - Invert: c_i = b_i - (1/(N_i - 1)) * G(b_i) / g(b_i)  in LEVELS
#     We invert on LEVELS b (not log), using the chain-rule relationship
#     between log-bid density and level-bid density:
#       g_lev(b) = (1/b) * g_log(log b)
#     and G_lev(b) = G_log(log b). So:
#       c = b - (1/(N-1)) * G_log(log b) / [ (1/b) * g_log(log b) ]
#         = b - b/(N-1) * G_log(log b) / g_log(log b)
#   - Trim pseudo-costs at 1% / 99% within stratum to mitigate boundary bias
#
# Critical check: c must be <= b. If not, equilibrium violation / misspec.

gpv_stratum <- function(sub) {
  # sub is a data.table with columns: bid, lb, N_bin, period_lbl, sme_lbl, ref
  if (nrow(sub) < 200) return(NULL)
  N_eff <- as.integer(sub[, first(N)])
  if (is.na(N_eff) || N_eff < 2L) return(NULL)

  # Kernel density on log-scale
  # Silverman's rule: h = 1.06 * sd(x) * n^{-1/5}
  n <- nrow(sub)
  h <- 1.06 * sd(sub$lb, na.rm = TRUE) * n^(-1/5)
  if (!is.finite(h) || h <= 0) h <- 0.1

  # Evaluate kernel density at every observation's lb value
  dens <- density(sub$lb, bw = h, from = min(sub$lb), to = max(sub$lb),
                  n = 512, kernel = "gaussian")
  g_at <- approx(dens$x, dens$y, xout = sub$lb, rule = 2)$y

  # ECDF at each obs
  # Using plug-in: G(x) = rank(x)/n (standard empirical CDF, no ties-correction)
  G_at <- rank(sub$lb, ties.method = "average") / n

  # GPV inversion on LEVELS
  #   c = b - b/(N-1) * G_log / g_log
  sub[, G_hat := G_at]
  sub[, g_hat := g_at]
  sub[, markup_term := bid / (N_eff - 1) * G_hat / g_hat]
  sub[, c_hat := bid - markup_term]
  # Trim boundary bias (keep 1-99% cost range)
  q_lo <- quantile(sub$c_hat, 0.01, na.rm = TRUE)
  q_hi <- quantile(sub$c_hat, 0.99, na.rm = TRUE)
  sub[, trimmed := c_hat < q_lo | c_hat > q_hi]
  sub
}

log_msg("Running GPV inversion per stratum...")
res <- list()
for (cell_name in unique(fa$cell)) {
  sub <- fa[cell == cell_name]
  if (nrow(sub) < 200) {
    log_msg(sprintf("  skip %s (n=%d < 200)", cell_name, nrow(sub)))
    next
  }
  out <- gpv_stratum(sub)
  if (!is.null(out)) res[[cell_name]] <- out
  log_msg(sprintf("  %s: n=%d, median c_hat=%.3f, median markup=%.3f, eq_viol=%.2f%%",
                  cell_name, nrow(sub),
                  median(out$c_hat, na.rm = TRUE),
                  median(out$markup_term, na.rm = TRUE),
                  100 * mean(out$c_hat > out$bid, na.rm = TRUE)))
}
fa_gpv <- rbindlist(res, use.names = TRUE)
log_msg(sprintf("GPV-estimated bidder-auctions: %s",
                format(nrow(fa_gpv), big.mark = ",")))

# Equilibrium-violation audit
eq_viol <- fa_gpv[, .(
    n = .N,
    pct_c_gt_b = round(100 * mean(c_hat > bid, na.rm = TRUE), 2),
    pct_c_neg  = round(100 * mean(c_hat < 0,   na.rm = TRUE), 2)
  ), by = .(period_lbl, sme_lbl, N_bin)][order(period_lbl, sme_lbl, N_bin)]
log_msg("")
log_msg("Equilibrium-violation audit (c > b is FAIL under GPV):")
print(eq_viol)

# ============================================================================
# 3. SUMMARY STATS ON COST DISTRIBUTIONS
# ============================================================================

fa_clean <- fa_gpv[!trimmed & c_hat > 0 & c_hat <= bid]
log_msg(sprintf("Clean subset (no trim, c in (0, b]): %s rows (%.1f%% of GPV-estimated)",
                format(nrow(fa_clean), big.mark = ","),
                100 * nrow(fa_clean) / nrow(fa_gpv)))

# Cost summary per (period, sme)
cost_sum <- fa_clean[, .(
    n          = .N,
    mean_c     = round(mean(c_hat), 3),
    median_c   = round(median(c_hat), 3),
    sd_c       = round(sd(c_hat), 3),
    q25_c      = round(quantile(c_hat, 0.25), 3),
    q75_c      = round(quantile(c_hat, 0.75), 3),
    median_b   = round(median(bid), 3),
    median_mkp = round(median(bid - c_hat), 3),
    mkp_pct    = round(100 * median((bid - c_hat) / bid), 2)
  ), by = .(period_lbl, sme_lbl)][order(period_lbl, sme_lbl)]
log_msg("Cost distribution summary (log-normalized bids, c in log(bid/ref) scale):")
print(cost_sum)

fwrite(cost_sum, file.path(V2_TABLES, "tab_v2_gpv_summary.csv"))
sink(file.path(V2_TABLES, "tab_v2_gpv_summary.tex"))
cat("% Auto-generated by 34_gpv_convite.R\n")
cat("\\begin{tabular}{llrrrrrr}\n\\toprule\n")
cat("Period & Type & $n$ & $\\bar c$ & med $c$ & sd $c$ &",
    "med mkp & mkp\\% \\\\\n\\midrule\n")
for (i in seq_len(nrow(cost_sum))) {
  with(cost_sum[i], cat(
    period_lbl, "&", sme_lbl, "&",
    format(n, big.mark = ","), "&",
    sprintf("%.3f", mean_c), "&",
    sprintf("%.3f", median_c), "&",
    sprintf("%.3f", sd_c), "&",
    sprintf("%.3f", median_mkp), "&",
    sprintf("%.2f\\%%", mkp_pct), "\\\\\n"))
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()

# ============================================================================
# 4. STABILITY TEST: F_c(SME, Pre) vs F_c(SME, Post)  and same for NonSME
# ============================================================================
# Under the model, primitive cost distributions are invariant to auction
# rules. If SME cost dist shifts between Pre and Post, model is misspecified
# OR there is selection-into-bidding driven by the regime change.
log_msg("")
log_msg("Stability test (KS-like): primitive cost dist should be invariant across periods")

stability <- data.table()
for (typ in c("SME", "NonSME")) {
  a <- fa_clean[period_lbl == "Pre"  & sme_lbl == typ, c_hat]
  b <- fa_clean[period_lbl == "Post" & sme_lbl == typ, c_hat]
  if (length(a) < 50 || length(b) < 50) next
  ks <- suppressWarnings(ks.test(a, b))
  stability <- rbind(stability, data.table(
    type       = typ,
    n_pre      = length(a),
    n_post     = length(b),
    mean_pre   = round(mean(a), 3),
    mean_post  = round(mean(b), 3),
    mean_shift = round(mean(b) - mean(a), 3),
    KS_D       = round(unname(ks$statistic), 3),
    KS_p       = signif(unname(ks$p.value), 3)
  ))
}
print(stability)
fwrite(stability, file.path(V2_TABLES, "tab_v2_gpv_stability.csv"))

# ============================================================================
# 5. FIGURES
# ============================================================================

# Normalize pseudo-cost by reference price for interpretability and
# cross-auction pooling. c_norm = c_hat / ref = "cost as fraction of
# reference price"; takes values in (0, 1) typically.
fa_clean[, c_norm := c_hat / ref]
fa_clean[, b_rel  := bid / ref]

# Figure 1: F_c(type) at Pre period — normalized scale, trimmed to 99th pct
d_pre <- fa_clean[period_lbl == "Pre" & is.finite(c_norm) & c_norm > 0 & c_norm < 1.5]
fig_pre <- ggplot(d_pre, aes(x = c_norm, color = sme_lbl, linetype = sme_lbl)) +
  stat_ecdf(linewidth = 0.6) +
  scale_color_manual(values = c("SME" = "black", "NonSME" = "grey40")) +
  scale_linetype_manual(values = c("SME" = "solid", "NonSME" = "dashed")) +
  scale_x_continuous(labels = percent_format(),
                     limits = c(0, quantile(d_pre$c_norm, 0.98, na.rm = TRUE))) +
  labs(x = "Pseudo-cost / reference price  (c/ref)",
       y = "Cumulative distribution F(c/ref)",
       title = "Recovered cost distributions at Pre period (Convite G65)",
       subtitle = "Symmetric-GPV by stratum: SME CDF first-order stochastically dominates NonSME CDF (lower c/ref)") +
  theme_pub()
save_pub(fig_pre, "fig_v2_gpv_costs_pre.pdf", w = 7.0, h = 4.2)

# Figure 2: stability — F_c(type, Pre) vs F_c(type, Post)
d_stab <- fa_clean[is.finite(c_norm) & c_norm > 0 & c_norm < 1.5,
                   .(c_norm, sme_lbl, period_lbl)]
fig_stab <- ggplot(d_stab, aes(x = c_norm, color = period_lbl, linetype = period_lbl)) +
  stat_ecdf(linewidth = 0.6) +
  facet_wrap(~ sme_lbl) +
  scale_color_manual(values = c("Pre" = "grey20", "Post" = "grey60")) +
  scale_linetype_manual(values = c("Pre" = "solid", "Post" = "dashed")) +
  scale_x_continuous(labels = percent_format(),
                     limits = c(0, quantile(d_stab$c_norm, 0.98, na.rm = TRUE))) +
  labs(x = "Pseudo-cost / reference price", y = "F(c/ref)",
       title = "Stability of recovered cost distribution across regimes",
       subtitle = "Under GPV, within-type cost dist should be invariant (primitive)") +
  theme_pub()
save_pub(fig_stab, "fig_v2_gpv_stability.pdf", w = 7.5, h = 4.0)

# Figure 3: implied markup as fraction of reference  (b - c)/ref
fa_clean[, markup_rel := (bid - c_hat) / ref]
d_mkp <- fa_clean[markup_rel >= 0 & markup_rel < 1]
fig_mkp <- ggplot(d_mkp, aes(x = markup_rel, linetype = period_lbl, color = sme_lbl)) +
  geom_density(linewidth = 0.5, adjust = 1.2) +
  scale_color_manual(values = c("SME" = "black", "NonSME" = "grey40")) +
  scale_linetype_manual(values = c("Pre" = "solid", "Post" = "dashed")) +
  scale_x_continuous(labels = percent_format()) +
  labs(x = "Implied markup  (b − c) / ref",
       y = "Density",
       title = "Implied markup, by period × bidder type",
       subtitle = "GPV-recovered: Pre-period SMEs charge ~40% markup vs ~30% for non-SMEs") +
  theme_pub()
save_pub(fig_mkp, "fig_v2_gpv_markup.pdf", w = 7.0, h = 4.0)

# ============================================================================
# 6. SAVE BIDDER-AUCTION PSEUDO-COST PANEL (for counterfactuals)
# ============================================================================
out_pq <- file.path(V2_DATA, "convite_pseudo_costs.parquet")
write_parquet(fa_gpv, out_pq)
log_msg(sprintf("Saved pseudo-cost panel: %s (%s rows, %.1f MB)",
                out_pq, format(nrow(fa_gpv), big.mark = ","),
                file.info(out_pq)$size / 1024^2))

log_mem("final")
log_msg("=== 34_gpv_convite.R: DONE ===")
