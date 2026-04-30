# ============================================================================
# 23_mde_calculations.R — Minimum Detectable Effect for null tests
# Paper 3 v14: addresses Fragility 5 (RDD/DiD nulls may be underpowered)
#
# For each null test in v14, compute the MDE at:
#   - α = 0.05 (two-sided)
#   - power = 0.80
# Compare to typical effect sizes in the cartel/procurement literature
# (e.g., 5-10% price markup, ~0.10-0.15 log price coefficient).
#
# Tests covered:
#   T1.A — RDD R$80k cap pre-Decreto, FL prevalence
#   T1.B — RDD R$176k cap post-Decreto, FL prevalence
#   T1.C — RDD R$80k cap pre-Decreto, first-stage convite share
#   T1.D — RDD R$176k cap post-Decreto, first-stage convite share
#   T2.A — DiD Decreto 9.412/2018, FL prevalence (treated × post)
#   T2.B — DiD Decreto 9.412/2018, log(price)
#   T2.C — DiD Decreto 9.412/2018, n_firms
#
# Method: SE from rdrobust/feols × MDE multiplier 2.80 (= 1.96 + 0.84) for
# two-sided test with 80% power. MDE = SE × 2.80.
#
# Output: csv table with each test's coefficient, SE, t-stat, p, and MDE.
# ============================================================================

cat("=== 23_mde_calculations.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
  if (!requireNamespace("rdrobust", quietly = TRUE)) {
    install.packages("rdrobust", repos = "https://cran.r-project.org")
  }
  library(rdrobust)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "mde_calculations")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data -----------------------------------------------------------
iv <- as.data.table(read_parquet(file.path(BASE, "data/processed/item_value_panel.parquet")))
d <- iv[modality %in% c(1L, 3L) & item_value > 0 & is.finite(item_value)]

# ---- MDE for RDD tests ----------------------------------------------------
mde_rdd <- function(d_sub, cap, dv, label) {
  d_sub[, running := log(item_value) - log(cap)]
  m <- tryCatch(
    rdrobust(y = d_sub[[dv]], x = d_sub$running, c = 0,
             kernel = "triangular", bwselect = "mserd"),
    error = function(e) { cat("  rdd error:", conditionMessage(e), "\n"); NULL })
  if (is.null(m)) return(NULL)
  list(label  = label,
       coef   = m$coef[1], se = m$se[1], pval = m$pv[1],
       mde_80 = 2.80 * m$se[1],
       mde_50 = 1.96 * m$se[1],
       n      = m$N_h[1] + m$N_h[2])
}

cat("\n--- RDD MDE (80% power, α=0.05) ---\n")
rdd_results <- list()
rdd_results[[1]] <- mde_rdd(copy(d[year <= 2017L]), 80000,  "has_fl",
                             "RDD R$80k pre-Decreto, FL prevalence")
rdd_results[[2]] <- mde_rdd(copy(d[year >= 2018L]), 176000, "has_fl",
                             "RDD R$176k post-Decreto, FL prevalence")
d_conv <- copy(d); d_conv[, conv := as.integer(modality == 1L)]
rdd_results[[3]] <- mde_rdd(d_conv[year <= 2017L], 80000,  "conv",
                             "RDD R$80k pre-Decreto, convite share (1st-stage)")
rdd_results[[4]] <- mde_rdd(d_conv[year >= 2018L], 176000, "conv",
                             "RDD R$176k post-Decreto, convite share (1st-stage)")

for (r in rdd_results) {
  if (is.null(r)) next
  cat(sprintf("  %s\n", r$label))
  cat(sprintf("    coef=%+.4f, SE=%.4f, p=%.3g, n=%d\n",
              r$coef, r$se, r$pval, r$n))
  cat(sprintf("    MDE (80%% power): ±%.4f\n", r$mde_80))
  cat(sprintf("    MDE (50%% power): ±%.4f\n", r$mde_50))
}

rdd_dt <- rbindlist(lapply(rdd_results, function(r) {
  if (is.null(r)) return(NULL)
  data.table(test = r$label, coef = r$coef, se = r$se, pval = r$pval,
             mde_80 = r$mde_80, mde_50 = r$mde_50, n = r$n)
}))

# ---- MDE for DiD tests ----------------------------------------------------
cat("\n--- DiD MDE (Decreto 9.412/2018) ---\n")

CAP_OLD  <- 80000
CAP_NEW  <- 176000
d[, treated := as.integer(item_value >= CAP_OLD & item_value < CAP_NEW)]
d[, post    := as.integer(year >= 2018)]
d_did <- d[(item_value >= 40000 & item_value < CAP_OLD) |
           (item_value >= CAP_OLD & item_value < CAP_NEW) |
           (item_value >= CAP_NEW & item_value <= 300000)]
d_did[, item_f := factor(codigoitem)]
d_did[, year_f := factor(year)]
d_did[, pbu_f  := factor(pbu_code)]
d_did[, log_value := log(item_value)]
d_did[, convite   := as.integer(modality == 1L)]

did_specs <- list(
  list(formula = has_fl ~ treated * post | year_f + pbu_f,
       label   = "DiD Decreto, FL prevalence"),
  list(formula = log_value ~ treated * post | year_f + pbu_f,
       label   = "DiD Decreto, log(value) — placebo"),
  list(formula = n_firms ~ treated * post | year_f + pbu_f,
       label   = "DiD Decreto, n_firms"),
  list(formula = convite ~ treated * post | year_f + pbu_f,
       label   = "DiD Decreto, convite share (1st-stage)")
)

did_dt <- data.table()
for (sp in did_specs) {
  m <- tryCatch(feols(sp$formula, data = d_did, cluster = ~item_f),
                error = function(e) NULL)
  if (is.null(m)) next
  ct <- coeftable(m)
  if (!"treated:post" %in% rownames(ct)) next
  se <- ct["treated:post", "Std. Error"]
  did_dt <- rbind(did_dt, data.table(
    test = sp$label,
    coef = ct["treated:post", "Estimate"],
    se   = se,
    pval = ct["treated:post", "Pr(>|t|)"],
    mde_80 = 2.80 * se,
    mde_50 = 1.96 * se,
    n    = m$nobs
  ))
}
print(did_dt)

# ---- Combine + interpret in context of typical effect sizes --------------
all_dt <- rbind(rdd_dt, did_dt, fill = TRUE)
all_dt[, observed_to_mde := abs(coef) / mde_80]   # relative to MDE
all_dt[, interp_mde_pp := round(mde_80 * 100, 2)]   # in percentage points

# Reference effect sizes from the literature
ref_effects <- data.table(
  reference = c("Imhof 2017 (Swiss highway)",
                "Bajari–Ye 2003",
                "Chassang–Ortner 2019",
                "this paper OLS baseline (FL price)",
                "Conley–Decarolis 2016"),
  effect_pp = c(15, 9, 8, 6.4, 12),
  metric    = "log price coefficient"
)

cat("\n--- MDE comparison vs literature ---\n")
for (i in seq_len(nrow(all_dt))) {
  cat(sprintf("  %s\n", all_dt$test[i]))
  cat(sprintf("    Observed:  %+.2f pp (SE %.2f, p=%.3g)\n",
              all_dt$coef[i] * 100, all_dt$se[i] * 100, all_dt$pval[i]))
  cat(sprintf("    MDE 80%%:   %.2f pp\n", all_dt$mde_80[i] * 100))
  cat(sprintf("    Cannot rule out effects up to ±%.2f pp\n",
              all_dt$mde_80[i] * 100))
  if (all_dt$mde_80[i] * 100 < 6) cat("      → can rule out v13-baseline 6.4pp ✓\n")
  if (all_dt$mde_80[i] * 100 >= 6) cat("      → CANNOT rule out v13-baseline 6.4pp ✗\n")
}

fwrite(all_dt,        file.path(OUT, "mde_summary.csv"))
fwrite(ref_effects,   file.path(OUT, "reference_effect_sizes.csv"))

# ---- Visualization: observed effect vs MDE ribbon -------------------------
plot_dt <- all_dt[, .(test, coef = coef * 100, se = se * 100,
                       mde_80 = mde_80 * 100, mde_50 = mde_50 * 100)]
plot_dt[, test_short := gsub(",.*", "",
                              sub("^.+, ", "", test, perl = TRUE))]
plot_dt[, group := fcase(
  grepl("RDD R\\$80k pre", test), "RDD R$80k pre",
  grepl("RDD R\\$176k post", test), "RDD R$176k post",
  grepl("DiD", test), "DiD Decreto",
  default = "other"
)]

p <- ggplot(plot_dt, aes(x = test, y = coef)) +
  geom_hline(yintercept = 0, color = "gray60") +
  geom_segment(aes(xend = test, y = -mde_80, yend = mde_80),
               color = "#bdbdbd", linewidth = 4, alpha = 0.6) +
  geom_segment(aes(xend = test, y = -mde_50, yend = mde_50),
               color = "#7f7f7f", linewidth = 4, alpha = 0.7) +
  geom_point(size = 3, color = "#d73027") +
  geom_hline(yintercept =  6.4, linetype = "dotted", color = "#1f77b4") +
  geom_hline(yintercept = -6.4, linetype = "dotted", color = "#1f77b4") +
  annotate("text", x = 1, y = 7.5, label = "v13 baseline ±6.4pp",
           color = "#1f77b4", size = 3, hjust = 0) +
  coord_flip() +
  labs(x = NULL, y = "Coefficient (%) with MDE bands (light = 80% power, dark = 50% power)",
       title = "Minimum detectable effects for the null tests",
       subtitle = "Observed point estimates ± MDE bands. Dotted: v13 OLS-baseline reference.") +
  theme_bw() +
  theme(panel.grid.major.y = element_blank())

ggsave(file.path(OUT, "fig_mde.pdf"), p, width = 8, height = 4.5,
       device = cairo_pdf)
cat(sprintf("  Saved: %s\n", file.path(OUT, "fig_mde.pdf")))

cat("\n  Done.\n")
