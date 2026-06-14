#!/usr/bin/env Rscript
# 65_first_stage_flow_vs_distance.R
#
# Measurement exhibit: does the exposure rule bite? Holds the 48 PNASH closures,
# the outcome, and the municipality universe fixed and varies only how exposure
# is defined -- flow (>=5% pre-closure admission share to the closing hospital;
# g_emb, 104 municipalities) versus distance (top-3 nearest hospitals; g_km, 129
# municipalities; only 30 in common). g_km is built and validated in 65a.
#
# The first stage is the Poisson count event study on inpatient psychiatric
# admissions (matching script 75), so the comparison is on the denominator-clean
# count, not the pre-2015-sensitive rate. The point: the distance rule treats more
# municipalities, but lower-use ones -- towns near the building rather than the
# towns that used it -- so it both mismeasures who is exposed and dilutes the dose.
#
# Inputs:  02_data/intermediate/g_km_pnash48.parquet  (from 65a)
#          02_data/intermediate/staggered_panel_pnash48_ext.parquet
#          02_data/intermediate/psych_outcomes_panel.parquet
# Outputs: 02_data/processed/first_stage_flow_vs_distance.csv
#          01_manuscript/tables_appendix/table_flow_vs_distance_firststage.tex
#          04_figures/fig_first_stage_flow_vs_distance.pdf
#
# Usage: Rscript 03_analysis/65_first_stage_flow_vs_distance.R [--force]

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
})
setFixest_nthreads(4); setDTthreads(4)

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
FIG   <- file.path(ROOT, "04_figures")
TABA  <- file.path(ROOT, "01_manuscript", "tables_appendix")
LOGF  <- file.path(ROOT, "04_logs", "65_first_stage_flow_vs_distance.log")

force   <- "--force" %in% commandArgs(TRUE)
OUT_CSV <- file.path(PROC, "first_stage_flow_vs_distance.csv")
OUT_TEX <- file.path(TABA, "table_flow_vs_distance_firststage.tex")
OUT_FIG <- file.path(FIG, "fig_first_stage_flow_vs_distance.pdf")
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOGF, append = TRUE) }
cat(sprintf("==== 65_first_stage_flow_vs_distance %s ====\n", Sys.time()), file = LOGF)
if (file.exists(OUT_CSV) && file.exists(OUT_TEX) && file.exists(OUT_FIG) && !force) {
  say("outputs exist, skipping (use --force)"); quit(save = "no") }

GKM <- file.path(INTER, "g_km_pnash48.parquet")
if (!file.exists(GKM)) stop("g_km_pnash48.parquet missing -- run 65a_build_gkm_pnash48.py first")

OK <- "#0072B2"; ORANGE <- "#D55E00"; GREY <- "gray55"
PRE_LO <- -6L

P  <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
po <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
d  <- merge(P[, .(codmun_6, year, g_emb, pop, muni_id)],
            po[, .(codmun_6, year, n_psych_adm)], by = c("codmun_6", "year"), all.x = TRUE)
gkm <- as.data.table(read_parquet(GKM)); gkm[, codmun_6 := as.character(codmun_6)]
d[, codmun_6 := as.character(codmun_6)]
d <- merge(d, gkm[, .(codmun_6, g_km)], by = "codmun_6", all.x = TRUE)
d[, gn_emb := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
d[, gn_km  := ifelse(is.na(g_km)  | g_km  == 0, 10000L, as.integer(g_km))]

n_flow <- uniqueN(d[gn_emb < 10000, codmun_6]); n_dist <- uniqueN(d[gn_km < 10000, codmun_6])
overlap <- uniqueN(intersect(d[gn_emb < 10000, codmun_6], d[gn_km < 10000, codmun_6]))
say("treated: flow=%d distance=%d overlap=%d", n_flow, n_dist, overlap)

# pre-closure psychiatric admission rate per 1,000 by group (their own pre-period,
# clean 2015+ pop only -> denominator-clean cross-sectional descriptor of WHO is treated)
pre_rate <- function(gcol) {
  x <- merge(d[get(gcol) < 10000 & year < get(gcol) & year >= 2015,
               .(codmun_6, year, pop, n_psych_adm)],
             d[, .(codmun_6, year)], by = c("codmun_6", "year"))
  x[is.finite(pop) & pop > 0, 1e3 * sum(n_psych_adm) / sum(pop)]
}
base_flow <- pre_rate("gn_emb"); base_dist <- pre_rate("gn_km")
say("pre-closure psych adm per 1,000 (2015+): flow=%.1f distance=%.1f", base_flow, base_dist)

# Poisson count first stage under each rule (matches script 75)
est <- function(gcol) {
  d2 <- d[is.finite(n_psych_adm)]
  m  <- fepois(as.formula(sprintf("n_psych_adm ~ sunab(%s, year) | muni_id + year", gcol)),
               d2, cluster = "muni_id")
  ag <- summary(m, agg = "att"); att <- as.numeric(coef(ag)[1]); se <- as.numeric(se(ag)[1])
  cf <- coef(m); s <- fixest::se(m); vc <- vcov(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), b = cf[i], se = s[i]) else NULL))[order(e)]
  pre <- es[e <= -2 & e >= PRE_LO]; ii <- which(names(cf) %in% paste0("year::", pre$e))
  W <- as.numeric(t(cf[ii]) %*% solve(vc[ii, ii]) %*% cf[ii]); p <- 1 - pchisq(W, length(ii))
  list(att = att, pct = 100 * (exp(att) - 1),
       lo = 100 * (exp(att - 1.96 * se) - 1), hi = 100 * (exp(att + 1.96 * se) - 1),
       p = p, es = es)
}
flow <- est("gn_emb"); dist <- est("gn_km")
stopifnot(abs(flow$pct - (-54.8)) < 1.5)   # must reproduce script 75's count first stage
say("FLOW  count ATT=%.1f%% CI[%.1f,%.1f] pre-p=%.3f", flow$pct, flow$lo, flow$hi, flow$p)
say("DIST  count ATT=%.1f%% CI[%.1f,%.1f] pre-p=%.3f", dist$pct, dist$lo, dist$hi, dist$p)

fwrite(rbindlist(list(
  data.table(rule = "flow",     n_treated = n_flow, overlap = overlap, base_per1k = base_flow,
             att_pct = flow$pct, ci_lo = flow$lo, ci_hi = flow$hi, pretrend_p = flow$p),
  data.table(rule = "distance", n_treated = n_dist, overlap = overlap, base_per1k = base_dist,
             att_pct = dist$pct, ci_lo = dist$lo, ci_hi = dist$hi, pretrend_p = dist$p))), OUT_CSV)
say("wrote %s", OUT_CSV)

# body macros (self-owned file, input by main.tex)
MAC <- file.path(ROOT, "01_manuscript", "values_measurement.tex")
writeLines(c(
  "% Auto-generated by 03_analysis/65_first_stage_flow_vs_distance.R",
  "% Flow-vs-distance first-stage measurement exhibit (PNASH count Poisson).",
  sprintf("\\newcommand{\\valFDnFlow}{%d}%% flow-rule treated municipalities", n_flow),
  sprintf("\\newcommand{\\valFDnDist}{%d}%% distance-rule treated municipalities", n_dist),
  sprintf("\\newcommand{\\valFDoverlap}{%d}%% municipalities both rules treat", overlap),
  sprintf("\\newcommand{\\valFDbaseFlow}{%.1f}%% flow-treated pre-closure psych adm per 1,000 (2015+)", base_flow),
  sprintf("\\newcommand{\\valFDbaseDist}{%.1f}%% distance-treated pre-closure psych adm per 1,000 (2015+)", base_dist),
  sprintf("\\newcommand{\\valFDflowPct}{%.0f}%% flow-rule first-stage count ATT, |%%|", abs(flow$pct)),
  sprintf("\\newcommand{\\valFDdistPct}{%.0f}%% distance-rule first-stage count ATT, |%%|", abs(dist$pct))
), MAC)
say("wrote %s", MAC)

# ---- composition table (appendix) ----
tab <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{The exposure rule selects different municipalities and a different dose}",
  "\\label{tab:flow-vs-distance-firststage}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Flow rule & Distance rule \\\\",
  " & ($\\geq 5\\%$ admission share) & (top-3 nearest) \\\\",
  "\\midrule",
  sprintf("Treated municipalities & %d & %d \\\\", n_flow, n_dist),
  sprintf("\\quad in common (of %d union) & \\multicolumn{2}{c}{%d} \\\\", n_flow + n_dist - overlap, overlap),
  sprintf("Pre-closure psychiatric admissions per $1{,}000$ & %.1f & %.1f \\\\", base_flow, base_dist),
  sprintf("First-stage ATT (Poisson count) & $%.0f\\%%$ & $%.0f\\%%$ \\\\", flow$pct, dist$pct),
  sprintf("\\quad 95\\%% CI & $[%.0f, %.0f]\\%%$ & $[%.0f, %.0f]\\%%$ \\\\", flow$lo, flow$hi, dist$lo, dist$hi),
  "\\bottomrule",
  sprintf("\\multicolumn{3}{p{0.86\\textwidth}}{\\footnotesize Notes: Same %d PNASH psychiatric closures, outcome, and municipality universe; only the exposure rule differs. The distance rule treats %d municipalities to the flow rule's %d, but the two agree on only %d: it adds %d near-but-low-use towns and drops %d that sent admissions to the closing hospital. Distance-treated municipalities have less than half the pre-closure psychiatric admission rate of flow-treated ones (%.1f versus %.1f per $1{,}000$, clean post-2015 population), direct evidence that most were never the hospital's catchment; averaging them in dilutes the estimated dose. The first stage is the same Poisson count event study used for the headline result.}\\\\",
          48L, n_dist, n_flow, overlap, n_dist - overlap, n_flow - overlap, base_dist, base_flow),
  "\\end{tabular}",
  "\\end{table}", "")
writeLines(tab, OUT_TEX); say("wrote %s", OUT_TEX)

# ---- two-panel count event study (% scale) ----
mk <- function(es, ttl, col) {
  dd <- es[e >= PRE_LO & e <= 8]
  dd[, `:=`(pct = 100 * (exp(b) - 1),
            lo = 100 * (exp(b - 1.96 * se) - 1), hi = 100 * (exp(b + 1.96 * se) - 1))]
  ggplot(dd, aes(e, pct)) +
    geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
    geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, fill = col) +
    geom_pointrange(aes(ymin = lo, ymax = hi), color = col, linewidth = 0.55, size = 0.34) +
    geom_line(color = col, linewidth = 0.4, alpha = 0.55) +
    scale_x_continuous(breaks = seq(-6, 8, 2)) +
    labs(x = "Years since closure", y = "Effect on psychiatric admissions (%)", title = ttl) +
    theme_minimal(base_size = 9.5) +
    theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 9.5, hjust = 0))
}
yl <- c(-75, 35)
g1 <- mk(flow$es, sprintf("Flow rule: %d municipalities (ATT %.0f%%)", n_flow, flow$pct), OK) + coord_cartesian(ylim = yl)
g2 <- mk(dist$es, sprintf("Distance rule: %d municipalities (ATT %.0f%%)", n_dist, dist$pct), ORANGE) + coord_cartesian(ylim = yl)
combo <- if (requireNamespace("patchwork", quietly = TRUE)) patchwork::wrap_plots(g1, g2, nrow = 1) else g1
ggsave(OUT_FIG, combo, width = 8.4, height = 3.7, device = "pdf")
say("wrote %s", OUT_FIG)
say("done")
