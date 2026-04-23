# Paths, DuckDB config e helpers comuns para os scripts v3.

suppressPackageStartupMessages({
  library(data.table)
  library(duckdb)
  library(DBI)
  library(arrow)
})

v3_root   <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural"
data_root <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data"
p3_data   <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/data/processed"

path_v3 <- function(...) file.path(v3_root, ...)
path_raw <- function(...) file.path(data_root, "raw", ...)
path_proc <- function(...) file.path(data_root, "processed", ...)

dir.create(path_v3("data/processed"), showWarnings = FALSE, recursive = TRUE)
dir.create(path_v3("logs"),           showWarnings = FALSE, recursive = TRUE)
dir.create(path_v3("output/tables"),  showWarnings = FALSE, recursive = TRUE)
dir.create(path_v3("output/figures"), showWarnings = FALSE, recursive = TRUE)

con_duck <- function() {
  con <- dbConnect(duckdb::duckdb())
  dbExecute(con, "PRAGMA threads=12")
  dbExecute(con, "PRAGMA memory_limit='14GB'")
  dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill_v3'")
  con
}

# Rapid RSS probe for the telemetry line required by the machine-profile rules.
rss_gb <- function() {
  tryCatch({
    info <- system(paste0("ps -p ", Sys.getpid(), " -o rss="), intern = TRUE)
    round(as.numeric(info) / 1024^2, 2)
  }, error = function(e) NA_real_)
}

log_step <- function(tag, msg, log_con = NULL) {
  line <- sprintf("[%s] %s  RSS=%.2fGb  %s",
                  format(Sys.time(), "%H:%M:%S"), tag, rss_gb(), msg)
  message(line)
  if (!is.null(log_con)) writeLines(line, log_con)
}

# CADMAT class codes used to flag pharma items inside Group 65.
# Narrow = CMED-regulated drugs + biologicals (the hard pharma core).
# Broad  = qualquer item com princípio farmacológico ou reativo
#          (reagentes, soluções, insumos laboratoriais).
cadmat_pharma_narrow <- c(6531L, 6532L, 6536L, 6581L)
cadmat_pharma_broad  <- c(6509L, 6528L, 6531L, 6532L, 6533L, 6534L, 6536L,
                          6541L, 6542L, 6573L, 6574L, 6575L, 6576L, 6577L,
                          6578L, 6579L, 6581L, 6582L, 6586L)

# Treatment calendar: g65 entrou no regime SME-only em março de 2018.
# data_oc_numb é o int mensal Stata. 698 = 2018m3.
cutoff_m <- 698L
win_18m  <- c(680L, 715L)
win_12m  <- c(686L, 709L)
win_06m  <- c(692L, 703L)
