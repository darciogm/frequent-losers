# Publication-ready LaTeX tables
# Output: v4/pub/tables/ (17 .tex files, threeparttable + booktabs format)

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

# Output directory
PUB_TAB <- file.path(V4, "pub", "tables")
dir.create(PUB_TAB, recursive = TRUE, showWarnings = FALSE)

# FORMATTING HELPERS

pfmt <- function(x, d = 3) formatC(x, format = "f", digits = d, big.mark = ",")
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

pstars <- function(p) {
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

# Standard FE labels for 4-spec tables
fe_labels_4spec <- list(
  "Item FE"        = c("Yes", "Yes", "Yes", "Yes"),
  "Year FE"        = c("No",  "Yes", "Yes", "No"),
  "Year-Month FE"  = c("No",  "No",  "No",  "Yes"),
  "PBU FE"         = c("No",  "No",  "Yes", "Yes")
)

# Default regression note
default_note <- paste0(
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)

# TABLE WRITERS

# write_reg_table: single-panel regression table
write_reg_table <- function(models, coef_vars, coef_labs, title, label,
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

  filepath <- file.path(PUB_TAB, filename)
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# write_panel_reg_table: two-panel (A/B) regression table
write_panel_reg_table <- function(models_a, models_b,
                                  coef_vars_a, coef_vars_b,
                                  coef_labs,
                                  panel_a_title, panel_b_title,
                                  title, label, filename,
                                  note = NULL, fe_labels = NULL,
                                  digits = 3) {
  n <- length(models_a)
  if (is.null(fe_labels)) fe_labels <- fe_labels_4spec
  if (is.null(note)) note <- default_note

  write_coef_block <- function(models, coef_vars) {
    block <- character()
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

  filepath <- file.path(PUB_TAB, filename)
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# write_panel3_reg_table: three-panel regression table
write_panel3_reg_table <- function(models_a, models_b, models_c,
                                   coef_vars, coef_labs,
                                   panel_titles, title, label, filename,
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
    "    \\hline"
  )

  all_models <- list(models_a, models_b, models_c)
  for (k in seq_along(all_models)) {
    lines <- c(lines,
      paste0("    \\multicolumn{", ncol, "}{l}{\\textit{", panel_titles[k], "}} \\\\[3pt]")
    )
    lines <- c(lines, write_coef_block(all_models[[k]], coef_vars))
    if (k < 3) lines <- c(lines, "    \\hline")
  }

  lines <- c(lines, "    \\hline")
  for (fe_name in names(fe_labels)) {
    vals <- fe_labels[[fe_name]]
    lines <- c(lines,
      paste0("    ", fe_name, " & ", paste(vals[seq_len(n)], collapse = " & "), " \\\\")
    )
  }

  obs_a <- sapply(models_a, function(m) pfmt_int(m$nobs))
  obs_b <- sapply(models_b, function(m) pfmt_int(m$nobs))
  obs_c <- sapply(models_c, function(m) pfmt_int(m$nobs))
  if (identical(obs_a, obs_b) && identical(obs_b, obs_c)) {
    lines <- c(lines,
      paste0("    Observations & ", paste(obs_a, collapse = " & "), " \\\\"))
  } else {
    lines <- c(lines,
      paste0("    Obs.\\ (A) & ", paste(obs_a, collapse = " & "), " \\\\"),
      paste0("    Obs.\\ (B) & ", paste(obs_b, collapse = " & "), " \\\\"),
      paste0("    Obs.\\ (C) & ", paste(obs_c, collapse = " & "), " \\\\"))
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

  filepath <- file.path(PUB_TAB, filename)
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# write_het_table: heterogeneity (split + interaction)
write_het_table <- function(models_lo, models_hi, models_int,
                            split_var, lo_label, hi_label,
                            coef_labs, title, label, filename,
                            note = NULL, digits = 3) {
  # 3 columns: Low (preferred), High (preferred), Interaction (preferred)
  mods <- list(
    models_lo[["Item+Year+PBU"]],
    models_hi[["Item+Year+PBU"]],
    models_int[["Item+Year+PBU"]]
  )

  int_term <- paste0("urgent:", split_var)

  if (is.null(note)) {
    note <- paste0(
      "Preferred specification: Item + Year + PBU FE; PBU-clustered SEs in parentheses. ",
      "Columns (1)--(2) are split-sample estimates. ",
      "Column (3) reports the interaction. ",
      "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
    )
  }

  lines <- c(
    "\\begin{table}[ht]",
    "  \\centering",
    paste0("  \\caption{", title, "}"),
    paste0("  \\label{tab:", label, "}"),
    "  \\small",
    "  \\begin{threeparttable}",
    "  \\begin{tabular}{lccc}",
    "    \\hline\\hline",
    paste0("    & \\multicolumn{2}{c}{Split Sample} & Interaction \\\\"),
    "    \\cmidrule(lr){2-3} \\cmidrule(lr){4-4}",
    paste0("    & ", lo_label, " & ", hi_label, " & Full Sample \\\\"),
    paste0("    & (1) & (2) & (3) \\\\"),
    "    \\hline"
  )

  # Urgent coefficient (all columns)
  cells <- se_cells <- character(3)
  for (j in 1:3) {
    b <- coef(mods[[j]])["urgent"]
    s <- se(mods[[j]])["urgent"]
    p <- pvalue(mods[[j]])["urgent"]
    if (is.na(b)) { cells[j] <- ""; se_cells[j] <- "" }
    else {
      cells[j] <- paste0(pfmt(b, digits), pstars(p))
      se_cells[j] <- paste0("(", pfmt(s, digits), ")")
    }
  }
  lines <- c(lines,
    paste0("    Urgent Purchase & ", paste(cells, collapse = " & "), " \\\\"),
    paste0("     & ", paste(se_cells, collapse = " & "), " \\\\[3pt]")
  )

  # Interaction term (column 3 only)
  b_int <- coef(mods[[3]])[int_term]
  if (!is.na(b_int)) {
    s_int <- se(mods[[3]])[int_term]
    p_int <- pvalue(mods[[3]])[int_term]
    int_label <- if (int_term %in% names(coef_labs)) coef_labs[int_term] else int_term
    lines <- c(lines,
      paste0("    ", int_label, " &  &  & ",
             pfmt(b_int, digits), pstars(p_int), " \\\\"),
      paste0("     &  &  & (", pfmt(s_int, digits), ") \\\\[3pt]")
    )
  }

  # Main effect of split var (column 3 only, if present)
  b_main <- coef(mods[[3]])[split_var]
  if (!is.na(b_main)) {
    s_main <- se(mods[[3]])[split_var]
    p_main <- pvalue(mods[[3]])[split_var]
    main_label <- if (split_var %in% names(coef_labs)) coef_labs[split_var] else split_var
    lines <- c(lines,
      paste0("    ", main_label, " &  &  & ",
             pfmt(b_main, digits), pstars(p_main), " \\\\"),
      paste0("     &  &  & (", pfmt(s_main, digits), ") \\\\[3pt]")
    )
  }

  lines <- c(lines, "    \\hline")
  lines <- c(lines, "    FE: Item + Year + PBU & Yes & Yes & Yes \\\\")

  obs <- sapply(mods, function(m) pfmt_int(m$nobs))
  lines <- c(lines, paste0("    Observations & ", paste(obs, collapse = " & "), " \\\\"))

  wr2 <- sapply(mods, function(m) {
    w <- get_wr2(m); if (is.na(w)) "" else pfmt(w, 3)
  })
  lines <- c(lines, paste0("    Within R$^2$ & ", paste(wr2, collapse = " & "), " \\\\"))

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

  filepath <- file.path(PUB_TAB, filename)
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

# LOAD DATA & PREPARE SAMPLES

cat("\n--- Loading data ---\n")
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

# UTG subsample
dt_utg <- dt[purchase_type == 1 | purchase_type == 2]
dt_utg[, has_admin2 := any(purchase_type == 1), by = item]
dt_utg[, has_lit2   := any(purchase_type == 2), by = item]
dt_utg <- dt_utg[has_admin2 == TRUE & has_lit2 == TRUE]
dt_utg_win <- dt_utg[po_firm_winner == 1]
cat("UTG winners sample:", nrow(dt_utg_win), "obs\n")

# TABLE 1: DESCRIPTIVE STATISTICS
cat("\n--- Table 1: Descriptive Statistics ---\n")

desc_row <- function(data, varname, label) {
  ord <- data[purchase_type == 0 & is.finite(get(varname)), get(varname)]
  adm <- data[purchase_type == 1 & is.finite(get(varname)), get(varname)]
  lit <- data[purchase_type == 2 & is.finite(get(varname)), get(varname)]
  tt_ol <- if (length(ord) > 1 && length(lit) > 1) t.test(ord, lit) else list(p.value = NA)
  tt_al <- if (length(adm) > 1 && length(lit) > 1) t.test(adm, lit) else list(p.value = NA)
  list(label = label,
       m_ord = mean(ord), s_ord = sd(ord), n_ord = length(ord),
       m_adm = mean(adm), s_adm = sd(adm), n_adm = length(adm),
       m_lit = mean(lit), s_lit = sd(lit), n_lit = length(lit),
       diff_ol = mean(ord) - mean(lit), p_ol = tt_ol$p.value,
       diff_al = mean(adm) - mean(lit), p_al = tt_al$p.value)
}

panel_a <- list(
  desc_row(dt_win, "bid_price_ref", "Reference~Price"),
  desc_row(dt_win, "bid_price",     "Negotiated~Price"),
  desc_row(dt_win, "bid_qty",       "Quantity"),
  desc_row(dt,     "n_firms_bids",  "N.~Bidding~Firms")
)
panel_b <- list(
  desc_row(dt_win, "bid_price_ref_log", "Log~Reference~Price"),
  desc_row(dt_win, "bid_price_log",     "Log~Negotiated~Price"),
  desc_row(dt_win, "bid_qty_log",       "Log~Quantity"),
  desc_row(dt,     "ln_n_firms",        "Log~N.~Firms")
)
panel_c <- list(
  desc_row(dt, "po_firm_winner", "Successful~Tender~(\\%)")
)

write_desc_row <- function(r, d = 2) {
  pfmt_p <- function(p) if (is.na(p)) "" else paste0("[", pfmt(p, 3), "]")
  paste0(
    "    ", r$label,
    " & ", pfmt(r$m_ord, d), " & (", pfmt(r$s_ord, d), ")",
    " & ", pfmt(r$m_adm, d), " & (", pfmt(r$s_adm, d), ")",
    " & ", pfmt(r$m_lit, d), " & (", pfmt(r$s_lit, d), ")",
    " & ", pfmt(r$diff_ol, d), pstars(r$p_ol),
    " & ", pfmt(r$diff_al, d), pstars(r$p_al), " \\\\"
  )
}

write_desc_prow <- function(r) {
  pfmt_p <- function(p) if (is.na(p)) "" else paste0("[", pfmt(p, 3), "]")
  paste0(
    "     & & & & & & & ", pfmt_p(r$p_ol), " & ", pfmt_p(r$p_al), " \\\\"
  )
}

desc_lines <- c(
  "\\begin{table}[ht]",
  "  \\centering",
  "  \\caption{Descriptive Statistics by Purchase Type}",
  "  \\label{tab:desc_stats}",
  "  \\resizebox{\\textwidth}{!}{%",
  "  \\begin{threeparttable}",
  "  \\begin{tabular}{lcccccccc}",
  "    \\hline\\hline",
  "    & \\multicolumn{2}{c}{Ordinary} & \\multicolumn{2}{c}{Administrative} & \\multicolumn{2}{c}{Litigated} & Diff & Diff \\\\",
  "    \\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7}",
  "    & Mean & (SD) & Mean & (SD) & Mean & (SD) & (O--L) & (A--L) \\\\",
  "    \\hline",
  paste0("    \\multicolumn{9}{l}{\\textit{Panel~A: Levels}} \\\\[3pt]")
)
for (r in panel_a) desc_lines <- c(desc_lines, write_desc_row(r, 2), write_desc_prow(r))
desc_lines <- c(desc_lines,
  "    \\\\[3pt]",
  paste0("    \\multicolumn{9}{l}{\\textit{Panel~B: Log~Transformations}} \\\\[3pt]")
)
for (r in panel_b) desc_lines <- c(desc_lines, write_desc_row(r, 3), write_desc_prow(r))
desc_lines <- c(desc_lines,
  "    \\\\[3pt]",
  paste0("    \\multicolumn{9}{l}{\\textit{Panel~C: Tender~Characteristics}} \\\\[3pt]")
)
for (r in panel_c) desc_lines <- c(desc_lines, write_desc_row(r, 3), write_desc_prow(r))

desc_lines <- c(desc_lines,
  "    \\hline",
  paste0("    Observations",
         " & \\multicolumn{2}{c}{", pfmt_int(panel_a[[1]]$n_ord), "}",
         " & \\multicolumn{2}{c}{", pfmt_int(panel_a[[1]]$n_adm), "}",
         " & \\multicolumn{2}{c}{", pfmt_int(panel_a[[1]]$n_lit), "}",
         " & & \\\\"),
  "    \\hline\\hline",
  "  \\end{tabular}",
  "  \\begin{tablenotes}",
  "    \\small",
  paste0("    \\item \\textit{Notes:} Sample restricted to items with at least one ordinary ",
         "and one litigated purchase. Winners only for price and quantity variables. ",
         "Variables winsorized at 1\\%/99\\%. ",
         "Stars on differences from Welch \\textit{t}-tests; \\textit{p}-values in brackets. ",
         "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."),
  "  \\end{tablenotes}",
  "  \\end{threeparttable}",
  "  }",
  "\\end{table}"
)

writeLines(desc_lines, file.path(PUB_TAB, "tab_desc_stats.tex"))
cat("  Saved: tab_desc_stats.tex\n")

# TABLE 2: BALANCE TABLE
cat("\n--- Table 2: Balance Table ---\n")

balance_row <- function(data, varname, label) {
  adm <- data[is_admin == 1 & is.finite(get(varname)), get(varname)]
  lit <- data[is_admin == 0 & is.finite(get(varname)), get(varname)]
  tt <- if (length(adm) > 1 && length(lit) > 1) t.test(adm, lit) else list(statistic = NA, p.value = NA)
  list(label = label,
       m_adm = mean(adm), s_adm = sd(adm), n_adm = length(adm),
       m_lit = mean(lit), s_lit = sd(lit), n_lit = length(lit),
       diff = mean(adm) - mean(lit), t_stat = as.numeric(tt$statistic),
       p_val = tt$p.value)
}

bal_a <- list(
  balance_row(dt_utg[po_firm_winner == 1], "bid_price_ref",     "Reference~Price"),
  balance_row(dt_utg[po_firm_winner == 1], "bid_price",         "Negotiated~Price"),
  balance_row(dt_utg[po_firm_winner == 1], "bid_qty",           "Quantity"),
  balance_row(dt_utg[po_firm_winner == 1], "bid_price_ref_log", "Log~Reference~Price"),
  balance_row(dt_utg[po_firm_winner == 1], "bid_price_log",     "Log~Negotiated~Price"),
  balance_row(dt_utg[po_firm_winner == 1], "bid_qty_log",       "Log~Quantity")
)
bal_b <- list(
  balance_row(dt_utg, "n_firms_bids",   "N.~Bidding~Firms"),
  balance_row(dt_utg, "ln_n_firms",     "Log~N.~Firms"),
  balance_row(dt_utg, "po_firm_winner", "Successful~Tender~(\\%)")
)
bal_c <- list(
  balance_row(dt_utg, "pregao", "Electronic~Auction")
)

write_bal_row <- function(r, d = 2) {
  paste0(
    "    ", r$label,
    " & ", pfmt(r$m_adm, d), " & (", pfmt(r$s_adm, d), ")",
    " & ", pfmt(r$m_lit, d), " & (", pfmt(r$s_lit, d), ")",
    " & ", pfmt(r$diff, d), pstars(r$p_val),
    " & [", pfmt(r$p_val, 3), "] \\\\"
  )
}

bal_lines <- c(
  "\\begin{table}[ht]",
  "  \\centering",
  "  \\caption{Balance Table: Administrative vs Litigated (Urgent Purchases)}",
  "  \\label{tab:balance}",
  "  \\footnotesize",
  "  \\begin{threeparttable}",
  "  \\begin{tabular}{lcccccc}",
  "    \\hline\\hline",
  "    & \\multicolumn{2}{c}{Administrative} & \\multicolumn{2}{c}{Litigated} & Diff & \\textit{p}-value \\\\",
  "    \\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  "    & Mean & (SD) & Mean & (SD) & (A--L) & \\\\",
  "    \\hline",
  paste0("    \\multicolumn{7}{l}{\\textit{Panel~A: Procurement~Outcomes}} \\\\[3pt]")
)
for (r in bal_a) bal_lines <- c(bal_lines, write_bal_row(r, 2))
bal_lines <- c(bal_lines,
  "    \\\\[3pt]",
  paste0("    \\multicolumn{7}{l}{\\textit{Panel~B: Market~Structure}} \\\\[3pt]")
)
for (r in bal_b) bal_lines <- c(bal_lines, write_bal_row(r, 3))
bal_lines <- c(bal_lines,
  "    \\\\[3pt]",
  paste0("    \\multicolumn{7}{l}{\\textit{Panel~C: Purchase~Characteristics}} \\\\[3pt]")
)
for (r in bal_c) bal_lines <- c(bal_lines, write_bal_row(r, 3))

bal_lines <- c(bal_lines,
  "    \\hline",
  paste0("    Observations",
         " & \\multicolumn{2}{c}{", pfmt_int(bal_a[[1]]$n_adm), "}",
         " & \\multicolumn{2}{c}{", pfmt_int(bal_a[[1]]$n_lit), "}",
         " & & \\\\"),
  "    \\hline\\hline",
  "  \\end{tabular}",
  "  \\begin{tablenotes}",
  "    \\small",
  paste0("    \\item \\textit{Notes:} Sample restricted to urgent purchases (administrative ",
         "and litigated) for items with both types present. Winners only for price/quantity. ",
         "Variables winsorized at 1\\%/99\\%. \\textit{p}-values from Welch \\textit{t}-tests ",
         "in brackets. *** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."),
  "  \\end{tablenotes}",
  "  \\end{threeparttable}",
  "\\end{table}"
)

writeLines(bal_lines, file.path(PUB_TAB, "tab_balance.tex"))
cat("  Saved: tab_balance.tex\n")

# REGRESSION TABLES (3–8)

cat("\n--- Running regressions ---\n")

# Table 4: Reference Prices
t4 <- run_feols4("bid_price_ref_log", "urgent", dt_win, cluster = ~pbu_id)

# Table 5: Quantities
t5 <- run_feols4("bid_qty_log", "urgent", dt_win, cluster = ~pbu_id)

# Table 6: Negotiated Prices
t6a <- run_feols4("bid_price_log", "urgent", dt_win, cluster = ~pbu_id)
t6b <- run_feols4("bid_price_log", c("urgent", "bid_qty_log"), dt_win, cluster = ~pbu_id)

# Table 7: Firms
t7a <- run_feols4("ln_n_firms", "urgent", dt_win, cluster = ~pbu_id)
t7b <- run_feols4("ln_n_firms", c("urgent", "bid_qty_log"), dt_win, cluster = ~pbu_id)

# Table 9: Success
t9a <- run_feols4("po_firm_winner", "urgent", dt, cluster = ~pbu_id)
t9b <- run_feols4("po_firm_winner", c("urgent", "bid_qty_log"), dt, cluster = ~pbu_id)

# Table 10: Under the Gun
t10a <- run_feols4("bid_price_log", "is_admin", dt_utg_win, cluster = ~pbu_id)
t10b <- run_feols4("bid_price_log", c("is_admin", "bid_qty_log"), dt_utg_win, cluster = ~pbu_id)

cat("  All regressions done.\n")

# Table 3: Reference Prices
cat("\n--- Table 3: Reference Prices ---\n")

ref_note <- paste0(
  "Dependent variable: log reference price. Sample: winners only, items with both ",
  "ordinary and litigated purchases. Winsorized at 1\\%/99\\%. ",
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)
write_reg_table(t4, "urgent", coef_labels,
                "Reference Prices", "ref_prices", "tab_ref_prices.tex",
                note = ref_note)

# Table 4: Quantities
cat("Table 4: Quantities\n")

qty_note <- paste0(
  "Dependent variable: log quantity. Sample: winners only. Winsorized at 1\\%/99\\%. ",
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)
write_reg_table(t5, "urgent", coef_labels,
                "Quantities", "quantities", "tab_quantities.tex",
                note = qty_note)

# Table 5: Negotiated Prices (Panel A: Total, Panel B: Direct)
cat("Table 5: Negotiated Prices\n")

neg_note <- paste0(
  "Dependent variable: log negotiated price. Sample: winners only. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)
write_panel_reg_table(t6a, t6b,
                      "urgent", c("urgent", "bid_qty_log"),
                      coef_labels,
                      "Panel~A: Total Effect", "Panel~B: Direct Effect",
                      "Negotiated Prices", "neg_prices", "tab_neg_prices.tex",
                      note = neg_note)

# Table 6: Firms (Panel A: Total, Panel B: Direct)
cat("Table 6: Participant Firms\n")

firms_note <- paste0(
  "Dependent variable: log number of bidding firms. Sample: winners only. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)
write_panel_reg_table(t7a, t7b,
                      "urgent", c("urgent", "bid_qty_log"),
                      coef_labels,
                      "Panel~A: Total Effect", "Panel~B: Direct Effect",
                      "Participant Firms", "firms", "tab_firms.tex",
                      note = firms_note)

# Table 7: Success LPM (Panel A: Total, Panel B: Direct)
cat("Table 7: Success LPM\n")

success_note <- paste0(
  "Dependent variable: successful tender (LPM). Sample: all observations. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)
write_panel_reg_table(t9a, t9b,
                      "urgent", c("urgent", "bid_qty_log"),
                      coef_labels,
                      "Panel~A: Total Effect", "Panel~B: Direct Effect",
                      "Tender Success (LPM)", "success", "tab_success.tex",
                      note = success_note)

# Table 8: Under the Gun (Panel A: Total, Panel B: Direct)
cat("Table 8: Under the Gun\n")

utg_note <- paste0(
  "Dependent variable: log negotiated price. Sample: urgent purchases only ",
  "(administrative and litigated), winners, items with both types present. ",
  "Panel~A reports the total effect; Panel~B controls for log quantity. ",
  "Winsorized at 1\\%/99\\%. ",
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)
write_panel_reg_table(t10a, t10b,
                      "is_admin", c("is_admin", "bid_qty_log"),
                      coef_labels,
                      "Panel~A: Total Effect", "Panel~B: Direct Effect",
                      "Under the Gun: Administrative vs Litigated",
                      "underthegun", "tab_underthegun.tex",
                      note = utg_note)

# HETEROGENEITY TABLES (9–12)
cat("\n--- Heterogeneity regressions ---\n")

run_het <- function(dt_win, split_var) {
  dt_sub <- dt_win[!is.na(get(split_var))]
  dt_lo <- dt_sub[get(split_var) == 0]
  dt_hi <- dt_sub[get(split_var) == 1]

  models_lo <- run_feols4("bid_price_log", "urgent", dt_lo, cluster = ~pbu_id)
  models_hi <- run_feols4("bid_price_log", "urgent", dt_hi, cluster = ~pbu_id)

  fe_specs <- list(
    "Item"          = "item_id",
    "Item+Year"     = "item_id + year_n",
    "Item+Year+PBU" = "item_id + year_n + pbu_id",
    "Item+YM+PBU"   = "item_id + ym_f + pbu_id"
  )
  models_int <- list()
  for (nm in names(fe_specs)) {
    fml <- as.formula(paste0("bid_price_log ~ urgent * ", split_var,
                             " | ", fe_specs[[nm]]))
    models_int[[nm]] <- feols(fml, data = dt_sub, cluster = ~pbu_id)
  }

  list(lo = models_lo, hi = models_hi, int = models_int)
}

# SUS Component
cat("  SUS Component\n")
het_sus <- run_het(dt_win, "sus_basic")
write_het_table(het_sus$lo, het_sus$hi, het_sus$int,
                "sus_basic", "Specialized", "Basic~SUS",
                coef_labels,
                "Heterogeneity: SUS Component", "het_sus", "tab_het_sus.tex")

# Time Period
cat("  Time Period\n")
het_period <- run_het(dt_win, "late_period")
write_het_table(het_period$lo, het_period$hi, het_period$int,
                "late_period", "Early", "Late~(2014+)",
                coef_labels,
                "Heterogeneity: Time Period", "het_period", "tab_het_period.tex")

# Market Competition
cat("  Market Competition\n")
het_comp <- run_het(dt_win, "high_competition")
write_het_table(het_comp$lo, het_comp$hi, het_comp$int,
                "high_competition", "Low~Comp.", "High~Comp.",
                coef_labels,
                "Heterogeneity: Market Competition", "het_competition",
                "tab_het_competition.tex")

# PBU Size
cat("  PBU Size\n")
het_pbu <- run_het(dt_win, "large_pbu")
write_het_table(het_pbu$lo, het_pbu$hi, het_pbu$int,
                "large_pbu", "Small~PBU", "Large~PBU",
                coef_labels,
                "Heterogeneity: PBU Size", "het_pbu", "tab_het_pbu.tex")

# ROBUSTNESS TABLE 13: UTG PROGRESSIVE CONTROLS (3 winsor panels)
cat("\n--- Robustness: UTG Progressive ---\n")

run_utg_prog <- function(dt_base, p_lo, p_hi) {
  dt2 <- copy(dt_base)
  if (p_lo > 0 || p_hi < 1) winsorize_dt(dt2, win_vars, p_lo, p_hi)
  gen_log_vars(dt2)

  dt_u <- dt2[purchase_type == 1 | purchase_type == 2]
  dt_u[, has_admin2 := any(purchase_type == 1), by = item]
  dt_u[, has_lit2   := any(purchase_type == 2), by = item]
  dt_u <- dt_u[has_admin2 == TRUE & has_lit2 == TRUE]
  dw <- dt_u[po_firm_winner == 1]

  list(
    feols(bid_price_log ~ is_admin | item_id + year_n + pbu_id,
          data = dw, cluster = ~pbu_id),
    feols(bid_price_log ~ is_admin + bid_qty_log | item_id + year_n + pbu_id,
          data = dw, cluster = ~pbu_id),
    feols(bid_price_log ~ is_admin + bid_qty_log + bid_price_ref_log | item_id + year_n + pbu_id,
          data = dw, cluster = ~pbu_id),
    feols(bid_price_log ~ is_admin + bid_qty_log + bid_price_ref_log + ln_n_firms | item_id + year_n + pbu_id,
          data = dw, cluster = ~pbu_id),
    feols(bid_price_log ~ is_admin + bid_qty_log + bid_price_ref_log + ln_n_firms | item_id + ym_f + pbu_id,
          data = dw, cluster = ~pbu_id)
  )
}

utg_nowin <- run_utg_prog(dt_raw, 0, 1)
utg_w01   <- run_utg_prog(dt_raw, 0.01, 0.99)
utg_w05   <- run_utg_prog(dt_raw, 0.05, 0.95)

utg_prog_fe <- list(
  "Log~Quantity"         = c("No",  "Yes", "Yes", "Yes", "Yes"),
  "Log~Ref.~Price"       = c("No",  "No",  "Yes", "Yes", "Yes"),
  "Log~N.~Firms"         = c("No",  "No",  "No",  "Yes", "Yes"),
  "Item FE"              = c("Yes", "Yes", "Yes", "Yes", "Yes"),
  "Year FE"              = c("Yes", "Yes", "Yes", "Yes", "No"),
  "Year-Month FE"        = c("No",  "No",  "No",  "No",  "Yes"),
  "PBU FE"               = c("Yes", "Yes", "Yes", "Yes", "Yes")
)

utg_rob_note <- paste0(
  "Dependent variable: log negotiated price. UTG sample (urgent, winners, items with ",
  "both administrative and litigated). Progressive controls added left to right. ",
  "Column~(5) replaces Year with Year-Month FE. ",
  "Standard errors clustered at the PBU level in parentheses. ",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
)

write_panel3_reg_table(utg_nowin, utg_w01, utg_w05,
                       "is_admin", coef_labels,
                       c("Panel~A: No Winsorization",
                         "Panel~B: Winsorized 1\\%/99\\%",
                         "Panel~C: Winsorized 5\\%/95\\%"),
                       "Robustness: Under the Gun with Progressive Controls",
                       "rob_utg", "tab_rob_utg.tex",
                       note = utg_rob_note, fe_labels = utg_prog_fe)

# ROBUSTNESS TABLES 14–17: MAIN TABLES × 3 WINSORIZATION LEVELS
cat("\n--- Robustness: Main tables × winsorization ---\n")

run_main_winsor <- function(dt_base, p_lo, p_hi) {
  dt2 <- copy(dt_base)
  if (p_lo > 0 || p_hi < 1) winsorize_dt(dt2, win_vars, p_lo, p_hi)
  gen_log_vars(dt2)
  dw <- dt2[po_firm_winner == 1]

  list(
    ref   = run_feols4("bid_price_ref_log", "urgent", dw, ~pbu_id),
    neg   = run_feols4("bid_price_log",     "urgent", dw, ~pbu_id),
    firms = run_feols4("ln_n_firms",        "urgent", dw, ~pbu_id),
    succ  = run_feols4("po_firm_winner",    "urgent", dt2, ~pbu_id)
  )
}

rob_nowin <- run_main_winsor(dt_raw, 0, 1)
rob_w01   <- run_main_winsor(dt_raw, 0.01, 0.99)
rob_w05   <- run_main_winsor(dt_raw, 0.05, 0.95)

rob_note_fn <- function(dv_desc) {
  paste0(
    "Dependent variable: ", dv_desc, ". Sample: winners only (success uses all obs). ",
    "Each panel uses a different winsorization level. ",
    "Standard errors clustered at the PBU level in parentheses. ",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1."
  )
}

# Table 14: Robustness — Reference Prices
cat("  Robustness: Reference Prices\n")
write_panel3_reg_table(
  rob_nowin$ref, rob_w01$ref, rob_w05$ref,
  "urgent", coef_labels,
  c("Panel~A: No Winsorization",
    "Panel~B: Winsorized 1\\%/99\\%",
    "Panel~C: Winsorized 5\\%/95\\%"),
  "Robustness: Reference Prices", "rob_ref_prices", "tab_rob_ref_prices.tex",
  note = rob_note_fn("log reference price"))

# Table 15: Robustness — Negotiated Prices
cat("  Robustness: Negotiated Prices\n")
write_panel3_reg_table(
  rob_nowin$neg, rob_w01$neg, rob_w05$neg,
  "urgent", coef_labels,
  c("Panel~A: No Winsorization",
    "Panel~B: Winsorized 1\\%/99\\%",
    "Panel~C: Winsorized 5\\%/95\\%"),
  "Robustness: Negotiated Prices", "rob_neg_prices", "tab_rob_neg_prices.tex",
  note = rob_note_fn("log negotiated price"))

# Table 16: Robustness — Firms
cat("  Robustness: Firms\n")
write_panel3_reg_table(
  rob_nowin$firms, rob_w01$firms, rob_w05$firms,
  "urgent", coef_labels,
  c("Panel~A: No Winsorization",
    "Panel~B: Winsorized 1\\%/99\\%",
    "Panel~C: Winsorized 5\\%/95\\%"),
  "Robustness: Participant Firms", "rob_firms", "tab_rob_firms.tex",
  note = rob_note_fn("log number of bidding firms"))

# Table 17: Robustness — Success
cat("  Robustness: Success\n")
write_panel3_reg_table(
  rob_nowin$succ, rob_w01$succ, rob_w05$succ,
  "urgent", coef_labels,
  c("Panel~A: No Winsorization",
    "Panel~B: Winsorized 1\\%/99\\%",
    "Panel~C: Winsorized 5\\%/95\\%"),
  "Robustness: Tender Success (LPM)", "rob_success", "tab_rob_success.tex",
  note = rob_note_fn("successful tender (LPM)"))


# Emit macros for the manuscript layer.
# 08 is the canonical publication-table script: it re-fits the same models
# that 03/04/06 do, then writes the booktabs/threeparttable .tex files that
# the manuscript actually \input{}s. Macros emitted here are the single
# source of truth for the prose. (03/04/06 also emit the same blocks; since
# both fit identical models on identical samples, the values agree.)
.bp_macros_path <- file.path(.this_dir, "..", "..", "v6-jpub-short", "analysis", "_macros.R")
if (file.exists(.bp_macros_path)) {
  source(.bp_macros_path)

  pull <- function(model, var) {
    list(b  = unname(coef(model)[var]),
         se = unname(sqrt(vcov(model)[var, var])),
         n  = model$nobs)
  }

  m <- list()

  # Reference / Negotiated / Firms / Quantity / Success / UTG (Tables 4-10)
  r  <- pull(t4[["Item+Year+PBU"]],  "urgent")
  ri <- pull(t4[["Item"]],            "urgent")
  m$refCoef       <- bp_fmt(r$b, 3); m$refSE <- bp_fmt(r$se, 3)
  m$refPct        <- bp_fmt_pct((exp(r$b) - 1) * 100, 1)
  m$refCoefItem   <- bp_fmt(ri$b, 3)
  m$refPctItem    <- bp_fmt_pct((exp(ri$b) - 1) * 100, 1)
  m$refPctPreferred <- m$refPct
  m$refPctItemFE    <- m$refPctItem

  q <- pull(t5[["Item+Year+PBU"]], "urgent")
  m$qtyCoef <- bp_fmt(q$b, 3); m$qtySE <- bp_fmt(q$se, 3)

  na  <- pull(t6a[["Item+Year+PBU"]], "urgent")
  ni  <- pull(t6a[["Item"]],          "urgent")
  nym <- pull(t6a[["Item+YM+PBU"]],   "urgent")
  m$negCoef           <- bp_fmt(na$b, 3); m$negSE <- bp_fmt(na$se, 3)
  m$negPct            <- bp_fmt_pct((exp(na$b) - 1) * 100, 1)
  m$negPanelAcoefShort<- bp_fmt(na$b, 3)
  m$negNobs           <- bp_fmt_int(na$n)
  m$negCoefItem       <- bp_fmt(ni$b, 3)
  m$negPctItem        <- bp_fmt_pct((exp(ni$b) - 1) * 100, 1)
  m$negPctItemFE      <- m$negPctItem
  m$negCoefItemYM     <- bp_fmt(nym$b, 3)
  m$negPctItemYM      <- bp_fmt_pct((exp(nym$b) - 1) * 100, 1)
  m$negPctRange       <- sprintf("%s--%s\\%%",
                                 bp_fmt_pct_n((exp(na$b) - 1) * 100, 1),
                                 bp_fmt_pct_n((exp(nym$b) - 1) * 100, 1))
  m$negPctHeadline    <- bp_fmt_pct((exp(na$b) - 1) * 100, 1)

  nb <- pull(t6b[["Item+Year+PBU"]], "urgent")
  qb <- pull(t6b[["Item+Year+PBU"]], "bid_qty_log")
  m$negPanelBcoef       <- bp_fmt(nb$b, 3)
  m$negPanelBcoefShort  <- bp_fmt(nb$b, 3)
  m$negPanelBpct        <- bp_fmt_pct((exp(nb$b) - 1) * 100, 1)
  m$negPanelBqty        <- bp_fmt(qb$b, 3)

  fm <- pull(t7a[["Item+Year+PBU"]], "urgent")
  m$firmsCoef <- bp_fmt(fm$b, 3); m$firmsSE <- bp_fmt(fm$se, 3)
  m$firmsPct  <- bp_fmt_pct((exp(fm$b) - 1) * 100, 1)
  m$firmsPctHeadline <- m$firmsPct

  sm <- pull(t9a[["Item+Year+PBU"]], "urgent")
  m$successCoef <- bp_fmt(sm$b, 3); m$successSE <- bp_fmt(sm$se, 3)
  m$successPct  <- bp_fmt_pp(sm$b * 100, 1)
  m$successPP   <- bp_fmt_pp(sm$b * 100, 1)

  # UTG headline range covers all 4 canonical specs (col 1: Item; col 2: Item+Year;
  # col 3: Item+Year+PBU; col 4: Item+YM+PBU). The original "23-30%" prose came
  # from the bottom-to-top sweep across these specs.
  ua_item   <- pull(t10a[["Item"]],          "is_admin")
  ua_year   <- pull(t10a[["Item+Year"]],     "is_admin")
  ua        <- pull(t10a[["Item+Year+PBU"]], "is_admin")
  uy        <- pull(t10a[["Item+YM+PBU"]],   "is_admin")
  ub        <- pull(t10b[["Item+Year+PBU"]], "is_admin")
  uq        <- pull(t10b[["Item+Year+PBU"]], "bid_qty_log")
  utg_pcts4 <- (exp(-c(ua_item$b, ua_year$b, ua$b, uy$b)) - 1) * 100
  m$utgCoef        <- bp_fmt(ua$b, 3); m$utgSE <- bp_fmt(ua$se, 3)
  m$utgPct         <- bp_fmt_pct(utg_pcts4[3], 1)
  m$utgCoefItemYM  <- bp_fmt(uy$b, 3)
  m$utgPctItemYM   <- bp_fmt_pct(utg_pcts4[4], 1)
  m$utgCoefItem    <- bp_fmt(ua_item$b, 3)
  m$utgPctItem     <- bp_fmt_pct(utg_pcts4[1], 1)
  m$utgCoefItemYr  <- bp_fmt(ua_year$b, 3)
  m$utgPctItemYr   <- bp_fmt_pct(utg_pcts4[2], 1)
  m$utgPanelBcoef  <- bp_fmt(ub$b, 3); m$utgPanelBSE <- bp_fmt(ub$se, 3)
  m$utgPanelBqty   <- bp_fmt(uq$b, 3)
  # Range across the 4 specs (matches original "23-30%" framing honestly)
  m$utgPctRange    <- sprintf("%s--%s\\%%",
                              bp_fmt_pct_n(min(utg_pcts4), 0),
                              bp_fmt_pct_n(max(utg_pcts4), 0))
  m$utgPctRangePreferred <- sprintf("%s--%s\\%%",
                              bp_fmt_pct_n(min(utg_pcts4[3:4]), 1),
                              bp_fmt_pct_n(max(utg_pcts4[3:4]), 1))
  m$nUTG <- bp_fmt_int(ua$n)

  # Heterogeneity: SUS basic vs specialized; market competition split + interaction
  if (exists("het_sus")) {
    b_basic <- coef(het_sus$hi[["Item+Year+PBU"]])["urgent"]
    b_spec  <- coef(het_sus$lo[["Item+Year+PBU"]])["urgent"]
    if (length(b_basic) == 1 && !is.na(b_basic)) m$hetSUSbasic <- bp_fmt(b_basic, 3)
    if (length(b_spec)  == 1 && !is.na(b_spec))  m$hetSUSspec  <- bp_fmt(b_spec, 3)
  }
  if (exists("het_comp")) {
    b_hi <- coef(het_comp$hi[["Item+Year+PBU"]])["urgent"]
    b_lo <- coef(het_comp$lo[["Item+Year+PBU"]])["urgent"]
    inter_m   <- het_comp$int[["Item+Year+PBU"]]
    inter_var <- intersect(c("urgent:high_competition", "urgent:high_competitionTRUE"),
                           names(coef(inter_m)))[1]
    if (length(b_hi) == 1) m$hetCompetitive  <- bp_fmt(b_hi, 3)
    if (length(b_lo) == 1) m$hetConcentrated <- bp_fmt(b_lo, 3)
    if (!is.na(inter_var)) m$hetInteraction  <- bp_fmt(coef(inter_m)[inter_var], 3)
  }

  # Robustness (Appendix A.1): preferred coef per winsor variant
  if (exists("rob_nowin") && exists("rob_w01") && exists("rob_w05")) {
    m$robRefNoWin  <- bp_fmt(coef(rob_nowin$ref[["Item+Year+PBU"]])["urgent"], 3)
    m$robRefBase   <- bp_fmt(coef(rob_w01$ref[["Item+Year+PBU"]])["urgent"], 3)
    m$robRefAgg    <- bp_fmt(coef(rob_w05$ref[["Item+Year+PBU"]])["urgent"], 3)
    neg_p_no  <- (exp(coef(rob_nowin$neg[["Item+Year+PBU"]])["urgent"]) - 1) * 100
    neg_p_w01 <- (exp(coef(rob_w01$neg[["Item+Year+PBU"]])["urgent"])   - 1) * 100
    neg_p_w05 <- (exp(coef(rob_w05$neg[["Item+Year+PBU"]])["urgent"])   - 1) * 100
    m$robNegLow  <- bp_fmt_pct_n(min(neg_p_no, neg_p_w01, neg_p_w05), 0)
    m$robNegHigh <- bp_fmt_pct_n(max(neg_p_no, neg_p_w01, neg_p_w05), 0)
    fc <- c(coef(rob_nowin$firms[["Item+Year+PBU"]])["urgent"],
            coef(rob_w01$firms[["Item+Year+PBU"]])["urgent"],
            coef(rob_w05$firms[["Item+Year+PBU"]])["urgent"])
    m$robFirmsLow  <- bp_fmt(min(fc), 2)
    m$robFirmsHigh <- bp_fmt(max(fc), 2)
    suc_pp <- mean(c(coef(rob_nowin$succ[["Item+Year+PBU"]])["urgent"],
                     coef(rob_w01$succ[["Item+Year+PBU"]])["urgent"],
                     coef(rob_w05$succ[["Item+Year+PBU"]])["urgent"])) * 100
    m$robSuccessPP <- bp_fmt_pp(suc_pp, 0)
    m$winsorAggLow  <- "5"
    m$winsorAggHigh <- "95"
  }

  bp_macros_emit("08_pub_tables", m)
}

# SUMMARY
n_files <- length(list.files(PUB_TAB, pattern = "\\.tex$"))
cat(sprintf("\n08_pub_tables.R complete: %d .tex files in %s\n", n_files, PUB_TAB))
