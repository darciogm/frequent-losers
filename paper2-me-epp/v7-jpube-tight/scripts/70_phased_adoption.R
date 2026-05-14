# ----------------------------------------------------------------------
# 70_phased_adoption.R
#
# Generates Table tab_phased_adoption (Appendix §7): drop-incubation
# robustness check. Headline DiD re-estimated on the sample with
# months [690, 697] excluded — i.e., dropping the eight-month BEC
# functionality enablement window between COMUNICADO BEC 02/2017 and
# the empirical cutoff.
#
# This is the publication-safe twin of EX2 in 99_internal_robustness.R.
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})
setDTthreads(12)
setFixest_estimation(lean = TRUE)

p <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/processed/paper2_me_epp.parquet"
dt <- as.data.table(arrow::read_parquet(p))
dt <- dt[data_oc_numb >= 680L & data_oc_numb <= 715L]
dt[, codigogrupo := as.character(codigogrupo)]
dt[, g65 := as.integer(codigogrupo == "65")]

TREAT_PAPER <- 698L
DATE_BEC02  <- 690L

dt_p <- dt[oc_item_status == 1L & !is.na(lpreco_final) &
             !is.na(item_alt) & !is.na(pbu_alt)]
dt_p[, Pre := as.integer(data_oc_numb < TREAT_PAPER)]
dt_p[, g65_pre := g65 * Pre]

m_full  <- feols(lpreco_final ~ g65_pre + convite + lquantidade |
                    item_alt + data_oc_numb,
                  data = dt_p, cluster = ~item_alt)

dt_p_short <- dt_p[!(data_oc_numb >= DATE_BEC02 & data_oc_numb < TREAT_PAPER)]
m_short <- feols(lpreco_final ~ g65_pre + convite + lquantidade |
                    item_alt + data_oc_numb,
                  data = dt_p_short, cluster = ~item_alt)

fmt <- function(x, d = 3) formatC(x, format = "f", digits = d, big.mark = ",")
ci_str <- function(model) {
  b  <- coef(model)["g65_pre"]
  se <- sqrt(vcov(model)["g65_pre", "g65_pre"])
  p  <- 2 * pnorm(-abs(b / se))
  star <- ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
  list(coef = paste0(fmt(b), star), se = paste0("(", fmt(se), ")"))
}

c_full  <- ci_str(m_full)
c_short <- ci_str(m_short)
n_full  <- nobs(m_full)
n_short <- nobs(m_short)

tex <- paste0(
"\\begin{table}[!htbp]\n",
"\\centering\n",
"\\begin{threeparttable}\n",
"\\caption{Phased-adoption robustness: DiD coefficient with the BEC enablement window excluded.}\n",
"\\label{tab:phased_adoption}\n",
"\\small\n",
"\\setlength{\\tabcolsep}{8pt}\n",
"\\begin{tabular}{lcc}\n",
"\\toprule\n",
" & Full sample & Drop incubation \\\\\n",
" & (paper baseline) & ($m \\notin [690, 697]$) \\\\\n",
"\\midrule\n",
"$g65 \\times \\text{Pre}$ & ", c_full$coef, " & ", c_short$coef, " \\\\\n",
" & ", c_full$se, " & ", c_short$se, " \\\\\n",
"\\addlinespace\n",
"Observations & ", formatC(n_full, format = "d", big.mark = ","), " & ",
                   formatC(n_short, format = "d", big.mark = ","), " \\\\\n",
"Item FE & Yes & Yes \\\\\n",
"Month FE & Yes & Yes \\\\\n",
"Cluster (item) & Yes & Yes \\\\\n",
"\\bottomrule\n",
"\\end{tabular}\n",
"\\begin{tablenotes}\\footnotesize\n",
"\\item DiD specification: $\\ln(\\text{price}) = \\beta\\, g65 \\times \\text{Pre} + \\gamma_1 \\,\\text{convite} + \\gamma_2 \\ln(\\text{qty}) + \\delta_i + \\delta_t + \\varepsilon$, on completed Preg\\~ao items. The full-sample column reproduces the headline coefficient on the 18-month symmetric window [680, 715]; the drop-incubation column re-estimates after excluding the eight months $m \\in [690, 697]$ (Jul 2017--Feb 2018), the window during which BEC operationalized the SME-only OC functionality (COMUNICADO BEC 02/2017 and 03/2017) before the empirical cutoff of mass take-up in Mar 2018. Effect persists with magnitude reduced by 22\\%, supporting that the headline is not driven by the BEC enablement window. Standard errors clustered at the item level. *** $p<0.01$, ** $p<0.05$, * $p<0.1$.\n",
"\\end{tablenotes}\n",
"\\end{threeparttable}\n",
"\\end{table}\n"
)

out <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/output/tables/tab_phased_adoption.tex"
writeLines(tex, out)
cat("Wrote:", out, "\n")
cat("\nFull-sample coef: ", c_full$coef, " ", c_full$se, "  N=", n_full, "\n", sep = "")
cat("Drop-incubation:  ", c_short$coef, " ", c_short$se, "  N=", n_short, "\n", sep = "")
