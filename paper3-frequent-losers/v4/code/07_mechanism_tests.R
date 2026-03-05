# ============================================================================
# 07_mechanism_tests.R — Mechanism tests with IV extension (v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# M1: Competitive displacement (+ IV-instrumented version)
# M2: Reference price calibration (+ IV version)
# M3: Reverse causality (lagged price -> FL entry)
# ============================================================================

cat("=== 07_mechanism_tests.R: Mechanism tests ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

mech_results <- list()

# ============================================================================
# M1: Competitive Displacement
# ============================================================================

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
cat(sprintf("  M1 (OLS): cover_tender -> log(n_genuine+1): %.4f\n", b_m1))

# M1 with IV
if ("fl_supply_loo" %in% names(dt)) {
  m1_iv <- tryCatch(
    feols(log_n_genuine ~ convite | item_f + year_f + pbu_f | cover_tender ~ fl_supply_loo,
          data = dt, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) { cat(sprintf("  M1 IV failed: %s\n", e$message)); NULL }
  )
  if (!is.null(m1_iv) && "fit_cover_tender" %in% names(coef(m1_iv))) {
    cat(sprintf("  M1 (IV): %.4f\n", coef(m1_iv)["fit_cover_tender"]))
  }
  mech_results[["m1_iv"]] <- m1_iv
}

# ============================================================================
# M2: Reference Price Calibration
# ============================================================================

cat("\n  M2: Reference price calibration...\n")

d_m2 <- dt[!is.na(price_ratio)]
cat(sprintf("  Valid price_ratio: %s\n", pfmt_int(nrow(d_m2))))

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

  cat(sprintf("  M2 (OLS): cover_tender -> price_ratio: %.4f\n",
              coef(m2_pbu)["cover_tender"]))
}

# ============================================================================
# M3: Reverse Causality
# ============================================================================

cat("\n  M3: Reverse causality...\n")

panel <- dt[, .(
  cover_tender = max(losers),
  mean_log_price = mean(lneg_price, na.rm = TRUE),
  n_obs = .N
), by = .(market_id, year)]

setkey(panel, market_id, year)
panel[, log_price_lag := shift(mean_log_price, 1L, type = "lag"), by = market_id]

d_m3 <- panel[!is.na(log_price_lag) & !is.na(cover_tender)]
cat(sprintf("  Market-year panel: %s rows\n", pfmt_int(nrow(d_m3))))

if (nrow(d_m3) > 100) {
  d_m3[, market_id_f := factor(market_id)]
  d_m3[, year_f := factor(year)]

  m3_lpm <- tryCatch(
    feols(cover_tender ~ log_price_lag | market_id_f + year_f,
          data = d_m3, cluster = ~market_id_f, fixef.rm = "none"),
    error = function(e) NULL
  )

  if (!is.null(m3_lpm)) {
    mech_results[["m3"]] <- m3_lpm
    b_m3 <- coef(m3_lpm)["log_price_lag"]
    se_m3 <- sqrt(vcov(m3_lpm)["log_price_lag", "log_price_lag"])
    p_m3 <- 2 * pnorm(-abs(b_m3 / se_m3))
    cat(sprintf("  M3: log_price_lag -> cover_tender: %.4f (%.4f), p=%.4f\n",
                b_m3, se_m3, p_m3))
  }
}

# ============================================================================
# Save
# ============================================================================

saveRDS(mech_results, MECHANISMS_CACHE_V4)
cat("  Mechanism results saved:", MECHANISMS_CACHE_V4, "\n")
cat("  Done.\n")
