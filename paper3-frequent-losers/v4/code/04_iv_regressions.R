# ============================================================================
# 04_iv_regressions.R — 2SLS regressions using LOO instrument (NEW for v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Main causal identification strategy [Major 3.1]:
#   First stage: losers ~ fl_supply_loo + convite | item_f + year_f + pbu_f
#   2SLS: lneg_price ~ convite | item_f + year_f + pbu_f | losers ~ fl_supply_loo
#
# Also: placebo IV (sub-threshold always-losers) and network-split IV.
#
# Outputs:
#   - /tmp/p3v4_iv_models.rds
#   - tab_iv_main.tex, tab_iv_first_stage.tex, tab_iv_placebo.tex
#   - fig_first_stage_binscatter.pdf
# ============================================================================

cat("=== 04_iv_regressions.R: 2SLS regressions ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data ---------------------------------------------------------------
if (!file.exists(DATA_CACHE_V4)) stop("Run 01-03 first")
dt <- readRDS(DATA_CACHE_V4)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

if (!"fl_supply_loo" %in% names(dt)) stop("Run 03_iv_construction.R first")
cat(sprintf("  fl_supply_loo: mean=%.2f, non-zero=%s\n",
            mean(dt$fl_supply_loo), pfmt_int(sum(dt$fl_supply_loo > 0))))

# ============================================================================
# Phase 1: First-stage diagnostics
# ============================================================================

cat("  Phase 1: First-stage regressions...\n")

# First stage: losers ~ fl_supply_loo + convite | item_f + year_f + pbu_f
fs_general <- feols(
  losers ~ fl_supply_loo + convite | item_f + year_f,
  data = dt, cluster = ~item_f, fixef.rm = "none"
)

fs_pbu <- feols(
  losers ~ fl_supply_loo + convite | item_f + year_f + pbu_f,
  data = dt, cluster = ~item_f, fixef.rm = "none"
)

fs_pregao <- feols(
  losers ~ fl_supply_loo | item_f + year_f + pbu_f,
  data = dt[pregao == 1L], cluster = ~item_f, fixef.rm = "none"
)

# First-stage F-statistics
cat("  First-stage coefficients (fl_supply_loo):\n")
for (nm in c("general", "pbu", "pregao")) {
  m <- get(paste0("fs_", nm))
  b  <- coef(m)["fl_supply_loo"]
  se <- sqrt(vcov(m)["fl_supply_loo", "fl_supply_loo"])
  f_stat <- (b / se)^2
  cat(sprintf("    %s: coef=%.6f (SE=%.6f), F=%.1f\n", nm, b, se, f_stat))
}

# ============================================================================
# Phase 2: 2SLS regressions (main IV results)
# ============================================================================

cat("  Phase 2: 2SLS regressions...\n")

dvs <- c("lneg_price", "ln_firms", "ln_bids", "ln_firms_excl")
dv_labels <- c("Log Price", "Log Firms", "Log Bids", "Log Firms (excl. FL)")

iv_models <- list()

for (di in seq_along(dvs)) {
  dv <- dvs[di]
  dv_lbl <- dv_labels[di]

  d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt

  cat(sprintf("  %s...\n", dv_lbl))

  # Spec 1: General + PBU FE (preferred)
  iv_pbu <- tryCatch(
    feols(as.formula(paste0(dv, " ~ convite | item_f + year_f + pbu_f | losers ~ fl_supply_loo")),
          data = d, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) { cat(sprintf("    IV+PBU failed: %s\n", e$message)); NULL }
  )

  # Spec 2: Pregao only
  iv_pregao <- tryCatch(
    feols(as.formula(paste0(dv, " ~ 1 | item_f + year_f + pbu_f | losers ~ fl_supply_loo")),
          data = d[pregao == 1L], cluster = ~item_f, fixef.rm = "none"),
    error = function(e) { cat(sprintf("    IV+Pregao failed: %s\n", e$message)); NULL }
  )

  iv_models[[dv]] <- list(iv_pbu = iv_pbu, iv_pregao = iv_pregao)

  # Print results
  if (!is.null(iv_pbu) && "fit_losers" %in% names(coef(iv_pbu))) {
    b <- coef(iv_pbu)["fit_losers"]
    se <- sqrt(vcov(iv_pbu)["fit_losers", "fit_losers"])
    cat(sprintf("    IV+PBU: %.4f (%.4f) N=%s\n", b, se, pfmt_int(iv_pbu$nobs)))
  }
}

# ============================================================================
# Phase 2B: Panel C — IV with item_group x year FE (Comment 2.1A)
# ============================================================================

cat("  Phase 2B: 2SLS with item_group x year FE...\n")

iv_igyr_models <- list()
if ("item_group_year_f" %in% names(dt)) {
  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt

    iv_igyr <- tryCatch(
      feols(as.formula(paste0(dv, " ~ convite | item_group_year_f + pbu_f | losers ~ fl_supply_loo")),
            data = d, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) {
        cat(sprintf("    IV+IGYR failed for %s: %s\n", dv, e$message))
        # Fallback: absorb item_group_year_f and item_f separately
        tryCatch(
          feols(as.formula(paste0(dv, " ~ convite | item_f + item_group_year_f + pbu_f | losers ~ fl_supply_loo")),
                data = d, cluster = ~item_f, fixef.rm = "none"),
          error = function(e2) { cat(sprintf("    Fallback also failed: %s\n", e2$message)); NULL }
        )
      }
    )
    iv_igyr_models[[dv]] <- iv_igyr

    if (!is.null(iv_igyr) && "fit_losers" %in% names(coef(iv_igyr))) {
      b <- coef(iv_igyr)["fit_losers"]
      se <- sqrt(vcov(iv_igyr)["fit_losers", "fit_losers"])
      cat(sprintf("    %s IV+IGYR: %.4f (%.4f) N=%s\n", dv, b, se, pfmt_int(iv_igyr$nobs)))
    }
  }
} else {
  cat("  item_group_year_f not available. Run 01_data_prep.R (v5).\n")
}

# ============================================================================
# Phase 2C: Balance tests (Comment 2.1B)
# ============================================================================

cat("  Phase 2C: Balance tests — observables on LOO instrument...\n")

balance_vars <- c("ln_firms_excl", "log_ref_price", "convite", "log_bid_sd")
balance_labels <- c("Log Firms (excl. FL)", "Log Reference Price", "Convite", "Log Bid SD")
balance_results <- list()

for (bi in seq_along(balance_vars)) {
  bv <- balance_vars[bi]
  if (!bv %in% names(dt)) { cat(sprintf("    %s: not available\n", bv)); next }
  d_bal <- dt[!is.na(get(bv))]
  m_bal <- tryCatch(
    feols(as.formula(paste0(bv, " ~ fl_supply_loo + convite | item_f + year_f + pbu_f")),
          data = d_bal, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) {
      # convite is both a control and a balance var; drop from RHS if needed
      tryCatch(
        feols(as.formula(paste0(bv, " ~ fl_supply_loo | item_f + year_f + pbu_f")),
              data = d_bal, cluster = ~item_f, fixef.rm = "none"),
        error = function(e2) NULL
      )
    }
  )
  if (!is.null(m_bal) && "fl_supply_loo" %in% names(coef(m_bal))) {
    b <- coef(m_bal)["fl_supply_loo"]
    se <- sqrt(vcov(m_bal)["fl_supply_loo", "fl_supply_loo"])
    p <- 2 * pnorm(-abs(b/se))
    # Standardized effect: coef × SD(instrument) / SD(outcome)
    sd_instr <- sd(d_bal[["fl_supply_loo"]], na.rm = TRUE)
    sd_outc  <- sd(d_bal[[bv]], na.rm = TRUE)
    std_eff  <- abs(b) * sd_instr / sd_outc
    balance_results[[bv]] <- list(coef = b, se = se, p = p, n = m_bal$nobs,
                                  label = balance_labels[bi], std_eff = std_eff)
    cat(sprintf("    %s: coef=%.6f (SE=%.6f), p=%.4f, std=%.4f SD\n", bv, b, se, p, std_eff))
  }
}

# Write tab_iv_balance.tex
if (length(balance_results) > 0) {
  cat("  Writing tab_iv_balance.tex...\n")
  bal_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Balance Tests: Observables on LOO Instrument}",
    "\\label{tab:iv_balance}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lccccc}", "\\toprule",
    "Observable & Coefficient & SE & \\textit{p}-value & Std.\\ Effect & N \\\\", "\\midrule"
  )
  for (bv in names(balance_results)) {
    r <- balance_results[[bv]]
    bal_lines <- c(bal_lines, sprintf(
      "%s & %s & (%s) & %s & %s & %s \\\\",
      r$label, pfmt(r$coef, 6), pfmt(r$se, 6), pfmt(r$p, 4),
      sprintf("%.3f", r$std_eff), pfmt_int(r$n)))
  }
  bal_lines <- c(bal_lines, "\\midrule",
    "Item + Year + PBU FE & \\multicolumn{4}{c}{YES} \\\\",
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Each row regresses the observable on the LOO instrument",
    "with item, year, and PBU FE. Std.\\ Effect = $|\\hat{\\beta}| \\times \\text{SD}(Z) / \\text{SD}(Y)$,",
    "i.e.\\ the SD change in the outcome per SD increase in the instrument.",
    "SE clustered at item level.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(bal_lines, file.path(OUT_TAB, "tab_iv_balance.tex"))
}

# ============================================================================
# Phase 2D: Implied misclassification rate (Comment 2.2)
# ============================================================================

cat("  Phase 2D: IV magnitude interpretation...\n")

m_ols_price <- NULL
if (file.exists(MODELS_CACHE_V4)) {
  models_loaded <- readRDS(MODELS_CACHE_V4)
  m_ols_price <- models_loaded$prices$general_pbu
}

if (!is.null(m_ols_price) && !is.null(iv_models$lneg_price$iv_pbu)) {
  b_ols <- coef(m_ols_price)["losers"]
  m_iv_price <- iv_models$lneg_price$iv_pbu
  b_iv <- coef(m_iv_price)["fit_losers"]
  lambda <- b_ols / b_iv
  misclass <- 1 - lambda
  cat(sprintf("  OLS = %.4f, IV = %.4f\n", b_ols, b_iv))
  cat(sprintf("  Lambda (OLS/IV) = %.4f → %.0f%% of treatment variation is noise\n",
              lambda, misclass * 100))

  # Compare to network low-suspicion
  if (!is.null(models_loaded$network_split) && length(models_loaded$network_split) > 0) {
    m_ns <- models_loaded$network_split$general_pbu
    if ("has_low_susp_fl" %in% names(coef(m_ns))) {
      b_low <- coef(m_ns)["has_low_susp_fl"]
      ratio_iv_low <- b_iv / b_low
      cat(sprintf("  IV / low-suspicion = %.4f / %.4f = %.2f\n", b_iv, b_low, ratio_iv_low))
    }
  }

  cat("\n  === Manuscript text (Comment 2.2) ===\n")
  cat(sprintf("  The ratio lambda = OLS/IV = %.3f implies that approximately %.0f%% of the\n",
              lambda, misclass * 100))
  cat("  variation in the binary FL indicator is noise (misclassification). This is\n")
  cat("  plausible: the IQR threshold is a statistical screen, not a diagnostic tool.\n")
  cat("  The IV estimate represents the LATE for tenders where FL presence is driven by\n")
  cat("  supply-side availability rather than demand-side selection.\n")
} else {
  cat("  OLS or IV models not available for misclassification computation.\n")
}

# ============================================================================
# Phase 3: Placebo IV (sub-threshold always-losers)
# ============================================================================

cat("  Phase 3: Placebo IV...\n")

placebo_models <- list()
if ("sub_supply_loo" %in% names(dt)) {
  d_price <- dt[!is.na(lneg_price)]

  # Placebo first stage
  fs_placebo <- tryCatch(
    feols(losers ~ sub_supply_loo + convite | item_f + year_f + pbu_f,
          data = d_price, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) NULL
  )

  if (!is.null(fs_placebo)) {
    b_pl <- coef(fs_placebo)["sub_supply_loo"]
    se_pl <- sqrt(vcov(fs_placebo)["sub_supply_loo", "sub_supply_loo"])
    cat(sprintf("  Placebo first-stage: %.6f (%.6f), F=%.1f\n",
                b_pl, se_pl, (b_pl/se_pl)^2))
  }

  # Placebo 2SLS (expect null)
  iv_placebo <- tryCatch(
    feols(lneg_price ~ convite | item_f + year_f + pbu_f | losers ~ sub_supply_loo,
          data = d_price, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) { cat(sprintf("  Placebo 2SLS failed: %s\n", e$message)); NULL }
  )

  placebo_models$first_stage <- fs_placebo
  placebo_models$iv <- iv_placebo

  if (!is.null(iv_placebo) && "fit_losers" %in% names(coef(iv_placebo))) {
    b <- coef(iv_placebo)["fit_losers"]
    se <- sqrt(vcov(iv_placebo)["fit_losers", "fit_losers"])
    p <- 2 * pnorm(-abs(b/se))
    cat(sprintf("  Placebo IV: %.4f (%.4f) p=%.4f %s\n",
                b, se, p, if (p > 0.10) "(null, as expected)" else "(significant!)"))
  }
} else {
  cat("  sub_supply_loo not available. Skipping placebo IV.\n")
}

# ============================================================================
# Phase 4: Network-split IV
# ============================================================================

cat("  Phase 4: Network-split IV (high-suspicion FL)...\n")

iv_network <- list()
if ("has_high_susp_fl" %in% names(dt) && "high_supply_loo" %in% names(dt)) {
  d_price <- dt[!is.na(lneg_price)]

  iv_high <- tryCatch(
    feols(lneg_price ~ convite | item_f + year_f + pbu_f |
            has_high_susp_fl ~ high_supply_loo,
          data = d_price, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) { cat(sprintf("  Network IV failed: %s\n", e$message)); NULL }
  )

  iv_network$iv_high <- iv_high
  if (!is.null(iv_high) && "fit_has_high_susp_fl" %in% names(coef(iv_high))) {
    b <- coef(iv_high)["fit_has_high_susp_fl"]
    se <- sqrt(vcov(iv_high)["fit_has_high_susp_fl", "fit_has_high_susp_fl"])
    cat(sprintf("  Network IV (high-susp): %.4f (%.4f) N=%s\n",
                b, se, pfmt_int(iv_high$nobs)))
  }
}

# ============================================================================
# Phase 5: Write tables
# ============================================================================

cat("  Writing IV tables...\n")

# --- tab_iv_first_stage.tex ---
fs_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{First-Stage Regressions: FL Supply Instrument}",
  "\\label{tab:iv_first_stage}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}", "\\toprule",
  " & (1) General & (2) General+PBU & (3) Preg\\~{a}o \\\\",
  " & \\multicolumn{3}{c}{DV: FL presence ($\\mathbb{1}[\\text{losers} > 0]$)} \\\\",
  "\\midrule"
)

for (nm in c("general", "pbu", "pregao")) {
  m <- get(paste0("fs_", nm))
  b <- coef(m)["fl_supply_loo"]
  se <- sqrt(vcov(m)["fl_supply_loo", "fl_supply_loo"])
  p <- 2 * pnorm(-abs(b/se))
  f_stat <- (b/se)^2

  if (nm == "general") {
    fs_lines <- c(fs_lines, sprintf(
      "FL supply (LOO) & %s%s & & \\\\", pfmt(b, 6), pstars(p)))
    fs_lines <- c(fs_lines, sprintf(" & (%s) & & \\\\", pfmt(se, 6)))
  } else if (nm == "pbu") {
    fs_lines <- c(fs_lines, sprintf(
      " & & %s%s & \\\\", pfmt(b, 6), pstars(p)))
    fs_lines <- c(fs_lines, sprintf(" & & (%s) & \\\\", pfmt(se, 6)))
  } else {
    fs_lines <- c(fs_lines, sprintf(
      " & & & %s%s \\\\", pfmt(b, 6), pstars(p)))
    fs_lines <- c(fs_lines, sprintf(" & & & (%s) \\\\", pfmt(se, 6)))
  }
}

fs_lines <- c(fs_lines, "\\midrule")

# F-statistics row
f_vals <- sapply(c("general", "pbu", "pregao"), function(nm) {
  m <- get(paste0("fs_", nm))
  b <- coef(m)["fl_supply_loo"]
  se <- sqrt(vcov(m)["fl_supply_loo", "fl_supply_loo"])
  sprintf("%.1f", (b/se)^2)
})
fs_lines <- c(fs_lines, sprintf("F-statistic & %s \\\\", paste(f_vals, collapse = " & ")))

obs_vals <- sapply(c("general", "pbu", "pregao"), function(nm) {
  pfmt_int(get(paste0("fs_", nm))$nobs)
})
fs_lines <- c(fs_lines, sprintf("Observations & %s \\\\", paste(obs_vals, collapse = " & ")))

# Partial R² row (Comment 2.1C)
pr2_vals <- sapply(c("general", "pbu", "pregao"), function(nm) {
  m <- get(paste0("fs_", nm))
  r2_full <- fitstat(m, "r2")[[1]]
  # Partial R²: contribution of fl_supply_loo beyond FE
  b <- coef(m)["fl_supply_loo"]
  se <- sqrt(vcov(m)["fl_supply_loo", "fl_supply_loo"])
  f <- (b / se)^2
  # Approximate partial R² = F / (F + dof)
  dof <- m$nobs - length(coef(m))
  sprintf("%.4f", f / (f + dof))
})
fs_lines <- c(fs_lines, sprintf("Partial $R^2$ & %s \\\\", paste(pr2_vals, collapse = " & ")))

fs_lines <- c(fs_lines, "PBU FE & NO & YES & YES \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} FL supply (LOO) = count of FL firms active at other PBUs",
  "in the same item group and year, excluding the focal PBU.",
  "SE clustered at item level. *** \\textit{p}$<$0.01.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(fs_lines, file.path(OUT_TAB, "tab_iv_first_stage.tex"))

# --- tab_iv_main.tex (2SLS results) ---
iv_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{2SLS Estimates: Effect of FL Presence on Tender Outcomes}",
  "\\label{tab:iv_main}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & Log Price & Log Firms & Log Bids & Log Firms (excl.) \\\\",
  " & (1) & (2) & (3) & (4) \\\\",
  "\\midrule",
  "\\textit{Panel A: 2SLS (General + PBU FE)} & & & & \\\\"
)

# Panel A: IV + PBU FE
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  m <- iv_models[[dv]]$iv_pbu
  if (!is.null(m) && "fit_losers" %in% names(coef(m))) {
    b <- coef(m)["fit_losers"]
    se <- sqrt(vcov(m)["fit_losers", "fit_losers"])
    p <- 2 * pnorm(-abs(b/se))
    if (di == 1) {
      iv_lines <- c(iv_lines, sprintf(
        "FL presence (instrumented) & %s%s & & & \\\\", pfmt(b, 4), pstars(p)))
      iv_lines <- c(iv_lines, sprintf(" & (%s) & & & \\\\", pfmt(se, 4)))
    }
  }
}

# Simpler: show all 4 DVs in one row
vals <- character(4)
ses_row <- character(4)
for (di in seq_along(dvs)) {
  m <- iv_models[[dvs[di]]]$iv_pbu
  if (!is.null(m) && "fit_losers" %in% names(coef(m))) {
    b <- coef(m)["fit_losers"]
    se <- sqrt(vcov(m)["fit_losers", "fit_losers"])
    p <- 2 * pnorm(-abs(b/se))
    vals[di] <- paste0(pfmt(b, 4), pstars(p))
    ses_row[di] <- sprintf("(%s)", pfmt(se, 4))
  } else {
    vals[di] <- "---"
    ses_row[di] <- ""
  }
}

# Overwrite Panel A with proper format
iv_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{2SLS Estimates: Effect of FL Presence on Tender Outcomes}",
  "\\label{tab:iv_main}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & Log Price & Log Firms & Log Bids & Log Firms (excl.) \\\\",
  " & (1) & (2) & (3) & (4) \\\\",
  "\\midrule",
  "\\textit{Panel A: 2SLS (General + PBU FE)} & & & & \\\\",
  sprintf("FL presence (instrumented) & %s \\\\", paste(vals, collapse = " & ")),
  sprintf(" & %s \\\\", paste(ses_row, collapse = " & "))
)

# Observations for Panel A
obs_a <- sapply(dvs, function(dv) {
  m <- iv_models[[dv]]$iv_pbu
  if (!is.null(m)) pfmt_int(m$nobs) else "---"
})
iv_lines <- c(iv_lines, sprintf("Observations & %s \\\\", paste(obs_a, collapse = " & ")))

# Panel B: Pregao only
iv_lines <- c(iv_lines, "\\midrule",
  "\\textit{Panel B: 2SLS (Preg\\~{a}o only)} & & & & \\\\")

vals_b <- character(4)
ses_b <- character(4)
for (di in seq_along(dvs)) {
  m <- iv_models[[dvs[di]]]$iv_pregao
  if (!is.null(m) && "fit_losers" %in% names(coef(m))) {
    b <- coef(m)["fit_losers"]
    se <- sqrt(vcov(m)["fit_losers", "fit_losers"])
    p <- 2 * pnorm(-abs(b/se))
    vals_b[di] <- paste0(pfmt(b, 4), pstars(p))
    ses_b[di] <- sprintf("(%s)", pfmt(se, 4))
  } else {
    vals_b[di] <- "---"
    ses_b[di] <- ""
  }
}
iv_lines <- c(iv_lines,
  sprintf("FL presence (instrumented) & %s \\\\", paste(vals_b, collapse = " & ")),
  sprintf(" & %s \\\\", paste(ses_b, collapse = " & ")))

obs_b <- sapply(dvs, function(dv) {
  m <- iv_models[[dv]]$iv_pregao
  if (!is.null(m)) pfmt_int(m$nobs) else "---"
})
iv_lines <- c(iv_lines, sprintf("Observations & %s \\\\", paste(obs_b, collapse = " & ")))

# Panel C: Item-group x Year FE (Comment 2.1A)
if (length(iv_igyr_models) > 0 && any(!sapply(iv_igyr_models, is.null))) {
  iv_lines <- c(iv_lines, "\\midrule",
    "\\textit{Panel C: 2SLS (Item-group $\\times$ Year FE)} & & & & \\\\")

  vals_c <- character(4)
  ses_c <- character(4)
  for (di in seq_along(dvs)) {
    m <- iv_igyr_models[[dvs[di]]]
    if (!is.null(m) && "fit_losers" %in% names(coef(m))) {
      b <- coef(m)["fit_losers"]
      se <- sqrt(vcov(m)["fit_losers", "fit_losers"])
      p <- 2 * pnorm(-abs(b/se))
      vals_c[di] <- paste0(pfmt(b, 4), pstars(p))
      ses_c[di] <- sprintf("(%s)", pfmt(se, 4))
    } else {
      vals_c[di] <- "---"
      ses_c[di] <- ""
    }
  }
  iv_lines <- c(iv_lines,
    sprintf("FL presence (instrumented) & %s \\\\", paste(vals_c, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses_c, collapse = " & ")))

  obs_c <- sapply(dvs, function(dv) {
    m <- iv_igyr_models[[dv]]
    if (!is.null(m)) pfmt_int(m$nobs) else "---"
  })
  iv_lines <- c(iv_lines, sprintf("Observations & %s \\\\", paste(obs_c, collapse = " & ")))
}

iv_lines <- c(iv_lines, "\\midrule",
  "Item + Year + PBU FE & YES & YES & YES & YES \\\\",
  "Instrument & \\multicolumn{4}{c}{FL supply at other PBUs (LOO)} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 2SLS using leave-one-out FL supply as instrument.",
  "FL supply (LOO) = count of FL firms active at other PBUs in the same item",
  "group and year. SE clustered at item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(iv_lines, file.path(OUT_TAB, "tab_iv_main.tex"))

# --- tab_iv_placebo.tex ---
if (!is.null(placebo_models$iv)) {
  plac_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Placebo IV: Sub-Threshold Always-Losers as Instrument}",
    "\\label{tab:iv_placebo}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcc}", "\\toprule",
    " & First Stage & 2SLS \\\\",
    " & FL presence & Log Price \\\\",
    "\\midrule"
  )

  m_fs <- placebo_models$first_stage
  if (!is.null(m_fs)) {
    b_fs <- coef(m_fs)["sub_supply_loo"]
    se_fs <- sqrt(vcov(m_fs)["sub_supply_loo", "sub_supply_loo"])
    p_fs <- 2 * pnorm(-abs(b_fs/se_fs))
    plac_lines <- c(plac_lines,
      sprintf("Sub-threshold supply (LOO) & %s%s & \\\\",
              pfmt(b_fs, 6), pstars(p_fs)),
      sprintf(" & (%s) & \\\\", pfmt(se_fs, 6)),
      sprintf("F-statistic & %.1f & \\\\", (b_fs/se_fs)^2))
  }

  m_iv <- placebo_models$iv
  if (!is.null(m_iv) && "fit_losers" %in% names(coef(m_iv))) {
    b_iv <- coef(m_iv)["fit_losers"]
    se_iv <- sqrt(vcov(m_iv)["fit_losers", "fit_losers"])
    p_iv <- 2 * pnorm(-abs(b_iv/se_iv))
    plac_lines <- c(plac_lines,
      sprintf("FL presence (instrumented) & & %s%s \\\\",
              pfmt(b_iv, 4), pstars(p_iv)),
      sprintf(" & & (%s) \\\\", pfmt(se_iv, 4)))
  }

  plac_lines <- c(plac_lines, "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Placebo instrument uses supply of sub-threshold",
    "always-losers (below the IQR cutoff). These firms lose always but participate",
    "in fewer tenders. If the main IV effect is causal, sub-threshold firms should",
    "not predict prices. SE clustered at item level.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(plac_lines, file.path(OUT_TAB, "tab_iv_placebo.tex"))
}

# ============================================================================
# Phase 6: First-stage binscatter
# ============================================================================

cat("  Creating first-stage binscatter...\n")

# Filter to non-zero instrument values to get meaningful bins
d_bin <- dt[!is.na(fl_supply_loo) & fl_supply_loo > 0]
# Create bins using unique quantile breaks
brks <- unique(quantile(d_bin$fl_supply_loo, probs = seq(0, 1, 0.05), na.rm = TRUE))
if (length(brks) < 3) brks <- unique(quantile(d_bin$fl_supply_loo, probs = seq(0, 1, 0.1), na.rm = TRUE))
d_bin[, loo_bin := cut(fl_supply_loo,
  breaks = brks,
  include.lowest = TRUE, labels = FALSE)]

bin_means <- d_bin[!is.na(loo_bin), .(
  mean_loo = mean(fl_supply_loo),
  mean_losers = mean(losers),
  n = .N
), by = loo_bin]

p_bs <- ggplot(bin_means, aes(x = mean_loo, y = mean_losers)) +
  geom_point(aes(size = n), alpha = 0.7) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 0.7) +
  labs(x = "FL Supply at Other PBUs (LOO instrument, binned means)",
       y = "FL Presence (mean within bin)") +
  guides(size = "none") +
  theme_pub()
save_pub(p_bs, "fig_first_stage_binscatter.pdf")

# ============================================================================
# Save all IV models
# ============================================================================

all_iv <- list(
  first_stage = list(general = fs_general, pbu = fs_pbu, pregao = fs_pregao),
  iv_models = iv_models,
  iv_igyr_models = iv_igyr_models,
  balance = balance_results,
  placebo = placebo_models,
  network_iv = iv_network
)

saveRDS(all_iv, IV_MODELS_CACHE_V4)
cat("  IV models saved:", IV_MODELS_CACHE_V4, "\n")
cat("  Done.\n")
