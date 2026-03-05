# ============================================================================
# 06_main_regressions.R — Main regressions + regime test (v2)
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# 6.1: Same 4 DVs x 4 specs as v1 (reuse run_losers_4)
# 6.2: Dispersion regressions (regime test P3/P4)
# 6.3: Price ratio regression
# 6.4: Cover intensity (continuous treatment)
# ============================================================================

cat("=== 06_main_regressions.R: Main regressions ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ============================================================================
# 6.1: Standard regressions (4 DVs x 4 specs = 16 models)
# ============================================================================

cat("  6.1 Standard regressions (replicating v1)...\n")

cat("  Running price regressions...\n")
m_prices <- run_losers_4("lneg_price", dt, price_only = TRUE)

cat("  Running n_firms regressions...\n")
m_nfirms <- run_losers_4("ln_firms", dt, price_only = FALSE)

cat("  Running n_bids regressions...\n")
m_nbids <- run_losers_4("ln_bids", dt, price_only = FALSE)

cat("  Running n_firms_excl regressions...\n")
m_nfirms_excl <- run_losers_4("ln_firms_excl", dt, price_only = FALSE)

# Quick summary
cat("\n  --- Key coefficients (losers) ---\n")
for (outcome_name in c("prices", "nfirms", "nfirms_excl", "nbids")) {
  mlist <- switch(outcome_name,
    prices = m_prices, nfirms = m_nfirms,
    nfirms_excl = m_nfirms_excl, nbids = m_nbids
  )
  cat(sprintf("  %s:\n", toupper(outcome_name)))
  for (mname in names(mlist)) {
    m <- mlist[[mname]]
    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    cat(sprintf("    %-15s: %s (%s) N=%s\n",
                mname, pfmt(b, 4), pfmt(se, 4), pfmt_int(m$nobs)))
  }
}

# ============================================================================
# 6.2: Dispersion regressions (Regime test)
# ============================================================================

cat("\n  6.2 Regime test: bid dispersion...\n")

m_disp <- list()

# Total bid dispersion (from BEC collapse)
d_sd <- dt[!is.na(log_bid_sd)]
if (nrow(d_sd) > 100) {
  cat("  Running log_bid_sd (total dispersion)...\n")
  m_disp[["total"]] <- run_losers_4("log_bid_sd", d_sd, price_only = FALSE)
}

# FL bid dispersion (from 04_cover_bid_flags)
if ("log_disp_fl" %in% names(dt)) {
  d_dfl <- dt[!is.na(log_disp_fl)]
  if (nrow(d_dfl) > 100) {
    cat(sprintf("  Running log_disp_fl (FL dispersion, N=%s)...\n", pfmt_int(nrow(d_dfl))))
    m_disp[["fl"]] <- feols(
      log_disp_fl ~ cover_tender + convite | item_f + year_f,
      data = d_dfl, cluster = ~item_f, fixef.rm = "none"
    )
  }
}

# Non-FL bid dispersion
if ("log_disp_nonfl" %in% names(dt)) {
  d_dnfl <- dt[!is.na(log_disp_nonfl)]
  if (nrow(d_dnfl) > 100) {
    cat(sprintf("  Running log_disp_nonfl (Non-FL dispersion, N=%s)...\n", pfmt_int(nrow(d_dnfl))))
    m_disp[["nonfl"]] <- feols(
      log_disp_nonfl ~ cover_tender + convite | item_f + year_f,
      data = d_dnfl, cluster = ~item_f, fixef.rm = "none"
    )
  }
}

# Regime test interpretation
if (!is.null(m_disp[["fl"]]) && !is.null(m_disp[["nonfl"]])) {
  b_fl    <- coef(m_disp[["fl"]])["cover_tender"]
  b_nonfl <- coef(m_disp[["nonfl"]])["cover_tender"]
  cat(sprintf("\n  REGIME TEST: beta(disp_FL) = %.4f, beta(disp_nonFL) = %.4f\n",
              b_fl, b_nonfl))
  if (b_fl > b_nonfl) {
    cat("  Interpretation: REGIME 1 (complementary cover bidding)\n")
    cat("  FL bids show more dispersion -> bids drawn independently above reference\n")
  } else {
    cat("  Interpretation: REGIME 2 (coordinated cover bidding)\n")
    cat("  FL bids show less dispersion -> bids clustered near winning price\n")
  }
}

# ============================================================================
# 6.3: Price ratio regression
# ============================================================================

cat("\n  6.3 Price ratio regressions...\n")

m_pratio <- NULL
d_pr <- dt[!is.na(price_ratio)]
if (nrow(d_pr) > 100) {
  m_pratio <- feols(
    price_ratio ~ cover_tender + cover_intensity + convite | item_f + year_f + pbu_f,
    data = d_pr, cluster = ~item_f, fixef.rm = "none"
  )
  cat(sprintf("  Price ratio: cover_tender=%.4f, cover_intensity=%.4f, N=%s\n",
              coef(m_pratio)["cover_tender"],
              coef(m_pratio)["cover_intensity"],
              pfmt_int(m_pratio$nobs)))
}

# ============================================================================
# 6.4: Cover intensity (continuous treatment)
# ============================================================================

cat("\n  6.4 Cover intensity regressions...\n")

m_intensity <- list()
for (dv in c("lneg_price", "ln_firms", "ln_bids")) {
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt
  m_intensity[[dv]] <- feols(
    as.formula(paste0(dv, " ~ cover_intensity + convite | item_f + year_f + pbu_f")),
    data = d, cluster = ~item_f, fixef.rm = "none"
  )
  cat(sprintf("  %s ~ cover_intensity: %.4f (%.4f)\n", dv,
              coef(m_intensity[[dv]])["cover_intensity"],
              sqrt(vcov(m_intensity[[dv]])["cover_intensity", "cover_intensity"])))
}

# ============================================================================
# Save all models
# ============================================================================

models <- list(
  prices      = m_prices,
  nfirms      = m_nfirms,
  nfirms_excl = m_nfirms_excl,
  nbids       = m_nbids,
  dispersion  = m_disp,
  price_ratio = m_pratio,
  intensity   = m_intensity
)

saveRDS(models, MODELS_CACHE_V2)
cat("  Models saved:", MODELS_CACHE_V2, "\n")
cat("  Done.\n")
