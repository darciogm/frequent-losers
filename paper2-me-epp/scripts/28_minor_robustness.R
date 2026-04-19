# ============================================================================
# 28_minor_robustness.R — Minor-referee concerns M2, M3, M4
# ============================================================================
# M2: selection into valid phase-2 moments
# M3: F-test of quartile-coefficient equality for counterfactual claim
# M4: distribution of pharma contract prices relative to reference (CMED proxy)
# ============================================================================

cat("=== 28_minor_robustness.R ===\n")

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  f_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(f_arg)) dirname(sub("^--file=", "", f_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils.R"), local = TRUE)
suppressPackageStartupMessages({library(fixest); library(ggplot2); library(scales)})
setFixest_estimation(lean = FALSE)

dt <- as.data.table(readRDS(DATA_CACHE))

# ============================================================================
# M2 — Selection into valid phase-2 bid moments
# ============================================================================
cat("\n--- M2: Phase-2 validity selection DiD ---\n")

bd <- readRDS("/tmp/p2_bid_raw.rds")  # already Group 65 + valid_ph2 + 18m completed
cat("  Valid phase-2 rows (G65, 18m, completed):", pfmt_int(nrow(bd)), "\n")

# Construct has_valid_ph2 on the full 18m completed sample. Join via item_alt.
# Note: p2_bid_raw has only Group-65 items; it cannot tell us about valid_ph2
# for non-G65 items. Instead, replicate the valid_ph2 test directly on the
# full CSV view to get an indicator for every row.

csv_path <- file.path(DATA_RAW, "Paper2_ME_EPP.csv")
if (file.exists(csv_path)) {
  cat("  Reading phase-2 columns from CSV for full-sample valid_ph2 flag...\n")
  hdr <- names(fread(csv_path, sep=";", encoding="Latin-1", nrows=0))
  keep <- c("data_oc_numb", "item_alt", "pbu_alt", "oc_item_status",
            "min_bid_ph2", "max_bid_ph2", "mean_bid_ph2", "sd_bid_ph2",
            "preco_ref",
            grep("digogrupo$", hdr, value=TRUE))
  cd <- fread(csv_path, sep=";", encoding="Latin-1",
              select = intersect(hdr, keep))
  grupo_col <- grep("digogrupo$", names(cd), value=TRUE)
  if (length(grupo_col) == 1 && grupo_col != "codigogrupo")
    setnames(cd, grupo_col, "codigogrupo")
  cd[, codigogrupo := as.character(codigogrupo)]
  cd[, g65 := as.integer(codigogrupo == "65")]
  cd[, Pre := as.integer(data_oc_numb < TREAT_DATE)]
  cd[, g65_pre := g65 * Pre]
  cd[, has_valid_ph2 := as.integer(!is.na(min_bid_ph2) & min_bid_ph2 > 0 &
                                   !is.na(preco_ref) & preco_ref > 0 &
                                   !is.na(sd_bid_ph2) & !is.na(mean_bid_ph2) &
                                   mean_bid_ph2 > 0)]
  d18c <- cd[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
             oc_item_status == 1L]
  cat(sprintf("    full-sample 18m completed: %s rows\n", pfmt_int(nrow(d18c))))
  cat(sprintf("    pct with valid phase-2:    %.1f%% (%s rows)\n",
              100 * mean(d18c$has_valid_ph2, na.rm=TRUE),
              pfmt_int(sum(d18c$has_valid_ph2, na.rm=TRUE))))

  # DiD on selection indicator — controls taken from CSV context itself via
  # simpler spec (no sealed-bid dummy since that isn't in the CSV subset).
  m_sel <- feols(has_valid_ph2 ~ g65_pre | item_alt + data_oc_numb,
                 data = d18c, cluster = ~item_alt, lean = FALSE)
  b <- coef(m_sel)["g65_pre"]; se <- sqrt(vcov(m_sel)["g65_pre", "g65_pre"])
  p <- 2 * pnorm(-abs(b / se))
  cat(sprintf("    DiD on has_valid_ph2:  %+.4f (%.4f), p = %.3f\n", b, se, p))
  sel_result <- list(beta = b, se = se, p = p,
                     pct_overall = 100 * mean(d18c$has_valid_ph2, na.rm=TRUE))
  saveRDS(sel_result, "/tmp/p2_m2_selection.rds")
} else {
  cat("  CSV not found; skipping selection DiD.\n")
  sel_result <- NULL
}

# ============================================================================
# M3 — F-test of equality across quartile coefficients
# ============================================================================
cat("\n--- M3: F-test of quartile-coefficient equality ---\n")

cf <- readRDS("/tmp/p2_counterfactual.rds")
b_q <- sapply(cf$betas, function(x) x$b)
se_q <- sapply(cf$betas, function(x) x$se)
n_q <- sapply(cf$betas, function(x) x$n)
cat("  Quartile-specific coefficients and SEs:\n")
for (q in 1:4) cat(sprintf("    Q%d: beta = %+.4f (SE %.4f), n = %s\n",
                            q, b_q[q], se_q[q], pfmt_int(n_q[q])))

# Conservative chi-square test of H0: beta_1 = beta_2 = beta_3 = beta_4
# assuming independent estimates (between-quartile covariances are zero
# because the quartiles are disjoint subsamples of items)
b_mean <- weighted.mean(b_q, w = 1 / se_q^2)
chi_sq <- sum((b_q - b_mean)^2 / se_q^2)
df_chi <- length(b_q) - 1L
p_chi <- pchisq(chi_sq, df_chi, lower.tail = FALSE)
cat(sprintf("  Weighted mean beta: %+.4f\n", b_mean))
cat(sprintf("  H0: all beta_q equal. Wald chi-square(%d) = %.2f, p = %.3f\n",
            df_chi, chi_sq, p_chi))

# Range and spread
cat(sprintf("  Range: %+.4f to %+.4f (spread = %.4f log points)\n",
            min(b_q), max(b_q), max(b_q) - min(b_q)))

q_result <- list(b_q = b_q, se_q = se_q, n_q = n_q,
                 chi_sq = chi_sq, df = df_chi, p = p_chi, b_mean = b_mean)
saveRDS(q_result, "/tmp/p2_m3_quartile.rds")

# ============================================================================
# M4 — Distribution of pharma prices relative to reference (CMED-cap proxy)
# ============================================================================
cat("\n--- M4: Pharma price / reference distribution ---\n")

d_pharma <- dt[g65 == 1L & class_alt == "6531" & oc_item_status == 1L &
               !is.na(preco_final) & !is.na(preco_ref) &
               preco_ref > 0 & preco_final > 0 &
               data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
d_pharma[, ratio := preco_final / preco_ref]
d_pharma[, regime := fifelse(Pre == 1L, "Open tenders", "SME-only")]

cat(sprintf("  Pharma sample size: %s\n", pfmt_int(nrow(d_pharma))))
cat("  Distribution of preco_final / preco_ref (CMED-cap proxy):\n")
summary_ratio <- d_pharma[, .(
  mean_ratio   = mean(ratio),
  median_ratio = median(ratio),
  pct_below_1  = 100 * mean(ratio <= 1),
  pct_below_90 = 100 * mean(ratio <= 0.90),
  pct_below_75 = 100 * mean(ratio <= 0.75)
), by = regime]
print(summary_ratio)

# Simple PDF figure
cat("  Rendering figure...\n")
df_fig <- d_pharma[ratio <= 1.3 & ratio > 0.2]
df_fig[, regime := factor(regime, levels = c("Open tenders", "SME-only"))]
p <- ggplot(df_fig, aes(x = ratio, fill = regime,
                         color = regime, linetype = regime)) +
  geom_density(alpha = 0.35, linewidth = 0.7, adjust = 1.1) +
  geom_vline(xintercept = 1, linetype = "dotted", color = "red4",
             linewidth = 0.4) +
  annotate("text", x = 1, y = 0, label = "CMED cap", hjust = -0.1,
           vjust = -0.5, size = 3.0, color = "red4") +
  scale_fill_manual(values = c("Open tenders" = "gray25",
                               "SME-only"     = "gray80")) +
  scale_color_manual(values = c("Open tenders" = "black",
                                "SME-only"     = "gray50")) +
  scale_linetype_manual(values = c("Open tenders" = "solid",
                                   "SME-only"     = "longdash")) +
  scale_x_continuous(labels = percent_format(accuracy = 1),
                     breaks = c(0.25, 0.5, 0.75, 1.0, 1.25)) +
  labs(x = "Winning unit price / reference price (CMED cap proxy)",
       y = "Density of pharma (class 6531) completed items") +
  theme_pub() +
  theme(legend.position = "bottom")
save_pub(p, "fig_cmed_distribution.pdf")

cmed_result <- list(summary = summary_ratio, n = nrow(d_pharma))
saveRDS(cmed_result, "/tmp/p2_m4_cmed.rds")

cat("\n=== 28_minor_robustness.R: Done ===\n")
