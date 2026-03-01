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

# ============================================================================
# NEW TABLES — Robustness and Extensions
# ============================================================================

# ---- Load robustness and extension models (if available) -------------------
rob_path <- "/tmp/p2_robustness.rds"
ext_path <- "/tmp/p2_extensions.rds"

has_rob <- file.exists(rob_path)
has_ext <- file.exists(ext_path)

if (has_rob) {
  rob <- readRDS(rob_path)
  cat("  Loaded robustness models\n")
}
if (has_ext) {
  ext <- readRDS(ext_path)
  cat("  Loaded extension models\n")
}

# ---- Table: Placebo Tests --------------------------------------------------
if (has_rob && !is.null(rob$placebo1_prices)) {
  cat("  Generating placebo table...\n")

  dvs_p <- list(
    list(label = "Log prices",    p1 = "placebo1_prices",   p2 = "placebo2_prices"),
    list(label = "Log firms",     p1 = "placebo1_firms",    p2 = "placebo2_firms"),
    list(label = "Log bids",      p1 = "placebo1_bids",     p2 = "placebo2_bids"),
    list(label = "Distance (km)", p1 = "placebo1_distance", p2 = "placebo2_distance")
  )

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Placebo Tests: Fake Treatment Dates}",
    "\\label{tab:placebo}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccccccc}",
    "\\toprule",
    " & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Log firms} & \\multicolumn{2}{c}{Log bids} & \\multicolumn{2}{c}{Distance} \\\\",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7} \\cmidrule(lr){8-9}",
    " & Sep 2017 & Mar 2017 & Sep 2017 & Mar 2017 & Sep 2017 & Mar 2017 & Sep 2017 & Mar 2017 \\\\",
    "\\midrule"
  )

  # Coefficient row
  vals <- character(8)
  ses  <- character(8)
  obs  <- character(8)
  r2v  <- character(8)
  idx <- 1
  for (v in dvs_p) {
    m1 <- rob[[v$p1]]
    m2 <- rob[[v$p2]]
    vals[idx]     <- coef_cell(m1, "g65_pre_placebo", 4)
    vals[idx + 1] <- coef_cell(m2, "g65_pre_placebo", 4)
    ses[idx]      <- se_cell(m1, "g65_pre_placebo", 4)
    ses[idx + 1]  <- se_cell(m2, "g65_pre_placebo", 4)
    obs[idx]      <- pfmt_int(m1$nobs)
    obs[idx + 1]  <- pfmt_int(m2$nobs)
    r2v[idx]      <- pfmt(fitstat(m1, "wr2")[[1]], 4)
    r2v[idx + 1]  <- pfmt(fitstat(m2, "wr2")[[1]], 4)
    idx <- idx + 2
  }

  lines <- c(lines,
    sprintf("$g65 \\times Pre_{placebo}$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    sprintf("R-squared & %s \\\\", paste(r2v, collapse = " & ")),
    "Item FE & YES & YES & YES & YES & YES & YES & YES & YES \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} Placebo tests using fake treatment dates (Sep 2017 and Mar 2017) on pre-treatment data only.",
    "Standard errors clustered at the item level in parentheses.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(lines, file.path(OUT_TAB, "tab_placebo.tex"))
  cat("  Saved: tab_placebo.tex\n")
}

# ---- Table: Alternative Clustering -----------------------------------------
if (has_rob && !is.null(rob$altcl_prices_grupo)) {
  cat("  Generating alternative clustering table...\n")

  dvs_cl <- list(
    list(label = "Log prices",    prefix = "prices"),
    list(label = "Log firms",     prefix = "firms"),
    list(label = "Log bids",      prefix = "bids"),
    list(label = "Distance (km)", prefix = "distance")
  )
  cl_labels <- c("grupo" = "Group", "pbu" = "PBU", "twoway" = "Two-way")

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Alternative Clustering (18-month window, base specification)}",
    "\\label{tab:altcluster}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & Log prices & Log firms & Log bids & Distance \\\\",
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel A: Cluster by item group}} \\\\"
  )

  # Panel A: cluster by grupo
  vals <- sapply(dvs_cl, function(v) coef_cell(rob[[paste0("altcl_", v$prefix, "_grupo")]], "g65_pre", 4))
  ses  <- sapply(dvs_cl, function(v) se_cell(rob[[paste0("altcl_", v$prefix, "_grupo")]], "g65_pre", 4))
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel B: Cluster by PBU}} \\\\"
  )

  # Panel B: cluster by PBU
  vals <- sapply(dvs_cl, function(v) coef_cell(rob[[paste0("altcl_", v$prefix, "_pbu")]], "g65_pre", 4))
  ses  <- sapply(dvs_cl, function(v) se_cell(rob[[paste0("altcl_", v$prefix, "_pbu")]], "g65_pre", 4))
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel C: Two-way clustering (item $\\times$ PBU)}} \\\\"
  )

  # Panel C: two-way
  vals <- sapply(dvs_cl, function(v) coef_cell(rob[[paste0("altcl_", v$prefix, "_twoway")]], "g65_pre", 4))
  ses  <- sapply(dvs_cl, function(v) se_cell(rob[[paste0("altcl_", v$prefix, "_twoway")]], "g65_pre", 4))
  obs  <- sapply(dvs_cl, function(v) pfmt_int(rob[[paste0("altcl_", v$prefix, "_twoway")]]$nobs))
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} 18-month window, base specification (item FE only).",
    "Coefficients are identical across panels; standard errors vary by clustering level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(lines, file.path(OUT_TAB, "tab_altcluster.tex"))
  cat("  Saved: tab_altcluster.tex\n")
}

# ---- Table: Winsorization Robustness ---------------------------------------
if (has_rob && !is.null(rob$win_prices_w01_base)) {
  cat("  Generating winsorization table...\n")

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Winsorized Regressions (18-month window)}",
    "\\label{tab:winsorize}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Distance} \\\\",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
    " & Base & +PBU FE & Base & +PBU FE \\\\",
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel A: 1st/99th percentile winsorization}} \\\\"
  )

  # Panel A: 1%/99%
  ms_a <- list(rob$win_prices_w01_base, rob$win_prices_w01_pbu,
               rob$win_dist_w01_base, rob$win_dist_w01_pbu)
  vals <- sapply(ms_a, function(m) coef_cell(m, "g65_pre", 4))
  ses  <- sapply(ms_a, function(m) se_cell(m, "g65_pre", 4))
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel B: 5th/95th percentile winsorization}} \\\\"
  )

  # Panel B: 5%/95%
  ms_b <- list(rob$win_prices_w05_base, rob$win_prices_w05_pbu,
               rob$win_dist_w05_base, rob$win_dist_w05_pbu)
  vals <- sapply(ms_b, function(m) coef_cell(m, "g65_pre", 4))
  ses  <- sapply(ms_b, function(m) se_cell(m, "g65_pre", 4))
  obs  <- sapply(ms_b, function(m) pfmt_int(m$nobs))
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & ")),
    "\\midrule",
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    "Item FE & YES & YES & YES & YES \\\\",
    "PBU FE & NO & YES & NO & YES \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} 18-month window. Dependent variables winsorized at indicated percentiles.",
    "Standard errors clustered at the item level in parentheses.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(lines, file.path(OUT_TAB, "tab_winsorize.tex"))
  cat("  Saved: tab_winsorize.tex\n")
}

# ---- Table: Real Prices (IPCA-deflated) ------------------------------------
if (has_ext && !is.null(ext$prices_real)) {
  cat("  Generating real prices table...\n")
  write_didir_table(
    mlist       = ext$prices_real,
    caption     = "Real Prices (IPCA-deflated, log): Pre-switch-period effect on group 65",
    label       = "tab:prices_real",
    dv_label    = "Log real price",
    coef_names  = c("g65_pre", "convite", "lquantidade"),
    coef_labels = c("$g65 \\times Pre$", "Sealed bids", "lquantity"),
    d           = 4,
    filename    = "tab_prices_real.tex"
  )
}

# ---- Table: Extensive Margin -----------------------------------------------
if (has_ext && !is.null(ext$extensive)) {
  cat("  Generating extensive margin table...\n")

  # Custom table since FE differs (grupo_f instead of item_alt)
  m_order <- c("6m_base", "6m_pbu", "12m_base", "12m_pbu", "18m_base", "18m_pbu")
  ms <- ext$extensive[m_order]

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Extensive Margin: Tender Completion Rate}",
    "\\label{tab:extensive}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccccc}",
    "\\toprule",
    " & (1) & (2) & (3) & (4) & (5) & (6) \\\\",
    " & 6-month & 6-month & 12-month & 12-month & 18-month & 18-month \\\\",
    "\\midrule"
  )

  coef_names  <- c("g65_pre", "convite", "lquantidade")
  coef_labels <- c("$g65 \\times Pre$", "Sealed bids", "lquantity")

  for (i in seq_along(coef_names)) {
    var <- coef_names[i]
    lbl <- coef_labels[i]
    vals <- sapply(ms, function(m) coef_cell(m, var, 4))
    lines <- c(lines, sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")))
    ses <- sapply(ms, function(m) se_cell(m, var, 4))
    lines <- c(lines, sprintf(" & %s \\\\", paste(ses, collapse = " & ")))
  }

  obs <- sapply(ms, function(m) pfmt_int(m$nobs))
  r2  <- sapply(ms, function(m) pfmt(fitstat(m, "wr2")[[1]], 4))
  lines <- c(lines,
    "\\midrule",
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    sprintf("R-squared & %s \\\\", paste(r2, collapse = " & ")),
    "Group FE & YES & YES & YES & YES & YES & YES \\\\",
    "Controlling for PBU & NO & YES & NO & YES & NO & YES \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} DV = 1 if item was successfully purchased, 0 otherwise. All items included (not filtered to completed).",
    "Group FE used instead of item FE. Standard errors clustered at the item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(lines, file.path(OUT_TAB, "tab_extensive.tex"))
  cat("  Saved: tab_extensive.tex\n")
}

# ---- Table: Efficiency -----------------------------------------------------
if (has_ext && !is.null(ext$efficiency)) {
  cat("  Generating efficiency table...\n")
  write_didir_table(
    mlist       = ext$efficiency,
    caption     = "Price Efficiency: Final Price / Reference Price (\\%)",
    label       = "tab:efficiency",
    dv_label    = "Final/Ref price (\\%)",
    coef_names  = c("g65_pre", "convite", "lquantidade"),
    coef_labels = c("$g65 \\times Pre$", "Sealed bids", "lquantity"),
    d           = 4,
    filename    = "tab_efficiency.tex"
  )
}

# ---- Table: SME Winner Composition ----------------------------------------
if (has_ext && !is.null(ext$sme_winner)) {
  cat("  Generating SME winner table...\n")
  write_didir_table(
    mlist       = ext$sme_winner,
    caption     = "Winner Composition: SME Winner (binary)",
    label       = "tab:sme_winner",
    dv_label    = "SME winner (0/1)",
    coef_names  = c("g65_pre", "convite", "lquantidade"),
    coef_labels = c("$g65 \\times Pre$", "Sealed bids", "lquantity"),
    d           = 4,
    filename    = "tab_sme_winner.tex"
  )
}

# ---- Table: Bid Spread -----------------------------------------------------
if (has_ext && !is.null(ext$bid_spread)) {
  cat("  Generating bid spread table...\n")
  write_didir_table(
    mlist       = ext$bid_spread,
    caption     = "Bid Spread: Difference between 1st and 2nd Bid (Phase 1)",
    label       = "tab:bid_spread",
    dv_label    = "Bid spread",
    coef_names  = c("g65_pre", "convite", "lquantidade"),
    coef_labels = c("$g65 \\times Pre$", "Sealed bids", "lquantity"),
    d           = 4,
    filename    = "tab_bid_spread.tex"
  )
}

# ---- Table: Heterogeneity by PBU Type -------------------------------------
if (has_ext && !is.null(ext$heterog_pbu_prices_base)) {
  cat("  Generating PBU heterogeneity table...\n")

  ms_het <- list(
    ext$heterog_pbu_prices_base, ext$heterog_pbu_prices_pbu,
    ext$heterog_pbu_firms_base, ext$heterog_pbu_firms_pbu
  )

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Heterogeneous Effects by PBU Type (18-month window)}",
    "\\label{tab:heterog_pbu}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Log firms} \\\\",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
    " & Base & +PBU FE & Base & +PBU FE \\\\",
    "\\midrule"
  )

  coef_names  <- c("g65_pre", "adm_dir", "g65_pre:adm_dir")
  coef_labels <- c("$g65 \\times Pre$", "Direct admin.", "$g65 \\times Pre \\times$ Direct admin.")

  for (i in seq_along(coef_names)) {
    var <- coef_names[i]
    lbl <- coef_labels[i]
    vals <- sapply(ms_het, function(m) {
      if (var %in% names(coef(m))) coef_cell(m, var, 4) else "--"
    })
    lines <- c(lines, sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")))
    ses <- sapply(ms_het, function(m) {
      if (var %in% names(coef(m))) se_cell(m, var, 4) else ""
    })
    lines <- c(lines, sprintf(" & %s \\\\", paste(ses, collapse = " & ")))
  }

  obs <- sapply(ms_het, function(m) pfmt_int(m$nobs))
  r2  <- sapply(ms_het, function(m) pfmt(fitstat(m, "wr2")[[1]], 4))
  lines <- c(lines,
    "\\midrule",
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    sprintf("R-squared & %s \\\\", paste(r2, collapse = " & ")),
    "Item FE & YES & YES & YES & YES \\\\",
    "PBU FE & NO & YES & NO & YES \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} 18-month window. Direct admin.~is 1 for PBUs under direct administration, 0 otherwise.",
    "Standard errors clustered at the item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(lines, file.path(OUT_TAB, "tab_heterog_pbu.tex"))
  cat("  Saved: tab_heterog_pbu.tex\n")
}

# ---- Table: Heterogeneity by Item Value ------------------------------------
if (has_ext && !is.null(ext$heterog_val_prices_high)) {
  cat("  Generating item value heterogeneity table...\n")

  dvs_hv <- list(
    list(label = "Log prices",    prefix = "prices"),
    list(label = "Log firms",     prefix = "firms"),
    list(label = "Log bids",      prefix = "bids"),
    list(label = "Distance (km)", prefix = "distance")
  )

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Heterogeneous Effects by Item Value (18-month window, base specification)}",
    "\\label{tab:heterog_value}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & Log prices & Log firms & Log bids & Distance \\\\",
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel A: High-value items (above median)}} \\\\"
  )

  # Panel A: high value
  vals_h <- sapply(dvs_hv, function(v) {
    m <- ext[[paste0("heterog_val_", v$prefix, "_high")]]
    coef_cell(m, "g65_pre", 4)
  })
  ses_h <- sapply(dvs_hv, function(v) {
    m <- ext[[paste0("heterog_val_", v$prefix, "_high")]]
    se_cell(m, "g65_pre", 4)
  })
  obs_h <- sapply(dvs_hv, function(v) {
    m <- ext[[paste0("heterog_val_", v$prefix, "_high")]]
    pfmt_int(m$nobs)
  })
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals_h, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses_h, collapse = " & ")),
    sprintf("Observations & %s \\\\", paste(obs_h, collapse = " & ")),
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel B: Low-value items (below median)}} \\\\"
  )

  # Panel B: low value
  vals_l <- sapply(dvs_hv, function(v) {
    m <- ext[[paste0("heterog_val_", v$prefix, "_low")]]
    coef_cell(m, "g65_pre", 4)
  })
  ses_l <- sapply(dvs_hv, function(v) {
    m <- ext[[paste0("heterog_val_", v$prefix, "_low")]]
    se_cell(m, "g65_pre", 4)
  })
  obs_l <- sapply(dvs_hv, function(v) {
    m <- ext[[paste0("heterog_val_", v$prefix, "_low")]]
    pfmt_int(m$nobs)
  })
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals_l, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses_l, collapse = " & ")),
    sprintf("Observations & %s \\\\", paste(obs_l, collapse = " & ")),
    "\\midrule",
    "Item FE & YES & YES & YES & YES \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} 18-month window, base specification. Sample split at median reference value.",
    "Standard errors clustered at the item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(lines, file.path(OUT_TAB, "tab_heterog_value.tex"))
  cat("  Saved: tab_heterog_value.tex\n")
}

cat("  All tables generated.\n")
