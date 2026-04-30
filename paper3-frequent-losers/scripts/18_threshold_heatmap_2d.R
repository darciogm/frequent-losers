# ============================================================================
# 18_threshold_heatmap_2d.R — 2D threshold sensitivity heatmap (Tier 2.4)
# Paper 3 v14
#
# v13 already varies the IQR multiplier (0.5x–3.0x). Add a second axis:
# the win-rate cutoff (currently fixed at 0% = always-loser-only). Sweep:
#   IQR multiplier:    {0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0}
#   Win-rate cutoff:   {0%, 1%, 2%, 5%, 10%}
#
# For each (multiplier, cutoff) cell:
#   1. Re-classify FL: win_rate ≤ cutoff AND tenders_count > median + multiplier × IQR
#   2. Re-flag tender-items where ≥1 FL participant
#   3. Run feols(lneg_price ~ losers + convite | item + year + pbu, cluster=~item)
#   4. Record losers coefficient + p-value + N_FL
#
# Output: 8 × 5 = 40 cells, plotted as a heatmap with coefficient color
# and significance annotation. Visualizes that the price-gap result does not
# hinge on the exact (multiplier, cutoff) choice.
# ============================================================================

cat("=== 18_threshold_heatmap_2d.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "threshold_heatmap_2d")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load FTM (firm-tender map) for FL re-classification ------------------
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
cat(sprintf("  Loaded FTM (%s rows) and firm_loss_stats (%s firms)\n",
            format(nrow(ftm), big.mark=","),
            format(nrow(fls), big.mark=",")))

# ---- Load main analysis dataset (item × tender level) --------------------
dt <- readRDS("/tmp/p3_prepared.rds")
cat(sprintf("  Loaded analysis sample: %s rows\n", format(nrow(dt), big.mark=",")))

# ---- Compute always-loser tenders_count distribution ---------------------
fls[, tenders_count := total_participations - total_wins]
al_tcount <- fls[always_loser == 1L, tenders_count]
median_al <- median(al_tcount)
iqr_al    <- IQR(al_tcount)
cat(sprintf("  Always-loser tenders_count: median=%g, IQR=%g\n", median_al, iqr_al))

# ---- Sweep grid -----------------------------------------------------------
mult_grid   <- c(0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0)
cutoff_grid <- c(0.00, 0.01, 0.02, 0.05, 0.10)
grid <- CJ(multiplier = mult_grid, win_rate_cutoff = cutoff_grid)
cat(sprintf("  Grid: %d × %d = %d cells\n",
            length(mult_grid), length(cutoff_grid), nrow(grid)))

# ---- Per-cell evaluation --------------------------------------------------
# To re-flag tender-items, we re-derive the (numerodaoc, codigoitem) FL
# count from FTM filtered to the new FL firm set, then merge with dt.

ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]
dt[,  oc_item_key := paste0(oc_code,   "_", item_code)]

run_cell <- function(multiplier, win_rate_cutoff) {
  thresh <- median_al + multiplier * iqr_al

  # Identify FL firms under this (multiplier, cutoff)
  fl_firms <- fls[win_rate <= win_rate_cutoff & tenders_count > thresh,
                  `códigofornecedor`]

  # Tender-items with ≥1 FL participant (exclude winners — losers only)
  fl_items <- ftm[`códigofornecedor` %in% fl_firms & won == 0L,
                  unique(oc_item_key)]

  # Add new losers flag to dt
  dt[, losers_alt := as.integer(oc_item_key %in% fl_items)]

  d_p <- dt[!is.na(lneg_price)]
  m <- tryCatch(
    feols(lneg_price ~ losers_alt + convite | item_f + year_f + pbu_f,
          data = d_p, cluster = ~item_f),
    error = function(e) NULL)

  if (is.null(m)) return(list(coef=NA, se=NA, pval=NA, n_fl=length(fl_firms),
                              n_items=length(fl_items)))

  ct <- coeftable(m)
  list(
    coef  = ct["losers_alt", "Estimate"],
    se    = ct["losers_alt", "Std. Error"],
    pval  = ct["losers_alt", "Pr(>|t|)"],
    n_fl  = length(fl_firms),
    n_items = length(fl_items)
  )
}

cat("\n  Running 40 cells (each ~5-10s)...\n")
results <- vector("list", nrow(grid))
for (i in seq_len(nrow(grid))) {
  r <- run_cell(grid$multiplier[i], grid$win_rate_cutoff[i])
  results[[i]] <- r
  cat(sprintf("    [%2d/%d] mult=%.2f  cutoff=%.2f  coef=%+.4f (p=%.3g, N_FL=%d)\n",
              i, nrow(grid), grid$multiplier[i], grid$win_rate_cutoff[i],
              r$coef, r$pval, r$n_fl))
}

# ---- Assemble result table ------------------------------------------------
res_dt <- data.table(
  multiplier      = grid$multiplier,
  win_rate_cutoff = grid$win_rate_cutoff,
  coef            = sapply(results, function(x) x$coef),
  se              = sapply(results, function(x) x$se),
  pval            = sapply(results, function(x) x$pval),
  n_fl            = sapply(results, function(x) x$n_fl),
  n_items         = sapply(results, function(x) x$n_items)
)
res_dt[, sig := fcase(
  pval < 0.001, "***",
  pval < 0.01,  "**",
  pval < 0.05,  "*",
  pval < 0.10,  ".",
  default = ""
)]

fwrite(res_dt, file.path(OUT, "threshold_heatmap_2d.csv"))
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "threshold_heatmap_2d.csv")))

# ---- Plot heatmap ---------------------------------------------------------
res_dt[, coef_pct := coef * 100]   # display as percent
res_dt[, label    := sprintf("%.2f%s", coef_pct, sig)]
res_dt[, mult_f   := factor(multiplier, levels = mult_grid)]
res_dt[, cut_f    := factor(sprintf("%.0f%%", win_rate_cutoff * 100),
                             levels = sprintf("%.0f%%", cutoff_grid * 100))]

p <- ggplot(res_dt, aes(x = mult_f, y = cut_f, fill = coef_pct)) +
  geom_tile(color = "white") +
  geom_text(aes(label = label), size = 3) +
  scale_fill_gradient2(low = "#3b8dbd", mid = "white", high = "#d73027",
                       midpoint = 0,
                       name = "FL price\ncoefficient (%)") +
  labs(x = "IQR multiplier (FL threshold = median + k × IQR)",
       y = "Win-rate cutoff (FL = win_rate ≤ cutoff)",
       title = "FL price coefficient across (multiplier × win-rate) grid",
       subtitle = "Stable significance and direction = result not hinged on classification choice") +
  theme_bw() +
  theme(panel.grid = element_blank())

ggsave(file.path(OUT, "fig_threshold_heatmap_2d.pdf"), p,
       width = 8, height = 4.5, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", file.path(OUT, "fig_threshold_heatmap_2d.pdf")))

cat("\n  ===== Cell summary =====\n")
cat(sprintf("  Cells with positive coef: %d/%d\n",
            sum(res_dt$coef > 0, na.rm = TRUE), nrow(res_dt)))
cat(sprintf("  Cells with p<0.05:        %d/%d\n",
            sum(res_dt$pval < 0.05, na.rm = TRUE), nrow(res_dt)))
cat(sprintf("  Cells with p<0.10:        %d/%d\n",
            sum(res_dt$pval < 0.10, na.rm = TRUE), nrow(res_dt)))
cat(sprintf("  Coef range: [%.4f, %.4f]\n", min(res_dt$coef, na.rm=TRUE),
            max(res_dt$coef, na.rm=TRUE)))

cat("\n  Done.\n")
