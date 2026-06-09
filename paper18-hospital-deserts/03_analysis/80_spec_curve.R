#!/usr/bin/env Rscript
# 80_spec_curve.R
#
# Specification curve for the suicide ATT, assembled from estimates already
# produced elsewhere (values.tex macros + processed CSVs). NO new estimation:
# this is a presentation layer that consolidates the robustness battery into
# one ordered multiverse plot, so a reader sees at a glance that the null is
# not specification-dependent.
#
# Output: 04_figures/fig_spec_curve_suicide.pdf
#         02_data/processed/spec_curve_suicide.csv

suppressPackageStartupMessages({ library(ggplot2); library(data.table) })
ROOT <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
VAL  <- file.path(ROOT, "01_manuscript", "values.tex")
PROC <- file.path(ROOT, "02_data", "processed")
FIG  <- file.path(ROOT, "04_figures")
OK <- "#0072B2"; ORANGE <- "#D55E00"; GREY <- "gray55"

force <- "--force" %in% commandArgs(TRUE)
out <- file.path(FIG, "fig_spec_curve_suicide.pdf")
if (file.exists(out) && !force) { cat("exists, skip (--force)\n"); quit(save="no") }

# ---- parse values.tex + values_inference.tex (single source of truth) ----
L <- c(readLines(VAL), readLines(file.path(ROOT, "01_manuscript", "values_inference.tex")))
mm <- regmatches(L, regexec("\\\\newcommand\\{\\\\(val[A-Za-z]+)\\}\\{([^}]*)\\}", L))
V <- list(); for (x in mm) if (length(x) == 3) V[[x[2]]] <- x[3]
g <- function(k) { v <- V[[k]]; if (is.null(v)) NA_real_ else as.numeric(gsub("[{},]", "", v)) }

# ---- read processed CSVs for spec-specific CIs ----
rc  <- fread(file.path(PROC, "recipient_control_spillover.csv"))
lc  <- fread(file.path(PROC, "lococor_displacement.csv"))
dr  <- fread(file.path(PROC, "doubly_robust_selection.csv"))
sc  <- fread(file.path(PROC, "synthetic_control_leg.csv"))
an  <- fread(file.path(PROC, "anticipation_renorm.csv"))

S <- function(label, group, att, lo, hi) data.table(label, group, att, lo, hi)
ci <- function(att, se) c(att - 1.96*se, att + 1.96*se)

rows <- list(
  S("Sun--Abraham, population-weighted (primary)", "Primary", g("valSuicWAtt"), g("valSuicWLo"), g("valSuicWHi")),
  S("Municipality-weighted", "Weighting", g("valSuicOAtt"), g("valSuicOLo"), g("valSuicOHi")),
  S("Specialized sample (n=41)", "Sample", g("valSuicSpecAtt"), g("valSuicSpecLo"), g("valSuicSpecHi")),
  S("Broad psychiatric sample (n=60)", "Sample", g("valSuicPsymaxAtt"), g("valSuicPsymaxLo"), g("valSuicPsymaxHi")),
  S("Drop pandemic years (2020--21)", "Robustness", g("valSuicDropPandAtt"), ci(g("valSuicDropPandAtt"), g("valSuicDropPandSe"))[1], ci(g("valSuicDropPandAtt"), g("valSuicDropPandSe"))[2]),
  S("Exclude state capitals", "Robustness", g("valSuicNoCapAtt"), ci(g("valSuicNoCapAtt"), g("valSuicNoCapSe"))[1], ci(g("valSuicNoCapAtt"), g("valSuicNoCapSe"))[2]),
  S("Naive two-way FE (biased benchmark)", "Estimator", g("valSuicTwfeAtt"), ci(g("valSuicTwfeAtt"), g("valSuicTwfeSe"))[1], ci(g("valSuicTwfeAtt"), g("valSuicTwfeSe"))[2]),
  S("Callaway--Sant'Anna, not-yet-treated", "Estimator", dr[control=="not-yet-treated" & covariates=="none", as.numeric(att)], dr[control=="not-yet-treated" & covariates=="none", as.numeric(ci_lo)], dr[control=="not-yet-treated" & covariates=="none", as.numeric(ci_hi)]),
  S("Callaway--Sant'Anna, doubly robust + covariate", "Estimator", dr[control=="never-treated" & covariates=="log_pop", as.numeric(att)], dr[control=="never-treated" & covariates=="log_pop", as.numeric(ci_lo)], dr[control=="never-treated" & covariates=="log_pop", as.numeric(ci_hi)]),
  S("Synthetic difference-in-differences", "Estimator", sc[step=="synthdid_agg", att], sc[step=="synthdid_agg", ci_lo], sc[step=="synthdid_agg", ci_hi]),
  S("Drop revealed-recipient controls (spillover)", "Threat", rc[outcome=="suicide_per100k" & spec=="drop_recipient_controls", att], rc[outcome=="suicide_per100k" & spec=="drop_recipient_controls", ci_lo], rc[outcome=="suicide_per100k" & spec=="drop_recipient_controls", ci_hi]),
  S("Out-of-hospital deaths only (displacement)", "Threat", lc[outcome=="suicide_outhosp", att], lc[outcome=="suicide_outhosp", ci_lo], lc[outcome=="suicide_outhosp", ci_hi]),
  S("Reference period $e=-3$ (anticipation)", "Threat", an[outcome=="suicide_per100k" & refp==-3 & weighted==TRUE, att], an[outcome=="suicide_per100k" & refp==-3 & weighted==TRUE, ci_lo], an[outcome=="suicide_per100k" & refp==-3 & weighted==TRUE, ci_hi]),
  S("Federation-Unit clustering", "Inference", g("valSuicWAtt"), g("valSuicUFLo"), g("valSuicUFHi")),
  S("Randomization inference (placebo band)", "Inference", g("valSuicWAtt"), g("valSuicRILo"), g("valSuicRIHi"))
)
d <- rbindlist(rows)
d <- d[is.finite(att) & is.finite(lo) & is.finite(hi)]
d[, group := factor(group, levels=c("Primary","Weighting","Sample","Estimator","Robustness","Threat","Inference"))]
setorder(d, att)
d[, label := factor(label, levels=label)]
d[, incl0 := lo <= 0 & hi >= 0]

fwrite(d, file.path(PROC, "spec_curve_suicide.csv"))
cat(sprintf("specs=%d  point range [%.2f, %.2f]  all CIs include 0: %s\n",
            nrow(d), min(d$att), max(d$att), all(d$incl0)))

prim <- g("valSuicWAtt")
gg <- ggplot(d, aes(att, label, color=group)) +
  geom_vline(xintercept=0, color=GREY, linewidth=0.4, linetype="dashed") +
  geom_vline(xintercept=prim, color=OK, linewidth=0.3, linetype="dotted") +
  geom_pointrange(aes(xmin=lo, xmax=hi), linewidth=0.5, size=0.32) +
  scale_color_manual(values=c(Primary="#0072B2", Weighting="#D55E00",
    Sample="#009E73", Estimator="#CC79A7", Robustness="#E69F00",
    Threat="#56B4E9", Inference="#999999"), name=NULL) +
  labs(x="Suicide ATT (per 100,000)", y=NULL,
       title="Specification curve: the suicide null across the analysis multiverse") +
  theme_minimal(base_size=9) +
  theme(panel.grid.minor=element_blank(), plot.title=element_text(size=10, hjust=0),
        legend.position="bottom", axis.text.y=element_text(size=8))
ggsave(out, gg, width=7.4, height=5.0, device="pdf")
ggsave(sub("\\.pdf$",".png",out), gg, width=7.4, height=5.0, dpi=150)
cat("wrote", out, "\n")
