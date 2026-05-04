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


# Emit macros for the manuscript layer
.bp_macros_path <- file.path(.this_dir, "..", "..", "v7-r2round1", "analysis", "_macros.R")
if (file.exists(.bp_macros_path)) {
  source(.bp_macros_path)

  pull <- function(model, var) {
    list(b  = unname(coef(model)[var]),
         se = unname(sqrt(vcov(model)[var, var])),
         n  = model$nobs)
  }

  m <- list()
  # Reference prices (Table 4)
  r <- pull(t4_pbu[["Item+Year+PBU"]], "urgent")
  m$refCoef <- bp_fmt(r$b, 3); m$refSE <- bp_fmt(r$se, 3)
  m$refPct  <- bp_fmt_pct((exp(r$b) - 1) * 100, 1)
  ri <- pull(t4_pbu[["Item"]], "urgent")
  m$refCoefItem <- bp_fmt(ri$b, 3); m$refPctItem <- bp_fmt_pct((exp(ri$b) - 1) * 100, 1)
  m$refPctPreferred <- m$refPct
  m$refPctItemFE    <- m$refPctItem

  # Quantities (Table 5)
  q <- pull(t5[["Item+Year+PBU"]], "urgent")
  m$qtyCoef <- bp_fmt(q$b, 3); m$qtySE <- bp_fmt(q$se, 3)

  # Negotiated prices Panel A (Table 6A)
  na <- pull(t6a[["Item+Year+PBU"]], "urgent")
  m$negCoef <- bp_fmt(na$b, 3); m$negSE <- bp_fmt(na$se, 3)
  m$negPct  <- bp_fmt_pct((exp(na$b) - 1) * 100, 1)
  m$negPanelAcoefShort <- bp_fmt(na$b, 3)
  m$negNobs <- bp_fmt_int(na$n)
  ni  <- pull(t6a[["Item"]], "urgent")
  m$negCoefItem <- bp_fmt(ni$b, 3)
  m$negPctItem  <- bp_fmt_pct((exp(ni$b) - 1) * 100, 1)
  m$negPctItemFE <- m$negPctItem
  nym <- pull(t6a[["Item+YM+PBU"]], "urgent")
  m$negCoefItemYM <- bp_fmt(nym$b, 3)
  m$negPctItemYM  <- bp_fmt_pct((exp(nym$b) - 1) * 100, 1)
  m$negPctRange   <- sprintf("%s--%s",
                             bp_fmt_pct_n((exp(na$b) - 1) * 100, 1),
                             bp_fmt_pct_n((exp(nym$b) - 1) * 100, 1))
  m$negPctHeadline <- bp_fmt_pct((exp(na$b) - 1) * 100, 1)

  # Negotiated prices Panel B (Table 6B): direct (mediation) effect
  nb <- pull(t6b[["Item+Year+PBU"]], "urgent")
  qb <- pull(t6b[["Item+Year+PBU"]], "bid_qty_log")
  m$negPanelBcoef       <- bp_fmt(nb$b, 3)
  m$negPanelBcoefShort  <- bp_fmt(nb$b, 3)
  m$negPanelBpct        <- bp_fmt_pct((exp(nb$b) - 1) * 100, 1)
  m$negPanelBqty        <- bp_fmt(qb$b, 3)

  # Firms (Table 7A)
  fm <- pull(t7a[["Item+Year+PBU"]], "urgent")
  m$firmsCoef <- bp_fmt(fm$b, 3); m$firmsSE <- bp_fmt(fm$se, 3)
  m$firmsPct  <- bp_fmt_pct((exp(fm$b) - 1) * 100, 1)
  m$firmsPctHeadline <- m$firmsPct

  # Success (Table 9A): LPM, so coefficient is in pp directly
  sm <- pull(t9a[["Item+Year+PBU"]], "urgent")
  m$successCoef <- bp_fmt(sm$b, 3); m$successSE <- bp_fmt(sm$se, 3)
  m$successPct  <- bp_fmt_pp(sm$b * 100, 1)
  m$successPP   <- bp_fmt_pp(sm$b * 100, 1)

  # UTG (Table 10A/B)
  ua <- pull(t10a[["Item+Year+PBU"]], "is_admin")
  uy <- pull(t10a[["Item+YM+PBU"]],   "is_admin")
  ub <- pull(t10b[["Item+Year+PBU"]], "is_admin")
  uq <- pull(t10b[["Item+Year+PBU"]], "bid_qty_log")
  # UTG prose convention: report litigated > administrative. Coef is on
  # is_admin (negative); flip sign for the percentage premium.
  utg_pct <- (exp(-ua$b) - 1) * 100
  utg_pct_iym <- (exp(-uy$b) - 1) * 100
  m$utgCoef        <- bp_fmt(ua$b, 3)
  m$utgSE          <- bp_fmt(ua$se, 3)
  m$utgPct         <- bp_fmt_pct(utg_pct, 1)
  m$utgCoefItemYM  <- bp_fmt(uy$b, 3)
  m$utgPctItemYM   <- bp_fmt_pct(utg_pct_iym, 1)
  m$utgPanelBcoef  <- bp_fmt(ub$b, 3)
  m$utgPanelBSE    <- bp_fmt(ub$se, 3)
  m$utgPanelBqty   <- bp_fmt(uq$b, 3)
  # Range used in headline ("23--30%"): flip both endpoints to positive premium
  utg_low  <- min(utg_pct, utg_pct_iym)
  utg_high <- max(utg_pct, utg_pct_iym)
  m$utgPctRange <- sprintf("%s--%s\\%%",
                            bp_fmt_pct_n(utg_low, 0),
                            bp_fmt_pct_n(utg_high, 0))
  m$nUTG <- bp_fmt_int(ua$n)

  bp_macros_emit("03_main_regressions", m)
}

cat("\n03_main_regressions.R complete\n")
