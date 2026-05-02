# ============================================================================
# 48_stratum_scope_reframe.R -- make the scope of detection performance
# explicit and reproducible
#
# Goal: stop the paper from sounding like a general cartelist detector. This
# script lines up the three relevant validation objects: within-stratum
# cobidder prioritization, direct-defendant failure, and strict temporal
# generalization.
#
# Outputs:
#   output/stratum_scope/stratum_scope_metrics.csv
#   work/v13/output/tables/tab_stratum_scope.tex
# ============================================================================

cat("=== 48_stratum_scope_reframe.R ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(data.table)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "stratum_scope")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)

thr <- fread(file.path(BASE, "output", "threshold_table_q3iqr", "threshold_table_q3iqr.csv"))
direct <- fread(file.path(BASE, "output", "auc_direct_cade", "auc_direct_cade.csv"))
strict <- fread(file.path(BASE, "output", "strict_train_threshold", "strict_train_threshold.csv"))
leak <- fread(file.path(BASE, "output", "leakage_audit_d3", "leakage_audit_d3.csv"))

paper_rule <- thr[construct == "median_plus_1.5_iqr"]
cont_rule  <- thr[construct == "continuous_log_tc"]
direct_bin <- direct[sample == "all_BEC_firms" & label == "all_direct_CADE" & score == "is_fl"]
direct_tc  <- direct[sample == "all_BEC_firms" & label == "all_direct_CADE" & score == "tenders_count"]
strict_firm <- strict[scope == "firm_al_train_pool" & score == "fl_train_binary"]
strict_item <- strict[scope == "item_2017_2019" & score == "log_max_tc_train"]
strict_item_bin <- strict[scope == "item_2017_2019" & score == "any_fl_train_binary"]
direct_item_temp <- leak[audit == "3_temporal_holdout" & label == "any_direct"]

res <- rbindlist(list(
  data.table(
    row_id = 1L,
    screen = "Binary FL rule",
    universe = "Always-loser firms",
    positive_class = "CADE co-bidders inside always-loser stratum",
    empirical_question = "Can a participation-only flag prioritize risk within the loser-side stratum?",
    metric = "AUC",
    auc = paper_rule$auc,
    ci_lo = paper_rule$ci_lo,
    ci_hi = paper_rule$ci_hi,
    n_pos = 193L,
    n_total = 16843L,
    headline_reading = "Within-stratum prioritization only"
  ),
  data.table(
    row_id = 2L,
    screen = "Continuous log(1 + tenders_count)",
    universe = "Always-loser firms",
    positive_class = "CADE co-bidders inside always-loser stratum",
    empirical_question = "How informative is the latent loser-side concentration score before binarization?",
    metric = "AUC",
    auc = cont_rule$auc,
    ci_lo = cont_rule$ci_lo,
    ci_hi = cont_rule$ci_hi,
    n_pos = 193L,
    n_total = 16843L,
    headline_reading = "Best within-stratum ranking object"
  ),
  data.table(
    row_id = 3L,
    screen = "Binary FL rule",
    universe = "All BEC firms",
    positive_class = "Direct CADE defendants",
    empirical_question = "Does the screen detect cartel defendants in general?",
    metric = "AUC",
    auc = direct_bin$auc,
    ci_lo = direct_bin$ci_lo,
    ci_hi = direct_bin$ci_hi,
    n_pos = direct_bin$n_pos,
    n_total = direct_bin$n_total,
    headline_reading = "No; performance is at chance"
  ),
  data.table(
    row_id = 4L,
    screen = "Participation count",
    universe = "All BEC firms",
    positive_class = "Direct CADE defendants",
    empirical_question = "Does simple bidding intensity recover winner-heavy defendants?",
    metric = "AUC",
    auc = direct_tc$auc,
    ci_lo = direct_tc$ci_lo,
    ci_hi = direct_tc$ci_hi,
    n_pos = direct_tc$n_pos,
    n_total = direct_tc$n_total,
    headline_reading = "No; loser-side scores miss winner-heavy defendants"
  ),
  data.table(
    row_id = 5L,
    screen = "Binary FL rule frozen on 2009-2016",
    universe = "Always-losers as of 2009-2016",
    positive_class = "CADE co-bidders",
    empirical_question = "What survives when the threshold is trained only in the pre-2017 window?",
    metric = "AUC",
    auc = strict_firm$auc,
    ci_lo = strict_firm$ci_lo,
    ci_hi = strict_firm$ci_hi,
    n_pos = strict_firm$n_pos,
    n_total = strict_firm$n_total,
    headline_reading = "Much weaker than pooled within-stratum performance"
  ),
  data.table(
    row_id = 6L,
    screen = "Continuous item score trained on 2009-2016",
    universe = "Items in 2017-2019",
    positive_class = "Items containing CADE co-bidders",
    empirical_question = "Does participation intensity generalize prospectively at the item level?",
    metric = "AUC",
    auc = strict_item$auc,
    ci_lo = strict_item$ci_lo,
    ci_hi = strict_item$ci_hi,
    n_pos = strict_item$n_pos,
    n_total = strict_item$n_total,
    headline_reading = "Some prospective generalization, but narrower and weaker"
  ),
  data.table(
    row_id = 7L,
    screen = "Binary item flag frozen on 2009-2016",
    universe = "Items in 2017-2019",
    positive_class = "Items containing CADE co-bidders",
    empirical_question = "Does the binary deployment rule remain strong out of time?",
    metric = "AUC",
    auc = strict_item_bin$auc,
    ci_lo = strict_item_bin$ci_lo,
    ci_hi = strict_item_bin$ci_hi,
    n_pos = strict_item_bin$n_pos,
    n_total = strict_item_bin$n_total,
    headline_reading = "No; binary holdout performance is weak"
  ),
  data.table(
    row_id = 8L,
    screen = "Continuous item score trained on 2009-2016",
    universe = "Items in 2017-2019",
    positive_class = "Items containing direct CADE defendants",
    empirical_question = "Does prospective item-level scoring recover direct defendants?",
    metric = "AUC",
    auc = direct_item_temp$auc,
    ci_lo = direct_item_temp$ci_lo,
    ci_hi = direct_item_temp$ci_hi,
    n_pos = direct_item_temp$n_pos,
    n_total = strict_item$n_total,
    headline_reading = "No; direct-defendant scope failure remains"
  )
), fill = TRUE)

setorder(res, row_id)
fwrite(res, file.path(OUT, "stratum_scope_metrics.csv"))

fmt_ci <- function(lo, hi) sprintf("[%.3f, %.3f]", lo, hi)
tex <- c(
  "% JLEO-R1: scope of detection performance made explicit",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Scope of Detection Performance}",
  "\\label{tab:stratum_scope}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{p{2.7cm}p{3.1cm}p{5.6cm}cc}",
  "\\toprule",
  "Universe & Positive class & Empirical question & AUC & 95\\% CI \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(res))) {
  rr <- res[i]
  tex <- c(
    tex,
    sprintf("%s & %s & %s & $%.3f$ & $%s$ \\\\",
            rr$universe,
            rr$positive_class,
            rr$empirical_question,
            rr$auc,
            fmt_ci(rr$ci_lo, rr$ci_hi))
  )
}

tex <- c(
  tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} The same participation-based construct answers different empirical questions on different universes. High AUC in the always-loser pool does not transport to the universe of direct CADE defendants. The revised manuscript should therefore front-page ``within-stratum prioritization'' rather than ``cartelist detection'' as the correct headline.",
  "\\item \\textit{Source:} \\texttt{scripts/48\\_stratum\\_scope\\_reframe.R}, consolidating outputs from \\texttt{33}, \\texttt{40}, \\texttt{53}, and \\texttt{54}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_stratum_scope.tex"))

cat("\n  Stratum-scope summary:\n")
print(res[, .(universe, positive_class, auc = round(auc, 4), headline_reading)])
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "stratum_scope_metrics.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_stratum_scope.tex"), "\n", sep = "")
