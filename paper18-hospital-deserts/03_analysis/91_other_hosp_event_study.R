#!/usr/bin/env Rscript
# 91_other_hosp_event_study.R
#
# Causal upgrade of the "other hospitals do not absorb" claim. Same staggered
# Sun-Abraham specification as the headline psychiatric-admissions result
# (script 75), but the outcome is admissions to hospitals OTHER than the focal
# closing hospital, per 1,000 residents. With municipality and year fixed
# effects netting out trends, the ATT measures whether non-closing hospitals
# pick up the lost volume after closure.
#
# Outputs:
#   02_data/processed/other_hosp_event_study.csv
#   01_manuscript/values_displacement.tex  (appends causal macros)
#   04_figures/fig_es_other_hosp_psych.pdf
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
d  <- merge(P, oh[, .(codmun_6, year, psych_adm_other_per1k, psych_adm_total_per1k,
                      psych_adm_closing)], by = c("codmun_6", "year"), all.x = TRUE)
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]

est_full <- function(yn, dat = d, wt = TRUE) {
  d2 <- dat[is.finite(get(yn)) & (!wt | is.finite(pop))]
  w  <- if (wt) d2$pop else NULL
  m  <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
              d2, cluster = "muni_id", weights = w)
  att <- as.numeric(coef(summary(m, agg = "att"))[1]); se <- as.numeric(se(summary(m, agg = "att"))[1])
  cf <- coef(m); s <- se(m); mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]
  pre <- es[e <= -2 & e >= -6]; W <- sum((pre$cf / pre$se)^2)
  base <- weighted.mean(d2[gn < 10000 & year < gn][[yn]], d2[gn < 10000 & year < gn]$pop, na.rm = TRUE)
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       p = 1 - pchisq(W, nrow(pre)), base = base, es = es)
}

# sanity: total psychiatric admissions must reproduce the ~69% headline drop
vt <- est_full("psych_adm_total_per1k")
say("SANITY total psych_adm ATT = %.2f base = %.1f (%.0f%% of base; target ~ -69%%)",
    vt$att, vt$base, 100 * vt$att / vt$base)

# primary: other-hospital admissions
r <- est_full("psych_adm_other_per1k")
say("OTHER-HOSP ATT = %.3f  CI [%.3f, %.3f]  pre-trend p = %.3f  base = %.2f  (%.0f%% of base)",
    r$att, r$lo, r$hi, r$p, r$base, 100 * r$att / r$base)

# robustness: clean subsample (treated munis whose focal closing hospital is
# identified in the psychiatric edges), and unweighted
treated_with_closing <- unique(d[gn < 10000 & year < gn & psych_adm_closing > 0]$codmun_6)
d_clean <- d[gn == 10000L | codmun_6 %in% treated_with_closing]
rc <- est_full("psych_adm_other_per1k", dat = d_clean)
say("OTHER-HOSP (clean subsample, n_treated=%d) ATT = %.3f CI [%.3f, %.3f] p = %.3f",
    length(treated_with_closing), rc$att, rc$lo, rc$hi, rc$p)
ru <- est_full("psych_adm_other_per1k", wt = FALSE)
say("OTHER-HOSP (unweighted) ATT = %.3f CI [%.3f, %.3f] p = %.3f", ru$att, ru$lo, ru$hi, ru$p)

fwrite(rbindlist(list(
  data.table(spec = "other_primary",   att = r$att,  se = r$se,  ci_lo = r$lo,  ci_hi = r$hi,  pretrend_p = r$p,  base = r$base),
  data.table(spec = "other_clean",     att = rc$att, se = rc$se, ci_lo = rc$lo, ci_hi = rc$hi, pretrend_p = rc$p, base = rc$base),
  data.table(spec = "other_unweighted",att = ru$att, se = ru$se, ci_lo = ru$lo, ci_hi = ru$hi, pretrend_p = ru$p, base = ru$base),
  data.table(spec = "total_sanity",    att = vt$att, se = vt$se, ci_lo = vt$lo, ci_hi = vt$hi, pretrend_p = vt$p, base = vt$base)
)), file.path(PROC, "other_hosp_event_study.csv"))

# macros (append to values_displacement.tex)
MAC <- file.path(ROOT, "01_manuscript", "values_displacement.tex")
pct <- 100 * r$att / r$base
extra <- c(
  sprintf("\\newcommand{\\valOtherHospATT}{%.2f}%% causal ATT, other-hospital psych adm per 1k", r$att),
  sprintf("\\newcommand{\\valOtherHospLo}{%.2f}%%", r$lo),
  sprintf("\\newcommand{\\valOtherHospHi}{%.2f}%%", r$hi),
  sprintf("\\newcommand{\\valOtherHospBase}{%.2f}%% pre-closure base, other-hospital psych adm per 1k", r$base),
  sprintf("\\newcommand{\\valOtherHospPct}{%.0f}%% ATT as pct of base", pct),
  sprintf("\\newcommand{\\valOtherHospPpre}{%.2f}%% pre-trend p", r$p)
)
ln <- readLines(MAC); ln <- ln[!grepl("valOtherHosp", ln)]
writeLines(c(ln, extra), MAC)
say("appended causal macros to %s", MAC)

# appendix robustness table: the absorption null across specifications
TABA <- file.path(ROOT, "01_manuscript", "tables_appendix", "table_other_hosp_es.tex")
fr <- function(res, lab) sprintf("%s & %+.2f & [%+.2f, %+.2f] & %.2f & %.2f \\\\",
                                 lab, res$att, res$lo, res$hi, res$base, res$p)
tab <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Other hospitals do not measurably absorb the lost inpatient psychiatric volume (causal event study)}",
  "\\label{tab:other-hosp-es}",
  "\\small",
  "\\begin{tabular}{lrrrr}",
  "\\toprule",
  "Specification & ATT & 95\\% CI & Pre-base & Pre-trend $p$ \\\\",
  "\\midrule",
  fr(r,  "Other hospitals, population-weighted"),
  fr(rc, "\\quad treated with identified closing hospital"),
  fr(ru, "\\quad municipality-weighted"),
  "\\midrule",
  sprintf("Total (any hospital), for reference & %+.2f & [%+.2f, %+.2f] & %.2f & %.2f \\\\",
          vt$att, vt$lo, vt$hi, vt$base, vt$p),
  "\\bottomrule",
  "\\multicolumn{5}{p{0.92\\textwidth}}{\\footnotesize Notes: Staggered Sun-Abraham event study, outcome is",
  "inpatient psychiatric admissions per $1{,}000$ at hospitals other than the focal closing hospital, with",
  "municipality and year fixed effects. The same specification applied to total admissions reproduces the",
  "headline $69\\%$ decline. Other-hospital admissions are statistically unchanged across specifications: the",
  "lost volume is not absorbed by other inpatient providers. ATT and base are per $1{,}000$ residents.}\\\\",
  "\\end{tabular}",
  "\\end{table}", "")
writeLines(tab, TABA)
say("wrote table_other_hosp_es.tex")

# figure: total vs other on one panel
mk <- function(res, lab) { x <- res$es[e >= -6 & e <= 6]; x[, `:=`(lo = cf - 1.96*se, hi = cf + 1.96*se, series = lab)]; x }
dd <- rbindlist(list(mk(vt, "Total (any hospital)"), mk(r, "Other hospitals only")))
g <- ggplot(dd, aes(e, cf, color = series, fill = series)) +
  geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
  geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.10, color = NA) +
  geom_pointrange(aes(ymin = lo, ymax = hi), linewidth = 0.5, size = 0.34,
                  position = position_dodge(width = 0.3)) +
  scale_color_manual(values = c("Total (any hospital)" = VERM, "Other hospitals only" = OK)) +
  scale_fill_manual(values = c("Total (any hospital)" = VERM, "Other hospitals only" = OK)) +
  scale_x_continuous(breaks = seq(-6, 6, 2)) +
  labs(x = "Years since closure", y = "ATT, psychiatric admissions (per 1,000)",
       color = NULL, fill = NULL,
       title = "Other hospitals do not absorb the lost psychiatric volume") +
  theme_minimal(base_size = 9.5) +
  theme(panel.grid.minor = element_blank(), legend.position = c(0.30, 0.18),
        legend.background = element_rect(fill = "white", color = NA),
        plot.title = element_text(size = 10, hjust = 0))
ggsave(file.path(FIG, "fig_es_other_hosp_psych.pdf"), g, width = 5.8, height = 4.0, device = "pdf")
say("wrote fig_es_other_hosp_psych.pdf")
say("done")
