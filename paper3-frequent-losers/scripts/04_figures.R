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
# Uses bid-level data from LANCES files (partial: 2009-2011, 2015-2016)
# ============================================================================

has_bidlevel <- file.exists(DATA_CACHE_BL)

if (has_bidlevel) {
  cat("  Loading bid-level data for figures 3-8...\n")
  bl <- readRDS(DATA_CACHE_BL)
  fls <- readRDS(DATA_CACHE_FLS)

  # Normalize column names
  setnames(bl, "códigofornecedor", "firm_id", skip_absent = TRUE)
  setnames(bl, "códigoitem", "item_code_bl", skip_absent = TRUE)
  setnames(bl, "numerodaoc", "oc_code_bl", skip_absent = TRUE)
  setnames(bl, "mêsanoencerramento", "month_year", skip_absent = TRUE)
  setnames(bl, "descriçãoprocedimentocompra", "proc_type", skip_absent = TRUE)
  setnames(bl, "códigounidadecompradora", "pbu_bl", skip_absent = TRUE)
  setnames(fls, "códigofornecedor", "firm_id", skip_absent = TRUE)

  # Identify FL firms in bid-level data (cross-reference with FREQ_PARTICIP)
  fp_ids <- freq_particip[[grep("fornecedor", names(freq_particip), value = TRUE, ignore.case = TRUE)[1]]]
  bl[, is_fl := firm_id %chin% fp_ids]

  fl_bl <- bl[is_fl == TRUE]
  cat(sprintf("    FL bids in bid-level data: %s (out of %s total)\n",
              pfmt_int(nrow(fl_bl)), pfmt_int(nrow(bl))))

  # ---- Figure 3: Persistence (months competed vs total losses) ----
  cat("  Figure 3: Persistence...\n")

  # Count distinct months and total participations per FL firm
  fl_persist <- fl_bl[, .(n_months = uniqueN(month_year),
                           n_losses = .N), by = firm_id]

  if (nrow(fl_persist) > 10) {
    p3 <- ggplot(fl_persist, aes(x = n_months, y = n_losses)) +
      geom_point(alpha = 0.3, size = 1, color = "gray30") +
      geom_smooth(method = "lm", se = FALSE, color = "black", linewidth = 0.7) +
      scale_y_continuous(labels = scales::comma_format()) +
      labs(x = "Number of Months Competing", y = "Total Losses") +
      theme_pub()

    save_pub(p3, "fig_03_persistence.pdf")
  }

  # ---- Figure 4: Tender mode breakdown ----
  cat("  Figure 4: Tender modes...\n")

  mode_counts <- fl_bl[, .N, by = proc_type][order(-N)]
  mode_counts <- mode_counts[!is.na(proc_type) & N > 100]

  if (nrow(mode_counts) > 1) {
    mode_counts[, proc_short := substr(proc_type, 1, 25)]
    p4 <- ggplot(mode_counts, aes(x = reorder(proc_short, N), y = N)) +
      geom_col(fill = "gray50") +
      coord_flip() +
      scale_y_continuous(labels = scales::comma_format()) +
      labs(x = NULL, y = "Number of FL Bids") +
      theme_pub()

    save_pub(p4, "fig_04_tender_modes.pdf")
  }

  # ---- Figure 5: Loser types (convite-only / pregão-only / both) ----
  cat("  Figure 5: Loser types...\n")

  fl_types <- fl_bl[, .(has_convite = any(grepl("CONVITE", proc_type, ignore.case = TRUE)),
                          has_pregao = any(grepl("PREG", proc_type, ignore.case = TRUE))),
                      by = firm_id]
  fl_types[, type := fifelse(has_convite & has_pregao, "Both",
                     fifelse(has_convite, "Convite only", "Pregão only"))]
  type_summary <- fl_types[, .N, by = type]

  if (nrow(type_summary) > 0) {
    p5 <- ggplot(type_summary, aes(x = reorder(type, N), y = N)) +
      geom_col(fill = "gray50") +
      coord_flip() +
      labs(x = NULL, y = "Number of FL Firms") +
      theme_pub()

    save_pub(p5, "fig_05_loser_types.pdf")
  }

  # ---- Figure 6: Shannon entropy of item group diversity ----
  cat("  Figure 6: Shannon entropy...\n")

  fl_bl[, item_group_bl := substr(item_code_bl, 1, 2)]
  fl_entropy <- fl_bl[, {
    tab <- table(item_group_bl)
    p <- tab / sum(tab)
    .(entropy = -sum(p * log(p)), n_groups = length(tab))
  }, by = firm_id]

  if (nrow(fl_entropy) > 10) {
    p6 <- ggplot(fl_entropy, aes(x = entropy)) +
      geom_histogram(bins = 30, fill = "gray60", color = "gray30", linewidth = 0.3) +
      labs(x = "Shannon Entropy (Item Group Diversity)", y = "Number of FL Firms") +
      theme_pub()

    save_pub(p6, "fig_06_entropy.pdf")
  }

  # ---- Figure 7: Item group variety ----
  cat("  Figure 7: Item group variety...\n")

  if (nrow(fl_entropy) > 10) {
    p7 <- ggplot(fl_entropy, aes(x = n_groups)) +
      geom_histogram(bins = 30, fill = "gray60", color = "gray30", linewidth = 0.3) +
      labs(x = "Number of Distinct Item Groups", y = "Number of FL Firms") +
      theme_pub()

    save_pub(p7, "fig_07_item_variety.pdf")
  }

  # ---- Figure 8: PBU concentration ----
  cat("  Figure 8: PBU concentration...\n")

  fl_pbu <- fl_bl[, .(n_pbus = uniqueN(pbu_bl),
                        n_tenders = uniqueN(oc_code_bl)), by = firm_id]
  fl_pbu[, pbu_concentration := 1 / n_pbus]  # Inverse = more concentrated

  if (nrow(fl_pbu) > 10) {
    p8 <- ggplot(fl_pbu, aes(x = n_pbus)) +
      geom_histogram(bins = 30, fill = "gray60", color = "gray30", linewidth = 0.3) +
      labs(x = "Number of Distinct PBUs", y = "Number of FL Firms") +
      theme_pub()

    save_pub(p8, "fig_08_pbu_concentration.pdf")
  }

  rm(bl, fl_bl)
  gc()
} else {
  cat("  Figures 3-8: SKIPPED (run 00_build_bidlevel.py first for bid-level data)\n")
}

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
