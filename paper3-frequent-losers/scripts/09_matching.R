# ============================================================================
# 09_matching.R — CEM and IPW matching estimators
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================
# CEM via MatchIt: coarsen on year, convite, item_group, pbu_size_q
# IPW: logit P(losers=1 | covariates), weight regression by 1/p
# Re-run price, nfirms, nbids on matched/weighted samples
# ============================================================================

cat("=== 09_matching.R: Matching estimators ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

if (!requireNamespace("MatchIt", quietly = TRUE)) {
  stop("Package 'MatchIt' is required. Install with: install.packages('MatchIt')")
}
suppressPackageStartupMessages(library(MatchIt))

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

dvs <- c("lneg_price", "ln_firms", "ln_bids")
dv_labels <- c("Log Price", "Log Firms", "Log Bids")

# ---- Prepare matching data ---------------------------------------------------
# Keep complete cases for matching covariates
d_match <- dt[!is.na(pbu_size_q) & !is.na(item_group)]
cat("  Matching sample:", pfmt_int(nrow(d_match)), "rows\n")

# Subsample if too large for MatchIt (memory-intensive)
max_n <- 1000000L
if (nrow(d_match) > max_n) {
  set.seed(42)
  d_match <- d_match[sample(.N, max_n)]
  cat(sprintf("  Subsampled to %s rows for matching\n", pfmt_int(max_n)))
}

# ============================================================================
# CEM (Coarsened Exact Matching)
# ============================================================================

cat("  CEM matching...\n")

cem_result <- tryCatch({
  matchit(losers ~ year + convite + item_group + pbu_size_q,
          data = d_match,
          method = "cem")
}, error = function(e) {
  cat(sprintf("    CEM failed: %s\n", e$message))
  NULL
})

cem_models <- list()
if (!is.null(cem_result)) {
  d_cem <- match.data(cem_result)
  cat(sprintf("  CEM matched sample: %s rows\n", pfmt_int(nrow(d_cem))))

  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    d <- if (dv == "lneg_price") d_cem[!is.na(d_cem[[dv]]), ] else d_cem

    if (nrow(d) < 100) next

    # Convert to data.table for feols
    d <- as.data.table(d)

    m <- tryCatch(
      feols(as.formula(paste0(dv, " ~ losers + convite | item_f + year_f + pbu_f")),
            data = d, weights = ~weights, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) {
        cat(sprintf("    CEM %s failed: %s\n", dv_labels[di], e$message))
        NULL
      }
    )
    if (!is.null(m)) cem_models[[dv]] <- m
  }
}

# ============================================================================
# IPW (Inverse Probability Weighting)
# ============================================================================

cat("  IPW estimation...\n")

# Propensity score: P(losers=1 | year, convite, n_firms, pbu_size_q)
d_ipw <- copy(d_match)
d_ipw[, year_c := year - min(year)]  # center year

pscore_fit <- tryCatch(
  glm(losers ~ year_c + convite + log(n_firms + 1) + factor(pbu_size_q),
      data = d_ipw, family = binomial(link = "logit")),
  error = function(e) {
    cat(sprintf("    Propensity score model failed: %s\n", e$message))
    NULL
  }
)

ipw_models <- list()
if (!is.null(pscore_fit)) {
  d_ipw[, pscore := predict(pscore_fit, type = "response")]

  # Trim extreme propensity scores
  d_ipw <- d_ipw[pscore > 0.01 & pscore < 0.99]
  cat(sprintf("  IPW sample after trimming: %s rows\n", pfmt_int(nrow(d_ipw))))

  # IPW weights: treated get 1/p, controls get 1/(1-p)
  d_ipw[, ipw := fifelse(losers == 1, 1 / pscore, 1 / (1 - pscore))]

  # Normalize weights
  d_ipw[, ipw := ipw / mean(ipw)]

  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    d <- if (dv == "lneg_price") d_ipw[!is.na(get(dv))] else d_ipw

    if (nrow(d) < 100) next

    m <- tryCatch(
      feols(as.formula(paste0(dv, " ~ losers + convite | item_f + year_f + pbu_f")),
            data = d, weights = ~ipw, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) {
        cat(sprintf("    IPW %s failed: %s\n", dv_labels[di], e$message))
        NULL
      }
    )
    if (!is.null(m)) ipw_models[[dv]] <- m
  }
}

# ============================================================================
# Matching results table
# ============================================================================

cat("  Writing tab_matching.tex...\n")

match_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Matching and Reweighting Estimates}",
  "\\label{tab:matching}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  " & Log Price & Log Firms & Log Bids \\\\",
  "\\midrule",
  "\\textit{Panel A: Baseline (OLS with FE)} & & & \\\\"
)

# Baseline: reload main models
models_path <- "/tmp/p3_models.rds"
if (file.exists(models_path)) {
  main_models <- readRDS(models_path)
  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    m <- main_models[[c("prices", "nfirms", "nbids")[di]]][["general_pbu"]]
    if (di == 1) {
      coefs_base <- coef_cell(m, "losers")
      ses_base   <- se_cell(m, "losers")
    }
  }

  # Collect all three baselines
  base_coefs <- character(3)
  base_ses   <- character(3)
  base_ns    <- character(3)
  for (di in seq_along(dvs)) {
    m <- main_models[[c("prices", "nfirms", "nbids")[di]]][["general_pbu"]]
    base_coefs[di] <- coef_cell(m, "losers")
    base_ses[di]   <- se_cell(m, "losers")
    base_ns[di]    <- pfmt_int(m$nobs)
  }

  match_lines <- c(match_lines,
    sprintf("\\quad losers & %s \\\\", paste(base_coefs, collapse = " & ")),
    sprintf("\\quad & %s \\\\", paste(base_ses, collapse = " & ")),
    sprintf("\\quad N & %s \\\\", paste(base_ns, collapse = " & "))
  )
}

# Panel B: CEM
match_lines <- c(match_lines,
  "[6pt]",
  "\\textit{Panel B: CEM} & & & \\\\"
)

cem_coefs <- character(3); cem_ses <- character(3); cem_ns <- character(3)
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  if (dv %in% names(cem_models)) {
    m <- cem_models[[dv]]
    cem_coefs[di] <- coef_cell(m, "losers")
    cem_ses[di]   <- se_cell(m, "losers")
    cem_ns[di]    <- pfmt_int(m$nobs)
  } else {
    cem_coefs[di] <- "---"; cem_ses[di] <- ""; cem_ns[di] <- "---"
  }
}

match_lines <- c(match_lines,
  sprintf("\\quad losers & %s \\\\", paste(cem_coefs, collapse = " & ")),
  sprintf("\\quad & %s \\\\", paste(cem_ses, collapse = " & ")),
  sprintf("\\quad N & %s \\\\", paste(cem_ns, collapse = " & "))
)

# Panel C: IPW
match_lines <- c(match_lines,
  "[6pt]",
  "\\textit{Panel C: IPW} & & & \\\\"
)

ipw_coefs <- character(3); ipw_ses <- character(3); ipw_ns <- character(3)
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  if (dv %in% names(ipw_models)) {
    m <- ipw_models[[dv]]
    ipw_coefs[di] <- coef_cell(m, "losers")
    ipw_ses[di]   <- se_cell(m, "losers")
    ipw_ns[di]    <- pfmt_int(m$nobs)
  } else {
    ipw_coefs[di] <- "---"; ipw_ses[di] <- ""; ipw_ns[di] <- "---"
  }
}

match_lines <- c(match_lines,
  sprintf("\\quad losers & %s \\\\", paste(ipw_coefs, collapse = " & ")),
  sprintf("\\quad & %s \\\\", paste(ipw_ses, collapse = " & ")),
  sprintf("\\quad N & %s \\\\", paste(ipw_ns, collapse = " & "))
)

match_lines <- c(match_lines,
  "\\midrule",
  "Item FE & YES & YES & YES \\\\",
  "Year FE & YES & YES & YES \\\\",
  "PBU FE & YES & YES & YES \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Panel A reproduces the General+PBU specification from Tables 2--4.",
  "Panel B uses Coarsened Exact Matching on year, procedure type, item group, and PBU size quartile.",
  "Panel C uses Inverse Probability Weighting based on a logit propensity score model.",
  "Propensity scores trimmed to $[0.01, 0.99]$. Standard errors clustered at the item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(match_lines, file.path(OUT_TAB, "tab_matching.tex"))

# ---- Save models -----------------------------------------------------------
matching_models <- list(
  cem = cem_models,
  ipw = ipw_models,
  cem_result = cem_result,
  pscore_fit = pscore_fit
)
saveRDS(matching_models, "/tmp/p3_matching.rds")
cat("  Matching models saved: /tmp/p3_matching.rds\n")
cat("  Done.\n")
