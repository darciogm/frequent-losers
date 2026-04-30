# ============================================================================
# 25_sham_fl_permutation.R — Sham FL classification permutation test (B3)
# Paper 3 v14: zero-risk falsification
#
# Generate B = 2,000 random "FL classifications" by drawing N_FL = 2,735
# firms uniformly at random from the always-loser pool of 16,843. For each
# sham classification:
#   - Compute AUC against CADE co-bidder ground truth (193 positives)
#   - Compute the price coefficient on losers in the OLS spec
#
# If observed AUC = 0.939 and observed price coef = +0.064 are NOT just
# artifacts of cherry-picking among always-losers, they should sit in the
# >99th percentile of the random distribution.
#
# Output:
#   output/sham_fl/sham_auc_distribution.csv
#   output/sham_fl/sham_price_coef_distribution.csv
#   output/sham_fl/fig_sham_distributions.pdf
#   output/sham_fl/sham_summary.csv
# ============================================================================

cat("=== 25_sham_fl_permutation.R ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2); library(pROC)
})

BASE <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
OUT  <- file.path(BASE, "output", "sham_fl")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- Load data -----------------------------------------------------------
fp <- as.data.table(read_parquet(file.path(BASE, "data/processed/FREQ_PARTICIP_rebuilt.parquet")))
ftm <- as.data.table(read_parquet(file.path(BASE, "data/processed/firm_tender_map.parquet")))
cade <- fread(file.path(BASE, "data/processed/cade_fl_cobidders.csv"))
cade[, firm_code := sprintf("%014.0f", as.numeric(`códigofornecedor`))]
cade_codes <- unique(cade$firm_code)

fp[, firm_code := as.character(`códigofornecedor`)]
ftm[, firm_code := as.character(`códigofornecedor`)]

dt <- readRDS("/tmp/p3_prepared.rds")

# ---- Define always-loser pool + observed FL set --------------------------
THRESH    <- 14L
al_codes  <- fp[always_loser == 1L, firm_code]
fl_obs    <- fp[always_loser == 1L & tenders_count > THRESH, firm_code]
N_FL_obs  <- length(fl_obs)
N_AL      <- length(al_codes)
cat(sprintf("  Always-loser pool: %s firms\n", format(N_AL, big.mark=",")))
cat(sprintf("  Observed FL set:   %s firms\n", format(N_FL_obs, big.mark=",")))
cat(sprintf("  CADE positives:    %d\n", length(cade_codes)))
cat(sprintf("  Bidding cost: %d simulations × {AUC + price regression}\n", 2000L))

# ---- Helper: compute observed values for reference ------------------------
al_dt <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al_dt[, is_cade := as.integer(firm_code %in% cade_codes)]

# Observed AUC (using continuous tenders_count = the v13 score)
obs_auc <- as.numeric(pROC::auc(pROC::roc(al_dt$is_cade, al_dt$tenders_count,
                                            quiet = TRUE)))
cat(sprintf("\n  Observed AUC (continuous tenders_count): %.4f\n", obs_auc))

# Observed AUC for binary FL flag
al_dt[, is_fl_obs := as.integer(firm_code %in% fl_obs)]
obs_auc_binary <- as.numeric(pROC::auc(pROC::roc(al_dt$is_cade, al_dt$is_fl_obs,
                                                  quiet = TRUE)))
cat(sprintf("  Observed AUC (binary FL flag):           %.4f\n", obs_auc_binary))

# Observed price coefficient
dt[, oc_item_key := paste0(oc_code, "_", item_code)]
dt_p <- dt[!is.na(lneg_price)]
m_obs <- feols(lneg_price ~ losers + convite | item_f + year_f + pbu_f,
                data = dt_p, cluster = ~item_f)
obs_coef <- coef(m_obs)["losers"]
obs_coef_se <- sqrt(vcov(m_obs)["losers", "losers"])
cat(sprintf("  Observed FL price coefficient:           %+.4f (SE %.4f)\n",
            obs_coef, obs_coef_se))

# ---- Sham simulation ------------------------------------------------------
cat("\n  Running 2,000 sham FL classifications...\n")

# Pre-compute firm → tender-item map (always-losers only)
ftm_al <- ftm[firm_code %in% al_codes & won == 0L,
              .(firm_code, oc_item_key = paste0(numerodaoc, "_", `códigoitem`))]

set.seed(20260430)
B <- 2000L

# We'll track AUC (binary) and price coef for each sham
sham_auc <- numeric(B)
sham_coef <- numeric(B)

t0 <- Sys.time()
for (b in seq_len(B)) {
  # Draw N_FL_obs firms uniformly at random from always-loser pool
  sham_fl_set <- sample(al_codes, N_FL_obs, replace = FALSE)

  # AUC: binary indicator of being in sham FL set, vs is_cade
  is_sham_fl <- as.integer(al_dt$firm_code %in% sham_fl_set)
  if (length(unique(is_sham_fl)) < 2 || sum(al_dt$is_cade) == 0) {
    sham_auc[b] <- NA_real_
  } else {
    r <- pROC::roc(al_dt$is_cade, is_sham_fl, quiet = TRUE)
    sham_auc[b] <- as.numeric(pROC::auc(r))
  }

  # Price coefficient: tender-items with ≥1 sham-FL participant
  sham_items <- ftm_al[firm_code %in% sham_fl_set, unique(oc_item_key)]
  dt_p[, sham_losers := as.integer(oc_item_key %in% sham_items)]
  m_sham <- tryCatch(
    feols(lneg_price ~ sham_losers + convite | item_f + year_f + pbu_f,
          data = dt_p, cluster = ~item_f, lean = TRUE),
    error = function(e) NULL)
  sham_coef[b] <- if (!is.null(m_sham)) coef(m_sham)["sham_losers"] else NA_real_

  if (b %% 100L == 0L) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("    [%4d/%d]  elapsed %.0fs\n", b, B, elapsed))
  }
}

# ---- Statistics ----------------------------------------------------------
cat("\n  ===== Sham distribution statistics =====\n")
sham_dt <- data.table(b = seq_len(B), auc = sham_auc, coef = sham_coef)
fwrite(sham_dt, file.path(OUT, "sham_auc_distribution.csv"))

# AUC quantiles + p-value for observed AUC
auc_q <- quantile(sham_auc, probs = c(0.5, 0.95, 0.99, 0.999), na.rm = TRUE)
cat(sprintf("  AUC sham: median=%.4f  q95=%.4f  q99=%.4f  q999=%.4f\n",
            auc_q[1], auc_q[2], auc_q[3], auc_q[4]))
auc_pvalue <- mean(sham_auc >= obs_auc_binary, na.rm = TRUE)
cat(sprintf("  Observed AUC (binary FL): %.4f → p = %.4g (%d/%d sham ≥ observed)\n",
            obs_auc_binary, auc_pvalue,
            sum(sham_auc >= obs_auc_binary, na.rm = TRUE), B))

# Price-coef quantiles
coef_q <- quantile(sham_coef, probs = c(0.5, 0.95, 0.99, 0.999), na.rm = TRUE)
cat(sprintf("  Coef sham: median=%+.4f  q95=%+.4f  q99=%+.4f  q999=%+.4f\n",
            coef_q[1], coef_q[2], coef_q[3], coef_q[4]))
coef_pvalue <- mean(sham_coef >= obs_coef, na.rm = TRUE)
cat(sprintf("  Observed price coef: %+.4f → p = %.4g (%d/%d sham ≥ observed)\n",
            obs_coef, coef_pvalue,
            sum(sham_coef >= obs_coef, na.rm = TRUE), B))

# Save consolidated summary
summary_dt <- data.table(
  metric    = c("AUC (binary FL)", "Price coefficient"),
  observed  = c(obs_auc_binary, obs_coef),
  sham_mean = c(mean(sham_auc, na.rm = TRUE), mean(sham_coef, na.rm = TRUE)),
  sham_sd   = c(sd(sham_auc,   na.rm = TRUE), sd(sham_coef,   na.rm = TRUE)),
  sham_q95  = c(auc_q[2], coef_q[2]),
  sham_q99  = c(auc_q[3], coef_q[3]),
  pvalue    = c(auc_pvalue, coef_pvalue),
  reject_99 = c(auc_pvalue < 0.01, coef_pvalue < 0.01)
)
fwrite(summary_dt, file.path(OUT, "sham_summary.csv"))
print(summary_dt)

# ---- Plot ----------------------------------------------------------------
auc_dt <- data.table(value = sham_auc, type = "AUC (binary FL flag)")
coef_dt <- data.table(value = sham_coef, type = "Price coefficient")

p_auc <- ggplot(auc_dt, aes(x = value)) +
  geom_histogram(bins = 50, fill = "#5b8aa6", color = "white") +
  geom_vline(xintercept = obs_auc_binary, linetype = "dashed",
             color = "#d73027", linewidth = 0.8) +
  annotate("text", x = obs_auc_binary, y = Inf, vjust = 1.5, hjust = -0.1,
           label = sprintf("Observed = %.4f\np = %.4g", obs_auc_binary,
                            auc_pvalue),
           color = "#d73027", size = 3) +
  labs(x = "AUC against CADE co-bidder labels (sham FL classifications, B=2000)",
       y = "Frequency",
       title = "Sham FL permutation test — AUC distribution",
       subtitle = "Random draws of 2,735 firms from 16,843 always-losers") +
  theme_bw()

p_coef <- ggplot(coef_dt, aes(x = value)) +
  geom_histogram(bins = 50, fill = "#9e3a4d", color = "white") +
  geom_vline(xintercept = obs_coef, linetype = "dashed",
             color = "#d73027", linewidth = 0.8) +
  annotate("text", x = obs_coef, y = Inf, vjust = 1.5, hjust = -0.1,
           label = sprintf("Observed = %+.4f\np = %.4g", obs_coef,
                            coef_pvalue),
           color = "#d73027", size = 3) +
  labs(x = "FL price coefficient (sham classifications)",
       y = "Frequency",
       title = "Sham FL permutation test — price coefficient distribution",
       subtitle = "Tender-items with ≥1 sham-FL participant; same FE structure") +
  theme_bw()

suppressPackageStartupMessages({
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    install.packages("patchwork", repos = "https://cran.r-project.org")
  }
  library(patchwork)
})
p_combined <- p_auc / p_coef
ggsave(file.path(OUT, "fig_sham_distributions.pdf"), p_combined,
       width = 7, height = 7, device = cairo_pdf)
cat(sprintf("  Saved: %s\n", file.path(OUT, "fig_sham_distributions.pdf")))

cat("\n  Done.\n")
