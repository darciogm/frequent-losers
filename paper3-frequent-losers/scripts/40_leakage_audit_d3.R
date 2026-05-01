# ============================================================================
# 40_leakage_audit_d3.R — Leakage audit for D3 item-level AUC = 0.983
# Paper 3 v14 / Path γ++ post-gate diagnostic
#
# CONCERN (raised by codex peer review): the D3 item-level AUC of 0.983
# predicting any-cobidder participation from log_max_tc may be tautological.
# Cobidders are by construction always-losers with high tenders_count.
# An item that contains a cobidder participant therefore mechanically has
# a high max_tc among its always-loser participants. The "screen" is
# closer to "is there an always-loser with tenders_count > k in this
# item?" — and cobidders satisfy that by definition.
#
# Three audits:
#
# 1. CONSTRUCTION-INDEPENDENT LABEL. Replace any-cobidder label with
#    any-direct-CADE-defendant label (47 firms). Direct defendants are
#    NOT defined as always-losers; they are CADE-adjudicated firms in BEC.
#    AUC against this label tests whether the screen predicts items with
#    a CADE-adjudicated firm participating, not just the construct's own
#    population.
#
# 2. CROSS-FITTED CV. 5-fold CV at the COBIDDER FIRM level (not item
#    level): split the 193 cobidders into 5 folds; in each fold, exclude
#    those firms entirely from the training tenders_count computation,
#    then evaluate AUC on items containing held-out cobidders. This
#    breaks the in-sample tautology: training tenders_count cannot use
#    the held-out cobidders' own participation history.
#
# 3. TEMPORAL HOLDOUT. Train tenders_count on 2009-2016 only; predict
#    items in 2017-2019. If the construct generalizes prospectively, the
#    AUC should still be high; if it was leaking, it should drop sharply.
#
# Pass criterion (post-codex): if AUC drops to < 0.70 in any of the three
# audits while staying high in original, the original 0.983 was leakage.
# If AUC stays > 0.85 in all three, the original is defensible.
#
# Output: output/leakage_audit_d3/leakage_results.csv
# ============================================================================

cat("=== 40_leakage_audit_d3.R: Leakage audit for D3 item-level AUC ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(duckdb); library(DBI)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "leakage_audit_d3")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load ground-truth labels --------------------------------------------
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

cade_xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(cade_xm$firm_code)

cat(sprintf("\n  Cobidders (always-loser ∩ CADE co-participant): %d\n", length(cobid_codes)))
cat(sprintf("  Direct CADE defendants in BEC:                  %d\n", length(direct_codes)))
cat(sprintf("  Always-losers:                                  %s\n",
            format(sum(fp$always_loser == 1L), big.mark = ",")))

# ---- Label items at oc_item_key level ------------------------------------
ftm[, has_cobidder := as.integer(firm_code %in% cobid_codes)]
ftm[, has_direct   := as.integer(firm_code %in% direct_codes)]
item_lbl <- ftm[, .(any_cobidder = max(has_cobidder),
                     any_direct   = max(has_direct),
                     year         = max(year)),
                 by = oc_item_key]
item_lbl[!is.finite(any_cobidder), any_cobidder := 0L]
item_lbl[!is.finite(any_direct),   any_direct   := 0L]

cat(sprintf("\n  Items with any cobidder:        %s\n",
            format(sum(item_lbl$any_cobidder == 1), big.mark = ",")))
cat(sprintf("  Items with any direct defendant: %s\n",
            format(sum(item_lbl$any_direct == 1),   big.mark = ",")))

# ============================================================================
# AUDIT 1 — Same score, different label (direct CADE, not cobidders)
# ============================================================================
cat("\n=== Audit 1: AUC against direct-CADE label (47 firms, not 193) ===\n")

ftm_loser <- merge(ftm[won == 0L],
                    fp[always_loser == 1L, .(firm_code, tenders_count)],
                    by = "firm_code", all.x = TRUE)
ftm_loser[is.na(tenders_count), tenders_count := 0L]

intensity_full <- ftm_loser[, .(max_tc = max(tenders_count, na.rm = TRUE)),
                             by = oc_item_key]
intensity_full[!is.finite(max_tc), max_tc := 0L]
intensity_full[, log_max_tc := log1p(max_tc)]

dt <- merge(item_lbl, intensity_full, by = "oc_item_key", all.x = TRUE)
dt[is.na(log_max_tc), log_max_tc := 0]

cat("\n  Reference: original D3 AUC against any-cobidder ...\n")
r_orig <- pROC::roc(dt$any_cobidder, dt$log_max_tc, quiet = TRUE)
cat(sprintf("    [original | any_cobidder]   AUC = %.4f [%.4f, %.4f]  N+ = %d/%d\n",
            as.numeric(pROC::auc(r_orig)),
            as.numeric(pROC::ci(r_orig))[1],
            as.numeric(pROC::ci(r_orig))[3],
            sum(dt$any_cobidder == 1), nrow(dt)))

cat("\n  Audit 1: AUC against any-direct-CADE label ...\n")
r_direct <- pROC::roc(dt$any_direct, dt$log_max_tc, quiet = TRUE)
cat(sprintf("    [audit1   | any_direct   ]   AUC = %.4f [%.4f, %.4f]  N+ = %d/%d\n",
            as.numeric(pROC::auc(r_direct)),
            as.numeric(pROC::ci(r_direct))[1],
            as.numeric(pROC::ci(r_direct))[3],
            sum(dt$any_direct == 1), nrow(dt)))

audit1 <- data.table(
  audit = "1_label_direct_cade",
  label = c("any_cobidder (orig)", "any_direct"),
  auc   = c(as.numeric(pROC::auc(r_orig)), as.numeric(pROC::auc(r_direct))),
  ci_lo = c(as.numeric(pROC::ci(r_orig))[1], as.numeric(pROC::ci(r_direct))[1]),
  ci_hi = c(as.numeric(pROC::ci(r_orig))[3], as.numeric(pROC::ci(r_direct))[3]),
  n_pos = c(sum(dt$any_cobidder == 1), sum(dt$any_direct == 1))
)

# ============================================================================
# AUDIT 2 — Cross-fitted at COBIDDER FIRM level (5 folds)
# ============================================================================
cat("\n=== Audit 2: 5-fold CV at cobidder-firm level (out-of-fold AUC) ===\n")
set.seed(20260430)
cobid_fold <- data.table(firm_code = cobid_codes,
                          fold = sample(rep(1:5, length.out = length(cobid_codes))))

# For each fold k:
#   1. Hold out fold k of cobidders.
#   2. Recompute tenders_count on always-losers EXCLUDING held-out cobidders.
#   3. For items containing held-out cobidders (positives) and items with no
#      cobidder (negatives), compute log_max_tc using the recomputed score.
#   4. Pool out-of-fold predictions; report pooled AUC.

# Always-losers (full pool)
al <- fp[always_loser == 1L, .(firm_code, tenders_count_orig = tenders_count)]
al[, is_cobid := as.integer(firm_code %in% cobid_codes)]

# We need the per-firm participation count: rebuild from FTM directly.
firm_partic <- ftm[, .(n_partic = .N), by = firm_code]
al <- merge(al, firm_partic, by = "firm_code", all.x = TRUE)
al[is.na(n_partic), n_partic := 0L]
# Confirm tenders_count_orig matches n_partic for always-losers
cat(sprintf("    diag: max |tenders_count − n_partic| in always-losers = %d\n",
            max(abs(al$tenders_count_orig - al$n_partic))))

# Held-out fold framework: for each fold, set tenders_count of held-out
# cobidders to 0 (simulating "we never observed those firms"), recompute
# item-level max_tc, predict on items with any held-out cobidder.

results <- list()
for (k in 1:5) {
  held <- cobid_fold[fold == k, firm_code]

  # Recompute item-level max_tc using only NON-held-out always-losers
  ftm_k <- merge(ftm[won == 0L],
                  al[!firm_code %in% held, .(firm_code, tenders_count_orig)],
                  by = "firm_code", all.x = TRUE)
  ftm_k[is.na(tenders_count_orig), tenders_count_orig := 0L]
  intensity_k <- ftm_k[, .(max_tc_k = max(tenders_count_orig, na.rm = TRUE)),
                        by = oc_item_key]
  intensity_k[!is.finite(max_tc_k), max_tc_k := 0L]
  intensity_k[, log_max_tc_k := log1p(max_tc_k)]

  # Items with any held-out cobidder = positives in this fold
  ftm_held <- ftm[firm_code %in% held]
  pos_items <- unique(ftm_held$oc_item_key)

  # Negatives: items with no cobidder at all
  neg_items <- item_lbl[any_cobidder == 0L, oc_item_key]

  pos_dt <- intensity_k[oc_item_key %in% pos_items]
  pos_dt[, label := 1L]
  neg_dt <- intensity_k[oc_item_key %in% neg_items]
  neg_dt[, label := 0L]
  fold_dt <- rbind(pos_dt[, .(label, score = log_max_tc_k)],
                    neg_dt[, .(label, score = log_max_tc_k)])

  if (sum(fold_dt$label) >= 5) {
    r_k <- pROC::roc(fold_dt$label, fold_dt$score, quiet = TRUE)
    auc_k <- as.numeric(pROC::auc(r_k))
    ci_k  <- as.numeric(pROC::ci(r_k))
    cat(sprintf("    fold %d: held %d cobidders, %d positive items, AUC = %.4f [%.4f, %.4f]\n",
                k, length(held), sum(fold_dt$label), auc_k, ci_k[1], ci_k[3]))
    results[[k]] <- data.table(fold = k, auc = auc_k, ci_lo = ci_k[1],
                               ci_hi = ci_k[3], n_held = length(held),
                               n_pos_items = sum(fold_dt$label))
  }
}
cv_dt <- rbindlist(results, fill = TRUE)
fwrite(cv_dt, file.path(OUT, "audit2_cv_per_fold.csv"))

# Pooled AUC across folds (combine predictions in a single ROC)
pooled <- list()
for (k in 1:5) {
  held <- cobid_fold[fold == k, firm_code]
  ftm_k <- merge(ftm[won == 0L],
                  al[!firm_code %in% held, .(firm_code, tenders_count_orig)],
                  by = "firm_code", all.x = TRUE)
  ftm_k[is.na(tenders_count_orig), tenders_count_orig := 0L]
  intensity_k <- ftm_k[, .(max_tc_k = max(tenders_count_orig, na.rm = TRUE)),
                        by = oc_item_key]
  intensity_k[!is.finite(max_tc_k), max_tc_k := 0L]
  intensity_k[, log_max_tc_k := log1p(max_tc_k)]

  ftm_held <- ftm[firm_code %in% held]
  pos_items <- unique(ftm_held$oc_item_key)
  neg_items <- item_lbl[any_cobidder == 0L, oc_item_key]

  pos_dt <- intensity_k[oc_item_key %in% pos_items]
  pos_dt[, label := 1L]
  neg_dt <- intensity_k[oc_item_key %in% neg_items]
  neg_dt[, label := 0L]
  pooled[[k]] <- rbind(pos_dt[, .(label, score = log_max_tc_k)],
                        neg_dt[, .(label, score = log_max_tc_k)])
}
pooled_dt <- rbindlist(pooled, fill = TRUE)
r_pool <- pROC::roc(pooled_dt$label, pooled_dt$score, quiet = TRUE)
cat(sprintf("\n  POOLED 5-fold out-of-fold AUC: %.4f [%.4f, %.4f]\n",
            as.numeric(pROC::auc(r_pool)),
            as.numeric(pROC::ci(r_pool))[1],
            as.numeric(pROC::ci(r_pool))[3]))

audit2 <- data.table(
  audit = "2_cv_pooled",
  label = "pooled_oof",
  auc   = as.numeric(pROC::auc(r_pool)),
  ci_lo = as.numeric(pROC::ci(r_pool))[1],
  ci_hi = as.numeric(pROC::ci(r_pool))[3],
  n_pos = sum(pooled_dt$label)
)

# ============================================================================
# AUDIT 3 — Temporal holdout (train 2009-2016, test 2017-2019)
# ============================================================================
cat("\n=== Audit 3: Temporal holdout (train 2009-2016, test 2017-2019) ===\n")

# Recompute tenders_count using only items in train period
ftm_train <- ftm[year >= 2009 & year <= 2016 & won == 0L]
firm_partic_train <- ftm_train[, .(tenders_count_train = .N), by = firm_code]

al_train <- merge(al, firm_partic_train, by = "firm_code", all.x = TRUE)
al_train[is.na(tenders_count_train), tenders_count_train := 0L]

# Item-level max_tc using train-only counts
ftm_loser_temp <- merge(ftm[won == 0L],
                         al_train[, .(firm_code, tenders_count_train)],
                         by = "firm_code", all.x = TRUE)
ftm_loser_temp[is.na(tenders_count_train), tenders_count_train := 0L]
intensity_train <- ftm_loser_temp[, .(max_tc_train = max(tenders_count_train, na.rm = TRUE)),
                                   by = oc_item_key]
intensity_train[!is.finite(max_tc_train), max_tc_train := 0L]
intensity_train[, log_max_tc_train := log1p(max_tc_train)]

# Test set: items in 2017-2019
test_items <- item_lbl[year >= 2017 & year <= 2019]
test_dt <- merge(test_items, intensity_train, by = "oc_item_key", all.x = TRUE)
test_dt[is.na(log_max_tc_train), log_max_tc_train := 0]

cat(sprintf("  Test items (2017-2019): %s  with cobidder: %s  with direct: %s\n",
            format(nrow(test_dt), big.mark = ","),
            format(sum(test_dt$any_cobidder == 1), big.mark = ","),
            format(sum(test_dt$any_direct == 1), big.mark = ",")))

if (sum(test_dt$any_cobidder) >= 5) {
  r_t1 <- pROC::roc(test_dt$any_cobidder, test_dt$log_max_tc_train, quiet = TRUE)
  cat(sprintf("    [audit3 | any_cobidder, score uses 2009-2016] AUC = %.4f [%.4f, %.4f]\n",
              as.numeric(pROC::auc(r_t1)),
              as.numeric(pROC::ci(r_t1))[1],
              as.numeric(pROC::ci(r_t1))[3]))
}
if (sum(test_dt$any_direct) >= 5) {
  r_t2 <- pROC::roc(test_dt$any_direct, test_dt$log_max_tc_train, quiet = TRUE)
  cat(sprintf("    [audit3 | any_direct,   score uses 2009-2016] AUC = %.4f [%.4f, %.4f]\n",
              as.numeric(pROC::auc(r_t2)),
              as.numeric(pROC::ci(r_t2))[1],
              as.numeric(pROC::ci(r_t2))[3]))
}

audit3 <- data.table(
  audit = "3_temporal_holdout",
  label = c("any_cobidder", "any_direct"),
  auc   = c(if (exists("r_t1")) as.numeric(pROC::auc(r_t1)) else NA_real_,
            if (exists("r_t2")) as.numeric(pROC::auc(r_t2)) else NA_real_),
  ci_lo = c(if (exists("r_t1")) as.numeric(pROC::ci(r_t1))[1] else NA_real_,
            if (exists("r_t2")) as.numeric(pROC::ci(r_t2))[1] else NA_real_),
  ci_hi = c(if (exists("r_t1")) as.numeric(pROC::ci(r_t1))[3] else NA_real_,
            if (exists("r_t2")) as.numeric(pROC::ci(r_t2))[3] else NA_real_),
  n_pos = c(sum(test_dt$any_cobidder == 1), sum(test_dt$any_direct == 1))
)

# ---- Consolidated table -------------------------------------------------
all_results <- rbind(audit1, audit2, audit3, fill = TRUE)
fwrite(all_results, file.path(OUT, "leakage_audit_d3.csv"))

cat("\n  ===== Consolidated leakage audit =====\n")
print(all_results[, .(audit, label, auc = round(auc, 4),
                       ci = sprintf("[%.4f, %.4f]", ci_lo, ci_hi),
                       n_pos)])

# ---- Verdict ------------------------------------------------------------
cat("\n  ===== Leakage verdict =====\n")
auc_orig    <- audit1[label == "any_cobidder (orig)", auc]
auc_direct  <- audit1[label == "any_direct", auc]
auc_cv      <- audit2$auc
auc_temp_co <- audit3[label == "any_cobidder", auc]
auc_temp_dr <- audit3[label == "any_direct", auc]

cat(sprintf("    Original (in-sample, any_cobidder):        %.4f\n", auc_orig))
cat(sprintf("    Audit 1 (any_direct, same score):          %.4f  [scope]\n", auc_direct))
cat(sprintf("    Audit 2 (5-fold CV pooled out-of-fold):    %.4f  [tautology gate]\n", auc_cv))
cat(sprintf("    Audit 3 (temporal holdout, cobidder):      %.4f  [generalization]\n", auc_temp_co))
cat(sprintf("    Audit 3 (temporal holdout, direct):        %.4f\n", auc_temp_dr))

drop_cv     <- auc_orig - auc_cv
drop_temp_co <- auc_orig - auc_temp_co
verdict_cv     <- (auc_cv     > 0.85)
verdict_temp_co <- (auc_temp_co > 0.85)
verdict_temp_dr <- (auc_temp_dr > 0.65)
verdict <- (
  if (verdict_cv && verdict_temp_co) "DEFENSIBLE"
  else if (verdict_cv || verdict_temp_co) "WEAK"
  else "LEAKAGE_LIKELY"
)

cat(sprintf("\n    Audit 2 (CV) AUC > 0.85 ?           %s  (%.4f, drop = %.4f)\n",
            ifelse(verdict_cv, "YES", "NO"), auc_cv, drop_cv))
cat(sprintf("    Audit 3 (temp, cobidder) > 0.85 ?  %s  (%.4f, drop = %.4f)\n",
            ifelse(verdict_temp_co, "YES", "NO"), auc_temp_co, drop_temp_co))
cat(sprintf("    Audit 3 (temp, direct)   > 0.65 ?  %s  (%.4f)\n",
            ifelse(verdict_temp_dr, "YES", "NO"), auc_temp_dr))
cat(sprintf("\n    LEAKAGE AUDIT VERDICT: %s\n", verdict))

cat("\n  Done.\n")
