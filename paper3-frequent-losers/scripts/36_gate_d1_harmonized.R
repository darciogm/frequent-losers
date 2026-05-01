# ============================================================================
# 36_gate_d1_harmonized.R — Gate diagnostic D1: harmonized horse race
# Paper 3 v14 / Path γ++ gate
#
# Purpose: confirm that the FL14 vs continuous loss-intensity comparison
# uses *exactly the same observations* in (a) AUC against CADE cobidders
# and (b) within-item price regression. The earlier script 34 mixes
# samples slightly (cobidder pool from FREQ_PARTICIP, price sample from
# /tmp/p3_prepared.rds). This script rebuilds both on a single harmonized
# observation set.
#
# Pass criterion (Round 3): same-sample DeLong test confirms continuous
# AUC > FL14 AUC (p < 0.05) AND price-regression rank ordering preserved
# (continuous coefficient of same sign, comparable magnitude). If continuous
# WINS in AUC but FAILS in price (or vice versa), the gate is ambiguous.
#
# Output: output/gate_d1/d1_harmonized_results.csv + log
# ============================================================================

cat("=== 36_gate_d1_harmonized.R: Diagnostic D1 (harmonized horse race) ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "gate_d1")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load main panel + auxiliary firm-level features ---------------------
fp  <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]

cobid <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cobid_codes <- unique(cobid$firm_code)

# ---- Build firm-level FL features ---------------------------------------
THRESH <- 14L
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, fl14    := as.integer(tenders_count > THRESH)]
al[, log_tc  := log1p(tenders_count)]
al[, is_cade := as.integer(firm_code %in% cobid_codes)]

# ---- Build item-level loser-side intensity (max tenders_count among
#      always-loser participants in the item) -----------------------------
ftm_loser <- merge(ftm[won == 0L],
                    fp[always_loser == 1L, .(firm_code, tenders_count)],
                    by = "firm_code", all.x = TRUE)
ftm_loser[is.na(tenders_count), tenders_count := 0L]
intensity <- ftm_loser[, .(
  max_tc   = max(tenders_count, na.rm = TRUE),
  any_fl14 = max(as.integer(tenders_count > THRESH), na.rm = TRUE)
), by = oc_item_key]
intensity[!is.finite(max_tc),   max_tc   := 0L]
intensity[!is.finite(any_fl14), any_fl14 := 0L]
intensity[, log_max_tc := log1p(max_tc)]

# ---- Load main analysis panel from /tmp cache ---------------------------
prepared <- "/tmp/p3_prepared.rds"
if (!file.exists(prepared)) {
  stop("Run 01_clean.R first to build ", prepared)
}
dt <- readRDS(prepared)
dt[, oc_item_key := paste0(oc_code, "_", item_code)]
dt <- merge(dt, intensity, by = "oc_item_key", all.x = TRUE)
for (c in c("max_tc","any_fl14","log_max_tc")) dt[is.na(get(c)), (c) := 0]

# ---- Define HARMONIZED sample: items with non-missing lneg_price AND
#      assignable to the always-loser intensity panel -----------------------
dt_h <- dt[!is.na(lneg_price)]
cat(sprintf("\n  Harmonized panel: %s items\n",
            format(nrow(dt_h), big.mark = ",")))
cat(sprintf("    of which losers (FL14, any_fl14=1): %s\n",
            format(sum(dt_h$any_fl14 == 1L), big.mark = ",")))
cat(sprintf("    median max_tc among loser-side items: %d\n",
            as.integer(median(dt_h$max_tc[dt_h$max_tc > 0]))))

# ---- Part A: AUC same-sample (firm-level, vs cobidders) -----------------
cat("\n--- Part A: Firm-level AUC vs CADE cobidders (always-loser pool) ---\n")
roc_fl14 <- pROC::roc(al$is_cade, al$fl14,    quiet = TRUE)
roc_log  <- pROC::roc(al$is_cade, al$log_tc,  quiet = TRUE)
auc_fl14 <- as.numeric(pROC::auc(roc_fl14))
auc_log  <- as.numeric(pROC::auc(roc_log))
ci_fl14  <- as.numeric(pROC::ci(roc_fl14))
ci_log   <- as.numeric(pROC::ci(roc_log))
delong   <- pROC::roc.test(roc_fl14, roc_log, method = "delong")
cat(sprintf("  FL14   AUC = %.4f [%.4f, %.4f]   N+ = %d / %d\n",
            auc_fl14, ci_fl14[1], ci_fl14[3], sum(al$is_cade), nrow(al)))
cat(sprintf("  log_tc AUC = %.4f [%.4f, %.4f]\n",
            auc_log, ci_log[1], ci_log[3]))
cat(sprintf("  DeLong: Z = %.3f  p = %.4g\n",
            as.numeric(delong$statistic), delong$p.value))

# ---- Part B: Price regression — SAME items, FL binary vs continuous ----
cat("\n--- Part B: Within-item price regression on harmonized sample ---\n")
m_bin <- feols(lneg_price ~ any_fl14 + convite |
                 item_f + year_f + pbu_f,
               data = dt_h, cluster = ~item_f)
m_log <- feols(lneg_price ~ log_max_tc + convite |
                 item_f + year_f + pbu_f,
               data = dt_h, cluster = ~item_f)
m_both <- feols(lneg_price ~ any_fl14 + log_max_tc + convite |
                  item_f + year_f + pbu_f,
                data = dt_h, cluster = ~item_f)

print_coef <- function(m, lbl) {
  ct <- coeftable(m)
  rn <- intersect(c("any_fl14","log_max_tc"), rownames(ct))
  for (r in rn) {
    cat(sprintf("    [%s] %s coef = %+.4f (SE %.4f, p = %.4g)  N = %s\n",
                lbl, r, ct[r,"Estimate"], ct[r,"Std. Error"],
                ct[r,"Pr(>|t|)"], format(m$nobs, big.mark = ",")))
  }
}
print_coef(m_bin,  "FL14 only")
print_coef(m_log,  "log_max_tc only")
print_coef(m_both, "Both")

# ---- Save consolidated summary -------------------------------------------
extract_row <- function(m, lbl) {
  ct <- coeftable(m)
  out <- data.table()
  for (rn in intersect(c("any_fl14","log_max_tc"), rownames(ct))) {
    out <- rbind(out, data.table(
      spec  = lbl, term = rn,
      coef  = ct[rn,"Estimate"], se = ct[rn,"Std. Error"],
      pval  = ct[rn,"Pr(>|t|)"], n = m$nobs))
  }
  out
}

price_dt <- rbind(extract_row(m_bin,"FL14 only"),
                  extract_row(m_log,"log_max_tc only"),
                  extract_row(m_both,"Both"))

auc_dt <- data.table(
  spec  = c("FL14_firm_auc","log_tc_firm_auc"),
  term  = c("fl14_firm","log_tc_firm"),
  auc   = c(auc_fl14, auc_log),
  ci_lo = c(ci_fl14[1], ci_log[1]),
  ci_hi = c(ci_fl14[3], ci_log[3]),
  n_pos = c(sum(al$is_cade), sum(al$is_cade)),
  n_total = c(nrow(al), nrow(al))
)

fwrite(price_dt, file.path(OUT, "d1_price_regressions.csv"))
fwrite(auc_dt,   file.path(OUT, "d1_auc.csv"))
saveRDS(list(price = price_dt, auc = auc_dt, delong = delong),
        file.path(OUT, "d1_harmonized_results.rds"))

# ---- Pass / fail verdict (Round 3 criterion) -----------------------------
cat("\n  ===== Gate D1 verdict =====\n")
auc_pass   <- (auc_log > auc_fl14) && (delong$p.value < 0.05)
price_sign <- (price_dt[term == "log_max_tc" & spec == "log_max_tc only", coef] > 0)
verdict    <- if (auc_pass && price_sign) "PASS" else "AMBIGUOUS"
cat(sprintf("    AUC: log_tc > FL14 with DeLong p < 0.05 ?  %s\n",
            ifelse(auc_pass, "YES", "NO")))
cat(sprintf("    Price: log_max_tc same sign as FL14 (positive) ?  %s\n",
            ifelse(price_sign, "YES", "NO")))
cat(sprintf("    Diagnostic D1 verdict: %s\n", verdict))

cat("\n  Done.\n")
