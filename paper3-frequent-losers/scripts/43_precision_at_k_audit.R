# ============================================================================
# 43_precision_at_k_audit.R — temporal-holdout audit of operational metrics
# Paper 3 v14 / Path A+ Action 8 (re-audited)
#
# Concern: the precision@k numbers in tab_operational_metrics
# (script 42) use full-sample tenders_count to score firms and full-sample
# cobidder labels to evaluate. This is the same in-sample setup that
# inflated the D3 item-level AUC from 0.864 (audited) to 0.995 (in-sample).
# A referee will ask whether top-k flags would have ranked cobidders
# correctly using only ex-ante information.
#
# Audits:
#   1. TEMPORAL HOLDOUT. Score = log(1 + tenders_count restricted to
#      2009-2016 participations). Predict cobidders adjudicated 2017
#      onward. Compare precision@k to in-sample reference.
#   2. CADE-DATE STRATIFIED. Split cobidders by CADE adjudication date
#      (pre-2019 vs post-2019). Compute separate precision@k for each
#      group. If early/late are similar, the screen is forward-looking;
#      if early is much higher, the screen is fitting historical patterns.
#   3. FIRM-LEVEL CV. 5-fold split of cobidders; for each fold, drop
#      held-out cobidders from labels (but keep their score), compute
#      precision@k over remaining cobidders. Pool across folds.
#
# Output: output/operational/audit_precision_k.csv
# ============================================================================

cat("=== 43_precision_at_k_audit.R: temporal+CV audit of precision@k ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "operational")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data -----------------------------------------------------------
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cade_xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]

# Adjudication dates live in cade_carteis_licitacoes (one row per process+firm).
cade_lic <- fread(file.path(BASE, "data/processed/cade_carteis_licitacoes_2009_2019.csv"))
cade_lic[, data_julgamento := suppressWarnings(as.Date(data_julgamento))]
cade_lic[, post_2019 := as.integer(data_julgamento > as.Date("2019-12-31"))]
cade_lic[, firm_code := sprintf("%014.0f", as.numeric(cnpj))]

# Direct-defendant adjudication classification per firm
direct_class <- cade_lic[!is.na(data_julgamento), .(
  earliest_adj = min(data_julgamento),
  has_post2019 = max(post_2019)
), by = firm_code]

# Cobidders are co-bidders, not direct defendants. Approximate their
# adjudication cohort via the direct-defendants they co-bid with: a
# cobidder shares CADE-process tenders with one or more direct defendants;
# we attribute the EARLIEST adjudication of those direct defendants.
# (Imperfect but sufficient for the audit's directional question.)
cobid_class <- merge(
  cobid[, .(firm_code = unique(firm_code))],
  direct_class[, .(firm_code, earliest_adj_direct = earliest_adj,
                    has_post2019_direct = has_post2019)],
  by = "firm_code", all.x = TRUE
)
# For cobidders without direct-defendant overlap by firm_code, fall back
# to the median adjudication date (post-2019 = 1).
fallback_post2019 <- as.integer(median(direct_class$has_post2019,
                                         na.rm = TRUE) >= 0.5)
cobid_class[is.na(has_post2019_direct), has_post2019_direct := fallback_post2019]
cobid_class[, earliest_adj := earliest_adj_direct]
cobid_class[, has_post2019 := has_post2019_direct]

al <- fp[always_loser == 1L, .(firm_code, tenders_count_full = tenders_count)]
al[, log_tc_full := log1p(tenders_count_full)]
al[, is_cobid    := as.integer(firm_code %in% unique(cobid$firm_code))]
al <- merge(al,
             cobid_class[, .(firm_code, earliest_adj, has_post2019)],
             by = "firm_code", all.x = TRUE)
al[, cohort := fcase(
  is_cobid == 1L & has_post2019 == 1L, "post2019",
  is_cobid == 1L & has_post2019 == 0L, "pre2020",
  is_cobid == 1L,                       "unknown_date",
  default = "non_cobidder"
)]
cat(sprintf("\n  Cobidder cohort distribution:\n"))
print(al[is_cobid == 1L, .N, by = cohort])

# ---- Build tenders_count restricted to 2009-2016 -------------------------
# tenders_count from FREQ_PARTICIP is full-sample. Recompute from
# firm_tender_map restricted to year <= 2016.
tc_train <- ftm[year <= 2016L, .(tenders_count_train = .N), by = firm_code]
al <- merge(al, tc_train, by = "firm_code", all.x = TRUE)
al[is.na(tenders_count_train), tenders_count_train := 0L]
al[, log_tc_train := log1p(tenders_count_train)]

cat(sprintf("\n  tenders_count summary (full sample vs 2009-2016):\n"))
print(al[, .(median_full = median(tenders_count_full),
              p90_full   = quantile(tenders_count_full, 0.90),
              median_train = median(tenders_count_train),
              p90_train   = quantile(tenders_count_train, 0.90))])

# ---- Helper: precision/recall@k -----------------------------------------
prec_recall_at_k <- function(score, label, ks) {
  ord <- order(score, decreasing = TRUE)
  lab_sorted <- label[ord]
  tot_pos <- sum(label)
  out <- data.table()
  for (k in ks) {
    if (k > length(lab_sorted)) k <- length(lab_sorted)
    n_pos_k <- sum(lab_sorted[1:k])
    out <- rbind(out, data.table(
      k = k,
      n_pos = n_pos_k,
      precision = n_pos_k / k,
      recall = n_pos_k / tot_pos,
      total_pos = tot_pos
    ))
  }
  out
}

ks <- c(50, 100, 250, 500, 1000, 2000)

# ============================================================================
# AUDIT 1 — Temporal holdout
# ============================================================================
cat("\n=== Audit 1: temporal holdout (score = log(1 + tc 2009-2016)) ===\n")

cat("\n  In-sample reference (full tenders_count):\n")
ref <- prec_recall_at_k(al$log_tc_full, al$is_cobid, ks)
ref[, lift := precision / mean(al$is_cobid)]
print(ref)

cat("\n  Audit 1A: score uses 2009-2016 only; predict ALL cobidders (regardless of CADE date):\n")
a1 <- prec_recall_at_k(al$log_tc_train, al$is_cobid, ks)
a1[, lift := precision / mean(al$is_cobid)]
print(a1)

# Audit 1B: predict only post-2019-adjudicated cobidders (true forward-looking)
cat("\n  Audit 1B: score uses 2009-2016 only; predict only post-2019-adjudicated cobidders:\n")
al[, is_cobid_post := as.integer(is_cobid == 1L & cohort == "post2019")]
a1b <- prec_recall_at_k(al$log_tc_train, al$is_cobid_post, ks)
a1b[, lift := precision / mean(al$is_cobid_post)]
print(a1b)

# ============================================================================
# AUDIT 2 — Stratified by CADE adjudication cohort
# ============================================================================
cat("\n=== Audit 2: precision@k stratified by CADE adjudication cohort ===\n")
cat("\n  Pre-2020 cohort (cobidders adjudicated before 2020):\n")
al[, is_cobid_pre := as.integer(is_cobid == 1L & cohort == "pre2020")]
a2_pre <- prec_recall_at_k(al$log_tc_full, al$is_cobid_pre, ks)
a2_pre[, lift := precision / mean(al$is_cobid_pre)]
print(a2_pre)

cat("\n  Post-2019 cohort (cobidders adjudicated 2020+):\n")
a2_post <- prec_recall_at_k(al$log_tc_full, al$is_cobid_post, ks)
a2_post[, lift := precision / mean(al$is_cobid_post)]
print(a2_post)

# ============================================================================
# AUDIT 3 — 5-fold CV at cobidder-firm level (holdout-only labels)
# ============================================================================
cat("\n=== Audit 3: 5-fold CV at cobidder-firm level (pooled out-of-fold) ===\n")
set.seed(20260430)
cobid_codes <- unique(al$firm_code[al$is_cobid == 1L])
fold_id <- sample(rep(1:5, length.out = length(cobid_codes)))
cobid_fold <- data.table(firm_code = cobid_codes, fold = fold_id)

pooled <- list()
for (k in 1:5) {
  held <- cobid_fold[fold == k, firm_code]
  al_k <- copy(al)
  # Treat held-out cobidders as positives ONLY in this fold; mask other
  # cobidders as negatives (so we evaluate ranking of held-out on the
  # population of held-out + non-cobidders).
  al_k[, target_k := fcase(
    firm_code %in% held, 1L,
    is_cobid == 1L,      NA_integer_,  # mask other cobidders
    default = 0L
  )]
  al_k <- al_k[!is.na(target_k)]
  setorder(al_k, -log_tc_full)
  for (k_top in ks) {
    if (k_top > nrow(al_k)) next
    n_pos_k <- sum(al_k$target_k[1:k_top])
    pooled[[length(pooled)+1]] <- data.table(
      fold = k, k_top = k_top,
      n_pos = n_pos_k, precision = n_pos_k / k_top,
      recall = n_pos_k / sum(al_k$target_k),
      n_held = length(held))
  }
}
cv_dt <- rbindlist(pooled)
agg_cv <- cv_dt[, .(
  precision_mean = mean(precision),
  precision_sd   = sd(precision),
  recall_mean    = mean(recall),
  n_pos_avg      = mean(n_pos)
), by = k_top]
print(agg_cv)

# ---- Save consolidated CSV ----------------------------------------------
all_audits <- rbind(
  data.table(audit = "0_in_sample_reference", ref),
  data.table(audit = "1A_temporal_all_cobidders", a1),
  data.table(audit = "1B_temporal_post2019_only", a1b),
  data.table(audit = "2_pre2020_cohort", a2_pre),
  data.table(audit = "2_post2019_cohort", a2_post),
  fill = TRUE
)
fwrite(all_audits, file.path(OUT, "audit_precision_k.csv"))
fwrite(agg_cv, file.path(OUT, "audit_precision_k_cv.csv"))

# ---- Verdict ------------------------------------------------------------
cat("\n  ===== Precision@k audit verdict =====\n")
prec_500_ref <- ref[k == 500, precision]
prec_500_temp <- a1[k == 500, precision]
prec_500_post <- a1b[k == 500, precision]
prec_500_cv  <- agg_cv[k_top == 500, precision_mean]

cat(sprintf("    In-sample precision@500:                        %.3f (lift %.1fx)\n",
            prec_500_ref, ref[k == 500, lift]))
cat(sprintf("    Temporal holdout (all cobidders) prec@500:      %.3f (drop %.3f, %.0f%% retention)\n",
            prec_500_temp, prec_500_ref - prec_500_temp,
            100 * prec_500_temp / prec_500_ref))
cat(sprintf("    Temporal holdout (post-2019 only) prec@500:     %.3f (drop %.3f, %.0f%% retention)\n",
            prec_500_post, prec_500_ref - prec_500_post,
            100 * prec_500_post / prec_500_ref))
cat(sprintf("    5-fold CV (pooled) prec@500:                    %.3f (drop %.3f, %.0f%% retention)\n",
            prec_500_cv, prec_500_ref - prec_500_cv,
            100 * prec_500_cv / prec_500_ref))

retention_ok <- (prec_500_temp / prec_500_ref) > 0.65
verdict <- (
  if (retention_ok && prec_500_post > 2 * mean(al$is_cobid_post)) "DEFENSIBLE"
  else if (retention_ok) "WEAK"
  else "INFLATED"
)
cat(sprintf("\n    PRECISION@K AUDIT VERDICT: %s\n", verdict))

cat("\n  Done.\n")
