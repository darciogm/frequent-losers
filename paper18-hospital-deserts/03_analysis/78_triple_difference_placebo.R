#!/usr/bin/env Rscript
# 78_triple_difference_placebo.R
# Triple-difference (DDD) sharpening for the staggered Sun-Abraham event study of
# 48 PNASH psychiatric-hospital closures on suicide / self-harm mortality.
#
# Logic: the plain DiD differences out muni + year FE but not muni-specific
# mortality shocks correlated with closure timing. We add a within-muni
# comparison against a PLACEBO cause of death (AMI / acute myocardial infarction)
# that a psychiatric inpatient closure should NOT move, but that responds to the
# same local economic / health-system shocks. If the suicide effect net of the
# placebo trend is still a tight null, the result is sharper.
#
# Placebo = AMI (cardiovascular). Largest count among available causes
# (most precise rates), responsive to local deprivation / SUS quality, but with
# no clinical pathway from a psychiatric-bed closure to acute cardiac death.
# Sepsis avoided (general inpatient-capacity proxy); maternal/perinatal too thin.
#
# Cache-aware: skips if output exists unless --force.

suppressMessages({
  library(duckdb); library(DBI); library(data.table); library(fixest)
})

setFixest_nthreads(6); setDTthreads(6)

args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args

ROOT      <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
PANEL_FP  <- file.path(ROOT, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")
CAUSE_FP  <- file.path(ROOT, "02_data/intermediate/cause_specific_mortality.parquet")
OUT_FP    <- file.path(ROOT, "02_data/processed/triple_difference_placebo.csv")
LOG_FP    <- file.path(ROOT, "04_logs/78_triple_difference_placebo.log")
PLACEBO   <- "ami"

# ---- telemetry ----
logcon <- file(LOG_FP, open = "wt")
log <- function(...) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(..., collapse = ""))
  cat(msg, "\n"); cat(msg, "\n", file = logcon); flush(logcon)
}
rss <- function() {
  kb <- tryCatch(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE)),
                 error = function(e) NA)
  sprintf("%.2f GiB", kb / 1024 / 1024)
}
t0 <- Sys.time()
log("=== 78_triple_difference_placebo ===")
log("host=", Sys.info()[["nodename"]], " threads=6 placebo=", PLACEBO)
log("RAM total: ", system("free -g | awk 'NR==2{print $2}'", intern = TRUE), " GiB; ",
    "free: ", system("free -g | awk 'NR==2{print $7}'", intern = TRUE), " GiB")

if (file.exists(OUT_FP) && !FORCE) {
  log("Output exists and --force not set; skipping. ", OUT_FP)
  log("Re-run with --force to recompute.")
  close(logcon); quit(status = 0)
}

ci2 <- function(x) sprintf("%.2f", x)

# ---- load panel ----
log("Loading panel + placebo cause via DuckDB...")
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=6")

# Panel: keep the SA estimation window. Build gn here.
panel <- as.data.table(dbGetQuery(con, sprintf("
  SELECT codmun_6, uf, year, g_emb, muni_id, suicide_per100k, selfharm_per100k, pop
  FROM read_parquet('%s')
", PANEL_FP)))

# Placebo deaths joined onto panel; fill zeros for muni-years without the cause,
# recompute rate using panel pop (cause-file pop is frequently NA).
plc <- as.data.table(dbGetQuery(con, sprintf("
  SELECT codmun_6, year, n_deaths
  FROM read_parquet('%s')
  WHERE cause = '%s'
", CAUSE_FP, PLACEBO)))
dbDisconnect(con, shutdown = TRUE)

log("panel rows=", nrow(panel), " placebo cause rows=", nrow(plc), " RSS=", rss())

panel[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]

# merge placebo deaths; missing -> 0 deaths
plc[, year := as.integer(year)]
panel[, year := as.integer(year)]
panel <- merge(panel, plc, by = c("codmun_6", "year"), all.x = TRUE)
panel[is.na(n_deaths), n_deaths := 0]
panel[, placebo_per100k := ifelse(pop > 0, n_deaths * 100000.0 / pop, NA_real_)]

# relative event time for the DDD interaction layer; never-treated parked at -1000
panel[, rel := ifelse(gn == 10000L, -1000L, year - gn)]

log("merged. placebo missing/zero-pop rows dropped in models. RSS=", rss())

results <- list()

# ============================================================
# STEP 1 — VALIDATE: pop-weighted SA suicide ATT ~ +0.28, CI ~[-0.72,+1.29]
# ============================================================
log("STEP 1: validating suicide SA ATT...")
d <- panel[!is.na(suicide_per100k) & !is.na(pop) & pop > 0]
m_sui <- feols(suicide_per100k ~ sunab(gn, year) | muni_id + year,
               data = d, cluster = "muni_id", weights = ~pop)
att_sui <- summary(m_sui, agg = "att")
att_sui_co <- att_sui$coeftable["ATT", ]
sui_est <- att_sui_co[["Estimate"]]
sui_se  <- att_sui_co[["Std. Error"]]
sui_lo  <- sui_est - 1.96 * sui_se
sui_hi  <- sui_est + 1.96 * sui_se
log(sprintf("  suicide ATT = %.2f  SE=%.2f  CI=[%.2f, %.2f]", sui_est, sui_se, sui_lo, sui_hi))

# pre-trend p: joint test of the SA pre-period (negative relative-time) coefs.
# sunab labels them "year::-k". Exclude the reference (-1, dropped) automatically.
pretrend_p <- function(model) {
  nm  <- names(coef(model))
  pre <- grep("^year::-[0-9]", nm, value = TRUE)
  if (length(pre) == 0) return(NA_real_)
  tryCatch(as.numeric(wald(model, keep = "^year::-[0-9]")[["p"]]), error = function(e) NA_real_)
}
sui_pre_p <- pretrend_p(m_sui)
log(sprintf("  suicide pre-trend joint p = %s", ifelse(is.na(sui_pre_p), "NA", ci2(sui_pre_p))))

VALID_OK <- (sui_est > 0.10 && sui_est < 0.45 && sui_lo < -0.4 && sui_hi > 1.0)
if (!VALID_OK) {
  log("!! VALIDATION FAILED: ATT/CI does not reproduce ~+0.28 / [-0.72,+1.29]. STOPPING.")
  results[["validation"]] <- data.table(quantity = "suicide_ATT_validation",
                                         estimate = round(sui_est,2), se = round(sui_se,2),
                                         ci_lo = round(sui_lo,2), ci_hi = round(sui_hi,2),
                                         pretrend_p = round(sui_pre_p,2), status = "FAILED")
  fwrite(rbindlist(results, fill = TRUE), OUT_FP)
  close(logcon); quit(status = 1)
}
log("  VALIDATION PASSED.")
results[["validate_suicide"]] <- data.table(
  quantity = "suicide_ATT (plain SA, validation)",
  estimate = round(sui_est,2), se = round(sui_se,2),
  ci_lo = round(sui_lo,2), ci_hi = round(sui_hi,2),
  pretrend_p = round(sui_pre_p,2), status = "PASS")

# ============================================================
# STEP 2 — placebo outcome on SAME SA spec
# ============================================================
log("STEP 2: placebo (AMI) SA ATT...")
dp <- panel[!is.na(placebo_per100k) & !is.na(pop) & pop > 0]
m_plc <- feols(placebo_per100k ~ sunab(gn, year) | muni_id + year,
               data = dp, cluster = "muni_id", weights = ~pop)
att_plc <- summary(m_plc, agg = "att")$coeftable["ATT", ]
plc_est <- att_plc[["Estimate"]]; plc_se <- att_plc[["Std. Error"]]
plc_lo <- plc_est - 1.96*plc_se; plc_hi <- plc_est + 1.96*plc_se
plc_pre_p <- pretrend_p(m_plc)
log(sprintf("  placebo(AMI) ATT = %.2f  SE=%.2f  CI=[%.2f, %.2f]  pretrend p=%s",
            plc_est, plc_se, plc_lo, plc_hi, ifelse(is.na(plc_pre_p),"NA",ci2(plc_pre_p))))
results[["placebo_ami"]] <- data.table(
  quantity = "placebo_ATT (AMI, plain SA)",
  estimate = round(plc_est,2), se = round(plc_se,2),
  ci_lo = round(plc_lo,2), ci_hi = round(plc_hi,2),
  pretrend_p = round(plc_pre_p,2), status = "-")

# ============================================================
# STEP 3 — DDD: stack treated outcome + placebo, psych=1 on treated rows.
#   muni-by-outcome and year-by-outcome FE absorb level/trend differences
#   between the two causes; the SA terms interacted with psych give the
#   triple-difference (suicide effect net of placebo).
# ============================================================
# DDD construction (stacked, Sun-Abraham aware):
#   - psych=1 rows carry the treated outcome (suicide/self-harm), psych=0 the placebo (AMI).
#   - sunab(gn,year) gives the cohort-robust event path of the PLACEBO (psych=0 base).
#   - i(rel, psych) adds the within-muni DIFFERENCE between treated and placebo
#     around the event = the triple difference event path.
#   - muni^psych and year^psych FE absorb cause-specific levels and common shocks.
#   The DDD ATT = mean of the post-period i(rel,psych) coefficients (rel>=0),
#   tested jointly via a linear hypothesis to get a proper clustered SE/CI.
# (sunab cannot itself be interacted with a covariate in fixest, so the DDD
#  layer uses a two-way relative-time interaction; cohort-robustness is retained
#  on the base treatment timing via sunab.)
ddd_run <- function(treated_var, label) {
  log(sprintf("STEP 3: DDD for %s vs placebo(AMI)...", label))
  base <- panel[!is.na(get(treated_var)) & !is.na(placebo_per100k) & !is.na(pop) & pop > 0]
  treated <- base[, .(muni_id, gn, year, rel, pop, rate = get(treated_var))][, psych := 1L]
  placebo <- base[, .(muni_id, gn, year, rel, pop, rate = placebo_per100k)][, psych := 0L]
  stk <- rbindlist(list(treated, placebo))
  m <- feols(rate ~ sunab(gn, year) + i(rel, psych, ref = c(-1, -1000)) |
               muni_id^psych + year^psych,
             data = stk, cluster = "muni_id", weights = ~pop)
  bfull <- coef(m)
  V     <- vcov(m)                                   # clustered (muni_id)
  common <- intersect(names(bfull), colnames(V))     # drop any NA / collinear terms
  common <- common[!is.na(bfull[common])]
  b   <- bfull[common]
  V   <- V[common, common, drop = FALSE]
  post <- grep("^rel::([0-9]|1[0-9]):psych$", common, value = TRUE)   # rel>=0 interactions
  # DDD ATT = simple average of post-period interaction coefs; clustered SE via lincom
  w <- setNames(rep(0, length(common)), common)
  w[post] <- 1 / length(post)
  est <- as.numeric(w %*% b)
  se  <- as.numeric(sqrt(t(w) %*% V %*% w))
  lo <- est - 1.96*se; hi <- est + 1.96*se
  # DDD pre-trend joint test on the interaction pre-coefs
  ddd_pre_p <- tryCatch(as.numeric(wald(m, keep = "^rel::-[0-9]+:psych$")[["p"]]),
                        error = function(e) NA_real_)
  log(sprintf("  DDD %s ATT(net of AMI) = %.2f  SE=%.2f  CI=[%.2f, %.2f]  DDD-pretrend p=%s",
              label, est, se, lo, hi, ifelse(is.na(ddd_pre_p),"NA",ci2(ddd_pre_p))))
  list(est = est, se = se, lo = lo, hi = hi, pre_p = ddd_pre_p, model = m)
}

ddd_sui <- ddd_run("suicide_per100k", "suicide")
results[["ddd_suicide"]] <- data.table(
  quantity = "DDD_ATT suicide (net of AMI)",
  estimate = round(ddd_sui$est,2), se = round(ddd_sui$se,2),
  ci_lo = round(ddd_sui$lo,2), ci_hi = round(ddd_sui$hi,2),
  pretrend_p = round(ddd_sui$pre_p,2), status = "-")

# self-harm DDD
log("STEP 1b: validating self-harm plain SA ATT...")
dsh <- panel[!is.na(selfharm_per100k) & !is.na(pop) & pop > 0]
m_sh <- feols(selfharm_per100k ~ sunab(gn, year) | muni_id + year,
              data = dsh, cluster = "muni_id", weights = ~pop)
att_sh <- summary(m_sh, agg = "att")$coeftable["ATT", ]
sh_est <- att_sh[["Estimate"]]; sh_se <- att_sh[["Std. Error"]]
sh_lo <- sh_est - 1.96*sh_se; sh_hi <- sh_est + 1.96*sh_se
log(sprintf("  self-harm plain ATT = %.2f  SE=%.2f  CI=[%.2f, %.2f]", sh_est, sh_se, sh_lo, sh_hi))
results[["plain_selfharm"]] <- data.table(
  quantity = "selfharm_ATT (plain SA)",
  estimate = round(sh_est,2), se = round(sh_se,2),
  ci_lo = round(sh_lo,2), ci_hi = round(sh_hi,2),
  pretrend_p = round(pretrend_p(m_sh),2), status = "-")

ddd_sh <- ddd_run("selfharm_per100k", "self-harm")
results[["ddd_selfharm"]] <- data.table(
  quantity = "DDD_ATT self-harm (net of AMI)",
  estimate = round(ddd_sh$est,2), se = round(ddd_sh$se,2),
  ci_lo = round(ddd_sh$lo,2), ci_hi = round(ddd_sh$hi,2),
  pretrend_p = round(ddd_sh$pre_p,2), status = "-")

# ============================================================
# STEP 4 — VERDICT
# ============================================================
tight_null <- function(est, lo, hi) abs(est) < 1.0 && lo < 0 && hi > 0 && (hi - lo) < 4.0
plc_moves  <- abs(plc_est) > 2.0 || plc_lo > 0 || plc_hi < 0

verdict <- if (plc_moves) {
  "THREAT-FOUND-or-INCONCLUSIVE: placebo (AMI) ATT is non-trivial -> local mortality shocks move with closure timing."
} else if (tight_null(ddd_sui$est, ddd_sui$lo, ddd_sui$hi)) {
  "STRENGTHEN: suicide effect net of placebo remains a tight null."
} else {
  "INCONCLUSIVE: DDD null not tight."
}
log("STEP 4 VERDICT: ", verdict)

results[["verdict"]] <- data.table(
  quantity = "VERDICT", estimate = NA_real_, se = NA_real_,
  ci_lo = NA_real_, ci_hi = NA_real_, pretrend_p = NA_real_, status = verdict)

out <- rbindlist(results, fill = TRUE)
fwrite(out, OUT_FP)
log("Wrote ", OUT_FP)
log(sprintf("Done. elapsed=%.1f s  RSS=%s", as.numeric(difftime(Sys.time(), t0, units="secs")), rss()))
print(out)
close(logcon)
