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

cat("  Loading LOSERS.parquet...\n")
losers <- as.data.table(read_parquet(file.path(DATA_PROC, "LOSERS.parquet")))
cat("  LOSERS rows:", pfmt_int(nrow(losers)), "\n")

cat("  Loading FREQ_PARTICIP.parquet...\n")
freq_particip <- as.data.table(read_parquet(file.path(DATA_PROC, "FREQ_PARTICIP.parquet")))
cat("  FREQ_PARTICIP rows:", pfmt_int(nrow(freq_particip)), "\n")

cat("  Loading Firms_final.parquet...\n")
firms <- as.data.table(read_parquet(file.path(DATA_PROC, "Firms_final.parquet")))
cat("  Firms rows:", pfmt_int(nrow(firms)), "\n")

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
# LOSERS key_item_oc = item_code + "_" + oc_code
# Match LOSERS keys at their exact item_code length against BEC true item codes

cat("  Merging LOSERS flags into BEC...\n")

losers[, l_item_code := sub("_.*", "", key_item_oc)]
losers[, l_ic_len := nchar(l_item_code)]

bec[, has_loser := 0L]
total_matched <- 0L

for (n in 2:8) {
  losers_n <- losers[l_ic_len == n, key_item_oc]
  if (length(losers_n) == 0) next

  # BEC true item code truncated to n chars + "_" + oc_code
  bec_key_n <- paste0(substr(bec$item_code, 1, n), "_", bec$oc_code)
  matched <- bec_key_n %in% losers_n & bec$has_loser == 0L
  n_matched <- sum(matched)

  if (n_matched > 0) {
    bec[matched, has_loser := 1L]
    total_matched <- total_matched + n_matched
    cat(sprintf("    LOSERS with %d-digit item code: %s keys -> %s BEC rows\n",
                n, pfmt_int(length(losers_n)), pfmt_int(n_matched)))
  }
}

n_with_loser <- sum(bec$has_loser)
cat("  BEC rows with frequent losers:", pfmt_int(n_with_loser),
    sprintf("(%.2f%%)\n", 100 * n_with_loser / nrow(bec)))

losers[, c("l_item_code", "l_ic_len") := NULL]

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

# Winner flag (for price sample)
bec[, has_price := !is.na(lneg_price) & po_winner_max == 1L]

# Factor variables for fixed effects
bec[, item_f := factor(item_code)]
bec[, pbu_f  := factor(pbu_code)]
bec[, year_f := factor(year)]

# Losers binary
bec[, losers := has_loser]

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
  "po_item_merge_key", "pbu_code", "year", "item_code",
  "po_phase_code", "convite", "pregao",
  "n_firms", "n_bids", "lneg_price", "ln_firms", "ln_bids",
  "has_price", "losers", "has_loser",
  "item_f", "pbu_f", "year_f",
  "bid_unit_price_negot_min", "bid_price_min", "bid_ref_price_min",
  "po_winner_max"
)
keep_cols <- intersect(keep_cols, names(dt))
dt <- dt[, ..keep_cols]

cat("\n  Saving analysis cache...\n")
saveRDS(dt, DATA_CACHE)
cat("  Saved:", DATA_CACHE, "\n")

saveRDS(freq_particip, DATA_CACHE_FP)
saveRDS(firms, DATA_CACHE_FIRMS)
cat("  Saved:", DATA_CACHE_FP, "\n")
cat("  Saved:", DATA_CACHE_FIRMS, "\n")

cat("  Done.\n")
