#!/usr/bin/env Rscript
# 103_physician_first_stage_honestdid.R
#
# Harden the use-#2 first stage (102): closure -> local physician supply.
# Two robustness layers on the SAME Sun-Abraham spec used in 102:
#   (1) joint pre-trend Wald test  — are all pre-period coefs jointly zero?
#   (2) HonestDiD relative-magnitudes sensitivity (Rambachan-Roth 2023) — does
#       the average post-closure effect survive allowing post-period violations
#       up to Mbar times the worst observed pre-period violation?
#
# Mirrors the extraction/sensitivity pattern of 58_honestdid_mortality_revision.R.
# Unweighted (matches 102, so ATT reproduces). Exposure g_emb, F5_main closures.
#
# Outputs (NO manuscript files):
#   04_logs/103_physician_first_stage_honestdid_<stamp>.log
#   02_data/processed/physician_first_stage_honestdid.csv
#   04_figures/diag_physician_first_stage_honestdid.pdf

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(HonestDiD)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
LOG   <- file.path(ROOT, "04_logs")
FIG   <- file.path(ROOT, "04_figures")
SUPPLY <- "/home/darciogm1/projetos/bitter-pills/paper19-two-deserts/02_data/processed/physician_supply_panel.parquet"

force_run <- "--force" %in% args
csv_out <- file.path(PROC, "physician_first_stage_honestdid.csv")
if (file.exists(csv_out) && !force_run) { cat("output exists; use --force. skipping.\n"); quit(save = "no") }

setFixest_nthreads(12); setDTthreads(12)
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_con <- file(file.path(LOG, sprintf("103_physician_first_stage_honestdid_%s.log", stamp)), open = "wt")
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = log_con) }
sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) "NA")
say("==== 103 physician first-stage hardening ===="); say("host=%s git=%s HonestDiD=%s",
    Sys.info()[["nodename"]], sha, as.character(utils::packageVersion("HonestDiD")))
t0 <- Sys.time()

stopifnot(file.exists(SUPPLY))
supply <- as.data.table(read_parquet(SUPPLY)); supply[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]
panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
panel[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]
d <- merge(panel[, .(muni_id, codmun_6, year, g_emb, pop)],
           supply[, .(codmun_6, year, medicos_por_1000, medicos_sus_por_1000, n_medicos)],
           by = c("codmun_6", "year"), all.x = TRUE)
d[, `:=`(log_n_medicos = log(n_medicos + 1),
         gn_use = ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb)))]

# extract event-study vector + vcov (drop e=-1 reference), per 58
extract_es <- function(fit) {
  cf <- coef(fit); vc <- vcov(fit)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(idx = i, e = as.integer(mm[[i]][2]), cf = cf[i]) else NULL))
  es <- es[order(e)]; keep <- es[e != -1][order(e)]
  list(e = keep$e, betahat = keep$cf, sigma = vc[keep$idx, keep$idx],
       num_pre = sum(keep$e < 0), num_post = sum(keep$e >= 0))
}

run_one <- function(outcome, label) {
  x <- d[is.finite(get(outcome))]
  fit <- feols(as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", outcome)),
               data = x, cluster = "muni_id", warn = FALSE, notes = FALSE)
  att <- summary(fit, agg = "att")
  att_b <- as.numeric(coef(att)[1]); att_s <- as.numeric(se(att)[1])

  # (1) joint pre-trend Wald on all year::-k coefs
  w <- tryCatch(fixest::wald(fit, keep = "^year::-", print = FALSE), error = function(e) NULL)
  w_stat <- if (!is.null(w)) w$stat else NA_real_
  w_p    <- if (!is.null(w)) w$p    else NA_real_

  # (2) HonestDiD relative-magnitudes on average post effect
  es <- extract_es(fit)
  l_vec <- rep(1 / es$num_post, es$num_post)
  m_grid <- c(0, 0.5, 1, 1.5, 2)
  sens <- rbindlist(lapply(m_grid, function(mbar) tryCatch({
    o <- HonestDiD::createSensitivityResults_relativeMagnitudes(
      betahat = es$betahat, sigma = es$sigma, numPrePeriods = es$num_pre,
      numPostPeriods = es$num_post, l_vec = l_vec, Mbarvec = c(mbar), gridPoints = 200)
    data.table(Mbar = mbar, lb = o$lb[1], ub = o$ub[1], status = "ok")
  }, error = function(e) data.table(Mbar = mbar, lb = NA_real_, ub = NA_real_, status = conditionMessage(e)))))

  # breakdown Mbar: largest Mbar whose robust CI still excludes 0
  ok <- sens[status == "ok" & is.finite(lb) & is.finite(ub)]
  excl0 <- ok[(lb > 0 & ub > 0) | (lb < 0 & ub < 0)]
  bd <- if (nrow(excl0) > 0) max(excl0$Mbar) else NA_real_

  say("\n--- %s (%s) ---", label, outcome)
  say("  ATT=% .5f (SE % .5f)  t=% .2f   pre-trend Wald: stat=%.2f p=%.3f",
      att_b, att_s, att_b/att_s, w_stat, w_p)
  for (i in seq_len(nrow(ok))) say("  Mbar=%.1f  robust 95%% CI [% .4f, % .4f]", ok$Mbar[i], ok$lb[i], ok$ub[i])
  say("  breakdown Mbar (CI still excludes 0): %s",
      if (is.na(bd)) "fails even at Mbar=0 (classical CI includes 0)" else sprintf("%.1f", bd))

  list(att = data.table(outcome = outcome, label = label, att = att_b, se = att_s,
                        t = att_b/att_s, pretrend_wald_stat = w_stat, pretrend_wald_p = w_p,
                        num_pre = es$num_pre, num_post = es$num_post, breakdown_Mbar = bd),
       sens = cbind(outcome = outcome, sens))
}

JOBS <- list(c("log_n_medicos","log(N physicians) [primary]"),
             c("medicos_por_1000","Physicians per 1,000"),
             c("medicos_sus_por_1000","SUS physicians per 1,000"))
res <- lapply(JOBS, function(j) run_one(j[1], j[2]))
att <- rbindlist(lapply(res, `[[`, "att"))
sens <- rbindlist(lapply(res, `[[`, "sens"))
fwrite(att, csv_out); fwrite(sens, file.path(PROC, "physician_first_stage_honestdid_sens.csv"))

# diagnostic figure: robust CI vs Mbar, primary outcome
pdf(file.path(FIG, "diag_physician_first_stage_honestdid.pdf"), width = 6.5, height = 4.2)
ok <- sens[outcome == "log_n_medicos" & status == "ok" & is.finite(lb)]
plot(ok$Mbar, ok$lb, type = "b", ylim = range(c(ok$lb, ok$ub, 0)), pch = 16,
     xlab = "Relative-magnitude restriction Mbar", ylab = "Robust 95% CI",
     main = "First stage: closure -> log(N physicians)")
lines(ok$Mbar, ok$ub, type = "b", pch = 16); abline(h = 0, lty = 2, col = "gray40")
dev.off()

say("\nwrote %s + sens + diag figure", csv_out)
say("READING: pre-trend Wald p>0.10 => no joint pre-trend (good). breakdown Mbar")
say("  is how far post-period parallel-trends violations can go before the effect")
say("  loses significance; higher = more robust. Mbar=1 means 'as large as the")
say("  worst pre-period wiggle'.")
say("elapsed: %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))
close(log_con)
