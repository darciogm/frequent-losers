# ============================================================================
# 00_master.R — v6-jpube structural pipeline orchestrator
# Usage: Rscript scripts/00_master.R   (from v6-jpube/ root)
#
# Runs every numbered script in scripts/ in lexicographic order, each as a
# separate Rscript subprocess (so the OS reclaims memory between scripts —
# critical on 21 GiB RAM). Per-script logs live in logs/<name>.log; the
# pipeline timing summary lands in logs/00_master.log.
#
# values.tex (output/values.tex) is reset at start; each script appends its
# macros via write_macro() (defined in utils_v6.R). The manuscript imports
# values.tex in the preamble — every numerical claim refreshes automatically.
# ============================================================================

suppressPackageStartupMessages({
  source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/utils_v6.R")
})

# --- Pre-flight -------------------------------------------------------------
master_log <- file(path_v6("logs/00_master.log"), open = "wt")
on.exit(close(master_log), add = TRUE)

banner <- function(s) {
  msg <- paste(c(
    strrep("=", 76),
    s,
    strrep("=", 76)
  ), collapse = "\n")
  message(msg); writeLines(msg, master_log); flush(master_log)
}

banner(sprintf("v6-jpube pipeline | start %s | host %s",
               format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
               Sys.info()[["nodename"]]))

writeLines(sprintf("R version: %s", R.version.string), master_log)
writeLines(sprintf("nproc: %d   RAM total: %s",
                   parallel::detectCores(),
                   tryCatch(system("grep MemTotal /proc/meminfo", intern = TRUE),
                            error = function(e) "?")),
           master_log)
flush(master_log)

# --- Required packages ------------------------------------------------------
required <- c("data.table", "fixest", "ggplot2", "arrow", "duckdb", "DBI",
              "scales", "gridExtra")
missing  <- required[!sapply(required, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  stop("Missing R packages: ", paste(missing, collapse = ", "))
}

# --- Reset macro registry ---------------------------------------------------
reset_macros()
write_macro("pipelinedate", format(Sys.Date(), "%B~%Y"),
            comment = "set by 00_master.R")
write_macro("pipelinehost", Sys.info()[["nodename"]],
            comment = "set by 00_master.R")

# --- Discover scripts to run ------------------------------------------------
script_dir <- path_v6("scripts")
scripts    <- list.files(script_dir, pattern = "^[0-9]{2}_.*\\.R$",
                         full.names = FALSE)
scripts    <- scripts[scripts != "00_master.R"]
scripts    <- sort(scripts)

writeLines(c("", "Scripts to run (lexicographic order):"), master_log)
writeLines(paste0("  ", scripts), master_log)
flush(master_log)

# --- Optional --skip / --only filters --------------------------------------
args <- commandArgs(trailingOnly = TRUE)
skip <- args[grepl("^--skip=", args)]
only <- args[grepl("^--only=", args)]
keep_going <- "--keep-going" %in% args

if (length(skip)) {
  patt <- sub("^--skip=", "", skip)
  for (p in patt) scripts <- scripts[!grepl(p, scripts)]
}
if (length(only)) {
  patt <- sub("^--only=", "", only)
  scripts <- scripts[Reduce(`|`, lapply(patt, function(p) grepl(p, scripts)))]
}
# --fast: skip the four heavy collusion-screen bootstraps (each >5 min on
# 14-thread WSL2). They feed appendix robustness, no headline macros.
if ("--fast" %in% args) {
  scripts <- scripts[!grepl("collusion_screen", scripts)]
  msg <- "  [--fast] skipping collusion-screen bootstraps"
  message(msg); writeLines(msg, master_log); flush(master_log)
}

# --- Execute ----------------------------------------------------------------
timings <- data.frame(script = character(), seconds = numeric(),
                      status = character(), stringsAsFactors = FALSE)
pipeline_start <- Sys.time()

for (s in scripts) {
  banner(sprintf("RUNNING: %s   [%s]", s, format(Sys.time(), "%H:%M:%S")))
  t0  <- Sys.time()
  cmd <- sprintf("Rscript %s", shQuote(file.path(script_dir, s)))
  rc  <- system(cmd)
  dt  <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  status <- if (rc == 0) "OK" else sprintf("FAIL (rc=%d)", rc)
  timings <- rbind(timings, data.frame(script = s, seconds = round(dt, 1),
                                       status = status,
                                       stringsAsFactors = FALSE))
  msg <- sprintf("  -> %s in %.1fs", status, dt)
  message(msg); writeLines(msg, master_log); flush(master_log)
  if (rc != 0 && !keep_going) {
    banner(sprintf("ABORT: %s failed (use --keep-going to continue)", s))
    break
  }
}

# --- Summary ----------------------------------------------------------------
total <- as.numeric(difftime(Sys.time(), pipeline_start, units = "secs"))
banner(sprintf("Pipeline finished in %.1f minutes", total / 60))

writeLines("", master_log)
writeLines(capture.output(print(timings, row.names = FALSE)), master_log)

n_tex <- length(list.files(path_v6("output/tables"), pattern = "\\.tex$"))
n_pdf <- length(list.files(path_v6("output/figures"), pattern = "\\.pdf$"))
n_macros <- if (file.exists(values_path()))
  length(grep("^\\\\renewcommand", readLines(values_path()))) else 0
writeLines(sprintf("Outputs: %d tables, %d figures, %d macros (values.tex)",
                   n_tex, n_pdf, n_macros), master_log)

if (any(grepl("^FAIL", timings$status))) {
  message("WARNING: some scripts failed.")
  quit(status = 1)
}
