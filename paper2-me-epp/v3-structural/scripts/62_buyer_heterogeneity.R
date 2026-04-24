# 62 — Buyer heterogeneity in DiD price effect ----------------------
# Splits buyers by pbu_type_mgmt_code into "direct administration"
# (state secretariats, code 1), "indirect" (autarquias, fundações,
# state companies; codes 3-6), and "convenied entities" (code 80).
# Runs the headline DiD interacted with buyer type and reports the
# coefficient by group.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({
  library(data.table)
  library(duckdb)
  library(fixest)
})

logf <- file(path_v3("logs/62_buyer_heterogeneity.log"), open = "wt")
on.exit(close(logf), add = TRUE)
log_step("62", "start: buyer heterogeneity", logf)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

bec_path <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/processed/paper2_me_epp.parquet"

# Load 18-month window, completed items, with buyer type
dat <- dbGetQuery(con, sprintf("
  SELECT log(preco_final) AS lprice,
         CASE WHEN codigogrupo = 65 THEN 1 ELSE 0 END AS g65,
         CASE WHEN data_oc_numb >= 698 THEN 1 ELSE 0 END AS post,
         CASE WHEN pbu_type_mgmt_code = 1 THEN 'Direct admin'
              WHEN pbu_type_mgmt_code BETWEEN 3 AND 6 THEN 'Indirect admin'
              WHEN pbu_type_mgmt_code = 80 THEN 'Convenied'
              ELSE 'Other' END AS buyer_grp,
         pbu_type_mgmt_code,
         item_alt,
         data_oc_numb,
         log(GREATEST(1, COALESCE(numfornecs_type_me_ph2, 0)
                       + COALESCE(numfornecs_type_epp_ph2, 0)
                       + COALESCE(numfornecs_type_oth_ph2, 0))) AS lqty
  FROM read_parquet('%s')
  WHERE oc_item_status = 1
    AND preco_final > 0
    AND data_oc_numb BETWEEN 680 AND 715
    AND item_alt IS NOT NULL
    AND pbu_type_mgmt_code IS NOT NULL
", bec_path)) |> setDT()

log_step("62", sprintf("loaded %d completed item-rows", nrow(dat)), logf)

dat[, treat := g65 * post]
dat[, lprice_w := pmin(pmax(lprice, quantile(lprice, 0.005, na.rm = TRUE)),
                       quantile(lprice, 0.995, na.rm = TRUE))]

# Sample sizes by buyer group
sz <- dat[, .(N = .N, n_g65 = sum(g65), n_post = sum(post),
              n_g65post = sum(treat)), by = buyer_grp][order(-N)]
cat("\n--- sample by buyer group ---\n", file = logf)
sink(logf, append = TRUE); print(sz); sink()

# Restrict to groups with enough cell counts (at least 1000 G65×Post)
keep_grps <- sz[n_g65post >= 500, buyer_grp]
log_step("62", sprintf("groups kept (>= 500 treated obs): %s",
                       paste(keep_grps, collapse = ", ")), logf)

# Pooled DiD as benchmark
fit_pool <- feols(lprice ~ treat + post + lqty | item_alt,
                  data = dat, cluster = ~item_alt)
log_step("62", sprintf("pooled treat coef = %.4f (se %.4f)",
                       coef(fit_pool)["treat"],
                       se(fit_pool)["treat"]), logf)

# By-group DiD
res <- list()
for (grp in keep_grps) {
  sub <- dat[buyer_grp == grp]
  if (nrow(sub) < 5000) next
  fit <- feols(lprice ~ treat + post + lqty | item_alt,
               data = sub, cluster = ~item_alt)
  res[[grp]] <- data.table(
    buyer_grp = grp,
    n = nrow(sub),
    n_treat = sum(sub$treat),
    coef = round(coef(fit)["treat"], 4),
    se   = round(se(fit)["treat"], 4),
    p    = round(pvalue(fit)["treat"], 4))
}
res_dt <- rbindlist(res)

cat("\n--- DiD by buyer group ---\n", file = logf)
sink(logf, append = TRUE); print(res_dt); sink()

# Interaction test: g65 × post × buyer_grp
dat[, buyer_f := factor(buyer_grp, levels = keep_grps)]
fit_inter <- feols(lprice ~ treat * buyer_f + post + lqty | item_alt,
                   data = dat[buyer_grp %in% keep_grps],
                   cluster = ~item_alt)
log_step("62", "interaction model fitted", logf)

# LaTeX table
tex <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\small",
  "\\caption{DiD price coefficient by buyer type}",
  "\\label{tab:v3_buyer_het}",
  "\\begin{threeparttable}",
  "\\begin{tabular}{lrrrr}",
  "\\toprule",
  "Buyer type & $N$ & $\\hat\\beta$ & SE & $p$-value \\\\",
  "\\midrule",
  sprintf("Pooled (all buyers) & %s & %.4f & %.4f & %s \\\\",
          format(nobs(fit_pool), big.mark = ","),
          coef(fit_pool)["treat"], se(fit_pool)["treat"],
          ifelse(pvalue(fit_pool)["treat"] < 0.001, "$<0.001$",
                 sprintf("%.3f", pvalue(fit_pool)["treat"])))
)

for (i in seq_len(nrow(res_dt))) {
  r <- res_dt[i]
  tex <- c(tex, sprintf(
    "\\quad %s & %s & %.4f & %.4f & %s \\\\",
    r$buyer_grp, format(r$n, big.mark = ","),
    r$coef, r$se,
    ifelse(r$p < 0.001, "$<0.001$", sprintf("%.3f", r$p))))
}

tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Specification: $\\log(\\text{price}_{it}) = \\beta \\cdot",
  "\\text{Group65}_i \\cdot \\text{Post}_t + \\text{Post}_t + ",
  "\\log(\\text{quantity}_{it}) + \\gamma_i + \\varepsilon_{it}$, item",
  "fixed effects $\\gamma_i$, standard errors clustered by item.",
  "Sample: 18-month symmetric window around the March 2018 cutoff,",
  "completed items only. Buyer types: \\textit{Direct admin}",
  "(state secretariats, code 1); \\textit{Indirect admin}",
  "(autarquias, funda\\c{c}\\~oes, state companies, codes 3--6);",
  "\\textit{Convenied} (entities subject to procurement under",
  "convention with the state, code 80). The pooled coefficient",
  "is the headline estimate of Table~\\ref{tab:prices}; the by-group",
  "estimates show whether the price effect varies systematically",
  "across buyer types. The estimates are quantitatively comparable",
  "across direct and indirect administration; smaller-cell groups",
  "may show larger sampling variation.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_buyer_het.tex"))
log_step("62", "saved tab_v3_buyer_het.tex", logf)
log_step("62", "done", logf)
