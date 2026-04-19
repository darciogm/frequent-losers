# ============================================================================
# 11_rais_validation.R — Robustness using RAIS 2017 BR to validate ME/EPP
# ============================================================================
# Runs the headline DiDiR (18-month window, item FE) on successively stricter
# winner subsamples defined by RAIS-observed establishment size at cnpj_raiz.
# Writes output/tables/tab_rais_validation.tex.
#
# Prereqs:
#   - /tmp/p2_prepared.rds (01_clean.R)
#   - data/processed/paper2_suppliers_rais_linked.parquet (05_link_rais.py)
# ============================================================================

cat("=== 11_rais_validation.R: RAIS-validated subsamples ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

RAIS_LINK <- file.path(BASE, "data", "processed",
                       "paper2_suppliers_rais_linked.parquet")

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
if (!file.exists(RAIS_LINK)) stop("Run 05_link_rais.py first: ", RAIS_LINK)

dt <- readRDS(DATA_CACHE)
if (!"cnpj_raiz" %in% names(dt)) {
  stop("cnpj_raiz missing from cache — 01_clean.R must be rerun after v3 bump")
}
cat("  Cache rows:", pfmt_int(nrow(dt)),
    "| with cnpj_raiz:", pfmt_int(sum(!is.na(dt$cnpj_raiz))), "\n")

# ---- Merge RAIS supplier aggregates ---------------------------------------
rais <- as.data.table(read_parquet(RAIS_LINK))
keep <- c("cnpj_raiz", "rais_match", "has_sp_estab", "n_estab",
          "vinc_ativos_sum", "any_simples", "year_abertura_min",
          "cnae20_modal", "uf_modal")
rais <- rais[, ..keep]
setkey(rais, cnpj_raiz)
setkey(dt, cnpj_raiz)
dt <- rais[dt]  # left-join on dt

# Fill logical flags: suppliers with no CNPJ have rais_match = FALSE
dt[, rais_match   := fifelse(is.na(rais_match),   FALSE, as.logical(rais_match))]
dt[, has_sp_estab := fifelse(is.na(has_sp_estab), FALSE, as.logical(has_sp_estab))]

# ---- Define RAIS-validated flags at the obs (winner) level ---------------
dt[, win_sme      := rais_match & !is.na(vinc_ativos_sum) & vinc_ativos_sum <= 49]
dt[, win_micro    := rais_match & !is.na(vinc_ativos_sum) & vinc_ativos_sum <= 9]
dt[, win_not_large := rais_match & (is.na(vinc_ativos_sum) | vinc_ativos_sum < 100)]

cat("  RAIS flags (18m, completed, valid CNPJ subset):\n")
base18 <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
             oc_item_status == 1L]
cat(sprintf("    full completed 18m:      n=%s\n",    pfmt_int(nrow(base18))))
cat(sprintf("    winner matched in RAIS:  n=%s\n",    pfmt_int(base18[rais_match == TRUE, .N])))
cat(sprintf("    winner SME (<=49 vinc):  n=%s\n",    pfmt_int(base18[win_sme == TRUE, .N])))
cat(sprintf("    winner micro (<=9 vinc): n=%s\n",    pfmt_int(base18[win_micro == TRUE, .N])))
cat(sprintf("    winner not-large (<100): n=%s\n",    pfmt_int(base18[win_not_large == TRUE, .N])))

# ---- Regression helper (18m, completed, item FE, base spec) --------------
run_sub <- function(dv, data, sub_mask) {
  d <- data[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
            oc_item_status == 1L]
  if (!is.null(sub_mask)) d <- d[eval(sub_mask)]
  fml <- as.formula(paste0(dv, " ~ g65_pre + convite + lquantidade | item_alt + data_oc_numb"))
  feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none")
}

cat("  Running regressions...\n")

samples <- list(
  full      = NULL,
  matched   = quote(rais_match == TRUE),
  sme       = quote(win_sme == TRUE),
  micro     = quote(win_micro == TRUE),
  not_large = quote(win_not_large == TRUE)
)

models <- list()
for (outcome in c("lpreco_final", "dist1", "lnum_firms", "lnum_bids")) {
  for (snm in names(samples)) {
    key <- paste0(outcome, "_", snm)
    t0 <- Sys.time()
    models[[key]] <- run_sub(outcome, dt, samples[[snm]])
    dt_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("    %-28s n=%s (%.1fs)\n", key,
                pfmt_int(models[[key]]$nobs), dt_s))
  }
}

saveRDS(models, "/tmp/p2_rais_validation.rds")

# ---- Write LaTeX table ---------------------------------------------------
cat("  Writing LaTeX table...\n")

col_labels <- c(
  "Full",
  "Winner in RAIS",
  "SME ($\\leq$49)",
  "Micro ($\\leq$9)",
  "Not large ($<$100)"
)

write_panel <- function(model_names, panel_title) {
  ms <- models[model_names]
  vals <- sapply(ms, function(m) coef_cell(m, "g65_pre", 4))
  ses  <- sapply(ms, function(m) se_cell(m, "g65_pre", 4))
  obs  <- sapply(ms, function(m) pfmt_int(m$nobs))
  r2   <- sapply(ms, function(m) pfmt(fitstat(m, "wr2")[[1]], 4))
  c(
    sprintf("\\multicolumn{6}{l}{\\textit{%s}} \\\\", panel_title),
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\",                   paste(ses,  collapse = " & ")),
    sprintf("Observations & %s \\\\",       paste(obs,  collapse = " & ")),
    sprintf("R-squared & %s \\\\",          paste(r2,   collapse = " & "))
  )
}

suffixes <- c("full", "matched", "sme", "micro", "not_large")

lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{RAIS-Validated Winner Subsamples (18-month window, item FE)}",
  "\\label{tab:rais_validation}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  " & (1) & (2) & (3) & (4) & (5) \\\\",
  sprintf(" & %s \\\\", paste(col_labels, collapse = " & ")),
  "\\midrule",
  write_panel(paste0("lpreco_final_", suffixes), "Panel A: Log price"),
  "\\midrule",
  write_panel(paste0("dist1_",        suffixes), "Panel B: Distance (km)"),
  "\\midrule",
  write_panel(paste0("lnum_firms_",   suffixes), "Panel C: Log firms (completed-item subset)"),
  "\\midrule",
  write_panel(paste0("lnum_bids_",    suffixes), "Panel D: Log bids (completed-item subset)"),
  "\\midrule",
  "Item FE & YES & YES & YES & YES & YES \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Base specification from column (5) of Table~\\ref{tab:prices}",
  "(18-month window, item FE, controls for sealed bids and log quantity) re-estimated",
  "on subsamples defined by the RAIS-observed size of the winning firm.",
  "Column (1) uses the full sample with a valid winner (\\texttt{oc\\_item\\_status=1}).",
  "(2) restricts to winners matched in RAIS 2017 (Brasil, any UF).",
  "(3)--(4) further restrict to winners with $\\leq$49 and $\\leq$9 active employment",
  "links (i.e., RAIS-confirmed SME and micro).",
  "(5) drops winners with $\\geq$100 links, addressing potential mis-declaration of ME/EPP status.",
  "Employment is summed across all Brazilian establishments of the CNPJ raiz.",
  "Panels~A--B match Tables~\\ref{tab:prices} and~\\ref{tab:distance}, both of which",
  "condition on completion. Panels~C--D differ from Tables~\\ref{tab:participants}--\\ref{tab:validbids}",
  "by also conditioning on completion, since only winners carry a CNPJ observable in RAIS.",
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

filepath <- file.path(OUT_TAB, "tab_rais_validation.tex")
writeLines(lines, filepath)
cat("  Saved:", filepath, "\n")
cat("  Done.\n")
