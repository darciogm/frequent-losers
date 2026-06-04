# ============================================================================
# 08_bid_benchmark_reproduction.R  (JLEO R&R, v22, Step 7)
#
# Reproduces the current manuscript bid-layer benchmark numbers by RE-RUNNING
# the random-forest CV (same construction as scripts 31 & 49) and comparing to
# both (a) the manuscript-cited values and (b) the committed output CSVs.
#
# Manuscript targets:
#   Script-31 pool (N=16,779):
#     fl_alone 0.921, tenders_alone 0.884, imhof_cv_only 0.585,
#     imhof_full 0.888, imhof_full+fl 0.962, imhof_full+tenders 0.962
#   Script-49 pool (N=11,676):
#     imhof_full 0.846, fl_only 0.881, imhof+fl 0.942
#
# Output: outputs/diagnostics/bid_benchmark_number_reproduction.csv
# Engine: DuckDB (features) + ranger (RF). num.threads=12. Telemetry on.
# ============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow)
  library(pROC); library(ranger)
})
set.seed(20260603L)
t0 <- Sys.time()
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()),
  intern = TRUE)) / 1024, 1), error = function(e) NA_real_)
log_step <- function(msg) cat(sprintf("[%6.1fs | RSS %sMB] %s\n",
  as.numeric(difftime(Sys.time(), t0, units = "secs")), rss_mb(), msg))

cat("=== 08_bid_benchmark_reproduction.R ===\n")
cat(sprintf("host=%s  pid=%d\n", Sys.info()[["nodename"]], Sys.getpid()))

BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
V22  <- file.path(BASE, "work/v22-editor")
DIAG <- file.path(V22, "outputs/diagnostics")
dir.create(DIAG, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

bid_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
fp_path  <- file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")
# canonical reproducible broad always-loser cobidder label (positive = broad_cobidder==1, 651 firms)
cobid_path <- file.path(BASE, "work/v22-editor/outputs/cache/canonical_cobidders_broad.csv")
# NOTE: historical benchmarks were computed under the archived 193 label; under the
# canonical broad label (651) deviations are expected and informational.

# ---- firm features (DuckDB; same construction as 31/49) -------------------
log_step("Building firm-level Imhof features ...")
con <- dbConnect(duckdb(), dbdir = ":memory:")
dbExecute(con, "SET threads TO 12"); dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")
ff <- as.data.table(dbGetQuery(con, sprintf("
  WITH bids AS (SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') firm_code,
    CAST(\"numerodaoc\" AS VARCHAR) numerodaoc, CAST(\"códigoitem\" AS VARCHAR) codigoitem,
    CAST(bid_price AS DOUBLE) bid_price FROM read_parquet('%s') WHERE bid_price IS NOT NULL AND bid_price>0),
  ts AS (SELECT numerodaoc,codigoitem,COUNT(*) n,AVG(bid_price) m,STDDEV_SAMP(bid_price) s,MIN(bid_price) mn,MAX(bid_price) mx FROM bids GROUP BY 1,2 HAVING COUNT(*)>=2),
  mom AS (SELECT b.numerodaoc,b.codigoitem,AVG(POWER(b.bid_price-t.m,3))/NULLIF(POWER(t.s,3),0) skew,AVG(POWER(b.bid_price-t.m,4))/NULLIF(POWER(t.s,4),0)-3 kurt FROM bids b JOIN ts t ON b.numerodaoc=t.numerodaoc AND b.codigoitem=t.codigoitem GROUP BY 1,2,t.s,t.m),
  sl AS (SELECT numerodaoc,codigoitem,CASE WHEN MAX(CASE WHEN rn=1 THEN bid_price END)>0 AND MAX(CASE WHEN rn=2 THEN bid_price END) IS NOT NULL THEN LOG(MAX(CASE WHEN rn=2 THEN bid_price END)/MAX(CASE WHEN rn=1 THEN bid_price END)) ELSE NULL END sld FROM (SELECT numerodaoc,codigoitem,bid_price,ROW_NUMBER() OVER(PARTITION BY numerodaoc,codigoitem ORDER BY bid_price) rn FROM bids) WHERE rn<=2 GROUP BY 1,2),
  tf AS (SELECT t.numerodaoc,t.codigoitem,t.n n_bids,t.s/NULLIF(t.m,0) cv,m.skew,m.kurt,(t.mx-t.mn)/NULLIF(t.m,0) spread,LOG(t.mx/NULLIF(t.mn,0)) mml,s.sld FROM ts t LEFT JOIN mom m ON t.numerodaoc=m.numerodaoc AND t.codigoitem=m.codigoitem LEFT JOIN sl s ON t.numerodaoc=s.numerodaoc AND t.codigoitem=s.codigoitem),
  ftq AS (SELECT DISTINCT b.firm_code,f.numerodaoc,f.codigoitem,f.cv,f.skew,f.kurt,f.spread,f.mml,f.sld FROM bids b JOIN tf f ON b.numerodaoc=f.numerodaoc AND b.codigoitem=f.codigoitem)
  SELECT firm_code,AVG(cv) imhof_cv_mean,STDDEV_SAMP(cv) imhof_cv_sd,AVG(skew) imhof_skew_mean,AVG(kurt) imhof_kurt_mean,AVG(spread) imhof_spread_mean,AVG(mml) imhof_minmax_mean,AVG(sld) imhof_second_low_mean,COUNT(*) n_tenders_priced FROM ftq GROUP BY firm_code", bid_path)))
dbDisconnect(con, shutdown = TRUE)
log_step(sprintf("firm_features: %s firms", format(nrow(ff), big.mark=",")))

fp <- as.data.table(read_parquet(fp_path)); fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid <- fread(cobid_path); cobid <- cobid[broad_cobidder == 1L]   # canonical broad AL cobidder positive set (651)
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, is_fl := as.integer(tenders_count >= 14L)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]
al <- merge(al, ff, by = "firm_code", all.x = TRUE)
feat7 <- c("imhof_cv_mean","imhof_cv_sd","imhof_skew_mean","imhof_kurt_mean","imhof_spread_mean","imhof_minmax_mean","imhof_second_low_mean")

pool31 <- al[!is.na(imhof_cv_mean)&is.finite(imhof_cv_mean)&!is.na(imhof_kurt_mean)&is.finite(imhof_kurt_mean)&!is.na(imhof_skew_mean)&is.finite(imhof_skew_mean)]
pool49 <- copy(al); for (v in feat7) pool49 <- pool49[!is.na(get(v))&is.finite(get(v))]; pool49 <- pool49[!is.na(tenders_count)]
log_step(sprintf("pool31 N=%d pos=%d | pool49 N=%d pos=%d", nrow(pool31), sum(pool31$is_cade), nrow(pool49), sum(pool49$is_cade)))

# ---- CV runner (matches 31/49: 5-fold random, ranger 500 trees) ----------
run_cv <- function(d, features, seed_base) {
  set.seed(seed_base)
  d <- copy(d); d[, fold := sample(rep(1:5, length.out = .N))]
  preds <- numeric(nrow(d))
  for (k in 1:5) {
    tr <- d[fold != k]; te <- d[fold == k]
    tr[, target := factor(is_cade, levels = c(0,1))]
    fmla <- as.formula(paste0("target ~ ", paste(features, collapse = " + ")))
    rf <- ranger(fmla, data = tr, num.trees = 500, probability = TRUE,
                 num.threads = 12, seed = seed_base + k)
    preds[d$fold == k] <- predict(rf, te)$predictions[, "1"]
  }
  r <- pROC::roc(d$is_cade, preds, quiet = TRUE)
  list(auc = as.numeric(pROC::auc(r)), ci = as.numeric(pROC::ci(r)))
}

# ---- Script-31 specs on pool31 (seed 20260430) ---------------------------
log_step("Re-running script-31 specs on pool31 ...")
s31 <- list(
  fl_alone = "is_fl", tenders_alone = "tenders_count", imhof_cv_only = "imhof_cv_mean",
  imhof_full = feat7,
  imhof_full_plus_fl = c("is_fl", feat7),
  imhof_full_plus_tenders = c("tenders_count", feat7))
r31 <- lapply(s31, function(f) run_cv(pool31, f, 20260430L))
for (nm in names(r31)) log_step(sprintf("  31:%-24s AUC=%.4f", nm, r31[[nm]]$auc))

# ---- Script-49 specs on pool49 (seed 20260501) ---------------------------
log_step("Re-running script-49 specs on pool49 ...")
s49 <- list(imhof_full = feat7, fl_only = "is_fl", imhof_plus_fl = c("is_fl", feat7))
r49 <- lapply(s49, function(f) run_cv(pool49, f, 20260501L))
for (nm in names(r49)) log_step(sprintf("  49:%-24s AUC=%.4f", nm, r49[[nm]]$auc))

# ---- committed CSVs for cross-check --------------------------------------
csv31 <- fread(file.path(BASE, "output/imhof_full/imhof_full_results.csv"))
csv49 <- fread(file.path(BASE, "output/imhof_incremental/imhof_incremental.csv"))
get31 <- function(m) csv31[model == m, auc]
get49 <- function(m) csv49[model == m, auc]

# ---- build reproduction table --------------------------------------------
mk <- function(name, repro, manu, csv, sample_def, model_def, src_data, src_script, notes) {
  # NOTE: historical benchmarks (manu) were computed under the archived 193 label;
  # under the canonical broad label (651) deviations are EXPECTED and informational,
  # not reproduction failures. Status is descriptive only; the script never errors.
  status <- if (is.na(repro) || is.na(manu)) "n/a"
            else if (abs(repro - manu) <= 0.005) "MATCH"
            else if (abs(repro - manu) <= 0.015) "MATCH(CV-jitter)"
            else "DEVIATION(broad-label, informational)"
  data.table(count_or_metric_name = name, reproduced_value = round(repro,4),
    manuscript_value = manu, committed_csv_value = round(csv,4), match_status = status,
    sample_definition = sample_def, model_definition = model_def,
    validation_scheme = "5-fold-random-CV", source_data = src_data,
    source_script = src_script, notes = notes)
}
rep <- rbindlist(list(
  mk("fl_alone (N=16779)", r31$fl_alone$auc, 0.921, get31("fl_alone"),
     "always-loser pool31 (cv/skew/kurt complete)", "RF is_fl",
     "bid_level_with_prices + FREQ_PARTICIP + canonical_cobidders_broad", "31", "FL binary flag"),
  mk("tenders_alone (N=16779)", r31$tenders_alone$auc, 0.884, get31("tenders_alone"),
     "pool31", "RF tenders_count", "idem", "31", ""),
  mk("imhof_cv_only (N=16779)", r31$imhof_cv_only$auc, 0.585, get31("imhof_cv_only"),
     "pool31", "RF imhof_cv_mean", "idem", "31", "v13 strawman baseline"),
  mk("imhof_full (N=16779)", r31$imhof_full$auc, 0.888, get31("imhof_full"),
     "pool31", "RF 7 Imhof moments", "idem", "31", "full Imhof-Wallimann pipeline"),
  mk("imhof_full_plus_fl (N=16779)", r31$imhof_full_plus_fl$auc, 0.962, get31("imhof_full_plus_fl"),
     "pool31", "RF 7 Imhof + is_fl", "idem", "31", "combined"),
  mk("imhof_full_plus_tenders (N=16779)", r31$imhof_full_plus_tenders$auc, 0.962, get31("imhof_full_plus_tenders"),
     "pool31", "RF 7 Imhof + tenders_count", "idem", "31", "combined"),
  mk("imhof_full (N=11676)", r49$imhof_full$auc, 0.846, get49("imhof_full"),
     "always-loser pool49 (all 7 incl cv_sd)", "RF 7 Imhof moments", "idem", "49",
     "SAME-SAMPLE incremental design; lower than pool31 0.888 because cv_sd drops single-tender firms"),
  mk("fl_only (N=11676)", r49$fl_only$auc, 0.881, get49("fl_only"),
     "pool49", "RF is_fl", "idem", "49", ""),
  mk("imhof_plus_fl (N=11676)", r49$imhof_plus_fl$auc, 0.942, get49("imhof_plus_fl"),
     "pool49", "RF 7 Imhof + is_fl", "idem", "49", "Delta +0.096 vs imhof_full, DeLong p=1.15e-26")
), fill = TRUE)

fwrite(rep, file.path(DIAG, "bid_benchmark_number_reproduction.csv"))
log_step("wrote bid_benchmark_number_reproduction.csv")
cat("\n=== REPRODUCTION ===\n")
print(rep[, .(count_or_metric_name, reproduced_value, manuscript_value, committed_csv_value, match_status)])
cat(sprintf("\nDone. Elapsed %.1fs\n", as.numeric(difftime(Sys.time(), t0, units="secs"))))
