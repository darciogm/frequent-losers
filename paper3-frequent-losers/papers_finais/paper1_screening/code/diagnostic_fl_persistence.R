# ============================================================================
# diagnostic_fl_persistence.R — What happens to FL firms that disappear?
# ============================================================================
# Split-half: define FL on 2009-2013, check fate in 2014-2019
# ============================================================================

cat("=== diagnostic_fl_persistence.R ===\n")
cat("  What happens to FL firms that disappear between periods?\n\n")

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})

DATA_DIR <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/data/processed"
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

# ---- Load data ---------------------------------------------------------------
cat("  Loading data...\n")

ftm <- as.data.table(read_parquet(file.path(DATA_DIR, "firm_tender_map.parquet")))
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
ftm[, firm_id := as.character(firm_id)]
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

# Extract year from OC code (chars 12-15)
ftm[, year := as.integer(substr(oc_code, 12, 15))]

# ---- Split-half FL definition ------------------------------------------------
cat("  Defining FL in each half-period...\n")

define_fl <- function(dt) {
  # Per-firm stats
  firm_stats <- dt[, .(
    n_tenders = .N,
    n_wins = sum(won),
    win_rate = mean(won)
  ), by = firm_id]

  # Always-losers
  al <- firm_stats[win_rate == 0]

  # IQR threshold on always-losers
  q <- quantile(al$n_tenders, c(0.25, 0.50, 0.75))
  iqr_val <- q[3] - q[1]
  threshold <- q[2] + 1.5 * iqr_val

  fl_ids <- al[n_tenders > threshold, firm_id]

  list(
    firm_stats = firm_stats,
    always_losers = al,
    fl_ids = fl_ids,
    threshold = threshold,
    n_al = nrow(al),
    n_fl = length(fl_ids)
  )
}

# Period 1: 2009-2013
ftm_p1 <- ftm[year >= 2009 & year <= 2013]
p1 <- define_fl(ftm_p1)
cat(sprintf("  Period 1 (2009-2013): %s always-losers, %d FL (threshold: %.0f)\n",
            pfmt_int(p1$n_al), p1$n_fl, p1$threshold))

# Period 2: 2014-2019
ftm_p2 <- ftm[year >= 2014 & year <= 2019]
p2 <- define_fl(ftm_p2)
cat(sprintf("  Period 2 (2014-2019): %s always-losers, %d FL (threshold: %.0f)\n",
            pfmt_int(p2$n_al), p2$n_fl, p2$threshold))

# ---- Persistence check -------------------------------------------------------
fl_p1 <- p1$fl_ids
fl_p2 <- p2$fl_ids

persistent <- intersect(fl_p1, fl_p2)
disappeared <- setdiff(fl_p1, fl_p2)

cat(sprintf("\n  P1 FL firms: %d\n", length(fl_p1)))
cat(sprintf("  Persistent (FL in both periods): %d (%.1f%%)\n",
            length(persistent), 100 * length(persistent) / length(fl_p1)))
cat(sprintf("  Disappeared from FL: %d (%.1f%%)\n",
            length(disappeared), 100 * length(disappeared) / length(fl_p1)))

# ---- Fate of disappeared FL firms in Period 2 --------------------------------
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("FATE OF DISAPPEARED FL FIRMS IN PERIOD 2\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

# Check if they appear at all in P2
p2_stats <- p2$firm_stats

disappeared_in_p2 <- p2_stats[firm_id %chin% disappeared]
disappeared_absent <- setdiff(disappeared, p2_stats$firm_id)

cat(sprintf("\n  Of %d disappeared FL firms:\n", length(disappeared)))
cat(sprintf("    Exited BEC entirely (no P2 activity): %d (%.1f%%)\n",
            length(disappeared_absent),
            100 * length(disappeared_absent) / length(disappeared)))
cat(sprintf("    Still active in P2: %d (%.1f%%)\n",
            nrow(disappeared_in_p2),
            100 * nrow(disappeared_in_p2) / length(disappeared)))

if (nrow(disappeared_in_p2) > 0) {
  # Classify the active ones
  disappeared_in_p2[, fate := fcase(
    win_rate > 0, "Started winning (wr > 0)",
    win_rate == 0 & n_tenders > p2$threshold, "Still FL-eligible (should be in P2 FL)",
    win_rate == 0 & n_tenders <= p2$threshold, "Below threshold (zero-win, low volume)"
  )]

  fate_table <- disappeared_in_p2[, .N, by = fate][order(-N)]

  cat("\n  Fate breakdown (active in P2):\n")
  for (i in 1:nrow(fate_table)) {
    cat(sprintf("    %s: %d (%.1f%% of disappeared, %.1f%% of active)\n",
                fate_table$fate[i], fate_table$N[i],
                100 * fate_table$N[i] / length(disappeared),
                100 * fate_table$N[i] / nrow(disappeared_in_p2)))
  }

  # Stats for those who started winning
  winners <- disappeared_in_p2[win_rate > 0]
  if (nrow(winners) > 0) {
    cat(sprintf("\n  Those who started winning (N = %d):\n", nrow(winners)))
    cat(sprintf("    Mean win rate in P2: %.1f%%\n", 100 * mean(winners$win_rate)))
    cat(sprintf("    Mean participations in P2: %.1f\n", mean(winners$n_tenders)))
    cat(sprintf("    Median wins in P2: %.0f\n", median(winners$n_wins)))
  }

  # Stats for below-threshold
  below <- disappeared_in_p2[win_rate == 0 & n_tenders <= p2$threshold]
  if (nrow(below) > 0) {
    cat(sprintf("\n  Below-threshold zero-win (N = %d):\n", nrow(below)))
    cat(sprintf("    Mean participations in P2: %.1f (vs threshold %.0f)\n",
                mean(below$n_tenders), p2$threshold))
    cat(sprintf("    Median participations in P2: %.0f\n", median(below$n_tenders)))
  }
}

# ---- New FL firms in Period 2 ------------------------------------------------
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("NEW FL FIRMS IN PERIOD 2\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

new_fl <- setdiff(fl_p2, fl_p1)
cat(sprintf("\n  New FL firms in P2 (not FL in P1): %d\n", length(new_fl)))

# Were they active in P1 at all?
p1_stats <- p1$firm_stats
new_fl_in_p1 <- p1_stats[firm_id %chin% new_fl]
new_fl_absent_p1 <- setdiff(new_fl, p1_stats$firm_id)

cat(sprintf("    Not active in P1 (new entrants): %d (%.1f%%)\n",
            length(new_fl_absent_p1), 100 * length(new_fl_absent_p1) / length(new_fl)))
cat(sprintf("    Active in P1 but not FL: %d (%.1f%%)\n",
            nrow(new_fl_in_p1), 100 * nrow(new_fl_in_p1) / length(new_fl)))

if (nrow(new_fl_in_p1) > 0) {
  new_fl_in_p1[, p1_status := fcase(
    win_rate > 0, "Had wins in P1",
    win_rate == 0, "Zero-win in P1 (below threshold)"
  )]

  p1_status_table <- new_fl_in_p1[, .N, by = p1_status]
  cat("\n  P1 status of new P2 FL firms:\n")
  for (i in 1:nrow(p1_status_table)) {
    cat(sprintf("    %s: %d\n", p1_status_table$p1_status[i], p1_status_table$N[i]))
  }
}

# ---- Market-level rotation test ----------------------------------------------
cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("MARKET-LEVEL ROTATION: Do new FL firms appear in same markets?\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

# Can't directly compare OCs across periods (different tenders).
# Compare at the PBU level (first 11 chars of oc_code)
ftm_p1[, pbu := substr(oc_code, 1, 11)]
ftm_p2[, pbu := substr(oc_code, 1, 11)]

disappeared_pbus <- ftm_p1[firm_id %chin% disappeared, unique(pbu)]
new_fl_pbus <- ftm_p2[firm_id %chin% new_fl, unique(pbu)]

overlap_pbus <- intersect(disappeared_pbus, new_fl_pbus)
all_pbus_p2 <- ftm_p2[, uniqueN(pbu)]

cat(sprintf("\n  PBUs where disappeared FL firms operated (P1): %d\n",
            length(disappeared_pbus)))
cat(sprintf("  PBUs where new FL firms operate (P2): %d\n",
            length(new_fl_pbus)))
cat(sprintf("  Overlap: %d PBUs (%.1f%% of disappeared-FL PBUs)\n",
            length(overlap_pbus),
            100 * length(overlap_pbus) / length(disappeared_pbus)))

# Compare to random expectation
# If new FL firms were randomly distributed across P2 PBUs,
# what fraction of disappeared-FL PBUs would they cover?
set.seed(42)
ftm_p2[, pbu := substr(oc_code, 1, 11)]
all_p2_pbus <- ftm_p2[, unique(pbu)]
n_perm <- 1000
perm_overlaps <- numeric(n_perm)
for (i in seq_len(n_perm)) {
  random_pbus <- sample(all_p2_pbus, length(new_fl_pbus))
  perm_overlaps[i] <- length(intersect(disappeared_pbus, random_pbus))
}

cat(sprintf("\n  Random expectation: %.1f PBUs (SD: %.1f)\n",
            mean(perm_overlaps), sd(perm_overlaps)))
cat(sprintf("  Observed / Expected: %.2f\n",
            length(overlap_pbus) / mean(perm_overlaps)))
cat(sprintf("  p-value (observed >= random): %.4f\n",
            mean(perm_overlaps >= length(overlap_pbus))))

cat("\n=== DIAGNOSTIC COMPLETE ===\n")
