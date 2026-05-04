# Prepare BEC-G65-WORK1 parquet for analysis

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

library(arrow)

# Load parquet
cat("Reading parquet:", DATA_RAW, "\n")
dt <- as.data.table(read_parquet(DATA_RAW))
cat("  Raw dimensions:", nrow(dt), "×", ncol(dt), "\n")

# Rename winner variable
# v3 uses po_firm_winner; v4 parquet has po_item_winner
if ("po_item_winner" %in% names(dt) && !"po_firm_winner" %in% names(dt)) {
  setnames(dt, "po_item_winner", "po_firm_winner")
  cat("  Renamed po_item_winner -> po_firm_winner\n")
}

# Treatment variables
# purchase_type already exists as int8: 0=Ordinary, 1=Administrative, 2=Litigated
dt[, urgent  := as.integer(purchase_type > 0)]
dt[, is_admin := as.integer(purchase_type == 1)]
cat("  Purchase type distribution:\n")
print(dt[, .N, keyby = .(purchase_type, urgent, is_admin)])

# Procurement procedure
dt[, pregao := as.integer(po_proc_code == 3)]

# Time variables
# year is string in parquet → convert to integer
dt[, year_n := as.integer(year)]
cat("  Year range:", range(dt$year_n, na.rm = TRUE), "\n")

# m_y is timestamp → create year-month integer for FE
dt[, ym_int := as.integer(format(m_y, "%Y")) * 12L + as.integer(format(m_y, "%m"))]
dt[, ym_f := as.factor(ym_int)]

# Late period indicator
dt[, late_period := as.integer(year_n >= 2014)]

# Log transformations
# Protect against log(0) or log(negative)
dt[bid_price > 0,     bid_price_log     := log(bid_price)]
dt[bid_price_ref > 0, bid_price_ref_log := log(bid_price_ref)]
dt[bid_qty > 0,       bid_qty_log       := log(bid_qty)]
dt[n_firms_bids > 0,  ln_n_firms        := log(n_firms_bids)]

# Factor IDs for fixed effects
dt[, item_id := as.factor(item)]
dt[, pbu_id  := as.factor(pbu_code)]

# Item-level flags
# has_litigated: item has at least one litigated purchase (type 2)
dt[, has_litigated := any(purchase_type == 2), by = item]
# has_ordinary: item has at least one ordinary purchase (type 0)
dt[, has_ordinary  := any(purchase_type == 0), by = item]
# has_admin: item has at least one administrative purchase (type 1)
dt[, has_admin     := any(purchase_type == 1), by = item]

cat("  Items with litigated+ordinary:", dt[has_litigated == TRUE & has_ordinary == TRUE, uniqueN(item)], "\n")

# Heterogeneity variables

# high_competition: above-median item-level median number of firms
item_med_firms <- dt[!is.na(n_firms_bids), .(med_firms = median(n_firms_bids, na.rm = TRUE)), by = item]
overall_median <- median(item_med_firms$med_firms, na.rm = TRUE)
item_med_firms[, high_competition := as.integer(med_firms > overall_median)]
dt <- merge(dt, item_med_firms[, .(item, high_competition)], by = "item", all.x = TRUE)
cat("  High competition split (overall median =", overall_median, "):\n")
print(dt[, .N, keyby = high_competition])

# large_pbu: above-median PBU transaction count
pbu_counts <- dt[, .(n_trans = .N), by = pbu_code]
pbu_median <- median(pbu_counts$n_trans)
pbu_counts[, large_pbu := as.integer(n_trans > pbu_median)]
dt <- merge(dt, pbu_counts[, .(pbu_code, large_pbu)], by = "pbu_code", all.x = TRUE)
cat("  Large PBU split (median =", pbu_median, "transactions):\n")
print(dt[, .N, keyby = large_pbu])

# sus_basic: proxy via class_item_descr (padronizadosus absent in G65)
# Basic = descriptions containing "MEDICAMENTO"; Specialized = others
if ("class_item_descr" %in% names(dt)) {
  dt[, sus_basic := as.integer(grepl("MEDICAMENTO", class_item_descr, ignore.case = TRUE))]
  cat("  SUS basic proxy distribution:\n")
  print(dt[, .N, keyby = sus_basic])
} else {
  dt[, sus_basic := NA_integer_]
  cat("  WARNING: class_item_descr not found, sus_basic set to NA\n")
}

# Summary
cat("\nFinal dataset:", nrow(dt), "obs ×", ncol(dt), "cols\n")
cat("Key variable missingness:\n")
for (v in c("bid_price_log", "bid_price_ref_log", "bid_qty_log", "ln_n_firms",
            "po_firm_winner", "urgent", "is_admin")) {
  n_na <- sum(is.na(dt[[v]]))
  cat(sprintf("  %-20s  %d missing (%.1f%%)\n", v, n_na, 100 * n_na / nrow(dt)))
}

# Save cache
cat("Saving prepared data to:", DATA_CACHE, "\n")
saveRDS(dt, DATA_CACHE, compress = FALSE)
cat("  Done. File size:", round(file.size(DATA_CACHE) / 1e6, 1), "MB\n")

# Emit macros for the v6 manuscript (raw-sample counts).
# v4 scripts forward macros to the v6 values.tex via the shared helper.
.bp_macros_path <- file.path(.this_dir, "..", "..", "v6-jpub-short", "analysis", "_macros.R")
if (file.exists(.bp_macros_path)) {
  source(.bp_macros_path)
  # Pick a "purchase order" id: po_subject is the tender-notice text shared by
  # all POIs of one notice; if the parquet has a numeric PO id, prefer it.
  order_col <- intersect(c("po_id", "po_seq", "po_num", "po_subject"), names(dt))[1]
  bp_macros_emit("00_prepare_data", list(
    nPOIfull       = bp_fmt_int(nrow(dt)),
    nItemsFull     = bp_fmt_int(uniqueN(dt$item)),
    nOrdersFull    = if (!is.na(order_col)) bp_fmt_int(uniqueN(dt[[order_col]])) else "TBD",
    nPBUsObserved  = bp_fmt_int(uniqueN(dt$pbu_code))
  ))
}

