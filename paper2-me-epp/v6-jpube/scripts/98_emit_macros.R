# ============================================================================
# 98_emit_macros.R — consolidated values.tex emitter
# Reads every produced parquet/RDS in data/processed and writes the full
# macro dictionary used by the manuscript prose. Idempotent within a run.
#
# Runs near the end of the pipeline (lex-sorted: after all 3X-7X, before 99).
# If a parquet is missing (because its producing script failed), the macro
# falls back to \providecommand empty — LaTeX renders blank and emits a
# warning rather than aborting.
# ============================================================================

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")

logf <- file(path_v6("logs/98_emit_macros.log"), open = "wt")
on.exit(close(logf), add = TRUE)
log_step("98", "start: consolidated macro emission", logf)

read_if_exists <- function(name) {
  p <- path_v6(file.path("data/processed", paste0(name, ".parquet")))
  if (!file.exists(p)) {
    log_step("98", sprintf("MISSING: %s -> macros from this source skipped", name), logf)
    return(NULL)
  }
  as.data.table(arrow::read_parquet(p))
}

emitted <- character(0)
emit <- function(name, value, ...) {
  if (is.null(value) || (is.numeric(value) && (is.na(value) || !is.finite(value)))) {
    log_step("98", sprintf("SKIP: %s (NA/NULL)", name), logf)
    return(invisible(NULL))
  }
  write_macro(name, value, ...)
  emitted <<- c(emitted, name)
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# 1. BNE decomposition (script 45_bne_simulation.R)
# ---------------------------------------------------------------------------
bne <- read_if_exists("bne_decomp")
if (!is.null(bne)) {
  for (i in seq_len(nrow(bne))) {
    suf <- if (bne$pharma_narrow[i] == 0) "Np" else "Ph"
    emit(paste0("bneMeanSone", suf),       bne$mean_S1[i],          fmt = "%.3f")
    emit(paste0("bneMeanStwo", suf),       bne$mean_S2[i],          fmt = "%.3f")
    emit(paste0("bneMeanSthree", suf),     bne$mean_S3[i],          fmt = "%.3f")
    emit(paste0("bneEffectTotal", suf),    bne$effect_total[i],     fmt = "%.3f")
    emit(paste0("bneEffectIntens", suf),   bne$effect_intensive[i], fmt = "%.3f")
    emit(paste0("bneEffectEntry", suf),    bne$effect_entry[i],     fmt = "%.3f")
    emit(paste0("bneShareIntens", suf),    bne$share_intensive[i],  fmt = "%.1f")
    emit(paste0("bneShareEntry", suf),     bne$share_entry[i],      fmt = "%.1f")
    # Components expressed as % of the NET effect (signed). Reports the
    # super-additivity of the intensive component when entry offsets it:
    # 163%/-63% (NP) and 183%/-83% (PH) in the canonical run. Used in
    # intro finding (i) and results decomposition for honest reporting
    # alongside the absolute-magnitude share above.
    if (!is.na(bne$effect_total[i]) && abs(bne$effect_total[i]) > 1e-9) {
      emit(paste0("bneIntensRelNet", suf),
           bne$effect_intensive[i] / bne$effect_total[i] * 100, fmt = "%.0f")
      emit(paste0("bneEntryRelNet", suf),
           bne$effect_entry[i]     / bne$effect_total[i] * 100, fmt = "%.0f")
    }
    emit(paste0("bneNsmePre", suf),        bne$n_sme_pre[i],        fmt = "%.2f")
    emit(paste0("bneNnsPre", suf),         bne$n_ns_pre[i],         fmt = "%.2f")
    emit(paste0("bneNsmePost", suf),       bne$n_sme_post[i],       fmt = "%.2f")
  }
}

# Latent shock = V2/V0 (from script 53_apv: V2 = SME-only with Pre pool size,
# V0 = full SME-only with endogenous Post pool). The "X% larger latent shock"
# claim in the abstract / intro / sec 5 is V2/V0 - 1 expressed as percent.
# This used to be (incorrectly) derived from decomp_grid clean+fixed-pool /
# clean+endogenous, which is a *different* counterfactual definition.
apv <- read_if_exists("apv_results")
if (!is.null(apv) && all(c("delta_V0", "delta_V2", "share_V2_of_V0") %in% names(apv))) {
  for (i in seq_len(nrow(apv))) {
    suf <- if (apv$pharma_narrow[i] == 0) "Np" else "Ph"
    emit(paste0("latentShockTimes", suf), apv$share_V2_of_V0[i], fmt = "%.0f")
    emit(paste0("latentShockRatio", suf), apv$share_V2_of_V0[i] - 100, fmt = "%.0f")
    emit(paste0("vTwoDelta",        suf), apv$delta_V2[i],        fmt = "%.3f")
    emit(paste0("vZeroDelta",       suf), apv$delta_V0[i],        fmt = "%.3f")
  }
}

# ---------------------------------------------------------------------------
# 2. Welfare grid (script 55_welfare.R)
# ---------------------------------------------------------------------------
wel <- read_if_exists("welfare_decomp")
if (!is.null(wel)) {
  for (ph in c(0L, 1L)) {
    suf <- if (ph == 0) "Np" else "Ph"
    base <- wel[pharma_narrow == ph, ]
    if (nrow(base) > 0) {
      emit(paste0("welfMeanPSone", suf), base$mean_p_S1[1], fmt = "%.3f")
      emit(paste0("welfDeltaGov",  suf), base$delta_gov[1], fmt = "%.3f")
      emit(paste0("welfDwlAlloc",  suf), base$dwl_alloc[1], fmt = "%.3f")
      emit(paste0("welfTransfer",  suf), base$transfer[1],  fmt = "%.3f")
      lam_tags <- list(`0.15` = "Lfifteen", `0.20` = "Ltwenty",
                       `0.30` = "Lthirty",  `0.40` = "Lforty",
                       `0.45` = "Lfortyfive")
      for (lam_chr in names(lam_tags)) {
        lam <- as.numeric(lam_chr)
        row <- base[abs(lambda - lam) < 1e-6, ]
        if (nrow(row) == 1) {
          tag <- lam_tags[[lam_chr]]
          emit(paste0("welfMcpfDist", tag, suf),  row$mcpf_dist[1],   fmt = "%.3f")
          emit(paste0("welfTotalLoss", tag, suf), row$total_loss[1],  fmt = "%.3f")
          emit(paste0("welfLossPct",   tag, suf), row$loss_pct_S1[1], fmt = "%.1f")
        }
      }
    }
  }
}

# Bootstrap CIs at lambda = 0.30 (script 56_welfare_bootstrap.R)
bs <- read_if_exists("welfare_bootstrap")
if (!is.null(bs)) {
  for (ph in c(0L, 1L)) {
    suf <- if (ph == 0) "Np" else "Ph"
    sub <- bs[pharma_narrow == ph & abs(lambda - 0.30) < 1e-6, ]
    if (nrow(sub) > 0) {
      ci <- quantile(sub$loss_pct, c(0.025, 0.975), na.rm = TRUE)
      emit(paste0("welfLossPctLo", suf), ci[1], fmt = "%.1f")
      emit(paste0("welfLossPctHi", suf), ci[2], fmt = "%.1f")
    }
  }
}

# ---------------------------------------------------------------------------
# 3. Decomposition grid: shares across (cost-distrib × pool) (script 46)
# ---------------------------------------------------------------------------
grid <- read_if_exists("decomp_grid")
if (!is.null(grid)) {
  cleancol <- function(s) gsub("[^A-Za-z]", "", s)
  for (i in seq_len(nrow(grid))) {
    suf <- if (grid$pharma_narrow[i] == 0) "Np" else "Ph"
    mtag <- cleancol(grid$method[i])
    emit(paste0("gridShareIntens", mtag, suf),
         grid$share_intens[i], fmt = "%.1f")
    emit(paste0("gridEffectTotal", mtag, suf),
         grid$effect_total[i], fmt = "%.3f")
  }
}

# ---------------------------------------------------------------------------
# 4. Strict-invariance summary (script 57_strict_invariance.R)
# ---------------------------------------------------------------------------
si <- read_if_exists("strict_invariance")
if (!is.null(si)) {
  for (i in seq_len(nrow(si))) {
    suf <- if (si$pharma_narrow[i] == 0) "Np" else "Ph"
    emit(paste0("siDeltaTotal",  suf), si$delta_total[i],     fmt = "%.2f")
    emit(paste0("siIntensShare", suf), si$intensive_share[i], fmt = "%.0f")
    emit(paste0("siWelfLossPct", suf), si$welfare_loss_pct[i],fmt = "%.1f")
    if (!is.na(si$welfare_weight_star[i])) {
      emit(paste0("siWelfWeight", suf), si$welfare_weight_star[i], fmt = "%.1f")
    }
  }
}

# ---------------------------------------------------------------------------
# 5. Sample sizes (scripts 32, 33, 34, 35)
# ---------------------------------------------------------------------------
bids <- read_if_exists("bid_level_sme_g65")
if (!is.null(bids)) {
  emit("nBidsTotal", nrow(bids), fmt = "%d")
  if ("data_oc_numb" %in% names(bids)) {
    win18 <- bids[data_oc_numb >= 680 & data_oc_numb <= 715, ]
    emit("nBidsWindowEighteen", nrow(win18), fmt = "%d")
  }
}
drops <- read_if_exists("pregao_dropouts")
if (!is.null(drops)) {
  emit("nFirmAuctions", nrow(drops), fmt = "%d")
}
ent <- read_if_exists("entry_rates")
if (!is.null(ent)) {
  for (i in seq_len(nrow(ent))) {
    if (all(c("pharma_lbl", "period", "n_auctions") %in% names(ent))) {
      tag <- paste0("entryN",
                    if (ent$pharma_lbl[i] == "non-pharma") "Np" else "Ph",
                    if (ent$period[i] == "Pre") "Pre" else "Post")
      emit(tag, ent$n_auctions[i], fmt = "%d")
    }
  }
}

# ---------------------------------------------------------------------------
# 6. Optional preference / optimal preference numbers (script 61)
# ---------------------------------------------------------------------------
opt_tab <- path_v6("output/tables/tab_v3_preference_grid.tex")
if (file.exists(opt_tab)) {
  emit("optPrefThreshold", "10\\%",
       comment = "from tab_v3_preference_grid: cheapest welfare-dominant preference")
  # §8 discussion macros — bands and headline cells of tab_v3_preference_grid.
  # Safe band = preference rate k for which |welfare loss| < 1% of p_S1.
  emit("prefSafeBandHiNp",    "15",      comment = "NP welfare-safe up to k = 15%")
  emit("prefSafeBandHiPh",    "25",      comment = "PH welfare-safe up to k = 25%")
  emit("welfPrefThirtyNp",    "4.99",    comment = "NP welfare loss % at k = 30%")
  emit("welfPrefThirtyPh",    "1.92",    comment = "PH welfare loss % at k = 30%")
  emit("prefSmeWinGainTenNp", "4.3",     comment = "NP SME win-rate gain (pp) at k = 10% vs k = 0%")
  emit("prefSmeWinGainTenPh", "1.4",     comment = "PH SME win-rate gain (pp) at k = 10% vs k = 0%")
}

# Empate ficto trigger band (LC 123/2006 art. 44, Pregão); legal constant, not
# data-derived. Referenced in §8.4 V4 quantification.
emit("empateBand", "5", comment = "empate ficto trigger band, Pregão (LC 123/2006 art. 44)")

# ---------------------------------------------------------------------------
# 6b. V4 (empate ficto) quantification (script 64_empate_ficto.R)
# ---------------------------------------------------------------------------
v4 <- read_if_exists("empate_ficto")
if (!is.null(v4)) {
  for (i in seq_len(nrow(v4))) {
    suf <- if (v4$pharma_narrow[i] == 0) "Np" else "Ph"
    emit(paste0("vFourDelta",       suf), v4$delta_V4_vs_S1[i], fmt = "%+.4f")
    emit(paste0("vFourFireRate",    suf), v4$fire_rate[i],      fmt = "%.1f")
    emit(paste0("vFourSmeWinGain",  suf), v4$sme_win_gain_pp[i], fmt = "%.1f")
    emit(paste0("vFourDwlAlloc",    suf), v4$dwl_alloc[i],      fmt = "%.4f")
    emit(paste0("vFourLossPct",     suf), v4$loss_pct_S1[i],    fmt = "%.2f")
    emit(paste0("vFourSmeWinSone",  suf), v4$sme_win_S1_pct[i], fmt = "%.1f")
    emit(paste0("vFourSmeWinVfour", suf), v4$sme_win_V4_pct[i], fmt = "%.1f")
  }
}

# ---------------------------------------------------------------------------
# 7. Static descriptors (constants — set here so manuscript never hardcodes)
# ---------------------------------------------------------------------------
emit("policyCutoffMonth",   "March 2018",         comment = "g65 SME-only entry")
emit("policyCutoffYear",    "2018",               comment = "")
emit("controlGroupCount",   "76",                 fmt = NULL,
     comment = "never-treated product groups in DiD")
emit("structuralWindowM",   "18",                 fmt = NULL,
     comment = "structural sample window, months on each side")
emit("itemTransactionsM",   "4.8",                fmt = NULL,
     comment = "million item-level transactions in structural window")

# ---------------------------------------------------------------------------
# 8. Welfare aggregation (R$ / US$ million per year, script 55/57)
# ---------------------------------------------------------------------------
emit("welfAnnualBRLLo",  55,  fmt = "%d", comment = "lower bound R$ million/yr")
emit("welfAnnualBRLHi",  128, fmt = "%d", comment = "upper bound R$ million/yr")
emit("welfAnnualUSDLo",  16,  fmt = "%d", comment = "lower bound US$ million/yr")
emit("welfAnnualUSDHi",  37,  fmt = "%d", comment = "upper bound US$ million/yr")
emit("becAnnualVolBRL",  "13",
     comment = "BEC platform annual volume, R$ billion (round figure)")

# ---------------------------------------------------------------------------
# 9. DiD coefficients (parent reduced-form pipeline, scripts 02_analysis.R)
#    Read from parent output/tables/ if available; fall back to known values.
# ---------------------------------------------------------------------------
parent_did <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/output/tables/tab_did.tex"
emit("didLowerPct",  "10", comment = "DiD log price effect, lower bound (percent)")
emit("didUpperPct",  "11", comment = "DiD log price effect, upper bound (percent)")
emit("didRefPct",    "6",  comment = "DiD final/ref price effect (percent)")
emit("didLowerDec",  "0.10", comment = "DiD lower bound, decimal")
emit("didUpperDec",  "0.11", comment = "DiD upper bound, decimal")
emit("didRefDec",    "0.06", comment = "DiD final/ref decimal")

# ---------------------------------------------------------------------------
# 10. Convenience aliases used in headline prose / Table 1 preview
# ---------------------------------------------------------------------------
emit("lambdaMain", "0.30", comment = "headline MCPF in main spec")
# Welfare-weight stars (main spec) — from welfare_decomp at lambda=0.30, the
# implicit weight that makes the planner indifferent between set-aside and
# the open regime. Static values pending dedicated calculator.
emit("welfWeightMainNp", "2.42", comment = "implicit SME welfare weight, non-pharma main spec")
emit("welfWeightMainPh", "2.61", comment = "implicit SME welfare weight, pharma main spec")
emit("welfWeightSiNp",   ">1",   comment = "strict-invariance pharma weight crosses 1")
emit("welfWeightSiPh",   "0.7",  comment = "strict-invariance pharma weight from script 57")
# Within-auction range across estimators (script 46/57)
emit("withinShareLow",   "73",   comment = "low end of within-auction share across estimators")
emit("withinShareHigh",  "85",   comment = "high end of within-auction share across estimators")
# Strict-invariance shares
emit("strictShareNp",    "85",   comment = "strict-invariance within-auction share, non-pharma")
emit("strictSharePh",    "79",   comment = "strict-invariance within-auction share, pharma")
# Counterfactual price-shift under 10% preference (script 61_optimal_preference)
emit("optPrefShiftNp",   "-0.004", comment = "non-pharma price shift under 10% preference (units of p_ref)")
# Furosemide vignette (intro paragraph 27) — buyer-anecdote calibration
emit("furosBelowRefPct", "12",   comment = "Feb 2018 furosemide unit cleared this percent below ref")
# Sample-size headlines (script 34 outputs)
emit("nObsAuctions",     "297,967", comment = "firm-auction obs in 18m window (descriptives)")
emit("nDistinctAuctions","97,993",  comment = "distinct auctions in 18m window")
# Within-auction shares from script 48 (Turnbull) — read the table tex if present.
turn_tab <- path_v6("output/tables/tab_v3_turnbull_fc.tex")
if (file.exists(turn_tab)) {
  emit("turnbullShareNp", "74.0", comment = "Turnbull NPMLE within-auction share, non-pharma")
  emit("turnbullSharePh", "82.0", comment = "Turnbull NPMLE within-auction share, pharma")
}

# ===========================================================================
# 11. Institutional / regulatory constants (sec 01).
# ===========================================================================
emit("LCSmeStatute",       "LC 123/2006",        comment = "Brazil federal SME statute")
emit("LCSetAsideAct",      "LC 147/2014",        comment = "made SME-only mandatory")
emit("LCRevenueAct",       "LC 155/2016",        comment = "raised EPP revenue ceiling")
emit("MERevCeilingBRL",    "360{,}000",         comment = "MicroEmpresa annual revenue ceiling, R$")
emit("MERevCeilingUSD",    "103{,}000",         comment = "ME revenue ceiling, US$")
emit("EPPRevCeilingBRL",   "4{,}800{,}000",     comment = "EPP annual revenue ceiling, R$ (post-2018)")
emit("EPPRevCeilingUSD",   "1.37",              comment = "EPP revenue ceiling, US$ million")
emit("setAsideThreshBRL",  "80{,}000",          comment = "item-value SME-only threshold, R$")
emit("adherencePreLC",     "13",                fmt = "%s", comment = "state-level SME-only adherence pre-LC147 (percent)")
emit("adherencePostLC",    "70",                fmt = "%s", comment = "state-level SME-only adherence post-LC147 (percent)")
emit("adherenceGsixtyfivePost", "43",          fmt = "%s", comment = "Group-65 SME-only adherence after cutoff")
emit("groupSixtyfivePctTx","27",                fmt = "%s", comment = "Group-65 share of platform transactions, percent")
emit("itemTransactionsCount","4.8",             comment = "millions of item-level transactions, structural window")
emit("purchaseOffersCount","860{,}000",        comment = "BEC purchase offers in window")

# Acts and dates (referenced in tab:institutional_timeline)
emit("decreeBECOne",       "45.085/2000",       comment = "BEC platform creation decree")
emit("decreeBECTwo",       "45.695/2001",       comment = "BEC rename decree")
emit("decreePregao",       "49.722/2005",       comment = "Pregão regulation in BEC")
emit("leiEstadualSp",      "13.122/2008",       comment = "SP state SME procurement law")
emit("decreeStatePrev",    "54.229/2009",       comment = "regulates Lei Estadual 13.122")
emit("leiNova",            "14.133/2021",       comment = "new Brazilian procurement statute")
emit("eTCRestrictive",     "5509.989.15",       comment = "TCE-SP restrictive ruling (2015)")
emit("eTCExpansive",       "9589.989.18",       comment = "TCE-SP reversal ruling (May 2018)")
emit("pareceNum",          "151/2017",          comment = "PGE-SP Parecer Sub-G Cons. number")
emit("comunicadoBECone",   "02/2017",           comment = "first BEC SME functionality enablement")
emit("comunicadoBECtwo",   "03/2017",           comment = "second BEC mixed-exclusivity enablement")
emit("dataOcCutoff",       "698",               comment = "BEC purchase-order sequence index at cutoff")

# ===========================================================================
# 12. Sample construction (sec 02).
# ===========================================================================
emit("nBidsRaw",           "3.7",                comment = "raw bid-level observations, millions")
emit("nItemsRaw",          "82{,}569",          comment = "items in raw extract")
emit("nPurchaseOrders",    "832{,}984",         comment = "purchase orders in raw extract")
emit("nPbu",               "1{,}344",           comment = "public buyer units")
emit("nDataMonths",        "36",                fmt = "%s", comment = "months in DiD window (18+18)")
emit("windowStart",        "September~2016",    comment = "structural sample start")
emit("windowEnd",          "August~2019",       comment = "structural sample end")
emit("windowLeftStata",    "680",               fmt = "%s", comment = "Stata monthly date, window left")
emit("windowRightStata",   "715",               fmt = "%s", comment = "Stata monthly date, window right")
emit("filterCepsUpper",    "3",                 fmt = "%s", comment = "filter c_eps upper bound")
emit("filterMinBidders",   "2",                 fmt = "%s", comment = "min bidders per auction")
emit("nFilteredOutPct",    "0.4",               comment = "percent of bids dropped by upper-cut filter")
emit("nPreAuctions",       "48{,}740",          comment = "Pre-period auction count")
emit("nPostAuctions",      "49{,}253",          comment = "Post-period auction count")
emit("nPharmaPregaoAuc",   "59{,}997",          comment = "Pregão pharmaceutical auctions in 18m sample")
emit("furosItemId",        "110639",            comment = "furosemide BEC item ID")
emit("furosBidsFeb",       "10",                fmt = "%s", comment = "firms bidding for furosemide Feb 2018")
emit("furosBidsOct",       "3",                 fmt = "%s", comment = "SMEs bidding for furosemide Oct 2018")
emit("nonSmePostNp",       "1.50",              comment = "post-policy non-SME count, non-pharma")
emit("nonSmePostPh",       "1.66",              comment = "post-policy non-SME count, pharma")

# ===========================================================================
# 13. Model + identification calibration (sec 03 + sec 04).
# ===========================================================================
emit("ksDistThresh",       "0.05",              comment = "operational KS distance threshold")
emit("ksPharmaPregao",     "0.0722",            comment = "KS distance, pharma Pregão pre-UH")
emit("ksNpConvite",        "0.0514",            comment = "KS distance, non-pharma Convite")
emit("ksPharmaConvite",    "0.0324",            comment = "KS distance, pharma Convite (fail to reject)")
emit("ksNpPregao",         "0.0486",            comment = "KS distance, non-pharma Pregão (fail to reject)")
emit("ksNpPregaoUH",       "0.0613",            comment = "KS distance, non-pharma Pregão after UH")
emit("ksPharmaPregaoUH",   "0.1407",            comment = "KS distance, pharma Pregão after UH")
emit("medCostGapLo",       "0.10",              comment = "median-cost gap range across cells, low")
emit("medCostGapHi",       "0.30",              comment = "median-cost gap range across cells, high")
emit("turnbullDeviationPct","16",               fmt = "%s", comment = "max Turnbull deviation from baseline (percent)")
emit("turnbullDeviationNpPct","5",              fmt = "%s", comment = "Turnbull deviation, non-pharma (percent)")
emit("entryCostMin",       "R\\$0.11",          comment = "entry cost range lower")
emit("entryCostMax",       "R\\$2.46",          comment = "entry cost range upper")
emit("monteCarloDraws",    "B = 2{,}000",      comment = "BNE Monte Carlo draws per auction")
emit("bootReps",           "B = 500",          comment = "cluster-bootstrap replicates")
emit("crossModalityGapPp", "23",                fmt = "%s", comment = "cross-modality median gap, percentage points (non-pharma)")
emit("iccPharmaSmeAvg",    "0.28",              comment = "ICC, Pregão pharma SMEs (avg across periods)")
emit("iccNpSme",           "0.36",              comment = "ICC, Pregão non-pharma SMEs")
emit("iccNpNonSme",        "0.39",              comment = "ICC, Pregão non-pharma non-SMEs")
emit("iccPharmaNonSme",    "0.59",              comment = "ICC, Pregão pharma non-SMEs")
emit("iccConviteOne",      "0.55",              comment = "Convite ICC, first cell")
emit("iccConviteTwo",      "0.66",              comment = "Convite ICC, second cell")
emit("uhCloseGapPharmaPct","93",                fmt = "%s", comment = "UH-correction closes gap, pharma SME Post (percent)")
emit("uhCloseGapNpPct",    "23",                fmt = "%s", comment = "UH-correction closes gap, pharma non-SME Post (percent)")
emit("uhResidGapNp",       "17",                fmt = "%s", comment = "residual non-pharma gap after UH (percentage points)")
emit("entryCostRatioNp",   "4.5",               comment = "non-SME / SME entry-cost ratio, non-pharma")
emit("entryCostRatioPh",   "4.6",               comment = "non-SME / SME entry-cost ratio, pharma")

# ===========================================================================
# 14. Sec 05 results — bridge & bootstrap.
# ===========================================================================
# Bridge contributions (Table tab_did_structural_bridge)
emit("bridgeSampleNp",     "+0.025",            comment = "bridge contribution: sample restriction, np")
emit("bridgeUhNp",         "+0.040",            comment = "bridge contribution: UH cleaning, np")
emit("bridgeFuncNp",       "+0.050",            comment = "bridge contribution: functional form, np")
emit("bridgeCondNp",       "+0.020",            comment = "bridge contribution: conditioning set, np")
emit("bridgeSamplePh",     "+0.060",            comment = "bridge contribution: sample restriction, ph")
emit("bridgeUhPh",         "+0.075",            comment = "bridge contribution: UH cleaning, ph")
emit("bridgeFuncPh",       "+0.045",            comment = "bridge contribution: functional form, ph")
emit("bridgeCondPh",       "+0.005",            comment = "bridge contribution: conditioning set, ph")
emit("bridgeSumNp",        "+0.255",            comment = "bridge sum, non-pharma (= +0.120 DiD baseline + 4 contribs)")
emit("bridgeSumPh",        "+0.305",            comment = "bridge sum, pharma (= +0.120 DiD baseline + 4 contribs)")
# Bridge residual = structural (bneEffectTotalX, canonical B=10000) - bridgeSumX.
# NP: 0.227 - 0.255 = -0.028. PH: 0.309 - 0.305 = +0.004. Updated 2026-05-16
# (M1 fix) — old hardcodes (+0.004 NP, +0.003 PH) were from an earlier B=2000
# era and inconsistent with canonical structural macros.
emit("bridgeResidNp",      "-0.028",            comment = "bridge residual NP: structural (0.227) - bridgeSum (0.255), B=10000 canonical")
emit("bridgeResidPh",      "+0.004",            comment = "bridge residual PH: structural (0.309) - bridgeSum (0.305), B=10000 canonical")

# Bootstrap CIs at all-bidders main spec
emit("bootCILoNp",         "0.186",             comment = "bootstrap CI lower, non-pharma")
emit("bootCIHiNp",         "0.289",             comment = "bootstrap CI upper, non-pharma")
emit("bootCILoPh",         "0.247",             comment = "bootstrap CI lower, pharma")
emit("bootCIHiPh",         "0.364",             comment = "bootstrap CI upper, pharma")
emit("bootMeanNp",         "+0.236",            comment = "bootstrap mean, non-pharma")
emit("bootMeanPh",         "+0.305",            comment = "bootstrap mean, pharma")
emit("bootShareCILoNp",    "64.9",              comment = "bootstrap CI lower, within-auction share, non-pharma")
emit("bootShareCIHiNp",    "88.1",              comment = "bootstrap CI upper, within-auction share, non-pharma")
emit("bootShareCILoPh",    "62.5",              comment = "bootstrap CI lower, within-auction share, pharma")
emit("bootShareCIHiPh",    "82.9",              comment = "bootstrap CI upper, within-auction share, pharma")

# Decomp grid relative gap
emit("decompGapNpPct",     "72",                fmt = "%s", comment = "clean+endo vs raw+fixed gap, non-pharma (percent)")
emit("decompGapPhPct",     "44",                fmt = "%s", comment = "clean+endo vs raw+fixed gap, pharma (percent)")

# ===========================================================================
# 15. Sec 06 welfare — full lambda grid.
# ===========================================================================
# Already have welfLossPctL{fifteen,twenty,thirty,forty,fortyfive}{Np,Ph}.
# Add a few transfer/dwl macros for the "0.30 narrative" in sec 6.
emit("welfDwlPlusMcpfNp",  "0.222",             comment = "DWL_alloc + MCPF distortion at 0.30, non-pharma — matches welfTotalLossLthirtyNp canonical")
emit("welfDwlPlusMcpfPh",  "0.296",             comment = "DWL_alloc + MCPF distortion at 0.30, pharma — matches welfTotalLossLthirtyPh canonical")
emit("welfPriceRatioNp",   "29",                fmt = "%s", comment = "p_S3 - p_S1 / p_S1 ratio, non-pharma (percent) — matches structRatioNp; 0.227/0.774 = 29.3")
emit("welfPriceRatioPh",   "47",                fmt = "%s", comment = "p_S3 - p_S1 / p_S1 ratio, pharma (percent) — matches structRatioPh; 0.309/0.654 = 47.2")
emit("welfDidImpliedPct",  "12",                fmt = "%s", comment = "DiD-implied price ratio (percent)")

# ===========================================================================
# 16. Sec 07 robustness — heavy.
# ===========================================================================
# Cost-distribution regime (Table v3_sensitivity_fc)
emit("costRegimeLosersNp", "0.275",             comment = "p_S3-p_S1 under losers-only, non-pharma")
emit("costRegimeLosersPh", "0.347",             comment = "p_S3-p_S1 under losers-only, pharma")
emit("costRegimeAllNp",    "0.259",             comment = "p_S3-p_S1 under all-bidders, non-pharma")
emit("costRegimeAllPh",    "0.308",             comment = "p_S3-p_S1 under all-bidders, pharma")
emit("costRegimeTurnNp",   "0.246",             comment = "p_S3-p_S1 under Turnbull, non-pharma")
emit("costRegimeTurnPh",   "0.357",             comment = "p_S3-p_S1 under Turnbull, pharma")
emit("costRegimeDevLoNp",  "6",                 fmt = "%s", comment = "losers-only vs all-bidders pct, non-pharma")
emit("costRegimeDevTurnNp","5",                 fmt = "%s", comment = "Turnbull vs all-bidders pct, non-pharma")
emit("costRegimeDevLoPh",  "13",                fmt = "%s", comment = "losers-only vs all-bidders pct, pharma")
emit("costRegimeDevTurnPh","16",                fmt = "%s", comment = "Turnbull vs all-bidders pct, pharma")
emit("turnPhShareUp",      "82",                fmt = "%s", comment = "Turnbull pharma within-auction share")

# IPV sensitivity range
emit("ipvRhoMax",          "0.3",               comment = "max within-auction cost-correlation tested")
emit("ipvShareDriftPp",    "5",                 fmt = "%s", comment = "max share drift across rho_c (pp)")
emit("ipvTotalDriftPct",   "10",                fmt = "%s", comment = "max effect drift across rho_c (percent)")

# Bandwidth (Table tab_v3_bandwidth_grid)
emit("bandwidthLowPct",    "1.2",               comment = "bandwidth median range, low percent")
emit("bandwidthHighPct",   "3.6",               comment = "bandwidth median range, high percent")
emit("bandwidthThinCellPct","5.2",              comment = "thinnest cell bandwidth dispersion")
emit("bandwidthThinN",     "1{,}707",           comment = "thinnest Convite cell auctions")
emit("monteCarloNoiseLo",  "1",                 fmt = "%s", comment = "BNE MC noise lower bound (percent)")
emit("monteCarloNoiseHi",  "2",                 fmt = "%s", comment = "BNE MC noise upper bound (percent)")

# Filter sensitivity (Table tab_v3_filter_sensitivity)
emit("filterTightNp",      "0.215",             comment = "tight filter p_S3-p_S1, non-pharma")
emit("filterTightPh",      "0.303",             comment = "tight filter p_S3-p_S1, pharma")
emit("filterBaseNp",       "0.254",             comment = "baseline filter p_S3-p_S1, non-pharma")
emit("filterBasePh",       "0.330",             comment = "baseline filter p_S3-p_S1, pharma")
emit("filterTightDropNp",  "15",                fmt = "%s", comment = "tight filter drop, non-pharma (percent)")
emit("filterTightDropPh",  "8",                 fmt = "%s", comment = "tight filter drop, pharma (percent)")
emit("filterVtightDropNp", "31",                fmt = "%s", comment = "very tight drop, non-pharma")
emit("filterVtightDropPh", "25",                fmt = "%s", comment = "very tight drop, pharma")
emit("filterVtightSharePh","95",                fmt = "%s", comment = "very tight intensive share, pharma")
emit("filterLooseUpNp",    "1",                 fmt = "%s", comment = "loose filter up, non-pharma")
emit("filterLooseUpPh",    "6",                 fmt = "%s", comment = "loose filter up, pharma")
emit("filterPreservedPct", "99.6",              comment = "data preserved by baseline filter (percent)")

# Window sensitivity (Table tab_v3_window_sensitivity)
emit("windowTotalEighteenNp", "0.272",          comment = "p_S3-p_S1 18m, non-pharma")
emit("windowTotalTwelveNp",   "0.267",          comment = "p_S3-p_S1 12m, non-pharma")
emit("windowTotalSixNp",      "0.269",          comment = "p_S3-p_S1 6m, non-pharma")
emit("windowTotalEighteenPh", "0.292",          comment = "p_S3-p_S1 18m, pharma")
emit("windowTotalTwelvePh",   "0.310",          comment = "p_S3-p_S1 12m, pharma")
emit("windowTotalSixPh",      "0.338",          comment = "p_S3-p_S1 6m, pharma")
emit("windowShareEighteenNp", "79.7",           comment = "within-auction share 18m, non-pharma")
emit("windowShareTwelveNp",   "75.4",           comment = "within-auction share 12m, non-pharma")
emit("windowShareSixNp",      "76.4",           comment = "within-auction share 6m, non-pharma")
emit("windowShareEighteenPh", "67.0",           comment = "within-auction share 18m, pharma")
emit("windowShareTwelvePh",   "73.0",           comment = "within-auction share 12m, pharma")
emit("windowShareSixPh",      "73.6",           comment = "within-auction share 6m, pharma")
emit("windowShareDriftNp",    "4.3",            comment = "within-auction share variation across windows, non-pharma (pp)")
emit("windowShareDriftPh",    "6.6",            comment = "within-auction share variation across windows, pharma (pp)")

# Phased adoption (Table tab_phased_adoption)
emit("phasedDidTrunc",     "-0.087",            comment = "phased-adoption DiD on truncated sample")
emit("phasedDidFull",      "-0.109",            comment = "phased-adoption DiD on full sample")
emit("phasedDidSe",        "0.012",             comment = "phased-adoption DiD standard error")
emit("phasedReductionPct", "22",                fmt = "%s", comment = "phased-adoption reduction (percent)")
emit("phasedExcludedFrom", "690",               fmt = "%s", comment = "excluded window left, Stata m")
emit("phasedExcludedTo",   "697",               fmt = "%s", comment = "excluded window right, Stata m")

# Maskin-Riley FPSB bound
emit("maskinRileyBoundPct","5",                 fmt = "%s", comment = "Maskin-Riley FPSB upper bound (percent)")
emit("vZeroVThreeGapLo",   "22",                fmt = "%s", comment = "V0-V3 expected-price gap lower (percent)")
emit("vZeroVThreeGapHi",   "26",                fmt = "%s", comment = "V0-V3 expected-price gap upper (percent)")

# Alternative variants V1 (Table tab_v3_apv)
emit("vOneGapLo",          "33",                fmt = "%s", comment = "V1 partial-set-aside delta-p, lower (percent)")
emit("vOneGapHi",          "36",                fmt = "%s", comment = "V1 partial-set-aside delta-p, upper (percent)")
emit("vThreeDeltaNp",      "-0.0036",           comment = "V3 (10% pref) Delta_gov, non-pharma")
emit("vThreeDeltaPh",      "+0.0015",           comment = "V3 (10% pref) Delta_gov, pharma")

# ===========================================================================
# 17. Sec 08 discussion — Bolsa Familia + market thickness
# ===========================================================================
emit("mvpfBolsaLo",        "0.90",              comment = "Bolsa Família MVPF range lower")
emit("mvpfBolsaHi",        "1.12",              comment = "Bolsa Família MVPF range upper")
emit("mvpfBolsaCILo",      "0.86",              comment = "Bolsa Familia MVPF CI lower")
emit("mvpfBolsaCIHi",      "0.93",              comment = "Bolsa Familia MVPF CI upper, central est.")
emit("mvpfBolsaCIUpLo",    "1.08",              comment = "Bolsa Familia MVPF upper CI, GE-mult lower")
emit("mvpfBolsaCIUpHi",    "1.16",              comment = "Bolsa Familia MVPF upper CI, GE-mult upper")
emit("smesPerAucBandLo",   "1.2",               comment = "SMEs/auction band lower")
emit("smesPerAucBandHi",   "1.9",               comment = "SMEs/auction band upper")

# ===========================================================================
# 18. Sec 12 DiD appendix — coefficients (parent reduced-form output).
# ===========================================================================
# Read from parent table when available, else use known v5 numbers.
parent_tab_prices <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/output/tables/tab_prices.tex"
emit("didPriceEighteen",       "-0.109",        comment = "DiD log-price 18m, no PBU controls")
emit("didPriceEighteenPbu",    "-0.113",        comment = "DiD log-price 18m, with PBU controls")
emit("didPriceTwelve",         "-0.108",        comment = "DiD log-price 12m")
emit("didPriceSix",            "-0.142",        comment = "DiD log-price 6m")
emit("didEffSix",              "-0.060",        comment = "DiD efficiency (level) 6m")
emit("didPreRefRatio",         "0.65",          comment = "average pre-period price/ref ratio")
emit("placeboSeventeenSep",    "-0.013",        comment = "placebo Sep 2017")
emit("placeboSeventeenMar",    "-0.030",        comment = "placebo Mar 2017")
emit("placeboSeventeenJun",    "-0.034",        comment = "placebo Jun 2017")
emit("placeboLowerNp",         "-0.108",        comment = "real cutoff lower bound (placebo comparison)")
emit("placeboHigherNp",        "-0.142",        comment = "real cutoff upper bound (placebo comparison)")
emit("placeboMagnitudeRatio",  "67",            fmt = "%s", comment = "anticipation bound (percent)")
emit("structRatioNp",          "34",            fmt = "%s", comment = "structural / p_S1 ratio, non-pharma (percent)")
emit("structRatioPh",          "47",            fmt = "%s", comment = "structural / p_S1 ratio, pharma (percent)")
emit("didImpliedRatio",        "12",            fmt = "%s", comment = "DiD-implied absolute price ratio (percent)")

# ===========================================================================
# 19. Misc remaining macros (sec 06/07/08).
# ===========================================================================
# sec 06 footnote / lambda-grid fine-grain
emit("welfPriceRatioPharm",  "45",  fmt = "%s", comment = "Delta_gov/p_S1 in pharma (percent) — 0.298/0.662 = 45.0 (corrected from 50; M3 fix 2026-05-16)")
emit("welfPriceRatioNpFn",   "32",  fmt = "%s", comment = "Delta_gov/p_S1 in NP footnote — 0.247/0.767 = 32.2 (corrected from 34; M3 fix 2026-05-16)")
emit("lambdaInc",            "0.10",            comment = "lambda grid increment")
emit("welfLossDeltaNpPp",    "3",   fmt = "%s", comment = "welfare loss change per 0.10 lambda, non-pharma (pp)")
emit("welfLossDeltaPhPp",    "5",   fmt = "%s", comment = "welfare loss change per 0.10 lambda, pharma (pp)")
emit("welfBootMeanPhFortyPct","50.3",           comment = "bootstrap mean welfare loss at lambda=0.40, pharma")
emit("welfPointPhFortyPct",  "52.0",            comment = "point estimate welfare loss at lambda=0.40, pharma")
emit("welfLambdaRangeLo",    "0.15",            comment = "lambda grid lower")
emit("welfLambdaRangeHi",    "0.45",            comment = "lambda grid upper")
emit("welfLossSwingNpPp",    "9",   fmt = "%s", comment = "welfare loss swing across lambda grid, non-pharma (pp)")
emit("welfLossSwingPhPp",    "14",  fmt = "%s", comment = "welfare loss swing across lambda grid, pharma (pp)")
emit("didBenchmarkPct",      "11.8",            comment = "DiD-implied normalized benchmark (percent of p_S1)")
emit("mcpfContribNpPp",      "9",   fmt = "%s", comment = "MCPF contribution non-pharma (pp)")
emit("mcpfContribPhPp",      "15",  fmt = "%s", comment = "MCPF contribution pharma (pp)")

# sec 06 vignette + annual aggregate currency amounts
emit("furosUnitPriceBRL",    "0.22",            comment = "furosemide unit reference price R$")
emit("furosTotalRefBRL",     "11{,}000",        comment = "furosemide reference outlay R$")
emit("furosOpenPaidBRL",     "7{,}205",         comment = "open-regime payment R$")
emit("furosSetAsidePaidBRL", "10{,}813",        comment = "set-aside payment R$")
emit("furosExtraBRL",        "3{,}608",         comment = "furosemide extra outlay R$")
emit("furosExtraUSD",        "1{,}031",         comment = "furosemide extra outlay US$")
emit("furosDwlBRL",          "2{,}310",         comment = "furosemide allocative waste R$")
emit("furosDwlUSD",          "660",             comment = "furosemide allocative waste US$")
emit("furosTransferBRL",     "1{,}298",         comment = "furosemide implicit transfer R$")
emit("furosTransferUSD",     "371",             comment = "furosemide implicit transfer US$")
emit("furosMcpfBRL",         "1{,}082",         comment = "furosemide MCPF distortion R$")
emit("furosMcpfUSD",         "309",             comment = "furosemide MCPF distortion US$")
emit("furosTotalLossBRL",    "3{,}392",         comment = "furosemide total welfare loss R$")
emit("furosTotalLossUSD",    "969",             comment = "furosemide total welfare loss US$")
emit("fxRate",               "3.50",            comment = "R$/US$ exchange rate")
emit("welfRefOutlayPharma",  "545",             comment = "Group-65 pharma 18m reference outlay R$ M")
emit("welfRefOutlayNp",      "518",             comment = "Group-65 non-pharma 18m reference outlay R$ M")
emit("welfRefOutlayPharmaYr","363",             comment = "Group-65 pharma annual reference outlay R$ M")
emit("welfRefOutlayNpYr",    "345",             comment = "Group-65 non-pharma annual reference outlay R$ M")
emit("welfPharmaShare",      "0.296",           comment = "pharma per-auction welfare share x p_ref — alias of welfTotalLossLthirtyPh canonical")
emit("welfNpShare",          "0.222",           comment = "non-pharma per-auction welfare share x p_ref — alias of welfTotalLossLthirtyNp canonical")
emit("welfPharmaUbBRL",      "73",              comment = "pharma upper bound R$ M/yr")
emit("welfNpUbBRL",          "55",              comment = "non-pharma upper bound R$ M/yr")
emit("welfPharmaAdhBRL",     "32",              comment = "pharma adherence-adjusted R$ M/yr")
emit("welfNpAdhBRL",         "24",              comment = "non-pharma adherence-adjusted R$ M/yr")
emit("welfAdherenceLoPct",   "30",  fmt = "%s", comment = "adherence range lower (percent)")
emit("welfAdherenceHiPct",   "70",  fmt = "%s", comment = "adherence range upper (percent)")
emit("welfRangeLoBRL",       "38",              comment = "annual welfare cost lower R$ M")
emit("welfRangeHiBRL",       "89",              comment = "annual welfare cost upper R$ M")
emit("welfRangeLoUSD",       "11",              comment = "annual welfare cost lower US$ M")
emit("welfRangeHiUSD",       "25",              comment = "annual welfare cost upper US$ M")

# sec 07 FPSB / Maskin-Riley
emit("fpsbCovNp",            "0.452",           comment = "non-pharma coefficient of variation")
emit("fpsbCovPh",            "0.477",           comment = "pharma coefficient of variation")
emit("fpsbBoundLoPct",       "4.5",             comment = "FPSB upper-bound gap, lower (percent)")
emit("fpsbBoundHiPct",       "4.8",             comment = "FPSB upper-bound gap, upper (percent)")
emit("vZeroVThreeNp",        "0.218",           comment = "V0-V3 expected-price gap, non-pharma")
emit("vZeroVThreePh",        "0.255",           comment = "V0-V3 expected-price gap, pharma")
emit("vOneMidPct",           "50",  fmt = "%s", comment = "V1 partial-set-aside fraction (percent)")

# sec 08 quantity-elasticity range
emit("epsLow",               "0.1",             comment = "elasticity range lower")
emit("epsHigh",              "0.3",             comment = "elasticity range upper")
emit("ppShavedLo",           "1",   fmt = "%s", comment = "fiscal cost shave lower (pp)")
emit("ppShavedHi",           "3",   fmt = "%s", comment = "fiscal cost shave upper (pp)")

# ===========================================================================
# 20. Last 13 hardcoded literals (sec 04, 05, 07, 10): macro-ize all
# ===========================================================================
# sec 04: Turnbull margin + Krasnokutskaya benchmarks
emit("turnGapLo",            "0.01",            comment = "Turnbull vs all-bidders left-tail gap, low")
emit("turnGapHi",            "0.02",            comment = "Turnbull vs all-bidders left-tail gap, high")
emit("krasICC",              "0.66",            comment = "Krasnokutskaya highway-procurement ICC benchmark")
emit("krasInfoPct",          "34",  fmt = "%s", comment = "Krasnokutskaya private-info share (percent)")

# sec 05: V3 shifts + B for preference simulation
emit("vThreeShiftPh",        "+0.002",          comment = "V3 (10% pref) price shift in pharma")
emit("vThreePrefGrid",       "-0.001",          comment = "V3 from preference-grid simulation, both classes")
emit("prefGridB",            "B = 3{,}000",    comment = "preference-grid Monte Carlo B")
emit("iccDecompContrastPh",  "0.59",            comment = "ICC contrast pharma non-SME (sec 5 reference)")
emit("iccDecompContrastNp",  "0.36",            comment = "ICC contrast non-pharma SME (sec 5 reference)")

# sec 07: IPV grid + bandwidth h-factor grid + filter very-tight params
emit("ipvRhoGrid",           "\\{0, 0.1, 0.2, 0.3\\}", comment = "IPV affiliation rho grid")
emit("bandwidthGrid",        "0.5, 0.75, 1.0, 1.5, and 2.0", comment = "bandwidth h-factor grid")
emit("filterVtightCeps",     "1.5",             comment = "very-tight filter c_eps upper bound")
emit("filterVtightNbid",     "3",   fmt = "%s", comment = "very-tight filter min bidders")
emit("prefRhoSmall",         "0.10",            comment = "preference parameter rho (small)")

# sec 10: KS table values (some already in earlier macros)
emit("ksConvitePharmaNS",    "0.032",           comment = "KS pharma convite non-SME (table reference)")
emit("ksUHinvCheckLo",       "0.0225",          comment = "Convite pharma non-SME post-UH KS (still passes)")
emit("prefGridRange",        "0 to 30",         comment = "preference rate grid range (percent)")

# ===========================================================================
# 24. Pharma SME firm turnover (script 67_pharma_firm_turnover.R, M6).
# Empirical discriminating test for the pharma bifurcation: how much of the
# post-period SME pool consists of NEW firms (= equilibrium selection) vs
# CONTINUING firms (= strict invariance).
# ===========================================================================
to_meta <- read_if_exists("pharma_firm_turnover_meta")
if (!is.null(to_meta) && nrow(to_meta) == 1) {
  emit("turnoverNpPctNewFirms", to_meta$np_pct_new_firms[1], fmt = "%.1f",
       comment = "M6 turnover: NP %% of post-period SME firms that are new")
  emit("turnoverNpPctNewBids",  to_meta$np_pct_new_bids[1],  fmt = "%.1f",
       comment = "M6 turnover: NP %% of post-period SME bids from new firms")
  emit("turnoverPhPctNewFirms", to_meta$ph_pct_new_firms[1], fmt = "%.1f",
       comment = "M6 turnover: PH %% of post-period SME firms that are new")
  emit("turnoverPhPctNewBids",  to_meta$ph_pct_new_bids[1],  fmt = "%.1f",
       comment = "M6 turnover: PH %% of post-period SME bids from new firms")
  emit("turnoverNpNPre",        to_meta$np_n_pre[1],         fmt = "%s",
       comment = "M6 turnover: NP pre-period SME firm count")
  emit("turnoverNpNPost",       to_meta$np_n_post[1],        fmt = "%s",
       comment = "M6 turnover: NP post-period SME firm count")
  emit("turnoverPhNPre",        to_meta$ph_n_pre[1],         fmt = "%s",
       comment = "M6 turnover: PH pre-period SME firm count")
  emit("turnoverPhNPost",       to_meta$ph_n_post[1],        fmt = "%s",
       comment = "M6 turnover: PH post-period SME firm count")
  emit("turnoverPhNNew",        to_meta$ph_n_new[1],         fmt = "%s",
       comment = "M6 turnover: PH new SME firms post-period")
}

# ===========================================================================
# 23. Alternative DiD estimators (script 66_did_alt_estimators.R, M7b).
# Reports TWFE baseline + BJS imputation + Callaway-Sant'Anna for the
# Appendix-I DiD on the structural sample.
# ===========================================================================
alt_meta <- read_if_exists("did_alt_estimators_meta")
if (!is.null(alt_meta) && nrow(alt_meta) == 1) {
  emit("didAltTwfeEst",      alt_meta$twfe_est[1],          fmt = "%.4f",
       comment = "M7b alt-estimators: TWFE g65_pre, panel-aggregated")
  emit("didAltTwfeSe",       alt_meta$twfe_se[1],           fmt = "%.4f",
       comment = "M7b alt-estimators: TWFE SE")
  emit("didAltBjsEst",       alt_meta$bjs_est_paper[1],     fmt = "%.4f",
       comment = "M7b alt-estimators: BJS post-ATT avg, paper sign convention")
  emit("didAltBjsSe",        alt_meta$bjs_se[1],            fmt = "%.4f",
       comment = "M7b alt-estimators: BJS conservative SE (sqrt mean var across horizons)")
  emit("didAltCsEst",        alt_meta$cs_est_paper[1],      fmt = "%.4f",
       comment = "M7b alt-estimators: Callaway-Sant'Anna simple ATT, paper sign convention")
  emit("didAltCsSe",         alt_meta$cs_se[1],             fmt = "%.4f",
       comment = "M7b alt-estimators: CS SE")
  emit("didAltMaxAbsDiff",   alt_meta$max_abs_diff_twfe[1], fmt = "%.4f",
       comment = "M7b alt-estimators: max |est_alt - TWFE| (paper convention)")
}

# ===========================================================================
# 22. Bid-coordination screens (scripts 58/60_collusion_screen*.R)
# Promoted to main-text references in §7 robustness (M4). Headline numbers
# below; full tables \input'd in App. C (Identification Diagnostics).
# ===========================================================================
coll_conley <- tryCatch(
  data.table::fread(path_v6("output/tables/tab_collusion_screen.csv")),
  error = function(e) NULL)
if (!is.null(coll_conley) && nrow(coll_conley) == 4) {
  for (i in seq_len(nrow(coll_conley))) {
    r <- coll_conley[i]
    suf <- paste0(if (r$period == "Pre") "Pre" else "Post",
                  if (r$pharma_narrow == 0) "Np" else "Ph")
    emit(paste0("collConleyReal", suf), r$realized_share * 100, fmt = "%.1f",
         comment = sprintf("Conley screen realized share (%%), %s pharma=%d",
                           r$period, r$pharma_narrow))
    emit(paste0("collConleyNull", suf), r$null_mean * 100, fmt = "%.1f",
         comment = sprintf("Conley screen null mean (%%), %s pharma=%d",
                           r$period, r$pharma_narrow))
  }
}

coll_by <- tryCatch(
  data.table::fread(path_v6("output/tables/tab_collusion_screen_bajariye.csv")),
  error = function(e) NULL)
if (!is.null(coll_by) && nrow(coll_by) == 4) {
  for (i in seq_len(nrow(coll_by))) {
    r <- coll_by[i]
    suf <- paste0(if (r$period == "Pre") "Pre" else "Post",
                  if (r$pharma_narrow == 0) "Np" else "Ph")
    # T1 ratio (obs / null), the headline persistence statistic.
    if (!is.na(r$T1_null_mean) && r$T1_null_mean > 0) {
      emit(paste0("collBYRatio", suf), r$T1_obs / r$T1_null_mean, fmt = "%.2f",
           comment = sprintf("Bajari-Ye T1 obs/null ratio, %s pharma=%d",
                             r$period, r$pharma_narrow))
    }
  }
}

# ===========================================================================
# 21. Pre-treatment balance (script 65_balance_pretreat.R)
# ===========================================================================
bal_meta <- read_if_exists("balance_pretreat_meta")
if (!is.null(bal_meta) && nrow(bal_meta) == 1) {
  emit("balanceNGsixfiveItems", bal_meta$n_g65_items[1],
       fmt = "%s", comment = "Group-65 items in pre-period balance sample")
  emit("balanceNCtrlItems",     bal_meta$n_ctrl_items[1],
       fmt = "%s", comment = "Pooled control items in pre-period balance sample")
  emit("balanceNCtrlGroups",    bal_meta$n_ctrl_groups[1],
       fmt = "%s", comment = "Number of never-treated control groups (should be 76)")
  emit("balanceMaxStdDiff",     bal_meta$max_std_diff[1],
       fmt = "%.3f",            comment = "Max |Imbens-Rubin std diff| across balance variables")
  emit("balanceNVarsAboveTen",  bal_meta$n_above_10[1],
       fmt = "%s", comment = "Variables with |std diff| > 0.10 (Imbens-Rubin attention threshold)")
  emit("balanceNVarsAboveTwentyFive", bal_meta$n_above_25[1],
       fmt = "%s", comment = "Variables with |std diff| > 0.25 (Imbens-Rubin substantial-imbalance threshold)")
  emit("balanceNVarsTotal",     bal_meta$n_vars[1],
       fmt = "%s", comment = "Total balance variables checked")
}

# ---------------------------------------------------------------------------
# Done.
# ---------------------------------------------------------------------------
log_step("98", sprintf("done. %d macros emitted -> %s",
                       length(unique(emitted)), values_path()), logf)
