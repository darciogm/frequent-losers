# ============================================================================
# 14_quality_checks.R — Final validation for Paper 3 v4
# ============================================================================
# Verifies all expected outputs exist and key statistics are consistent.
# Run this after all other scripts to confirm pipeline integrity.
# ============================================================================

cat("=== 14_quality_checks.R: Final validation ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

n_pass <- 0L
n_fail <- 0L
n_warn <- 0L

check <- function(cond, msg) {
  if (cond) {
    cat(sprintf("  PASS: %s\n", msg))
    n_pass <<- n_pass + 1L
  } else {
    cat(sprintf("  FAIL: %s\n", msg))
    n_fail <<- n_fail + 1L
  }
}

warn_check <- function(cond, msg) {
  if (cond) {
    cat(sprintf("  PASS: %s\n", msg))
    n_pass <<- n_pass + 1L
  } else {
    cat(sprintf("  WARN: %s\n", msg))
    n_warn <<- n_warn + 1L
  }
}

# ============================================================================
# 1. Cache files exist
# ============================================================================

cat("\n--- Cache files ---\n")

cache_files <- list(
  "Data (prepared)"        = DATA_CACHE_V4,
  "Data (full)"            = DATA_CACHE_V4_FULL,
  "Models"                 = MODELS_CACHE_V4,
  "Network"                = NETWORK_CACHE_V4,
  "IV cache"               = IV_CACHE_V4,
  "IV models"              = IV_MODELS_CACHE_V4,
  "Bajari-Ye"              = BAJARI_CACHE_V4,
  "Mechanisms"             = MECHANISMS_CACHE_V4,
  "DiD"                    = DID_CACHE_V4,
  "CADE"                   = CADE_CACHE_V4,
  "Robustness"             = ROBUSTNESS_CACHE_V4,
  "Welfare"                = WELFARE_CACHE_V4,
  "FL robustness"          = FL_ROBUST_CACHE_V4,
  "Regime"                 = REGIME_CACHE_V4
)

for (nm in names(cache_files)) {
  check(file.exists(cache_files[[nm]]), paste0(nm, " cache exists"))
}

# ============================================================================
# 2. Required LaTeX tables exist
# ============================================================================

cat("\n--- LaTeX tables ---\n")

required_tables <- c(
  # Main body
  "tab_desc_stats.tex",
  "tab_prices.tex",
  "tab_nfirms.tex",
  "tab_nbids.tex",
  "tab_nfirms_excl.tex",
  "tab_bajari_ye.tex",
  "tab_mechanisms.tex",
  "tab_modality_by_year.tex",
  # IV
  "tab_iv_main.tex",
  "tab_iv_first_stage.tex",
  "tab_iv_placebo.tex",
  # Network
  "tab_fl_network_summary.tex",
  "tab_network_split.tex",
  # CADE
  "tab_cade_permutation.tex",
  "tab_excl_cade.tex",
  # Robustness
  "tab_regime_oversight.tex",
  "tab_welfare_bounds.tex"
)

optional_tables <- c(
  "tab_regime_test.tex",
  "tab_tighter_controls.tex",
  "tab_unrestricted_sample.tex",
  "tab_homogeneous_subsample.tex",
  "tab_did_revised.tex",
  "tab_fl_lowwinrate.tex",
  "tab_fl_crossfit.tex",
  "tab_fl_temporal.tex",
  "tab_bajari_ye_firststage.tex",
  "tab_bajari_ye_placebo.tex",
  "tab_iv_network_split.tex"
)

for (tbl in required_tables) {
  check(file.exists(file.path(OUT_TAB, tbl)), paste0(tbl, " exists"))
}

for (tbl in optional_tables) {
  warn_check(file.exists(file.path(OUT_TAB, tbl)), paste0(tbl, " exists (optional)"))
}

# ============================================================================
# 3. Required figures exist
# ============================================================================

cat("\n--- Figures ---\n")

required_figs <- c(
  "fig_01_losses_distribution.pdf",
  "fig_02_iqr_identification.pdf",
  "fig_03_coef_summary.pdf"
)

optional_figs <- c(
  "fig_04_cover_bid_spread.pdf",
  "fig_05_regime_boxplot.pdf",
  "fig_06_event_study.pdf",
  "fig_07_threshold_stability.pdf",
  "fig_08_sensitivity_contour.pdf",
  "fig_09_welfare_markup.pdf",
  "fig_10_year_coefficients.pdf",
  "fig_11_network_split.pdf",
  "fig_12_fl_definition_robustness.pdf",
  "fig_13_cade_permutation.pdf",
  "fig_14_oversight_heterogeneity.pdf",
  "fig_first_stage_binscatter.pdf",
  "fig_bajari_bootstrap.pdf",
  "fig_did_honest.pdf",
  "fig_regime_densities.pdf",
  "fig_network_hhi.pdf"
)

for (fig in required_figs) {
  check(file.exists(file.path(OUT_FIG, fig)), paste0(fig, " exists"))
}

for (fig in optional_figs) {
  warn_check(file.exists(file.path(OUT_FIG, fig)), paste0(fig, " exists (optional)"))
}

# ============================================================================
# 4. Key statistics consistency
# ============================================================================

cat("\n--- Key statistics ---\n")

if (file.exists(DATA_CACHE_V4)) {
  dt <- readRDS(DATA_CACHE_V4)
  check(nrow(dt) > 1e6, sprintf("Dataset has %s rows (>1M expected)", pfmt_int(nrow(dt))))
  check("losers" %in% names(dt), "losers column exists")
  check("lneg_price" %in% names(dt), "lneg_price column exists")
  check("convite" %in% names(dt), "convite column exists")
  check("item_f" %in% names(dt), "item_f factor exists")
  check("year_f" %in% names(dt), "year_f factor exists")
  check("pbu_f" %in% names(dt), "pbu_f factor exists")

  # Check FL definition
  n_fl_tenders <- sum(dt$losers == 1, na.rm = TRUE)
  n_total <- nrow(dt)
  fl_share <- n_fl_tenders / n_total * 100
  check(fl_share > 1 & fl_share < 50,
        sprintf("FL share = %.1f%% (plausible range 1-50%%)", fl_share))

  # Network columns
  warn_check("has_high_susp_fl" %in% names(dt), "has_high_susp_fl column exists")
  warn_check("has_low_susp_fl" %in% names(dt), "has_low_susp_fl column exists")

  # IV column
  warn_check("fl_supply_loo" %in% names(dt), "fl_supply_loo (IV instrument) column exists")
}

if (file.exists(MODELS_CACHE_V4)) {
  models <- readRDS(MODELS_CACHE_V4)
  check(!is.null(models$prices), "Price models exist")
  check(!is.null(models$nfirms), "N firms models exist")
  check(!is.null(models$nbids), "N bids models exist")
  check(!is.null(models$nfirms_excl), "N firms excl models exist")

  # Check coefficient sign (expect positive for prices)
  m <- models$prices$general_pbu
  if (!is.null(m) && "losers" %in% names(coef(m))) {
    b <- coef(m)["losers"]
    check(b > 0, sprintf("Price coefficient positive: %.4f", b))
  }
}

if (file.exists(IV_MODELS_CACHE_V4)) {
  iv <- readRDS(IV_MODELS_CACHE_V4)
  warn_check(!is.null(iv$first_stage), "First-stage diagnostics exist")
  if (!is.null(iv$first_stage)) {
    fs <- iv$first_stage
    for (nm in names(fs)) {
      if (!is.null(fs[[nm]]$f_stat)) {
        check(fs[[nm]]$f_stat > 10,
              sprintf("First-stage F-stat (%s): %.1f (>10 = strong)", nm, fs[[nm]]$f_stat))
      }
    }
  }
}

# ============================================================================
# 5. Summary
# ============================================================================

cat(sprintf("\n=== Quality Check Summary ===\n"))
cat(sprintf("  PASS: %d\n", n_pass))
cat(sprintf("  WARN: %d\n", n_warn))
cat(sprintf("  FAIL: %d\n", n_fail))

if (n_fail == 0) {
  cat("  STATUS: All required checks passed.\n")
} else {
  cat(sprintf("  STATUS: %d required checks FAILED. Review pipeline.\n", n_fail))
}

cat("  Done.\n")
