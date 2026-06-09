#!/usr/bin/env Rscript
# 68_goodman_bacon.R
# Goodman-Bacon (2021) decomposition of the naive TWFE suicide effect.
# Substantiates the paper's claim that TWFE drifts up (+0.72) vs Sun-Abraham
# (+0.28) by quantifying the weight TWFE places on each 2x2 comparison group,
# in particular the "forbidden" already-treated-as-control comparisons.
#
# Primary estimator in the paper is Sun-Abraham; this is a diagnostic.
# bacondecomp requires a BALANCED panel + binary absorbing treatment, and does
# NOT support weights -> the decomposition is run UNWEIGHTED (noted in output).
#
# Usage: Rscript 03_analysis/68_goodman_bacon.R [--force]

suppressMessages({
  library(arrow)
  library(data.table)
  library(fixest)
  library(bacondecomp)
})

t0 <- Sys.time()
args <- commandArgs(trailingOnly = TRUE)
force <- "--force" %in% args

root <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
in_path  <- file.path(root, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")
out_csv  <- file.path(root, "02_data/processed/goodman_bacon_suicide.csv")
log_path <- file.path(root, "04_logs/68_goodman_bacon.log")

dir.create(dirname(out_csv),  showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)

setDTthreads(4)
setFixest_nthreads(4)

con <- file(log_path, open = "wt")
logmsg <- function(...) {
  line <- sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...))
  cat(line, "\n"); cat(line, "\n", file = con); flush(con)
}

logmsg("=== Goodman-Bacon decomposition: suicide_per100k ===")
logmsg("host=", Sys.info()[["nodename"]], " threads=4")
logmsg("RAM total GiB=", round(as.numeric(system("awk '/MemTotal/{print $2}' /proc/meminfo", intern = TRUE)) / 1024^2, 1),
       " free GiB=", round(as.numeric(system("awk '/MemAvailable/{print $2}' /proc/meminfo", intern = TRUE)) / 1024^2, 1))

if (file.exists(out_csv) && !force) {
  logmsg("Output exists and --force not set; skipping. ", out_csv)
  cat(readLines(out_csv), sep = "\n")
  quit(status = 0)
}

# ---- Load ----------------------------------------------------------------
d <- as.data.table(read_parquet(in_path))
orig_rows <- nrow(d)
orig_munis <- uniqueN(d$muni_id)
logmsg("loaded rows=", orig_rows, " muni_id=", orig_munis,
       " years=", uniqueN(d$year))

# ---- Build binary staggered treatment ------------------------------------
# never-treated (g_emb 0 or NA) coded as 10000 so it never switches on.
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
d[, treat := as.integer(gn < 10000L & year >= gn)]

n_nevertreated <- d[, uniqueN(muni_id[gn == 10000L])]
logmsg("never-treated munis=", n_nevertreated,
       " treated cohorts=", paste(sort(unique(d$gn[d$gn < 10000L])), collapse = ","))

# ---- Handle missing outcome ----------------------------------------------
# bacon() rejects NA outcomes. suicide_per100k is unpopulated for the final
# data year (2024 mortality not yet released) -> drop years with no coverage,
# then drop any muni with a residual NA (would break balance otherwise).
yr_cov <- d[, .(non_na = sum(!is.na(suicide_per100k)), n = .N), by = year][order(year)]
drop_years <- yr_cov[non_na == 0, year]
if (length(drop_years) > 0) {
  logmsg("dropping year(s) with zero outcome coverage: ", paste(drop_years, collapse = ","))
  d <- d[!year %in% drop_years]
}
na_munis <- d[is.na(suicide_per100k), unique(muni_id)]
if (length(na_munis) > 0) {
  logmsg("dropping ", length(na_munis), " muni(s) with residual NA suicide_per100k: ",
         paste(na_munis, collapse = ","))
  d <- d[!muni_id %in% na_munis]
}
stopifnot(sum(is.na(d$suicide_per100k)) == 0)

# ---- Balance the panel ---------------------------------------------------
# bacon() requires every muni_id observed in every year.
n_years <- uniqueN(d$year)
obs_per <- d[, .(n = .N), by = muni_id]
keep    <- obs_per[n == n_years, muni_id]
dropped <- obs_per[n != n_years]

n_muni_before <- uniqueN(d$muni_id)
rows_before   <- nrow(d)
d <- d[muni_id %in% keep]
rows_after    <- nrow(d)
n_muni_after  <- uniqueN(d$muni_id)

logmsg("balance: munis ", n_muni_before, " -> ", n_muni_after,
       " (dropped ", n_muni_before - n_muni_after, " munis)")
logmsg("balance: rows ", rows_before, " -> ", rows_after,
       " (dropped ", rows_before - rows_after, " muni-years at balance step)")
logmsg("TOTAL muni-years dropped from original ", orig_rows, " -> ", rows_after,
       " = ", orig_rows - rows_after, " (NA-handling + balancing); munis ",
       orig_munis, " -> ", n_muni_after)
if (nrow(dropped) > 0) {
  logmsg("dropped munis obs-count distribution: ",
         paste(capture.output(print(dropped[, .N, by = n][order(n)])), collapse = " | "))
}

# ---- Verify treatment is absorbing (no switch-off) -----------------------
setorder(d, muni_id, year)
switchoff <- d[, .(off = any(diff(treat) < 0)), by = muni_id][off == TRUE]
logmsg("treatment switch-off munis (should be 0)=", nrow(switchoff))
if (nrow(switchoff) > 0) stop("Treatment switches off; not absorbing — bacon() invalid.")

# ---- STEP 1: validate naive TWFE -----------------------------------------
m_w <- feols(suicide_per100k ~ treat | muni_id + year, d,
             cluster = "muni_id", weights = ~pop)
m_u <- feols(suicide_per100k ~ treat | muni_id + year, d,
             cluster = "muni_id")
att_w <- coef(m_w)[["treat"]]
att_u <- coef(m_u)[["treat"]]
logmsg(sprintf("TWFE weighted   ATT (treat) = %+.4f  (se %.4f)", att_w, se(m_w)[["treat"]]))
logmsg(sprintf("TWFE unweighted ATT (treat) = %+.4f  (se %.4f)", att_u, se(m_u)[["treat"]]))
logmsg(sprintf("paper naive-TWFE benchmark  = +0.72   | weighted near 0.72? %s",
               ifelse(abs(att_w - 0.72) < 0.10, "YES", "NO")))

# ---- STEP 2: Goodman-Bacon decomposition ---------------------------------
# bacon() has no weights arg -> UNWEIGHTED. Compare to unweighted TWFE.
#
# IMPLEMENTATION NOTE: bacondecomp::bacon() estimates each 2x2 via
#   lm(outcome ~ treated + factor(time) + factor(id))
# With ~5,500 muni dummies, that dense design makes each of the 21 pairwise
# regressions take minutes (a single full bacon() run exceeded 30 min and did
# not finish within budget). We therefore reuse bacon's EXACT grouping and
# weight formulas (the package's own un-exported helpers, called verbatim) and
# replace ONLY the per-2x2 point estimate with fixest::feols(outcome ~ treated |
# id + time). That feols absorbs the two-way FEs and returns the IDENTICAL OLS
# 'treated' coefficient as bacon's lm() — same Goodman-Bacon (2021) estimand,
# just a faster estimation engine. We then cross-check the implied
# weighted-average against the actual unweighted TWFE (must match).
bdns <- getNamespace("bacondecomp")

# Reproduce bacon()'s no-control branch using package helpers + feols.
dat <- as.data.frame(d[, .(id = muni_id, time = year,
                           outcome = suicide_per100k, treated = treat)])
tgc <- bdns$create_treatment_groups(dat, control_vars = character(0),
                                    return_merged_df = TRUE)
two_by_twos <- tgc$two_by_twos
dat <- tgc$data

logmsg("computing ", nrow(two_by_twos), " 2x2 estimates via feols (FE-absorbed) ...")
for (i in seq_len(nrow(two_by_twos))) {
  tg <- two_by_twos[i, "treated"]
  ug <- two_by_twos[i, "untreated"]
  d1 <- bdns$subset_data(dat, tg, ug)
  w  <- bdns$calculate_weights(d1, treated_group = tg, untreated_group = ug)
  est <- coef(feols(outcome ~ treated | id + time, data = d1,
                    notes = FALSE))[["treated"]]
  two_by_twos[i, "estimate"] <- est
  two_by_twos[i, "weight"]   <- w
}
two_by_twos <- bdns$scale_weights(two_by_twos)
logmsg("feols 2x2 loop done")

bdt <- as.data.table(two_by_twos)
# Map bacon 'type' labels to interpretable comparison groups.
# bacondecomp emits: "Earlier vs Later Treated", "Later vs Earlier Treated",
# "Treated vs Untreated".
grp <- bdt[, .(weight = sum(weight),
               avg_estimate = weighted.mean(estimate, weight)), by = type]
setnames(grp, "type", "comparison_group")

# Weighted-average TWFE implied by the decomposition (sanity check vs unweighted TWFE).
twfe_implied <- bdt[, weighted.mean(estimate, weight)]
logmsg(sprintf("bacon implied weighted-avg estimate = %+.4f (should match unweighted TWFE %+.4f)",
               twfe_implied, att_u))

# Identify weights on the two key buckets.
w_nevertreated <- grp[comparison_group == "Treated vs Untreated", sum(weight)]
w_forbidden    <- grp[comparison_group == "Later vs Earlier Treated", sum(weight)]
w_earlier_late <- grp[comparison_group == "Earlier vs Later Treated", sum(weight)]
total_w        <- grp[, sum(weight)]

logmsg("--- DECOMPOSITION (weights normalised to ", round(total_w, 3), ") ---")
for (i in seq_len(nrow(grp))) {
  logmsg(sprintf("  %-28s weight=%.3f  avg.est=%+.2f",
                 grp$comparison_group[i], grp$weight[i], grp$avg_estimate[i]))
}
logmsg(sprintf("weight on never-treated (Treated vs Untreated)      = %.3f", w_nevertreated))
logmsg(sprintf("weight on FORBIDDEN (Later vs Earlier, already-trt) = %.3f", w_forbidden))
logmsg(sprintf("weight on Earlier vs Later treated                  = %.3f", w_earlier_late))

# ---- Assemble output -----------------------------------------------------
out <- rbindlist(list(
  grp[, .(comparison_group, weight = round(weight, 4),
          avg_estimate = round(avg_estimate, 4))],
  data.table(comparison_group = "TWFE_implied_weighted_avg",
             weight = round(total_w, 4), avg_estimate = round(twfe_implied, 4)),
  data.table(comparison_group = "TWFE_unweighted_actual",
             weight = NA_real_, avg_estimate = round(att_u, 4)),
  data.table(comparison_group = "TWFE_weighted_by_pop_actual",
             weight = NA_real_, avg_estimate = round(att_w, 4))
))
out[, weights_used := "UNWEIGHTED (bacon() has no weights arg)"]
out[, panel_balanced_munis := n_muni_after]
out[, panel_years := n_years]
out[, muni_years_dropped := orig_rows - rows_after]

fwrite(out, out_csv)
logmsg("wrote ", out_csv)
logmsg(sprintf("done in %.1f s", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
close(con)

cat("\n===== goodman_bacon_suicide.csv =====\n")
print(out)
