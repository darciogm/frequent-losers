# ============================================================================
# 60_theory_validation_bridge.R -- tighten the bridge between the theoretical
# cover-bidder type and the empirical validation object (cobidders inside the
# always-loser stratum).
#
# Generates side-by-side comparisons of cobidders vs. four reference
# populations along five operational predictions of the cover-bidder type
# from Online Appendix A.
#
# Outputs:
#   output/theory_bridge/firm_profile_by_class.csv      -- firm-level descriptive comparison
#   output/theory_bridge/bid_behavior_by_class.csv      -- bid-level: premium, dispersion
#   output/theory_bridge/repeat_pair_by_class.csv       -- repeat co-bidding with winners
#   output/theory_bridge/concentration_by_class.csv     -- portfolio concentration
#   output/theory_bridge/standardized_diffs.csv         -- Cohen's d per dimension, cobidders vs comparison populations
#   work/v13/output/tables/tab_theory_bridge.tex        -- summary table
# ============================================================================

cat("=== 60_theory_validation_bridge.R ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI); library(duckdb)
  library(data.table); library(arrow)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "theory_bridge")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)

# ---------- (0) load classification of firms ------------------------------

# Cobidders (the validation positive class)
cob <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cob[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
cob_codes <- unique(cob$firm_code)
cat("  Cobidders inside always-loser stratum:", length(cob_codes), "\n")

# Direct CADE defendants
xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(xm$firm_code)
cat("  Direct CADE defendants in BEC:", length(direct_codes), "\n")

# Frequent losers (operational rule)
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
fp[, is_fl := as.integer(always_loser == 1L & tenders_count >= 14L)]
fl_codes <- fp[is_fl == 1L, firm_code]
non_fl_al_codes <- fp[is_fl == 0L & always_loser == 1L, firm_code]
cat("  FL firms:", length(fl_codes), "\n")
cat("  Always-losers, non-FL:", length(non_fl_al_codes), "\n")

# Winner firms (any winning firm at least once) and direct CADE that are winners
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fls[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
winner_codes <- fls[total_wins > 0L, firm_code]
cat("  Winner firms (total):", length(winner_codes), "\n")

# Build classification: cobidders are inside fl_codes by construction; we want
# to compare cobidders against three reference populations:
#   (A) Other FL firms (FL but not cobidder): the operational class minus cobidders
#   (B) Non-FL always-losers: less-intensive losers
#   (C) Random matched winners: a random subset of winners with comparable participation

class_dt <- data.table(firm_code = fls$firm_code,
                       tenders_count = fls$total_participations,
                       total_wins = fls$total_wins,
                       win_rate = fls$win_rate,
                       always_loser = fls$always_loser)
class_dt[, class_label := fcase(
  firm_code %in% cob_codes, "cobidder",
  firm_code %in% setdiff(fl_codes, cob_codes), "FL_non_cobidder",
  firm_code %in% non_fl_al_codes, "AL_non_FL",
  firm_code %in% winner_codes & !(firm_code %in% direct_codes), "winner_other",
  firm_code %in% direct_codes, "direct_CADE",
  default = "other"
)]

cat("\n  Class counts:\n")
print(class_dt[, .N, by = class_label][order(-N)])

# ---------- (1) firm-level profile ----------------------------------------

profile <- class_dt[class_label != "other",
  .(N = as.integer(.N),
    mean_tenders = as.numeric(mean(tenders_count, na.rm = TRUE)),
    median_tenders = as.numeric(median(tenders_count, na.rm = TRUE)),
    p25_tenders = as.numeric(quantile(tenders_count, 0.25, na.rm = TRUE)),
    p75_tenders = as.numeric(quantile(tenders_count, 0.75, na.rm = TRUE)),
    mean_win_rate = as.numeric(mean(win_rate, na.rm = TRUE)),
    share_always_loser = as.numeric(mean(always_loser == 1L, na.rm = TRUE))),
  by = class_label]

fwrite(profile, file.path(OUT, "firm_profile_by_class.csv"))
cat("\n  Firm-level profile:\n"); print(profile)

# ---------- (2) co-bidding behavior: repeat-pair density ------------------
# Theory prediction (cover bidder): bids alongside the SAME winners
# repeatedly, in greater proportion than other always-losers.

cat("\n  Loading firm_tender_map via DuckDB ...\n")
drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

ftm_path <- file.path(BASE, "data/processed/firm_tender_map.parquet")

# We extract:
#   - winners per (oc, item)
#   - losers (one per row) with their oc-item context
# Then build pair counts (loser firm, winner firm) and characterize each
# firm by repeat-pair concentration of its own portfolio.

losers_winners <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT
      LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
      CAST(\"numerodaoc\" AS VARCHAR) AS oc,
      CAST(\"códigoitem\" AS VARCHAR) AS item,
      CAST(\"won\" AS INTEGER) AS won
    FROM read_parquet('%s')
  ),
  winners AS (
    SELECT oc, item, firm_code AS winner FROM ftm WHERE won = 1
  ),
  losers AS (
    SELECT oc, item, firm_code AS loser FROM ftm WHERE won = 0
  )
  SELECT loser AS firm_code, winner, oc, item
  FROM losers JOIN winners USING (oc, item)
", ftm_path)))
dbDisconnect(con, shutdown = TRUE)

cat("  Loser-winner pair edges:", format(nrow(losers_winners), big.mark = ","), "\n")

# Pair counts per (loser, winner)
pairs <- losers_winners[, .N, by = .(firm_code, winner)]
setnames(pairs, "N", "pair_n")

# Per-firm features
firm_pairs <- pairs[, .(
  total_bids_loss   = sum(pair_n),
  unique_winners    = uniqueN(winner),
  max_pair_count    = max(pair_n),
  mean_pair_count   = mean(pair_n),
  pairs_at_least_5  = sum(pair_n >= 5L),
  share_repeat_5    = sum(pair_n[pair_n >= 5L]) / sum(pair_n),
  pair_HHI          = sum((pair_n / sum(pair_n))^2)
), by = firm_code]

# Direct-CADE exposure: share of own loss-bids that face a CADE direct defendant
firm_pairs_with_direct <- pairs[, .(
  cade_pair_bids = sum(pair_n[winner %in% direct_codes]),
  total_pair_bids = sum(pair_n)
), by = firm_code]
firm_pairs_with_direct[, share_facing_direct_cade := cade_pair_bids / pmax(total_pair_bids, 1L)]
firm_pairs <- merge(firm_pairs, firm_pairs_with_direct[, .(firm_code, share_facing_direct_cade)], by = "firm_code", all.x = TRUE)
firm_pairs[is.na(share_facing_direct_cade), share_facing_direct_cade := 0]

# Item-group concentration: HHI on item_group code (chars 1-2 of item)
losers_winners[, item_group := substr(item, 1, 2)]
firm_ig <- losers_winners[, .(n_bids = .N), by = .(firm_code, item_group)]
firm_ig[, total := sum(n_bids), by = firm_code]
firm_ig[, share := n_bids / total]
firm_ig_hhi <- firm_ig[, .(item_group_HHI = sum(share^2),
                           n_item_groups = uniqueN(item_group)), by = firm_code]
firm_pairs <- merge(firm_pairs, firm_ig_hhi, by = "firm_code", all.x = TRUE)

firm_pairs <- merge(firm_pairs, class_dt[, .(firm_code, class_label)],
                    by = "firm_code", all.x = TRUE)
firm_pairs <- firm_pairs[!is.na(class_label) & class_label != "other"]

cat("  Firm-pair table rows:", format(nrow(firm_pairs), big.mark = ","), "\n")

bid_behavior <- firm_pairs[, .(
  N = .N,
  mean_unique_winners = mean(unique_winners),
  mean_max_pair = mean(max_pair_count),
  mean_pair_HHI = mean(pair_HHI),
  share_repeat_5_mean = mean(share_repeat_5),
  pairs_at_least_5_mean = mean(pairs_at_least_5),
  share_facing_direct_cade_mean = mean(share_facing_direct_cade),
  mean_item_group_HHI = mean(item_group_HHI, na.rm = TRUE),
  mean_n_item_groups = mean(n_item_groups, na.rm = TRUE)
), by = class_label]

fwrite(bid_behavior, file.path(OUT, "repeat_pair_by_class.csv"))
cat("\n  Repeat-pair / concentration profile:\n"); print(bid_behavior)

# ---------- (3) standardized differences (Cohen's d) ----------------------

cat("\n  Computing Cohen's d (cobidders vs each comparison group) ...\n")

cd <- function(x, y) {
  x <- x[is.finite(x)]; y <- y[is.finite(y)]
  if (length(x) < 2L || length(y) < 2L) return(NA_real_)
  pooled_sd <- sqrt(((length(x) - 1L) * var(x) + (length(y) - 1L) * var(y)) /
                    (length(x) + length(y) - 2L))
  if (pooled_sd == 0) return(NA_real_)
  (mean(x) - mean(y)) / pooled_sd
}

dims <- list(
  list(name = "tenders_count", get = function(d) d$tenders_count, src = "class_dt"),
  list(name = "unique_winners", get = function(d) d$unique_winners, src = "firm_pairs"),
  list(name = "share_repeat_5", get = function(d) d$share_repeat_5, src = "firm_pairs"),
  list(name = "pairs_at_least_5", get = function(d) d$pairs_at_least_5, src = "firm_pairs"),
  list(name = "share_facing_direct_cade", get = function(d) d$share_facing_direct_cade, src = "firm_pairs"),
  list(name = "item_group_HHI", get = function(d) d$item_group_HHI, src = "firm_pairs"),
  list(name = "n_item_groups", get = function(d) d$n_item_groups, src = "firm_pairs")
)

comparison_groups <- c("FL_non_cobidder", "AL_non_FL", "winner_other")

results <- list()
for (dim in dims) {
  src_dt <- if (dim$src == "class_dt") class_dt[class_label != "other"] else firm_pairs
  cob_vals <- dim$get(src_dt[class_label == "cobidder"])
  for (g in comparison_groups) {
    other_vals <- dim$get(src_dt[class_label == g])
    if (length(other_vals) == 0L) next
    mean_cob <- mean(cob_vals, na.rm = TRUE)
    mean_oth <- mean(other_vals, na.rm = TRUE)
    d_val <- cd(cob_vals, other_vals)
    test_p <- tryCatch(wilcox.test(cob_vals, other_vals)$p.value, error = function(e) NA_real_)
    results[[length(results) + 1L]] <- data.table(
      dimension = dim$name,
      comparison = g,
      mean_cobidder = mean_cob,
      mean_comparison = mean_oth,
      cohens_d = d_val,
      wilcoxon_p = test_p,
      n_cob = length(cob_vals),
      n_comp = length(other_vals)
    )
  }
}
sd_dt <- rbindlist(results, fill = TRUE)
fwrite(sd_dt, file.path(OUT, "standardized_diffs.csv"))
cat("\n  Standardized differences (cobidders vs each comparison group):\n")
print(sd_dt[, .(dimension, comparison, mean_cobidder = round(mean_cobidder, 3),
                mean_comparison = round(mean_comparison, 3),
                cohens_d = round(cohens_d, 2),
                wilcoxon_p = formatC(wilcoxon_p, format = "e", digits = 2))])

# ---------- (4) summary LaTeX table --------------------------------------

cat("\n[4] Writing summary LaTeX table ...\n")

# Pull headline rows for the paper
key_dims <- c("tenders_count", "share_facing_direct_cade", "share_repeat_5", "item_group_HHI")
pretty_lab <- c(
  tenders_count = "Mean total participations",
  share_facing_direct_cade = "Mean share of loss-bids facing a direct CADE defendant",
  share_repeat_5 = "Mean share of loss-bids in winner-pairs of count $\\geq 5$",
  item_group_HHI = "Mean portfolio item-group HHI"
)

fmt_v <- function(v, scale = 1) sprintf("%.3f", v * scale)
fmt_d <- function(v) ifelse(is.na(v), "--", sprintf("%+.2f", v))
fmt_p <- function(p) ifelse(is.na(p), "--", ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))

# Per-class means (cobidder, FL_non_cobidder, AL_non_FL, winner_other)
class_means <- list()
for (kd in key_dims) {
  dim_def <- Filter(function(d) d$name == kd, dims)[[1L]]
  src_dt <- if (dim_def$src == "class_dt") class_dt[class_label != "other"] else firm_pairs
  for (cl in c("cobidder", "FL_non_cobidder", "AL_non_FL", "winner_other")) {
    v <- dim_def$get(src_dt[class_label == cl])
    class_means[[length(class_means) + 1L]] <- data.table(
      dimension = kd, class_label = cl,
      mean_v = mean(v, na.rm = TRUE)
    )
  }
}
cm_dt <- rbindlist(class_means)
cm_wide <- dcast(cm_dt, dimension ~ class_label, value.var = "mean_v")

# d vs FL_non_cobidder for each
d_vs_FL <- sd_dt[comparison == "FL_non_cobidder", .(dimension, cohens_d_vs_FL = cohens_d, p_vs_FL = wilcoxon_p)]
cm_wide <- merge(cm_wide, d_vs_FL, by = "dimension", all.x = TRUE)
setcolorder(cm_wide, c("dimension", "cobidder", "FL_non_cobidder", "AL_non_FL", "winner_other",
                       "cohens_d_vs_FL", "p_vs_FL"))

tex <- c(
  "% Subprompt 4: theory-validation bridge (script 60)",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Cobidders vs.\\ Reference Populations: Operational Predictions of the Cover-Bidder Type}",
  "\\label{tab:theory_bridge}",
  "\\begin{threeparttable}",
  "\\footnotesize",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{tabular}{lcccccc}",
  "\\toprule",
  " & Cobidders & FL non- & Always- & Other & Cohen's $d$ & Wilcoxon \\\\",
  " & ($N=191$) & cobidders & loser, non-FL & winners & vs.\\ FL & $p$ \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(cm_wide))) {
  rr <- cm_wide[i]
  lab <- pretty_lab[rr$dimension]
  tex <- c(tex, sprintf("%s & $%s$ & $%s$ & $%s$ & $%s$ & $%s$ & $%s$ \\\\",
                        lab,
                        fmt_v(rr$cobidder),
                        fmt_v(rr$FL_non_cobidder),
                        fmt_v(rr$AL_non_FL),
                        fmt_v(rr$winner_other),
                        fmt_d(rr$cohens_d_vs_FL),
                        fmt_p(rr$p_vs_FL)))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{adjustbox}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  "\\item \\textit{Notes:} Each row reports a firm-level mean for four populations: cobidders ($\\valCobidders$ always-losers participating alongside CADE direct defendants), FL non-cobidders ($\\valFL{-}\\!\\valCobidders$ frequent losers without recorded direct-defendant adjacency), always-losers below the FL threshold, and other winners (firms with at least one win, excluding direct CADE defendants). The two rightmost columns report Cohen's $d$ and a Wilcoxon rank-sum test of cobidders against FL non-cobidders, the relevant within-stratum comparison. The four operational measures map directly to the cover-bidder type in Online Appendix~A: total participation (deployment intensity), share of own loss-bids facing a direct CADE defendant (deployment proximity), share of loss-bids in winner-pairs of count $\\geq 5$ (repeat co-bidding density), and portfolio item-group HHI (specialization in the cartel's market).",
  "\\item \\textit{Source:} \\texttt{scripts/60\\_theory\\_validation\\_bridge.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

writeLines(tex, file.path(TABS, "tab_theory_bridge.tex"))
cat("  Wrote LaTeX table.\n")

# ---------- (5) outputs --------------------------------------------------

fwrite(cm_wide, file.path(OUT, "summary_means_wide.csv"))

cat("\n=== Done. Outputs:\n")
cat("   ", file.path(OUT, "firm_profile_by_class.csv"), "\n")
cat("   ", file.path(OUT, "repeat_pair_by_class.csv"), "\n")
cat("   ", file.path(OUT, "standardized_diffs.csv"), "\n")
cat("   ", file.path(OUT, "summary_means_wide.csv"), "\n")
cat("   ", file.path(TABS, "tab_theory_bridge.tex"), "\n")
