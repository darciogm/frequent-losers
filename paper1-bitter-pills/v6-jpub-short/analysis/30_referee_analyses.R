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
if (length(macros) > 0) bp_macros_emit("30_referee_analyses", macros)

cat("\nAll referee analyses complete\n")
