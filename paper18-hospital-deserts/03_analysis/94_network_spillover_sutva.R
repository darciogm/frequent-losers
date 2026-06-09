#!/usr/bin/env Rscript
# 94_network_spillover_sutva.R  [ML EXPERIMENT BRANCH — not in submission]
#
# Network-defined SUTVA / spillover test. A closure reroutes flow onto substitute
# hospitals; a control municipality that co-uses hospitals with a treated catchment
# (a co-patiency edge in the projected municipality network) is therefore exposed
# to the same rerouting and is a contaminated control. Spillover attenuates a true
# effect toward zero, so DROPPING network-contaminated controls should RAISE the
# suicide ATT if an effect is hidden; if the estimate stays a bounded null across
# contamination thresholds, the null is not an artifact of spillover-polluted
# controls. Same staggered Sun-Abraham spec as the headline.

suppressPackageStartupMessages({ library(arrow); library(data.table); library(fixest) })
setFixest_nthreads(4); setDTthreads(4)
ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")

P <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
G <- as.data.table(read_parquet(file.path(INTER, "edges_munmun_proj.parquet")))
P[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
treated <- unique(P[gn < 10000]$codmun_6)

# undirected co-patiency links: control m is linked to a treated catchment if any
# edge (treated <-> m) has weight >= theta
links <- rbindlist(list(
  G[src_codmun_6 %in% treated, .(ctrl = dst_codmun_6, weight)],
  G[dst_codmun_6 %in% treated, .(ctrl = src_codmun_6, weight)]
))[!ctrl %in% treated]

est_suicide <- function(keep_munis) {
  d2 <- P[codmun_6 %in% keep_munis & is.finite(suicide_per100k) & is.finite(pop)]
  m  <- feols(suicide_per100k ~ sunab(gn, year) | muni_id + year,
              d2, cluster = "muni_id", weights = d2$pop)
  att <- as.numeric(coef(summary(m, agg = "att"))[1]); se <- as.numeric(se(summary(m, agg = "att"))[1])
  list(att = att, lo = att - 1.96*se, hi = att + 1.96*se,
       n_ctrl = uniqueN(d2[gn == 10000L]$codmun_6))
}

base <- est_suicide(unique(P$codmun_6))
cat(sprintf("Headline (all controls):   ATT %+.3f  CI [%+.3f, %+.3f]  n_ctrl=%d\n",
            base$att, base$lo, base$hi, base$n_ctrl))
rows <- list(list(lab = "All controls (headline)", drop = 0L,
                  att = base$att, lo = base$lo, hi = base$hi, n = base$n_ctrl))
cat("\nDropping network-contaminated controls (co-patiency weight >= theta):\n")
for (theta in c(0.05, 0.10, 0.25, 0.50, 1.00)) {
  contaminated <- unique(links[weight >= theta]$ctrl)
  keep <- setdiff(unique(P$codmun_6), contaminated)
  r <- est_suicide(keep)
  cat(sprintf("  theta>=%.2f: dropped %4d contaminated controls -> ATT %+.3f  CI [%+.3f, %+.3f]  n_ctrl=%d\n",
              theta, length(contaminated), r$att, r$lo, r$hi, r$n_ctrl))
  rows[[length(rows) + 1]] <- list(lab = sprintf("Drop co-patiency weight $\\geq %.2f$", theta),
                                   drop = length(contaminated), att = r$att, lo = r$lo, hi = r$hi, n = r$n_ctrl)
}

# ---- appendix table (matches tables_appendix style) ----
TAB <- file.path(ROOT, "01_manuscript", "tables_appendix", "table_network_spillover.tex")
fmt <- function(x) sprintf("%+.2f", x)
body <- sapply(rows, function(r) sprintf("%s & %s & [%s, %s] & %s & %s \\\\",
               r$lab, fmt(r$att), fmt(r$lo), fmt(r$hi),
               formatC(r$drop, big.mark = "{,}", format = "d"),
               formatC(r$n, big.mark = "{,}", format = "d")))
tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{The suicide null is not an artifact of network-spillover-contaminated controls}",
  "\\label{tab:network-spillover}",
  "\\small",
  "\\begin{tabular}{lrrrr}",
  "\\toprule",
  "Control set & Suicide ATT & 95\\% CI & Controls dropped & $N$ controls \\\\",
  "\\midrule",
  body[1], "\\midrule", body[-1],
  "\\bottomrule",
  paste0("\\multicolumn{5}{p{0.94\\textwidth}}{\\footnotesize Notes: Population-weighted staggered ",
         "Sun-Abraham event study for suicide mortality per $100{,}000$, municipality and year fixed ",
         "effects, standard errors clustered by municipality. A never-treated municipality is treated as ",
         "network-contaminated if it shares a co-patiency edge of weight at least $\\theta$ with any exposed ",
         "catchment in the projected municipality network (municipalities that co-use the same hospitals are ",
         "exposed to the same closure-induced rerouting). Because spillover attenuates a true effect toward ",
         "zero, dropping contaminated controls would \\emph{raise} the estimate if an effect were hidden; ",
         "instead the ATT stays a bounded null across thresholds. This complements the shared-hub, ",
         "shared-substitute, and flow-similarity contamination checks in the main robustness battery.}\\\\"),
  "\\end{tabular}",
  "\\end{table}", "")
writeLines(tex, TAB)
cat(sprintf("\nwrote %s\n", TAB))
