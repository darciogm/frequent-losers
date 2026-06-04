# ============================================================================
# 07_bid_feature_audit.R  (JLEO R&R, v22 bid-layer audit, Steps 5-6)
#
# Builds, WITHOUT inventing any feature or number:
#   - outputs/tables/appendix/table_F_bid_feature_dictionary.{csv,tex}
#   - outputs/tables/main/table_O_bid_feature_support.{csv,tex}
#   - outputs/tables/appendix/table_F_bid_feature_missingness.csv
#   - outputs/diagnostics/bid_feature_support_diagnostics.csv
#
# All features are the EXACT 7 Imhof-Wallimann moments + 2 counts computed by
# scripts/31_imhof_full_pipeline.R / 49_imhof_incremental_value.R. No timing,
# bid-revision, or late-bid features are computed (not in the pipeline).
#
# Engine: DuckDB for the heavy bid->firm aggregation; data.table for the rest.
# Telemetry: host / elapsed / RSS logged.
# ============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow)
})

set.seed(20260603L)
t0 <- Sys.time()
rss_mb <- function() {
  tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()),
            intern = TRUE)) / 1024, 1), error = function(e) NA_real_)
}
log_step <- function(msg) cat(sprintf("[%6.1fs | RSS %sMB] %s\n",
  as.numeric(difftime(Sys.time(), t0, units = "secs")), rss_mb(), msg))

cat("=== 07_bid_feature_audit.R ===\n")
cat(sprintf("host=%s  pid=%d  seed=20260603\n", Sys.info()[["nodename"]], Sys.getpid()))

BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
V22  <- file.path(BASE, "work/v22-editor")
TAB_APP <- file.path(V22, "outputs/tables/appendix")
TAB_MAIN <- file.path(V22, "outputs/tables/main")
DIAG <- file.path(V22, "outputs/diagnostics")
for (d in c(TAB_APP, TAB_MAIN, DIAG)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

bid_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
fp_path  <- file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")
# canonical reproducible broad always-loser cobidder label (positive = broad_cobidder==1, 651 firms)
cobid_path <- file.path(BASE, "work/v22-editor/outputs/cache/canonical_cobidders_broad.csv")
direct_path <- file.path(BASE, "data/processed/cade_bec_crossmatch.csv")

# ---------------------------------------------------------------------------
# 1. Build firm-level Imhof features (replicates script 49 DuckDB pipeline,
#    which is the same construction as script 31).
# ---------------------------------------------------------------------------
log_step("Building firm-level Imhof features in DuckDB ...")
con <- dbConnect(duckdb(), dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

firm_features <- as.data.table(dbGetQuery(con, sprintf("
  WITH bids AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS numerodaoc,
           CAST(\"códigoitem\" AS VARCHAR) AS codigoitem,
           CAST(bid_price AS DOUBLE) AS bid_price
    FROM read_parquet('%s')
    WHERE bid_price IS NOT NULL AND bid_price > 0),
  ts AS (SELECT numerodaoc, codigoitem, COUNT(*) AS n, AVG(bid_price) AS m,
                STDDEV_SAMP(bid_price) AS s, MIN(bid_price) AS mn, MAX(bid_price) AS mx
         FROM bids GROUP BY 1,2 HAVING COUNT(*) >= 2),
  mom AS (SELECT b.numerodaoc, b.codigoitem,
                 AVG(POWER(b.bid_price - t.m, 3)) / NULLIF(POWER(t.s, 3), 0) AS skew,
                 AVG(POWER(b.bid_price - t.m, 4)) / NULLIF(POWER(t.s, 4), 0) - 3 AS kurt
          FROM bids b JOIN ts t ON b.numerodaoc=t.numerodaoc AND b.codigoitem=t.codigoitem
          GROUP BY 1,2,t.s,t.m),
  sl AS (SELECT numerodaoc, codigoitem,
                CASE WHEN MAX(CASE WHEN rn=1 THEN bid_price END) > 0
                      AND MAX(CASE WHEN rn=2 THEN bid_price END) IS NOT NULL
                     THEN LOG(MAX(CASE WHEN rn=2 THEN bid_price END) /
                              MAX(CASE WHEN rn=1 THEN bid_price END)) ELSE NULL END AS sld
         FROM (SELECT numerodaoc, codigoitem, bid_price,
                      ROW_NUMBER() OVER (PARTITION BY numerodaoc, codigoitem ORDER BY bid_price) AS rn
               FROM bids) WHERE rn <= 2 GROUP BY 1,2),
  tf AS (SELECT t.numerodaoc, t.codigoitem, t.n AS n_bids, t.s/NULLIF(t.m,0) AS cv,
                m.skew, m.kurt, (t.mx-t.mn)/NULLIF(t.m,0) AS spread,
                LOG(t.mx/NULLIF(t.mn,0)) AS mml, s.sld
         FROM ts t LEFT JOIN mom m ON t.numerodaoc=m.numerodaoc AND t.codigoitem=m.codigoitem
                   LEFT JOIN sl s ON t.numerodaoc=s.numerodaoc AND t.codigoitem=s.codigoitem),
  ftq AS (SELECT DISTINCT b.firm_code, f.numerodaoc, f.codigoitem,
                 f.cv, f.skew, f.kurt, f.spread, f.mml, f.sld
          FROM bids b JOIN tf f ON b.numerodaoc=f.numerodaoc AND b.codigoitem=f.codigoitem)
  SELECT firm_code,
         AVG(cv)   AS imhof_cv_mean,
         STDDEV_SAMP(cv) AS imhof_cv_sd,
         AVG(skew) AS imhof_skew_mean,
         AVG(kurt) AS imhof_kurt_mean,
         AVG(spread) AS imhof_spread_mean,
         AVG(mml)  AS imhof_minmax_mean,
         AVG(sld)  AS imhof_second_low_mean,
         COUNT(*)  AS n_tenders_priced
  FROM ftq GROUP BY firm_code", bid_path)))
dbDisconnect(con, shutdown = TRUE)
log_step(sprintf("firm_features rows: %s", format(nrow(firm_features), big.mark=",")))

# ---------------------------------------------------------------------------
# 2. Always-loser pool + labels
# ---------------------------------------------------------------------------
fp <- as.data.table(read_parquet(fp_path))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid <- fread(cobid_path)
cobid <- cobid[broad_cobidder == 1L]   # canonical broad AL cobidder positive set (651)
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)
direct <- fread(direct_path)
direct_codes <- unique(sprintf("%014.0f", as.numeric(gsub("[^0-9]", "", direct$firm_cnpj))))

al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, is_fl   := as.integer(tenders_count >= 14L)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]
al <- merge(al, firm_features, by = "firm_code", all.x = TRUE)

feat7 <- c("imhof_cv_mean", "imhof_cv_sd", "imhof_skew_mean", "imhof_kurt_mean",
           "imhof_spread_mean", "imhof_minmax_mean", "imhof_second_low_mean")

# script-31 pool: complete cv/skew/kurt
pool31 <- al[!is.na(imhof_cv_mean) & is.finite(imhof_cv_mean) &
             !is.na(imhof_kurt_mean) & is.finite(imhof_kurt_mean) &
             !is.na(imhof_skew_mean) & is.finite(imhof_skew_mean)]
# script-49 pool: all 7 + non-NA tenders_count
pool49 <- copy(al)
for (v in feat7) pool49 <- pool49[!is.na(get(v)) & is.finite(get(v))]
pool49 <- pool49[!is.na(tenders_count)]

n_al      <- nrow(al)
n_fl      <- sum(al$is_fl)
n_cobid   <- sum(al$is_cade)
log_step(sprintf("always-losers=%d  FL14=%d  cobidders=%d", n_al, n_fl, n_cobid))
log_step(sprintf("pool31 N=%d (pos=%d, FL14=%d) | pool49 N=%d (pos=%d, FL14=%d)",
  nrow(pool31), sum(pool31$is_cade), sum(pool31$is_fl),
  nrow(pool49), sum(pool49$is_cade), sum(pool49$is_fl)))

# ---------------------------------------------------------------------------
# 3. FEATURE DICTIONARY (Step 5) -- one row per feature.
#    Formulas quoted EXACTLY from script 31/49.
# ---------------------------------------------------------------------------
log_step("Building feature dictionary ...")

# missingness on always-loser universe
miss <- function(v) {
  ok <- !is.na(al[[v]]) & is.finite(al[[v]])
  list(nonmiss = sum(ok), rate = 1 - mean(ok))
}

dict <- rbindlist(list(
  data.table(
    feature_name = "imhof_cv_mean", feature_family = "within-tender dispersion (CV)",
    raw_bid_variables_used = "bid_price",
    construction_level = "tender-item -> firm",
    formula_or_description = "per tender-item: cv = sd(bid)/mean(bid); firm: mean(cv) across firm's priced tenders",
    aggregation_to_firm_level = "mean across firm's priced tenders (AVG(cv))",
    available_modalities = "Convite + Pregao (pooled; no modality split in pipeline)",
    uses_winner_information = "NO (all priced bids on item, winner included)",
    uses_losing_bid_information = "YES", uses_within_tender_distribution = "YES",
    uses_timestamp = "NO", can_be_computed_from_award_layer = "NO",
    leakage_risk = "low (field-level moment, shared across firms on same item)",
    interpretation = "relative dispersion of bids on the items the firm participated in",
    source_script = "31:65, 49:107"),
  data.table(
    feature_name = "imhof_cv_sd", feature_family = "within-tender dispersion (CV variability)",
    raw_bid_variables_used = "bid_price",
    construction_level = "tender-item -> firm",
    formula_or_description = "firm: sd(cv) across firm's priced tenders (SD of the per-tender CV)",
    aggregation_to_firm_level = "STDDEV_SAMP(cv) / sd(cv) across firm's tenders",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "NO", uses_losing_bid_information = "YES",
    uses_within_tender_distribution = "YES", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "NO",
    leakage_risk = "low",
    interpretation = "how variable the firm's tender-level dispersion is; UNDEFINED for single-priced-tender firms (drives 16,779->11,676 sample drop)",
    source_script = "31:90, 49:140"),
  data.table(
    feature_name = "imhof_skew_mean", feature_family = "within-tender skewness",
    raw_bid_variables_used = "bid_price",
    construction_level = "tender-item -> firm",
    formula_or_description = "per tender-item: skew = mean((b-m)^3)/s^3; firm: mean(skew)",
    aggregation_to_firm_level = "mean across firm's priced tenders (AVG(skew))",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "NO", uses_losing_bid_information = "YES",
    uses_within_tender_distribution = "YES", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "NO", leakage_risk = "low",
    interpretation = "asymmetry of the within-tender bid distribution",
    source_script = "31:66, 49:69"),
  data.table(
    feature_name = "imhof_kurt_mean", feature_family = "within-tender kurtosis",
    raw_bid_variables_used = "bid_price",
    construction_level = "tender-item -> firm",
    formula_or_description = "per tender-item: kurt = mean((b-m)^4)/s^4 - 3 (excess kurtosis); firm: mean(kurt)",
    aggregation_to_firm_level = "mean across firm's priced tenders (AVG(kurt))",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "NO", uses_losing_bid_information = "YES",
    uses_within_tender_distribution = "YES", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "NO", leakage_risk = "low",
    interpretation = "tailedness of the within-tender bid distribution",
    source_script = "31:67, 49:70"),
  data.table(
    feature_name = "imhof_spread_mean", feature_family = "within-tender spread",
    raw_bid_variables_used = "bid_price",
    construction_level = "tender-item -> firm",
    formula_or_description = "per tender-item: spread = (max(b)-min(b))/mean(b); firm: mean(spread)",
    aggregation_to_firm_level = "mean across firm's priced tenders (AVG(spread))",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "NO", uses_losing_bid_information = "YES",
    uses_within_tender_distribution = "YES", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "NO", leakage_risk = "low",
    interpretation = "normalized range of bids on the firm's items",
    source_script = "31:68, 49:110"),
  data.table(
    feature_name = "imhof_minmax_mean", feature_family = "within-tender spread (log min-max)",
    raw_bid_variables_used = "bid_price",
    construction_level = "tender-item -> firm",
    formula_or_description = "per tender-item: min_max_log = log(max(b)/min(b)); firm: mean(min_max_log)",
    aggregation_to_firm_level = "mean across firm's priced tenders (AVG(min_max_log))",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "NO", uses_losing_bid_information = "YES",
    uses_within_tender_distribution = "YES", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "NO", leakage_risk = "low",
    interpretation = "log ratio of highest to lowest bid on the firm's items",
    source_script = "31:69, 49:111"),
  data.table(
    feature_name = "imhof_second_low_mean", feature_family = "second-low (lowest-bid gap)",
    raw_bid_variables_used = "bid_price",
    construction_level = "tender-item -> firm",
    formula_or_description = "per tender-item: second_lowest_dist = log(b2/b1) where b1,b2 = two lowest bids; firm: mean",
    aggregation_to_firm_level = "mean across firm's priced tenders (AVG(second_lowest_dist))",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "YES (b1 = lowest bid ~ likely winner)",
    uses_losing_bid_information = "YES (b2)",
    uses_within_tender_distribution = "YES", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "NO", leakage_risk = "low-moderate (uses winning-margin proxy)",
    interpretation = "log gap between the two lowest bids (cover-bidding margin signal)",
    source_script = "31:70-73, 49:77-100"),
  data.table(
    feature_name = "n_bids", feature_family = "count (tender-item)",
    raw_bid_variables_used = "bid_price (count)",
    construction_level = "tender-item",
    formula_or_description = "per tender-item: COUNT(priced bids); used for the >=2-bid filter, not a firm feature in the RF",
    aggregation_to_firm_level = "NOT aggregated to firm; tender-item level only",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "n/a", uses_losing_bid_information = "n/a",
    uses_within_tender_distribution = "n/a", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "PARTIAL (award layer has participant count, not priced-bid count)",
    leakage_risk = "none", interpretation = "number of priced bids on the tender-item; gating variable (>=2)",
    source_script = "31:56-74, 49:56"),
  data.table(
    feature_name = "n_tenders_priced", feature_family = "count (firm)",
    raw_bid_variables_used = "bid_price (count of firm-tender rows)",
    construction_level = "firm",
    formula_or_description = "firm: COUNT(*) of distinct priced tender-items the firm participated in",
    aggregation_to_firm_level = "COUNT across firm's priced tenders",
    available_modalities = "Convite + Pregao (pooled)",
    uses_winner_information = "NO", uses_losing_bid_information = "NO",
    uses_within_tender_distribution = "NO", uses_timestamp = "NO",
    can_be_computed_from_award_layer = "PARTIAL (related to tenders_count but counts only priced tenders)",
    leakage_risk = "none", interpretation = "how many priced tenders the firm appears in (exposure)",
    source_script = "31:96, 49:146")
), fill = TRUE)

# fill measured columns
dict[, missingness_rate := NA_real_]
dict[, sample_N_nonmissing := NA_integer_]
for (i in seq_len(nrow(dict))) {
  fn <- dict$feature_name[i]
  if (fn %in% names(al)) {
    m <- miss(fn)
    dict$missingness_rate[i] <- round(m$rate, 4)
    dict$sample_N_nonmissing[i] <- m$nonmiss
  } else {
    dict$missingness_rate[i] <- NA_real_
    dict$sample_N_nonmissing[i] <- NA_integer_
  }
}
dict[feature_name == "n_bids", `:=`(missingness_rate = NA_real_, sample_N_nonmissing = NA_integer_)]
dict[, notes := "Imhof-Wallimann moment in a random forest (ranger, 500 trees, 5-fold random CV). Timing/bid-revision features NOT implemented in benchmark (discussed in Fig 1 only)."]

col_order <- c("feature_name","feature_family","raw_bid_variables_used","construction_level",
  "formula_or_description","aggregation_to_firm_level","available_modalities",
  "missingness_rate","sample_N_nonmissing","uses_winner_information",
  "uses_losing_bid_information","uses_within_tender_distribution","uses_timestamp",
  "can_be_computed_from_award_layer","leakage_risk","interpretation","source_script","notes")
setcolorder(dict, col_order)
fwrite(dict, file.path(TAB_APP, "table_F_bid_feature_dictionary.csv"))

# compact LaTeX (subset of columns to keep it printable)
esc <- function(x) gsub("([&%_#])", "\\\\\\1", x)
tex <- c("% AUTO-GENERATED by 07_bid_feature_audit.R -- do not hand-edit",
  "\\begin{table}[htbp]\\centering\\scriptsize",
  "\\caption{Bid-Layer Feature Dictionary (Imhof--Wallimann benchmark)}",
  "\\label{tab:F_bid_feature_dictionary}",
  "\\begin{tabular}{p{2.4cm}p{2.6cm}p{4.2cm}p{1.0cm}cc}",
  "\\toprule",
  "Feature & Family & Formula & Miss.\\ & Within-tender & Timestamp \\\\",
  "\\midrule")
for (i in seq_len(nrow(dict))) {
  r <- dict[i]
  mr <- if (is.na(r$missingness_rate)) "---" else sprintf("%.3f", r$missingness_rate)
  tex <- c(tex, sprintf("%s & %s & %s & %s & %s & %s \\\\",
    esc(r$feature_name), esc(r$feature_family), esc(r$formula_or_description),
    mr, esc(r$uses_within_tender_distribution), esc(r$uses_timestamp)))
}
tex <- c(tex, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}\\scriptsize",
  "\\item Source: \\texttt{scripts/31\\_imhof\\_full\\_pipeline.R}, \\texttt{49\\_imhof\\_incremental\\_value.R}.",
  "Learner: random forest (ranger, 500 trees), 5-fold random CV. Timing / bid-revision features are NOT in the benchmark.",
  "\\end{tablenotes}", "\\end{table}")
writeLines(tex, file.path(TAB_APP, "table_F_bid_feature_dictionary.tex"))
log_step("wrote feature dictionary (csv + tex)")

# ---------------------------------------------------------------------------
# 4. SUPPORT / MISSINGNESS (Step 6)
# ---------------------------------------------------------------------------
log_step("Building support / missingness tables ...")

# direct defendants that are always-losers (for reporting only)
n_direct <- length(direct_codes)
n_direct_in_al <- sum(direct_codes %in% al$firm_code)

# populations
pops <- list(
  list(name = "all_bec_firms",
       N_award = NA_integer_, mask_al = NULL, note = "full BEC firm registry (~39.6K); not the candidate pool"),
  list(name = "all_always_losers", N_award = n_al, sub = al,
       note = "always_loser==1 universe (candidate pool)"),
  list(name = "frequent_losers_FL14", N_award = n_fl, sub = al[is_fl == 1L],
       note = "always-losers with tenders_count>=14"),
  list(name = "always_loser_cobidders", N_award = n_cobid, sub = al[is_cade == 1L],
       note = "canonical broad AL cobidder label (651) (canonical_cobidders_broad)"),
  list(name = "direct_cade_defendants", N_award = n_direct, sub = NULL,
       note = "cade_bec_crossmatch (49); EXCLUDED from cobidder candidate pool"),
  list(name = "common_bid_feature_pool_31", N_award = nrow(pool31), sub = pool31,
       note = "always-losers w/ complete cv/skew/kurt (script 31 pool)"),
  list(name = "common_bid_feature_pool_49", N_award = nrow(pool49), sub = pool49,
       note = "always-losers w/ all 7 features incl cv_sd (script 49 pool)")
)

complete7 <- function(d) {
  if (is.null(d) || nrow(d) == 0) return(integer(0))
  keep <- rep(TRUE, nrow(d))
  for (v in feat7) keep <- keep & !is.na(d[[v]]) & is.finite(d[[v]])
  which(keep)
}
complete3 <- function(d) {  # cv/skew/kurt (script-31 definition)
  if (is.null(d) || nrow(d) == 0) return(integer(0))
  which(!is.na(d$imhof_cv_mean) & is.finite(d$imhof_cv_mean) &
        !is.na(d$imhof_skew_mean) & is.finite(d$imhof_skew_mean) &
        !is.na(d$imhof_kurt_mean) & is.finite(d$imhof_kurt_mean))
}

support_rows <- list()
for (p in pops) {
  d <- p$sub
  if (is.null(d)) {
    row <- data.table(population = p$name, N_award_layer = p$N_award,
      N_with_bid_features = NA_integer_, support_retained_share = NA_real_,
      positives_award_layer = NA_integer_, positives_with_bid_features = NA_integer_,
      positive_retention_share = NA_real_, frequent_losers_award = NA_integer_,
      frequent_losers_with_bid_features = NA_integer_,
      main_reason_for_support_loss = NA_character_, notes = p$note)
  } else {
    idx31 <- complete3(d)         # script-31 "with bid features" definition
    nf <- length(idx31)
    pos_aw <- sum(d$is_cade)
    pos_f  <- sum(d$is_cade[idx31])
    fl_aw  <- sum(d$is_fl)
    fl_f   <- sum(d$is_fl[idx31])
    reason <- if (nf == nrow(d)) "no loss (already feature-complete)"
              else "no priced bids / <2 bids per tender (cv/skew/kurt undefined)"
    row <- data.table(population = p$name, N_award_layer = nrow(d),
      N_with_bid_features = nf,
      support_retained_share = round(nf / nrow(d), 4),
      positives_award_layer = pos_aw,
      positives_with_bid_features = pos_f,
      positive_retention_share = if (pos_aw > 0) round(pos_f / pos_aw, 4) else NA_real_,
      frequent_losers_award = fl_aw,
      frequent_losers_with_bid_features = fl_f,
      main_reason_for_support_loss = reason, notes = p$note)
  }
  support_rows[[length(support_rows) + 1L]] <- row
}
support <- rbindlist(support_rows, fill = TRUE)
fwrite(support, file.path(TAB_MAIN, "table_O_bid_feature_support.csv"))

# LaTeX (main) support table
tex2 <- c("% AUTO-GENERATED by 07_bid_feature_audit.R -- do not hand-edit",
  "\\begin{table}[htbp]\\centering\\small",
  "\\caption{Bid-Feature Support and Positive Retention by Population}",
  "\\label{tab:O_bid_feature_support}",
  "\\begin{tabular}{lrrrrr}",
  "\\toprule",
  "Population & $N$ award & $N$ feat. & Retained & Pos.\\ award & Pos.\\ retained \\\\",
  "\\midrule")
for (i in seq_len(nrow(support))) {
  r <- support[i]
  fmt_i <- function(x) if (is.na(x)) "---" else format(x, big.mark=",")
  fmt_s <- function(x) if (is.na(x)) "---" else sprintf("%.3f", x)
  tex2 <- c(tex2, sprintf("%s & %s & %s & %s & %s & %s \\\\",
    esc(r$population), fmt_i(r$N_award_layer), fmt_i(r$N_with_bid_features),
    fmt_s(r$support_retained_share), fmt_i(r$positives_award_layer),
    fmt_i(r$positives_with_bid_features)))
}
tex2 <- c(tex2, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}\\small",
  "\\item ``$N$ feat.'' = with complete cv/skew/kurt (script-31 pool). Cobidder positives use the canonical broad AL label (651).",
  "\\item Source: \\texttt{scripts/analysis/07\\_bid\\_feature\\_audit.R}.",
  "\\end{tablenotes}", "\\end{table}")
writeLines(tex2, file.path(TAB_MAIN, "table_O_bid_feature_support.tex"))

# per-feature missingness on the always-loser universe
missrows <- rbindlist(lapply(c(feat7, "n_tenders_priced"), function(v) {
  ok <- !is.na(al[[v]]) & is.finite(al[[v]])
  data.table(feature_name = v,
             population = "all_always_losers", N = n_al,
             N_nonmissing = sum(ok),
             missingness_rate = round(1 - mean(ok), 4),
             positives_nonmissing = sum(ok & al$is_cade == 1L),
             positives_total = n_cobid)
}))
fwrite(missrows, file.path(TAB_APP, "table_F_bid_feature_missingness.csv"))

# diagnostics
diag <- data.table(
  metric = c("always_losers", "frequent_losers_FL14", "cobidder_positives",
             "direct_defendants", "direct_defendants_in_always_losers",
             "pool31_N", "pool31_positives", "pool31_FL14",
             "pool49_N", "pool49_positives", "pool49_FL14",
             "support_loss_al_to_pool31", "support_loss_al_to_pool49",
             "positive_support_loss_pool31", "positive_support_loss_pool49",
             "cv_sd_nonmissing_rate"),
  value = c(n_al, n_fl, n_cobid, n_direct, n_direct_in_al,
            nrow(pool31), sum(pool31$is_cade), sum(pool31$is_fl),
            nrow(pool49), sum(pool49$is_cade), sum(pool49$is_fl),
            n_al - nrow(pool31), n_al - nrow(pool49),
            n_cobid - sum(pool31$is_cade), n_cobid - sum(pool49$is_cade),
            round(mean(!is.na(al$imhof_cv_sd) & is.finite(al$imhof_cv_sd)), 4)),
  note = c("FREQ_PARTICIP always_loser==1", "tenders_count>=14",
           "canonical broad AL cobidder label (651) (positive class)", "cade_bec_crossmatch (excluded)",
           "all canonical broad cobidders are always-losers; direct defendants reported only",
           "complete cv/skew/kurt", "broad-label positives retained in pool31", "FL lost to feature missingness",
           "all 7 features incl cv_sd", "broad-label positives retained in pool49", "FL14 retained in pool49",
           "negatives only", "negatives only (cv_sd single-tender drop)",
           "ZERO positive loss", "ZERO positive loss",
           "cv_sd undefined for single-priced-tender firms -> drives 16779->11676"))
fwrite(diag, file.path(DIAG, "bid_feature_support_diagnostics.csv"))

log_step("ALL TABLES WRITTEN")
cat("\n=== SUPPORT SUMMARY ===\n"); print(support[, .(population, N_award_layer, N_with_bid_features, positives_award_layer, positives_with_bid_features)])
cat("\n=== DIAGNOSTICS ===\n"); print(diag)
cat(sprintf("\nDone. Elapsed %.1fs\n", as.numeric(difftime(Sys.time(), t0, units="secs"))))
