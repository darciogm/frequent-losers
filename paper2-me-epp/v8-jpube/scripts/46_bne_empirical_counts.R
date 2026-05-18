# Robustness: replace Poisson bidder-count draws with sampling from the
# empirical class-period-type bidder-count distributions in the BNE
# Monte Carlo. Mirrors the baseline simulate_auction() logic from
# v7-jpube-tight/scripts/45_bne_simulation.R, changing ONLY the count
# draws (lines 85-86 in the canonical script).
#
# Output: console report + JSON snippet for the manuscript threat table.

suppressPackageStartupMessages({
  library(data.table)
  library(duckdb)
  library(DBI)
})

BASE <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
FC_PATH    <- file.path(BASE, "v6-jpube/data/processed/bids_uh_cleaned.parquet")
ENTRY_PATH <- file.path(BASE, "v6-jpube/data/processed/entry_rates.parquet")

con <- dbConnect(duckdb::duckdb())
dbExecute(con, "PRAGMA threads=8")
dbExecute(con, "PRAGMA memory_limit='8GB'")

# 1. F_c per (pharma × type × period). Same query as baseline. -------
fc <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", FC_PATH)) |> setDT()

fc_samples <- list()
for (ph in c(0, 1)) {
  for (per in c("Pre", "Post")) {
    for (sm in c(0, 1)) {
      x <- fc[pharma_narrow == ph & period == per & sme_bec == sm, c]
      if (length(x) < 50) next
      fc_samples[[paste(ph, per, sm, sep = "_")]] <- x
    }
  }
}

# 2. Empirical bidder-count distributions per (pharma × period). ----
counts <- dbGetQuery(con, sprintf("
  SELECT pharma_narrow, period, n_sme_bid, n_nonsme_bid
  FROM read_parquet('%s')
  WHERE mod = 'pregao'
", ENTRY_PATH)) |> setDT()

count_vec <- function(ph, per, type) {
  v <- counts[pharma_narrow == ph & period == per, get(type)]
  v[is.finite(v)]
}

# 3. Simulation under empirical count distributions. ------------------
# Same logic as simulate_auction() in 45_bne_simulation.R, only
# difference: counts are sample()'d from the empirical per-auction
# vectors instead of rpois().

simulate_empirical <- function(n_sme_vec, n_nonsme_vec,
                                fc_sme, fc_nonsme, B = 10000) {
  prices <- numeric(B)
  for (b in seq_len(B)) {
    n_s  <- if (length(n_sme_vec)  > 0) sample(n_sme_vec,  1) else 0
    n_ns <- if (length(n_nonsme_vec) > 0) sample(n_nonsme_vec, 1) else 0
    if (n_s + n_ns < 2) { prices[b] <- NA; next }
    costs <- c(
      if (n_s  > 0) sample(fc_sme,   n_s,  replace = TRUE) else numeric(),
      if (n_ns > 0) sample(fc_nonsme, n_ns, replace = TRUE) else numeric())
    prices[b] <- sort(costs)[2]
  }
  prices
}

# Single non-SME count vector for S2/S3: by construction non-SMEs are
# zero in SME-only counterfactuals, so we just pass an empty vector.
zero_ns <- numeric(0)

set.seed(20260517L)  # robustness seed, distinct from baseline

results <- list()
for (ph in c(0, 1)) {
  fc_sme_pre  <- fc_samples[[paste(ph, "Pre",  1, sep = "_")]]
  fc_sme_post <- fc_samples[[paste(ph, "Post", 1, sep = "_")]]
  fc_ns_pre   <- fc_samples[[paste(ph, "Pre",  0, sep = "_")]]
  if (is.null(fc_sme_pre) || is.null(fc_ns_pre)) next

  n_sme_pre   <- count_vec(ph, "Pre",  "n_sme_bid")
  n_sme_post  <- count_vec(ph, "Post", "n_sme_bid")
  n_ns_pre    <- count_vec(ph, "Pre",  "n_nonsme_bid")

  # S1: open Pre — empirical (n_sme, n_nonsme) from Pre.
  p_S1 <- simulate_empirical(n_sme_pre, n_ns_pre,  fc_sme_pre, fc_ns_pre)
  # S2: SME-only with Pre SME pool, zero non-SMEs.
  p_S2 <- simulate_empirical(n_sme_pre, zero_ns,    fc_sme_pre, fc_ns_pre)
  # S3: SME-only with Post SME pool (endogenous), zero non-SMEs.
  p_S3 <- simulate_empirical(n_sme_post, zero_ns,
                              if (!is.null(fc_sme_post)) fc_sme_post
                              else fc_sme_pre,
                              fc_ns_pre)

  mean_S1 <- mean(p_S1, na.rm = TRUE)
  mean_S2 <- mean(p_S2, na.rm = TRUE)
  mean_S3 <- mean(p_S3, na.rm = TRUE)
  eff_total <- mean_S3 - mean_S1
  eff_intens <- mean_S2 - mean_S1
  eff_entry  <- mean_S3 - mean_S2
  share_intens <- abs(eff_intens) /
                   (abs(eff_intens) + abs(eff_entry)) * 100

  results[[length(results) + 1]] <- data.table(
    pharma_narrow = ph,
    mean_S1 = round(mean_S1, 4),
    mean_S2 = round(mean_S2, 4),
    mean_S3 = round(mean_S3, 4),
    eff_total = round(eff_total, 4),
    eff_intens = round(eff_intens, 4),
    eff_entry  = round(eff_entry, 4),
    share_intens_abs = round(share_intens, 2),
    n_pre_obs  = length(n_sme_pre),
    n_post_obs = length(n_sme_post)
  )
}
res <- rbindlist(results)
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]

cat("\n=== Empirical bidder-count BNE robustness ===\n\n")
print(res[, .(pharma_lbl,
              mean_S1, mean_S2, mean_S3,
              eff_total, eff_intens, eff_entry,
              share_intens_abs,
              n_pre_obs, n_post_obs)])

cat("\n--- comparison with baseline (Poisson) ---\n")
cat("Baseline NP: total +0.227, exclusion-share 72.0%\n")
cat("Baseline PH: total +0.294, exclusion-share ~79%\n")

dbDisconnect(con, shutdown = TRUE)
