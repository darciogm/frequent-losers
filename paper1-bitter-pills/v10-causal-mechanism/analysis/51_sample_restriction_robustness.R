# Sample-restriction robustness for the under-the-gun contrast.
#
# Output:
#   - tab_sample_restriction_robustness.tex
#   - macros: BPsrRobustnessNrows

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
dir.create(LOGS, recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(LOGS, "51_sample_restriction_robustness.log")
writeLines(sprintf("# 51_sample_restriction_robustness | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 &
          !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]

qty_col <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if (is.na(qty_col)) stop("No quantity column found.")
d[, qty_raw := as.numeric(get(qty_col))]
d <- d[!is.na(qty_raw) & qty_raw > 0]

q_lo <- as.numeric(quantile(d$qty_raw, probs = 0.01, na.rm = TRUE, names = FALSE))
q_hi <- as.numeric(quantile(d$qty_raw, probs = 0.99, na.rm = TRUE, names = FALSE))
d[, central_qty := qty_raw >= q_lo & qty_raw <= q_hi]

item_counts <- d[, .N, by = item_id]
item_counts[, common_item := N >= 10L]
d <- merge(d, item_counts[, .(item_id, common_item)], by = "item_id", all.x = TRUE)

fit_spec <- function(data, label) {
  m <- feols(bid_price_log ~ admin | item_id + year_n + pbu_id,
             data = data,
             cluster = ~pbu_id,
             notes = FALSE,
             warn = FALSE)
  b <- unname(coef(m)["admin"])
  se <- unname(sqrt(diag(vcov(m, cluster = ~pbu_id)))["admin"])
  data.table(
    label = label,
    coef = b,
    se = se,
    pct_lit_over_admin = (exp(-b) - 1) * 100,
    n = nobs(m),
    items = uniqueN(data$item_id)
  )
}

rows <- rbindlist(list(
  fit_spec(d, "Baseline UTG sample"),
  fit_spec(d[central_qty == TRUE], "Exclude quantity tails"),
  fit_spec(d[common_item == TRUE], "Exclude rare urgent items"),
  fit_spec(d[central_qty == TRUE & common_item == TRUE],
           "Exclude quantity tails and rare items")
))
print(rows)

fmt <- function(x, digits = 3) formatC(round(x, digits), format = "f", digits = digits)
fmt_pct <- function(x) formatC(round(x, 1), format = "f", digits = 1)
fmt_int <- function(x) formatC(as.integer(x), format = "d", big.mark = ",")

tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Under-the-gun gap under sample restrictions.}\n",
  "\\label{tab:sample_restriction_robustness}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\setlength{\\tabcolsep}{3pt}\n",
  "\\begin{tabular}{p{.32\\linewidth}rrrrr}\n",
  "\\toprule\n",
  "Sample & Admin coef. & SE & Gap (\\%) & $N$ & Items \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & %s & %s & %s & %s & %s \\\\",
                rows$label,
                fmt(rows$coef),
                fmt(rows$se),
                fmt_pct(rows$pct_lit_over_admin),
                fmt_int(rows$n),
                fmt_int(rows$items)),
        collapse = "\n"),
  "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} Each row estimates the same administrative-versus-",
  "litigated urgent price specification with item, year, and PBU fixed effects. ",
  "The coefficient is administrative minus litigated log negotiated price; the ",
  "percentage column reports the implied litigated-over-administrative price ",
  "gap. ``Exclude quantity tails'' drops observations outside the central ",
  "quantity range. ``Exclude rare urgent items'' keeps items with at least ten ",
  "urgent winning observations. Standard errors are clustered by PBU.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(tex, file.path(OUT, "tables", "tab_sample_restriction_robustness.tex"))

bp_macros_emit("51_sample_restriction_robustness", list(
  srRobustnessNrows = bp_fmt_int(nrow(rows))
))
bp_log_step("done", t0, LOG)
