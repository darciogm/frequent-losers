# ============================================================================
# 06_extensions.R — Extension analyses: real prices, extensive margin,
#                   efficiency, winner composition, bid spread, heterogeneity,
#                   fiscal cost quantification
# ============================================================================

cat("=== 06_extensions.R: Extension analyses ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data ------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

extensions <- list()

# ============================================================================
# 1. REAL PRICES (IPCA-Deflated)
# ============================================================================
cat("\n  --- Real prices (IPCA-deflated) ---\n")

if ("lpreco_final_real" %in% names(dt)) {
  extensions$prices_real <- run_didir_6("lpreco_final_real", dt, completed = TRUE)
  cat("    Done: 6 models\n")
} else {
  cat("    SKIPPED: lpreco_final_real not available in data\n")
}

# ============================================================================
# 2. EXTENSIVE MARGIN — Tender Completion Rate
# ============================================================================
cat("\n  --- Extensive margin (completion rate) ---\n")

# Use grupo_f instead of item_alt for FE (item FE absorbs too much for binary DV)
run_extensive <- function(data, window, add_pbu = FALSE) {
  sub <- data[data_oc_numb >= window[1] & data_oc_numb <= window[2]]
  fe <- if (add_pbu) "grupo_f + pbu_alt" else "grupo_f"
  fml <- as.formula(paste0("completed_binary ~ g65_pre + convite + lquantidade | ", fe))
  feols(fml, data = sub, cluster = ~item_alt, fixef.rm = "none")
}

windows <- list("6m" = WIN_6M, "12m" = WIN_12M, "18m" = WIN_18M)
ext_models <- list()
for (wname in names(windows)) {
  w <- windows[[wname]]
  cat("    ", wname, "...\n")
  ext_models[[paste0(wname, "_base")]] <- run_extensive(dt, w, add_pbu = FALSE)
  ext_models[[paste0(wname, "_pbu")]]  <- run_extensive(dt, w, add_pbu = TRUE)
}
extensions$extensive <- ext_models

# ============================================================================
# 3. EFFICIENCY — Final Price / Reference Price
# ============================================================================
cat("\n  --- Efficiency (final/reference price ratio) ---\n")

if ("efficiency" %in% names(dt)) {
  # Filter to completed items with non-missing efficiency
  extensions$efficiency <- run_didir_6("efficiency", dt, completed = TRUE)
  cat("    Done: 6 models\n")
} else {
  cat("    SKIPPED: efficiency not available in data\n")
}

# ============================================================================
# 4. WINNER COMPOSITION — SME Winner
# ============================================================================
cat("\n  --- Winner composition (SME winner) ---\n")

if ("sme_winner" %in% names(dt)) {
  extensions$sme_winner <- run_didir_6("sme_winner", dt, completed = TRUE)
  cat("    Done: 6 models\n")
} else {
  cat("    SKIPPED: sme_winner not available in data\n")
}

# ============================================================================
# 5. BID SPREAD — Difference between 1st and 2nd Bid
# ============================================================================
cat("\n  --- Bid spread (1st - 2nd bid, phase 1) ---\n")

if ("bid_spread" %in% names(dt)) {
  bs_result <- tryCatch({
    run_didir_6("bid_spread", dt, completed = TRUE)
  }, error = function(e) {
    cat("    WARNING: bid_spread regression failed:", conditionMessage(e), "\n")
    NULL
  })
  if (!is.null(bs_result)) {
    extensions$bid_spread <- bs_result
    cat("    Done: 6 models\n")
  }
} else {
  cat("    SKIPPED: bid_spread not available in data\n")
}

# ============================================================================
# 6. HETEROGENEOUS EFFECTS BY PBU TYPE (Direct vs Indirect Admin)
# ============================================================================
cat("\n  --- Heterogeneity by PBU type (adm_dir) ---\n")

if ("adm_dir" %in% names(dt)) {
  run_heterog_pbu <- function(dv, data, window, add_pbu = FALSE, completed = FALSE) {
    sub <- data[data_oc_numb >= window[1] & data_oc_numb <= window[2]]
    if (completed) sub <- sub[oc_item_status == 1L]
    # Drop missing adm_dir
    sub <- sub[!is.na(adm_dir)]
    fe <- if (add_pbu) "item_alt + pbu_alt" else "item_alt"
    fml <- as.formula(paste0(dv, " ~ g65_pre * adm_dir + convite + lquantidade | ", fe))
    feols(fml, data = sub, cluster = ~item_alt, fixef.rm = "none")
  }

  # Run for log prices and log firms (18m window, 2 specs each)
  cat("    Prices - base...\n")
  extensions$heterog_pbu_prices_base <-
    run_heterog_pbu("lpreco_final", dt, WIN_18M, add_pbu = FALSE, completed = TRUE)
  cat("    Prices - pbu...\n")
  extensions$heterog_pbu_prices_pbu <-
    run_heterog_pbu("lpreco_final", dt, WIN_18M, add_pbu = TRUE, completed = TRUE)
  cat("    Firms - base...\n")
  extensions$heterog_pbu_firms_base <-
    run_heterog_pbu("lnum_firms", dt, WIN_18M, add_pbu = FALSE, completed = FALSE)
  cat("    Firms - pbu...\n")
  extensions$heterog_pbu_firms_pbu <-
    run_heterog_pbu("lnum_firms", dt, WIN_18M, add_pbu = TRUE, completed = FALSE)
} else {
  cat("    SKIPPED: adm_dir not available in data\n")
}

# ============================================================================
# 7. HETEROGENEOUS EFFECTS BY ITEM VALUE (Median Split)
# ============================================================================
cat("\n  --- Heterogeneity by item value (median split) ---\n")

if ("high_value" %in% names(dt)) {
  dvs_heterog <- list(
    list(dv = "lpreco_final", completed = TRUE,  label = "prices"),
    list(dv = "lnum_firms",   completed = FALSE, label = "firms"),
    list(dv = "lnum_bids",    completed = FALSE, label = "bids"),
    list(dv = "dist1",        completed = TRUE,  label = "distance")
  )

  for (v in dvs_heterog) {
    for (hv in c(0L, 1L)) {
      hv_label <- if (hv == 1) "high" else "low"
      cat("    ", v$label, "- value:", hv_label, "...\n")
      sub <- dt[!is.na(high_value) & high_value == hv]
      extensions[[paste0("heterog_val_", v$label, "_", hv_label)]] <-
        run_didir(v$dv, sub, WIN_18M, add_pbu = FALSE, completed = v$completed)
    }
  }
} else {
  cat("    SKIPPED: high_value not available in data\n")
}

# ============================================================================
# 8. FISCAL COST QUANTIFICATION
# ============================================================================
cat("\n  --- Fiscal cost quantification ---\n")

# Load main models for price coefficient
main_models_path <- "/tmp/p2_models.rds"
if (file.exists(main_models_path)) {
  main_models <- readRDS(main_models_path)
  price_coef_18m <- coef(main_models$prices$`18m_base`)["g65_pre"]
  price_coef_pbu <- coef(main_models$prices$`18m_pbu`)["g65_pre"]

  # Total procurement value for G65 in pre-period (18m window)
  g65_pre <- dt[g65 == 1 & Pre == 1 & oc_item_status == 1L &
                 data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]

  if ("valor_total_final" %in% names(dt)) {
    total_value <- sum(g65_pre$valor_total_final, na.rm = TRUE)
  } else {
    total_value <- sum(g65_pre$preco_final, na.rm = TRUE)
  }

  # Price effect is in log → approximate percentage = exp(coef) - 1
  pct_effect_base <- exp(price_coef_18m) - 1
  pct_effect_pbu  <- exp(price_coef_pbu) - 1

  fiscal_saving_base <- total_value * abs(pct_effect_base)
  fiscal_saving_pbu  <- total_value * abs(pct_effect_pbu)

  extensions$fiscal_cost <- list(
    price_coef_base    = price_coef_18m,
    price_coef_pbu     = price_coef_pbu,
    pct_effect_base    = pct_effect_base,
    pct_effect_pbu     = pct_effect_pbu,
    total_value_g65_pre = total_value,
    fiscal_saving_base = fiscal_saving_base,
    fiscal_saving_pbu  = fiscal_saving_pbu
  )

  cat("    G65 pre-period total value: R$", pfmt(total_value, 0), "\n")
  cat("    Price effect (base):", pfmt(pct_effect_base * 100, 2), "%\n")
  cat("    Fiscal saving (base): R$", pfmt(fiscal_saving_base, 0), "\n")
  cat("    Price effect (PBU):", pfmt(pct_effect_pbu * 100, 2), "%\n")
  cat("    Fiscal saving (PBU): R$", pfmt(fiscal_saving_pbu, 0), "\n")
} else {
  cat("    SKIPPED: main models not available (run 02_analysis.R first)\n")
}

# ---- Save all extension models --------------------------------------------
extensions_path <- "/tmp/p2_extensions.rds"
saveRDS(extensions, extensions_path)
cat("  Extension models saved:", extensions_path, "\n")

# Free memory
rm(dt)
gc(verbose = FALSE)
