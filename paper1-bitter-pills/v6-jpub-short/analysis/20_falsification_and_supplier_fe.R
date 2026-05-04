# 20_falsification_and_supplier_fe.R
# Darcio Genicolo-Martins — INSPER, 2026
#
# Two new empirical exercises for the JPub short paper:
#   (1) Placebo test: run the main regression on items NEVER litigated
#   (2) Supplier FE: add firm FE to separate demand vs supply side
#
# Uses cached data from 00_prepare_data.R (/tmp/v4_prepared.rds)


library(data.table)
library(fixest)

setFixest_nthreads(16L)
setDTthreads(16L)

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "_macros.R"))

DATA_CACHE <- "/tmp/v4_prepared.rds"
if (!file.exists(DATA_CACHE)) stop("Run 00_prepare_data.R first")

dt <- readRDS(DATA_CACHE)
cat("Loaded:", nrow(dt), "obs\n")

# Output directory
OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v6-jpub-short/output/tables"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)


# EXERCISE 1: PLACEBO — Items never litigated
# If our identification is correct, the "urgent" coefficient should be
# zero or much smaller for items that are never subject to court orders.
# These items have no reason to show an urgency premium — any non-zero
# coefficient would indicate confounding.

cat("\n--- Exercise 1: Placebo (never-litigated items) ---\n")

# Items that NEVER have a litigated purchase (type 2)
never_litigated_items <- dt[, .(ever_litigated = any(purchase_type == 2)), by = item]
never_lit <- never_litigated_items[ever_litigated == FALSE, item]
cat("  Never-litigated items:", length(never_lit), "\n")
cat("  Ever-litigated items:", sum(never_litigated_items$ever_litigated), "\n")

# But we need items that have BOTH ordinary and urgent (admin) purchases
# among the never-litigated set
placebo_dt <- dt[item %in% never_lit]
placebo_dt <- placebo_dt[, has_both := any(purchase_type == 0) & any(purchase_type == 1), by = item]
placebo_dt <- placebo_dt[has_both == TRUE]
cat("  Placebo sample (never-litigated, has ordinary+admin):", nrow(placebo_dt), "obs\n")
cat("  Items:", uniqueN(placebo_dt$item), "\n")

if (nrow(placebo_dt) > 100) {
  # Main sample for comparison
  main_dt <- dt[has_litigated == TRUE & has_ordinary == TRUE]

  # Placebo regression: same spec as main, on never-litigated items
  placebo_neg <- tryCatch(
    feols(bid_price_log ~ urgent | item_id + year_n + pbu_id,
          data = placebo_dt[po_firm_winner == 1],
          cluster = ~pbu_id),
    error = function(e) { cat("  Placebo neg price failed:", e$message, "\n"); NULL })

  # Main regression for comparison
  main_neg <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id,
                    data = main_dt[po_firm_winner == 1],
                    cluster = ~pbu_id)

  cat("\n  Placebo vs main, negotiated price:\n")
  if (!is.null(placebo_neg)) {
    cat("  Placebo (never-litigated): coef =", round(coef(placebo_neg)["urgent"], 4),
        " SE =", round(sqrt(vcov(placebo_neg)["urgent","urgent"]), 4),
        " N =", placebo_neg$nobs, "\n")
  }
  cat("  Main (ever-litigated):     coef =", round(coef(main_neg)["urgent"], 4),
      " SE =", round(sqrt(vcov(main_neg)["urgent","urgent"]), 4),
      " N =", main_neg$nobs, "\n")

  # Also for reference price
  placebo_ref <- tryCatch(
    feols(bid_price_ref_log ~ urgent | item_id + year_n + pbu_id,
          data = placebo_dt,
          cluster = ~pbu_id),
    error = function(e) { cat("  Placebo ref price failed:", e$message, "\n"); NULL })

  main_ref <- feols(bid_price_ref_log ~ urgent | item_id + year_n + pbu_id,
                    data = main_dt,
                    cluster = ~pbu_id)

  cat("\n  Placebo vs main, reference price:\n")
  if (!is.null(placebo_ref)) {
    cat("  Placebo (never-litigated): coef =", round(coef(placebo_ref)["urgent"], 4),
        " SE =", round(sqrt(vcov(placebo_ref)["urgent","urgent"]), 4),
        " N =", placebo_ref$nobs, "\n")
  }
  cat("  Main (ever-litigated):     coef =", round(coef(main_ref)["urgent"], 4),
      " SE =", round(sqrt(vcov(main_ref)["urgent","urgent"]), 4),
      " N =", main_ref$nobs, "\n")

  # Save LaTeX table
  if (!is.null(placebo_neg)) {
    models_placebo <- list(
      "Placebo: Neg. Price" = placebo_neg,
      "Main: Neg. Price" = main_neg
    )
    if (!is.null(placebo_ref)) {
      models_placebo <- c(models_placebo, list(
        "Placebo: Ref. Price" = placebo_ref,
        "Main: Ref. Price" = main_ref
      ))
    }
    placebo_tex <- file.path(OUT, "tab_placebo.tex")
    etable(models_placebo,
           file = placebo_tex,
           replace = TRUE,
           title = "Placebo Test: Items Never Subject to Litigation",
           dict = c(urgent = "Urgent Purchase"),
           style.tex = style.tex("aer"),
           notes = "Placebo sample: items with zero litigated purchases across 2009-2019. Main sample: items with at least one litigated and one ordinary purchase. DV: log price. Item + Year + PBU FE. SE clustered at PBU level.")
    # etable's "aer" style emits a \begingroup wrapper without \begin{table}/\caption/\label.
    # Wrap it ourselves so cross-refs (\ref{tab:placebo}) resolve in the manuscript.
    raw <- readLines(placebo_tex)
    wrapped <- c(
      "\\begin{table}[ht]",
      "  \\centering",
      "  \\caption{Placebo Test: Items Never Subject to Litigation}",
      "  \\label{tab:placebo}",
      "  \\small",
      raw,
      "\\end{table}"
    )
    writeLines(wrapped, placebo_tex)
    cat("  Saved (wrapped with caption/label):", placebo_tex, "\n")
  }
} else {
  cat("  WARNING: Placebo sample too small (", nrow(placebo_dt), "obs). Skipping.\n")
}


# EXERCISE 2: SUPPLIER FIXED EFFECTS
# When the SAME firm sells the SAME item, does it charge more in urgent
# tenders? Adding firm FE separates demand-side pressure (official accepts
# higher price) from supply-side exploitation (firm charges more because
# it knows the government is desperate).

cat("\n--- Exercise 2: Supplier Fixed Effects ---\n")

# Use firm_id as supplier identifier (2,202 unique firms, zero NAs)
win_dt <- dt[po_firm_winner == 1L & has_litigated == TRUE & has_ordinary == TRUE]
win_dt[, firm_f := as.factor(firm_id)]
cat("  Winner observations:", nrow(win_dt), "\n")
cat("  Unique firms:", uniqueN(win_dt$firm_f), "\n")

if (!all(is.na(win_dt$firm_f))) {
  cat("  Unique firms:", uniqueN(win_dt$firm_f), "\n")

  # Baseline: item + year + PBU FE (preferred spec)
  m_baseline <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id,
                      data = win_dt, cluster = ~pbu_id)

  # Add firm FE
  m_firm_fe <- feols(bid_price_log ~ urgent | item_id + year_n + pbu_id + firm_f,
                     data = win_dt, cluster = ~pbu_id)

  cat("\n  Negotiated price, baseline vs firm FE:\n")
  cat("  Baseline (no firm FE):  coef =", round(coef(m_baseline)["urgent"], 4),
      " SE =", round(sqrt(vcov(m_baseline)["urgent","urgent"]), 4),
      " N =", m_baseline$nobs, "\n")
  cat("  With firm FE:           coef =", round(coef(m_firm_fe)["urgent"], 4),
      " SE =", round(sqrt(vcov(m_firm_fe)["urgent","urgent"]), 4),
      " N =", m_firm_fe$nobs, "\n")

  attenuation <- 1 - coef(m_firm_fe)["urgent"] / coef(m_baseline)["urgent"]
  cat("  Attenuation:", round(100 * attenuation, 1), "%\n")

  if (attenuation > 0.5) {
    cat("  INTERPRETATION: >50% attenuation — substantial supply-side component.\n")
    cat("  Firms charge more in urgent tenders, not just officials accepting more.\n")
  } else {
    cat("  INTERPRETATION: <50% attenuation — primarily demand-side.\n")
    cat("  Officials accept worse terms; firms don't systematically exploit urgency.\n")
  }

  # Also with direct effect (controlling for quantity)
  m_firm_fe_qty <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id + firm_f,
                         data = win_dt, cluster = ~pbu_id)

  cat("  With firm FE + qty:     coef =", round(coef(m_firm_fe_qty)["urgent"], 4),
      " SE =", round(sqrt(vcov(m_firm_fe_qty)["urgent","urgent"]), 4), "\n")

  # Save LaTeX table
  models_supplier <- list(
    "(1) Baseline" = m_baseline,
    "(2) + Firm FE" = m_firm_fe,
    "(3) + Firm FE + Qty" = m_firm_fe_qty
  )
  supplier_tex <- file.path(OUT, "tab_supplier_fe.tex")
  etable(models_supplier,
         file = supplier_tex,
         replace = TRUE,
         title = "Supplier Fixed Effects: Demand vs Supply Side",
         dict = c(urgent = "Urgent Purchase", bid_qty_log = "Log Quantity"),
         style.tex = style.tex("aer"),
         notes = "DV: log negotiated price. Sample: winning bids for items with both ordinary and litigated purchases. Column (1): item + year + PBU FE. Column (2) adds firm FE. Column (3) adds log quantity. SE clustered at PBU level.")
  # Wrap with caption + label so \ref{tab:supplier_fe} resolves.
  raw <- readLines(supplier_tex)
  wrapped <- c(
    "\\begin{table}[ht]",
    "  \\centering",
    "  \\caption{Supplier Fixed Effects: Demand vs Supply Side}",
    "  \\label{tab:supplier_fe}",
    "  \\small",
    raw,
    "\\end{table}"
  )
  writeLines(wrapped, supplier_tex)
  cat("  Saved (wrapped with caption/label):", supplier_tex, "\n")
}


# Emit macros for the manuscript layer
macros <- list()
if (exists("placebo_neg") && !is.null(placebo_neg)) {
  macros$placeboNegCoef <- bp_fmt(coef(placebo_neg)["urgent"], 3)
  macros$placeboNegSE   <- bp_fmt(sqrt(vcov(placebo_neg)["urgent","urgent"]), 3)
}
if (exists("placebo_ref") && !is.null(placebo_ref)) {
  macros$placeboRefCoef <- bp_fmt(coef(placebo_ref)["urgent"], 3)
  macros$placeboRefSE   <- bp_fmt(sqrt(vcov(placebo_ref)["urgent","urgent"]), 3)
}
if (exists("m_baseline")) {
  bb <- coef(m_baseline)["urgent"]
  macros$supBaseline    <- bp_fmt(bb, 3)
  macros$supBaselinePct <- bp_fmt_pct((exp(bb) - 1) * 100, 1)
}
if (exists("m_firm_fe")) {
  macros$supFirmFE     <- bp_fmt(coef(m_firm_fe)["urgent"], 3)
  if (exists("m_baseline")) {
    attn <- 1 - coef(m_firm_fe)["urgent"] / coef(m_baseline)["urgent"]
    macros$supFirmFEAttn <- bp_fmt_pct_n(100 * attn, 0)
  }
}
if (exists("m_firm_fe_qty")) {
  macros$supFirmFEqty <- bp_fmt(coef(m_firm_fe_qty)["urgent"], 3)
}
if (length(macros) > 0) bp_macros_emit("20_falsification_and_supplier_fe", macros)

cat("\n20_falsification_and_supplier_fe.R complete\n")
