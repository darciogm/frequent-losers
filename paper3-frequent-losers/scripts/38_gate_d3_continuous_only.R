# ============================================================================
# 38_gate_d3_continuous_only.R — Gate diagnostic D3: continuous preserves
# loser-side thesis without FL14
# Paper 3 v14 / Path γ++ gate
#
# Purpose: confirm that the loser-side concentration thesis survives if we
# drop the FL14 binary entirely and replace it with continuous loss-intensity
# scores. The thesis to defend is: "items where always-loser participants
# have collectively higher loss intensity exhibit higher prices, lower
# competition, and higher AUC against CADE cobidders". The FL14 binary is an
# operational implementation, not the substantive claim.
#
# Three tests on the harmonized v13 panel:
#   1. Within-item price regression: log_max_tc, log_sum_tc, mean_tc
#      (continuous representations) replacing the losers binary.
#   2. Modal interaction: continuous × convite — does the asymmetry the
#      institutional reading predicts (premium concentrated in convite, not
#      pregão) survive without the binary?
#   3. Item-level AUC: predict items with ≥1 CADE-cobidder participant using
#      continuous loser-side scores (no FL14 thresholding anywhere).
#
# Pass criterion (Round 3): all three tests deliver positive coefficients
# / above-baseline AUC at conventional significance, AND continuous-with-
# convite-interaction reproduces the modal sign pattern.
#
# Output: output/gate_d3/d3_continuous_results.csv
# ============================================================================

cat("=== 38_gate_d3_continuous_only.R: Diagnostic D3 (continuous-only) ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "gate_d3")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load main panel + firm features -------------------------------------
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

# Loser-side intensity per item (no FL14 thresholding anywhere)
ftm_loser <- merge(ftm[won == 0L],
                    fp[always_loser == 1L, .(firm_code, tenders_count)],
                    by = "firm_code", all.x = TRUE)
ftm_loser[is.na(tenders_count), tenders_count := 0L]

# Has-cobidder indicator at item level (item-level CADE label)
ftm[, has_cobidder := as.integer(firm_code %in% cobid_codes)]
item_cobid <- ftm[, .(any_cobidder = max(has_cobidder, na.rm = TRUE)),
                   by = oc_item_key]
item_cobid[!is.finite(any_cobidder), any_cobidder := 0L]

intensity <- ftm_loser[, .(
  max_tc  = max(tenders_count, na.rm = TRUE),
  sum_tc  = sum(tenders_count, na.rm = TRUE),
  mean_tc = mean(tenders_count, na.rm = TRUE),
  n_loser = .N
), by = oc_item_key]
intensity[!is.finite(max_tc),  max_tc  := 0]
intensity[!is.finite(mean_tc), mean_tc := 0]
intensity[, log_max_tc  := log1p(max_tc)]
intensity[, log_sum_tc  := log1p(sum_tc)]
intensity[, log_mean_tc := log1p(mean_tc)]

# Merge to main panel
dt <- readRDS("/tmp/p3_prepared.rds")
dt[, oc_item_key := paste0(oc_code, "_", item_code)]
dt <- merge(dt, intensity, by = "oc_item_key", all.x = TRUE)
dt <- merge(dt, item_cobid, by = "oc_item_key", all.x = TRUE)
for (c in c("max_tc","sum_tc","mean_tc","n_loser",
            "log_max_tc","log_sum_tc","log_mean_tc","any_cobidder")) {
  dt[is.na(get(c)), (c) := 0]
}

cat(sprintf("\n  Panel rows: %s   With cobidder participant: %s (%.2f%%)\n",
            format(nrow(dt), big.mark = ","),
            format(sum(dt$any_cobidder == 1), big.mark = ","),
            100 * mean(dt$any_cobidder == 1)))

dt_p <- dt[!is.na(lneg_price)]

# ---- Test 1: Within-item price regression — continuous only ------------
cat("\n--- Test 1: log price ~ continuous loser-side intensity ---\n")
m1a <- feols(lneg_price ~ log_max_tc  + convite | item_f + year_f + pbu_f,
             data = dt_p, cluster = ~item_f)
m1b <- feols(lneg_price ~ log_sum_tc  + convite | item_f + year_f + pbu_f,
             data = dt_p, cluster = ~item_f)
m1c <- feols(lneg_price ~ log_mean_tc + convite | item_f + year_f + pbu_f,
             data = dt_p, cluster = ~item_f)

print_one <- function(m, lbl) {
  ct <- coeftable(m)
  rn <- intersect(c("log_max_tc","log_sum_tc","log_mean_tc"), rownames(ct))[1]
  cat(sprintf("    [%-12s] coef = %+.4f (SE %.4f, p = %.4g)  N = %s\n",
              lbl, ct[rn,"Estimate"], ct[rn,"Std. Error"],
              ct[rn,"Pr(>|t|)"], format(m$nobs, big.mark = ",")))
}
print_one(m1a,"log_max_tc")
print_one(m1b,"log_sum_tc")
print_one(m1c,"log_mean_tc")

# ---- Test 2: Modal interaction (continuous × convite) ------------------
cat("\n--- Test 2: log_max_tc × convite — modal asymmetry without FL14 ---\n")
m2 <- feols(lneg_price ~ log_max_tc * convite | item_f + year_f + pbu_f,
            data = dt_p, cluster = ~item_f)
print(coeftable(m2))

# Implied per-modality coefficient
cf2 <- coeftable(m2)
b_main <- cf2["log_max_tc","Estimate"]
b_int  <- cf2["log_max_tc:convite","Estimate"]
cat(sprintf("\n    Implied effect (pregão, convite=0): %+.4f\n", b_main))
cat(sprintf("    Implied effect (convite, convite=1): %+.4f\n", b_main + b_int))

# Run separately
m2_conv <- feols(lneg_price ~ log_max_tc | item_f + year_f + pbu_f,
                  data = dt_p[convite == 1L], cluster = ~item_f)
m2_preg <- feols(lneg_price ~ log_max_tc | item_f + year_f + pbu_f,
                  data = dt_p[convite == 0L], cluster = ~item_f)
cat("\n  --- Stratified: ---\n")
print_one(m2_conv,"convite")
print_one(m2_preg,"pregão")

# ---- Test 3: Item-level AUC — continuous only --------------------------
cat("\n--- Test 3: item-level AUC predicting any-cobidder participation ---\n")
run_item_auc <- function(score, label) {
  if (length(unique(dt[[score]])) < 2) return(NULL)
  r <- pROC::roc(dt$any_cobidder, dt[[score]], quiet = TRUE)
  cat(sprintf("    [%-13s] AUC = %.4f [%.4f, %.4f]\n",
              label,
              as.numeric(pROC::auc(r)),
              as.numeric(pROC::ci(r))[1],
              as.numeric(pROC::ci(r))[3]))
  data.table(score = score,
             auc = as.numeric(pROC::auc(r)),
             ci_lo = as.numeric(pROC::ci(r))[1],
             ci_hi = as.numeric(pROC::ci(r))[3],
             n_pos = sum(dt$any_cobidder == 1),
             n = nrow(dt))
}
auc_dt <- rbind(
  run_item_auc("log_max_tc", "log_max_tc"),
  run_item_auc("log_sum_tc", "log_sum_tc"),
  run_item_auc("log_mean_tc","log_mean_tc"),
  run_item_auc("losers",     "FL14_binary (ref)")
)
fwrite(auc_dt, file.path(OUT, "d3_item_auc.csv"))

# ---- Save price regression summary -------------------------------------
extract_row <- function(m, lbl, term) {
  ct <- coeftable(m)
  if (!term %in% rownames(ct)) return(NULL)
  data.table(spec = lbl, term = term,
             coef = ct[term,"Estimate"], se = ct[term,"Std. Error"],
             pval = ct[term,"Pr(>|t|)"], n = m$nobs)
}
price_dt <- rbind(
  extract_row(m1a,    "log_max_tc only","log_max_tc"),
  extract_row(m1b,    "log_sum_tc only","log_sum_tc"),
  extract_row(m1c,    "log_mean_tc only","log_mean_tc"),
  extract_row(m2,     "interaction main","log_max_tc"),
  extract_row(m2,     "interaction term","log_max_tc:convite"),
  extract_row(m2_conv,"convite only","log_max_tc"),
  extract_row(m2_preg,"pregão only","log_max_tc")
)
fwrite(price_dt, file.path(OUT, "d3_price_regressions.csv"))

# ---- Verdict ----------------------------------------------------------
cat("\n  ===== Gate D3 verdict =====\n")
all_positive <- all(price_dt[spec %in% c("log_max_tc only","log_sum_tc only",
                                          "log_mean_tc only"), coef] > 0 &
                    price_dt[spec %in% c("log_max_tc only","log_sum_tc only",
                                          "log_mean_tc only"), pval] < 0.05)
modal_asym <- price_dt[spec == "convite only", coef] > 0 &&
              price_dt[spec == "convite only", pval] < 0.05
auc_above_baseline <- auc_dt[score == "log_max_tc", auc] > 0.55
verdict <- (
  if (all_positive && modal_asym && auc_above_baseline) "PASS"
  else if (all_positive && (modal_asym || auc_above_baseline)) "WEAK_PASS"
  else "FAIL"
)

cat(sprintf("    All continuous coefs positive & sig (p<0.05) ?  %s\n",
            ifelse(all_positive, "YES", "NO")))
cat(sprintf("    Modal asymmetry (convite > 0 sig) survives without FL14 ?  %s\n",
            ifelse(modal_asym, "YES", "NO")))
cat(sprintf("    Item-level AUC of continuous score > 0.55 ?  %s\n",
            ifelse(auc_above_baseline, "YES", "NO")))
cat(sprintf("    Diagnostic D3 verdict: %s\n", verdict))

cat("\n  Done.\n")
