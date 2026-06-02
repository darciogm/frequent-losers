# =============================================================================
# cost_frontier.R  --  cost-recall frontier utilities for the JLEO R&R (v22)
#
# Supports Section 6 / Table D / FIG_COST_RECALL_FRONTIER and the sequential
# gatekeeper reported as a FRONTIER over K1 and cost denominators (not a single
# "83%"). These functions NEVER invent cost data: cost denominators must be
# supplied as columns; unavailable denominators are marked, not imputed.
#
# Depends on metrics_triage.R for recall/precision at k. Source both.
# =============================================================================
if (!exists("recall_at_k")) stop("cost_frontier.R: source scripts/utils/metrics_triage.R first.")

# Supported cost denominators (column names expected in the firm/cell panel).
COST_DENOMINATORS <- c(
  "firms_opened",                # # firms whose record is opened
  "tender_items_opened",         # # award-layer tender-items pulled
  "bid_rows_opened",             # # LANCES bid rows pulled
  "buyer_item_year_cells_opened",# # opportunity cells opened
  "lances_files_opened",         # # raw LANCES files (if tracked)
  "analyst_hour_proxy_low",      # analyst-hour proxy (low / med / high)
  "analyst_hour_proxy_medium",
  "analyst_hour_proxy_high")

# ---- 1. calculate_cost_denominators ----------------------------------------
# Given a ranked firm/cell panel and per-unit cost weights, accumulate the cost
# denominators over the top-k. `panel` must already carry the per-firm unit
# columns that exist; missing ones are reported in attr(.,"unavailable").
calculate_cost_denominators <- function(panel, denominators = COST_DENOMINATORS) {
  stopifnot(is.data.frame(panel))
  have <- intersect(denominators, names(panel))
  miss <- setdiff(denominators, names(panel))
  if (length(miss))
    message("calculate_cost_denominators: UNAVAILABLE (not in panel): ",
            paste(miss, collapse = ", "))
  out <- panel[, have, drop = FALSE]
  attr(out, "available")   <- have
  attr(out, "unavailable") <- miss
  out
}

# ---- 2. summarize_survivor_pool --------------------------------------------
# After a first-stage cut at K1 (keep top-K1 by score), summarize what survives
# into the second (forensic) stage: pool size + cost denominators carried.
summarize_survivor_pool <- function(panel, score, K1, higher_is_risk = TRUE,
                                    denominators = COST_DENOMINATORS) {
  stopifnot(is.data.frame(panel), length(score) == nrow(panel))
  o <- order(if (higher_is_risk) -score else score, seq_along(score))
  keep <- o[seq_len(min(K1, length(o)))]
  surv <- panel[keep, , drop = FALSE]
  have <- intersect(denominators, names(surv))
  data.frame(
    K1 = length(keep),
    survivor_firms = nrow(surv),
    as.list(setNames(lapply(have, function(d) sum(surv[[d]], na.rm = TRUE)),
                     paste0("sum_", have))),
    check.names = FALSE)
}

# ---- 3. compute_cost_recall_frontier ---------------------------------------
# The core deliverable: for a grid of first-stage cuts K1, compute recall of
# adjudicated positives retained AND each available cost denominator consumed.
# Returns one row per (K1, denominator) so the operator can read the frontier.
compute_cost_recall_frontier <- function(panel, score, labels,
                                         K1_grid = c(250,500,1000,1500,2000,3000,5000),
                                         denominators = COST_DENOMINATORS,
                                         higher_is_risk = TRUE) {
  stopifnot(length(score) == nrow(panel), length(labels) == nrow(panel))
  have <- intersect(denominators, names(panel))
  if (!length(have))
    warning("compute_cost_recall_frontier: NO cost denominators present; recall-only frontier.")
  o <- order(if (higher_is_risk) -score else score, seq_along(score))
  P <- sum(labels == 1L, na.rm = TRUE)
  rows <- list()
  for (K1 in sort(unique(pmin(as.integer(K1_grid), nrow(panel))))) {
    keep <- o[seq_len(K1)]
    rec  <- if (P) sum(labels[keep] == 1L, na.rm = TRUE) / P else NA_real_
    base <- data.frame(K1 = K1, recall = rec,
                       tp = sum(labels[keep] == 1L, na.rm = TRUE), positives = P)
    if (length(have)) {
      for (d in have)
        rows[[length(rows)+1]] <- cbind(base, denominator = d,
                                        cost = sum(panel[[d]][keep], na.rm = TRUE))
    } else {
      rows[[length(rows)+1]] <- cbind(base, denominator = NA_character_, cost = NA_real_)
    }
  }
  do.call(rbind, rows)
}

# ---- 4. compare_rules_at_k --------------------------------------------------
# Compare two or more ranking rules (e.g. FL14 vs log_tc vs Imhof) at matched K.
# `rules` is a named list of score vectors over the SAME panel rows.
compare_rules_at_k <- function(labels, rules, k_grid = c(250,500,1000,2000),
                               higher_is_risk = TRUE) {
  stopifnot(is.list(rules), length(rules) >= 1L)
  do.call(rbind, lapply(names(rules), function(nm) {
    s <- rules[[nm]]
    do.call(rbind, lapply(k_grid, function(k) data.frame(
      rule = nm, k = k,
      precision = precision_at_k(labels, s, k, higher_is_risk),
      recall    = recall_at_k(labels, s, k, higher_is_risk),
      lift      = lift_at_k(labels, s, k, higher_is_risk))))
  }))
}

# ---- 5. export_frontier_table ----------------------------------------------
# Write the frontier to CSV (machine-readable; the LaTeX table is built later
# from this CSV, never hand-typed).
export_frontier_table <- function(frontier, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(frontier, path, row.names = FALSE)
  message("export_frontier_table -> ", path); invisible(path)
}

# ---- 6. frontier_plot_frame -------------------------------------------------
# Prepare a tidy frame for plotting (cost on x, recall on y, one line per
# denominator). Plotting itself is done by the figure script (ggplot), not here.
frontier_plot_frame <- function(frontier) {
  stopifnot(all(c("K1","recall","denominator","cost") %in% names(frontier)))
  frontier[order(frontier$denominator, frontier$cost),
           c("denominator","cost","K1","recall")]
}

# TODO(repo-wiring): the firm/cell panel with cost columns is produced by
# scripts/56_regulatory_cost_frontier.R (NOT YET RUN) and scripts/63/64
# (gatekeeper). Wire those outputs in at Prompt 8. Until then these run on any
# panel that supplies the denominator columns.
.COST_FRONTIER_VERSION <- "v22-2026-06-02"
