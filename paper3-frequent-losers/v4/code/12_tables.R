# ============================================================================
# 12_tables.R — All LaTeX tables for Paper 3 v4
# ============================================================================
# Tables already written by individual scripts (04-16) are NOT duplicated.
# This script generates: descriptive stats, main regressions (4 DVs),
# Bajari-Ye combined, mechanisms, C&S DiD, regime test (from models).
# Individual scripts already produce: IV tables, network-split, CADE,
# threshold robustness, matching, welfare, FL robustness, oversight, etc.
# ============================================================================

cat("=== 12_tables.R: Table generation ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load models and data ---------------------------------------------------
if (!file.exists(MODELS_CACHE_V4)) stop("Run 05_main_regressions.R first")
models <- readRDS(MODELS_CACHE_V4)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

# ============================================================================
# Table 1: Descriptive statistics
# ============================================================================

cat("  Table 1: Descriptive statistics...\n")

vars <- list(
  list(name = "bid_unit_price_negot_min", label = "Negotiated price", filter = "price", fmt = 2),
  list(name = "lneg_price", label = "Log negotiated price", filter = "price", fmt = 2),
  list(name = "n_firms", label = "Number of firms", filter = "all", fmt = 2),
  list(name = "ln_firms", label = "Log number of firms", filter = "all", fmt = 2),
  list(name = "n_bids", label = "Number of bids", filter = "all", fmt = 2),
  list(name = "n_genuine", label = "Non-FL firms", filter = "all", fmt = 2),
  list(name = "losers_count", label = "FL count per tender", filter = "all", fmt = 2)
)

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Descriptive Statistics: Tenders With vs.\\ Without Frequent Losers}",
  "\\label{tab:descstats}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccccc}", "\\toprule",
  " & \\multicolumn{3}{c}{With FL} & \\multicolumn{3}{c}{Without FL} \\\\",
  "\\cmidrule(lr){2-4} \\cmidrule(lr){5-7}",
  " & Mean & SD & N & Mean & SD & N \\\\", "\\midrule"
)

for (v in vars) {
  vals <- character(6); idx <- 1
  for (cond in list(quote(losers == 1), quote(losers == 0))) {
    sub <- dt[eval(cond)]
    if (v$filter == "price") sub <- sub[!is.na(lneg_price)]
    x <- sub[[v$name]]; x <- x[!is.na(x)]
    vals[idx]     <- pfmt(mean(x), v$fmt)
    vals[idx + 1] <- pfmt(sd(x), v$fmt)
    vals[idx + 2] <- pfmt_int(length(x))
    idx <- idx + 3
  }
  lines <- c(lines, sprintf("%s & %s \\\\", v$label, paste(vals, collapse = " & ")))
}

lines <- c(lines, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Sample restricted to item types with $\\geq$1 FL tender.",
  "FL = frequent losers defined by median + 1.5$\\times$IQR threshold.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(lines, file.path(OUT_TAB, "tab_desc_stats.tex"))
cat("  Saved: tab_desc_stats.tex\n")

# ============================================================================
# Tables 2-5: Main regressions (4 DVs x 4 specs)
# ============================================================================

cat("  Tables 2-5: Main regressions...\n")

table_specs <- list(
  list(mlist = models$prices, caption = "Negotiated Prices (log): Effect of Frequent Losers",
       label = "tab:prices", coef_names = c("losers", "convite"),
       coef_labels = c("FL presence", "Convite"), filename = "tab_prices.tex"),
  list(mlist = models$nfirms, caption = "Number of Firms (log): Effect of Frequent Losers",
       label = "tab:nfirms", coef_names = c("losers", "convite"),
       coef_labels = c("FL presence", "Convite"), filename = "tab_nfirms.tex"),
  list(mlist = models$nbids, caption = "Number of Bids (log): Effect of Frequent Losers",
       label = "tab:nbids", coef_names = c("losers", "convite"),
       coef_labels = c("FL presence", "Convite"), filename = "tab_nbids.tex"),
  list(mlist = models$nfirms_excl,
       caption = "Non-FL Firms (log): Genuine Competition",
       label = "tab:nfirms_excl", coef_names = c("losers", "convite"),
       coef_labels = c("FL presence", "Convite"), filename = "tab_nfirms_excl.tex")
)

for (ts in table_specs) {
  write_losers_table(ts$mlist, ts$caption, ts$label,
                      ts$coef_names, ts$coef_labels, filename = ts$filename)
}

# ============================================================================
# Table 6: Bajari-Ye test results (combined)
# ============================================================================

cat("  Table 6: Bajari-Ye test results...\n")

if (file.exists(BAJARI_CACHE_V4)) {
  bj <- readRDS(BAJARI_CACHE_V4)

  if (isTRUE(bj$feasible)) {
    bj_lines <- c(
      "\\begin{table}[htbp]", "\\centering",
      "\\caption{Bajari \\& Ye (2003) Tests for Bid Coordination}",
      "\\label{tab:bajari_ye}",
      "\\begin{adjustbox}{max width=\\textwidth}",
      "\\begin{threeparttable}", "\\small",
      "\\begin{tabular}{lcc}", "\\toprule",
      "Test & Statistic & p-value \\\\", "\\midrule",
      "\\textit{Panel A: Exchangeability (KS test)} & & \\\\"
    )

    if (bj$exchangeability$feasible)
      bj_lines <- c(bj_lines, sprintf(
        "\\quad FL vs.\\ non-FL residuals & %.4f & %.6f \\\\",
        bj$exchangeability$ks_stat, bj$exchangeability$ks_p))

    bj_lines <- c(bj_lines, "[6pt]",
      "\\textit{Panel B: Conditional Independence} & & \\\\")

    if (bj$independence$feasible) {
      bj_lines <- c(bj_lines,
        sprintf("\\quad FL pairwise product & %.4f & %.6f \\\\",
                bj$independence$mean_product, bj$independence$p_value),
        sprintf("\\quad Non-FL pairwise product & %.4f & %.6f \\\\",
                bj$placebo$mean, bj$placebo$p_value),
        sprintf("\\quad Difference (FL $-$ non-FL) & %.4f & \\\\",
                bj$bootstrap$observed_diff),
        sprintf("\\quad Bootstrap 95\\%% CI & [%.4f, %.4f] & \\\\",
                bj$bootstrap$boot_ci[1], bj$bootstrap$boot_ci[2]))
    }

    bj_lines <- c(bj_lines, "[6pt]",
      "\\textit{Panel C: Fake-Groups Placebo} & & \\\\")
    if (!is.na(bj$fake_groups$p_value))
      bj_lines <- c(bj_lines, sprintf(
        "\\quad Random non-FL groups & %.4f & %.4f \\\\",
        bj$fake_groups$mean, bj$fake_groups$p_value))

    bj_lines <- c(bj_lines, "\\bottomrule", "\\end{tabular}",
      "\\begin{tablenotes}", "\\small",
      "\\item \\textit{Notes:} Panel A: KS test on first-stage bid residuals.",
      "Panel B: Mean product of pairwise residuals.",
      "Panel C: Non-FL firms randomly split into groups (validates methodology).",
      "Bootstrap: 1,000 tender-level resamples.",
      "\\end{tablenotes}", "\\end{threeparttable}",
      "\\end{adjustbox}", "\\end{table}")
    writeLines(bj_lines, file.path(OUT_TAB, "tab_bajari_ye.tex"))
    cat("  Saved: tab_bajari_ye.tex\n")
  }
}

# ============================================================================
# Table 7: Mechanism tests
# ============================================================================

cat("  Table 7: Mechanism tests...\n")

if (file.exists(MECHANISMS_CACHE_V4)) {
  mech <- readRDS(MECHANISMS_CACHE_V4)

  mech_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Mechanism Tests}",
    "\\label{tab:mechanisms}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lccc}", "\\toprule",
    "Mechanism & Coefficient & SE & N \\\\", "\\midrule"
  )

  if (!is.null(mech$m1)) {
    m <- mech$m1$general_pbu
    b <- coef(m)["cover_tender"]; se <- sqrt(vcov(m)["cover_tender", "cover_tender"])
    p <- 2 * pnorm(-abs(b/se))
    mech_lines <- c(mech_lines,
      sprintf("M1: Competitive displacement (OLS) & %s%s & (%s) & %s \\\\",
              pfmt(b,4), pstars(p), pfmt(se,4), pfmt_int(m$nobs)),
      "\\quad DV: $\\log(n_{\\text{genuine}} + 1)$ & & & \\\\")
  }

  if (!is.null(mech$m1_iv) && "fit_cover_tender" %in% names(coef(mech$m1_iv))) {
    m <- mech$m1_iv
    b <- coef(m)["fit_cover_tender"]; se <- sqrt(vcov(m)["fit_cover_tender", "fit_cover_tender"])
    p <- 2 * pnorm(-abs(b/se))
    mech_lines <- c(mech_lines,
      sprintf("M1: Competitive displacement (IV) & %s%s & (%s) & %s \\\\",
              pfmt(b,4), pstars(p), pfmt(se,4), pfmt_int(m$nobs)))
  }

  if (!is.null(mech$m2)) {
    m <- mech$m2$general_pbu
    b <- coef(m)["cover_tender"]; se <- sqrt(vcov(m)["cover_tender", "cover_tender"])
    p <- 2 * pnorm(-abs(b/se))
    mech_lines <- c(mech_lines,
      sprintf("M2: Reference price calibration & %s%s & (%s) & %s \\\\",
              pfmt(b,4), pstars(p), pfmt(se,4), pfmt_int(m$nobs)),
      "\\quad DV: $\\log(p_{\\text{negot}} / p_{\\text{ref}})$ & & & \\\\")
  }

  if (!is.null(mech$m3)) {
    m <- mech$m3
    b <- coef(m)["log_price_lag"]; se <- sqrt(vcov(m)["log_price_lag", "log_price_lag"])
    p <- 2 * pnorm(-abs(b/se))
    mech_lines <- c(mech_lines,
      sprintf("M3: Reverse causality & %s%s & (%s) & %s \\\\",
              pfmt(b,4), pstars(p), pfmt(se,4), pfmt_int(m$nobs)))
  }

  mech_lines <- c(mech_lines, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} M1: FL presence on genuine competition. M2: bid-to-reference ratio.",
    "M3: lagged price predicting FL entry (reverse causality check).",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(mech_lines, file.path(OUT_TAB, "tab_mechanisms.tex"))
  cat("  Saved: tab_mechanisms.tex\n")
}

# ============================================================================
# Table: Regime test (dispersion)
# ============================================================================

cat("  Regime test table...\n")

if (!is.null(models$dispersion) && length(models$dispersion) > 0 &&
    !is.null(models$dispersion$total)) {
  regime_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Regime Test: Bid Dispersion}",
    "\\label{tab:regime_test}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcccc}", "\\toprule",
    " & (1) & (2) & (3) & (4) \\\\",
    " & General & General & Preg\\~{a}o & Convite \\\\",
    "\\midrule"
  )

  m_order <- c("general", "general_pbu", "pregao", "convite")
  vals <- sapply(m_order, function(sp) {
    m <- models$dispersion$total[[sp]]
    if (!is.null(m) && "losers" %in% names(coef(m))) coef_cell(m, "losers", 4) else ""
  })
  ses <- sapply(m_order, function(sp) {
    m <- models$dispersion$total[[sp]]
    if (!is.null(m) && "losers" %in% names(coef(m))) se_cell(m, "losers", 4) else ""
  })

  regime_lines <- c(regime_lines,
    sprintf("FL presence & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    "DV: Log bid SD & \\multicolumn{4}{c}{Total bid dispersion} \\\\",
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Positive coefficient: FL presence increases bid dispersion",
    "(consistent with Regime 1, complementary cover bidding).",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(regime_lines, file.path(OUT_TAB, "tab_regime_test.tex"))
}

cat("  All tables generated.\n")
