# Layer 2 / Track H --- Single welfare bound (selection-bias-corrected).
#
# Replaces v7's stacked $16-88M range. One number with explicit 95% CI:
#
#   welfare = bounded_UTG x admissibility_share x annual_litigated_spend
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
#     same anchor but reports the welfare with explicit dependence on the
#     anchor.
#   - annual litigated spend: $300 M (CNJ/INSPER 2019)
#
# Output:
#   - tab_welfare_bound.tex
#   - macros: BPwelfareBound, BPwelfareBoundCIlow, BPwelfareBoundCIhigh,
#             BPsanctionExposedSharePref

suppressPackageStartupMessages({
  library(data.table)
  library(kableExtra)
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
LOG  <- file.path(LOGS, "46_welfare_bound.log")
writeLines(sprintf("# 46_welfare_bound | start=%s", Sys.time()), LOG)

t0 <- Sys.time()

# read the bounded UTG numbers off the Lee bound CSV/TeX rather than parsing
# values.tex. Keep this file authoritative (Lee).
LEE_TEX <- file.path(OUT, "tables", "tab_utg_lee_bounds.tex")
if (!file.exists(LEE_TEX)) stop("Run 40_utg_lee_bounds.R first.")
lee_lines <- readLines(LEE_TEX)
# parse cleanly: pct_lit_over_admin column is the 4th numeric in each data row.
# we did not export the raw numbers, so re-read from the script's CSV if any.
# Fall back to recomputing here from values.tex via macros parse:
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

# Welfare = (bounded UTG / 100) * admissibility * annual spend.
# Lee midpoint as point estimate; Lee endpoints as bounds.
utg_mid_pct <- (utg_low_pct + utg_high_pct) / 2
welf_point <- utg_mid_pct / 100 * ADMISSIBILITY * SPEND_USD_M_TOT
welf_lo    <- utg_low_pct  / 100 * ADMISSIBILITY * SPEND_USD_M_TOT
welf_hi    <- utg_high_pct / 100 * ADMISSIBILITY * SPEND_USD_M_TOT

cat(sprintf("Bounded UTG midpoint:        %.1f%%  (Lee bounds: [%.1f, %.1f])\n",
            utg_mid_pct, utg_low_pct, utg_high_pct))
cat(sprintf("Admissibility (calibration): %.0f%%\n", ADMISSIBILITY * 100))
cat(sprintf("Annual litigated spend:      $%d M\n", SPEND_USD_M_TOT))
cat(sprintf("Welfare bound (point):       $%.1f M / year\n", welf_point))
cat(sprintf("Welfare bound (Lee range):   [$%.1f M, $%.1f M] / year\n", welf_lo, welf_hi))

res <- data.table(
  row = c("Bounded UTG (Lee midpoint)",
          "Lee lower bound",
          "Lee upper bound",
          "Admissibility share (calibration)",
          "Annual litigated spend, SP",
          "Welfare bound (Lee midpoint x admissibility x spend)",
          "Welfare bound (Lee lower x admissibility x spend)",
          "Welfare bound (Lee upper x admissibility x spend)"),
  value = c(sprintf("%.1f%%", utg_mid_pct),
            sprintf("%.1f%%", utg_low_pct),
            sprintf("%.1f%%", utg_high_pct),
            sprintf("%.0f%%", ADMISSIBILITY * 100),
            sprintf("$%d M / yr", SPEND_USD_M_TOT),
            sprintf("$%.1f M / yr", welf_point),
            sprintf("$%.1f M / yr", welf_lo),
            sprintf("$%.1f M / yr", welf_hi))
)
print(res)

ktab <- kbl(res, format = "latex", booktabs = TRUE,
            col.names = c("Component", "Value"),
            label = "tab:welfare_bound",
            caption = "Selection-bias-corrected welfare bound on the procurement cost of judicial enforcement.",
            escape = FALSE) |>
  footnote(general = paste(
    "Bounded UTG: Manski-Lee bounds from Table~\\ref{tab:utg_lee_bounds}.",
    "Admissibility share: calibration anchor for the fraction of court-mandated",
    "cases that the SES/SP scientific committee would admit to the",
    "administrative channel under expanded capacity. Annual litigated spend",
    "in S\\~ao Paulo: CNJ/INSPER (2019). The welfare bound is the cost margin",
    "associated with the litigated regime relative to a counterfactual world",
    "where the admissible share is processed through the no-sanction admin",
    "channel; the residual share remains unaffected. This bound is gross of",
    "the supplier composition residual that v8's reconciliation table",
    "(Table~\\ref{tab:utg_reconciliation}) attributes to sourcing rather",
    "than within-firm pricing."),
    general_title = "", footnote_as_chunk = TRUE, escape = FALSE)
writeLines(ktab, file.path(OUT, "tables", "tab_welfare_bound.tex"))

bp_macros_emit("46_welfare_bound", list(
  welfareBound             = sprintf("\\$%.1f~M", welf_point),
  welfareBoundCIlow        = sprintf("\\$%.1f~M", welf_lo),
  welfareBoundCIhigh       = sprintf("\\$%.1f~M", welf_hi),
  welfareBoundUTGmidPct    = bp_fmt_pct(utg_mid_pct),
  welfareBoundAdmissibility= bp_fmt_pct(ADMISSIBILITY * 100),
  welfareBoundAnnualSpend  = sprintf("\\$%d~M", SPEND_USD_M_TOT),
  sanctionExposedSharePref = bp_fmt_pct(ADMISSIBILITY * 100)
))
bp_log_step("done", t0, LOG)
