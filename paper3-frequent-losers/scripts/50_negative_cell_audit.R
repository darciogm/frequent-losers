# 50_negative_cell_audit.R -- audit the negative High HHI x High pairs cell
#
# Outputs:
#   output/negative_cell_audit/negative_cell_audit.csv
#   work/v13/output/tables/tab_negative_cell_audit.tex


if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(data.table)
  library(fixest)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "negative_cell_audit")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

dt <- readRDS("/tmp/p3_prepared.rds")
dt[, oc_item_key := paste0(oc_code, "_", item_code)]

drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

ftm <- as.data.table(dbGetQuery(con, sprintf("
  SELECT
    LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    CAST(\"numerodaoc\" AS VARCHAR) AS numerodaoc,
    CAST(\"códigoitem\" AS VARCHAR) AS codigoitem,
    CAST(\"won\" AS INTEGER) AS won,
    CAST(SUBSTR(CAST(\"numerodaoc\" AS VARCHAR), 12, 4) AS INTEGER) AS year
  FROM read_parquet('%s')
", file.path(BASE, "data/processed/firm_tender_map.parquet"))))
dbDisconnect(con, shutdown = TRUE)

ftm[, oc_item_key := paste0(numerodaoc, "_", codigoitem)]
ftm[, pbu_code := substr(numerodaoc, 1, 11)]
ftm[, item_group := substr(codigoitem, 1, 2)]
ftm[, cell_id := paste0(pbu_code, "_", item_group, "_", year)]

fp <- as.data.table(arrow::read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
fp[, is_fl := as.integer(always_loser == 1L & tenders_count >= 14L)]
fl_firms <- fp[is_fl == 1L, firm_code]

cat("  Reconstructing network quadrants ...\n")
winners <- ftm[won == 1L, .(oc_item_key, cell_id, winner = firm_code)]
hhi <- winners[, {
  shares <- table(winner) / .N
  list(hhi = sum(shares^2))
}, by = cell_id]

ftm_fl <- ftm[firm_code %in% fl_firms & won == 0L, .(fl_firm = firm_code, oc_item_key, cell_id)]
fl_pairs <- merge(ftm_fl, winners, by = c("oc_item_key", "cell_id"), allow.cartesian = TRUE)
pair_counts <- fl_pairs[, .N, by = .(cell_id, fl_firm, winner)]
rep_pairs <- pair_counts[N >= 2, .(rep_pair_count = .N), by = cell_id]

cell_feat <- merge(hhi, rep_pairs, by = "cell_id", all.x = TRUE)
cell_feat[is.na(rep_pair_count), rep_pair_count := 0L]
cell_feat[, hhi_high := as.integer(hhi > median(hhi, na.rm = TRUE))]
cell_feat[, pair_high := as.integer(rep_pair_count > 0L)]
cell_feat[, quadrant := fcase(
  hhi_high == 0L & pair_high == 0L, "Low HHI x Low pairs",
  hhi_high == 0L & pair_high == 1L, "Low HHI x High pairs",
  hhi_high == 1L & pair_high == 0L, "High HHI x Low pairs",
  hhi_high == 1L & pair_high == 1L, "High HHI x High pairs"
)]

oc_map <- unique(ftm[, .(oc_item_key, cell_id, year)])
dt <- merge(dt, oc_map, by = c("oc_item_key", "year"), all.x = TRUE)
dt <- merge(dt, cell_feat[, .(cell_id, quadrant, hhi, rep_pair_count)], by = "cell_id", all.x = TRUE)

cade_xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(cade_xm$firm_code)
item_direct <- ftm[, .(any_direct = max(as.integer(firm_code %in% direct_codes))), by = oc_item_key]
dt <- merge(dt, item_direct, by = "oc_item_key", all.x = TRUE)
dt[is.na(any_direct), any_direct := 0L]

dt[, period := fcase(
  year <= 2013L, "2009-2013",
  year <= 2016L, "2014-2016",
  default = "2017-2019"
)]
dt[, modality := fcase(convite == 1L, "Convite", pregao == 1L, "Pregao", default = "Other")]
dt[, item_group_top := item_group]
top_groups <- dt[quadrant == "High HHI x High pairs", .N, by = item_group][order(-N)][1:min(10, .N), item_group]
dt[!item_group %in% top_groups, item_group_top := "Other groups"]
top_buyers <- dt[quadrant == "High HHI x High pairs", .N, by = pbu_code][order(-N)][1:min(10, .N), pbu_code]
dt[, buyer_top := fifelse(pbu_code %in% top_buyers, pbu_code, "Other buyers")]

dneg <- dt[quadrant == "High HHI x High pairs" & !is.na(lneg_price)]
cat(sprintf("  Negative-cell estimation sample: %s items\n", format(nrow(dneg), big.mark = ",")))

run_dim <- function(data, dim_name, var_name, top_only = FALSE) {
  groups <- unique(data[[var_name]])
  out <- list()
  for (g in groups) {
    sub <- data[get(var_name) == g]
    if (nrow(sub) < 1000L || length(unique(sub$losers)) < 2L || sum(sub$losers == 1L) < 50L) next
    fit <- feols(
      lneg_price ~ losers + convite | item_f + year_f + pbu_f,
      data = sub, cluster = ~item_f, lean = TRUE
    )
    ct <- coeftable(fit)
    out[[length(out) + 1L]] <- data.table(
      dimension = dim_name,
      group = as.character(g),
      coef = ct["losers", "Estimate"],
      se = ct["losers", "Std. Error"],
      pval = ct["losers", "Pr(>|t|)"],
      n = nrow(sub),
      treated_share = mean(sub$losers == 1L),
      direct_item_share = mean(sub$any_direct == 1L),
      mean_n_firms = mean(sub$n_firms, na.rm = TRUE),
      mean_price_ratio = mean(sub$price_ratio, na.rm = TRUE),
      mean_value = mean(sub$bid_unit_price_negot_min, na.rm = TRUE),
      share_of_negative_cell = nrow(sub) / nrow(data)
    )
  }
  rbindlist(out, fill = TRUE)
}

audit <- rbindlist(list(
  run_dim(dneg, "modality", "modality"),
  run_dim(dneg, "period", "period"),
  run_dim(dneg, "direct_cade_item", "any_direct"),
  run_dim(dneg, "pbu_size_q", "pbu_size_q"),
  run_dim(dneg, "tender_value_q", "tender_value_q"),
  run_dim(dneg, "item_group_top", "item_group_top"),
  run_dim(dneg, "buyer_top", "buyer_top")
), fill = TRUE)

fwrite(audit, file.path(OUT, "negative_cell_audit.csv"))

sel <- audit[dimension %in% c("modality", "period", "direct_cade_item")]
esc <- function(x) gsub("_", "\\_", x, fixed = TRUE)
fmt_row <- function(rr) {
  sprintf("%s & %s & $%+.3f$ & $%.3f$ & $%s$ \\\\",
          esc(rr$dimension), esc(rr$group), rr$coef, rr$se,
          ifelse(rr$pval < 0.001, "<0.001", sprintf("%.3f", rr$pval)))
}

tex <- c(
  "% JLEO-R1: negative-cell audit",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Audit of the Negative High-HHI x High-Pairs Cell}",
  "\\label{tab:negative_cell_audit}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{llccc}",
  "\\toprule",
  "Dimension & Group & FL coefficient & SE & $p$-value \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(sel))) tex <- c(tex, fmt_row(sel[i]))
tex <- c(
  tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Each row re-estimates the within-item price association inside the problematic High-HHI x High-pairs cell. The purpose is not to rescue the mechanism, but to document where the sign flip lives. The full CSV additionally reports decompositions by buyer, item group, PBU size, and tender-value quartile.",
  "\\item \\textit{Source:} \\texttt{scripts/50\\_negative\\_cell\\_audit.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_negative_cell_audit.tex"))

cat("\n  Negative-cell audit summary:\n")
print(audit[, .(dimension, group, coef = round(coef, 4), pval = round(pval, 4), n)][1:min(20, .N)])
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "negative_cell_audit.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_negative_cell_audit.tex"), "\n", sep = "")
