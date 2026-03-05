# ============================================================================
# 05_bajari_ye_test.R — Bajari & Ye (2003) exchangeability and independence
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Test A (Exchangeability): KS test on FL vs non-FL bid residuals
# Test B (Conditional Independence): Pairwise correlation of FL bid residuals
# Placebo: Same tests on non-FL pairs (should NOT reject)
# ============================================================================

cat("=== 05_bajari_ye_test.R: Bajari-Ye tests ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load bid-level analysis data -------------------------------------------
bl_file <- file.path(DATA_V2, "bid_level_analysis.parquet")
if (!file.exists(bl_file)) stop("Run 04_cover_bid_flags.R first")
bl <- as.data.table(read_parquet(bl_file))
cat("  Bid-level rows:", pfmt_int(nrow(bl)), "\n")

has_prices <- sum(!is.na(bl$bid_price) & bl$bid_price > 0) > 1000

if (!has_prices) {
  cat("  WARNING: Insufficient bid prices. Bajari-Ye tests require individual bid prices.\n")
  cat("  Run 00_build_bidlevel_v2.py first.\n")
  cat("  Skipping Bajari-Ye tests.\n")

  # Save empty results
  bj_results <- list(
    exchangeability = list(feasible = FALSE, reason = "No bid prices"),
    independence = list(feasible = FALSE, reason = "No bid prices")
  )
  saveRDS(bj_results, "/tmp/p3v2_bajari_ye.rds")
  cat("  Done (skipped).\n")
  quit(save = "no", status = 0)
}

# ---- Load firm characteristics for first-stage controls ----------------------
firms <- readRDS(DATA_CACHE_FIRMS)
firms_col <- grep("^c.digofornecedor$", names(firms), value = TRUE, ignore.case = TRUE)
if (length(firms_col) == 1) setnames(firms, firms_col, "firm_id")

# Encode firm size as numeric (porte_empresa)
if ("porte_empresa" %in% names(firms)) {
  firms[, firm_size := as.numeric(factor(porte_empresa))]
  bl <- merge(bl, firms[, .(firm_id, firm_size)], by = "firm_id", all.x = TRUE)
  bl[is.na(firm_size), firm_size := 0]
} else {
  bl[, firm_size := 0]
}

# ---- Extract year from month_year (format: "MM/YYYY") -----------------------
bl[, year := as.integer(sub(".*/", "", as.character(month_year)))]

# ---- First stage: bid residuals ----------------------------------------------
cat("  First stage: bid residuals from losing bids...\n")

# Filter to losing bids with valid prices
d_resid <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
d_resid[, log_bid := log(bid_price)]

# Add reference price if available
if ("ref_price" %in% names(d_resid)) {
  d_resid[, log_ref := fifelse(!is.na(ref_price) & ref_price > 0,
                                log(ref_price), NA_real_)]
} else {
  d_resid[, log_ref := NA_real_]
}

cat(sprintf("  Losing bids with prices: %s\n", pfmt_int(nrow(d_resid))))
cat(sprintf("  With reference prices: %s\n",
            pfmt_int(sum(!is.na(d_resid$log_ref)))))

# First-stage regression: log(bid) ~ controls | FE
# Use what's available for controls
has_ref <- sum(!is.na(d_resid$log_ref)) > nrow(d_resid) * 0.3

if (has_ref) {
  cat("  Running first stage with reference price control...\n")
  d_fs <- d_resid[!is.na(log_ref)]
  m_fs <- tryCatch(
    feols(log_bid ~ log_ref + firm_size | item_code + year,
          data = d_fs, fixef.rm = "none", lean = FALSE),
    error = function(e) {
      cat(sprintf("  First stage with ref failed: %s\n", e$message))
      NULL
    }
  )
} else {
  cat("  Running first stage without reference price...\n")
  d_fs <- d_resid
  m_fs <- tryCatch(
    feols(log_bid ~ firm_size | item_code + year,
          data = d_fs, fixef.rm = "none", lean = FALSE),
    error = function(e) {
      cat(sprintf("  First stage failed: %s\n", e$message))
      NULL
    }
  )
}

if (is.null(m_fs)) {
  cat("  ERROR: First stage regression failed. Skipping Bajari-Ye.\n")
  bj_results <- list(
    exchangeability = list(feasible = FALSE, reason = "First stage failed"),
    independence = list(feasible = FALSE, reason = "First stage failed")
  )
  saveRDS(bj_results, "/tmp/p3v2_bajari_ye.rds")
  cat("  Done (failed).\n")
  quit(save = "no", status = 0)
}

# Extract residuals
d_fs[, resid := residuals(m_fs)]
cat(sprintf("  First stage R2: %.4f, N: %s\n",
            fitstat(m_fs, "r2")[[1]], pfmt_int(m_fs$nobs)))

# ============================================================================
# Test A: Exchangeability (KS test on FL vs non-FL residuals)
# ============================================================================

cat("  Test A: Exchangeability (KS test)...\n")

resid_fl    <- d_fs[is_fl == 1L, resid]
resid_nonfl <- d_fs[is_fl == 0L, resid]

cat(sprintf("  FL residuals: %s, Non-FL residuals: %s\n",
            pfmt_int(length(resid_fl)), pfmt_int(length(resid_nonfl))))

ks_test <- NULL
if (length(resid_fl) >= 30 && length(resid_nonfl) >= 30) {
  ks_test <- ks.test(resid_fl, resid_nonfl)
  cat(sprintf("  KS statistic: %.4f, p-value: %.6f\n",
              ks_test$statistic, ks_test$p.value))
  cat(sprintf("  Result: %s at 5%% level\n",
              if (ks_test$p.value < 0.05) "REJECT exchangeability (FL bids differ)" else "FAIL TO REJECT"))
} else {
  cat("  Insufficient FL residuals for KS test\n")
}

# ============================================================================
# Test B: Conditional Independence (pairwise correlation within tenders)
# ============================================================================

cat("  Test B: Conditional Independence (pairwise FL bid correlation)...\n")

# Get tenders with 2+ FL losing bids
fl_resid_dt <- d_fs[is_fl == 1L, .(firm_id, oc_code, item_code, resid)]
fl_tender_counts <- fl_resid_dt[, .N, by = .(oc_code, item_code)]
tenders_2plus <- fl_tender_counts[N >= 2]
cat(sprintf("  Tenders with 2+ FL losing bids: %s\n", pfmt_int(nrow(tenders_2plus))))

fl_cors <- numeric()
if (nrow(tenders_2plus) >= 50) {
  # For each tender with 2+ FL bids, compute pairwise correlation of residuals
  # Use all pairs within each tender
  fl_resid_wide <- fl_resid_dt[tenders_2plus, on = .(oc_code, item_code)]

  # Sample if too many tenders (computational constraint)
  if (nrow(tenders_2plus) > 5000) {
    set.seed(42)
    sample_tenders <- tenders_2plus[sample(.N, 5000)]
    fl_resid_wide <- fl_resid_dt[sample_tenders, on = .(oc_code, item_code)]
  }

  # Compute pairwise correlations within tenders
  fl_cors <- fl_resid_wide[, {
    if (.N >= 2) {
      pairs <- combn(.N, 2)
      cors <- sapply(seq_len(ncol(pairs)), function(p) {
        # Point-biserial correlation for just 2 values → use difference
        resid[pairs[1, p]] * resid[pairs[2, p]]
      })
      .(pair_product = cors)
    }
  }, by = .(oc_code, item_code)]

  if (nrow(fl_cors) > 0) {
    mean_prod <- mean(fl_cors$pair_product, na.rm = TRUE)
    se_prod   <- sd(fl_cors$pair_product, na.rm = TRUE) / sqrt(nrow(fl_cors))
    t_stat    <- mean_prod / se_prod
    p_val     <- 2 * pnorm(-abs(t_stat))

    cat(sprintf("  Mean pairwise product: %.6f (SE: %.6f)\n", mean_prod, se_prod))
    cat(sprintf("  t-statistic: %.3f, p-value: %.6f\n", t_stat, p_val))
    cat(sprintf("  Result: %s at 5%% level\n",
                if (p_val < 0.05) "REJECT independence (FL bids correlated)" else "FAIL TO REJECT"))
  }
}

# ============================================================================
# Placebo: Same tests on non-FL pairs (should NOT reject)
# ============================================================================

cat("  Placebo: Non-FL pairwise correlation...\n")

nonfl_resid_dt <- d_fs[is_fl == 0L, .(firm_id, oc_code, item_code, resid)]
nonfl_tender_counts <- nonfl_resid_dt[, .N, by = .(oc_code, item_code)]
nonfl_2plus <- nonfl_tender_counts[N >= 2]

placebo_p <- NA_real_
if (nrow(nonfl_2plus) >= 50) {
  # Sample for computational feasibility
  if (nrow(nonfl_2plus) > 5000) {
    set.seed(42)
    sample_nonfl <- nonfl_2plus[sample(.N, 5000)]
  } else {
    sample_nonfl <- nonfl_2plus
  }

  nonfl_resid_wide <- nonfl_resid_dt[sample_nonfl, on = .(oc_code, item_code)]

  nonfl_cors <- nonfl_resid_wide[, {
    if (.N >= 2) {
      pairs <- combn(min(.N, 10), 2)  # cap at 10 bids per tender
      cors <- sapply(seq_len(ncol(pairs)), function(p) {
        resid[pairs[1, p]] * resid[pairs[2, p]]
      })
      .(pair_product = cors)
    }
  }, by = .(oc_code, item_code)]

  if (nrow(nonfl_cors) > 0) {
    placebo_mean <- mean(nonfl_cors$pair_product, na.rm = TRUE)
    placebo_se   <- sd(nonfl_cors$pair_product, na.rm = TRUE) / sqrt(nrow(nonfl_cors))
    placebo_t    <- placebo_mean / placebo_se
    placebo_p    <- 2 * pnorm(-abs(placebo_t))

    cat(sprintf("  Placebo mean pairwise product: %.6f (SE: %.6f)\n",
                placebo_mean, placebo_se))
    cat(sprintf("  Placebo t-statistic: %.3f, p-value: %.6f\n", placebo_t, placebo_p))
    cat(sprintf("  Result: %s at 10%% level (expected: fail to reject)\n",
                if (placebo_p > 0.10) "FAIL TO REJECT (good)" else "REJECT (unexpected)"))
  }
}

# ============================================================================
# Save results
# ============================================================================

bj_results <- list(
  first_stage = list(
    r2 = fitstat(m_fs, "r2")[[1]],
    n = m_fs$nobs,
    has_ref = has_ref
  ),
  exchangeability = list(
    feasible = !is.null(ks_test),
    ks_stat = if (!is.null(ks_test)) ks_test$statistic else NA,
    ks_p = if (!is.null(ks_test)) ks_test$p.value else NA,
    n_fl_resid = length(resid_fl),
    n_nonfl_resid = length(resid_nonfl)
  ),
  independence = list(
    feasible = nrow(tenders_2plus) >= 50,
    n_tenders_2plus = nrow(tenders_2plus),
    mean_product = if (exists("mean_prod")) mean_prod else NA,
    se_product = if (exists("se_prod")) se_prod else NA,
    p_value = if (exists("p_val")) p_val else NA
  ),
  placebo = list(
    p_value = placebo_p
  )
)

saveRDS(bj_results, "/tmp/p3v2_bajari_ye.rds")
cat("  Bajari-Ye results saved: /tmp/p3v2_bajari_ye.rds\n")
cat("  Done.\n")
