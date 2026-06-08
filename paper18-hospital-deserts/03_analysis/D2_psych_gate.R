#!/usr/bin/env Rscript
# D2_psych_gate.R  (DIAGNOSTIC — Stage-2 outcome viability gate)
#
# Runs the SAME Sun-Abraham E1 (share-based g_emb) spec used in 30_event_study_final.R
# on candidate psychiatric health outcomes, and reports for each (panel x outcome):
#   - post ATT (simple aggregation), SE, z
#   - pre-trend Wald: W = sum_{e<=-2} (cf_e/se_e)^2 ; p = 1 - pchisq(W, k)
#     (this reproduces the paper's "sum-of-squared-z Wald-type test on k pre-period coefs")
#
# Validation rows: travel_burden_km (paper: W=1.82) and icsap_per1k (paper: W=35.8)
# confirm the pre-trend implementation matches the manuscript before reading the gate.

suppressPackageStartupMessages({ library(arrow); library(data.table); library(fixest) })

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG   <- file.path(ROOT, "04_logs")

psy <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
psy <- psy[, .(codmun_6, year, suicide_per100k, selfharm_per100k,
               psychF_mort_per100k, psych_adm_per1k)]

load_panel <- function(fname, join_psy = TRUE) {
  d <- as.data.table(read_parquet(file.path(INTER, fname)))
  if (join_psy && !"suicide_per100k" %in% names(d))
    d <- merge(d, psy, by = c("codmun_6", "year"), all.x = TRUE)
  d
}

run_gate <- function(panel, yname) {
  d <- panel[is.finite(get(yname))]
  d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  if (d[gn < 10000, uniqueN(muni_id)] < 5) return(NULL)
  m <- tryCatch(feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yname)),
                      data = d, cluster = "muni_id"),
                error = function(e) { cat("  ERR:", conditionMessage(e), "\n"); NULL })
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  att <- as.numeric(coef(agg)[1]); se <- as.numeric(se(agg)[1])

  cf <- coef(m); s <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]
  # pre-trend tested on the paper's binding window [-5,+5]: pre-period e in [-6,-2]
  # (e=-1 is the SunAb reference; deep pre-period e<=-7 is explosive/out-of-window).
  pre <- es[e <= -2 & e >= -6]
  W <- sum((pre$cf / pre$se)^2); k <- nrow(pre)
  p_pre <- if (k > 0) 1 - pchisq(W, k) else NA_real_
  # post-period peak at e=+5 (or max available) for context
  peak <- es[e >= 0][which.max(abs(es[e >= 0]$cf))]
  list(att = att, se = se, z = att / se,
       n_tr = d[gn < 10000, uniqueN(muni_id)],
       W = W, k = k, p_pre = p_pre,
       peak_e = if (nrow(peak)) peak$e else NA, peak_cf = if (nrow(peak)) peak$cf else NA,
       pre_e = paste(pre$e, collapse = ","))
}

panels <- list(
  F5_main  = "staggered_panel_F5_main.parquet",
  spec07   = "staggered_panel_spec07.parquet",
  F6_admin = "staggered_panel_F6_admin.parquet"
)
outcomes <- c("travel_burden_km", "icsap_per1k",            # validation
              "suicide_per100k", "selfharm_per100k",        # gate candidates
              "psychF_mort_per100k", "psych_adm_per1k")

cat(sprintf("%-9s %-20s %8s %7s %6s %5s %7s %8s %3s %6s\n",
            "panel", "outcome", "ATT", "SE", "z", "n_tr", "W_pre", "p_pre", "k", "pk@e+5"))
cat(strrep("-", 95), "\n")
res <- list()
for (pn in names(panels)) {
  pan <- load_panel(panels[[pn]])
  for (yn in outcomes) {
    if (!yn %in% names(pan)) next
    r <- run_gate(pan, yn)
    if (is.null(r)) next
    flag <- if (yn %in% c("travel_burden_km","icsap_per1k")) " (ref)" else
            if (!is.na(r$p_pre) && r$p_pre > 0.10) "  <== PT OK" else ""
    cat(sprintf("%-9s %-20s %+8.3f %7.3f %6.2f %5d %7.2f %8.4f %3d %+6.2f%s\n",
                pn, yn, r$att, r$se, r$z, r$n_tr, r$W, r$p_pre, r$k, r$peak_cf, flag))
    res[[paste(pn, yn)]] <- c(panel = pn, outcome = yn, unlist(r))
  }
  cat("\n")
}
saveRDS(res, file.path(LOG, "D2_psych_gate.rds"))
cat("(PT OK = pre-trend Wald p>0.10, i.e. parallel trends not rejected)\n")
