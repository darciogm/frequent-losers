# 51_item_level_scope_match.R -- tighten the item-level comparison without
# pretending it solves selection
#
# Outputs:
#   output/item_level_scope_match/item_level_scope_match.csv
#   work/v13/output/tables/tab_item_level_scope_match.tex


if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "item_level_scope_match")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)

dt <- as.data.table(readRDS("/tmp/p3_prepared.rds"))
dt <- dt[!is.na(lneg_price)]
dt[, log_ref_price := log1p(pmax(bid_ref_price_min, 0))]
qt <- quantile(dt$log_ref_price[is.finite(dt$log_ref_price)], probs = seq(0, 1, 0.2), na.rm = TRUE)
dt[, ref_bin := cut(log_ref_price, breaks = unique(qt), include.lowest = TRUE, ordered_result = TRUE)]
dt[, overlap_cell := interaction(item_group, year, convite, pbu_size_q, tender_value_q, drop = TRUE)]
dt[, overlap_ref_cell := interaction(item_group, year, convite, pbu_size_q, tender_value_q, ref_bin, drop = TRUE)]

calc_att_weights <- function(data, cell_var) {
  cell_stats <- data[, .(
    n_treat = sum(losers == 1L),
    n_ctrl = sum(losers == 0L)
  ), by = cell_var]
  keep <- cell_stats[n_treat > 0L & n_ctrl > 0L]
  setnames(keep, cell_var, "cell_key")
  d <- merge(data, keep, by.x = cell_var, by.y = "cell_key", all = FALSE)
  d[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]
  d
}

extract <- function(model, data_used, label, note) {
  ct <- coeftable(model)
  data.table(
    spec = label,
    coef = ct["losers", "Estimate"],
    se = ct["losers", "Std. Error"],
    pval = ct["losers", "Pr(>|t|)"],
    n = model$nobs,
    n_treat = data_used[, sum(losers == 1L)],
    note = note
  )
}

results <- list()

cat("  Baseline FE association ...\n")
m_base <- feols(
  lneg_price ~ losers + convite | item_f + year_f + pbu_f,
  data = dt, cluster = ~item_f, lean = TRUE
)
results[[length(results) + 1L]] <- extract(
  m_base,
  dt,
  "baseline_fe",
  "Main within-item, year, and PBU association"
)

cat("  Overlap-weighted exact-cell match ...\n")
d_cell <- calc_att_weights(dt, "overlap_cell")
m_cell <- feols(
  lneg_price ~ losers + convite | item_f + year_f + pbu_f,
  data = d_cell, weights = ~att_w, cluster = ~item_f, lean = TRUE
)
results[[length(results) + 1L]] <- extract(
  m_cell,
  d_cell,
  "overlap_cell_att",
  "Exact on item-group, year, modality, PBU size, tender-value quartile"
)

cat("  Stricter overlap with reference-price bins ...\n")
d_ref <- calc_att_weights(dt[!is.na(ref_bin)], "overlap_ref_cell")
m_ref <- feols(
  lneg_price ~ losers + convite | item_f + year_f + pbu_f,
  data = d_ref, weights = ~att_w, cluster = ~item_f, lean = TRUE
)
results[[length(results) + 1L]] <- extract(
  m_ref,
  d_ref,
  "overlap_ref_att",
  "Adds pre-bid reference-price bins to the exact overlap design"
)

cat("  Propensity-score ATT weighting on pre-treatment observables ...\n")
ps_fit <- glm(
  losers ~ factor(item_group) + factor(year) + convite +
    factor(pbu_size_q) + factor(tender_value_q) + log_ref_price,
  data = dt[is.finite(log_ref_price)], family = binomial()
)
d_ps <- copy(dt[is.finite(log_ref_price)])
d_ps[, pscore := predict(ps_fit, type = "response")]
d_ps <- d_ps[pscore >= 0.05 & pscore <= 0.95]
d_ps[, att_w := fifelse(losers == 1L, 1, pscore / pmax(1 - pscore, 1e-6))]
m_ps <- feols(
  lneg_price ~ losers + convite | item_f + year_f + pbu_f,
  data = d_ps, weights = ~att_w, cluster = ~item_f, lean = TRUE
)
results[[length(results) + 1L]] <- extract(
  m_ps,
  d_ps,
  "ps_att_trimmed",
  "ATT weights after trimming to common support on observables"
)

res <- rbindlist(results, fill = TRUE)
fwrite(res, file.path(OUT, "item_level_scope_match.csv"))

tex <- c(
  "% JLEO-R1: item-level scope match",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Item-Level Scope Checks: Conditional Association Under Stricter Overlap}",
  "\\label{tab:item_level_scope_match}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  "Specification & Coefficient & SE & $p$-value & $N$ \\\\",
  "\\midrule"
)
esc <- function(x) gsub("_", "\\_", x, fixed = TRUE)
for (i in seq_len(nrow(res))) {
  rr <- res[i]
  tex <- c(
    tex,
    sprintf("%s & $%+.3f$ & $%.3f$ & $%s$ & $%s$ \\\\",
            esc(rr$spec),
            rr$coef,
            rr$se,
            ifelse(rr$pval < 0.001, "<0.001", sprintf("%.3f", rr$pval)),
            format(rr$n, big.mark = "{,}"))
  )
}
tex <- c(
  tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} All rows remain descriptive. The overlap designs tighten comparability by forcing treated and untreated items into the same observed pre-treatment cells; the propensity-score row further trims to common support. None of these designs eliminates selection on unobservables, so the revised paper should call the resulting gap a conditional price association rather than a causal effect.",
  "\\item \\textit{Source:} \\texttt{scripts/51\\_item\\_level\\_scope\\_match.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_item_level_scope_match.tex"))

cat("\n  Item-level scope-match summary:\n")
print(res[, .(spec, coef = round(coef, 4), pval = round(pval, 4), n)])
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "item_level_scope_match.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_item_level_scope_match.tex"), "\n", sep = "")
