#!/usr/bin/env Rscript
# ============================================================================
# 14_density_test_with_cartel.R — KNOC-style density test with CADE ground
# truth comparison (Track A, item A.2)
#
# Purpose: implement the KNOC test of density discontinuity at MV=0 properly
#   (the test the original paper SHOULD have done) and compare results
#   across cartel-exposed vs control subsamples. The question: is the
#   discontinuity (or lack thereof) concentrated in known cartel auctions?
#
# Design
# ------
# Running variable: MV = (runner_up_bid - winner_bid) / winner_bid
#   - For winner rows: MV is negative (winner is cheaper)
#   - For runner-up rows: MV is positive (loser is more expensive)
#
# We use ONE row per auction (the running = -MV from script 06's prep) and
# apply the donut at |MV| < 1e-6 to remove discreteness ties. Note: this
# script reads the *raw* pair files (with cartel flags) directly to keep
# all subsample logic in one place.
#
# Subsamples
# ----------
#   1. PREGÃO full — baseline
#   2. CONVITE full — baseline
#   3. PREGÃO with ≥1 cartel firm in cartel-active period
#   4. PREGÃO with ≥1 cartel firm OUTSIDE cartel period (post-cartel)
#   5. PREGÃO non-cartel control (same year window)
#   6. PREGÃO pair-matched (both winner AND runner-up cartel-active)
#   7. PER-SECTOR breakouts for cartel sectors (medicamentos, etc.)
#
# Outputs
#   04_figures/density_test_panel.pdf — multi-panel density plots
#   04_figures/density_test_pregao_cartel_active.pdf
#   04_figures/density_test_pregao_pair_matched.pdf
#   02_data/intermediate/density_test_results.csv
#   02_data/intermediate/density_test_report.txt
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rddensity)
})

BASE        <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
PREGAO_PATH <- file.path(BASE, "02_data/final/df_pregao_with_cartel_flags.parquet")
CONVITE_PATH<- file.path(BASE, "02_data/final/df_convite_with_cartel_flags.parquet")
FIG_DIR     <- file.path(BASE, "04_figures")
OUT_DIR     <- file.path(BASE, "02_data/intermediate")
TABLE_PATH  <- file.path(OUT_DIR, "density_test_results.csv")
REPORT_PATH <- file.path(OUT_DIR, "density_test_report.txt")

dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

DONUT <- 1e-6
MV_MAX <- 0.10  # envelope around cutoff

.sink <- file(REPORT_PATH, open = "wt")
log <- function(...) {
  msg <- paste0(..., collapse = "")
  cat(msg, "\n"); cat(msg, "\n", file = .sink)
}

log("KNOC density test — pregão & convite, with CADE ground truth")
log("Run at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log(strrep("=", 70))

# ─────────────────────────────────────────────────────────────────────
# Helper: density test with donut
# ─────────────────────────────────────────────────────────────────────
density_test <- function(running, label, n_obs_required = 200) {
  running <- running[is.finite(running)]
  running <- running[abs(running) >= DONUT]
  running <- running[abs(running) < MV_MAX]

  if (length(running) < n_obs_required) {
    log(sprintf("  %-40s [skip, N=%d]", label, length(running)))
    return(data.table(label = label, n = length(running),
                      t_stat = NA_real_, p_value = NA_real_,
                      h_left = NA_real_, h_right = NA_real_))
  }

  fit <- tryCatch(
    rddensity(running, c = 0),
    error = function(e) NULL
  )
  if (is.null(fit)) {
    log(sprintf("  %-40s [fit error]", label))
    return(data.table(label = label, n = length(running),
                      t_stat = NA_real_, p_value = NA_real_,
                      h_left = NA_real_, h_right = NA_real_))
  }

  log(sprintf("  %-40s N=%-7d  T=%+.3f  p=%.4f  h_L=%.4f h_R=%.4f",
              label, length(running),
              fit$test$t_jk, fit$test$p_jk,
              fit$h$left, fit$h$right))

  data.table(
    label = label,
    n = length(running),
    t_stat = fit$test$t_jk,
    p_value = fit$test$p_jk,
    h_left = fit$h$left,
    h_right = fit$h$right
  )
}

# ─────────────────────────────────────────────────────────────────────
# Plot helper: side-by-side density comparison
# ─────────────────────────────────────────────────────────────────────
plot_density_pair <- function(running_a, label_a,
                              running_b, label_b,
                              outfile, title) {
  ra <- running_a[is.finite(running_a) & abs(running_a) >= DONUT &
                  abs(running_a) < 0.05]
  rb <- running_b[is.finite(running_b) & abs(running_b) >= DONUT &
                  abs(running_b) < 0.05]
  if (length(ra) < 100 || length(rb) < 100) {
    log("  [plot skip] insufficient n: ", length(ra), " / ", length(rb))
    return(invisible())
  }
  pdf(outfile, width = 10, height = 5)
  op <- par(mfrow = c(1, 2), mar = c(5, 5, 4, 2), las = 1)

  for (pair in list(list(ra, label_a), list(rb, label_b))) {
    r <- pair[[1]]; lab <- pair[[2]]
    h <- hist(r, breaks = 60, plot = FALSE)
    plot(h, freq = FALSE, col = "lightblue", border = "white",
         xlab = "Running variable (signed margin)",
         ylab = "Density",
         main = paste0(lab, "\n(N=", format(length(r), big.mark = ","),
                       ")"))
    abline(v = 0, lty = 2, col = "red", lwd = 2)
    rug(sample(r, min(2000, length(r))), col = "gray40")
  }

  par(op); dev.off()
  log("  [written] ", outfile)
}

# ─────────────────────────────────────────────────────────────────────
# Load data
# ─────────────────────────────────────────────────────────────────────
log("\n[load] pregão pair file...")
pregao <- as.data.table(read_parquet(PREGAO_PATH))
log("  rows: ", format(nrow(pregao), big.mark = ","))
pregao[, running := -MV]   # +running = won

log("[load] convite pair file...")
convite <- as.data.table(read_parquet(CONVITE_PATH))
log("  rows: ", format(nrow(convite), big.mark = ","))
convite[, running := -MV]

# ─────────────────────────────────────────────────────────────────────
# 1. Baseline density tests
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("1. BASELINE DENSITY TESTS")
log(strrep("─", 70))

results <- list()
results[[length(results) + 1]] <- density_test(
  pregao$running, "PREGÃO full")
results[[length(results) + 1]] <- density_test(
  convite$running, "CONVITE full")

# ─────────────────────────────────────────────────────────────────────
# 2. Cartel-exposure subsamples (pregão)
#
# IMPORTANT: filter at the AUCTION level so both winner and runner-up rows
# are kept together. Filtering by row-level firm flags would introduce
# spurious density asymmetry through sample selection.
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("2. PREGÃO — cartel exposure subsamples (auction-level filters)")
log(strrep("─", 70))

# Auctions with at least one cartel-active firm participating
sub_active <- pregao[has_active_cartel == 1]
results[[length(results) + 1]] <- density_test(
  sub_active$running,
  "Pregão: auctions w/ ≥1 cartel-active firm")

# Auctions with at least one CADE-listed firm but NONE active in current
# year (i.e., the firm is in CADE but the auction is outside the cartel
# period)
sub_inactive <- pregao[has_any_cartel_firm == 1 & has_active_cartel == 0]
results[[length(results) + 1]] <- density_test(
  sub_inactive$running,
  "Pregão: auctions w/ cartel firm × outside period")

# Auctions with NO cartel firm at all (clean control)
sub_noncartel <- pregao[has_any_cartel_firm == 0]
results[[length(results) + 1]] <- density_test(
  sub_noncartel$running, "Pregão: clean control (no cartel firm)")

# Pair-matched: BOTH winner and runner-up are cartel-active firms.
# Strongest signal of head-to-head designated rotation.
sub_paired <- pregao[both_cartel_active == 1]
results[[length(results) + 1]] <- density_test(
  sub_paired$running,
  "Pregão: PAIR-MATCHED both cartel-active",
  n_obs_required = 20)

# Winner is cartel-active (auction-level flag, includes both pair rows)
sub_win_cartel <- pregao[winner_is_cartel_active == 1]
results[[length(results) + 1]] <- density_test(
  sub_win_cartel$running,
  "Pregão: winner is cartel-active firm")

# Runner-up is cartel-active (auction-level)
sub_runner_cartel <- pregao[runnerup_is_cartel_active == 1]
results[[length(results) + 1]] <- density_test(
  sub_runner_cartel$running,
  "Pregão: runner-up is cartel-active firm")

# ─────────────────────────────────────────────────────────────────────
# 3. Convite cartel-exposure subsamples (auction-level filters)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("3. CONVITE — cartel exposure subsamples (auction-level)")
log(strrep("─", 70))

con_active <- convite[has_active_cartel == 1]
results[[length(results) + 1]] <- density_test(
  con_active$running,
  "Convite: auctions w/ cartel-active firm")

con_inactive <- convite[has_any_cartel_firm == 1 & has_active_cartel == 0]
results[[length(results) + 1]] <- density_test(
  con_inactive$running,
  "Convite: auctions w/ cartel firm outside period")

con_noncartel <- convite[has_any_cartel_firm == 0]
results[[length(results) + 1]] <- density_test(
  con_noncartel$running,
  "Convite: clean control (no cartel firm)")

# ─────────────────────────────────────────────────────────────────────
# 4. Per-sector cartel breakouts (pregão)
# Use auction-level filter: keep auctions where any participant is in
# this sector's CADE list AND auction is in cartel-active period.
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("4. PREGÃO — by cartel sector (auction-level)")
log(strrep("─", 70))

# Get sector tag at auction level (any participant)
sector_at_auction <- pregao[
  !is.na(cartel_setor_any),
  .(sector = first(cartel_setor_any)),
  by = auction_item
]
pregao_with_sector <- pregao[sector_at_auction, on = "auction_item"]

cartel_sectors <- unique(pregao_with_sector[!is.na(sector), sector])
log("  cartel sectors observed: ", paste(cartel_sectors, collapse = ", "))

for (sec in cartel_sectors) {
  # Auction-level: pick auctions where ANY participant is from this sector
  # AND has at least one cartel-active firm in the auction year
  sub <- pregao_with_sector[sector == sec & has_active_cartel == 1]
  results[[length(results) + 1]] <- density_test(
    sub$running, paste0("Pregão sector × active: ", sec))
}

# ─────────────────────────────────────────────────────────────────────
# 5. Within-cartel-firm DURING vs AFTER (auction-level filter)
#    Compares the same SET of firms in two different time windows.
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("5. PREGÃO — within cartel-firm auctions, DURING vs AFTER")
log(strrep("─", 70))

cf_auctions <- pregao[has_any_cartel_firm == 1]
log("  total auctions w/ cartel firm (rows): ",
    format(nrow(cf_auctions), big.mark = ","))

during <- cf_auctions[has_active_cartel == 1]
after  <- cf_auctions[has_active_cartel == 0]

results[[length(results) + 1]] <- density_test(
  during$running, "Cartel-firm auctions × DURING period")
results[[length(results) + 1]] <- density_test(
  after$running, "Cartel-firm auctions × AFTER period")

log("\n  Δ(T_during − T_after) — informal test of period concentration")

# ─────────────────────────────────────────────────────────────────────
# 6. Persist results
# ─────────────────────────────────────────────────────────────────────
res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, TABLE_PATH)
log("\n[written] ", TABLE_PATH)

# ─────────────────────────────────────────────────────────────────────
# 7. Figures
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("7. FIGURES")
log(strrep("─", 70))

plot_density_pair(
  sub_active$running, "Cartel × active period",
  sub_noncartel$running, "Non-cartel firms",
  file.path(FIG_DIR, "density_test_cartel_vs_noncartel.pdf"),
  "Density at MV=0: cartel-active vs non-cartel"
)

plot_density_pair(
  during$running, "Cartel firms — DURING",
  after$running,  "Cartel firms — AFTER",
  file.path(FIG_DIR, "density_test_during_vs_after.pdf"),
  "Density at MV=0: cartel firms during vs after period"
)

plot_density_pair(
  sub_paired$running, "PAIR-MATCHED (both cartel)",
  sub_noncartel$running[1:min(50000, length(sub_noncartel$running))],
  "Non-cartel sample",
  file.path(FIG_DIR, "density_test_pair_matched.pdf"),
  "Density at MV=0: pair-matched cartel vs non-cartel"
)

# ─────────────────────────────────────────────────────────────────────
# Summary table
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("=", 70))
log("SUMMARY (T statistic > 0 means more mass on RIGHT side; < 0 means LEFT)")
log("CJM null: density continuous at zero. Reject if |T| > 1.96.")
log(strrep("=", 70))

print(res_dt)
log(""); log(capture.output(print(res_dt)))

log("\nDone.")
close(.sink)
cat("\n[written]", REPORT_PATH, "\n")
