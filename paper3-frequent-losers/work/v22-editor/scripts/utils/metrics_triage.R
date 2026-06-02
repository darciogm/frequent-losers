# =============================================================================
# metrics_triage.R  --  reusable triage/screening metrics for the JLEO R&R (v22)
#
# Self-contained BASE R (no pROC/PRROC dependency) so it runs anywhere and the
# toy test is deterministic. Convention throughout:
#   * `labels`  : 0/1 integer vector (1 = positive = adjudicated cobidder).
#   * `scores`  : numeric risk score; HIGHER score = HIGHER risk by default
#                 (set higher_is_risk = FALSE to flip).
#   * ties      : broken DETERMINISTICALLY. Ranking sorts by score desc, then by
#                 a stable secondary key (the original row order) so results are
#                 reproducible. AUC uses midranks (Mann-Whitney), which is the
#                 standard tie-correct estimator.
#   * missing   : rows with NA score or NA label are handled EXPLICITLY via
#                 `na_action` ("error" | "drop" | "keep_worst"); never silent.
#
# Source from a script with:  source(".../scripts/utils/metrics_triage.R")
# =============================================================================

# ---- input validation -------------------------------------------------------
.mt_check <- function(labels, scores, na_action = c("error","drop","keep_worst")) {
  na_action <- match.arg(na_action)
  if (length(labels) != length(scores))
    stop(sprintf("metrics_triage: length(labels)=%d != length(scores)=%d",
                 length(labels), length(scores)))
  if (length(labels) == 0L) stop("metrics_triage: empty input.")
  labels <- as.integer(labels)
  bad_lab <- !is.na(labels) & !(labels %in% c(0L, 1L))
  if (any(bad_lab)) stop("metrics_triage: labels must be 0/1 (or NA).")
  na_lab <- is.na(labels); na_sc <- is.na(scores)
  if (any(na_lab) && na_action == "error")
    stop(sprintf("metrics_triage: %d missing label(s); set na_action.", sum(na_lab)))
  if (any(na_sc) && na_action == "error")
    stop(sprintf("metrics_triage: %d missing score(s); set na_action.", sum(na_sc)))
  keep <- rep(TRUE, length(labels))
  if (na_action == "drop") {
    keep <- !(na_lab | na_sc)
    if (any(!keep)) warning(sprintf("metrics_triage: dropping %d row(s) with NA.", sum(!keep)))
  } else if (na_action == "keep_worst") {
    # missing score -> least-risky (ranked last); missing label still errors
    if (any(na_lab)) stop("metrics_triage: na_action='keep_worst' cannot impute labels.")
    scores[na_sc] <- -Inf
  }
  list(labels = labels[keep], scores = scores[keep])
}

# ---- deterministic risk ordering (desc), midrank helper ---------------------
.mt_order <- function(scores, higher_is_risk = TRUE) {
  s <- if (higher_is_risk) scores else -scores
  order(-s, seq_along(s))           # stable: ties keep original order
}

# ---- ROC-AUC (Mann-Whitney, tie-correct midranks) ---------------------------
roc_auc <- function(labels, scores, higher_is_risk = TRUE,
                    na_action = "error") {
  cc <- .mt_check(labels, scores, na_action)
  y <- cc$labels; s <- if (higher_is_risk) cc$scores else -cc$scores
  n1 <- sum(y == 1L); n0 <- sum(y == 0L)
  if (n1 == 0L || n0 == 0L) { warning("roc_auc: one class absent -> NA."); return(NA_real_) }
  r <- rank(s, ties.method = "average")
  (sum(r[y == 1L]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# ---- PR-AUC / average precision (step interpolation, AP estimator) ----------
average_precision <- function(labels, scores, higher_is_risk = TRUE,
                              na_action = "error") {
  cc <- .mt_check(labels, scores, na_action)
  y <- cc$labels
  o <- .mt_order(cc$scores, higher_is_risk)
  y <- y[o]
  P <- sum(y == 1L)
  if (P == 0L) { warning("average_precision: no positives -> NA."); return(NA_real_) }
  tp <- cumsum(y == 1L)
  fp <- cumsum(y == 0L)
  precision <- tp / (tp + fp)
  recall    <- tp / P
  d_recall  <- c(recall[1], diff(recall))   # AP = sum precision * delta-recall
  sum(precision * d_recall)
}
pr_auc <- average_precision

# ---- top-k operating-point metrics (k = number of flagged firms) ------------
.mt_topk <- function(labels, scores, k, higher_is_risk = TRUE, na_action = "error") {
  cc <- .mt_check(labels, scores, na_action)
  y <- cc$labels; n <- length(y)
  k <- as.integer(min(k, n))
  o <- .mt_order(cc$scores, higher_is_risk)
  flagged <- y[o][seq_len(k)]
  list(k = k, n = n, P = sum(y == 1L),
       tp = sum(flagged == 1L), fp = sum(flagged == 0L))
}
precision_at_k <- function(labels, scores, k, higher_is_risk = TRUE, na_action = "error") {
  z <- .mt_topk(labels, scores, k, higher_is_risk, na_action); z$tp / z$k }
recall_at_k <- function(labels, scores, k, higher_is_risk = TRUE, na_action = "error") {
  z <- .mt_topk(labels, scores, k, higher_is_risk, na_action)
  if (z$P == 0L) { warning("recall_at_k: no positives -> NA."); return(NA_real_) }; z$tp / z$P }
false_positives_at_k <- function(labels, scores, k, higher_is_risk = TRUE, na_action = "error") {
  .mt_topk(labels, scores, k, higher_is_risk, na_action)$fp }
false_negatives_at_k <- function(labels, scores, k, higher_is_risk = TRUE, na_action = "error") {
  z <- .mt_topk(labels, scores, k, higher_is_risk, na_action); z$P - z$tp }
lift_at_k <- function(labels, scores, k, higher_is_risk = TRUE, na_action = "error") {
  z <- .mt_topk(labels, scores, k, higher_is_risk, na_action)
  base <- z$P / z$n; if (base == 0) { warning("lift_at_k: base rate 0 -> NA."); return(NA_real_) }
  (z$tp / z$k) / base }
cost_per_true_positive <- function(labels, scores, k, cost_per_flag = 1,
                                   higher_is_risk = TRUE, na_action = "error") {
  z <- .mt_topk(labels, scores, k, higher_is_risk, na_action)
  if (z$tp == 0L) return(Inf); (z$k * cost_per_flag) / z$tp }

# ---- metrics-at-k sweep table ----------------------------------------------
DEFAULT_K_GRID <- c(100, 250, 500, 1000, 1500, 2000, 3000, 5000)
metrics_at_k_grid <- function(labels, scores, k_grid = DEFAULT_K_GRID,
                              cost_per_flag = 1, higher_is_risk = TRUE,
                              na_action = "error") {
  cc <- .mt_check(labels, scores, na_action); n <- length(cc$labels)
  ks <- sort(unique(pmin(as.integer(k_grid), n)))
  do.call(rbind, lapply(ks, function(k) {
    z <- .mt_topk(cc$labels, cc$scores, k, higher_is_risk, "error")
    data.frame(k = k, n = z$n, positives = z$P, tp = z$tp, fp = z$fp,
               fn = z$P - z$tp,
               precision = z$tp / z$k,
               recall = if (z$P) z$tp / z$P else NA_real_,
               lift = if (z$P) (z$tp / z$k) / (z$P / z$n) else NA_real_,
               cost_per_tp = if (z$tp) (z$k * cost_per_flag) / z$tp else Inf)
  }))
}

# ---- bootstrap CI for any metric -------------------------------------------
# metric_fn(labels, scores) -> scalar. Resamples rows with replacement.
bootstrap_metric_ci <- function(labels, scores, metric_fn, B = 2000L, seed = 20260602L,
                                conf = 0.95, higher_is_risk = TRUE, na_action = "error") {
  cc <- .mt_check(labels, scores, na_action)
  y <- cc$labels; s <- cc$scores; n <- length(y)
  if (is.null(seed)) stop("bootstrap_metric_ci: seed must be set (reproducibility).")
  set.seed(as.integer(seed))
  pt <- metric_fn(y, s, higher_is_risk = higher_is_risk, na_action = "error")
  reps <- numeric(B)
  for (b in seq_len(B)) {
    idx <- sample.int(n, n, replace = TRUE)
    reps[b] <- tryCatch(
      suppressWarnings(metric_fn(y[idx], s[idx], higher_is_risk = higher_is_risk, na_action = "error")),
      error = function(e) NA_real_)
  }
  a <- (1 - conf) / 2
  data.frame(estimate = pt,
             ci_lo = stats::quantile(reps, a, na.rm = TRUE, names = FALSE),
             ci_hi = stats::quantile(reps, 1 - a, na.rm = TRUE, names = FALSE),
             B = B, seed = as.integer(seed), n_valid = sum(!is.na(reps)))
}

# ---- split generators -------------------------------------------------------
# Grouped K-fold: rows sharing a group_id never straddle train/test (anti-leakage).
grouped_cv_splits <- function(group_id, k = 5L, seed = 20260602L) {
  if (is.null(seed)) stop("grouped_cv_splits: seed must be set.")
  set.seed(as.integer(seed))
  g <- unique(group_id); g <- sample(g)
  fold_of_group <- setNames(rep_len(seq_len(k), length(g)), as.character(g))
  fold <- fold_of_group[as.character(group_id)]
  lapply(seq_len(k), function(f) list(
    test  = which(fold == f),
    train = which(fold != f)))
}

# Leave-one-case-out: one fold per case_id; test = rows of that case.
leave_one_case_out_splits <- function(case_id) {
  if (all(is.na(case_id))) stop("leave_one_case_out_splits: case_id all NA (no case linkage).")
  cases <- sort(unique(case_id[!is.na(case_id)]))
  lapply(cases, function(cc) list(
    case = cc,
    test  = which(case_id == cc),
    train = which(case_id != cc | is.na(case_id))))
}

# Rolling-origin: expanding-window train up to year t, test on year t+1 (or horizon).
rolling_origin_splits <- function(year, min_train_year = NULL, horizon = 1L) {
  yrs <- sort(unique(year[!is.na(year)]))
  if (length(yrs) < 2L) stop("rolling_origin_splits: need >=2 distinct years.")
  if (is.null(min_train_year)) min_train_year <- yrs[1]
  origins <- yrs[yrs >= min_train_year & yrs < max(yrs)]
  lapply(origins, function(t) list(
    origin = t,
    train = which(year <= t),
    test  = which(year > t & year <= t + horizon)))
}

# Sanity flag so a sourcing script can confirm the lib loaded.
.METRICS_TRIAGE_VERSION <- "v22-2026-06-02"
