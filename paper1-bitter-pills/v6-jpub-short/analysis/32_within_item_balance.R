#  32_within_item_balance.R --- Within-item balance between administrative and
#  litigated purchases on pre-determined item attributes.
#
#  Addresses Referee 2's concern that item FE absorb only *time-invariant* item
#  characteristics, so within-item composition differences (case severity,
#  dose, packaging, procurement modality) could still drive the UTG gap.
#
#  Approach: for each candidate covariate x, estimate
#    x_{i,g,t} = beta * Admin_{i,g,t} + gamma_g + epsilon
#  on the matched UTG subsample (items with both administrative and litigated
#  purchases). A small beta means that within a given item, admin and lit
#  draws are balanced on x --- supporting the "same item, different penalty"
#  reading.


suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})
setFixest_nthreads(12L)
setDTthreads(12L)

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "_macros.R"))

OUT <- "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v6-jpub-short/output"
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)

# Build UTG matched sample
cat("Loading cache...\n")
dt <- readRDS("/tmp/v4_prepared.rds")
dt <- dt[has_admin == TRUE & has_litigated == TRUE & urgent == 1]
dt <- dt[!is.na(is_admin)]
cat("  UTG sample:", nrow(dt), "obs,",
    uniqueN(dt$item), "items\n")

# Winsorise continuous covariates lightly for balance tests
winz <- function(x, p = c(0.01, 0.99)) {
  q <- quantile(x, p, na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}
dt[, bid_qty_log_w        := winz(bid_qty_log)]
dt[, bid_price_ref_log_w  := winz(bid_price_ref_log)]

# Covariates to test. "Composition" = item attributes that differ across cases
# for the *same* item; "Procurement design" = mechanism variables.
cov_list <- list(
  list(name = "SUS basic (MEDICAMENTO flag)",           var = "sus_basic",              group = "Composition"),
  list(name = "Electronic auction (preg\\~{a}o)",       var = "pregao",                 group = "Procurement"),
  list(name = "Log quantity (bulk size signal)",        var = "bid_qty_log_w",          group = "Composition"),
  list(name = "Log reference price",                    var = "bid_price_ref_log_w",    group = "Composition"),
  list(name = "Successful tender",                      var = "po_firm_winner",         group = "Outcome check"),
  list(name = "Late period (year $\\geq$ 2014)",        var = "late_period",            group = "Time"),
  list(name = "Large PBU (above-median)",               var = "large_pbu",              group = "Buyer")
)

results <- list()
for (cov in cov_list) {
  v <- cov$var
  if (!(v %in% names(dt))) {
    cat("  skipping", v, "(not in data)\n"); next
  }
  d <- dt[!is.na(get(v))]
  if (nrow(d) == 0) next
  # Drop singleton items (one obs)
  d[, n_by_item := .N, by = item_id]
  d <- d[n_by_item > 1]
  if (nrow(d) < 100) next

  frm <- as.formula(sprintf("%s ~ is_admin | item_id", v))
  m <- tryCatch(feols(frm, data = d, cluster = ~pbu_id, warn = FALSE),
                error = function(e) NULL)
  if (is.null(m)) next
  co  <- coef(m)["is_admin"]
  se  <- sqrt(diag(vcov(m)))["is_admin"]
  tval <- co / se
  p    <- 2 * pt(-abs(tval), df = m$nobs - 1)
  stars <- ifelse(p < 0.01, "***",
                  ifelse(p < 0.05, "**",
                         ifelse(p < 0.10, "*", "")))
  # Raw means for context
  m_adm <- d[is_admin == 1, mean(get(v), na.rm = TRUE)]
  m_lit <- d[is_admin == 0, mean(get(v), na.rm = TRUE)]

  results[[v]] <- data.table(
    name      = cov$name,
    group     = cov$group,
    mean_adm  = m_adm,
    mean_lit  = m_lit,
    raw_diff  = m_adm - m_lit,
    within_coef = co,
    within_se   = se,
    p_val     = p,
    stars     = stars,
    N         = m$nobs
  )
}
tab <- rbindlist(results)
print(tab)

# Emit LaTeX table
fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)
fmt_se <- function(x, d = 3) sprintf("(%s)", fmt(x, d))

cat(sprintf("\nWithin-item balance: %d covariates tested, %d items in UTG matched sample.\n",
            nrow(tab), uniqueN(dt$item)))

tex <- c(
"\\begin{table}[ht]",
"  \\centering",
"  \\caption{Within-Item Balance: Administrative vs.\\ Litigated}",
"  \\label{tab:balance_within}",
"  \\small",
"  \\begin{threeparttable}",
"  \\begin{tabular}{lccccc}",
"    \\toprule",
"    & Mean (Admin) & Mean (Lit) & Raw diff.\\ & \\multicolumn{2}{c}{Within-item diff.}\\\\",
"    \\cmidrule(lr){5-6}",
"    Covariate &  &  & (A--L) & Coef & (SE) \\\\",
"    \\midrule"
)
for (i in seq_len(nrow(tab))) {
  r <- tab[i]
  tex <- c(tex,
    sprintf("    %s & %s & %s & %s & %s$^{\\text{%s}}$ & %s \\\\",
            r$name,
            fmt(r$mean_adm),
            fmt(r$mean_lit),
            fmt(r$raw_diff),
            fmt(r$within_coef),
            r$stars,
            fmt_se(r$within_se)))
}
tex <- c(tex,
"    \\midrule",
sprintf("    Observations & \\multicolumn{5}{c}{%s}\\\\",
        formatC(nrow(dt), big.mark = "{,}", format = "d")),
sprintf("    Items        & \\multicolumn{5}{c}{%s}\\\\",
        formatC(uniqueN(dt$item), big.mark = "{,}", format = "d")),
"    \\bottomrule",
"  \\end{tabular}",
"  \\begin{tablenotes}",
"    \\small",
"    \\item \\textit{Notes:} Within-item balance between administrative",
"    ($Admin = 1$) and litigated ($Admin = 0$) urgent purchases, restricted",
"    to items with both types present. Raw difference is the unconditional",
"    mean gap. Within-item coefficient is $\\beta$ from",
"    $x_{i,g,t} = \\beta\\,\\text{Admin}_{i,g,t} + \\gamma_g + \\varepsilon_{i,g,t}$,",
"    where $\\gamma_g$ is an item fixed effect and standard errors are",
"    clustered at the PBU level. A coefficient close to zero means that,",
"    within a given item, the administrative and litigated draws are",
"    balanced on the covariate. Significance: $^{***}$ $p<0.01$,",
"    $^{**}$ $p<0.05$, $^{*}$ $p<0.10$.",
"  \\end{tablenotes}",
"  \\end{threeparttable}",
"\\end{table}",
""
)
writeLines(tex, file.path(OUT, "tables", "tab_balance_within.tex"))
cat("  Saved: tab_balance_within.tex\n")

# One-line summary for the §Empirical Strategy paragraph
sig_rows <- tab[abs(within_coef) > 0 & p_val < 0.05]
cat(sprintf("\nOf %d covariates, %d show a statistically significant (p<0.05) within-item imbalance.\n",
            nrow(tab), nrow(sig_rows)))
cat("Largest within-item coefficient (absolute):\n")
print(tab[which.max(abs(within_coef)), .(name, within_coef, within_se, p_val)])


# Emit macros for the manuscript layer.
# Predetermined-covariate set: SUS basic, late period, large PBU (composition that
# the paper claims is balanced; see EmpiricalStrategy.tex). The "modality (pregao)"
# row is a procurement-design knob, not a pre-determined covariate, so it is
# reported separately as the "4 pp gap" claim.
macros <- list()
predet_vars <- c("sus_basic", "late_period", "large_pbu")
predet_rows <- tab[match(predet_vars, names(results), nomatch = 0L)]
predet_rows <- tab[name %in% c("SUS basic (MEDICAMENTO flag)",
                                "Late period (year $\\geq$ 2014)",
                                "Large PBU (above-median)")]
if (nrow(predet_rows) > 0) {
  pmin_pre <- min(predet_rows$p_val, na.rm = TRUE)
  macros$balPMin <- bp_fmt(pmin_pre, 2)
}
modality_row <- tab[grepl("preg", name, ignore.case = TRUE)]
if (nrow(modality_row) == 1) {
  # Express within-item gap in percentage points (binary outcome scale).
  macros$balModalityPP <- bp_fmt_pp(100 * abs(modality_row$within_coef), 0)
}
if (length(macros) > 0) bp_macros_emit("32_within_item_balance", macros)

cat("\n32_within_item_balance.R complete\n")
