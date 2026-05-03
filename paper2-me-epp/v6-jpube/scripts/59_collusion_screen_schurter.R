# ----------------------------------------------------------------------
# Schurter (2017) anchor-controlled bid-pairing collusion screen.
#
# The raw Conley screen (script 58) rejects independence in all four
# pharma × period strata. Two innocent explanations remain:
#
#   (A) reference-price anchoring + bid-increment discreteness, which
#       compresses bid distributions toward a common scale and
#       mechanically generates close pairs without coordination, and
#   (B) variation in n_bidders, which mechanically produces more close
#       pairs in auctions with more bidders (more gaps to be small).
#
# Schurter (2017) approach: condition the null distribution on
# observable auction-level features that proxy for anchoring intensity,
# instead of resampling from the stratum-wide pool. If the realized
# share still exceeds the conditional null, the excess is something
# beyond the anchoring/discreteness story.
#
# This script reports the test under three conditioning regimes:
#   (i)   raw (no conditioning)              — replicates script 58
#   (ii)  conditional on n_bidders bin
#   (iii) conditional on intra-auction bid-range quartile (anchor proxy:
#         tight range = strong anchor; wide range = weak anchor)
#
# Statistic: same close-pair indicator as script 58 (gap < TAU = 0.005).
# Bootstrap: B = 500 replicates per regime per stratum.
# Output:
#   output/tables/tab_collusion_screen_schurter.csv
#   output/tables/tab_collusion_screen_schurter.tex   (NOT yet \input'd)
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

TAU      <- 0.005
B        <- 500
MIN_NBID <- 3
SEED     <- seed_for_script(59)

# -- load + filter -----------------------------------------------------
t0 <- Sys.time()
bids <- as.data.table(read_parquet(in_parquet))
bids <- bids[mod == "pregao" &
             period %in% c("Pre", "Post") &
             !is.na(pharma_narrow) &
             c_norm_clean > 0 & c_norm_clean <= 3]
bids[, auc_id := paste(numerodaoc, codigoitem, sep = "_")]

# Auction-level features
auc_feat <- bids[, .(
  n_bid    = .N,
  bid_min  = min(c_norm_clean),
  bid_max  = max(c_norm_clean),
  bid_rng  = max(c_norm_clean) - min(c_norm_clean)
), by = .(period, pharma_narrow, auc_id)]
auc_feat <- auc_feat[n_bid >= MIN_NBID]

cat(sprintf("[load] %s bids in %d eligible auctions (n_bid >= %d) (%.1fs)\n",
            format(nrow(bids), big.mark = ","),
            nrow(auc_feat), MIN_NBID,
            as.numeric(Sys.time() - t0)))

# -- realized close-pair indicator per auction ------------------------
realized <- bids[, .(
  close = {
    sx <- sort(c_norm_clean)
    if (length(sx) < MIN_NBID) NA_integer_
    else as.integer(min(diff(sx)) < TAU)
  }
), by = .(period, pharma_narrow, auc_id)]
realized <- realized[!is.na(close)]

# -- bin construction --------------------------------------------------
# n_bidders: 3, 4, 5, 6+
auc_feat[, nbid_bin := pmin(n_bid, 6L)]
auc_feat[, nbid_bin := factor(nbid_bin,
                              levels = 3:6,
                              labels = c("3", "4", "5", "6+"))]

# Bid-range quartile within stratum
auc_feat[, rng_q := cut(bid_rng,
                        breaks = quantile(bid_rng,
                                          probs = seq(0, 1, by = 0.25),
                                          na.rm = TRUE),
                        labels = c("Q1_tight", "Q2", "Q3", "Q4_wide"),
                        include.lowest = TRUE),
         by = .(period, pharma_narrow)]

# Merge bins back onto realized
realized <- merge(realized, auc_feat[, .(auc_id, nbid_bin, rng_q, n_bid)],
                  by = "auc_id", all.x = TRUE)

# -- bootstrap helper --------------------------------------------------
# Given a vector of auction sizes and a pool of bids, return null share.
boot_null_share <- function(sizes, pool, B, tau = TAU) {
  if (length(sizes) == 0L || length(pool) < max(sizes)) return(NA_real_)
  shares <- numeric(B)
  for (b in seq_len(B)) {
    sim <- vapply(sizes, function(n) {
      sx <- sort(sample(pool, n, replace = TRUE))
      as.integer(min(diff(sx)) < tau)
    }, integer(1))
    shares[b] <- mean(sim)
  }
  shares
}

# -- run three conditioning regimes per stratum -----------------------
strata <- unique(realized[, .(period, pharma_narrow)])
setorder(strata, pharma_narrow, period)

set.seed(SEED)
out_rows <- list()
row_idx  <- 1L

for (s in seq_len(nrow(strata))) {
  per <- strata$period[s]
  ph  <- strata$pharma_narrow[s]

  d_realized <- realized[period == per & pharma_narrow == ph]
  d_bids     <- bids[period == per & pharma_narrow == ph]
  realized_share <- mean(d_realized$close)
  n_auc          <- nrow(d_realized)

  # --- regime (i): raw ---------------------------------------------
  ti <- Sys.time()
  null_raw <- boot_null_share(d_realized$n_bid, d_bids$c_norm_clean, B)
  out_rows[[row_idx]] <- data.table(
    pharma_narrow = ph, period = per,
    regime = "raw",
    n_auctions = n_auc,
    realized_share = realized_share,
    null_mean = mean(null_raw), null_sd = sd(null_raw),
    p_value = mean(null_raw >= realized_share)
  )
  row_idx <- row_idx + 1L
  cat(sprintf("[%-15s pharma=%d %-4s] realized=%.3f null_raw=%.3f p=%.3f (%.1fs)\n",
              "raw", ph, per, realized_share,
              mean(null_raw), mean(null_raw >= realized_share),
              as.numeric(Sys.time() - ti)))

  # --- regime (ii): conditional on n_bidders bin -------------------
  ti <- Sys.time()
  bins_n <- split(d_realized, d_realized$nbid_bin)
  null_bin_n_means <- numeric(B)
  for (b in seq_len(B)) {
    cell_share <- numeric(0)
    cell_w     <- numeric(0)
    for (bn in names(bins_n)) {
      cell <- bins_n[[bn]]
      if (nrow(cell) == 0L) next
      pool_cell <- d_bids[auc_id %in% cell$auc_id, c_norm_clean]
      if (length(pool_cell) < max(cell$n_bid)) next
      sim <- vapply(cell$n_bid, function(n) {
        sx <- sort(sample(pool_cell, n, replace = TRUE))
        as.integer(min(diff(sx)) < TAU)
      }, integer(1))
      cell_share <- c(cell_share, mean(sim))
      cell_w     <- c(cell_w, nrow(cell))
    }
    null_bin_n_means[b] <- weighted.mean(cell_share, cell_w)
  }
  out_rows[[row_idx]] <- data.table(
    pharma_narrow = ph, period = per,
    regime = "cond_nbidders",
    n_auctions = n_auc,
    realized_share = realized_share,
    null_mean = mean(null_bin_n_means), null_sd = sd(null_bin_n_means),
    p_value = mean(null_bin_n_means >= realized_share)
  )
  row_idx <- row_idx + 1L
  cat(sprintf("[%-15s pharma=%d %-4s] realized=%.3f null=%.3f p=%.3f (%.1fs)\n",
              "cond_nbidders", ph, per, realized_share,
              mean(null_bin_n_means), mean(null_bin_n_means >= realized_share),
              as.numeric(Sys.time() - ti)))

  # --- regime (iii): conditional on bid-range quartile -------------
  ti <- Sys.time()
  bins_r <- split(d_realized, d_realized$rng_q)
  null_bin_r_means <- numeric(B)
  for (b in seq_len(B)) {
    cell_share <- numeric(0)
    cell_w     <- numeric(0)
    for (bn in names(bins_r)) {
      cell <- bins_r[[bn]]
      if (nrow(cell) == 0L) next
      pool_cell <- d_bids[auc_id %in% cell$auc_id, c_norm_clean]
      if (length(pool_cell) < max(cell$n_bid)) next
      sim <- vapply(cell$n_bid, function(n) {
        sx <- sort(sample(pool_cell, n, replace = TRUE))
        as.integer(min(diff(sx)) < TAU)
      }, integer(1))
      cell_share <- c(cell_share, mean(sim))
      cell_w     <- c(cell_w, nrow(cell))
    }
    null_bin_r_means[b] <- weighted.mean(cell_share, cell_w)
  }
  out_rows[[row_idx]] <- data.table(
    pharma_narrow = ph, period = per,
    regime = "cond_range",
    n_auctions = n_auc,
    realized_share = realized_share,
    null_mean = mean(null_bin_r_means), null_sd = sd(null_bin_r_means),
    p_value = mean(null_bin_r_means >= realized_share)
  )
  row_idx <- row_idx + 1L
  cat(sprintf("[%-15s pharma=%d %-4s] realized=%.3f null=%.3f p=%.3f (%.1fs)\n",
              "cond_range", ph, per, realized_share,
              mean(null_bin_r_means), mean(null_bin_r_means >= realized_share),
              as.numeric(Sys.time() - ti)))
}

res <- rbindlist(out_rows)

# -- write CSV ---------------------------------------------------------
csv_path <- file.path(out_tables, "tab_collusion_screen_anchor.csv")
fwrite(res, csv_path)
cat(sprintf("\n[ok] csv written: %s\n", csv_path))

# -- format LaTeX (3 panels: raw, cond_nbidders, cond_range) ----------
res[, lab := paste0(
  ifelse(pharma_narrow == 1, "Pharma", "Non-pharma"), " ", period)]
ord <- c("Non-pharma Pre", "Non-pharma Post", "Pharma Pre", "Pharma Post")

mark_p <- function(p) {
  s <- sprintf("%.3f", p)
  if (is.na(p)) return(s)
  if (p < 0.01) sprintf("\\textbf{%s}\\sym{***}", s)
  else if (p < 0.05) sprintf("\\textbf{%s}\\sym{**}", s)
  else if (p < 0.10) sprintf("%s\\sym{*}", s)
  else s
}

panel_block <- function(panel_name, regime_key) {
  d <- res[regime == regime_key]
  d <- d[match(ord, lab)]
  rows <- character(nrow(d))
  for (i in seq_len(nrow(d))) {
    rows[i] <- sprintf(
      "%s & %s & %s & %s & %s \\\\",
      d$lab[i],
      sprintf("%.3f", d$realized_share[i]),
      sprintf("%.3f", d$null_mean[i]),
      sprintf("%.3f", d$null_sd[i]),
      mark_p(d$p_value[i])
    )
  }
  c(sprintf("\\multicolumn{5}{l}{\\emph{%s}} \\\\", panel_name),
    "\\midrule",
    rows)
}

tex_lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Anchor-controlled bid-pairing screen.}",
  "\\label{tab:collusion_screen_anchor}",
  "\\small",
  "\\setlength{\\tabcolsep}{6pt}",
  "\\providecommand{\\sym}[1]{\\textsuperscript{#1}}",
  "\\begin{tabular}{lrrrr}",
  "\\toprule",
  "Stratum & Realized & Null mean & Null s.d. & $p$-value \\\\",
  panel_block("Panel A. Raw test (script 58)",       "raw"),
  panel_block("Panel B. Conditional on $n$ bidders", "cond_nbidders"),
  panel_block("Panel C. Conditional on bid-range quartile", "cond_range"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf(paste(
    "\\item Test statistic: share of auctions in which the smallest gap between",
    "sorted UH-clean cost residuals is below $\\tau = %.3f$ of the reference price.",
    "$B = %d$ bootstrap replicates per regime per stratum. \\emph{Panel A} resamples",
    "from the unconditional cell-level pool (raw Conley screen, replicates",
    "Table~\\ref{tab:collusion_screen}).",
    "\\emph{Panel B} resamples within bins of $n_{\\mathrm{bidders}}\\in\\{3,4,5,6+\\}$,",
    "controlling for the mechanical effect that auctions with more bidders have",
    "more potential close pairs.",
    "\\emph{Panel C} resamples within within-stratum quartiles of the intra-auction",
    "bid range $R = \\max(c_\\varepsilon) - \\min(c_\\varepsilon)$, the natural",
    "anchor-intensity proxy: tight-range auctions are mechanically anchored to a",
    "common scale, wide-range auctions are not. Conditioning the null distribution",
    "on observable auction-level features that proxy for anchor intensity absorbs",
    "the bid clustering attributable to common reference points and bid-increment",
    "discreteness, separating that mechanism from genuine coordination.",
    "Significance: \\sym{*} $p<0.10$, \\sym{**} $p<0.05$, \\sym{***} $p<0.01$.",
    "Auctions with $n<%d$ bidders are excluded.",
    "$p$-values that survive Panel C are evidence of clustering beyond the",
    "anchor/discreteness story; $p$-values that disappear in Panel C are evidence",
    "that the raw rejection of Panel A is anchoring artifact, not coordination."
  ), TAU, B, MIN_NBID),
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)
tex_path <- file.path(out_tables, "tab_collusion_screen_anchor.tex")
writeLines(tex_lines, tex_path)
cat(sprintf("[ok] tex written: %s\n", tex_path))

# -- console summary ---------------------------------------------------
cat("\n=== SCHURTER ANCHOR-CONTROLLED RESULTS ===\n")
print(res[, .(stratum = lab, regime, n_auc = n_auctions,
              realized = round(realized_share, 3),
              null_mean = round(null_mean, 3),
              p_value = round(p_value, 3))])

cat(sprintf("\nTotal time: %.1fs\n", as.numeric(Sys.time() - t0)))
