# ============================================================================
# 04_figures.R — Event study plots (publication quality)
# ============================================================================

cat("=== 04_figures.R: Event study figures ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load models -----------------------------------------------------------
models_path <- "/tmp/p2_models.rds"
if (!file.exists(models_path)) stop("Run 02_analysis.R first")
models <- readRDS(models_path)

# ---- Helper: extract event study coefficients ------------------------------
extract_es_coefs <- function(model) {
  # fixest i() coefficients: semester_f::k:g65
  ct <- as.data.table(coeftable(model), keep.rownames = "term")
  setnames(ct, c("term", "estimate", "se", "tval", "pval"))

  # Filter to interaction terms
  ct <- ct[grepl("semester_f::", term)]

  # Extract semester number from term name
  ct[, semester := as.integer(gsub(".*semester_f::(\\d+):g65", "\\1", term))]

  # Add reference period (semester 4) with zero effect
  ref <- data.table(term = "ref", estimate = 0, se = 0, tval = 0, pval = 1, semester = 4L)
  ct <- rbind(ct, ref)
  setorder(ct, semester)

  # Compute 95% CI
  ct[, ci_lo := estimate - 1.96 * se]
  ct[, ci_hi := estimate + 1.96 * se]

  ct
}

# ---- Helper: plot event study ----------------------------------------------
plot_event_study <- function(model, ylab) {
  coefs <- extract_es_coefs(model)

  # x-axis: semester labels
  coefs[, x_label := factor(semester, levels = 1:6, labels = SEM_LABELS)]

  ggplot(coefs, aes(x = semester, y = estimate)) +
    # Treatment line (between semesters 3 and 4)
    geom_vline(xintercept = 3.5, linetype = "dashed", color = "red", linewidth = 0.5) +
    # Zero reference line
    geom_hline(yintercept = 0, linetype = "dotted", color = "gray50", linewidth = 0.3) +
    # CI bars
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                  width = 0.15, linewidth = 0.5, color = "black") +
    # Point estimates
    geom_point(size = 2.5, color = "black") +
    # Labels
    scale_x_continuous(breaks = 1:6, labels = SEM_LABELS) +
    labs(x = "Semester", y = ylab) +
    theme_pub() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))
}

# ---- Generate figures ------------------------------------------------------

cat("  Figure 1: Log prices event study...\n")
p1 <- plot_event_study(models$es_prices,
                       ylab = "Log Prices (coefficient)")
save_pub(p1, "fig_01_logprices_es.pdf")

cat("  Figure 2: Distance event study...\n")
p2 <- plot_event_study(models$es_distance,
                       ylab = "Distance in km (coefficient)")
save_pub(p2, "fig_02_distance_es.pdf")

cat("  Figure 3: Number of firms event study...\n")
p3 <- plot_event_study(models$es_numfirms,
                       ylab = "Log Number of Firms (coefficient)")
save_pub(p3, "fig_03_numfirms_es.pdf")

cat("  Figure 4: Number of valid bids event study...\n")
p4 <- plot_event_study(models$es_numbids,
                       ylab = "Log Number of Valid Bids (coefficient)")
save_pub(p4, "fig_04_numbids_es.pdf")

# ============================================================================
# NEW FIGURES — Raw Trends, Permutation, SME Share
# ============================================================================

# ---- Load data for raw trends ---------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

# ---- Helper: raw trends plot -----------------------------------------------
plot_raw_trends <- function(data, dv, ylab, completed = FALSE) {
  sub <- data[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
  if (completed) sub <- sub[oc_item_status == 1L]
  sub <- sub[!is.na(get(dv))]

  # Group label
  sub[, group_label := fifelse(g65 == 1, "Group 65", "Other groups")]

  # Monthly means with CI
  agg <- sub[, .(mean_y = mean(get(dv), na.rm = TRUE),
                  sd_y   = sd(get(dv), na.rm = TRUE),
                  n      = .N),
              by = .(data_oc_numb, group_label)]
  agg[, se := sd_y / sqrt(n)]
  agg[, ci_lo := mean_y - 1.96 * se]
  agg[, ci_hi := mean_y + 1.96 * se]

  ggplot(agg, aes(x = data_oc_numb, y = mean_y,
                   linetype = group_label, shape = group_label)) +
    geom_vline(xintercept = TREAT_DATE - 0.5, linetype = "dashed",
               color = "red", linewidth = 0.5) +
    geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi, group = group_label),
                alpha = 0.15, color = NA, fill = "gray50") +
    geom_line(linewidth = 0.6, color = "black") +
    geom_point(size = 1.2, color = "black") +
    scale_linetype_manual(values = c("Group 65" = "solid", "Other groups" = "dashed")) +
    scale_shape_manual(values = c("Group 65" = 16, "Other groups" = 1)) +
    labs(x = "Month (Stata monthly date)", y = ylab) +
    theme_pub() +
    theme(legend.position = "bottom")
}

# ---- Raw trends figures ----------------------------------------------------
cat("  Figure 5: Raw trends — log prices...\n")
p5 <- plot_raw_trends(dt, "lpreco_final", "Mean Log Price", completed = TRUE)
save_pub(p5, "fig_05_trends_prices.pdf")

cat("  Figure 6: Raw trends — log firms...\n")
p6 <- plot_raw_trends(dt, "lnum_firms", "Mean Log Number of Firms", completed = FALSE)
save_pub(p6, "fig_06_trends_firms.pdf")

cat("  Figure 7: Raw trends — log bids...\n")
p7 <- plot_raw_trends(dt, "lnum_bids", "Mean Log Number of Valid Bids", completed = FALSE)
save_pub(p7, "fig_07_trends_bids.pdf")

cat("  Figure 8: Raw trends — distance...\n")
p8 <- plot_raw_trends(dt, "dist1", "Mean Distance (km)", completed = TRUE)
save_pub(p8, "fig_08_trends_distance.pdf")

# ---- Permutation histogram -------------------------------------------------
rob_path <- "/tmp/p2_robustness.rds"
if (file.exists(rob_path)) {
  rob <- readRDS(rob_path)
  if (!is.null(rob$permutation)) {
    cat("  Figure 9: Permutation test histogram...\n")

    perm_data <- data.table(coef = rob$permutation$perm_coefs)
    obs_val   <- rob$permutation$observed_coef
    perm_pval <- rob$permutation$perm_pval

    p9 <- ggplot(perm_data, aes(x = coef)) +
      geom_histogram(bins = 40, fill = "gray70", color = "gray40", linewidth = 0.3) +
      geom_vline(xintercept = obs_val, linetype = "dashed", color = "black",
                 linewidth = 0.8) +
      annotate("text", x = obs_val, y = Inf, vjust = 2, hjust = -0.1,
               label = paste0("Observed = ", pfmt(obs_val, 4),
                              "\np-value = ", pfmt(perm_pval, 3)),
               size = 3) +
      labs(x = "Permuted coefficient (g65 x Pre on log prices)",
           y = "Frequency") +
      theme_pub()

    save_pub(p9, "fig_09_permutation.pdf")
  }
}

# ---- SME share trends ------------------------------------------------------
if ("sme_share_ph1" %in% names(dt)) {
  cat("  Figure 10: SME participation share...\n")

  sub <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
             !is.na(sme_share_ph1)]
  sub[, group_label := fifelse(g65 == 1, "Group 65", "Other groups")]

  agg <- sub[, .(mean_share = mean(sme_share_ph1, na.rm = TRUE),
                  se = sd(sme_share_ph1, na.rm = TRUE) / sqrt(.N)),
              by = .(data_oc_numb, group_label)]
  agg[, ci_lo := mean_share - 1.96 * se]
  agg[, ci_hi := mean_share + 1.96 * se]

  p10 <- ggplot(agg, aes(x = data_oc_numb, y = mean_share,
                          linetype = group_label, shape = group_label)) +
    geom_vline(xintercept = TREAT_DATE - 0.5, linetype = "dashed",
               color = "red", linewidth = 0.5) +
    geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi, group = group_label),
                alpha = 0.15, color = NA, fill = "gray50") +
    geom_line(linewidth = 0.6, color = "black") +
    geom_point(size = 1.2, color = "black") +
    scale_linetype_manual(values = c("Group 65" = "solid", "Other groups" = "dashed")) +
    scale_shape_manual(values = c("Group 65" = 16, "Other groups" = 1)) +
    scale_y_continuous(labels = scales::percent_format()) +
    labs(x = "Month (Stata monthly date)", y = "SME Share Among Firms (Phase 1)") +
    theme_pub() +
    theme(legend.position = "bottom")

  save_pub(p10, "fig_10_sme_share.pdf")
}

cat("  All figures generated.\n")
