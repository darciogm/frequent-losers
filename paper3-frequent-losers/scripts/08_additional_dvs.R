# ============================================================================
# 08_additional_dvs.R — New dependent variables and balancing table
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================
# 8.1 Bid dispersion (log_bid_sd) — key cartel test
# 8.2 Price ratio (price_ratio) — efficiency
# 8.3 Procedure duration (log_proc_hours)
# 8.4 Balancing table
# ============================================================================

cat("=== 08_additional_dvs.R: Additional dependent variables ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ============================================================================
# 8.1 Bid dispersion (key cartel test)
# ============================================================================
# Prediction: cartel → LOWER bid dispersion (coordinated bids)

cat("  8.1 Bid dispersion regressions...\n")

d_sd <- dt[!is.na(log_bid_sd)]
cat(sprintf("    Valid log_bid_sd: %s rows\n", pfmt_int(nrow(d_sd))))

if (nrow(d_sd) > 100) {
  m_sd <- run_losers_4("log_bid_sd", d_sd, price_only = FALSE)

  # --- Bid dispersion table ---
  cat("  Writing tab_bid_dispersion.tex...\n")

  # Reuse the same table format as main results
  sd_lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Bid Price Dispersion (log SD): With vs.\\ Without Frequent Losers}",
    "\\label{tab:bid_dispersion}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & (1) & (2) & (3) & (4) \\\\",
    " & General & General & Preg\\~{a}o & Convite \\\\",
    "\\midrule"
  )

  m_order <- c("general", "general_pbu", "pregao", "convite")

  # Losers coefficient
  coefs <- sapply(m_order, function(n) {
    m <- m_sd[[n]]
    if (!is.null(m) && "losers" %in% names(coef(m))) coef_cell(m, "losers") else "---"
  })
  ses <- sapply(m_order, function(n) {
    m <- m_sd[[n]]
    if (!is.null(m) && "losers" %in% names(coef(m))) se_cell(m, "losers") else ""
  })
  sd_lines <- c(sd_lines,
    sprintf("losers & %s \\\\", paste(coefs, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & "))
  )

  # Convite coefficient (only in general specs)
  coefs_c <- sapply(m_order, function(n) {
    m <- m_sd[[n]]
    if (!is.null(m) && "convite" %in% names(coef(m))) coef_cell(m, "convite") else ""
  })
  ses_c <- sapply(m_order, function(n) {
    m <- m_sd[[n]]
    if (!is.null(m) && "convite" %in% names(coef(m))) se_cell(m, "convite") else ""
  })
  sd_lines <- c(sd_lines,
    sprintf("convite & %s \\\\", paste(coefs_c, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses_c, collapse = " & "))
  )

  sd_lines <- c(sd_lines, "\\midrule")

  # Observations
  obs <- sapply(m_order, function(n) {
    m <- m_sd[[n]]
    if (!is.null(m)) pfmt_int(m$nobs) else "---"
  })
  r2 <- sapply(m_order, function(n) {
    m <- m_sd[[n]]
    if (!is.null(m)) pfmt(fitstat(m, "r2")[[1]], 4) else "---"
  })

  sd_lines <- c(sd_lines,
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    sprintf("R-squared & %s \\\\", paste(r2, collapse = " & ")),
    "Item Dummies & YES & YES & YES & YES \\\\",
    "Year Dummies & YES & YES & YES & YES \\\\",
    "PBU Dummies & NO & YES & YES & YES \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} Dependent variable: log of bid price standard deviation.",
    "A negative coefficient indicates lower bid dispersion (more coordinated bids)",
    "in tenders with frequent losers, consistent with cartel behavior.",
    "Standard errors clustered at the item level in parentheses.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(sd_lines, file.path(OUT_TAB, "tab_bid_dispersion.tex"))
} else {
  cat("    Too few observations for bid dispersion. Skipped.\n")
  m_sd <- NULL
}

# ============================================================================
# 8.2 Price ratio (efficiency)
# ============================================================================

cat("  8.2 Price ratio regressions...\n")

d_pr <- dt[!is.na(price_ratio)]
cat(sprintf("    Valid price_ratio: %s rows\n", pfmt_int(nrow(d_pr))))

m_pr <- NULL
if (nrow(d_pr) > 100) {
  m_pr <- run_losers_4("price_ratio", d_pr, price_only = FALSE)
}

# ============================================================================
# 8.3 Procedure duration
# ============================================================================

cat("  8.3 Procedure duration regressions...\n")

d_dur <- dt[!is.na(log_proc_hours)]
cat(sprintf("    Valid log_proc_hours: %s rows\n", pfmt_int(nrow(d_dur))))

m_dur <- NULL
if (nrow(d_dur) > 100) {
  m_dur <- run_losers_4("log_proc_hours", d_dur, price_only = FALSE)
}

# ============================================================================
# Additional DVs summary table
# ============================================================================

cat("  Writing tab_additional_dvs.tex...\n")

adv_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Additional Dependent Variables}",
  "\\label{tab:additional_dvs}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & (1) & (2) & (3) & (4) \\\\",
  " & General & General+PBU & Preg\\~{a}o & Convite \\\\",
  "\\midrule",
  "\\textit{Panel A: Bid Dispersion (log SD)} & & & & \\\\"
)

m_order <- c("general", "general_pbu", "pregao", "convite")

# Panel A: Bid dispersion
if (!is.null(m_sd)) {
  coefs <- sapply(m_order, function(n) coef_cell(m_sd[[n]], "losers"))
  ses   <- sapply(m_order, function(n) se_cell(m_sd[[n]], "losers"))
  obs_a <- sapply(m_order, function(n) pfmt_int(m_sd[[n]]$nobs))
  adv_lines <- c(adv_lines,
    sprintf("\\quad losers & %s \\\\", paste(coefs, collapse = " & ")),
    sprintf("\\quad & %s \\\\", paste(ses, collapse = " & ")),
    sprintf("\\quad N & %s \\\\", paste(obs_a, collapse = " & "))
  )
} else {
  adv_lines <- c(adv_lines, "\\quad \\multicolumn{4}{c}{Insufficient data} \\\\")
}

adv_lines <- c(adv_lines,
  "[6pt]",
  "\\textit{Panel B: Price Ratio (log negot/ref)} & & & & \\\\"
)

# Panel B: Price ratio
if (!is.null(m_pr)) {
  coefs <- sapply(m_order, function(n) coef_cell(m_pr[[n]], "losers"))
  ses   <- sapply(m_order, function(n) se_cell(m_pr[[n]], "losers"))
  obs_b <- sapply(m_order, function(n) pfmt_int(m_pr[[n]]$nobs))
  adv_lines <- c(adv_lines,
    sprintf("\\quad losers & %s \\\\", paste(coefs, collapse = " & ")),
    sprintf("\\quad & %s \\\\", paste(ses, collapse = " & ")),
    sprintf("\\quad N & %s \\\\", paste(obs_b, collapse = " & "))
  )
} else {
  adv_lines <- c(adv_lines, "\\quad \\multicolumn{4}{c}{Insufficient data} \\\\")
}

adv_lines <- c(adv_lines,
  "[6pt]",
  "\\textit{Panel C: Procedure Duration (log hours)} & & & & \\\\"
)

# Panel C: Duration
if (!is.null(m_dur)) {
  coefs <- sapply(m_order, function(n) coef_cell(m_dur[[n]], "losers"))
  ses   <- sapply(m_order, function(n) se_cell(m_dur[[n]], "losers"))
  obs_c <- sapply(m_order, function(n) pfmt_int(m_dur[[n]]$nobs))
  adv_lines <- c(adv_lines,
    sprintf("\\quad losers & %s \\\\", paste(coefs, collapse = " & ")),
    sprintf("\\quad & %s \\\\", paste(ses, collapse = " & ")),
    sprintf("\\quad N & %s \\\\", paste(obs_c, collapse = " & "))
  )
} else {
  adv_lines <- c(adv_lines, "\\quad \\multicolumn{4}{c}{Insufficient data} \\\\")
}

adv_lines <- c(adv_lines,
  "\\midrule",
  "Item FE & YES & YES & YES & YES \\\\",
  "Year FE & YES & YES & YES & YES \\\\",
  "PBU FE & NO & YES & YES & YES \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Each panel reports the coefficient on \\textit{losers}",
  "for a different dependent variable. Standard errors clustered at the item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(adv_lines, file.path(OUT_TAB, "tab_additional_dvs.tex"))

# ============================================================================
# 8.4 Balancing table
# ============================================================================

cat("  8.4 Balancing table...\n")

bal_vars <- list(
  list(name = "n_firms",              label = "Number of firms",         fmt = 2),
  list(name = "n_bids",               label = "Number of bids",          fmt = 2),
  list(name = "bid_ref_price_min",    label = "Reference price (min)",   fmt = 2),
  list(name = "proc_length_hours",    label = "Procedure duration (h)",  fmt = 2),
  list(name = "convite",              label = "Convite share",           fmt = 3)
)

bal_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Balancing Table: Tenders With vs.\\ Without Frequent Losers}",
  "\\label{tab:balance}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{With FL} & \\multicolumn{2}{c}{Without FL} & Diff. & Norm. \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  " & Mean & SD & Mean & SD & (p-val) & Diff. \\\\",
  "\\midrule"
)

for (v in bal_vars) {
  x1 <- dt[losers == 1][[v$name]]
  x0 <- dt[losers == 0][[v$name]]
  x1 <- x1[!is.na(x1)]
  x0 <- x0[!is.na(x0)]

  m1 <- mean(x1); s1 <- sd(x1)
  m0 <- mean(x0); s0 <- sd(x0)

  # Normalized difference: (m1 - m0) / sqrt(s1^2 + s0^2)
  norm_diff <- (m1 - m0) / sqrt(s1^2 + s0^2)

  # t-test p-value
  tt <- tryCatch(t.test(x1, x0)$p.value, error = function(e) NA)
  p_str <- if (!is.na(tt)) sprintf("%.3f", tt) else "---"

  bal_lines <- c(bal_lines, sprintf(
    "%s & %s & %s & %s & %s & %s & %s \\\\",
    v$label,
    pfmt(m1, v$fmt), pfmt(s1, v$fmt),
    pfmt(m0, v$fmt), pfmt(s0, v$fmt),
    p_str, pfmt(norm_diff, 3)
  ))
}

bal_lines <- c(bal_lines,
  "\\midrule",
  sprintf("N (with FL) & \\multicolumn{6}{c}{%s} \\\\", pfmt_int(dt[losers == 1, .N])),
  sprintf("N (without FL) & \\multicolumn{6}{c}{%s} \\\\", pfmt_int(dt[losers == 0, .N])),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} FL = Frequent Losers. Normalized difference:",
  "$(\\bar{x}_1 - \\bar{x}_0) / \\sqrt{s_1^2 + s_0^2}$.",
  "Values $>$ 0.25 indicate meaningful imbalance \\citep{imbens2015causal}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(bal_lines, file.path(OUT_TAB, "tab_balance.tex"))

# ---- Save models -----------------------------------------------------------
addl_models <- list(
  bid_dispersion = m_sd,
  price_ratio    = m_pr,
  duration       = m_dur
)
saveRDS(addl_models, "/tmp/p3_additional_dvs.rds")
cat("  Additional DV models saved: /tmp/p3_additional_dvs.rds\n")
cat("  Done.\n")
