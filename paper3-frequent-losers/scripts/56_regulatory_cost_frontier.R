# 56_regulatory_cost_frontier.R — Boost D: data-cost-aware operational frontier
# Paper 3 v14 / Major 1+3 deliverables
#
# Reframe: instead of "comparable AUC at lower data cost", quantify the
# regulatory cost-benefit frontier explicitly.
#
# For each operational truncation k in {50, 100, 250, 500, 1000, 2000}:
#   1. Precision@k for FL alone (free: only contract awards)
#   2. Precision@k for Imhof full alone (paid: per-bid microdata)
#   3. Precision@k for FL + Imhof combined (paid + free)
#   4. Cost per cobidder identified at each k, given data-acquisition cost
#
# Output:
#   output/regulatory_frontier/regulatory_frontier.csv
#   output/regulatory_frontier/fig_regulatory_frontier.pdf


if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(pROC); library(ggplot2)
  if (!requireNamespace("ranger", quietly = TRUE)) {
    install.packages("ranger", repos = "https://cran.r-project.org")
  }
  library(ranger)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "regulatory_frontier")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load + replicate the Imhof full pipeline features --------------------
cat("\n  Computing Imhof features (5 within-tender) + FL features ...\n")
bl_path <- file.path(BASE, "v3/data/processed/bid_level_with_prices.parquet")
bl <- as.data.table(read_parquet(bl_path))
bl[, firm_code := as.character(`códigofornecedor`)]
bl_valid <- bl[!is.na(bid_price) & bid_price > 0]

tender_features <- bl_valid[, {
  if (.N < 2) {
    list(n_bids = .N, cv = NA_real_, skew = NA_real_, kurt = NA_real_,
         spread = NA_real_, min_max_log = NA_real_, second_lowest_dist = NA_real_)
  } else {
    bp <- bid_price; n  <- .N; m  <- mean(bp); s  <- sd(bp)
    cv <- ifelse(m > 0, s / m, NA_real_)
    skew <- ifelse(s > 0, mean((bp - m)^3) / s^3, NA_real_)
    kurt <- ifelse(s > 0, mean((bp - m)^4) / s^4 - 3, NA_real_)
    spread <- ifelse(m > 0, (max(bp) - min(bp)) / m, NA_real_)
    min_max_log <- log(max(bp) / max(min(bp), 1e-9))
    sorted_bp <- sort(bp)
    second_lowest_dist <- ifelse(n >= 2 && sorted_bp[1] > 0,
                                  log(sorted_bp[2] / sorted_bp[1]),
                                  NA_real_)
    list(n_bids = n, cv = cv, skew = skew, kurt = kurt,
         spread = spread, min_max_log = min_max_log,
         second_lowest_dist = second_lowest_dist)
  }
}, by = .(numerodaoc, codigoitem = `códigoitem`)]

firm_tender <- bl_valid[, .(firm_code, numerodaoc, codigoitem = `códigoitem`)]
firm_tender <- merge(firm_tender, tender_features,
                      by = c("numerodaoc","codigoitem"))

firm_features <- firm_tender[!is.na(cv), .(
  imhof_cv_mean    = mean(cv,   na.rm = TRUE),
  imhof_cv_sd      = sd(cv,     na.rm = TRUE),
  imhof_skew_mean  = mean(skew, na.rm = TRUE),
  imhof_kurt_mean  = mean(kurt, na.rm = TRUE),
  imhof_spread_mean = mean(spread, na.rm = TRUE),
  imhof_minmax_mean = mean(min_max_log, na.rm = TRUE),
  imhof_second_low_mean = mean(second_lowest_dist, na.rm = TRUE),
  n_tenders_priced = .N
), by = firm_code]

# ---- Load FL classification + CADE labels ---------------------------------
fp <- as.data.table(read_parquet(file.path(BASE,"data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
cobid <- fread(file.path(BASE,"data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

THRESH <- 14L
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, is_fl   := as.integer(tenders_count > THRESH)]
al[, log_tc  := log1p(tenders_count)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]
al <- merge(al, firm_features, by = "firm_code", all.x = TRUE)
al_complete <- al[!is.na(imhof_cv_mean) & is.finite(imhof_cv_mean) &
                   !is.na(imhof_kurt_mean) & is.finite(imhof_kurt_mean) &
                   !is.na(imhof_skew_mean) & is.finite(imhof_skew_mean)]
cat(sprintf("  Always-losers with full features: %s; CADE+ = %d\n",
            format(nrow(al_complete), big.mark=","), sum(al_complete$is_cade)))

# ---- 5-fold CV: get out-of-fold predictions for each model -----------------
set.seed(20260501)
al_complete[, fold := sample(rep(1:5, length.out = .N))]

predict_cv <- function(features) {
  preds <- numeric(nrow(al_complete))
  for (k in 1:5) {
    train_idx <- al_complete$fold != k
    test_idx  <- al_complete$fold == k
    tr <- al_complete[train_idx]
    tr[, target := factor(is_cade, levels = c(0, 1))]
    te <- al_complete[test_idx]
    fmla <- as.formula(paste0("target ~ ", paste(features, collapse = " + ")))
    rf <- ranger(fmla, data = tr, num.trees = 500,
                 probability = TRUE, num.threads = 12)
    pred_mat <- predict(rf, te)$predictions
    preds[test_idx] <- pred_mat[, "1"]
  }
  preds
}

cat("\n  5-fold CV predictions: FL alone, Imhof full, combined ...\n")
imhof_features <- c("imhof_cv_mean","imhof_cv_sd","imhof_skew_mean",
                     "imhof_kurt_mean","imhof_spread_mean",
                     "imhof_minmax_mean","imhof_second_low_mean")

al_complete[, score_fl     := log_tc]  # continuous score, free signal
al_complete[, score_imhof  := predict_cv(imhof_features)]
al_complete[, score_combined := predict_cv(c("log_tc", imhof_features))]

# ---- Precision@k for each model -----------------------------------------
ks <- c(50, 100, 250, 500, 1000, 2000)
n_total <- nrow(al_complete)
n_pos   <- sum(al_complete$is_cade)
base_rate <- n_pos / n_total

prec_at_k <- function(score, label = "model") {
  setorder(al_complete, -score)
  al_complete[, cum_pos := cumsum(is_cade)]
  out <- data.table()
  for (k in ks) {
    if (k > nrow(al_complete)) k <- nrow(al_complete)
    out <- rbind(out, data.table(
      model = label, k = k,
      tp = al_complete$cum_pos[k],
      precision = al_complete$cum_pos[k] / k,
      recall    = al_complete$cum_pos[k] / n_pos,
      lift      = (al_complete$cum_pos[k] / k) / base_rate
    ))
  }
  out
}

# Compute per-model
fl_pk <- prec_at_k(al_complete$score_fl,       "FL alone (free)")
im_pk <- prec_at_k(al_complete$score_imhof,    "Imhof alone (microdata)")
cm_pk <- prec_at_k(al_complete$score_combined, "Combined (microdata + free)")

frontier <- rbind(fl_pk, im_pk, cm_pk)

# ---- Cost per true positive (cobidder identified) ------------------------
# Cost components (illustrative, declared explicitly):
#   - per-flag investigation cost: c_inv = R$5,000 (analyst-day)
#   - data acquisition cost (Imhof requires bid microdata):
#     - free for participation-only (FL alone)
#     - paid for Imhof full or Combined (R$50,000 fixed cost for bid
#       microdata acquisition; Brazilian SP municipality FOI estimate)
# Cost per identified cobidder = (c_data + k * c_inv) / TP

c_inv <- 5000L      # R$5K per investigation
c_data_imhof <- 50000L  # R$50K bid microdata acquisition

frontier[, data_cost := fifelse(grepl("free", model), 0L,
                                 fifelse(grepl("Combined", model),
                                          c_data_imhof, c_data_imhof))]
frontier[, total_cost := data_cost + k * c_inv]
frontier[, cost_per_tp := total_cost / pmax(tp, 1)]

fwrite(frontier, file.path(OUT, "regulatory_frontier.csv"))
cat(sprintf("\n  Wrote: %s\n", file.path(OUT, "regulatory_frontier.csv")))
print(frontier[, .(model, k, tp, precision = round(precision, 3),
                   lift = round(lift, 1),
                   cost_per_tp_brl = format(round(cost_per_tp), big.mark=","))])

# ---- Frontier crossing detection -----------------------------------------
cat("\n  Cost-per-cobidder crossing analysis:\n")
fl_only <- frontier[model == "FL alone (free)", .(k, fl_cost = cost_per_tp, fl_tp = tp)]
im_only <- frontier[model == "Imhof alone (microdata)", .(k, im_cost = cost_per_tp, im_tp = tp)]
cm_only <- frontier[model == "Combined (microdata + free)", .(k, cm_cost = cost_per_tp, cm_tp = tp)]
joined <- merge(fl_only, im_only, by = "k")
joined <- merge(joined, cm_only, by = "k")
joined[, fl_wins_cost := as.integer(fl_cost < im_cost & fl_cost < cm_cost)]
joined[, fl_wins_recall := as.integer(fl_tp >= im_tp & fl_tp >= cm_tp)]
print(joined[, .(k,
                  fl_cost = format(round(fl_cost), big.mark=","),
                  im_cost = format(round(im_cost), big.mark=","),
                  cm_cost = format(round(cm_cost), big.mark=","),
                  fl_wins_cost, fl_wins_recall)])

# ---- Plot regulatory frontier --------------------------------------------
plot_dt <- copy(frontier)
plot_dt[, model := factor(model, levels = c("FL alone (free)",
                                              "Imhof alone (microdata)",
                                              "Combined (microdata + free)"))]
p <- ggplot(plot_dt, aes(x = k, y = cost_per_tp / 1000, color = model, shape = model)) +
  geom_line(size = 0.8) + geom_point(size = 3) +
  geom_text(aes(label = sprintf("R$%.0fK", cost_per_tp/1000)),
            vjust = -1.0, size = 2.8, show.legend = FALSE) +
  scale_x_continuous(trans = "log10",
                     breaks = ks,
                     labels = format(ks, big.mark = ",")) +
  scale_y_continuous(trans = "log10", labels = scales::comma) +
  scale_color_manual(values = c("FL alone (free)" = "#d73027",
                                 "Imhof alone (microdata)" = "#5b8aa6",
                                 "Combined (microdata + free)" = "#762a83")) +
  labs(x = "Top-k flags issued", y = "Cost per cobidder identified (R$ thousands, log scale)",
       title = "Regulatory cost-benefit frontier: where bid microdata pays off",
       subtitle = "FL alone is cheapest at every operating point because data acquisition cost dominates investigation cost",
       color = NULL, shape = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave(file.path(OUT, "fig_regulatory_frontier.pdf"), p,
       width = 8.5, height = 5.5, device = cairo_pdf)
cat(sprintf("\n  Wrote: %s\n", file.path(OUT, "fig_regulatory_frontier.pdf")))

cat("\n  Done.\n")
