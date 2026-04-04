# ============================================================================
# task1b_horse_race_r2.R — Marginal R² for horse-race regression
# Addresses Concern 8: horse-race needs marginal R², not just coefficients
# ============================================================================
# Computes three feols models:
#   (1) FL only
#   (2) Imhof CV flag only
#   (3) Both FL + Imhof CV flag
# Reports within-R² and marginal contributions.
# Updates tab_horse_race.tex with R² rows.
# ============================================================================

cat("=== task1b_horse_race_r2.R: Marginal R² for horse-race ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# Load prepared data
if (!file.exists(DATA_CACHE_V4)) stop("DATA_CACHE_V4 not found. Run 01_data_prep.R first.")
dt <- readRDS(DATA_CACHE_V4)
cat("  Data loaded:", pfmt_int(nrow(dt)), "rows\n")

# ---- Construct Imhof CV flag ------------------------------------------------
# The Imhof CV flag equals 1 if the tender-level bid CV exceeds the
# item-group median CV (same definition as v5_fix_horserace.R).
# This varies WITHIN items (different tenders have different CVs).

d_price <- dt[!is.na(lneg_price)]

# Load tender-level bid stats from BEC
bec <- as.data.table(read_parquet(
  file.path(DATA_V1, "BEC_collapse_final.parquet"),
  col_select = c("po_item_merge_key", "bid_price_sd", "bid_price_mean")))
d_price <- merge(d_price,
  bec[, .(po_item_merge_key, bec_sd = bid_price_sd, bec_mean = bid_price_mean)],
  by = "po_item_merge_key", all.x = TRUE)
rm(bec); gc(verbose = FALSE)

# Tender-level CV
d_price[, cv_bids := fifelse(
  bec_sd > 0 & bec_mean > 0 & !is.na(bec_sd) & !is.na(bec_mean),
  bec_sd / bec_mean, NA_real_)]

# Item-group median split (each tender compared to its group median)
cv_med <- d_price[!is.na(cv_bids), .(cv_median = median(cv_bids)), by = item_group]
d_price <- merge(d_price, cv_med, by = "item_group", all.x = TRUE)
d_price[, imhof_cv_flag := as.integer(!is.na(cv_bids) & cv_bids > cv_median)]

cat(sprintf("  Imhof CV flag prevalence: %.1f%%\n",
            100 * mean(d_price$imhof_cv_flag)))
cat(sprintf("  FL prevalence: %.1f%%\n", 100 * mean(d_price$losers)))

# Correlation
r <- cor(d_price$losers, d_price$imhof_cv_flag, use = "complete.obs")
cat(sprintf("  Correlation(FL, Imhof): %.3f\n", r))

# ---- Three models -----------------------------------------------------------

cat("  Running horse-race models...\n")

# Model 1: FL only
m_fl <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
              data = d_price, cluster = ~item_f, fixef.rm = "none")

# Model 2: Imhof only
m_imhof <- feols(lneg_price ~ imhof_cv_flag + convite | item_f + year_f + pbu_f,
                 data = d_price, cluster = ~item_f, fixef.rm = "none")

# Model 3: Both
m_both <- feols(lneg_price ~ losers + imhof_cv_flag + convite | item_f + year_f + pbu_f,
                data = d_price, cluster = ~item_f, fixef.rm = "none")

# ---- Extract R² -------------------------------------------------------------

r2_fl    <- fitstat(m_fl, "r2")$r2
r2_imhof <- fitstat(m_imhof, "r2")$r2
r2_both  <- fitstat(m_both, "r2")$r2

# Within-R² (if available)
wr2_fl    <- fitstat(m_fl, "wr2")$wr2
wr2_imhof <- fitstat(m_imhof, "wr2")$wr2
wr2_both  <- fitstat(m_both, "wr2")$wr2

# Marginal R² contributions
dr2_fl_given_imhof <- r2_both - r2_imhof
dr2_imhof_given_fl <- r2_both - r2_fl

cat(sprintf("\n  R² results:\n"))
cat(sprintf("    FL only:     R²=%.6f  within-R²=%.6f\n", r2_fl, wr2_fl))
cat(sprintf("    Imhof only:  R²=%.6f  within-R²=%.6f\n", r2_imhof, wr2_imhof))
cat(sprintf("    Both:        R²=%.6f  within-R²=%.6f\n", r2_both, wr2_both))
cat(sprintf("    ΔR²(FL|Imhof):     %.6f\n", dr2_fl_given_imhof))
cat(sprintf("    ΔR²(Imhof|FL):     %.6f\n", dr2_imhof_given_fl))

# ---- Coefficients -----------------------------------------------------------

cat(sprintf("\n  Coefficients:\n"))
cat(sprintf("    FL (alone):      %.4f (SE %.4f)\n", coef(m_fl)["losers"],
            sqrt(vcov(m_fl)["losers","losers"])))
cat(sprintf("    FL (with Imhof): %.4f (SE %.4f)\n", coef(m_both)["losers"],
            sqrt(vcov(m_both)["losers","losers"])))
cat(sprintf("    Imhof (alone):      %.4f (SE %.4f)\n", coef(m_imhof)["imhof_cv_flag"],
            sqrt(vcov(m_imhof)["imhof_cv_flag","imhof_cv_flag"])))
cat(sprintf("    Imhof (with FL): %.4f (SE %.4f)\n", coef(m_both)["imhof_cv_flag"],
            sqrt(vcov(m_both)["imhof_cv_flag","imhof_cv_flag"])))

# ---- Write updated table ----------------------------------------------------

cat("  Writing updated tab_horse_race.tex...\n")

pstars_local <- function(p) {
  if (p < 0.01) "***" else if (p < 0.05) "**" else if (p < 0.1) "*" else ""
}

coef_fmt <- function(m, var) {
  b <- coef(m)[var]; se <- sqrt(vcov(m)[var, var])
  p <- 2 * pnorm(-abs(b / se))
  list(val = sprintf("%.3f%s", b, pstars_local(p)),
       se = sprintf("(%.3f)", se))
}

fl1 <- coef_fmt(m_fl, "losers")
fl3 <- coef_fmt(m_both, "losers")
im2 <- coef_fmt(m_imhof, "imhof_cv_flag")
im3 <- coef_fmt(m_both, "imhof_cv_flag")

tex <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Horse-Race Regression: FL Screen vs.\\ Imhof CV Flag}",
  "\\label{tab:horse_race}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}", "\\toprule",
  " & (1) FL only & (2) Imhof only & (3) Both \\\\",
  "\\midrule",
  sprintf("FL presence & %s &  & %s \\\\", fl1$val, fl3$val),
  sprintf(" & %s &  & %s \\\\", fl1$se, fl3$se),
  sprintf("Imhof CV flag &  & %s & %s \\\\", im2$val, im3$val),
  sprintf(" &  & %s & %s \\\\", im2$se, im3$se),
  "\\midrule",
  sprintf("R-squared & %.4f & %.4f & %.4f \\\\", r2_fl, r2_imhof, r2_both),
  sprintf("$\\Delta R^2$ (marginal) & %.1e & %.1e & --- \\\\",
          dr2_fl_given_imhof, dr2_imhof_given_fl),
  "Item + Year + PBU FE & YES & YES & YES \\\\",
  sprintf("Observations & %s & %s & %s \\\\",
          pfmt_int(m_fl$nobs), pfmt_int(m_imhof$nobs), pfmt_int(m_both$nobs)),
  sprintf("Correlation(FL, Imhof) & \\multicolumn{3}{c}{%.3f} \\\\", r),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} DV: log negotiated price. Imhof CV flag equals one",
  "if the within-item-group coefficient of variation exceeds the median.",
  "$\\Delta R^2$ reports the marginal R-squared contribution of each screen",
  "relative to the model containing only the other screen.",
  "SE clustered at item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")

writeLines(tex, file.path(OUT_TAB, "tab_horse_race.tex"))
cat("  Saved: tab_horse_race.tex\n")

# Save results
horse_race_results <- list(
  m_fl = m_fl, m_imhof = m_imhof, m_both = m_both,
  r2 = c(fl = r2_fl, imhof = r2_imhof, both = r2_both),
  wr2 = c(fl = wr2_fl, imhof = wr2_imhof, both = wr2_both),
  dr2 = c(fl_given_imhof = dr2_fl_given_imhof,
          imhof_given_fl = dr2_imhof_given_fl),
  correlation = r
)
saveRDS(horse_race_results, file.path(dirname(MODELS_CACHE_V4), "p3v4_horse_race.rds"))

cat("  Done.\n")
