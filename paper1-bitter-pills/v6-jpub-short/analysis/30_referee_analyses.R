# Analyses for referee response (J-PubE short)
# 1A. Event study around first court order
# 1B. Cinelli-Hazlett sensitivity (sensemakr)
# 1C. Bulk-discount elasticity reality check
# 1D. Supplier FE: selection vs exploitation (overlap count)


suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(sensemakr)
})
setFixest_nthreads(16L)
setDTthreads(16L)

OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v6-jpub-short/output"
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "figures"), recursive = TRUE, showWarnings = FALSE)

# Load data
cat("Loading cache...\n")
dt <- readRDS("/tmp/v4_prepared.rds")
cat("  Rows:", nrow(dt), "\n")

# Main sample: items with both ordinary and litigated, winners only
d_main <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1 &
             !is.na(bid_price_log)]
cat("  Main sample (winners, both types):", nrow(d_main), "\n")

# 1A. Event Study Around First Court Order
cat("\n1A: Event study\n")

# For each item, find year of first litigated purchase
first_lit <- dt[purchase_type == 2, .(first_lit_year = min(year_n, na.rm = TRUE)), by = item]
d_es <- merge(d_main, first_lit, by = "item", all.x = TRUE)
d_es[, event_time := year_n - first_lit_year]

# Keep items with >= 2 pre and >= 2 post observations
item_coverage <- d_es[!is.na(event_time), .(
  has_pre  = any(event_time < 0),
  has_post = any(event_time >= 0),
  min_et = min(event_time),
  max_et = max(event_time)
), by = item]
good_items <- item_coverage[has_pre == TRUE & has_post == TRUE & min_et <= -2 & max_et >= 2, item]
d_es <- d_es[item %in% good_items]
cat("  Items with >=2 pre + >=2 post:", length(good_items), "\n")
cat("  Observations:", nrow(d_es), "\n")

# Trim event window to [-5, +5]
d_es <- d_es[event_time >= -5 & event_time <= 5]
d_es[, et_f := relevel(factor(event_time), ref = "-1")]

# Event study regression
m_es <- feols(bid_price_log ~ et_f | item_id + pbu_id,
              data = d_es, cluster = ~pbu_id)
cat("  Event study estimated.\n")

# Extract coefficients
es_coefs <- data.table(
  event_time = as.integer(gsub("et_f", "", names(coef(m_es)))),
  coef = coef(m_es),
  se = sqrt(diag(vcov(m_es)))
)
# Add t=-1 reference
es_coefs <- rbind(es_coefs, data.table(event_time = -1L, coef = 0, se = 0))
es_coefs <- es_coefs[order(event_time)]
es_coefs[, ci_lo := coef - 1.96 * se]
es_coefs[, ci_hi := coef + 1.96 * se]

cat("  Event study coefficients:\n")
print(es_coefs)

# Plot
p_es <- ggplot(es_coefs, aes(x = event_time, y = coef)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = -0.5, linetype = "dashed", color = "gray70") +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.15, fill = "steelblue") +
  geom_point(size = 2.5, color = "steelblue") +
  geom_line(color = "steelblue", linewidth = 0.6) +
  labs(x = "Years Relative to First Court Order",
       y = "Log Negotiated Price (relative to t = -1)",
       caption = "Item + PBU FE. SE clustered at PBU level. Reference: t = -1.") +
  scale_x_continuous(breaks = -5:5) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank())

ggsave(file.path(OUT, "figures", "fig_event_study_item.pdf"),
       p_es, width = 6.5, height = 4, device = cairo_pdf)
cat("  Saved: fig_event_study_item.pdf\n")

# 1B. Cinelli-Hazlett Sensitivity
cat("\n1B: Cinelli-Hazlett sensitivity\n")

# OLS version (sensemakr requires lm, not feols)
# Use de-meaned approach: residualize on FE, then run OLS
d_sens <- d_main[!is.na(bid_price_log) & !is.na(urgent)]

# sensemakr needs lm, not feols. Use Frisch-Waugh with fixest::demean
d_sens[, c("y_dm", "t_dm") := {
  yd <- fixest::demean(bid_price_log, list(item_id, factor(year_n), pbu_id))
  td <- fixest::demean(urgent, list(item_id, factor(year_n), pbu_id))
  list(as.numeric(yd), as.numeric(td))
}]
d_sens_clean <- d_sens[!is.na(y_dm) & !is.na(t_dm)]

# OLS on demeaned variables (Frisch-Waugh)
m_ols <- lm(y_dm ~ t_dm, data = d_sens_clean)

# sensemakr
sens <- sensemakr(m_ols, treatment = "t_dm", benchmark_covariates = NULL,
                  q = 1, alpha = 0.05)
cat("  RV_q=1:", round(sens$sensitivity_stats$rv_q, 4), "\n")
cat("  RV_qa:", round(sens$sensitivity_stats$rv_qa, 4), "\n")

# Save summary
sink(file.path(OUT, "tables", "sensemakr_summary.txt"))
summary(sens)
sink()
cat("  Saved: sensemakr_summary.txt\n")

# 1C. Bulk-Discount Elasticity Reality Check
cat("\n1C: Bulk-discount elasticity\n")

# Urgent subsample for under-the-gun
d_utg <- dt[urgent == 1 & has_admin == TRUE & has_litigated == TRUE &
            po_firm_winner == 1 & !is.na(bid_price_log) & !is.na(bid_qty_log)]

# Mean log quantity by type
qty_admin <- d_utg[is_admin == 1, mean(bid_qty_log, na.rm = TRUE)]
qty_litig <- d_utg[is_admin == 0, mean(bid_qty_log, na.rm = TRUE)]
qty_gap <- qty_admin - qty_litig
cat(sprintf("  Mean log qty: admin=%.3f, litigated=%.3f, gap=%.3f\n",
            qty_admin, qty_litig, qty_gap))

# Bulk-discount elasticity from Panel B of under-the-gun (coefficient on log quantity)
# From Table 8 Panel B: -0.341 (col 3)
bulk_elast <- -0.341
implied_price_diff <- qty_gap * bulk_elast
cat(sprintf("  Bulk-discount elasticity: %.3f\n", bulk_elast))
cat(sprintf("  Implied price difference from quantity gap: %.3f (%.1f%%)\n",
            implied_price_diff, 100 * (exp(-implied_price_diff) - 1)))
cat(sprintf("  Actual under-the-gun total effect: 0.262 (30%%)\n"))
cat(sprintf("  Quantity channel explains: %.1f%% of total\n",
            100 * abs(implied_price_diff) / 0.262))

# Item overlap: how many items have BOTH admin and litigated
items_admin <- unique(d_utg[is_admin == 1, item])
items_litig <- unique(d_utg[is_admin == 0, item])
overlap <- intersect(items_admin, items_litig)
cat(sprintf("  Items with admin: %d\n", length(items_admin)))
cat(sprintf("  Items with litigated: %d\n", length(items_litig)))
cat(sprintf("  Items with BOTH: %d (%.1f%% of union)\n",
            length(overlap),
            100 * length(overlap) / length(union(items_admin, items_litig))))

# 1D. Supplier FE: Selection vs Exploitation
cat("\n1D: Supplier FE overlap\n")

# How many (item, firm) pairs appear in both ordinary and urgent?
d_firm <- dt[po_firm_winner == 1 & has_litigated == TRUE & has_ordinary == TRUE &
             !is.na(bid_price_log)]

# Firm identity variable
firm_col <- grep("firm_id|fornecedor|winner_id|supplier", names(d_firm),
                 value = TRUE, ignore.case = TRUE)
if (length(firm_col) == 0) {
  # Try to find the firm column from the bid data
  firm_col <- grep("cod.*forn|firm", names(d_firm), value = TRUE, ignore.case = TRUE)
}
cat("  Firm column candidates:", paste(firm_col, collapse = ", "), "\n")

if (length(firm_col) > 0) {
  fc <- firm_col[1]
  d_firm[, firm := get(fc)]

  # Pairs in ordinary
  pairs_ord <- unique(d_firm[urgent == 0, .(item, firm)])
  pairs_urg <- unique(d_firm[urgent == 1, .(item, firm)])
  pairs_both <- fintersect(pairs_ord, pairs_urg)

  cat(sprintf("  (item, firm) pairs in ordinary: %d\n", nrow(pairs_ord)))
  cat(sprintf("  (item, firm) pairs in urgent: %d\n", nrow(pairs_urg)))
  cat(sprintf("  (item, firm) pairs in BOTH: %d (%.1f%% of urgent pairs)\n",
              nrow(pairs_both), 100 * nrow(pairs_both) / nrow(pairs_urg)))

  # Unique firms
  firms_ord <- unique(pairs_ord$firm)
  firms_urg <- unique(pairs_urg$firm)
  firms_both <- intersect(firms_ord, firms_urg)
  cat(sprintf("  Unique firms in ordinary: %d\n", length(firms_ord)))
  cat(sprintf("  Unique firms in urgent: %d\n", length(firms_urg)))
  cat(sprintf("  Firms in BOTH: %d (%.1f%%)\n",
              length(firms_both), 100 * length(firms_both) / length(firms_urg)))
} else {
  cat("  WARNING: No firm column found. Skipping overlap analysis.\n")
}

cat("\nAll referee analyses complete\n")
