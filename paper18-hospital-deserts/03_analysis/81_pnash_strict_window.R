#!/usr/bin/env Rscript
# 81_pnash_strict_window.R
#
# Referee-facing robustness: the 48 PNASH-anchored psychiatric closures vs. the
# 37 that fall within an EXACT +/-1 calendar year of the nearest PNASH inspection
# cycle year. The other 11 (all 2014 closures) sit at distance 2 from the
# 2011-2012 cycle, so a referee can argue they are not truly "PNASH-anchored".
# This script reconstructs treatment from ONLY the 37 strict closures and re-runs
# the headline population-weighted Sun-Abraham mortality/mechanism spec, to show
# honestly whether the mortality null survives the stricter anchoring window.
#
# Window definitions (made explicit in code, written to CSV):
#   PNASH_cycle_window = all 48   (nearest cycle, any distance; canonical sample)
#   PNASH_exact_pm1    = the 37 with within_pm1_year_of_pnash_cycle == TRUE
#   PNASH_strict       = PNASH_exact_pm1 (same 37; alias used in prose/tables)
#
# Estimator mirrors 03_analysis/D5_make_mortality_results.R and
# 03_analysis/75_psych_admissions_result.R exactly:
#   feols(y ~ sunab(gn, year) | muni_id + year, cluster = muni_id, weights = ~pop)
#   gn = closure year for treated, 10000 for never-treated; agg = "att".
#   Pre-trend = diagonal chi-sq Wald on event-time leads e in [-6,-2]
#   (W = sum((cf/se)^2), p = 1 - pchisq(W, k)) -- the SAME pre-trend the
#   headline mortality scripts (D5/75) report. (Script 39 uses the full-vcov
#   Wald on [-7,-2] for the first-stage travel/ICSAP tables; for the mortality
#   null this robustness mirrors D5/75 so the numbers line up with the headline.)
#
# Strict-37 panel construction (mirrors 29_build_final_panels.py logic, but the
# exposure mapping is read from the already-built canonical flow-exposure flags):
#   treated muni  = flow-exposed to >=1 strict closure; g = earliest strict
#                   exposing-closure year (recomputed from strict CNES only).
#   DROP munis exposed ONLY to the 11 non-strict closures (not controls).
#   never-treated controls (never exposed to any of the 48) unchanged.
#
# Outputs (owned by this script):
#   02_data/processed/pnash_window_definitions.csv
#   02_data/intermediate/staggered_panel_pnash_strict37.parquet
#   02_data/processed/pnash_strict_window_results.csv
#   01_manuscript/tables_appendix/table_pnash_strict_window_robustness.tex
#   04_logs/pnash_window_robustness_20260609.log
#
# Usage: Rscript 03_analysis/81_pnash_strict_window.R [--force]

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest)
})
setFixest_nthreads(8); setDTthreads(8)

ROOT  <- normalizePath(file.path(dirname(sub("--file=", "",
          commandArgs(FALSE)[grepl("--file=", commandArgs(FALSE))])), ".."))
INTER <- file.path(ROOT, "02_data", "intermediate")
PROC  <- file.path(ROOT, "02_data", "processed")
TABA  <- file.path(ROOT, "01_manuscript", "tables_appendix")
LOGD  <- file.path(ROOT, "04_logs")
dir.create(TABA, showWarnings = FALSE, recursive = TRUE)
dir.create(LOGD, showWarnings = FALSE, recursive = TRUE)

force <- "--force" %in% commandArgs(TRUE)

DEF_CSV   <- file.path(PROC, "pnash_window_definitions.csv")
STRICT_PQ <- file.path(INTER, "staggered_panel_pnash_strict37.parquet")
RES_CSV   <- file.path(PROC, "pnash_strict_window_results.csv")
TEX       <- file.path(TABA, "table_pnash_strict_window_robustness.tex")
LOGF      <- file.path(LOGD, "pnash_window_robustness_20260609.log")

# ---- telemetry header (per ~/.claude/CLAUDE.md) -----------------------------
sink(LOGF, split = TRUE)
on.exit({ sink(); closeAllConnections() }, add = TRUE)
t0 <- Sys.time()
cat("==== 81_pnash_strict_window.R ====\n")
cat("started:", format(t0, "%Y-%m-%d %H:%M:%S %Z"), "\n")
cat("hostname:", Sys.info()[["nodename"]], "\n")
ncores <- tryCatch(as.integer(system("nproc", intern = TRUE)), error = function(e) NA_integer_)
ram <- tryCatch(system("free -h | awk 'NR==2{print $2\" total, \"$7\" avail\"}'", intern = TRUE),
                error = function(e) NA_character_)
cat("cores (nproc):", ncores, " | fixest threads: 8 | dt threads: 8\n")
cat("RAM:", ram, "\n")
cat("R:", R.version.string, "\n")
cat("packages: arrow=", as.character(packageVersion("arrow")),
    " data.table=", as.character(packageVersion("data.table")),
    " fixest=", as.character(packageVersion("fixest")), "\n", sep = "")
git_sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA)
cat("git_sha:", paste(git_sha, collapse = " "), "\n")
cat("force:", force, "\n\n")

managed <- c(DEF_CSV, STRICT_PQ, RES_CSV, TEX)
if (!force && all(file.exists(managed))) {
  cat("All outputs exist; use --force to rebuild. Exiting.\n")
  quit(save = "no")
}

# =============================================================================
# 1. WINDOW DEFINITIONS
# =============================================================================
ev <- as.data.table(read_parquet(file.path(PROC, "pnash_event_level_dataset.parquet")))
ev[, CNES := as.character(CNES)]

defs <- ev[, .(
  CNES,
  municipality,
  closure_year,
  nearest_pnash_cycle,
  years_from_nearest_pnash_cycle,
  within_pm1_year_of_pnash_cycle,
  in_cycle_window = 1L,                              # all 48 are in the cycle window
  in_strict       = as.integer(within_pm1_year_of_pnash_cycle)  # 37 strict
)]
fwrite(defs, DEF_CSV)
cat("[1] wrote", DEF_CSV, "\n")
cat("    PNASH_cycle_window (in_cycle_window==1):", defs[in_cycle_window == 1, .N], "(must be 48)\n")
cat("    PNASH_exact_pm1 / PNASH_strict (in_strict==1):", defs[in_strict == 1, .N], "(must be 37)\n")
stopifnot(defs[in_cycle_window == 1, .N] == 48L, defs[in_strict == 1, .N] == 37L)

strict_cnes    <- defs[in_strict == 1, CNES]
nonstrict_cnes <- defs[in_strict == 0, CNES]
cat("    non-strict (11, all 2014):", paste(sort(unique(defs[in_strict == 0, closure_year])), collapse = ","), "\n\n")

# =============================================================================
# 2. BUILD STRICT-37 PANEL
# =============================================================================
# Canonical flow-exposure mapping for the 48 PNASH closures (sample_id =
# pnash_psychiatric_closures). flow_exposed TRUE == treated-by-this-closure.
# Verified offline that reconstructing g = min(year_closure) over all 48
# exactly reproduces staggered_panel_pnash48_ext.parquet (104 munis, 0 g diffs).
ef <- as.data.table(read_parquet(file.path(PROC, "closure_sample_exposure_flags_long.parquet")))
ef <- ef[sample_id == "pnash_psychiatric_closures"]
ef[, CNES := as.character(CNES)]
ef[, municipality := as.character(municipality)]
fx <- ef[flow_exposed == TRUE]

# g from STRICT closures only
g_strict <- fx[CNES %in% strict_cnes, .(g_emb = min(year_closure)), by = .(codmun_6 = municipality)]
# munis exposed to >=1 non-strict closure
nonstrict_munis <- unique(fx[CNES %in% nonstrict_cnes, municipality])
# munis exposed ONLY to non-strict closures -> DROP (never used as controls)
drop_munis <- setdiff(nonstrict_munis, g_strict$codmun_6)
all_exposed <- unique(fx$municipality)

cat("[2] strict treated munis (g from 37):", nrow(g_strict), "\n")
cat("    strict cohorts (g):", paste(sort(unique(g_strict$g_emb)), collapse = ","),
    " (", uniqueN(g_strict$g_emb), "cohorts )\n")
cat("    munis exposed only to the 11 non-strict closures -> DROPPED:", length(drop_munis), "\n")
cat("    (these are removed entirely, not reused as controls)\n")

# Start from the canonical 48 panel (mirror has psych_adm_per1k + macroregion).
# Rebuild treatment from strict-only g; drop only-non-strict exposed munis;
# never-treated controls (never exposed to any of the 48) carried over unchanged.
base48 <- as.data.table(read_parquet(file.path(PROC, "revision_pnash48_panel.parquet")))
base48[, codmun_6 := as.character(codmun_6)]

# refresh psych_adm_per1k from the canonical source the headline (script 75) uses,
# so the strict psych-admission spec is built identically to the full-48 one.
po <- as.data.table(read_parquet(file.path(INTER, "psych_outcomes_panel.parquet")))
po[, codmun_6 := as.character(codmun_6)]
base48[, psych_adm_per1k := NULL]
base48 <- merge(base48, po[, .(codmun_6, year, psych_adm_per1k)],
                by = c("codmun_6", "year"), all.x = TRUE)

# drop only-non-strict-exposed munis
strict_panel <- base48[!codmun_6 %in% drop_munis]
# wipe old treatment, re-stamp strict g
strict_panel[, g_emb := NULL]
strict_panel <- merge(strict_panel, g_strict, by = "codmun_6", all.x = TRUE)
strict_panel[, g_emb := fifelse(is.na(g_emb), 0L, as.integer(g_emb))]
strict_panel[, gn := fifelse(g_emb == 0L, 10000L, as.integer(g_emb))]
strict_panel[, treated_ever := g_emb > 0L]

# sanity: treated count == strict munis; controls unchanged; no stragglers
stopifnot(strict_panel[g_emb > 0, uniqueN(codmun_6)] == nrow(g_strict))
n_ctrl_48     <- base48[!(codmun_6 %in% all_exposed), uniqueN(codmun_6)]
n_ctrl_strict <- strict_panel[g_emb == 0, uniqueN(codmun_6)]
cat("    never-treated controls (full 48):", n_ctrl_48,
    " | (strict 37):", n_ctrl_strict, " (must match)\n")
stopifnot(n_ctrl_48 == n_ctrl_strict)

write_parquet(strict_panel, STRICT_PQ, compression = "snappy")
cat("    wrote", STRICT_PQ, "rows =", nrow(strict_panel), "\n\n")

# =============================================================================
# 3. ESTIMATION (pop-weighted Sun-Abraham; mirrors D5/75)
# =============================================================================
OUTCOMES <- c("suicide_per100k", "selfharm_per100k", "psych_adm_per1k", "travel_burden_km")

estimate <- function(d, yn) {
  d2 <- d[is.finite(get(yn)) & is.finite(pop) & pop > 0]
  d2[, gn := fifelse(is.na(g_emb) | g_emb == 0, 10000L, as.integer(g_emb))]
  m <- feols(as.formula(sprintf("%s ~ sunab(gn, year) | muni_id + year", yn)),
             d2, cluster = "muni_id", weights = ~pop, warn = FALSE, notes = FALSE)
  a   <- summary(m, agg = "att")
  att <- as.numeric(coef(a)[1]); se <- as.numeric(se(a)[1])
  # event-time coefs for the pre-trend test (D5/75 convention)
  cf <- coef(m); s <- se(m)
  mm <- regmatches(names(cf), regexec("^year::(-?[0-9]+)$", names(cf)))
  es <- rbindlist(lapply(seq_along(mm), function(i)
    if (length(mm[[i]]) == 2) data.table(e = as.integer(mm[[i]][2]), cf = cf[i], se = s[i]) else NULL))
  es  <- es[is.finite(cf) & is.finite(se) & se > 0]
  pre <- es[e <= -2 & e >= -6]
  if (nrow(pre) > 0) { W <- sum((pre$cf / pre$se)^2); pretrend_p <- 1 - pchisq(W, nrow(pre)) }
  else               { pretrend_p <- NA_real_ }
  list(att = att, se = se, lo = att - 1.96 * se, hi = att + 1.96 * se,
       pretrend_p = pretrend_p, k_pre = nrow(pre),
       n_exposed = d2[gn < 10000, uniqueN(codmun_6)],
       n_cohorts = d2[gn < 10000, uniqueN(g_emb)])
}

panels <- list(
  PNASH_cycle_window = base48,        # 48
  PNASH_strict       = strict_panel   # 37
)
sample_meta <- data.table(
  sample      = c("PNASH_cycle_window", "PNASH_strict"),
  n_closures  = c(48L, 37L)
)

cat("[3] estimating pop-weighted Sun-Abraham for both samples x 4 outcomes\n")
res <- rbindlist(lapply(names(panels), function(snm) {
  d <- panels[[snm]]
  rbindlist(lapply(OUTCOMES, function(yn) {
    r <- estimate(d, yn)
    cat(sprintf("  %-19s %-16s ATT=%+.3f SE=%.3f [%+.2f,%+.2f] PTp=%s (k=%d) exp=%d coh=%d\n",
                snm, yn, r$att, r$se, r$lo, r$hi,
                ifelse(is.na(r$pretrend_p), "NA", sprintf("%.3f", r$pretrend_p)),
                r$k_pre, r$n_exposed, r$n_cohorts))
    data.table(sample = snm, outcome = yn,
               n_closures = sample_meta[sample == snm, n_closures],
               n_exposed = r$n_exposed, n_cohorts = r$n_cohorts,
               att = r$att, se = r$se, ci_lo = r$lo, ci_hi = r$hi,
               pretrend_p = r$pretrend_p)
  }))
}))

# VALIDATION GATE: full-48 pop-weighted suicide must reproduce ~ +0.28
v <- res[sample == "PNASH_cycle_window" & outcome == "suicide_per100k", att]
cat(sprintf("\n  VALIDATION full-48 suicide ATT = %+.4f (target ~ +0.28)\n", v))
if (abs(v - 0.28) > 0.05) stop("VALIDATION FAILED: full-48 suicide ATT not ~+0.28. Aborting.")
cat("  VALIDATION PASSED.\n\n")

fwrite(res, RES_CSV)
cat("[3] wrote", RES_CSV, "\n\n")

# =============================================================================
# 4. VERDICT
# =============================================================================
ss <- res[sample == "PNASH_strict" & outcome == "suicide_per100k"]
sh <- res[sample == "PNASH_strict" & outcome == "selfharm_per100k"]
sf <- res[sample == "PNASH_cycle_window" & outcome == "suicide_per100k"]
cat("[4] VERDICT\n")
suic_null <- ss$ci_lo <= 0 & ss$ci_hi >= 0
self_null <- sh$ci_lo <= 0 & sh$ci_hi >= 0
cat(sprintf("    strict suicide CI includes 0: %s  [%+.2f,%+.2f]\n", suic_null, ss$ci_lo, ss$ci_hi))
cat(sprintf("    strict selfharm CI includes 0: %s [%+.2f,%+.2f]\n", self_null, sh$ci_lo, sh$ci_hi))
cat(sprintf("    full-48 suicide for reference: [%+.2f,%+.2f]\n", sf$ci_lo, sf$ci_hi))
if (suic_null && self_null) {
  cat("    => strict-37 PRESERVES the mortality null.\n\n")
} else {
  cat("    => strict-37 CHANGES the mortality null. See CIs above.\n\n")
}

# =============================================================================
# 5. LaTeX FRAGMENT (booktabs + threeparttable, \input-able, no \documentclass)
# =============================================================================
labof <- c(suicide_per100k = "Suicide (per 100k)",
           selfharm_per100k = "Self-harm (per 100k)",
           psych_adm_per1k  = "Psychiatric admissions (per 1k)",
           travel_burden_km = "Travel burden (km)")
cell <- function(snm, yn) {
  r <- res[sample == snm & outcome == yn]
  sprintf("$%+.2f$ & $[%+.2f,\\,%+.2f]$", r$att, r$ci_lo, r$ci_hi)
}
ptp <- function(yn) {
  a <- res[sample == "PNASH_cycle_window" & outcome == yn, pretrend_p]
  b <- res[sample == "PNASH_strict" & outcome == yn, pretrend_p]
  fmt <- function(x) ifelse(is.na(x), "NA", sprintf("%.2f", x))
  sprintf("%s & %s", fmt(a), fmt(b))
}
meta_get <- function(snm, col) res[sample == snm][1][[col]]

tex <- c(
"% Auto-generated by 03_analysis/81_pnash_strict_window.R -- do not edit by hand.",
"\\begin{table}[!htbp]\\centering",
"\\begin{threeparttable}",
"\\caption{Strict PNASH-window robustness: the mortality null under exact $\\pm1$-year anchoring. Population-weighted Sun--Abraham ATTs (Callaway--Sant'Anna--style cohort aggregation) on patient-flow--exposed municipalities, never-treated municipalities as controls, two-way (municipality and year) fixed effects, municipality-clustered standard errors. The cycle-window sample is all 48 PNASH-anchored psychiatric closures; the strict sample drops the 11 closures (all in 2014) that lie two calendar years from the nearest PNASH inspection cycle, keeping the 37 within an exact $\\pm1$ year.}",
"\\label{tab:pnash-strict-window}",
"\\small",
"\\begin{tabular}{lcccc}",
"\\toprule",
" & \\multicolumn{2}{c}{Cycle window (48)} & \\multicolumn{2}{c}{Strict $\\pm1$ (37)} \\\\",
"\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
"Outcome & ATT & 95\\% CI & ATT & 95\\% CI \\\\",
"\\midrule",
"\\multicolumn{5}{l}{\\textit{Sample composition}}\\\\",
sprintf("Closures & \\multicolumn{2}{c}{%d} & \\multicolumn{2}{c}{%d} \\\\",
        meta_get("PNASH_cycle_window","n_closures"), meta_get("PNASH_strict","n_closures")),
sprintf("Exposed municipalities & \\multicolumn{2}{c}{%d} & \\multicolumn{2}{c}{%d} \\\\",
        meta_get("PNASH_cycle_window","n_exposed"), meta_get("PNASH_strict","n_exposed")),
sprintf("Treatment cohorts & \\multicolumn{2}{c}{%d} & \\multicolumn{2}{c}{%d} \\\\",
        meta_get("PNASH_cycle_window","n_cohorts"), meta_get("PNASH_strict","n_cohorts")),
"\\addlinespace",
"\\multicolumn{5}{l}{\\textit{Population-weighted ATT [95\\% CI]}}\\\\",
sprintf("%s & %s & %s \\\\", labof["suicide_per100k"],  cell("PNASH_cycle_window","suicide_per100k"),  cell("PNASH_strict","suicide_per100k")),
sprintf("%s & %s & %s \\\\", labof["selfharm_per100k"], cell("PNASH_cycle_window","selfharm_per100k"), cell("PNASH_strict","selfharm_per100k")),
sprintf("%s & %s & %s \\\\", labof["psych_adm_per1k"],  cell("PNASH_cycle_window","psych_adm_per1k"),  cell("PNASH_strict","psych_adm_per1k")),
sprintf("%s & %s & %s \\\\", labof["travel_burden_km"], cell("PNASH_cycle_window","travel_burden_km"), cell("PNASH_strict","travel_burden_km")),
"\\addlinespace",
"\\multicolumn{5}{l}{\\textit{Pre-trend joint Wald $p$-value (leads $e\\in[-6,-2]$): cycle / strict}}\\\\",
sprintf("%s & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{} \\\\", labof["suicide_per100k"],  gsub(" & ", " / ", ptp("suicide_per100k"))),
sprintf("%s & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{} \\\\", labof["selfharm_per100k"], gsub(" & ", " / ", ptp("selfharm_per100k"))),
sprintf("%s & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{} \\\\", labof["psych_adm_per1k"],  gsub(" & ", " / ", ptp("psych_adm_per1k"))),
sprintf("%s & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{} \\\\", labof["travel_burden_km"], gsub(" & ", " / ", ptp("travel_burden_km"))),
"\\bottomrule",
"\\end{tabular}",
"\\begin{tablenotes}[flushleft]\\footnotesize",
"\\item \\textit{Window definitions.} PNASH (Programa Nacional de Avalia\\c{c}\\~ao dos Servi\\c{c}os Hospitalares) psychiatric inspections occur in discrete cycles. \\emph{Cycle window} assigns each closure to its nearest inspection cycle regardless of distance: all 48 closures qualify. \\emph{Strict $\\pm1$} keeps only closures within one calendar year of that cycle's year. The 11 excluded closures are all 2014 closures, which sit two years from the 2011--2012 cycle; the 37 retained closures all lie within $\\pm1$ year of their nearest cycle. Strict treatment status is reconstructed from the 37 closures only: a municipality is treated if patient-flow exposed to $\\ge 1$ strict closure (cohort year = earliest strict exposing closure), the 15 municipalities exposed \\emph{only} to the 11 dropped closures are removed (not reused as controls), and never-treated controls are unchanged.",
"\\item Pre-trend $p$-values are the diagonal joint Wald statistic on event-time leads $e\\in[-6,-2]$, matching the headline mortality scripts. Per-outcome cycle/strict pre-trend $p$-values are reported in \\texttt{pnash\\_strict\\_window\\_results.csv}.",
"\\end{tablenotes}",
"\\end{threeparttable}",
"\\end{table}")
writeLines(tex, TEX)
cat("[5] wrote", TEX, "\n")

cat(sprintf("\n==== done in %.1fs ====\n", as.numeric(Sys.time() - t0, units = "secs")))
