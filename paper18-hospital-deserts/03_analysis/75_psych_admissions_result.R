#!/usr/bin/env Rscript
# 75_psych_admissions_result.R
#
# Featured first stage: inpatient psychiatric admissions (DIAG_PRINC F00-F99, by
# residence municipality, any hospital) collapse after a PNASH psychiatric closure.
# Estimated as a Poisson (fepois) count event study on n_psych_adm with muni + year
# fixed effects -- the "dose" the mortality null is set against (a net reduction in
# inpatient psychiatric care received, not redistribution across hospitals, since the
# outcome counts admissions anywhere).
#
# Why count, not the per-capita rate: psych_adm_per1k divides by municipal population,
# whose pre-2015 values are interpolated / back-extrapolated (SIDRA t6579, see D1/D4).
# That extrapolated denominator injects a spurious downward pre-trend into the RATE
# that is absent from the admission COUNTS. The Poisson count event study has an
# economically flat pre-period (|pre coefs| ~ a few percent) and a sharp post-closure
# drop; it is the correct model for an admission count and is immune to the pre-2015
# denominator. The rate spec is retained only as a denominator-sensitive robustness.
#
# HonestDiD (relative-magnitudes + smoothness, mirroring script 84) bounds the effect
# against the small residual pre-period deviation.
#
# Outputs:
#   02_data/processed/psych_admissions_result.csv  (ATT %, CI, pre-trend, HonestDiD)
#   04_figures/fig_es_psych_adm.pdf                 (body event-study, % scale)
#
# Usage: Rscript 03_analysis/75_psych_admissions_result.R [--force]

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2); library(HonestDiD)
})
setFixest_nthreads(4); setDTthreads(4)

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
FIG   <- file.path(ROOT, "04_figures")
LOGF  <- file.path(ROOT, "04_logs", "75_psych_admissions_result.log")

force <- "--force" %in% commandArgs(TRUE)
OUT_CSV <- file.path(PROC, "psych_admissions_result.csv")
OUT_FIG <- file.path(FIG, "fig_es_psych_adm.pdf")
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOGF, append = TRUE) }
cat(sprintf("==== 75_psych_admissions_result %s ====\n", Sys.time()), file = LOGF)
if (file.exists(OUT_CSV) && file.exists(OUT_FIG) && !force) { say("outputs exist, skipping (use --force)"); quit(save = "no") }

OK <- "#0072B2"; GREY <- "gray55"
PRE_LO <- -6L; POST_HI <- 5L; M_GRID <- c(0, 0.5, 1.0, 1.5, 2.0)

P  <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
po <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
d  <- merge(P[, .(codmun_6, year, g_emb, pop, muni_id, suicide_per100k)],
            po[, .(codmun_6, year, n_psych_adm)], by = c("codmun_6", "year"), all.x = TRUE)
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
d[, rel := year - gn]

# sanity: mortality path is untouched -- suicide ATT must still reproduce +0.28
sv <- d[is.finite(suicide_per100k) & is.finite(pop) & pop > 0]
ms <- feols(suicide_per100k ~ sunab(gn, year) | muni_id + year, sv, cluster = "muni_id", weights = ~pop)
suic_att <- as.numeric(coef(summary(ms, agg = "att"))[1])
say("VALIDATION suicide ATT = %.4f (target ~ +0.28; mortality unchanged)", suic_att)
stopifnot(abs(suic_att - 0.28) < 0.05)

# ---- Poisson count first stage (no offset: muni FE absorbs size, year FE the national trend) ----
dd <- d[is.finite(n_psych_adm)]
m  <- fepois(n_psych_adm ~ sunab(gn, year) | muni_id + year, dd, cluster = "muni_id")
agg <- summary(m, agg = "att")
att_log <- as.numeric(coef(agg)[1]); se_log <- as.numeric(se(agg)[1])
pct    <- 100 * (exp(att_log) - 1)
ci_lo  <- 100 * (exp(att_log - 1.96 * se_log) - 1)
ci_hi  <- 100 * (exp(att_log + 1.96 * se_log) - 1)

# event-study coefficients (log scale)
cf <- coef(m); vc <- vcov(m); nm <- names(cf); ev <- grepl("^year::", nm)
e_all <- as.integer(sub("year::", "", nm[ev])); idx_all <- which(ev)
ord <- order(e_all); e_all <- e_all[ord]; idx_all <- idx_all[ord]
es <- data.table(e = e_all, b = cf[idx_all], se = sqrt(diag(vc))[idx_all])
es[, pct := 100 * (exp(b) - 1)]

impact_pct <- es[e == 0, pct]
stable_pct <- es[e >= 3 & e <= 5, mean(pct)]

# pre-trend: covariance-aware joint Wald on pre coefs in [PRE_LO, -2]
pre <- es[e <= -2 & e >= PRE_LO]
ipre <- idx_all[match(pre$e, e_all)]
Wpre <- as.numeric(t(cf[ipre]) %*% solve(vc[ipre, ipre]) %*% cf[ipre])
pre_p <- 1 - pchisq(Wpre, length(ipre))
max_pre_dev_pct <- max(abs(pre$pct))

# descriptive baseline rate per 1,000 from CLEAN canonical pop (2015+ only)
bsrc <- merge(d[gn < 10000 & year < gn & year >= 2015, .(codmun_6, year, pop, gn)],
              po[, .(codmun_6, year, n_psych_adm)], by = c("codmun_6", "year"))
base_rate <- bsrc[is.finite(pop) & pop > 0, 1e3 * sum(n_psych_adm) / sum(pop)]

say("psych_adm (Poisson count) ATT = %.1f%%  CI [%.1f%%, %.1f%%]  (log %.3f, se %.3f)",
    pct, ci_lo, ci_hi, att_log, se_log)
say("  impact (e=0) = %.1f%% ; stabilized (e=3..5) = %.1f%%", impact_pct, stable_pct)
say("  pre-trend p = %.3f ; largest pre-period deviation = %.1f%% ; baseline = %.1f per 1,000 (2015+)",
    pre_p, max_pre_dev_pct, base_rate)

# ---- HonestDiD: window, l_vec reproducing agg='att' (unweighted treated-obs shares) ----
keep <- which(e_all >= PRE_LO & e_all <= POST_HI & e_all != -1L)
ek <- e_all[keep]; ik <- idx_all[keep]
betahat <- cf[ik]; sigma <- vc[ik, ik]
num_pre <- sum(ek < 0); num_post <- sum(ek >= 0); post_e <- ek[ek >= 0]
post_pos <- (num_pre + 1):(num_pre + num_post)
wtab <- dd[gn < 10000 & rel %in% post_e, .(W = .N), by = rel]
l_vec <- as.numeric(setNames(wtab$W, as.character(wtab$rel))[as.character(post_e)]); l_vec <- l_vec / sum(l_vec)
repro <- as.numeric(l_vec %*% betahat[post_pos])
say("HonestDiD: window e=[%s], num_pre=%d num_post=%d, l_vec-reproduced ATT(log)=%.4f (head %.4f)",
    paste(range(ek), collapse = ","), num_pre, num_post, repro, att_log)

hd <- function(kind) rbindlist(lapply(M_GRID, function(M) {
  if (M == 0) { bt <- as.numeric(l_vec %*% betahat[post_pos])
    st <- as.numeric(sqrt(t(l_vec) %*% sigma[post_pos, post_pos] %*% l_vec))
    return(data.table(kind = kind, M = 0, lb = bt - 1.96 * st, ub = bt + 1.96 * st)) }
  r <- tryCatch(
    if (kind == "RM") HonestDiD::createSensitivityResults_relativeMagnitudes(
        betahat = betahat, sigma = sigma, numPrePeriods = num_pre, numPostPeriods = num_post,
        l_vec = l_vec, Mbarvec = c(M), gridPoints = 300)
    else HonestDiD::createSensitivityResults(
        betahat = betahat, sigma = sigma, numPrePeriods = num_pre, numPostPeriods = num_post,
        l_vec = l_vec, Mvec = c(M)),
    error = function(e) NULL)
  if (is.null(r)) data.table(kind = kind, M = M, lb = NA_real_, ub = NA_real_)
  else data.table(kind = kind, M = M, lb = r$lb[1], ub = r$ub[1])
}))
sens <- rbind(hd("RM"), hd("SD"))
sens[, `:=`(lb_pct = 100 * (exp(lb) - 1), ub_pct = 100 * (exp(ub) - 1))]
say("HonestDiD sensitivity (log-scale bounds -> %% effect):"); for (i in seq_len(nrow(sens)))
  say("  [%s M=%.1f] effect in [%.1f%%, %.1f%%]", sens$kind[i], sens$M[i], sens$lb_pct[i], sens$ub_pct[i])
# breakdown M: largest M whose robust UB still excludes 0 (effect stays negative)
bd <- function(k) { s <- sens[kind == k & M > 0 & is.finite(ub)]; s <- s[ub < 0]; if (nrow(s)) max(s$M) else 0 }
rm_bd <- bd("RM"); sd_bd <- bd("SD")
say("breakdown M: RM=%.1f  SD=%.1f (largest M with robust UB < 0)", rm_bd, sd_bd)

fwrite(data.table(
  outcome = "psych_adm_count", spec = "poisson_fepois",
  att_log = att_log, se_log = se_log, pct = pct, ci_lo = ci_lo, ci_hi = ci_hi,
  impact_pct = impact_pct, stable_pct = stable_pct,
  pretrend_p = pre_p, max_pre_dev_pct = max_pre_dev_pct, base = base_rate,
  pct_of_base = pct, honest_rm_breakdown_M = rm_bd, honest_sd_breakdown_M = sd_bd,
  n_treated = uniqueN(dd[gn < 10000, codmun_6])), OUT_CSV)
say("wrote %s", OUT_CSV)

# ---- body event-study figure (% scale, house style) ----
dd2 <- es[e >= PRE_LO & e <= 8]
dd2[, `:=`(lo = 100 * (exp(b - 1.96 * se) - 1), hi = 100 * (exp(b + 1.96 * se) - 1))]
g <- ggplot(dd2, aes(e, pct)) +
  geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
  geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, fill = OK) +
  geom_pointrange(aes(ymin = lo, ymax = hi), color = OK, linewidth = 0.55, size = 0.38) +
  geom_line(color = OK, linewidth = 0.4, alpha = 0.55) +
  scale_x_continuous(breaks = seq(-6, 8, 2)) +
  labs(x = "Years since closure", y = "Effect on psychiatric admissions (%)",
       title = "Inpatient psychiatric admissions fall sharply after closure") +
  theme_minimal(base_size = 9.5) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 10, hjust = 0))
ggsave(OUT_FIG, g, width = 5.6, height = 3.9, device = "pdf")
say("wrote %s", OUT_FIG)
say("done")
