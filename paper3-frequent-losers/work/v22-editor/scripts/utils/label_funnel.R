# =============================================================================
# label_funnel.R  --  label-construction-funnel utilities for the JLEO R&R (v22)
#
# Backs Table A (label funnel & sample reconciliation) and Appendix C. These are
# THIN, REUSABLE wrappers around the counting logic already implemented and RUN
# in scripts/79_label_funnel.R. The substantive, data-touching reconstruction
# lives in 79 (DuckDB over 16.8M rows); THIS file provides composable helpers and
# the Table-A export schema so the section script does not re-implement counting.
#
# U2 DECISION (locked 2026-06-02): DISCLOSE + ROBUSTNESS. Keep 193 as the primary
# adjudicated target; report the transparent 79-funnel (341) as a reproducible
# robustness target; drop the unsupported 30 -> use 19 conservative defendants.
# The "results materially unchanged" claim is UNVERIFIED until a core AUC is
# re-run under the 341 label (see 05_BLOCKERS U2).
# =============================================================================

# ---- 1-6. count_* : composable counters over already-linked frames ----------
# Each takes a data.frame/data.table already filtered to the relevant population
# and returns an integer. They do NOT touch raw data -- that is script 79's job.
count_cases <- function(case_df, case_col = "proc")
  length(unique(case_df[[case_col]][!is.na(case_df[[case_col]]) &
                                    trimws(case_df[[case_col]]) != "" &
                                    toupper(case_df[[case_col]]) != "IT_DF"]))

count_direct_defendants <- function(defendant_df, cnpj_col = "cnpj")
  length(unique(defendant_df[[cnpj_col]][!is.na(defendant_df[[cnpj_col]])]))

# BEC-active = direct defendants that actually appear in firm_tender_map.
count_BEC_active_defendants <- function(defendant_cnpjs, ftm_cnpjs)
  length(intersect(unique(defendant_cnpjs), unique(ftm_cnpjs)))

count_defendant_tender_items <- function(def_items_df,
                                         oc_col = "numerodaoc", item_col = "códigoitem")
  nrow(unique(def_items_df[, c(oc_col, item_col)]))

count_always_loser_cobidders <- function(cobidder_stat, al_col = "is_AL")
  sum(cobidder_stat[[al_col]] == 1L, na.rm = TRUE)

count_frequent_loser_cobidders <- function(cobidder_stat, fl_col = "is_FL")
  sum(cobidder_stat[[fl_col]] == 1L, na.rm = TRUE)

# ---- 7. reconcile_label_samples --------------------------------------------
# Compare a reconstructed cobidder set to a reference (static) set and report
# overlap, so the disclosure paragraph is exact, not hand-waved.
reconcile_label_samples <- function(recon_cnpjs, reference_cnpjs) {
  r <- unique(recon_cnpjs); f <- unique(reference_cnpjs)
  data.frame(
    recon_n     = length(r),
    reference_n = length(f),
    in_both     = length(intersect(r, f)),
    recon_only  = length(setdiff(r, f)),
    reference_only = length(setdiff(f, r)))
}

# ---- 8. export_label_funnel_table ------------------------------------------
# Table-A schema. One row per SAMPLE (e.g. "primary 193", "transparent 341",
# "conservative <=2020"). Counts come from the count_* helpers / script 79
# outputs; NA/TODO where a cell is not yet linked. NEVER fabricate counts.
LABEL_FUNNEL_SCHEMA <- c(
  "sample_name","cade_cases","final_decision_window","conduct_window",
  "direct_defendants_legal_record","BEC_active_direct_defendants",
  "defendant_tender_items","always_loser_cobidders","frequent_loser_cobidders",
  "total_always_losers","exclusion_rule","reason_for_difference_from_main_target",
  "notes")

new_label_funnel_row <- function(sample_name, ...) {
  row <- as.list(stats::setNames(rep(NA, length(LABEL_FUNNEL_SCHEMA)), LABEL_FUNNEL_SCHEMA))
  row$sample_name <- sample_name
  ov <- list(...)
  for (nm in names(ov)) {
    if (!nm %in% LABEL_FUNNEL_SCHEMA) stop("new_label_funnel_row: unknown field '", nm, "'")
    row[[nm]] <- ov[[nm]]
  }
  as.data.frame(row, stringsAsFactors = FALSE)
}

export_label_funnel_table <- function(rows, path) {
  df <- if (is.data.frame(rows)) rows else do.call(rbind, rows)
  miss <- setdiff(LABEL_FUNNEL_SCHEMA, names(df))
  if (length(miss)) stop("export_label_funnel_table: missing schema cols: ",
                         paste(miss, collapse = ", "))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df[, LABEL_FUNNEL_SCHEMA], path, row.names = FALSE)
  message("export_label_funnel_table -> ", path); invisible(path)
}

# Convenience: load the script-79 funnel.csv (already produced) into Table-A rows.
# This is the REAL, RUN reconstruction; see scripts/79_label_funnel.R.
load_funnel_from_script79 <- function(funnel_csv) {
  if (!file.exists(funnel_csv))
    stop("load_funnel_from_script79: run scripts/79_label_funnel.R first (", funnel_csv, " absent).")
  utils::read.csv(funnel_csv, stringsAsFactors = FALSE)
}

# TODO(repo-wiring): the data-touching reconstruction is scripts/79_label_funnel.R
# -> output/label_funnel/{funnel,case_timing,case_cobidder_map}.csv.
# Table A (Prompt 3) assembles primary(193) + transparent(341) + conservative
# rows from those CSVs via the helpers above. case_cobidder_map.csv supplies the
# case_id linkage for leave-one-case-out (Prompt 5).
.LABEL_FUNNEL_VERSION <- "v22-2026-06-02"
