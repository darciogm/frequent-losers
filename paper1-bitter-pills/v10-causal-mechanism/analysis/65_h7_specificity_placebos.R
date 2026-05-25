# 65_h7_specificity_placebos.R
# Strengthen H7 with a stricter placebo battery.
#
# The target is specificity, not a new identifying design. We ask whether the
# urgent-price pattern appears among never-litigated items when they are bought
# in the same buyer x class environments in which litigated items also appear.

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

OUT <- file.path(.this_dir, "..", "output")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)

dt <- as.data.table(bp_load_cache())

coef_cell <- function(model, term = "urgent") {
  if (is.null(model) || !(term %in% names(coef(model)))) {
    return(list(coef = "--", se = "--", n = "--"))
  }
  b <- coef(model)[term]
  se <- sqrt(vcov(model)[term, term])
  p <- pvalue(model)[term]
  star <- ifelse(is.na(p), "", ifelse(p < .01, "$^{***}$",
                               ifelse(p < .05, "$^{**}$",
                               ifelse(p < .10, "$^{*}$", ""))))
  list(coef = paste0(bp_fmt(b, 3), star),
       se = paste0("(", bp_fmt(se, 3), ")"),
       n = bp_fmt_int(model$nobs),
       b = b,
       raw_se = se)
}

fit_or_null <- function(fml, data, cluster = ~pbu_id) {
  tryCatch(feols(fml, data = data, cluster = cluster),
           error = function(e) {
             cat("[warn] model failed: ", conditionMessage(e), "\n")
             NULL
           })
}

# Never-litigated items with within-item ordinary/admin variation.
item_lit <- dt[, .(ever_litigated = any(purchase_type == 2L),
                   has_ord = any(purchase_type == 0L),
                   has_adm = any(purchase_type == 1L)),
               by = item]
never_items <- item_lit[ever_litigated == FALSE & has_ord == TRUE & has_adm == TRUE, item]

dt[, buyer_class := paste(pbu_id, class_item, sep = "::")]
lit_buyer_class <- unique(dt[purchase_type == 2L & !is.na(class_item), buyer_class])

placebo_all <- dt[item %in% never_items]
placebo_matched <- placebo_all[buyer_class %in% lit_buyer_class]

cat("All never-litigated placebo obs:", nrow(placebo_all), "\n")
cat("Matched buyer-class placebo obs:", nrow(placebo_matched), "\n")
cat("Matched placebo items:", uniqueN(placebo_matched$item), "\n")
cat("Matched buyer-class cells:", uniqueN(placebo_matched$buyer_class), "\n")

# Baseline placebo mirrors AN-008; matched placebo is stricter.
m_all_neg <- fit_or_null(
  bid_price_log ~ urgent | item_id + year_n + pbu_id,
  placebo_all[po_firm_winner == 1L])

m_matched_neg <- fit_or_null(
  bid_price_log ~ urgent | item_id + year_n + pbu_id,
  placebo_matched[po_firm_winner == 1L])

m_matched_neg_qty <- fit_or_null(
  bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id,
  placebo_matched[po_firm_winner == 1L])

m_matched_ref <- fit_or_null(
  bid_price_ref_log ~ urgent | item_id + year_n + pbu_id,
  placebo_matched)

m_matched_bidders <- fit_or_null(
  ln_n_firms ~ urgent | item_id + year_n + pbu_id,
  placebo_matched)

cells <- lapply(list(m_all_neg, m_matched_neg, m_matched_neg_qty,
                     m_matched_ref, m_matched_bidders), coef_cell)

tab <- c(
  "\\begin{table}[ht]",
  "\\centering",
  "\\caption{Litigation-specificity placebo battery}",
  "\\label{tab:h7_placebo_battery}",
  "\\begin{threeparttable}",
  "\\small",
  "\\setlength{\\tabcolsep}{4.5pt}",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  " & All never-lit. & Matched never-lit. & Matched + qty & Matched ref. price & Matched bidders \\\\",
  "\\midrule",
  paste0("Urgent purchase & ", cells[[1]]$coef, " & ", cells[[2]]$coef, " & ",
         cells[[3]]$coef, " & ", cells[[4]]$coef, " & ", cells[[5]]$coef, " \\\\"),
  paste0(" & ", cells[[1]]$se, " & ", cells[[2]]$se, " & ",
         cells[[3]]$se, " & ", cells[[4]]$se, " & ", cells[[5]]$se, " \\\\"),
  "\\addlinespace",
  paste0("Observations & ", cells[[1]]$n, " & ", cells[[2]]$n, " & ",
         cells[[3]]$n, " & ", cells[[4]]$n, " & ", cells[[5]]$n, " \\\\"),
  "Item FE & Yes & Yes & Yes & Yes & Yes \\\\",
  "Year FE & Yes & Yes & Yes & Yes & Yes \\\\",
  "PBU FE & Yes & Yes & Yes & Yes & Yes \\\\",
  "Quantity control & No & No & Yes & No & No \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  "\\item \\textit{Notes:} The matched placebo restricts never-litigated items to buyer-by-class environments that also contain litigated purchases elsewhere in the panel. The exercise is a specificity check: it asks whether the urgent-procurement pattern appears where the litigation channel is absent but procurement environments overlap. Price columns use accepted winning bids when the outcome is negotiated price. Standard errors are clustered by PBU. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tab, file.path(OUT, "tables", "tab_h7_placebo_battery.tex"))

macros <- list(
  HsevenPlaceboAllCoef = bp_fmt(cells[[1]]$b, 3),
  HsevenPlaceboAllSE = bp_fmt(cells[[1]]$raw_se, 3),
  HsevenPlaceboMatchedCoef = bp_fmt(cells[[2]]$b, 3),
  HsevenPlaceboMatchedSE = bp_fmt(cells[[2]]$raw_se, 3),
  HsevenPlaceboMatchedQtyCoef = bp_fmt(cells[[3]]$b, 3),
  HsevenPlaceboMatchedQtySE = bp_fmt(cells[[3]]$raw_se, 3),
  HsevenPlaceboMatchedRefCoef = bp_fmt(cells[[4]]$b, 3),
  HsevenPlaceboMatchedRefSE = bp_fmt(cells[[4]]$raw_se, 3),
  HsevenPlaceboMatchedBiddersCoef = bp_fmt(cells[[5]]$b, 3),
  HsevenPlaceboMatchedBiddersSE = bp_fmt(cells[[5]]$raw_se, 3),
  HsevenPlaceboMatchedItems = bp_fmt_int(uniqueN(placebo_matched$item)),
  HsevenPlaceboMatchedCells = bp_fmt_int(uniqueN(placebo_matched$buyer_class))
)
bp_macros_emit("65_h7_specificity_placebos", macros)

cat("Wrote ", file.path(OUT, "tables", "tab_h7_placebo_battery.tex"), "\n", sep = "")
