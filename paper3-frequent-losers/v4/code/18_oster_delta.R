# ============================================================================
# 18_oster_delta.R — Oster (2019) Coefficient Stability Test
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Computes the Oster (2019) delta: how large would selection on unobservables
# need to be, relative to selection on observables, to explain away the FL
# price coefficient. Complements the Cinelli-Hazlett (2020) RV = 17.5%.
#
# Formula: delta = (beta_full * (R_max - R_tilde)) /
#                  ((beta_short - beta_full) * (R_tilde - R_short))
# where R_max = min(1, 1.3 * R_tilde) per Oster's recommendation.
# ============================================================================

cat("=== 18_oster_delta.R: Oster (2019) coefficient stability ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

# ============================================================================
# Phase 1: Estimate short and full regressions
# ============================================================================

cat("  Phase 1: Estimating regression pairs...\n")

# We compute delta for three samples: full, pregao, convite
samples <- list(
  full    = dt[!is.na(lneg_price)],
  pregao  = dt[!is.na(lneg_price) & pregao == 1L],
  convite = dt[!is.na(lneg_price) & convite == 1L]
)

oster_results <- list()

for (sname in names(samples)) {
  d <- samples[[sname]]
  cat(sprintf("  Sample: %s (N = %s)\n", sname, pfmt_int(nrow(d))))

  # Short model: item + year FE only (no PBU, no controls beyond treatment)
  m_short <- tryCatch(
    feols(lneg_price ~ losers | item_f + year_f,
          data = d, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) NULL
  )

  # Full model: item + year + PBU FE + convite control
  if (sname == "full") {
    m_full <- tryCatch(
      feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
            data = d, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) NULL
    )
  } else {
    # For subsamples, convite/pregao is constant, so just add PBU FE
    m_full <- tryCatch(
      feols(lneg_price ~ losers | item_f + year_f + pbu_f,
            data = d, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) NULL
    )
  }

  if (is.null(m_short) || is.null(m_full)) {
    cat(sprintf("    %s: regression failed, skipping\n", sname))
    next
  }

  beta_short <- coef(m_short)["losers"]
  beta_full  <- coef(m_full)["losers"]

  # Overall R-squared (not within) to approximate Stata areg behavior
  r2_short <- fitstat(m_short, "r2")[[1]]
  r2_full  <- fitstat(m_full, "r2")[[1]]

  # Oster recommended R_max
  r2_max <- min(1, 1.3 * r2_full)

  # Compute delta
  numerator   <- beta_full * (r2_max - r2_full)
  denominator <- (beta_short - beta_full) * (r2_full - r2_short)

  delta <- if (abs(denominator) > 1e-10) numerator / denominator else NA_real_

  # Also compute beta*(delta=1): the coefficient that would survive if
  # unobservables are as important as observables
  # beta_star = beta_full - delta_denom * (1 / (r2_max - r2_full)) ...
  # Actually: beta_star = beta_full - (beta_short - beta_full) * (r2_max - r2_full) / (r2_full - r2_short)
  beta_star <- beta_full - (beta_short - beta_full) * (r2_max - r2_full) /
    max(r2_full - r2_short, 1e-10)

  se_full <- sqrt(vcov(m_full)["losers", "losers"])

  oster_results[[sname]] <- list(
    beta_short = beta_short,
    beta_full  = beta_full,
    se_full    = se_full,
    r2_short   = r2_short,
    r2_full    = r2_full,
    r2_max     = r2_max,
    delta      = delta,
    beta_star  = beta_star,
    n          = nrow(d)
  )

  cat(sprintf("    beta_short=%.4f, beta_full=%.4f\n", beta_short, beta_full))
  cat(sprintf("    R2_short=%.4f, R2_full=%.4f, R2_max=%.4f\n", r2_short, r2_full, r2_max))
  cat(sprintf("    Oster delta = %.2f (|delta|>1 → robust)\n", delta))
  cat(sprintf("    beta*(delta=1) = %.4f\n", beta_star))
}

# ============================================================================
# Phase 2: Write tab_oster_delta.tex
# ============================================================================

cat("  Phase 2: Writing tab_oster_delta.tex...\n")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Oster (2019) Coefficient Stability Bounds}",
  "\\label{tab:oster_delta}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}", "\\toprule",
  " & Full sample & Preg\\~{a}o & Convite \\\\", "\\midrule"
)

# Beta short
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r)) "---" else pfmt(r$beta_short, 4)
})
lines <- c(lines, sprintf("$\\hat{\\beta}_{\\text{short}}$ (item + year FE) & %s \\\\",
                           paste(vals, collapse = " & ")))

# Beta full
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r)) "---" else pfmt(r$beta_full, 4)
})
lines <- c(lines, sprintf("$\\hat{\\beta}_{\\text{full}}$ (+ PBU FE) & %s \\\\",
                           paste(vals, collapse = " & ")))

# R2 short
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r)) "---" else pfmt(r$r2_short, 4)
})
lines <- c(lines, sprintf("$\\tilde{R}^2_{\\text{short}}$ & %s \\\\",
                           paste(vals, collapse = " & ")))

# R2 full
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r)) "---" else pfmt(r$r2_full, 4)
})
lines <- c(lines, sprintf("$\\tilde{R}^2_{\\text{full}}$ & %s \\\\",
                           paste(vals, collapse = " & ")))

# R2 max
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r)) "---" else pfmt(r$r2_max, 4)
})
lines <- c(lines, sprintf("$R^2_{\\max} = \\min(1, 1.3 \\tilde{R}^2)$ & %s \\\\",
                           paste(vals, collapse = " & ")))

lines <- c(lines, "\\midrule")

# Delta
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r) || is.na(r$delta)) "---" else pfmt(r$delta, 2)
})
lines <- c(lines, sprintf("$\\hat{\\delta}$ (Oster bound) & %s \\\\",
                           paste(vals, collapse = " & ")))

# Beta star
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r)) "---" else pfmt(r$beta_star, 4)
})
lines <- c(lines, sprintf("$\\beta^*(\\delta = 1)$ & %s \\\\",
                           paste(vals, collapse = " & ")))

# N
vals <- sapply(c("full", "pregao", "convite"), function(s) {
  r <- oster_results[[s]]
  if (is.null(r)) "---" else pfmt_int(r$n)
})
lines <- c(lines, sprintf("Observations & %s \\\\",
                           paste(vals, collapse = " & ")))

lines <- c(lines,
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} $\\hat{\\delta}$ is the degree of selection on",
  "unobservables (relative to observables) required to drive $\\hat{\\beta}$ to zero",
  "\\citep{oster2019unobservable}. $|\\hat{\\delta}| > 1$ indicates robustness:",
  "unobservables would need to be more important than observables to explain",
  "the coefficient. $\\beta^*(\\delta = 1)$ is the bias-adjusted coefficient",
  "assuming equal selection. $R^2_{\\max} = 1.3 \\tilde{R}^2$ following",
  "Oster's recommended bound. Short model: item + year FE. Full model adds",
  "PBU FE (and convite control for full sample).",
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")

writeLines(lines, file.path(OUT_TAB, "tab_oster_delta.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_oster_delta.tex"), "\n")

# ============================================================================
# Save
# ============================================================================

saveRDS(oster_results, OSTER_CACHE_V4)
cat("  Results saved:", OSTER_CACHE_V4, "\n")
cat("  Done.\n")
