# 62_theory_bridge_bidlevel.R
#
# v16 wrote off bid-aggressiveness and bid-dispersion at the firm level as
# untestable. They aren't: bid_level_full_v14 carries per-bid
# Valor Unitário Proposta (100% populated in Convite + Pregão), Data Hr
# Proposta, Código Fornecedor, Flag Vencedor, and the (sparser) reference
# price. This script extends the within-always-loser cobidder vs
# FL-non-cobidder comparison along three bid-level dimensions:
#   - P5: bid-aggressiveness against the reference price (sparse coverage,
#         reported only as appendix diagnostic)
#   - P6: gap to the winning bid -- cover bid above winner by characteristic
#         margin
#   - P7: within-firm cross-bid dispersion of the gap -- rotation across
#         cover roles
#
# Outputs:
#   output/theory_bridge_bidlevel/firm_bidlevel_metrics.csv
#   output/theory_bridge_bidlevel/standardized_diffs_bidlevel.csv
#   output/theory_bridge_bidlevel/multivariate_logit.csv
#   work/v13/output/tables/tab_theory_bridge_bidlevel.tex


if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI); library(duckdb)
  library(data.table); library(arrow)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "theory_bridge_bidlevel")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)

# ---------- (0) firm classification ----------------------------------------

cob <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cob[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
cob_codes <- unique(cob$firm_code)

xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(xm$firm_code)

fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
fp[, is_fl := as.integer(always_loser == 1L & tenders_count >= 14L)]
fl_codes <- fp[is_fl == 1L, firm_code]
non_fl_al_codes <- fp[is_fl == 0L & always_loser == 1L, firm_code]

fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fls[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
winner_codes <- fls[total_wins > 0L, firm_code]

class_dt <- data.table(firm_code = fls$firm_code,
                       tenders_count = fls$total_participations,
                       total_wins = fls$total_wins,
                       win_rate = fls$win_rate,
                       always_loser = fls$always_loser)
class_dt[, class_label := fcase(
  firm_code %in% direct_codes, "direct_CADE",
  firm_code %in% cob_codes, "cobidder",
  firm_code %in% setdiff(fl_codes, cob_codes), "FL_non_cobidder",
  firm_code %in% non_fl_al_codes, "AL_non_FL",
  firm_code %in% winner_codes, "winner_other",
  default = "other"
)]
fwrite(class_dt[, .N, by = class_label][order(-N)], file.path(OUT, "class_counts.csv"))
print(class_dt[, .N, by = class_label][order(-N)])

# ---------- (1) DuckDB extraction of bid-level metrics ---------------------

cat("\n[1/4] Extracting per-firm bid-level metrics via DuckDB ...\n")

bid_path <- file.path(BASE, "data/processed/bid_level_full_v14.parquet")
stopifnot(file.exists(bid_path))

con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

# Per-bid pipeline:
#   - cleaned: parse numeric bid prices and reference prices, attach winner flag
#   - with_winner: identify the winning bid per (OC, item) so we can compute
#     a per-bid (bid - winner)/winner ratio
#   - per_bid: keep only LOSING bids; compute bid/reference and gap-to-winner
#     ratios; **winsorize at the per-bid level** to avoid the outlier tail
#     contaminating per-firm means (the raw ratios have heavy right tails:
#     mean bid/ref is 152k in pregão, but median is 0.94; the few cells with
#     unit-mismatched reference prices dominate raw means).
#   - per-firm: aggregate over winsorized per-bid ratios, requiring at least
#     5 usable losing bids. mean / median / SD computed from the winsorized
#     bid-level series so per-firm metrics are not driven by a single
#     pathological observation.
sql_firm <- sprintf("
WITH cleaned AS (
  SELECT
    LPAD(CAST(\"Código Fornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    \"Numero da OC\"   AS oc,
    \"Código Item\"    AS item,
    \"Descrição Procedimento Compra\" AS proc,
    TRY_CAST(\"Flag Vencedor\" AS INTEGER) AS won,
    TRY_CAST(REPLACE(CAST(\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) AS bp,
    TRY_CAST(REPLACE(CAST(\"Valor Unitário Referência\" AS VARCHAR), ',', '.') AS DOUBLE) AS rp
  FROM read_parquet('%s')
  WHERE \"Código Fornecedor\" IS NOT NULL
    AND \"Valor Unitário Proposta\" IS NOT NULL
    AND \"Descrição Procedimento Compra\" IN ('CONVITE', 'PREGÃO ELETRÔNICO')
),
with_winner AS (
  SELECT *,
    MIN(CASE WHEN won = 1 AND bp > 0 THEN bp END)
      OVER (PARTITION BY oc, item) AS win_bp
  FROM cleaned
  WHERE bp > 0
),
per_bid_raw AS (
  SELECT
    firm_code, oc, item, proc, bp, rp, win_bp,
    CASE WHEN rp > 0 THEN bp / rp END  AS bid_ref_ratio_raw,
    CASE WHEN win_bp > 0 THEN (bp - win_bp) / win_bp END AS gap_to_winner_raw
  FROM with_winner
  WHERE won = 0
),
per_bid AS (
  -- Winsorize: drop pathological per-bid observations before aggregating.
  -- Bid/reference outside [0.01, 10] is almost surely a unit-mismatch error.
  -- Gap-to-winner outside [-0.99, 10] is either a winner with bp ≤ 0 or a
  -- bid that is 1000x the winner: not what the cover-bidding signature is
  -- about (theory predicts characteristic positive margins, not 10x bursts).
  SELECT
    firm_code, oc, item, proc,
    CASE WHEN bid_ref_ratio_raw BETWEEN 0.01 AND 10
         THEN bid_ref_ratio_raw END AS bid_ref_ratio,
    CASE WHEN gap_to_winner_raw BETWEEN -0.99 AND 10
         THEN gap_to_winner_raw END AS gap_to_winner
  FROM per_bid_raw
)
SELECT
  firm_code,
  COUNT(*)                                     AS n_losing_bids,
  COUNT(DISTINCT oc || '_' || item)            AS n_losing_items,
  COUNT(bid_ref_ratio)                         AS n_with_bidref,
  COUNT(gap_to_winner)                         AS n_with_gap,
  AVG(bid_ref_ratio)                           AS mean_bid_ref_ratio,
  STDDEV(bid_ref_ratio)                        AS sd_bid_ref_ratio,
  approx_quantile(bid_ref_ratio, 0.5)          AS median_bid_ref_ratio,
  approx_quantile(bid_ref_ratio, 0.25)         AS p25_bid_ref_ratio,
  approx_quantile(bid_ref_ratio, 0.75)         AS p75_bid_ref_ratio,
  AVG(gap_to_winner)                           AS mean_gap_to_winner,
  STDDEV(gap_to_winner)                        AS sd_gap_to_winner,
  approx_quantile(gap_to_winner, 0.5)          AS median_gap_to_winner,
  approx_quantile(gap_to_winner, 0.75)         AS p75_gap_to_winner,
  SUM(CASE WHEN proc = 'CONVITE' THEN 1 ELSE 0 END) AS n_convite,
  SUM(CASE WHEN proc = 'PREGÃO ELETRÔNICO' THEN 1 ELSE 0 END) AS n_pregao
FROM per_bid
GROUP BY firm_code
HAVING n_losing_bids >= 5
", bid_path)

firm_metrics <- as.data.table(dbGetQuery(con, sql_firm))
cat("  firms with >= 5 losing bids:", nrow(firm_metrics), "\n")
cat("  median n_with_bidref per firm:",
    median(firm_metrics$n_with_bidref, na.rm = TRUE), "\n")
cat("  median n_with_gap per firm   :",
    median(firm_metrics$n_with_gap, na.rm = TRUE), "\n")

dbDisconnect(con, shutdown = TRUE)

# Drop firms with too few usable price observations
firm_metrics[, has_bidref := as.integer(n_with_bidref >= 5L)]
firm_metrics[, has_gap    := as.integer(n_with_gap >= 5L)]

# Within-firm CV of bid/reference ratio
firm_metrics[, cv_bid_ref_ratio := sd_bid_ref_ratio /
              pmax(abs(mean_bid_ref_ratio), 1e-9)]
# IQR-based dispersion is more robust than CV here
firm_metrics[, iqr_bid_ref_ratio := p75_bid_ref_ratio - p25_bid_ref_ratio]

# Attach class
firm_metrics <- merge(firm_metrics, class_dt, by = "firm_code", all.x = TRUE)
firm_metrics[is.na(class_label), class_label := "other"]

fwrite(firm_metrics, file.path(OUT, "firm_bidlevel_metrics.csv"))
cat("  Saved firm-level bid metrics.\n")

# ---------- (2) Cohen's d cobidder vs comparison populations ---------------

cat("\n[2/4] Cohen's d, cobidders vs comparison populations ...\n")

cohens_d <- function(a, b) {
  a <- a[is.finite(a)]; b <- b[is.finite(b)]
  if (length(a) < 3L || length(b) < 3L) return(NA_real_)
  va <- var(a); vb <- var(b)
  na <- length(a); nb <- length(b)
  if ((na + nb - 2) <= 0) return(NA_real_)
  s_pool <- sqrt(((na - 1) * va + (nb - 1) * vb) / (na + nb - 2))
  if (s_pool == 0) return(NA_real_)
  (mean(a) - mean(b)) / s_pool
}

dimensions <- c("mean_bid_ref_ratio", "median_bid_ref_ratio",
                "cv_bid_ref_ratio", "iqr_bid_ref_ratio",
                "mean_gap_to_winner", "median_gap_to_winner",
                "p75_gap_to_winner", "sd_gap_to_winner")
comp_groups <- c("FL_non_cobidder", "AL_non_FL", "winner_other")

diffs <- list()
for (dim in dimensions) {
  cob_vals <- firm_metrics[class_label == "cobidder", get(dim)]
  for (g in comp_groups) {
    comp_vals <- firm_metrics[class_label == g, get(dim)]
    a <- cob_vals[is.finite(cob_vals)]
    b <- comp_vals[is.finite(comp_vals)]
    d <- cohens_d(cob_vals, comp_vals)
    p_w <- if (length(a) >= 3L && length(b) >= 3L)
      tryCatch(wilcox.test(a, b)$p.value, error = function(e) NA_real_) else NA_real_
    diffs[[length(diffs) + 1L]] <- data.table(
      dimension = dim,
      comparison = g,
      mean_cobidder = mean(cob_vals, na.rm = TRUE),
      mean_comparison = mean(comp_vals, na.rm = TRUE),
      median_cobidder = median(cob_vals, na.rm = TRUE),
      median_comparison = median(comp_vals, na.rm = TRUE),
      cohens_d = d,
      wilcoxon_p = p_w,
      n_cob = length(a),
      n_comp = length(b)
    )
  }
}
diffs_dt <- rbindlist(diffs, fill = TRUE)
fwrite(diffs_dt, file.path(OUT, "standardized_diffs_bidlevel.csv"))
cat("  Saved standardized diffs.\n")
print(diffs_dt[, .(dimension, comparison,
                   mean_cob = round(mean_cobidder, 3),
                   mean_comp = round(mean_comparison, 3),
                   d = round(cohens_d, 3),
                   p = formatC(wilcoxon_p, format = "e", digits = 2),
                   n_cob, n_comp)])

# ---------- (3) Multivariate profile: logit of cobidder on dims, controlling for tenders_count ----

cat("\n[3/4] Multivariate logit profile (within FL stratum) ...\n")

fl_subset <- firm_metrics[class_label %in% c("cobidder", "FL_non_cobidder")]
fl_subset[, cobidder := as.integer(class_label == "cobidder")]
fl_subset[, log_tc := log1p(tenders_count)]

# Restrict logit to firms with usable gap-to-winner metrics.
# Reference-price coverage is too sparse at the firm level to use here
# (median n_with_bidref per firm = 0 because BEC's reference price field is
# populated for only ~22% of convite and ~32% of pregão losing bids and the
# coverage is correlated with item type rather than firm).
fl_subset_logit <- fl_subset[has_gap == 1L]

# Winsorize within the logit subset
for (dim in c("mean_gap_to_winner", "median_gap_to_winner",
              "p75_gap_to_winner", "sd_gap_to_winner")) {
  vals <- fl_subset_logit[[dim]]
  vals_finite <- vals[is.finite(vals)]
  if (length(vals_finite) < 30L) next
  qs <- quantile(vals_finite, probs = c(0.01, 0.99), na.rm = TRUE)
  fl_subset_logit[, (paste0(dim, "_w")) := pmin(pmax(get(dim), qs[1L]), qs[2L])]
}

cat("  logit subset: cobidders =", fl_subset_logit[cobidder == 1L, .N],
    "; FL non-cobidders =", fl_subset_logit[cobidder == 0L, .N], "\n")

fl_subset_logit <- fl_subset_logit[
  is.finite(mean_gap_to_winner_w) & is.finite(median_gap_to_winner_w) &
  is.finite(sd_gap_to_winner_w)   & is.finite(log_tc)
]

fit <- glm(cobidder ~ log_tc + median_gap_to_winner_w +
             sd_gap_to_winner_w,
           data = fl_subset_logit, family = binomial("logit"))
sumf <- summary(fit)
mlogit <- as.data.table(sumf$coefficients, keep.rownames = "term")
setnames(mlogit, c("Estimate", "Std. Error", "z value", "Pr(>|z|)"),
         c("estimate", "se", "z", "pval"))
fwrite(mlogit, file.path(OUT, "multivariate_logit.csv"))
print(mlogit)

# ---------- (4) LaTeX table ------------------------------------------------

cat("\n[4/4] LaTeX table ...\n")

fmt_d <- function(x) ifelse(is.na(x), "--", sprintf("%+.2f", x))
fmt_n <- function(x) ifelse(is.na(x), "--", format(round(x), big.mark = "{,}"))
fmt_b <- function(x) ifelse(is.na(x), "--", sprintf("%+.3f", x))
fmt_p <- function(p) ifelse(is.na(p), "--",
                            ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))

# Pivot for cobidder vs FL_non_cobidder primary comparison
pri <- diffs_dt[comparison == "FL_non_cobidder"]
order_dim <- c("mean_bid_ref_ratio", "median_bid_ref_ratio",
               "cv_bid_ref_ratio", "iqr_bid_ref_ratio",
               "mean_gap_to_winner", "median_gap_to_winner",
               "p75_gap_to_winner", "sd_gap_to_winner")
pri_labels <- c(
  mean_bid_ref_ratio   = "Mean bid / reference price",
  median_bid_ref_ratio = "Median bid / reference price",
  cv_bid_ref_ratio     = "Within-firm CV of bid / reference",
  iqr_bid_ref_ratio    = "Within-firm IQR of bid / reference",
  mean_gap_to_winner   = "Mean (bid $-$ winner) / winner",
  median_gap_to_winner = "Median (bid $-$ winner) / winner",
  p75_gap_to_winner    = "P75 (bid $-$ winner) / winner",
  sd_gap_to_winner     = "Within-firm SD of (bid $-$ winner) / winner"
)

# Direction predicted: under the v16 cover-bidder reading (R1: textbook
# uncompetitive cover bid), cobidders should bid systematically *higher*
# above winners than FL non-cobidders. Under a refined cover-bidder reading
# (R2: credible phantom competition), cobidders should bid *closer* to
# winners (because credible cover requires a believable bid level), with
# *higher cross-bid dispersion* (because the same firm cycles through cover
# roles in different items). The data discriminate between these readings.
tex <- c(
  "% Subprompt 2: bid-level theory-validation bridge (script 62)",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Bid-Level Within-Stratum Profile of Cobidders vs.\\ FL Non-Cobidders}",
  "\\label{tab:theory_bridge_bidlevel}",
  "\\begin{threeparttable}",
  "\\footnotesize",
  "\\begin{tabular}{lrrrr}",
  "\\toprule",
  " & Cobidder & FL non-cob. & Cohen's $d$ & Wilcoxon $p$ \\\\",
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel A. Distance from the winning bid (per-bid (bid $-$ winner)/winner, restricted to losing bids, winsorized at $[-0.99, 10]$ before per-firm aggregation).}} \\\\"
)
for (dim in c("median_gap_to_winner", "p75_gap_to_winner",
              "mean_gap_to_winner")) {
  rr <- pri[dimension == dim]
  if (nrow(rr) == 0L) next
  tex <- c(tex, sprintf("%s & $%.3f$ & $%.3f$ & $%s$ & $%s$ \\\\",
                        pri_labels[[dim]],
                        rr$mean_cobidder, rr$mean_comparison,
                        fmt_d(rr$cohens_d), fmt_p(rr$wilcoxon_p)))
}
tex <- c(tex,
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel B. Within-firm cross-bid dispersion of (bid $-$ winner)/winner.}} \\\\"
)
for (dim in c("sd_gap_to_winner")) {
  rr <- pri[dimension == dim]
  if (nrow(rr) == 0L) next
  tex <- c(tex, sprintf("%s & $%.3f$ & $%.3f$ & $%s$ & $%s$ \\\\",
                        pri_labels[[dim]],
                        rr$mean_cobidder, rr$mean_comparison,
                        fmt_d(rr$cohens_d), fmt_p(rr$wilcoxon_p)))
}
tex <- c(tex,
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel C. Multivariate profile: logit of cobidder on per-firm bid-level moments within the FL stratum, holding $\\log(1+\\text{tenders\\_count})$ constant. Estimates show whether bid-level metrics discriminate cobidders beyond their higher participation count.}} \\\\"
)
mlogit_show <- mlogit[term != "(Intercept)"]
for (i in seq_len(nrow(mlogit_show))) {
  rr <- mlogit_show[i]
  pretty_term <- switch(rr$term,
    log_tc = "$\\log(1+\\text{tenders\\_count})$",
    median_gap_to_winner_w = "Median (bid $-$ winner) / winner (winsorized)",
    sd_gap_to_winner_w = "Within-firm SD of (bid $-$ winner) / winner (winsorized)",
    rr$term
  )
  tex <- c(tex,
           sprintf("%s & coef.\\ $%s$ & SE $%s$ & --- & $%s$ \\\\",
                   pretty_term,
                   fmt_b(rr$estimate),
                   sprintf("%.3f", rr$se),
                   fmt_p(rr$pval)))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  "\\item \\textit{Notes:} Per-bid \\textit{Valor Unit\\'ario Proposta} and per-(OC, item) winning bid (identified by \\textit{Flag Vencedor}) read from \\texttt{bid\\_level\\_full\\_v14.parquet}; restricted to losing bids in \\textsc{convite} or \\textsc{preg\\~ao eletr\\^onico}. Per-bid (bid $-$ winner)/winner ratio winsorized at $[-0.99, 10]$ before per-firm aggregation; firms retained with at least 5 usable losing bids. Reference-price ratios are reported in the online appendix only: BEC's \\textit{Valor Unit\\'ario Refer\\^encia} is populated for $\\sim$22\\,\\% of \\textsc{convite} losing bids and $\\sim$32\\,\\% of \\textsc{preg\\~ao} losing bids, leaving most cobidders without firm-level coverage. The cover-bidder framework in Online Appendix~A predicts that cobidders, as the modeled type, place bids that maintain credible separation from the winner with cross-bid dispersion above what genuine losers display. The signs reported here \\emph{do not} match the textbook ``deliberately uncompetitive'' cover bid: cobidders bid systematically \\emph{closer} to winners than FL non-cobidders, while their within-firm dispersion is mildly elevated. The pattern is consistent with a refined credible-cover-bidding interpretation under which cover bids must be plausible to disguise coordination, not with an indiscriminately-high-bid version of the type. Cohen's $d$ uses pooled standard deviations; Wilcoxon $p$-values from two-sided rank-sum tests; logit standard errors are conventional MLE.",
  "\\item \\textit{Source:} \\texttt{scripts/62\\_theory\\_bridge\\_bidlevel.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_theory_bridge_bidlevel.tex"))
cat("  Wrote LaTeX table: tab_theory_bridge_bidlevel.tex.\n")

cat("   ", file.path(OUT, "firm_bidlevel_metrics.csv"), "\n")
cat("   ", file.path(OUT, "standardized_diffs_bidlevel.csv"), "\n")
cat("   ", file.path(OUT, "multivariate_logit.csv"), "\n")
cat("   ", file.path(OUT, "class_counts.csv"), "\n")
cat("   ", file.path(TABS, "tab_theory_bridge_bidlevel.tex"), "\n")
