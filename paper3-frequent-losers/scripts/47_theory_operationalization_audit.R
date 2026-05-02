# ============================================================================
# 47_theory_operationalization_audit.R -- audit the paper's construct versus
# its operational implementation
#
# Goal: make explicit that loser-side concentration is the latent behavioral
# object, while FL is a binary deployment rule. The script consolidates the
# continuous score, the paper rule, and alternative cutoffs into one canonical
# comparison with explicit editorial interpretation fields.
#
# Outputs:
#   output/theory_operationalization/theory_operationalization.csv
#   work/v13/output/tables/tab_theory_operationalization.tex
# ============================================================================

cat("=== 47_theory_operationalization_audit.R ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(data.table)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "theory_operationalization")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)

thr <- fread(file.path(BASE, "output", "threshold_table_q3iqr", "threshold_table_q3iqr.csv"))
strict <- fread(file.path(BASE, "output", "strict_train_threshold", "strict_train_threshold.csv"))

strict_firm <- strict[scope == "firm_al_train_pool"]
strict_item <- strict[scope == "item_2017_2019"]

get_strict_auc <- function(score_name, scope_name) {
  strict[scope == scope_name & score == score_name, auc][1]
}

get_strict_thr <- function() {
  strict[score == "fl_train_binary", threshold_value][1]
}

paper_rule <- thr[construct == "median_plus_1.5_iqr"]
q3_rule    <- thr[construct == "q3_plus_1.5_iqr"]
loose_rule <- thr[construct == "median_plus_1.0_iqr"]
cont_rule  <- thr[construct == "continuous_log_tc"]

res <- rbindlist(list(
  data.table(
    measure = "Continuous log(1 + tenders_count)",
    editorial_role = "Latent construct",
    threshold = NA_real_,
    universe = "Always-loser firms",
    auc_full = cont_rule$auc,
    ci_full_lo = cont_rule$ci_lo,
    ci_full_hi = cont_rule$ci_hi,
    auc_strict = get_strict_auc("log_tc_train", "firm_al_train_pool"),
    auc_item_2017_2019 = get_strict_auc("log_max_tc_train", "item_2017_2019"),
    interpretability = "Ranked score; concept-rich, less deployable",
    information_cost = "Winner + participants only",
    administrative_use = "Prioritization within loser-side strata",
    takeaway = "Best discriminator; theory should attach here, not to a unique cutoff."
  ),
  data.table(
    measure = "Binary FL rule: median + 1.5 IQR",
    editorial_role = "Operational deployment rule",
    threshold = paper_rule$threshold,
    universe = "Always-loser firms",
    auc_full = paper_rule$auc,
    ci_full_lo = paper_rule$ci_lo,
    ci_full_hi = paper_rule$ci_hi,
    auc_strict = get_strict_auc("fl_train_binary", "firm_al_train_pool"),
    auc_item_2017_2019 = get_strict_auc("any_fl_train_binary", "item_2017_2019"),
    interpretability = "Single flag; easiest to deploy and audit",
    information_cost = "Winner + participants only",
    administrative_use = "Binary triage trigger",
    takeaway = "Transparent rule, but materially weaker than the continuous score out of time."
  ),
  data.table(
    measure = "Alternative binary: Q3 + 1.5 IQR",
    editorial_role = "Standard Tukey alternative",
    threshold = q3_rule$threshold,
    universe = "Always-loser firms",
    auc_full = q3_rule$auc,
    ci_full_lo = q3_rule$ci_lo,
    ci_full_hi = q3_rule$ci_hi,
    auc_strict = NA_real_,
    auc_item_2017_2019 = NA_real_,
    interpretability = "Simple binary flag",
    information_cost = "Winner + participants only",
    administrative_use = "Conservative outlier rule",
    takeaway = "Performs worse inside the already-tail always-loser stratum."
  ),
  data.table(
    measure = "Alternative binary: median + 1.0 IQR",
    editorial_role = "Looser deployment rule",
    threshold = loose_rule$threshold,
    universe = "Always-loser firms",
    auc_full = loose_rule$auc,
    ci_full_lo = loose_rule$ci_lo,
    ci_full_hi = loose_rule$ci_hi,
    auc_strict = NA_real_,
    auc_item_2017_2019 = NA_real_,
    interpretability = "Simple binary flag with broader coverage",
    information_cost = "Winner + participants only",
    administrative_use = "Higher-recall triage",
    takeaway = "Catches more firms, but loses discrimination relative to the paper rule."
  )
), fill = TRUE)

res[, strict_train_threshold := get_strict_thr()]
fwrite(res, file.path(OUT, "theory_operationalization.csv"))

fmt_ci <- function(lo, hi) sprintf("[%.3f, %.3f]", lo, hi)
fmt_num <- function(x) ifelse(is.na(x), "---", sprintf("%.3f", x))
fmt_thr <- function(x) ifelse(is.na(x), "---", sprintf("%.1f", x))
esc <- function(x) gsub("_", "\\_", x, fixed = TRUE)

tex <- c(
  "% JLEO-R1: theory versus operationalization audit",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Loser-Side Concentration as Concept, FL as Operational Rule}",
  "\\label{tab:theory_operationalization}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{p{4.0cm}p{3.0cm}cccc}",
  "\\toprule",
  "Measure & Editorial role & Threshold & Full-sample AUC & Strict firm AUC & Strict item AUC \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(res))) {
  rr <- res[i]
  tex <- c(
    tex,
    sprintf("%s & %s & %s & $%.3f$ & %s & %s \\\\",
            esc(rr$measure),
            esc(rr$editorial_role),
            fmt_thr(rr$threshold),
            rr$auc_full,
            ifelse(is.na(rr$auc_strict), "---", paste0("$", fmt_num(rr$auc_strict), "$")),
            ifelse(is.na(rr$auc_item_2017_2019), "---", paste0("$", fmt_num(rr$auc_item_2017_2019), "$")))
  )
}

tex <- c(
  tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  sprintf("\\item \\textit{Notes:} The strict-train threshold estimated only on 2009--2016 is $%.1f$, far below the full-sample paper-rule threshold of $%.1f$. This is precisely why the revised paper should attach theory to the continuous loser-side concentration object and describe the binary FL rule as an administrative compression rather than a theoretically unique boundary.", get_strict_thr(), paper_rule$threshold),
  "\\item \\textit{Source:} \\texttt{scripts/47\\_theory\\_operationalization\\_audit.R}, consolidating \\texttt{53\\_strict\\_train\\_period\\_threshold.R} and \\texttt{54\\_threshold\\_table\\_q3iqr.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_theory_operationalization.tex"))

cat("\n  Theory-operationalization audit summary:\n")
print(res[, .(
  measure, editorial_role, threshold = round(threshold, 2),
  auc_full = round(auc_full, 4),
  auc_strict = round(auc_strict, 4),
  auc_item_2017_2019 = round(auc_item_2017_2019, 4)
)])
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "theory_operationalization.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_theory_operationalization.tex"), "\n", sep = "")
