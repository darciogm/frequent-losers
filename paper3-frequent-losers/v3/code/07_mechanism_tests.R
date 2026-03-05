# ============================================================================
# 07_mechanism_tests.R — Mechanism tests (100% new)
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# M1: Competitive displacement — does cover bidding reduce genuine competition?
# M2: Reference price calibration — do FL tenders show different bid-to-ref ratios?
# M3: Reverse causality — does lagged price predict FL entry?
# ============================================================================

cat("=== 07_mechanism_tests.R: Mechanism tests ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data ---------------------------------------------------------------
if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

mech_results <- list()

# ============================================================================
# M1: Competitive Displacement
# ============================================================================
# Does FL presence reduce the number of genuine (non-FL) competitors?
# log(n_genuine + 1) ~ cover_tender | item_f + year_f

cat("  M1: Competitive displacement...\n")

dt[, log_n_genuine := log(n_genuine + 1)]

m1_general <- feols(
  log_n_genuine ~ cover_tender + convite | item_f + year_f,
  data = dt, cluster = ~item_f, fixef.rm = "none"
)

m1_pbu <- feols(
  log_n_genuine ~ cover_tender + convite | item_f + year_f + pbu_f,
  data = dt, cluster = ~item_f, fixef.rm = "none"
)

m1_pregao <- feols(
  log_n_genuine ~ cover_tender | item_f + year_f + pbu_f,
  data = dt[pregao == 1L], cluster = ~item_f, fixef.rm = "none"
)

m1_convite <- feols(
  log_n_genuine ~ cover_tender | item_f + year_f + pbu_f,
  data = dt[convite == 1L], cluster = ~item_f, fixef.rm = "none"
)

mech_results[["m1"]] <- list(
  general = m1_general, general_pbu = m1_pbu,
  pregao = m1_pregao, convite = m1_convite
)

b_m1 <- coef(m1_pbu)["cover_tender"]
cat(sprintf("  M1: cover_tender -> log(n_genuine+1): %.4f (%.4f)\n",
            b_m1, sqrt(vcov(m1_pbu)["cover_tender", "cover_tender"])))
if (b_m1 < 0) {
  cat("  Interpretation: FL presence REDUCES genuine competition (displacement)\n")
} else {
  cat("  Interpretation: FL presence does NOT reduce genuine competition\n")
}

# ============================================================================
# M2: Reference Price Calibration
# ============================================================================
# Do FL-present tenders show different bid-to-reference-price ratios?
# This tests whether cartels use FL bids to manipulate perceptions of the
# reference price.
# bid_to_ref ~ cover_tender | item_f + year_f + pbu_f

cat("\n  M2: Reference price calibration...\n")

# bid_to_ref = negotiated_price / reference_price (in logs = price_ratio)
d_m2 <- dt[!is.na(price_ratio)]
cat(sprintf("  Valid price_ratio observations: %s\n", pfmt_int(nrow(d_m2))))

if (nrow(d_m2) > 100) {
  m2_general <- feols(
    price_ratio ~ cover_tender + convite | item_f + year_f,
    data = d_m2, cluster = ~item_f, fixef.rm = "none"
  )

  m2_pbu <- feols(
    price_ratio ~ cover_tender + convite | item_f + year_f + pbu_f,
    data = d_m2, cluster = ~item_f, fixef.rm = "none"
  )

  m2_pregao <- feols(
    price_ratio ~ cover_tender | item_f + year_f + pbu_f,
    data = d_m2[pregao == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  m2_convite <- feols(
    price_ratio ~ cover_tender | item_f + year_f + pbu_f,
    data = d_m2[convite == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  mech_results[["m2"]] <- list(
    general = m2_general, general_pbu = m2_pbu,
    pregao = m2_pregao, convite = m2_convite
  )

  b_m2 <- coef(m2_pbu)["cover_tender"]
  cat(sprintf("  M2: cover_tender -> price_ratio: %.4f (%.4f)\n",
              b_m2, sqrt(vcov(m2_pbu)["cover_tender", "cover_tender"])))
} else {
  cat("  Insufficient data for M2.\n")
}

# ============================================================================
# M3: Reverse Causality
# ============================================================================
# Does lagged price predict FL entry? If so, cartels may target high-price markets.
# cover_tender_t ~ log_price_{t-1} | market_id_f + year_f
# Requires market-level panel (market_id x year)

cat("\n  M3: Reverse causality (lagged price -> FL entry)...\n")

# Collapse to market-year panel
panel <- dt[, .(
  cover_tender = max(losers),
  mean_log_price = mean(lneg_price, na.rm = TRUE),
  n_obs = .N
), by = .(market_id, year)]

# Sort and create lagged price
setkey(panel, market_id, year)
panel[, log_price_lag := shift(mean_log_price, 1L, type = "lag"), by = market_id]

# Filter to valid observations
d_m3 <- panel[!is.na(log_price_lag) & !is.na(cover_tender)]
cat(sprintf("  Market-year panel: %s rows\n", pfmt_int(nrow(d_m3))))

if (nrow(d_m3) > 100) {
  d_m3[, market_id_f := factor(market_id)]
  d_m3[, year_f := factor(year)]

  # Linear probability model
  m3_lpm <- tryCatch(
    feols(cover_tender ~ log_price_lag | market_id_f + year_f,
          data = d_m3, cluster = ~market_id_f, fixef.rm = "none"),
    error = function(e) {
      cat(sprintf("  M3 LPM failed: %s\n", e$message))
      NULL
    }
  )

  if (!is.null(m3_lpm)) {
    mech_results[["m3"]] <- m3_lpm

    b_m3 <- coef(m3_lpm)["log_price_lag"]
    se_m3 <- sqrt(vcov(m3_lpm)["log_price_lag", "log_price_lag"])
    p_m3 <- 2 * pnorm(-abs(b_m3 / se_m3))

    cat(sprintf("  M3: log_price_lag -> cover_tender: %.4f (%.4f), p=%.4f\n",
                b_m3, se_m3, p_m3))
    if (p_m3 > 0.10) {
      cat("  Interpretation: No evidence of reverse causality (good)\n")
    } else {
      cat("  WARNING: Lagged price predicts FL entry — potential reverse causality\n")
    }
  }
} else {
  cat("  Insufficient data for M3 panel.\n")
}

# ============================================================================
# Save results
# ============================================================================

saveRDS(mech_results, "/tmp/p3v2_mechanisms.rds")
cat("  Mechanism results saved: /tmp/p3v2_mechanisms.rds\n")
cat("  Done.\n")
