# =============================================================================
# 19_v8_adm_vs_ord.R — V8: Administrative vs Ordinary Regressions
# Bitter Pills to Swallow — v4 (R/fixest)
#
# Replicates ALL 8 outcome specifications from the urgent analysis for the
# administrative vs ordinary comparison (purchase_type 1 vs 0).
#
# Produces:
#   - 5 publication-ready tables (booktabs/threeparttable)
#   - 1 coefficient plot (90% + 95% CI, grayscale)
#   - 14 modelsummary tables (LaTeX + HTML)
#   - 9 checkpoint .rds files
#
# Output directories: v4/pub/tables_v8/, v4/manuscript_v8/, v4/results_v8/
# =============================================================================

cat("=== 19_v8_adm_vs_ord.R — V8: Administrative vs Ordinary ===\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
t_start <- proc.time()

# --- Boilerplate ---
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
source(file.path(.this_dir, "utils.R"))

# =============================================================================
# HARDWARE DETECTION & MAX PERFORMANCE
# =============================================================================
cat("=== Hardware Detection ===\n")
n_cores <- parallel::detectCores(logical = TRUE)
ram_gb  <- as.numeric(system("free -b | awk '/Mem:/{print $2}'", intern = TRUE)) / 1e9
cat(sprintf("  CPU cores (logical): %d\n", n_cores))
cat(sprintf("  RAM total: %.1f GB\n", ram_gb))

setFixest_nthreads(n_cores)
setDTthreads(n_cores)
cat(sprintf("  fixest threads: %d\n", n_cores))
cat(sprintf("  data.table threads: %d\n", n_cores))

# --- Output directories -------------------------------------------------------
PUB_TAB_V8 <- file.path(V4, "pub", "tables_v8")
PUB_FIG_V8 <- file.path(V4, "pub", "figures")
MANU_V8    <- file.path(V4, "manuscript_v8")
RESU_V8    <- file.path(V4, "results_v8")
CHECKPOINT <- file.path(V4, "checkpoints_v8")
for (d in c(PUB_TAB_V8, PUB_FIG_V8, MANU_V8, RESU_V8, CHECKPOINT)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# --- Timing log ---------------------------------------------------------------
timing_log <- list()
log_time <- function(label, t0) {
  elapsed <- (proc.time() - t0)[["elapsed"]]
  timing_log[[label]] <<- elapsed
  cat(sprintf("  [%s] %.1f sec\n", label, elapsed))
}

# =============================================================================
# FORMATTING HELPERS (from 16_v7_extensions.R)
# =============================================================================
pfmt     <- function(x, d = 3) formatC(x, format = "f", digits = d, big.mark = ",")
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")
pstars   <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.01) return("***")
  if (p < 0.05) return("**")
  if (p < 0.1)  return("*")
  ""
}
get_wr2 <- function(m) {
  w <- tryCatch(as.numeric(fixest::r2(m, "wr2")), error = function(e) NA_real_)
  if (is.null(w) || length(w) == 0 || is.na(w)) return(NA_real_)
  w
}

fe_labels_4spec <- list(
  "Item FE"        = c("Yes", "Yes", "Yes", "Yes"),
  "Year FE"        = c("No",  "Yes", "Yes", "No"),
  "Year-Month FE"  = c("No",  "No",  "No",  "Yes"),
  "PBU FE"         = c("No",  "No",  "Yes", "Yes")
)

default_note <- paste0(
  "Standard errors clustered at the PBU level in parentheses. ",
  "Sample restricted to items with both administrative and ordinary purchases. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)

# --- save_table_v8 ---
save_table_v8 <- function(models, title, filename,
                          coef_map = NULL, gof_map = NULL,
                          add_rows = NULL, notes = NULL) {
  if (is.null(gof_map)) {
    gof_map <- c("nobs" = "Observations", "r.squared" = "R^2",
                 "adj.r.squared" = "Adj. R^2",
                 "within.r.squared" = "Within R^2")
  }
  tex_file <- file.path(MANU_V8, paste0(filename, ".tex"))
  modelsummary(models, output = tex_file,
               title = title, coef_map = coef_map, gof_map = gof_map,
               add_rows = add_rows, notes = notes,
               stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
               escape = FALSE)
  html_file <- file.path(RESU_V8, paste0(filename, ".html"))
  modelsummary(models, output = html_file,
               title = title, coef_map = coef_map, gof_map = gof_map,
               add_rows = add_rows, notes = notes,
               stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01))
  cat("    Saved:", basename(tex_file), "+", basename(html_file), "\n")
}

# --- write_reg_table_v8: publication-ready single-panel table ---
write_reg_table_v8 <- function(models, coef_vars, coef_labs, title, label,
                               filename, note = NULL, fe_labels = NULL,
                               digits = 3, show_wr2 = TRUE) {
  n <- length(models)
  if (is.null(fe_labels)) fe_labels <- fe_labels_4spec
  if (is.null(note)) note <- default_note

  lines <- c(
    "\\begin{table}[ht]",
    "  \\centering",
    paste0("  \\caption{", title, "}"),
    paste0("  \\label{tab:", label, "}"),
    "  \\small",
    "  \\begin{threeparttable}",
    paste0("  \\begin{tabular}{l", paste(rep("c", n), collapse = ""), "}"),
    "    \\hline\\hline",
    paste0("    & ", paste(paste0("(", seq_len(n), ")"), collapse = " & "), " \\\\"),
    "    \\hline"
  )

  for (v in coef_vars) {
    cells <- se_cells <- character(n)
    for (j in seq_len(n)) {
      b <- coef(models[[j]])[v]
      s <- se(models[[j]])[v]
      p <- pvalue(models[[j]])[v]
      if (is.na(b)) { cells[j] <- ""; se_cells[j] <- "" }
      else {
        cells[j] <- paste0(pfmt(b, digits), pstars(p))
        se_cells[j] <- paste0("(", pfmt(s, digits), ")")
      }
    }
    lines <- c(lines,
      paste0("    ", coef_labs[v], " & ", paste(cells, collapse = " & "), " \\\\"),
      paste0("     & ", paste(se_cells, collapse = " & "), " \\\\[3pt]")
    )
  }

  lines <- c(lines, "    \\hline")
  for (fe_name in names(fe_labels)) {
    vals <- fe_labels[[fe_name]]
    lines <- c(lines,
      paste0("    ", fe_name, " & ", paste(vals[seq_len(n)], collapse = " & "), " \\\\")
    )
  }

  obs <- sapply(models, function(m) pfmt_int(m$nobs))
  lines <- c(lines, paste0("    Observations & ", paste(obs, collapse = " & "), " \\\\"))

  if (show_wr2) {
    wr2 <- sapply(models, function(m) {
      w <- get_wr2(m); if (is.na(w)) "" else pfmt(w, 3)
    })
    lines <- c(lines, paste0("    Within R$^2$ & ", paste(wr2, collapse = " & "), " \\\\"))
  }

  lines <- c(lines,
    "    \\hline\\hline",
    "  \\end{tabular}",
    "  \\begin{tablenotes}",
    "    \\small",
    paste0("    \\item \\textit{Notes:} ", note),
    "  \\end{tablenotes}",
    "  \\end{threeparttable}",
    "\\end{table}"
  )

  filepath <- file.path(PUB_TAB_V8, filename)
  writeLines(lines, filepath)
  cat("    Pub table:", basename(filepath), "\n")
}

# --- write_panel_reg_table_v8: two-panel pub table ---
write_panel_reg_table_v8 <- function(models_a, models_b,
                                     coef_vars_a, coef_vars_b,
                                     coef_labs,
                                     panel_a_title, panel_b_title,
                                     title, label, filename,
                                     note = NULL, fe_labels = NULL,
                                     digits = 3) {
  n <- length(models_a)
  if (is.null(fe_labels)) fe_labels <- fe_labels_4spec
  if (is.null(note)) note <- default_note

  write_coef_block <- function(models, cvars) {
    block <- character()
    for (v in cvars) {
      cells <- se_cells <- character(n)
      for (j in seq_len(n)) {
        b <- coef(models[[j]])[v]
        s <- se(models[[j]])[v]
        p <- pvalue(models[[j]])[v]
        if (is.na(b)) { cells[j] <- ""; se_cells[j] <- "" }
        else {
          cells[j] <- paste0(pfmt(b, digits), pstars(p))
          se_cells[j] <- paste0("(", pfmt(s, digits), ")")
        }
      }
      block <- c(block,
        paste0("    ", coef_labs[v], " & ", paste(cells, collapse = " & "), " \\\\"),
        paste0("     & ", paste(se_cells, collapse = " & "), " \\\\[3pt]")
      )
    }
    block
  }

  ncol <- n + 1
  lines <- c(
    "\\begin{table}[ht]",
    "  \\centering",
    paste0("  \\caption{", title, "}"),
    paste0("  \\label{tab:", label, "}"),
    "  \\small",
    "  \\begin{threeparttable}",
    paste0("  \\begin{tabular}{l", paste(rep("c", n), collapse = ""), "}"),
    "    \\hline\\hline",
    paste0("    & ", paste(paste0("(", seq_len(n), ")"), collapse = " & "), " \\\\"),
    "    \\hline",
    paste0("    \\multicolumn{", ncol, "}{l}{\\textit{", panel_a_title, "}} \\\\[3pt]")
  )
  lines <- c(lines, write_coef_block(models_a, coef_vars_a))

  lines <- c(lines,
    "    \\hline",
    paste0("    \\multicolumn{", ncol, "}{l}{\\textit{", panel_b_title, "}} \\\\[3pt]")
  )
  lines <- c(lines, write_coef_block(models_b, coef_vars_b))

  lines <- c(lines, "    \\hline")
  for (fe_name in names(fe_labels)) {
    vals <- fe_labels[[fe_name]]
    lines <- c(lines,
      paste0("    ", fe_name, " & ", paste(vals[seq_len(n)], collapse = " & "), " \\\\")
    )
  }

  obs_a <- sapply(models_a, function(m) pfmt_int(m$nobs))
  obs_b <- sapply(models_b, function(m) pfmt_int(m$nobs))
  if (identical(obs_a, obs_b)) {
    lines <- c(lines,
      paste0("    Observations & ", paste(obs_a, collapse = " & "), " \\\\"))
  } else {
    lines <- c(lines,
      paste0("    Obs.\\ (Panel~A) & ", paste(obs_a, collapse = " & "), " \\\\"),
      paste0("    Obs.\\ (Panel~B) & ", paste(obs_b, collapse = " & "), " \\\\"))
  }

  wr2_a <- sapply(models_a, function(m) {
    w <- get_wr2(m); if (is.na(w)) "" else pfmt(w, 3)
  })
  wr2_b <- sapply(models_b, function(m) {
    w <- get_wr2(m); if (is.na(w)) "" else pfmt(w, 3)
  })
  lines <- c(lines,
    paste0("    Within R$^2$ (A) & ", paste(wr2_a, collapse = " & "), " \\\\"),
    paste0("    Within R$^2$ (B) & ", paste(wr2_b, collapse = " & "), " \\\\")
  )

  lines <- c(lines,
    "    \\hline\\hline",
    "  \\end{tabular}",
    "  \\begin{tablenotes}",
    "    \\small",
    paste0("    \\item \\textit{Notes:} ", note),
    "  \\end{tablenotes}",
    "  \\end{threeparttable}",
    "\\end{table}"
  )

  filepath <- file.path(PUB_TAB_V8, filename)
  writeLines(lines, filepath)
  cat("    Pub table:", basename(filepath), "\n")
}

# =============================================================================
# LOAD DATA & PREPARE SAMPLE
# =============================================================================

cat("\n=== Loading data ===\n")
t0 <- proc.time()
dt_raw <- readRDS(DATA_CACHE)
cat("Full dataset:", nrow(dt_raw), "obs\n")

# Admin vs Ordinary sample: exclude litigated (type 2)
dt_ao <- dt_raw[purchase_type == 0 | purchase_type == 1]
dt_ao[, admin := as.integer(purchase_type == 1)]

# Keep items with BOTH admin and ordinary purchases
dt_ao[, has_admin := any(purchase_type == 1), by = item]
dt_ao[, has_ordinary := any(purchase_type == 0), by = item]
dt_ao <- dt_ao[has_admin == TRUE & has_ordinary == TRUE]
cat("Admin vs Ordinary sample (both types):", nrow(dt_ao), "obs\n")

# Winsorize
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt_ao, win_vars, 0.01, 0.99)
gen_log_vars(dt_ao)

dt_ao_win <- dt_ao[po_firm_winner == 1]
cat("Winners sample:", nrow(dt_ao_win), "obs\n")

log_time("Data loading", t0)

# Coefficient labels (avoid duplicates from coef_labels in utils.R)
coef_labels_v8 <- c(
  "admin"       = "Administrative Purchase",
  coef_labels
)
# Ensure bid_qty_log is present
if (!"bid_qty_log" %in% names(coef_labels_v8)) {
  coef_labels_v8 <- c(coef_labels_v8, "bid_qty_log" = "Log Quantity")
}

# =============================================================================
# REGRESSIONS: ADMINISTRATIVE vs ORDINARY
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("REGRESSIONS: Administrative vs Ordinary\n")
cat(strrep("=", 70), "\n")

# --- 1. Reference Prices (DV: bid_price_ref_log) ----------------------------
cat("\n--- 1. Reference Prices ---\n")
t0 <- proc.time()
m_ref <- run_feols4("bid_price_ref_log", "admin", dt_ao_win, cluster = ~pbu_id)
saveRDS(m_ref, file.path(CHECKPOINT, "v8_adm_ref_prices.rds"))
save_table_v8(m_ref, "Admin vs Ordinary: Reference Prices",
              "v8_adm_ref_prices_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
write_reg_table_v8(m_ref, "admin", coef_labels_v8,
                   "Administrative vs.\\ Ordinary: Reference Prices",
                   "v8_adm_ref_prices", "tab_adm_vs_ord_ref_prices_v8.tex")
log_time("Ref prices", t0)

# --- 2. Quantities (DV: bid_qty_log) ----------------------------------------
cat("\n--- 2. Quantities ---\n")
t0 <- proc.time()
m_qty <- run_feols4("bid_qty_log", "admin", dt_ao_win, cluster = ~pbu_id)
saveRDS(m_qty, file.path(CHECKPOINT, "v8_adm_quantities.rds"))
save_table_v8(m_qty, "Admin vs Ordinary: Quantities",
              "v8_adm_quantities_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
write_reg_table_v8(m_qty, "admin", coef_labels_v8,
                   "Administrative vs.\\ Ordinary: Quantities",
                   "v8_adm_quantities", "tab_adm_vs_ord_quantities_v8.tex")
log_time("Quantities", t0)

# --- 3. Negotiated Prices (DV: bid_price_log) — Total + Direct --------------
cat("\n--- 3. Negotiated Prices ---\n")
t0 <- proc.time()
m_neg_total  <- run_feols4("bid_price_log", "admin", dt_ao_win, cluster = ~pbu_id)
m_neg_direct <- run_feols4("bid_price_log", c("admin", "bid_qty_log"), dt_ao_win,
                           cluster = ~pbu_id)
saveRDS(list(total = m_neg_total, direct = m_neg_direct),
        file.path(CHECKPOINT, "v8_adm_neg_prices.rds"))
save_table_v8(m_neg_total, "Admin vs Ordinary: Negotiated Prices (Total)",
              "v8_adm_neg_prices_total_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
save_table_v8(m_neg_direct, "Admin vs Ordinary: Negotiated Prices (Direct)",
              "v8_adm_neg_prices_direct_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
write_panel_reg_table_v8(
  m_neg_total, m_neg_direct,
  "admin", c("admin", "bid_qty_log"), coef_labels_v8,
  "Panel A: Total Effect", "Panel B: Direct Effect (controlling for quantity)",
  "Administrative vs.\\ Ordinary: Negotiated Prices",
  "v8_adm_neg_prices", "tab_adm_vs_ord_neg_prices_v8.tex"
)
log_time("Neg prices", t0)

# --- 4. Bidder Participation (DV: ln_n_firms) — Total + Direct ---------------
cat("\n--- 4. Bidder Participation ---\n")
t0 <- proc.time()
m_firms_total  <- run_feols4("ln_n_firms", "admin", dt_ao_win, cluster = ~pbu_id)
m_firms_direct <- run_feols4("ln_n_firms", c("admin", "bid_qty_log"), dt_ao_win,
                             cluster = ~pbu_id)
saveRDS(list(total = m_firms_total, direct = m_firms_direct),
        file.path(CHECKPOINT, "v8_adm_firms.rds"))
save_table_v8(m_firms_total, "Admin vs Ordinary: Bidder Participation (Total)",
              "v8_adm_firms_total_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
save_table_v8(m_firms_direct, "Admin vs Ordinary: Bidder Participation (Direct)",
              "v8_adm_firms_direct_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
write_panel_reg_table_v8(
  m_firms_total, m_firms_direct,
  "admin", c("admin", "bid_qty_log"), coef_labels_v8,
  "Panel A: Total Effect", "Panel B: Direct Effect (controlling for quantity)",
  "Administrative vs.\\ Ordinary: Bidder Participation",
  "v8_adm_firms", "tab_adm_vs_ord_firms_v8.tex"
)
log_time("Firms", t0)

# --- 5. Tender Success (DV: po_firm_winner, LPM) — Total + Direct -----------
cat("\n--- 5. Tender Success ---\n")
t0 <- proc.time()
# Success uses ALL obs (not winners only)
m_suc_total  <- run_feols4("po_firm_winner", "admin", dt_ao, cluster = ~pbu_id)
m_suc_direct <- run_feols4("po_firm_winner", c("admin", "bid_qty_log"), dt_ao,
                           cluster = ~pbu_id)
saveRDS(list(total = m_suc_total, direct = m_suc_direct),
        file.path(CHECKPOINT, "v8_adm_success.rds"))
save_table_v8(m_suc_total, "Admin vs Ordinary: Tender Success (Total)",
              "v8_adm_success_total_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
save_table_v8(m_suc_direct, "Admin vs Ordinary: Tender Success (Direct)",
              "v8_adm_success_direct_cluster_pbu",
              coef_map = coef_labels_v8, add_rows = fe_rows())
write_panel_reg_table_v8(
  m_suc_total, m_suc_direct,
  "admin", c("admin", "bid_qty_log"), coef_labels_v8,
  "Panel A: Total Effect", "Panel B: Direct Effect (controlling for quantity)",
  "Administrative vs.\\ Ordinary: Tender Success (LPM)",
  "v8_adm_success", "tab_adm_vs_ord_success_v8.tex"
)
log_time("Success", t0)

# =============================================================================
# COEFFICIENT PLOT
# =============================================================================
cat("\n", strrep("=", 70), "\n")
cat("COEFFICIENT PLOT\n")
cat(strrep("=", 70), "\n")

# Use preferred spec (Item+Year+PBU, col 3) for all outcomes
spec_idx <- 3  # Item+Year+PBU

coef_data <- data.frame(
  outcome = c("Reference\nPrice", "Quantity", "Neg. Price\n(Total)",
              "Neg. Price\n(Direct)", "Firms\n(Total)", "Firms\n(Direct)",
              "Success\n(Total)", "Success\n(Direct)"),
  estimate = c(
    coef(m_ref[[spec_idx]])["admin"],
    coef(m_qty[[spec_idx]])["admin"],
    coef(m_neg_total[[spec_idx]])["admin"],
    coef(m_neg_direct[[spec_idx]])["admin"],
    coef(m_firms_total[[spec_idx]])["admin"],
    coef(m_firms_direct[[spec_idx]])["admin"],
    coef(m_suc_total[[spec_idx]])["admin"],
    coef(m_suc_direct[[spec_idx]])["admin"]
  ),
  se = c(
    se(m_ref[[spec_idx]])["admin"],
    se(m_qty[[spec_idx]])["admin"],
    se(m_neg_total[[spec_idx]])["admin"],
    se(m_neg_direct[[spec_idx]])["admin"],
    se(m_firms_total[[spec_idx]])["admin"],
    se(m_firms_direct[[spec_idx]])["admin"],
    se(m_suc_total[[spec_idx]])["admin"],
    se(m_suc_direct[[spec_idx]])["admin"]
  ),
  stringsAsFactors = FALSE
)

coef_data$ci90_lo <- coef_data$estimate - 1.645 * coef_data$se
coef_data$ci90_hi <- coef_data$estimate + 1.645 * coef_data$se
coef_data$ci95_lo <- coef_data$estimate - 1.96  * coef_data$se
coef_data$ci95_hi <- coef_data$estimate + 1.96  * coef_data$se

coef_data$outcome <- factor(coef_data$outcome,
  levels = rev(c("Reference\nPrice", "Quantity", "Neg. Price\n(Total)",
                 "Neg. Price\n(Direct)", "Firms\n(Total)", "Firms\n(Direct)",
                 "Success\n(Total)", "Success\n(Direct)"))
)

p_coef <- ggplot(coef_data, aes(x = estimate, y = outcome)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_linerange(aes(xmin = ci95_lo, xmax = ci95_hi),
                 linewidth = 0.6, color = "gray40") +
  geom_linerange(aes(xmin = ci90_lo, xmax = ci90_hi),
                 linewidth = 1.2, color = "gray20") +
  geom_point(size = 2.5, shape = 16, color = "black") +
  labs(
    x = "Coefficient estimate",
    y = NULL,
    caption = paste0("Notes: Preferred specification (Item + Year + PBU FE). ",
                     "Thick bars = 90% CI; thin bars = 95% CI. ",
                     "SE clustered at PBU level.")
  ) +
  theme_bw(base_size = 11) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.text.y        = element_text(size = 9),
    plot.caption       = element_text(size = 7, hjust = 0, color = "gray30"),
    plot.margin        = margin(5, 10, 5, 5)
  )

out_coef <- file.path(PUB_FIG_V8, "fig_coef_adm_vs_ord_v8.pdf")
ggsave(out_coef, p_coef, width = 6.5, height = 4, device = cairo_pdf)
cat(sprintf("  Coefficient plot saved: %s\n", out_coef))

# Also save as PNG for MkDocs
out_png <- file.path(PUB_FIG_V8, "fig_coef_adm_vs_ord_v8.png")
ggsave(out_png, p_coef, width = 6.5, height = 4, dpi = 300)
cat(sprintf("  PNG saved: %s\n", out_png))

# =============================================================================
# SUMMARY
# =============================================================================
elapsed_total <- (proc.time() - t_start)[["elapsed"]]

cat("\n", strrep("=", 70), "\n")
cat("19_v8_adm_vs_ord.R COMPLETE\n")
cat(strrep("=", 70), "\n")
cat(sprintf("  Total time: %.1f sec\n", elapsed_total))
cat(sprintf("  Regressions: 40 models (8 outcomes × 4 FE specs + 2 LPM variants)\n"))
cat(sprintf("  Pub tables: 5 (.tex in %s)\n", PUB_TAB_V8))
cat(sprintf("  Manuscript tables: %d (.tex in %s)\n",
            length(list.files(MANU_V8, pattern = "\\.tex$")), MANU_V8))
cat(sprintf("  HTML results: %d (.html in %s)\n",
            length(list.files(RESU_V8, pattern = "\\.html$")), RESU_V8))
cat(sprintf("  Checkpoints: %d (.rds in %s)\n",
            length(list.files(CHECKPOINT, pattern = "\\.rds$")), CHECKPOINT))
cat(sprintf("  Coefficient plot: %s\n", out_coef))

# --- Print key results for manuscript ---
cat("\n=== KEY RESULTS (Preferred Spec: Item+Year+PBU) ===\n")
outcomes <- list(
  "Ref Price"       = m_ref[[3]],
  "Quantity"        = m_qty[[3]],
  "Neg Price Total" = m_neg_total[[3]],
  "Neg Price Direct"= m_neg_direct[[3]],
  "Firms Total"     = m_firms_total[[3]],
  "Firms Direct"    = m_firms_direct[[3]],
  "Success Total"   = m_suc_total[[3]],
  "Success Direct"  = m_suc_direct[[3]]
)

for (nm in names(outcomes)) {
  m <- outcomes[[nm]]
  b <- coef(m)["admin"]
  s <- se(m)["admin"]
  p <- pvalue(m)["admin"]
  pct <- (exp(b) - 1) * 100
  cat(sprintf("  %-20s: coef = %7.4f (SE = %.4f) %s  → %+.1f%%\n",
              nm, b, s, pstars(p), pct))
}

# Save summary
summary_file <- file.path(V4, "v8_summary.md")
writeLines(c(
  "# V8 Summary: Administrative vs Ordinary",
  paste0("Generated: ", Sys.time()),
  paste0("Total runtime: ", round(elapsed_total, 1), " sec"),
  "",
  "## Key Results (Preferred Spec: Item+Year+PBU)",
  paste0("| Outcome | Coefficient | SE | Stars | % Effect |"),
  paste0("|---------|-------------|-----|-------|----------|"),
  sapply(names(outcomes), function(nm) {
    m <- outcomes[[nm]]; b <- coef(m)["admin"]; s <- se(m)["admin"]
    p <- pvalue(m)["admin"]; pct <- (exp(b) - 1) * 100
    sprintf("| %s | %.4f | %.4f | %s | %+.1f%% |", nm, b, s, pstars(p), pct)
  }),
  "",
  "## Files Generated",
  paste0("- Pub tables: ", length(list.files(PUB_TAB_V8, pattern = "\\.tex$"))),
  paste0("- Manuscript tables: ", length(list.files(MANU_V8, pattern = "\\.tex$"))),
  paste0("- HTML results: ", length(list.files(RESU_V8, pattern = "\\.html$"))),
  paste0("- Checkpoints: ", length(list.files(CHECKPOINT, pattern = "\\.rds$"))),
  "- Coefficient plot: 1 (PDF + PNG)"
), summary_file)
cat(sprintf("\n  Summary: %s\n", summary_file))
