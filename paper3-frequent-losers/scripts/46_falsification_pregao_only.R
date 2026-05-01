# ============================================================================
# 46_falsification_pregao_only.R — falsification on pregão-only subsample
# Paper 3 v14 / Path A+ submission reinforcement
#
# Question: does the loser-side concentration screen still work in the
# subsample WITHOUT the convite minimum-bidder rule?
#
# If yes: the screen is robust to rule presence — strengthens claim that
#   the construct identifies coordination behavior, not regulatory artifact.
# If no: the screen depends on the rule — informative for scope but
#   reframes the contribution.
#
# Tests on pregão-only items (no minimum-bidder rule):
#   1. Within-item price regression (FL14 binary + continuous log_max_tc)
#   2. Firm-level AUC vs cobidders (using only firms primarily in pregão)
#   3. Item-level cobidder presence prediction (loss intensity score)
#   4. Comparison: same regressions on convite-only subsample
#
# Pass criterion: pregão-only point estimates of FL price coefficient
# remain positive and significant; AUCs remain >= 0.85; complete
# robustness across modal split.
#
# Output: output/falsification_pregao/falsification_results.csv
# ============================================================================

cat("=== 46_falsification_pregao_only.R: pregão-only falsification ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "falsification_pregao")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data --------------------------------------------------------
dt <- readRDS("/tmp/p3_prepared.rds")
fp <- as.data.table(read_parquet(file.path(BASE,"data/processed/FREQ_PARTICIP_rebuilt.parquet")))
fp[, firm_code := as.character(`códigofornecedor`)]
ftm <- as.data.table(read_parquet(file.path(BASE,"data/processed/firm_tender_map.parquet")))
ftm[, firm_code := as.character(`códigofornecedor`)]
ftm[, oc_item_key := paste0(numerodaoc, "_", `códigoitem`)]
cobid <- fread(file.path(BASE,"data/processed/cade_fl_cobidders.csv"))
cobid[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]

THRESH <- 14L
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, fl14    := as.integer(tenders_count > THRESH)]
al[, log_tc  := log1p(tenders_count)]
al[, is_cade := as.integer(firm_code %in% unique(cobid$firm_code))]

# ---- Item-level loser-side intensity ----------------------------------
ftm_loser <- merge(ftm[won == 0L],
                    fp[always_loser == 1L, .(firm_code, tenders_count)],
                    by = "firm_code", all.x = TRUE)
ftm_loser[is.na(tenders_count), tenders_count := 0L]
intensity <- ftm_loser[, .(max_tc = max(tenders_count, na.rm = TRUE),
                            any_fl14 = max(as.integer(tenders_count > THRESH))),
                        by = oc_item_key]
intensity[!is.finite(max_tc), max_tc := 0L]
intensity[!is.finite(any_fl14), any_fl14 := 0L]
intensity[, log_max_tc := log1p(max_tc)]

dt[, oc_item_key := paste0(oc_code, "_", item_code)]
dt <- merge(dt, intensity, by = "oc_item_key", all.x = TRUE)
for (c in c("max_tc","any_fl14","log_max_tc")) dt[is.na(get(c)), (c) := 0]

dt_main <- dt[!is.na(lneg_price)]
dt_preg <- dt_main[pregao == 1L]
dt_conv <- dt_main[convite == 1L]

cat(sprintf("\n  Sample sizes:\n"))
cat(sprintf("    Main panel:         %s\n", format(nrow(dt_main), big.mark=",")))
cat(sprintf("    Pregão-only:        %s\n", format(nrow(dt_preg), big.mark=",")))
cat(sprintf("    Convite-only:       %s\n", format(nrow(dt_conv), big.mark=",")))

# ---- TEST 1: Within-item price regression by modal subsample ----------
cat("\n--- TEST 1: Within-item price regression by modal subsample ---\n")
specs <- list()

# Pregão-only
m_preg_bin <- feols(lneg_price ~ any_fl14 | item_f + year_f + pbu_f,
                     data = dt_preg, cluster = ~item_f)
m_preg_log <- feols(lneg_price ~ log_max_tc | item_f + year_f + pbu_f,
                     data = dt_preg, cluster = ~item_f)
m_preg_both <- feols(lneg_price ~ any_fl14 + log_max_tc | item_f + year_f + pbu_f,
                      data = dt_preg, cluster = ~item_f)

# Convite-only
m_conv_bin <- feols(lneg_price ~ any_fl14 | item_f + year_f + pbu_f,
                     data = dt_conv, cluster = ~item_f)
m_conv_log <- feols(lneg_price ~ log_max_tc | item_f + year_f + pbu_f,
                     data = dt_conv, cluster = ~item_f)
m_conv_both <- feols(lneg_price ~ any_fl14 + log_max_tc | item_f + year_f + pbu_f,
                      data = dt_conv, cluster = ~item_f)

# Main (full sample) reference
m_full_bin <- feols(lneg_price ~ any_fl14 + convite | item_f + year_f + pbu_f,
                     data = dt_main, cluster = ~item_f)

print_coef <- function(m, lbl, term) {
  ct <- coeftable(m)
  if (term %in% rownames(ct)) {
    cat(sprintf("    [%-22s] %s coef = %+.4f (SE %.4f, p = %.4g)  N = %s\n",
                lbl, term,
                ct[term,"Estimate"], ct[term,"Std. Error"],
                ct[term,"Pr(>|t|)"], format(m$nobs, big.mark=",")))
  }
}

cat("\n  Pregão-only:\n")
print_coef(m_preg_bin,   "FL14 only",        "any_fl14")
print_coef(m_preg_log,   "log_max_tc only",  "log_max_tc")
print_coef(m_preg_both,  "Both",             "any_fl14")
print_coef(m_preg_both,  "Both",             "log_max_tc")

cat("\n  Convite-only:\n")
print_coef(m_conv_bin,   "FL14 only",        "any_fl14")
print_coef(m_conv_log,   "log_max_tc only",  "log_max_tc")
print_coef(m_conv_both,  "Both",             "any_fl14")
print_coef(m_conv_both,  "Both",             "log_max_tc")

cat("\n  Full sample reference:\n")
print_coef(m_full_bin,   "FL14 + convite",   "any_fl14")

# ---- TEST 2: Firm-level AUC by primary modality -----------------------
cat("\n--- TEST 2: Firm-level AUC vs cobidders by primary modality ---\n")
# Determine each firm's primary modality from raw bid data
suppressPackageStartupMessages({library(duckdb); library(DBI)})
con <- dbConnect(duckdb()); dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")
dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")

# Re-use modality assignment from script 37 — pull mod_per_item if cached
mod_csv <- file.path(BASE, "output/gate_d2/d2_modal_auc.csv")
if (file.exists(mod_csv)) {
  cat("    (Re-using modality split from gate D2 script 37)\n")
  d2 <- fread(mod_csv)
  for (pool in c("convite_primary","pregao_primary")) {
    for (sc in c("fl14","log_tc")) {
      r <- d2[d2$pool == pool & d2$score == sc]
      if (nrow(r) > 0) {
        cat(sprintf("    [%-15s | %-13s] AUC = %.4f [%.4f, %.4f]\n",
                    pool, sc, r$auc, r$ci_lo, r$ci_hi))
      }
    }
  }
} else {
  cat("    (No d2 cache — skipping detailed modal AUC)\n")
}
dbDisconnect(con, shutdown = TRUE)

# ---- TEST 3: Falsification interpretation -----------------------------
cat("\n--- TEST 3: Interpretation ---\n")
cf_preg <- coeftable(m_preg_bin)["any_fl14","Estimate"]
cf_conv <- coeftable(m_conv_bin)["any_fl14","Estimate"]
p_preg  <- coeftable(m_preg_bin)["any_fl14","Pr(>|t|)"]
p_conv  <- coeftable(m_conv_bin)["any_fl14","Pr(>|t|)"]

cat(sprintf("    Pregão-only FL premium:  %+.4f (p=%.4g)\n", cf_preg, p_preg))
cat(sprintf("    Convite-only FL premium: %+.4f (p=%.4g)\n", cf_conv, p_conv))
cat(sprintf("    Ratio pregão/convite:    %.2f\n", cf_preg / cf_conv))
cat("\n  Reading: if pregão coefficient is positive and significant, the\n")
cat("  loser-side construct is robust to absence of the minimum-bidder rule;\n")
cat("  the screen is not a regulatory artifact.\n")

# ---- Save consolidated CSV --------------------------------------------
extract <- function(m, label) {
  ct <- coeftable(m)
  out <- data.table()
  for (rn in intersect(c("any_fl14","log_max_tc"), rownames(ct))) {
    out <- rbind(out, data.table(spec = label, term = rn,
                                  coef = ct[rn,"Estimate"],
                                  se = ct[rn,"Std. Error"],
                                  pval = ct[rn,"Pr(>|t|)"],
                                  n = m$nobs))
  }
  out
}
res <- rbind(
  extract(m_preg_bin,  "Pregão only — FL14"),
  extract(m_preg_log,  "Pregão only — log_max_tc"),
  extract(m_preg_both, "Pregão only — both"),
  extract(m_conv_bin,  "Convite only — FL14"),
  extract(m_conv_log,  "Convite only — log_max_tc"),
  extract(m_conv_both, "Convite only — both"),
  extract(m_full_bin,  "Full sample — FL14 + convite")
)
fwrite(res, file.path(OUT, "falsification_results.csv"))
cat(sprintf("\n  Wrote: %s\n", file.path(OUT, "falsification_results.csv")))

cat("\n  Done.\n")
