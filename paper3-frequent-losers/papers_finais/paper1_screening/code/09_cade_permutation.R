# ============================================================================
# 09_cade_permutation.R — CADE validation with permutation test (v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# NEW [Major 3.3]:
#   - Permutation test (1,000 iterations): randomly draw 2,735 always-losers
#     stratified by participation quartile, compute co-participation rate
#   - Full 2x2 chi-squared table with denominators
#   - Regressions excluding CADE-involved markets [R2.10]
# ============================================================================

cat("=== 09_cade_permutation.R: CADE validation ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data ---------------------------------------------------------------
cade_file       <- file.path(DATA_V1, "cade_carteis_licitacoes_2009_2019.csv")
cade_match_file <- file.path(DATA_V1, "cade_bec_crossmatch.csv")
cade_fl_file    <- file.path(DATA_V1, "cade_fl_cobidders.csv")

if (!all(file.exists(c(cade_file, cade_match_file, cade_fl_file)))) {
  cat("  CADE data files not found. Skipping.\n")
  saveRDS(list(feasible = FALSE), CADE_CACHE_V4)
  quit(save = "no", status = 0)
}

cade_cartels <- fread(cade_file)
cade_match   <- fread(cade_match_file)
cade_fl      <- fread(cade_fl_file)

cat(sprintf("  CADE convictions: %d\n", nrow(cade_cartels)))
cat(sprintf("  CADE firms in BEC: %d\n", nrow(cade_match)))
cat(sprintf("  FL firms co-bidding with CADE: %d\n", nrow(cade_fl)))

# Load FL identification (apply IQR threshold to get true FL firms)
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val
fl_ids <- unique(fp[tenders_count > threshold, firm_id])

# Load firm_loss_stats for all always-losers
fls_file <- file.path(DATA_V1, "firm_loss_stats.parquet")
fls <- NULL
if (file.exists(fls_file)) {
  fls <- as.data.table(read_parquet(fls_file))
  fls_col <- grep("fornecedor", names(fls), value = TRUE, ignore.case = TRUE)
  if (length(fls_col) == 1) setnames(fls, fls_col, "firm_id")
}

# Load FTM for co-bidding check
ftm <- as.data.table(read_parquet(file.path(DATA_V1, "firm_tender_map.parquet")))
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

# Identify CADE firm IDs
cade_firm_col <- grep("fornecedor|cnpj|firm_id", names(cade_match), value = TRUE, ignore.case = TRUE)[1]
cade_firm_ids <- as.character(unique(cade_match[[cade_firm_col]]))

# ============================================================================
# Phase 1: Full 2x2 table
# ============================================================================

cat("  Phase 1: Full 2x2 contingency table...\n")

# All unique firms in BEC
all_firms <- unique(ftm$firm_id)
n_total <- length(all_firms)
n_fl <- length(fl_ids)
n_non_fl <- n_total - n_fl

# Count FL firms that co-bid with CADE
# cade_fl already has this: 193 FL firms
fl_cobid_col <- grep("fornecedor|firm_id", names(cade_fl), value = TRUE, ignore.case = TRUE)[1]
fl_cobid_ids <- unique(cade_fl[[fl_cobid_col]])
n_fl_cade <- length(fl_cobid_ids)
n_fl_no_cade <- n_fl - n_fl_cade

# Non-FL firms that co-bid with CADE
# Find all firms that share a tender with any CADE firm
cade_tenders <- ftm[firm_id %chin% cade_firm_ids, .(oc_code, item_code)]
cade_cobidders <- merge(cade_tenders, ftm[, .(firm_id, oc_code, item_code)],
                         by = c("oc_code", "item_code"), all.x = TRUE)
all_cade_cobid <- unique(cade_cobidders$firm_id)
all_cade_cobid <- setdiff(all_cade_cobid, cade_firm_ids)  # exclude CADE firms themselves

nonfl_cobid <- setdiff(all_cade_cobid, fl_ids)
n_nonfl_cade <- length(nonfl_cobid)
n_nonfl_no_cade <- n_non_fl - n_nonfl_cade

# 2x2 table
cat("  2x2 Contingency Table:\n")
cat(sprintf("  FL + CADE: %d, FL no CADE: %d\n", n_fl_cade, n_fl_no_cade))
cat(sprintf("  Non-FL + CADE: %d, Non-FL no CADE: %d\n", n_nonfl_cade, n_nonfl_no_cade))

# Chi-squared test
cont_table <- matrix(c(n_fl_cade, n_fl_no_cade, n_nonfl_cade, n_nonfl_no_cade),
                      nrow = 2, byrow = TRUE)
chi_sq <- chisq.test(cont_table)
odds_ratio <- (n_fl_cade * n_nonfl_no_cade) / (n_fl_no_cade * n_nonfl_cade)

cat(sprintf("  Chi-squared: %.1f, p < %.6f\n", chi_sq$statistic, chi_sq$p.value))
cat(sprintf("  Odds ratio: %.2f\n", odds_ratio))
cat(sprintf("  FL co-participation rate: %.1f%% vs Non-FL: %.1f%%\n",
            100 * n_fl_cade / n_fl, 100 * n_nonfl_cade / n_non_fl))

# ============================================================================
# Phase 2: Permutation test (1,000 iterations)
# ============================================================================

cat("  Phase 2: Permutation test...\n")

# Get all always-losers (win_rate = 0) from firm_loss_stats
if (!is.null(fls)) {
  win_rate_col <- grep("win_rate|taxa", names(fls), value = TRUE, ignore.case = TRUE)
  tc_col <- grep("tenders_count|particip", names(fls), value = TRUE, ignore.case = TRUE)

  if (length(win_rate_col) > 0 && length(tc_col) > 0) {
    always_losers <- fls[get(win_rate_col[1]) == 0]
    cat(sprintf("  Always-losers (pool): %s firms\n", pfmt_int(nrow(always_losers))))

    # Create participation quartiles for stratified resampling
    always_losers[, tc := get(tc_col[1])]
    always_losers[, tc_quartile := as.integer(cut(tc,
      quantile(tc, 0:4/4, na.rm = TRUE), include.lowest = TRUE, labels = 1:4))]

    # Compute FL's quartile distribution for matching
    fl_quartiles <- always_losers[firm_id %chin% fl_ids, .N, by = tc_quartile][order(tc_quartile)]

    n_iter <- 1000L
    perm_rates <- numeric(n_iter)
    observed_rate <- n_fl_cade / n_fl

    set.seed(42)
    for (i in seq_len(n_iter)) {
      # Stratified sample: match FL's quartile distribution
      sampled <- character(0)
      for (q in fl_quartiles$tc_quartile) {
        pool_q <- always_losers[tc_quartile == q & !(firm_id %chin% fl_ids), firm_id]
        n_needed <- fl_quartiles[tc_quartile == q, N]
        if (length(pool_q) >= n_needed) {
          sampled <- c(sampled, sample(pool_q, n_needed, replace = FALSE))
        } else {
          sampled <- c(sampled, sample(pool_q, n_needed, replace = TRUE))
        }
      }

      # Count co-participation rate with CADE for this random sample
      n_cobid <- sum(sampled %chin% all_cade_cobid)
      perm_rates[i] <- n_cobid / length(sampled)
    }

    perm_p_value <- mean(perm_rates >= observed_rate)
    cat(sprintf("  Observed FL-CADE rate: %.4f\n", observed_rate))
    cat(sprintf("  Permutation mean rate: %.4f (SD: %.4f)\n",
                mean(perm_rates), sd(perm_rates)))
    cat(sprintf("  Permutation p-value: %.4f\n", perm_p_value))
  } else {
    perm_rates <- numeric(0)
    perm_p_value <- NA
  }
} else {
  perm_rates <- numeric(0)
  perm_p_value <- NA
  cat("  firm_loss_stats not available. Skipping permutation test.\n")
}

# ============================================================================
# Phase 2b: Within-band AUC (Concern 1 — volume decomposition)
# ============================================================================
# Both FL score (participation count) and ground truth (CADE co-participation)
# are volume-driven. We decompose the AUC by computing it within participation-
# count deciles, isolating the signal that is not mechanically driven by volume.

cat("  Phase 2b: Within-band AUC decomposition...\n")

if (!is.null(fls) && length(win_rate_col) > 0 && length(tc_col) > 0) {
  # Simple AUC function (Mann-Whitney U statistic)
  auc_simple <- function(score, label) {
    pos <- score[label == 1L]
    neg <- score[label == 0L]
    if (length(pos) == 0 || length(neg) == 0) return(NA_real_)
    # Mann-Whitney U / (n_pos * n_neg)
    u <- sum(vapply(pos, function(p) sum(p > neg) + 0.5 * sum(p == neg), numeric(1)))
    u / (length(pos) * length(neg))
  }

  # Prepare always-loser data with CADE co-participation label
  al_auc <- copy(always_losers)
  al_auc[, cade_cobid := as.integer(firm_id %chin% as.character(all_cade_cobid))]
  al_auc[, is_fl := as.integer(firm_id %chin% as.character(fl_ids))]

  # Create deciles of participation count (use frank to handle ties)
  al_auc[, tc_rank := frank(tc, ties.method = "random")]
  al_auc[, tc_decile := ceiling(tc_rank / .N * 10)]
  al_auc[tc_decile > 10L, tc_decile := 10L]

  # Overall AUC (unconditional)
  overall_auc <- auc_simple(al_auc$tc, al_auc$cade_cobid)
  cat(sprintf("  Overall AUC (participation count): %.4f\n", overall_auc))

  # Within-band AUC per decile
  band_results <- al_auc[, {
    n_cade <- sum(cade_cobid)
    n_total <- .N
    tc_range <- paste0(min(tc), "--", max(tc))
    auc_val <- if (n_cade >= 2 && n_cade < n_total) auc_simple(tc, cade_cobid) else NA_real_
    list(n_firms = n_total, n_cade = n_cade, tc_range = tc_range, auc = auc_val)
  }, by = tc_decile][order(tc_decile)]

  cat("  Within-band AUC by participation-count decile:\n")
  print(band_results)

  # Pooled within-band AUC (weighted average of decile AUCs)
  valid_bands <- band_results[!is.na(auc)]
  if (nrow(valid_bands) > 0) {
    pooled_within_auc <- weighted.mean(valid_bands$auc, valid_bands$n_firms)
    cat(sprintf("  Pooled within-band AUC: %.4f\n", pooled_within_auc))
  } else {
    pooled_within_auc <- NA
  }

  # Residualized AUC: demean participation count within deciles
  al_auc[, tc_resid := tc - mean(tc, na.rm = TRUE), by = tc_decile]
  resid_auc <- auc_simple(al_auc$tc_resid, al_auc$cade_cobid)
  cat(sprintf("  Residualized AUC (demeaned within bands): %.4f\n", resid_auc))

  # Bootstrap CI for within-band AUC
  n_boot <- 500L
  set.seed(123)
  boot_within <- numeric(n_boot)
  for (b in seq_len(n_boot)) {
    idx <- sample.int(nrow(al_auc), replace = TRUE)
    boot_dt <- al_auc[idx]
    boot_dt[, tc_rank_b := frank(tc, ties.method = "random")]
    boot_dt[, tc_decile_b := ceiling(tc_rank_b / .N * 10)]
    boot_dt[tc_decile_b > 10L, tc_decile_b := 10L]
    bw <- boot_dt[, {
      n_c <- sum(cade_cobid); n_t <- .N
      auc_v <- if (n_c >= 2 && n_c < n_t) auc_simple(tc, cade_cobid) else NA_real_
      list(n = n_t, auc = auc_v)
    }, by = tc_decile_b]
    bv <- bw[!is.na(auc)]
    boot_within[b] <- if (nrow(bv) > 0) weighted.mean(bv$auc, bv$n) else NA_real_
  }
  boot_within <- boot_within[!is.na(boot_within)]
  within_ci <- quantile(boot_within, c(0.025, 0.975))
  cat(sprintf("  Within-band AUC 95%% CI: [%.3f, %.3f]\n", within_ci[1], within_ci[2]))

  # Write table
  cat("  Writing tab_within_band_auc.tex...\n")
  wb_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Within-Band AUC: FL Screen Performance by Participation Volume}",
    "\\label{tab:within_band_auc}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{clcccc}", "\\toprule",
    "Decile & Tenders range & Firms & CADE-linked & AUC \\\\",
    "\\midrule"
  )
  for (r in seq_len(nrow(band_results))) {
    row <- band_results[r]
    auc_str <- if (is.na(row$auc)) "---" else sprintf("%.3f", row$auc)
    wb_lines <- c(wb_lines,
      sprintf("%d & %s & %s & %d & %s \\\\",
              row$tc_decile, row$tc_range, pfmt_int(row$n_firms),
              row$n_cade, auc_str))
  }
  wb_lines <- c(wb_lines,
    "\\midrule",
    sprintf("\\multicolumn{4}{l}{Overall AUC (unconditional)} & %.3f \\\\", overall_auc),
    sprintf("\\multicolumn{4}{l}{Pooled within-band AUC} & %.3f \\\\",
            if (!is.na(pooled_within_auc)) pooled_within_auc else 0),
    sprintf("\\multicolumn{4}{l}{\\quad 95\\%% CI} & [%.3f, %.3f] \\\\",
            within_ci[1], within_ci[2]),
    sprintf("\\multicolumn{4}{l}{Residualized AUC (demeaned)} & %.3f \\\\", resid_auc),
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} AUC computed using participation count as the",
    "screening score and CADE co-participation as the binary outcome.",
    "Within-band AUC measures discrimination after controlling for volume.",
    "Residualized AUC uses participation count demeaned within deciles.",
    sprintf("Total always-losers: %s (CADE-linked: %d).",
            pfmt_int(nrow(al_auc)), sum(al_auc$cade_cobid)),
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(wb_lines, file.path(OUT_TAB, "tab_within_band_auc.tex"))

} else {
  pooled_within_auc <- NA
  resid_auc <- NA
  band_results <- NULL
  cat("  Skipping within-band AUC (data unavailable).\n")
}

# ============================================================================
# Phase 3: Regressions excluding CADE-involved markets [R2.10]
# ============================================================================

cat("  Phase 3: Excluding CADE markets...\n")

dt <- readRDS(DATA_CACHE_V4)

# Find tenders involving any CADE firm
cade_tenders_oc <- unique(ftm[firm_id %chin% cade_firm_ids, oc_code])
cat(sprintf("  CADE-involved OCs: %s\n", pfmt_int(length(cade_tenders_oc))))

dt_clean <- dt[!(oc_code %chin% cade_tenders_oc)]
cat(sprintf("  CADE-clean sample: %s rows (dropped %s)\n",
            pfmt_int(nrow(dt_clean)), pfmt_int(nrow(dt) - nrow(dt_clean))))

# Re-run baseline price regression on clean sample
m_clean <- list()
if (nrow(dt_clean[!is.na(lneg_price)]) > 1000) {
  m_clean[["general_pbu"]] <- feols(
    lneg_price ~ losers + convite | item_f + year_f + pbu_f,
    data = dt_clean[!is.na(lneg_price)], cluster = ~item_f, fixef.rm = "none"
  )

  m_clean[["pregao"]] <- feols(
    lneg_price ~ losers | item_f + year_f + pbu_f,
    data = dt_clean[pregao == 1L & !is.na(lneg_price)],
    cluster = ~item_f, fixef.rm = "none"
  )

  cat(sprintf("  CADE-clean coefficient (PBU FE): %.4f\n",
              coef(m_clean[["general_pbu"]])["losers"]))
}

# ============================================================================
# Write tables
# ============================================================================

cat("  Writing tab_cade_permutation.tex...\n")

cade_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{CADE Validation: Co-Participation and Permutation Test}",
  "\\label{tab:cade_permutation}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  "\\midrule",
  "\\textit{Panel A: Co-participation with CADE Cartelists} & & \\\\",
  sprintf("CADE procurement cartel convictions (2009--2019) & %s & \\\\",
          pfmt_int(nrow(cade_cartels))),
  sprintf("CADE firms matched to BEC & %s & \\\\", pfmt_int(length(cade_firm_ids))),
  "\\midrule",
  " & FL Firms & Non-FL Firms \\\\",
  "\\cmidrule(lr){2-3}",
  sprintf("Co-bids with CADE & %s & %s \\\\", pfmt_int(n_fl_cade), pfmt_int(n_nonfl_cade)),
  sprintf("Does not co-bid & %s & %s \\\\", pfmt_int(n_fl_no_cade), pfmt_int(n_nonfl_no_cade)),
  sprintf("Total & %s & %s \\\\", pfmt_int(n_fl), pfmt_int(n_non_fl)),
  sprintf("Co-participation rate & %.1f\\%% & %.1f\\%% \\\\",
          100 * n_fl_cade / n_fl, 100 * n_nonfl_cade / n_non_fl),
  "\\midrule",
  sprintf("$\\chi^2$ statistic & %.1f & \\\\", chi_sq$statistic),
  sprintf("p-value & %.3f & \\\\", chi_sq$p.value),
  sprintf("Odds ratio & %.2f & \\\\", odds_ratio),
  "\\midrule",
  "\\textit{Panel B: Permutation Test (1,000 iterations)} & & \\\\"
)

if (!is.na(perm_p_value)) {
  cade_lines <- c(cade_lines,
    sprintf("Observed FL-CADE rate & %.4f & \\\\", observed_rate),
    sprintf("Permutation mean rate & %.4f & \\\\", mean(perm_rates)),
    sprintf("Permutation SD & %.4f & \\\\", sd(perm_rates)),
    sprintf("p-value (rate $\\geq$ observed) & %.4f & \\\\", perm_p_value))
}

cade_lines <- c(cade_lines, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Panel A: contingency table of firm co-participation",
  "with CADE-convicted cartelists. Panel B: 1,000 random draws of",
  sprintf("%s firms from the always-loser pool, stratified by participation", pfmt_int(n_fl)),
  "quartile, computing co-participation rate with CADE firms.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(cade_lines, file.path(OUT_TAB, "tab_cade_permutation.tex"))

# Write excl-CADE table
if (length(m_clean) > 0) {
  cat("  Writing tab_excl_cade.tex...\n")

  excl_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Price Regressions Excluding CADE-Involved Markets}",
    "\\label{tab:excl_cade}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcc}", "\\toprule",
    " & (1) General+PBU & (2) Preg\\~{a}o \\\\",
    "\\midrule"
  )

  for (nm in names(m_clean)) {
    m <- m_clean[[nm]]
    b <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    p <- 2 * pnorm(-abs(b/se))
    excl_lines <- c(excl_lines,
      sprintf("FL presence & %s%s & \\\\", pfmt(b, 4), pstars(p)))
  }

  # Proper 2-column format
  vals <- sapply(m_clean, function(m) {
    coef_cell(m, "losers", 4)
  })
  ses <- sapply(m_clean, function(m) {
    se_cell(m, "losers", 4)
  })
  obs <- sapply(m_clean, function(m) pfmt_int(m$nobs))

  excl_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Price Regressions Excluding CADE-Involved Markets}",
    "\\label{tab:excl_cade}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcc}", "\\toprule",
    " & (1) General+PBU & (2) Preg\\~{a}o \\\\",
    "\\midrule",
    sprintf("FL presence & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    sprintf("CADE tenders dropped & \\multicolumn{2}{c}{%s} \\\\",
            pfmt_int(length(cade_tenders_oc))),
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Dropping all tenders involving any CADE-convicted firm.",
    "SE clustered at item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(excl_lines, file.path(OUT_TAB, "tab_excl_cade.tex"))
}

# ============================================================================
# Save
# ============================================================================

cade_results <- list(
  contingency = list(
    n_fl_cade = n_fl_cade, n_fl_no_cade = n_fl_no_cade,
    n_nonfl_cade = n_nonfl_cade, n_nonfl_no_cade = n_nonfl_no_cade,
    chi_sq = chi_sq$statistic, chi_p = chi_sq$p.value,
    odds_ratio = odds_ratio
  ),
  permutation = list(
    rates = perm_rates,
    observed = if (exists("observed_rate")) observed_rate else NA,
    p_value = perm_p_value
  ),
  within_band_auc = list(
    overall_auc = if (exists("overall_auc")) overall_auc else NA,
    pooled_within_auc = pooled_within_auc,
    resid_auc = if (exists("resid_auc")) resid_auc else NA,
    band_results = band_results
  ),
  excl_cade = m_clean
)

saveRDS(cade_results, CADE_CACHE_V4)
cat("  CADE results saved:", CADE_CACHE_V4, "\n")
cat("  Done.\n")
