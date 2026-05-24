# Alternative quantity-control definitions for the under-the-gun contrast.
#
# Output:
#   - tab_quantity_definition_robustness.tex
#   - macros: BPqtyRobustnessNrows

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
LOG <- file.path(LOGS, "53_quantity_definition_robustness.log")
writeLines(sprintf("# 53_quantity_definition_robustness | start=%s", Sys.time()), LOG)

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
d[, qty_log := log(qty_raw)]
d[, qty_raw_k := qty_raw / 1000]
d[, qty_item_pct := {
  n <- .N
  if (n <= 1L) rep(0.5, n) else (frank(qty_raw, ties.method = "average") - 0.5) / n
}, by = item_id]

fit_spec <- function(rhs, label) {
  fml <- as.formula(sprintf("bid_price_log ~ %s | item_id + year_n + pbu_id", rhs))
  m <- feols(fml, data = d, cluster = ~pbu_id, notes = FALSE, warn = FALSE)
  b <- unname(coef(m)["admin"])
  se <- unname(sqrt(diag(vcov(m, cluster = ~pbu_id)))["admin"])
  data.table(
    label = label,
    coef = b,
    se = se,
    pct_lit_over_admin = (exp(-b) - 1) * 100,
    n = nobs(m)
  )
}

rows <- rbindlist(list(
  fit_spec("admin", "No quantity control"),
  fit_spec("admin + qty_log", "Log accepted quantity"),
  fit_spec("admin + qty_raw_k", "Raw accepted quantity / 1,000"),
  fit_spec("admin + qty_item_pct", "Within-item quantity percentile")
))
print(rows)

fmt <- function(x, digits = 3) formatC(round(x, digits), format = "f", digits = digits)
fmt_pct <- function(x) formatC(round(x, 1), format = "f", digits = 1)
fmt_int <- function(x) formatC(as.integer(x), format = "d", big.mark = ",")

tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Under-the-gun gap under alternative quantity controls.}\n",
  "\\label{tab:quantity_definition_robustness}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\setlength{\\tabcolsep}{5pt}\n",
  "\\begin{tabular}{p{.42\\linewidth}rrrr}\n",
  "\\toprule\n",
  "Quantity control & Admin coef. & SE & Gap (\\%) & $N$ \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & %s & %s & %s & %s \\\\",
                rows$label,
                fmt(rows$coef),
                fmt(rows$se),
                fmt_pct(rows$pct_lit_over_admin),
                fmt_int(rows$n)),
        collapse = "\n"),
  "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} Each row estimates the administrative-versus-",
  "litigated urgent price specification with item, year, and PBU fixed effects. ",
  "The coefficient is administrative minus litigated log negotiated price; the ",
  "percentage column reports the implied litigated-over-administrative price ",
  "gap. Quantity controls are included as listed. The BEC data used here do ",
  "not contain a common dose-standardized quantity field, so the table varies ",
  "the observed accepted-quantity transformation instead. Standard errors are ",
  "clustered by PBU.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(tex, file.path(OUT, "tables", "tab_quantity_definition_robustness.tex"))

bp_macros_emit("53_quantity_definition_robustness", list(
  qtyRobustnessNrows = bp_fmt_int(nrow(rows))
))
bp_log_step("done", t0, LOG)
