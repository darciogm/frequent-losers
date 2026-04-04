#!/usr/bin/env Rscript
# ==========================================================================
# imhof_comparison.R — FL vs Imhof screen comparison (v7)
# ==========================================================================
cat("=== IMHOF vs FL SCREEN COMPARISON ===\n\n")
suppressPackageStartupMessages({
  library(data.table); library(arrow); library(pROC); library(ggplot2)
})
setDTthreads(16L)
BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
cb <- c("#0072B2","#D55E00","#009E73","#CC79A7","#E69F00")

# ── 1. Load bid-level data ──────────────────────────────────────
cat("1. Loading bid-level data...\n")
bl <- as.data.table(read_parquet(file.path(BASE, "v3/data/processed/bid_level_analysis.parquet"),
  col_select=c("firm_id","oc_code","item_code","bid_price","won","is_fl")))
bl_valid <- bl[!is.na(bid_price) & bid_price > 0]
cat("  Valid bids:", formatC(nrow(bl_valid), big.mark=","), "\n")

# ── 2. Tender-level Imhof features ─────────────────────────────
cat("2. Computing tender-level bid statistics...\n")
tender_stats <- bl_valid[, {
  p <- bid_price; nn <- .N
  if (nn >= 3) {
    mn <- mean(p); sd_p <- sd(p)
    .(cv = sd_p/mn,
      kurtosis = if(nn>=4) (sum((p-mn)^4)/nn)/(sd_p^4)-3 else NA_real_,
      skewness = (sum((p-mn)^3)/nn)/(sd_p^3),
      spread = (max(p)-min(p))/mn,
      n_bids = nn)
  }
}, by=.(oc_code, item_code)]
cat("  Tenders with stats:", formatC(nrow(tender_stats), big.mark=","), "\n")

# ── 3. Firm-level scores ───────────────────────────────────────
cat("3. Computing firm-level Imhof scores...\n")
firm_tender <- unique(bl_valid[, .(firm_id, oc_code, item_code)],
                      by=c("firm_id","oc_code","item_code"))
firm_tender <- merge(firm_tender, tender_stats, by=c("oc_code","item_code"))
firm_scores <- firm_tender[, .(
  mean_cv = mean(cv, na.rm=TRUE),
  mean_kurtosis = mean(kurtosis, na.rm=TRUE),
  mean_skewness = mean(skewness, na.rm=TRUE),
  mean_spread = mean(spread, na.rm=TRUE),
  n_tenders = .N
), by=firm_id]
cat("  Firms with scores:", formatC(nrow(firm_scores), big.mark=","), "\n")
rm(bl, bl_valid, firm_tender, tender_stats); gc(verbose=FALSE)

# ── 4. Load ground truth ───────────────────────────────────────
cat("4. Loading CADE ground truth...\n")
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value=TRUE, ignore.case=TRUE)
if (length(fp_col) > 0) setnames(fp, fp_col[1], "firm_id")
fp[, firm_id := as.character(firm_id)]

cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade_col <- grep("fornecedor|firm|codigo", names(cade), value=TRUE, ignore.case=TRUE)
if (length(cade_col) > 0 && !"firm_id" %in% names(cade))
  setnames(cade, cade_col[1], "firm_id")
cade[, firm_id := as.character(trimws(firm_id))]
cade_ids <- unique(cade$firm_id)

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
threshold <- q[2] + 1.5 * (q[3] - q[1])
fp[, is_cade := as.integer(firm_id %in% cade_ids)]
fp[, is_fl := as.integer(tenders_count > threshold)]
cat("  Always-losers:", nrow(fp), "| CADE:", sum(fp$is_cade), "| FL:", sum(fp$is_fl), "\n")

# ── 5. Merge ───────────────────────────────────────────────────
firm_scores[, firm_id := as.character(firm_id)]
fp <- merge(fp, firm_scores, by="firm_id", all.x=TRUE)
fp_scored <- fp[!is.na(mean_cv)]
cat("  With Imhof scores:", nrow(fp_scored), "| CADE in scored:", sum(fp_scored$is_cade), "\n")

# ── 6. ROC curves ─────────────────────────────────────────────
cat("\n=== ROC CURVES ===\n")

roc_fl <- roc(fp_scored$is_cade, fp_scored$tenders_count, quiet=TRUE)
cat("  FL screen AUC:        ", round(auc(roc_fl), 4), "\n")

roc_cv <- roc(fp_scored$is_cade, -fp_scored$mean_cv, quiet=TRUE)
cat("  Imhof CV AUC:         ", round(auc(roc_cv), 4), "\n")

roc_spread <- roc(fp_scored$is_cade, -fp_scored$mean_spread, quiet=TRUE)
cat("  Imhof spread AUC:     ", round(auc(roc_spread), 4), "\n")

# Imhof composite
fp_scored[, z_cv := as.numeric(scale(-mean_cv))]
fp_scored[, z_kurt := as.numeric(scale(-mean_kurtosis))]
fp_scored[, z_spread := as.numeric(scale(-mean_spread))]
fp_scored[, z_skew := as.numeric(scale(mean_skewness))]
fp_scored[, imhof_score := rowMeans(cbind(z_cv, z_kurt, z_spread, z_skew), na.rm=TRUE)]
roc_imhof <- roc(fp_scored$is_cade, fp_scored$imhof_score, quiet=TRUE)
cat("  Imhof composite AUC:  ", round(auc(roc_imhof), 4), "\n")

# Combined (all 5 z-scores: FL + 4 Imhof components)
# NOTE: AUC ≈ 0.50 is expected, not a bug. Under Regime 2, FL firms
# raise within-tender dispersion, so Imhof features point in the
# opposite direction from FL participation — the signals cancel.
fp_scored[, z_fl := as.numeric(scale(tenders_count))]
fp_scored[, combined := rowMeans(cbind(z_fl, z_cv, z_kurt, z_spread, z_skew), na.rm=TRUE)]
roc_combined <- roc(fp_scored$is_cade, fp_scored$combined, quiet=TRUE)
cat("  Combined AUC:         ", round(auc(roc_combined), 4), "\n")

# DeLong tests
test1 <- roc.test(roc_fl, roc_imhof, method="delong")
test2 <- roc.test(roc_fl, roc_combined, method="delong")
cat(sprintf("\n  DeLong FL vs Imhof: Z=%.3f, p=%.4f\n", test1$statistic, test1$p.value))
cat(sprintf("  DeLong FL vs Combined: Z=%.3f, p=%.4f\n", test2$statistic, test2$p.value))

# ── 7. ROC figure ─────────────────────────────────────────────
cat("\n7. Generating ROC figure...\n")
get_roc_df <- function(r, lab) data.table(fpr=1-r$specificities, tpr=r$sensitivities, screen=lab)
roc_data <- rbind(
  get_roc_df(roc_fl, sprintf("FL screen (AUC = %.3f)", auc(roc_fl))),
  get_roc_df(roc_imhof, sprintf("Imhof composite (AUC = %.3f)", auc(roc_imhof))),
  get_roc_df(roc_combined, sprintf("Combined (AUC = %.3f)", auc(roc_combined)))
)
p <- ggplot(roc_data, aes(x=fpr, y=tpr, color=screen)) +
  geom_line(linewidth=1.1) +
  geom_abline(slope=1, intercept=0, linetype="dashed", color="gray50") +
  scale_color_manual(values=cb[1:3]) +
  labs(x="False Positive Rate", y="True Positive Rate", color=NULL) +
  theme_bw(base_size=12) +
  theme(legend.position=c(0.62, 0.22),
        legend.background=element_rect(fill="white", color="gray80"),
        panel.grid.minor=element_blank()) +
  coord_equal()
ggsave(file.path(BASE, "work/v7/images/fig_roc_comparison.pdf"), p,
       width=6, height=5.5, device=cairo_pdf)
cat("  Saved: fig_roc_comparison.pdf\n")

# ── 8. LaTeX table ────────────────────────────────────────────
cat("8. Writing LaTeX table...\n")
tex <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Detection Performance: FL Screen vs.\\ Imhof-Style Bid-Level Screens}",
  "\\label{tab:imhof_comparison}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}", "\\toprule",
  "Screen & AUC & Data required & DeLong $p$ \\\\", "\\midrule",
  sprintf("FL screen (this paper) & %.3f & Participation only & --- \\\\", auc(roc_fl)),
  sprintf("Imhof CV only & %.3f & Bid values & \\\\", auc(roc_cv)),
  sprintf("Imhof spread only & %.3f & Bid values & \\\\", auc(roc_spread)),
  sprintf("Imhof composite & %.3f & Bid values & %.4f \\\\", auc(roc_imhof), test1$p.value),
  sprintf("Combined (FL + Imhof) & %.3f & Both & %.4f \\\\", auc(roc_combined), test2$p.value),
  "Random classifier & 0.500 & None & --- \\\\", "\\bottomrule",
  "\\end{tabular}", "\\begin{tablenotes}", "\\small",
  sprintf("\\item \\textit{Notes:} AUC computed on %s always-loser firms", formatC(nrow(fp_scored), big.mark=",")),
  sprintf("(%d CADE co-bidders, %s non-CADE).", sum(fp_scored$is_cade), formatC(sum(!fp_scored$is_cade), big.mark=",")),
  "Ground truth: co-participation with CADE-convicted cartelists.",
  "FL screen score: tender participation count (higher $=$ more suspicious).",
  "Imhof composite: standardized mean of within-tender CV, excess kurtosis,",
  "skewness, and normalized bid spread across all tenders the firm participates in.",
  "DeLong $p$-value tests the null that the AUC difference from FL screen equals zero.",
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")
writeLines(tex, file.path(BASE, "work/v7/tables/tab_imhof_comparison.tex"))
cat("  Saved: tab_imhof_comparison.tex\n")

# ── 9. CSV ────────────────────────────────────────────────────
write.csv(data.frame(
  screen=c("FL","Imhof_CV","Imhof_spread","Imhof_composite","Combined","Random"),
  auc=c(auc(roc_fl), auc(roc_cv), auc(roc_spread), auc(roc_imhof), auc(roc_combined), 0.5),
  data=c("participation","bids","bids","bids","both","none")
), file.path(BASE, "work/v7/tables/imhof_comparison_results.csv"), row.names=FALSE)

cat("\n=== DONE ===\n")
