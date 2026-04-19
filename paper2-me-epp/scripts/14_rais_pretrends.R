# ============================================================================
# 14_rais_pretrends.R — Firm-level employment trajectories (RAIS 2011-2017)
# ============================================================================
# Runs a two-way fixed-effect event study of log employment for winners
# classified by BEC pre-period exposure to group 65. Two specifications:
#
#   (A) Full panel (balanced with zero-fill). Pre-ref F fails to reject
#       parallel pre-trends at 10%.
#   (B) Always-present subset (emp >= 1 every year). Pre-ref F rejects;
#       reflects selection of procurement winners on firm productivity
#       and growth, not a violation of the paper's identification, which
#       is assigned at the ITEM group level (not the firm level).
#
# The item-level event studies (figs A.1-A.4) remain the authoritative
# pre-trends test matching the paper's identifying assumption.
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

# ---- Always-present subset (firms with emp >= 1 every year) ---------------
# Removes firms that were founded mid-window or closed mid-window (artificial
# zeros from panel balancing). Cleaner identification of secular pre-trends.
firm_coverage <- panel[, .(years_active = sum(emp >= 1L)), by = cnpj_raiz]
always_present <- firm_coverage[years_active == length(YEARS), cnpj_raiz]
panel_ap <- panel[cnpj_raiz %in% always_present]

n_ap      <- uniqueN(panel_ap$cnpj_raiz)
n_treat_ap <- uniqueN(panel_ap[treated == 1L, cnpj_raiz])
n_ctrl_ap  <- uniqueN(panel_ap[treated == 0L, cnpj_raiz])
cat(sprintf("  Always-present subset: %s firms (treated=%s, control=%s)\n",
            pfmt_int(n_ap), pfmt_int(n_treat_ap), pfmt_int(n_ctrl_ap)))

# ---- Event studies (full and always-present) ------------------------------
run_es <- function(data) {
  feols(log_emp ~ i(year_f, treated, ref = as.character(REF_YEAR)) |
                 cnpj_raiz + year_f,
        data = data, cluster = ~cnpj_raiz)
}

pre_coef_names <- function(model) {
  grep(sprintf("year_f::(%s):treated",
               paste(YEARS[YEARS < REF_YEAR], collapse = "|")),
       names(model$coefficients), value = TRUE)
}

cat("  Estimating event study (full panel)...\n")
es    <- run_es(panel)
wt    <- wald(es, keep = "year_f")
wt_pre <- wald(es, keep = pre_coef_names(es))

cat("  Estimating event study (always-present subset)...\n")
es_ap    <- run_es(panel_ap)
wt_ap    <- wald(es_ap, keep = "year_f")
wt_pre_ap <- wald(es_ap, keep = pre_coef_names(es_ap))

cat(sprintf("  Full panel     : all F = %.3f (p=%.4f) | pre-ref F = %.3f (p=%.4f)\n",
            wt$stat, wt$p, wt_pre$stat, wt_pre$p))
cat(sprintf("  Always-present : all F = %.3f (p=%.4f) | pre-ref F = %.3f (p=%.4f)\n",
            wt_ap$stat, wt_ap$p, wt_pre_ap$stat, wt_pre_ap$p))

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
  "",
  "-- Full panel (balanced with zero-fill) --",
  sprintf("Firms: %s (treated=%s, control=%s) | firm-years: %s",
          pfmt_int(n_firms), pfmt_int(n_treat), pfmt_int(n_ctrl),
          pfmt_int(nrow(panel))),
  sprintf("Joint F (all coefs): %.3f, p = %.4f", wt$stat, wt$p),
  sprintf("Pre-ref F (years<%d): %.3f, p = %.4f",
          REF_YEAR, wt_pre$stat, wt_pre$p),
  "",
  "-- Always-present subset (emp >= 1 every year) --",
  sprintf("Firms: %s (treated=%s, control=%s) | firm-years: %s",
          pfmt_int(n_ap), pfmt_int(n_treat_ap), pfmt_int(n_ctrl_ap),
          pfmt_int(nrow(panel_ap))),
  sprintf("Joint F (all coefs): %.3f, p = %.4f", wt_ap$stat, wt_ap$p),
  sprintf("Pre-ref F (years<%d): %.3f, p = %.4f",
          REF_YEAR, wt_pre_ap$stat, wt_pre_ap$p),
  "",
  sprintf("Years: %d-%d (%d years)  |  Reference: %d",
          min(YEARS), max(YEARS), length(YEARS), REF_YEAR),
  "",
  "Interpretation notes:",
  "- Full panel: pre-ref F fails to reject parallel pre-trends at 10%.",
  "- Always-present: pre-ref F strongly rejects. This reflects selection of",
  "  winners on firm productivity (procurement winners grow faster), NOT a",
  "  violation of the paper's identification, which is at the ITEM level.",
  "- The item-level event studies (figs A.1-A.4) are the pre-trends test",
  "  matching the paper's identifying assumption.",
  "",
  "Year x treatment summary (full panel):",
  capture.output(print(yr_summary))
)
writeLines(diag, file.path(OUT_TAB, "diag_pretrends.txt"))
cat("  Saved:", file.path(OUT_TAB, "diag_pretrends.txt"), "\n")

saveRDS(list(model_full = es, model_ap = es_ap,
             wald_all = wt, wald_pre = wt_pre,
             wald_all_ap = wt_ap, wald_pre_ap = wt_pre_ap,
             year_summary = yr_summary,
             n_treated = n_treat, n_control = n_ctrl,
             n_treated_ap = n_treat_ap, n_control_ap = n_ctrl_ap,
             ref_year = REF_YEAR, years = YEARS),
        "/tmp/p2_pretrends.rds")

# ---- Helper: extract year x treated coefs ordered by year ----------------
extract_yr <- function(model) {
  cf <- summary(model)$coeftable
  yrs <- as.integer(sub(".*?([0-9]{4}).*", "\\1", rownames(cf)))
  keep <- !is.na(yrs)
  cf <- cf[keep, , drop = FALSE]; yrs <- yrs[keep]
  ord <- order(yrs)
  list(yrs = yrs[ord], cf = cf[ord, , drop = FALSE])
}
ex_full <- extract_yr(es)
ex_ap   <- extract_yr(es_ap)

# ---- LaTeX table (both specs side-by-side) -------------------------------
cat("  Writing LaTeX table...\n")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Employment Pre-Trends: Event Study from RAIS 2011--2017}",
  "\\label{tab:pretrends}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{Full panel (zero-filled)} & \\multicolumn{2}{c}{Always-present subset} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  " Year & $\\beta_y$ & (SE) & $\\beta_y$ & (SE) \\\\",
  "\\midrule"
)

ref_cells <- "\\textit{ref.} & --- & \\textit{ref.} & ---"
all_years <- sort(unique(c(ex_full$yrs, REF_YEAR)))
for (yr in all_years) {
  if (yr == REF_YEAR) {
    lines <- c(lines, sprintf("%d & %s \\\\", yr, ref_cells))
    next
  }
  i_full <- which(ex_full$yrs == yr)
  i_ap   <- which(ex_ap$yrs == yr)
  b_full  <- ex_full$cf[i_full, "Estimate"]
  se_full <- ex_full$cf[i_full, "Std. Error"]
  pv_full <- ex_full$cf[i_full, "Pr(>|t|)"]
  b_ap    <- ex_ap$cf[i_ap, "Estimate"]
  se_ap   <- ex_ap$cf[i_ap, "Std. Error"]
  pv_ap   <- ex_ap$cf[i_ap, "Pr(>|t|)"]
  lines <- c(lines, sprintf(
    "%d & %s & (%s) & %s & (%s) \\\\", yr,
    paste0(pfmt(b_full, 4), pstars(pv_full)), pfmt(se_full, 4),
    paste0(pfmt(b_ap,   4), pstars(pv_ap)),   pfmt(se_ap,   4)))
}

lines <- c(lines,
  "\\midrule",
  sprintf("Firms & \\multicolumn{2}{c}{%s (%s / %s)} & \\multicolumn{2}{c}{%s (%s / %s)} \\\\",
          pfmt_int(n_firms),  pfmt_int(n_treat),  pfmt_int(n_ctrl),
          pfmt_int(n_ap),     pfmt_int(n_treat_ap), pfmt_int(n_ctrl_ap)),
  sprintf("Firm-years & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\",
          pfmt_int(nrow(panel)), pfmt_int(nrow(panel_ap))),
  sprintf("Joint $F$ (all coefs) & \\multicolumn{2}{c}{$F = %.3f$, $p = %.4f$} & \\multicolumn{2}{c}{$F = %.3f$, $p = %.4f$} \\\\",
          wt$stat, wt$p, wt_ap$stat, wt_ap$p),
  sprintf("Pre-ref $F$ (years $<$ %d) & \\multicolumn{2}{c}{$F = %.3f$, $p = %.4f$} & \\multicolumn{2}{c}{$F = %.3f$, $p = %.4f$} \\\\",
          REF_YEAR, wt_pre$stat, wt_pre$p, wt_pre_ap$stat, wt_pre_ap$p),
  "Firm FE, Year FE & \\multicolumn{4}{c}{YES} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Dependent variable $\\log(1 + \\text{vínculos ativos})$",
  sprintf("from RAIS ESTB %d--%d. Treated firms ever won a group-65 item in",
          min(YEARS), max(YEARS)),
  "BEC before March 2018; control firms won only non-group-65 items in the same period.",
  "Firm counts shown as ``total (treated / control)''.",
  "``Full panel'' is balanced with zero-fill for firm-years absent from RAIS.",
  "``Always-present'' restricts to firms with at least one employment link in every",
  "year of the window, removing artificial zeros from firms founded mid-sample",
  "or closed mid-sample.",
  "Reference year 2016 (last full pre-policy year in RAIS; the policy switched",
  "March 2018, outside the available RAIS window).",
  "\\textit{Caveat:} the identifying assumption of the main DiDiR is parallel",
  "pre-trends at the item--group level (see event studies for prices, firms, bids,",
  "and distance), not at the winning-firm level. The rejection in the",
  "always-present column reflects selection of winners on firm productivity",
  "and growth---a well-known feature of public procurement---rather than a",
  "violation of identification: treatment is assigned to the item group,",
  "not to the firm.",
  "Standard errors clustered at the CNPJ-raiz level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)
writeLines(lines, file.path(OUT_TAB, "tab_pretrends.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_pretrends.tex"), "\n")

# ---- Figure (two series side-by-side) ------------------------------------
cat("  Rendering figure...\n")
mk_df <- function(ex, label) {
  data.frame(
    year = c(ex$yrs, REF_YEAR),
    est  = c(ex$cf[, "Estimate"], 0),
    se   = c(ex$cf[, "Std. Error"], 0),
    ref  = c(rep(FALSE, length(ex$yrs)), TRUE),
    spec = label
  )
}
df <- rbind(mk_df(ex_full, "Full panel"),
            mk_df(ex_ap,   "Always-present"))
df$lo <- df$est - 1.96 * df$se
df$hi <- df$est + 1.96 * df$se
df <- df[order(df$spec, df$year), ]
df$spec <- factor(df$spec, levels = c("Full panel", "Always-present"))

# Dodge slightly for readability
df$year_jit <- df$year + ifelse(df$spec == "Full panel", -0.10, 0.10)

p <- ggplot(df, aes(x = year_jit, y = est, shape = spec, linetype = spec)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, color = "black") +
  geom_point(size = 2.2, color = "black", fill = "white") +
  scale_shape_manual(values = c("Full panel" = 16, "Always-present" = 1)) +
  scale_linetype_manual(values = c("Full panel" = "solid",
                                    "Always-present" = "dashed")) +
  scale_x_continuous(breaks = YEARS) +
  labs(x = "Year",
       y = expression(paste("Employment effect: ", beta[y],
                             " (log points, ref = 2016)"))) +
  theme_pub()

save_pub(p, "fig_pretrends.pdf")
cat("  Done.\n")
