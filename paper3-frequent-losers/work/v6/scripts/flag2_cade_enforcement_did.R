# ============================================================================
# flag2_cade_enforcement_did.R — CADE enforcement DiD (v6)
# Paper 3 v6: Frequent Losers in Public Procurement
# ============================================================================
# Purpose: Test whether FL firms exit and prices fall after CADE cartel
#          convictions using staggered DiD on market-level panel.
#
# Design:
#   Unit:      market = item_2digit × pbu (11-char purchasing unit)
#   Period:    year (2009–2019)
#   Treatment: market ever had a CADE-convicted firm participating
#   Timing:    first conviction year for any convicted firm in that market
#   Outcomes:  (1) log mean negotiated price, (2) FL count per market-year
#
# Strategy (in order of preference):
#   1. Callaway-Sant'Anna (did package) with never-treated control
#   2. Sun-Abraham (fixest) staggered TWFE
#   3. Simple TWFE with fixest (cohort × post indicator)
#   4. Two-period collapsed DiD
#   If data too sparse: write FLAG_cade_did.txt and exit.
#
# Outputs:
#   work/v6/images/fig_cade_enforcement_did.pdf
#   work/v6/tables/cade_did_att.csv
#   work/v6/FLAG_cade_did.txt  (only if data insufficient)
# ============================================================================

cat("=== flag2_cade_enforcement_did.R: CADE enforcement DiD ===\n")

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(fixest)
  library(ggplot2)
})

# ---- Path constants ---------------------------------------------------------
BASE_DIR  <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
DATA_DIR  <- file.path(BASE_DIR, "data", "processed")
V6_DIR    <- file.path(BASE_DIR, "work", "v6")
OUT_IMG   <- file.path(V6_DIR, "images")
OUT_TAB   <- file.path(V6_DIR, "tables")
FLAG_DIR  <- V6_DIR

dir.create(OUT_IMG, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_TAB, recursive = TRUE, showWarnings = FALSE)

NCORES <- min(parallel::detectCores(logical = FALSE), 16L)
setDTthreads(NCORES)
setFixest_nthreads(NCORES)
setFixest_estimation(lean = TRUE)

# ---- Helper: write flag and exit --------------------------------------------
write_flag <- function(msg) {
  flag_path <- file.path(FLAG_DIR, "FLAG_cade_did.txt")
  writeLines(c(
    paste("FLAG generated:", Sys.time()),
    "",
    msg
  ), flag_path)
  cat("FLAG written to:", flag_path, "\n")
  cat(msg, "\n")
}

# ---- Helper: normalise CNPJ to 14-digit zero-padded string -----------------
clean_cnpj <- function(x) {
  # Remove dots, slashes, dashes, whitespace; zero-pad to 14 chars
  x <- gsub("[^0-9]", "", as.character(x))
  x <- ifelse(nchar(x) > 0, formatC(as.numeric(x), width = 14, flag = "0"), NA_character_)
  x
}

# ============================================================================
# 1. LOAD CADE DATA
# ============================================================================
cat("\n--- 1. Loading CADE data ---\n")

CADE_CSV       <- file.path(DATA_DIR, "cade_carteis_licitacoes_2009_2019.csv")
CROSSMATCH_CSV <- file.path(DATA_DIR, "cade_bec_crossmatch.csv")
COBIDDERS_CSV  <- file.path(DATA_DIR, "cade_fl_cobidders.csv")

if (!file.exists(CADE_CSV) || !file.exists(CROSSMATCH_CSV)) {
  write_flag(paste(
    "Missing required CADE files.",
    "Expected:", CADE_CSV, "and", CROSSMATCH_CSV
  ))
  quit(save = "no", status = 0)
}

cade_raw    <- as.data.table(read.csv(CADE_CSV,    stringsAsFactors = FALSE))
crossmatch  <- as.data.table(read.csv(CROSSMATCH_CSV, stringsAsFactors = FALSE))

cat("  cade_raw rows:", nrow(cade_raw), "\n")
cat("  crossmatch rows:", nrow(crossmatch), "\n")

# Parse conviction year from data_julgamento (format: YYYY-MM-DD)
cade_raw[, conviction_year := as.integer(substr(trimws(data_julgamento), 1, 4))]

# Keep only rows with a valid conviction year AND a CNPJ
cade_firms <- cade_raw[
  !is.na(conviction_year) & conviction_year >= 2009 & conviction_year <= 2019 &
  nchar(trimws(cnpj)) > 0,
  .(cnpj, numero_processo, conviction_year, setor)
]
cade_firms[, cnpj_clean := clean_cnpj(cnpj)]
cade_firms <- cade_firms[!is.na(cnpj_clean)]
cat("  CADE firms with valid CNPJ & conviction year:", nrow(cade_firms), "\n")

# Crossmatch: firm_cnpj + processo → conviction year via merge
crossmatch[, cnpj_clean := clean_cnpj(firm_cnpj)]
crossmatch[, processo_clean := trimws(processo)]
cade_firms[, processo_clean := trimws(numero_processo)]

# Merge crossmatch with cade_raw to get conviction years for crossmatched firms
# (cade_raw has the conviction year; crossmatch has BEC firm identifiers)
cade_proc_year <- unique(cade_firms[, .(processo_clean, conviction_year)])
crossmatch_conv <- merge(
  crossmatch[, .(cnpj_clean, processo_clean, setor)],
  cade_proc_year,
  by = "processo_clean",
  all.x = TRUE
)
# For cases where processo is "IT_DF" or non-standard, try direct year from cade_raw
# Fill NAs by looking up firm_cnpj directly in cade_firms
direct_year <- unique(cade_firms[, .(cnpj_clean, conviction_year_direct = conviction_year)])
# Keep minimum conviction year per firm
direct_year <- direct_year[, .(conviction_year_direct = min(conviction_year_direct, na.rm = TRUE)),
                            by = cnpj_clean]
crossmatch_conv <- merge(crossmatch_conv, direct_year, by = "cnpj_clean", all.x = TRUE)
crossmatch_conv[is.na(conviction_year), conviction_year := conviction_year_direct]
crossmatch_conv[, conviction_year_direct := NULL]

# Earliest conviction year per BEC firm
firm_conv <- crossmatch_conv[
  !is.na(conviction_year),
  .(conviction_year = min(conviction_year, na.rm = TRUE)),
  by = cnpj_clean
]
cat("  Crossmatched firms with conviction year:", nrow(firm_conv), "\n")

if (nrow(firm_conv) == 0) {
  write_flag(paste(
    "No crossmatched CADE firms have a valid conviction year in 2009-2019.",
    "Cannot construct treatment timing. DiD not feasible."
  ))
  quit(save = "no", status = 0)
}

# ============================================================================
# 2. LOAD BEC COLLAPSE DATA — extract market identifiers
# ============================================================================
cat("\n--- 2. Loading BEC collapse data ---\n")

BEC_PARQUET <- file.path(DATA_DIR, "BEC_collapse_final.parquet")
FTM_PARQUET <- file.path(DATA_DIR, "firm_tender_map.parquet")
LOSERS_PARQUET <- file.path(DATA_DIR, "LOSERS_rebuilt.parquet")
FP_PARQUET  <- file.path(DATA_DIR, "FREQ_PARTICIP_rebuilt.parquet")

if (!file.exists(BEC_PARQUET)) {
  write_flag(paste("Missing BEC_collapse_final.parquet at", BEC_PARQUET))
  quit(save = "no", status = 0)
}

# Read only needed columns from BEC collapse
cat("  Reading BEC_collapse_final.parquet ...\n")
bec_cols <- c("po_item_merge_key", "preconegociado", "quantidadeentregue",
              "po_phase_code", "numerodaoc", "códigoitem")
bec_schema <- schema(read_parquet(BEC_PARQUET, as_data_frame = FALSE))
avail_cols <- names(bec_schema)
cat("  Available columns:", paste(avail_cols, collapse = ", "), "\n")

use_cols <- intersect(bec_cols, avail_cols)
bec <- as.data.table(read_parquet(BEC_PARQUET, col_select = all_of(use_cols)))
cat("  BEC rows loaded:", formatC(nrow(bec), big.mark = ","), "\n")

# ---- Extract keys from po_item_merge_key ------------------------------------
# Layout per CLAUDE.md:
#   chars  1-11 : PBU code (códigounidadecompradora)
#   chars 12-15 : year
#   chars 16-17 : "OC"
#   chars 18-22 : OC sequence number
#   chars 23+   : item_code + phase + description
bec[, pbu        := substr(po_item_merge_key, 1, 11)]
bec[, year_chr   := substr(po_item_merge_key, 12, 15)]
bec[, year       := suppressWarnings(as.integer(year_chr))]

# item_code: use códigoitem if available, else parse from key
if ("códigoitem" %in% names(bec)) {
  bec[, item_code := as.character(códigoitem)]
} else {
  bec[, item_code := substr(po_item_merge_key, 23, nchar(po_item_merge_key))]
}

# 2-digit item category
bec[, item_2digit := substr(item_code, 1, 2)]

# Price: preconegociado (negotiated price per unit)
if ("preconegociado" %in% names(bec)) {
  bec[, price := suppressWarnings(as.numeric(preconegociado))]
} else {
  # fallback: no price column available
  bec[, price := NA_real_]
}

# Phase filter: keep phases 2 (Convite) and 3 (Pregão)
if ("po_phase_code" %in% names(bec)) {
  bec <- bec[po_phase_code %in% c(2, 3)]
}

# Keep valid years
bec <- bec[!is.na(year) & year >= 2009 & year <= 2019]
bec <- bec[nchar(pbu) == 11 & nchar(item_2digit) >= 1]
cat("  BEC rows after filters:", formatC(nrow(bec), big.mark = ","), "\n")

# OC identifier for joining with firm-tender map
if ("numerodaoc" %in% names(bec)) {
  bec[, oc_code := as.character(numerodaoc)]
} else {
  bec[, oc_code := substr(po_item_merge_key, 18, 22)]
}

# ============================================================================
# 3. LOAD FIRM-TENDER MAP — identify which CADE firms participated where
# ============================================================================
cat("\n--- 3. Loading firm-tender map ---\n")

if (!file.exists(FTM_PARQUET)) {
  write_flag(paste("Missing firm_tender_map.parquet at", FTM_PARQUET))
  quit(save = "no", status = 0)
}

ftm_schema <- schema(read_parquet(FTM_PARQUET, as_data_frame = FALSE))
ftm_cols_avail <- names(ftm_schema)
cat("  firm_tender_map columns:", paste(ftm_cols_avail, collapse = ", "), "\n")

# We need: firm CNPJ, OC identifier, item identifier
# Typical columns: códigofornecedor, numerodaoc, códigoitem (or oc_code, item_code)
need_ftm <- c("códigofornecedor", "numerodaoc", "códigoitem")
alt_ftm  <- c("firm_cnpj", "oc_code", "item_code")
use_ftm  <- if (all(need_ftm %in% ftm_cols_avail)) need_ftm else
            if (all(alt_ftm  %in% ftm_cols_avail)) alt_ftm  else
            intersect(c(need_ftm, alt_ftm), ftm_cols_avail)

cat("  Using FTM columns:", paste(use_ftm, collapse = ", "), "\n")

ftm <- as.data.table(read_parquet(FTM_PARQUET, col_select = all_of(use_ftm)))
cat("  FTM rows:", formatC(nrow(ftm), big.mark = ","), "\n")

# Standardise column names
if ("códigofornecedor" %in% names(ftm)) setnames(ftm, "códigofornecedor", "firm_cnpj_raw")
if ("firm_cnpj"        %in% names(ftm)) setnames(ftm, "firm_cnpj",        "firm_cnpj_raw")
if ("numerodaoc"  %in% names(ftm)) setnames(ftm, "numerodaoc",  "oc_code")
if ("códigoitem"  %in% names(ftm)) setnames(ftm, "códigoitem",  "item_code_ftm")

ftm[, cnpj_clean := clean_cnpj(firm_cnpj_raw)]
ftm[, oc_code    := as.character(oc_code)]
ftm[, item_code_ftm := as.character(item_code_ftm)]

# Keep only CADE firms
cade_cnpjs <- unique(firm_conv$cnpj_clean)
ftm_cade <- ftm[cnpj_clean %in% cade_cnpjs]
cat("  FTM rows for CADE firms:", formatC(nrow(ftm_cade), big.mark = ","), "\n")
rm(ftm); gc(verbose = FALSE)

if (nrow(ftm_cade) == 0) {
  write_flag(paste(
    "No CADE-convicted firms found in firm_tender_map.parquet.",
    "CNPJ matching failed. Cannot identify treated markets.",
    "CADE CNPJs checked:", paste(head(cade_cnpjs, 10), collapse = ", ")
  ))
  quit(save = "no", status = 0)
}

# ============================================================================
# 4. LOAD FL DATA (LOSERS + FREQ_PARTICIP) — secondary outcome
# ============================================================================
cat("\n--- 4. Loading FL data ---\n")

has_losers <- file.exists(LOSERS_PARQUET)
has_fp     <- file.exists(FP_PARQUET)

fl_count_per_oc <- NULL

if (has_losers) {
  losers_raw <- as.data.table(read_parquet(LOSERS_PARQUET))
  cat("  LOSERS columns:", paste(names(losers_raw), collapse = ", "), "\n")
  # Typical cols: numerodaoc, códigoitem, fl_count (or n_fl, losers_count, etc.)
  fl_col <- intersect(c("fl_count", "n_fl", "losers_count", "num_fl",
                        "frequentes_perdedores"), names(losers_raw))
  oc_col_l  <- intersect(c("numerodaoc", "oc_code"), names(losers_raw))
  item_col_l <- intersect(c("códigoitem", "item_code"), names(losers_raw))
  if (length(fl_col) > 0 && length(oc_col_l) > 0 && length(item_col_l) > 0) {
    fl_col   <- fl_col[1]
    oc_col_l <- oc_col_l[1]
    item_col_l <- item_col_l[1]
    losers_sub <- losers_raw[, .SD, .SDcols = c(oc_col_l, item_col_l, fl_col)]
    setnames(losers_sub, c(oc_col_l, item_col_l, fl_col),
             c("oc_code", "item_code_l", "fl_count"))
    losers_sub[, oc_code := as.character(oc_code)]
    fl_count_per_oc <- losers_sub
    cat("  FL count data loaded:", nrow(fl_count_per_oc), "rows\n")
  } else {
    cat("  WARNING: LOSERS columns not as expected — FL secondary outcome skipped\n")
  }
  rm(losers_raw); gc(verbose = FALSE)
}

# IQR threshold for FL (median + 1.5 * IQR, NOT Tukey Q3)
fl_threshold <- NA_real_
if (has_fp) {
  fp <- as.data.table(read_parquet(FP_PARQUET))
  tc_col <- intersect(c("tenders_count", "tenders_count_fp", "n_tenders"),
                      names(fp))
  if (length(tc_col) > 0) {
    tc <- fp[[tc_col[1]]]
    tc <- tc[!is.na(tc) & is.finite(tc)]
    fl_threshold <- median(tc) + 1.5 * IQR(tc)
    cat(sprintf("  FL threshold (median + 1.5*IQR): %.1f\n", fl_threshold))
  }
  rm(fp); gc(verbose = FALSE)
}

# ============================================================================
# 5. CONSTRUCT MARKET × YEAR PANEL
# ============================================================================
cat("\n--- 5. Constructing market-year panel ---\n")

# 5a. Market-year price aggregate from BEC collapse
bec[, log_price := log(price)]
bec[is.infinite(log_price) | is.nan(log_price), log_price := NA_real_]

# Market = item_2digit × pbu
market_price <- bec[
  !is.na(log_price) & is.finite(log_price),
  .(log_price = mean(log_price, na.rm = TRUE),
    n_tenders  = .N),
  by = .(item_2digit, pbu, year)
]
cat("  Market-year cells:", formatC(nrow(market_price), big.mark = ","), "\n")

# 5b. Merge FL count into market-year if available
if (!is.null(fl_count_per_oc) && nrow(fl_count_per_oc) > 0) {
  # Join FL counts via BEC key (oc_code + item_code → pbu + year via bec)
  bec_keys <- unique(bec[, .(oc_code, pbu, year, item_2digit,
                              item_code = item_code)])
  fl_join <- merge(fl_count_per_oc,
                   bec_keys[, .(oc_code, pbu, year, item_2digit)],
                   by = "oc_code", all.x = FALSE)
  market_fl <- fl_join[, .(fl_count = sum(fl_count, na.rm = TRUE)),
                       by = .(item_2digit, pbu, year)]
  market_price <- merge(market_price, market_fl,
                        by = c("item_2digit", "pbu", "year"), all.x = TRUE)
  market_price[is.na(fl_count), fl_count := 0L]
  cat("  FL count merged into panel\n")
} else {
  market_price[, fl_count := NA_integer_]
}

# 5c. Identify treated markets via CADE firm participation
# Join CADE FTM with BEC to get (item_2digit, pbu) for each CADE participation
bec_mkt <- unique(bec[, .(oc_code, pbu, item_2digit)])
ftm_cade[, oc_code := as.character(oc_code)]
cade_mkt <- merge(
  ftm_cade[, .(cnpj_clean, oc_code)],
  bec_mkt,
  by = "oc_code",
  all.x = FALSE
)
cade_mkt <- merge(cade_mkt, firm_conv, by = "cnpj_clean", all.x = TRUE)
cade_mkt <- cade_mkt[!is.na(conviction_year)]

cat("  CADE market-participations matched:", nrow(cade_mkt), "\n")

if (nrow(cade_mkt) == 0) {
  write_flag(paste(
    "CADE firm participations could not be matched to BEC markets.",
    "OC-level join between firm_tender_map and BEC_collapse yielded zero rows.",
    "Possible cause: oc_code formatting mismatch between datasets."
  ))
  quit(save = "no", status = 0)
}

# Treatment timing: first conviction year of any CADE firm per market
treat_timing <- cade_mkt[, .(first_treat_year = min(conviction_year, na.rm = TRUE)),
                          by = .(item_2digit, pbu)]
n_treated <- nrow(treat_timing)
cat("  Treated markets:", n_treated, "\n")

if (n_treated < 5) {
  write_flag(paste(
    "Only", n_treated, "treated markets identified — insufficient for DiD.",
    "Minimum requirement: 5 treated markets.",
    "Check CNPJ matching between CADE crossmatch and firm_tender_map."
  ))
  quit(save = "no", status = 0)
}

# Merge treatment timing into market panel
panel <- merge(market_price, treat_timing,
               by = c("item_2digit", "pbu"), all.x = TRUE)

# Never-treated markets: first_treat_year = 0 (convention for did package)
# In fixest/staggered: NA = never treated, which we keep as NA
panel[, treated := as.integer(!is.na(first_treat_year))]
panel[, post    := as.integer(!is.na(first_treat_year) & year >= first_treat_year)]

# Unit identifier (market_id)
panel[, market_id := .GRP, by = .(item_2digit, pbu)]
setkey(panel, market_id, year)

n_control   <- uniqueN(panel[treated == 0, market_id])
n_treat_obs <- uniqueN(panel[treated == 1, market_id])
cat(sprintf("  Panel: %s obs | %s markets (%s treated, %s never-treated)\n",
            formatC(nrow(panel), big.mark = ","),
            formatC(uniqueN(panel$market_id), big.mark = ","),
            n_treat_obs, n_control))

if (n_control < 10) {
  write_flag(paste(
    "Insufficient never-treated control markets:", n_control,
    ". Need at least 10 for DiD. Treated:", n_treat_obs
  ))
  quit(save = "no", status = 0)
}

# ============================================================================
# 6. STAGGERED DiD ESTIMATION
# ============================================================================
cat("\n--- 6. Staggered DiD estimation ---\n")

# Cohort dummies for Sun-Abraham / TWFE
# g = first_treat_year; g = 0 for never-treated
panel[, g := fifelse(is.na(first_treat_year), 0L,
                     as.integer(first_treat_year))]

method_used <- "none"
cs_result   <- NULL
sa_result   <- NULL
twfe_result <- NULL

# ---- 6a. Callaway-Sant'Anna (preferred) ------------------------------------
cs_ok <- requireNamespace("did", quietly = TRUE)
if (cs_ok) {
  cat("  Attempting Callaway-Sant'Anna (did package)...\n")
  tryCatch({
    # did package requires: idname, tname, gname, yname, data
    # gname = 0 for never-treated
    panel_df <- as.data.frame(panel[!is.na(log_price)])
    cs_out <- did::att_gt(
      yname        = "log_price",
      tname        = "year",
      idname       = "market_id",
      gname        = "g",
      data         = panel_df,
      control_group = "nevertreated",
      est_method   = "reg",
      panel        = TRUE,
      allow_unbalanced_panel = TRUE,
      print_details = FALSE
    )
    cs_agg <- did::aggte(cs_out, type = "dynamic",
                         min_e = -4, max_e = 4,
                         na.rm = TRUE)
    cs_att  <- did::aggte(cs_out, type = "simple", na.rm = TRUE)
    cs_result <- list(att_gt = cs_out, dynamic = cs_agg, simple = cs_att)
    method_used <- "callaway_santanna"
    cat("  C&S succeeded. Overall ATT:", round(cs_att$overall.att, 4),
        "SE:", round(cs_att$overall.se, 4), "\n")
  }, error = function(e) {
    cat("  C&S failed:", conditionMessage(e), "\n")
  })
}

# ---- 6b. Sun-Abraham via fixest --------------------------------------------
if (method_used == "none") {
  cat("  Attempting Sun-Abraham (fixest::feols sunab)...\n")
  tryCatch({
    panel_sa <- panel[!is.na(log_price) & g != 0 | (treated == 0)]
    # sunab requires never-treated coded as Inf
    panel_sa[, g_sa := fifelse(g == 0L, Inf, as.numeric(g))]
    sa_out <- feols(
      log_price ~ sunab(g_sa, year) | market_id + year,
      data    = panel_sa,
      cluster = ~market_id,
      lean    = FALSE   # need coefs for event study
    )
    sa_result   <- sa_out
    method_used <- "sun_abraham"
    cat("  Sun-Abraham succeeded.\n")
  }, error = function(e) {
    cat("  Sun-Abraham failed:", conditionMessage(e), "\n")
  })
}

# ---- 6c. TWFE fallback -----------------------------------------------------
if (method_used == "none") {
  cat("  Falling back to TWFE (post × treated indicator)...\n")
  tryCatch({
    twfe_out <- feols(
      log_price ~ post | market_id + year,
      data    = panel[!is.na(log_price)],
      cluster = ~market_id,
      lean    = TRUE
    )
    twfe_result <- twfe_out
    method_used <- "twfe"
    coef_post <- coef(twfe_out)["post"]
    se_post   <- se(twfe_out)["post"]
    cat(sprintf("  TWFE succeeded. Coef(post): %.4f  SE: %.4f\n",
                coef_post, se_post))
  }, error = function(e) {
    cat("  TWFE failed:", conditionMessage(e), "\n")
  })
}

# ---- 6d. Two-period DiD as last resort -------------------------------------
if (method_used == "none") {
  cat("  Falling back to two-period DiD...\n")
  tryCatch({
    panel2 <- panel[!is.na(log_price) & !is.na(first_treat_year)]
    # pre = mean of years < first_treat_year, post = mean of years >= first_treat_year
    panel2[, period := fifelse(year >= first_treat_year, 1L, 0L)]
    tp_treated  <- panel2[treated == 1, .(y = mean(log_price)), by = period]
    tp_control  <- panel[treated == 0 & !is.na(log_price),
                          .(y = mean(log_price)), by = .(period = 0L)]
    # Simple 2x2: (post_treat - pre_treat) - (post_ctrl - pre_ctrl)
    pre_t  <- tp_treated[period == 0, y]
    post_t <- tp_treated[period == 1, y]
    pre_c  <- panel[treated == 0 & !is.na(log_price), mean(log_price)]
    att_2p <- (post_t - pre_t) - 0   # no control post period available cleanly
    cat(sprintf("  Two-period DiD ATT (approx): %.4f\n", att_2p))
    method_used <- "two_period"
    twfe_result <- list(att = att_2p)
  }, error = function(e) {
    cat("  Two-period DiD failed:", conditionMessage(e), "\n")
  })
}

if (method_used == "none") {
  write_flag(paste(
    "All estimation methods failed.",
    "Panel has", nrow(panel), "obs,", n_treat_obs, "treated markets,",
    n_control, "never-treated markets.",
    "Check log for individual method errors."
  ))
  quit(save = "no", status = 0)
}

cat("\n  Estimation method used:", method_used, "\n")

# ============================================================================
# 7. FL COUNT AS SECONDARY OUTCOME (if available)
# ============================================================================
fl_did_result <- NULL

has_fl_outcome <- !all(is.na(panel$fl_count))
if (has_fl_outcome) {
  cat("\n--- 7. FL count secondary outcome ---\n")
  panel[, log_fl_count := log1p(as.numeric(fl_count))]

  tryCatch({
    fl_twfe <- feols(
      log_fl_count ~ post | market_id + year,
      data    = panel[!is.na(log_fl_count)],
      cluster = ~market_id,
      lean    = TRUE
    )
    fl_did_result <- fl_twfe
    cat(sprintf("  FL count TWFE: coef(post)=%.4f  SE=%.4f\n",
                coef(fl_twfe)["post"], se(fl_twfe)["post"]))
  }, error = function(e) {
    cat("  FL count TWFE failed:", conditionMessage(e), "\n")
  })
}

# ============================================================================
# 8. BUILD EVENT STUDY DATA FOR PLOTTING
# ============================================================================
cat("\n--- 8. Building event study data ---\n")

es_dt <- NULL

if (method_used == "callaway_santanna" && !is.null(cs_result)) {
  dyn <- cs_result$dynamic
  es_dt <- data.table(
    event_time  = dyn$egt,
    att         = dyn$att.egt,
    se          = dyn$se.egt,
    ci_lo       = dyn$att.egt - 1.96 * dyn$se.egt,
    ci_hi       = dyn$att.egt + 1.96 * dyn$se.egt,
    method      = "Callaway-Sant'Anna"
  )
} else if (method_used == "sun_abraham" && !is.null(sa_result)) {
  # Extract event-time coefficients from sunab
  cf  <- coef(sa_result)
  se_v <- se(sa_result)
  nms <- names(cf)
  # sunab coefs are named like "year::XXXX:cohort::YYYY" or "cohort_rel_time::N"
  # Use iplot-style extraction
  tryCatch({
    ip <- iplot(sa_result, drop.section = NULL, plot = FALSE)
    es_dt <- data.table(
      event_time = as.numeric(ip$prms$x),
      att        = ip$prms$y,
      se         = (ip$prms$ci_high - ip$prms$ci_low) / (2 * 1.96),
      ci_lo      = ip$prms$ci_low,
      ci_hi      = ip$prms$ci_high,
      method     = "Sun-Abraham"
    )
  }, error = function(e) {
    cat("  iplot extraction failed:", conditionMessage(e), "\n")
    # Manual: look for rel_year pattern
    rel_idx <- grep("rel_year|::[-0-9]", nms)
    if (length(rel_idx) > 0) {
      et <- as.numeric(gsub(".*::([-0-9]+).*", "\\1", nms[rel_idx]))
      es_dt <<- data.table(
        event_time = et,
        att        = cf[rel_idx],
        se         = se_v[rel_idx],
        ci_lo      = cf[rel_idx] - 1.96 * se_v[rel_idx],
        ci_hi      = cf[rel_idx] + 1.96 * se_v[rel_idx],
        method     = "Sun-Abraham"
      )
    }
  })
} else if (method_used == "twfe" && !is.null(twfe_result) &&
           inherits(twfe_result, "fixest")) {
  # For plain TWFE we create a two-point event study: pre (t=-1) and post (t=0+)
  cf_post <- coef(twfe_result)["post"]
  se_post <- se(twfe_result)["post"]
  es_dt <- data.table(
    event_time = c(-1L, 0L),
    att        = c(0, cf_post),
    se         = c(0, se_post),
    ci_lo      = c(0, cf_post - 1.96 * se_post),
    ci_hi      = c(0, cf_post + 1.96 * se_post),
    method     = "TWFE (two-period)"
  )
}

# ============================================================================
# 9. SAVE ATT TABLE
# ============================================================================
cat("\n--- 9. Saving ATT table ---\n")

att_rows <- list()

if (method_used == "callaway_santanna" && !is.null(cs_result)) {
  att_rows[["price_overall"]] <- data.table(
    outcome       = "log_price",
    method        = "Callaway-Sant'Anna",
    estimand      = "ATT (overall)",
    att           = cs_result$simple$overall.att,
    se            = cs_result$simple$overall.se,
    ci_lo         = cs_result$simple$overall.att - 1.96 * cs_result$simple$overall.se,
    ci_hi         = cs_result$simple$overall.att + 1.96 * cs_result$simple$overall.se,
    n_treated_mkts = n_treat_obs,
    n_control_mkts = n_control
  )
} else if (method_used %in% c("sun_abraham", "twfe") &&
           inherits(twfe_result %||% sa_result, "fixest")) {
  obj <- if (!is.null(sa_result)) sa_result else twfe_result
  cf  <- coef(obj)
  se_v <- se(obj)
  pv  <- pvalue(obj)
  # Primary coefficient
  pk <- names(cf)[1]
  att_rows[["price_overall"]] <- data.table(
    outcome        = "log_price",
    method         = method_used,
    estimand       = "ATT",
    att            = cf[[pk]],
    se             = se_v[[pk]],
    ci_lo          = cf[[pk]] - 1.96 * se_v[[pk]],
    ci_hi          = cf[[pk]] + 1.96 * se_v[[pk]],
    n_treated_mkts = n_treat_obs,
    n_control_mkts = n_control
  )
} else if (method_used == "two_period" && is.list(twfe_result)) {
  att_rows[["price_overall"]] <- data.table(
    outcome        = "log_price",
    method         = "two_period_did",
    estimand       = "ATT (approx)",
    att            = twfe_result$att,
    se             = NA_real_,
    ci_lo          = NA_real_,
    ci_hi          = NA_real_,
    n_treated_mkts = n_treat_obs,
    n_control_mkts = n_control
  )
}

if (!is.null(fl_did_result) && inherits(fl_did_result, "fixest")) {
  cf_fl  <- coef(fl_did_result)["post"]
  se_fl  <- se(fl_did_result)["post"]
  att_rows[["fl_overall"]] <- data.table(
    outcome        = "log_fl_count",
    method         = "TWFE",
    estimand       = "ATT",
    att            = cf_fl,
    se             = se_fl,
    ci_lo          = cf_fl - 1.96 * se_fl,
    ci_hi          = cf_fl + 1.96 * se_fl,
    n_treated_mkts = n_treat_obs,
    n_control_mkts = n_control
  )
}

att_tbl <- rbindlist(att_rows, fill = TRUE)

if (nrow(att_tbl) > 0) {
  att_path <- file.path(OUT_TAB, "cade_did_att.csv")
  fwrite(att_tbl, att_path)
  cat("  ATT table saved:", att_path, "\n")
  print(att_tbl)
}

# ============================================================================
# 10. EVENT STUDY PLOT
# ============================================================================
cat("\n--- 10. Saving event study plot ---\n")

plot_path <- file.path(OUT_IMG, "fig_cade_enforcement_did.pdf")

if (!is.null(es_dt) && nrow(es_dt) > 0) {
  es_dt <- es_dt[order(event_time)]
  method_label <- es_dt$method[1]

  p <- ggplot(es_dt, aes(x = event_time, y = att)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
    geom_vline(xintercept = -0.5, linetype = "dotted", colour = "grey60") +
    geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.20, fill = "steelblue") +
    geom_line(colour = "steelblue3", linewidth = 0.8) +
    geom_point(colour = "steelblue4", size = 2.2) +
    scale_x_continuous(
      breaks = sort(unique(es_dt$event_time)),
      labels = sort(unique(es_dt$event_time))
    ) +
    labs(
      title    = "Effect of CADE Conviction on Log Negotiated Price",
      subtitle = paste0("Event study — ", method_label,
                        " | Treated markets: ", n_treat_obs,
                        " | Never-treated: ", n_control),
      x        = "Years relative to first conviction",
      y        = "ATT (log price)",
      caption  = paste0("Unit: item_2digit × PBU. Period: 2009–2019.\n",
                         "Shaded band = 95% CI. Vertical dotted line = event time 0.")
    ) +
    theme_bw(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      plot.title       = element_text(size = 12, face = "bold"),
      plot.subtitle    = element_text(size = 9, colour = "grey40")
    )

  # Add FL count panel if available
  if (!is.null(fl_did_result) && inherits(fl_did_result, "fixest") &&
      method_used == "twfe") {
    cf_fl <- coef(fl_did_result)["post"]
    se_fl <- se(fl_did_result)["post"]
    es_fl <- data.table(
      event_time = c(-1L, 0L),
      att        = c(0, cf_fl),
      se         = c(0, se_fl),
      ci_lo      = c(0, cf_fl - 1.96 * se_fl),
      ci_hi      = c(0, cf_fl + 1.96 * se_fl)
    )
    p_fl <- ggplot(es_fl, aes(x = event_time, y = att)) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
      geom_vline(xintercept = -0.5, linetype = "dotted", colour = "grey60") +
      geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.20, fill = "tomato") +
      geom_line(colour = "tomato3", linewidth = 0.8) +
      geom_point(colour = "tomato4", size = 2.2) +
      scale_x_continuous(breaks = c(-1L, 0L)) +
      labs(
        title  = "Effect of CADE Conviction on Log(1 + FL Count)",
        x      = "Years relative to first conviction",
        y      = "ATT (log FL count)"
      ) +
      theme_bw(base_size = 11) +
      theme(panel.grid.minor = element_blank())

    pdf(plot_path, width = 10, height = 9)
    gridExtra::grid.arrange(p, p_fl, nrow = 2)
    dev.off()
  } else {
    pdf(plot_path, width = 9, height = 5.5)
    print(p)
    dev.off()
  }
  cat("  Event study plot saved:", plot_path, "\n")

} else {
  # Fallback: summary bar chart showing ATT point estimate with CI
  cat("  Event study data unavailable — saving ATT bar chart\n")
  if (nrow(att_tbl) > 0) {
    p_bar <- ggplot(att_tbl[!is.na(att)],
                    aes(x = outcome, y = att, ymin = ci_lo, ymax = ci_hi)) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
      geom_errorbar(width = 0.2, colour = "steelblue4") +
      geom_point(size = 3, colour = "steelblue4") +
      labs(
        title    = "CADE Enforcement DiD — ATT Estimates",
        subtitle = paste0("Method: ", method_used,
                          " | Treated: ", n_treat_obs,
                          " | Control: ", n_control),
        x = "Outcome", y = "ATT"
      ) +
      theme_bw(base_size = 11)
    pdf(plot_path, width = 7, height = 5)
    print(p_bar)
    dev.off()
    cat("  ATT bar chart saved:", plot_path, "\n")
  } else {
    # Produce a text-only diagnostic plot
    pdf(plot_path, width = 7, height = 4)
    plot.new()
    text(0.5, 0.6,
         paste0("CADE enforcement DiD\n",
                "Method: ", method_used, "\n",
                "Treated markets: ", n_treat_obs, "\n",
                "Never-treated markets: ", n_control, "\n",
                "ATT table: see cade_did_att.csv"),
         cex = 1.0, adj = 0.5)
    dev.off()
    cat("  Diagnostic text plot saved:", plot_path, "\n")
  }
}

# ============================================================================
# 11. SUMMARY DIAGNOSTICS
# ============================================================================
cat("\n=== Summary ===\n")
cat(sprintf("  Method used       : %s\n", method_used))
cat(sprintf("  Treated markets   : %d\n", n_treat_obs))
cat(sprintf("  Control markets   : %d\n", n_control))
cat(sprintf("  Panel obs         : %s\n", formatC(nrow(panel), big.mark = ",")))
cat(sprintf("  ATT table         : %s\n", file.path(OUT_TAB, "cade_did_att.csv")))
cat(sprintf("  Event study plot  : %s\n", plot_path))
if (!all(is.na(panel$fl_count))) {
  cat(sprintf("  FL threshold used : %.1f (median + 1.5*IQR)\n",
              ifelse(is.na(fl_threshold), NA, fl_threshold)))
}
if (nrow(att_tbl) > 0) {
  cat("\n  ATT estimates:\n")
  for (i in seq_len(nrow(att_tbl))) {
    cat(sprintf("    [%s] %s: ATT=%.4f  SE=%.4f\n",
                att_tbl$outcome[i], att_tbl$method[i],
                att_tbl$att[i], ifelse(is.na(att_tbl$se[i]), NA, att_tbl$se[i])))
  }
}

cat("\n=== flag2_cade_enforcement_did.R complete ===\n")
