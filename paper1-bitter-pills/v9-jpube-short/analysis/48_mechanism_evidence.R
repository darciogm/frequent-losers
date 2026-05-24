# Direct mechanism-positive evidence for the sourcing channel and
# robustness of the within-firm null. Two outputs:
#
# 1. Winner-switch test (Table A). For each item-buyer pair observed
#    under both admin and litigated regimes, do the WINNERS shift?
#    Reports modal-winner-same share, average distinct-winner counts
#    per regime, Jaccard similarity of winner sets. If winners shift
#    systematically, sourcing channel has direct positive evidence.
#
# 2. Within-firm null robustness (Table B). The within firm-buyer-item
#    null is the empirical pivot of the paper; we re-fit it on five
#    subsamples to confirm the null is not specific to a slice of the
#    data.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

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

OUT  <- file.path(.this_dir, "..", "output")
LOGS <- file.path(.this_dir, "..", "logs")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(LOGS, "48_mechanism_evidence.log")
writeLines(sprintf("# 48_mechanism_evidence | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

# ============================================================================
# Sample setup
# ============================================================================
d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 &
        !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]

firm_col <- intersect(c("firm_id", "po_firm_winner_id", "cnpj_winner",
                        "cnpj_raiz_winner"), names(d))[1]
d[, firm := as.factor(get(firm_col))]
d[, ib := paste(pbu_id, item_id, sep = "_")]
d[, fbi := paste(firm, pbu_id, item_id, sep = "_")]

qty_col <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if ("bid_qty_log" %in% names(d) && qty_col == "bid_qty") {
  d[, lqty := bid_qty_log]
} else {
  d[, lqty := log(pmax(get(qty_col), 1))]
}

ym_col <- intersect(c("ym_id", "year_month", "yyyymm", "ym_f", "ym_int"), names(d))[1]
if (is.na(ym_col)) {
  if ("po_date" %in% names(d)) {
    d[, ym := format(as.Date(po_date), "%Y-%m")]
  } else {
    d[, ym := as.character(year_n)]
  }
} else {
  d[, ym := as.character(get(ym_col))]
}

poi_col <- intersect(c("po_item", "po_item_id", "po_item_seq", "po"), names(d))[1]
if (is.na(poi_col)) {
  d[, poi_unit := .I]
} else {
  d[, poi_unit := as.character(get(poi_col))]
}

# ============================================================================
# Test 1: Winner-switch across regimes (item-buyer pairs)
# ============================================================================
ib_summary <- d[, .(
  has_admin = sum(admin == 1) > 0,
  has_lit   = sum(admin == 0) > 0,
  n_admin   = sum(admin == 1),
  n_lit     = sum(admin == 0)
), by = ib]
both_ibs <- ib_summary[has_admin & has_lit, ib]
d_both <- d[ib %in% both_ibs]
cat(sprintf("IB pairs with both regimes: %d\n", length(both_ibs)))

# Per ib: distinct winners by regime
winners_per_ib <- d_both[, .(
  admin_winners = list(unique(as.character(firm[admin == 1L]))),
  lit_winners   = list(unique(as.character(firm[admin == 0L])))
), by = ib]
winners_per_ib[, n_admin_winners := vapply(admin_winners, length, integer(1))]
winners_per_ib[, n_lit_winners   := vapply(lit_winners,   length, integer(1))]
winners_per_ib[, n_intersect     := mapply(function(a, l) length(intersect(a, l)),
                                           admin_winners, lit_winners)]
winners_per_ib[, n_union         := mapply(function(a, l) length(union(a, l)),
                                           admin_winners, lit_winners)]
winners_per_ib[, jaccard         := n_intersect / n_union]
winners_per_ib[, any_overlap     := as.integer(n_intersect > 0)]
winners_per_ib[, no_overlap      := 1L - any_overlap]

# Modal winner per regime
modal_per_ib <- d_both[, .(
  modal_admin = {tab <- table(as.character(firm[admin == 1L]));
                 if (length(tab) > 0) names(sort(tab, decreasing = TRUE))[1] else NA_character_},
  modal_lit   = {tab <- table(as.character(firm[admin == 0L]));
                 if (length(tab) > 0) names(sort(tab, decreasing = TRUE))[1] else NA_character_}
), by = ib]
modal_per_ib[, modal_same := as.integer(modal_admin == modal_lit)]

cat(sprintf("\n--- Winner-switch results ---\n"))
cat(sprintf("IB pairs with both regimes:          %d\n", nrow(winners_per_ib)))
cat(sprintf("Mean n distinct winners (admin):     %.2f\n", mean(winners_per_ib$n_admin_winners)))
cat(sprintf("Mean n distinct winners (lit):       %.2f\n", mean(winners_per_ib$n_lit_winners)))
cat(sprintf("Mean Jaccard winner sets:            %.3f\n", mean(winners_per_ib$jaccard)))
cat(sprintf("Median Jaccard winner sets:          %.3f\n", median(winners_per_ib$jaccard)))
cat(sprintf("Share with ANY winner overlap:       %.3f\n", mean(winners_per_ib$any_overlap)))
cat(sprintf("Share with NO winner overlap:        %.3f\n", mean(winners_per_ib$no_overlap)))
cat(sprintf("Share with same modal winner:        %.3f\n", mean(modal_per_ib$modal_same, na.rm = TRUE)))

# Build winner-switch table
ws_tab <- data.table(
  metric = c("Item-buyer pairs (both regimes)",
             "Mean distinct winners, admin",
             "Mean distinct winners, litigated",
             "Mean Jaccard similarity, winner sets",
             "Pairs with any winner overlap (\\%)",
             "Pairs with NO winner overlap (\\%)",
             "Pairs with same modal winner (\\%)"),
  value  = c(format(nrow(winners_per_ib), big.mark = ","),
             sprintf("%.2f", mean(winners_per_ib$n_admin_winners)),
             sprintf("%.2f", mean(winners_per_ib$n_lit_winners)),
             sprintf("%.3f", mean(winners_per_ib$jaccard)),
             sprintf("%.1f", mean(winners_per_ib$any_overlap) * 100),
             sprintf("%.1f", mean(winners_per_ib$no_overlap) * 100),
             sprintf("%.1f", mean(modal_per_ib$modal_same, na.rm = TRUE) * 100))
)
print(ws_tab)

ws_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Winner switching across regimes for the same item-buyer pair.}\n",
  "\\label{tab:winner_switch}\n",
  "\\begin{threeparttable}\n",
  "\\begin{tabular}{lr}\n",
  "\\toprule\n",
  paste(sprintf("%s & %s \\\\", ws_tab$metric, ws_tab$value),
        collapse = "\n"),
  "\n",
  "\\midrule\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} Sample of buyer$\\times$item pairs with at least one ",
  "administrative and one litigated urgent purchase. Jaccard similarity is the ",
  "ratio of the cardinality of the intersection to the cardinality of the union ",
  "of the two regimes' winning-firm sets. ``Modal winner'' is the most frequent ",
  "winning firm within each regime for a given pair. Source: BEC-SP, ",
  "\\BPsampleStartYear--\\BPsampleEndYear.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(ws_tex, file.path(OUT, "tables", "tab_winner_switch.tex"))
bp_log_step("winner-switch", t0, LOG)

# ============================================================================
# Test 1b: Aggregation of repeated demands within buyer-item-month cells
# ============================================================================
# This is a direct diagnostic for the scale channel. It asks whether, within
# the same buyer x item x month cells observed under both urgent regimes,
# administrative purchases combine more winning POI demands than litigated
# purchases.
cell_regime <- d[, .(
  n_poi = uniqueN(poi_unit),
  total_qty = sum(get(qty_col), na.rm = TRUE),
  mean_lqty = mean(lqty, na.rm = TRUE)
), by = .(pbu_id, item_id, ym, admin)]

cell_regime[, cell_id := paste(pbu_id, item_id, ym, sep = "_")]
both_cell_ids <- cell_regime[, .(has_admin = any(admin == 1L),
                                 has_lit = any(admin == 0L)),
                             by = cell_id][has_admin & has_lit, cell_id]
cell_regime_both <- cell_regime[cell_id %in% both_cell_ids]
cell_regime_both[, multi_poi := as.integer(n_poi > 1L)]
cell_regime_both[, log_total_qty := log(pmax(total_qty, 1))]

paired <- dcast(cell_regime_both,
                cell_id + pbu_id + item_id + ym ~ admin,
                value.var = c("n_poi", "multi_poi", "total_qty", "log_total_qty"))
setnames(paired,
         old = c("n_poi_0", "n_poi_1", "multi_poi_0", "multi_poi_1",
                 "total_qty_0", "total_qty_1", "log_total_qty_0", "log_total_qty_1"),
         new = c("n_poi_lit", "n_poi_admin", "multi_lit", "multi_admin",
                 "qty_lit", "qty_admin", "log_qty_lit", "log_qty_admin"),
         skip_absent = TRUE)

pval_paired <- function(x_admin, x_lit) {
  if (length(x_admin) < 3L || sd(x_admin - x_lit, na.rm = TRUE) == 0) return(NA_real_)
  tryCatch(t.test(x_admin, x_lit, paired = TRUE)$p.value, error = function(e) NA_real_)
}
fmt_p <- function(p) {
  if (is.na(p)) return("--")
  if (p < 0.001) return("$<0.001$")
  sprintf("%.3f", p)
}

agg_rows <- data.table(
  metric = c("Purchase-offer-items per cell",
             "Cells with repeated POIs (\\%)",
             "Log total quantity per cell"),
  admin = c(mean(paired$n_poi_admin, na.rm = TRUE),
            mean(paired$multi_admin, na.rm = TRUE) * 100,
            mean(paired$log_qty_admin, na.rm = TRUE)),
  litigated = c(mean(paired$n_poi_lit, na.rm = TRUE),
                mean(paired$multi_lit, na.rm = TRUE) * 100,
                mean(paired$log_qty_lit, na.rm = TRUE)),
  diff = c(mean(paired$n_poi_admin - paired$n_poi_lit, na.rm = TRUE),
           mean(paired$multi_admin - paired$multi_lit, na.rm = TRUE) * 100,
           mean(paired$log_qty_admin - paired$log_qty_lit, na.rm = TRUE)),
  p_value = c(pval_paired(paired$n_poi_admin, paired$n_poi_lit),
              pval_paired(paired$multi_admin, paired$multi_lit),
              pval_paired(paired$log_qty_admin, paired$log_qty_lit))
)

fmt_num <- function(x, digits = 2) {
  formatC(round(x, digits), format = "f", digits = digits, big.mark = ",")
}
agg_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Aggregation of repeated urgent demands within buyer-item-month cells.}\n",
  "\\label{tab:aggregation_cells}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\begin{tabular}{lrrrr}\n",
  "\\toprule\n",
  "Metric & Administrative & Litigated & Admin $-$ litigated & $p$-value \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & %s & %s & %s & %s \\\\",
                agg_rows$metric,
                fmt_num(agg_rows$admin),
                fmt_num(agg_rows$litigated),
                fmt_num(agg_rows$diff),
                vapply(agg_rows$p_value, fmt_p, character(1))),
        collapse = "\n"),
  "\n",
  "\\midrule\n",
  "Buyer-item-month cells & \\multicolumn{4}{c}{", bp_fmt_int(nrow(paired)), "} \\\\\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} The unit is a buyer$\\times$item$\\times$year-month ",
  "cell observed with at least one administrative and one litigated urgent ",
  "winning purchase. Each regime-cell is first collapsed to the number of ",
  "distinct purchase-offer-items and total accepted quantity. The log-quantity ",
  "row uses the log of total accepted quantity within the regime-cell. The table ",
  "then reports paired means across common cells. $p$-values are from paired ",
  "$t$-tests across cells. This diagnostic speaks to demand aggregation and ",
  "does not use the firm-buyer-item triple sample.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(agg_tex, file.path(OUT, "tables", "tab_aggregation_cells.tex"))
bp_log_step("aggregation-cells", t0, LOG)

# ============================================================================
# Test 2: Within-firm null robustness across subsamples
# ============================================================================
n_per_fbi <- d[, .N, by = .(fbi, admin)]
fbi_both <- unique(merge(n_per_fbi[admin == 0L][, .(fbi)],
                         n_per_fbi[admin == 1L][, .(fbi)],
                         by = "fbi")$fbi)
d_triple <- d[fbi %in% fbi_both]

# Median quantity for split
med_qty <- median(d_triple$lqty, na.rm = TRUE)

# Detect SUS-formulary indicator
sus_col <- intersect(c("sus_formulary", "is_formulary", "formulary",
                       "sus_basic", "in_remume", "in_rename"), names(d_triple))[1]
have_sus <- !is.na(sus_col)

# Detect period split (year_n)
have_year <- "year_n" %in% names(d_triple)

# Run within-FBI regression on each subsample
fit_fbi <- function(sub_data, label) {
  if (nrow(sub_data) < 100L) return(NULL)
  m <- tryCatch(
    feols(bid_price_log ~ admin | fbi + year_n,
          data = sub_data, cluster = ~pbu_id,
          notes = FALSE, warn = FALSE),
    error = function(e) NULL
  )
  if (is.null(m)) return(NULL)
  data.table(
    label = label,
    n     = nobs(m),
    coef  = unname(coef(m)["admin"]),
    se    = unname(sqrt(diag(vcov(m, cluster = ~pbu_id)))["admin"])
  )
}

robustness <- list()
robustness[[1]] <- fit_fbi(d_triple, "All triples (baseline)")
robustness[[2]] <- fit_fbi(d_triple[lqty >= med_qty], "Above-median quantity")
robustness[[3]] <- fit_fbi(d_triple[lqty <  med_qty], "Below-median quantity")

if (have_sus) {
  d_triple[, sus_flag := as.integer(get(sus_col) > 0)]
  robustness[[4]] <- fit_fbi(d_triple[sus_flag == 1L], "SUS-formulary items")
  robustness[[5]] <- fit_fbi(d_triple[sus_flag == 0L], "Non-formulary items")
}

period_ranges <- list(early = NA_character_, later = NA_character_)
if (have_year) {
  med_year <- median(d_triple$year_n, na.rm = TRUE)
  early <- d_triple[year_n <= med_year]; later <- d_triple[year_n > med_year]
  robustness[[6]] <- fit_fbi(early, "Earlier period")
  robustness[[7]] <- fit_fbi(later, "Later period")
  period_ranges$early <- sprintf("%d--%d", min(early$year_n), max(early$year_n))
  period_ranges$later <- sprintf("%d--%d", min(later$year_n), max(later$year_n))
}

robustness <- rbindlist(Filter(Negate(is.null), robustness))
print(robustness)

# Alternative clustering for the baseline within-FBI estimate. The coefficient
# is identical across rows; only the variance estimator changes.
fit_fbi_alt_cluster <- function(sub_data) {
  m <- feols(bid_price_log ~ admin | fbi + year_n,
             data = sub_data,
             notes = FALSE,
             warn = FALSE)
  cluster_specs <- list(
    list(label = "Buyer/PBU (baseline)", formula = ~pbu_id,
         count_label = function(x) format(uniqueN(x$pbu_id), big.mark = ",")),
    list(label = "Item", formula = ~item_id,
         count_label = function(x) format(uniqueN(x$item_id), big.mark = ",")),
    list(label = "Item-buyer", formula = ~ib,
         count_label = function(x) format(uniqueN(x$ib), big.mark = ",")),
    list(label = "Item + buyer/PBU", formula = ~item_id + pbu_id,
         count_label = function(x) sprintf("%s; %s",
                                           format(uniqueN(x$item_id), big.mark = ","),
                                           format(uniqueN(x$pbu_id), big.mark = ",")))
  )
  rbindlist(lapply(cluster_specs, function(sp) {
    vc <- vcov(m, cluster = sp$formula)
    se <- unname(sqrt(diag(vc))["admin"])
    coef_admin <- unname(coef(m)["admin"])
    t_val <- coef_admin / se
    data.table(
      label = sp$label,
      coef = coef_admin,
      se = se,
      p_val = 2 * (1 - pnorm(abs(t_val))),
      clusters = sp$count_label(sub_data),
      n = nobs(m)
    )
  }))
}

alt_cluster <- fit_fbi_alt_cluster(d_triple)
print(alt_cluster)

# Build robustness table
sig <- function(p) if (p < 0.01) "***" else if (p < 0.05) "**" else if (p < 0.10) "*" else ""
robustness[, t_val := coef / se]
robustness[, p_val := 2 * (1 - pnorm(abs(t_val)))]
robustness[, stars := sapply(p_val, sig)]
alt_cluster[, stars := sapply(p_val, sig)]

rb_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Within firm-buyer-item null: robustness across subsamples.}\n",
  "\\label{tab:within_firm_robustness}\n",
  "\\begin{threeparttable}\n",
  "\\begin{tabular}{lrrr}\n",
  "\\toprule\n",
  "Subsample & $\\hat\\beta_{\\text{Admin}}$ & SE & $N$ \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & %.3f%s & %.3f & %s \\\\",
                robustness$label,
                robustness$coef,
                robustness$stars,
                robustness$se,
                format(robustness$n, big.mark = ",")),
        collapse = "\n"),
  "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} Each row reports the within firm-buyer-item triple ",
  "Admin coefficient on log negotiated price, with FBI and year fixed effects, ",
  "PBU-clustered SEs. Subsamples are constructed from the triple sample ",
  "(\\BPutgTripleCountUTG{} triples). Significance: $^{*}p<0.10$, ",
  "$^{**}p<0.05$, $^{***}p<0.01$.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(rb_tex, file.path(OUT, "tables", "tab_within_firm_robustness.tex"))
bp_log_step("robustness", t0, LOG)

ac_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Within firm-buyer-item estimate: alternative clustering.}\n",
  "\\label{tab:within_firm_alt_cluster}\n",
  "\\begin{threeparttable}\n",
  "\\begin{tabular}{lrrrrr}\n",
  "\\toprule\n",
  "Clustering level & $\\hat\\beta_{\\text{Admin}}$ & SE & $p$-value & Clusters & $N$ \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & %.3f%s & %.3f & %.3f & %s & %s \\\\",
                alt_cluster$label,
                alt_cluster$coef,
                alt_cluster$stars,
                alt_cluster$se,
                alt_cluster$p_val,
                alt_cluster$clusters,
                format(alt_cluster$n, big.mark = ",")),
        collapse = "\n"),
  "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} Each row reports the same baseline within ",
  "firm-buyer-item specification with FBI and year fixed effects. Rows vary ",
  "only the clustering level used to compute standard errors. The coefficient ",
  "is administrative minus litigated log negotiated price. Significance: ",
  "$^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(ac_tex, file.path(OUT, "tables", "tab_within_firm_alt_cluster.tex"))

# Per-subsample macros so the prose reads coef/SE/significance straight from
# the same fit that builds the table (no hand-transcription, no prose/table drift).
rob_suffix <- c(
  "All triples (baseline)" = "wfRobAll",
  "Above-median quantity"  = "wfRobAboveQty",
  "Below-median quantity"  = "wfRobBelowQty",
  "SUS-formulary items"    = "wfRobSUS",
  "Non-formulary items"    = "wfRobNonSUS",
  "Earlier period"         = "wfRobEarly",
  "Later period"           = "wfRobLater"
)
psig_str <- function(p) if (p < 0.01) "p<0.01" else if (p < 0.05) "p<0.05" else if (p < 0.10) "p<0.10" else "n.s."
rob_macros <- list()
for (j in seq_len(nrow(robustness))) {
  suf <- rob_suffix[[robustness$label[j]]]
  if (is.null(suf) || is.na(suf)) next
  rob_macros[[paste0(suf, "Coef")]]   <- sprintf("%+.3f", robustness$coef[j])
  rob_macros[[paste0(suf, "SE")]]     <- sprintf("%.3f",  robustness$se[j])
  rob_macros[[paste0(suf, "Stars")]]  <- robustness$stars[j]
  rob_macros[[paste0(suf, "N")]]      <- bp_fmt_int(robustness$n[j])
  rob_macros[[paste0(suf, "Psig")]]   <- psig_str(robustness$p_val[j])
  rob_macros[[paste0(suf, "PctAbs")]] <- bp_fmt_pct(abs((exp(robustness$coef[j]) - 1) * 100))
}
rob_macros[["wfRobEarlyYears"]] <- period_ranges$early
rob_macros[["wfRobLaterYears"]] <- period_ranges$later

# ============================================================================
# Emit macros
# ============================================================================
ws_macros <- list(
  winnerSwitchIBpairs        = bp_fmt_int(nrow(winners_per_ib)),
  winnerSwitchAdminWinnersMean = bp_fmt(mean(winners_per_ib$n_admin_winners)),
  winnerSwitchLitWinnersMean   = bp_fmt(mean(winners_per_ib$n_lit_winners)),
  winnerSwitchJaccardMean    = bp_fmt(mean(winners_per_ib$jaccard)),
  winnerSwitchJaccardMedian  = bp_fmt(median(winners_per_ib$jaccard)),
  winnerSwitchAnyOverlapPct  = bp_fmt_pct(mean(winners_per_ib$any_overlap) * 100),
  winnerSwitchNoOverlapPct   = bp_fmt_pct(mean(winners_per_ib$no_overlap) * 100),
  winnerSwitchSameModalPct   = bp_fmt_pct(mean(modal_per_ib$modal_same, na.rm = TRUE) * 100),
  winnerSwitchDiffModalPct   = bp_fmt_pct((1 - mean(modal_per_ib$modal_same, na.rm = TRUE)) * 100),
  withinFirmRobustnessNrows  = bp_fmt_int(nrow(robustness)),
  withinFirmAltClusterNrows  = bp_fmt_int(nrow(alt_cluster)),
  aggCellN                   = bp_fmt_int(nrow(paired)),
  aggAdminPOIMean            = bp_fmt(mean(paired$n_poi_admin, na.rm = TRUE), digits = 2),
  aggLitPOIMean              = bp_fmt(mean(paired$n_poi_lit, na.rm = TRUE), digits = 2),
  aggDiffPOIMean             = bp_fmt(mean(paired$n_poi_admin - paired$n_poi_lit, na.rm = TRUE), digits = 2),
  aggAdminMultiPct           = bp_fmt_pct(mean(paired$multi_admin, na.rm = TRUE) * 100),
  aggLitMultiPct             = bp_fmt_pct(mean(paired$multi_lit, na.rm = TRUE) * 100),
  aggDiffMultiPP             = bp_fmt_pp(mean(paired$multi_admin - paired$multi_lit, na.rm = TRUE) * 100),
  aggAdminLogQtyMean         = bp_fmt(mean(paired$log_qty_admin, na.rm = TRUE)),
  aggLitLogQtyMean           = bp_fmt(mean(paired$log_qty_lit, na.rm = TRUE)),
  aggDiffLogQtyMean          = bp_fmt(mean(paired$log_qty_admin - paired$log_qty_lit, na.rm = TRUE))
)
bp_macros_emit("48_mechanism_evidence", c(ws_macros, rob_macros))

bp_log_step("done", t0, LOG)
