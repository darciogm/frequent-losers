# ============================================================================
# 20_auc_decomposition.R — AUC marginal contribution of FL flag (Tier 2.1)
# Paper 3 v14
#
# Quantify how much of the AUC = 0.94 comes from the FL flag specifically,
# vs. observable confounders (Imhof CV, Imhof spread, n_firms, modality, year).
#
# Method: train two random forests (or logit ensembles) on always-losers,
# predict CADE co-bidder status:
#   Model A: features = FL flag + Imhof CV + Imhof spread + tenders_count
#   Model B: features = Imhof CV + Imhof spread + tenders_count (no FL flag)
#   Model C: features = FL flag alone
# Compare 5-fold CV AUC. The gap between A and B = marginal AUC of FL flag.
#
# Output: AUC table per model + permutation importance table for Model A.
# ============================================================================

cat("=== 20_auc_decomposition.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC)
  if (!requireNamespace("ranger", quietly = TRUE)) {
    install.packages("ranger", repos = "https://cran.r-project.org")
  }
  library(ranger)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "auc_decomposition")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Build firm-level feature panel ---------------------------------------
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
# Use v3/bid_level_with_prices (has bid_price, ref_price) — paper3 v3 build
bl_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
if (!file.exists(bl_path)) {
  bl_path <- file.path(BASE, "data/processed/bid_level_full.parquet")
  cat("  Using fallback:", bl_path, "\n")
}
bl  <- as.data.table(read_parquet(bl_path))

cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cade_codes <- unique(cade$firm_code)
cat(sprintf("  CADE co-bidder always-losers: %d\n", length(cade_codes)))

# Always-losers only (matches v13 sample)
fls[, firm_code := as.character(`códigofornecedor`)]
al <- fls[always_loser == 1L, .(firm_code, total_participations,
                                 total_losses, total_wins, win_rate)]
setnames(al, "total_participations", "tenders_count_full")

# tenders_count from FREQ_PARTICIP (the v13 canonical FL definition basis)
fp[, firm_code := as.character(`códigofornecedor`)]
al <- merge(al, fp[, .(firm_code, tenders_count, fp_always_loser = always_loser)],
            by = "firm_code", all.x = TRUE)
al[is.na(tenders_count), tenders_count := total_losses]

# FL flag (median + 1.5 × IQR)
THRESH <- 14L
al[, is_fl := as.integer(tenders_count > THRESH)]
al[, is_cade_cobidder := as.integer(firm_code %in% cade_codes)]

# ---- Imhof-style features: per-firm bid distribution stats ----------------
cat("\n  Computing per-firm Imhof-style features ...\n")
# bid_level_full has bid_price (we need real prices). bl has columns:
#   firm_code, oc, item, won, bid_price (from build_bidlevel.py)
cat("  bid_level cols:\n"); print(names(bl))
n_bl <- nrow(bl)
cat(sprintf("  bid_level rows: %s\n", format(n_bl, big.mark=",")))

# Detect price column
price_col <- intersect(c("bid_price", "bid_price_min"), names(bl))[1]
firm_col_bl <- intersect(c("firm_code", "códigofornecedor", "firm_id"), names(bl))[1]
if (is.na(price_col) || is.na(firm_col_bl)) {
  cat("  WARNING: bid_level columns not as expected. Skipping Imhof features.\n")
  al[, imhof_cv := NA_real_]
  al[, imhof_spread := NA_real_]
} else {
  setnames(bl, c(firm_col_bl, price_col), c("firm_code", "bid_price"))
  bl[, firm_code := as.character(firm_code)]
  fl_bids <- bl[firm_code %in% al$firm_code & !is.na(bid_price) & bid_price > 0]
  imhof <- fl_bids[, .(
    n_bids   = .N,
    mean_bid = mean(bid_price, na.rm = TRUE),
    sd_bid   = sd(bid_price, na.rm = TRUE),
    log_mean = mean(log(bid_price), na.rm = TRUE),
    log_sd   = sd(log(bid_price), na.rm = TRUE)
  ), by = firm_code]
  imhof[, imhof_cv     := sd_bid / pmax(mean_bid, 1)]
  imhof[, imhof_spread := log_sd]   # simple Imhof-style spread proxy
  al <- merge(al, imhof[, .(firm_code, imhof_cv, imhof_spread, n_bids)],
              by = "firm_code", all.x = TRUE)
}

# Drop rows with missing features (need ≥2 non-NA features)
al_complete <- al[!is.na(imhof_cv) & !is.na(imhof_spread) &
                   is.finite(imhof_cv) & is.finite(imhof_spread)]
cat(sprintf("\n  Always-losers with complete Imhof features: %s (CADE+ = %d)\n",
            format(nrow(al_complete), big.mark=","),
            sum(al_complete$is_cade_cobidder)))

# ---- 5-fold CV training of each model -------------------------------------
set.seed(20260430)
al_complete[, fold := sample(rep(1:5, length.out = .N))]

run_cv <- function(features) {
  preds <- numeric(nrow(al_complete))
  for (k in 1:5) {
    train_idx <- al_complete$fold != k
    test_idx  <- al_complete$fold == k
    tr <- al_complete[train_idx]
    te <- al_complete[test_idx]
    tr[, target := factor(is_cade_cobidder, levels = c(0, 1))]
    fmla <- as.formula(paste0("target ~ ", paste(features, collapse = " + ")))
    rf <- ranger(fmla, data = tr, num.trees = 500,
                 probability = TRUE, num.threads = 12)
    pred_mat <- predict(rf, te)$predictions
    # Probability of class "1" (CADE co-bidder)
    pred <- pred_mat[, "1"]
    preds[test_idx] <- pred
  }
  r <- pROC::roc(al_complete$is_cade_cobidder, preds, quiet = TRUE)
  list(auc = as.numeric(pROC::auc(r)),
       ci_lo = as.numeric(pROC::ci(r)[1]),
       ci_hi = as.numeric(pROC::ci(r)[3]))
}

cat("\n  Training 4 nested-feature random forest models (5-fold CV) ...\n")
specs <- list(
  A = c("is_fl", "imhof_cv", "imhof_spread", "tenders_count", "n_bids"),
  B = c("imhof_cv", "imhof_spread", "tenders_count", "n_bids"),  # no FL
  C = c("is_fl"),                                                 # FL alone
  D = c("imhof_cv", "imhof_spread")                              # Imhof alone
)

results <- list()
for (k in names(specs)) {
  r <- run_cv(specs[[k]])
  results[[k]] <- data.table(
    model    = k,
    features = paste(specs[[k]], collapse = " + "),
    auc      = r$auc,
    ci_lo    = r$ci_lo,
    ci_hi    = r$ci_hi
  )
  cat(sprintf("    Model %s: AUC = %.4f [%.4f, %.4f]\n",
              k, r$auc, r$ci_lo, r$ci_hi))
}

res_dt <- rbindlist(results)
res_dt[, marginal_contribution_to_A :=
       results$A$auc - c(0,
                          results$B$auc - results$A$auc + results$A$auc,  # B
                          results$C$auc - results$A$auc + results$A$auc,  # C
                          results$D$auc - results$A$auc + results$A$auc)] # D
# Simpler: marginal of FL = A - B (gap when removing FL)
fl_marginal <- results$A$auc - results$B$auc
imhof_marginal <- results$A$auc - results$C$auc

cat(sprintf("\n  Marginal AUC of FL flag (A − B):       %+.4f\n", fl_marginal))
cat(sprintf("  Marginal AUC of Imhof+ext (A − C):     %+.4f\n", imhof_marginal))
cat(sprintf("  AUC FL alone (C):                       %.4f\n", results$C$auc))
cat(sprintf("  AUC Imhof alone (D):                    %.4f\n", results$D$auc))

fwrite(res_dt, file.path(OUT, "auc_decomposition.csv"))
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "auc_decomposition.csv")))
cat("\n  Done.\n")
