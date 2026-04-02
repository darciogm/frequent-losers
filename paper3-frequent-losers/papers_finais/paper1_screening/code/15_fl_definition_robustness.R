# ============================================================================
# 15_fl_definition_robustness.R — FL definition robustness tests (NEW for v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# (a) Low-win-rate FL variants (win_rate < 1%, < 2%) [R2.8]
# (b) Sample splitting / cross-fitting (odd/even years) [R2.9]
# (c) Temporal FL definition (3-year rolling windows) [R2.3]
# ============================================================================

cat("=== 15_fl_definition_robustness.R: FL definition robustness ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

# Load firm_loss_stats and FTM
fls_file <- file.path(DATA_V1, "firm_loss_stats.parquet")
ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")

if (!file.exists(fls_file) || !file.exists(ftm_file)) {
  cat("  Required data files missing. Skipping FL robustness.\n")
  saveRDS(list(feasible = FALSE), FL_ROBUST_CACHE_V4)
  quit(save = "no", status = 0)
}

fls <- as.data.table(read_parquet(fls_file))
fls_col <- grep("fornecedor", names(fls), value = TRUE, ignore.case = TRUE)
if (length(fls_col) == 1) setnames(fls, fls_col, "firm_id")

ftm <- as.data.table(read_parquet(ftm_file))
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

win_rate_col <- grep("win_rate|taxa", names(fls), value = TRUE, ignore.case = TRUE)[1]

# Compute tenders_count from FTM (unique tender-items per firm) to match
# the main FL definition in 01_data_prep.R. Do NOT use total_participations
# from firm_loss_stats.parquet, which counts bid-level rows (~3x larger).
ftm_tc <- ftm[, .(tenders_count_ftm = .N), by = firm_id]
fls <- merge(fls, ftm_tc, by = "firm_id", all.x = TRUE)
fls[is.na(tenders_count_ftm), tenders_count_ftm := 0L]
tc_col <- "tenders_count_ftm"

fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
baseline_threshold <- q[2] + 1.5 * iqr_val

fl_robust <- list()

# ============================================================================
# (a) Low-win-rate FL variants [R2.8]
# ============================================================================

cat("  (a) Low-win-rate FL variants...\n")

lowwin_results <- list()

for (max_wr in c(0, 0.01, 0.02)) {
  label <- if (max_wr == 0) "win_rate = 0 (baseline)" else sprintf("win_rate < %.0f%%", max_wr * 100)

  # Select firms with win_rate <= max_wr
  subset_firms <- fls[get(win_rate_col) <= max_wr]

  # Apply same IQR threshold on tenders_count
  q_sub <- quantile(subset_firms[[tc_col]], c(0.25, 0.50, 0.75), na.rm = TRUE)
  iqr_sub <- q_sub[3] - q_sub[1]
  thr_sub <- q_sub[2] + 1.5 * iqr_sub

  fl_ids_sub <- subset_firms[get(tc_col) > thr_sub, firm_id]
  n_fl_sub <- length(fl_ids_sub)

  cat(sprintf("    %s: threshold=%.0f, %d FL firms\n", label, thr_sub, n_fl_sub))

  if (n_fl_sub >= 100) {
    # Reclassify tenders
    ftm_sub <- ftm[firm_id %chin% fl_ids_sub]
    new_losers <- ftm_sub[, .(losers_count_new = .N), by = .(oc_code, item_code)]

    dt_sub <- copy(dt)
    dt_sub[, losers_count_new := NULL]
    dt_sub <- merge(dt_sub, new_losers, by = c("oc_code", "item_code"), all.x = TRUE)
    dt_sub[is.na(losers_count_new), losers_count_new := 0L]
    dt_sub[, losers := as.integer(losers_count_new > 0L)]

    m <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
               data = dt_sub[!is.na(lneg_price)], cluster = ~item_f, fixef.rm = "none")

    lowwin_results[[as.character(max_wr)]] <- list(
      max_win_rate = max_wr, threshold = thr_sub, n_fl = n_fl_sub,
      coef = coef(m)["losers"], se = sqrt(vcov(m)["losers", "losers"]),
      n = m$nobs
    )
  }
}

fl_robust[["lowwinrate"]] <- lowwin_results

# Write table
if (length(lowwin_results) > 0) {
  cat("  Writing tab_fl_lowwinrate.tex...\n")

  lw_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{FL Definition: Low-Win-Rate Variants}",
    "\\label{tab:fl_lowwinrate}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcccc}", "\\toprule",
    "Max Win Rate & FL Firms & Threshold & Coefficient & N \\\\", "\\midrule"
  )

  for (r in lowwin_results) {
    p <- 2 * pnorm(-abs(r$coef / r$se))
    lbl <- if (r$max_win_rate == 0) "0\\% (baseline)" else sprintf("$<$ %.0f\\%%", r$max_win_rate * 100)
    lw_lines <- c(lw_lines, sprintf(
      "%s & %s & %.0f & %s%s (%s) & %s \\\\",
      lbl, pfmt_int(r$n_fl), r$threshold, pfmt(r$coef, 4), pstars(p), pfmt(r$se, 4), pfmt_int(r$n)))
  }

  lw_lines <- c(lw_lines, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Each row redefines FL using a different max win rate.",
    "IQR threshold (median + 1.5$\\times$IQR) recomputed for each definition.",
    "DV: log price. Item, year, PBU FE. SE clustered at item level.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(lw_lines, file.path(OUT_TAB, "tab_fl_lowwinrate.tex"))
}

# ============================================================================
# (b) Cross-fitting: define FL in odd years, estimate in even years [R2.9]
# ============================================================================

cat("  (b) Cross-fitting (odd/even years)...\n")

ftm[, year := as.integer(substr(oc_code, 12, 15))]

crossfit_results <- list()

for (fold in c("odd_train", "even_train")) {
  if (fold == "odd_train") {
    train_years <- seq(2009, 2019, by = 2)
    test_years  <- seq(2010, 2018, by = 2)
  } else {
    train_years <- seq(2010, 2018, by = 2)
    test_years  <- seq(2009, 2019, by = 2)
  }

  # Compute FL status in training half
  ftm_train <- ftm[year %in% train_years]
  firm_wins_train <- ftm_train[, .(
    n_participations = .N,
    n_wins = sum(won, na.rm = TRUE)
  ), by = firm_id]
  firm_wins_train[, win_rate := n_wins / n_participations]

  always_losers_train <- firm_wins_train[win_rate == 0]
  q_train <- quantile(always_losers_train$n_participations, c(0.25, 0.50, 0.75))
  iqr_train <- q_train[3] - q_train[1]
  thr_train <- q_train[2] + 1.5 * iqr_train

  fl_ids_train <- always_losers_train[n_participations > thr_train, firm_id]
  cat(sprintf("    %s: %d FL firms (threshold=%.0f)\n",
              fold, length(fl_ids_train), thr_train))

  # Create treatment indicators in test sample
  ftm_test <- ftm[year %in% test_years & firm_id %chin% fl_ids_train]
  test_losers <- ftm_test[, .(losers_count_new = .N), by = .(oc_code, item_code)]

  dt_test <- dt[year %in% test_years]
  dt_test[, losers_count_new := NULL]
  dt_test <- merge(dt_test, test_losers, by = c("oc_code", "item_code"), all.x = TRUE)
  dt_test[is.na(losers_count_new), losers_count_new := 0L]
  dt_test[, losers := as.integer(losers_count_new > 0L)]

  if (nrow(dt_test[!is.na(lneg_price) & sum(losers) > 10]) > 100) {
    m_cf <- tryCatch(
      feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
            data = dt_test[!is.na(lneg_price)], cluster = ~item_f, fixef.rm = "none"),
      error = function(e) NULL
    )

    if (!is.null(m_cf)) {
      crossfit_results[[fold]] <- list(
        fold = fold, n_fl = length(fl_ids_train), threshold = thr_train,
        coef = coef(m_cf)["losers"], se = sqrt(vcov(m_cf)["losers", "losers"]),
        n = m_cf$nobs
      )
      cat(sprintf("    Coefficient: %.4f (%.4f)\n",
                  crossfit_results[[fold]]$coef, crossfit_results[[fold]]$se))
    }
  }
}

# Average across folds
if (length(crossfit_results) == 2) {
  avg_coef <- mean(sapply(crossfit_results, `[[`, "coef"))
  cat(sprintf("  Cross-fit average coefficient: %.4f\n", avg_coef))
}

fl_robust[["crossfit"]] <- crossfit_results

# Write table
if (length(crossfit_results) > 0) {
  cf_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{FL Definition: Cross-Fitting (Odd/Even Year Split)}",
    "\\label{tab:fl_crossfit}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcccc}", "\\toprule",
    "Fold & Training Years & FL Firms & Coefficient & N \\\\", "\\midrule"
  )

  for (r in crossfit_results) {
    p <- 2 * pnorm(-abs(r$coef / r$se))
    train_lbl <- if (r$fold == "odd_train") "Odd (2009,...)" else "Even (2010,...)"
    cf_lines <- c(cf_lines, sprintf(
      "%s & %s & %s & %s%s (%s) & %s \\\\",
      r$fold, train_lbl, pfmt_int(r$n_fl),
      pfmt(r$coef, 4), pstars(p), pfmt(r$se, 4), pfmt_int(r$n)))
  }

  if (length(crossfit_results) == 2) {
    cf_lines <- c(cf_lines, "\\midrule",
      sprintf("Average & & & %s & \\\\", pfmt(avg_coef, 4)))
  }

  cf_lines <- c(cf_lines, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} FL defined in training years, regressions on test years.",
    "This breaks the mechanical link between FL classification and outcome.",
    "DV: log price. Item, year, PBU FE. SE clustered at item level.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(cf_lines, file.path(OUT_TAB, "tab_fl_crossfit.tex"))
}

# ============================================================================
# (c) Temporal FL: 3-year rolling windows [R2.3]
# ============================================================================

cat("  (c) Temporal FL (3-year windows)...\n")

temporal_results <- list()

for (t_end in 2011:2019) {
  window_years <- (t_end - 2):t_end

  ftm_window <- ftm[year %in% window_years]
  firm_wins_w <- ftm_window[, .(
    n_participations = .N,
    n_wins = sum(won, na.rm = TRUE)
  ), by = firm_id]
  firm_wins_w[, win_rate := n_wins / n_participations]

  always_losers_w <- firm_wins_w[win_rate == 0]
  if (nrow(always_losers_w) < 100) next

  q_w <- quantile(always_losers_w$n_participations, c(0.25, 0.50, 0.75))
  iqr_w <- q_w[3] - q_w[1]
  thr_w <- q_w[2] + 1.5 * iqr_w

  fl_ids_w <- always_losers_w[n_participations > thr_w, firm_id]

  if (length(fl_ids_w) < 50) {
    # Try 5-year window as fallback
    window_years <- (t_end - 4):t_end
    ftm_window <- ftm[year %in% window_years]
    firm_wins_w <- ftm_window[, .(n_participations = .N, n_wins = sum(won, na.rm = TRUE)), by = firm_id]
    firm_wins_w[, win_rate := n_wins / n_participations]
    always_losers_w <- firm_wins_w[win_rate == 0]
    if (nrow(always_losers_w) < 100) next
    q_w <- quantile(always_losers_w$n_participations, c(0.25, 0.50, 0.75))
    iqr_w <- q_w[3] - q_w[1]
    thr_w <- q_w[2] + 1.5 * iqr_w
    fl_ids_w <- always_losers_w[n_participations > thr_w, firm_id]
  }

  if (length(fl_ids_w) >= 50) {
    # Create treatment indicators for year t_end
    ftm_fl_w <- ftm[firm_id %chin% fl_ids_w & year == t_end]
    new_losers_w <- ftm_fl_w[, .(losers_count_new = .N), by = .(oc_code, item_code)]

    dt_year <- dt[year == t_end]
    dt_year[, losers_count_new := NULL]
    dt_year <- merge(dt_year, new_losers_w, by = c("oc_code", "item_code"), all.x = TRUE)
    dt_year[is.na(losers_count_new), losers_count_new := 0L]
    dt_year[, losers := as.integer(losers_count_new > 0L)]

    temporal_results[[as.character(t_end)]] <- list(
      year = t_end, n_fl = length(fl_ids_w), threshold = thr_w,
      n_treated = sum(dt_year$losers)
    )
  }
}

# Pool temporal results and run regression
if (length(temporal_results) >= 3) {
  cat("  Pooling temporal FL across years...\n")

  # Create temporal FL indicators for all years 2011-2019
  temporal_fl_all <- data.table()
  for (r in temporal_results) {
    t_end <- r$year
    window_years <- (t_end - 2):t_end
    ftm_window <- ftm[year %in% window_years]
    fw <- ftm_window[, .(n_part = .N, n_wins = sum(won, na.rm = TRUE)), by = firm_id]
    fw[, wr := n_wins / n_part]
    al <- fw[wr == 0]
    q_w <- quantile(al$n_part, c(0.25, 0.50, 0.75))
    thr_w <- q_w[2] + 1.5 * (q_w[3] - q_w[1])
    fl_ids_w <- al[n_part > thr_w, firm_id]

    ftm_fl_w <- ftm[firm_id %chin% fl_ids_w & year == t_end]
    nl <- ftm_fl_w[, .(losers_temporal = as.integer(.N > 0)), by = .(oc_code, item_code)]
    nl[, year := t_end]
    temporal_fl_all <- rbind(temporal_fl_all, nl)
  }

  dt_temp <- dt[year >= 2011]
  dt_temp[, losers_temporal := NULL]
  dt_temp <- merge(dt_temp, temporal_fl_all, by = c("oc_code", "item_code", "year"), all.x = TRUE)
  dt_temp[is.na(losers_temporal), losers_temporal := 0L]

  m_temporal <- tryCatch(
    feols(lneg_price ~ losers_temporal + convite | item_f + year_f + pbu_f,
          data = dt_temp[!is.na(lneg_price)], cluster = ~item_f, fixef.rm = "none"),
    error = function(e) NULL
  )

  if (!is.null(m_temporal)) {
    cat(sprintf("  Temporal FL: coef=%.4f (%.4f) N=%s\n",
                coef(m_temporal)["losers_temporal"],
                sqrt(vcov(m_temporal)["losers_temporal", "losers_temporal"]),
                pfmt_int(m_temporal$nobs)))
    fl_robust[["temporal"]] <- list(model = m_temporal, year_results = temporal_results)
  }

  # Write temporal table
  temp_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{FL Definition: 3-Year Rolling Window}",
    "\\label{tab:fl_temporal}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lc}", "\\toprule",
    "\\midrule",
    sprintf("Temporal FL coefficient & %s \\\\",
            if (!is.null(m_temporal)) coef_cell(m_temporal, "losers_temporal", 4) else "---"),
    sprintf(" & %s \\\\",
            if (!is.null(m_temporal)) se_cell(m_temporal, "losers_temporal", 4) else ""),
    sprintf("Observations & %s \\\\",
            if (!is.null(m_temporal)) pfmt_int(m_temporal$nobs) else "---"),
    "Sample & 2011--2019 \\\\",
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} FL status defined using 3-year rolling windows.",
    "A firm is FL in year $t$ if it is an always-loser with participation above",
    "the IQR threshold in years $[t-2, t]$. Item, year, PBU FE.",
    "SE clustered at item level.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(temp_lines, file.path(OUT_TAB, "tab_fl_temporal.tex"))
}

# ============================================================================
# Save
# ============================================================================

saveRDS(fl_robust, FL_ROBUST_CACHE_V4)
cat("  FL robustness results saved:", FL_ROBUST_CACHE_V4, "\n")
cat("  Done.\n")
