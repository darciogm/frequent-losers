# ============================================================================
# 28_pbu_characterization.R — Characterize persistent FL-active PBUs (A7.1)
# Paper 3 v14
#
# Script 24 found 83.5% PBU-level FL persistence (790 of 946 early-period
# FL-active PBUs are also FL-active in late period). This script asks:
# what makes persistent FL-active PBUs different from
#   (a) non-persistent FL-active PBUs (156 PBUs FL-active 2009-2013 only)
#   (b) never-FL-active PBUs (1,347 - 1,044 = 303 PBUs that never had FL)
#
# Three groups:
#   PERSIST    = FL-active in BOTH 2009-2013 AND 2014-2019 (790)
#   TRANSIENT  = FL-active in early period ONLY (156 = 946 - 790)
#   NEVER      = never FL-active in either period
#
# Characteristics tested:
#   - Geographic: state, region, city size proxies
#   - Administrative type: pbu_power, pbu_type_mgmt
#   - Size: total tenders, total spending, distinct items procured
#
# Output:
#   output/pbu_characterization/pbu_characterization.csv
#   output/pbu_characterization/fig_pbu_characterization.pdf
# ============================================================================

cat("=== 28_pbu_characterization.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(ggplot2); library(duckdb); library(DBI)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "pbu_characterization")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Re-derive PBU groups (replicates script 24) ------------------------
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]
ftm[, pbu_code := substr(numerodaoc, 1, 11)]
ftm[, firm_code := as.character(`códigofornecedor`)]
fp[, firm_code := as.character(`códigofornecedor`)]

build_fl_period <- function(yr_start, yr_end) {
  ftm_p <- ftm[year >= yr_start & year <= yr_end]
  losses <- ftm_p[won == 0L, .N, by = firm_code]
  setnames(losses, "N", "tcount")
  wins <- ftm_p[won == 1L, .N, by = firm_code]
  setnames(wins, "N", "wcount")
  firms <- merge(losses, wins, by = "firm_code", all = TRUE)
  firms[is.na(tcount), tcount := 0L]
  firms[is.na(wcount), wcount := 0L]
  firms[, win_rate := wcount / pmax(tcount + wcount, 1L)]
  firms[, always_loser := as.integer(win_rate == 0)]
  al <- firms[always_loser == 1L, tcount]
  thresh <- median(al) + 1.5 * IQR(al)
  firms[, is_fl := as.integer(always_loser == 1L & tcount > thresh)]
  firms
}

fl_e <- build_fl_period(2009L, 2013L)
fl_l <- build_fl_period(2014L, 2019L)

ftm_e <- merge(ftm[year >= 2009L & year <= 2013L],
               fl_e[, .(firm_code, is_fl_e = is_fl)], by = "firm_code", all.x = TRUE)
ftm_l <- merge(ftm[year >= 2014L & year <= 2019L],
               fl_l[, .(firm_code, is_fl_l = is_fl)], by = "firm_code", all.x = TRUE)
ftm_e[is.na(is_fl_e), is_fl_e := 0L]
ftm_l[is.na(is_fl_l), is_fl_l := 0L]

pbu_e_fl <- ftm_e[is_fl_e == 1L, unique(pbu_code)]
pbu_l_fl <- ftm_l[is_fl_l == 1L, unique(pbu_code)]
all_pbus  <- ftm[, unique(pbu_code)]

persist_pbus   <- intersect(pbu_e_fl, pbu_l_fl)
transient_pbus <- setdiff(pbu_e_fl, pbu_l_fl)
never_pbus     <- setdiff(all_pbus, union(pbu_e_fl, pbu_l_fl))
new_pbus       <- setdiff(pbu_l_fl, pbu_e_fl)

cat(sprintf("  PBU groups:\n"))
cat(sprintf("    PERSIST   (FL in both): %s\n", format(length(persist_pbus),  big.mark=",")))
cat(sprintf("    TRANSIENT (early only): %s\n", format(length(transient_pbus), big.mark=",")))
cat(sprintf("    NEW       (late only):  %s\n", format(length(new_pbus),       big.mark=",")))
cat(sprintf("    NEVER     (no FL):      %s\n", format(length(never_pbus),     big.mark=",")))
cat(sprintf("    Total PBUs:              %s\n", format(length(all_pbus),       big.mark=",")))

# ---- PBU characteristics from bid_level_full_v14 (with metadata) -------
cat("\n  Pulling PBU metadata from bid_level_full_v14 ...\n")
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

pbu_meta_q <- sprintf("
SELECT
  SUBSTR(CAST(\"Numero da OC\" AS VARCHAR), 1, 11) AS pbu_code,
  ANY_VALUE(\"Descrição Unidade Compradora\")        AS pbu_descr,
  COUNT(*)                                              AS n_bid_records
FROM read_parquet('%s', union_by_name=true)
WHERE \"Numero da OC\" IS NOT NULL
GROUP BY pbu_code
", file.path(BASE, "data/processed/bid_level_full_v14.parquet"))
pbu_meta <- as.data.table(dbGetQuery(con, pbu_meta_q))
dbDisconnect(con, shutdown = TRUE)
cat(sprintf("  Pulled metadata for %s PBUs\n", format(nrow(pbu_meta), big.mark=",")))

# pbu_descr typically includes city/agency/level — extract patterns
pbu_meta[is.na(pbu_descr), pbu_descr := ""]
pbu_meta[, has_dir_ens := as.integer(grepl("DIR\\.ENS", pbu_descr))]   # education
pbu_meta[, has_secretaria := as.integer(grepl("SECRETARIA", pbu_descr))]
pbu_meta[, has_prefeitura := as.integer(grepl("PREFEITURA", pbu_descr))]
pbu_meta[, has_hospital := as.integer(grepl("HOSPITAL|MEDICO", pbu_descr))]
pbu_meta[, has_universidade := as.integer(grepl("UNIVERSIDADE|FACULDADE", pbu_descr))]
pbu_meta[, has_policia := as.integer(grepl("POLICIA|POLÍCIA", pbu_descr))]

# Compute size: total tender-items and unique firms per PBU
pbu_size <- ftm[, .(
  n_tenders = .N,
  n_unique_items = uniqueN(`códigoitem`),
  n_unique_firms = uniqueN(firm_code),
  n_unique_oc    = uniqueN(numerodaoc)
), by = pbu_code]

pbu_meta <- merge(pbu_meta, pbu_size, by = "pbu_code", all.x = TRUE)

# Assign group
pbu_meta[, group := fcase(
  pbu_code %in% persist_pbus,   "PERSIST",
  pbu_code %in% transient_pbus, "TRANSIENT",
  pbu_code %in% new_pbus,       "NEW",
  default = "NEVER"
)]
pbu_meta[, group := factor(group, levels = c("PERSIST", "TRANSIENT", "NEW", "NEVER"))]

# ---- Group means + tests --------------------------------------------------
cat("\n  Characteristics by PBU group:\n")

vars <- c("n_tenders", "n_unique_items", "n_unique_firms", "n_unique_oc",
          "has_dir_ens", "has_secretaria", "has_prefeitura",
          "has_hospital", "has_universidade", "has_policia")

summ <- pbu_meta[group %in% c("PERSIST", "TRANSIENT", "NEW", "NEVER"),
                  lapply(.SD, mean, na.rm = TRUE),
                  by = group, .SDcols = vars]
summ_n <- pbu_meta[, .(n_pbus = .N), by = group]
summ <- merge(summ_n, summ, by = "group")
print(summ)

# Tests: PERSIST vs NEVER on each variable
cat("\n  Tests PERSIST vs NEVER (Welch t-test):\n")
test_dt <- data.table()
for (v in vars) {
  x_p <- pbu_meta[group == "PERSIST", get(v)]
  x_n <- pbu_meta[group == "NEVER",   get(v)]
  if (length(x_p) < 5 || length(x_n) < 5) next
  tt <- t.test(x_p, x_n)
  test_dt <- rbind(test_dt, data.table(
    variable = v,
    persist_mean = round(mean(x_p, na.rm=TRUE), 3),
    never_mean   = round(mean(x_n, na.rm=TRUE), 3),
    diff         = round(mean(x_p, na.rm=TRUE) - mean(x_n, na.rm=TRUE), 3),
    t_stat       = round(tt$statistic, 2),
    pval         = round(tt$p.value, 4)
  ))
}
print(test_dt)
fwrite(test_dt, file.path(OUT, "pbu_characterization_tests.csv"))

# ---- Save full table -----------------------------------------------------
fwrite(summ, file.path(OUT, "pbu_characterization_summary.csv"))

# ---- Plot -----------------------------------------------------------------
plot_dt <- melt(pbu_meta[group %in% c("PERSIST", "TRANSIENT", "NEW", "NEVER"),
                          .(group, n_tenders, n_unique_items, n_unique_firms,
                            has_secretaria, has_prefeitura, has_hospital,
                            has_universidade)],
                 id.vars = "group", variable.name = "characteristic",
                 value.name = "value")

# size-based: log scale
size_dt <- plot_dt[characteristic %in% c("n_tenders", "n_unique_items",
                                           "n_unique_firms")]
size_dt[, value_log := log10(pmax(value, 1))]
p_size <- ggplot(size_dt, aes(x = group, y = value_log, fill = group)) +
  geom_boxplot(alpha = 0.7, outlier.size = 0.5) +
  facet_wrap(~ characteristic, scales = "free_y",
             labeller = as_labeller(c(n_tenders = "Total tender-items",
                                       n_unique_items = "Distinct items procured",
                                       n_unique_firms = "Distinct firms"))) +
  scale_fill_manual(values = c("PERSIST" = "#d73027",
                                "TRANSIENT" = "#9e3a4d",
                                "NEW" = "#5b8aa6",
                                "NEVER" = "#bdbdbd")) +
  labs(x = NULL, y = "log10(value)",
       title = "PBU size by FL-persistence group",
       subtitle = "Persistent FL-active PBUs are LARGER procurement bodies, not smaller") +
  theme_bw() + theme(legend.position = "none")

# admin type proportions
admin_dt <- pbu_meta[group %in% c("PERSIST", "TRANSIENT", "NEW", "NEVER"),
                       lapply(.SD, mean),
                       by = group,
                       .SDcols = c("has_secretaria", "has_prefeitura",
                                    "has_hospital", "has_universidade",
                                    "has_dir_ens")]
admin_long <- melt(admin_dt, id.vars = "group",
                   variable.name = "admin_type", value.name = "share")
admin_long[, admin_type_label := fcase(
  admin_type == "has_secretaria",  "Secretaria",
  admin_type == "has_prefeitura",  "Prefeitura",
  admin_type == "has_hospital",    "Hospital/Saúde",
  admin_type == "has_universidade", "Universidade",
  admin_type == "has_dir_ens",     "Dir. Ensino"
)]

p_admin <- ggplot(admin_long, aes(x = admin_type_label, y = share, fill = group)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = c("PERSIST" = "#d73027",
                                "TRANSIENT" = "#9e3a4d",
                                "NEW" = "#5b8aa6",
                                "NEVER" = "#bdbdbd")) +
  scale_y_continuous(labels = scales::percent) +
  labs(x = NULL, y = "Share of PBUs",
       title = "PBU administrative type by FL-persistence group",
       fill = "Group") +
  theme_bw() + theme(legend.position = "bottom",
                     axis.text.x = element_text(angle = 15, hjust = 1))

# Combine
suppressPackageStartupMessages({library(patchwork)})
p_combined <- p_size / p_admin
ggsave(file.path(OUT, "fig_pbu_characterization.pdf"), p_combined,
       width = 9, height = 8, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_pbu_characterization.pdf")))

cat("\n  Done.\n")
