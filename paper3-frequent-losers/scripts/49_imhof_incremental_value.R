# ============================================================================
# 49_imhof_incremental_value.R -- recenter the Imhof comparison on
# complementary signal and data-cost wedge
#
# Outputs:
#   output/imhof_incremental/imhof_incremental.csv
#   work/v13/output/tables/tab_imhof_incremental.tex
# ============================================================================

cat("=== 49_imhof_incremental_value.R ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(data.table)
  library(pROC)
  library(ranger)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "imhof_incremental")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

bid_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
fp_path  <- file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")

cat("  Building firm-level Imhof features in DuckDB ...\n")
firm_features <- as.data.table(dbGetQuery(con, sprintf("
  WITH bids AS (
    SELECT
      LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
      CAST(\"numerodaoc\" AS VARCHAR) AS numerodaoc,
      CAST(\"códigoitem\" AS VARCHAR) AS codigoitem,
      CAST(bid_price AS DOUBLE) AS bid_price
    FROM read_parquet('%s')
    WHERE bid_price IS NOT NULL
      AND bid_price > 0
  ),
  tender_stats AS (
    SELECT
      numerodaoc,
      codigoitem,
      COUNT(*) AS n_bids,
      AVG(bid_price) AS mean_bp,
      STDDEV_SAMP(bid_price) AS sd_bp,
      MIN(bid_price) AS min_bp,
      MAX(bid_price) AS max_bp
    FROM bids
    GROUP BY numerodaoc, codigoitem
    HAVING COUNT(*) >= 2
  ),
  tender_moments AS (
    SELECT
      b.numerodaoc,
      b.codigoitem,
      AVG(POWER(b.bid_price - t.mean_bp, 3)) / NULLIF(POWER(t.sd_bp, 3), 0) AS skew,
      AVG(POWER(b.bid_price - t.mean_bp, 4)) / NULLIF(POWER(t.sd_bp, 4), 0) - 3 AS kurt
    FROM bids AS b
    INNER JOIN tender_stats AS t
      ON b.numerodaoc = t.numerodaoc
     AND b.codigoitem = t.codigoitem
    GROUP BY b.numerodaoc, b.codigoitem, t.sd_bp, t.mean_bp
  ),
  second_lowest AS (
    SELECT
      numerodaoc,
      codigoitem,
      CASE
        WHEN MAX(CASE WHEN rn = 1 THEN bid_price END) > 0
         AND MAX(CASE WHEN rn = 2 THEN bid_price END) IS NOT NULL
        THEN LOG(MAX(CASE WHEN rn = 2 THEN bid_price END) /
                 MAX(CASE WHEN rn = 1 THEN bid_price END))
        ELSE NULL
      END AS second_lowest_dist
    FROM (
      SELECT
        numerodaoc,
        codigoitem,
        bid_price,
        ROW_NUMBER() OVER (
          PARTITION BY numerodaoc, codigoitem
          ORDER BY bid_price
        ) AS rn
      FROM bids
    ) AS ranked
    WHERE rn <= 2
    GROUP BY numerodaoc, codigoitem
  ),
  tender_features AS (
    SELECT
      t.numerodaoc,
      t.codigoitem,
      t.n_bids,
      t.sd_bp / NULLIF(t.mean_bp, 0) AS cv,
      m.skew,
      m.kurt,
      (t.max_bp - t.min_bp) / NULLIF(t.mean_bp, 0) AS spread,
      LOG(t.max_bp / NULLIF(t.min_bp, 0)) AS min_max_log,
      s.second_lowest_dist
    FROM tender_stats AS t
    LEFT JOIN tender_moments AS m
      ON t.numerodaoc = m.numerodaoc
     AND t.codigoitem = m.codigoitem
    LEFT JOIN second_lowest AS s
      ON t.numerodaoc = s.numerodaoc
     AND t.codigoitem = s.codigoitem
  ),
  firm_tender AS (
    SELECT DISTINCT
      b.firm_code,
      f.numerodaoc,
      f.codigoitem,
      f.cv,
      f.skew,
      f.kurt,
      f.spread,
      f.min_max_log,
      f.second_lowest_dist
    FROM bids AS b
    INNER JOIN tender_features AS f
      ON b.numerodaoc = f.numerodaoc
     AND b.codigoitem = f.codigoitem
  )
  SELECT
    firm_code,
    AVG(cv) AS imhof_cv_mean,
    STDDEV_SAMP(cv) AS imhof_cv_sd,
    AVG(skew) AS imhof_skew_mean,
    AVG(kurt) AS imhof_kurt_mean,
    AVG(spread) AS imhof_spread_mean,
    AVG(min_max_log) AS imhof_minmax_mean,
    AVG(second_lowest_dist) AS imhof_second_low_mean,
    COUNT(*) AS n_tenders_priced
  FROM firm_tender
  GROUP BY firm_code
", bid_path)))

dbDisconnect(con, shutdown = TRUE)

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

fp <- as.data.table(arrow::read_parquet(fp_path))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]

al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, is_fl := as.integer(tenders_count >= 14L)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]

al <- merge(al, firm_features, by = "firm_code", all.x = TRUE)
complete_vars <- c(
  "imhof_cv_mean", "imhof_cv_sd", "imhof_skew_mean", "imhof_kurt_mean",
  "imhof_spread_mean", "imhof_minmax_mean", "imhof_second_low_mean"
)
al_complete <- copy(al)
for (v in complete_vars) {
  al_complete <- al_complete[!is.na(get(v)) & is.finite(get(v))]
}
al_complete <- al_complete[!is.na(tenders_count)]

set.seed(20260501)
al_complete[, fold := sample(rep(1:5, length.out = .N))]

cat(sprintf("  Same-universe comparison sample: %s firms, %s positives\n",
            format(nrow(al_complete), big.mark = ","),
            format(sum(al_complete$is_cade), big.mark = ",")))

run_cv_predictions <- function(features) {
  preds <- numeric(nrow(al_complete))
  for (k in 1:5) {
    train <- copy(al_complete[fold != k])
    test  <- copy(al_complete[fold == k])
    train[, target := factor(is_cade, levels = c(0, 1))]
    formula_str <- paste("target ~", paste(features, collapse = " + "))
    fit <- ranger(
      as.formula(formula_str),
      data = train,
      num.trees = 500,
      probability = TRUE,
      num.threads = 12,
      seed = 20260501 + k
    )
    pred <- predict(fit, test)$predictions[, "1"]
    preds[al_complete$fold == k] <- pred
  }
  preds
}

evaluate_preds <- function(preds) {
  roc_obj <- pROC::roc(al_complete$is_cade, preds, quiet = TRUE)
  ci <- as.numeric(pROC::ci.auc(roc_obj))
  list(
    roc = roc_obj,
    auc = as.numeric(pROC::auc(roc_obj)),
    ci_lo = ci[1],
    ci_hi = ci[3]
  )
}

specs <- list(
  list(
    model = "imhof_full",
    label = "Imhof full pipeline",
    features = complete_vars,
    data_requirements = "All bid values within each tender",
    editorial_role = "Rich-data forensic benchmark"
  ),
  list(
    model = "fl_only",
    label = "Binary FL flag",
    features = c("is_fl"),
    data_requirements = "Winner + participants only",
    editorial_role = "Low-cost deployment rule"
  ),
  list(
    model = "tenders_only",
    label = "Continuous participation count",
    features = c("tenders_count"),
    data_requirements = "Winner + participants only",
    editorial_role = "Low-cost latent score"
  ),
  list(
    model = "imhof_plus_fl",
    label = "Imhof full + binary FL",
    features = c("is_fl", complete_vars),
    data_requirements = "Bid microdata + award records",
    editorial_role = "Incremental value of FL over rich benchmark"
  ),
  list(
    model = "imhof_plus_tenders",
    label = "Imhof full + participation count",
    features = c("tenders_count", complete_vars),
    data_requirements = "Bid microdata + award records",
    editorial_role = "Incremental value of continuous low-cost signal"
  )
)

pred_store <- list()
eval_store <- list()
for (sp in specs) {
  cat(sprintf("  Cross-validating %s ...\n", sp$label))
  preds <- run_cv_predictions(sp$features)
  pred_store[[sp$model]] <- preds
  eval_store[[sp$model]] <- evaluate_preds(preds)
}

base_auc <- eval_store[["imhof_full"]]$auc
base_roc <- eval_store[["imhof_full"]]$roc

rows <- list()
for (sp in specs) {
  ev <- eval_store[[sp$model]]
  delta <- ev$auc - base_auc
  p_delong <- if (sp$model == "imhof_full") {
    NA_real_
  } else {
    as.numeric(pROC::roc.test(base_roc, ev$roc, method = "delong")$p.value)
  }
  rows[[length(rows) + 1L]] <- data.table(
    model = sp$model,
    label = sp$label,
    auc = ev$auc,
    ci_lo = ev$ci_lo,
    ci_hi = ev$ci_hi,
    delta_vs_imhof_full = delta,
    p_delong_vs_imhof_full = p_delong,
    data_requirements = sp$data_requirements,
    editorial_role = sp$editorial_role,
    n_total = nrow(al_complete),
    n_pos = sum(al_complete$is_cade)
  )
}

res <- rbindlist(rows, fill = TRUE)
fwrite(res, file.path(OUT, "imhof_incremental.csv"))

fmt_ci <- function(lo, hi) sprintf("[%.3f, %.3f]", lo, hi)
fmt_delta <- function(x) ifelse(is.na(x), "---", sprintf("%+.3f", x))
fmt_p <- function(x) {
  if (is.na(x)) return("---")
  if (x < 0.001) return("$<0.001$")
  sprintf("$%.3f$", x)
}

tex <- c(
  "% JLEO-R1: Imhof comparison recentred on incremental value",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Incremental Value of Loser-Side Concentration Relative to the Full Imhof Benchmark}",
  "\\label{tab:imhof_incremental}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{p{3.8cm}p{4.0cm}cccc}",
  "\\toprule",
  "Model & Data requirements & AUC & 95\\% CI & $\\Delta$ vs Imhof full & DeLong $p$ \\\\",
  "\\midrule"
)

for (i in seq_len(nrow(res))) {
  rr <- res[i]
  tex <- c(
    tex,
    sprintf("%s & %s & $%.3f$ & $%s$ & %s & %s \\\\",
            rr$label,
            rr$data_requirements,
            rr$auc,
            fmt_ci(rr$ci_lo, rr$ci_hi),
            ifelse(is.na(rr$delta_vs_imhof_full), "---",
                   paste0("$", fmt_delta(rr$delta_vs_imhof_full), "$")),
            fmt_p(rr$p_delong_vs_imhof_full))
  )
}

tex <- c(
  tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} All models are evaluated on the exact same always-loser subsample for which the full bid-distribution feature set is available. The relevant comparison is therefore not ``does FL beat Imhof everywhere,'' but whether participation-only information remains informative when rich bid microdata are absent and whether it adds non-redundant signal when those microdata are present. The combined specifications answer the second question directly.",
  "\\item \\textit{Source:} \\texttt{scripts/49\\_imhof\\_incremental\\_value.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_imhof_incremental.tex"))

cat("\n  Imhof incremental summary:\n")
print(res[, .(
  label,
  auc = round(auc, 4),
  delta_vs_imhof_full = round(delta_vs_imhof_full, 4),
  p_delong_vs_imhof_full = round(p_delong_vs_imhof_full, 4)
)])
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "imhof_incremental.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_imhof_incremental.tex"), "\n", sep = "")
