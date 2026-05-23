#!/usr/bin/env Rscript
# ============================================================================
# an006_strict_holdout.R  —  AN-006 strict prospective holdout
# Paper 3 v20 / federal cross-jurisdiction replication
#
# Purpose: build FL classifier from train-period data ONLY, then predict
# cobidder labels from test-period data. Strict temporal cut prevents
# information leakage from future cobidder labels into the classifier.
#
# BEC reference (from `\valAUCFLfirmHoldout`-style numbers, paper):
#   AN-006 firm-level holdout AUC: 0.79–0.85.
#   Source: `scripts/27_strict_prospective_holdout.R`-equivalent.
#
# Federal split: train 2013–2016 (31.4M rows), test 2017–2019 (19.9M rows).
# BEC split (paper): train 2009–2016, test 2017–2019.
#
# Design:
#   - Pool: always-losers in TRAIN period (zero wins through 2016).
#   - Classifier: fl_train_binary = (tenders_count_train >= train_threshold),
#                 log_tc_train continuous (log1p(tenders_count_train)).
#   - Label: is_cobidder_test = 1 if firm appears in same (tender, item) as
#            a CADE direct defendant DURING 2017-2019.
#   - AUC over the always-loser-in-train pool.
#
# Output: work/v20-comprasnet/output/an006_{bec,comprasnet}/an006_results.{json,csv}
# ============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(duckdb); library(DBI)
})

args   <- commandArgs(trailingOnly = TRUE)
source <- if (length(args) > 0 && args[1] %in% c("bec","comprasnet")) {
  args[1]
} else {
  stop("usage: an006_strict_holdout.R {bec|comprasnet}")
}

script_path <- (function() {
  cargs <- commandArgs(trailingOnly = FALSE)
  hit <- grep("--file=", cargs, value = TRUE)
  if (length(hit) > 0L) sub("--file=", "", hit[1]) else NA_character_
})()
ROOT <- if (!is.na(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", "..", ".."), mustWork = FALSE)
} else {
  getwd()
}
if (!file.exists(file.path(ROOT, "scripts", "00_master.R"))) ROOT <- getwd()
setwd(ROOT)

cat(sprintf("[AN-006] source=%s\n", source))

# Helper: build train/test partition + run AUC
auc_with_ci <- function(labels, scores) {
  r  <- pROC::roc(labels, scores, quiet = TRUE)
  list(auc = as.numeric(pROC::auc(r)),
       ci  = as.numeric(pROC::ci(r)))
}

run_federal <- function() {
  con <- dbConnect(duckdb())
  dbExecute(con, "PRAGMA threads=12; PRAGMA memory_limit='14GB'")

  PANEL   <- file.path(ROOT, "data/processed_comprasnet/bid_level_full_year.parquet")
  DIRECTS <- file.path(ROOT, "data/processed_comprasnet/cade_link_v1/direct_defendants_federal.parquet")
  COBID   <- file.path(ROOT, "data/processed_comprasnet/cade_link_v1/cobidders_federal.parquet")

  # ---- TRAIN: 2013-2016 firm-level aggregation ---------------------------
  cat("\n  building train (2013-2016) firm stats ...\n")
  train_stats <- dbGetQuery(con, sprintf("
    SELECT
      códigofornecedor AS firm_code,
      COUNT(*) AS n_part_train,
      SUM(flagvencedor) AS n_wins_train,
      CAST(SUM(flagvencedor) AS DOUBLE) / COUNT(*) AS win_rate_train,
      CASE WHEN SUM(flagvencedor) = 0 THEN 1 ELSE 0 END AS always_loser_train,
      SUM(CASE WHEN flagvencedor = 0 THEN 1 ELSE 0 END) AS tenders_count_train
    FROM '%s'
    WHERE year BETWEEN 2013 AND 2016
    GROUP BY códigofornecedor
  ", PANEL))
  setDT(train_stats)
  cat(sprintf("    train firms:           %s\n", format(nrow(train_stats), big.mark = ",")))
  cat(sprintf("    train always-losers:   %s\n",
              format(sum(train_stats$always_loser_train), big.mark = ",")))

  # ---- Train-period FL threshold via IQR over train always-losers --------
  al_train_tc <- train_stats[always_loser_train == 1L, tenders_count_train]
  qts <- quantile(al_train_tc, c(0.25, 0.5, 0.75))
  thresh_train <- as.integer(qts[2] + 1.5 * (qts[3] - qts[1]))
  cat(sprintf("    train-period IQR threshold (median+1.5*IQR): %d\n", thresh_train))

  train_stats[, fl_binary_train :=
    as.integer(always_loser_train == 1L & tenders_count_train >= thresh_train)]
  train_stats[, log_tc_train := log1p(tenders_count_train)]

  # ---- TEST GROUND TRUTHS: two variants ----------------------------------
  cat("\n  computing two ground-truth variants ...\n")
  directs <- as.data.table(read_parquet(DIRECTS))
  suppressWarnings(directs[, firm_code := sprintf("%014.0f", as.numeric(firm_id))])
  direct_codes <- unique(directs$firm_code)
  direct_codes_quoted <- paste(sprintf("'%s'", direct_codes), collapse = ",")

  # Ground truth A — BEC-STYLE (paper script 27 spirit):
  # cobidders = all-period cobidder set from cade_link_v1.
  cobid_all <- as.data.table(read_parquet(COBID))
  suppressWarnings(cobid_all[, firm_code := sprintf("%014.0f", as.numeric(firm_id))])
  cobid_all_codes <- unique(cobid_all$firm_code)
  cat(sprintf("    GT-A (BEC-style, all-period cobidders):    %d\n",
              length(cobid_all_codes)))

  # Ground truth B — ULTRA-STRICT (my original impl):
  # cobidders = firms appearing in same (tender, item) as ANY direct
  # defendant DURING the 2017-2019 test period only.
  dbExecute(con, sprintf("
    CREATE OR REPLACE TABLE anchored_test AS
    SELECT DISTINCT numerodaoc, códigoitem
    FROM '%s'
    WHERE year BETWEEN 2017 AND 2019
      AND códigofornecedor IN (%s)
  ", PANEL, direct_codes_quoted))
  n_anch_test <- dbGetQuery(con, "SELECT COUNT(*) FROM anchored_test")[[1]]

  cobid_test <- dbGetQuery(con, sprintf("
    SELECT DISTINCT bl.códigofornecedor AS firm_code
    FROM '%s' bl
    JOIN anchored_test atn
      ON bl.numerodaoc = atn.numerodaoc AND bl.códigoitem = atn.códigoitem
    WHERE bl.year BETWEEN 2017 AND 2019
      AND bl.códigofornecedor NOT IN (%s)
  ", PANEL, direct_codes_quoted))
  cobid_test_codes <- cobid_test$firm_code
  cat(sprintf("    GT-B (ultra-strict, test-period cobidders): %d\n",
              length(cobid_test_codes)))
  cat(sprintf("       (from %d test-period anchored tender-items)\n", n_anch_test))

  dbDisconnect(con, shutdown = TRUE)

  # ---- Apply both labels to train firms ----------------------------------
  train_stats[, is_cobid_A_all  := as.integer(firm_code %in% cobid_all_codes)]
  train_stats[, is_cobid_B_test := as.integer(firm_code %in% cobid_test_codes)]

  # ---- AUC over always-losers-in-train pool ------------------------------
  al_train <- train_stats[always_loser_train == 1L]
  pool_n   <- nrow(al_train)
  pos_A    <- sum(al_train$is_cobid_A_all)
  pos_B    <- sum(al_train$is_cobid_B_test)
  cat(sprintf("\n  scoring pool (always-loser-in-train):     %s firms\n",
              format(pool_n, big.mark = ",")))
  cat(sprintf("    positives in GT-A (all-period cobidders): %d\n", pos_A))
  cat(sprintf("    positives in GT-B (test-period cobidders): %d\n", pos_B))

  if (pos_A < 5L) stop("GT-A: too few positives")
  if (pos_B < 5L) stop("GT-B: too few positives")

  rA_b <- auc_with_ci(al_train$is_cobid_A_all,  al_train$fl_binary_train)
  rA_c <- auc_with_ci(al_train$is_cobid_A_all,  al_train$log_tc_train)
  rB_b <- auc_with_ci(al_train$is_cobid_B_test, al_train$fl_binary_train)
  rB_c <- auc_with_ci(al_train$is_cobid_B_test, al_train$log_tc_train)

  cat(sprintf("\n  === BEC-STYLE (GT-A: all-period cobidders, paper-equivalent) ===\n"))
  cat(sprintf("  AUC FL%d binary  (train→all-cobid)   = %.4f [%.4f, %.4f]\n",
              thresh_train, rA_b$auc, rA_b$ci[1], rA_b$ci[3]))
  cat(sprintf("  AUC log_tc cont (train→all-cobid)   = %.4f [%.4f, %.4f]\n",
              rA_c$auc, rA_c$ci[1], rA_c$ci[3]))
  cat(sprintf("  BEC paper reference: 0.79-0.85\n"))

  cat(sprintf("\n  === ULTRA-STRICT (GT-B: test-period cobidders only) ===\n"))
  cat(sprintf("  AUC FL%d binary  (train→test-cobid)  = %.4f [%.4f, %.4f]\n",
              thresh_train, rB_b$auc, rB_b$ci[1], rB_b$ci[3]))
  cat(sprintf("  AUC log_tc cont (train→test-cobid)  = %.4f [%.4f, %.4f]\n",
              rB_c$auc, rB_c$ci[1], rB_c$ci[3]))

  list(
    threshold_train         = thresh_train,
    pool_size               = pool_n,
    n_positives_A_all       = pos_A,
    n_positives_B_test      = pos_B,
    # GT-A: BEC-style (all-period cobidders)
    auc_binary_A            = rA_b$auc,
    ci_A_b_lo               = rA_b$ci[1], ci_A_b_hi = rA_b$ci[3],
    auc_continuous_A        = rA_c$auc,
    ci_A_c_lo               = rA_c$ci[1], ci_A_c_hi = rA_c$ci[3],
    # GT-B: ultra-strict (test-period cobidders only)
    auc_binary_B            = rB_b$auc,
    ci_B_b_lo               = rB_b$ci[1], ci_B_b_hi = rB_b$ci[3],
    auc_continuous_B        = rB_c$auc,
    ci_B_c_lo               = rB_c$ci[1], ci_B_c_hi = rB_c$ci[3],
    n_anchored_tenders_test = n_anch_test,
    n_cobidders_all         = length(cobid_all_codes),
    n_cobidders_test        = length(cobid_test_codes)
  )
}

run_bec <- function() {
  # BEC pipeline mirrors federal but uses the canonical data sources.
  # We do not have a year-stamped BEC parquet here, so we approximate
  # by reading firm_tender_map.parquet + bid_level_full.parquet and
  # using the OC code year extraction logic from CLAUDE.md (chars 12-15
  # of po_item_merge_key). For this validation pass we accept that the
  # BEC AN-006 reference value (0.79-0.85) was published from a script
  # that operates on the same data lake; we replicate via a simpler
  # firm-level proxy: drop firms whose entire activity is concentrated
  # in test years (no train participation), then run AUC analogously.
  #
  # The proxy match should fall within the published 0.79-0.85 range
  # if the temporal logic is sound.

  fp <- as.data.table(read_parquet(
    file.path(ROOT, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
  suppressWarnings(fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))])

  cobid <- fread(file.path(ROOT, "data/processed/cade_fl_cobidders.csv"))
  cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
  cobid_codes <- unique(cobid$firm_code)

  # BEC version uses the existing all-period tenders_count as a proxy
  # for "train-period activity" — this is a simplification; the strict
  # paper version would compute tc_train from /tmp/p3_prepared.rds with
  # year filtering. We log the proxy explicitly.
  cat("\n  BEC mode: PROXY validation only — uses all-period tenders_count.\n")
  cat("  For a strict BEC reproduction, port the train-period filter from\n")
  cat("  `scripts/27_strict_prospective_holdout.R` if present.\n")

  thresh <- 14L
  al <- fp[always_loser == 1L]
  al[, fl_binary := as.integer(tenders_count >= thresh)]
  al[, log_tc    := log1p(tenders_count)]
  al[, is_cobidder := as.integer(firm_code %in% cobid_codes)]
  cat(sprintf("\n  BEC pool (always-losers):       %s firms\n",
              format(nrow(al), big.mark = ",")))
  cat(sprintf("  positives:                       %d\n", sum(al$is_cobidder)))

  r_b <- auc_with_ci(al$is_cobidder, al$fl_binary)
  r_c <- auc_with_ci(al$is_cobidder, al$log_tc)
  cat(sprintf("\n  AUC FL14 binary (all-period)   = %.4f [%.4f, %.4f]\n",
              r_b$auc, r_b$ci[1], r_b$ci[3]))
  cat(sprintf("  AUC log_tc cont (all-period)   = %.4f [%.4f, %.4f]\n",
              r_c$auc, r_c$ci[1], r_c$ci[3]))
  cat(sprintf("  (paper AN-004 reference: 0.924; AN-006 strict: 0.79-0.85)\n"))

  list(
    threshold_train  = thresh,
    pool_size        = nrow(al),
    n_positives      = sum(al$is_cobidder),
    auc_binary       = r_b$auc, ci_b_lo = r_b$ci[1], ci_b_hi = r_b$ci[3],
    auc_continuous   = r_c$auc, ci_c_lo = r_c$ci[1], ci_c_hi = r_c$ci[3]
  )
}

results <- if (source == "bec") run_bec() else run_federal()
results$source <- source
results$generated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")

# Output
out_dir <- file.path(ROOT, "work/v20-comprasnet/output", paste0("an006_", source))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

json_path <- file.path(out_dir, "an006_results.json")
fmt_val <- function(v) {
  if (is.numeric(v) && length(v) == 1L) {
    if (is.finite(v) && (abs(v) < 1e-3 || abs(v) >= 1e5)) sprintf("%.4e", v)
    else sprintf("%.6f", v)
  } else if (is.character(v)) sprintf('"%s"', v)
  else as.character(v)
}
lines <- sapply(names(results), function(k) sprintf('  "%s": %s', k, fmt_val(results[[k]])))
writeLines(c("{", paste(lines, collapse = ",\n"), "}"), json_path)
cat(sprintf("\n  → %s\n", json_path))

csv_path <- file.path(out_dir, "an006_results.csv")
write.csv(as.data.frame(results), csv_path, row.names = FALSE)
cat(sprintf("  → %s\n", csv_path))
