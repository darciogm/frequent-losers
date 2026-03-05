# ============================================================================
# 01_data_prep.R — Data loading, merging, variable creation (v2)
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Heavily reuses scripts/01_clean.R from v1. Additions:
#   - market_id := paste0(item_code, "_", pbu_code) for DiD panel
#   - cover_tender / cover_intensity aliases
#   - first_fl_year at market_id level
#   - Caches to /tmp/p3v2_prepared.rds
# ============================================================================

cat("=== 01_data_prep.R: Data preparation (v2) ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ============================================================================
# Phase A: Load parquet datasets (from v1 data/processed/)
# ============================================================================

cat("  Loading BEC_collapse_final.parquet...\n")
bec <- as.data.table(read_parquet(file.path(DATA_V1, "BEC_collapse_final.parquet")))
cat("  BEC rows:", pfmt_int(nrow(bec)), " cols:", ncol(bec), "\n")

cat("  Loading LOSERS_rebuilt.parquet...\n")
losers <- as.data.table(read_parquet(file.path(DATA_V1, "LOSERS_rebuilt.parquet")))
cat("  LOSERS rows:", pfmt_int(nrow(losers)), "\n")

cat("  Loading FREQ_PARTICIP_rebuilt.parquet...\n")
freq_particip <- as.data.table(read_parquet(file.path(DATA_V1, "FREQ_PARTICIP_rebuilt.parquet")))
cat("  FREQ_PARTICIP rows:", pfmt_int(nrow(freq_particip)), "\n")

cat("  Loading Firms_final.parquet...\n")
firms <- as.data.table(read_parquet(file.path(DATA_V1, "Firms_final.parquet")))
cat("  Firms rows:", pfmt_int(nrow(firms)), "\n")

# ============================================================================
# Phase B: Extract structural variables from BEC keys
# ============================================================================

cat("  Extracting PBU, year, item code from po_item_merge_key...\n")

bec[, pbu_code := substr(po_item_merge_key, 1, 11)]
bec[, year := as.integer(substr(po_item_merge_key, 12, 15))]
bec[, oc_code := substr(po_item_merge_key, 1, OC_CODE_LEN)]

bec[, after_oc := substr(po_item_merge_key, OC_CODE_LEN + 1L,
                          nchar(po_item_merge_key))]
bec[, full_num := sub("^(\\d+).*", "\\1", after_oc)]
bec[, item_code := substr(full_num, 1, nchar(full_num) - 1L)]
bec[, c("after_oc", "full_num") := NULL]

cat("  Year range:", min(bec$year, na.rm = TRUE), "-",
    max(bec$year, na.rm = TRUE), "\n")

# ============================================================================
# Phase C: Merge LOSERS with BEC
# ============================================================================

cat("  Merging LOSERS flags + losers_count into BEC...\n")

setnames(losers, c("numerodaoc", "códigoitem"), c("oc_code", "item_code"),
         skip_absent = TRUE)
bec <- merge(bec, losers[, .(oc_code, item_code, losers_count)],
             by = c("oc_code", "item_code"), all.x = TRUE)
bec[is.na(losers_count), losers_count := 0L]
bec[, has_loser := as.integer(losers_count > 0L)]

n_with_loser <- sum(bec$has_loser)
cat("  BEC rows with frequent losers:", pfmt_int(n_with_loser),
    sprintf("(%.2f%%)\n", 100 * n_with_loser / nrow(bec)))

# ============================================================================
# Phase D: Create analysis variables
# ============================================================================

cat("  Creating analysis variables...\n")

bec[, po_phase_code := as.integer(po_phase_code)]
bec[, convite := as.integer(po_phase_code == PHASE_CONVITE)]
bec[, pregao  := as.integer(po_phase_code == PHASE_PREGAO)]

# Log outcome variables
bec[, lneg_price := fifelse(
  bid_unit_price_negot_min > 0, log(bid_unit_price_negot_min), NA_real_
)]

neg_valid <- sum(!is.na(bec$lneg_price))
if (neg_valid < nrow(bec) * 0.1) {
  cat("  WARNING: Few valid negotiated prices. Using bid_price_min instead.\n")
  bec[, lneg_price := fifelse(bid_price_min > 0, log(bid_price_min), NA_real_)]
  neg_valid <- sum(!is.na(bec$lneg_price))
}
cat("  Valid price observations:", pfmt_int(neg_valid), "\n")

bec[, ln_firms := fifelse(n_firms > 0, log(n_firms), NA_real_)]
bec[, ln_bids  := fifelse(n_bids > 0, log(n_bids), NA_real_)]

bec[, n_firms_excl := pmax(n_firms - losers_count, 0L)]
bec[, ln_firms_excl := fifelse(n_firms_excl > 0, log(n_firms_excl), NA_real_)]

bec[, has_price := !is.na(lneg_price) & po_winner_max == 1L]

bec[, item_f := factor(item_code)]
bec[, pbu_f  := factor(pbu_code)]
bec[, year_f := factor(year)]

bec[, losers := has_loser]

# ============================================================================
# Phase D_ext: Extended variables (cover bidding framing)
# ============================================================================

cat("  Creating extended analysis variables...\n")

# Continuous treatment
bec[, losers_share := fifelse(n_firms > 0, losers_count / n_firms, 0)]

# v2 aliases for cover bidding framing
bec[, cover_tender    := losers]
bec[, cover_intensity := losers_share]
bec[, n_fl_per_tender := losers_count]

# Bid dispersion, price ratio, procedure duration
bec[, log_bid_sd := fifelse(
  !is.na(bid_price_sd) & bid_price_sd > 0, log(bid_price_sd), NA_real_
)]
bec[, price_ratio := fifelse(
  bid_unit_price_negot_min > 0 & !is.na(bid_ref_price_min) & bid_ref_price_min > 0,
  log(bid_unit_price_negot_min / bid_ref_price_min), NA_real_
)]
bec[, log_proc_hours := fifelse(
  !is.na(proc_length_hours), log(proc_length_hours + 1), NA_real_
)]

# Item group (first 2 digits)
bec[, item_group := substr(item_code, 1, 2)]

# PBU size quartile
pbu_counts <- bec[, .N, by = pbu_code]
pbu_counts[, pbu_size_q := as.integer(cut(N, quantile(N, 0:4/4), include.lowest = TRUE,
                                           labels = 1:4))]
bec <- merge(bec, pbu_counts[, .(pbu_code, pbu_size_q)], by = "pbu_code", all.x = TRUE)

# Tender value quartile
bec[!is.na(bid_ref_price_min) & bid_ref_price_min > 0,
    tender_value_q := as.integer(cut(bid_ref_price_min,
                                      quantile(bid_ref_price_min, 0:4/4, na.rm = TRUE),
                                      include.lowest = TRUE, labels = 1:4))]

# Market ID (item_code x pbu_code) for C&S DiD panel
bec[, market_id := paste0(item_code, "_", pbu_code)]
bec[, market_id_f := factor(market_id)]

# Number of genuine (non-FL) firms
bec[, n_genuine := pmax(n_firms - losers_count, 0L)]

cat("  Valid log_bid_sd:", pfmt_int(sum(!is.na(bec$log_bid_sd))), "\n")
cat("  Valid price_ratio:", pfmt_int(sum(!is.na(bec$price_ratio))), "\n")

# ============================================================================
# Phase E: Filter to analysis sample
# ============================================================================

cat("  Filtering to analysis sample...\n")

bec <- bec[po_phase_code %in% c(PHASE_CONVITE, PHASE_PREGAO)]
cat("  After phase filter (convite + pregao):", pfmt_int(nrow(bec)), "\n")

loser_items <- unique(bec[has_loser == 1L, item_code])
cat("  Item types with >= 1 loser tender:", pfmt_int(length(loser_items)), "\n")

dt <- bec[item_code %in% loser_items]
cat("  Losers subsample (all phases 2+3):", pfmt_int(nrow(dt)), "\n")

dt <- dt[po_winner_max == 1L]
cat("  After winner filter:", pfmt_int(nrow(dt)), "\n")

# ============================================================================
# Phase F: Temporal variables for DiD
# ============================================================================

cat("  Computing first_fl_year at market_id level...\n")

# First-loser-year per market_id (for C&S DiD: item × PBU markets)
fly_market <- dt[losers == 1, .(first_fl_year_market = min(year)), by = market_id]
dt <- merge(dt, fly_market, by = "market_id", all.x = TRUE)

# Also keep item-level first_loser_year for backward compatibility
fly_item <- dt[losers == 1, .(first_loser_year = min(year)), by = item_code]
dt <- merge(dt, fly_item, by = "item_code", all.x = TRUE)

cat("  Markets with FL entry:", pfmt_int(nrow(fly_market)), "\n")

# ============================================================================
# Phase G: Keep needed columns and cache
# ============================================================================

keep_cols <- c(
  "po_item_merge_key", "pbu_code", "year", "oc_code", "item_code",
  "po_phase_code", "convite", "pregao",
  "n_firms", "n_bids", "lneg_price", "ln_firms", "ln_bids",
  "n_firms_excl", "ln_firms_excl",
  "has_price", "losers", "has_loser",
  "losers_count", "losers_share",
  "cover_tender", "cover_intensity", "n_fl_per_tender",
  "log_bid_sd", "price_ratio", "log_proc_hours",
  "item_group", "pbu_size_q", "tender_value_q",
  "market_id", "market_id_f",
  "n_genuine",
  "item_f", "pbu_f", "year_f",
  "bid_unit_price_negot_min", "bid_price_min", "bid_ref_price_min",
  "bid_price_sd", "proc_length_hours",
  "po_winner_max",
  "first_fl_year_market", "first_loser_year"
)
keep_cols <- intersect(keep_cols, names(dt))
dt <- dt[, ..keep_cols]

cat("\n  Saving analysis caches...\n")
saveRDS(dt, DATA_CACHE_V2)
cat("  Saved:", DATA_CACHE_V2, "\n")

# Also cache auxiliary data for other scripts
saveRDS(freq_particip, DATA_CACHE_FP)
saveRDS(firms, DATA_CACHE_FIRMS)
cat("  Saved:", DATA_CACHE_FP, "\n")
cat("  Saved:", DATA_CACHE_FIRMS, "\n")

cat("  Final sample:", pfmt_int(nrow(dt)), "rows\n")
cat("  Done.\n")
