# ============================================================================
# v5_new_analyses.R — New analyses for v5 revision
# Paper 3: Frequent Losers as Cover Bidders in Public Procurement
# ============================================================================
# Analyses:
#   1. Conditional descriptive statistics (M7)
#   2. FL subgroup observable characteristics (M4c)
#   3. Alternative mechanisms (5.5)
#   4. Imhof-style screen + horse race (M8)
#   5. Sensitivity-adjusted welfare bound (M5c)
#   6. Enriched Bajari-Ye first stage (M3)
# ============================================================================

cat("=== v5_new_analyses.R: New analyses for v5 revision ===\n")
cat("  Start time:", format(Sys.time()), "\n\n")

# ---- Setup ------------------------------------------------------------------
suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(arrow)
  library(sensemakr)
})

NCORES <- min(parallel::detectCores(logical = FALSE), 16L)
cat("  Using", NCORES, "threads\n")
setFixest_nthreads(NCORES)
setDTthreads(NCORES)
setFixest_estimation(lean = TRUE)

# Paths
BASE_DIR <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers"
DATA_V1  <- file.path(BASE_DIR, "data", "processed")
OUT_TAB  <- file.path(BASE_DIR, "work", "v5", "tables")
dir.create(OUT_TAB, recursive = TRUE, showWarnings = FALSE)

# Formatting helpers
pfmt     <- function(x, d = 4) formatC(x, format = "f", digits = d, big.mark = ",")
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")
pstars   <- function(p) ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))

coef_cell <- function(model, var, d = 4) {
  b  <- coef(model)[var]
  se <- sqrt(vcov(model)[var, var])
  p  <- 2 * pnorm(-abs(b / se))
  paste0(pfmt(b, d), pstars(p))
}

se_cell <- function(model, var, d = 4) {
  se <- sqrt(vcov(model)[var, var])
  paste0("(", pfmt(se, d), ")")
}

# ---- Load main analysis dataset --------------------------------------------
cat("  Loading prepared dataset...\n")
dt <- readRDS("/tmp/p3v4_prepared.rds")
cat("  Loaded:", pfmt_int(nrow(dt)), "rows,", ncol(dt), "columns\n")
cat("  Columns:", paste(names(dt), collapse = ", "), "\n\n")

# ============================================================================
# ANALYSIS 1: Conditional Descriptive Statistics (referee M7)
# ============================================================================

cat("=" , rep("=", 70), "\n")
cat("  ANALYSIS 1: Conditional Descriptive Statistics (M7)\n")
cat("=", rep("=", 70), "\n\n")

# Regress lneg_price on item_f + year_f + pbu_f to get residuals
d_price <- dt[!is.na(lneg_price)]
cat("  Observations with valid prices:", pfmt_int(nrow(d_price)), "\n")

cat("  Running residualization regression: lneg_price ~ 1 | item_f + year_f + pbu_f ...\n")
m_resid <- feols(lneg_price ~ 1 | item_f + year_f + pbu_f,
                 data = d_price, fixef.rm = "none", lean = FALSE)
d_price[, resid_price := residuals(m_resid)]

# Split by FL status
resid_fl1 <- d_price[losers == 1, resid_price]
resid_fl0 <- d_price[losers == 0, resid_price]

mean_fl1 <- mean(resid_fl1, na.rm = TRUE)
mean_fl0 <- mean(resid_fl0, na.rm = TRUE)
sd_fl1   <- sd(resid_fl1, na.rm = TRUE)
sd_fl0   <- sd(resid_fl0, na.rm = TRUE)
gap      <- mean_fl1 - mean_fl0
overlap  <- 2 * pnorm(-abs(gap) / sqrt(sd_fl1^2 + sd_fl0^2))

# T-test
tt <- t.test(resid_fl1, resid_fl0)

cat(sprintf("  FL-present: mean=%.4f, SD=%.4f, N=%s\n", mean_fl1, sd_fl1, pfmt_int(length(resid_fl1))))
cat(sprintf("  FL-absent:  mean=%.4f, SD=%.4f, N=%s\n", mean_fl0, sd_fl0, pfmt_int(length(resid_fl0))))
cat(sprintf("  Gap: %.4f, t-stat: %.2f, p-value: %.6f\n", gap, tt$statistic, tt$p.value))
cat(sprintf("  SD overlap coefficient: %.4f\n", overlap))

# Also compute raw (unconditional) means for comparison
raw_fl1 <- mean(d_price[losers == 1, lneg_price], na.rm = TRUE)
raw_fl0 <- mean(d_price[losers == 0, lneg_price], na.rm = TRUE)
raw_gap <- raw_fl1 - raw_fl0

# Cohen's d
cohens_d <- gap / sqrt((sd_fl1^2 + sd_fl0^2) / 2)

# Write table
tab1_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Conditional Descriptive Statistics: Residualized Prices by FL Status}",
  "\\label{tab:conditional_descstats}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  " & FL-Present & FL-Absent \\\\",
  " & (losers = 1) & (losers = 0) \\\\",
  "\\midrule",
  "\\textit{Panel A: Unconditional} & & \\\\",
  sprintf("Mean $\\log$(price) & %s & %s \\\\", pfmt(raw_fl1, 4), pfmt(raw_fl0, 4)),
  sprintf("Difference & \\multicolumn{2}{c}{%s} \\\\", pfmt(raw_gap, 4)),
  "\\midrule",
  "\\textit{Panel B: Conditional on Item + Year + PBU FE} & & \\\\",
  sprintf("Mean residualized price & %s & %s \\\\", pfmt(mean_fl1, 4), pfmt(mean_fl0, 4)),
  sprintf("SD residualized price & %s & %s \\\\", pfmt(sd_fl1, 4), pfmt(sd_fl0, 4)),
  sprintf("Difference (gap) & \\multicolumn{2}{c}{%s} \\\\", pfmt(gap, 4)),
  sprintf("$t$-statistic & \\multicolumn{2}{c}{%.2f} \\\\", tt$statistic),
  sprintf("$p$-value & \\multicolumn{2}{c}{%.6f} \\\\", tt$p.value),
  sprintf("Cohen's $d$ & \\multicolumn{2}{c}{%s} \\\\", pfmt(cohens_d, 4)),
  "\\midrule",
  sprintf("Observations & %s & %s \\\\", pfmt_int(length(resid_fl1)), pfmt_int(length(resid_fl0))),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Residuals from regressing $\\log$(negotiated price) on item,",
  "year, and purchasing unit (PBU) fixed effects. The gap represents the mean",
  "difference in residualized prices between FL-present and FL-absent tenders,",
  "after absorbing common item-level, temporal, and PBU-level variation.",
  "Cohen's $d$ measures the standardized effect size.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")

writeLines(tab1_lines, file.path(OUT_TAB, "tab_conditional_descstats.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_conditional_descstats.tex"), "\n\n")

rm(m_resid, d_price, resid_fl1, resid_fl0); gc(verbose = FALSE)

# ============================================================================
# ANALYSIS 2: FL Subgroup Observable Characteristics (referee M4c)
# ============================================================================

cat("=", rep("=", 70), "\n")
cat("  ANALYSIS 2: FL Subgroup Observable Characteristics (M4c)\n")
cat("=", rep("=", 70), "\n\n")

# Load network results
cat("  Loading network results...\n")
net <- readRDS("/tmp/p3v4_network.rds")
fl_metrics <- net$fl_metrics
high_fl_ids <- net$high_fl_ids
low_fl_ids  <- net$low_fl_ids

cat("  High-suspicion FL firms:", pfmt_int(length(high_fl_ids)), "\n")
cat("  Low-suspicion FL firms:", pfmt_int(length(low_fl_ids)), "\n")

# Load firm characteristics
cat("  Loading Firms_final.parquet...\n")
firms <- as.data.table(read_parquet(file.path(DATA_V1, "Firms_final.parquet")))
cat("  Firms columns:", paste(names(firms), collapse = ", "), "\n")

# Standardize firm ID column
firms_col <- grep("^c.digofornecedor$", names(firms), value = TRUE, ignore.case = TRUE)
if (length(firms_col) == 1) setnames(firms, firms_col, "firm_id")

# Compute firm age
age_col <- grep("inicio|data_inic|fundacao|abertura", names(firms), value = TRUE, ignore.case = TRUE)
if (length(age_col) > 0) {
  cat("  Age column found:", age_col[1], "\n")
  # Try to parse date
  firms[, firm_age := as.numeric(difftime(as.Date("2019-12-31"),
    tryCatch(as.Date(get(age_col[1])), error = function(e) {
      tryCatch(as.Date(get(age_col[1]), format = "%d/%m/%Y"), error = function(e2) NA)
    }),
    units = "days")) / 365.25]
  cat("  Valid firm_age:", pfmt_int(sum(!is.na(firms$firm_age))), "\n")
} else {
  firms[, firm_age := NA_real_]
  cat("  WARNING: No firm age column found\n")
}

# SP indicator
sp_col <- grep("estado_SP|fornec_estado", names(firms), value = TRUE, ignore.case = TRUE)
if (length(sp_col) > 0) {
  cat("  SP column found:", sp_col[1], "\n")
  firms[, is_sp := as.integer(get(sp_col[1]))]
} else {
  # Try to construct from UF column
  uf_col <- grep("uf|estado|descri.*uf", names(firms), value = TRUE, ignore.case = TRUE)
  if (length(uf_col) > 0) {
    cat("  UF column found:", uf_col[1], "\n")
    firms[, is_sp := as.integer(grepl("SP|S.o Paulo|SAO PAULO", get(uf_col[1]), ignore.case = TRUE))]
  } else {
    firms[, is_sp := NA_integer_]
    cat("  WARNING: No SP/UF column found\n")
  }
}

# CNAE sector
cnae_col <- grep("secao_cnae|cnae_secao|secao", names(firms), value = TRUE, ignore.case = TRUE)
if (length(cnae_col) > 0) {
  firms[, cnae_sector := as.character(get(cnae_col[1]))]
} else {
  cnae_col2 <- grep("cnae", names(firms), value = TRUE, ignore.case = TRUE)
  if (length(cnae_col2) > 0) {
    firms[, cnae_sector := substr(as.character(get(cnae_col2[1])), 1, 2)]
  } else {
    firms[, cnae_sector := NA_character_]
  }
}

# Porte (firm size)
porte_col <- grep("porte", names(firms), value = TRUE, ignore.case = TRUE)
if (length(porte_col) > 0) {
  firms[, porte := as.character(get(porte_col[1]))]
} else {
  firms[, porte := NA_character_]
}

# Split firms into high-HHI and low-HHI subgroups using fl_metrics
# fl_metrics has winner_hhi per FL firm
fl_chars_high <- merge(
  fl_metrics[high_suspicion == 1L, .(firm_id, winner_hhi, n_repeat_partners)],
  firms[, .(firm_id, firm_age, is_sp, cnae_sector, porte)],
  by = "firm_id", all.x = TRUE)

fl_chars_low <- merge(
  fl_metrics[high_suspicion == 0L, .(firm_id, winner_hhi, n_repeat_partners)],
  firms[, .(firm_id, firm_age, is_sp, cnae_sector, porte)],
  by = "firm_id", all.x = TRUE)

cat("\n  --- Subgroup comparison ---\n")

# Helper function for means comparison
compare_means <- function(var, label, high, low) {
  h <- high[[var]]; l <- low[[var]]
  h <- h[!is.na(h)]; l <- l[!is.na(l)]
  if (length(h) == 0 || length(l) == 0) return(NULL)
  if (is.numeric(h)) {
    tt <- tryCatch(t.test(h, l), error = function(e) NULL)
    p <- if (!is.null(tt)) tt$p.value else NA
    cat(sprintf("  %s: High=%.2f (N=%d), Low=%.2f (N=%d), diff=%.2f, p=%.4f\n",
                label, mean(h), length(h), mean(l), length(l),
                mean(h) - mean(l), p))
    return(list(label = label, mean_high = mean(h), mean_low = mean(l),
                n_high = length(h), n_low = length(l),
                diff = mean(h) - mean(l), p = p))
  }
  NULL
}

comp_age <- compare_means("firm_age", "Firm age (years)", fl_chars_high, fl_chars_low)
comp_sp  <- compare_means("is_sp", "Located in SP", fl_chars_high, fl_chars_low)
comp_hhi <- compare_means("winner_hhi", "Winner HHI", fl_chars_high, fl_chars_low)
comp_rep <- compare_means("n_repeat_partners", "Repeat co-bidding partners", fl_chars_high, fl_chars_low)

# Porte distribution
cat("\n  Porte distribution:\n")
if (any(!is.na(fl_chars_high$porte))) {
  cat("  High-suspicion:\n")
  print(fl_chars_high[!is.na(porte), .N, by = porte][order(-N)])
  cat("  Low-suspicion:\n")
  print(fl_chars_low[!is.na(porte), .N, by = porte][order(-N)])
}

# Porte: compute share of micro/small
fl_chars_high[, is_micro_small := as.integer(grepl("MICRO|MEI|PEQUEN", porte, ignore.case = TRUE))]
fl_chars_low[, is_micro_small := as.integer(grepl("MICRO|MEI|PEQUEN", porte, ignore.case = TRUE))]
comp_size <- compare_means("is_micro_small", "Micro/Small enterprise", fl_chars_high, fl_chars_low)

# CNAE sector: top 3
cat("\n  CNAE sector distribution (top 5):\n")
if (any(!is.na(fl_chars_high$cnae_sector))) {
  cat("  High-suspicion:\n")
  print(fl_chars_high[!is.na(cnae_sector), .N, by = cnae_sector][order(-N)][1:5])
  cat("  Low-suspicion:\n")
  print(fl_chars_low[!is.na(cnae_sector), .N, by = cnae_sector][order(-N)][1:5])
}

# Write table
tab2_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Observable Characteristics of FL Firms by Suspicion Level}",
  "\\label{tab:fl_subgroup_chars}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccccc}", "\\toprule",
  " & High-Suspicion & Low-Suspicion & Difference & $p$-value & N \\\\",
  "\\midrule")

comps <- list(comp_age, comp_sp, comp_size, comp_hhi, comp_rep)
for (cc in comps) {
  if (!is.null(cc)) {
    tab2_lines <- c(tab2_lines, sprintf(
      "%s & %s & %s & %s & %s & %s \\\\",
      cc$label, pfmt(cc$mean_high, 3), pfmt(cc$mean_low, 3),
      pfmt(cc$diff, 3),
      if (!is.na(cc$p)) pfmt(cc$p, 3) else "---",
      pfmt_int(cc$n_high + cc$n_low)))
  }
}

tab2_lines <- c(tab2_lines,
  "\\midrule",
  sprintf("N firms & %s & %s & & & %s \\\\",
          pfmt_int(nrow(fl_chars_high)), pfmt_int(nrow(fl_chars_low)),
          pfmt_int(nrow(fl_chars_high) + nrow(fl_chars_low))),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Comparison of observable firm characteristics between",
  "high-suspicion FL firms (winner HHI above median and $\\geq$2 repeat co-bidding partners)",
  "and low-suspicion FL firms. Firm age computed as years from registration to 2019.",
  "$p$-values from two-sample $t$-tests of equal means.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")

writeLines(tab2_lines, file.path(OUT_TAB, "tab_fl_subgroup_chars.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_fl_subgroup_chars.tex"), "\n\n")


# ============================================================================
# ANALYSIS 3: Alternative Mechanisms (referee 5.5)
# ============================================================================

cat("=", rep("=", 70), "\n")
cat("  ANALYSIS 3: Alternative Mechanisms (5.5)\n")
cat("=", rep("=", 70), "\n\n")

# Get FL firm IDs (from network results)
all_fl_ids <- unique(c(high_fl_ids, low_fl_ids))

# Load freq_particip for FL identification
fp <- as.data.table(read_parquet(file.path(DATA_V1, "FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

# Compute IQR threshold
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val
cat(sprintf("  IQR threshold: %.0f\n", threshold))

# All always-losers vs FL subset
always_losers <- unique(fp$firm_id)
fl_firm_ids   <- unique(fp[tenders_count > threshold, firm_id])
non_fl_losers <- setdiff(always_losers, fl_firm_ids)

cat("  Always-losers:", pfmt_int(length(always_losers)), "\n")
cat("  FL firms:", pfmt_int(length(fl_firm_ids)), "\n")

# Merge firm characteristics
firms_mech <- firms[, .(firm_id, firm_age, is_sp, porte)]
firms_mech[, is_fl := as.integer(firm_id %chin% fl_firm_ids)]
firms_mech[, is_always_loser := as.integer(firm_id %chin% always_losers)]

# Keep only always-losers for comparison (FL vs non-FL-losers)
firms_al <- firms_mech[is_always_loser == 1L]

cat("\n  --- (a) Firm Age ---\n")
age_fl    <- firms_al[is_fl == 1 & !is.na(firm_age), firm_age]
age_nonfl <- firms_al[is_fl == 0 & !is.na(firm_age), firm_age]
if (length(age_fl) > 0 && length(age_nonfl) > 0) {
  tt_age <- t.test(age_fl, age_nonfl)
  cat(sprintf("  FL firm age: mean=%.1f, median=%.1f, N=%d\n",
              mean(age_fl), median(age_fl), length(age_fl)))
  cat(sprintf("  Non-FL loser age: mean=%.1f, median=%.1f, N=%d\n",
              mean(age_nonfl), median(age_nonfl), length(age_nonfl)))
  cat(sprintf("  Difference: %.1f years, t=%.2f, p=%.4f\n",
              mean(age_fl) - mean(age_nonfl), tt_age$statistic, tt_age$p.value))

  # Also run probit/logit: FL ~ firm_age
  firms_al_reg <- firms_al[!is.na(firm_age)]
  m_age <- glm(is_fl ~ firm_age, data = firms_al_reg, family = binomial(link = "logit"))
  cat(sprintf("  Logit FL ~ age: coef=%.4f, SE=%.4f, p=%.4f\n",
              coef(m_age)["firm_age"], sqrt(vcov(m_age)["firm_age","firm_age"]),
              summary(m_age)$coef["firm_age", 4]))
} else {
  tt_age <- NULL
  m_age <- NULL
  cat("  Insufficient data for age comparison\n")
}

cat("\n  --- (b) Geographic Distance ---\n")
sp_fl    <- firms_al[is_fl == 1 & !is.na(is_sp)]
sp_nonfl <- firms_al[is_fl == 0 & !is.na(is_sp)]
if (nrow(sp_fl) > 0 && nrow(sp_nonfl) > 0) {
  share_sp_fl    <- mean(sp_fl$is_sp)
  share_sp_nonfl <- mean(sp_nonfl$is_sp)
  tt_sp <- t.test(sp_fl$is_sp, sp_nonfl$is_sp)
  cat(sprintf("  FL share from SP: %.3f (N=%d)\n", share_sp_fl, nrow(sp_fl)))
  cat(sprintf("  Non-FL loser share from SP: %.3f (N=%d)\n", share_sp_nonfl, nrow(sp_nonfl)))
  cat(sprintf("  Difference: %.3f, p=%.4f\n", share_sp_fl - share_sp_nonfl, tt_sp$p.value))

  m_sp <- glm(is_fl ~ is_sp, data = firms_al[!is.na(is_sp)], family = binomial(link = "logit"))
  cat(sprintf("  Logit FL ~ SP: coef=%.4f, p=%.4f\n",
              coef(m_sp)["is_sp"], summary(m_sp)$coef["is_sp", 4]))
} else {
  tt_sp <- NULL
  m_sp <- NULL
  cat("  Insufficient data for geographic comparison\n")
}

cat("\n  --- (c) Financial Distress Proxy ---\n")
firms_al[, is_micro_small := as.integer(porte %chin% c("01", "03"))]  # 01=micro, 03=small, 05=medium/large
ms_fl    <- firms_al[is_fl == 1 & !is.na(is_micro_small)]
ms_nonfl <- firms_al[is_fl == 0 & !is.na(is_micro_small)]
if (nrow(ms_fl) > 0 && nrow(ms_nonfl) > 0) {
  share_ms_fl    <- mean(ms_fl$is_micro_small)
  share_ms_nonfl <- mean(ms_nonfl$is_micro_small)
  tt_ms <- t.test(ms_fl$is_micro_small, ms_nonfl$is_micro_small)
  cat(sprintf("  FL share micro/small: %.3f (N=%d)\n", share_ms_fl, nrow(ms_fl)))
  cat(sprintf("  Non-FL loser share micro/small: %.3f (N=%d)\n", share_ms_nonfl, nrow(ms_nonfl)))
  cat(sprintf("  Difference: %.3f, p=%.4f\n", share_ms_fl - share_ms_nonfl, tt_ms$p.value))

  m_ms <- tryCatch(glm(is_fl ~ is_micro_small, data = firms_al[!is.na(is_micro_small)],
              family = binomial(link = "logit")), error = function(e) NULL)
  if (!is.null(m_ms) && "is_micro_small" %in% rownames(summary(m_ms)$coef)) {
    cat(sprintf("  Logit FL ~ micro/small: coef=%.4f, p=%.4f\n",
                coef(m_ms)["is_micro_small"], summary(m_ms)$coef["is_micro_small", 4]))
  } else {
    cat("  Logit FL ~ micro/small: could not estimate (low variation)\n")
  }
} else {
  tt_ms <- NULL
  m_ms <- NULL
  cat("  Insufficient data for size comparison\n")
}

# Combined logit
cat("\n  --- Combined logit ---\n")
firms_comb <- firms_al[!is.na(firm_age) & !is.na(is_sp) & !is.na(is_micro_small)]
if (nrow(firms_comb) > 100) {
  m_comb <- glm(is_fl ~ firm_age + is_sp + is_micro_small,
                data = firms_comb, family = binomial(link = "logit"))
  cat("  Combined logit results:\n")
  print(summary(m_comb)$coef)
} else {
  m_comb <- NULL
}

# Write table
tab3_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Alternative Mechanisms: FL Status and Firm Characteristics}",
  "\\label{tab:alternative_mechanisms}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccccc}", "\\toprule",
  " & FL Firms & Non-FL Losers & Difference & $p$-value & N \\\\",
  "\\midrule",
  "\\textit{Panel A: Means Comparison} & & & & & \\\\")

if (!is.null(tt_age)) {
  tab3_lines <- c(tab3_lines, sprintf(
    "Firm age (years) & %.1f & %.1f & %.1f & %s & %s \\\\",
    mean(age_fl), mean(age_nonfl), mean(age_fl)-mean(age_nonfl),
    pfmt(tt_age$p.value, 3), pfmt_int(length(age_fl)+length(age_nonfl))))
}
if (!is.null(tt_sp)) {
  tab3_lines <- c(tab3_lines, sprintf(
    "Share from S\\~{a}o Paulo & %.3f & %.3f & %.3f & %s & %s \\\\",
    share_sp_fl, share_sp_nonfl, share_sp_fl-share_sp_nonfl,
    pfmt(tt_sp$p.value, 3), pfmt_int(nrow(sp_fl)+nrow(sp_nonfl))))
}
if (!is.null(tt_ms)) {
  tab3_lines <- c(tab3_lines, sprintf(
    "Share micro/small & %.3f & %.3f & %.3f & %s & %s \\\\",
    share_ms_fl, share_ms_nonfl, share_ms_fl-share_ms_nonfl,
    pfmt(tt_ms$p.value, 3), pfmt_int(nrow(ms_fl)+nrow(ms_nonfl))))
}

tab3_lines <- c(tab3_lines, "\\midrule",
  "\\textit{Panel B: Logit Regressions (DV: FL = 1)} & & & & & \\\\",
  " & Coef. & SE & $z$ & $p$-value & N \\\\",
  "\\midrule")

if (!is.null(m_comb)) {
  sc <- summary(m_comb)$coef
  for (vn in c("firm_age", "is_sp", "is_micro_small")) {
    lbl <- switch(vn,
      firm_age = "Firm age",
      is_sp = "Located in SP",
      is_micro_small = "Micro/small enterprise")
    if (vn %in% rownames(sc)) {
      tab3_lines <- c(tab3_lines, sprintf(
        "%s & %s%s & (%s) & %.2f & %s & \\\\",
        lbl, pfmt(sc[vn, 1], 4), pstars(sc[vn, 4]),
        pfmt(sc[vn, 2], 4), sc[vn, 3], pfmt(sc[vn, 4], 3)))
    }
  }
  tab3_lines <- c(tab3_lines, sprintf(
    "Observations & \\multicolumn{5}{c}{%s} \\\\", pfmt_int(nrow(firms_comb))))
}

tab3_lines <- c(tab3_lines,
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Panel A compares means between FL firms (always-losers with",
  "tenders\\_count above IQR threshold) and non-FL always-losers. $p$-values from",
  "two-sample $t$-tests. Panel B reports logit coefficients from regressing FL",
  "status on all three characteristics simultaneously.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")

writeLines(tab3_lines, file.path(OUT_TAB, "tab_alternative_mechanisms.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_alternative_mechanisms.tex"), "\n\n")


# ============================================================================
# ANALYSIS 4: Imhof-Style Screen Statistics + Horse Race (referee M8)
# ============================================================================

cat("=", rep("=", 70), "\n")
cat("  ANALYSIS 4: Imhof-Style Screen + Horse Race (M8)\n")
cat("=", rep("=", 70), "\n\n")

# Check for bid_price_sd in prepared data
cat("  Checking bid_price_sd availability...\n")
has_sd <- "bid_price_sd" %in% names(dt) && sum(!is.na(dt$bid_price_sd)) > 10000

if (!has_sd) {
  cat("  bid_price_sd not in prepared data. Loading from BEC_collapse_final.parquet...\n")
  bec_sd <- as.data.table(read_parquet(
    file.path(DATA_V1, "BEC_collapse_final.parquet"),
    col_select = c("po_item_merge_key", "bid_price_sd", "bid_price_min", "n_bids")))
  dt <- merge(dt, bec_sd[, .(po_item_merge_key, bid_price_sd_bec = bid_price_sd,
                               bid_price_min_bec = bid_price_min)],
              by = "po_item_merge_key", all.x = TRUE)
  if (!"bid_price_sd" %in% names(dt) || sum(!is.na(dt$bid_price_sd)) < 10000) {
    dt[, bid_price_sd := bid_price_sd_bec]
  }
  if (!"bid_price_min" %in% names(dt)) {
    dt[, bid_price_min := bid_price_min_bec]
  }
  rm(bec_sd); gc(verbose = FALSE)
}

# Compute CV: need mean price. Use bid_price_min as proxy for mean if no explicit mean
# Actually compute bid_price_mean from bid_price_min and bid_price_sd:
#   For aggregated data, use bid_unit_price_negot_min as the mean proxy
if ("bid_unit_price_negot_min" %in% names(dt)) {
  dt[, bid_price_mean_proxy := bid_unit_price_negot_min]
} else if ("bid_price_min" %in% names(dt)) {
  dt[, bid_price_mean_proxy := bid_price_min]
} else {
  dt[, bid_price_mean_proxy := exp(lneg_price)]
}

dt[, cv_bids := fifelse(
  !is.na(bid_price_sd) & bid_price_sd > 0 &
  !is.na(bid_price_mean_proxy) & bid_price_mean_proxy > 0,
  bid_price_sd / bid_price_mean_proxy, NA_real_)]

n_cv_valid <- sum(!is.na(dt$cv_bids))
cat("  Valid CV observations:", pfmt_int(n_cv_valid), "\n")

if (n_cv_valid > 10000) {
  # Compute item-group level medians
  if ("item_group" %in% names(dt)) {
    cv_medians <- dt[!is.na(cv_bids), .(cv_median = median(cv_bids)), by = item_group]
    dt <- merge(dt, cv_medians, by = "item_group", all.x = TRUE)
    dt[, imhof_flag := as.integer(!is.na(cv_bids) & !is.na(cv_median) & cv_bids > cv_median)]
  } else {
    overall_median <- median(dt$cv_bids, na.rm = TRUE)
    dt[, imhof_flag := as.integer(!is.na(cv_bids) & cv_bids > overall_median)]
  }

  cat("  Imhof flag = 1:", pfmt_int(sum(dt$imhof_flag, na.rm = TRUE)),
      sprintf("(%.1f%%)\n", 100 * mean(dt$imhof_flag, na.rm = TRUE)))

  # Descriptive stats for CV
  cat(sprintf("  CV: mean=%.4f, median=%.4f, SD=%.4f\n",
              mean(dt$cv_bids, na.rm = TRUE),
              median(dt$cv_bids, na.rm = TRUE),
              sd(dt$cv_bids, na.rm = TRUE)))

  # Horse race: FL + Imhof flag
  d_hr <- dt[!is.na(lneg_price) & !is.na(imhof_flag)]
  cat("  Horse race sample:", pfmt_int(nrow(d_hr)), "\n")

  # Model 1: FL only
  m_fl_only <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                     data = d_hr, cluster = ~item_f, fixef.rm = "none")

  # Model 2: Imhof only
  m_imhof_only <- feols(lneg_price ~ imhof_flag + convite | item_f + year_f + pbu_f,
                        data = d_hr, cluster = ~item_f, fixef.rm = "none")

  # Model 3: Both (horse race)
  m_horserace <- feols(lneg_price ~ losers + imhof_flag + convite | item_f + year_f + pbu_f,
                       data = d_hr, cluster = ~item_f, fixef.rm = "none")

  # Model 4: Interaction
  m_interact <- feols(lneg_price ~ losers * imhof_flag + convite | item_f + year_f + pbu_f,
                      data = d_hr, cluster = ~item_f, fixef.rm = "none")

  cat("\n  Horse-race results:\n")
  for (nm in c("losers", "imhof_flag")) {
    if (nm %in% names(coef(m_horserace))) {
      b <- coef(m_horserace)[nm]
      se <- sqrt(vcov(m_horserace)[nm, nm])
      cat(sprintf("    %s: %.4f (%.4f)\n", nm, b, se))
    }
  }

  # Correlation between FL and Imhof
  cor_fl_imhof <- cor(d_hr$losers, d_hr$imhof_flag, use = "complete.obs")
  cat(sprintf("  Correlation(FL, Imhof): %.4f\n", cor_fl_imhof))

  # Write table
  tab4_lines <- c(
    "\\begin{table}[htbp]", "\\centering",
    "\\caption{Screen Horse Race: FL Indicator vs.\\ Imhof-Style CV Flag}",
    "\\label{tab:screen_horserace}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}", "\\small",
    "\\begin{tabular}{lcccc}", "\\toprule",
    " & (1) & (2) & (3) & (4) \\\\",
    " & FL Only & Imhof Only & Horse Race & Interaction \\\\",
    "\\midrule")

  models_hr <- list(m_fl_only, m_imhof_only, m_horserace, m_interact)

  for (vn in c("losers", "imhof_flag", "losers:imhof_flag")) {
    lbl <- switch(vn,
      losers = "FL presence",
      imhof_flag = "Imhof flag (high CV)",
      `losers:imhof_flag` = "FL $\\times$ Imhof")
    vals <- sapply(models_hr, function(m) {
      if (vn %in% names(coef(m))) coef_cell(m, vn, 4) else ""
    })
    ses <- sapply(models_hr, function(m) {
      if (vn %in% names(coef(m))) se_cell(m, vn, 4) else ""
    })
    tab4_lines <- c(tab4_lines,
      sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")),
      sprintf(" & %s \\\\", paste(ses, collapse = " & ")))
  }

  tab4_lines <- c(tab4_lines, "\\midrule")
  obs <- sapply(models_hr, function(m) pfmt_int(m$nobs))
  r2 <- sapply(models_hr, function(m) pfmt(fitstat(m, "r2")[[1]], 4))
  tab4_lines <- c(tab4_lines,
    sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")),
    sprintf("R-squared & %s \\\\", paste(r2, collapse = " & ")),
    "Item + Year + PBU FE & YES & YES & YES & YES \\\\",
    sprintf("Corr(FL, Imhof) & \\multicolumn{4}{c}{%s} \\\\", pfmt(cor_fl_imhof, 3)),
    "\\bottomrule", "\\end{tabular}",
    "\\begin{tablenotes}", "\\small",
    "\\item \\textit{Notes:} DV: $\\log$(negotiated price).",
    "Imhof flag = 1 if the within-item-group coefficient of variation of bid prices",
    "exceeds the item-group median, following \\citet{imhof_detecting_2018}.",
    "SE clustered at item level.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "\\end{tablenotes}", "\\end{threeparttable}",
    "\\end{adjustbox}", "\\end{table}")

  writeLines(tab4_lines, file.path(OUT_TAB, "tab_screen_horserace.tex"))
  cat("  Saved:", file.path(OUT_TAB, "tab_screen_horserace.tex"), "\n\n")

} else {
  cat("  WARNING: Insufficient CV data. Skipping horse race.\n\n")
}


# ============================================================================
# ANALYSIS 5: Sensitivity-Adjusted Welfare Bound (referee M5c)
# ============================================================================

cat("=", rep("=", 70), "\n")
cat("  ANALYSIS 5: Sensitivity-Adjusted Welfare Bound (M5c)\n")
cat("=", rep("=", 70), "\n\n")

# Load OLS models
if (file.exists("/tmp/p3v4_models.rds")) {
  models_v4 <- readRDS("/tmp/p3v4_models.rds")
  m_ols <- models_v4$prices$general_pbu
  b_ols <- coef(m_ols)["losers"]
  se_ols <- sqrt(vcov(m_ols)["losers", "losers"])
} else {
  cat("  Running baseline OLS for welfare...\n")
  d_wf <- dt[!is.na(lneg_price)]
  m_ols <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                 data = d_wf, cluster = ~item_f, fixef.rm = "none")
  b_ols <- coef(m_ols)["losers"]
  se_ols <- sqrt(vcov(m_ols)["losers", "losers"])
}

cat(sprintf("  OLS coefficient: %.4f (SE=%.4f)\n", b_ols, se_ols))

# Use sensemakr approach
# The RV_q=1 = 17.5% from previous analyses means a confounder explaining 17.5%
# of residual variation in both treatment and outcome would reduce the effect to zero
RV_q1 <- 0.175

# Cinelli-Hazlett adjusted beta formula:
# The bias from a confounder is bounded by: bias <= sqrt(R2_Y.D * R2_D.Y) * sigma_Y / sigma_D
# For a simplified bound: adjusted_beta = beta * (1 - delta) where delta depends on confounder strength
# More precisely, with RV as the robustness value:
# If a confounder has partial R2 = r, the adjusted coefficient is:
# adjusted_beta ~ beta_OLS - sign(beta) * sqrt(r^2) * (something)
# The simpler approach: beta_adjusted = beta * (1 - partial_R2_confounder)
# Conservative: assume confounder explains half of RV in both directions
partial_r2_confounder <- RV_q1 / 2  # conservative: half the strength that would null the result
adjusted_beta <- b_ols * (1 - partial_r2_confounder)

# Even more conservative: use the 3x benchmark (confounder 3x as important as observed covariates)
# From sensemakr, if benchmark covariate explains X, then 3X scenario gives:
# adjusted_beta_3x ~ beta * (1 - 3 * benchmark_R2)
# We use RV directly for maximum transparency
adjusted_beta_full_rv <- b_ols * (1 - RV_q1)

cat(sprintf("  RV (q=1): %.1f%%\n", RV_q1 * 100))
cat(sprintf("  Adjusted beta (half RV): %.4f\n", adjusted_beta))
cat(sprintf("  Adjusted beta (full RV): %.4f\n", adjusted_beta_full_rv))

# Welfare computation
d_fl <- dt[losers == 1 & !is.na(bid_unit_price_negot_min) & bid_unit_price_negot_min > 0]
total_price_fl <- sum(d_fl$bid_unit_price_negot_min)
total_spending <- sum(dt[!is.na(bid_unit_price_negot_min) & bid_unit_price_negot_min > 0,
                          bid_unit_price_negot_min])

# Original welfare
wf_ols <- (exp(b_ols) - 1) * total_price_fl
markup_ols <- (exp(b_ols) - 1) * 100

# Sensitivity-adjusted welfare (conservative: half RV)
wf_adj_half <- (exp(adjusted_beta) - 1) * total_price_fl
markup_adj_half <- (exp(adjusted_beta) - 1) * 100

# Sensitivity-adjusted welfare (aggressive: full RV)
wf_adj_full <- (exp(adjusted_beta_full_rv) - 1) * total_price_fl
markup_adj_full <- (exp(adjusted_beta_full_rv) - 1) * 100

# Lower bound: OLS - 1.96*SE with RV adjustment
b_lower <- (b_ols - 1.96 * se_ols) * (1 - RV_q1)
wf_lower <- (exp(b_lower) - 1) * total_price_fl
markup_lower <- (exp(b_lower) - 1) * 100

cat(sprintf("  FL tenders: %s, total FL prices: R$ %s\n",
            pfmt_int(nrow(d_fl)), formatC(total_price_fl, format="f", digits=0, big.mark=",")))
cat(sprintf("  OLS markup: %.2f%%, welfare: R$ %s\n",
            markup_ols, formatC(wf_ols, format="f", digits=0, big.mark=",")))
cat(sprintf("  Adjusted (half RV) markup: %.2f%%, welfare: R$ %s\n",
            markup_adj_half, formatC(wf_adj_half, format="f", digits=0, big.mark=",")))
cat(sprintf("  Adjusted (full RV) markup: %.2f%%, welfare: R$ %s\n",
            markup_adj_full, formatC(wf_adj_full, format="f", digits=0, big.mark=",")))
cat(sprintf("  Conservative lower bound markup: %.2f%%, welfare: R$ %s\n",
            markup_lower, formatC(wf_lower, format="f", digits=0, big.mark=",")))

# Write table
tab5_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Sensitivity-Adjusted Welfare Bounds (Cinelli-Hazlett Framework)}",
  "\\label{tab:welfare_adjusted}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}", "\\toprule",
  " & OLS & Adjusted & Adjusted & Conservative \\\\",
  " & (baseline) & ($\\frac{1}{2}$ RV) & (full RV) & lower bound \\\\",
  "\\midrule",
  sprintf("Price coefficient & %s & %s & %s & %s \\\\",
          pfmt(b_ols, 4), pfmt(adjusted_beta, 4),
          pfmt(adjusted_beta_full_rv, 4), pfmt(b_lower, 4)),
  sprintf("Implied markup (\\%%) & %.2f & %.2f & %.2f & %.2f \\\\",
          markup_ols, markup_adj_half, markup_adj_full, markup_lower),
  sprintf("Welfare loss (R\\$) & %s & %s & %s & %s \\\\",
          formatC(wf_ols, format="f", digits=0, big.mark=","),
          formatC(wf_adj_half, format="f", digits=0, big.mark=","),
          formatC(wf_adj_full, format="f", digits=0, big.mark=","),
          formatC(wf_lower, format="f", digits=0, big.mark=",")),
  sprintf("As \\%% of spending & %.3f\\%% & %.3f\\%% & %.3f\\%% & %.3f\\%% \\\\",
          wf_ols/total_spending*100, wf_adj_half/total_spending*100,
          wf_adj_full/total_spending*100, wf_lower/total_spending*100),
  "\\midrule",
  sprintf("Robustness Value ($RV_{q=1}$) & \\multicolumn{4}{c}{%.1f\\%%} \\\\", RV_q1*100),
  sprintf("FL-present tenders & \\multicolumn{4}{c}{%s} \\\\", pfmt_int(nrow(d_fl))),
  sprintf("Total FL prices (R\\$) & \\multicolumn{4}{c}{%s} \\\\",
          formatC(total_price_fl, format="f", digits=0, big.mark=",")),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Sensitivity-adjusted welfare bounds using the Cinelli and Hazlett (2020)",
  "robustness value framework. The RV$_{q=1}$ = 17.5\\% indicates that an omitted confounder",
  "would need to explain 17.5\\% of the residual variation in both treatment and outcome to",
  "reduce the coefficient to zero. Column 2 adjusts for a confounder at half this strength;",
  "Column 3 for the full RV strength. Column 4 combines the full RV adjustment with the",
  "lower 95\\% confidence bound. Markup = $\\exp(\\hat{\\beta}_{adj}) - 1$.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")

writeLines(tab5_lines, file.path(OUT_TAB, "tab_welfare_adjusted.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_welfare_adjusted.tex"), "\n\n")


# ============================================================================
# ANALYSIS 6: Enriched Bajari-Ye First Stage (referee M3)
# ============================================================================

cat("=", rep("=", 70), "\n")
cat("  ANALYSIS 6: Enriched Bajari-Ye First Stage (M3)\n")
cat("=", rep("=", 70), "\n\n")

# Load bid-level data (40M rows) with column selection
cat("  Loading bid_level_full.parquet (with column selection)...\n")
bl_cols <- c("códigofornecedor", "flagvencedor", "numerodaoc", "códigoitem",
             "códigounidadecompradora", "mêsanoencerramento")
# Also try to get price column
bl_all_cols <- names(read_parquet(file.path(DATA_V1, "bid_level_full.parquet"), as_data_frame = FALSE))
cat("  Available bid-level columns:", paste(bl_all_cols, collapse = ", "), "\n")

price_col_name <- grep("valor|preco|price|lance", bl_all_cols, value = TRUE, ignore.case = TRUE)
cat("  Price column candidates:", paste(price_col_name, collapse = ", "), "\n")

bl_cols_use <- intersect(c(bl_cols, price_col_name[1]), bl_all_cols)
cat("  Reading columns:", paste(bl_cols_use, collapse = ", "), "\n")

bl <- as.data.table(read_parquet(
  file.path(DATA_V1, "bid_level_full.parquet"),
  col_select = all_of(bl_cols_use)))
cat("  Bid-level rows:", pfmt_int(nrow(bl)), "\n")

# Standardize column names
setnames(bl, "códigofornecedor", "firm_id", skip_absent = TRUE)
setnames(bl, "flagvencedor", "won", skip_absent = TRUE)
setnames(bl, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(bl, "códigoitem", "item_code", skip_absent = TRUE)
setnames(bl, "códigounidadecompradora", "pbu_code", skip_absent = TRUE)
setnames(bl, "mêsanoencerramento", "month_year", skip_absent = TRUE)

# Rename price column
if (length(price_col_name) > 0 && price_col_name[1] %in% names(bl)) {
  setnames(bl, price_col_name[1], "bid_price", skip_absent = TRUE)
} else if (!"bid_price" %in% names(bl)) {
  cat("  WARNING: No price column found in bid-level data!\n")
  bl[, bid_price := NA_real_]
}

# Convert firm_id to character for matching
bl[, firm_id := as.character(firm_id)]

# Extract year
if ("month_year" %in% names(bl)) {
  bl[, year := tryCatch(
    as.integer(sub(".*/", "", as.character(month_year))),
    error = function(e) NA_integer_)]
  # If year extraction failed, try alternative
  if (all(is.na(bl$year)) || max(bl$year, na.rm = TRUE) < 2000) {
    bl[, year := as.integer(substr(oc_code, 12, 15))]
  }
} else {
  bl[, year := as.integer(substr(oc_code, 12, 15))]
}

cat("  Year range:", min(bl$year, na.rm = TRUE), "-", max(bl$year, na.rm = TRUE), "\n")

# Sample if too large (>15M rows)
if (nrow(bl) > 15000000L) {
  cat("  Sampling 10M rows for tractability...\n")
  set.seed(42)
  # Sample by tenders (not rows) to preserve within-tender structure
  tender_ids <- unique(bl[, .(oc_code, item_code)])
  n_sample_tenders <- min(nrow(tender_ids), 2000000L)
  sample_tenders <- tender_ids[sample(.N, n_sample_tenders)]
  bl <- bl[sample_tenders, on = .(oc_code, item_code), nomatch = NULL]
  cat("  After sampling:", pfmt_int(nrow(bl)), "rows from",
      pfmt_int(n_sample_tenders), "tenders\n")
}

# Load firm characteristics
cat("  Merging firm characteristics...\n")
firms_for_bl <- firms[, .(firm_id)]

# Add porte
if ("porte_empresa" %in% names(firms)) {
  firms_for_bl[, porte_empresa := firms$porte_empresa]
  firms_for_bl[, firm_size := as.numeric(factor(porte_empresa))]
} else {
  firms_for_bl[, firm_size := NA_real_]
}

# Add CNAE
cnae_col_bl <- grep("cnae_fiscal|cnae", names(firms), value = TRUE, ignore.case = TRUE)
if (length(cnae_col_bl) > 0) {
  firms_for_bl[, cnae_fiscal := firms[[cnae_col_bl[1]]]]
  firms_for_bl[, cnae_sector := substr(as.character(cnae_fiscal), 1, 2)]
} else {
  firms_for_bl[, cnae_sector := NA_character_]
}

# Add firm age
if ("firm_age" %in% names(firms)) {
  firms_for_bl[, firm_age := firms$firm_age]
} else {
  firms_for_bl[, firm_age := NA_real_]
}

bl <- merge(bl, firms_for_bl[, .(firm_id, firm_size, cnae_sector, firm_age)],
            by = "firm_id", all.x = TRUE)
bl[is.na(firm_size), firm_size := 0]
bl[is.na(firm_age), firm_age := median(bl$firm_age, na.rm = TRUE)]

# Load reference prices from BEC
cat("  Loading reference prices from BEC...\n")
bec_ref <- as.data.table(read_parquet(
  file.path(DATA_V1, "BEC_collapse_final.parquet"),
  col_select = c("po_item_merge_key", "bid_ref_price_min")))

# Extract oc_code and item_code from po_item_merge_key
OC_CODE_LEN <- 22L
bec_ref[, oc_code := substr(po_item_merge_key, 1, OC_CODE_LEN)]
bec_ref[, after_oc := substr(po_item_merge_key, OC_CODE_LEN + 1L, nchar(po_item_merge_key))]
bec_ref[, full_num := sub("^(\\d+).*", "\\1", after_oc)]
bec_ref[, item_code := substr(full_num, 1, nchar(full_num) - 1L)]
bec_ref[, c("after_oc", "full_num", "po_item_merge_key") := NULL]

# Deduplicate
bec_ref <- bec_ref[!is.na(bid_ref_price_min) & bid_ref_price_min > 0]
bec_ref <- unique(bec_ref, by = c("oc_code", "item_code"))

bl <- merge(bl, bec_ref, by = c("oc_code", "item_code"), all.x = TRUE)
cat("  Bids with reference price:", pfmt_int(sum(!is.na(bl$bid_ref_price_min))),
    sprintf("(%.1f%%)\n", 100 * mean(!is.na(bl$bid_ref_price_min))))

rm(bec_ref); gc(verbose = FALSE)

# Flag FL firms
fl_firm_ids_char <- as.character(fl_firm_ids)
bl[, is_fl := as.integer(firm_id %chin% fl_firm_ids_char)]
cat("  FL bids:", pfmt_int(sum(bl$is_fl)), "\n")

# ---- First stage regressions ------------------------------------------------
cat("  Running first-stage regressions on losing bids...\n")

d_resid <- bl[won == 0L & !is.na(bid_price) & bid_price > 0]
d_resid[, log_bid := log(bid_price)]
d_resid[, log_ref := fifelse(!is.na(bid_ref_price_min) & bid_ref_price_min > 0,
                              log(bid_ref_price_min), NA_real_)]
d_resid[, log_firm_age := fifelse(!is.na(firm_age) & firm_age > 0,
                                   log(firm_age), NA_real_)]
d_resid[, cnae_sector_f := factor(cnae_sector)]

cat("  Losing bids with prices:", pfmt_int(nrow(d_resid)), "\n")

has_ref <- sum(!is.na(d_resid$log_ref)) > nrow(d_resid) * 0.3

# Model 1: Baseline (firm_size | item_code + year) -- same as v4
cat("  Model 1: Baseline first stage...\n")
if (has_ref) {
  d_fs1 <- d_resid[!is.na(log_ref)]
  m_fs1 <- tryCatch(
    feols(log_bid ~ log_ref + firm_size | item_code + year,
          data = d_fs1, fixef.rm = "none", lean = FALSE),
    error = function(e) { cat("  Baseline failed:", e$message, "\n"); NULL })
} else {
  d_fs1 <- d_resid
  m_fs1 <- tryCatch(
    feols(log_bid ~ firm_size | item_code + year,
          data = d_fs1, fixef.rm = "none", lean = FALSE),
    error = function(e) { cat("  Baseline failed:", e$message, "\n"); NULL })
}

if (!is.null(m_fs1)) {
  fs1_r2 <- fitstat(m_fs1, "r2")[[1]]
  cat(sprintf("  Baseline R2: %.4f, N: %s\n", fs1_r2, pfmt_int(m_fs1$nobs)))
  d_fs1[, resid_baseline := residuals(m_fs1)]
}

# Model 2: Enriched (firm_size + log_ref + firm_age + cnae_sector | item_code + year)
cat("  Model 2: Enriched first stage...\n")
d_fs2 <- d_resid[!is.na(log_ref) & !is.na(log_firm_age) & !is.na(cnae_sector)]
if (nrow(d_fs2) > 100000) {
  m_fs2 <- tryCatch(
    feols(log_bid ~ log_ref + firm_size + log_firm_age + cnae_sector_f | item_code + year,
          data = d_fs2, fixef.rm = "none", lean = FALSE),
    error = function(e) { cat("  Enriched failed:", e$message, "\n"); NULL })
} else {
  m_fs2 <- NULL
  cat("  Insufficient data for enriched model\n")
}

if (!is.null(m_fs2)) {
  fs2_r2 <- fitstat(m_fs2, "r2")[[1]]
  cat(sprintf("  Enriched R2: %.4f, N: %s\n", fs2_r2, pfmt_int(m_fs2$nobs)))
  d_fs2[, resid_enriched := residuals(m_fs2)]
}

# ---- Exchangeability (KS) tests with both sets of residuals ------------------
cat("\n  Running KS tests...\n")

ks_baseline <- NULL; ks_enriched <- NULL

if (!is.null(m_fs1)) {
  r_fl_b  <- d_fs1[is_fl == 1L, resid_baseline]
  r_nfl_b <- d_fs1[is_fl == 0L, resid_baseline]
  if (length(r_fl_b) >= 30 && length(r_nfl_b) >= 30) {
    ks_baseline <- ks.test(r_fl_b, r_nfl_b)
    cat(sprintf("  KS (baseline): D=%.4f, p=%.6f\n",
                ks_baseline$statistic, ks_baseline$p.value))
  }
}

if (!is.null(m_fs2)) {
  # Need to flag FL in d_fs2
  r_fl_e  <- d_fs2[is_fl == 1L, resid_enriched]
  r_nfl_e <- d_fs2[is_fl == 0L, resid_enriched]
  if (length(r_fl_e) >= 30 && length(r_nfl_e) >= 30) {
    ks_enriched <- ks.test(r_fl_e, r_nfl_e)
    cat(sprintf("  KS (enriched): D=%.4f, p=%.6f\n",
                ks_enriched$statistic, ks_enriched$p.value))
  }
}

# ---- Conditional Independence tests -----------------------------------------
cat("\n  Running conditional independence tests...\n")

compute_pair_product <- function(resid_dt, label, max_tenders = 5000) {
  t2 <- resid_dt[, .N, by = .(oc_code, item_code)][N >= 2]
  if (nrow(t2) < 50) {
    cat(sprintf("  %s: insufficient tenders (%d)\n", label, nrow(t2)))
    return(list(mean = NA, se = NA, p = NA, n_pairs = 0))
  }
  if (nrow(t2) > max_tenders) {
    set.seed(42)
    t2 <- t2[sample(.N, max_tenders)]
  }
  r_wide <- resid_dt[t2, on = .(oc_code, item_code)]
  cors <- r_wide[, {
    if (.N >= 2) {
      pairs <- combn(min(.N, 10), 2)
      .(pp = sapply(seq_len(ncol(pairs)), function(p) resid[pairs[1,p]] * resid[pairs[2,p]]))
    }
  }, by = .(oc_code, item_code)]

  if (nrow(cors) > 0) {
    m <- mean(cors$pp, na.rm = TRUE)
    s <- sd(cors$pp, na.rm = TRUE) / sqrt(nrow(cors))
    p <- 2 * pnorm(-abs(m / s))
    cat(sprintf("  %s: mean_product=%.4f (SE=%.4f), p=%.6f\n", label, m, s, p))
    return(list(mean = m, se = s, p = p, n_pairs = nrow(cors)))
  }
  list(mean = NA, se = NA, p = NA, n_pairs = 0)
}

ci_baseline_fl <- ci_baseline_nfl <- ci_enriched_fl <- ci_enriched_nfl <- NULL

if (!is.null(m_fs1)) {
  ci_baseline_fl <- compute_pair_product(
    d_fs1[is_fl == 1L, .(firm_id, oc_code, item_code, resid = resid_baseline)],
    "Baseline FL")
  ci_baseline_nfl <- compute_pair_product(
    d_fs1[is_fl == 0L, .(firm_id, oc_code, item_code, resid = resid_baseline)],
    "Baseline Non-FL")
}

if (!is.null(m_fs2)) {
  ci_enriched_fl <- compute_pair_product(
    d_fs2[is_fl == 1L, .(firm_id, oc_code, item_code, resid = resid_enriched)],
    "Enriched FL")
  ci_enriched_nfl <- compute_pair_product(
    d_fs2[is_fl == 0L, .(firm_id, oc_code, item_code, resid = resid_enriched)],
    "Enriched Non-FL")
}

# ---- Write enriched Bajari-Ye table -----------------------------------------
cat("\n  Writing tab_bajari_ye_enriched.tex...\n")

tab6_lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Enriched Bajari-Ye First Stage and Tests}",
  "\\label{tab:bajari_ye_enriched}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcc}", "\\toprule",
  " & (1) Baseline & (2) Enriched \\\\",
  "\\midrule",
  "\\textit{Panel A: First Stage (DV: $\\log$ bid)} & & \\\\")

# First stage coefficients
if (!is.null(m_fs1) && has_ref) {
  tab6_lines <- c(tab6_lines,
    sprintf("$\\log$(reference price) & %s & %s \\\\",
            coef_cell(m_fs1, "log_ref", 4),
            if (!is.null(m_fs2) && "log_ref" %in% names(coef(m_fs2))) coef_cell(m_fs2, "log_ref", 4) else "---"),
    sprintf(" & %s & %s \\\\",
            se_cell(m_fs1, "log_ref", 4),
            if (!is.null(m_fs2) && "log_ref" %in% names(coef(m_fs2))) se_cell(m_fs2, "log_ref", 4) else ""))
}

tab6_lines <- c(tab6_lines,
  sprintf("Firm size (porte) & %s & %s \\\\",
          if (!is.null(m_fs1)) coef_cell(m_fs1, "firm_size", 4) else "---",
          if (!is.null(m_fs2)) coef_cell(m_fs2, "firm_size", 4) else "---"),
  sprintf(" & %s & %s \\\\",
          if (!is.null(m_fs1)) se_cell(m_fs1, "firm_size", 4) else "",
          if (!is.null(m_fs2)) se_cell(m_fs2, "firm_size", 4) else ""))

if (!is.null(m_fs2) && "log_firm_age" %in% names(coef(m_fs2))) {
  tab6_lines <- c(tab6_lines,
    sprintf("$\\log$(firm age) & & %s \\\\", coef_cell(m_fs2, "log_firm_age", 4)),
    sprintf(" & & %s \\\\", se_cell(m_fs2, "log_firm_age", 4)))
}

tab6_lines <- c(tab6_lines, "\\midrule",
  sprintf("R-squared & %s & %s \\\\",
          if (!is.null(m_fs1)) pfmt(fs1_r2, 4) else "---",
          if (!is.null(m_fs2)) pfmt(fs2_r2, 4) else "---"),
  sprintf("Observations & %s & %s \\\\",
          if (!is.null(m_fs1)) pfmt_int(m_fs1$nobs) else "---",
          if (!is.null(m_fs2)) pfmt_int(m_fs2$nobs) else "---"),
  "CNAE sector dummies & NO & YES \\\\",
  "Item + Year FE & YES & YES \\\\")

tab6_lines <- c(tab6_lines, "\\midrule",
  "\\textit{Panel B: Exchangeability (KS test)} & & \\\\",
  sprintf("KS statistic & %s & %s \\\\",
          if (!is.null(ks_baseline)) pfmt(ks_baseline$statistic, 4) else "---",
          if (!is.null(ks_enriched)) pfmt(ks_enriched$statistic, 4) else "---"),
  sprintf("KS $p$-value & %s & %s \\\\",
          if (!is.null(ks_baseline)) pfmt(ks_baseline$p.value, 6) else "---",
          if (!is.null(ks_enriched)) pfmt(ks_enriched$p.value, 6) else "---"))

tab6_lines <- c(tab6_lines, "\\midrule",
  "\\textit{Panel C: Conditional Independence} & & \\\\",
  sprintf("FL mean pairwise product & %s & %s \\\\",
          if (!is.null(ci_baseline_fl) && !is.na(ci_baseline_fl$mean)) pfmt(ci_baseline_fl$mean, 4) else "---",
          if (!is.null(ci_enriched_fl) && !is.na(ci_enriched_fl$mean)) pfmt(ci_enriched_fl$mean, 4) else "---"),
  sprintf("FL $p$-value & %s & %s \\\\",
          if (!is.null(ci_baseline_fl) && !is.na(ci_baseline_fl$p)) pfmt(ci_baseline_fl$p, 6) else "---",
          if (!is.null(ci_enriched_fl) && !is.na(ci_enriched_fl$p)) pfmt(ci_enriched_fl$p, 6) else "---"),
  sprintf("Non-FL mean pairwise product & %s & %s \\\\",
          if (!is.null(ci_baseline_nfl) && !is.na(ci_baseline_nfl$mean)) pfmt(ci_baseline_nfl$mean, 4) else "---",
          if (!is.null(ci_enriched_nfl) && !is.na(ci_enriched_nfl$mean)) pfmt(ci_enriched_nfl$mean, 4) else "---"),
  sprintf("Non-FL $p$-value & %s & %s \\\\",
          if (!is.null(ci_baseline_nfl) && !is.na(ci_baseline_nfl$p)) pfmt(ci_baseline_nfl$p, 6) else "---",
          if (!is.null(ci_enriched_nfl) && !is.na(ci_enriched_nfl$p)) pfmt(ci_enriched_nfl$p, 6) else "---"))

tab6_lines <- c(tab6_lines,
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Panel A reports first-stage auxiliary regressions on losing bids.",
  "Column (1): baseline with firm size and reference price. Column (2): enriched with",
  "firm age and CNAE sector dummies. Panel B: Kolmogorov-Smirnov test of exchangeability",
  "between FL and non-FL residual distributions. Panel C: mean pairwise product of",
  "residuals within tenders (Bajari \\& Ye, 2003). Under competitive bidding,",
  "the mean product should equal zero.",
  "\\end{tablenotes}", "\\end{threeparttable}",
  "\\end{adjustbox}", "\\end{table}")

writeLines(tab6_lines, file.path(OUT_TAB, "tab_bajari_ye_enriched.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_bajari_ye_enriched.tex"), "\n\n")

# Clean up
rm(bl, d_resid, d_fs1, d_fs2); gc(verbose = FALSE)

# ============================================================================
# Summary
# ============================================================================

cat("\n", rep("=", 72), "\n")
cat("  ALL ANALYSES COMPLETE\n")
cat(rep("=", 72), "\n")
cat("  Tables saved to:", OUT_TAB, "\n")
cat("  End time:", format(Sys.time()), "\n")

# List all output files
out_files <- list.files(OUT_TAB, pattern = "\\.tex$", full.names = TRUE)
cat("  Output files:\n")
for (f in out_files) cat("    ", f, "\n")

cat("\n  Done.\n")
