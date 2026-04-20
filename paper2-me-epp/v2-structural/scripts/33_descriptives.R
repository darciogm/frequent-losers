# ============================================================================
# 33_descriptives.R — Sprint 1: structural diagnostics on the bid-level data
# ============================================================================
# Purpose: diagnose GPV feasibility on Convite G65 and characterize Pregão
# bidding patterns. Output feeds the model-choice decision in S2.
#
# GPV (Guerre-Perrigne-Vuong 2000) requires:
#   (A) Single sealed-bid round per firm per auction (Convite ✓, Pregão ✗)
#   (B) Independent private values (IPV)
#   (C) Symmetric bidders (or weak relaxation — Athey-Haile 2007)
#   (D) Risk-neutral bidders (testable via bid distribution shape)
#   (E) Reserve price known or irrelevant (we have ref_price)
#   (F) Bid function monotonic in cost (theorem: it is; testable via
#       nonparametric bid density)
#   (G) N ≥ 2 firms per auction (GPV estimator undefined at N=1)
#
# Outputs:
#   output/tables/tab_v2_desc_*.tex         (LaTeX summary tables)
#   output/figures/fig_v2_*.pdf             (grayscale publication figures)
#   logs/33_descriptives.log                (diagnostic narrative)
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
  library(fixest)
  library(scales)
})

setDTthreads(12)
log_msg("=== 33_descriptives.R — structural diagnostics ===")
log_mem("startup")

# ---- publication theme (aligned with v1 theme_pub) -------------------------
theme_pub <- function() {
  theme_bw(base_size = 9) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
      axis.line = element_line(color = "black", linewidth = 0.3),
      axis.ticks = element_line(color = "black", linewidth = 0.3),
      strip.background = element_rect(fill = "grey95", color = "black",
                                      linewidth = 0.3),
      strip.text = element_text(color = "black", face = "bold"),
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.title = element_text(size = 10, face = "bold")
    )
}
save_pub <- function(p, fn, w = 6.5, h = 4.0) {
  out <- file.path(V2_FIGS, fn)
  ggsave(out, p, width = w, height = h, device = cairo_pdf)
  log_msg("  saved ", out)
}

# ---- 1. Load --------------------------------------------------------------
log_msg("Loading bid-level parquets...")
conv <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
preg <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_pregao.parquet")))
log_msg(sprintf("  Convite: %s rows | Pregão: %s rows",
                format(nrow(conv), big.mark = ","),
                format(nrow(preg), big.mark = ",")))

# Combine for cross-modality diagnostics
both <- rbindlist(list(conv[, modality := "Convite"],
                       preg[, modality := "Pregão"]), use.names = TRUE)
both[, arm := fifelse(g65 == 1L, "G65", "Controls")]
both[, period := fifelse(Pre == 1L, "Pre", "Post")]
both[, cell := paste(modality, arm, period, sep = " / ")]
log_mem("after load")

# ---- 2. Collapse bids to one-per-firm-per-auction --------------------------
# In Convite this is already the case (bids_per_firm = 1.00).
# In Pregão, winner's progressive lowering bids get collapsed to the firm's
# final bid (minimum for reverse auction). Losers' final stand = their
# minimum observed bid.
log_msg("Collapsing to firm-auction level (min bid per firm × auction)...")
firm_au <- both[, .(
    bid     = min(bid_price, na.rm = TRUE),
    n_bids  = .N,
    won     = max(won, na.rm = TRUE),
    negot   = mean(negot_price, na.rm = TRUE),
    ref     = mean(ref_price,   na.rm = TRUE),
    sme     = max(sme_proxy, na.rm = TRUE),
    porte   = first(porte_bidder)
  ),
  by = .(modality, arm, period, g65, Pre, pharma,
         numerodaoc, codigoitem, data_oc_numb, codigofornecedor)]
log_msg(sprintf("  firm-auction rows: %s",
                format(nrow(firm_au), big.mark = ",")))

# Auction level: one row per auction
au <- firm_au[, .(
    n_firms   = uniqueN(codigofornecedor),
    mean_bid  = mean(bid, na.rm = TRUE),
    min_bid   = min(bid,  na.rm = TRUE),
    max_bid   = max(bid,  na.rm = TRUE),
    sd_bid    = sd(bid,   na.rm = TRUE),
    negot     = first(negot[won == 1L]),
    ref       = mean(ref, na.rm = TRUE),
    sme_share = mean(sme),
    sme_wins  = as.integer(any(won == 1L & sme == 1L))
  ),
  by = .(modality, arm, period, g65, Pre, pharma,
         numerodaoc, codigoitem, data_oc_numb)]
au[, has_winner := as.integer(!is.na(negot))]
au[, discount := 1 - (min_bid / ref)]   # price discount vs reference
au[, log_ref := log(ref)]
log_msg(sprintf("  auction rows: %s", format(nrow(au), big.mark = ",")))
log_mem("after collapse")

# ---- 3. DIAGNOSTIC: N per auction distribution ----------------------------
log_msg("Diagnostic 1: N per auction distribution by cell")
nfirms_tab <- au[, .(
    n_auctions = .N,
    mean_n     = round(mean(n_firms), 2),
    median_n   = as.numeric(median(n_firms)),
    pct_N1     = round(100 * mean(n_firms == 1L), 1),
    pct_N2     = round(100 * mean(n_firms == 2L), 1),
    pct_N3plus = round(100 * mean(n_firms >= 3L), 1),
    pct_N5plus = round(100 * mean(n_firms >= 5L), 1)
  ), by = .(modality, arm, period)][order(modality, arm, period)]
print(nfirms_tab)

# Save as TeX
fwrite(nfirms_tab, file.path(V2_TABLES, "tab_v2_nfirms.csv"))
sink(file.path(V2_TABLES, "tab_v2_nfirms.tex"))
cat("% Auto-generated by 33_descriptives.R\n")
cat("\\begin{tabular}{lllrrrrrr}\n\\toprule\n")
cat("Modality & Arm & Period & $N_\\text{auc}$ & $\\bar N$ & $\\text{med}\\,N$ &",
    "$\\%N{=}1$ & $\\%N{=}2$ & $\\%N{\\geq}5$ \\\\\n\\midrule\n")
for (i in seq_len(nrow(nfirms_tab))) {
  with(nfirms_tab[i], cat(
    modality, "&", arm, "&", period, "&",
    format(n_auctions, big.mark = ","), "&",
    sprintf("%.2f", mean_n), "&", median_n, "&",
    sprintf("%.1f", pct_N1), "&",
    sprintf("%.1f", pct_N2), "&",
    sprintf("%.1f", pct_N5plus), "\\\\\n"))
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()

# Figure 1: N distribution, truncated at 15
fig_n <- ggplot(au[n_firms <= 15], aes(x = n_firms)) +
  geom_histogram(binwidth = 1, fill = "grey30", color = "white", linewidth = 0.3) +
  facet_grid(arm ~ modality + period, scales = "free_y") +
  labs(x = "Number of unique firms per auction", y = "Auctions",
       title = "Distribution of bidders per auction (truncated at 15)") +
  theme_pub()
save_pub(fig_n, "fig_v2_nfirms.pdf", w = 7.5, h = 5.0)

# ---- 4. DIAGNOSTIC: Single-firm share (GPV unusable at N=1) ---------------
log_msg("Diagnostic 2: single-firm auctions (GPV-infeasible share)")
share_N1 <- au[, .(
    n_total      = .N,
    n_single     = sum(n_firms == 1L),
    pct_single   = round(100 * mean(n_firms == 1L), 2),
    n_GPV_usable = sum(n_firms >= 2L)
  ), by = .(modality, arm, period)][order(modality, arm, period)]
print(share_N1)

# ---- 5. DIAGNOSTIC: Bid discount distribution -----------------------------
log_msg("Diagnostic 3: bid discount distribution")
au_valid <- au[is.finite(discount) & discount >= -0.2 & discount <= 1]
log_msg(sprintf("  valid discount rows: %s / %s",
                format(nrow(au_valid), big.mark = ","),
                format(nrow(au),       big.mark = ",")))

fig_disc <- ggplot(au_valid, aes(x = discount, linetype = period, color = arm)) +
  geom_density(linewidth = 0.5) +
  facet_wrap(~ modality, scales = "free_y") +
  scale_color_manual(values = c("Controls" = "grey40", "G65" = "black")) +
  scale_linetype_manual(values = c("Pre" = "dashed", "Post" = "solid")) +
  scale_x_continuous(labels = percent, limits = c(-0.2, 1)) +
  labs(x = "Winning-bid discount (1 - min_bid/ref)",
       y = "Density",
       title = "Bid discount density, by modality × arm × period") +
  theme_pub() +
  theme(legend.position = "bottom")
save_pub(fig_disc, "fig_v2_discount_density.pdf", w = 7.0, h = 4.0)

# ---- 6. DIAGNOSTIC: Within-auction SME bid gap -----------------------------
# Test for asymmetric bidders: do SME and non-SME firms bid differently
# WITHIN the same auction? Fixed-effects regression on firm-auction level.
log_msg("Diagnostic 4: within-auction SME vs non-SME bid gap")

# We restrict to auctions with BOTH at least one SME bidder and at least one
# non-SME bidder (i.e., within-auction variation on the SME indicator),
# discard non-positive bids/refs that break the log, and winsorize the
# outcome at 1%/99% to neutralize the bid=0 mechanical spike visible in
# the discount density.
fa <- firm_au[is.finite(bid) & bid > 0 & is.finite(ref) & ref > 0]
fa[, log_bid_rel := log(bid / ref)]
fa[, auction_id  := paste0(numerodaoc, "/", codigoitem)]

# Drop outliers (bid/ref ratio outside 1%-99% within modality)
fa[, q_lo := quantile(log_bid_rel, 0.01, na.rm = TRUE), by = modality]
fa[, q_hi := quantile(log_bid_rel, 0.99, na.rm = TRUE), by = modality]
fa <- fa[log_bid_rel >= q_lo & log_bid_rel <= q_hi]

# Keep only auctions with within-auction SME variation (both types present)
fa_var <- fa[, .(sme_var = uniqueN(sme) > 1L), by = auction_id][sme_var == TRUE]
fa_ok  <- fa[auction_id %in% fa_var$auction_id]

sme_gap <- list()
for (mod in c("Convite", "Pregão")) {
  for (arm_i in c("Controls", "G65")) {
    for (per in c("Pre", "Post")) {
      sub <- fa_ok[modality == mod & arm == arm_i & period == per]
      if (nrow(sub) < 200 || uniqueN(sub$auction_id) < 100) next
      tryCatch({
        m <- feols(log_bid_rel ~ sme | auction_id, data = sub,
                   cluster = ~auction_id, lean = TRUE)
        sme_gap[[paste(mod, arm_i, per, sep = "/")]] <- data.table(
          modality = mod, arm = arm_i, period = per,
          n_firm_auc = nrow(sub),
          n_auc      = uniqueN(sub$auction_id),
          beta_sme   = as.numeric(coef(m)["sme"]),
          se_sme     = as.numeric(se(m)["sme"]),
          tstat      = as.numeric(coef(m)["sme"] / se(m)["sme"])
        )
      }, error = function(e) NULL)
    }
  }
}
sme_gap_tab <- rbindlist(sme_gap, use.names = TRUE)
print(sme_gap_tab)
fwrite(sme_gap_tab, file.path(V2_TABLES, "tab_v2_sme_gap.csv"))

# ---- 7. DIAGNOSTIC: Ref price distribution --------------------------------
log_msg("Diagnostic 5: ref price distribution (identifies auction-level heterogeneity)")
ref_stats <- au[is.finite(ref) & ref > 0, .(
    n        = .N,
    q10      = round(quantile(ref, 0.10), 2),
    q50      = round(quantile(ref, 0.50), 2),
    q90      = round(quantile(ref, 0.90), 2),
    mean_ref = round(mean(ref), 2),
    cv       = round(sd(log(ref)), 2)  # dispersion in log-scale
  ), by = .(modality, arm, period)][order(modality, arm, period)]
print(ref_stats)
fwrite(ref_stats, file.path(V2_TABLES, "tab_v2_ref_stats.csv"))

# Figure: log(ref) densities
fig_ref <- ggplot(au[is.finite(ref) & ref > 0],
                  aes(x = log(ref), linetype = period, color = arm)) +
  geom_density(linewidth = 0.5) +
  facet_wrap(~ modality) +
  scale_color_manual(values = c("Controls" = "grey40", "G65" = "black")) +
  scale_linetype_manual(values = c("Pre" = "dashed", "Post" = "solid")) +
  labs(x = "log(reference price, R$)", y = "Density",
       title = "Auction-level reference price dispersion") +
  theme_pub()
save_pub(fig_ref, "fig_v2_ref_density.pdf", w = 7.0, h = 4.0)

# ---- 8. DIAGNOSTIC: Pregão trajectory depth --------------------------------
log_msg("Diagnostic 6: Pregão iterative trajectory depth per firm × auction")
preg_traj <- preg[, .(n_bids_per_firm = .N),
                  by = .(numerodaoc, codigoitem, codigofornecedor, g65, Pre)]
traj_tab <- preg_traj[, .(
    n_firm_auc_obs = .N,
    mean_rounds    = round(mean(n_bids_per_firm), 2),
    median_rounds  = as.numeric(median(n_bids_per_firm)),
    q90_rounds     = as.numeric(quantile(n_bids_per_firm, 0.90)),
    max_rounds     = as.numeric(max(n_bids_per_firm)),
    pct_single     = round(100 * mean(n_bids_per_firm == 1L), 1),
    pct_3plus      = round(100 * mean(n_bids_per_firm >= 3L), 1)
  ), by = .(g65, Pre)][order(g65, Pre)]
print(traj_tab)
fwrite(traj_tab, file.path(V2_TABLES, "tab_v2_pregao_trajectory.csv"))

# Figure: iterative rounds density (Pregão only, truncated at 20)
fig_traj <- ggplot(preg_traj[n_bids_per_firm <= 20],
                   aes(x = n_bids_per_firm,
                       linetype = factor(Pre, labels = c("Post", "Pre")),
                       color    = factor(g65, labels = c("Controls", "G65")))) +
  geom_density(linewidth = 0.5, adjust = 1.5) +
  scale_color_manual(values = c("Controls" = "grey40", "G65" = "black")) +
  scale_linetype_manual(values = c("Pre" = "dashed", "Post" = "solid")) +
  labs(x = "Bids per firm per auction (Pregão, iterative phase 2)",
       y = "Density",
       title = "Iterative bidding depth in Pregão auctions") +
  theme_pub()
save_pub(fig_traj, "fig_v2_pregao_trajectory.pdf", w = 7.0, h = 4.0)

# ---- 9. Final winning bid flag (Pregão) ------------------------------------
log_msg("Diagnostic 7: final winning bid identification in Pregão")
# In bid_level_with_prices, the WINNING auction's TRUE final bid is the row
# where won == 1 AND bid_price == negot_price. Winner's intermediate (losing)
# bids are also marked won=1 but have bid_price > negot_price.
preg[, is_final_win := as.integer(won == 1L &
                                  !is.na(negot_price) &
                                  abs(bid_price - negot_price) < 1e-6)]
final_win_summary <- preg[won == 1L, .(
    n_winning_rows   = .N,
    n_final_wins     = sum(is_final_win),
    pct_final        = round(100 * mean(is_final_win), 1)
  ), by = .(g65, Pre)][order(g65, Pre)]
print(final_win_summary)

# ---- 10. GPV feasibility checklist ----------------------------------------
log_msg("")
log_msg("================================================================")
log_msg("GPV FEASIBILITY CHECKLIST (Convite G65)")
log_msg("================================================================")

checklist <- function(name, passed, detail) {
  symbol <- if (passed) "[PASS]" else "[FAIL]"
  log_msg(sprintf("  %s %s — %s", symbol, name, detail))
}

conv_g65 <- au[modality == "Convite" & arm == "G65"]
n_G65_auc <- nrow(conv_g65)
pct_single_G65 <- mean(conv_g65$n_firms == 1L)
pct_N2plus_G65 <- mean(conv_g65$n_firms >= 2L)
median_N_G65   <- median(conv_g65$n_firms)

conv_firm_nbids <- firm_au[modality == "Convite" & arm == "G65", n_bids]
pct_single_bid <- mean(conv_firm_nbids == 1L)
checklist("(A) Single sealed bid/firm/auction",
          pct_single_bid >= 0.95,
          sprintf("%.2f%% of Convite G65 firm-auctions have exactly 1 bid (max = %d; outliers filterable)",
                  100 * pct_single_bid,
                  max(conv_firm_nbids)))

checklist("(G) N >= 2 per auction",
          pct_N2plus_G65 >= 0.5,
          sprintf("%.1f%% of Convite G65 auctions have N>=2 (%s auctions GPV-usable out of %s)",
                  100 * pct_N2plus_G65,
                  format(sum(conv_g65$n_firms >= 2L), big.mark = ","),
                  format(n_G65_auc, big.mark = ",")))

checklist("(E) Reserve price observed",
          mean(is.finite(au[modality == "Convite" & arm == "G65", ref])) > 0.8,
          sprintf("%.1f%% of Convite G65 auctions have finite ref_price",
                  100 * mean(is.finite(au[modality == "Convite" & arm == "G65", ref]))))

sample_N <- conv_g65[n_firms >= 2L]
sd_med <- median(sample_N$sd_bid, na.rm = TRUE)
mean_med <- median(sample_N$mean_bid, na.rm = TRUE)
cv_med <- ifelse(mean_med > 0, sd_med / mean_med, NA)
checklist("(F) Non-trivial bid dispersion within auction",
          !is.na(cv_med) && cv_med > 0.05,
          sprintf("median within-auction CV of bids = %.3f (>0.05 suggests GPV has identifying variation)",
                  cv_med))

checklist("Sample size for GPV",
          n_G65_auc > 5000,
          sprintf("Convite G65 auctions = %s (Krasnokutskaya 2011 used ~2k)",
                  format(n_G65_auc, big.mark = ",")))

log_msg("")
log_msg("================================================================")
log_msg("Pregão: iterative format — GPV does not apply directly.")
log_msg("Use Haile-Tamer (2003) bounds or Carvalho (2019) random-close model.")
log_msg(sprintf("  G65 Pregão auctions: %s",
                format(nrow(au[modality == "Pregão" & arm == "G65"]), big.mark = ",")))
log_msg(sprintf("  Pre/Post split:  Pre=%s, Post=%s",
                format(sum(au$modality == "Pregão" & au$g65 == 1L & au$Pre == 1L), big.mark = ","),
                format(sum(au$modality == "Pregão" & au$g65 == 1L & au$Pre == 0L), big.mark = ",")))
log_msg("================================================================")
log_mem("final")
log_msg("=== 33_descriptives.R: DONE ===")

# Save audit CSVs
fwrite(nfirms_tab,        file.path(V2_TABLES, "tab_v2_nfirms.csv"))
fwrite(share_N1,          file.path(V2_TABLES, "tab_v2_single_firm.csv"))
fwrite(sme_gap_tab,       file.path(V2_TABLES, "tab_v2_sme_gap.csv"))
fwrite(ref_stats,         file.path(V2_TABLES, "tab_v2_ref_stats.csv"))
fwrite(traj_tab,          file.path(V2_TABLES, "tab_v2_pregao_trajectory.csv"))
fwrite(final_win_summary, file.path(V2_TABLES, "tab_v2_final_win.csv"))
