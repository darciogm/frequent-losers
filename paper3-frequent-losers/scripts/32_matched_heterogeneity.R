# ============================================================================
# 32_matched_heterogeneity.R — FL premium heterogeneity in matched sample
# Paper 3 v14
#
# Test whether the +6-8% matched first-tender FL premium concentrates in
# the cartel-signature cell (Low HHI × High pairs).
#
# Output:
#   output/matched_heterogeneity/matched_het_results.csv
#   output/matched_heterogeneity/fig_matched_het.pdf
# ============================================================================

cat("=== 32_matched_heterogeneity.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
  if (!requireNamespace("MatchIt", quietly = TRUE)) {
    install.packages("MatchIt", repos = "https://cran.r-project.org")
  }
  library(MatchIt)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "matched_heterogeneity")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]
ftm[, year := suppressWarnings(as.integer(substr(numerodaoc, 12, 15)))]
ftm[, pbu_code := substr(numerodaoc, 1, 11)]
ftm[, item_group := substr(`códigoitem`, 1, 2)]
ftm[, cell_id := paste0(pbu_code, "_", item_group, "_", year)]

THRESH <- 14L
fp[, is_fl := as.integer(always_loser == 1L & tenders_count > THRESH)]
fl_firms <- fp[is_fl == 1L, firm_code]

# ---- Step 1: compute cell-level HHI + repeated FL-winner pairs ----------
cat("\n  Computing cell features (PBU × item-group × year) ...\n")
winners <- ftm[won == 1L, .(numerodaoc, `códigoitem`, oc_item_key,
                              cell_id, winner = firm_code)]
hhi <- winners[, {
  shares <- table(winner) / .N
  list(hhi = sum(shares^2))
}, by = cell_id]

ftm_fl <- ftm[firm_code %in% fl_firms & won == 0L,
              .(fl_firm = firm_code, oc_item_key, cell_id)]
fl_pairs <- merge(ftm_fl, winners[, .(oc_item_key, winner)], by = "oc_item_key")
pair_counts <- fl_pairs[, .N, by = .(cell_id, fl_firm, winner)]
rep_pairs <- pair_counts[N >= 2, .(rep_pair_count = .N), by = cell_id]

cell_feat <- merge(hhi, rep_pairs, by = "cell_id", all.x = TRUE)
cell_feat[is.na(rep_pair_count), rep_pair_count := 0L]
cell_feat[, hhi_high := as.integer(hhi > median(hhi, na.rm = TRUE))]
cell_feat[, pair_high := as.integer(rep_pair_count > 0L)]
cell_feat[, quadrant := fcase(
  hhi_high == 0L & pair_high == 0L, "Low HHI × Low pairs",
  hhi_high == 0L & pair_high == 1L, "Low HHI × High pairs",
  hhi_high == 1L & pair_high == 0L, "High HHI × Low pairs",
  hhi_high == 1L & pair_high == 1L, "High HHI × High pairs"
)]
cat(sprintf("  Cells with quadrant: %s\n",
            format(sum(!is.na(cell_feat$quadrant)), big.mark=",")))

# ---- Step 2: build first-tender panel with quadrant via oc_item_key ----
if (!file.exists("/tmp/p3_al_bids.parquet")) {
  source(file.path(.script_dir, "15_first_time_fl.R"))
}
bids <- as.data.table(read_parquet("/tmp/p3_al_bids.parquet"))
bids[, bid_price := suppressWarnings(as.numeric(gsub(",", ".", bid_price_str)))]
bids[, year := suppressWarnings(as.integer(substr(mes_ano, 4, 4)))]
bids[, month := suppressWarnings(as.integer(substr(mes_ano, 1, 2)))]
bids[, yyyymm := year * 12L + month]
bids[, modality := fifelse(toupper(modal_str) == "CONVITE", 1L,
                    fifelse(toupper(modal_str) %in%
                            c("PREGÃO ELETRÔNICO", "PREGAO ELETRONICO"), 3L,
                            NA_integer_))]
bids[, oc_item_key := paste0(numerodaoc, "_", codigoitem)]

valid <- bids[bid_price > 0 & !is.na(yyyymm)]
setkey(valid, firm_code, yyyymm, numerodaoc, codigoitem)
ff <- valid[, .SD[1], by = firm_code]

# Map oc_item_key → cell_id from FTM (one ftm row per oc-item-firm; take first)
oc_to_cell <- unique(ftm[, .(oc_item_key, cell_id)])
ff <- merge(ff, oc_to_cell, by = "oc_item_key", all.x = TRUE)
ff <- merge(ff, cell_feat[, .(cell_id, quadrant, hhi, rep_pair_count)],
            by = "cell_id", all.x = TRUE)

# Item winner price
suppressPackageStartupMessages({library(duckdb); library(DBI)})
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")
keys <- ff[, .(numerodaoc, codigoitem)]
write_parquet(keys, "/tmp/m32_keys.parquet")
item_w <- as.data.table(dbGetQuery(con, sprintf("
  WITH bids AS (
    SELECT
      CAST(\"Numero da OC\" AS VARCHAR) AS numerodaoc,
      CAST(\"Código Item\"  AS VARCHAR) AS codigoitem,
      TRY_CAST(REPLACE(CAST(\"Valor Unitário Proposta\" AS VARCHAR), ',', '.') AS DOUBLE) AS bp,
      TRY_CAST(CAST(\"Flag Vencedor\" AS VARCHAR) AS INTEGER) AS won
    FROM read_parquet('%s', union_by_name=true)
    WHERE (\"Numero da OC\", \"Código Item\") IN (
      SELECT numerodaoc, codigoitem FROM read_parquet('/tmp/m32_keys.parquet')
    )
  )
  SELECT numerodaoc, codigoitem,
         MAX(CASE WHEN won = 1 AND bp > 0 THEN bp ELSE NULL END) AS item_winner_bid,
         COUNT(*) AS item_n_bids
  FROM bids GROUP BY numerodaoc, codigoitem
", file.path(BASE, "data/processed/bid_level_full_v14.parquet"))))
dbDisconnect(con, shutdown = TRUE)

ff <- merge(ff, item_w, by = c("numerodaoc", "codigoitem"), all.x = TRUE)
ff <- merge(ff, fp[, .(firm_code, is_fl, always_loser, tenders_count)],
            by = "firm_code", all.x = TRUE)
ff[, log_bw := log(bid_price / pmax(item_winner_bid, 1e-9))]
ff[, item_group := substr(codigoitem, 1, 2)]

panel <- ff[always_loser == 1L & item_n_bids >= 2L & item_winner_bid > 0 &
            !is.na(log_bw) & is.finite(log_bw) & abs(log_bw) <= 5 &
            !is.na(quadrant)]
panel[is.na(modality), modality := 0L]
panel[, log_winner := log(pmax(item_winner_bid, 1))]

cat(sprintf("\n  Panel with quadrant: %s firms (FL=%s, non-FL AL=%s)\n",
            format(nrow(panel), big.mark=","),
            format(sum(panel$is_fl == 1), big.mark=","),
            format(sum(panel$is_fl == 0), big.mark=",")))
cat("\n  Quadrant distribution:\n")
print(panel[, .N, by = .(quadrant, is_fl)])

# ---- Per-quadrant FL coefficient (FE: item × year, no matching) --------
cat("\n--- Per-quadrant FL coefficient (item × year FE, item-clustered SE) ---\n")
results <- list()
for (q in c("Low HHI × Low pairs", "Low HHI × High pairs",
            "High HHI × Low pairs", "High HHI × High pairs")) {
  d_q <- panel[quadrant == q]
  if (nrow(d_q) < 100 || sum(d_q$is_fl == 1) < 30) {
    cat(sprintf("    [%s] N=%d, FL=%d  -- skipped\n",
                q, nrow(d_q), sum(d_q$is_fl == 1)))
    next
  }
  m <- tryCatch(
    feols(log_bw ~ is_fl | factor(codigoitem) + factor(year),
          data = d_q, cluster = ~codigoitem),
    error = function(e) { cat("    error:", conditionMessage(e), "\n"); NULL })
  if (is.null(m)) next
  ct <- coeftable(m)
  results[[q]] <- data.table(
    quadrant = q, sample = "unmatched",
    coef = ct["is_fl", "Estimate"],
    se   = ct["is_fl", "Std. Error"],
    pval = ct["is_fl", "Pr(>|t|)"],
    n    = m$nobs,
    n_fl = sum(d_q$is_fl == 1)
  )
  cat(sprintf("    [%s]  unmatched coef=%+.4f (SE %.4f, p=%.3g)  N=%s\n",
              q, results[[q]]$coef, results[[q]]$se, results[[q]]$pval,
              format(m$nobs, big.mark=",")))
}

# ---- Per-quadrant matched (CEM) -----------------------------------------
cat("\n--- Per-quadrant FL coefficient on CEM-matched sample ---\n")
match_obj <- tryCatch(
  matchit(is_fl ~ item_group + year + modality + log_winner,
          data = panel,
          method = "cem",
          cutpoints = list(log_winner = c(0, 1, 2, 4, 8)),
          k2k = TRUE),
  error = function(e) { cat("  CEM failed:", conditionMessage(e), "\n"); NULL })

if (!is.null(match_obj)) {
  md <- as.data.table(match.data(match_obj))
  cat(sprintf("  Matched panel: %s firms (FL=%s)\n",
              format(nrow(md), big.mark=","),
              format(sum(md$is_fl == 1), big.mark=",")))

  for (q in c("Low HHI × Low pairs", "Low HHI × High pairs",
              "High HHI × Low pairs", "High HHI × High pairs")) {
    d_q <- md[quadrant == q]
    if (nrow(d_q) < 100 || sum(d_q$is_fl == 1) < 30) {
      cat(sprintf("    [%s] N=%d, FL=%d  -- skipped (matched too few)\n",
                  q, nrow(d_q), sum(d_q$is_fl == 1)))
      next
    }
    m <- tryCatch(
      feols(log_bw ~ is_fl | factor(codigoitem) + factor(year),
            data = d_q, weights = ~weights, cluster = ~codigoitem),
      error = function(e) NULL)
    if (is.null(m)) next
    ct <- coeftable(m)
    results[[paste0(q, "_matched")]] <- data.table(
      quadrant = q, sample = "matched",
      coef = ct["is_fl", "Estimate"],
      se   = ct["is_fl", "Std. Error"],
      pval = ct["is_fl", "Pr(>|t|)"],
      n    = m$nobs,
      n_fl = sum(d_q$is_fl == 1)
    )
    cat(sprintf("    [%s]  matched coef=%+.4f (SE %.4f, p=%.3g)  N=%s\n",
                q, ct["is_fl","Estimate"], ct["is_fl","Std. Error"],
                ct["is_fl","Pr(>|t|)"], format(m$nobs, big.mark=",")))
  }
}

res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, file.path(OUT, "matched_het_results.csv"))

# ---- Plot ---------------------------------------------------------------
if (nrow(res_dt) >= 2) {
  res_dt[, ci_lo := coef - 1.96 * se]
  res_dt[, ci_hi := coef + 1.96 * se]
  res_dt[, quadrant := factor(quadrant,
    levels = c("Low HHI × Low pairs", "Low HHI × High pairs",
               "High HHI × Low pairs", "High HHI × High pairs"))]
  p <- ggplot(res_dt, aes(x = quadrant, y = coef * 100, color = sample,
                            shape = sample)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbar(aes(ymin = ci_lo * 100, ymax = ci_hi * 100),
                  width = 0.15,
                  position = position_dodge(width = 0.4)) +
    geom_point(size = 3.5,
               position = position_dodge(width = 0.4)) +
    scale_color_manual(values = c("unmatched" = "#5b8aa6",
                                   "matched" = "#d73027")) +
    labs(x = "Cell type",
         y = "FL coefficient on log(bid/winner) — first tender",
         title = "First-tender FL premium by network quadrant — unmatched vs CEM-matched",
         color = "Sample", shape = "Sample") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 15, hjust = 1),
          legend.position = "bottom")
  ggsave(file.path(OUT, "fig_matched_het.pdf"), p,
         width = 8, height = 5, device = cairo_pdf)
  cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_matched_het.pdf")))
}

cat("\n  Done.\n")
