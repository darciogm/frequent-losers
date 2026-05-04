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
source(file.path(.this_dir, "_macros.R"))

OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v7-r2round1/output"
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


# 1F. Tightest UTG comparison: item x year-month FE.
# The Results.tex paragraph cites the coefficient, the within-cell N,
# the share of cells with both purchase types, and the quantity decomposition.
cat("\n1F: UTG with item x year-month FE\n")
utg_dt <- dt[has_admin == TRUE & has_litigated == TRUE & urgent == 1L &
             po_firm_winner == 1L &
             !is.na(bid_price_log) & !is.na(is_admin)]
utg_dt[, item_ym := paste(item, ym_int, sep = "_")]
cell_counts <- utg_dt[, .(n = .N,
                         both = (any(is_admin == 1L) & any(is_admin == 0L))),
                      by = item_ym]
n_total_cells   <- nrow(cell_counts)
n_both_cells    <- sum(cell_counts$both)
n_singleton     <- sum(cell_counts$n == 1L)
utg_within      <- utg_dt[item_ym %in% cell_counts[n > 1L, item_ym]]
n_within        <- nrow(utg_within)

m_utg_iym <- feols(bid_price_log ~ is_admin | item_id + ym_f + pbu_id,
                   data = utg_dt, cluster = ~pbu_id)
m_utg_iym_q <- feols(bid_price_log ~ is_admin + bid_qty_log | item_id + ym_f + pbu_id,
                     data = utg_dt, cluster = ~pbu_id)
m_qty_iym <- feols(bid_qty_log ~ is_admin | item_id + ym_f + pbu_id,
                   data = utg_dt, cluster = ~pbu_id)

cat(sprintf("  N within-cell variation: %d (singletons absorbed: %d, total cells: %d, both-types cells: %d = %.1f%%)\n",
            n_within, n_singleton, n_total_cells, n_both_cells,
            100 * n_both_cells / n_total_cells))
cat(sprintf("  UTG i*ym coef (Panel A): %.4f\n", coef(m_utg_iym)["is_admin"]))
cat(sprintf("  UTG i*ym coef (Panel B + qty): %.4f (SE %.4f)\n",
            coef(m_utg_iym_q)["is_admin"],
            sqrt(vcov(m_utg_iym_q)["is_admin","is_admin"])))
cat(sprintf("  qty on admin (i*ym + PBU): %.4f\n", coef(m_qty_iym)["is_admin"]))

# Emit macros for the manuscript layer
macros <- list()
macros$utgNobsItemYM        <- bp_fmt_int(n_within)
macros$utgSingletonsItemYM  <- bp_fmt_int(n_singleton)
macros$utgCellsItemYM       <- bp_fmt_int(n_total_cells)
macros$utgCellsBoth         <- bp_fmt_int(n_both_cells)
macros$utgCellsBothPct      <- bp_fmt_pct(100 * n_both_cells / n_total_cells, 0)
macros$utgPanelBItemYMcoef  <- bp_fmt(coef(m_utg_iym_q)["is_admin"], 3)
macros$utgPanelBItemYMSE    <- bp_fmt(sqrt(vcov(m_utg_iym_q)["is_admin","is_admin"]), 3)
macros$utgQtyAdminCoef      <- bp_fmt(coef(m_qty_iym)["is_admin"], 3)
macros$utgQtyAdminPct       <- bp_fmt_pct((exp(coef(m_qty_iym)["is_admin"]) - 1) * 100, 0)
# Geometric multiplier: e^coef. "admin orders are X times the size of litigated"
# is more palatable than "X% larger" when X is large (e.g. 230%).
macros$utgQtyAdminFold      <- bp_fmt(exp(coef(m_qty_iym)["is_admin"]), 1)
# Same fold for the preferred (Item+Year+PBU) spec to be safe
m_qty_iy_pbu <- feols(bid_qty_log ~ is_admin | item_id + year_n + pbu_id,
                      data = utg_dt, cluster = ~pbu_id)
macros$utgQtyAdminFoldPref  <- bp_fmt(exp(coef(m_qty_iy_pbu)["is_admin"]), 1)
macros$utgQtyAdminCoefPref  <- bp_fmt(coef(m_qty_iy_pbu)["is_admin"], 3)

# Forensic: trace what spec / sample produces the legacy 0.787 / 120% qty-on-admin
# coefficient that earlier drafts cited. The current spec (item x ym + PBU FE,
# entire UTG sample) gives 1.193 / 230%. Try alternative samples / FE to see
# which one matches 0.787.
cat("\n1G: Forensic on qty-on-admin 0.787 -> 1.193 drift\n")
forensic_specs <- list(
  item_only        = list(d = utg_dt, fe = "item_id"),
  item_year        = list(d = utg_dt, fe = "item_id + year_n"),
  item_year_pbu    = list(d = utg_dt, fe = "item_id + year_n + pbu_id"),
  item_ym_pbu      = list(d = utg_dt, fe = "item_id + ym_f + pbu_id"),
  item_only_winsor = list(d = utg_dt, fe = "item_id"),  # winsorized below
  item_pbu         = list(d = utg_dt, fe = "item_id + pbu_id")
)
# Try with winsorized log quantity (1/99) on the qty side
utg_dt_w <- copy(utg_dt)
utg_dt_w[, bid_qty_log_w := pmin(pmax(bid_qty_log,
                                       quantile(bid_qty_log, 0.01, na.rm=TRUE)),
                                   quantile(bid_qty_log, 0.99, na.rm=TRUE))]
for (nm in names(forensic_specs)) {
  sp <- forensic_specs[[nm]]
  dv <- if (nm == "item_only_winsor") "bid_qty_log_w" else "bid_qty_log"
  d  <- if (nm == "item_only_winsor") utg_dt_w else sp$d
  m  <- tryCatch(feols(as.formula(sprintf("%s ~ is_admin | %s", dv, sp$fe)),
                       data = d, cluster = ~pbu_id),
                 error = function(e) NULL)
  if (!is.null(m)) {
    b  <- unname(coef(m)["is_admin"])
    pc <- (exp(b) - 1) * 100
    cat(sprintf("  %-20s coef=%.4f  pct=%.0f%%  N=%d\n", nm, b, pc, m$nobs))
  }
}
if (exists("qty_admin") && exists("qty_litig")) {
  macros$qtyGapAdmLit <- bp_fmt(qty_admin - qty_litig, 2)
}
if (exists("bulk_elast")) {
  macros$bulkElast <- bp_fmt(bulk_elast, 2)
}
if (exists("qty_gap") && exists("bulk_elast")) {
  implied_pct <- (exp(abs(qty_gap * bulk_elast)) - 1) * 100
  macros$qtyImpliedPct <- bp_fmt_pct_n(implied_pct, 0)
}
# Dose-response: urgency premium by intensity of judicial pressure on the item.
# Intensity = # litigated purchases (purchase_type == 2) per item-year. Bins:
#   1-2 (low), 3-5 (mid), 6-10 (high). Item+Year+PBU FE preferred spec.
cat("\n1E: Dose-response by court orders per item-year\n")
dose_dt <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1 &
              !is.na(bid_price_log)]
ct_iy <- dose_dt[purchase_type == 2L, .(ct = .N), by = .(item, year_n)]
dose_dt <- merge(dose_dt, ct_iy, by = c("item", "year_n"), all.x = TRUE)
dose_dt[is.na(ct), ct := 0L]
dose_dt[, dose_bin := fcase(
  urgent == 0L,             "ord",
  ct >= 1L  & ct <= 2L,     "lo",
  ct >= 3L  & ct <= 5L,     "mid",
  ct >= 6L  & ct <= 10L,    "hi",
  ct >= 11L,                "chronic",
  default = NA_character_)]
dose_models <- list()
for (b in c("lo", "mid", "hi")) {
  d_b <- dose_dt[dose_bin %in% c("ord", b)]
  d_b[, urgent_b := as.integer(dose_bin == b)]
  if (nrow(d_b) > 100L) {
    dose_models[[b]] <- tryCatch(
      feols(bid_price_log ~ urgent_b | item_id + year_n + pbu_id,
            data = d_b, cluster = ~pbu_id),
      error = function(e) { cat("  dose", b, ":", e$message, "\n"); NULL })
  }
}
dose_pcts <- list()
dose_se_b <- list()
dose_n    <- list()
for (b in names(dose_models)) {
  if (!is.null(dose_models[[b]])) {
    coef_b <- coef(dose_models[[b]])["urgent_b"]
    se_b   <- sqrt(vcov(dose_models[[b]])["urgent_b","urgent_b"])
    dose_pcts[[b]] <- (exp(coef_b) - 1) * 100
    dose_se_b[[b]] <- se_b
    dose_n[[b]]    <- dose_models[[b]]$nobs
    lo <- (exp(coef_b - 1.96 * se_b) - 1) * 100
    hi <- (exp(coef_b + 1.96 * se_b) - 1) * 100
    cat(sprintf("  bin=%s  coef=%.4f (SE %.4f)  pct=%.2f%%  IC95=[%.2f%%, %.2f%%]  N=%d\n",
                b, coef_b, se_b, dose_pcts[[b]], lo, hi, dose_n[[b]]))
  }
}
# Test whether mid and hi are distinguishable: 95% CIs overlap?
if (!is.null(dose_pcts$mid) && !is.null(dose_pcts$hi)) {
  cm <- coef(dose_models$mid)["urgent_b"];  sm <- dose_se_b$mid
  ch <- coef(dose_models$hi)["urgent_b"];   sh <- dose_se_b$hi
  diff <- cm - ch
  se_diff <- sqrt(sm^2 + sh^2)   # naive (assumes independence between bins)
  z <- diff / se_diff
  cat(sprintf("  mid - hi (log scale): %.4f (naive SE %.4f), z=%.2f\n", diff, se_diff, z))
}
# Item/firm overlap (used in supplier-FE section, prose: "92% of winning firms serve both")
if (exists("firms_both") && exists("firms_urg")) {
  macros$supFirmsBothShare <- bp_fmt_pct(100 * length(firms_both) / length(firms_urg), 0)
}
# Dose-response macros (urgency premium by court-orders-per-item-year intensity)
if (length(dose_pcts) > 0) {
  for (b_nm in names(dose_pcts)) {
    pc  <- dose_pcts[[b_nm]]; se_b <- dose_se_b[[b_nm]]
    cb  <- coef(dose_models[[b_nm]])["urgent_b"]
    lo_pct <- (exp(cb - 1.96 * se_b) - 1) * 100
    hi_pct <- (exp(cb + 1.96 * se_b) - 1) * 100
    suffix <- switch(b_nm, lo = "Low", mid = "Mid", hi = "High")
    macros[[paste0("dose", suffix)]]      <- bp_fmt_pct(pc, 1)
    macros[[paste0("dose", suffix, "CIlo")]] <- bp_fmt_pct(lo_pct, 1)
    macros[[paste0("dose", suffix, "CIhi")]] <- bp_fmt_pct(hi_pct, 1)
  }
  if (!is.null(dose_pcts$mid) && !is.null(dose_pcts$hi)) {
    cm <- coef(dose_models$mid)["urgent_b"];  sm <- dose_se_b$mid
    ch <- coef(dose_models$hi)["urgent_b"];   sh <- dose_se_b$hi
    z  <- (cm - ch) / sqrt(sm^2 + sh^2)
    macros$doseMidVsHighZ <- bp_fmt(z, 2)
  }
}
# --------------------------------------------------------------------------
# v7-r2round1 NEW (Wave 1): Per-channel positive evidence.
#   T2.1 -- Reference-price Panel B (isolates pure demand-side, can't reflect
#           supplier markup since reference price is set BEFORE bidding)
#   T2.2 -- Firms-count Panel B (urgency reduces participation even holding
#           qty constant -> demand-side participation channel)
#   T2.4 -- Search-cost proxy via mean bids per firm per tender
# Sample = winners with both ord and lit, baseline matching Tabela tab_neg_prices.
# --------------------------------------------------------------------------
cat("\n2A: T2.1 Reference-price Panel B (demand-side residual after qty)\n")
d_ref <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1L &
            !is.na(bid_price_ref_log) & !is.na(bid_qty_log)]
m_ref_total <- feols(bid_price_ref_log ~ urgent | item_id + year_n + pbu_id,
                     data = d_ref, cluster = ~pbu_id)
m_ref_qty   <- feols(bid_price_ref_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                     data = d_ref, cluster = ~pbu_id)
b_ref_total <- unname(coef(m_ref_total)["urgent"])
b_ref_qty   <- unname(coef(m_ref_qty)["urgent"])
se_ref_qty  <- sqrt(vcov(m_ref_qty)["urgent","urgent"])
cat(sprintf("  Total: coef=%.4f (pct=%.2f%%) | After qty: coef=%.4f (pct=%.2f%%, SE=%.4f)\n",
            b_ref_total, (exp(b_ref_total)-1)*100,
            b_ref_qty,   (exp(b_ref_qty)-1)*100, se_ref_qty))
macros$refPanelBcoef <- bp_fmt(b_ref_qty, 3)
macros$refPanelBpct  <- bp_fmt_pct((exp(b_ref_qty) - 1) * 100, 1)
macros$refPanelBSE   <- bp_fmt(se_ref_qty, 3)

cat("\n2B: T2.2 Firms-count Panel B (participation residual after qty)\n")
d_firms <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1L &
              !is.na(ln_n_firms) & !is.na(bid_qty_log)]
m_firms_total <- feols(ln_n_firms ~ urgent | item_id + year_n + pbu_id,
                       data = d_firms, cluster = ~pbu_id)
m_firms_qty   <- feols(ln_n_firms ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                       data = d_firms, cluster = ~pbu_id)
b_firms_total <- unname(coef(m_firms_total)["urgent"])
b_firms_qty   <- unname(coef(m_firms_qty)["urgent"])
se_firms_qty  <- sqrt(vcov(m_firms_qty)["urgent","urgent"])
cat(sprintf("  Total: coef=%.4f (pct=%.2f%%) | After qty: coef=%.4f (pct=%.2f%%, SE=%.4f)\n",
            b_firms_total, (exp(b_firms_total)-1)*100,
            b_firms_qty,   (exp(b_firms_qty)-1)*100, se_firms_qty))
macros$firmsPanelBcoef <- bp_fmt(b_firms_qty, 3)
macros$firmsPanelBpct  <- bp_fmt_pct((exp(b_firms_qty) - 1) * 100, 1)
macros$firmsPanelBSE   <- bp_fmt(se_firms_qty, 3)

cat("\n2C: T2.4 Search-cost proxy (mean bids per participating firm)\n")
# n_bids_bids per tender / n_firms_bids per tender = mean bids per firm during
# the bidding phase. A drop under urgency means officials stop iterating bids
# before searching widely. We compute the ratio at the POI level (each POI is a
# single bidding round in BEC) and average within urgency status.
if ("n_bids_bids" %in% names(dt) && "n_firms_bids" %in% names(dt)) {
  d_search <- dt[!is.na(n_bids_bids) & !is.na(n_firms_bids) & n_firms_bids > 0,
                 .(bids_per_firm = n_bids_bids / n_firms_bids, urgent)]
  bpf_urgent <- d_search[urgent == 1L, mean(bids_per_firm, na.rm = TRUE)]
  bpf_ord    <- d_search[urgent == 0L, mean(bids_per_firm, na.rm = TRUE)]
  bpf_diff_pct <- 100 * (bpf_urgent - bpf_ord) / bpf_ord
  cat(sprintf("  Mean bids/firm: urgent=%.2f | ordinary=%.2f | gap=%.2f (%.1f%%)\n",
              bpf_urgent, bpf_ord, bpf_urgent - bpf_ord, bpf_diff_pct))
  # Within-item regression to handle item-mix
  d_search2 <- dt[!is.na(n_bids_bids) & !is.na(n_firms_bids) & n_firms_bids > 0]
  d_search2[, bids_per_firm := n_bids_bids / n_firms_bids]
  m_search <- feols(bids_per_firm ~ urgent | item_id + year_n + pbu_id,
                    data = d_search2, cluster = ~pbu_id)
  cb_s <- unname(coef(m_search)["urgent"])
  se_s <- sqrt(vcov(m_search)["urgent","urgent"])
  cat(sprintf("  Within-item coef (bids/firm ~ urgent): %.4f (SE %.4f)\n", cb_s, se_s))
  macros$searchBidsPerFirmUrgent     <- bp_fmt(bpf_urgent, 2)
  macros$searchBidsPerFirmOrdinary   <- bp_fmt(bpf_ord, 2)
  macros$searchBidsPerFirmGapPct     <- bp_fmt_pct(bpf_diff_pct, 1)
  macros$searchBidsPerFirmWithinCoef <- bp_fmt(cb_s, 3)
  macros$searchBidsPerFirmWithinSE   <- bp_fmt(se_s, 3)
} else {
  cat("  n_bids_bids or n_firms_bids missing; skipping search-cost macros.\n")
}

# --------------------------------------------------------------------------
# v7-r2round1 NEW (Wave 2): Heterogeneity tests for C2 (participation) and
# C3 (selection) channels.
#   T2.3-alt -- Supplier-base depth heterogeneity. Items with thin supplier
#               base should suffer more from the C2 participation channel
#               under urgency (fewer potential bidders to lose).
#   T3.1     -- Market concentration heterogeneity. Selection effect (C3)
#               should be larger in concentrated markets where buyers have
#               fewer outside options to substitute on.
# Note: T2.3 (deadline intensity from po_subject text) abandoned --
#       po_subject averages 61 chars and rarely carries delivery deadlines
#       (28 mentions of DIAS in ~51k litigated subjects).
# --------------------------------------------------------------------------
cat("\n3A: T2.3-alt Supplier-base depth heterogeneity (C2 participation)\n")
# Per-item historical supplier base = unique winning firms over 2009-2019
item_sup_base <- dt[po_firm_winner == 1L & !is.na(firm_id),
                    .(n_suppliers = uniqueN(firm_id)), by = item]
sup_med <- item_sup_base[, median(n_suppliers)]
item_sup_base[, thin_supplier_base := as.integer(n_suppliers <= sup_med)]
cat(sprintf("  Median historical suppliers per item: %d\n", sup_med))
cat(sprintf("  Items with thin (<=median) base: %d | thick: %d\n",
            sum(item_sup_base$thin_supplier_base == 1L),
            sum(item_sup_base$thin_supplier_base == 0L)))

d_supbase <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1L &
                !is.na(bid_price_log) & !is.na(bid_qty_log)]
d_supbase <- merge(d_supbase, item_sup_base, by = "item", all.x = TRUE)
d_supbase <- d_supbase[!is.na(thin_supplier_base)]

m_supbase_thin  <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                         data = d_supbase[thin_supplier_base == 1L], cluster = ~pbu_id)
m_supbase_thick <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                         data = d_supbase[thin_supplier_base == 0L], cluster = ~pbu_id)
cb_thin  <- unname(coef(m_supbase_thin)["urgent"])
cb_thick <- unname(coef(m_supbase_thick)["urgent"])
se_thin  <- sqrt(vcov(m_supbase_thin)["urgent","urgent"])
se_thick <- sqrt(vcov(m_supbase_thick)["urgent","urgent"])
cat(sprintf("  Thin supplier base: urgency coef (Panel B) = %.4f (SE %.4f, pct=%.2f%%)\n",
            cb_thin, se_thin, (exp(cb_thin)-1)*100))
cat(sprintf("  Thick supplier base: urgency coef (Panel B) = %.4f (SE %.4f, pct=%.2f%%)\n",
            cb_thick, se_thick, (exp(cb_thick)-1)*100))
macros$hetSupBaseThinCoef  <- bp_fmt(cb_thin, 3)
macros$hetSupBaseThinPct   <- bp_fmt_pct((exp(cb_thin)-1)*100, 1)
macros$hetSupBaseThinSE    <- bp_fmt(se_thin, 3)
macros$hetSupBaseThickCoef <- bp_fmt(cb_thick, 3)
macros$hetSupBaseThickPct  <- bp_fmt_pct((exp(cb_thick)-1)*100, 1)
macros$hetSupBaseThickSE   <- bp_fmt(se_thick, 3)
macros$hetSupBaseMedianN   <- bp_fmt_int(sup_med)

# Same exercise for participation outcome (firms count) to test C2 directly
m_supbase_thin_firms  <- feols(ln_n_firms ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                               data = d_supbase[thin_supplier_base == 1L], cluster = ~pbu_id)
m_supbase_thick_firms <- feols(ln_n_firms ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                               data = d_supbase[thin_supplier_base == 0L], cluster = ~pbu_id)
cb_thin_f  <- unname(coef(m_supbase_thin_firms)["urgent"])
cb_thick_f <- unname(coef(m_supbase_thick_firms)["urgent"])
cat(sprintf("  Firms Panel B (thin):  %.4f (pct=%.2f%%)\n", cb_thin_f,  (exp(cb_thin_f)-1)*100))
cat(sprintf("  Firms Panel B (thick): %.4f (pct=%.2f%%)\n", cb_thick_f, (exp(cb_thick_f)-1)*100))
macros$hetSupBaseThinFirmsPct  <- bp_fmt_pct((exp(cb_thin_f)-1)*100, 1)
macros$hetSupBaseThickFirmsPct <- bp_fmt_pct((exp(cb_thick_f)-1)*100, 1)

cat("\n3B: T3.1 Market concentration heterogeneity (C3 selection)\n")
# Concentration proxy = mean number of firms participating per item.
# (HHI on winners is degenerate -- single winner per tender -> HHI=1 always.)
# Items with low mean n_firms = concentrated; high mean = competitive.
item_n_firms <- dt[!is.na(n_firms_bids), .(mean_firms = mean(n_firms_bids, na.rm = TRUE)),
                   by = item]
nf_med <- item_n_firms[, median(mean_firms, na.rm = TRUE)]
item_n_firms[, high_hhi := as.integer(mean_firms <= nf_med)]   # FEW firms = concentrated
cat(sprintf("  Median mean n_firms per item: %.2f\n", nf_med))
cat(sprintf("  High-concentration items (mean firms <= median): %d | Low-concentration: %d\n",
            sum(item_n_firms$high_hhi == 1L, na.rm=TRUE),
            sum(item_n_firms$high_hhi == 0L, na.rm=TRUE)))
item_hhi <- item_n_firms[, .(item, high_hhi)]
hhi_med <- nf_med   # for macro emission below

d_hhi <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1L &
            !is.na(bid_price_log) & !is.na(firm_id)]
d_hhi <- merge(d_hhi, item_hhi[, .(item, high_hhi)], by = "item", all.x = TRUE)
d_hhi <- d_hhi[!is.na(high_hhi)]
d_hhi[, firm_f := as.factor(firm_id)]

# Compare attenuation when adding firm FE in high-HHI vs low-HHI subsamples
m_hhi_high_base   <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id,
                           data = d_hhi[high_hhi == 1L], cluster = ~pbu_id)
m_hhi_high_firmFE <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id + firm_f,
                           data = d_hhi[high_hhi == 1L], cluster = ~pbu_id)
m_hhi_low_base    <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id,
                           data = d_hhi[high_hhi == 0L], cluster = ~pbu_id)
m_hhi_low_firmFE  <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id + firm_f,
                           data = d_hhi[high_hhi == 0L], cluster = ~pbu_id)
b_hh_b <- unname(coef(m_hhi_high_base)["urgent"])
b_hh_f <- unname(coef(m_hhi_high_firmFE)["urgent"])
b_lh_b <- unname(coef(m_hhi_low_base)["urgent"])
b_lh_f <- unname(coef(m_hhi_low_firmFE)["urgent"])
attn_high <- 1 - b_hh_f / b_hh_b
attn_low  <- 1 - b_lh_f / b_lh_b
cat(sprintf("  High-HHI: baseline %.3f -> firmFE %.3f | attn %.0f%% | residual pct %.2f%%\n",
            b_hh_b, b_hh_f, 100*attn_high, (exp(b_hh_f)-1)*100))
cat(sprintf("  Low-HHI:  baseline %.3f -> firmFE %.3f | attn %.0f%% | residual pct %.2f%%\n",
            b_lh_b, b_lh_f, 100*attn_low,  (exp(b_lh_f)-1)*100))
macros$hetHHIhighBaselinePct   <- bp_fmt_pct((exp(b_hh_b)-1)*100, 1)
macros$hetHHIhighFirmFEPct     <- bp_fmt_pct((exp(b_hh_f)-1)*100, 1)
macros$hetHHIhighAttnPct       <- bp_fmt_pct_n(100*attn_high, 0)
macros$hetHHIlowBaselinePct    <- bp_fmt_pct((exp(b_lh_b)-1)*100, 1)
macros$hetHHIlowFirmFEPct      <- bp_fmt_pct((exp(b_lh_f)-1)*100, 1)
macros$hetHHIlowAttnPct        <- bp_fmt_pct_n(100*attn_low, 0)
macros$hetHHIMedianValue       <- bp_fmt(hhi_med, 3)

# Within firm-buyer-item triple: does concentrated-market markup exist there?
# This is the cleanest test of "supply-side under-the-gun in concentrated markets."
# Reuse fbi_triple-style analysis but split by HHI.
d_hhi_triple <- d_hhi[!is.na(firm_id) & !is.na(pbu_code)]
d_hhi_triple[, fbi_triple := paste(firm_id, pbu_code, item, sep = "_")]
fbi_counts2 <- d_hhi_triple[, .(has_ord = any(urgent == 0L), has_urg = any(urgent == 1L)),
                            by = fbi_triple]
good_t2 <- fbi_counts2[has_ord & has_urg, fbi_triple]
d_hhi_t  <- d_hhi_triple[fbi_triple %in% good_t2]
m_t_hhi_high <- feols(bid_price_log ~ urgent | fbi_triple + year_n,
                      data = d_hhi_t[high_hhi == 1L], cluster = ~pbu_id)
m_t_hhi_low  <- feols(bid_price_log ~ urgent | fbi_triple + year_n,
                      data = d_hhi_t[high_hhi == 0L], cluster = ~pbu_id)
cb_t_hh <- unname(coef(m_t_hhi_high)["urgent"])
cb_t_lh <- unname(coef(m_t_hhi_low)["urgent"])
se_t_hh <- sqrt(vcov(m_t_hhi_high)["urgent","urgent"])
se_t_lh <- sqrt(vcov(m_t_hhi_low)["urgent","urgent"])
cat(sprintf("  Triple within-firm-buyer-item: high-HHI = %.4f (SE %.4f, pct=%.2f%%) | low-HHI = %.4f (SE %.4f, pct=%.2f%%)\n",
            cb_t_hh, se_t_hh, (exp(cb_t_hh)-1)*100,
            cb_t_lh, se_t_lh, (exp(cb_t_lh)-1)*100))
macros$hetHHIhighTripleCoef <- bp_fmt(cb_t_hh, 3)
macros$hetHHIhighTriplePct  <- bp_fmt_pct((exp(cb_t_hh)-1)*100, 2)
macros$hetHHIlowTripleCoef  <- bp_fmt(cb_t_lh, 3)
macros$hetHHIlowTriplePct   <- bp_fmt_pct((exp(cb_t_lh)-1)*100, 2)

# --------------------------------------------------------------------------
# v7-r2round1 NEW: Welfare bounds + policy counterfactuals + three-channel
# decomposition (urgent-vs-ord and UTG). Computes magnitudes for the new prose.
# --------------------------------------------------------------------------

# Three-channel decomposition: urgent-vs-ord
# Need 4 specs all on same winners-with-both-types sample to make the cascade
# numerically clean. We pull from existing models if available, else refit.
cat("\n1H: Three-channel decomposition (urgent-vs-ord)\n")
d_main <- dt[has_litigated == TRUE & has_ordinary == TRUE & po_firm_winner == 1L &
             !is.na(bid_price_log)]
d_main[, firm_f := as.factor(firm_id)]
m_uo_total <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id,
                    data = d_main, cluster = ~pbu_id)
m_uo_qty   <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
                    data = d_main, cluster = ~pbu_id)
m_uo_firm  <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id + firm_f,
                    data = d_main, cluster = ~pbu_id)
m_uo_both  <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id + firm_f,
                    data = d_main, cluster = ~pbu_id)
b_uo <- function(m) (exp(unname(coef(m)["urgent"])) - 1) * 100
pp_total <- b_uo(m_uo_total)
pp_qty   <- b_uo(m_uo_qty)
pp_firm  <- b_uo(m_uo_firm)
pp_both  <- b_uo(m_uo_both)
chan_qty_uo  <- pp_total - pp_qty       # C1 contribution: drop when adding qty
chan_firm_uo <- pp_total - pp_firm      # C3 selection contribution: drop when adding firm FE
chan_resid_uo <- pp_both                # residual after C1 + C3 (per-unit demand-side + within-firm markup)
cat(sprintf("  Total: %.2f%%  | -qty: %.2f%%  | -firmFE: %.2f%%  | -both: %.2f%%\n",
            pp_total, pp_qty, pp_firm, pp_both))
cat(sprintf("  C1 (qty): %.2f pp | C3 (firm sel): %.2f pp | Residual: %.2f pp\n",
            chan_qty_uo, chan_firm_uo, chan_resid_uo))
macros$chanQtyUrgentPP      <- bp_fmt(chan_qty_uo,  2)
macros$chanFirmSelUrgentPP  <- bp_fmt(chan_firm_uo, 2)
macros$chanResidualUrgentPP <- bp_fmt(chan_resid_uo, 2)

# Three-channel decomposition: UTG (lit-vs-admin within urgent)
cat("\n1I: Three-channel decomposition (UTG)\n")
d_utg <- dt[has_admin == TRUE & has_litigated == TRUE & urgent == 1L &
            po_firm_winner == 1L & !is.na(bid_price_log)]
m_utg_total <- feols(bid_price_log ~ is_admin | item_id + year_n + pbu_id,
                     data = d_utg, cluster = ~pbu_id)
m_utg_qty   <- feols(bid_price_log ~ is_admin + bid_qty_log | item_id + year_n + pbu_id,
                     data = d_utg, cluster = ~pbu_id)
b_utg <- function(m) (exp(-unname(coef(m)["is_admin"])) - 1) * 100   # litigated premium
pp_utg_total <- b_utg(m_utg_total)
pp_utg_qty   <- b_utg(m_utg_qty)
chan_qty_utg <- pp_utg_total - pp_utg_qty
chan_resid_utg <- pp_utg_qty
cat(sprintf("  UTG total: %.2f%%  | -qty: %.2f%%\n", pp_utg_total, pp_utg_qty))
cat(sprintf("  C1 (qty): %.2f pp | Residual: %.2f pp\n", chan_qty_utg, chan_resid_utg))
macros$chanQtyUTGPP      <- bp_fmt(chan_qty_utg, 2)
macros$chanResidualUTGPP <- bp_fmt(chan_resid_utg, 2)

# Welfare bounds (replaces v6 point estimate $16-18M)
# Calibration anchors: $300M annual litigated spending in SP (BPlitSpendingUSDmm,
# manual narrative); UTG-pct sweep range 23-30%; sanction-exposed base $250-300M.
cat("\n1J: Welfare bounds\n")
LIT_SPENDING_USDMM <- 300
SANCT_EXPOSED_LO   <- 250
SANCT_EXPOSED_HI   <- 300
welfare_low  <- (pp_total / 100) * LIT_SPENDING_USDMM
welfare_high_lo <- (pp_utg_total / 100) * SANCT_EXPOSED_LO
welfare_high_hi <- (pp_utg_total / 100) * SANCT_EXPOSED_HI
cat(sprintf("  Lower bound (5.4%% x $300M): $%.0fM\n", welfare_low))
cat(sprintf("  Upper bound (UTG x $%.0f-%.0fM): $%.0fM-%.0fM\n",
            SANCT_EXPOSED_LO, SANCT_EXPOSED_HI, welfare_high_lo, welfare_high_hi))
macros$welfareBoundLow   <- sprintf("\\$%.0f~M", welfare_low)
macros$welfareBoundHigh  <- sprintf("\\$%.0f--%.0f~M", welfare_high_lo, welfare_high_hi)
macros$welfareBoundRange <- sprintf("\\$%.0f--%.0f~M", welfare_low, welfare_high_hi)

# Policy counterfactuals
# Admin-expansion: UTG-pct of admin-eligible spending. We do not observe the
# committee-eligible fraction directly, so we use a defensible bound: admin
# requests already account for ~6.5% of court-mandated purchases (per institutional
# memory: \BPadminToCourtShare); a credible expansion target is 25-50% (a quarter
# to half of cases would be diverted to admin if the channel were widely available).
# We report the recovery at 50% of $300M as the upper bound.
cat("\n1K: Policy counterfactuals\n")
ADMIN_ELIGIBLE_SHARE <- 0.50   # upper-bound expansion target
FRAMEWORK_FEASIBLE_SHARE <- 0.40   # framework-agreement-feasible items (commodity-like, repeat purchases)
policy_admin_recovery <- (pp_utg_total / 100) * ADMIN_ELIGIBLE_SHARE * LIT_SPENDING_USDMM
policy_framework_recovery <- (chan_qty_uo / 100) * FRAMEWORK_FEASIBLE_SHARE * LIT_SPENDING_USDMM
cat(sprintf("  Admin expansion (UTG x 50%% x $300M): $%.0fM\n", policy_admin_recovery))
cat(sprintf("  Framework agreements (C1-qty x 40%% x $300M): $%.0fM\n", policy_framework_recovery))
macros$policyAdminEligibleShare    <- sprintf("%.0f\\%%", ADMIN_ELIGIBLE_SHARE * 100)
macros$policyFrameworkFeasibleShare <- sprintf("%.0f\\%%", FRAMEWORK_FEASIBLE_SHARE * 100)
macros$policyAdminRecoveryHigh     <- sprintf("\\$%.0f~M", policy_admin_recovery)
macros$policyFrameworkRecovery     <- sprintf("\\$%.0f~M", policy_framework_recovery)

if (length(macros) > 0) bp_macros_emit("30_referee_analyses", macros)

cat("\nAll referee analyses complete\n")
