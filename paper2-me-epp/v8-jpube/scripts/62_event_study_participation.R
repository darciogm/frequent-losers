# 62_event_study_participation.R --------------------------------------
# First-stage participation event study, non-pharmaceutical Group 65.
# Outcomes: SME bidders per auction (me_ph2 + epp_ph2) and non-SME bidders
# per auction (oth_ph2), the iterative price-forming phase. This is the
# mechanism the structural decomposition rests on: the set-aside recomposes
# the bidder pool. Mirrors the run_es machinery of script 34 (item + month
# FE, item-clustered SE, evt_cap +/-12, ref = -1).
#
# Rationale (audit M3 follow-up, 2026-06-07): the log(p_final) and
# log(b^(2)) event studies are visually noisy with no clean break at the
# cutoff and rejected pre-trends -- promoting either to Figure 1 would
# contradict the paper's own conservative reading of the reduced form. The
# participation first stage is mechanical, visible, and is the object the
# structural decomposition actually uses. This script builds it for
# inspection before any promotion decision.
#
# Outputs:
#   v8-jpube/output/figures/event_study_participation.pdf
#   v8-jpube/output/values_es_participation.tex
#   v8-jpube/output/62_event_study_participation.log
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(arrow); library(ggplot2)
})

ROOT      <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
DATA_PARQ <- file.path(ROOT, "data/processed/paper2_me_epp.parquet")
V8_FIG    <- file.path(ROOT, "v8-jpube/output/figures")
V8_OUT    <- file.path(ROOT, "v8-jpube/output")
stopifnot(file.exists(DATA_PARQ))

logf <- file(file.path(V8_OUT, "62_event_study_participation.log"), open = "wt")
logln <- function(...) { line <- sprintf(...); message(line); writeLines(line, logf); flush(logf) }

TREAT_DATE   <- 698L
WIN_18M      <- c(680L, 715L)
PHARMA_CLASS <- 6531L

NCORES <- min(parallel::detectCores(logical = FALSE), 12L)
setFixest_nthreads(NCORES); setDTthreads(NCORES); setFixest_estimation(lean = TRUE)
set.seed(42)

logln("[62] host=%s cores=%d | participation event study, NP Group 65",
      Sys.info()[["nodename"]], NCORES)

dt <- as.data.table(read_parquet(DATA_PARQ))
dt <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
dt[, g65 := as.integer(codigogrupo == "65")]
dt[, pharma := as.integer(!is.na(class_alt) & class_alt == PHARMA_CLASS)]

# Participation counts in the iterative (price-forming) phase 2.
zna <- function(x) fifelse(is.na(x), 0, as.numeric(x))
dt[, n_sme    := zna(numfornecs_type_me_ph2) + zna(numfornecs_type_epp_ph2)]
dt[, n_nonsme := zna(numfornecs_type_oth_ph2)]
dt[, item_alt := factor(item_alt)]

# One row per oc-item: counts are item-auction attributes repeated across
# bid rows. Collapse to unique auctions to avoid weighting by bidder count.
au <- unique(dt[, .(item_alt, data_oc_numb, g65, pharma, convite,
                    lquantidade, n_sme, n_nonsme)])
logln("[62] auction-level rows in window: %s", format(nrow(au), big.mark = ","))

# Non-pharma sample: controls + g65 non-pharma.
np <- au[g65 == 0L | (g65 == 1L & pharma == 0L)]
logln("[62] NP sample: %s (g65 NP = %s, controls = %s)",
      format(nrow(np), big.mark = ","),
      format(sum(np$g65 == 1), big.mark = ","),
      format(sum(np$g65 == 0), big.mark = ","))

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
    k = as.integer(sub("^evt_cap::(-?[0-9]+):g65$", "\\1", names(cf)[idx])),
    beta = as.numeric(cf[idx]), se = as.numeric(se[idx]), label = label)
  d <- rbind(d, data.frame(k = -1L, beta = 0, se = 0, label = label))
  d <- d[order(d$k), ]
  d$lo <- d$beta - 1.96 * d$se; d$hi <- d$beta + 1.96 * d$se
  pre <- grep("^evt_cap::-(1[0-2]|[2-9]):g65$", names(cf), value = TRUE)
  ft <- tryCatch(wald(m, keep = pre, print = FALSE),
                 error = function(e) list(stat = NA, p = NA))
  list(df = d, joint_F = as.numeric(ft$stat), joint_P = as.numeric(ft$p),
       max_abs_pre = max(abs(d$beta[d$k < -1])),
       post_mean = mean(d$beta[d$k >= 0]))
}

es_sme <- run_es(np, "n_sme",    "SME bidders per auction")
es_ns  <- run_es(np, "n_nonsme", "Non-SME bidders per auction")
logln("[62] SME:     pre F = %.2f (p=%.3f) | max|b_pre| = %.3f | post mean = %+.3f",
      es_sme$joint_F, es_sme$joint_P, es_sme$max_abs_pre, es_sme$post_mean)
logln("[62] non-SME: pre F = %.2f (p=%.3f) | max|b_pre| = %.3f | post mean = %+.3f",
      es_ns$joint_F, es_ns$joint_P, es_ns$max_abs_pre, es_ns$post_mean)

es_combined <- rbind(es_sme$df, es_ns$df)
es_combined$label <- factor(es_combined$label,
  levels = c("SME bidders per auction", "Non-SME bidders per auction"))
p <- ggplot(es_combined, aes(x = k, y = beta)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "gray40") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.25, color = "gray30") +
  geom_point(size = 1.5, color = "black") +
  scale_x_continuous(breaks = seq(-12, 12, 4)) +
  facet_wrap(~ label, ncol = 1, scales = "free_y") +
  labs(x = "Months relative to cutoff (March 2018)",
       y = expression(hat(beta)[k]~", Group 65"~symbol('\264')~"event month"),
       caption = sprintf(paste0("First-stage participation, non-pharmaceutical Group 65. ",
                                "SME pre-trend F = %.2f (p = %.3f); non-SME pre-trend F = %.2f (p = %.3f). ",
                                "95%% CIs from item-clustered SEs. Reference k = -1."),
                         es_sme$joint_F, es_sme$joint_P, es_ns$joint_F, es_ns$joint_P)) +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        plot.caption = element_text(hjust = 0, size = 8),
        strip.text = element_text(face = "bold"))
ggsave(file.path(V8_FIG, "event_study_participation.pdf"),
       p, width = 6.5, height = 6, device = cairo_pdf)
logln("[62] saved event_study_participation.pdf")

f2 <- function(x) sprintf("%.2f", x); f3 <- function(x) sprintf("%.3f", x)
writeLines(c(
  "%% First-stage participation event study, NP Group 65 (Figure 1)",
  "%% script v8-jpube/scripts/62_event_study_participation.R 2026-06-07",
  sprintf("\\providecommand{\\esPartSmePreFNp}{}\\renewcommand{\\esPartSmePreFNp}{%s}", f2(es_sme$joint_F)),
  sprintf("\\providecommand{\\esPartSmePrePNp}{}\\renewcommand{\\esPartSmePrePNp}{%s}", f3(es_sme$joint_P)),
  sprintf("\\providecommand{\\esPartNsPreFNp}{}\\renewcommand{\\esPartNsPreFNp}{%s}",  f2(es_ns$joint_F)),
  sprintf("\\providecommand{\\esPartNsPrePNp}{}\\renewcommand{\\esPartNsPrePNp}{%s}",  f3(es_ns$joint_P))
), file.path(V8_OUT, "values_es_participation.tex"))
logln("[62] done")
close(logf)
