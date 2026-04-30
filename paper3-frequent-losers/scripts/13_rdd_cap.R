# ============================================================================
# 13_rdd_cap.R — Sharp RDD on FL prevalence at procurement statutory caps
# Paper 3 v14: Strategy 1 (multi-cap, multi-year)
#
# Two caps in our window:
#   R$80,000  — Lei 8.666/93 Art. 23 (effective 2009-2018-Mar)
#   R$176,000 — Decreto 9.412/2018  (effective 2018-Apr-2019)
#
# Each cap is the statutory threshold separating convite (below) from pregão
# (above). For each cap × period combination:
#   1. First-stage RDD on convite share (must jump at the cap if rule binds)
#   2. Sharp RDD on FL prevalence at log(cap)
#   3. Sharp RDD on n_firms (auxiliary)
#   4. Falsification at placebo cutoffs
#   5. Cattaneo-Jansson-Ma density continuity test
# ============================================================================

cat("=== 13_rdd_cap.R: Strategy 1 — Sharp RDD at statutory caps ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table)
  if (!requireNamespace("rdrobust", quietly = TRUE)) {
    install.packages("rdrobust", repos = "https://cran.r-project.org")
  }
  library(rdrobust)
  has_rddensity <- requireNamespace("rddensity", quietly = TRUE)
  if (has_rddensity) library(rddensity)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
DATA <- file.path(BASE, "data", "processed", "item_value_panel.parquet")
OUT  <- file.path(BASE, "output", "rdd_cap")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(DATA)) stop("Run 12_build_item_value.R first.")

dt <- as.data.table(read_parquet(DATA))
cat("  Loaded:", DATA, " rows:", format(nrow(dt), big.mark=","), "\n")
cat("  Year coverage:", paste(sort(unique(dt$year)), collapse=", "), "\n")

# ---- Filter to convite + pregão with valid item value ----------------------
d <- dt[modality %in% c(1L, 3L) & item_value > 0 & is.finite(item_value)]
cat("  Convite + pregão, valid value:", format(nrow(d), big.mark=","), "\n")

# ---- Run a full RDD battery for one (cap, period) combination -------------
run_rdd_battery <- function(d_sub, cap, label) {
  cat(sprintf("\n========================================================\n"))
  cat(sprintf("  RDD battery: %s, cap = R$%s, N = %s\n",
              label, format(cap, big.mark=","), format(nrow(d_sub), big.mark=",")))
  cat(sprintf("========================================================\n"))

  d_sub <- copy(d_sub)
  d_sub[, running := log(item_value) - log(cap)]
  d_sub[, convite := as.integer(modality == 1L)]
  d_sub[, log_qty := log(pmax(qty, 1))]

  # Bandwidth diagnostics
  cat("  Bandwidth diagnostics (cap-relative):\n")
  for (bw_pct in c(0.10, 0.20, 0.30, 0.50)) {
    bw_log <- log(1 + bw_pct)
    n_band <- d_sub[abs(running) <= bw_log, .N]
    n_conv <- d_sub[abs(running) <= bw_log & convite == 1, .N]
    n_preg <- d_sub[abs(running) <= bw_log & convite == 0, .N]
    cat(sprintf("    +-%2.0f%%: n=%6d  convite=%5d  pregao=%5d  conv_share=%.3f\n",
                bw_pct*100, n_band, n_conv, n_preg,
                ifelse(n_band > 0, n_conv / n_band, NA)))
  }

  # Helper to print rdrobust output
  fmt_rdd <- function(m, name) {
    if (is.null(m)) { cat(sprintf("  [%s] failed\n", name)); return(NULL) }
    list(
      coef_conv = m$coef[1], se_conv = m$se[1], pv_conv = m$pv[1],
      coef_bc   = m$coef[3], se_bc   = m$se[3], pv_bc   = m$pv[3],
      bw_l = m$bws[1,1], bw_r = m$bws[1,2],
      n_l  = m$N_h[1],   n_r  = m$N_h[2]
    )
  }

  results <- list()

  # --- Test 1: First-stage RDD on convite share -----------------------------
  cat("\n  --- Test 1: First-stage RDD on convite share ---\n")
  fs <- tryCatch(rdrobust(y = d_sub$convite, x = d_sub$running, c = 0,
                          kernel = "triangular", bwselect = "mserd"),
                 error = function(e) { cat("    Error:", conditionMessage(e), "\n"); NULL })
  if (!is.null(fs)) {
    cat(sprintf("    Conventional:   %.4f (SE %.4f, p=%.4g) bw=%.3f, N=%d/%d\n",
                fs$coef[1], fs$se[1], fs$pv[1], fs$bws[1,1], fs$N_h[1], fs$N_h[2]))
    cat(sprintf("    Bias-corrected: %.4f (SE %.4f, p=%.4g)\n",
                fs$coef[3], fs$se[3], fs$pv[3]))
    results$first_stage_convite <- fmt_rdd(fs, "first_stage")
  }

  # --- Test 2: Sharp RDD on FL prevalence -----------------------------------
  cat("\n  --- Test 2: Sharp RDD on FL prevalence ---\n")
  fl_rdd <- tryCatch(rdrobust(y = d_sub$has_fl, x = d_sub$running, c = 0,
                              kernel = "triangular", bwselect = "mserd"),
                     error = function(e) NULL)
  if (!is.null(fl_rdd)) {
    cat(sprintf("    Conventional:   %.4f (SE %.4f, p=%.4g) bw=%.3f, N=%d/%d\n",
                fl_rdd$coef[1], fl_rdd$se[1], fl_rdd$pv[1],
                fl_rdd$bws[1,1], fl_rdd$N_h[1], fl_rdd$N_h[2]))
    cat(sprintf("    Bias-corrected: %.4f (SE %.4f, p=%.4g)\n",
                fl_rdd$coef[3], fl_rdd$se[3], fl_rdd$pv[3]))
    results$fl_prevalence <- fmt_rdd(fl_rdd, "fl")
  }

  # --- Test 3: Sharp RDD on n_firms -----------------------------------------
  cat("\n  --- Test 3: Sharp RDD on n_firms ---\n")
  nf <- tryCatch(rdrobust(y = d_sub$n_firms, x = d_sub$running, c = 0,
                          kernel = "triangular", bwselect = "mserd"),
                 error = function(e) NULL)
  if (!is.null(nf)) {
    cat(sprintf("    Conventional:   %.4f (SE %.4f, p=%.4g)\n",
                nf$coef[1], nf$se[1], nf$pv[1]))
    results$n_firms <- fmt_rdd(nf, "nf")
  }

  # --- Test 4: Placebos -----------------------------------------------------
  cat("\n  --- Test 4: Placebos at non-statutory cutoffs ---\n")
  placebos <- c(round(cap * 0.5), round(cap * 0.75), round(cap * 1.5),
                round(cap * 2.0))
  for (placebo_cap in placebos) {
    d_sub[, running_pl := log(item_value) - log(placebo_cap)]
    pl <- tryCatch(rdrobust(y = d_sub$has_fl, x = d_sub$running_pl, c = 0,
                            kernel = "triangular", bwselect = "mserd"),
                   error = function(e) NULL)
    if (!is.null(pl)) {
      cat(sprintf("    Placebo R$%s: %.4f (SE %.4f, p=%.4g) [should be ~0]\n",
                  format(placebo_cap, big.mark=","),
                  pl$coef[1], pl$se[1], pl$pv[1]))
    }
  }

  # --- Test 5: Density continuity (Cattaneo-Jansson-Ma) --------------------
  cat("\n  --- Test 5: Density continuity at cutoff ---\n")
  if (has_rddensity) {
    dens <- tryCatch(rddensity(X = d_sub$running, c = 0),
                     error = function(e) NULL)
    if (!is.null(dens)) {
      cat(sprintf("    CJM density: T=%.4f, p=%.4g\n",
                  dens$test$t_jk, dens$test$p_jk))
      cat(sprintf("    Density at cutoff: left=%.6f, right=%.6f\n",
                  dens$hat$left, dens$hat$right))
      results$density_cjm <- list(t = dens$test$t_jk, pv = dens$test$p_jk,
                                  left = dens$hat$left, right = dens$hat$right)
    }
  } else {
    cat("    (rddensity not installed — skipping CJM test)\n")
  }

  results
}

# ---- Run battery for each (cap, period) combination ----------------------
all_results <- list()

# (1) R$80k cap on the FULL pre-Decreto sample (2009-2017 + Q1 2018)
cat("\n\n[1/4] R$80k cap, pre-Decreto period (year <= 2017)\n")
all_results$cap80_pre <- run_rdd_battery(
  d_sub = d[year <= 2017L],
  cap   = 80000,
  label = "R$80k pre-Decreto"
)

# (2) R$80k cap on the POST-Decreto sample (year >= 2018) — should be NULL
#     since the cap no longer binds (rule moved to R$176k).
cat("\n\n[2/4] R$80k cap, post-Decreto period (year >= 2018) — placebo\n")
all_results$cap80_post <- run_rdd_battery(
  d_sub = d[year >= 2018L],
  cap   = 80000,
  label = "R$80k post-Decreto (placebo)"
)

# (3) R$176k cap on the POST-Decreto sample
cat("\n\n[3/4] R$176k cap, post-Decreto period (year >= 2018)\n")
all_results$cap176_post <- run_rdd_battery(
  d_sub = d[year >= 2018L],
  cap   = 176000,
  label = "R$176k post-Decreto"
)

# (4) R$176k cap on PRE-Decreto sample — placebo (rule didn't exist yet)
cat("\n\n[4/4] R$176k cap, pre-Decreto period (year <= 2017) — placebo\n")
all_results$cap176_pre <- run_rdd_battery(
  d_sub = d[year <= 2017L],
  cap   = 176000,
  label = "R$176k pre-Decreto (placebo)"
)

# ---- Save consolidated summary --------------------------------------------
saveRDS(all_results, file.path(OUT, "rdd_results_full.rds"))

extract_row <- function(label, test_label, x) {
  if (is.null(x)) return(NULL)
  data.table(
    period_cap = label,
    test       = test_label,
    coef_conv  = x$coef_conv, se_conv = x$se_conv, pv_conv = x$pv_conv,
    coef_bc    = x$coef_bc,   se_bc   = x$se_bc,   pv_bc   = x$pv_bc,
    bw_l = x$bw_l, bw_r = x$bw_r, n_l = x$n_l, n_r = x$n_r
  )
}

summary_dt <- rbindlist(lapply(names(all_results), function(label) {
  res <- all_results[[label]]
  if (is.null(res)) return(NULL)
  rbindlist(list(
    extract_row(label, "first_stage_convite", res$first_stage_convite),
    extract_row(label, "fl_prevalence",       res$fl_prevalence),
    extract_row(label, "n_firms",             res$n_firms)
  ), fill = TRUE)
}), fill = TRUE)

fwrite(summary_dt, file.path(OUT, "rdd_summary.csv"))
cat("\n  Saved:", file.path(OUT, "rdd_summary.csv"), "\n")

cat("\n  ===== Headline RDD coefficients =====\n")
print(summary_dt[, .(period_cap, test,
                     coef = round(coef_conv, 4),
                     se   = round(se_conv, 4),
                     pv   = round(pv_conv, 4),
                     n_l, n_r)])

cat("\n  Done.\n")
