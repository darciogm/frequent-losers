# =============================================================================
# 02_balance_table.R — Balance Table (Admin vs Litigated, urgent subsample)
# Bitter Pills to Swallow — v4 (R/fixest)
# =============================================================================

cat("=== 02_balance_table.R ===\n")
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

# --- Load data ---------------------------------------------------------------
dt <- readRDS(DATA_CACHE)

# --- Sample: items with litigated + ordinary, urgent only --------------------
dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]
dt <- dt[purchase_type == 1 | purchase_type == 2]  # urgent only

# For UTG balance: need items with both admin and litigated in urgent subsample
dt[, has_admin2 := any(purchase_type == 1), by = item]
dt[, has_lit2   := any(purchase_type == 2), by = item]
dt <- dt[has_admin2 == TRUE & has_lit2 == TRUE]
cat("UTG balance sample:", nrow(dt), "obs\n")

# --- Winsorize 1%/99% -------------------------------------------------------
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

# --- Helper: balance row -----------------------------------------------------
balance_row <- function(dt, varname, label) {
  adm <- dt[is_admin == 1 & !is.na(get(varname)), get(varname)]
  lit <- dt[is_admin == 0 & !is.na(get(varname)), get(varname)]

  m_adm <- mean(adm); s_adm <- sd(adm); n_adm <- length(adm)
  m_lit <- mean(lit); s_lit <- sd(lit); n_lit <- length(lit)

  tt <- if (n_adm > 1 && n_lit > 1) t.test(adm, lit) else list(statistic = NA, p.value = NA)

  stars <- function(p) {
    if (is.na(p)) return("")
    if (p < 0.01) return("***")
    if (p < 0.05) return("**")
    if (p < 0.1)  return("*")
    ""
  }

  diff <- m_adm - m_lit

  list(
    label = label,
    mean_adm = m_adm, sd_adm = s_adm, n_adm = n_adm,
    mean_lit = m_lit, sd_lit = s_lit, n_lit = n_lit,
    diff = diff, t_stat = as.numeric(tt$statistic),
    p_val = tt$p.value, stars = stars(tt$p.value)
  )
}

# --- Build rows --------------------------------------------------------------
# Panel A: Procurement Outcomes
panel_a <- list(
  balance_row(dt[po_firm_winner == 1], "bid_price_ref",     "Reference Price"),
  balance_row(dt[po_firm_winner == 1], "bid_price",         "Negotiated Price"),
  balance_row(dt[po_firm_winner == 1], "bid_qty",           "Quantity"),
  balance_row(dt[po_firm_winner == 1], "bid_price_ref_log", "Log Reference Price"),
  balance_row(dt[po_firm_winner == 1], "bid_price_log",     "Log Negotiated Price"),
  balance_row(dt[po_firm_winner == 1], "bid_qty_log",       "Log Quantity")
)

# Panel B: Market Structure
panel_b <- list(
  balance_row(dt, "n_firms_bids",  "N. Bidding Firms"),
  balance_row(dt, "ln_n_firms",    "Log N. Firms"),
  balance_row(dt, "po_firm_winner", "Successful Tender (%)")
)

# Panel C: Purchase Characteristics
panel_c <- list(
  balance_row(dt, "pregao", "Electronic Auction (Pregão)")
)

# --- Format LaTeX table ------------------------------------------------------
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d, big.mark = ",")
fmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

write_bal_row <- function(r, digits = 3) {
  paste0(
    "  ", r$label,
    " & ", fmt(r$mean_adm, digits), " & (", fmt(r$sd_adm, digits), ")",
    " & ", fmt(r$mean_lit, digits), " & (", fmt(r$sd_lit, digits), ")",
    " & ", fmt(r$diff, digits), r$stars,
    " & [", fmt(r$t_stat, 2), "]",
    " \\\\"
  )
}

tex_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Balance Table: Administrative vs Litigated (Urgent Purchases)}",
  "\\label{tab:balance}",
  "\\small",
  "\\begin{tabular}{lcccccc}",
  "\\hline\\hline",
  " & \\multicolumn{2}{c}{Administrative} & \\multicolumn{2}{c}{Litigated} & Difference & t-stat \\\\",
  " & Mean & (SD) & Mean & (SD) & & \\\\",
  "\\hline",
  "\\multicolumn{7}{l}{\\textit{Panel A: Procurement Outcomes}} \\\\[3pt]"
)

for (r in panel_a) tex_lines <- c(tex_lines, write_bal_row(r, 2))
tex_lines <- c(tex_lines,
  "\\\\[3pt]",
  "\\multicolumn{7}{l}{\\textit{Panel B: Market Structure}} \\\\[3pt]"
)
for (r in panel_b) tex_lines <- c(tex_lines, write_bal_row(r, 3))
tex_lines <- c(tex_lines,
  "\\\\[3pt]",
  "\\multicolumn{7}{l}{\\textit{Panel C: Purchase Characteristics}} \\\\[3pt]"
)
for (r in panel_c) tex_lines <- c(tex_lines, write_bal_row(r, 3))

tex_lines <- c(tex_lines,
  "\\hline",
  paste0("  Observations & \\multicolumn{2}{c}{", fmt_int(panel_a[[1]]$n_adm), "}",
         " & \\multicolumn{2}{c}{", fmt_int(panel_a[[1]]$n_lit), "}",
         " & & \\\\"),
  "\\hline\\hline",
  "\\multicolumn{7}{p{0.90\\textwidth}}{\\footnotesize Notes: Sample restricted to urgent purchases (administrative and litigated) for items with both types present. Variables winsorized at 1\\%/99\\%. Stars: *** p$<$0.01, ** p$<$0.05, * p$<$0.1 (Welch t-test).} \\\\",
  "\\end{tabular}",
  "\\end{table}"
)

tex_file <- file.path(MANU, "table_balance.tex")
writeLines(tex_lines, tex_file)
cat("Saved:", tex_file, "\n")

# --- HTML version ------------------------------------------------------------
all_rows <- c(panel_a, panel_b, panel_c)
html_df <- data.frame(
  Variable = sapply(all_rows, `[[`, "label"),
  Mean_Admin = sapply(all_rows, `[[`, "mean_adm"),
  SD_Admin = sapply(all_rows, `[[`, "sd_adm"),
  Mean_Litigated = sapply(all_rows, `[[`, "mean_lit"),
  SD_Litigated = sapply(all_rows, `[[`, "sd_lit"),
  Difference = sapply(all_rows, function(r) paste0(fmt(r$diff, 3), r$stars)),
  t_stat = sapply(all_rows, function(r) fmt(r$t_stat, 2)),
  stringsAsFactors = FALSE
)

html_file <- file.path(RESU, "balance_table.html")
html_content <- knitr::kable(html_df, format = "html",
                             caption = "Balance Table: Administrative vs Litigated",
                             digits = 3)
writeLines(as.character(html_content), html_file)
cat("Saved:", html_file, "\n")

cat("=== 02_balance_table.R complete ===\n")
