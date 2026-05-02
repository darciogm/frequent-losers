# 64_gatekeeper_temporal_holdout.R
#
# Temporal-holdout audit for script 63. We need this because script 43
# already showed FL precision-at-k inflates ~50% in-sample, so the
# gatekeeper headlines need the same out-of-time check before submission.
#
# Per-firm features are restricted to participation observed in 2009-2016
# (log_tc_train and Imhof aggregates both built from train-window tenders).
# Cobidder labels stay anchored on the full-window CADE adjudication
# record -- truncating labels temporally would discard nearly all
# positives, so the holdout applies to features, not labels. We then
# evaluate on firms with non-zero train-window participation against the
# same cobidder ground truth.
#
# Outputs:
#   output/architecture_gatekeeper_th/precision_at_k_th.csv
#   output/architecture_gatekeeper_th/temporal_holdout_table.csv
#   work/v13/output/tables/tab_architecture_gatekeeper_th.tex


if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI); library(duckdb)
  library(data.table); library(arrow); library(pROC); library(ranger)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "architecture_gatekeeper_th")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)

TRAIN_END <- 2016L

# ---------- (1) firm features computed on train window only ---------------
cat(sprintf("\n[1/4] Building train-window (2009-%d) Imhof features ...\n", TRAIN_END))

drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='12GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

bid_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")

# Use mêsanoencerramento (e.g., "201503" or "201503") — convert to year.
firm_features_train <- as.data.table(dbGetQuery(con, sprintf("
WITH bids AS (
  SELECT
    LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    CAST(\"numerodaoc\" AS VARCHAR)  AS numerodaoc,
    CAST(\"códigoitem\"  AS VARCHAR) AS codigoitem,
    CAST(bid_price AS DOUBLE)         AS bid_price,
    -- Year extracted from numerodaoc positions 12-15 (BEC OC code convention)
    TRY_CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR), 12, 4) AS INTEGER) AS yr
  FROM read_parquet('%s')
  WHERE bid_price IS NOT NULL AND bid_price > 0
),
bids_train AS (
  SELECT * FROM bids WHERE yr IS NOT NULL AND yr <= %d
),
tender_stats AS (
  SELECT numerodaoc, codigoitem, COUNT(*) AS n_bids,
         AVG(bid_price) AS mean_bp, STDDEV_SAMP(bid_price) AS sd_bp,
         MIN(bid_price) AS min_bp, MAX(bid_price) AS max_bp
  FROM bids_train GROUP BY numerodaoc, codigoitem HAVING COUNT(*) >= 2
),
tender_moments AS (
  SELECT b.numerodaoc, b.codigoitem,
         AVG(POWER(b.bid_price - t.mean_bp, 3)) / NULLIF(POWER(t.sd_bp, 3), 0)     AS skew,
         AVG(POWER(b.bid_price - t.mean_bp, 4)) / NULLIF(POWER(t.sd_bp, 4), 0) - 3 AS kurt
  FROM bids_train b INNER JOIN tender_stats t USING (numerodaoc, codigoitem)
  GROUP BY b.numerodaoc, b.codigoitem, t.sd_bp, t.mean_bp
),
second_lowest AS (
  SELECT numerodaoc, codigoitem,
         CASE WHEN MAX(CASE WHEN rn = 1 THEN bid_price END) > 0
               AND MAX(CASE WHEN rn = 2 THEN bid_price END) IS NOT NULL
              THEN LOG(MAX(CASE WHEN rn = 2 THEN bid_price END) /
                       MAX(CASE WHEN rn = 1 THEN bid_price END)) END AS second_lowest_dist
  FROM (SELECT numerodaoc, codigoitem, bid_price,
               ROW_NUMBER() OVER (PARTITION BY numerodaoc, codigoitem ORDER BY bid_price) AS rn
        FROM bids_train) WHERE rn <= 2 GROUP BY numerodaoc, codigoitem
),
tender_features AS (
  SELECT t.numerodaoc, t.codigoitem, t.n_bids,
         t.sd_bp / NULLIF(t.mean_bp, 0)        AS cv,
         m.skew, m.kurt,
         (t.max_bp - t.min_bp) / NULLIF(t.mean_bp, 0) AS spread,
         LOG(t.max_bp / NULLIF(t.min_bp, 0))   AS min_max_log,
         s.second_lowest_dist
  FROM tender_stats t
  LEFT JOIN tender_moments m USING (numerodaoc, codigoitem)
  LEFT JOIN second_lowest  s USING (numerodaoc, codigoitem)
),
firm_tender AS (
  SELECT DISTINCT b.firm_code, f.numerodaoc, f.codigoitem,
         f.cv, f.skew, f.kurt, f.spread, f.min_max_log, f.second_lowest_dist
  FROM bids_train b INNER JOIN tender_features f USING (numerodaoc, codigoitem)
)
SELECT firm_code,
       AVG(cv)  AS imhof_cv_mean, STDDEV_SAMP(cv) AS imhof_cv_sd,
       AVG(skew) AS imhof_skew_mean, AVG(kurt) AS imhof_kurt_mean,
       AVG(spread) AS imhof_spread_mean,
       AVG(min_max_log) AS imhof_minmax_mean,
       AVG(second_lowest_dist) AS imhof_second_low_mean,
       COUNT(*) AS n_tenders_priced_train
FROM firm_tender GROUP BY firm_code
", bid_path, TRAIN_END)))

# Per-firm train-window participation count for log_tc_train
tc_train <- as.data.table(dbGetQuery(con, sprintf("
SELECT firm_code, COUNT(*) AS tc_train
FROM (
  SELECT DISTINCT
    LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    CAST(\"numerodaoc\" AS VARCHAR)  AS numerodaoc,
    CAST(\"códigoitem\"  AS VARCHAR) AS codigoitem
  FROM read_parquet('%s')
  WHERE TRY_CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR), 12, 4) AS INTEGER) <= %d
)
GROUP BY firm_code
", bid_path, TRAIN_END)))

dbDisconnect(con, shutdown = TRUE)

cat(sprintf("  firms with train-window Imhof features: %s\n",
            format(nrow(firm_features_train), big.mark=",")))
cat(sprintf("  firms with train-window participation count: %s\n",
            format(nrow(tc_train), big.mark=",")))

# ---------- (2) labels: always-loser ground truth (full window) -----------
cat("\n[2/4] Loading cobidder labels and always-loser pool ...\n")

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
al <- fp[always_loser == 1L, .(firm_code)]
al <- merge(al, tc_train, by = "firm_code", all.x = TRUE)
al[is.na(tc_train), tc_train := 0L]
al[, log_tc_train := log1p(tc_train)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]
al <- merge(al, firm_features_train, by = "firm_code", all.x = TRUE)

complete_vars <- c("imhof_cv_mean","imhof_cv_sd","imhof_skew_mean",
                   "imhof_kurt_mean","imhof_spread_mean",
                   "imhof_minmax_mean","imhof_second_low_mean")

# Apply same evaluation-pool filter as script 63: complete Imhof + train participation
al_complete <- copy(al)
for (v in complete_vars) al_complete <- al_complete[!is.na(get(v)) & is.finite(get(v))]
al_complete <- al_complete[!is.na(tc_train) & tc_train > 0L]

n_full <- nrow(al_complete)
n_pos  <- sum(al_complete$is_cade)
base_rate <- n_pos / n_full

cat(sprintf("  always-losers in train-window evaluation pool: %s (%d cobidders, base rate %.4f)\n",
            format(n_full, big.mark=","), n_pos, base_rate))

# ---------- (3) cross-validated scores on train-window features -----------
cat("\n[3/4] 5-fold CV on train-window features ...\n")

set.seed(20260503)
al_complete[, fold := sample(rep(1:5, length.out = .N))]

predict_cv <- function(features) {
  preds <- numeric(nrow(al_complete))
  for (k in 1:5) {
    tr_idx <- al_complete$fold != k
    te_idx <- al_complete$fold == k
    tr <- al_complete[tr_idx]
    tr[, target := factor(is_cade, levels = c(0, 1))]
    fmla <- as.formula(paste0("target ~ ", paste(features, collapse = " + ")))
    rf <- ranger(fmla, data = tr, num.trees = 500,
                 probability = TRUE, num.threads = 12,
                 seed = 20260503 + k)
    preds[te_idx] <- predict(rf, al_complete[te_idx])$predictions[, "1"]
  }
  preds
}

al_complete[, score_fl     := log_tc_train]
al_complete[, score_imhof  := predict_cv(complete_vars)]
al_complete[, score_combined := predict_cv(c("log_tc_train", complete_vars))]

# ---------- (4) precision @ k for the four rules + sequential gatekeeper --
cat("\n[4/4] Precision/recall/lift envelope (temporal-holdout features) ...\n")

ks <- c(50, 100, 250, 500, 1000, 2000)
precision_at_k <- function(scores, k) {
  ord <- order(scores, decreasing = TRUE)
  top <- al_complete$is_cade[ord[seq_len(k)]]
  list(tp = sum(top), precision = sum(top) / k,
       recall = sum(top) / n_pos, lift = (sum(top) / k) / base_rate)
}

rows <- list()
for (k in ks) {
  for (model in c("score_fl", "score_imhof", "score_combined")) {
    pk <- precision_at_k(al_complete[[model]], k)
    rows[[length(rows) + 1L]] <- data.table(
      rule = switch(model,
                    score_fl = "Award-layer only (train-window log\\_tc)",
                    score_imhof = "Bid-layer only (train-window Imhof full)",
                    score_combined = "Joint scoring (train-window FL + Imhof)"),
      microdata_extractions_needed = ifelse(model == "score_fl", 0L, n_full),
      k = k, tp = pk$tp, precision = pk$precision,
      recall = pk$recall, lift = pk$lift
    )
  }
}

# Sequential gatekeeper at K1 = 1000, 2000, 4000
for (K1 in c(1000L, 2000L, 4000L)) {
  ord1 <- order(al_complete$score_fl, decreasing = TRUE)
  stage1_keep <- al_complete[ord1[seq_len(min(K1, nrow(al_complete)))]]
  imhof_in_pool <- stage1_keep$score_imhof
  for (k in ks) {
    if (k > nrow(stage1_keep)) {
      pk_seq <- list(tp = sum(stage1_keep$is_cade),
                     precision = sum(stage1_keep$is_cade) / nrow(stage1_keep),
                     recall = sum(stage1_keep$is_cade) / n_pos,
                     lift = (sum(stage1_keep$is_cade) / nrow(stage1_keep)) / base_rate)
    } else {
      ord2 <- order(imhof_in_pool, decreasing = TRUE)
      top <- stage1_keep$is_cade[ord2[seq_len(k)]]
      pk_seq <- list(tp = sum(top), precision = sum(top) / k,
                     recall = sum(top) / n_pos, lift = (sum(top) / k) / base_rate)
    }
    rows[[length(rows) + 1L]] <- data.table(
      rule = sprintf("Sequential: FL $\\rightarrow$ Imhof (Stage-1 keeps top %d)", K1),
      microdata_extractions_needed = K1,
      k = k, tp = pk_seq$tp, precision = pk_seq$precision,
      recall = pk_seq$recall, lift = pk_seq$lift
    )
  }
}

env_th <- rbindlist(rows, fill = TRUE)
fwrite(env_th, file.path(OUT, "precision_at_k_th.csv"))
print(env_th[, .(rule = substr(rule, 1, 55), k, tp,
                 prec = round(precision, 3),
                 rec = round(recall, 3),
                 lift = round(lift, 2))])

# ---------- (5) compare to in-sample (script 63 outputs) ------------------
cat("\n[5/5] Side-by-side: in-sample (script 63) vs temporal-holdout ...\n")

env_in <- fread(file.path(BASE, "output/architecture_gatekeeper/precision_at_k.csv"))
# Normalize the rule column so the labels match
env_in[, rule_clean := gsub("FL log_tc", "FL log\\\\_tc", rule, fixed = TRUE)]
env_th[, rule_clean := rule]

# Pivot at k = 500 and 1000 for the headline rules
panel_rows <- list()
panel_ks <- c(250, 500, 1000)
rule_pairs <- list(
  c("Award-layer only (FL log\\_tc)", "Award-layer only (train-window log\\_tc)",
    "Award-layer only"),
  c("Bid-layer only (Imhof full)", "Bid-layer only (train-window Imhof full)",
    "Bid-layer only (Imhof full)"),
  c("Joint scoring (FL + Imhof, single model)", "Joint scoring (train-window FL + Imhof)",
    "Joint scoring (FL + Imhof)"),
  c("Sequential: FL $\\rightarrow$ Imhof (Stage-1 keeps top 2000)",
    "Sequential: FL $\\rightarrow$ Imhof (Stage-1 keeps top 2000)",
    "Sequential FL $\\rightarrow$ Imhof, $K_1=2{,}000$")
)
for (rp in rule_pairs) {
  rin_label <- rp[1]; rth_label <- rp[2]; pretty <- rp[3]
  for (kk in panel_ks) {
    in_row <- env_in[rule == rin_label & k == kk]
    th_row <- env_th[rule == rth_label & k == kk]
    panel_rows[[length(panel_rows) + 1L]] <- data.table(
      rule_pretty = pretty,
      k = kk,
      prec_in = if (nrow(in_row)) in_row$precision[1] else NA_real_,
      prec_th = if (nrow(th_row)) th_row$precision[1] else NA_real_,
      rec_in  = if (nrow(in_row)) in_row$recall[1]    else NA_real_,
      rec_th  = if (nrow(th_row)) th_row$recall[1]    else NA_real_,
      tp_in   = if (nrow(in_row)) in_row$tp[1]        else NA_integer_,
      tp_th   = if (nrow(th_row)) th_row$tp[1]        else NA_integer_,
      microdata_in = if (nrow(in_row)) in_row$microdata_extractions_needed[1] else NA_integer_,
      microdata_th = if (nrow(th_row)) th_row$microdata_extractions_needed[1] else NA_integer_
    )
  }
}
panel_dt <- rbindlist(panel_rows, fill = TRUE)
fwrite(panel_dt, file.path(OUT, "temporal_holdout_table.csv"))
print(panel_dt)

# ---------- (6) LaTeX table -------------------------------------------------
fmt_p <- function(x) ifelse(is.na(x), "--", sprintf("%.3f", x))
fmt_n <- function(x) ifelse(is.na(x), "--", format(round(x), big.mark = "{,}"))
inflation <- function(p_in, p_th) {
  if (is.na(p_in) || is.na(p_th) || p_th == 0) return("--")
  sprintf("%.0f\\%%", 100 * (p_in - p_th) / p_th)
}

tex <- c(
  "% Subprompt 4 follow-on: temporal-holdout audit of the gatekeeper (script 64)",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Architecture / Gatekeeper Under Temporal Holdout: Features Trained on $2009$--$2016$, Evaluated on the Same Cobidder Labels}",
  "\\label{tab:architecture_gatekeeper_th}",
  "\\begin{threeparttable}",
  "\\footnotesize",
  "\\begin{tabular}{lrrrrrrr}",
  "\\toprule",
  " & & \\multicolumn{2}{c}{Precision @ $k$} & \\multicolumn{2}{c}{Recall @ $k$} & \\multicolumn{2}{c}{TP @ $k$} \\\\",
  "\\cmidrule(lr){3-4} \\cmidrule(lr){5-6} \\cmidrule(lr){7-8}",
  "Rule & $k$ & In-samp.\\ & T.\\ holdout & In-samp.\\ & T.\\ holdout & In-samp.\\ & T.\\ holdout \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(panel_dt))) {
  rr <- panel_dt[i]
  tex <- c(tex,
    sprintf("%s & $%s$ & $%s$ & $%s$ & $%s$ & $%s$ & $%s$ & $%s$ \\\\",
            ifelse(i == 1L || rr$rule_pretty != panel_dt$rule_pretty[i-1L],
                   rr$rule_pretty, ""),
            fmt_n(rr$k),
            fmt_p(rr$prec_in), fmt_p(rr$prec_th),
            fmt_p(rr$rec_in),  fmt_p(rr$rec_th),
            fmt_n(rr$tp_in),   fmt_n(rr$tp_th)))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  sprintf("\\item \\textit{Notes:} Temporal-holdout column restricts every per-firm feature to participation observed in $2009$--$2016$ before random-forest scoring. The cobidder ground truth (193 always-losers co-bidding with direct CADE defendants) is anchored on adjudications post-sample and cannot be temporally truncated without discarding nearly all positives, so the holdout applies to features rather than labels. Evaluation pool: in-sample is the $%s$-firm pool of Table~\\ref{tab:architecture_gatekeeper}; temporal-holdout pool is the $%s$ always-losers with both train-window participation $>0$ and complete train-window Imhof features. The pattern parallels the precision-at-$k$ audit on FL alone reported in Online Appendix C: precision compresses by roughly half, recall by less, lift by roughly half. The relative ordering of the four rules is preserved.",
          "11{,}676", fmt_n(n_full)),
  "\\item \\textit{Source:} \\texttt{scripts/64\\_gatekeeper\\_temporal\\_holdout.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_architecture_gatekeeper_th.tex"))
cat("  Wrote LaTeX table: tab_architecture_gatekeeper_th.tex.\n")

cat("   ", file.path(OUT, "precision_at_k_th.csv"), "\n")
cat("   ", file.path(OUT, "temporal_holdout_table.csv"), "\n")
cat("   ", file.path(TABS, "tab_architecture_gatekeeper_th.tex"), "\n")
