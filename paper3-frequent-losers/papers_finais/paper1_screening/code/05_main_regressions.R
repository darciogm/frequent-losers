# ============================================================================
# 05_main_regressions.R — OLS baseline + network-split + tighter controls (v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# 5.1: Standard 4 DVs x 4 specs (replicating v1/v3)
# 5.2: Network-split: high-suspicion vs. low-suspicion FL [Major 3.2]
# 5.3: Tighter controls (genuine bidders, ref price, item×year FE) [R2.4]
# 5.4: Dispersion regressions (regime test)
# 5.5: Cover intensity (continuous treatment)
# ============================================================================

cat("=== 05_main_regressions.R: Main regressions ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

# ---- Load data ---------------------------------------------------------------
if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ============================================================================
# 5.1: Standard regressions (4 DVs x 4 specs = 16 models)
# ============================================================================

cat("  5.1 Standard regressions (OLS baseline)...\n")

m_prices      <- run_losers_4("lneg_price", dt, price_only = TRUE)
m_nfirms      <- run_losers_4("ln_firms", dt, price_only = FALSE)
m_nbids       <- run_losers_4("ln_bids", dt, price_only = FALSE)
m_nfirms_excl <- run_losers_4("ln_firms_excl", dt, price_only = FALSE)

# Quick summary
cat("\n  --- Key OLS coefficients (losers) ---\n")
for (outcome_name in c("prices", "nfirms", "nfirms_excl", "nbids")) {
  mlist <- switch(outcome_name,
    prices = m_prices, nfirms = m_nfirms,
    nfirms_excl = m_nfirms_excl, nbids = m_nbids
  )
  cat(sprintf("  %s:\n", toupper(outcome_name)))
  for (mname in names(mlist)) {
    m <- mlist[[mname]]
    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    cat(sprintf("    %-15s: %s (%s) N=%s\n",
                mname, pfmt(b, 4), pfmt(se, 4), pfmt_int(m$nobs)))
  }
}

# ============================================================================
# 5.2: Network-split regressions [Major 3.2]
# ============================================================================

cat("\n  5.2 Network-split regressions...\n")

m_network_split <- list()

if ("has_high_susp_fl" %in% names(dt) && "has_low_susp_fl" %in% names(dt)) {
  d_price <- dt[!is.na(lneg_price)]

  # Main split regression: both high and low in same model
  m_split_general <- feols(
    lneg_price ~ has_high_susp_fl + has_low_susp_fl + convite | item_f + year_f,
    data = d_price, cluster = ~item_f, fixef.rm = "none"
  )

  m_split_pbu <- feols(
    lneg_price ~ has_high_susp_fl + has_low_susp_fl + convite | item_f + year_f + pbu_f,
    data = d_price, cluster = ~item_f, fixef.rm = "none"
  )

  m_split_pregao <- feols(
    lneg_price ~ has_high_susp_fl + has_low_susp_fl | item_f + year_f + pbu_f,
    data = d_price[pregao == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  m_split_convite <- feols(
    lneg_price ~ has_high_susp_fl + has_low_susp_fl | item_f + year_f + pbu_f,
    data = d_price[convite == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  m_network_split <- list(
    general = m_split_general, general_pbu = m_split_pbu,
    pregao = m_split_pregao, convite = m_split_convite
  )

  cat("  Network-split (PBU FE):\n")
  for (v in c("has_high_susp_fl", "has_low_susp_fl")) {
    b <- coef(m_split_pbu)[v]
    se <- sqrt(vcov(m_split_pbu)[v, v])
    cat(sprintf("    %s: %.4f (%.4f)\n", v, b, se))
  }

  # F-test: high = low
  diff <- coef(m_split_pbu)["has_high_susp_fl"] - coef(m_split_pbu)["has_low_susp_fl"]
  cat(sprintf("  Difference (high - low): %.4f\n", diff))
} else {
  cat("  Network indicators not available. Run 02_network_analysis.R first.\n")
}

# ============================================================================
# 5.3: Tighter controls [R2.4]
# ============================================================================

cat("\n  5.3 Tighter controls...\n")

m_tighter <- list()
d_price <- dt[!is.na(lneg_price)]

# Spec A: Add number of genuine bidders
if ("ln_genuine" %in% names(dt)) {
  d_a <- d_price[!is.na(ln_genuine)]
  m_tighter[["with_genuine"]] <- feols(
    lneg_price ~ losers + ln_genuine + convite | item_f + year_f + pbu_f,
    data = d_a, cluster = ~item_f, fixef.rm = "none"
  )
  cat(sprintf("  + genuine bidders: losers=%.4f, N=%s\n",
              coef(m_tighter[["with_genuine"]])["losers"],
              pfmt_int(m_tighter[["with_genuine"]]$nobs)))
}

# Spec B: Add reference price
if ("log_ref_price" %in% names(dt)) {
  d_b <- d_price[!is.na(log_ref_price)]
  if (nrow(d_b) > 1000) {
    m_tighter[["with_refprice"]] <- feols(
      lneg_price ~ losers + log_ref_price + convite | item_f + year_f + pbu_f,
      data = d_b, cluster = ~item_f, fixef.rm = "none"
    )
    cat(sprintf("  + reference price: losers=%.4f, N=%s\n",
                coef(m_tighter[["with_refprice"]])["losers"],
                pfmt_int(m_tighter[["with_refprice"]]$nobs)))
  }
}

# Spec C: Item x Year FE (very demanding)
m_tighter[["item_year_fe"]] <- tryCatch({
  feols(lneg_price ~ losers + convite | item_year_f + pbu_f,
        data = d_price, cluster = ~item_f, fixef.rm = "none")
}, error = function(e) {
  cat(sprintf("  Item x Year FE failed: %s\n", e$message))
  NULL
})

if (!is.null(m_tighter[["item_year_fe"]])) {
  cat(sprintf("  Item x Year FE: losers=%.4f, N=%s\n",
              coef(m_tighter[["item_year_fe"]])["losers"],
              pfmt_int(m_tighter[["item_year_fe"]]$nobs)))
}

# Write tighter controls table
cat("  Writing tab_tighter_controls.tex...\n")
tc_models <- list()
tc_labels <- character()

tc_models[[1]] <- m_prices$general_pbu  # Baseline
tc_labels[1] <- "(1) Baseline"

idx <- 2
for (nm in c("with_genuine", "with_refprice", "item_year_fe")) {
  if (!is.null(m_tighter[[nm]])) {
    tc_models[[idx]] <- m_tighter[[nm]]
    lbl <- switch(nm,
      with_genuine = paste0("(", idx, ") + Genuine N"),
      with_refprice = paste0("(", idx, ") + Ref Price"),
      item_year_fe = paste0("(", idx, ") Item x Year FE")
    )
    tc_labels[idx] <- lbl
    idx <- idx + 1
  }
}

if (length(tc_models) > 1) {
  write_2col_table(tc_models,
    caption = "Price Regressions with Tighter Controls",
    label = "tab:tighter_controls",
    filename = "tab_tighter_controls.tex",
    coef_var = "losers", coef_label = "FL presence",
    col_labels = tc_labels,
    notes = paste(
      "Column (1): baseline with item, year, PBU FE.",
      "Additional columns add controls progressively.",
      "SE clustered at item level.",
      "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
    ))
}

# ============================================================================
# 5.4: Dispersion regressions (Regime test)
# ============================================================================

cat("\n  5.4 Regime test: bid dispersion...\n")

m_disp <- list()

d_sd <- dt[!is.na(log_bid_sd)]
if (nrow(d_sd) > 100) {
  m_disp[["total"]] <- run_losers_4("log_bid_sd", d_sd, price_only = FALSE)
}

# ============================================================================
# 5.5: Cover intensity (continuous treatment)
# ============================================================================

cat("\n  5.5 Cover intensity regressions...\n")

m_intensity <- list()
for (dv in c("lneg_price", "ln_firms", "ln_bids")) {
  d <- if (dv == "lneg_price") dt[!is.na(lneg_price)] else dt
  m_intensity[[dv]] <- feols(
    as.formula(paste0(dv, " ~ cover_intensity + convite | item_f + year_f + pbu_f")),
    data = d, cluster = ~item_f, fixef.rm = "none"
  )
  cat(sprintf("  %s ~ cover_intensity: %.4f (%.4f)\n", dv,
              coef(m_intensity[[dv]])["cover_intensity"],
              sqrt(vcov(m_intensity[[dv]])["cover_intensity", "cover_intensity"])))
}

# ============================================================================
# 5.6: Network-split table
# ============================================================================

if (length(m_network_split) > 0) {
  cat("  Writing tab_network_split.tex...\n")

  ns_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Price Effects by FL Suspicion Level}",
    "\\label{tab:network_split}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcccc}", "\\toprule",
    " & (1) & (2) & (3) & (4) \\\\",
    " & General & General & Preg\\~{a}o & Convite \\\\",
    "\\midrule"
  )

  for (var in c("has_high_susp_fl", "has_low_susp_fl")) {
    lbl <- if (var == "has_high_susp_fl") "High-suspicion FL" else "Low-suspicion FL"
    vals <- sapply(c("general", "general_pbu", "pregao", "convite"), function(sp) {
      m <- m_network_split[[sp]]
      if (var %in% names(coef(m))) coef_cell(m, var, 4) else ""
    })
    ns_lines <- c(ns_lines, sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")))

    ses <- sapply(c("general", "general_pbu", "pregao", "convite"), function(sp) {
      m <- m_network_split[[sp]]
      if (var %in% names(coef(m))) se_cell(m, var, 4) else ""
    })
    ns_lines <- c(ns_lines, sprintf(" & %s \\\\", paste(ses, collapse = " & ")))
  }

  ns_lines <- c(ns_lines, "\\midrule")
  obs <- sapply(c("general", "general_pbu", "pregao", "convite"), function(sp) {
    pfmt_int(m_network_split[[sp]]$nobs)
  })
  ns_lines <- c(ns_lines, sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")))

  ns_lines <- c(ns_lines,
    "Item + Year FE & YES & YES & YES & YES \\\\",
    "PBU FE & NO & YES & YES & YES \\\\",
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} DV: log negotiated price.",
    "High-suspicion FL = winner HHI above median and $\\geq$2 repeat co-bidding partners.",
    "SE clustered at item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(ns_lines, file.path(OUT_TAB, "tab_network_split.tex"))
}

# ============================================================================
# 5.7: Network interactions (Comment 2.4)
# ============================================================================

cat("\n  5.7 Network interactions (Comment 2.4)...\n")

m_network_interact <- list()
d_price <- dt[!is.na(lneg_price)]

# (a) Continuous HHI x FL interaction
if ("winner_hhi_market" %in% names(dt)) {
  m_hhi_interact <- tryCatch(
    feols(lneg_price ~ losers * winner_hhi_market + convite | item_f + year_f + pbu_f,
          data = d_price, cluster = ~item_f, fixef.rm = "none"),
    error = function(e) { cat(sprintf("  HHI interaction failed: %s\n", e$message)); NULL }
  )
  if (!is.null(m_hhi_interact)) {
    m_network_interact[["hhi_interact"]] <- m_hhi_interact
    cat("  HHI x FL interaction:\n")
    for (v in c("losers", "winner_hhi_market", "losers:winner_hhi_market")) {
      if (v %in% names(coef(m_hhi_interact))) {
        b <- coef(m_hhi_interact)[v]
        se <- sqrt(vcov(m_hhi_interact)[v, v])
        cat(sprintf("    %s: %.4f (%.4f)\n", v, b, se))
      }
    }
  }
} else {
  cat("  winner_hhi_market not available. Run 02_network_analysis.R.\n")
}

# (b) Genuine bidder distribution by FL status
cat("  Genuine bidder distribution by FL status:\n")
cat(sprintf("    High-susp FL tenders: mean n_genuine = %.2f\n",
            mean(dt[has_high_susp_fl == 1, n_genuine], na.rm = TRUE)))
cat(sprintf("    Low-susp FL tenders: mean n_genuine = %.2f\n",
            mean(dt[has_low_susp_fl == 1, n_genuine], na.rm = TRUE)))
cat(sprintf("    No-FL tenders: mean n_genuine = %.2f\n",
            mean(dt[losers == 0, n_genuine], na.rm = TRUE)))

# (c) FL x n_genuine interaction
m_genuine_interact <- tryCatch(
  feols(lneg_price ~ losers * n_genuine + convite | item_f + year_f + pbu_f,
        data = d_price, cluster = ~item_f, fixef.rm = "none"),
  error = function(e) { cat(sprintf("  n_genuine interaction failed: %s\n", e$message)); NULL }
)
if (!is.null(m_genuine_interact)) {
  m_network_interact[["genuine_interact"]] <- m_genuine_interact
  cat("  FL x n_genuine interaction:\n")
  for (v in c("losers", "n_genuine", "losers:n_genuine")) {
    if (v %in% names(coef(m_genuine_interact))) {
      b <- coef(m_genuine_interact)[v]
      se <- sqrt(vcov(m_genuine_interact)[v, v])
      cat(sprintf("    %s: %.4f (%.4f)\n", v, b, se))
    }
  }
}

# Write tab_network_interactions.tex
if (length(m_network_interact) > 0) {
  cat("  Writing tab_network_interactions.tex...\n")
  ni_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Market Structure Interactions with FL Presence}",
    "\\label{tab:network_interactions}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcc}", "\\toprule",
    " & (1) HHI $\\times$ FL & (2) Genuine $\\times$ FL \\\\",
    " & Log Price & Log Price \\\\",
    "\\midrule"
  )

  # HHI interaction
  if (!is.null(m_network_interact[["hhi_interact"]])) {
    m <- m_network_interact[["hhi_interact"]]
    for (v in c("losers", "winner_hhi_market", "losers:winner_hhi_market")) {
      lbl <- switch(v,
        losers = "FL presence",
        winner_hhi_market = "Winner HHI (market)",
        `losers:winner_hhi_market` = "FL $\\times$ HHI")
      if (v %in% names(coef(m))) {
        ni_lines <- c(ni_lines,
          sprintf("%s & %s & \\\\", lbl, coef_cell(m, v, 4)),
          sprintf(" & %s & \\\\", se_cell(m, v, 4)))
      }
    }
  }

  ni_lines <- c(ni_lines, "\\midrule")

  # n_genuine interaction
  if (!is.null(m_network_interact[["genuine_interact"]])) {
    m <- m_network_interact[["genuine_interact"]]
    for (v in c("losers", "n_genuine", "losers:n_genuine")) {
      lbl <- switch(v,
        losers = "FL presence",
        n_genuine = "N genuine bidders",
        `losers:n_genuine` = "FL $\\times$ N genuine")
      if (v %in% names(coef(m))) {
        ni_lines <- c(ni_lines,
          sprintf("%s & & %s \\\\", lbl, coef_cell(m, v, 4)),
          sprintf(" & & %s \\\\", se_cell(m, v, 4)))
      }
    }
  }

  ni_lines <- c(ni_lines, "\\midrule")
  obs1 <- if (!is.null(m_network_interact[["hhi_interact"]])) pfmt_int(m_network_interact[["hhi_interact"]]$nobs) else "---"
  obs2 <- if (!is.null(m_network_interact[["genuine_interact"]])) pfmt_int(m_network_interact[["genuine_interact"]]$nobs) else "---"
  ni_lines <- c(ni_lines,
    sprintf("Observations & %s & %s \\\\", obs1, obs2),
    "Item + Year + PBU FE & YES & YES \\\\",
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} DV: log negotiated price.",
    "Winner HHI (market) computed at item-group $\\times$ PBU $\\times$ year level.",
    "N genuine = number of non-FL firms bidding in the tender.",
    "SE clustered at item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(ni_lines, file.path(OUT_TAB, "tab_network_interactions.tex"))
}

# ============================================================================
# Save all models
# ============================================================================

models <- list(
  prices            = m_prices,
  nfirms            = m_nfirms,
  nfirms_excl       = m_nfirms_excl,
  nbids             = m_nbids,
  network_split     = m_network_split,
  network_interact  = m_network_interact,
  tighter           = m_tighter,
  dispersion        = m_disp,
  intensity         = m_intensity
)

saveRDS(models, MODELS_CACHE_V4)
cat("  Models saved:", MODELS_CACHE_V4, "\n")
cat("  Done.\n")
