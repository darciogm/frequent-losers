# ============================================================================
# 39_gate_d4_cade_winner_heavy.R — Gate diagnostic D4: CADE-defendant
# winner-heavy distribution
# Paper 3 v14 / Path γ++ gate
#
# Purpose: confirm that direct CADE bid-rigging defendants are predominantly
# frequent WINNERS, not frequent losers — empirically grounding the
# institutional asymmetry the screen exploits. The screen targets the
# loser-side of the bidding pool by design; if direct defendants were also
# concentrated on the loser-side, the construct would be ill-defined.
#
# Tests:
#   1. Win-rate distribution: 47 direct CADE-BEC defendants vs full BEC
#      universe (41,444 firms) — Mann-Whitney; histogram.
#   2. Direct defendants split by always-loser status: how many are AL?
#   3. Among non-AL CADE defendants, what is the distribution of n_wins,
#      n_participations, win_rate?
#   4. Comparison: median win_rate of CADE defendants vs median win_rate
#      of BEC firms.
#
# Pass criterion (Round 3): direct CADE defendants have median win_rate
# significantly above the BEC median (Mann-Whitney p < 0.05), AND fewer
# than 1/3 of direct defendants are always-losers, AND median n_wins
# among direct defendants exceeds 1.
#
# Output: output/gate_d4/d4_winner_heavy.csv
#         output/gate_d4/fig_d4_winner_distribution.pdf
# ============================================================================

cat("=== 39_gate_d4_cade_winner_heavy.R: Diagnostic D4 (CADE winner-heavy) ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "gate_d4")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load firm-level loss/win stats + CADE direct-defendant crossmatch --
fls <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_loss_stats.parquet")))
fls[, firm_code := as.character(`códigofornecedor`)]

cade_xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(cade_xm$firm_code)
cat(sprintf("\n  Direct CADE-BEC defendants (unique CNPJs): %d\n",
            length(direct_codes)))
cat(sprintf("  Universe of BEC firms: %s\n", format(nrow(fls), big.mark=",")))

fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
fls <- merge(fls,
             fp[, .(firm_code, fp_always_loser = always_loser, fp_tc = tenders_count)],
             by = "firm_code", all.x = TRUE)
fls[is.na(fp_always_loser), fp_always_loser := 0L]
fls[is.na(fp_tc),           fp_tc           := 0L]
fls[, is_direct_cade := as.integer(firm_code %in% direct_codes)]

# ---- Test 1: Win-rate distribution — Mann-Whitney + summary ------------
cat("\n--- Test 1: win_rate distribution ---\n")
direct <- fls[is_direct_cade == 1L]
others <- fls[is_direct_cade == 0L]
cat(sprintf("  Direct CADE defendants matched: %d / %d on file\n",
            nrow(direct), length(direct_codes)))

if (nrow(direct) >= 5) {
  cat(sprintf("\n  CADE direct defendants — win_rate summary:\n"))
  print(direct[, .(N = .N,
                    mean    = round(mean(win_rate, na.rm = TRUE), 4),
                    median  = round(median(win_rate, na.rm = TRUE), 4),
                    p25     = round(quantile(win_rate, 0.25, na.rm = TRUE), 4),
                    p75     = round(quantile(win_rate, 0.75, na.rm = TRUE), 4),
                    n_zero_wr = sum(win_rate == 0, na.rm = TRUE))])
  cat(sprintf("\n  BEC universe (others) — win_rate summary:\n"))
  print(others[, .(N = .N,
                    mean    = round(mean(win_rate, na.rm = TRUE), 4),
                    median  = round(median(win_rate, na.rm = TRUE), 4),
                    p25     = round(quantile(win_rate, 0.25, na.rm = TRUE), 4),
                    p75     = round(quantile(win_rate, 0.75, na.rm = TRUE), 4),
                    n_zero_wr = sum(win_rate == 0, na.rm = TRUE))])

  mw <- wilcox.test(direct$win_rate, others$win_rate, alternative = "greater",
                    conf.int = FALSE, exact = FALSE)
  cat(sprintf("\n  Mann-Whitney (one-sided: direct > others): W = %.0f, p = %.4g\n",
              mw$statistic, mw$p.value))
}

# ---- Test 2: Always-loser breakdown -----------------------------------
cat("\n--- Test 2: always-loser status of direct CADE defendants ---\n")
breakdown <- direct[, .(N = .N,
                         always_loser = sum(fp_always_loser == 1L),
                         non_AL       = sum(fp_always_loser == 0L))]
print(breakdown)
share_AL <- breakdown$always_loser / breakdown$N
cat(sprintf("    Share AL among direct defendants: %.2f%% (%d/%d)\n",
            100 * share_AL, breakdown$always_loser, breakdown$N))
cat(sprintf("    Share AL in BEC universe:         %.2f%% (%s/%s)\n",
            100 * mean(others$fp_always_loser == 1L),
            format(sum(others$fp_always_loser == 1L), big.mark=","),
            format(nrow(others), big.mark=",")))

# ---- Test 3: Among non-AL CADE direct, distribution of activity --------
cat("\n--- Test 3: activity distribution of NON-always-loser CADE defendants ---\n")
non_al_direct <- direct[fp_always_loser == 0L]
if (nrow(non_al_direct) >= 1) {
  print(non_al_direct[, .(
    N = .N,
    mean_wins  = round(mean(total_wins, na.rm = TRUE), 1),
    med_wins   = round(median(total_wins, na.rm = TRUE), 1),
    mean_part  = round(mean(total_participations, na.rm = TRUE), 1),
    med_part   = round(median(total_participations, na.rm = TRUE), 1),
    mean_wr    = round(mean(win_rate, na.rm = TRUE), 4),
    med_wr     = round(median(win_rate, na.rm = TRUE), 4)
  )])
}

# ---- Test 4: Comparison median win_rate ---------------------------------
cat("\n--- Test 4: comparison of medians ---\n")
med_direct <- median(direct$win_rate, na.rm = TRUE)
med_other  <- median(others$win_rate, na.rm = TRUE)
mean_direct <- mean(direct$win_rate, na.rm = TRUE)
mean_other  <- mean(others$win_rate, na.rm = TRUE)
cat(sprintf("    Median win_rate: direct = %.4f  others = %.4f\n",
            med_direct, med_other))
cat(sprintf("    Mean   win_rate: direct = %.4f  others = %.4f\n",
            mean_direct, mean_other))

# ---- Save consolidated CSV ----------------------------------------------
sum_dt <- data.table(
  group = c("direct_CADE","BEC_others"),
  N = c(nrow(direct), nrow(others)),
  mean_win_rate = c(mean_direct, mean_other),
  med_win_rate  = c(med_direct,  med_other),
  share_AL      = c(mean(direct$fp_always_loser == 1L),
                    mean(others$fp_always_loser == 1L)),
  med_total_wins = c(median(direct$total_wins, na.rm = TRUE),
                     median(others$total_wins, na.rm = TRUE)),
  med_total_participations = c(median(direct$total_participations, na.rm = TRUE),
                                median(others$total_participations, na.rm = TRUE))
)
fwrite(sum_dt, file.path(OUT, "d4_winner_heavy.csv"))

# ---- Plot ---------------------------------------------------------------
plot_dt <- rbind(
  data.table(group = "Direct CADE defendants", win_rate = direct$win_rate),
  data.table(group = "BEC universe (others)",  win_rate = others$win_rate)
)
plot_dt <- plot_dt[!is.na(win_rate)]

p <- ggplot(plot_dt, aes(x = win_rate, y = after_stat(density), fill = group)) +
  geom_histogram(position = "identity", alpha = 0.5, bins = 30) +
  scale_fill_manual(values = c("Direct CADE defendants" = "#d73027",
                                 "BEC universe (others)"  = "#5b8aa6")) +
  labs(x = "Win rate (wins / participations)",
       y = "Density",
       title = "Direct CADE defendants are winner-heavy, not loser-heavy",
       subtitle = sprintf("Median win_rate: direct = %.3f vs BEC universe = %.3f",
                          med_direct, med_other),
       fill = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave(file.path(OUT, "fig_d4_winner_distribution.pdf"), p,
       width = 8, height = 4.5, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n",
            file.path(OUT, "fig_d4_winner_distribution.pdf")))

# ---- Verdict ------------------------------------------------------------
cat("\n  ===== Gate D4 verdict =====\n")
mw_pass     <- exists("mw") && mw$p.value < 0.05
share_pass  <- share_AL < 1/3
median_pass <- median(direct$total_wins, na.rm = TRUE) > 1
verdict <- (
  if (mw_pass && share_pass && median_pass) "PASS"
  else if (sum(c(mw_pass, share_pass, median_pass)) >= 2) "WEAK_PASS"
  else "FAIL"
)
cat(sprintf("    Mann-Whitney win_rate (direct > others) p < 0.05 ?  %s\n",
            ifelse(mw_pass, "YES", "NO")))
cat(sprintf("    Share AL among direct defendants < 33%% ?  %s  (%.1f%%)\n",
            ifelse(share_pass, "YES", "NO"), 100 * share_AL))
cat(sprintf("    Median total_wins among direct defendants > 1 ?  %s  (%.0f)\n",
            ifelse(median_pass, "YES", "NO"),
            median(direct$total_wins, na.rm = TRUE)))
cat(sprintf("    Diagnostic D4 verdict: %s\n", verdict))

cat("\n  Done.\n")
