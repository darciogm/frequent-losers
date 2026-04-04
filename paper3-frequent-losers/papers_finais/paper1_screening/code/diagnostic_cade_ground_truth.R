# ============================================================================
# diagnostic_cade_ground_truth.R — Does zero-win add signal beyond volume?
# Self-contained: loads from parquet, no cache dependencies
# ============================================================================

cat("=== diagnostic_cade_ground_truth.R ===\n")
cat("  Does the zero-win condition add signal beyond participation volume?\n\n")

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})

# ---- Paths -------------------------------------------------------------------
DATA_DIR  <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/data/processed"
CADE_DIR  <- DATA_DIR

pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

# ---- Load data ---------------------------------------------------------------
cat("  Loading data...\n")

# CADE files
cade_match <- fread(file.path(CADE_DIR, "cade_bec_crossmatch.csv"))
cade_fl    <- fread(file.path(CADE_DIR, "cade_fl_cobidders.csv"))

# FREQ_PARTICIP (always-losers with participation counts)
fp <- as.data.table(read_parquet(file.path(DATA_DIR, "FREQ_PARTICIP_rebuilt.parquet")))
fp_col <- grep("fornecedor", names(fp), value = TRUE, ignore.case = TRUE)
if (length(fp_col) == 1 && fp_col != "firm_id") setnames(fp, fp_col, "firm_id")
fp[, firm_id := as.character(firm_id)]

# FL threshold
q <- quantile(fp$tenders_count, c(0.25, 0.50, 0.75))
iqr_val <- q[3] - q[1]
threshold <- q[2] + 1.5 * iqr_val
fl_ids <- unique(fp[tenders_count > threshold, firm_id])
cat(sprintf("  FL threshold: %.0f tenders\n", threshold))
cat(sprintf("  FL firms: %d\n", length(fl_ids)))

# Firm loss stats
fls <- as.data.table(read_parquet(file.path(DATA_DIR, "firm_loss_stats.parquet")))
fls_col <- grep("fornecedor", names(fls), value = TRUE, ignore.case = TRUE)
if (length(fls_col) == 1) setnames(fls, fls_col, "firm_id")
fls[, firm_id := as.character(firm_id)]

# FTM (big — 16.8M rows)
cat("  Loading firm_tender_map (16.8M rows)...\n")
ftm <- as.data.table(read_parquet(file.path(DATA_DIR, "firm_tender_map.parquet")))
ftm_col <- grep("fornecedor", names(ftm), value = TRUE, ignore.case = TRUE)
if (length(ftm_col) == 1) setnames(ftm, ftm_col, "firm_id")
ftm[, firm_id := as.character(firm_id)]
setnames(ftm, "numerodaoc", "oc_code", skip_absent = TRUE)
setnames(ftm, "códigoitem", "item_code", skip_absent = TRUE)

# CADE firm IDs
cade_firm_col <- grep("fornecedor|cnpj|firm_id", names(cade_match), value = TRUE, ignore.case = TRUE)[1]
cade_firm_ids <- as.character(unique(cade_match[[cade_firm_col]]))
cat(sprintf("  CADE firms in BEC: %d\n", length(cade_firm_ids)))

# ---- Compute co-bidding with CADE --------------------------------------------
cat("  Computing CADE co-bidders...\n")

cade_tenders <- ftm[firm_id %chin% cade_firm_ids, .(oc_code, item_code)]
cade_tenders <- unique(cade_tenders)
cade_cobidders <- merge(cade_tenders, ftm[, .(firm_id, oc_code, item_code)],
                         by = c("oc_code", "item_code"), all.x = TRUE)
all_cade_cobid <- unique(cade_cobidders$firm_id)
all_cade_cobid <- setdiff(all_cade_cobid, cade_firm_ids)
cat(sprintf("  Firms co-bidding with CADE: %d\n", length(all_cade_cobid)))

# Per-firm participation count
cat("  Computing firm participation counts...\n")
firm_participation <- ftm[, .(n_tenders = uniqueN(paste0(oc_code, "_", item_code))), by = firm_id]

# Master firm-level dataset
firms <- merge(fls, firm_participation, by = "firm_id", all.x = TRUE)
firms[is.na(n_tenders), n_tenders := 0L]
firms[, is_fl := firm_id %chin% fl_ids]
firms[, cobids_cade := firm_id %chin% all_cade_cobid]
firms[, is_always_loser := (win_rate == 0)]

cat(sprintf("\n  Total firms: %s\n", pfmt_int(nrow(firms))))
cat(sprintf("  Always-losers: %s\n", pfmt_int(sum(firms$is_always_loser))))
cat(sprintf("  Firms co-bidding with CADE: %s\n", pfmt_int(sum(firms$cobids_cade))))

# ============================================================================
# TEST 1: High-participation firms — zero-win vs positive-win
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST 1: High-participation firms (>= threshold) — zero-win vs positive-win\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

high_part <- firms[n_tenders >= threshold]
cat(sprintf("  Firms with >= %.0f participations: %d\n", threshold, nrow(high_part)))
cat(sprintf("    Zero-win (always-losers): %d\n", sum(high_part$is_always_loser)))
cat(sprintf("    Positive-win: %d\n", sum(!high_part$is_always_loser)))

rate_al <- high_part[is_always_loser == TRUE, mean(cobids_cade)]
rate_pw <- high_part[is_always_loser == FALSE, mean(cobids_cade)]
cat(sprintf("\n  CADE co-participation rate:\n"))
cat(sprintf("    Always-losers (win_rate = 0): %.1f%% (%d / %d)\n",
            100 * rate_al, high_part[is_always_loser == TRUE, sum(cobids_cade)],
            high_part[is_always_loser == TRUE, .N]))
cat(sprintf("    Positive-win firms:          %.1f%% (%d / %d)\n",
            100 * rate_pw, high_part[is_always_loser == FALSE, sum(cobids_cade)],
            high_part[is_always_loser == FALSE, .N]))
cat(sprintf("    Ratio (AL / PW): %.2f\n", rate_al / rate_pw))

mat1 <- matrix(c(
  high_part[is_always_loser == TRUE & cobids_cade == TRUE, .N],
  high_part[is_always_loser == TRUE & cobids_cade == FALSE, .N],
  high_part[is_always_loser == FALSE & cobids_cade == TRUE, .N],
  high_part[is_always_loser == FALSE & cobids_cade == FALSE, .N]
), nrow = 2, byrow = TRUE)
fisher1 <- fisher.test(mat1)
cat(sprintf("  Fisher exact test: OR = %.3f, p = %.6f\n", fisher1$estimate, fisher1$p.value))

logit1 <- glm(cobids_cade ~ is_always_loser + log(n_tenders),
              data = high_part, family = binomial)
cat("\n  Logistic: cobids_cade ~ always_loser + log(n_tenders)\n")
print(round(summary(logit1)$coefficients, 4))

# ============================================================================
# TEST 2: Zero-win vs low-positive-win, both high-participation
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST 2: Zero-win vs low-positive-win (< 2%), both >= threshold\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

strict_al <- firms[n_tenders >= threshold & win_rate == 0]
quasi_al  <- firms[n_tenders >= threshold & win_rate > 0 & win_rate <= 0.02]

cat(sprintf("  Strict always-losers (win_rate = 0): %d\n", nrow(strict_al)))
cat(sprintf("  Quasi-always-losers (0 < wr <= 2%%): %d\n", nrow(quasi_al)))

rate_strict <- strict_al[, mean(cobids_cade)]
rate_quasi  <- if (nrow(quasi_al) > 0) quasi_al[, mean(cobids_cade)] else NA

cat(sprintf("\n  CADE co-participation rate:\n"))
cat(sprintf("    Strict always-losers: %.1f%% (%d / %d)\n",
            100 * rate_strict, strict_al[, sum(cobids_cade)], nrow(strict_al)))
if (nrow(quasi_al) > 0) {
  cat(sprintf("    Quasi-always-losers:  %.1f%% (%d / %d)\n",
              100 * rate_quasi, quasi_al[, sum(cobids_cade)], nrow(quasi_al)))
  if (rate_quasi > 0) cat(sprintf("    Ratio: %.2f\n", rate_strict / rate_quasi))

  mat2 <- matrix(c(
    strict_al[, sum(cobids_cade)], strict_al[, sum(!cobids_cade)],
    quasi_al[, sum(cobids_cade)], quasi_al[, sum(!cobids_cade)]
  ), nrow = 2, byrow = TRUE)
  fisher2 <- fisher.test(mat2)
  cat(sprintf("  Fisher exact test: OR = %.3f, p = %.6f\n", fisher2$estimate, fisher2$p.value))
}

# Expand to 5%
quasi_al5 <- firms[n_tenders >= threshold & win_rate > 0 & win_rate <= 0.05]
if (nrow(quasi_al5) > 0) {
  rate_quasi5 <- quasi_al5[, mean(cobids_cade)]
  cat(sprintf("\n  Expanded (wr <= 5%%): %d firms, rate = %.1f%%\n",
              nrow(quasi_al5), 100 * rate_quasi5))
}

# ============================================================================
# TEST 3: Within participation deciles — FL vs non-FL among always-losers
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST 3: Within participation deciles — FL vs non-FL always-losers\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

al_firms <- firms[is_always_loser == TRUE & n_tenders >= 2]
# Use quintiles instead of deciles (distribution too skewed for 10 bins)
brks <- unique(quantile(al_firms$n_tenders, 0:5/5, na.rm = TRUE))
if (length(brks) <= 2) brks <- c(min(al_firms$n_tenders), 5, 10, 20, 50, max(al_firms$n_tenders))
al_firms[, tc_bin := as.integer(cut(n_tenders, brks, include.lowest = TRUE))]

bin_stats <- al_firms[!is.na(tc_bin), .(
  n_firms = .N,
  n_fl = sum(is_fl),
  n_non_fl = sum(!is_fl),
  min_tc = min(n_tenders),
  max_tc = max(n_tenders),
  cade_rate_fl = fifelse(sum(is_fl) > 0, mean(cobids_cade[is_fl]), NA_real_),
  cade_rate_non_fl = fifelse(sum(!is_fl) > 0, mean(cobids_cade[!is_fl]), NA_real_),
  cade_rate_all = mean(cobids_cade)
), by = tc_bin][order(tc_bin)]

cat("\n  CADE co-participation by participation bin (always-losers only):\n\n")
cat(sprintf("  %-5s  %-12s  %-7s  %-7s  %-12s  %-12s  %-12s\n",
            "Bin", "Range", "N_FL", "N_nonFL", "Rate_FL", "Rate_nonFL", "Rate_All"))
cat(paste(rep("-", 82), collapse = ""), "\n")
for (i in 1:nrow(bin_stats)) {
  d <- bin_stats[i]
  cat(sprintf("  %-5d  %4d - %-5d  %-7d  %-7d  %-12s  %-12s  %-12s\n",
              d$tc_bin, d$min_tc, d$max_tc, d$n_fl, d$n_non_fl,
              ifelse(is.na(d$cade_rate_fl), "---", sprintf("%.1f%%", 100 * d$cade_rate_fl)),
              ifelse(is.na(d$cade_rate_non_fl), "---", sprintf("%.1f%%", 100 * d$cade_rate_non_fl)),
              sprintf("%.1f%%", 100 * d$cade_rate_all)))
}

# ============================================================================
# TEST 4: Logistic regressions — disentangling volume vs zero-win vs FL
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST 4: Logistic regressions — volume vs zero-win vs FL\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

logitA <- glm(cobids_cade ~ log(n_tenders), data = firms[n_tenders >= 1], family = binomial)
logitB <- glm(cobids_cade ~ log(n_tenders) + is_always_loser, data = firms[n_tenders >= 1], family = binomial)
logitC <- glm(cobids_cade ~ log(n_tenders) + is_always_loser + is_fl, data = firms[n_tenders >= 1], family = binomial)
logitD <- glm(cobids_cade ~ log(n_tenders) + is_fl, data = firms[n_tenders >= 1], family = binomial)

cat("  Model A: ~ log(n_tenders)\n")
cat(sprintf("    AIC: %.0f\n", AIC(logitA)))
print(round(coef(summary(logitA)), 4))

cat("\n  Model B: ~ log(n_tenders) + always_loser\n")
cat(sprintf("    AIC: %.0f\n", AIC(logitB)))
print(round(coef(summary(logitB)), 4))

cat("\n  Model C: ~ log(n_tenders) + always_loser + FL\n")
cat(sprintf("    AIC: %.0f\n", AIC(logitC)))
print(round(coef(summary(logitC)), 4))

cat("\n  Model D: ~ log(n_tenders) + FL\n")
cat(sprintf("    AIC: %.0f\n", AIC(logitD)))
print(round(coef(summary(logitD)), 4))

# LR tests
lr_ba <- anova(logitA, logitB, test = "Chisq")
lr_cb <- anova(logitB, logitC, test = "Chisq")
cat("\n  Likelihood ratio tests:\n")
cat(sprintf("    B vs A (+ always_loser): chi2 = %.1f, p = %.6f\n",
            lr_ba$Deviance[2], lr_ba$`Pr(>Chi)`[2]))
cat(sprintf("    C vs B (+ FL | already_loser): chi2 = %.1f, p = %.6f\n",
            lr_cb$Deviance[2], lr_cb$`Pr(>Chi)`[2]))

# ============================================================================
# TEST 5: Fine-grained permutation — exact count matching (±2)
# ============================================================================

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("TEST 5: Fine-grained permutation — exact count matching (±2)\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

al_all <- firms[is_always_loser == TRUE]
fl_firms_dt <- al_all[is_fl == TRUE]
non_fl_firms_dt <- al_all[is_fl == FALSE]

set.seed(42)
n_perm <- 1000
perm_rates_exact <- numeric(n_perm)
observed_fl_rate <- fl_firms_dt[, mean(cobids_cade)]

cat(sprintf("  FL firms for matching: %d\n", nrow(fl_firms_dt)))
cat(sprintf("  Non-FL always-losers for pool: %d\n", nrow(non_fl_firms_dt)))

for (i in seq_len(n_perm)) {
  sampled_ids <- character(0)
  for (j in seq_len(nrow(fl_firms_dt))) {
    tc_target <- fl_firms_dt$n_tenders[j]
    pool <- non_fl_firms_dt[abs(n_tenders - tc_target) <= 2, firm_id]
    if (length(pool) > 0) {
      sampled_ids <- c(sampled_ids, sample(pool, 1))
    }
  }
  if (length(sampled_ids) > 0) {
    perm_rates_exact[i] <- mean(sampled_ids %chin% all_cade_cobid)
  }
}

cat(sprintf("\n  FL CADE co-participation rate: %.2f%%\n", 100 * observed_fl_rate))
cat(sprintf("  Exact-matched permutation mean: %.2f%% (SD: %.2f%%)\n",
            100 * mean(perm_rates_exact), 100 * sd(perm_rates_exact)))
cat(sprintf("  Ratio (observed / permutation): %.2f\n",
            observed_fl_rate / mean(perm_rates_exact)))
cat(sprintf("  p-value (observed >= permuted): %.4f\n",
            mean(perm_rates_exact >= observed_fl_rate)))

cat("\n=== DIAGNOSTIC COMPLETE ===\n")
