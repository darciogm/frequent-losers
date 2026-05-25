# 62_h4_period_axis.R --- disambiguate the PERIOD axis of the H4 thin-market
# heterogeneity. The quantity axis turned out to be the scale channel
# (61_h4_quantity_quartiles.R). Does the earlier-period within firm-buyer-item
# markup (+0.117) survive a log-quantity control, or is it scale/composition too?
# Same triple sample as 48/60/61.

suppressPackageStartupMessages({ library(data.table); library(fixest) })

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
bp_set_threads(12L)

dt <- bp_load_cache()
d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 & !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]
fc <- intersect(c("firm_id", "po_firm_winner_id", "cnpj_winner", "cnpj_raiz_winner"), names(d))[1]
d[, firm := as.factor(get(fc))]
d[, fbi := paste(firm, pbu_id, item_id, sep = "_")]
qc <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if ("bid_qty_log" %in% names(d) && qc == "bid_qty") d[, lqty := bid_qty_log] else d[, lqty := log(pmax(get(qc), 1))]
np <- d[, .N, by = .(fbi, admin)]
fb <- unique(merge(np[admin == 0L][, .(fbi)], np[admin == 1L][, .(fbi)], by = "fbi")$fbi)
dT <- d[fbi %in% fb]

med_year <- median(dT$year_n, na.rm = TRUE)
dT[, period := factor(fifelse(year_n <= med_year, "Early", "Late"), levels = c("Early", "Late"))]
cat(sprintf("Median year split: Early = <=%d, Late = >%d\n", med_year, med_year))
cat("Obs by period:\n"); print(dT[, .N, by = period])

se_of <- function(m, v = "admin") unname(sqrt(diag(vcov(m, cluster = ~pbu_id)))[v])

# 1. Early/Late within-FBI admin coef, with vs without log-quantity control.
# Separate-subsample estimation (matches 48_mechanism_evidence.R / the paper's
# +0.117 earlier-period figure) so the disambiguation applies to the reported number.
fit_sub <- function(sub, ctl) {
  f <- if (ctl) bid_price_log ~ admin + lqty | fbi + year_n else bid_price_log ~ admin | fbi + year_n
  m <- feols(f, sub, cluster = ~pbu_id, notes = FALSE, warn = FALSE)
  c(unname(coef(m)["admin"]), se_of(m, "admin"), nobs(m), if (ctl) unname(coef(m)["lqty"]) else NA_real_)
}
early <- dT[year_n <= med_year]; late <- dT[year_n > med_year]
e_no <- fit_sub(early, FALSE); e_ct <- fit_sub(early, TRUE)
l_no <- fit_sub(late, FALSE);  l_ct <- fit_sub(late, TRUE)
lqty_b <- e_ct[4]; lqty_se <- NA_real_

cat("\n--- Within-FBI admin coef by period: no control vs +log-quantity ---\n")
cat(sprintf("Early: %.3f (SE %.3f)  ->  %.3f (SE %.3f) with qty control\n", e_no[1], e_no[2], e_ct[1], e_ct[2]))
cat(sprintf("Late : %.3f (SE %.3f)  ->  %.3f (SE %.3f) with qty control\n", l_no[1], l_no[2], l_ct[1], l_ct[2]))
cat(sprintf("Within-FBI log-quantity coef: %.4f (SE %.4f)\n", lqty_b, lqty_se))

# 2. Composition check: does the early period differ in scale / formulary mix?
sus_col <- intersect(c("sus_formulary","is_formulary","formulary","sus_basic","in_remume","in_rename"), names(dT))[1]
comp <- dT[, .(mean_lqty = mean(lqty, na.rm = TRUE),
               n = .N,
               admin_share = mean(admin)), by = period]
if (!is.na(sus_col)) comp <- merge(comp, dT[, .(sus_share = mean(get(sus_col) > 0, na.rm = TRUE)), by = period], by = "period")
cat("\n--- Composition by period ---\n"); print(comp)

# 3. Continuous year interaction (does a smooth time gradient survive qty control?)
dT[, yr_c := year_n - mean(year_n, na.rm = TRUE)]
my_no <- feols(bid_price_log ~ admin + admin:yr_c        | fbi + year_n, dT, cluster = ~pbu_id)
my_ct <- feols(bid_price_log ~ admin + admin:yr_c + lqty | fbi + year_n, dT, cluster = ~pbu_id)
yint_no <- coef(my_no)["admin:yr_c"]; yint_no_se <- se_of(my_no, "admin:yr_c")
yint_ct <- coef(my_ct)["admin:yr_c"]; yint_ct_se <- se_of(my_ct, "admin:yr_c")
cat(sprintf("\nContinuous admin x year: %.4f (SE %.4f)  ->  %.4f (SE %.4f) with qty control\n",
            yint_no, yint_no_se, yint_ct, yint_ct_se))

# Verdict
e_p_ct <- 2 * (1 - pnorm(abs(e_ct[1] / e_ct[2])))
cat("\n=== Verdict ===\n")
if (e_p_ct < 0.05) {
  cat(sprintf("Earlier-period markup SURVIVES the quantity control (%.3f, p=%.3f): not pure scale.\n", e_ct[1], e_p_ct))
} else {
  cat(sprintf("Earlier-period markup is NOT robust to the quantity control (%.3f, p=%.3f): largely scale/composition.\n", e_ct[1], e_p_ct))
}

mac <- list(
  h4EarlyNoCtl     = sprintf("%+.3f", e_no[1]),
  h4EarlyNoCtlSE   = sprintf("%.3f",  e_no[2]),
  h4EarlyQtyCtl    = sprintf("%+.3f", e_ct[1]),
  h4EarlyQtyCtlSE  = sprintf("%.3f",  e_ct[2]),
  h4EarlyQtyCtlP   = sprintf("%.3f",  e_p_ct),
  h4LateQtyCtl     = sprintf("%+.3f", l_ct[1]),
  h4PeriodLqtyCoef = sprintf("%.3f",  lqty_b),
  h4EarlyMeanLqty  = sprintf("%.2f",  comp[period == "Early", mean_lqty]),
  h4LateMeanLqty   = sprintf("%.2f",  comp[period == "Late",  mean_lqty]),
  h4AdminYearNoCtl = sprintf("%+.4f", yint_no),
  h4AdminYearQtyCtl = sprintf("%+.4f", yint_ct)
)
# Site-only diagnostics: emit to a separate file NOT \input by the paper
# (keys carry hypothesis IDs like h4, illegal in LaTeX control sequences).
bp_macros_emit("62_h4_period_axis", mac, file = file.path(.this_dir, "referee_macros.tex"))
cat("\n[62_h4_period_axis] done.\n"); print(mac)
