# ============================================================================
# 13_rdd_cap.R — Sharp RDD on FL prevalence at R$80,000 statutory cap
# Paper 3 v14: Strategy 1
#
# Running variable: item value (qty × ref_price)
# Cutoff: R$80,000 (Lei 8.666 Art. 23 — convite cap pre-2018)
# Treatment: modality assignment (below cap → convite, above → pregão)
#
# Tests:
#   (1) Sharp RDD on FL prevalence (binary)
#   (2) First-stage check: convite share at the cap (must jump from ~1 to ~0)
#   (3) Falsification at placebo cutoffs (R$50K, R$120K)
# ============================================================================

cat("=== 13_rdd_cap.R: Strategy 1 sharp RDD at R$80,000 cap ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table)
  if (!requireNamespace("rdrobust", quietly = TRUE)) {
    cat("  Installing rdrobust...\n")
    install.packages("rdrobust", repos = "https://cran.r-project.org")
  }
  library(rdrobust)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
DATA <- file.path(BASE, "data", "processed", "item_value_panel.parquet")
OUT  <- file.path(BASE, "output", "rdd_cap_2017")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

dt <- as.data.table(read_parquet(DATA))
cat("  Loaded:", DATA, " rows:", format(nrow(dt), big.mark=","), "\n")
cat("  Year coverage:", paste(sort(unique(dt$year)), collapse=", "), "\n")

# ---- Filter to convite + pregão with valid item value ----------------------
d <- dt[modality %in% c(1L, 3L) & item_value > 0 & is.finite(item_value)]
cat("  Convite + pregão items with valid value:", format(nrow(d), big.mark=","), "\n")

# Running variable: log(item_value), centered at log(80000)
CAP <- 80000
d[, running := log(item_value) - log(CAP)]
d[, convite := as.integer(modality == 1L)]
d[, pregao  := as.integer(modality == 3L)]

cat("\n  Bandwidth diagnostics:\n")
for (bw_pct in c(0.10, 0.20, 0.30, 0.50)) {
  bw_log <- log(1 + bw_pct)
  n_band <- d[abs(running) <= bw_log, .N]
  n_conv <- d[abs(running) <= bw_log & convite == 1, .N]
  n_preg <- d[abs(running) <= bw_log & pregao  == 1, .N]
  cat(sprintf("    ±%.0f%% bandwidth: total=%d, convite=%d, pregão=%d\n",
              bw_pct*100, n_band, n_conv, n_preg))
}

# ---- Test 1: First-stage — convite share at the cap ------------------------
cat("\n--- Test 1: First-stage RDD on convite indicator ---\n")
fs <- tryCatch(
  rdrobust(y = d$convite, x = d$running, c = 0,
           kernel = "triangular", bwselect = "mserd"),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })

if (!is.null(fs)) {
  cat(sprintf("  Convite share jump at log(R$80k):\n"))
  cat(sprintf("    Conventional: %.4f (SE %.4f, p=%.4g)\n",
              fs$coef[1], fs$se[1], fs$pv[1]))
  cat(sprintf("    Bias-corrected: %.4f (SE %.4f, p=%.4g)\n",
              fs$coef[3], fs$se[3], fs$pv[3]))
  cat(sprintf("    Bandwidth (h_l=%.3f, h_r=%.3f), N(left)=%d, N(right)=%d\n",
              fs$bws[1,1], fs$bws[1,2], fs$N_h[1], fs$N_h[2]))
  saveRDS(fs, file.path(OUT, "rdd_first_stage.rds"))
}

# ---- Test 2: Sharp RDD on FL prevalence -----------------------------------
cat("\n--- Test 2: Sharp RDD on FL prevalence ---\n")
fl_rdd <- tryCatch(
  rdrobust(y = d$has_fl, x = d$running, c = 0,
           kernel = "triangular", bwselect = "mserd"),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })

if (!is.null(fl_rdd)) {
  cat(sprintf("  FL prevalence jump at log(R$80k):\n"))
  cat(sprintf("    Conventional: %.4f (SE %.4f, p=%.4g)\n",
              fl_rdd$coef[1], fl_rdd$se[1], fl_rdd$pv[1]))
  cat(sprintf("    Bias-corrected: %.4f (SE %.4f, p=%.4g)\n",
              fl_rdd$coef[3], fl_rdd$se[3], fl_rdd$pv[3]))
  cat(sprintf("    Bandwidth (h_l=%.3f, h_r=%.3f), N(left)=%d, N(right)=%d\n",
              fl_rdd$bws[1,1], fl_rdd$bws[1,2], fl_rdd$N_h[1], fl_rdd$N_h[2]))
  saveRDS(fl_rdd, file.path(OUT, "rdd_fl_prevalence.rds"))
}

# ---- Test 3: Sharp RDD on number of bidders -------------------------------
cat("\n--- Test 3: Sharp RDD on n_firms ---\n")
nf_rdd <- tryCatch(
  rdrobust(y = d$n_firms, x = d$running, c = 0,
           kernel = "triangular", bwselect = "mserd"),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })

if (!is.null(nf_rdd)) {
  cat(sprintf("  n_firms jump at log(R$80k):\n"))
  cat(sprintf("    Conventional: %.4f (SE %.4f, p=%.4g)\n",
              nf_rdd$coef[1], nf_rdd$se[1], nf_rdd$pv[1]))
}

# ---- Test 4: Falsification at placebo cutoffs ------------------------------
cat("\n--- Test 4: Placebo RDDs at non-statutory cutoffs ---\n")
for (placebo_cap in c(50000, 100000, 120000)) {
  d[, running_pl := log(item_value) - log(placebo_cap)]
  pl <- tryCatch(
    rdrobust(y = d$has_fl, x = d$running_pl, c = 0,
             kernel = "triangular", bwselect = "mserd"),
    error = function(e) NULL)
  if (!is.null(pl)) {
    cat(sprintf("  Placebo R$%s: coef=%.4f (SE %.4f, p=%.4g) [should be ~0]\n",
                format(placebo_cap, big.mark=","),
                pl$coef[1], pl$se[1], pl$pv[1]))
  }
}

# ---- Density continuity check (McCrary-style) -----------------------------
cat("\n--- Density check at the cutoff ---\n")
if (requireNamespace("rddensity", quietly = TRUE)) {
  library(rddensity)
  dens <- rddensity(X = d$running, c = 0)
  cat(sprintf("  Cattaneo-Jansson-Ma density test: T=%.4f, p=%.4g\n",
              dens$test$t_jk, dens$test$p_jk))
  cat(sprintf("  Density at cutoff: left=%.6f, right=%.6f\n",
              dens$hat$left, dens$hat$right))
} else {
  cat("  (install rddensity for Cattaneo-Jansson-Ma density test)\n")
  # Simple bin-density check
  cat("  Simple bin density (±0.10 of log(R$80k)):\n")
  cat(sprintf("    Left:  %d items\n", d[running >= -0.10 & running < 0, .N]))
  cat(sprintf("    Right: %d items\n", d[running > 0 & running <= 0.10, .N]))
}

# ---- Save coefficient summary ---------------------------------------------
summary_dt <- data.table(
  test = c("first_stage_convite", "fl_prevalence", "n_firms"),
  coef = c(fs$coef[1], fl_rdd$coef[1], nf_rdd$coef[1]),
  se   = c(fs$se[1], fl_rdd$se[1], nf_rdd$se[1]),
  pval = c(fs$pv[1], fl_rdd$pv[1], nf_rdd$pv[1]),
  n_left  = c(fs$N_h[1], fl_rdd$N_h[1], nf_rdd$N_h[1]),
  n_right = c(fs$N_h[2], fl_rdd$N_h[2], nf_rdd$N_h[2])
)
fwrite(summary_dt, file.path(OUT, "rdd_summary_2017.csv"))
cat("\n  Saved summary to:", file.path(OUT, "rdd_summary_2017.csv"), "\n")
cat("  Done.\n")
