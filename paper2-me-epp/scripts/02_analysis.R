# ============================================================================
# 02_analysis.R — DiDiR regressions and event studies
# ============================================================================

cat("=== 02_analysis.R: Regressions ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data ------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

# ---- Main DiDiR regressions (Equation 1) -----------------------------------
# 4 outcomes x (3 windows x 2 specs) = 24 models

cat("  Running prices regressions (completed items)...\n")
m_prices <- run_didir_6("lpreco_final", dt, completed = TRUE)

cat("  Running participants regressions (all items)...\n")
m_participants <- run_didir_6("lnum_firms", dt, completed = FALSE)

cat("  Running valid bids regressions (all items)...\n")
m_validbids <- run_didir_6("lnum_bids", dt, completed = FALSE)

cat("  Running distance regressions (completed items)...\n")
m_distance <- run_didir_6("dist1", dt, completed = TRUE)

# ---- Event studies (Equation 2) --------------------------------------------
# 4 outcomes x 1 model each, on 18-month window

run_event_study <- function(dv, data, completed = FALSE) {
  es_data <- data[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
  if (completed) es_data <- es_data[oc_item_status == 1L]
  # Drop observations outside semester boundaries
  es_data <- es_data[!is.na(semester_f)]

  fml <- as.formula(paste0(dv, " ~ i(semester_f, g65, ref = 4) | grupo_f + semester_f"))
  feols(fml, data = es_data, cluster = ~grupo_f)
}

cat("  Running event study: log prices...\n")
es_prices <- run_event_study("lpreco_final", dt, completed = TRUE)

cat("  Running event study: distance...\n")
es_distance <- run_event_study("dist1", dt, completed = TRUE)

cat("  Running event study: num firms...\n")
es_numfirms <- run_event_study("lnum_firms", dt, completed = FALSE)

cat("  Running event study: num bids...\n")
es_numbids <- run_event_study("lnum_bids", dt, completed = FALSE)

# ---- Save all models -------------------------------------------------------
models <- list(
  prices       = m_prices,
  participants = m_participants,
  validbids    = m_validbids,
  distance     = m_distance,
  es_prices    = es_prices,
  es_distance  = es_distance,
  es_numfirms  = es_numfirms,
  es_numbids   = es_numbids
)

models_path <- "/tmp/p2_models.rds"
saveRDS(models, models_path)
cat("  Models saved:", models_path, "\n")

# ---- Quick summary of key coefficients ------------------------------------
cat("\n  --- Key DiDiR coefficients (g65 x Pre) ---\n")
for (outcome in c("prices", "participants", "validbids", "distance")) {
  mlist <- models[[outcome]]
  cat(sprintf("  %s:\n", toupper(outcome)))
  for (mname in names(mlist)) {
    m <- mlist[[mname]]
    b  <- coef(m)["g65_pre"]
    se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
    cat(sprintf("    %s: %.4f (%.4f)\n", mname, b, se))
  }
}
