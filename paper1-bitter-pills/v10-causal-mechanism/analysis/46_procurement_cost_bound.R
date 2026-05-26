# Layer 2 / Track H --- Fiscal procurement-cost bound.
#
# Applies the bounded UTG price gap to a calibrated admissible share of
# annual litigated spending. This is a fiscal procurement-cost implication,
# not a full social-welfare estimate.
#
# Inputs:
#   - bounded UTG point: Lee midpoint of [BPutgBoundLow, BPutgBoundHigh]
#   - bounded UTG CI: Lee bound endpoints (Manski-Lee gives a partial
#     identification interval, not a CI; we report the endpoint range as
#     the bound and add the wild-bootstrap CI as the statistical-uncertainty
#     overlay)
#   - admissibility share: share of litigated spending the SES/SP scientific
#     committee would conceivably accept into the admin channel under
#     expanded capacity. v7 used 50% as a calibration anchor. v8 keeps the
#     same anchor but reports the implication with explicit dependence on
#     the anchor.
#   - annual litigated spend: $300 M (CNJ/INSPER 2019)
#
# Output:
#   - tab_procurement_cost_bound.tex
#   - tab_procurement_cost_sensitivity.tex
#   - tab_procurement_cost_spending_sensitivity.tex
#   - macros: BPprocCostBound, BPprocCostBoundCIlow, BPprocCostBoundCIhigh,
#             BPsanctionExposedSharePref

suppressPackageStartupMessages({
  library(data.table)
})

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "_macros.R"))
bp_set_threads(12L)

OUT  <- file.path(.this_dir, "..", "output")
LOGS <- file.path(.this_dir, "..", "logs")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)
LOG  <- file.path(LOGS, "46_procurement_cost_bound.log")
writeLines(sprintf("# 46_procurement_cost_bound | start=%s", Sys.time()), LOG)

t0 <- Sys.time()

# Bounded UTG numbers come from the values.tex macros written by
# 40_utg_lee_bounds.R (utgBoundLow/High, utgPointNaive). read_macro() below
# errors if a macro is missing, which also enforces that 40 ran first.
read_macro <- function(name, file = file.path(.this_dir, "..", "manuscript",
                                              "paper", "values.tex")) {
  lines <- readLines(file)
  pat <- sprintf("\\\\renewcommand\\{\\\\BP%s\\}\\{(.+?)\\}", name)
  m <- regmatches(lines, regexec(pat, lines))
  hits <- vapply(m, function(x) if (length(x) >= 2) x[2] else NA_character_,
                 character(1))
  hits <- hits[!is.na(hits)]
  if (!length(hits)) stop(sprintf("Macro %s not found in %s.", name, file))
  tail(hits, 1)
}

parse_pct <- function(s) {
  num <- gsub("[^0-9.\\-]", "", gsub("\\\\%", "", s))
  as.numeric(num)
}

utg_low_pct  <- parse_pct(read_macro("utgBoundLow"))   # 15.9
utg_high_pct <- parse_pct(read_macro("utgBoundHigh"))  # 21.1
utg_naive    <- parse_pct(read_macro("utgPointNaive")) # 29.5

# wild-bootstrap CI on the naive UTG, in log points -> percent (lit over admin)
boo_lo_log <- as.numeric(read_macro("utgBoottestCIlow"))
boo_hi_log <- as.numeric(read_macro("utgBoottestCIhigh"))
# Convert to lit-over-admin pct: coef is on Admin (admin=1), so lit-over-admin
# pct = (exp(-coef) - 1) * 100. The CI flips when negating.
boo_pct_lo <- (exp(-boo_hi_log) - 1) * 100
boo_pct_hi <- (exp(-boo_lo_log) - 1) * 100
cat(sprintf("Naive UTG bootstrap CI in pct: [%.2f%%, %.2f%%]\n", boo_pct_lo, boo_pct_hi))

# Anchors
SPEND_USD_M_TOT  <- 300       # annual litigated spending in SP, $M
ADMISSIBILITY    <- 0.50      # share of litigated cases admissible to admin (calibration)

# Procurement-cost implication = bounded UTG x admissibility x annual spend.
# Lee midpoint as point estimate; Lee endpoints as bounds.
utg_mid_pct <- (utg_low_pct + utg_high_pct) / 2
cost_point <- utg_mid_pct / 100 * ADMISSIBILITY * SPEND_USD_M_TOT
cost_lo    <- utg_low_pct  / 100 * ADMISSIBILITY * SPEND_USD_M_TOT
cost_hi    <- utg_high_pct / 100 * ADMISSIBILITY * SPEND_USD_M_TOT

cat(sprintf("Bounded UTG midpoint:        %.1f%%  (Lee bounds: [%.1f, %.1f])\n",
            utg_mid_pct, utg_low_pct, utg_high_pct))
cat(sprintf("Admissibility (calibration): %.0f%%\n", ADMISSIBILITY * 100))
cat(sprintf("Annual litigated spend:      $%d M\n", SPEND_USD_M_TOT))
cat(sprintf("Procurement-cost implication (point):       $%.1f M / year\n", cost_point))
cat(sprintf("Procurement-cost implication (Lee range):   [$%.1f M, $%.1f M] / year\n", cost_lo, cost_hi))

res <- data.table(
  row = c("Bounded UTG (Lee midpoint)",
          "Lee lower bound",
          "Lee upper bound",
          "Admissibility share (calibration)",
          "Annual litigated spend, SP",
          "Annual procurement-cost implication, midpoint",
          "Annual procurement-cost implication, lower",
          "Annual procurement-cost implication, upper"),
  value = c(sprintf("%.1f%%", utg_mid_pct),
            sprintf("%.1f%%", utg_low_pct),
            sprintf("%.1f%%", utg_high_pct),
            sprintf("%.0f%%", ADMISSIBILITY * 100),
            sprintf("$%d M / yr", SPEND_USD_M_TOT),
            sprintf("$%.1f M / yr", cost_point),
            sprintf("$%.1f M / yr", cost_lo),
            sprintf("$%.1f M / yr", cost_hi))
)
print(res)

bound_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Fiscal procurement-cost implication of the bounded UTG gap.}\n",
  "\\label{tab:procurement_cost_bound}\n",
  "\\begin{threeparttable}\n",
  "\\begin{tabular}{lr}\n",
  "\\toprule\n",
  "Component & Value \\\\\n",
  "\\midrule\n",
  "Lee midpoint & \\BPprocCostBoundUTGmidPct{} \\\\\n",
  "Lee lower bound & \\BPutgBoundLow{} \\\\\n",
  "Lee upper bound & \\BPutgBoundHigh{} \\\\\n",
  "Admissibility calibration & \\BPprocCostBoundAdmissibility{} \\\\\n",
  "Annual litigated spending & \\BPprocCostBoundAnnualSpend{} \\\\\n",
  "Annual procurement-cost implication, midpoint & \\BPprocCostBound{} \\\\\n",
  "Annual procurement-cost implication, lower & \\BPprocCostBoundCIlow{} \\\\\n",
  "Annual procurement-cost implication, upper & \\BPprocCostBoundCIhigh{} \\\\\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} This calculation is not a full welfare estimate. It applies the bounded price gap to a calibrated admissible share of litigated spending and excludes patient health benefits, search costs, and other welfare components. It should be read together with the main-paper sourcing decomposition.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(bound_tex, file.path(OUT, "tables", "tab_procurement_cost_bound.tex"))

sensitivity <- data.table(admissibility = c(0.25, 0.50, 0.75))
sensitivity[, `:=`(
  midpoint = utg_mid_pct / 100 * admissibility * SPEND_USD_M_TOT,
  lower = utg_low_pct / 100 * admissibility * SPEND_USD_M_TOT,
  upper = utg_high_pct / 100 * admissibility * SPEND_USD_M_TOT
)]
sensitivity_out <- sensitivity[, .(
  admissible = sprintf("%.0f\\%%", admissibility * 100),
  midpoint_s = sprintf("\\$%.1f M / yr", midpoint),
  lower_s = sprintf("\\$%.1f M / yr", lower),
  upper_s = sprintf("\\$%.1f M / yr", upper)
)]

sens_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Sensitivity of the annual procurement-cost implication to the admissibility calibration.}\n",
  "\\label{tab:procurement_cost_sensitivity}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\begin{tabular}{lccc}\n",
  "\\toprule\n",
  "Admissible share & Midpoint & Lee lower bound & Lee upper bound \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & %s & %s & %s \\\\",
                sensitivity_out$admissible,
                sensitivity_out$midpoint_s,
                sensitivity_out$lower_s,
                sensitivity_out$upper_s),
        collapse = "\n"),
  "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} Each row applies the bounded litigated-over-",
  "administrative price gap to annual litigated spending under the listed ",
  "admissible share. The middle row is the calibration used in ",
  "Table~\\ref{tab:procurement_cost_bound}. The table is a fiscal ",
  "procurement-cost sensitivity calculation, not a full welfare estimate.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(sens_tex, file.path(OUT, "tables", "tab_procurement_cost_sensitivity.tex"))

spending_sensitivity <- data.table(spend_usd_m = c(250, 300, 350))
spending_sensitivity[, `:=`(
  midpoint = utg_mid_pct / 100 * ADMISSIBILITY * spend_usd_m,
  lower = utg_low_pct / 100 * ADMISSIBILITY * spend_usd_m,
  upper = utg_high_pct / 100 * ADMISSIBILITY * spend_usd_m
)]
spending_out <- spending_sensitivity[, .(
  spend_s = sprintf("\\$%d M / yr", spend_usd_m),
  midpoint_s = sprintf("\\$%.1f M / yr", midpoint),
  lower_s = sprintf("\\$%.1f M / yr", lower),
  upper_s = sprintf("\\$%.1f M / yr", upper)
)]

spend_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Sensitivity of the annual procurement-cost implication to litigated spending.}\n",
  "\\label{tab:procurement_cost_spending_sensitivity}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\begin{tabular}{lccc}\n",
  "\\toprule\n",
  "Annual litigated spend & Midpoint & Lee lower bound & Lee upper bound \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & %s & %s & %s \\\\",
                spending_out$spend_s,
                spending_out$midpoint_s,
                spending_out$lower_s,
                spending_out$upper_s),
        collapse = "\n"),
  "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} Each row keeps the central admissibility calibration ",
  "fixed at ", bp_fmt_pct(ADMISSIBILITY * 100), " and varies only annual ",
  "litigated spending. The middle row is the spending anchor used in ",
  "Table~\\ref{tab:procurement_cost_bound}. The table is a fiscal ",
  "procurement-cost sensitivity calculation, not a full welfare estimate.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(spend_tex, file.path(OUT, "tables",
                                "tab_procurement_cost_spending_sensitivity.tex"))

bp_macros_emit("46_procurement_cost_bound", list(
  procCostBound             = sprintf("\\$%.1f~M", cost_point),
  procCostBoundCIlow        = sprintf("\\$%.1f~M", cost_lo),
  procCostBoundCIhigh       = sprintf("\\$%.1f~M", cost_hi),
  procCostBoundUTGmidPct    = bp_fmt_pct(utg_mid_pct),
  procCostBoundAdmissibility= bp_fmt_pct(ADMISSIBILITY * 100),
  procCostBoundAnnualSpend  = sprintf("\\$%d~M", SPEND_USD_M_TOT),
  sanctionExposedSharePref = bp_fmt_pct(ADMISSIBILITY * 100),
  procCostSensitivityNrows = bp_fmt_int(nrow(sensitivity_out)),
  procCostSpendSensitivityNrows = bp_fmt_int(nrow(spending_out))
))
bp_log_step("done", t0, LOG)
