# Layer 1 / Lever 6 (storytelling round 2) --- Mini balance table for §3
# Compute means and N by purchase type for the analysis sample (winners only,
# since prices are bid-level): ordinary, administrative, litigated.
#
# Outputs:
#   - tab_descriptive_balance.tex  (3-col booktabs with stats by type)
#   - macros: BP{n,meanLogRef,meanLogNeg,meanQty,meanFirms,success}{Ord,Adm,Lit}

suppressPackageStartupMessages({
  library(data.table)
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

OUT  <- file.path(.this_dir, "..", "output")
LOGS <- file.path(.this_dir, "..", "logs")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)
LOG  <- file.path(LOGS, "46_balance_descriptive.log")
writeLines(sprintf("# 46_balance_descriptive | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()

# Use winners only (prices are bid-level, success is at POI level).
# purchase_type: 0=Ordinary, 1=Administrative, 2=Litigated.
d <- dt[!is.na(purchase_type)]

qty_col <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if ("bid_qty_log" %in% names(d) && qty_col == "bid_qty") {
  d[, lqty := bid_qty_log]
} else {
  d[, lqty := log(pmax(get(qty_col), 1))]
}

# Compute means on winners (price/qty/firms) and success on full POI.
# success is closing with an accepted winner --- po_firm_winner is per-bid;
# need to aggregate to POI level for success rate. Simpler: success rate
# equals share of POIs in which any bid won.
firm_col <- intersect(c("firm_id", "po_firm_winner_id", "cnpj_winner",
                        "cnpj_raiz_winner"), names(d))[1]

agg <- d[!is.na(bid_price_log) & po_firm_winner == 1,
         .(n           = .N,
           mean_logref = mean(bid_price_ref_log, na.rm = TRUE),
           mean_logneg = mean(bid_price_log,     na.rm = TRUE),
           mean_qty    = mean(get(qty_col),      na.rm = TRUE),
           mean_firms  = mean(n_firms_bids,      na.rm = TRUE)),
         by = purchase_type]

# success rate: per POI, did any bid have po_firm_winner==1?
poi_id_col <- intersect(c("poi_id", "po_id", "purchase_offer_item_id"),
                         names(d))[1]
if (is.na(poi_id_col)) {
  # fallback: row-level success share
  success <- d[, .(success_rate = mean(po_firm_winner == 1, na.rm = TRUE)),
               by = purchase_type]
} else {
  success <- d[, .(success = as.integer(any(po_firm_winner == 1, na.rm = TRUE))),
               by = c(poi_id_col, "purchase_type")
              ][, .(success_rate = mean(success, na.rm = TRUE)),
                by = purchase_type]
}
agg <- merge(agg, success, by = "purchase_type")
setorder(agg, purchase_type)
print(agg)

stopifnot(nrow(agg) == 3L)

# Map for label clarity
type_label <- c("0" = "Ord", "1" = "Adm", "2" = "Lit")

emit <- list()
for (i in seq_len(nrow(agg))) {
  lab <- type_label[as.character(agg$purchase_type[i])]
  emit[[paste0("nObs",        lab)]] <- bp_fmt_int(agg$n[i])
  emit[[paste0("meanLogRef",  lab)]] <- bp_fmt(agg$mean_logref[i])
  emit[[paste0("meanLogNeg",  lab)]] <- bp_fmt(agg$mean_logneg[i])
  emit[[paste0("meanQty",     lab)]] <- bp_fmt_int(round(agg$mean_qty[i]))
  emit[[paste0("meanFirms",   lab)]] <- bp_fmt(agg$mean_firms[i])
  emit[[paste0("success",     lab)]] <- bp_fmt_pct(agg$success_rate[i] * 100)
}

bp_macros_emit("46_balance_descriptive", emit)

# Build the table
fmt_row <- function(stat, ord, adm, lit) {
  sprintf("%s & %s & %s & %s \\\\", stat, ord, adm, lit)
}
nobs_row    <- fmt_row("Observations (winners)",
                       emit$nObsOrd, emit$nObsAdm, emit$nObsLit)
logref_row  <- fmt_row("Log reference price",
                       emit$meanLogRefOrd, emit$meanLogRefAdm, emit$meanLogRefLit)
logneg_row  <- fmt_row("Log negotiated price",
                       emit$meanLogNegOrd, emit$meanLogNegAdm, emit$meanLogNegLit)
qty_row     <- fmt_row("Quantity (units)",
                       emit$meanQtyOrd, emit$meanQtyAdm, emit$meanQtyLit)
firms_row   <- fmt_row("Number of bidding firms",
                       emit$meanFirmsOrd, emit$meanFirmsAdm, emit$meanFirmsLit)
success_row <- fmt_row("Tender success rate",
                       emit$successOrd, emit$successAdm, emit$successLit)

tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Sample means by purchase type.}\n",
  "\\label{tab:descriptive_balance}\n",
  "\\begin{threeparttable}\n",
  "\\begin{tabular}{lccc}\n",
  "\\toprule\n",
  " & Ordinary & Administrative & Litigated \\\\\n",
  "\\midrule\n",
  nobs_row, "\n",
  logref_row, "\n",
  logneg_row, "\n",
  qty_row, "\n",
  firms_row, "\n",
  success_row, "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item Means computed on winners (POIs with an accepted winning bid). ",
  "Reference and negotiated prices are in logs; quantity in units; ",
  "tender success rate is the share of POIs that close with an accepted ",
  "winning bid. Sample period: 2009--2019. ",
  "Source: BEC-SP, SES/SP S-CODES.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(tex, file.path(OUT, "tables", "tab_descriptive_balance.tex"))

bp_log_step("done", t0, LOG)
