# ============================================================================
# 27_strict_prospective_holdout.R — Strict prospective hold-out test (B1)
# Paper 3 v14
#
# v13 reports AUC=0.94 against ALL CADE defendants (12 cases, 8 of which
# adjudicated post-2019). Critique: pre-2020 cases could leak into
# training because they were already known when v13 wrote the screen.
#
# Strict prospective test:
#   1. Train FL classification using ONLY 2009-2015 BEC data (frozen
#      threshold at end of 2015).
#   2. Test ground truth: firms whose cartel adjudication occurred
#      AFTER 2019-12-31 (genuinely prospective — could not have leaked).
#   3. Compute AUC. If ≥ 0.85 → strong external-validity claim.
#
# We also do a "1.5 strict" version: train on 2009-2017, test against
# adjudications after 2019. And a "v13 reference" (full sample) for
# comparison.
#
# Outputs:
#   output/strict_prospective/strict_prospective_summary.csv
#   output/strict_prospective/fig_strict_prospective.pdf
# ============================================================================

cat("=== 27_strict_prospective_holdout.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "strict_prospective")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load FREQ_PARTICIP and FTM early (needed for cobidder construction) ---
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]

# ---- Load CADE data + adjudication dates ---------------------------------
cade_full <- fread(file.path(BASE, "data/processed/cade_carteis_licitacoes_2009_2019.csv"))
cade_xm   <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))

cade_full[, data_julgamento := as.Date(data_julgamento)]
cade_full[, post_2019 := as.integer(data_julgamento > as.Date("2019-12-31"))]

# Merge crossmatch with adjudication dates
cade_xm[, processo := as.character(processo)]
cade_full[, processo := as.character(numero_processo)]
proc_dates <- unique(cade_full[, .(processo, data_julgamento, post_2019)])
cade_xm <- merge(cade_xm, proc_dates, by = "processo", all.x = TRUE,
                  allow.cartesian = FALSE)
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]

cat(sprintf("  CADE crossmatch firms: %s\n", format(nrow(cade_xm), big.mark=",")))
cat("  Adjudication date distribution:\n")
print(cade_xm[, .N, by = .(post_2019, year(data_julgamento))][order(year)])

# Strict prospective firm set: post-2019 adjudicated + always-loser
strict_codes <- unique(cade_xm[post_2019 == 1L & is_always_loser == TRUE, firm_code])
all_codes    <- unique(cade_xm$firm_code)
cat(sprintf("\n  All CADE-defendant firm_codes (BEC-active): %d\n", length(all_codes)))
cat(sprintf("  Of which always-losers:                       %d\n",
            length(unique(cade_xm[is_always_loser == TRUE, firm_code]))))
cat(sprintf("  Of which always-loser + post-2019 adjud:      %d  ← STRICT\n",
            length(strict_codes)))

# ---- Use v13 cobidder file directly as ground truth ---------------------
# v13 AUC=0.94 uses cade_fl_cobidders.csv (193 firms). We re-use that set
# directly. For prospective restriction we recompute ONLY the post-2019
# subset by intersecting the 193 cobidders with FTM tenders involving
# post-2019 cartelists.
cat("\n  Loading v13 cobidder file (193 firms) and computing prospective subset ...\n")
cobid_v13 <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid_v13[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_all_al <- unique(cobid_v13$firm_code)

# Identify cobidders that shared ≥1 tender with a POST-2019-adjudicated
# CADE cartelist (using FTM)
ftm_for_cobid <- copy(ftm)
ftm_for_cobid[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]
cade_post2019_codes <- unique(cade_xm[post_2019 == 1L, firm_code])
cartel_items_post   <- ftm_for_cobid[firm_code %in% cade_post2019_codes,
                                       unique(oc_item_key)]
post_cobids <- ftm_for_cobid[oc_item_key %in% cartel_items_post,
                               unique(firm_code)]
cobid_post2019_al   <- intersect(cobid_all_al, post_cobids)

cat(sprintf("  Co-bidders (v13 file):          %d  (v13 baseline)\n",
            length(cobid_all_al)))
cat(sprintf("  Co-bidders (post-2019 subset):  %d  ← STRICT cobidders\n",
            length(cobid_post2019_al)))

# Also: cade_fl_cobidders defines the 193 always-losers that co-bid with
# CADE-firms. For strict prospective, we need to restrict this to firms
# that co-bid SPECIFICALLY with post-2019-adjudicated cartelists.
# This requires the bid-level join. We use a simpler proxy here: any
# always-loser that also appears in cade_xm with post_2019==1.
# TODO: more refined version recomputes co-bidding set from bid-level data.

# Recompute tenders_count using only data up to year_end
build_classifier <- function(year_end, label) {
  ftm_p <- ftm[year <= year_end]
  losses <- ftm_p[won == 0L, .N, by = firm_code]; setnames(losses, "N", "tcount")
  wins   <- ftm_p[won == 1L, .N, by = firm_code]; setnames(wins, "N", "wcount")
  firms <- merge(losses, wins, by = "firm_code", all = TRUE)
  firms[is.na(tcount), tcount := 0L]
  firms[is.na(wcount), wcount := 0L]
  firms[, win_rate := wcount / pmax(tcount + wcount, 1L)]
  firms[, always_loser := as.integer(win_rate == 0)]

  al <- firms[always_loser == 1L, tcount]
  thresh <- median(al) + 1.5 * IQR(al)
  firms[, is_fl := as.integer(always_loser == 1L & tcount > thresh)]
  cat(sprintf("  [%s] year≤%d: firms=%s, AL=%s, threshold=%g, FL=%s\n",
              label, year_end,
              format(nrow(firms), big.mark=","),
              format(sum(firms$always_loser), big.mark=","),
              round(thresh, 1),
              format(sum(firms$is_fl), big.mark=",")))
  firms
}

cat("\n  Building three classifiers (training-window cuts):\n")
clf_2015 <- build_classifier(2015L, "strict — 2009-2015 only")
clf_2017 <- build_classifier(2017L, "extended — 2009-2017")
clf_2019 <- build_classifier(2019L, "full     — 2009-2019")

# ---- AUC under three (classifier, ground-truth) combinations -------------
calc_auc <- function(d, label_col, score_col, name) {
  d2 <- copy(d)
  d2 <- d2[!is.na(get(score_col))]
  if (length(unique(d2[[label_col]])) < 2 || sum(d2[[label_col]]) < 5) {
    return(list(name = name, auc = NA_real_, ci_lo = NA_real_,
                ci_hi = NA_real_, n = nrow(d2), n_pos = sum(d2[[label_col]])))
  }
  r <- pROC::roc(d2[[label_col]], d2[[score_col]], quiet = TRUE)
  list(name = name,
       auc = as.numeric(pROC::auc(r)),
       ci_lo = as.numeric(pROC::ci(r)[1]),
       ci_hi = as.numeric(pROC::ci(r)[3]),
       n = nrow(d2), n_pos = sum(d2[[label_col]]))
}

# Four ground-truth definitions (cobidder-based mirrors v13 AUC=0.94)
ground_truths <- list(
  list(name = "cobid_all",      codes = cobid_all_al,
       desc = "Always-losers co-bidding with ANY CADE defendant (v13 def)"),
  list(name = "cobid_post2019", codes = cobid_post2019_al,
       desc = "Always-losers co-bidding with POST-2019 CADE (strict)"),
  list(name = "all_cade",       codes = all_codes,
       desc = "Direct CADE-defendant always-losers"),
  list(name = "post_2019",      codes = strict_codes,
       desc = "Direct CADE + adjudicated AFTER 2019 (strictest)")
)

classifiers <- list(
  list(name = "clf_2015",       df = clf_2015[always_loser == 1L]),
  list(name = "clf_2017",       df = clf_2017[always_loser == 1L]),
  list(name = "clf_2019_full",  df = clf_2019[always_loser == 1L])
)

results <- list()
for (clf in classifiers) {
  for (gt in ground_truths) {
    d <- copy(clf$df)
    d[, is_target := as.integer(firm_code %in% gt$codes)]
    a_fl  <- calc_auc(d, "is_target", "is_fl",  paste0(clf$name, "_", gt$name, "_FL"))
    a_tc  <- calc_auc(d, "is_target", "tcount", paste0(clf$name, "_", gt$name, "_tcount"))
    cat(sprintf("\n  [%s × %s]  N=%s, +=%s\n",
                clf$name, gt$name, format(a_fl$n, big.mark=","),
                format(a_fl$n_pos, big.mark=",")))
    cat(sprintf("    FL flag       AUC = %.4f [%.4f, %.4f]\n",
                a_fl$auc, a_fl$ci_lo, a_fl$ci_hi))
    cat(sprintf("    tenders_count AUC = %.4f [%.4f, %.4f]\n",
                a_tc$auc, a_tc$ci_lo, a_tc$ci_hi))
    results[[length(results) + 1]] <- data.table(
      classifier = clf$name, ground_truth = gt$name, score = "FL flag",
      auc = a_fl$auc, ci_lo = a_fl$ci_lo, ci_hi = a_fl$ci_hi,
      n = a_fl$n, n_pos = a_fl$n_pos
    )
    results[[length(results) + 1]] <- data.table(
      classifier = clf$name, ground_truth = gt$name, score = "tenders_count",
      auc = a_tc$auc, ci_lo = a_tc$ci_lo, ci_hi = a_tc$ci_hi,
      n = a_tc$n, n_pos = a_tc$n_pos
    )
  }
}

res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, file.path(OUT, "strict_prospective_summary.csv"))

# ---- Plot ---------------------------------------------------------------
plot_dt <- copy(res_dt)
plot_dt[, classifier_label := fcase(
  classifier == "clf_2015",      "Trained 2009–2015",
  classifier == "clf_2017",      "Trained 2009–2017",
  classifier == "clf_2019_full", "Trained 2009–2019 (v13)"
)]
plot_dt[, gt_label := fcase(
  ground_truth == "all_cade",  "All CADE defendants",
  ground_truth == "post_2019", "Strict prospective (post-2019)"
)]
plot_dt[, classifier_label := factor(classifier_label,
  levels = c("Trained 2009–2015", "Trained 2009–2017", "Trained 2009–2019 (v13)"))]
plot_dt[, gt_label := factor(gt_label,
  levels = c("All CADE defendants", "Strict prospective (post-2019)"))]

p <- ggplot(plot_dt, aes(x = classifier_label, y = auc,
                          color = score, group = score, shape = score)) +
  geom_hline(yintercept = 0.5, linetype = "dotted", color = "gray60") +
  geom_hline(yintercept = 0.85, linetype = "dashed", color = "gray60") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.12,
                position = position_dodge(width = 0.35)) +
  geom_line(position = position_dodge(width = 0.35), linewidth = 0.5,
            alpha = 0.5) +
  geom_point(position = position_dodge(width = 0.35), size = 3) +
  scale_color_manual(values = c("FL flag" = "#d73027",
                                 "tenders_count" = "#5b8aa6")) +
  scale_y_continuous(limits = c(0.45, 1.0), breaks = seq(0.5, 1, 0.1)) +
  facet_wrap(~ gt_label) +
  labs(x = NULL, y = "AUC against ground truth",
       title = "Strict prospective hold-out: AUC by training window × ground truth",
       subtitle = "Dashed line = 0.85 (strong-external-validity threshold)",
       color = "Score", shape = "Score") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1),
        legend.position = "bottom",
        strip.text = element_text(face = "bold"))

ggsave(file.path(OUT, "fig_strict_prospective.pdf"), p,
       width = 9, height = 5, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_strict_prospective.pdf")))

cat("\n  ===== Headline strict prospective results =====\n")
print(plot_dt[, .(classifier = classifier_label, ground_truth = gt_label,
                  score, auc = round(auc, 4),
                  ci = sprintf("[%.3f, %.3f]", ci_lo, ci_hi),
                  n_pos)])

cat("\n  Done.\n")
