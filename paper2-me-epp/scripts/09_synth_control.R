# ============================================================================
# 09_synth_control.R — Synthetic Control Method for Paper 2
#
# Uses the 68 balanced product groups as the donor pool for synthetic Group 65
# (69 groups appear in all 6 semesters, of which one is Group 65 itself).
# Treatment date: March 2018 (semester 4; group 65 loses open-tender exemption).
# Pre-treatment gap shows the price advantage under open tenders.
# Post-treatment near-zero gap validates parallel trends assumption.
# ============================================================================

cat("=== 09_synth_control.R: Synthetic Control ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages({
  library(augsynth)
})

# ---- Load cached data -------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ============================================================================
# 1. AGGREGATE TO GROUP × SEMESTER BALANCED PANEL
# ============================================================================
cat("\n  --- Aggregating to group × semester panel ---\n")

price_dt <- dt[oc_item_status == 1L & !is.na(lpreco_final) & !is.na(codigogrupo)]
price_dt[, semester := cut(data_oc_numb, breaks = SEM_BREAKS, labels = SEM_LABELS,
                           right = FALSE, include.lowest = FALSE)]

sem_panel <- price_dt[!is.na(semester), .(
  lnprice    = mean(lpreco_final, na.rm = TRUE),
  lnfirms    = mean(lnum_firms, na.rm = TRUE),
  lnbids     = mean(lnum_bids, na.rm = TRUE),
  distance   = mean(dist1, na.rm = TRUE),
  lquant     = mean(lquantidade, na.rm = TRUE),
  convite_sh = mean(convite, na.rm = TRUE),
  n_items    = .N
), by = .(grupo = codigogrupo, semester)]

# Balance: keep only groups present in all 6 semesters
sem_counts <- sem_panel[, .(n_sem = uniqueN(semester)), by = grupo]
balanced_groups <- sem_counts[n_sem == 6, grupo]
cat("  Balanced groups:", length(balanced_groups), "of", uniqueN(sem_panel$grupo), "\n")
cat("  Group 65 included:", "65" %in% balanced_groups, "\n")

sem_panel <- sem_panel[grupo %in% balanced_groups]
sem_panel[, grupo_num := as.integer(factor(grupo, levels = sort(unique(grupo))))]
sem_panel[, sem_num := as.integer(factor(semester, levels = SEM_LABELS))]
sem_panel[, trt := as.integer(grupo == "65" & sem_num >= 4)]

setorder(sem_panel, grupo_num, sem_num)
cat("  Panel:", uniqueN(sem_panel$grupo), "groups ×", 6, "semesters =", nrow(sem_panel), "obs\n")

# ============================================================================
# 2. AUGMENTED SYNTHETIC CONTROL
# ============================================================================
cat("\n  --- Estimating augmented synthetic control ---\n")

panel_df <- as.data.frame(sem_panel)

asyn_fit <- augsynth(lnprice ~ trt, unit = grupo_num, time = sem_num,
                     data = panel_df, progfunc = "Ridge", scm = TRUE)

smry <- summary(asyn_fit)
post_att <- mean(smry$att$Estimate[smry$att$Time >= 4], na.rm = TRUE)
post_pval <- smry$att$p_val[smry$att$Time >= 4]
cat("  Mean post-treatment ATT:", pfmt(post_att, 4), "\n")
cat("  Post-period p-values:", paste(pfmt(post_pval, 3), collapse = ", "), "\n")

# Extract period-by-period estimates
period_ests <- smry$att
cat("  Period estimates:\n")
print(period_ests)

# ============================================================================
# 3. EXTRACT PRE-TREATMENT GAP (the key result)
# ============================================================================
cat("\n  --- Extracting pre/post gaps ---\n")

# Get treated vs synthetic time series
g65_id <- sem_panel[grupo == "65", unique(grupo_num)]
g65_actual <- sem_panel[grupo == "65", .(sem_num, lnprice)]
setorder(g65_actual, sem_num)

# Synthetic = weighted donors
weights <- as.numeric(asyn_fit$weights)
donor_ids <- unique(sem_panel[grupo != "65", grupo_num])
donor_wide <- dcast(sem_panel[grupo != "65"], sem_num ~ grupo_num, value.var = "lnprice")
donor_mat <- as.matrix(donor_wide[, -1])

# Align weights with donor columns
w_aligned <- rep(0, ncol(donor_mat))
dcols <- as.integer(colnames(donor_mat))
for (i in seq_along(donor_ids)) {
  idx <- which(dcols == donor_ids[i])
  if (length(idx) == 1 && i <= length(weights)) w_aligned[idx] <- weights[i]
}

synthetic_prices <- as.numeric(donor_mat %*% w_aligned)

gap_df <- data.frame(
  semester = 1:6,
  sem_label = SEM_LABELS,
  actual = g65_actual$lnprice,
  synthetic = synthetic_prices,
  gap = g65_actual$lnprice - synthetic_prices,
  period = c(rep("Pre", 3), rep("Post", 3))
)

cat("\n  Gap by semester:\n")
print(gap_df[, c("sem_label", "actual", "synthetic", "gap", "period")])

pre_gap_mean <- mean(gap_df$gap[1:3])
post_gap_mean <- mean(gap_df$gap[4:6])
cat("\n  Mean pre-period gap:", pfmt(pre_gap_mean, 4), "(group 65 - synthetic)\n")
cat("  Mean post-period gap:", pfmt(post_gap_mean, 4), "(should be ~0)\n")

# ============================================================================
# 4. FIGURE: ACTUAL VS SYNTHETIC + GAP
# ============================================================================
cat("\n  --- Generating figures ---\n")

# Panel A: Levels (actual vs synthetic)
levels_df <- rbind(
  data.frame(semester = 1:6, price = gap_df$actual, series = "Group 65 (actual)"),
  data.frame(semester = 1:6, price = gap_df$synthetic, series = "Synthetic Group 65")
)

fig_levels <- ggplot(levels_df, aes(x = semester, y = price, linetype = series)) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = 3.5, linetype = "dashed", color = "grey50") +
  scale_linetype_manual(values = c("Group 65 (actual)" = "solid",
                                    "Synthetic Group 65" = "dashed")) +
  scale_x_continuous(breaks = 1:6, labels = SEM_LABELS) +
  labs(x = NULL, y = "Mean log price") +
  annotate("text", x = 3.4, y = max(levels_df$price) * 0.98,
           label = "Policy change", hjust = 1, size = 2.8) +
  theme_pub() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))

save_pub(fig_levels, "fig_16_synth_levels.pdf")

# Panel B: Gap
fig_gap <- ggplot(data.frame(semester = 1:6, gap = gap_df$gap),
                  aes(x = semester, y = gap)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = 3.5, linetype = "dashed", color = "grey50") +
  scale_x_continuous(breaks = 1:6, labels = SEM_LABELS) +
  labs(x = NULL, y = "Gap: Group 65 - Synthetic (log prices)") +
  annotate("text", x = 3.4, y = min(gap_df$gap) * 0.9,
           label = "Policy change", hjust = 1, size = 2.8) +
  theme_pub() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))

save_pub(fig_gap, "fig_17_synth_gap.pdf")

# ============================================================================
# 5. IN-SPACE PLACEBO TESTS
# ============================================================================
cat("\n  --- In-space placebo tests ---\n")

donor_list <- setdiff(balanced_groups, "65")
placebo_atts <- numeric(length(donor_list))
names(placebo_atts) <- donor_list

for (i in seq_along(donor_list)) {
  g <- donor_list[i]
  if (i %% 20 == 0) cat("    Placebo", i, "of", length(donor_list), "\n")

  temp_df <- copy(panel_df)
  g_num <- sem_panel[grupo == g, unique(grupo_num)]
  temp_df$trt_temp <- as.integer(temp_df$grupo_num == g_num & temp_df$sem_num >= 4)

  pfit <- tryCatch({
    augsynth(lnprice ~ trt_temp, unit = grupo_num, time = sem_num,
             data = temp_df, progfunc = "Ridge", scm = TRUE)
  }, error = function(e) NULL)

  if (!is.null(pfit)) {
    psmry <- tryCatch(summary(pfit), error = function(e) NULL)
    placebo_atts[i] <- if (!is.null(psmry)) psmry$att$Estimate else NA_real_
  } else {
    placebo_atts[i] <- NA_real_
  }
}

placebo_atts <- placebo_atts[!is.na(placebo_atts)]
# Use the mean post-treatment ATT (average of periods 4-6)
treated_att <- mean(smry$att$Estimate[smry$att$Time >= 4], na.rm = TRUE)
rank_pval <- mean(abs(placebo_atts) >= abs(treated_att))

cat("  Treated ATT:", pfmt(treated_att, 4), "\n")
cat("  Placebo rank p-value:", pfmt(rank_pval, 4),
    "(", sum(abs(placebo_atts) >= abs(treated_att)), "/",
    length(placebo_atts), ")\n")

# Placebo figure
fig_placebo <- ggplot(data.frame(att = c(placebo_atts, treated_att),
                                  type = c(rep("Placebo", length(placebo_atts)),
                                           "Group 65")),
                      aes(x = att, fill = type)) +
  geom_histogram(bins = 25, alpha = 0.7, color = "white", linewidth = 0.3) +
  geom_vline(xintercept = treated_att, linetype = "dashed", linewidth = 0.8) +
  scale_fill_manual(values = c("Group 65" = "black", "Placebo" = "grey60")) +
  labs(x = "Post-treatment ATT (log prices)", y = "Count") +
  theme_pub()

save_pub(fig_placebo, "fig_18_synth_placebo.pdf")

# ============================================================================
# 6. GENERATE TABLE
# ============================================================================
cat("\n  --- Generating table ---\n")

# Top donor weights
w_df <- data.frame(grupo = donor_list,
                   grupo_num = sapply(donor_list, function(g) sem_panel[grupo == g, unique(grupo_num)]),
                   weight = weights[seq_along(donor_list)])
# Actually get weights properly from augsynth
w_raw <- as.numeric(asyn_fit$weights)
w_names <- rownames(asyn_fit$weights)
if (is.null(w_names)) w_names <- as.character(seq_along(w_raw))
w_df2 <- data.frame(grupo_num = as.integer(w_names), weight = w_raw)
w_df2 <- w_df2[order(-w_df2$weight), ]
w_df2 <- w_df2[w_df2$weight > 0.01, ]

# Map grupo_num back to grupo name
gmap <- unique(sem_panel[, .(grupo, grupo_num)])
w_df2 <- merge(w_df2, gmap, by = "grupo_num")

tab_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Synthetic Control: Summary Results}",
  "\\label{tab:synth}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lc}",
  "\\toprule",
  "\\multicolumn{2}{l}{\\textit{Panel A: Gaps}} \\\\",
  "\\midrule",
  paste0("Mean pre-treatment gap (semesters 1--3) & ", pfmt(pre_gap_mean, 4), " \\\\"),
  paste0("Mean post-treatment gap (semesters 4--6) & ", pfmt(post_gap_mean, 4), " \\\\"),
  paste0("Post-treatment ATT (mean) & ", pfmt(treated_att, 4), " \\\\"),
  paste0("Placebo rank $p$-value & ", pfmt(rank_pval, 3),
         " (", sum(abs(placebo_atts) >= abs(treated_att)),
         "/", length(placebo_atts), ") \\\\"),
  paste0("L2 imbalance & ", pfmt(smry$l2_imbalance, 4), " \\\\"),
  "\\midrule",
  "\\multicolumn{2}{l}{\\textit{Panel B: Top donor weights ($>$ 1\\%)}} \\\\",
  "\\midrule",
  "Product group & Weight \\\\"
)

for (j in seq_len(min(nrow(w_df2), 12))) {
  tab_lines <- c(tab_lines,
    paste0("Group ", w_df2$grupo[j], " & ", pfmt(w_df2$weight[j], 3), " \\\\"))
}

remaining <- sum(w_raw[w_raw > 0 & w_raw <= 0.01])
if (remaining > 0) {
  tab_lines <- c(tab_lines,
    paste0("Other groups & ", pfmt(remaining, 3), " \\\\"))
}

tab_lines <- c(tab_lines,
  "\\midrule",
  paste0("Balanced groups & ", length(balanced_groups), " \\\\"),
  paste0("Semesters & 6 \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Augmented synthetic control with Ridge augmentation.",
  "Outcome: mean log price at the group $\\times$ semester level.",
  "Treatment date: March 2018 (group 65 loses open-tender exemption).",
  "Pre-treatment gap measures how much lower group 65 prices were under",
  "open tenders relative to the synthetic counterfactual.",
  "Post-treatment gap near zero validates the parallel trends assumption.",
  "Inference via conformal method.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(tab_lines, file.path(OUT_TAB, "tab_synth.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_synth.tex"), "\n")

# ---- Save all results -------------------------------------------------------
saveRDS(list(
  fit = asyn_fit, gap_df = gap_df, placebo_atts = placebo_atts,
  rank_pval = rank_pval, pre_gap_mean = pre_gap_mean,
  post_gap_mean = post_gap_mean
), "/tmp/p2_synth.rds")

rm(dt, price_dt, sem_panel)
gc(verbose = FALSE)

cat("=== 09_synth_control.R: Done ===\n")
