# ============================================================================
# 24_pharma.R — CMED-regulated pharmaceuticals vs non-pharma medical supplies
# ============================================================================
# Decomposes Group 65 into two economically distinct subcategories:
#   - class_alt == 6531: medications (pharmaceuticals), subject to CMED
#     (Camara de Regulacao do Mercado de Medicamentos) price regulation
#   - other Group-65 classes: non-pharma medical supplies, no price cap
#
# CMED sets annual list-price ceilings for medications. If those ceilings bind,
# the ME/EPP preference cannot raise prices beyond the cap, so the pharma
# price effect should be SMALLER than in the unregulated segment. If the cap
# is slack (actual procurement prices below the ceiling), the pharma segment
# can behave like any unregulated oligopoly and the effect can be larger.
# The existing Extensions passage reports a 67% larger pharma effect,
# consistent with the latter.
#
# This script formalizes the comparison with side-by-side DiDs, an
# interaction test for the difference, and a split of the fiscal cost.
#
# Outputs:
#   - /tmp/p2_pharma.rds
#   - output/tables/tab_pharma.tex
#   - output/tables/diag_pharma.txt
# ============================================================================

cat("=== 24_pharma.R: Pharma (CMED) vs non-pharma decomposition ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

PHARMA_CLASS <- 6531L
dt[, pharma := as.integer(!is.na(class_alt) & class_alt == PHARMA_CLASS)]

dt_win <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
dt_c   <- dt_win[oc_item_status == 1L]

n_g65 <- dt_win[g65 == 1L, .N]
n_pharma <- dt_win[g65 == 1L & pharma == 1L, .N]
n_nonph  <- dt_win[g65 == 1L & pharma == 0L, .N]
cat(sprintf("  Group-65 sample (18m): %s obs; pharma=%s (%.1f%%), non-pharma=%s\n",
            pfmt_int(n_g65), pfmt_int(n_pharma),
            100 * n_pharma / n_g65, pfmt_int(n_nonph)))

# ---- Split-sample DiDs for each outcome -----------------------------------
run_split <- function(dv, sub_mask, completed = FALSE) {
  d <- if (completed) dt_c else dt_win
  d <- d[eval(sub_mask)]
  if (nrow(d) < 500L) return(NULL)
  fml <- as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt + pbu_alt"))
  tryCatch(
    feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none"),
    error = function(e) NULL)
}

outcomes <- list(
  list(dv = "lpreco_final", label = "Log prices",    completed = TRUE),
  list(dv = "lnum_firms",   label = "Log firms",     completed = FALSE),
  list(dv = "lnum_bids",    label = "Log bids",      completed = FALSE),
  list(dv = "dist1",        label = "Distance (km)", completed = TRUE)
)

cat("  Running split-sample DiDs (pharma vs non-pharma)...\n")
mods_pharma <- list()
mods_nonph  <- list()
mods_int    <- list()
for (o in outcomes) {
  # Split samples
  mods_pharma[[o$dv]] <- run_split(o$dv, quote(pharma == 1L), o$completed)
  mods_nonph[[o$dv]]  <- run_split(o$dv,
    quote((g65 == 0L) | (g65 == 1L & pharma == 0L)), o$completed)
  # Interaction within full 18m sample: treat = g65_pre; differential = g65_pre:pharma
  d <- if (o$completed) dt_c else dt_win
  fml <- as.formula(paste0(o$dv,
    " ~ g65_pre + g65_pre:pharma + convite + lquantidade | item_alt + pbu_alt"))
  mods_int[[o$dv]] <- suppressMessages(
    feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none"))
  cat(sprintf("    %-16s done\n", o$dv))
}

saveRDS(list(pharma = mods_pharma, nonph = mods_nonph, int = mods_int),
        "/tmp/p2_pharma.rds")

# ---- Fiscal cost split ---------------------------------------------------
V_pharma <- dt[g65 == 1L & pharma == 1L & data_oc_numb < TREAT_DATE &
               oc_item_status == 1L & !is.na(valor_total_final),
               sum(valor_total_final, na.rm = TRUE)]
V_nonph <- dt[g65 == 1L & pharma == 0L & data_oc_numb < TREAT_DATE &
              oc_item_status == 1L & !is.na(valor_total_final),
              sum(valor_total_final, na.rm = TRUE)]

b_ph <- coef(mods_pharma[["lpreco_final"]])["g65_pre"]
b_np <- coef(mods_nonph[["lpreco_final"]])["g65_pre"]

cost_ph <- V_pharma * abs(exp(b_ph) - 1)
cost_np <- V_nonph  * abs(exp(b_np) - 1)
cost_total <- cost_ph + cost_np

cat(sprintf("\n  Fiscal cost decomposition:\n"))
cat(sprintf("    Pharma (class 6531):    V = R$%.1fM, beta = %+.4f, cost = R$%.1fM\n",
            V_pharma / 1e6, b_ph, cost_ph / 1e6))
cat(sprintf("    Non-pharma (other 65):  V = R$%.1fM, beta = %+.4f, cost = R$%.1fM\n",
            V_nonph / 1e6, b_np, cost_np / 1e6))
cat(sprintf("    Total:                              cost = R$%.1fM (%.0f%% pharma)\n",
            cost_total / 1e6, 100 * cost_ph / cost_total))

# ---- LaTeX table ---------------------------------------------------------
cat("  Writing LaTeX table...\n")

fmt_coef <- function(mod, var = "g65_pre", d = 4) {
  if (is.null(mod)) return(c("--", "--"))
  if (!(var %in% names(coef(mod)))) return(c("--", "--"))
  b  <- coef(mod)[var]
  se <- sqrt(vcov(mod)[var, var])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d), pstars(p)), paste0("(", pfmt(se, d), ")"))
}

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Pharmaceuticals (CMED-Regulated) vs.~Non-Pharma Medical Supplies}",
  "\\label{tab:pharma}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  " & Pharma (class 6531) & Non-pharma (other 65) & Interaction \\\\",
  " & split sample & split sample & full sample \\\\",
  "\\midrule"
)

for (o in outcomes) {
  dv <- o$dv; lbl <- o$label
  c_ph <- fmt_coef(mods_pharma[[dv]], "g65_pre")
  c_np <- fmt_coef(mods_nonph[[dv]],  "g65_pre")
  c_i1 <- fmt_coef(mods_int[[dv]],    "g65_pre")
  c_i2 <- fmt_coef(mods_int[[dv]],    "g65_pre:pharma")
  # Put both interaction coefs in the third column as a stacked cell
  lines <- c(lines,
    sprintf("\\multicolumn{4}{l}{\\textit{%s}} \\\\", lbl),
    sprintf("$g65 \\times Pre$                 & %s & %s & %s \\\\",
            c_ph[1], c_np[1], c_i1[1]),
    sprintf("                                  & %s & %s & %s \\\\",
            c_ph[2], c_np[2], c_i1[2]),
    sprintf("$g65 \\times Pre \\times$ Pharma   & -- & -- & %s \\\\",
            c_i2[1]),
    sprintf("                                  & -- & -- & %s \\\\",
            c_i2[2]),
    "\\addlinespace"
  )
}

# N row
obs_ph <- sapply(outcomes, function(o)
  if (!is.null(mods_pharma[[o$dv]])) pfmt_int(mods_pharma[[o$dv]]$nobs) else "--")
obs_np <- sapply(outcomes, function(o)
  if (!is.null(mods_nonph[[o$dv]])) pfmt_int(mods_nonph[[o$dv]]$nobs) else "--")
obs_int <- sapply(outcomes, function(o)
  if (!is.null(mods_int[[o$dv]])) pfmt_int(mods_int[[o$dv]]$nobs) else "--")

# Pick log-price row for N display (most restrictive spec)
lines <- c(lines,
  "\\midrule",
  sprintf("Obs. (Log prices) & %s & %s & %s \\\\", obs_ph[1], obs_np[1], obs_int[1]),
  sprintf("Obs. (Log firms)  & %s & %s & %s \\\\", obs_ph[2], obs_np[2], obs_int[2]),
  sprintf("Obs. (Log bids)   & %s & %s & %s \\\\", obs_ph[3], obs_np[3], obs_int[3]),
  sprintf("Obs. (Distance)   & %s & %s & %s \\\\", obs_ph[4], obs_np[4], obs_int[4]),
  "Item FE + PBU FE & YES & YES & YES \\\\",
  "\\midrule",
  "\\multicolumn{4}{l}{\\textit{Implied fiscal cost (pre-period, nominal)}} \\\\",
  sprintf("Value of Group-65 procurement (R\\$M) & %.1f & %.1f & %.1f \\\\",
          V_pharma / 1e6, V_nonph / 1e6, (V_pharma + V_nonph) / 1e6),
  sprintf("Fiscal cost (R\\$M) & %.1f & %.1f & %.1f \\\\",
          cost_ph / 1e6, cost_np / 1e6, cost_total / 1e6),
  sprintf("Share of total cost & %.0f\\%% & %.0f\\%% & 100\\%% \\\\",
          100 * cost_ph / cost_total, 100 * cost_np / cost_total),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 18-month window; log prices and distance conditioned on completion.",
  "Class 6531 identifies medications (Group 65's pharmaceutical subcategory)",
  "subject to \\emph{CMED} (C\\^amara de Regula\\c{c}\\~ao do Mercado de Medicamentos)",
  "list-price ceilings. Remaining Group-65 classes (non-pharma medical supplies) are",
  "unregulated. The first two columns estimate the headline DiD separately within",
  "each subsample. The third column estimates the interaction specification",
  "$y = \\eta_i + \\beta_1 (g65 \\times Pre) + \\beta_2 (g65 \\times Pre \\times Pharma) + x\\delta$",
  "where $\\beta_2$ is the differential pharma effect relative to non-pharma and the main",
  "pharma dummy is absorbed by item FE. SEs clustered at the item level.",
  "The implied fiscal cost applies the class-specific $\\hat\\beta$ on log prices to the",
  "pre-period Group-65 procurement value within that class.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_pharma.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_pharma.tex"), "\n")

# ---- Diagnostic ---------------------------------------------------------
diag_lines <- c(
  "=== Pharma vs non-pharma decomposition diagnostic ===",
  sprintf("Pharma class: %d (medications, CMED-regulated)", PHARMA_CLASS),
  sprintf("Group-65 composition (18m): %s pharma (%.1f%%), %s non-pharma",
          pfmt_int(n_pharma), 100 * n_pharma / n_g65, pfmt_int(n_nonph)),
  "",
  "DiD price coefficients (split sample):",
  sprintf("  Pharma:     %+.4f (SE %.4f)", b_ph,
          sqrt(vcov(mods_pharma$lpreco_final)["g65_pre", "g65_pre"])),
  sprintf("  Non-pharma: %+.4f (SE %.4f)", b_np,
          sqrt(vcov(mods_nonph$lpreco_final)["g65_pre", "g65_pre"])),
  sprintf("  Differential from interaction: %+.4f (SE %.4f)",
          coef(mods_int$lpreco_final)["g65_pre:pharma"],
          sqrt(vcov(mods_int$lpreco_final)["g65_pre:pharma", "g65_pre:pharma"])),
  "",
  sprintf("Pharma value: R$%.1fM (%.0f%% of total Group-65 pre-period spending)",
          V_pharma / 1e6, 100 * V_pharma / (V_pharma + V_nonph)),
  sprintf("Fiscal cost: pharma R$%.1fM + non-pharma R$%.1fM = total R$%.1fM",
          cost_ph / 1e6, cost_np / 1e6, cost_total / 1e6)
)
writeLines(diag_lines, file.path(OUT_TAB, "diag_pharma.txt"))
cat("  Done.\n")
