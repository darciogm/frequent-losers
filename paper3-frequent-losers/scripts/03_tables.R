# ============================================================================
# 03_tables.R — Publication-ready LaTeX tables (threeparttable + booktabs)
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================

cat("=== 03_tables.R: Table generation ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load models and data --------------------------------------------------
models_path <- "/tmp/p3_models.rds"
if (!file.exists(models_path)) stop("Run 02_analysis.R first")
models <- readRDS(models_path)

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

# ============================================================================
# Helper: write a 4-column regression table (matches manuscript Tables 2-4)
# ============================================================================

write_losers_table <- function(mlist, caption, label, dv_label,
                               coef_names, coef_labels, d = 4,
                               filename) {
  # mlist: named list of 4 models: general, general_pbu, pregao, convite
  m_order <- c("general", "general_pbu", "pregao", "convite")
  ms <- mlist[m_order]

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    sprintf("\\caption{%s}", caption),
    sprintf("\\label{%s}", label),
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & (1) & (2) & (3) & (4) \\\\",
    " & General & General & Preg\\~{a}o & Convite \\\\"
  )

  lines <- c(lines, "\\midrule")

  # Coefficient rows
  for (i in seq_along(coef_names)) {
    var <- coef_names[i]
    lbl <- coef_labels[i]

    # Some covariates only appear in cols 1-2 (general specs)
    vals <- sapply(seq_along(ms), function(j) {
      m <- ms[[j]]
      if (var %in% names(coef(m))) coef_cell(m, var, d) else ""
    })
    lines <- c(lines, sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")))

    ses <- sapply(seq_along(ms), function(j) {
      m <- ms[[j]]
      if (var %in% names(coef(m))) se_cell(m, var, d) else ""
    })
    lines <- c(lines, sprintf(" & %s \\\\", paste(ses, collapse = " & ")))
  }

  # Separator before summary stats
  lines <- c(lines, "\\midrule")

  # Observations
  obs <- sapply(ms, function(m) pfmt_int(m$nobs))
  lines <- c(lines, sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")))

  # R-squared (overall, approximates Stata areg)
  r2 <- sapply(ms, function(m) pfmt(fitstat(m, "r2")[[1]], 4))
  lines <- c(lines, sprintf("R-squared & %s \\\\", paste(r2, collapse = " & ")))

  # FE indicators
  lines <- c(lines, "Item Dummies & YES & YES & YES & YES \\\\")
  lines <- c(lines, "Year Dummies & YES & YES & YES & YES \\\\")
  lines <- c(lines, "PBU Dummies & NO & YES & YES & YES \\\\")

  lines <- c(lines,
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} Standard errors clustered at the item level in parentheses.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "Columns (3) and (4) restrict the sample to preg\\~{a}o and convite procedures, respectively.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  filepath <- file.path(OUT_TAB, filename)
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# ============================================================================
# Table 1: Descriptive statistics
# ============================================================================

write_desc_stats <- function(dt) {
  cat("  Generating descriptive statistics table...\n")

  vars <- list(
    list(name = "bid_unit_price_negot_min", label = "Negotiated price",
         filter = "price", fmt = 2),
    list(name = "lneg_price", label = "Log negotiated price",
         filter = "price", fmt = 2),
    list(name = "n_firms", label = "Number of firms",
         filter = "all", fmt = 2),
    list(name = "ln_firms", label = "Log number of firms",
         filter = "all", fmt = 2),
    list(name = "n_bids", label = "Number of bids",
         filter = "all", fmt = 2),
    list(name = "ln_bids", label = "Log number of bids",
         filter = "all", fmt = 2)
  )

  # Two groups: with vs. without frequent losers
  groups <- list(
    list(label = "With Frequent Losers",  cond = quote(losers == 1)),
    list(label = "Without Frequent Losers", cond = quote(losers == 0))
  )

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Descriptive Statistics: With vs. Without Frequent Losers}",
    "\\label{tab:descstats}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccccc}",
    "\\toprule",
    " & \\multicolumn{3}{c}{With Frequent Losers} & \\multicolumn{3}{c}{Without Frequent Losers} \\\\",
    "\\cmidrule(lr){2-4} \\cmidrule(lr){5-7}",
    " & Mean & SD & N & Mean & SD & N \\\\"
  )

  lines <- c(lines, "\\midrule")

  for (v in vars) {
    vals <- character(6)
    idx <- 1
    for (grp in groups) {
      sub <- dt[eval(grp$cond)]
      if (v$filter == "price") sub <- sub[!is.na(lneg_price)]
      x <- sub[[v$name]]
      x <- x[!is.na(x)]
      vals[idx]     <- pfmt(mean(x), v$fmt)
      vals[idx + 1] <- pfmt(sd(x), v$fmt)
      vals[idx + 2] <- pfmt_int(length(x))
      idx <- idx + 3
    }
    lines <- c(lines, sprintf("%s & %s \\\\", v$label, paste(vals, collapse = " & ")))
  }

  lines <- c(lines,
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} Sample restricted to item types with at least one tender",
    "involving a frequent loser. Price statistics computed on completed tenders only.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  filepath <- file.path(OUT_TAB, "tab_desc_stats.tex")
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# ============================================================================
# Generate all tables
# ============================================================================

# Table 1: Descriptive statistics
write_desc_stats(dt)

# Table 2: Prices (log negotiated price)
write_losers_table(
  mlist       = models$prices,
  caption     = "Negotiated Prices (log): With vs.\\ Without Frequent Losers",
  label       = "tab:prices",
  dv_label    = "Log negotiated price",
  coef_names  = c("losers", "convite"),
  coef_labels = c("losers", "convite"),
  d           = 4,
  filename    = "tab_prices.tex"
)

# Table 3: Number of firms (log)
write_losers_table(
  mlist       = models$nfirms,
  caption     = "Number of Firms (log): With vs.\\ Without Frequent Losers",
  label       = "tab:nfirms",
  dv_label    = "Log number of firms",
  coef_names  = c("losers", "convite"),
  coef_labels = c("losers", "convite"),
  d           = 4,
  filename    = "tab_nfirms.tex"
)

# Table 4: Number of bids (log)
write_losers_table(
  mlist       = models$nbids,
  caption     = "Number of Bids (log): With vs.\\ Without Frequent Losers",
  label       = "tab:nbids",
  dv_label    = "Log number of bids",
  coef_names  = c("losers", "convite"),
  coef_labels = c("losers", "convite"),
  d           = 4,
  filename    = "tab_nbids.tex"
)

# Table 5: Number of non-FL firms (mechanical test)
write_losers_table(
  mlist       = models$nfirms_excl,
  caption     = "Number of Non-FL Firms (log): Mechanical Relationship Test",
  label       = "tab:nfirms_excl",
  dv_label    = "Log number of non-FL firms",
  coef_names  = c("losers", "convite"),
  coef_labels = c("losers", "convite"),
  d           = 4,
  filename    = "tab_nfirms_excl.tex"
)

cat("  All tables generated.\n")
