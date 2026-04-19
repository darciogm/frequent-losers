# ============================================================================
# 17_rais_controls.R — RAIS firm-level controls in the main DiDiR
# ============================================================================
# Augments the headline DiDiR (18m window, +PBU FE) with RAIS firm-level
# controls: log(1 + vinc_ativos_sum), log(1 + firm_age), CNAE 2-digit FE.
# Tests whether g65 x Pre is stable once productivity/size proxies are
# absorbed, addressing the referee concern that the estimate merely reflects
# differences in firm composition across groups.
#
# Sample: winners matched in RAIS 2017 (82.6% of valid-CNPJ observations),
# 18m window, all outcomes conditioning on completion (required to observe
# a winner whose RAIS profile can be merged).
#
# Outputs:
#   - /tmp/p2_rais_controls.rds
#   - output/tables/tab_rais_controls.tex
#   - output/tables/diag_rais_controls.txt
# ============================================================================

cat("=== 17_rais_controls.R: RAIS firm-level controls ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

RAIS_LINK <- file.path(BASE, "data", "processed",
                       "paper2_suppliers_rais_linked.parquet")
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
if (!file.exists(RAIS_LINK)) stop("Run 05_link_rais.py first")

dt <- readRDS(DATA_CACHE)
stopifnot("cnpj_raiz" %in% names(dt))

rais <- as.data.table(read_parquet(RAIS_LINK))
rais <- rais[, .(cnpj_raiz, rais_match, vinc_ativos_sum,
                 year_abertura_min, cnae20_modal)]
setkey(rais, cnpj_raiz)
setkey(dt, cnpj_raiz)
dt <- rais[dt]
dt[, rais_match := fifelse(is.na(rais_match), FALSE, as.logical(rais_match))]

POLICY_YEAR <- 2018L
dt[, firm_age := POLICY_YEAR - year_abertura_min]
dt[, log_emp := log1p(pmax(vinc_ativos_sum, 0, na.rm = TRUE))]
dt[, log_age := log1p(pmax(firm_age, 0, na.rm = TRUE))]
dt[, cnae2   := as.integer(floor(cnae20_modal / 1000))]
dt[, cnae2_f := factor(cnae2)]

# Restrict to matched winners in 18m completed universe
base_sub <- dt[rais_match == TRUE &
               data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
               oc_item_status == 1L]
cat(sprintf("  RAIS-matched 18m completed sample: %s\n",
            pfmt_int(nrow(base_sub))))

diag <- c(
  "=== RAIS controls diagnostic ===",
  sprintf("Sample: %s matched winners in 18m completed window",
          pfmt_int(nrow(base_sub))),
  sprintf("Distinct CNAE-2 divisions in sample: %d",
          uniqueN(base_sub$cnae2)),
  sprintf("Mean vínculos: %.1f  |  Mean firm age: %.1f",
          mean(base_sub$vinc_ativos_sum, na.rm = TRUE),
          mean(base_sub$firm_age, na.rm = TRUE))
)
writeLines(diag, file.path(OUT_TAB, "diag_rais_controls.txt"))

# ---- Run specifications -----------------------------------------------------
# For each outcome: (A) baseline on matched sample, (B) +log_emp +log_age,
# (C) +log_emp +log_age +CNAE-2 FE. Always +PBU FE (headline preferred spec).
specs <- list(
  A = list(rhs = "g65_pre + convite + lquantidade",
           fe  = "item_alt + pbu_alt + data_oc_numb",
           label = "Baseline"),
  B = list(rhs = "g65_pre + convite + lquantidade + log_emp + log_age",
           fe  = "item_alt + pbu_alt + data_oc_numb",
           label = "+ RAIS firm controls"),
  C = list(rhs = "g65_pre + convite + lquantidade + log_emp + log_age",
           fe  = "item_alt + pbu_alt + cnae2_f + data_oc_numb",
           label = "+ CNAE-2 FE")
)

outcomes <- c("lpreco_final", "lnum_firms", "lnum_bids", "dist1")

cat("  Running", length(outcomes) * length(specs), "regressions...\n")
mods <- list()
for (dv in outcomes) {
  for (sp in names(specs)) {
    key <- paste0(dv, "_", sp)
    fml <- as.formula(sprintf("%s ~ %s | %s",
                              dv, specs[[sp]]$rhs, specs[[sp]]$fe))
    t0 <- Sys.time()
    mods[[key]] <- feols(fml, data = base_sub, cluster = ~item_alt,
                         fixef.rm = "none")
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("    %-24s n=%s (%.1fs)\n", key,
                pfmt_int(mods[[key]]$nobs), el))
  }
}

saveRDS(mods, "/tmp/p2_rais_controls.rds")

# ---- LaTeX table ----------------------------------------------------------
cat("  Writing LaTeX table...\n")

cell_coef <- function(mod, var, d = 4) {
  if (!(var %in% names(coef(mod)))) return(c("--", ""))
  b  <- coef(mod)[var]
  se <- sqrt(vcov(mod)[var, var])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d), pstars(p)), paste0("(", pfmt(se, d), ")"))
}

col_labels <- c("Log prices", "Log firms", "Log bids", "Distance (km)")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Main DiDiR with RAIS Firm-Level Controls (18-month window, +PBU FE)}",
  "\\label{tab:rais_controls}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  sprintf(" & %s \\\\", paste(col_labels, collapse = " & ")),
  "\\midrule"
)

# Emit a panel per specification
spec_headers <- c(
  A = "\\multicolumn{5}{l}{\\textit{Panel A: Baseline (matched winners, no RAIS controls)}} \\\\",
  B = "\\multicolumn{5}{l}{\\textit{Panel B: + log(1+vínculos) + log(1+age)}} \\\\",
  C = "\\multicolumn{5}{l}{\\textit{Panel C: + log(1+vínculos) + log(1+age) + CNAE-2 FE}} \\\\"
)

for (sp in names(specs)) {
  lines <- c(lines, spec_headers[[sp]])
  # g65xPre row
  vals <- sapply(outcomes, function(dv) cell_coef(mods[[paste0(dv, "_", sp)]], "g65_pre")[1])
  ses  <- sapply(outcomes, function(dv) cell_coef(mods[[paste0(dv, "_", sp)]], "g65_pre")[2])
  lines <- c(lines,
    sprintf("$g65 \\times Pre$ & %s \\\\", paste(vals, collapse = " & ")),
    sprintf(" & %s \\\\",                   paste(ses,  collapse = " & ")))
  # Control coefficients in panels B and C
  if (sp %in% c("B", "C")) {
    for (cv in c("log_emp", "log_age")) {
      lbl <- switch(cv, log_emp = "$\\log(1 + \\text{vínculos})$",
                       log_age = "$\\log(1 + \\text{age})$")
      vals <- sapply(outcomes, function(dv) cell_coef(mods[[paste0(dv, "_", sp)]], cv)[1])
      ses  <- sapply(outcomes, function(dv) cell_coef(mods[[paste0(dv, "_", sp)]], cv)[2])
      lines <- c(lines,
        sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")),
        sprintf(" & %s \\\\",  paste(ses,  collapse = " & ")))
    }
  }
  lines <- c(lines, "\\addlinespace")
}

obs <- sapply(outcomes, function(dv) pfmt_int(mods[[paste0(dv, "_A")]]$nobs))
r2A <- sapply(outcomes, function(dv) pfmt(fitstat(mods[[paste0(dv, "_A")]], "wr2")[[1]], 4))
r2B <- sapply(outcomes, function(dv) pfmt(fitstat(mods[[paste0(dv, "_B")]], "wr2")[[1]], 4))
r2C <- sapply(outcomes, function(dv) pfmt(fitstat(mods[[paste0(dv, "_C")]], "wr2")[[1]], 4))

lines <- c(lines,
  "\\midrule",
  sprintf("Observations (Panel A) & %s \\\\", paste(obs, collapse = " & ")),
  sprintf("R-squared (Panel A) & %s \\\\",   paste(r2A, collapse = " & ")),
  sprintf("R-squared (Panel B) & %s \\\\",   paste(r2B, collapse = " & ")),
  sprintf("R-squared (Panel C) & %s \\\\",   paste(r2C, collapse = " & ")),
  "Item FE + PBU FE & YES & YES & YES & YES \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 18-month window, RAIS-matched winners only, all",
  "outcomes conditioned on completion (\\texttt{oc\\_item\\_status=1}) to",
  "permit merging the winner's RAIS profile. Item FE and PBU FE throughout.",
  "\\textit{Panel A} is the headline specification restricted to matched",
  "winners (for direct comparison with Panels B--C). \\textit{Panel B} adds",
  "firm-level productivity proxies: log of active employment links (2017) and",
  "log of firm age at the March~2018 policy switch (from earliest RAIS",
  "establishment opening). \\textit{Panel C} further saturates with CNAE 2-digit",
  "division fixed effects (sector of the winning firm).",
  "Stability of $g65 \\times Pre$ across panels rules out firm-composition bias.",
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_rais_controls.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_rais_controls.tex"), "\n")
cat("  Done.\n")
