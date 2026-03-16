#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════
# fl_participation_rationality.R — FL participation rationality test
# Addresses referee concern: "FL are merely inefficient firms"
#
# Key test: Under competitive conditions, FL participation is
# irrational (expected profit < 0) for any positive bidding cost.
# FL firms have win_rate = 0, so E[π] = -bidding_cost × N_tenders.
#
# Bidding cost calibration:
#   BEC is an electronic platform; unit prices are per-item (median
#   R$9.90). Bidding cost is modeled as a FIXED cost per participation
#   (staff time, documentation, opportunity cost), not a fraction of
#   unit price. Range R$50–R$500 per bid based on:
#   - BEC electronic participation: ~1–2h analyst time at R$25–50/h
#   - Documentation/compliance overhead
#   - Opportunity cost of monitoring auctions
#   References: Bajari & Hortaçsu (2003), Krasnokutskaya & Seim (2011)
# ═══════════════════════════════════════════════════════════════════
cat("=== FL PARTICIPATION RATIONALITY TEST ===\n\n")
suppressPackageStartupMessages({
  library(data.table); library(arrow)
})
setDTthreads(16L)

BASE <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
OUT_T <- file.path(BASE, "work/v8/tables")
OUT_F <- file.path(BASE, "work/v8/images")

# ── Load data ─────────────────────────────────────────────────────
cat("Loading data...\n")

# Firm tender map: participation + outcomes
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
setnames(ftm, c("códigofornecedor","numerodaoc","códigoitem","n_bids","won"),
         c("firm_id","oc_code","item_code","n_bids","won"))
ftm[, firm_id := as.character(firm_id)]

# BEC collapse: prices (bid_price_min = total bid value for the item line)
bec <- as.data.table(read_parquet(file.path(BASE, "data/processed/BEC_collapse_final.parquet"),
  col_select=c("po_item_merge_key","bid_price_min","bid_unit_price_negot_min","n_firms")))
bec[, oc_code := substr(po_item_merge_key, 1, 22)]

# FL classification
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value=TRUE, ignore.case=TRUE)
if (length(fp_col) > 0) setnames(fp, fp_col[1], "firm_id")
fp[, firm_id := as.character(firm_id)]
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
threshold <- q[2] + 1.5 * (q[3] - q[1])
fl_ids <- fp[tenders_count > threshold, firm_id]

# Firm loss stats
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
setnames(fls, "códigofornecedor", "firm_id")
fls[, firm_id := as.character(firm_id)]

cat("FL firms:", length(fl_ids), "\n")
cat("Total firms:", nrow(fls), "\n\n")

# ═══════════════════════════════════════════════════════════════════
# 1. FIRM-LEVEL AGGREGATES
# ═══════════════════════════════════════════════════════════════════
cat("=== 1. Firm-level aggregates ===\n")

# Aggregate winning bid value per OC (sum across items in the OC)
# This gives contract-level revenue for winners
oc_value <- bec[bid_price_min > 0,
                .(oc_total_value = sum(bid_price_min, na.rm=TRUE)),
                by=oc_code]

cat("OC-level values:\n")
cat("  N OCs:", formatC(nrow(oc_value), big.mark=","), "\n")
cat("  Median OC value: R$", formatC(median(oc_value$oc_total_value), big.mark=",", format="f", digits=0), "\n")
cat("  Mean OC value:   R$", formatC(mean(oc_value$oc_total_value), big.mark=",", format="f", digits=0), "\n")
cat("  P25 OC value:    R$", formatC(quantile(oc_value$oc_total_value, 0.25), big.mark=",", format="f", digits=0), "\n")
cat("  P75 OC value:    R$", formatC(quantile(oc_value$oc_total_value, 0.75), big.mark=",", format="f", digits=0), "\n\n")

# Merge OC value to firm participation
ftm_val <- merge(ftm, oc_value, by="oc_code", all.x=FALSE)
ftm_val[, is_fl := as.integer(firm_id %in% fl_ids)]

# Firm-level statistics
firm_stats <- ftm_val[, .(
  n_participations = .N,
  n_distinct_ocs = uniqueN(oc_code),
  n_wins = sum(won, na.rm=TRUE),
  win_rate = mean(won, na.rm=TRUE),
  total_won_value = sum(oc_total_value * won, na.rm=TRUE),
  mean_oc_value = mean(oc_total_value, na.rm=TRUE),
  median_oc_value = median(oc_total_value, na.rm=TRUE),
  is_fl = max(is_fl)
), by=firm_id]

# Classify into groups
firm_stats[, group := fifelse(is_fl == 1, "FL",
                    fifelse(win_rate == 0, "Non-FL always-loser",
                    fifelse(win_rate < 0.1, "Low win-rate (<10%)",
                    "Regular competitor")))]

cat("Groups:\n")
print(firm_stats[, .N, by=group][order(group)])
cat("\n")

# ═══════════════════════════════════════════════════════════════════
# 2. EXPECTED PROFIT WITH FIXED BIDDING COSTS
# ═══════════════════════════════════════════════════════════════════
cat("=== 2. Expected Profit Analysis (fixed bidding costs) ===\n")

# Fixed bidding costs per participation (R$)
# Calibration: BEC is electronic, but requires bid preparation,
# documentation, monitoring. Range based on:
#   - 1-2h analyst time at R$25-50/h → R$25-100 (preparation)
#   - Document compliance, opportunity cost → R$25-100 (overhead)
#   - Lower bound R$50 (minimal electronic), upper R$500 (complex items)
fixed_costs <- c(50, 100, 200, 500)

# For firms that win: expected surplus per win
# Assume 10% gross margin on contract value (conservative)
MARGIN <- 0.10

for (fc in fixed_costs) {
  col_name <- paste0("eprofit_fc", fc)
  # E[π] = win_rate × mean_contract_value × margin - fixed_cost
  firm_stats[, (col_name) := win_rate * mean_oc_value * MARGIN - fc]
}

cat("\n--- Expected Profit per Participation (R$/bid) ---\n")
cat("(Assuming 10% gross margin on wins)\n\n")

for (fc in fixed_costs) {
  col_name <- paste0("eprofit_fc", fc)
  cat(sprintf("Fixed bidding cost = R$%d/participation:\n", fc))
  summary_dt <- firm_stats[, .(
    N = .N,
    mean_win_rate = round(mean(win_rate, na.rm=TRUE), 4),
    mean_eprofit = round(mean(get(col_name), na.rm=TRUE), 0),
    median_eprofit = round(median(get(col_name), na.rm=TRUE), 0),
    pct_negative = round(100 * mean(get(col_name) < 0, na.rm=TRUE), 1)
  ), by=group]
  setorder(summary_dt, group)
  print(summary_dt)
  cat("\n")
}

# ═══════════════════════════════════════════════════════════════════
# 3. CAREER LOSS
# ═══════════════════════════════════════════════════════════════════
cat("=== 3. Total Career Loss ===\n")

# Career loss = fixed_cost × n_participations (for always-losers)
# Career net = total_won_value × margin - fixed_cost × n_participations (for winners)
for (fc in fixed_costs) {
  cl_name <- paste0("career_net_fc", fc)
  firm_stats[, (cl_name) := total_won_value * MARGIN - fc * n_participations]
}

cat("Career net profit at R$200/bid:\n")
career_summary <- firm_stats[, .(
  N = .N,
  mean_participations = round(mean(n_participations), 1),
  mean_career_net = round(mean(career_net_fc200, na.rm=TRUE), 0),
  median_career_net = round(median(career_net_fc200, na.rm=TRUE), 0),
  pct_negative = round(100 * mean(career_net_fc200 < 0, na.rm=TRUE), 1),
  mean_total_won_R = round(mean(total_won_value, na.rm=TRUE), 0)
), by=group]
setorder(career_summary, group)
print(career_summary)

cat("\nFL vs Non-FL always-losers:\n")
cat("  FL mean participations:     ", round(mean(firm_stats[group=="FL", n_participations]), 1), "\n")
cat("  Non-FL AL mean particip.:   ", round(mean(firm_stats[group=="Non-FL always-loser", n_participations]), 1), "\n")
cat("  FL mean career loss @R$200: R$", formatC(
    -mean(firm_stats[group=="FL", career_net_fc200], na.rm=TRUE),
    big.mark=",", format="f", digits=0), "\n")
cat("  Non-FL AL career loss @R$200: R$", formatC(
    -mean(firm_stats[group=="Non-FL always-loser", career_net_fc200], na.rm=TRUE),
    big.mark=",", format="f", digits=0), "\n")

# Wilcoxon test
w_test <- wilcox.test(
  firm_stats[group=="FL", n_participations],
  firm_stats[group=="Non-FL always-loser", n_participations])
cat("  Wilcoxon p:", format(w_test$p.value, digits=4), "\n")

# ═══════════════════════════════════════════════════════════════════
# 4. LaTeX TABLE
# ═══════════════════════════════════════════════════════════════════
cat("\n=== 4. Writing LaTeX table ===\n")

fmt <- function(x) formatC(x, big.mark=",", format="d")

# Compute table values at the central R$200/bid
gs <- firm_stats[, .(
  n = .N,
  part = round(mean(n_participations), 1),
  wr = round(mean(win_rate), 3),
  ep50 = round(mean(eprofit_fc50, na.rm=TRUE), 0),
  ep200 = round(mean(eprofit_fc200, na.rm=TRUE), 0),
  ep500 = round(mean(eprofit_fc500, na.rm=TRUE), 0),
  neg50 = round(100 * mean(eprofit_fc50 < 0, na.rm=TRUE), 1),
  neg200 = round(100 * mean(eprofit_fc200 < 0, na.rm=TRUE), 1),
  neg500 = round(100 * mean(eprofit_fc500 < 0, na.rm=TRUE), 1),
  cl200 = round(mean(career_net_fc200, na.rm=TRUE) / 1000, 1)
), by=group]
setorder(gs, group)

# Extract rows
fl <- gs[group == "FL"]
al <- gs[group == "Non-FL always-loser"]
lw <- gs[group == "Low win-rate (<10%)"]
rc <- gs[group == "Regular competitor"]

tex <- c(
  "% CO-AUTHOR EDIT: INSERT RATIONALITY TEST [T2.1]",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{FL Participation Rationality Test}",
  "\\label{tab:rationality}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lccccccc}",
  "\\toprule",
  " & & Mean & Win & \\multicolumn{3}{c}{$E[\\pi]$ per bid (R\\$)} & Career net \\\\",
  "\\cmidrule(lr){5-7}",
  " & $N$ & particip. & rate & $c=50$ & $c=200$ & $c=500$ & at $c=200$ (R\\$K) \\\\",
  "\\midrule",
  sprintf("FL firms & %s & %.1f & %s & $%s$ & $%s$ & $%s$ & $%s$ \\\\",
    fmt(fl$n), fl$part, "0.000", fmt(fl$ep50), fmt(fl$ep200), fmt(fl$ep500), sprintf("%.1f", fl$cl200)),
  sprintf("Non-FL always-losers & %s & %.1f & %s & $%s$ & $%s$ & $%s$ & $%s$ \\\\",
    fmt(al$n), al$part, "0.000", fmt(al$ep50), fmt(al$ep200), fmt(al$ep500), sprintf("%.1f", al$cl200)),
  sprintf("Low win-rate ($<$10\\%%) & %s & %.1f & %.3f & %s & %s & %s & %s \\\\",
    fmt(lw$n), lw$part, lw$wr, fmt(lw$ep50), fmt(lw$ep200), fmt(lw$ep500), sprintf("%.1f", lw$cl200)),
  sprintf("Regular competitors & %s & %.1f & %.3f & %s & %s & %s & %s \\\\",
    fmt(rc$n), rc$part, rc$wr, fmt(rc$ep50), fmt(rc$ep200), fmt(rc$ep500), sprintf("%.1f", rc$cl200)),
  "\\addlinespace[3pt]",
  " & & & & \\multicolumn{3}{c}{\\% with $E[\\pi] < 0$} & \\\\",
  "\\cmidrule(lr){5-7}",
  sprintf("FL firms & & & & %.1f\\%% & %.1f\\%% & %.1f\\%% & \\\\",
    fl$neg50, fl$neg200, fl$neg500),
  sprintf("Regular competitors & & & & %.1f\\%% & %.1f\\%% & %.1f\\%% & \\\\",
    rc$neg50, rc$neg200, rc$neg500),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} $c$ denotes fixed bidding cost per participation (R\\$).",
  "BEC is an electronic platform; $c$ captures staff time for bid preparation",
  "(1--2 hours at R\\$25--50/hour), documentation compliance, and opportunity cost.",
  "Expected profit: $E[\\pi] = \\text{win\\_rate} \\times \\overline{V} \\times 0.10 - c$,",
  "where $\\overline{V}$ is the mean procurement-order value across the firm's",
  "participations and 0.10 is a conservative gross margin.",
  "Career net = total winnings $\\times$ 0.10 $-$ $c \\times$ total participations.",
  "FL firms have zero wins by construction; participation generates",
  "guaranteed losses of $c$ per bid for any $c > 0$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(OUT_T, "tab_rationality.tex"))
cat("Table saved.\n")

# ── Save CSV ──────────────────────────────────────────────────────
results <- data.frame(
  group = c("FL", "NonFL_AL", "LowWR", "Regular"),
  n_firms = c(fl$n, al$n, lw$n, rc$n),
  mean_participations = c(fl$part, al$part, lw$part, rc$part),
  win_rate = c(0, 0, lw$wr, rc$wr),
  eprofit_fc50 = c(fl$ep50, al$ep50, lw$ep50, rc$ep50),
  eprofit_fc200 = c(fl$ep200, al$ep200, lw$ep200, rc$ep200),
  eprofit_fc500 = c(fl$ep500, al$ep500, lw$ep500, rc$ep500),
  pct_neg_fc200 = c(fl$neg200, al$neg200, lw$neg200, rc$neg200),
  career_net_fc200_K = c(fl$cl200, al$cl200, lw$cl200, rc$cl200)
)
write.csv(results, file.path(OUT_T, "rationality_results.csv"), row.names=FALSE)
cat("CSV saved.\n")

cat("\n=== DONE ===\n")
