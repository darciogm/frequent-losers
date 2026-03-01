# ============================================================================
# 01_clean.R — Data loading, variable creation, and caching
# ============================================================================

cat("=== 01_clean.R: Data preparation ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load data -------------------------------------------------------------
if (file.exists(DATA_PARQ)) {
  cat("  Reading parquet...\n")
  dt <- as.data.table(read_parquet(DATA_PARQ))
} else {
  cat("  Reading CSV (this will take a few minutes)...\n")
  csv_path <- file.path(DATA_RAW, "Paper2_ME_EPP.csv")

  # Read header to find column indices (avoid encoding issues with select-by-name)
  hdr <- names(fread(csv_path, sep = ";", encoding = "Latin-1", nrows = 0))

  # Columns we need (match by position-stable suffixes to avoid encoding issues)
  keep_patterns <- c("data_oc_numb", "item_alt$", "pbu_alt$", "convite$",
                      "lquantidade$", "lpreco_final$", "oc_item_status",
                      "lnum_firms$", "lnum_bids$", "dist1$",
                      "num_firms$", "num_bids$", "preco_final$", "digogrupo$")
  keep_idx <- unique(unlist(lapply(keep_patterns, function(p) grep(p, hdr))))
  keep_names <- hdr[sort(keep_idx)]
  cat("  Selecting", length(keep_names), "columns\n")

  dt <- fread(csv_path, sep = ";", encoding = "Latin-1", select = keep_names)

  # Normalize column names: find the codigogrupo column (may have encoding artifacts)
  grupo_col <- grep("digogrupo$", names(dt), value = TRUE)
  if (length(grupo_col) == 1 && grupo_col != "codigogrupo") {
    setnames(dt, grupo_col, "codigogrupo")
  }

  # Save as parquet for fast future reads
  cat("  Saving parquet...\n")
  write_parquet(dt, DATA_PARQ)
}

cat("  Raw rows:", nrow(dt), "\n")

# ---- Normalize column name for group code ----------------------------------
# After parquet reload, the name might be the original encoded one
grupo_col <- grep("digogrupo$", names(dt), value = TRUE)
if (length(grupo_col) == 1 && grupo_col != "codigogrupo") {
  setnames(dt, grupo_col, "codigogrupo")
}

# ---- Ensure numeric types --------------------------------------------------
num_cols <- c("data_oc_numb", "item_alt", "pbu_alt", "convite",
              "lquantidade", "lpreco_final", "oc_item_status",
              "lnum_firms", "lnum_bids", "dist1", "num_firms", "num_bids",
              "preco_final")
for (col in num_cols) {
  if (col %in% names(dt) && is.character(dt[[col]])) {
    dt[, (col) := as.numeric(get(col))]
  }
}

# codigogrupo: normalize to character for comparison
dt[, codigogrupo := as.character(codigogrupo)]

# ---- Create treatment variables --------------------------------------------
dt[, g65 := as.integer(codigogrupo == "65")]
dt[, Pre := as.integer(data_oc_numb < TREAT_DATE)]
dt[, g65_pre := g65 * Pre]

# ---- Create semester factor for event study (18-month window) --------------
dt[, semester := cut(data_oc_numb,
                     breaks = SEM_BREAKS,
                     labels = 1:6,
                     right = FALSE,
                     include.lowest = FALSE)]
dt[, semester_f := factor(semester)]

# ---- Create group factor for event study FE --------------------------------
dt[, grupo_f := factor(codigogrupo)]

# ---- Convert FE identifiers to factor (saves memory in fixest) -------------
dt[, item_alt := factor(item_alt)]
dt[, pbu_alt := factor(pbu_alt)]

# ---- Filter to analysis windows only (keep 18-month superset) --------------
dt <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
cat("  Rows in 18-month window:", nrow(dt), "\n")

# ---- Mark completed items --------------------------------------------------
dt[, completed := (oc_item_status == 1L)]

# ---- Validate observation counts against manuscript ------------------------
validate_counts <- function(dt) {
  windows <- list("6m" = WIN_6M, "12m" = WIN_12M, "18m" = WIN_18M)
  for (wname in names(windows)) {
    w <- windows[[wname]]
    sub <- dt[data_oc_numb >= w[1] & data_oc_numb <= w[2]]
    n_completed <- sub[completed == TRUE & !is.na(lpreco_final), .N]
    n_all <- sub[!is.na(lnum_firms), .N]
    cat(sprintf("  %s window: completed=%s, all=%s\n",
                wname, pfmt_int(n_completed), pfmt_int(n_all)))
  }
}
validate_counts(dt)

# ---- Save cache ------------------------------------------------------------
cat("  Saving RDS cache...\n")
saveRDS(dt, DATA_CACHE)
cat("  Done. Cache:", DATA_CACHE, "\n")
