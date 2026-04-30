# ============================================================================
# 26_auc_by_subsample.R — AUC by data-richness subsample (A1.1)
# Paper 3 v14: address Fragility 1 by demonstrating where FL screen
# substantively outperforms Imhof-style alternatives.
#
# Hypothesis: in data-thin subsamples (firms without enough priced bids
# to compute Imhof CV/spread), Imhof's screen is unavailable, but FL still
# detects cartels. If AUC of FL flag is high in BOTH data-rich and
# data-thin subsamples, then FL captures cartel signature where bid-
# microdata-based screens cannot.
#
# Subsamples:
#   - full:           all always-losers with CADE crossmatch (16,843)
#   - data-rich:      always-losers with valid Imhof CV + spread features
#   - data-thin:      always-losers WITHOUT valid Imhof features
#   - low n_bids:     always-losers whose tenders have < 3 bidders on average
#   - high n_bids:    always-losers whose tenders have ≥ 3 bidders on average
#
# Per subsample: compute AUC of (a) FL binary flag, (b) continuous
# tenders_count, (c) Imhof CV (where available), (d) Imhof spread.
#
# Output:
#   output/auc_by_subsample/auc_subsample.csv
#   output/auc_by_subsample/fig_auc_subsample.pdf
# ============================================================================

cat("=== 26_auc_by_subsample.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "auc_by_subsample")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data -----------------------------------------------------------
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cade_codes <- unique(cade$firm_code)

# bid-level with prices
bl_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
bl <- as.data.table(read_parquet(bl_path))
bl[, firm_code := as.character(`códigofornecedor`)]
cat(sprintf("  bid-level rows (with prices): %s\n", format(nrow(bl), big.mark=",")))

fp[, firm_code := as.character(`códigofornecedor`)]
THRESH <- 14L

# ---- Per-firm feature panel: Imhof CV + spread + tenders_count ----------
cat("\n  Building per-firm feature panel...\n")

# Imhof CV/spread per firm: CV of bid_price across firm's bids (priced ones)
imhof <- bl[!is.na(bid_price) & bid_price > 0,
            .(n_priced_bids = .N,
              imhof_cv      = sd(bid_price) / pmax(mean(bid_price), 1),
              imhof_log_sd  = sd(log(bid_price)),
              imhof_skew    = mean((bid_price - mean(bid_price))^3) /
                               pmax(sd(bid_price)^3, 1e-6)),
            by = firm_code]

# n_bids per tender (avg) per firm
ftm[, firm_code := as.character(`códigofornecedor`)]
firm_avg_nbids <- ftm[, .(avg_n_bids = mean(n_bids)), by = firm_code]

# Build always-loser feature panel
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, is_fl := as.integer(tenders_count > THRESH)]
al[, is_cade := as.integer(firm_code %in% cade_codes)]

al <- merge(al, imhof, by = "firm_code", all.x = TRUE)
al <- merge(al, firm_avg_nbids, by = "firm_code", all.x = TRUE)

cat(sprintf("  Always-loser pool: %s firms\n", format(nrow(al), big.mark=",")))
cat(sprintf("  CADE positives:    %s\n", format(sum(al$is_cade), big.mark=",")))
cat(sprintf("  Firms with Imhof CV:        %s (%.1f%%)\n",
            format(sum(!is.na(al$imhof_cv)), big.mark=","),
            100 * mean(!is.na(al$imhof_cv))))
cat(sprintf("  Firms with Imhof + ≥3 bids: %s\n",
            format(sum(!is.na(al$imhof_cv) & al$n_priced_bids >= 3), big.mark=",")))

# ---- Subsample definitions -----------------------------------------------
al[, has_imhof    := as.integer(!is.na(imhof_cv) & is.finite(imhof_cv) &
                                  !is.na(imhof_log_sd) & is.finite(imhof_log_sd) &
                                  n_priced_bids >= 3L)]
al[, low_nbids    := as.integer(!is.na(avg_n_bids) & avg_n_bids < 3)]
al[, high_nbids   := as.integer(!is.na(avg_n_bids) & avg_n_bids >= 3)]

subsamples <- list(
  list(name = "full",            mask = rep(TRUE, nrow(al))),
  list(name = "data_rich",       mask = al$has_imhof == 1L),
  list(name = "data_thin",       mask = al$has_imhof == 0L),
  list(name = "low_n_bids",      mask = al$low_nbids == 1L),
  list(name = "high_n_bids",     mask = al$high_nbids == 1L)
)

# ---- AUC per subsample ----------------------------------------------------
calc_auc <- function(label, score, name) {
  if (length(unique(label)) < 2 || sum(label) < 5) {
    return(list(auc = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
                n = length(label), n_pos = sum(label)))
  }
  if (all(is.na(score))) return(list(auc = NA_real_, ci_lo = NA_real_,
                                       ci_hi = NA_real_, n = length(label),
                                       n_pos = sum(label)))
  ok <- !is.na(score) & is.finite(score)
  if (sum(ok) < 50 || length(unique(label[ok])) < 2) {
    return(list(auc = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
                n = sum(ok), n_pos = sum(label[ok])))
  }
  r <- pROC::roc(label[ok], score[ok], quiet = TRUE)
  list(auc = as.numeric(pROC::auc(r)),
       ci_lo = as.numeric(pROC::ci(r)[1]),
       ci_hi = as.numeric(pROC::ci(r)[3]),
       n = sum(ok),
       n_pos = sum(label[ok]))
}

results <- list()
for (sub in subsamples) {
  d <- al[sub$mask]
  cat(sprintf("\n  Subsample [%s]: n=%s (CADE+ = %s)\n",
              sub$name, format(nrow(d), big.mark=","),
              format(sum(d$is_cade), big.mark=",")))

  for (score_name in c("is_fl", "tenders_count", "imhof_cv", "imhof_log_sd")) {
    a <- calc_auc(d$is_cade, d[[score_name]], score_name)
    if (!is.na(a$auc)) {
      cat(sprintf("    AUC[%s] = %.4f [%.4f, %.4f] (n=%s, +=%s)\n",
                  score_name, a$auc, a$ci_lo, a$ci_hi,
                  format(a$n, big.mark=","), format(a$n_pos, big.mark=",")))
      results[[length(results) + 1]] <- data.table(
        subsample = sub$name,
        score     = score_name,
        auc       = a$auc, ci_lo = a$ci_lo, ci_hi = a$ci_hi,
        n         = a$n,   n_pos = a$n_pos
      )
    } else {
      cat(sprintf("    AUC[%s] = NA (insufficient data)\n", score_name))
    }
  }
}

res_dt <- rbindlist(results, fill = TRUE)
fwrite(res_dt, file.path(OUT, "auc_subsample.csv"))

# ---- Plot ---------------------------------------------------------------
plot_dt <- res_dt[score %in% c("is_fl", "tenders_count", "imhof_cv", "imhof_log_sd")]
plot_dt[, score_label := fcase(
  score == "is_fl",         "FL flag (binary)",
  score == "tenders_count", "tenders_count (continuous)",
  score == "imhof_cv",      "Imhof CV",
  score == "imhof_log_sd",  "Imhof log-spread",
  default = score
)]
plot_dt[, subsample_label := fcase(
  subsample == "full",        "Full pool (16,843)",
  subsample == "data_rich",   "Data-rich (Imhof feasible)",
  subsample == "data_thin",   "Data-thin (Imhof infeasible)",
  subsample == "low_n_bids",  "Low n_bids (avg<3)",
  subsample == "high_n_bids", "High n_bids (avg≥3)"
)]
plot_dt[, subsample_label := factor(subsample_label,
  levels = c("Full pool (16,843)",
             "Data-rich (Imhof feasible)",
             "Data-thin (Imhof infeasible)",
             "Low n_bids (avg<3)",
             "High n_bids (avg≥3)"))]
plot_dt[, score_label := factor(score_label,
  levels = c("FL flag (binary)",
             "tenders_count (continuous)",
             "Imhof CV",
             "Imhof log-spread"))]

p <- ggplot(plot_dt, aes(x = subsample_label, y = auc,
                          fill = score_label)) +
  geom_hline(yintercept = 0.5, linetype = "dotted", color = "gray60") +
  geom_col(position = position_dodge(width = 0.85), width = 0.8,
           color = "white", linewidth = 0.3) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                position = position_dodge(width = 0.85), width = 0.2,
                color = "gray30") +
  geom_text(aes(label = ifelse(is.na(auc), "",
                                sprintf("%.2f", auc))),
            position = position_dodge(width = 0.85), vjust = -0.3, size = 2.7) +
  scale_y_continuous(limits = c(0.45, 1.0), breaks = seq(0.5, 1, 0.1)) +
  scale_fill_manual(values = c("FL flag (binary)"          = "#d73027",
                                "tenders_count (continuous)" = "#9e3a4d",
                                "Imhof CV"                   = "#5b8aa6",
                                "Imhof log-spread"           = "#3b8dbd")) +
  labs(x = NULL, y = "AUC against CADE co-bidder labels",
       title = "Detection AUC by data-richness subsample",
       subtitle = "FL preserves AUC where Imhof bid-microdata features are unavailable",
       fill  = "Score") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1),
        legend.position = "bottom")

ggsave(file.path(OUT, "fig_auc_subsample.pdf"), p,
       width = 10, height = 5.5, device = cairo_pdf)
cat(sprintf("\n  Saved: %s\n", file.path(OUT, "fig_auc_subsample.pdf")))

cat("\n  Done.\n")
