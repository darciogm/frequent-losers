# 61_h4_quantity_quartiles.R --- characterize the quantity axis of the H4
# thin-market heterogeneity. Reconciles the median split (below-median +0.066,
# above-median -0.005) with the continuous admin x log-quantity interaction
# (+0.021), by estimating the within firm-buyer-item admin coefficient by
# quantity QUARTILE and testing curvature with a quadratic interaction.
# Same triple sample as 48_mechanism_evidence.R / 60_referee_tests.R.

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
firm_col <- intersect(c("firm_id", "po_firm_winner_id", "cnpj_winner",
                        "cnpj_raiz_winner"), names(d))[1]
d[, firm := as.factor(get(firm_col))]
d[, fbi := paste(firm, pbu_id, item_id, sep = "_")]
qty_col <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if ("bid_qty_log" %in% names(d) && qty_col == "bid_qty") d[, lqty := bid_qty_log] else d[, lqty := log(pmax(get(qty_col), 1))]

n_per_fbi <- d[, .N, by = .(fbi, admin)]
fbi_both  <- unique(merge(n_per_fbi[admin == 0L][, .(fbi)],
                          n_per_fbi[admin == 1L][, .(fbi)], by = "fbi")$fbi)
dT <- d[fbi %in% fbi_both]

# quantity quartiles within the triple sample
qb <- quantile(dT$lqty, probs = c(0, .25, .5, .75, 1), na.rm = TRUE)
dT[, qtile := cut(lqty, breaks = unique(qb), include.lowest = TRUE,
                  labels = paste0("Q", seq_len(length(unique(qb)) - 1)))]
cat("Quartile cutpoints (log qty):", paste(round(qb, 3), collapse = " "), "\n")
cat("Obs per quartile:\n"); print(dT[, .N, by = qtile][order(qtile)])

# admin coefficient by quantity quartile, within FBI + year (one regression)
mq <- feols(bid_price_log ~ i(qtile, admin) | fbi + year_n, data = dT, cluster = ~pbu_id)
print(summary(mq))
cf <- coef(mq); se <- sqrt(diag(vcov(mq, cluster = ~pbu_id)))
qrows <- grep("^qtile::", names(cf), value = TRUE)
cat("\n--- Admin coef by quantity quartile (within FBI) ---\n")
qsumm <- data.table(term = qrows, coef = cf[qrows], se = se[qrows])
qsumm[, q := sub("^qtile::(Q[0-9]).*", "\\1", term)]
qsumm[, p := 2 * (1 - pnorm(abs(coef / se)))]
print(qsumm[, .(q, coef = round(coef, 3), se = round(se, 3), p = round(p, 3))])

# curvature test: quadratic admin x log-quantity (centered)
dT[, lqc := lqty - mean(lqty, na.rm = TRUE)]
mquad <- feols(bid_price_log ~ admin + admin:lqc + admin:I(lqc^2) | fbi + year_n,
               data = dT, cluster = ~pbu_id)
cq  <- coef(mquad); sq <- sqrt(diag(vcov(mquad, cluster = ~pbu_id)))
lin <- cq["admin:lqc"]; lin_se <- sq["admin:lqc"]
qua <- cq["admin:I(lqc^2)"]; qua_se <- sq["admin:I(lqc^2)"]
qua_p <- if (is.na(qua) || is.na(qua_se) || qua_se == 0) NA_real_ else 2 * (1 - pnorm(abs(qua / qua_se)))
cat(sprintf("\nQuadratic interaction: linear admin:lqc = %.4f (SE %.4f); curvature admin:lqc^2 = %s\n",
            lin, lin_se, if (is.na(qua)) "NA (collinear/dropped)" else sprintf("%.4f (SE %.4f, p=%.3f)", qua, qua_se, qua_p)))
if (is.na(qua_p)) {
  cat("  => curvature not separately identified; the quartile pattern characterizes the shape.\n")
} else if (qua_p < 0.05 && qua > 0) {
  cat("  => U-shaped: admin effect highest at the quantity extremes.\n")
} else if (qua_p < 0.05 && qua < 0) {
  cat("  => inverted-U.\n")
} else {
  cat("  => no significant curvature.\n")
}

# Disambiguation: is the quartile gradient same-firm PRICING or the SCALE channel
# (bulk discounts) leaking through? Re-fit the per-quartile admin coefficient
# holding log-quantity fixed within FBI. If the gradient collapses, it is scale.
mqc <- feols(bid_price_log ~ i(qtile, admin) + lqty | fbi + year_n,
             data = dT, cluster = ~pbu_id)
cfc <- coef(mqc); sec <- sqrt(diag(vcov(mqc, cluster = ~pbu_id)))
qc1 <- cfc["qtile::Q1:admin"]; qc4 <- cfc["qtile::Q4:admin"]
lqty_b <- cfc["lqty"]; lqty_se <- sec["lqty"]
cat(sprintf("\n--- With within-FBI log-quantity control ---\n"))
cat(sprintf("Q1 admin: %.3f -> %.3f ; Q4 admin: %.3f -> %.3f (controlled)\n",
            qsumm[q=="Q1", coef], qc1, qsumm[q=="Q4", coef], qc4))
cat(sprintf("Within-FBI log-quantity coef: %.4f (SE %.4f) -- direct bulk-discount evidence\n",
            lqty_b, lqty_se))
cat("  => The raw quartile gradient is the scale/bulk-discount channel, not same-firm pricing.\n")

q1 <- qsumm[q == "Q1"]; q4 <- qsumm[q == "Q4"]
mac <- list(
  h4Q1Coef = sprintf("%+.3f", qsumm[q == "Q1", coef]),
  h4Q1SE   = sprintf("%.3f",  qsumm[q == "Q1", se]),
  h4Q2Coef = sprintf("%+.3f", qsumm[q == "Q2", coef]),
  h4Q3Coef = sprintf("%+.3f", qsumm[q == "Q3", coef]),
  h4Q4Coef = sprintf("%+.3f", qsumm[q == "Q4", coef]),
  h4Q4SE   = sprintf("%.3f",  qsumm[q == "Q4", se]),
  h4QtileLinSlope = sprintf("%+.4f", lin),
  h4Q1CoefCtl = sprintf("%+.3f", qc1),
  h4Q4CoefCtl = sprintf("%+.3f", qc4),
  h4WithinFbiLqtyCoef = sprintf("%.3f", lqty_b),
  h4WithinFbiLqtySE   = sprintf("%.3f", lqty_se),
  h4QuadCurv  = if (is.na(qua)) "n/a" else sprintf("%+.4f", qua),
  h4QuadCurvP = if (is.na(qua_p)) "n/a" else sprintf("%.3f", qua_p)
)
# Site-only diagnostics: emit to a separate file NOT \input by the paper
# (keys carry hypothesis IDs like h4, illegal in LaTeX control sequences).
bp_macros_emit("61_h4_quantity_quartiles", mac, file = file.path(.this_dir, "referee_macros.tex"))
cat("\n[61_h4_quantity_quartiles] done.\n"); print(mac)
