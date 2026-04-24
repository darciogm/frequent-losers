# 62 — Buyer heterogeneity in DiD price effect ----------------------
# Splits buyers by pbu_type_mgmt_code into "direct administration"
# (state secretariats, code 1), "indirect" (autarquias, fundações,
# state companies; codes 3-6), and "convenied entities" (code 80).
# Replicates the v1 baseline spec g65_pre + convite + lquantidade |
# item_alt + data_oc_numb and reports the coefficient by group.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({
  library(data.table)
  library(duckdb)
  library(fixest)
})

logf <- file(path_v3("logs/62_buyer_heterogeneity.log"), open = "wt")
on.exit(close(logf), add = TRUE)
log_step("62", "start: buyer heterogeneity (corrected spec)", logf)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

bec_path <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/processed/paper2_me_epp.parquet"

dat <- dbGetQuery(con, sprintf("
  SELECT lpreco_final, lquantidade, convite, item_alt, data_oc_numb,
         pbu_type_mgmt_code,
         CASE WHEN codigogrupo = 65 THEN 1 ELSE 0 END AS g65,
         CASE WHEN data_oc_numb < 698 THEN 1 ELSE 0 END AS Pre,
         CASE WHEN pbu_type_mgmt_code = 1 THEN 'Direct admin'
              WHEN pbu_type_mgmt_code BETWEEN 3 AND 6 THEN 'Indirect admin'
              WHEN pbu_type_mgmt_code = 80 THEN 'Convenied'
              ELSE 'Other' END AS buyer_grp
  FROM read_parquet('%s')
  WHERE oc_item_status = 1
    AND data_oc_numb BETWEEN 680 AND 715
    AND item_alt IS NOT NULL
    AND pbu_type_mgmt_code IS NOT NULL
", bec_path)) |> setDT()

dat[, g65_pre := g65 * Pre]
log_step("62", sprintf("loaded %d rows", nrow(dat)), logf)

# Sample by buyer group
sz <- dat[, .(N = .N, n_g65 = sum(g65), n_g65_pre = sum(g65_pre)),
          by = buyer_grp][order(-N)]
cat("\n--- sample by buyer group ---\n", file = logf)
sink(logf, append = TRUE); print(sz); sink()

# v1 spec: g65_pre + convite + lquantidade | item_alt + data_oc_numb
fit_pool <- feols(lpreco_final ~ g65_pre + convite + lquantidade |
                  item_alt + data_oc_numb,
                  data = dat, cluster = ~item_alt)
b_pool <- coef(fit_pool)["g65_pre"]
s_pool <- se(fit_pool)["g65_pre"]
p_pool <- pvalue(fit_pool)["g65_pre"]
log_step("62", sprintf("pooled g65_pre = %.4f (se %.4f)",
                       b_pool, s_pool), logf)

keep_grps <- sz[n_g65_pre >= 200, buyer_grp]
log_step("62", sprintf("groups kept (>= 200 g65_pre obs): %s",
                       paste(keep_grps, collapse = ", ")), logf)

res <- list()
for (grp in keep_grps) {
  sub <- dat[buyer_grp == grp]
  if (nrow(sub) < 5000) next
  fit <- feols(lpreco_final ~ g65_pre + convite + lquantidade |
               item_alt + data_oc_numb,
               data = sub, cluster = ~item_alt)
  res[[grp]] <- data.table(
    buyer_grp = grp,
    n        = nobs(fit),
    n_g65pre = sub[, sum(g65_pre)],
    coef     = round(coef(fit)["g65_pre"], 4),
    se       = round(se(fit)["g65_pre"], 4),
    p        = round(pvalue(fit)["g65_pre"], 4))
}
res_dt <- rbindlist(res)

cat("\n--- DiD by buyer group ---\n", file = logf)
sink(logf, append = TRUE); print(res_dt); sink()

# Interaction model for chow-style equality test
sub_int <- dat[buyer_grp %in% keep_grps]
sub_int[, buyer_f := factor(buyer_grp, levels = keep_grps)]
fit_inter <- feols(lpreco_final ~ g65_pre * buyer_f + convite + lquantidade |
                   item_alt + data_oc_numb,
                   data = sub_int, cluster = ~item_alt)
log_step("62", "interaction model fitted", logf)

# Wald test: are interaction coefficients zero?
wald_res <- wald(fit_inter, "g65_pre:")

# LaTeX table
fmt_p <- function(p) ifelse(p < 0.001, "$<0.001$", sprintf("%.3f", p))
tex <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\small",
  "\\caption{DiD price coefficient by buyer-unit type}",
  "\\label{tab:v3_buyer_het}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lrrrrr}",
  "\\toprule",
  "Buyer type & $N$ & $n_{g65 \\times Pre}$ & $\\hat\\beta_{g65\\_pre}$ & SE & $p$-value \\\\",
  "\\midrule",
  sprintf("\\textbf{Pooled (all buyer types)} & %s & %s & %.4f & %.4f & %s \\\\",
          format(nobs(fit_pool), big.mark = ","),
          format(dat[, sum(g65_pre)], big.mark = ","),
          b_pool, s_pool, fmt_p(p_pool)),
  "\\midrule")

for (i in seq_len(nrow(res_dt))) {
  r <- res_dt[i]
  tex <- c(tex, sprintf(
    "\\quad %s & %s & %s & %.4f & %.4f & %s \\\\",
    r$buyer_grp,
    format(r$n,        big.mark = ","),
    format(r$n_g65pre, big.mark = ","),
    r$coef, r$se, fmt_p(r$p)))
}

tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Specification: $\\log p_{\\mathit{final},\\,it} = \\beta \\cdot",
  "(\\mathit{g65}_i \\cdot \\mathit{Pre}_t) + \\delta \\cdot \\mathit{convite}_{it}",
  "+ \\theta \\cdot \\log q_{it} + \\gamma_i + \\gamma_t + \\varepsilon_{it}$,",
  "with item ($\\gamma_i$) and month ($\\gamma_t$) fixed effects, and",
  "standard errors clustered by item. Sample: 18-month symmetric",
  "window around the March 2018 cutoff, completed items only. The",
  "coefficient $\\hat\\beta_{g65\\_pre}$ on $g65 \\times Pre$ is the",
  "DiD effect of being in Group~65 \\emph{during the open period}",
  "(when the SME-only rule did not yet bind); a negative coefficient",
  "thus indicates that prices were lower in the open period than",
  "after March 2018, i.e., the SME-only rule raises winning prices.",
  "Buyer types: \\textit{Direct admin} (state secretariats, code 1);",
  "\\textit{Indirect admin} (autarquias, funda\\c{c}\\~oes, state companies,",
  "codes 3--6); only buyer groups with $\\geq 200$ treated observations",
  "are reported. The pooled estimate exactly replicates the headline of",
  "Table~\\ref{tab:prices}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")

writeLines(tex, path_v3("output/tables/tab_v3_buyer_het.tex"))
log_step("62", "saved tab_v3_buyer_het.tex", logf)
log_step("62", "done", logf)
