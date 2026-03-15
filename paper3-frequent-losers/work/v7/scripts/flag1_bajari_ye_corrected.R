# ============================================================================
# flag1_bajari_ye_corrected.R — Bajari-Ye corrected first stage (v6)
# Paper 3 v6: Frequent Losers in Public Procurement
# ============================================================================
# Purpose: Re-run Bajari-Ye first stage WITHOUT n_bids, enriched with firm
#          age and CNAE sector from Firms_final.parquet.
# Outputs:
#   - work/v6/tables/bajari_ye_corrected_results.csv
#   - work/v6/tables/tab_bajari_ye_corrected.tex
#   - work/v6/FLAG_bajari_ye.txt (if data/cache missing)
# ============================================================================

cat("=== flag1_bajari_ye_corrected.R: Bajari-Ye corrected first stage ===\n")

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

# ---- Formatting helpers -----------------------------------------------------
pfmt     <- function(x, d = 4) formatC(x, format = "f", digits = d, big.mark = ",")
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")
pstars <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
}

# ---- Check v4 cache --------------------------------------------------------
BAJARI_CACHE <- "/tmp/p3v4_bajari_ye.rds"
has_cache <- file.exists(BAJARI_CACHE)
if (has_cache) {
  cat("  Found v4 Bajari-Ye cache:", BAJARI_CACHE, "\n")
  bj_old <- readRDS(BAJARI_CACHE)
  cat("  v4 results:\n")
  cat(sprintf("    Feasible: %s\n", bj_old$feasible))
  if (bj_old$feasible) {
    cat(sprintf("    First stage R2: %.4f, N: %s\n",
                bj_old$first_stage$r2, pfmt_int(bj_old$first_stage$n)))
    cat(sprintf("    KS stat: %.4f, KS p: %.6f\n",
                bj_old$exchangeability$ks_stat, bj_old$exchangeability$ks_p))
    cat(sprintf("    FL mean product: %.4f, p: %.6f\n",
                bj_old$independence$mean_product, bj_old$independence$p_value))
    cat(sprintf("    n_bids included: NO (corrected in v4/06_bajari_ye_test.R)\n"))
  }
} else {
  cat("  v4 cache not found at:", BAJARI_CACHE, "\n")
}

# ---- Check bid-level data ---------------------------------------------------
# bid_level_full.parquet has NO price data; use v3 bid_level_analysis.parquet instead
BID_CACHE <- "/tmp/p3_bid_level.rds"
BID_PARQUET_V3 <- file.path(BASE_DIR, "v3", "data", "processed", "bid_level_analysis.parquet")
BID_PARQUET <- file.path(DATA_DIR, "bid_level_full.parquet")
FP_PARQUET  <- file.path(DATA_DIR, "FREQ_PARTICIP_rebuilt.parquet")
FIRMS_PARQUET <- file.path(DATA_DIR, "Firms_final.parquet")

has_bid_cache   <- file.exists(BID_CACHE)
has_bid_parquet <- file.exists(BID_PARQUET)
has_fp          <- file.exists(FP_PARQUET)
has_firms       <- file.exists(FIRMS_PARQUET)

cat(sprintf("  Bid-level RDS cache: %s\n", has_bid_cache))
cat(sprintf("  Bid-level parquet: %s\n", has_bid_parquet))
cat(sprintf("  FREQ_PARTICIP parquet: %s\n", has_fp))
cat(sprintf("  Firms parquet: %s\n", has_firms))

# ---- Decide data source and load -------------------------------------------
bl <- NULL

if (has_bid_cache) {
  cat("  Loading bid-level from RDS cache...\n")
  bl <- readRDS(BID_CACHE)
  if (!is.data.table(bl)) bl <- as.data.table(bl)

  # Standardize column names from RDS cache (may use Portuguese originals)
  if ("códigofornecedor" %in% names(bl) && !"firm_id" %in% names(bl)) {
    setnames(bl, "códigofornecedor", "firm_id")
  } else {
    bl_col <- grep("fornecedor", names(bl), value = TRUE, ignore.case = TRUE)
    if (length(bl_col) == 1 && bl_col != "firm_id") setnames(bl, bl_col, "firm_id")
  }
  setnames(bl, "numerodaoc", "oc_code", skip_absent = TRUE)
  setnames(bl, "códigoitem", "item_code", skip_absent = TRUE)

  # Won flag
  if ("flagvencedor" %in% names(bl) && !"won" %in% names(bl)) {
    setnames(bl, "flagvencedor", "won")
  } else {
    won_col <- grep("vencedor|won|winner", names(bl), value = TRUE, ignore.case = TRUE)
    if (length(won_col) > 0 && !"won" %in% names(bl)) setnames(bl, won_col[1], "won")
  }

  # Bid price
  if (!"bid_price" %in% names(bl)) {
    price_col <- grep("valor|preco|price|lance", names(bl), value = TRUE, ignore.case = TRUE)
    if (length(price_col) > 0) setnames(bl, price_col[1], "bid_price")
  }

  cat(sprintf("  Loaded %s rows, %d cols from RDS cache\n", pfmt_int(nrow(bl)), ncol(bl)))
  cat(sprintf("  Columns: %s\n", paste(names(bl), collapse = ", ")))

  # Check if bid_price exists; if not, this cache has no prices — fall back to v3
  if (!"bid_price" %in% names(bl)) {
    cat("  WARNING: RDS cache has no bid_price column. Trying v3 data...\n")
    bl <- NULL
  }
}

if (is.null(bl) && file.exists(BID_PARQUET_V3)) {
  cat("  Loading v3/bid_level_analysis.parquet (40M rows with prices)...\n")
  bl <- as.data.table(read_parquet(BID_PARQUET_V3))
  # v3 data already has: firm_id, oc_code, item_code, won, bid_price, is_fl
  cat(sprintf("  Loaded %s rows, %d cols from v3\n", pfmt_int(nrow(bl)), ncol(bl)))
  cat(sprintf("  Columns: %s\n", paste(names(bl), collapse = ", ")))
} else if (is.null(bl) && has_bid_parquet) {
  cat("  Loading bid_level_full.parquet (40M rows, may take a moment)...\n")
  bl <- as.data.table(read_parquet(BID_PARQUET))

  # Standardize column names
  bl_col <- grep("fornecedor", names(bl), value = TRUE, ignore.case = TRUE)
  if (length(bl_col) == 1 && bl_col != "firm_id") setnames(bl, bl_col, "firm_id")
  setnames(bl, "numerodaoc", "oc_code", skip_absent = TRUE)
  setnames(bl, "códigoitem", "item_code", skip_absent = TRUE)

  # Find price column
  price_col <- grep("valor|preco|price|lance", names(bl), value = TRUE, ignore.case = TRUE)
  if (length(price_col) > 0 && !"bid_price" %in% names(bl)) {
    setnames(bl, price_col[1], "bid_price")
  }

  # Find won column
  won_col <- grep("vencedor|won|winner", names(bl), value = TRUE, ignore.case = TRUE)
  if (length(won_col) > 0 && !"won" %in% names(bl)) {
    setnames(bl, won_col[1], "won")
  }

  cat(sprintf("  Loaded %s rows, %d cols\n", pfmt_int(nrow(bl)), ncol(bl)))
  cat(sprintf("  Columns: %s\n", paste(names(bl), collapse = ", ")))
}

if (is.null(bl) || !has_fp) {
  # Write flag file
  missing_items <- character()
  if (is.null(bl)) missing_items <- c(missing_items, "bid_level data (neither RDS cache nor parquet)")
  if (!has_fp) missing_items <- c(missing_items, "FREQ_PARTICIP_rebuilt.parquet")
  if (!has_firms) missing_items <- c(missing_items, "Firms_final.parquet")

  flag_msg <- paste0(
    "FLAG: Bajari-Ye corrected first stage cannot run.\n",
    "Missing data:\n",
    paste("  -", missing_items, collapse = "\n"), "\n\n",
    "v4 cache available: ", has_cache, "\n",
    if (has_cache && bj_old$feasible) paste0(
      "v4 cached results:\n",
      "  KS stat: ", pfmt(bj_old$exchangeability$ks_stat, 4), "\n",
      "  KS p-value: ", pfmt(bj_old$exchangeability$ks_p, 6), "\n",
      "  FL mean pairwise product: ", pfmt(bj_old$independence$mean_product, 4), "\n",
      "  FL pairwise p-value: ", pfmt(bj_old$independence$p_value, 6), "\n",
      "  First stage R2: ", pfmt(bj_old$first_stage$r2, 4), "\n",
      "  n_bids included: NO\n"
    ) else "No usable v4 cache.\n",
    "\nTimestamp: ", Sys.time(), "\n"
  )

  flag_path <- file.path(FLAG_DIR, "FLAG_bajari_ye.txt")
  writeLines(flag_msg, flag_path)
  cat("  FLAG written to:", flag_path, "\n")

  # If we have cache, still write results CSV from it
  if (has_cache && bj_old$feasible) {
    results_df <- data.frame(
      metric = c("first_stage_r2", "first_stage_n", "ks_stat", "ks_p",
                  "fl_mean_product", "fl_product_p", "n_bids_included",
                  "source"),
      value = c(pfmt(bj_old$first_stage$r2, 4),
                pfmt_int(bj_old$first_stage$n),
                pfmt(bj_old$exchangeability$ks_stat, 4),
                pfmt(bj_old$exchangeability$ks_p, 6),
                pfmt(bj_old$independence$mean_product, 4),
                pfmt(bj_old$independence$p_value, 6),
                "NO",
                "v4_cache")
    )
    csv_path <- file.path(OUT_TAB, "bajari_ye_corrected_results.csv")
    write.csv(results_df, csv_path, row.names = FALSE)
    cat("  Results CSV (from cache) written to:", csv_path, "\n")
  }

  cat("  Done (with flag).\n")
  quit(save = "no", status = 0)
}

# ---- Flag FL firms ----------------------------------------------------------
cat("  Loading FREQ_PARTICIP to identify FL firms...\n")
fp <- as.data.table(read_parquet(FP_PARQUET))
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val  # median + 1.5*IQR (NOT Tukey Q3 + 1.5*IQR)
fl_ids <- unique(fp[tenders_count > threshold, firm_id])
cat(sprintf("  FL threshold: %.0f, FL firms: %d\n", threshold, length(fl_ids)))

bl[, is_fl := as.integer(firm_id %chin% fl_ids)]
cat(sprintf("  FL bids: %s / %s total\n",
            pfmt_int(sum(bl$is_fl == 1L)), pfmt_int(nrow(bl))))

# ---- Load firm characteristics (age, CNAE) ----------------------------------
cat("  Loading firm characteristics...\n")
firms <- NULL
firm_age_available <- FALSE
firm_cnae_available <- FALSE

if (has_firms) {
  firms <- as.data.table(read_parquet(FIRMS_PARQUET))
  if ("códigofornecedor" %in% names(firms)) {
    setnames(firms, "códigofornecedor", "firm_id")
  } else {
    firms_col <- grep("^codigo.*fornecedor$|^firm_id$", names(firms), value = TRUE, ignore.case = TRUE)
    if (length(firms_col) >= 1) setnames(firms, firms_col[1], "firm_id")
  }

  cat(sprintf("  Firms columns: %s\n", paste(names(firms), collapse = ", ")))

  # Firm size (porte)
  if ("porte_empresa" %in% names(firms)) {
    firms[, firm_size := as.numeric(factor(porte_empresa))]
  } else {
    size_col <- grep("porte|size", names(firms), value = TRUE, ignore.case = TRUE)
    if (length(size_col) > 0) {
      firms[, firm_size := as.numeric(factor(firms[[size_col[1]]]))]
    } else {
      firms[, firm_size := 0]
    }
  }

  # CNAE sector (2-digit)
  cnae_col <- grep("cnae_fiscal|cnae$", names(firms), value = TRUE, ignore.case = TRUE)
  if (length(cnae_col) > 0) {
    firms[, cnae_raw := as.character(firms[[cnae_col[1]]])]
    firms[, cnae_2d := substr(cnae_raw, 1, 2)]
    firms[cnae_2d == "" | is.na(cnae_2d), cnae_2d := "00"]
    firms[, cnae_sector := as.numeric(factor(cnae_2d))]
    firm_cnae_available <- TRUE
    cat(sprintf("  CNAE sectors: %d unique\n", uniqueN(firms$cnae_2d)))
  }

  # Firm age proxy: use data_abertura if available
  age_col <- grep("abertura|fundacao|age|data.*constituicao|data_inicio_atividade", names(firms), value = TRUE, ignore.case = TRUE)
  if (length(age_col) > 0) {
    firms[, firm_age_raw := as.character(firms[[age_col[1]]])]
    firms[, firm_age := tryCatch({
      as.numeric(difftime(as.Date("2014-01-01"), as.Date(firm_age_raw), units = "days")) / 365.25
    }, error = function(e) NA_real_)]
    firms[is.na(firm_age) | firm_age < 0, firm_age := NA_real_]
    firm_age_available <- sum(!is.na(firms$firm_age)) > 100
    if (firm_age_available) {
      cat(sprintf("  Firm age: %d valid, median %.1f years\n",
                  sum(!is.na(firms$firm_age)), median(firms$firm_age, na.rm = TRUE)))
    }
  }

  # Merge into bl
  merge_cols <- c("firm_id", "firm_size")
  if (firm_cnae_available) merge_cols <- c(merge_cols, "cnae_sector")
  if (firm_age_available)  merge_cols <- c(merge_cols, "firm_age")

  bl <- merge(bl, firms[, ..merge_cols], by = "firm_id", all.x = TRUE)
  bl[is.na(firm_size), firm_size := 0]
  if (firm_cnae_available) bl[is.na(cnae_sector), cnae_sector := 0]
  if (firm_age_available)  bl[is.na(firm_age), firm_age := 0]
}

# ---- Extract year -----------------------------------------------------------
if (!"year" %in% names(bl)) {
  if ("month_year" %in% names(bl)) {
    bl[, year := as.integer(sub(".*/", "", as.character(month_year)))]
  } else if ("oc_code" %in% names(bl)) {
    bl[, year := as.integer(substr(oc_code, 12, 15))]
  } else {
    bl[, year := 2014L]  # fallback
  }
}

# ---- First stage: bid residuals (NO n_bids) ---------------------------------
cat("  First stage: bid residuals from losing bids (no n_bids)...\n")

d_resid <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
d_resid[, log_bid := log(bid_price)]
cat(sprintf("  Losing bids with prices: %s\n", pfmt_int(nrow(d_resid))))

if (nrow(d_resid) < 1000) {
  flag_msg <- paste0(
    "FLAG: Insufficient losing bids with prices.\n",
    "Found: ", pfmt_int(nrow(d_resid)), " (need >= 1000)\n",
    "Columns in bid-level data: ", paste(names(bl), collapse = ", "), "\n",
    "won column values: ", paste(sort(unique(bl$won)), collapse = ", "), "\n",
    "bid_price non-NA: ", pfmt_int(sum(!is.na(bl$bid_price))), "\n",
    "Timestamp: ", Sys.time(), "\n"
  )
  writeLines(flag_msg, file.path(FLAG_DIR, "FLAG_bajari_ye.txt"))
  cat("  FLAG written. Insufficient data.\n")
  quit(save = "no", status = 0)
}

# Reference price if available
if ("ref_price" %in% names(d_resid)) {
  d_resid[, log_ref := fifelse(!is.na(ref_price) & ref_price > 0,
                                log(ref_price), NA_real_)]
} else {
  d_resid[, log_ref := NA_real_]
}
has_ref <- sum(!is.na(d_resid$log_ref)) > nrow(d_resid) * 0.3

# Build formula: NO n_bids, YES firm_size, optionally firm_age + cnae_sector
covars <- "firm_size"
if (firm_age_available)  covars <- paste(covars, "+ firm_age")
if (firm_cnae_available) covars <- paste(covars, "+ cnae_sector")
if (has_ref) covars <- paste("log_ref +", covars)

fs_formula <- as.formula(paste("log_bid ~", covars, "| item_code + year"))
cat(sprintf("  First stage formula: %s\n", deparse(fs_formula)))

d_fs <- if (has_ref) d_resid[!is.na(log_ref)] else d_resid

m_fs <- tryCatch(
  feols(fs_formula, data = d_fs, fixef.rm = "none", lean = FALSE),
  error = function(e) {
    cat(sprintf("  First stage failed: %s\n", e$message))
    NULL
  }
)

if (is.null(m_fs)) {
  flag_msg <- paste0(
    "FLAG: First stage regression failed.\n",
    "Formula: ", deparse(fs_formula), "\n",
    "Data rows: ", pfmt_int(nrow(d_fs)), "\n",
    "Timestamp: ", Sys.time(), "\n"
  )
  writeLines(flag_msg, file.path(FLAG_DIR, "FLAG_bajari_ye.txt"))
  cat("  FLAG written.\n")
  quit(save = "no", status = 0)
}

d_fs[, resid := residuals(m_fs)]
fs_r2 <- fitstat(m_fs, "r2")[[1]]
cat(sprintf("  First stage R2: %.4f, N: %s\n", fs_r2, pfmt_int(m_fs$nobs)))
cat(sprintf("  Covariates: %s\n", covars))
cat(sprintf("  n_bids included: NO\n"))

# ---- Test A: Exchangeability (KS test) --------------------------------------
cat("  Test A: Exchangeability (KS test)...\n")

resid_fl    <- d_fs[is_fl == 1L, resid]
resid_nonfl <- d_fs[is_fl == 0L, resid]

ks_stat <- NA; ks_p <- NA; ks_result <- "N/A"
if (length(resid_fl) >= 30 && length(resid_nonfl) >= 30) {
  ks_test <- ks.test(resid_fl, resid_nonfl)
  ks_stat <- ks_test$statistic
  ks_p    <- ks_test$p.value
  ks_result <- if (ks_p < 0.05) "REJECT" else "FAIL TO REJECT"
  cat(sprintf("  KS: D=%.4f, p=%.6f -> %s\n", ks_stat, ks_p, ks_result))
} else {
  cat(sprintf("  Insufficient FL residuals: FL=%d, non-FL=%d\n",
              length(resid_fl), length(resid_nonfl)))
}

# ---- Test B: Conditional Independence (pairwise products) -------------------
cat("  Test B: Conditional Independence...\n")

fl_resid_dt <- d_fs[is_fl == 1L, .(firm_id, oc_code, item_code, resid)]
fl_tender_counts <- fl_resid_dt[, .N, by = .(oc_code, item_code)]
tenders_2plus <- fl_tender_counts[N >= 2]

mean_prod <- NA; se_prod <- NA; p_val_prod <- NA
if (nrow(tenders_2plus) >= 50) {
  if (nrow(tenders_2plus) > 5000) {
    set.seed(42)
    sample_t <- tenders_2plus[sample(.N, 5000)]
  } else sample_t <- tenders_2plus

  fl_resid_wide <- fl_resid_dt[sample_t, on = .(oc_code, item_code)]
  fl_cors <- fl_resid_wide[, {
    if (.N >= 2) {
      pairs <- combn(min(.N, 10), 2)
      cors <- sapply(seq_len(ncol(pairs)), function(p) {
        resid[pairs[1, p]] * resid[pairs[2, p]]
      })
      .(pair_product = cors)
    }
  }, by = .(oc_code, item_code)]

  if (nrow(fl_cors) > 0) {
    mean_prod  <- mean(fl_cors$pair_product, na.rm = TRUE)
    se_prod    <- sd(fl_cors$pair_product, na.rm = TRUE) / sqrt(nrow(fl_cors))
    t_stat     <- mean_prod / se_prod
    p_val_prod <- 2 * pnorm(-abs(t_stat))
    cat(sprintf("  FL: mean_product=%.4f (SE=%.4f), t=%.1f, p=%.6f\n",
                mean_prod, se_prod, t_stat, p_val_prod))
  }
} else {
  cat(sprintf("  Insufficient tenders with 2+ FL bids: %d\n", nrow(tenders_2plus)))
}

# ---- Write results CSV ------------------------------------------------------
cat("  Writing results CSV...\n")

results_df <- data.frame(
  metric = c("first_stage_r2", "first_stage_n", "first_stage_covariates",
             "ks_stat", "ks_p", "ks_result",
             "fl_mean_product", "fl_product_se", "fl_product_p",
             "n_bids_included", "firm_age_included", "cnae_sector_included",
             "fl_threshold", "n_fl_firms", "n_fl_losing_bids",
             "source"),
  value = c(pfmt(fs_r2, 4),
            pfmt_int(m_fs$nobs),
            covars,
            pfmt(ks_stat, 4),
            pfmt(ks_p, 6),
            ks_result,
            pfmt(mean_prod, 4),
            pfmt(se_prod, 4),
            pfmt(p_val_prod, 6),
            "NO",
            as.character(firm_age_available),
            as.character(firm_cnae_available),
            pfmt(threshold, 0),
            as.character(length(fl_ids)),
            pfmt_int(sum(d_fs$is_fl == 1L)),
            "bid_level_full.parquet (fresh run)")
)

csv_path <- file.path(OUT_TAB, "bajari_ye_corrected_results.csv")
write.csv(results_df, csv_path, row.names = FALSE)
cat("  CSV written to:", csv_path, "\n")

# ---- Write LaTeX table ------------------------------------------------------
cat("  Writing LaTeX table...\n")

tex_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Bajari-Ye Tests: Corrected First Stage (No \\textit{n\\_bids})}",
  "\\label{tab:bajari_ye_corrected}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Statistic & \\textit{p}-value \\\\",
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Panel A: First-Stage Auxiliary Regression}} \\\\[3pt]"
)

# First-stage details
tex_lines <- c(tex_lines,
  sprintf("R-squared & \\multicolumn{2}{c}{%s} \\\\", pfmt(fs_r2, 4)),
  sprintf("Observations & \\multicolumn{2}{c}{%s} \\\\", pfmt_int(m_fs$nobs)),
  "Covariates: firm size (porte) & \\multicolumn{2}{c}{YES} \\\\")

if (firm_age_available) {
  tex_lines <- c(tex_lines, "Covariates: firm age & \\multicolumn{2}{c}{YES} \\\\")
} else {
  tex_lines <- c(tex_lines, "Covariates: firm age & \\multicolumn{2}{c}{NO (unavailable)} \\\\")
}
if (firm_cnae_available) {
  tex_lines <- c(tex_lines, "Covariates: CNAE sector & \\multicolumn{2}{c}{YES} \\\\")
} else {
  tex_lines <- c(tex_lines, "Covariates: CNAE sector & \\multicolumn{2}{c}{NO (unavailable)} \\\\")
}
tex_lines <- c(tex_lines, "Covariates: \\textit{n\\_bids} & \\multicolumn{2}{c}{NO (excluded)} \\\\")

tex_lines <- c(tex_lines,
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Panel B: Exchangeability (KS Test)}} \\\\[3pt]",
  sprintf("KS statistic & %s & %s \\\\",
          if (!is.na(ks_stat)) pfmt(ks_stat, 4) else "---",
          if (!is.na(ks_p)) pfmt(ks_p, 6) else "---"),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Panel C: Conditional Independence}} \\\\[3pt]",
  sprintf("FL mean pairwise product & %s & %s \\\\",
          if (!is.na(mean_prod)) pfmt(mean_prod, 4) else "---",
          if (!is.na(p_val_prod)) pfmt(p_val_prod, 6) else "---"),
  if (!is.na(se_prod)) sprintf("\\quad (SE) & (%s) & \\\\", pfmt(se_prod, 4)) else "",
  sprintf("FL tenders with $\\geq$2 bidders & \\multicolumn{2}{c}{%s} \\\\",
          pfmt_int(nrow(tenders_2plus)))
)

tex_lines <- c(tex_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} First-stage residuals from auxiliary regression of",
  "$\\log(\\text{bid})$ on firm covariates with item and year fixed effects,",
  "estimated on losing bids only. \\textit{n\\_bids} is deliberately excluded",
  "as it is endogenous to collusion. Panel B tests whether FL and non-FL bid",
  "residual distributions are exchangeable. Panel C reports the mean pairwise",
  "product of residuals among FL firms within the same tender; a positive value",
  "indicates bid coordination (rejection of conditional independence).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

# Remove empty strings
tex_lines <- tex_lines[tex_lines != ""]

tex_path <- file.path(OUT_TAB, "tab_bajari_ye_corrected.tex")
writeLines(tex_lines, tex_path)
cat("  LaTeX table written to:", tex_path, "\n")

# ---- Cleanup ----------------------------------------------------------------
rm(bl, d_resid, d_fs); gc(verbose = FALSE)
cat("  Done.\n")
