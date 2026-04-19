# ============================================================================
# 15_firm_age.R — DiDiR heterogeneity by winner firm age (RAIS data_abertura)
# ============================================================================
# Tests whether the ME/EPP policy's effects differ between young and mature
# winners, using the earliest establishment opening year from RAIS ESTB as
# proxy for firm age. Median split at 2018 ages the sample.
#
# Outputs:
#   - /tmp/p2_firm_age.rds
#   - output/tables/tab_firm_age.tex
#   - output/tables/diag_firm_age.txt
# ============================================================================

cat("=== 15_firm_age.R: Heterogeneity by winner firm age ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

RAIS_LINK <- file.path(BASE, "data", "processed",
                       "paper2_suppliers_rais_linked.parquet")

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
if (!file.exists(RAIS_LINK)) stop("Run 05_link_rais.py first")

dt <- readRDS(DATA_CACHE)
stopifnot("cnpj_raiz" %in% names(dt))

rais <- as.data.table(read_parquet(RAIS_LINK))
rais <- rais[, .(cnpj_raiz, rais_match, year_abertura_min)]
setkey(rais, cnpj_raiz)
setkey(dt, cnpj_raiz)
dt <- rais[dt]
dt[, rais_match := fifelse(is.na(rais_match), FALSE, as.logical(rais_match))]

# ---- Firm age at policy switch (2018) ------------------------------------
POLICY_YEAR <- 2018L
dt[, firm_age := POLICY_YEAR - year_abertura_min]  # NA if year_abertura_min NA

# Median split restricted to pre-period completed winning rows (observational
# universe with age visible). Define cutoff once, then apply everywhere.
pre_ages <- dt[data_oc_numb < TREAT_DATE & oc_item_status == 1L &
               !is.na(firm_age), firm_age]
age_med <- as.numeric(median(pre_ages, na.rm = TRUE))
cat(sprintf("  Median firm age at policy (pre-period winners): %.1f years\n",
            age_med))

dt[, young := fifelse(!is.na(firm_age) & firm_age <= age_med, 1L, 0L)]
dt[is.na(firm_age), young := NA_integer_]   # unmatched → NA, dropped below

# Diagnostics
diag <- c(
  "=== Firm-age heterogeneity diagnostic ===",
  sprintf("Policy switch year: %d", POLICY_YEAR),
  sprintf("Median firm age (pre-period winners): %.1f years", age_med),
  sprintf("(Cutoff: young if firm_age <= %.1f, i.e., founded %.0f or later)",
          age_med, POLICY_YEAR - age_med),
  "",
  "Age distribution in 18m+completed sample with RAIS match:"
)
age_dist <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
               oc_item_status == 1L & !is.na(firm_age),
               .(n_obs = .N,
                 mean_age = mean(firm_age),
                 median_age = as.numeric(median(firm_age))),
               by = young][order(young)]
diag <- c(diag, capture.output(print(age_dist)), "")

writeLines(diag, file.path(OUT_TAB, "diag_firm_age.txt"))

# ---- Heterogeneous DiDiR -------------------------------------------------
run_het <- function(dv, data, completed = FALSE, add_pbu = FALSE) {
  d <- data[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
            !is.na(young)]
  if (completed) d <- d[oc_item_status == 1L]
  fe <- if (add_pbu) "item_alt + pbu_alt" else "item_alt"
  fml <- as.formula(paste0(dv,
    " ~ g65_pre + g65_pre:young + convite + lquantidade | ", fe))
  feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none")
}

outcomes <- list(
  list(dv = "lpreco_final", label = "Log prices",    completed = TRUE),
  list(dv = "lnum_firms",   label = "Log firms",     completed = FALSE),
  list(dv = "lnum_bids",    label = "Log bids",      completed = FALSE),
  list(dv = "dist1",        label = "Distance (km)", completed = TRUE)
)

cat("  Running 8 heterogeneous regressions (4 outcomes x 2 specs)...\n")
models <- list()
for (o in outcomes) {
  for (spec in c("base", "pbu")) {
    key <- paste0(o$dv, "_", spec)
    t0 <- Sys.time()
    models[[key]] <- run_het(o$dv, dt, completed = o$completed,
                             add_pbu = (spec == "pbu"))
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("    %-20s n=%s (%.1fs)\n", key,
                pfmt_int(models[[key]]$nobs), el))
  }
}

saveRDS(list(models = models, age_cutoff = age_med), "/tmp/p2_firm_age.rds")

# ---- LaTeX table ---------------------------------------------------------
cat("  Writing LaTeX table...\n")
lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Heterogeneity by Winner Firm Age (18-month window)}",
  "\\label{tab:firm_age}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccccccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Log firms}",
     " & \\multicolumn{2}{c}{Log bids} & \\multicolumn{2}{c}{Distance} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7} \\cmidrule(lr){8-9}",
  " & Base & +PBU FE & Base & +PBU FE & Base & +PBU FE & Base & +PBU FE \\\\",
  "\\midrule"
)

order_keys <- c("lpreco_final_base", "lpreco_final_pbu",
                "lnum_firms_base",   "lnum_firms_pbu",
                "lnum_bids_base",    "lnum_bids_pbu",
                "dist1_base",        "dist1_pbu")

for (var_info in list(
  list(var = "g65_pre",        lbl = "$g65 \\times Pre$"),
  list(var = "g65_pre:young",  lbl = "$g65 \\times Pre \\times$ Young winner"))) {
  vals <- sapply(order_keys, function(k) {
    m <- models[[k]]
    if (var_info$var %in% names(coef(m))) coef_cell(m, var_info$var, 4) else "--"
  })
  ses <- sapply(order_keys, function(k) {
    m <- models[[k]]
    if (var_info$var %in% names(coef(m))) se_cell(m, var_info$var, 4) else ""
  })
  lines <- c(lines,
    sprintf("%s & %s \\\\", var_info$lbl, paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\",                   paste(ses,  collapse = " & ")))
}

obs <- sapply(order_keys, function(k) pfmt_int(models[[k]]$nobs))
r2  <- sapply(order_keys, function(k) pfmt(fitstat(models[[k]], "wr2")[[1]], 4))

lines <- c(lines,
  "\\midrule",
  sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
  sprintf("R-squared & %s \\\\",    paste(r2,  collapse = " & ")),
  "Item FE & YES & YES & YES & YES & YES & YES & YES & YES \\\\",
  "PBU FE & NO & YES & NO & YES & NO & YES & NO & YES \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 18-month window. Log prices and distance condition on completion.",
  "``Young winner'' = 1 if the winning firm's earliest establishment opening year",
  "(RAIS ESTB) puts firm age at the March~2018 policy switch at or below the median",
  sprintf("of %.0f years (i.e., firm founded in %.0f or later).",
          age_med, POLICY_YEAR - age_med),
  "Observations without a RAIS-observable opening year are dropped.",
  "Main effect of \\textit{Young} absorbed by item FE (composition) and winner identity.",
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_firm_age.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_firm_age.tex"), "\n")
cat("  Done.\n")
