# ============================================================================
# Paper 2 — SMEs and Public Procurement: the Costs of Restricting Tenders
# Shared utilities (paths, helpers, themes)
# ============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(ggplot2)
  library(arrow)
})

# ---- Path constants --------------------------------------------------------
.script_dir <- if (exists(".script_dir")) .script_dir else getwd()
BASE     <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
DATA_RAW <- file.path(BASE, "data", "raw")
DATA_PARQ <- file.path(BASE, "data", "processed", "paper2_me_epp.parquet")
DATA_CACHE <- "/tmp/p2_prepared.rds"
OUT_TAB  <- file.path(BASE, "output", "tables")
OUT_FIG  <- file.path(BASE, "output", "figures")

for (d in c(OUT_TAB, OUT_FIG)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---- Thread settings -------------------------------------------------------
setFixest_nthreads(16)
setDTthreads(16)

# ---- Window and treatment constants ----------------------------------------
# Stata monthly dates: months since Jan 1960
# March 2018 = (2018-1960)*12 + 2 = 698
TREAT_DATE <- 698L

# Window boundaries [start, end] in Stata monthly dates
WIN_6M  <- c(692L, 703L)   # Sep 2017 – Aug 2018
WIN_12M <- c(686L, 709L)   # Mar 2017 – Feb 2019
WIN_18M <- c(680L, 715L)   # Sep 2016 – Aug 2019

# Semester boundaries for event study (18-month window)
SEM_BREAKS <- c(680L, 686L, 692L, 698L, 704L, 710L, 716L)
SEM_LABELS <- c("Sep16-Feb17", "Mar17-Aug17", "Sep17-Feb18",
                "Mar18-Aug18", "Sep18-Feb19", "Mar19-Aug19")

# ---- Regression helpers ----------------------------------------------------

#' Run a single DiDiR regression for one window and spec
#' @param dv character: dependent variable name
#' @param data data.table: full prepared dataset
#' @param window integer(2): [start, end] Stata monthly dates
#' @param add_pbu logical: if TRUE, add pbu_alt FE
#' @param completed logical: if TRUE, filter to oc_item_status == 1
run_didir <- function(dv, data, window, add_pbu = FALSE, completed = FALSE) {
  dt <- data[data_oc_numb >= window[1] & data_oc_numb <= window[2]]
  if (completed) dt <- dt[oc_item_status == 1L]

  fe <- if (add_pbu) "item_alt + pbu_alt" else "item_alt"
  fml <- as.formula(paste0(dv, " ~ g65_pre + convite + lquantidade | ", fe))
  feols(fml, data = dt, cluster = ~item_alt, fixef.rm = "none")
}

#' Run all 6 DiDiR models for one outcome (3 windows x 2 specs)
#' @return named list of 6 fixest models
run_didir_6 <- function(dv, data, completed = FALSE) {
  windows <- list("6m" = WIN_6M, "12m" = WIN_12M, "18m" = WIN_18M)
  models <- list()
  for (wname in names(windows)) {
    w <- windows[[wname]]
    models[[paste0(wname, "_base")]] <- run_didir(dv, data, w, add_pbu = FALSE, completed = completed)
    models[[paste0(wname, "_pbu")]]  <- run_didir(dv, data, w, add_pbu = TRUE,  completed = completed)
  }
  models
}

# ---- Formatting helpers ----------------------------------------------------
pfmt <- function(x, d = 4) formatC(x, format = "f", digits = d, big.mark = ",")
pfmt_int <- function(x) formatC(x, format = "d", big.mark = ",")

pstars <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
}

#' Format coefficient with stars
coef_cell <- function(model, var, d = 4) {
  b  <- coef(model)[var]
  se <- sqrt(vcov(model)[var, var])
  p  <- 2 * pnorm(-abs(b / se))
  paste0(pfmt(b, d), pstars(p))
}

#' Format standard error in parentheses
se_cell <- function(model, var, d = 4) {
  se <- sqrt(vcov(model)[var, var])
  paste0("(", pfmt(se, d), ")")
}

# ---- Publication figure theme and saver ------------------------------------
FIG_W <- 6.5
FIG_H <- 4
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
