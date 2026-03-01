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

cat("  All figures generated.\n")
