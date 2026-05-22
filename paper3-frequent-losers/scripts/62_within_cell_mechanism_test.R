# ============================================================================
# 62_within_cell_mechanism_test.R — Test 2 of the sign-reversal rationalization
#
# Hypothesis: WITHIN cell, FL presence depresses the observed winner price
# relative to the reference price (cover-bidding theater makes the auction
# look competitive, pulls the winner toward the reference price). This is
# the second component of the rationalization that complements AN-039
# (selection mechanism) and explains the -0.097 overlap-cell ATT.
#
# Test 2a: within-cell mean of log(winner / reference), comparing FL-present
#          vs FL-absent items.
# Test 2b: M1 + M2 revalidation with explicit overlap-cell FE.
# Test 2c: heterogeneity — does the mechanism strengthen with more bidders?
#
# Inputs:  /tmp/p3_prepared.rds (from 01_clean.R)
# Outputs: output/mechanism_within_cell/mechanism_test_results.csv
#          output/mechanism_within_cell/m1_m2_revalidated.csv
# ============================================================================

cat("=== 62_within_cell_mechanism_test.R: Test 2 ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "",
                  commandArgs(trailingOnly = FALSE)[
                    grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(data.table); library(fixest)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "mechanism_within_cell")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
setDTthreads(12L)

cat("  Loading /tmp/p3_prepared.rds...\n")
dt <- as.data.table(readRDS("/tmp/p3_prepared.rds"))
dt <- dt[!is.na(lneg_price)]

# Compute log of reference price + winner-to-reference ratio
dt[, log_ref_price := log1p(pmax(bid_ref_price_min, 0))]
dt <- dt[is.finite(log_ref_price) & log_ref_price > 0]
dt[, winner_vs_ref := lneg_price - log_ref_price]  # log of (winner / ref)

# Cell definition (matches scripts 51, 59, 61)
dt[, overlap_cell := interaction(item_group, year, convite, pbu_size_q,
                                  tender_value_q, drop = TRUE)]
dt[, has_treat := as.integer(any(losers == 1L)), by = overlap_cell]
dt[, has_ctrl  := as.integer(any(losers == 0L)), by = overlap_cell]
dt[, cell_overlap := as.integer(has_treat == 1L & has_ctrl == 1L)]
ov <- dt[cell_overlap == 1L]

cat("\n  Overlap-cell sample: ", format(nrow(ov), big.mark = ","), " items\n", sep = "")
cat("  Treated (losers == 1): ", format(sum(ov$losers == 1L), big.mark = ","), "\n", sep = "")
cat("  Untreated (losers == 0): ", format(sum(ov$losers == 0L), big.mark = ","), "\n", sep = "")

# ─── Test 2a: within-cell winner-to-reference ratio by FL presence ──────────
cat("\n  Test 2a: within-cell winner-to-reference (log_winner − log_ref)\n")

m_ref_a <- feols(winner_vs_ref ~ losers | overlap_cell, data = ov,
                 cluster = ~overlap_cell, lean = TRUE)
m_ref_b <- feols(winner_vs_ref ~ losers + log(n_firms) | overlap_cell,
                 data = ov, cluster = ~overlap_cell, lean = TRUE)

res_2a <- data.table(
  spec = c("winner_vs_ref ~ losers | overlap_cell",
           "winner_vs_ref ~ losers + log(n_firms) | overlap_cell"),
  coef_losers = c(coef(m_ref_a)[1], coef(m_ref_b)[1]),
  se_losers   = c(se(m_ref_a)[1], se(m_ref_b)[1]),
  n = c(m_ref_a$nobs, m_ref_b$nobs)
)
print(res_2a)

# ─── Test 2b: M1 + M2 revalidation with cell FE ─────────────────────────────
cat("\n  Test 2b: M1 (n_bidders) and M2 (winner vs ref) within overlap cell\n")

# M1: how does n_firms (number of bidders) change in FL-present vs absent items?
ov[, log_n_firms := log(n_firms)]
m_M1 <- feols(log_n_firms ~ losers | overlap_cell, data = ov,
              cluster = ~overlap_cell, lean = TRUE)

# M2 revalidated: same as Test 2a; report alongside for completeness
m_M2 <- m_ref_a

res_2b <- data.table(
  mech = c("M1 (more bidders in FL tender)", "M2 (winner closer to reference)"),
  outcome = c("log(n_firms)", "log(winner) − log(reference)"),
  coef = c(coef(m_M1)[1], coef(m_M2)[1]),
  se = c(se(m_M1)[1], se(m_M2)[1]),
  n = c(m_M1$nobs, m_M2$nobs)
)
print(res_2b)

# ─── Test 2c: heterogeneity by n_bidders ────────────────────────────────────
cat("\n  Test 2c: does the mechanism strengthen with more bidders?\n")
ov[, nfirms_q := cut(n_firms, breaks = c(0, 3, 6, 10, Inf),
                      labels = c("1-3", "4-6", "7-10", "11+"),
                      include.lowest = TRUE)]
het_res <- ov[, .(
  n_items = .N,
  fl_share = mean(losers == 1L),
  mean_winner_vs_ref = mean(winner_vs_ref, na.rm = TRUE)
), by = .(nfirms_q, losers)]
het_res[, diff := mean_winner_vs_ref - mean_winner_vs_ref[losers == 0L],
        by = nfirms_q]
cat("  Bidder-count strata:\n")
print(het_res[order(nfirms_q, losers)])

# ─── Save outputs ───────────────────────────────────────────────────────────
fwrite(res_2a, file.path(OUT, "mechanism_test_results.csv"))
fwrite(res_2b, file.path(OUT, "m1_m2_revalidated.csv"))
fwrite(het_res, file.path(OUT, "mechanism_by_bidder_count.csv"))

# ─── Verdict ────────────────────────────────────────────────────────────────
verdict <- (coef(m_ref_a)[1] < -0.01) & (coef(m_M1)[1] > 0.05)
cat("\n  Verdict: ", ifelse(verdict, "PASSES", "FAILS"),
    " (mechanism is real)\n", sep = "")
cat("  Required: within-cell winner-vs-ref coef < -0.01 AND n_firms coef > 0.05\n")
cat("  Observed: winner-vs-ref = ", round(coef(m_ref_a)[1], 4),
    " (SE ", round(se(m_ref_a)[1], 4), ", p = ",
    format.pval(2 * pnorm(-abs(coef(m_ref_a)[1] / se(m_ref_a)[1])), digits = 3), ")\n", sep = "")
cat("            n_firms       = ", round(coef(m_M1)[1], 4),
    " (SE ", round(se(m_M1)[1], 4), ", p = ",
    format.pval(2 * pnorm(-abs(coef(m_M1)[1] / se(m_M1)[1])), digits = 3), ")\n", sep = "")
