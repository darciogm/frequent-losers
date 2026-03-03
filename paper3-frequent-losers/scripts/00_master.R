# ============================================================================
# 00_master.R — Paper 3 pipeline orchestrator
# Usage: Rscript scripts/00_master.R   (from paper3-frequent-losers/ root)
# ============================================================================

cat("================================================================\n")
cat("  Paper 3 — Frequent Losers in Public Procurement Pipeline\n")
cat("  Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("================================================================\n\n")

pipeline_start <- Sys.time()

# ---- Pre-flight checks -----------------------------------------------------
cat("--- Pre-flight checks ---\n")
cat("  System:", Sys.info()["sysname"], Sys.info()["release"], "\n")
cat("  R version:", R.version.string, "\n")
cat("  Cores:", parallel::detectCores(), "\n")

mem_info <- tryCatch({
  if (Sys.info()["sysname"] == "Linux") {
    mi <- system("grep MemTotal /proc/meminfo", intern = TRUE)
    paste(round(as.numeric(gsub("[^0-9]", "", mi)) / 1024 / 1024, 1), "GB")
  } else "unknown"
}, error = function(e) "unknown")
cat("  RAM:", mem_info, "\n")

if (getRversion() < "4.5") {
  stop("R >= 4.5 is required. You have ", R.version.string,
       ".\nPlease update R from https://cran.r-project.org/")
}

# ---- Check required packages -----------------------------------------------
required <- c("data.table", "fixest", "ggplot2", "arrow", "scales",
               "sensemakr", "MatchIt")
optional <- c("grf")

missing  <- required[!sapply(required, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  stop("Missing packages: ", paste(missing, collapse = ", "),
       "\nRun: install.packages(c('", paste(missing, collapse = "', '"), "'))")
}
cat("  All", length(required), "required packages found.\n")

missing_opt <- optional[!sapply(optional, requireNamespace, quietly = TRUE)]
if (length(missing_opt) > 0) {
  cat("  Optional packages not found (some analyses will be skipped):",
      paste(missing_opt, collapse = ", "), "\n")
}

# ---- Check data availability -----------------------------------------------
data_dir <- file.path("data", "processed")
required_files <- c("BEC_collapse_final.parquet", "LOSERS_rebuilt.parquet",
                     "FREQ_PARTICIP_rebuilt.parquet", "Firms_final.parquet")
missing_files <- required_files[!file.exists(file.path(data_dir, required_files))]
if (length(missing_files) > 0) {
  stop("Missing data files in ", data_dir, ":\n  ",
       paste(missing_files, collapse = "\n  "))
}
cat("  All", length(required_files), "data files found.\n")

# Check bid-level data (optional but recommended)
bidlevel_files <- c("bid_level_full.parquet", "firm_tender_map.parquet",
                     "firm_loss_stats.parquet")
missing_bl <- bidlevel_files[!file.exists(file.path(data_dir, bidlevel_files))]
if (length(missing_bl) > 0) {
  cat("  Bid-level parquets not found. Running Python extraction...\n")
  py_script <- file.path("scripts", "00_build_bidlevel.py")
  if (file.exists(py_script)) {
    py_rc <- system(paste("python3", py_script))
    if (py_rc != 0) {
      cat("  WARNING: Python bid-level extraction failed (exit", py_rc, ").\n")
      cat("  Some analyses (threshold reclassification, figures 3-8) will be approximate.\n")
    } else {
      cat("  Bid-level data extracted successfully.\n")
    }
  } else {
    cat("  WARNING:", py_script, "not found. Skipping bid-level extraction.\n")
  }
} else {
  cat("  Bid-level parquets found:", paste(bidlevel_files, collapse = ", "), "\n")
}

cat("--- Pre-flight checks passed ---\n\n")

# ---- Resolve script directory -----------------------------------------------
script_dir <- NULL
if (!interactive()) {
  args <- commandArgs(trailingOnly = FALSE)
  file_args <- grep("^--file=", args, value = TRUE)
  if (length(file_args) == 1) {
    script_dir <- dirname(sub("^--file=", "", file_args))
  }
}
if (is.null(script_dir) || is.na(script_dir) || script_dir == "" || script_dir == ".") {
  script_dir <- file.path(getwd(), "scripts")
}

# ---- Run scripts as separate processes (prevents OOM on 15 GB RAM) ----------
scripts <- c("01_clean.R", "02_analysis.R", "03_tables.R", "04_figures.R",
             "05_robustness.R", "06_did_temporal.R", "07_heterogeneity.R",
             "08_additional_dvs.R", "09_matching.R", "10_fl_characteristics.R")
timings <- data.frame(script = character(), seconds = numeric(), status = character(),
                      stringsAsFactors = FALSE)

for (s in scripts) {
  path <- file.path(script_dir, s)
  cat("\n--- Running:", s, "---\n")
  t0 <- Sys.time()

  cmd <- sprintf("Rscript -e \".script_dir <- '%s'; source('%s')\"",
                 script_dir, path)
  rc <- system(cmd)

  result <- if (rc == 0) "OK" else paste0("FAILED (exit code ", rc, ")")
  if (rc != 0) cat("  ERROR in", s, "(exit code", rc, ")\n")

  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  timings <- rbind(timings, data.frame(script = s, seconds = round(elapsed, 1),
                                       status = result, stringsAsFactors = FALSE))
}

# ---- Summary ----------------------------------------------------------------
total_time <- as.numeric(difftime(Sys.time(), pipeline_start, units = "secs"))

cat("\n================================================================\n")
cat("  Pipeline Summary\n")
cat("================================================================\n")
print(timings, row.names = FALSE)
cat(sprintf("\n  Total time: %.1f seconds (%.1f minutes)\n", total_time, total_time / 60))

# Count outputs
n_tex <- length(list.files(file.path(script_dir, "..", "output", "tables"), pattern = "\\.tex$"))
n_pdf <- length(list.files(file.path(script_dir, "..", "output", "figures"), pattern = "\\.pdf$"))
cat(sprintf("  Outputs: %d .tex tables, %d .pdf figures\n", n_tex, n_pdf))

if (any(grepl("FAILED", timings$status))) {
  cat("\n  WARNING: Some scripts failed. Check errors above.\n")
} else {
  cat("\n  All scripts completed successfully.\n")
}
cat("================================================================\n")
