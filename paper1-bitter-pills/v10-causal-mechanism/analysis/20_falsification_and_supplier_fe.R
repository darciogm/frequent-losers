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

setFixest_nthreads(12L)
setDTthreads(12L)

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
OUT <- file.path(.this_dir, "..", "output", "tables")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

tex_escape <- function(x) {
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("&", "\\\\&", x, fixed = TRUE)
  x <- gsub("%", "\\\\%", x, fixed = TRUE)
  x <- gsub("_", "\\\\_", x, fixed = TRUE)
  x
}

coef_row <- function(model, term = "urgent") {
  b <- coef(model)[term]
  se <- sqrt(vcov(model)[term, term])
  p <- pvalue(model)[term]
  star <- ifelse(is.na(p), "", ifelse(p < .01, "$^{***}$",
                               ifelse(p < .05, "$^{**}$",
                               ifelse(p < .10, "$^{*}$", ""))))
  list(
    coef = paste0(bp_fmt(b, 3), star),
    se = paste0("(", bp_fmt(se, 3), ")"),
    n = bp_fmt_int(model$nobs),
    r2 = bp_fmt(fitstat(model, "r2")[[1]], 3)
  )
}

term_cell <- function(model, term) {
  if (!(term %in% names(coef(model)))) return(list(coef = "--", se = ""))
  coef_row(model, term)
}

write_supplier_table <- function(path, models) {
  urgent <- lapply(models, term_cell, term = "urgent")
  qty <- lapply(models, term_cell, term = "bid_qty_log")
  lines <- c(
    "\\begin{table}[ht]",
    "\\centering",
    "\\caption{Supplier Fixed Effects and Quantity Controls}",
    "\\label{tab:supplier_fe}",
    "\\begin{threeparttable}",
    "\\small",
    "\\setlength{\\tabcolsep}{5pt}",
    "\\begin{tabular}{lccc}",
    "\\toprule",
    " & Baseline & Supplier FE & Supplier FE + quantity \\\\",
    "\\midrule",
    paste0("Urgent purchase & ", urgent[[1]]$coef, " & ", urgent[[2]]$coef, " & ", urgent[[3]]$coef, " \\\\"),
    paste0(" & ", urgent[[1]]$se, " & ", urgent[[2]]$se, " & ", urgent[[3]]$se, " \\\\"),
    paste0("Log accepted quantity & ", qty[[1]]$coef, " & ", qty[[2]]$coef, " & ", qty[[3]]$coef, " \\\\"),
    paste0(" & ", qty[[1]]$se, " & ", qty[[2]]$se, " & ", qty[[3]]$se, " \\\\"),
    "\\addlinespace",
    paste0("Observations & ", urgent[[1]]$n, " & ", urgent[[2]]$n, " & ", urgent[[3]]$n, " \\\\"),
    paste0("$R^2$ & ", urgent[[1]]$r2, " & ", urgent[[2]]$r2, " & ", urgent[[3]]$r2, " \\\\"),
    "Item FE & Yes & Yes & Yes \\\\",
    "Year FE & Yes & Yes & Yes \\\\",
    "PBU FE & Yes & Yes & Yes \\\\",
    "Supplier FE & No & Yes & Yes \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}[flushleft]\\footnotesize",
    "\\item \\textit{Notes:} The dependent variable is log negotiated price. The sample is accepted winning bids for items observed in both ordinary and litigated procurement. Column 1 includes item, year, and PBU fixed effects. Column 2 adds supplier fixed effects. Column 3 adds log accepted quantity. Standard errors, in parentheses, are clustered by PBU. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{table}"
  )
  writeLines(lines, path)
}

write_placebo_table <- function(path, models) {
  urgent <- lapply(models, term_cell, term = "urgent")
  lines <- c(
    "\\begin{table}[ht]",
    "\\centering",
    "\\caption{Placebo Test on Never-Litigated Items}",
    "\\label{tab:placebo}",
    "\\begin{threeparttable}",
    "\\small",
    "\\setlength{\\tabcolsep}{5pt}",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & \\multicolumn{2}{c}{Negotiated price} & \\multicolumn{2}{c}{Reference price} \\\\",
    "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
    " & Never-litigated & Main sample & Never-litigated & Main sample \\\\",
    "\\midrule",
    paste0("Urgent purchase & ", urgent[[1]]$coef, " & ", urgent[[2]]$coef, " & ", urgent[[3]]$coef, " & ", urgent[[4]]$coef, " \\\\"),
    paste0(" & ", urgent[[1]]$se, " & ", urgent[[2]]$se, " & ", urgent[[3]]$se, " & ", urgent[[4]]$se, " \\\\"),
    "\\addlinespace",
    paste0("Observations & ", urgent[[1]]$n, " & ", urgent[[2]]$n, " & ", urgent[[3]]$n, " & ", urgent[[4]]$n, " \\\\"),
    paste0("$R^2$ & ", urgent[[1]]$r2, " & ", urgent[[2]]$r2, " & ", urgent[[3]]$r2, " & ", urgent[[4]]$r2, " \\\\"),
    "Item FE & Yes & Yes & Yes & Yes \\\\",
    "Year FE & Yes & Yes & Yes & Yes \\\\",
    "PBU FE & Yes & Yes & Yes & Yes \\\\",
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}[flushleft]\\footnotesize",
    "\\item \\textit{Notes:} The never-litigated sample contains items with zero litigated purchases during the sample period and variation between ordinary and administrative urgent purchases. The main sample contains items observed in both ordinary and litigated procurement. All specifications include item, year, and PBU fixed effects. Standard errors, in parentheses, are clustered by PBU. $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{table}"
  )
  writeLines(lines, path)
}


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
    models_placebo <- list(placebo_neg, main_neg, placebo_ref, main_ref)
    if (!is.null(placebo_ref)) {
      placebo_tex <- file.path(OUT, "tab_placebo.tex")
      write_placebo_table(placebo_tex, models_placebo)
      cat("  Saved:", placebo_tex, "\n")
    } else {
      cat("  WARNING: Reference-price placebo unavailable. Skipping table.\n")
    }
  }
} else {
  cat("  WARNING: Placebo sample too small (", nrow(placebo_dt), "obs). Skipping.\n")
}


# EXERCISE 2: SUPPLIER FIXED EFFECTS
# When the SAME firm sells the SAME item, does it charge more in urgent
# tenders? Adding firm FE and quantity controls checks how much of the
# urgent coefficient is explained by supplier composition and scale.

cat("\n--- Exercise 2: Supplier Fixed Effects ---\n")

# Use firm_id as supplier identifier (2,202 unique firms, zero NAs)
win_dt <- dt[po_firm_winner == 1L & has_litigated == TRUE & has_ordinary == TRUE]
win_dt[, firm_f := as.factor(firm_id)]
cat("  Winner observations:", nrow(win_dt), "\n")
cat("  Unique firms:", uniqueN(win_dt$firm_f), "\n")

if (!all(is.na(win_dt$firm_f))) {
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
  cat("  Diagnostic: attenuation after supplier FE is interpreted with the quantity-controlled column.\n")

  # Also with direct effect (controlling for quantity)
  m_firm_fe_qty <- feols(bid_price_log ~ urgent + bid_qty_log | item_id + year_n + pbu_id + firm_f,
                         data = win_dt, cluster = ~pbu_id)

  cat("  With firm FE + qty:     coef =", round(coef(m_firm_fe_qty)["urgent"], 4),
      " SE =", round(sqrt(vcov(m_firm_fe_qty)["urgent","urgent"]), 4), "\n")

  # Save LaTeX table
  models_supplier <- list(m_baseline, m_firm_fe, m_firm_fe_qty)
  supplier_tex <- file.path(OUT, "tab_supplier_fe.tex")
  write_supplier_table(supplier_tex, models_supplier)
  cat("  Saved:", supplier_tex, "\n")
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
