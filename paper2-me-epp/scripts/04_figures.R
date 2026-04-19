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

# ---- SME winner share trends ------------------------------------------------
# Note: sme_share_ph1 (firm-type counts in phase 1) has all NAs due to a
# data import issue. We use sme_winner (binary: was the winner an SME?) as
# a proxy, computed on completed items only.
if ("sme_winner" %in% names(dt)) {
  cat("  Figure 10: SME winner share...\n")

  sub <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
             oc_item_status == 1L & !is.na(sme_winner)]
  sub[, group_label := fifelse(g65 == 1, "Group 65", "Other groups")]

  agg <- sub[, .(mean_share = mean(sme_winner, na.rm = TRUE),
                  se = sd(sme_winner, na.rm = TRUE) / sqrt(.N)),
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
    labs(x = "Month (Stata monthly date)", y = "SME Winner Share (Completed Items)") +
    theme_pub() +
    theme(legend.position = "bottom")

  save_pub(p10, "fig_10_sme_share.pdf")
}

# ============================================================================
# ADVANCED METHODS FIGURES
# ============================================================================

adv_path <- "/tmp/p2_advanced.rds"
if (file.exists(adv_path)) {
  adv <- readRDS(adv_path)
  cat("  Loaded advanced models\n")

  # ---- Figure 11: Parallel trends sensitivity (2x2 panel) --------------------
  if (!is.null(adv$honestdid)) {
    cat("  Figure 11: Parallel trends sensitivity analysis...\n")

    suppressPackageStartupMessages(library(gridExtra))

    outcome_labels <- c(
      prices   = "Log Prices",
      distance = "Distance (km)",
      numfirms = "Log Number of Firms",
      numbids  = "Log Number of Valid Bids"
    )

    hd_plots <- list()
    for (nm in names(adv$honestdid)) {
      hd <- adv$honestdid[[nm]]
      if (is.null(hd$result)) {
        hd_plots[[nm]] <- ggplot() +
          annotate("text", x = 0.5, y = 0.5, label = "Sensitivity failed") +
          labs(title = outcome_labels[nm]) +
          theme_void()
        next
      }

      plot_df <- hd$result  # data.frame with Mbar, lb, ub

      # Expand y-axis by 8% on both ends so CI lines don't abut the panel edges
      # (fixes the "title overlaps CI" complaint).
      y_range <- range(c(plot_df$lb, plot_df$ub), na.rm = TRUE)
      y_pad <- 0.08 * diff(y_range)

      p <- ggplot(plot_df, aes(x = Mbar)) +
        geom_ribbon(aes(ymin = lb, ymax = ub), alpha = 0.2, fill = "gray50") +
        geom_line(aes(y = lb), linetype = "dashed", color = "black") +
        geom_line(aes(y = ub), linetype = "dashed", color = "black") +
        geom_hline(yintercept = 0, linetype = "dotted", color = "red", linewidth = 0.3) +
        scale_y_continuous(limits = c(y_range[1] - y_pad, y_range[2] + y_pad)) +
        labs(x = expression(bar(M)), y = "Robust CI",
             title = outcome_labels[nm]) +
        theme_pub(base_size = 8) +
        theme(plot.title = element_text(face = "bold", size = 9,
                                        margin = margin(b = 8)),
              plot.title.position = "plot",
              plot.margin = margin(t = 10, r = 8, b = 4, l = 4))

      hd_plots[[nm]] <- p
    }

    if (length(hd_plots) > 0) {
      p11 <- arrangeGrob(grobs = hd_plots, ncol = 2)
      filepath <- file.path(OUT_FIG, "fig_11_honestdid.pdf")
      ggsave(filepath, p11, width = 6.5, height = 6, device = cairo_pdf)
      cat("  Saved:", filepath, "\n")
    }
  }

  # ---- Figure 12: Causal forest variable importance ---------------------------
  if (!is.null(adv$causal_forest)) {
    cat("  Figure 12: Causal forest variable importance...\n")

    vi <- adv$causal_forest$varimp
    vi$variable <- factor(vi$variable, levels = vi$variable[order(vi$importance)])

    p12 <- ggplot(vi, aes(x = importance, y = variable)) +
      geom_col(fill = "gray50", width = 0.6) +
      labs(x = "Variable Importance", y = NULL) +
      theme_pub() +
      theme(legend.position = "none")

    save_pub(p12, "fig_12_cforest_varimp.pdf")
  }

  # ---- Figure 13: Causal forest GATE by quartile -----------------------------
  if (!is.null(adv$causal_forest)) {
    cat("  Figure 13: Causal forest GATE by quartile...\n")

    gate <- adv$causal_forest$gate
    gate$ci_lo <- gate$estimate - 1.96 * gate$se
    gate$ci_hi <- gate$estimate + 1.96 * gate$se

    ate_val <- adv$causal_forest$ate[1]

    p13 <- ggplot(gate, aes(x = quartile, y = estimate)) +
      geom_hline(yintercept = ate_val, linetype = "dashed", color = "gray40",
                 linewidth = 0.5) +
      geom_hline(yintercept = 0, linetype = "dotted", color = "red", linewidth = 0.3) +
      geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15,
                    linewidth = 0.5, color = "black") +
      geom_point(size = 3, color = "black") +
      annotate("text", x = 4.3, y = ate_val,
               label = paste0("ATE = ", pfmt(ate_val, 3)),
               size = 2.5, hjust = 0) +
      labs(x = "CATE Quartile", y = "Group Average Treatment Effect") +
      theme_pub()

    save_pub(p13, "fig_13_cforest_gate.pdf")
  }

  # ---- Figure 14: Quantile DiD -----------------------------------------------
  if (!is.null(adv$quantile_did)) {
    cat("  Figure 14: Quantile DiD...\n")

    qd <- adv$quantile_did
    qc <- qd$quantile_coefs

    # OLS band
    ols_lo <- qd$ols_coef - 1.96 * qd$ols_se
    ols_hi <- qd$ols_coef + 1.96 * qd$ols_se

    p14 <- ggplot(qc, aes(x = tau, y = estimate)) +
      # OLS reference band
      annotate("rect", xmin = min(qc$tau) - 0.05, xmax = max(qc$tau) + 0.05,
               ymin = ols_lo, ymax = ols_hi,
               fill = "gray85", alpha = 0.5) +
      geom_hline(yintercept = qd$ols_coef, linetype = "dashed",
                 color = "gray40", linewidth = 0.5) +
      geom_hline(yintercept = 0, linetype = "dotted", color = "red", linewidth = 0.3) +
      geom_line(linewidth = 0.6, color = "black") +
      geom_point(size = 2.5, color = "black")

    # Add CIs if available
    if (any(!is.na(qc$ci_lo))) {
      p14 <- p14 +
        geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.02,
                      linewidth = 0.5, color = "black")
    }

    p14 <- p14 +
      scale_x_continuous(breaks = qc$tau) +
      labs(x = expression(paste("Quantile (", tau, ")")),
           y = expression(paste("Treatment effect on log price (", g65 %*% Pre, ")"))) +
      annotate("text", x = max(qc$tau) + 0.02, y = qd$ols_coef,
               label = "OLS", size = 2.5, hjust = 0) +
      theme_pub()

    save_pub(p14, "fig_14_quantile_did.pdf")
  }

  # ---- Figure 15: Gelbach mediation ------------------------------------------
  if (!is.null(adv$gelbach)) {
    cat("  Figure 15: Gelbach decomposition...\n")

    gel <- adv$gelbach
    decomp <- gel$decomposition

    # Build plot data: channels + direct effect
    plot_df <- data.frame(
      channel  = c(decomp$label, "Direct effect"),
      value    = c(decomp$delta, gel$direct_effect),
      se       = c(decomp$delta_se, gel$se_full),
      stringsAsFactors = FALSE
    )
    plot_df$channel <- factor(plot_df$channel,
                              levels = rev(plot_df$channel))
    plot_df$ci_lo <- plot_df$value - 1.96 * plot_df$se
    plot_df$ci_hi <- plot_df$value + 1.96 * plot_df$se
    plot_df$type <- c(rep("Channel", nrow(decomp)), "Direct")

    p15 <- ggplot(plot_df, aes(x = value, y = channel)) +
      geom_vline(xintercept = 0, linetype = "dotted", color = "red", linewidth = 0.3) +
      geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.2,
                    linewidth = 0.5, color = "black", orientation = "y") +
      geom_point(aes(shape = type), size = 3, color = "black") +
      scale_shape_manual(values = c("Channel" = 16, "Direct" = 17)) +
      labs(x = "Contribution to price effect", y = NULL) +
      theme_pub() +
      theme(legend.position = "none")

    save_pub(p15, "fig_15_mediation.pdf")
  }
}

cat("  All figures generated.\n")
