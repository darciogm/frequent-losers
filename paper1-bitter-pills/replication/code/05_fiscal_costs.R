# =============================================================================
# 05_fiscal_costs.R — Aggregate Fiscal Cost Estimates
# Bitter Pills to Swallow — v4 (R/fixest)
# =============================================================================

cat("=== 05_fiscal_costs.R ===\n")
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

# --- Load data ---------------------------------------------------------------
dt <- readRDS(DATA_CACHE)

# --- Analysis sample ---------------------------------------------------------
dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

dt_win <- dt[po_firm_winner == 1]

# --- Compute total spending --------------------------------------------------
dt_win[, total_spend := bid_price * bid_qty]

# Spending summaries
cat("\n=== Spending Summary ===\n")
spend_by_type <- dt_win[, .(
  n_obs = .N,
  total_spend = sum(total_spend, na.rm = TRUE),
  mean_spend = mean(total_spend, na.rm = TRUE)
), keyby = .(purchase_type)]
print(spend_by_type)

total_urgent_spend <- dt_win[urgent == 1, sum(total_spend, na.rm = TRUE)]
year_min <- dt_win[, min(year_n, na.rm = TRUE)]
year_max <- dt_win[, max(year_n, na.rm = TRUE)]
n_years <- year_max - year_min + 1
cat("Period:", year_min, "-", year_max, "(", n_years, "years)\n")
cat("Total urgent spending: R$", formatC(total_urgent_spend, format = "f",
                                          digits = 0, big.mark = ","), "\n")

# --- Helper: extract fiscal costs from a model ------------------------------
fiscal_from_model <- function(model, var_name, urgent_spend, n_years, label) {
  beta <- coef(model)[var_name]
  se <- sqrt(vcov(model)[var_name, var_name])

  pct_effect <- (exp(beta) - 1) * 100
  pct_lo <- (exp(beta - 1.96 * se) - 1) * 100
  pct_hi <- (exp(beta + 1.96 * se) - 1) * 100

  # Excess cost: share of urgent spending attributable to urgency premium
  excess_factor <- 1 - exp(-beta)
  total_excess <- urgent_spend * excess_factor
  annual_excess <- total_excess / n_years
  pct_of_total <- total_excess / urgent_spend * 100

  cat(sprintf("\n  %s\n", label))
  cat(sprintf("    β = %.4f (SE = %.4f)\n", beta, se))
  cat(sprintf("    Price premium: %.2f%% [95%% CI: %.2f%%, %.2f%%]\n",
              pct_effect, pct_lo, pct_hi))
  cat(sprintf("    Excess factor: %.4f\n", excess_factor))
  cat(sprintf("    Total excess cost: R$ %s\n",
              formatC(total_excess, format = "f", digits = 0, big.mark = ",")))
  cat(sprintf("    Annual average:    R$ %s\n",
              formatC(annual_excess, format = "f", digits = 0, big.mark = ",")))
  cat(sprintf("    As %% of urgent spend: %.2f%%\n", pct_of_total))

  data.frame(
    label = label, beta = beta, se = se,
    pct_effect = pct_effect, pct_lo = pct_lo, pct_hi = pct_hi,
    excess_factor = excess_factor,
    total_excess = total_excess, annual_excess = annual_excess,
    pct_of_total = pct_of_total
  )
}

# --- Open log file -----------------------------------------------------------
log_file <- file.path(RESU, "fiscal_costs_log.txt")
sink(log_file, split = TRUE)

cat("=============================================================================\n")
cat("FISCAL COST ESTIMATES — Bitter Pills v4 (G65 dataset)\n")
cat("=============================================================================\n")

# =============================================================================
# SECTION A: Total Effect (Price Impact)
# =============================================================================
cat("\n\n=== SECTION A: TOTAL PRICE EFFECT ===\n")
cat("DV: bid_price_log ~ urgent | FE\n")

fe_specs <- list(
  "Item+Year"     = "item_id + year_n",
  "Item+Year+PBU" = "item_id + year_n + pbu_id",
  "Item+YM+PBU"   = "item_id + ym_f + pbu_id"
)

results_a <- list()
for (nm in names(fe_specs)) {
  fml <- as.formula(paste0("bid_price_log ~ urgent | ", fe_specs[[nm]]))
  m <- feols(fml, data = dt_win, cluster = ~pbu_id)
  results_a[[nm]] <- fiscal_from_model(m, "urgent", total_urgent_spend, n_years,
                                        paste("Section A:", nm))
}

# =============================================================================
# SECTION B: Direct Effect (Controlling for Quantity)
# =============================================================================
cat("\n\n=== SECTION B: DIRECT PRICE EFFECT (qty control) ===\n")
cat("DV: bid_price_log ~ urgent + bid_qty_log | FE\n")

results_b <- list()
for (nm in names(fe_specs)) {
  fml <- as.formula(paste0("bid_price_log ~ urgent + bid_qty_log | ", fe_specs[[nm]]))
  m <- feols(fml, data = dt_win, cluster = ~pbu_id)
  results_b[[nm]] <- fiscal_from_model(m, "urgent", total_urgent_spend, n_years,
                                        paste("Section B:", nm))
}

# =============================================================================
# SECTION C: Under the Gun — Sanction Channel
# =============================================================================
cat("\n\n=== SECTION C: UNDER THE GUN (Sanction Channel) ===\n")
cat("DV: bid_price_log ~ is_admin | FE, urgent subsample\n")

# UTG subsample
dt_utg_win <- dt_win[purchase_type == 1 | purchase_type == 2]
dt_utg_win[, has_admin2 := any(purchase_type == 1), by = item]
dt_utg_win[, has_lit2   := any(purchase_type == 2), by = item]
dt_utg_win <- dt_utg_win[has_admin2 == TRUE & has_lit2 == TRUE]

total_lit_spend <- dt_utg_win[purchase_type == 2, sum(total_spend, na.rm = TRUE)]
cat("Litigated spending in UTG sample: R$",
    formatC(total_lit_spend, format = "f", digits = 0, big.mark = ","), "\n")

results_c <- list()
for (nm in names(fe_specs)) {
  fml <- as.formula(paste0("bid_price_log ~ is_admin | ", fe_specs[[nm]]))
  m <- feols(fml, data = dt_utg_win, cluster = ~pbu_id)

  beta <- coef(m)["is_admin"]
  se <- sqrt(vcov(m)["is_admin", "is_admin"])

  # is_admin is negative → litigated pays MORE
  # Sanction premium on litigated: exp(-β_admin) - 1
  sanction_pct <- (exp(-beta) - 1) * 100
  sanction_lo <- (exp(-(beta + 1.96 * se)) - 1) * 100
  sanction_hi <- (exp(-(beta - 1.96 * se)) - 1) * 100

  # Excess cost: factor = 1 - exp(β_admin) (β_admin < 0 → factor > 0)
  excess_factor <- 1 - exp(beta)
  total_excess <- total_lit_spend * excess_factor
  annual_excess <- total_excess / n_years

  cat(sprintf("\n  Section C: %s\n", nm))
  cat(sprintf("    β_admin = %.4f (SE = %.4f)\n", beta, se))
  cat(sprintf("    Sanction premium on litigated: %.2f%% [%.2f%%, %.2f%%]\n",
              sanction_pct, sanction_lo, sanction_hi))
  cat(sprintf("    Excess factor: %.4f\n", excess_factor))
  cat(sprintf("    Total sanction excess: R$ %s\n",
              formatC(total_excess, format = "f", digits = 0, big.mark = ",")))
  cat(sprintf("    Annual average: R$ %s\n",
              formatC(annual_excess, format = "f", digits = 0, big.mark = ",")))

  results_c[[nm]] <- data.frame(
    label = paste("Section C:", nm), beta = beta, se = se,
    sanction_pct = sanction_pct,
    excess_factor = excess_factor,
    total_excess = total_excess, annual_excess = annual_excess
  )
}

# --- Summary table -----------------------------------------------------------
cat("\n\n=== SUMMARY TABLE ===\n")
cat(sprintf("%-35s %10s %10s %15s %15s\n",
            "Specification", "Beta", "Premium%", "Total Excess", "Annual"))
cat(strrep("-", 90), "\n")

for (r in c(results_a, results_b)) {
  cat(sprintf("%-35s %10.4f %9.2f%% %15s %15s\n",
              r$label, r$beta, r$pct_effect,
              formatC(r$total_excess, format = "f", digits = 0, big.mark = ","),
              formatC(r$annual_excess, format = "f", digits = 0, big.mark = ",")))
}
for (r in results_c) {
  cat(sprintf("%-35s %10.4f %9.2f%% %15s %15s\n",
              r$label, r$beta, r$sanction_pct,
              formatC(r$total_excess, format = "f", digits = 0, big.mark = ","),
              formatC(r$annual_excess, format = "f", digits = 0, big.mark = ",")))
}

sink()
cat("\nFiscal costs log saved to:", log_file, "\n")

cat("=== 05_fiscal_costs.R complete ===\n")
