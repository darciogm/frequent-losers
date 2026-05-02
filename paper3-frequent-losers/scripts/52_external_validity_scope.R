# 52_external_validity_scope.R -- narrow the external-validity claim to what
# BEC can actually support
#
# Outputs:
#   output/external_validity_scope/external_validity_scope.csv
#   work/v13/output/tables/tab_external_validity_scope.tex


if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(data.table)
  library(fixest)
  library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "external_validity_scope")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create("/tmp/duckdb_spill", recursive = TRUE, showWarnings = FALSE)

drv <- duckdb::duckdb()
con <- dbConnect(drv, dbdir = ":memory:")
dbExecute(con, "SET threads TO 12")
dbExecute(con, "SET memory_limit='14GB'")
dbExecute(con, "SET temp_directory='/tmp/duckdb_spill'")

item_dict <- as.data.table(dbGetQuery(con, sprintf("
  SELECT
    CAST(\"Código Item\" AS VARCHAR) AS item_code,
    ANY_VALUE(COALESCE(\"Desc Item\", '')) AS desc_item,
    ANY_VALUE(COALESCE(\"Desc Grupo Item\", '')) AS desc_group,
    ANY_VALUE(COALESCE(\"Desc Classe Item\", '')) AS desc_class,
    ANY_VALUE(COALESCE(\"Desc Categoria Item\", '')) AS desc_category
  FROM read_parquet('%s', union_by_name=true)
  GROUP BY item_code
", file.path(BASE, "data/processed/bid_level_full_v14.parquet"))))

ftm <- as.data.table(dbGetQuery(con, sprintf("
  SELECT
    LPAD(CAST(\"códigofornecedor\" AS VARCHAR), 14, '0') AS firm_code,
    CAST(\"numerodaoc\" AS VARCHAR) AS numerodaoc,
    CAST(\"códigoitem\" AS VARCHAR) AS item_code,
    CAST(\"won\" AS INTEGER) AS won
  FROM read_parquet('%s')
", file.path(BASE, "data/processed/firm_tender_map.parquet"))))
dbDisconnect(con, shutdown = TRUE)

normalize_txt <- function(x) {
  x <- toupper(iconv(x, from = "", to = "ASCII//TRANSLIT"))
  x[is.na(x)] <- ""
  x
}

item_dict[, text := paste(desc_item, desc_group, desc_class, desc_category)]
item_dict[, text_norm := normalize_txt(text)]
service_pat <- paste(
  "SERVICO", "PRESTACAO", "MANUTENCAO", "LOCACAO", "TRANSPORTE",
  "LIMPEZA", "VIGILANCIA", "CONSULTORIA", "REFEICAO", "ALIMENTACAO PREPARADA",
  "SEGURO", "MONITORAMENTO", sep = "|"
)
item_dict[, item_class := fifelse(grepl(service_pat, text_norm), "Service", "Commodity")]
item_dict[text_norm == "", item_class := "Unknown"]

dt <- as.data.table(readRDS("/tmp/p3_prepared.rds"))
dt <- merge(dt, item_dict[, .(item_code, item_class)], by.x = "item_code", by.y = "item_code", all.x = TRUE)
dt[is.na(item_class), item_class := "Unknown"]

coverage <- dt[, .(
  n_items = .N,
  share_items = .N / nrow(dt),
  share_fl_present = mean(losers == 1L)
), by = item_class]

fp <- as.data.table(arrow::read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

ftm <- merge(ftm, item_dict[, .(item_code, item_class)], by = "item_code", all.x = TRUE)
ftm[is.na(item_class), item_class := "Unknown"]
firm_class <- ftm[, .N, by = .(firm_code, item_class)][order(firm_code, -N)]
firm_class <- firm_class[, .SD[1], by = firm_code]

al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]
al[, log_tc := log1p(tenders_count)]
al <- merge(al, firm_class[, .(firm_code, dominant_class = item_class)], by = "firm_code", all.x = TRUE)
al[is.na(dominant_class), dominant_class := "Unknown"]

calc_auc <- function(label, score) {
  if (sum(label) < 5L || length(unique(score)) < 2L) return(list(auc = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_))
  r <- pROC::roc(label, score, quiet = TRUE)
  ci <- as.numeric(pROC::ci.auc(r))
  list(auc = as.numeric(pROC::auc(r)), ci_lo = ci[1], ci_hi = ci[3])
}

detect_rows <- list()
for (cls in c("Commodity", "Service", "Unknown")) {
  sub <- al[dominant_class == cls]
  if (!nrow(sub)) next
  a <- calc_auc(sub$is_cade, sub$log_tc)
  detect_rows[[length(detect_rows) + 1L]] <- data.table(
    dimension = "dominant_item_class",
    group = cls,
    metric = "auc_log_tc",
    value = a$auc,
    ci_lo = a$ci_lo,
    ci_hi = a$ci_hi,
    n = nrow(sub),
    n_pos = sum(sub$is_cade)
  )
}

price_rows <- list()
for (cls in c("Commodity", "Service", "Unknown")) {
  sub <- dt[item_class == cls & !is.na(lneg_price)]
  if (nrow(sub) < 1000L || length(unique(sub$losers)) < 2L) next
  fit <- feols(
    lneg_price ~ losers + convite | item_f + year_f + pbu_f,
    data = sub, cluster = ~item_f, lean = TRUE
  )
  ct <- coeftable(fit)
  price_rows[[length(price_rows) + 1L]] <- data.table(
    dimension = "item_class_price",
    group = cls,
    metric = "coef_losers",
    value = ct["losers", "Estimate"],
    ci_lo = ct["losers", "Estimate"] - 1.96 * ct["losers", "Std. Error"],
    ci_hi = ct["losers", "Estimate"] + 1.96 * ct["losers", "Std. Error"],
    n = nrow(sub),
    n_pos = sum(sub$losers == 1L)
  )
}

gate_d2 <- fread(file.path(BASE, "output", "gate_d2", "d2_modal_auc.csv"))
modal_rows <- gate_d2[pool %in% c("convite_primary", "pregao_primary") & score == "log_tc",
  .(dimension = "modal_primary_auc",
    group = pool,
    metric = "auc_log_tc",
    value = auc,
    ci_lo = ci_lo,
    ci_hi = ci_hi,
    n = n_total,
    n_pos = n_pos)]

cov_rows <- coverage[, .(
  dimension = "coverage",
  group = item_class,
  metric = "share_items",
  value = share_items,
  ci_lo = NA_real_,
  ci_hi = NA_real_,
  n = n_items,
  n_pos = round(share_fl_present * n_items)
)]

normalize_schema <- function(d) {
  setDT(d)
  d[, `:=`(
    dimension = as.character(dimension),
    group = as.character(group),
    metric = as.character(metric),
    value = as.numeric(value),
    ci_lo = as.numeric(ci_lo),
    ci_hi = as.numeric(ci_hi),
    n = as.integer(n),
    n_pos = as.integer(n_pos)
  )]
  d
}

res <- rbindlist(
  lapply(c(list(cov_rows), detect_rows, price_rows, list(modal_rows)), normalize_schema),
  fill = TRUE
)
fwrite(res, file.path(OUT, "external_validity_scope.csv"))

tex <- c(
  "% JLEO-R1: external validity scope table",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{External Validity Scope: Modality and Commodity-Service Boundaries}",
  "\\label{tab:external_validity_scope}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lllcc}",
  "\\toprule",
  "Dimension & Group & Metric & Value & 95\\% CI \\\\",
  "\\midrule"
)
esc <- function(x) gsub("_", "\\_", x, fixed = TRUE)

for (i in seq_len(nrow(res))) {
  rr <- res[i]
  val_lab <- if (rr$metric == "share_items") sprintf("%.3f", rr$value) else sprintf("%.3f", rr$value)
  ci_lab <- if (is.na(rr$ci_lo)) "---" else sprintf("[%.3f, %.3f]", rr$ci_lo, rr$ci_hi)
  tex <- c(tex, sprintf("%s & %s & %s & $%s$ & %s \\\\",
                        esc(rr$dimension), esc(rr$group), esc(rr$metric), val_lab,
                        ifelse(ci_lab == "---", "---", paste0("$", ci_lab, "$"))))
}
tex <- c(
  tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Item classes use a transparent text rule on BEC item descriptions. Rows labelled \\texttt{modal\\_primary\\_auc} reuse the always-loser firm split by primary modality; rows labelled \\texttt{item\\_class\\_price} report the within-item price association separately for commodity-like and service-like items. The point is not to claim exportability to all procurement, but to document that the paper speaks most naturally to standardized-goods environments and selected simple services.",
  "\\item \\textit{Source:} \\texttt{scripts/52\\_external\\_validity\\_scope.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_external_validity_scope.tex"))

cat("\n  External-validity scope summary:\n")
print(res)
cat("\n  Wrote:\n")
cat("   - ", file.path(OUT, "external_validity_scope.csv"), "\n", sep = "")
cat("   - ", file.path(TABS, "tab_external_validity_scope.tex"), "\n", sep = "")
