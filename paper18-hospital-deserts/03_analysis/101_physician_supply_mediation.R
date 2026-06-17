#!/usr/bin/env Rscript
# 101_physician_supply_mediation.R
#
# Use #1 (mr-hospital co-author): is the closure -> amenable-mortality effect
# "network isolation" or "just losing doctors"? Merge the national physician
# supply panel (built in paper19-two-deserts, CNES-PF, all 27 UFs, 2015-2023)
# into paper18's staggered panel and re-estimate the headline mortality ATT
# with vs without physician supply.
#
# Three specs, by design — contemporaneous physician supply is a post-treatment
# mediator (bad control). We report it as a *suggestive* decomposition, not a
# clean causal control, and add a baseline-density version that is not a bad
# control.
#   M0  anchor          ATT, no physician term (reproduces headline)
#   M1  mediation probe ATT + contemporaneous medicos_por_1000   [BAD CONTROL — flagged]
#   M2  baseline split  ATT by pre-closure physician-density tercile (clean)
#
# Estimator mirrors 30_event_study_final.R / 55_*: Sun-Abraham, FE muni_id+year,
# cluster muni_id, embedding exposure g_emb.
#
# Outputs (NO manuscript files — paper18 text untouched):
#   04_logs/101_physician_supply_mediation_<stamp>.log
#   02_data/processed/physician_supply_mediation.csv

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(jsonlite)
})

# ---- paths ----
args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
LOG   <- file.path(ROOT, "04_logs")
PHYS  <- "/home/darciogm1/projetos/bitter-pills/paper19-two-deserts/02_data/processed/physician_supply_panel.parquet"

force_run <- "--force" %in% args
csv_out <- file.path(PROC, "physician_supply_mediation.csv")
if (file.exists(csv_out) && !force_run) {
  cat("output exists:", csv_out, "\n  use --force to rerun. skipping.\n"); quit(save = "no")
}

setFixest_nthreads(12); setDTthreads(12)
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_con <- file(file.path(LOG, sprintf("101_physician_supply_mediation_%s.log", stamp)), open = "wt")
say <- function(...) { msg <- sprintf(...); cat(msg, "\n"); cat(msg, "\n", file = log_con) }

# ---- telemetry ----
mem_gb <- tryCatch(as.numeric(system("awk '/MemTotal/{print $2/1048576}' /proc/meminfo", intern = TRUE)), error = function(e) NA)
sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) "NA")
say("==== 101 physician supply mediation ====")
say("host=%s  git=%s  RAM_total=%.1f GiB  threads=12", Sys.info()[["nodename"]], sha, mem_gb)
say("physician panel: %s", PHYS)
t0 <- Sys.time()

stopifnot(file.exists(PHYS))
phys <- as.data.table(read_parquet(PHYS))
phys[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]
say("physician panel: %d rows, %d muni, years %d-%d",
    nrow(phys), uniqueN(phys$codmun_6), min(phys$year), max(phys$year))

# ---- Sun-Abraham ATT helper (mirrors 30_event_study_final.R) ----
run_att <- function(d, yname, extra_rhs = NULL) {
  d <- d[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  rhs <- "sunab(gn_use, year)"
  if (!is.null(extra_rhs)) rhs <- paste(rhs, extra_rhs, sep = " + ")
  fml <- as.formula(sprintf("%s ~ %s | muni_id + year", yname, rhs))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"), error = function(e) { say("  ERR: %s", conditionMessage(e)); NULL })
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]), se = as.numeric(se(agg)[1]),
       n_obs = nrow(d), n_treat = d[gn_use < 10000, uniqueN(muni_id)])
}

# ---- run for each (panel, outcome) ----
# Primary: AMI in-hospital mortality (general amenable proxy, main F5/F6 panels).
# Secondary: population psych mortality (PNASH track) — physician supply is a
# general-medicine control there, so treat as context, not decisive.
JOBS <- list(
  list(panel = "staggered_panel_F5_main.parquet",  outcome = "ami_inhosp_mort_pct", track = "AMI in-hospital mortality (%)"),
  list(panel = "staggered_panel_pnash48.parquet",  outcome = "suicide_per100k",     track = "Suicide per 100k (PNASH)"),
  list(panel = "staggered_panel_pnash48.parquet",  outcome = "selfharm_per100k",    track = "Self-harm per 100k (PNASH)")
)

results <- list()
for (job in JOBS) {
  pf <- file.path(INTER, job$panel)
  if (!file.exists(pf)) { say("skip (no panel): %s", job$panel); next }
  d <- as.data.table(read_parquet(pf))
  if (!job$outcome %in% names(d)) { say("skip (no outcome %s in %s)", job$outcome, job$panel); next }
  d[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]

  say("\n--- %s  [%s | %s] ---", job$track, job$panel, job$outcome)

  # merge physician supply
  d <- merge(d, phys[, .(codmun_6, year, medicos_por_1000, medicos_sus_por_1000, fte, n_medicos, pop_phys = pop)],
             by = c("codmun_6", "year"), all.x = TRUE)

  # baseline (pre-closure) physician density, per municipality, fixed
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  base <- d[gn < 10000 & year < gn & is.finite(medicos_por_1000),
            .(base_phys = mean(medicos_por_1000)), by = muni_id]
  d <- merge(d, base, by = "muni_id", all.x = TRUE)

  # estimation sample where physician supply is observed (apples-to-apples M0 vs M1)
  d_ov <- d[is.finite(medicos_por_1000) & is.finite(get(job$outcome))]

  m0_full <- run_att(d, job$outcome)                                  # headline (full window)
  m0_ov   <- run_att(d_ov, job$outcome)                               # anchor on overlap sample
  m1       <- run_att(d_ov, job$outcome, extra_rhs = "medicos_por_1000") # mediation probe [BAD CONTROL]
  m1b      <- run_att(d_ov, job$outcome, extra_rhs = "log(fte + 1)")     # alt physician term

  if (!is.null(m0_full)) say("  M0 full   ATT=% .5f (SE % .5f)  N=%d  treat=%d", m0_full$att, m0_full$se, m0_full$n_obs, m0_full$n_treat)
  if (!is.null(m0_ov))   say("  M0 overlap ATT=% .5f (SE % .5f)  N=%d  treat=%d", m0_ov$att, m0_ov$se, m0_ov$n_obs, m0_ov$n_treat)
  if (!is.null(m1))      say("  M1 +medico ATT=% .5f (SE % .5f)   [BAD CONTROL — suggestive mediation]", m1$att, m1$se)
  if (!is.null(m0_ov) && !is.null(m1) && m0_ov$att != 0)
    say("    -> share of ATT 'explained' by contemporaneous physician supply: %.1f%%", 100 * (1 - m1$att / m0_ov$att))

  # M2: clean baseline-density tercile split
  qs <- quantile(base$base_phys, c(1/3, 2/3), na.rm = TRUE)
  d_ov[, base_terc := fifelse(base_phys <= qs[1], "T1_low",
                       fifelse(base_phys <= qs[2], "T2_mid", "T3_high"))]
  terc_res <- list()
  for (tc in c("T1_low", "T2_mid", "T3_high")) {
    mt <- run_att(d_ov[base_terc == tc | gn >= 10000], job$outcome)  # keep never-treated as comparison
    if (!is.null(mt)) { say("  M2 %s ATT=% .5f (SE % .5f)  treat=%d", tc, mt$att, mt$se, mt$n_treat); terc_res[[tc]] <- mt }
  }

  pack <- function(spec, r, note = "") if (is.null(r)) NULL else
    data.table(track = job$track, panel = job$panel, outcome = job$outcome,
               spec = spec, att = r$att, se = r$se, n_obs = r$n_obs, n_treat = r$n_treat, note = note)
  results[[length(results) + 1]] <- rbindlist(c(
    list(pack("M0_full", m0_full, "headline window")),
    list(pack("M0_overlap", m0_ov, "anchor, physician-overlap sample")),
    list(pack("M1_medicos_por_1000", m1, "BAD CONTROL: post-treatment mediator")),
    list(pack("M1_log_fte", m1b, "BAD CONTROL: post-treatment mediator")),
    lapply(names(terc_res), function(tc) pack(paste0("M2_baseline_", tc), terc_res[[tc]], "clean: baseline density split"))
  ), use.names = TRUE, fill = TRUE)
}

out <- rbindlist(results, use.names = TRUE, fill = TRUE)
fwrite(out, csv_out)
say("\nwrote %s (%d rows)", csv_out, nrow(out))
say("elapsed: %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))
say("\nREADING GUIDE:")
say("  M0 full vs M0 overlap: how much restricting to 2015-2023 moves the headline.")
say("  M0 overlap vs M1: drop in |ATT| is *suggestive* of mediation via physician")
say("    supply, but M1 is a bad control (supply is itself a closure outcome) — do")
say("    NOT report M1 as the causal estimate. Use #2 (supply as first-stage outcome).")
say("  M2: if ATT concentrates in T1_low (thin baseline supply), the mortality cost")
say("    of closure bites where doctors were already scarce — clean heterogeneity.")
close(log_con)
