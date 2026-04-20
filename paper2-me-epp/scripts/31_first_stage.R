# ============================================================================
# 31_first_stage.R — First-stage evidence: the March-2018 reinterpretation
# actually changed who wins Group-65 items
# ============================================================================
# Motivation: JPubE referees routinely ask "did the shock you describe
# really bind? show me the composition shift directly." This panel gives
# that directly.
#
# Outcome: sme_winner in {0,1} — indicator that the winning firm was
# registered as ME/EPP. Under the March-2018 reinterpretation, Group-65
# items became restricted to SME-only tenders (subject to opt-out), so
# the winning-firm SME share should jump sharply in Group 65 and not in
# controls.
#
# Specs:
#   (1) Simple means panel (pre/post x treated/control)
#   (2) DiDiR coefficient on sme_winner (analogue of main Equation 1)
#   (3) Event-study of sme_winner over semesters (same semester_f scheme
#       used for the main Figure~\ref{fig:collapse})
#
# Outputs:
#   - /tmp/p2_first_stage.rds
#   - output/tables/tab_first_stage.tex
#   - output/figures/fig_first_stage.pdf
# ============================================================================

cat("=== 31_first_stage.R: First-stage SME-composition shift ===\n")

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  f_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(f_arg)) dirname(sub("^--file=", "", f_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(ggplot2)
})

dt <- as.data.table(readRDS(DATA_CACHE))

# ---- Panel A: raw pre/post x treated/control means -----------------------
cat("\n  Panel A: raw SME-winner means (completed items only)\n")
cat("  (sample = oc_item_status == 1)\n\n")

means <- dt[oc_item_status == 1L,
            .(sme_share = mean(sme_winner, na.rm = TRUE),
              n = .N),
            by = .(g65, Pre)]
setorder(means, g65, -Pre)

cat(sprintf("  %-15s %10s %10s %10s\n", "cell", "pre/post", "sme_share", "n"))
for (i in seq_len(nrow(means))) {
  cell <- if (means$g65[i] == 1L) "Group 65" else "Control"
  per  <- if (means$Pre[i] == 1L) "pre"     else "post"
  cat(sprintf("  %-15s %10s %10.4f %10s\n", cell, per,
              means$sme_share[i], pfmt_int(means$n[i])))
}

sh_g65_pre  <- means[g65 == 1L & Pre == 1L, sme_share]
sh_g65_post <- means[g65 == 1L & Pre == 0L, sme_share]
sh_c_pre    <- means[g65 == 0L & Pre == 1L, sme_share]
sh_c_post   <- means[g65 == 0L & Pre == 0L, sme_share]

dd_did <- (sh_g65_post - sh_g65_pre) - (sh_c_post - sh_c_pre)
cat(sprintf("\n  Raw DiD on SME-winner share: %+.3f (%+.1f pp)\n",
            dd_did, 100 * dd_did))

# ---- Panel B: DiDiR regression (Equation 1 analogue) ---------------------
cat("\n  Panel B: DiDiR regression of sme_winner on g65xPre\n")
m_did <- run_didir_6("sme_winner", dt, completed = TRUE)

# The 18-month, item+PBU spec is the paper's headline in text
m_main <- m_did$`18m_pbu`
b  <- coef(m_main)["g65_pre"]
se <- sqrt(vcov(m_main)["g65_pre", "g65_pre"])
p  <- 2 * pnorm(-abs(b / se))
cat(sprintf("    18m item+PBU FE: b = %+.4f (%.4f), p = %.3g, n = %s\n",
            b, se, p, pfmt_int(m_main$nobs)))

# ---- Panel C: event study over semesters ----------------------------------
cat("\n  Panel C: event study over semesters\n")
es_data <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
              oc_item_status == 1L & !is.na(semester_f)]
m_es <- feols(sme_winner ~ i(semester_f, g65, ref = 4) |
              grupo_f + semester_f,
              data = es_data, cluster = ~grupo_f)

ct <- as.data.table(coeftable(m_es), keep.rownames = "term")
setnames(ct, c("term", "estimate", "se", "tval", "pval"))
ct <- ct[grepl("semester_f::", term)]
ct[, semester := as.integer(gsub(".*semester_f::(\\d+):g65", "\\1", term))]
ref <- data.table(term = "ref", estimate = 0, se = 0, tval = 0,
                  pval = 1, semester = 4L)
ct <- rbind(ct, ref); setorder(ct, semester)
ct[, ci_lo := estimate - 1.96 * se]
ct[, ci_hi := estimate + 1.96 * se]
cat("    Event-study coefficients:\n")
for (i in seq_len(nrow(ct))) {
  cat(sprintf("      sem %d: %+.4f (%.4f)\n",
              ct$semester[i], ct$estimate[i], ct$se[i]))
}

# ---- Save ------------------------------------------------------------------
saveRDS(list(means = means, m_did = m_did, m_es = m_es, es_coefs = ct),
        "/tmp/p2_first_stage.rds")

# ---- LaTeX table ----------------------------------------------------------
cat("\n  Writing LaTeX table...\n")

# DiDiR coefficients across 6 specs (match paper convention)
spec_names <- c("6m_base", "6m_pbu", "12m_base",
                "12m_pbu", "18m_base", "18m_pbu")
spec_labels <- c("(1) 6m, item", "(2) 6m, item+PBU",
                 "(3) 12m, item", "(4) 12m, item+PBU",
                 "(5) 18m, item", "(6) 18m, item+PBU")

cell_b  <- character(6); cell_se <- character(6); cell_n <- character(6)
for (i in seq_along(spec_names)) {
  mi <- m_did[[spec_names[i]]]
  bi  <- coef(mi)["g65_pre"]
  sei <- sqrt(vcov(mi)["g65_pre", "g65_pre"])
  pi_ <- 2 * pnorm(-abs(bi / sei))
  cell_b[i]  <- paste0(formatC(bi,  format = "f", digits = 4), pstars(pi_))
  cell_se[i] <- paste0("(", formatC(sei, format = "f", digits = 4), ")")
  cell_n[i]  <- pfmt_int(mi$nobs)
}

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{First Stage: March-2018 Reinterpretation and the SME-Composition Shift in Group-65 Winners}",
  "\\label{tab:first_stage}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccccc}",
  "\\toprule",
  paste0(" & ", paste(spec_labels, collapse = " & "), " \\\\"),
  "\\midrule",
  sprintf("$g65 \\times Pre$ & %s \\\\", paste(cell_b,  collapse = " & ")),
  sprintf(" & %s \\\\",                  paste(cell_se, collapse = " & ")),
  "\\midrule",
  sprintf("Observations & %s \\\\", paste(cell_n,  collapse = " & ")),
  "Item FE & YES & YES & YES & YES & YES & YES \\\\",
  "Month FE & YES & YES & YES & YES & YES & YES \\\\",
  "PBU FE & NO & YES & NO & YES & NO & YES \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Dependent variable is an indicator for whether",
  "the winning firm was registered as ME or EPP. Sample is restricted to",
  "completed items ($oc\\_item\\_status = 1$). $g65 \\times Pre$ identifies",
  "the Group-65 pre-treatment cell: a \\emph{negative} coefficient means",
  "Group-65 items had a lower SME-winner share \\emph{before} the",
  "reinterpretation than after, relative to the within-item average.",
  "Equivalently, the March~2018 cutoff raised the SME-winner share in Group",
  "65 by about 11--12 percentage points above what item and PBU fixed effects",
  "alone would predict. Raw pre/post means: Group-65 pre = 0.1\\%, post =",
  "39.1\\%; controls pre = 40.4\\%, post = 67.0\\% (controls also rise over",
  "time, so the DiD is smaller than the within-G65 jump). This is the",
  "\\emph{first stage} of the identification strategy: the legal",
  "reinterpretation measurably changes who wins Group-65 items. Standard",
  "errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_first_stage.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_first_stage.tex"), "\n")

# ---- Event-study figure ---------------------------------------------------
cat("\n  Rendering event-study figure...\n")

ct[, x_label := factor(semester, levels = 1:6, labels = SEM_LABELS)]

p <- ggplot(ct, aes(x = semester, y = estimate)) +
  geom_vline(xintercept = 3.5, linetype = "dashed",
             color = "red4", linewidth = 0.5) +
  geom_hline(yintercept = 0, linetype = "dotted",
             color = "gray50", linewidth = 0.3) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                width = 0.15, linewidth = 0.5, color = "black") +
  geom_point(size = 2.5, color = "black") +
  scale_x_continuous(breaks = 1:6, labels = SEM_LABELS) +
  labs(x = "Semester",
       y = "SME-winner share (DiD coefficient vs. controls)") +
  theme_pub() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))

save_pub(p, "fig_first_stage.pdf")

cat("  Done.\n")
