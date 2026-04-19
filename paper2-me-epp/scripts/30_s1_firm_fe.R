# ============================================================================
# 30_s1_firm_fe.R — Bidder-level mechanism with firm (CNPJ raiz) fixed effects
# ============================================================================
# Responds to mr-sme referee suggestion s1: "linking phase-2 bids to bidder
# CNPJ and studying within-firm bid aggressiveness change pre vs post would
# transform the mechanism story from 'residual evidence' to 'direct
# bid-shading evidence'."
#
# Identification: within-firm change in bid aggressiveness under the SME-only
# regime switch. The winner's CNPJ raiz is observed; firm FE absorbs all
# time-invariant firm characteristics (size, cost, strategy). Interaction
# g65 x Pre identifies the within-firm change in bid_discount associated
# with the regime shift in Group 65 vs. non-Group-65 items.
#
# This is stronger than the auction-level tests because it shows that the
# SAME firms bid more aggressively when the open-tender regime applies.
# Rules out bidder-selection stories for the bid-discount effect.
#
# Outputs: /tmp/p2_firm_fe.rds, output/tables/tab_firm_fe.tex
# ============================================================================

cat("=== 30_s1_firm_fe.R: Bidder-level firm FE mechanism ===\n")

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  f_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(f_arg)) dirname(sub("^--file=", "", f_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils.R"), local = TRUE)

suppressPackageStartupMessages({library(fixest); library(data.table)})
setFixest_estimation(lean = FALSE)

# ---- Build full-sample bid-discount + CNPJ panel --------------------------
csv_path <- file.path(DATA_RAW, "Paper2_ME_EPP.csv")
dt_prep  <- as.data.table(readRDS(DATA_CACHE))

FE_CACHE <- "/tmp/p2_firm_fe_raw.rds"
if (!file.exists(FE_CACHE)) {
  cat("  Reading min_bid_ph2 from CSV and joining to prepared cache (cnpj_raiz)...\n")
  hdr <- names(fread(csv_path, sep = ";", encoding = "Latin-1", nrows = 0))
  keep <- c("data_oc_numb", "item_alt", "oc_item_status",
            "preco_ref", "min_bid_ph2")
  csv_bids <- fread(csv_path, sep = ";", encoding = "Latin-1",
                    select = intersect(hdr, keep))
  csv_bids[, valid_bid := !is.na(min_bid_ph2) & min_bid_ph2 > 0 &
                          !is.na(preco_ref)   & preco_ref   > 0]
  csv_bids[valid_bid == TRUE,
           bid_discount := (preco_ref - min_bid_ph2) / preco_ref]
  csv_bids[valid_bid == TRUE & (bid_discount < -2 | bid_discount > 1),
           bid_discount := NA_real_]

  # Prepared cache has cnpj_raiz + convite + lquantidade; restrict to 18m
  prep_sub <- dt_prep[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
                      oc_item_status == 1L & !is.na(cnpj_raiz) & cnpj_raiz != "",
                      .(data_oc_numb, item_alt, pbu_alt, cnpj_raiz, codigogrupo,
                        g65, Pre, g65_pre, convite, lquantidade, num_firms)]
  prep_sub[, item_alt_key := as.character(item_alt)]
  csv_bids[, item_alt_key := as.character(item_alt)]

  setkey(prep_sub, data_oc_numb, item_alt_key)
  setkey(csv_bids, data_oc_numb, item_alt_key)

  d <- csv_bids[, .(data_oc_numb, item_alt_key,
                    min_bid_ph2, preco_ref, bid_discount, valid_bid)
                ][prep_sub, on = c("data_oc_numb", "item_alt_key"), mult = "first"]
  d <- d[valid_bid == TRUE & !is.na(bid_discount)]

  saveRDS(d, FE_CACHE)
  cat(sprintf("  Saved: %s (%s rows, %s unique CNPJ)\n",
              FE_CACHE, pfmt_int(nrow(d)),
              pfmt_int(uniqueN(d$cnpj_raiz))))
} else {
  d <- readRDS(FE_CACHE)
  cat(sprintf("  Loaded cache: %s rows (%s unique CNPJ)\n",
              pfmt_int(nrow(d)), pfmt_int(uniqueN(d$cnpj_raiz))))
}

# ---- Subsample: firms that win in both G65 and non-G65 within 18m window --
# These are the firms for which the treatment effect is identified via firm FE
firm_coverage <- d[, .(any_g65 = any(g65 == 1L),
                       any_nong65 = any(g65 == 0L),
                       any_pre = any(Pre == 1L),
                       any_post = any(Pre == 0L)),
                   by = cnpj_raiz]
firms_both_groups  <- firm_coverage[any_g65 & any_nong65, cnpj_raiz]
firms_both_periods <- firm_coverage[any_pre & any_post, cnpj_raiz]
firms_for_fe <- intersect(firms_both_groups, firms_both_periods)
cat(sprintf("  Firms winning in BOTH G65 and non-G65: %s\n",
            pfmt_int(length(firms_both_groups))))
cat(sprintf("  Firms winning in BOTH pre and post:    %s\n",
            pfmt_int(length(firms_both_periods))))
cat(sprintf("  Both (identified under firm FE):       %s\n",
            pfmt_int(length(firms_for_fe))))

# ---- Specifications ------------------------------------------------------
cat("\n  Running specifications...\n")

# (1) Headline replication, item+month FE (benchmark)
m1 <- feols(bid_discount ~ g65_pre + convite + lquantidade |
            item_alt + data_oc_numb,
            data = d, cluster = ~item_alt, lean = FALSE)
b <- coef(m1)["g65_pre"]; se <- sqrt(vcov(m1)["g65_pre","g65_pre"])
cat(sprintf("    (1) item+month FE: b=%+.4f (%.4f) n=%s\n",
            b, se, pfmt_int(m1$nobs)))

# (2) + PBU FE
m2 <- feols(bid_discount ~ g65_pre + convite + lquantidade |
            item_alt + data_oc_numb + pbu_alt,
            data = d, cluster = ~item_alt, lean = FALSE)
b <- coef(m2)["g65_pre"]; se <- sqrt(vcov(m2)["g65_pre","g65_pre"])
cat(sprintf("    (2) + PBU FE:      b=%+.4f (%.4f) n=%s\n",
            b, se, pfmt_int(m2$nobs)))

# (3) + firm (cnpj_raiz) FE — full sample
m3 <- feols(bid_discount ~ g65_pre + convite + lquantidade |
            item_alt + data_oc_numb + pbu_alt + cnpj_raiz,
            data = d, cluster = ~item_alt, lean = FALSE)
b <- coef(m3)["g65_pre"]; se <- sqrt(vcov(m3)["g65_pre","g65_pre"])
cat(sprintf("    (3) + firm FE:     b=%+.4f (%.4f) n=%s\n",
            b, se, pfmt_int(m3$nobs)))

# (4) + firm FE, restricted to firms in both G65 and non-G65 + both periods
d_sub <- d[cnpj_raiz %in% firms_for_fe]
m4 <- feols(bid_discount ~ g65_pre + convite + lquantidade |
            item_alt + data_oc_numb + pbu_alt + cnpj_raiz,
            data = d_sub, cluster = ~item_alt, lean = FALSE)
b <- coef(m4)["g65_pre"]; se <- sqrt(vcov(m4)["g65_pre","g65_pre"])
cat(sprintf("    (4) + firm FE (balanced): b=%+.4f (%.4f) n=%s\n",
            b, se, pfmt_int(m4$nobs)))

mods <- list(base = m1, pbu = m2, firm = m3, firm_bal = m4)
saveRDS(mods, "/tmp/p2_firm_fe.rds")

# ---- LaTeX table ---------------------------------------------------------
cat("\n  Writing LaTeX table...\n")
fmt_cell <- function(m, d_digits = 4) {
  b  <- coef(m)["g65_pre"]
  se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d_digits), pstars(p)),
    paste0("(", pfmt(se, d_digits), ")"))
}

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Within-Firm Mechanism: Phase-2 Bid Discount under Firm (CNPJ) Fixed Effects}",
  "\\label{tab:firm_fe}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  " & (1) & (2) & (3) & (4) \\\\",
  " & item + month & + PBU & + firm & + firm, balanced \\\\",
  "\\midrule",
  sprintf("$g65 \\times Pre$ & %s & %s & %s & %s \\\\",
          fmt_cell(m1)[1], fmt_cell(m2)[1],
          fmt_cell(m3)[1], fmt_cell(m4)[1]),
  sprintf(" & %s & %s & %s & %s \\\\",
          fmt_cell(m1)[2], fmt_cell(m2)[2],
          fmt_cell(m3)[2], fmt_cell(m4)[2]),
  "\\midrule",
  sprintf("Observations & %s & %s & %s & %s \\\\",
          pfmt_int(m1$nobs), pfmt_int(m2$nobs),
          pfmt_int(m3$nobs), pfmt_int(m4$nobs)),
  "Item FE & YES & YES & YES & YES \\\\",
  "Month FE & YES & YES & YES & YES \\\\",
  "PBU FE & NO & YES & YES & YES \\\\",
  "Firm FE (cnpj raiz) & NO & NO & YES & YES \\\\",
  sprintf("Sample & \\multicolumn{3}{c}{Full 18m completed} & Balanced (%s firms) \\\\",
          pfmt_int(length(firms_for_fe))),
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Dependent variable is the phase-2 winning-bid",
  "discount, $(p^\\text{ref} - p^{(1)}) / p^\\text{ref}$. Column (1) reproduces",
  "the headline specification (item + month FE) from Figure~\\ref{fig:collapse}.",
  "Columns (2)--(3) add PBU and then winning-firm (CNPJ raiz) fixed",
  "effects. Column (4) further restricts the sample to firms that win at",
  "least one Group-65 item and at least one non-Group-65 item within the",
  "18-month window, \\emph{and} at least once pre- and post-cutoff---i.e., the",
  "subset of bidders for whom the within-firm DiD coefficient is identified.",
  "A negative coefficient means the same firm bids further below the",
  "reference price when the SME restriction does not bind: a direct test of",
  "within-bidder behavioral change, not contaminated by bidder selection.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_firm_fe.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_firm_fe.tex"), "\n")
cat("  Done.\n")
