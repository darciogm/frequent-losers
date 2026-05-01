# ============================================================================
# 44_consolidate_v8_csvs.R — consolidate v8 legacy CSV outputs into a single
# canonical CSV for paper-values sourcing
# Paper 3 v14 / Path A+ Action 10 follow-up (script-source legacy constants)
#
# Reads:
#   work/v7/tables/counterfactual_results.csv      (welfare, CF1-CF3)
#   work/v7/tables/bajari_ye_corrected_results.csv (BY exchangeability)
#   work/v7/tables/cade_did_att.csv                (Callaway-Sant'Anna)
#   work/v7/tables/structural_params.csv           (structural)
#   work/v8/tables/mechanism_tests.csv             (HHI, bid inflation)
#   logs/v8_mechanism_evidence.log                 (dyadic permutation)
#   logs/v8_imhof_comparison.log                   (LCA, ROC variants)
# Plus regenerates Cox HR via minimal scripted run on existing data.
#
# Output: output/v8_consolidated/v8_canonical.csv
# ============================================================================

cat("=== 44_consolidate_v8_csvs.R: consolidate legacy CSVs into one canonical ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(data.table); library(arrow)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "v8_consolidated")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

vals <- list()
add_v <- function(key, value, source) {
  vals[[length(vals) + 1L]] <<- list(metric = key, value = value, source = source)
}

# ---- Counterfactual welfare (v7) ----------------------------------------
cf <- fread(file.path(BASE, "work/v7/tables/counterfactual_results.csv"))
src_cf <- "work/v7/tables/counterfactual_results.csv"
add_v("welfare_cf1_ols_brl",
      cf[counterfactual=="CF1_remove_min_bidder" & metric=="welfare_gain_ols_BRL", value],
      src_cf)
add_v("welfare_cf1_iv_brl",
      cf[counterfactual=="CF1_remove_min_bidder" & metric=="welfare_gain_iv_BRL", value],
      src_cf)
add_v("welfare_cf1_pure_cover_brl",
      cf[counterfactual=="CF1_remove_min_bidder" &
         metric=="welfare_gain_pure_cover_ols_BRL", value],
      src_cf)
add_v("welfare_cf2_net_brl",
      cf[counterfactual=="CF2_optimal_threshold" &
         metric=="net_welfare_cost100k_BRL", value],
      src_cf)
add_v("welfare_cf2_optimal_mult",
      cf[counterfactual=="CF2_optimal_threshold" &
         metric=="optimal_multiplier_cost100k", value],
      src_cf)
add_v("welfare_cf2_n_flagged",
      cf[counterfactual=="CF2_optimal_threshold" &
         metric=="optimal_n_flagged_cost100k", value],
      src_cf)
add_v("welfare_cf3_elasticity",
      cf[counterfactual=="CF3_theta_increase" &
         metric=="elasticity_m_theta", value],
      src_cf)
add_v("welfare_cf3_10pct_ols_brl",
      cf[counterfactual=="CF3_theta_increase" &
         metric=="welfare_gain_10pct_theta_ols_BRL", value],
      src_cf)
add_v("welfare_cf3_10pct_iv_brl",
      cf[counterfactual=="CF3_theta_increase" &
         metric=="welfare_gain_10pct_theta_iv_BRL", value],
      src_cf)
add_v("welfare_cf3_50pct_ols_brl",
      cf[counterfactual=="CF3_theta_increase" &
         metric=="welfare_gain_50pct_theta_ols_BRL", value],
      src_cf)
add_v("welfare_cf1_constrained_tenders",
      cf[counterfactual=="CF1_remove_min_bidder" &
         metric=="n_constrained_tenders", value],
      src_cf)
add_v("welfare_cf1_pure_cover_tenders",
      cf[counterfactual=="CF1_remove_min_bidder" &
         metric=="n_pure_cover_tenders", value],
      src_cf)
add_v("welfare_cf1_fraction_constraint",
      cf[counterfactual=="CF1_remove_min_bidder" &
         metric=="fraction_constraint_binds", value],
      src_cf)

# ---- Bajari-Ye corrected (v7) -------------------------------------------
by <- fread(file.path(BASE, "work/v7/tables/bajari_ye_corrected_results.csv"))
src_by <- "work/v7/tables/bajari_ye_corrected_results.csv"
for (m in c("first_stage_r2","ks_stat","ks_p","fl_mean_product",
            "fl_product_se","fl_product_p")) {
  add_v(paste0("by_", m), by[metric==m, value], src_by)
}

# ---- CADE DiD ATT (v7) --------------------------------------------------
cade <- fread(file.path(BASE, "work/v7/tables/cade_did_att.csv"))
src_cade <- "work/v7/tables/cade_did_att.csv"
add_v("csa_att_price",      cade[outcome=="log_price"    & method=="Callaway-Sant'Anna", att],   src_cade)
add_v("csa_att_price_se",   cade[outcome=="log_price"    & method=="Callaway-Sant'Anna", se],    src_cade)
add_v("csa_att_price_lo",   cade[outcome=="log_price"    & method=="Callaway-Sant'Anna", ci_lo], src_cade)
add_v("csa_att_price_hi",   cade[outcome=="log_price"    & method=="Callaway-Sant'Anna", ci_hi], src_cade)
add_v("twfe_att_flcount",   cade[outcome=="log_fl_count" & method=="TWFE",                att],   src_cade)
add_v("twfe_att_flcount_se",cade[outcome=="log_fl_count" & method=="TWFE",                se],    src_cade)
add_v("did_n_treated_mkts", cade[outcome=="log_price"    & method=="Callaway-Sant'Anna", n_treated_mkts], src_cade)
add_v("did_n_control_mkts", cade[outcome=="log_price"    & method=="Callaway-Sant'Anna", n_control_mkts], src_cade)

# ---- Mechanism evidence (v8) --------------------------------------------
me <- fread(file.path(BASE, "work/v8/tables/mechanism_tests.csv"))
src_me <- "work/v8/tables/mechanism_tests.csv"
for (t in me$test) {
  add_v(paste0("mech_", t), me[test==t, value], src_me)
}

# ---- Structural parameters (v7) -----------------------------------------
sp <- fread(file.path(BASE, "work/v7/tables/structural_params.csv"))
src_sp <- "work/v7/tables/structural_params.csv"
for (p in sp$param) {
  add_v(paste0("struct_", p), sp[param==p, value], src_sp)
}

# ---- Dyadic permutation (parsed from v8 log) ----------------------------
log_path <- file.path(BASE, "logs", "v8_mechanism_evidence.log")
if (file.exists(log_path)) {
  src_dy <- "logs/v8_mechanism_evidence.log"
  log_lines <- readLines(log_path)
  # Pull the FULL numerical TOKEN (incl. thousands separators) that appears
  # AFTER ":" in each diagnostic line.
  pick <- function(pat, line_subset = log_lines) {
    line <- grep(pat, line_subset, value = TRUE)[1]
    if (is.null(line) || is.na(line)) return(NA_real_)
    after_colon <- sub(".*:", "", line)
    # Match a number with optional thousands separators (commas) and optional decimal.
    nums <- regmatches(after_colon,
                       regexpr("[0-9][0-9,]*(\\.[0-9]+)?", after_colon))
    if (length(nums) == 0) return(NA_real_)
    suppressWarnings(as.numeric(gsub(",", "", nums)))
  }
  add_v("dyadic_total_pairs",  pick("FL-winner pairs:"),         src_dy)
  # ">=" appears as a UTF-8 ≥ in the log; use a broader pattern.
  add_v("dyadic_pairs_5plus",  pick("Pairs with .*5 shared:"),    src_dy)
  add_v("dyadic_pairs_10plus", pick("Pairs with .*10 shared:"),   src_dy)
  add_v("dyadic_pairs_20plus", pick("Pairs with .*20 shared:"),   src_dy)
  add_v("dyadic_max_shared",   pick("Max shared:"),               src_dy)
  add_v("dyadic_mean_shared",  pick("Mean shared tenders:"),     src_dy)
  add_v("nonfl_dyadic_pairs",  pick("Non-FL loser-winner pairs:"), src_dy)
  add_v("nonfl_pairs_5plus",   {
      idx <- grep("Non-FL loser-winner pairs", log_lines)[1]
      if (is.na(idx)) NA_real_ else pick("Pairs with .*5 shared:", log_lines[(idx+1):length(log_lines)])
  }, src_dy)
}

# ---- Threshold robustness (re-read from existing tex) -------------------
# tab_threshold_robustness.tex has the values; parse into rows.
thr_tex <- file.path(BASE, "output/tables/tab_threshold_robustness.tex")
if (file.exists(thr_tex)) {
  src_thr <- "output/tables/tab_threshold_robustness.tex (parsed)"
  thr_lines <- readLines(thr_tex)
  data_rows <- grep("\\\\times.*\\&.*\\&.*\\&.*\\&", thr_lines, value = TRUE)
  for (line in data_rows) {
    parts <- strsplit(line, "&")[[1]]
    mult  <- regmatches(parts[1], regexpr("[0-9]+\\.[0-9]+", parts[1]))
    thresh<- regmatches(parts[2], regexpr("[0-9]+", parts[2]))
    nfl   <- regmatches(parts[3], regexpr("[0-9{,}]+", parts[3]))
    coef  <- regmatches(parts[4], regexpr("[0-9]+\\.[0-9]+", parts[4]))
    add_v(sprintf("thresh_%s_coef",   gsub("\\.", "", mult)), as.numeric(coef), src_thr)
    add_v(sprintf("thresh_%s_n_fl",   gsub("\\.", "", mult)),
          suppressWarnings(as.integer(gsub("\\{,\\}|,", "", nfl))), src_thr)
    add_v(sprintf("thresh_%s_threshold", gsub("\\.", "", mult)),
          suppressWarnings(as.integer(thresh)), src_thr)
  }
}

# ---- Cox HR (re-extract minimally) --------------------------------------
# The Cox table in tab_cox_survival.tex has the HR. Parse from there.
cox_tex <- file.path(BASE, "work/v13/output/tables/tab_cox_survival.tex")
if (file.exists(cox_tex)) {
  src_cox <- "work/v13/output/tables/tab_cox_survival.tex (parsed)"
  cox_lines <- readLines(cox_tex)
  # Look for "FL exposure" or "0.60" pattern
  # The line "[HR: 0.852] & [HR: 0.556] & [HR: 0.600]" contains three HRs.
  hr_line <- grep("\\[HR:", cox_lines, value = TRUE)[1]
  if (!is.null(hr_line) && !is.na(hr_line)) {
    nums <- regmatches(hr_line, gregexpr("[0-9]+\\.[0-9]+", hr_line))[[1]]
    if (length(nums) >= 1) add_v("cox_hr_col1", suppressWarnings(as.numeric(nums[1])), src_cox)
    if (length(nums) >= 2) add_v("cox_hr_col2", suppressWarnings(as.numeric(nums[2])), src_cox)
    if (length(nums) >= 3) add_v("cox_hr_fl_exposure", suppressWarnings(as.numeric(nums[3])), src_cox)
  }
  # Coefficients from "FL exposure & -0.1607*** & -0.5876*** & -0.5109***"
  coef_line <- grep("^FL exposure", cox_lines, value = TRUE)[1]
  if (!is.null(coef_line) && !is.na(coef_line)) {
    nums <- regmatches(coef_line, gregexpr("-?[0-9]+\\.[0-9]+", coef_line))[[1]]
    if (length(nums) >= 3) add_v("cox_coef_fl_exposure", suppressWarnings(as.numeric(nums[3])), src_cox)
  }
  # Sample sizes — drop any leading number that's a multicolumn column count.
  pick_n <- function(line) {
    nums <- regmatches(line, gregexpr("[0-9][0-9,]+", line))[[1]]
    nums <- nums[!nums %in% c("3", "1", "2")]  # column count
    if (length(nums) >= 1) suppressWarnings(as.integer(gsub(",", "", nums[1])))
    else NA_integer_
  }
  firms_line <- grep("^Firms ", cox_lines, value = TRUE)[1]
  if (!is.null(firms_line) && !is.na(firms_line)) {
    add_v("cox_n_firms", pick_n(firms_line), src_cox)
  }
  events_line <- grep("^Events", cox_lines, value = TRUE)[1]
  if (!is.null(events_line) && !is.na(events_line)) {
    add_v("cox_n_events", pick_n(events_line), src_cox)
  }
  censored_line <- grep("^Censored", cox_lines, value = TRUE)[1]
  if (!is.null(censored_line) && !is.na(censored_line)) {
    add_v("cox_n_censored", pick_n(censored_line), src_cox)
  }
}

# ---- Write consolidated CSV ----------------------------------------------
out_dt <- rbindlist(lapply(vals, as.data.table), fill = TRUE)
fwrite(out_dt, file.path(OUT, "v8_canonical.csv"))

cat(sprintf("\n  Wrote %d metrics to %s\n", nrow(out_dt),
            file.path(OUT, "v8_canonical.csv")))
cat("  Sample (first 10):\n")
print(head(out_dt, 10))
