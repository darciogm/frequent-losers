# ============================================================================
# 18_age_size.R — DiDiR by winner age x size quadrants (RAIS)
# ============================================================================
# Crosses firm age (young/mature, median split = 9 years) with firm size
# (SME/large, legal ME/EPP ceiling at 49 vínculos) to form four quadrants
# of winner type. Runs a separate DiDiR within each quadrant to identify
# which combination drives the rent transfer of the ME/EPP preference.
#
# Quadrants:
#   - Young-SME     (firm_age <= 9  &  vinculos <= 49): the stated target
#   - Young-Large   (firm_age <= 9  &  vinculos >  49): startups already scaled
#   - Mature-SME    (firm_age >  9  &  vinculos <= 49): established yet small
#   - Mature-Large  (firm_age >  9  &  vinculos >  49): strictly non-eligible
#
# Outputs:
#   - /tmp/p2_age_size.rds
#   - output/tables/tab_age_size.tex
#   - output/tables/diag_age_size.txt
# ============================================================================

cat("=== 18_age_size.R: Age x Size quadrant heterogeneity ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

RAIS_LINK <- file.path(BASE, "data", "processed",
                       "paper2_suppliers_rais_linked.parquet")
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
if (!file.exists(RAIS_LINK)) stop("Run 05_link_rais.py first")

dt <- readRDS(DATA_CACHE)
stopifnot("cnpj_raiz" %in% names(dt))

rais <- as.data.table(read_parquet(RAIS_LINK))
rais <- rais[, .(cnpj_raiz, rais_match, vinc_ativos_sum, year_abertura_min)]
setkey(rais, cnpj_raiz); setkey(dt, cnpj_raiz)
dt <- rais[dt]
dt[, rais_match := fifelse(is.na(rais_match), FALSE, as.logical(rais_match))]

POLICY_YEAR <- 2018L
dt[, firm_age := POLICY_YEAR - year_abertura_min]

# Cutoffs: median age from pre-period winners (matches script 15) and legal
# ME/EPP ceiling of 49 employees.
pre_ages <- dt[data_oc_numb < TREAT_DATE & oc_item_status == 1L &
               !is.na(firm_age), firm_age]
AGE_CUT  <- as.numeric(median(pre_ages, na.rm = TRUE))
SIZE_CUT <- 49L

cat(sprintf("  Cutoffs: age <= %.1f years (young), vinculos <= %d (SME)\n",
            AGE_CUT, SIZE_CUT))

dt[, young  := as.integer(!is.na(firm_age)         & firm_age        <= AGE_CUT)]
dt[, is_sme := as.integer(!is.na(vinc_ativos_sum) & vinc_ativos_sum <= SIZE_CUT)]
# observations lacking either covariate are excluded from quadrants
dt[is.na(firm_age) | is.na(vinc_ativos_sum), c("young", "is_sme") := NA_integer_]

dt[, quadrant := fcase(
  young == 1L & is_sme == 1L, "young_sme",
  young == 1L & is_sme == 0L, "young_large",
  young == 0L & is_sme == 1L, "mature_sme",
  young == 0L & is_sme == 0L, "mature_large",
  default = NA_character_
)]

# ---- Diagnostic ------------------------------------------------------------
d18c <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
           oc_item_status == 1L]
qcounts <- d18c[!is.na(quadrant), .N, by = quadrant][order(-N)]
cat("  Quadrant sample sizes (18m completed):\n")
print(qcounts)

diag <- c(
  "=== Age x Size quadrant heterogeneity ===",
  sprintf("Age cutoff (median of pre-period winners): %.1f years (founded %.0f)",
          AGE_CUT, POLICY_YEAR - AGE_CUT),
  sprintf("Size cutoff (ME/EPP legal ceiling):         %d vínculos", SIZE_CUT),
  "",
  "Quadrant sample sizes (18m completed):",
  capture.output(print(qcounts))
)
writeLines(diag, file.path(OUT_TAB, "diag_age_size.txt"))

# ---- DiDiR per quadrant ----------------------------------------------------
run_q <- function(dv, quadrant_name) {
  d <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
          oc_item_status == 1L &
          !is.na(quadrant) & quadrant == quadrant_name]
  if (nrow(d) < 500L) return(NULL)
  fml <- as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt"))
  tryCatch(
    feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none"),
    error = function(e) NULL)
}

outcomes <- c("lpreco_final", "lnum_firms", "lnum_bids", "dist1")
quadrants <- c("young_sme", "young_large", "mature_sme", "mature_large")

cat("  Running ", length(outcomes) * length(quadrants), " regressions...\n",
    sep = "")
mods <- list()
for (q in quadrants) {
  for (dv in outcomes) {
    key <- paste0(q, "_", dv)
    mods[[key]] <- run_q(dv, q)
  }
}

saveRDS(list(mods = mods, age_cut = AGE_CUT, size_cut = SIZE_CUT,
             qcounts = qcounts),
        "/tmp/p2_age_size.rds")

# ---- LaTeX table ----------------------------------------------------------
cat("  Writing LaTeX table...\n")

cell_coef <- function(key, d = 4) {
  m <- mods[[key]]
  if (is.null(m))                     return(c("--", "--"))
  if (!"g65_pre" %in% names(coef(m))) return(c("--", "--"))
  b  <- coef(m)["g65_pre"]
  se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d), pstars(p)), paste0("(", pfmt(se, d), ")"))
}

quadrant_labels <- c(
  young_sme     = "Young SME ($\\leq$9y, $\\leq$49 v.)",
  young_large   = "Young large ($\\leq$9y, $>$49 v.)",
  mature_sme    = "Mature SME ($>$9y, $\\leq$49 v.)",
  mature_large  = "Mature large ($>$9y, $>$49 v.)"
)

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{DiDiR by Winner Age $\\times$ Size Quadrant (18-month window)}",
  "\\label{tab:age_size}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  " & $N$ & Log prices & Log firms & Log bids & Distance \\\\",
  "\\midrule"
)

for (q in quadrants) {
  nrow_q <- if (!is.null(mods[[paste0(q, "_lpreco_final")]]))
               pfmt_int(mods[[paste0(q, "_lpreco_final")]]$nobs)
            else "--"
  cells_val <- character(0)
  cells_se  <- character(0)
  for (dv in outcomes) {
    cc <- cell_coef(paste0(q, "_", dv))
    cells_val <- c(cells_val, cc[1])
    cells_se  <- c(cells_se,  cc[2])
  }
  lines <- c(lines,
    sprintf("%s & %s & %s \\\\",
            quadrant_labels[[q]], nrow_q,
            paste(cells_val, collapse = " & ")),
    sprintf(" & & %s \\\\",
            paste(cells_se, collapse = " & ")))
}

lines <- c(lines,
  "\\midrule",
  "Item FE & \\multicolumn{5}{c}{YES (within each quadrant subsample)} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 18-month window, completed items, RAIS-matched",
  "winners only. Each row is a separate DiDiR regression on a sub-sample",
  "defined by the winner's age at the March~2018 policy switch (cutoff at",
  sprintf("%.0f-year median) and active employment links in RAIS 2017",
          AGE_CUT),
  sprintf("(cutoff at the legal ME/EPP ceiling of %d).", SIZE_CUT),
  "Item FE within each sub-sample; SEs clustered at the item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_age_size.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_age_size.tex"), "\n")
cat("  Done.\n")
