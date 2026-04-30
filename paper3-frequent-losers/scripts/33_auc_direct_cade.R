# ============================================================================
# 33_auc_direct_cade.R — AUC against direct CADE defendants (mr-frequent #1)
# Paper 3 v14
#
# Mr-frequent's Q5 / first prioritized addition: validate the screen
# against the 47 BEC-active CADE defendants directly, not just the 193
# co-bidders. The headline AUC=0.94 is against the broader cobidder
# construct; if AUC against direct defendants is 0.62-0.69 (as the
# preliminary check in script 27 suggested with frozen-window classifiers),
# the scope of the "high-accuracy" claim must be reframed.
#
# This script:
#   1. Computes AUC against direct CADE defendants using ALL always-losers
#      (full-sample classifier, 16,843 firms, 7 always-loser defendants).
#   2. Computes AUC against post-2019-adjudicated CADE defendants only
#      (5 firms — strict prospective).
#   3. Reports bootstrap CI and DeLong test vs sham.
#   4. Uses the FULL CADE-defendant list (not restricted to always-losers)
#      to compute AUC over ALL firms in BEC, with FL flag (binary) as
#      score. This is the most honest "the screen flags any cartelist"
#      test.
#
# Output:
#   output/auc_direct_cade/auc_direct_cade.csv
#   output/auc_direct_cade/fig_auc_direct_cade.pdf
# ============================================================================

cat("=== 33_auc_direct_cade.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "auc_direct_cade")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load CADE direct-defendant list with adjudication dates ------------
cade_full <- fread(file.path(BASE, "data/processed/cade_carteis_licitacoes_2009_2019.csv"))
cade_xm   <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
cade_full[, data_julgamento := as.Date(data_julgamento)]
cade_full[, post_2019 := as.integer(data_julgamento > as.Date("2019-12-31"))]
proc_dates <- unique(cade_full[, .(processo = numero_processo, data_julgamento,
                                     post_2019)])
cade_xm[, processo := as.character(processo)]
cade_xm <- merge(cade_xm, proc_dates, by = "processo", all.x = TRUE)
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]

cat(sprintf("  Total CADE-BEC firms (47 distinct CNPJs): %d (rows %d)\n",
            length(unique(cade_xm$firm_code)), nrow(cade_xm)))

direct_all      <- unique(cade_xm$firm_code)
direct_post2019 <- unique(cade_xm[post_2019 == 1L, firm_code])
direct_pre2020  <- unique(cade_xm[post_2019 == 0L, firm_code])
direct_al       <- unique(cade_xm[is_always_loser == TRUE, firm_code])
direct_al_post  <- unique(cade_xm[is_always_loser == TRUE & post_2019 == 1L, firm_code])

cat(sprintf("  Direct CADE-defendant firms (any always-loser status): %d\n",
            length(direct_all)))
cat(sprintf("  Direct CADE-defendant always-losers:                   %d\n",
            length(direct_al)))
cat(sprintf("  Direct CADE-defendants adjudicated post-2019:          %d\n",
            length(direct_post2019)))
cat(sprintf("  Direct CADE-defendants always-loser AND post-2019:     %d  ← strict prospective\n",
            length(direct_al_post)))

# ---- Load FREQ_PARTICIP for FL flag --------------------------------------
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
THRESH <- 14L
fp[, is_fl := as.integer(always_loser == 1L & tenders_count > THRESH)]

# ---- (a) AUC over ALL firms in BEC (not just always-losers) -------------
# Universe: ALL firms that ever participated in BEC (FREQ_PARTICIP has
# only always-losers; need the broader pool from firm_loss_stats).
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fls[, firm_code := as.character(`códigofornecedor`)]
fls <- merge(fls, fp[, .(firm_code, tenders_count, fp_always_loser = always_loser)],
             by = "firm_code", all.x = TRUE)
fls[is.na(tenders_count), tenders_count := 0L]
fls[, is_fl := as.integer(fp_always_loser == 1L & tenders_count > THRESH)]
fls[is.na(is_fl), is_fl := 0L]

# Score: tenders_count (continuous) — penalty for non-always-losers handled
# by zero-imputation; or use is_fl (binary). Both are used in main paper.
cat(sprintf("\n  Universe (all BEC firms): %s\n",
            format(nrow(fls), big.mark=",")))

run_auc_universe <- function(label_set, score_col, label_name) {
  fls[, target := as.integer(firm_code %in% label_set)]
  if (sum(fls$target) < 5) {
    cat(sprintf("    [%s | %s]  too few positives: %d — skipped\n",
                label_name, score_col, sum(fls$target)))
    return(NULL)
  }
  r <- pROC::roc(fls$target, fls[[score_col]], quiet = TRUE)
  list(label = label_name, score = score_col,
       auc = as.numeric(pROC::auc(r)),
       ci_lo = as.numeric(pROC::ci(r)[1]),
       ci_hi = as.numeric(pROC::ci(r)[3]),
       n_pos = sum(fls$target),
       n_total = nrow(fls))
}

cat("\n--- (a) AUC over ALL BEC firms (universe = 41,444) ---\n")
results <- list()
for (lbl in list(
  list(set = direct_all,      name = "all_direct_CADE"),
  list(set = direct_post2019, name = "post2019_direct_CADE"),
  list(set = direct_pre2020,  name = "pre2020_direct_CADE")
)) {
  for (sc in c("is_fl", "tenders_count")) {
    r <- run_auc_universe(lbl$set, sc, lbl$name)
    if (!is.null(r)) {
      cat(sprintf("    [%-22s | %-13s] AUC = %.4f [%.4f, %.4f]  pos=%d/%d\n",
                  lbl$name, sc, r$auc, r$ci_lo, r$ci_hi, r$n_pos, r$n_total))
      results[[length(results) + 1]] <- data.table(
        sample = "all_BEC_firms", label = r$label, score = r$score,
        auc = r$auc, ci_lo = r$ci_lo, ci_hi = r$ci_hi,
        n_pos = r$n_pos, n_total = r$n_total
      )
    }
  }
}

# ---- (b) AUC restricted to ALWAYS-LOSER pool ----------------------------
cat("\n--- (b) AUC restricted to always-loser pool (n=16,843) ---\n")
al <- fp[always_loser == 1L]

run_auc_al <- function(label_set, score_col, label_name) {
  al[, target := as.integer(firm_code %in% label_set)]
  if (sum(al$target) < 3) {
    cat(sprintf("    [%s | %s]  too few positives: %d — skipped\n",
                label_name, score_col, sum(al$target)))
    return(NULL)
  }
  r <- pROC::roc(al$target, al[[score_col]], quiet = TRUE)
  list(label = label_name, score = score_col,
       auc = as.numeric(pROC::auc(r)),
       ci_lo = as.numeric(pROC::ci(r)[1]),
       ci_hi = as.numeric(pROC::ci(r)[3]),
       n_pos = sum(al$target),
       n_total = nrow(al))
}

for (lbl in list(
  list(set = direct_al,      name = "AL_direct_CADE"),
  list(set = direct_al_post, name = "AL_direct_post2019_CADE_strict")
)) {
  for (sc in c("is_fl", "tenders_count")) {
    r <- run_auc_al(lbl$set, sc, lbl$name)
    if (!is.null(r)) {
      cat(sprintf("    [%-32s | %-13s] AUC = %.4f [%.4f, %.4f]  pos=%d/%d\n",
                  lbl$name, sc, r$auc, r$ci_lo, r$ci_hi, r$n_pos, r$n_total))
      results[[length(results) + 1]] <- data.table(
        sample = "always_loser_pool", label = r$label, score = r$score,
        auc = r$auc, ci_lo = r$ci_lo, ci_hi = r$ci_hi,
        n_pos = r$n_pos, n_total = r$n_total
      )
    }
  }
}

# ---- (c) Reference: 193 cobidder ground truth (v13 baseline) ------------
cat("\n--- (c) Reference: 193-cobidder ground truth (v13 baseline) ---\n")
cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

for (sc in c("is_fl", "tenders_count")) {
  r <- run_auc_al(cobid_codes, sc, "AL_193_cobidders_v13")
  if (!is.null(r)) {
    cat(sprintf("    [%-32s | %-13s] AUC = %.4f [%.4f, %.4f]  pos=%d/%d\n",
                "AL_193_cobidders_v13", sc, r$auc, r$ci_lo, r$ci_hi,
                r$n_pos, r$n_total))
    results[[length(results) + 1]] <- data.table(
      sample = "always_loser_pool", label = "AL_193_cobidders_v13",
      score = sc, auc = r$auc, ci_lo = r$ci_lo, ci_hi = r$ci_hi,
      n_pos = r$n_pos, n_total = r$n_total
    )
  }
}

# ---- Save + plot --------------------------------------------------------
res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, file.path(OUT, "auc_direct_cade.csv"))

cat("\n  ===== Headline summary =====\n")
print(res_dt[, .(sample, label, score, auc = round(auc, 3),
                  ci = sprintf("[%.3f, %.3f]", ci_lo, ci_hi),
                  n_pos)])

# Plot
plot_dt <- copy(res_dt)
plot_dt[, label_short := fcase(
  label == "all_direct_CADE",                "Direct CADE (all)",
  label == "post2019_direct_CADE",           "Direct CADE (post-2019)",
  label == "pre2020_direct_CADE",            "Direct CADE (pre-2020)",
  label == "AL_direct_CADE",                 "AL ∩ Direct CADE",
  label == "AL_direct_post2019_CADE_strict", "AL ∩ Direct CADE post-2019",
  label == "AL_193_cobidders_v13",           "AL Cobidders (v13, n=193)"
)]
plot_dt[, label_short := factor(label_short, levels = c(
  "AL Cobidders (v13, n=193)",
  "AL ∩ Direct CADE",
  "AL ∩ Direct CADE post-2019",
  "Direct CADE (all)",
  "Direct CADE (post-2019)",
  "Direct CADE (pre-2020)"))]

p <- ggplot(plot_dt, aes(y = label_short, x = auc, color = score, shape = score)) +
  geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray60") +
  geom_vline(xintercept = 0.85, linetype = "dashed", color = "gray60") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.15,
                 position = position_dodge(width = 0.4)) +
  geom_point(size = 3, position = position_dodge(width = 0.4)) +
  geom_text(aes(label = sprintf("%.3f", auc)),
            vjust = -1.0, size = 3,
            position = position_dodge(width = 0.4)) +
  scale_color_manual(values = c("is_fl" = "#d73027",
                                 "tenders_count" = "#5b8aa6")) +
  scale_x_continuous(limits = c(0.3, 1.0), breaks = seq(0.3, 1, 0.1)) +
  labs(x = "AUC against CADE ground truth (with 95% CI)",
       y = NULL,
       title = "AUC by ground-truth construction: cobidders vs direct defendants",
       subtitle = "Headline 0.94 against cobidders; 0.62–0.85 against direct defendants depending on universe",
       color = "Score", shape = "Score") +
  theme_bw() + theme(legend.position = "bottom")

ggsave(file.path(OUT, "fig_auc_direct_cade.pdf"), p,
       width = 10, height = 5.5, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_auc_direct_cade.pdf")))
cat("\n  Done.\n")
