# ============================================================================
# 09_rdd_thresholds.R — RDD at procurement thresholds (Task 9)
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Expected: INFEASIBLE (BEC only records competitive procurement above Art. 24)
# Script documents the finding and attempts analysis if surprisingly feasible.
# ============================================================================

cat("=== 09_rdd_thresholds.R: RDD threshold analysis ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data ---------------------------------------------------------------
if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ---- Check RDD feasibility --------------------------------------------------

cat("  Checking RDD feasibility at Art. 24 procurement thresholds...\n")

# Art. 24 thresholds (Lei 8.666/93, updated values ~2009-2019):
# - Below ~R$8,000: dispensa de licitação (no competitive bidding)
# - R$8,000 - R$80,000: carta convite (sealed bid, min 3 bidders)
# - R$80,000 - R$650,000: tomada de preços
# - Above R$650,000: concorrência
# BEC records convite (phase 2) and pregão (phase 3) — both above threshold

rdd_log <- character()
rdd_log_add <- function(...) {
  msg <- paste0(...)
  cat(msg, "\n")
  rdd_log <<- c(rdd_log, msg)
}

rdd_log_add("RDD FEASIBILITY ANALYSIS")
rdd_log_add(paste(rep("=", 50), collapse = ""))

# Check density around each threshold
thresholds <- data.table(
  name = c("Dispensa/Convite", "Convite/Tomada", "Tomada/Concorrencia"),
  value = c(8000, 80000, 650000)
)

for (i in seq_len(nrow(thresholds))) {
  thr <- thresholds$value[i]
  nm  <- thresholds$name[i]
  bw  <- thr * 0.10  # 10% bandwidth

  n_below <- dt[!is.na(bid_ref_price_min) & bid_ref_price_min > (thr - bw) &
                bid_ref_price_min < thr, .N]
  n_above <- dt[!is.na(bid_ref_price_min) & bid_ref_price_min >= thr &
                bid_ref_price_min < (thr + bw), .N]
  n_total <- n_below + n_above

  rdd_log_add(sprintf("  %s (R$%s):", nm, pfmt_int(thr)))
  rdd_log_add(sprintf("    Below (10%% bw): %s, Above: %s, Total: %s",
                        pfmt_int(n_below), pfmt_int(n_above), pfmt_int(n_total)))
}

# Overall assessment
n_valid_ref <- dt[!is.na(bid_ref_price_min), .N]
n_below_min <- dt[!is.na(bid_ref_price_min) & bid_ref_price_min < 8000, .N]

rdd_log_add("")
rdd_log_add(sprintf("  Total obs with reference price: %s", pfmt_int(n_valid_ref)))
rdd_log_add(sprintf("  Obs below R$8,000 (min threshold): %s (%.2f%%)",
                      pfmt_int(n_below_min), 100 * n_below_min / max(n_valid_ref, 1)))

# Minimum sample for RDD: need ~1000+ obs on each side of cutoff
rdd_feasible <- n_below_min > 1000

rdd_log_add("")
if (!rdd_feasible) {
  rdd_log_add("RESULT: RDD IS INFEASIBLE")
  rdd_log_add("")
  rdd_log_add("Institutional reason: BEC (Bolsa Eletrônica de Compras) is an")
  rdd_log_add("electronic procurement platform that ONLY records competitive")
  rdd_log_add("procurement processes. Direct purchases (dispensa de licitação)")
  rdd_log_add("below Art. 24 thresholds are not conducted through BEC.")
  rdd_log_add("")
  rdd_log_add("Implication for identification: We cannot use procurement value")
  rdd_log_add("thresholds as a running variable for RDD because there is no")
  rdd_log_add("discontinuity in the data — all observations are above the")
  rdd_log_add("threshold. This is documented as an institutional finding in")
  rdd_log_add("Section 3.1 of the manuscript.")
  rdd_log_add("")
  rdd_log_add("Alternative identification: Callaway & Sant'Anna (2021)")
  rdd_log_add("staggered DiD using first FL entry as treatment event.")
} else {
  rdd_log_add("RESULT: RDD MAY BE FEASIBLE — investigating further...")

  # Attempt RDD if rdrobust is available
  if (requireNamespace("rdrobust", quietly = TRUE)) {
    library(rdrobust)

    # Try at the convite/tomada threshold (R$80,000)
    d_rdd <- dt[!is.na(bid_ref_price_min) & !is.na(lneg_price)]
    d_rdd[, running := bid_ref_price_min - 80000]

    rdd_out <- tryCatch(
      rdrobust(y = d_rdd$lneg_price, x = d_rdd$running, c = 0),
      error = function(e) {
        rdd_log_add(sprintf("  rdrobust failed: %s", e$message))
        NULL
      }
    )

    if (!is.null(rdd_out)) {
      rdd_log_add(sprintf("  RDD estimate: %.4f (SE: %.4f, p: %.4f)",
                            rdd_out$coef[1], rdd_out$se[1], rdd_out$pv[1]))
    }

    # McCrary density test
    if (requireNamespace("rddensity", quietly = TRUE)) {
      library(rddensity)
      density_test <- tryCatch(
        rddensity(X = d_rdd$running),
        error = function(e) NULL
      )
      if (!is.null(density_test)) {
        rdd_log_add(sprintf("  McCrary density test p-value: %.4f",
                              density_test$test$p_jk))
      }
    }
  } else {
    rdd_log_add("  rdrobust package not installed. Install with:")
    rdd_log_add("  install.packages(c('rdrobust', 'rddensity'))")
  }
}

# ---- Save results ------------------------------------------------------------
log_path <- file.path(OUT_LOG, "rdd_feasibility.txt")
writeLines(rdd_log, log_path)
cat("  Saved:", log_path, "\n")

rdd_results <- list(
  feasible = rdd_feasible,
  n_below_min = n_below_min,
  n_valid_ref = n_valid_ref
)
saveRDS(rdd_results, "/tmp/p3v2_rdd.rds")
cat("  Done.\n")
