#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════
# latent_class_validation.R — Latent Class validation of FL rule
# Addresses referee request T1.2: unsupervised 2-class model
# that discovers cover bidder vs genuine bidder classes,
# then checks overlap with FL classification.
#
# Uses flexmix (Gaussian mixture, k=2) on firm-level features
# of always-losers. If the latent "cover bidder" class aligns
# with FL classification, the IQR rule is structurally validated.
# ═══════════════════════════════════════════════════════════════════
cat("=== LATENT CLASS VALIDATION ===\n\n")
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(flexmix)
})
setDTthreads(16L)

BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT_T <- file.path(BASE, "work/v8/tables")

# ── 1. Load data and compute firm features ────────────────────────
cat("1. Loading data...\n")

# Bid-level data (v3 processed — verified consistent with main pipeline)
bl <- as.data.table(read_parquet(file.path(BASE, "v3/data/processed/bid_level_analysis.parquet"),
  col_select=c("firm_id","oc_code","item_code","bid_price","negot_price","won","is_fl")))

# Get winning price per tender
winners <- bl[won == 1L & !is.na(negot_price) & negot_price > 0,
              .(win_price = min(negot_price)), by=.(oc_code, item_code)]

# Losing bids with spread
losing <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
losing <- merge(losing, winners, by=c("oc_code","item_code"), all.x=FALSE)
losing[, log_spread := log(bid_price) - log(win_price)]

# FL classification from main pipeline
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value=TRUE, ignore.case=TRUE)
if (length(fp_col) > 0) setnames(fp, fp_col[1], "firm_id")
fp[, firm_id := as.character(firm_id)]
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_threshold <- q[2] + 1.5 * (q[3] - q[1])
fl_ids <- fp[tenders_count > iqr_threshold, firm_id]

# Win rates
win_rates <- bl[, .(win_rate = mean(won, na.rm=TRUE)), by=firm_id]

cat("  Losing bids:", formatC(nrow(losing), big.mark=","), "\n")

# ── 2. Compute firm-level features (referee-specified) ────────────
cat("\n2. Computing firm-level features...\n")

# Feature 1: mean_bid_distance (mean log-spread above winner)
# Feature 2: participation_rate (n_tenders, proxy for intensity)
# Feature 3: win_rate (0 for all always-losers, but included for completeness)
# Feature 4: cobidding_concentration (HHI of co-winners)

# Features from losing bids
firm_bid_features <- losing[, .(
  mean_bid_distance = mean(log_spread, na.rm=TRUE),
  sd_bid_distance = sd(log_spread, na.rm=TRUE),
  median_bid_distance = median(log_spread, na.rm=TRUE),
  pct_above_winner = mean(log_spread > 0, na.rm=TRUE),
  n_bids = .N,
  n_tenders = uniqueN(paste0(oc_code, item_code))
), by=firm_id]

# Co-bidding concentration (winner HHI)
# For each firm: who wins the tenders they participate in?
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
setnames(ftm, c("códigofornecedor","numerodaoc","códigoitem","n_bids","won"),
         c("firm_id","oc_code","item_code","n_bids_ftm","won"))
ftm[, firm_id := as.character(firm_id)]

winners_ftm <- ftm[won == 1, .(winner_id = firm_id[1]), by=.(oc_code, item_code)]

# For always-losers: compute winner HHI
al_tenders <- ftm[firm_id %in% fp$firm_id, .(firm_id, oc_code, item_code)]
al_tenders <- merge(al_tenders, winners_ftm, by=c("oc_code","item_code"), all.x=FALSE)

winner_hhi <- al_tenders[, {
  if (.N < 2) {
    .(cobidding_hhi = 1.0)
  } else {
    w <- table(winner_id)
    shares <- as.numeric(w) / sum(w)
    .(cobidding_hhi = sum(shares^2))
  }
}, by=firm_id]

rm(ftm, al_tenders); gc(verbose=FALSE)

# Merge all features
firm_features <- merge(firm_bid_features, winner_hhi, by="firm_id", all.x=TRUE)
firm_features <- merge(firm_features, win_rates, by="firm_id", all.x=TRUE)
firm_features <- merge(firm_features, fp[, .(firm_id, tenders_count)], by="firm_id", all.x=TRUE)

# Always-losers only (win_rate == 0)
always_losers <- firm_features[win_rate == 0 & !is.na(mean_bid_distance) &
                                is.finite(mean_bid_distance) & n_tenders >= 3]
always_losers[, is_fl := as.integer(firm_id %in% fl_ids)]

cat("  Always-losers with features (≥3 tenders):", nrow(always_losers), "\n")
cat("  FL among them:", sum(always_losers$is_fl), "\n")
cat("  Non-FL:", sum(!always_losers$is_fl), "\n\n")

# ── 3. Latent Class Analysis (Gaussian mixture, k=2) ─────────────
cat("3. Running LCA (flexmix, k=2)...\n")

# Standardize features for LCA
lca_vars <- c("mean_bid_distance", "sd_bid_distance", "pct_above_winner",
              "cobidding_hhi", "tenders_count")

lca_data <- always_losers[complete.cases(always_losers[, ..lca_vars])]
cat("  LCA sample:", nrow(lca_data), "\n")

# Standardize
for (v in lca_vars) {
  z_name <- paste0("z_", v)
  lca_data[, (z_name) := scale(get(v))]
}

z_vars <- paste0("z_", lca_vars)

# Fit 2-component Gaussian mixture via flexmix
set.seed(42)
lca_formula <- as.formula(paste("cbind(", paste(z_vars, collapse=","), ") ~ 1"))
fm <- stepFlexmix(lca_formula, data=lca_data, k=2, nrep=10,
                   model=FLXMCmvnorm(), verbose=FALSE)

cat("  Log-likelihood:", round(logLik(fm), 1), "\n")
cat("  BIC:", round(BIC(fm), 1), "\n")

# Posterior probabilities
post <- posterior(fm)
lca_data[, class := apply(post, 1, which.max)]
lca_data[, prob_class1 := post[, 1]]
lca_data[, prob_class2 := post[, 2]]

# Identify which class is the "cover bidder" class
# The cover bidder class should have: higher tenders_count, higher mean_bid_distance
class_means <- lca_data[, .(
  mean_tenders = mean(tenders_count, na.rm=TRUE),
  mean_bid_dist = mean(mean_bid_distance, na.rm=TRUE),
  mean_hhi = mean(cobidding_hhi, na.rm=TRUE),
  mean_pct_above = mean(pct_above_winner, na.rm=TRUE),
  n = .N,
  pct_fl = mean(is_fl)
), by=class]
cat("\nClass profiles:\n")
print(class_means)

# The class with higher tenders_count is the "cover bidder" class
cover_class <- class_means[which.max(mean_tenders), class]
genuine_class <- setdiff(1:2, cover_class)
cat("\nCover bidder class:", cover_class, "\n")
cat("Genuine bidder class:", genuine_class, "\n")

# Assign cover bidder probability
lca_data[, prob_cover := post[, cover_class]]

# ── 4. Overlap with FL classification ────────────────────────────
cat("\n4. Overlap analysis...\n")

# Binary LCA classification
lca_data[, lca_cover := as.integer(class == cover_class)]

# Confusion matrix: LCA vs FL
tp <- sum(lca_data$lca_cover == 1 & lca_data$is_fl == 1)
fp_val <- sum(lca_data$lca_cover == 1 & lca_data$is_fl == 0)
fn <- sum(lca_data$lca_cover == 0 & lca_data$is_fl == 1)
tn <- sum(lca_data$lca_cover == 0 & lca_data$is_fl == 0)

precision <- tp / (tp + fp_val)
recall <- tp / (tp + fn)
f1 <- 2 * precision * recall / (precision + recall)

cat("  Confusion matrix (LCA cover vs FL):\n")
cat(sprintf("    TP=%d, FP=%d, FN=%d, TN=%d\n", tp, fp_val, fn, tn))
cat(sprintf("    Precision: %.3f\n", precision))
cat(sprintf("    Recall:    %.3f\n", recall))
cat(sprintf("    F1:        %.3f\n", f1))

# Mean posterior probability of cover bidder class given FL status
mean_prob_fl <- mean(lca_data[is_fl == 1, prob_cover], na.rm=TRUE)
mean_prob_nonfl <- mean(lca_data[is_fl == 0, prob_cover], na.rm=TRUE)
cat(sprintf("\n  Mean Pr(cover | FL):     %.3f\n", mean_prob_fl))
cat(sprintf("  Mean Pr(cover | non-FL): %.3f\n", mean_prob_nonfl))

if (mean_prob_fl >= 0.75) {
  cat("  >>> VALIDATION CONFIRMED: Pr(cover | FL) >= 0.75 <<<\n")
} else {
  cat(sprintf("  >>> Pr(cover | FL) = %.3f < 0.75 threshold <<<\n", mean_prob_fl))
  cat("  Interpretation: LCA classes partially align with FL.\n")
  cat("  The IQR rule captures participation intensity which the\n")
  cat("  LCA may distribute across multiple features.\n")
}

# ── 5. LaTeX table ───────────────────────────────────────────────
cat("\n5. Writing LaTeX table...\n")

tex <- c(
  "% CO-AUTHOR EDIT: INSERT LATENT CLASS VALIDATION [T1.2]",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Latent Class Validation of FL Classification}",
  "\\label{tab:lca_validation}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Latent class 1 & Latent class 2 \\\\",
  sprintf(" & (%s) & (%s) \\\\",
    ifelse(cover_class == 1, "cover bidder", "genuine"),
    ifelse(cover_class == 2, "cover bidder", "genuine")),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{Panel A: Class profiles}} \\\\",
  "\\addlinespace[2pt]",
  sprintf("$N$ firms & %s & %s \\\\",
    formatC(class_means[class==1, n], big.mark=","),
    formatC(class_means[class==2, n], big.mark=",")),
  sprintf("Mean tenders & %.1f & %.1f \\\\",
    class_means[class==1, mean_tenders],
    class_means[class==2, mean_tenders]),
  sprintf("Mean bid distance & %.3f & %.3f \\\\",
    class_means[class==1, mean_bid_dist],
    class_means[class==2, mean_bid_dist]),
  sprintf("Mean winner HHI & %.3f & %.3f \\\\",
    class_means[class==1, mean_hhi],
    class_means[class==2, mean_hhi]),
  sprintf("Mean \\%% above winner & %.3f & %.3f \\\\",
    class_means[class==1, mean_pct_above],
    class_means[class==2, mean_pct_above]),
  sprintf("\\%% classified FL & %.1f\\%% & %.1f\\%% \\\\",
    100*class_means[class==1, pct_fl],
    100*class_means[class==2, pct_fl]),
  "\\addlinespace[6pt]",
  "\\multicolumn{3}{l}{\\textit{Panel B: Overlap with FL classification}} \\\\",
  "\\addlinespace[2pt]",
  sprintf("$\\Pr(\\text{cover} \\mid \\text{FL})$ & \\multicolumn{2}{c}{%.3f} \\\\", mean_prob_fl),
  sprintf("$\\Pr(\\text{cover} \\mid \\text{non-FL})$ & \\multicolumn{2}{c}{%.3f} \\\\", mean_prob_nonfl),
  sprintf("Precision (LCA vs.\\ FL) & \\multicolumn{2}{c}{%.3f} \\\\", precision),
  sprintf("Recall (LCA vs.\\ FL) & \\multicolumn{2}{c}{%.3f} \\\\", recall),
  sprintf("$F_1$ & \\multicolumn{2}{c}{%.3f} \\\\", f1),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Two-component Gaussian mixture model (flexmix) estimated on",
  sprintf("%s always-loser firms with $\\geq 3$ tenders and valid bid-level features.", formatC(nrow(lca_data), big.mark=",")),
  "Features: mean log bid distance from winner, SD of bid distance, fraction of bids",
  "above winner, winner HHI (co-bidding concentration), and participation count.",
  "The cover bidder class is identified as the component with higher mean participation.",
  "Precision and recall treat FL classification as the reference standard.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(OUT_T, "tab_lca_validation.tex"))
cat("Table saved.\n")

# Save CSV
write.csv(data.frame(
  metric = c("n_lca_sample", "cover_class", "n_cover", "n_genuine",
             "mean_prob_cover_fl", "mean_prob_cover_nonfl",
             "precision", "recall", "f1", "bic"),
  value = round(c(nrow(lca_data), cover_class,
    class_means[class==cover_class, n], class_means[class==genuine_class, n],
    mean_prob_fl, mean_prob_nonfl,
    precision, recall, f1, BIC(fm)), 4)
), file.path(OUT_T, "lca_validation_results.csv"), row.names=FALSE)
cat("CSV saved.\n")

cat("\n=== DONE ===\n")
