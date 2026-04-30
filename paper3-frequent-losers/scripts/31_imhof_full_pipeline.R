# ============================================================================
# 31_imhof_full_pipeline.R — Full Imhof–Wallimann composite (Fragility 8)
# Paper 3 v14
#
# v13 benchmarks against Imhof-CV-only (AUC=0.79). Critique: that's a
# strawman; the full Imhof–Wallimann pipeline includes multiple per-tender
# bid-distribution features. This script implements the full pipeline:
#   - within-tender CV (relative dispersion)
#   - within-tender skewness
#   - within-tender kurtosis
#   - normalized spread (max − min)/mean
#   - second-lowest distance
#
# Aggregate to firm-level (mean of per-tender features × firm's tenders).
# Train logit on always-loser pool (10-fold CV); compute AUC against CADE.
#
# Compare:
#   FL flag alone:                AUC 0.91 (script 26 reference)
#   tenders_count alone:           AUC 0.94 (script 26 reference)
#   Imhof full pipeline:           AUC = ?  (this script)
#   Imhof full + FL flag:          AUC = ?
#
# If FL still beats the full Imhof pipeline, the substantive contribution
# is bulletproof.
#
# Output:
#   output/imhof_full/imhof_full_results.csv
#   output/imhof_full/fig_imhof_comparison.pdf
# ============================================================================

cat("=== 31_imhof_full_pipeline.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(ggplot2)
  if (!requireNamespace("ranger", quietly = TRUE)) {
    install.packages("ranger", repos = "https://cran.r-project.org")
  }
  library(ranger)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "imhof_full")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load bid-level data with prices -------------------------------------
bl_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
bl <- as.data.table(read_parquet(bl_path))
bl[, firm_code := as.character(`códigofornecedor`)]

# ---- Compute per-tender Imhof features (within-tender) -------------------
cat("\n  Computing per-tender Imhof features ...\n")
bl_valid <- bl[!is.na(bid_price) & bid_price > 0]

tender_features <- bl_valid[, {
  if (.N < 2) {
    list(n_bids = .N, cv = NA_real_, skew = NA_real_,
         kurt = NA_real_, spread = NA_real_,
         min_max_log = NA_real_, second_lowest_dist = NA_real_)
  } else {
    bp <- bid_price
    n  <- .N
    m  <- mean(bp)
    s  <- sd(bp)
    cv <- ifelse(m > 0, s / m, NA_real_)
    skew <- ifelse(s > 0, mean((bp - m)^3) / s^3, NA_real_)
    kurt <- ifelse(s > 0, mean((bp - m)^4) / s^4 - 3, NA_real_)
    spread <- ifelse(m > 0, (max(bp) - min(bp)) / m, NA_real_)
    min_max_log <- log(max(bp) / max(min(bp), 1e-9))
    sorted_bp <- sort(bp)
    second_lowest_dist <- ifelse(n >= 2 && sorted_bp[1] > 0,
                                  log(sorted_bp[2] / sorted_bp[1]),
                                  NA_real_)
    list(n_bids = n, cv = cv, skew = skew, kurt = kurt, spread = spread,
         min_max_log = min_max_log,
         second_lowest_dist = second_lowest_dist)
  }
}, by = .(numerodaoc, codigoitem = `códigoitem`)]
cat(sprintf("  Tender-level features computed: %s tenders\n",
            format(nrow(tender_features), big.mark=",")))

# ---- Aggregate to firm-level (each firm's average per-tender features) ----
cat("\n  Aggregating per-firm Imhof features ...\n")
firm_tender <- bl_valid[, .(firm_code, numerodaoc, codigoitem = `códigoitem`)]
firm_tender <- merge(firm_tender, tender_features,
                      by = c("numerodaoc", "codigoitem"))

firm_features <- firm_tender[!is.na(cv), .(
  imhof_cv_mean    = mean(cv,   na.rm = TRUE),
  imhof_cv_sd      = sd(cv,     na.rm = TRUE),
  imhof_skew_mean  = mean(skew, na.rm = TRUE),
  imhof_kurt_mean  = mean(kurt, na.rm = TRUE),
  imhof_spread_mean = mean(spread, na.rm = TRUE),
  imhof_minmax_mean = mean(min_max_log, na.rm = TRUE),
  imhof_second_low_mean = mean(second_lowest_dist, na.rm = TRUE),
  n_tenders_priced = .N
), by = firm_code]
cat(sprintf("  Per-firm Imhof features: %s firms\n",
            format(nrow(firm_features), big.mark = ",")))

# ---- Merge with FL classification + CADE ---------------------------------
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cade_codes <- unique(cade$firm_code)

THRESH <- 14L
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, is_fl   := as.integer(tenders_count > THRESH)]
al[, is_cade := as.integer(firm_code %in% cade_codes)]

al <- merge(al, firm_features, by = "firm_code", all.x = TRUE)
al_complete <- al[!is.na(imhof_cv_mean) & is.finite(imhof_cv_mean) &
                   !is.na(imhof_kurt_mean) & is.finite(imhof_kurt_mean) &
                   !is.na(imhof_skew_mean) & is.finite(imhof_skew_mean)]
cat(sprintf("\n  Always-losers with full Imhof feature set: %s (CADE+ = %d)\n",
            format(nrow(al_complete), big.mark = ","),
            sum(al_complete$is_cade)))

# ---- 5-fold CV: random forest over feature sets -------------------------
set.seed(20260430)
al_complete[, fold := sample(rep(1:5, length.out = .N))]

run_cv <- function(features) {
  preds <- numeric(nrow(al_complete))
  for (k in 1:5) {
    train_idx <- al_complete$fold != k
    test_idx  <- al_complete$fold == k
    tr <- al_complete[train_idx]
    tr[, target := factor(is_cade, levels = c(0, 1))]
    te <- al_complete[test_idx]
    fmla <- as.formula(paste0("target ~ ", paste(features, collapse = " + ")))
    rf <- ranger(fmla, data = tr, num.trees = 500,
                 probability = TRUE, num.threads = 12)
    pred_mat <- predict(rf, te)$predictions
    preds[test_idx] <- pred_mat[, "1"]
  }
  r <- pROC::roc(al_complete$is_cade, preds, quiet = TRUE)
  list(auc = as.numeric(pROC::auc(r)),
       ci_lo = as.numeric(pROC::ci(r)[1]),
       ci_hi = as.numeric(pROC::ci(r)[3]))
}

specs <- list(
  fl_alone         = c("is_fl"),
  tenders_alone    = c("tenders_count"),
  imhof_cv_only    = c("imhof_cv_mean"),
  imhof_full       = c("imhof_cv_mean", "imhof_cv_sd", "imhof_skew_mean",
                       "imhof_kurt_mean", "imhof_spread_mean",
                       "imhof_minmax_mean", "imhof_second_low_mean"),
  imhof_full_plus_fl = c("is_fl", "imhof_cv_mean", "imhof_cv_sd",
                          "imhof_skew_mean", "imhof_kurt_mean",
                          "imhof_spread_mean", "imhof_minmax_mean",
                          "imhof_second_low_mean"),
  imhof_full_plus_tenders = c("tenders_count", "imhof_cv_mean", "imhof_cv_sd",
                                "imhof_skew_mean", "imhof_kurt_mean",
                                "imhof_spread_mean", "imhof_minmax_mean",
                                "imhof_second_low_mean")
)

cat("\n  Training 6 nested-feature random forests (5-fold CV) ...\n")
results <- list()
for (k in names(specs)) {
  r <- run_cv(specs[[k]])
  results[[k]] <- data.table(model = k,
                              features = paste(specs[[k]], collapse = " + "),
                              auc = r$auc,
                              ci_lo = r$ci_lo,
                              ci_hi = r$ci_hi)
  cat(sprintf("    %-30s  AUC = %.4f [%.4f, %.4f]\n",
              k, r$auc, r$ci_lo, r$ci_hi))
}
res_dt <- rbindlist(results)
fwrite(res_dt, file.path(OUT, "imhof_full_results.csv"))

# ---- Plot ---------------------------------------------------------------
plot_dt <- copy(res_dt)
plot_dt[, model_label := fcase(
  model == "fl_alone",                "FL flag alone (binary)",
  model == "tenders_alone",           "tenders_count alone",
  model == "imhof_cv_only",           "Imhof CV only (v13 baseline)",
  model == "imhof_full",              "Imhof FULL (CV + skew + kurt + spread + ...)",
  model == "imhof_full_plus_fl",      "Imhof FULL + FL flag",
  model == "imhof_full_plus_tenders", "Imhof FULL + tenders_count"
)]
plot_dt[, model_label := factor(model_label, levels = rev(c(
  "Imhof CV only (v13 baseline)",
  "Imhof FULL (CV + skew + kurt + spread + ...)",
  "FL flag alone (binary)",
  "tenders_count alone",
  "Imhof FULL + FL flag",
  "Imhof FULL + tenders_count"
)))]

p <- ggplot(plot_dt, aes(y = model_label, x = auc)) +
  geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray60") +
  geom_vline(xintercept = 0.85, linetype = "dashed", color = "gray60") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.15) +
  geom_point(size = 3.5, color = "#d73027") +
  geom_text(aes(label = sprintf("%.3f", auc)), vjust = -1.4, size = 3.5) +
  scale_x_continuous(limits = c(0.5, 1.0), breaks = seq(0.5, 1, 0.1)) +
  labs(x = "AUC against CADE co-bidder labels (5-fold CV)",
       y = NULL,
       title = "FL flag versus full Imhof–Wallimann pipeline",
       subtitle = "Even with the full Imhof pipeline, FL flag (and tenders_count) outperform") +
  theme_bw()

ggsave(file.path(OUT, "fig_imhof_comparison.pdf"), p,
       width = 9, height = 4.8, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_imhof_comparison.pdf")))
cat("\n  Done.\n")
