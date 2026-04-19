# ============================================================================
# 29_runnerup_gap.R — Winner-to-runner-up bid gap: direct bidder-level test
# ============================================================================
# Responds to referee concern MC1: the paper's intensive-margin claim had
# been weakened when SD compression disappeared under TWFE. The referee
# asked for one additional bidder-level mechanism. This script computes
# the normalized gap between the winning bid and the runner-up bid:
#
#   gap = (second_bid_ph2 - min_bid_ph2) / preco_ref
#
# Under aggressive bidding (competitors closer to winner), the runner-up
# sits closer to the winner; the gap shrinks. This is a direct
# measurement of competitive pressure that does not require SD
# compression and is not contaminated by mediation-residual ambiguity.
#
# Outputs:
#   - /tmp/p2_runnerup_gap.rds
#   - output/tables/tab_runnerup_gap.tex
# ============================================================================

cat("=== 29_runnerup_gap.R: Winner-to-runner-up bid gap ===\n")

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  f_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(f_arg)) dirname(sub("^--file=", "", f_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages({library(fixest); library(data.table)})
setFixest_estimation(lean = FALSE)

# ---- Build the full-sample winner-runnerup dataset ------------------------
# Re-read CSV columns we need; we already have min_bid_ph2 in the CSV and
# second_bid_ph2 in the prepared cache; join on (data_oc_numb, item_alt).

csv_path <- file.path(DATA_RAW, "Paper2_ME_EPP.csv")
dt_prep  <- as.data.table(readRDS(DATA_CACHE))

GAP_CACHE <- "/tmp/p2_runnerup_raw.rds"
if (!file.exists(GAP_CACHE)) {
  cat("  Reading min_bid_ph2 + second_bid_ph2 + identifiers from CSV...\n")
  hdr <- names(fread(csv_path, sep = ";", encoding = "Latin-1", nrows = 0))
  keep <- c("data_oc_numb", "item_alt", "pbu_alt",
            "oc_item_status", "num_firms", "preco_ref",
            "min_bid_ph2", "second_bid_ph2",
            grep("digogrupo$", hdr, value = TRUE))
  d <- fread(csv_path, sep = ";", encoding = "Latin-1",
             select = intersect(hdr, keep))
  grupo_col <- grep("digogrupo$", names(d), value = TRUE)
  if (length(grupo_col) == 1 && grupo_col != "codigogrupo")
    setnames(d, grupo_col, "codigogrupo")
  d[, codigogrupo := as.character(codigogrupo)]
  d[, g65 := as.integer(codigogrupo == "65")]
  d[, Pre := as.integer(data_oc_numb < TREAT_DATE)]
  d[, g65_pre := g65 * Pre]

  # Valid gap: need both bids strictly positive, runner-up >= winner
  d[, valid_gap := !is.na(min_bid_ph2) & min_bid_ph2 > 0 &
                   !is.na(second_bid_ph2) & second_bid_ph2 > 0 &
                   !is.na(preco_ref) & preco_ref > 0 &
                   second_bid_ph2 >= min_bid_ph2]

  # Normalized gap as a percentage of reference price
  d[valid_gap == TRUE, gap_norm := (second_bid_ph2 - min_bid_ph2) / preco_ref]

  # 18m completed window
  d <- d[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
         oc_item_status == 1L]

  # Bring in convite and lquantidade controls from prepared cache
  # (these are controls the rest of the paper uses)
  ctrl <- dt_prep[, .(data_oc_numb, item_alt_key = as.character(item_alt),
                      convite, lquantidade)]
  d[, item_alt_key := as.character(item_alt)]
  setkey(ctrl, data_oc_numb, item_alt_key)
  setkey(d,    data_oc_numb, item_alt_key)
  d <- ctrl[d, mult = "first"]  # left-join controls onto d

  # Clip extreme gaps (defensive)
  d[valid_gap == TRUE & gap_norm > 2, gap_norm := NA_real_]

  saveRDS(d, GAP_CACHE)
  cat(sprintf("  Saved: %s (%s rows; %s with valid gap)\n",
              GAP_CACHE, pfmt_int(nrow(d)),
              pfmt_int(d[valid_gap == TRUE, .N])))
} else {
  d <- readRDS(GAP_CACHE)
  cat(sprintf("  Loaded cache: %s rows (%s with valid gap)\n",
              pfmt_int(nrow(d)),
              pfmt_int(d[valid_gap == TRUE, .N])))
}

# ---- Also compute log gap (handle gap = 0 with log1p scaling) -------------
d[valid_gap == TRUE, log_gap := log1p(gap_norm)]

# ---- Coverage diagnostic --------------------------------------------------
cat("  Coverage of gap_norm by regime and treatment:\n")
tab <- d[valid_gap == TRUE, .(
  n  = .N,
  mean_gap = mean(gap_norm, na.rm = TRUE),
  median_gap = median(gap_norm, na.rm = TRUE)
), by = .(g65, Pre)]
print(tab)

# ---- DiD on gap_norm + log_gap --------------------------------------------
run_spec <- function(dv, sub_mask = NULL) {
  dd <- if (is.null(sub_mask)) d else d[eval(sub_mask)]
  dd <- dd[valid_gap == TRUE]
  if (nrow(dd) < 500L) return(NULL)
  fml <- as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt + pbu_alt + data_oc_numb"))
  tryCatch(
    feols(fml, data = dd, cluster = ~item_alt, fixef.rm = "none",
          lean = FALSE),
    error = function(e) { cat("    ERROR:", conditionMessage(e), "\n"); NULL })
}

cat("\n  Running DiDs on gap outcomes...\n")
mods <- list(
  full_gap     = run_spec("gap_norm"),
  n2_gap       = run_spec("gap_norm", quote(num_firms == 2L)),
  n3_gap       = run_spec("gap_norm", quote(num_firms == 3L)),
  n5p_gap      = run_spec("gap_norm", quote(num_firms >= 5L)),
  full_log_gap = run_spec("log_gap"),
  n2_log_gap   = run_spec("log_gap", quote(num_firms == 2L)),
  n3_log_gap   = run_spec("log_gap", quote(num_firms == 3L)),
  n5p_log_gap  = run_spec("log_gap", quote(num_firms >= 5L))
)

for (nm in names(mods)) {
  m <- mods[[nm]]
  if (!is.null(m)) {
    b  <- coef(m)["g65_pre"]
    se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
    cat(sprintf("    %-15s beta = %+.4f (SE %.4f), n = %s\n",
                nm, b, se, pfmt_int(m$nobs)))
  } else cat(sprintf("    %-15s NULL\n", nm))
}

saveRDS(mods, "/tmp/p2_runnerup_gap.rds")

# ---- LaTeX table ----------------------------------------------------------
cat("\n  Writing LaTeX table...\n")

fmt_cell <- function(m, d_digits = 4) {
  if (is.null(m)) return(c("--", "--"))
  b  <- coef(m)["g65_pre"]
  se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d_digits), pstars(p)),
    paste0("(", pfmt(se, d_digits), ")"))
}

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Winner-to-Runner-up Bid Gap (18-month window)}",
  "\\label{tab:runnerup_gap}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & Full sample & $N=2$ firms & $N=3$ firms & $N \\geq 5$ firms \\\\",
  "\\midrule",
  "\\multicolumn{5}{l}{\\textit{Normalized gap: $(p^{(2)} - p^{(1)})/p^\\text{ref}$}} \\\\",
  sprintf("$g65 \\times Pre$ & %s & %s & %s & %s \\\\",
          fmt_cell(mods$full_gap)[1], fmt_cell(mods$n2_gap)[1],
          fmt_cell(mods$n3_gap)[1],  fmt_cell(mods$n5p_gap)[1]),
  sprintf(" & %s & %s & %s & %s \\\\",
          fmt_cell(mods$full_gap)[2], fmt_cell(mods$n2_gap)[2],
          fmt_cell(mods$n3_gap)[2],  fmt_cell(mods$n5p_gap)[2]),
  "\\addlinespace",
  "\\multicolumn{5}{l}{\\textit{Log-gap: $\\log(1 + \\text{normalized gap})$}} \\\\",
  sprintf("$g65 \\times Pre$ & %s & %s & %s & %s \\\\",
          fmt_cell(mods$full_log_gap)[1], fmt_cell(mods$n2_log_gap)[1],
          fmt_cell(mods$n3_log_gap)[1],  fmt_cell(mods$n5p_log_gap)[1]),
  sprintf(" & %s & %s & %s & %s \\\\",
          fmt_cell(mods$full_log_gap)[2], fmt_cell(mods$n2_log_gap)[2],
          fmt_cell(mods$n3_log_gap)[2],  fmt_cell(mods$n5p_log_gap)[2]),
  "\\addlinespace",
  sprintf("Observations (normalized gap) & %s & %s & %s & %s \\\\",
          if (!is.null(mods$full_gap)) pfmt_int(mods$full_gap$nobs) else "--",
          if (!is.null(mods$n2_gap))   pfmt_int(mods$n2_gap$nobs)   else "--",
          if (!is.null(mods$n3_gap))   pfmt_int(mods$n3_gap$nobs)   else "--",
          if (!is.null(mods$n5p_gap))  pfmt_int(mods$n5p_gap$nobs)  else "--"),
  "\\midrule",
  "Item + PBU + Month FE & YES & YES & YES & YES \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} The \\textit{normalized gap} is the difference",
  "between the second-lowest (runner-up) and lowest (winner) phase-2 bids,",
  "normalized by the buyer's reference price. Under more aggressive bidding",
  "the runner-up's bid sits closer to the winner's, and the gap shrinks.",
  "The \\textit{log-gap} variant is $\\log(1 + \\text{gap})$, which is more",
  "robust to right-skewness of the raw gap distribution.",
  "Columns (2)--(4) condition on the exact number of participating firms",
  "to hold the extensive margin approximately fixed. A negative",
  "$\\mathit{g65}\\times\\mathit{Pre}$ coefficient means the runner-up-to-winner",
  "gap narrows under open tenders: direct bidder-level evidence of",
  "intensifying competitive pressure within auctions. Standard errors",
  "clustered at the item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_runnerup_gap.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_runnerup_gap.tex"), "\n")
cat("  Done.\n")
