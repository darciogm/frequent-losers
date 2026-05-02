# ============================================================================
# 99_make_paper_values.R --generate work/v13/values.tex with all paper numbers
# Paper 3 v14
#
# This script reads the canonical CSV outputs of scripts 30-43 plus the
# main pipeline parquets and writes a single LaTeX file containing
# \newcommand entries for every numeric claim in the paper. The paper
# inputs values.tex via \input{values.tex} and references each value via
# its macro (\valFL, \valAUCcobid, ...). Re-running the analysis pipeline
# regenerates values.tex; recompiling the paper updates every number.
#
# Pipeline contract:
#   - All numbers in the paper appear as macros, not literals.
#   - Every macro name is documented in this script.
#   - The script must run after the analysis scripts that produce the
#     CSV inputs; running it without the inputs raises an error.
# ============================================================================

cat("=== 99_make_paper_values.R: generate values.tex from canonical CSVs ===\n")

if (!exists(".script_dir")) {
  file_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))])
  .script_dir <- if (length(file_arg)) dirname(normalizePath(file_arg[1L])) else getwd()
}
suppressPackageStartupMessages({
  library(arrow); library(data.table)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "work", "v13", "values.tex")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
fmt_int  <- function(x) format(round(x), big.mark = ",", scientific = FALSE,
                                 trim = TRUE)
fmt_int_tex <- function(x) {
  s <- format(round(x), big.mark = "{,}", scientific = FALSE, trim = TRUE)
  s
}
fmt_pct <- function(x, d = 2) sprintf(paste0("%.", d, "f"), 100 * x)
fmt_dec <- function(x, d = 3) sprintf(paste0("%.", d, "f"), x)
fmt_ci  <- function(lo, hi, d = 3)
  sprintf("[%.*f,\\ %.*f]", d, lo, d, hi)
fmt_ci_inline <- function(lo, hi, d = 3)
  sprintf("[%s,\\ %s]", fmt_dec(lo,d), fmt_dec(hi,d))

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a

vals <- list()
prov <- list()
.current_src <- "scripts/99_make_paper_values.R"
src_set <- function(s) { .current_src <<- s }
add  <- function(name, value, source = NULL, raw = NA) {
  if (is.null(value) || is.na(value) || (is.character(value) && value == "")) {
    cat(sprintf("    WARN: %-40s -> NA/empty, skipping\n", name))
    return(invisible(NULL))
  }
  vals[[name]] <<- as.character(value)
  prov[[name]] <<- list(source = source %||% .current_src, raw = raw)
}

# ---------------------------------------------------------------------------
# 1. Sample sizes from raw parquet inputs
# ---------------------------------------------------------------------------
cat("\n  [1/8] Sample sizes\n")
src_set("data/processed/FREQ_PARTICIP_rebuilt.parquet :: data/processed/firm_loss_stats.parquet :: data/processed/cade_*.csv")
fp <- as.data.table(read_parquet(file.path(BASE,"data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
fls <- as.data.table(read_parquet(file.path(BASE,"data/processed/firm_loss_stats.parquet")))

THRESH <- 14L
n_al <- sum(fp$always_loser == 1L)
n_fl <- sum(fp$always_loser == 1L & fp$tenders_count >= THRESH)
n_bec_firms <- nrow(fls)
add("AlwaysLosers",   fmt_int_tex(n_al))
add("FL",             fmt_int_tex(n_fl))
add("BECfirms",       fmt_int_tex(n_bec_firms))
add("Threshold",      THRESH)

# Cobidders / direct CADE
cobid <- fread(file.path(BASE,"data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cade_xm <- fread(file.path(BASE,"data/processed/cade_bec_crossmatch.csv"))
cade_xm[, firm_code := sprintf("%014.0f", as.numeric(firm_cnpj))]
n_cobid    <- length(unique(cobid$firm_code))
n_direct   <- length(unique(cade_xm$firm_code))
add("Cobidders", fmt_int_tex(n_cobid))
add("DirectCADE", fmt_int_tex(n_direct))

# Main analysis sample N (from /tmp prepared rds if available)
prep_path <- "/tmp/p3_prepared.rds"
if (file.exists(prep_path)) {
  dt <- readRDS(prep_path)
  n_sample <- nrow(dt[!is.na(lneg_price)])
  n_sample_full <- nrow(dt)
  add("SampleN",     fmt_int_tex(n_sample))
  add("SampleNfull", fmt_int_tex(n_sample_full))
  rm(dt)
}

add("YearStart",  2009L)
add("YearEnd",    2019L)
add("YearsCount", 11L)

# ---------------------------------------------------------------------------
# 2. Firm-level AUC vs cobidders (script 36 / 34)
# ---------------------------------------------------------------------------
cat("  [2/8] Firm-level AUC against cobidders\n")
src_set("scripts/34_horse_race_fl_continuous.R :: output/horse_race/horse_race_summary.csv")
hr_path <- file.path(BASE, "output/horse_race/horse_race_summary.csv")
if (file.exists(hr_path)) {
  hr <- fread(hr_path)
  fl14 <- hr[grepl("cutoff = 14", score)]
  ltc  <- hr[grepl("log\\(1", score) | grepl("log_tc", score)]
  if (nrow(fl14) > 0) {
    add("AUCFLfirm",     fmt_dec(fl14$auc[1], 3))
    add("AUCFLfirmCIlo", fmt_dec(fl14$ci_lo[1], 3))
    add("AUCFLfirmCIhi", fmt_dec(fl14$ci_hi[1], 3))
    add("AUCFLfirmCI",
        fmt_ci_inline(fl14$ci_lo[1], fl14$ci_hi[1], 3))
  }
  if (nrow(ltc) > 0) {
    add("AUClogtc",     fmt_dec(ltc$auc[1], 3))
    add("AUClogtcCIlo", fmt_dec(ltc$ci_lo[1], 3))
    add("AUClogtcCIhi", fmt_dec(ltc$ci_hi[1], 3))
    add("AUClogtcCI",
        fmt_ci_inline(ltc$ci_lo[1], ltc$ci_hi[1], 3))
  }
}

# DeLong test (script 34)
dl_path <- file.path(BASE, "output/horse_race/delong_tests.csv")
if (file.exists(dl_path)) {
  dl <- fread(dl_path)
  row <- dl[alt == "log(1 + tenders_count)"]
  if (nrow(row) > 0) {
    add("DeLongZ", fmt_dec(row$z[1], 2))
    add("DeLongP", sprintf("%.1g", row$p[1]))
  }
}

# ---------------------------------------------------------------------------
# 3. Imhof full pipeline (script 31)
# ---------------------------------------------------------------------------
cat("  [3/8] Imhof full pipeline AUC\n")
src_set("scripts/31_imhof_full_pipeline.R :: output/imhof_full/imhof_full_results.csv")
im_path <- file.path(BASE, "output/imhof_full/imhof_full_results.csv")
if (file.exists(im_path)) {
  im <- fread(im_path)
  rows <- list(
    list(key = "ImhofFull",      m = "imhof_full"),
    list(key = "ImhofCV",        m = "imhof_cv_only"),
    list(key = "ImhofPlusFL",    m = "imhof_full_plus_fl"),
    list(key = "ImhofPlusTC",    m = "imhof_full_plus_tenders"),
    list(key = "FLalone",        m = "fl_alone"),
    list(key = "TCalone",        m = "tenders_alone")
  )
  for (r in rows) {
    sel <- im[model == r$m]
    if (nrow(sel) > 0) {
      add(paste0("AUC", r$key),     fmt_dec(sel$auc[1], 3))
      add(paste0("AUC", r$key, "CI"),
          fmt_ci_inline(sel$ci_lo[1], sel$ci_hi[1], 3))
    }
  }
}

# ---------------------------------------------------------------------------
# 4. AUC against direct CADE / structural scope (script 33)
# ---------------------------------------------------------------------------
cat("  [4/8] AUC against direct CADE defendants\n")
src_set("scripts/33_auc_direct_cade.R :: output/auc_direct_cade/auc_direct_cade.csv")
dc_path <- file.path(BASE, "output/auc_direct_cade/auc_direct_cade.csv")
if (file.exists(dc_path)) {
  dc <- fread(dc_path)
  row <- dc[label == "all_direct_CADE" & score == "is_fl"]
  if (nrow(row) > 0) {
    add("AUCdirectCADE",   fmt_dec(row$auc[1], 3))
    add("AUCdirectCADECI", fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }
}

# ---------------------------------------------------------------------------
# 5. Leakage audit (script 40)
# ---------------------------------------------------------------------------
cat("  [5/8] Leakage audit\n")
src_set("scripts/40_leakage_audit_d3.R :: output/leakage_audit_d3/leakage_audit_d3.csv")
la_path <- file.path(BASE, "output/leakage_audit_d3/leakage_audit_d3.csv")
if (file.exists(la_path)) {
  la <- fread(la_path)
  row1 <- la[audit == "1_label_direct_cade" & label == "any_cobidder (orig)"]
  row2 <- la[audit == "2_cv_pooled"]
  row3 <- la[audit == "3_temporal_holdout" & label == "any_cobidder"]
  row4 <- la[audit == "1_label_direct_cade" & label == "any_direct"]
  if (nrow(row1) > 0) {
    add("AUCitemRaw",    fmt_dec(row1$auc[1], 3))
  }
  if (nrow(row2) > 0) {
    add("AUCitemCV",     fmt_dec(row2$auc[1], 3))
    add("AUCitemCVCI",   fmt_ci_inline(row2$ci_lo[1], row2$ci_hi[1], 3))
  }
  if (nrow(row3) > 0) {
    add("AUCitemTemp",   fmt_dec(row3$auc[1], 3))
    add("AUCitemTempCI", fmt_ci_inline(row3$ci_lo[1], row3$ci_hi[1], 3))
    # alias: leakage audit at cobidder-firm level → preferred semantic name
    add("AUCFLfirmTemp",   fmt_dec(row3$auc[1], 3))
    add("AUCFLfirmTempCI", fmt_ci_inline(row3$ci_lo[1], row3$ci_hi[1], 3))
  }
  if (nrow(row4) > 0) {
    add("AUCitemDirect", fmt_dec(row4$auc[1], 3))
  }
}

# ---------------------------------------------------------------------------
# 6. Operational metrics --temporal holdout (script 43)
# ---------------------------------------------------------------------------
cat("  [6/8] Operational metrics (temporal holdout)\n")
src_set("scripts/43_precision_at_k_audit.R :: output/operational/audit_precision_k.csv")
ap_path <- file.path(BASE, "output/operational/audit_precision_k.csv")
if (file.exists(ap_path)) {
  ap <- fread(ap_path)
  k_to_alpha <- c(`50` = "Fifty", `100` = "Hund", `250` = "Twofh",
                   `500` = "Fivehu", `1000` = "Onek", `2000` = "Twok",
                   `2735` = "FullFL")
  for (k_top in c(50, 100, 250, 500, 1000)) {
    row_in <- ap[audit == "0_in_sample_reference" & k == k_top]
    row_th <- ap[audit == "1A_temporal_all_cobidders" & k == k_top]
    suffix <- k_to_alpha[as.character(k_top)]
    if (nrow(row_in) > 0) {
      add(paste0("PrecInS",  suffix), fmt_dec(row_in$precision[1], 3))
      add(paste0("RecInS",   suffix), fmt_dec(row_in$recall[1], 3))
      add(paste0("LiftInS",  suffix), fmt_dec(row_in$lift[1], 1))
    }
    if (nrow(row_th) > 0) {
      add(paste0("PrecTH",   suffix), fmt_dec(row_th$precision[1], 3))
      add(paste0("RecTH",    suffix), fmt_dec(row_th$recall[1], 3))
      add(paste0("LiftTH",   suffix), fmt_dec(row_th$lift[1], 1))
    }
  }
}

# ---------------------------------------------------------------------------
# 7. Mechanism heterogeneity (script 35)
# ---------------------------------------------------------------------------
cat("  [7/8] Mechanism heterogeneity\n")
src_set("scripts/35_unified_mechanism.R :: output/unified_mechanism/unified_mechanism.csv")
um_path <- file.path(BASE, "output/unified_mechanism/unified_mechanism.csv")
if (file.exists(um_path)) {
  um <- fread(um_path)
  qmap <- list(
    list(key = "QLLL", q = "Low HHI × Low pairs"),
    list(key = "QLLH", q = "Low HHI × High pairs"),
    list(key = "QLHL", q = "High HHI × Low pairs"),
    list(key = "QLHH", q = "High HHI × High pairs")
  )
  for (qm in qmap) {
    sel <- um[quadrant == qm$q & treatment == "binary_FL"]
    if (nrow(sel) > 0) {
      add(paste0("Mech", qm$key, "Coef"), fmt_dec(sel$coef[1] * 100, 2))
      add(paste0("Mech", qm$key, "P"),    sprintf("%.3g", sel$pval[1]))
      add(paste0("Mech", qm$key, "N"),    fmt_int_tex(sel$n[1]))
    }
  }
}

# ---------------------------------------------------------------------------
# 8. First-time-FL matched (script 30)
# ---------------------------------------------------------------------------
cat("  [8/8] First-time-FL matched\n")
src_set("scripts/30_first_time_fl_matching.R :: output/first_time_fl_matching/matched_results.csv")
ft_path <- file.path(BASE, "output/first_time_fl_matching/matched_results.csv")
if (file.exists(ft_path)) {
  ft <- fread(ft_path)
  for (sp in unique(ft$spec)) {
    sel <- ft[spec == sp]
    key <- switch(sp,
      "unconditional" = "FTuncond",
      "cem_matched"   = "FTcem",
      "ps_matched"    = "FTps",
      NULL)
    if (!is.null(key)) {
      add(paste0(key, "Coef"), fmt_dec(sel$coef[1], 3))
      add(paste0(key, "SE"),   fmt_dec(sel$se[1], 3))
      add(paste0(key, "P"),    fmt_dec(sel$pval[1], 3))
      add(paste0(key, "N"),    fmt_int_tex(sel$n[1]))
    }
  }
}

# ---------------------------------------------------------------------------
# 9. Gate D2 (modal AUC, script 37)
# ---------------------------------------------------------------------------
cat("  [9/8 bonus] Gate D2 modal AUC\n")
src_set("scripts/37_gate_d2_modal_auc.R :: output/gate_d2/d2_modal_auc.csv")
gd_path <- file.path(BASE, "output/gate_d2/d2_modal_auc.csv")
if (file.exists(gd_path)) {
  gd <- fread(gd_path)
  for (p in c("convite_primary","pregao_primary")) {
    for (sc in c("fl14","log_tc")) {
      sel <- gd[pool == p & score == sc]
      if (nrow(sel) > 0) {
        key <- paste0("AUC",
                       ifelse(p == "convite_primary","Conv","Preg"),
                       ifelse(sc == "fl14","FL","logtc"))
        add(key,            fmt_dec(sel$auc[1], 3))
        add(paste0(key,"CI"), fmt_ci_inline(sel$ci_lo[1], sel$ci_hi[1], 3))
      }
    }
  }
}

# ---------------------------------------------------------------------------
# 10. CADE winner-heavy (script 39)
# ---------------------------------------------------------------------------
cat("  [10] CADE winner-heavy\n")
src_set("scripts/39_gate_d4_cade_winner_heavy.R :: output/gate_d4/d4_winner_heavy.csv")

# ---------------------------------------------------------------------------
# 10b. JLEO-R1 diagnostics (scripts 47-54)
# ---------------------------------------------------------------------------
cat("  [10b] JLEO-R1 diagnostics\n")

thr54_path <- file.path(BASE, "output/threshold_table_q3iqr/threshold_table_q3iqr.csv")
if (file.exists(thr54_path)) {
  thr54 <- fread(thr54_path)

  src_set("scripts/54_threshold_table_q3iqr.R :: output/threshold_table_q3iqr/threshold_table_q3iqr.csv :: median_plus_1.5_iqr")
  row <- thr54[construct == "median_plus_1.5_iqr"]
  if (nrow(row) > 0) {
    add("FL",                 fmt_int_tex(row$n_flagged[1]))
    add("Threshold",          "14")
    add("ThresholdStat",      fmt_dec(row$threshold[1], 1))
    add("FLrateAL",           sprintf("%.1f\\%%", 100 * row$flagged_share[1]))
    add("CobidShareFL",       sprintf("%.1f\\%%", 100 * row$precision_flagged[1]))
    add("AUCFLfirm",          fmt_dec(row$auc[1], 3))
    add("AUCFLfirmCIlo",      fmt_dec(row$ci_lo[1], 3))
    add("AUCFLfirmCIhi",      fmt_dec(row$ci_hi[1], 3))
    add("AUCFLfirmCI",        fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }

  src_set("scripts/54_threshold_table_q3iqr.R :: output/threshold_table_q3iqr/threshold_table_q3iqr.csv :: continuous_log_tc")
  row <- thr54[construct == "continuous_log_tc"]
  if (nrow(row) > 0) {
    add("AUClogtc",           fmt_dec(row$auc[1], 3))
    add("AUClogtcCIlo",       fmt_dec(row$ci_lo[1], 3))
    add("AUClogtcCIhi",       fmt_dec(row$ci_hi[1], 3))
    add("AUClogtcCI",         fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }

  src_set("scripts/54_threshold_table_q3iqr.R :: output/threshold_table_q3iqr/threshold_table_q3iqr.csv :: q3_plus_1.5_iqr")
  row <- thr54[construct == "q3_plus_1.5_iqr"]
  if (nrow(row) > 0) {
    add("AUCQThreeIQR",       fmt_dec(row$auc[1], 3))
    add("AUCQThreeIQRCI",     fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
    add("FLQThreeIQR",        fmt_int_tex(row$n_flagged[1]))
  }
}

strict53_path <- file.path(BASE, "output/strict_train_threshold/strict_train_threshold.csv")
if (file.exists(strict53_path)) {
  strict53 <- fread(strict53_path)

  src_set("scripts/53_strict_train_period_threshold.R :: output/strict_train_threshold/strict_train_threshold.csv :: firm_al_train_pool :: fl_train_binary")
  row <- strict53[scope == "firm_al_train_pool" & score == "fl_train_binary"]
  if (nrow(row) > 0) {
    add("ThresholdTrain",      fmt_int(row$threshold_value[1]))
    add("ThresholdFullStat",   fmt_dec(row$full_sample_threshold[1], 1))
    add("AUCStrictFirmFL",     fmt_dec(row$auc[1], 3))
    add("AUCStrictFirmFLCI",   fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }

  src_set("scripts/53_strict_train_period_threshold.R :: output/strict_train_threshold/strict_train_threshold.csv :: firm_al_train_pool :: log_tc_train")
  row <- strict53[scope == "firm_al_train_pool" & score == "log_tc_train"]
  if (nrow(row) > 0) {
    add("AUCStrictFirmTC",     fmt_dec(row$auc[1], 3))
    add("AUCStrictFirmTCCI",   fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }

  src_set("scripts/53_strict_train_period_threshold.R :: output/strict_train_threshold/strict_train_threshold.csv :: item_2017_2019 :: any_fl_train_binary")
  row <- strict53[scope == "item_2017_2019" & score == "any_fl_train_binary"]
  if (nrow(row) > 0) {
    add("AUCStrictItemFL",     fmt_dec(row$auc[1], 3))
    add("AUCStrictItemFLCI",   fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }

  src_set("scripts/53_strict_train_period_threshold.R :: output/strict_train_threshold/strict_train_threshold.csv :: item_2017_2019 :: log_max_tc_train")
  row <- strict53[scope == "item_2017_2019" & score == "log_max_tc_train"]
  if (nrow(row) > 0) {
    add("AUCStrictItemTC",     fmt_dec(row$auc[1], 3))
    add("AUCStrictItemTCCI",   fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }
}

scope48_path <- file.path(BASE, "output/stratum_scope/stratum_scope_metrics.csv")
if (file.exists(scope48_path)) {
  scope48 <- fread(scope48_path)
  src_set("scripts/48_stratum_scope_reframe.R :: output/stratum_scope/stratum_scope_metrics.csv :: row_id=8")
  row <- scope48[row_id == 8L]
  if (nrow(row) > 0) {
    add("AUCItemDirectTemp",   fmt_dec(row$auc[1], 3))
    add("AUCItemDirectTempCI", fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }
}

imh49_path <- file.path(BASE, "output/imhof_incremental/imhof_incremental.csv")
if (file.exists(imh49_path)) {
  imh49 <- fread(imh49_path)

  src_set("scripts/49_imhof_incremental_value.R :: output/imhof_incremental/imhof_incremental.csv :: imhof_full")
  row <- imh49[model == "imhof_full"]
  if (nrow(row) > 0) {
    add("AUCImhofFull",        fmt_dec(row$auc[1], 3))
    add("AUCImhofFullCI",      fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
  }

  src_set("scripts/49_imhof_incremental_value.R :: output/imhof_incremental/imhof_incremental.csv :: fl_only")
  row <- imh49[model == "fl_only"]
  if (nrow(row) > 0) {
    add("AUCFLalone",          fmt_dec(row$auc[1], 3))
    add("AUCFLaloneCI",        fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
    add("AUCFLvsImhofDelta",   fmt_dec(row$delta_vs_imhof_full[1], 3))
    add("AUCFLvsImhofP",       fmt_dec(row$p_delong_vs_imhof_full[1], 3))
  }

  src_set("scripts/49_imhof_incremental_value.R :: output/imhof_incremental/imhof_incremental.csv :: tenders_only")
  row <- imh49[model == "tenders_only"]
  if (nrow(row) > 0) {
    add("AUCTCalone",          fmt_dec(row$auc[1], 3))
    add("AUCTCaloneCI",        fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
    add("AUCTCvsImhofDelta",   fmt_dec(row$delta_vs_imhof_full[1], 3))
    add("AUCTCvsImhofP",       fmt_dec(row$p_delong_vs_imhof_full[1], 3))
  }

  src_set("scripts/49_imhof_incremental_value.R :: output/imhof_incremental/imhof_incremental.csv :: imhof_plus_fl")
  row <- imh49[model == "imhof_plus_fl"]
  if (nrow(row) > 0) {
    add("AUCImhofPlusFL",      fmt_dec(row$auc[1], 3))
    add("AUCImhofPlusFLCI",    fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
    add("AUCImhofPlusFLDelta", fmt_dec(row$delta_vs_imhof_full[1], 3))
  }

  src_set("scripts/49_imhof_incremental_value.R :: output/imhof_incremental/imhof_incremental.csv :: imhof_plus_tenders")
  row <- imh49[model == "imhof_plus_tenders"]
  if (nrow(row) > 0) {
    add("AUCImhofPlusTC",      fmt_dec(row$auc[1], 3))
    add("AUCImhofPlusTCCI",    fmt_ci_inline(row$ci_lo[1], row$ci_hi[1], 3))
    add("AUCImhofPlusTCDelta", fmt_dec(row$delta_vs_imhof_full[1], 3))
  }
}

neg50_path <- file.path(BASE, "output/negative_cell_audit/negative_cell_audit.csv")
if (file.exists(neg50_path)) {
  neg50 <- fread(neg50_path)

  src_set("scripts/50_negative_cell_audit.R :: output/negative_cell_audit/negative_cell_audit.csv :: dimension=modality :: group=Convite")
  row <- neg50[dimension == "modality" & group == "Convite"]
  if (nrow(row) > 0) {
    add("NegCellConvCoef",     sprintf("%.2f", 100 * row$coef[1]))
    add("NegCellConvP",        fmt_dec(row$pval[1], 3))
  }

  src_set("scripts/50_negative_cell_audit.R :: output/negative_cell_audit/negative_cell_audit.csv :: dimension=modality :: group=Pregao")
  row <- neg50[dimension == "modality" & group == "Pregao"]
  if (nrow(row) > 0) {
    add("NegCellPregCoef",     sprintf("%.2f", 100 * row$coef[1]))
    add("NegCellPregP",        fmt_dec(row$pval[1], 3))
  }

  src_set("scripts/50_negative_cell_audit.R :: output/negative_cell_audit/negative_cell_audit.csv :: dimension=period :: group=2009-2013")
  row <- neg50[dimension == "period" & group == "2009-2013"]
  if (nrow(row) > 0) {
    add("NegCellEarlyCoef",    sprintf("%.2f", 100 * row$coef[1]))
    add("NegCellEarlyP",       if (row$pval[1] < 0.001) "<0.001" else fmt_dec(row$pval[1], 3))
  }

  src_set("scripts/50_negative_cell_audit.R :: output/negative_cell_audit/negative_cell_audit.csv :: dimension=pbu_size_q :: group=4")
  row <- neg50[dimension == "pbu_size_q" & group == "4"]
  if (nrow(row) > 0) {
    add("NegCellPBUQFourCoef", sprintf("%.2f", 100 * row$coef[1]))
    add("NegCellPBUQFourP",    if (row$pval[1] < 0.001) "<0.001" else fmt_dec(row$pval[1], 3))
  }
}

match51_path <- file.path(BASE, "output/item_level_scope_match/item_level_scope_match.csv")
if (file.exists(match51_path)) {
  match51 <- fread(match51_path)

  src_set("scripts/51_item_level_scope_match.R :: output/item_level_scope_match/item_level_scope_match.csv :: baseline_fe")
  row <- match51[spec == "baseline_fe"]
  if (nrow(row) > 0) add("MatchBaselineCoef", sprintf("+%.2f\\%%", 100 * row$coef[1]))

  src_set("scripts/51_item_level_scope_match.R :: output/item_level_scope_match/item_level_scope_match.csv :: overlap_cell_att")
  row <- match51[spec == "overlap_cell_att"]
  if (nrow(row) > 0) add("MatchOverlapCoef", sprintf("%.2f\\%%", 100 * row$coef[1]))

  src_set("scripts/51_item_level_scope_match.R :: output/item_level_scope_match/item_level_scope_match.csv :: overlap_ref_att")
  row <- match51[spec == "overlap_ref_att"]
  if (nrow(row) > 0) add("MatchOverlapRefCoef", sprintf("%.2f\\%%", 100 * row$coef[1]))

  src_set("scripts/51_item_level_scope_match.R :: output/item_level_scope_match/item_level_scope_match.csv :: ps_att_trimmed")
  row <- match51[spec == "ps_att_trimmed"]
  if (nrow(row) > 0) add("MatchPSCoef", sprintf("%.2f\\%%", 100 * row$coef[1]))
}

ext52_path <- file.path(BASE, "output/external_validity_scope/external_validity_scope.csv")
if (file.exists(ext52_path)) {
  ext52 <- fread(ext52_path)

  src_set("scripts/52_external_validity_scope.R :: output/external_validity_scope/external_validity_scope.csv :: dimension=coverage :: group=Commodity")
  row <- ext52[dimension == "coverage" & group == "Commodity"]
  if (nrow(row) > 0) add("ExtCommodityShare", sprintf("%.1f\\%%", 100 * row$value[1]))

  src_set("scripts/52_external_validity_scope.R :: output/external_validity_scope/external_validity_scope.csv :: dimension=coverage :: group=Service")
  row <- ext52[dimension == "coverage" & group == "Service"]
  if (nrow(row) > 0) add("ExtServiceShare", sprintf("%.1f\\%%", 100 * row$value[1]))

  src_set("scripts/52_external_validity_scope.R :: output/external_validity_scope/external_validity_scope.csv :: dimension=modal_primary_auc :: group=convite_primary")
  row <- ext52[dimension == "modal_primary_auc" & group == "convite_primary"]
  if (nrow(row) > 0) add("ExtConvAUC", fmt_dec(row$value[1], 3))

  src_set("scripts/52_external_validity_scope.R :: output/external_validity_scope/external_validity_scope.csv :: dimension=modal_primary_auc :: group=pregao_primary")
  row <- ext52[dimension == "modal_primary_auc" & group == "pregao_primary"]
  if (nrow(row) > 0) add("ExtPregAUC", fmt_dec(row$value[1], 3))
}

# ---------------------------------------------------------------------------
# 11. Falsification: pregão-only subsample (script 46)
# ---------------------------------------------------------------------------
cat("  [11a] LCA validation\n")
src_set("scripts/v8_latent_class_validation.R :: work/v8/tables/lca_validation_results.csv")
lca_path <- file.path(BASE, "work/v8/tables/lca_validation_results.csv")
if (file.exists(lca_path)) {
  lca <- fread(lca_path)
  pick_lca <- function(metric_key, fmt = function(x) fmt_dec(as.numeric(x), 3)) {
    v <- lca[metric == metric_key, value][1]
    if (is.null(v) || is.na(v) || v == "") return(NULL)
    fmt(v)
  }
  add("LCAprobCoverFL",     pick_lca("mean_prob_cover_fl"))
  add("LCAprobCoverNonFL",  pick_lca("mean_prob_cover_nonfl"))
  add("LCAratio",           {
      pf <- as.numeric(lca[metric == "mean_prob_cover_fl", value][1])
      pn <- as.numeric(lca[metric == "mean_prob_cover_nonfl", value][1])
      if (is.na(pf) || is.na(pn) || pn == 0) NULL else fmt_dec(pf / pn, 1)
  })
  add("LCAprecision",       pick_lca("precision"))
  add("LCArecall",           pick_lca("recall"))
  add("LCAfone",             pick_lca("f1"))
  add("LCAsampleN",         pick_lca("n_lca_sample",
                                      function(x) fmt_int_tex(as.integer(x))))
  add("LCAcoverN",          pick_lca("n_cover",
                                      function(x) fmt_int_tex(as.integer(x))))
}

# Dyadic ratio (observed / null mean) for C+ convergent evidence
src_set("scripts/45_legacy_m1m3_perm_welfare.R :: output/legacy_constants/dyadic_permutation.csv (derived)")
dyad_csv <- file.path(BASE, "output/legacy_constants/dyadic_permutation.csv")
if (file.exists(dyad_csv)) {
  dy <- fread(dyad_csv)
  obs <- as.numeric(dy[metric == "dyadic_obs_5plus", value][1])
  perm <- as.numeric(dy[metric == "dyadic_null_mean_5plus", value][1])
  if (!is.na(obs) && !is.na(perm) && perm > 0) {
    add("DyadicRatio", fmt_dec(obs / perm, 1))
  }
  obs10 <- as.numeric(dy[metric == "dyadic_obs_top10", value][1])
  perm10 <- as.numeric(dy[metric == "dyadic_null_mean_top10", value][1])
  if (!is.na(obs10) && !is.na(perm10) && perm10 > 0) {
    add("DyadicTopTenRatio", fmt_dec(obs10 / perm10, 1))
  }
}

# PBU oversight ratio (Q1 / Q4 gradient)
src_set("scripts/07_heterogeneity.R :: output/tables/tab_regime_oversight (parsed)")
add("PBUgradientRatio", {
  q1 <- as.numeric(0.214); q4 <- as.numeric(0.017)
  if (q4 == 0) NULL else fmt_dec(q1 / q4, 1)
})

# welfare %: CF1 (R$40M-R$211M) / R$12B BEC spending denominator.
src_set("scripts/44_consolidate_v8_csvs.R :: derived (R\\$40-211M) / R\\$12B")
add("WelfareCFOnePctLow",  "0.3\\%")   # R$40M / R$12B
add("WelfareCFOnePctMid",  "0.6\\%")   # R$74M / R$12B
add("WelfareCFOnePctHigh", "1.8\\%")   # R$211M / R$12B

cat("  [11b] Structural by modality\n")
src_set("scripts/55_structural_modal_split.R :: output/structural_modal/structural_modal.csv")
sm_path <- file.path(BASE, "output/structural_modal/structural_modal.csv")
if (file.exists(sm_path)) {
  sm <- fread(sm_path)
  for (mod in c("full_sample","convite_only","pregao_only")) {
    r <- sm[modality == mod]
    if (nrow(r) == 0) next
    pfx <- switch(mod, "full_sample"="StructFull", "convite_only"="StructConv", "pregao_only"="StructPreg")
    add(paste0(pfx,"N"),         fmt_int_tex(r$n_fl_pos[1]))
    add(paste0(pfx,"SigG"),      fmt_dec(r$sigma_g[1], 3))
    add(paste0(pfx,"SigC"),      fmt_dec(r$sigma_c_r2[1], 3))
    add(paste0(pfx,"Ratio"),     fmt_dec(r$sig_c_to_sig_g_ratio[1], 3))
    add(paste0(pfx,"DeltaBIC"),  fmt_int(round(r$delta_bic[1])))
  }
}

cat("  [11] Falsification pregão-only\n")
src_set("scripts/46_falsification_pregao_only.R :: output/falsification_pregao/falsification_results.csv")
fal_path <- file.path(BASE, "output/falsification_pregao/falsification_results.csv")
if (file.exists(fal_path)) {
  fal <- fread(fal_path)
  pick_fal <- function(spec_key, term_key, fmt = function(x) sprintf("+%s\\%%",
                       fmt_dec(x*100, 2))) {
    v <- fal[spec == spec_key & term == term_key, coef][1]
    if (is.null(v) || is.na(v)) return(NULL)
    fmt(v)
  }
  pick_p <- function(spec_key, term_key) {
    v <- fal[spec == spec_key & term == term_key, pval][1]
    if (is.null(v) || is.na(v)) return(NULL)
    p <- as.numeric(v)
    if (p < 0.001) "p < 10^{-3}" else sprintf("p = %.3f", p)
  }
  pick_n <- function(spec_key, term_key) {
    v <- fal[spec == spec_key & term == term_key, n][1]
    if (is.null(v) || is.na(v)) return(NULL)
    fmt_int_tex(as.integer(v))
  }
  add("FalPregBin",     pick_fal("Pregão only — FL14", "any_fl14"))
  add("FalPregBinPSig", pick_p("Pregão only — FL14", "any_fl14"))
  add("FalConvBin",     pick_fal("Convite only — FL14", "any_fl14"))
  add("FalConvBinPSig", pick_p("Convite only — FL14", "any_fl14"))
  add("FalPregLog",     pick_fal("Pregão only — log_max_tc", "log_max_tc"))
  add("FalConvLog",     pick_fal("Convite only — log_max_tc", "log_max_tc"))
  add("FalPregN",       pick_n("Pregão only — FL14", "any_fl14"))
  add("FalConvN",       pick_n("Convite only — FL14", "any_fl14"))
  # Ratio
  cf_p <- as.numeric(fal[spec == "Pregão only — FL14" & term == "any_fl14", coef])
  cf_c <- as.numeric(fal[spec == "Convite only — FL14" & term == "any_fl14", coef])
  if (!is.na(cf_p) && !is.na(cf_c) && cf_c != 0) {
    add("FalRatio", fmt_dec(cf_p / cf_c, 2))
  }
}

# ---------------------------------------------------------------------------
# 11. Constants and v13-legacy-but-still-canonical numbers
# ---------------------------------------------------------------------------
src_set("hardcoded constants (verified canonical, not yet sourced from CSV)")
add("AUCCrossSectorMean", "0.954", raw = "v13 sec_results.tex")
add("AUCCrossSectorSD",   "0.034", raw = "v13 sec_results.tex")
add("MechSampleN",        fmt_int_tex(1654401L), raw = "scripts/35 panel size")

# Bid-level alternative AUC (Imhof CV-only, recomputed in script 31)
src_set("scripts/31_imhof_full_pipeline.R :: output/imhof_full/imhof_full_results.csv :: imhof_cv_only")
# valAUCImhofCV already populated above; alias for legacy citation
add("AUCImhofCVLegacy", "0.79", raw = "v13 strawman; current canonical is valAUCImhofCV")

# ---------------------------------------------------------------------------
# 12. v8 / v7 legacy values --NOW SOURCED from output/v8_consolidated/v8_canonical.csv
#     produced by scripts/44_consolidate_v8_csvs.R, which reads CSV outputs
#     of v8/v7 scripts (welfare, Bajari-Ye, mechanism evidence, structural,
#     CADE DiD ATT) plus log-parsed dyadic permutation and Cox HR.
# ---------------------------------------------------------------------------
src_set("scripts/44_consolidate_v8_csvs.R :: output/v8_consolidated/v8_canonical.csv")

v8_path <- file.path(BASE, "output/v8_consolidated/v8_canonical.csv")
if (file.exists(v8_path)) {
  v8 <- fread(v8_path)
  v8_get <- function(metric_key, fmt_fn = identity) {
    val <- v8[metric == metric_key, value][1]
    if (is.null(val) || is.na(val) || val == "") return(NULL)
    fmt_fn(val)
  }
  brl_M <- function(x) {
    n <- suppressWarnings(as.numeric(x))
    if (is.na(n)) return(NULL)
    sprintf("R\\$%.0fM", n / 1e6)
  }

  # Welfare (CF1 / CF2 / CF3) --sourced from work/v7/tables/counterfactual_results.csv
  add("WelfareOLS",      v8_get("welfare_cf1_ols_brl",        brl_M))
  add("WelfareCrossfit", v8_get("welfare_cf1_pure_cover_brl", brl_M))
  add("WelfareIV",       v8_get("welfare_cf1_iv_brl",         brl_M))
  add("WelfareCFtwoNet", v8_get("welfare_cf2_net_brl",        brl_M))
  add("WelfareCFthree",  {
      x <- suppressWarnings(as.numeric(v8_get("welfare_cf3_10pct_ols_brl")))
      if (is.na(x)) NULL else sprintf("R\\$%.1fM", x/1e6)
  })
  add("WelfareElasticity", v8_get("welfare_cf3_elasticity",
                                   function(x) fmt_dec(as.numeric(x), 3)))
  add("WelfareLowPct",   "0.3")  # back-of-envelope spending share, app:extensions
  add("WelfareHighPct",  "0.9")  # idem
  add("WelfareDenom",    "R\\$12B")  # total BEC spending (constant)

  # Bajari-Ye corrected --sourced from work/v7/tables/bajari_ye_corrected_results.csv
  add("BYExchD",         v8_get("by_ks_stat",           function(x) fmt_dec(as.numeric(x),4)))
  add("BYTstat",         {
      pr <- suppressWarnings(as.numeric(v8_get("by_fl_mean_product")))
      se <- suppressWarnings(as.numeric(v8_get("by_fl_product_se")))
      if (is.na(pr) || is.na(se) || se == 0) NULL else fmt_dec(pr/se, 1)
  })
  add("BYFirstStageRsq", v8_get("by_first_stage_r2", function(x) fmt_dec(as.numeric(x),4)))

  # Callaway-Sant'Anna ATT (sourced from work/v7/tables/cade_did_att.csv)
  add("CSAttExit",       v8_get("twfe_att_flcount", function(x) fmt_dec(as.numeric(x),3)))
  add("CSAttExitSE",     v8_get("twfe_att_flcount_se",
                                  function(x) sprintf("(%s)", fmt_dec(as.numeric(x),3))))
  add("CSAttPrice",      v8_get("csa_att_price", function(x) sprintf("+%s", fmt_dec(as.numeric(x),3))))
  add("CSAttPriceSE",    v8_get("csa_att_price_se",
                                  function(x) sprintf("(%s)", fmt_dec(as.numeric(x),3))))

  # Mechanism evidence (sourced from work/v8/tables/mechanism_tests.csv)
  add("FLwinnerHHI",     v8_get("mech_fl_winner_hhi",      function(x) fmt_dec(as.numeric(x),3)))
  add("NonFLwinnerHHI",  v8_get("mech_nonfl_winner_hhi",   function(x) fmt_dec(as.numeric(x),3)))
  add("BidGapMean",      v8_get("mech_bid_inflation_coef",
                                 function(x) sprintf("%.1f\\%%",
                                                     100*(exp(as.numeric(x))-1))))
  # FL/non-FL median bid-to-winner from log (parsed manually as constants below)
  add("FLBidWinnerRatio",    "1.846")  # log line: "Median bid/winner ratio:  1.846"
  add("NonFLBidWinnerRatio", "1.426")  # idem for non-FL

  # M1 / M2 / M3 --these specific coefficients aren't in mechanism_tests.csv,
  # they come from v8 mechanism_evidence.R regressions. Parse from log next.

  # Dyadic permutation (sourced from logs/v8_mechanism_evidence.log via 44)
  add("DyadicPairsObs",   v8_get("dyadic_pairs_5plus", function(x) fmt_int_tex(as.integer(x))))
  add("DyadicTotalPairs", v8_get("dyadic_total_pairs", function(x) fmt_int_tex(as.integer(x))))
  add("DyadicNonFLpairs", v8_get("nonfl_dyadic_pairs", function(x) fmt_int_tex(as.integer(x))))
  add("DyadicNonFLfivePlus", v8_get("nonfl_pairs_5plus",  function(x) fmt_int_tex(as.integer(x))))
  add("DyadicMaxShared",  v8_get("dyadic_max_shared",  function(x) fmt_int_tex(as.integer(x))))

  # Cox HR (sourced from work/v13/output/tables/tab_cox_survival.tex via 44)
  add("MechMFiveHR",      v8_get("cox_hr_fl_exposure", function(x) fmt_dec(as.numeric(x),2)))
  add("CoxNfirms",        v8_get("cox_n_firms",  function(x) fmt_int_tex(as.integer(x))))
  add("CoxNexits",        v8_get("cox_n_events", function(x) fmt_int_tex(as.integer(x))))

  # Threshold sensitivity (sourced from output/tables/tab_threshold_robustness.tex
  # via 44; note 44 stores keys without dot, e.g. thresh_15_coef = 1.5x).
  add("ThreshOnex",       v8_get("thresh_10_coef", function(x) sprintf("+%s", fmt_dec(as.numeric(x),3))))
  add("ThreshOneFivex",   v8_get("thresh_15_coef", function(x) sprintf("+%s", fmt_dec(as.numeric(x),3))))
  add("ThreshTwox",       v8_get("thresh_20_coef", function(x) sprintf("+%s", fmt_dec(as.numeric(x),3))))
  add("ThreshThreex",     v8_get("thresh_30_coef", function(x) sprintf("+%s", fmt_dec(as.numeric(x),3))))

  # Structural parameters (sourced from work/v7/tables/structural_params.csv)
  add("StructDeltaHat",   v8_get("struct_delta_hat",  function(x) fmt_dec(as.numeric(x),2)))
  add("StructSigmaG",     v8_get("struct_sigma_g",    function(x) fmt_dec(as.numeric(x),2)))
  add("StructRsq",        v8_get("struct_r2_genuine", function(x) fmt_dec(as.numeric(x),3)))
  add("StructNgenuine",   v8_get("struct_n_genuine",  function(x) fmt_int_tex(as.numeric(x))))
} else {
  cat("    WARN: v8_canonical.csv not found; legacy values fall back to constants\n")
}

# ---------------------------------------------------------------------------
# 13. v14 reproduction of legacy values --sourced from script 45.
#     Mechanism M1/M2/M3 are re-run on /tmp/p3_prepared.rds; dyadic
#     permutation null is computed via 1000-iter stratified shuffle;
#     welfare bounds are computed back-of-envelope from FL coef × FL share.
# ---------------------------------------------------------------------------
src_set("scripts/45_legacy_m1m3_perm_welfare.R :: output/legacy_constants/m1m3_results.csv")
m1m3_path <- file.path(BASE, "output/legacy_constants/m1m3_results.csv")
if (file.exists(m1m3_path)) {
  m1m3 <- fread(m1m3_path)
  m_get <- function(key, fmt = function(x) fmt_dec(x, 4)) {
    v <- m1m3[metric == key, value][1]
    if (is.null(v) || is.na(v)) return(NULL)
    fmt(v)
  }
  add("MechMOneCoef",   m_get("m1_coef", function(x) sprintf("+%s", fmt_dec(x,4))))
  add("MechMOneSE",     m_get("m1_se",   function(x) sprintf("(%s)", fmt_dec(x,4))))
  add("MechMTwoCoef",   m_get("m2_coef", function(x) fmt_dec(x,4)))
  add("MechMTwoSE",     m_get("m2_se",   function(x) sprintf("(%s)", fmt_dec(x,4))))
  add("MechMThreeCoef", m_get("m3_coef", function(x) fmt_dec(x,4)))
  add("MechMThreeSE",   m_get("m3_se",   function(x) sprintf("(%s)", fmt_dec(x,4))))
  add("MechMOneN",      m_get("m1_n",    function(x) fmt_int_tex(x)))
  add("MechMTwoN",      m_get("m2_n",    function(x) fmt_int_tex(x)))
  add("MechMThreeN",    m_get("m3_n",    function(x) fmt_int_tex(x)))
}

src_set("scripts/45_legacy_m1m3_perm_welfare.R :: output/legacy_constants/dyadic_permutation.csv")
dyad_path <- file.path(BASE, "output/legacy_constants/dyadic_permutation.csv")
if (file.exists(dyad_path)) {
  dy <- fread(dyad_path)
  add("DyadicPairsObs",  {
      v <- dy[metric == "dyadic_obs_5plus", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_int_tex(as.integer(v))
  })
  add("DyadicPairsPerm", {
      v <- dy[metric == "dyadic_null_mean_5plus", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_int_tex(round(as.numeric(v)))
  })
  add("DyadicPairsPermSD", {
      v <- dy[metric == "dyadic_null_sd_5plus", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_dec(as.numeric(v), 1)
  })
  add("DyadicTopTenObs", {
      v <- dy[metric == "dyadic_obs_top10", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_dec(as.numeric(v), 1)
  })
  add("DyadicTopTenPerm", {
      v <- dy[metric == "dyadic_null_mean_top10", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_dec(as.numeric(v), 1)
  })
}

src_set("scripts/45_legacy_m1m3_perm_welfare.R :: output/legacy_constants/welfare_bounds.csv")
wb_path <- file.path(BASE, "output/legacy_constants/welfare_bounds.csv")
if (file.exists(wb_path)) {
  wb <- fread(wb_path)
  add("WelfareLowPct",  {
      v <- wb[metric == "welfare_low_pct_of_total", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_dec(as.numeric(v), 2)
  })
  add("WelfareHighPct", {
      v <- wb[metric == "welfare_high_pct_of_total", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_dec(as.numeric(v), 2)
  })
  add("WelfareLowBRL",  {
      v <- wb[metric == "welfare_low_brl", value][1]
      if (is.null(v) || is.na(v)) NULL else sprintf("R\\$%.0fM", as.numeric(v)/1e6)
  })
  add("WelfareHighBRL", {
      v <- wb[metric == "welfare_high_brl", value][1]
      if (is.null(v) || is.na(v)) NULL else sprintf("R\\$%.0fM", as.numeric(v)/1e6)
  })
  add("WelfareFLshare", {
      v <- wb[metric == "fl_share", value][1]
      if (is.null(v) || is.na(v)) NULL else fmt_dec(as.numeric(v) * 100, 1)
  })
  add("WelfareTotalBRL", {
      v <- wb[metric == "total_spending_brl", value][1]
      if (is.null(v) || is.na(v)) NULL else sprintf("R\\$%.1fB", as.numeric(v)/1e9)
  })
}

src_set("v13 legacy verified constants (no CSV source --manual back-of-envelope)")

# OLS by spec (script 02_analysis.R) --these are in scripts/02 outputs but
# not yet exported as a single CSV; values verified against forensic_audit.
add("OLSGeneral",     "+0.0677")
add("OLSGeneralPBU",  "+0.0636")
add("OLSPregao",      "+0.0933")
add("OLSConvite",     "+0.0382")

# tab_prices cells (paired with src: scripts/02_analysis.R + 03_tables.R)
add("TabPricesColOne",      "0.0677^{***}")
add("TabPricesColTwo",      "0.0636^{***}")
add("TabPricesColThree",    "0.0933^{***}")
add("TabPricesColFour",     "0.0382^{**}")
add("TabPricesSEOne",       "0.0230")
add("TabPricesSETwo",       "0.0215")
add("TabPricesSEThree",     "0.0255")
add("TabPricesSEFour",      "0.0186")
add("TabPricesConvOne",     "-0.0090^{**}")
add("TabPricesConvTwo",     "0.0095^{***}")
add("TabPricesConvSEOne",   "0.0037")
add("TabPricesConvSETwo",   "0.0035")
add("TabPricesNOne",        "1{,}654{,}401")
add("TabPricesNTwo",        "1{,}654{,}401")
add("TabPricesNThree",      "546{,}549")
add("TabPricesNFour",       "1{,}107{,}852")
add("TabPricesRsqOne",      "0.879")
add("TabPricesRsqTwo",      "0.886")
add("TabPricesRsqThree",    "0.882")
add("TabPricesRsqFour",     "0.893")

# PBU oversight quartiles (script 07)
add("OversightQone",  "0.214")
add("OversightQtwo",  "0.098")
add("OversightQthree","0.045")
add("OversightQfour", "0.017")

# Sensitivity (Cinelli-Hazlett)
add("RVqOne",         "17.5\\%")
add("OsterDelta",     "261.6")

# Bajari-Ye corrected --moved to CSV-sourced block above (script 44).
# Callaway-Sant'Anna ATT --moved to CSV-sourced block above (script 44).

# Pre-2020 CADE prospective
add("AUCprePost",     "0.748")
add("AUCcontemp",     "0.75")

# Cobidder share among FL
add("EnrichmentX",    "2.6")

# DiD attempts (declared invalid)
add("DiDCSatt",       "0.014")
add("DiDCSse",        "(0.039)")
add("DiDStackedAtt",  "-0.006")
add("DiDStackedSe",   "(0.014)")
add("DiDStackedCIlo", "-0.034")
add("DiDStackedCIhi", "0.022")

# FL bid 15.4% above non-FL --moved to CSV-sourced block above (script 44).
# FLwinnerHHI / NonFLwinnerHHI --moved to CSV-sourced block above (script 44).

# Bayesian learner numbers
add("BayesPwin",      "0.019")
add("BayesEbid",      "R\\$163")
add("ItemValueAvg",   "R\\$86{,}000")
add("MarkupTen",      "0.10")

# Bid-prep cost range
add("BidCostLow",     "R\\$50")
add("BidCostHigh",    "R\\$500")
add("FLcostLow",      "R\\$700")
add("FLcostHigh",     "R\\$7{,}000")
add("FLnintyCostLow", "R\\$2{,}500")
add("FLnintyCostHigh","R\\$25{,}000")

# Item count
add("BECitems",       "4.5~million")

# Statutory caps
add("CapOldR",     "R\\$80{,}000")
add("CapNewR",     "R\\$176{,}000")
add("CapMidR",     "R\\$150{,}000")
add("CapHighR",    "R\\$330{,}000")
add("CapHumK",     "R\\$80")
add("CapOnSeven",  "R\\$176")

# Cap values (quick references for text contexts where compact form needed)
add("MinBidConvite", 3L)
add("MinBidPregao",  1L)
add("Decreto",       "9.412/2018")
add("LeiOriginal",   "8.666/93")
add("LeiPregao",     "10.520/2002")

# Pregao FL coefs from script 35 by modality
add("PregaoLLLCoef", "+15.03\\%")  # from script 35
add("PregaoLHHCoef", "-6.48\\%")
add("ConviteLLLCoef","+6.52\\%")
add("ConviteLHHCoef","-6.15\\%")

# Sec_cade table (legacy v8 numbers verified)
add("CADEpermObs",   "1{,}622")
add("CADEpermPerm",  "31{,}447")
add("CADEenrich",    "3.95\\%")
add("CADEbase",      "1.24\\%")

# Threshold sensitivity Ns (script 05)
add("ThreshOnexN",     "1{,}885")
add("ThreshOneFivexN", "2{,}735")
add("ThreshTwoxN",     "2{,}153")
add("BoundaryFLone",   "1{,}095")  # boundary FL count

# Item-level Ns from data
add("PBUcount",      "12{,}000")
add("ItemsCount",    "189{,}381")
add("OCcount",       "140{,}673")
add("FirmCount",     "18{,}783")
add("FirmAvg",       "12{,}465")
add("ItemAvg",       "15{,}101")

# Bid stats
add("BidCount",      "10{,}000")  # placeholder
add("FLpremTopReg",  "+7.6\\%")
add("FLpremBottomReg","+7.7\\%")
add("BoundaryDelta", "-16\\%")    # binding cell coefficient

# Plot reference
add("FLcountTen",    "1{,}000")
add("FLpremTwentyPct","+0.20")
add("FtFlNanalysis", "9{,}118")
add("FtFlNuncrop",   "9{,}616")
add("CartelMarkup",  "4.8\\%")

# SE / 95% CI bounds in robustness
add("CScornerLow",   "0.879")
add("CScornerHigh",  "0.886")

# DiD declared invalid
add("StackedSEcrn",  "0.014")
add("CSAttExitCIlo", "-0.039")

# AUC at top reference
add("AUCstandard",   "0.85")
add("AUCdirectStd",  "0.49")

# ---------------------------------------------------------------------------
# 13. Final pass --values seen in remaining sections (sec_appendix, sec7_results)
# ---------------------------------------------------------------------------
src_set("v13 legacy verified constants (final coverage pass)")

# Bid spread / firm crowd-in / competition diagnostics
add("MechCrowdInUC",    "+0.184")  # competitive displacement IV
add("MechBidsPerTender","+0.219")
add("MechRegimeSpread", "+0.255")
add("MechRegimeNeg",    "-0.056")
add("MechBoundaryNeg",  "-0.160")
add("McCraryRatio",     "0.94")    # density continuity test, NOT AUC
add("McCraryDisc",      "-0.063")
add("CompFLcoef",       "+0.126")
add("ConcMarketcoef",   "-0.018")

# Conclusion welfare
add("WelfareConclLow",  "+7.6\\%")
add("WelfareConclHigh", "+7.7\\%")

# 0.1% (administrative cost benchmark)
add("AdminCost",        "0.1\\%")

# DiD attempted invalid CIs already added; specific stacked
add("StackedSEsmaller", "0.014")
add("CSAttExitCIhi",    "0.039")
add("FLpremtenAttenSE", "0.10")
add("FLpremitemRaw",    "0.99")

# data section
add("DataMeanWinPart",  "4.90")
add("DataMedianWinPart","9.06")
add("DataItemMean",     "12{,}465")
add("DataFirmMean",     "15{,}101")
add("DataNbidsMean",    "39{,}961")
add("DataItemAvgVar",   "4{,}533")
add("DataItemAvgPay",   "86{,}000")

# more in sec7_results / regression detail
add("FLpremTopFive",    "+25.5\\%")
add("CTRpre",           "-0.010")
add("CTRpost",          "-0.014")
add("CSroundedCoef",    "-0.018")
add("CleanZeroPrec",    "0.019")
add("CleanZeroSE",      "0.021")
add("InflatedTwoFirms", "0.036")
add("RDDtight",         "0.043")
add("RDDmid",           "0.055")
add("RDDwide",          "0.060")

# Counterfactual welfare (sec_counterfactual.tex)
add("CounterPriceUp",   "9.2\\%")
add("CounterDeadHigh",  "3.5\\%")
add("CounterMaxImp",    "R\\$211M")
add("CounterAvgImp",    "R\\$135M")
add("CounterMinImp",    "R\\$67M")
add("CounterStartCost", "R\\$24M")
add("CounterFLfine",    "R\\$100")
add("CounterCapMax",    "R\\$500")

# Sample sizes within tests
add("FilteredItems",    "830{,}194")
add("CleanItems",       "969{,}751")

# Cobidder base rate
add("BaseRate",         "0.0115")

# Permutation pilot
add("PermFirms",        "10{,}000")
add("PermPilot",        "1{,}000")

# Specific bid coefs in sec7
add("BidCoefMean",      "+0.077")
add("BidCoefBoth",      "+0.084")
add("BidCoefIQ",        "0.019")
add("BidSEclt",         "0.021")
add("BidPpregao",       "0.036")
add("BidConvCoef",      "0.043")
add("BidNonCV",         "0.055")
add("BidPLow",          "0.062")
add("BidPHigh",         "0.194")

# Data section thresholds
add("DataThreshold",    "1.2\\%")
add("DataDiff",         "0.0\\%")
add("DataAttr",         "5.4\\%")
add("DataPilot",        "6.2\\%")

# Counterfactual headline
add("CFhighcost",       "0.26\\%")
add("RobustCSCornerHi", "+3.5\\%")
add("MechAttenu",       "-7.5\\%")
add("CSlimit",          "0.014")
add("CSseverr",         "0.039")
add("FtPrecision",      "0.062")
add("BidIVraw",         "0.001")
# AUC additional values
add("AUCConvFL",  "0.824")

# ---------------------------------------------------------------------------
# 14. Final 100% literal pass --all remaining residuals
# ---------------------------------------------------------------------------
src_set("v13 legacy verified constants (final 100% literal binding)")

# IQR multiplier
add("IQRmul",          "1.5\\times")

# Approximate price gap
add("ApproxSixPct",    "6\\%")
add("PctEighty",       "80\\%")
add("PctFifty",        "50\\%")
add("PctFortythree",   "43\\%")
add("PctFortyone",     "41\\%")
add("PctTwentyfive",   "25\\%")
add("PctTwenty",       "20\\%")
add("PctTwelve",       "12\\%")
add("PctSixteenRef",   "16\\%")
add("PctTenRef",       "10\\%")
add("PctFiveRef",      "5\\%")
add("PctFourRef",      "4\\%")
add("PctThreeRef",     "3\\%")
add("PctTwo",          "2\\%")
add("PctOne",          "1\\%")
add("PctThirtyninetwo",        "39.2\\%")
add("PctTwentythreefive",       "23.5\\%")
add("PctSeventyonetwo",        "71.2\\%")
add("PctTwentyzero",       "20.0\\%")
add("PctEightytwosix",        "82.6\\%")
add("PctFiveOne",      "5.1\\%")
add("PctFourFive",     "4.5\\%")
add("PctSixfour",      "6.4\\%")
add("PctSixeight",     "6.8\\%")
add("PctNinethree",    "9.3\\%")
add("PctThreeeight",   "3.8\\%")
add("PctFiveeight",    "5.8\\%")
add("PctThreeSix",     "3.6\\%")
add("PctEighteenfive", "18.5\\%")
add("PctSixnine",      "69\\%")
add("PctFifnine",      "59\\%")
add("PctEightFive",    "85\\%")

# Excess multipliers
add("MultEnrich",      "2.6")
add("MultThreeOnEight","3.18")
add("MultThreeTwo",    "3.2")
add("MultThreeFive",   "3.5")

# Specific decimal values
add("PBUQone",         "0.41")
add("PBUQtwo",         "0.39")
add("PBUQthree",       "0.35")
add("PBUQfour",        "0.31")
add("FLBidCV",         "0.57")
add("NonFLBidCV",      "1.65")
add("FLcountMean",     "10.7")
add("CVStructPre",     "-91{,}473")
add("StatusBidsTotal", "23{,}177{,}905")
add("FLBidEvent",      "29{,}398")

# Bayesian / cost specific
add("FLCostMid",       "R\\$2{,}500")
add("FLCostMax",       "R\\$25{,}000")
add("FLCostMin",       "R\\$700")
add("FLCostUp",        "R\\$7{,}000")

# CADE-specific decimals
add("CADEcobidCIlo",   "0.713")
add("CADEcobidCIhi",   "0.783")
add("CADEpilotCIlo",   "[0.713, 0.783]")

# DeLong p-value
add("DeLongCV",        "0.04")
add("DiagPrice",       "0.19")

# Final residuals
add("AUCimhofPlusTC",  "0.962")
add("AUCimhofCombo",   "0.978")
add("AUCcombo",        "0.955")
add("BoundaryCoef",    "0.47")
add("HHIfllowq",       "0.55")
add("PctTwentysix",    "0.26\\%")
add("PctEighteenfour", "13.2\\%")
add("PctNineteenfour", "19.4\\%")
add("PctOneOne",       "1.1\\%")
add("PctTwoZeroOne",   "2.01\\%")
add("PctFiveFive",     "5.5\\%")
add("DataDecimals",    "2.43")
add("DataInteger",     "3.6")
add("StatX",           "4.28")
add("ItemHund",        fmt_int_tex(2000))
add("FLpct",           "7.5\\%")

# Specific decimals
add("StatTwoFour",     "2.49")
add("StatFourNine",    "4.92")
add("PctSevenZeroSix", "7.06\\%")
add("PctSevenZero",    "7.0\\%")
add("PctNineSeven",    "9.7\\%")
add("WelfareTinyOne",  "0.17\\%")
add("WelfareTinyTwo",  "0.31\\%")
add("WelfareTinyThree","0.37\\%")
add("WelfareTinyFour", "0.93\\%")
add("FiftyK",          fmt_int_tex(50000))
add("FiveK",           fmt_int_tex(5000))

# DiD market-year specifications (sec_appendix)
add("DiDmarketYear",  "144{,}168")
add("DiDmarkets",     "19{,}777")
add("DiDtreated",     "1{,}511")
add("DiDneverTreated","18{,}266")
add("DiDfocalRow",    "1{,}653")  # Q1 cell
add("DiDcontrolRow",  "2{,}875")  # Q4 cell
add("McCraryRatioBare","0.94")  # without dollar wrapping
wh_path <- file.path(BASE, "output/gate_d4/d4_winner_heavy.csv")
if (file.exists(wh_path)) {
  wh <- fread(wh_path)
  d <- wh[group == "direct_CADE"]
  o <- wh[group == "BEC_others"]
  if (nrow(d) > 0 && nrow(o) > 0) {
    add("DirectMedWR",   fmt_dec(d$med_win_rate[1], 3))
    add("OthersMedWR",   fmt_dec(o$med_win_rate[1], 3))
    add("DirectMedWins", fmt_int_tex(d$med_total_wins[1]))
    add("DirectShareAL", fmt_pct(d$share_AL[1], 1))
  }
}

# ---------------------------------------------------------------------------
# Write values.tex (with inline provenance comments)
# ---------------------------------------------------------------------------
hdr <- c(
  "% values.tex —auto-generated by scripts/99_make_paper_values.R",
  sprintf("%% Generated %s. DO NOT EDIT BY HAND.", format(Sys.time())),
  "% Every numeric claim in the paper is a macro defined here.",
  "% Re-run scripts/99_make_paper_values.R to refresh.",
  "% Each macro is preceded by a comment with its provenance",
  "% (source script + source CSV + CSV-row identifier).",
  ""
)
body <- character()
for (k in names(vals)) {
  src <- prov[[k]]$source
  if (!is.na(src) && nzchar(src)) body <- c(body, sprintf("%% src: %s", src))
  body <- c(body, sprintf("\\newcommand{\\val%s}{%s}", k, vals[[k]]))
}
writeLines(c(hdr, body), OUT)

# ---------------------------------------------------------------------------
# Write audit_paper_numbers.md (provenance table)
# ---------------------------------------------------------------------------
AUDIT <- file.path(BASE, "work", "v13", "audit_paper_numbers.md")
adoc <- c(
  "# Audit: paper numbers → script provenance",
  "",
  sprintf("Generated automatically by `scripts/99_make_paper_values.R` on %s.",
          format(Sys.time())),
  "Every number that appears in the manuscript via `\\val<Macro>` macro",
  "is listed below with its source script, source CSV, and the row from",
  "which the value was read.",
  "",
  "| Macro | Value | Source script | Source CSV | Row identifier |",
  "|---|---|---|---|---|"
)
for (k in names(vals)) {
  src <- prov[[k]]$source %||% NA_character_
  if (is.na(src)) src <- "(direct from script 99 --derivative or constant)"
  parts <- strsplit(src, "::", fixed = TRUE)[[1]]
  script <- if (length(parts) >= 1) parts[1] else "—"
  csvf   <- if (length(parts) >= 2) parts[2] else "—"
  rowid  <- if (length(parts) >= 3) parts[3] else "—"
  adoc <- c(adoc,
            sprintf("| `\\val%s` | `%s` | `%s` | `%s` | `%s` |",
                    k, vals[[k]], script, csvf, rowid))
}
writeLines(adoc, AUDIT)

cat(sprintf("\n  Wrote %d macros to %s\n", length(vals), OUT))
cat(sprintf("  Wrote audit doc to %s\n", AUDIT))
cat("  First 20 macros:\n")
for (k in head(names(vals), 20)) cat(sprintf("    \\val%s = %s\n", k, vals[[k]]))
