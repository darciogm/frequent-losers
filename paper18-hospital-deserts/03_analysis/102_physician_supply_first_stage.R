#!/usr/bin/env Rscript
# 102_physician_supply_first_stage.R
#
# Use #2 (mr-hospital co-author): does a hospital closure actually reduce the
# LOCAL physician supply? Here physician supply IS the outcome, so there is no
# bad-control problem (cf. 101). This is the clean first stage that tells us
# whether the closure -> mortality channel can run through doctors at all.
#
# If supply / retention drops post-closure -> the 101 baseline-density
# heterogeneity (effect concentrates where doctors were scarce) gets a causal
# mechanism. If it does NOT drop -> that explains why contemporaneous physician
# supply barely moved the ATT in 101, and reframes the story as "network access,
# not headcount".
#
# Estimator mirrors 30_event_study_final.R: Sun-Abraham, FE muni_id+year,
# cluster muni_id, embedding exposure g_emb. Full event-study path reported so
# pre-trends are visible (a pre-closure decline in supply = endogeneity flag).
#
# Outcomes (paper19 CNES-PF panels, national, 2015-2023):
#   supply:   medicos_por_1000, medicos_sus_por_1000, fte, log(n_medicos+1)
#   mobility: net (in-out), retention, n_out
#
# Outputs (NO manuscript files — paper18 text untouched):
#   04_logs/102_physician_supply_first_stage_<stamp>.log
#   02_data/processed/physician_supply_first_stage_att.csv     (ATT per outcome)
#   02_data/processed/physician_supply_first_stage_es.csv      (event-study path)
#   04_figures/diag_physician_first_stage.pdf                  (diagnostic, not a paper float)

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) normalizePath(file.path(dirname(script_arg), "..")) else normalizePath(getwd())
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
LOG   <- file.path(ROOT, "04_logs")
FIG   <- file.path(ROOT, "04_figures")
P19   <- "/home/darciogm1/projetos/bitter-pills/paper19-two-deserts/02_data/processed"
SUPPLY   <- file.path(P19, "physician_supply_panel.parquet")
MOBILITY <- file.path(P19, "physician_mobility_panel.parquet")

force_run <- "--force" %in% args
att_out <- file.path(PROC, "physician_supply_first_stage_att.csv")
if (file.exists(att_out) && !force_run) { cat("output exists; use --force. skipping.\n"); quit(save = "no") }

setFixest_nthreads(12); setDTthreads(12)
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_con <- file(file.path(LOG, sprintf("102_physician_supply_first_stage_%s.log", stamp)), open = "wt")
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = log_con) }

sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) "NA")
say("==== 102 physician supply first stage ====")
say("host=%s git=%s threads=12", Sys.info()[["nodename"]], sha)
t0 <- Sys.time()

stopifnot(file.exists(SUPPLY), file.exists(MOBILITY))
supply <- as.data.table(read_parquet(SUPPLY))
mob    <- as.data.table(read_parquet(MOBILITY))
for (dt in list(supply, mob)) dt[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]

# closure sample / exposure from paper18 headline panel
panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
panel[, `:=`(codmun_6 = as.character(codmun_6), year = as.integer(year))]
panel <- panel[, .(muni_id, codmun_6, uf, year, g_emb, g_km, pop)]

d <- merge(panel, supply[, .(codmun_6, year, medicos_por_1000, medicos_sus_por_1000, fte, n_medicos)],
           by = c("codmun_6", "year"), all.x = TRUE)
d <- merge(d, mob[, .(codmun_6, year, net, retention, n_out, n_in, n_stock)],
           by = c("codmun_6", "year"), all.x = TRUE)
d[, log_n_medicos := log(n_medicos + 1)]
say("merged panel: %d rows, %d muni, years %d-%d", nrow(d), uniqueN(d$muni_id),
    min(d$year), max(d$year))

# ---- Sun-Abraham helper: ATT + event-study path (mirrors 30) ----
run_sunab <- function(dat, yname) {
  x <- dat[is.finite(get(yname))]
  x[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  if (x[gn < 10000, uniqueN(muni_id)] < 3) return(NULL)
  m <- tryCatch(feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yname)),
                      data = x, cluster = "muni_id"),
                error = function(e) { say("  ERR %s: %s", yname, conditionMessage(e)); NULL })
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  cf <- coef(m); s <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- do.call(rbind, lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  if (!is.null(es)) es <- es[order(e)]
  list(att = as.numeric(coef(agg)[1]), se = as.numeric(se(agg)[1]),
       n_obs = nrow(x), n_treat = x[gn < 10000, uniqueN(muni_id)], es = es)
}

OUTCOMES <- list(
  c("medicos_por_1000",     "Physicians per 1,000 (all)"),
  c("medicos_sus_por_1000", "SUS physicians per 1,000"),
  c("fte",                  "Physician FTE"),
  c("log_n_medicos",        "log(N physicians)"),
  c("net",                  "Net physician inflow"),
  c("retention",            "Physician retention rate"),
  c("n_out",                "Physicians leaving (outflow)")
)

att_rows <- list(); es_rows <- list()
for (oc in OUTCOMES) {
  yn <- oc[1]; lab <- oc[2]
  if (!yn %in% names(d)) { say("skip %s (absent)", yn); next }
  r <- run_sunab(d, yn)
  if (is.null(r)) { say("skip %s (no model)", yn); next }
  say("%-26s ATT=% .5f (SE % .5f)  N=%d treat=%d", yn, r$att, r$se, r$n_obs, r$n_treat)
  att_rows[[yn]] <- data.table(outcome = yn, label = lab, att = r$att, se = r$se,
                               tstat = r$att / r$se, n_obs = r$n_obs, n_treat = r$n_treat)
  if (!is.null(r$es)) es_rows[[yn]] <- cbind(outcome = yn, label = lab, r$es)
}

att <- rbindlist(att_rows); es <- rbindlist(es_rows)
fwrite(att, att_out)
fwrite(es, file.path(PROC, "physician_supply_first_stage_es.csv"))
say("\nwrote ATT (%d) + ES (%d) to processed/", nrow(att), nrow(es))

# ---- diagnostic event-study figure (supply + mobility), NOT a paper float ----
if (nrow(es) > 0) {
  pe <- es[e >= -5 & e <= 5]
  pe[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se)]
  p <- ggplot(pe, aes(e, cf)) +
    geom_hline(yintercept = 0, linewidth = 0.3, colour = "grey50") +
    geom_vline(xintercept = -0.5, linetype = 2, linewidth = 0.3, colour = "grey50") +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15) +
    geom_line() + geom_point(size = 1) +
    facet_wrap(~label, scales = "free_y") +
    labs(x = "Years relative to closure", y = "Coefficient (Sun-Abraham)",
         title = "Diagnostic: closure -> local physician supply (first stage)",
         subtitle = "Embedding exposure (g_emb), F5_main closures. Pre-period coefs should be flat.") +
    theme_minimal(base_size = 9)
  ggsave(file.path(FIG, "diag_physician_first_stage.pdf"), p, width = 9, height = 6)
  say("wrote 04_figures/diag_physician_first_stage.pdf")
}

say("\nREADING GUIDE:")
say("  Pre-period (e<0) flat -> no endogenous pre-trend in physician supply (good).")
say("  Post (e>=0): negative ATT on supply/retention/net OR positive on n_out =")
say("    closures push doctors out -> mechanism for 101's baseline-density gradient.")
say("  Null everywhere -> municipal physician stock is sticky; the closure -> mortality")
say("    channel is NOT raw headcount. Either way the paper gets a clean answer.")
say("elapsed: %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))
close(log_con)
