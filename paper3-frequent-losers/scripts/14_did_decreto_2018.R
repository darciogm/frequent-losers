# ============================================================================
# 14_did_decreto_2018.R — DiD on Decreto 9.412/2018 (cap raise R$80k → R$176k)
# Paper 3 v14: Strategy 2
#
# Identification: Decreto 9.412/2018 raised the convite statutory cap from
# R$80,000 to R$176,000 in April 2018. Items with reference value in
# [R$80k, R$176k] became NEWLY convite-eligible. Items outside this range
# experienced no policy change.
#
# Pre-period (2009-01 to 2018-03): items in [R$80k, R$176k] could only use
#   pregão (above old R$80k cap). Convite share in this band ≈ 0.
# Post-period (2018-04 to 2019-12): items in [R$80k, R$176k] became convite
#   eligible. Convite share in this band increases.
#
# Treated: item_value in [R$80k, R$176k]
# Control: item_value in [R$40k, R$80k) OR [R$176k, R$300k]  (outside band,
#   close enough to be comparable)
# Time:    post = 1 if year-month >= 2018-04
#
# Outcomes:
#   y1: has_fl                    (FL prevalence — main DV)
#   y2: convite                   (first-stage modal switch — sanity check)
#   y3: log(price)                (price effect — what JLE wants)
#   y4: n_firms                   (auxiliary)
#
# Specs:
#   (1) DiD basic: y ~ Treated × Post + item_FE + ym_FE
#   (2) Event study (5 leads, 4 lags around 2018-Q2)
#   (3) Triple-diff Treated × Post × Convite (FL effect heterogeneous by modality)
#
# Robustness:
#   - Vary treated/control bands
#   - Drop items with manipulation pattern around R$80k or R$176k
#   - Year-month vs quarter aggregation
#   - Cluster SEs at item level
# ============================================================================

cat("=== 14_did_decreto_2018.R: Strategy 2 — DiD on cap raise ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
  library(ggplot2)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
DATA <- file.path(BASE, "data", "processed", "item_value_panel.parquet")
OUT  <- file.path(BASE, "output", "did_decreto_2018")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(DATA)) stop("Run 12_build_item_value.R first to build the panel.")

dt <- as.data.table(read_parquet(DATA))
cat("  Loaded:", DATA, " rows:", format(nrow(dt), big.mark = ","), "\n")
cat("  Year coverage:", paste(sort(unique(dt$year)), collapse = ", "), "\n")

# ---- Filter sample --------------------------------------------------------
# Need both modalities valid; need item_value > 0; year 2009–2019.
d <- dt[modality %in% c(1L, 3L) & item_value > 0 & is.finite(item_value) &
        !is.na(year) & year >= 2009 & year <= 2019]
cat("  Filtered sample:", format(nrow(d), big.mark = ","), "\n")

# ---- Construct treatment / time --------------------------------------------
CAP_OLD  <- 80000   # Lei 8.666/93 Art. 23 (pre-Decreto 9.412)
CAP_NEW  <- 176000  # Decreto 9.412/2018
CAP_DATE <- as.Date("2018-04-01")  # Decreto effective ~April 2018

d[, treated := as.integer(item_value >= CAP_OLD & item_value < CAP_NEW)]
d[, post    := as.integer(year > 2018 | (year == 2018 & TRUE))]  # year-only fallback
# If month is available later we can refine; for now year >= 2018 is post.
d[, post    := as.integer(year >= 2018)]

cat("  Treatment cell counts:\n")
print(d[, .N, by = .(treated, post)])

# ---- Build DiD sample ------------------------------------------------------
# Treated: [R$80k, R$176k]
# Control: [R$40k, R$80k) ∪ [R$176k, R$300k]
# Outside the [40k, 300k] window we drop (too far for parallel trends).
d_did <- d[(item_value >= 40000 & item_value < CAP_OLD) |    # control low
           (item_value >= CAP_OLD & item_value < CAP_NEW) |   # treated
           (item_value >= CAP_NEW & item_value <= 300000)]    # control high
cat("  DiD sample (R$40k–R$300k):", format(nrow(d_did), big.mark = ","), "\n")

cat("  Treated × post cell sizes within DiD sample:\n")
print(d_did[, .N, by = .(treated, post)])

# ---- Outcome variables -----------------------------------------------------
d_did[, log_value := log(item_value)]
d_did[, item_f    := factor(codigoitem)]
d_did[, year_f    := factor(year)]
d_did[, pbu_f     := factor(pbu_code)]
d_did[, convite   := as.integer(modality == 1L)]

# ---- Spec 1: First-stage — convite share -----------------------------------
cat("\n--- Spec 1a: First-stage on convite share ---\n")
m_fs <- feols(convite ~ treated * post | year_f + pbu_f,
              data = d_did, cluster = ~item_f)
print(coeftable(m_fs))

cat("\n--- Spec 1b: First-stage with item FE ---\n")
m_fs_item <- tryCatch(
  feols(convite ~ treated * post | item_f + year_f + pbu_f,
        data = d_did, cluster = ~item_f),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })
if (!is.null(m_fs_item)) print(coeftable(m_fs_item))

# ---- Spec 2: Reduced-form on FL prevalence ---------------------------------
cat("\n--- Spec 2: DiD on FL prevalence ---\n")
m_fl <- feols(has_fl ~ treated * post | year_f + pbu_f,
              data = d_did, cluster = ~item_f)
print(coeftable(m_fl))

cat("\n--- Spec 2b: With item FE ---\n")
m_fl_item <- tryCatch(
  feols(has_fl ~ treated * post | item_f + year_f + pbu_f,
        data = d_did, cluster = ~item_f),
  error = function(e) NULL)
if (!is.null(m_fl_item)) print(coeftable(m_fl_item))

# ---- Spec 3: DiD on log(item_value) — placebo (should be ~0 by construction) ---
cat("\n--- Spec 3: DiD on log(item_value) [placebo, expect ~0] ---\n")
m_lv <- feols(log_value ~ treated * post | year_f + pbu_f,
              data = d_did, cluster = ~item_f)
print(coeftable(m_lv))

# ---- Spec 4: DiD on n_firms ------------------------------------------------
cat("\n--- Spec 4: DiD on n_firms ---\n")
m_nf <- feols(n_firms ~ treated * post | year_f + pbu_f,
              data = d_did, cluster = ~item_f)
print(coeftable(m_nf))

# ---- Event study (yearly, around 2018) ------------------------------------
cat("\n--- Event study: relative year × treated, 2009-2019 ---\n")
d_did[, ev_year := year - 2018L]   # 2018 = event year (relative 0)
m_es <- tryCatch(
  feols(has_fl ~ i(ev_year, treated, ref = -1) | year_f + pbu_f,
        data = d_did, cluster = ~item_f),
  error = function(e) { cat("  Error:", conditionMessage(e), "\n"); NULL })

if (!is.null(m_es)) {
  cf <- as.data.table(coeftable(m_es), keep.rownames = TRUE)
  setnames(cf, c("term", "estimate", "se", "tstat", "pval"))
  cf[, ev_year := suppressWarnings(as.integer(gsub(".*ev_year::(-?\\d+).*",
                                                    "\\1", term)))]
  cf <- cf[!is.na(ev_year)][order(ev_year)]
  cf[, ci_lo := estimate - 1.96 * se]
  cf[, ci_hi := estimate + 1.96 * se]

  cat("  Event-study coefficients (FL prevalence, ref = ev_year=-1):\n")
  print(cf[, .(ev_year,
               coef  = round(estimate, 4),
               se    = round(se, 4),
               p     = round(pval, 4))])

  # Plot
  p_es <- ggplot(cf, aes(x = ev_year, y = estimate)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_vline(xintercept = -0.5, linetype = "dotted", color = "red") +
    geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.2) +
    geom_line() + geom_point() +
    labs(x = "Year relative to Decreto 9.412/2018",
         y = "FL prevalence (treated − control)",
         title = "Event study: FL prevalence around 2018 cap raise") +
    theme_bw()
  ggsave(file.path(OUT, "fig_event_study_fl.pdf"), p_es,
         width = 7, height = 4.5, device = cairo_pdf)
  cat("  Saved:", file.path(OUT, "fig_event_study_fl.pdf"), "\n")

  fwrite(cf, file.path(OUT, "event_study_coefs.csv"))
}

# ---- Save coefficient summary ---------------------------------------------
extract_did <- function(m, label) {
  if (is.null(m)) return(NULL)
  ct <- coeftable(m)
  rownm <- "treated:post"
  if (!rownm %in% rownames(ct)) return(NULL)
  data.table(
    spec    = label,
    coef    = ct[rownm, "Estimate"],
    se      = ct[rownm, "Std. Error"],
    pval    = ct[rownm, "Pr(>|t|)"],
    n       = m$nobs
  )
}

summary_dt <- rbindlist(list(
  extract_did(m_fs,      "first_stage_convite"),
  extract_did(m_fs_item, "first_stage_convite_itemFE"),
  extract_did(m_fl,      "fl_prevalence"),
  extract_did(m_fl_item, "fl_prevalence_itemFE"),
  extract_did(m_lv,      "log_value_placebo"),
  extract_did(m_nf,      "n_firms")
), fill = TRUE)

fwrite(summary_dt, file.path(OUT, "did_summary.csv"))
cat("\n  Saved summary:", file.path(OUT, "did_summary.csv"), "\n")
cat("\n  ===== Headline results =====\n")
print(summary_dt[, .(spec, coef = round(coef, 4), se = round(se, 4),
                     pval = round(pval, 4), n = format(n, big.mark = ","))])

cat("\n  Done.\n")
