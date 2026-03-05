# ============================================================================
# 00_master_v2.R — Paper 3 v2 pipeline orchestrator
# Paper 3 v2: Frequent Losers as Cover Bidders in Public Procurement
# Usage: Rscript v2/code/00_master_v2.R  (from paper3-frequent-losers/ root)
# ============================================================================

cat("================================================================\n")
cat("  Paper 3 v2 — Cover Bidders Pipeline\n")
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

# Check data
data_dir <- file.path("data", "processed")
required_files <- c("BEC_collapse_final.parquet", "LOSERS_rebuilt.parquet",
                     "FREQ_PARTICIP_rebuilt.parquet", "Firms_final.parquet")
missing_files <- required_files[!file.exists(file.path(data_dir, required_files))]
if (length(missing_files) > 0) {
  stop("Missing data files in ", data_dir, ":\n  ",
       paste(missing_files, collapse = "\n  "))
}
cat("  All data files found.\n")

# ---- Resolve script directory -------------------------------------------------
v2_code_dir <- NULL
if (!interactive()) {
  args <- commandArgs(trailingOnly = FALSE)
  file_args <- grep("^--file=", args, value = TRUE)
  if (length(file_args) == 1) {
    v2_code_dir <- dirname(sub("^--file=", "", file_args))
  }
}
if (is.null(v2_code_dir) || v2_code_dir == "." || v2_code_dir == "") {
  v2_code_dir <- file.path(getwd(), "v2", "code")
}
v2_dir <- normalizePath(file.path(v2_code_dir, ".."), mustWork = FALSE)

cat("  v2 code dir:", v2_code_dir, "\n")
cat("--- Pre-flight checks passed ---\n\n")

# ---- Check if Python build is needed -----------------------------------------
bid_price_file <- file.path(v2_dir, "data", "processed", "bid_level_with_prices.parquet")
if (!file.exists(bid_price_file)) {
  py_script <- file.path(v2_code_dir, "00_build_bidlevel_v2.py")
  if (file.exists(py_script)) {
    cat("--- Running Python bid-level build ---\n")
    py_rc <- system(paste("python3", py_script))
    if (py_rc != 0) {
      cat("  WARNING: Python build failed (exit", py_rc, ").\n")
      cat("  Continuing without bid-level prices (some analyses will be limited).\n")
    }
  } else {
    cat("  NOTE: 00_build_bidlevel_v2.py not found at", py_script, "\n")
    cat("  Continuing without bid-level prices.\n")
  }
} else {
  cat("  bid_level_with_prices.parquet found.\n")
}

# ---- Run R scripts as separate processes --------------------------------------
scripts <- c(
  "01_data_prep.R",
  "03_data_diagnostics.R",
  "04_cover_bid_flags.R",
  "05_bajari_ye_test.R",
  "06_main_regressions.R",
  "07_mechanism_tests.R",
  "08_did_callaway_santanna.R",
  "09_rdd_thresholds.R",
  "11_welfare.R",
  "12_robustness.R",
  "13_tables.R",
  "14_figures.R",
  "15_quality_checks.R"
)

timings <- data.frame(script = character(), seconds = numeric(), status = character(),
                      stringsAsFactors = FALSE)

for (s in scripts) {
  path <- file.path(v2_code_dir, s)
  cat("\n--- Running:", s, "---\n")
  t0 <- Sys.time()

  cmd <- sprintf("Rscript -e \".v2_dir <- '%s'; source('%s')\"", v2_dir, path)
  rc <- system(cmd)

  result <- if (rc == 0) "OK" else paste0("FAILED (exit code ", rc, ")")
  if (rc != 0) cat("  ERROR in", s, "(exit code", rc, ")\n")

  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  timings <- rbind(timings, data.frame(script = s, seconds = round(elapsed, 1),
                                       status = result, stringsAsFactors = FALSE))

  # STOP after diagnostics if explicitly requested
  if (s == "03_data_diagnostics.R" && rc == 0) {
    diag_log <- file.path(v2_dir, "output", "logs", "diagnostics.txt")
    if (file.exists(diag_log)) {
      cat("\n  *** DIAGNOSTICS COMPLETE — Review", diag_log, "***\n")
    }
  }
}

# ---- Run Python ML script ----------------------------------------------------
cat("\n--- Running: 10_ml_screens.py ---\n")
t0 <- Sys.time()
py_ml <- file.path(v2_code_dir, "10_ml_screens.py")
if (file.exists(py_ml)) {
  rc <- system(paste("python3", py_ml))
  result <- if (rc == 0) "OK" else paste0("FAILED (exit code ", rc, ")")
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  timings <- rbind(timings, data.frame(script = "10_ml_screens.py",
                                       seconds = round(elapsed, 1),
                                       status = result, stringsAsFactors = FALSE))
}

# ---- Summary ------------------------------------------------------------------
total_time <- as.numeric(difftime(Sys.time(), pipeline_start, units = "secs"))

cat("\n================================================================\n")
cat("  Pipeline Summary\n")
cat("================================================================\n")
print(timings, row.names = FALSE)
cat(sprintf("\n  Total time: %.1f seconds (%.1f minutes)\n", total_time, total_time / 60))

n_tex <- length(list.files(file.path(v2_dir, "output", "tables"), pattern = "\\.tex$"))
n_pdf <- length(list.files(file.path(v2_dir, "output", "figures"), pattern = "\\.pdf$"))
cat(sprintf("  Outputs: %d .tex tables, %d .pdf figures\n", n_tex, n_pdf))

if (any(grepl("FAILED", timings$status))) {
  cat("\n  WARNING: Some scripts failed. Check errors above.\n")
} else {
  cat("\n  All scripts completed successfully.\n")
}
cat("================================================================\n")
