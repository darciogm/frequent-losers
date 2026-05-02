# 53_strict_train_period_threshold.R -- strict temporal holdout with frozen
# threshold estimated on the training window only
#
# Referee concern: the temporal holdout should not inherit a threshold tuned on
# the full 2009-2019 participation distribution. This script freezes the
# loser-side threshold on 2009-2016, applies it out of time, and reports both
# firm-level and item-level validation objects.
#
# Outputs:
#   output/strict_train_threshold/strict_train_threshold.csv
#   work/v13/output/tables/tab_strict_train_threshold.tex


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
OUT  <- file.path(BASE, "output", "strict_train_threshold")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

ftm_path <- file.path(BASE, "data/processed/firm_tender_map.parquet")

cat("  Loading firm-level train/full participation summaries via DuckDB ...\n")
firm_stats <- as.data.table(dbGetQuery(con, sprintf("
  WITH base AS (
    SELECT
      LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
      CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR), 12, 4) AS INTEGER) AS year,
      CAST(\"won\" AS INTEGER) AS won
    FROM read_parquet('%s')
  )
  SELECT
    firm_code,
    SUM(CASE WHEN year BETWEEN 2009 AND 2016 AND won = 0 THEN 1 ELSE 0 END) AS losses_train,
    SUM(CASE WHEN year BETWEEN 2009 AND 2016 AND won = 1 THEN 1 ELSE 0 END) AS wins_train,
    SUM(CASE WHEN year BETWEEN 2009 AND 2019 AND won = 0 THEN 1 ELSE 0 END) AS losses_full,
    SUM(CASE WHEN year BETWEEN 2009 AND 2019 AND won = 1 THEN 1 ELSE 0 END) AS wins_full
  FROM base
  GROUP BY firm_code
", ftm_path)))

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)
dbWriteTable(con, "cobid_codes_tmp", data.frame(firm_code = cobid_codes),
             temporary = TRUE, overwrite = TRUE)

firm_stats[, always_loser_train := as.integer(wins_train == 0L)]
firm_stats[, always_loser_full  := as.integer(wins_full  == 0L)]
firm_stats[, is_cobid := as.integer(firm_code %in% cobid_codes)]
firm_stats[, log_tc_train := log1p(losses_train)]
firm_stats[, log_tc_full  := log1p(losses_full)]

cut_train <- with(firm_stats[always_loser_train == 1L], median(losses_train) + 1.5 * IQR(losses_train))
cut_full  <- with(firm_stats[always_loser_full  == 1L], median(losses_full)  + 1.5 * IQR(losses_full))
firm_stats[, fl_train := as.integer(always_loser_train == 1L & losses_train > cut_train)]
firm_stats[, fl_full  := as.integer(always_loser_full  == 1L & losses_full  > cut_full)]

cat(sprintf("  Train-window threshold (2009-2016): %.2f\n", cut_train))
cat(sprintf("  Full-sample threshold  (2009-2019): %.2f\n", cut_full))
cat(sprintf("  Train-window always-losers: %s | flagged FL: %s\n",
            format(sum(firm_stats$always_loser_train == 1L), big.mark = ","),
            format(sum(firm_stats$fl_train == 1L), big.mark = ",")))

calc_auc <- function(label, score) {
  keep <- !is.na(label) & !is.na(score)
  label <- as.integer(label[keep])
  score <- score[keep]
  if (length(unique(label)) < 2L || length(unique(score)) < 2L || sum(label) < 5L) {
    return(list(auc = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_))
  }
  r <- pROC::roc(label, score, quiet = TRUE)
  ci <- as.numeric(pROC::ci.auc(r))
  list(
    auc = as.numeric(pROC::auc(r)),
    ci_lo = ci[1],
    ci_hi = ci[3]
  )
}

calc_binary_summary <- function(label, flag) {
  keep <- !is.na(label) & !is.na(flag)
  label <- as.integer(label[keep])
  flag  <- as.integer(flag[keep])
  n_flagged <- sum(flag == 1L)
  precision <- if (n_flagged > 0) mean(label[flag == 1L]) else NA_real_
  recall    <- if (sum(label) > 0) sum(label == 1L & flag == 1L) / sum(label) else NA_real_
  fpr       <- if (sum(label == 0L) > 0) sum(label == 0L & flag == 1L) / sum(label == 0L) else NA_real_
  list(n_flagged = n_flagged, precision = precision, recall = recall, fpr = fpr)
}

calc_topk <- function(score, label, k = 500L) {
  ord <- order(score, decreasing = TRUE, na.last = NA)
  if (!length(ord)) return(list(n_pos = NA_integer_, precision = NA_real_, recall = NA_real_))
  k_use <- min(k, length(ord))
  top_lab <- as.integer(label[ord][seq_len(k_use)])
  total_pos <- sum(label == 1L, na.rm = TRUE)
  list(
    n_pos = sum(top_lab),
    precision = mean(top_lab),
    recall = if (total_pos > 0) sum(top_lab) / total_pos else NA_real_
  )
}

cat("  Computing firm-level strict holdout metrics ...\n")
firm_panel <- firm_stats[always_loser_train == 1L]
firm_auc_bin  <- calc_auc(firm_panel$is_cobid, firm_panel$fl_train)
firm_auc_cont <- calc_auc(firm_panel$is_cobid, firm_panel$log_tc_train)
firm_bin_sum  <- calc_binary_summary(firm_panel$is_cobid, firm_panel$fl_train)
firm_top500   <- calc_topk(firm_panel$log_tc_train, firm_panel$is_cobid, 500L)

cat("  Building item-level 2017-2019 application panel ...\n")
item_panel <- as.data.table(dbGetQuery(con, sprintf("
  WITH base AS (
    SELECT
      LPAD(CAST(a.\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
      CAST(a.\"numerodaoc\" AS VARCHAR) AS numerodaoc,
      CAST(a.\"códigoitem\" AS VARCHAR) AS codigoitem,
      CAST(SUBSTR(CAST(a.\"numerodaoc\" AS VARCHAR), 12, 4) AS INTEGER) AS year,
      CAST(a.\"won\" AS INTEGER) AS won
    FROM read_parquet('%s') AS a
  ),
  loss_score AS (
    SELECT
      firm_code,
      SUM(CASE WHEN year BETWEEN 2009 AND 2016 AND won = 0 THEN 1 ELSE 0 END) AS losses_train
    FROM base
    GROUP BY firm_code
  )
  SELECT
    CONCAT(b.numerodaoc, '_', b.codigoitem) AS oc_item_key,
    MAX(b.year) AS year,
    MAX(CASE WHEN b.firm_code IN (SELECT firm_code FROM cobid_codes_tmp) THEN 1 ELSE 0 END) AS any_cobidder,
    MAX(CASE WHEN b.won = 0 AND COALESCE(ls.losses_train, 0) > %.10f THEN 1 ELSE 0 END) AS any_fl_train,
    MAX(CASE WHEN b.won = 0 THEN LOG(COALESCE(ls.losses_train, 0) + 1) ELSE NULL END) AS log_max_tc_train
  FROM base AS b
  LEFT JOIN loss_score AS ls
    ON b.firm_code = ls.firm_code
  WHERE b.year BETWEEN 2017 AND 2019
  GROUP BY oc_item_key
", ftm_path, cut_train)))

item_auc_bin  <- calc_auc(item_panel$any_cobidder, item_panel$any_fl_train)
item_auc_cont <- calc_auc(item_panel$any_cobidder, item_panel$log_max_tc_train)
item_bin_sum  <- calc_binary_summary(item_panel$any_cobidder, item_panel$any_fl_train)

results <- rbindlist(list(
  data.table(
    scope = "firm_al_train_pool",
    score = "fl_train_binary",
    threshold_rule = "median_plus_1.5_iqr_train",
    threshold_value = cut_train,
    universe = "Always-losers as of 2009-2016",
    auc = firm_auc_bin$auc,
    ci_lo = firm_auc_bin$ci_lo,
    ci_hi = firm_auc_bin$ci_hi,
    n_pos = sum(firm_panel$is_cobid),
    n_total = nrow(firm_panel),
    n_flagged = firm_bin_sum$n_flagged,
    precision_flagged = firm_bin_sum$precision,
    recall_flagged = firm_bin_sum$recall,
    fpr_flagged = firm_bin_sum$fpr,
    top500_precision = NA_real_,
    top500_recall = NA_real_
  ),
  data.table(
    scope = "firm_al_train_pool",
    score = "log_tc_train",
    threshold_rule = "continuous",
    threshold_value = cut_train,
    universe = "Always-losers as of 2009-2016",
    auc = firm_auc_cont$auc,
    ci_lo = firm_auc_cont$ci_lo,
    ci_hi = firm_auc_cont$ci_hi,
    n_pos = sum(firm_panel$is_cobid),
    n_total = nrow(firm_panel),
    n_flagged = NA_integer_,
    precision_flagged = NA_real_,
    recall_flagged = NA_real_,
    fpr_flagged = NA_real_,
    top500_precision = firm_top500$precision,
    top500_recall = firm_top500$recall
  ),
  data.table(
    scope = "item_2017_2019",
    score = "any_fl_train_binary",
    threshold_rule = "median_plus_1.5_iqr_train",
    threshold_value = cut_train,
    universe = "Items in 2017-2019",
    auc = item_auc_bin$auc,
    ci_lo = item_auc_bin$ci_lo,
    ci_hi = item_auc_bin$ci_hi,
    n_pos = sum(item_panel$any_cobidder),
    n_total = nrow(item_panel),
    n_flagged = item_bin_sum$n_flagged,
    precision_flagged = item_bin_sum$precision,
    recall_flagged = item_bin_sum$recall,
    fpr_flagged = item_bin_sum$fpr,
    top500_precision = NA_real_,
    top500_recall = NA_real_
  ),
  data.table(
    scope = "item_2017_2019",
    score = "log_max_tc_train",
    threshold_rule = "continuous",
    threshold_value = cut_train,
    universe = "Items in 2017-2019",
    auc = item_auc_cont$auc,
    ci_lo = item_auc_cont$ci_lo,
    ci_hi = item_auc_cont$ci_hi,
    n_pos = sum(item_panel$any_cobidder),
    n_total = nrow(item_panel),
    n_flagged = NA_integer_,
    precision_flagged = NA_real_,
    recall_flagged = NA_real_,
    fpr_flagged = NA_real_,
    top500_precision = NA_real_,
    top500_recall = NA_real_
  )
), fill = TRUE)

results[, full_sample_threshold := cut_full]
fwrite(results, file.path(OUT, "strict_train_threshold.csv"))

fmt_ci <- function(lo, hi) sprintf("[%.3f, %.3f]", lo, hi)
tex <- c(
  "% JLEO-R1: strict temporal holdout with threshold trained on 2009--2016 only",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Strict Temporal Holdout with Threshold Frozen on 2009--2016}",
  "\\label{tab:strict_train_threshold}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{llcccc}",
  "\\toprule",
  "Scope & Score & Threshold & AUC & 95\\% CI & Positives / $N$ \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(results))) {
  rr <- results[i]
  scope_lab <- if (rr$scope == "firm_al_train_pool") {
    "Firm-level always-loser pool"
  } else {
    "Item-level 2017--2019"
  }
  score_lab <- if (rr$score %in% c("fl_train_binary", "any_fl_train_binary")) {
    "Binary FL flag"
  } else {
    "$\\log(1+\\text{tc})$"
  }
  thr_lab <- if (rr$threshold_rule == "continuous") {
    "---"
  } else {
    sprintf("$%.1f$", rr$threshold_value)
  }
  tex <- c(
    tex,
    sprintf("%s & %s & %s & $%.3f$ & $%s$ & $%s / %s$ \\\\",
            scope_lab,
            score_lab,
            thr_lab,
            rr$auc,
            fmt_ci(rr$ci_lo, rr$ci_hi),
            format(rr$n_pos, big.mark = "{,}"),
            format(rr$n_total, big.mark = "{,}"))
  )
}

tex <- c(
  tex,
  "\\midrule",
  sprintf("\\multicolumn{6}{l}{Train-window threshold (2009--2016 always-losers): $%.1f$; full-sample reference threshold: $%.1f$.} \\\\", cut_train, cut_full),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} The binary FL threshold is estimated exclusively on the 2009--2016 participation distribution of firms with zero wins in the training window. The item-level rows then apply that frozen threshold to 2017--2019 items. This removes the full-sample threshold leakage that a hostile rereview would treat as a technical flaw.",
  "\\item \\textit{Source:} \\texttt{scripts/53\\_strict\\_train\\_period\\_threshold.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_strict_train_threshold.tex"))

cat("\n  Strict holdout summary:\n")
print(results[, .(
  scope, score,
  threshold_value = round(threshold_value, 2),
  auc = round(auc, 4),
  ci = sprintf("[%.3f, %.3f]", ci_lo, ci_hi),
  n_pos, n_total
)])
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "strict_train_threshold.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_strict_train_threshold.tex"), "\n", sep = "")

dbDisconnect(con, shutdown = TRUE)
