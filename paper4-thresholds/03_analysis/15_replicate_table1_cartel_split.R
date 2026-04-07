#!/usr/bin/env Rscript
# ============================================================================
# 15_replicate_table1_cartel_split.R — Track A item A.3
#
# Purpose: replicate the original paper's Table 1 (RD jumps in incumbency
#   and last-bid) with the corrections from the parecer:
#     1. Restricted treatment window (2009-2015)
#     2. Item-class clustering
#     3. NEW: split by CADE cartel exposure
#
# Hypothesis test:
#   - Story (a) — inter-auction rotation: jumps APPEAR in cartel-exposed
#     auctions and SHRINK / VANISH in clean controls. Vindicates the
#     original paper but reframes as "inter-auction rotation signal".
#   - Story (b) — persistent firm heterogeneity: jumps appear EVERYWHERE,
#     equally in cartel and non-cartel. Original paper was finding selection,
#     not collusion.
#
# The split is the diagnostic.
#
# Inputs:
#   02_data/final/df_convite_winner_looser.parquet  — full convite with
#       won_previous_market, last, item_class, etc. (315 cols)
#   02_data/final/df_convite_with_cartel_flags.parquet — cartel exposure
#       flags (auction-level)
#
# Outputs:
#   02_data/intermediate/table1_cartel_split.csv
#   02_data/intermediate/table1_cartel_split_report.txt
# ============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(rdrobust)
})

BASE        <- "/home/darciogm1/projetos/bitter-pills/paper4-thresholds"
CONVITE_FULL <- file.path(BASE, "02_data/final/df_convite_winner_looser.parquet")
CONVITE_FLAGS<- file.path(BASE, "02_data/final/df_convite_with_cartel_flags.parquet")
PREGAO_FULL  <- file.path(BASE, "02_data/final/df_pregao_winner_looser.parquet")
PREGAO_FLAGS <- file.path(BASE, "02_data/final/df_pregao_with_cartel_flags.parquet")
OUT_DIR      <- file.path(BASE, "02_data/intermediate")
TABLE_PATH   <- file.path(OUT_DIR, "table1_cartel_split.csv")
REPORT_PATH  <- file.path(OUT_DIR, "table1_cartel_split_report.txt")

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

.sink <- file(REPORT_PATH, open = "wt")
log <- function(...) {
  msg <- paste0(..., collapse = "")
  cat(msg, "\n"); cat(msg, "\n", file = .sink)
}

log("Replicate original Table 1 — with cartel exposure split")
log("Run at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log(strrep("=", 70))

TREAT_YEARS <- 2009:2015
DONUT <- 1e-6
MV_MAX <- 0.10  # close-bid envelope (matches scripts 03/04/06/07)

# ─────────────────────────────────────────────────────────────────────
# Load convite
# ─────────────────────────────────────────────────────────────────────
log("\n[load] full convite + cartel flags...")

cv_full <- read_parquet(CONVITE_FULL,
                        col_select = c("auction_item", "year",
                                       "códigofornecedor",
                                       "MV", "flagvencedor",
                                       "won_previous_market", "last",
                                       "códigoclasse"))
cv_full <- as.data.table(cv_full)
log("  full convite rows: ", format(nrow(cv_full), big.mark = ","))

cv_flags <- as.data.table(read_parquet(CONVITE_FLAGS))
log("  flags rows: ", format(nrow(cv_flags), big.mark = ","))

# Merge: cv_flags is one row per (auction_item, firm), so we join on
# (auction_item, cnpj_full)
cv_full[, cnpj_full := stringr::str_pad(as.character(`códigofornecedor`),
                                          14, pad = "0")]
flags_keys <- cv_flags[, .(auction_item, cnpj_full,
                           cartel_firm, cartel_in_period,
                           has_any_cartel_firm, has_active_cartel,
                           winner_is_cartel_firm, runnerup_is_cartel_firm,
                           both_cartel_firm)]

cv <- merge(cv_full, flags_keys,
            by = c("auction_item", "cnpj_full"),
            all.x = TRUE)
log("  merged rows: ", format(nrow(cv), big.mark = ","))
cv[is.na(has_active_cartel), has_active_cartel := 0L]
cv[is.na(has_any_cartel_firm), has_any_cartel_firm := 0L]

# Restrict treatment window
cv <- cv[year %in% TREAT_YEARS]
log("  after window 2009-2015: ", format(nrow(cv), big.mark = ","))

# Drop ties (donut) and apply close-bid envelope
cv <- cv[abs(MV) >= DONUT]
cv <- cv[abs(MV) < MV_MAX]
log("  after donut + |MV|<", MV_MAX, ": ", format(nrow(cv), big.mark = ","))

# Construct running variable: -MV (positive = won)
cv[, running := -as.numeric(MV)]
cv[, item_class := as.integer(`códigoclasse`)]
cv[is.na(item_class), item_class := 0L]

# Outcome variable types
cv[, was_incumbent := as.numeric(won_previous_market)]
cv[, was_last_bid := as.numeric(last)]

log("  rows ready for RD: ", format(nrow(cv), big.mark = ","))

# ─────────────────────────────────────────────────────────────────────
# RD runner
# ─────────────────────────────────────────────────────────────────────
run_rd <- function(d, y_name, label) {
  idx <- is.finite(d[[y_name]])
  if (sum(idx) < 200) {
    return(data.table(label = label, n = sum(idx),
                      coef = NA_real_, se = NA_real_,
                      p = NA_real_, h = NA_real_,
                      coef_rb = NA_real_, se_rb = NA_real_, p_rb = NA_real_))
  }
  fit <- tryCatch(
    rdrobust(y = d[[y_name]][idx], x = d$running[idx], c = 0,
             cluster = d$item_class[idx],
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) NULL)
  if (is.null(fit)) {
    return(data.table(label = label, n = sum(idx),
                      coef = NA_real_, se = NA_real_,
                      p = NA_real_, h = NA_real_,
                      coef_rb = NA_real_, se_rb = NA_real_, p_rb = NA_real_))
  }
  log(sprintf("  %-50s n=%-7d  coef=%+.4f (SE=%.4f) p=%.4f  h=%.4f",
              label, sum(idx), fit$coef[1,1], fit$se[1,1], fit$pv[1,1],
              fit$bws[1,1]))
  data.table(
    label = label, n = sum(idx),
    coef = fit$coef[1,1], se = fit$se[1,1], p = fit$pv[1,1],
    coef_rb = fit$coef[3,1], se_rb = fit$se[3,1], p_rb = fit$pv[3,1],
    h = fit$bws[1,1]
  )
}

results <- list()

# ─────────────────────────────────────────────────────────────────────
# 1. CONVITE — full sample (replication of original paper)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("1. CONVITE FULL — original paper replication (2009-2015)")
log(strrep("─", 70))

results[[length(results)+1]] <- run_rd(cv, "was_incumbent",
                                        "convite full × incumbent")
results[[length(results)+1]] <- run_rd(cv, "was_last_bid",
                                        "convite full × last bid")

# ─────────────────────────────────────────────────────────────────────
# 2. CONVITE — split by cartel exposure (auction level)
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("2. CONVITE — auction-level cartel split")
log(strrep("─", 70))

# Active cartel
sub_active <- cv[has_active_cartel == 1]
results[[length(results)+1]] <- run_rd(sub_active, "was_incumbent",
                                        "convite cartel-active × incumbent")
results[[length(results)+1]] <- run_rd(sub_active, "was_last_bid",
                                        "convite cartel-active × last bid")

# Cartel firm but outside period
sub_outside <- cv[has_any_cartel_firm == 1 & has_active_cartel == 0]
results[[length(results)+1]] <- run_rd(sub_outside, "was_incumbent",
                                        "convite cartel-firm outside × incumbent")
results[[length(results)+1]] <- run_rd(sub_outside, "was_last_bid",
                                        "convite cartel-firm outside × last bid")

# Clean control
sub_control <- cv[has_any_cartel_firm == 0]
results[[length(results)+1]] <- run_rd(sub_control, "was_incumbent",
                                        "convite clean control × incumbent")
results[[length(results)+1]] <- run_rd(sub_control, "was_last_bid",
                                        "convite clean control × last bid")

# ─────────────────────────────────────────────────────────────────────
# 3. PREGÃO — bring in cartel flags + last + manually-derivable proxies
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("─", 70))
log("3. PREGÃO — last-bid proxy split")
log("   (incumbency requires market+history, computed in separate script)")
log(strrep("─", 70))

# Pregão pair file with cartel flags has only basic columns. We can do
# the cartel-active vs control comparison on the running variable itself
# (= the close-bid jump) for any outcome we have. Skip incumbency for
# pregão here since computing won_previous_market requires the original
# paper's market-definition pipeline.

pg_flags <- as.data.table(read_parquet(PREGAO_FLAGS))
pg_flags <- pg_flags[year %in% TREAT_YEARS]
pg_flags <- pg_flags[abs(MV) >= DONUT & abs(MV) < MV_MAX]
pg_flags[, running := -as.numeric(MV)]

# A reasonable item-class proxy from the cartel sector tag isn't great;
# cluster at firm level instead for pregão.
pg_flags[, cluster_id := .GRP, by = cnpj_raiz]

run_rd_pregao <- function(d, y_name, label) {
  idx <- is.finite(d[[y_name]])
  if (sum(idx) < 200) {
    return(data.table(label = label, n = sum(idx),
                      coef = NA_real_, se = NA_real_,
                      p = NA_real_, h = NA_real_,
                      coef_rb = NA_real_, se_rb = NA_real_, p_rb = NA_real_))
  }
  fit <- tryCatch(
    rdrobust(y = d[[y_name]][idx], x = d$running[idx], c = 0,
             cluster = d$cluster_id[idx],
             kernel = "triangular", p = 1, bwselect = "mserd"),
    error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  log(sprintf("  %-50s n=%-7d  coef=%+.4f (SE=%.4f) p=%.4f  h=%.4f",
              label, sum(idx), fit$coef[1,1], fit$se[1,1], fit$pv[1,1],
              fit$bws[1,1]))
  data.table(label = label, n = sum(idx),
             coef = fit$coef[1,1], se = fit$se[1,1], p = fit$pv[1,1],
             coef_rb = fit$coef[3,1], se_rb = fit$se[3,1], p_rb = fit$pv[3,1],
             h = fit$bws[1,1])
}

# Pregão has flagvencedor (1=winner) which mirrors the "is winner" outcome.
# A null on this is a sanity check (the running variable IS computed from
# winner/loser status, so jumps should be 1 by construction). Skip.

# Real check: does winner_is_cartel_firm depend on running side?
# This is essentially a trivial check (winners are at running > 0 by
# construction). Skip.

# More useful: incumbency-like proxy = runner-up is cartel firm
# This tests whether being on the loser side is correlated with being a
# cartel firm — i.e., a per-side compositional jump.
pg_flags[, runnerup_dummy := as.numeric(runnerup_is_cartel_firm)]
sub_pg_active <- pg_flags[has_active_cartel == 1]
sub_pg_control <- pg_flags[has_any_cartel_firm == 0]

# Skipped — these are mechanical given the construction.

log("  pregão skipped: incumbency requires the original market-definition")
log("  pipeline; will be added in script 16 if needed.")

# ─────────────────────────────────────────────────────────────────────
# 4. Persist
# ─────────────────────────────────────────────────────────────────────
res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, TABLE_PATH)
log("\n[written] ", TABLE_PATH)

# ─────────────────────────────────────────────────────────────────────
# 5. Diagnostic interpretation
# ─────────────────────────────────────────────────────────────────────
log("\n", strrep("=", 70))
log("DIAGNOSTIC")
log(strrep("=", 70))
log("Compare incumbency jumps across subsamples:")
log("  - Story (a) cartel rotation: cartel-active >> clean control")
log("  - Story (b) persistent heterogeneity: all subsamples similar")

inc_full    <- res_dt[label == "convite full × incumbent", coef]
inc_active  <- res_dt[label == "convite cartel-active × incumbent", coef]
inc_outside <- res_dt[label == "convite cartel-firm outside × incumbent", coef]
inc_clean   <- res_dt[label == "convite clean control × incumbent", coef]

log(sprintf("\n  Incumbency jump:"))
log(sprintf("    full sample           : %+.4f", inc_full))
log(sprintf("    cartel-active period  : %+.4f", inc_active))
log(sprintf("    cartel firm outside   : %+.4f", inc_outside))
log(sprintf("    clean control         : %+.4f", inc_clean))
if (!is.na(inc_active) && !is.na(inc_clean)) {
  log(sprintf("\n  Ratio (active/clean): %.2f", inc_active / inc_clean))
  log("  > 1.5 → cartel rotation story plausible")
  log("  ~ 1.0 → persistent heterogeneity story (not cartel-specific)")
}

last_full   <- res_dt[label == "convite full × last bid", coef]
last_active <- res_dt[label == "convite cartel-active × last bid", coef]
last_clean  <- res_dt[label == "convite clean control × last bid", coef]

log(sprintf("\n  Last-bid jump:"))
log(sprintf("    full sample           : %+.4f", last_full))
log(sprintf("    cartel-active period  : %+.4f", last_active))
log(sprintf("    clean control         : %+.4f", last_clean))

log("\nDone.")
close(.sink)
cat("\n[written]", REPORT_PATH, "\n")
