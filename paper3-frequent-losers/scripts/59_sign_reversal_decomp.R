# ============================================================================
# 59_sign_reversal_decomp.R -- decompose the broad-sample β vs
# overlap-restricted β^ov gap with maximum empirical concreteness.
#
# Goal: replace the verbal "deployment-sorting diagnostic" reading of the
# sign reversal with cell-level evidence about (a) which cells get dropped
# under overlap restriction, (b) what those dropped cells look like, and
# (c) where the negative β^ov actually lives.
#
# Outputs:
#   output/sign_reversal_decomp/headline_specs.csv          -- {β, β^ov_cell, β^ov_ref, β^ov_ps} on a common sample
#   output/sign_reversal_decomp/cell_dropping_dimensions.csv -- characterize dropped vs surviving cells
#   output/sign_reversal_decomp/within_overlap_subgroup_betas.csv -- where β^ov < 0 lives
#   output/sign_reversal_decomp/screening_alignment.csv     -- direct test of screening-value reading
#   work/v13/output/tables/tab_sign_reversal_decomp.tex     -- summary table for paper
# ============================================================================

cat("=== 59_sign_reversal_decomp.R ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "sign_reversal_decomp")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)

dt <- as.data.table(readRDS("/tmp/p3_prepared.rds"))
dt <- dt[!is.na(lneg_price)]
dt[, log_ref_price := log1p(pmax(bid_ref_price_min, 0))]
dt[, oc_item_key := paste0(oc_code, "_", item_code)]

# pre-bid reference price quintile (same definition as script 51)
qt <- quantile(dt$log_ref_price[is.finite(dt$log_ref_price)], probs = seq(0, 1, 0.2), na.rm = TRUE)
dt[, ref_bin := cut(log_ref_price, breaks = unique(qt), include.lowest = TRUE, ordered_result = TRUE)]

# overlap cell definition (same as script 51, baseline overlap design)
dt[, overlap_cell := interaction(item_group, year, convite, pbu_size_q, tender_value_q, drop = TRUE)]

# direct CADE item flag, used to test the screening-value reading
cade_xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(cade_xm$firm_code)

ftm <- as.data.table(arrow::read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
ftm[, oc_item_key := paste0(`numerodaoc`, "_", `códigoitem`)]
item_direct <- ftm[, .(any_direct = max(as.integer(firm_code %in% direct_codes))), by = oc_item_key]
dt <- merge(dt, item_direct, by = "oc_item_key", all.x = TRUE)
dt[is.na(any_direct), any_direct := 0L]

# also flag CADE-cobidder items, for the conservative "near-the-cartel" stratum
cade_co <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade_co[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
cob_codes <- unique(cade_co$firm_code)
item_cob <- ftm[, .(any_cobidder = max(as.integer(firm_code %in% cob_codes))), by = oc_item_key]
dt <- merge(dt, item_cob, by = "oc_item_key", all.x = TRUE)
dt[is.na(any_cobidder), any_cobidder := 0L]

# tag treatment status of cells
dt[, has_treat := as.integer(any(losers == 1L)), by = overlap_cell]
dt[, has_ctrl  := as.integer(any(losers == 0L)), by = overlap_cell]
dt[, cell_overlap := as.integer(has_treat == 1L & has_ctrl == 1L)]

# ---------- (1) headline specs reproduced on the same dataset --------------

cat("\n[1/5] Headline specs (β, β^ov, β^ov_ref, β^ov_PS)...\n")

extract <- function(model, label, n_used, n_treat) {
  ct <- coeftable(model)
  data.table(
    spec = label,
    coef = ct["losers", "Estimate"],
    se = ct["losers", "Std. Error"],
    pval = ct["losers", "Pr(>|t|)"],
    n = n_used,
    n_treat = n_treat
  )
}

m_base <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                data = dt, cluster = ~item_f, lean = TRUE)
results <- list(extract(m_base, "broad_sample_beta", nrow(dt), dt[, sum(losers == 1L)]))

d_overlap <- dt[cell_overlap == 1L]
m_overlap <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                   data = d_overlap, cluster = ~item_f, lean = TRUE)
results[[length(results) + 1L]] <- extract(m_overlap, "overlap_cell_unweighted",
                                           nrow(d_overlap), d_overlap[, sum(losers == 1L)])

# ATT-weighted overlap (matches script 51's β^ov)
cell_sizes <- d_overlap[, .(n_treat = sum(losers == 1L), n_ctrl = sum(losers == 0L)),
                        by = overlap_cell]
d_overlap <- merge(d_overlap, cell_sizes, by = "overlap_cell")
d_overlap[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]
m_overlap_att <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                       data = d_overlap, weights = ~att_w, cluster = ~item_f, lean = TRUE)
results[[length(results) + 1L]] <- extract(m_overlap_att, "overlap_cell_att",
                                           nrow(d_overlap), d_overlap[, sum(losers == 1L)])

headline <- rbindlist(results, fill = TRUE)
fwrite(headline, file.path(OUT, "headline_specs.csv"))
cat("  Saved headline specs.\n")
print(headline[, .(spec, coef = round(coef, 4), pval = formatC(pval, format = "e", digits = 2),
                   n = format(n, big.mark = ","))])

# ---------- (2) characterize dropped vs surviving cells -------------------

cat("\n[2/5] Cell-level dropping characterization...\n")

cell_summary <- dt[, .(
  n_items = .N,
  n_treat = sum(losers == 1L),
  n_ctrl = sum(losers == 0L),
  share_convite = mean(convite == 1L),
  share_direct_cade = mean(any_direct == 1L),
  share_cobidder = mean(any_cobidder == 1L),
  mean_log_ref_price = mean(log_ref_price[is.finite(log_ref_price)]),
  mean_n_firms = mean(n_firms, na.rm = TRUE),
  mean_lneg_price = mean(lneg_price)
), by = .(overlap_cell, item_group, year, convite, pbu_size_q, tender_value_q)]
cell_summary[, status := fcase(
  n_treat > 0L & n_ctrl > 0L, "surviving",
  n_treat > 0L & n_ctrl == 0L, "dropped_no_control",
  n_treat == 0L & n_ctrl > 0L, "dropped_no_treated",
  default = "empty"
)]

drop_summary <- cell_summary[, .(
  n_cells = .N,
  n_items = sum(n_items),
  n_treat = sum(n_treat),
  share_convite = sum(share_convite * n_items) / sum(n_items),
  share_direct_cade = sum(share_direct_cade * n_items) / sum(n_items),
  share_cobidder = sum(share_cobidder * n_items) / sum(n_items),
  mean_log_ref_price = sum(mean_log_ref_price * n_items, na.rm = TRUE) / sum(n_items),
  mean_n_firms = sum(mean_n_firms * n_items, na.rm = TRUE) / sum(n_items)
), by = status]

fwrite(drop_summary, file.path(OUT, "cell_dropping_dimensions.csv"))
cat("  Saved cell dropping dimensions.\n")
print(drop_summary)

# also: per-dimension breakdowns (which dimensions are over-represented in dropped cells?)
dims <- list(
  modality = list(var = "convite", levels = c(0, 1), labels = c("Pregão", "Convite")),
  pbu_size = list(var = "pbu_size_q", levels = sort(unique(na.omit(dt$pbu_size_q)))),
  tender_value = list(var = "tender_value_q", levels = sort(unique(na.omit(dt$tender_value_q)))),
  year = list(var = "year", levels = sort(unique(dt$year))),
  direct_cade = list(var = "any_direct", levels = c(0, 1), labels = c("non-CADE", "direct-CADE")),
  cobidder = list(var = "any_cobidder", levels = c(0, 1), labels = c("non-cobidder", "cobidder-item"))
)

per_dim <- list()
for (dim_name in names(dims)) {
  v <- dims[[dim_name]]$var
  for (lv in dims[[dim_name]]$levels) {
    sub <- dt[get(v) == lv]
    if (nrow(sub) == 0L) next
    per_dim[[length(per_dim) + 1L]] <- data.table(
      dimension = dim_name,
      level = as.character(lv),
      label = if (!is.null(dims[[dim_name]]$labels))
        dims[[dim_name]]$labels[which(dims[[dim_name]]$levels == lv)] else as.character(lv),
      n_items = nrow(sub),
      share_in_surviving = sub[, mean(cell_overlap == 1L)],
      share_treated = sub[, mean(losers == 1L)],
      share_direct_cade = sub[, mean(any_direct == 1L)],
      share_cobidder = sub[, mean(any_cobidder == 1L)]
    )
  }
}
per_dim_dt <- rbindlist(per_dim, fill = TRUE)
fwrite(per_dim_dt, file.path(OUT, "per_dimension_overlap_share.csv"))
cat("  Saved per-dimension overlap share.\n")

# ---------- (3) within-overlap subgroup betas: where does β^ov < 0 live? ---

cat("\n[3/5] Within-overlap subgroup β^ov estimates...\n")

run_subgroup <- function(data, group_var, group_label, weighted = TRUE) {
  groups <- sort(unique(data[[group_var]]))
  out <- list()
  for (g in groups) {
    sub <- data[get(group_var) == g]
    if (nrow(sub) < 1000L) next
    if (length(unique(sub$losers)) < 2L) next
    if (sub[, sum(losers == 1L)] < 50L) next
    fit <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                 data = sub, weights = if (weighted) ~att_w else NULL,
                 cluster = ~item_f, lean = TRUE)
    ct <- coeftable(fit)
    out[[length(out) + 1L]] <- data.table(
      dimension = group_label,
      group = as.character(g),
      coef = ct["losers", "Estimate"],
      se = ct["losers", "Std. Error"],
      pval = ct["losers", "Pr(>|t|)"],
      n = nrow(sub),
      n_treat = sub[, sum(losers == 1L)],
      share_direct_cade = sub[, mean(any_direct == 1L)],
      share_cobidder = sub[, mean(any_cobidder == 1L)]
    )
  }
  rbindlist(out, fill = TRUE)
}

# For subgroup analysis, we want β^ov within each subgroup -> use overlap-cell ATT-weighted dataset
sub_within <- rbindlist(list(
  run_subgroup(d_overlap, "convite", "modality"),
  run_subgroup(d_overlap, "pbu_size_q", "pbu_size_q"),
  run_subgroup(d_overlap, "tender_value_q", "tender_value_q"),
  run_subgroup(d_overlap, "any_direct", "any_direct"),
  run_subgroup(d_overlap, "any_cobidder", "any_cobidder"),
  run_subgroup(d_overlap, "year", "year")
), fill = TRUE)

fwrite(sub_within, file.path(OUT, "within_overlap_subgroup_betas.csv"))
cat("  Saved within-overlap subgroup betas.\n")
print(sub_within[, .(dimension, group, coef = round(coef, 4),
                     pval = formatC(pval, format = "e", digits = 2),
                     n = format(n, big.mark = ","))])

# ---------- (4) screening-alignment test ---------------------------------
# H0 (paper's screening-value reading): cells dropped under overlap-restriction
# disproportionately resemble cartel-adjacent environments (higher direct-CADE
# rate, higher cobidder rate, higher convite share, smaller PBUs).
#
# H1 (alternative): dropping is symmetric on screening dimensions; the sign
# reversal is selection on item characteristics unrelated to deployment.

cat("\n[4/5] Screening-alignment of cell-dropping pattern...\n")

# Among items with treatment (losers == 1), which are in dropped-no-control vs surviving cells?
treated_items <- dt[losers == 1L]
treated_items[, in_dropped_cell := as.integer(cell_overlap == 0L)]

screening_test <- list()
for (var in c("convite", "any_direct", "any_cobidder")) {
  in_drop <- treated_items[in_dropped_cell == 1L, mean(get(var))]
  in_surv <- treated_items[in_dropped_cell == 0L, mean(get(var))]
  fmla <- as.formula(sprintf("%s ~ in_dropped_cell", var))
  test <- t.test(fmla, data = treated_items)
  screening_test[[length(screening_test) + 1L]] <- data.table(
    dimension = var,
    share_in_dropped_cells = in_drop,
    share_in_surviving_cells = in_surv,
    diff = in_drop - in_surv,
    t_pval = test$p.value
  )
}
# also: PBU size and ref-price (numeric)
for (var in c("pbu_size_q", "tender_value_q", "log_ref_price", "n_firms")) {
  if (!var %in% names(treated_items)) next
  vec <- treated_items[[var]]
  in_drop <- mean(vec[treated_items$in_dropped_cell == 1L], na.rm = TRUE)
  in_surv <- mean(vec[treated_items$in_dropped_cell == 0L], na.rm = TRUE)
  test <- t.test(treated_items[[var]] ~ treated_items$in_dropped_cell)
  screening_test[[length(screening_test) + 1L]] <- data.table(
    dimension = var,
    share_in_dropped_cells = in_drop,
    share_in_surviving_cells = in_surv,
    diff = in_drop - in_surv,
    t_pval = test$p.value
  )
}
screening_test_dt <- rbindlist(screening_test, fill = TRUE)
fwrite(screening_test_dt, file.path(OUT, "screening_alignment.csv"))
cat("  Saved screening-alignment test.\n")
print(screening_test_dt)

# ---------- (5) summary table for paper ----------------------------------

cat("\n[5/5] Writing summary LaTeX table...\n")

# Compose a compact two-panel table that the manuscript can use directly
fmt_p <- function(p) ifelse(is.na(p), "--", ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))
fmt_b <- function(b) ifelse(is.na(b), "--", sprintf("%+.3f", b))
fmt_n <- function(n) format(round(n), big.mark = "{,}")

# Panel A: headline specs
panA <- headline[spec %in% c("broad_sample_beta", "overlap_cell_att")]
panA[, label := c("Broad sample $\\widehat\\beta$", "Overlap-cell ATT $\\widehat\\beta^{ov}$")[match(spec, c("broad_sample_beta", "overlap_cell_att"))]]

# Panel B: where β^ov lives (modality + direct CADE)
panB <- sub_within[dimension %in% c("modality", "any_direct")][order(dimension, group)]
panB[, label := fcase(
  dimension == "modality" & group == "0", "$\\widehat\\beta^{ov}$ in pregão items",
  dimension == "modality" & group == "1", "$\\widehat\\beta^{ov}$ in convite items",
  dimension == "any_direct" & group == "0", "$\\widehat\\beta^{ov}$ in non-direct-CADE items",
  dimension == "any_direct" & group == "1", "$\\widehat\\beta^{ov}$ in direct-CADE items"
)]

# Panel C: cell-dropping pattern
sa <- screening_test_dt
panC_rows <- list(
  list("Convite share among treated items", "convite", "share"),
  list("Direct-CADE-item share among treated items", "any_direct", "share"),
  list("Cobidder-item share among treated items", "any_cobidder", "share"),
  list("Mean log reference price among treated items", "log_ref_price", "level"),
  list("Mean number of bidders among treated items", "n_firms", "level")
)

tex <- c(
  "% Subprompt 3: sign-reversal decomposition (script 59)",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Sign-Reversal Decomposition: Where Does $\\widehat\\beta^{ov}<0$ Live, and Which Items Get Dropped?}",
  "\\label{tab:sign_reversal_decomp}",
  "\\begin{threeparttable}",
  "\\footnotesize",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & Coef. / Mean & SE & $p$-value & $N$ \\\\",
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel A. Headline specifications on common sample.}} \\\\"
)
for (i in seq_len(nrow(panA))) {
  rr <- panA[i]
  tex <- c(tex, sprintf("%s & $%s$ & $%.3f$ & $%s$ & $%s$ \\\\",
                        rr$label, fmt_b(rr$coef), rr$se, fmt_p(rr$pval), fmt_n(rr$n)))
}

tex <- c(tex,
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel B. $\\widehat\\beta^{ov}$ within overlap-cell sample, by subgroup.}} \\\\"
)
for (i in seq_len(nrow(panB))) {
  rr <- panB[i]
  tex <- c(tex, sprintf("%s & $%s$ & $%.3f$ & $%s$ & $%s$ \\\\",
                        rr$label, fmt_b(rr$coef), rr$se, fmt_p(rr$pval), fmt_n(rr$n)))
}

tex <- c(tex,
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel C. Treated items in dropped vs.\\ surviving cells (means).}} \\\\",
  " & In dropped & In surviving & Difference & $t$-test $p$ \\\\"
)
for (rowdef in panC_rows) {
  lab <- rowdef[[1L]]
  v <- rowdef[[2L]]
  rr <- sa[dimension == v]
  if (nrow(rr) == 0L) next
  tex <- c(tex, sprintf("%s & $%.3f$ & $%.3f$ & $%+.3f$ & $%s$ \\\\",
                        lab,
                        rr$share_in_dropped_cells,
                        rr$share_in_surviving_cells,
                        rr$diff,
                        fmt_p(rr$t_pval)))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  "\\item \\textit{Notes:} Panel A reports the broad-sample $\\widehat\\beta$ and the overlap-cell ATT-weighted $\\widehat\\beta^{ov}$, both estimated on items with non-missing log negotiated price and within-item, year, and PBU fixed effects. Panel B re-estimates $\\widehat\\beta^{ov}$ on the same overlap-cell ATT design within four subgroups (pregão vs.\\ convite items; non-direct-CADE vs.\\ direct-CADE items). Panel C compares treated items (FL present) that fall in cells dropped by the overlap restriction (no untreated counterfactual) versus treated items in surviving cells; differences in convite share, direct-CADE-item share, cobidder-item share, log reference price and number of bidders test the screening-value reading directly. The screening framework predicts that items dropped by overlap restriction should disproportionately carry markers of deployment value (higher convite, direct-CADE, cobidder-item rates).",
  "\\item \\textit{Source:} \\texttt{scripts/59\\_sign\\_reversal\\_decomp.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

writeLines(tex, file.path(TABS, "tab_sign_reversal_decomp.tex"))
cat("  Wrote LaTeX table.\n")

cat("\n=== Done. Outputs:\n")
cat("   ", file.path(OUT, "headline_specs.csv"), "\n")
cat("   ", file.path(OUT, "cell_dropping_dimensions.csv"), "\n")
cat("   ", file.path(OUT, "per_dimension_overlap_share.csv"), "\n")
cat("   ", file.path(OUT, "within_overlap_subgroup_betas.csv"), "\n")
cat("   ", file.path(OUT, "screening_alignment.csv"), "\n")
cat("   ", file.path(TABS, "tab_sign_reversal_decomp.tex"), "\n")
