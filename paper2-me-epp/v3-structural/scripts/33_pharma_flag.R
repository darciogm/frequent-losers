# S1 / task 33 -------------------------------------------------------
# Classifica cada item G65 como pharma (CMED-regulado / droga / reativo
# biológico) vs não-pharma (mobiliário, equipamento, instrumental,
# consumíveis). Duas definições: narrow (apenas CMED core) e broad
# (qualquer item com componente farmacológico ou reativo). As duas vão
# como variáveis separadas para permitir robustez em S5.
#
# Também reporto sample sizes por (pharma × SME × período × modalidade)
# para checar se cada estrato tem massa suficiente para GPV/CPV
# (threshold ≥ 1k bids por estrato).
#
# Saídas:
#   data/processed/bid_level_sme_pharma_g65.parquet
#   output/tables/tab_v3_pharma_counts.tex
#   logs/33_pharma_flag.log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/33_pharma_flag.log"), open = "wt")
on.exit(close(logf), add = TRUE)

log_step("33", "start: pharma flag + strato counts", logf)

bids <- arrow::read_parquet(
  path_v3("data/processed/bid_level_sme_g65.parquet")) |> setDT()

log_step("33", sprintf("bids = %s linhas", format(nrow(bids), big.mark=",")), logf)

# Pharma flags -------------------------------------------------------
bids[, pharma_narrow := as.integer(codigoclasse %in% cadmat_pharma_narrow)]
bids[, pharma_broad  := as.integer(codigoclasse %in% cadmat_pharma_broad)]

cat("\n--- pharma flag coverage (univ. G65) ---\n", file = logf)
sink(logf, append = TRUE)
print(bids[, .(
  bids         = .N,
  pct_narrow   = round(mean(pharma_narrow, na.rm = TRUE) * 100, 2),
  pct_broad    = round(mean(pharma_broad,  na.rm = TRUE) * 100, 2)
)])
sink()

cat("\n--- top classes dentro de pharma_broad ---\n", file = logf)
sink(logf, append = TRUE)
print(bids[pharma_broad == 1,
           .(bids = .N, pct = round(.N / nrow(bids) * 100, 2)),
           by = codigoclasse][order(-bids)][1:15])
sink()

# Período ------------------------------------------------------------
bids[, period := fcase(
  data_oc_numb < cutoff_m & data_oc_numb >= win_18m[1], "Pre",
  data_oc_numb >= cutoff_m & data_oc_numb <= win_18m[2], "Post",
  default = "fora")]

# Stratified counts --------------------------------------------------
# Convite e Pregão, janela 18m, pharma_narrow.
strat <- bids[mod %in% c("convite", "pregao") & period %in% c("Pre", "Post"),
              .(bids       = .N,
                n_auctions = uniqueN(paste(numerodaoc, codigoitem)),
                sme_pct    = round(mean(sme_flag, na.rm = TRUE) * 100, 2),
                win_rate   = round(mean(won) * 100, 2)),
              by = .(mod, period, pharma_narrow, sme_flag)]

strat <- strat[order(mod, period, pharma_narrow, sme_flag)]
strat[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
strat[, sme_lbl    := fifelse(sme_flag == 1,     "SME",    "non-SME")]

cat("\n--- strato counts (mod × period × pharma × SME) ---\n", file = logf)
sink(logf, append = TRUE)
print(strat[, .(mod, period, pharma_lbl, sme_lbl, bids, n_auctions,
                sme_pct, win_rate)])
sink()

# Threshold check: ≥ 1k bids por estrato para CPV ter massa.
under_thresh <- strat[bids < 1000]
cat("\n--- estratos com < 1k bids (alerta para S3/S4) ---\n", file = logf)
sink(logf, append = TRUE)
print(under_thresh[, .(mod, period, pharma_lbl, sme_lbl, bids)])
sink()

# Persistência do parquet enriquecido --------------------------------
arrow::write_parquet(bids,
  path_v3("data/processed/bid_level_sme_pharma_g65.parquet"),
  compression = "snappy")

# Tabela LaTeX para o manuscrito -------------------------------------
strat[, row := sprintf("%s %s %s %s", mod, period, pharma_lbl, sme_lbl)]
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{G65 bid-level sample sizes by modality, period, pharma type, and bidder SME status}",
  "\\label{tab:v3_pharma_counts}",
  "\\begin{tabular}{llllrrrr}",
  "\\toprule",
  "Modality & Period & Class & Bidder & Bids & Auctions & SME share (\\%) & Win rate (\\%) \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(strat))) {
  r <- strat[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %s & %s & %s & %.2f & %.2f \\\\",
    r$mod, r$period, r$pharma_lbl, r$sme_lbl,
    format(r$bids, big.mark = ","),
    format(r$n_auctions, big.mark = ","),
    r$sme_pct, r$win_rate))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Group 65 universe within the 18-month window around March 2018.",
  "Pharma follows the narrow CMED-regulated definition (CADMAT 6531/6532/",
  "6536/6581). Bidder SME flag is BEC fornec\\_enquad (see proxy audit,",
  "Appendix~A).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_pharma_counts.tex"))

log_step("33", "done", logf)
