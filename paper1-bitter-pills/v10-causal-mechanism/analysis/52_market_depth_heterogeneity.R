# Market-depth and formulary heterogeneity for the under-the-gun contrast.
#
# Output:
#   - tab_market_depth_heterogeneity.tex
#   - macros: BPmdHetNrows

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
LOG <- file.path(LOGS, "52_market_depth_heterogeneity.log")
writeLines(sprintf("# 52_market_depth_heterogeneity | start=%s", Sys.time()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 &
          !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]

sus_col <- intersect(c("sus_basic", "sus_formulary", "is_formulary",
                       "formulary", "has_sus", "in_sus"), names(d))[1]
if (is.na(sus_col)) stop("No SUS/formulary column found.")
d[, sus_flag := as.integer(get(sus_col) > 0)]

depth_col <- intersect(c("high_competition", "high_liquidity", "liquid_market"),
                       names(d))[1]
if (is.na(depth_col)) {
  if ("n_firms_bids" %in% names(d)) {
    med_firms <- median(d$n_firms_bids, na.rm = TRUE)
    d[, high_depth := as.integer(n_firms_bids >= med_firms)]
  } else {
    stop("No market-depth proxy found.")
  }
} else {
  d[, high_depth := as.integer(get(depth_col) > 0)]
}

fit_spec <- function(data, label) {
  if (nrow(data) < 500L || uniqueN(data$admin) < 2L) return(NULL)
  m <- tryCatch(
    feols(bid_price_log ~ admin | item_id + year_n + pbu_id,
          data = data,
          cluster = ~pbu_id,
          notes = FALSE,
          warn = FALSE),
    error = function(e) NULL
  )
  if (is.null(m) || !"admin" %in% names(coef(m))) return(NULL)
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

rows <- rbindlist(Filter(Negate(is.null), list(
  fit_spec(d[sus_flag == 1L], "SUS-formulary items"),
  fit_spec(d[sus_flag == 0L], "Non-formulary items"),
  fit_spec(d[high_depth == 1L], "High-depth markets"),
  fit_spec(d[high_depth == 0L], "Low-depth markets")
)))
print(rows)

fmt <- function(x, digits = 3) formatC(round(x, digits), format = "f", digits = digits)
fmt_pct <- function(x) formatC(round(x, 1), format = "f", digits = 1)
fmt_int <- function(x) formatC(as.integer(x), format = "d", big.mark = ",")

tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Under-the-gun gap by formulary status and market depth.}\n",
  "\\label{tab:market_depth_heterogeneity}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\setlength{\\tabcolsep}{4pt}\n",
  "\\begin{tabular}{p{.32\\linewidth}rrrrr}\n",
  "\\toprule\n",
  "Subsample & Admin coef. & SE & Gap (\\%) & $N$ & Items \\\\\n",
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
  "\\item \\textit{Notes:} Each row estimates the administrative-versus-",
  "litigated urgent price specification with item, year, and PBU fixed effects ",
  "within the listed subsample. The coefficient is administrative minus ",
  "litigated log negotiated price; the percentage column reports the implied ",
  "litigated-over-administrative price gap. Market depth uses the generated ",
  "high-competition indicator when available, and otherwise splits observations ",
  "by the median number of bidding firms. Standard errors are clustered by PBU.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(tex, file.path(OUT, "tables", "tab_market_depth_heterogeneity.tex"))

bp_macros_emit("52_market_depth_heterogeneity", list(
  mdHetNrows = bp_fmt_int(nrow(rows))
))
bp_log_step("done", t0, LOG)
