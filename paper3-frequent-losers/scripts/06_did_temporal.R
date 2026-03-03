# ============================================================================
# 06_did_temporal.R — DiD temporal entry design
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================
# For each item_code, compute first_loser_year = min(year) where losers==1.
# Event study around FL entry. Sun & Abraham (2021) estimator for robustness.
# ============================================================================

cat("=== 06_did_temporal.R: DiD temporal design ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ---- Setup: cohort and event time -------------------------------------------

cat("  Building DiD sample...\n")

# first_loser_year was computed in 01_clean.R
# Drop items that always or never have losers (need within-item variation)
# "Always" = first_loser_year == min(year in data) AND losers==1 in all years
# "Never" = is.na(first_loser_year)

# Items with FL entry (not in first year of data, not NA)
min_year <- min(dt$year, na.rm = TRUE)
max_year <- max(dt$year, na.rm = TRUE)

# Keep items where FL first appeared AFTER the minimum year (staggered entry)
did_dt <- dt[!is.na(first_loser_year) & first_loser_year > min_year]

# Also ensure within-item variation: item must have obs both before and after entry
item_variation <- did_dt[, .(
  has_pre  = any(year < first_loser_year),
  has_post = any(year >= first_loser_year)
), by = item_code]
valid_items <- item_variation[has_pre == TRUE & has_post == TRUE, item_code]

did_dt <- did_dt[item_code %in% valid_items]
cat("  Items with staggered FL entry:", pfmt_int(length(valid_items)), "\n")
cat("  DiD sample rows:", pfmt_int(nrow(did_dt)), "\n")

# Event time
did_dt[, rel_year := year - first_loser_year]
did_dt[, cohort := first_loser_year]

# Trim to reasonable event window [-5, +5]
did_dt <- did_dt[rel_year >= -5 & rel_year <= 5]
cat("  After trimming to [-5, +5]:", pfmt_int(nrow(did_dt)), "\n")

# Check cohort distribution
cat("  Cohort distribution:\n")
cohort_tab <- did_dt[, .N, by = cohort][order(cohort)]
print(cohort_tab)

# ---- Event study regressions ------------------------------------------------

dvs <- c("lneg_price", "ln_firms", "ln_bids")
dv_labels <- c("Log Price", "Log Firms", "Log Bids")
fig_names <- c("fig_event_study_prices.pdf", "fig_event_study_nfirms.pdf",
               "fig_event_study_nbids.pdf")

es_models <- list()
es_coefs  <- list()

for (di in seq_along(dvs)) {
  dv <- dvs[di]
  dv_lbl <- dv_labels[di]
  cat(sprintf("  Event study: %s...\n", dv_lbl))

  d <- if (dv == "lneg_price") did_dt[!is.na(lneg_price)] else did_dt

  if (nrow(d) < 100) {
    cat("    Skipping: too few observations\n")
    next
  }

  # TWFE event study: y ~ i(rel_year, ref = -1) | item_f + year_f
  m_es <- feols(as.formula(paste0(dv, " ~ i(rel_year, ref = -1) | item_f + year_f")),
                data = d, cluster = ~item_f, fixef.rm = "none")
  es_models[[dv]] <- m_es

  # Extract coefficients
  cf <- as.data.table(coeftable(m_es), keep.rownames = "term")
  setnames(cf, c("term", "coef", "se", "tval", "pval"))
  # Parse rel_year from term names (e.g., "rel_year::-5")
  cf[, rel_year := as.integer(sub(".*::", "", term))]
  cf[, dv := dv_lbl]
  cf[, ci_lo := coef - 1.96 * se]
  cf[, ci_hi := coef + 1.96 * se]
  es_coefs[[dv]] <- cf

  # --- Event study figure ---
  p_es <- ggplot(cf, aes(x = rel_year, y = coef)) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
    geom_vline(xintercept = -0.5, linetype = "dashed", color = "gray70") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.2, linewidth = 0.5) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = -5:5) +
    labs(x = "Years Relative to First Loser Entry",
         y = paste("Coefficient (", dv_lbl, ")")) +
    theme_pub()

  save_pub(p_es, fig_names[di])
}

# ---- Sun & Abraham (2021) estimator ----------------------------------------

cat("  Sun & Abraham estimator...\n")

sa_models <- list()
n_cohorts <- uniqueN(did_dt$cohort)

if (n_cohorts >= 2) {
  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    d <- if (dv == "lneg_price") did_dt[!is.na(lneg_price)] else did_dt

    if (nrow(d) < 100) next

    tryCatch({
      # lean=FALSE required: summary(agg="ATT") needs stored data
      m_sa <- feols(
        as.formula(paste0(dv, " ~ sunab(cohort, year) | item_f + year_f")),
        data = d, cluster = ~item_f, fixef.rm = "none", lean = FALSE
      )
      sa_models[[dv]] <- m_sa
      cat(sprintf("    %s: SA ATT = %.4f\n", dv_labels[di],
                  summary(m_sa, agg = "ATT")$coeftable[1, 1]))
    }, error = function(e) {
      cat(sprintf("    %s: Sun & Abraham failed: %s\n", dv_labels[di], e$message))
    })
  }
} else {
  cat("    Only", n_cohorts, "cohort(s) — Sun & Abraham requires >=2. Skipped.\n")
}

# ---- DiD temporal table (pre/post coefficients) ----------------------------

cat("  Writing tab_did_temporal.tex...\n")

did_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Difference-in-Differences: Staggered Entry of Frequent Losers}",
  "\\label{tab:did_temporal}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{TWFE Event Study} & \\multicolumn{2}{c}{Sun \\& Abraham} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  "Outcome & Pre-trend (avg) & Post (avg) & ATT & SE \\\\",
  "\\midrule"
)

for (di in seq_along(dvs)) {
  dv <- dvs[di]
  dv_lbl <- dv_labels[di]

  # TWFE pre and post averages
  if (dv %in% names(es_coefs)) {
    cf <- es_coefs[[dv]]
    pre_avg  <- mean(cf[rel_year < 0, coef], na.rm = TRUE)
    post_avg <- mean(cf[rel_year >= 0, coef], na.rm = TRUE)
    pre_str  <- pfmt(pre_avg, 4)
    post_str <- pfmt(post_avg, 4)
  } else {
    pre_str  <- "---"
    post_str <- "---"
  }

  # Sun & Abraham ATT
  if (dv %in% names(sa_models)) {
    sa_sum <- summary(sa_models[[dv]], agg = "ATT")$coeftable
    sa_att <- pfmt(sa_sum[1, 1], 4)
    sa_se  <- paste0("(", pfmt(sa_sum[1, 2], 4), ")")
  } else {
    sa_att <- "---"
    sa_se  <- ""
  }

  did_lines <- c(did_lines, sprintf(
    "%s & %s & %s & %s & %s \\\\",
    dv_lbl, pre_str, post_str, sa_att, sa_se
  ))
}

did_lines <- c(did_lines,
  "\\midrule",
  sprintf("Observations & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{---} \\\\",
          pfmt_int(nrow(did_dt))),
  sprintf("Items & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{---} \\\\",
          pfmt_int(length(valid_items))),
  sprintf("Cohorts & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\",
          pfmt_int(n_cohorts), pfmt_int(n_cohorts)),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} TWFE event study with item and year fixed effects.",
  "Event window trimmed to $[-5, +5]$ years relative to first frequent loser entry.",
  "Pre-trend and Post columns report average coefficients for $t < 0$ and $t \\geq 0$.",
  "Sun \\& Abraham (2021) estimates correct for heterogeneous treatment effects",
  "across cohorts. Standard errors clustered at the item level.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(did_lines, file.path(OUT_TAB, "tab_did_temporal.tex"))

# ---- Save models -----------------------------------------------------------
saveRDS(list(es = es_models, sa = sa_models, coefs = es_coefs),
        "/tmp/p3_did_temporal.rds")
cat("  DiD temporal models saved: /tmp/p3_did_temporal.rds\n")
cat("  Done.\n")
