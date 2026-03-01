# ============================================================================
# 03_tables.R — Publication-ready LaTeX tables (threeparttable + booktabs)
# ============================================================================

cat("=== 03_tables.R: Table generation ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load models and data --------------------------------------------------
models_path <- "/tmp/p2_models.rds"
if (!file.exists(models_path)) stop("Run 02_analysis.R first")
models <- readRDS(models_path)

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

# ---- Helper: write a 6-column DiDiR regression table -----------------------

write_didir_table <- function(mlist, caption, label, dv_label,
                              coef_names, coef_labels, d = 4,
                              filename) {
  # mlist: named list of 6 models in order:
  #   6m_base, 6m_pbu, 12m_base, 12m_pbu, 18m_base, 18m_pbu

  m_order <- c("6m_base", "6m_pbu", "12m_base", "12m_pbu", "18m_base", "18m_pbu")
  ms <- mlist[m_order]

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    sprintf("\\caption{%s}", caption),
    sprintf("\\label{%s}", label),
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccccc}",
    "\\toprule",
    " & (1) & (2) & (3) & (4) & (5) & (6) \\\\",
    " & 6-month & 6-month & 12-month & 12-month & 18-month & 18-month \\\\"
  )

  lines <- c(lines, "\\midrule")

  # Coefficient rows
  for (i in seq_along(coef_names)) {
    var  <- coef_names[i]
    lbl  <- coef_labels[i]

    # Coefficient row
    vals <- sapply(ms, function(m) coef_cell(m, var, d))
    lines <- c(lines, sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")))

    # Standard error row
    ses <- sapply(ms, function(m) se_cell(m, var, d))
    lines <- c(lines, sprintf(" & %s \\\\", paste(ses, collapse = " & ")))
  }

  # Separator before summary stats
  lines <- c(lines, "\\midrule")

  # Observations
  obs <- sapply(ms, function(m) pfmt_int(m$nobs))
  lines <- c(lines, sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")))

  # R-squared (within R², matches Stata areg output)
  r2 <- sapply(ms, function(m) pfmt(fitstat(m, "wr2")[[1]], 4))
  lines <- c(lines, sprintf("R-squared & %s \\\\", paste(r2, collapse = " & ")))

  # FE indicators
  lines <- c(lines, "Item Fixed Effects & YES & YES & YES & YES & YES & YES \\\\")
  lines <- c(lines, "Controlling for PBU & NO & YES & NO & YES & NO & YES \\\\")

  lines <- c(lines,
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} Standard errors clustered at the item level in parentheses.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "Constant absorbed by fixed effects.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  filepath <- file.path(OUT_TAB, filename)
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# ---- Table 1: Descriptive statistics ---------------------------------------

write_desc_stats <- function(dt) {
  cat("  Generating descriptive statistics table...\n")

  # Use 18-month window
  d <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]

  # Variables to summarize
  vars <- list(
    list(name = "preco_final", label = "Price (levels)", filter = "completed"),
    list(name = "lpreco_final", label = "Log price", filter = "completed"),
    list(name = "num_firms", label = "Number of firms", filter = "all"),
    list(name = "lnum_firms", label = "Log number of firms", filter = "all"),
    list(name = "num_bids", label = "Number of valid bids", filter = "all"),
    list(name = "lnum_bids", label = "Log number of valid bids", filter = "all"),
    list(name = "dist1", label = "Distance (km)", filter = "completed")
  )

  # 4 groups: G65-Pre, G65-Post, Others-Pre, Others-Post
  groups <- list(
    list(label = "Group 65, Pre",  cond = quote(g65 == 1 & Pre == 1)),
    list(label = "Group 65, Post", cond = quote(g65 == 1 & Pre == 0)),
    list(label = "Others, Pre",    cond = quote(g65 == 0 & Pre == 1)),
    list(label = "Others, Post",   cond = quote(g65 == 0 & Pre == 0))
  )

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Descriptive Statistics (18-month window)}",
    "\\label{tab:descstats}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccccccc}",
    "\\toprule",
    " & \\multicolumn{2}{c}{Group 65, Pre} & \\multicolumn{2}{c}{Group 65, Post} & \\multicolumn{2}{c}{Others, Pre} & \\multicolumn{2}{c}{Others, Post} \\\\",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7} \\cmidrule(lr){8-9}",
    " & Mean & SD & Mean & SD & Mean & SD & Mean & SD \\\\"
  )

  lines <- c(lines, "\\midrule")

  for (v in vars) {
    vals <- character(8)
    idx <- 1
    for (grp in groups) {
      sub <- d[eval(grp$cond)]
      if (v$filter == "completed") sub <- sub[completed == TRUE]
      x <- sub[[v$name]]
      x <- x[!is.na(x)]
      vals[idx]     <- pfmt(mean(x), 2)
      vals[idx + 1] <- pfmt(sd(x), 2)
      idx <- idx + 2
    }
    lines <- c(lines, sprintf("%s & %s \\\\", v$label, paste(vals, collapse = " & ")))
  }

  # Observation counts
  lines <- c(lines, "\\midrule")

  obs_row <- character(8)
  idx <- 1
  for (grp in groups) {
    sub <- d[eval(grp$cond)]
    n_comp <- sub[completed == TRUE & !is.na(lpreco_final), .N]
    n_all  <- sub[!is.na(lnum_firms), .N]
    obs_row[idx]     <- pfmt_int(n_comp)
    obs_row[idx + 1] <- pfmt_int(n_all)
    idx <- idx + 2
  }
  lines <- c(lines, sprintf("N (completed / all) & %s \\\\", paste(obs_row, collapse = " & ")))

  lines <- c(lines,
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} Price and distance statistics computed on completed items (status = 1).",
    "Firm and bid statistics computed on all items.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  filepath <- file.path(OUT_TAB, "tab_desc_stats.tex")
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# ---- Generate all tables ---------------------------------------------------

# Table: Descriptive statistics
write_desc_stats(dt)

# Table 2: Prices (log)
write_didir_table(
  mlist       = models$prices,
  caption     = "Prices (log): Pre-switch-period effect on group 65",
  label       = "tab:prices",
  dv_label    = "Log price",
  coef_names  = c("g65_pre", "convite", "lquantidade"),
  coef_labels = c("$g65 \\times Pre$", "Sealed bids", "lquantity"),
  d           = 4,
  filename    = "tab_prices.tex"
)

# Table 3: Number of participant firms (log)
write_didir_table(
  mlist       = models$participants,
  caption     = "Number of Participant Firms (log): Pre-switch-period effect on group 65",
  label       = "tab:participants",
  dv_label    = "Log firms",
  coef_names  = c("g65_pre", "convite", "lquantidade"),
  coef_labels = c("$g65 \\times Pre$", "sealed-bids", "lquantity"),
  d           = 4,
  filename    = "tab_participants.tex"
)

# Table 4: Number of valid bids (log)
write_didir_table(
  mlist       = models$validbids,
  caption     = "Number of Valid Bids (log): Pre-switch-period effect on group 65",
  label       = "tab:validbids",
  dv_label    = "Log bids",
  coef_names  = c("g65_pre", "convite", "lquantidade"),
  coef_labels = c("$g65 \\times Pre$", "sealed-bids", "lquantity"),
  d           = 4,
  filename    = "tab_validbids.tex"
)

# Table 5: Distance
write_didir_table(
  mlist       = models$distance,
  caption     = "Distance from PBUs to winner firms: Pre-switch-period effect on group 65",
  label       = "tab:distance",
  dv_label    = "Distance (km)",
  coef_names  = c("g65_pre", "convite", "lquantidade"),
  coef_labels = c("$g65 \\times Pre$", "convite", "lquantidade"),
  d           = 4,
  filename    = "tab_distance.tex"
)

cat("  All tables generated.\n")
