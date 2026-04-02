#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════
# alternative_classification.R — Model-based + ML FL classification
# Addresses external referee Concern 2: ad hoc FL threshold
# ═══════════════════════════════════════════════════════════════════
cat("=== ALTERNATIVE FL CLASSIFICATION ===\n\n")
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(pROC); library(ggplot2)
})
setDTthreads(16L)

BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT_T <- file.path(BASE, "work/v8/tables")
OUT_F <- file.path(BASE, "work/v8/images")
cb <- c("#0072B2","#D55E00","#009E73","#CC79A7","#E69F00")

# Structural parameters from estimation
EPS_HAT   <- 0.831   # mean log-spread of cover bids above winner
SIGMA_C   <- 1.187   # cover-bid SD
SIGMA_G   <- 1.642   # genuine-bid SD

# ── 1. Load bid-level data ──────────────────────────────────────
cat("1. Loading data...\n")
bl <- as.data.table(read_parquet(file.path(BASE, "v3/data/processed/bid_level_analysis.parquet"),
  col_select=c("firm_id","oc_code","item_code","bid_price","negot_price","won","is_fl")))

# Get winning price per tender
winners <- bl[won == 1L & !is.na(negot_price) & negot_price > 0,
              .(win_price = min(negot_price)), by=.(oc_code, item_code)]

# Merge to get log-spread for each losing bid
losing <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
losing <- merge(losing, winners, by=c("oc_code","item_code"), all.x=FALSE)
losing[, log_spread := log(bid_price) - log(win_price)]
cat("  Losing bids with spread:", formatC(nrow(losing), big.mark=","), "\n")

# ── 2. Compute firm-level features ─────────────────────────────
cat("2. Computing firm-level features...\n")
firm_features <- losing[, .(
  n_participations = .N,
  n_tenders = uniqueN(paste0(oc_code, item_code)),
  mean_spread = mean(log_spread, na.rm=TRUE),
  sd_spread = sd(log_spread, na.rm=TRUE),
  median_spread = median(log_spread, na.rm=TRUE),
  pct_above_winner = mean(log_spread > 0, na.rm=TRUE),
  mean_bid_cv = sd(bid_price, na.rm=TRUE) / mean(bid_price, na.rm=TRUE),
  max_spread = max(log_spread, na.rm=TRUE),
  min_spread = min(log_spread, na.rm=TRUE),
  is_fl_any = max(is_fl)
), by=firm_id]

# Win rate (from all bids, not just losing)
win_rates <- bl[, .(win_rate = mean(won, na.rm=TRUE)), by=firm_id]
firm_features <- merge(firm_features, win_rates, by="firm_id")

# Always-losers only
always_losers <- firm_features[win_rate == 0]
cat("  Always-losers with features:", nrow(always_losers), "\n")

# ── 3. Structural classifier ──────────────────────────────────
cat("\n3. Structural classifier (likelihood ratio)...\n")

# For each always-loser, compute log-likelihood ratio:
# L(cover) / L(genuine) = P(bids | cover model) / P(bids | genuine model)
# Under Regime 2: cover bids ~ N(eps, sigma_c^2) in log-spread
# Under genuine model: log-spread ~ N(mu_g_spread, sigma_g^2)
# For genuine losing bids, mean spread depends on how far above winner

# Compute genuine losing-bid spread distribution
genuine_spread <- losing[is_fl == 0 & log_spread > 0]
mu_g_spread <- mean(genuine_spread$log_spread, na.rm=TRUE)
sd_g_spread <- sd(genuine_spread$log_spread, na.rm=TRUE)
cat("  Genuine spread: mean=", round(mu_g_spread, 4), "SD=", round(sd_g_spread, 4), "\n")
cat("  Cover spread:   mean=", round(EPS_HAT, 4), "SD=", round(SIGMA_C, 4), "\n")

# For each always-loser, compute average log-likelihood ratio
# LR = mean[ log f_cover(spread) - log f_genuine(spread) ] across their bids
always_losers[, structural_score := {
  # Log-likelihood under cover model
  ll_cover <- dnorm(mean_spread, mean=EPS_HAT, sd=SIGMA_C, log=TRUE)
  # Log-likelihood under genuine model
  ll_genuine <- dnorm(mean_spread, mean=mu_g_spread, sd=sd_g_spread, log=TRUE)
  # LR score (higher = more likely cover bidder)
  ll_cover - ll_genuine
}]

cat("  Structural score: mean=", round(mean(always_losers$structural_score, na.rm=TRUE), 3),
    "SD=", round(sd(always_losers$structural_score, na.rm=TRUE), 3), "\n")

# ── 4. Load CADE ground truth ─────────────────────────────────
cat("\n4. Loading CADE ground truth...\n")
cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade_col <- grep("fornecedor|firm", names(cade), value=TRUE, ignore.case=TRUE)
if (length(cade_col) > 0 && !"firm_id" %in% names(cade))
  setnames(cade, cade_col[1], "firm_id")
cade[, firm_id := as.character(trimws(firm_id))]
cade_ids <- unique(cade$firm_id)

always_losers[, firm_id := as.character(firm_id)]
always_losers[, is_cade := as.integer(firm_id %in% cade_ids)]
cat("  CADE positives:", sum(always_losers$is_cade), "\n")

# IQR threshold
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value=TRUE, ignore.case=TRUE)
if (length(fp_col) > 0) setnames(fp, fp_col[1], "firm_id")
fp[, firm_id := as.character(firm_id)]
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_threshold <- q[2] + 1.5 * (q[3] - q[1])

always_losers <- merge(always_losers, fp[, .(firm_id, tenders_count)],
                       by="firm_id", all.x=TRUE)
always_losers[is.na(tenders_count), tenders_count := n_tenders]
always_losers[, is_fl_iqr := as.integer(tenders_count > iqr_threshold)]

# ── 5. ROC comparison ─────────────────────────────────────────
cat("\n5. ROC comparison...\n")
al_scored <- always_losers[!is.na(structural_score) & !is.na(is_cade) & is.finite(structural_score)]

if (sum(al_scored$is_cade) >= 5) {
  # Screen 1: IQR rule (baseline)
  roc_iqr <- roc(al_scored$is_cade, al_scored$tenders_count, quiet=TRUE)
  cat("  IQR rule AUC:          ", round(auc(roc_iqr), 4), "\n")

  # Screen 2: Structural score
  roc_struct <- roc(al_scored$is_cade, al_scored$structural_score, quiet=TRUE)
  cat("  Structural score AUC:  ", round(auc(roc_struct), 4), "\n")

  # Screen 3: Combined (participation + structural)
  al_scored[, z_part := as.numeric(scale(tenders_count))]
  al_scored[, z_struct := as.numeric(scale(structural_score))]
  al_scored[, combined := z_part + z_struct]
  roc_combined <- roc(al_scored$is_cade, al_scored$combined, quiet=TRUE)
  cat("  Combined AUC:          ", round(auc(roc_combined), 4), "\n")

  # Screen 4: ML (random forest with firm features)
  cat("\n  Training Random Forest (ranger)...\n")
  library(ranger)
  ml_features <- c("n_participations","n_tenders","mean_spread","sd_spread",
                    "median_spread","pct_above_winner","mean_bid_cv")
  ml_data <- al_scored[, c("is_cade", ml_features), with=FALSE]
  ml_data <- ml_data[complete.cases(ml_data)]
  ml_data[, is_cade := factor(is_cade)]

  set.seed(42)
  # 5-fold cross-validated predictions to avoid overfitting
  ml_data[, fold := sample(rep(1:5, length.out=.N))]
  ml_data[, ml_prob := NA_real_]
  for (k in 1:5) {
    train_k <- ml_data[fold != k]
    test_k  <- ml_data[fold == k]
    rf_k <- ranger(is_cade ~ . - fold - ml_prob, data=train_k,
                   num.trees=500, probability=TRUE,
                   case.weights=ifelse(train_k$is_cade=="1", 50, 1),
                   num.threads=16L)
    ml_data[fold == k, ml_prob := predict(rf_k, test_k)$predictions[,2]]
  }
  ml_proba <- ml_data$ml_prob
  ml_data[, is_cade := as.integer(as.character(is_cade))]
  roc_ml <- roc(ml_data$is_cade, ml_proba, quiet=TRUE)
  cat("  ML (Random Forest) AUC:", round(auc(roc_ml), 4), "\n")

  # DeLong tests
  test_iqr_struct <- roc.test(roc_iqr, roc_struct, method="delong")
  test_iqr_ml <- roc.test(roc_iqr, roc_ml, method="delong")
  cat(sprintf("\n  DeLong IQR vs Structural: Z=%.3f, p=%.4f\n",
      test_iqr_struct$statistic, test_iqr_struct$p.value))
  cat(sprintf("  DeLong IQR vs ML:        Z=%.3f, p=%.4f\n",
      test_iqr_ml$statistic, test_iqr_ml$p.value))

  # ── 6. Figure ─────────────────────────────────────────────────
  cat("\n6. Generating figure...\n")
  get_roc_df <- function(r, lab) data.table(fpr=1-r$specificities, tpr=r$sensitivities, screen=lab)
  roc_data <- rbind(
    get_roc_df(roc_iqr, sprintf("IQR rule (AUC = %.3f)", auc(roc_iqr))),
    get_roc_df(roc_struct, sprintf("Structural (AUC = %.3f)", auc(roc_struct))),
    get_roc_df(roc_ml, sprintf("Random Forest (AUC = %.3f)", auc(roc_ml))),
    get_roc_df(roc_combined, sprintf("Combined (AUC = %.3f)", auc(roc_combined)))
  )

  p <- ggplot(roc_data, aes(x=fpr, y=tpr, color=screen)) +
    geom_line(linewidth=1) +
    geom_abline(slope=1, intercept=0, linetype="dashed", color="gray50") +
    scale_color_manual(values=cb[1:4]) +
    labs(x="False Positive Rate", y="True Positive Rate", color=NULL) +
    theme_bw(base_size=12) +
    theme(legend.position=c(0.62, 0.25),
          legend.background=element_rect(fill="white", color="gray80"),
          panel.grid.minor=element_blank()) +
    coord_equal()
  ggsave(file.path(OUT_F, "fig_classification_comparison.pdf"), p,
         width=6.5, height=5.5, device=cairo_pdf)
  cat("  Figure saved.\n")

  # ── 7. LaTeX table ─────────────────────────────────────────────
  cat("7. Writing LaTeX table...\n")
  tex <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{FL Classification: IQR Rule vs.\\ Model-Based Alternatives}",
    "\\label{tab:classification_comparison}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lccc}", "\\toprule",
    "Classifier & AUC & Data required & DeLong $p$ \\\\", "\\midrule",
    sprintf("IQR rule (this paper) & %.3f & Participation count & --- \\\\", auc(roc_iqr)),
    sprintf("Structural score & %.3f & Bid values & %.4f \\\\", auc(roc_struct), test_iqr_struct$p.value),
    sprintf("Random Forest (7 features) & %.3f & Bid values + firm chars & %.4f \\\\", auc(roc_ml), test_iqr_ml$p.value),
    sprintf("Combined (IQR + structural) & %.3f & Both & \\\\", auc(roc_combined)),
    "Random classifier & 0.500 & None & --- \\\\", "\\bottomrule",
    "\\end{tabular}", "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} AUC computed on always-loser firms with valid",
    "bid-level features. Ground truth: co-participation with CADE-convicted",
    "cartelists. IQR rule: participation count (higher $=$ more suspicious).",
    "Structural score: log-likelihood ratio of mean bid spread under Regime~2",
    "cover-bid distribution ($\\hat{\\epsilon} = 0.83$, $\\hat{\\sigma}_c = 1.19$)",
    "vs.\\ genuine-loser spread distribution.",
    "Random Forest: 500 trees trained on 7 firm-level features (participations,",
    "mean/SD/median spread, \\% above winner, bid CV).",
    "DeLong $p$-value: null that AUC difference from IQR rule equals zero.",
    "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")
  writeLines(tex, file.path(OUT_T, "tab_classification_comparison.tex"))
  cat("  Table saved.\n")

  # Save CSV
  write.csv(data.frame(
    classifier = c("IQR","Structural","RF","Combined","Random"),
    auc = round(c(auc(roc_iqr), auc(roc_struct), auc(roc_ml), auc(roc_combined), 0.5), 4)
  ), file.path(OUT_T, "classification_comparison.csv"), row.names=FALSE)
}

cat("\n=== DONE ===\n")
