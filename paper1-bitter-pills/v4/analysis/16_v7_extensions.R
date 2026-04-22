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

cat("Hardware Detection\n")
n_cores <- parallel::detectCores(logical = TRUE)
ram_gb  <- as.numeric(system("free -b | awk '/Mem:/{print $2}'", intern = TRUE)) / 1e9
cat(sprintf("  CPU cores (logical): %d\n", n_cores))
cat(sprintf("  RAM total: %.1f GB\n", ram_gb))

# Configure all parallelism to max
setFixest_nthreads(n_cores)
setDTthreads(n_cores)
cat(sprintf("  fixest threads: %d\n", n_cores))
cat(sprintf("  data.table threads: %d\n", n_cores))

# Output directories
PUB_TAB_V7 <- file.path(V4, "pub", "tables_v7")
MANU_V7    <- file.path(V4, "manuscript_v7")
RESU_V7    <- file.path(V4, "results_v7")
CHECKPOINT <- file.path(V4, "checkpoints_v7")
for (d in c(PUB_TAB_V7, MANU_V7, RESU_V7, CHECKPOINT)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Timing log
timing_log <- list()
log_time <- function(label, t0) {
  elapsed <- (proc.time() - t0)[["elapsed"]]
  timing_log[[label]] <<- elapsed
  cat(sprintf("  [%s] %.1f sec\n", label, elapsed))
}

# FORMATTING HELPERS (from 08_pub_tables.R)
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

# V7 save_table: saves to v7 directories
save_table_v7 <- function(models, title, filename,
                          coef_map = NULL, gof_map = NULL,
                          add_rows = NULL, notes = NULL) {
  if (is.null(gof_map)) {
    gof_map <- c("nobs" = "Observations", "r.squared" = "R^2",
                 "adj.r.squared" = "Adj. R^2",
                 "within.r.squared" = "Within R^2")
  }
  tex_file <- file.path(MANU_V7, paste0(filename, ".tex"))
  modelsummary(models, output = tex_file,
               title = title, coef_map = coef_map, gof_map = gof_map,
               add_rows = add_rows, notes = notes,
               stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
               escape = FALSE)
  html_file <- file.path(RESU_V7, paste0(filename, ".html"))
  modelsummary(models, output = html_file,
               title = title, coef_map = coef_map, gof_map = gof_map,
               add_rows = add_rows, notes = notes,
               stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01))
  cat("    Saved:", basename(tex_file), "+", basename(html_file), "\n")
}

# write_reg_table_v7: publication-ready single-panel table
write_reg_table_v7 <- function(models, coef_vars, coef_labs, title, label,
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

  filepath <- file.path(PUB_TAB_V7, filename)
  writeLines(lines, filepath)
  cat("    Pub table:", basename(filepath), "\n")
}

# write_panel_reg_table_v7: two-panel pub table
write_panel_reg_table_v7 <- function(models_a, models_b,
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

  filepath <- file.path(PUB_TAB_V7, filename)
  writeLines(lines, filepath)
  cat("    Pub table:", basename(filepath), "\n")
}

# LOAD DATA & PREPARE SAMPLES

cat("\nLoading data\n")
t0 <- proc.time()
dt_raw <- readRDS(DATA_CACHE)
dt_raw <- dt_raw[has_litigated == TRUE & has_ordinary == TRUE]
cat("Analysis sample (raw):", nrow(dt_raw), "obs\n")

# Baseline: 1%/99% winsorization
dt <- copy(dt_raw)
win_vars <- c("bid_price", "bid_price_ref", "bid_qty", "n_firms_bids")
winsorize_dt(dt, win_vars, 0.01, 0.99)
gen_log_vars(dt)

dt_win <- dt[po_firm_winner == 1]
cat("Winners sample:", nrow(dt_win), "obs\n")

# UTG subsample: urgent only, items with both admin and litigated
dt_utg <- dt[purchase_type == 1 | purchase_type == 2]
dt_utg[, has_admin2 := any(purchase_type == 1), by = item]
dt_utg[, has_lit2   := any(purchase_type == 2), by = item]
dt_utg <- dt_utg[has_admin2 == TRUE & has_lit2 == TRUE]
dt_utg_win <- dt_utg[po_firm_winner == 1]
cat("UTG sample:", nrow(dt_utg), "obs\n")
cat("UTG winners:", nrow(dt_utg_win), "obs\n")

# Litigated-only subsample: exclude administrative, keep litigated + ordinary
dt_lit <- dt[purchase_type == 0 | purchase_type == 2]
dt_lit[, litigated := as.integer(purchase_type == 2)]
dt_lit_win <- dt_lit[po_firm_winner == 1]
cat("Litigated-only sample:", nrow(dt_lit), "obs\n")
cat("Litigated-only winners:", nrow(dt_lit_win), "obs\n")

log_time("Data loading", t0)

# Extended coefficient labels for v7
coef_labels_v7 <- c(
  coef_labels,
  "litigated"  = "Litigated Purchase",
  "litigated:late_period"      = "Litigated $\\times$ Late Period",
  "litigated:sus_basic"        = "Litigated $\\times$ Basic SUS",
  "litigated:high_competition" = "Litigated $\\times$ High Competition",
  "litigated:large_pbu"        = "Litigated $\\times$ Large PBU"
)


cat("TASK 1: Under the Gun — Missing Outcomes\n")

# T1.1: UTG Reference Prices (DV: bid_price_ref_log)
cat("\n--- T1.1: UTG Reference Prices ---\n")
t0 <- proc.time()

t1_ref_total <- run_feols4("bid_price_ref_log", "is_admin", dt_utg_win, cluster = ~pbu_id)
save_table_v7(t1_ref_total, "UTG: Reference Prices",
              "t1_utg_ref_prices_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

utg_ref_note <- paste0(
  "Dependent variable: log reference price. Sample: urgent purchases only ",
  "(administrative and litigated), winners, items with both types present. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_reg_table_v7(t1_ref_total, "is_admin", coef_labels_v7,
                   "Under the Gun: Reference Prices", "t1_utg_ref_prices",
                   "t1_tab_utg_ref_prices.tex", note = utg_ref_note)

log_time("T1.1 UTG Ref Prices", t0)
saveRDS(t1_ref_total, file.path(CHECKPOINT, "t1_ref_total.rds"))

# T1.2: UTG Quantities (DV: bid_qty_log)
cat("\n--- T1.2: UTG Quantities ---\n")
t0 <- proc.time()

t1_qty_total <- run_feols4("bid_qty_log", "is_admin", dt_utg_win, cluster = ~pbu_id)
save_table_v7(t1_qty_total, "UTG: Quantities",
              "t1_utg_quantities_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

utg_qty_note <- paste0(
  "Dependent variable: log quantity. Sample: urgent purchases only ",
  "(administrative and litigated), winners, items with both types present. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_reg_table_v7(t1_qty_total, "is_admin", coef_labels_v7,
                   "Under the Gun: Quantities", "t1_utg_quantities",
                   "t1_tab_utg_quantities.tex", note = utg_qty_note)

log_time("T1.2 UTG Quantities", t0)
saveRDS(t1_qty_total, file.path(CHECKPOINT, "t1_qty_total.rds"))

# T1.3: UTG Firms — Total & Direct (DV: ln_n_firms)
cat("\n--- T1.3: UTG Participant Firms ---\n")
t0 <- proc.time()

t1_firms_total  <- run_feols4("ln_n_firms", "is_admin", dt_utg_win, cluster = ~pbu_id)
t1_firms_direct <- run_feols4("ln_n_firms", c("is_admin", "bid_qty_log"), dt_utg_win, cluster = ~pbu_id)

save_table_v7(t1_firms_total, "UTG: Participant Firms — Total Effect",
              "t1_utg_firms_total_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())
save_table_v7(t1_firms_direct, "UTG: Participant Firms — Direct Effect",
              "t1_utg_firms_direct_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

utg_firms_note <- paste0(
  "Dependent variable: log number of bidding firms. Sample: urgent purchases only ",
  "(administrative and litigated), winners, items with both types present. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_panel_reg_table_v7(t1_firms_total, t1_firms_direct,
                         "is_admin", c("is_admin", "bid_qty_log"),
                         coef_labels_v7,
                         "Panel~A: Total Effect", "Panel~B: Direct Effect",
                         "Under the Gun: Participant Firms",
                         "t1_utg_firms", "t1_tab_utg_firms.tex",
                         note = utg_firms_note)

log_time("T1.3 UTG Firms", t0)
saveRDS(list(total = t1_firms_total, direct = t1_firms_direct),
        file.path(CHECKPOINT, "t1_firms.rds"))

# T1.4: UTG Success/Failure LPM — Total & Direct (DV: po_firm_winner)
cat("\n--- T1.4: UTG Success LPM ---\n")
t0 <- proc.time()

# Success uses ALL observations (not just winners)
t1_success_total  <- run_feols4("po_firm_winner", "is_admin", dt_utg, cluster = ~pbu_id)
t1_success_direct <- run_feols4("po_firm_winner", c("is_admin", "bid_qty_log"), dt_utg, cluster = ~pbu_id)

save_table_v7(t1_success_total, "UTG: Success (LPM) — Total Effect",
              "t1_utg_success_total_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())
save_table_v7(t1_success_direct, "UTG: Success (LPM) — Direct Effect",
              "t1_utg_success_direct_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

utg_success_note <- paste0(
  "Dependent variable: successful tender (LPM). Sample: urgent purchases only ",
  "(administrative and litigated), all observations, items with both types present. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_panel_reg_table_v7(t1_success_total, t1_success_direct,
                         "is_admin", c("is_admin", "bid_qty_log"),
                         coef_labels_v7,
                         "Panel~A: Total Effect", "Panel~B: Direct Effect",
                         "Under the Gun: Tender Success (LPM)",
                         "t1_utg_success", "t1_tab_utg_success.tex",
                         note = utg_success_note)

log_time("T1.4 UTG Success", t0)
saveRDS(list(total = t1_success_total, direct = t1_success_direct),
        file.path(CHECKPOINT, "t1_success.rds"))

cat("\n--- TASK 1 COMPLETE ---\n")


cat("TASK 2: Urgent Purchases — Litigated Only (vs Ordinary)\n")

# T2.1: Reference Prices (DV: bid_price_ref_log)
cat("\n--- T2.1: Litigated — Reference Prices ---\n")
t0 <- proc.time()

t2_ref <- run_feols4("bid_price_ref_log", "litigated", dt_lit_win, cluster = ~pbu_id)
save_table_v7(t2_ref, "Litigated vs Ordinary: Reference Prices",
              "t2_lit_ref_prices_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

lit_ref_note <- paste0(
  "Dependent variable: log reference price. Sample: litigated and ordinary purchases only ",
  "(excluding administrative), winners, items with both litigated and ordinary present. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_reg_table_v7(t2_ref, "litigated", coef_labels_v7,
                   "Litigated vs Ordinary: Reference Prices",
                   "t2_lit_ref_prices", "t2_tab_ref_prices.tex",
                   note = lit_ref_note)

log_time("T2.1 Lit Ref Prices", t0)
saveRDS(t2_ref, file.path(CHECKPOINT, "t2_ref.rds"))

# T2.2: Quantities (DV: bid_qty_log)
cat("\n--- T2.2: Litigated — Quantities ---\n")
t0 <- proc.time()

t2_qty <- run_feols4("bid_qty_log", "litigated", dt_lit_win, cluster = ~pbu_id)
save_table_v7(t2_qty, "Litigated vs Ordinary: Quantities",
              "t2_lit_quantities_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

lit_qty_note <- paste0(
  "Dependent variable: log quantity. Sample: litigated and ordinary purchases only ",
  "(excluding administrative), winners. Winsorized at 1\\%/99\\%. ",
  default_note
)
write_reg_table_v7(t2_qty, "litigated", coef_labels_v7,
                   "Litigated vs Ordinary: Quantities",
                   "t2_lit_quantities", "t2_tab_quantities.tex",
                   note = lit_qty_note)

log_time("T2.2 Lit Quantities", t0)
saveRDS(t2_qty, file.path(CHECKPOINT, "t2_qty.rds"))

# T2.3: Negotiated Prices — Total (DV: bid_price_log)
cat("\n--- T2.3: Litigated — Negotiated Prices (Total) ---\n")
t0 <- proc.time()

t2_neg_total <- run_feols4("bid_price_log", "litigated", dt_lit_win, cluster = ~pbu_id)
save_table_v7(t2_neg_total, "Litigated vs Ordinary: Negotiated Prices — Total",
              "t2_lit_neg_prices_total_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

log_time("T2.3 Lit Neg Prices Total", t0)

# T2.4: Negotiated Prices, Direct effect (DV: bid_price_log, ctrl: bid_qty_log)
cat("\nT2.4: Litigated, negotiated prices (direct)\n")
t0 <- proc.time()

t2_neg_direct <- run_feols4("bid_price_log", c("litigated", "bid_qty_log"),
                             dt_lit_win, cluster = ~pbu_id)
save_table_v7(t2_neg_direct, "Litigated vs Ordinary: Negotiated Prices — Direct",
              "t2_lit_neg_prices_direct_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

lit_neg_note <- paste0(
  "Dependent variable: log negotiated price. Sample: litigated and ordinary purchases only ",
  "(excluding administrative), winners. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_panel_reg_table_v7(t2_neg_total, t2_neg_direct,
                         "litigated", c("litigated", "bid_qty_log"),
                         coef_labels_v7,
                         "Panel~A: Total Effect", "Panel~B: Direct Effect",
                         "Litigated vs Ordinary: Negotiated Prices",
                         "t2_lit_neg_prices", "t2_tab_neg_prices.tex",
                         note = lit_neg_note)

log_time("T2.4 Lit Neg Prices Direct", t0)
saveRDS(list(total = t2_neg_total, direct = t2_neg_direct),
        file.path(CHECKPOINT, "t2_neg.rds"))

# T2.5: Firms — Total (DV: ln_n_firms)
cat("\n--- T2.5: Litigated — Participant Firms (Total) ---\n")
t0 <- proc.time()

t2_firms_total <- run_feols4("ln_n_firms", "litigated", dt_lit_win, cluster = ~pbu_id)
save_table_v7(t2_firms_total, "Litigated vs Ordinary: Firms — Total",
              "t2_lit_firms_total_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

log_time("T2.5 Lit Firms Total", t0)

# T2.6: Firms — Direct (DV: ln_n_firms, ctrl: bid_qty_log)
cat("\n--- T2.6: Litigated — Participant Firms (Direct) ---\n")
t0 <- proc.time()

t2_firms_direct <- run_feols4("ln_n_firms", c("litigated", "bid_qty_log"),
                               dt_lit_win, cluster = ~pbu_id)
save_table_v7(t2_firms_direct, "Litigated vs Ordinary: Firms — Direct",
              "t2_lit_firms_direct_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

lit_firms_note <- paste0(
  "Dependent variable: log number of bidding firms. Sample: litigated and ordinary purchases only ",
  "(excluding administrative), winners. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_panel_reg_table_v7(t2_firms_total, t2_firms_direct,
                         "litigated", c("litigated", "bid_qty_log"),
                         coef_labels_v7,
                         "Panel~A: Total Effect", "Panel~B: Direct Effect",
                         "Litigated vs Ordinary: Participant Firms",
                         "t2_lit_firms", "t2_tab_firms.tex",
                         note = lit_firms_note)

log_time("T2.6 Lit Firms Direct", t0)
saveRDS(list(total = t2_firms_total, direct = t2_firms_direct),
        file.path(CHECKPOINT, "t2_firms.rds"))

# T2.7: Success — Total (DV: po_firm_winner, LPM)
cat("\n--- T2.7: Litigated — Success LPM (Total) ---\n")
t0 <- proc.time()

# Success uses ALL obs (not just winners)
t2_success_total <- run_feols4("po_firm_winner", "litigated", dt_lit, cluster = ~pbu_id)
save_table_v7(t2_success_total, "Litigated vs Ordinary: Success — Total",
              "t2_lit_success_total_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

log_time("T2.7 Lit Success Total", t0)

# T2.8: Success — Direct (DV: po_firm_winner, ctrl: bid_qty_log)
cat("\n--- T2.8: Litigated — Success LPM (Direct) ---\n")
t0 <- proc.time()

t2_success_direct <- run_feols4("po_firm_winner", c("litigated", "bid_qty_log"),
                                 dt_lit, cluster = ~pbu_id)
save_table_v7(t2_success_direct, "Litigated vs Ordinary: Success — Direct",
              "t2_lit_success_direct_cluster_pbu",
              coef_map = coef_labels_v7, add_rows = fe_rows())

lit_success_note <- paste0(
  "Dependent variable: successful tender (LPM). Sample: litigated and ordinary purchases only ",
  "(excluding administrative), all observations. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  default_note
)
write_panel_reg_table_v7(t2_success_total, t2_success_direct,
                         "litigated", c("litigated", "bid_qty_log"),
                         coef_labels_v7,
                         "Panel~A: Total Effect", "Panel~B: Direct Effect",
                         "Litigated vs Ordinary: Tender Success (LPM)",
                         "t2_lit_success", "t2_tab_success.tex",
                         note = lit_success_note)

log_time("T2.8 Lit Success Direct", t0)
saveRDS(list(total = t2_success_total, direct = t2_success_direct),
        file.path(CHECKPOINT, "t2_success.rds"))

cat("\n--- TASK 2 COMPLETE ---\n")

# KEY COEFFICIENTS SUMMARY

cat("KEY COEFFICIENTS — Preferred spec: Item+Year+PBU FE\n")

print_coef_v7 <- function(label, model, var) {
  b  <- coef(model)[var]
  se_val <- sqrt(vcov(model)[var, var])
  p  <- pvalue(model)[var]
  pct <- (exp(b) - 1) * 100
  cat(sprintf("  %-50s  b=%.4f (SE=%.4f) p=%.4f  -> %.1f%%\n",
              label, b, se_val, p, pct))
}

cat("\n--- TASK 1: UTG Missing Outcomes (is_admin = Admin vs Litigated) ---\n")
print_coef_v7("T1.1 UTG Ref Price (total)",       t1_ref_total[["Item+Year+PBU"]],    "is_admin")
print_coef_v7("T1.2 UTG Quantity (total)",         t1_qty_total[["Item+Year+PBU"]],    "is_admin")
print_coef_v7("T1.3a UTG Firms (total)",           t1_firms_total[["Item+Year+PBU"]],  "is_admin")
print_coef_v7("T1.3b UTG Firms (direct)",          t1_firms_direct[["Item+Year+PBU"]], "is_admin")
print_coef_v7("T1.4a UTG Success (total)",         t1_success_total[["Item+Year+PBU"]],"is_admin")
print_coef_v7("T1.4b UTG Success (direct)",        t1_success_direct[["Item+Year+PBU"]],"is_admin")

cat("\n--- TASK 2: Litigated Only (litigated vs Ordinary) ---\n")
print_coef_v7("T2.1 Lit Ref Price",                t2_ref[["Item+Year+PBU"]],           "litigated")
print_coef_v7("T2.2 Lit Quantity",                  t2_qty[["Item+Year+PBU"]],           "litigated")
print_coef_v7("T2.3 Lit Neg Price (total)",         t2_neg_total[["Item+Year+PBU"]],     "litigated")
print_coef_v7("T2.4 Lit Neg Price (direct)",        t2_neg_direct[["Item+Year+PBU"]],    "litigated")
print_coef_v7("T2.5 Lit Firms (total)",             t2_firms_total[["Item+Year+PBU"]],   "litigated")
print_coef_v7("T2.6 Lit Firms (direct)",            t2_firms_direct[["Item+Year+PBU"]],  "litigated")
print_coef_v7("T2.7 Lit Success (total)",           t2_success_total[["Item+Year+PBU"]], "litigated")
print_coef_v7("T2.8 Lit Success (direct)",          t2_success_direct[["Item+Year+PBU"]],"litigated")

# FINAL SUMMARY

t_total <- (proc.time() - t_start)[["elapsed"]]

cat("EXECUTION SUMMARY\n")
cat(sprintf("Total execution time: %.1f seconds (%.1f min)\n", t_total, t_total / 60))
cat("\nTiming breakdown:\n")
for (nm in names(timing_log)) {
  cat(sprintf("  %-35s  %.1f sec\n", nm, timing_log[[nm]]))
}

# List output files
cat("\nOutput files generated:\n")
cat("\n  Publication-ready tables (v7):\n")
v7_pub <- list.files(PUB_TAB_V7, pattern = "\\.tex$", full.names = FALSE)
for (f in v7_pub) cat("    ", f, "\n")

cat("\n  Manuscript LaTeX tables (v7):\n")
v7_manu <- list.files(MANU_V7, pattern = "\\.tex$", full.names = FALSE)
for (f in v7_manu) cat("    ", f, "\n")

cat("\n  HTML results (v7):\n")
v7_html <- list.files(RESU_V7, pattern = "\\.html$", full.names = FALSE)
for (f in v7_html) cat("    ", f, "\n")

cat("\n  Checkpoints:\n")
v7_ckpt <- list.files(CHECKPOINT, pattern = "\\.rds$", full.names = FALSE)
for (f in v7_ckpt) cat("    ", f, "\n")

# Generate markdown summary
md_lines <- c(
  "# V7 Extensions — Execution Summary",
  "",
  paste0("**Date:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("**Total time:** ", round(t_total, 1), " seconds (",
         round(t_total / 60, 1), " min)"),
  paste0("**Hardware:** ", n_cores, " cores, ", round(ram_gb, 1), " GB RAM"),
  paste0("**Threads:** fixest=", n_cores, ", data.table=", n_cores),
  "",
  "## Task 1: Under the Gun — Missing Outcomes",
  "",
  "Added to UTG section (IV: `is_admin`, Admin vs Litigated):",
  "",
  "| Estimate | DV | Sample | Pub Table |",
  "|----------|----|---------|-----------| "
)

t1_rows <- list(
  c("Ref Prices",       "bid_price_ref_log", "UTG winners", "t1_tab_utg_ref_prices.tex"),
  c("Quantities",       "bid_qty_log",       "UTG winners", "t1_tab_utg_quantities.tex"),
  c("Firms (A+B)",      "ln_n_firms",        "UTG winners", "t1_tab_utg_firms.tex"),
  c("Success LPM (A+B)","po_firm_winner",    "UTG all obs", "t1_tab_utg_success.tex")
)
for (r in t1_rows) {
  md_lines <- c(md_lines, paste0("| ", paste(r, collapse = " | "), " |"))
}

md_lines <- c(md_lines, "",
  "## Task 2: Urgent Purchases — Litigated Only",
  "",
  "Replicated all urgent regressions with IV: `litigated` (Litigated vs Ordinary, excluding Admin):",
  "",
  "| Estimate | DV | Sample | Pub Table |",
  "|----------|----|---------|-----------| "
)

t2_rows <- list(
  c("Ref Prices",        "bid_price_ref_log", "Lit+Ord winners", "t2_tab_ref_prices.tex"),
  c("Quantities",        "bid_qty_log",       "Lit+Ord winners", "t2_tab_quantities.tex"),
  c("Neg Prices (A+B)",  "bid_price_log",     "Lit+Ord winners", "t2_tab_neg_prices.tex"),
  c("Firms (A+B)",       "ln_n_firms",        "Lit+Ord winners", "t2_tab_firms.tex"),
  c("Success LPM (A+B)", "po_firm_winner",    "Lit+Ord all obs", "t2_tab_success.tex")
)
for (r in t2_rows) {
  md_lines <- c(md_lines, paste0("| ", paste(r, collapse = " | "), " |"))
}

md_lines <- c(md_lines, "",
  "## Timing Breakdown",
  "",
  "| Step | Time (sec) |",
  "|------|------------|"
)
for (nm in names(timing_log)) {
  md_lines <- c(md_lines, sprintf("| %s | %.1f |", nm, timing_log[[nm]]))
}

md_lines <- c(md_lines, "",
  "## Files Generated",
  "",
  paste0("- **Pub tables (v7):** ", length(v7_pub), " .tex files in `v4/pub/tables_v7/`"),
  paste0("- **Manuscript LaTeX (v7):** ", length(v7_manu), " .tex files in `v4/manuscript_v7/`"),
  paste0("- **HTML results (v7):** ", length(v7_html), " .html files in `v4/results_v7/`"),
  paste0("- **Checkpoints:** ", length(v7_ckpt), " .rds files in `v4/checkpoints_v7/`"),
  "",
  "## Regressions Run",
  "",
  paste0("- **Task 1:** ", 4 * 4 + 2 * 4, " regressions (6 outcome specs × 4 FE each = 24)"),
  paste0("- **Task 2:** ", 8 * 4, " regressions (8 outcome specs × 4 FE each = 32)"),
  paste0("- **Total:** 56 regressions"),
  ""
)

md_file <- file.path(V4, "v7_summary.md")
writeLines(md_lines, md_file)
cat("\nSummary written to:", md_file, "\n")

cat("\n16_v7_extensions.R COMPLETE\n")
cat("Finished:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
