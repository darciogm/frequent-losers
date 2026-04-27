# ----------------------------------------------------------------------
# Product-class-conditional persistent-pair collusion screen.
#
# Step 3 of the sequential screen protocol. Bajari-Ye (script 60)
# rejects independence in T1 (max pair count) and T2 (99th percentile)
# in all four strata, with T3 (count of pairs co-bidding >= 5) generally
# passing. The pattern is consistent with two distinct mechanisms:
#
#   (a) coordinated bidding by a small number of firm dyads, OR
#   (b) market segmentation: narrow CADMAT product classes have
#       naturally restricted supplier pools, and the same handful of
#       qualified firms co-bid mechanically across all auctions in
#       that class.
#
# This script tests (a) vs (b) by stratifying the permutation null on
# CADMAT product class. Under the null, firm-bid associations are
# permuted ONLY within product-class. If joint participation between
# specific firm pairs is concentrated within classes (segmentation),
# the within-class permutation reproduces it. If joint participation
# spans across classes (cross-class coordination), the within-class
# permutation cannot reproduce it, and the test still rejects.
#
# Outcome interpretation:
#   - Same pattern as script 60 (T1, T2 reject) → cross-class
#     coordination signal: the same firm pairs co-bid across many
#     classes, beyond what within-class segmentation explains.
#   - T1, T2 stop rejecting → segmentation absorbs the signal:
#     pair concentration is class-internal (specialized supplier pools)
#     rather than across classes.
#
# Citations relevant for the framework:
#   - Bajari and Ye (2003) — pair-test framework (REStat)
#   - Conley and Decarolis (2016) — bidder grouping detection
#     in procurement (AEJ:Micro)
#   - Kawai and Nakabayashi (2022) — modern reference for pair-based
#     collusion detection (JPE)
#   Product-class conditioning itself is a standard statistical control,
#   not a named technique from any single paper.
#
# Output:
#   output/tables/tab_collusion_screen_pair_classcond.csv
#   output/tables/tab_collusion_screen_pair_classcond.tex   (NOT yet \input'd)
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(Matrix)
  library(duckdb)
  library(DBI)
})

root        <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v5-jpube"
out_tables  <- file.path(root, "output", "tables")
in_parquet  <- file.path(root, "data", "processed", "bids_uh_cleaned.parquet")
in_class    <- file.path(root, "data", "processed", "bid_level_sme_g65.parquet")
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

MIN_FIRM_BIDS <- 5L
HI_THRESHOLD  <- 5L
B             <- 200L
SEED          <- 20260427L

# -- load + join class id ---------------------------------------------
t0 <- Sys.time()
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12")

bids <- dbGetQuery(con, sprintf("
  SELECT b.numerodaoc, b.codigoitem, b.cod_forn, b.period,
         b.pharma_narrow, m.codigoclasse
  FROM read_parquet('%s') b
  LEFT JOIN (
    SELECT DISTINCT codigoitem, codigoclasse
    FROM read_parquet('%s')
  ) m ON b.codigoitem = m.codigoitem
  WHERE b.mod = 'pregao'
    AND b.period IN ('Pre','Post')
    AND b.pharma_narrow IS NOT NULL
    AND b.c_norm_clean > 0 AND b.c_norm_clean <= 3
    AND b.cod_forn IS NOT NULL
", in_parquet, in_class)) |> setDT()
dbDisconnect(con, shutdown = TRUE)

bids <- bids[!is.na(codigoclasse)]
bids[, auc_id := paste(numerodaoc, codigoitem, sep = "_")]

cat(sprintf("[load] %s bids, %d auctions, %d firms, %d classes (%.1fs)\n",
            format(nrow(bids), big.mark = ","),
            length(unique(bids$auc_id)),
            length(unique(bids$cod_forn)),
            length(unique(bids$codigoclasse)),
            as.numeric(Sys.time() - t0)))

# -- per-stratum analysis ---------------------------------------------
# Each auction has a single codigoclasse. To permute within class, we
# work on auction-level firm participation lists (each auction has a
# class), and shuffle bids within class.

compute_stats_from_pairs <- function(d) {
  # d: data.table with cod_forn, auc_id
  firm_counts <- d[, .N, by = cod_forn]
  keep_firms  <- firm_counts[N >= MIN_FIRM_BIDS, cod_forn]
  d <- d[cod_forn %in% keep_firms]
  if (length(unique(d$cod_forn)) < 2L) {
    return(list(T1 = NA_integer_, T2 = NA_real_, T3 = NA_integer_,
                n_firms = length(unique(d$cod_forn)),
                n_pairs = NA_integer_))
  }
  firms <- sort(unique(d$cod_forn))
  aucs  <- sort(unique(d$auc_id))
  fid <- match(d$cod_forn, firms)
  aid <- match(d$auc_id, aucs)
  M   <- sparseMatrix(i = fid, j = aid, x = 1,
                      dims = c(length(firms), length(aucs)))
  C   <- tcrossprod(M)
  C   <- as(C, "TsparseMatrix")
  ut  <- C@i < C@j
  vals <- C@x[ut]
  if (length(vals) == 0L) {
    return(list(T1 = 0L, T2 = 0, T3 = 0L,
                n_firms = length(firms), n_pairs = 0L))
  }
  list(
    T1      = max(vals),
    T2      = unname(quantile(vals, 0.99)),
    T3      = sum(vals >= HI_THRESHOLD),
    n_firms = length(firms),
    n_pairs = length(vals)
  )
}

# Permutation: shuffle cod_forn within codigoclasse (preserves
# class-level firm-bid counts but breaks specific firm-auction
# associations within class).
permute_within_class <- function(d) {
  d_copy <- copy(d)
  d_copy[, cod_forn := sample(cod_forn), by = codigoclasse]
  d_copy
}

strata <- unique(bids[, .(period, pharma_narrow)])
setorder(strata, pharma_narrow, period)

set.seed(SEED)
out_rows <- list()

for (s in seq_len(nrow(strata))) {
  per <- strata$period[s]
  ph  <- strata$pharma_narrow[s]
  d   <- bids[period == per & pharma_narrow == ph,
              .(cod_forn, auc_id, codigoclasse)]

  ti <- Sys.time()
  obs <- compute_stats_from_pairs(d[, .(cod_forn, auc_id)])

  # within-class permutation null
  null_T1 <- integer(B); null_T2 <- numeric(B); null_T3 <- integer(B)
  for (b in seq_len(B)) {
    d_shuf <- permute_within_class(d)
    s_b <- compute_stats_from_pairs(d_shuf[, .(cod_forn, auc_id)])
    null_T1[b] <- s_b$T1
    null_T2[b] <- s_b$T2
    null_T3[b] <- s_b$T3
  }

  p_T1 <- mean(null_T1 >= obs$T1)
  p_T2 <- mean(null_T2 >= obs$T2)
  p_T3 <- mean(null_T3 >= obs$T3)

  n_classes <- length(unique(d$codigoclasse))

  out_rows[[length(out_rows) + 1L]] <- data.table(
    pharma_narrow = ph, period = per,
    n_classes = n_classes,
    n_firms = obs$n_firms, n_pairs = obs$n_pairs,
    T1_obs = obs$T1, T1_null_mean = mean(null_T1), p_T1 = p_T1,
    T2_obs = obs$T2, T2_null_mean = mean(null_T2), p_T2 = p_T2,
    T3_obs = obs$T3, T3_null_mean = mean(null_T3), p_T3 = p_T3
  )

  cat(sprintf("[stratum %d/%d] pharma=%d %-4s  classes=%d firms=%d pairs=%d\n",
              s, nrow(strata), ph, per, n_classes,
              obs$n_firms, obs$n_pairs))
  cat(sprintf("   T1 max:        obs=%d   null_mu=%.1f   p=%.3f\n",
              obs$T1, mean(null_T1), p_T1))
  cat(sprintf("   T2 99%%-tile:   obs=%.1f null_mu=%.2f   p=%.3f\n",
              obs$T2, mean(null_T2), p_T2))
  cat(sprintf("   T3 count(>=%d): obs=%d   null_mu=%.1f   p=%.3f   (%.1fs)\n",
              HI_THRESHOLD, obs$T3, mean(null_T3), p_T3,
              as.numeric(Sys.time() - ti)))
}

res <- rbindlist(out_rows)

# -- write CSV ---------------------------------------------------------
csv_path <- file.path(out_tables, "tab_collusion_screen_pair_classcond.csv")
fwrite(res, csv_path)
cat(sprintf("\n[ok] csv written: %s\n", csv_path))

# -- format LaTeX ------------------------------------------------------
res[, lab := paste0(
  ifelse(pharma_narrow == 1, "Pharma", "Non-pharma"), " ", period)]
ord <- c("Non-pharma Pre", "Non-pharma Post", "Pharma Pre", "Pharma Post")
res <- res[match(ord, lab)]

mark_p <- function(p) {
  s <- sprintf("%.3f", p)
  if (is.na(p)) return(s)
  if (p < 0.01) sprintf("\\textbf{%s}\\sym{***}", s)
  else if (p < 0.05) sprintf("\\textbf{%s}\\sym{**}", s)
  else if (p < 0.10) sprintf("%s\\sym{*}", s)
  else s
}

body <- character(nrow(res))
for (i in seq_len(nrow(res))) {
  body[i] <- sprintf(
    "%s & %d & %d & %.1f & %s & %.1f & %.2f & %s & %d & %.1f & %s \\\\",
    res$lab[i],
    res$n_classes[i],
    res$T1_obs[i], res$T1_null_mean[i], mark_p(res$p_T1[i]),
    res$T2_obs[i], res$T2_null_mean[i], mark_p(res$p_T2[i]),
    res$T3_obs[i], res$T3_null_mean[i], mark_p(res$p_T3[i])
  )
}

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Persistent-pair collusion screen, conditional on CADMAT product class.}",
  "\\label{tab:collusion_screen_pair_classcond}",
  "\\footnotesize",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\providecommand{\\sym}[1]{\\textsuperscript{#1}}",
  "\\begin{tabular}{lrrrrrrrrrr}",
  "\\toprule",
  " & & \\multicolumn{3}{c}{$T_1$: max pair count} & \\multicolumn{3}{c}{$T_2$: 99\\%-tile pair count} & \\multicolumn{3}{c}{$T_3$: count$\\geq 5$} \\\\",
  "\\cmidrule(lr){3-5}\\cmidrule(lr){6-8}\\cmidrule(lr){9-11}",
  "Stratum & $N_{\\mathrm{cls}}$ & Obs & Null & $p$ & Obs & Null & $p$ & Obs & Null & $p$ \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf(paste(
    "\\item Persistent-pair test on Preg\\~ao auctions, firms with $\\geq %d$ bids in",
    "the stratum. The permutation null shuffles firm labels \\emph{within}",
    "CADMAT product class, preserving class-level firm-bid counts but breaking",
    "firm-auction associations within class. $N_{\\mathrm{cls}}$ is the number",
    "of distinct CADMAT classes in the stratum. Statistics: $T_1$ = max pair",
    "co-bidding count; $T_2$ = 99th percentile of pair co-bidding distribution;",
    "$T_3$ = count of firm pairs co-bidding in at least %d auctions.",
    "$B = %d$ permutation replicates. One-sided $p$-values report the probability",
    "under the within-class null that the realized statistic is matched or exceeded",
    "by chance. Significance: \\sym{*} $p<0.10$, \\sym{**} $p<0.05$, \\sym{***} $p<0.01$.",
    "Companion to the unconditional test reported in",
    "Table~\\ref{tab:collusion_screen_bajariye} (Bajari and Ye 2003 framework).",
    "Modern references on pair-based collusion detection in procurement:",
    "Conley and Decarolis (2016) for bidder grouping in average-bid auctions;",
    "Kawai and Nakabayashi (2022) for persistent bidder identity in Japanese",
    "construction procurement. Product-class conditioning itself is a standard",
    "statistical control for naturally restricted supplier pools, not a named",
    "technique from any single paper. $p$-values that survive class conditioning",
    "are evidence of cross-class pair concentration beyond market segmentation;",
    "$p$-values that disappear under class conditioning are evidence that the",
    "raw rejection of Table~\\ref{tab:collusion_screen_bajariye} is segmentation",
    "rather than coordination."
  ), MIN_FIRM_BIDS, HI_THRESHOLD, B),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
tex_path <- file.path(out_tables, "tab_collusion_screen_pair_classcond.tex")
writeLines(tex_lines, tex_path)
cat(sprintf("[ok] tex written: %s\n", tex_path))

# -- console summary ---------------------------------------------------
cat("\n=== PRODUCT-CLASS-CONDITIONAL PERSISTENT-PAIR RESULTS ===\n")
print(res[, .(stratum = lab, n_cls = n_classes, n_firms, n_pairs,
              T1 = T1_obs, T1_null = round(T1_null_mean, 1), p_T1 = round(p_T1, 3),
              T2 = round(T2_obs, 1), T2_null = round(T2_null_mean, 2), p_T2 = round(p_T2, 3),
              T3 = T3_obs, T3_null = round(T3_null_mean, 1), p_T3 = round(p_T3, 3))])

cat(sprintf("\nTotal time: %.1fs\n", as.numeric(Sys.time() - t0)))
