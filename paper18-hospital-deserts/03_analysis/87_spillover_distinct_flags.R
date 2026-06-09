#!/usr/bin/env Rscript
# =====================================================================
# 87_spillover_distinct_flags.R
#
# Rebuild the network-spillover / SUTVA sensitivity table with GENUINELY
# DISTINCT contamination flags (fixing the transparency flaw where
# shared-hub, shared-substitute and high-flow-similarity were aliases of
# the same `same_top_referral_hub` column and produced identical rows).
#
# Flags come from 87a_build_distinct_spillover_flags.py
# (-> spillover_control_flags_v2.parquet). Headline panel:
# staggered_panel_pnash48_ext.parquet, pop-weighted Sun-Abraham, matching
# 69_recipient_control_spillover.R (baseline suicide +0.28 [-0.72,+1.29]).
#
# For each rule we report: N controls removed, N controls kept, suicide
# ATT + 95% CI, self-harm ATT + 95% CI, and a pre-trend joint Wald p-value
# (on pre-period event-study leads, e in [-7,-2]), computed as in
# 39_pretrend_tests_and_r99.R.
#
# Cache-aware (--force). setFixest_nthreads(8). Telemetry to 04_logs.
# =====================================================================

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})
setDTthreads(8); setFixest_nthreads(8)

ROOT  <- "/home/darciogm1/projetos/bitter-pills/paper18-hospital-deserts"
PANEL <- file.path(ROOT, "02_data/intermediate/staggered_panel_pnash48_ext.parquet")
FLAGS <- file.path(ROOT, "02_data/processed/spillover_control_flags_v2.parquet")
PROC  <- file.path(ROOT, "02_data/processed")
CSV   <- file.path(PROC, "spillover_sensitivity_estimates.csv")
TEX   <- file.path(ROOT, "01_manuscript/tables_appendix/table_spillover_sensitivity.tex")
TEX2  <- file.path(ROOT, "01_manuscript/tables/table_spillover_sensitivity.tex")
LOG   <- file.path(ROOT, "04_logs/spillover_distinct_flags_20260609.log")
ARCH_CSV <- file.path(PROC, "_archive")
ARCH_TEX <- file.path(ROOT, "01_manuscript/_archive")

args  <- commandArgs(trailingOnly = TRUE)
FORCE <- "--force" %in% args
dir.create(ARCH_CSV, showWarnings = FALSE, recursive = TRUE)
dir.create(ARCH_TEX, showWarnings = FALSE, recursive = TRUE)

logf <- function(...) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), sprintf(...))
  cat(msg, "\n"); cat(msg, "\n", file = LOG, append = TRUE)
}
mem_rss <- function() tryCatch(
  round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE)) / 1024, 1),
  error = function(e) NA)

logf("=== 87_spillover_distinct_flags.R START host=%s nproc=%s ===",
     Sys.info()[["nodename"]], system("nproc", intern = TRUE))
logf("R=%s arrow=%s data.table=%s fixest=%s", R.version.string,
     as.character(packageVersion("arrow")), as.character(packageVersion("data.table")),
     as.character(packageVersion("fixest")))
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA)
logf("git_sha=%s force=%s", paste(git_sha, collapse = " "), FORCE)

# --- data -------------------------------------------------------------
d <- as.data.table(read_parquet(PANEL))
d[, codmun_6 := as.character(codmun_6)]
d[, gn := ifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
flags <- as.data.table(read_parquet(FLAGS))
flags[, codmun_6 := as.character(codmun_6)]
fcols <- c("same_cir_as_closure_catchment", "shared_top_referral_hub",
           "shared_substitute_hospital", "high_flow_similarity_to_treated",
           "contaminated_control_any")
d <- flags[, c("codmun_6", fcols), with = FALSE][d, on = "codmun_6"]
for (v in fcols) d[is.na(get(v)), (v) := FALSE]

ctrl_munis <- unique(d[gn == 10000L, codmun_6])
logf("panel rows=%d munis=%d treated=%d controls=%d | RSS=%sMB",
     nrow(d), uniqueN(d$codmun_6), uniqueN(d[gn < 10000L, codmun_6]),
     length(ctrl_munis), mem_rss())
for (v in fcols)
  logf("flag %-32s removes %d controls", v, d[gn == 10000L & get(v) == TRUE, uniqueN(codmun_6)])

# --- estimator: pop-weighted Sun-Abraham ATT + pre-trend Wald --------
fit_one <- function(dat, y) {
  dd <- dat[is.finite(get(y)) & is.finite(pop) & pop > 0]
  f <- as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", y))
  m <- feols(f, dd, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
  a <- summary(m, agg = "att")
  att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  # pre-trend joint Wald on event-time leads e in [-7,-2] (cf. script 39)
  cf <- coef(m); V <- vcov(m); nm <- names(cf)
  pre_idx <- which(grepl("^year::", nm))
  pre_e <- suppressWarnings(as.integer(sub("^year::", "", nm[pre_idx])))
  keep <- pre_idx[!is.na(pre_e) & pre_e < -1 & pre_e >= -7]
  if (length(keep) >= 1) {
    b <- cf[keep]; Vsub <- as.matrix(V[keep, keep, drop = FALSE])
    W <- tryCatch(as.numeric(t(b) %*% solve(Vsub, b)), error = function(e) NA_real_)
    k <- length(b)
    pj <- if (is.finite(W)) 1 - pchisq(W, df = k) else NA_real_
  } else { W <- NA_real_; k <- 0L; pj <- NA_real_ }
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       n_obs = nobs(m), n_treated = dd[gn < 10000L, uniqueN(codmun_6)],
       n_controls = dd[gn == 10000L, uniqueN(codmun_6)],
       pretrend_W = W, pretrend_df = k, pretrend_p = pj)
}

# --- rules (distinct) -------------------------------------------------
rules <- data.table(
  rule = c("Baseline (all controls)",
           "Exclude same health-region (CIR)",
           "Exclude shared top referral hub",
           "Exclude shared substitute hospital (recipient flow)",
           "Exclude high flow-similarity",
           "Exclude any network-contaminated"),
  flag = c(NA_character_,
           "same_cir_as_closure_catchment",
           "shared_top_referral_hub",
           "shared_substitute_hospital",
           "high_flow_similarity_to_treated",
           "contaminated_control_any")
)
outcomes <- data.table(outcome = c("suicide_per100k", "selfharm_per100k"),
                       label = c("Suicide", "Self-harm"))

res <- rbindlist(lapply(seq_len(nrow(rules)), function(i) {
  r <- rules[i]; dat <- copy(d); removed <- 0L
  if (!is.na(r$flag)) {
    removed <- dat[gn == 10000L & get(r$flag) == TRUE, uniqueN(codmun_6)]
    dat <- dat[!(gn == 10000L & get(r$flag) == TRUE)]
  }
  rbindlist(lapply(seq_len(nrow(outcomes)), function(j) {
    y <- outcomes[j]; e <- fit_one(dat, y$outcome)
    logf("%-52s %-9s ATT=%+.2f CI[%+.2f,%+.2f] removed=%d kept=%d preP=%.3f",
         r$rule, y$label, e$att, e$lo, e$hi, removed, e$n_controls, e$pretrend_p)
    data.table(rule = r$rule, flag = r$flag, outcome = y$outcome, outcome_label = y$label,
               removed_controls = removed, att = e$att, se = e$se, lo = e$lo, hi = e$hi,
               n_obs = e$n_obs, n_treated = e$n_treated, n_controls = e$n_controls,
               pretrend_W = e$pretrend_W, pretrend_df = e$pretrend_df,
               pretrend_p = e$pretrend_p, status = "ok")
  }))
}))

# --- VALIDATE baseline reproduces +0.28 [-0.72,+1.29] ----------------
bl <- res[rule == "Baseline (all controls)" & outcome == "suicide_per100k"]
logf("VALIDATION baseline suicide ATT=%.4f CI[%.4f,%.4f] (target +0.28 [-0.72,+1.29])",
     bl$att, bl$lo, bl$hi)
ok <- abs(bl$att - 0.28) < 0.02 && abs(bl$lo - (-0.72)) < 0.03 && abs(bl$hi - 1.29) < 0.03
if (!ok) {
  logf("FATAL: baseline does not reproduce headline +0.28 [-0.72,+1.29]; aborting before writing outputs")
  stop("baseline validation failed")
}
logf("VALIDATION PASSED")

# --- archive old outputs, write new -----------------------------------
if (file.exists(CSV)) {
  ar <- file.path(ARCH_CSV, "spillover_sensitivity_estimates_pre20260609.csv")
  if (!file.exists(ar) || FORCE) file.copy(CSV, ar, overwrite = TRUE)
  logf("archived old CSV -> %s", ar)
}
for (tf in c(TEX, TEX2)) if (file.exists(tf)) {
  ar <- file.path(ARCH_TEX, paste0(basename(tf), ".pre20260609"))
  if (!file.exists(ar) || FORCE) file.copy(tf, ar, overwrite = TRUE)
  logf("archived old TEX -> %s", ar)
}

fwrite(res, CSV)
logf("wrote %s rows=%d", CSV, nrow(res))

# --- LaTeX (threeparttable, one row per spec x outcome) ---------------
fmt   <- function(x) ifelse(is.finite(x), sprintf("%+.2f", x), "--")
fmtci <- function(lo, hi) ifelse(is.finite(lo) & is.finite(hi),
                                 sprintf("[%+.2f, %+.2f]", lo, hi), "--")
fmtp  <- function(p) ifelse(is.finite(p), sprintf("%.2f", p), "--")
wide <- dcast(res, rule + removed_controls + n_controls ~ outcome,
              value.var = c("att", "lo", "hi", "pretrend_p"))
ord <- match(rules$rule, wide$rule); wide <- wide[ord]
body <- wide[, sprintf(
  "%s & %d & %d & %s & %s & %s & %s & %s \\\\",
  rule, removed_controls, n_controls,
  fmt(att_suicide_per100k), fmtci(lo_suicide_per100k, hi_suicide_per100k),
  fmt(att_selfharm_per100k), fmtci(lo_selfharm_per100k, hi_selfharm_per100k),
  fmtp(pretrend_p_suicide_per100k))]

n_a <- d[gn == 10000L & same_cir_as_closure_catchment == TRUE, uniqueN(codmun_6)]
n_b <- d[gn == 10000L & shared_top_referral_hub == TRUE, uniqueN(codmun_6)]
n_c <- d[gn == 10000L & shared_substitute_hospital == TRUE, uniqueN(codmun_6)]
n_d <- d[gn == 10000L & high_flow_similarity_to_treated == TRUE, uniqueN(codmun_6)]
n_any <- d[gn == 10000L & contaminated_control_any == TRUE, uniqueN(codmun_6)]

tex <- c(
  "\\begin{table}[!htbp]\\centering",
  "\\begin{threeparttable}",
  "\\caption{Mortality sensitivity to network-contaminated controls (distinct SUTVA flags)}",
  "\\label{tab:spillover-sensitivity}",
  "\\small",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\begin{tabular}{lrrcccc c}",
  "\\toprule",
  " & & & \\multicolumn{2}{c}{Suicide} & \\multicolumn{2}{c}{Self-harm} & Pre-trend \\\\",
  "\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
  "Specification & Removed & Kept & ATT & 95\\% CI & ATT & 95\\% CI & $p$ \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  "\\item \\textit{Notes.} Population-weighted Sun--Abraham ATT estimates on the PNASH-48 staggered panel (104 treated municipalities, 5{,}461 never-treated controls), with municipality and year fixed effects and municipality-clustered standard errors. Each row drops never-treated controls flagged by one network-contamination rule and re-estimates. ``Removed'' / ``Kept'' count control municipalities. ``Pre-trend $p$'' is the joint Wald test that all pre-period event-study leads ($e\\in[-7,-2]$) are zero, for the suicide outcome. The four contamination rules are constructed to be genuinely distinct:",
  sprintf("\\item \\textbf{(a) Same health region (CIR):} control whose modal health region (\\texttt{regsaude\\_modal}) equals that of any treated catchment in the year before closure --- a purely administrative/geographic proxy (removes %d controls).", n_a),
  sprintf("\\item \\textbf{(b) Shared top referral hub:} control whose modal 2010--2014 referral destination (top-1 hospital by admissions) is also the top hub of a treated municipality --- network-revealed but using only the single strongest edge (removes %d controls).", n_b),
  sprintf("\\item \\textbf{(c) Shared substitute hospital:} control revealed by \\emph{post}-closure admission flows to be a recipient of volume redirected to the substitute hospitals that absorbed displaced patients (share-rise threshold $>0.01$; the recipient-control construction of script~69) --- the genuine redirection channel, distinct from any pre-closure hub (removes %d controls).", n_c),
  sprintf("\\item \\textbf{(d) High flow similarity:} control whose full pre-closure municipality$\\to$hospital flow-share vector has cosine similarity in the top decile (within controls) to any treated catchment's flow vector. By construction a top-hub match implies high cosine, so rule~(d) nests rule~(b); the additional %d controls flagged here share a similar \\emph{whole} referral distribution without sharing the single top hub, so the row is not a duplicate of~(b) (removes %d controls in total).", n_d - n_b, n_d),
  sprintf("\\item \\textbf{Any:} union of (a)--(d) (removes %d controls). Flags built in \\texttt{87a\\_build\\_distinct\\_spillover\\_flags.py}; estimates in \\texttt{87\\_spillover\\_distinct\\_flags.R}.", n_any),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex, TEX)
file.copy(TEX, TEX2, overwrite = TRUE)
logf("wrote %s and %s", TEX, TEX2)
logf("=== DONE runtime check | RSS=%sMB ===", mem_rss())
print(res[, .(rule, outcome_label, removed_controls, n_controls,
              att = round(att, 2), lo = round(lo, 2), hi = round(hi, 2),
              pretrend_p = round(pretrend_p, 3))])
