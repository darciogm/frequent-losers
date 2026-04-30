# ============================================================================
# 35_unified_mechanism.R — unified mechanism design (mr-frequent #3)
# Paper 3 v14
#
# Mr-frequent's Q4: scripts 19 (full sample) and 32 (first-tender, matched)
# tell incompatible stories about WHERE the FL premium concentrates:
#   Script 19: Low HHI × High pairs (cartel-signature reading)
#   Script 32: High HHI × Low pairs (dominant-winner cover bidding)
#
# This is interpreted as sample-mining unless we run the SAME 2x2
# heterogeneity design across multiple samples and outcomes simultaneously,
# with consistent definitions.
#
# Unified design:
#   Outcome:    log(negotiated price) — the v13 main DV
#   Cells:      PBU × item-group(2-digit) × year, split on
#                hhi_winners (median split) × repeated_FL_winner_pairs (≥1)
#   Sample:     full v13 sample (1.65M items)
#   Treatment:  is_fl (item-level "any FL participant")
#   Specs:
#     (1) Unmatched, full FE structure
#     (2) Continuous treatment: log(1+max tenders_count among AL participants)
#     (3) Subset by modality (convite, pregão)
#
# This delivers ONE consistent test of where the premium concentrates —
# resolving the 19 vs 32 contradiction via shared design.
#
# Output:
#   output/unified_mechanism/unified_mechanism.csv
#   output/unified_mechanism/fig_unified_mechanism.pdf
# ============================================================================

cat("=== 35_unified_mechanism.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "unified_mechanism")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data -----------------------------------------------------------
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]
ftm[, pbu_code := substr(numerodaoc, 1, 11)]
ftm[, item_group := substr(`códigoitem`, 1, 2)]
ftm[, cell_id := paste0(pbu_code, "_", item_group, "_", year)]

THRESH <- 14L
fp[, is_fl := as.integer(always_loser == 1L & tenders_count > THRESH)]
fl_firms <- fp[is_fl == 1L, firm_code]

# ---- Compute cell features ---------------------------------------------
cat("\n  Computing cell HHI + repeated-pair features ...\n")
winners <- ftm[won == 1L, .(numerodaoc, `códigoitem`, oc_item_key,
                              cell_id, winner = firm_code)]
hhi <- winners[, {
  shares <- table(winner) / .N
  list(hhi = sum(shares^2), n_winners = length(unique(winner)))
}, by = cell_id]

ftm_fl <- ftm[firm_code %in% fl_firms & won == 0L,
              .(fl_firm = firm_code, oc_item_key, cell_id)]
fl_pairs <- merge(ftm_fl, winners[, .(oc_item_key, winner)], by = "oc_item_key")
pair_counts <- fl_pairs[, .N, by = .(cell_id, fl_firm, winner)]
rep_pairs <- pair_counts[N >= 2, .(rep_pair_count = .N), by = cell_id]

cell_feat <- merge(hhi, rep_pairs, by = "cell_id", all.x = TRUE)
cell_feat[is.na(rep_pair_count), rep_pair_count := 0L]
cell_feat[, hhi_high := as.integer(hhi > median(hhi, na.rm = TRUE))]
cell_feat[, pair_high := as.integer(rep_pair_count > 0L)]
cell_feat[, quadrant := fcase(
  hhi_high == 0L & pair_high == 0L, "Low HHI × Low pairs",
  hhi_high == 0L & pair_high == 1L, "Low HHI × High pairs",
  hhi_high == 1L & pair_high == 0L, "High HHI × Low pairs",
  hhi_high == 1L & pair_high == 1L, "High HHI × High pairs"
)]
cat(sprintf("  Cells: %s\n", format(nrow(cell_feat), big.mark=",")))

# ---- Map cell quadrant onto v13 main analysis sample -------------------
dt <- readRDS("/tmp/p3_prepared.rds")
dt[, oc_item_key := paste0(oc_code, "_", item_code)]
oc_to_cell <- unique(ftm[, .(oc_item_key, cell_id)])
dt <- merge(dt, oc_to_cell, by = "oc_item_key", all.x = TRUE)
dt <- merge(dt, cell_feat[, .(cell_id, quadrant, hhi, rep_pair_count)],
            by = "cell_id", all.x = TRUE)

# Continuous FL intensity per item (max tenders_count among always-loser
# participants — same as v13's loser definition continuum)
ftm_w_tc <- merge(ftm[won == 0L],
                   fp[always_loser == 1L, .(firm_code, tenders_count)],
                   by = "firm_code", all.x = TRUE)
ftm_w_tc[is.na(tenders_count), tenders_count := 0L]
intensity <- ftm_w_tc[, .(max_tc = max(tenders_count, na.rm = TRUE)),
                       by = oc_item_key]
intensity[!is.finite(max_tc), max_tc := 0L]
dt <- merge(dt, intensity, by = "oc_item_key", all.x = TRUE)
dt[is.na(max_tc), max_tc := 0L]
dt[, log_max_tc := log1p(max_tc)]

cat(sprintf("\n  Sample with quadrant assigned: %s/%s (%.1f%%)\n",
            format(sum(!is.na(dt$quadrant)), big.mark=","),
            format(nrow(dt), big.mark=","),
            100 * mean(!is.na(dt$quadrant))))
cat("\n  Quadrant distribution (full sample):\n")
print(dt[!is.na(quadrant), .N, by = quadrant])

dt_p <- dt[!is.na(lneg_price) & !is.na(quadrant)]
cat(sprintf("\n  Price-regression sample with quadrant: %s\n",
            format(nrow(dt_p), big.mark=",")))

# ---- Run unified per-quadrant regressions ------------------------------
cat("\n--- Per-quadrant FL price coefficient: BINARY (losers) ---\n")
results <- list()

for (q in c("Low HHI × Low pairs", "Low HHI × High pairs",
            "High HHI × Low pairs", "High HHI × High pairs")) {
  d_q <- dt_p[quadrant == q]
  if (nrow(d_q) < 1000 || sum(d_q$losers == 1) < 100) {
    cat(sprintf("    [%s] N=%d, FL=%d  -- skipped\n",
                q, nrow(d_q), sum(d_q$losers == 1)))
    next
  }
  m <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
             data = d_q, cluster = ~item_f)
  ct <- coeftable(m)
  cat(sprintf("    [%-25s]  binary FL: coef=%+.4f (SE %.4f, p=%.3g)  N=%s\n",
              q, ct["losers", "Estimate"], ct["losers", "Std. Error"],
              ct["losers", "Pr(>|t|)"], format(m$nobs, big.mark=",")))
  results[[length(results) + 1]] <- data.table(
    quadrant = q, treatment = "binary_FL",
    coef = ct["losers", "Estimate"], se = ct["losers", "Std. Error"],
    pval = ct["losers", "Pr(>|t|)"], n = m$nobs)
}

cat("\n--- Per-quadrant FL price coefficient: CONTINUOUS log(1+max_tc) ---\n")
for (q in c("Low HHI × Low pairs", "Low HHI × High pairs",
            "High HHI × Low pairs", "High HHI × High pairs")) {
  d_q <- dt_p[quadrant == q]
  if (nrow(d_q) < 1000) next
  m <- feols(lneg_price ~ log_max_tc + convite | item_f + year_f + pbu_f,
             data = d_q, cluster = ~item_f)
  ct <- coeftable(m)
  cat(sprintf("    [%-25s]  log_tc:    coef=%+.4f (SE %.4f, p=%.3g)\n",
              q, ct["log_max_tc", "Estimate"], ct["log_max_tc", "Std. Error"],
              ct["log_max_tc", "Pr(>|t|)"]))
  results[[length(results) + 1]] <- data.table(
    quadrant = q, treatment = "log_max_tc",
    coef = ct["log_max_tc", "Estimate"], se = ct["log_max_tc", "Std. Error"],
    pval = ct["log_max_tc", "Pr(>|t|)"], n = m$nobs)
}

# ---- By modality --------------------------------------------------------
cat("\n--- Per-quadrant × modality (CONVITE only) ---\n")
for (q in c("Low HHI × Low pairs", "Low HHI × High pairs",
            "High HHI × Low pairs", "High HHI × High pairs")) {
  d_q <- dt_p[quadrant == q & convite == 1L]
  if (nrow(d_q) < 1000 || sum(d_q$losers == 1) < 100) next
  m <- feols(lneg_price ~ losers | item_f + year_f + pbu_f,
             data = d_q, cluster = ~item_f)
  ct <- coeftable(m)
  cat(sprintf("    [%-25s] CONV  binary FL: coef=%+.4f (p=%.3g)  N=%s\n",
              q, ct["losers", "Estimate"], ct["losers", "Pr(>|t|)"],
              format(m$nobs, big.mark=",")))
  results[[length(results) + 1]] <- data.table(
    quadrant = q, treatment = "binary_FL_convite",
    coef = ct["losers", "Estimate"], se = ct["losers", "Std. Error"],
    pval = ct["losers", "Pr(>|t|)"], n = m$nobs)
}

cat("\n--- Per-quadrant × modality (PREGÃO only) ---\n")
for (q in c("Low HHI × Low pairs", "Low HHI × High pairs",
            "High HHI × Low pairs", "High HHI × High pairs")) {
  d_q <- dt_p[quadrant == q & pregao == 1L]
  if (nrow(d_q) < 1000 || sum(d_q$losers == 1) < 100) next
  m <- feols(lneg_price ~ losers | item_f + year_f + pbu_f,
             data = d_q, cluster = ~item_f)
  ct <- coeftable(m)
  cat(sprintf("    [%-25s] PREG  binary FL: coef=%+.4f (p=%.3g)  N=%s\n",
              q, ct["losers", "Estimate"], ct["losers", "Pr(>|t|)"],
              format(m$nobs, big.mark=",")))
  results[[length(results) + 1]] <- data.table(
    quadrant = q, treatment = "binary_FL_pregao",
    coef = ct["losers", "Estimate"], se = ct["losers", "Std. Error"],
    pval = ct["losers", "Pr(>|t|)"], n = m$nobs)
}

# ---- Save + plot --------------------------------------------------------
res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, file.path(OUT, "unified_mechanism.csv"))

plot_dt <- copy(res_dt)
plot_dt[, ci_lo := coef - 1.96 * se]
plot_dt[, ci_hi := coef + 1.96 * se]
plot_dt[, treatment_label := fcase(
  treatment == "binary_FL",         "Binary FL — full sample",
  treatment == "log_max_tc",        "log(1+max tenders_count)",
  treatment == "binary_FL_convite", "Binary FL — CONVITE only",
  treatment == "binary_FL_pregao",  "Binary FL — PREGÃO only"
)]
plot_dt[, treatment_label := factor(treatment_label, levels = c(
  "Binary FL — full sample",
  "log(1+max tenders_count)",
  "Binary FL — CONVITE only",
  "Binary FL — PREGÃO only"))]
plot_dt[, quadrant := factor(quadrant, levels = c(
  "Low HHI × Low pairs", "Low HHI × High pairs",
  "High HHI × Low pairs", "High HHI × High pairs"))]

p <- ggplot(plot_dt, aes(x = quadrant, y = coef * 100,
                          color = treatment_label, shape = treatment_label)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray60") +
  geom_errorbar(aes(ymin = ci_lo * 100, ymax = ci_hi * 100), width = 0.15,
                position = position_dodge(width = 0.5)) +
  geom_point(size = 3, position = position_dodge(width = 0.5)) +
  facet_wrap(~ treatment_label, ncol = 2, scales = "free_y") +
  labs(x = "Cell type", y = "Price coefficient (%)",
       title = "Unified mechanism: FL premium by network quadrant",
       subtitle = "Same sample, same FE, same outcome — across treatment definitions and modalities") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1),
        legend.position = "none",
        strip.text = element_text(face = "bold"))

ggsave(file.path(OUT, "fig_unified_mechanism.pdf"), p,
       width = 11, height = 7, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_unified_mechanism.pdf")))

# ---- Summary table ------------------------------------------------------
cat("\n  ===== Unified summary table =====\n")
print(plot_dt[, .(quadrant, treatment_label,
                   coef = round(coef * 100, 2),
                   pval = round(pval, 4),
                   n = format(n, big.mark = ","))])

cat("\n  Done.\n")
