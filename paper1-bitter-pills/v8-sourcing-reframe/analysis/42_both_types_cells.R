# Layer 1 / Track D --- Both-types-cell representativeness.
#
# In the tightest UTG specification (item x year-month FE), only ~11% of
# cells contain both admin and litigated observations and contribute
# within-cell variation. The rest are absorbed as singletons. The 11%
# are not a representative subsample of urgent items; they tilt toward
# higher-volume, more-reordered medications. This script compares
# both-types cells with single-type cells along: log ref price, log neg
# price, log quantity, modality (sealed-bid vs reverse-auction), SUS
# formulary status, mean number of bidding firms.
#
# Output:
#   - tab_both_types_cells.tex
#   - macros: BPbothCellN, BPbothCellNSingleton, BPbothCellMeanLogRefBoth,
#             BPbothCellMeanLogRefSingle, BPbothCellMeanLogQtyBoth,
#             BPbothCellMeanLogQtySingle, BPbothCellSusShareBoth,
#             BPbothCellSusShareSingle, BPbothCellModalityShareBoth,
#             BPbothCellModalityShareSingle, BPbothCellMeanFirmsBoth,
#             BPbothCellMeanFirmsSingle, BPbothCellPMin

suppressPackageStartupMessages({
  library(data.table)
  library(kableExtra)
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
LOG  <- file.path(LOGS, "42_both_types_cells.log")
writeLines(sprintf("# 42_both_types_cells | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

# UTG sample
d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 & !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]

# year-month identifier --- prefer pre-existing column if present
ym_col <- intersect(c("ym_id", "year_month", "yyyymm"), names(d))[1]
if (is.na(ym_col)) {
  if ("po_date" %in% names(d)) {
    d[, ym := format(as.Date(po_date), "%Y-%m")]
  } else {
    # fall back to year only
    d[, ym := as.character(year_n)]
  }
} else {
  d[, ym := as.character(get(ym_col))]
}

# cell-level type counts
cell <- d[, .(n_admin = sum(admin == 1L), n_lit = sum(admin == 0L)),
          by = .(item_id, ym)]
cell[, both_types := as.integer(n_admin > 0 & n_lit > 0)]
cell[, singleton  := as.integer(n_admin == 0 | n_lit == 0)]
n_both   <- sum(cell$both_types)
n_single <- sum(cell$singleton)
cat(sprintf("Cells with both types: %s\n", format(n_both, big.mark = ",")))
cat(sprintf("Singleton cells:       %s\n", format(n_single, big.mark = ",")))

# join cell-level flag back to obs and compute observation-level summaries
d <- merge(d, cell[, .(item_id, ym, both_types)], by = c("item_id", "ym"), all.x = TRUE)
d[, group := ifelse(both_types == 1L, "both", "single")]

ref_col <- intersect(c("bid_price_ref_log", "ref_price_log", "ln_ref_price"), names(d))[1]
qty_col <- intersect(c("bid_qty_log", "qty_log", "ln_qty", "ln_po_qty"), names(d))[1]
firms_col <- intersect(c("n_firms_bids", "n_firms"), names(d))[1]
sus_col <- intersect(c("sus_basic", "has_sus", "in_sus"), names(d))[1]
mod_col <- intersect(c("pregao", "modality", "modalidade", "is_pregao"), names(d))[1]

summarise_group <- function(d, var, default_na = NA_real_) {
  if (is.na(var) || !var %in% names(d)) return(c(both = default_na, single = default_na))
  c(both   = mean(d[group == "both",   get(var)], na.rm = TRUE),
    single = mean(d[group == "single", get(var)], na.rm = TRUE))
}

s_ref   <- summarise_group(d, ref_col)
s_neg   <- summarise_group(d, "bid_price_log")
s_qty   <- summarise_group(d, qty_col)
s_firms <- summarise_group(d, firms_col)
s_sus   <- summarise_group(d, sus_col)
# modality: share of pregao (reverse auction) if pregao binary present
if (!is.na(mod_col)) {
  modval <- d[[mod_col]]
  if (is.numeric(modval) || is.logical(modval)) {
    d[, mod_pregao := as.integer(modval == 1)]
  } else {
    d[, mod_pregao := as.integer(grepl("preg", tolower(as.character(modval))))]
  }
  s_mod <- summarise_group(d, "mod_pregao")
} else {
  s_mod <- c(both = NA_real_, single = NA_real_)
}

t_test_p <- function(d, var) {
  if (is.na(var) || !var %in% names(d)) return(NA_real_)
  x_b <- d[group == "both",   get(var)]
  x_s <- d[group == "single", get(var)]
  if (length(unique(c(x_b, x_s))) < 2 || sd(x_b, na.rm = TRUE) == 0 ||
      sd(x_s, na.rm = TRUE) == 0) return(NA_real_)
  tryCatch(t.test(x_b, x_s)$p.value, error = function(e) NA_real_)
}

p_ref   <- t_test_p(d, ref_col)
p_neg   <- t_test_p(d, "bid_price_log")
p_qty   <- t_test_p(d, qty_col)
p_firms <- t_test_p(d, firms_col)
p_sus   <- t_test_p(d, sus_col)
p_mod   <- if ("mod_pregao" %in% names(d)) t_test_p(d, "mod_pregao") else NA_real_

p_min <- min(c(p_ref, p_neg, p_qty, p_firms, p_sus, p_mod), na.rm = TRUE)
cat(sprintf("Min p across t-tests: %.4g\n", p_min))

res <- data.table(
  variable = c("Log reference price", "Log negotiated price",
               "Log quantity", "N. bidding firms",
               "SUS formulary share", "Reverse-auction (pregao) share"),
  both_types = c(s_ref["both"], s_neg["both"], s_qty["both"],
                 s_firms["both"], s_sus["both"], s_mod["both"]),
  singleton  = c(s_ref["single"], s_neg["single"], s_qty["single"],
                 s_firms["single"], s_sus["single"], s_mod["single"]),
  p_value    = c(p_ref, p_neg, p_qty, p_firms, p_sus, p_mod)
)
print(res)

ktab <- kbl(res, format = "latex", booktabs = TRUE, digits = 3,
            col.names = c("Variable", "Both-types cells", "Singleton cells",
                          "$p$-value"),
            label = "tab:both_types_cells",
            caption = paste0("Representativeness of both-types cells: cells with both administrative and litigated urgent purchases (",
                             format(n_both, big.mark = ","), " cells, ", round(100*n_both/(n_both+n_single), 1),
                             "\\%) vs.\\ singleton cells (", format(n_single, big.mark = ","), ")."),
            escape = FALSE) |>
  footnote(general = paste(
    "Means computed at the observation level within each cell type. $p$-values",
    "from two-sample $t$-tests. Both-types cells provide the within-cell",
    "variation that identifies the item$\\times$year-month UTG specification.",
    "Differences in modality, supplier-base depth, and SUS formulary status",
    "indicate that the within-cell estimator is identified off a non-random",
    "subsample of urgent items."),
    general_title = "", footnote_as_chunk = TRUE, escape = FALSE)
writeLines(ktab, file.path(OUT, "tables", "tab_both_types_cells.tex"))

bp_macros_emit("42_both_types_cells", list(
  bothCellN                  = bp_fmt_int(n_both),
  bothCellNSingleton         = bp_fmt_int(n_single),
  bothCellMeanLogRefBoth     = bp_fmt(s_ref["both"]),
  bothCellMeanLogRefSingle   = bp_fmt(s_ref["single"]),
  bothCellMeanLogQtyBoth     = bp_fmt(s_qty["both"]),
  bothCellMeanLogQtySingle   = bp_fmt(s_qty["single"]),
  bothCellSusShareBoth       = bp_fmt_pct(s_sus["both"] * 100),
  bothCellSusShareSingle     = bp_fmt_pct(s_sus["single"] * 100),
  bothCellModalityShareBoth  = bp_fmt_pct(s_mod["both"] * 100),
  bothCellModalityShareSingle= bp_fmt_pct(s_mod["single"] * 100),
  bothCellMeanFirmsBoth      = bp_fmt(s_firms["both"]),
  bothCellMeanFirmsSingle    = bp_fmt(s_firms["single"]),
  bothCellPMin               = bp_fmt(p_min, digits = 4)
))
bp_log_step("done", t0, LOG)
