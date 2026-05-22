# ============================================================================
# 61_selection_mechanism_test.R — Test 1 of the sign-reversal rationalization
#
# Hypothesis: cartels with cover bidders endogenously select into cells where
# the underlying (non-treated) price level is higher. This selection produces
# the naive positive coefficient (+6.4%) in the broad sample; once overlap
# discipline removes the across-cell variation, the within-cell mechanism
# (cover bidding depresses observed prices) flips the sign to negative (-9.7%).
#
# Test 1 isolates the SELECTION component:
# Compare mean log_neg_price across cells with high vs low FL share, looking
# ONLY at NON-treated items (items without FL presence). If high-FL-share
# cells have higher non-treated prices, cartels select into structurally
# higher-priced markets.
#
# Cell definition (same as scripts 51 and 59):
#   overlap_cell = interaction(item_group, year, convite, pbu_size_q,
#                              tender_value_q)
#
# Inputs:  /tmp/p3_prepared.rds (from 01_clean.R)
# Outputs: output/selection_mechanism/selection_test_results.csv
#          output/selection_mechanism/non_treated_price_by_fl_share.csv
# ============================================================================

cat("=== 61_selection_mechanism_test.R: Test 1 ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "",
                  commandArgs(trailingOnly = FALSE)[
                    grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "selection_mechanism")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
setDTthreads(12L)

cat("  Loading /tmp/p3_prepared.rds...\n")
dt <- as.data.table(readRDS("/tmp/p3_prepared.rds"))
dt <- dt[!is.na(lneg_price)]
cat("  Rows: ", format(nrow(dt), big.mark = ","), "\n", sep = "")

# Cell definition (matches script 59)
dt[, overlap_cell := interaction(item_group, year, convite, pbu_size_q,
                                  tender_value_q, drop = TRUE)]

# Cell-level FL-share + sizes
cell_stats <- dt[, .(
  n_items      = .N,
  n_treat      = sum(losers == 1L),
  n_ctrl       = sum(losers == 0L),
  fl_share     = mean(losers == 1L),
  mean_lp_all  = mean(lneg_price),
  mean_lp_ctrl = mean(lneg_price[losers == 0L]),
  mean_lp_treat= mean(lneg_price[losers == 1L])
), by = overlap_cell]

cell_stats[, cell_overlap := as.integer(n_treat > 0L & n_ctrl > 0L)]

cat("\n  Cell counts:\n")
cat("    Total cells:                 ", nrow(cell_stats), "\n")
cat("    Overlap cells (treat+ctrl):  ", sum(cell_stats$cell_overlap == 1L), "\n")
cat("    Items in overlap cells:      ",
    format(sum(cell_stats[cell_overlap == 1L]$n_items), big.mark=","), "\n", sep="")

# Restrict to overlap cells only
ov <- cell_stats[cell_overlap == 1L]

# Quintiles of FL share (cell-level)
qs <- quantile(ov$fl_share, probs = seq(0, 1, 0.20))
ov[, fl_share_q := cut(fl_share, breaks = unique(qs),
                        include.lowest = TRUE, ordered_result = TRUE,
                        labels = c("Q1 (lowest)", "Q2", "Q3", "Q4", "Q5 (highest)"))]

cat("\n  FL-share quintile cutoffs:", round(qs, 4), "\n")

# ─── Test 1a: Mean non-treated price by FL-share quintile ───────────────
# Aggregate at cell level (one observation per cell). Weight by N items.
test1a <- ov[, .(
  n_cells      = .N,
  total_items  = sum(n_items),
  total_ctrl_items = sum(n_ctrl),
  weighted_mean_ctrl_lp = sum(mean_lp_ctrl * n_ctrl) / sum(n_ctrl),
  mean_fl_share = mean(fl_share)
), by = fl_share_q]
setorder(test1a, fl_share_q)

cat("\n  Test 1a: Mean non-treated log_price by cell FL-share quintile\n")
print(test1a)

# ─── Test 1b: Item-level OLS regression ─────────────────────────────────
# Take all non-treated items, regress log_neg_price on cell fl_share
# (continuous), with cell-dimension fixed effects.
nt <- merge(dt[losers == 0L], ov[, .(overlap_cell, fl_share)], by = "overlap_cell")
cat("\n  Test 1b sample (non-treated in overlap cells): ",
    format(nrow(nt), big.mark = ","), " items\n", sep = "")

m1 <- feols(lneg_price ~ fl_share, data = nt, lean = TRUE)
m2 <- feols(lneg_price ~ fl_share | item_group + year, data = nt,
            cluster = ~overlap_cell, lean = TRUE)
m3 <- feols(lneg_price ~ fl_share | item_group + year + convite + pbu_size_q +
              tender_value_q, data = nt, cluster = ~overlap_cell, lean = TRUE)

results_1b <- data.table(
  spec      = c("raw", "item_group+year FE", "all 5 dim FE except identity"),
  coef      = c(coef(m1)[2], coef(m2)[1], coef(m3)[1]),
  se        = c(se(m1)[2], se(m2)[1], se(m3)[1]),
  n         = c(m1$nobs, m2$nobs, m3$nobs)
)
cat("\n  Test 1b: log_neg_price (non-treated only) ~ fl_share\n")
print(results_1b)

# ─── Test 1c: top vs bottom Q1/Q5 comparison ────────────────────────────
top_ctrl_lp <- with(test1a[fl_share_q == "Q5 (highest)"], weighted_mean_ctrl_lp)
bot_ctrl_lp <- with(test1a[fl_share_q == "Q1 (lowest)"], weighted_mean_ctrl_lp)
delta_q5_q1 <- top_ctrl_lp - bot_ctrl_lp

cat("\n  Test 1c: Q5 vs Q1 non-treated price\n")
cat("    Q1 mean log_price (lowest FL-share): ", round(bot_ctrl_lp, 4), "\n")
cat("    Q5 mean log_price (highest FL-share):", round(top_ctrl_lp, 4), "\n")
cat("    Δ (Q5 − Q1):                          ", round(delta_q5_q1, 4),
    "  (", round(100 * (exp(delta_q5_q1) - 1), 1), "% price difference)\n", sep="")

# ─── Save outputs ────────────────────────────────────────────────────────
fwrite(test1a, file.path(OUT, "non_treated_price_by_fl_share.csv"))
fwrite(results_1b, file.path(OUT, "selection_test_results.csv"))

# Headline verdict
verdict_passes <- (delta_q5_q1 > 0.05) & (coef(m3)[1] > 0) & (m3$nobs > 100000)

cat("\n  Verdict: ", ifelse(verdict_passes, "PASSES", "FAILS"),
    " (selection mechanism is real)\n", sep = "")
cat("  Required: Δ(Q5−Q1) > 0.05 AND fl_share coef in fully-FE-controlled spec > 0\n")
cat("  Observed: Δ = ", round(delta_q5_q1, 4),
    " ; coef (full FE) = ", round(coef(m3)[1], 4),
    " (SE ", round(se(m3)[1], 4), ")\n", sep = "")

cat("\n  Wrote ",
    file.path(OUT, "selection_test_results.csv"),
    " and ",
    file.path(OUT, "non_treated_price_by_fl_share.csv"),
    "\n", sep = "")
