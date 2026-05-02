# 61_sign_reversal_segment_decomp.R
#
# Where does the sign reversal actually live?
# Script 59 already showed that broad +0.064 -> ATT-overlap -0.097 is mostly
# a reweighting story. This script goes one level deeper: it asks which
# segments (item group, PBU quintile, tender-value quintile, year cohort)
# carry the broad-sample positive, where the ATT weights pull from, and
# whether trimming the heaviest cells flips or strengthens the negative.
#
# Outputs:
#   output/sign_reversal_segment/segment_betas.csv
#   output/sign_reversal_segment/att_weight_concentration.csv
#   output/sign_reversal_segment/top_weight_cells.csv
#   output/sign_reversal_segment/att_trim_sensitivity.csv
#   output/sign_reversal_segment/fig_segment_betas.pdf
#   work/v13/output/tables/tab_sign_reversal_segment.tex


if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(arrow)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "sign_reversal_segment")
TABS <- file.path(BASE, "work", "v13", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)

# ---------- (0) load and recreate overlap-cell design (mirrors script 59) ----

dt <- as.data.table(readRDS("/tmp/p3_prepared.rds"))
dt <- dt[!is.na(lneg_price)]
dt[, log_ref_price := log1p(pmax(bid_ref_price_min, 0))]
dt[, oc_item_key := paste0(oc_code, "_", item_code)]
dt[, overlap_cell := interaction(item_group, year, convite, pbu_size_q, tender_value_q, drop = TRUE)]

# Direct-CADE flag at item level (mirrors 59)
cade_xm <- fread(file.path(BASE, "data/processed/cade_bec_crossmatch.csv"))
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
direct_codes <- unique(cade_xm$firm_code)

cade_co <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade_co[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
cob_codes <- unique(cade_co$firm_code)

ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
ftm[, oc_item_key := paste0(`numerodaoc`, "_", `códigoitem`)]
item_dc <- ftm[, .(any_direct = max(as.integer(firm_code %in% direct_codes)),
                   any_cobidder = max(as.integer(firm_code %in% cob_codes))),
               by = oc_item_key]
dt <- merge(dt, item_dc, by = "oc_item_key", all.x = TRUE)
dt[is.na(any_direct), any_direct := 0L]
dt[is.na(any_cobidder), any_cobidder := 0L]

dt[, has_treat := as.integer(any(losers == 1L)), by = overlap_cell]
dt[, has_ctrl  := as.integer(any(losers == 0L)), by = overlap_cell]
dt[, cell_overlap := as.integer(has_treat == 1L & has_ctrl == 1L)]

d_overlap <- dt[cell_overlap == 1L]
cell_sizes <- d_overlap[, .(n_treat = sum(losers == 1L), n_ctrl = sum(losers == 0L)),
                        by = overlap_cell]
d_overlap <- merge(d_overlap, cell_sizes, by = "overlap_cell")
d_overlap[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]

# ---------- (1) segment-level betas: 3 specs per segment -------------------

cat("\n[1/4] Segment-level betas (broad / overlap-unweighted / overlap-ATT) ...\n")

run_three <- function(d_full, d_olap, segment_label, segment_value) {
  res <- list()
  if (nrow(d_full) >= 1000L && length(unique(d_full$losers)) == 2L &&
      sum(d_full$losers == 1L) >= 30L) {
    fit <- tryCatch(feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                          data = d_full, cluster = ~item_f, lean = TRUE),
                    error = function(e) NULL)
    if (!is.null(fit)) {
      ct <- coeftable(fit)
      res[[length(res) + 1L]] <- data.table(segment = segment_label,
                                            level = as.character(segment_value),
                                            spec = "broad",
                                            coef = ct["losers", "Estimate"],
                                            se = ct["losers", "Std. Error"],
                                            pval = ct["losers", "Pr(>|t|)"],
                                            n = nrow(d_full),
                                            n_treat = sum(d_full$losers == 1L))
    }
  }
  if (nrow(d_olap) >= 1000L && length(unique(d_olap$losers)) == 2L &&
      sum(d_olap$losers == 1L) >= 30L) {
    fit_uw <- tryCatch(feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                             data = d_olap, cluster = ~item_f, lean = TRUE),
                       error = function(e) NULL)
    if (!is.null(fit_uw)) {
      ct <- coeftable(fit_uw)
      res[[length(res) + 1L]] <- data.table(segment = segment_label,
                                            level = as.character(segment_value),
                                            spec = "overlap_unweighted",
                                            coef = ct["losers", "Estimate"],
                                            se = ct["losers", "Std. Error"],
                                            pval = ct["losers", "Pr(>|t|)"],
                                            n = nrow(d_olap),
                                            n_treat = sum(d_olap$losers == 1L))
    }
    fit_at <- tryCatch(feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                             data = d_olap, weights = ~att_w,
                             cluster = ~item_f, lean = TRUE),
                       error = function(e) NULL)
    if (!is.null(fit_at)) {
      ct <- coeftable(fit_at)
      res[[length(res) + 1L]] <- data.table(segment = segment_label,
                                            level = as.character(segment_value),
                                            spec = "overlap_att",
                                            coef = ct["losers", "Estimate"],
                                            se = ct["losers", "Std. Error"],
                                            pval = ct["losers", "Pr(>|t|)"],
                                            n = nrow(d_olap),
                                            n_treat = sum(d_olap$losers == 1L))
    }
  }
  rbindlist(res, fill = TRUE)
}

segment_results <- list()

# (a) by item_group (collapse very small groups for stability)
ig_n <- dt[, .N, by = item_group][order(-N)]
big_groups <- ig_n[N >= 50000L, item_group]
for (g in big_groups) {
  d_full <- dt[item_group == g]
  d_olap <- d_overlap[item_group == g]
  if (nrow(d_olap) > 0L) {
    cs <- d_olap[, .(n_treat = sum(losers == 1L), n_ctrl = sum(losers == 0L)),
                 by = overlap_cell]
    d_olap_local <- merge(d_olap[, !c("n_treat", "n_ctrl", "att_w"), with = FALSE],
                          cs, by = "overlap_cell")
    d_olap_local[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]
  } else {
    d_olap_local <- d_olap[0]
  }
  segment_results[[length(segment_results) + 1L]] <- run_three(d_full, d_olap_local,
                                                               "item_group", g)
}

# (b) by PBU size quintile
for (q in sort(unique(na.omit(dt$pbu_size_q)))) {
  d_full <- dt[pbu_size_q == q]
  d_olap <- d_overlap[pbu_size_q == q]
  if (nrow(d_olap) > 0L) {
    cs <- d_olap[, .(n_treat = sum(losers == 1L), n_ctrl = sum(losers == 0L)),
                 by = overlap_cell]
    d_olap_local <- merge(d_olap[, !c("n_treat", "n_ctrl", "att_w"), with = FALSE],
                          cs, by = "overlap_cell")
    d_olap_local[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]
  } else {
    d_olap_local <- d_olap[0]
  }
  segment_results[[length(segment_results) + 1L]] <- run_three(d_full, d_olap_local,
                                                               "pbu_size_q", q)
}

# (c) by tender_value quintile
for (q in sort(unique(na.omit(dt$tender_value_q)))) {
  d_full <- dt[tender_value_q == q]
  d_olap <- d_overlap[tender_value_q == q]
  if (nrow(d_olap) > 0L) {
    cs <- d_olap[, .(n_treat = sum(losers == 1L), n_ctrl = sum(losers == 0L)),
                 by = overlap_cell]
    d_olap_local <- merge(d_olap[, !c("n_treat", "n_ctrl", "att_w"), with = FALSE],
                          cs, by = "overlap_cell")
    d_olap_local[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]
  } else {
    d_olap_local <- d_olap[0]
  }
  segment_results[[length(segment_results) + 1L]] <- run_three(d_full, d_olap_local,
                                                               "tender_value_q", q)
}

# (d) by modal x value (cross): convite/pregão x tender_value_q
for (m in c(0, 1)) {
  for (q in sort(unique(na.omit(dt$tender_value_q)))) {
    d_full <- dt[convite == m & tender_value_q == q]
    d_olap <- d_overlap[convite == m & tender_value_q == q]
    if (nrow(d_olap) > 0L) {
      cs <- d_olap[, .(n_treat = sum(losers == 1L), n_ctrl = sum(losers == 0L)),
                   by = overlap_cell]
      d_olap_local <- merge(d_olap[, !c("n_treat", "n_ctrl", "att_w"), with = FALSE],
                            cs, by = "overlap_cell")
      d_olap_local[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]
    } else {
      d_olap_local <- d_olap[0]
    }
    label <- sprintf("%s_Q%s", ifelse(m == 1, "convite", "pregao"), q)
    segment_results[[length(segment_results) + 1L]] <- run_three(d_full, d_olap_local,
                                                                 "modal_x_value", label)
  }
}

# (e) by year cohort: pre-2017 vs 2017+ (2017 is the inflection in CADE adjudication tempo)
for (period in c("2009-2016", "2017-2019")) {
  yrs <- if (period == "2009-2016") 2009:2016 else 2017:2019
  d_full <- dt[year %in% yrs]
  d_olap <- d_overlap[year %in% yrs]
  if (nrow(d_olap) > 0L) {
    cs <- d_olap[, .(n_treat = sum(losers == 1L), n_ctrl = sum(losers == 0L)),
                 by = overlap_cell]
    d_olap_local <- merge(d_olap[, !c("n_treat", "n_ctrl", "att_w"), with = FALSE],
                          cs, by = "overlap_cell")
    d_olap_local[, att_w := fifelse(losers == 1L, 1, n_treat / pmax(n_ctrl, 1))]
  } else {
    d_olap_local <- d_olap[0]
  }
  segment_results[[length(segment_results) + 1L]] <- run_three(d_full, d_olap_local,
                                                               "year_cohort", period)
}

seg_dt <- rbindlist(segment_results, fill = TRUE)
fwrite(seg_dt, file.path(OUT, "segment_betas.csv"))
cat("  Saved segment betas:", nrow(seg_dt), "rows.\n")

# ---------- (2) ATT-weight concentration -----------------------------------

cat("\n[2/4] ATT-weight concentration (Herfindahl + top-k share) ...\n")

cell_w <- d_overlap[, .(total_w = sum(att_w),
                        n_treat = sum(losers == 1L),
                        n_ctrl = sum(losers == 0L),
                        n_items = .N,
                        share_convite = mean(convite == 1L),
                        share_direct_cade = mean(any_direct == 1L),
                        share_cobidder = mean(any_cobidder == 1L),
                        mean_log_ref = mean(log_ref_price[is.finite(log_ref_price)]),
                        mean_n_firms = mean(n_firms, na.rm = TRUE),
                        mean_lneg_price = mean(lneg_price)),
                    by = overlap_cell]
cell_w[, w_share := total_w / sum(total_w)]
setorder(cell_w, -w_share)
cell_w[, cum_share := cumsum(w_share)]
cell_w[, rank := seq_len(.N)]
cell_w[, top_decile := as.integer(rank <= ceiling(0.10 * .N))]
cell_w[, top_pct := as.integer(rank <= ceiling(0.01 * .N))]

hhi <- cell_w[, sum(w_share^2)]

conc <- data.table(
  metric = c("hhi_weights", "top1pct_weight_share", "top10pct_weight_share",
             "n_cells", "n_treated_items_in_top_decile_cells",
             "share_treated_items_in_top_decile_cells"),
  value = c(hhi,
            cell_w[top_pct == 1L, sum(w_share)],
            cell_w[top_decile == 1L, sum(w_share)],
            nrow(cell_w),
            cell_w[top_decile == 1L, sum(n_treat)],
            cell_w[top_decile == 1L, sum(n_treat)] / cell_w[, sum(n_treat)])
)
fwrite(conc, file.path(OUT, "att_weight_concentration.csv"))
print(conc)

# ---------- (3) characterize the top-weight cells ---------------------------

cat("\n[3/4] Top-decile-weighted cells: characteristics ...\n")

top_summary <- cell_w[, .(
  n_cells = .N,
  total_weight = sum(total_w),
  weight_share = sum(w_share),
  n_items = sum(n_items),
  n_treat = sum(n_treat),
  n_ctrl = sum(n_ctrl),
  mean_n_treat_per_cell = mean(n_treat),
  mean_n_ctrl_per_cell = mean(n_ctrl),
  share_convite = sum(share_convite * n_items) / sum(n_items),
  share_direct_cade = sum(share_direct_cade * n_items) / sum(n_items),
  share_cobidder = sum(share_cobidder * n_items) / sum(n_items),
  mean_log_ref = sum(mean_log_ref * n_items, na.rm = TRUE) / sum(n_items),
  mean_n_firms = sum(mean_n_firms * n_items, na.rm = TRUE) / sum(n_items),
  mean_lneg_price = sum(mean_lneg_price * n_items, na.rm = TRUE) / sum(n_items)
), by = .(group = fifelse(top_decile == 1L, "top_decile", "rest"))]
fwrite(top_summary, file.path(OUT, "top_weight_cells.csv"))
print(top_summary)

# ---------- (3b) re-estimate beta after trimming the most extreme weights --

cat("\n[3b/4] Trimmed ATT betas (drop top-k% weights) ...\n")
trim_results <- list()
for (k in c(0.00, 0.01, 0.05, 0.10, 0.25, 0.50)) {
  if (k == 0) {
    sub <- d_overlap
    label <- "no trim"
  } else {
    cutoff <- quantile(cell_w$w_share, probs = 1 - k, na.rm = TRUE)
    drop_cells <- cell_w[w_share > cutoff, overlap_cell]
    sub <- d_overlap[!overlap_cell %in% drop_cells]
    label <- sprintf("drop top %.0f\\%%", 100 * k)  # \% literal in LaTeX
  }
  if (nrow(sub) >= 1000L && length(unique(sub$losers)) == 2L) {
    fit <- tryCatch(feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                          data = sub, weights = ~att_w,
                          cluster = ~item_f, lean = TRUE),
                    error = function(e) NULL)
    if (!is.null(fit)) {
      ct <- coeftable(fit)
      trim_results[[length(trim_results) + 1L]] <- data.table(
        trim_label = label, k = k,
        coef = ct["losers", "Estimate"],
        se = ct["losers", "Std. Error"],
        pval = ct["losers", "Pr(>|t|)"],
        n = nrow(sub),
        n_treat = sum(sub$losers == 1L)
      )
    }
  }
}
trim_dt <- rbindlist(trim_results, fill = TRUE)
fwrite(trim_dt, file.path(OUT, "att_trim_sensitivity.csv"))
print(trim_dt)

# ---------- (4) figure + table ---------------------------------------------

cat("\n[4/4] Figure + LaTeX table ...\n")

# Figure: dot plot of broad vs ATT betas across segments (item-group + value-quintile)
fig_dt <- seg_dt[segment %in% c("item_group", "tender_value_q", "year_cohort", "modal_x_value")]
fig_dt[, label := sprintf("%s = %s", segment, level)]
fig_dt[, spec := factor(spec, levels = c("broad", "overlap_unweighted", "overlap_att"),
                        labels = c("Broad", "Overlap unweighted", "Overlap ATT-wt"))]

p <- ggplot(fig_dt, aes(x = coef, y = label, colour = spec, shape = spec)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_point(size = 2.4, position = position_dodge(width = 0.4)) +
  geom_errorbarh(aes(xmin = coef - 1.96 * se, xmax = coef + 1.96 * se),
                 height = 0, position = position_dodge(width = 0.4),
                 alpha = 0.5) +
  facet_grid(rows = vars(segment), scales = "free_y", space = "free_y",
             switch = "y") +
  scale_colour_manual(values = c("Broad" = "#1f77b4",
                                  "Overlap unweighted" = "#2ca02c",
                                  "Overlap ATT-wt" = "#d62728")) +
  labs(x = expression(widehat(beta)~" (log negotiated price)"),
       y = NULL,
       colour = NULL, shape = NULL,
       title = NULL) +
  theme_bw(base_size = 9) +
  theme(legend.position = "bottom",
        strip.placement = "outside",
        strip.background = element_rect(fill = "grey90", colour = NA),
        panel.grid.minor = element_blank())
ggsave(file.path(OUT, "fig_segment_betas.pdf"), p, width = 7.0, height = 5.6)
cat("  Saved figure.\n")

# LaTeX table: most informative segments only
fmt_p <- function(p) ifelse(is.na(p), "--", ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))
fmt_b <- function(b) ifelse(is.na(b), "--", sprintf("%+.3f", b))
fmt_n <- function(n) format(round(n), big.mark = "{,}")

# Pick: top 3 item groups by N + 5 PBU quintiles + 5 tender_value quintiles + 2 year cohorts
top_ig <- ig_n[1:3, item_group]
tab_dt <- rbind(
  seg_dt[segment == "item_group" & level %in% as.character(top_ig)],
  seg_dt[segment == "tender_value_q"],
  seg_dt[segment == "year_cohort"]
)
setorder(tab_dt, segment, level, spec)

# Pivot wide: rows are (segment, level), cols are spec
wide <- dcast(tab_dt, segment + level ~ spec,
              value.var = c("coef", "se", "pval", "n"))

tex <- c(
  "% Subprompt 2: segment-level sign-reversal decomposition (script 61)",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Where the Sign Reversal Lives: Segment-Level $\\widehat\\beta$ Estimates}",
  "\\label{tab:sign_reversal_segment}",
  "\\begin{threeparttable}",
  "\\footnotesize",
  "\\begin{tabular}{llrrr c}",
  "\\toprule",
  "Segment & Level & Broad $\\widehat\\beta$ & Overlap unwt.\\ $\\widehat\\beta$ & Overlap ATT $\\widehat\\beta^{ov}$ & $N$ (broad) \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(wide))) {
  rr <- wide[i]
  seg_label <- switch(rr$segment,
                      item_group = "Item group",
                      tender_value_q = "Tender-value Q",
                      year_cohort = "Year cohort",
                      pbu_size_q = "PBU size Q",
                      modal_x_value = "Modal $\\times$ Value",
                      rr$segment)
  tex <- c(tex,
           sprintf("%s & %s & $%s$ & $%s$ & $%s$ & $%s$ \\\\",
                   seg_label,
                   rr$level,
                   fmt_b(rr$coef_broad),
                   fmt_b(rr$coef_overlap_unweighted),
                   fmt_b(rr$coef_overlap_att),
                   ifelse(is.na(rr$n_broad), "--", fmt_n(rr$n_broad))))
}
tex <- c(tex,
  "\\midrule",
  "\\multicolumn{6}{l}{\\textit{Panel B. ATT-weight concentration and trim sensitivity.}} \\\\",
  sprintf("HHI of cell weights & --- & --- & --- & $%.4f$ & $%s$ cells \\\\",
          conc[metric == "hhi_weights", value],
          fmt_n(conc[metric == "n_cells", value])),
  sprintf("Top 1\\%% cells weight share & --- & --- & --- & $%.3f$ & --- \\\\",
          conc[metric == "top1pct_weight_share", value]),
  sprintf("Top 10\\%% cells weight share & --- & --- & --- & $%.3f$ & --- \\\\",
          conc[metric == "top10pct_weight_share", value])
)

if (nrow(trim_dt) > 0L) {
  tex <- c(tex, "\\midrule",
           "\\multicolumn{6}{l}{\\textit{Panel C. Overlap ATT $\\widehat\\beta^{ov}$ after trimming most heavily weighted cells.}} \\\\")
  for (i in seq_len(nrow(trim_dt))) {
    rr <- trim_dt[i]
    tex <- c(tex,
             sprintf("%s & --- & --- & --- & $%s$ & $%s$ ($N_{\\text{trt}}=%s$) \\\\",
                     rr$trim_label,
                     fmt_b(rr$coef),
                     fmt_n(rr$n),
                     fmt_n(rr$n_treat)))
  }
}

tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  "\\item \\textit{Notes:} Panel A re-estimates the headline regression of Panel A of Table~\\ref{tab:sign_reversal_decomp} within segments. ``Broad'' uses all items; ``Overlap unwt.'' restricts to overlap cells without ATT weights; ``Overlap ATT'' adds the cell-size-based ATT weights that produce $\\widehat\\beta^{ov}$ in Table~\\ref{tab:sign_reversal_decomp}. Panel B reports the Herfindahl of cell-level ATT weights and the share of total weight concentrated in the top 1\\,\\% / 10\\,\\% of cells. Panel C re-estimates $\\widehat\\beta^{ov}$ after dropping the most heavily weighted cells; if the negative reversal is mechanically driven by a small fraction of cells with thin untreated counterfactuals, $\\widehat\\beta^{ov}$ should attenuate sharply as we trim.",
  "\\item \\textit{Source:} \\texttt{scripts/61\\_sign\\_reversal\\_segment\\_decomp.R}.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, file.path(TABS, "tab_sign_reversal_segment.tex"))
cat("  Wrote LaTeX table: tab_sign_reversal_segment.tex.\n")

cat("   ", file.path(OUT, "segment_betas.csv"), "\n")
cat("   ", file.path(OUT, "att_weight_concentration.csv"), "\n")
cat("   ", file.path(OUT, "top_weight_cells.csv"), "\n")
cat("   ", file.path(OUT, "att_trim_sensitivity.csv"), "\n")
cat("   ", file.path(OUT, "fig_segment_betas.pdf"), "\n")
cat("   ", file.path(TABS, "tab_sign_reversal_segment.tex"), "\n")
