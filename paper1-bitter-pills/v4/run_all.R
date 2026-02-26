# =============================================================================
# run_all.R — Orchestrator for v4 R pipeline
# Bitter Pills to Swallow — G65 analysis with R/fixest
# =============================================================================

cat("=============================================================\n")
cat("  Bitter Pills v4 — Full R Pipeline\n")
cat("  Dataset: BEC-G65-WORK1.parquet (Group 65)\n")
cat("=============================================================\n\n")

t_start <- Sys.time()

# --- Check/install packages --------------------------------------------------
required_pkgs <- c("data.table", "fixest", "modelsummary", "ggplot2",
                   "arrow", "knitr", "scales")
missing <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  cat("Installing missing packages:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = "https://cloud.r-project.org")
}

# --- Script directory --------------------------------------------------------
script_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(file.path(normalizePath(dirname(f)), "analysis"))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(file.path(normalizePath(dirname(sub("^--file=", "", fa[1]))), "analysis"))
  "paper1-bitter-pills/v4/analysis"
})()

# --- Sequential execution (fixest uses OpenMP internally) --------------------
scripts <- c(
  "00_prepare_data.R",
  "01_desc_stats.R",
  "02_balance_table.R",
  "03_main_regressions.R",
  "04_heterogeneity.R",
  "05_fiscal_costs.R",
  "06_robustness.R",
  "07_graphs.R"
)

timings <- data.frame(script = scripts, seconds = NA_real_,
                      status = "pending", stringsAsFactors = FALSE)

for (i in seq_along(scripts)) {
  script_path <- file.path(script_dir, scripts[i])
  cat("\n=============================================================\n")
  cat(sprintf("  [%d/%d] Running: %s\n", i, length(scripts), scripts[i]))
  cat("=============================================================\n")

  t_script <- Sys.time()
  tryCatch({
    source(script_path, local = new.env(parent = globalenv()))
    elapsed <- as.numeric(difftime(Sys.time(), t_script, units = "secs"))
    timings$seconds[i] <- elapsed
    timings$status[i] <- "OK"
    cat(sprintf("  [%d/%d] %s completed in %.1f seconds\n",
                i, length(scripts), scripts[i], elapsed))
  }, error = function(e) {
    elapsed <- as.numeric(difftime(Sys.time(), t_script, units = "secs"))
    timings$seconds[i] <<- elapsed
    timings$status[i] <<- paste("ERROR:", conditionMessage(e))
    cat(sprintf("  [%d/%d] %s FAILED after %.1f seconds: %s\n",
                i, length(scripts), scripts[i], elapsed, conditionMessage(e)))
  })
}

# --- Summary -----------------------------------------------------------------
t_total <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

cat("\n\n=============================================================\n")
cat("  PIPELINE SUMMARY\n")
cat("=============================================================\n\n")

cat(sprintf("%-25s %10s %10s\n", "Script", "Time (s)", "Status"))
cat(strrep("-", 50), "\n")
for (i in seq_along(scripts)) {
  cat(sprintf("%-25s %10.1f %10s\n",
              scripts[i], timings$seconds[i], timings$status[i]))
}
cat(strrep("-", 50), "\n")
cat(sprintf("%-25s %10.1f\n", "TOTAL", t_total))

# --- Output verification ----------------------------------------------------
v4_dir <- file.path(dirname(script_dir))

n_tex  <- length(list.files(file.path(v4_dir, "manuscript"), pattern = "\\.tex$"))
n_html <- length(list.files(file.path(v4_dir, "results"),    pattern = "\\.html$"))
n_pdf  <- length(list.files(file.path(v4_dir, "graphs"),     pattern = "\\.pdf$"))
n_txt  <- length(list.files(file.path(v4_dir, "results"),    pattern = "\\.txt$"))

cat(sprintf("\nOutputs: %d .tex, %d .html, %d .pdf, %d .txt\n",
            n_tex, n_html, n_pdf, n_txt))

n_errors <- sum(grepl("ERROR", timings$status))
if (n_errors > 0) {
  cat(sprintf("\nWARNING: %d script(s) failed! Check errors above.\n", n_errors))
} else {
  cat("\nAll scripts completed successfully.\n")
}

cat(sprintf("Total time: %.1f seconds (%.1f minutes)\n", t_total, t_total / 60))
cat("=============================================================\n")
