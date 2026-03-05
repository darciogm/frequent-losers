# ============================================================================
# 00_setup.R — Shared setup for Paper 3 v2 pipeline
# Paper 3: Frequent Losers as Cover Bidders in Public Procurement
# ============================================================================
# Loads packages, defines paths, sets thread config, and provides shared helpers.
# All v2 scripts source this file at the top.
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(arrow)
  library(scales)
  library(sensemakr)
  library(MatchIt)
})

# ---- Install optional packages (once) ----------------------------------------
for (pkg in c("bacondecomp", "did")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("  Installing %s...\n", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
  }
}

# ---- Path constants ----------------------------------------------------------
.v2_dir <- if (exists(".v2_dir")) .v2_dir else {
  normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."),
                mustWork = FALSE)
}

BASE_V1    <- normalizePath(file.path(.v2_dir, ".."), mustWork = FALSE)
DATA_V1    <- file.path(BASE_V1, "data", "processed")
DATA_V2    <- file.path(.v2_dir, "data", "processed")
OUT_TAB    <- file.path(.v2_dir, "output", "tables")
OUT_FIG    <- file.path(.v2_dir, "output", "figures")
OUT_LOG    <- file.path(.v2_dir, "output", "logs")

for (d in c(DATA_V2, OUT_TAB, OUT_FIG, OUT_LOG))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# v1 cache paths (from scripts/01_clean.R)
DATA_CACHE       <- "/tmp/p3_prepared.rds"
DATA_CACHE_FP    <- "/tmp/p3_freq_particip.rds"
DATA_CACHE_FIRMS <- "/tmp/p3_firms.rds"
DATA_CACHE_FTM   <- "/tmp/p3_firm_tender_map.rds"
DATA_CACHE_FLS   <- "/tmp/p3_firm_loss_stats.rds"
DATA_CACHE_BL    <- "/tmp/p3_bid_level.rds"

# v2 cache paths
DATA_CACHE_V2    <- "/tmp/p3v3_prepared.rds"
MODELS_CACHE_V2  <- "/tmp/p3v3_models.rds"

# LANCES source (for bid-level with prices)
LANCES_PATH <- file.path(
  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement",
  "ai-procurement/Discontinuity/LANCES_Final_Semester.dta"
)

# ---- Thread settings ---------------------------------------------------------
NCORES <- min(parallel::detectCores(logical = FALSE), 16L)
cat("  Using", NCORES, "threads\n")
setFixest_nthreads(NCORES)
setDTthreads(NCORES)
setFixest_estimation(lean = TRUE)

# ---- BEC key constants -------------------------------------------------------
OC_CODE_LEN    <- 22L
PHASE_CONVITE  <- 2L
PHASE_PREGAO   <- 3L

# ---- Regression helpers (reused from v1/scripts/utils.R) ---------------------

#' Run 4 specifications for one DV (Equation 2 in manuscript)
run_losers_4 <- function(dv, data, price_only = FALSE) {
  dt <- copy(data)
  if (price_only) dt <- dt[!is.na(lneg_price)]

  models <- list()

  models[["general"]] <- feols(
    as.formula(paste0(dv, " ~ losers + convite | item_f + year_f")),
    data = dt, cluster = ~item_f, fixef.rm = "none"
  )

  models[["general_pbu"]] <- feols(
    as.formula(paste0(dv, " ~ losers + convite | item_f + year_f + pbu_f")),
    data = dt, cluster = ~item_f, fixef.rm = "none"
  )

  models[["pregao"]] <- feols(
    as.formula(paste0(dv, " ~ losers | item_f + year_f + pbu_f")),
    data = dt[pregao == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  models[["convite"]] <- feols(
    as.formula(paste0(dv, " ~ losers | item_f + year_f + pbu_f")),
    data = dt[convite == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  models
}

# ---- Formatting helpers ------------------------------------------------------
pfmt     <- function(x, d = 4) formatC(x, format = "f", digits = d, big.mark = ",")
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

pstars <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
}

coef_cell <- function(model, var, d = 4) {
  b  <- coef(model)[var]
  se <- sqrt(vcov(model)[var, var])
  p  <- 2 * pnorm(-abs(b / se))
  paste0(pfmt(b, d), pstars(p))
}

se_cell <- function(model, var, d = 4) {
  se <- sqrt(vcov(model)[var, var])
  paste0("(", pfmt(se, d), ")")
}

# ---- Publication figure theme and saver --------------------------------------
FIG_W     <- 6.5
FIG_H     <- 4
BASE_SIZE <- 9

theme_pub <- function(base_size = BASE_SIZE) {
  theme_bw(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      legend.margin    = margin(t = -2),
      plot.title       = element_blank(),
      strip.text       = element_text(face = "bold")
    )
}

save_pub <- function(plot, filename) {
  filepath <- file.path(OUT_FIG, filename)
  ggsave(filepath, plot, width = FIG_W, height = FIG_H, device = cairo_pdf)
  cat("  Saved:", filepath, "\n")
}

# ---- LaTeX table helper (4-column regression table) --------------------------
write_losers_table <- function(mlist, caption, label, coef_names, coef_labels,
                                d = 4, filename, notes = NULL) {
  m_order <- c("general", "general_pbu", "pregao", "convite")
  ms <- mlist[m_order]

  lines <- c(
    "\\begin{table}[htbp]",
    "\\centering",
    sprintf("\\caption{%s}", caption),
    sprintf("\\label{%s}", label),
    "\\begin{adjustbox}{max width=\\textwidth}",
    "\\begin{threeparttable}",
    "\\small",
    "\\begin{tabular}{lcccc}",
    "\\toprule",
    " & (1) & (2) & (3) & (4) \\\\",
    " & General & General & Preg\\~{a}o & Convite \\\\"
  )

  lines <- c(lines, "\\midrule")

  for (i in seq_along(coef_names)) {
    var <- coef_names[i]
    lbl <- coef_labels[i]

    vals <- sapply(seq_along(ms), function(j) {
      m <- ms[[j]]
      if (var %in% names(coef(m))) coef_cell(m, var, d) else ""
    })
    lines <- c(lines, sprintf("%s & %s \\\\", lbl, paste(vals, collapse = " & ")))

    ses <- sapply(seq_along(ms), function(j) {
      m <- ms[[j]]
      if (var %in% names(coef(m))) se_cell(m, var, d) else ""
    })
    lines <- c(lines, sprintf(" & %s \\\\", paste(ses, collapse = " & ")))
  }

  lines <- c(lines, "\\midrule")

  obs <- sapply(ms, function(m) pfmt_int(m$nobs))
  lines <- c(lines, sprintf("Observations & %s \\\\", paste(obs, collapse = " & ")))

  r2 <- sapply(ms, function(m) pfmt(fitstat(m, "r2")[[1]], 4))
  lines <- c(lines, sprintf("R-squared & %s \\\\", paste(r2, collapse = " & ")))

  lines <- c(lines, "Item Dummies & YES & YES & YES & YES \\\\")
  lines <- c(lines, "Year Dummies & YES & YES & YES & YES \\\\")
  lines <- c(lines, "PBU Dummies & NO & YES & YES & YES \\\\")

  default_notes <- paste(
    "Standard errors clustered at the item level in parentheses.",
    "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
    "Columns (3) and (4) restrict the sample to preg\\~{a}o and convite procedures."
  )

  lines <- c(lines,
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}",
    "\\small",
    sprintf("\\item \\textit{Notes:} %s", if (!is.null(notes)) notes else default_notes),
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{adjustbox}",
    "\\end{table}"
  )

  filepath <- file.path(OUT_TAB, filename)
  writeLines(lines, filepath)
  cat("  Saved:", filepath, "\n")
}

cat("  v2 setup complete.\n")
