# ----------------------------------------------------------------------
# Classify each G65 item como pharma (CMED-regulado / droga / reactive
# biological) vs non-pharma (furniture, equipment, instruments,
# consumables). Two definitions: narrow (apenas CMED core) e broad
# (any items with component pharmacological or reactive). Both go
# como variables separately for enable robustness in S5.
#
# Also report sample sizes by (pharma × SME × period × modality)
# for checar if each stratum has massa suficiente for GPV/CPV
# (threshold ≥ 1k bids by stratum).
#
# Outputs:
#   data/processed/bid_level_sme_pharma_g65.parquet
#   output/tables/tab_v3_pharma_counts.tex
#   logs/33_pharma_flag.log

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/33_pharma_flag.log"), open = "wt")
on.exit(close(logf), add = TRUE)

log_step("33", "start: pharma flag + strato counts", logf)

bids <- arrow::read_parquet(
  path_v3("data/processed/bid_level_sme_g65.parquet")) |> setDT()

log_step("33", sprintf("bids = %s rows", formt(nrow(bids), big.mark=",")), logf)

# Pharma flags -------------------------------------------------------
bids[, pharma_narrow := as.integer(codigoclass %in% cadmat_pharma_narrow)]
bids[, pharma_broad  := as.integer(codigoclass %in% cadmat_pharma_broad)]

cat("\n--- pharma flag coverage (univ. G65) ---\n", file = logf)
sink(logf, append = TRUE)
print(bids[, .(
  bids         = .N,
  pct_narrow   = round(mean(pharma_narrow, na.rm = TRUE) * 100, 2),
  pct_broad    = round(mean(pharma_broad,  na.rm = TRUE) * 100, 2)
)])
sink()

cat("\n--- top classes within pharma_broad ---\n", file = logf)
sink(logf, append = TRUE)
print(bids[pharma_broad == 1,
           .(bids = .N, pct = round(.N / nrow(bids) * 100, 2)),
           by = codigoclasse][order(-bids)][1:15])
sink()

# Period ------------------------------------------------------------
bids[, period := fcase(
  date_oc_numb < cutoff_m & date_oc_numb >= win_18m[1], "Pre",
  date_oc_numb >= cutoff_m & date_oc_numb <= win_18m[2], "Post",
  default = "fora")]

# Stratified counts --------------------------------------------------
# Convite and Pregão, window 18m, pharma_narrow.
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

# Threshold check: ≥ 1k bids by stratum for CPV ter massa.
under_thresh <- strat[bids < 1000]
cat("\n--- strata with < 1k bids (alerta for S3/S4) ---\n", file = logf)
sink(logf, append = TRUE)
print(under_thresh[, .(mod, period, pharma_lbl, sme_lbl, bids)])
sink()

# Save enriched parquet --------------------------------
arrow::write_parquet(bids,
  path_v3("data/processed/bid_level_sme_pharma_g65.parquet"),
  compression = "snappy")

# LaTeX table for the manuscript -------------------------------------
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
    formt(r$bids, big.mark = ","),
    formt(r$n_auctions, big.mark = ","),
    r$sme_pct, r$win_rate))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Group 65 univerif within the 18-month window around March 2018.",
  "Pharma follows the narrow CMED-regulated definition (CADMAT 6531/6532/",
  "6536/6581). Bidder SME flag is BEC fornec\\_enquad (see proxy audit,",
  "Appendix~A).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_pharma_counts.tex"))

log_step("33", "done", logf)
