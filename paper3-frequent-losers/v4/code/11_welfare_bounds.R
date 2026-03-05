# ============================================================================
# 11_welfare_bounds.R — Welfare analysis with IV-based bounds (v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Base: same as v3 (exp(beta) - 1) x total_price
# NEW: IV-based upper bound [Medium 4.3]
# NEW: Network-split welfare bounds
# ============================================================================

cat("=== 11_welfare_bounds.R: Welfare analysis ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

if (!file.exists(MODELS_CACHE_V4)) stop("Run 05_main_regressions.R first")
models <- readRDS(MODELS_CACHE_V4)

# ---- OLS-based welfare (baseline) -------------------------------------------
m_price <- models$prices$general_pbu
b_ols  <- coef(m_price)["losers"]
se_ols <- sqrt(vcov(m_price)["losers", "losers"])
ci_lo_ols <- b_ols - 1.96 * se_ols
ci_hi_ols <- b_ols + 1.96 * se_ols

markup_ols <- (exp(b_ols) - 1) * 100

d_fl <- dt[losers == 1 & !is.na(bid_unit_price_negot_min) & bid_unit_price_negot_min > 0]
total_price_fl <- sum(d_fl$bid_unit_price_negot_min)
n_fl_tenders <- nrow(d_fl)

wf_ols    <- (exp(b_ols) - 1) * total_price_fl
wf_ols_lo <- (exp(ci_lo_ols) - 1) * total_price_fl
wf_ols_hi <- (exp(ci_hi_ols) - 1) * total_price_fl

cat(sprintf("  OLS markup: %.2f%% [%.2f%%, %.2f%%]\n",
            markup_ols, (exp(ci_lo_ols)-1)*100, (exp(ci_hi_ols)-1)*100))
cat(sprintf("  OLS welfare loss: R$ %s [%s, %s]\n",
            formatC(wf_ols, format="f", digits=0, big.mark=","),
            formatC(wf_ols_lo, format="f", digits=0, big.mark=","),
            formatC(wf_ols_hi, format="f", digits=0, big.mark=",")))

# ---- IV-based welfare (upper bound) -----------------------------------------
b_iv <- NA; se_iv <- NA; markup_iv <- NA; wf_iv <- NA

if (file.exists(IV_MODELS_CACHE_V4)) {
  iv_models <- readRDS(IV_MODELS_CACHE_V4)

  m_iv_price <- iv_models$iv_models$lneg_price$iv_pbu
  if (!is.null(m_iv_price) && "fit_losers" %in% names(coef(m_iv_price))) {
    b_iv  <- coef(m_iv_price)["fit_losers"]
    se_iv <- sqrt(vcov(m_iv_price)["fit_losers", "fit_losers"])
    markup_iv <- (exp(b_iv) - 1) * 100
    wf_iv <- (exp(b_iv) - 1) * total_price_fl

    cat(sprintf("  IV markup: %.2f%%\n", markup_iv))
    cat(sprintf("  IV welfare loss: R$ %s\n",
                formatC(wf_iv, format="f", digits=0, big.mark=",")))
  }
}

# ---- Network-split welfare ---------------------------------------------------
b_high <- NA; wf_high <- NA

if (!is.null(models$network_split) && length(models$network_split) > 0) {
  m_ns <- models$network_split$general_pbu
  if (!is.null(m_ns) && "has_high_susp_fl" %in% names(coef(m_ns))) {
    b_high <- coef(m_ns)["has_high_susp_fl"]
    markup_high <- (exp(b_high) - 1) * 100

    d_high <- dt[has_high_susp_fl == 1 & !is.na(bid_unit_price_negot_min) &
                   bid_unit_price_negot_min > 0]
    if (nrow(d_high) > 0) {
      wf_high <- (exp(b_high) - 1) * sum(d_high$bid_unit_price_negot_min)
      cat(sprintf("  High-suspicion markup: %.2f%%, welfare: R$ %s\n",
                  markup_high, formatC(wf_high, format="f", digits=0, big.mark=",")))
    }
  }
}

# ---- Welfare as % of total procurement spending (Comment 3.3a) ---------------

cat("  Computing welfare as %% of total spending...\n")

total_spending <- sum(dt[!is.na(bid_unit_price_negot_min) & bid_unit_price_negot_min > 0,
                          bid_unit_price_negot_min])
pct_ols <- wf_ols / total_spending * 100
pct_iv <- if (!is.na(wf_iv)) wf_iv / total_spending * 100 else NA

cat(sprintf("  Total procurement spending: R$ %s\n",
            formatC(total_spending, format="f", digits=0, big.mark=",")))
cat(sprintf("  OLS welfare / total: %.3f%%\n", pct_ols))
if (!is.na(pct_iv)) cat(sprintf("  IV welfare / total: %.3f%%\n", pct_iv))

# ---- Cross-fit welfare bound (Comment 3.3b) ----------------------------------

cat("  Cross-fit welfare bound...\n")

b_crossfit <- 0.036  # from v4 cross-fitting exercise (odd/even year average)
markup_crossfit <- (exp(b_crossfit) - 1) * 100
wf_crossfit <- (exp(b_crossfit) - 1) * total_price_fl
pct_crossfit <- wf_crossfit / total_spending * 100

cat(sprintf("  Cross-fit: coef=%.4f, markup=%.2f%%, welfare=R$ %s\n",
            b_crossfit, markup_crossfit,
            formatC(wf_crossfit, format="f", digits=0, big.mark=",")))

# ---- LATE caveat (Comment 3.3c) ---------------------------------------------

cat("\n  === LATE caveat text (Comment 3.3c) ===\n")
cat("  The IV estimate represents a Local Average Treatment Effect (LATE) for the\n")
cat("  subset of tenders whose FL participation status is shifted by the supply-side\n")
cat("  instrument. This is not necessarily the ATE for all FL-present tenders.\n")
cat("  The welfare bounds should be interpreted accordingly: the IV-based upper bound\n")
cat("  may overstate total welfare losses if complier tenders are not representative.\n\n")

# ============================================================================
# Write welfare bounds table (updated with cross-fit and % spending)
# ============================================================================

cat("  Writing tab_welfare_bounds.tex...\n")

wf_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Welfare Loss Bounds from Cover Bidding}",
  "\\label{tab:welfare_bounds}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & OLS & Cross-Fit & IV & High-Suspicion FL \\\\",
  " & (lower bound) & (intermediate) & (upper bound) & (network-adjusted) \\\\",
  "\\midrule",
  sprintf("Price coefficient & %s & %s & %s & %s \\\\",
          pfmt(b_ols, 4), pfmt(b_crossfit, 4),
          if (!is.na(b_iv)) pfmt(b_iv, 4) else "---",
          if (!is.na(b_high)) pfmt(b_high, 4) else "---"),
  sprintf("Implied markup (\\%%) & %.2f & %.2f & %s & %s \\\\",
          markup_ols, markup_crossfit,
          if (!is.na(markup_iv)) sprintf("%.2f", markup_iv) else "---",
          if (!is.na(b_high)) sprintf("%.2f", (exp(b_high)-1)*100) else "---"),
  "\\midrule",
  sprintf("FL-present tenders & \\multicolumn{4}{c}{%s} \\\\", pfmt_int(n_fl_tenders)),
  sprintf("Total FL prices (R\\$) & \\multicolumn{4}{c}{%s} \\\\",
          formatC(total_price_fl, format="f", digits=0, big.mark=",")),
  sprintf("Total procurement (R\\$) & \\multicolumn{4}{c}{%s} \\\\",
          formatC(total_spending, format="f", digits=0, big.mark=",")),
  "\\midrule",
  sprintf("\\textbf{Welfare loss (R\\$)} & \\textbf{%s} & \\textbf{%s} & \\textbf{%s} & \\textbf{%s} \\\\",
          formatC(wf_ols, format="f", digits=0, big.mark=","),
          formatC(wf_crossfit, format="f", digits=0, big.mark=","),
          if (!is.na(wf_iv)) formatC(wf_iv, format="f", digits=0, big.mark=",") else "---",
          if (!is.na(wf_high)) formatC(wf_high, format="f", digits=0, big.mark=",") else "---"),
  sprintf("As \\%% of total spending & %.3f\\%% & %.3f\\%% & %s & %s \\\\",
          pct_ols, pct_crossfit,
          if (!is.na(pct_iv)) sprintf("%.3f\\%%", pct_iv) else "---",
          "---"),
  sprintf("95\\%% CI (OLS) & [%s, %s] & & & \\\\",
          formatC(wf_ols_lo, format="f", digits=0, big.mark=","),
          formatC(wf_ols_hi, format="f", digits=0, big.mark=",")),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Markup = $\\exp(\\hat{\\beta}) - 1$.",
  "OLS provides a lower bound if measurement error attenuates the coefficient.",
  "Cross-fit uses the average coefficient from odd/even year cross-fitting (0.036).",
  "IV corrects for attenuation; the IV estimate represents a LATE for complier tenders.",
  "High-suspicion restricts to FL firms with concentrated winner patterns.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(wf_lines, file.path(OUT_TAB, "tab_welfare_bounds.tex"))

# ============================================================================
# Save
# ============================================================================

welfare_results <- list(
  ols = list(coef = b_ols, se = se_ols, markup = markup_ols,
             welfare = wf_ols, ci = c(wf_ols_lo, wf_ols_hi)),
  crossfit = list(coef = b_crossfit, markup = markup_crossfit, welfare = wf_crossfit),
  iv = list(coef = b_iv, se = se_iv, markup = markup_iv, welfare = wf_iv),
  network = list(coef_high = b_high, welfare_high = wf_high),
  total_price_fl = total_price_fl,
  total_spending = total_spending,
  pct_of_spending = list(ols = pct_ols, crossfit = pct_crossfit, iv = pct_iv),
  n_fl_tenders = n_fl_tenders
)

saveRDS(welfare_results, WELFARE_CACHE_V4)
cat("  Welfare results saved:", WELFARE_CACHE_V4, "\n")
cat("  Done.\n")
