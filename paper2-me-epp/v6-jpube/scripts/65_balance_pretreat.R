# 65_balance_pretreat.R
#
# Pre-treatment covariate balance: Group 65 (treated) vs the 76 never-treated
# control groups, on the pre-period (data_oc_numb < 698, i.e. Sep 2016 - Feb
# 2018) subsample of the DiD panel in Appendix \ref{app:did}.
#
# Built in response to a referee concern that the DiD design (eq.~\ref{eq:did})
# rests on 76 never-treated groups as control without a documented pre-period
# composition check. The Imbens-Rubin normalized differences below quantify
# group-65-vs-pool composition gaps; item fixed effects in the estimating
# equation absorb the time-invariant component, so this check is informative
# about cross-group composition rather than the identifying assumption itself.
#
# Outputs:
#   data/processed/balance_pretreat.parquet   — per-variable summary stats
#   output/tables/tab_balance_pretreat.tex    — appendix balance table
#   logs/65_balance_pretreat.log              — text log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v6("logs/65_balance_pretreat.log"), open = "wt")
on.exit(close(logf), add = TRUE)
con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("65", "start: pre-treatment balance G65 vs 76 controls", logf)

src <- path_proc("paper2_me_epp.parquet")
log_step("65", sprintf("lendo %s", src), logf)

# 1. Item-level aggregation in pre-period. me_epp/dist1/fornec_estado_SP vary
#    across bid rows within an item; num_bids/num_firms/convite/valor_total_ref
#    are item-level repeats. Two-bid floor mirrors the structural sample
#    restriction. We use all pre-period eligible items in non-G65 groups as
#    the control pool (the broadest set the balance check can speak to);
#    the macro \controlGroupCount{} (= 76) elsewhere in the paper refers to
#    the DiD-identifying universe under additional restrictions and may
#    differ by one or two groups from the count reported here.
item_pre <- dbGetQuery(con, sprintf("
  SELECT
    codigogrupo,
    item_alt,
    FIRST(lpreco_ref)        AS log_pref,
    FIRST(num_bids)          AS num_bids,
    FIRST(num_firms)         AS num_firms,
    FIRST(convite)           AS convite,
    FIRST(valor_total_ref)   AS valor_total_ref,
    AVG(CAST(me_epp AS DOUBLE))           AS pct_sme_bids,
    AVG(CAST(fornec_estado_SP AS DOUBLE)) AS pct_sp_bids,
    AVG(ldist1)              AS log_dist,
    AVG(final_ref_perc)      AS final_ref
  FROM read_parquet('%s')
  WHERE data_oc_numb < 698
    AND num_bids >= 2
  GROUP BY codigogrupo, item_alt
", src)) |> setDT()

log_step("65", sprintf("item_pre = %s items, %d distinct groups",
  format(nrow(item_pre), big.mark = ","),
  length(unique(item_pre$codigogrupo))), logf)

# 2. Derived flags.
item_pre[, treated      := as.integer(codigogrupo == "65")]
item_pre[, below_thresh := as.integer(valor_total_ref < 80000)]
item_pre[, pregao       := 1L - convite]

vars <- c("log_pref", "num_bids", "num_firms", "pregao", "below_thresh",
          "pct_sme_bids", "pct_sp_bids", "log_dist", "final_ref")

# 3. Group-level means: each item one observation within group; then the 76
#    control groups give a distribution of group-mean values for P25/median/P75.
group_means <- item_pre[, lapply(.SD, mean, na.rm = TRUE),
                        .SDcols = vars,
                        by = .(codigogrupo, treated)]

# 4. Headline: G65 vs pooled-control item-level pool, Imbens-Rubin std diff.
g65_items  <- item_pre[treated == 1]
ctrl_items <- item_pre[treated == 0]

n_g65_items   <- nrow(g65_items)
n_ctrl_items  <- nrow(ctrl_items)
n_ctrl_groups <- length(unique(ctrl_items$codigogrupo))

summary_dt <- data.table()
for (v in vars) {
  mu_t <- mean(g65_items[[v]],  na.rm = TRUE)
  sd_t <- sd(  g65_items[[v]],  na.rm = TRUE)
  mu_c <- mean(ctrl_items[[v]], na.rm = TRUE)
  sd_c <- sd(  ctrl_items[[v]], na.rm = TRUE)
  pooled_sd <- sqrt((sd_t^2 + sd_c^2) / 2)
  std_diff  <- if (is.finite(pooled_sd) && pooled_sd > 0) (mu_t - mu_c) / pooled_sd else NA_real_

  ctrl_grp_means <- group_means[treated == 0, get(v)]

  summary_dt <- rbind(summary_dt, data.table(
    variable      = v,
    mu_g65        = mu_t,
    mu_ctrl_p25   = quantile(ctrl_grp_means, 0.25, na.rm = TRUE),
    mu_ctrl_p50   = quantile(ctrl_grp_means, 0.50, na.rm = TRUE),
    mu_ctrl_p75   = quantile(ctrl_grp_means, 0.75, na.rm = TRUE),
    mu_ctrl_mean  = mean(    ctrl_grp_means,        na.rm = TRUE),
    std_diff_IR   = std_diff,
    sd_g65        = sd_t,
    sd_ctrl_pool  = sd_c
  ))
}

abs_std <- abs(summary_dt$std_diff_IR)
max_std       <- max(abs_std, na.rm = TRUE)
n_above_25    <- sum(abs_std > 0.25, na.rm = TRUE)
n_above_10    <- sum(abs_std > 0.10, na.rm = TRUE)

log_step("65", sprintf("max |std diff|=%.3f, vars |>0.25|=%d, vars |>0.10|=%d",
  max_std, n_above_25, n_above_10), logf)
log_step("65", sprintf("g65 items=%s, ctrl items=%s, ctrl groups=%d",
  format(n_g65_items, big.mark = ","),
  format(n_ctrl_items, big.mark = ","),
  n_ctrl_groups), logf)

# Cabeçalho de resumo no log (legível).
cat("\n--- balance summary (Imbens-Rubin std diff, G65 vs pooled controls) ---\n",
    file = logf)
sink(logf, append = TRUE)
print(summary_dt[, .(variable,
                     mu_g65 = round(mu_g65, 3),
                     mu_ctrl_mean = round(mu_ctrl_mean, 3),
                     std_diff_IR = round(std_diff_IR, 3))])
sink()

# 5. Persist.
arrow::write_parquet(summary_dt,
                     path_v6("data/processed/balance_pretreat.parquet"),
                     compression = "snappy")

# Headline scalars (for 98_emit_macros.R).
arrow::write_parquet(
  data.table(
    n_g65_items   = n_g65_items,
    n_ctrl_items  = n_ctrl_items,
    n_ctrl_groups = n_ctrl_groups,
    max_std_diff  = max_std,
    n_vars        = length(vars),
    n_above_25    = n_above_25,
    n_above_10    = n_above_10
  ),
  path_v6("data/processed/balance_pretreat_meta.parquet"),
  compression = "snappy")

# 6. LaTeX table.
var_labels <- c(
  log_pref      = "log reference price",
  num_bids      = "Bids per item",
  num_firms     = "Firms per item",
  pregao        = "Share Preg\\~ao (vs Convite)",
  below_thresh  = "Share items $<$ R\\$80k threshold",
  pct_sme_bids  = "Share SME bids",
  pct_sp_bids   = "Share SP-state bidders",
  log_dist      = "log distance bidder $\\to$ buyer",
  final_ref     = "Final / reference price"
)

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Pre-treatment covariate balance: Group 65 vs.\\ \\balanceNCtrlGroups{} never-treated control groups.}",
  "\\label{tab:balance_pretreat}",
  "\\footnotesize",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\begin{tabular}{l c cccc c}",
  "\\toprule",
  " & \\textbf{Group 65} & \\multicolumn{4}{c}{\\textbf{\\balanceNCtrlGroups{} control groups (group-mean distribution)}} & \\textbf{Std.\\ diff.}\\tnote{a} \\\\",
  "\\cmidrule(lr){3-6}",
  "Variable & mean & P25 & median & P75 & mean & (Imbens--Rubin) \\\\",
  "\\midrule"
)
for (row_i in seq_len(nrow(summary_dt))) {
  r <- summary_dt[row_i]
  tex_lines <- c(tex_lines, sprintf(
    "%s & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f \\\\",
    var_labels[[r$variable]],
    r$mu_g65, r$mu_ctrl_p25, r$mu_ctrl_p50, r$mu_ctrl_p75, r$mu_ctrl_mean,
    r$std_diff_IR
  ))
}
tex_lines <- c(tex_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  sprintf("\\item Sample: pre-period items in the DiD panel (Stata months $<$ \\dataOcCutoff, i.e.\\ Sep 2016--Feb 2018), restricted to auctions with $\\ge 2$ bidders. Group 65 contributes %s items; the \\balanceNCtrlGroups{} never-treated control groups contribute %s items collectively.",
    format(n_g65_items, big.mark = ","), format(n_ctrl_items, big.mark = ",")),
  "\\item Per-group means are computed by collapsing item-level observations within each group; the P25/median/P75/mean columns summarize the distribution of those \\balanceNCtrlGroups{} group-mean values.",
  "\\item[a] Imbens--Rubin normalized difference: $(\\mu_{65} - \\mu_{\\mathrm{ctrl,pool}}) / \\sqrt{(\\sigma^2_{65} + \\sigma^2_{\\mathrm{ctrl,pool}})/2}$, computed on the item-level pool (treated vs.\\ all \\balanceNCtrlGroups{} controls pooled). \\citet{imbens2015} flag $|\\text{std.\\ diff.}| > 0.25$ as ``substantial imbalance'' and $> 0.10$ as warranting attention; item fixed effects in eq.~\\eqref{eq:did} absorb time-invariant cross-item heterogeneity, so this check is informative about cross-group composition rather than identifying-assumption violation. The control-group count of \\balanceNCtrlGroups{} is the empirically distinct set of non-Group-65 product groups with pre-period items meeting the $n \\ge 2$ requirement; the \\controlGroupCount{} figure used elsewhere in the paper refers to the DiD-identifying universe under stricter restrictions (both-period presence at the item-FE level).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex_lines, path_v6("output/tables/tab_balance_pretreat.tex"))

log_step("65", "outputs gravados", logf)
log_step("65", "done", logf)
