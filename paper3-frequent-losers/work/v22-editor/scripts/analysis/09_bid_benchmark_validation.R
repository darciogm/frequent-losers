#!/usr/bin/env Rscript
# =============================================================================
# 09_bid_benchmark_validation.R  --  JLEO R&R (v22)
# RIGOROUS VALIDATION OF THE BID-LAYER (IMHOF) BENCHMARK + AWARD/BID COMPLEMENTARITY
#
# Question: is the award+bid "complementarity" (pooled +0.096 PR/AUC) real, or an
# artifact of (i) RANDOM CV folds when CADE labels cluster by case, and (ii)
# feature-target overlap (bid features built from label-defining tenders)?
#
# We re-implement script 31's firm-level Imhof feature frame and re-run the
# benchmark under MULTIPLE validation designs:
#   A  pooled random 5-fold CV (diagnostic upper bound; reproduce ~0.888/0.921/0.962)
#   E  CASE-GROUPED CV / leave-one-case-out (THE KEY TEST)
#   F  exclude label-defining tenders from feature construction (contamination test)
#   G  environment holdout (largest item-group / buyer)
#
# Models compared throughout: award_continuous = log1p(tenders_count),
#   award_FL14 = 1[tenders_count>=14], bid_RF (Imhof RF), combined_RF (award+bid RF).
#
# Plus: model audit (Table P), complementarity (Table R), leakage audit (Table S),
# calibration + error analysis (appendix Table F).
#
# Candidate pool = always-losers with COMPLETE Imhof features, EXCLUDING direct
# CADE defendants (crossmatch). Target = is_cade (canonical broad AL cobidder label
# (651), in candidate pool, not a defendant). Seed 20260603. ranger 500 trees, num.threads=12.
#
# Run:
#   cd <repo>; Rscript work/v22-editor/scripts/analysis/09_bid_benchmark_validation.R \
#     2>&1 | tee work/v22-editor/outputs/logs/bid_benchmark_validation.log
# =============================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(ranger); library(ggplot2)
})

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
DOCS <- file.path(V22, "docs", "jleo_rr_revision")

source(file.path(UTIL, "metrics_triage.R"))

dir_main_t <- file.path(OUT, "tables", "main")
dir_app_t  <- file.path(OUT, "tables", "appendix")
dir_main_f <- file.path(OUT, "figures", "main")
dir_app_f  <- file.path(OUT, "figures", "appendix")
dir_diag   <- file.path(OUT, "diagnostics")
dir_cache  <- file.path(OUT, "cache")
dir_logs   <- file.path(OUT, "logs")
for (d in c(dir_main_t, dir_app_t, dir_main_f, dir_app_f, dir_diag, dir_cache, dir_logs, DOCS))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)
SEED <- 20260603L
set.seed(SEED)
RF_TREES <- 500L
RF_THREADS <- 12L

# ---- telemetry --------------------------------------------------------------
LOG <- file.path(dir_diag, "bid_benchmark_validation_audit_log.txt")
.t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern=TRUE))/1024), error=function(e) NA_real_)
stamp <- function(s) say("  [stage %-26s] elapsed=%6.1fs  RSS=%s MB", s, as.numeric(difftime(Sys.time(),.t0,units="secs")), rss_mb())

say("=== 09_bid_benchmark_validation.R ===")
say("host=%s  nproc=%s  seed=%d  date=%s  RAM_free=%s  RF_trees=%d",
    Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern=TRUE), error=function(e)"?"), SEED, format(Sys.time()),
    tryCatch(system("free -h | awk 'NR==2{print $7}'", intern=TRUE), error=function(e)"?"), RF_TREES)
say("REPO=%s", REPO)

norm14 <- function(x) sprintf("%014.0f", as.numeric(x))

# safe metric wrappers (NA on degenerate input, never error)
safe <- function(expr) tryCatch(suppressWarnings(expr), error = function(e) NA_real_)
m_rocauc <- function(y, s) if (sum(y==1)<1 || sum(y==0)<1) NA_real_ else safe(roc_auc(y, s))
m_prauc  <- function(y, s) if (sum(y==1)<1) NA_real_ else safe(average_precision(y, s))
m_prec   <- function(y, s, k) safe(precision_at_k(y, s, k))
m_rec    <- function(y, s, k) if (sum(y==1)<1) NA_real_ else safe(recall_at_k(y, s, k))
m_lift   <- function(y, s, k) if (sum(y==1)<1) NA_real_ else safe(lift_at_k(y, s, k))
m_fp     <- function(y, s, k) safe(false_positives_at_k(y, s, k))
m_fn     <- function(y, s, k) safe(false_negatives_at_k(y, s, k))

IMHOF_FEATS <- c("imhof_cv_mean","imhof_cv_sd","imhof_skew_mean","imhof_kurt_mean",
                 "imhof_spread_mean","imhof_minmax_mean","imhof_second_low_mean")

# =============================================================================
# STAGE 0. BUILD / CACHE FIRM-LEVEL IMHOF FEATURE FRAME (reuse script 31 logic)
# =============================================================================
say("\n========== STAGE 0. FIRM-LEVEL IMHOF FEATURE FRAME ==========")
cache_feat <- file.path(dir_cache, "imhof_firm_features.parquet")
cache_tend <- file.path(dir_cache, "imhof_tender_features.parquet")
bl_path <- file.path(REPO, "v3/data/processed/bid_level_with_prices.parquet")

if (file.exists(cache_feat) && file.exists(cache_tend)) {
  say("loading cached firm + tender Imhof feature frames")
  firm_features  <- as.data.table(read_parquet(cache_feat))
  tender_features <- as.data.table(read_parquet(cache_tend))
} else {
  say("computing per-tender Imhof features from %s", basename(bl_path))
  bl <- as.data.table(read_parquet(bl_path))
  bl[, firm_code := as.character(`códigofornecedor`)]
  bl_valid <- bl[!is.na(bid_price) & bid_price > 0]
  say("valid bid rows (price>0): %s", format(nrow(bl_valid), big.mark=","))

  tender_features <- bl_valid[, {
    if (.N < 2) {
      list(n_bids = .N, cv = NA_real_, skew = NA_real_, kurt = NA_real_,
           spread = NA_real_, min_max_log = NA_real_, second_lowest_dist = NA_real_)
    } else {
      bp <- bid_price; n <- .N; m <- mean(bp); s <- sd(bp)
      cv <- ifelse(m > 0, s/m, NA_real_)
      skew <- ifelse(s > 0, mean((bp-m)^3)/s^3, NA_real_)
      kurt <- ifelse(s > 0, mean((bp-m)^4)/s^4 - 3, NA_real_)
      spread <- ifelse(m > 0, (max(bp)-min(bp))/m, NA_real_)
      min_max_log <- log(max(bp)/max(min(bp), 1e-9))
      sorted_bp <- sort(bp)
      second_lowest_dist <- ifelse(n >= 2 && sorted_bp[1] > 0, log(sorted_bp[2]/sorted_bp[1]), NA_real_)
      list(n_bids = n, cv = cv, skew = skew, kurt = kurt, spread = spread,
           min_max_log = min_max_log, second_lowest_dist = second_lowest_dist)
    }
  }, by = .(numerodaoc, codigoitem = `códigoitem`)]
  say("tender-level features: %s tenders", format(nrow(tender_features), big.mark=","))

  firm_tender <- bl_valid[, .(firm_code, numerodaoc, codigoitem = `códigoitem`)]
  firm_tender <- merge(firm_tender, tender_features, by = c("numerodaoc","codigoitem"))
  firm_features <- firm_tender[!is.na(cv), .(
    imhof_cv_mean = mean(cv, na.rm=TRUE), imhof_cv_sd = sd(cv, na.rm=TRUE),
    imhof_skew_mean = mean(skew, na.rm=TRUE), imhof_kurt_mean = mean(kurt, na.rm=TRUE),
    imhof_spread_mean = mean(spread, na.rm=TRUE), imhof_minmax_mean = mean(min_max_log, na.rm=TRUE),
    imhof_second_low_mean = mean(second_lowest_dist, na.rm=TRUE), n_tenders_priced = .N
  ), by = firm_code]
  say("per-firm Imhof features: %s firms", format(nrow(firm_features), big.mark=","))
  write_parquet(firm_features, cache_feat)
  write_parquet(tender_features, cache_tend)
  rm(bl, bl_valid, firm_tender); gc()
}
stamp("0_firm_features")

# =============================================================================
# STAGE 1. CANDIDATE POOL + LABELS + CASE LINKAGE
# =============================================================================
say("\n========== STAGE 1. CANDIDATE POOL + LABELS ==========")
fp <- as.data.table(read_parquet(file.path(DATA, "FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := norm14(`códigofornecedor`)]

# canonical reproducible broad always-loser cobidder label (positive = broad_cobidder==1, 651 firms)
cob <- fread(file.path(REPO, "work", "v22-editor", "outputs", "cache", "canonical_cobidders_broad.csv"))
cob <- cob[broad_cobidder == 1L]                       # broad AL cobidder positive set (651)
cob[, firm_code := norm14(`códigofornecedor`)]
cob_codes <- unique(cob$firm_code)
xm  <- fread(file.path(DATA, "cade_bec_crossmatch.csv"))
xm[, firm_code := norm14(firm_cnpj)]
direct_codes_raw <- unique(xm$firm_code)
overlap <- intersect(direct_codes_raw, cob_codes)
say("cobidder positives (file): %d distinct ; direct defendants (crossmatch): %d distinct ; overlap (-> defendant only): %d {%s}",
    length(cob_codes), length(direct_codes_raw), length(overlap), paste(overlap, collapse=","))
pos_codes <- setdiff(cob_codes, direct_codes_raw)

# always-loser pool, EXCLUDE direct defendants, merge firm features
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al <- al[!firm_code %in% direct_codes_raw]
al <- merge(al, firm_features, by = "firm_code", all.x = TRUE)
al[, is_cade := as.integer(firm_code %in% pos_codes)]
al[, score_award := log1p(tenders_count)]
al[, fl14 := as.integer(tenders_count >= 14L)]
al[, has_imhof := as.integer(
  !is.na(imhof_cv_mean) & is.finite(imhof_cv_mean) &
  !is.na(imhof_kurt_mean) & is.finite(imhof_kurt_mean) &
  !is.na(imhof_skew_mean) & is.finite(imhof_skew_mean))]
al_complete <- al[has_imhof == 1L]
setorder(al_complete, firm_code)
al_complete[, firm_id := .I]
say("always-losers (minus %d defendants in pool): %d", length(intersect(direct_codes_raw, fp[always_loser==1L]$firm_code)), nrow(al))
say("CANDIDATE POOL (complete Imhof features): N=%s ; positives(is_cade)=%d",
    format(nrow(al_complete), big.mark=","), sum(al_complete$is_cade))
say("positive codes not in complete-feature pool (excluded): %d",
    sum(!pos_codes %in% al_complete$firm_code))

# case linkage (cobidder -> CADE case), restricted to positives in the pool
ccm <- fread(file.path(REPO, "output", "label_funnel", "case_cobidder_map.csv"),
             colClasses = list(character = c("cnpj","proc")))
ccm[, firm_code := norm14(cnpj)]
pos_in_pool <- al_complete[is_cade==1L]$firm_code
case_links <- unique(ccm[firm_code %in% pos_in_pool, .(firm_code, proc, jdate)])
# primary case per positive: case with most cobid rows in map; tiebreak earliest jdate
cl_count <- ccm[firm_code %in% pos_in_pool, .N, by=.(firm_code, proc, jdate)]
setorder(cl_count, firm_code, -N, jdate)
primary_case <- cl_count[, .SD[1], by=firm_code][, .(firm_code, proc, jdate)]
n_linked <- uniqueN(primary_case$firm_code)
n_pos_pool <- length(pos_in_pool)
say("positives in pool linked to >=1 CADE case: %d ; UNLINKED (no case in map): %d",
    n_linked, n_pos_pool - n_linked)
case_pos <- primary_case[, .(n_pos=.N), by=proc][order(-n_pos)]
say("--- primary-case positive counts (in pool) ---")
for (i in seq_len(nrow(case_pos))) say("  %-22s : %d", case_pos$proc[i], case_pos$n_pos[i])
largest_case <- case_pos$proc[1]
stamp("1_candidate_pool")

# =============================================================================
# STAGE 2. RF CV ENGINE (reusable across designs)
# =============================================================================
# Returns out-of-fold predictions for a given fold assignment and feature set.
# Each row predicted by a model trained on the OTHER folds. For LOCO/case-grouped,
# the held-out fold's positives are evaluated against a model that never saw them.
rf_oof_preds <- function(dt, features, fold_vec, label_col = "is_cade") {
  preds <- rep(NA_real_, nrow(dt))
  folds <- sort(unique(fold_vec))
  for (k in folds) {
    test_idx  <- which(fold_vec == k)
    train_idx <- which(fold_vec != k)
    if (length(train_idx) < 2L) next
    tr <- dt[train_idx]
    tr_lab <- factor(tr[[label_col]], levels = c(0,1))
    if (nlevels(droplevels(tr_lab)) < 2L) {
      # training fold has no positives -> RF can't learn; leave NA (handled by caller)
      next
    }
    tr2 <- copy(tr); tr2[, .y := tr_lab]
    fmla <- as.formula(paste0(".y ~ ", paste(features, collapse=" + ")))
    rf <- ranger(fmla, data = tr2, num.trees = RF_TREES, probability = TRUE,
                 num.threads = RF_THREADS, seed = SEED)
    pm <- predict(rf, dt[test_idx])$predictions
    preds[test_idx] <- pm[, "1"]
  }
  preds
}

# metric block for a score vs label vector
metric_block <- function(y, s, prefix="") {
  out <- list(
    roc_auc = m_rocauc(y, s), pr_auc = m_prauc(y, s),
    prec_100 = m_prec(y, s, 100), prec_250 = m_prec(y, s, 250),
    prec_500 = m_prec(y, s, 500), prec_1000 = m_prec(y, s, 1000),
    rec_100 = m_rec(y, s, 100), rec_250 = m_rec(y, s, 250),
    rec_500 = m_rec(y, s, 500), rec_1000 = m_rec(y, s, 1000),
    lift_500 = m_lift(y, s, 500), fp_500 = m_fp(y, s, 500), fn_500 = m_fn(y, s, 500))
  setNames(out, paste0(prefix, names(out)))
}

# DeLong test (two correlated ROC-AUCs) -- self-contained, no pROC.
delong_test <- function(y, s1, s2) {
  ok <- !is.na(s1) & !is.na(s2) & !is.na(y)
  y <- y[ok]; s1 <- s1[ok]; s2 <- s2[ok]
  pos <- which(y==1); neg <- which(y==0)
  m <- length(pos); n <- length(neg)
  if (m<2 || n<2) return(list(auc1=NA, auc2=NA, z=NA, p=NA))
  # placement values (structural components) per Sun & Xu fast DeLong
  comp <- function(s) {
    X <- s[pos]; Y <- s[neg]
    # V10[i] = (1/n) sum_j psi(X_i, Y_j) ; V01[j] = (1/m) sum_i psi(X_i, Y_j)
    rX <- rank(c(X, Y))[seq_len(m)]
    rY <- rank(c(X, Y))[m + seq_len(n)]
    rXo <- rank(X); rYo <- rank(Y)
    V10 <- (rX - rXo) / n
    V01 <- 1 - (rY - rYo) / m
    auc <- (sum(rX) - m*(m+1)/2) / (m*n)
    list(auc=auc, V10=V10, V01=V01)
  }
  a <- comp(s1); b <- comp(s2)
  S10 <- cov(cbind(a$V10, b$V10)); S01 <- cov(cbind(a$V01, b$V01))
  S <- S10/m + S01/n
  d <- a$auc - b$auc
  var_d <- S[1,1] + S[2,2] - 2*S[1,2]
  z <- if (var_d > 0) d/sqrt(var_d) else NA_real_
  p <- if (is.na(z)) NA_real_ else 2*pnorm(-abs(z))
  list(auc1=a$auc, auc2=b$auc, z=z, p=p, delta=d)
}

# storage for prediction export
pred_store <- list()
add_preds <- function(design, model_name, dt, score, fold) {
  pred_store[[length(pred_store)+1]] <<- data.table(
    firm_id = dt$firm_id, sample_flag = "always_loser_complete_imhof",
    target = dt$is_cade, model_name = model_name, validation_design = design,
    fold_id = fold, score_predicted = score, raw_award_score = dt$score_award,
    FL14 = dt$fl14, bid_feature_availability = dt$has_imhof,
    direct_defendant_flag = 0L)
}

# =============================================================================
# STAGE 3. DESIGN A -- POOLED RANDOM 5-FOLD CV (diagnostic upper bound)
# =============================================================================
say("\n========== DESIGN A: POOLED RANDOM 5-FOLD CV ==========")
set.seed(SEED)
al_complete[, fold_random := sample(rep(1:5, length.out=.N))]
y <- al_complete$is_cade

# award models are CADE-label-independent rank scores -> use raw score directly
preds_award_cont <- al_complete$score_award
preds_award_fl14 <- al_complete$fl14
preds_bidA  <- rf_oof_preds(al_complete, IMHOF_FEATS, al_complete$fold_random)
preds_combA <- rf_oof_preds(al_complete, c("score_award", IMHOF_FEATS), al_complete$fold_random)

say("Design A AUC -- award_cont=%.4f  award_FL14=%.4f  bid_RF=%.4f  combined_RF=%.4f",
    m_rocauc(y, preds_award_cont), m_rocauc(y, preds_award_fl14),
    m_rocauc(y, preds_bidA), m_rocauc(y, preds_combA))
say("(script-31 reference: fl_alone 0.921, imhof_full 0.888, imhof_full_plus_fl 0.962)")

add_preds("A_pooled_random", "award_continuous", al_complete, preds_award_cont, al_complete$fold_random)
add_preds("A_pooled_random", "award_FL14",       al_complete, preds_award_fl14, al_complete$fold_random)
add_preds("A_pooled_random", "bid_RF",           al_complete, preds_bidA,  al_complete$fold_random)
add_preds("A_pooled_random", "combined_RF",      al_complete, preds_combA, al_complete$fold_random)
stamp("3_designA")

# =============================================================================
# STAGE 4. DESIGN E -- CASE-GROUPED CV / LEAVE-ONE-CASE-OUT (KEY TEST)
# =============================================================================
# Folds assigned by CADE case. Cobidders -> their primary case's fold; non-cobidders
# distributed across folds at random. Train RF without the held-out fold; this means
# when a fold is held out, ALL of that case's positives are unseen in training.
# Evaluation: pooled out-of-fold predictions, scored against full is_cade label.
# This is the standard grouped-CV anti-leakage design.
say("\n========== DESIGN E: CASE-GROUPED CV (leave-one-case-out folds) ==========")
# map each case to a fold; 7 cases -> use case itself as the grouping unit so that
# leave-one-case-out = one fold per case. Non-cobidders + unlinked positives get a
# random fold among the case-folds (they are negatives or unassignable positives).
case_list <- case_pos$proc
case_fold <- setNames(seq_along(case_list), case_list)   # one fold per case
al_complete <- merge(al_complete, primary_case[, .(firm_code, proc)], by="firm_code", all.x=TRUE)
al_complete[, case_fold := case_fold[proc]]
set.seed(SEED)
# non-linked rows (negatives + unlinked positives) distributed across the case folds
n_cf <- length(case_list)
unlinked_idx <- which(is.na(al_complete$case_fold))
al_complete[unlinked_idx, case_fold := sample(rep(1:n_cf, length.out=length(unlinked_idx)))]
say("case-grouped folds: %d (one per case). positives per fold:", n_cf)
print(al_complete[is_cade==1L, .N, by=.(case_fold, proc)][order(case_fold)])

preds_bidE  <- rf_oof_preds(al_complete, IMHOF_FEATS, al_complete$case_fold)
preds_combE <- rf_oof_preds(al_complete, c("score_award", IMHOF_FEATS), al_complete$case_fold)
# award scores are label-independent; under case-grouped eval they are unchanged
# (no training), so pooled award AUC is identical to Design A. We still report it.
nay <- is.na(preds_bidE) | is.na(preds_combE)
say("rows with NA OOF bid pred (fold had no training positives or empty): %d", sum(is.na(preds_bidE)))
say("Design E POOLED out-of-fold AUC -- award_cont=%.4f  award_FL14=%.4f  bid_RF=%.4f  combined_RF=%.4f",
    m_rocauc(y, preds_award_cont), m_rocauc(y, preds_award_fl14),
    m_rocauc(y[!is.na(preds_bidE)], preds_bidE[!is.na(preds_bidE)]),
    m_rocauc(y[!is.na(preds_combE)], preds_combE[!is.na(preds_combE)]))

add_preds("E_case_grouped", "award_continuous", al_complete, preds_award_cont, al_complete$case_fold)
add_preds("E_case_grouped", "award_FL14",       al_complete, preds_award_fl14, al_complete$case_fold)
add_preds("E_case_grouped", "bid_RF",           al_complete, preds_bidE,  al_complete$case_fold)
add_preds("E_case_grouped", "combined_RF",      al_complete, preds_combE, al_complete$case_fold)

# ---- per-case LOCO detail: evaluate ONLY held-out case positives vs candidate set
say("\n----- Design E LOCO per-case detail (held-out case positives only) -----")
TOO_SPARSE_MIN <- 5L
loco_rows <- list()
for (c in case_list) {
  held <- primary_case[proc==c, firm_code]
  other_pos <- setdiff(pos_in_pool, held)
  ev <- al_complete[!firm_code %in% other_pos]
  yv <- as.integer(ev$firm_code %in% held)
  # bid/combined predictions for these rows come from the case-grouped OOF preds
  fold_c <- case_fold[c]
  idx <- match(ev$firm_code, al_complete$firm_code)
  bid_pred_ev  <- preds_bidE[idx]
  comb_pred_ev <- preds_combE[idx]
  loco_rows[[c]] <- data.table(
    case=c, positives=sum(yv), n_candidates=nrow(ev),
    too_sparse = sum(yv) < TOO_SPARSE_MIN,
    award_cont_auc = m_rocauc(yv, ev$score_award),
    award_fl14_auc = m_rocauc(yv, ev$fl14),
    bid_auc  = m_rocauc(yv, bid_pred_ev),
    comb_auc = m_rocauc(yv, comb_pred_ev),
    award_cont_prauc = m_prauc(yv, ev$score_award),
    bid_prauc  = m_prauc(yv, bid_pred_ev),
    comb_prauc = m_prauc(yv, comb_pred_ev),
    award_cont_prec500 = m_prec(yv, ev$score_award, 500),
    bid_prec500  = m_prec(yv, bid_pred_ev, 500),
    comb_prec500 = m_prec(yv, comb_pred_ev, 500),
    award_cont_rec500 = m_rec(yv, ev$score_award, 500),
    bid_rec500  = m_rec(yv, bid_pred_ev, 500),
    comb_rec500 = m_rec(yv, comb_pred_ev, 500))
}
loco <- rbindlist(loco_rows)[order(-positives)]
print(loco[, .(case=substr(case,7,18), positives, too_sparse,
               award=round(award_cont_auc,3), bid=round(bid_auc,3), comb=round(comb_auc,3),
               bid_pr=round(bid_prauc,3), comb_pr=round(comb_prauc,3))])
say("LOCO non-sparse mean AUC: award_cont=%.3f bid=%.3f combined=%.3f",
    mean(loco[too_sparse==FALSE]$award_cont_auc, na.rm=TRUE),
    mean(loco[too_sparse==FALSE]$bid_auc, na.rm=TRUE),
    mean(loco[too_sparse==FALSE]$comb_auc, na.rm=TRUE))
fwrite(loco, file.path(dir_diag, "bid_benchmark_loco_per_case.csv"))
stamp("4_designE")

# =============================================================================
# STAGE 5. DESIGN F -- EXCLUDE LABEL-DEFINING TENDERS FROM FEATURE CONSTRUCTION
# =============================================================================
# Recompute firm Imhof features EXCLUDING tender-items (oc,item) where the firm
# co-appears with a DIRECT CADE defendant. These are the "label-defining" tenders:
# co-appearance with a defendant is exactly what creates a cobidder label. If the
# bid-layer AUC drops sharply, the benchmark was reading the label off the contam.
say("\n========== DESIGN F: EXCLUDE LABEL-DEFINING TENDERS ==========")
cache_featF <- file.path(dir_cache, "imhof_firm_features_excl_label.parquet")
if (file.exists(cache_featF)) {
  say("loading cached label-excluded firm features")
  firm_features_F <- as.data.table(read_parquet(cache_featF))
} else {
  say("recomputing firm features excluding defendant-co-appearance tender-items (DuckDB)")
  suppressPackageStartupMessages({ library(DBI); library(duckdb) })
  dir.create("/tmp/duckdb_spill", recursive=TRUE, showWarnings=FALSE)
  con <- dbConnect(duckdb())
  dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
  dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")
  dbWriteTable(con, "direct", data.frame(firm_code = direct_codes_raw), overwrite=TRUE)
  # label-defining tender-items: (oc,item) where any direct defendant placed a bid
  label_items <- as.data.table(dbGetQuery(con, sprintf("
    WITH bl AS (
      SELECT printf('%%014.0f', CAST(\"códigofornecedor\" AS DOUBLE)) AS firm_code,
             CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
      FROM read_parquet('%s'))
    SELECT DISTINCT b.oc, b.item
    FROM bl b JOIN direct d ON b.firm_code = d.firm_code", bl_path)))
  dbDisconnect(con, shutdown=TRUE)
  say("label-defining tender-items (defendant present): %s", format(nrow(label_items), big.mark=","))

  # rebuild firm features over tender_features EXCLUDING those items
  bl2 <- as.data.table(read_parquet(bl_path))
  bl2[, firm_code := norm14(`códigofornecedor`)]
  bl2 <- bl2[!is.na(bid_price) & bid_price > 0, .(firm_code, oc=numerodaoc, item=`códigoitem`)]
  setkey(label_items, oc, item); setkey(bl2, oc, item)
  bl2[, is_label := FALSE]
  bl2[label_items, is_label := TRUE]
  say("firm-participation rows flagged label-defining: %s of %s (%.2f%%)",
      format(sum(bl2$is_label), big.mark=","), format(nrow(bl2), big.mark=","),
      100*mean(bl2$is_label))
  tf <- copy(tender_features); setnames(tf, c("numerodaoc","codigoitem"), c("oc","item"))
  ft <- merge(bl2[is_label==FALSE], tf, by=c("oc","item"))
  firm_features_F <- ft[!is.na(cv), .(
    imhof_cv_mean = mean(cv, na.rm=TRUE), imhof_cv_sd = sd(cv, na.rm=TRUE),
    imhof_skew_mean = mean(skew, na.rm=TRUE), imhof_kurt_mean = mean(kurt, na.rm=TRUE),
    imhof_spread_mean = mean(spread, na.rm=TRUE), imhof_minmax_mean = mean(min_max_log, na.rm=TRUE),
    imhof_second_low_mean = mean(second_lowest_dist, na.rm=TRUE), n_tenders_priced = .N
  ), by = firm_code]
  write_parquet(firm_features_F, cache_featF)
  rm(bl2, tf, ft); gc()
}

# rebuild candidate pool with the label-excluded features
alF <- fp[always_loser==1L, .(firm_code, tenders_count)][!firm_code %in% direct_codes_raw]
alF <- merge(alF, firm_features_F, by="firm_code", all.x=TRUE)
alF[, is_cade := as.integer(firm_code %in% pos_codes)]
alF[, score_award := log1p(tenders_count)]
alF[, fl14 := as.integer(tenders_count >= 14L)]
alF[, has_imhof := as.integer(!is.na(imhof_cv_mean) & is.finite(imhof_cv_mean) &
                              !is.na(imhof_kurt_mean) & is.finite(imhof_kurt_mean) &
                              !is.na(imhof_skew_mean) & is.finite(imhof_skew_mean))]
alF_c <- alF[has_imhof==1L]; setorder(alF_c, firm_code); alF_c[, firm_id := .I]
say("Design F pool (complete features after exclusion): N=%s ; positives=%d (was N=%s/%d)",
    format(nrow(alF_c), big.mark=","), sum(alF_c$is_cade),
    format(nrow(al_complete), big.mark=","), sum(al_complete$is_cade))
set.seed(SEED); alF_c[, fold_random := sample(rep(1:5, length.out=.N))]
yF <- alF_c$is_cade
preds_bidF  <- rf_oof_preds(alF_c, IMHOF_FEATS, alF_c$fold_random)
preds_combF <- rf_oof_preds(alF_c, c("score_award", IMHOF_FEATS), alF_c$fold_random)
say("Design F (random 5-fold, label-defining tenders EXCLUDED) AUC -- award_cont=%.4f bid_RF=%.4f combined_RF=%.4f",
    m_rocauc(yF, alF_c$score_award), m_rocauc(yF, preds_bidF), m_rocauc(yF, preds_combF))
say("  contamination magnitude: bid AUC %.4f (A) -> %.4f (F)  delta=%.4f",
    m_rocauc(y, preds_bidA), m_rocauc(yF, preds_bidF), m_rocauc(yF, preds_bidF) - m_rocauc(y, preds_bidA))

add_preds("F_excl_label_tenders", "award_continuous", alF_c, alF_c$score_award, alF_c$fold_random)
add_preds("F_excl_label_tenders", "award_FL14",       alF_c, alF_c$fl14, alF_c$fold_random)
add_preds("F_excl_label_tenders", "bid_RF",           alF_c, preds_bidF,  alF_c$fold_random)
add_preds("F_excl_label_tenders", "combined_RF",      alF_c, preds_combF, alF_c$fold_random)
stamp("5_designF")

# =============================================================================
# STAGE 6. DESIGN G -- ENVIRONMENT HOLDOUT (largest item-group)
# =============================================================================
# Hold out the largest item-group among positives; train RF on the rest, evaluate
# on the held-out environment's candidates. item_group = first 2 chars of item code,
# assigned per firm by modal participation (DuckDB).
say("\n========== DESIGN G: ENVIRONMENT HOLDOUT (largest item-group) ==========")
suppressPackageStartupMessages({ library(DBI); library(duckdb) })
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbWriteTable(con, "cand", data.frame(firm_code = al_complete$firm_code), overwrite=TRUE)
igmap <- as.data.table(dbGetQuery(con, sprintf("
  WITH bl AS (
    SELECT printf('%%014.0f', CAST(\"códigofornecedor\" AS DOUBLE)) AS firm_code,
           SUBSTR(CAST(\"códigoitem\" AS VARCHAR),1,2) AS item_group
    FROM read_parquet('%s')),
  j AS (SELECT b.firm_code, b.item_group FROM bl b JOIN cand c ON b.firm_code=c.firm_code),
  cnt AS (SELECT firm_code, item_group, COUNT(*) n,
            ROW_NUMBER() OVER (PARTITION BY firm_code ORDER BY COUNT(*) DESC, item_group) rn
          FROM j GROUP BY firm_code, item_group)
  SELECT firm_code, item_group FROM cnt WHERE rn=1", bl_path)))
dbDisconnect(con, shutdown=TRUE)
alG <- merge(al_complete, igmap, by="firm_code", all.x=TRUE)
pos_ig <- alG[is_cade==1L, .N, by=item_group][order(-N)]
largest_ig <- pos_ig$item_group[1]
say("largest positive item-group = %s (%d positives). holding it out as test.", largest_ig, pos_ig$N[1])
alG[, foldG := ifelse(item_group == largest_ig, 1L, 2L)]   # 1=test (held-out), 2=train
# train on fold 2, predict fold 1
yG_test <- alG[foldG==1L]$is_cade
preds_bidG  <- rf_oof_preds(alG, IMHOF_FEATS, alG$foldG)
preds_combG <- rf_oof_preds(alG, c("score_award", IMHOF_FEATS), alG$foldG)
test_idx_G <- which(alG$foldG==1L)
say("Design G held-out item-group=%s : N_test=%d pos_test=%d", largest_ig, length(test_idx_G), sum(yG_test))
say("Design G AUC on held-out env -- award_cont=%.4f bid_RF=%.4f combined_RF=%.4f",
    m_rocauc(yG_test, alG[foldG==1L]$score_award),
    m_rocauc(yG_test, preds_bidG[test_idx_G]),
    m_rocauc(yG_test, preds_combG[test_idx_G]))
add_preds("G_env_holdout", "award_continuous", alG[foldG==1L], alG[foldG==1L]$score_award, rep(1L, length(test_idx_G)))
add_preds("G_env_holdout", "award_FL14",       alG[foldG==1L], alG[foldG==1L]$fl14, rep(1L, length(test_idx_G)))
add_preds("G_env_holdout", "bid_RF",           alG[foldG==1L], preds_bidG[test_idx_G],  rep(1L, length(test_idx_G)))
add_preds("G_env_holdout", "combined_RF",      alG[foldG==1L], preds_combG[test_idx_G], rep(1L, length(test_idx_G)))
stamp("6_designG")

# =============================================================================
# STAGE 7. TABLE Q -- BID-LAYER PERFORMANCE ACROSS DESIGNS
# =============================================================================
say("\n========== TABLE Q: PERFORMANCE ACROSS DESIGNS ==========")
# helper to make a row given (design, model, y, scores, support_retained)
bootB <- 1000L
make_row <- function(design, model, yv, sv, support_retained) {
  mb <- metric_block(yv, sv)
  # bootstrap CI for PR-AUC and precision@500
  ci_pr  <- tryCatch(bootstrap_metric_ci(yv, sv, average_precision, B=bootB, seed=SEED),
                     error=function(e) data.frame(ci_lo=NA, ci_hi=NA))
  ci_p500 <- tryCatch(bootstrap_metric_ci(yv, sv, function(l,s,...) precision_at_k(l,s,500,...),
                     B=bootB, seed=SEED), error=function(e) data.frame(ci_lo=NA, ci_hi=NA))
  data.table(
    validation_design=design, model=model, N=length(yv), positives=sum(yv==1),
    support_retained=support_retained,
    roc_auc=mb$roc_auc, pr_auc=mb$pr_auc,
    pr_auc_ci_lo=ci_pr$ci_lo, pr_auc_ci_hi=ci_pr$ci_hi,
    prec_100=mb$prec_100, prec_250=mb$prec_250, prec_500=mb$prec_500, prec_1000=mb$prec_1000,
    prec_500_ci_lo=ci_p500$ci_lo, prec_500_ci_hi=ci_p500$ci_hi,
    rec_100=mb$rec_100, rec_250=mb$rec_250, rec_500=mb$rec_500, rec_1000=mb$rec_1000,
    lift_500=mb$lift_500, fp_500=mb$fp_500, fn_500=mb$fn_500)
}
nz <- function(v) v[!is.na(v)]
qrows <- list()
# Design A
qrows[[length(qrows)+1]] <- make_row("A_pooled_random","award_continuous", y, preds_award_cont, 1.0)
qrows[[length(qrows)+1]] <- make_row("A_pooled_random","award_FL14",       y, preds_award_fl14, 1.0)
qrows[[length(qrows)+1]] <- make_row("A_pooled_random","bid_RF",           y, preds_bidA, 1.0)
qrows[[length(qrows)+1]] <- make_row("A_pooled_random","combined_RF",      y, preds_combA, 1.0)
# Design E (pooled OOF; drop NA preds for bid/combined)
okE_b <- !is.na(preds_bidE); okE_c <- !is.na(preds_combE)
qrows[[length(qrows)+1]] <- make_row("E_case_grouped","award_continuous", y, preds_award_cont, 1.0)
qrows[[length(qrows)+1]] <- make_row("E_case_grouped","award_FL14",       y, preds_award_fl14, 1.0)
qrows[[length(qrows)+1]] <- make_row("E_case_grouped","bid_RF",           y[okE_b], preds_bidE[okE_b], mean(okE_b))
qrows[[length(qrows)+1]] <- make_row("E_case_grouped","combined_RF",      y[okE_c], preds_combE[okE_c], mean(okE_c))
# Design F
qrows[[length(qrows)+1]] <- make_row("F_excl_label_tenders","award_continuous", yF, alF_c$score_award, nrow(alF_c)/nrow(al_complete))
qrows[[length(qrows)+1]] <- make_row("F_excl_label_tenders","award_FL14",       yF, alF_c$fl14, nrow(alF_c)/nrow(al_complete))
qrows[[length(qrows)+1]] <- make_row("F_excl_label_tenders","bid_RF",           yF, preds_bidF, nrow(alF_c)/nrow(al_complete))
qrows[[length(qrows)+1]] <- make_row("F_excl_label_tenders","combined_RF",      yF, preds_combF, nrow(alF_c)/nrow(al_complete))
# Design G (held-out env only)
qrows[[length(qrows)+1]] <- make_row("G_env_holdout","award_continuous", yG_test, alG[foldG==1L]$score_award, length(test_idx_G)/nrow(alG))
qrows[[length(qrows)+1]] <- make_row("G_env_holdout","award_FL14",       yG_test, alG[foldG==1L]$fl14, length(test_idx_G)/nrow(alG))
qrows[[length(qrows)+1]] <- make_row("G_env_holdout","bid_RF",           yG_test, preds_bidG[test_idx_G], length(test_idx_G)/nrow(alG))
qrows[[length(qrows)+1]] <- make_row("G_env_holdout","combined_RF",      yG_test, preds_combG[test_idx_G], length(test_idx_G)/nrow(alG))
tableQ <- rbindlist(qrows)
# interpretation column
interp <- function(design) switch(design,
  A_pooled_random = "full-observability diagnostic upper bound (random CV optimism)",
  E_case_grouped = "case-holdout robustness: positives clustered by case never co-train",
  F_excl_label_tenders = "contamination test: features blind to defendant-co-appearance tenders",
  G_env_holdout = "environment generalization to a held-out item-group")
tableQ[, interpretation := sapply(validation_design, interp)]
say("--- Table Q (ROC-AUC / PR-AUC by design x model) ---")
print(tableQ[, .(validation_design, model, N, positives,
                 roc=round(roc_auc,3), pr=round(pr_auc,3),
                 p500=round(prec_500,4), r500=round(rec_500,3))])
fwrite(tableQ, file.path(dir_main_t, "table_Q_bid_layer_performance.csv"))

# LaTeX (compact: design, model, N, pos, ROC, PR, prec@500, rec@500)
fmt <- function(x,d=3) ifelse(is.na(x),"--",formatC(x,format="f",digits=d))
texQ <- c("% table_Q_bid_layer_performance.tex (auto: 09_bid_benchmark_validation.R)",
  "\\begin{tabular}{llrrcccc}", "\\toprule",
  "Design & Model & $N$ & Pos & ROC & PR-AUC & Prec@500 & Rec@500 \\\\", "\\midrule",
  vapply(seq_len(nrow(tableQ)), function(i) sprintf("%s & %s & %s & %d & %s & %s & %s & %s \\\\",
    gsub("_","\\\\_",tableQ$validation_design[i]), gsub("_","\\\\_",tableQ$model[i]),
    format(tableQ$N[i],big.mark=","), tableQ$positives[i],
    fmt(tableQ$roc_auc[i]), fmt(tableQ$pr_auc[i]),
    fmt(tableQ$prec_500[i],4), fmt(tableQ$rec_500[i])), character(1)),
  "\\bottomrule","\\end{tabular}")
writeLines(texQ, file.path(dir_main_t, "table_Q_bid_layer_performance.tex"))

# predictions export + fold audit
preds_all <- rbindlist(pred_store, fill=TRUE)
fwrite(preds_all, file.path(dir_cache, "bid_benchmark_predictions.csv"))
fold_audit <- preds_all[, .(N=.N, positives=sum(target==1),
                            na_score=sum(is.na(score_predicted))),
                        by=.(validation_design, model_name, fold_id)][order(validation_design, model_name, fold_id)]
fwrite(fold_audit, file.path(dir_diag, "bid_benchmark_fold_audit.csv"))
say("wrote table_Q + predictions (%s rows) + fold audit", format(nrow(preds_all), big.mark=","))
stamp("7_tableQ")

# =============================================================================
# STAGE 8. TABLE R -- COMPLEMENTARITY (rank corr, incremental, top-k overlap)
# =============================================================================
say("\n========== TABLE R: COMPLEMENTARITY ==========")
# Use Design A (pooled diagnostic) AND Design E (case-grouped) bid/combined preds.
spearman <- function(a, b) suppressWarnings(cor(a, b, method="spearman", use="complete.obs"))
cob_idx <- which(y==1); non_idx <- which(y==0)

# (1) rank correlation award score vs bid RF score (pooled A)
rc_all  <- spearman(preds_award_cont, preds_bidA)
rc_cob  <- spearman(preds_award_cont[cob_idx], preds_bidA[cob_idx])
rc_non  <- spearman(preds_award_cont[non_idx], preds_bidA[non_idx])
say("Spearman(award, bid_RF) [A] : overall=%.3f cobidders=%.3f non=%.3f", rc_all, rc_cob, rc_non)
# also under E
okE <- !is.na(preds_bidE)
rc_all_E <- spearman(preds_award_cont[okE], preds_bidE[okE])

# (2) incremental: bid-only vs bid+award ; award-only vs award+bid  (Design A)
dl_bid_vs_comb   <- delong_test(y, preds_combA, preds_bidA)
dl_award_vs_comb <- delong_test(y, preds_combA, preds_award_cont)
pr_bid <- m_prauc(y, preds_bidA); pr_comb <- m_prauc(y, preds_combA); pr_award <- m_prauc(y, preds_award_cont)
p500_bid <- m_prec(y, preds_bidA,500); p500_comb <- m_prec(y, preds_combA,500); p500_award <- m_prec(y, preds_award_cont,500)
say("[A] PR-AUC bid=%.3f award=%.3f combined=%.3f  | dPR(bid->comb)=%.3f dPR(award->comb)=%.3f",
    pr_bid, pr_award, pr_comb, pr_comb-pr_bid, pr_comb-pr_award)
say("[A] DeLong combined vs bid: Z=%.3f p=%.2e ; combined vs award: Z=%.3f p=%.2e",
    dl_bid_vs_comb$z, dl_bid_vs_comb$p, dl_award_vs_comb$z, dl_award_vs_comb$p)
# under E (case-grouped)
pr_bidE <- m_prauc(y[okE], preds_bidE[okE]); pr_combE <- m_prauc(y[!is.na(preds_combE)], preds_combE[!is.na(preds_combE)])
okEc <- !is.na(preds_combE) & !is.na(preds_bidE)
dl_bid_vs_comb_E <- delong_test(y[okEc], preds_combE[okEc], preds_bidE[okEc])
say("[E] PR-AUC bid=%.3f combined=%.3f dPR=%.3f ; DeLong comb vs bid Z=%.3f p=%.2e",
    pr_bidE, pr_combE, pr_combE-pr_bidE, dl_bid_vs_comb_E$z, dl_bid_vs_comb_E$p)

# (3) top-k overlap
topk_codes <- function(score, k) al_complete$firm_code[order(-score, al_complete$firm_id)][1:k]
overlap_rows <- list()
for (k in c(100,250,500,1000)) {
  a_top <- topk_codes(preds_award_cont, k); b_top <- topk_codes(preds_bidA, k); c_top <- topk_codes(preds_combA, k)
  posc <- al_complete[is_cade==1L]$firm_code
  ov <- length(intersect(a_top, b_top))
  cap_a <- sum(posc %in% a_top); cap_b <- sum(posc %in% b_top); cap_both <- sum(posc %in% intersect(a_top,b_top)); cap_c <- sum(posc %in% c_top)
  netnew_award_to_bid <- sum(posc %in% setdiff(a_top, b_top))   # positives award catches that bid misses
  netnew_bid_to_award <- sum(posc %in% setdiff(b_top, a_top))
  overlap_rows[[as.character(k)]] <- data.table(
    k=k, award_bid_overlap=ov, overlap_frac=ov/k,
    pos_award=cap_a, pos_bid=cap_b, pos_both=cap_both, pos_combined=cap_c,
    netnew_award_over_bid=netnew_award_to_bid, netnew_bid_over_award=netnew_bid_to_award)
}
overlap_tab <- rbindlist(overlap_rows)
say("--- top-k overlap (Design A) ---"); print(overlap_tab)

# (4) residual complementarity: does award score predict positives missed by bid-only top-500?
b_top500 <- topk_codes(preds_bidA, 500)
residual_pos <- al_complete[is_cade==1L & !firm_code %in% b_top500]
res_y <- as.integer(al_complete$is_cade==1L & !al_complete$firm_code %in% b_top500)
res_among <- al_complete[!firm_code %in% b_top500]   # candidates not flagged by bid top-500
res_y2 <- as.integer(res_among$firm_code %in% residual_pos$firm_code)
res_auc_award <- m_rocauc(res_y2, res_among$score_award)
say("residual complementarity: %d positives missed by bid top-500; award AUC over residual pool=%.3f",
    nrow(residual_pos), res_auc_award)

# assemble table R
tableR <- data.table(
  quantity = c(
    "spearman_award_bid_overall_A","spearman_award_bid_cobidders_A","spearman_award_bid_noncob_A",
    "spearman_award_bid_overall_E",
    "prauc_bid_A","prauc_award_A","prauc_combined_A",
    "dprauc_bid_to_combined_A","dprauc_award_to_combined_A",
    "delong_z_combined_vs_bid_A","delong_p_combined_vs_bid_A",
    "delong_z_combined_vs_award_A","delong_p_combined_vs_award_A",
    "prauc_bid_E","prauc_combined_E","dprauc_bid_to_combined_E",
    "delong_z_combined_vs_bid_E","delong_p_combined_vs_bid_E",
    "prec500_bid_A","prec500_award_A","prec500_combined_A",
    "residual_pos_missed_by_bid_top500","award_auc_over_bid_residual_pool"),
  value = c(rc_all, rc_cob, rc_non, rc_all_E,
            pr_bid, pr_award, pr_comb, pr_comb-pr_bid, pr_comb-pr_award,
            dl_bid_vs_comb$z, dl_bid_vs_comb$p, dl_award_vs_comb$z, dl_award_vs_comb$p,
            pr_bidE, pr_combE, pr_combE-pr_bidE, dl_bid_vs_comb_E$z, dl_bid_vs_comb_E$p,
            p500_bid, p500_award, p500_comb, nrow(residual_pos), res_auc_award))
fwrite(tableR, file.path(dir_main_t, "table_R_award_bid_complementarity.csv"))
fwrite(overlap_tab, file.path(dir_diag, "bid_benchmark_topk_overlap.csv"))
texR <- c("% table_R_award_bid_complementarity.tex (auto: 09_bid_benchmark_validation.R)",
  "\\begin{tabular}{lr}", "\\toprule", "Quantity & Value \\\\", "\\midrule",
  vapply(seq_len(nrow(tableR)), function(i) sprintf("%s & %s \\\\",
    gsub("_","\\\\_",tableR$quantity[i]),
    if (grepl("_p_", tableR$quantity[i])) formatC(tableR$value[i],format="e",digits=2) else fmt(tableR$value[i],4)),
    character(1)),
  "\\bottomrule","\\end{tabular}")
writeLines(texR, file.path(dir_main_t, "table_R_award_bid_complementarity.tex"))

# ---- FIGURES: PR curves, rank overlap, score scatter -----------------------
pr_curve <- function(yv, sv, label) {
  o <- order(-sv, seq_along(sv)); yo <- yv[o]
  P <- sum(yo==1); tp <- cumsum(yo==1); fp <- cumsum(yo==0)
  data.table(model=label, recall=tp/P, precision=tp/(tp+fp))
}
prc <- rbindlist(list(
  pr_curve(y, preds_award_cont, "Award (continuous)"),
  pr_curve(y, preds_bidA, "Bid-layer RF (Imhof)"),
  pr_curve(y, preds_combA, "Combined award+bid RF"),
  pr_curve(y[okE], preds_bidE[okE], "Bid-layer RF (case-grouped)")))
pPR <- ggplot(prc, aes(recall, precision, colour=model)) + geom_line(linewidth=0.8) +
  labs(title="Precision-recall: award, bid-layer, and combined",
       subtitle="Design A pooled (full-observability diagnostic) + bid under case-grouped folds",
       x="Recall", y="Precision", colour=NULL,
       caption="Alt text: PR curves comparing award score, bid-layer RF, combined model (pooled random CV), and bid-layer RF under case-grouped folds.") +
  theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave(file.path(dir_main_f, "fig_award_bid_pr_curves.pdf"), pPR, width=7.5, height=5, device=cairo_pdf)

ov_long <- melt(overlap_tab[, .(k, pos_award, pos_bid, pos_both, pos_combined)],
                id.vars="k", variable.name="set", value.name="positives")
pOV <- ggplot(ov_long, aes(factor(k), positives, fill=set)) +
  geom_col(position="dodge") +
  labs(title="Positives captured in top-k: award vs bid vs combined",
       subtitle="Design A pooled diagnostic; 'both' = captured by award AND bid top-k",
       x="Top-k flagged firms", y="Positive cobidders captured", fill=NULL,
       caption="Alt text: grouped bar chart of positive cobidders captured in top-k by award-only, bid-only, both, and combined models.") +
  theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave(file.path(dir_main_f, "fig_award_bid_rank_overlap.pdf"), pOV, width=7.5, height=5, device=cairo_pdf)

sc <- data.table(award_rank=rank(-preds_award_cont), bid_rank=rank(-preds_bidA), is_cade=factor(y))
pSC <- ggplot(sc, aes(award_rank, bid_rank, colour=is_cade)) +
  geom_point(alpha=0.25, size=0.7) +
  scale_colour_manual(values=c("0"="grey70","1"="#9B1B30"), labels=c("non-cobidder","cobidder")) +
  labs(title="Award-score rank vs bid-RF-score rank",
       subtitle=sprintf("Spearman overall=%.3f; cobidders highlighted", rc_all),
       x="Award-score rank (1 = highest risk)", y="Bid-RF rank", colour=NULL,
       caption="Alt text: scatter of firm ranks by award score vs bid RF score; cobidders highlighted in red.") +
  theme_minimal(base_size=11) + theme(legend.position="bottom")
ggsave(file.path(dir_app_f, "fig_award_bid_score_scatter.pdf"), pSC, width=7, height=6, device=cairo_pdf)
say("wrote table_R + 3 figures")
stamp("8_tableR")

# =============================================================================
# STAGE 9. TABLE S -- LEAKAGE AUDIT
# =============================================================================
say("\n========== TABLE S: LEAKAGE AUDIT ==========")
tableS <- data.table(
  design = c("award_full","award_strict_timing","bid_full","bid_excl_label_defining_tenders",
             "bid_strict_timing","combined_full","combined_strict","LOCO_bid","LOCO_combined"),
  score_uses_future_participation = c("yes","no(2009-2016)","n/a","n/a","blocked","yes","partial","n/a","yes"),
  bid_features_use_future_bids = c("n/a","n/a","yes","yes","blocked","yes","blocked","yes","yes"),
  bid_features_include_label_defining_tenders = c("n/a","n/a","yes","no","blocked","yes","blocked","yes","yes"),
  direct_defendant_tenders_in_features = c("n/a","n/a","yes","no","blocked","yes","blocked","yes","yes"),
  case_labels_used_in_training = c("no","no","yes(random folds)","yes(random folds)","blocked","yes","yes","held-out by case","held-out by case"),
  fold_grouping = c("none(rank score)","temporal","random","random","blocked","random","temporal","case","case"),
  leakage_status = c("clean","clean","diagnostic_only","diagnostic_only(reduced)","blocked","diagnostic_only","blocked","case-holdout","case-holdout"),
  allowed_claim = c(
    "operational low-cost screen","operational temporal-holdout screen",
    "forensic-stage full-observability diagnostic","contamination-controlled forensic diagnostic",
    "n/a (cannot run)","forensic-stage full-observability diagnostic","n/a (cannot run)",
    "case-holdout robustness of bid layer","case-holdout robustness of combined layer"),
  forbidden_claim = c(
    "proof of cartel role","proof of cartel role",
    "real-time bid-layer triage without bid recovery; no leakage with full-period features",
    "no leakage with full-period features",
    "any operational claim","real-time triage without bid recovery; no leakage",
    "any operational claim","first-stage operational screen","first-stage operational screen"),
  notes = c(
    "score = log1p(tenders_count), CADE-label-independent rank",
    "Sub6 strict 2009-2016 -> 2017-2019 holdout",
    "Imhof features need ALL within-tender bids -> not first-stage; random CV = optimistic",
    "features recomputed excluding defendant-co-appearance tenders (Design F)",
    "bid features cannot be cleanly time-limited without per-period re-derivation of within-tender moments",
    "combines award + bid RF under random folds",
    "would require re-deriving bid moments on a time-limited bid panel -> blocked",
    "Design E per-case holdout: held-out case positives never co-train",
    "Design E combined per-case holdout"))
fwrite(tableS, file.path(dir_main_t, "table_S_bid_layer_leakage_audit.csv"))
texS <- c("% table_S_bid_layer_leakage_audit.tex (auto: 09_bid_benchmark_validation.R)",
  "\\begin{tabular}{llll}", "\\toprule",
  "Design & Fold grouping & Leakage status & Allowed claim \\\\", "\\midrule",
  vapply(seq_len(nrow(tableS)), function(i) sprintf("%s & %s & %s & %s \\\\",
    gsub("_","\\\\_",tableS$design[i]), gsub("_","\\\\_",tableS$fold_grouping[i]),
    gsub("_","\\\\_",tableS$leakage_status[i]), tableS$allowed_claim[i]), character(1)),
  "\\bottomrule","\\end{tabular}")
writeLines(texS, file.path(dir_main_t, "table_S_bid_layer_leakage_audit.tex"))
say("wrote table_S (%d rows)", nrow(tableS))
stamp("9_tableS")

# =============================================================================
# STAGE 10. TABLE F (appendix) -- CALIBRATION + ERROR ANALYSIS
# =============================================================================
say("\n========== TABLE F (appendix): CALIBRATION + ERROR ANALYSIS ==========")
# calibration of the combined RF (Design A) by decile of predicted prob
cal_dt <- data.table(p=preds_combA, y=y)
# rank-based deciles (many predicted probs are tied at 0 -> quantile breaks not unique)
cal_dt[, decile := as.integer(cut(rank(p, ties.method="first"),
                                  breaks=10, include.lowest=TRUE, labels=FALSE))]
calib <- cal_dt[, .(n=.N, mean_pred=mean(p), obs_rate=mean(y)), by=decile][order(decile)]
brier <- mean((preds_combA - y)^2)
calib[, brier_overall := brier]
fwrite(calib, file.path(dir_app_t, "table_F_bid_model_calibration.csv"))
say("combined RF Brier=%.5f ; calibration by decile:", brier)
print(calib[, .(decile, n, mean_pred=round(mean_pred,4), obs_rate=round(obs_rate,4))])

pCAL <- ggplot(calib, aes(mean_pred, obs_rate)) +
  geom_abline(slope=1, intercept=0, linetype="dashed", colour="grey60") +
  geom_point(size=2.5, colour="#9B1B30") + geom_line(colour="#9B1B30") +
  labs(title="Calibration: combined award+bid RF (Design A)",
       subtitle=sprintf("Brier=%.4f; observed vs expected by predicted-probability decile", brier),
       x="Mean predicted probability", y="Observed cobidder rate",
       caption="Alt text: calibration curve of combined RF, observed cobidder rate vs mean predicted probability by decile, with 45-degree reference line.") +
  theme_minimal(base_size=11)
ggsave(file.path(dir_app_f, "fig_bid_model_calibration.pdf"), pCAL, width=6.5, height=5, device=cairo_pdf)

# error analysis @500 for combined RF (Design A): TP/FP/FN + top environments
setorder(alG, firm_code)   # alG has item_group; align to al_complete order
ig_by_firm <- setNames(igmap$item_group, igmap$firm_code)
err <- copy(al_complete)
err[, comb_score := preds_combA]
setorder(err, -comb_score, firm_id)
err[, rank := .I]
err[, item_group := ig_by_firm[firm_code]]
top500 <- err[rank<=500]
tp <- top500[is_cade==1L]; fp <- top500[is_cade==0L]; fn <- err[rank>500 & is_cade==1L]
say("combined RF @500 (Design A): TP=%d FP=%d FN=%d", nrow(tp), nrow(fp), nrow(fn))
err_summary <- rbindlist(list(
  data.table(error_type="TP", item_group=tp$item_group),
  data.table(error_type="FP", item_group=fp$item_group),
  data.table(error_type="FN", item_group=fn$item_group)))
err_env <- err_summary[, .N, by=.(error_type, item_group)][order(error_type, -N)]
err_env[, note := "FPs are non-labeled firms under the canonical broad AL cobidder target (651), not 'bad firms'"]
fwrite(err_env, file.path(dir_diag, "bid_benchmark_error_analysis.csv"))
say("top FP item-groups:"); print(head(err_env[error_type=="FP"], 5))
say("top FN item-groups:"); print(head(err_env[error_type=="FN"], 5))
stamp("10_tableF")

# =============================================================================
# STAGE 11. TABLE P + MODEL AUDIT MARKDOWN
# =============================================================================
say("\n========== TABLE P: MODEL AUDIT ==========")
tableP <- data.table(
  model_name = c("Award continuous","Award FL14","Bid-layer RF (Imhof)","Combined award+bid RF","Opportunity-adjusted award (Sub5)"),
  information_layer = c("award/participation","award/participation","bid microdata","award+bid","award/participation (exposure-adjusted)"),
  features = c("log1p(tenders_count)","1[tenders_count>=14]",
               paste(IMHOF_FEATS, collapse="; "),
               paste(c("log1p(tenders_count)", IMHOF_FEATS), collapse="; "),
               "within-opportunity-cell award score (see Sub5/script 76)"),
  learner = c("rank score (no learner)","rank score (no learner)","RF (ranger, 500 trees, probability)",
              "RF (ranger, 500 trees, probability)","exposure-adjusted rank score"),
  validation_scheme = c("rank (no CV needed)","rank (no CV needed)","5-fold RANDOM CV (PROBLEM: labels cluster by case)",
                        "5-fold RANDOM CV","within-opportunity / case-holdout"),
  fold_unit = c("n/a","n/a","firm (random)","firm (random)","opportunity-cell / case"),
  tuning = c("none","none","none (fixed 500 trees, no hyperparameter search)","none (fixed 500 trees)","none"),
  missingness_handling = c("complete tenders_count","complete tenders_count",
                           "candidate restricted to complete Imhof feature set (listwise)",
                           "listwise complete Imhof","complete"),
  leakage_controls = c("CADE-label-independent score","CADE-label-independent score",
                       "direct defendants excluded from pool; BUT bid features DO include label-defining tenders (contamination risk); random folds let case labels co-train",
                       "same as bid + award","direct defendants excluded; opportunity-adjusted; case-holdout"),
  candidate_pool = c("always-losers (minus defendants)","always-losers (minus defendants)",
                     "always-losers w/ complete Imhof features (minus defendants)",
                     "always-losers w/ complete Imhof features","always-losers (minus defendants)"),
  target_label = rep("is_cade (canonical broad AL cobidder label (651), in pool, not defendant)", 5),
  support_N = c(nrow(al), nrow(al), nrow(al_complete), nrow(al_complete), nrow(al)),
  positives = c(sum(al$is_cade), sum(al$is_cade), sum(al_complete$is_cade), sum(al_complete$is_cade), sum(al$is_cade)),
  operational_interpretation = c(
    "deployable low-cost screen (winners+participants only)",
    "deployable binary rule",
    "rich-data forensic benchmark; NOT first-stage (needs all within-tender bids)",
    "forensic benchmark combining cheap signal + bid microdata",
    "exposure-corrected deployable screen"),
  legal_interpretation = rep("flags/prioritizes; NOT proof of cartel role; canonical broad AL cobidder target (651)", 5),
  notes = c(
    "score_award; same target as RF models, same sample (minus feature-incompletes)",
    "binary FL14",
    "the audited object: random CV + label-defining-tender contamination are the two risks tested here",
    "pooled +0.096 PR/AUC is a full-observability diagnostic with random-CV optimism",
    "cross-reference Sub5 within-AUC 0.7715/+0.0415"))
fwrite(tableP, file.path(dir_main_t, "table_P_bid_benchmark_model_audit.csv"))
texP <- c("% table_P_bid_benchmark_model_audit.tex (auto: 09_bid_benchmark_validation.R)",
  "\\begin{tabular}{lllrr}", "\\toprule",
  "Model & Layer & Validation & $N$ & Pos \\\\", "\\midrule",
  vapply(seq_len(nrow(tableP)), function(i) sprintf("%s & %s & %s & %s & %d \\\\",
    tableP$model_name[i], gsub("_","\\\\_",tableP$information_layer[i]),
    gsub("_","\\\\_",substr(tableP$validation_scheme[i],1,28)),
    format(tableP$support_N[i],big.mark=","), tableP$positives[i]), character(1)),
  "\\bottomrule","\\end{tabular}")
writeLines(texP, file.path(dir_main_t, "table_P_bid_benchmark_model_audit.tex"))

# model audit markdown with 20 questions answered from numbers
A_auc_bid <- m_rocauc(y, preds_bidA); A_auc_award <- m_rocauc(y, preds_award_fl14); A_auc_comb <- m_rocauc(y, preds_combA)
E_auc_bid <- m_rocauc(y[okE_b], preds_bidE[okE_b]); E_auc_comb <- m_rocauc(y[okE_c], preds_combE[okE_c])
F_auc_bid <- m_rocauc(yF, preds_bidF)
md <- c(
"# Bid-layer benchmark — model audit (Step 8)",
"",
sprintf("_Generated %s by `09_bid_benchmark_validation.R` (seed %d). Numbers are from this run; never invented._", format(Sys.time()), SEED),
"",
"## Specification",
sprintf("- **Learner**: random forest (ranger, %d trees, `probability=TRUE`), num.threads=%d.", RF_TREES, RF_THREADS),
"- **Outcome**: `is_cade` (1 = canonical broad AL CADE cobidder (651), in candidate pool, not a direct defendant).",
sprintf("- **Candidate pool**: always-losers with COMPLETE Imhof feature set, direct CADE defendants excluded. N=%s, positives=%d.", format(nrow(al_complete), big.mark=","), sum(al_complete$is_cade)),
sprintf("- **Features (7, firm-mean of within-tender moments)**: %s.", paste(IMHOF_FEATS, collapse=", ")),
"- **Standardization**: none (RF is scale-invariant).",
"- **Hyperparameter tuning**: none (fixed 500 trees, default mtry).",
"- **Default CV**: 5-fold RANDOM (the PROBLEM — CADE labels cluster by case, so random folds let a case's positives co-train).",
"- **Direct defendants**: excluded from the candidate pool (they define defendant tender-items).",
"- **Bid features DO include label-defining tenders** (co-appearance with defendants) — contamination risk, tested in Design F.",
"- **No future-info control** in the bid features (full-period within-tender moments).",
"- **Same target** as the award score; **same sample** (minus feature-incomplete firms).",
"",
"## 20 questions",
sprintf("1. **What is the learner?** RF (ranger, %d trees, probability forest).", RF_TREES),
"2. **Is it tuned?** No — fixed 500 trees, default mtry/min.node.size, no grid search.",
"3. **What is the outcome?** Binary `is_cade` (canonical broad AL cobidder (651) in pool, not a defendant).",
sprintf("4. **What is the candidate pool?** Always-losers with complete Imhof features, defendants excluded (N=%s, %d positives).", format(nrow(al_complete), big.mark=","), sum(al_complete$is_cade)),
"5. **What are the features?** 7 firm-mean within-tender bid-distribution moments (CV, CV-sd, skew, kurtosis, spread, min-max-log, second-lowest-distance).",
"6. **Standardized?** No (RF scale-invariant).",
"7. **Missingness?** Listwise — pool restricted to firms with complete Imhof features.",
sprintf("8. **Default validation?** 5-fold RANDOM CV. Reproduces bid AUC=%.3f, combined AUC=%.3f (vs script-31 0.888/0.962).", A_auc_bid, A_auc_comb),
"9. **Why is random CV a problem?** CADE positives cluster by case; random folds put same-case positives in train and test, so the RF can memorize case-specific bid signatures.",
sprintf("10. **Does case-grouped CV change it?** Yes — Design E pooled bid AUC=%.3f, combined AUC=%.3f.", E_auc_bid, E_auc_comb),
"11. **Do bid features include label-defining tenders?** Yes by default (firm-mean over ALL its tenders, including defendant-co-appearance tenders).",
sprintf("12. **What happens excluding them?** Design F bid AUC=%.3f (vs %.3f pooled); contamination delta=%.3f.", F_auc_bid, A_auc_bid, F_auc_bid-A_auc_bid),
"13. **Same target as award score?** Yes — both predict `is_cade`.",
"14. **Same sample?** Award uses the full always-loser pool; RF restricts to complete-feature firms (a subset). Table Q reports each on its own N.",
"15. **Are direct defendants in the pool?** No — excluded (they define the labels).",
"16. **Is there a future-info control?** No for bid features (full-period moments). Award has a strict-timing variant (Sub6); bid strict-timing is BLOCKED (cannot re-derive within-tender moments on a time-limited panel cleanly).",
"17. **Is the complementarity real?** Pooled yes (Table R), but it is a full-observability diagnostic with random-CV optimism — see how it changes under Design E.",
"18. **What is the operational interpretation?** Bid/combined RF are rich-data FORENSIC benchmarks (need all within-tender bids); NOT first-stage triage.",
"19. **What is the legal interpretation?** Flags/prioritizes the canonical broad AL cobidder target (651); NOT proof of cartel role.",
"20. **What is the headline risk?** Two: (a) random-CV optimism (case clustering), (b) label-defining-tender contamination. Both quantified in Designs E and F.",
"",
"## Cross-references",
"- Award opportunity-adjusted within-AUC 0.7715 / +0.0415 (Sub5, script 76).",
"- Award strict-timing temporal holdout (Sub6).",
"- See Table Q (performance by design), Table R (complementarity), Table S (leakage audit).")
writeLines(md, file.path(DOCS, "bid_benchmark_model_audit.md"))
say("wrote table_P + bid_benchmark_model_audit.md")
stamp("11_tableP")

# =============================================================================
# FINAL VERDICT INPUTS
# =============================================================================
say("\n========== VERDICT INPUTS ==========")
say("A pooled : award_FL14=%.3f bid_RF=%.3f combined_RF=%.3f", A_auc_award, A_auc_bid, A_auc_comb)
say("E grouped: bid_RF=%.3f combined_RF=%.3f", E_auc_bid, E_auc_comb)
say("F excl-label: bid_RF=%.3f (delta vs A = %.3f)", F_auc_bid, F_auc_bid-A_auc_bid)
say("complementarity [A] dPR(bid->combined)=%.3f ; [E] dPR(bid->combined)=%.3f", pr_comb-pr_bid, pr_combE-pr_bidE)
say("spearman(award,bid)=%.3f ; top-500 award/bid overlap=%d", rc_all, overlap_tab[k==500]$award_bid_overlap)
say("\n=== DONE === elapsed=%.1fs", as.numeric(difftime(Sys.time(),.t0,units="secs")))
