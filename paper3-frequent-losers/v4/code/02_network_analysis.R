# ============================================================================
# 02_network_analysis.R — Co-bidding network analysis (NEW for v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Purpose: Separate genuine cover bidders from incompetent/marginal firms
# among the 2,735 FL firms. Creates high-suspicion vs low-suspicion
# classification for network-split regressions. [Major 3.2, R2.2]
#
# Outputs:
#   - /tmp/p3v4_network.rds (network metrics + FL classification)
#   - tab_fl_network_summary.tex
#   - tab_fl_characteristics.tex (expanded)
# ============================================================================

cat("=== 02_network_analysis.R: Co-bidding network analysis ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data ---------------------------------------------------------------
cat("  Loading firm_tender_map...\n")
ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")
if (!file.exists(ftm_file)) stop("firm_tender_map.parquet not found")
ftm <- as.data.table(read_parquet(ftm_file))

# Standardize column names
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

cat("  FTM rows:", pfmt_int(nrow(ftm)), "\n")

# Load FL identification
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

# Load firm characteristics
firms <- readRDS(DATA_CACHE_FIRMS)
firms_col <- grep("^c.digofornecedor$", names(firms), value = TRUE, ignore.case = TRUE)
if (length(firms_col) == 1) setnames(firms, firms_col, "firm_id")

# Load prepared analysis data
dt <- readRDS(DATA_CACHE_V4)

# FL firm IDs — apply IQR threshold to get the 2,735 FL firms (not all 16,843 always-losers)
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val
fl_ids <- unique(fp[tenders_count > threshold, firm_id])
cat(sprintf("  IQR threshold: %.0f (median + 1.5*IQR)\n", threshold))
cat("  FL firms (above threshold):", pfmt_int(length(fl_ids)), "\n")

# Flag FL in FTM
ftm[, is_fl := as.integer(firm_id %chin% fl_ids)]
cat("  FL bids in FTM:", pfmt_int(sum(ftm$is_fl)), "\n")

# ============================================================================
# Phase 1: For each FL firm, find co-bidders and compute network metrics
# ============================================================================

cat("  Phase 1: Computing co-bidding network metrics...\n")

# Get FL firm participations
fl_ftm <- ftm[is_fl == 1L]
fl_tenders <- unique(fl_ftm[, .(oc_code, item_code)])
cat("  Tenders with FL participation:", pfmt_int(nrow(fl_tenders)), "\n")

# Join: for each FL tender, get all participants
fl_all_bidders <- merge(fl_tenders, ftm, by = c("oc_code", "item_code"), all.x = TRUE)
cat("  Total bidder-rows in FL tenders:", pfmt_int(nrow(fl_all_bidders)), "\n")

# ---- 1a: Winner concentration (HHI) per FL firm ----------------------------
# For each FL firm, look at who WINS in tenders where this FL bids

cat("  Computing winner_hhi per FL firm...\n")

# Get winners in FL tenders
winners_in_fl <- fl_all_bidders[won == 1L]

# For each FL firm, find all its tenders and who won
fl_winner_map <- merge(
  fl_ftm[, .(firm_id, oc_code, item_code)],
  winners_in_fl[, .(oc_code, item_code, winner_id = firm_id)],
  by = c("oc_code", "item_code"), all.x = TRUE, allow.cartesian = TRUE
)

# Compute HHI of winner shares per FL firm
fl_winner_hhi <- fl_winner_map[!is.na(winner_id), {
  n_total <- .N
  shares <- .SD[, .N, by = winner_id][, N / n_total]
  .(winner_hhi = sum(shares^2), n_tenders_with_winner = n_total,
    n_unique_winners = uniqueN(winner_id))
}, by = firm_id]

cat("  FL firms with winner_hhi:", pfmt_int(nrow(fl_winner_hhi)), "\n")

# ---- 1b: Repeat co-bidding partners ----------------------------------------
cat("  Computing repeat co-bidding partners...\n")

# For each FL firm, find non-FL co-bidders
fl_cobidders <- merge(
  fl_ftm[, .(fl_firm = firm_id, oc_code, item_code)],
  fl_all_bidders[is_fl == 0L, .(oc_code, item_code, cobidder = firm_id)],
  by = c("oc_code", "item_code"), all.x = TRUE, allow.cartesian = TRUE
)

# Count how many times each FL-cobidder pair co-bids
fl_pair_counts <- fl_cobidders[!is.na(cobidder),
  .N, by = .(fl_firm, cobidder)]

# Per FL firm: number of repeat partners (3+ co-bids)
fl_repeat <- fl_pair_counts[N >= 3, .(n_repeat_partners = .N), by = fl_firm]
setnames(fl_repeat, "fl_firm", "firm_id")

# Top partner share: fraction of FL's tenders shared with most frequent co-bidder
fl_top_partner <- fl_pair_counts[, {
  total_tenders <- sum(N)
  max_share <- max(N) / total_tenders
  .(top_partner_share = max_share, total_cobid_instances = total_tenders)
}, by = fl_firm]
setnames(fl_top_partner, "fl_firm", "firm_id")

cat("  FL firms with repeat partners:", pfmt_int(nrow(fl_repeat)), "\n")

# ---- 1c: Bid spread CV (from bid-level data if available) -------------------
cat("  Computing bid_spread_cv...\n")

# Try to load bid-level data with prices
bl_file <- file.path(DATA_V1, "bid_level_full.parquet")
bid_spread_cv <- NULL

if (file.exists(bl_file)) {
  # Read only FL firms' bids to save memory
  bl <- as.data.table(read_parquet(bl_file))
  bl_col <- grep("fornecedor", names(bl), value = TRUE, ignore.case = TRUE)
  if (length(bl_col) == 1) setnames(bl, bl_col, "firm_id")
  setnames(bl, "numerodaoc", "oc_code", skip_absent = TRUE)
  setnames(bl, "códigoitem", "item_code", skip_absent = TRUE)

  # Price column
  price_col <- grep("valor|preco|price|lance", names(bl), value = TRUE, ignore.case = TRUE)[1]
  if (!is.na(price_col)) {
    setnames(bl, price_col, "bid_price", skip_absent = TRUE)
    bl_fl <- bl[firm_id %chin% fl_ids & !is.na(bid_price) & bid_price > 0]

    # Get winning price per tender
    win_prices <- bl[won == 1L & !is.na(bid_price) & bid_price > 0,
                      .(win_price = min(bid_price)), by = .(oc_code, item_code)]

    bl_fl <- merge(bl_fl, win_prices, by = c("oc_code", "item_code"), all.x = TRUE)
    bl_fl[, bid_spread := (bid_price - win_price) / abs(win_price)]

    # CV of bid spread per FL firm
    bid_spread_cv <- bl_fl[!is.na(bid_spread),
      .(bid_spread_cv = sd(bid_spread, na.rm = TRUE) / abs(mean(bid_spread, na.rm = TRUE)),
        mean_bid_spread = mean(bid_spread, na.rm = TRUE),
        n_bids_priced = .N),
      by = firm_id]

    cat("  FL firms with bid_spread_cv:", pfmt_int(nrow(bid_spread_cv)), "\n")
    rm(bl, bl_fl, win_prices); gc(verbose = FALSE)
  }
} else {
  cat("  bid_level_full.parquet not found. Skipping bid_spread_cv.\n")
}

# ============================================================================
# Phase 2: Merge metrics and classify FL firms
# ============================================================================

cat("  Phase 2: Merging metrics and classifying...\n")

# Start with all FL firms
fl_metrics <- data.table(firm_id = fl_ids)

# Merge all metrics
fl_metrics <- merge(fl_metrics, fl_winner_hhi, by = "firm_id", all.x = TRUE)
fl_metrics <- merge(fl_metrics, fl_repeat, by = "firm_id", all.x = TRUE)
fl_metrics <- merge(fl_metrics, fl_top_partner, by = "firm_id", all.x = TRUE)
if (!is.null(bid_spread_cv)) {
  fl_metrics <- merge(fl_metrics, bid_spread_cv, by = "firm_id", all.x = TRUE)
}

# Fill NAs
fl_metrics[is.na(n_repeat_partners), n_repeat_partners := 0L]
fl_metrics[is.na(winner_hhi), winner_hhi := 0]
fl_metrics[is.na(top_partner_share), top_partner_share := 0]

# Classification: high_suspicion = (winner_hhi > median) AND (n_repeat_partners >= 2)
hhi_median <- median(fl_metrics[winner_hhi > 0, winner_hhi], na.rm = TRUE)
cat(sprintf("  Winner HHI median (non-zero): %.4f\n", hhi_median))

fl_metrics[, high_suspicion := as.integer(
  winner_hhi > hhi_median & n_repeat_partners >= 2L
)]

n_high <- sum(fl_metrics$high_suspicion, na.rm = TRUE)
n_low  <- nrow(fl_metrics) - n_high
cat(sprintf("  High-suspicion FL: %d (%.1f%%)\n", n_high, 100 * n_high / nrow(fl_metrics)))
cat(sprintf("  Low-suspicion FL: %d (%.1f%%)\n", n_low, 100 * n_low / nrow(fl_metrics)))

# ============================================================================
# Phase 3: Create tender-level indicators
# ============================================================================

cat("  Phase 3: Creating tender-level indicators...\n")

high_fl_ids <- fl_metrics[high_suspicion == 1L, firm_id]
low_fl_ids  <- fl_metrics[high_suspicion == 0L, firm_id]

# Count high/low FL per tender from FTM
ftm[, is_high_fl := as.integer(firm_id %chin% high_fl_ids)]
ftm[, is_low_fl  := as.integer(firm_id %chin% low_fl_ids)]

tender_fl_split <- ftm[, .(
  n_high_fl = sum(is_high_fl),
  n_low_fl  = sum(is_low_fl)
), by = .(oc_code, item_code)]

tender_fl_split[, has_high_susp_fl := as.integer(n_high_fl > 0)]
tender_fl_split[, has_low_susp_fl  := as.integer(n_low_fl > 0)]

# Merge onto analysis dataset
dt <- merge(dt, tender_fl_split[, .(oc_code, item_code, has_high_susp_fl, has_low_susp_fl,
                                      n_high_fl, n_low_fl)],
             by = c("oc_code", "item_code"), all.x = TRUE)
dt[is.na(has_high_susp_fl), has_high_susp_fl := 0L]
dt[is.na(has_low_susp_fl),  has_low_susp_fl := 0L]
dt[is.na(n_high_fl), n_high_fl := 0L]
dt[is.na(n_low_fl),  n_low_fl := 0L]

cat(sprintf("  Tenders with high-suspicion FL: %s (%.1f%%)\n",
            pfmt_int(sum(dt$has_high_susp_fl)),
            100 * mean(dt$has_high_susp_fl)))
cat(sprintf("  Tenders with low-suspicion FL: %s (%.1f%%)\n",
            pfmt_int(sum(dt$has_low_susp_fl)),
            100 * mean(dt$has_low_susp_fl)))

# ---- Market-level winner HHI (Comment 2.4) ----------------------------------
cat("  Computing market-level winner HHI (item_group x pbu_code x year)...\n")

# Extract item_group and pbu_code from dt for ftm join
dt_keys <- unique(dt[, .(oc_code, item_code, item_group, pbu_code, year)])
ftm_market <- merge(ftm[, .(firm_id, oc_code, item_code, won)],
                     dt_keys, by = c("oc_code", "item_code"), all.x = FALSE)

# Winners only: compute market share per firm within (item_group, pbu_code, year)
winners_market <- ftm_market[won == 1L]
market_totals <- winners_market[, .(total_wins = .N), by = .(item_group, pbu_code, year)]
firm_market <- winners_market[, .(firm_wins = .N), by = .(item_group, pbu_code, year, firm_id)]
firm_market <- merge(firm_market, market_totals, by = c("item_group", "pbu_code", "year"))
firm_market[, share := firm_wins / total_wins]

# HHI = sum of squared shares per market cell
winner_hhi_dt <- firm_market[, .(winner_hhi_market = sum(share^2)), by = .(item_group, pbu_code, year)]
cat(sprintf("  Market HHI cells: %s, mean=%.4f, median=%.4f\n",
            pfmt_int(nrow(winner_hhi_dt)),
            mean(winner_hhi_dt$winner_hhi_market),
            median(winner_hhi_dt$winner_hhi_market)))

# Merge onto dt
dt <- merge(dt, winner_hhi_dt, by = c("pbu_code", "year", "item_group"), all.x = TRUE)
dt[is.na(winner_hhi_market), winner_hhi_market := 1]  # single winner = monopoly
cat(sprintf("  winner_hhi_market non-missing: %s (%.1f%%)\n",
            pfmt_int(sum(!is.na(dt$winner_hhi_market))),
            100 * mean(!is.na(dt$winner_hhi_market))))

rm(ftm_market, winners_market, market_totals, firm_market, winner_hhi_dt); gc(verbose = FALSE)

# Save updated analysis dataset with network indicators
saveRDS(dt, DATA_CACHE_V4)
cat("  Updated:", DATA_CACHE_V4, "\n")

# ============================================================================
# Phase 4: FL Firm-Level Facts [R2.2]
# ============================================================================

cat("  Phase 4: FL firm-level characteristics...\n")

# Merge firm characteristics
fl_chars <- merge(fl_metrics, firms, by = "firm_id", all.x = TRUE)

# Check available columns
cat("  Available firm columns:", paste(names(firms), collapse = ", "), "\n")

# Compute summary statistics: FL vs non-FL
all_firm_ids <- unique(ftm$firm_id)
nonfl_ids <- setdiff(all_firm_ids, fl_ids)

fl_firm_data <- firms[firm_id %chin% fl_ids]
nonfl_firm_data <- firms[firm_id %chin% nonfl_ids]

char_summary <- data.table()

# Porte (firm size category)
if ("porte_empresa" %in% names(firms)) {
  fl_porte <- fl_firm_data[, .N, by = porte_empresa][order(-N)]
  nonfl_porte <- nonfl_firm_data[, .N, by = porte_empresa][order(-N)]
  cat("  FL firm size distribution:\n")
  print(fl_porte)
}

# Capital social (if available)
cap_col <- grep("capital", names(firms), value = TRUE, ignore.case = TRUE)
if (length(cap_col) > 0) {
  cat(sprintf("  FL mean capital: %.0f\n",
              mean(fl_firm_data[[cap_col[1]]], na.rm = TRUE)))
  cat(sprintf("  Non-FL mean capital: %.0f\n",
              mean(nonfl_firm_data[[cap_col[1]]], na.rm = TRUE)))
}

# CNAE (economic activity)
cnae_col <- grep("cnae", names(firms), value = TRUE, ignore.case = TRUE)
if (length(cnae_col) > 0) {
  fl_cnae_top <- fl_firm_data[, .N, by = eval(cnae_col[1])][order(-N)][1:10]
  cat("  Top 10 CNAE for FL firms:\n")
  print(fl_cnae_top)
}

# Firm age (data_inicio_atividade)
age_col <- grep("inicio|data_inic|fundacao|abertura", names(firms), value = TRUE, ignore.case = TRUE)
if (length(age_col) > 0) {
  cat(sprintf("  Age column found: %s\n", age_col[1]))
}

# ============================================================================
# Phase 5: Write network summary table
# ============================================================================

cat("  Writing tab_fl_network_summary.tex...\n")

net_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Co-Bidding Network Metrics for Frequent Loser Firms}",
  "\\label{tab:fl_network_summary}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & Mean & SD & Median & N \\\\", "\\midrule"
)

net_vars <- list(
  list(col = "winner_hhi", label = "Winner HHI"),
  list(col = "n_repeat_partners", label = "Repeat co-bidding partners ($\\geq$3)"),
  list(col = "top_partner_share", label = "Top partner tender share")
)

if ("bid_spread_cv" %in% names(fl_metrics)) {
  net_vars <- c(net_vars, list(list(col = "bid_spread_cv", label = "Bid spread CV")))
}

for (v in net_vars) {
  x <- fl_metrics[[v$col]]
  x <- x[!is.na(x)]
  net_lines <- c(net_lines, sprintf(
    "%s & %s & %s & %s & %s \\\\",
    v$label, pfmt(mean(x), 3), pfmt(sd(x), 3), pfmt(median(x), 3), pfmt_int(length(x))
  ))
}

net_lines <- c(net_lines, "\\midrule",
  sprintf("\\textbf{High-suspicion FL} & \\multicolumn{4}{c}{%s firms (%.1f\\%%)} \\\\",
          pfmt_int(n_high), 100 * n_high / nrow(fl_metrics)),
  sprintf("\\textbf{Low-suspicion FL} & \\multicolumn{4}{c}{%s firms (%.1f\\%%)} \\\\",
          pfmt_int(n_low), 100 * n_low / nrow(fl_metrics)),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Winner HHI measures concentration of winning firms in tenders",
  "where the FL firm participates. Repeat partners = non-FL firms co-bidding $\\geq$3 times.",
  "High-suspicion = HHI above median AND $\\geq$2 repeat partners.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(net_lines, file.path(OUT_TAB, "tab_fl_network_summary.tex"))

# ============================================================================
# Save results
# ============================================================================

network_results <- list(
  fl_metrics = fl_metrics,
  high_fl_ids = high_fl_ids,
  low_fl_ids = low_fl_ids,
  tender_fl_split = tender_fl_split,
  hhi_median = hhi_median,
  n_high = n_high,
  n_low = n_low,
  fl_chars = fl_chars
)

saveRDS(network_results, NETWORK_CACHE_V4)
cat("  Network results saved:", NETWORK_CACHE_V4, "\n")
cat("  Done.\n")
