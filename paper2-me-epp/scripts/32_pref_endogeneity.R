# ============================================================================
# Paper 2 — Reference-price endogeneity test (non-pharma vs pharma split)
# Mirrors main DiD spec on lpreco_final but with lpreco_ref as DV. Splits the
# Group 65 sample by pharma flag (class_alt == 6531) following 24_pharma.R.
# Reports TWFE / CS / BJS / event study / heterogeneity placebo separately
# for non-pharma and pharma samples.
#
# Run from project root: Rscript scripts/32_pref_endogeneity.R
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(arrow)
  library(ggplot2)
  library(did)
  library(didimputation)
})

# ---- Paths --------------------------------------------------------------
PROJ_ROOT <- getwd()
DATA_PARQ <- file.path(PROJ_ROOT, "data/processed/paper2_me_epp.parquet")
stopifnot("Run from paper2-me-epp/ project root (parquet not found)" =
            file.exists(DATA_PARQ))
V8_DIR <- file.path(PROJ_ROOT, "v8-jpube")
V8_VAL <- file.path(V8_DIR, "output/values.tex")
V8_FIG <- file.path(V8_DIR, "output/figures")
dir.create(V8_FIG, recursive = TRUE, showWarnings = FALSE)

TREAT_DATE <- 698L              # March 2018
WIN_18M    <- c(680L, 715L)     # Sep 2016 – Aug 2019
PHARMA_CLASS <- 6531L

NCORES <- min(parallel::detectCores(logical = FALSE), 12L)
setFixest_nthreads(NCORES)
setDTthreads(NCORES)
setFixest_estimation(lean = TRUE)
set.seed(42)

cat("=== Reference-price endogeneity test (NP / PH split) ===\n")
cat("Threads:", NCORES, "\n\n")

# ---- Load + window restriction ----------------------------------------
cat("[1/7] Loading parquet...\n")
dt <- as.data.table(read_parquet(DATA_PARQ))
dt <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
cat("  rows in 18m window:", format(nrow(dt), big.mark=","), "\n")

dt[, g65 := as.integer(codigogrupo == "65")]
dt[, Pre := as.integer(data_oc_numb < TREAT_DATE)]
dt[, g65_pre := g65 * Pre]
dt[, pharma := as.integer(!is.na(class_alt) & class_alt == PHARMA_CLASS)]
dt[, item_alt := factor(item_alt)]
dt[, pbu_alt  := factor(pbu_alt)]

dt_pref <- dt[!is.na(lpreco_ref) & is.finite(lpreco_ref)]
n_g65   <- sum(dt_pref$g65)
n_pharm <- sum(dt_pref$g65 == 1 & dt_pref$pharma == 1)
n_nonph <- sum(dt_pref$g65 == 1 & dt_pref$pharma == 0)
cat("  valid lpreco_ref rows:", format(nrow(dt_pref), big.mark=","), "\n")
cat(sprintf("  Group 65: %s total = %s pharma + %s non-pharma\n",
            format(n_g65, big.mark=","),
            format(n_pharm, big.mark=","),
            format(n_nonph, big.mark=",")))
cat("  control groups (g65=0):", uniqueN(dt_pref[g65 == 0, codigogrupo]), "\n")

# ---- Subsamples (mirror 24_pharma.R) ----------------------------------
# NP sample: controls + (g65=1 & pharma=0)
# PH sample: controls + (g65=1 & pharma=1)
dt_np <- dt_pref[g65 == 0L | (g65 == 1L & pharma == 0L)]
dt_ph <- dt_pref[g65 == 0L | (g65 == 1L & pharma == 1L)]
cat(sprintf("  NP subsample: %s rows; PH subsample: %s rows\n",
            format(nrow(dt_np), big.mark=","),
            format(nrow(dt_ph), big.mark=",")))

# ============================================================================
# Helper functions
# ============================================================================

run_twfe <- function(data, dv) {
  m <- feols(as.formula(paste0(dv, " ~ g65_pre + convite + lquantidade",
                               " | item_alt + data_oc_numb")),
             data = data, cluster = ~item_alt, fixef.rm = "none")
  list(est = as.numeric(coef(m)["g65_pre"]),
       se  = as.numeric(sqrt(vcov(m)["g65_pre","g65_pre"])),
       n   = nobs(m))
}

run_event_study <- function(data, dv) {
  data <- copy(data)
  data[, evt := data_oc_numb - TREAT_DATE]
  data[, evt_cap := pmax(pmin(evt, 12L), -12L)]
  m <- feols(as.formula(paste0(dv, " ~ i(evt_cap, g65, ref = -1)",
                               " + convite + lquantidade",
                               " | item_alt + data_oc_numb")),
             data = data, cluster = ~item_alt, fixef.rm = "none")
  cf <- coef(m); se <- sqrt(diag(vcov(m)))
  idx <- grep("^evt_cap::", names(cf))
  d <- data.frame(
    k    = as.integer(sub("^evt_cap::(-?[0-9]+):g65$", "\\1", names(cf)[idx])),
    beta = as.numeric(cf[idx]),
    se   = as.numeric(se[idx])
  )
  d <- rbind(d, data.frame(k = -1L, beta = 0, se = 0))
  d <- d[order(d$k), ]
  d$lo <- d$beta - 1.96 * d$se
  d$hi <- d$beta + 1.96 * d$se
  # Joint F on pre-period
  pre <- grep("^evt_cap::-(1[0-2]|[2-9]):g65$", names(cf), value = TRUE)
  ft <- tryCatch(wald(m, keep = pre, print = FALSE),
                 error = function(e) list(stat = NA, p = NA))
  list(df = d, joint_F = as.numeric(ft$stat), joint_P = as.numeric(ft$p),
       max_abs = max(abs(d$beta)))
}

run_cs <- function(data) {
  # Group-level aggregation for tractability; ensure treat_time is double for did pkg
  dt_grp <- data[, .(y = mean(lpreco_ref, na.rm = TRUE), N = .N),
                 by = .(codigogrupo, data_oc_numb, g65)]
  dt_grp[, treat_time := as.numeric(fifelse(g65 == 1L, TREAT_DATE, 0L))]
  dt_grp[, unit_id := as.integer(factor(codigogrupo))]
  if (uniqueN(dt_grp$codigogrupo) < 5)
    return(list(est = NA_real_, se = NA_real_))
  tryCatch({
    out <- did::att_gt(
      yname = "y", tname = "data_oc_numb", idname = "unit_id",
      gname = "treat_time", data = dt_grp,
      control_group = "nevertreated", panel = FALSE,
      allow_unbalanced_panel = TRUE, bstrap = TRUE, biters = 500
    )
    agg <- did::aggte(out, type = "simple", na.rm = TRUE)
    list(est = as.numeric(agg$overall.att),
         se  = as.numeric(agg$overall.se))
  }, error = function(e) {
    cat("    CS err:", conditionMessage(e), "\n")
    list(est = NA_real_, se = NA_real_)
  })
}

run_bjs <- function(data) {
  d <- copy(data)
  d[, item_int := as.integer(item_alt)]
  d[, treat_time_bjs := as.numeric(fifelse(g65 == 1L, TREAT_DATE, 0))]
  tryCatch({
    out <- didimputation::did_imputation(
      data = d, yname = "lpreco_ref",
      gname = "treat_time_bjs", tname = "data_oc_numb",
      idname = "item_int", horizon = FALSE, pretrends = FALSE,
      cluster_var = "item_int"
    )
    list(est = as.numeric(out$estimate[1]),
         se  = as.numeric(out$std.error[1]))
  }, error = function(e) {
    cat("    BJS err:", conditionMessage(e), "\n")
    list(est = NA_real_, se = NA_real_)
  })
}

run_quartile_het <- function(data, label) {
  ic <- data[, .(mean_pre  = mean(lpreco_ref[Pre == 1], na.rm = TRUE),
                 mean_post = mean(lpreco_ref[Pre == 0], na.rm = TRUE),
                 n_pre     = sum(Pre),
                 n_post    = sum(1 - Pre)),
             by = item_alt]
  ic[, delta := mean_post - mean_pre]
  ic[, abs_delta := abs(delta)]
  iq <- ic[n_pre >= 1 & n_post >= 1 & is.finite(abs_delta)]
  iq[, q := cut(abs_delta,
                breaks = quantile(abs_delta, probs = seq(0, 1, 0.25), na.rm = TRUE),
                labels = 1:4, include.lowest = TRUE)]
  dh <- merge(data, iq[, .(item_alt, q)], by = "item_alt")
  cat(sprintf("    [%s] quartile sample: %s items of %s; obs %s\n",
              label,
              format(nrow(iq), big.mark=","),
              format(uniqueN(data$item_alt), big.mark=","),
              format(nrow(dh), big.mark=",")))
  out <- list()
  for (qi in 1:4) {
    m <- feols(lpreco_final ~ g65_pre + convite + lquantidade
               | item_alt + data_oc_numb,
               data = dh[q == qi], cluster = ~item_alt, fixef.rm = "none")
    out[[paste0("Q", qi)]] <- list(
      est = as.numeric(coef(m)["g65_pre"]),
      se  = as.numeric(sqrt(vcov(m)["g65_pre","g65_pre"])),
      n   = nobs(m)
    )
  }
  out
}

# ============================================================================
# Run all analyses for NP and PH
# ============================================================================

results <- list()

for (label in c("NP", "PH")) {
  data <- if (label == "NP") dt_np else dt_ph
  cat(sprintf("\n--- [%s] %s ---\n", label,
              if (label == "NP") "Non-pharma + controls" else "Pharma + controls"))

  cat("[2/7] TWFE static DiD on lpreco_ref\n")
  twfe <- run_twfe(data, "lpreco_ref")
  cat(sprintf("    δ̂_TWFE = %.4f (SE %.4f), N = %s\n",
              twfe$est, twfe$se, format(twfe$n, big.mark=",")))

  cat("[3/7] Sanity check (same spec on lpreco_final)\n")
  sanity <- run_twfe(data, "lpreco_final")
  cat(sprintf("    δ̂_lpreco_final = %.4f (SE %.4f) — expect ≈ paper's main DiD\n",
              sanity$est, sanity$se))

  cat("[4/7] Event study\n")
  es <- run_event_study(data, "lpreco_ref")
  cat(sprintf("    max |β_k| = %.4f; joint F = %.3f (p = %.4f)\n",
              es$max_abs, es$joint_F, es$joint_P))

  cat("[5/7] CS aggregate ATT (group-level)\n")
  cs <- run_cs(data)
  if (!is.na(cs$est))
    cat(sprintf("    δ̂_CS = %.4f (SE %.4f)\n", cs$est, cs$se))

  cat("[6/7] BJS imputation\n")
  bjs <- run_bjs(data)
  if (!is.na(bjs$est))
    cat(sprintf("    δ̂_BJS = %.4f (SE %.4f)\n", bjs$est, bjs$se))

  cat("[7/7] Heterogeneity by |Δlpreco_ref| quartile (DV: lpreco_final)\n")
  het <- run_quartile_het(data, label)
  for (qi in 1:4)
    cat(sprintf("    Q%d: δ̂_p_final = %.4f (SE %.4f), N = %s\n",
                qi, het[[paste0("Q", qi)]]$est, het[[paste0("Q", qi)]]$se,
                format(het[[paste0("Q", qi)]]$n, big.mark=",")))

  results[[label]] <- list(twfe = twfe, sanity = sanity, es = es,
                           cs = cs, bjs = bjs, het = het)
}

# ============================================================================
# Build event-study figure (two panels NP/PH)
# ============================================================================
cat("\n[OUT] Saving event-study figure (2-panel NP/PH)\n")
es_df <- rbind(
  data.frame(class = "Non-pharmaceutical", results$NP$es$df),
  data.frame(class = "Pharmaceutical",     results$PH$es$df)
)
p <- ggplot(es_df, aes(x = k, y = beta)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "gray40") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.25, color = "gray30") +
  geom_point(size = 1.5, shape = 16, color = "black") +
  scale_x_continuous(breaks = seq(-12, 12, 4)) +
  facet_wrap(~ class, ncol = 1, scales = "free_y") +
  labs(x = "Months relative to cutoff (March 2018)",
       y = expression(hat(beta)[k]~"on"~log(p^{ref})),
       caption = sprintf("NP: F = %.2f (p = %.3f). PH: F = %.2f (p = %.3f). 95%% CIs from item-clustered SEs. Reference k = -1.",
                          results$NP$es$joint_F, results$NP$es$joint_P,
                          results$PH$es$joint_F, results$PH$es$joint_P)) +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        plot.caption = element_text(hjust = 0, size = 8),
        strip.text = element_text(face = "bold"))
ggsave(file.path(V8_FIG, "event_study_log_pref.pdf"),
       p, width = 6.5, height = 6, device = cairo_pdf)
cat("  Saved:", file.path(V8_FIG, "event_study_log_pref.pdf"), "\n")

# ============================================================================
# Macros to values.tex
# ============================================================================
cat("\n[OUT] Appending macros to", V8_VAL, "\n")

f4 <- function(x) ifelse(is.na(x), "NA", sprintf("%.4f", x))
f2 <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f", x))
f3 <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", x))

macros <- c(
  "",
  "% ==========================================================================",
  "% Reference-price endogeneity (script 32_pref_endogeneity.R, NP/PH split)",
  "% Added/refreshed 2026-05-17",
  "% ==========================================================================",
  paste0("\\providecommand{\\pRefDidEstNp}{}\\renewcommand{\\pRefDidEstNp}{", f4(results$NP$twfe$est), "}"),
  paste0("\\providecommand{\\pRefDidSeNp}{}\\renewcommand{\\pRefDidSeNp}{",   f4(results$NP$twfe$se),  "}"),
  paste0("\\providecommand{\\pRefDidObsNp}{}\\renewcommand{\\pRefDidObsNp}{", format(results$NP$twfe$n, big.mark=","), "}"),
  paste0("\\providecommand{\\pRefDidEstPh}{}\\renewcommand{\\pRefDidEstPh}{", f4(results$PH$twfe$est), "}"),
  paste0("\\providecommand{\\pRefDidSePh}{}\\renewcommand{\\pRefDidSePh}{",   f4(results$PH$twfe$se),  "}"),
  paste0("\\providecommand{\\pRefDidObsPh}{}\\renewcommand{\\pRefDidObsPh}{", format(results$PH$twfe$n, big.mark=","), "}"),
  paste0("\\providecommand{\\pRefDidCsEstNp}{}\\renewcommand{\\pRefDidCsEstNp}{", f4(results$NP$cs$est), "}"),
  paste0("\\providecommand{\\pRefDidCsSeNp}{}\\renewcommand{\\pRefDidCsSeNp}{",   f4(results$NP$cs$se),  "}"),
  paste0("\\providecommand{\\pRefDidCsEstPh}{}\\renewcommand{\\pRefDidCsEstPh}{", f4(results$PH$cs$est), "}"),
  paste0("\\providecommand{\\pRefDidCsSePh}{}\\renewcommand{\\pRefDidCsSePh}{",   f4(results$PH$cs$se),  "}"),
  paste0("\\providecommand{\\pRefDidBjsEstNp}{}\\renewcommand{\\pRefDidBjsEstNp}{", f4(results$NP$bjs$est), "}"),
  paste0("\\providecommand{\\pRefDidBjsSeNp}{}\\renewcommand{\\pRefDidBjsSeNp}{",   f4(results$NP$bjs$se),  "}"),
  paste0("\\providecommand{\\pRefDidBjsEstPh}{}\\renewcommand{\\pRefDidBjsEstPh}{", f4(results$PH$bjs$est), "}"),
  paste0("\\providecommand{\\pRefDidBjsSePh}{}\\renewcommand{\\pRefDidBjsSePh}{",   f4(results$PH$bjs$se),  "}"),
  paste0("\\providecommand{\\pRefEventStudyJointFNp}{}\\renewcommand{\\pRefEventStudyJointFNp}{", f2(results$NP$es$joint_F), "}"),
  paste0("\\providecommand{\\pRefEventStudyJointPNp}{}\\renewcommand{\\pRefEventStudyJointPNp}{", f3(results$NP$es$joint_P), "}"),
  paste0("\\providecommand{\\pRefEventStudyJointFPh}{}\\renewcommand{\\pRefEventStudyJointFPh}{", f2(results$PH$es$joint_F), "}"),
  paste0("\\providecommand{\\pRefEventStudyJointPPh}{}\\renewcommand{\\pRefEventStudyJointPPh}{", f3(results$PH$es$joint_P), "}"),
  paste0("\\providecommand{\\pRefEventStudyMaxAbsNp}{}\\renewcommand{\\pRefEventStudyMaxAbsNp}{", f4(results$NP$es$max_abs), "}"),
  paste0("\\providecommand{\\pRefEventStudyMaxAbsPh}{}\\renewcommand{\\pRefEventStudyMaxAbsPh}{", f4(results$PH$es$max_abs), "}"),
  paste0("\\providecommand{\\pRefHetQOneNp}{}\\renewcommand{\\pRefHetQOneNp}{",  f4(results$NP$het$Q1$est), "}"),
  paste0("\\providecommand{\\pRefHetQOneSeNp}{}\\renewcommand{\\pRefHetQOneSeNp}{",f4(results$NP$het$Q1$se), "}"),
  paste0("\\providecommand{\\pRefHetQFourNp}{}\\renewcommand{\\pRefHetQFourNp}{", f4(results$NP$het$Q4$est), "}"),
  paste0("\\providecommand{\\pRefHetQFourSeNp}{}\\renewcommand{\\pRefHetQFourSeNp}{", f4(results$NP$het$Q4$se), "}"),
  paste0("\\providecommand{\\pRefHetQOnePh}{}\\renewcommand{\\pRefHetQOnePh}{",  f4(results$PH$het$Q1$est), "}"),
  paste0("\\providecommand{\\pRefHetQOneSePh}{}\\renewcommand{\\pRefHetQOneSePh}{",f4(results$PH$het$Q1$se), "}"),
  paste0("\\providecommand{\\pRefHetQFourPh}{}\\renewcommand{\\pRefHetQFourPh}{", f4(results$PH$het$Q4$est), "}"),
  paste0("\\providecommand{\\pRefHetQFourSePh}{}\\renewcommand{\\pRefHetQFourSePh}{", f4(results$PH$het$Q4$se), "}"),
  ""
)

# Strip any previous version block before appending
existing <- if (file.exists(V8_VAL)) readLines(V8_VAL) else character()
hdr <- "% Reference-price endogeneity"
start_idx <- grep(hdr, existing, fixed = TRUE)
if (length(start_idx) > 0) {
  # Drop from the first hit's section header (% ===) to end-of-block (next blank line after macros)
  start <- max(1L, start_idx[1] - 2L)  # back up to opening "% ===" line
  existing <- existing[1:(start - 1L)]
}
writeLines(c(existing, macros), V8_VAL)
cat("  Wrote", length(macros), "lines\n")

# ============================================================================
# Summary table
# ============================================================================
cat("\n========================== SUMMARY ==========================\n")
cat(sprintf("                          NP                    PH\n"))
cat(sprintf("TWFE δ̂_p_ref     %s (%s)     %s (%s)\n",
            f4(results$NP$twfe$est), f4(results$NP$twfe$se),
            f4(results$PH$twfe$est), f4(results$PH$twfe$se)))
cat(sprintf("CS   δ̂_p_ref     %s (%s)     %s (%s)\n",
            f4(results$NP$cs$est), f4(results$NP$cs$se),
            f4(results$PH$cs$est), f4(results$PH$cs$se)))
cat(sprintf("BJS  δ̂_p_ref     %s (%s)     %s (%s)\n",
            f4(results$NP$bjs$est), f4(results$NP$bjs$se),
            f4(results$PH$bjs$est), f4(results$PH$bjs$se)))
cat(sprintf("Sanity p_final   %s (%s)     %s (%s)\n",
            f4(results$NP$sanity$est), f4(results$NP$sanity$se),
            f4(results$PH$sanity$est), f4(results$PH$sanity$se)))
cat(sprintf("ES max |β_k|     %s                       %s\n",
            f4(results$NP$es$max_abs), f4(results$PH$es$max_abs)))
cat(sprintf("Joint F pre-tr   %s (p=%s)             %s (p=%s)\n",
            f2(results$NP$es$joint_F), f3(results$NP$es$joint_P),
            f2(results$PH$es$joint_F), f3(results$PH$es$joint_P)))
cat(sprintf("Het Q1→Q4        %s → %s        %s → %s\n",
            f4(results$NP$het$Q1$est), f4(results$NP$het$Q4$est),
            f4(results$PH$het$Q1$est), f4(results$PH$het$Q4$est)))
cat("==============================================================\n")
