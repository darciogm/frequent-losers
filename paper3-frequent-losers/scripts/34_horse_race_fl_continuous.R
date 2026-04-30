# ============================================================================
# 34_horse_race_fl_continuous.R — formal horse race FL vs continuous
# Paper 3 v14: mr-frequent's prioritized test #2
#
# Mr-frequent's Q1: FL is potentially just discretization of continuous
# tenders_count. Script 22 already showed in a price regression that
# FL coefficient flips negative when continuous is added. This script
# extends to:
#   1. Multiple continuous representations: tenders_count, log(1+tc),
#      win_rate, log(1+win_rate), tc × always_loser interaction
#   2. Multiple cutoff rules: median+0.5×IQR, +1×, +1.5× (baseline),
#      +2×, fixed cutoffs at 5/10/14/20/50
#   3. AUC predicting CADE cobidders for each spec
#   4. Price regression with each alternative as treatment
#
# If discretization is well-justified, the binary FL (cutoff = 14) should
# either: (a) outperform continuous in AUC (suggesting threshold
# nonlinearity), OR (b) match continuous in AUC AND have substantive
# operational/interpretive advantages (single binary trigger).
#
# If FL is dominated by continuous in BOTH AUC and price regression, the
# discretization is not justified and the v13 framing collapses.
#
# Output:
#   output/horse_race/horse_race_summary.csv
#   output/horse_race/fig_horse_race.pdf
# ============================================================================

cat("=== 34_horse_race_fl_continuous.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(pROC); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "horse_race")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data -----------------------------------------------------------
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fls[, firm_code := as.character(`códigofornecedor`)]
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

dt <- readRDS("/tmp/p3_prepared.rds")
dt[, oc_item_key := paste0(oc_code, "_", item_code)]

# Build firm-level feature panel
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al <- merge(al, fls[, .(firm_code, total_participations, total_wins, win_rate)],
            by = "firm_code", all.x = TRUE)
al[is.na(total_participations), total_participations := 0L]
al[is.na(total_wins), total_wins := 0L]
al[is.na(win_rate), win_rate := 0]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]

# Continuous + binary feature variants
al[, log_tc       := log1p(tenders_count)]
al[, sqrt_tc      := sqrt(tenders_count)]
# Multiple FL cutoff variants
al[, fl_cut5      := as.integer(tenders_count > 5L)]
al[, fl_cut10     := as.integer(tenders_count > 10L)]
al[, fl_cut14     := as.integer(tenders_count > 14L)]   # v13 baseline
al[, fl_cut20     := as.integer(tenders_count > 20L)]
al[, fl_cut50     := as.integer(tenders_count > 50L)]

cat(sprintf("  Always-loser pool: %s\n", format(nrow(al), big.mark=",")))
cat(sprintf("  CADE cobidders:    %s\n", format(sum(al$is_cade), big.mark=",")))

# ---- Part A: AUC across feature variants --------------------------------
cat("\n--- Part A: AUC against CADE cobidders (always-loser pool) ---\n")
auc_for <- function(score, name) {
  if (length(unique(score)) < 2) return(NULL)
  r <- pROC::roc(al$is_cade, score, quiet = TRUE)
  data.table(score = name,
             auc = as.numeric(pROC::auc(r)),
             ci_lo = as.numeric(pROC::ci(r)[1]),
             ci_hi = as.numeric(pROC::ci(r)[3]))
}

scores_to_test <- list(
  list(s = al$tenders_count, n = "tenders_count_raw"),
  list(s = al$log_tc,        n = "log(1 + tenders_count)"),
  list(s = al$sqrt_tc,       n = "sqrt(tenders_count)"),
  list(s = al$fl_cut5,       n = "FL cutoff = 5"),
  list(s = al$fl_cut10,      n = "FL cutoff = 10"),
  list(s = al$fl_cut14,      n = "FL cutoff = 14 (v13)"),
  list(s = al$fl_cut20,      n = "FL cutoff = 20"),
  list(s = al$fl_cut50,      n = "FL cutoff = 50")
)
auc_results <- rbindlist(lapply(scores_to_test, function(x) auc_for(x$s, x$n)),
                          fill = TRUE)
print(auc_results)

# DeLong tests: FL cutoff 14 vs each continuous
cat("\n  DeLong tests vs FL cutoff 14:\n")
roc_fl14 <- pROC::roc(al$is_cade, al$fl_cut14, quiet = TRUE)
delong_results <- list()
for (sc in scores_to_test) {
  if (sc$n == "FL cutoff = 14 (v13)") next
  if (length(unique(sc$s)) < 2) next
  roc_alt <- pROC::roc(al$is_cade, sc$s, quiet = TRUE)
  d <- pROC::roc.test(roc_fl14, roc_alt, method = "delong")
  cat(sprintf("    FL14 vs %-30s  Z=%.2f, p=%.4g  (FL14 AUC=%.3f, alt AUC=%.3f)\n",
              sc$n, d$statistic, d$p.value,
              as.numeric(pROC::auc(roc_fl14)),
              as.numeric(pROC::auc(roc_alt))))
  delong_results[[length(delong_results) + 1]] <- data.table(
    alt = sc$n, z = as.numeric(d$statistic), p = d$p.value,
    fl14_auc = as.numeric(pROC::auc(roc_fl14)),
    alt_auc = as.numeric(pROC::auc(roc_alt))
  )
}
delong_dt <- rbindlist(delong_results, fill = TRUE)
fwrite(delong_dt, file.path(OUT, "delong_tests.csv"))

# ---- Part B: price regression — horse race ------------------------------
cat("\n\n--- Part B: price regression — FL variants vs continuous ---\n")
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm <- merge(ftm,
             al[, .(firm_code, tenders_count, log_tc, sqrt_tc,
                    fl_cut5, fl_cut10, fl_cut14, fl_cut20, fl_cut50)],
             by = "firm_code", all.x = TRUE)
for (col in c("tenders_count", "log_tc", "sqrt_tc",
              "fl_cut5", "fl_cut10", "fl_cut14", "fl_cut20", "fl_cut50")) {
  ftm[is.na(get(col)), (col) := 0]
}

# Tender-item level: aggregate over loser-side participants
intensity <- ftm[won == 0L, .(
  fl5_any  = max(fl_cut5),
  fl10_any = max(fl_cut10),
  fl14_any = max(fl_cut14),
  fl20_any = max(fl_cut20),
  fl50_any = max(fl_cut50),
  tc_max   = max(tenders_count),
  tc_sum   = sum(tenders_count),
  log_tc_max = max(log_tc),
  log_tc_sum = sum(log_tc)
), by = oc_item_key]

dt2 <- merge(dt, intensity, by = "oc_item_key", all.x = TRUE)
for (col in names(intensity)[-1]) dt2[is.na(get(col)), (col) := 0]
dt_p <- dt2[!is.na(lneg_price)]

run_price <- function(formula_str, label) {
  m <- tryCatch(
    feols(as.formula(formula_str), data = dt_p, cluster = ~item_f),
    error = function(e) NULL)
  if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  # Pick first non-FE coefficient
  rownames_ct <- rownames(ct)
  treatment <- rownames_ct[1]
  data.table(spec = label,
             treatment = treatment,
             coef = ct[treatment, "Estimate"],
             se   = ct[treatment, "Std. Error"],
             pval = ct[treatment, "Pr(>|t|)"],
             n    = m$nobs,
             r2   = fitstat(m, "r2", verbose = FALSE)$r2)
}

base_fe <- "| item_f + year_f + pbu_f"
specs <- list(
  list(f = paste("lneg_price ~ fl14_any + convite",   base_fe), n = "FL14 binary (v13 baseline)"),
  list(f = paste("lneg_price ~ fl5_any + convite",    base_fe), n = "FL5 binary"),
  list(f = paste("lneg_price ~ fl10_any + convite",   base_fe), n = "FL10 binary"),
  list(f = paste("lneg_price ~ fl20_any + convite",   base_fe), n = "FL20 binary"),
  list(f = paste("lneg_price ~ fl50_any + convite",   base_fe), n = "FL50 binary"),
  list(f = paste("lneg_price ~ log_tc_max + convite", base_fe), n = "log(1+max tenders_count)"),
  list(f = paste("lneg_price ~ tc_max + convite",     base_fe), n = "max tenders_count (raw)"),
  list(f = paste("lneg_price ~ log_tc_sum + convite", base_fe), n = "log(1+sum tenders_count)"),
  list(f = paste("lneg_price ~ fl14_any + log_tc_max + convite", base_fe),
       n = "FL14 binary + log_tc_max")
)

price_results <- rbindlist(lapply(specs, function(s) run_price(s$f, s$n)),
                            fill = TRUE)
print(price_results)
fwrite(price_results, file.path(OUT, "horse_race_price.csv"))

# ---- Part C: monotonicity diagnostic -------------------------------------
cat("\n\n--- Part C: AUC across continuous tenders_count cutoff sweep ---\n")
sweep_dt <- data.table()
for (k in c(2, 3, 5, 7, 10, 14, 20, 30, 50, 75, 100)) {
  al[, score := as.integer(tenders_count > k)]
  if (length(unique(al$score)) < 2) next
  r <- pROC::roc(al$is_cade, al$score, quiet = TRUE)
  sweep_dt <- rbind(sweep_dt, data.table(
    cutoff = k, auc = as.numeric(pROC::auc(r)),
    n_above = sum(al$score == 1)
  ))
}
print(sweep_dt)
fwrite(sweep_dt, file.path(OUT, "auc_cutoff_sweep.csv"))

# ---- Save consolidated summary -------------------------------------------
fwrite(auc_results, file.path(OUT, "horse_race_summary.csv"))

# ---- Plot ----------------------------------------------------------------
plot_dt <- copy(auc_results)
plot_dt[, score_label := score]
plot_dt[, family := fcase(
  grepl("FL cutoff", score), "Binary cutoff",
  grepl("tenders_count|tc|log", score), "Continuous",
  default = "Other"
)]
plot_dt[, score_label := factor(score_label, levels = c(
  "FL cutoff = 5", "FL cutoff = 10", "FL cutoff = 14 (v13)",
  "FL cutoff = 20", "FL cutoff = 50",
  "tenders_count_raw", "log(1 + tenders_count)", "sqrt(tenders_count)"))]

p <- ggplot(plot_dt, aes(y = score_label, x = auc, color = family)) +
  geom_vline(xintercept = 0.5, linetype = "dotted", color = "gray60") +
  geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi), height = 0.15) +
  geom_point(size = 3) +
  geom_text(aes(label = sprintf("%.3f", auc)), vjust = -0.7, size = 3) +
  scale_color_manual(values = c("Binary cutoff" = "#d73027",
                                 "Continuous" = "#5b8aa6")) +
  scale_x_continuous(limits = c(0.4, 1.0), breaks = seq(0.4, 1, 0.1)) +
  labs(x = "AUC against CADE co-bidder labels",
       y = NULL,
       title = "Horse race: binary FL cutoffs vs continuous tenders_count",
       subtitle = "Does discretization at cutoff=14 add value over continuous score?",
       color = NULL) +
  theme_bw() + theme(legend.position = "bottom")

ggsave(file.path(OUT, "fig_horse_race.pdf"), p,
       width = 9, height = 5, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_horse_race.pdf")))
cat("\n  Done.\n")
