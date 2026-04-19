# ============================================================================
# 14_rais_pretrends.R — Employment pre-trends event study (RAIS 2011-2017)
# ============================================================================
# Consumes the balanced firm-year panel built by 14_rais_pretrends_etl.py
# and runs a two-way fixed-effect event study of log employment to validate
# the parallel-trends assumption at the firm level.
#
# Outputs:
#   - /tmp/p2_pretrends.rds
#   - output/tables/tab_pretrends.tex
#   - output/figures/fig_pretrends.pdf
#   - output/tables/diag_pretrends.txt
# ============================================================================

cat("=== 14_rais_pretrends.R: Pre-trends event study ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

PANEL_PARQ <- file.path(BASE, "data", "processed", "p2_rais_firmyear.parquet")
if (!file.exists(PANEL_PARQ))
  stop("Run 14_rais_pretrends_etl.py first: ", PANEL_PARQ)

panel <- as.data.table(read_parquet(PANEL_PARQ))
panel[, log_emp := log1p(emp)]
panel[, year_f  := factor(year, levels = sort(unique(year)))]

n_firms   <- uniqueN(panel$cnpj_raiz)
n_treat   <- uniqueN(panel[treated == 1L, cnpj_raiz])
n_ctrl    <- uniqueN(panel[treated == 0L, cnpj_raiz])
YEARS     <- sort(unique(panel$year))
REF_YEAR  <- max(YEARS) - 1L  # 2016: last full pre-treatment year in RAIS

cat(sprintf("  Panel: %s firm-years (firms=%s; treated=%s, control=%s)\n",
            pfmt_int(nrow(panel)), pfmt_int(n_firms),
            pfmt_int(n_treat), pfmt_int(n_ctrl)))
cat(sprintf("  Years: %d-%d | Reference: %d\n",
            min(YEARS), max(YEARS), REF_YEAR))

# ---- Event study ----------------------------------------------------------
cat("  Estimating event study...\n")
es <- feols(log_emp ~ i(year_f, treated, ref = as.character(REF_YEAR)) |
                     cnpj_raiz + year_f,
            data = panel, cluster = ~cnpj_raiz)

wt <- wald(es, keep = "year_f")
cat(sprintf("  Joint Wald F = %.3f  |  p = %.4f  (k = %d coefs)\n",
            wt$stat, wt$p, length(es$coefficients)))

# Pre-period only F-test: coefficients for years < REF_YEAR
pre_coefs <- grep(sprintf("year_f::(%s):treated",
                          paste(YEARS[YEARS < REF_YEAR], collapse = "|")),
                  names(es$coefficients), value = TRUE)
wt_pre <- if (length(pre_coefs) > 0) {
  wald(es, keep = pre_coefs)
} else list(stat = NA, p = NA)
cat(sprintf("  Pre-period only (years<%d): F = %.3f  |  p = %.4f  (k = %d)\n",
            REF_YEAR, wt_pre$stat, wt_pre$p, length(pre_coefs)))

# ---- Diagnostics ----------------------------------------------------------
yr_summary <- panel[, .(
  n_firms    = uniqueN(cnpj_raiz),
  mean_emp   = mean(emp),
  median_emp = as.numeric(median(emp)),
  mean_logp  = mean(log_emp)
), by = .(treated, year)]
setorder(yr_summary, treated, year)

diag <- c(
  "=== Pre-trends event study diagnostic ===",
  sprintf("Firms: %s (treated=%s, control=%s)",
          pfmt_int(n_firms), pfmt_int(n_treat), pfmt_int(n_ctrl)),
  sprintf("Years: %d-%d (%d years)  |  Reference: %d",
          min(YEARS), max(YEARS), length(YEARS), REF_YEAR),
  sprintf("Firm-years: %s", pfmt_int(nrow(panel))),
  "",
  sprintf("Joint F (all years vs ref): %.3f, p = %.4f", wt$stat, wt$p),
  sprintf("Pre-ref F (years<%d):       %.3f, p = %.4f",
          REF_YEAR, wt_pre$stat, wt_pre$p),
  "Interpretation: p > 0.10 on pre-ref F supports parallel pre-trends.",
  "",
  "Year x treatment summary (emp = Qtd Vínculos Ativos):",
  capture.output(print(yr_summary))
)
writeLines(diag, file.path(OUT_TAB, "diag_pretrends.txt"))
cat("  Saved:", file.path(OUT_TAB, "diag_pretrends.txt"), "\n")

saveRDS(list(model = es, wald_all = wt, wald_pre = wt_pre,
             year_summary = yr_summary,
             n_treated = n_treat, n_control = n_ctrl,
             ref_year = REF_YEAR, years = YEARS),
        "/tmp/p2_pretrends.rds")

# ---- LaTeX table ---------------------------------------------------------
cat("  Writing LaTeX table...\n")
cf <- summary(es)$coeftable
row_names <- rownames(cf)
yrs <- as.integer(sub(".*?([0-9]{4}).*", "\\1", row_names))
keep <- !is.na(yrs)
cf <- cf[keep, , drop = FALSE]
yrs <- yrs[keep]
ord <- order(yrs); yrs <- yrs[ord]; cf <- cf[ord, , drop = FALSE]

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Employment Pre-Trends: Event Study from RAIS 2011--2017}",
  "\\label{tab:pretrends}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " Year & $\\beta_y$ & (SE) \\\\",
  "\\midrule"
)

out_rows <- character(0)
for (i in seq_along(yrs)) {
  b  <- cf[i, "Estimate"]; se <- cf[i, "Std. Error"]; pv <- cf[i, "Pr(>|t|)"]
  out_rows <- c(out_rows,
    sprintf("%d & %s & (%s) \\\\", yrs[i],
            paste0(pfmt(b, 4), pstars(pv)), pfmt(se, 4)))
}

# Insert reference row in correct position
ref_row <- sprintf("%d & \\textit{reference} & --- \\\\", REF_YEAR)
all_years <- sort(c(yrs, REF_YEAR))
combined <- character(0)
for (yr in all_years) {
  if (yr == REF_YEAR) {
    combined <- c(combined, ref_row)
  } else {
    idx <- which(yrs == yr)
    combined <- c(combined, out_rows[idx])
  }
}
lines <- c(lines, combined)

lines <- c(lines,
  "\\midrule",
  sprintf("Firms & \\multicolumn{2}{c}{%s (treated %s, control %s)} \\\\",
          pfmt_int(n_firms), pfmt_int(n_treat), pfmt_int(n_ctrl)),
  sprintf("Firm-years & \\multicolumn{2}{c}{%s} \\\\", pfmt_int(nrow(panel))),
  sprintf("Joint F (all years) & \\multicolumn{2}{c}{$F = %.3f$, $p = %.4f$} \\\\",
          wt$stat, wt$p),
  sprintf("Pre-ref F (years $<$ %d) & \\multicolumn{2}{c}{$F = %.3f$, $p = %.4f$} \\\\",
          REF_YEAR, wt_pre$stat, wt_pre$p),
  "Firm FE, Year FE & \\multicolumn{2}{c}{YES} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Dependent variable $\\log(1 + \\text{vínculos ativos})$,",
  sprintf("from RAIS ESTB %d--%d. Treated firms ever won a group-65 item in",
          min(YEARS), max(YEARS)),
  "BEC before March 2018; control firms won only non-group-65 items in the same period.",
  "Panel is balanced with zero-fill for firm-years absent from RAIS.",
  "Reference year is 2016 (last full pre-policy year in RAIS; the policy switched",
  "March 2018, which falls outside the available RAIS window).",
  "Failure to reject the pre-ref F-test supports the parallel pre-trends assumption.",
  "Standard errors clustered at the CNPJ-raiz level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)
writeLines(lines, file.path(OUT_TAB, "tab_pretrends.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_pretrends.tex"), "\n")

# ---- Figure --------------------------------------------------------------
cat("  Rendering figure...\n")
df <- data.frame(
  year = c(yrs, REF_YEAR),
  est  = c(cf[, "Estimate"], 0),
  se   = c(cf[, "Std. Error"], 0),
  ref  = c(rep(FALSE, length(yrs)), TRUE)
)
df <- df[order(df$year), ]
df$lo <- df$est - 1.96 * df$se
df$hi <- df$est + 1.96 * df$se

p <- ggplot(df, aes(x = year, y = est)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, color = "black") +
  geom_point(aes(shape = ref), size = 2.2, color = "black", fill = "white") +
  scale_shape_manual(values = c(16, 1), guide = "none") +
  scale_x_continuous(breaks = YEARS) +
  labs(x = "Year",
       y = expression(paste("Employment effect: ", beta[y], " (log points)"))) +
  theme_pub()

save_pub(p, "fig_pretrends.pdf")
cat("  Done.\n")
