# ============================================================================
# 11_welfare.R — Welfare analysis: back-of-envelope markup estimates
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Welfare loss = (exp(β) - 1) × Σ(winning_price where cover_tender = 1)
# Uses 95% CI from main regression for bounds
# Benchmarks against OECD (2010) and Connor & Lande (2006)
# ============================================================================

cat("=== 11_welfare.R: Welfare analysis ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data and models ----------------------------------------------------
if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)

if (!file.exists(MODELS_CACHE_V2)) stop("Run 06_main_regressions.R first")
models <- readRDS(MODELS_CACHE_V2)

# ---- Extract main price coefficient and CI -----------------------------------
# Use general + PBU FE specification (column 2)
m_price <- models$prices$general_pbu
b  <- coef(m_price)["losers"]
se <- sqrt(vcov(m_price)["losers", "losers"])
ci_lo <- b - 1.96 * se
ci_hi <- b + 1.96 * se

cat(sprintf("  Main price coefficient: %.4f (SE: %.4f)\n", b, se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n", ci_lo, ci_hi))

# ---- Compute markup in percentage terms --------------------------------------
# β is in log-points: markup = exp(β) - 1
markup_pct     <- (exp(b) - 1) * 100
markup_pct_lo  <- (exp(ci_lo) - 1) * 100
markup_pct_hi  <- (exp(ci_hi) - 1) * 100

cat(sprintf("  Implied markup: %.2f%% [%.2f%%, %.2f%%]\n",
            markup_pct, markup_pct_lo, markup_pct_hi))

# ---- Compute total welfare loss ----------------------------------------------
cat("  Computing welfare loss...\n")

# Sum of winning prices in FL-present tenders
d_fl <- dt[losers == 1 & !is.na(bid_unit_price_negot_min) & bid_unit_price_negot_min > 0]
total_price_fl <- sum(d_fl$bid_unit_price_negot_min)
n_fl_tenders   <- nrow(d_fl)

cat(sprintf("  FL-present tenders with valid prices: %s\n", pfmt_int(n_fl_tenders)))
cat(sprintf("  Total winning prices (FL tenders): R$ %s\n",
            formatC(total_price_fl, format = "f", digits = 0, big.mark = ",")))

# Welfare loss = markup_fraction × total_price
welfare_loss    <- (exp(b) - 1) * total_price_fl
welfare_loss_lo <- (exp(ci_lo) - 1) * total_price_fl
welfare_loss_hi <- (exp(ci_hi) - 1) * total_price_fl

cat(sprintf("\n  WELFARE LOSS (back-of-envelope):\n"))
cat(sprintf("  Point estimate: R$ %s\n",
            formatC(welfare_loss, format = "f", digits = 0, big.mark = ",")))
cat(sprintf("  95%% CI: [R$ %s, R$ %s]\n",
            formatC(welfare_loss_lo, format = "f", digits = 0, big.mark = ","),
            formatC(welfare_loss_hi, format = "f", digits = 0, big.mark = ",")))

# In USD (approximate: 1 BRL ≈ 0.20 USD average 2009-2019)
brl_usd <- 0.20
cat(sprintf("  In USD (approx): $%s [$%s, $%s]\n",
            formatC(welfare_loss * brl_usd, format = "f", digits = 0, big.mark = ","),
            formatC(welfare_loss_lo * brl_usd, format = "f", digits = 0, big.mark = ","),
            formatC(welfare_loss_hi * brl_usd, format = "f", digits = 0, big.mark = ",")))

# ---- Benchmarks --------------------------------------------------------------
cat("\n  Benchmarks:\n")
cat("  OECD (2010): cartel markups typically 15-40% in procurement\n")
cat("  Connor & Lande (2006): median cartel overcharge ~25%\n")
cat(sprintf("  Our estimate: %.1f%% — %s OECD benchmark range\n",
            markup_pct,
            if (markup_pct < 15) "below" else if (markup_pct <= 40) "within" else "above"))

# Per-tender average
avg_price_fl <- mean(d_fl$bid_unit_price_negot_min)
avg_markup   <- (exp(b) - 1) * avg_price_fl
cat(sprintf("  Average per-tender markup: R$ %s\n",
            formatC(avg_markup, format = "f", digits = 2, big.mark = ",")))

# ---- Per-year breakdown ------------------------------------------------------
cat("\n  Year-by-year welfare loss:\n")
year_loss <- d_fl[, .(
  total_price = sum(bid_unit_price_negot_min),
  n_tenders = .N
), by = year][order(year)]
year_loss[, welfare_loss := (exp(b) - 1) * total_price]

for (i in seq_len(nrow(year_loss))) {
  cat(sprintf("    %d: %s tenders, loss = R$ %s\n",
              year_loss$year[i], pfmt_int(year_loss$n_tenders[i]),
              formatC(year_loss$welfare_loss[i], format = "f", digits = 0, big.mark = ",")))
}

# ============================================================================
# Write welfare table
# ============================================================================

cat("  Writing tab_welfare.tex...\n")

wf_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Welfare Loss Estimates from Cover Bidding}",
  "\\label{tab:welfare}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lc}",
  "\\toprule",
  "\\midrule",
  sprintf("Price coefficient ($\\hat{\\beta}$) & %s \\\\", pfmt(b, 4)),
  sprintf("Standard error & (%s) \\\\", pfmt(se, 4)),
  sprintf("Implied markup (\\%%) & %.2f\\%% \\\\", markup_pct),
  sprintf("95\\%% CI & [%.2f\\%%, %.2f\\%%] \\\\", markup_pct_lo, markup_pct_hi),
  "\\midrule",
  sprintf("FL-present tenders & %s \\\\", pfmt_int(n_fl_tenders)),
  sprintf("Total winning prices (R\\$) & %s \\\\",
          formatC(total_price_fl, format = "f", digits = 0, big.mark = ",")),
  "\\midrule",
  sprintf("\\textbf{Total welfare loss (R\\$)} & \\textbf{%s} \\\\",
          formatC(welfare_loss, format = "f", digits = 0, big.mark = ",")),
  sprintf("95\\%% CI (R\\$) & [%s, %s] \\\\",
          formatC(welfare_loss_lo, format = "f", digits = 0, big.mark = ","),
          formatC(welfare_loss_hi, format = "f", digits = 0, big.mark = ",")),
  sprintf("Total welfare loss (USD, approx) & \\$%s \\\\",
          formatC(welfare_loss * brl_usd, format = "f", digits = 0, big.mark = ",")),
  "\\midrule",
  "\\textit{Benchmarks} & \\\\",
  "OECD (2010) range & 15--40\\% \\\\",
  "Connor \\& Lande (2006) median & 25\\% \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Markup = $\\exp(\\hat{\\beta}) - 1$.",
  "Welfare loss = markup $\\times$ sum of winning prices in FL-present tenders.",
  "USD conversion at approximate average rate R\\$1 = US\\$0.20 (2009--2019).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(wf_lines, file.path(OUT_TAB, "tab_welfare.tex"))

# ---- Save results ------------------------------------------------------------
welfare_results <- list(
  coef = b, se = se, ci = c(ci_lo, ci_hi),
  markup_pct = markup_pct,
  total_price_fl = total_price_fl,
  n_fl_tenders = n_fl_tenders,
  welfare_loss = welfare_loss,
  welfare_ci = c(welfare_loss_lo, welfare_loss_hi),
  year_breakdown = year_loss
)
saveRDS(welfare_results, "/tmp/p3v2_welfare.rds")
cat("  Welfare results saved: /tmp/p3v2_welfare.rds\n")
cat("  Done.\n")
