# =============================================================================
# 06_robustness.R — Robustness Checks
# Bitter Pills to Swallow — v4 (R/fixest)
# =============================================================================

cat("=== 06_robustness.R ===\n")
.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "utils.R"))

# --- Load fresh data (will re-winsorize per panel) ---------------------------
dt_raw <- readRDS(DATA_CACHE)
dt_raw <- dt_raw[has_litigated == TRUE & has_ordinary == TRUE]

# =============================================================================
# PART A: Under the Gun with Progressive Controls × 3 Winsorization Panels
# =============================================================================
cat("\n=== PART A: UTG Progressive Controls ===\n")

run_utg_progressive <- function(dt, panel_label, file_suffix) {
  # UTG subsample
  dt_utg <- dt[purchase_type == 1 | purchase_type == 2]
  dt_utg[, has_admin2 := any(purchase_type == 1), by = item]
  dt_utg[, has_lit2   := any(purchase_type == 2), by = item]
  dt_utg <- dt_utg[has_admin2 == TRUE & has_lit2 == TRUE]
  dt_utg_win <- dt_utg[po_firm_winner == 1]

  cat("  ", panel_label, "- UTG winners:", nrow(dt_utg_win), "\n")

  # 5 progressive columns (all with Item+Year+PBU FE, except col 5 uses YM)
  models <- list()

  # Col 1: is_admin only
  models[["(1)"]] <- feols(bid_price_log ~ is_admin | item_id + year_n + pbu_id,
                            data = dt_utg_win, cluster = ~pbu_id)

  # Col 2: + bid_qty_log
  models[["(2)"]] <- feols(bid_price_log ~ is_admin + bid_qty_log | item_id + year_n + pbu_id,
                            data = dt_utg_win, cluster = ~pbu_id)

  # Col 3: + bid_price_ref_log
  models[["(3)"]] <- feols(bid_price_log ~ is_admin + bid_qty_log + bid_price_ref_log | item_id + year_n + pbu_id,
                            data = dt_utg_win, cluster = ~pbu_id)

  # Col 4: + ln_n_firms
  models[["(4)"]] <- feols(bid_price_log ~ is_admin + bid_qty_log + bid_price_ref_log + ln_n_firms | item_id + year_n + pbu_id,
                            data = dt_utg_win, cluster = ~pbu_id)

  # Col 5: + Year-Month FE (replaces Year)
  models[["(5)"]] <- feols(bid_price_log ~ is_admin + bid_qty_log + bid_price_ref_log + ln_n_firms | item_id + ym_f + pbu_id,
                            data = dt_utg_win, cluster = ~pbu_id)

  save_table(models,
             paste0("UTG Progressive Controls — ", panel_label),
             paste0("underthegun_progressive_", file_suffix),
             coef_map = coef_labels)

  # Time interaction: is_admin × late_period
  interact_models <- list()
  interact_models[["Item+Yr+PBU"]] <- feols(
    bid_price_log ~ is_admin * late_period | item_id + year_n + pbu_id,
    data = dt_utg_win, cluster = ~pbu_id
  )
  interact_models[["+ qty"]] <- feols(
    bid_price_log ~ is_admin * late_period + bid_qty_log | item_id + year_n + pbu_id,
    data = dt_utg_win, cluster = ~pbu_id
  )
  interact_models[["+ ref_price"]] <- feols(
    bid_price_log ~ is_admin * late_period + bid_qty_log + bid_price_ref_log | item_id + year_n + pbu_id,
    data = dt_utg_win, cluster = ~pbu_id
  )
  interact_models[["+ ln_firms"]] <- feols(
    bid_price_log ~ is_admin * late_period + bid_qty_log + bid_price_ref_log + ln_n_firms | item_id + year_n + pbu_id,
    data = dt_utg_win, cluster = ~pbu_id
  )

  save_table(interact_models,
             paste0("UTG Time Interaction — ", panel_label),
             paste0("underthegun_time_interaction_", file_suffix),
             coef_map = coef_labels)

  invisible(models)
}

# Panel A: No winsorization
dt_nowin <- copy(dt_raw)
gen_log_vars(dt_nowin)
run_utg_progressive(dt_nowin, "No Winsorization", "nowin")

# Panel B: 1%/99% winsorization
dt_w1 <- copy(dt_raw)
winsorize_dt(dt_w1, c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids"), 0.01, 0.99)
gen_log_vars(dt_w1)
run_utg_progressive(dt_w1, "Winsorized 1/99", "w01")

# Panel C: 5%/95% winsorization
dt_w5 <- copy(dt_raw)
winsorize_dt(dt_w5, c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids"), 0.05, 0.95)
gen_log_vars(dt_w5)
run_utg_progressive(dt_w5, "Winsorized 5/95", "w05")

# =============================================================================
# PART B: All Main Tables × 3 Winsorization Levels
# =============================================================================
cat("\n=== PART B: Main Tables × Winsorization ===\n")

run_all_tables_winsor <- function(dt, panel_label, file_suffix) {
  dt_win <- dt[po_firm_winner == 1]

  # UTG subsample
  dt_utg <- dt[purchase_type == 1 | purchase_type == 2]
  dt_utg[, has_admin2 := any(purchase_type == 1), by = item]
  dt_utg[, has_lit2   := any(purchase_type == 2), by = item]
  dt_utg <- dt_utg[has_admin2 == TRUE & has_lit2 == TRUE]
  dt_utg_win <- dt_utg[po_firm_winner == 1]

  cat("  ", panel_label, "- Winners:", nrow(dt_win), ", UTG winners:", nrow(dt_utg_win), "\n")

  # Table 4: Reference Prices
  t4 <- run_feols4("bid_price_ref_log", "urgent", dt_win, ~pbu_id)
  save_table(t4, paste0("Table 4 Ref Prices — ", panel_label),
             paste0("table4_ref_prices_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 5: Quantities
  t5 <- run_feols4("bid_qty_log", "urgent", dt_win, ~pbu_id)
  save_table(t5, paste0("Table 5 Quantities — ", panel_label),
             paste0("table5_quantities_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 6A: Neg Prices Total
  t6a <- run_feols4("bid_price_log", "urgent", dt_win, ~pbu_id)
  save_table(t6a, paste0("Table 6A Neg Prices Total — ", panel_label),
             paste0("table6a_neg_prices_total_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 6B: Neg Prices Direct
  t6b <- run_feols4("bid_price_log", c("urgent", "bid_qty_log"), dt_win, ~pbu_id)
  save_table(t6b, paste0("Table 6B Neg Prices Direct — ", panel_label),
             paste0("table6b_neg_prices_direct_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 7A: Firms Total
  t7a <- run_feols4("ln_n_firms", "urgent", dt_win, ~pbu_id)
  save_table(t7a, paste0("Table 7A Firms Total — ", panel_label),
             paste0("table7a_firms_total_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 7B: Firms Direct
  t7b <- run_feols4("ln_n_firms", c("urgent", "bid_qty_log"), dt_win, ~pbu_id)
  save_table(t7b, paste0("Table 7B Firms Direct — ", panel_label),
             paste0("table7b_firms_direct_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 9A: Success Total (all obs)
  t9a <- run_feols4("po_firm_winner", "urgent", dt, ~pbu_id)
  save_table(t9a, paste0("Table 9A Success Total — ", panel_label),
             paste0("table9a_success_total_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 9B: Success Direct
  t9b <- run_feols4("po_firm_winner", c("urgent", "bid_qty_log"), dt, ~pbu_id)
  save_table(t9b, paste0("Table 9B Success Direct — ", panel_label),
             paste0("table9b_success_direct_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 10A: UTG Total
  t10a <- run_feols4("bid_price_log", "is_admin", dt_utg_win, ~pbu_id)
  save_table(t10a, paste0("Table 10A UTG Total — ", panel_label),
             paste0("table10a_underthegun_total_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  # Table 10B: UTG Direct
  t10b <- run_feols4("bid_price_log", c("is_admin", "bid_qty_log"), dt_utg_win, ~pbu_id)
  save_table(t10b, paste0("Table 10B UTG Direct — ", panel_label),
             paste0("table10b_underthegun_direct_", file_suffix),
             coef_map = coef_labels, add_rows = fe_rows())

  invisible(NULL)
}

# No winsorization
run_all_tables_winsor(dt_nowin, "No Winsorization", "nowin")

# 1%/99%
run_all_tables_winsor(dt_w1, "Winsorized 1/99", "w01")

# 5%/95%
run_all_tables_winsor(dt_w5, "Winsorized 5/95", "w05")

cat("\n=== 06_robustness.R complete ===\n")
