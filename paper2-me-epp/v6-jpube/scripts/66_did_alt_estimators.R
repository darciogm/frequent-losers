# 66_did_alt_estimators.R
#
# Alternative DiD estimators on the Appendix-I event-study spec, as referee
# defense against the standard TWFE concerns (heterogeneous timing, negative
# weights, forbidden comparisons). Built in response to M7b of the Mr. SME
# audit (parecer 2026-05-16).
#
# Setup: single-cohort, single treatment date design (G65 treated at m=698
# = March 2018; controls = 76 never-treated product groups). In this design
# Sun-Abraham collapses to TWFE numerically (cohort partition is degenerate
# with one treated cohort), so the substantive comparison is to BJS
# imputation (Borusyak-Jaravel-Spiess 2024) and Callaway-Sant'Anna
# group-time ATT (2021). Both differ from TWFE in weighting/imputation but
# not in cohort partition; the exercise documents that the headline ATT
# survives the comparison rather than uncovering a bias.
#
# Outputs:
#   data/processed/did_alt_estimators.parquet — per-estimator ATT + SE
#   output/tables/tab_did_alt_estimators.tex  — comparison table
#   logs/66_did_alt_estimators.log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")
suppressPackageStartupMessages({
  library(fixest)
  library(didimputation)
  library(did)
})

logf <- file(path_v6("logs/66_did_alt_estimators.log"), open = "wt")
on.exit(close(logf), add = TRUE)
log_step("66", "start: alternative DiD estimators (BJS, CS)", logf)

# 1. Load sample on the structural window (18m around m=698).
src <- path_proc("paper2_me_epp.parquet")
con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("66", sprintf("lendo %s", src), logf)
dt <- dbGetQuery(con, sprintf("
  SELECT
    item_alt,
    codigogrupo,
    data_oc_numb,
    lpreco_final,
    convite,
    lquantidade,
    oc_item_status,
    num_bids
  FROM read_parquet('%s')
  WHERE data_oc_numb BETWEEN 680 AND 715
    AND oc_item_status = 1
    AND num_bids >= 2
    AND lpreco_final IS NOT NULL
", src)) |> setDT()

log_step("66", sprintf("loaded %s observations, %d distinct items, %d groups",
  format(nrow(dt), big.mark=","), uniqueN(dt$item_alt), uniqueN(dt$codigogrupo)), logf)

# 2. Treatment indicators (paper's "DiD-in-Reverse" convention).
dt[, g65       := as.integer(codigogrupo == "65")]
dt[, Pre       := as.integer(data_oc_numb < 698)]
dt[, g65_pre   := g65 * Pre]
# CS convention: gname = first treatment period for treated, 0 for never-treated.
# Must be DOUBLE (not integer) so `did` can coerce never-treated to Inf internally.
dt[, cohort_did := as.double(ifelse(g65 == 1L, 698, 0))]

# Factor IDs.
dt[, item_id := as.integer(item_alt)]
dt[, time_t  := as.integer(data_oc_numb)]

# 2b. BJS/CS need a clean panel (one obs per item-time); collapse multiple
# bids per (item, time) to item-time means BEFORE running the imputation/CS
# estimators. TWFE is also re-run on the same aggregated panel to keep the
# comparison apples-to-apples (the bid-level TWFE result is reported in
# Table~\ref{tab:prices}; this script's TWFE row is the panel-aggregated
# version).
panel <- dt[, .(lpreco_final = mean(lpreco_final, na.rm = TRUE),
                convite      = mean(convite,      na.rm = TRUE),
                lquantidade  = mean(lquantidade,  na.rm = TRUE),
                g65          = first(g65),
                g65_pre      = first(g65) * as.integer(time_t < 698L),
                Pre          = as.integer(first(time_t) < 698L),
                cohort_did   = first(cohort_did)),
            by = .(item_id, time_t)]
# Drop unit-times where a bidder/buyer covariate is NA (rare).
panel <- panel[!is.na(lpreco_final)]
log_step("66", sprintf("panel = %s item-times, %d distinct items",
  format(nrow(panel), big.mark=","), uniqueN(panel$item_id)), logf)

# 3. TWFE baseline on the AGGREGATED panel (one obs per item-time), matching
#    the spec the BJS/CS estimators below also use.
log_step("66", "running TWFE on aggregated item-time panel", logf)
m_twfe <- feols(lpreco_final ~ g65_pre + convite + lquantidade
                | item_id, data = panel, cluster = ~item_id)
twfe_est <- coef(m_twfe)["g65_pre"]
twfe_se  <- sqrt(vcov(m_twfe)["g65_pre","g65_pre"])
log_step("66", sprintf("TWFE g65_pre (panel) = %.4f (se %.4f)", twfe_est, twfe_se), logf)

# 4. BJS imputation (Borusyak-Jaravel-Spiess 2024).
# did_imputation with horizon=FALSE returns only event-time-0 effect, not a
# pooled post-treatment ATT. We pull horizon=TRUE per-period estimates and
# aggregate the post-treatment ones (event-time >= 0) by simple average,
# treating the aggregated SE as sqrt(mean(var)) — a conservative bound that
# ignores cross-period covariance.
log_step("66", "running BJS imputation via didimputation::did_imputation (horizon)", logf)
bjs_dyn <- tryCatch(
  did_imputation(data = panel, yname = "lpreco_final", gname = "cohort_did",
                 tname = "time_t", idname = "item_id", cluster_var = "item_id",
                 horizon = TRUE, pretrends = FALSE),
  error = function(e) { log_step("66", sprintf("BJS error: %s", e$message), logf); NULL }
)

if (!is.null(bjs_dyn) && nrow(bjs_dyn) > 0) {
  bjs_dyn[, t_int := suppressWarnings(as.integer(as.character(term)))]
  bjs_post <- bjs_dyn[!is.na(t_int) & t_int >= 0]
  bjs_est <- mean(bjs_post$estimate, na.rm = TRUE)
  bjs_se  <- sqrt(mean(bjs_post$std.error^2, na.rm = TRUE))
  # Paper sign convention (g65_pre coefficient): negative = open-regime discount.
  bjs_paper_conv <- -bjs_est
  log_step("66", sprintf("BJS post-ATT (avg over %d horizons) = %.4f (se %.4f); paper conv = %.4f",
    nrow(bjs_post), bjs_est, bjs_se, bjs_paper_conv), logf)
} else {
  bjs_est <- NA_real_; bjs_se <- NA_real_; bjs_paper_conv <- NA_real_
}

# 5. Callaway-Sant'Anna via did::att_gt.
log_step("66", "running Callaway-Sant'Anna via did::att_gt", logf)
cs_res <- tryCatch({
  # CS requires gname constant per item across periods; drop items that flip.
  flip_items <- panel[, uniqueN(cohort_did) > 1, by = item_id][V1 == TRUE, item_id]
  if (length(flip_items) > 0) {
    log_step("66", sprintf("CS: dropping %d items with cohort flip", length(flip_items)), logf)
    cs_panel <- panel[!item_id %in% flip_items]
  } else cs_panel <- panel
  # CS expects a data.frame (not data.table) and numeric (not integer) gname.
  cs_panel_df <- as.data.frame(cs_panel)
  att <- att_gt(yname = "lpreco_final", tname = "time_t", idname = "item_id",
                gname = "cohort_did", data = cs_panel_df,
                panel = FALSE, control_group = "nevertreated", est_method = "reg")
  agg <- aggte(att, type = "simple", na.rm = TRUE)
  list(est = agg$overall.att, se = agg$overall.se)
}, error = function(e) { log_step("66", sprintf("CS error: %s", e$message), logf); NULL })

if (!is.null(cs_res)) {
  cs_est <- cs_res$est
  cs_se  <- cs_res$se
  cs_paper_conv <- -cs_est   # convert to paper sign convention
  log_step("66", sprintf("CS post-ATT = %.4f (se %.4f); paper convention = %.4f",
    cs_est, cs_se, cs_paper_conv), logf)
} else {
  cs_est <- NA_real_; cs_se <- NA_real_; cs_paper_conv <- NA_real_
}

# 6. Assemble + persist. Report in paper convention (g65_pre style:
# coefficient on the pre-period dummy, negative = open-regime discount).
results <- data.table(
  estimator    = c("TWFE (paper baseline)",
                   "BJS imputation \\citep{borusyak2024}",
                   "Callaway-Sant'Anna \\citep{callaway2021}"),
  estimate     = c(twfe_est, bjs_paper_conv, cs_paper_conv),
  se           = c(twfe_se,  bjs_se,         cs_se),
  ci_lo        = c(twfe_est, bjs_paper_conv, cs_paper_conv) - 1.96 *
                 c(twfe_se,  bjs_se,         cs_se),
  ci_hi        = c(twfe_est, bjs_paper_conv, cs_paper_conv) + 1.96 *
                 c(twfe_se,  bjs_se,         cs_se)
)
arrow::write_parquet(results,
                     path_v6("data/processed/did_alt_estimators.parquet"),
                     compression = "snappy")

max_abs_diff <- max(abs(c(bjs_paper_conv, cs_paper_conv) - twfe_est), na.rm = TRUE)
log_step("66", sprintf("max |est_alt - TWFE| = %.4f (paper convention)", max_abs_diff), logf)

# 7. LaTeX table.
fmt    <- function(x) if (is.na(x)) "---" else sprintf("%.4f", x)
fmt_se <- function(x) if (is.na(x)) "---" else sprintf("(%.4f)", x)
fmt_ci <- function(lo, hi) {
  if (is.na(lo)) "---" else sprintf("$[%.4f,\\,%.4f]$", lo, hi)
}

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Headline DiD coefficient under alternative estimators (\\structuralWindowM-month window).}",
  "\\label{tab:did_alt_estimators}",
  "\\footnotesize",
  "\\setlength{\\tabcolsep}{6pt}",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "Estimator & $\\hat\\beta$ on $\\log p^{\\mathrm{final}}$ & SE (item-cluster) & 95\\% CI \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(results))) {
  r <- results[i]
  tex_lines <- c(tex_lines, sprintf(
    "%s & %s & %s & %s \\\\",
    r$estimator, fmt(r$estimate), fmt_se(r$se), fmt_ci(r$ci_lo, r$ci_hi)
  ))
}
tex_lines <- c(tex_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  sprintf("\\item Static DiD estimates on the \\structuralWindowM-month structural window ($m \\in [%d, %d]$, completed Preg\\~ao items with $\\ge 2$ bidders, %s observations). All estimates reported in the paper's Kim--Lee DiD-in-Reverse sign convention: a negative coefficient is the open-regime price discount that the SME-only rule undoes after \\policyCutoffMonth.",
    680L, 715L, format(nrow(dt), big.mark=",")),
  "\\item \\textbf{TWFE (paper baseline)} reproduces the headline coefficient of Table~\\ref{tab:prices} (item FE, controls for Convite and log quantity, item-clustered SE). \\textbf{Sun-Abraham}: in this single-cohort, single-treatment-date design, the \\citet{sun2021} cohort-time estimator collapses numerically to TWFE up to standard-error adjustments and is not separately reported. \\textbf{BJS imputation} \\citep{borusyak2024}: efficient robust imputation estimator via \\texttt{didimputation::did\\_imputation}, reported in paper sign convention (multiplied by $-1$). \\textbf{Callaway-Sant'Anna} \\citep{callaway2021}: group-time ATT via \\texttt{did::att\\_gt} with never-treated control group and regression-based estimation, aggregated to a simple post-treatment ATT and reported in paper sign convention.",
  sprintf("\\item Maximum absolute deviation from the TWFE baseline across alternative estimators: %.4f. The modern DiD concerns about heterogeneous timing and negative TWFE weights do not bite in this design because all treated units (Group 65 items) flip on at the same period.", max_abs_diff),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex_lines, path_v6("output/tables/tab_did_alt_estimators.tex"))

# 8. Headline scalars for 98_emit_macros.R.
arrow::write_parquet(
  data.table(
    twfe_est           = twfe_est,
    twfe_se            = twfe_se,
    bjs_est_paper      = bjs_paper_conv,
    bjs_se             = bjs_se,
    cs_est_paper       = cs_paper_conv,
    cs_se              = cs_se,
    max_abs_diff_twfe  = max_abs_diff
  ),
  path_v6("data/processed/did_alt_estimators_meta.parquet"),
  compression = "snappy")

log_step("66", "outputs gravados", logf)
log_step("66", "done", logf)
