# ============================================================================
# 13_figures.R — All figures for Paper 3 v4
# ============================================================================
# Figures already written by individual scripts (04, 06, 08, 16) are NOT
# duplicated here. This script generates: loss distribution, IQR threshold,
# coefficient summary (including IV + network), cover bid spread, regime
# boxplot, event study, threshold stability, sensitivity contour, welfare,
# year-by-year coefficients.
#
# Individual scripts already produce:
#   04 → fig_first_stage_binscatter.pdf
#   06 → fig_bajari_bootstrap.pdf
#   08 → fig_did_honest.pdf
#   16 → fig_regime_densities.pdf, fig_network_hhi.pdf
# ============================================================================

cat("=== 13_figures.R: Figure generation ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

suppressPackageStartupMessages(library(scales))

# ---- Load data ---------------------------------------------------------------
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

models <- readRDS(MODELS_CACHE_V4)
dt <- readRDS(DATA_CACHE_V4)

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
# Figure 3: Coefficient summary plot (OLS + IV + Network)
# ============================================================================

cat("  Figure 3: Coefficient summary...\n")

outcome_labels <- c(prices = "Log Price", nfirms = "Log Firms",
                     nfirms_excl = "Log Firms (excl. FL)", nbids = "Log Bids")
spec_labels <- c(general = "(1) General", general_pbu = "(2) General+PBU",
                  pregao = "(3) Pregao", convite = "(4) Convite")

coef_data <- data.table()
for (outcome in c("prices", "nfirms", "nfirms_excl", "nbids")) {
  mlist <- models[[outcome]]
  if (is.null(mlist)) next
  for (spec in names(mlist)) {
    m <- mlist[[spec]]
    if (is.null(m) || !("losers" %in% names(coef(m)))) next
    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    coef_data <- rbind(coef_data, data.table(
      outcome = outcome_labels[outcome], spec = spec_labels[spec],
      method = "OLS",
      coef = b, se = se, ci_lo = b - 1.96 * se, ci_hi = b + 1.96 * se
    ))
  }
}

# Add IV estimates if available
if (file.exists(IV_MODELS_CACHE_V4)) {
  iv_mods <- readRDS(IV_MODELS_CACHE_V4)
  iv_dv_map <- c(lneg_price = "Log Price", ln_firms = "Log Firms",
                  ln_bids = "Log Bids", ln_firms_excl = "Log Firms (excl. FL)")

  if (!is.null(iv_mods$iv_models)) {
    for (dv in names(iv_mods$iv_models)) {
      lbl <- iv_dv_map[dv]
      if (is.na(lbl)) next
      m <- iv_mods$iv_models[[dv]]$iv_pbu
      if (!is.null(m) && "fit_losers" %in% names(coef(m))) {
        b  <- coef(m)["fit_losers"]
        se <- sqrt(vcov(m)["fit_losers", "fit_losers"])
        coef_data <- rbind(coef_data, data.table(
          outcome = lbl, spec = "(2) General+PBU",
          method = "IV",
          coef = b, se = se, ci_lo = b - 1.96 * se, ci_hi = b + 1.96 * se
        ))
      }
    }
  }
}

coef_data[, outcome := factor(outcome, levels = rev(unique(outcome)))]
coef_data[, spec := factor(spec, levels = rev(unique(spec)))]

p3 <- ggplot(coef_data, aes(x = coef, y = spec, shape = outcome, color = method)) +
  geom_vline(xintercept = 0, linetype = "dotted", color = "gray50", linewidth = 0.3) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.15, linewidth = 0.5,
                position = position_dodge(width = 0.6)) +
  geom_point(size = 2.5, position = position_dodge(width = 0.6)) +
  scale_color_manual(values = c("OLS" = "gray30", "IV" = "firebrick")) +
  labs(x = "Coefficient on FL Presence", y = NULL, color = "Method") +
  theme_pub()
save_pub(p3, "fig_03_coef_summary.pdf")

# ============================================================================
# Figure 4: Cover bid spread distribution
# ============================================================================

cat("  Figure 4: Cover bid spread...\n")

spread_file <- file.path(DATA_V4, "fl_cover_bid_spread.parquet")
if (!file.exists(spread_file))
  spread_file <- file.path(DATA_V1, "fl_cover_bid_spread.parquet")

if (file.exists(spread_file)) {
  fl_spread <- as.data.table(read_parquet(spread_file))
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

if ("dispersion_fl" %in% names(dt) && "dispersion_nonfl" %in% names(dt)) {
  d_fl  <- dt[!is.na(dispersion_fl), .(dispersion = dispersion_fl, type = "FL Bids")]
  d_nfl <- dt[!is.na(dispersion_nonfl), .(dispersion = dispersion_nonfl, type = "Non-FL Bids")]
  d_box <- rbind(d_fl, d_nfl)
  d_box <- d_box[dispersion < quantile(dispersion, 0.99, na.rm = TRUE)]

  p5 <- ggplot(d_box, aes(x = type, y = dispersion)) +
    geom_boxplot(fill = "gray80", outlier.size = 0.5, outlier.alpha = 0.3) +
    labs(x = NULL, y = "Bid Dispersion (IQR/Median)") +
    theme_pub()
  save_pub(p5, "fig_05_regime_boxplot.pdf")
} else if ("log_bid_sd" %in% names(dt)) {
  d_box <- dt[!is.na(log_bid_sd), .(dispersion = log_bid_sd,
                                      type = fifelse(losers == 1, "FL-present", "FL-absent"))]
  d_box <- d_box[dispersion < quantile(dispersion, 0.99, na.rm = TRUE)]

  p5 <- ggplot(d_box, aes(x = type, y = dispersion)) +
    geom_boxplot(fill = "gray80", outlier.size = 0.5, outlier.alpha = 0.3) +
    labs(x = NULL, y = "Log Bid Standard Deviation") +
    theme_pub()
  save_pub(p5, "fig_05_regime_boxplot.pdf")
} else {
  cat("  Skipped: dispersion columns not available\n")
}

# ============================================================================
# Figure 6: Event study (TWFE + C&S)
# ============================================================================

cat("  Figure 6: Event study...\n")

if (file.exists(DID_CACHE_V4)) {
  did <- readRDS(DID_CACHE_V4)

  # TWFE event study coefficients
  if (!is.null(did$twfe_coefs) && length(did$twfe_coefs) > 0) {
    es_all <- rbindlist(did$twfe_coefs)

    p6 <- ggplot(es_all, aes(x = rel_year, y = coef)) +
      geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
      geom_vline(xintercept = -0.5, linetype = "dashed", color = "gray70") +
      geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2, linewidth = 0.5) +
      geom_point(size = 2) +
      facet_wrap(~dv, scales = "free_y") +
      scale_x_continuous(breaks = seq(-5, 5, 1)) +
      labs(x = "Years Relative to First FL Entry",
           y = "Coefficient") +
      theme_pub()
    save_pub(p6, "fig_06_event_study.pdf")
  }

  # C&S event study (if available)
  if (!is.null(did$callaway_santanna)) {
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
} else {
  cat("  Skipped: DID cache not found\n")
}

# ============================================================================
# Figure 7: Threshold stability
# ============================================================================

cat("  Figure 7: Threshold stability...\n")

if (file.exists(ROBUSTNESS_CACHE_V4)) {
  rob <- readRDS(ROBUSTNESS_CACHE_V4)

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
      labs(x = "IQR Multiplier", y = "Coefficient on FL (log price)") +
      theme_pub()
    save_pub(p7, "fig_07_threshold_stability.pdf")
  }
}

# ============================================================================
# Figure 8: Sensitivity contour (sensemakr)
# ============================================================================

cat("  Figure 8: Sensitivity contour...\n")

if (file.exists(ROBUSTNESS_CACHE_V4)) {
  rob <- readRDS(ROBUSTNESS_CACHE_V4)
  if (!is.null(rob$sensemakr)) {
    fig_path <- file.path(OUT_FIG, "fig_08_sensitivity_contour.pdf")
    cairo_pdf(fig_path, width = FIG_W, height = FIG_H)
    plot(rob$sensemakr, sensitivity.of = "estimate")
    dev.off()
    cat("  Saved:", fig_path, "\n")
  }
}

# ============================================================================
# Figure 9: Welfare bounds comparison (OLS vs IV vs Network)
# ============================================================================

cat("  Figure 9: Welfare bounds...\n")

if (file.exists(WELFARE_CACHE_V4)) {
  wf <- readRDS(WELFARE_CACHE_V4)

  wf_dt <- data.table(
    method = character(), markup = numeric(),
    lo = numeric(), hi = numeric()
  )

  if (!is.null(wf$ols)) {
    wf_dt <- rbind(wf_dt, data.table(
      method = "OLS\n(lower bound)",
      markup = wf$ols$markup,
      lo = (exp(wf$ols$coef - 1.96 * wf$ols$se) - 1) * 100,
      hi = (exp(wf$ols$coef + 1.96 * wf$ols$se) - 1) * 100
    ))
  }

  if (!is.null(wf$iv) && !is.na(wf$iv$markup)) {
    wf_dt <- rbind(wf_dt, data.table(
      method = "IV\n(upper bound)",
      markup = wf$iv$markup,
      lo = (exp(wf$iv$coef - 1.96 * wf$iv$se) - 1) * 100,
      hi = (exp(wf$iv$coef + 1.96 * wf$iv$se) - 1) * 100
    ))
  }

  if (!is.null(wf$network) && !is.na(wf$network$coef_high)) {
    wf_dt <- rbind(wf_dt, data.table(
      method = "High-Suspicion\n(network)",
      markup = (exp(wf$network$coef_high) - 1) * 100,
      lo = NA_real_, hi = NA_real_
    ))
  }

  if (nrow(wf_dt) > 0) {
    wf_dt[, method := factor(method, levels = method)]

    p9 <- ggplot(wf_dt, aes(x = method, y = markup)) +
      geom_col(fill = "gray60", width = 0.5) +
      geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.15, linewidth = 0.5,
                    na.rm = TRUE) +
      geom_hline(yintercept = c(15, 40), linetype = "dashed", color = "gray70") +
      annotate("text", x = 0.5, y = 15, label = "OECD lower", hjust = -0.1, size = 2.5) +
      annotate("text", x = 0.5, y = 40, label = "OECD upper", hjust = -0.1, size = 2.5) +
      labs(x = NULL, y = "Implied Markup (%)") +
      theme_pub()
    save_pub(p9, "fig_09_welfare_markup.pdf")
  }
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
    labs(x = "Year", y = "Coefficient on FL Presence") +
    theme_pub()
  save_pub(p10, "fig_10_year_coefficients.pdf")
}

# ============================================================================
# Figure 11: Network split coefficient comparison
# ============================================================================

cat("  Figure 11: Network split coefficients...\n")

if (!is.null(models$network_split) && length(models$network_split) > 0) {
  ns_data <- data.table()

  for (spec in names(models$network_split)) {
    m <- models$network_split[[spec]]
    if (is.null(m)) next

    for (var in c("has_high_susp_fl", "has_low_susp_fl")) {
      if (var %in% names(coef(m))) {
        b  <- coef(m)[var]
        se <- sqrt(vcov(m)[var, var])
        ns_data <- rbind(ns_data, data.table(
          spec = spec_labels[spec],
          type = if (var == "has_high_susp_fl") "High Suspicion" else "Low Suspicion",
          coef = b, se = se,
          ci_lo = b - 1.96 * se, ci_hi = b + 1.96 * se
        ))
      }
    }
  }

  if (nrow(ns_data) > 0) {
    p11 <- ggplot(ns_data, aes(x = coef, y = spec, shape = type, color = type)) +
      geom_vline(xintercept = 0, linetype = "dotted", color = "gray50") +
      geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.15, linewidth = 0.5,
                    position = position_dodge(width = 0.4)) +
      geom_point(size = 2.5, position = position_dodge(width = 0.4)) +
      scale_color_manual(values = c("High Suspicion" = "firebrick", "Low Suspicion" = "steelblue")) +
      labs(x = "Coefficient on FL (log price)", y = NULL) +
      theme_pub()
    save_pub(p11, "fig_11_network_split.pdf")
  }
}

# ============================================================================
# Figure 12: FL definition robustness (low-win-rate + cross-fit + temporal)
# ============================================================================

cat("  Figure 12: FL definition robustness...\n")

if (file.exists(FL_ROBUST_CACHE_V4)) {
  fl_rob <- readRDS(FL_ROBUST_CACHE_V4)

  fl_rob_dt <- data.table()

  # Low-win-rate
  if (!is.null(fl_rob$low_winrate)) {
    for (nm in names(fl_rob$low_winrate)) {
      r <- fl_rob$low_winrate[[nm]]
      if (!is.null(r$coef)) {
        fl_rob_dt <- rbind(fl_rob_dt, data.table(
          variant = paste0("Win rate < ", nm),
          coef = r$coef, se = r$se,
          ci_lo = r$coef - 1.96 * r$se, ci_hi = r$coef + 1.96 * r$se
        ))
      }
    }
  }

  # Cross-fitting
  if (!is.null(fl_rob$crossfit)) {
    for (nm in names(fl_rob$crossfit)) {
      r <- fl_rob$crossfit[[nm]]
      if (!is.null(r$coef)) {
        lbl <- if (nm == "odd_train") "Train odd, est even" else "Train even, est odd"
        fl_rob_dt <- rbind(fl_rob_dt, data.table(
          variant = lbl,
          coef = r$coef, se = r$se,
          ci_lo = r$coef - 1.96 * r$se, ci_hi = r$coef + 1.96 * r$se
        ))
      }
    }
  }

  # Add baseline for reference
  m_base <- models$prices$general_pbu
  if (!is.null(m_base) && "losers" %in% names(coef(m_base))) {
    b <- coef(m_base)["losers"]; se <- sqrt(vcov(m_base)["losers", "losers"])
    fl_rob_dt <- rbind(data.table(
      variant = "Baseline (win_rate=0)",
      coef = b, se = se, ci_lo = b - 1.96 * se, ci_hi = b + 1.96 * se
    ), fl_rob_dt)
  }

  if (nrow(fl_rob_dt) > 0) {
    fl_rob_dt[, variant := factor(variant, levels = rev(variant))]

    p12 <- ggplot(fl_rob_dt, aes(x = coef, y = variant)) +
      geom_vline(xintercept = 0, linetype = "dotted", color = "gray50") +
      geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.15, linewidth = 0.5) +
      geom_point(size = 2.5) +
      labs(x = "Coefficient on FL (log price)", y = NULL) +
      theme_pub()
    save_pub(p12, "fig_12_fl_definition_robustness.pdf")
  }
}

# ============================================================================
# Figure 13: CADE permutation distribution
# ============================================================================

cat("  Figure 13: CADE permutation...\n")

if (file.exists(CADE_CACHE_V4)) {
  cade <- readRDS(CADE_CACHE_V4)

  if (!is.null(cade$permutation) && !is.null(cade$permutation$perm_rates)) {
    perm_dt <- data.table(rate = cade$permutation$perm_rates * 100)
    obs_rate <- cade$permutation$observed_rate * 100

    p13 <- ggplot(perm_dt, aes(x = rate)) +
      geom_histogram(bins = 50, fill = "gray60", color = "gray30", linewidth = 0.3) +
      geom_vline(xintercept = obs_rate, linetype = "dashed", color = "firebrick",
                 linewidth = 0.7) +
      annotate("text", x = obs_rate, y = Inf, vjust = 2, hjust = -0.1,
               label = sprintf("Observed = %.1f%%", obs_rate),
               size = 3, color = "firebrick") +
      labs(x = "Co-participation Rate with CADE Firms (%)",
           y = "Number of Permutations") +
      theme_pub()
    save_pub(p13, "fig_13_cade_permutation.pdf")
  }
}

# ============================================================================
# Figure 14: Oversight heterogeneity (regime)
# ============================================================================

cat("  Figure 14: Oversight heterogeneity...\n")

if (file.exists(REGIME_CACHE_V4)) {
  regime <- readRDS(REGIME_CACHE_V4)

  if (!is.null(regime$oversight)) {
    ov <- regime$oversight
    ov_dt <- data.table()

    for (q_val in 1:4) {
      key <- paste0("pbu_q", q_val)
      if (!is.null(ov[[key]])) {
        r <- ov[[key]]
        ov_dt <- rbind(ov_dt, data.table(
          group = paste0("PBU Q", q_val),
          coef = r$coef, se = r$se,
          ci_lo = r$coef - 1.96 * r$se, ci_hi = r$coef + 1.96 * r$se
        ))
      }
    }

    for (proc in c("pregao", "convite")) {
      if (!is.null(ov[[proc]])) {
        r <- ov[[proc]]
        lbl <- if (proc == "pregao") "Pregao" else "Convite"
        ov_dt <- rbind(ov_dt, data.table(
          group = lbl,
          coef = r$coef, se = r$se,
          ci_lo = r$coef - 1.96 * r$se, ci_hi = r$coef + 1.96 * r$se
        ))
      }
    }

    if (nrow(ov_dt) > 0) {
      ov_dt[, group := factor(group, levels = rev(group))]

      p14 <- ggplot(ov_dt, aes(x = coef, y = group)) +
        geom_vline(xintercept = 0, linetype = "dotted", color = "gray50") +
        geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.15, linewidth = 0.5) +
        geom_point(size = 2.5) +
        labs(x = "FL Coefficient on Log Price", y = NULL) +
        theme_pub()
      save_pub(p14, "fig_14_oversight_heterogeneity.pdf")
    }
  }
}

cat("  All figures generated.\n")
