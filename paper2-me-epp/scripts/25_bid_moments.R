# ============================================================================
# 25_bid_moments.R — Bid-level aggressiveness from CSV phase-2 moments
# ============================================================================
# Tests the intensive-margin story directly using phase-2 bid-distribution
# moments (min, max, mean, sd) extracted ad-hoc from the raw CSV. Phase 2 is
# the electronic iterative bidding phase where most items actually move;
# phase 1 sealed-bid data is sparse. Existing tab_bid_aggressiveness shows
# the log-price effect is robust to conditioning on firm count; this script
# adds the complementary evidence that the bids themselves become more
# aggressive under open tenders, i.e., firms bid further below the
# reference price.
#
# Outcomes (all conditional on completion and on valid phase-2 data):
#   bid_discount = (preco_ref - min_bid_ph2) / preco_ref
#   log_sd_bid2  = log(1 + sd_bid_ph2)
#   log_range    = log(1 + (max_bid_ph2 - min_bid_ph2)) normalized by mean
#
# Outputs:
#   - /tmp/p2_bid_moments.rds
#   - output/tables/tab_bid_moments.tex
#   - output/tables/diag_bid_moments.txt
# ============================================================================

cat("=== 25_bid_moments.R: Bid-level aggressiveness from phase-2 moments ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

csv_path <- file.path(DATA_RAW, "Paper2_ME_EPP.csv")
stopifnot(file.exists(csv_path))

cat("  Reading bid-moment columns from CSV (this takes ~1-2 minutes)...\n")
hdr <- names(fread(csv_path, sep = ";", encoding = "Latin-1", nrows = 0))
patterns <- c(
  "^data_oc_numb$", "^item_alt$", "^pbu_alt$", "^oc_item_status$",
  "^convite$", "^lquantidade$", "^num_firms$", "^preco_ref$",
  "^class_alt$", "digogrupo$",
  "^min_bid_ph2$", "^max_bid_ph2$", "^mean_bid_ph2$",
  "^median_bid_ph2$", "^sd_bid_ph2$"
)
keep <- unique(unlist(lapply(patterns, function(p) grep(p, hdr, value = TRUE))))
cat(sprintf("  Selecting %d CSV columns\n", length(keep)))

t0 <- Sys.time()
dt <- fread(csv_path, sep = ";", encoding = "Latin-1", select = keep)
cat(sprintf("  CSV loaded: %s rows (%.1fs)\n",
            pfmt_int(nrow(dt)),
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# Normalize group code name
grupo_col <- grep("digogrupo$", names(dt), value = TRUE)
if (length(grupo_col) == 1 && grupo_col != "codigogrupo")
  setnames(dt, grupo_col, "codigogrupo")
dt[, codigogrupo := as.character(codigogrupo)]

dt[, g65     := as.integer(codigogrupo == "65")]
dt[, Pre     := as.integer(data_oc_numb < TREAT_DATE)]
dt[, g65_pre := g65 * Pre]

# ---- Aggressiveness metrics -----------------------------------------------
# Filter to rows with valid phase-2 data (non-zero, non-NA).
dt[, valid_ph2 := !is.na(min_bid_ph2) & min_bid_ph2 > 0 &
                  !is.na(preco_ref)   & preco_ref   > 0 &
                  !is.na(max_bid_ph2) & max_bid_ph2 >= min_bid_ph2 &
                  !is.na(mean_bid_ph2) & mean_bid_ph2 > 0]

cat(sprintf("  Valid phase-2 observations: %s of %s (%.1f%%)\n",
            pfmt_int(dt[valid_ph2 == TRUE, .N]),
            pfmt_int(nrow(dt)),
            100 * dt[valid_ph2 == TRUE, .N] / nrow(dt)))

dt[valid_ph2 == TRUE, bid_discount := (preco_ref - min_bid_ph2) / preco_ref]
dt[valid_ph2 == TRUE, bid_range    := (max_bid_ph2 - min_bid_ph2) / mean_bid_ph2]
dt[valid_ph2 == TRUE, log_sd_bid2  := log1p(sd_bid_ph2)]

# Clip outliers on discount (allow negative if min bid > reference, unusual)
dt[valid_ph2 == TRUE & (bid_discount < -2 | bid_discount > 1),
   bid_discount := NA_real_]
dt[valid_ph2 == TRUE & bid_range > 10, bid_range := NA_real_]

# ---- Restrict to 18m completed window -------------------------------------
dt[, item_alt_f := factor(item_alt)]
dt[, pbu_alt_f  := factor(pbu_alt)]

d_win <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
            oc_item_status == 1L & valid_ph2 == TRUE]
cat(sprintf("  18m completed sample with ph2 moments: %s obs\n",
            pfmt_int(nrow(d_win))))

# ---- DiD runs -------------------------------------------------------------
run_bid <- function(dv, sub_mask = NULL) {
  d <- if (is.null(sub_mask)) d_win else d_win[eval(sub_mask)]
  if (nrow(d) < 500L) return(NULL)
  fml <- as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt_f + pbu_alt_f + data_oc_numb"))
  tryCatch(
    feols(fml, data = d, cluster = ~item_alt_f, fixef.rm = "none"),
    error = function(e) NULL)
}

cat("  Running DiDs on bid-level outcomes...\n")
outcomes <- c("bid_discount", "log_sd_bid2", "bid_range")
mods_full <- list()
for (dv in outcomes) {
  mods_full[[dv]] <- run_bid(dv)
}

# Conditional on number of firms (intensive-margin test)
cond_specs <- list(
  n2  = quote(num_firms == 2L),
  n3  = quote(num_firms == 3L),
  n5p = quote(num_firms >= 5L)
)
mods_cond <- list()
for (dv in outcomes) {
  for (cn in names(cond_specs)) {
    mods_cond[[paste0(dv, "_", cn)]] <- run_bid(dv, cond_specs[[cn]])
  }
}

saveRDS(list(full = mods_full, cond = mods_cond),
        "/tmp/p2_bid_moments.rds")

# ---- LaTeX table ---------------------------------------------------------
cat("  Writing LaTeX table...\n")

fmt_coef <- function(m, d = 4) {
  if (is.null(m))                       return(c("--", "--"))
  if (!"g65_pre" %in% names(coef(m)))   return(c("--", "--"))
  b  <- coef(m)["g65_pre"]
  se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d), pstars(p)), paste0("(", pfmt(se, d), ")"))
}

outcome_labels <- c(
  bid_discount = "Discount from ref. (\\%)",
  log_sd_bid2  = "Log SD of ph-2 bids",
  bid_range    = "Norm. bid range"
)

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Bid-Level Aggressiveness: Phase-2 Moments (18-month window)}",
  "\\label{tab:bid_moments}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & Full sample & $N=2$ firms & $N=3$ firms & $N \\geq 5$ firms \\\\",
  "\\midrule"
)

for (dv in outcomes) {
  label <- outcome_labels[dv]
  # Row: coefficients
  c_full <- fmt_coef(mods_full[[dv]])
  c_n2   <- fmt_coef(mods_cond[[paste0(dv, "_n2")]])
  c_n3   <- fmt_coef(mods_cond[[paste0(dv, "_n3")]])
  c_n5p  <- fmt_coef(mods_cond[[paste0(dv, "_n5p")]])
  # N row
  n_full <- if (!is.null(mods_full[[dv]])) pfmt_int(mods_full[[dv]]$nobs) else "--"
  n_n2   <- if (!is.null(mods_cond[[paste0(dv, "_n2")]])) pfmt_int(mods_cond[[paste0(dv, "_n2")]]$nobs) else "--"
  n_n3   <- if (!is.null(mods_cond[[paste0(dv, "_n3")]])) pfmt_int(mods_cond[[paste0(dv, "_n3")]]$nobs) else "--"
  n_n5p  <- if (!is.null(mods_cond[[paste0(dv, "_n5p")]])) pfmt_int(mods_cond[[paste0(dv, "_n5p")]]$nobs) else "--"
  lines <- c(lines,
    sprintf("\\multicolumn{5}{l}{\\textit{%s}} \\\\", label),
    sprintf("$g65 \\times Pre$ & %s & %s & %s & %s \\\\",
            c_full[1], c_n2[1], c_n3[1], c_n5p[1]),
    sprintf(" & %s & %s & %s & %s \\\\",
            c_full[2], c_n2[2], c_n3[2], c_n5p[2]),
    sprintf("Observations & %s & %s & %s & %s \\\\",
            n_full, n_n2, n_n3, n_n5p),
    "\\addlinespace"
  )
}

lines <- c(lines,
  "\\midrule",
  "Item FE + PBU FE & YES & YES & YES & YES \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 18-month window, completed items, sample restricted",
  "to observations with valid phase-2 bid-distribution moments (about 67\\% of",
  "all completed items have non-missing \\texttt{min\\_bid\\_ph2}).",
  "Columns (2)--(4) condition on the number of participating firms to isolate",
  "the intensive-margin bid aggressiveness, complementing the log-price",
  "results in Table~\\ref{tab:bid_aggressiveness} which hold the winning",
  "price (not the bid distribution) fixed.",
  "\\textit{Discount from ref.} = $(p_\\text{ref} - \\min_\\text{bid})/p_\\text{ref}$;",
  "a positive $g65 \\times Pre$ means bids reached further below the reference",
  "under open tenders. \\textit{Log SD of ph-2 bids} reflects bid dispersion",
  "(lower = tighter clustering = more aggressive competition).",
  "\\textit{Norm. bid range} = $(\\max - \\min) / \\overline{bid}$.",
  "Cluster-robust SE at item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_bid_moments.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_bid_moments.tex"), "\n")

# ---- Diagnostic ---------------------------------------------------------
diag_lines <- c(
  "=== Bid-level aggressiveness diagnostic ===",
  sprintf("CSV rows read: %s", pfmt_int(nrow(dt))),
  sprintf("Valid phase-2: %s (%.1f%%)",
          pfmt_int(sum(dt$valid_ph2, na.rm = TRUE)),
          100 * sum(dt$valid_ph2, na.rm = TRUE) / nrow(dt)),
  sprintf("18m completed + ph2 valid: %s", pfmt_int(nrow(d_win))),
  "",
  "Summary of constructed metrics (18m window sample):",
  capture.output(print(summary(d_win[, .(bid_discount, log_sd_bid2, bid_range)]))),
  "",
  "g65 x Pre coefficients (full sample):",
  sapply(outcomes, function(dv) {
    m <- mods_full[[dv]]
    if (is.null(m)) sprintf("  %s: n/a", dv)
    else sprintf("  %s: beta = %+.4f, SE = %.4f, n = %s",
                 dv, coef(m)["g65_pre"],
                 sqrt(vcov(m)["g65_pre", "g65_pre"]),
                 pfmt_int(m$nobs))
  })
)
writeLines(diag_lines, file.path(OUT_TAB, "diag_bid_moments.txt"))
cat("  Done.\n")
