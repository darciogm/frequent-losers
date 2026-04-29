# ============================================================================
# 11_modal_id.R — Modal × within-convite identification (Movement 3, v13-jle)
# Paper 3: Frequent Losers in Public Procurement
#
# Reproduces tab_modal_id: FL price premium across
#   (1) Pregão (Lei 10.520/2002 — no minimum-bidder rule)
#   (2) Convite (Lei 8.666/93 Art. 22 — ≥3 valid proposals required)
#   (3) Convite, n_genuine ≥ 3 (rule slack → cover bidding voluntary)
#   (4) Convite, n_genuine < 3 (rule binds → FL entry statutorily forced)
#
# n_genuine = n_firms - losers_count (non-FL bidders per tender-item).
# Logic of the split: when ≥3 non-FL bidders show up, the convite quorum is
# already met without the FL — any FL presence is a choice (the strategic
# cell). When <3 non-FL bidders show up, FL participation is what makes the
# tender clear at all (the mechanical-compliance cell).
# ============================================================================

cat("=== 11_modal_id.R: Modal × constraint identification ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

# ---- Load cached data ------------------------------------------------------
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)
cat("  Loaded", pfmt_int(nrow(dt)), "rows\n")

dt_p <- dt[!is.na(lneg_price)]
dt_p[, n_genuine := pmax(n_firms - losers_count, 0L)]
dt_p[, conv_voluntary := as.integer(convite == 1L & n_genuine >= 3L)]
dt_p[, conv_binding   := as.integer(convite == 1L & n_genuine <  3L)]

cat("  Price sample (winners only):", pfmt_int(nrow(dt_p)), "\n")
cat("  Convite (all):              ", pfmt_int(dt_p[convite == 1L, .N]), "\n")
cat("  Convite voluntary (n>=3):   ", pfmt_int(dt_p[conv_voluntary == 1L, .N]), "\n")
cat("  Convite binding   (n<3) :   ", pfmt_int(dt_p[conv_binding   == 1L, .N]), "\n")
cat("  Pregão:                     ", pfmt_int(dt_p[pregao == 1L, .N]), "\n")

# ---- Run the 4 columns -----------------------------------------------------
# Same FE structure as Equation (2): item × year × PBU. Cluster ~item_f.

run_one <- function(d) {
  feols(lneg_price ~ losers | item_f + year_f + pbu_f,
        data = d, cluster = ~item_f, fixef.rm = "none")
}

cat("\n  Estimating four columns...\n")

m_pregao    <- run_one(dt_p[pregao   == 1L])
m_convite   <- run_one(dt_p[convite  == 1L])
m_voluntary <- run_one(dt_p[conv_voluntary == 1L])

# Binding cell may be too thin for clustered FE; report what we can.
dt_bind <- dt_p[conv_binding == 1L]
cat("  Binding cell n =", pfmt_int(nrow(dt_bind)),
    " unique items =", pfmt_int(uniqueN(dt_bind$item_f)),
    " unique pbus =", pfmt_int(uniqueN(dt_bind$pbu_f)), "\n")
m_binding <- tryCatch(
  run_one(dt_bind),
  error = function(e) { cat("  Binding cell failed:", conditionMessage(e), "\n"); NULL }
)

models <- list(pregao = m_pregao, convite = m_convite,
               voluntary = m_voluntary, binding = m_binding)

# ---- Console summary -------------------------------------------------------

cat("\n  --- losers coefficient by column ---\n")
for (k in names(models)) {
  m <- models[[k]]
  if (is.null(m)) { cat(sprintf("    %-10s: NA (model failed)\n", k)); next }
  b  <- coef(m)["losers"]
  se <- sqrt(vcov(m)["losers", "losers"])
  p  <- 2 * pnorm(-abs(b / se))
  cat(sprintf("    %-10s: %s (%s) p=%.4g  N=%s\n",
              k, pfmt(b, 4), pfmt(se, 4), p, pfmt_int(m$nobs)))
}

# ---- LaTeX writer ----------------------------------------------------------

cell_or_dash <- function(m) {
  if (is.null(m)) return(list(coef = "---", se = "(---)"))
  list(coef = coef_cell(m, "losers", 4), se = se_cell(m, "losers", 4))
}

n_or_dash <- function(m) if (is.null(m)) "---" else pfmt_int(m$nobs)

c_pregao    <- cell_or_dash(m_pregao)
c_convite   <- cell_or_dash(m_convite)
c_voluntary <- cell_or_dash(m_voluntary)
c_binding   <- cell_or_dash(m_binding)

tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{FL Price Premium by Modality and Minimum-Bidder Constraint}",
  "\\label{tab:modal_id}",
  "\\begin{threeparttable}",
  "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & (1) & (2) & (3) & (4) \\\\",
  " & Preg\\~ao & Convite & Convite & Convite \\\\",
  " & (no rule) & (all) & ($n_{\\text{gen}} \\geq 3$) & ($n_{\\text{gen}} < 3$) \\\\",
  " &  &  & voluntary & binding \\\\",
  "\\midrule",
  paste0("FL presence & ", c_pregao$coef, " & ", c_convite$coef,
         " & ", c_voluntary$coef, " & ", c_binding$coef, " \\\\"),
  paste0("            & ", c_pregao$se, " & ", c_convite$se,
         " & ", c_voluntary$se, " & ", c_binding$se, " \\\\"),
  "\\midrule",
  "Item~$\\times$~Year FE & YES & YES & YES & YES \\\\",
  "PBU FE                & YES & YES & YES & YES \\\\",
  paste0("Observations          & ",
         n_or_dash(m_pregao), " & ", n_or_dash(m_convite),
         " & ", n_or_dash(m_voluntary), " & ", n_or_dash(m_binding), " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\small",
  "\\item \\textit{Notes:} Outcome is $\\log$ negotiated price.",
  "``$n_{\\text{genuine}}$'' is the number of non-FL bidders in a tender;",
  "the convite modality (Lei~8.666 Art.~22) requires at least three",
  "bidders for the call to clear. Columns~(1)--(2) reproduce the",
  "modality-stratified specifications of Table~\\ref{tab:prices}.",
  "Columns~(3)--(4) decompose the convite estimate by whether the",
  "minimum-bidder constraint binds: when $n_{\\text{genuine}} < 3$",
  "(column~4), regulatory cover bidding is statutorily required; when",
  "$n_{\\text{genuine}} \\geq 3$ (column~3), it is voluntary. The",
  "voluntary subset isolates the strategic component of FL deployment.",
  "Standard errors clustered at the item level.",
  "$^{*}$~$p<0.10$, $^{**}$~$p<0.05$, $^{***}$~$p<0.01$.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

# Write to canonical pipeline output and to v13 manuscript dir
out_canonical <- file.path(OUT_TAB, "tab_modal_id.tex")
writeLines(tex, out_canonical)
cat("\n  Saved:", out_canonical, "\n")

v13_tab <- file.path(BASE, "work", "v13", "tables", "tab_modal_id.tex")
if (dir.exists(dirname(v13_tab))) {
  writeLines(tex, v13_tab)
  cat("  Saved:", v13_tab, "\n")
}

saveRDS(models, "/tmp/p3_modal_id_models.rds")
cat("  Saved: /tmp/p3_modal_id_models.rds\n")
cat("  Done.\n")
