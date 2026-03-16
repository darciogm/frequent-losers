#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════
# mechanism_evidence.R — Bid rotation + bid inflation tests
# Addresses external referee Concern 5: mechanism evidence suggestive
# ═══════════════════════════════════════════════════════════════════
cat("=== MECHANISM EVIDENCE ===\n\n")
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(fixest); library(ggplot2)
})
setDTthreads(16L)
BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT_T <- file.path(BASE, "work/v8/tables")
OUT_F <- file.path(BASE, "work/v8/images")
cb <- c("#0072B2","#D55E00","#009E73","#CC79A7")

# ── Load data ─────────────────────────────────────────────────────
cat("Loading data...\n")
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet"),
  col_select=c("códigofornecedor","numerodaoc","códigoitem","won")))
setnames(ftm, c("firm_id","oc_code","item_code","won"))
ftm[, firm_id := as.character(firm_id)]

fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value=TRUE, ignore.case=TRUE)
if (length(fp_col) > 0) setnames(fp, fp_col[1], "firm_id")
fp[, firm_id := as.character(firm_id)]
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
threshold <- q[2] + 1.5 * (q[3] - q[1])
fl_ids <- fp[tenders_count > threshold, firm_id]

ftm[, is_fl := as.integer(firm_id %in% fl_ids)]
cat("FTM rows:", formatC(nrow(ftm), big.mark=","), "\n")
cat("FL firms:", length(fl_ids), "\n\n")

# ═══════════════════════════════════════════════════════════════════
# TEST 1: WINNER PERSISTENCE (designated winner hypothesis)
# For each FL firm: who wins the tenders they participate in?
# If FL is a cover bidder for cartel j*, then j* should win
# disproportionately often across FL's tenders.
# ═══════════════════════════════════════════════════════════════════
cat("=== TEST 1: Winner Persistence ===\n")

# Get winner per tender
winners <- ftm[won == 1, .(winner_id = firm_id[1]), by=.(oc_code, item_code)]

# For each FL firm: find tenders they participate in + who won
fl_tenders <- ftm[is_fl == 1, .(firm_id, oc_code, item_code)]
fl_tenders <- merge(fl_tenders, winners, by=c("oc_code","item_code"), all.x=FALSE)

# For each FL firm: compute winner HHI (concentration of winners)
fl_winner_conc <- fl_tenders[, {
  w <- table(winner_id)
  shares <- as.numeric(w) / sum(w)
  hhi <- sum(shares^2)
  top_winner_share <- max(shares)
  n_unique_winners <- length(w)
  .(winner_hhi = hhi, top_winner_share = top_winner_share,
    n_unique_winners = n_unique_winners, n_tenders = .N)
}, by=firm_id]
fl_winner_conc <- fl_winner_conc[n_tenders >= 5]  # at least 5 tenders

cat("FL firms with ≥5 tenders:", nrow(fl_winner_conc), "\n")
cat("  Mean winner HHI:         ", round(mean(fl_winner_conc$winner_hhi), 4), "\n")
cat("  Mean top-winner share:   ", round(mean(fl_winner_conc$top_winner_share), 4), "\n")
cat("  Mean unique winners:     ", round(mean(fl_winner_conc$n_unique_winners), 1), "\n")

# Comparison: non-FL always-losers (same computation)
nonfl_al_ids <- fp[tenders_count <= threshold & tenders_count >= 5, firm_id]
nonfl_tenders <- ftm[firm_id %in% nonfl_al_ids, .(firm_id, oc_code, item_code)]
nonfl_tenders <- merge(nonfl_tenders, winners, by=c("oc_code","item_code"), all.x=FALSE)

nonfl_winner_conc <- nonfl_tenders[, {
  w <- table(winner_id)
  shares <- as.numeric(w) / sum(w)
  hhi <- sum(shares^2)
  top_winner_share <- max(shares)
  n_unique_winners <- length(w)
  .(winner_hhi = hhi, top_winner_share = top_winner_share,
    n_unique_winners = n_unique_winners, n_tenders = .N)
}, by=firm_id]
nonfl_winner_conc <- nonfl_winner_conc[n_tenders >= 5]

cat("\nNon-FL always-losers (≥5 tenders):", nrow(nonfl_winner_conc), "\n")
cat("  Mean winner HHI:         ", round(mean(nonfl_winner_conc$winner_hhi), 4), "\n")
cat("  Mean top-winner share:   ", round(mean(nonfl_winner_conc$top_winner_share), 4), "\n")
cat("  Mean unique winners:     ", round(mean(nonfl_winner_conc$n_unique_winners), 1), "\n")

# T-test
t_hhi <- t.test(fl_winner_conc$winner_hhi, nonfl_winner_conc$winner_hhi)
t_top <- t.test(fl_winner_conc$top_winner_share, nonfl_winner_conc$top_winner_share)
cat(sprintf("\n  t-test winner HHI: FL=%.4f vs non-FL=%.4f, diff=%.4f, p=%.6f\n",
    t_hhi$estimate[1], t_hhi$estimate[2],
    t_hhi$estimate[1]-t_hhi$estimate[2], t_hhi$p.value))
cat(sprintf("  t-test top-winner: FL=%.4f vs non-FL=%.4f, diff=%.4f, p=%.6f\n",
    t_top$estimate[1], t_top$estimate[2],
    t_top$estimate[1]-t_top$estimate[2], t_top$p.value))

# ═══════════════════════════════════════════════════════════════════
# TEST 2: REPEATED FL-WINNER PAIRS
# Do specific FL firms repeatedly co-bid with specific winners?
# ═══════════════════════════════════════════════════════════════════
cat("\n=== TEST 2: Repeated FL-Winner Pairs ===\n")

# For each FL firm × winner pair: count shared tenders
fl_winner_pairs <- fl_tenders[, .N, by=.(firm_id, winner_id)]
setnames(fl_winner_pairs, "N", "n_shared")

cat("FL-winner pairs:", formatC(nrow(fl_winner_pairs), big.mark=","), "\n")
cat("  Mean shared tenders:", round(mean(fl_winner_pairs$n_shared), 2), "\n")
cat("  Pairs with ≥5 shared:", sum(fl_winner_pairs$n_shared >= 5), "\n")
cat("  Pairs with ≥10 shared:", sum(fl_winner_pairs$n_shared >= 10), "\n")
cat("  Pairs with ≥20 shared:", sum(fl_winner_pairs$n_shared >= 20), "\n")
cat("  Max shared:", max(fl_winner_pairs$n_shared), "\n")

# Compare with non-FL pairs
nonfl_winner_pairs <- nonfl_tenders[, .N, by=.(firm_id, winner_id)]
setnames(nonfl_winner_pairs, "N", "n_shared")
cat("\nNon-FL loser-winner pairs:", formatC(nrow(nonfl_winner_pairs), big.mark=","), "\n")
cat("  Mean shared:", round(mean(nonfl_winner_pairs$n_shared), 2), "\n")
cat("  Pairs with ≥5 shared:", sum(nonfl_winner_pairs$n_shared >= 5), "\n")

# Distribution comparison
cat("\nDistribution of shared tenders per pair:\n")
cat("  FL:     ", paste(round(quantile(fl_winner_pairs$n_shared, c(0.5,0.9,0.95,0.99)),1), collapse=", "), "\n")
cat("  Non-FL: ", paste(round(quantile(nonfl_winner_pairs$n_shared, c(0.5,0.9,0.95,0.99)),1), collapse=", "), "\n")

# ═══════════════════════════════════════════════════════════════════
# TEST 3: BID INFLATION — FL bids above competitive benchmark
# ═══════════════════════════════════════════════════════════════════
cat("\n=== TEST 3: Bid Inflation ===\n")

bl <- as.data.table(read_parquet(file.path(BASE, "v3/data/processed/bid_level_analysis.parquet"),
  col_select=c("firm_id","oc_code","item_code","bid_price","negot_price","won","is_fl")))

# Get winning price (competitive benchmark)
win_prices <- bl[won == 1L & !is.na(negot_price) & negot_price > 0,
                 .(win_price = min(negot_price)), by=.(oc_code, item_code)]

# Compute bid-to-winner ratio for losing bids
losing <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
losing <- merge(losing, win_prices, by=c("oc_code","item_code"), all.x=FALSE)
losing[, bid_ratio := bid_price / win_price]
losing[, log_ratio := log(bid_ratio)]

# Compare FL vs non-FL losing bids
cat("FL losing bids:\n")
cat("  Mean bid/winner ratio:   ", round(mean(losing[is_fl==1, bid_ratio], na.rm=TRUE), 3), "\n")
cat("  Median bid/winner ratio: ", round(median(losing[is_fl==1, bid_ratio], na.rm=TRUE), 3), "\n")
cat("  % above winner (ratio>1):", round(100*mean(losing[is_fl==1, bid_ratio] > 1, na.rm=TRUE), 1), "%\n")

cat("Non-FL losing bids:\n")
cat("  Mean bid/winner ratio:   ", round(mean(losing[is_fl==0, bid_ratio], na.rm=TRUE), 3), "\n")
cat("  Median bid/winner ratio: ", round(median(losing[is_fl==0, bid_ratio], na.rm=TRUE), 3), "\n")
cat("  % above winner (ratio>1):", round(100*mean(losing[is_fl==0, bid_ratio] > 1, na.rm=TRUE), 1), "%\n")

# Regression: log(bid/winner) on is_fl with item+year FE
losing[, year := as.integer(substr(oc_code, 12, 15))]
m_inf <- feols(log_ratio ~ is_fl | item_code + year, data=losing, cluster=~item_code)
cat(sprintf("\nBid inflation regression (log ratio ~ is_fl | item + year):\n"))
cat(sprintf("  FL coefficient: %.4f (SE=%.4f, p=%.6f)\n",
    coef(m_inf)["is_fl"], sqrt(vcov(m_inf)["is_fl","is_fl"]),
    coeftable(m_inf)["is_fl","Pr(>|t|)"]))
cat(sprintf("  Interpretation: FL bids are %.1f%% higher relative to winner\n",
    100*(exp(coef(m_inf)["is_fl"])-1)))

# ── Figure: bid ratio distribution ────────────────────────────────
cat("\nGenerating figure...\n")
set.seed(42)
plot_data <- rbind(
  losing[is_fl==1][sample(.N, min(50000,.N))][, .(log_ratio, group="FL firms")],
  losing[is_fl==0][sample(.N, min(50000,.N))][, .(log_ratio, group="Non-FL losers")]
)

p <- ggplot(plot_data[abs(log_ratio) < 3], aes(x=log_ratio, fill=group, color=group)) +
  geom_density(alpha=0.3, linewidth=0.8) +
  geom_vline(xintercept=0, linetype="dashed", color="gray40") +
  scale_fill_manual(values=cb[1:2]) +
  scale_color_manual(values=cb[1:2]) +
  labs(x="Log(bid / winning price)", y="Density", fill=NULL, color=NULL) +
  theme_bw(base_size=12) +
  theme(legend.position=c(0.8, 0.8),
        legend.background=element_rect(fill="white", color="gray80"),
        panel.grid.minor=element_blank())
ggsave(file.path(OUT_F, "fig_bid_inflation.pdf"), p,
       width=7, height=4.5, device=cairo_pdf)
cat("Figure saved.\n")

# Save results
write.csv(data.frame(
  test = c("fl_winner_hhi","nonfl_winner_hhi","hhi_diff_p",
           "fl_top_winner_share","nonfl_top_winner_share",
           "fl_bid_ratio_mean","nonfl_bid_ratio_mean","bid_inflation_coef"),
  value = round(c(mean(fl_winner_conc$winner_hhi), mean(nonfl_winner_conc$winner_hhi),
    t_hhi$p.value, mean(fl_winner_conc$top_winner_share),
    mean(nonfl_winner_conc$top_winner_share),
    mean(losing[is_fl==1, bid_ratio], na.rm=TRUE),
    mean(losing[is_fl==0, bid_ratio], na.rm=TRUE),
    coef(m_inf)["is_fl"]), 5)
), file.path(OUT_T, "mechanism_tests.csv"), row.names=FALSE)

cat("\n=== DONE ===\n")
