# ----------------------------------------------------------------------
# Bajari & Ye (2003) persistent-pair collusion screen.
#
# Step 2 of the sequential screen protocol. Schurter (script 59) shows
# bid clustering survives anchor controls. Bajari-Ye asks whether the
# clustering is concentrated in specific firm pairs (signal of pairwise
# coordination) or distributed across the bidder population (consistent
# with anchor / discreteness / round-number heuristics).
#
# Construction:
#   - For each stratum (period × pharma_narrow), build a firm × auction
#     binary participation matrix M (M[i,j] = 1 if firm i bid in auction
#     j). Restrict to firms with at least MIN_FIRM_BIDS auctions in the
#     stratum.
#   - Co-bidding matrix C = M %*% t(M); C[i,j] is the number of auctions
#     where firms i and j both bid.
#   - Test statistics on the upper-triangle of C:
#       T1 = max pair co-bidding count
#       T2 = 99th percentile of pair co-bidding counts
#       T3 = number of pairs with C[i,j] >= HI_THRESHOLD = 5
#   - Permutation null: shuffle firm labels across bid rows (preserving
#     auction structure but breaking firm-auction associations).
#     Recompute the three statistics under each permutation.
#   - One-sided p-values for each statistic in each stratum.
#
# Output:
#   output/tables/tab_collusion_screen_bajariye.csv
#   output/tables/tab_collusion_screen_bajariye.tex   (NOT yet \input'd)
#
# Interpretation:
#   - All three p > 0.10 in a stratum → no persistent-pair concentration.
#     Combined with Schurter rejection, this points to anchor / discreteness
#     as the explanation for raw clustering rather than coordination.
#   - p < 0.05 on T3 (count of high-cobidding pairs) → some firm pairs
#     systematically co-bid above chance. Further investigation needed.
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(Matrix)
})

root        <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v5-jpube"
out_tables  <- file.path(root, "output", "tables")
in_parquet  <- file.path(root, "data", "processed", "bids_uh_cleaned.parquet")
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

MIN_FIRM_BIDS <- 5L      # firms must bid in >= 5 auctions to enter the test
HI_THRESHOLD  <- 5L      # T3 counts pairs co-bidding in >= 5 auctions
B             <- 200L    # permutation replicates per stratum (each is O(N))
SEED          <- 20260427L

# -- load + filter -----------------------------------------------------
t0 <- Sys.time()
bids <- as.data.table(read_parquet(in_parquet))
bids <- bids[mod == "pregao" &
             period %in% c("Pre", "Post") &
             !is.na(pharma_narrow) &
             c_norm_clean > 0 & c_norm_clean <= 3 &
             !is.na(cod_forn)]
bids[, auc_id := paste(numerodaoc, codigoitem, sep = "_")]

cat(sprintf("[load] %s bids, %d auctions, %d firms (%.1fs)\n",
            format(nrow(bids), big.mark = ","),
            length(unique(bids$auc_id)),
            length(unique(bids$cod_forn)),
            as.numeric(Sys.time() - t0)))

# -- compute pair co-bidding statistics --------------------------------
compute_stats <- function(df) {
  # df: data.table with columns cod_forn, auc_id (in stratum)
  # Drop firms with fewer than MIN_FIRM_BIDS auctions
  firm_counts <- df[, .N, by = cod_forn]
  keep_firms  <- firm_counts[N >= MIN_FIRM_BIDS, cod_forn]
  d <- df[cod_forn %in% keep_firms]

  if (length(unique(d$cod_forn)) < 2L) {
    return(list(T1 = NA_integer_, T2 = NA_real_, T3 = NA_integer_,
                n_firms = length(unique(d$cod_forn)),
                n_pairs = NA_integer_))
  }

  firms <- sort(unique(d$cod_forn))
  aucs  <- sort(unique(d$auc_id))

  # firm × auction sparse binary matrix
  fid <- match(d$cod_forn, firms)
  aid <- match(d$auc_id, aucs)
  M   <- sparseMatrix(i = fid, j = aid, x = 1,
                      dims = c(length(firms), length(aucs)))

  # co-bid counts: C[i,j] = number of auctions where firms i and j both bid
  # Use crossprod for symmetric A %*% A^T efficient for sparse
  C <- tcrossprod(M)
  C <- as(C, "TsparseMatrix")
  # extract upper triangle (i < j)
  ut <- C@i < C@j
  vals <- C@x[ut]
  if (length(vals) == 0L) {
    return(list(T1 = 0L, T2 = 0, T3 = 0L,
                n_firms = length(firms),
                n_pairs = 0L))
  }
  list(
    T1      = max(vals),
    T2      = unname(quantile(vals, 0.99)),
    T3      = sum(vals >= HI_THRESHOLD),
    n_firms = length(firms),
    n_pairs = length(vals)
  )
}

# -- per-stratum analysis ---------------------------------------------
strata <- unique(bids[, .(period, pharma_narrow)])
setorder(strata, pharma_narrow, period)

set.seed(SEED)
out_rows <- list()

for (s in seq_len(nrow(strata))) {
  per <- strata$period[s]
  ph  <- strata$pharma_narrow[s]
  d   <- bids[period == per & pharma_narrow == ph, .(cod_forn, auc_id)]

  ti <- Sys.time()
  obs <- compute_stats(d)

  # permutation null: shuffle cod_forn within stratum, recompute
  null_T1 <- integer(B); null_T2 <- numeric(B); null_T3 <- integer(B)
  for (b in seq_len(B)) {
    d_shuf <- copy(d)
    d_shuf[, cod_forn := sample(cod_forn)]
    s_b <- compute_stats(d_shuf)
    null_T1[b] <- s_b$T1
    null_T2[b] <- s_b$T2
    null_T3[b] <- s_b$T3
  }

  p_T1 <- mean(null_T1 >= obs$T1)
  p_T2 <- mean(null_T2 >= obs$T2)
  p_T3 <- mean(null_T3 >= obs$T3)

  out_rows[[length(out_rows) + 1L]] <- data.table(
    pharma_narrow = ph, period = per,
    n_firms = obs$n_firms, n_pairs = obs$n_pairs,
    T1_obs = obs$T1, T1_null_mean = mean(null_T1), p_T1 = p_T1,
    T2_obs = obs$T2, T2_null_mean = mean(null_T2), p_T2 = p_T2,
    T3_obs = obs$T3, T3_null_mean = mean(null_T3), p_T3 = p_T3
  )

  cat(sprintf("[stratum %d/%d] pharma=%d %-4s  firms=%d  pairs=%d\n",
              s, nrow(strata), ph, per, obs$n_firms, obs$n_pairs))
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
csv_path <- file.path(out_tables, "tab_collusion_screen_bajariye.csv")
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
    "%s & %s & %s & %d & %.1f & %s & %.1f & %.2f & %s & %d & %.1f & %s \\\\",
    res$lab[i],
    format(res$n_firms[i], big.mark = ","),
    format(res$n_pairs[i], big.mark = ","),
    res$T1_obs[i], res$T1_null_mean[i], mark_p(res$p_T1[i]),
    res$T2_obs[i], res$T2_null_mean[i], mark_p(res$p_T2[i]),
    res$T3_obs[i], res$T3_null_mean[i], mark_p(res$p_T3[i])
  )
}

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Bajari-Ye (2003) persistent-pair collusion screen.}",
  "\\label{tab:collusion_screen_bajariye}",
  "\\footnotesize",
  "\\setlength{\\tabcolsep}{4pt}",
  "\\providecommand{\\sym}[1]{\\textsuperscript{#1}}",
  "\\begin{tabular}{lrrrrrrrrrrr}",
  "\\toprule",
  " & & & \\multicolumn{3}{c}{$T_1$: max pair count} & \\multicolumn{3}{c}{$T_2$: 99\\%-tile pair count} & \\multicolumn{3}{c}{$T_3$: count$\\geq 5$} \\\\",
  "\\cmidrule(lr){4-6}\\cmidrule(lr){7-9}\\cmidrule(lr){10-12}",
  "Stratum & $N_{\\mathrm{firms}}$ & $N_{\\mathrm{pairs}}$ & Obs & Null & $p$ & Obs & Null & $p$ & Obs & Null & $p$ \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf(paste(
    "\\item Per-stratum analysis on Preg\\~ao auctions, firms with $\\geq %d$",
    "bids in the stratum. $N_{\\mathrm{pairs}}$ is the number of unordered firm",
    "pairs in the test. $T_1$ = maximum pair-cobidding count (most extreme outlier).",
    "$T_2$ = 99th percentile of the pair-cobidding distribution.",
    "$T_3$ = count of firm pairs co-bidding in at least %d auctions.",
    "Permutation null: $B = %d$ replicates re-shuffling the firm-label column",
    "within stratum, breaking firm-auction associations while preserving auction",
    "and bid-row counts. One-sided $p$-values report the probability under the null",
    "that the realized statistic is matched or exceeded by chance.",
    "Significance: \\sym{*} $p<0.10$, \\sym{**} $p<0.05$, \\sym{***} $p<0.01$.",
    "Following Bajari and Ye (2003), large $p$-values across the three statistics",
    "indicate that the bid clustering documented in",
    "Tables~\\ref{tab:collusion_screen}--\\ref{tab:collusion_screen_schurter}",
    "is distributed over the bidder population rather than concentrated in",
    "specific coordinated dyads."
  ), MIN_FIRM_BIDS, HI_THRESHOLD, B),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
tex_path <- file.path(out_tables, "tab_collusion_screen_bajariye.tex")
writeLines(tex_lines, tex_path)
cat(sprintf("[ok] tex written: %s\n", tex_path))

# -- console summary ---------------------------------------------------
cat("\n=== BAJARI-YE PERSISTENT-PAIR RESULTS ===\n")
print(res[, .(stratum = lab, n_firms, n_pairs,
              T1 = T1_obs, T1_null = round(T1_null_mean, 1), p_T1 = round(p_T1, 3),
              T2 = round(T2_obs, 1), T2_null = round(T2_null_mean, 2), p_T2 = round(p_T2, 3),
              T3 = T3_obs, T3_null = round(T3_null_mean, 1), p_T3 = round(p_T3, 3))])

cat(sprintf("\nTotal time: %.1fs\n", as.numeric(Sys.time() - t0)))
