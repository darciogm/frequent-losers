# ============================================================================
# 12_robustness.R — Comprehensive robustness checks (v2)
# Paper 3 v2: Frequent Losers as Cover Bidders
# ============================================================================
# 12a: IQR threshold sensitivity (reuse v1 pattern)
# 12b: Placebo treatment years (new: C&S framework)
# 12c: HTE by procedure type and contract size (reuse v1)
# 12d: Geographic clustering permutation test (new)
# 12e: Sensemakr sensitivity (reuse v1)
# 12f: Matching estimators (CEM + IPW, reuse v1)
# ============================================================================

cat("=== 12_robustness.R: Robustness checks ===\n")

if (!exists(".v2_dir")) .v2_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v2_dir, "code", "00_setup.R"), local = TRUE)

suppressPackageStartupMessages({
  library(sensemakr)
  library(MatchIt)
})

# ---- Load data ---------------------------------------------------------------
if (!file.exists(DATA_CACHE_V2)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V2)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

# Load FTM for reclassification
ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")
if (file.exists(ftm_file)) {
  ftm <- as.data.table(read_parquet(ftm_file))
  ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
  if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
  setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
  setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)
  has_ftm <- TRUE
} else {
  has_ftm <- FALSE
  cat("  WARNING: firm_tender_map.parquet not found. Skipping reclassification.\n")
}

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]

dvs <- c("lneg_price", "ln_firms", "ln_bids")
dv_labels <- c("Log Price", "Log Firms", "Log Bids")

# ============================================================================
# 12a: IQR threshold sensitivity
# ============================================================================

cat("  12a: IQR threshold sensitivity...\n")

thresholds <- c(1.0, 1.5, 2.0, 2.5, 3.0)
threshold_results <- list()

for (mult in thresholds) {
  thr <- q[2] + mult * iqr_val
  fl_ids <- fp[tenders_count > thr, firm_id]
  n_fl <- length(fl_ids)
  cat(sprintf("    IQR %.1fx: threshold=%.0f, %d FL firms\n", mult, thr, n_fl))

  if (has_ftm) {
    ftm_fl <- ftm[firm_id %chin% fl_ids]
    new_losers <- ftm_fl[, .(losers_count_new = .N), by = .(oc_code, item_code)]

    dt_thr <- copy(dt)
    dt_thr[, losers_count_new := NULL]
    dt_thr <- merge(dt_thr, new_losers, by = c("oc_code", "item_code"), all.x = TRUE)
    dt_thr[is.na(losers_count_new), losers_count_new := 0L]
    dt_thr[, losers := as.integer(losers_count_new > 0L)]
  } else {
    dt_thr <- copy(dt)
  }

  m <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
             data = dt_thr[!is.na(lneg_price)], cluster = ~item_f, fixef.rm = "none")

  threshold_results[[as.character(mult)]] <- list(
    multiplier = mult, threshold = thr, n_fl_firms = n_fl,
    coef = coef(m)["losers"], se = sqrt(vcov(m)["losers", "losers"]),
    n = m$nobs, r2 = fitstat(m, "r2")[[1]]
  )
}

# Write threshold table
cat("  Writing tab_threshold_robustness.tex...\n")
thr_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Sensitivity to IQR Threshold Multiplier}",
  "\\label{tab:threshold_robustness}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccccc}", "\\toprule",
  "IQR Multiplier & Threshold & FL Firms & Losers Coef. & SE & N \\\\",
  "\\midrule"
)

for (r in threshold_results) {
  p <- 2 * pnorm(-abs(r$coef / r$se))
  thr_lines <- c(thr_lines, sprintf(
    "%.1f$\\times$ & %.0f & %s & %s%s & (%s) & %s \\\\",
    r$multiplier, r$threshold, pfmt_int(r$n_fl_firms),
    pfmt(r$coef, 4), pstars(p), pfmt(r$se, 4), pfmt_int(r$n)
  ))
}

thr_lines <- c(thr_lines, "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} DV: log negotiated price. Item, year, PBU FE.",
  "SE clustered at item level. Reclassification via firm-tender map.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(thr_lines, file.path(OUT_TAB, "tab_threshold_robustness.tex"))

# ============================================================================
# 12b: Placebo treatment years
# ============================================================================

cat("  12b: Placebo treatment years...\n")

# Randomly reassign first_fl_year_market to test for spurious effects
set.seed(42)
placebo_panel <- dt[, .(
  log_price = mean(lneg_price, na.rm = TRUE),
  cover_tender = max(losers),
  n_obs = .N
), by = .(market_id, year)]

fly_real <- dt[losers == 1, .(first_fl_year = min(year)), by = market_id]
treated_markets <- fly_real$market_id

# Randomly reassign treatment years
placebo_years <- sample(fly_real$first_fl_year)
fly_placebo <- data.table(market_id = treated_markets, placebo_year = placebo_years)

placebo_panel <- merge(placebo_panel, fly_placebo, by = "market_id", all.x = TRUE)
placebo_panel[, placebo_treat := as.integer(!is.na(placebo_year) & year >= placebo_year)]

d_plac <- placebo_panel[!is.na(log_price)]
d_plac[, market_f := factor(market_id)]
d_plac[, year_f := factor(year)]

m_placebo <- tryCatch(
  feols(log_price ~ placebo_treat | market_f + year_f,
        data = d_plac, cluster = ~market_f, fixef.rm = "none"),
  error = function(e) {
    cat(sprintf("  Placebo failed: %s\n", e$message))
    NULL
  }
)

if (!is.null(m_placebo)) {
  b_pl <- coef(m_placebo)["placebo_treat"]
  se_pl <- sqrt(vcov(m_placebo)["placebo_treat", "placebo_treat"])
  p_pl <- 2 * pnorm(-abs(b_pl / se_pl))
  cat(sprintf("  Placebo: coef=%.4f (SE=%.4f) p=%.4f %s\n",
              b_pl, se_pl, p_pl,
              if (p_pl > 0.10) "(null, as expected)" else "(significant!)"))
}

# ============================================================================
# 12c: Heterogeneous treatment effects
# ============================================================================

cat("  12c: HTE by procedure type and contract size...\n")

# By procedure
m_pregao <- feols(lneg_price ~ losers | item_f + year_f + pbu_f,
                  data = dt[pregao == 1L & !is.na(lneg_price)],
                  cluster = ~item_f, fixef.rm = "none")
m_convite <- feols(lneg_price ~ losers | item_f + year_f + pbu_f,
                   data = dt[convite == 1L & !is.na(lneg_price)],
                   cluster = ~item_f, fixef.rm = "none")

cat(sprintf("  Pregão: coef=%.4f, Convite: coef=%.4f\n",
            coef(m_pregao)["losers"], coef(m_convite)["losers"]))

# By tender value quartile
hte_tvq <- list()
for (tvq in 1:4) {
  d_tvq <- dt[tender_value_q == tvq & !is.na(lneg_price)]
  if (nrow(d_tvq) > 100) {
    m_tvq <- feols(lneg_price ~ losers + convite | item_f + year_f,
                   data = d_tvq, cluster = ~item_f, fixef.rm = "none")
    hte_tvq[[as.character(tvq)]] <- m_tvq
    cat(sprintf("  TVQ %d: coef=%.4f (N=%s)\n", tvq,
                coef(m_tvq)["losers"], pfmt_int(m_tvq$nobs)))
  }
}

# ============================================================================
# 12d: Geographic clustering permutation test
# ============================================================================

cat("  12d: Geographic clustering permutation...\n")

# Test: cluster SE at PBU level (geographic) vs item level
m_pbu_cluster <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                       data = dt[!is.na(lneg_price)],
                       cluster = ~pbu_f, fixef.rm = "none")
m_item_cluster <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                        data = dt[!is.na(lneg_price)],
                        cluster = ~item_f, fixef.rm = "none")
m_twoway <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                  data = dt[!is.na(lneg_price)],
                  cluster = ~item_f + pbu_f, fixef.rm = "none")

cat(sprintf("  SE(item): %.4f, SE(pbu): %.4f, SE(two-way): %.4f\n",
            sqrt(vcov(m_item_cluster)["losers", "losers"]),
            sqrt(vcov(m_pbu_cluster)["losers", "losers"]),
            sqrt(vcov(m_twoway)["losers", "losers"])))

# ============================================================================
# 12e: Sensemakr sensitivity
# ============================================================================

cat("  12e: Sensemakr sensitivity...\n")

dt_sens <- dt[!is.na(lneg_price)]
m_ols <- lm(lneg_price ~ losers + convite + factor(year), data = dt_sens)

sens <- sensemakr(model = m_ols, treatment = "losers",
                  benchmark_covariates = "convite", kd = 1:3)

cat(sprintf("  RV_q=1: %.3f\n", sens$sensitivity_stats$rv_q))
cat(sprintf("  RV_qa=0.05: %.3f\n", sens$sensitivity_stats$rv_qa))

# ============================================================================
# 12f: CEM + IPW matching
# ============================================================================

cat("  12f: Matching estimators...\n")

d_match <- dt[!is.na(pbu_size_q) & !is.na(item_group)]
max_n <- 1000000L
if (nrow(d_match) > max_n) {
  set.seed(42)
  d_match <- d_match[sample(.N, max_n)]
}

# CEM
cem_result <- tryCatch(
  matchit(losers ~ year + convite + item_group + pbu_size_q,
          data = d_match, method = "cem"),
  error = function(e) { cat(sprintf("  CEM failed: %s\n", e$message)); NULL }
)

cem_model <- NULL
if (!is.null(cem_result)) {
  d_cem <- as.data.table(match.data(cem_result))
  d_cem_price <- d_cem[!is.na(lneg_price)]
  if (nrow(d_cem_price) > 100) {
    cem_model <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                       data = d_cem_price, weights = ~weights,
                       cluster = ~item_f, fixef.rm = "none")
    cat(sprintf("  CEM: coef=%.4f (N=%s)\n",
                coef(cem_model)["losers"], pfmt_int(cem_model$nobs)))
  }
}

# IPW
d_ipw <- copy(d_match)
d_ipw[, year_c := year - min(year)]
pscore_fit <- tryCatch(
  glm(losers ~ year_c + convite + log(n_firms + 1) + factor(pbu_size_q),
      data = d_ipw, family = binomial(link = "logit")),
  error = function(e) NULL
)

ipw_model <- NULL
if (!is.null(pscore_fit)) {
  d_ipw[, pscore := predict(pscore_fit, type = "response")]
  d_ipw <- d_ipw[pscore > 0.01 & pscore < 0.99]
  d_ipw[, ipw := fifelse(losers == 1, 1 / pscore, 1 / (1 - pscore))]
  d_ipw[, ipw := ipw / mean(ipw)]

  d_ipw_price <- d_ipw[!is.na(lneg_price)]
  if (nrow(d_ipw_price) > 100) {
    ipw_model <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                       data = d_ipw_price, weights = ~ipw,
                       cluster = ~item_f, fixef.rm = "none")
    cat(sprintf("  IPW: coef=%.4f (N=%s)\n",
                coef(ipw_model)["losers"], pfmt_int(ipw_model$nobs)))
  }
}

# ============================================================================
# Save robustness models
# ============================================================================

robustness <- list(
  thresholds = threshold_results,
  placebo_years = if (!is.null(m_placebo)) m_placebo else NULL,
  hte_procedure = list(pregao = m_pregao, convite = m_convite),
  hte_tender_value = hte_tvq,
  clustering = list(item = m_item_cluster, pbu = m_pbu_cluster, twoway = m_twoway),
  sensemakr = sens,
  matching = list(cem = cem_model, ipw = ipw_model)
)

saveRDS(robustness, "/tmp/p3v2_robustness.rds")
cat("  Robustness results saved: /tmp/p3v2_robustness.rds\n")
cat("  Done.\n")
