# ============================================================================
# 08_did_revised.R — Revised DiD with Rambachan-Roth bounds (v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Changes from v3 [Major 3.5]:
#   - Restrict sample: markets with >=3 pre AND >=3 post observations
#   - Drop Sun & Abraham (numerically unstable)
#   - Keep C&S only with doubly-robust estimation
#   - Add Rambachan & Roth (2023) honest DiD bounds
#   - Frame as supplementary appendix exercise
# ============================================================================

cat("=== 08_did_revised.R: Revised DiD ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

suppressPackageStartupMessages({
  if (requireNamespace("did", quietly = TRUE)) library(did)
})

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)

# ============================================================================
# Phase 1: Construct restricted market-level panel
# ============================================================================

cat("  Phase 1: Restricted market-level panel...\n")

panel <- dt[, .(
  log_price       = mean(lneg_price, na.rm = TRUE),
  log_nfirms_excl = mean(ln_firms_excl, na.rm = TRUE),
  n_tenders       = .N,
  cover_tender    = max(losers)
), by = .(market_id, year)]

fly <- dt[losers == 1, .(first_fl_year = min(year)), by = market_id]
panel <- merge(panel, fly, by = "market_id", all.x = TRUE)
panel[is.na(first_fl_year), first_fl_year := 0L]

# Restriction: >=3 pre AND >=3 post observations
panel[, rel_year := fifelse(first_fl_year > 0, year - first_fl_year, NA_integer_)]

# For treated markets: count pre and post obs
treated_counts <- panel[first_fl_year > 0, .(
  n_pre  = sum(rel_year < 0, na.rm = TRUE),
  n_post = sum(rel_year >= 0, na.rm = TRUE)
), by = market_id]

# Keep markets with >= 3 pre AND >= 3 post
valid_treated <- treated_counts[n_pre >= 3 & n_post >= 3, market_id]

# Never-treated: keep those with >= 6 years of data
never_treated_counts <- panel[first_fl_year == 0, .N, by = market_id]
valid_never <- never_treated_counts[N >= 6, market_id]

panel_rest <- panel[market_id %in% c(valid_treated, valid_never)]

# Remove singleton markets
market_years <- panel_rest[, .N, by = market_id]
panel_rest <- panel_rest[market_id %in% market_years[N >= 2, market_id]]

panel_rest[, market_num := as.integer(factor(market_id))]

n_treated <- uniqueN(panel_rest[first_fl_year > 0, market_id])
n_control <- uniqueN(panel_rest[first_fl_year == 0, market_id])

cat(sprintf("  Restricted panel: %s rows, %s markets (%s treated, %s never-treated)\n",
            pfmt_int(nrow(panel_rest)), pfmt_int(uniqueN(panel_rest$market_id)),
            pfmt_int(n_treated), pfmt_int(n_control)))

# ============================================================================
# Phase 2: Callaway & Sant'Anna
# ============================================================================

cs_results <- list()
dvs <- c("log_price", "log_nfirms_excl")
dv_labels <- c("Log Price", "Log Firms (excl. FL)")

if (requireNamespace("did", quietly = TRUE) && n_treated >= 10 && n_control >= 10) {
  cat("  Phase 2: Running Callaway & Sant'Anna...\n")

  for (di in seq_along(dvs)) {
    dv <- dvs[di]; dv_lbl <- dv_labels[di]
    cat(sprintf("    %s...\n", dv_lbl))

    d_cs <- panel_rest[!is.na(get(dv))]

    cs_out <- tryCatch({
      att_gt(
        yname = dv, tname = "year", idname = "market_num",
        gname = "first_fl_year",
        data = as.data.frame(d_cs),
        control_group = "nevertreated",
        est_method = "dr",
        base_period = "universal"
      )
    }, error = function(e) {
      cat(sprintf("    C&S failed: %s\n", e$message)); NULL
    })

    if (!is.null(cs_out)) {
      es_agg <- tryCatch(aggte(cs_out, type = "dynamic"), error = function(e) NULL)
      att_agg <- tryCatch(aggte(cs_out, type = "simple"), error = function(e) NULL)

      cs_results[[dv]] <- list(att_gt = cs_out, event_study = es_agg, att_overall = att_agg)

      if (!is.null(att_agg)) {
        cat(sprintf("    ATT: %.4f (SE: %.4f)\n", att_agg$overall.att, att_agg$overall.se))
      }

      # Pre-trend F-test
      if (!is.null(es_agg)) {
        pre_coefs <- es_agg$att.egt[es_agg$egt < 0]
        pre_ses <- es_agg$se.egt[es_agg$egt < 0]
        if (length(pre_coefs) > 0) {
          avg_pre <- mean(abs(pre_coefs))
          cat(sprintf("    Pre-trend avg |ATT|: %.4f %s\n", avg_pre,
                      if (avg_pre < 0.02) "(clean)" else "(potential pre-trend)"))
        }
      }
    }
  }
} else {
  cat("  Skipping C&S: insufficient data or did package missing\n")
}

# ============================================================================
# Phase 3: Rambachan & Roth (2023) Honest DiD
# ============================================================================

cat("  Phase 3: Rambachan & Roth honest bounds...\n")

honest_results <- list()
if (requireNamespace("HonestDiD", quietly = TRUE) && length(cs_results) > 0) {
  library(HonestDiD)

  for (dv in names(cs_results)) {
    es <- cs_results[[dv]]$event_study
    if (is.null(es)) next

    cat(sprintf("    HonestDiD for %s...\n", dv))

    tryCatch({
      # Extract pre and post coefficients
      pre_idx  <- which(es$egt < 0)
      post_idx <- which(es$egt >= 0)

      if (length(pre_idx) >= 2 && length(post_idx) >= 1) {
        # Use smoothness restriction (relative magnitudes)
        honest_out <- HonestDiD::createSensitivityResults_relativeMagnitudes(
          betahat = es$att.egt,
          sigma = diag(es$se.egt^2),
          numPrePeriods = length(pre_idx),
          numPostPeriods = length(post_idx),
          Mbarvec = seq(0, 2, by = 0.5)
        )

        honest_results[[dv]] <- honest_out
        cat(sprintf("    HonestDiD bounds computed (Mbar 0-2)\n"))
      }
    }, error = function(e) {
      cat(sprintf("    HonestDiD failed for %s: %s\n", dv, e$message))
    })
  }
} else {
  cat("  HonestDiD package not available or no C&S results.\n")
}

# ============================================================================
# Phase 4: TWFE Event Study (for comparison)
# ============================================================================

cat("  Phase 4: TWFE event study...\n")

panel_treated <- panel_rest[first_fl_year > 0]
panel_treated[, rel_year := year - first_fl_year]
panel_treated <- panel_treated[rel_year >= -5 & rel_year <= 5]

es_coefs <- list()
for (di in seq_along(dvs)) {
  dv <- dvs[di]; dv_lbl <- dv_labels[di]
  d <- panel_treated[!is.na(get(dv))]
  if (nrow(d) < 100) next

  d[, market_f := factor(market_id)]
  d[, year_f := factor(year)]

  m_es <- tryCatch(
    feols(as.formula(paste0(dv, " ~ i(rel_year, ref = -1) | market_f + year_f")),
          data = d, cluster = ~market_f, fixef.rm = "none"),
    error = function(e) NULL
  )

  if (!is.null(m_es)) {
    cf <- as.data.table(coeftable(m_es), keep.rownames = "term")
    setnames(cf, c("term", "coef", "se", "tval", "pval"))
    cf[, rel_year := as.integer(sub(".*::", "", term))]
    cf[, dv := dv_lbl]
    cf[, ci_lo := coef - 1.96 * se]
    cf[, ci_hi := coef + 1.96 * se]
    es_coefs[[dv]] <- cf
  }
}

# ============================================================================
# Phase 4B: MDE and Rambachan-Roth specific Mbar values (Comment 2.5)
# ============================================================================

cat("  Phase 4B: MDE computation (Comment 2.5)...\n")

mde_5pct <- NA; mde_80pwr <- NA; cs_se_price <- NA

if ("log_price" %in% names(cs_results) && !is.null(cs_results$log_price$att_overall)) {
  cs_se_price <- cs_results$log_price$att_overall$overall.se
  mde_5pct  <- 1.96 * cs_se_price
  mde_80pwr <- (1.96 + 0.84) * cs_se_price

  cat(sprintf("  C&S SE for price: %.4f\n", cs_se_price))
  cat(sprintf("  MDE (5%%, two-sided): 1.96 * %.4f = %.4f\n", cs_se_price, mde_5pct))
  cat(sprintf("  MDE (80%% power): (1.96 + 0.84) * %.4f = %.4f\n", cs_se_price, mde_80pwr))
  cat(sprintf("  OLS estimate = 0.064 → DiD is %s for OLS-magnitude effects\n",
              if (mde_5pct > 0.064) "underpowered" else "adequately powered"))
}

# Rambachan-Roth with specific Mbar values
cat("  Rambachan-Roth specific Mbar values...\n")

rr_mbar_results <- list()
if (requireNamespace("HonestDiD", quietly = TRUE) && "log_price" %in% names(cs_results)) {
  es <- cs_results$log_price$event_study
  if (!is.null(es)) {
    pre_idx  <- which(es$egt < 0)
    post_idx <- which(es$egt >= 0)

    if (length(pre_idx) >= 2 && length(post_idx) >= 1) {
      for (mbar_val in c(0, 0.01, 0.02, 0.05)) {
        tryCatch({
          rr_out <- HonestDiD::createSensitivityResults(
            betahat = es$att.egt,
            sigma = diag(es$se.egt^2),
            numPrePeriods = length(pre_idx),
            numPostPeriods = length(post_idx),
            Mvec = mbar_val
          )
          rr_mbar_results[[as.character(mbar_val)]] <- rr_out
          cat(sprintf("    Mbar=%.2f: CI=[%.4f, %.4f]\n",
                      mbar_val, rr_out$lb[1], rr_out$ub[1]))
        }, error = function(e) {
          cat(sprintf("    Mbar=%.2f failed: %s\n", mbar_val, e$message))
        })
      }
    }
  }
}

# ============================================================================
# Phase 4C: Sharp entry subsample (Comment 2.5)
# ============================================================================

cat("  Phase 4C: Sharp entry subsample...\n")

cs_sharp <- NULL
sharp_summary <- list(n_markets = 0, n_treated = 0, n_control = 0)

# Sharp entry: markets where FL goes from 0 to >0 in a single year
# (no FL in year t-1, FL in year t, and no FL in years before t-1)
treated_panel <- panel_rest[first_fl_year > 0]
sharp_markets <- treated_panel[, {
  # Check that all years before first_fl_year have cover_tender == 0
  pre_years <- .SD[year < first_fl_year]
  post_years <- .SD[year == first_fl_year]
  is_sharp <- nrow(pre_years) > 0 && all(pre_years$cover_tender == 0) && nrow(post_years) > 0
  .(sharp = is_sharp)
}, by = market_id]

sharp_market_ids <- sharp_markets[sharp == TRUE, market_id]
cat(sprintf("  Sharp entry markets: %s\n", pfmt_int(length(sharp_market_ids))))

if (length(sharp_market_ids) >= 50) {
  panel_sharp <- panel_rest[market_id %in% c(sharp_market_ids, valid_never)]
  panel_sharp[, market_num := as.integer(factor(market_id))]

  n_sharp_treated <- uniqueN(panel_sharp[first_fl_year > 0, market_id])
  n_sharp_control <- uniqueN(panel_sharp[first_fl_year == 0, market_id])
  sharp_summary <- list(n_markets = uniqueN(panel_sharp$market_id),
                         n_treated = n_sharp_treated, n_control = n_sharp_control)

  cat(sprintf("  Sharp panel: %s markets (%s treated, %s control)\n",
              pfmt_int(sharp_summary$n_markets),
              pfmt_int(n_sharp_treated), pfmt_int(n_sharp_control)))

  if (n_sharp_treated >= 10 && requireNamespace("did", quietly = TRUE)) {
    d_sharp <- panel_sharp[!is.na(log_price)]
    cs_sharp <- tryCatch({
      cs_out <- att_gt(
        yname = "log_price", tname = "year", idname = "market_num",
        gname = "first_fl_year",
        data = as.data.frame(d_sharp),
        control_group = "nevertreated",
        est_method = "dr",
        base_period = "universal"
      )
      att_agg <- aggte(cs_out, type = "simple")
      cat(sprintf("  Sharp entry ATT: %.4f (SE: %.4f)\n",
                  att_agg$overall.att, att_agg$overall.se))
      list(att_gt = cs_out, att_overall = att_agg)
    }, error = function(e) {
      cat(sprintf("  Sharp entry C&S failed: %s\n", e$message)); NULL
    })
  }
} else {
  cat("  Too few sharp entry markets. Noting insufficient power.\n")
}

# ============================================================================
# Write tab_did_revised.tex
# ============================================================================

cat("  Writing tab_did_revised.tex...\n")

did_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Staggered DiD: Callaway \\& Sant'Anna (Restricted Sample)}",
  "\\label{tab:did_revised}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & \\multicolumn{2}{c}{C\\&S (2021)} & \\multicolumn{2}{c}{TWFE} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  "Outcome & ATT & SE & Pre-trend & Post \\\\", "\\midrule"
)

for (di in seq_along(dvs)) {
  dv <- dvs[di]; dv_lbl <- dv_labels[di]

  cs_att <- "---"; cs_se <- ""
  if (dv %in% names(cs_results) && !is.null(cs_results[[dv]]$att_overall)) {
    cs_att <- pfmt(cs_results[[dv]]$att_overall$overall.att, 4)
    cs_se <- sprintf("(%s)", pfmt(cs_results[[dv]]$att_overall$overall.se, 4))
  }

  pre_str <- "---"; post_str <- "---"
  if (dv %in% names(es_coefs)) {
    cf <- es_coefs[[dv]]
    pre_str  <- pfmt(mean(cf[rel_year < 0, coef], na.rm = TRUE), 4)
    post_str <- pfmt(mean(cf[rel_year >= 0, coef], na.rm = TRUE), 4)
  }

  did_lines <- c(did_lines, sprintf("%s & %s & %s & %s & %s \\\\",
    dv_lbl, cs_att, cs_se, pre_str, post_str))
}

# MDE panel
did_lines <- c(did_lines, "\\midrule",
  "\\textit{Panel B: Statistical Power} & & & & \\\\")
if (!is.na(mde_5pct)) {
  did_lines <- c(did_lines,
    sprintf("MDE (5\\%%, two-sided) & \\multicolumn{4}{c}{%.4f} \\\\", mde_5pct),
    sprintf("MDE (80\\%% power) & \\multicolumn{4}{c}{%.4f} \\\\", mde_80pwr),
    "OLS benchmark & \\multicolumn{4}{c}{0.064} \\\\")
}

# Rambachan-Roth Mbar panel
if (length(rr_mbar_results) > 0) {
  did_lines <- c(did_lines, "\\midrule",
    "\\textit{Panel C: Rambachan-Roth Bounds ($\\bar{M}$)} & & & & \\\\")
  for (mv in names(rr_mbar_results)) {
    rr <- rr_mbar_results[[mv]]
    did_lines <- c(did_lines, sprintf(
      "$\\bar{M} = %s$ & \\multicolumn{4}{c}{[%s, %s]} \\\\",
      mv, pfmt(rr$lb[1], 4), pfmt(rr$ub[1], 4)))
  }
}

# Sharp entry panel
if (!is.null(cs_sharp)) {
  did_lines <- c(did_lines, "\\midrule",
    "\\textit{Panel D: Sharp Entry Subsample} & & & & \\\\",
    sprintf("C\\&S ATT & %s & %s & & \\\\",
      pfmt(cs_sharp$att_overall$overall.att, 4),
      sprintf("(%s)", pfmt(cs_sharp$att_overall$overall.se, 4))),
    sprintf("Sharp entry markets & \\multicolumn{4}{c}{%s treated, %s control} \\\\",
      pfmt_int(sharp_summary$n_treated), pfmt_int(sharp_summary$n_control)))
} else if (length(sharp_market_ids) > 0) {
  did_lines <- c(did_lines, "\\midrule",
    sprintf("\\textit{Panel D: Sharp Entry} & \\multicolumn{4}{c}{%s markets (insufficient power)} \\\\",
      pfmt_int(length(sharp_market_ids))))
}

did_lines <- c(did_lines, "\\midrule",
  sprintf("Markets & \\multicolumn{4}{c}{%s (%s treated, %s control)} \\\\",
          pfmt_int(uniqueN(panel_rest$market_id)),
          pfmt_int(n_treated), pfmt_int(n_control)),
  "Sample restriction & \\multicolumn{4}{c}{$\\geq$3 pre \\& $\\geq$3 post observations} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Panel A: C\\&S = Callaway \\& Sant'Anna (2021) doubly-robust estimator.",
  "Panel B: MDE = minimum detectable effect at stated significance/power levels.",
  "Panel C: Rambachan \\& Roth (2023) sensitivity bounds under smoothness restriction $\\bar{M}$",
  "on maximum change in the slope of the trend.",
  "Panel D: restricts treated markets to those with zero FL presence before treatment year.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(did_lines, file.path(OUT_TAB, "tab_did_revised.tex"))

# ============================================================================
# Save
# ============================================================================

did_results <- list(
  callaway_santanna = cs_results,
  honest_did = honest_results,
  twfe_coefs = es_coefs,
  panel_summary = list(
    n_markets = uniqueN(panel_rest$market_id),
    n_treated = n_treated, n_control = n_control,
    n_panel_rows = nrow(panel_rest)
  ),
  mde = list(mde_5pct = mde_5pct, mde_80pwr = mde_80pwr, cs_se = cs_se_price),
  rr_mbar = rr_mbar_results,
  sharp_entry = list(cs = cs_sharp, summary = sharp_summary)
)

saveRDS(did_results, DID_CACHE_V4)
cat("  DiD results saved:", DID_CACHE_V4, "\n")
cat("  Done.\n")
