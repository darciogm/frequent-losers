# Orchestrator for the v4 R pipeline.

t_start <- Sys.time()

required_pkgs <- c("data.table", "fixest", "modelsummary", "ggplot2",
                   "arrow", "knitr", "scales",
                   "haven", "sf", "geobr", "sidrar")
missing <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  cat("Installing missing packages:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, repos = "https://cloud.r-project.org")
}

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

scripts <- c(
  "00_prepare_data.R",
  "01_desc_stats.R",
  "02_balance_table.R",
  "03_main_regressions.R",
  "04_heterogeneity.R",
  "05_fiscal_costs.R",
  "06_robustness.R",
  "07_graphs.R",
  "08_pub_tables.R",
  "09_pub_figures.R",
  "10_map_litigation.R",
  "11_map_pbu.R",
  "12_fig_purchase_types.R"
)

timings <- data.frame(script = scripts, seconds = NA_real_,
                      status = "pending", stringsAsFactors = FALSE)

for (i in seq_along(scripts)) {
  script_path <- file.path(script_dir, scripts[i])
  cat(sprintf("\n[%d/%d] %s\n", i, length(scripts), scripts[i]))

  t_script <- Sys.time()
  tryCatch({
    source(script_path, local = new.env(parent = globalenv()))
    elapsed <- as.numeric(difftime(Sys.time(), t_script, units = "secs"))
    timings$seconds[i] <- elapsed
    timings$status[i] <- "OK"
    cat(sprintf("  done in %.1fs\n", elapsed))
  }, error = function(e) {
    elapsed <- as.numeric(difftime(Sys.time(), t_script, units = "secs"))
    timings$seconds[i] <<- elapsed
    timings$status[i] <<- paste("ERROR:", conditionMessage(e))
    cat(sprintf("  FAILED after %.1fs: %s\n", elapsed, conditionMessage(e)))
  })
}

t_total <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

cat("\nPipeline summary\n")
cat(sprintf("%-25s %10s %10s\n", "Script", "Time (s)", "Status"))
for (i in seq_along(scripts)) {
  cat(sprintf("%-25s %10.1f %10s\n",
              scripts[i], timings$seconds[i], timings$status[i]))
}
cat(sprintf("%-25s %10.1f\n", "TOTAL", t_total))

v4_dir <- file.path(dirname(script_dir))

n_tex     <- length(list.files(file.path(v4_dir, "manuscript"),     pattern = "\\.tex$"))
n_html    <- length(list.files(file.path(v4_dir, "results"),        pattern = "\\.html$"))
n_pdf     <- length(list.files(file.path(v4_dir, "graphs"),         pattern = "\\.pdf$"))
n_txt     <- length(list.files(file.path(v4_dir, "results"),        pattern = "\\.txt$"))
n_pub_tex <- length(list.files(file.path(v4_dir, "pub", "tables"),  pattern = "\\.tex$"))
n_pub_pdf <- length(list.files(file.path(v4_dir, "pub", "figures"), pattern = "\\.pdf$"))

cat(sprintf("\nOutputs: %d .tex, %d .html, %d .pdf, %d .txt\n",
            n_tex, n_html, n_pdf, n_txt))
cat(sprintf("Pub-ready: %d .tex tables, %d .pdf figures\n", n_pub_tex, n_pub_pdf))

n_errors <- sum(grepl("ERROR", timings$status))
if (n_errors > 0) {
  cat(sprintf("\nWARNING: %d script(s) failed.\n", n_errors))
} else {
  cat("\nAll scripts completed.\n")
}

cat(sprintf("Total time: %.1fs (%.1f min)\n", t_total, t_total / 60))
