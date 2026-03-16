#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════
# ground_truth_robustness.R — Co-participation vs cover-bidder behavior
# Addresses external referee Concern 4
# ═══════════════════════════════════════════════════════════════════
cat("=== GROUND TRUTH ROBUSTNESS ===\n\n")
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(fixest)
})
setDTthreads(16L)
BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"

# ── Load data ─────────────────────────────────────────────────────
cat("Loading data...\n")
bl <- as.data.table(read_parquet(file.path(BASE, "v3/data/processed/bid_level_analysis.parquet"),
  col_select=c("firm_id","oc_code","item_code","bid_price","negot_price","won","is_fl")))

# Winners per tender
winners <- bl[won == 1L & !is.na(negot_price) & negot_price > 0,
              .(win_price = min(negot_price)), by=.(oc_code, item_code)]

# CADE firms
cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade_col <- grep("fornecedor|firm", names(cade), value=TRUE, ignore.case=TRUE)
if (length(cade_col) > 0 && !"firm_id" %in% names(cade))
  setnames(cade, cade_col[1], "firm_id")
cade[, firm_id := as.character(trimws(firm_id))]
cade_fl_ids <- unique(cade$firm_id)

# CADE convicted firms (the cartelists themselves)
cade_conv <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
conv_col <- grep("fornecedor|firm|cnpj", names(cade_conv), value=TRUE, ignore.case=TRUE)
if (length(conv_col) > 0 && !"firm_id" %in% names(cade_conv))
  setnames(cade_conv, conv_col[1], "firm_id")
cade_conv[, firm_id := as.character(trimws(firm_id))]
convicted_ids <- unique(cade_conv$firm_id)
cat("  CADE-convicted firms:", length(convicted_ids), "\n")
cat("  FL firms co-bidding with CADE:", length(cade_fl_ids), "\n")

# Always-losers and FL
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value=TRUE, ignore.case=TRUE)
if (length(fp_col) > 0) setnames(fp, fp_col[1], "firm_id")
fp[, firm_id := as.character(firm_id)]
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
threshold <- q[2] + 1.5 * (q[3] - q[1])
fl_ids <- fp[tenders_count > threshold, firm_id]

# ═══════════════════════════════════════════════════════════════════
# TEST 1: BID BEHAVIOR IN CADE-PRESENT TENDERS
# Do FL bids look like cover bids or genuine bids?
# ═══════════════════════════════════════════════════════════════════
cat("\n=== TEST 1: FL bid behavior in CADE-present tenders ===\n")

# Find tenders with CADE-convicted firms
bl[, is_convicted := as.integer(firm_id %in% convicted_ids)]
cade_tenders <- bl[is_convicted == 1, unique(paste0(oc_code, ":", item_code))]
bl[, tender_key := paste0(oc_code, ":", item_code)]
bl[, in_cade_tender := as.integer(tender_key %in% cade_tenders)]

cat("  Tenders with convicted firms:", length(cade_tenders), "\n")
cat("  Bids in CADE tenders:", sum(bl$in_cade_tender), "\n")

# In CADE tenders: compare FL losing bids vs non-FL losing bids
cade_losing <- bl[in_cade_tender == 1 & won == 0L & !is.na(bid_price) & bid_price > 0]
cade_losing <- merge(cade_losing, winners, by=c("oc_code","item_code"), all.x=FALSE)
cade_losing[, log_spread := log(bid_price) - log(win_price)]
cade_losing[, is_fl_firm := as.integer(firm_id %in% fl_ids)]

cat("  FL losing bids in CADE tenders:", sum(cade_losing$is_fl_firm), "\n")
cat("  Non-FL losing bids in CADE tenders:", sum(1-cade_losing$is_fl_firm), "\n")

if (sum(cade_losing$is_fl_firm) >= 30) {
  # Bid spread comparison
  fl_spread <- cade_losing[is_fl_firm == 1, log_spread]
  nonfl_spread <- cade_losing[is_fl_firm == 0, log_spread]

  cat("\n  FL bids in CADE tenders:\n")
  cat("    Mean log-spread:    ", round(mean(fl_spread, na.rm=TRUE), 4), "\n")
  cat("    SD log-spread:      ", round(sd(fl_spread, na.rm=TRUE), 4), "\n")
  cat("    % above winner:     ", round(100*mean(fl_spread > 0, na.rm=TRUE), 1), "%\n")

  cat("  Non-FL bids in CADE tenders:\n")
  cat("    Mean log-spread:    ", round(mean(nonfl_spread, na.rm=TRUE), 4), "\n")
  cat("    SD log-spread:      ", round(sd(nonfl_spread, na.rm=TRUE), 4), "\n")
  cat("    % above winner:     ", round(100*mean(nonfl_spread > 0, na.rm=TRUE), 1), "%\n")

  # t-test on spread
  t_spread <- t.test(fl_spread, nonfl_spread)
  cat(sprintf("\n  t-test (spread): diff=%.4f, t=%.2f, p=%.4f\n",
      t_spread$estimate[1]-t_spread$estimate[2], t_spread$statistic, t_spread$p.value))

  # KS test on bid distributions
  ks <- ks.test(fl_spread, nonfl_spread)
  cat(sprintf("  KS test: D=%.4f, p=%.6f\n", ks$statistic, ks$p.value))

  cover_bid_test1 <- TRUE
} else {
  cat("  Insufficient FL bids in CADE tenders for test\n")
  cover_bid_test1 <- FALSE
}

# ═══════════════════════════════════════════════════════════════════
# TEST 2: CO-PARTICIPATION INTENSITY
# FL-CADE pairs share more tenders than non-FL-CADE pairs?
# ═══════════════════════════════════════════════════════════════════
cat("\n=== TEST 2: Co-participation intensity ===\n")

# For each always-loser: count shared tenders with convicted firms
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet"),
  col_select=c("códigofornecedor","numerodaoc")))
setnames(ftm, c("firm_id","oc_code"))
ftm[, firm_id := as.character(firm_id)]

# Tenders with convicted firms
conv_ocs <- ftm[firm_id %in% convicted_ids, unique(oc_code)]
cat("  OC codes with convicted firms:", length(conv_ocs), "\n")

# For each always-loser: count how many convicted-firm tenders they also appear in
al_ftm <- ftm[firm_id %in% fp$firm_id]
al_ftm[, in_conv_tender := as.integer(oc_code %in% conv_ocs)]

intensity <- al_ftm[, .(
  n_shared_tenders = sum(in_conv_tender),
  n_total_tenders = .N,
  share_in_conv = mean(in_conv_tender)
), by=firm_id]

intensity[, is_fl := as.integer(firm_id %in% fl_ids)]
intensity <- merge(intensity, fp[, .(firm_id, tenders_count)], by="firm_id", all.x=TRUE)

cat("  FL firms: mean shared tenders =",
    round(intensity[is_fl==1, mean(n_shared_tenders)], 2),
    "| share =", round(intensity[is_fl==1, mean(share_in_conv)], 4), "\n")
cat("  Non-FL always-losers: mean shared =",
    round(intensity[is_fl==0, mean(n_shared_tenders)], 2),
    "| share =", round(intensity[is_fl==0, mean(share_in_conv)], 4), "\n")

# Conditional on participation count (controls for mechanical effect)
# Regress share_in_conv on is_fl controlling for log(tenders_count)
intensity[tenders_count > 0, log_tenders := log(tenders_count)]
m_int <- lm(share_in_conv ~ is_fl + log_tenders, data=intensity[!is.na(log_tenders)])
cat(sprintf("\n  Regression: share_in_conv ~ is_fl + log(tenders)\n"))
cat(sprintf("    is_fl: %.6f (SE=%.6f, p=%.4f)\n",
    coef(m_int)["is_fl"], summary(m_int)$coefficients["is_fl","Std. Error"],
    summary(m_int)$coefficients["is_fl","Pr(>|t|)"]))
cat(sprintf("    Interpretation: FL firms have %.2f pp higher share of tenders\n",
    100*coef(m_int)["is_fl"]))
cat("    in convicted-firm markets, CONDITIONAL on participation count\n")

# ═══════════════════════════════════════════════════════════════════
# TEST 3: ALTERNATIVE GROUND TRUTH — BY EXCHANGEABILITY FLAGS
# ═══════════════════════════════════════════════════════════════════
cat("\n=== TEST 3: Alternative ground truth (bid-pattern flags) ===\n")

# Flag firms whose bid spread is in the structural cover-bid range
# (epsilon_hat ± 1 SD: 0.831 ± 1.187 → [-0.36, 2.02])
losing_all <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
losing_all <- merge(losing_all, winners, by=c("oc_code","item_code"), all.x=FALSE)
losing_all[, log_spread := log(bid_price) - log(win_price)]

firm_spread <- losing_all[, .(
  mean_spread = mean(log_spread, na.rm=TRUE),
  sd_spread = sd(log_spread, na.rm=TRUE),
  n_bids = .N
), by=firm_id]

# Structural flag: mean spread within Regime 2 range AND low SD
EPS <- 0.831; SIGMA_C <- 1.187
firm_spread[, structural_flag := as.integer(
  mean_spread > 0 &
  mean_spread < EPS + 2*SIGMA_C &
  sd_spread < SIGMA_C * 1.5 &
  n_bids >= 5
)]

al_spread <- firm_spread[firm_id %in% fp$firm_id]
al_spread[, is_fl := as.integer(firm_id %in% fl_ids)]
al_spread[, is_cade := as.integer(firm_id %in% cade_fl_ids)]

cat("  Always-losers with bid data:", nrow(al_spread), "\n")
cat("  Structural flag positive:", sum(al_spread$structural_flag, na.rm=TRUE), "\n")

# Cross-tabulate: FL × structural flag → CADE overlap
cat("\n  CADE overlap rates:\n")
tab <- al_spread[, .(
  n = .N,
  n_cade = sum(is_cade),
  pct_cade = round(100*mean(is_cade), 2)
), by=.(is_fl, structural_flag)]
print(tab[order(-is_fl, -structural_flag)])

cat("\n  Key comparison:\n")
both <- al_spread[is_fl==1 & structural_flag==1]
fl_only <- al_spread[is_fl==1 & structural_flag==0]
struct_only <- al_spread[is_fl==0 & structural_flag==1]
neither <- al_spread[is_fl==0 & structural_flag==0]

cat(sprintf("    FL + structural flag:  %.2f%% CADE overlap (n=%d)\n",
    100*mean(both$is_cade), nrow(both)))
cat(sprintf("    FL only:               %.2f%% CADE overlap (n=%d)\n",
    100*mean(fl_only$is_cade), nrow(fl_only)))
cat(sprintf("    Structural flag only:  %.2f%% CADE overlap (n=%d)\n",
    100*mean(struct_only$is_cade), nrow(struct_only)))
cat(sprintf("    Neither:               %.2f%% CADE overlap (n=%d)\n",
    100*mean(neither$is_cade), nrow(neither)))

# Save results
write.csv(data.frame(
  test = c("test1_fl_spread_cade","test1_nonfl_spread_cade",
           "test2_fl_share_conv","test2_nonfl_share_conv","test2_fl_coef",
           "test3_fl_struct_cade","test3_fl_only_cade","test3_struct_only_cade","test3_neither_cade"),
  value = c(
    if(cover_bid_test1) round(mean(fl_spread, na.rm=TRUE), 4) else NA,
    if(cover_bid_test1) round(mean(nonfl_spread, na.rm=TRUE), 4) else NA,
    round(intensity[is_fl==1, mean(share_in_conv)], 6),
    round(intensity[is_fl==0, mean(share_in_conv)], 6),
    round(coef(m_int)["is_fl"], 6),
    round(100*mean(both$is_cade), 2),
    round(100*mean(fl_only$is_cade), 2),
    round(100*mean(struct_only$is_cade), 2),
    round(100*mean(neither$is_cade), 2))
), file.path(BASE, "work/v8/tables/ground_truth_tests.csv"), row.names=FALSE)

cat("\n=== DONE ===\n")
