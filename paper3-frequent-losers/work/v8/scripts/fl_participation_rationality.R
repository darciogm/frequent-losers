#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════════
# fl_participation_rationality.R — FL participation rationality test
# Addresses referee concern: "FL are merely inefficient firms"
#
# Key test: Under competitive conditions, FL participation is
# irrational (expected profit < 0) for any positive bidding cost.
# FL firms have win_rate = 0, so E[π] = -bidding_cost × N_tenders.
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

# BEC collapse: prices
bec <- as.data.table(read_parquet(file.path(BASE, "data/processed/BEC_collapse_final.parquet"),
  col_select=c("po_item_merge_key","bid_unit_price_negot_min","bid_ref_price_min","n_firms")))
bec[, oc_code := substr(po_item_merge_key, 1, 22)]
bec[, item_code := substr(po_item_merge_key, 23, nchar(po_item_merge_key))]

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
# 1. EXPECTED PROFIT COMPUTATION
# ═══════════════════════════════════════════════════════════════════
cat("=== 1. Expected Profit Analysis ===\n")

# Merge winning prices to participation data
win_prices <- bec[bid_unit_price_negot_min > 0,
                  .(win_price = bid_unit_price_negot_min[1]),
                  by=oc_code]

ftm_prices <- merge(ftm, win_prices, by="oc_code", all.x=FALSE)

# Classify firms
ftm_prices[, is_fl := as.integer(firm_id %in% fl_ids)]
ftm_prices[, is_always_loser := as.integer(firm_id %in% fp$firm_id)]

# Firm-level aggregates
firm_stats <- ftm_prices[, .(
  n_participations = .N,
  n_wins = sum(won, na.rm=TRUE),
  win_rate = mean(won, na.rm=TRUE),
  mean_contract_value = mean(win_price[won == 1], na.rm=TRUE),
  total_contract_value = sum(win_price[won == 1], na.rm=TRUE),
  median_tender_value = median(win_price, na.rm=TRUE),
  mean_tender_value = mean(win_price, na.rm=TRUE),
  is_fl = max(is_fl)
), by=firm_id]

# Classify into groups
firm_stats[, group := fifelse(is_fl == 1, "FL",
                    fifelse(win_rate == 0, "Non-FL always-loser",
                    fifelse(win_rate < 0.1, "Low win-rate (<10%)",
                    "Regular competitor")))]

# Expected profit per participation under different bidding cost assumptions
# bidding_cost = fraction of median tender value
bidding_costs <- c(0.005, 0.01, 0.02, 0.05)  # 0.5%, 1%, 2%, 5%

for (bc in bidding_costs) {
  col_name <- paste0("eprofit_bc", bc*100)
  firm_stats[, (col_name) := win_rate * mean_tender_value * 0.10 -  # 10% margin on wins
                              bc * median_tender_value]
}

# Summary by group
cat("\n--- Expected Profit per Participation ---\n")
cat("(Assuming 10% gross margin on wins)\n\n")

for (bc in bidding_costs) {
  col_name <- paste0("eprofit_bc", bc*100)
  cat(sprintf("Bidding cost = %.1f%% of tender value:\n", bc*100))
  summary_dt <- firm_stats[, .(
    N = .N,
    mean_win_rate = round(mean(win_rate, na.rm=TRUE), 4),
    mean_eprofit = round(mean(get(col_name), na.rm=TRUE), 2),
    median_eprofit = round(median(get(col_name), na.rm=TRUE), 2),
    pct_negative = round(100 * mean(get(col_name) < 0, na.rm=TRUE), 1)
  ), by=group]
  setorder(summary_dt, group)
  print(summary_dt)
  cat("\n")
}

# ═══════════════════════════════════════════════════════════════════
# 2. TOTAL CAREER EXPECTED LOSS
# ═══════════════════════════════════════════════════════════════════
cat("=== 2. Total Career Expected Loss ===\n")

# For FL firms: total loss = bidding_cost × n_participations × median_tender_value
# (since win_rate = 0, ALL participations are pure cost)
firm_stats[, career_loss_1pct := 0.01 * median_tender_value * n_participations]

career_summary <- firm_stats[, .(
  N = .N,
  mean_participations = round(mean(n_participations), 1),
  mean_career_loss = round(mean(career_loss_1pct, na.rm=TRUE), 0),
  median_career_loss = round(median(career_loss_1pct, na.rm=TRUE), 0),
  total_career_loss = round(sum(career_loss_1pct, na.rm=TRUE), 0),
  mean_total_won = round(mean(total_contract_value, na.rm=TRUE), 0)
), by=group]
setorder(career_summary, group)
cat("Career loss at 1% bidding cost:\n")
print(career_summary)

# ═══════════════════════════════════════════════════════════════════
# 3. COMPARISON: FL vs NON-FL ALWAYS-LOSERS
# ═══════════════════════════════════════════════════════════════════
cat("\n=== 3. FL vs Non-FL Always-Losers ===\n")

al_stats <- firm_stats[win_rate == 0]
al_stats[, is_fl_flag := as.integer(is_fl == 1)]

cat("Always-losers total:", nrow(al_stats), "\n")
cat("  FL:", sum(al_stats$is_fl_flag), "\n")
cat("  Non-FL:", sum(!al_stats$is_fl_flag), "\n")

cat("\nMean participations (FL):", round(mean(al_stats[is_fl_flag==1, n_participations]), 1), "\n")
cat("Mean participations (non-FL):", round(mean(al_stats[is_fl_flag==0, n_participations]), 1), "\n")
cat("Ratio:", round(mean(al_stats[is_fl_flag==1, n_participations]) /
                    mean(al_stats[is_fl_flag==0, n_participations]), 1), "x\n")

# Wilcoxon test on number of participations
w_test <- wilcox.test(al_stats[is_fl_flag==1, n_participations],
                      al_stats[is_fl_flag==0, n_participations])
cat("Wilcoxon p-value:", format(w_test$p.value, digits=4), "\n")

# FL participation is irrational by construction (win_rate=0)
# The question is: HOW irrational? (magnitude of losses)
cat("\nAt 1% bidding cost:\n")
cat("  FL mean career loss:     R$", formatC(mean(al_stats[is_fl_flag==1, career_loss_1pct], na.rm=TRUE),
    big.mark=",", format="f", digits=0), "\n")
cat("  Non-FL mean career loss: R$", formatC(mean(al_stats[is_fl_flag==0, career_loss_1pct], na.rm=TRUE),
    big.mark=",", format="f", digits=0), "\n")
cat("  FL total loss:           R$", formatC(sum(al_stats[is_fl_flag==1, career_loss_1pct], na.rm=TRUE),
    big.mark=",", format="f", digits=0), "\n")

# ═══════════════════════════════════════════════════════════════════
# 4. LaTeX TABLE
# ═══════════════════════════════════════════════════════════════════
cat("\n=== 4. Writing LaTeX table ===\n")

# Compute numbers for table
fl_n <- nrow(firm_stats[group == "FL"])
nonfl_al_n <- nrow(firm_stats[group == "Non-FL always-loser"])
low_wr_n <- nrow(firm_stats[group == "Low win-rate (<10%)"])
reg_n <- nrow(firm_stats[group == "Regular competitor"])

fl_part <- round(mean(firm_stats[group == "FL", n_participations]), 1)
nonfl_al_part <- round(mean(firm_stats[group == "Non-FL always-loser", n_participations]), 1)
low_wr_part <- round(mean(firm_stats[group == "Low win-rate (<10%)", n_participations]), 1)
reg_part <- round(mean(firm_stats[group == "Regular competitor", n_participations]), 1)

fl_wr <- "0.000"
nonfl_al_wr <- "0.000"
low_wr_wr <- round(mean(firm_stats[group == "Low win-rate (<10%)", win_rate]), 3)
reg_wr <- round(mean(firm_stats[group == "Regular competitor", win_rate]), 3)

# Expected profit at 1% bidding cost
fl_ep <- round(mean(firm_stats[group == "FL", eprofit_bc1], na.rm=TRUE), 0)
nonfl_al_ep <- round(mean(firm_stats[group == "Non-FL always-loser", eprofit_bc1], na.rm=TRUE), 0)
low_wr_ep <- round(mean(firm_stats[group == "Low win-rate (<10%)", eprofit_bc1], na.rm=TRUE), 0)
reg_ep <- round(mean(firm_stats[group == "Regular competitor", eprofit_bc1], na.rm=TRUE), 0)

# Percentage with negative expected profit
fl_neg <- round(100 * mean(firm_stats[group == "FL", eprofit_bc1] < 0, na.rm=TRUE), 1)
nonfl_al_neg <- round(100 * mean(firm_stats[group == "Non-FL always-loser", eprofit_bc1] < 0, na.rm=TRUE), 1)
low_wr_neg <- round(100 * mean(firm_stats[group == "Low win-rate (<10%)", eprofit_bc1] < 0, na.rm=TRUE), 1)
reg_neg <- round(100 * mean(firm_stats[group == "Regular competitor", eprofit_bc1] < 0, na.rm=TRUE), 1)

# Career loss at 1%
fl_cl <- round(mean(firm_stats[group == "FL", career_loss_1pct], na.rm=TRUE) / 1000, 1)
nonfl_al_cl <- round(mean(firm_stats[group == "Non-FL always-loser", career_loss_1pct], na.rm=TRUE) / 1000, 1)

fmt <- function(x) formatC(x, big.mark=",", format="d")

tex <- c(
  "% CO-AUTHOR EDIT: INSERT RATIONALITY TEST [T2.1]",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{FL Participation Rationality Test}",
  "\\label{tab:rationality}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccccc}",
  "\\toprule",
  " & $N$ & Mean & Win & $E[\\pi]$ & $\\%$ negative & Career \\\\",
  " & firms & particip. & rate & per bid & $E[\\pi]$ & loss (R\\$K) \\\\",
  "\\midrule",
  sprintf("FL firms & %s & %.1f & %s & %s & %.1f\\%% & %.1f \\\\",
          fmt(fl_n), fl_part, fl_wr, fmt(fl_ep), fl_neg, fl_cl),
  sprintf("Non-FL always-losers & %s & %.1f & %s & %s & %.1f\\%% & %.1f \\\\",
          fmt(nonfl_al_n), nonfl_al_part, nonfl_al_wr, fmt(nonfl_al_ep), nonfl_al_neg, nonfl_al_cl),
  sprintf("Low win-rate ($<$10\\%%) & %s & %.1f & %.3f & %s & %.1f\\%% & --- \\\\",
          fmt(low_wr_n), low_wr_part, low_wr_wr, fmt(low_wr_ep), low_wr_neg),
  sprintf("Regular competitors & %s & %.1f & %.3f & %s & %.1f\\%% & --- \\\\",
          fmt(reg_n), reg_part, reg_wr, fmt(reg_ep), reg_neg),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Expected profit per bid assumes 10\\% gross margin on wins",
  "and 1\\% of median tender value as bidding cost.",
  "$E[\\pi] = \\text{win\\_rate} \\times \\text{mean\\_value} \\times 0.10 - 0.01 \\times \\text{median\\_value}$.",
  "Career loss = bidding cost $\\times$ total participations.",
  "FL firms have zero wins by construction; under competitive bidding,",
  "their participation generates guaranteed losses for any positive bidding cost.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(OUT_T, "tab_rationality.tex"))
cat("Table saved.\n")

# ── Save CSV ──────────────────────────────────────────────────────
results <- data.frame(
  group = c("FL", "NonFL_AL", "LowWR", "Regular"),
  n_firms = c(fl_n, nonfl_al_n, low_wr_n, reg_n),
  mean_participations = c(fl_part, nonfl_al_part, low_wr_part, reg_part),
  mean_eprofit_1pct = c(fl_ep, nonfl_al_ep, low_wr_ep, reg_ep),
  pct_negative_eprofit = c(fl_neg, nonfl_al_neg, low_wr_neg, reg_neg)
)
write.csv(results, file.path(OUT_T, "rationality_results.csv"), row.names=FALSE)
cat("CSV saved.\n")

cat("\n=== DONE ===\n")
