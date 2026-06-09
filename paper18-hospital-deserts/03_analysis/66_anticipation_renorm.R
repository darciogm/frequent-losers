#!/usr/bin/env Rscript
# 66_anticipation_renorm.R
#
# Anticipation robustness: does the event-study reference-period choice (e = -1)
# contaminate the ATT via anticipation? Re-estimate Sun-Abraham with the
# reference period set to e = -2 and e = -3 and check that the aggregated ATT
# is stable.
#
# Mirrors the canonical estimator EXACTLY:
#   m <- feols(<yn> ~ sunab(gn, year, ref.p = <REFP>) | muni_id + year,
#              d, cluster = "muni_id", weights = ~pop)
#   a <- summary(m, agg = "att"); att <- coef(a)[1]; se <- se(a)[1]
#
# fixest 0.13.2: sunab() is resolved inside the formula and accepts ref.p
# directly (signature: sunab(cohort, period, ref.c, ref.p = -1, ...)). The
# re-normalization is therefore done by passing ref.p = c(-2) / c(-3) to sunab,
# which is the documented mechanism. No version workaround needed.
#
# Outputs:
#   02_data/processed/anticipation_renorm.csv
#   04_logs/66_anticipation_renorm.log

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})

# ---- args / paths ----
argv <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% argv

allargs <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", allargs[grepl("--file=", allargs)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }

INTER   <- file.path(ROOT, "02_data", "intermediate")
PROC    <- file.path(ROOT, "02_data", "processed")
LOG_DIR <- file.path(ROOT, "04_logs")
dir.create(PROC, showWarnings = FALSE, recursive = TRUE)
dir.create(LOG_DIR, showWarnings = FALSE, recursive = TRUE)

PANEL   <- file.path(INTER, "staggered_panel_pnash48_ext.parquet")
OUT_CSV <- file.path(PROC, "anticipation_renorm.csv")
LOG     <- file.path(LOG_DIR, "66_anticipation_renorm.log")

# ---- logging ----
con <- file(LOG, open = "wt")
logmsg <- function(...) {
  line <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] ", sprintf(...))
  cat(line, "\n"); cat(line, "\n", file = con)
}

# ---- cache ----
if (file.exists(OUT_CSV) && !FORCE) {
  logmsg("Output exists (%s) and --force not set. Skipping.", OUT_CSV)
  res <- fread(OUT_CSV)
  print(res)
  close(con)
  quit(status = 0)
}

t0 <- Sys.time()

# ---- telemetry ----
setFixest_nthreads(4)
setDTthreads(4)
memline <- tryCatch(system("free -h | awk 'NR==2{print $2\" total, \"$7\" avail\"}'",
                           intern = TRUE), error = function(e) NA_character_)
logmsg("host=%s  fixest_threads=4  dt_threads=%d  cores_avail=%d",
       Sys.info()[["nodename"]], getDTthreads(), parallel::detectCores())
logmsg("RAM: %s", if (length(memline)) memline else "n/a")

# ---- load ----
d_all <- as.data.table(read_parquet(PANEL))
logmsg("Loaded panel: %d rows x %d cols", nrow(d_all), ncol(d_all))

# ---- estimator (mirrors canonical EXACTLY) ----
# yn      : outcome column
# refp    : reference relative period passed to sunab(ref.p=)
# weighted: TRUE -> weights = ~pop, FALSE -> no weights
est <- function(yn, refp, weighted) {
  d <- copy(d_all)
  if (weighted) {
    d <- d[is.finite(get(yn)) & is.finite(pop)]
  } else {
    d <- d[is.finite(get(yn))]
  }
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]

  fml <- as.formula(
    sprintf("%s ~ sunab(gn, year, ref.p = %d) | muni_id + year", yn, refp))

  m <- tryCatch(
    if (weighted) {
      feols(fml, d, cluster = "muni_id", weights = ~pop)
    } else {
      feols(fml, d, cluster = "muni_id")
    },
    error = function(e) { logmsg("ERROR feols %s refp=%d w=%s: %s",
                                 yn, refp, weighted, conditionMessage(e)); NULL })
  if (is.null(m)) {
    return(data.table(outcome = yn, refp = refp, weighted = weighted,
                      att = NA_real_, se = NA_real_, ci_lo = NA_real_,
                      ci_hi = NA_real_, n_obs = NA_integer_, note = "feols failed"))
  }

  # confirm the chosen reference period is omitted (not estimated) and that
  # other event times remain — i.e. refp is usable as the reference.
  ev <- grep("^year::", names(coef(m)), value = TRUE)
  ev_e <- as.integer(sub("^year::", "", ev))
  note <- ""
  if (refp %in% ev_e) {
    note <- sprintf("WARN: refp=%d still estimated (not omitted)", refp)
  }
  if (sum(ev_e < 0) < 1) note <- paste(note, "few pre-periods")

  a  <- summary(m, agg = "att")
  att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  ci  <- tryCatch(as.numeric(confint(a)[1, ]),
                  error = function(e) c(att - 1.96 * se, att + 1.96 * se))

  data.table(outcome = yn, refp = refp, weighted = weighted,
             att = att, se = se, ci_lo = ci[1], ci_hi = ci[2],
             n_obs = m$nobs, note = trimws(note))
}

# ---- run grid ----
results <- rbindlist(list(
  # validation + main weighted grid: suicide & self-harm, refp in {-1,-2,-3}
  est("suicide_per100k",  -1, TRUE),
  est("suicide_per100k",  -2, TRUE),
  est("suicide_per100k",  -3, TRUE),
  est("selfharm_per100k", -1, TRUE),
  est("selfharm_per100k", -2, TRUE),
  est("selfharm_per100k", -3, TRUE),
  # secondary: suicide unweighted, refp in {-1,-2,-3}
  est("suicide_per100k",  -1, FALSE),
  est("suicide_per100k",  -2, FALSE),
  est("suicide_per100k",  -3, FALSE)
))

# round reported numbers to 2 decimals (keep raw too)
results[, `:=`(att = round(att, 4), se = round(se, 4),
               ci_lo = round(ci_lo, 4), ci_hi = round(ci_hi, 4))]

fwrite(results, OUT_CSV)
logmsg("Wrote %s (%d rows)", OUT_CSV, nrow(results))

# ---- validation gate ----
val <- results[outcome == "suicide_per100k" & refp == -1 & weighted == TRUE, att]
logmsg("VALIDATION suicide pop-wt ref.p=-1 ATT = %.4f (target ~ +0.28)", val)
if (is.finite(val) && abs(val - 0.28) < 0.05) {
  logmsg("VALIDATION PASSED.")
} else {
  logmsg("VALIDATION WARNING: ATT deviates from +0.28 target.")
}

print(results[, .(outcome, refp, weighted, att = round(att, 2),
                  se = round(se, 2), ci_lo = round(ci_lo, 2),
                  ci_hi = round(ci_hi, 2), n_obs, note)])

logmsg("Done. Elapsed %.1f s", as.numeric(difftime(Sys.time(), t0, units = "secs")))
close(con)
