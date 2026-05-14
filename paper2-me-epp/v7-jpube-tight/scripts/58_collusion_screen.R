# ----------------------------------------------------------------------
# Conley-style bid-pairing collusion screen on Pregão UH-clean residuals.
# Test of independence in bidding patterns against a sharp alternative
# in which bidder coordination produces clustered bids.
#
# Statistic (per auction): indicator that at least one consecutive gap
#   between sorted bids is below TAU = 0.005 (i.e., 0.5 percentage points
#   of the reference price). Sharp pairing under non-collusive bidding
#   is rare; under coordination it is systematically more common.
#
# Stratification: 4 cells (pharma_narrow × period). For each cell:
#   - Realized share of auctions with at least one close pair.
#   - Null distribution: B = 500 bootstrap replicates in which bid
#     sequences are resampled with replacement from the cell-level pool,
#     keeping each auction's bidder count fixed.
#   - One-sided p-value: P(null share >= realized share).
#
# Output:
#   output/tables/tab_collusion_screen.tex   (NOT yet \input'd)
#   output/tables/tab_collusion_screen.csv
#
# Inputs: data/processed/bids_uh_cleaned.parquet (c_norm_clean residual
# after Krasnokutskaya UH shrinkage, all-bidders).
# ----------------------------------------------------------------------

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube/scripts/seeds.R")
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})

root        <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v6-jpube"
out_tables  <- file.path(root, "output", "tables")
in_parquet  <- file.path(root, "data", "processed", "bids_uh_cleaned.parquet")
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

# -- parameters --------------------------------------------------------
TAU       <- 0.005      # close-pair threshold (0.5pp of p^ref)
B         <- 500        # bootstrap replicates
MIN_NBID  <- 3          # min bidders per auction (gap test needs ≥ 2 gaps)
SEED      <- seed_for_script(58)

# -- load + filter -----------------------------------------------------
t0 <- Sys.time()
bids <- as.data.table(read_parquet(in_parquet))
bids <- bids[mod == "pregao" &
             period %in% c("Pre", "Post") &
             !is.na(pharma_narrow) &
             c_norm_clean > 0 & c_norm_clean <= 3]
bids[, auc_id := paste(numerodaoc, codigoitem, sep = "_")]

cat(sprintf("[load] %s bids in %d auctions across %d strata (%.1fs)\n",
            format(nrow(bids), big.mark = ","),
            length(unique(bids$auc_id)),
            nrow(unique(bids[, .(period, pharma_narrow)])),
            as.numeric(Sys.time() - t0)))

# -- helper: per-auction close-pair indicator -------------------------
has_close_pair <- function(x, tau = TAU) {
  if (length(x) < MIN_NBID) return(NA_integer_)
  sx <- sort(x)
  as.integer(min(diff(sx)) < tau)
}

# -- realized statistic per stratum -----------------------------------
strata <- unique(bids[, .(period, pharma_narrow)])
setorder(strata, pharma_narrow, period)

set.seed(SEED)
results <- vector("list", nrow(strata))
for (i in seq_len(nrow(strata))) {
  per <- strata$period[i]
  ph  <- strata$pharma_narrow[i]
  d   <- bids[period == per & pharma_narrow == ph]

  # auction-level realized indicator
  auc <- d[, .(close = has_close_pair(c_norm_clean)),
           by = auc_id]
  auc <- auc[!is.na(close)]
  realized <- mean(auc$close)
  n_auc    <- nrow(auc)

  # auction sizes (only auctions with >= MIN_NBID bidders)
  auc_sizes <- d[auc_id %in% auc$auc_id, .N, by = auc_id]$N
  pool      <- d$c_norm_clean

  # bootstrap null
  ti <- Sys.time()
  null_shares <- numeric(B)
  for (b in seq_len(B)) {
    sim <- vapply(auc_sizes, function(n) {
      sx <- sort(sample(pool, n, replace = TRUE))
      as.integer(min(diff(sx)) < TAU)
    }, integer(1))
    null_shares[b] <- mean(sim)
  }
  pval     <- mean(null_shares >= realized)
  null_mu  <- mean(null_shares)
  null_se  <- sd(null_shares)

  cat(sprintf("[stratum %d/%d] pharma=%d period=%-4s  n_auc=%5d  realized=%.3f  null=%.3f (sd %.3f)  p=%.3f  (%.1fs)\n",
              i, nrow(strata), ph, per, n_auc, realized, null_mu, null_se, pval,
              as.numeric(Sys.time() - ti)))

  results[[i]] <- data.table(
    pharma_narrow = ph, period = per, n_auctions = n_auc,
    realized_share = realized, null_mean = null_mu,
    null_sd = null_se, p_value = pval
  )
}
res <- rbindlist(results)

# -- write CSV ---------------------------------------------------------
csv_path <- file.path(out_tables, "tab_collusion_screen.csv")
fwrite(res, csv_path)
cat(sprintf("\n[ok] csv written: %s\n", csv_path))

# -- format LaTeX ------------------------------------------------------
fmt3 <- function(x) sprintf("%.3f", x)

# build table body row by row, ordered: non-pharma Pre, non-pharma Post,
# pharma Pre, pharma Post.
res[, lab := paste0(
  ifelse(pharma_narrow == 1, "Pharma", "Non-pharma"),
  " ",
  period
)]
ord <- c("Non-pharma Pre", "Non-pharma Post", "Pharma Pre", "Pharma Post")
res <- res[match(ord, lab)]

mark_p <- function(p) {
  s <- fmt3(p)
  if (is.na(p)) return(s)
  if (p < 0.01) sprintf("\\textbf{%s}\\sym{***}", s)
  else if (p < 0.05) sprintf("\\textbf{%s}\\sym{**}", s)
  else if (p < 0.10) sprintf("%s\\sym{*}", s)
  else s
}

body <- character(nrow(res))
for (i in seq_len(nrow(res))) {
  body[i] <- sprintf(
    "%s & %s & %s & %s & %s & %s \\\\",
    res$lab[i],
    format(res$n_auctions[i], big.mark = ","),
    fmt3(res$realized_share[i]),
    fmt3(res$null_mean[i]),
    fmt3(res$null_sd[i]),
    mark_p(res$p_value[i])
  )
}

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Conley-style bid-pairing collusion screen on UH-clean Preg\\~ao residuals.}",
  "\\label{tab:collusion_screen}",
  "\\small",
  "\\setlength{\\tabcolsep}{6pt}",
  "\\providecommand{\\sym}[1]{\\textsuperscript{#1}}",
  "\\begin{tabular}{lrrrrr}",
  "\\toprule",
  "Stratum & $N_{\\mathrm{auc}}$ & Realized & Null mean & Null s.d. & $p$-value \\\\",
  "\\midrule",
  body,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf(
    paste(
      "\\item Test statistic: share of auctions in which the smallest gap",
      "between sorted UH-clean cost residuals is below $\\tau = %.3f$ of",
      "the reference price (a sharp bid-pairing signal). Auctions with",
      "fewer than %d bidders are excluded. Null distribution from $B = %d$",
      "bootstrap replicates that resample bid sequences with replacement",
      "from the cell-level pool while preserving each auction's bidder",
      "count, under independence of bid draws conditional on the cell.",
      "$p$-value reports the one-sided probability under the null that",
      "the realized share is matched or exceeded by chance.",
      "Significance: \\sym{*} $p<0.10$, \\sym{**} $p<0.05$, \\sym{***} $p<0.01$.",
      "Convergence between Convite GPV and Preg\\~ao drop-out recoveries",
      "in pharma non-SME Pre (Section~\\ref{sec:identification}) provides",
      "an independent consistency check against bid-coordination contamination",
      "in that stratum. The screen is not a formal test of collusion;",
      "it is a higher-power sharp-pairing diagnostic in the Conley--Decarolis",
      "(2016) tradition."
    ),
    TAU, MIN_NBID, B
  ),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
tex_path <- file.path(out_tables, "tab_collusion_screen.tex")
writeLines(tex_lines, tex_path)
cat(sprintf("[ok] tex written: %s\n", tex_path))

# -- console summary ---------------------------------------------------
cat("\nCollusion screen results (Pregão, UH-clean residuals):\n")
print(res[, .(stratum = lab, n_auc = n_auctions,
              realized = round(realized_share, 3),
              null_mean = round(null_mean, 3),
              null_sd = round(null_sd, 3),
              p_value = round(p_value, 3))])

cat(sprintf("\nTotal time: %.1fs\n", as.numeric(Sys.time() - t0)))
