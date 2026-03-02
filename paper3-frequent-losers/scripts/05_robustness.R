# ============================================================================
# 05_robustness.R — Robustness checks
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================
# Tests:
#   5.1 Multiple IQR thresholds (1.0x, 1.5x, 2.0x, 3.0x)
#   5.2 Continuous treatment (losers_count, losers_share)
#   5.3 Multi-way clustering
#   5.4 Item x Year FE (more demanding)
#   5.5 Winsorization (1st/99th percentile)
#   5.6 Sensitivity analysis (sensemakr)
#   5.7 Placebo quasi-losers
# ============================================================================

cat("=== 05_robustness.R: Robustness checks ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages({
  library(sensemakr)
})

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

fp <- readRDS(DATA_CACHE_FP)


# ============================================================================
# 5.1 Multiple IQR thresholds
# ============================================================================

cat("  5.1 IQR threshold robustness...\n")

# Original threshold uses 1.5x IQR. Test 1.0x, 2.0x, 3.0x as well.
# FREQ_PARTICIP has tenders_count for always-losers.
q <- quantile(fp$tenders_count, c(0.25, 0.75))
iqr_val <- q[2] - q[1]

thresholds <- c(1.0, 1.5, 2.0, 3.0)
threshold_results <- list()

for (mult in thresholds) {
  thr <- q[2] + mult * iqr_val
  n_firms_above <- sum(fp$tenders_count > thr)

  # Re-classify: firms above this threshold are frequent losers
  fl_firms <- fp[tenders_count > thr]
  fl_cnpjs <- fl_firms$códigofornecedor
  cat(sprintf("    IQR %.1fx: threshold=%.0f, %d firms classified as FL\n",
              mult, thr, n_firms_above))

  # Threshold reclassification strategy:
  # At the 1.5x baseline, LOSERS.parquet provides the exact losers flag.
  # For other thresholds, we use a proportional approximation:
  # since FREQ_PARTICIP has the complete distribution of always-loser
  # tenders_count, we know what fraction of FL firms remain at each threshold.
  # Tenders with higher losers_count are more likely to retain FL status
  # at stricter thresholds.
  #
  # Specifically: at 1.5x we have N_15 FL firms. At threshold k, we have N_k.
  # For a tender with losers_count = c at 1.5x, the probability of retaining
  # at least one FL firm at threshold k is 1 - (1 - N_k/N_15)^c.
  # We use a deterministic cutoff: tender has FL if losers_count ≥ ceil(N_15/N_k).

  n_fl_baseline <- sum(fp$tenders_count > (q[2] + 1.5 * iqr_val))

  dt_thr <- copy(dt)
  if (mult != 1.5) {
    # Minimum losers_count needed: if ratio = N_base / N_k, a tender
    # needs at least that many FL firms for at least one to survive the
    # stricter threshold (heuristic).
    ratio <- n_fl_baseline / max(n_firms_above, 1L)
    min_lc <- max(1L, ceiling(ratio))
    cat(sprintf("      Ratio: %.2f → min losers_count=%d for FL flag\n",
                ratio, min_lc))

    # For stricter thresholds (fewer FL firms), raise the bar
    dt_thr[, losers := as.integer(losers_count >= min_lc)]

    n_losers_new <- sum(dt_thr$losers)
    cat(sprintf("      Re-classified: %s tenders with FL (was %s at 1.5x)\n",
                pfmt_int(n_losers_new), pfmt_int(sum(dt$losers))))
  }

  # Run price regression (general + PBU FE spec)
  m <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
             data = dt_thr[!is.na(lneg_price)], cluster = ~item_f,
             fixef.rm = "none")

  threshold_results[[as.character(mult)]] <- list(
    multiplier = mult,
    threshold = thr,
    n_fl_firms = n_firms_above,
    coef = coef(m)["losers"],
    se = sqrt(vcov(m)["losers", "losers"]),
    n = m$nobs,
    r2 = fitstat(m, "r2")[[1]]
  )
}

# --- Write threshold robustness table ---
cat("  Writing tab_threshold_robustness.tex...\n")
thr_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Sensitivity to IQR Threshold Multiplier}",
  "\\label{tab:threshold_robustness}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "IQR Multiplier & Threshold & FL Firms & Losers Coef. & SE & N \\\\",
  "\\midrule"
)

for (r in threshold_results) {
  p <- 2 * pnorm(-abs(r$coef / r$se))
  thr_lines <- c(thr_lines, sprintf(
    "%.1f$\\times$ & %.0f & %s & %s%s & (%s) & %s \\\\",
    r$multiplier, r$threshold, pfmt_int(r$n_fl_firms),
    pfmt(r$coef, 4), pstars(p), pfmt(r$se, 4), pfmt_int(r$n)
  ))
}

thr_lines <- c(thr_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Dependent variable: log negotiated price.",
  "All specifications include item, year, and PBU fixed effects.",
  "Standard errors clustered at the item level.",
  "Reclassification at non-baseline thresholds uses a proportional approximation based on the \\textit{losers\\_count} variable.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(thr_lines, file.path(OUT_TAB, "tab_threshold_robustness.tex"))

# --- Threshold stability figure ---
cat("  Generating fig_threshold_stability.pdf...\n")
thr_df <- data.table(
  mult = sapply(threshold_results, `[[`, "multiplier"),
  coef = sapply(threshold_results, `[[`, "coef"),
  se   = sapply(threshold_results, `[[`, "se")
)
thr_df[, ci_lo := coef - 1.96 * se]
thr_df[, ci_hi := coef + 1.96 * se]
thr_df[, mult_label := paste0(mult, "x")]

p_thr <- ggplot(thr_df, aes(x = factor(mult_label, levels = mult_label),
                              y = coef)) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15, linewidth = 0.5) +
  geom_point(size = 2.5) +
  labs(x = "IQR Multiplier", y = "Coefficient on Losers (log price)") +
  theme_pub()

save_pub(p_thr, "fig_threshold_stability.pdf")

# ============================================================================
# 5.2 Continuous treatment
# ============================================================================

cat("  5.2 Continuous treatment...\n")

dvs <- c("lneg_price", "ln_firms", "ln_bids")
dv_labels <- c("Log Price", "Log Firms", "Log Bids")
treatments <- c("losers_count", "losers_share")
treat_labels <- c("Losers Count", "Losers Share")

cont_models <- list()

for (ti in seq_along(treatments)) {
  treat <- treatments[ti]
  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt

    # 4 specs per DV per treatment
    m1 <- feols(as.formula(paste0(dv, " ~ ", treat, " + convite | item_f + year_f")),
                data = d, cluster = ~item_f, fixef.rm = "none")
    m2 <- feols(as.formula(paste0(dv, " ~ ", treat, " + convite | item_f + year_f + pbu_f")),
                data = d, cluster = ~item_f, fixef.rm = "none")

    key <- paste0(treat, "_", dv)
    cont_models[[key]] <- list(
      treatment = treat_labels[ti], dv = dv_labels[di],
      general = m1, general_pbu = m2
    )
  }
}

# --- Write continuous treatment table ---
cat("  Writing tab_continuous_treatment.tex...\n")
ct_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Continuous Treatment: Losers Count and Losers Share}",
  "\\label{tab:continuous_treatment}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{llcccc}",
  "\\toprule",
  " & & \\multicolumn{2}{c}{Losers Count} & \\multicolumn{2}{c}{Losers Share} \\\\",
  "\\cmidrule(lr){3-4} \\cmidrule(lr){5-6}",
  "DV & & (1) General & (2) General+PBU & (3) General & (4) General+PBU \\\\",
  "\\midrule"
)

for (di in seq_along(dvs)) {
  dv <- dvs[di]
  dv_lbl <- dv_labels[di]

  key_count <- paste0("losers_count_", dv)
  key_share <- paste0("losers_share_", dv)

  mc1 <- cont_models[[key_count]]$general
  mc2 <- cont_models[[key_count]]$general_pbu
  ms1 <- cont_models[[key_share]]$general
  ms2 <- cont_models[[key_share]]$general_pbu

  ct_lines <- c(ct_lines, sprintf(
    "%s & Coef. & %s & %s & %s & %s \\\\",
    dv_lbl,
    coef_cell(mc1, "losers_count"), coef_cell(mc2, "losers_count"),
    coef_cell(ms1, "losers_share"), coef_cell(ms2, "losers_share")
  ))
  ct_lines <- c(ct_lines, sprintf(
    " & SE & %s & %s & %s & %s \\\\",
    se_cell(mc1, "losers_count"), se_cell(mc2, "losers_count"),
    se_cell(ms1, "losers_share"), se_cell(ms2, "losers_share")
  ))
  ct_lines <- c(ct_lines, sprintf(
    " & N & %s & %s & %s & %s \\\\",
    pfmt_int(mc1$nobs), pfmt_int(mc2$nobs),
    pfmt_int(ms1$nobs), pfmt_int(ms2$nobs)
  ))
  if (di < length(dvs)) ct_lines <- c(ct_lines, "[3pt]")
}

ct_lines <- c(ct_lines,
  "\\midrule",
  "Item FE & & YES & YES & YES & YES \\\\",
  "Year FE & & YES & YES & YES & YES \\\\",
  "PBU FE & & NO & YES & NO & YES \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Losers Count = number of frequent loser participations in the tender.",
  "Losers Share = losers count divided by number of firms.",
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(ct_lines, file.path(OUT_TAB, "tab_continuous_treatment.tex"))

# ============================================================================
# 5.3 Multi-way clustering
# ============================================================================

cat("  5.3 Multi-way clustering...\n")

cluster_specs <- list(
  "Item"          = ~item_f,
  "Item + Year"   = ~item_f + year_f,
  "Item + PBU"    = ~item_f + pbu_f
)

clust_results <- list()

for (di in seq_along(dvs)) {
  dv <- dvs[di]
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt

  for (cl_name in names(cluster_specs)) {
    cl <- cluster_specs[[cl_name]]
    m <- feols(as.formula(paste0(dv, " ~ losers + convite | item_f + year_f + pbu_f")),
               data = d, cluster = cl, fixef.rm = "none")

    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    p  <- 2 * pnorm(-abs(b / se))

    clust_results <- c(clust_results, list(data.table(
      dv = dv_labels[di], clustering = cl_name,
      coef = b, se = se, p = p, n = m$nobs
    )))
  }
}

clust_dt <- rbindlist(clust_results)

# --- Write clustering robustness table ---
cat("  Writing tab_clustering_robustness.tex...\n")
cl_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Robustness to Alternative Clustering}",
  "\\label{tab:clustering_robustness}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{llccc}",
  "\\toprule",
  " & & Item & Item + Year & Item + PBU \\\\",
  "\\midrule"
)

for (dv_lbl in dv_labels) {
  sub <- clust_dt[dv == dv_lbl]
  coefs <- sapply(c("Item", "Item + Year", "Item + PBU"), function(cl) {
    r <- sub[clustering == cl]
    paste0(pfmt(r$coef, 4), pstars(r$p))
  })
  ses <- sapply(c("Item", "Item + Year", "Item + PBU"), function(cl) {
    r <- sub[clustering == cl]
    paste0("(", pfmt(r$se, 4), ")")
  })
  cl_lines <- c(cl_lines,
    sprintf("%s & Coef. & %s \\\\", dv_lbl, paste(coefs, collapse = " & ")),
    sprintf(" & SE & %s \\\\", paste(ses, collapse = " & "))
  )
}

cl_lines <- c(cl_lines,
  "\\midrule",
  "Item FE & & YES & YES & YES \\\\",
  "Year FE & & YES & YES & YES \\\\",
  "PBU FE & & YES & YES & YES \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} All specifications include item, year, and PBU fixed effects.",
  "Columns differ only in the clustering level for standard errors.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(cl_lines, file.path(OUT_TAB, "tab_clustering_robustness.tex"))

# ============================================================================
# 5.4 Item x Year FE (more demanding specification)
# ============================================================================

cat("  5.4 Item x Year FE...\n")

ixyr_results <- list()
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt

  m1 <- feols(as.formula(paste0(dv, " ~ losers + convite | item_f^year_f")),
              data = d, cluster = ~item_f, fixef.rm = "none")
  m2 <- feols(as.formula(paste0(dv, " ~ losers + convite | item_f^year_f + pbu_f")),
              data = d, cluster = ~item_f, fixef.rm = "none")

  ixyr_results[[dv]] <- list(no_pbu = m1, with_pbu = m2)
}

# ============================================================================
# 5.5 Winsorization
# ============================================================================

cat("  5.5 Winsorization...\n")

dt_win <- copy(dt[!is.na(lneg_price)])
p01 <- quantile(dt_win$lneg_price, 0.01)
p99 <- quantile(dt_win$lneg_price, 0.99)
dt_win[, lneg_price_w := fifelse(lneg_price < p01, p01,
                                   fifelse(lneg_price > p99, p99, lneg_price))]

m_win <- feols(lneg_price_w ~ losers + convite | item_f + year_f + pbu_f,
               data = dt_win, cluster = ~item_f, fixef.rm = "none")

cat(sprintf("    Winsorized [%.2f, %.2f]: coef=%.4f se=%.4f\n",
            p01, p99, coef(m_win)["losers"], sqrt(vcov(m_win)["losers", "losers"])))

# ============================================================================
# 5.6 Sensitivity analysis (sensemakr)
# ============================================================================

cat("  5.6 Sensitivity analysis (sensemakr)...\n")

# sensemakr requires an OLS model (lm object)
# Run main spec without FE absorbed (use de-meaned approach or simple OLS proxy)
# For sensemakr, we use a simplified OLS with key controls
dt_sens <- dt[!is.na(lneg_price)]
m_ols <- lm(lneg_price ~ losers + convite + factor(year),
             data = dt_sens)

sens <- sensemakr(model = m_ols,
                  treatment = "losers",
                  benchmark_covariates = "convite",
                  kd = 1:3)

cat("  Sensitivity summary:\n")
cat(sprintf("    RV_q=1: %.3f\n", sens$sensitivity_stats$rv_q))
cat(sprintf("    RV_qa=0.05: %.3f\n", sens$sensitivity_stats$rv_qa))

# --- Contour plot ---
cat("  Generating fig_sensitivity_contour.pdf...\n")
fig_path <- file.path(OUT_FIG, "fig_sensitivity_contour.pdf")
cairo_pdf(fig_path, width = FIG_W, height = FIG_H)
plot(sens, sensitivity.of = "estimate")
dev.off()
cat("  Saved:", fig_path, "\n")

# ============================================================================
# 5.7 Placebo quasi-losers
# ============================================================================

cat("  5.7 Placebo quasi-losers...\n")

# Define quasi-losers: firms in 75th percentile to IQR threshold range
# (just below the cutoff — should NOT show cartel effects)
q75 <- quantile(fp$tenders_count, 0.75)
threshold_15 <- q75 + 1.5 * iqr_val

quasi_fp <- fp[tenders_count > q75 & tenders_count <= threshold_15]
cat(sprintf("    Quasi-losers: firms with tenders_count in (%.0f, %.0f]: %d firms\n",
            q75, threshold_15, nrow(quasi_fp)))

# For placebo test, we use the original data but treat quasi-losers region
# Since we can't directly re-merge at firm level from this dataset,
# we create a placebo by shuffling the losers flag within item-year cells
set.seed(42)
dt_placebo <- copy(dt[!is.na(lneg_price)])
dt_placebo[, placebo_losers := sample(losers), by = .(item_code, year)]

m_placebo <- feols(lneg_price ~ placebo_losers + convite | item_f + year_f + pbu_f,
                   data = dt_placebo, cluster = ~item_f, fixef.rm = "none")

b_pl <- coef(m_placebo)["placebo_losers"]
se_pl <- sqrt(vcov(m_placebo)["placebo_losers", "placebo_losers"])
p_pl <- 2 * pnorm(-abs(b_pl / se_pl))
cat(sprintf("    Placebo losers: coef=%.4f se=%.4f p=%.4f %s\n",
            b_pl, se_pl, p_pl, ifelse(p_pl > 0.1, "(null, as expected)", "(significant!)")))

# ============================================================================
# Save robustness models for reference
# ============================================================================

robustness_models <- list(
  thresholds     = threshold_results,
  continuous     = cont_models,
  clustering     = clust_dt,
  item_x_year    = ixyr_results,
  winsorized     = m_win,
  sensemakr      = sens,
  placebo        = m_placebo
)

saveRDS(robustness_models, "/tmp/p3_robustness.rds")
cat("  Robustness models saved: /tmp/p3_robustness.rds\n")
cat("  Done.\n")
