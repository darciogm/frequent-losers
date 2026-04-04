# ============================================================================
# 10_mechanisms.R — Mechanism evidence: dose-response, entry margin,
#                   within-group-65 heterogeneity
# ============================================================================

cat("=== 10_mechanisms.R: Mechanism evidence ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ============================================================================
# 1. DOSE-RESPONSE BY SME MARKET PENETRATION
# ============================================================================
cat("\n  --- Exercise 1: Dose-response by SME market penetration ---\n")

# Dose variable: item QUANTITY (log). The causal forest identified this as
# the dominant moderator (variable importance = 0.486). Large-quantity orders
# are more likely to attract large (non-SME) firms, so the SME restriction
# is more binding for high-quantity items.

# Split at median lquantidade within the pre-period
med_quant <- median(dt[Pre == 1L & !is.na(lquantidade), lquantidade], na.rm = TRUE)
cat("  Median log quantity:", pfmt(med_quant, 3), "\n")
dt[, high_quant := as.integer(lquantidade >= med_quant)]

dose_models <- list()
for (quant_level in c(0L, 1L)) {
  label <- if (quant_level == 0) "low_quant" else "high_quant"
  cat("    ", label, "...\n")
  sub <- dt[high_quant == quant_level]
  dose_models[[paste0(label, "_price_base")]] <-
    run_didir("lpreco_final", sub, WIN_18M, add_pbu = FALSE, completed = TRUE)
  dose_models[[paste0(label, "_price_pbu")]] <-
    run_didir("lpreco_final", sub, WIN_18M, add_pbu = TRUE, completed = TRUE)
  dose_models[[paste0(label, "_firms_base")]] <-
    run_didir("lnum_firms", sub, WIN_18M, add_pbu = FALSE, completed = FALSE)
  dose_models[[paste0(label, "_firms_pbu")]] <-
    run_didir("lnum_firms", sub, WIN_18M, add_pbu = TRUE, completed = FALSE)
}

cat("\n  Dose-response results (18m window, log prices):\n")
cat("    Low quantity:  price=",
    pfmt(coef(dose_models$low_quant_price_base)["g65_pre"], 4),
    " firms=", pfmt(coef(dose_models$low_quant_firms_base)["g65_pre"], 4), "\n")
cat("    High quantity: price=",
    pfmt(coef(dose_models$high_quant_price_base)["g65_pre"], 4),
    " firms=", pfmt(coef(dose_models$high_quant_firms_base)["g65_pre"], 4), "\n")

# ---- Generate table --------------------------------------------------------
cat("  Generating tab_dose_response.tex...\n")

tab <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Dose-Response: Effects by Item Quantity}",
  "\\label{tab:dose_response}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Log firms} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  " & Base & PBU FE & Base & PBU FE \\\\",
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel A: High quantity (above median)}} \\\\"
)

var <- "g65_pre"
hq <- c("high_quant_price_base", "high_quant_price_pbu",
        "high_quant_firms_base", "high_quant_firms_pbu")
lq <- c("low_quant_price_base", "low_quant_price_pbu",
        "low_quant_firms_base", "low_quant_firms_pbu")

coefs_h <- sapply(hq, function(m) coef_cell(dose_models[[m]], var, 4))
ses_h   <- sapply(hq, function(m) se_cell(dose_models[[m]], var, 4))
ns_h    <- sapply(hq, function(m) pfmt_int(nobs(dose_models[[m]])))

coefs_l <- sapply(lq, function(m) coef_cell(dose_models[[m]], var, 4))
ses_l   <- sapply(lq, function(m) se_cell(dose_models[[m]], var, 4))
ns_l    <- sapply(lq, function(m) pfmt_int(nobs(dose_models[[m]])))

tab <- c(tab,
  paste0("$g65 \\times Pre$ & ", paste(coefs_h, collapse = " & "), " \\\\"),
  paste0(" & ", paste(ses_h, collapse = " & "), " \\\\"),
  paste0("Observations & ", paste(ns_h, collapse = " & "), " \\\\"),
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Panel B: Low quantity (below median)}} \\\\",
  paste0("$g65 \\times Pre$ & ", paste(coefs_l, collapse = " & "), " \\\\"),
  paste0(" & ", paste(ses_l, collapse = " & "), " \\\\"),
  paste0("Observations & ", paste(ns_l, collapse = " & "), " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  paste0("\\item \\textit{Notes:} 18-month window. The sample is split at the median of ",
         "log quantity (", pfmt(med_quant, 2), "). High-quantity items are more likely to attract ",
         "large non-SME suppliers, so the SME restriction is more binding for these items. ",
         "This split aligns with the causal forest finding that item quantity is the dominant ",
         "source of treatment effect heterogeneity (variable importance = 0.486). ",
         "SE clustered at item level. * $p<0.10$, ** $p<0.05$, *** $p<0.01$."),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(tab, file.path(OUT_TAB, "tab_dose_response.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_dose_response.tex"), "\n")

# ============================================================================
# 2. ENTRY MARGIN: WHO ENTERS UNDER OPEN TENDERS?
# ============================================================================
cat("\n  --- Exercise 2: Entry margin decomposition ---\n")

# The tab_sme_winner already shows that the probability of SME winner drops
# by 34-41pp under open tenders. Here we put price, firms, and SME winner
# side by side to tell the mechanism story, plus add log(non-SME firms proxy).

# Since we can't decompose firm counts by type directly, we create
# an indirect decomposition:
# - Total firms increase (already known)
# - SME winner probability drops (already known)
# - NEW: interaction g65_pre × quantity to show scale-dependent entry

# More useful: show that the price effect is MEDIATED by firm entry
# Run the "short" and "long" regressions for the Gelbach-style narrative

cat("  Running mechanism panel (18m, base spec)...\n")

# DV set for mechanism narrative
mech_dvs <- list(
  list(dv = "lpreco_final", completed = TRUE,  label = "Log price"),
  list(dv = "lnum_firms",   completed = FALSE, label = "Log firms"),
  list(dv = "sme_winner",   completed = TRUE,  label = "SME winner")
)

mech_models <- list()
for (v in mech_dvs) {
  cat("    ", v$label, "...\n")
  mech_models[[v$label]] <-
    run_didir(v$dv, dt, WIN_18M, add_pbu = FALSE, completed = v$completed)
}

# Also: price regression controlling for log firms (to show mediation)
cat("    Log price + log firms control...\n")
sub_18m <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
               oc_item_status == 1L]
mech_models[["Price + firms"]] <- feols(
  lpreco_final ~ g65_pre + convite + lquantidade + lnum_firms | item_alt,
  data = sub_18m, cluster = ~item_alt, fixef.rm = "none"
)

# Price controlling for SME winner
cat("    Log price + SME winner control...\n")
mech_models[["Price + SME"]] <- feols(
  lpreco_final ~ g65_pre + convite + lquantidade + sme_winner | item_alt,
  data = sub_18m, cluster = ~item_alt, fixef.rm = "none"
)

# Price controlling for both
cat("    Log price + both controls...\n")
mech_models[["Price + both"]] <- feols(
  lpreco_final ~ g65_pre + convite + lquantidade + lnum_firms + sme_winner | item_alt,
  data = sub_18m, cluster = ~item_alt, fixef.rm = "none"
)

# ---- Generate mechanism table -----------------------------------------------
cat("  Generating tab_entry_margin.tex...\n")

var <- "g65_pre"
mlabels <- c("Log price", "Log firms", "SME winner",
             "Price + firms", "Price + SME", "Price + both")

tab <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Mechanism Decomposition: Entry Margin and Winner Composition}",
  "\\label{tab:entry_margin}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccccc}",
  "\\toprule",
  paste0(" & ", paste(paste0("(", 1:6, ")"), collapse = " & "), " \\\\"),
  paste0(" & ", paste(mlabels, collapse = " & "), " \\\\"),
  "\\midrule"
)

coefs <- sapply(mlabels, function(m) coef_cell(mech_models[[m]], var, 4))
ses   <- sapply(mlabels, function(m) se_cell(mech_models[[m]], var, 4))
ns    <- sapply(mlabels, function(m) pfmt_int(nobs(mech_models[[m]])))

tab <- c(tab,
  paste0("$g65 \\times Pre$ & ", paste(coefs, collapse = " & "), " \\\\"),
  paste0(" & ", paste(ses, collapse = " & "), " \\\\"),
  "\\midrule"
)

# Add mediator coefficients where applicable
for (med in c("lnum_firms", "sme_winner")) {
  cells <- character(6)
  se_cells_m <- character(6)
  for (i in seq_along(mlabels)) {
    m <- mech_models[[mlabels[i]]]
    if (med %in% names(coef(m))) {
      cells[i] <- coef_cell(m, med, 4)
      se_cells_m[i] <- se_cell(m, med, 4)
    } else {
      cells[i] <- ""
      se_cells_m[i] <- ""
    }
  }
  med_label <- if (med == "lnum_firms") "Log firms" else "SME winner"
  tab <- c(tab,
    paste0(med_label, " & ", paste(cells, collapse = " & "), " \\\\"),
    paste0(" & ", paste(se_cells_m, collapse = " & "), " \\\\")
  )
}

tab <- c(tab,
  "\\midrule",
  paste0("Observations & ", paste(ns, collapse = " & "), " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} 18-month window, item FE, SE clustered at item level. ",
  "Columns (1)--(3): DiDiR for each outcome separately. ",
  "Column (4): price regression adding log firms as control (mediation by competition). ",
  "Column (5): price regression adding SME winner indicator (mediation by composition). ",
  "Column (6): price regression with both mediators. ",
  "The attenuation of the $g65 \\times Pre$ coefficient from (1) to (4)--(6) measures ",
  "the fraction of the price effect explained by each channel. ",
  "* $p<0.10$, ** $p<0.05$, *** $p<0.01$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{adjustbox}",
  "\\end{table}"
)

writeLines(tab, file.path(OUT_TAB, "tab_entry_margin.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_entry_margin.tex"), "\n")

# Print the mediation story
cat("\n  Mediation story:\n")
cat("    Baseline price coef:", pfmt(coef(mech_models[["Log price"]])[var], 4), "\n")
cat("    + firms control:    ", pfmt(coef(mech_models[["Price + firms"]])[var], 4), "\n")
cat("    + SME control:      ", pfmt(coef(mech_models[["Price + SME"]])[var], 4), "\n")
cat("    + both:             ", pfmt(coef(mech_models[["Price + both"]])[var], 4), "\n")
base_coef <- coef(mech_models[["Log price"]])[var]
both_coef <- coef(mech_models[["Price + both"]])[var]
cat("    Explained fraction: ", pfmt(1 - both_coef/base_coef, 3), "\n")

# ============================================================================
# 3. WITHIN-GROUP-65 HETEROGENEITY: MEDICATIONS VS. OTHER
# ============================================================================
cat("\n  --- Exercise 3: Within-group-65 (class 6531 vs rest) ---\n")

if ("class_alt" %in% names(dt)) {
  # Class 6531 = medications (CMED-regulated, oligopolistic)
  # Other g65 classes = hospital supplies, dental, etc. (more competitive)
  dt[, medication := as.integer(!is.na(class_alt) & class_alt == 6531L)]

  # Check distribution
  cat("  Class 6531 (medications) in g65:\n")
  cat("    g65 & medication:", dt[g65==1 & medication==1, .N], "\n")
  cat("    g65 & other:     ", dt[g65==1 & medication==0, .N], "\n")
  cat("    non-g65:         ", dt[g65==0, .N], "\n")

  within_models <- list()

  # Panel A: Medications only (g65 medication items vs all non-g65)
  cat("  Panel A: Medications (class 6531) only...\n")
  sub_med <- dt[medication == 1L | g65 == 0L]
  # Redefine g65 to be medication items only
  sub_med[, g65_med := as.integer(medication == 1L)]
  sub_med[, g65_pre_med := g65_med * Pre]

  for (spec in c("base", "pbu")) {
    add_pbu <- spec == "pbu"
    fe <- if (add_pbu) "item_alt + pbu_alt" else "item_alt"
    for (v in list(list(dv = "lpreco_final", comp = TRUE, lab = "price"),
                   list(dv = "lnum_firms", comp = FALSE, lab = "firms"))) {
      s <- sub_med[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
      if (v$comp) s <- s[oc_item_status == 1L]
      fml <- as.formula(paste0(v$dv, " ~ g65_pre_med + convite + lquantidade | ", fe))
      within_models[[paste0("med_", v$lab, "_", spec)]] <-
        feols(fml, data = s, cluster = ~item_alt, fixef.rm = "none")
    }
  }

  # Panel B: Non-medication g65 items vs all non-g65
  cat("  Panel B: Non-medication g65 items...\n")
  sub_nonmed <- dt[g65 == 0L | (g65 == 1L & medication == 0L)]
  sub_nonmed[, g65_nonmed := as.integer(g65 == 1L & medication == 0L)]
  sub_nonmed[, g65_pre_nonmed := g65_nonmed * Pre]

  for (spec in c("base", "pbu")) {
    add_pbu <- spec == "pbu"
    fe <- if (add_pbu) "item_alt + pbu_alt" else "item_alt"
    for (v in list(list(dv = "lpreco_final", comp = TRUE, lab = "price"),
                   list(dv = "lnum_firms", comp = FALSE, lab = "firms"))) {
      s <- sub_nonmed[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
      if (v$comp) s <- s[oc_item_status == 1L]
      fml <- as.formula(paste0(v$dv, " ~ g65_pre_nonmed + convite + lquantidade | ", fe))
      within_models[[paste0("nonmed_", v$lab, "_", spec)]] <-
        feols(fml, data = s, cluster = ~item_alt, fixef.rm = "none")
    }
  }

  # Print comparison
  cat("\n  Within-g65 results (18m, base):\n")
  cat("    Medications (6531):  price=",
      pfmt(coef(within_models$med_price_base)["g65_pre_med"], 4),
      " firms=", pfmt(coef(within_models$med_firms_base)["g65_pre_med"], 4), "\n")
  cat("    Other g65 classes:   price=",
      pfmt(coef(within_models$nonmed_price_base)["g65_pre_nonmed"], 4),
      " firms=", pfmt(coef(within_models$nonmed_firms_base)["g65_pre_nonmed"], 4), "\n")

  # ---- Generate table --------------------------------------------------------
  cat("  Generating tab_within_g65.tex...\n")

  tab <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    "\\caption{Within-Group-65 Heterogeneity: Medications vs.\\ Other Medical Supplies}",
    "\\label{tab:within_g65}",
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Log firms} \\\\",
    "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
    " & Base & PBU FE & Base & PBU FE \\\\",
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel A: Medications (class 6531)}} \\\\"
  )

  # Panel A
  med_mnames <- c("med_price_base", "med_price_pbu", "med_firms_base", "med_firms_pbu")
  med_vars <- c("g65_pre_med", "g65_pre_med", "g65_pre_med", "g65_pre_med")
  coefs_a <- sapply(seq_along(med_mnames), function(i) coef_cell(within_models[[med_mnames[i]]], med_vars[i], 4))
  ses_a   <- sapply(seq_along(med_mnames), function(i) se_cell(within_models[[med_mnames[i]]], med_vars[i], 4))
  ns_a    <- sapply(med_mnames, function(m) pfmt_int(nobs(within_models[[m]])))

  tab <- c(tab,
    paste0("$g65_{med} \\times Pre$ & ", paste(coefs_a, collapse = " & "), " \\\\"),
    paste0(" & ", paste(ses_a, collapse = " & "), " \\\\"),
    paste0("Observations & ", paste(ns_a, collapse = " & "), " \\\\"),
    "\\midrule",
    "\\multicolumn{5}{l}{\\textit{Panel B: Other medical supplies (non-6531)}} \\\\"
  )

  # Panel B
  nm_mnames <- c("nonmed_price_base", "nonmed_price_pbu", "nonmed_firms_base", "nonmed_firms_pbu")
  nm_vars <- c("g65_pre_nonmed", "g65_pre_nonmed", "g65_pre_nonmed", "g65_pre_nonmed")
  coefs_b <- sapply(seq_along(nm_mnames), function(i) coef_cell(within_models[[nm_mnames[i]]], nm_vars[i], 4))
  ses_b   <- sapply(seq_along(nm_mnames), function(i) se_cell(within_models[[nm_mnames[i]]], nm_vars[i], 4))
  ns_b    <- sapply(nm_mnames, function(m) pfmt_int(nobs(within_models[[m]])))

  tab <- c(tab,
    paste0("$g65_{other} \\times Pre$ & ", paste(coefs_b, collapse = " & "), " \\\\"),
    paste0(" & ", paste(ses_b, collapse = " & "), " \\\\"),
    paste0("Observations & ", paste(ns_b, collapse = " & "), " \\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    "\\item \\textit{Notes:} 18-month window. Panel A restricts group 65 to class 6531 ",
    "(medications, subject to CMED pharmaceutical price regulation), using all non-group-65 items ",
    "as the comparison. Panel B restricts group 65 to non-medication medical supplies ",
    "(hospital equipment, dental supplies, etc.). If the price effect were driven by ",
    "differential pharmaceutical inflation rather than competition, it should appear ",
    "primarily in Panel A. SE clustered at item level. ",
    "* $p<0.10$, ** $p<0.05$, *** $p<0.01$.",
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  writeLines(tab, file.path(OUT_TAB, "tab_within_g65.tex"))
  cat("  Saved:", file.path(OUT_TAB, "tab_within_g65.tex"), "\n")
}

# ---- Save all results -------------------------------------------------------
saveRDS(list(dose_models = if(exists("dose_models")) dose_models else NULL,
             mech_models = mech_models,
             within_models = if(exists("within_models")) within_models else NULL),
        "/tmp/p2_mechanisms.rds")

rm(dt, sub_18m)
gc(verbose = FALSE)

cat("\n=== 10_mechanisms.R: Done ===\n")
