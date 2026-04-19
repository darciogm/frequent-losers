# ============================================================================
# 27_major2_controls.R — Comparator-group-validity robustness
# ============================================================================
# Responds to a reviewer concern (Major #2 of the internal referee report)
# that the 76 never-treated product groups may not satisfy parallel trends
# and that placebo pre-trends on firms/bids are significant.
#
# Three robustness specifications, side-by-side with the baseline item+month
# FE headline:
#
# (1) Headline: item + data_oc_numb FE.
# (2) + group-specific linear trends: item + data_oc_numb FE + codigogrupo[t].
# (3) Narrow control set: G65 + top-10 non-G65 groups by pre-period volume.
#
# Outputs:
#   - output/tables/tab_major2_controls.tex
#   - /tmp/p2_major2_controls.rds
# ============================================================================

cat("=== 27_major2_controls.R: Comparator-group robustness ===\n")

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  f_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(f_arg)) dirname(sub("^--file=", "", f_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages(library(fixest))
setFixest_estimation(lean = FALSE)

dt <- as.data.table(readRDS(DATA_CACHE))
dt[, t_num := as.numeric(data_oc_numb - min(data_oc_numb))]
dt[, grp_f := factor(codigogrupo)]

# Top-10 non-G65 groups by pre-period observation count
top_groups <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
                 g65 == 0L, .(.N), by = codigogrupo][order(-N)][1:10, codigogrupo]
cat("  Top-10 non-G65 control groups (by volume):",
    paste(top_groups, collapse = ", "), "\n")

outcomes <- list(
  list(dv = "lpreco_final", label = "Log prices",     completed = TRUE),
  list(dv = "lnum_firms",   label = "Log firms",      completed = FALSE),
  list(dv = "lnum_bids",    label = "Log bids",       completed = FALSE),
  list(dv = "dist1",        label = "Distance (km)",  completed = TRUE)
)

results <- list()
for (o in outcomes) {
  dv <- o$dv
  cat(sprintf("  %-16s ", dv))
  d <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
  if (o$completed) d <- d[oc_item_status == 1L]

  # (1) Headline
  m0 <- feols(as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt + data_oc_numb")),
    data = d, cluster = ~item_alt, lean = FALSE)

  # (2) + group-specific linear trends
  m1 <- feols(as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt + data_oc_numb + grp_f[t_num]")),
    data = d, cluster = ~item_alt, lean = FALSE)

  # (3) Narrow control set
  d_narrow <- d[codigogrupo == "65" | codigogrupo %in% top_groups]
  m2 <- feols(as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt + data_oc_numb")),
    data = d_narrow, cluster = ~item_alt, lean = FALSE)

  results[[dv]] <- list(headline = m0, grp_trends = m1, narrow = m2)
  cat("done\n")
}

saveRDS(results, "/tmp/p2_major2_controls.rds")

# ---- LaTeX table -----------------------------------------------------------
fmt_row <- function(m, d = 4) {
  if (is.null(m)) return(c("--", "--"))
  b  <- coef(m)["g65_pre"]
  se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d), pstars(p)), paste0("(", pfmt(se, d), ")"))
}

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Comparator-Group Robustness (18-month window)}",
  "\\label{tab:major2_controls}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  " & (1) Headline & (2) + Group trends & (3) Narrow controls \\\\",
  " & item + month FE & + codigogrupo[t] & G65 + top-10 groups \\\\",
  "\\midrule"
)

for (o in outcomes) {
  r <- results[[o$dv]]
  h <- fmt_row(r$headline); g <- fmt_row(r$grp_trends); n <- fmt_row(r$narrow)
  lines <- c(lines,
    sprintf("%s &       %s &       %s &       %s \\\\",
            o$label, h[1], g[1], n[1]),
    sprintf("                                   &  %s &  %s &  %s \\\\",
            h[2], g[2], n[2]))
}
lines <- c(lines, "\\midrule")

# N row (use price n as typical; document that firms/bids/dist use their own)
lines <- c(lines,
  sprintf("Observations (log prices) & %s & %s & %s \\\\",
          pfmt_int(results[["lpreco_final"]]$headline$nobs),
          pfmt_int(results[["lpreco_final"]]$grp_trends$nobs),
          pfmt_int(results[["lpreco_final"]]$narrow$nobs)))

lines <- c(lines,
  "Item FE & YES & YES & YES \\\\",
  "Month FE & YES & YES & YES \\\\",
  "Group-specific linear trends & NO & YES & NO \\\\",
  "Control-set restriction & None & None & Top-10 \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Each cell reports the $\\mathit{g65}\\times\\mathit{Pre}$",
  "coefficient from a DiD regression with the indicated fixed effects and",
  "controls (sealed-bid dummy and log quantity). Standard errors clustered",
  "at the item level. Column (1) is the headline specification (item and",
  "month fixed effects). Column (2) adds group-specific linear time trends",
  "($\\text{grp}_g \\times t$) to allow each of the 77 product groups to have",
  "its own pre-post-cutoff trajectory. Column (3) restricts the control set",
  "to the ten largest non-Group-65 product groups by 18-month observation",
  "count; the smaller sample is meant to focus on product groups most",
  "comparable in procurement-technology terms. The price coefficient",
  "survives both perturbations with mild attenuation; the firms and bids",
  "coefficients grow materially under group-specific linear trends,",
  "indicating that pre-trends in the headline specification attenuate",
  "rather than inflate the estimated effects. Distance remains positive",
  "and significant throughout.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_major2_controls.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_major2_controls.tex"), "\n")
cat("  Done.\n")
