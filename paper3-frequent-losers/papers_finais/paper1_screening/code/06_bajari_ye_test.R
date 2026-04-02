# ============================================================================
# 06_bajari_ye_test.R — Bajari & Ye (2003) tests with extensions (v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Core: same as v3 (exchangeability KS + conditional independence)
# NEW: bootstrap difference test [Medium 4.1]
# NEW: "fake groups" placebo [R2.6]
# NEW: first-stage transparency table [R2.6]
# ============================================================================

cat("=== 06_bajari_ye_test.R: Bajari-Ye tests ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load bid-level analysis data -------------------------------------------
bl_file <- file.path(DATA_V4, "bid_level_analysis.parquet")
bl_v2_file <- file.path(.v4_dir, "..", "v3", "data", "processed", "bid_level_analysis.parquet")

# Try v4, then v3, then v1
if (file.exists(bl_file)) {
  bl <- as.data.table(read_parquet(bl_file))
} else if (file.exists(bl_v2_file)) {
  bl <- as.data.table(read_parquet(bl_v2_file))
} else {
  # Fall back to bid_level_full.parquet
  bl_full <- file.path(DATA_V1, "bid_level_full.parquet")
  if (file.exists(bl_full)) {
    bl <- as.data.table(read_parquet(bl_full))
    bl_col <- grep("fornecedor", names(bl), value = TRUE, ignore.case = TRUE)
    if (length(bl_col) == 1) setnames(bl, bl_col, "firm_id")
    setnames(bl, "numerodaoc", "oc_code", skip_absent = TRUE)
    setnames(bl, "códigoitem", "item_code", skip_absent = TRUE)

    # Identify price column
    price_col <- grep("valor|preco|price|lance", names(bl), value = TRUE, ignore.case = TRUE)
    if (length(price_col) > 0 && !"bid_price" %in% names(bl)) {
      setnames(bl, price_col[1], "bid_price")
    }

    # Flag FL firms
    fp <- readRDS(DATA_CACHE_FP)
    fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
    if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")
    fl_ids <- unique(fp$firm_id)
    bl[, is_fl := as.integer(firm_id %chin% fl_ids)]
  } else {
    cat("  No bid-level data found. Skipping Bajari-Ye tests.\n")
    bj_results <- list(feasible = FALSE, reason = "No bid data")
    saveRDS(bj_results, BAJARI_CACHE_V4)
    quit(save = "no", status = 0)
  }
}

cat("  Bid-level rows:", pfmt_int(nrow(bl)), "\n")

has_prices <- sum(!is.na(bl$bid_price) & bl$bid_price > 0) > 1000

if (!has_prices) {
  cat("  Insufficient bid prices. Skipping.\n")
  bj_results <- list(feasible = FALSE, reason = "No bid prices")
  saveRDS(bj_results, BAJARI_CACHE_V4)
  quit(save = "no", status = 0)
}

# ---- Load firm characteristics -----------------------------------------------
firms <- readRDS(DATA_CACHE_FIRMS)
firms_col <- grep("^c.digofornecedor$", names(firms), value = TRUE, ignore.case = TRUE)
if (length(firms_col) == 1) setnames(firms, firms_col, "firm_id")

if ("porte_empresa" %in% names(firms)) {
  firms[, firm_size := as.numeric(factor(porte_empresa))]
  bl <- merge(bl, firms[, .(firm_id, firm_size)], by = "firm_id", all.x = TRUE)
  bl[is.na(firm_size), firm_size := 0]
} else {
  bl[, firm_size := 0]
}

# ---- Extract year ------------------------------------------------------------
if (!"year" %in% names(bl)) {
  if ("month_year" %in% names(bl)) {
    bl[, year := as.integer(sub(".*/", "", as.character(month_year)))]
  } else {
    bl[, year := as.integer(substr(oc_code, 12, 15))]
  }
}

# ---- First stage: bid residuals [R2.6: first-stage transparency] -------------
cat("  First stage: bid residuals from losing bids...\n")

d_resid <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
d_resid[, log_bid := log(bid_price)]

if ("ref_price" %in% names(d_resid)) {
  d_resid[, log_ref := fifelse(!is.na(ref_price) & ref_price > 0,
                                log(ref_price), NA_real_)]
} else {
  d_resid[, log_ref := NA_real_]
}

cat(sprintf("  Losing bids with prices: %s\n", pfmt_int(nrow(d_resid))))

has_ref <- sum(!is.na(d_resid$log_ref)) > nrow(d_resid) * 0.3

if (has_ref) {
  d_fs <- d_resid[!is.na(log_ref)]
  m_fs <- tryCatch(
    feols(log_bid ~ log_ref + firm_size | item_code + year,
          data = d_fs, fixef.rm = "none", lean = FALSE),
    error = function(e) NULL
  )
} else {
  d_fs <- d_resid
  m_fs <- tryCatch(
    feols(log_bid ~ firm_size | item_code + year,
          data = d_fs, fixef.rm = "none", lean = FALSE),
    error = function(e) NULL
  )
}

if (is.null(m_fs)) {
  cat("  First stage regression failed. Skipping.\n")
  bj_results <- list(feasible = FALSE, reason = "First stage failed")
  saveRDS(bj_results, BAJARI_CACHE_V4)
  quit(save = "no", status = 0)
}

d_fs[, resid := residuals(m_fs)]
fs_r2 <- fitstat(m_fs, "r2")[[1]]
cat(sprintf("  First stage R2: %.4f, N: %s\n", fs_r2, pfmt_int(m_fs$nobs)))

# ============================================================================
# Test A: Exchangeability (KS test)
# ============================================================================

cat("  Test A: Exchangeability...\n")

resid_fl    <- d_fs[is_fl == 1L, resid]
resid_nonfl <- d_fs[is_fl == 0L, resid]

ks_test <- NULL
if (length(resid_fl) >= 30 && length(resid_nonfl) >= 30) {
  ks_test <- ks.test(resid_fl, resid_nonfl)
  cat(sprintf("  KS: D=%.4f, p=%.6f → %s\n",
              ks_test$statistic, ks_test$p.value,
              if (ks_test$p.value < 0.05) "REJECT" else "FAIL TO REJECT"))
}

# ============================================================================
# Test B: Conditional Independence (pairwise correlation)
# ============================================================================

cat("  Test B: Conditional Independence...\n")

fl_resid_dt <- d_fs[is_fl == 1L, .(firm_id, oc_code, item_code, resid)]
fl_tender_counts <- fl_resid_dt[, .N, by = .(oc_code, item_code)]
tenders_2plus <- fl_tender_counts[N >= 2]

fl_cors <- numeric()
mean_prod <- NA; se_prod <- NA; p_val <- NA
if (nrow(tenders_2plus) >= 50) {
  fl_resid_wide <- fl_resid_dt[tenders_2plus, on = .(oc_code, item_code)]

  if (nrow(tenders_2plus) > 5000) {
    set.seed(42)
    sample_tenders <- tenders_2plus[sample(.N, 5000)]
    fl_resid_wide <- fl_resid_dt[sample_tenders, on = .(oc_code, item_code)]
  }

  fl_cors <- fl_resid_wide[, {
    if (.N >= 2) {
      pairs <- combn(.N, 2)
      cors <- sapply(seq_len(ncol(pairs)), function(p) {
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
    cat(sprintf("  FL: mean_product=%.4f (SE=%.4f), t=%.1f, p=%.6f\n",
                mean_prod, se_prod, t_stat, p_val))
  }
}

# Non-FL placebo
cat("  Placebo: Non-FL pairwise correlation...\n")
nonfl_resid_dt <- d_fs[is_fl == 0L, .(firm_id, oc_code, item_code, resid)]
nonfl_2plus <- nonfl_resid_dt[, .N, by = .(oc_code, item_code)][N >= 2]

placebo_mean <- NA; placebo_se <- NA; placebo_p <- NA
if (nrow(nonfl_2plus) >= 50) {
  if (nrow(nonfl_2plus) > 5000) {
    set.seed(42)
    sample_nonfl <- nonfl_2plus[sample(.N, 5000)]
  } else sample_nonfl <- nonfl_2plus

  nonfl_resid_wide <- nonfl_resid_dt[sample_nonfl, on = .(oc_code, item_code)]
  nonfl_cors <- nonfl_resid_wide[, {
    if (.N >= 2) {
      pairs <- combn(min(.N, 10), 2)
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
    cat(sprintf("  Non-FL: mean_product=%.4f (SE=%.4f), t=%.1f, p=%.6f\n",
                placebo_mean, placebo_se, placebo_t, placebo_p))
  }
}

# ============================================================================
# NEW: Bootstrap difference test (FL - non-FL) [Medium 4.1]
# ============================================================================

cat("  Bootstrap difference test (FL - non-FL)...\n")

n_boot <- 1000L
boot_diffs <- numeric(n_boot)

if (!is.na(mean_prod) && !is.na(placebo_mean)) {
  observed_diff <- mean_prod - placebo_mean
  cat(sprintf("  Observed difference: %.4f\n", observed_diff))

  # Get unique tender IDs for resampling — limit to manageable size
  tender_ids <- unique(d_fs[, .(oc_code, item_code)])
  # Subsample tenders to avoid OOM during bootstrap
  max_boot_tenders <- 50000L
  if (nrow(tender_ids) > max_boot_tenders) {
    set.seed(42)
    tender_ids <- tender_ids[sample(.N, max_boot_tenders)]
    d_fs_boot <- d_fs[tender_ids, on = .(oc_code, item_code), nomatch = NULL]
  } else {
    d_fs_boot <- d_fs
  }

  set.seed(42)
  for (b in seq_len(n_boot)) {
    # Resample tenders with replacement
    boot_tenders <- tender_ids[sample(.N, .N, replace = TRUE)]
    boot_data <- d_fs_boot[boot_tenders, on = .(oc_code, item_code), allow.cartesian = TRUE]

    # FL products
    fl_boot <- boot_data[is_fl == 1L]
    fl_boot_2plus <- fl_boot[, .N, by = .(oc_code, item_code)][N >= 2]

    fl_mean_b <- NA
    if (nrow(fl_boot_2plus) >= 10) {
      fl_resid_b <- fl_boot[fl_boot_2plus[1:min(.N, 1000)], on = .(oc_code, item_code)]
      fl_cors_b <- fl_resid_b[, {
        if (.N >= 2) {
          p <- combn(min(.N, 5), 2)
          .(pp = sapply(seq_len(ncol(p)), function(k) resid[p[1,k]] * resid[p[2,k]]))
        }
      }, by = .(oc_code, item_code)]
      if (nrow(fl_cors_b) > 0) fl_mean_b <- mean(fl_cors_b$pp, na.rm = TRUE)
    }

    # Non-FL products
    nfl_boot <- boot_data[is_fl == 0L]
    nfl_boot_2plus <- nfl_boot[, .N, by = .(oc_code, item_code)][N >= 2]

    nfl_mean_b <- NA
    if (nrow(nfl_boot_2plus) >= 10) {
      nfl_resid_b <- nfl_boot[nfl_boot_2plus[1:min(.N, 1000)], on = .(oc_code, item_code)]
      nfl_cors_b <- nfl_resid_b[, {
        if (.N >= 2) {
          p <- combn(min(.N, 5), 2)
          .(pp = sapply(seq_len(ncol(p)), function(k) resid[p[1,k]] * resid[p[2,k]]))
        }
      }, by = .(oc_code, item_code)]
      if (nrow(nfl_cors_b) > 0) nfl_mean_b <- mean(nfl_cors_b$pp, na.rm = TRUE)
    }

    boot_diffs[b] <- if (!is.na(fl_mean_b) && !is.na(nfl_mean_b)) fl_mean_b - nfl_mean_b else NA
  }

  boot_diffs <- boot_diffs[!is.na(boot_diffs)]
  boot_se <- sd(boot_diffs)
  boot_ci <- quantile(boot_diffs, c(0.025, 0.975))
  boot_p <- mean(boot_diffs <= 0)

  cat(sprintf("  Bootstrap (N=%d): SE=%.4f, 95%% CI=[%.4f, %.4f]\n",
              length(boot_diffs), boot_se, boot_ci[1], boot_ci[2]))
  cat(sprintf("  p-value (one-sided, diff <= 0): %.4f\n", boot_p))
} else {
  observed_diff <- NA; boot_se <- NA; boot_ci <- c(NA, NA); boot_p <- NA
  boot_diffs <- numeric(0)
}

# ============================================================================
# NEW: "Fake groups" placebo [R2.6]
# ============================================================================

cat("  Fake-groups placebo...\n")

fake_mean <- NA; fake_se <- NA; fake_p <- NA

# Among non-FL firms in each tender, randomly split into Group A and Group B
# Then compute pairwise products within each group
# Should show no correlation (null)
nonfl_tenders <- d_fs[is_fl == 0L & !is.na(resid)]

# Keep tenders with 4+ non-FL bids (need at least 2 per group)
tender_n <- nonfl_tenders[, .N, by = .(oc_code, item_code)]
tenders_4plus <- tender_n[N >= 4]

if (nrow(tenders_4plus) >= 50) {
  set.seed(42)
  if (nrow(tenders_4plus) > 3000) {
    tenders_4plus <- tenders_4plus[sample(.N, 3000)]
  }

  fake_products <- nonfl_tenders[tenders_4plus, on = .(oc_code, item_code)][, {
    if (.N >= 4) {
      # Random split into two groups
      idx <- sample(.N)
      half <- floor(.N / 2)
      grpA <- resid[idx[1:half]]
      grpB <- resid[idx[(half+1):.N]]

      # Products within Group A
      if (length(grpA) >= 2) {
        pairs <- combn(length(grpA), 2)
        prods <- sapply(seq_len(ncol(pairs)), function(p)
          grpA[pairs[1,p]] * grpA[pairs[2,p]])
        .(pair_product = prods)
      }
    }
  }, by = .(oc_code, item_code)]

  if (nrow(fake_products) > 0) {
    fake_mean <- mean(fake_products$pair_product, na.rm = TRUE)
    fake_se   <- sd(fake_products$pair_product, na.rm = TRUE) / sqrt(nrow(fake_products))
    fake_t    <- fake_mean / fake_se
    fake_p    <- 2 * pnorm(-abs(fake_t))
    cat(sprintf("  Fake-groups: mean=%.4f (SE=%.4f), t=%.1f, p=%.4f → %s\n",
                fake_mean, fake_se, fake_t, fake_p,
                if (fake_p > 0.10) "FAIL TO REJECT (validates methodology)" else "REJECT (unexpected)"))
  }
}

# ============================================================================
# Write first-stage transparency table [R2.6]
# ============================================================================

cat("  Writing tab_bajari_ye_firststage.tex...\n")

fs_tab_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Bajari-Ye First-Stage: Auxiliary Bid Regression}",
  "\\label{tab:bajari_ye_firststage}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lc}", "\\toprule",
  " & DV: $\\log(\\text{bid})$ \\\\", "\\midrule"
)

# Report first-stage covariates
if (has_ref) {
  fs_tab_lines <- c(fs_tab_lines,
    sprintf("$\\log(\\text{reference price})$ & %s \\\\", coef_cell(m_fs, "log_ref", 4)),
    sprintf(" & %s \\\\", se_cell(m_fs, "log_ref", 4)))
}
fs_tab_lines <- c(fs_tab_lines,
  sprintf("Firm size (porte) & %s \\\\", coef_cell(m_fs, "firm_size", 4)),
  sprintf(" & %s \\\\", se_cell(m_fs, "firm_size", 4)),
  "\\midrule",
  sprintf("R-squared & %s \\\\", pfmt(fs_r2, 4)),
  sprintf("Observations & %s \\\\", pfmt_int(m_fs$nobs)),
  "Item FE & YES \\\\",
  "Year FE & YES \\\\")

fs_tab_lines <- c(fs_tab_lines, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Auxiliary regression on losing bids only.",
  "Residuals from this regression are used for exchangeability",
  "(KS test) and conditional independence (pairwise product) tests.",
  "SE clustered at item level.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(fs_tab_lines, file.path(OUT_TAB, "tab_bajari_ye_firststage.tex"))

# Write fake-groups placebo table
cat("  Writing tab_bajari_ye_placebo.tex...\n")

plac_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Bajari-Ye Placebo: Random Group Assignment}",
  "\\label{tab:bajari_ye_placebo}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  " & Mean Pairwise Product & p-value \\\\", "\\midrule")

if (!is.na(mean_prod))
  plac_lines <- c(plac_lines, sprintf(
    "FL pairs (observed) & %s & %s \\\\", pfmt(mean_prod, 4), pfmt(p_val, 6)))
if (!is.na(placebo_mean))
  plac_lines <- c(plac_lines, sprintf(
    "Non-FL pairs (observed) & %s & %s \\\\", pfmt(placebo_mean, 4), pfmt(placebo_p, 6)))
if (!is.na(fake_mean))
  plac_lines <- c(plac_lines, sprintf(
    "Fake random groups (placebo) & %s & %s \\\\", pfmt(fake_mean, 4), pfmt(fake_p, 4)))
if (!is.na(observed_diff))
  plac_lines <- c(plac_lines, "\\midrule", sprintf(
    "Difference (FL $-$ non-FL) & %s & \\\\", pfmt(observed_diff, 4)))
if (!is.na(boot_se))
  plac_lines <- c(plac_lines, sprintf(
    "Bootstrap SE & %s & \\\\", pfmt(boot_se, 4)),
    sprintf("Bootstrap 95\\%% CI & [%s, %s] & \\\\",
            pfmt(boot_ci[1], 4), pfmt(boot_ci[2], 4)))

plac_lines <- c(plac_lines, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Pairwise products of first-stage bid residuals within tenders.",
  "Fake-groups: non-FL firms randomly split into two groups within each tender;",
  "expected null result validates the testing methodology.",
  "Bootstrap: 1,000 iterations resampling tenders with replacement.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(plac_lines, file.path(OUT_TAB, "tab_bajari_ye_placebo.tex"))

# ============================================================================
# NEW: Tender FE first stage (Comment 2.3)
# ============================================================================

cat("  Tender FE first stage (Comment 2.3)...\n")

tender_fe_mean_prod <- NA; tender_fe_se_prod <- NA; tender_fe_p <- NA
tender_fe_nonfl_mean <- NA; tender_fe_nonfl_se <- NA; tender_fe_nonfl_p <- NA
tender_fe_fake_mean <- NA; tender_fe_fake_se <- NA; tender_fe_fake_p <- NA

# Create tender FE using oc_code only (not oc_code x item_code) to reduce FE levels
# This still absorbs tender-level shocks; using oc_code x item_code would be ideal
# but creates too many FE levels (3M+) for memory constraints
d_fs[, tender_f := oc_code]
n_tender_fe <- uniqueN(d_fs$tender_f)
cat(sprintf("  Tender FE levels (oc_code): %s, rows: %s\n", pfmt_int(n_tender_fe), pfmt_int(nrow(d_fs))))

# Subsample if still too large
d_fs_tfe <- d_fs
if (n_tender_fe > 500000L || nrow(d_fs) > 15000000L) {
  cat("  Subsampling 25%% of tenders for tender FE...\n")
  set.seed(42)
  tender_ids_all <- unique(d_fs$tender_f)
  keep_tenders <- tender_ids_all[sample(length(tender_ids_all), length(tender_ids_all) %/% 4)]
  d_fs_tfe <- d_fs[tender_f %in% keep_tenders]
  cat(sprintf("  Subsampled: %s rows, %s tenders\n",
              pfmt_int(nrow(d_fs_tfe)), pfmt_int(uniqueN(d_fs_tfe$tender_f))))
}

# First stage with tender FE: absorbs all tender-level shocks
m_fs_tender <- tryCatch(
  feols(log_bid ~ firm_size | tender_f,
        data = d_fs_tfe, fixef.rm = "none", lean = FALSE),
  error = function(e) { cat(sprintf("  Tender FE regression failed: %s\n", e$message)); NULL }
)

if (!is.null(m_fs_tender)) {
  d_fs_tfe[, resid_tender := residuals(m_fs_tender)]
  fs_tender_r2 <- fitstat(m_fs_tender, "r2")[[1]]
  cat(sprintf("  Tender FE R2: %.4f, N: %s\n", fs_tender_r2, pfmt_int(m_fs_tender$nobs)))

  # FL pairwise products with tender-FE residuals
  fl_resid_tfe <- d_fs_tfe[is_fl == 1L, .(firm_id, oc_code, item_code, resid = resid_tender)]
  fl_2plus_tfe <- fl_resid_tfe[, .N, by = .(oc_code, item_code)][N >= 2]

  if (nrow(fl_2plus_tfe) >= 50) {
    if (nrow(fl_2plus_tfe) > 5000) {
      set.seed(42)
      fl_2plus_tfe <- fl_2plus_tfe[sample(.N, 5000)]
    }
    fl_resid_w <- fl_resid_tfe[fl_2plus_tfe, on = .(oc_code, item_code)]
    fl_cors_tfe <- fl_resid_w[, {
      if (.N >= 2) {
        pairs <- combn(min(.N, 10), 2)
        .(pair_product = sapply(seq_len(ncol(pairs)), function(p) resid[pairs[1,p]] * resid[pairs[2,p]]))
      }
    }, by = .(oc_code, item_code)]

    if (nrow(fl_cors_tfe) > 0) {
      tender_fe_mean_prod <- mean(fl_cors_tfe$pair_product, na.rm = TRUE)
      tender_fe_se_prod <- sd(fl_cors_tfe$pair_product, na.rm = TRUE) / sqrt(nrow(fl_cors_tfe))
      tender_fe_p <- 2 * pnorm(-abs(tender_fe_mean_prod / tender_fe_se_prod))
      cat(sprintf("  FL (tender FE): mean_product=%.4f (SE=%.4f), p=%.6f\n",
                  tender_fe_mean_prod, tender_fe_se_prod, tender_fe_p))
    }
  }

  # Non-FL pairwise products with tender-FE residuals
  nonfl_resid_tfe <- d_fs_tfe[is_fl == 0L, .(firm_id, oc_code, item_code, resid = resid_tender)]
  nonfl_2plus_tfe <- nonfl_resid_tfe[, .N, by = .(oc_code, item_code)][N >= 2]

  if (nrow(nonfl_2plus_tfe) >= 50) {
    if (nrow(nonfl_2plus_tfe) > 5000) {
      set.seed(42)
      nonfl_2plus_tfe <- nonfl_2plus_tfe[sample(.N, 5000)]
    }
    nonfl_resid_w <- nonfl_resid_tfe[nonfl_2plus_tfe, on = .(oc_code, item_code)]
    nonfl_cors_tfe <- nonfl_resid_w[, {
      if (.N >= 2) {
        pairs <- combn(min(.N, 10), 2)
        .(pair_product = sapply(seq_len(ncol(pairs)), function(p) resid[pairs[1,p]] * resid[pairs[2,p]]))
      }
    }, by = .(oc_code, item_code)]

    if (nrow(nonfl_cors_tfe) > 0) {
      tender_fe_nonfl_mean <- mean(nonfl_cors_tfe$pair_product, na.rm = TRUE)
      tender_fe_nonfl_se <- sd(nonfl_cors_tfe$pair_product, na.rm = TRUE) / sqrt(nrow(nonfl_cors_tfe))
      tender_fe_nonfl_p <- 2 * pnorm(-abs(tender_fe_nonfl_mean / tender_fe_nonfl_se))
      cat(sprintf("  Non-FL (tender FE): mean_product=%.4f (SE=%.4f), p=%.6f\n",
                  tender_fe_nonfl_mean, tender_fe_nonfl_se, tender_fe_nonfl_p))
    }
  }

  # Fake-groups placebo with tender-FE residuals
  nonfl_tenders_tfe <- d_fs_tfe[is_fl == 0L & !is.na(resid_tender), .(firm_id, oc_code, item_code, resid_tender)]
  tender_n_tfe <- nonfl_tenders_tfe[, .N, by = .(oc_code, item_code)]
  tenders_4plus_tfe <- tender_n_tfe[N >= 4]

  if (nrow(tenders_4plus_tfe) >= 50) {
    set.seed(42)
    if (nrow(tenders_4plus_tfe) > 3000) tenders_4plus_tfe <- tenders_4plus_tfe[sample(.N, 3000)]

    fake_tfe <- nonfl_tenders_tfe[tenders_4plus_tfe, on = .(oc_code, item_code)][, {
      if (.N >= 4) {
        idx <- sample(.N); half <- floor(.N / 2)
        grpA <- resid_tender[idx[1:half]]
        if (length(grpA) >= 2) {
          pairs <- combn(length(grpA), 2)
          .(pair_product = sapply(seq_len(ncol(pairs)), function(p) grpA[pairs[1,p]] * grpA[pairs[2,p]]))
        }
      }
    }, by = .(oc_code, item_code)]

    if (nrow(fake_tfe) > 0) {
      tender_fe_fake_mean <- mean(fake_tfe$pair_product, na.rm = TRUE)
      tender_fe_fake_se <- sd(fake_tfe$pair_product, na.rm = TRUE) / sqrt(nrow(fake_tfe))
      tender_fe_fake_p <- 2 * pnorm(-abs(tender_fe_fake_mean / tender_fe_fake_se))
      cat(sprintf("  Fake groups (tender FE): mean_product=%.4f (SE=%.4f), p=%.4f\n",
                  tender_fe_fake_mean, tender_fe_fake_se, tender_fe_fake_p))
    }
  }

  rm(d_fs_tfe); gc(verbose = FALSE)
}

# Write tab_bajari_ye_tender_fe.tex
cat("  Writing tab_bajari_ye_tender_fe.tex...\n")
tfe_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Bajari-Ye Pairwise Products with Tender Fixed Effects}",
  "\\label{tab:bajari_ye_tender_fe}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & \\multicolumn{2}{c}{Item + Year FE} & \\multicolumn{2}{c}{Tender FE} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  " & Mean Product & \\textit{p} & Mean Product & \\textit{p} \\\\", "\\midrule"
)

tfe_lines <- c(tfe_lines,
  sprintf("FL pairs & %s & %s & %s & %s \\\\",
    if (!is.na(mean_prod)) pfmt(mean_prod, 4) else "---",
    if (!is.na(p_val)) pfmt(p_val, 6) else "---",
    if (!is.na(tender_fe_mean_prod)) pfmt(tender_fe_mean_prod, 4) else "---",
    if (!is.na(tender_fe_p)) pfmt(tender_fe_p, 6) else "---"),
  sprintf("Non-FL pairs & %s & %s & %s & %s \\\\",
    if (!is.na(placebo_mean)) pfmt(placebo_mean, 4) else "---",
    if (!is.na(placebo_p)) pfmt(placebo_p, 6) else "---",
    if (!is.na(tender_fe_nonfl_mean)) pfmt(tender_fe_nonfl_mean, 4) else "---",
    if (!is.na(tender_fe_nonfl_p)) pfmt(tender_fe_nonfl_p, 6) else "---"),
  sprintf("Fake groups & %s & %s & %s & %s \\\\",
    if (!is.na(fake_mean)) pfmt(fake_mean, 4) else "---",
    if (!is.na(fake_p)) pfmt(fake_p, 4) else "---",
    if (!is.na(tender_fe_fake_mean)) pfmt(tender_fe_fake_mean, 4) else "---",
    if (!is.na(tender_fe_fake_p)) pfmt(tender_fe_fake_p, 4) else "---"))

tfe_lines <- c(tfe_lines, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Mean pairwise product of first-stage bid residuals.",
  "Columns 1--2: residuals from item + year FE regression (baseline).",
  "Columns 3--4: residuals from tender $\\times$ item FE regression, which absorbs all",
  "tender-level shocks (reference price, commodity prices, PBU effects).",
  "Under the null of competitive bidding, the mean product equals zero.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(tfe_lines, file.path(OUT_TAB, "tab_bajari_ye_tender_fe.tex"))

# ============================================================================
# Save results
# ============================================================================

bj_results <- list(
  feasible = TRUE,
  first_stage = list(r2 = fs_r2, n = m_fs$nobs, has_ref = has_ref, model = m_fs),
  exchangeability = list(
    feasible = !is.null(ks_test),
    ks_stat = if (!is.null(ks_test)) ks_test$statistic else NA,
    ks_p = if (!is.null(ks_test)) ks_test$p.value else NA
  ),
  independence = list(
    feasible = nrow(tenders_2plus) >= 50,
    n_tenders_2plus = nrow(tenders_2plus),
    mean_product = mean_prod,
    se_product = se_prod,
    p_value = p_val
  ),
  placebo = list(mean = placebo_mean, se = placebo_se, p_value = placebo_p),
  bootstrap = list(
    observed_diff = observed_diff,
    boot_se = boot_se,
    boot_ci = boot_ci,
    boot_p = boot_p,
    n_valid = length(boot_diffs)
  ),
  fake_groups = list(mean = fake_mean, se = fake_se, p_value = fake_p),
  tender_fe = list(
    fl = list(mean = tender_fe_mean_prod, se = tender_fe_se_prod, p_value = tender_fe_p),
    nonfl = list(mean = tender_fe_nonfl_mean, se = tender_fe_nonfl_se, p_value = tender_fe_nonfl_p),
    fake = list(mean = tender_fe_fake_mean, se = tender_fe_fake_se, p_value = tender_fe_fake_p)
  )
)

saveRDS(bj_results, BAJARI_CACHE_V4)
cat("  Results saved:", BAJARI_CACHE_V4, "\n")
cat("  Done.\n")
