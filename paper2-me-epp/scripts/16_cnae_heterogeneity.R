# ============================================================================
# 16_cnae_heterogeneity.R — DiDiR heterogeneity by winner CNAE 2-digit sector
# ============================================================================
# Splits the sample by the winner's modal CNAE 2.0 division (first two digits
# of cnae20_modal from RAIS) and runs the headline DiDiR within each of the
# top sectors, plus a pooled "other" residual group. Reveals which sectors
# drive the main results and where the ME/EPP preference has the largest
# procurement cost.
#
# Outputs:
#   - /tmp/p2_cnae_het.rds
#   - output/tables/tab_cnae_het.tex
#   - output/tables/diag_cnae_het.txt
# ============================================================================

cat("=== 16_cnae_heterogeneity.R: Heterogeneity by winner CNAE 2-digit ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

RAIS_LINK <- file.path(BASE, "data", "processed",
                       "paper2_suppliers_rais_linked.parquet")
if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
if (!file.exists(RAIS_LINK)) stop("Run 05_link_rais.py first")

dt <- readRDS(DATA_CACHE)
stopifnot("cnpj_raiz" %in% names(dt))

rais <- as.data.table(read_parquet(RAIS_LINK))
rais <- rais[, .(cnpj_raiz, rais_match, cnae20_modal)]
setkey(rais, cnpj_raiz)
setkey(dt, cnpj_raiz)
dt <- rais[dt]
dt[, rais_match := fifelse(is.na(rais_match), FALSE, as.logical(rais_match))]

# ---- CNAE 2-digit (divisão) via floor --------------------------------------
# NB: integer CAST on 47890/1000 rounds up to 48 in DuckDB/R; use floor.
dt[, cnae2 := as.integer(floor(cnae20_modal / 1000))]

# ---- Top sectors among 18m completed obs with valid CNAE -------------------
d18c <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
           oc_item_status == 1L & !is.na(cnae2)]
sec_counts <- d18c[, .N, by = cnae2][order(-N)]
cat("  Top 10 CNAE-2 sectors (18m completed):\n")
print(head(sec_counts, 10))

TOP_N <- 6L
top_secs <- sec_counts[seq_len(TOP_N), cnae2]

# Human-readable labels for top sectors (CNAE 2.0 Divisão)
cnae2_labels <- c(
  "01" = "Agriculture", "10" = "Food mfg.", "11" = "Beverages",
  "13" = "Textiles", "14" = "Apparel", "15" = "Leather",
  "17" = "Paper", "18" = "Printing", "20" = "Chemicals",
  "21" = "Pharma", "22" = "Rubber & plastics", "23" = "Non-metallic mineral",
  "24" = "Basic metal", "25" = "Fabricated metal", "26" = "Electronics",
  "27" = "Elec. equipment", "28" = "Machinery", "29" = "Vehicles",
  "30" = "Other transport", "31" = "Furniture", "32" = "Other mfg.",
  "33" = "Repair/install", "41" = "Building constr.", "42" = "Civil engr.",
  "43" = "Specialty constr.", "45" = "Vehicle wholesale",
  "46" = "Wholesale trade", "47" = "Retail trade",
  "49" = "Land transport", "50" = "Water transport", "51" = "Air transport",
  "52" = "Warehousing", "53" = "Postal", "55" = "Lodging", "56" = "Food service",
  "58" = "Publishing", "61" = "Telecoms", "62" = "IT services",
  "64" = "Financial", "68" = "Real estate", "69" = "Legal/accounting",
  "70" = "Holdings", "71" = "Architecture/engr.", "72" = "R\\&D",
  "73" = "Advertising", "74" = "Pro. activities",
  "77" = "Rental", "78" = "Employment agencies",
  "79" = "Travel", "80" = "Security", "81" = "Facilities",
  "82" = "Office admin.", "86" = "Human health", "87" = "Residential care",
  "88" = "Social", "90" = "Arts", "92" = "Gambling", "93" = "Sports",
  "94" = "Associations", "95" = "Repair", "96" = "Other personal services"
)
get_label <- function(k) {
  key <- sprintf("%02d", as.integer(k))
  if (!is.null(cnae2_labels[[key]])) cnae2_labels[[key]] else paste0("CNAE ", key)
}

diag <- c(
  "=== CNAE-2 heterogeneity diagnostic ===",
  sprintf("Sample (18m completed with CNAE-2): %s obs",
          pfmt_int(nrow(d18c))),
  sprintf("Top %d sectors retained; remaining pooled as ``Other''.", TOP_N),
  "",
  capture.output(print(head(sec_counts, 15)))
)
writeLines(diag, file.path(OUT_TAB, "diag_cnae_het.txt"))

# ---- DiDiR within each sector ---------------------------------------------
run_sector <- function(dv, sub_mask, completed = TRUE) {
  d <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
  if (completed) d <- d[oc_item_status == 1L]
  d <- d[eval(sub_mask)]
  if (nrow(d) < 500L) return(NULL)
  fml <- as.formula(paste0(dv,
    " ~ g65_pre + convite + lquantidade | item_alt"))
  tryCatch(
    feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none"),
    error = function(e) NULL)
}

# "other" group = matched firms whose CNAE2 is not in top_secs
outcomes <- list(
  list(dv = "lpreco_final", label = "Log prices", completed = TRUE),
  list(dv = "lnum_firms",   label = "Log firms",  completed = TRUE),
  list(dv = "lnum_bids",    label = "Log bids",   completed = TRUE),
  list(dv = "dist1",        label = "Distance",   completed = TRUE)
)

sector_labels <- c(as.character(top_secs), "other")
sector_masks  <- c(
  lapply(top_secs, function(s) bquote(cnae2 == .(s))),
  list(bquote(!is.na(cnae2) & !(cnae2 %in% .(top_secs))))
)

cat("  Running regressions (sectors x outcomes)...\n")
mod_grid <- list()
for (i in seq_along(sector_labels)) {
  slab <- sector_labels[i]
  smask <- sector_masks[[i]]
  for (o in outcomes) {
    key <- paste0(slab, "_", o$dv)
    mod_grid[[key]] <- run_sector(o$dv, smask, o$completed)
  }
}

saveRDS(list(mods = mod_grid, top_secs = top_secs,
             sector_labels = sector_labels),
        "/tmp/p2_cnae_het.rds")

# ---- LaTeX table ---------------------------------------------------------
cat("  Writing LaTeX table...\n")

cell <- function(key) {
  m <- mod_grid[[key]]
  if (is.null(m))                       return(c("--", "--", "0"))
  if (!"g65_pre" %in% names(coef(m)))   return(c("--", "--", pfmt_int(m$nobs)))
  b  <- coef(m)["g65_pre"]
  se <- sqrt(vcov(m)["g65_pre", "g65_pre"])
  p  <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, 4), pstars(p)), paste0("(", pfmt(se, 4), ")"),
    pfmt_int(m$nobs))
}

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{DiDiR Coefficient by Winner CNAE 2-Digit Sector (18-month window)}",
  "\\label{tab:cnae_het}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{llcccccccc}",
  "\\toprule",
  " & & \\multicolumn{2}{c}{Log prices} & \\multicolumn{2}{c}{Log firms}",
     " & \\multicolumn{2}{c}{Log bids} & \\multicolumn{2}{c}{Distance} \\\\",
  "\\cmidrule(lr){3-4} \\cmidrule(lr){5-6} \\cmidrule(lr){7-8} \\cmidrule(lr){9-10}",
  "CNAE-2 & Sector & $\\beta$ & (SE) & $\\beta$ & (SE) & $\\beta$ & (SE) & $\\beta$ & (SE) \\\\",
  "\\midrule"
)

for (slab in sector_labels) {
  label <- if (slab == "other") "Other" else get_label(slab)
  cnae_head <- if (slab == "other") "---" else sprintf("%02d", as.integer(slab))
  cells <- character(0)
  for (o in outcomes) {
    c_vals <- cell(paste0(slab, "_", o$dv))
    cells <- c(cells, c_vals[1], c_vals[2])
  }
  # Add N (common across outcomes since same sub-sample + same completed flag;
  # for lnum_firms/lnum_bids the N is a bit smaller due to NAs; use prices N)
  lines <- c(lines, sprintf("%s & %s & %s \\\\",
                            cnae_head, label,
                            paste(cells, collapse = " & ")))
}

# N row per sector (prices as the reference)
n_per_sec <- sapply(sector_labels, function(s) {
  m <- mod_grid[[paste0(s, "_lpreco_final")]]
  if (is.null(m)) "--" else pfmt_int(m$nobs)
})

lines <- c(lines,
  "\\midrule",
  "Item FE & \\multicolumn{9}{c}{YES (within each sector subsample)} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 18-month window, completed items. Each row is a",
  "separate DiDiR regression restricted to items whose winner's CNPJ-raiz is",
  "modally classified in the indicated CNAE 2.0 division (RAIS ESTB 2017).",
  sprintf("``Other'' pools all matched winners outside the top %d sectors.",
          TOP_N),
  sprintf("Sector sample sizes (prices): %s.",
          paste(sprintf("%s n=%s",
                        sapply(sector_labels, function(s) if (s == "other") "Other" else get_label(s)),
                        n_per_sec), collapse = "; ")),
  "Standard errors clustered at the item level in parentheses.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_cnae_het.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_cnae_het.tex"), "\n")
cat("  Done.\n")
