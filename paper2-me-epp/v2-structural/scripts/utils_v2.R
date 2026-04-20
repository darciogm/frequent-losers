# ============================================================================
# utils_v2.R — paths and helpers for v2-structural (Krasnokutskaya/GPV pipeline)
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})

# ---- paths -----------------------------------------------------------------
V2_ROOT   <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v2-structural"
V2_DATA   <- file.path(V2_ROOT, "data/processed")
V2_TABLES <- file.path(V2_ROOT, "output/tables")
V2_FIGS   <- file.path(V2_ROOT, "output/figures")
V2_LOGS   <- file.path(V2_ROOT, "logs")

# Upstream sources
BID_LEVEL_SRC <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/v3/data/processed/bid_level_with_prices.parquet"
FIRMS_SRC     <- "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers/data/processed/Firms_final.parquet"
P2_PARQUET    <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/data/processed/paper2_me_epp.parquet"
P2_KEYS_CACHE <- "/tmp/p2_keys.parquet"  # built by 32_bid_level_merge.R if absent

# ---- windows ---------------------------------------------------------------
WIN_18M <- c(680L, 715L)   # Sep 2016 – Aug 2019 (Stata monthly)
TREAT_DATE <- 698L         # March 2018

# ---- constants -------------------------------------------------------------
# CMED pharma class code (Group-65 subset with ANVISA drug-price regulation)
CMED_CLASS <- 6531L

# Modality labels in bid-level data
MODALITY_CONVITE <- "CONVITE"
MODALITY_PREGAO  <- "PREGÃO ELETRÔNICO"
MODALITY_DISPENSA <- "DISPENSA DE LICITAÇÃO"

# ---- logging helpers -------------------------------------------------------
log_msg <- function(...) {
  cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), ..., "\n", sep = "")
}

log_mem <- function(label = "") {
  ps <- sprintf("ps -o rss= -p %d", Sys.getpid())
  rss_kb <- as.integer(system(ps, intern = TRUE))
  log_msg(sprintf("%s RSS=%.2f GiB", label, rss_kb / 1024 / 1024))
}

# ---- DuckDB helper ---------------------------------------------------------
with_duckdb <- function(fn, threads = 12, memory = "14GB") {
  if (!requireNamespace("duckdb", quietly = TRUE)) {
    stop("duckdb R package required. install.packages('duckdb')")
  }
  con <- DBI::dbConnect(duckdb::duckdb())
  DBI::dbExecute(con, sprintf("PRAGMA threads=%d", threads))
  DBI::dbExecute(con, sprintf("PRAGMA memory_limit='%s'", memory))
  DBI::dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  fn(con)
}

# ---- Paper-2 keyset (for bid-level merge) ----------------------------------
ensure_p2_keys <- function() {
  if (file.exists(P2_KEYS_CACHE)) {
    log_msg("p2_keys cache present: ", P2_KEYS_CACHE)
    return(invisible(P2_KEYS_CACHE))
  }
  log_msg("Building p2_keys from raw CSV (stream, UTF-8, 3.67M rows)...")
  # Delegate to Python streaming extractor (R's readr/data.table struggle with
  # Latin-1 encoded headers that are actually UTF-8; Python handles it cleanly).
  extractor <- file.path(V2_ROOT, "scripts", "_extract_p2_keys.py")
  stopifnot(file.exists(extractor))
  system2("python3", extractor, stdout = "", stderr = "")
  stopifnot(file.exists(P2_KEYS_CACHE))
  invisible(P2_KEYS_CACHE)
}
