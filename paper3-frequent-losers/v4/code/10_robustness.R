# ============================================================================
# 10_robustness.R — Expanded robustness checks (v4)
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# From v3: threshold sensitivity, placebo, HTE, clustering, sensemakr, matching
# NEW: unrestricted sample [Medium 4.4]
# NEW: homogeneous sub-samples (fuel, A4, generic medicines) [R2.5]
# ============================================================================

cat("=== 10_robustness.R: Robustness checks ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

suppressPackageStartupMessages({
  library(sensemakr)
  library(MatchIt)
})

if (!file.exists(DATA_CACHE_V4)) stop("Run 01_data_prep.R first")
dt <- readRDS(DATA_CACHE_V4)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")
has_ftm <- file.exists(ftm_file)
if (has_ftm) {
  ftm <- as.data.table(read_parquet(ftm_file))
  ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
  if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
  setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
  setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)
}

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]

# ============================================================================
# 10a: IQR threshold sensitivity
# ============================================================================

cat("  10a: IQR threshold sensitivity...\n")

thresholds <- c(1.0, 1.5, 2.0, 2.5, 3.0)
threshold_results <- list()

for (mult in thresholds) {
  thr <- q[2] + mult * iqr_val
  fl_ids_t <- fp[tenders_count > thr, firm_id]
  n_fl <- length(fl_ids_t)
  cat(sprintf("    IQR %.1fx: threshold=%.0f, %d FL firms\n", mult, thr, n_fl))

  if (has_ftm) {
    ftm_fl <- ftm[firm_id %chin% fl_ids_t]
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

# ============================================================================
# 10b: Unrestricted sample [Medium 4.4]
# ============================================================================

cat("  10b: Unrestricted sample...\n")

m_unrestricted <- NULL
if (file.exists(DATA_CACHE_V4_FULL)) {
  dt_full <- readRDS(DATA_CACHE_V4_FULL)
  dt_full_price <- dt_full[!is.na(lneg_price)]
  cat(sprintf("  Unrestricted sample (price valid): %s rows\n", pfmt_int(nrow(dt_full_price))))

  m_unrestricted <- feols(
    lneg_price ~ losers + convite | item_f + year_f + pbu_f,
    data = dt_full_price, cluster = ~item_f, fixef.rm = "none"
  )

  cat(sprintf("  Unrestricted: losers=%.4f (%.4f) N=%s\n",
              coef(m_unrestricted)["losers"],
              sqrt(vcov(m_unrestricted)["losers", "losers"]),
              pfmt_int(m_unrestricted$nobs)))
  rm(dt_full); gc(verbose = FALSE)
}

# Write unrestricted table
if (!is.null(m_unrestricted)) {
  cat("  Writing tab_unrestricted_sample.tex...\n")

  models_v4 <- readRDS(MODELS_CACHE_V4)
  m_baseline <- models_v4$prices$general_pbu

  ur_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Price Regression: Restricted vs.\\ Unrestricted Sample}",
    "\\label{tab:unrestricted_sample}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcc}", "\\toprule",
    " & (1) Restricted & (2) Unrestricted \\\\",
    "\\midrule",
    sprintf("FL presence & %s & %s \\\\",
            coef_cell(m_baseline, "losers", 4),
            coef_cell(m_unrestricted, "losers", 4)),
    sprintf(" & %s & %s \\\\",
            se_cell(m_baseline, "losers", 4),
            se_cell(m_unrestricted, "losers", 4)),
    "\\midrule",
    sprintf("Observations & %s & %s \\\\",
            pfmt_int(m_baseline$nobs), pfmt_int(m_unrestricted$nobs)),
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} Restricted = item types with $\\geq$1 FL tender (baseline).",
    "Unrestricted = all item types. Item, year, PBU FE. SE clustered at item level.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")
  writeLines(ur_lines, file.path(OUT_TAB, "tab_unrestricted_sample.tex"))
}

# ============================================================================
# 10c: Homogeneous sub-samples — Price-CV approach (Comment 3.1)
# ============================================================================

cat("  10c: Homogeneous sub-samples (price-CV approach)...\n")

homo_results <- list()
cv_results <- list()

# Compute within-item-group price CV
d_price <- dt[!is.na(lneg_price)]
item_group_cv <- d_price[, .(
  price_cv = sd(lneg_price, na.rm = TRUE) / abs(mean(lneg_price, na.rm = TRUE)),
  n_obs = .N
), by = item_group]
item_group_cv <- item_group_cv[n_obs >= 100]  # require reasonable sample

cv_median <- median(item_group_cv$price_cv, na.rm = TRUE)
cat(sprintf("  Item groups with >=100 obs: %s, CV median: %.4f\n",
            pfmt_int(nrow(item_group_cv)), cv_median))

low_cv_groups  <- item_group_cv[price_cv <= cv_median, item_group]
high_cv_groups <- item_group_cv[price_cv > cv_median, item_group]

cat(sprintf("  Low-CV (homogeneous): %d groups, High-CV (heterogeneous): %d groups\n",
            length(low_cv_groups), length(high_cv_groups)))

# Run FL regression on each subsample
for (cv_type in c("low", "high")) {
  grps <- if (cv_type == "low") low_cv_groups else high_cv_groups
  d_sub <- d_price[item_group %in% grps]
  cat(sprintf("  %s-CV subsample: N=%s\n", cv_type, pfmt_int(nrow(d_sub))))

  if (nrow(d_sub) >= 1000) {
    m_sub <- tryCatch(
      feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
            data = d_sub, cluster = ~item_f, fixef.rm = "none"),
      error = function(e) { cat(sprintf("    %s-CV failed: %s\n", cv_type, e$message)); NULL }
    )
    if (!is.null(m_sub)) {
      cv_results[[cv_type]] <- list(
        model = m_sub,
        n = m_sub$nobs,
        coef = coef(m_sub)["losers"],
        se = sqrt(vcov(m_sub)["losers", "losers"]),
        n_groups = length(grps)
      )
      cat(sprintf("    %s-CV: coef=%.4f (SE=%.4f), N=%s\n", cv_type,
                  cv_results[[cv_type]]$coef,
                  cv_results[[cv_type]]$se,
                  pfmt_int(cv_results[[cv_type]]$n)))
    }
  }
}

# Top-20 most frequent item groups
top_groups <- d_price[, .N, by = item_group][order(-N)][1:20]
top_groups <- merge(top_groups, item_group_cv, by = "item_group", all.x = TRUE)
cat("  Top-20 item groups by N:\n")
print(top_groups)

# Write tab_homogeneous_cv.tex
cat("  Writing tab_homogeneous_cv.tex...\n")

homo_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{FL Price Effect by Item-Group Price Homogeneity}",
  "\\label{tab:homogeneous_cv}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}", "\\toprule",
  " & (1) Low CV & (2) High CV & (3) Baseline \\\\",
  " & (homogeneous) & (heterogeneous) & (all) \\\\",
  "\\midrule"
)

# Get baseline model
models_loaded <- if (file.exists(MODELS_CACHE_V4)) readRDS(MODELS_CACHE_V4) else NULL
m_baseline <- if (!is.null(models_loaded)) models_loaded$prices$general_pbu else NULL

vals <- character(3); ses_row <- character(3)
for (i in 1:3) {
  m <- if (i == 1 && !is.null(cv_results[["low"]])) cv_results[["low"]]$model
       else if (i == 2 && !is.null(cv_results[["high"]])) cv_results[["high"]]$model
       else if (i == 3) m_baseline
       else NULL
  if (!is.null(m) && "losers" %in% names(coef(m))) {
    vals[i] <- coef_cell(m, "losers", 4)
    ses_row[i] <- se_cell(m, "losers", 4)
  } else { vals[i] <- "---"; ses_row[i] <- "" }
}

homo_lines <- c(homo_lines,
  sprintf("FL presence & %s \\\\", paste(vals, collapse = " & ")),
  sprintf(" & %s \\\\", paste(ses_row, collapse = " & ")),
  "\\midrule")

obs <- character(3)
obs[1] <- if (!is.null(cv_results[["low"]])) pfmt_int(cv_results[["low"]]$n) else "---"
obs[2] <- if (!is.null(cv_results[["high"]])) pfmt_int(cv_results[["high"]]$n) else "---"
obs[3] <- if (!is.null(m_baseline)) pfmt_int(m_baseline$nobs) else "---"
homo_lines <- c(homo_lines, sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")))

ngrp <- character(3)
ngrp[1] <- if (!is.null(cv_results[["low"]])) as.character(cv_results[["low"]]$n_groups) else "---"
ngrp[2] <- if (!is.null(cv_results[["high"]])) as.character(cv_results[["high"]]$n_groups) else "---"
ngrp[3] <- pfmt_int(nrow(item_group_cv))
homo_lines <- c(homo_lines, sprintf("Item groups & %s \\\\", paste(ngrp, collapse = " & ")))

homo_lines <- c(homo_lines,
  sprintf("CV median split & \\multicolumn{3}{c}{%.4f} \\\\", cv_median),
  "Item + Year + PBU FE & YES & YES & YES \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Within-item-group price CV computed as $\\sigma / |\\mu|$",
  "of log negotiated prices. Groups split at the median CV.",
  "Low CV = homogeneous goods (standardized items); High CV = heterogeneous goods.",
  "SE clustered at item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")
writeLines(homo_lines, file.path(OUT_TAB, "tab_homogeneous_cv.tex"))

homo_results <- cv_results  # for saving

# ============================================================================
# 10d: Clustering robustness
# ============================================================================

cat("  10d: Clustering robustness...\n")

d_price <- dt[!is.na(lneg_price)]
m_item_cl <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                    data = d_price, cluster = ~item_f, fixef.rm = "none")
m_pbu_cl  <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                    data = d_price, cluster = ~pbu_f, fixef.rm = "none")
m_twoway  <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                    data = d_price, cluster = ~item_f + pbu_f, fixef.rm = "none")

cat(sprintf("  SE(item): %.4f, SE(pbu): %.4f, SE(two-way): %.4f\n",
            sqrt(vcov(m_item_cl)["losers", "losers"]),
            sqrt(vcov(m_pbu_cl)["losers", "losers"]),
            sqrt(vcov(m_twoway)["losers", "losers"])))

# ============================================================================
# 10e: Sensemakr
# ============================================================================

cat("  10e: Sensemakr...\n")

dt_sens <- d_price[, .(lneg_price, losers, convite, year)]
m_ols <- lm(lneg_price ~ losers + convite + factor(year), data = dt_sens)
sens <- sensemakr(model = m_ols, treatment = "losers",
                  benchmark_covariates = "convite", kd = 1:3)
cat(sprintf("  RV_q=1: %.3f, RV_qa=0.05: %.3f\n",
            sens$sensitivity_stats$rv_q, sens$sensitivity_stats$rv_qa))

# ============================================================================
# 10f: CEM + IPW matching
# ============================================================================

cat("  10f: Matching estimators...\n")

d_match <- dt[!is.na(pbu_size_q) & !is.na(item_group)]
max_n <- 1000000L
if (nrow(d_match) > max_n) {
  set.seed(42)
  d_match <- d_match[sample(.N, max_n)]
}

cem_model <- NULL
cem_result <- tryCatch(
  matchit(losers ~ year + convite + item_group + pbu_size_q,
          data = d_match, method = "cem"),
  error = function(e) NULL
)
if (!is.null(cem_result)) {
  d_cem <- as.data.table(match.data(cem_result))
  d_cem_price <- d_cem[!is.na(lneg_price)]
  if (nrow(d_cem_price) > 100) {
    cem_model <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                       data = d_cem_price, weights = ~weights,
                       cluster = ~item_f, fixef.rm = "none")
    cat(sprintf("  CEM: %.4f (N=%s)\n",
                coef(cem_model)["losers"], pfmt_int(cem_model$nobs)))
  }
}

ipw_model <- NULL
d_ipw <- copy(d_match)
d_ipw[, year_c := year - min(year)]
pscore_fit <- tryCatch(
  glm(losers ~ year_c + convite + log(n_firms + 1) + factor(pbu_size_q),
      data = d_ipw, family = binomial(link = "logit")),
  error = function(e) NULL
)
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
    cat(sprintf("  IPW: %.4f (N=%s)\n",
                coef(ipw_model)["losers"], pfmt_int(ipw_model$nobs)))
  }
}

# ============================================================================
# 10g: HTE by procedure type and tender value
# ============================================================================

cat("  10g: HTE...\n")

hte_tvq <- list()
for (tvq in 1:4) {
  d_tvq <- dt[tender_value_q == tvq & !is.na(lneg_price)]
  if (nrow(d_tvq) > 100) {
    m_tvq <- feols(lneg_price ~ losers + convite | item_f + year_f,
                   data = d_tvq, cluster = ~item_f, fixef.rm = "none")
    hte_tvq[[as.character(tvq)]] <- m_tvq
  }
}

# ============================================================================
# Save
# ============================================================================

robustness <- list(
  thresholds = threshold_results,
  unrestricted = m_unrestricted,
  homogeneous = homo_results,
  clustering = list(item = m_item_cl, pbu = m_pbu_cl, twoway = m_twoway),
  sensemakr = sens,
  matching = list(cem = cem_model, ipw = ipw_model),
  hte_tender_value = hte_tvq
)

saveRDS(robustness, ROBUSTNESS_CACHE_V4)
cat("  Robustness results saved:", ROBUSTNESS_CACHE_V4, "\n")
cat("  Done.\n")
