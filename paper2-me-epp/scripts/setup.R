# ============================================================================
# setup.R — Environment setup for replication package
# Usage: Rscript scripts/setup.R
# ============================================================================

cat("================================================================\n")
cat("  Paper 2 — Replication Package: Environment Setup\n")
cat("================================================================\n\n")

# ---- Check R version ------------------------------------------------------
cat("R version:", R.version.string, "\n")
if (getRversion() < "4.5") {
  stop("R >= 4.5 is required. You have ", R.version.string,
       ".\nPlease update R from https://cran.r-project.org/")
}
cat("  R version OK.\n\n")

# ---- Required packages ----------------------------------------------------
required <- c(
  "data.table",   # Data manipulation
  "fixest",       # Fixed-effects regression
  "arrow",        # Parquet I/O
  "ggplot2",      # Figures
  "scales",       # Axis formatting
  "grf",          # Causal forest
  "quantreg",     # Quantile regression
  "gridExtra"     # Multi-panel figures
)

cat("Checking", length(required), "required packages...\n")

missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  cat("  Installing missing packages:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  cat("  All packages already installed.\n")
}

# ---- Verify all packages load ---------------------------------------------
cat("\nVerifying all packages load...\n")
failures <- character(0)
for (pkg in required) {
  ok <- requireNamespace(pkg, quietly = TRUE)
  ver <- if (ok) as.character(packageVersion(pkg)) else "FAILED"
  status <- if (ok) "OK" else "FAILED"
  cat(sprintf("  %-12s %s  (%s)\n", pkg, status, ver))
  if (!ok) failures <- c(failures, pkg)
}

if (length(failures) > 0) {
  stop("Failed to load: ", paste(failures, collapse = ", "),
       "\nPlease install these packages manually.")
}

cat("\n================================================================\n")
cat("  Setup complete. All packages installed and verified.\n")
cat("  You can now run: Rscript scripts/00_master.R\n")
cat("================================================================\n")
