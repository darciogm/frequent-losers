#!/usr/bin/env Rscript
# 91_other_hosp_event_study.R
#
# Where the displaced inpatient volume goes. Same staggered Sun-Abraham design as
# the headline first stage (script 75), estimated as Poisson (fepois) count event
# studies with municipality and year fixed effects, on three counts for the treated
# (residence) municipalities: admissions to the closing hospital, admissions to all
# OTHER hospitals, and total admissions anywhere.
#
# Why count, not the per-1,000 rate: the rate divides by municipal population, whose
# pre-2015 values are interpolated (see D1/D4); that denominator both blanks the rate
# before 2015 (no real pre-period) and injects a spurious trend. On the clean counts
# the closing hospital's volume goes to zero, other hospitals pick up only a small
# fraction of it, and total admissions fall -- a partial-absorption, net-loss result,
# not the zero-absorption the truncated rate implied.
#
# Outputs:
#   02_data/processed/other_hosp_event_study.csv
#   01_manuscript/values_displacement.tex  (rewrites valOtherHosp* / valAbsorb* macros)
#   04_figures/fig_es_other_hosp_psych.pdf
#   01_manuscript/tables_appendix/table_other_hosp_es.tex
#
# Usage: Rscript 03_analysis/91_other_hosp_event_study.R [--force]

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
})
setFixest_nthreads(4); setDTthreads(4)

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
FIG   <- file.path(ROOT, "04_figures")
LOGF  <- file.path(ROOT, "04_logs", "91_other_hosp_event_study.log")
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOGF, append = TRUE) }
cat(sprintf("==== 91_other_hosp_event_study %s ====\n", Sys.time()), file = LOGF)

OK <- "#0072B2"; VERM <- "#D55E00"; GREY <- "gray55"

P  <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
oh <- as.data.table(read_parquet(file.path(PROC, "other_hosp_psych_panel.parquet")))
d  <- merge(P[, .(codmun_6, year, g_emb, muni_id)],
            oh[, .(codmun_6, year, psych_adm_total, psych_adm_closing, psych_adm_other)],
            by = c("codmun_6", "year"), all.x = TRUE)
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]

# Poisson count event study; returns ATT (log -> %), CI, dynamic path, pre-trend.
est_pois <- function(yn, dat = d) {
  d2 <- dat[is.finite(get(yn))]
  m  <- fepois(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)), d2, cluster = "muni_id")
  ag <- summary(m, agg = "att"); att <- as.numeric(coef(ag)[1]); se <- as.numeric(se(ag)[1])
  cf <- coef(m); s <- fixest::se(m); vc <- vcov(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), b = cf[i], se = s[i]) else NULL))[order(e)]
  pre <- es[e <= -2 & e >= -6]; ii <- which(names(cf) %in% paste0("year::", pre$e))
  W <- as.numeric(t(cf[ii]) %*% solve(vc[ii, ii]) %*% cf[ii]); p <- 1 - pchisq(W, length(ii))
  sr <- es[e >= 0 & e <= 2, 100 * (exp(mean(b)) - 1)]   # short-run (e0..2) avg % change
  list(att = att, pct = 100 * (exp(att) - 1),
       lo = 100 * (exp(att - 1.96 * se) - 1), hi = 100 * (exp(att + 1.96 * se) - 1),
       p = p, max_pre = max(abs(100 * (exp(pre$b) - 1))), sr = sr, es = es)
}

rt <- est_pois("psych_adm_total")
ro <- est_pois("psych_adm_other")
rc <- est_pois("psych_adm_closing")

# pre-closure treated levels -> absolute decomposition + absorption fraction
tr <- d[gn < 10000 & year < gn & is.finite(psych_adm_total)]
bt <- mean(tr$psych_adm_total); bo <- mean(tr$psych_adm_other); bc <- mean(tr$psych_adm_closing)
dO <- bo * (exp(ro$att) - 1); dC <- bc * (exp(rc$att) - 1)
absorb_frac <- 100 * dO / (-dC)               # rise in other / loss at closing
closing_share <- 100 * bc / bt

say("TOTAL  ATT=%.1f%% CI[%.1f,%.1f] pre-p=%.3f", rt$pct, rt$lo, rt$hi, rt$p)
say("OTHER  ATT=%.1f%% CI[%.1f,%.1f] pre-p=%.3f  short-run(e0-2)=%.0f%%", ro$pct, ro$lo, ro$hi, ro$p, ro$sr)
say("CLOSING ATT=%.1f%% (->0)", rc$pct)
say("pre-closure levels: total=%.0f closing=%.0f(%.0f%%) other=%.0f", bt, bc, closing_share, bo)
say("absorption fraction = rise_other / loss_closing = %.0f%%", absorb_frac)

fwrite(rbindlist(list(
  data.table(spec = "total",   att_log = rt$att, pct = rt$pct, ci_lo = rt$lo, ci_hi = rt$hi, pretrend_p = rt$p, base = bt),
  data.table(spec = "other",   att_log = ro$att, pct = ro$pct, ci_lo = ro$lo, ci_hi = ro$hi, pretrend_p = ro$p, base = bo),
  data.table(spec = "closing", att_log = rc$att, pct = rc$pct, ci_lo = rc$lo, ci_hi = rc$hi, pretrend_p = rc$p, base = bc)
)), file.path(PROC, "other_hosp_event_study.csv"))

# macros (rewrite the valOtherHosp* / valAbsorb* block in values_displacement.tex)
MAC <- file.path(ROOT, "01_manuscript", "values_displacement.tex")
extra <- c(
  sprintf("\\newcommand{\\valOtherHospPct}{%+.0f}%% other-hospital psych adm, Poisson-count ATT (%%)", ro$pct),
  sprintf("\\newcommand{\\valOtherHospLo}{%+.0f}%% CI lower (%%)", ro$lo),
  sprintf("\\newcommand{\\valOtherHospHi}{%+.0f}%% CI upper (%%)", ro$hi),
  sprintf("\\newcommand{\\valOtherHospSR}{%.0f}%% short-run (e0-2) rise, other-hospital (%%)", ro$sr),
  sprintf("\\newcommand{\\valOtherHospPpre}{%.2f}%% other-hospital pre-trend p", ro$p),
  sprintf("\\newcommand{\\valAbsorbFrac}{%.0f}%% absorption fraction: rise in other / loss at closing (%%)", absorb_frac),
  sprintf("\\newcommand{\\valClosingShare}{%.0f}%% closing hospital share of pre-closure treated total (%%)", closing_share)
)
if (file.exists(MAC)) { ln <- readLines(MAC); ln <- ln[!grepl("valOtherHosp|valAbsorbFrac|valClosingShare", ln)] } else ln <- character(0)
writeLines(c(ln, extra), MAC)
say("rewrote valOtherHosp*/valAbsorb* macros in %s", MAC)

# appendix table: the partial-absorption decomposition (Poisson, % effects)
TABA <- file.path(ROOT, "01_manuscript", "tables_appendix", "table_other_hosp_es.tex")
fr <- function(res, lab) sprintf("%s & %+.0f & [%+.0f, %+.0f] & %.2f \\\\", lab, res$pct, res$lo, res$hi, res$p)
tab <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Other hospitals absorb only a small fraction of the displaced inpatient psychiatric volume}",
  "\\label{tab:other-hosp-es}",
  "\\small",
  "\\begin{tabular}{lrrr}",
  "\\toprule",
  "Admissions count (Poisson event study) & ATT (\\%) & 95\\% CI (\\%) & Pre-trend $p$ \\\\",
  "\\midrule",
  fr(rc, "To the closing hospital"),
  fr(ro, "To all other hospitals"),
  fr(rt, "Total (any hospital)"),
  "\\bottomrule",
  sprintf("\\multicolumn{4}{p{0.92\\textwidth}}{\\footnotesize Notes: Staggered Sun-Abraham Poisson event study on admission counts at the municipality of residence, municipality and year fixed effects, by hospital of treatment. The closing hospital handled %.0f\\%% of treated catchments' pre-closure inpatient psychiatric admissions; after closure its volume goes to zero, admissions to other hospitals rise only modestly (recovering about %.0f\\%% of the lost volume), and total admissions fall. Counts, not per-capita rates, because the municipal population denominator is interpolated before 2015.}\\\\",
          closing_share, absorb_frac),
  "\\end{tabular}",
  "\\end{table}", "")
writeLines(tab, TABA)
say("wrote table_other_hosp_es.tex")

# figure: total vs other, % scale
mk <- function(res, lab) { x <- res$es[e >= -6 & e <= 6]
  x[, `:=`(pct = 100 * (exp(b) - 1),
           lo = 100 * (exp(b - 1.96 * se) - 1), hi = 100 * (exp(b + 1.96 * se) - 1), series = lab)]; x }
dd <- rbindlist(list(mk(rt, "Total (any hospital)"), mk(ro, "Other hospitals only")))
g <- ggplot(dd, aes(e, pct, color = series, fill = series)) +
  geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
  geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.10, color = NA) +
  geom_pointrange(aes(ymin = lo, ymax = hi), linewidth = 0.5, size = 0.34,
                  position = position_dodge(width = 0.3)) +
  scale_color_manual(values = c("Total (any hospital)" = VERM, "Other hospitals only" = OK)) +
  scale_fill_manual(values = c("Total (any hospital)" = VERM, "Other hospitals only" = OK)) +
  scale_x_continuous(breaks = seq(-6, 6, 2)) +
  labs(x = "Years since closure", y = "Effect on psychiatric admissions (%)",
       color = NULL, fill = NULL,
       title = "Other hospitals absorb only a small share of the lost volume") +
  theme_minimal(base_size = 9.5) +
  theme(panel.grid.minor = element_blank(), legend.position = c(0.32, 0.16),
        legend.background = element_rect(fill = "white", color = NA),
        plot.title = element_text(size = 10, hjust = 0))
ggsave(file.path(FIG, "fig_es_other_hosp_psych.pdf"), g, width = 5.8, height = 4.0, device = "pdf")
say("wrote fig_es_other_hosp_psych.pdf")
say("done")
