# ============================================================================
# 04_figures.R — Publication-quality figures
# Paper 3: Frequent Losers in Public Procurement
# ============================================================================

cat("=== 04_figures.R: Figure generation ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages(library(scales))

# ---- Load data and models --------------------------------------------------
if (!file.exists(DATA_CACHE_FP)) stop("Run 01_clean.R first")
freq_particip <- readRDS(DATA_CACHE_FP)

models_path <- "/tmp/p3_models.rds"
if (!file.exists(models_path)) stop("Run 02_analysis.R first")
models <- readRDS(models_path)

# ============================================================================
# Figure 1: Distribution of losses for "always losers"
# (Manuscript Figure 1 — histogram of number of losses)
# ============================================================================

cat("  Figure 1: Losses distribution...\n")

# FREQ_PARTICIP contains frequent losers with their tenders_count
# (for always-losers, tenders_count ≈ number of losses)
fp <- copy(freq_particip)
# Normalize column name (may have encoding)
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1) setnames(fp, fp_col, "firm_id")

p1 <- ggplot(fp, aes(x = tenders_count)) +
  geom_histogram(bins = 50, fill = "gray60", color = "gray30", linewidth = 0.3) +
  labs(x = "Number of Losses", y = "Number of Firms") +
  scale_x_continuous(labels = comma_format()) +
  theme_pub()

save_pub(p1, "fig_01_losses_distribution.pdf")

# ============================================================================
# Figure 2: IQR identification of frequent losers
# (Manuscript Figure 2 — distribution with IQR threshold line)
# ============================================================================

cat("  Figure 2: IQR identification...\n")

# Compute IQR threshold (1.5 × IQR above Q3)
q <- quantile(fp$tenders_count, c(0.25, 0.75))
iqr_val <- q[2] - q[1]
threshold <- q[2] + 1.5 * iqr_val

p2 <- ggplot(fp, aes(x = tenders_count)) +
  geom_histogram(bins = 50, fill = "gray60", color = "gray30", linewidth = 0.3) +
  geom_vline(xintercept = threshold, linetype = "dashed", color = "black",
             linewidth = 0.7) +
  annotate("text", x = threshold, y = Inf, vjust = 2, hjust = -0.1,
           label = paste0("IQR threshold = ", round(threshold)),
           size = 3) +
  labs(x = "Number of Losses", y = "Number of Firms") +
  scale_x_continuous(labels = comma_format()) +
  theme_pub()

save_pub(p2, "fig_02_iqr_identification.pdf")

# ============================================================================
# Figures 3-8: Descriptive characteristics of frequent losers
# These require bid-level data (which firm bid where, when, in which mode)
# that is not available in the collapsed parquet datasets.
# ============================================================================

cat("  Figures 3-8: STUBBED (require bid-level data not in parquets)\n")
cat("    Fig 3: Persistence (months competed, total losses) — needs temporal bid data\n")
cat("    Fig 4: Tender modes — needs firm×mode bid data\n")
cat("    Fig 5: Loser types (convite-only/pregao-only/both) — needs firm×mode data\n")
cat("    Fig 6: Shannon entropy — needs firm×item group bid data\n")
cat("    Fig 7: Item group variety — needs firm×item bid data\n")
cat("    Fig 8: PBU concentration — needs firm×PBU bid data\n")
cat("  To generate these, add bid-level data extraction from raw BEC CSV.\n")

# ============================================================================
# Figure 9: Coefficient summary plot from regression results
# ============================================================================

cat("  Figure 9: Coefficient summary plot...\n")

# Extract losers coefficients from all 12 models
coef_data <- data.table()
outcome_labels <- c(prices = "Log Price", nfirms = "Log Firms", nbids = "Log Bids")
spec_labels <- c(general = "(1) General", general_pbu = "(2) General+PBU",
                 pregao = "(3) Pregao", convite = "(4) Convite")

for (outcome in names(models)) {
  mlist <- models[[outcome]]
  for (spec in names(mlist)) {
    m <- mlist[[spec]]
    b  <- coef(m)["losers"]
    se <- sqrt(vcov(m)["losers", "losers"])
    coef_data <- rbind(coef_data, data.table(
      outcome = outcome_labels[outcome],
      spec    = spec_labels[spec],
      coef    = b,
      se      = se,
      ci_lo   = b - 1.96 * se,
      ci_hi   = b + 1.96 * se
    ))
  }
}

# Reorder factors
coef_data[, outcome := factor(outcome, levels = rev(c("Log Price", "Log Firms", "Log Bids")))]
coef_data[, spec := factor(spec, levels = rev(c("(1) General", "(2) General+PBU",
                                                  "(3) Pregao", "(4) Convite")))]

p9 <- ggplot(coef_data, aes(x = coef, y = spec, shape = outcome)) +
  geom_vline(xintercept = 0, linetype = "dotted", color = "gray50", linewidth = 0.3) +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi),
                width = 0.15, linewidth = 0.5, color = "black",
                position = position_dodge(width = 0.5)) +
  geom_point(size = 2.5, color = "black",
             position = position_dodge(width = 0.5)) +
  scale_shape_manual(values = c("Log Price" = 16, "Log Firms" = 17, "Log Bids" = 15)) +
  labs(x = "Coefficient (losers)", y = NULL) +
  theme_pub() +
  theme(legend.position = "bottom")

save_pub(p9, "fig_09_coef_summary.pdf")

cat("  All figures generated.\n")
