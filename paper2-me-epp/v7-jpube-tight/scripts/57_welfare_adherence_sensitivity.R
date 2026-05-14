# ----------------------------------------------------------------------
# Sensitivity of the annual welfare aggregate to the SME-only adherence
# rate within Group 65. Builds on the per-auction welfare share already
# estimated in 55_welfare.R; this script does NOT recompute the
# structural objects, only the aggregate scaling.
#
# Anchors from Table~tab:welfare_annual of the manuscript (06_welfare.tex):
#   100% adherence (upper bound):
#     pharma     R$ 73 M / yr
#     non-pharma R$ 55 M / yr
#     total      R$ 128 M / yr (US$ 37 M / yr)
#   43% adherence (baseline, empirical Post-period state-level rate):
#     pharma     R$ 32 M / yr
#     non-pharma R$ 24 M / yr
#     total      R$ 55 M / yr (US$ 16 M / yr)
#
# The two anchors are linear in adherence: 128 × 0.43 = 55. The
# manuscript footnote does not fully expose every multiplicative factor
# behind the upper-bound numbers (likely a p^ref→p_realized conversion
# and/or a completion-rate); rather than re-deriving from primitives
# and risking inconsistency with the published table, this script
# scales linearly off the upper-bound (100% adherence) numbers.
#
# Adherence range walked: 30, 43 (baseline), 55, 70, 85, 100 %.
# Output:
#   output/tables/tab_welfare_adherence_sensitivity.tex
#   output/tables/tab_welfare_adherence_sensitivity.csv
#
# This output is NOT yet \input{} into paper_v5.tex; incorporation is
# deferred until the user decides.
# ----------------------------------------------------------------------

library(data.table)

# -- absolute root (v5-jpube) -----------------------------------------
root <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube"
out_tables <- file.path(root, "output", "tables")
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

# -- upper-bound anchors (100% adherence) from Table tab:welfare_annual
upper_pharma_BRL_M     <- 73
upper_nonpharma_BRL_M  <- 55
brl_per_usd            <- 3.50

# -- adherence grid ----------------------------------------------------
adherence <- c(0.30, 0.43, 0.55, 0.70, 0.85, 1.00)

# -- compute (linear in adherence; consistent with paper's two anchors)
dt <- data.table(adherence = adherence)
dt[, pharma_BRL_M    := round(upper_pharma_BRL_M    * adherence)]
dt[, nonpharma_BRL_M := round(upper_nonpharma_BRL_M * adherence)]
dt[, total_BRL_M     := pharma_BRL_M + nonpharma_BRL_M]
dt[, total_USD_M     := round(total_BRL_M / brl_per_usd)]

# -- consistency check vs paper (must match Table tab:welfare_annual) --
stopifnot(dt[adherence == 1.00, total_BRL_M] == 128)
stopifnot(dt[adherence == 0.43, total_BRL_M] == 55)
stopifnot(dt[adherence == 1.00, pharma_BRL_M] == 73)
stopifnot(dt[adherence == 0.43, pharma_BRL_M] == 31)  # paper rounds to 32
stopifnot(dt[adherence == 1.00, nonpharma_BRL_M] == 55)
stopifnot(dt[adherence == 0.43, nonpharma_BRL_M] == 24)

# -- write CSV ---------------------------------------------------------
csv_path <- file.path(out_tables, "tab_welfare_adherence_sensitivity.csv")
fwrite(dt, csv_path)
cat(sprintf("[ok] csv written: %s\n", csv_path))

# -- format LaTeX table ------------------------------------------------
# threeparttable + booktabs, no tabularray/siunitx (paper convention).
# Baseline column (43%) marked with \textbf{}.
fmt_pct <- function(x) sprintf("%d\\%%", round(x * 100))
fmt_brl <- function(x) sprintf("%d", x)

baseline_idx <- which(dt$adherence == 0.43)
bold <- function(s) sprintf("\\textbf{%s}", s)
mark <- function(vec, idx, fn = fmt_brl) {
  out <- sapply(vec, fn)
  out[idx] <- bold(out[idx])
  out
}

header_cells   <- mark(dt$adherence, baseline_idx, fmt_pct)
pharma_cells   <- mark(dt$pharma_BRL_M, baseline_idx)
np_cells       <- mark(dt$nonpharma_BRL_M, baseline_idx)

# Total rows are bold throughout (including non-baseline cells), with
# baseline kept bold (no double-bold).
fmt_brl_money <- function(x) sprintf("\\textbf{R\\$\\,%d}", x)
fmt_usd_money <- function(x) sprintf("(US\\$\\,%d)", x)
total_brl_cells <- sapply(dt$total_BRL_M, fmt_brl_money)
total_usd_cells <- sapply(dt$total_USD_M, fmt_usd_money)
total_usd_cells[baseline_idx] <- bold(total_usd_cells[baseline_idx])

n_cols <- nrow(dt)
col_align <- paste0("l", strrep("c", n_cols))

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Annual welfare cost: sensitivity to SME-only adherence rate within Group 65.}",
  "\\label{tab:welfare_adherence_sensitivity}",
  "\\small",
  "\\setlength{\\tabcolsep}{4pt}",
  sprintf("\\begin{tabular}{%s}", col_align),
  "\\toprule",
  paste0("Adherence rate", " & ", paste(header_cells, collapse = " & "), " \\\\"),
  "\\midrule",
  paste0("Pharma           (R\\$~M/yr)", " & ", paste(pharma_cells, collapse = " & "), " \\\\"),
  paste0("Non-pharma       (R\\$~M/yr)", " & ", paste(np_cells,     collapse = " & "), " \\\\"),
  "\\addlinespace",
  paste0("\\textbf{Total Group-65}",     " & ", paste(total_brl_cells, collapse = " & "), " \\\\"),
  paste0("",                             " & ", paste(total_usd_cells, collapse = " & "), " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Welfare cost per affected auction held fixed at the $\\lambda = 0.30$ point estimates of Table~\\ref{tab:v3_welfare}: $0.308 \\times p^{\\mathrm{ref}}$ in pharma, $0.204 \\times p^{\\mathrm{ref}}$ in non-pharma. Annual reference outlays at the Post-policy run-rate: pharma R\\$\\,363~M/yr, non-pharma R\\$\\,345~M/yr (own tabulation, 18-month Post window m=698--715, annualized to 12 months). Adherence rate is the share of the Group-65 reference outlay procured under the SME-only rule. Baseline column (43\\%) shown in bold; this rate is the empirical Post-period state-level Group-65 adherence cited in Section~\\ref{sec:institutional}. R\\$/US\\$ at R\\$\\,3.50 (end-2018).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

tex_path <- file.path(out_tables, "tab_welfare_adherence_sensitivity.tex")
writeLines(tex_lines, tex_path)
cat(sprintf("[ok] tex written: %s\n", tex_path))

# -- console summary ---------------------------------------------------
cat("\nAdherence sensitivity (annual welfare cost, Group-65 only, λ=0.30):\n")
print(dt)

cat(sprintf("\nHeadline range across adherence in [30%%, 100%%]:\n"))
cat(sprintf("  R$ %d M / yr  to  R$ %d M / yr\n", min(dt$total_BRL_M), max(dt$total_BRL_M)))
cat(sprintf("  US$ %d M / yr  to  US$ %d M / yr\n", min(dt$total_USD_M), max(dt$total_USD_M)))
cat(sprintf("\nBaseline (43%%):  R$ %d M / yr  (US$ %d M / yr)\n",
            dt[adherence == 0.43, total_BRL_M],
            dt[adherence == 0.43, total_USD_M]))
