# 63_architecture_gatekeeper.R
#
# Sequential gatekeeper: FL screen as Stage-1 filter for the bid-layer
# forensic stage. Script 49 already showed FL + Imhof full reach AUC 0.942
# vs Imhof alone 0.846 with non-redundant signal. What 49 does not do is
# the sequential reading: rank by FL, keep top-K1, then re-rank within
# those K1 by Imhof full -- compared to Imhof-only on the whole pool, how
# much recall do we lose and how much bid-microdata interrogation do we
# save? No dollar costs (we don't have validated unit prices for either
# data acquisition or analyst time); just precision/recall/lift and the
# bid-microdata footprint each rule needs.
#
# Outputs:
#   output/architecture_gatekeeper/precision_at_k.csv
#   output/architecture_gatekeeper/sequential_envelope.csv
#   output/architecture_gatekeeper/fig_precision_at_k.pdf
#   work/v13/output/tables/tab_architecture_gatekeeper.tex


if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI); library(duckdb)
  library(data.table); library(arrow); library(pROC); library(ranger)
  library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "architecture_gatekeeper")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)

# ---------- (1) reuse script 49's feature pipeline ------------------------
cat("\n[1/5] Building Imhof firm features (mirrors script 49) ...\n")

drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='12GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

bid_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
fp_path  <- file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")

firm_features <- as.data.table(dbGetQuery(con, sprintf("
WITH bids AS (
  SELECT
    LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    CAST(\"numerodaoc\" AS VARCHAR)  AS numerodaoc,
    CAST(\"códigoitem\"  AS VARCHAR) AS codigoitem,
    CAST(bid_price AS DOUBLE)         AS bid_price
  FROM read_parquet('%s')
  WHERE bid_price IS NOT NULL AND bid_price > 0
),
tender_stats AS (
  SELECT numerodaoc, codigoitem, COUNT(*) AS n_bids,
         AVG(bid_price) AS mean_bp, STDDEV_SAMP(bid_price) AS sd_bp,
         MIN(bid_price) AS min_bp, MAX(bid_price) AS max_bp
  FROM bids GROUP BY numerodaoc, codigoitem HAVING COUNT(*) >= 2
),
tender_moments AS (
  SELECT b.numerodaoc, b.codigoitem,
         AVG(POWER(b.bid_price - t.mean_bp, 3)) / NULLIF(POWER(t.sd_bp, 3), 0)     AS skew,
         AVG(POWER(b.bid_price - t.mean_bp, 4)) / NULLIF(POWER(t.sd_bp, 4), 0) - 3 AS kurt
  FROM bids b INNER JOIN tender_stats t USING (numerodaoc, codigoitem)
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
        FROM bids) WHERE rn <= 2 GROUP BY numerodaoc, codigoitem
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
  FROM bids b INNER JOIN tender_features f USING (numerodaoc, codigoitem)
)
SELECT firm_code,
       AVG(cv)  AS imhof_cv_mean, STDDEV_SAMP(cv) AS imhof_cv_sd,
       AVG(skew) AS imhof_skew_mean, AVG(kurt) AS imhof_kurt_mean,
       AVG(spread) AS imhof_spread_mean,
       AVG(min_max_log) AS imhof_minmax_mean,
       AVG(second_lowest_dist) AS imhof_second_low_mean,
       COUNT(*) AS n_tenders_priced
FROM firm_tender GROUP BY firm_code
", bid_path)))

dbDisconnect(con, shutdown = TRUE)

# ---------- (2) build the always-loser evaluation sample -------------------
cat("\n[2/5] Building always-loser sample with FL flag and CADE labels ...\n")

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

fp <- as.data.table(read_parquet(fp_path))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]

al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, log_tc  := log1p(tenders_count)]
al[, is_fl   := as.integer(tenders_count >= 14L)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]
al <- merge(al, firm_features, by = "firm_code", all.x = TRUE)

complete_vars <- c("imhof_cv_mean","imhof_cv_sd","imhof_skew_mean",
                   "imhof_kurt_mean","imhof_spread_mean",
                   "imhof_minmax_mean","imhof_second_low_mean")
al_complete <- copy(al)
for (v in complete_vars) al_complete <- al_complete[!is.na(get(v)) & is.finite(get(v))]
al_complete <- al_complete[!is.na(tenders_count)]

n_total_al <- nrow(al)
n_full     <- nrow(al_complete)
n_pos      <- sum(al_complete$is_cade)
cat(sprintf("  Always-losers in pool:        %s\n", format(n_total_al, big.mark=",")))
cat(sprintf("  With Imhof features computed: %s (%.1f%% of pool)\n",
            format(n_full, big.mark=","), 100 * n_full / n_total_al))
cat(sprintf("  Cobidder positives in evaluation sample: %d\n", n_pos))

# ---------- (3) cross-validated scores ------------------------------------
cat("\n[3/5] 5-fold CV: Imhof-full predictions ...\n")
set.seed(20260502)
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
                 seed = 20260502 + k)
    preds[te_idx] <- predict(rf, al_complete[te_idx])$predictions[, "1"]
  }
  preds
}

al_complete[, score_fl     := log_tc]
al_complete[, score_imhof  := predict_cv(complete_vars)]
al_complete[, score_combined := predict_cv(c("log_tc", complete_vars))]

# ---------- (4) precision @ k for three rules + sequential gatekeeper -----
cat("\n[4/5] Operational precision/recall envelope ...\n")

base_rate <- n_pos / n_full
ks <- c(50, 100, 250, 500, 1000, 2000)

precision_at_k <- function(scores, k) {
  ord <- order(scores, decreasing = TRUE)
  top <- al_complete$is_cade[ord[seq_len(k)]]
  list(tp = sum(top), precision = sum(top) / k,
       recall = sum(top) / n_pos, lift = (sum(top) / k) / base_rate)
}

# (a) baseline rules: rank by single score
rows <- list()
for (k in ks) {
  for (model in c("score_fl", "score_imhof", "score_combined")) {
    pk <- precision_at_k(al_complete[[model]], k)
    rows[[length(rows) + 1L]] <- data.table(
      rule = switch(model,
                    score_fl = "Award-layer only (FL log\\_tc)",
                    score_imhof = "Bid-layer only (Imhof full)",
                    score_combined = "Joint scoring (FL + Imhof, single model)"),
      stage1_pool = "all always-losers (n_full)",
      stage2_pool = "n/a",
      microdata_extractions_needed = ifelse(model == "score_fl", 0L, n_full),
      k = k,
      tp = pk$tp,
      precision = pk$precision,
      recall = pk$recall,
      lift = pk$lift
    )
  }
}

# (b) sequential gatekeeper: Stage 1 = FL log_tc takes top-K1; Stage 2 = within
# Stage-1 survivors, re-rank by Imhof full and take top-k.
# K1 candidates considered: 1000, 2000, 4000 (the audit-court-feasible window).
for (K1 in c(1000L, 2000L, 4000L)) {
  ord1 <- order(al_complete$score_fl, decreasing = TRUE)
  stage1_keep <- al_complete[ord1[seq_len(K1)]]
  if (nrow(stage1_keep) == 0L) next
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
      pk_seq <- list(tp = sum(top),
                     precision = sum(top) / k,
                     recall = sum(top) / n_pos,
                     lift = (sum(top) / k) / base_rate)
    }
    rows[[length(rows) + 1L]] <- data.table(
      rule = sprintf("Sequential: FL $\\rightarrow$ Imhof (Stage-1 keeps top %d)", K1),
      stage1_pool = sprintf("top-%d FL", K1),
      stage2_pool = sprintf("Imhof on those %d", K1),
      microdata_extractions_needed = K1,
      k = k,
      tp = pk_seq$tp,
      precision = pk_seq$precision,
      recall = pk_seq$recall,
      lift = pk_seq$lift
    )
  }
}

env <- rbindlist(rows, fill = TRUE)
fwrite(env, file.path(OUT, "precision_at_k.csv"))
cat("  Saved precision_at_k.csv\n")
print(env[, .(rule = substr(rule, 1, 55), k, tp,
              precision = round(precision, 3),
              recall = round(recall, 3),
              lift = round(lift, 2),
              microdata = microdata_extractions_needed)])

# ---------- (5) sequential envelope: how much pool reduction at matched precision ----
cat("\n[5/5] Sequential envelope: matched-precision pool reduction ...\n")

# For each rule, find the smallest k that achieves precision >= 0.10, 0.15,
# 0.20 (operational thresholds for an audit-court analyst).
targets <- c(0.10, 0.15, 0.20)
matched <- list()
for (rule in unique(env$rule)) {
  this_rule <- rule
  sub <- env[rule == this_rule]
  for (target in targets) {
    sub_above <- sub[precision >= target]
    if (nrow(sub_above) == 0L) {
      matched[[length(matched) + 1L]] <- data.table(
        rule = rule, target_precision = target,
        smallest_k_achieving = NA_integer_,
        tp_at_smallest_k = NA_integer_,
        recall_at_smallest_k = NA_real_,
        microdata_at_smallest_k = NA_integer_
      )
    } else {
      best <- sub_above[which.min(k)]
      matched[[length(matched) + 1L]] <- data.table(
        rule = rule, target_precision = target,
        smallest_k_achieving = best$k,
        tp_at_smallest_k = best$tp,
        recall_at_smallest_k = best$recall,
        microdata_at_smallest_k = best$microdata_extractions_needed
      )
    }
  }
}
matched_dt <- rbindlist(matched, fill = TRUE)
fwrite(matched_dt, file.path(OUT, "sequential_envelope.csv"))
print(matched_dt)

# ---------- (6) figure --------------------------------------------------
cat("\n[6/6] Figure: precision and recall vs k by rule ...\n")
plot_dt <- copy(env)
plot_dt[, rule_short := fifelse(grepl("Sequential", rule),
                                gsub("Sequential: FL $\\rightarrow$ Imhof \\(Stage-1 keeps top ", "Seq.\\ K1=", rule),
                                rule)]
plot_dt[, rule_short := gsub("\\)", "", rule_short)]
plot_dt[, rule_short := gsub("Award-layer only \\(FL log_tc\\)", "FL only (free)", rule_short)]
plot_dt[, rule_short := gsub("Bid-layer only \\(Imhof full\\)", "Imhof only (paid)", rule_short)]
plot_dt[, rule_short := gsub("Joint scoring \\(FL \\+ Imhof, single model\\)", "Joint scoring (paid)", rule_short)]

p_prec <- ggplot(plot_dt, aes(x = k, y = precision, colour = rule_short, shape = rule_short)) +
  geom_line(linewidth = 0.6) + geom_point(size = 2.4) +
  scale_x_continuous(trans = "log10",
                     breaks = ks,
                     labels = format(ks, big.mark = ",")) +
  geom_hline(yintercept = base_rate, linetype = "dashed", colour = "grey60") +
  annotate("text", x = 60, y = base_rate * 1.4,
           label = sprintf("base rate %.3f", base_rate), size = 3, colour = "grey40") +
  labs(x = "Top-k flags (log scale)", y = "Precision @ k",
       colour = NULL, shape = NULL,
       title = NULL) +
  theme_bw(base_size = 9) +
  theme(legend.position = "bottom", legend.box = "vertical")
ggsave(file.path(OUT, "fig_precision_at_k.pdf"), p_prec, width = 7.0, height = 5.2)
cat("  Saved figure.\n")

# ---------- (7) LaTeX table --------------------------------------------
fmt_p <- function(x) ifelse(is.na(x), "--", sprintf("%.3f", x))
fmt_n <- function(x) ifelse(is.na(x), "--", format(round(x), big.mark = "{,}"))

# Table panel: at three operational k (250, 500, 1000), the four rules side by side
panel_ks <- c(250, 500, 1000)
rules_order <- c("Award-layer only (FL log\\_tc)",
                 "Bid-layer only (Imhof full)",
                 "Joint scoring (FL + Imhof, single model)",
                 "Sequential: FL $\\rightarrow$ Imhof (Stage-1 keeps top 1000)",
                 "Sequential: FL $\\rightarrow$ Imhof (Stage-1 keeps top 2000)",
                 "Sequential: FL $\\rightarrow$ Imhof (Stage-1 keeps top 4000)")

tex <- c(
  "% Subprompt 3: architecture / gatekeeper (script 63)",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Architecture / Gatekeeper: Operational Precision and Bid-Microdata Footprint by Rule}",
  "\\label{tab:architecture_gatekeeper}",
  "\\begin{threeparttable}",
  "\\footnotesize",
  "\\begin{tabular}{lrrrrrr}",
  "\\toprule",
  "Rule & $k$ & TP & Precision & Recall & Lift & Bid-microdata firms needed \\\\",
  "\\midrule"
)
for (rule in rules_order) {
  this_rule <- rule
  sub <- env[rule == this_rule & k %in% panel_ks]
  if (nrow(sub) == 0L) next
  for (i in seq_len(nrow(sub))) {
    rr <- sub[i]
    tex <- c(tex,
      sprintf("%s & $%s$ & $%d$ & $%s$ & $%s$ & $%.2f\\times$ & $%s$ \\\\",
              ifelse(i == 1L, rr$rule, ""),
              fmt_n(rr$k), rr$tp,
              fmt_p(rr$precision), fmt_p(rr$recall), rr$lift,
              fmt_n(rr$microdata_extractions_needed)))
  }
  tex <- c(tex, "\\midrule")
}
# Drop the last \midrule before adding bottomrule
tex[length(tex)] <- "\\addlinespace"
tex <- c(tex,
  sprintf("\\multicolumn{7}{l}{\\textit{Reference: evaluation pool size = $%s$ always-loser firms with $\\geq 2$ priced bids per tender; $%d$ cobidder positives; base rate $= %.4f$.}} \\\\",
          fmt_n(n_full), n_pos, base_rate),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  "\\item \\textit{Notes:} Always-loser firms in the BEC sample, restricted to those for whom the within-tender bid-distribution moments (CV, SD, skewness, kurtosis, spread, min/max log, second-lowest distance --- the seven Imhof full-pipeline features) can be computed from \\texttt{bid\\_level\\_with\\_prices.parquet}. Five-fold cross-validated random forest scores; no out-of-sample temporal holdout in this table (see Online Appendix~C for the temporal-holdout audit). The single-model joint scoring trains a random forest on $\\log(1+\\text{tenders\\_count})$ together with the seven Imhof features in one estimator; the sequential gatekeeper trains separately, using FL-stage rank to filter, then Imhof-stage rank inside the survivor pool. ``Bid-microdata firms needed'' is the number of always-loser firms for which per-bid \\textit{Valor Unit\\'ario Proposta} must be retrieved to compute the Imhof features under each rule. The award-layer-only rule needs zero bid-microdata extractions because $\\log(1+\\text{tenders\\_count})$ uses participation counts only. Lift is precision-at-$k$ divided by the unconditional cobidder rate in the evaluation pool. The sequential pipeline does not raise top-$k$ precision above joint scoring; its operational claim is that comparable precision is reachable while requesting bid microdata for only the Stage-1 survivor pool, not the full pool.",
  "\\item \\textit{Source:} \\texttt{scripts/63\\_architecture\\_gatekeeper.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_architecture_gatekeeper.tex"))
cat("  Wrote LaTeX table: tab_architecture_gatekeeper.tex.\n")

cat("   ", file.path(OUT, "precision_at_k.csv"), "\n")
cat("   ", file.path(OUT, "sequential_envelope.csv"), "\n")
cat("   ", file.path(OUT, "fig_precision_at_k.pdf"), "\n")
cat("   ", file.path(TABS, "tab_architecture_gatekeeper.tex"), "\n")
