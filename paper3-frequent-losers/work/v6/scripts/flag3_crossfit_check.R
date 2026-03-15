# ============================================================================
# flag3_crossfit_check.R — Cross-fit attenuation check (v6)
# Paper 3 v6: Frequent Losers in Public Procurement
# ============================================================================
# Purpose: Check cross-fit attenuation of the FL price effect.
#   1. Try loading v4 robustness cache for pre-computed cross-fit results
#   2. If not available, run fresh 2-fold cross-validation on BEC_collapse_final
#   3. Report: full-sample OLS (0.064), cross-fit average, attenuation ratio
# Outputs:
#   - work/v6/tables/crossfit_results.csv
#   - work/v6/FLAG_crossfit.txt (if data missing)
# ============================================================================

cat("=== flag3_crossfit_check.R: Cross-fit attenuation check ===\n")

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(arrow)
})

# ---- Path constants ---------------------------------------------------------
BASE_DIR   <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
DATA_DIR   <- file.path(BASE_DIR, "data", "processed")
V6_DIR     <- file.path(BASE_DIR, "work", "v6")
OUT_TAB    <- file.path(V6_DIR, "tables")
FLAG_DIR   <- V6_DIR

dir.create(OUT_TAB, recursive = TRUE, showWarnings = FALSE)

NCORES <- min(parallel::detectCores(logical = FALSE), 16L)
setDTthreads(NCORES)
setFixest_nthreads(NCORES)
setFixest_estimation(lean = TRUE)

pfmt     <- function(x, d = 4) formatC(x, format = "f", digits = d, big.mark = ",")
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

# ---- Check v4 caches -------------------------------------------------------
ROBUSTNESS_CACHE <- "/tmp/p3v4_robustness.rds"
FL_ROBUST_CACHE  <- "/tmp/p3v4_fl_robust.rds"
MODELS_CACHE     <- "/tmp/p3v4_models.rds"
DATA_CACHE_V4    <- "/tmp/p3v4_prepared.rds"
WELFARE_CACHE    <- "/tmp/p3v4_welfare.rds"

cat("  Checking v4 caches...\n")
cat(sprintf("    Robustness cache: %s\n", file.exists(ROBUSTNESS_CACHE)))
cat(sprintf("    FL robust cache: %s\n", file.exists(FL_ROBUST_CACHE)))
cat(sprintf("    Models cache: %s\n", file.exists(MODELS_CACHE)))
cat(sprintf("    Data cache (v4): %s\n", file.exists(DATA_CACHE_V4)))
cat(sprintf("    Welfare cache: %s\n", file.exists(WELFARE_CACHE)))

# ---- Try to extract cross-fit from caches ----------------------------------
crossfit_avg <- NA
ols_coef <- NA
attenuation <- NA
source_used <- "none"
ols_se <- NA
cf_fold1 <- NA; cf_fold2 <- NA

# Strategy 1: Check robustness or FL robust cache
if (file.exists(ROBUSTNESS_CACHE)) {
  cat("  Loading robustness cache...\n")
  rob <- readRDS(ROBUSTNESS_CACHE)
  cat(sprintf("  Robustness cache contents: %s\n", paste(names(rob), collapse = ", ")))

  # Look for cross-fit results in various possible locations
  if (!is.null(rob$crossfit)) {
    cat("  Found cross-fit in robustness cache.\n")
    if (is.list(rob$crossfit)) {
      if (!is.null(rob$crossfit$avg_coef)) crossfit_avg <- rob$crossfit$avg_coef
      if (!is.null(rob$crossfit$fold1)) cf_fold1 <- rob$crossfit$fold1
      if (!is.null(rob$crossfit$fold2)) cf_fold2 <- rob$crossfit$fold2
    }
    source_used <- "robustness_cache"
  }
}

if (file.exists(FL_ROBUST_CACHE) && is.na(crossfit_avg)) {
  cat("  Loading FL robust cache...\n")
  fl_rob <- readRDS(FL_ROBUST_CACHE)
  cat(sprintf("  FL robust cache contents: %s\n", paste(names(fl_rob), collapse = ", ")))
  if (!is.null(fl_rob$crossfit)) {
    if (is.list(fl_rob$crossfit)) {
      if (!is.null(fl_rob$crossfit$avg_coef)) crossfit_avg <- fl_rob$crossfit$avg_coef
    }
    source_used <- "fl_robust_cache"
  }
}

if (file.exists(WELFARE_CACHE) && is.na(crossfit_avg)) {
  cat("  Loading welfare cache...\n")
  welfare <- readRDS(WELFARE_CACHE)
  cat(sprintf("  Welfare cache contents: %s\n", paste(names(welfare), collapse = ", ")))
  if (!is.null(welfare$crossfit)) {
    if (is.list(welfare$crossfit)) {
      if (!is.null(welfare$crossfit$avg_coef)) crossfit_avg <- welfare$crossfit$avg_coef
    }
    source_used <- "welfare_cache"
  }
}

# Get OLS baseline from models cache
if (file.exists(MODELS_CACHE)) {
  cat("  Loading models cache for baseline OLS...\n")
  models <- readRDS(MODELS_CACHE)
  if (!is.null(models$prices$general_pbu)) {
    m_baseline <- models$prices$general_pbu
    ols_coef <- coef(m_baseline)["losers"]
    ols_se   <- sqrt(vcov(m_baseline)["losers", "losers"])
    cat(sprintf("  Baseline OLS: %.4f (SE=%.4f)\n", ols_coef, ols_se))
    source_used <- paste(source_used, "+ models_cache")
  }
}

# ---- Strategy 2: Run fresh cross-validation if needed -----------------------
BEC_PARQUET <- file.path(DATA_DIR, "BEC_collapse_final.parquet")
LOSERS_PARQUET <- file.path(DATA_DIR, "LOSERS_rebuilt.parquet")
FP_PARQUET <- file.path(DATA_DIR, "FREQ_PARTICIP_rebuilt.parquet")
FTM_PARQUET <- file.path(DATA_DIR, "firm_tender_map.parquet")

need_fresh <- is.na(crossfit_avg) || is.na(ols_coef)

if (need_fresh) {
  cat("  No cross-fit results from caches. Attempting fresh computation...\n")

  if (!file.exists(BEC_PARQUET)) {
    flag_msg <- paste0(
      "FLAG: Cross-fit check cannot run.\n",
      "Missing: BEC_collapse_final.parquet\n",
      "Cache status:\n",
      "  Robustness: ", file.exists(ROBUSTNESS_CACHE), "\n",
      "  FL robust: ", file.exists(FL_ROBUST_CACHE), "\n",
      "  Models: ", file.exists(MODELS_CACHE), "\n",
      "  Welfare: ", file.exists(WELFARE_CACHE), "\n",
      if (!is.na(ols_coef)) sprintf("  OLS from cache: %.4f\n", ols_coef) else "",
      "\nTimestamp: ", Sys.time(), "\n"
    )
    writeLines(flag_msg, file.path(FLAG_DIR, "FLAG_crossfit.txt"))
    cat("  FLAG written.\n")

    if (!is.na(ols_coef)) {
      # Still write partial results
      results_df <- data.frame(
        metric = c("ols_coef", "ols_se", "crossfit_avg", "attenuation_ratio", "source"),
        value = c(pfmt(ols_coef, 4), pfmt(ols_se, 4), "N/A", "N/A",
                  "partial (models_cache only)")
      )
      write.csv(results_df, file.path(OUT_TAB, "crossfit_results.csv"), row.names = FALSE)
      cat("  Partial results written.\n")
    }
    cat("  Done (with flag).\n")
    quit(save = "no", status = 0)
  }

  # ---- Load and prepare BEC data ------------------------------------------
  cat("  Loading BEC_collapse_final.parquet...\n")
  dt <- as.data.table(read_parquet(BEC_PARQUET))
  cat(sprintf("  BEC rows: %s, cols: %s\n", pfmt_int(nrow(dt)), paste(names(dt), collapse = ", ")))

  # Standardize column names (BEC parquet uses po_item_merge_key, not numerodaoc/códigoitem)
  setnames(dt, "numerodaoc", "oc_code", skip_absent = TRUE)
  setnames(dt, "códigoitem", "item_code", skip_absent = TRUE)

  # Extract BEC key fields if po_item_merge_key exists
  if ("po_item_merge_key" %in% names(dt)) {
    dt[, pbu_code := substr(po_item_merge_key, 1, 11)]
    dt[, year := as.integer(substr(po_item_merge_key, 12, 15))]
    # oc_code = first 22 chars of po_item_merge_key (BEC has no numerodaoc column)
    if (!"oc_code" %in% names(dt)) {
      dt[, oc_code := substr(po_item_merge_key, 1, 22)]
    }
    dt[, item_rest := substr(po_item_merge_key, 23, nchar(po_item_merge_key))]
    # Do NOT overwrite po_phase_code if it already exists as a proper column
    if (!"po_phase_code" %in% names(dt) || all(is.na(dt$po_phase_code))) {
      dt[, po_phase_code := as.integer(substr(item_rest, nchar(item_rest), nchar(item_rest)))]
    }
  }

  # Filter to phases 2 and 3
  phase_col <- grep("phase|fase|modalidade", names(dt), value = TRUE, ignore.case = TRUE)
  if ("po_phase_code" %in% names(dt)) {
    dt <- dt[po_phase_code %in% c(2L, 3L)]
    dt[, convite := as.integer(po_phase_code == 2L)]
    dt[, pregao := as.integer(po_phase_code == 3L)]
  } else if (length(phase_col) > 0) {
    cat(sprintf("  Phase column: %s\n", phase_col[1]))
  }

  # Identify or create losers variable
  if (!"losers" %in% names(dt)) {
    cat("  Creating losers variable...\n")
    if (file.exists(LOSERS_PARQUET)) {
      losers_dt <- as.data.table(read_parquet(LOSERS_PARQUET))
      setnames(losers_dt, "numerodaoc", "oc_code", skip_absent = TRUE)
      setnames(losers_dt, "códigoitem", "item_code", skip_absent = TRUE)

      losers_col <- grep("losers|fl_count|n_fl", names(losers_dt), value = TRUE, ignore.case = TRUE)
      if (length(losers_col) > 0) {
        if (losers_col[1] != "losers_count") setnames(losers_dt, losers_col[1], "losers_count")
      }

      # BEC data uses po_item_merge_key and has no item_code column; merge on oc_code only
      # by aggregating losers_count to the OC level
      if (!"item_code" %in% names(dt)) {
        losers_agg <- losers_dt[, .(losers_count = sum(losers_count, na.rm = TRUE)), by = oc_code]
        dt <- merge(dt, losers_agg, by = "oc_code", all.x = TRUE)
      } else {
        dt <- merge(dt, losers_dt[, .(oc_code, item_code, losers_count)],
                    by = c("oc_code", "item_code"), all.x = TRUE)
      }
      dt[is.na(losers_count), losers_count := 0L]
      dt[, losers := as.integer(losers_count > 0L)]
    } else if (file.exists(FP_PARQUET) && file.exists(FTM_PARQUET)) {
      cat("  Building losers from FP + FTM...\n")
      fp <- as.data.table(read_parquet(FP_PARQUET))
      fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
      if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

      q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
      iqr_val <- q[3] - q[1]
      threshold <- q[2] + 1.5 * iqr_val
      fl_ids <- fp[tenders_count > threshold, firm_id]

      ftm <- as.data.table(read_parquet(FTM_PARQUET))
      ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
      if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
      setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
      setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

      fl_tenders <- ftm[firm_id %chin% fl_ids, .(losers_count = .N), by = .(oc_code, item_code)]
      dt <- merge(dt, fl_tenders, by = c("oc_code", "item_code"), all.x = TRUE)
      dt[is.na(losers_count), losers_count := 0L]
      dt[, losers := as.integer(losers_count > 0L)]
      rm(fp, ftm, fl_tenders); gc(verbose = FALSE)
    } else {
      flag_msg <- paste0(
        "FLAG: Cannot create losers variable.\n",
        "Missing LOSERS_rebuilt.parquet and FTM/FP alternatives.\n",
        "Timestamp: ", Sys.time(), "\n"
      )
      writeLines(flag_msg, file.path(FLAG_DIR, "FLAG_crossfit.txt"))
      cat("  FLAG written.\n")
      quit(save = "no", status = 0)
    }
  }

  cat(sprintf("  losers=1: %s / %s total\n",
              pfmt_int(sum(dt$losers == 1L, na.rm = TRUE)),
              pfmt_int(nrow(dt))))

  # Create DV: log negotiated price
  if ("bid_unit_price_negot_min" %in% names(dt)) {
    dt[bid_unit_price_negot_min > 0, lneg_price := log(bid_unit_price_negot_min)]
  } else {
    price_col <- grep("preco.*neg|neg.*price|lneg|valornega|unit_price_negot", names(dt), value = TRUE, ignore.case = TRUE)
    if (length(price_col) > 0) {
      dt[, price_raw := as.numeric(dt[[price_col[1]]])]
      dt[price_raw > 0, lneg_price := log(price_raw)]
    }
  }

  # Create fixed effects — use po_item_merge_key as item-level FE
  # (each unique po_item_merge_key = one tender-item)
  if (!"item_f" %in% names(dt)) {
    if ("po_item_merge_key" %in% names(dt)) {
      # Extract item group from item_rest (first few digits = item code)
      dt[, item_group := substr(item_rest, 1, 4)]
      dt[, item_f := as.factor(item_group)]
    } else if ("item_code" %in% names(dt)) {
      dt[, item_f := as.factor(item_code)]
    }
  }
  if (!"year_f" %in% names(dt)) {
    if ("year" %in% names(dt)) dt[, year_f := as.factor(year)]
    else dt[, year_f := as.factor(2014)]
  }
  if (!"pbu_f" %in% names(dt)) {
    pbu_col <- grep("pbu|unidade", names(dt), value = TRUE, ignore.case = TRUE)
    if ("pbu_code" %in% names(dt)) {
      dt[, pbu_f := as.factor(pbu_code)]
    } else if (length(pbu_col) > 0) {
      dt[, pbu_f := as.factor(dt[[pbu_col[1]]])]
    } else {
      dt[, pbu_f := as.factor("1")]
    }
  }

  # Ensure convite exists
  if (!"convite" %in% names(dt)) dt[, convite := 0L]

  # ---- Full-sample OLS ---------------------------------------------------
  d_price <- dt[!is.na(lneg_price)]
  cat(sprintf("  Price-valid observations: %s\n", pfmt_int(nrow(d_price))))

  if (nrow(d_price) < 1000) {
    flag_msg <- paste0(
      "FLAG: Insufficient price data for cross-fit.\n",
      "Price-valid rows: ", pfmt_int(nrow(d_price)), "\n",
      "Columns: ", paste(names(dt), collapse = ", "), "\n",
      "Timestamp: ", Sys.time(), "\n"
    )
    writeLines(flag_msg, file.path(FLAG_DIR, "FLAG_crossfit.txt"))
    cat("  FLAG written.\n")
    quit(save = "no", status = 0)
  }

  if (is.na(ols_coef)) {
    cat("  Running full-sample OLS...\n")
    m_full <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                    data = d_price, cluster = ~item_f, fixef.rm = "none")
    ols_coef <- coef(m_full)["losers"]
    ols_se   <- sqrt(vcov(m_full)["losers", "losers"])
    cat(sprintf("  Full-sample OLS: %.4f (SE=%.4f), N=%s\n",
                ols_coef, ols_se, pfmt_int(m_full$nobs)))
    rm(m_full); gc(verbose = FALSE)
  }

  # ---- 2-fold cross-validation ------------------------------------------
  cat("  Running 2-fold cross-validation...\n")
  set.seed(42)

  # Split by item groups for clean separation
  items <- unique(d_price$item_f)
  n_items <- length(items)
  fold_assign <- sample(rep(1:2, length.out = n_items))
  item_folds <- data.table(item_f = items, fold = fold_assign)
  d_price <- merge(d_price, item_folds, by = "item_f", all.x = TRUE)

  fold_coefs <- numeric(2)

  for (k in 1:2) {
    train_k <- d_price[fold != k]
    test_k  <- d_price[fold == k]

    cat(sprintf("  Fold %d: train=%s, test=%s\n",
                k, pfmt_int(nrow(train_k)), pfmt_int(nrow(test_k))))

    # Estimate on training fold
    m_k <- tryCatch(
      feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
            data = train_k, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) {
        cat(sprintf("    Fold %d failed: %s\n", k, e$message))
        NULL
      }
    )

    if (!is.null(m_k)) {
      fold_coefs[k] <- coef(m_k)["losers"]
      cat(sprintf("    Fold %d coefficient (trained on other half): %.4f\n",
                  k, fold_coefs[k]))
    } else {
      fold_coefs[k] <- NA
    }
    rm(m_k); gc(verbose = FALSE)
  }

  cf_fold1 <- fold_coefs[1]
  cf_fold2 <- fold_coefs[2]
  crossfit_avg <- mean(fold_coefs, na.rm = TRUE)
  source_used <- "fresh_2fold_crossvalidation"

  cat(sprintf("  Cross-fit: fold1=%.4f, fold2=%.4f, avg=%.4f\n",
              cf_fold1, cf_fold2, crossfit_avg))

  rm(dt, d_price); gc(verbose = FALSE)
}

# ---- Compute attenuation ---------------------------------------------------
if (!is.na(crossfit_avg) && !is.na(ols_coef) && ols_coef != 0) {
  attenuation <- crossfit_avg / ols_coef
  cat(sprintf("\n  === RESULTS ===\n"))
  cat(sprintf("  Full-sample OLS: %.4f", ols_coef))
  if (!is.na(ols_se)) cat(sprintf(" (SE=%.4f)", ols_se))
  cat("\n")
  cat(sprintf("  Cross-fit average: %.4f\n", crossfit_avg))
  cat(sprintf("  Attenuation ratio: %.3f (cross-fit / OLS)\n", attenuation))
  if (!is.na(cf_fold1)) cat(sprintf("  Fold 1: %.4f, Fold 2: %.4f\n", cf_fold1, cf_fold2))
}

# ---- Write results CSV -----------------------------------------------------
results_df <- data.frame(
  metric = c("ols_coef", "ols_se", "crossfit_avg",
             "crossfit_fold1", "crossfit_fold2",
             "attenuation_ratio", "source"),
  value = c(
    pfmt(ols_coef, 4),
    if (!is.na(ols_se)) pfmt(ols_se, 4) else "N/A",
    if (!is.na(crossfit_avg)) pfmt(crossfit_avg, 4) else "N/A",
    if (!is.na(cf_fold1)) pfmt(cf_fold1, 4) else "N/A",
    if (!is.na(cf_fold2)) pfmt(cf_fold2, 4) else "N/A",
    if (!is.na(attenuation)) pfmt(attenuation, 3) else "N/A",
    source_used
  )
)

csv_path <- file.path(OUT_TAB, "crossfit_results.csv")
write.csv(results_df, csv_path, row.names = FALSE)
cat("  Results written to:", csv_path, "\n")

cat("  Done.\n")
