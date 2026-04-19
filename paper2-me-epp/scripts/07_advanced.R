# ============================================================================
# 07_advanced.R — Advanced econometric methods
#   1. HonestDiD (Rambachan & Roth 2023) — parallel trends sensitivity
#   2. Lee (2009) Bounds — sample selection correction
#   3. Causal Forest (Athey, Tibshirani & Wager 2019) — heterogeneous effects
#   4. Quantile DiD — distributional treatment effects
#   5. Gelbach (2016) Decomposition — mechanism quantification
# ============================================================================

cat("=== 07_advanced.R: Advanced econometric methods ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data and models -------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

models_path <- "/tmp/p2_models.rds"
if (!file.exists(models_path)) stop("Run 02_analysis.R first")
models <- readRDS(models_path)

advanced <- list()

# ============================================================================
# 1. PARALLEL TRENDS SENSITIVITY ANALYSIS (Rambachan & Roth 2023)
# ============================================================================
cat("\n  --- Method 1: Parallel trends sensitivity analysis ---\n")

# Manual implementation of Rambachan & Roth (2023) relative magnitudes approach.
# Under ΔRM(Mbar): post-treatment violations bounded by Mbar × max pre-trend violation.
# Robust CI = [β̂_post ± (bias_bound + z_α × SE)]
# This is a conservative (worst-case) version of the HonestDiD package approach.

advanced$honestdid <- tryCatch({
  es_models <- list(
    prices   = models$es_prices,
    distance = models$es_distance,
    numfirms = models$es_numfirms,
    numbids  = models$es_numbids
  )

  honestdid_results <- list()

  for (nm in names(es_models)) {
    cat("    Processing:", nm, "...\n")
    m <- es_models[[nm]]

    # Extract coefficients: fixest i() terms are semester_f::k:g65 for k=1..6 except ref=4
    ct <- as.data.table(coeftable(m), keep.rownames = "term")
    setnames(ct, c("term", "estimate", "se", "tval", "pval"))
    ct <- ct[grepl("semester_f::", term)]
    ct[, semester := as.integer(gsub(".*semester_f::(\\d+):g65", "\\1", term))]
    setorder(ct, semester)

    # Should be semesters 1,2,3,5,6 (4 is reference)
    # Pre-treatment: semesters 1,2,3 (indices 1:3)
    # Post-treatment: semesters 5,6 (indices 4:5)
    betahat <- ct$estimate
    se_vec  <- ct$se
    names(betahat) <- paste0("s", ct$semester)

    pre_coefs  <- betahat[1:3]   # semesters 1,2,3
    post_coefs <- betahat[4:5]   # semesters 5,6
    post_ses   <- se_vec[4:5]

    # Maximum absolute pre-treatment violation (relative to reference period 4 = 0)
    max_pre_violation <- max(abs(pre_coefs))

    # First post-treatment coefficient (semester 5) — our target
    beta_post1 <- post_coefs[1]
    se_post1   <- post_ses[1]

    # Sensitivity analysis across Mbar values
    Mbarvec <- seq(0, 2, by = 0.25)
    sens_df <- data.frame(Mbar = numeric(), lb = numeric(), ub = numeric(),
                          stringsAsFactors = FALSE)

    for (Mbar in Mbarvec) {
      bias_bound <- Mbar * max_pre_violation
      lb <- beta_post1 - bias_bound - 1.96 * se_post1
      ub <- beta_post1 + bias_bound + 1.96 * se_post1
      sens_df <- rbind(sens_df, data.frame(Mbar = Mbar, lb = lb, ub = ub))
    }

    honestdid_results[[nm]] <- list(
      betahat           = betahat,
      max_pre_violation = max_pre_violation,
      beta_post1        = beta_post1,
      se_post1          = se_post1,
      result            = sens_df
    )

    cat("      β_post1 =", pfmt(beta_post1, 4),
        ", max |pre| =", pfmt(max_pre_violation, 4), "\n")
  }

  cat("    Sensitivity analysis completed.\n")
  honestdid_results
}, error = function(e) {
  cat("    ERROR in sensitivity analysis:", conditionMessage(e), "\n")
  NULL
})

# ============================================================================
# 2. LEE (2009) BOUNDS — SAMPLE SELECTION CORRECTION
# ============================================================================
cat("\n  --- Method 2: Lee (2009) bounds ---\n")

advanced$lee_bounds <- tryCatch({
  # Prices conditioned on completion (oc_item_status==1). If treatment affects
  # completion, we have selection bias. Lee bounds trim the outcome distribution
  # to equalize selection rates across treatment/control.

  # 18-month window
  lb_data <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]

  # Step 1: Compute completion rates by g65 × Pre cell
  comp_rates <- lb_data[, .(
    n_total     = .N,
    n_completed = sum(oc_item_status == 1L, na.rm = TRUE)
  ), by = .(g65, Pre)]
  comp_rates[, comp_rate := n_completed / n_total]

  cat("    Completion rates:\n")
  print(comp_rates)

  # Step 2: Compute trimming proportion
  # For DiD, we need to equalize selection within each cross-section
  # Compare treatment group (g65=1) completion rate change vs control (g65=0)
  cr_t_pre  <- comp_rates[g65 == 1 & Pre == 1, comp_rate]
  cr_t_post <- comp_rates[g65 == 1 & Pre == 0, comp_rate]
  cr_c_pre  <- comp_rates[g65 == 0 & Pre == 1, comp_rate]
  cr_c_post <- comp_rates[g65 == 0 & Pre == 0, comp_rate]

  # Differential change in completion
  did_comp <- (cr_t_post - cr_t_pre) - (cr_c_post - cr_c_pre)
  cat("    DiD in completion rate:", pfmt(did_comp, 4), "\n")

  # Trimming proportion: proportion of "excess" completions to trim
  # If treatment increases completion (did_comp > 0), trim from treatment-post
  # If treatment decreases completion (did_comp < 0), trim from control-post
  p0 <- abs(did_comp)
  cat("    Trimming proportion (p0):", pfmt(p0, 4), "\n")

  # Step 3: Apply trimming and re-estimate
  # Work with completed items
  lb_comp <- lb_data[oc_item_status == 1L]

  run_lee_bound <- function(dv, trim_direction) {
    # Identify the "excess-selected" cell and trim from it
    if (did_comp > 0) {
      # Treatment increased completion → trim treatment-post
      excess_cell <- lb_comp[g65 == 1 & Pre == 0]
      other_cells <- lb_comp[!(g65 == 1 & Pre == 0)]
    } else {
      # Treatment decreased completion → trim control-post
      excess_cell <- lb_comp[g65 == 0 & Pre == 0]
      other_cells <- lb_comp[!(g65 == 0 & Pre == 0)]
    }

    n_trim <- round(nrow(excess_cell) * p0)
    if (n_trim < 1) return(NULL)

    y <- excess_cell[[dv]]
    if (trim_direction == "upper") {
      # Upper bound: trim from top (remove highest values → pushes estimate up)
      keep_idx <- order(y)[seq_len(nrow(excess_cell) - n_trim)]
    } else {
      # Lower bound: trim from bottom (remove lowest values → pushes estimate down)
      keep_idx <- order(y, decreasing = TRUE)[seq_len(nrow(excess_cell) - n_trim)]
    }

    trimmed_excess <- excess_cell[keep_idx]
    trimmed_data <- rbind(other_cells, trimmed_excess)

    fe_fml <- paste0(dv, " ~ g65_pre + convite + lquantidade | item_alt + data_oc_numb")
    feols(as.formula(fe_fml), data = trimmed_data, cluster = ~item_alt,
          fixef.rm = "none")
  }

  results <- list()
  for (dv in c("lpreco_final", "dist1")) {
    dv_label <- if (dv == "lpreco_final") "prices" else "distance"
    cat("    Lee bounds for", dv_label, "...\n")

    m_upper <- tryCatch(run_lee_bound(dv, "upper"), error = function(e) {
      cat("      WARNING: upper bound failed:", conditionMessage(e), "\n"); NULL
    })
    m_lower <- tryCatch(run_lee_bound(dv, "lower"), error = function(e) {
      cat("      WARNING: lower bound failed:", conditionMessage(e), "\n"); NULL
    })

    results[[paste0(dv_label, "_upper")]] <- m_upper
    results[[paste0(dv_label, "_lower")]] <- m_lower
  }

  results$trimming_proportion <- p0
  results$did_completion <- did_comp
  results$completion_rates <- comp_rates

  cat("    Lee bounds completed.\n")
  results
}, error = function(e) {
  cat("    ERROR in Lee bounds:", conditionMessage(e), "\n")
  NULL
})

# ============================================================================
# 3. CAUSAL FOREST — HETEROGENEOUS TREATMENT EFFECTS
# ============================================================================
cat("\n  --- Method 3: Causal Forest (grf) ---\n")

advanced$causal_forest <- tryCatch({
  suppressPackageStartupMessages(library(grf))

  # 18-month window, completed items only (price outcome)
  cf_data <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
                 oc_item_status == 1L & !is.na(lpreco_final)]

  # Covariates (pre-determined item/PBU characteristics)
  covar_names <- c("lquantidade", "convite", "same_municip", "gde_sp",
                   "fornec_estado_SP", "pbu_power", "adm_dir")

  # Step 1: Keep only covariates that exist AND have >50% non-missing
  available_covars <- character(0)
  for (v in covar_names) {
    if (v %in% names(cf_data)) {
      pct_valid <- mean(!is.na(cf_data[[v]]))
      if (pct_valid > 0.5) {
        available_covars <- c(available_covars, v)
      } else {
        cat("    Dropping", v, "(", round(pct_valid * 100, 1), "% valid)\n")
      }
    }
  }
  cat("    Available covariates:", paste(available_covars, collapse = ", "), "\n")

  if (length(available_covars) < 2) stop("Too few covariates available for causal forest")

  # Step 2: Drop rows with missing covariates
  cf_data <- cf_data[complete.cases(cf_data[, ..available_covars])]
  cat("    Observations with complete covariates:", pfmt_int(nrow(cf_data)), "\n")

  if (nrow(cf_data) < 100) stop("Too few observations after filtering")

  # Step 3: Residualize Y and W from item FE using FWL theorem (fixest::demean)
  cat("    Residualizing Y and W from item FE (FWL)...\n")
  demean_vars <- c("lpreco_final", "g65_pre", available_covars)
  demean_result <- demean(cf_data[, ..demean_vars], cf_data[["item_alt"]])
  cf_data_resid <- as.data.table(demean_result)

  # Free the large original data
  rm(cf_data)
  gc(verbose = FALSE)

  Y <- cf_data_resid[["lpreco_final"]]
  W <- cf_data_resid[["g65_pre"]]
  X <- as.matrix(cf_data_resid[, ..available_covars])

  # Step 4: Subsample if too large (>300K rows causes OOM on 15 GB)
  MAX_OBS <- 300000L
  if (length(Y) > MAX_OBS) {
    cat("    Subsampling to", pfmt_int(MAX_OBS), "observations for memory...\n")
    set.seed(42)
    idx <- sample.int(length(Y), MAX_OBS)
    Y <- Y[idx]; W <- W[idx]; X <- X[idx, , drop = FALSE]
  }

  cat("    Training causal forest (1000 trees)...\n")
  cf <- causal_forest(
    X             = X,
    Y             = Y,
    W             = W,
    num.trees     = 1000,
    min.node.size = 100,
    num.threads   = 8L,
    seed          = 42,
    honesty       = TRUE
  )

  # Variable importance
  varimp <- variable_importance(cf)
  varimp_df <- data.frame(
    variable   = available_covars,
    importance = as.numeric(varimp)
  )
  varimp_df <- varimp_df[order(-varimp_df$importance), ]
  cat("    Variable importance:\n")
  print(varimp_df, row.names = FALSE)

  # Average treatment effect
  ate <- average_treatment_effect(cf, target.sample = "all")
  cat("    ATE:", pfmt(ate[1], 4), "(SE:", pfmt(ate[2], 4), ")\n")

  # GATE by CATE quartile
  cate_pred <- predict(cf)$predictions
  cate_quartile <- cut(cate_pred,
                       breaks = quantile(cate_pred, probs = c(0, 0.25, 0.5, 0.75, 1)),
                       labels = paste0("Q", 1:4),
                       include.lowest = TRUE)

  gate_results <- data.frame(quartile = character(), estimate = numeric(),
                             se = numeric(), stringsAsFactors = FALSE)
  for (q in paste0("Q", 1:4)) {
    idx <- which(cate_quartile == q)
    gate <- average_treatment_effect(cf, target.sample = "all",
                                      subset = idx)
    gate_results <- rbind(gate_results, data.frame(
      quartile = q, estimate = gate[1], se = gate[2],
      stringsAsFactors = FALSE
    ))
  }
  cat("    GATE by quartile:\n")
  print(gate_results, row.names = FALSE)

  # Best linear projection
  blp <- tryCatch({
    best_linear_projection(cf, X)
  }, error = function(e) {
    cat("      BLP failed:", conditionMessage(e), "\n")
    NULL
  })

  # Calibration test
  cal_test <- tryCatch({
    test_calibration(cf)
  }, error = function(e) {
    cat("      Calibration test failed:", conditionMessage(e), "\n")
    NULL
  })

  cat("    Causal forest completed.\n")
  list(
    varimp      = varimp_df,
    ate         = ate,
    gate        = gate_results,
    blp         = blp,
    calibration = cal_test,
    cate_pred   = cate_pred
  )
}, error = function(e) {
  cat("    ERROR in Causal Forest:", conditionMessage(e), "\n")
  NULL
})

# Free memory after causal forest
gc(verbose = FALSE)

# ============================================================================
# 4. QUANTILE DiD — DISTRIBUTIONAL TREATMENT EFFECTS
# ============================================================================
cat("\n  --- Method 4: Quantile DiD ---\n")

advanced$quantile_did <- tryCatch({
  suppressPackageStartupMessages(library(quantreg))

  # 18-month window, completed items, log prices
  qd_data <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
                  oc_item_status == 1L &
                  !is.na(lpreco_final) & !is.na(g65_pre) &
                  !is.na(convite) & !is.na(lquantidade) & !is.na(grupo_f)]

  n_full <- nrow(qd_data)
  cat("    Full sample:", pfmt_int(n_full), "\n")

  # Canay (2011) two-step approach for quantile regression with FE:
  # Step 1: OLS with grupo_f FE → estimate group effects
  # Step 2: Subtract estimated FE from Y → run QR without dummies
  cat("    Step 1: Estimating group FE via OLS...\n")
  m_ols_fe <- feols(lpreco_final ~ g65_pre + convite + lquantidade | grupo_f,
                    data = qd_data, fixef.rm = "none", lean = FALSE)

  # Get estimated fixed effects
  fe_vals <- fixef(m_ols_fe)$grupo_f
  qd_data[, grupo_fe := fe_vals[as.character(grupo_f)]]
  qd_data[, y_tilde := lpreco_final - grupo_fe]

  # Subsample for computational feasibility
  QR_MAX <- 100000L
  if (n_full > QR_MAX) {
    set.seed(42)
    qd_data <- qd_data[sample.int(n_full, QR_MAX)]
    cat("    Subsampled to", pfmt_int(QR_MAX), "observations\n")
  }

  taus <- c(0.10, 0.25, 0.50, 0.75, 0.90)

  qd_results <- data.frame(tau = numeric(), estimate = numeric(),
                            se = numeric(), ci_lo = numeric(),
                            ci_hi = numeric(), stringsAsFactors = FALSE)

  cat("    Step 2: Quantile regressions on FE-adjusted Y...\n")
  for (tau in taus) {
    cat("    Quantile tau =", tau, "...\n")

    m_qr <- tryCatch({
      rq(y_tilde ~ g65_pre + convite + lquantidade, data = qd_data,
         tau = tau, method = "fn")
    }, error = function(e) {
      cat("      rq failed:", conditionMessage(e), "\n")
      NULL
    })

    if (is.null(m_qr)) next

    # Standard errors
    se_result <- tryCatch({
      s <- summary(m_qr, se = "nid")
      coef_tab <- coef(s)
      list(estimate = coef_tab["g65_pre", "Value"],
           se = coef_tab["g65_pre", "Std. Error"],
           ci_lo = coef_tab["g65_pre", "lower bd"],
           ci_hi = coef_tab["g65_pre", "upper bd"])
    }, error = function(e) {
      tryCatch({
        s <- summary(m_qr, se = "ker")
        coef_tab <- coef(s)
        list(estimate = coef_tab["g65_pre", "Value"],
             se = coef_tab["g65_pre", "Std. Error"],
             ci_lo = coef_tab["g65_pre", "Value"] - 1.96 * coef_tab["g65_pre", "Std. Error"],
             ci_hi = coef_tab["g65_pre", "Value"] + 1.96 * coef_tab["g65_pre", "Std. Error"])
      }, error = function(e2) {
        cat("      SE computation failed\n")
        b <- coef(m_qr)["g65_pre"]
        list(estimate = b, se = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_)
      })
    })

    qd_results <- rbind(qd_results, data.frame(
      tau      = tau,
      estimate = se_result$estimate,
      se       = se_result$se,
      ci_lo    = se_result$ci_lo,
      ci_hi    = se_result$ci_hi,
      stringsAsFactors = FALSE
    ))
  }

  # OLS benchmark (same subsample)
  cat("    OLS benchmark...\n")
  m_ols <- lm(y_tilde ~ g65_pre + convite + lquantidade, data = qd_data)
  ols_coef <- coef(m_ols)["g65_pre"]
  ols_se   <- sqrt(vcov(m_ols)["g65_pre", "g65_pre"])

  cat("    Quantile DiD completed.\n")
  cat("    OLS benchmark:", pfmt(ols_coef, 4), "(", pfmt(ols_se, 4), ")\n")

  list(
    quantile_coefs = qd_results,
    ols_coef       = ols_coef,
    ols_se         = ols_se,
    n_obs          = nrow(qd_data)
  )
}, error = function(e) {
  cat("    ERROR in Quantile DiD:", conditionMessage(e), "\n")
  NULL
})

# Free memory
gc(verbose = FALSE)

# ============================================================================
# 5. GELBACH (2016) DECOMPOSITION — MECHANISM QUANTIFICATION
# ============================================================================
cat("\n  --- Method 5: Gelbach (2016) decomposition ---\n")

advanced$gelbach <- tryCatch({
  # Gelbach decomposition compares "short" regression (only treatment) with
  # "full" regression (treatment + mediators). Decomposes the difference:
  #   β_short - β_full = Σ_k γ_k × π_k
  # where γ_k = coefficient of mediator k in full model
  #       π_k = coefficient of treatment in auxiliary regression of mediator k on treatment

  # 18-month window, completed items, all mediators non-missing
  gel_data <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
                  oc_item_status == 1L]

  # Channels (mediators)
  # (a) competition intensity: lnum_firms
  # (b) composition: sme_winner
  mediator_names <- c("lnum_firms", "sme_winner")
  mediator_labels <- c("Competition (log firms)", "Composition (SME winner)")

  # Keep only rows where all mediators are non-missing
  available_mediators <- mediator_names[mediator_names %in% names(gel_data)]
  gel_data <- gel_data[complete.cases(gel_data[, c("lpreco_final", "g65_pre",
                                                    "convite", "lquantidade",
                                                    available_mediators),
                                                with = FALSE])]
  cat("    Observations:", pfmt_int(nrow(gel_data)), "\n")
  cat("    Available mediators:", paste(available_mediators, collapse = ", "), "\n")

  # Short regression: y ~ treatment + controls | item + month FE
  cat("    Running short regression...\n")
  m_short <- feols(lpreco_final ~ g65_pre + convite + lquantidade | item_alt + data_oc_numb,
                   data = gel_data, cluster = ~item_alt, fixef.rm = "none")
  beta_short <- coef(m_short)["g65_pre"]
  se_short   <- sqrt(vcov(m_short)["g65_pre", "g65_pre"])

  # Full regression: y ~ treatment + controls + mediators | item + month FE
  mediator_str <- paste(available_mediators, collapse = " + ")
  full_fml <- paste0("lpreco_final ~ g65_pre + convite + lquantidade + ",
                     mediator_str, " | item_alt + data_oc_numb")
  cat("    Running full regression...\n")
  m_full <- feols(as.formula(full_fml), data = gel_data, cluster = ~item_alt,
                  fixef.rm = "none")
  beta_full <- coef(m_full)["g65_pre"]
  se_full   <- sqrt(vcov(m_full)["g65_pre", "g65_pre"])

  # Auxiliary regressions: mediator_k ~ treatment + controls | FE
  # π_k = coefficient on g65_pre
  decomp <- data.frame(
    channel     = character(),
    label       = character(),
    gamma       = numeric(),  # coef of mediator in full model
    gamma_se    = numeric(),
    pi          = numeric(),  # coef of treatment on mediator
    pi_se       = numeric(),
    delta       = numeric(),  # γ × π
    delta_se    = numeric(),
    pct_contrib = numeric(),
    stringsAsFactors = FALSE
  )

  total_explained <- 0
  for (i in seq_along(available_mediators)) {
    med <- available_mediators[i]
    lbl <- mediator_labels[which(mediator_names == med)]

    cat("    Auxiliary regression:", med, "...\n")

    # γ_k from full model
    gamma_k <- coef(m_full)[med]
    gamma_se_k <- sqrt(vcov(m_full)[med, med])

    # π_k: regress mediator on treatment + controls | item + month FE
    aux_fml <- paste0(med, " ~ g65_pre + convite + lquantidade | item_alt + data_oc_numb")
    m_aux <- feols(as.formula(aux_fml), data = gel_data, cluster = ~item_alt,
                   fixef.rm = "none")
    pi_k <- coef(m_aux)["g65_pre"]
    pi_se_k <- sqrt(vcov(m_aux)["g65_pre", "g65_pre"])

    # δ_k = γ_k × π_k
    delta_k <- gamma_k * pi_k

    # SE via delta method: se(δ) ≈ |π| × se(γ) + |γ| × se(π)
    # (conservative, treating as independent)
    delta_se_k <- sqrt((pi_k^2) * (gamma_se_k^2) + (gamma_k^2) * (pi_se_k^2))

    total_explained <- total_explained + delta_k

    decomp <- rbind(decomp, data.frame(
      channel     = med,
      label       = lbl,
      gamma       = gamma_k,
      gamma_se    = gamma_se_k,
      pi          = pi_k,
      pi_se       = pi_se_k,
      delta       = delta_k,
      delta_se    = delta_se_k,
      pct_contrib = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  # Direct effect (unexplained)
  direct_effect <- beta_full
  total_gap <- beta_short - beta_full

  # Percentage contributions
  if (abs(total_gap) > 1e-10) {
    decomp$pct_contrib <- decomp$delta / total_gap * 100
  }

  cat("    Short β:", pfmt(beta_short, 4), "\n")
  cat("    Full β:", pfmt(beta_full, 4), "\n")
  cat("    Gap (short - full):", pfmt(total_gap, 4), "\n")
  cat("    Decomposition:\n")
  for (i in seq_len(nrow(decomp))) {
    cat("      ", decomp$label[i], ": δ =", pfmt(decomp$delta[i], 4),
        "(", pfmt(decomp$pct_contrib[i], 1), "%)\n")
  }

  cat("    Gelbach decomposition completed.\n")
  list(
    m_short       = m_short,
    m_full        = m_full,
    beta_short    = beta_short,
    se_short      = se_short,
    beta_full     = beta_full,
    se_full       = se_full,
    decomposition = decomp,
    total_gap     = total_gap,
    direct_effect = direct_effect
  )
}, error = function(e) {
  cat("    ERROR in Gelbach decomposition:", conditionMessage(e), "\n")
  NULL
})

# ---- Save all advanced results ---------------------------------------------
advanced_path <- "/tmp/p2_advanced.rds"
saveRDS(advanced, advanced_path)
cat("\n  Advanced models saved:", advanced_path, "\n")

# Summary
cat("\n  --- Summary ---\n")
for (nm in names(advanced)) {
  status <- if (is.null(advanced[[nm]])) "FAILED" else "OK"
  cat("    ", nm, ":", status, "\n")
}

# Free memory
rm(dt, models)
gc(verbose = FALSE)
