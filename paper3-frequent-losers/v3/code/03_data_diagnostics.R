# ============================================================================
# 03_data_diagnostics.R — Mandatory diagnostics before analysis
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Diagnostic 1: RDD feasibility (Art. 24 thresholds)
# Diagnostic 2: Bajari-Ye power (tenders with 2+ FL firms)
# Diagnostic 3: Multicollinearity (cover_tender vs cover_intensity)
# Diagnostic 4: Preliminary regime test (bid_price_sd FL vs non-FL)
# Diagnostic 5: CADE validation data availability
# ============================================================================

cat("=== 03_data_diagnostics.R: Mandatory diagnostics ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

log_lines <- character()
log <- function(...) {
  msg <- paste0(...)
  cat(msg, "\n")
  log_lines <<- c(log_lines, msg)
}

log(paste(rep("=", 72), collapse = ""))
log("DIAGNOSTICS REPORT — Paper 3 v2")
log(format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log(paste(rep("=", 72), collapse = ""))

# ============================================================================
# Diagnostic 1: RDD Feasibility
# ============================================================================

log("")
log("--- Diagnostic 1: RDD Feasibility ---")

# Art. 24 of Lei 8.666/93 established procurement thresholds:
# - Below ~R$80K (2009 values): direct purchase (dispensa)
# - Above threshold: competitive bidding required
# BEC only records competitive procurement (above threshold)

# Check: how many observations have reference prices near common thresholds
thresholds_brl <- c(8000, 15000, 80000, 150000, 650000)
for (thr in thresholds_brl) {
  # Count obs within 10% bandwidth
  bw <- thr * 0.10
  n_near <- dt[!is.na(bid_ref_price_min) &
               bid_ref_price_min > (thr - bw) &
               bid_ref_price_min < (thr + bw), .N]
  log(sprintf("  Obs within 10%% of R$%s threshold: %s",
              pfmt_int(thr), pfmt_int(n_near)))
}

# Check for observations below minimum competitive threshold
n_below_8k <- dt[!is.na(bid_ref_price_min) & bid_ref_price_min < 8000, .N]
n_total_valid <- dt[!is.na(bid_ref_price_min), .N]
log(sprintf("  Total obs with valid ref_price: %s", pfmt_int(n_total_valid)))
log(sprintf("  Obs below R$8,000: %s (%.2f%%)",
            pfmt_int(n_below_8k), 100 * n_below_8k / max(n_total_valid, 1)))

rdd_feasible <- n_below_8k > 1000
log(sprintf("  RDD FEASIBILITY: %s", if (rdd_feasible) "FEASIBLE" else "INFEASIBLE"))
log("  Reason: BEC only records competitive procurement above Art. 24 thresholds.")

# ============================================================================
# Diagnostic 2: Bajari-Ye Power
# ============================================================================

log("")
log("--- Diagnostic 2: Bajari-Ye Power ---")

# Need tenders with 2+ FL firms for pairwise correlation tests
n_2plus_fl <- dt[losers_count >= 2, .N]
n_3plus_fl <- dt[losers_count >= 3, .N]
n_5plus_fl <- dt[losers_count >= 5, .N]

log(sprintf("  Tenders with >= 2 FL firms: %s", pfmt_int(n_2plus_fl)))
log(sprintf("  Tenders with >= 3 FL firms: %s", pfmt_int(n_3plus_fl)))
log(sprintf("  Tenders with >= 5 FL firms: %s", pfmt_int(n_5plus_fl)))

bajari_power <- n_2plus_fl >= 500
log(sprintf("  Bajari-Ye power (need >= 500 tenders w/ 2+ FL): %s",
            if (bajari_power) "SUFFICIENT" else "INSUFFICIENT — report as suggestive"))

# ============================================================================
# Diagnostic 3: Multicollinearity
# ============================================================================

log("")
log("--- Diagnostic 3: Multicollinearity ---")

cor_binary_share <- cor(dt$cover_tender, dt$cover_intensity, use = "complete.obs")
cor_count_share  <- cor(dt$losers_count, dt$losers_share, use = "complete.obs")
cor_binary_count <- cor(dt$cover_tender, dt$losers_count, use = "complete.obs")

log(sprintf("  cor(cover_tender, cover_intensity): %.3f", cor_binary_share))
log(sprintf("  cor(losers_count, losers_share): %.3f", cor_count_share))
log(sprintf("  cor(cover_tender, losers_count): %.3f", cor_binary_count))

if (abs(cor_binary_share) > 0.9) {
  log("  WARNING: High multicollinearity — do not use both in same regression")
} else {
  log("  OK: Moderate correlation — safe to use separately")
}

# ============================================================================
# Diagnostic 4: Preliminary Regime Test
# ============================================================================

log("")
log("--- Diagnostic 4: Preliminary Regime Test ---")

# Compare bid price SD in FL-present vs FL-absent tenders
d_sd <- dt[!is.na(bid_price_sd)]
sd_fl    <- d_sd[losers == 1, bid_price_sd]
sd_nofl  <- d_sd[losers == 0, bid_price_sd]

log(sprintf("  Bid SD (FL-present):  mean=%.2f, median=%.2f, N=%s",
            mean(sd_fl, na.rm = TRUE), median(sd_fl, na.rm = TRUE),
            pfmt_int(length(sd_fl))))
log(sprintf("  Bid SD (FL-absent):   mean=%.2f, median=%.2f, N=%s",
            mean(sd_nofl, na.rm = TRUE), median(sd_nofl, na.rm = TRUE),
            pfmt_int(length(sd_nofl))))

# Wilcoxon test
wt <- tryCatch(wilcox.test(sd_fl, sd_nofl), error = function(e) NULL)
if (!is.null(wt)) {
  log(sprintf("  Wilcoxon p-value: %.6f", wt$p.value))
  if (mean(sd_fl, na.rm = TRUE) > mean(sd_nofl, na.rm = TRUE)) {
    log("  Preliminary: FL tenders have HIGHER bid dispersion → Regime 1 (complementary)")
  } else {
    log("  Preliminary: FL tenders have LOWER bid dispersion → Regime 2 (coordinated)")
  }
}

# ============================================================================
# Diagnostic 5: CADE Validation Data
# ============================================================================

log("")
log("--- Diagnostic 5: CADE Validation Data ---")

cade_files <- c(
  "cade_carteis_licitacoes_2009_2019.csv",
  "cade_bec_crossmatch.csv",
  "cade_fl_cobidders.csv"
)

for (f in cade_files) {
  fpath <- file.path(DATA_V1, f)
  exists_flag <- file.exists(fpath)
  if (exists_flag) {
    n_rows <- nrow(fread(fpath, nrows = Inf))
    log(sprintf("  %s: EXISTS (%s rows)", f, pfmt_int(n_rows)))
  } else {
    log(sprintf("  %s: MISSING", f))
  }
}

# Quick CADE match analysis
cade_match_file <- file.path(DATA_V1, "cade_bec_crossmatch.csv")
if (file.exists(cade_match_file)) {
  cade_match <- fread(cade_match_file)
  log(sprintf("  CADE firms matched to BEC: %s", pfmt_int(nrow(cade_match))))

  cade_fl_file <- file.path(DATA_V1, "cade_fl_cobidders.csv")
  if (file.exists(cade_fl_file)) {
    cade_fl <- fread(cade_fl_file)
    log(sprintf("  FL firms co-bidding with CADE cartelists: %s", pfmt_int(nrow(cade_fl))))
  }
}

# ============================================================================
# Diagnostic 6: Sample summary
# ============================================================================

log("")
log("--- Diagnostic 6: Sample Summary ---")

log(sprintf("  Total observations: %s", pfmt_int(nrow(dt))))
log(sprintf("  Unique items: %s", pfmt_int(uniqueN(dt$item_code))))
log(sprintf("  Unique PBUs: %s", pfmt_int(uniqueN(dt$pbu_code))))
log(sprintf("  Unique markets (item x PBU): %s", pfmt_int(uniqueN(dt$market_id))))
log(sprintf("  Year range: %d - %d", min(dt$year), max(dt$year)))
log(sprintf("  Tenders with FL: %s (%.1f%%)",
            pfmt_int(sum(dt$losers)), 100 * mean(dt$losers)))
log(sprintf("  Mean FL count per FL-tender: %.1f",
            mean(dt[losers == 1, losers_count])))
log(sprintf("  Valid prices: %s", pfmt_int(sum(!is.na(dt$lneg_price)))))
log(sprintf("  Markets with FL entry event: %s",
            pfmt_int(sum(!is.na(dt$first_fl_year_market)))))

# ============================================================================
# Save diagnostics
# ============================================================================

log("")
log(paste(rep("=", 72), collapse = ""))
log("END OF DIAGNOSTICS")

# Write log file
log_path <- file.path(OUT_LOG, "diagnostics.txt")
writeLines(log_lines, log_path)
cat("  Saved:", log_path, "\n")

# Save key diagnostics as data
diag_results <- data.table(
  diagnostic = c("rdd_feasible", "bajari_power", "cor_binary_share",
                  "sd_fl_mean", "sd_nofl_mean", "cade_data_available",
                  "n_total", "n_fl_tenders", "n_markets"),
  value = c(as.numeric(rdd_feasible), as.numeric(bajari_power), cor_binary_share,
            mean(sd_fl, na.rm = TRUE), mean(sd_nofl, na.rm = TRUE),
            as.numeric(file.exists(cade_match_file)),
            nrow(dt), sum(dt$losers), uniqueN(dt$market_id))
)
write_parquet(diag_results, file.path(DATA_V2, "diagnostics.parquet"))
cat("  Saved:", file.path(DATA_V2, "diagnostics.parquet"), "\n")

cat("\n  *** STOP AND READ diagnostics.txt before proceeding ***\n")
cat("  Done.\n")
