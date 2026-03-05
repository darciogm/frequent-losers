# ============================================================================
# 00_master_v4.R — Paper 3 v4 pipeline orchestrator
# Paper 3 v4: Frequent Losers in Public Procurement
# Addressing Referee Reports R1 & R2
# Usage: Rscript v4/code/00_master_v4.R  (from paper3-frequent-losers/ root)
# ============================================================================

cat("================================================================\n")
cat("  Paper 3 v4 — Frequent Losers Pipeline\n")
cat("  Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================\n\n")

pipeline_start <- Sys.time()

# ---- Pre-flight checks -------------------------------------------------------
cat("--- Pre-flight checks ---\n")
cat("  System:", Sys.info()["sysname"], Sys.info()["release"], "\n")
cat("  R version:", R.version.string, "\n")
cat("  Cores:", parallel::detectCores(), "\n")

if (getRversion() < "4.3") {
  stop("R >= 4.3 is required. You have ", R.version.string)
}

# Check required packages
required <- c("data.table", "fixest", "ggplot2", "arrow", "scales",
               "sensemakr", "MatchIt")
missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  stop("Missing packages: ", paste(missing, collapse = ", "),
       "\nRun: install.packages(c('", paste(missing, collapse = "', '"), "'))")
}
cat("  All", length(required), "required packages found.\n")

# Check data — parquets are in the parent directory (paper3-frequent-losers/data/processed/)
data_dir <- file.path("..", "data", "processed")
if (!dir.exists(data_dir)) data_dir <- file.path("data", "processed")
required_files <- c("BEC_collapse_final.parquet", "LOSERS_rebuilt.parquet",
                     "FREQ_PARTICIP_rebuilt.parquet", "Firms_final.parquet",
                     "firm_tender_map.parquet")
missing_files <- required_files[!file.exists(file.path(data_dir, required_files))]
if (length(missing_files) > 0) {
  stop("Missing data files in ", data_dir, ":\n  ",
       paste(missing_files, collapse = "\n  "))
}
cat("  All data files found.\n")

# ---- Resolve script directory -------------------------------------------------
v4_code_dir <- NULL
if (!interactive()) {
  args <- commandArgs(trailingOnly = FALSE)
  file_args <- grep("^--file=", args, value = TRUE)
  if (length(file_args) == 1) {
    v4_code_dir <- dirname(sub("^--file=", "", file_args))
  }
}
if (is.null(v4_code_dir) || v4_code_dir == "." || v4_code_dir == "") {
  v4_code_dir <- file.path(getwd(), "v4", "code")
}
v4_dir <- normalizePath(file.path(v4_code_dir, ".."), mustWork = FALSE)

cat("  v4 code dir:", v4_code_dir, "\n")
cat("--- Pre-flight checks passed ---\n\n")

# ---- Run R scripts as separate processes -------------------------------------
scripts <- c(
  # Phase 1: Data infrastructure
  "01_data_prep.R",
  "02_network_analysis.R",
  "03_iv_construction.R",
  # Phase 2: Core analyses
  "04_iv_regressions.R",
  "05_main_regressions.R",
  "06_bajari_ye_test.R",
  "07_mechanism_tests.R",
  "08_did_revised.R",
  "09_cade_permutation.R",
  # Phase 3: Robustness
  "10_robustness.R",
  "11_welfare_bounds.R",
  "15_fl_definition_robustness.R",
  "16_regime_test.R",
  # Phase 4: Outputs
  "12_tables.R",
  "13_figures.R",
  "14_quality_checks.R"
)

timings <- data.frame(script = character(), seconds = numeric(), status = character(),
                      stringsAsFactors = FALSE)

for (s in scripts) {
  path <- file.path(v4_code_dir, s)
  if (!file.exists(path)) {
    cat(sprintf("\n--- SKIPPING: %s (file not found) ---\n", s))
    timings <- rbind(timings, data.frame(script = s, seconds = 0,
                                         status = "SKIPPED", stringsAsFactors = FALSE))
    next
  }

  cat(sprintf("\n--- Running: %s ---\n", s))
  t0 <- Sys.time()

  cmd <- sprintf("Rscript -e \".v4_dir <- '%s'; source('%s')\"", v4_dir, path)
  rc <- system(cmd)

  result <- if (rc == 0) "OK" else paste0("FAILED (exit code ", rc, ")")
  if (rc != 0) cat("  ERROR in", s, "(exit code", rc, ")\n")

  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  timings <- rbind(timings, data.frame(script = s, seconds = round(elapsed, 1),
                                       status = result, stringsAsFactors = FALSE))
}

# ---- Summary ------------------------------------------------------------------
total_time <- as.numeric(difftime(Sys.time(), pipeline_start, units = "secs"))

cat("\n================================================================\n")
cat("  Pipeline Summary\n")
cat("================================================================\n")
print(timings, row.names = FALSE)
cat(sprintf("\n  Total time: %.1f seconds (%.1f minutes)\n", total_time, total_time / 60))

n_tex <- length(list.files(file.path(v4_dir, "output", "tables"), pattern = "\\.tex$"))
n_pdf <- length(list.files(file.path(v4_dir, "output", "figures"), pattern = "\\.pdf$"))
cat(sprintf("  Outputs: %d .tex tables, %d .pdf figures\n", n_tex, n_pdf))

n_failed <- sum(grepl("FAILED", timings$status))
n_skipped <- sum(grepl("SKIPPED", timings$status))
if (n_failed > 0) {
  cat(sprintf("\n  WARNING: %d scripts failed. Check errors above.\n", n_failed))
} else if (n_skipped > 0) {
  cat(sprintf("\n  %d scripts skipped (not yet implemented), %d completed.\n",
              n_skipped, sum(timings$status == "OK")))
} else {
  cat("\n  All scripts completed successfully.\n")
}
cat("================================================================\n")
