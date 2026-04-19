# ============================================================================
# 19_cs2021.R — Callaway & Sant'Anna (2021) robustness for the main DiDiR
# ============================================================================
# Re-estimates the headline results by reframing the design as staggered
# DiD with group 65 as the single treated cohort (first treated March 2018 =
# data_oc_numb 698) and the other 76 product groups as never-treated within
# the sample window. CS2021 with the never-treated comparison group therefore
# applies directly and delivers identification under standard parallel-trends
# assumptions without relying on already-treated comparisons.
#
# Outcomes are group x month means of log price, log firms, log bids, and
# distance, on the 18-month window. Each CS2021 model produces a group-time
# ATT (single G here, multiple t), an overall ATT, and a dynamic event study.
# Signs are flipped relative to the DDR/DiDiR coefficient because the CS2021
# treatment is "ME/EPP regime active" (post-2018 for g65), whereas g65 x Pre
# measures the inverse (open-tender period for g65).
#
# Outputs:
#   - /tmp/p2_cs2021.rds
#   - output/tables/tab_cs2021.tex
#   - output/tables/diag_cs2021.txt
#   - output/figures/fig_cs2021_event.pdf
# ============================================================================

cat("=== 19_cs2021.R: Callaway & Sant'Anna robustness ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages(library(did))

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

# ---- Group x month panel ---------------------------------------------------
# Restrict to 18-month window for comparability with headline DiDiR.
dt_win <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]

# Completed-only aggregates for price and distance; all items for firms/bids.
agg_c <- dt_win[oc_item_status == 1L,
                .(y_price = mean(lpreco_final, na.rm = TRUE),
                  y_dist  = mean(dist1,        na.rm = TRUE),
                  n_completed = .N),
                by = .(codigogrupo, data_oc_numb)]
agg_a <- dt_win[, .(y_firms = mean(lnum_firms, na.rm = TRUE),
                    y_bids  = mean(lnum_bids,  na.rm = TRUE),
                    n_all   = .N),
                by = .(codigogrupo, data_oc_numb)]
setkey(agg_c, codigogrupo, data_oc_numb)
setkey(agg_a, codigogrupo, data_oc_numb)
panel <- merge(agg_c, agg_a, all = TRUE, by = c("codigogrupo", "data_oc_numb"))

# Drop cells with no completed items (NA on price/dist)
# Keep all cells for firms/bids (always observed)
# CS2021 requires balanced panel per unit; fill missing with NA is ok

panel[, G := as.numeric(fifelse(codigogrupo == "65", TREAT_DATE, 0L))]
panel[, id_grp := as.integer(factor(codigogrupo))]
setorder(panel, id_grp, data_oc_numb)

n_groups <- uniqueN(panel$codigogrupo)
n_times  <- uniqueN(panel$data_oc_numb)
cat(sprintf("  Panel: %d groups x %d months = %d cells (observed: %d)\n",
            n_groups, n_times, n_groups * n_times, nrow(panel)))
cat(sprintf("  Treated group (g65): gname = %d\n", TREAT_DATE))
cat(sprintf("  Never-treated controls: %d groups\n", n_groups - 1L))

# Balance panel for CS2021 (fill missing month-group cells with NA)
full_grid <- CJ(codigogrupo = unique(panel$codigogrupo),
                data_oc_numb = seq(WIN_18M[1], WIN_18M[2]))
setkey(full_grid, codigogrupo, data_oc_numb)
setkey(panel,    codigogrupo, data_oc_numb)
panel_b <- panel[full_grid]
panel_b[, G := as.numeric(fifelse(codigogrupo == "65", TREAT_DATE, 0L))]
panel_b[, id_grp := as.integer(factor(codigogrupo))]

cat(sprintf("  Balanced panel: %s rows\n", pfmt_int(nrow(panel_b))))

# ---- Run CS2021 per outcome ------------------------------------------------
run_cs <- function(yname) {
  cat(sprintf("    %s: running att_gt...\n", yname))
  res <- tryCatch(
    att_gt(
      yname         = yname,
      tname         = "data_oc_numb",
      idname        = "id_grp",
      gname         = "G",
      data          = as.data.frame(panel_b),
      control_group = "nevertreated",
      est_method    = "reg",
      panel         = TRUE,
      clustervars   = NULL,
      bstrap        = TRUE,
      cband         = FALSE,
      biters        = 999
    ),
    error = function(e) {
      cat("      att_gt failed:", conditionMessage(e), "\n")
      NULL
    })
  if (is.null(res)) return(NULL)
  agg_overall <- aggte(res, type = "group", na.rm = TRUE)
  agg_dynamic <- aggte(res, type = "dynamic", na.rm = TRUE, min_e = -10, max_e = 17)
  list(att_gt = res, overall = agg_overall, dynamic = agg_dynamic)
}

cat("  Fitting CS2021 models...\n")
cs_price <- run_cs("y_price")
cs_firms <- run_cs("y_firms")
cs_bids  <- run_cs("y_bids")
cs_dist  <- run_cs("y_dist")

saveRDS(list(price = cs_price, firms = cs_firms,
             bids = cs_bids, dist = cs_dist,
             panel = panel_b),
        "/tmp/p2_cs2021.rds")

# ---- Diagnostic -----------------------------------------------------------
cat("  Overall ATT by outcome:\n")
format_att <- function(res) {
  if (is.null(res)) return("failed")
  a  <- res$overall$overall.att
  se <- res$overall$overall.se
  sprintf("%.4f (%.4f)", a, se)
}

diag_lines <- c(
  "=== CS2021 staggered-DiD diagnostic ===",
  sprintf("Window: [%d, %d] (18-month)", WIN_18M[1], WIN_18M[2]),
  sprintf("Balanced panel: %s group-month cells (%d groups x %d months)",
          pfmt_int(nrow(panel_b)), n_groups, n_times),
  sprintf("Treated: codigogrupo == '65' at t = %d (March 2018)",
          TREAT_DATE),
  "",
  "-- Overall ATT (group=65, averaged over post-treatment times) --",
  sprintf("Log price    : %s", format_att(cs_price)),
  sprintf("Log firms    : %s", format_att(cs_firms)),
  sprintf("Log bids     : %s", format_att(cs_bids)),
  sprintf("Distance (km): %s", format_att(cs_dist)),
  "",
  "Note: CS2021 ATT = treatment effect for g65 under ME/EPP-only regime.",
  "Sign inverts relative to the DDR g65 x Pre coefficient (which measured",
  "the open-regime effect in pre-period).",
  "Magnitudes should roughly match up to aggregation and panel balance."
)
writeLines(diag_lines, file.path(OUT_TAB, "diag_cs2021.txt"))
cat(paste(diag_lines, collapse = "\n"), "\n")

# ---- LaTeX table: overall ATT side-by-side with DDR estimates ------------
cat("  Writing LaTeX table...\n")

# Recover DDR headline (18m + PBU FE) for comparison — compute inline so
# this script is self-contained. One feols per outcome on the 18m window.
cat("  Fitting DDR 18m +PBU FE for comparison...\n")
ddr_tab <- list()
ddr_specs <- list(
  prices       = list(dv = "lpreco_final", completed = TRUE),
  participants = list(dv = "lnum_firms",   completed = FALSE),
  validbids    = list(dv = "lnum_bids",    completed = FALSE),
  distance     = list(dv = "dist1",        completed = TRUE)
)
for (key in names(ddr_specs)) {
  sp <- ddr_specs[[key]]
  d <- dt_win
  if (sp$completed) d <- d[oc_item_status == 1L]
  fml <- as.formula(sprintf("%s ~ g65_pre + convite + lquantidade | item_alt + pbu_alt",
                            sp$dv))
  mm <- suppressMessages(feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none"))
  ddr_tab[[key]] <- list(
    b  = coef(mm)["g65_pre"],
    se = sqrt(vcov(mm)["g65_pre", "g65_pre"]))
}

row_cells <- function(cs_obj, ddr_key) {
  cs_b  <- if (!is.null(cs_obj)) cs_obj$overall$overall.att else NA
  cs_se <- if (!is.null(cs_obj)) cs_obj$overall$overall.se  else NA
  ddr_b  <- if (!is.null(ddr_tab[[ddr_key]])) ddr_tab[[ddr_key]]$b  else NA
  ddr_se <- if (!is.null(ddr_tab[[ddr_key]])) ddr_tab[[ddr_key]]$se else NA
  # Flip sign of DDR for side-by-side comparison (CS2021 estimates post, DDR pre)
  ddr_b_flip <- -ddr_b
  fmt_pair <- function(b, se) {
    if (is.na(b)) return(c("--", "--"))
    p <- 2 * pnorm(-abs(b / se))
    c(paste0(pfmt(b, 4), pstars(p)), paste0("(", pfmt(se, 4), ")"))
  }
  list(cs = fmt_pair(cs_b, cs_se),
       ddr = fmt_pair(ddr_b_flip, ddr_se))
}

cells <- list(
  list(label = "Log prices",    cs = cs_price, key = "prices"),
  list(label = "Log firms",     cs = cs_firms, key = "participants"),
  list(label = "Log bids",      cs = cs_bids,  key = "validbids"),
  list(label = "Distance (km)", cs = cs_dist,  key = "distance")
)

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Staggered DiD (Callaway \\& Sant'Anna 2021) vs.~DiDiR Headline}",
  "\\label{tab:cs2021}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & CS2021 ATT & DDR (sign-flipped) \\\\",
  " & (group $\\times$ month panel) & (18m + PBU FE) \\\\",
  "\\midrule"
)

for (r in cells) {
  rc <- row_cells(r$cs, r$key)
  lines <- c(lines,
    sprintf("%s & %s & %s \\\\", r$label, rc$cs[1], rc$ddr[1]),
    sprintf(" & %s & %s \\\\",            rc$cs[2], rc$ddr[2]))
}

lines <- c(lines,
  "\\midrule",
  sprintf("Groups (never-treated / treated) & \\multicolumn{2}{c}{%d / 1} \\\\",
          n_groups - 1L),
  sprintf("Months (panel) & \\multicolumn{2}{c}{%d} \\\\", n_times),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} CS2021 column reports the overall Average Treatment",
  "Effect on the Treated (ATT) from \\texttt{did::att\\_gt} followed by",
  "\\texttt{aggte(type=\"group\")}, estimated on a codigogrupo $\\times$ month",
  "panel of means (completed items for price and distance; all items for firms",
  sprintf("and bids). Control group: never-treated (%d product groups never subject to",
          n_groups - 1L),
  "a regime change within the sample window; they were already under ME/EPP",
  "rules pre-2014). Standard errors from multiplier bootstrap (999 iterations).",
  "DDR column reproduces the 18-month +PBU FE coefficient on $g65 \\times Pre$",
  "from Table~\\ref{tab:prices} and analogous tables, with the sign flipped",
  "because the DDR parameter measures the open-tender period (inverse of the",
  "ME/EPP regime that CS2021 treats as the policy). Magnitudes should coincide",
  "up to aggregation noise and estimator differences.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)
writeLines(lines, file.path(OUT_TAB, "tab_cs2021.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_cs2021.tex"), "\n")

# ---- Dynamic event study figure (log price) -------------------------------
if (!is.null(cs_price) && !is.null(cs_price$dynamic)) {
  dyn <- cs_price$dynamic
  df <- data.frame(
    e    = dyn$egt,
    att  = dyn$att.egt,
    se   = dyn$se.egt
  )
  df$lo <- df$att - 1.96 * df$se
  df$hi <- df$att + 1.96 * df$se

  p <- ggplot(df, aes(x = e, y = att)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.3, color = "black") +
    geom_point(size = 2, color = "black") +
    labs(x = "Months since policy switch (g65 $\\to$ ME/EPP-only)",
         y = expression(paste("CS2021 dynamic ATT: log price"))) +
    theme_pub()

  save_pub(p, "fig_cs2021_event.pdf")
}

cat("  Done.\n")
