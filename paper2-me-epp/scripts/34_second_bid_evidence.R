# ============================================================================
# Paper 2 — Second-lowest bid evidence (price-formation mechanism, reduced-form)
# DiD on log(second_bid_ph1) mirrors the main DiD spec. Identifies the order-
# statistic effect that the structural decomposition predicts, in raw bid
# units WITHOUT p^ref normalization. Independent of reference-price endogeneity.
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(arrow); library(ggplot2)
})

PROJ_ROOT <- getwd()
DATA_PARQ <- file.path(PROJ_ROOT, "data/processed/paper2_me_epp.parquet")
stopifnot(file.exists(DATA_PARQ))
V8_VAL <- file.path(PROJ_ROOT, "v8-jpube/output/values.tex")
V8_FIG <- file.path(PROJ_ROOT, "v8-jpube/output/figures")
dir.create(V8_FIG, recursive = TRUE, showWarnings = FALSE)

TREAT_DATE <- 698L
WIN_18M <- c(680L, 715L)
PHARMA_CLASS <- 6531L

NCORES <- min(parallel::detectCores(logical = FALSE), 12L)
setFixest_nthreads(NCORES); setDTthreads(NCORES); setFixest_estimation(lean = TRUE)
set.seed(42)

cat("=== Second-lowest bid DiD (price-formation reduced form) ===\n\n")

# ---- Load and prep ---------------------------------------------------------
dt <- as.data.table(read_parquet(DATA_PARQ))
dt <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
dt[, g65 := as.integer(codigogrupo == "65")]
dt[, Pre := as.integer(data_oc_numb < TREAT_DATE)]
dt[, g65_pre := g65 * Pre]
dt[, pharma := as.integer(!is.na(class_alt) & class_alt == PHARMA_CLASS)]
dt[, item_alt := factor(item_alt)]
dt[, pbu_alt  := factor(pbu_alt)]

# second_bid_ph2: second-lowest bid in iterative phase 2 (where firms exit).
# ph1 is sealed-bid (all zeros in this period); ph2 is the price-forming phase.
# Sample restricted to auctions where ph2 actually occurred (≥2 bidders).
dt[, lsecond_bid := fifelse(!is.na(second_bid_ph2) & second_bid_ph2 > 0,
                             log(second_bid_ph2), NA_real_)]

cat("Sample composition:\n")
cat(sprintf("  Total rows in 18m window:       %s\n", format(nrow(dt), big.mark=",")))
cat(sprintf("  Rows with valid second_bid_ph2: %s (%.1f%%)\n",
            format(sum(!is.na(dt$lsecond_bid)), big.mark=","),
            100*mean(!is.na(dt$lsecond_bid))))
cat(sprintf("  Rows with valid lpreco_final:   %s (%.1f%%)\n",
            format(sum(!is.na(dt$lpreco_final)), big.mark=","),
            100*mean(!is.na(dt$lpreco_final))))

dt_sb <- dt[!is.na(lsecond_bid) & is.finite(lsecond_bid)]
cat(sprintf("\n  Sample with valid log(second_bid): %s\n",
            format(nrow(dt_sb), big.mark=",")))
cat(sprintf("  g65 in sample:  %s (NP=%s, PH=%s)\n",
            format(sum(dt_sb$g65 == 1), big.mark=","),
            format(sum(dt_sb$g65 == 1 & dt_sb$pharma == 0), big.mark=","),
            format(sum(dt_sb$g65 == 1 & dt_sb$pharma == 1), big.mark=",")))
cat(sprintf("  controls:       %s\n", format(sum(dt_sb$g65 == 0), big.mark=",")))

# Subsamples (mirror 24_pharma.R)
dt_np <- dt_sb[g65 == 0L | (g65 == 1L & pharma == 0L)]
dt_ph <- dt_sb[g65 == 0L | (g65 == 1L & pharma == 1L)]

# ============================================================================
# Helper
# ============================================================================
run_did <- function(data, dv) {
  m <- feols(as.formula(paste0(dv, " ~ g65_pre + convite + lquantidade",
                               " | item_alt + data_oc_numb")),
             data = data, cluster = ~item_alt, fixef.rm = "none")
  list(est = as.numeric(coef(m)["g65_pre"]),
       se  = as.numeric(sqrt(vcov(m)["g65_pre","g65_pre"])),
       n   = nobs(m), model = m)
}

# ============================================================================
# Static DiDs
# ============================================================================
cat("\n--- [Pooled] log(second_bid_ph1) DiD ---\n")
m_pooled <- run_did(dt_sb, "lsecond_bid")
cat(sprintf("  δ̂ = %.4f (SE %.4f), N = %s\n",
            m_pooled$est, m_pooled$se, format(m_pooled$n, big.mark=",")))

# Sanity check on lpreco_final in same sample
m_pooled_pf <- run_did(dt_sb, "lpreco_final")
cat(sprintf("  [Sanity p_final, same sample] = %.4f (SE %.4f)\n",
            m_pooled_pf$est, m_pooled_pf$se))

cat("\n--- [Non-pharma] log(second_bid_ph1) DiD ---\n")
m_np <- run_did(dt_np, "lsecond_bid")
m_np_pf <- run_did(dt_np, "lpreco_final")
cat(sprintf("  δ̂ = %.4f (SE %.4f), N = %s\n", m_np$est, m_np$se, format(m_np$n, big.mark=",")))
cat(sprintf("  [Sanity p_final] = %.4f (SE %.4f)\n", m_np_pf$est, m_np_pf$se))

cat("\n--- [Pharma] log(second_bid_ph1) DiD ---\n")
m_ph <- run_did(dt_ph, "lsecond_bid")
m_ph_pf <- run_did(dt_ph, "lpreco_final")
cat(sprintf("  δ̂ = %.4f (SE %.4f), N = %s\n", m_ph$est, m_ph$se, format(m_ph$n, big.mark=",")))
cat(sprintf("  [Sanity p_final] = %.4f (SE %.4f)\n", m_ph_pf$est, m_ph_pf$se))

# ============================================================================
# Event studies (second_bid_ph1)
# ============================================================================
run_es <- function(data, dv, label) {
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
    se   = as.numeric(se[idx]),
    label = label
  )
  d <- rbind(d, data.frame(k = -1L, beta = 0, se = 0, label = label))
  d <- d[order(d$k), ]
  d$lo <- d$beta - 1.96 * d$se
  d$hi <- d$beta + 1.96 * d$se
  pre <- grep("^evt_cap::-(1[0-2]|[2-9]):g65$", names(cf), value = TRUE)
  ft <- tryCatch(wald(m, keep = pre, print = FALSE),
                 error = function(e) list(stat = NA, p = NA))
  list(df = d, joint_F = as.numeric(ft$stat), joint_P = as.numeric(ft$p),
       max_abs = max(abs(d$beta)))
}

cat("\n--- Event studies on log(second_bid_ph1) ---\n")
es_np <- run_es(dt_np, "lsecond_bid", "Non-pharmaceutical")
es_ph <- run_es(dt_ph, "lsecond_bid", "Pharmaceutical")
cat(sprintf("  NP: max |β_k| = %.4f; joint F (pre) = %.2f (p=%.3f)\n",
            es_np$max_abs, es_np$joint_F, es_np$joint_P))
cat(sprintf("  PH: max |β_k| = %.4f; joint F (pre) = %.2f (p=%.3f)\n",
            es_ph$max_abs, es_ph$joint_F, es_ph$joint_P))

# ============================================================================
# Figure: 2-panel event study (second_bid)
# ============================================================================
cat("\n[OUT] Saving event-study figure (second_bid, NP/PH)\n")
es_combined <- rbind(es_np$df, es_ph$df)
p <- ggplot(es_combined, aes(x = k, y = beta)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "gray40") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.25, color = "gray30") +
  geom_point(size = 1.5, color = "black") +
  scale_x_continuous(breaks = seq(-12, 12, 4)) +
  facet_wrap(~ label, ncol = 1, scales = "free_y") +
  labs(x = "Months relative to cutoff (March 2018)",
       y = expression(hat(beta)[k]~"on"~log(b^{(2)})),
       caption = sprintf("Second-lowest bid event study. NP: F = %.2f (p = %.3f). PH: F = %.2f (p = %.3f). 95%% CIs from item-clustered SEs. Reference k = -1.",
                          es_np$joint_F, es_np$joint_P, es_ph$joint_F, es_ph$joint_P)) +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        plot.caption = element_text(hjust = 0, size = 8),
        strip.text = element_text(face = "bold"))
ggsave(file.path(V8_FIG, "event_study_second_bid.pdf"),
       p, width = 6.5, height = 6, device = cairo_pdf)
cat("  Saved\n")

# ============================================================================
# Macros to values.tex
# ============================================================================
cat("\n[OUT] Appending bid-evidence macros to", V8_VAL, "\n")
f4 <- function(x) sprintf("%.4f", x)
f2 <- function(x) sprintf("%.2f", x)
f3 <- function(x) sprintf("%.3f", x)

macros <- c(
  "",
  "% ==========================================================================",
  "% Second-lowest bid DiD (script 34_second_bid_evidence.R, 2026-05-17)",
  "% Identifies order-statistic mechanism in raw bid units; no p^ref involved.",
  "% ==========================================================================",
  paste0("\\providecommand{\\bidSecondDidEst}{}\\renewcommand{\\bidSecondDidEst}{",   f4(m_pooled$est), "}"),
  paste0("\\providecommand{\\bidSecondDidSe}{}\\renewcommand{\\bidSecondDidSe}{",     f4(m_pooled$se),  "}"),
  paste0("\\providecommand{\\bidSecondDidObs}{}\\renewcommand{\\bidSecondDidObs}{",   format(m_pooled$n, big.mark=","), "}"),
  paste0("\\providecommand{\\bidSecondDidEstNp}{}\\renewcommand{\\bidSecondDidEstNp}{", f4(m_np$est), "}"),
  paste0("\\providecommand{\\bidSecondDidSeNp}{}\\renewcommand{\\bidSecondDidSeNp}{",   f4(m_np$se),  "}"),
  paste0("\\providecommand{\\bidSecondDidObsNp}{}\\renewcommand{\\bidSecondDidObsNp}{", format(m_np$n, big.mark=","), "}"),
  paste0("\\providecommand{\\bidSecondDidEstPh}{}\\renewcommand{\\bidSecondDidEstPh}{", f4(m_ph$est), "}"),
  paste0("\\providecommand{\\bidSecondDidSePh}{}\\renewcommand{\\bidSecondDidSePh}{",   f4(m_ph$se),  "}"),
  paste0("\\providecommand{\\bidSecondDidObsPh}{}\\renewcommand{\\bidSecondDidObsPh}{", format(m_ph$n, big.mark=","), "}"),
  paste0("\\providecommand{\\bidSecondEsJointFNp}{}\\renewcommand{\\bidSecondEsJointFNp}{", f2(es_np$joint_F), "}"),
  paste0("\\providecommand{\\bidSecondEsJointPNp}{}\\renewcommand{\\bidSecondEsJointPNp}{", f3(es_np$joint_P), "}"),
  paste0("\\providecommand{\\bidSecondEsJointFPh}{}\\renewcommand{\\bidSecondEsJointFPh}{", f2(es_ph$joint_F), "}"),
  paste0("\\providecommand{\\bidSecondEsJointPPh}{}\\renewcommand{\\bidSecondEsJointPPh}{", f3(es_ph$joint_P), "}"),
  ""
)

existing <- if (file.exists(V8_VAL)) readLines(V8_VAL) else character()
# Strip any prior version of this block
hdr <- "% Second-lowest bid DiD"
start_idx <- grep(hdr, existing, fixed = TRUE)
if (length(start_idx) > 0) {
  start <- max(1L, start_idx[1] - 2L)
  existing <- existing[1:(start - 1L)]
}
writeLines(c(existing, macros), V8_VAL)
cat("  Wrote", length(macros), "lines\n")

# ============================================================================
# Summary
# ============================================================================
cat("\n========== SUMMARY: second_bid_ph1 DiD ==========\n")
cat(sprintf("                                  δ̂            SE           N\n"))
cat(sprintf("  Pooled  log(second_bid_ph1)   %s   %s   %s\n",
            f4(m_pooled$est), f4(m_pooled$se), format(m_pooled$n, big.mark=",")))
cat(sprintf("  Pooled  log(p_final) sanity   %s   %s   %s\n",
            f4(m_pooled_pf$est), f4(m_pooled_pf$se), format(m_pooled_pf$n, big.mark=",")))
cat(sprintf("  NP      log(second_bid_ph1)   %s   %s   %s\n",
            f4(m_np$est), f4(m_np$se), format(m_np$n, big.mark=",")))
cat(sprintf("  NP      log(p_final) sanity   %s   %s   %s\n",
            f4(m_np_pf$est), f4(m_np_pf$se), format(m_np_pf$n, big.mark=",")))
cat(sprintf("  PH      log(second_bid_ph1)   %s   %s   %s\n",
            f4(m_ph$est), f4(m_ph$se), format(m_ph$n, big.mark=",")))
cat(sprintf("  PH      log(p_final) sanity   %s   %s   %s\n",
            f4(m_ph_pf$est), f4(m_ph_pf$se), format(m_ph_pf$n, big.mark=",")))
cat(sprintf("  ES NP joint F (pre): %s (p=%s)   max |β_k|: %s\n",
            f2(es_np$joint_F), f3(es_np$joint_P), f4(es_np$max_abs)))
cat(sprintf("  ES PH joint F (pre): %s (p=%s)   max |β_k|: %s\n",
            f2(es_ph$joint_F), f3(es_ph$joint_P), f4(es_ph$max_abs)))
cat("===================================================\n")
