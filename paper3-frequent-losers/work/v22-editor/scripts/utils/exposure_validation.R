# =============================================================================
# exposure_validation.R  --  opportunity/exposure-adjusted validation utilities
#                            for the JLEO R&R (v22)
#
# Backs Section 4.2 (the empirical CORE) and Appendix D: does the loser-side
# ranking carry signal BEYOND the mechanical fact that high-participation
# zero-win firms have more chances to appear near CADE defendants?
#
# Reference implementation already exists and PASSED: scripts/76_exposure_
# adjusted_audit.R (within-opportunity-decile AUC 0.7715; +0.0415 over
# exposure-only, DeLong p=2.08e-06; exposure-only ALONE 0.946). These functions
# generalize that logic across opportunity-cell granularities so the referee
# can see robustness to the exposure definition.
#
# Depends on metrics_triage.R (roc_auc). Source both.
# =============================================================================
if (!exists("roc_auc")) stop("exposure_validation.R: source scripts/utils/metrics_triage.R first.")

# Opportunity-cell granularities. Repo variable names (confirmed Subprompt 1):
#   item_group  -> only in bid_level_full_v14.parquet ("Código Grupo") -- needs join
#   item_code   -> "códigoitem" (firm_tender_map, everywhere)
#   modality    -> item_value_panel.modality (1=Convite,3=Pregão); BEC po_phase_code
#   year        -> substr(numerodaoc,12,15)  OR item_value_panel.year
#   buyer/PBU   -> "códigounidadecompradora" / item_value_panel.pbu_code / key[1:11]
CELL_GRANULARITIES <- list(
  ig_mod_year          = c("item_group","modality","year"),
  ig_mod_year_buyer    = c("item_group","modality","year","buyer"),
  item_mod_year_buyer  = c("item_code","modality","year","buyer"),
  item_mod_year        = c("item_code","modality","year")
  # fallback: user supplies an explicit character vector of cell columns.
)

# ---- 1. build_opportunity_cells --------------------------------------------
# Assign each firm-opportunity row to a cell id from the chosen granularity.
# `df` must already contain the granularity columns (caller joins item_group
# from v14 if needed -- see TODO).
build_opportunity_cells <- function(df, granularity = "item_mod_year_buyer",
                                    cols = NULL) {
  keys <- if (!is.null(cols)) cols else CELL_GRANULARITIES[[granularity]]
  if (is.null(keys)) stop("build_opportunity_cells: unknown granularity '", granularity, "'.")
  miss <- setdiff(keys, names(df))
  if (length(miss)) stop("build_opportunity_cells: missing cell cols: ",
                         paste(miss, collapse = ", "),
                         " (join from bid_level_full_v14 if item_group).")
  df$cell_id <- do.call(paste, c(df[keys], sep = "|"))
  attr(df, "cell_keys") <- keys
  df
}

# ---- 2. calculate_cell_defendant_contact_rate ------------------------------
# Per cell: fraction of firm-opportunities that touch a direct defendant.
calculate_cell_defendant_contact_rate <- function(df, cell = "cell_id",
                                                  contact = "touches_defendant") {
  stopifnot(all(c(cell, contact) %in% names(df)))
  agg <- aggregate(df[[contact]], by = list(cell = df[[cell]]),
                   FUN = function(x) mean(x, na.rm = TRUE))
  names(agg) <- c(cell, "cell_contact_rate"); agg
}

# ---- 3. calculate_firm_expected_contact ------------------------------------
# Firm expected contact = sum over the firm's opportunities of the cell contact
# rate (coupon-collector benchmark). LEAVE-ONE-OUT variant subtracts the firm's
# own contribution so a firm is not benchmarked against itself.
calculate_firm_expected_contact <- function(df, firm = "firm_id", cell = "cell_id",
                                            contact = "touches_defendant",
                                            leave_one_out = TRUE) {
  stopifnot(all(c(firm, cell, contact) %in% names(df)))
  cr <- calculate_cell_defendant_contact_rate(df, cell, contact)
  df <- merge(df, cr, by = cell, all.x = TRUE)
  if (leave_one_out) {
    # cell size & cell positives for LOO rate = (cell_pos - own)/(cell_n - 1)
    sz <- aggregate(list(cell_n = df[[contact]]), by = list(cell = df[[cell]]), length)
    ps <- aggregate(list(cell_pos = df[[contact]]), by = list(cell = df[[cell]]), sum, na.rm = TRUE)
    df <- merge(merge(df, sz, by.x = cell, by.y = "cell"), ps, by.x = cell, by.y = "cell")
    df$loo_rate <- ifelse(df$cell_n > 1,
                          (df$cell_pos - df[[contact]]) / (df$cell_n - 1),
                          NA_real_)
    rate_col <- "loo_rate"
  } else rate_col <- "cell_contact_rate"
  out <- aggregate(df[[rate_col]], by = list(firm = df[[firm]]),
                   FUN = function(x) sum(x, na.rm = TRUE))
  names(out) <- c(firm, "expected_contact"); out
}

# ---- 4. calculate_excess_contact -------------------------------------------
# Observed defendant contacts minus expected (the exposure-residual).
calculate_excess_contact <- function(observed_df, expected_df,
                                     firm = "firm_id", observed = "observed_contact") {
  m <- merge(observed_df, expected_df, by = firm, all = TRUE)
  m$excess_contact <- m[[observed]] - m$expected_contact
  m
}

# ---- 5. exposure_adjusted_model_frame --------------------------------------
# Build the model frame for the headline test: label ~ exposure + score.
# Returns a data.frame with label, log_opportunity (exposure), and the score(s);
# the caller fits the nested logits and DeLong-compares (mirrors script 76).
exposure_adjusted_model_frame <- function(firm_panel, label = "cobidder",
                                          exposure = "log_opportunity",
                                          scores = c("log_tc","fl14")) {
  need <- c(label, exposure, scores)
  miss <- setdiff(need, names(firm_panel))
  if (length(miss)) stop("exposure_adjusted_model_frame: missing ", paste(miss, collapse=", "))
  firm_panel[, need, drop = FALSE]
}

# ---- 6. exposure_stratified_matching_frame ---------------------------------
# Prepare a CEM-on-opportunity frame (mirror script 74/76 discipline): coarsen
# the exposure variable into strata so cobidders are compared to non-cobidders
# with similar opportunity. Returns df + stratum id; matching done by caller.
exposure_stratified_matching_frame <- function(firm_panel, exposure = "log_opportunity",
                                               n_strata = 10L, label = "cobidder") {
  stopifnot(all(c(exposure, label) %in% names(firm_panel)))
  br <- stats::quantile(firm_panel[[exposure]], probs = seq(0, 1, length.out = n_strata + 1),
                        na.rm = TRUE, type = 7)
  br[1] <- -Inf; br[length(br)] <- Inf
  firm_panel$exposure_stratum <- cut(firm_panel[[exposure]], unique(br),
                                     include.lowest = TRUE, labels = FALSE)
  firm_panel
}

# ---- 7. cell_preserving_permutation_skeleton -------------------------------
# Within-cell permutation null: shuffle the label WITHIN opportunity cells so
# the exposure structure is preserved under H0 (mirror script 25 discipline).
# Returns a function closure that yields one permuted label vector per call.
cell_preserving_permutation_skeleton <- function(df, label = "cobidder",
                                                 cell = "cell_id", seed = 20260602L) {
  stopifnot(all(c(label, cell) %in% names(df)))
  if (is.null(seed)) stop("cell_preserving_permutation: seed must be set.")
  set.seed(as.integer(seed))
  idx_by_cell <- split(seq_len(nrow(df)), df[[cell]])
  y <- df[[label]]
  function() {
    yp <- y
    for (ix in idx_by_cell) if (length(ix) > 1L) yp[ix] <- sample(y[ix])
    yp
  }
}

# ---- 8. common_support_diagnostics -----------------------------------------
# Standardized mean difference of exposure between labels, raw vs within-strata
# (confirms the exposure axis is actually balanced after matching).
common_support_diagnostics <- function(df, exposure = "log_opportunity",
                                       label = "cobidder", stratum = NULL) {
  smd <- function(x, g) {
    m1 <- mean(x[g==1], na.rm=TRUE); m0 <- mean(x[g==0], na.rm=TRUE)
    s  <- sqrt((stats::var(x[g==1], na.rm=TRUE) + stats::var(x[g==0], na.rm=TRUE))/2)
    if (is.na(s) || s == 0) NA_real_ else (m1 - m0) / s
  }
  raw <- smd(df[[exposure]], df[[label]])
  out <- data.frame(scope = "raw", smd = raw)
  if (!is.null(stratum) && stratum %in% names(df)) {
    by <- tapply(seq_len(nrow(df)), df[[stratum]],
                 function(ix) smd(df[[exposure]][ix], df[[label]][ix]))
    out <- rbind(out, data.frame(scope = "within_stratum_mean",
                                 smd = mean(by, na.rm = TRUE)))
  }
  out
}

# TODO(repo-wiring): item_group is only in bid_level_full_v14.parquet
# ("Código Grupo"); join it onto firm_tender_map by (numerodaoc,códigoitem)
# before using the ig_* granularities. The reference firm panel with
# cobidder/log_opportunity/log_tc/fl14 is output/exposure_adjusted_audit/
# firm_panel.csv (script 76).
.EXPOSURE_VALIDATION_VERSION <- "v22-2026-06-02"
