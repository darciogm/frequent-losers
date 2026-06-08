#!/usr/bin/env Rscript
# 45_pnash_cycle_robustness.R
#
# Path2-rest #B3 (parecer Major B3): robustness check restringindo a
# closures dentro de ±1 ano de uma janela PNASH (2007-08, 2011-12,
# 2015-16). PNASH 2002-03 está fora da janela do paper (2010-2024).
#
# Janelas ±1 ano: [2006, 2009] ∪ [2010, 2013] ∪ [2014, 2017]
# Como [2006-09] ∪ [2010-13] = [2006-13] e adjacente a [2014-17],
# efetivamente: [2006, 2017]. Essa é a janela "PNASH-anchored".
#
# Output: 04_logs/45_pnash_cycle.json

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")

cat("==== begin PNASH cycle robustness ====\n")

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))
exo   <- as.data.table(read_parquet(file.path(INTER, "hospital_closures_exogenous.parquet")))

# PNASH window membership for each closure
pnash_cycles <- c(2007, 2008, 2011, 2012, 2015, 2016)
pnash_window <- function(yr) any(abs(yr - pnash_cycles) <= 1)

exo60 <- exo[exogenous == TRUE]
exo60[, pnash_anchored := sapply(year_closure, pnash_window)]
cat(sprintf("F5 closures total: %d  PNASH-anchored: %d  others: %d\n",
            nrow(exo60), sum(exo60$pnash_anchored),
            sum(!exo60$pnash_anchored)))

# Para a robustness: restringir aos closures PNASH-anchored e re-estimar
# Importa: tem que restringir o gname (cohort year) na coluna g_emb a
# anos PNASH-anchored. Se uma muni foi treated por hospital fora desse
# conjunto, ela vira never-treated.
treated_munis_pnash <- unique(panel[g_emb %in% exo60[pnash_anchored == TRUE,
                                                       year_closure],
                                     muni_id])
cat(sprintf("PNASH-anchored treated munis (rough): %d\n",
            length(treated_munis_pnash)))

panel[, gn_pnash := ifelse(g_emb %in% exo60[pnash_anchored == TRUE,
                                              year_closure],
                            as.integer(g_emb), 10000L)]
panel[, gn_full  := ifelse(is.na(g_emb) | g_emb == 0, 10000L,
                            as.integer(g_emb))]

run_att <- function(d, yname, gname_col) {
  d <- d[is.finite(get(yname))]
  fml <- as.formula(sprintf("%s ~ sunab(%s, year) | muni_id + year",
                            yname, gname_col))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) NULL)
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]),
       se  = as.numeric(se(agg)[1]),
       n_treated = d[get(gname_col) < 10000, uniqueN(muni_id)])
}

results <- list()

for (yn in c("travel_burden_km", "icsap_per1k")) {
  for (sn in c("full", "pnash")) {
    gcol <- if (sn == "full") "gn_full" else "gn_pnash"
    r <- run_att(panel, yn, gcol)
    if (is.null(r)) next
    z <- r$att / r$se
    key <- sprintf("%s__%s", sn, yn)
    results[[key]] <- list(
      sample = sn, outcome = yn,
      n_treated = r$n_treated,
      att = r$att, se = r$se, z = z,
      significant_05 = abs(z) >= 1.96
    )
    cat(sprintf("  %s | %-18s | n_t=%3d | ATT=%+7.3f | SE=%5.3f | z=%5.2f | sig: %s\n",
                sn, yn, r$n_treated, r$att, r$se, z,
                ifelse(abs(z) >= 1.96, "YES", "no")))
  }
}

write(toJSON(list(results = results,
                  pnash_cycles = pnash_cycles,
                  pnash_window_radius = 1,
                  n_anchored = sum(exo60$pnash_anchored),
                  n_total = nrow(exo60)),
             auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "45_pnash_cycle.json"))
cat("wrote 45_pnash_cycle.json\n")
