# ============================================================================
# 01_clean.R — Data loading, variable creation, and caching
# ============================================================================

cat("=== 01_clean.R: Data preparation ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load data -------------------------------------------------------------
# Check parquet version — rebuild if outdated or missing
parq_current <- file.exists(DATA_PARQ) &&
  file.exists(DATA_PARQ_VER) &&
  as.integer(readLines(DATA_PARQ_VER, n = 1)) >= PARQUET_VERSION

if (parq_current) {
  cat("  Reading parquet (version", PARQUET_VERSION, ")...\n")
  dt <- as.data.table(read_parquet(DATA_PARQ))
} else {
  if (file.exists(DATA_PARQ)) cat("  Parquet cache outdated — rebuilding...\n")
  cat("  Reading CSV (this will take a few minutes)...\n")
  csv_path <- file.path(DATA_RAW, "Paper2_ME_EPP.csv")

  # Read header to find column indices (avoid encoding issues with select-by-name)
  hdr <- names(fread(csv_path, sep = ";", encoding = "Latin-1", nrows = 0))

  # Columns we need (match by position-stable suffixes to avoid encoding issues)
  keep_patterns <- c(
    # Original columns
    "data_oc_numb", "item_alt$", "pbu_alt$", "convite$",
    "lquantidade$", "lpreco_final$", "oc_item_status",
    "lnum_firms$", "lnum_bids$", "dist1$",
    "num_firms$", "num_bids$", "preco_final$", "digogrupo$",
    # Real prices / efficiency
    "preco_ref$", "lpreco_ref$", "preco_final_real$", "lpreco_final_real$",
    "fator_ipca$", "final_ref_perc$", "ref_efficiency$",
    # Firm type / winner composition
    "me_epp$", "porte_empresa$", "fornec_enquad$",
    # Firm counts by type (phase 1)
    "numfornecs_type_me_ph", "numfornecs_type_epp_ph", "numfornecs_type_oth_ph",
    # Bid spread
    "diff_first_sec_ph", "second_bid_ph",
    # Geography
    "same_municip$", "gde_sp$", "fornec_estado_SP$",
    # PBU characteristics
    "pbu_power$", "pbu_type_mgmt_code$", "adm_dir$",
    # Item classification
    "class_alt$", "codigoclasse$",
    # Reference / total values
    "valor_total_ref$", "valor_total_final$"
  )
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
  cat("  Saving parquet (version", PARQUET_VERSION, ")...\n")
  write_parquet(dt, DATA_PARQ)
  writeLines(as.character(PARQUET_VERSION), DATA_PARQ_VER)
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
              "preco_final",
              # New numeric columns
              "preco_ref", "lpreco_ref", "preco_final_real", "lpreco_final_real",
              "fator_ipca", "final_ref_perc", "ref_efficiency",
              "me_epp",
              "numfornecs_type_me_ph1", "numfornecs_type_epp_ph1",
              "numfornecs_type_oth_ph1",
              "diff_first_sec_ph1", "second_bid_ph1",
              "same_municip", "gde_sp", "fornec_estado_SP",
              "pbu_power", "pbu_type_mgmt_code", "adm_dir",
              "class_alt", "codigoclasse",
              "valor_total_ref", "valor_total_final")
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

# ---- Derived variables for extensions --------------------------------------

# Extensive margin: binary completion indicator (all items)
dt[, completed_binary := as.integer(oc_item_status == 1L)]

# Winner composition: SME winner indicator
if ("me_epp" %in% names(dt)) {
  dt[, sme_winner := fifelse(!is.na(me_epp) & me_epp == 1, 1L, 0L)]
}

# Efficiency: final price relative to reference price
if ("final_ref_perc" %in% names(dt)) {
  dt[, efficiency := final_ref_perc]
} else if (all(c("preco_final", "preco_ref") %in% names(dt))) {
  dt[, efficiency := fifelse(preco_ref > 0, preco_final / preco_ref * 100, NA_real_)]
}

# Bid spread: difference between 1st and 2nd bid (phase 1)
if ("diff_first_sec_ph1" %in% names(dt)) {
  dt[, bid_spread := diff_first_sec_ph1]
}

# SME share among firms in phase 1
if (all(c("numfornecs_type_me_ph1", "numfornecs_type_epp_ph1",
           "numfornecs_type_oth_ph1") %in% names(dt))) {
  dt[, total_firms_ph1 := numfornecs_type_me_ph1 + numfornecs_type_epp_ph1 +
                           numfornecs_type_oth_ph1]
  dt[, sme_share_ph1 := fifelse(total_firms_ph1 > 0,
     (numfornecs_type_me_ph1 + numfornecs_type_epp_ph1) / total_firms_ph1,
     NA_real_)]
}

# PBU type factor for heterogeneity
if ("pbu_type_mgmt_code" %in% names(dt)) {
  dt[, pbu_type_f := factor(pbu_type_mgmt_code)]
}

# High-value item indicator (above median valor_total_ref)
if ("valor_total_ref" %in% names(dt)) {
  med_val <- median(dt[!is.na(valor_total_ref) & valor_total_ref > 0,
                        valor_total_ref], na.rm = TRUE)
  dt[, high_value := fifelse(!is.na(valor_total_ref), as.integer(valor_total_ref >= med_val), NA_integer_)]
  cat("  Median reference value:", pfmt(med_val, 2), "\n")
}

# Winsorized dependent variables
dt[, lpreco_final_w01 := winsorize(lpreco_final, 0.01, 0.99)]
dt[, dist1_w01        := winsorize(dist1, 0.01, 0.99)]
dt[, lpreco_final_w05 := winsorize(lpreco_final, 0.05, 0.95)]
dt[, dist1_w05        := winsorize(dist1, 0.05, 0.95)]

# Direct administration factor for heterogeneity
if ("adm_dir" %in% names(dt)) {
  dt[, adm_dir_f := factor(adm_dir)]
}

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
