#!/usr/bin/env Rscript
# 99_ans_moderator_eventstudy.R  [ans-moderator branch]
#
# Does the SUS-only limitation bind? Re-estimate the headline suicide and
# psychiatric-admission event studies separately for treated municipalities with
# LOW vs HIGH private-plan penetration (ANS). Where private penetration is low,
# displaced patients cannot be absorbed by an invisible private sector, so the
# SUS-measured admission drop is the true care loss and the mortality null is clean.

suppressPackageStartupMessages({ library(arrow); library(data.table); library(fixest) })
setFixest_nthreads(4); setDTthreads(4)
ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")

P  <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_pnash48_ext.parquet")))
po <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
pen <- as.data.table(read_parquet(file.path(INTER, "ans_private_penetration.parquet")))
P[, codmun_6 := sprintf("%06d", as.integer(codmun_6))]
po[, codmun_6 := sprintf("%06d", as.integer(codmun_6))]
pen[, codmun_6 := sprintf("%06d", as.integer(codmun_6))]
d <- merge(P, po[, .(codmun_6, year, psych_adm_per1k)], by = c("codmun_6","year"), all.x = TRUE)
d <- merge(d, pen[, .(codmun_6, tx_cobert_med_pct, low_private)], by = "codmun_6", all.x = TRUE)
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
d[, treated := gn < 10000]

est <- function(dat, yn) {
  d2 <- dat[is.finite(get(yn)) & is.finite(pop)]
  if (uniqueN(d2[gn < 10000]$codmun_6) < 5) return(NULL)
  m <- tryCatch(feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
              d2, cluster = "muni_id", weights = d2$pop), error = function(e) NULL)
  if (is.null(m)) return(NULL)
  att <- as.numeric(coef(summary(m, agg = "att"))[1]); se <- as.numeric(se(summary(m, agg = "att"))[1])
  cf <- coef(m); s <- se(m); mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]; pre <- es[e <= -2 & e >= -6]
  list(att = att, lo = att - 1.96*se, hi = att + 1.96*se,
       p = if (nrow(pre)>0) 1 - pchisq(sum((pre$cf/pre$se)^2), nrow(pre)) else NA_real_,
       n = uniqueN(d2[gn < 10000]$codmun_6))
}

never <- d[gn == 10000L]
arms <- list(
  all          = d,
  low_private  = rbind(d[treated == TRUE & low_private == 1], never),
  high_private = rbind(d[treated == TRUE & low_private == 0], never))

res <- rbindlist(lapply(names(arms), function(a) rbindlist(lapply(
  c("suicide_per100k","psych_adm_per1k"), function(y) {
    r <- est(arms[[a]], y); if (is.null(r)) return(NULL)
    data.table(arm = a, outcome = y, att = r$att, ci_lo = r$lo, ci_hi = r$hi,
               pretrend_p = r$p, n_treated = r$n)
}))))
fwrite(res, file.path(PROC, "ans_moderator_eventstudy.csv"))

cat(sprintf("median penetration threshold (low<%.1f%%)\n",
            d[treated == TRUE][!is.na(tx_cobert_med_pct)][, median(tx_cobert_med_pct)]))
cat("\n=== suicide and psychiatric-admission ATT by private-penetration arm ===\n")
for (y in unique(res$outcome)) {
  cat(sprintf("\n%s\n", y))
  for (a in c("all","low_private","high_private")) {
    r <- res[arm==a & outcome==y]
    if (nrow(r)) cat(sprintf("  %-13s ATT %+8.3f  CI [%+7.3f, %+7.3f]  pretrend p=%.2f  n_tr=%d\n",
                             a, r$att, r$ci_lo, r$ci_hi, r$pretrend_p, r$n_treated))
  }
}
cat("\nTakeaway: if the null and the admission drop hold among LOW-private treated\n",
    "municipalities, the result is not an artifact of unobserved private absorption.\n", sep="")
