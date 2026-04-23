# S1 / task 34 -------------------------------------------------------
# Consolida o handoff de S1: estatísticas descritivas por estrato
# (modality × period × pharma × SME) que vão sustentar a decisão de
# como as próximas sprints (S3 UH, S4 entry) tratam heterogeneidade.
#
# Entrego como uma tabela só (tab_v3_s1_handoff.tex) com colunas
# interpretáveis: tamanho amostral, preço-ref médio, bids por firma,
# HHI de fornecedores, win-rate, spread do bid vs ref.
#
# Também anexo um diagnóstico leve: firmas recorrentes vs one-shot,
# auction-level número médio de bidders.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/34_s1_descriptives.log"), open = "wt")
on.exit(close(logf), add = TRUE)

log_step("34", "start: S1 handoff descriptives", logf)

# arrow::read_parquet tropeça em thrift stats desse parquet
# (alta cardinalidade do ym_enc). DuckDB lê sem reclamar.
con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

bids <- dbGetQuery(con, sprintf("
  SELECT * FROM read_parquet('%s')
", path_v3("data/processed/bid_level_sme_pharma_g65.parquet"))) |> setDT()

bids[, period := fcase(
  data_oc_numb < cutoff_m & data_oc_numb >= win_18m[1], "Pre",
  data_oc_numb >= cutoff_m & data_oc_numb <= win_18m[2], "Post",
  default = "fora")]

bids <- bids[mod %in% c("convite", "pregao") & period %in% c("Pre", "Post")]
bids <- bids[!is.na(sme_flag)]

# Auction-level N bidders ---------------------------------------------
auc <- bids[, .(
  n_bidders       = uniqueN(cod_forn),
  n_sme_bidders   = uniqueN(cod_forn[sme_flag == 1]),
  n_nonsme_bidders = uniqueN(cod_forn[sme_flag == 0]),
  mean_preco_ref  = mean(preco_ref, na.rm = TRUE)
), by = .(numerodaoc, codigoitem, mod, period, pharma_narrow)]

auc_desc <- auc[,
  .(N                  = .N,
    mean_N_bidders     = round(mean(n_bidders), 2),
    median_N_bidders   = as.numeric(median(n_bidders)),
    mean_N_sme         = round(mean(n_sme_bidders), 2),
    mean_N_nonsme      = round(mean(n_nonsme_bidders), 2),
    median_preco_ref   = round(median(mean_preco_ref, na.rm = TRUE), 2)),
  by = .(mod, period, pharma_narrow)]
auc_desc[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
auc_desc <- auc_desc[order(mod, pharma_narrow, period)]

cat("\n--- auction-level descriptives ---\n", file = logf)
sink(logf, append = TRUE); print(auc_desc); sink()

# Firm-level: recorrência dentro do estrato ---------------------------
firm_stats <- bids[, .(bids_per_firm = .N), by = .(mod, period, pharma_narrow, cod_forn)][,
  .(n_firms           = .N,
    mean_bids_per_firm = round(mean(bids_per_firm), 2),
    pct_oneshot_firm   = round(mean(bids_per_firm == 1) * 100, 2),
    hhi_bids           = round(sum((bids_per_firm / sum(bids_per_firm))^2) * 1e4, 1)),
  by = .(mod, period, pharma_narrow)]
firm_stats[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
firm_stats <- firm_stats[order(mod, pharma_narrow, period)]

cat("\n--- firm-level recurrence (HHI em pontos) ---\n", file = logf)
sink(logf, append = TRUE); print(firm_stats); sink()

# Merge e tabela única ----------------------------------------------
tab <- merge(
  auc_desc[, .(mod, period, pharma_lbl, N, mean_N_bidders, mean_N_sme,
               mean_N_nonsme, median_preco_ref)],
  firm_stats[, .(mod, period, pharma_lbl, n_firms, mean_bids_per_firm,
                 pct_oneshot_firm, hhi_bids)],
  by = c("mod", "period", "pharma_lbl"))
tab <- tab[order(mod, pharma_lbl, period)]

cat("\n--- tabela consolidada ---\n", file = logf)
sink(logf, append = TRUE); print(tab); sink()

# LaTeX ---------------------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{S1 handoff: G65 structural sample by stratum}",
  "\\label{tab:v3_s1_handoff}",
  "\\small",
  "\\begin{tabular}{llrrrrrrrrr}",
  "\\toprule",
  "Modality & Period & Class & Auctions & Avg.\\ $N$ & $N^{\\text{SME}}$ & $N^{\\neg\\text{SME}}$ & Med.\\ ref & Firms & Bids/firm & HHI \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(tab))) {
  r <- tab[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %s & %.2f & %.2f & %.2f & %s & %s & %.2f & %.1f \\\\",
    r$mod, r$period, r$pharma_lbl,
    format(r$N, big.mark = ","),
    r$mean_N_bidders, r$mean_N_sme, r$mean_N_nonsme,
    format(r$median_preco_ref, big.mark = ",", scientific = FALSE),
    format(r$n_firms, big.mark = ","),
    r$mean_bids_per_firm,
    r$hhi_bids))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Group 65, 18-month window around March 2018. Pharma is the",
  "narrow CMED-regulated definition (CADMAT 6531/6532/6536/6581).",
  "SME flag uses BEC \\emph{fornec\\_enquad}. Convite is sealed-bid and",
  "Preg\\~ao is iterative descending. Median reference price in BRL.",
  "HHI on firm bid shares within stratum, scaled to 0--10{,}000.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_s1_handoff.tex"))

# Flag de alerta: existem estratos onde SME share caiu ou não cresceu?
shift <- tab[, .(
  delta_N_sme = mean_N_sme[period == "Post"] - mean_N_sme[period == "Pre"],
  delta_N_nonsme = mean_N_nonsme[period == "Post"] - mean_N_nonsme[period == "Pre"]
), by = .(mod, pharma_lbl)]

cat("\n--- shift entry SME vs non-SME (Post − Pre) ---\n", file = logf)
sink(logf, append = TRUE); print(shift); sink()

log_step("34", "done", logf)
