# ============================================================================
# 01_clean.R — Data loading, merging, variable creation, and caching
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================

cat("=== 01_clean.R: Data preparation ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ============================================================================
# Phase A: Load parquet datasets
# ============================================================================

cat("  Loading BEC_collapse_final.parquet...\n")
bec <- as.data.table(read_parquet(file.path(DATA_PROC, "BEC_collapse_final.parquet")))
cat("  BEC rows:", pfmt_int(nrow(bec)), " cols:", ncol(bec), "\n")

cat("  Loading LOSERS_rebuilt.parquet...\n")
losers <- as.data.table(read_parquet(file.path(DATA_PROC, "LOSERS_rebuilt.parquet")))
cat("  LOSERS rows:", pfmt_int(nrow(losers)), "\n")

cat("  Loading FREQ_PARTICIP_rebuilt.parquet...\n")
freq_particip <- as.data.table(read_parquet(file.path(DATA_PROC, "FREQ_PARTICIP_rebuilt.parquet")))
cat("  FREQ_PARTICIP rows:", pfmt_int(nrow(freq_particip)), "\n")

cat("  Loading Firms_final.parquet...\n")
firms <- as.data.table(read_parquet(file.path(DATA_PROC, "Firms_final.parquet")))
cat("  Firms rows:", pfmt_int(nrow(firms)), "\n")

# ---- Bid-level data (full: 2009-2019 from LANCES_Final_Semester.dta) -------
bid_level_file <- file.path(DATA_PROC, "bid_level_full.parquet")
ftm_file <- file.path(DATA_PROC, "firm_tender_map.parquet")
fls_file <- file.path(DATA_PROC, "firm_loss_stats.parquet")
has_bidlevel <- file.exists(bid_level_file)

if (has_bidlevel) {
  cat("  Loading bid_level_full.parquet...\n")
  bid_level <- as.data.table(read_parquet(bid_level_file))
  cat("  Bid-level rows:", pfmt_int(nrow(bid_level)), "\n")

  cat("  Loading firm_tender_map.parquet...\n")
  ftm <- as.data.table(read_parquet(ftm_file))
  cat("  Firm-tender pairs:", pfmt_int(nrow(ftm)), "\n")

  cat("  Loading firm_loss_stats.parquet...\n")
  fls <- as.data.table(read_parquet(fls_file))
  cat("  Unique firms:", pfmt_int(nrow(fls)),
      "  Always-losers:", pfmt_int(sum(fls$always_loser)), "\n")
} else {
  cat("  WARNING: bid_level_full.parquet not found.\n")
  cat("  Run: python3 scripts/00_build_bidlevel.py\n")
  bid_level <- NULL
  ftm <- NULL
  fls <- NULL
}

# ============================================================================
# Phase B: Extract structural variables from BEC keys
# ============================================================================
# BEC po_item_merge_key structure:
#   chars 1-11  = PBU code
#   chars 12-15 = year
#   chars 16-17 = "OC"
#   chars 18-22 = OC sequence number
#   chars 23+   = ITEM_CODE + PHASE_DIGIT + description
# The LAST digit of the numeric prefix is po_phase_code (verified 99.99%)

cat("  Extracting PBU, year, item code from po_item_merge_key...\n")

bec[, pbu_code := substr(po_item_merge_key, 1, 11)]
bec[, year := as.integer(substr(po_item_merge_key, 12, 15))]
bec[, oc_code := substr(po_item_merge_key, 1, OC_CODE_LEN)]

# Full numeric prefix after OC code = true_item_code + phase_digit
bec[, after_oc := substr(po_item_merge_key, OC_CODE_LEN + 1L,
                          nchar(po_item_merge_key))]
bec[, full_num := sub("^(\\d+).*", "\\1", after_oc)]
# True item code = all digits except the last (which is the phase code)
bec[, item_code := substr(full_num, 1, nchar(full_num) - 1L)]
bec[, c("after_oc", "full_num") := NULL]

cat("  Year range:", min(bec$year, na.rm = TRUE), "-",
    max(bec$year, na.rm = TRUE), "\n")
cat("  Unique PBUs:", pfmt_int(uniqueN(bec$pbu_code)), "\n")
cat("  Unique item codes:", pfmt_int(uniqueN(bec$item_code)), "\n")

# ============================================================================
# Phase C: Merge LOSERS with BEC
# ============================================================================
# LOSERS_rebuilt has (numerodaoc, códigoitem, losers_count) — direct join on
# (oc_code, item_code), no iterative variable-length matching needed.

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

# Procedure type: po_phase_code 2 = convite (sealed bid), 3 = pregão (auction)
bec[, po_phase_code := as.integer(po_phase_code)]
bec[, convite := as.integer(po_phase_code == PHASE_CONVITE)]
bec[, pregao  := as.integer(po_phase_code == PHASE_PREGAO)]

# Log outcome variables
bec[, lneg_price := fifelse(
  bid_unit_price_negot_min > 0, log(bid_unit_price_negot_min), NA_real_
)]

# Fallback to bid_price_min if negotiated prices are sparse
neg_valid <- sum(!is.na(bec$lneg_price))
if (neg_valid < nrow(bec) * 0.1) {
  cat("  WARNING: Few valid negotiated prices. Using bid_price_min instead.\n")
  bec[, lneg_price := fifelse(bid_price_min > 0, log(bid_price_min), NA_real_)]
  neg_valid <- sum(!is.na(bec$lneg_price))
}
cat("  Valid price observations:", pfmt_int(neg_valid), "\n")

bec[, ln_firms := fifelse(n_firms > 0, log(n_firms), NA_real_)]
bec[, ln_bids  := fifelse(n_bids > 0, log(n_bids), NA_real_)]

# Firms excluding FL: test mechanical relationship
bec[, n_firms_excl := pmax(n_firms - losers_count, 0L)]
bec[, ln_firms_excl := fifelse(n_firms_excl > 0, log(n_firms_excl), NA_real_)]

# Winner flag (for price sample)
bec[, has_price := !is.na(lneg_price) & po_winner_max == 1L]

# Factor variables for fixed effects
bec[, item_f := factor(item_code)]
bec[, pbu_f  := factor(pbu_code)]
bec[, year_f := factor(year)]

# Losers binary
bec[, losers := has_loser]

# ============================================================================
# Phase D_ext: Additional variables for extended analysis (scripts 05-09)
# ============================================================================

cat("  Creating extended analysis variables...\n")

# Continuous treatment: losers_share = losers_count / n_firms
bec[, losers_share := fifelse(n_firms > 0, losers_count / n_firms, 0)]

# New DVs: bid dispersion, price ratio, procedure duration
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

# Item group (first 2 digits of item code) — for heterogeneity analysis
bec[, item_group := substr(item_code, 1, 2)]

# PBU size quartile (by tender count per PBU)
pbu_counts <- bec[, .N, by = pbu_code]
pbu_counts[, pbu_size_q := as.integer(cut(N, quantile(N, 0:4/4), include.lowest = TRUE,
                                           labels = 1:4))]
bec <- merge(bec, pbu_counts[, .(pbu_code, pbu_size_q)], by = "pbu_code", all.x = TRUE)

# Tender value quartile (by reference price)
bec[!is.na(bid_ref_price_min) & bid_ref_price_min > 0,
    tender_value_q := as.integer(cut(bid_ref_price_min,
                                      quantile(bid_ref_price_min, 0:4/4, na.rm = TRUE),
                                      include.lowest = TRUE, labels = 1:4))]

cat("  Extended variables: losers_count, losers_share, log_bid_sd, price_ratio,\n")
cat("    log_proc_hours, item_group, pbu_size_q, tender_value_q\n")
cat("  Valid log_bid_sd:", pfmt_int(sum(!is.na(bec$log_bid_sd))), "\n")
cat("  Valid price_ratio:", pfmt_int(sum(!is.na(bec$price_ratio))), "\n")
cat("  Valid log_proc_hours:", pfmt_int(sum(!is.na(bec$log_proc_hours))), "\n")

# ============================================================================
# Phase E: Filter to analysis sample
# ============================================================================
# Manuscript uses phases 2 (convite) and 3 (pregão) only, with successful
# tenders (po_winner_max == 1). Verified: this gives N ≈ 1,673K which closely
# matches the manuscript's 1,671,773.

cat("  Filtering to analysis sample...\n")

# Step 1: Keep only convite + pregão phases
bec <- bec[po_phase_code %in% c(PHASE_CONVITE, PHASE_PREGAO)]
cat("  After phase filter (convite + pregão):", pfmt_int(nrow(bec)), "\n")

# Step 2: Keep only items with at least one loser
loser_items <- unique(bec[has_loser == 1L, item_code])
cat("  Item types with >= 1 loser tender:", pfmt_int(length(loser_items)), "\n")

dt <- bec[item_code %in% loser_items]
cat("  Losers subsample (all phases 2+3):", pfmt_int(nrow(dt)), "\n")

# Step 3: Keep only winners (successful tenders)
dt <- dt[po_winner_max == 1L]
cat("  After winner filter:", pfmt_int(nrow(dt)), "\n")

# ---- Validate against manuscript targets -----------------------------------
cat("\n  --- Validation against manuscript ---\n")
cat("  Target: ~1,671,773 total; pregão ~474K; convite ~925K\n")

n_total   <- nrow(dt)
n_pregao  <- dt[pregao == 1L, .N]
n_convite <- dt[convite == 1L, .N]
n_price   <- dt[!is.na(lneg_price), .N]
cat(sprintf("  Actual: total=%s; pregão=%s; convite=%s; valid_price=%s\n",
            pfmt_int(n_total), pfmt_int(n_pregao),
            pfmt_int(n_convite), pfmt_int(n_price)))

# ============================================================================
# Phase F: Keep only needed columns and cache
# ============================================================================

keep_cols <- c(
  "po_item_merge_key", "pbu_code", "year", "oc_code", "item_code",
  "po_phase_code", "convite", "pregao",
  "n_firms", "n_bids", "lneg_price", "ln_firms", "ln_bids",
  "n_firms_excl", "ln_firms_excl",
  "has_price", "losers", "has_loser",
  "losers_count", "losers_share",
  "log_bid_sd", "price_ratio", "log_proc_hours",
  "item_group", "pbu_size_q", "tender_value_q",
  "item_f", "pbu_f", "year_f",
  "bid_unit_price_negot_min", "bid_price_min", "bid_ref_price_min",
  "bid_price_sd", "proc_length_hours",
  "po_winner_max"
)
keep_cols <- intersect(keep_cols, names(dt))
dt <- dt[, ..keep_cols]

# First-loser-year per item_code (for DiD temporal design)
fly <- dt[losers == 1, .(first_loser_year = min(year)), by = item_code]
dt <- merge(dt, fly, by = "item_code", all.x = TRUE)

cat("\n  Saving analysis caches...\n")
saveRDS(dt, DATA_CACHE)
cat("  Saved:", DATA_CACHE, "\n")

# Extended cache path for new scripts
DATA_CACHE_EXT <- "/tmp/p3_prepared_ext.rds"
saveRDS(dt, DATA_CACHE_EXT)
cat("  Saved:", DATA_CACHE_EXT, "\n")

saveRDS(freq_particip, DATA_CACHE_FP)
saveRDS(firms, DATA_CACHE_FIRMS)
cat("  Saved:", DATA_CACHE_FP, "\n")
cat("  Saved:", DATA_CACHE_FIRMS, "\n")

# Cache bid-level data if available
if (!is.null(ftm)) {
  saveRDS(ftm, DATA_CACHE_FTM)
  saveRDS(fls, DATA_CACHE_FLS)
  saveRDS(bid_level, DATA_CACHE_BL)
  cat("  Saved:", DATA_CACHE_FTM, "\n")
  cat("  Saved:", DATA_CACHE_FLS, "\n")
  cat("  Saved:", DATA_CACHE_BL, "\n")
}

cat("  Done.\n")
