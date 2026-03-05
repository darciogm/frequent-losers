# ============================================================================
# 03_iv_construction.R — Leave-One-Out IV construction (NEW for v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Instrument: For each tender-item at PBU k in year t and item-group g,
# Z_{kgt} = count of FL firms active at PBUs != k in group g, year t.
# This measures supply-side availability of FL firms, driven by activity
# in other markets. [Major 3.1]
#
# Also constructs placebo IV using sub-threshold always-losers.
# Also constructs network-split IV using high-suspicion FL only.
#
# Outputs: /tmp/p3v4_iv.rds (instrument merged onto analysis data)
# ============================================================================

cat("=== 03_iv_construction.R: LOO IV construction ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data ---------------------------------------------------------------
cat("  Loading firm_tender_map...\n")
ftm <- as.data.table(read_parquet(file.path(DATA_V1, "firm_tender_map.parquet")))

ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

cat("  FTM rows:", pfmt_int(nrow(ftm)), "\n")

# Load FL identification (apply IQR threshold to get true FL firms)
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val
fl_ids <- unique(fp[tenders_count > threshold, firm_id])
cat(sprintf("  FL firms (above IQR threshold %.0f): %d\n", threshold, length(fl_ids)))

# Load firm_loss_stats for sub-threshold always-losers (placebo)
fls_file <- file.path(DATA_V1, "firm_loss_stats.parquet")
if (file.exists(fls_file)) {
  fls <- as.data.table(read_parquet(fls_file))
  fls_col <- grep("fornecedor", names(fls), value = TRUE, ignore.case = TRUE)
  if (length(fls_col) == 1) setnames(fls, fls_col, "firm_id")
} else {
  fls <- NULL
}

# Load network classification if available
if (file.exists(NETWORK_CACHE_V4)) {
  network <- readRDS(NETWORK_CACHE_V4)
  high_fl_ids <- network$high_fl_ids
} else {
  high_fl_ids <- fl_ids  # Fall back to all FL
}

# ---- Extract structural keys from FTM OC codes ------------------------------
cat("  Extracting PBU, year, item_group from FTM...\n")

# po_item_merge_key is not in FTM; use oc_code + item_code
# oc_code structure: chars 1-11 = pbu_code, chars 12-15 = year
ftm[, pbu_code := substr(oc_code, 1, 11)]
ftm[, year := as.integer(substr(oc_code, 12, 15))]
ftm[, item_group := substr(item_code, 1, 2)]

# Flag FL status
ftm[, is_fl := as.integer(firm_id %chin% fl_ids)]

# ============================================================================
# Phase 1: Construct LOO instrument for FL supply
# ============================================================================

cat("  Phase 1: LOO instrument (FL supply at other PBUs)...\n")

# Step 1: Count unique FL firms active per (pbu_code, year, item_group)
fl_activity <- ftm[is_fl == 1L, .(
  n_fl_active = uniqueN(firm_id)
), by = .(pbu_code, year, item_group)]

# Step 2: Total FL firms per (year, item_group) across ALL PBUs
total_fl <- fl_activity[, .(total_fl = sum(n_fl_active)), by = .(year, item_group)]

# Step 3: LOO = total - own PBU's count
fl_loo <- merge(fl_activity, total_fl, by = c("year", "item_group"), all.x = TRUE)
fl_loo[, fl_supply_loo := total_fl - n_fl_active]

cat(sprintf("  LOO instrument computed for %s (pbu, year, item_group) cells\n",
            pfmt_int(nrow(fl_loo))))
cat(sprintf("  Mean fl_supply_loo: %.2f, SD: %.2f\n",
            mean(fl_loo$fl_supply_loo, na.rm = TRUE),
            sd(fl_loo$fl_supply_loo, na.rm = TRUE)))

# ============================================================================
# Phase 2: Placebo IV (sub-threshold always-losers)
# ============================================================================

cat("  Phase 2: Placebo IV (sub-threshold always-losers)...\n")

placebo_loo <- NULL
{
  # Sub-threshold always-losers: in fp (all always-losers) but below FL threshold
  # fp already has all 16,843 always-losers; fl_ids has the 2,735 above threshold
  sub_threshold_ids <- fp[tenders_count <= threshold & !(firm_id %chin% fl_ids), firm_id]
  cat(sprintf("  Sub-threshold always-losers: %s firms\n", pfmt_int(length(sub_threshold_ids))))

    if (length(sub_threshold_ids) > 100) {
      ftm[, is_sub_fl := as.integer(firm_id %chin% sub_threshold_ids)]

      sub_activity <- ftm[is_sub_fl == 1L, .(
        n_sub_active = uniqueN(firm_id)
      ), by = .(pbu_code, year, item_group)]

      total_sub <- sub_activity[, .(total_sub = sum(n_sub_active)), by = .(year, item_group)]
      sub_loo <- merge(sub_activity, total_sub, by = c("year", "item_group"), all.x = TRUE)
      sub_loo[, sub_supply_loo := total_sub - n_sub_active]
      placebo_loo <- sub_loo[, .(pbu_code, year, item_group, sub_supply_loo)]

      cat(sprintf("  Placebo LOO: mean=%.2f, SD=%.2f\n",
                  mean(placebo_loo$sub_supply_loo, na.rm = TRUE),
                  sd(placebo_loo$sub_supply_loo, na.rm = TRUE)))
    }
}

# ============================================================================
# Phase 3: Network-split IV (high-suspicion FL supply)
# ============================================================================

cat("  Phase 3: Network-split IV (high-suspicion FL supply)...\n")

ftm[, is_high_fl := as.integer(firm_id %chin% high_fl_ids)]

high_activity <- ftm[is_high_fl == 1L, .(
  n_high_active = uniqueN(firm_id)
), by = .(pbu_code, year, item_group)]

total_high <- high_activity[, .(total_high = sum(n_high_active)), by = .(year, item_group)]
high_loo <- merge(high_activity, total_high, by = c("year", "item_group"), all.x = TRUE)
high_loo[, high_supply_loo := total_high - n_high_active]

cat(sprintf("  High-suspicion LOO: mean=%.2f, SD=%.2f\n",
            mean(high_loo$high_supply_loo, na.rm = TRUE),
            sd(high_loo$high_supply_loo, na.rm = TRUE)))

# ============================================================================
# Phase 4: Merge instruments onto analysis dataset
# ============================================================================

cat("  Phase 4: Merging instruments onto analysis data...\n")

dt <- readRDS(DATA_CACHE_V4)

# Ensure item_group exists
if (!"item_group" %in% names(dt)) {
  dt[, item_group := substr(item_code, 1, 2)]
}

# Merge main LOO instrument
dt <- merge(dt, fl_loo[, .(pbu_code, year, item_group, fl_supply_loo)],
             by = c("pbu_code", "year", "item_group"), all.x = TRUE)
dt[is.na(fl_supply_loo), fl_supply_loo := 0]

# Merge placebo LOO
if (!is.null(placebo_loo)) {
  dt <- merge(dt, placebo_loo,
               by = c("pbu_code", "year", "item_group"), all.x = TRUE)
  dt[is.na(sub_supply_loo), sub_supply_loo := 0]
}

# Merge high-suspicion LOO
dt <- merge(dt, high_loo[, .(pbu_code, year, item_group, high_supply_loo)],
             by = c("pbu_code", "year", "item_group"), all.x = TRUE)
dt[is.na(high_supply_loo), high_supply_loo := 0]

cat(sprintf("  Merged. Analysis dataset: %s rows\n", pfmt_int(nrow(dt))))
cat(sprintf("  fl_supply_loo: mean=%.2f, non-zero=%s\n",
            mean(dt$fl_supply_loo), pfmt_int(sum(dt$fl_supply_loo > 0))))

# Save updated dataset
saveRDS(dt, DATA_CACHE_V4)
cat("  Updated:", DATA_CACHE_V4, "\n")

# Save IV results separately
iv_data <- list(
  fl_loo = fl_loo,
  placebo_loo = placebo_loo,
  high_loo = high_loo,
  threshold = if (exists("threshold")) threshold else NA,
  n_sub_threshold = if (exists("sub_threshold_ids")) length(sub_threshold_ids) else 0
)
saveRDS(iv_data, IV_CACHE_V4)
cat("  IV data saved:", IV_CACHE_V4, "\n")
cat("  Done.\n")
