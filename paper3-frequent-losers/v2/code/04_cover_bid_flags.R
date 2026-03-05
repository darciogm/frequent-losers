# ============================================================================
# 04_cover_bid_flags.R — Cover bid construction from bid-level prices
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Loads bid-level data WITH prices (from 00_build_bidlevel_v2.py)
# Merges FL firm flag, computes per-tender:
#   - dispersion_fl (IQR/median of FL bids)
#   - dispersion_nonfl (IQR/median of non-FL bids)
#   - cover_bid_spread: (FL bid - winning bid) / |winning bid|
# Saves enriched bid-level to v2/data/processed/bid_level_analysis.parquet
# ============================================================================

cat("=== 04_cover_bid_flags.R: Cover bid construction ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load bid-level data with prices ----------------------------------------
bid_price_file <- file.path(DATA_V2, "bid_level_with_prices.parquet")
if (!file.exists(bid_price_file)) {
  cat("  WARNING: bid_level_with_prices.parquet not found.\n")
  cat("  Run: python3 v2/code/00_build_bidlevel_v2.py\n")
  cat("  Falling back to v1 bid-level (NO prices)...\n")

  # Fallback: use v1 bid-level + BEC collapse prices
  if (!file.exists(DATA_CACHE_BL)) stop("No bid-level data available. Run Python build first.")
  bl <- readRDS(DATA_CACHE_BL)
  bl[, bid_price := NA_real_]
  bl[, negot_price := NA_real_]
  bl[, ref_price := NA_real_]
  setnames(bl, "flagvencedor", "won", skip_absent = TRUE)
  bl[, won := as.integer(as.numeric(won))]
  has_prices <- FALSE
} else {
  cat("  Loading bid_level_with_prices.parquet...\n")
  bl <- as.data.table(read_parquet(bid_price_file))
  cat("  Bid-level rows:", pfmt_int(nrow(bl)), "\n")
  has_prices <- TRUE
}

# ---- Normalize column names --------------------------------------------------
setnames(bl, "códigofornecedor", "firm_id", skip_absent = TRUE)
setnames(bl, "códigoitem", "item_code", skip_absent = TRUE)
setnames(bl, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(bl, "mêsanoencerramento", "month_year", skip_absent = TRUE)
setnames(bl, "códigounidadecompradora", "pbu_code", skip_absent = TRUE)
setnames(bl, "descriçãoprocedimentocompra", "proc_type", skip_absent = TRUE)

# ---- Load FL firm classification ---------------------------------------------
cat("  Loading FREQ_PARTICIP for FL classification...\n")
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1) setnames(fp, fp_col, "firm_id")

# Compute IQR threshold (median + 1.5 * IQR)
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val

fl_ids <- fp[tenders_count > threshold, firm_id]
cat(sprintf("  FL firms (threshold=%.0f): %s\n", threshold, pfmt_int(length(fl_ids))))

# Flag FL firms in bid-level
bl[, is_fl := as.integer(firm_id %chin% fl_ids)]
cat(sprintf("  FL bids: %s (%.1f%%)\n",
            pfmt_int(sum(bl$is_fl)), 100 * mean(bl$is_fl)))

# ---- Compute winning bid per tender-item ------------------------------------

cat("  Computing winning bids...\n")

if (has_prices) {
  # Use actual bid prices — winning bid = bid from the winner
  winners <- bl[won == 1L & !is.na(bid_price) & bid_price > 0,
                .(win_price = min(bid_price)), by = .(oc_code, item_code)]
} else {
  # Fallback: no individual prices available
  winners <- data.table(oc_code = character(), item_code = character(),
                         win_price = numeric())
}

cat(sprintf("  Tender-items with winning price: %s\n", pfmt_int(nrow(winners))))

# ---- Compute dispersion metrics per tender-item -----------------------------

cat("  Computing bid dispersion by FL status...\n")

if (has_prices) {
  # FL bid dispersion per tender-item
  disp_fl <- bl[is_fl == 1L & !is.na(bid_price) & bid_price > 0,
                .(dispersion_fl = fifelse(.N >= 2, IQR(bid_price) / median(bid_price), NA_real_),
                  n_fl_bids = .N,
                  mean_fl_bid = mean(bid_price),
                  sd_fl_bid = sd(bid_price)),
                by = .(oc_code, item_code)]

  # Non-FL bid dispersion per tender-item
  disp_nonfl <- bl[is_fl == 0L & !is.na(bid_price) & bid_price > 0,
                   .(dispersion_nonfl = fifelse(.N >= 2, IQR(bid_price) / median(bid_price), NA_real_),
                     n_nonfl_bids = .N,
                     mean_nonfl_bid = mean(bid_price),
                     sd_nonfl_bid = sd(bid_price)),
                   by = .(oc_code, item_code)]

  cat(sprintf("  Tender-items with FL dispersion: %s\n", pfmt_int(nrow(disp_fl))))
  cat(sprintf("  Tender-items with non-FL dispersion: %s\n", pfmt_int(nrow(disp_nonfl))))
} else {
  disp_fl <- data.table(oc_code = character(), item_code = character(),
                          dispersion_fl = numeric())
  disp_nonfl <- data.table(oc_code = character(), item_code = character(),
                             dispersion_nonfl = numeric())
}

# ---- Compute cover bid spread ------------------------------------------------

cat("  Computing cover bid spread...\n")

if (has_prices && nrow(winners) > 0) {
  # Merge winning price onto FL bids
  fl_bids <- bl[is_fl == 1L & !is.na(bid_price) & bid_price > 0]
  fl_bids <- merge(fl_bids, winners, by = c("oc_code", "item_code"), all.x = TRUE)
  fl_bids[, cover_bid_spread := fifelse(
    !is.na(win_price) & abs(win_price) > 0,
    (bid_price - win_price) / abs(win_price),
    NA_real_
  )]

  n_spread <- sum(!is.na(fl_bids$cover_bid_spread))
  cat(sprintf("  FL bids with cover_bid_spread: %s\n", pfmt_int(n_spread)))

  if (n_spread > 0) {
    cat(sprintf("  Cover bid spread: mean=%.3f, median=%.3f, sd=%.3f\n",
                mean(fl_bids$cover_bid_spread, na.rm = TRUE),
                median(fl_bids$cover_bid_spread, na.rm = TRUE),
                sd(fl_bids$cover_bid_spread, na.rm = TRUE)))
    cat(sprintf("  %% FL bids ABOVE winner: %.1f%%\n",
                100 * mean(fl_bids$cover_bid_spread > 0, na.rm = TRUE)))
  }
} else {
  fl_bids <- NULL
}

# ---- Merge dispersion metrics onto tender-level data -------------------------

cat("  Merging dispersion metrics into tender-level cache...\n")

# Load v2 prepared data
dt <- readRDS(DATA_CACHE_V2)

if (nrow(disp_fl) > 0) {
  dt <- merge(dt, disp_fl[, .(oc_code, item_code, dispersion_fl, n_fl_bids,
                                mean_fl_bid, sd_fl_bid)],
              by = c("oc_code", "item_code"), all.x = TRUE)
}
if (nrow(disp_nonfl) > 0) {
  dt <- merge(dt, disp_nonfl[, .(oc_code, item_code, dispersion_nonfl, n_nonfl_bids,
                                   mean_nonfl_bid, sd_nonfl_bid)],
              by = c("oc_code", "item_code"), all.x = TRUE)
}

# Log dispersion ratio (for regime test)
dt[, log_disp_fl := fifelse(!is.na(dispersion_fl) & dispersion_fl > 0,
                             log(dispersion_fl), NA_real_)]
dt[, log_disp_nonfl := fifelse(!is.na(dispersion_nonfl) & dispersion_nonfl > 0,
                                log(dispersion_nonfl), NA_real_)]

# Re-save enriched cache
saveRDS(dt, DATA_CACHE_V2)
cat("  Updated:", DATA_CACHE_V2, "\n")

# ---- Save enriched bid-level for Bajari-Ye ----------------------------------

cat("  Saving bid-level analysis data...\n")

# Save FL bids with spread (for figures)
if (!is.null(fl_bids) && nrow(fl_bids) > 0) {
  fl_spread_out <- fl_bids[!is.na(cover_bid_spread),
                            .(firm_id, oc_code, item_code, bid_price,
                              win_price, cover_bid_spread)]
  write_parquet(fl_spread_out, file.path(DATA_V2, "fl_cover_bid_spread.parquet"))
  cat("  Saved: fl_cover_bid_spread.parquet\n")
}

# Save full bid-level with FL flag (for Bajari-Ye)
bl_out <- bl[, .(firm_id, oc_code, item_code, month_year, pbu_code,
                  won, bid_price, negot_price, ref_price, is_fl)]
write_parquet(bl_out, file.path(DATA_V2, "bid_level_analysis.parquet"))
cat("  Saved: bid_level_analysis.parquet\n")

cat("  Done.\n")
