#!/usr/bin/env Rscript
# =============================================================================
# 10_cost_recall_frontier.R  --  JLEO R&R (v22)
# COST-RECALL FRONTIER FOR SEQUENTIAL AWARD -> BID GATEKEEPING
#
# Referee objection to defeat: "83% reduction = 1 - 2000/11,676 is mechanically
# firm-level; show the WHOLE frontier with REAL cost denominators (tender-items,
# bid rows), not one nice K1."
#
# This script builds the entire cost-recall frontier over a grid of first-stage
# cuts K1 and final cuts k, with MULTIPLE cost denominators (firms, tender-items,
# bid rows, cells). It NEVER invents cost data: every denominator comes from
# firm_tender_map (firm->tender-item links) and imhof_tender_features (per-item
# n_bids). It is honest that the bid-row reduction is smaller than the firm
# reduction.
#
# Reuses: scripts/31_imhof_full_pipeline.R + work/v22/.../09_bid_benchmark_validation.R
#   (same RF: ranger 500 trees, 5-fold CV, 7 firm-mean Imhof moments; pool =
#    always-loser complete-Imhof minus direct CADE defendants; target is_cade=cobidder).
#   We RE-RUN the RF keyed by CNPJ (the Sub8 prediction cache is anonymized by
#   firm_id), validate AUC against the cached benchmark, then attach cost.
#
# Run:
#   cd <repo>; Rscript work/v22-editor/scripts/analysis/10_cost_recall_frontier.R \
#     2>&1 | tee work/v22-editor/outputs/logs/cost_recall_frontier.log
# =============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table)
  ok_ranger <- requireNamespace("ranger", quietly = TRUE)
  ok_duckdb <- requireNamespace("duckdb", quietly = TRUE) && requireNamespace("DBI", quietly = TRUE)
  ok_ggplot <- requireNamespace("ggplot2", quietly = TRUE)
})
if (!ok_ranger) stop("MISSING PACKAGE: ranger. install.packages('ranger')")
if (!ok_duckdb) stop("MISSING PACKAGE: duckdb/DBI. install.packages(c('duckdb','DBI'))")
library(ranger)
if (ok_ggplot) library(ggplot2)

# ---- locate repo + dirs -----------------------------------------------------
if (!exists(".script_dir")) {
  fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
  .script_dir <- if (length(fa)) dirname(normalizePath(fa[1L])) else getwd()
}
REPO <- normalizePath(file.path(.script_dir, "..", "..", "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(REPO, "data", "processed")))
  REPO <- normalizePath("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
DATA <- file.path(REPO, "data", "processed")
V22  <- file.path(REPO, "work", "v22-editor")
OUT  <- file.path(V22, "outputs")
UTIL <- file.path(V22, "scripts", "utils")

source(file.path(UTIL, "metrics_triage.R"))
source(file.path(UTIL, "cost_frontier.R"))

dir_main_t <- file.path(OUT, "tables", "main")
dir_app_t  <- file.path(OUT, "tables", "appendix")
dir_main_f <- file.path(OUT, "figures", "main")
dir_app_f  <- file.path(OUT, "figures", "appendix")
dir_diag   <- file.path(OUT, "diagnostics")
dir_cache  <- file.path(OUT, "cache")
dir_logs   <- file.path(OUT, "logs")
for (d in c(dir_main_t, dir_app_t, dir_main_f, dir_app_f, dir_diag, dir_cache, dir_logs))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)
SEED <- 20260603L
set.seed(SEED)
RF_TREES   <- 500L
RF_THREADS <- 12L

# ---- telemetry --------------------------------------------------------------
LOG <- file.path(dir_diag, "cost_recall_frontier_audit_log.txt")
.t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern=TRUE))/1024), error=function(e) NA_real_)
stamp <- function(s) say("  [stage %-30s] elapsed=%6.1fs  RSS=%s MB", s, as.numeric(difftime(Sys.time(),.t0,units="secs")), rss_mb())

say("=== 10_cost_recall_frontier.R ===")
say("host=%s  nproc=%s  seed=%d  date=%s  RAM_free=%s  RF_trees=%d",
    Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern=TRUE), error=function(e)"?"), SEED, format(Sys.time()),
    tryCatch(system("free -h | awk 'NR==2{print $7}'", intern=TRUE), error=function(e)"?"), RF_TREES)
say("REPO=%s", REPO)

norm14 <- function(x) sprintf("%014.0f", as.numeric(x))
safe <- function(expr) tryCatch(suppressWarnings(expr), error = function(e) NA_real_)
m_rocauc <- function(y, s) if (sum(y==1)<1 || sum(y==0)<1) NA_real_ else safe(roc_auc(y, s))

IMHOF_FEATS <- c("imhof_cv_mean","imhof_cv_sd","imhof_skew_mean","imhof_kurt_mean",
                 "imhof_spread_mean","imhof_minmax_mean","imhof_second_low_mean")

# =============================================================================
# STAGE A. CANDIDATE POOL (CNPJ-KEYED) + RE-RUN RF -> bid_RF, combined_RF
# =============================================================================
say("\n========== STAGE A. POOL + RF (CNPJ-keyed) ==========")
cache_feat <- file.path(dir_cache, "imhof_firm_features.parquet")
if (!file.exists(cache_feat)) stop("missing firm Imhof cache; run 09_bid_benchmark_validation.R first")
firm_features <- as.data.table(read_parquet(cache_feat))   # keyed by firm_code (CNPJ 14)

fp <- as.data.table(read_parquet(file.path(DATA, "FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]         # already 14-char zero-padded

cob <- fread(file.path(DATA, "cade_fl_cobidders.csv"))
cob[, firm_code := norm14(firm_cnpj)]
cob_codes <- unique(cob$firm_code)
xm  <- fread(file.path(DATA, "cade_bec_crossmatch.csv"))
xm[, firm_code := norm14(firm_cnpj)]
direct_codes <- unique(xm$firm_code)                        # EXCLUDE direct defendants
pos_codes <- setdiff(cob_codes, direct_codes)               # cobidder positives, not defendants
say("cobidders=%d  direct_defendants=%d  positives(after excl)=%d",
    length(cob_codes), length(direct_codes), length(pos_codes))

# Pool A: always-losers with complete Imhof features, minus direct defendants
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al <- al[!firm_code %in% direct_codes]
al <- merge(al, firm_features, by = "firm_code", all.x = TRUE)
al[, is_cade := as.integer(firm_code %in% pos_codes)]
al[, award_continuous := log1p(tenders_count)]
al[, award_FL14 := as.integer(tenders_count >= 14L)]
al[, has_imhof := as.integer(
  !is.na(imhof_cv_mean) & is.finite(imhof_cv_mean) &
  !is.na(imhof_kurt_mean) & is.finite(imhof_kurt_mean) &
  !is.na(imhof_skew_mean) & is.finite(imhof_skew_mean))]
poolA <- al[has_imhof == 1L]
setorder(poolA, firm_code); poolA[, firm_id := .I]
N_A <- nrow(poolA); P_A <- sum(poolA$is_cade)
say("Pool A (always-loser complete-Imhof, CNPJ-keyed): N=%s  positives=%d", format(N_A, big.mark=","), P_A)

# Pool B: ALL always-losers (award-only frontier reference); not used for cost cuts
poolB <- al[, .(firm_code, tenders_count, is_cade, award_continuous, award_FL14)]
say("Pool B (all always-losers): N=%s  positives=%d", format(nrow(poolB), big.mark=","), sum(poolB$is_cade))

# ---- RF out-of-fold engine (reuse 09 logic) --------------------------------
rf_oof_preds <- function(dt, features, fold_vec, label_col = "is_cade") {
  preds <- rep(NA_real_, nrow(dt)); folds <- sort(unique(fold_vec))
  for (k in folds) {
    test_idx  <- which(fold_vec == k); train_idx <- which(fold_vec != k)
    if (length(train_idx) < 2L) next
    tr <- dt[train_idx]; tr_lab <- factor(tr[[label_col]], levels = c(0,1))
    if (nlevels(droplevels(tr_lab)) < 2L) next
    tr2 <- copy(tr); tr2[, .y := tr_lab]
    fmla <- as.formula(paste0(".y ~ ", paste(features, collapse=" + ")))
    rf <- ranger(fmla, data = tr2, num.trees = RF_TREES, probability = TRUE,
                 num.threads = RF_THREADS, seed = SEED)
    preds[test_idx] <- predict(rf, dt[test_idx])$predictions[, "1"]
  }
  preds
}

say("re-running RF (5-fold, seed=%d, ranger %d trees) keyed by CNPJ ...", SEED, RF_TREES)
set.seed(SEED); poolA[, fold_random := sample(rep(1:5, length.out=.N))]
y <- poolA$is_cade
poolA[, bid_RF      := rf_oof_preds(poolA, IMHOF_FEATS, fold_random)]
poolA[, combined_RF := rf_oof_preds(poolA, c("award_continuous", IMHOF_FEATS), fold_random)]
auc_bid  <- m_rocauc(y, poolA$bid_RF)
auc_comb <- m_rocauc(y, poolA$combined_RF)
auc_aw   <- m_rocauc(y, poolA$award_continuous)
auc_fl   <- m_rocauc(y, poolA$award_FL14)
say("RF re-run AUC: award_cont=%.4f  award_FL14=%.4f  bid_RF=%.4f  combined_RF=%.4f",
    auc_aw, auc_fl, auc_bid, auc_comb)
say("validation targets: bid_RF~0.888  combined_RF~0.962")
flag_bid  <- abs(auc_bid  - 0.888) > 0.01
flag_comb <- abs(auc_comb - 0.962) > 0.01
if (flag_bid)  say("  *** FLAG: bid_RF AUC %.4f off target 0.888 by >0.01", auc_bid)
if (flag_comb) say("  *** FLAG: combined_RF AUC %.4f off target 0.962 by >0.01", auc_comb)
fwrite(poolA[, .(firm_code, tenders_count, is_cade, award_continuous, award_FL14,
                 bid_RF, combined_RF, firm_id)],
       file.path(dir_cache, "cost_frontier_poolA_scores.csv"))
stamp("A_pool_rf")

# =============================================================================
# STAGE B. COST DENOMINATORS  (per-firm tender-item set + per-item n_bids)
# =============================================================================
# Build, once, two caches via DuckDB:
#   (1) per-firm aggregates: tender-item count, distinct buyers, distinct
#       item_groups, distinct buyer x item_group x year cells, and the firm's
#       OWN bid-row count (sum of its n_bids in firm_tender_map = LOWER BOUND).
#   (2) firm -> tender-item edge list (CNPJ in Pool A only) joined to the FULL
#       per-item n_bids (imhof_tender_features), so that for ANY survivor pool S
#       we can compute the UNION of opened tender-items and the FULL-tender bid-row
#       footprint (sum of per-item n_bids over the union).
say("\n========== STAGE B. COST DENOMINATORS (DuckDB) ==========")
suppressPackageStartupMessages({ library(DBI); library(duckdb) })
dir.create("/tmp/duckdb_spill", recursive=TRUE, showWarnings=FALSE)
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

ftm_path <- file.path(DATA, "firm_tender_map.parquet")
imt_path <- file.path(dir_cache, "imhof_tender_features.parquet")
dbWriteTable(con, "poolA", data.frame(firm_code = poolA$firm_code), overwrite = TRUE)

# per-item full n_bids (imhof) -- realistic full-tender record; missing -> 1 (a
# single-bid / unpriced item still has 1 bid row to process). State assumption.
say("building per-item full-tender n_bids view (imhof n_bids; missing item -> 1 bid row)")

# (1) per-firm aggregates over Pool A
firm_cost <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT \"códigofornecedor\" AS firm_code, numerodaoc AS oc, \"códigoitem\" AS item, n_bids AS firm_nbids
    FROM read_parquet('%s')
  ),
  jp AS (SELECT f.* FROM ftm f JOIN poolA p ON f.firm_code = p.firm_code)
  SELECT firm_code,
         COUNT(*)                                                   AS firm_tender_items,
         SUM(firm_nbids)                                            AS firm_own_bid_rows,
         COUNT(DISTINCT SUBSTR(oc,1,11))                            AS firm_buyers,
         COUNT(DISTINCT SUBSTR(item,1,2))                           AS firm_item_groups,
         COUNT(DISTINCT (SUBSTR(oc,1,11)||'|'||SUBSTR(item,1,2)||'|'||SUBSTR(oc,12,4))) AS firm_cells
  FROM jp GROUP BY firm_code", ftm_path)))
say("per-firm cost aggregates: %d firms", nrow(firm_cost))

# (2) firm -> tender-item edges (Pool A) with FULL-tender n_bids from imhof.
#     This is the heavy cache that lets us compute UNION footprints per survivor pool.
say("building firm->tender-item edge cache with full-tender n_bids ...")
edge_cache <- file.path(dir_cache, "cost_frontier_firm_item_edges.parquet")
dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE edges AS
  WITH ftm AS (
    SELECT \"códigofornecedor\" AS firm_code, numerodaoc AS oc, \"códigoitem\" AS item
    FROM read_parquet('%s')
  ),
  jp AS (SELECT f.firm_code, f.oc, f.item FROM ftm f JOIN poolA p ON f.firm_code = p.firm_code),
  im AS (SELECT numerodaoc AS oc, codigoitem AS item, n_bids FROM read_parquet('%s'))
  SELECT j.firm_code, j.oc, j.item,
         COALESCE(im.n_bids, 1) AS item_nbids_full,
         SUBSTR(j.oc,1,11) AS buyer,
         SUBSTR(j.item,1,2) AS item_group,
         SUBSTR(j.oc,12,4) AS yr
  FROM jp j LEFT JOIN im ON j.oc = im.oc AND j.item = im.item", ftm_path, imt_path))
n_edges <- dbGetQuery(con, "SELECT COUNT(*) n FROM edges")$n
say("edge rows (Pool A firm x tender-item): %s", format(n_edges, big.mark=","))
dbExecute(con, sprintf("COPY edges TO '%s' (FORMAT PARQUET, COMPRESSION 'snappy')", edge_cache))

# distinct tender-items per item id (for unioning) -- precompute item -> n_bids map
item_nbids <- as.data.table(dbGetQuery(con, "
  SELECT oc, item, ANY_VALUE(item_nbids_full) AS item_nbids_full FROM edges GROUP BY oc, item"))
say("distinct tender-items touched by Pool A: %s (total full bid rows if all opened=%s)",
    format(nrow(item_nbids), big.mark=","),
    format(sum(as.numeric(item_nbids$item_nbids_full)), big.mark=","))
stamp("B_cost_caches")

# ---- full-observability baseline (S = full Pool A) -------------------------
# When every firm record is opened, the denominators are these maxima.
full_obs <- list(
  firms_opened          = N_A,
  survivor_firm_tender_items = sum(as.numeric(firm_cost$firm_tender_items)),
  opened_tender_items   = nrow(item_nbids),
  opened_bid_rows_full  = sum(as.numeric(item_nbids$item_nbids_full)),
  survivor_bid_rows_only= sum(as.numeric(firm_cost$firm_own_bid_rows)),
  cells_opened          = NA_real_,   # filled below from union
  buyers_opened         = NA_real_,
  item_groups_opened    = NA_real_
)
# union-level cells/buyers/item_groups for full pool
full_union <- as.data.table(dbGetQuery(con, "
  SELECT COUNT(DISTINCT (buyer||'|'||item_group||'|'||yr)) AS cells,
         COUNT(DISTINCT buyer) AS buyers,
         COUNT(DISTINCT item_group) AS item_groups
  FROM edges"))
full_obs$cells_opened       <- full_union$cells
full_obs$buyers_opened      <- full_union$buyers
full_obs$item_groups_opened <- full_union$item_groups
full_obs_dt <- data.table(denominator = names(full_obs), full_obs_value = unlist(full_obs))
fwrite(full_obs_dt, file.path(dir_diag, "full_observability_costs.csv"))
say("--- full-observability baseline (S = full Pool A, N=%d) ---", N_A)
print(full_obs_dt)

# bring per-firm cost into poolA (firms with no edges -> 0)
poolA <- merge(poolA, firm_cost, by = "firm_code", all.x = TRUE)
for (cc in c("firm_tender_items","firm_own_bid_rows","firm_buyers","firm_item_groups","firm_cells"))
  poolA[is.na(get(cc)), (cc) := 0L]
stamp("B_full_obs")

# =============================================================================
# COST AGGREGATOR for an arbitrary survivor set S (vector of firm_code)
# =============================================================================
# Computes the multi-denominator footprint for opening the records of firms in S.
# D1 firms ; D2 sum firm tender-items (with multiplicity) ; D3 UNIQUE opened
# tender-items ; D4 opened bid rows FULL tender (sum item n_bids over unique
# opened items) ; D5 survivor bid rows only (firms' own bids = LOWER BOUND) ;
# D6 cells ; D7 buyers ; D8 item_groups.
cost_of_pool <- function(S_codes) {
  if (length(S_codes) == 0L)
    return(list(firms_opened=0L, survivor_firm_tender_items=0, opened_tender_items=0,
                opened_bid_rows_full=0, survivor_bid_rows_only=0,
                cells_opened=0, buyers_opened=0, item_groups_opened=0))
  dbExecute(con, "CREATE OR REPLACE TEMP TABLE survS (firm_code VARCHAR)")
  DBI::dbWriteTable(con, "survS", data.frame(firm_code = S_codes), append = TRUE)
  agg <- dbGetQuery(con, "
    WITH s AS (SELECT e.* FROM edges e JOIN survS v ON e.firm_code = v.firm_code),
    items AS (SELECT oc, item, ANY_VALUE(item_nbids_full) nb FROM s GROUP BY oc, item)
    SELECT
      (SELECT COUNT(*) FROM s)                                   AS d2_firm_items,
      (SELECT COUNT(*) FROM items)                               AS d3_unique_items,
      (SELECT SUM(nb)  FROM items)                               AS d4_full_bid_rows,
      (SELECT COUNT(DISTINCT (buyer||'|'||item_group||'|'||yr)) FROM s) AS d6_cells,
      (SELECT COUNT(DISTINCT buyer) FROM s)                      AS d7_buyers,
      (SELECT COUNT(DISTINCT item_group) FROM s)                 AS d8_item_groups")
  # D5 survivor-own bid rows from per-firm cache (fast, no join)
  d5 <- sum(as.numeric(firm_cost[firm_code %in% S_codes]$firm_own_bid_rows), na.rm=TRUE)
  list(firms_opened = length(S_codes),
       survivor_firm_tender_items = as.numeric(agg$d2_firm_items),
       opened_tender_items        = as.numeric(agg$d3_unique_items),
       opened_bid_rows_full       = as.numeric(agg$d4_full_bid_rows),
       survivor_bid_rows_only     = d5,
       cells_opened       = as.numeric(agg$d6_cells),
       buyers_opened      = as.numeric(agg$d7_buyers),
       item_groups_opened = as.numeric(agg$d8_item_groups))
}

# =============================================================================
# STAGE C. RANKING RULES + GRIDS
# =============================================================================
say("\n========== STAGE C. RANKING RULES + GRIDS ==========")
# deterministic ranking: score desc, tiebreak firm_id (stable) then firm_code
rank_codes <- function(score, tiebreak = poolA$firm_id) {
  o <- order(-score, tiebreak, poolA$firm_code)
  poolA$firm_code[o]
}
K1_GRID    <- c(250,500,1000,1500,2000,3000,5000,7500, N_A)
FINALK_GRID<- c(100,250,500,1000)
pos_set <- poolA[is_cade==1L]$firm_code

# survivor pool by an award rule cut at K1
survivor_by_award <- function(rule = c("continuous","FL14"), K1) {
  rule <- match.arg(rule)
  if (rule == "continuous") {
    ranked <- rank_codes(poolA$award_continuous)
  } else {
    # FL14: keep FL14==1 firms; tiebreak by continuous, then firm_id
    sc <- poolA$award_FL14 + 1e-9 * (poolA$award_continuous / max(poolA$award_continuous))
    ranked <- rank_codes(sc)
  }
  ranked[seq_len(min(K1, length(ranked)))]
}

# feasibility grid
feas <- CJ(K1 = K1_GRID, k = FINALK_GRID)[k <= K1]
feas[, feasible := TRUE]
fwrite(feas, file.path(dir_diag, "cost_frontier_grid_feasibility.csv"))
say("K1 grid: %s", paste(K1_GRID, collapse=","))
say("final-k grid: %s ; feasible (k<=K1) combos: %d", paste(FINALK_GRID, collapse=","), nrow(feas))
stamp("C_rules_grids")

# =============================================================================
# STAGE D. FRONTIER METRICS (pool x rule x K1 x k)
# =============================================================================
say("\n========== STAGE D. FRONTIER GRID ==========")
# helper: metrics for a ranked top-k list against positives
topk_metrics <- function(ranked_codes, k, P = length(pos_set)) {
  topk <- ranked_codes[seq_len(min(k, length(ranked_codes)))]
  tp <- sum(topk %in% pos_set); fp <- length(topk) - tp; fn <- P - tp
  prec <- tp / length(topk); rec <- tp / P
  base <- P / N_A
  list(tp=tp, fp=fp, fn=fn, precision=prec, recall=rec, lift = if (base>0) prec/base else NA_real_,
       k_eff = length(topk))
}

# cost cache keyed by survivor signature to avoid recomputation
cost_cache <- new.env()
cost_lookup <- function(S_codes, key) {
  if (!is.null(cost_cache[[key]])) return(cost_cache[[key]])
  v <- cost_of_pool(S_codes); cost_cache[[key]] <- v; v
}

# Joint full-obs cost = cost of opening ALL N_A firms for bid (upper bound).
cost_full <- cost_lookup(poolA$firm_code, "FULL")

# RULES:
# R2 award-only continuous (no survivor pool; rank all by award; cost = top-k firms opened... but award-only opens only the FINAL k? )
#   NB: award-only does NOT require bid recovery; its cost denominator is the
#   firms/items/bid-rows of the FINAL top-k flagged firms (no gate stage).
# R7 sequential award->bid : survivor pool S_K1 (award top-K1); recover bid for S_K1
#   (cost of OPENING bid for all K1 survivors); rerank survivors by bid_RF; final top-k.
# R8 sequential award->combined : rerank S_K1 by combined_RF.
# R10 FL14->bid : survivor = FL14 firms, rerank by bid_RF.
# R5 bid-only full-obs : rank all by bid_RF (needs full recovery -> cost_full).
# R6 joint full-obs : rank all by combined_RF (needs full recovery -> cost_full, UPPER BOUND).
# R3 award-only FL14 : final top-k from FL14 ranking.
# R1 random survivor pool: B=1000 random S_K1, rerank by bid_RF.

ranked_award      <- rank_codes(poolA$award_continuous)
ranked_fl14       <- survivor_by_award("FL14", N_A)   # full FL14-first ordering
ranked_bid_full   <- rank_codes(poolA$bid_RF)
ranked_comb_full  <- rank_codes(poolA$combined_RF)

# bid_RF / combined_RF lookups by firm_code for survivor reranking
bidmap  <- setNames(poolA$bid_RF,      poolA$firm_code)
combmap <- setNames(poolA$combined_RF, poolA$firm_code)
awmap   <- setNames(poolA$award_continuous, poolA$firm_code)

frontier_rows <- list()
emit <- function(...) frontier_rows[[length(frontier_rows)+1]] <<- data.table(...)

# ---- reduction helper vs full observability --------------------------------
red <- function(open, full) if (full>0) 1 - open/full else NA_real_

# ===== R5 bid-only full-obs, R6 joint full-obs (no gate) =====================
for (rl in c("R5_bid_only_fullobs","R6_joint_fullobs")) {
  ranked <- if (rl=="R5_bid_only_fullobs") ranked_bid_full else ranked_comb_full
  for (k in FINALK_GRID) {
    mm <- topk_metrics(ranked, k)
    # cost: full recovery required (bid features for all) -> denominators = cost_full
    cst <- cost_full
    emit(pool="A", rule=rl, K1=NA_integer_, k=k,
         positives_in_survivor=P_A, survivor_recall_before_bid=1.0,
         positives_lost_at_gate=0L, nonpositives_sent_to_bid=N_A - P_A,
         firms_opened=cst$firms_opened, survivor_firm_tender_items=cst$survivor_firm_tender_items,
         opened_tender_items=cst$opened_tender_items, opened_bid_rows_full=cst$opened_bid_rows_full,
         survivor_bid_rows_only=cst$survivor_bid_rows_only, cells_opened=cst$cells_opened,
         buyers_opened=cst$buyers_opened, item_groups_opened=cst$item_groups_opened,
         tp=mm$tp, fp=mm$fp, fn=mm$fn, precision=mm$precision, recall=mm$recall, lift=mm$lift)
  }
}

# ===== R2 award-only continuous, R3 award-only FL14 (no gate) ================
for (rl in c("R2_award_only_cont","R3_award_only_FL14")) {
  ranked <- if (rl=="R2_award_only_cont") ranked_award else ranked_fl14
  for (k in FINALK_GRID) {
    mm <- topk_metrics(ranked, k)
    topk <- ranked[seq_len(min(k, length(ranked)))]
    cst <- cost_lookup(topk, paste0(rl,"_k",k))   # award opens only final top-k
    emit(pool="A", rule=rl, K1=NA_integer_, k=k,
         positives_in_survivor=mm$tp, survivor_recall_before_bid=NA_real_,
         positives_lost_at_gate=NA_integer_, nonpositives_sent_to_bid=0L,
         firms_opened=cst$firms_opened, survivor_firm_tender_items=cst$survivor_firm_tender_items,
         opened_tender_items=cst$opened_tender_items, opened_bid_rows_full=cst$opened_bid_rows_full,
         survivor_bid_rows_only=cst$survivor_bid_rows_only, cells_opened=cst$cells_opened,
         buyers_opened=cst$buyers_opened, item_groups_opened=cst$item_groups_opened,
         tp=mm$tp, fp=mm$fp, fn=mm$fn, precision=mm$precision, recall=mm$recall, lift=mm$lift)
  }
}

# ===== R7/R8 sequential award->bid / award->combined ========================
# survivor pool S_K1 = award top-K1; cost = OPENING bid for the WHOLE S_K1 (the
# realistic gatekeeping footprint: you must pull the bid record for every survivor
# to score it). final top-k by rerank within survivors.
seq_rule <- function(rl, rerankmap) {
  for (K1 in K1_GRID) {
    S <- survivor_by_award("continuous", K1)
    pos_in_S <- sum(S %in% pos_set)
    cst <- cost_lookup(S, paste0("seqcont_K1", K1))   # bid recovery over all survivors
    # rerank survivors by the bid/combined score
    sc <- rerankmap[S]; oS <- order(-sc, match(S, poolA$firm_code))
    S_ranked <- S[oS]
    for (k in FINALK_GRID) {
      if (k > K1) next
      mm <- topk_metrics(S_ranked, k)
      emit(pool="A", rule=rl, K1=K1, k=k,
           positives_in_survivor=pos_in_S, survivor_recall_before_bid=pos_in_S/P_A,
           positives_lost_at_gate=P_A - pos_in_S, nonpositives_sent_to_bid=K1 - pos_in_S,
           firms_opened=cst$firms_opened, survivor_firm_tender_items=cst$survivor_firm_tender_items,
           opened_tender_items=cst$opened_tender_items, opened_bid_rows_full=cst$opened_bid_rows_full,
           survivor_bid_rows_only=cst$survivor_bid_rows_only, cells_opened=cst$cells_opened,
           buyers_opened=cst$buyers_opened, item_groups_opened=cst$item_groups_opened,
           tp=mm$tp, fp=mm$fp, fn=mm$fn, precision=mm$precision, recall=mm$recall, lift=mm$lift)
    }
  }
}
seq_rule("R7_seq_award_bid",      bidmap)
seq_rule("R8_seq_award_combined", combmap)

# ===== R10 FL14 -> bid ======================================================
S_fl14 <- poolA[award_FL14==1L]$firm_code
{
  pos_in_S <- sum(S_fl14 %in% pos_set)
  cst <- cost_lookup(S_fl14, "FL14_survivors")
  sc <- bidmap[S_fl14]; oS <- order(-sc, match(S_fl14, poolA$firm_code)); S_ranked <- S_fl14[oS]
  for (k in FINALK_GRID) {
    mm <- topk_metrics(S_ranked, k)
    emit(pool="A", rule="R10_FL14_bid", K1=length(S_fl14),
         k=k, positives_in_survivor=pos_in_S, survivor_recall_before_bid=pos_in_S/P_A,
         positives_lost_at_gate=P_A - pos_in_S, nonpositives_sent_to_bid=length(S_fl14)-pos_in_S,
         firms_opened=cst$firms_opened, survivor_firm_tender_items=cst$survivor_firm_tender_items,
         opened_tender_items=cst$opened_tender_items, opened_bid_rows_full=cst$opened_bid_rows_full,
         survivor_bid_rows_only=cst$survivor_bid_rows_only, cells_opened=cst$cells_opened,
         buyers_opened=cst$buyers_opened, item_groups_opened=cst$item_groups_opened,
         tp=mm$tp, fp=mm$fp, fn=mm$fn, precision=mm$precision, recall=mm$recall, lift=mm$lift)
  }
}
say("FL14 survivor pool size=%d  positives_in=%d", length(S_fl14), sum(S_fl14 %in% pos_set))

# ===== R1 random survivor pool (B=1000) =====================================
say("computing random-survivor baseline (B=1000) ...")
B_RAND <- 1000L
rand_rows <- list()
for (K1 in K1_GRID) {
  set.seed(SEED + K1)
  recs <- matrix(NA_real_, nrow=B_RAND, ncol=length(FINALK_GRID))
  pos_in_rec <- numeric(B_RAND)
  for (b in seq_len(B_RAND)) {
    S <- sample(poolA$firm_code, min(K1, N_A))
    pos_in_rec[b] <- sum(S %in% pos_set)
    sc <- bidmap[S]; oS <- order(-sc, runif(length(S))); S_ranked <- S[oS]
    for (j in seq_along(FINALK_GRID)) {
      k <- FINALK_GRID[j]; if (k>K1) { recs[b,j] <- NA; next }
      topk <- S_ranked[seq_len(min(k,length(S_ranked)))]
      recs[b,j] <- sum(topk %in% pos_set) / length(pos_set)
    }
  }
  for (j in seq_along(FINALK_GRID)) {
    k <- FINALK_GRID[j]; if (k>K1) next
    rr <- recs[,j]
    rand_rows[[length(rand_rows)+1]] <- data.table(
      K1=K1, k=k, mean_recall=mean(rr,na.rm=TRUE),
      lo95=quantile(rr,.025,na.rm=TRUE,names=FALSE), hi95=quantile(rr,.975,na.rm=TRUE,names=FALSE),
      mean_positives_in_survivor=mean(pos_in_rec))
  }
}
rand_tab <- rbindlist(rand_rows)
stamp("D_frontier_grid")

front <- rbindlist(frontier_rows, fill=TRUE)

# ---- attach reductions vs full-observability + cost-per-TP -----------------
front[, cost_reduction_firms        := red(firms_opened, full_obs$firms_opened)]
front[, cost_reduction_tender_items := red(opened_tender_items, full_obs$opened_tender_items)]
front[, cost_reduction_bid_rows     := red(opened_bid_rows_full, full_obs$opened_bid_rows_full)]
front[, cost_reduction_cells        := red(cells_opened, full_obs$cells_opened)]
front[, cost_per_TP_firms      := ifelse(tp>0, firms_opened/tp, NA_real_)]
front[, cost_per_TP_tender_items := ifelse(tp>0, opened_tender_items/tp, NA_real_)]
front[, cost_per_TP_bid_rows   := ifelse(tp>0, opened_bid_rows_full/tp, NA_real_)]

# recall_loss_vs_joint (joint full-obs at same k), recall_gain_vs_award_only
joint_recall_by_k <- front[rule=="R6_joint_fullobs", .(k, joint_recall=recall)]
award_recall_by_k <- front[rule=="R2_award_only_cont", .(k, award_recall=recall,
                                                          award_bidrows=opened_bid_rows_full)]
front <- merge(front, joint_recall_by_k, by="k", all.x=TRUE)
front <- merge(front, award_recall_by_k, by="k", all.x=TRUE)
front[, recall_loss_vs_joint_abs := joint_recall - recall]
front[, recall_loss_vs_joint_rel := ifelse(joint_recall>0, (joint_recall-recall)/joint_recall, NA_real_)]
front[, recall_gain_vs_award_only := recall - award_recall]
front[, net_TP_gain_per_1000_bid_rows_vs_award_only :=
        ifelse(!is.na(award_bidrows) & (opened_bid_rows_full-award_bidrows)!=0,
               1000*(tp - award_recall*P_A)/(opened_bid_rows_full - award_bidrows), NA_real_)]

# marginal TP / marginal cost vs previous K1 (within rule x k, ordered by K1)
setorder(front, rule, k, K1)
front[, marginal_TP := tp - shift(tp), by=.(rule,k)]
front[, marginal_cost_bid_rows := opened_bid_rows_full - shift(opened_bid_rows_full), by=.(rule,k)]
front[, marginal_cost_firms := firms_opened - shift(firms_opened), by=.(rule,k)]

fwrite(front, file.path(dir_cache, "cost_recall_frontier_full.csv"))
fwrite(front, file.path(dir_app_t, "table_G_full_cost_recall_frontier.csv"))
say("frontier grid rows: %d", nrow(front))
stamp("D_attach")

# =============================================================================
# K1=2000 REPRODUCTION CHECK
# =============================================================================
say("\n========== K1=2000 REPRODUCTION ==========")
r2000 <- front[rule=="R7_seq_award_bid" & K1==2000]
say("seq award->bid @ K1=2000:")
for (kq in FINALK_GRID) {
  rr <- r2000[k==kq]
  if (nrow(rr)) say("  k=%-4d  TP=%d  recall=%.3f  precision=%.3f  firms_opened=%d  reduce_firms=%.1f%%  reduce_items=%.1f%%  reduce_bidrows=%.1f%%",
                    kq, rr$tp, rr$recall, rr$precision, rr$firms_opened,
                    100*rr$cost_reduction_firms, 100*rr$cost_reduction_tender_items, 100*rr$cost_reduction_bid_rows)
}
say("(target: seq recovers 131/193 cobidders firm-footprint; precision@500 seq 0.192; recall@1000 seq 0.679)")
say("Pool A positives=%d (vs 193 raw, vs 190 in 09-cache; differs by defendant-exclusion)", P_A)

# =============================================================================
# COST-DENOMINATOR DEFINITIONS TABLE (appendix G)
# =============================================================================
defs <- data.table(
  id = c("D1","D2","D3","D4","D5","D6","D7","D8","D9","D10","D11"),
  denominator = c("firms_opened","survivor_firm_tender_items","opened_tender_items",
                  "opened_bid_rows_full_tender","survivor_bid_rows_only",
                  "buyer_x_item_group_x_year_cells","buyers","item_groups",
                  "lances_exports","legal_requests","analyst_hours_proxy"),
  definition = c(
    "Number of firms whose record is opened (=|S|).",
    "Sum over survivors of each firm's tender-item count (with multiplicity).",
    "Unique tender-items in the union over survivors (de-duplicated).",
    "Sum of per-tender-item TOTAL bid count over the unique opened tender-items; within-tender Imhof moments require the FULL tender record. THE realistic processing footprint.",
    "Bid rows by survivor firms only (their own bids). LOWER BOUND on bid-row burden.",
    "Unique buyer x item_group x year cells touched by survivors.",
    "Unique buyers (PBU codes) touched by survivors.",
    "Unique 2-digit item groups touched by survivors.",
    "LANCES exports: ASSUMPTION 1 tender-item = 1 export = opened_tender_items.",
    "Legal/forensic requests: NOT_OBSERVED (no data).",
    "ILLUSTRATIVE-NOT-MEASURED proxy = alpha*opened_tender_items + beta*opened_bid_rows/1000; appendix only."),
  source = c("firm_tender_map","firm_tender_map","firm_tender_map x imhof_tender_features",
             "imhof_tender_features.n_bids (missing item -> 1)","firm_tender_map.n_bids (firm-own)",
             "firm_tender_map (oc/item substr)","firm_tender_map","firm_tender_map",
             "derived (=D3)","none","derived (illustrative)"))
fwrite(defs, file.path(dir_app_t, "table_G_cost_denominator_definitions.csv"))
texdef <- c("% table_G_cost_denominator_definitions.tex (auto: 10_cost_recall_frontier.R)",
  "\\begin{tabular}{llp{8cm}l}", "\\toprule",
  "ID & Denominator & Definition & Source \\\\", "\\midrule",
  vapply(seq_len(nrow(defs)), function(i) sprintf("%s & %s & %s & %s \\\\",
    defs$id[i], gsub("_","\\\\_",defs$denominator[i]),
    gsub("_","\\\\_",defs$definition[i]), gsub("_","\\\\_",defs$source[i])), character(1)),
  "\\bottomrule","\\end{tabular}")
writeLines(texdef, file.path(dir_app_t, "table_G_cost_denominator_definitions.tex"))

# D11 illustrative analyst-hours (appendix only, LABELED illustrative) ---------
ah_params <- data.table(level=c("low","med","high"), alpha=c(0.002,0.005,0.010), beta=c(0.05,0.10,0.20))
fwrite(ah_params, file.path(dir_diag, "analyst_hours_illustrative_params.csv"))
ah <- front[rule %in% c("R2_award_only_cont","R7_seq_award_bid","R6_joint_fullobs")]
ah_long <- rbindlist(lapply(seq_len(nrow(ah_params)), function(i) {
  p <- ah_params[i]; copy(ah)[, `:=`(level=p$level,
    analyst_hours_illustrative = p$alpha*opened_tender_items + p$beta*opened_bid_rows_full/1000)][]
}), fill=TRUE)[, .(rule,K1,k,level,opened_tender_items,opened_bid_rows_full,analyst_hours_illustrative)]
fwrite(ah_long, file.path(dir_app_t, "table_G_analyst_hours_illustrative.csv"))
stamp("E_defs")

# =============================================================================
# STAGE E. MAIN TABLE 6 (compact)
# =============================================================================
say("\n========== STAGE E. MAIN TABLE 6 ==========")
build_panel <- function(kk) {
  rows <- list()
  add <- function(rule_label, dt) {
    if (!nrow(dt)) return(invisible())
    rows[[length(rows)+1]] <<- data.table(
      rule=rule_label, K1=ifelse(is.na(dt$K1),NA_integer_,dt$K1), k=dt$k,
      firms_opened=dt$firms_opened, opened_tender_items=dt$opened_tender_items,
      opened_bid_rows=dt$opened_bid_rows_full, TP=dt$tp, FP=dt$fp,
      positives_missed=P_A - dt$tp, precision=dt$precision, recall=dt$recall, lift=dt$lift,
      cost_reduction_firms=dt$cost_reduction_firms, cost_reduction_bid_rows=dt$cost_reduction_bid_rows,
      recall_loss_vs_joint=dt$recall_loss_vs_joint_abs, cost_per_TP_bid_rows=dt$cost_per_TP_bid_rows)
  }
  add("Award-only (continuous)", front[rule=="R2_award_only_cont" & k==kk])
  add("Bid-only (full obs)",     front[rule=="R5_bid_only_fullobs" & k==kk])
  add("Joint (full obs, upper bound)", front[rule=="R6_joint_fullobs" & k==kk])
  for (K1q in c(500,1000,2000,3000,5000))
    add(sprintf("Sequential award->bid (K1=%d)", K1q),
        front[rule=="R7_seq_award_bid" & K1==K1q & k==kk])
  rbindlist(rows, fill=TRUE)
}
panelA <- build_panel(500)
panelB <- build_panel(1000)
tab6 <- rbind(cbind(panel="A (k=500)", panelA), cbind(panel="B (k=1000)", panelB), fill=TRUE)
fwrite(tab6, file.path(dir_main_t, "table_6_cost_recall_frontier.csv"))
say("--- Table 6 Panel A (k=500) ---")
print(panelA[, .(rule, K1, firms_opened, opened_bid_rows, TP, recall=round(recall,3),
                 prec=round(precision,3), red_firms=round(cost_reduction_firms,3),
                 red_bidrows=round(cost_reduction_bid_rows,3))])

fmt <- function(x,d=3) ifelse(is.na(x),"--",formatC(x,format="f",digits=d))
fmti <- function(x) ifelse(is.na(x),"--",formatC(x,format="d",big.mark=","))
mk_tex_rows <- function(dt) vapply(seq_len(nrow(dt)), function(i) sprintf(
  "%s & %s & %d & %s & %s & %s & %d & %d & %d & %s & %s & %s & %s & %s & %s & %s \\\\",
  gsub("->","$\\\\to$",gsub("_","\\\\_",dt$rule[i])),
  ifelse(is.na(dt$K1[i]),"--",formatC(dt$K1[i],format="d",big.mark=",")), dt$k[i],
  fmti(dt$firms_opened[i]), fmti(dt$opened_tender_items[i]), fmti(dt$opened_bid_rows[i]),
  dt$TP[i], dt$FP[i], dt$positives_missed[i], fmt(dt$precision[i]), fmt(dt$recall[i]),
  fmt(dt$lift[i],1), fmt(dt$cost_reduction_firms[i]), fmt(dt$cost_reduction_bid_rows[i]),
  fmt(dt$recall_loss_vs_joint[i]), fmt(dt$cost_per_TP_bid_rows[i],0)), character(1))
tex6 <- c("% table_6_cost_recall_frontier.tex (auto: 10_cost_recall_frontier.R)",
  "% TABLENOTE: target = adjudication-anchored exposure (NOT membership). Bid/joint",
  "% rules require full observability; sequential recovers bid only for survivors.",
  "% Reductions are vs full observability over Pool A. Firm count is NOT the only",
  "% denominator: opened tender-items / bid-rows better approximate forensic burden,",
  "% and the bid-row reduction is SMALLER than the firm reduction. FPs are non-labeled",
  "% firms, NOT exonerated. ROC is not the decision metric.",
  "\\begin{tabular}{llrrrrrrrccccccr}", "\\toprule",
  "Rule & $K_1$ & $k$ & Firms & Items & BidRows & TP & FP & Miss & Prec & Rec & Lift & $\\Delta$Firms & $\\Delta$Bid & RecLoss & \\$/TP \\\\",
  "\\midrule", "\\multicolumn{16}{l}{\\textit{Panel A: final $k=500$}} \\\\",
  mk_tex_rows(panelA), "\\midrule",
  "\\multicolumn{16}{l}{\\textit{Panel B: final $k=1000$}} \\\\",
  mk_tex_rows(panelB), "\\bottomrule","\\end{tabular}")
writeLines(tex6, file.path(dir_main_t, "table_6_cost_recall_frontier.tex"))
stamp("E_table6")

# =============================================================================
# STAGE F. FIGURES
# =============================================================================
if (ok_ggplot) {
say("\n========== STAGE F. FIGURES ==========")
# MAIN Fig 3: x = opened_bid_rows_full, y = recall vs cobidders
fig_k <- 500L
fr_main <- front[k==fig_k]
seq_b   <- fr_main[rule=="R7_seq_award_bid"][order(opened_bid_rows_full)]
seq_c   <- fr_main[rule=="R8_seq_award_combined"][order(opened_bid_rows_full)]
aw_pt   <- fr_main[rule=="R2_award_only_cont"]
bid_pt  <- fr_main[rule=="R5_bid_only_fullobs"]
joint_pt<- fr_main[rule=="R6_joint_fullobs"]
plt <- rbind(
  seq_b[, .(opened_bid_rows_full, recall, series="Sequential award->bid", type="line", K1)],
  seq_c[, .(opened_bid_rows_full, recall, series="Sequential award->combined", type="line", K1)],
  aw_pt[, .(opened_bid_rows_full, recall, series="Award-only", type="point", K1=NA)],
  bid_pt[, .(opened_bid_rows_full, recall, series="Bid-only (full obs)", type="point", K1=NA)],
  joint_pt[,.(opened_bid_rows_full, recall, series="Joint (full obs)", type="point", K1=NA)], fill=TRUE)
p3 <- ggplot() +
  geom_line(data=plt[type=="line"], aes(opened_bid_rows_full, recall, colour=series), linewidth=0.8) +
  geom_point(data=plt[type=="line"], aes(opened_bid_rows_full, recall, colour=series), size=2) +
  geom_point(data=plt[type=="point"], aes(opened_bid_rows_full, recall, colour=series), size=3.4, shape=17) +
  scale_x_continuous(labels=function(x) format(x, big.mark=",", scientific=FALSE)) +
  labs(x="Opened bid rows (full-tender record; realistic forensic cost)",
       y=sprintf("Recall of CADE cobidders (final k=%d)", fig_k), colour=NULL,
       title="Cost-recall frontier: sequential gatekeeping vs full observability",
       subtitle="Each sequential point = a first-stage cut K1. Bid/joint require opening all records (full obs).",
       caption="Alt text: recall vs opened bid rows; sequential award->bid and award->combined trace a frontier as K1 grows, approaching the joint full-observability point at far higher cost.") +
  theme_bw() + theme(legend.position="bottom")
ggsave(file.path(dir_main_f, "fig_3_cost_recall_frontier.pdf"), p3, width=8.5, height=5.2, device=cairo_pdf)
say("wrote fig_3_cost_recall_frontier.pdf")

# tender-item version (less skewed alternative)
p3b <- p3 + aes() ; p3b <- ggplot() +
  geom_line(data=front[k==fig_k & rule=="R7_seq_award_bid"][order(opened_tender_items)],
            aes(opened_tender_items, recall), colour="#1b9e77", linewidth=0.8) +
  geom_point(data=front[k==fig_k & rule=="R7_seq_award_bid"], aes(opened_tender_items, recall), colour="#1b9e77", size=2) +
  geom_point(data=front[k==fig_k & rule=="R6_joint_fullobs"], aes(opened_tender_items, recall), colour="#d95f02", size=3.4, shape=17) +
  geom_point(data=front[k==fig_k & rule=="R2_award_only_cont"], aes(opened_tender_items, recall), colour="#7570b3", size=3.4, shape=17) +
  labs(x="Opened tender-items (alternative cost denominator)", y=sprintf("Recall (k=%d)", fig_k),
       title="Cost-recall frontier (tender-item denominator)",
       caption="Alt text: recall vs opened tender-items for sequential award->bid, with joint and award-only reference points.") +
  theme_bw()
ggsave(file.path(dir_app_f, "fig_G_cost_recall_tender_items.pdf"), p3b, width=8, height=5, device=cairo_pdf)

# Appendix: cost-precision, cost-per-TP, marginal cost per TP, FP frontier
seqg <- front[rule=="R7_seq_award_bid" & k==fig_k][order(K1)]
pp <- ggplot(seqg, aes(opened_bid_rows_full, precision)) + geom_line() + geom_point() +
  labs(x="Opened bid rows", y="Precision@500", title="Cost-precision frontier (sequential award->bid)",
       caption="Alt text: precision vs opened bid rows along K1.") + theme_bw()
ggsave(file.path(dir_app_f, "fig_G_cost_precision.pdf"), pp, width=7.5, height=4.6, device=cairo_pdf)
pc <- ggplot(seqg, aes(K1, cost_per_TP_bid_rows)) + geom_line() + geom_point() +
  labs(x="First-stage cut K1", y="Bid rows opened per true positive",
       title="Cost-per-TP (bid rows) along K1", caption="Alt text: bid rows per TP vs K1.") + theme_bw()
ggsave(file.path(dir_app_f, "fig_G_cost_per_TP.pdf"), pc, width=7.5, height=4.6, device=cairo_pdf)
pm <- ggplot(seqg[!is.na(marginal_TP)], aes(K1, marginal_cost_bid_rows/pmax(marginal_TP,1e-9))) +
  geom_line() + geom_point() +
  labs(x="First-stage cut K1", y="Marginal bid rows per marginal TP",
       title="Marginal cost per marginal TP (sequential award->bid)",
       caption="Alt text: marginal bid rows per marginal TP vs K1; rises steeply as K1 grows.") + theme_bw()
ggsave(file.path(dir_app_f, "fig_G_marginal_cost_per_TP.pdf"), pm, width=7.5, height=4.6, device=cairo_pdf)
pf <- ggplot(seqg, aes(K1)) +
  geom_line(aes(y=nonpositives_sent_to_bid, colour="non-positives sent to bid recovery")) + geom_point(aes(y=nonpositives_sent_to_bid, colour="non-positives sent to bid recovery")) +
  geom_line(aes(y=fp, colour="final top-k false positives")) + geom_point(aes(y=fp, colour="final top-k false positives")) +
  labs(x="First-stage cut K1", y="Count", colour=NULL, title="False-positive frontier (two FP types)",
       caption="Alt text: non-positives sent to bid recovery grows ~linearly with K1; final top-k FPs flat.") +
  theme_bw() + theme(legend.position="bottom")
ggsave(file.path(dir_app_f, "fig_G_false_positive_frontier.pdf"), pf, width=8, height=4.8, device=cairo_pdf)
say("wrote 5 appendix figures")
stamp("F_figures")
} else say("ggplot2 unavailable: skipping figures")

# =============================================================================
# STAGE G. BASELINES + OPERATING POINTS + CASE-HOLDOUT + TIMING
# =============================================================================
say("\n========== STAGE G. BASELINES / OPERATING POINTS / CASE-HOLDOUT ==========")
# award-only survivor recall by K1 (how many positives ALREADY captured before bid rerank)
aw_surv <- rbindlist(lapply(K1_GRID, function(K1) {
  S <- survivor_by_award("continuous", K1)
  data.table(K1=K1, award_survivor_recall = sum(S %in% pos_set)/P_A,
             positives_in_survivor=sum(S %in% pos_set))
}))
base_tab <- merge(rand_tab, aw_surv, by="K1", all=TRUE)
fwrite(base_tab, file.path(dir_app_t, "table_G_random_and_award_only_baselines.csv"))
say("--- award-only survivor recall vs random, by K1 (k=500) ---")
print(base_tab[k==500, .(K1, award_survivor_recall=round(award_survivor_recall,3),
                         rand_mean=round(mean_recall,3), rand_hi=round(hi95,3))])

# operating points: Pareto efficiency on (opened_bid_rows_full, recall) at k=500, sequential
op <- front[rule=="R7_seq_award_bid" & k %in% c(500,1000)][order(k, opened_bid_rows_full)]
op[, dominated_by := NA_character_]
op[, pareto_efficient := TRUE]
for (kk in unique(op$k)) {
  sub <- op[k==kk]; setorder(sub, opened_bid_rows_full)
  best <- -Inf
  for (i in seq_len(nrow(sub))) {
    if (sub$recall[i] <= best) { sub$pareto_efficient[i] <- FALSE }
    else best <- sub$recall[i]
  }
  op[k==kk, pareto_efficient := sub$pareto_efficient]
}
op[, marginal_cost_per_marginal_TP := marginal_cost_bid_rows/pmax(marginal_TP,1e-9)]
op[, recommended_use_case := fcase(
  K1<=500, "low-capacity / high-precision",
  K1<=2000, "balanced",
  default="high-recall / high-capacity")]
fwrite(op[, .(rule,K1,k,opened_bid_rows_full,firms_opened,tp,recall,precision,
              pareto_efficient,marginal_cost_per_marginal_TP,recommended_use_case)],
       file.path(dir_app_t, "table_G_operating_points.csv"))

# ---- CASE-HOLDOUT GATEKEEPING (Pool D) -------------------------------------
# Use case map: each positive -> primary CADE case. Leave-one-case-out: hold out
# a case's positives, run the gatekeeper, measure recovered TP/precision/recall/cost
# of held-out positives. award score is label-independent (no retrain); bid_RF is
# OOF from random folds (reused). This evaluates whether the frontier holds when
# the largest case is removed.
ccm <- tryCatch(fread(file.path(REPO, "output", "label_funnel", "case_cobidder_map.csv"),
                      colClasses=list(character=c("cnpj","proc"))), error=function(e) NULL)
if (!is.null(ccm)) {
  ccm[, firm_code := norm14(cnpj)]
  pos_in_pool <- poolA[is_cade==1L]$firm_code
  clc <- ccm[firm_code %in% pos_in_pool, .N, by=.(firm_code, proc, jdate)]
  setorder(clc, firm_code, -N, jdate)
  primary_case <- clc[, .SD[1], by=firm_code][, .(firm_code, proc)]
  case_pos <- primary_case[, .N, by=proc][order(-N)]
  say("case linkage: %d/%d positives linked; cases:", uniqueN(primary_case$firm_code), length(pos_in_pool))
  for (i in seq_len(nrow(case_pos))) say("  %-22s : %d", case_pos$proc[i], case_pos$N[i])
  largest_case <- case_pos$proc[1]
  ch_rows <- list()
  for (cse in c("ALL", case_pos$proc)) {
    held <- if (cse=="ALL") character(0) else primary_case[proc==cse]$firm_code
    # evaluation positives: held-out case's positives (or all if ALL)
    eval_pos <- if (cse=="ALL") pos_in_pool else held
    # sequential gatekeeper at K1=2000 (anchor) then k=500
    for (K1 in c(1000,2000,5000)) {
      S <- survivor_by_award("continuous", K1)
      sc <- bidmap[S]; oS <- order(-sc, match(S, poolA$firm_code)); S_ranked <- S[oS]
      topk <- S_ranked[seq_len(min(500,length(S_ranked)))]
      tp <- sum(topk %in% eval_pos); P_e <- length(eval_pos)
      cst <- cost_lookup(S, paste0("seqcont_K1",K1))
      ch_rows[[length(ch_rows)+1]] <- data.table(
        held_out_case = cse, K1=K1, k=500, eval_positives=P_e,
        TP=tp, precision=tp/length(topk), recall=ifelse(P_e>0,tp/P_e,NA_real_),
        opened_bid_rows_full=cst$opened_bid_rows_full, firms_opened=cst$firms_opened,
        is_largest_case = (cse==largest_case))
    }
  }
  ch <- rbindlist(ch_rows)
  fwrite(ch, file.path(dir_app_t, "table_G_case_holdout_cost_recall.csv"))
  say("--- case-holdout (seq award->bid, k=500) ---")
  print(ch[K1==2000, .(held_out_case=substr(held_out_case,1,20), eval_positives, TP,
                       recall=round(recall,3), precision=round(precision,3))])
  # leave-largest-case-out summary: recall on REMAINING positives w/ largest case removed
  remaining_pos <- setdiff(pos_in_pool, primary_case[proc==largest_case]$firm_code)
  S2k <- survivor_by_award("continuous", 2000)
  sc <- bidmap[S2k]; oS <- order(-sc, match(S2k, poolA$firm_code)); top500 <- S2k[oS][1:500]
  llco_tp <- sum(top500 %in% remaining_pos)
  say("leave-largest-case-out: largest=%s removes %d positives; remaining=%d; seq K1=2000 k=500 recovers %d (recall=%.3f)",
      largest_case, length(primary_case[proc==largest_case]$firm_code), length(remaining_pos),
      llco_tp, llco_tp/length(remaining_pos))
} else say("case map not found: skipping case-holdout")

# ---- TIMING: award-only strict 2009-16 -> 2017-19 (cheap) ------------------
# award score = log1p(tenders_count) is built over the FULL window; a strict
# timing variant needs tenders_count restricted to 2009-2016. Build it from
# firm_tender_map years. Sequential timing (bid strict-timing) is BLOCKED per Sub8.
say("\n--- timing: award-only strict 2009-2016 award score ---")
tc_train <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (SELECT \"códigofornecedor\" AS firm_code, numerodaoc AS oc FROM read_parquet('%s'))
  SELECT f.firm_code, COUNT(*) AS tc_train
  FROM ftm f JOIN poolA p ON f.firm_code=p.firm_code
  WHERE CAST(SUBSTR(f.oc,12,4) AS INTEGER) BETWEEN 2009 AND 2016
  GROUP BY f.firm_code", ftm_path)))
poolT <- merge(poolA[, .(firm_code, is_cade)], tc_train, by="firm_code", all.x=TRUE)
poolT[is.na(tc_train), tc_train := 0L]
poolT[, award_train := log1p(tc_train)]
auc_train <- m_rocauc(poolT$is_cade, poolT$award_train)
auc_fullw <- m_rocauc(poolA$is_cade, poolA$award_continuous)
say("award-only AUC: strict 2009-16 score=%.4f  vs full-window=%.4f", auc_train, auc_fullw)
timing_tab <- data.table(
  scenario=c("award_full_window","award_strict_2009_2016"),
  auc=c(auc_fullw, auc_train),
  note=c("full-window award score","strict pre-period award score (timing-honest)"))
# sequential timing: BLOCKED
timing_block <- data.table(scenario="sequential_strict_timing", status="BLOCKED",
  reason="bid strict-timing infeasible (Sub8): bid features built over full window; cannot re-derive pre-period bid moments without re-pipelining LANCES.")
fwrite(timing_tab, file.path(dir_app_t, "table_G_timing_award_only.csv"))
fwrite(timing_block, file.path(dir_diag, "timing_sequential_blocked.csv"))
stamp("G_baselines")

dbDisconnect(con, shutdown=TRUE)

# =============================================================================
# DONE
# =============================================================================
say("\n========== DONE ==========")
say("outputs:")
for (f in c(
  file.path(dir_main_t, "table_6_cost_recall_frontier.csv"),
  file.path(dir_main_t, "table_6_cost_recall_frontier.tex"),
  file.path(dir_app_t,  "table_G_full_cost_recall_frontier.csv"),
  file.path(dir_app_t,  "table_G_cost_denominator_definitions.csv"),
  file.path(dir_app_t,  "table_G_random_and_award_only_baselines.csv"),
  file.path(dir_app_t,  "table_G_operating_points.csv"),
  file.path(dir_app_t,  "table_G_case_holdout_cost_recall.csv"),
  file.path(dir_app_t,  "table_G_timing_award_only.csv"),
  file.path(dir_app_t,  "table_G_analyst_hours_illustrative.csv"),
  file.path(dir_diag,   "full_observability_costs.csv"),
  file.path(dir_diag,   "cost_frontier_grid_feasibility.csv"),
  file.path(dir_cache,  "cost_recall_frontier_full.csv"),
  file.path(dir_cache,  "cost_frontier_poolA_scores.csv"),
  file.path(dir_main_f, "fig_3_cost_recall_frontier.pdf")))
  say("  %s", f)
say("elapsed total=%.1fs", as.numeric(difftime(Sys.time(),.t0,units="secs")))
