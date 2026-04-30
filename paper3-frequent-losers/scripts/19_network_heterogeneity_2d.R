# ============================================================================
# 19_network_heterogeneity_2d.R — 2D network heterogeneity (Tier 1.4)
# Paper 3 v14
#
# v13 already split FL effect by single-axis network position (low-HHI vs
# high-HHI markets, "competitive vs concentrated"). Refine to 2D:
#   x-axis: winner HHI per (PBU × item-group × year) cell — market concentration
#   y-axis: repeated FL-winner pair count per cell — coordinated bidding
#
# 2 × 2 = 4 cells (low/high splits at each axis median):
#   - Low HHI × Low pairs:   diversified, no repeat partners (clean competitive)
#   - Low HHI × High pairs:  diversified BUT repeated partners (cartel signature)
#   - High HHI × Low pairs:  concentrated single supplier (no FL space)
#   - High HHI × High pairs: concentrated + repeated (small market with cartel)
#
# Hypothesis: FL price effect concentrates in "Low HHI × High pairs" — the
# canonical cartel signature combining diverse cover with stable winner pacts.
#
# Output: 4-cell coefficient table + bar chart figure.
# ============================================================================

cat("=== 19_network_heterogeneity_2d.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "network_heterogeneity_2d")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

dt  <- readRDS("/tmp/p3_prepared.rds")
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))

cat(sprintf("  dt rows: %s | FTM rows: %s | FREQ_PARTICIP: %s\n",
            format(nrow(dt), big.mark=","),
            format(nrow(ftm), big.mark=","),
            format(nrow(fp), big.mark=",")))

THRESH <- 14L
fl_firms <- fp[always_loser == 1L & tenders_count > THRESH, `códigofornecedor`]
cat(sprintf("  FL firms (always-loser & tenders > %d): %s\n",
            THRESH, format(length(fl_firms), big.mark=",")))

# ---- Compute winner HHI per (pbu × item-group × year) ---------------------
# Winner per (oc, item) is firm with won=1 in FTM
winners <- ftm[won == 1L, .(winner = `códigofornecedor`),
               by = .(numerodaoc, `códigoitem`)]
winners[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]

# Map to (pbu × item-group × year) cell from dt
dt[, oc_item_key := paste0(oc_code, "_", item_code)]
dt[, cell_id := paste0(pbu_code, "_", item_group, "_", year)]
dt[, item_group_local := substr(item_code, 1, 4)]   # broader group

cell_winners <- merge(
  dt[, .(oc_item_key, cell_id)],
  winners[, .(oc_item_key, winner)],
  by = "oc_item_key", all.x = TRUE
)

# Compute HHI per cell
hhi <- cell_winners[!is.na(winner), {
  shares <- table(winner) / .N
  list(hhi = sum(shares^2), n_winners = length(unique(winner)))
}, by = cell_id]
cat(sprintf("  Cells with computed HHI: %s\n",
            format(nrow(hhi), big.mark=",")))

# ---- Compute repeated FL-winner pair count per cell -----------------------
# For each cell, count distinct (FL firm, winner) pairs across the cell's
# tender-items. "Repeated pairs" = pairs that appear ≥2 times.

# FL participations (loser side) joined with item winners
ftm_fl <- ftm[`códigofornecedor` %in% fl_firms & won == 0L,
              .(fl_firm = `códigofornecedor`, numerodaoc, `códigoitem`)]
ftm_fl[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]

fl_pairs <- merge(ftm_fl[, .(oc_item_key, fl_firm)],
                   winners[, .(oc_item_key, winner)],
                   by = "oc_item_key")
fl_pairs <- merge(fl_pairs, dt[, .(oc_item_key, cell_id)],
                   by = "oc_item_key")

# Count pair occurrences within each cell
pair_counts <- fl_pairs[, .N, by = .(cell_id, fl_firm, winner)]
repeated_pairs <- pair_counts[N >= 2, .(rep_pair_count = .N), by = cell_id]
cell_pairs <- merge(hhi, repeated_pairs, by = "cell_id", all.x = TRUE)
cell_pairs[is.na(rep_pair_count), rep_pair_count := 0L]
cat(sprintf("  Cells with FL-winner pair info: %s\n",
            format(nrow(cell_pairs), big.mark=",")))

# Quartile splits
cell_pairs[, hhi_high := as.integer(hhi > median(hhi, na.rm = TRUE))]
cell_pairs[, pair_high := as.integer(rep_pair_count > 0L)]
cell_pairs[, quad := fcase(
  hhi_high == 0L & pair_high == 0L, "Low HHI × Low pairs",
  hhi_high == 0L & pair_high == 1L, "Low HHI × High pairs",
  hhi_high == 1L & pair_high == 0L, "High HHI × Low pairs",
  hhi_high == 1L & pair_high == 1L, "High HHI × High pairs",
  default = NA_character_
)]
cat("\n  Cell distribution by quadrant:\n")
print(cell_pairs[, .N, by = quad])

# Merge quadrant onto dt
dt2 <- merge(dt, cell_pairs[, .(cell_id, quad, hhi, rep_pair_count)],
             by = "cell_id", all.x = TRUE)

# ---- Run FL coefficient per quadrant --------------------------------------
cat("\n  Running FL coefficient per quadrant ...\n")
results <- list()

for (q in c("Low HHI × Low pairs", "Low HHI × High pairs",
            "High HHI × Low pairs", "High HHI × High pairs")) {
  d_q <- dt2[quad == q & !is.na(lneg_price)]
  if (nrow(d_q) < 1000 || sum(d_q$losers == 1) < 50) {
    cat(sprintf("    [%s] N=%d, FL_n=%d  -- skipped\n",
                q, nrow(d_q), sum(d_q$losers == 1)))
    next
  }
  m <- tryCatch(
    feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
          data = d_q, cluster = ~item_f),
    error = function(e) { cat("    error:", conditionMessage(e), "\n"); NULL })

  if (!is.null(m)) {
    ct <- coeftable(m)
    results[[q]] <- data.table(
      quadrant = q,
      coef     = ct["losers", "Estimate"],
      se       = ct["losers", "Std. Error"],
      pval     = ct["losers", "Pr(>|t|)"],
      n        = m$nobs,
      n_fl_obs = sum(d_q$losers == 1)
    )
    cat(sprintf("    [%s]  coef=%+.4f (SE %.4f, p=%.3g)  N=%s\n",
                q, results[[q]]$coef, results[[q]]$se, results[[q]]$pval,
                format(m$nobs, big.mark=",")))
  }
}

# ---- Combined regression with quadrant interaction ------------------------
cat("\n  Combined regression (FL × quadrant interaction) ...\n")
dt2[, quad_f := factor(quad,
  levels = c("High HHI × Low pairs",      # reference
             "Low HHI × Low pairs",
             "High HHI × High pairs",
             "Low HHI × High pairs"))]
m_combined <- feols(lneg_price ~ losers + losers:quad_f + convite |
                      item_f + year_f + pbu_f,
                    data = dt2[!is.na(lneg_price) & !is.na(quad_f)],
                    cluster = ~item_f)
print(coeftable(m_combined))

# ---- Save + plot ---------------------------------------------------------
res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, file.path(OUT, "network_heterogeneity_2d.csv"))

if (nrow(res_dt) >= 2) {
  res_dt[, ci_lo := coef - 1.96 * se]
  res_dt[, ci_hi := coef + 1.96 * se]
  res_dt[, quadrant := factor(quadrant,
    levels = c("Low HHI × Low pairs", "Low HHI × High pairs",
               "High HHI × Low pairs", "High HHI × High pairs"))]
  p <- ggplot(res_dt, aes(x = quadrant, y = coef * 100)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbar(aes(ymin = ci_lo * 100, ymax = ci_hi * 100),
                  width = 0.15, color = "gray30") +
    geom_point(size = 3.5) +
    labs(x = "Cell type (winner HHI × repeated FL-winner pairs)",
         y = "FL price coefficient (%)",
         title = "FL price effect across network-structure quadrants",
         subtitle = "Cartel signature: Low HHI (diversified winners) × High pairs (repeated partners)") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 15, hjust = 1))
  ggsave(file.path(OUT, "fig_network_heterogeneity_2d.pdf"), p,
         width = 7, height = 4.5, device = cairo_pdf)
  cat(sprintf("  Saved: %s\n", file.path(OUT, "fig_network_heterogeneity_2d.pdf")))
}

cat("\n  Done.\n")
