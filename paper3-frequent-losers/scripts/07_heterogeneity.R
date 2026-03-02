# ============================================================================
# 07_heterogeneity.R — Subgroup and heterogeneity analysis
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================
# 7.1 By item group (top 5)
# 7.2 By PBU size quartile (interaction)
# 7.3 By year (year-by-year coefficients)
# 7.4 By tender value quartile (interaction)
# 7.5 Causal forest (grf)
# ============================================================================

cat("=== 07_heterogeneity.R: Heterogeneity analysis ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

dvs <- c("lneg_price", "ln_firms", "ln_bids")
dv_labels <- c("Log Price", "Log Firms", "Log Bids")

# ============================================================================
# 7.1 By item group (top 5 groups)
# ============================================================================

cat("  7.1 Heterogeneity by item group...\n")

# Top 5 item groups by observation count
top_groups <- dt[, .N, by = item_group][order(-N)][1:5, item_group]
cat("  Top 5 item groups:", paste(top_groups, collapse = ", "), "\n")

ig_models <- list()
for (ig in top_groups) {
  d_ig <- dt[item_group == ig]
  cat(sprintf("    Group %s: N=%s\n", ig, pfmt_int(nrow(d_ig))))

  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    d <- if (dv == "lneg_price") d_ig[!is.na(lneg_price)] else d_ig

    if (nrow(d) < 100) next

    m <- tryCatch(
      feols(as.formula(paste0(dv, " ~ losers + convite | item_f + year_f + pbu_f")),
            data = d, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) NULL
    )
    if (!is.null(m)) ig_models[[paste0(ig, "_", dv)]] <- m
  }
}

# --- Write item group heterogeneity table ---
cat("  Writing tab_heterogeneity_itemgroup.tex...\n")

ig_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Heterogeneity by Item Group (Top 5)}",
  "\\label{tab:heterogeneity_itemgroup}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "Item Group & Log Price & Log Firms & Log Bids \\\\",
  "\\midrule"
)

for (ig in top_groups) {
  coefs <- character(3)
  ses   <- character(3)
  for (di in seq_along(dvs)) {
    key <- paste0(ig, "_", dvs[di])
    if (key %in% names(ig_models)) {
      m <- ig_models[[key]]
      coefs[di] <- coef_cell(m, "losers")
      ses[di]   <- se_cell(m, "losers")
    } else {
      coefs[di] <- "---"
      ses[di]   <- ""
    }
  }
  ig_lines <- c(ig_lines,
    sprintf("Group %s & %s \\\\", ig, paste(coefs, collapse = " & ")),
    sprintf(" & %s \\\\", paste(ses, collapse = " & "))
  )
}

ig_lines <- c(ig_lines,
  "\\midrule",
  "Item FE & YES & YES & YES \\\\",
  "Year FE & YES & YES & YES \\\\",
  "PBU FE & YES & YES & YES \\\\",
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Each cell reports the coefficient on \\textit{losers}",
  "from a separate regression estimated on the subsample of the indicated item group.",
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(ig_lines, file.path(OUT_TAB, "tab_heterogeneity_itemgroup.tex"))

# ============================================================================
# 7.2 By PBU size quartile (interaction)
# ============================================================================

cat("  7.2 PBU size interaction...\n")

pbu_models <- list()
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price) & !is.na(pbu_size_q)] else
    dt[!is.na(pbu_size_q)]

  if (nrow(d) < 100) next

  m <- feols(as.formula(paste0(dv, " ~ losers * factor(pbu_size_q) + convite | item_f + year_f")),
             data = d, cluster = ~item_f, fixef.rm = "none")
  pbu_models[[dv]] <- m
}

# ============================================================================
# 7.3 By year (year-by-year coefficients)
# ============================================================================

cat("  7.3 Year-by-year coefficients...\n")

year_models <- list()
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt

  m <- feols(as.formula(paste0(dv, " ~ i(year_f, losers) + convite | item_f + year_f")),
             data = d, cluster = ~item_f, fixef.rm = "none")
  year_models[[dv]] <- m
}

# --- Year coefficients figure ---
cat("  Generating fig_year_coefficients.pdf...\n")

yr_coefs <- list()
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  if (!(dv %in% names(year_models))) next
  m <- year_models[[dv]]

  cf <- as.data.table(coeftable(m), keep.rownames = "term")
  setnames(cf, c("term", "coef", "se", "tval", "pval"))
  # Parse year from term (e.g., "year_f::2010:losers")
  cf <- cf[grepl("losers", term)]
  cf[, yr := as.integer(sub("year_f::(\\d+):losers", "\\1", term))]
  cf[, dv := dv_labels[di]]
  cf[, ci_lo := coef - 1.96 * se]
  cf[, ci_hi := coef + 1.96 * se]
  yr_coefs[[dv]] <- cf
}

yr_all <- rbindlist(yr_coefs)

if (nrow(yr_all) > 0) {
  p_yr <- ggplot(yr_all, aes(x = yr, y = coef, shape = dv)) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi),
                  width = 0.3, linewidth = 0.4,
                  position = position_dodge(width = 0.5)) +
    geom_point(size = 2, position = position_dodge(width = 0.5)) +
    scale_shape_manual(values = c("Log Price" = 16, "Log Firms" = 17, "Log Bids" = 15)) +
    labs(x = "Year", y = "Coefficient on Losers") +
    theme_pub()

  save_pub(p_yr, "fig_year_coefficients.pdf")
}

# ============================================================================
# 7.4 By tender value quartile (interaction)
# ============================================================================

cat("  7.4 Tender value interaction...\n")

tv_models <- list()
for (di in seq_along(dvs)) {
  dv <- dvs[di]
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price) & !is.na(tender_value_q)] else
    dt[!is.na(tender_value_q)]

  if (nrow(d) < 100) next

  m <- feols(as.formula(paste0(dv, " ~ losers * factor(tender_value_q) + convite | item_f + year_f")),
             data = d, cluster = ~item_f, fixef.rm = "none")
  tv_models[[dv]] <- m
}

# ============================================================================
# 7.5 Causal forest (grf)
# ============================================================================

cat("  7.5 Causal forest...\n")

if (requireNamespace("grf", quietly = TRUE)) {
  library(grf)

  # Prepare data for causal forest
  d_cf <- dt[!is.na(lneg_price) & !is.na(pbu_size_q) & !is.na(tender_value_q)]
  cat(sprintf("    Causal forest sample: %s rows\n", pfmt_int(nrow(d_cf))))

  # Covariates
  X <- as.matrix(d_cf[, .(n_firms, year, pbu_size_q, tender_value_q, convite)])
  Y <- d_cf$lneg_price
  W <- as.numeric(d_cf$losers)

  # Subsample if too large (grf is memory-intensive)
  max_n <- 500000L
  if (length(Y) > max_n) {
    set.seed(42)
    idx <- sample(length(Y), max_n)
    X <- X[idx, ]
    Y <- Y[idx]
    W <- W[idx]
    cat(sprintf("    Subsampled to %s rows for grf\n", pfmt_int(max_n)))
  }

  cf_model <- tryCatch({
    causal_forest(X = X, Y = Y, W = W, num.trees = 2000, seed = 42)
  }, error = function(e) {
    cat(sprintf("    Causal forest failed: %s\n", e$message))
    NULL
  })

  if (!is.null(cf_model)) {
    ate <- average_treatment_effect(cf_model)
    cat(sprintf("    ATE: %.4f (SE: %.4f)\n", ate[1], ate[2]))

    # Variable importance
    vimp <- variable_importance(cf_model)
    vimp_df <- data.table(
      variable = c("n_firms", "year", "pbu_size_q", "tender_value_q", "convite"),
      importance = as.numeric(vimp)
    )
    vimp_df <- vimp_df[order(-importance)]

    # --- Variable importance figure ---
    cat("  Generating fig_cate_varimp.pdf...\n")
    p_vimp <- ggplot(vimp_df, aes(x = reorder(variable, importance), y = importance)) +
      geom_col(fill = "gray50") +
      coord_flip() +
      labs(x = NULL, y = "Variable Importance") +
      theme_pub()

    save_pub(p_vimp, "fig_cate_varimp.pdf")
  }
} else {
  cat("    Package 'grf' not installed. Skipping causal forest.\n")
  cat("    Install with: install.packages('grf')\n")
}

# ============================================================================
# Combined heterogeneity table
# ============================================================================

cat("  Writing tab_heterogeneity.tex...\n")

het_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Heterogeneity Analysis: Interaction Effects}",
  "\\label{tab:heterogeneity}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  "Specification & Coefficient & SE \\\\",
  "\\midrule",
  "\\textit{Panel A: PBU Size Interactions (Log Price)} & & \\\\"
)

# PBU size interaction coefficients
if ("lneg_price" %in% names(pbu_models)) {
  m <- pbu_models[["lneg_price"]]
  cf <- as.data.table(coeftable(m), keep.rownames = "term")
  setnames(cf, c("term", "coef", "se", "tval", "pval"))
  # Report losers main effect and interaction terms
  for (i in seq_len(nrow(cf))) {
    if (grepl("losers", cf$term[i])) {
      p <- cf$pval[i]
      het_lines <- c(het_lines, sprintf(
        "\\quad %s & %s%s & (%s) \\\\",
        gsub("_", "\\\\_", cf$term[i]),
        pfmt(cf$coef[i], 4), pstars(p), pfmt(cf$se[i], 4)
      ))
    }
  }
}

het_lines <- c(het_lines,
  "[6pt]",
  "\\textit{Panel B: Tender Value Interactions (Log Price)} & & \\\\"
)

if ("lneg_price" %in% names(tv_models)) {
  m <- tv_models[["lneg_price"]]
  cf <- as.data.table(coeftable(m), keep.rownames = "term")
  setnames(cf, c("term", "coef", "se", "tval", "pval"))
  for (i in seq_len(nrow(cf))) {
    if (grepl("losers", cf$term[i])) {
      p <- cf$pval[i]
      het_lines <- c(het_lines, sprintf(
        "\\quad %s & %s%s & (%s) \\\\",
        gsub("_", "\\\\_", cf$term[i]),
        pfmt(cf$coef[i], 4), pstars(p), pfmt(cf$se[i], 4)
      ))
    }
  }
}

het_lines <- c(het_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Panel A interacts \\textit{losers} with PBU size quartiles",
  "(1=smallest, 4=largest by tender count). Panel B interacts with tender value quartiles.",
  "All specifications include item and year FE. Standard errors clustered at the item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(het_lines, file.path(OUT_TAB, "tab_heterogeneity.tex"))

# --- Combined heterogeneity coefficient plot ---
cat("  Generating fig_heterogeneity_coef.pdf...\n")

# Collect coefficients from item group analysis
het_coefs <- list()
for (ig in top_groups) {
  key <- paste0(ig, "_lneg_price")
  if (key %in% names(ig_models)) {
    m <- ig_models[[key]]
    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    het_coefs <- c(het_coefs, list(data.table(
      group = paste0("Item Group ", ig), coef = b, se = se,
      ci_lo = b - 1.96 * se, ci_hi = b + 1.96 * se
    )))
  }
}

het_df <- rbindlist(het_coefs)

if (nrow(het_df) > 0) {
  p_het <- ggplot(het_df, aes(x = coef, y = reorder(group, coef))) +
    geom_vline(xintercept = 0, linetype = "dotted", color = "gray50") +
    geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), width = 0.2, linewidth = 0.5) +
    geom_point(size = 2.5) +
    labs(x = "Coefficient on Losers (log price)", y = NULL) +
    theme_pub()

  save_pub(p_het, "fig_heterogeneity_coef.pdf")
}

# ---- Save models -----------------------------------------------------------
het_models <- list(
  item_group = ig_models,
  pbu_size   = pbu_models,
  year       = year_models,
  tender_val = tv_models
)
saveRDS(het_models, "/tmp/p3_heterogeneity.rds")
cat("  Heterogeneity models saved: /tmp/p3_heterogeneity.rds\n")
cat("  Done.\n")
