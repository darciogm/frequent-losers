# ----------------------------------------------------------------------
# 99_internal_robustness.R
#
# **NOT WIRED INTO 00_master.R. NOT FOR PUBLICATION.**
#
# Three exploratory robustness exercises held for referee response, in
# case the timing of the empirical cutoff is challenged. The exercises
# are motivated by the institutional timeline reconstructed in §1: BEC
# operationalized the SME-only functionality before the empirical
# cutoff (COMUNICADO BEC 02/2017, 18-Jul-2017; COMUNICADO BEC 03/2017,
# 20-Nov-2017), the PGE-SP ratified juridically (Parecer 151/2017,
# 11-Dec-2017), the empirical cutoff is March 2018 (mass take-up by
# Group-65 PBUs), and TCE-SP confirmed the interpretation in May 2018
# (eTC-9589.989.18).
#
# Findings (saved to logs/internal_robustness.log):
# EX1 — Two-dummy decomposition (Habilitacao vs Adocao): the dip
#       during the habilitação window [690, 697] explains a large
#       share of the headline 10.9 percent effect. The incremental
#       jump strictly post-cutoff (m >= 698) versus the pre-habilitacao
#       baseline (m in [680, 689]) is statistically zero in the wide
#       variant and small (+3.5%) in the narrow variant.
# EX2 — Drop-incubation robustness: dropping months [690, 697] from
#       the sample yields g65_pre = -0.087 *** versus -0.109 *** in
#       the full sample. Effect persists, magnitude falls 22 percent.
#       This is the only exercise that survives publication: it is
#       wired into the appendix as Table tab_phased_adoption (see
#       script 70_phased_adoption.R if/when activated).
# EX3 — Placebo TCE-SP cutoff (m=700, May 2018): on the post-period
#       sample [698, 715], the placebo dummy g65 * (m < 700) returns
#       -0.037 ** — i.e., prices in Group 65 continue to adjust after
#       the empirical cutoff, with an additional 3.7 percent jump
#       around the TCE-SP realignment. Diagnostic of phased adoption,
#       not a clean placebo.
#
# Recommendation: hold all three for referee response. Only EX2 is
# safe to publish; EX1 and EX3 raise questions a referee may not have
# asked otherwise. See docs/referee_response_notes.md.
#
# To re-run: Rscript scripts/99_internal_robustness.R
#   (writes to logs/internal_robustness.log)
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})
setDTthreads(12)
setFixest_estimation(lean = TRUE)

LOGF <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/logs/internal_robustness.log"
sink(LOGF, split = TRUE)
on.exit(sink(NULL), add = TRUE)

cat("# 99_internal_robustness.R — referee-response artifact\n")
cat("# Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

p <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/processed/paper2_me_epp.parquet"
dt <- as.data.table(arrow::read_parquet(p))
dt <- dt[data_oc_numb >= 680L & data_oc_numb <= 715L]
dt[, codigogrupo := as.character(codigogrupo)]
dt[, g65 := as.integer(codigogrupo == "65")]

# Stata monthly anchors
TREAT_PAPER  <- 698L  # Mar 2018 — paper cutoff
DATE_BEC02   <- 690L  # Jul 2017 — COMUNICADO BEC 02/2017
DATE_BEC03   <- 694L  # Nov 2017 — COMUNICADO BEC 03/2017
DATE_TCE     <- 700L  # May 2018 — TCE-SP eTC-9589.989.18

cat("Sample size:", nrow(dt), "\n")
cat("Group 65 share:", round(mean(dt$g65), 3), "\n\n")

dt_p <- dt[oc_item_status == 1L & !is.na(lpreco_final) &
             !is.na(item_alt) & !is.na(pbu_alt)]
cat("Completed sample for prices:", nrow(dt_p), "\n\n")

# =====================================================================
# EX1 — Habilitacao vs Adocao (two-dummy decomposition)
# =====================================================================
cat("============================================================\n")
cat("EX1: Habilitacao vs Adocao — two-dummy decomposition\n")
cat("============================================================\n\n")

dt_p[, D_hab        := g65 * as.integer(data_oc_numb >= DATE_BEC02 & data_oc_numb < TREAT_PAPER)]
dt_p[, D_post       := g65 * as.integer(data_oc_numb >= TREAT_PAPER)]
dt_p[, D_hab_narrow := g65 * as.integer(data_oc_numb >= DATE_BEC03 & data_oc_numb < TREAT_PAPER)]
dt_p[, Pre          := as.integer(data_oc_numb < TREAT_PAPER)]
dt_p[, g65_pre      := g65 * Pre]

m_paper <- feols(lpreco_final ~ g65_pre + convite + lquantidade |
                   item_alt + data_oc_numb,
                 data = dt_p, cluster = ~item_alt)
m_two <- feols(lpreco_final ~ D_hab + D_post + convite + lquantidade |
                  item_alt + data_oc_numb,
                data = dt_p, cluster = ~item_alt)
m_two_narrow <- feols(lpreco_final ~ D_hab_narrow + D_post + convite + lquantidade |
                         item_alt + data_oc_numb,
                       data = dt_p, cluster = ~item_alt)

cat("PAPER baseline (g65*Pre): coef should be ~ -0.109\n")
print(summary(m_paper))
cat("\nTWO-DUMMY (Hab Jul17-Feb18 / Post Mar18+):\n")
print(summary(m_two))
cat("\nTWO-DUMMY (Hab_narrow Nov17-Feb18 / Post Mar18+):\n")
print(summary(m_two_narrow))

# =====================================================================
# EX2 — Drop incubation [690, 697] (the safe-to-publish robustness)
# =====================================================================
cat("\n\n============================================================\n")
cat("EX2: Drop incubation [m in 690..697]\n")
cat("============================================================\n\n")

dt_p_short <- dt_p[!(data_oc_numb >= DATE_BEC02 & data_oc_numb < TREAT_PAPER)]
cat("Sample after drop:", nrow(dt_p_short), "\n")
cat("Months retained: m in [680, 689] union [698, 715]\n\n")

m_short <- feols(lpreco_final ~ g65_pre + convite + lquantidade |
                    item_alt + data_oc_numb,
                  data = dt_p_short, cluster = ~item_alt)
cat("DiD on truncated (no incubation) sample:\n")
print(summary(m_short))

# =====================================================================
# EX3 — Placebo TCE-SP cutoff (m=700, post-period only)
# =====================================================================
cat("\n\n============================================================\n")
cat("EX3: Placebo cutoff at m=700 (TCE-SP, post-period only)\n")
cat("============================================================\n\n")

dt_post <- dt_p[data_oc_numb >= TREAT_PAPER]
cat("Post-only sample size:", nrow(dt_post), "\n")
dt_post[, post_tce   := as.integer(data_oc_numb >= DATE_TCE)]
dt_post[, g65_pretce := g65 * (1L - post_tce)]

m_placebo <- feols(lpreco_final ~ g65_pretce + convite + lquantidade |
                      item_alt + data_oc_numb,
                    data = dt_post, cluster = ~item_alt)
cat("Placebo DiD: g65 * (m < 700) on post-cutoff sample [698-715]:\n")
print(summary(m_placebo))

cat("\n\nDONE. Internal artifact, not for publication.\n")
