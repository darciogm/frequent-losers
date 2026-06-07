# 61_event_study_pfinal.R ---------------------------------------------
# Event study on log(p_final), the headline reduced-form outcome reported
# in Table 2 (tab_did_benchmark_v8). Mirrors the ES machinery of
# ../scripts/34_second_bid_evidence.R exactly (same window, same FE, same
# clustering, same evt_cap, ref = -1), changing ONLY the dependent
# variable to lpreco_final. Purpose: provide a body-of-paper Figure 1 that
# shows treatment timing and a pre-period that behaves, as the audit
# (M3, 2026-06-07) requires for a DiD design.
#
# Decision rule: this figure is promoted to the body ONLY if the pre-period
# joint F does not reject flatness too hard AND the post jump is visible.
# Otherwise we fall back to a participation first-stage figure. The script
# only PRODUCES the figure + pre-trend macros; the promotion call is made
# after visual inspection.
#
# Outputs:
#   v8-jpube/output/figures/event_study_pfinal.pdf
#   v8-jpube/output/values_es_pfinal.tex
#   v8-jpube/output/61_event_study_pfinal.log
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(arrow); library(ggplot2)
})

ROOT      <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
DATA_PARQ <- file.path(ROOT, "data/processed/paper2_me_epp.parquet")
V8_FIG    <- file.path(ROOT, "v8-jpube/output/figures")
V8_OUT    <- file.path(ROOT, "v8-jpube/output")
stopifnot(file.exists(DATA_PARQ))

logf <- file(file.path(V8_OUT, "61_event_study_pfinal.log"), open = "wt")
logln <- function(...) { line <- sprintf(...); message(line); writeLines(line, logf); flush(logf) }

TREAT_DATE   <- 698L
WIN_18M      <- c(680L, 715L)
PHARMA_CLASS <- 6531L

NCORES <- min(parallel::detectCores(logical = FALSE), 12L)
setFixest_nthreads(NCORES); setDTthreads(NCORES); setFixest_estimation(lean = TRUE)
set.seed(42)

logln("[61] host=%s cores=%d | event study on log(p_final), 18m window",
      Sys.info()[["nodename"]], NCORES)

# ---- Load and prep (identical to script 34) --------------------------
dt <- as.data.table(read_parquet(DATA_PARQ))
dt <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
dt[, g65 := as.integer(codigogrupo == "65")]
dt[, Pre := as.integer(data_oc_numb < TREAT_DATE)]
dt[, pharma := as.integer(!is.na(class_alt) & class_alt == PHARMA_CLASS)]
dt[, item_alt := factor(item_alt)]

dt_pf <- dt[!is.na(lpreco_final) & is.finite(lpreco_final)]
logln("[61] rows in window: %s | valid lpreco_final: %s (%.1f%%)",
      format(nrow(dt), big.mark = ","),
      format(nrow(dt_pf), big.mark = ","), 100 * nrow(dt_pf) / nrow(dt))

dt_np <- dt_pf[g65 == 0L | (g65 == 1L & pharma == 0L)]
dt_ph <- dt_pf[g65 == 0L | (g65 == 1L & pharma == 1L)]

# ---- Event-study estimator (verbatim from script 34) -----------------
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
    label = label)
  d <- rbind(d, data.frame(k = -1L, beta = 0, se = 0, label = label))
  d <- d[order(d$k), ]
  d$lo <- d$beta - 1.96 * d$se
  d$hi <- d$beta + 1.96 * d$se
  pre <- grep("^evt_cap::-(1[0-2]|[2-9]):g65$", names(cf), value = TRUE)
  ft <- tryCatch(wald(m, keep = pre, print = FALSE),
                 error = function(e) list(stat = NA, p = NA))
  # Post-period average (k>=0) as the visible-jump summary.
  post_idx <- d$k >= 0
  list(df = d, joint_F = as.numeric(ft$stat), joint_P = as.numeric(ft$p),
       max_abs_pre = max(abs(d$beta[d$k < -1])),
       post_mean = mean(d$beta[post_idx]))
}

es_np <- run_es(dt_np, "lpreco_final", "Non-pharmaceutical")
es_ph <- run_es(dt_ph, "lpreco_final", "Pharmaceutical")
logln("[61] NP: pre joint F = %.2f (p=%.3f) | max|beta_pre| = %.4f | post mean = %.4f",
      es_np$joint_F, es_np$joint_P, es_np$max_abs_pre, es_np$post_mean)
logln("[61] PH: pre joint F = %.2f (p=%.3f) | max|beta_pre| = %.4f | post mean = %.4f",
      es_ph$joint_F, es_ph$joint_P, es_ph$max_abs_pre, es_ph$post_mean)

# ---- Figure (same style as script 34) --------------------------------
es_combined <- rbind(es_np$df, es_ph$df)
es_combined$label <- factor(es_combined$label,
                            levels = c("Non-pharmaceutical", "Pharmaceutical"))
p <- ggplot(es_combined, aes(x = k, y = beta)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "gray40") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.25, color = "gray30") +
  geom_point(size = 1.5, color = "black") +
  scale_x_continuous(breaks = seq(-12, 12, 4)) +
  facet_wrap(~ label, ncol = 1, scales = "free_y") +
  labs(x = "Months relative to cutoff (March 2018)",
       y = expression(hat(beta)[k]~"on"~log(p^{final})),
       caption = sprintf(paste0("Event study of the headline DiD on log final price. ",
                                 "NP pre-trend F = %.2f (p = %.3f); PH pre-trend F = %.2f (p = %.3f). ",
                                 "95%% CIs from item-clustered SEs. Reference k = -1."),
                         es_np$joint_F, es_np$joint_P, es_ph$joint_F, es_ph$joint_P)) +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        plot.caption = element_text(hjust = 0, size = 8),
        strip.text = element_text(face = "bold"))
ggsave(file.path(V8_FIG, "event_study_pfinal.pdf"),
       p, width = 6.5, height = 6, device = cairo_pdf)
logln("[61] saved event_study_pfinal.pdf")

# ---- Macros ----------------------------------------------------------
f2 <- function(x) sprintf("%.2f", x); f3 <- function(x) sprintf("%.3f", x)
writeLines(c(
  "%% Event study on log(p_final), headline DiD outcome (Figure 1)",
  "%% script v8-jpube/scripts/61_event_study_pfinal.R 2026-06-07",
  sprintf("\\providecommand{\\esPfinalPreFNp}{}\\renewcommand{\\esPfinalPreFNp}{%s}", f2(es_np$joint_F)),
  sprintf("\\providecommand{\\esPfinalPrePNp}{}\\renewcommand{\\esPfinalPrePNp}{%s}", f3(es_np$joint_P)),
  sprintf("\\providecommand{\\esPfinalPreFPh}{}\\renewcommand{\\esPfinalPreFPh}{%s}", f2(es_ph$joint_F)),
  sprintf("\\providecommand{\\esPfinalPrePPh}{}\\renewcommand{\\esPfinalPrePPh}{%s}", f3(es_ph$joint_P))
), file.path(V8_OUT, "values_es_pfinal.tex"))
logln("[61] done")
close(logf)
