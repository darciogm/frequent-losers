# ============================================================================
# 17_stacked_did.R — Stacked Regression (Cengiz et al. 2019)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Implements stacked DiD to avoid the "bad comparison" problem in staggered
# designs. Each cohort-year gets its own sub-experiment with never-treated
# controls and cohort-specific FE. Compares with Callaway & Sant'Anna ATT
# from 08_did_revised.R.
# ============================================================================

cat("=== 17_stacked_did.R: Stacked DiD (Cengiz et al.) ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

# ============================================================================
# Phase 1: Construct market-level panel (same as 08_did_revised.R)
# ============================================================================

cat("  Phase 1: Building market-level panel...\n")

panel <- dt[, .(
  log_price       = mean(lneg_price, na.rm = TRUE),
  log_nfirms_excl = mean(ln_firms_excl, na.rm = TRUE),
  n_tenders       = .N,
  cover_tender    = max(losers)
), by = .(market_id, year)]

fly <- dt[losers == 1, .(first_fl_year = min(year)), by = market_id]
panel <- merge(panel, fly, by = "market_id", all.x = TRUE)
panel[is.na(first_fl_year), first_fl_year := 0L]

# Restriction: >= 3 pre AND >= 3 post observations (matching 08_did_revised.R)
panel[, rel_year := fifelse(first_fl_year > 0, year - first_fl_year, NA_integer_)]

treated_counts <- panel[first_fl_year > 0, .(
  n_pre  = sum(rel_year < 0, na.rm = TRUE),
  n_post = sum(rel_year >= 0, na.rm = TRUE)
), by = market_id]
valid_treated <- treated_counts[n_pre >= 3 & n_post >= 3, market_id]

never_treated_counts <- panel[first_fl_year == 0, .N, by = market_id]
valid_never <- never_treated_counts[N >= 6, market_id]

panel_rest <- panel[market_id %in% c(valid_treated, valid_never)]
market_years <- panel_rest[, .N, by = market_id]
panel_rest <- panel_rest[market_id %in% market_years[N >= 2, market_id]]

n_treated <- uniqueN(panel_rest[first_fl_year > 0, market_id])
n_control <- uniqueN(panel_rest[first_fl_year == 0, market_id])
cat(sprintf("  Panel: %s rows, %s markets (%s treated, %s never-treated)\n",
            pfmt_int(nrow(panel_rest)), pfmt_int(uniqueN(panel_rest$market_id)),
            pfmt_int(n_treated), pfmt_int(n_control)))

# ============================================================================
# Phase 2: Build stacked dataset
# ============================================================================

cat("  Phase 2: Building stacked dataset...\n")

EVENT_WINDOW <- 5L  # symmetric ±5 years around treatment
cohorts <- sort(unique(panel_rest[first_fl_year > 0, first_fl_year]))
cat(sprintf("  Cohorts: %s (years %d-%d)\n", pfmt_int(length(cohorts)),
            min(cohorts), max(cohorts)))

# Never-treated pool
never_panel <- panel_rest[first_fl_year == 0]

stacked_list <- vector("list", length(cohorts))

for (ci in seq_along(cohorts)) {
  g <- cohorts[ci]

  # Treated markets in this cohort
  cohort_treated <- panel_rest[first_fl_year == g &
                                 year >= (g - EVENT_WINDOW) &
                                 year <= (g + EVENT_WINDOW)]
  if (nrow(cohort_treated) < 10) next

  # Never-treated in the same year window
  cohort_control <- never_panel[year >= (g - EVENT_WINDOW) &
                                  year <= (g + EVENT_WINDOW)]

  # Stack
  sub <- rbind(cohort_treated, cohort_control)
  sub[, cohort_id := g]
  sub[, treat_post := as.integer(first_fl_year == g & year >= g)]
  sub[, rel_year_stacked := year - g]

  stacked_list[[ci]] <- sub
}

stacked <- rbindlist(stacked_list[!sapply(stacked_list, is.null)])

# Create cohort-specific identifiers for FE
stacked[, market_cohort := paste0(market_id, "_", cohort_id)]
stacked[, market_cohort_f := as.integer(factor(market_cohort))]
stacked[, year_cohort_f := as.integer(factor(paste0(year, "_", cohort_id)))]

cat(sprintf("  Stacked dataset: %s rows, %s cohorts, %s market-cohort units\n",
            pfmt_int(nrow(stacked)),
            pfmt_int(uniqueN(stacked$cohort_id)),
            pfmt_int(uniqueN(stacked$market_cohort))))

# ============================================================================
# Phase 3: Estimate stacked ATT
# ============================================================================

cat("  Phase 3: Stacked regression...\n")

dvs <- c("log_price", "log_nfirms_excl")
dv_labels <- c("Log Price", "Log Firms (excl. FL)")

stacked_models <- list()
stacked_atts <- list()

for (di in seq_along(dvs)) {
  dv <- dvs[di]; dv_lbl <- dv_labels[di]
  d <- stacked[!is.na(get(dv))]
  if (nrow(d) < 100) {
    cat(sprintf("    %s: insufficient data, skipping\n", dv_lbl))
    next
  }

  # Main stacked ATT: treat_post with cohort-specific market and year FE
  m <- tryCatch(
    feols(as.formula(paste0(dv, " ~ treat_post | market_cohort_f + year_cohort_f")),
          data = d, cluster = ~market_id),
    error = function(e) { cat(sprintf("    %s failed: %s\n", dv_lbl, e$message)); NULL }
  )

  if (!is.null(m)) {
    b <- coef(m)["treat_post"]
    se <- sqrt(vcov(m)["treat_post", "treat_post"])
    p <- 2 * pnorm(-abs(b / se))
    stacked_models[[dv]] <- m
    stacked_atts[[dv]] <- list(att = b, se = se, pval = p, n = m$nobs)
    cat(sprintf("    %s: ATT = %.4f (SE = %.4f, p = %.4f)\n", dv_lbl, b, se, p))
  }
}

# ============================================================================
# Phase 4: Stacked event study
# ============================================================================

cat("  Phase 4: Stacked event study...\n")

stacked_es_coefs <- list()

for (di in seq_along(dvs)) {
  dv <- dvs[di]; dv_lbl <- dv_labels[di]
  d <- stacked[!is.na(get(dv)) & first_fl_year > 0]  # treated only for ES
  if (nrow(d) < 100) next

  d[, market_f := factor(market_id)]
  d[, year_f := factor(year)]

  m_es <- tryCatch(
    feols(as.formula(paste0(dv, " ~ i(rel_year_stacked, ref = -1) | market_cohort_f + year_cohort_f")),
          data = stacked[!is.na(get(dv))], cluster = ~market_id),
    error = function(e) NULL
  )

  if (!is.null(m_es)) {
    cf <- as.data.table(coeftable(m_es), keep.rownames = "term")
    setnames(cf, c("term", "coef", "se", "tval", "pval"))
    cf[, rel_year := as.integer(sub(".*::", "", term))]
    cf[, dv := dv_lbl]
    cf[, ci_lo := coef - 1.96 * se]
    cf[, ci_hi := coef + 1.96 * se]
    stacked_es_coefs[[dv]] <- cf
  }
}

# ============================================================================
# Phase 5: Comparison with C&S
# ============================================================================

cat("  Phase 5: Comparison with C&S...\n")

cs_comparison <- NULL
if (file.exists(DID_CACHE_V4)) {
  did_res <- readRDS(DID_CACHE_V4)
  cs_comparison <- list()
  for (dv in names(stacked_atts)) {
    cs_att <- NA; cs_se <- NA
    if (dv %in% names(did_res$callaway_santanna) &&
        !is.null(did_res$callaway_santanna[[dv]]$att_overall)) {
      cs_att <- did_res$callaway_santanna[[dv]]$att_overall$overall.att
      cs_se  <- did_res$callaway_santanna[[dv]]$att_overall$overall.se
    }
    cs_comparison[[dv]] <- data.table(
      dv = dv,
      stacked_att = stacked_atts[[dv]]$att,
      stacked_se  = stacked_atts[[dv]]$se,
      cs_att = cs_att,
      cs_se  = cs_se
    )
    cat(sprintf("    %s: Stacked=%.4f vs C&S=%.4f\n", dv,
                stacked_atts[[dv]]$att, cs_att))
  }
  cs_comparison <- rbindlist(cs_comparison)
}

# ============================================================================
# Phase 6: Write tab_stacked_did.tex
# ============================================================================

cat("  Phase 6: Writing tab_stacked_did.tex...\n")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Stacked DiD vs.\\ Callaway \\& Sant'Anna}",
  "\\label{tab:stacked_did}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & \\multicolumn{2}{c}{Stacked (Cengiz et al.)} & \\multicolumn{2}{c}{C\\&S (2021)} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  "Outcome & ATT & SE & ATT & SE \\\\", "\\midrule"
)

for (di in seq_along(dvs)) {
  dv <- dvs[di]; dv_lbl <- dv_labels[di]

  s_att <- "---"; s_se <- ""
  if (dv %in% names(stacked_atts)) {
    s_att <- paste0(pfmt(stacked_atts[[dv]]$att, 4), pstars(stacked_atts[[dv]]$pval))
    s_se <- sprintf("(%s)", pfmt(stacked_atts[[dv]]$se, 4))
  }

  c_att <- "---"; c_se <- ""
  if (!is.null(cs_comparison) && dv %in% cs_comparison$dv) {
    row <- cs_comparison[dv == (dvs[di])]
    if (!is.na(row$cs_att)) {
      c_att <- pfmt(row$cs_att, 4)
      c_se <- sprintf("(%s)", pfmt(row$cs_se, 4))
    }
  }

  lines <- c(lines,
    sprintf("%s & %s & %s & %s & %s \\\\", dv_lbl, s_att, s_se, c_att, c_se))
}

lines <- c(lines, "\\midrule",
  sprintf("Stacked obs. & \\multicolumn{4}{c}{%s} \\\\", pfmt_int(nrow(stacked))),
  sprintf("Cohorts & \\multicolumn{4}{c}{%s} \\\\", pfmt_int(uniqueN(stacked$cohort_id))),
  sprintf("Event window & \\multicolumn{4}{c}{$\\pm$%d years} \\\\", EVENT_WINDOW),
  "Cohort $\\times$ Market FE & YES & & --- & \\\\",
  "Cohort $\\times$ Year FE & YES & & --- & \\\\",
  "Clustering & \\multicolumn{4}{c}{Market level} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Stacked regression following \\citet{cengiz2019effect}.",
  "Each cohort-year sub-experiment includes treated markets entering in year $g$",
  "and all never-treated markets, within a symmetric $\\pm$5-year event window.",
  "Cohort-specific market and year fixed effects absorb level differences across",
  "sub-experiments. SE clustered at market level.",
  "C\\&S = Callaway \\& Sant'Anna (2021) doubly-robust estimator from Table~\\ref{tab:did_revised}.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")

writeLines(lines, file.path(OUT_TAB, "tab_stacked_did.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_stacked_did.tex"), "\n")

# ============================================================================
# Save
# ============================================================================

stacked_results <- list(
  models = stacked_models,
  atts = stacked_atts,
  es_coefs = stacked_es_coefs,
  cs_comparison = cs_comparison,
  panel_summary = list(
    n_stacked_rows = nrow(stacked),
    n_cohorts = uniqueN(stacked$cohort_id),
    n_market_cohort = uniqueN(stacked$market_cohort),
    event_window = EVENT_WINDOW
  )
)

saveRDS(stacked_results, STACKED_DID_CACHE_V4)
cat("  Results saved:", STACKED_DID_CACHE_V4, "\n")
cat("  Done.\n")
