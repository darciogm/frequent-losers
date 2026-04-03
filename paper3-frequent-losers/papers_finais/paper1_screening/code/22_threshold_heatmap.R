# ============================================================================
# 22_threshold_heatmap.R — Optimal Threshold Heatmap
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Produces a 2D heatmap: IQR multiplier (x) × win-rate cutoff (y),
# with color = FL price coefficient. Shows the trade-off between
# classification strictness and the strength of the price signal.
# ============================================================================

cat("=== 22_threshold_heatmap.R: Threshold heatmap ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

# Load always-losers and FTM
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

# Full loss stats for win-rate cutoff
fls_file <- file.path(DATA_V1, "firm_loss_stats.parquet")
if (file.exists(fls_file)) {
  fls <- as.data.table(read_parquet(fls_file))
} else if (file.exists(DATA_CACHE_FLS)) {
  fls <- readRDS(DATA_CACHE_FLS)
} else {
  stop("firm_loss_stats not found. Run scripts/01_clean.R or provide firm_loss_stats.parquet")
}
fls_col <- grep("fornecedor", names(fls), value = TRUE, ignore.case = TRUE)
if (length(fls_col) == 1 && fls_col != "firm_id") setnames(fls, fls_col, "firm_id")

# FTM for reclassification
ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")
if (!file.exists(ftm_file)) stop("firm_tender_map.parquet not found")
ftm <- as.data.table(read_parquet(ftm_file))
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

# Identify win_rate column
wr_col <- grep("win_rate|winrate|taxa", names(fls), value = TRUE, ignore.case = TRUE)[1]
if (!is.na(wr_col)) setnames(fls, wr_col, "win_rate", skip_absent = TRUE)

# Compute tenders_count in fls if not present
tc_col <- grep("tenders_count|n_tenders|total", names(fls), value = TRUE, ignore.case = TRUE)[1]
if (!is.na(tc_col)) setnames(fls, tc_col, "tenders_count", skip_absent = TRUE)

cat(sprintf("  Loss stats: %s firms\n", pfmt_int(nrow(fls))))

# ============================================================================
# Phase 1: Grid search
# ============================================================================

cat("  Phase 1: Grid search over (IQR multiplier, win_rate cutoff)...\n")

iqr_mults <- seq(1.0, 3.0, by = 0.25)
wr_cutoffs <- c(0, 0.01, 0.02, 0.05)

# Base quantiles from always-losers (win_rate == 0)
al_firms <- fls[win_rate == 0, firm_id]
fp_al <- fp[firm_id %chin% al_firms]
q <- quantile(fp_al$tenders_count, c(0.25, 0.50, 0.75), na.rm = TRUE)
iqr_val <- q[3] - q[1]

grid_results <- data.table()

for (wr in wr_cutoffs) {
  # Pool of candidate FL firms: win_rate <= cutoff
  if (wr == 0) {
    pool <- fls[win_rate == 0, firm_id]
  } else {
    pool <- fls[win_rate <= wr, firm_id]
  }

  # Recompute tenders_count for this pool from fp (always-losers data)
  pool_fp <- fp[firm_id %chin% pool]
  if (nrow(pool_fp) == 0) next

  q_pool <- quantile(pool_fp$tenders_count, c(0.25, 0.50, 0.75), na.rm = TRUE)
  iqr_pool <- q_pool[3] - q_pool[1]

  for (mult in iqr_mults) {
    thr <- q_pool[2] + mult * iqr_pool
    fl_ids_cell <- pool_fp[tenders_count > thr, firm_id]
    n_fl <- length(fl_ids_cell)

    if (n_fl < 10) {
      grid_results <- rbind(grid_results, data.table(
        iqr_mult = mult, wr_cutoff = wr, threshold = thr,
        n_fl = n_fl, coef = NA_real_, se = NA_real_,
        pval = NA_real_, n_obs = NA_integer_))
      next
    }

    # Reclassify
    ftm_fl <- ftm[firm_id %chin% fl_ids_cell]
    new_losers <- ftm_fl[, .(losers_count_new = .N), by = .(oc_code, item_code)]

    dt_cell <- copy(dt)
    if ("losers_count_new" %in% names(dt_cell)) dt_cell[, losers_count_new := NULL]
    dt_cell <- merge(dt_cell, new_losers, by = c("oc_code", "item_code"), all.x = TRUE)
    dt_cell[is.na(losers_count_new), losers_count_new := 0L]
    dt_cell[, losers := as.integer(losers_count_new > 0L)]

    m <- tryCatch(
      feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
            data = dt_cell[!is.na(lneg_price)], cluster = ~item_f, fixef.rm = "none"),
      error = function(e) NULL
    )

    if (!is.null(m) && "losers" %in% names(coef(m))) {
      b <- coef(m)["losers"]
      se <- sqrt(vcov(m)["losers", "losers"])
      p <- 2 * pnorm(-abs(b / se))
      grid_results <- rbind(grid_results, data.table(
        iqr_mult = mult, wr_cutoff = wr, threshold = thr,
        n_fl = n_fl, coef = b, se = se, pval = p, n_obs = m$nobs))
    } else {
      grid_results <- rbind(grid_results, data.table(
        iqr_mult = mult, wr_cutoff = wr, threshold = thr,
        n_fl = n_fl, coef = NA_real_, se = NA_real_,
        pval = NA_real_, n_obs = NA_integer_))
    }

    cat(sprintf("    IQR=%.2f, WR=%.2f: %d FL, coef=%.4f\n",
                mult, wr, n_fl, if (!is.null(m) && "losers" %in% names(coef(m))) coef(m)["losers"] else NA))
  }
}

grid_results[, significant := as.integer(!is.na(pval) & pval < 0.05)]
grid_results[, wr_label := factor(paste0(wr_cutoff * 100, "%"),
  levels = paste0(wr_cutoffs * 100, "%"))]

cat(sprintf("  Grid: %d cells (%d significant at 5%%)\n",
            nrow(grid_results), sum(grid_results$significant, na.rm = TRUE)))

# ============================================================================
# Phase 2: Heatmap
# ============================================================================

cat("  Phase 2: Generating heatmap...\n")

p_heat <- ggplot(grid_results[!is.na(coef)],
                  aes(x = iqr_mult, y = wr_label, fill = coef)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.3f%s", coef,
    ifelse(!is.na(pval) & pval < 0.01, "***",
    ifelse(!is.na(pval) & pval < 0.05, "**",
    ifelse(!is.na(pval) & pval < 0.1, "*", ""))))),
    size = 2.5, color = "white") +
  scale_fill_gradient2(low = "gray85", mid = "gray95", high = "black",
                        midpoint = 0, name = "FL coeff.",
                        labels = scales::label_number(accuracy = 0.01)) +
  scale_x_continuous(breaks = iqr_mults) +
  labs(x = "IQR multiplier", y = "Win-rate cutoff") +
  theme_pub() +
  theme(legend.position = "right",
        panel.grid = element_blank(),
        axis.text.x = element_text(size = 7))

save_pub(p_heat, "fig_threshold_heatmap.pdf")

# ============================================================================
# Phase 3: N-FL annotation plot (secondary)
# ============================================================================

p_nfl <- ggplot(grid_results[!is.na(n_fl)],
                 aes(x = iqr_mult, y = wr_label, fill = n_fl)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = pfmt_int(n_fl)), size = 2.2) +
  scale_fill_gradient(low = "lightyellow", high = "darkorange3",
                       name = "N FL firms",
                       labels = scales::label_comma()) +
  scale_x_continuous(breaks = iqr_mults) +
  labs(x = "IQR multiplier", y = "Win-rate cutoff") +
  theme_pub() +
  theme(legend.position = "right",
        panel.grid = element_blank(),
        axis.text.x = element_text(size = 7))

save_pub(p_nfl, "fig_threshold_nfl_heatmap.pdf")

# ============================================================================
# Phase 4: FP vs Savings welfare heatmap
# ============================================================================

cat("  Phase 4: FP vs Savings welfare heatmap...\n")

# Compute FL-present spending for baseline threshold (win_rate = 0)
baseline_grid <- grid_results[wr_cutoff == 0 & !is.na(coef)]

# Total FL-present spending per threshold
# We need to re-merge with the data to compute spending
price_col <- grep("bid_unit_price_negot_min|negot", names(dt), value = TRUE, ignore.case = TRUE)[1]
if (!is.na(price_col) && price_col %in% names(dt)) {
  cat(sprintf("  Using price column: %s\n", price_col))

  # For each IQR multiplier, compute FL-present spending
  inv_costs <- c(50, 100, 200, 300, 500)  # R$ thousands per investigation
  deterrence <- 0.50  # assumed deterrence rate

  welfare_grid <- data.table()

  for (mult in iqr_mults) {
    thr <- q[2] + mult * iqr_val
    fl_ids_w <- fp[tenders_count > thr, firm_id]
    n_fl_w <- length(fl_ids_w)

    # Get coefficient from grid_results
    row <- baseline_grid[iqr_mult == mult]
    if (nrow(row) == 0 || is.na(row$coef)) next
    beta <- row$coef

    # Compute FL-present spending
    ftm_fl_w <- ftm[firm_id %chin% fl_ids_w]
    fl_tenders_w <- ftm_fl_w[, .(losers_count_new = .N), by = .(oc_code, item_code)]
    dt_w <- merge(dt[!is.na(get(price_col)) & get(price_col) > 0,
                      .(oc_code, item_code, price = get(price_col))],
                   fl_tenders_w, by = c("oc_code", "item_code"))
    fl_spending <- sum(dt_w$price, na.rm = TRUE)

    # Gross savings (illustrative, assumes full causality)
    gross_savings <- (exp(beta) - 1) * fl_spending * deterrence

    for (c_inv in inv_costs) {
      total_inv_cost <- c_inv * 1000 * n_fl_w
      net_welfare <- gross_savings - total_inv_cost

      welfare_grid <- rbind(welfare_grid, data.table(
        iqr_mult = mult,
        inv_cost_k = c_inv,
        n_fl = n_fl_w,
        beta = beta,
        fl_spending = fl_spending,
        gross_savings = gross_savings,
        inv_total = total_inv_cost,
        net_welfare = net_welfare,
        net_welfare_m = net_welfare / 1e6  # in R$ millions
      ))
    }
  }

  welfare_grid[, inv_label := factor(paste0("R$", inv_cost_k, "K"),
    levels = paste0("R$", inv_costs, "K"))]

  p_welfare <- ggplot(welfare_grid,
                       aes(x = iqr_mult, y = inv_label, fill = net_welfare_m)) +
    geom_tile(color = "white", linewidth = 0.5) +
    geom_text(aes(label = sprintf("%.0f", net_welfare_m),
                  color = ifelse(net_welfare_m > 0, "pos", "neg")),
              size = 2.5, show.legend = FALSE) +
    scale_color_manual(values = c("pos" = "white", "neg" = "gray20")) +
    scale_fill_gradient2(low = "gray85", mid = "gray95", high = "black",
                          midpoint = 0, name = "Net welfare\n(R$ millions)",
                          labels = scales::label_number(accuracy = 1)) +
    scale_x_continuous(breaks = iqr_mults) +
    labs(x = "IQR multiplier",
         y = "Investigation cost per firm") +
    theme_pub() +
    theme(legend.position = "right",
          panel.grid = element_blank(),
          axis.text.x = element_text(size = 7))

  save_pub(p_welfare, "fig_welfare_heatmap.pdf")
} else {
  cat("  Price column not found. Skipping welfare heatmap.\n")
}

# ============================================================================
# Save
# ============================================================================

saveRDS(grid_results, "/tmp/p3v4_threshold_heatmap.rds")
cat("  Results saved: /tmp/p3v4_threshold_heatmap.rds\n")
cat("  Done.\n")
