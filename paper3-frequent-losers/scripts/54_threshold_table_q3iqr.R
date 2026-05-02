# 54_threshold_table_q3iqr.R -- tabulate threshold sensitivity, explicitly
# including the standard Tukey Q3 + 1.5*IQR rule requested by the referee
#
# Outputs:
#   output/threshold_table_q3iqr/threshold_table_q3iqr.csv
#   work/v13/output/tables/tab_threshold_q3iqr.tex

cat("=== 54_threshold_table_q3iqr.R ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(data.table)
  library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "threshold_table_q3iqr")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)

drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

fp <- as.data.table(dbGetQuery(con, sprintf("
  SELECT
    LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    CAST(\"tenders_count\" AS DOUBLE) AS tenders_count,
    CAST(\"always_loser\" AS INTEGER) AS always_loser
  FROM read_parquet('%s')
", file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet"))))

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

al <- fp[always_loser == 1L]
al[, is_cobid := as.integer(firm_code %in% cobid_codes)]
al[, log_tc := log1p(tenders_count)]

median_tc <- median(al$tenders_count)
iqr_tc    <- IQR(al$tenders_count)
q3_tc     <- as.numeric(quantile(al$tenders_count, 0.75))

rules <- list(
  list(
    key = "median_plus_1.0_iqr",
    label = "Median + 1.0 IQR",
    threshold = median_tc + 1.0 * iqr_tc
  ),
  list(
    key = "median_plus_1.5_iqr",
    label = "Median + 1.5 IQR (paper rule)",
    threshold = median_tc + 1.5 * iqr_tc
  ),
  list(
    key = "q3_plus_1.5_iqr",
    label = "Q3 + 1.5 IQR (standard Tukey)",
    threshold = q3_tc + 1.5 * iqr_tc
  ),
  list(
    key = "median_plus_2.0_iqr",
    label = "Median + 2.0 IQR",
    threshold = median_tc + 2.0 * iqr_tc
  )
)

calc_auc <- function(label, score) {
  if (length(unique(score)) < 2L || sum(label) < 5L) {
    return(list(auc = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_))
  }
  r <- pROC::roc(label, score, quiet = TRUE)
  ci <- as.numeric(pROC::ci.auc(r))
  list(auc = as.numeric(pROC::auc(r)), ci_lo = ci[1], ci_hi = ci[3])
}

rows <- list()
for (rule in rules) {
  flag <- as.integer(al$tenders_count > rule$threshold)
  auc <- calc_auc(al$is_cobid, flag)
  n_flagged <- sum(flag == 1L)
  rows[[length(rows) + 1L]] <- data.table(
    construct = rule$key,
    label = rule$label,
    family = "binary_threshold",
    threshold = rule$threshold,
    n_flagged = n_flagged,
    flagged_share = n_flagged / nrow(al),
    precision_flagged = if (n_flagged > 0) mean(al$is_cobid[flag == 1L]) else NA_real_,
    recall_flagged = if (sum(al$is_cobid) > 0) sum(al$is_cobid[flag == 1L]) / sum(al$is_cobid) else NA_real_,
    auc = auc$auc,
    ci_lo = auc$ci_lo,
    ci_hi = auc$ci_hi,
    info_cost = "winner + participants",
    interpretability = "single binary trigger"
  )
}

auc_cont <- calc_auc(al$is_cobid, al$log_tc)
rows[[length(rows) + 1L]] <- data.table(
  construct = "continuous_log_tc",
  label = "Continuous log(1 + tenders_count)",
  family = "continuous",
  threshold = NA_real_,
  n_flagged = NA_integer_,
  flagged_share = NA_real_,
  precision_flagged = NA_real_,
  recall_flagged = NA_real_,
  auc = auc_cont$auc,
  ci_lo = auc_cont$ci_lo,
  ci_hi = auc_cont$ci_hi,
  info_cost = "winner + participants",
  interpretability = "ranked continuous score"
)

res <- rbindlist(rows, fill = TRUE)
fwrite(res, file.path(OUT, "threshold_table_q3iqr.csv"))

fmt_ci <- function(lo, hi) sprintf("[%.3f, %.3f]", lo, hi)
thr_lab <- function(x) ifelse(is.na(x), "---", sprintf("$%.1f$", x))
ppv_lab <- function(x) ifelse(is.na(x), "---", sprintf("$%.3f$", x))
shr_lab <- function(x) ifelse(is.na(x), "---", sprintf("$%.3f$", x))
esc <- function(x) gsub("_", "\\_", x, fixed = TRUE)

tex <- c(
  "% JLEO-R1: cutoff sensitivity table including Q3 + 1.5 IQR",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Threshold Sensitivity of the Loser-Side Concentration Screen}",
  "\\label{tab:threshold_q3iqr}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "Construct & Threshold & Flagged share & Precision among flagged & AUC & 95\\% CI \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(res))) {
  rr <- res[i]
  tex <- c(
    tex,
    sprintf("%s & %s & %s & %s & $%.3f$ & $%s$ \\\\",
            esc(rr$label),
            thr_lab(rr$threshold),
            shr_lab(rr$flagged_share),
            ppv_lab(rr$precision_flagged),
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
  "\\item \\textit{Notes:} The table holds fixed the always-loser universe and varies only the operational rule used to discretize the underlying participation-count distribution. The referee-requested $Q_3 + 1.5\\times\\mathrm{IQR}$ rule is reported explicitly rather than only in figures. The continuous score is included because the paper's theoretical object is loser-side concentration, while the binary FL rule is an administrative deployment choice.",
  "\\item \\textit{Source:} \\texttt{scripts/54\\_threshold\\_table\\_q3iqr.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_threshold_q3iqr.tex"))

cat("\n  Threshold sensitivity summary:\n")
print(res[, .(
  label,
  threshold = round(threshold, 2),
  n_flagged,
  flagged_share = round(flagged_share, 3),
  auc = round(auc, 4),
  ci = sprintf("[%.3f, %.3f]", ci_lo, ci_hi)
)])
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "threshold_table_q3iqr.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_threshold_q3iqr.tex"), "\n", sep = "")

dbDisconnect(con, shutdown = TRUE)
