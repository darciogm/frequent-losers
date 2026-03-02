# ============================================================================
# 02_analysis.R — Regressions (Equation 2 from manuscript)
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================

cat("=== 02_analysis.R: Regressions ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data ------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ---- Main regressions: 3 DVs x 4 specs = 12 models -------------------------
# Equation 2: y_igt = β·losers_igt + α_g + λ_t + x·δ + ε_igt
#
# Specs:
#   (1) General:     item + year FE, controls: convite, pregao
#   (2) General+PBU: item + year + PBU FE, controls: convite, pregao
#   (3) Pregão only: item + year + PBU FE (subsample: pregao==1)
#   (4) Convite only: item + year + PBU FE (subsample: convite==1)
#
# Note: lquantity is unavailable in BEC_collapse_final.parquet.
# Item FE absorbs most within-item quantity variation. Coefficients may
# differ slightly from manuscript (which uses Stata areg with lquantity).

cat("  Running price regressions (negotiated price)...\n")
m_prices <- run_losers_4("lneg_price", dt, price_only = TRUE)

cat("  Running n_firms regressions...\n")
m_nfirms <- run_losers_4("ln_firms", dt, price_only = FALSE)

cat("  Running n_bids regressions...\n")
m_nbids <- run_losers_4("ln_bids", dt, price_only = FALSE)

# ---- Save all models -------------------------------------------------------
models <- list(
  prices = m_prices,
  nfirms = m_nfirms,
  nbids  = m_nbids
)

models_path <- "/tmp/p3_models.rds"
saveRDS(models, models_path)
cat("  Models saved:", models_path, "\n")

# ---- Quick summary of key coefficients (losers) ----------------------------
cat("\n  --- Key coefficients (losers) ---\n")
cat("  Manuscript targets: prices ~0.10-0.13, n_firms ~0.29-0.33, n_bids ~0.23-0.30\n\n")

for (outcome in c("prices", "nfirms", "nbids")) {
  mlist <- models[[outcome]]
  cat(sprintf("  %s:\n", toupper(outcome)))
  for (mname in names(mlist)) {
    m <- mlist[[mname]]
    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    p  <- 2 * pnorm(-abs(b / se))
    cat(sprintf("    %-15s: %s (%s) N=%s\n",
                mname, pfmt(b, 4), pfmt(se, 4), pfmt_int(m$nobs)))
  }
}
