# ============================================================================
# 08_did_callaway_santanna.R — Callaway & Sant'Anna (2021) staggered DiD
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# Primary causal identification strategy.
# Market-level panel: market_id (item_code x pbu_code) x year
# Treatment cohort: g = first_fl_year_market per market_id (0 for never-treated)
# Also includes TWFE event study and Sun & Abraham for comparison.
# Bacon decomposition as diagnostic.
# ============================================================================

cat("=== 08_did_callaway_santanna.R: C&S DiD ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

suppressPackageStartupMessages({
  if (requireNamespace("did", quietly = TRUE)) library(did)
  if (requireNamespace("bacondecomp", quietly = TRUE)) library(bacondecomp)
})

# ---- Load data ---------------------------------------------------------------
if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ============================================================================
# Phase 1: Construct market-level panel
# ============================================================================

cat("  Constructing market-level panel...\n")

# Collapse to market_id x year
panel <- dt[, .(
  log_price       = mean(lneg_price, na.rm = TRUE),
  log_nfirms      = mean(ln_firms, na.rm = TRUE),
  log_nfirms_excl = mean(ln_firms_excl, na.rm = TRUE),
  log_bid_sd      = mean(log_bid_sd, na.rm = TRUE),
  price_ratio     = mean(price_ratio, na.rm = TRUE),
  n_tenders       = .N,
  cover_tender    = max(losers)
), by = .(market_id, year)]

# Merge first_fl_year_market
fly <- dt[losers == 1, .(first_fl_year = min(year)), by = market_id]
panel <- merge(panel, fly, by = "market_id", all.x = TRUE)

# Never-treated markets: set cohort to 0
panel[is.na(first_fl_year), first_fl_year := 0L]

# Remove singleton markets (only 1 year of data)
market_years <- panel[, .N, by = market_id]
panel <- panel[market_id %in% market_years[N >= 2, market_id]]

# Create numeric market_id for did package
panel[, market_num := as.integer(factor(market_id))]

n_treated <- uniqueN(panel[first_fl_year > 0, market_id])
n_control <- uniqueN(panel[first_fl_year == 0, market_id])
cat(sprintf("  Panel: %s rows, %s markets (%s treated, %s never-treated)\n",
            pfmt_int(nrow(panel)), pfmt_int(uniqueN(panel$market_id)),
            pfmt_int(n_treated), pfmt_int(n_control)))
cat(sprintf("  Year range: %d-%d\n", min(panel$year), max(panel$year)))

# ============================================================================
# Phase 2: Callaway & Sant'Anna att_gt()
# ============================================================================

cs_results <- list()
dvs <- c("log_price", "log_nfirms_excl")
dv_labels <- c("Log Price", "Log Firms (excl. FL)")

if (requireNamespace("did", quietly = TRUE) && n_treated >= 10 && n_control >= 10) {
  cat("  Running Callaway & Sant'Anna...\n")

  for (di in seq_along(dvs)) {
    dv <- dvs[di]
    dv_lbl <- dv_labels[di]
    cat(sprintf("    %s...\n", dv_lbl))

    d_cs <- panel[!is.na(get(dv))]

    cs_out <- tryCatch({
      att_gt(
        yname = dv,
        tname = "year",
        idname = "market_num",
        gname = "first_fl_year",
        data = as.data.frame(d_cs),
        control_group = "nevertreated",
        est_method = "dr",
        base_period = "universal"
      )
    }, error = function(e) {
      cat(sprintf("    C&S failed for %s: %s\n", dv_lbl, e$message))
      NULL
    })

    if (!is.null(cs_out)) {
      # Aggregate to event study
      es_agg <- tryCatch(
        aggte(cs_out, type = "dynamic"),
        error = function(e) {
          cat(sprintf("    aggte dynamic failed: %s\n", e$message))
          NULL
        }
      )

      # Aggregate to overall ATT
      att_agg <- tryCatch(
        aggte(cs_out, type = "simple"),
        error = function(e) NULL
      )

      cs_results[[dv]] <- list(
        att_gt = cs_out,
        event_study = es_agg,
        att_overall = att_agg
      )

      if (!is.null(att_agg)) {
        cat(sprintf("    Overall ATT: %.4f (SE: %.4f)\n",
                    att_agg$overall.att, att_agg$overall.se))
      }

      # Pre-trend check
      if (!is.null(es_agg)) {
        pre_coefs <- es_agg$att.egt[es_agg$egt < 0]
        if (length(pre_coefs) > 0) {
          avg_pre <- mean(abs(pre_coefs))
          cat(sprintf("    Pre-trend avg |ATT|: %.4f %s\n",
                      avg_pre,
                      if (avg_pre < 0.02) "(clean)" else "(potential pre-trend)"))
        }
      }
    }
  }
} else {
  cat("  Skipping C&S: did package not available or insufficient treated/control markets\n")
}

# ============================================================================
# Phase 3: TWFE Event Study (for comparison)
# ============================================================================

cat("  Running TWFE event study...\n")

# Keep only treated markets for event study
panel_treated <- panel[first_fl_year > 0]
panel_treated[, rel_year := year - first_fl_year]
panel_treated <- panel_treated[rel_year >= -5 & rel_year <= 5]

es_models <- list()
es_coefs  <- list()

for (di in seq_along(dvs)) {
  dv <- dvs[di]
  dv_lbl <- dv_labels[di]

  d <- panel_treated[!is.na(get(dv))]
  if (nrow(d) < 100) next

  d[, market_f := factor(market_id)]
  d[, year_f := factor(year)]

  m_es <- tryCatch(
    feols(as.formula(paste0(dv, " ~ i(rel_year, ref = -1) | market_f + year_f")),
          data = d, cluster = ~market_f, fixef.rm = "none"),
    error = function(e) {
      cat(sprintf("    TWFE ES failed for %s: %s\n", dv_lbl, e$message))
      NULL
    }
  )

  if (!is.null(m_es)) {
    es_models[[dv]] <- m_es

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
# Phase 4: Sun & Abraham (for comparison)
# ============================================================================

cat("  Sun & Abraham estimator...\n")

sa_results <- list()
panel_treated[, cohort := first_fl_year]

for (di in seq_along(dvs)) {
  dv <- dvs[di]
  d <- panel_treated[!is.na(get(dv))]
  if (nrow(d) < 100) next

  d[, market_f := factor(market_id)]
  d[, year_f := factor(year)]

  tryCatch({
    m_sa <- feols(
      as.formula(paste0(dv, " ~ sunab(cohort, year) | market_f + year_f")),
      data = d, cluster = ~market_f, fixef.rm = "none", lean = FALSE
    )
    sa_tab <- summary(m_sa, agg = "ATT")$coeftable
    sa_results[[dv]] <- list(att = sa_tab[1, 1], se = sa_tab[1, 2])
    cat(sprintf("    %s: SA ATT = %.4f (SE: %.4f)\n",
                dv_labels[di], sa_tab[1, 1], sa_tab[1, 2]))
    rm(m_sa); gc(verbose = FALSE)
  }, error = function(e) {
    cat(sprintf("    %s: Sun & Abraham failed: %s\n", dv_labels[di], e$message))
  })
}

# ============================================================================
# Phase 5: Bacon Decomposition (diagnostic)
# ============================================================================

cat("  Bacon decomposition...\n")

bacon_results <- NULL
if (requireNamespace("bacondecomp", quietly = TRUE)) {
  d_bacon <- panel[!is.na(log_price)]
  d_bacon[, treated := as.integer(first_fl_year > 0 & year >= first_fl_year)]

  tryCatch({
    bacon_out <- bacon(
      treated ~ log_price,
      data = as.data.frame(d_bacon[, .(market_num, year, treated, log_price)]),
      id_var = "market_num",
      time_var = "year"
    )
    bacon_results <- bacon_out
    cat("  Bacon decomposition completed.\n")
    if (is.data.frame(bacon_out)) {
      cat(sprintf("  Bacon groups: %d\n", nrow(bacon_out)))
    }
  }, error = function(e) {
    cat(sprintf("  Bacon decomposition failed: %s\n", e$message))
  })
}

# ============================================================================
# Save all results
# ============================================================================

did_results <- list(
  callaway_santanna = cs_results,
  twfe_event_study  = es_models,
  twfe_coefs        = es_coefs,
  sun_abraham       = sa_results,
  bacon             = bacon_results,
  panel_summary     = list(
    n_markets = uniqueN(panel$market_id),
    n_treated = n_treated,
    n_control = n_control,
    n_panel_rows = nrow(panel)
  )
)

saveRDS(did_results, "/tmp/p3v2_did.rds")
cat("  DiD results saved: /tmp/p3v2_did.rds\n")
cat("  Done.\n")
