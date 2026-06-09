#!/usr/bin/env Rscript
# 67_illdefined_placebo.R
#
# Falsification test for differential death-recording.
#
# Puts the ill-defined-cause death rate (ICD-10 R96-R99 "garbage codes", per
# 100,000) on the LHS of the SAME staggered Sun-Abraham event study used for the
# mortality outcomes. If closure does NOT move the ill-defined-cause rate, then
# misclassification is a level phenomenon absorbed by municipality FE, and
# differential recording is not manufacturing the mortality null.
#
# Spec mirrors D5_make_mortality_results.R exactly:
#   y ~ sunab(gn, year) | muni_id + year, cluster = muni_id, weights = ~pop
#   gn = ifelse(is.na(g_emb) | g_emb == 0, 10000L, g_emb)
#   pre-trend chi-sq on event coefs e in [-6,-2].
#
# STEP 2 validation: reproduce suicide ATT ~ +0.28 (CI ~ [-0.72,+1.29]) first.
# STEP 3: same spec with R96-R99 rate as outcome.
#
# Outcome source: n_r96_r99 column of
#   02_data/intermediate/sim_quality_panel.parquet
#   (built by 03_analysis/02b_build_sim_quality_panel.py from SIM raw CAUSABAS),
# merged to the analysis panel and divided by pop * 1e5.
#
# Output: 02_data/processed/illdefined_placebo.csv
#         04_logs/67_illdefined_placebo.log
# Cache-aware: skips if output exists unless --force.

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})

args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
LOG   <- file.path(ROOT, "04_logs")
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG,  showWarnings = FALSE, recursive = TRUE)

OUT_CSV <- file.path(PROC, "illdefined_placebo.csv")
LOG_FILE <- file.path(LOG, "67_illdefined_placebo.log")

# ---- telemetry / logging ----
con_log <- file(LOG_FILE, open = "wt")
say <- function(...) {
  msg <- paste0(...)
  cat(msg, "\n"); cat(msg, "\n", file = con_log); flush(con_log)
}
t0 <- Sys.time()
say("==== 67_illdefined_placebo ====")
say("host: ", Sys.info()[["nodename"]], "  start: ", format(t0))
say("R: ", R.version.string)

setDTthreads(4L)
setFixest_nthreads(4L)
say("threads: data.table=", getDTthreads(), "  fixest=", getFixest_nthreads())

if (file.exists(OUT_CSV) && !FORCE) {
  say("output exists and --force not set; printing cached and exiting:")
  cached <- fread(OUT_CSV)
  print(cached)
  say(paste(capture.output(print(cached)), collapse = "\n"))
  close(con_log); quit(save = "no", status = 0)
}

# ---- estimator mirroring D5 ----
estimate <- function(d, yn, wt = TRUE) {
  d <- d[is.finite(get(yn)) & (!wt | is.finite(pop))]
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  fml <- as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn))
  m <- if (wt) feols(fml, d, cluster = "muni_id", weights = ~pop)
       else    feols(fml, d, cluster = "muni_id")
  a <- summary(m, agg = "att")
  att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  base <- if (wt) weighted.mean(d[gn < 10000 & year < 2015][[yn]],
                                d[gn < 10000 & year < 2015]$pop, na.rm = TRUE)
          else    mean(d[gn < 10000 & year < 2015][[yn]], na.rm = TRUE)
  cf <- coef(m); s <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2)
      data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0][order(e)]
  pre <- es[e <= -2 & e >= -6]
  W <- sum((pre$cf / pre$se)^2); k <- nrow(pre)
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       base = base, p_pre = 1 - pchisq(W, k),
       n_tr = d[gn < 10000, uniqueN(muni_id)], n_obs = nrow(d), es = es)
}

# ---- load analysis panel ----
P <- file.path(INTER, "staggered_panel_pnash48_ext.parquet")
panel <- as.data.table(read_parquet(P))
say("panel: ", P)
say("  rows=", nrow(panel), "  munis=", panel[, uniqueN(codmun_6)],
    "  years=", paste(range(panel$year), collapse = "-"))

# ============================================================
# STEP 2 — validate on suicide (must reproduce ATT ~ +0.28, CI ~ [-0.72,+1.29])
# ============================================================
say("\n--- STEP 2: validation on suicide_per100k (pop-weighted) ---")
val <- estimate(copy(panel), "suicide_per100k", wt = TRUE)
say(sprintf("  suicide ATT = %+.2f  SE = %.2f  CI = [%+.2f, %+.2f]  n_tr = %d",
            val$att, val$se, val$lo, val$hi, val$n_tr))
match_ok <- abs(val$att - 0.28) < 0.05 &&
            abs(val$lo - (-0.72)) < 0.10 && abs(val$hi - 1.29) < 0.10
say("  matches +0.28 / CI[-0.72,+1.29]? ", if (match_ok) "YES" else "NO")
if (!match_ok) {
  say("!! VALIDATION FAILED — estimator does not reproduce the known suicide ATT.")
  say("!! STOPPING per instructions.")
  close(con_log)
  stop("validation failed")
}

# ============================================================
# STEP 1 — build R96-R99 rate per municipality-year
# ============================================================
say("\n--- STEP 1: build R96-R99 ill-defined-cause rate ---")
QP <- file.path(INTER, "sim_quality_panel.parquet")
q  <- as.data.table(read_parquet(QP))
say("quality panel: ", QP)
say("  rows=", nrow(q), "  years=", paste(range(q$year), collapse = "-"),
    "  has n_r96_r99? ", "n_r96_r99" %in% names(q))
# n_r96_r99 = count of deaths with CAUSABAS in R96..R99 (DECIMAL -> numeric)
q[, n_r96_r99 := as.numeric(n_r96_r99)]
q <- q[, .(codmun_6, year, n_r96_r99)]

# merge to analysis panel on (codmun_6, year); keep panel pop and g_emb
d <- merge(panel, q, by = c("codmun_6", "year"), all.x = TRUE)
n_unmatched <- d[is.na(n_r96_r99), .N]
say("  panel rows: ", nrow(d), "  unmatched (no SIM-quality row): ", n_unmatched,
    "  (expect 2024, outside SIM coverage)")
say("  unmatched years: ",
    paste(sort(unique(d[is.na(n_r96_r99)]$year)), collapse = ","))
# rate per 100,000; unmatched stay NA and are dropped by is.finite filter
d[, illdefined_per100k := n_r96_r99 / pop * 1e5]
say(sprintf("  illdefined_per100k: mean=%.2f  median=%.2f  finite n=%d",
            mean(d$illdefined_per100k, na.rm = TRUE),
            median(d$illdefined_per100k, na.rm = TRUE),
            d[is.finite(illdefined_per100k), .N]))

# ============================================================
# STEP 3 — same spec with R96-R99 rate as outcome (pop-weighted)
# ============================================================
say("\n--- STEP 3: placebo event study on illdefined_per100k (pop-weighted) ---")
plc <- estimate(d, "illdefined_per100k", wt = TRUE)
say(sprintf("  ill-defined ATT = %+.2f  SE = %.2f  CI = [%+.2f, %+.2f]",
            plc$att, plc$se, plc$lo, plc$hi))
say(sprintf("  pre-trend chi-sq p (e in [-6,-2]) = %.2f", plc$p_pre))
say("  pre-period coefficients (e, cf, se):")
pre_coefs <- plc$es[e <= -2 & e >= -6]
for (i in seq_len(nrow(pre_coefs))) {
  say(sprintf("    e=%+d  cf=%+.2f  se=%.2f",
              pre_coefs$e[i], pre_coefs$cf[i], pre_coefs$se[i]))
}
say("  full event-study path (e, cf, se):")
for (i in seq_len(nrow(plc$es))) {
  say(sprintf("    e=%+d  cf=%+.2f  se=%.2f",
              plc$es$e[i], plc$es$cf[i], plc$es$se[i]))
}

# ============================================================
# write CSV
# ============================================================
out <- rbindlist(list(
  data.table(outcome = "suicide_per100k (validation)", att = val$att, se = val$se,
             ci_lo = val$lo, ci_hi = val$hi, p_pretrend = val$p_pre,
             base = val$base, n_treated = val$n_tr, n_obs = val$n_obs,
             source = "panel column"),
  data.table(outcome = "illdefined_per100k (R96-R99 placebo)", att = plc$att, se = plc$se,
             ci_lo = plc$lo, ci_hi = plc$hi, p_pretrend = plc$p_pre,
             base = plc$base, n_treated = plc$n_tr, n_obs = plc$n_obs,
             source = "sim_quality_panel.parquet:n_r96_r99 / pop * 1e5")
))
fwrite(out, OUT_CSV)
say("\nwrote ", OUT_CSV)

# also dump event-study path of the placebo for the record
es_out <- copy(plc$es)
es_out[, outcome := "illdefined_per100k"]
fwrite(es_out, file.path(PROC, "illdefined_placebo_eventstudy.csv"))
say("wrote ", file.path(PROC, "illdefined_placebo_eventstudy.csv"))

say(sprintf("\n==== done ==== elapsed %.1fs",
            as.numeric(Sys.time() - t0, units = "secs")))
close(con_log)
