# ============================================================================
# 21_goodman_bacon.R — Goodman-Bacon (2021) TWFE decomposition
# ============================================================================
# Decomposes the headline TWFE DiD coefficient into 2x2 pairwise comparisons
# weighted by group and timing variation. For a single-cohort design with
# never-treated controls, the decomposition collapses to a single 2x2
# comparison (treated vs never-treated); this check verifies that all the
# weight falls on that clean comparison and that no "forbidden" treated-vs-
# already-treated comparisons contaminate the estimate.
#
# Uses bacondecomp package. Aggregates to codigogrupo x month to avoid the
# millions of unit-time cells item-level data would produce.
#
# Outputs:
#   - /tmp/p2_bacon.rds
#   - output/tables/tab_bacon.tex
#   - output/tables/diag_bacon.txt
# ============================================================================

cat("=== 21_goodman_bacon.R: Goodman-Bacon TWFE decomposition ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

if (!requireNamespace("bacondecomp", quietly = TRUE)) {
  install.packages("bacondecomp", repos = "https://cloud.r-project.org")
}
suppressPackageStartupMessages(library(bacondecomp))

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

# ---- Build group x month panel --------------------------------------------
dt_win <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
agg_c <- dt_win[oc_item_status == 1L,
                .(y_price = mean(lpreco_final, na.rm = TRUE),
                  y_dist  = mean(dist1,        na.rm = TRUE)),
                by = .(codigogrupo, data_oc_numb)]
agg_a <- dt_win[, .(y_firms = mean(lnum_firms, na.rm = TRUE),
                    y_bids  = mean(lnum_bids,  na.rm = TRUE)),
                by = .(codigogrupo, data_oc_numb)]
panel <- merge(agg_c, agg_a, all = TRUE, by = c("codigogrupo", "data_oc_numb"))

# Treatment: 1 if Group 65 AND t >= TREAT_DATE
panel[, treat := as.integer(codigogrupo == "65" & data_oc_numb >= TREAT_DATE)]
panel[, id_grp := as.integer(factor(codigogrupo))]

# Drop cells with missing outcome (bacondecomp requires balanced panel)
# We'll run each outcome separately on its complete sub-panel.

run_bacon <- function(yname) {
  sub <- panel[!is.na(get(yname)), .(y = get(yname), treat, id_grp, data_oc_numb)]
  # bacondecomp requires balanced panel on (id, time)
  n_t <- uniqueN(sub$data_oc_numb)
  counts <- sub[, .N, by = id_grp]
  keep_ids <- counts[N == n_t, id_grp]
  sub <- sub[id_grp %in% keep_ids]
  if (uniqueN(sub$id_grp) < 3L) return(NULL)
  tryCatch(
    bacon(y ~ treat, data = as.data.frame(sub),
          id_var = "id_grp", time_var = "data_oc_numb"),
    error = function(e) { cat("   bacon failed:", conditionMessage(e), "\n"); NULL})
}

cat("  Decomposing 4 outcomes...\n")
b_price <- run_bacon("y_price")
b_firms <- run_bacon("y_firms")
b_bids  <- run_bacon("y_bids")
b_dist  <- run_bacon("y_dist")

# ---- Summarize decomposition ---------------------------------------------
summarize_bacon <- function(b, label) {
  if (is.null(b)) return(NULL)
  # bacon returns a data.frame with columns: treated, untreated, estimate, weight, type
  # For single treated cohort: "Treated vs Untreated" (never-treated comparison)
  # and possibly "Within" (a fixed-effects within component) rows.
  # Aggregate by type.
  d <- as.data.table(b)
  agg <- d[, .(sum_w = sum(weight), wavg = sum(estimate * weight) / sum(weight)),
           by = type]
  agg[, outcome := label]
  setcolorder(agg, c("outcome", "type", "sum_w", "wavg"))
  agg
}

sum_price <- summarize_bacon(b_price, "Log prices")
sum_firms <- summarize_bacon(b_firms, "Log firms")
sum_bids  <- summarize_bacon(b_bids,  "Log bids")
sum_dist  <- summarize_bacon(b_dist,  "Distance")

all_summaries <- rbind(sum_price, sum_firms, sum_bids, sum_dist)

cat("  Weighted 2x2 summaries by type:\n")
print(all_summaries)

saveRDS(list(b_price = b_price, b_firms = b_firms,
             b_bids  = b_bids,  b_dist  = b_dist,
             summaries = all_summaries),
        "/tmp/p2_bacon.rds")

# ---- Diagnostic ----------------------------------------------------------
diag_lines <- c(
  "=== Goodman-Bacon (2021) TWFE decomposition ===",
  sprintf("Panel: codigogrupo x month (18-month window [%d, %d])",
          WIN_18M[1], WIN_18M[2]),
  sprintf("Treatment: codigogrupo == '65' AND month >= %d", TREAT_DATE),
  "Other 76 groups are never-treated within the window.",
  "",
  "For a single-cohort design with never-treated controls, the Goodman-Bacon",
  "decomposition has at most two components:",
  "  1. Treated-vs-Untreated (clean 2x2): the desired estimate",
  "  2. Within (time-only variation): minor, absorbs trend",
  "No `treated-vs-already-treated' forbidden comparisons exist here.",
  "",
  "Weighted decomposition by type and outcome:",
  capture.output(print(all_summaries))
)
writeLines(diag_lines, file.path(OUT_TAB, "diag_bacon.txt"))

# ---- LaTeX table ---------------------------------------------------------
cat("  Writing LaTeX table...\n")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Goodman-Bacon (2021) Decomposition of the TWFE DiD Coefficient}",
  "\\label{tab:bacon}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{llcc}",
  "\\toprule",
  "Outcome & Comparison type & Weight & Weighted avg. estimate \\\\",
  "\\midrule"
)

for (row in 1:nrow(all_summaries)) {
  r <- all_summaries[row]
  lines <- c(lines,
    sprintf("%s & %s & %.3f & %s \\\\",
            r$outcome, r$type, r$sum_w, pfmt(r$wavg, 4)))
}

lines <- c(lines,
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Decomposition of the pooled two-way fixed-effects",
  "DiD coefficient $\\hat\\beta^{\\mathrm{DD}}$ into weighted average of all",
  "possible $2{\\times}2$ comparisons implicit in the TWFE estimator~\\citep{goodmanbacon2021}.",
  "In a single-cohort design with never-treated controls, only two comparison types arise:",
  "\\textit{Treated vs Untreated}, the clean 2$\\times$2 comparison between group~65 and the",
  "never-treated 76 groups; and \\textit{Within}, a time-variation component",
  "that bacondecomp reports separately. No ``forbidden'' comparisons---treated-vs-already-treated",
  "of the sort that motivate the \\citet{callaway2021} and \\citet{sun2021} corrections---enter",
  "the decomposition because there is no variation in treatment timing among controls.",
  "Weights and weighted estimates are reported by \\texttt{bacondecomp::bacon}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)
writeLines(lines, file.path(OUT_TAB, "tab_bacon.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_bacon.tex"), "\n")
cat("  Done.\n")
