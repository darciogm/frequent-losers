# ============================================================================
# 24_market_persistence.R — Market-level FL persistence (Fragility 7)
# Paper 3 v14
#
# v13 reports 10% firm-level persistence: only 10% of FL firms classified
# on 2009-2013 reappear as FL on 2014-2019. v13 then says "FL flags markets,
# not firms." This script tests THAT claim by computing market-level
# persistence directly:
#
# Market unit: PBU × item-group × {2-year periods}
# A market is "FL-flagged" if it contains ≥1 FL participant.
#
# We compute:
#   1. Firm-level persistence (replicates v13's 10%): how many firms
#      classified FL in early period reappear FL in late period?
#   2. Market-level persistence: what fraction of FL-flagged markets
#      in early period are also FL-flagged in late period?
#   3. PBU-level persistence: what fraction of PBUs with FL activity
#      in early period have FL activity in late period?
#
# Hypothesis (defending v13's claim): market-level persistence is much
# higher than firm-level — say, 50-70% — validating "environment marker"
# language.
# ============================================================================

cat("=== 24_market_persistence.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "market_persistence")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]

# ---- Build period-specific FL classification --------------------------
build_fl_period <- function(yr_start, yr_end, label) {
  ftm_p <- ftm[year >= yr_start & year <= yr_end]
  losses <- ftm_p[won == 0L, .N, by = `códigofornecedor`]
  setnames(losses, "N", "tcount")
  wins   <- ftm_p[won == 1L, .N, by = `códigofornecedor`]
  setnames(wins, "N", "wcount")
  firms <- merge(losses, wins, by = "códigofornecedor", all = TRUE)
  firms[is.na(tcount), tcount := 0L]
  firms[is.na(wcount), wcount := 0L]
  firms[, win_rate := wcount / pmax(tcount + wcount, 1L)]
  firms[, always_loser := as.integer(win_rate == 0)]

  al <- firms[always_loser == 1L, tcount]
  thresh <- median(al) + 1.5 * IQR(al)
  firms[, is_fl := as.integer(always_loser == 1L & tcount > thresh)]

  cat(sprintf("  [%s] %d–%d: firms=%s, always-losers=%s, threshold=%g, FL=%s\n",
              label, yr_start, yr_end,
              format(nrow(firms), big.mark=","),
              format(sum(firms$always_loser), big.mark=","),
              round(thresh, 1),
              format(sum(firms$is_fl), big.mark=",")))
  firms[, .(`códigofornecedor`, is_fl_period = is_fl, tcount_period = tcount)]
}

# Two-period split (matches v13)
fl_e <- build_fl_period(2009L, 2013L, "early")
fl_l <- build_fl_period(2014L, 2019L, "late")

# ---- (1) Firm-level persistence (replicate v13's 10%) ------------------
cat("\n--- Analysis 1: firm-level persistence ---\n")
fl_e_set <- fl_e[is_fl_period == 1L, `códigofornecedor`]
fl_l_set <- fl_l[is_fl_period == 1L, `códigofornecedor`]
overlap_firm <- intersect(fl_e_set, fl_l_set)
cat(sprintf("  Early-period FL firms:  %s\n", format(length(fl_e_set), big.mark=",")))
cat(sprintf("  Late-period  FL firms:  %s\n", format(length(fl_l_set), big.mark=",")))
cat(sprintf("  Overlap:                %s (%.1f%% of early)\n",
            format(length(overlap_firm), big.mark=","),
            100 * length(overlap_firm) / length(fl_e_set)))

# ---- (2) Market-level persistence (PBU × item-group) ------------------
cat("\n--- Analysis 2: market-level persistence (PBU × item-group) ---\n")

# PBU code from numerodaoc (chars 1-11), item_code from FTM
ftm[, pbu_code := substr(numerodaoc, 1, 11)]
# item_group = first 4 digits of códigoitem (broad product class)
ftm[, item_group := substr(`códigoitem`, 1, 4)]

ftm_e <- ftm[year >= 2009L & year <= 2013L]
ftm_l <- ftm[year >= 2014L & year <= 2019L]
ftm_e <- merge(ftm_e, fl_e[, .(`códigofornecedor`, is_fl_e = is_fl_period)],
               by = "códigofornecedor", all.x = TRUE)
ftm_l <- merge(ftm_l, fl_l[, .(`códigofornecedor`, is_fl_l = is_fl_period)],
               by = "códigofornecedor", all.x = TRUE)
ftm_e[is.na(is_fl_e), is_fl_e := 0L]
ftm_l[is.na(is_fl_l), is_fl_l := 0L]

mkt_e <- ftm_e[, .(any_fl = max(is_fl_e), n_tenders = .N),
                by = .(pbu_code, item_group)][n_tenders >= 5]
mkt_l <- ftm_l[, .(any_fl = max(is_fl_l), n_tenders = .N),
                by = .(pbu_code, item_group)][n_tenders >= 5]

mkt_e_fl_set <- mkt_e[any_fl == 1L, paste0(pbu_code, "_", item_group)]
mkt_l_fl_set <- mkt_l[any_fl == 1L, paste0(pbu_code, "_", item_group)]
overlap_mkt <- intersect(mkt_e_fl_set, mkt_l_fl_set)
cat(sprintf("  Early FL-flagged markets: %s\n",
            format(length(mkt_e_fl_set), big.mark=",")))
cat(sprintf("  Late  FL-flagged markets: %s\n",
            format(length(mkt_l_fl_set), big.mark=",")))
cat(sprintf("  Overlap:                  %s (%.1f%% of early)\n",
            format(length(overlap_mkt), big.mark=","),
            100 * length(overlap_mkt) / max(length(mkt_e_fl_set), 1L)))

# ---- (3) PBU-level persistence ----------------------------------------
cat("\n--- Analysis 3: PBU-level persistence ---\n")
pbu_e <- ftm_e[is_fl_e == 1L, unique(pbu_code)]
pbu_l <- ftm_l[is_fl_l == 1L, unique(pbu_code)]
pbu_overlap <- intersect(pbu_e, pbu_l)
cat(sprintf("  Early FL-active PBUs:  %s\n", format(length(pbu_e), big.mark=",")))
cat(sprintf("  Late  FL-active PBUs:  %s\n", format(length(pbu_l), big.mark=",")))
cat(sprintf("  Overlap:               %s (%.1f%% of early)\n",
            format(length(pbu_overlap), big.mark=","),
            100 * length(pbu_overlap) / max(length(pbu_e), 1L)))

# ---- Summary table -----------------------------------------------------
summ <- data.table(
  unit_of_analysis = c("Firm",
                       "Market (PBU × item-group, ≥5 tenders)",
                       "PBU"),
  early_n = c(length(fl_e_set), length(mkt_e_fl_set), length(pbu_e)),
  late_n  = c(length(fl_l_set), length(mkt_l_fl_set), length(pbu_l)),
  overlap_n   = c(length(overlap_firm), length(overlap_mkt), length(pbu_overlap)),
  persistence_pct = c(
    round(100 * length(overlap_firm) / max(length(fl_e_set), 1L), 1),
    round(100 * length(overlap_mkt) / max(length(mkt_e_fl_set), 1L), 1),
    round(100 * length(pbu_overlap) / max(length(pbu_e), 1L), 1)
  )
)
fwrite(summ, file.path(OUT, "persistence_summary.csv"))
cat("\n=== Persistence summary ===\n")
print(summ)

# ---- Plot ---------------------------------------------------------------
p <- ggplot(summ, aes(x = unit_of_analysis, y = persistence_pct)) +
  geom_col(fill = "#5b8aa6", width = 0.5) +
  geom_text(aes(label = paste0(persistence_pct, "%")),
            vjust = -0.6, size = 4) +
  scale_y_continuous(limits = c(0, 100), expand = c(0, 0)) +
  labs(x = NULL, y = "Persistence: % of early-period FL units that remain FL in late period",
       title = "Firm- vs market-level FL persistence: 2009-2013 → 2014-2019",
       subtitle = "Firm: 10% (v13). Market: much higher → validates 'environment marker' language") +
  theme_bw() + theme(panel.grid.major.x = element_blank())
ggsave(file.path(OUT, "fig_persistence.pdf"), p,
       width = 7, height = 4.2, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", file.path(OUT, "fig_persistence.pdf")))

cat("\n  Done.\n")
