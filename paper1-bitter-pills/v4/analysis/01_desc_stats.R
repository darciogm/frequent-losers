# Descriptive Statistics Table

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

# Load data
dt <- readRDS(DATA_CACHE)

# Sample restriction: items with both litigated and ordinary
dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]
cat("Analysis sample:", nrow(dt), "obs\n")

# Winsorize 1%/99%
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

# Helper: compute stats for one variable
desc_row <- function(dt, varname, label) {
  # Split by purchase_type: 0=Ordinary, 1=Admin, 2=Litigated
  # Filter out NA and non-finite values (protects against -Inf from log(0))
  ord <- dt[purchase_type == 0 & is.finite(get(varname)), get(varname)]
  adm <- dt[purchase_type == 1 & is.finite(get(varname)), get(varname)]
  lit <- dt[purchase_type == 2 & is.finite(get(varname)), get(varname)]

  # Means and SDs
  m_ord <- mean(ord); s_ord <- sd(ord); n_ord <- length(ord)
  m_adm <- mean(adm); s_adm <- sd(adm); n_adm <- length(adm)
  m_lit <- mean(lit); s_lit <- sd(lit); n_lit <- length(lit)

  # t-tests: Ordinary vs Litigated, Admin vs Litigated
  tt_ol <- if (n_ord > 1 && n_lit > 1) t.test(ord, lit) else list(statistic = NA, p.value = NA)
  tt_al <- if (n_adm > 1 && n_lit > 1) t.test(adm, lit) else list(statistic = NA, p.value = NA)

  stars <- function(p) {
    if (is.na(p)) return("")
    if (p < 0.01) return("***")
    if (p < 0.05) return("**")
    if (p < 0.1)  return("*")
    ""
  }

  diff_ol <- m_ord - m_lit
  diff_al <- m_adm - m_lit

  list(
    label = label,
    mean_ord = m_ord, sd_ord = s_ord, n_ord = n_ord,
    mean_adm = m_adm, sd_adm = s_adm, n_adm = n_adm,
    mean_lit = m_lit, sd_lit = s_lit, n_lit = n_lit,
    diff_ol = diff_ol, t_ol = as.numeric(tt_ol$statistic),
    p_ol = tt_ol$p.value, stars_ol = stars(tt_ol$p.value),
    diff_al = diff_al, t_al = as.numeric(tt_al$statistic),
    p_al = tt_al$p.value, stars_al = stars(tt_al$p.value)
  )
}

# Build table rows
# Panel A: Levels
panel_a <- list(
  desc_row(dt[po_firm_winner == 1], "bid_price_ref", "Reference Price"),
  desc_row(dt[po_firm_winner == 1], "bid_price",     "Negotiated Price"),
  desc_row(dt[po_firm_winner == 1], "bid_qty",       "Quantity"),
  desc_row(dt,                      "n_firms_bids",  "N. Bidding Firms")
)

# Panel B: Logs
panel_b <- list(
  desc_row(dt[po_firm_winner == 1], "bid_price_ref_log", "Log Reference Price"),
  desc_row(dt[po_firm_winner == 1], "bid_price_log",     "Log Negotiated Price"),
  desc_row(dt[po_firm_winner == 1], "bid_qty_log",       "Log Quantity"),
  desc_row(dt,                      "ln_n_firms",        "Log N. Firms")
)

# Panel C: Tender Characteristics
panel_c <- list(
  desc_row(dt, "po_firm_winner", "Successful Tender (%)")
)

# Format LaTeX table
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d, big.mark = ",")
fmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

write_tex_row <- function(r, digits = 3) {
  paste0(
    "  ", r$label,
    " & ", fmt(r$mean_ord, digits), " & (", fmt(r$sd_ord, digits), ")",
    " & ", fmt(r$mean_adm, digits), " & (", fmt(r$sd_adm, digits), ")",
    " & ", fmt(r$mean_lit, digits), " & (", fmt(r$sd_lit, digits), ")",
    " & ", fmt(r$diff_ol, digits), r$stars_ol,
    " & ", fmt(r$diff_al, digits), r$stars_al,
    " \\\\"
  )
}

tex_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Descriptive Statistics by Purchase Type}",
  "\\label{tab:desc_stats}",
  "\\small",
  "\\begin{tabular}{lcccccccc}",
  "\\hline\\hline",
  " & \\multicolumn{2}{c}{Ordinary} & \\multicolumn{2}{c}{Administrative} & \\multicolumn{2}{c}{Litigated} & Diff (O-L) & Diff (A-L) \\\\",
  " & Mean & (SD) & Mean & (SD) & Mean & (SD) & & \\\\",
  "\\hline",
  "\\multicolumn{9}{l}{\\textit{Panel A: Levels}} \\\\[3pt]"
)

for (r in panel_a) tex_lines <- c(tex_lines, write_tex_row(r, 2))
tex_lines <- c(tex_lines,
  "\\\\[3pt]",
  "\\multicolumn{9}{l}{\\textit{Panel B: Log Transformations}} \\\\[3pt]"
)
for (r in panel_b) tex_lines <- c(tex_lines, write_tex_row(r, 3))
tex_lines <- c(tex_lines,
  "\\\\[3pt]",
  "\\multicolumn{9}{l}{\\textit{Panel C: Tender Characteristics}} \\\\[3pt]"
)
for (r in panel_c) tex_lines <- c(tex_lines, write_tex_row(r, 3))

# Observation counts
tex_lines <- c(tex_lines,
  "\\hline",
  paste0("  Observations & \\multicolumn{2}{c}{", fmt_int(panel_a[[1]]$n_ord), "}",
         " & \\multicolumn{2}{c}{", fmt_int(panel_a[[1]]$n_adm), "}",
         " & \\multicolumn{2}{c}{", fmt_int(panel_a[[1]]$n_lit), "}",
         " & & \\\\"),
  "\\hline\\hline",
  "\\multicolumn{9}{p{0.95\\textwidth}}{\\footnotesize Notes: Sample restricted to items with at least one ordinary and one litigated purchase. Variables winsorized at 1\\%/99\\%. Stars denote significance of Welch t-tests: *** p$<$0.01, ** p$<$0.05, * p$<$0.1.} \\\\",
  "\\end{tabular}",
  "\\end{table}"
)

tex_file <- file.path(MANU, "table_desc_stats.tex")
writeLines(tex_lines, tex_file)
cat("Saved:", tex_file, "\n")

# HTML version via modelsummary datasummary
# Build a summary data.frame for HTML output
all_rows <- c(panel_a, panel_b, panel_c)
html_df <- data.frame(
  Variable = sapply(all_rows, `[[`, "label"),
  Mean_Ordinary = sapply(all_rows, `[[`, "mean_ord"),
  SD_Ordinary = sapply(all_rows, `[[`, "sd_ord"),
  Mean_Admin = sapply(all_rows, `[[`, "mean_adm"),
  SD_Admin = sapply(all_rows, `[[`, "sd_adm"),
  Mean_Litigated = sapply(all_rows, `[[`, "mean_lit"),
  SD_Litigated = sapply(all_rows, `[[`, "sd_lit"),
  Diff_OL = sapply(all_rows, function(r) paste0(fmt(r$diff_ol, 3), r$stars_ol)),
  Diff_AL = sapply(all_rows, function(r) paste0(fmt(r$diff_al, 3), r$stars_al)),
  stringsAsFactors = FALSE
)

html_file <- file.path(RESU, "desc_stats.html")
html_content <- knitr::kable(html_df, format = "html",
                             caption = "Descriptive Statistics by Purchase Type",
                             digits = 3)
writeLines(as.character(html_content), html_file)
cat("Saved:", html_file, "\n")

# Emit macros for the manuscript layer (analysis-sample counts and per-type means)
.bp_macros_path <- file.path(.this_dir, "..", "..", "v6-jpub-short", "analysis", "_macros.R")
if (file.exists(.bp_macros_path)) {
  source(.bp_macros_path)
  ref <- panel_a[[1]]   # Reference price
  neg <- panel_a[[2]]   # Negotiated price
  qty <- panel_a[[3]]   # Quantity
  frm <- panel_a[[4]]   # N. firms (uses full dt, not winners)
  lref <- panel_b[[1]]; lneg <- panel_b[[2]]; lqty <- panel_b[[3]]

  bp_macros_emit("01_desc_stats", list(
    nAnalysisSample   = bp_fmt_int(nrow(dt)),
    nItemsAnalysis    = bp_fmt_int(uniqueN(dt$item)),
    nWinners          = bp_fmt_int(nrow(dt[po_firm_winner == 1])),
    meanRefPriceOrd   = paste0("R\\$", bp_fmt_int(round(ref$mean_ord))),
    meanRefPriceAdm   = paste0("R\\$", bp_fmt_int(round(ref$mean_adm))),
    meanRefPriceLit   = paste0("R\\$", bp_fmt_int(round(ref$mean_lit))),
    meanLogRefLit     = bp_fmt(lref$mean_lit, 2),
    meanLogNegLit     = bp_fmt(lneg$mean_lit, 2),
    meanLogRefOrd     = bp_fmt(lref$mean_ord, 2),
    meanLogNegOrd     = bp_fmt(lneg$mean_ord, 2),
    meanQtyLit        = bp_fmt_int(round(qty$mean_lit)),
    meanQtyOrd        = bp_fmt_int(round(qty$mean_ord)),
    meanFirmsLit      = bp_fmt(frm$mean_lit, 1),
    meanFirmsOrd      = bp_fmt(frm$mean_ord, 1)
  ))
}

