# ============================================================================
# 13_tables.R — All LaTeX tables for Paper 3 v2
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Generates ~15 LaTeX tables. Some reuse v1 format; others are new.
# Tables produced by individual scripts (05, 11, 12) are NOT duplicated here.
# This script generates: descriptive stats, main regressions, regime test,
# Bajari-Ye, mechanisms, C&S DiD, CADE validation, FL characteristics.
# ============================================================================

cat("=== 13_tables.R: Table generation ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load models and data ----------------------------------------------------
if (!file.exists(MODELS_CACHE_V2)) stop("Run 06_main_regressions.R first")
models <- readRDS(MODELS_CACHE_V2)

if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)

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
  "\\caption{Descriptive Statistics: Tenders With vs.\\ Without Cover Bidders}",
  "\\label{tab:descstats}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccccc}", "\\toprule",
  " & \\multicolumn{3}{c}{With Cover Bidders} & \\multicolumn{3}{c}{Without Cover Bidders} \\\\",
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
  "\\item \\textit{Notes:} Sample restricted to item types with at least one tender involving a frequent loser.",
  "Cover bidders = frequent losers (FL) as defined by median + 1.5$\\times$IQR threshold.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(lines, file.path(OUT_TAB, "tab_desc_stats.tex"))
cat("  Saved: tab_desc_stats.tex\n")

# ============================================================================
# Tables 2-5: Main regressions (4 DVs x 4 specs)
# ============================================================================

cat("  Tables 2-5: Main regressions...\n")

table_specs <- list(
  list(mlist = models$prices, caption = "Negotiated Prices (log): Effect of Cover Bidders",
       label = "tab:prices", coef_names = c("losers", "convite"),
       coef_labels = c("Cover bidder", "Convite"), filename = "tab_prices.tex"),
  list(mlist = models$nfirms, caption = "Number of Firms (log): Effect of Cover Bidders",
       label = "tab:nfirms", coef_names = c("losers", "convite"),
       coef_labels = c("Cover bidder", "Convite"), filename = "tab_nfirms.tex"),
  list(mlist = models$nbids, caption = "Number of Bids (log): Effect of Cover Bidders",
       label = "tab:nbids", coef_names = c("losers", "convite"),
       coef_labels = c("Cover bidder", "Convite"), filename = "tab_nbids.tex"),
  list(mlist = models$nfirms_excl,
       caption = "Non-FL Firms (log): Mechanical Relationship Test",
       label = "tab:nfirms_excl", coef_names = c("losers", "convite"),
       coef_labels = c("Cover bidder", "Convite"), filename = "tab_nfirms_excl.tex")
)

for (ts in table_specs) {
  write_losers_table(ts$mlist, ts$caption, ts$label,
                      ts$coef_names, ts$coef_labels, filename = ts$filename)
}

# ============================================================================
# Table 6: Bajari-Ye test results
# ============================================================================

cat("  Table 6: Bajari-Ye test results...\n")

bj_file <- "/tmp/p3v2_bajari_ye.rds"
if (file.exists(bj_file)) {
  bj <- readRDS(bj_file)

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

  if (bj$exchangeability$feasible) {
    bj_lines <- c(bj_lines, sprintf(
      "\\quad FL vs.\\ non-FL residuals & %.4f & %.6f \\\\",
      bj$exchangeability$ks_stat, bj$exchangeability$ks_p))
  } else {
    bj_lines <- c(bj_lines, "\\quad Not feasible & --- & --- \\\\")
  }

  bj_lines <- c(bj_lines, "[6pt]",
    "\\textit{Panel B: Conditional Independence} & & \\\\")

  if (bj$independence$feasible) {
    bj_lines <- c(bj_lines, sprintf(
      "\\quad FL pairwise correlation & %.6f & %.6f \\\\",
      bj$independence$mean_product, bj$independence$p_value))
    bj_lines <- c(bj_lines, sprintf(
      "\\quad Tenders with 2+ FL bids & %s & \\\\",
      pfmt_int(bj$independence$n_tenders_2plus)))
  }

  bj_lines <- c(bj_lines, "[6pt]",
    "\\textit{Panel C: Placebo (non-FL pairs)} & & \\\\")
  if (!is.na(bj$placebo$p_value)) {
    bj_lines <- c(bj_lines, sprintf(
      "\\quad Non-FL pairwise correlation & & %.6f \\\\",
      bj$placebo$p_value))
  }

  bj_lines <- c(bj_lines, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Panel A: KS test on first-stage bid residuals.",
    "Panel B: Mean product of pairwise residuals within tenders with 2+ FL losing bids.",
    "Panel C: Same test on non-FL pairs (placebo, expected: fail to reject).",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(bj_lines, file.path(OUT_TAB, "tab_bajari_ye.tex"))
  cat("  Saved: tab_bajari_ye.tex\n")
}

# ============================================================================
# Table 7: Mechanism tests
# ============================================================================

cat("  Table 7: Mechanism tests...\n")

mech_file <- "/tmp/p3v2_mechanisms.rds"
if (file.exists(mech_file)) {
  mech <- readRDS(mech_file)

  mech_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Mechanism Tests}",
    "\\label{tab:mechanisms}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lccc}", "\\toprule",
    "Mechanism & Coefficient & SE & N \\\\", "\\midrule"
  )

  # M1: Competitive displacement
  if (!is.null(mech$m1)) {
    m <- mech$m1$general_pbu
    b <- coef(m)["cover_tender"]; se <- sqrt(vcov(m)["cover_tender", "cover_tender"])
    p <- 2 * pnorm(-abs(b/se))
    mech_lines <- c(mech_lines, sprintf(
      "M1: Competitive displacement & %s%s & (%s) & %s \\\\",
      pfmt(b, 4), pstars(p), pfmt(se, 4), pfmt_int(m$nobs)))
    mech_lines <- c(mech_lines, "\\quad DV: $\\log(n_{\\text{genuine}} + 1)$ & & & \\\\")
  }

  # M2: Reference price calibration
  if (!is.null(mech$m2)) {
    m <- mech$m2$general_pbu
    b <- coef(m)["cover_tender"]; se <- sqrt(vcov(m)["cover_tender", "cover_tender"])
    p <- 2 * pnorm(-abs(b/se))
    mech_lines <- c(mech_lines, sprintf(
      "M2: Reference price calibration & %s%s & (%s) & %s \\\\",
      pfmt(b, 4), pstars(p), pfmt(se, 4), pfmt_int(m$nobs)))
    mech_lines <- c(mech_lines, "\\quad DV: $\\log(p_{\\text{negot}} / p_{\\text{ref}})$ & & & \\\\")
  }

  # M3: Reverse causality
  if (!is.null(mech$m3)) {
    m <- mech$m3
    b <- coef(m)["log_price_lag"]; se <- sqrt(vcov(m)["log_price_lag", "log_price_lag"])
    p <- 2 * pnorm(-abs(b/se))
    mech_lines <- c(mech_lines, sprintf(
      "M3: Reverse causality & %s%s & (%s) & %s \\\\",
      pfmt(b, 4), pstars(p), pfmt(se, 4), pfmt_int(m$nobs)))
    mech_lines <- c(mech_lines,
      "\\quad DV: $\\text{cover\\_tender}_t$, IV: $\\log(\\text{price})_{t-1}$ & & & \\\\")
  }

  mech_lines <- c(mech_lines, "\\midrule",
    "FE & \\multicolumn{3}{c}{Item + Year + PBU (M1, M2); Market + Year (M3)} \\\\",
    "Clustering & \\multicolumn{3}{c}{Item (M1, M2); Market (M3)} \\\\",
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} M1 tests whether cover bidder presence reduces genuine competition.",
    "M2 tests whether FL tenders show different negotiated-to-reference price ratios.",
    "M3 tests reverse causality: lagged market price predicting FL entry.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(mech_lines, file.path(OUT_TAB, "tab_mechanisms.tex"))
  cat("  Saved: tab_mechanisms.tex\n")
}

# ============================================================================
# Table 8: C&S DiD results
# ============================================================================

cat("  Table 8: C&S DiD results...\n")

did_file <- "/tmp/p3v2_did.rds"
if (file.exists(did_file)) {
  did <- readRDS(did_file)

  did_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Staggered Difference-in-Differences: Cover Bidder Entry}",
    "\\label{tab:did_cs}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcccccc}", "\\toprule",
    " & \\multicolumn{2}{c}{C\\&S (2021)} & \\multicolumn{2}{c}{TWFE} & \\multicolumn{2}{c}{Sun \\& Abraham} \\\\",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7}",
    "Outcome & ATT & SE & Pre-trend & Post & ATT & SE \\\\",
    "\\midrule"
  )

  dvs <- c("log_price", "log_nfirms_excl")
  dv_labels <- c("Log Price", "Log Firms (excl. FL)")

  for (di in seq_along(dvs)) {
    dv <- dvs[di]; dv_lbl <- dv_labels[di]

    # C&S
    cs_att <- "---"; cs_se <- ""
    if (dv %in% names(did$callaway_santanna)) {
      cs <- did$callaway_santanna[[dv]]
      if (!is.null(cs$att_overall)) {
        cs_att <- pfmt(cs$att_overall$overall.att, 4)
        cs_se <- sprintf("(%s)", pfmt(cs$att_overall$overall.se, 4))
      }
    }

    # TWFE
    pre_str <- "---"; post_str <- "---"
    if (dv %in% names(did$twfe_coefs)) {
      cf <- did$twfe_coefs[[dv]]
      pre_str  <- pfmt(mean(cf[rel_year < 0, coef], na.rm = TRUE), 4)
      post_str <- pfmt(mean(cf[rel_year >= 0, coef], na.rm = TRUE), 4)
    }

    # Sun & Abraham
    sa_att <- "---"; sa_se <- ""
    if (dv %in% names(did$sun_abraham)) {
      sa_att <- pfmt(did$sun_abraham[[dv]]$att, 4)
      sa_se <- sprintf("(%s)", pfmt(did$sun_abraham[[dv]]$se, 4))
    }

    did_lines <- c(did_lines, sprintf(
      "%s & %s & %s & %s & %s & %s & %s \\\\",
      dv_lbl, cs_att, cs_se, pre_str, post_str, sa_att, sa_se))
  }

  did_lines <- c(did_lines, "\\midrule",
    sprintf("Markets & \\multicolumn{6}{c}{%s (%s treated, %s control)} \\\\",
            pfmt_int(did$panel_summary$n_markets),
            pfmt_int(did$panel_summary$n_treated),
            pfmt_int(did$panel_summary$n_control)),
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} C\\&S: Callaway \\& Sant'Anna (2021) with doubly-robust estimation.",
    "TWFE: Two-way FE event study, pre/post = average coefficients.",
    "Market = item $\\times$ PBU. Treatment: first FL entry year.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(did_lines, file.path(OUT_TAB, "tab_did_cs.tex"))
  cat("  Saved: tab_did_cs.tex\n")
}

# ============================================================================
# Table 9: CADE Validation
# ============================================================================

cat("  Table 9: CADE validation...\n")

cade_file <- file.path(DATA_V1, "cade_carteis_licitacoes_2009_2019.csv")
cade_match_file <- file.path(DATA_V1, "cade_bec_crossmatch.csv")
cade_fl_file <- file.path(DATA_V1, "cade_fl_cobidders.csv")

if (all(file.exists(c(cade_file, cade_match_file, cade_fl_file)))) {
  cade_cartels <- fread(cade_file)
  cade_match   <- fread(cade_match_file)
  cade_fl      <- fread(cade_fl_file)

  cade_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{External Validation: CADE Cartel Convictions (2009--2019)}",
    "\\label{tab:cade_validation}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lc}", "\\toprule",
    "\\midrule",
    sprintf("CADE cartel convictions (procurement, 2009--2019) & %s \\\\",
            pfmt_int(nrow(cade_cartels))),
    sprintf("CADE firms matched to BEC & %s \\\\", pfmt_int(nrow(cade_match))),
    sprintf("FL firms co-bidding with CADE cartelists & %s \\\\", pfmt_int(nrow(cade_fl))),
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} CADE = Brazilian Competition Authority.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(cade_lines, file.path(OUT_TAB, "tab_cade_validation.tex"))
  cat("  Saved: tab_cade_validation.tex\n")
}

# ============================================================================
# Table 10: Regime test (dispersion)
# ============================================================================

cat("  Table 10: Regime test...\n")

if (!is.null(models$dispersion) && length(models$dispersion) > 0) {
  regime_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Regime Test: Bid Dispersion by Bidder Type}",
    "\\label{tab:regime_test}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcc}", "\\toprule",
    "Dispersion measure & Cover bidder coef. & SE \\\\", "\\midrule"
  )

  # Total dispersion
  if (!is.null(models$dispersion$total)) {
    m <- models$dispersion$total$general
    b <- coef(m)["losers"]; se <- sqrt(vcov(m)["losers", "losers"])
    p <- 2 * pnorm(-abs(b/se))
    regime_lines <- c(regime_lines, sprintf(
      "Total bid dispersion (log SD) & %s%s & (%s) \\\\",
      pfmt(b, 4), pstars(p), pfmt(se, 4)))
  }

  # FL dispersion
  if (!is.null(models$dispersion$fl)) {
    m <- models$dispersion$fl
    b <- coef(m)["cover_tender"]; se <- sqrt(vcov(m)["cover_tender", "cover_tender"])
    p <- 2 * pnorm(-abs(b/se))
    regime_lines <- c(regime_lines, sprintf(
      "FL bid dispersion (log IQR/median) & %s%s & (%s) \\\\",
      pfmt(b, 4), pstars(p), pfmt(se, 4)))
  }

  # Non-FL dispersion
  if (!is.null(models$dispersion$nonfl)) {
    m <- models$dispersion$nonfl
    b <- coef(m)["cover_tender"]; se <- sqrt(vcov(m)["cover_tender", "cover_tender"])
    p <- 2 * pnorm(-abs(b/se))
    regime_lines <- c(regime_lines, sprintf(
      "Non-FL bid dispersion (log IQR/median) & %s%s & (%s) \\\\",
      pfmt(b, 4), pstars(p), pfmt(se, 4)))
  }

  regime_lines <- c(regime_lines, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} If FL dispersion $>$ non-FL dispersion $\\Rightarrow$ Regime 1 (complementary).",
    "If FL dispersion $<$ non-FL dispersion $\\Rightarrow$ Regime 2 (coordinated).",
    "Item and year FE. SE clustered at item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(regime_lines, file.path(OUT_TAB, "tab_regime_test.tex"))
  cat("  Saved: tab_regime_test.tex\n")
}

cat("  All tables generated.\n")
