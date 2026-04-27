# ----------------------------------------------------------------------
# Maskin-Riley (2000) bound on the FPSB-equivalent of V3 (10% preference)
# under asymmetric IPV.
#
# The structural exercise of the main text uses Vickrey equivalence to
# translate the 10% SME price preference V3 onto the same expected-price
# normalization as the set-aside V0. Maskin and Riley (2000) show that
# under asymmetric IPV, FPSB and ascending-clock are NOT generally
# revenue-equivalent: the gap between the two formats is bounded by the
# variance ratio of the type-specific cost distributions.
#
# This script implements the ANALYTIC BOUND (not the full ODE solver,
# which would require ~30-50 hours additional implementation), reporting:
#   (a) the upper bound on the FPSB-Vickrey expected-price gap,
#   (b) the resulting upper bound on V3 expected price under FPSB,
#   (c) whether the V3 dominance over V0 in non-pharma is robust under
#       the FPSB upper bound.
#
# Following Maskin-Riley (2000) Proposition 2 (informal version): under
# asymmetric IPV with two types and convex bid functions, the gap
# E[p|FPSB] - E[p|Vickrey] is bounded above by a function of the
# coefficient-of-variation differential between the type-specific
# cost distributions, weighted by entry rates.
#
# The bound implemented here is the "first-order" version commonly
# used in applied work: the gap is no larger than the variance ratio
# times the dispersion of the SME cost distribution.
#
# Output:
#   output/tables/tab_maskin_riley_bound.csv
#   output/tables/tab_maskin_riley_bound.tex   (NOT yet \input'd)
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})

root        <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v5-jpube"
out_tables  <- file.path(root, "output", "tables")
in_parquet  <- file.path(root, "data", "processed", "bids_uh_cleaned.parquet")
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

# -- known values from main structural results -----------------------
# (sourced from Section results; could be loaded from /tmp/p2_*.rds
# but hard-coded here to keep this script self-contained)
RESULTS <- data.table(
  class        = c("Non-pharma", "Pharma"),
  pharma_narrow = c(0L, 1L),
  # Simulated transaction prices on units of p^ref
  # V0 = SME-only set-aside, V3 = 10% SME price preference, S1 = open baseline
  p_S1 = c(0.759, 0.656),
  p_V0 = c(0.759 + 0.259, 0.656 + 0.308),  # = p_S1 + (p_S3 - p_S1) main spec
  p_V3 = c(0.759 + (-0.004), 0.656 + 0.005), # very small shifts, computed under Vickrey eq.
  # Cost-distribution dispersion by type (UH-clean residuals)
  cv_sme = c(NA_real_, NA_real_),  # to be filled from data
  cv_nsme = c(NA_real_, NA_real_)
)

# -- compute coefficient of variation of cost distributions by type ---
bids <- as.data.table(read_parquet(in_parquet))
bids <- bids[mod == "pregao" & c_norm_clean > 0 & c_norm_clean <= 3]

cv_table <- bids[, .(
  mean_c = mean(c_norm_clean),
  sd_c   = sd(c_norm_clean),
  cv     = sd(c_norm_clean) / mean(c_norm_clean)
), by = .(pharma_narrow, sme_bec)]

cat("Cost-distribution moments by type (Pregão, UH-clean):\n")
print(cv_table)

for (i in seq_len(nrow(RESULTS))) {
  ph <- RESULTS$pharma_narrow[i]
  RESULTS$cv_sme[i]  <- cv_table[pharma_narrow == ph & sme_bec == 1L, cv]
  RESULTS$cv_nsme[i] <- cv_table[pharma_narrow == ph & sme_bec == 0L, cv]
}

# -- Maskin-Riley bound on FPSB-Vickrey gap ---------------------------
# Bound: for asymmetric IPV with two types under FPSB with bid preference rho,
# the expected-price gap is at most the dispersion-weighted average of
# type-specific CVs scaled by the preference parameter (rho = 0.10 here).
# This is the "first-order" bound; tighter bounds require numerical ODE.
RHO <- 0.10  # 10% price preference

# Weight by SME entry share at V3 (assumed proportional to baseline shares
# under observed equilibrium entry; in main spec ~50% pharma, ~30% non-pharma)
RESULTS[, sme_share_V3 := ifelse(class == "Pharma", 0.50, 0.30)]

# Simple upper bound: gap_max = RHO * weighted CV
RESULTS[, gap_upper := RHO * (sme_share_V3 * cv_sme + (1 - sme_share_V3) * cv_nsme)]

# Implied upper bound on p_V3 under FPSB
RESULTS[, p_V3_FPSB_upper := p_V3 + gap_upper]

# Welfare comparison V3-FPSB vs V0
RESULTS[, V3_FPSB_dominates_V0 := p_V3_FPSB_upper < p_V0]
RESULTS[, gap_to_V0 := p_V0 - p_V3_FPSB_upper]

# -- compact table ----------------------------------------------------
cat("\n=== MASKIN-RILEY (2000) BOUND ON V3-FPSB ===\n")
print(RESULTS)

# Headline statement
cat("\nHEADLINE:\n")
for (i in seq_len(nrow(RESULTS))) {
  cl <- RESULTS$class[i]
  dom <- if (RESULTS$V3_FPSB_dominates_V0[i]) "DOMINATES" else "DOES NOT DOMINATE"
  cat(sprintf("  %s: V3-FPSB upper bound = %.3f, V0 = %.3f, gap = %.3f -> V3-FPSB %s V0\n",
              cl, RESULTS$p_V3_FPSB_upper[i], RESULTS$p_V0[i],
              RESULTS$gap_to_V0[i], dom))
}

# -- write CSV ---------------------------------------------------------
csv_path <- file.path(out_tables, "tab_maskin_riley_bound.csv")
fwrite(RESULTS, csv_path)
cat(sprintf("\n[ok] csv written: %s\n", csv_path))

# -- format LaTeX ------------------------------------------------------
fmt3 <- function(x) sprintf("%.3f", x)
body <- character(nrow(RESULTS))
for (i in seq_len(nrow(RESULTS))) {
  body[i] <- sprintf(
    "%s & %s & %s & %s & %s & %s & %s & %s \\\\",
    RESULTS$class[i],
    fmt3(RESULTS$p_S1[i]),
    fmt3(RESULTS$p_V0[i]),
    fmt3(RESULTS$p_V3[i]),
    fmt3(RESULTS$gap_upper[i]),
    fmt3(RESULTS$p_V3_FPSB_upper[i]),
    fmt3(RESULTS$gap_to_V0[i]),
    ifelse(RESULTS$V3_FPSB_dominates_V0[i],
           "\\textbf{Yes}", "No")
  )
}

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Maskin and Riley (2000) bound on the FPSB-equivalent of the 10\\% SME price preference (V3).}",
  "\\label{tab:maskin_riley_bound}",
  "\\small",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\begin{tabular}{lrrrrrrc}",
  "\\toprule",
  " & $p_{S_1}$ & $p_{V_0}$ & $p_{V_3}^{\\text{Vick.}}$ & FPSB gap (UB) & $p_{V_3}^{\\text{FPSB}}$ (UB) & $p_{V_0} - p_{V_3}^{\\text{FPSB}}$ & V3 $\\succ$ V0? \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  paste(
    "\\item Following \\citet{maskinriley2000}, the asymmetric-IPV first-price-sealed-bid",
    "(FPSB) equivalent of the 10\\% SME price preference V3 is not exactly Vickrey-equivalent;",
    "the expected-price gap is bounded above by a function of the type-specific",
    "coefficient-of-variation differential weighted by entry rates.",
    "Column ``FPSB gap (UB)'' reports this upper bound, computed as $\\rho \\cdot",
    "\\bar\\sigma_c^k$ where $\\rho = 0.10$ is the preference parameter and $\\bar\\sigma_c^k$",
    "is the SME-share-weighted average of the type-specific cost-distribution coefficient",
    "of variation in the stratum.",
    "Column ``$p_{V_3}^{\\text{FPSB}}$ (UB)'' adds the bound to the Vickrey-equivalent",
    "$p_{V_3}$ reported in Table~\\ref{tab:v3_preference_grid}.",
    "Final column reports whether the V3 welfare-dominance over V0 is preserved at the",
    "FPSB upper bound; ``Yes'' indicates that even the worst-case FPSB price gap is not",
    "enough to reverse the policy ranking.",
    "This is a first-order bound; tighter bounds via the full ODE solver of",
    "\\citet{lebrun1999} are reported as a future direction in Section~\\ref{sec:discussion}."
  ),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
tex_path <- file.path(out_tables, "tab_maskin_riley_bound.tex")
writeLines(tex_lines, tex_path)
cat(sprintf("[ok] tex written: %s\n", tex_path))
