# V7 Extensions: UTG Missing Outcomes + Litigated-Only
#

cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
t_start <- proc.time()

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

# FORMATTING HELPERS (pub-ready tables: threeparttable + booktabs)

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
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)

# Extended coefficient labels for v7
coef_labels_v7 <- c(
  coef_labels,
  "litigated"  = "Litigated Purchase",
  "litigated:late_period"      = "Litigated $\\times$ Late Period",
  "litigated:sus_basic"        = "Litigated $\\times$ Basic SUS",
  "litigated:high_competition" = "Litigated $\\times$ High Competition",
  "litigated:large_pbu"        = "Litigated $\\times$ Large PBU"
)

# write single-panel pub table
write_reg_table_pub <- function(models, coef_vars, coef_labs, title, label,
                                filename, note = NULL, fe_labels = NULL,
                                digits = 3, show_wr2 = TRUE) {
  n <- length(models)
  if (is.null(fe_labels)) fe_labels <- fe_labels_4spec
  if (is.null(note)) note <- default_note

  lines <- c(
    "\\begin{table}[ht]", "  \\centering",
    paste0("  \\caption{", title, "}"), paste0("  \\label{tab:", label, "}"),
    "  \\small", "  \\begin{threeparttable}",
    paste0("  \\begin{tabular}{l", paste(rep("c", n), collapse = ""), "}"),
    "    \\hline\\hline",
    paste0("    & ", paste(paste0("(", seq_len(n), ")"), collapse = " & "), " \\\\"),
    "    \\hline")

  for (v in coef_vars) {
    cells <- se_cells <- character(n)
    for (j in seq_len(n)) {
      b <- coef(models[[j]])[v]; s <- se(models[[j]])[v]; p <- pvalue(models[[j]])[v]
      if (is.na(b)) { cells[j] <- ""; se_cells[j] <- "" }
      else { cells[j] <- paste0(pfmt(b, digits), pstars(p)); se_cells[j] <- paste0("(", pfmt(s, digits), ")") }
    }
    lines <- c(lines,
      paste0("    ", coef_labs[v], " & ", paste(cells, collapse = " & "), " \\\\"),
      paste0("     & ", paste(se_cells, collapse = " & "), " \\\\[3pt]"))
  }

  lines <- c(lines, "    \\hline")
  for (fe_name in names(fe_labels)) {
    vals <- fe_labels[[fe_name]]
    lines <- c(lines, paste0("    ", fe_name, " & ", paste(vals[seq_len(n)], collapse = " & "), " \\\\"))
  }
  obs <- sapply(models, function(m) pfmt_int(m$nobs))
  lines <- c(lines, paste0("    Observations & ", paste(obs, collapse = " & "), " \\\\"))
  if (show_wr2) {
    wr2 <- sapply(models, function(m) { w <- get_wr2(m); if (is.na(w)) "" else pfmt(w, 3) })
    lines <- c(lines, paste0("    Within R$^2$ & ", paste(wr2, collapse = " & "), " \\\\"))
  }
  lines <- c(lines, "    \\hline\\hline", "  \\end{tabular}",
    "  \\begin{tablenotes}", "    \\small",
    paste0("    \\item \\textit{Notes:} ", note),
    "  \\end{tablenotes}", "  \\end{threeparttable}", "\\end{table}")

  filepath <- file.path(PUB_TAB, filename)
  writeLines(lines, filepath)
  cat("    Pub table:", basename(filepath), "\n")
}

# write two-panel pub table
write_panel_reg_table_pub <- function(models_a, models_b,
                                      coef_vars_a, coef_vars_b, coef_labs,
                                      panel_a_title, panel_b_title,
                                      title, label, filename,
                                      note = NULL, fe_labels = NULL, digits = 3) {
  n <- length(models_a)
  if (is.null(fe_labels)) fe_labels <- fe_labels_4spec
  if (is.null(note)) note <- default_note

  write_block <- function(models, cvars) {
    block <- character()
    for (v in cvars) {
      cells <- se_cells <- character(n)
      for (j in seq_len(n)) {
        b <- coef(models[[j]])[v]; s <- se(models[[j]])[v]; p <- pvalue(models[[j]])[v]
        if (is.na(b)) { cells[j] <- ""; se_cells[j] <- "" }
        else { cells[j] <- paste0(pfmt(b, digits), pstars(p)); se_cells[j] <- paste0("(", pfmt(s, digits), ")") }
      }
      block <- c(block,
        paste0("    ", coef_labs[v], " & ", paste(cells, collapse = " & "), " \\\\"),
        paste0("     & ", paste(se_cells, collapse = " & "), " \\\\[3pt]"))
    }
    block
  }

  ncol <- n + 1
  lines <- c("\\begin{table}[ht]", "  \\centering",
    paste0("  \\caption{", title, "}"), paste0("  \\label{tab:", label, "}"),
    "  \\small", "  \\begin{threeparttable}",
    paste0("  \\begin{tabular}{l", paste(rep("c", n), collapse = ""), "}"),
    "    \\hline\\hline",
    paste0("    & ", paste(paste0("(", seq_len(n), ")"), collapse = " & "), " \\\\"),
    "    \\hline",
    paste0("    \\multicolumn{", ncol, "}{l}{\\textit{", panel_a_title, "}} \\\\[3pt]"))
  lines <- c(lines, write_block(models_a, coef_vars_a))
  lines <- c(lines, "    \\hline",
    paste0("    \\multicolumn{", ncol, "}{l}{\\textit{", panel_b_title, "}} \\\\[3pt]"))
  lines <- c(lines, write_block(models_b, coef_vars_b))
  lines <- c(lines, "    \\hline")
  for (fe_name in names(fe_labels)) {
    vals <- fe_labels[[fe_name]]
    lines <- c(lines, paste0("    ", fe_name, " & ", paste(vals[seq_len(n)], collapse = " & "), " \\\\"))
  }
  obs_a <- sapply(models_a, function(m) pfmt_int(m$nobs))
  obs_b <- sapply(models_b, function(m) pfmt_int(m$nobs))
  if (identical(obs_a, obs_b)) {
    lines <- c(lines, paste0("    Observations & ", paste(obs_a, collapse = " & "), " \\\\"))
  } else {
    lines <- c(lines, paste0("    Obs.\\ (Panel~A) & ", paste(obs_a, collapse = " & "), " \\\\"),
                       paste0("    Obs.\\ (Panel~B) & ", paste(obs_b, collapse = " & "), " \\\\"))
  }
  wr2_a <- sapply(models_a, function(m) { w <- get_wr2(m); if (is.na(w)) "" else pfmt(w, 3) })
  wr2_b <- sapply(models_b, function(m) { w <- get_wr2(m); if (is.na(w)) "" else pfmt(w, 3) })
  lines <- c(lines,
    paste0("    Within R$^2$ (A) & ", paste(wr2_a, collapse = " & "), " \\\\"),
    paste0("    Within R$^2$ (B) & ", paste(wr2_b, collapse = " & "), " \\\\"))
  lines <- c(lines, "    \\hline\\hline", "  \\end{tabular}",
    "  \\begin{tablenotes}", "    \\small",
    paste0("    \\item \\textit{Notes:} ", note),
    "  \\end{tablenotes}", "  \\end{threeparttable}", "\\end{table}")

  filepath <- file.path(PUB_TAB, filename)
  writeLines(lines, filepath)
  cat("    Pub table:", basename(filepath), "\n")
}

# LOAD DATA & PREPARE SAMPLES

cat("\nLoading data\n")
dt_raw <- readRDS(DATA_CACHE)
dt_raw <- dt_raw[has_litigated == TRUE & has_ordinary == TRUE]

dt <- copy(dt_raw)
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

dt_win <- dt[po_firm_winner == 1]

# UTG subsample
dt_utg <- dt[purchase_type == 1 | purchase_type == 2]
dt_utg[, has_admin2 := any(purchase_type == 1), by = item]
dt_utg[, has_lit2   := any(purchase_type == 2), by = item]
dt_utg <- dt_utg[has_admin2 == TRUE & has_lit2 == TRUE]
dt_utg_win <- dt_utg[po_firm_winner == 1]

# Litigated-only subsample
dt_lit <- dt[purchase_type == 0 | purchase_type == 2]
dt_lit[, litigated := as.integer(purchase_type == 2)]
dt_lit_win <- dt_lit[po_firm_winner == 1]

cat("Analysis sample:", nrow(dt), "| Winners:", nrow(dt_win), "\n")
cat("UTG:", nrow(dt_utg), "| UTG winners:", nrow(dt_utg_win), "\n")
cat("Litigated-only:", nrow(dt_lit), "| Lit winners:", nrow(dt_lit_win), "\n")

cat("\nTASK 1: UTG Missing Outcomes\n")

# T1.1: UTG Reference Prices
t1_ref <- run_feols4("bid_price_ref_log", "is_admin", dt_utg_win, cluster = ~pbu_id)
write_reg_table_pub(t1_ref, "is_admin", coef_labels_v7,
  "Under the Gun: Reference Prices", "t1_utg_ref_prices",
  "t1_tab_utg_ref_prices.tex",
  note = paste0("Dependent variable: log reference price. UTG sample (urgent, winners). ", default_note))

# T1.2: UTG Quantities
t1_qty <- run_feols4("bid_qty_log", "is_admin", dt_utg_win, cluster = ~pbu_id)
write_reg_table_pub(t1_qty, "is_admin", coef_labels_v7,
  "Under the Gun: Quantities", "t1_utg_quantities",
  "t1_tab_utg_quantities.tex",
  note = paste0("Dependent variable: log quantity. UTG sample (urgent, winners). ", default_note))

# T1.3: UTG Firms (total + direct)
t1_firms_t <- run_feols4("ln_n_firms", "is_admin", dt_utg_win, cluster = ~pbu_id)
t1_firms_d <- run_feols4("ln_n_firms", c("is_admin", "bid_qty_log"), dt_utg_win, cluster = ~pbu_id)
write_panel_reg_table_pub(t1_firms_t, t1_firms_d, "is_admin", c("is_admin", "bid_qty_log"),
  coef_labels_v7, "Panel~A: Total Effect", "Panel~B: Direct Effect",
  "Under the Gun: Participant Firms", "t1_utg_firms", "t1_tab_utg_firms.tex",
  note = paste0("Dependent variable: log N. firms. UTG sample (urgent, winners). ", default_note))

# T1.4: UTG Success (all obs)
t1_succ_t <- run_feols4("po_firm_winner", "is_admin", dt_utg, cluster = ~pbu_id)
t1_succ_d <- run_feols4("po_firm_winner", c("is_admin", "bid_qty_log"), dt_utg, cluster = ~pbu_id)
write_panel_reg_table_pub(t1_succ_t, t1_succ_d, "is_admin", c("is_admin", "bid_qty_log"),
  coef_labels_v7, "Panel~A: Total Effect", "Panel~B: Direct Effect",
  "Under the Gun: Tender Success (LPM)", "t1_utg_success", "t1_tab_utg_success.tex",
  note = paste0("Dependent variable: successful tender (LPM). UTG sample (urgent, all obs). ", default_note))

cat("\nTASK 2: Litigated vs Ordinary\n")

# T2.1: Ref Prices
t2_ref <- run_feols4("bid_price_ref_log", "litigated", dt_lit_win, cluster = ~pbu_id)
write_reg_table_pub(t2_ref, "litigated", coef_labels_v7,
  "Litigated vs Ordinary: Reference Prices", "t2_lit_ref_prices",
  "t2_tab_ref_prices.tex",
  note = paste0("Dependent variable: log reference price. Litigated+Ordinary only, winners. ", default_note))

# T2.2: Quantities
t2_qty <- run_feols4("bid_qty_log", "litigated", dt_lit_win, cluster = ~pbu_id)
write_reg_table_pub(t2_qty, "litigated", coef_labels_v7,
  "Litigated vs Ordinary: Quantities", "t2_lit_quantities",
  "t2_tab_quantities.tex",
  note = paste0("Dependent variable: log quantity. Litigated+Ordinary only, winners. ", default_note))

# T2.3-4: Neg Prices (total + direct)
t2_neg_t <- run_feols4("bid_price_log", "litigated", dt_lit_win, cluster = ~pbu_id)
t2_neg_d <- run_feols4("bid_price_log", c("litigated", "bid_qty_log"), dt_lit_win, cluster = ~pbu_id)
write_panel_reg_table_pub(t2_neg_t, t2_neg_d, "litigated", c("litigated", "bid_qty_log"),
  coef_labels_v7, "Panel~A: Total Effect", "Panel~B: Direct Effect",
  "Litigated vs Ordinary: Negotiated Prices", "t2_lit_neg_prices", "t2_tab_neg_prices.tex",
  note = paste0("Dependent variable: log negotiated price. Litigated+Ordinary only, winners. ", default_note))

# T2.5-6: Firms (total + direct)
t2_firms_t <- run_feols4("ln_n_firms", "litigated", dt_lit_win, cluster = ~pbu_id)
t2_firms_d <- run_feols4("ln_n_firms", c("litigated", "bid_qty_log"), dt_lit_win, cluster = ~pbu_id)
write_panel_reg_table_pub(t2_firms_t, t2_firms_d, "litigated", c("litigated", "bid_qty_log"),
  coef_labels_v7, "Panel~A: Total Effect", "Panel~B: Direct Effect",
  "Litigated vs Ordinary: Participant Firms", "t2_lit_firms", "t2_tab_firms.tex",
  note = paste0("Dependent variable: log N. firms. Litigated+Ordinary only, winners. ", default_note))

# T2.7-8: Success (all obs)
t2_succ_t <- run_feols4("po_firm_winner", "litigated", dt_lit, cluster = ~pbu_id)
t2_succ_d <- run_feols4("po_firm_winner", c("litigated", "bid_qty_log"), dt_lit, cluster = ~pbu_id)
write_panel_reg_table_pub(t2_succ_t, t2_succ_d, "litigated", c("litigated", "bid_qty_log"),
  coef_labels_v7, "Panel~A: Total Effect", "Panel~B: Direct Effect",
  "Litigated vs Ordinary: Tender Success (LPM)", "t2_lit_success", "t2_tab_success.tex",
  note = paste0("Dependent variable: successful tender (LPM). Litigated+Ordinary only, all obs. ", default_note))

# COEFFICIENT PLOT FIGURES
cat("\nGenerating coefficient plots\n")

extract_coef <- function(models, var, label) {
  m <- models[["Item+Year+PBU"]]
  b  <- coef(m)[var]; se_val <- se(m)[var]
  data.frame(label = label, coef = b, se = se_val,
    ci90_lo = b - 1.645 * se_val, ci90_hi = b + 1.645 * se_val,
    ci95_lo = b - 1.96  * se_val, ci95_hi = b + 1.96  * se_val,
    stringsAsFactors = FALSE)
}

theme_pub <- function(base_size = 9) {
  theme_bw(base_size = base_size) + theme(
    panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    legend.position = "none", plot.title = element_text(face = "bold", size = base_size + 1),
    plot.subtitle = element_text(size = base_size - 1, color = "gray40"),
    axis.title.y = element_blank())
}

# Recompute original UTG neg price for T1 plot
t10a_orig <- run_feols4("bid_price_log", "is_admin", dt_utg_win, cluster = ~pbu_id)

# Task 1 plot
df_t1 <- rbind(
  extract_coef(t1_ref,      "is_admin", "Reference Price"),
  extract_coef(t1_qty,      "is_admin", "Quantity"),
  extract_coef(t10a_orig,   "is_admin", "Negotiated Price"),
  extract_coef(t1_firms_t,  "is_admin", "N. Firms"),
  extract_coef(t1_succ_t,   "is_admin", "Tender Success"))
df_t1$label <- factor(df_t1$label, levels = rev(df_t1$label))

p1 <- ggplot(df_t1, aes(x = coef, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_linerange(aes(xmin = ci95_lo, xmax = ci95_hi), linewidth = 0.6, color = "gray60") +
  geom_linerange(aes(xmin = ci90_lo, xmax = ci90_hi), linewidth = 1.2, color = "gray30") +
  geom_point(size = 2.5, color = "black") +
  labs(title = "Under the Gun: Administrative vs. Litigated",
       subtitle = "Item + Year + PBU FE. Inner: 90% CI; Outer: 95% CI.",
       x = "Coefficient") + theme_pub()

cairo_pdf(file.path(PUB_FIG, "fig_09_utg_coefplot_v7.pdf"), width = 6.5, height = 4)
print(p1); dev.off()
cat("  Saved: fig_09_utg_coefplot_v7.pdf\n")

# Task 2 plot
df_t2 <- rbind(
  extract_coef(t2_ref,     "litigated", "Reference Price"),
  extract_coef(t2_qty,     "litigated", "Quantity"),
  extract_coef(t2_neg_t,   "litigated", "Neg. Price (total)"),
  extract_coef(t2_neg_d,   "litigated", "Neg. Price (direct)"),
  extract_coef(t2_firms_t, "litigated", "N. Firms (total)"),
  extract_coef(t2_firms_d, "litigated", "N. Firms (direct)"),
  extract_coef(t2_succ_t,  "litigated", "Tender Success (total)"),
  extract_coef(t2_succ_d,  "litigated", "Tender Success (direct)"))
df_t2$label <- factor(df_t2$label, levels = rev(df_t2$label))

p2 <- ggplot(df_t2, aes(x = coef, y = label)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.4) +
  geom_linerange(aes(xmin = ci95_lo, xmax = ci95_hi), linewidth = 0.6, color = "gray60") +
  geom_linerange(aes(xmin = ci90_lo, xmax = ci90_hi), linewidth = 1.2, color = "gray30") +
  geom_point(size = 2.5, color = "black") +
  labs(title = "Litigated vs. Ordinary Purchases",
       subtitle = "Item + Year + PBU FE. Inner: 90% CI; Outer: 95% CI.",
       x = "Coefficient") + theme_pub()

cairo_pdf(file.path(PUB_FIG, "fig_10_litigated_coefplot_v7.pdf"), width = 6.5, height = 4)
print(p2); dev.off()
cat("  Saved: fig_10_litigated_coefplot_v7.pdf\n")

# SUMMARY
t_total <- (proc.time() - t_start)[["elapsed"]]
cat(sprintf("\n16_v7_extensions.R complete in %.0f seconds\n", t_total))
