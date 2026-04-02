# ============================================================================
# 19_dyadic_permutation.R — Dyadic Linkage with Permutation Test
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Tests whether FL-winner co-bidding pairs are more concentrated than
# expected under random assignment of FL labels among always-losers.
# Permutation preserves participation intensity (stratified by quartile).
# ============================================================================

cat("=== 19_dyadic_permutation.R: Dyadic linkage permutation ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

N_PERM <- 1000L
set.seed(20240401)

# ---- Load data ---------------------------------------------------------------
cat("  Loading data...\n")

ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")
if (!file.exists(ftm_file)) stop("firm_tender_map.parquet not found")
ftm <- as.data.table(read_parquet(ftm_file))

# Standardize column names
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

# Load FL identification
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

# FL threshold (median + 1.5*IQR)
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val
fl_ids <- unique(fp[tenders_count > threshold, firm_id])
cat(sprintf("  FL firms: %s (threshold: %.0f)\n", pfmt_int(length(fl_ids)), threshold))

# All always-losers (pool for permutation)
al_ids <- unique(fp$firm_id)
cat(sprintf("  Always-losers (permutation pool): %s\n", pfmt_int(length(al_ids))))

# Participation counts for stratification
al_tenders <- fp[, .(firm_id, tenders_count)]
# Use ntile-style quartiles to handle ties (quantile breaks may not be unique)
al_tenders[, quartile := frank(tenders_count, ties.method = "random")]
al_tenders[, quartile := ceiling(quartile / .N * 4)]
al_tenders[quartile > 4, quartile := 4L]  # safety cap

# ============================================================================
# Phase 1: Compute observed dyadic statistics
# ============================================================================

cat("  Phase 1: Observed dyadic statistics...\n")

ftm[, is_fl := as.integer(firm_id %chin% fl_ids)]

# Get FL tenders
fl_ftm <- ftm[is_fl == 1L]
fl_tenders <- unique(fl_ftm[, .(oc_code, item_code)])

# Winners in FL tenders
all_in_fl_tenders <- merge(fl_tenders, ftm, by = c("oc_code", "item_code"))
winners_in_fl <- all_in_fl_tenders[won == 1L & is_fl == 0L]

# FL-Winner pair counts
fl_winner_pairs <- merge(
  fl_ftm[, .(fl_firm = firm_id, oc_code, item_code)],
  winners_in_fl[, .(oc_code, item_code, winner = firm_id)],
  by = c("oc_code", "item_code"), allow.cartesian = TRUE
)

observed_pair_counts <- fl_winner_pairs[, .N, by = .(fl_firm, winner)]
cat(sprintf("  Unique FL-winner pairs: %s\n", pfmt_int(nrow(observed_pair_counts))))
cat(sprintf("  Pairs with 5+ co-bids: %s\n", pfmt_int(sum(observed_pair_counts$N >= 5))))
cat(sprintf("  Pairs with 10+ co-bids: %s\n", pfmt_int(sum(observed_pair_counts$N >= 10))))
cat(sprintf("  Pairs with 20+ co-bids: %s\n", pfmt_int(sum(observed_pair_counts$N >= 20))))

# Key statistics to test
obs_max_pair <- max(observed_pair_counts$N)
obs_mean_top10 <- mean(sort(observed_pair_counts$N, decreasing = TRUE)[1:min(10, nrow(observed_pair_counts))])
obs_n_5plus <- sum(observed_pair_counts$N >= 5)
obs_top_share <- observed_pair_counts[, .(top_share = max(N) / sum(N)), by = fl_firm]
obs_mean_top_share <- mean(obs_top_share$top_share)

cat(sprintf("  Max pair count: %d\n", obs_max_pair))
cat(sprintf("  Mean top-10 pair count: %.1f\n", obs_mean_top10))
cat(sprintf("  Mean top-partner share: %.4f\n", obs_mean_top_share))

# ============================================================================
# Phase 2: Permutation test
# ============================================================================

cat(sprintf("  Phase 2: Permutation test (%d iterations)...\n", N_PERM))

# Pre-compute: always-loser tenders for fast permutation
al_ftm <- ftm[firm_id %chin% al_ids]
al_firm_list <- al_tenders[, .(firm_id, quartile)]

# Original FL flags by quartile for stratified permutation
fl_in_al <- al_firm_list[firm_id %chin% fl_ids]
fl_per_q <- fl_in_al[, .N, by = quartile]

perm_max_pair <- numeric(N_PERM)
perm_mean_top10 <- numeric(N_PERM)
perm_n_5plus <- numeric(N_PERM)
perm_mean_top_share <- numeric(N_PERM)

t0 <- Sys.time()
for (iter in seq_len(N_PERM)) {
  if (iter %% 100 == 0) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("    Iteration %d/%d (%.1fs elapsed)\n", iter, N_PERM, elapsed))
  }

  # Stratified random draw: same number of FL per quartile
  perm_fl <- character(0)
  for (qi in fl_per_q$quartile) {
    pool <- al_firm_list[quartile == qi, firm_id]
    n_draw <- fl_per_q[quartile == qi, N]
    perm_fl <- c(perm_fl, sample(pool, min(n_draw, length(pool))))
  }

  # Compute pair counts for permuted FL set
  perm_fl_ftm <- al_ftm[firm_id %chin% perm_fl]
  perm_fl_tenders <- unique(perm_fl_ftm[, .(oc_code, item_code)])

  perm_all_bidders <- merge(perm_fl_tenders, ftm, by = c("oc_code", "item_code"))
  perm_winners <- perm_all_bidders[won == 1L & !(firm_id %chin% perm_fl)]

  perm_pairs <- merge(
    perm_fl_ftm[, .(fl_firm = firm_id, oc_code, item_code)],
    perm_winners[, .(oc_code, item_code, winner = firm_id)],
    by = c("oc_code", "item_code"), allow.cartesian = TRUE
  )

  if (nrow(perm_pairs) == 0) {
    perm_max_pair[iter] <- 0
    perm_mean_top10[iter] <- 0
    perm_n_5plus[iter] <- 0
    perm_mean_top_share[iter] <- 0
    next
  }

  pc <- perm_pairs[, .N, by = .(fl_firm, winner)]
  perm_max_pair[iter] <- max(pc$N)
  perm_mean_top10[iter] <- mean(sort(pc$N, decreasing = TRUE)[1:min(10, nrow(pc))])
  perm_n_5plus[iter] <- sum(pc$N >= 5)
  pts <- pc[, .(top_share = max(N) / sum(N)), by = fl_firm]
  perm_mean_top_share[iter] <- mean(pts$top_share)
}

elapsed_total <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Permutation complete: %.1f seconds\n", elapsed_total))

# ============================================================================
# Phase 3: Compute p-values
# ============================================================================

cat("  Phase 3: Computing p-values...\n")

pval_max_pair <- mean(perm_max_pair >= obs_max_pair)
pval_mean_top10 <- mean(perm_mean_top10 >= obs_mean_top10)
pval_n_5plus <- mean(perm_n_5plus >= obs_n_5plus)
pval_top_share <- mean(perm_mean_top_share >= obs_mean_top_share)

cat(sprintf("  Max pair count: observed=%d, perm mean=%.1f, p=%.4f\n",
            obs_max_pair, mean(perm_max_pair), pval_max_pair))
cat(sprintf("  Mean top-10 pairs: observed=%.1f, perm mean=%.1f, p=%.4f\n",
            obs_mean_top10, mean(perm_mean_top10), pval_mean_top10))
cat(sprintf("  Pairs >=5 co-bids: observed=%d, perm mean=%.0f, p=%.4f\n",
            obs_n_5plus, mean(perm_n_5plus), pval_n_5plus))
cat(sprintf("  Mean top-partner share: observed=%.4f, perm mean=%.4f, p=%.4f\n",
            obs_mean_top_share, mean(perm_mean_top_share), pval_top_share))

# ============================================================================
# Phase 4: Write tab_dyadic_permutation.tex
# ============================================================================

cat("  Phase 4: Writing tab_dyadic_permutation.tex...\n")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Dyadic Linkage: FL--Winner Pair Concentration (Permutation Test)}",
  "\\label{tab:dyadic_permutation}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  "Statistic & Observed & Perm.\\ mean & Perm.\\ SD & $p$-value \\\\", "\\midrule",
  sprintf("Max pair co-occurrences & %d & %.1f & %.1f & %s \\\\",
    obs_max_pair, mean(perm_max_pair), sd(perm_max_pair), pfmt(pval_max_pair, 4)),
  sprintf("Mean top-10 pair count & %.1f & %.1f & %.1f & %s \\\\",
    obs_mean_top10, mean(perm_mean_top10), sd(perm_mean_top10), pfmt(pval_mean_top10, 4)),
  sprintf("Pairs with $\\geq$5 co-bids & %s & %.0f & %.0f & %s \\\\",
    pfmt_int(obs_n_5plus), mean(perm_n_5plus), sd(perm_n_5plus), pfmt(pval_n_5plus, 4)),
  sprintf("Mean top-partner share & %.4f & %.4f & %.4f & %s \\\\",
    obs_mean_top_share, mean(perm_mean_top_share), sd(perm_mean_top_share), pfmt(pval_top_share, 4)),
  "\\midrule",
  sprintf("FL firms & \\multicolumn{4}{c}{%s} \\\\", pfmt_int(length(fl_ids))),
  sprintf("Always-losers (pool) & \\multicolumn{4}{c}{%s} \\\\", pfmt_int(length(al_ids))),
  sprintf("Permutations & \\multicolumn{4}{c}{%s} \\\\", pfmt_int(N_PERM)),
  "Stratification & \\multicolumn{4}{c}{Participation quartile} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Each permutation randomly reassigns FL labels among",
  "the 16,843 always-loser firms, preserving the number of FL firms per",
  "participation-count quartile (stratified permutation). $p$-values are the",
  "fraction of permutations producing a statistic $\\geq$ the observed value.",
  "Top-partner share is the fraction of an FL firm's tenders won by its most",
  "frequent co-winner.",
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")

writeLines(lines, file.path(OUT_TAB, "tab_dyadic_permutation.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_dyadic_permutation.tex"), "\n")

# ============================================================================
# Save
# ============================================================================

dyadic_results <- list(
  observed = list(
    max_pair = obs_max_pair,
    mean_top10 = obs_mean_top10,
    n_5plus = obs_n_5plus,
    mean_top_share = obs_mean_top_share
  ),
  permutation = list(
    max_pair = perm_max_pair,
    mean_top10 = perm_mean_top10,
    n_5plus = perm_n_5plus,
    mean_top_share = perm_mean_top_share
  ),
  pvalues = list(
    max_pair = pval_max_pair,
    mean_top10 = pval_mean_top10,
    n_5plus = pval_n_5plus,
    top_share = pval_top_share
  ),
  pair_counts = observed_pair_counts,
  config = list(n_perm = N_PERM, n_fl = length(fl_ids), n_al = length(al_ids))
)

saveRDS(dyadic_results, DYADIC_CACHE_V4)
cat("  Results saved:", DYADIC_CACHE_V4, "\n")
cat("  Done.\n")
