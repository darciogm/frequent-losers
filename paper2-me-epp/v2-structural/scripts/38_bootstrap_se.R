# ============================================================================
# 38_bootstrap_se.R — Sprint 7: block-bootstrap SEs for structural estimates
# ============================================================================
# The structural results reported in scripts 35 (CPV asymmetric) and 36
# (welfare counterfactuals) are point estimates with no uncertainty bands.
# For top-journal submission they need SEs + CIs.
#
# Bootstrap design:
#   - Unit of resampling: AUCTION (numerodaoc × codigoitem).  Resampling
#     auctions rather than individual bids preserves within-auction
#     correlation in bids (same N, shared reference price, strategic
#     interdependence).
#   - B = 200 bootstrap replicates (minimum for stable SEs; 500+ would
#     give sharper CIs but with 10s per replicate gets expensive).
#   - For each replicate: re-estimate G_A, g_A, G_B, g_B per stratum,
#     re-run CPV inversion, re-compute summary stats, decomposition
#     weights, and counterfactual Pareto points.
#
# Stored quantities per replicate:
#   (i) Mean c_norm by (period, type)
#  (ii) Primitive-invariance shift: mean_Post - mean_Pre, by type
# (iii) Decomposition weights: intensive%, entry%, by N-bin
#  (iv) Counterfactual cost recovery at key thresholds (50/75/90/95 pct)
#
# Output:
#   data/processed/bootstrap_convite.parquet — B rows of stats
#   output/tables/tab_v2_bootstrap_se.{tex,csv} — final with SEs + 95% CIs
#   logs/38_bootstrap_se.log
# ============================================================================

if (!exists(".script_dir")) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  .script_dir <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1])) else "scripts"
}
source(file.path(.script_dir, "utils_v2.R"), local = TRUE)

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})

setDTthreads(12)
log_msg("=== 38_bootstrap_se.R — block-bootstrap SEs ===")
log_mem("startup")

B <- 200L    # bootstrap replicates
set.seed(20260420L)

# ============================================================================
# 1. LOAD SOURCE DATA ONCE
# ============================================================================
log_msg("Loading Convite G65 firm-auction data...")
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
bl <- bl[g65 == 1L]

# Pre-collapse to firm-auction for speed
fa_all <- bl[, .(
    bid   = min(bid_price, na.rm = TRUE),
    won   = max(won, na.rm = TRUE),
    sme   = max(sme_proxy, na.rm = TRUE),
    ref   = mean(ref_price, na.rm = TRUE)
  ),
  by = .(numerodaoc, codigoitem, codigofornecedor, data_oc_numb, Pre, pharma)]

# Auction IDs (integer-coded for fast resampling)
fa_all[, auction_id := .GRP, by = .(numerodaoc, codigoitem)]
unique_auctions <- unique(fa_all$auction_id)
n_auc <- length(unique_auctions)
log_msg(sprintf("  %s unique auctions, %s firm-auction rows",
                format(n_auc, big.mark = ","),
                format(nrow(fa_all), big.mark = ",")))

# ============================================================================
# 2. CORE ESTIMATION FUNCTION
# ============================================================================
# Returns a single-row data.table with all summary statistics for one
# bootstrap sample. Reused for the point estimate (b=0) and for B replicates.

one_estimation <- function(fa_sample) {
  # Auction composition
  au <- fa_sample[, .(
      N   = .N,
      n_A = sum(sme == 1L),
      n_B = sum(sme == 0L),
      ref = mean(ref, na.rm = TRUE)
    ), by = .(auction_id, Pre)]
  fa <- merge(fa_sample, au[, .(auction_id, N, n_A, n_B)],
              by = "auction_id")
  fa[, b_norm := bid / ref]

  # Filter
  fa <- fa[N >= 2L & is.finite(bid) & bid > 0 &
           is.finite(ref) & ref > 0 &
           b_norm > 0.005 & b_norm < 2]
  if (nrow(fa) < 1000) return(NULL)

  # Stratify
  fa[, period_lbl := fifelse(Pre == 1L, "Pre", "Post")]
  fa[, sme_lbl    := fifelse(sme  == 1L, "SME", "NonSME")]
  fa[, N_bin      := fifelse(N == 2L, "N=2",
                     fifelse(N == 3L, "N=3",
                      fifelse(N == 4L, "N=4", "N>=5")))]

  # CPV inversion per (period, N_bin) stratum
  fa_cpv <- data.table()
  for (per in c("Pre", "Post")) {
    for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
      sub <- fa[period_lbl == per & N_bin == Nb]
      if (nrow(sub) < 200) next
      b_A <- sub[sme == 1L, b_norm]
      b_B <- sub[sme == 0L, b_norm]
      if (length(b_A) < 50 || length(b_B) < 50) next

      # Kernel estimates per type
      hA <- 1.06 * sd(b_A) * length(b_A)^(-1/5)
      hB <- 1.06 * sd(b_B) * length(b_B)^(-1/5)
      if (!is.finite(hA) || hA <= 0) hA <- 0.01
      if (!is.finite(hB) || hB <= 0) hB <- 0.01
      dA <- density(b_A, bw = hA, n = 256,
                    from = min(b_A), to = max(b_A), kernel = "gaussian")
      dB <- density(b_B, bw = hB, n = 256,
                    from = min(b_B), to = max(b_B), kernel = "gaussian")
      ecA <- ecdf(b_A); ecB <- ecdf(b_B)

      # Evaluate at each bid
      in_suppA <- sub$b_norm >= min(b_A) & sub$b_norm <= max(b_A)
      in_suppB <- sub$b_norm >= min(b_B) & sub$b_norm <= max(b_B)
      g_A <- rep(1e-8, nrow(sub)); G_A <- rep(NA_real_, nrow(sub))
      g_B <- rep(1e-8, nrow(sub)); G_B <- rep(NA_real_, nrow(sub))
      g_A[in_suppA] <- pmax(approx(dA$x, dA$y,
                                   xout = sub$b_norm[in_suppA], rule = 2)$y, 1e-8)
      G_A[in_suppA] <- ecA(sub$b_norm[in_suppA])
      G_A[sub$b_norm < min(b_A)] <- 0
      G_A[sub$b_norm > max(b_A)] <- 1
      g_B[in_suppB] <- pmax(approx(dB$x, dB$y,
                                   xout = sub$b_norm[in_suppB], rule = 2)$y, 1e-8)
      G_B[in_suppB] <- ecB(sub$b_norm[in_suppB])
      G_B[sub$b_norm < min(b_B)] <- 0
      G_B[sub$b_norm > max(b_B)] <- 1

      sub[, `:=`(hazA = g_A / pmax(1 - G_A, 1e-6),
                 hazB = g_B / pmax(1 - G_B, 1e-6))]
      sub[, `:=`(n_A_star = fifelse(sme == 1L, n_A - 1L, n_A),
                 n_B_star = fifelse(sme == 1L, n_B,     n_B - 1L))]
      sub[, denom := pmax(n_A_star * hazA + n_B_star * hazB, 1e-6)]
      sub[, c_norm := b_norm - 1 / denom]

      fa_cpv <- rbind(fa_cpv, sub, fill = TRUE)
    }
  }
  if (nrow(fa_cpv) == 0) return(NULL)

  # Clean
  clean <- fa_cpv[is.finite(c_norm) & c_norm > 0.001 & c_norm < 1.5]

  # ---- Summary statistics --------------------------------------------
  cs <- clean[, .(mean_c = mean(c_norm)),
              by = .(period_lbl, sme_lbl)]
  # Primitive-invariance shift
  nonsme_pre  <- cs[period_lbl == "Pre"  & sme_lbl == "NonSME", mean_c]
  nonsme_post <- cs[period_lbl == "Post" & sme_lbl == "NonSME", mean_c]
  sme_pre     <- cs[period_lbl == "Pre"  & sme_lbl == "SME",    mean_c]
  sme_post    <- cs[period_lbl == "Post" & sme_lbl == "SME",    mean_c]

  shift_nonsme <- if (length(nonsme_pre) == 1 && length(nonsme_post) == 1) {
    nonsme_post - nonsme_pre
  } else NA_real_
  shift_sme <- if (length(sme_pre) == 1 && length(sme_post) == 1) {
    sme_post - sme_pre
  } else NA_real_

  # ---- Decomposition (intensive vs entry) by N-bin ------------------
  # Empirical survival functions
  grid <- seq(0.005, 2, length.out = 500)
  emp_surv <- function(x) 1 - ecdf(x)(grid)
  exp_min_joint <- function(S_A, n_A, S_B, n_B) {
    s_joint <- S_A^n_A * S_B^n_B
    dg <- diff(grid)
    mid <- (s_joint[-1] + s_joint[-length(s_joint)]) / 2
    grid[1] + sum(mid * dg)
  }
  exp_min_single <- function(S, k) {
    s <- S^k
    dg <- diff(grid)
    mid <- (s[-1] + s[-length(s)]) / 2
    grid[1] + sum(mid * dg)
  }

  decomp <- data.table()
  for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
    sub_pre  <- fa[period_lbl == "Pre"  & N_bin == Nb]
    sub_post <- fa[period_lbl == "Post" & N_bin == Nb]
    if (nrow(sub_pre) < 200 || nrow(sub_post) < 200) next
    SA_pre  <- emp_surv(sub_pre[sme == 1L, b_norm])
    SB_pre  <- emp_surv(sub_pre[sme == 0L, b_norm])
    SA_post <- emp_surv(sub_post[sme == 1L, b_norm])
    # Average composition
    au_Nb <- au[auction_id %in% sub_pre$auction_id][, N_bin := Nb]
    comp <- au[auction_id %in% unique(sub_pre$auction_id)]
    comp[, N_bin := fifelse(N == 2L, "N=2",
                   fifelse(N == 3L, "N=3",
                    fifelse(N == 4L, "N=4", "N>=5")))]
    comp <- comp[N_bin == Nb & Pre == 1L]
    if (nrow(comp) < 20) next
    # Decomposition requires auctions with at least one SME (else S2 and S3
    # undefined). Filter comp to n_A >= 1 for the S2/S3 expectations; S1
    # can use full composition (mixed auctions with n_A = 0 are defined:
    # S_A^0 = 1, so expected min is just min of n_B non-SME bids).
    e_S1 <- mean(mapply(function(nA, nB) exp_min_joint(SA_pre, nA, SB_pre, nB),
                        comp$n_A, comp$n_B), na.rm = TRUE)
    comp_has_sme <- comp[n_A >= 1]
    if (nrow(comp_has_sme) == 0) next
    e_S2 <- mean(sapply(comp_has_sme$n_A,
                        function(nA) exp_min_single(SA_pre,  nA)), na.rm = TRUE)
    e_S3 <- mean(sapply(comp_has_sme$n_A,
                        function(nA) exp_min_single(SA_post, nA)), na.rm = TRUE)
    decomp <- rbind(decomp, data.table(
      N_bin    = Nb,
      intensive = e_S2 - e_S1,
      entry     = e_S3 - e_S2,
      total     = e_S3 - e_S1
    ))
  }
  decomp[, intens_pct := 100 * intensive / total]
  decomp[, entry_pct  := 100 * entry     / total]
  # Weighted average across N-bins
  avg_intens_pct <- if (nrow(decomp) > 0) mean(decomp$intens_pct, na.rm = TRUE) else NA_real_
  avg_entry_pct  <- if (nrow(decomp) > 0) mean(decomp$entry_pct,  na.rm = TRUE) else NA_real_

  # ---- Value-threshold cost recovery at 75th percentile --------------
  # Use all Pre auctions within this bootstrap to compute percentiles
  au_pre <- au[Pre == 1L & auction_id %in% unique(fa$auction_id)]
  au_pre[, N_bin := fifelse(N == 2L, "N=2",
                    fifelse(N == 3L, "N=3",
                     fifelse(N == 4L, "N=4", "N>=5")))]
  # Compute per-auction S1 vs S3
  au_pre[, E_S1 := NA_real_]; au_pre[, E_S3 := NA_real_]
  for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
    sub_pre  <- fa[period_lbl == "Pre"  & N_bin == Nb]
    sub_post <- fa[period_lbl == "Post" & N_bin == Nb]
    if (nrow(sub_pre) < 200 || nrow(sub_post) < 200) next
    SA_pre  <- emp_surv(sub_pre[sme == 1L, b_norm])
    SB_pre  <- emp_surv(sub_pre[sme == 0L, b_norm])
    SA_post <- emp_surv(sub_post[sme == 1L, b_norm])
    idx <- which(au_pre$N_bin == Nb)
    if (length(idx) == 0) next
    for (i in idx) {
      nA <- au_pre$n_A[i]; nB <- au_pre$n_B[i]
      au_pre$E_S1[i] <- exp_min_joint(SA_pre, nA, SB_pre, nB)
      if (nA >= 1) au_pre$E_S3[i] <- exp_min_single(SA_post, nA)
    }
  }
  au_pre[, price_effect_R := (E_S3 - E_S1) * ref]
  total_cost <- sum(au_pre$price_effect_R, na.rm = TRUE)

  recover_pct <- function(pct_threshold) {
    # Exempt auctions ABOVE this percentile threshold of ref
    q <- quantile(au_pre$ref, pct_threshold, na.rm = TRUE)
    cost_with_exemption <- sum(au_pre$price_effect_R[au_pre$ref <= q],
                               na.rm = TRUE)
    100 * (1 - cost_with_exemption / total_cost)
  }
  rec50 <- recover_pct(0.50)
  rec75 <- recover_pct(0.75)
  rec90 <- recover_pct(0.90)

  # Return one-row summary
  data.table(
    mean_c_nonsme_pre  = if (length(nonsme_pre) == 1) nonsme_pre else NA_real_,
    mean_c_nonsme_post = if (length(nonsme_post) == 1) nonsme_post else NA_real_,
    mean_c_sme_pre     = if (length(sme_pre) == 1) sme_pre else NA_real_,
    mean_c_sme_post    = if (length(sme_post) == 1) sme_post else NA_real_,
    shift_nonsme       = shift_nonsme,
    shift_sme          = shift_sme,
    decomp_intens_pct  = avg_intens_pct,
    decomp_entry_pct   = avg_entry_pct,
    recover_50pct      = rec50,
    recover_75pct      = rec75,
    recover_90pct      = rec90,
    total_cost_R       = total_cost
  )
}

# ============================================================================
# 3. POINT ESTIMATE (b = 0)
# ============================================================================
log_msg("Computing point estimate on full sample...")
point_est <- one_estimation(fa_all)
log_msg("Point estimate:")
print(point_est)
log_mem("after point")

# ============================================================================
# 4. BOOTSTRAP LOOP
# ============================================================================
log_msg(sprintf("Starting bootstrap loop with B=%d replicates...", B))
log_msg(sprintf("  Each replicate ~10-15s; total ~%.0f-%.0f min",
                as.numeric(B)/6, as.numeric(B)/4))

boot_results <- vector("list", B)
t_start <- Sys.time()
setkey(fa_all, auction_id)
for (b in seq_len(B)) {
  # Resample auctions with replacement. Give each draw a unique
  # `resample_id` so that duplicates are not collapsed by downstream
  # `by = auction_id` groupings inside one_estimation.
  sampled_ids <- sample(unique_auctions, size = n_auc, replace = TRUE)
  sampled_tbl <- data.table(auction_id  = sampled_ids,
                            resample_id = seq_along(sampled_ids))

  fa_b <- fa_all[sampled_tbl, on = "auction_id", allow.cartesian = TRUE]
  # Overwrite auction_id with the unique resample_id so that each
  # resampled draw is treated as its own auction downstream.
  fa_b[, auction_id := resample_id]
  fa_b[, resample_id := NULL]

  # Re-estimate
  suppressWarnings({
    rep_est <- tryCatch(one_estimation(fa_b), error = function(e) NULL)
  })
  if (!is.null(rep_est)) {
    rep_est[, b := b]
    boot_results[[b]] <- rep_est
  }

  if (b %% 25 == 0L) {
    elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
    rate    <- elapsed / b
    eta     <- rate * (B - b)
    log_msg(sprintf("  replicate %d/%d (%.1f min elapsed; ~%.1f min remaining)",
                    b, B, elapsed, eta))
  }
}

boot_tab <- rbindlist(boot_results, use.names = TRUE, fill = TRUE)
log_msg(sprintf("Bootstrap complete: %d / %d replicates successful",
                nrow(boot_tab), B))

# Save raw bootstrap results
write_parquet(boot_tab, file.path(V2_DATA, "bootstrap_convite.parquet"))

# ============================================================================
# 5. COMPUTE SEs AND CIs
# ============================================================================
log_msg("")
log_msg("Computing SEs and 95% percentile CIs...")

summary_stats <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 10) return(c(NA_real_, NA_real_, NA_real_, NA_real_))
  c(mean = mean(x),
    sd   = sd(x),
    q025 = quantile(x, 0.025),
    q975 = quantile(x, 0.975))
}

vars <- c("mean_c_nonsme_pre", "mean_c_nonsme_post",
          "mean_c_sme_pre",    "mean_c_sme_post",
          "shift_nonsme",      "shift_sme",
          "decomp_intens_pct", "decomp_entry_pct",
          "recover_50pct",     "recover_75pct", "recover_90pct",
          "total_cost_R")
boot_sum <- lapply(vars, function(v) {
  x  <- boot_tab[[v]]
  st <- summary_stats(x)
  pt <- point_est[[v]]
  data.table(
    stat       = v,
    point_est  = round(as.numeric(pt), 4),
    boot_mean  = round(as.numeric(st[1]), 4),
    boot_SE    = round(as.numeric(st[2]), 4),
    CI95_lower = round(as.numeric(st[3]), 4),
    CI95_upper = round(as.numeric(st[4]), 4)
  )
})
boot_sum_tab <- rbindlist(boot_sum, use.names = TRUE)
log_msg("Structural estimates with bootstrap SEs and 95% CIs:")
print(boot_sum_tab)
fwrite(boot_sum_tab, file.path(V2_TABLES, "tab_v2_bootstrap_se.csv"))

# LaTeX
sink(file.path(V2_TABLES, "tab_v2_bootstrap_se.tex"))
cat("% Auto-generated by 38_bootstrap_se.R\n")
cat("\\begin{tabular}{lrrrrr}\n\\toprule\n")
cat("Statistic & Point est. & Boot mean & Boot SE & 95\\% CI lower & 95\\% CI upper \\\\\n\\midrule\n")
for (i in seq_len(nrow(boot_sum_tab))) {
  with(boot_sum_tab[i], cat(
    gsub("_", "\\\\_", stat), "&",
    sprintf("%.4f", point_est), "&",
    sprintf("%.4f", boot_mean), "&",
    sprintf("(%.4f)", boot_SE), "&",
    sprintf("%.4f", CI95_lower), "&",
    sprintf("%.4f", CI95_upper), "\\\\\n"))
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()

log_mem("final")
log_msg("=== 38_bootstrap_se.R: DONE ===")
