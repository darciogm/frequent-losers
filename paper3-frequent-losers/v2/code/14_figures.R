# ============================================================================
# 14_figures.R — All figures for Paper 3 v2
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# ~15 PDFs including: loss distribution, IQR threshold, C&S event study,
# Bacon decomposition, coefficient summary, regime test, cover bid spread,
# welfare CI, mechanism timing, year-by-year coefficients.
# ============================================================================

cat("=== 14_figures.R: Figure generation ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

suppressPackageStartupMessages(library(scales))

# ---- Load data ---------------------------------------------------------------
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1) setnames(fp, fp_col, "firm_id")

models <- readRDS(MODELS_CACHE_V2)
dt <- readRDS(DATA_CACHE_V2)

# ============================================================================
# Figure 1: Distribution of losses for always-losers
# ============================================================================

cat("  Figure 1: Losses distribution...\n")

p1 <- ggplot(fp, aes(x = tenders_count)) +
  geom_histogram(bins = 50, fill = "gray60", color = "gray30", linewidth = 0.3) +
  labs(x = "Number of Tender Participations", y = "Number of Firms") +
  scale_x_continuous(labels = comma_format()) +
  theme_pub()
save_pub(p1, "fig_01_losses_distribution.pdf")

# ============================================================================
# Figure 2: IQR identification with threshold line
# ============================================================================

cat("  Figure 2: IQR identification...\n")

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val

p2 <- ggplot(fp, aes(x = tenders_count)) +
  geom_histogram(bins = 50, fill = "gray60", color = "gray30", linewidth = 0.3) +
  geom_vline(xintercept = threshold, linetype = "dashed", color = "black", linewidth = 0.7) +
  annotate("text", x = threshold, y = Inf, vjust = 2, hjust = -0.1,
           label = paste0("Threshold = ", round(threshold)), size = 3) +
  labs(x = "Number of Tender Participations", y = "Number of Firms") +
  scale_x_continuous(labels = comma_format()) +
  theme_pub()
save_pub(p2, "fig_02_iqr_identification.pdf")

# ============================================================================
# Figure 3: Coefficient summary plot
# ============================================================================

cat("  Figure 3: Coefficient summary...\n")

outcome_labels <- c(prices = "Log Price", nfirms = "Log Firms",
                     nfirms_excl = "Log Firms (excl. FL)", nbids = "Log Bids")
spec_labels <- c(general = "(1) General", general_pbu = "(2) General+PBU",
                  pregao = "(3) Pregao", convite = "(4) Convite")

coef_data <- data.table()
for (outcome in c("prices", "nfirms", "nfirms_excl", "nbids")) {
  mlist <- models[[outcome]]
  for (spec in names(mlist)) {
    m <- mlist[[spec]]
    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    coef_data <- rbind(coef_data, data.table(
      outcome = outcome_labels[outcome], spec = spec_labels[spec],
      coef = b, se = se, ci_lo = b - 1.96 * se, ci_hi = b + 1.96 * se
    ))
  }
}

coef_data[, outcome := factor(outcome, levels = rev(unique(outcome)))]
coef_data[, spec := factor(spec, levels = rev(unique(spec)))]

p3 <- ggplot(coef_data, aes(x = coef, y = spec, shape = outcome)) +
  geom_vline(xintercept = 0, linetype = "dotted", color = "gray50", linewidth = 0.3) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.15, linewidth = 0.5,
                position = position_dodge(width = 0.5)) +
  geom_point(size = 2.5, position = position_dodge(width = 0.5)) +
  labs(x = "Coefficient on Cover Bidder", y = NULL) +
  theme_pub()
save_pub(p3, "fig_03_coef_summary.pdf")

# ============================================================================
# Figure 4: Cover bid spread distribution
# ============================================================================

cat("  Figure 4: Cover bid spread...\n")

spread_file <- file.path(DATA_V2, "fl_cover_bid_spread.parquet")
if (file.exists(spread_file)) {
  fl_spread <- as.data.table(read_parquet(spread_file))

  # Trim extreme values for visualization
  fl_spread_trim <- fl_spread[cover_bid_spread > -1 & cover_bid_spread < 5]

  p4 <- ggplot(fl_spread_trim, aes(x = cover_bid_spread)) +
    geom_histogram(bins = 100, fill = "gray60", color = "gray30", linewidth = 0.2) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "black", linewidth = 0.5) +
    labs(x = "Cover Bid Spread: (FL bid - Winner) / |Winner|",
         y = "Number of FL Bids") +
    scale_x_continuous(labels = percent_format(accuracy = 1)) +
    theme_pub()
  save_pub(p4, "fig_04_cover_bid_spread.pdf")
} else {
  cat("  Skipped: fl_cover_bid_spread.parquet not found\n")
}

# ============================================================================
# Figure 5: Regime test boxplot
# ============================================================================

cat("  Figure 5: Regime test boxplot...\n")

if ("dispersion_fl" %in% names(dt) || "log_disp_fl" %in% names(dt)) {
  d_regime <- dt[losers == 1 & !is.na(log_bid_sd)]

  if ("dispersion_fl" %in% names(dt) && "dispersion_nonfl" %in% names(dt)) {
    d_fl <- dt[!is.na(dispersion_fl), .(dispersion = dispersion_fl, type = "FL Bids")]
    d_nfl <- dt[!is.na(dispersion_nonfl), .(dispersion = dispersion_nonfl, type = "Non-FL Bids")]
    d_box <- rbind(d_fl, d_nfl)
    d_box <- d_box[dispersion < quantile(dispersion, 0.99, na.rm = TRUE)]

    p5 <- ggplot(d_box, aes(x = type, y = dispersion)) +
      geom_boxplot(fill = "gray80", outlier.size = 0.5, outlier.alpha = 0.3) +
      labs(x = NULL, y = "Bid Dispersion (IQR/Median)") +
      theme_pub()
    save_pub(p5, "fig_05_regime_boxplot.pdf")
  }
} else {
  cat("  Skipped: dispersion columns not available\n")
}

# ============================================================================
# Figure 6: C&S Event Study
# ============================================================================

cat("  Figure 6: C&S event study...\n")

did_file <- "/tmp/p3v2_did.rds"
if (file.exists(did_file)) {
  did <- readRDS(did_file)

  # Plot TWFE event study coefficients
  if (length(did$twfe_coefs) > 0) {
    es_all <- rbindlist(did$twfe_coefs)

    p6 <- ggplot(es_all, aes(x = rel_year, y = coef)) +
      geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
      geom_vline(xintercept = -0.5, linetype = "dashed", color = "gray70") +
      geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2, linewidth = 0.5) +
      geom_point(size = 2) +
      facet_wrap(~dv, scales = "free_y") +
      scale_x_continuous(breaks = -5:5) +
      labs(x = "Years Relative to First Cover Bidder Entry",
           y = "Coefficient") +
      theme_pub()
    save_pub(p6, "fig_06_event_study.pdf")
  }

  # C&S event study plot (if available)
  for (dv in names(did$callaway_santanna)) {
    cs <- did$callaway_santanna[[dv]]
    if (!is.null(cs$event_study)) {
      es <- cs$event_study
      es_dt <- data.table(
        egt = es$egt,
        att = es$att.egt,
        se = es$se.egt,
        ci_lo = es$att.egt - 1.96 * es$se.egt,
        ci_hi = es$att.egt + 1.96 * es$se.egt
      )

      p_cs <- ggplot(es_dt, aes(x = egt, y = att)) +
        geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
        geom_vline(xintercept = -0.5, linetype = "dashed", color = "gray70") +
        geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2, linewidth = 0.5) +
        geom_point(size = 2) +
        labs(x = "Event Time", y = paste("ATT:", dv)) +
        theme_pub()
      save_pub(p_cs, paste0("fig_06_cs_event_study_", gsub("log_", "", dv), ".pdf"))
    }
  }
}

# ============================================================================
# Figure 7: Threshold stability
# ============================================================================

cat("  Figure 7: Threshold stability...\n")

rob_file <- "/tmp/p3v2_robustness.rds"
if (file.exists(rob_file)) {
  rob <- readRDS(rob_file)

  if (!is.null(rob$thresholds)) {
    thr_df <- data.table(
      mult = sapply(rob$thresholds, `[[`, "multiplier"),
      coef = sapply(rob$thresholds, `[[`, "coef"),
      se   = sapply(rob$thresholds, `[[`, "se")
    )
    thr_df[, ci_lo := coef - 1.96 * se]
    thr_df[, ci_hi := coef + 1.96 * se]
    thr_df[, mult_label := paste0(mult, "x")]

    p7 <- ggplot(thr_df, aes(x = factor(mult_label, levels = mult_label), y = coef)) +
      geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
      geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15, linewidth = 0.5) +
      geom_point(size = 2.5) +
      labs(x = "IQR Multiplier", y = "Coefficient on Cover Bidder (log price)") +
      theme_pub()
    save_pub(p7, "fig_07_threshold_stability.pdf")
  }
}

# ============================================================================
# Figure 8: Sensitivity contour (sensemakr)
# ============================================================================

cat("  Figure 8: Sensitivity contour...\n")

if (file.exists(rob_file)) {
  rob <- readRDS(rob_file)
  if (!is.null(rob$sensemakr)) {
    fig_path <- file.path(OUT_FIG, "fig_08_sensitivity_contour.pdf")
    cairo_pdf(fig_path, width = FIG_W, height = FIG_H)
    plot(rob$sensemakr, sensitivity.of = "estimate")
    dev.off()
    cat("  Saved:", fig_path, "\n")
  }
}

# ============================================================================
# Figure 9: Welfare CI
# ============================================================================

cat("  Figure 9: Welfare estimates...\n")

wf_file <- "/tmp/p3v2_welfare.rds"
if (file.exists(wf_file)) {
  wf <- readRDS(wf_file)

  wf_dt <- data.table(
    label = c("Point Estimate", "95% CI Lower", "95% CI Upper"),
    markup = c(wf$markup_pct, (exp(wf$ci[1]) - 1) * 100, (exp(wf$ci[2]) - 1) * 100)
  )

  # Simple bar chart
  p9 <- ggplot(data.table(x = "Cover Bidding Markup",
                            y = wf$markup_pct,
                            lo = (exp(wf$ci[1]) - 1) * 100,
                            hi = (exp(wf$ci[2]) - 1) * 100),
               aes(x = x, y = y)) +
    geom_col(fill = "gray60", width = 0.5) +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.5) +
    geom_hline(yintercept = c(15, 40), linetype = "dashed", color = "gray70") +
    annotate("text", x = 0.5, y = 15, label = "OECD lower", hjust = -0.1, size = 2.5) +
    annotate("text", x = 0.5, y = 40, label = "OECD upper", hjust = -0.1, size = 2.5) +
    labs(x = NULL, y = "Implied Markup (%)") +
    theme_pub()
  save_pub(p9, "fig_09_welfare_markup.pdf")
}

# ============================================================================
# Figure 10: Year-by-year coefficients
# ============================================================================

cat("  Figure 10: Year-by-year coefficients...\n")

year_models <- list()
for (di in seq_along(c("lneg_price", "ln_firms", "ln_bids"))) {
  dv <- c("lneg_price", "ln_firms", "ln_bids")[di]
  dv_lbl <- c("Log Price", "Log Firms", "Log Bids")[di]
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt

  m <- tryCatch(
    feols(as.formula(paste0(dv, " ~ i(year_f, losers) + convite | item_f + year_f")),
          data = d, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) NULL
  )

  if (!is.null(m)) {
    cf <- as.data.table(coeftable(m), keep.rownames = "term")
    setnames(cf, c("term", "coef", "se", "tval", "pval"))
    cf <- cf[grepl("losers", term)]
    cf[, yr := as.integer(sub("year_f::(\\d+):losers", "\\1", term))]
    cf[, dv := dv_lbl]
    cf[, ci_lo := coef - 1.96 * se]
    cf[, ci_hi := coef + 1.96 * se]
    year_models[[dv]] <- cf
  }
}

yr_all <- rbindlist(year_models)
if (nrow(yr_all) > 0) {
  p10 <- ggplot(yr_all, aes(x = yr, y = coef, shape = dv)) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.3, linewidth = 0.4,
                  position = position_dodge(width = 0.5)) +
    geom_point(size = 2, position = position_dodge(width = 0.5)) +
    scale_shape_manual(values = c("Log Price" = 16, "Log Firms" = 17, "Log Bids" = 15)) +
    labs(x = "Year", y = "Coefficient on Cover Bidder") +
    theme_pub()
  save_pub(p10, "fig_10_year_coefficients.pdf")
}

cat("  All figures generated.\n")
