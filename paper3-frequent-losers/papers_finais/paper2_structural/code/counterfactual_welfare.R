# =============================================================================
# counterfactual_welfare.R
# Policy counterfactuals from the structural model of cover-bidder deployment
#
# Paper: "Frequent Losers in Public Procurement"
# Authors: Darcio Genicolo-Martins & Paulo Furquim de Azevedo (INSPER)
#
# Three counterfactuals:
#   CF1: Remove minimum-bidder requirement for convite
#   CF2: Optimal screening threshold given enforcement budget
#   CF3: Effect of increasing detection probability theta
#
# Outputs:
#   work/v7/tables/tab_counterfactual_welfare.tex
#   work/v7/tables/counterfactual_results.csv
#   work/v7/images/fig_counterfactual_screening.pdf
#   work/v7/images/fig_counterfactual_theta.pdf
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(ggplot2)
  library(scales)
})

setDTthreads(16L)

# ── Paths ────────────────────────────────────────────────────────────────────

REPO_ROOT <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"

DATA_DIR  <- file.path(REPO_ROOT, "data/processed")
V7_DIR    <- file.path(REPO_ROOT, "work/v7")
TAB_DIR   <- file.path(V7_DIR, "tables")
IMG_DIR   <- file.path(V7_DIR, "images")

for (d in c(TAB_DIR, IMG_DIR)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

cat("=== Counterfactual Welfare Analysis ===\n")
cat("Repo root:", REPO_ROOT, "\n")
cat("Data dir: ", DATA_DIR,  "\n\n")

# ── Colorblind-safe palette ───────────────────────────────────────────────────

CB_COLS <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7")

# =============================================================================
# 0. MODEL PARAMETERS (from structural_params.csv and paper text)
# =============================================================================

PARAMS_FILE <- file.path(TAB_DIR, "structural_params.csv")
if (!file.exists(PARAMS_FILE)) {
  stop("structural_params.csv not found at: ", PARAMS_FILE,
       "\nRun work/v7/scripts/structural_estimation.R first.")
}

params_raw <- fread(PARAMS_FILE)
# Named list for easy access
params <- setNames(as.list(params_raw$value), params_raw$param)

cat("Structural parameters loaded:\n")
cat("  epsilon_hat  :", round(as.numeric(params$epsilon_hat), 4), "\n")
cat("  sigma_c      :", round(as.numeric(params$sigma_c),     4), "\n")
cat("  delta_hat    :", round(as.numeric(params$delta_hat),   4), "\n")
cat("  pct_markup   :", round(as.numeric(params$pct_markup),  2), "%\n\n")

# Reduced-form price coefficients (log points)
BETA_OLS   <- 0.064   # OLS; main specification
BETA_IV    <- 0.194   # IV upper bound
BETA_CF    <- 0.036   # cross-fit (temporal)

# Aggregate spending constants (BRL, approximate from paper)
SPEND_FL_PRESENT <- 12e9   # ~R$12 billion (FL-present tenders)
SPEND_BEC_TOTAL  <- 30.8e9 # ~R$30.8 billion (total BEC 2009-2019)

# Minimum bidder rules
MIN_BIDDERS_CONVITE <- 3L
MIN_BIDDERS_PREGAO  <- 0L   # no minimum

# Phase codes
PHASE_CONVITE <- 2L
PHASE_PREGAO  <- 3L

# =============================================================================
# 1. LOAD AND PREPARE DATA
# =============================================================================

cat("--- Loading data ---\n")

# 1.1 BEC collapse dataset
BEC_FILE <- file.path(DATA_DIR, "BEC_collapse_final.parquet")
if (!file.exists(BEC_FILE)) {
  stop("BEC_collapse_final.parquet not found at: ", BEC_FILE)
}

cat("  Loading BEC_collapse_final.parquet...\n")
bec_raw <- as.data.table(read_parquet(BEC_FILE))
cat("  Rows loaded:", formatC(nrow(bec_raw), big.mark = ","), "\n")

# Check required columns
required_bec <- c("po_phase_code", "po_item_merge_key",
                   "n_firms", "bid_unit_price_negot_min")
missing_bec <- setdiff(required_bec, names(bec_raw))
if (length(missing_bec) > 0) {
  stop("Missing columns in BEC_collapse_final.parquet: ",
       paste(missing_bec, collapse = ", "))
}

# 1.2 LOSERS dataset
LOSERS_FILE <- file.path(DATA_DIR, "LOSERS_rebuilt.parquet")
if (!file.exists(LOSERS_FILE)) {
  stop("LOSERS_rebuilt.parquet not found at: ", LOSERS_FILE)
}

cat("  Loading LOSERS_rebuilt.parquet...\n")
losers_raw <- as.data.table(read_parquet(LOSERS_FILE))
cat("  Rows loaded:", formatC(nrow(losers_raw), big.mark = ","), "\n")

# Check LOSERS columns
if (!"losers_count" %in% names(losers_raw)) {
  # Fallback: try n_losers or fl_count
  alt_col <- intersect(c("n_losers", "fl_count", "n_fl"), names(losers_raw))
  if (length(alt_col) == 0) {
    stop("Cannot find losers_count or equivalent in LOSERS_rebuilt.parquet. ",
         "Available columns: ", paste(names(losers_raw), collapse = ", "))
  }
  setnames(losers_raw, alt_col[1], "losers_count")
  cat("  Note: renamed", alt_col[1], "to losers_count\n")
}

# 1.3 ROC data
ROC_FILE <- file.path(TAB_DIR, "roc_detection_full.csv")
if (!file.exists(ROC_FILE)) {
  stop("roc_detection_full.csv not found at: ", ROC_FILE,
       "\nRun work/v7/scripts/roc_detection.py first.")
}

cat("  Loading roc_detection_full.csv...\n")
roc_dt <- fread(ROC_FILE)
cat("  ROC rows:", nrow(roc_dt), "\n\n")

# =============================================================================
# 2. CONSTRUCT ANALYSIS DATASET
# =============================================================================

cat("--- Constructing analysis dataset ---\n")

# Extract OC code (first 22 characters of po_item_merge_key)
bec_raw[, oc_code := substr(po_item_merge_key, 1L, 22L)]

# Filter to phases 2 and 3
bec <- bec_raw[po_phase_code %in% c(PHASE_CONVITE, PHASE_PREGAO)]
cat("  After phase filter:", formatC(nrow(bec), big.mark = ","), "rows\n")

# Keep only tenders with valid price and firm count
bec <- bec[!is.na(bid_unit_price_negot_min) & bid_unit_price_negot_min > 0 &
           !is.na(n_firms) & n_firms >= 1]
cat("  After validity filter:", formatC(nrow(bec), big.mark = ","), "rows\n")

# Detect the key columns for LOSERS join
losers_key_col <- intersect(c("numerodaoc", "oc_code"), names(losers_raw))
item_key_col   <- intersect(c("codigoitem", "códigoitem", "item_code",
                               "codigo_item"), names(losers_raw))

if (length(losers_key_col) == 0) {
  stop("Cannot identify OC-code column in LOSERS_rebuilt.parquet. ",
       "Available: ", paste(names(losers_raw), collapse = ", "))
}
if (length(item_key_col) == 0) {
  stop("Cannot identify item-code column in LOSERS_rebuilt.parquet. ",
       "Available: ", paste(names(losers_raw), collapse = ", "))
}

losers_key_col <- losers_key_col[1]
item_key_col   <- item_key_col[1]

cat("  LOSERS OC key   :", losers_key_col, "\n")
cat("  LOSERS item key :", item_key_col,   "\n")

# Standardise LOSERS column names for join
losers <- copy(losers_raw)
setnames(losers, c(losers_key_col, item_key_col), c("oc_code", "item_code_l"))

# Detect item_code column in BEC
bec_item_col <- intersect(c("item_code", "codigoitem", "códigoitem",
                             "codigo_item"), names(bec))
if (length(bec_item_col) == 0) {
  # Extract from po_item_merge_key chars 23+
  # item_code starts at char 23 per CLAUDE.md BEC key structure
  bec[, item_code := substr(po_item_merge_key, 23L, nchar(po_item_merge_key))]
  bec_item_col <- "item_code"
  cat("  Extracted item_code from po_item_merge_key\n")
} else {
  bec_item_col <- bec_item_col[1]
  if (bec_item_col != "item_code") setnames(bec, bec_item_col, "item_code")
}

# Merge losers count — aggregate at oc_code level because BEC item_code
# contains description text that doesn't match LOSERS clean item codes
losers_agg <- losers[, .(losers_count = sum(losers_count, na.rm=TRUE)), by=oc_code]
bec <- merge(bec, losers_agg, by = "oc_code", all.x = TRUE)
bec[is.na(losers_count), losers_count := 0L]

# Compute genuine firm count (total minus FL cover bidders)
bec[, fl_count     := losers_count]
bec[, genuine_n    := pmax(0L, n_firms - fl_count)]
bec[, fl_present   := as.integer(fl_count > 0L)]
bec[, phase_label  := fifelse(po_phase_code == PHASE_CONVITE, "convite", "pregao")]

cat("  FL-present tenders :", formatC(sum(bec$fl_present), big.mark = ","), "\n")
cat("  Total tenders       :", formatC(nrow(bec), big.mark = ","), "\n")
cat("  FL-present share    :", round(100 * mean(bec$fl_present), 2), "%\n\n")

# =============================================================================
# CF1: REMOVE MINIMUM-BIDDER REQUIREMENT (CONVITE)
# =============================================================================

cat("=== CF1: Remove minimum-bidder requirement (convite) ===\n")

# Convite-only FL-present tenders
cf1_dt <- bec[po_phase_code == PHASE_CONVITE & fl_present == 1L]
cat("  Convite FL-present tenders:", formatC(nrow(cf1_dt), big.mark = ","), "\n")

# Constraint binds when genuine_n < 3
# (the cartel needed at least 3 - genuine_n cover bidders just to satisfy the rule)
cf1_dt[, constraint_binds := as.integer(genuine_n < MIN_BIDDERS_CONVITE)]
cf1_dt[, m_constraint     := pmax(0L, MIN_BIDDERS_CONVITE - genuine_n)]

n_binds <- sum(cf1_dt$constraint_binds)
n_pure  <- sum(cf1_dt$genuine_n == 0L)  # pure cover-bidding: no genuine bidders
n_total <- nrow(cf1_dt)

cat("  Constraint binds (genuine_n < 3):", formatC(n_binds, big.mark = ","),
    sprintf("(%.1f%%)", 100 * n_binds / n_total), "\n")
cat("  Pure cover-bidding (genuine_n=0):", formatC(n_pure, big.mark = ","),
    sprintf("(%.1f%%)", 100 * n_pure / n_total), "\n")

# Spending in constraint-binding tenders
# Assumption: removing the rule eliminates ALL FL presence in tenders where
# the constraint binds and the interior optimum is m*=0
# (i.e., cartels only deployed cover bidders to satisfy the rule)
# Key identification: tenders where genuine_n=0 are pure cover-bidding tenders
spend_bind   <- cf1_dt[constraint_binds == 1L,
                        sum(bid_unit_price_negot_min, na.rm = TRUE)]
spend_pure   <- cf1_dt[genuine_n == 0L,
                        sum(bid_unit_price_negot_min, na.rm = TRUE)]
spend_convite_fl <- cf1_dt[, sum(bid_unit_price_negot_min, na.rm = TRUE)]

cat("  Total convite FL-present spending : R$",
    formatC(spend_convite_fl / 1e9, digits = 3, format = "f"), "B\n")
cat("  Constraint-binding spending       : R$",
    formatC(spend_bind / 1e9, digits = 3, format = "f"), "B\n")
cat("  Pure cover-bidding spending       : R$",
    formatC(spend_pure / 1e9, digits = 3, format = "f"), "B\n")

# Welfare gains: if FL removed from constraint-binding tenders, price falls by beta
# Three price coefficient scenarios
cf1_results <- data.table(
  scenario    = c("OLS (beta=0.064)", "Cross-fit (beta=0.036)", "IV (beta=0.194)"),
  beta        = c(BETA_OLS, BETA_CF, BETA_IV),
  spend_base  = spend_bind
)
cf1_results[, price_pct    := 1 - exp(-beta)]   # approx price reduction if FL removed
cf1_results[, welfare_gain := spend_base * price_pct]

# Narrow definition: only pure cover-bidding tenders (strongest assumption)
cf1_results[, welfare_gain_pure := spend_pure * (1 - exp(-beta))]

cat("\n  CF1 Welfare gains (constraint-binding tenders):\n")
for (i in seq_len(nrow(cf1_results))) {
  cat(sprintf("    [%s] price_pct=%.2f%%, gain=R$%.2fM (pure cover: R$%.2fM)\n",
              cf1_results$scenario[i],
              cf1_results$price_pct[i] * 100,
              cf1_results$welfare_gain[i] / 1e6,
              cf1_results$welfare_gain_pure[i] / 1e6))
}

# =============================================================================
# CF2: OPTIMAL SCREENING THRESHOLD GIVEN ENFORCEMENT BUDGET
# =============================================================================

cat("\n=== CF2: Optimal screening threshold ===\n")

# Compute total spending associated with FL firms at each ROC threshold
# For each threshold, n_flagged firms are flagged
# Tenders involving AT LEAST ONE flagged firm contribute to expected benefit
# We need: for each threshold, what fraction of FL-present spending is covered?

# The ROC table has n_flagged at each IQR multiplier.
# At multiplier=1.5 (baseline), n_flagged=2735 (all FL firms)
# At higher thresholds, fewer firms are flagged (subset of most egregious FL)
# TPR = fraction of CADE co-bidders captured

# Total FL-present spending (from data)
spend_fl_total <- bec[fl_present == 1L, sum(bid_unit_price_negot_min, na.rm = TRUE)]
cat("  Total FL-present spending: R$",
    formatC(spend_fl_total / 1e9, digits = 3, format = "f"), "B\n")

# At baseline threshold (1.5x IQR, n_flagged=2735), all FL firms are flagged.
# At stricter thresholds, only the most active FL firms (larger n_flagged → lower threshold)
# The ROC data: at multiplier=0, threshold=3, n_flagged=7639 (MORE firms, LOWER bar)
# At multiplier=1.5, threshold=13.5, n_flagged=2735 (FL definition baseline)
# At multiplier>1.5, n_flagged decreases further

# Spending coverage: approximate as (n_flagged_at_t / n_flagged_baseline) * spend_fl_total
# More precisely, higher-activity FL firms (flagged at strict thresholds) likely
# account for a disproportionate share of tenders. Use TPR as proxy for coverage.
n_flagged_baseline <- roc_dt[abs(multiplier - 1.5) < 0.01, n_flagged[1]]
cat("  n_flagged at baseline (1.5x IQR):", n_flagged_baseline, "\n")

roc_dt[, spend_covered := spend_fl_total * tpr]   # tpr proxies fraction of cartel spending covered
roc_dt[, n_fl_baseline := n_flagged_baseline]

# Deterrence rates
DETERRENCE_RATES <- c(0.25, 0.50, 0.75, 1.00)
BASE_DETERRENCE  <- 0.50

# Vary cost per investigation from R$10K to R$1M
cost_grid <- 10^seq(log10(10000), log10(1000000), length.out = 50)

# For each (cost, deterrence_rate) combination, find optimal threshold
cf2_results_list <- list()

for (det in DETERRENCE_RATES) {
  for (cost_inv in cost_grid) {
    # For each threshold in ROC table:
    #   benefit = beta * deterrence * spend_covered
    #   cost    = cost_per_investigation * n_flagged
    #   net     = benefit - cost
    tmp <- copy(roc_dt)
    tmp[, investigation_cost := cost_inv * n_flagged]
    tmp[, expected_benefit   := BETA_OLS * det * spend_covered]
    tmp[, net_welfare        := expected_benefit - investigation_cost]

    best_idx <- which.max(tmp$net_welfare)
    best_row <- tmp[best_idx]

    cf2_results_list[[length(cf2_results_list) + 1]] <- data.table(
      deterrence_rate     = det,
      cost_per_inv        = cost_inv,
      optimal_multiplier  = best_row$multiplier,
      optimal_threshold   = best_row$threshold,
      optimal_n_flagged   = best_row$n_flagged,
      optimal_tpr         = best_row$tpr,
      optimal_net_welfare = best_row$net_welfare,
      net_welfare_positive = as.integer(best_row$net_welfare > 0)
    )
  }
}

cf2_results <- rbindlist(cf2_results_list)

# Find break-even cost for each deterrence rate
cat("  Break-even investigation costs:\n")
cf2_breakeven <- cf2_results[net_welfare_positive == 1L,
                              .(min_cost = min(cost_per_inv)),
                              by = deterrence_rate]
setorder(cf2_breakeven, deterrence_rate)
for (i in seq_len(nrow(cf2_breakeven))) {
  cat(sprintf("    deterrence=%.2f: screening welfare-positive above R$%.0f/investigation\n",
              cf2_breakeven$deterrence_rate[i],
              cf2_breakeven$min_cost[i]))
}

# =============================================================================
# CF3: EFFECT OF INCREASING DETECTION PROBABILITY θ
# =============================================================================

cat("\n=== CF3: Detection probability theta ===\n")

# Proxy theta with PBU size (number of tenders per PBU → oversight proxy)
# Larger PBUs have more procurement staff → higher θ

# Check for PBU column
pbu_col <- intersect(c("codigounidadecompradora", "pbu_code", "pbu",
                        "codigo_unidade_compradora", "pbu_f"), names(bec))
if (length(pbu_col) == 0) {
  # Try to extract from po_item_merge_key chars 1-11
  cat("  No PBU column found; extracting from po_item_merge_key (chars 1-11)\n")
  bec[, pbu_code := substr(po_item_merge_key, 1L, 11L)]
  pbu_col <- "pbu_code"
} else {
  pbu_col <- pbu_col[1]
  if (pbu_col != "pbu_code") {
    bec[, pbu_code := get(pbu_col)]
    pbu_col <- "pbu_code"
  }
}

# PBU-level statistics: total tenders (size proxy), mean FL count
pbu_stats <- bec[, .(
  n_tenders    = .N,
  mean_fl      = mean(fl_count, na.rm = TRUE),
  mean_fl_present = mean(fl_present, na.rm = TRUE),
  total_spend  = sum(bid_unit_price_negot_min, na.rm = TRUE),
  mean_spend   = mean(bid_unit_price_negot_min, na.rm = TRUE)
), by = pbu_code]

cat("  PBUs identified:", nrow(pbu_stats), "\n")

# Assign PBU size quartile (Q1 = smallest PBUs, Q4 = largest)
pbu_stats[, pbu_size_q := cut(n_tenders,
                               breaks = quantile(n_tenders, probs = 0:4/4,
                                                 na.rm = TRUE),
                               labels = c("Q1 (Small)", "Q2", "Q3", "Q4 (Large)"),
                               include.lowest = TRUE)]

# Merge PBU size quartile back to main dataset
bec <- merge(bec, pbu_stats[, .(pbu_code, n_tenders, pbu_size_q)],
             by = "pbu_code", all.x = TRUE)

# Mean FL count by PBU size quartile
cf3_dt <- bec[!is.na(pbu_size_q),
              .(mean_fl   = mean(fl_count, na.rm = TRUE),
                mean_m    = mean(fl_count[fl_present == 1L], na.rm = TRUE),
                n_tenders = .N,
                share_fl  = mean(fl_present, na.rm = TRUE)),
              by = pbu_size_q]
setorder(cf3_dt, pbu_size_q)

cat("  Mean FL count (m) by PBU size quartile:\n")
print(cf3_dt[, .(pbu_size_q, mean_fl = round(mean_fl, 3),
                 mean_m_conditional = round(mean_m, 3),
                 share_fl = round(share_fl, 3))])

# Check if m is decreasing in PBU size (larger PBU → higher θ → lower m)
m_q1 <- cf3_dt[pbu_size_q == "Q1 (Small)", mean_fl]
m_q4 <- cf3_dt[pbu_size_q == "Q4 (Large)", mean_fl]
m_decreasing <- m_q4 < m_q1

cat("\n  Predicted monotonicity (m decreasing in PBU size / theta):",
    ifelse(m_decreasing, "CONFIRMED", "NOT confirmed"), "\n")

# Calibrate elasticity ∂m/∂θ using PBU quartile variation
# Proxy θ_q with quartile rank (1, 2, 3, 4) normalized to [0,1]
cf3_dt[, theta_proxy := (as.integer(pbu_size_q) - 1) / 3]
cf3_dt[, theta_rank  := as.integer(pbu_size_q)]

# OLS regression of log(mean_fl + 0.001) on log(theta_proxy + 0.1)
# to estimate d(log m)/d(log theta) = elasticity
# Use pbu_stats (PBU level)
pbu_theta <- merge(bec[!is.na(pbu_size_q)],
                   cf3_dt[, .(pbu_size_q, theta_proxy)],
                   by = "pbu_size_q", all.x = TRUE)

pbu_level <- pbu_theta[fl_present == 1L,
                        .(mean_fl = mean(fl_count, na.rm = TRUE),
                          theta_proxy = mean(theta_proxy, na.rm = TRUE)),
                        by = pbu_code]

if (nrow(pbu_level) >= 10 && var(pbu_level$theta_proxy, na.rm = TRUE) > 0) {
  pbu_level[, log_m     := log(mean_fl + 0.01)]
  pbu_level[, log_theta := log(theta_proxy + 0.1)]
  cf3_reg <- lm(log_m ~ log_theta, data = pbu_level)
  elasticity_theta <- coef(cf3_reg)["log_theta"]
  cat("  Estimated elasticity d(log m)/d(log theta):",
      round(elasticity_theta, 3), "\n")
} else {
  elasticity_theta <- -0.30   # plausible default
  cat("  Insufficient variation; using default elasticity =", elasticity_theta, "\n")
}

# Welfare gain from 10% increase in theta
# For each 10% increase in theta:
#   Δm = elasticity * 0.10 * mean(m)  [absolute change in FL count per tender]
#   ΔPrice = -BETA_OLS * |Δm/m|       [approximate price reduction]
#   If theta increases enough to push m* to 0 for some tenders, FL-present share falls

mean_m_overall <- bec[fl_present == 1L, mean(fl_count, na.rm = TRUE)]
mean_m_all     <- bec[, mean(fl_count, na.rm = TRUE)]  # includes zeros

cat("  Mean m (FL-present tenders):", round(mean_m_overall, 3), "\n")
cat("  Mean m (all tenders)        :", round(mean_m_all, 3), "\n")

# Compute welfare effects for theta increases of 10% to 100%
theta_grid <- seq(0.10, 1.00, by = 0.10)
cf3_welfare <- data.table(theta_increase_pct = theta_grid * 100)

cf3_welfare[, pct_m_reduction    := pmin(1, abs(elasticity_theta) * theta_increase_pct / 100)]
cf3_welfare[, new_fl_share       := mean(bec$fl_present) * (1 - pct_m_reduction)]
cf3_welfare[, fl_spend_reduced   := SPEND_FL_PRESENT * pct_m_reduction]
cf3_welfare[, welfare_gain_ols   := fl_spend_reduced * (1 - exp(-BETA_OLS))]
cf3_welfare[, welfare_gain_iv    := fl_spend_reduced * (1 - exp(-BETA_IV))]
cf3_welfare[, welfare_gain_cf    := fl_spend_reduced * (1 - exp(-BETA_CF))]

cat("\n  Welfare gain per 10% increase in theta (OLS, R$ million):\n")
w_per10 <- cf3_welfare[theta_increase_pct == 10, welfare_gain_ols / 1e6]
cat(sprintf("    R$%.1fM\n", w_per10))

# =============================================================================
# 3. SUMMARY TABLE: ALL THREE COUNTERFACTUALS
# =============================================================================

cat("\n--- Building summary output ---\n")

# CF1 summary (OLS, full constraint-binding)
cf1_ols_gain    <- cf1_results[scenario == "OLS (beta=0.064)", welfare_gain]
cf1_ols_pure    <- cf1_results[scenario == "OLS (beta=0.064)", welfare_gain_pure]
cf1_iv_gain     <- cf1_results[scenario == "IV (beta=0.194)",  welfare_gain]
cf1_cf_gain     <- cf1_results[scenario == "Cross-fit (beta=0.036)", welfare_gain]

# CF2 summary (baseline deterrence=0.5, optimal threshold)
cf2_base <- cf2_results[deterrence_rate == 0.50]
# Net welfare at R$100K/investigation (reference budget)
cf2_100k <- cf2_base[which.min(abs(cost_per_inv - 100000))]
# Net welfare at R$1M/investigation
cf2_1m   <- cf2_base[which.min(abs(cost_per_inv - 1000000))]
# Net welfare at R$10K/investigation
cf2_10k  <- cf2_base[which.min(abs(cost_per_inv - 10000))]

# CF3 summary
cf3_10pct <- cf3_welfare[theta_increase_pct == 10]
cf3_50pct <- cf3_welfare[theta_increase_pct == 50]

# Collect all results in a single CSV
cf_csv <- rbindlist(list(
  # CF1
  data.table(
    counterfactual = "CF1_remove_min_bidder",
    metric         = "n_constrained_tenders",
    value          = n_binds,
    unit           = "tenders"
  ),
  data.table(
    counterfactual = "CF1_remove_min_bidder",
    metric         = "n_pure_cover_tenders",
    value          = n_pure,
    unit           = "tenders"
  ),
  data.table(
    counterfactual = "CF1_remove_min_bidder",
    metric         = "fraction_constraint_binds",
    value          = round(n_binds / n_total, 4),
    unit           = "fraction"
  ),
  data.table(
    counterfactual = "CF1_remove_min_bidder",
    metric         = "welfare_gain_ols_BRL",
    value          = round(cf1_ols_gain),
    unit           = "BRL"
  ),
  data.table(
    counterfactual = "CF1_remove_min_bidder",
    metric         = "welfare_gain_iv_BRL",
    value          = round(cf1_iv_gain),
    unit           = "BRL"
  ),
  data.table(
    counterfactual = "CF1_remove_min_bidder",
    metric         = "welfare_gain_pure_cover_ols_BRL",
    value          = round(cf1_ols_pure),
    unit           = "BRL"
  ),
  # CF2
  data.table(
    counterfactual = "CF2_optimal_threshold",
    metric         = "net_welfare_cost100k_BRL",
    value          = round(cf2_100k$optimal_net_welfare),
    unit           = "BRL"
  ),
  data.table(
    counterfactual = "CF2_optimal_threshold",
    metric         = "optimal_multiplier_cost100k",
    value          = round(cf2_100k$optimal_multiplier, 3),
    unit           = "IQR_multiplier"
  ),
  data.table(
    counterfactual = "CF2_optimal_threshold",
    metric         = "optimal_n_flagged_cost100k",
    value          = cf2_100k$optimal_n_flagged,
    unit           = "firms"
  ),
  data.table(
    counterfactual = "CF2_optimal_threshold",
    metric         = "net_welfare_cost1M_BRL",
    value          = round(cf2_1m$optimal_net_welfare),
    unit           = "BRL"
  ),
  # CF3
  data.table(
    counterfactual = "CF3_theta_increase",
    metric         = "elasticity_m_theta",
    value          = round(elasticity_theta, 4),
    unit           = "log_log"
  ),
  data.table(
    counterfactual = "CF3_theta_increase",
    metric         = "welfare_gain_10pct_theta_ols_BRL",
    value          = round(cf3_10pct$welfare_gain_ols),
    unit           = "BRL"
  ),
  data.table(
    counterfactual = "CF3_theta_increase",
    metric         = "welfare_gain_50pct_theta_ols_BRL",
    value          = round(cf3_50pct$welfare_gain_ols),
    unit           = "BRL"
  ),
  data.table(
    counterfactual = "CF3_theta_increase",
    metric         = "welfare_gain_10pct_theta_iv_BRL",
    value          = round(cf3_10pct$welfare_gain_iv),
    unit           = "BRL"
  )
), fill = TRUE)

fwrite(cf_csv, file.path(TAB_DIR, "counterfactual_results.csv"))
cat("  Saved: counterfactual_results.csv\n")

# =============================================================================
# 4. LaTeX TABLE
# =============================================================================

cat("  Writing LaTeX table...\n")

# Helper: format large numbers for LaTeX
fmt_brl <- function(x, digits = 0) {
  if (is.na(x)) return("---")
  if (abs(x) >= 1e9) return(sprintf("R\\$%.2fB", x / 1e9))
  if (abs(x) >= 1e6) return(sprintf("R\\$%.1fM", x / 1e6))
  return(sprintf("R\\$%.0f", x))
}
fmt_num <- function(x, digits = 0) {
  if (is.na(x)) return("---")
  formatC(x, big.mark = ",", format = "f", digits = digits)
}

tex_lines <- c(
  "% ===========================================================================",
  "% tab_counterfactual_welfare.tex",
  "% Policy counterfactuals: structural model of cover-bidder deployment",
  "% Auto-generated by work/v7/scripts/counterfactual_welfare.R",
  "% ===========================================================================",
  "",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Policy Counterfactuals from the Structural Model}",
  "\\label{tab:counterfactual_welfare}",
  "\\small",
  "\\begin{tabular}{lp{6.5cm}rr}",
  "\\toprule",
  "Counterfactual & Description & OLS Estimate & IV Estimate \\\\",
  "\\midrule",
  "\\multicolumn{4}{l}{\\textit{Panel A: Remove Minimum-Bidder Requirement (Convite)}} \\\\",
  "\\addlinespace[2pt]",
  paste0(
    " & Convite FL-present tenders (total) & \\multicolumn{2}{c}{",
    fmt_num(n_total, 0), "} \\\\"),
  paste0(
    " & Constraint-binding tenders ($n_{\\text{genuine}} < 3$) & \\multicolumn{2}{c}{",
    fmt_num(n_binds, 0), " (",
    round(100 * n_binds / n_total, 1), "\\%)} \\\\"),
  paste0(
    " & Pure cover-bidding tenders ($n_{\\text{genuine}} = 0$) & \\multicolumn{2}{c}{",
    fmt_num(n_pure, 0), " (",
    round(100 * n_pure / n_total, 1), "\\%)} \\\\"),
  " & \\addlinespace[4pt] & & \\\\",
  paste0(
    " & Annual welfare gain (constraint-binding) & ",
    fmt_brl(cf1_ols_gain / 10), " & ",
    fmt_brl(cf1_iv_gain / 10), " \\\\"),
  paste0(
    " & Annual welfare gain (pure cover-bidding) & ",
    fmt_brl(cf1_ols_pure / 10), " & ",
    fmt_brl(cf1_results[scenario == "IV (beta=0.194)", welfare_gain_pure] / 10),
    " \\\\"),
  "\\addlinespace[6pt]",
  "\\multicolumn{4}{l}{\\textit{Panel B: Optimal Screening Threshold (Deterrence = 50\\%)}} \\\\",
  "\\addlinespace[2pt]",
  paste0(
    " & Net welfare at R\\$100K/investigation & \\multicolumn{2}{c}{",
    fmt_brl(cf2_100k$optimal_net_welfare), "} \\\\"),
  paste0(
    " & Optimal IQR multiplier at R\\$100K & \\multicolumn{2}{c}{",
    round(cf2_100k$optimal_multiplier, 2), "\\texttimes{} IQR} \\\\"),
  paste0(
    " & Firms flagged at optimal threshold & \\multicolumn{2}{c}{",
    fmt_num(cf2_100k$optimal_n_flagged, 0), "} \\\\"),
  paste0(
    " & Net welfare at R\\$1M/investigation & \\multicolumn{2}{c}{",
    fmt_brl(cf2_1m$optimal_net_welfare), "} \\\\"),
  "\\addlinespace[6pt]",
  "\\multicolumn{4}{l}{\\textit{Panel C: Welfare Gain from Increasing Detection Probability ($\\theta$)}} \\\\",
  "\\addlinespace[2pt]",
  paste0(
    " & Estimated elasticity $\\partial \\log m^* / \\partial \\log \\theta$ & \\multicolumn{2}{c}{",
    round(elasticity_theta, 3), "} \\\\"),
  paste0(
    " & Welfare gain per 10\\% $\\uparrow\\theta$ & ",
    fmt_brl(cf3_10pct$welfare_gain_ols), " & ",
    fmt_brl(cf3_10pct$welfare_gain_iv), " \\\\"),
  paste0(
    " & Welfare gain per 50\\% $\\uparrow\\theta$ & ",
    fmt_brl(cf3_50pct$welfare_gain_ols), " & ",
    fmt_brl(cf3_50pct$welfare_gain_iv), " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\small",
  "\\item \\textit{Notes:} Panel A reports the welfare effect of removing the",
  "  convite minimum-bidder requirement (Lei 8.666/93, Art.~22, \\S7).",
  "  Constraint-binding tenders are those with genuine bidders $n < 3$,",
  "  where the cartel must deploy cover bidders solely to satisfy the rule.",
  "  Pure cover-bidding tenders have $n=0$.",
  "  Annual estimates divide total-period savings by 10 years (2009--2019).",
  "  Panel B reports optimal IQR-multiplier thresholds under different",
  "  investigation cost budgets (baseline deterrence rate = 50\\%).",
  "  Panel C uses cross-PBU variation in oversight (PBU size quartiles as",
  "  proxy for $\\theta$) to calibrate the elasticity of $m^*$ with respect",
  "  to detection probability. OLS: $\\hat{\\beta} = 0.064$;",
  "  IV: $\\hat{\\beta} = 0.194$. All welfare figures in BRL (nominal).",
  "\\end{tablenotes}",
  "\\end{table}"
)

writeLines(tex_lines, file.path(TAB_DIR, "tab_counterfactual_welfare.tex"))
cat("  Saved: tab_counterfactual_welfare.tex\n")

# =============================================================================
# 5. FIGURE: OPTIMAL THRESHOLD (CF2)
# =============================================================================

cat("  Plotting CF2 figure...\n")

# Panel A: Net welfare vs. cost_per_investigation for each deterrence rate
cf2_plot_dt <- cf2_results[cost_per_inv %in% round(10^seq(log10(10000),
                                                           log10(1000000),
                                                           length.out = 50))]
cf2_plot_dt[, deterrence_label := paste0("Deterrence = ",
                                          round(deterrence_rate * 100), "%")]

# Panel A: Optimal IQR multiplier as function of investigation cost
p_cf2a <- ggplot(cf2_plot_dt,
                 aes(x = cost_per_inv / 1000,
                     y = optimal_multiplier,
                     colour = deterrence_label,
                     linetype = deterrence_label)) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 1.5, linetype = "dashed", colour = "grey50",
             linewidth = 0.5) +
  annotate("text", x = 500, y = 1.55, label = "Baseline (1.5\u00d7 IQR)",
           colour = "grey40", size = 3, hjust = 1) +
  scale_x_log10(
    labels = scales::dollar_format(prefix = "R$", suffix = "K", scale = 1),
    breaks = c(10, 50, 100, 500, 1000)
  ) +
  scale_colour_manual(values = CB_COLS) +
  scale_linetype_manual(values = c("solid", "dashed", "dotdash", "dotted")) +
  labs(
    title    = "Panel A: Optimal IQR Multiplier Threshold",
    x        = "Investigation Cost per Firm (R$ thousands)",
    y        = "Optimal IQR Multiplier",
    colour   = NULL,
    linetype = NULL
  ) +
  theme_bw(base_size = 11) +
  theme(legend.position  = "bottom",
        legend.key.width = unit(1.5, "cm"),
        plot.title       = element_text(size = 10, face = "bold"))

# Panel B: Net welfare at optimal threshold vs. investigation cost
p_cf2b <- ggplot(cf2_plot_dt,
                 aes(x = cost_per_inv / 1000,
                     y = optimal_net_welfare / 1e6,
                     colour = deterrence_label,
                     linetype = deterrence_label)) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 0, linetype = "solid", colour = "black",
             linewidth = 0.4) +
  scale_x_log10(
    labels = scales::dollar_format(prefix = "R$", suffix = "K", scale = 1),
    breaks = c(10, 50, 100, 500, 1000)
  ) +
  scale_y_continuous(labels = scales::dollar_format(prefix = "R$", suffix = "M",
                                                      scale = 1)) +
  scale_colour_manual(values = CB_COLS) +
  scale_linetype_manual(values = c("solid", "dashed", "dotdash", "dotted")) +
  labs(
    title    = "Panel B: Net Welfare at Optimal Threshold",
    x        = "Investigation Cost per Firm (R$ thousands)",
    y        = "Net Welfare (R$ millions)",
    colour   = NULL,
    linetype = NULL
  ) +
  theme_bw(base_size = 11) +
  theme(legend.position  = "bottom",
        legend.key.width = unit(1.5, "cm"),
        plot.title       = element_text(size = 10, face = "bold"))

# Combine panels using base R layout (avoid patchwork dependency)
# Save as multi-page PDF
pdf(file.path(IMG_DIR, "fig_counterfactual_screening.pdf"),
    width = 8, height = 9)

# Stack both panels in one page using grid
library(grid)
grid.newpage()
vp1 <- viewport(x = 0.5, y = 0.75, width = 1.0, height = 0.50)
vp2 <- viewport(x = 0.5, y = 0.25, width = 1.0, height = 0.50)

print(p_cf2a, vp = vp1)
print(p_cf2b, vp = vp2)

invisible(dev.off())
cat("  Saved: fig_counterfactual_screening.pdf\n")

# =============================================================================
# 6. FIGURE: DETECTION PROBABILITY θ (CF3)
# =============================================================================

cat("  Plotting CF3 figure...\n")

# Panel A: Mean FL count by PBU size quartile
cf3_bar_dt <- cf3_dt[!is.na(pbu_size_q)]

p_cf3a <- ggplot(cf3_bar_dt,
                 aes(x = pbu_size_q, y = mean_fl, fill = pbu_size_q)) +
  geom_col(width = 0.6, colour = "white") +
  geom_text(aes(label = round(mean_fl, 3)),
            vjust = -0.4, size = 3.2) +
  scale_fill_manual(values = CB_COLS, guide = "none") +
  labs(
    title = paste0("Panel A: Mean Cover-Bidder Count by PBU Size\n",
                   "(Proxy for Detection Probability \u03b8)"),
    x = "PBU Size Quartile (Q1 = Smallest)",
    y = "Mean FL Count per Tender-Item"
  ) +
  theme_bw(base_size = 11) +
  theme(plot.title = element_text(size = 10, face = "bold"))

# Panel B: Welfare gain as function of theta increase (3 beta scenarios)
cf3_plot_dt <- melt(
  cf3_welfare[, .(theta_increase_pct, welfare_gain_ols, welfare_gain_cf,
                   welfare_gain_iv)],
  id.vars       = "theta_increase_pct",
  variable.name = "estimator",
  value.name    = "welfare_gain_BRL"
)
cf3_plot_dt[, estimator_label := fcase(
  estimator == "welfare_gain_ols", "OLS (\u03b2 = 0.064)",
  estimator == "welfare_gain_cf",  "Cross-fit (\u03b2 = 0.036)",
  estimator == "welfare_gain_iv",  "IV (\u03b2 = 0.194)"
)]
cf3_plot_dt[, estimator_label := factor(estimator_label,
  levels = c("OLS (\u03b2 = 0.064)",
             "Cross-fit (\u03b2 = 0.036)",
             "IV (\u03b2 = 0.194)"))]

p_cf3b <- ggplot(cf3_plot_dt,
                 aes(x = theta_increase_pct,
                     y = welfare_gain_BRL / 1e6,
                     colour = estimator_label,
                     linetype = estimator_label)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_colour_manual(values = CB_COLS[c(1, 3, 2)]) +
  scale_linetype_manual(values = c("solid", "dashed", "dotdash")) +
  scale_x_continuous(breaks = seq(10, 100, by = 10),
                     labels = paste0(seq(10, 100, by = 10), "%")) +
  scale_y_continuous(labels = scales::dollar_format(prefix = "R$", suffix = "M",
                                                      scale = 1)) +
  labs(
    title    = "Panel B: Welfare Gain from Increasing Detection Probability",
    x        = "Increase in Detection Probability \u03b8 (%)",
    y        = "Welfare Gain (R$ millions, 2009\u20132019)",
    colour   = "Price coefficient",
    linetype = "Price coefficient"
  ) +
  theme_bw(base_size = 11) +
  theme(legend.position  = "bottom",
        legend.key.width = unit(1.5, "cm"),
        plot.title       = element_text(size = 10, face = "bold"))

pdf(file.path(IMG_DIR, "fig_counterfactual_theta.pdf"),
    width = 8, height = 9)

grid.newpage()
vp1 <- viewport(x = 0.5, y = 0.75, width = 1.0, height = 0.50)
vp2 <- viewport(x = 0.5, y = 0.25, width = 1.0, height = 0.50)

print(p_cf3a, vp = vp1)
print(p_cf3b, vp = vp2)

invisible(dev.off())
cat("  Saved: fig_counterfactual_theta.pdf\n")

# =============================================================================
# 7. CONSOLE SUMMARY
# =============================================================================

cat("\n", strrep("=", 60), "\n", sep = "")
cat("COUNTERFACTUAL WELFARE — SUMMARY\n")
cat(strrep("=", 60), "\n", sep = "")

cat("\nCF1: Remove minimum-bidder requirement (convite)\n")
cat(sprintf("  Constraint-binding tenders : %s (%.1f%% of convite FL)\n",
            formatC(n_binds, big.mark = ",", format = "d"),
            100 * n_binds / n_total))
cat(sprintf("  Pure cover-bidding tenders : %s (%.1f%%)\n",
            formatC(n_pure, big.mark = ",", format = "d"),
            100 * n_pure / n_total))
cat(sprintf("  Welfare gain [OLS]  : R$%.1fM (constraint-binding)\n",
            cf1_ols_gain / 1e6))
cat(sprintf("  Welfare gain [OLS]  : R$%.1fM (pure cover-bidding)\n",
            cf1_ols_pure / 1e6))
cat(sprintf("  Welfare gain [IV]   : R$%.1fM (constraint-binding)\n",
            cf1_iv_gain / 1e6))

cat("\nCF2: Optimal screening threshold\n")
cat(sprintf("  At R$100K/investigation (det=50%%): opt. multiplier=%.2fx, ",
            cf2_100k$optimal_multiplier),
    sprintf("n_flagged=%d, net welfare=R$%.1fM\n",
            cf2_100k$optimal_n_flagged,
            cf2_100k$optimal_net_welfare / 1e6))
cat(sprintf("  At R$1M/investigation  (det=50%%): opt. multiplier=%.2fx, ",
            cf2_1m$optimal_multiplier),
    sprintf("n_flagged=%d, net welfare=R$%.1fM\n",
            cf2_1m$optimal_n_flagged,
            cf2_1m$optimal_net_welfare / 1e6))

cat("\nCF3: Increasing detection probability theta\n")
cat(sprintf("  Estimated elasticity d(log m)/d(log theta): %.3f\n",
            elasticity_theta))
cat(sprintf("  Welfare gain per 10%% increase in theta [OLS]: R$%.1fM\n",
            cf3_10pct$welfare_gain_ols / 1e6))
cat(sprintf("  Welfare gain per 10%% increase in theta [IV] : R$%.1fM\n",
            cf3_10pct$welfare_gain_iv / 1e6))

cat("\nOutputs written to:\n")
cat("  ", file.path(TAB_DIR, "tab_counterfactual_welfare.tex"), "\n")
cat("  ", file.path(TAB_DIR, "counterfactual_results.csv"),     "\n")
cat("  ", file.path(IMG_DIR, "fig_counterfactual_screening.pdf"), "\n")
cat("  ", file.path(IMG_DIR, "fig_counterfactual_theta.pdf"),     "\n")

cat("\n=== DONE ===\n")
