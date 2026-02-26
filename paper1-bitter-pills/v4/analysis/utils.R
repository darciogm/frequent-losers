# =============================================================================
# utils.R — Shared infrastructure for v4 R pipeline
# Bitter Pills to Swallow — G65 analysis
# =============================================================================

library(data.table)
library(fixest)
library(modelsummary)
library(ggplot2)

# --- Thread settings ---------------------------------------------------------
setFixest_nthreads(16)
setDTthreads(16)

# --- Path constants ----------------------------------------------------------
# Robust script directory detection
.get_script_dir <- function() {
  # When sourced from another script
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f), mustWork = FALSE))
  }
  # When run via Rscript with --file
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(dirname(sub("^--file=", "", file_arg[1])), mustWork = FALSE))
  }
  # Fallback: working directory
  getwd()
}

.script_dir <- .get_script_dir()
BASE <- normalizePath(file.path(.script_dir, "../.."), mustWork = FALSE)
if (!dir.exists(file.path(BASE, "datasets"))) {
  BASE <- normalizePath("paper1-bitter-pills", mustWork = FALSE)
}
V4        <- file.path(BASE, "v4")
MANU      <- file.path(V4, "manuscript")
RESU      <- file.path(V4, "results")
GRAP      <- file.path(V4, "graphs")
DATA_RAW  <- file.path(BASE, "datasets", "BEC-G65-WORK1.parquet")
DATA_CACHE <- "/tmp/v4_prepared.rds"

# Ensure output dirs exist
for (d in c(MANU, RESU, GRAP)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# --- Winsorization -----------------------------------------------------------
winsorize <- function(x, p_lo = 0.01, p_hi = 0.99) {
  qs <- quantile(x, probs = c(p_lo, p_hi), na.rm = TRUE)
  x[x < qs[1] & !is.na(x)] <- qs[1]
  x[x > qs[2] & !is.na(x)] <- qs[2]
  x
}

winsorize_dt <- function(dt, vars, p_lo = 0.01, p_hi = 0.99) {
  for (v in vars) {
    if (v %in% names(dt)) {
      set(dt, j = v, value = winsorize(dt[[v]], p_lo, p_hi))
    }
  }
  invisible(dt)
}

# --- Regenerate log variables after winsorization ----------------------------
gen_log_vars <- function(dt) {
  if ("bid_price"     %in% names(dt)) dt[, bid_price_log     := log(bid_price)]
  if ("bid_price_ref" %in% names(dt)) dt[, bid_price_ref_log := log(bid_price_ref)]
  if ("bid_qty"       %in% names(dt)) dt[, bid_qty_log       := log(bid_qty)]
  if ("n_firms_bids"  %in% names(dt)) dt[, ln_n_firms        := log(n_firms_bids)]
  invisible(dt)
}

# --- Run 4 FE specifications ------------------------------------------------
# Returns a named list of 4 fixest models
run_feols4 <- function(dv, controls = NULL, data, cluster = ~pbu_id,
                       sample_expr = NULL) {
  # Build RHS
  rhs <- if (is.null(controls) || length(controls) == 0) {
    ""
  } else {
    paste(controls, collapse = " + ")
  }

  # 4 FE specs
  fe_specs <- list(
    "Item"          = "item_id",
    "Item+Year"     = "item_id + year_n",
    "Item+Year+PBU" = "item_id + year_n + pbu_id",
    "Item+YM+PBU"   = "item_id + ym_f + pbu_id"
  )

  models <- list()
  for (nm in names(fe_specs)) {
    fml_str <- paste0(dv, " ~ ", rhs, " | ", fe_specs[[nm]])
    fml <- as.formula(fml_str)
    models[[nm]] <- feols(fml, data = data, cluster = cluster)
  }
  models
}

# --- Save tables via modelsummary --------------------------------------------
save_table <- function(models, title, filename,
                       coef_map = NULL, gof_map = NULL,
                       add_rows = NULL, notes = NULL) {
  if (is.null(gof_map)) {
    gof_map <- c("nobs" = "Observations", "r.squared" = "R²",
                 "adj.r.squared" = "Adj. R²",
                 "within.r.squared" = "Within R²")
  }

  # LaTeX
  tex_file <- file.path(MANU, paste0(filename, ".tex"))
  modelsummary(models, output = tex_file,
               title = title,
               coef_map = coef_map,
               gof_map = gof_map,
               add_rows = add_rows,
               notes = notes,
               stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
               escape = FALSE)

  # HTML
  html_file <- file.path(RESU, paste0(filename, ".html"))
  modelsummary(models, output = html_file,
               title = title,
               coef_map = coef_map,
               gof_map = gof_map,
               add_rows = add_rows,
               notes = notes,
               stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01))

  cat("  Saved:", tex_file, "\n")
  cat("  Saved:", html_file, "\n")
  invisible(NULL)
}

# --- ggplot2 theme -----------------------------------------------------------
theme_paper <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.line = element_line(color = "black", linewidth = 0.3),
      axis.ticks = element_line(color = "black", linewidth = 0.3),
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.title = element_text(face = "bold", size = base_size + 1),
      strip.text = element_text(face = "bold")
    )
}

# --- Coefficient label dictionary --------------------------------------------
coef_labels <- c(
  "urgent"                    = "Urgent Purchase",
  "is_admin"                  = "Administrative (vs Litigated)",
  "bid_qty_log"               = "Log Quantity",
  "bid_price_ref_log"         = "Log Reference Price",
  "ln_n_firms"                = "Log N. Firms",
  "urgent:late_period"        = "Urgent × Late Period",
  "is_admin:late_period"      = "Administrative × Late Period",
  "late_period"               = "Late Period (2014+)",
  "urgent:sus_basic"          = "Urgent × Basic SUS",
  "sus_basic"                 = "Basic SUS Component",
  "urgent:high_competition"   = "Urgent × High Competition",
  "high_competition"          = "High Competition",
  "urgent:large_pbu"          = "Urgent × Large PBU",
  "large_pbu"                 = "Large PBU"
)

# --- FE row labels for modelsummary ------------------------------------------
fe_rows <- function(specs = c("Item", "Item+Year", "Item+Year+PBU", "Item+YM+PBU")) {
  n <- length(specs)
  item_row <- c("Item FE", ifelse(grepl("Item", specs), "Yes", "No"))
  year_row <- c("Year FE", ifelse(grepl("Year", specs) & !grepl("YM", specs), "Yes", "No"))
  ym_row   <- c("Year-Month FE", ifelse(grepl("YM", specs), "Yes", "No"))
  pbu_row  <- c("PBU FE", ifelse(grepl("PBU", specs), "Yes", "No"))
  as.data.frame(rbind(item_row, year_row, ym_row, pbu_row), stringsAsFactors = FALSE)
}

cat("utils.R loaded.\n")
