#!/usr/bin/env Rscript
# 96_estimate_disagreement_placebo.R  [disagreement-placebo branch]
#
# Exposure-validation placebo. Same staggered Sun-Abraham machinery as the main
# paper, run separately for flow-only / distance-only / both treatment groups
# against never-flagged controls. Prediction: the first stage (travel burden,
# psychiatric admissions) loads on flow-only and both, not on distance-only.

suppressPackageStartupMessages({ library(arrow); library(data.table); library(fixest) })
setFixest_nthreads(4); setDTthreads(4)
ROOT <- normalizePath(file.path(dirname(sub("--file=", "",
         commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
PROC <- file.path(ROOT, "02_data", "processed")
LOGF <- file.path(ROOT, "04_logs", sprintf("disagreement_placebo_%s.log", format(Sys.Date(), "%Y%m%d")))
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOGF, append = TRUE) }
cat(sprintf("==== 96_estimate_disagreement_placebo %s ====\n", Sys.time()), file = LOGF)

D <- as.data.table(read_parquet(file.path(PROC, "disagreement_event_panel.parquet")))

# est: group (treated, cohort_year) vs never (controls); same spec as headline
est <- function(dat, yn) {
  d2 <- dat[is.finite(get(yn)) & is.finite(pop)]
  d2[, gn := ifelse(group == "never", 10000L, as.integer(cohort_year))]
  if (uniqueN(d2[gn < 10000]$codmun_6) < 5) return(NULL)
  m <- tryCatch(feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
              d2, cluster = "muni_id", weights = d2$pop), error = function(e) NULL)
  if (is.null(m)) return(NULL)
  att <- as.numeric(coef(summary(m, agg = "att"))[1]); se <- as.numeric(se(summary(m, agg = "att"))[1])
  cf <- coef(m); s <- se(m); mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es <- es[is.finite(cf) & is.finite(se) & se > 0]; pre <- es[e <= -2 & e >= -6]
  W <- sum((pre$cf / pre$se)^2)
  list(att = att, se = se, lo = att - 1.96*se, hi = att + 1.96*se,
       p = if (nrow(pre) > 0) 1 - pchisq(W, nrow(pre)) else NA_real_,
       n_tr = uniqueN(d2[gn < 10000]$codmun_6))
}

grid <- list(
  list(s = "PNASH_psychiatric", y = "travel_burden_km",  g = "flow_only"),
  list(s = "PNASH_psychiatric", y = "travel_burden_km",  g = "both"),
  list(s = "PNASH_psychiatric", y = "travel_burden_km",  g = "distance_only"),
  list(s = "PNASH_psychiatric", y = "psych_adm_per1k",   g = "flow_only"),
  list(s = "PNASH_psychiatric", y = "psych_adm_per1k",   g = "both"),
  list(s = "PNASH_psychiatric", y = "psych_adm_per1k",   g = "distance_only"),
  list(s = "PNASH_psychiatric", y = "suicide_per100k",   g = "flow_only"),
  list(s = "PNASH_psychiatric", y = "suicide_per100k",   g = "both"),
  list(s = "PNASH_psychiatric", y = "suicide_per100k",   g = "distance_only"),
  list(s = "PNASH_psychiatric", y = "selfharm_per100k",  g = "flow_only"),
  list(s = "PNASH_psychiatric", y = "selfharm_per100k",  g = "both"),
  list(s = "PNASH_psychiatric", y = "selfharm_per100k",  g = "distance_only"),
  list(s = "F5_measurement",    y = "travel_burden_km",  g = "flow_only"),
  list(s = "F5_measurement",    y = "travel_burden_km",  g = "both"),
  list(s = "F5_measurement",    y = "travel_burden_km",  g = "distance_only")
)

res <- rbindlist(lapply(grid, function(x) {
  dat <- D[sample_id == x$s & group %in% c(x$g, "never")]
  r <- est(dat, x$y)
  if (is.null(r)) return(NULL)
  data.table(sample = x$s, outcome = x$y, group = x$g, att = r$att, se = r$se,
             ci_lo = r$lo, ci_hi = r$hi, pretrend_p = r$p, n_treated = r$n_tr)
}))
fwrite(res, file.path(PROC, "disagreement_placebo_results.csv"))

say("\n=== disagreement-placebo event studies (group vs never controls) ===")
for (s in unique(res$sample)) for (y in unique(res[sample == s]$outcome)) {
  say("\n[%s] %s", s, y)
  for (i in which(res$sample == s & res$outcome == y)) {
    say("  %-14s ATT %+8.3f  CI [%+7.3f, %+7.3f]  pretrend p=%.2f  n_tr=%d",
        res$group[i], res$att[i], res$ci_lo[i], res$ci_hi[i], res$pretrend_p[i], res$n_treated[i])
  }
}

# ---- appendix table (full) ----
ynice <- c(travel_burden_km = "Travel burden (km)", psych_adm_per1k = "Psychiatric admissions per 1{,}000",
           suicide_per100k = "Suicide per 100{,}000", selfharm_per100k = "Self-harm per 100{,}000")
gnice <- c(flow_only = "Flow-only (distance misses)", both = "Both rules",
           distance_only = "Distance-only (flow misses)")
mk_block <- function(samp) {
  rr <- res[sample == samp]
  lines <- c()
  for (y in unique(rr$outcome)) {
    lines <- c(lines, sprintf("\\multicolumn{5}{l}{\\emph{%s}} \\\\", ynice[y]))
    for (g in c("flow_only","both","distance_only")) {
      r <- rr[outcome == y & group == g]
      if (nrow(r) == 0) next
      lines <- c(lines, sprintf("\\quad %s & %+.2f & [%+.2f, %+.2f] & %.2f & %d \\\\",
                 gnice[g], r$att, r$ci_lo, r$ci_hi, r$pretrend_p, r$n_treated))
    }
    lines <- c(lines, "\\addlinespace")
  }
  lines
}
tab <- c("\\begin{table}[!htbp]\\centering",
  "\\caption{Exposure-validation placebo: the first stage loads on revealed use, not proximity}",
  "\\label{tab:disagreement-placebo}", "\\small", "\\begin{tabular}{lrrrr}", "\\toprule",
  "Group vs.\\ never-flagged controls & ATT & 95\\% CI & Pre-trend $p$ & $N$ treated \\\\",
  "\\midrule",
  "\\multicolumn{5}{l}{\\textbf{Panel A. PNASH psychiatric sample}} \\\\", mk_block("PNASH_psychiatric"),
  "\\midrule",
  "\\multicolumn{5}{l}{\\textbf{Panel B. F5 measurement sample}} \\\\", mk_block("F5_measurement"),
  "\\bottomrule",
  paste0("\\multicolumn{5}{p{0.94\\textwidth}}{\\footnotesize Notes: Population-weighted staggered ",
    "Sun-Abraham event studies, municipality and year fixed effects, standard errors clustered by ",
    "municipality. Each row compares one disagreement group---municipalities flagged only by patient ",
    "flows, by both rules, or only by distance---against never-flagged controls, using each ",
    "municipality's earliest flagged closure as its cohort. Flow-only and both municipalities show the ",
    "utilization first stage (travel falls, admissions drop); distance-only municipalities, the false ",
    "positives of the distance rule, do not. Mortality is secondary and does not drive the validation.}\\\\"),
  "\\end{tabular}", "\\end{table}", "")
writeLines(tab, file.path(ROOT, "01_manuscript", "tables_appendix", "table_disagreement_placebo_full.tex"))
say("\nwrote table_disagreement_placebo_full.tex + disagreement_placebo_results.csv")
say("done")
