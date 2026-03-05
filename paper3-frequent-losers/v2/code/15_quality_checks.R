# ============================================================================
# 15_quality_checks.R — Quality gates for Paper 3 v2
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Verifies:
#   1. Main coefficient < 40% markup (not implausibly large)
#   2. Bajari-Ye placebo p > 0.10
#   3. Pre-trends clean (avg |ATT| for t<0 < 0.02)
#   4. All required output files exist
#   5. Table/figure counts match expectations
# ============================================================================

cat("=== 15_quality_checks.R: Quality gates ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

n_pass <- 0
n_fail <- 0
n_skip <- 0

check <- function(name, condition, msg_pass = "PASS", msg_fail = "FAIL") {
  if (is.na(condition)) {
    cat(sprintf("  [SKIP] %s: condition unavailable\n", name))
    n_skip <<- n_skip + 1
  } else if (condition) {
    cat(sprintf("  [PASS] %s\n", name))
    n_pass <<- n_pass + 1
  } else {
    cat(sprintf("  [FAIL] %s: %s\n", name, msg_fail))
    n_fail <<- n_fail + 1
  }
}

# ============================================================================
# Gate 1: Main coefficient plausibility
# ============================================================================

cat("\n--- Gate 1: Main coefficient plausibility ---\n")

if (file.exists(MODELS_CACHE_V2)) {
  models <- readRDS(MODELS_CACHE_V2)
  m_price <- models$prices$general_pbu
  b <- coef(m_price)["losers"]
  markup_pct <- (exp(b) - 1) * 100

  check("Main price coef > 0 (expected positive)",
        b > 0, msg_fail = sprintf("coef = %.4f (negative!)", b))
  check("Markup < 40% (plausible range)",
        markup_pct < 40,
        msg_fail = sprintf("markup = %.1f%% (implausibly large)", markup_pct))
  check("Markup > 1% (economically meaningful)",
        markup_pct > 1,
        msg_fail = sprintf("markup = %.1f%% (too small)", markup_pct))

  cat(sprintf("  Markup estimate: %.2f%%\n", markup_pct))
} else {
  cat("  Models file not found. Skipping Gate 1.\n")
  n_skip <- n_skip + 3
}

# ============================================================================
# Gate 2: Bajari-Ye placebo
# ============================================================================

cat("\n--- Gate 2: Bajari-Ye placebo ---\n")

bj_file <- "/tmp/p3v2_bajari_ye.rds"
if (file.exists(bj_file)) {
  bj <- readRDS(bj_file)

  check("Bajari-Ye placebo p > 0.10",
        !is.na(bj$placebo$p_value) && bj$placebo$p_value > 0.10,
        msg_fail = sprintf("placebo p = %.4f (should be > 0.10)",
                            ifelse(is.na(bj$placebo$p_value), NA, bj$placebo$p_value)))

  if (bj$exchangeability$feasible) {
    check("Exchangeability test: KS rejects (FL bids differ)",
          bj$exchangeability$ks_p < 0.05,
          msg_fail = sprintf("KS p = %.4f", bj$exchangeability$ks_p))
  }
} else {
  cat("  Bajari-Ye results not found. Skipping Gate 2.\n")
  n_skip <- n_skip + 2
}

# ============================================================================
# Gate 3: Pre-trends (DiD)
# ============================================================================

cat("\n--- Gate 3: Pre-trends ---\n")

did_file <- "/tmp/p3v2_did.rds"
if (file.exists(did_file)) {
  did <- readRDS(did_file)

  for (dv in names(did$twfe_coefs)) {
    cf <- did$twfe_coefs[[dv]]
    pre_coefs <- cf[rel_year < 0, coef]
    avg_pre <- mean(abs(pre_coefs), na.rm = TRUE)

    check(sprintf("Pre-trend clean for %s (avg |coef| < 0.02)", dv),
          avg_pre < 0.02,
          msg_fail = sprintf("avg |pre-coef| = %.4f", avg_pre))
  }

  # C&S pre-trends
  for (dv in names(did$callaway_santanna)) {
    cs <- did$callaway_santanna[[dv]]
    if (!is.null(cs$event_study)) {
      pre_att <- cs$event_study$att.egt[cs$event_study$egt < 0]
      if (length(pre_att) > 0) {
        avg_pre_cs <- mean(abs(pre_att), na.rm = TRUE)
        check(sprintf("C&S pre-trend clean for %s", dv),
              avg_pre_cs < 0.02,
              msg_fail = sprintf("avg |pre-ATT| = %.4f", avg_pre_cs))
      }
    }
  }
} else {
  cat("  DiD results not found. Skipping Gate 3.\n")
  n_skip <- n_skip + 2
}

# ============================================================================
# Gate 4: Required output files exist
# ============================================================================

cat("\n--- Gate 4: Required output files ---\n")

required_tables <- c(
  "tab_desc_stats.tex", "tab_prices.tex", "tab_nfirms.tex", "tab_nbids.tex",
  "tab_nfirms_excl.tex", "tab_bajari_ye.tex", "tab_mechanisms.tex",
  "tab_did_cs.tex", "tab_regime_test.tex", "tab_welfare.tex",
  "tab_threshold_robustness.tex", "tab_ml_comparison.tex",
  "tab_cade_validation.tex"
)

required_figures <- c(
  "fig_01_losses_distribution.pdf", "fig_02_iqr_identification.pdf",
  "fig_03_coef_summary.pdf", "fig_06_event_study.pdf",
  "fig_07_threshold_stability.pdf", "fig_10_year_coefficients.pdf"
)

for (f in required_tables) {
  exists_flag <- file.exists(file.path(OUT_TAB, f))
  check(sprintf("Table: %s", f), exists_flag,
        msg_fail = "file not found")
}

for (f in required_figures) {
  exists_flag <- file.exists(file.path(OUT_FIG, f))
  check(sprintf("Figure: %s", f), exists_flag,
        msg_fail = "file not found")
}

# ============================================================================
# Gate 5: File counts
# ============================================================================

cat("\n--- Gate 5: Output counts ---\n")

n_tex <- length(list.files(OUT_TAB, pattern = "\\.tex$"))
n_pdf <- length(list.files(OUT_FIG, pattern = "\\.pdf$"))

cat(sprintf("  Tables: %d .tex files\n", n_tex))
cat(sprintf("  Figures: %d .pdf files\n", n_pdf))

check("At least 10 tables generated", n_tex >= 10,
      msg_fail = sprintf("only %d tables", n_tex))
check("At least 5 figures generated", n_pdf >= 5,
      msg_fail = sprintf("only %d figures", n_pdf))

# ============================================================================
# Summary
# ============================================================================

cat("\n")
cat(paste(rep("=", 60), collapse = ""), "\n")
cat("  QUALITY GATE SUMMARY\n")
cat(paste(rep("=", 60), collapse = ""), "\n")
cat(sprintf("  PASS: %d\n", n_pass))
cat(sprintf("  FAIL: %d\n", n_fail))
cat(sprintf("  SKIP: %d\n", n_skip))

if (n_fail == 0) {
  cat("\n  ALL GATES PASSED. Ready for manuscript compilation.\n")
} else {
  cat(sprintf("\n  WARNING: %d gate(s) failed. Review before proceeding.\n", n_fail))
}

cat(paste(rep("=", 60), collapse = ""), "\n")

# Save summary
qc_summary <- data.table(
  metric = c("pass", "fail", "skip", "n_tables", "n_figures"),
  value = c(n_pass, n_fail, n_skip, n_tex, n_pdf)
)
write_parquet(qc_summary, file.path(DATA_V2, "quality_checks.parquet"))
cat("  Done.\n")
