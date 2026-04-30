# ============================================================================
# 16_run_v8_legacy.R — Re-run all v8 scripts to verify legacy numbers
# Paper 3 v14: forensic audit ⚠️ → ✅/❌ verification
#
# Each v8 script produces output that the v13 manuscript cites. This
# sequencer runs them with the current data and current FL classification,
# captures stdout/stderr per script, and lets us mark each entry in
# work/v13/forensic_audit.md as reproducible or not.
#
# Output: per-script log under logs/v8_<script>.log + a summary table
# at output/v8_legacy_audit/v8_run_summary.csv with status (OK / ERROR /
# SKIPPED) and elapsed time.
#
# Run order is sensitive: scripts depend on shared caches at /tmp/p3_*.rds
# produced by 01_clean.R + 02_analysis.R. 00_master.R must run first.
# ============================================================================

cat("=== 16_run_v8_legacy.R: re-run v8 scripts for forensic audit ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")

BASE      <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
V8_DIR    <- file.path(BASE, "work", "v8", "scripts")
LOGS_DIR  <- file.path(BASE, "logs")
OUT_DIR   <- file.path(BASE, "output", "v8_legacy_audit")
dir.create(LOGS_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_DIR,  recursive = TRUE, showWarnings = FALSE)

# Pre-flight: canonical caches must exist
required_caches <- c("/tmp/p3_prepared.rds", "/tmp/p3_models.rds",
                     "/tmp/p3_freq_particip.rds", "/tmp/p3_firms.rds",
                     "/tmp/p3_firm_loss_stats.rds")
missing <- required_caches[!file.exists(required_caches)]
if (length(missing) > 0) {
  stop("Missing canonical caches: ", paste(missing, collapse = ", "),
       "\nRun 00_master.R first (or 01_clean.R + 02_analysis.R).")
}
cat("  Canonical caches found.\n\n")

# Execution plan: each script + which ⚠️ numbers it produces (per forensic_audit)
plan <- list(
  list(script = "flag1_bajari_ye_corrected.R",
       numbers = "Bajari-Ye D, t-stat, first-stage R², tender-FE drops"),
  list(script = "flag2_cade_enforcement_did.R",
       numbers = "Callaway-Sant'Anna ATT (FL exit, price)"),
  list(script = "flag3_crossfit_check.R",
       numbers = "Cross-fit decomposition coefficient"),
  list(script = "mechanism_evidence.R",
       numbers = "M1 (+0.143 non-FL), M2 (-0.041 ref-price), M3 (0.0021 lagged-price)"),
  list(script = "imhof_comparison.R",
       numbers = "Imhof CV AUC (0.79), suppression effect (0.064→0.084)"),
  list(script = "ground_truth_robustness.R",
       numbers = "Conditional FL-CADE p=0.93"),
  list(script = "counterfactual_welfare.R",
       numbers = "Welfare bounds (0.3-0.9% of spending)"),
  list(script = "latent_class_validation.R",
       numbers = "LCA cover_class identification"),
  list(script = "structural_estimation.R",
       numbers = "Cartel calibration parameters"),
  list(script = "alternative_classification.R",
       numbers = "IQR threshold sensitivity (0.079, 0.064, 0.060, 0.050)"),
  list(script = "fl_participation_rationality.R",
       numbers = "Rationality table (R$700-7000, R$2500-25000)")
)

# Run each script with proper context, capturing stdout/stderr.
results <- list()

for (i in seq_along(plan)) {
  entry <- plan[[i]]
  script_path <- file.path(V8_DIR, entry$script)
  log_file <- file.path(LOGS_DIR, sprintf("v8_%s.log",
                        sub("\\.R$", "", entry$script)))

  cat(sprintf("\n[%d/%d] %s\n", i, length(plan), entry$script))
  cat(sprintf("       expected outputs: %s\n", entry$numbers))

  if (!file.exists(script_path)) {
    cat(sprintf("       SKIPPED: script not found at %s\n", script_path))
    results[[length(results) + 1]] <- data.table::data.table(
      script = entry$script, status = "MISSING", elapsed_sec = NA,
      log_file = NA_character_, expected = entry$numbers
    )
    next
  }

  t0 <- Sys.time()

  # Run script with .v8_dir set so it can resolve its paths. Use a
  # subprocess so a segfault or infinite loop doesn't kill our sequencer.
  cmd <- sprintf(
    'Rscript -e \'.v8_dir <- "%s"; .script_dir <- "%s"; tryCatch(source("%s"), error = function(e) { cat("FATAL:", conditionMessage(e), "\\n"); quit(status = 1) })\'',
    file.path(BASE, "work", "v8"),
    V8_DIR,
    script_path
  )
  rc <- system(sprintf("cd %s && %s > %s 2>&1",
                       shQuote(BASE), cmd, shQuote(log_file)))

  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  status  <- if (rc == 0) "OK" else "ERROR"

  cat(sprintf("       %s   %.1fs   log: %s\n", status, elapsed,
              basename(log_file)))

  results[[length(results) + 1]] <- data.table::data.table(
    script    = entry$script,
    status    = status,
    elapsed_sec = round(elapsed, 1),
    log_file  = basename(log_file),
    expected  = entry$numbers
  )
}

# ---- Summary --------------------------------------------------------------
summary_dt <- data.table::rbindlist(results, fill = TRUE)
data.table::fwrite(summary_dt, file.path(OUT_DIR, "v8_run_summary.csv"))

cat("\n========================================================\n")
cat("  Summary\n")
cat("========================================================\n")
print(summary_dt[, .(script, status, elapsed_sec)])
cat(sprintf("\n  Total: %d scripts, %d OK, %d ERROR, %d MISSING\n",
            nrow(summary_dt),
            sum(summary_dt$status == "OK"),
            sum(summary_dt$status == "ERROR"),
            sum(summary_dt$status == "MISSING")))
cat(sprintf("  Total elapsed: %.1f minutes\n",
            sum(summary_dt$elapsed_sec, na.rm = TRUE) / 60))
cat(sprintf("\n  Saved: %s\n", file.path(OUT_DIR, "v8_run_summary.csv")))
cat("\n  Per-script logs at:", LOGS_DIR, "\n")
cat("\n  Done.\n")
