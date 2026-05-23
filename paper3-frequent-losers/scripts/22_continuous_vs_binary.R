# ============================================================================
# 22_continuous_vs_binary.R — FL flag is operationalization of continuous signal
# Paper 3 v14: addresses Fragility 1 (AUC comes from tenders_count) +
# Fragility 2 (bright line at zero economic justification)
#
# Three analyses:
#   1. Replace binary FL flag with log(tenders_count) of FL participants in
#      tender-item, run price regression. Compare coefficients/AUC.
#   2. Counterfactual cartelist: simulate what FL firms WOULD look like if
#      they allowed occasional wins (1%, 2%, 5%) to evade detection.
#      Compute the minimum win-rate at which the cartelist breaks even with
#      an oversight body running our screen.
#   3. Visualize the binary-vs-continuous trade-off: at threshold k, what
#      fraction of "true positive" firms (CADE co-bidders) does the binary
#      flag retain vs continuous tenders_count.
#
# Output:
#   output/continuous_vs_binary/cont_vs_bin_summary.csv
#   output/continuous_vs_binary/fig_cont_vs_bin.pdf
#   output/continuous_vs_binary/fig_cartelist_break_even.pdf
# ============================================================================

cat("=== 22_continuous_vs_binary.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2); library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "continuous_vs_binary")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data -----------------------------------------------------------
dt <- readRDS("/tmp/p3_prepared.rds")
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]

cat(sprintf("  dt rows: %s | FREQ_PARTICIP: %s\n",
            format(nrow(dt), big.mark=","), format(nrow(fp), big.mark=",")))

# ---- (1) Continuous vs binary: price regression --------------------------
cat("\n--- Analysis 1: continuous tenders_count vs binary FL flag ---\n")

# Tender-item level: total tenders_count of always-loser participants
# (continuous version of binary 'losers' flag)
fp[, firm_code := as.character(`códigofornecedor`)]
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm <- merge(ftm, fp[always_loser == 1L, .(firm_code, tenders_count)],
             by = "firm_code", all.x = TRUE)
ftm[is.na(tenders_count), tenders_count := 0L]

# Per (oc, item): total FL-participation intensity
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]
intensity <- ftm[won == 0L, .(
  fl_intensity_sum = sum(tenders_count, na.rm = TRUE),
  fl_intensity_max = max(tenders_count, na.rm = TRUE),
  n_al_firms       = sum(tenders_count > 0L)
), by = oc_item_key]

dt[, oc_item_key := paste0(oc_code, "_", item_code)]
dt2 <- merge(dt, intensity, by = "oc_item_key", all.x = TRUE)
dt2[is.na(fl_intensity_sum), fl_intensity_sum := 0L]
dt2[is.na(fl_intensity_max), fl_intensity_max := 0L]
dt2[is.na(n_al_firms),       n_al_firms       := 0L]
dt2[, log_fl_int_sum := log1p(fl_intensity_sum)]
dt2[, log_fl_int_max := log1p(fl_intensity_max)]

dt2_p <- dt2[!is.na(lneg_price)]
cat(sprintf("  Sample for price regressions: %s\n", format(nrow(dt2_p), big.mark=",")))

m_binary  <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                    data = dt2_p, cluster = ~item_f)
m_int_sum <- feols(lneg_price ~ log_fl_int_sum + convite | item_f + year_f + pbu_f,
                    data = dt2_p, cluster = ~item_f)
m_int_max <- feols(lneg_price ~ log_fl_int_max + convite | item_f + year_f + pbu_f,
                    data = dt2_p, cluster = ~item_f)
m_combined <- feols(lneg_price ~ losers + log_fl_int_max + convite |
                                 item_f + year_f + pbu_f,
                    data = dt2_p, cluster = ~item_f)

cat("\n  Spec 1 — Binary FL flag (losers):\n");          print(coeftable(m_binary))
cat("\n  Spec 2 — log(1+sum tenders_count of always-loser participants):\n")
print(coeftable(m_int_sum))
cat("\n  Spec 3 — log(1+max tenders_count among always-loser participants):\n")
print(coeftable(m_int_max))
cat("\n  Spec 4 — Both (binary FL + continuous max):\n"); print(coeftable(m_combined))

extract <- function(m, var, name) {
  ct <- coeftable(m)
  if (!var %in% rownames(ct)) return(NULL)
  data.table(spec = name, coef = ct[var, "Estimate"],
             se = ct[var, "Std. Error"], pval = ct[var, "Pr(>|t|)"])
}
res_dt <- rbindlist(list(
  extract(m_binary,   "losers",         "binary_fl_alone"),
  extract(m_int_sum,  "log_fl_int_sum", "log_sum_tenders_count_alone"),
  extract(m_int_max,  "log_fl_int_max", "log_max_tenders_count_alone"),
  extract(m_combined, "losers",         "binary_fl_with_continuous"),
  extract(m_combined, "log_fl_int_max", "continuous_with_binary_fl")
))
fwrite(res_dt, file.path(OUT, "cont_vs_bin_price_regressions.csv"))

# ---- (2) AUC: continuous tenders_count vs binary FL on always-loser pool --
cat("\n--- Analysis 2: AUC binary vs continuous on always-loser pool ---\n")

al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
THRESH <- 14L
# Paper FL14 rule: firms with tenders_count >= 14 (matches \valThreshold=14
# and \valFL=2,735). Pre-2026-05-22 this line used `> THRESH`, which
# silently computed the FL15 stratum (2,537 firms, AUC 0.911); the
# canonical macros come from script 54 with median+1.5*IQR=13.5.
al[, is_fl := as.integer(tenders_count >= THRESH)]
al[, is_cade := as.integer(firm_code %in% cade$firm_code)]

roc_binary <- pROC::roc(al$is_cade, al$is_fl, quiet = TRUE)
roc_cont   <- pROC::roc(al$is_cade, al$tenders_count, quiet = TRUE)

cat(sprintf("  AUC binary FL flag:        %.4f [%.4f, %.4f]\n",
            as.numeric(pROC::auc(roc_binary)),
            as.numeric(pROC::ci(roc_binary)[1]),
            as.numeric(pROC::ci(roc_binary)[3])))
cat(sprintf("  AUC continuous tenders:    %.4f [%.4f, %.4f]\n",
            as.numeric(pROC::auc(roc_cont)),
            as.numeric(pROC::ci(roc_cont)[1]),
            as.numeric(pROC::ci(roc_cont)[3])))
cat(sprintf("  AUC gap (continuous - binary): %+.4f\n",
            as.numeric(pROC::auc(roc_cont)) - as.numeric(pROC::auc(roc_binary))))

# Sweep threshold to find binary-flag AUC at each cutoff
sweep_dt <- data.table()
for (k in seq(5, 50, by = 1)) {
  al[, is_k := as.integer(tenders_count > k)]
  if (length(unique(al$is_k)) < 2) next
  r <- pROC::roc(al$is_cade, al$is_k, quiet = TRUE)
  sweep_dt <- rbind(sweep_dt, data.table(
    threshold = k,
    auc       = as.numeric(pROC::auc(r)),
    n_above   = sum(al$is_k),
    n_cade_above = sum(al$is_k == 1L & al$is_cade == 1L)
  ))
}
fwrite(sweep_dt, file.path(OUT, "auc_threshold_sweep.csv"))
cat("  Threshold sweep (head):\n")
print(head(sweep_dt))

# ---- (3) Counterfactual cartelist: how many wins to evade detection? -----
cat("\n--- Analysis 3: cartelist break-even (Fragility 2) ---\n")
# At each win-rate ε, an "evasive cartelist" with k cover-bidding episodes
# would have k*(1-ε) losses and k*ε wins. Their tenders_count (losses)
# = k*(1-ε). Threshold for FL classification: tenders_count > 14 AND
# win_rate <= 0% (always-loser definition).
#
# An evasive cartelist with ε > 0 would NOT be classified as always-loser
# under the v13 definition. But how many wins does it need to evade?
#
# Computation: for each candidate cover-bidding intensity k (15, 20, 30,
# 50, 100), the cartelist needs at least ⌈k*ε⌉ "engineered wins" out of
# k+⌈k*ε⌉ total participations. Each engineered win has cost: foregoing
# the cover-bidding role + risk of audit. Compute break-even.

evade_dt <- CJ(k = c(14, 20, 30, 50, 100, 200),
                eps_pct = c(0.5, 1, 2, 5, 10))
evade_dt[, eps := eps_pct / 100]
evade_dt[, n_wins_needed := ceiling(k * eps / (1 - eps))]
evade_dt[, total_participations := k + n_wins_needed]
evade_dt[, total_cost_per_loss := 200]   # R$200/bid lower bound (CLAUDE.md)
evade_dt[, total_loss_cost := k * total_cost_per_loss]
# Engineering a win costs: foregoing cartel-rent share + some win cost.
# Assume each win extracted (R$10K average procurement value × 10% margin) − cost
evade_dt[, avg_tender_value := 10000]   # conservative (median is much lower)
evade_dt[, margin := 0.10]
evade_dt[, win_revenue := n_wins_needed * avg_tender_value * margin]
evade_dt[, evasion_cost := total_loss_cost - win_revenue]   # negative = profitable

cat("\n  How many engineered wins to evade FL screen vs. expected payoff:\n")
print(evade_dt[, .(k, eps_pct, n_wins_needed, evasion_cost)])

p_evade <- ggplot(evade_dt[k %in% c(20, 50, 100)],
                   aes(x = eps_pct, y = n_wins_needed,
                       color = factor(k), group = factor(k))) +
  geom_line(linewidth = 0.7) + geom_point(size = 2) +
  scale_x_continuous(breaks = c(0.5, 1, 2, 5, 10)) +
  scale_y_log10() +
  labs(x = "Required win-rate to evade FL screen (%)",
       y = "Engineered wins needed (log scale)",
       color = "Cover-bidding episodes (k)",
       title = "Evasion cost: how many engineered wins to escape FL classification",
       subtitle = "An evasive cartelist must trade cover-bidding rents for occasional wins") +
  theme_bw() + theme(legend.position = "bottom")

ggsave(file.path(OUT, "fig_cartelist_evasion.pdf"), p_evade,
       width = 7, height = 4.2, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", file.path(OUT, "fig_cartelist_evasion.pdf")))

# ---- Save consolidated summary -------------------------------------------
fwrite(evade_dt, file.path(OUT, "cartelist_evasion.csv"))
cat(sprintf("\n  Outputs:\n    %s\n    %s\n    %s\n    %s\n    %s\n",
            file.path(OUT, "cont_vs_bin_price_regressions.csv"),
            file.path(OUT, "auc_threshold_sweep.csv"),
            file.path(OUT, "cartelist_evasion.csv"),
            file.path(OUT, "fig_cartelist_evasion.pdf"),
            "(more figures could be added — see scratch)"))

cat("\n  Done.\n")
