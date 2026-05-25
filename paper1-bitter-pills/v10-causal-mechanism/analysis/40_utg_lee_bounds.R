# Layer 1 / Track B --- Manski-Lee bounds on the UTG coefficient.
#
# Object: bound the litigated-vs-administrative gap under selection of
# observed admin cases by the SES/SP scientific committee. The committee
# admits cases on cost-effectiveness criteria; rejected cases land in the
# litigated pool. Naively comparing litigated to admin therefore confounds
# the sanction effect with selection on item economics.
#
# Lee (2009, ReStud) trims the over-represented group from the upper or
# lower tail of the outcome distribution by the trimming proportion
# implied by the differential selection rate. Here the over-represented
# group is admin (since rejection is unobserved and admin is the
# committee-screened sample). We trim admin observations from the tails
# of log neg price within each item-by-month cell to match the litigated
# sample size in cells where both occur.
#
# Output:
#   - tab_utg_lee_bounds.tex   : Manski-Lee bound table
#   - macros: BPutgPointNaive, BPutgBoundLow, BPutgBoundHigh,
#             BPutgPointBounded (will be filled in by 41_utg_heckman.R)

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(kableExtra)
})

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
bp_set_threads(12L)

OUT  <- file.path(.this_dir, "..", "output")
LOGS <- file.path(.this_dir, "..", "logs")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(LOGS, recursive = TRUE, showWarnings = FALSE)
LOG <- file.path(LOGS, "40_utg_lee_bounds.log")
writeLines(sprintf("# 40_utg_lee_bounds | start=%s | host=%s | nproc=%d",
                   Sys.time(), Sys.info()["nodename"], parallel::detectCores()), LOG)

t0 <- Sys.time()
dt <- bp_load_cache()
bp_log_step("cache loaded", t0, LOG)

# UTG sample: urgent purchases only (admin or lit), winners with bid price.
d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 &
        !is.na(bid_price_log) & !is.na(item_id) & !is.na(year_n) & !is.na(pbu_id)]
d[, admin := as.integer(purchase_type == 1)]
if ("ym_int" %in% names(d)) {
  d[, ym := as.character(ym_int)]
} else if ("ym_f" %in% names(d)) {
  d[, ym := as.character(ym_f)]
} else {
  d[, ym := NA_character_]
}

cat("UTG sample N:", nrow(d), " (admin =", sum(d$admin), ", lit =", sum(1L - d$admin), ")\n")

# 1. Naive UTG point estimate (preferred FE: item + year + PBU)
m_naive <- feols(bid_price_log ~ admin | item_id + year_n + pbu_id,
                 data = d, cluster = ~pbu_id)
b_naive <- coef(m_naive)["admin"]
se_naive <- sqrt(diag(vcov(m_naive)))["admin"]
cat(sprintf("Naive UTG: b=%.4f (SE=%.4f) -> lit-vs-admin pct = %.2f%%\n",
            b_naive, se_naive, (exp(-b_naive) - 1) * 100))
bp_log_step("naive UTG estimated", t0, LOG)

# 2. Manski-Lee bounds.
#
# Step 1: estimate the trimming fraction p* = max(0, (n_admin - n_lit) / n_admin)
# within each item x year x PBU stratum. This is the share of admin
# observations that have no litigated counterpart in the cell --- under the
# monotone-acceptance Lee assumption, these are committee-screened cases
# that would not have appeared in the litigated counterfactual.
strata_n <- d[, .(n_admin = sum(admin == 1L), n_lit = sum(admin == 0L)),
              by = .(item_id, year_n, pbu_id)]
strata_n[, p_trim := pmax(0, (n_admin - n_lit) / pmax(n_admin, 1))]
strata_n[, p_trim := pmin(p_trim, 1)]
trim_summary <- strata_n[, .(
  cells_total = .N,
  cells_admin_excess = sum(p_trim > 0),
  mean_trim = mean(p_trim),
  max_trim = max(p_trim)
)]
cat("Trimming summary:\n"); print(trim_summary)

# Step 2: compute Lee bounds by trimming admin observations from the upper
# tail (lower bound on lit-admin gap) or lower tail (upper bound on
# lit-admin gap) within each stratum, by p_trim share.
d <- merge(d, strata_n[, .(item_id, year_n, pbu_id, p_trim)],
           by = c("item_id", "year_n", "pbu_id"), all.x = TRUE)
d[is.na(p_trim), p_trim := 0]

bp_lee_bound <- function(dt_in, side = c("lower", "upper")) {
  side <- match.arg(side)
  # Within each stratum, drop the top p_trim share of admin obs (lower bound)
  # or bottom p_trim share (upper bound). Lit obs are kept as-is.
  d_lit <- dt_in[admin == 0L]
  d_adm <- dt_in[admin == 1L]
  d_adm[, rank_w := frank(if (side == "lower") -bid_price_log else bid_price_log,
                          ties.method = "first") / .N,
        by = .(item_id, year_n, pbu_id)]
  d_adm_trim <- d_adm[rank_w > p_trim]
  d_adm_trim[, rank_w := NULL]
  d_use <- rbindlist(list(d_lit, d_adm_trim), use.names = TRUE, fill = TRUE)
  m <- feols(bid_price_log ~ admin | item_id + year_n + pbu_id,
             data = d_use, cluster = ~pbu_id)
  list(coef = coef(m)["admin"],
       se   = sqrt(diag(vcov(m)))["admin"],
       n    = nobs(m))
}

cat("Computing Lee lower bound (trim admin upper-tail)...\n")
lb <- bp_lee_bound(d, "lower"); bp_log_step("lower bound done", t0, LOG)

cat("Computing Lee upper bound (trim admin lower-tail)...\n")
ub <- bp_lee_bound(d, "upper"); bp_log_step("upper bound done", t0, LOG)

cat(sprintf("Lee bounds (admin coef): [%.4f, %.4f]\n", lb$coef, ub$coef))
cat(sprintf("Implied lit-vs-admin pct: [%.2f%%, %.2f%%]\n",
            (exp(-ub$coef) - 1) * 100, (exp(-lb$coef) - 1) * 100))

# 3. Build the output table.
res <- data.table(
  spec = c("Naive UTG (item + year + PBU FE)",
           "Lee lower bound (admin top-trim)",
           "Lee upper bound (admin bottom-trim)"),
  coef = c(b_naive, lb$coef, ub$coef),
  se   = c(se_naive, lb$se, ub$se),
  pct_lit_over_admin = c((exp(-b_naive) - 1) * 100,
                         (exp(-ub$coef) - 1) * 100,
                         (exp(-lb$coef) - 1) * 100),
  n    = c(nobs(m_naive), lb$n, ub$n)
)
print(res)

# Output table (booktabs)
ktab <- kbl(res, format = "latex", booktabs = TRUE, digits = 3,
            col.names = c("Specification", "Coef.\\ on Admin", "SE",
                          "Lit-vs-Admin (\\%)", "$N$"),
            label = "tab:utg_lee_bounds",
            caption = "Lee bounds on the under-the-gun coefficient.",
            escape = FALSE) |>
  add_header_above(c(" " = 1, "log negotiated price" = 2, "implied" = 1, " " = 1)) |>
  footnote(general = paste(
    "Trimming applied within item$\\times$year$\\times$PBU strata where the admin",
    "sample exceeds the litigated count, by the differential proportion. Lower bound",
    "trims the top of the admin price distribution; upper bound trims the bottom.",
    "Standard errors clustered at PBU level."),
    general_title = "", footnote_as_chunk = TRUE, escape = FALSE)
writeLines(ktab, file.path(OUT, "tables", "tab_utg_lee_bounds.tex"))
cat("[ok] wrote tab_utg_lee_bounds.tex\n")

bp_lee_for_strata <- function(dt_in, strata_cols) {
  d0 <- copy(dt_in)
  if ("p_trim" %in% names(d0)) d0[, p_trim := NULL]
  sn <- d0[, .(n_admin = sum(admin == 1L), n_lit = sum(admin == 0L)),
           by = strata_cols]
  sn[, p_trim := pmax(0, (n_admin - n_lit) / pmax(n_admin, 1))]
  sn[, p_trim := pmin(p_trim, 1)]
  d0 <- merge(d0, sn[, c(strata_cols, "p_trim"), with = FALSE],
              by = strata_cols, all.x = TRUE)
  d0[is.na(p_trim), p_trim := 0]

  bound_one <- function(side = c("lower", "upper")) {
    side <- match.arg(side)
    d_lit <- d0[admin == 0L]
    d_adm <- d0[admin == 1L]
    d_adm[, rank_w := frank(if (side == "lower") -bid_price_log else bid_price_log,
                            ties.method = "first") / .N,
          by = strata_cols]
    d_adm <- d_adm[rank_w > p_trim]
    d_adm[, rank_w := NULL]
    d_use <- rbindlist(list(d_lit, d_adm), use.names = TRUE, fill = TRUE)
    m <- feols(bid_price_log ~ admin | item_id + year_n + pbu_id,
               data = d_use, cluster = ~pbu_id)
    list(coef = unname(coef(m)["admin"]),
         se = unname(sqrt(diag(vcov(m)))["admin"]),
         n = nobs(m))
  }
  lower <- bound_one("lower")
  upper <- bound_one("upper")
  summ <- sn[, .(
    cells_total = .N,
    cells_admin_excess = sum(p_trim > 0),
    mean_trim = mean(p_trim),
    max_trim = max(p_trim)
  )]
  list(lower = lower, upper = upper, trim = summ)
}

alt_rows <- list()
alt_rows[[1]] <- list(label = "item $\\times$ year",
                      cols = c("item_id", "year_n"),
                      obj = bp_lee_for_strata(d, c("item_id", "year_n")))
alt_rows[[2]] <- list(label = "item $\\times$ year $\\times$ PBU",
                      cols = c("item_id", "year_n", "pbu_id"),
                      obj = list(lower = lb, upper = ub, trim = trim_summary))
if ("ym" %in% names(d) && any(!is.na(d$ym))) {
  alt_rows[[3]] <- list(label = "item $\\times$ year-month $\\times$ PBU",
                        cols = c("item_id", "ym", "pbu_id"),
                        obj = bp_lee_for_strata(d[!is.na(ym)], c("item_id", "ym", "pbu_id")))
}

alt_dt <- rbindlist(lapply(alt_rows, function(x) {
  o <- x$obj
  data.table(
    strata = x$label,
    lower_coef = o$lower$coef,
    upper_coef = o$upper$coef,
    lower_gap = (exp(-o$upper$coef) - 1) * 100,
    upper_gap = (exp(-o$lower$coef) - 1) * 100,
    trim_mean = o$trim$mean_trim * 100,
    admin_excess_cells = o$trim$cells_admin_excess
  )
}))

alt_tex <- paste0(
  "\\begin{table}[ht]\n",
  "\\centering\n",
  "\\caption{Lee bounds under alternative trimming strata.}\n",
  "\\label{tab:utg_lee_alt_strata}\n",
  "\\begin{threeparttable}\n",
  "\\small\n",
  "\\begin{tabular}{p{0.34\\linewidth}ccc}\n",
  "\\toprule\n",
  "Strata & Admin coef. & Gap (\\%) & Trim (\\%) \\\\\n",
  "\\midrule\n",
  paste(sprintf("%s & [%.3f, %.3f] & [%.1f, %.1f] & %.1f \\\\",
                alt_dt$strata,
                alt_dt$lower_coef,
                alt_dt$upper_coef,
                alt_dt$lower_gap,
                alt_dt$upper_gap,
                alt_dt$trim_mean),
        collapse = "\n"),
  "\n",
  "\\bottomrule\n",
  "\\end{tabular}\n",
  "\\begin{tablenotes}[flushleft]\\footnotesize\n",
  "\\item \\textit{Notes:} The outcome and second-stage fixed effects are held ",
  "fixed across rows: log negotiated price with item, year, and PBU fixed effects. ",
  "Rows vary only the strata used to compute the administrative trimming share. ",
  "The item $\\times$ year $\\times$ PBU row is the preferred specification in the main analysis. ",
  "Coefficients are administrative minus litigated log prices; percentage gaps ",
  "are reported as litigated-over-administrative prices. ",
  "In the finest item $\\times$ year-month $\\times$ PBU strata, cells contain too ",
  "few administrative observations for top-tail and bottom-tail trimming to remove ",
  "different observations, so the lower and upper bounds coincide; this row is ",
  "reported for completeness, and the preferred bounds use the coarser ",
  "item $\\times$ year $\\times$ PBU strata.\n",
  "\\end{tablenotes}\n",
  "\\end{threeparttable}\n",
  "\\end{table}\n"
)
writeLines(alt_tex, file.path(OUT, "tables", "tab_utg_lee_alt_strata.tex"))
cat("[ok] wrote tab_utg_lee_alt_strata.tex\n")

# 4. Emit macros for the manuscript.
bp_macros_emit("40_utg_lee_bounds", list(
  utgPointNaive       = bp_pct_from_log(-b_naive),
  utgPointNaiveCoef   = bp_fmt(b_naive),
  utgPointNaiveSE     = bp_fmt(se_naive),
  utgPointNaiveN      = bp_fmt_int(nobs(m_naive)),
  utgBoundLow         = bp_pct_from_log(-ub$coef),
  utgBoundLowCoef     = bp_fmt(lb$coef),
  utgBoundLowSE       = bp_fmt(lb$se),
  utgBoundLowN        = bp_fmt_int(lb$n),
  utgBoundHigh        = bp_pct_from_log(-lb$coef),
  utgBoundHighCoef    = bp_fmt(ub$coef),
  utgBoundHighSE      = bp_fmt(ub$se),
  utgBoundHighN       = bp_fmt_int(ub$n),
  utgLeeTrimMean      = bp_fmt_pct(trim_summary$mean_trim * 100),
  utgLeeTrimMax       = bp_fmt_pct(trim_summary$max_trim * 100),
  utgLeeStrataExcess  = bp_fmt_int(trim_summary$cells_admin_excess),
  utgLeeStrataTotal   = bp_fmt_int(trim_summary$cells_total)
))

bp_log_step("done", t0, LOG)
