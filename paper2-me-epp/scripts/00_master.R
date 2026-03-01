# ============================================================================
# 00_master.R — Paper 2 pipeline orchestrator
# Usage: Rscript scripts/00_master.R   (from project root)
# ============================================================================

cat("================================================================\n")
cat("  Paper 2 — SMEs and Public Procurement Pipeline\n")
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
               "grf", "quantreg", "gridExtra")
missing  <- required[!sapply(required, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  stop("Missing packages: ", paste(missing, collapse = ", "),
       "\nRun: Rscript scripts/setup.R")
}
cat("  All", length(required), "required packages found.\n")

# ---- Check data availability -----------------------------------------------
if (!file.exists("data/raw/Paper2_ME_EPP.csv") &&
    !file.exists("data/processed/paper2_me_epp.parquet")) {
  stop("Raw data not found. Place Paper2_ME_EPP.csv in data/raw/.\n",
       "See data/raw/README_data.md for access instructions.")
}
cat("  Data files found.\n")
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
scripts <- c("01_clean.R", "02_analysis.R", "05_robustness.R",
             "06_extensions.R", "07_advanced.R", "03_tables.R", "04_figures.R")
timings <- data.frame(script = character(), seconds = numeric(), status = character(),
                      stringsAsFactors = FALSE)

for (s in scripts) {
  path <- file.path(script_dir, s)
  cat("\n--- Running:", s, "---\n")
  t0 <- Sys.time()

  # Run each script as a separate Rscript subprocess so the OS fully
  # reclaims memory between scripts (15 GB RAM is too tight for in-process)
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
