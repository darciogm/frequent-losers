# Main Regression Tables (4-10)

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

# Load data
dt <- readRDS(DATA_CACHE)

# Analysis sample: items with both litigated and ordinary
dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]
cat("Analysis sample:", nrow(dt), "obs\n")

# Winsorize 1%/99% (baseline)
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

# Winners subsample
dt_win <- dt[po_firm_winner == 1]
cat("Winners subsample:", nrow(dt_win), "obs\n")

# FE row labels for tables
fe_add_rows <- fe_rows()

# TABLE 4: Reference Prices (DV: bid_price_ref_log)
cat("\n--- Table 4: Reference Prices ---\n")

# PBU clustering (primary)
t4_pbu <- run_feols4("bid_price_ref_log", "urgent", dt_win, cluster = ~pbu_id)
save_table(t4_pbu, "Reference Prices (Cluster: PBU)", "table4_ref_prices_cluster_pbu",
           coef_map = coef_labels, add_rows = fe_add_rows)

# Item clustering
t4_item <- run_feols4("bid_price_ref_log", "urgent", dt_win, cluster = ~item_id)
save_table(t4_item, "Reference Prices (Cluster: Item)", "table4_ref_prices_cluster_item",
           coef_map = coef_labels, add_rows = fe_add_rows)

# Two-way clustering
t4_tw <- run_feols4("bid_price_ref_log", "urgent", dt_win, cluster = ~pbu_id + item_id)
save_table(t4_tw, "Reference Prices (Cluster: PBU+Item)", "table4_ref_prices_cluster_twoway",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 5: Quantities (DV: bid_qty_log)
cat("\n--- Table 5: Quantities ---\n")

t5 <- run_feols4("bid_qty_log", "urgent", dt_win, cluster = ~pbu_id)
save_table(t5, "Quantities", "table5_quantities_cluster_pbu",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 6A: Negotiated Prices — Total Effect
cat("\n--- Table 6A: Negotiated Prices (Total Effect) ---\n")

t6a <- run_feols4("bid_price_log", "urgent", dt_win, cluster = ~pbu_id)
save_table(t6a, "Negotiated Prices — Total Effect", "table6a_neg_prices_total_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 6B: Negotiated Prices — Direct Effect (controlling for quantity)
cat("\n--- Table 6B: Negotiated Prices (Direct Effect) ---\n")

t6b <- run_feols4("bid_price_log", c("urgent", "bid_qty_log"), dt_win, cluster = ~pbu_id)
save_table(t6b, "Negotiated Prices — Direct Effect", "table6b_neg_prices_direct_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 7A: Participant Firms — Total Effect
cat("\n--- Table 7A: Participant Firms (Total Effect) ---\n")

t7a <- run_feols4("ln_n_firms", "urgent", dt_win, cluster = ~pbu_id)
save_table(t7a, "Participant Firms — Total Effect", "table7a_firms_total_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 7B: Participant Firms — Direct Effect
cat("\n--- Table 7B: Participant Firms (Direct Effect) ---\n")

t7b <- run_feols4("ln_n_firms", c("urgent", "bid_qty_log"), dt_win, cluster = ~pbu_id)
save_table(t7b, "Participant Firms — Direct Effect", "table7b_firms_direct_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 9A: Success/Failure LPM — Total Effect (all obs, no winner filter)
cat("\n--- Table 9A: Success LPM (Total Effect) ---\n")

t9a <- run_feols4("po_firm_winner", "urgent", dt, cluster = ~pbu_id)
save_table(t9a, "Success (LPM) — Total Effect", "table9a_success_total_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 9B: Success/Failure LPM — Direct Effect
cat("\n--- Table 9B: Success LPM (Direct Effect) ---\n")

t9b <- run_feols4("po_firm_winner", c("urgent", "bid_qty_log"), dt, cluster = ~pbu_id)
save_table(t9b, "Success (LPM) — Direct Effect", "table9b_success_direct_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# TABLE 10: Under the Gun (UTG) — urgent purchases only
cat("\n--- Table 10: Under the Gun ---\n")

# UTG subsample: only urgent, items with both admin and litigated
dt_utg <- dt[purchase_type == 1 | purchase_type == 2]
dt_utg[, has_admin2 := any(purchase_type == 1), by = item]
dt_utg[, has_lit2   := any(purchase_type == 2), by = item]
dt_utg <- dt_utg[has_admin2 == TRUE & has_lit2 == TRUE]
dt_utg_win <- dt_utg[po_firm_winner == 1]
cat("UTG winners sample:", nrow(dt_utg_win), "obs\n")

# Table 10A: Total Effect (PBU cluster)
t10a <- run_feols4("bid_price_log", "is_admin", dt_utg_win, cluster = ~pbu_id)
save_table(t10a, "Under the Gun — Total Effect", "table10a_underthegun_total_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# Table 10B: Direct Effect (PBU cluster)
t10b <- run_feols4("bid_price_log", c("is_admin", "bid_qty_log"), dt_utg_win, cluster = ~pbu_id)
save_table(t10b, "Under the Gun — Direct Effect", "table10b_underthegun_direct_effect",
           coef_map = coef_labels, add_rows = fe_add_rows)

# Table 10 two-way clustering robustness
t10_tw <- run_feols4("bid_price_log", "is_admin", dt_utg_win, cluster = ~pbu_id + item_id)
save_table(t10_tw, "Under the Gun — Two-way Clustering", "table10_underthegun_cluster_twoway",
           coef_map = coef_labels, add_rows = fe_add_rows)

# Summary: key coefficients
cat("\nKey Coefficients (preferred spec: Item+Year+PBU FE)\n")
print_coef <- function(label, model, var) {
  b <- coef(model)[var]
  se <- sqrt(vcov(model)[var, var])
  pct <- (exp(b) - 1) * 100
  cat(sprintf("  %-40s  β=%.4f (SE=%.4f)  → %.1f%%\n", label, b, se, pct))
}

print_coef("Table 4 (Ref Price, urgent)",    t4_pbu[["Item+Year+PBU"]], "urgent")
print_coef("Table 5 (Quantity, urgent)",      t5[["Item+Year+PBU"]],    "urgent")
print_coef("Table 6A (Neg Price, total)",     t6a[["Item+Year+PBU"]],   "urgent")
print_coef("Table 6B (Neg Price, direct)",    t6b[["Item+Year+PBU"]],   "urgent")
print_coef("Table 7A (Firms, total)",         t7a[["Item+Year+PBU"]],   "urgent")
print_coef("Table 7B (Firms, direct)",        t7b[["Item+Year+PBU"]],   "urgent")
print_coef("Table 9A (Success, total)",       t9a[["Item+Year+PBU"]],   "urgent")
print_coef("Table 10A (UTG, total)",          t10a[["Item+Year+PBU"]],  "is_admin")
print_coef("Table 10B (UTG, direct)",         t10b[["Item+Year+PBU"]],  "is_admin")

cat("\n03_main_regressions.R complete\n")
