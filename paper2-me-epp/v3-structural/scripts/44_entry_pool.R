# S4 / task 44 -------------------------------------------------------
# Entry rates por estrato: quantos SME e non-SME bidaram em cada
# leilão, sobre o pool potencial (firmas que já bidaram naquela
# classe CADMAT em qualquer momento).
#
# Isto é o passo 1 do Athey-Levin-Seira (2011): identificar a margem
# extensiva. A razão (bidders observados / pool potencial) é a
# probabilidade de entrada.
#
# DiD de entry rate Pre → Post, estratificado por pharma:
#   Δ^SME, Δ^non-SME = efeito da política sobre a propensão de entrar
#
# Saídas:
#   data/processed/entry_rates.parquet
#   output/tables/tab_v3_entry_rates.tex

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/44_entry_pool.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("44", "start: entry pool + rates", logf)

# 1. Pool potencial por classe CADMAT × tipo -------------------------
# Firma faz parte do pool se já bidou naquela classe em qualquer
# período (janela Pre, Post, ou fora). Uso bid_level_sme_pharma_g65
# para construir a firm × class x type table.

sme_path <- path_v3("data/processed/bid_level_sme_pharma_g65.parquet")

pool <- dbGetQuery(con, sprintf("
  SELECT
    codigoclasse, sme_bec,
    COUNT(DISTINCT cod_forn) AS pool_size
  FROM read_parquet('%s')
  WHERE mod IN ('convite','pregao') AND codigoclasse IS NOT NULL
  GROUP BY codigoclasse, sme_bec
", sme_path)) |> setDT()

cat("\n--- pool size por (class × type) (top 15) ---\n", file = logf)
sink(logf, append = TRUE)
print(pool[order(-pool_size)][1:15])
sink()

# Soma por pharma flag.
pool[, pharma_narrow := as.integer(codigoclasse %in% cadmat_pharma_narrow)]
pool_pharma <- pool[, .(pool_size = sum(pool_size)),
                    by = .(pharma_narrow, sme_bec)]
cat("\n--- pool size por (pharma × type) ---\n", file = logf)
sink(logf, append = TRUE); print(pool_pharma); sink()

# 2. Entry count por leilão e tipo -----------------------------------
# Número de firmas DISTINTAS por tipo em cada leilão×item. Sem
# distinct, Pregão conta bids iterativos e infla 3-4×.
entry <- dbGetQuery(con, sprintf("
  WITH firm_auc AS (
    SELECT DISTINCT
      numerodaoc, codigoitem, cod_forn, mod, period, pharma_narrow, sme_bec
    FROM read_parquet('%s')
    WHERE period IN ('Pre','Post')
      AND mod IN ('convite','pregao')
      AND sme_bec IS NOT NULL
  )
  SELECT
    numerodaoc, codigoitem, mod, period, pharma_narrow,
    SUM(CASE WHEN sme_bec = 1 THEN 1 ELSE 0 END) AS n_sme_bid,
    SUM(CASE WHEN sme_bec = 0 THEN 1 ELSE 0 END) AS n_nonsme_bid
  FROM firm_auc
  GROUP BY 1,2,3,4,5
", sme_path)) |> setDT()

log_step("44", sprintf("auctions × period = %s",
                       format(nrow(entry), big.mark = ",")), logf)

# 3. Entry rate = n_bid / pool ---------------------------------------
entry <- merge(entry,
  pool_pharma[sme_bec == 1, .(pharma_narrow, pool_sme = pool_size)],
  by = "pharma_narrow", all.x = TRUE)
entry <- merge(entry,
  pool_pharma[sme_bec == 0, .(pharma_narrow, pool_nonsme = pool_size)],
  by = "pharma_narrow", all.x = TRUE)

entry[, rate_sme    := n_sme_bid    / pool_sme]
entry[, rate_nonsme := n_nonsme_bid / pool_nonsme]

# Médias por estrato.
rates <- entry[,
  .(n_auctions = .N,
    mean_n_sme       = round(mean(n_sme_bid),    2),
    mean_n_nonsme    = round(mean(n_nonsme_bid), 2),
    mean_rate_sme    = round(mean(rate_sme),    5),
    mean_rate_nonsme = round(mean(rate_nonsme), 5)),
  by = .(mod, period, pharma_narrow)]
rates[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
rates <- rates[order(mod, pharma_narrow, period)]

cat("\n--- entry rates por estrato ---\n", file = logf)
sink(logf, append = TRUE); print(rates); sink()

# 4. DiD: Δ_SME^k = entry_Post - entry_Pre ---------------------------
did <- dcast(rates, mod + pharma_lbl ~ period,
             value.var = c("mean_rate_sme", "mean_rate_nonsme",
                           "mean_n_sme", "mean_n_nonsme"))
did[, delta_rate_sme    := mean_rate_sme_Post    - mean_rate_sme_Pre]
did[, delta_rate_nonsme := mean_rate_nonsme_Post - mean_rate_nonsme_Pre]
did[, delta_n_sme       := mean_n_sme_Post       - mean_n_sme_Pre]
did[, delta_n_nonsme    := mean_n_nonsme_Post    - mean_n_nonsme_Pre]

cat("\n--- DiD entry (Post − Pre) ---\n", file = logf)
sink(logf, append = TRUE)
print(did[, .(mod, pharma_lbl,
              delta_n_sme, delta_n_nonsme,
              delta_rate_sme = round(delta_rate_sme,    5),
              delta_rate_nonsme = round(delta_rate_nonsme, 5))])
sink()

arrow::write_parquet(entry,
  path_v3("data/processed/entry_rates.parquet"),
  compression = "snappy")

# 5. LaTeX table -----------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Entry rates and Pre→Post shift, by modality and class}",
  "\\label{tab:v3_entry_rates}",
  "\\small",
  "\\begin{tabular}{llrrrrrr}",
  "\\toprule",
  " & & \\multicolumn{2}{c}{Pre} & \\multicolumn{2}{c}{Post} & \\multicolumn{2}{c}{$\\Delta$} \\\\",
  "\\cmidrule(lr){3-4}\\cmidrule(lr){5-6}\\cmidrule(lr){7-8}",
  "Mod. & Class & $\\bar N^{\\text{SME}}$ & $\\bar N^{\\neg}$ & $\\bar N^{\\text{SME}}$ & $\\bar N^{\\neg}$ & SME & non-SME \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(did))) {
  r <- did[i]
  tex <- c(tex, sprintf(
    "%s & %s & %.2f & %.2f & %.2f & %.2f & %+.2f & %+.2f \\\\",
    r$mod, r$pharma_lbl,
    r$mean_n_sme_Pre, r$mean_n_nonsme_Pre,
    r$mean_n_sme_Post, r$mean_n_nonsme_Post,
    r$delta_n_sme, r$delta_n_nonsme))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Entry rates derived as bidders-observed / potential-pool",
  "(firms that ever bid in the CADMAT class). $\\bar N$ columns show",
  "average bidders per auction. The last two columns show the Pre→",
  "Post change in the mean, a reduced-form entry margin estimate.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_entry_rates.tex"))

log_step("44", "done", logf)
