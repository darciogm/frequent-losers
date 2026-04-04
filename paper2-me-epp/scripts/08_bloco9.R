# ============================================================================
# 08_bloco9.R — Additional robustness: exclude last post-period, balance test,
#               wild cluster bootstrap
# ============================================================================

cat("=== 08_bloco9.R: Bloco 9 additional analyses ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ============================================================================
# 1. EXCLUDE LAST POST-PERIOD ROBUSTNESS
# ============================================================================
cat("\n  --- Exclude last post-period (Mar-Aug 2019) ---\n")

# The last semester (Mar19-Aug19, Stata dates 710-715) shows a positive drift
# in the event study. We re-estimate the 18-month spec excluding this semester.
# New 18-month window: [680, 709] instead of [680, 715]
WIN_18M_EXCL <- c(680L, 709L)

excl_models <- list()

dvs_excl <- list(
  list(dv = "lpreco_final", completed = TRUE,  label = "prices"),
  list(dv = "lnum_firms",   completed = FALSE, label = "firms"),
  list(dv = "lnum_bids",    completed = FALSE, label = "bids"),
  list(dv = "dist1",        completed = TRUE,  label = "distance")
)

for (v in dvs_excl) {
  cat("    ", v$label, "...\n")
  excl_models[[paste0(v$label, "_base")]] <-
    run_didir(v$dv, dt, WIN_18M_EXCL, add_pbu = FALSE, completed = v$completed)
  excl_models[[paste0(v$label, "_pbu")]] <-
    run_didir(v$dv, dt, WIN_18M_EXCL, add_pbu = TRUE, completed = v$completed)
}

# ---- Generate Table: Exclude Last Post-Period --------------------------------
cat("  Generating tab_excl_lastpost.tex...\n")

make_excl_table <- function(models) {
  header <- paste0(
    "\\begin{table}[htbp]\n",
    "\\centering\n",
    "\\caption{Robustness: Excluding Last Post-Period Semester (Mar--Aug 2019)}\n",
    "\\label{tab:excl_lastpost}\n",
    "\\begin{adjustbox}{max width=\\textwidth}\n",
    "\\begin{threeparttable}\n",
    "\\small\n",
    "\\begin{tabular}{lcccccccc}\n",
    "\\toprule\n",
    " & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Log firms} ",
    "& \\multicolumn{2}{c}{Log bids} & \\multicolumn{2}{c}{Distance} \\\\\n",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7} \\cmidrule(lr){8-9}\n",
    " & Base & PBU FE & Base & PBU FE & Base & PBU FE & Base & PBU FE \\\\\n",
    "\\midrule\n"
  )

  var <- "g65_pre"
  cells <- character(8)
  se_row <- character(8)
  n_row <- character(8)
  r2_row <- character(8)

  mnames <- c("prices_base", "prices_pbu", "firms_base", "firms_pbu",
              "bids_base", "bids_pbu", "distance_base", "distance_pbu")

  for (i in seq_along(mnames)) {
    m <- models[[mnames[i]]]
    cells[i] <- coef_cell(m, var, 4)
    se_row[i] <- se_cell(m, var, 4)
    n_row[i] <- pfmt_int(nobs(m))
    r2_row[i] <- pfmt(fitstat(m, "r2")$r2, 4)
  }

  body <- paste0(
    "$g65 \\times Pre$ & ", paste(cells, collapse = " & "), " \\\\\n",
    " & ", paste(se_row, collapse = " & "), " \\\\\n",
    "\\midrule\n",
    "Observations & ", paste(n_row, collapse = " & "), " \\\\\n",
    "$R^2$ & ", paste(r2_row, collapse = " & "), " \\\\\n"
  )

  footer <- paste0(
    "\\bottomrule\n",
    "\\end{tabular}\n",
    "\\begin{tablenotes}\n",
    "\\small\n",
    "\\item \\textit{Notes:} Re-estimation of the 18-month window specification ",
    "excluding the final post-period semester (March--August 2019). ",
    "The effective window is September 2016 to February 2019. ",
    "Standard errors clustered at the item level in parentheses. ",
    "* $p<0.10$, ** $p<0.05$, *** $p<0.01$.\n",
    "\\end{tablenotes}\n",
    "\\end{threeparttable}\n",
    "\\end{adjustbox}\n",
    "\\end{table}\n"
  )

  paste0(header, body, footer)
}

writeLines(make_excl_table(excl_models), file.path(OUT_TAB, "tab_excl_lastpost.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_excl_lastpost.tex"), "\n")

# ============================================================================
# 2. BALANCE TEST — PRE-TREATMENT COVARIATE COMPARISON
# ============================================================================
cat("\n  --- Balance test: pre-treatment covariates ---\n")

# Compare group 65 vs others in the pre-period on observable characteristics
pre_dt <- dt[Pre == 1L]

# Covariates to compare
balance_vars <- list(
  list(var = "lquantidade",     label = "Log quantity",            all = TRUE),
  list(var = "convite",         label = "Sealed bid (share)",      all = TRUE),
  list(var = "completed_binary",label = "Completion rate",         all = TRUE),
  list(var = "num_firms",       label = "Number of firms",         all = TRUE),
  list(var = "num_bids",        label = "Number of valid bids",    all = TRUE),
  list(var = "preco_final",     label = "Price (levels)",          all = FALSE)
)

if ("dist1" %in% names(pre_dt))
  balance_vars <- c(balance_vars, list(list(var = "dist1", label = "Distance (km)", all = FALSE)))

balance_rows <- list()

for (bv in balance_vars) {
  v <- bv$var
  if (!(v %in% names(pre_dt))) next

  sub <- if (bv$all) pre_dt[!is.na(get(v))] else pre_dt[oc_item_status == 1L & !is.na(get(v))]

  g65_vals  <- sub[g65 == 1L, get(v)]
  oth_vals  <- sub[g65 == 0L, get(v)]

  mean_g65  <- mean(g65_vals, na.rm = TRUE)
  mean_oth  <- mean(oth_vals, na.rm = TRUE)
  sd_g65    <- sd(g65_vals, na.rm = TRUE)
  sd_oth    <- sd(oth_vals, na.rm = TRUE)
  diff      <- mean_g65 - mean_oth

  # Welch t-test
  tt <- tryCatch(t.test(g65_vals, oth_vals), error = function(e) NULL)
  pval <- if (!is.null(tt)) tt$p.value else NA_real_

  balance_rows[[v]] <- data.frame(
    label    = bv$label,
    mean_g65 = mean_g65,
    sd_g65   = sd_g65,
    mean_oth = mean_oth,
    sd_oth   = sd_oth,
    diff     = diff,
    pval     = pval,
    stringsAsFactors = FALSE
  )
}

bal_df <- do.call(rbind, balance_rows)

# ---- Generate Balance Table --------------------------------------------------
cat("  Generating tab_balance.tex...\n")

make_balance_table <- function(df) {
  header <- paste0(
    "\\begin{table}[htbp]\n",
    "\\centering\n",
    "\\caption{Balance Test: Pre-Treatment Covariate Means by Group}\n",
    "\\label{tab:balance}\n",
    "\\begin{adjustbox}{max width=\\textwidth}\n",
    "\\begin{threeparttable}\n",
    "\\small\n",
    "\\begin{tabular}{lcccccc}\n",
    "\\toprule\n",
    " & \\multicolumn{2}{c}{Group 65} & \\multicolumn{2}{c}{Other Groups} & & \\\\\n",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}\n",
    " & Mean & SD & Mean & SD & Difference & $p$-value \\\\\n",
    "\\midrule\n"
  )

  body <- ""
  for (i in seq_len(nrow(df))) {
    r <- df[i, ]
    stars <- pstars(r$pval)
    body <- paste0(body,
      r$label, " & ",
      pfmt(r$mean_g65, 2), " & ",
      pfmt(r$sd_g65, 2), " & ",
      pfmt(r$mean_oth, 2), " & ",
      pfmt(r$sd_oth, 2), " & ",
      pfmt(r$diff, 3), stars, " & ",
      pfmt(r$pval, 3), " \\\\\n"
    )
  }

  footer <- paste0(
    "\\bottomrule\n",
    "\\end{tabular}\n",
    "\\begin{tablenotes}\n",
    "\\small\n",
    "\\item \\textit{Notes:} Pre-treatment period means (September 2016 to February 2018) ",
    "for Group 65 and all other groups. Difference = Group 65 $-$ Others. ",
    "$p$-values from Welch two-sample $t$-tests. ",
    "Price and distance are conditional on item completion. ",
    "* $p<0.10$, ** $p<0.05$, *** $p<0.01$.\n",
    "\\end{tablenotes}\n",
    "\\end{threeparttable}\n",
    "\\end{adjustbox}\n",
    "\\end{table}\n"
  )

  paste0(header, body, footer)
}

writeLines(make_balance_table(bal_df), file.path(OUT_TAB, "tab_balance.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_balance.tex"), "\n")

# ============================================================================
# 3. PAIRS CLUSTER BOOTSTRAP (group-level, 76 clusters)
# ============================================================================
cat("\n  --- Pairs cluster bootstrap (group level, 76 clusters) ---\n")

# Since fwildclusterboot is not available for this R version, we implement
# a pairs cluster bootstrap: resample entire groups with replacement,
# re-estimate, and collect the distribution of coefficients.

# Since fwildclusterboot is not available for this R version, we use
# a score cluster bootstrap (Kline & Santos 2012): fast, no re-estimation.
# Resample Rademacher weights at the group level, multiply scores, re-form t-stat.

N_BOOT <- 9999L
set.seed(42)

run_score_boot <- function(dv, data, window, completed = FALSE) {
  sub <- data[data_oc_numb >= window[1] & data_oc_numb <= window[2]]
  if (completed) sub <- sub[oc_item_status == 1L]
  sub[, grupo_f := factor(codigogrupo)]

  # Pre-filter NAs so residual length matches data length
  vars_needed <- c(dv, "g65_pre", "convite", "lquantidade", "item_alt", "grupo_f")
  sub <- sub[complete.cases(sub[, ..vars_needed])]

  fml <- as.formula(paste0(dv, " ~ g65_pre + convite + lquantidade | item_alt"))
  orig <- feols(fml, data = sub, cluster = ~grupo_f, fixef.rm = "none", lean = FALSE)
  orig_coef <- coef(orig)["g65_pre"]
  orig_se   <- sqrt(vcov(orig)["g65_pre", "g65_pre"])
  orig_tstat <- orig_coef / orig_se

  # Get group-level scores (influence function)
  group_ids <- levels(droplevels(sub$grupo_f))
  n_groups  <- length(group_ids)

  resids <- residuals(orig)
  g65_pre_vals <- sub$g65_pre
  group_idx <- as.integer(factor(sub$grupo_f, levels = group_ids))
  score_sums <- tapply(resids * g65_pre_vals, group_idx, sum)

  # Bootstrap: Rademacher weights at group level
  boot_tstats <- numeric(N_BOOT)
  for (b in seq_len(N_BOOT)) {
    weights <- sample(c(-1, 1), n_groups, replace = TRUE)
    # Perturbed score sum
    perturbed <- sum(weights * score_sums)
    # Bootstrap SE estimate: just the SD of weighted score sums
    boot_var <- sum((weights * score_sums)^2)
    boot_tstats[b] <- perturbed / sqrt(boot_var)
  }

  # Bootstrap p-value: fraction of |t*| >= |t_obs|
  boot_pval <- mean(abs(boot_tstats) >= abs(orig_tstat))

  # Confidence interval via inversion (percentile-t)
  boot_se <- orig_se  # Use analytical SE for CI
  t_crit <- quantile(abs(boot_tstats), 0.95)
  boot_ci <- c(orig_coef - t_crit * orig_se, orig_coef + t_crit * orig_se)

  list(
    coef = orig_coef,
    se_group = orig_se,
    boot_pval = boot_pval,
    boot_ci = as.numeric(boot_ci),
    n = nobs(orig),
    n_boot = N_BOOT
  )
}

wcb_results_all <- list()

pcb_specs <- list(
  list(dv = "lpreco_final", completed = TRUE,  label = "prices"),
  list(dv = "lnum_firms",   completed = FALSE, label = "firms"),
  list(dv = "lnum_bids",    completed = FALSE, label = "bids"),
  list(dv = "dist1",        completed = TRUE,  label = "distance")
)

for (sp in pcb_specs) {
  cat("  Score bootstrap for", sp$label, "...\n")
  res <- tryCatch(
    run_score_boot(sp$dv, dt, WIN_18M, completed = sp$completed),
    error = function(e) { cat("    Error:", conditionMessage(e), "\n"); NULL }
  )
  if (!is.null(res)) {
    wcb_results_all[[sp$label]] <- res
    cat("    coef:", pfmt(res$coef, 4),
        " group SE:", pfmt(res$se_group, 4),
        " boot p:", pfmt(res$boot_pval, 4),
        " CI: [", pfmt(res$boot_ci[1], 4), ",", pfmt(res$boot_ci[2], 4), "]\n")
  }
}

# ---- Generate WCB Table -----------------------------------------------------
if (length(wcb_results_all) > 0) {
  cat("  Generating tab_wcb.tex...\n")

  make_wcb_table <- function(results) {
    header <- paste0(
      "\\begin{table}[htbp]\n",
      "\\centering\n",
      "\\caption{Score Cluster Bootstrap Inference (Group-Level, 76 Clusters)}\n",
      "\\label{tab:wcb}\n",
      "\\begin{adjustbox}{max width=\\textwidth}\n",
      "\\begin{threeparttable}\n",
      "\\small\n",
      "\\begin{tabular}{lcccc}\n",
      "\\toprule\n",
      " & Log prices & Log firms & Log bids & Distance \\\\\n",
      "\\midrule\n"
    )

    outcomes <- c("prices", "firms", "bids", "distance")
    coef_cells <- se_cells <- bse_cells <- pval_cells <- ci_cells <- n_cells <- character(4)

    for (i in seq_along(outcomes)) {
      r <- results[[outcomes[i]]]
      if (is.null(r)) {
        coef_cells[i] <- se_cells[i] <- bse_cells[i] <- pval_cells[i] <- ci_cells[i] <- n_cells[i] <- "---"
      } else {
        stars <- pstars(r$boot_pval)
        coef_cells[i] <- paste0(pfmt(r$coef, 4), stars)
        se_cells[i] <- paste0("(", pfmt(r$se_group, 4), ")")
        bse_cells[i] <- ""
        pval_cells[i] <- pfmt(r$boot_pval, 4)
        ci_cells[i] <- paste0("[", pfmt(r$boot_ci[1], 4), ", ", pfmt(r$boot_ci[2], 4), "]")
        n_cells[i] <- pfmt_int(r$n)
      }
    }

    body <- paste0(
      "$g65 \\times Pre$ & ", paste(coef_cells, collapse = " & "), " \\\\\n",
      "Group-clustered SE & ", paste(se_cells, collapse = " & "), " \\\\\n",
      "Bootstrap $p$-value & ", paste(pval_cells, collapse = " & "), " \\\\\n",
      "Bootstrap 95\\% CI & ", paste(ci_cells, collapse = " & "), " \\\\\n",
      "\\midrule\n",
      "Observations & ", paste(n_cells, collapse = " & "), " \\\\\n"
    )

    footer <- paste0(
      "\\bottomrule\n",
      "\\end{tabular}\n",
      "\\begin{tablenotes}\n",
      "\\small\n",
      "\\item \\textit{Notes:} 18-month window, baseline specification (item FE). ",
      "Analytical standard errors clustered at the item-group level (76 clusters) in parentheses. ",
      "Score cluster bootstrap with Rademacher weights and ", N_BOOT, " replications ",
      "\\citep{cameron2008}. $p$-values from the bootstrap $t$-distribution; ",
      "confidence intervals by percentile-$t$ inversion. ",
      "* $p<0.10$, ** $p<0.05$, *** $p<0.01$.\n",
      "\\end{tablenotes}\n",
      "\\end{threeparttable}\n",
      "\\end{adjustbox}\n",
      "\\end{table}\n"
    )

    paste0(header, body, footer)
  }

  writeLines(make_wcb_table(wcb_results_all), file.path(OUT_TAB, "tab_wcb.tex"))
  cat("  Saved:", file.path(OUT_TAB, "tab_wcb.tex"), "\n")
}

# ---- Save all results -------------------------------------------------------
bloco9_path <- "/tmp/p2_bloco9.rds"
saveRDS(list(excl_models = excl_models,
             balance = bal_df,
             wcb = wcb_results_all),
        bloco9_path)
cat("\n  All Bloco 9 results saved:", bloco9_path, "\n")

# Free memory
rm(dt, pre_dt, wcb_sub, wcb_sub_all)
gc(verbose = FALSE)

cat("=== 08_bloco9.R: Done ===\n")
