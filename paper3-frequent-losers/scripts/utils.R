# ============================================================================
# Paper 3 — Frequent Losers in Public Procurement
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
BASE      <- normalizePath(file.path(.script_dir, ".."), mustWork = FALSE)
DATA_PROC <- file.path(BASE, "data", "processed")
DATA_CACHE     <- "/tmp/p3_prepared.rds"
DATA_CACHE_EXT <- "/tmp/p3_prepared_ext.rds"
DATA_CACHE_FP  <- "/tmp/p3_freq_particip.rds"
DATA_CACHE_FIRMS <- "/tmp/p3_firms.rds"
DATA_CACHE_FTM   <- "/tmp/p3_firm_tender_map.rds"
DATA_CACHE_FLS   <- "/tmp/p3_firm_loss_stats.rds"
DATA_CACHE_BL    <- "/tmp/p3_bid_level.rds"
OUT_TAB   <- file.path(BASE, "output", "tables")
OUT_FIG   <- file.path(BASE, "output", "figures")

for (d in c(OUT_TAB, OUT_FIG)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---- Thread settings -------------------------------------------------------
NCORES <- min(parallel::detectCores(logical = FALSE), 16L)
cat("  Using", NCORES, "threads\n")
setFixest_nthreads(NCORES)
setDTthreads(NCORES)
setFixest_estimation(lean = TRUE)

# ---- BEC key constants -----------------------------------------------------
# BEC po_item_merge_key structure:
#   chars 1-11  = PBU code
#   chars 12-15 = year (4 digits)
#   chars 16-17 = "OC"
#   chars 18-22 = OC sequence number
#   chars 23+   = item code (variable length) + description
OC_CODE_LEN <- 22L

# ---- Phase code → procedure type mapping -----------------------------------
# Verified against manuscript sample counts:
#   po_phase_code 2 → Convite (sealed-bid); 3 → Pregão (electronic auction)
PHASE_CONVITE <- 2L
PHASE_PREGAO  <- 3L

# ---- Regression helpers ----------------------------------------------------

#' Run 4 specifications for one DV (Equation 2 in manuscript)
#' @param dv character: dependent variable name
#' @param data data.table: prepared dataset (losers subsample, pre-filtered to winners)
#' @param price_only logical: if TRUE, further filter to valid price observations
#' @return named list of 4 fixest models
run_losers_4 <- function(dv, data, price_only = FALSE) {
  dt <- copy(data)
  if (price_only) dt <- dt[!is.na(lneg_price)]

  models <- list()

  # (1) General: item + year FE, no PBU FE
  # Only `convite` dummy needed — `pregao` is omitted reference category
  # (sample restricted to convite + pregão, so they sum to 1)
  models[["general"]] <- feols(
    as.formula(paste0(dv, " ~ losers + convite | item_f + year_f")),
    data = dt, cluster = ~item_f, fixef.rm = "none"
  )

  # (2) General + PBU FE
  models[["general_pbu"]] <- feols(
    as.formula(paste0(dv, " ~ losers + convite | item_f + year_f + pbu_f")),
    data = dt, cluster = ~item_f, fixef.rm = "none"
  )

  # (3) Pregão only (with PBU FE)
  models[["pregao"]] <- feols(
    as.formula(paste0(dv, " ~ losers | item_f + year_f + pbu_f")),
    data = dt[pregao == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  # (4) Convite only (with PBU FE)
  models[["convite"]] <- feols(
    as.formula(paste0(dv, " ~ losers | item_f + year_f + pbu_f")),
    data = dt[convite == 1L], cluster = ~item_f, fixef.rm = "none"
  )

  models
}

# ---- Formatting helpers ----------------------------------------------------
pfmt <- function(x, d = 4) formatC(x, format = "f", digits = d, big.mark = ",")
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
