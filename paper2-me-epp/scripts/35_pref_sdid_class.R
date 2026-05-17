# ============================================================================
# Paper 2 — SDID on log(p_ref) with class-level controls (Arkhangelsky et al. 2021)
#
# STATUS: ABANDONED 2026-05-17. Estimates NOT used in paper.
#
# Why dropped:
#   1. Balanced-panel requirement eliminated 75% of control classes (504 -> 126),
#      leaving a non-representative subset of "permanent" classes.
#   2. NP point estimate (+0.0926) had the opposite sign from TWFE (-0.0273) and
#      BJS (-0.1048), inconsistent with the rest of the evidence.
#   3. Jackknife SE failed (returned NA) in both NP and PH runs.
#   4. The synthdid method is designed for state-year-style balanced panels;
#      forcing it on class-month panels in this regime is outside its design.
#
# The paper instead reports TWFE + CS + BJS in Table OA-14, with the Q1 placebo
# (Section 6.6) as the substantive defense against p_ref endogeneity. Script
# preserved as record of attempted analysis.
#
# Treated: Group 65 NP-subset and PH-subset (run separately, single composite unit)
# Controls: ALL class_alt within the 76 never-treated codigogrupos (~500+ units)
# Outcome: monthly average log(preco_ref) per unit
# ============================================================================

suppressPackageStartupMessages({
  library(data.table); library(arrow); library(synthdid); library(ggplot2)
})

PROJ_ROOT <- getwd()
DATA_PARQ <- file.path(PROJ_ROOT, "data/processed/paper2_me_epp.parquet")
stopifnot(file.exists(DATA_PARQ))
V8_VAL <- file.path(PROJ_ROOT, "v8-jpube/output/values.tex")

TREAT_DATE <- 698L
WIN_18M <- c(680L, 715L)
PHARMA_CLASS <- 6531L

setDTthreads(min(parallel::detectCores(logical = FALSE), 12L))
set.seed(42)

cat("=== SDID on log(p_ref): class-level controls ===\n\n")

# ---- Load and window restriction ------------------------------------------
dt <- as.data.table(read_parquet(DATA_PARQ,
  col_select = c("codigogrupo","class_alt","data_oc_numb",
                 "lpreco_ref","preco_ref")))
dt <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
dt[, g65 := as.integer(codigogrupo == "65")]
dt[, pharma := as.integer(!is.na(class_alt) & class_alt == PHARMA_CLASS)]
dt <- dt[!is.na(lpreco_ref) & is.finite(lpreco_ref) & !is.na(class_alt)]
cat(sprintf("Window rows (lpreco_ref valid): %s\n", format(nrow(dt), big.mark=",")))
cat(sprintf("Distinct codigogrupos: %d\n", uniqueN(dt$codigogrupo)))
cat(sprintf("Distinct class_alt: %d\n", uniqueN(dt$class_alt)))

# Identify control classes (within never-treated codigogrupos, i.e., not g65)
ctrl_classes <- dt[g65 == 0L, unique(class_alt)]
cat(sprintf("Control classes (within never-treated groups): %d\n", length(ctrl_classes)))

# ---- Build panel for SDID -------------------------------------------------
# Unit definitions:
#  - For NP run: treated unit = "G65_NP" (one composite), controls = all ctrl_classes
#  - For PH run: treated unit = "G65_PH" (one composite), controls = all ctrl_classes
# Time: data_oc_numb
# Outcome: mean(lpreco_ref) per (unit, time)

build_panel <- function(label, treat_subset) {
  # treat_subset is a data.table subset of g65 items for this run (NP or PH)
  d_treat <- treat_subset[, .(unit = label, time = data_oc_numb, y = lpreco_ref)]
  d_treat_agg <- d_treat[, .(y = mean(y, na.rm = TRUE), n = .N), by = .(unit, time)]
  d_ctrl <- dt[g65 == 0L, .(unit = paste0("C_", class_alt), time = data_oc_numb, y = lpreco_ref)]
  d_ctrl_agg <- d_ctrl[, .(y = mean(y, na.rm = TRUE), n = .N), by = .(unit, time)]
  panel <- rbind(d_treat_agg, d_ctrl_agg)

  # Balance: keep only units present in ALL time periods (SDID needs balanced)
  all_times <- sort(unique(panel$time))
  n_times <- length(all_times)
  units_full <- panel[, .(n_obs = .N), by = unit][n_obs == n_times, unit]
  panel <- panel[unit %in% units_full]
  cat(sprintf("  [%s] Balanced panel: %d units x %d months (= %d cells)\n",
              label, length(units_full), n_times, nrow(panel)))
  cat(sprintf("  [%s] Treated %s, controls = %d classes\n",
              label, label, length(units_full) - 1L))

  # synthdid needs: Y = unit x time matrix, N0 = #controls, T0 = #pre-periods
  # Ordering: controls first, then treated unit at the end
  panel[, unit := factor(unit, levels = c(setdiff(units_full, label), label))]
  panel <- panel[order(unit, time)]
  Y <- as.matrix(dcast(panel, unit ~ time, value.var = "y"), rownames = "unit")
  Y <- Y[, -1, drop = FALSE]  # drop the unit-name column
  storage.mode(Y) <- "numeric"
  N0 <- length(units_full) - 1L  # number of controls
  T0 <- sum(all_times < TREAT_DATE)  # pre-treatment periods
  list(Y = Y, N0 = N0, T0 = T0, panel = panel, all_times = all_times)
}

run_sdid <- function(label, subset_data) {
  panel_obj <- build_panel(label, subset_data)
  if (nrow(panel_obj$Y) < 5) {
    cat(sprintf("  [%s] insufficient units after balancing\n", label))
    return(list(est = NA_real_, se = NA_real_, panel_obj = panel_obj))
  }
  fit <- synthdid::synthdid_estimate(panel_obj$Y, panel_obj$N0, panel_obj$T0)
  est <- as.numeric(fit)
  # Jackknife SE recommended for SDID
  se <- tryCatch(sqrt(synthdid::vcov.synthdid_estimate(fit, method = "jackknife")),
                 error = function(e) NA_real_)
  cat(sprintf("  [%s] SDID estimate = %.4f (SE %.4f)\n", label, est, se))
  list(est = est, se = se, fit = fit, panel_obj = panel_obj)
}

# ---- Run NP -----------------------------------------------------------------
cat("\n--- NP (Group 65 non-pharmaceutical) ---\n")
dt_np_treat <- dt[g65 == 1L & pharma == 0L]
np <- run_sdid("G65_NP", dt_np_treat)

# ---- Run PH -----------------------------------------------------------------
cat("\n--- PH (Group 65 pharmaceutical) ---\n")
dt_ph_treat <- dt[g65 == 1L & pharma == 1L]
ph <- run_sdid("G65_PH", dt_ph_treat)

# ---- Write macros to values.tex --------------------------------------------
cat("\n[OUT] Appending SDID macros to", V8_VAL, "\n")
f4 <- function(x) ifelse(is.na(x), "NA", sprintf("%.4f", x))

macros <- c(
  "",
  "% ==========================================================================",
  "% SDID on log(p_ref) with class-level controls (script 35, 2026-05-17)",
  "% Treated: Group 65 NP / PH composite; Controls: all class_alt in never-treated groups",
  "% ==========================================================================",
  paste0("\\providecommand{\\pRefDidSdidEstNp}{}\\renewcommand{\\pRefDidSdidEstNp}{", f4(np$est), "}"),
  paste0("\\providecommand{\\pRefDidSdidSeNp}{}\\renewcommand{\\pRefDidSdidSeNp}{",   f4(np$se),  "}"),
  paste0("\\providecommand{\\pRefDidSdidEstPh}{}\\renewcommand{\\pRefDidSdidEstPh}{", f4(ph$est), "}"),
  paste0("\\providecommand{\\pRefDidSdidSePh}{}\\renewcommand{\\pRefDidSdidSePh}{",   f4(ph$se),  "}"),
  ""
)

existing <- if (file.exists(V8_VAL)) readLines(V8_VAL) else character()
hdr <- "% SDID on log(p_ref)"
start_idx <- grep(hdr, existing, fixed = TRUE)
if (length(start_idx) > 0) {
  start <- max(1L, start_idx[1] - 2L)
  existing <- existing[1:(start - 1L)]
}
writeLines(c(existing, macros), V8_VAL)
cat("  Wrote", length(macros), "lines\n")

# ---- Summary ----------------------------------------------------------------
cat("\n========== SUMMARY ==========\n")
cat(sprintf("SDID class-level on log(p_ref):\n"))
cat(sprintf("  NP: %s (SE %s)\n", f4(np$est), f4(np$se)))
cat(sprintf("  PH: %s (SE %s)\n", f4(ph$est), f4(ph$se)))
cat("\nFor reference (from script 32):\n")
cat("  TWFE  NP: -0.0273 (0.0105)   PH: -0.0325 (0.0124)\n")
cat("  BJS   NP: -0.1048 (0.0259)   PH: -0.0598 (0.0201)\n")
cat("  CS    NP:  0.1208 (0.3129)   PH: -0.2057 (0.3062)\n")
cat("=============================\n")
