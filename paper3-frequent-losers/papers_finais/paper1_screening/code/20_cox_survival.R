# ============================================================================
# 20_cox_survival.R — Cox Proportional Hazard Model
# Paper 3 v4: Frequent Losers in Public Procurement
# ============================================================================
# Models firm exit from BEC as a function of FL exposure. Tests whether
# genuine firms operating in FL-heavy markets exit faster, consistent
# with competitive displacement or cartel capture.
#
# Caveat: "exit" = last observed participation in BEC, not firm death.
# ============================================================================

cat("=== 20_cox_survival.R: Cox survival model ===\n")

if (!exists(".v4_dir")) .v4_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
source(file.path(.v4_dir, "code", "00_setup.R"), local = TRUE)

suppressPackageStartupMessages(library(survival))

# ---- Load data ---------------------------------------------------------------
cat("  Loading data...\n")

ftm_file <- file.path(DATA_V1, "firm_tender_map.parquet")
if (!file.exists(ftm_file)) stop("firm_tender_map.parquet not found")
ftm <- as.data.table(read_parquet(ftm_file))

ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

# Extract year from oc_code (chars 12-15)
ftm[, year := as.integer(substr(oc_code, 12, 15))]
ftm <- ftm[year >= 2009 & year <= 2019]

# FL identification
fp <- readRDS(DATA_CACHE_FP)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")

q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val
fl_ids <- unique(fp[tenders_count > threshold, firm_id])

# Analysis dataset for FL flags per tender
dt <- readRDS(DATA_CACHE_V4)

# ============================================================================
# Phase 1: Construct firm-level survival panel
# ============================================================================

cat("  Phase 1: Building firm survival panel...\n")

# Exclude FL firms themselves — we study genuine firms' survival
non_fl_ftm <- ftm[!(firm_id %chin% fl_ids)]

# Firm entry/exit
firm_panel <- non_fl_ftm[, .(
  entry_year = min(year),
  last_year  = max(year),
  n_tenders  = .N,
  n_wins     = sum(won, na.rm = TRUE)
), by = firm_id]

# Exit: firm disappears before 2019 (last_year < 2018 to allow 1-year gap)
firm_panel[, exit_year := last_year + 1L]
firm_panel[, event := as.integer(last_year < 2018L)]  # censored if active in 2018+
firm_panel[, duration := exit_year - entry_year]
firm_panel <- firm_panel[duration > 0]  # drop zero-duration

# Win rate
firm_panel[, win_rate := n_wins / n_tenders]
firm_panel[, log_tenders := log(n_tenders + 1)]

cat(sprintf("  Firms: %s (events: %s, censored: %s)\n",
            pfmt_int(nrow(firm_panel)),
            pfmt_int(sum(firm_panel$event)),
            pfmt_int(sum(1 - firm_panel$event))))

# ============================================================================
# Phase 2: Compute FL exposure per firm
# ============================================================================

cat("  Phase 2: Computing FL exposure...\n")

# For each tender (oc_code × item_code), flag if FL present
fl_tenders <- unique(ftm[firm_id %chin% fl_ids, .(oc_code, item_code)])
fl_tenders[, fl_present := 1L]

# Merge with non-FL firms' tenders
non_fl_with_fl <- merge(
  non_fl_ftm[, .(firm_id, oc_code, item_code)],
  fl_tenders, by = c("oc_code", "item_code"), all.x = TRUE
)
non_fl_with_fl[is.na(fl_present), fl_present := 0L]

# FL exposure: fraction of firm's tenders with FL presence
fl_exposure <- non_fl_with_fl[, .(
  fl_exposure = mean(fl_present),
  n_fl_tenders = sum(fl_present),
  n_total_tenders = .N
), by = firm_id]

firm_panel <- merge(firm_panel, fl_exposure[, .(firm_id, fl_exposure)],
                     by = "firm_id", all.x = TRUE)
firm_panel[is.na(fl_exposure), fl_exposure := 0]

# FL exposure terciles for KM plot
firm_panel[, fl_tercile := cut(fl_exposure,
  breaks = c(-0.01, 0, quantile(fl_exposure[fl_exposure > 0], c(0.5, 1))),
  labels = c("No FL exposure", "Low FL", "High FL"),
  include.lowest = TRUE)]

cat(sprintf("  FL exposure: mean=%.4f, median=%.4f, max=%.4f\n",
            mean(firm_panel$fl_exposure), median(firm_panel$fl_exposure),
            max(firm_panel$fl_exposure)))
cat("  FL tercile distribution:\n")
print(firm_panel[, .N, by = fl_tercile])

# ============================================================================
# Phase 3: Cox Proportional Hazard Model
# ============================================================================

cat("  Phase 3: Cox PH model...\n")

# Model 1: FL exposure only
cox1 <- coxph(Surv(duration, event) ~ fl_exposure,
              data = firm_panel)
cat("  Model 1 (FL exposure only):\n")
print(summary(cox1)$coefficients)

# Model 2: FL exposure + controls
cox2 <- coxph(Surv(duration, event) ~ fl_exposure + log_tenders + win_rate,
              data = firm_panel)
cat("  Model 2 (+ log_tenders, win_rate):\n")
print(summary(cox2)$coefficients)

# Model 3: With entry_year strata (controls for cohort effects)
firm_panel[, entry_cohort := cut(entry_year, breaks = c(2008, 2011, 2014, 2020),
                                  labels = c("2009-2011", "2012-2014", "2015-2019"))]
cox3 <- coxph(Surv(duration, event) ~ fl_exposure + log_tenders + win_rate +
                strata(entry_cohort),
              data = firm_panel)
cat("  Model 3 (+ strata(entry_cohort)):\n")
print(summary(cox3)$coefficients)

# Schoenfeld test for PH assumption
cat("  Schoenfeld test (PH assumption):\n")
ph_test <- cox.zph(cox2)
print(ph_test)

# ============================================================================
# Phase 4: Kaplan-Meier by FL exposure tercile
# ============================================================================

cat("  Phase 4: Kaplan-Meier curves...\n")

km_fit <- survfit(Surv(duration, event) ~ fl_tercile, data = firm_panel)

# Build KM data for ggplot
km_data <- data.table()
for (s in seq_along(km_fit$strata)) {
  strata_name <- names(km_fit$strata)[s]
  idx_start <- if (s == 1) 1 else sum(km_fit$strata[1:(s-1)]) + 1
  idx_end <- sum(km_fit$strata[1:s])
  idx <- idx_start:idx_end

  km_data <- rbind(km_data, data.table(
    time = km_fit$time[idx],
    surv = km_fit$surv[idx],
    lower = km_fit$lower[idx],
    upper = km_fit$upper[idx],
    group = sub("fl_tercile=", "", strata_name)
  ))
}

p_km <- ggplot(km_data, aes(x = time, y = surv, color = group, fill = group)) +
  geom_step(linewidth = 0.7) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.15, linetype = 0) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  scale_x_continuous(breaks = 1:11) +
  scale_color_manual(values = c("No FL exposure" = "gray50",
                                 "Low FL" = "steelblue",
                                 "High FL" = "firebrick")) +
  scale_fill_manual(values = c("No FL exposure" = "gray50",
                                "Low FL" = "steelblue",
                                "High FL" = "firebrick")) +
  labs(x = "Years since entry", y = "Survival probability") +
  theme_pub()

save_pub(p_km, "fig_km_fl_exposure.pdf")

# ============================================================================
# Phase 5: Write tab_cox_survival.tex
# ============================================================================

cat("  Phase 5: Writing tab_cox_survival.tex...\n")

extract_cox <- function(m, var) {
  s <- summary(m)$coefficients
  if (var %in% rownames(s)) {
    b <- s[var, "coef"]
    se <- s[var, "se(coef)"]
    p <- s[var, "Pr(>|z|)"]
    hr <- exp(b)
    list(coef = b, se = se, pval = p, hr = hr)
  } else {
    list(coef = NA, se = NA, pval = NA, hr = NA)
  }
}

c1 <- extract_cox(cox1, "fl_exposure")
c2 <- extract_cox(cox2, "fl_exposure")
c3 <- extract_cox(cox3, "fl_exposure")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Cox Proportional Hazard: Firm Exit and FL Exposure}",
  "\\label{tab:cox_survival}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}", "\\toprule",
  " & (1) & (2) & (3) \\\\", "\\midrule"
)

# FL exposure coefficient
vals <- sapply(list(c1, c2, c3), function(x) {
  if (is.na(x$coef)) "---"
  else paste0(pfmt(x$coef, 4), pstars(x$pval))
})
lines <- c(lines, sprintf("FL exposure & %s \\\\", paste(vals, collapse = " & ")))

# SE
vals <- sapply(list(c1, c2, c3), function(x) {
  if (is.na(x$se)) "" else sprintf("(%s)", pfmt(x$se, 4))
})
lines <- c(lines, sprintf(" & %s \\\\", paste(vals, collapse = " & ")))

# Hazard ratio
vals <- sapply(list(c1, c2, c3), function(x) {
  if (is.na(x$hr)) "---" else sprintf("[HR: %s]", pfmt(x$hr, 3))
})
lines <- c(lines, sprintf(" & %s \\\\", paste(vals, collapse = " & ")))

lines <- c(lines, "\\midrule",
  sprintf("Log tenders & & %s%s & %s%s \\\\",
    pfmt(extract_cox(cox2, "log_tenders")$coef, 4),
    pstars(extract_cox(cox2, "log_tenders")$pval),
    pfmt(extract_cox(cox3, "log_tenders")$coef, 4),
    pstars(extract_cox(cox3, "log_tenders")$pval)),
  sprintf("Win rate & & %s%s & %s%s \\\\",
    pfmt(extract_cox(cox2, "win_rate")$coef, 4),
    pstars(extract_cox(cox2, "win_rate")$pval),
    pfmt(extract_cox(cox3, "win_rate")$coef, 4),
    pstars(extract_cox(cox3, "win_rate")$pval)))

lines <- c(lines, "\\midrule",
  "Entry cohort strata & NO & NO & YES \\\\",
  sprintf("Firms & \\multicolumn{3}{c}{%s} \\\\", pfmt_int(nrow(firm_panel))),
  sprintf("Events (exits) & \\multicolumn{3}{c}{%s} \\\\", pfmt_int(sum(firm_panel$event))),
  sprintf("Censored & \\multicolumn{3}{c}{%s} \\\\", pfmt_int(sum(1 - firm_panel$event))),
  sprintf("PH test ($p$) & %s & %s & %s \\\\",
    pfmt(cox.zph(cox1)$table["GLOBAL", "p"], 3),
    pfmt(ph_test$table["GLOBAL", "p"], 3),
    pfmt(cox.zph(cox3)$table["GLOBAL", "p"], 3)))

lines <- c(lines,
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Cox proportional hazard model. Dependent variable:",
  "time from first to last BEC participation (years). Event = firm absent from",
  "BEC for $\\geq$2 consecutive years before 2019; firms active in 2018--2019 are",
  "right-censored. FL exposure = fraction of a firm's tenders with $\\geq$1 FL",
  "participant. HR $>$ 1 indicates higher exit hazard. PH test: Schoenfeld",
  "residuals global $p$-value.",
  "``Exit'' denotes cessation of BEC participation, not necessarily firm closure.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")

writeLines(lines, file.path(OUT_TAB, "tab_cox_survival.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_cox_survival.tex"), "\n")

# ============================================================================
# Save
# ============================================================================

cox_results <- list(
  models = list(cox1 = cox1, cox2 = cox2, cox3 = cox3),
  ph_test = ph_test,
  km_fit = km_fit,
  firm_panel_summary = list(
    n_firms = nrow(firm_panel),
    n_events = sum(firm_panel$event),
    n_censored = sum(1 - firm_panel$event),
    mean_fl_exposure = mean(firm_panel$fl_exposure),
    median_duration = median(firm_panel$duration)
  )
)

saveRDS(cox_results, COX_CACHE_V4)
cat("  Results saved:", COX_CACHE_V4, "\n")
cat("  Done.\n")
