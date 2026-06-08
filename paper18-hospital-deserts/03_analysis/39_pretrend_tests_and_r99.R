#!/usr/bin/env Rscript
# 39_pretrend_tests_and_r99.R
#
# Path2 #4 (parecer Major #4 + #9):
#   (a) F-test joint pre-trend coefficients (e<0) for travel x E1, travel x E2,
#       ICSAP x E1, ICSAP x E2 (4 specs).
#   (b) Sun-Abraham re-estimation incluindo municipality-year R99 fraction
#       como time-varying control. Reportar travel x E1 e ICSAP x E1 com R99
#       partialled out.
#
# Output: 04_logs/39_pretrend_r99.json + 01_manuscript/tables/tab_pretrend_r99.tex

suppressPackageStartupMessages({
  library(arrow); library(data.table); library(fixest); library(jsonlite)
})

args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grepl("--file=", args)])
ROOT <- if (length(script_arg) > 0) {
  normalizePath(file.path(dirname(script_arg), ".."))
} else { normalizePath(getwd()) }
INTER <- file.path(ROOT, "02_data", "intermediate")
LOG_DIR <- file.path(ROOT, "04_logs")
TAB_DIR <- file.path(ROOT, "01_manuscript", "tables")

cat("==== begin pre-trend tests + R99 ====\n")
t0 <- Sys.time()

panel <- as.data.table(read_parquet(file.path(INTER, "staggered_panel_F5_main.parquet")))

# (a) pre-trend F-tests via Sun-Abraham
run_with_pretrend_test <- function(panel, yname, gname_col) {
  d <- panel[is.finite(get(yname))]
  d[, gn_use := ifelse(is.na(get(gname_col)) | get(gname_col) == 0,
                        10000L, as.integer(get(gname_col)))]
  fml <- as.formula(sprintf("%s ~ sunab(gn_use, year) | muni_id + year", yname))
  m <- feols(fml, data = d, cluster = "muni_id")
  cf_all <- coef(m)
  V <- vcov(m)
  nm <- names(cf_all)
  pre_idx <- which(grepl("^year::", nm))
  pre_e <- as.integer(sub("^year::", "", nm[pre_idx]))
  keep <- pre_idx[pre_e < -1 & pre_e >= -7]
  if (length(keep) == 0) return(NULL)
  b <- cf_all[keep]
  Vsub <- as.matrix(V[keep, keep, drop = FALSE])
  W <- as.numeric(t(b) %*% solve(Vsub, b))
  k <- length(b)
  pval <- 1 - pchisq(W, df = k)
  cat(sprintf("  pre-trend joint Wald test  k=%d  W=%.2f  p=%.4f\n", k, W, pval))

  list(W = W, k = k, pval_joint_pre = pval,
       pre_coefs = as.numeric(b), pre_ses = sqrt(diag(Vsub)))
}

results_pre <- list()
for (yn in c("travel_burden_km", "icsap_per1k")) {
  for (gn in c("g_emb", "g_km")) {
    key <- sprintf("%s__%s", yn, gn)
    cat(sprintf("\n=== %s ===\n", key))
    r <- run_with_pretrend_test(panel, yn, gn)
    if (!is.null(r)) results_pre[[key]] <- r
  }
}

# (b) R99 time-varying control. Construir municipality-year R96-R99 fraction
cat("\n==== R99 fraction control ====\n")
simq <- as.data.table(read_parquet(file.path(INTER, "sim_quality_panel.parquet")))
simq[, r99_frac := ifelse(n_total_deaths > 0,
                          as.numeric(n_r96_r99) / as.numeric(n_total_deaths), NA_real_)]
mort_short <- simq[, .(codmun_6, year, r99_frac)]
panel[, codmun_6 := as.character(codmun_6)]
mort_short[, codmun_6 := as.character(codmun_6)]
panel_r99 <- merge(panel, mort_short, by = c("codmun_6", "year"), all.x = TRUE)
cat(sprintf("rows w/ R99: %d (of %d)\n",
            panel_r99[!is.na(r99_frac), .N], nrow(panel_r99)))

run_with_r99 <- function(panel, yname, gname_col) {
  d <- panel[is.finite(get(yname)) & !is.na(r99_frac)]
  d[, gn_use := ifelse(is.na(get(gname_col)) | get(gname_col) == 0,
                        10000L, as.integer(get(gname_col)))]
  fml <- as.formula(sprintf(
    "%s ~ sunab(gn_use, year) + r99_frac | muni_id + year", yname))
  m <- tryCatch(feols(fml, data = d, cluster = "muni_id"),
                error = function(e) { cat("ERR:", conditionMessage(e), "\n"); NULL })
  if (is.null(m)) return(NULL)
  agg <- summary(m, agg = "att")
  list(att = as.numeric(coef(agg)[1]), se = as.numeric(se(agg)[1]),
       n_obs = nrow(d))
}

results_r99 <- list()
for (yn in c("travel_burden_km", "icsap_per1k")) {
  cat(sprintf("\n--- %s + R99 control ---\n", yn))
  r <- run_with_r99(panel_r99, yn, "g_emb")
  if (!is.null(r)) {
    cat(sprintf("  ATT=%+.3f  SE=%.3f  n=%d\n", r$att, r$se, r$n_obs))
    results_r99[[yn]] <- r
  }
}

# ---- combine + JSON ----
out <- list(
  pretrend_tests = lapply(results_pre, function(r) {
    list(W = r$W, k = r$k, pval = r$pval_joint_pre)
  }),
  r99_control = results_r99
)
write(toJSON(out, auto_unbox = TRUE, pretty = TRUE),
      file.path(LOG_DIR, "39_pretrend_r99.json"))
cat("wrote 39_pretrend_r99.json\n")

# ---- LaTeX table ----
tab <- c(
  "\\begin{table}[h!]",
  "\\centering",
  "\\caption{Formal pre-trend tests and R$99$ time-varying control. \\emph{Top panel}: joint Wald test that all pre-period event-study coefficients $\\hat{\\delta}_{e \\in [-7, -2]}$ are zero. \\emph{Bottom panel}: Sun-Abraham re-estimation including the municipality-year R$96$--R$99$ ill-defined-cause death fraction as a time-varying covariate.}",
  "\\label{tab:pretrend-r99}",
  "\\small",
  "\\begin{tabular}{llrrr}",
  "\\toprule",
  "Outcome & Exposure & $W$ stat & d.f. & $p$-value \\\\",
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Joint Wald test of pre-trends} ($H_0$: all $\\hat{\\delta}_{e<-1} = 0$)} \\\\")
for (key in names(results_pre)) {
  parts <- strsplit(key, "__")[[1]]
  yn <- parts[1]; gn <- parts[2]
  r <- results_pre[[key]]
  yname <- ifelse(yn == "travel_burden_km", "Travel (km)", "ICSAP per 1k")
  enm <- ifelse(gn == "g_emb", "E1 (embedding)", "E2 (alternative exposure rule)")
  sig <- ifelse(r$pval_joint_pre < 0.01, "$^{***}$",
         ifelse(r$pval_joint_pre < 0.05, "$^{**}$",
         ifelse(r$pval_joint_pre < 0.10, "$^{*}$", "")))
  tab <- c(tab, sprintf("%s & %s & %.2f & %d & %.4f%s \\\\",
                         yname, enm, r$W, r$k, r$pval_joint_pre, sig))
}
tab <- c(tab, "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Sun-Abraham simple ATT with R$99$ time-varying control (E1 only)}} \\\\")
for (yn in names(results_r99)) {
  r <- results_r99[[yn]]
  yname <- ifelse(yn == "travel_burden_km", "Travel (km)", "ICSAP per 1k")
  z <- abs(r$att / max(r$se, 1e-9))
  sig <- ifelse(z > 2.58, "$^{***}$", ifelse(z > 1.96, "$^{**}$",
        ifelse(z > 1.64, "$^{*}$", "")))
  tab <- c(tab, sprintf("%s & E1 + R$99$ ctrl & $%+.3f$%s & SE %.3f & $n = %d$ \\\\",
                         yname, r$att, sig, r$se, r$n_obs))
}
tab <- c(tab, "\\bottomrule",
  "\\multicolumn{5}{l}{\\footnotesize $^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01.} \\\\",
  "\\end{tabular}", "\\end{table}")
writeLines(tab, file.path(TAB_DIR, "tab_pretrend_r99.tex"))
cat("wrote tab_pretrend_r99.tex\n")

cat(sprintf("==== done %.0fs ====\n", as.numeric(Sys.time() - t0, units = "secs")))
