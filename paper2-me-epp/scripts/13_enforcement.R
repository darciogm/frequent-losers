# ============================================================================
# 13_enforcement.R — Enforcement/eligibility heterogeneity via RAIS
# ============================================================================
# Builds a PBU-level measure of pre-period exposure to large-firm winners
# (share of pre-treatment winners with RAIS vínculos >= 100) and tests whether
# the DiDiR coefficients are larger where the ME/EPP restriction is more
# binding ex ante. This turns the RAIS link into direct policy evidence:
# where eligibility is most constrained, procurement costs rise more.
#
# Outputs:
#   - /tmp/p2_enforcement.rds
#   - output/tables/tab_enforcement.tex
#   - output/tables/diag_enforcement.txt
# ============================================================================

cat("=== 13_enforcement.R: Supply-constraint heterogeneity ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

RAIS_LINK <- file.path(BASE, "data", "processed",
                       "paper2_suppliers_rais_linked.parquet")

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
if (!file.exists(RAIS_LINK)) stop("Run 05_link_rais.py first")

dt <- readRDS(DATA_CACHE)
stopifnot("cnpj_raiz" %in% names(dt))

rais <- as.data.table(read_parquet(RAIS_LINK))
rais <- rais[, .(cnpj_raiz, rais_match, vinc_ativos_sum)]
setkey(rais, cnpj_raiz)
setkey(dt, cnpj_raiz)
dt <- rais[dt]
dt[, rais_match := fifelse(is.na(rais_match), FALSE, as.logical(rais_match))]

# ---- Build PBU-level pre-period large-firm exposure -----------------------
# Universe: pre-period completed items with RAIS-observable winner.
pre_win <- dt[data_oc_numb < TREAT_DATE &
              oc_item_status == 1L &
              rais_match == TRUE &
              !is.na(vinc_ativos_sum)]

pbu_exp <- pre_win[, .(
  n_pre_wins     = .N,
  large_share_pre = mean(vinc_ativos_sum >= 100)
), by = pbu_alt]

# Require at least 20 pre-period winning observations to stabilize the share
MIN_N <- 20L
pbu_exp_stable <- pbu_exp[n_pre_wins >= MIN_N]
cat(sprintf("  PBUs total=%s | with n_pre>=%d: %s\n",
            pfmt_int(nrow(pbu_exp)), MIN_N, pfmt_int(nrow(pbu_exp_stable))))

# Weighted median (by observation counts) as cutoff
med <- with(pbu_exp_stable,
            matrixStats::weightedMedian(large_share_pre, w = n_pre_wins,
                                        interpolate = FALSE))
cat(sprintf("  Weighted median large_share_pre = %.4f\n", med))

pbu_exp_stable[, pbu_lax := as.integer(large_share_pre > med)]
setkey(pbu_exp_stable, pbu_alt)

# Save diagnostics
diag_lines <- c(
  "=== Enforcement heterogeneity diagnostic ===",
  sprintf("PBUs with pre-period wins >= %d: %d (of %d total)",
          MIN_N, nrow(pbu_exp_stable), nrow(pbu_exp)),
  sprintf("Weighted median large_share_pre cutoff: %.4f", med),
  "",
  "Distribution of large_share_pre (stable PBUs):",
  capture.output(print(summary(pbu_exp_stable$large_share_pre))),
  "",
  sprintf("PBUs flagged lax (share > %.4f): %d",
          med, sum(pbu_exp_stable$pbu_lax)),
  sprintf("Total obs in lax PBUs (all years): will compute after merge")
)

# ---- Merge back to main data ---------------------------------------------
setkey(dt, pbu_alt)
dt_het <- pbu_exp_stable[, .(pbu_alt, pbu_lax, large_share_pre)][dt]
# observations in PBUs below the min_n threshold have pbu_lax = NA and are
# dropped by feols; that's intentional — the test runs only on stable PBUs.

n_in_lax <- dt_het[!is.na(pbu_lax) & pbu_lax == 1L, .N]
n_in_strict <- dt_het[!is.na(pbu_lax) & pbu_lax == 0L, .N]
n_drop <- dt_het[is.na(pbu_lax), .N]
diag_lines <- c(diag_lines,
  sprintf("Obs in lax PBUs: %s", pfmt_int(n_in_lax)),
  sprintf("Obs in strict PBUs: %s", pfmt_int(n_in_strict)),
  sprintf("Obs dropped (PBU below MIN_N): %s", pfmt_int(n_drop))
)
writeLines(diag_lines, file.path(OUT_TAB, "diag_enforcement.txt"))
cat("  Wrote diagnostic:", file.path(OUT_TAB, "diag_enforcement.txt"), "\n")

# ---- Heterogeneous DiDiR --------------------------------------------------
run_het <- function(dv, data, completed = FALSE, add_pbu = FALSE) {
  d <- data[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
            !is.na(pbu_lax)]
  if (completed) d <- d[oc_item_status == 1L]
  fe <- paste0(if (add_pbu) "item_alt + pbu_alt" else "item_alt", " + data_oc_numb")
  fml <- as.formula(paste0(dv,
    " ~ g65_pre + g65_pre:pbu_lax + convite + lquantidade | ", fe))
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
    add_pbu <- (spec == "pbu")
    t0 <- Sys.time()
    models[[key]] <- run_het(o$dv, dt_het, completed = o$completed,
                             add_pbu = add_pbu)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("    %-20s n=%s (%.1fs)\n", key,
                pfmt_int(models[[key]]$nobs), el))
  }
}

saveRDS(list(models = models, cutoff = med,
             pbu_exp = pbu_exp_stable),
        "/tmp/p2_enforcement.rds")

# ---- LaTeX table ----------------------------------------------------------
cat("  Writing LaTeX table...\n")
lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Supply-Constraint Heterogeneity by PBU Exposure to Large Firms}",
  "\\label{tab:enforcement}",
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
  list(var = "g65_pre",          lbl = "$g65 \\times Pre$"),
  list(var = "g65_pre:pbu_lax",  lbl = "$g65 \\times Pre \\times$ Lax PBU"))) {
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
  "\\item \\textit{Notes:} 18-month window. Panel~A and~D condition on completion.",
  sprintf("``Lax PBU'' = 1 if the PBU's pre-period large-firm win share (winners with $\\geq$100 RAIS vínculos) exceeds %.3f (weighted median across PBUs with $\\geq$20 pre-period wins).", med),
  "Lax PBUs are those where the ME/EPP restriction is ex-ante most binding because",
  "the buyer historically transacted more with non-SME suppliers.",
  "Main effect of \\textit{Lax PBU} absorbed by PBU fixed effects (+PBU specs) and by composition shift under Item FE.",
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_enforcement.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_enforcement.tex"), "\n")
cat("  Done.\n")
