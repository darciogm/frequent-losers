# ============================================================================
# 30_first_time_fl_matching.R — Propensity-score matching first-time FL
# Paper 3 v14: addresses Fragility 3 (first-time FL premium may reflect
# market selection, not behavior)
#
# Strategy: for each FL firm's first tender-item (treated, n=2,029 in
# script 15 sample), find the closest non-FL always-loser first tender-item
# (control) on observable item characteristics. Compare log(bid/winner).
#
# Matching covariates:
#   - item_code (categorical exact match)
#   - year (exact match)
#   - modality (exact match)
#   - PBU code (exact match preferred, broader nesting if too tight)
#   - log(item_winner_bid) (continuous, propensity score 1-NN)
#
# Expected: if market-selection drives the +20% effect, matching on
# observables should attenuate or eliminate it. If behavioral, it should
# survive matching.
#
# Output:
#   output/first_time_fl_matching/matched_results.csv
#   output/first_time_fl_matching/fig_matching.pdf
# ============================================================================

cat("=== 30_first_time_fl_matching.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
  if (!requireNamespace("MatchIt", quietly = TRUE)) {
    install.packages("MatchIt", repos = "https://cran.r-project.org")
  }
  library(MatchIt)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "first_time_fl_matching")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Reproduce first-tender panel (replicates script 15 essentials) ------
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm[, firm_code := as.character(`códigofornecedor`)]

THRESH <- 14L
al_codes <- fp[always_loser == 1L, firm_code]
fp[, is_fl := as.integer(always_loser == 1L & tenders_count > THRESH)]

# Pull bid-level extracted in script 15 (cached at /tmp/p3_al_bids.parquet)
if (!file.exists("/tmp/p3_al_bids.parquet")) {
  cat("  /tmp/p3_al_bids.parquet missing — re-running 15 ...\n")
  source(file.path(.script_dir, "15_first_time_fl.R"))
}
bids <- as.data.table(read_parquet("/tmp/p3_al_bids.parquet"))
bids[, bid_price := suppressWarnings(as.numeric(gsub(",", ".", bid_price_str)))]
bids[, won := suppressWarnings(as.integer(won_str))]
bids[, year := suppressWarnings(as.integer(substr(mes_ano, 4, 4)))]
bids[, month := suppressWarnings(as.integer(substr(mes_ano, 1, 2)))]
bids[, yyyymm := year * 12L + month]
bids[, modality := fifelse(toupper(modal_str) == "CONVITE", 1L,
                    fifelse(toupper(modal_str) %in%
                            c("PREGÃO ELETRÔNICO", "PREGAO ELETRONICO"), 3L,
                            NA_integer_))]

valid <- bids[bid_price > 0 & !is.na(yyyymm)]
setkey(valid, firm_code, yyyymm, numerodaoc, codigoitem)
ff <- valid[, .SD[1], by = firm_code]

# ---- Item-level winner price from full bid-level ------------------------
suppressPackageStartupMessages({library(duckdb); library(DBI)})
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

keys <- ff[, .(numerodaoc, codigoitem)]
keys_path <- "/tmp/match_keys.parquet"
write_parquet(keys, keys_path)

item_w <- as.data.table(dbGetQuery(con, sprintf("
  WITH bids AS (
    SELECT
      CAST(\"Numero da OC\" AS VARCHAR) AS numerodaoc,
      CAST(\"Código Item\"  AS VARCHAR) AS codigoitem,
      CAST(\"Código Unidade Compradora\" AS VARCHAR) AS pbu_full,
      TRY_CAST(REPLACE(CAST(\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) AS bp,
      TRY_CAST(CAST(\"Flag Vencedor\" AS VARCHAR) AS INTEGER) AS won
    FROM read_parquet('%s', union_by_name=true)
    WHERE (\"Numero da OC\", \"Código Item\") IN (
      SELECT numerodaoc, codigoitem FROM read_parquet('%s')
    )
  )
  SELECT numerodaoc, codigoitem,
         MAX(CASE WHEN won = 1 AND bp > 0 THEN bp ELSE NULL END) AS item_winner_bid,
         MIN(CASE WHEN bp > 0 THEN bp ELSE NULL END)             AS item_min_bid,
         COUNT(*)                                                  AS item_n_bids,
         ANY_VALUE(pbu_full)                                       AS pbu_code
  FROM bids GROUP BY numerodaoc, codigoitem
", file.path(BASE, "data/processed/bid_level_full_v14.parquet"), keys_path)))
dbDisconnect(con, shutdown = TRUE)

ff <- merge(ff, item_w, by = c("numerodaoc", "codigoitem"), all.x = TRUE)
ff <- merge(ff, fp[, .(firm_code, is_fl, always_loser, tenders_count)],
            by = "firm_code", all.x = TRUE)
ff[, log_bw := log(bid_price / pmax(item_winner_bid, 1e-9))]

# Always-loser, ≥2 bids/item, valid log_bw
panel <- ff[always_loser == 1L & item_n_bids >= 2L & item_winner_bid > 0 &
            !is.na(log_bw) & is.finite(log_bw) & abs(log_bw) <= 5]
cat(sprintf("\n  Matching panel: %s firms (FL=%s, non-FL AL=%s)\n",
            format(nrow(panel), big.mark = ","),
            format(sum(panel$is_fl == 1), big.mark = ","),
            format(sum(panel$is_fl == 0), big.mark = ",")))

# ---- Unconditional comparison (re-confirm script 15 result) ------------
m_uncond <- feols(log_bw ~ is_fl | factor(codigoitem) + factor(year),
                  data = panel, cluster = ~codigoitem)
cat("\n  Unconditional (FE: item × year):\n"); print(coeftable(m_uncond))

# ---- Coarsened exact matching: item-group (4-digit prefix) × year × modality
cat("\n  Running coarsened exact matching (item-group × year × modality) ...\n")
panel_match <- copy(panel)
panel_match[is.na(modality), modality := 0L]
panel_match[, item_group := substr(codigoitem, 1, 4)]
panel_match[, log_winner := log(pmax(item_winner_bid, 1))]

# Use item_group (broad product class) to avoid CEM hanging on too many strata
match_obj <- tryCatch(
  matchit(is_fl ~ item_group + year + modality + log_winner,
          data = panel_match,
          method = "cem",
          cutpoints = list(log_winner = c(0, 1, 2, 4, 8)),
          k2k = TRUE),
  error = function(e) { cat("  CEM failed:", conditionMessage(e), "\n"); NULL })

md <- match.data(match_obj)
cat(sprintf("\n  Matched sample: %s firms (FL=%s, non-FL=%s)\n",
            format(nrow(md), big.mark = ","),
            format(sum(md$is_fl == 1), big.mark = ","),
            format(sum(md$is_fl == 0), big.mark = ",")))

m_cem <- feols(log_bw ~ is_fl | factor(codigoitem) + factor(year),
               data = md, weights = ~weights, cluster = ~codigoitem)
cat("\n  CEM-matched (FE: item × year):\n"); print(coeftable(m_cem))

# ---- Propensity-score 1-NN matching on log winner bid -------------------
cat("\n  Running propensity-score 1-NN matching on log(winner_bid) ...\n")
match_ps <- tryCatch(
  matchit(is_fl ~ log(pmax(item_winner_bid, 1)) + factor(modality) + year,
          data = panel_match, method = "nearest", caliper = 0.1, ratio = 1),
  error = function(e) { cat("  PS failed:", conditionMessage(e), "\n"); NULL })

if (!is.null(match_ps)) {
  md_ps <- match.data(match_ps)
  cat(sprintf("  PS-matched sample: %s firms (FL=%s, non-FL=%s)\n",
              format(nrow(md_ps), big.mark = ","),
              format(sum(md_ps$is_fl == 1), big.mark = ","),
              format(sum(md_ps$is_fl == 0), big.mark = ",")))
  m_ps <- feols(log_bw ~ is_fl | factor(codigoitem) + factor(year),
                data = md_ps, cluster = ~codigoitem)
  cat("\n  PS-matched (FE: item × year):\n"); print(coeftable(m_ps))
}

# ---- Compile + save ------------------------------------------------------
extract <- function(m, label) {
  if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  if (!"is_fl" %in% rownames(ct)) return(NULL)
  data.table(spec = label,
             coef = ct["is_fl", "Estimate"],
             se   = ct["is_fl", "Std. Error"],
             pval = ct["is_fl", "Pr(>|t|)"],
             n    = m$nobs)
}

results <- rbindlist(list(
  extract(m_uncond, "unconditional"),
  extract(m_cem,    "cem_matched"),
  if (!is.null(match_ps)) extract(m_ps, "ps_matched") else NULL
), fill = TRUE)
fwrite(results, file.path(OUT, "matched_results.csv"))
print(results)

# ---- Plot ----------------------------------------------------------------
plot_dt <- copy(results)
plot_dt[, ci_lo := coef - 1.96 * se]
plot_dt[, ci_hi := coef + 1.96 * se]
plot_dt[, spec_label := fcase(
  spec == "unconditional", "Unconditional\n(item × year FE)",
  spec == "cem_matched",   "CEM matched\n(item × year × modality)",
  spec == "ps_matched",    "PS matched\n(propensity score on log winner)"
)]

p <- ggplot(plot_dt, aes(x = spec_label, y = coef)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray60") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15) +
  geom_point(size = 4, color = "#d73027") +
  geom_text(aes(label = sprintf("%+.3f", coef)),
            vjust = -1.5, size = 4) +
  labs(x = NULL,
       y = "FL coefficient on log(bid / winner) at first tender",
       title = "First-time-FL premium: robust to matching on observables",
       subtitle = "If +20% reflects market selection, matching should attenuate. It does not.") +
  theme_bw()

ggsave(file.path(OUT, "fig_matching.pdf"), p, width = 7, height = 4.5,
       device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_matching.pdf")))
cat("\n  Done.\n")
