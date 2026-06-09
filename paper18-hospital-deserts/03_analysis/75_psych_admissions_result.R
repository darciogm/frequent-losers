#!/usr/bin/env Rscript
# 75_psych_admissions_result.R
#
# Featured mechanism result: inpatient psychiatric admissions (DIAG_PRINC
# F00-F99, by residence municipality, any hospital) fall sharply after a
# PNASH psychiatric closure. This is the "dose" of the shock that the
# mortality null is set against -- a large, identified, net reduction in
# inpatient psychiatric care received (not redistribution across hospitals,
# since the outcome counts admissions anywhere).
#
# Outputs:
#   02_data/processed/psych_admissions_result.csv  (ATT/CI/pre-trend/base)
#   04_figures/fig_es_psych_adm.pdf                 (body event-study figure)
#
# Usage: Rscript 03_analysis/75_psych_admissions_result.R [--force]

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(ggplot2)
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

P  <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
po <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
d  <- merge(P[, !c("psychF_mort_per100k"), with = FALSE],
            po[, .(codmun_6, year, psych_adm_per1k)], by = c("codmun_6", "year"), all.x = TRUE)
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]

est_full <- function(yn, wt = TRUE) {
  d2 <- d[is.finite(get(yn)) & (!wt | is.finite(pop))]
  w  <- if (wt) d2$pop else NULL
  m  <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
              d2, cluster = "muni_id", weights = w)
  att <- as.numeric(coef(summary(m, agg = "att"))[1]); se <- as.numeric(se(summary(m, agg = "att"))[1])
  cf <- coef(m); s <- se(m); mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]
  pre <- es[e <= -2 & e >= -6]; W <- sum((pre$cf / pre$se)^2)
  base <- weighted.mean(d2[gn < 10000 & year < gn][[yn]], d2[gn < 10000 & year < gn]$pop, na.rm = TRUE)
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       p = 1 - pchisq(W, nrow(pre)), base = base, es = es)
}

# sanity: suicide must reproduce +0.28
val <- est_full("suicide_per100k")
say("VALIDATION suicide ATT = %.4f (target ~ +0.28)", val$att)
stopifnot(abs(val$att - 0.28) < 0.05)

r <- est_full("psych_adm_per1k")
say("psych_adm ATT = %.2f  CI [%.2f, %.2f]  pre-trend p = %.3f  base = %.1f  (%.0f%% of base)",
    r$att, r$lo, r$hi, r$p, r$base, 100 * r$att / r$base)

fwrite(data.table(outcome = "psych_adm_per1k", att = r$att, se = r$se, ci_lo = r$lo, ci_hi = r$hi,
                  pretrend_p = r$p, base = r$base, pct_of_base = 100 * r$att / r$base), OUT_CSV)
say("wrote %s", OUT_CSV)

# body figure (house style, single trajectory)
dd <- r$es[e >= -6 & e <= 8]; dd[, `:=`(lo = cf - 1.96 * se, hi = cf + 1.96 * se)]
g <- ggplot(dd, aes(e, cf)) +
  geom_hline(yintercept = 0, color = GREY, linewidth = 0.4, linetype = "dashed") +
  geom_vline(xintercept = -0.5, color = GREY, linewidth = 0.3, linetype = "dotted") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, fill = OK) +
  geom_pointrange(aes(ymin = lo, ymax = hi), color = OK, linewidth = 0.55, size = 0.38) +
  geom_line(color = OK, linewidth = 0.4, alpha = 0.55) +
  scale_x_continuous(breaks = seq(-6, 8, 2)) +
  labs(x = "Years since closure", y = "ATT, psychiatric admissions (per 1,000)",
       title = "Inpatient psychiatric admissions fall sharply after closure") +
  theme_minimal(base_size = 9.5) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(size = 10, hjust = 0))
ggsave(OUT_FIG, g, width = 5.6, height = 3.9, device = "pdf")
say("wrote %s", OUT_FIG)
say("done")
