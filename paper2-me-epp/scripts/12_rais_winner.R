# ============================================================================
# 12_rais_winner.R — Winner composition: RAIS-validated SME (causal clean)
# ============================================================================
# Item-level outcome "was the winner a true SME in RAIS?" is causally clean
# (no post-treatment sample conditioning beyond existing completed=TRUE used
# by the companion self-declared outcome `sme_winner`).
# Writes output/tables/tab_winner_rais.tex in the 6-col DiDiR format,
# mirroring tab_sme_winner for direct comparison.
# ============================================================================

cat("=== 12_rais_winner.R: RAIS-validated winner composition ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

RAIS_LINK <- file.path(BASE, "data", "processed",
                       "paper2_suppliers_rais_linked.parquet")

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
if (!file.exists(RAIS_LINK)) stop("Run 05_link_rais.py first: ", RAIS_LINK)

dt <- readRDS(DATA_CACHE)
stopifnot("cnpj_raiz" %in% names(dt))

rais <- as.data.table(read_parquet(RAIS_LINK))
rais <- rais[, .(cnpj_raiz, rais_match, vinc_ativos_sum)]
setkey(rais, cnpj_raiz)
setkey(dt, cnpj_raiz)
dt <- rais[dt]
dt[, rais_match := fifelse(is.na(rais_match), FALSE, as.logical(rais_match))]

# ---- Item-level binary outcomes (completed items; 0 for NA inputs) --------
# Following the coding of existing sme_winner: defined on the completed sample.
dt[, win_rais_sme     := fifelse(
       rais_match & !is.na(vinc_ativos_sum) & vinc_ativos_sum <= 49, 1L, 0L,
       na = 0L)]
dt[, win_rais_micro   := fifelse(
       rais_match & !is.na(vinc_ativos_sum) & vinc_ativos_sum <= 9,  1L, 0L,
       na = 0L)]
dt[, win_rais_notlarge := fifelse(
       rais_match & (is.na(vinc_ativos_sum) | vinc_ativos_sum < 100), 1L, 0L,
       na = 0L)]

# ---- Diagnostic: means on completed 18-month sample -----------------------
d18c <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
           oc_item_status == 1L]
cat(sprintf("  Sample (18m, completed): n=%s\n", pfmt_int(nrow(d18c))))
cat(sprintf("  Mean win_rais_sme     = %.4f\n", mean(d18c$win_rais_sme)))
cat(sprintf("  Mean win_rais_micro   = %.4f\n", mean(d18c$win_rais_micro)))
cat(sprintf("  Mean win_rais_notlarge= %.4f\n", mean(d18c$win_rais_notlarge)))
if ("sme_winner" %in% names(dt)) {
  cat(sprintf("  Mean sme_winner (self)= %.4f  [for comparison]\n",
              mean(d18c$sme_winner)))
}

# ---- Run 6-col DiDiR for each RAIS outcome --------------------------------
cat("  Running regressions...\n")
m_sme      <- run_didir_6("win_rais_sme",     dt, completed = TRUE)
m_micro    <- run_didir_6("win_rais_micro",   dt, completed = TRUE)
m_notlarge <- run_didir_6("win_rais_notlarge", dt, completed = TRUE)

models <- list(sme = m_sme, micro = m_micro, notlarge = m_notlarge)
saveRDS(models, "/tmp/p2_rais_winner.rds")

# ---- Write LaTeX table (6-col DiDiR) --------------------------------------
# Minimal inline helper (write_didir_table lives in 03_tables.R).
write_6col <- function(mlist, caption, label, coef_names, coef_labels,
                       filename, d = 4) {
  m_order <- c("6m_base", "6m_pbu", "12m_base", "12m_pbu", "18m_base", "18m_pbu")
  ms <- mlist[m_order]
  lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    sprintf("\\caption{%s}", caption), sprintf("\\label{%s}", label),
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcccccc}", "\\toprule",
    " & (1) & (2) & (3) & (4) & (5) & (6) \\\\",
    " & 6-month & 6-month & 12-month & 12-month & 18-month & 18-month \\\\",
    "\\midrule"
  )
  for (i in seq_along(coef_names)) {
    var <- coef_names[i]; lbl <- coef_labels[i]
    vals <- sapply(ms, function(m) coef_cell(m, var, d))
    ses  <- sapply(ms, function(m) se_cell(m, var, d))
    lines <- c(lines,
      sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")),
      sprintf(" & %s \\\\",   paste(ses,  collapse = " & ")))
  }
  obs <- sapply(ms, function(m) pfmt_int(m$nobs))
  r2  <- sapply(ms, function(m) pfmt(fitstat(m, "wr2")[[1]], 4))
  lines <- c(lines,
    "\\midrule",
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    sprintf("R-squared & %s \\\\",    paste(r2,  collapse = " & ")),
    "Item Fixed Effects & YES & YES & YES & YES & YES & YES \\\\",
    "Controlling for PBU & NO & YES & NO & YES & NO & YES \\\\",
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Standard errors clustered at the item level in parentheses.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "Constant absorbed by fixed effects.",
    "\\end{tablenotes}",
    "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
  )
  writeLines(lines, file.path(OUT_TAB, filename))
  cat("  Saved:", file.path(OUT_TAB, filename), "\n")
}

write_6col(
  mlist       = m_sme,
  caption     = "Winner Composition: RAIS-Validated SME (winner $\\leq$49 employment links)",
  label       = "tab:winner_rais",
  coef_names  = c("g65_pre", "convite", "lquantidade"),
  coef_labels = c("$g65 \\times Pre$", "Sealed bids", "lquantity"),
  filename    = "tab_winner_rais.tex"
)

# ---- Append a compact supplementary panel with the other two definitions --
cat("  Appending compact 18m summary for alternative definitions...\n")
compact_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Winner Composition: Alternative RAIS Size Thresholds (18-month window)}",
  "\\label{tab:winner_rais_alt}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{Micro ($\\leq$9 vínculos)} & \\multicolumn{2}{c}{Not large ($<$100 vínculos)} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  " & Base & +PBU FE & Base & +PBU FE \\\\",
  "\\midrule"
)

ms_alt <- list(m_micro$`18m_base`, m_micro$`18m_pbu`,
               m_notlarge$`18m_base`, m_notlarge$`18m_pbu`)
vals <- sapply(ms_alt, function(m) coef_cell(m, "g65_pre", 4))
ses  <- sapply(ms_alt, function(m) se_cell(m, "g65_pre", 4))
obs  <- sapply(ms_alt, function(m) pfmt_int(m$nobs))
r2   <- sapply(ms_alt, function(m) pfmt(fitstat(m, "wr2")[[1]], 4))

compact_lines <- c(compact_lines,
  sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
  sprintf(" & %s \\\\",                   paste(ses,  collapse = " & ")),
  "\\midrule",
  sprintf("Observations & %s \\\\",       paste(obs,  collapse = " & ")),
  sprintf("R-squared & %s \\\\",          paste(r2,   collapse = " & ")),
  "Item FE & YES & YES & YES & YES \\\\",
  "PBU FE & NO & YES & NO & YES \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Item-level binary outcome equal to one if the winner's",
  "CNPJ raiz matches RAIS 2017 (Brasil) with at most 9 (Micro) or fewer than 100",
  "(Not large) active employment links summed across establishments. 18-month window,",
  "completed items. Compare to Table~\\ref{tab:winner_rais} (SME $\\leq$49) and",
  "Table~\\ref{tab:sme_winner} (self-declared).",
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)
writeLines(compact_lines, file.path(OUT_TAB, "tab_winner_rais_alt.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_winner_rais_alt.tex"), "\n")
cat("  Done.\n")
