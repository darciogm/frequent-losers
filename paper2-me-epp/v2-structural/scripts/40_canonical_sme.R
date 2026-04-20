# ============================================================================
# 40_canonical_sme.R — Sprint 9: canonical me_epp SME classification
# ============================================================================
# The structural pilots (scripts 35-39) used a firm-registry proxy for SME
# status: sme_proxy = 1 if porte_empresa in {01,03} or fornec_enquad in {1,2}.
# That proxy is time-invariant and conservative; it captures ME and EPP
# classifications as recorded in the Firms_final registry.
#
# The BEC-CANONICAL classification is the me_epp self-declaration
# submitted at each bid. This reflects the policy-relevant SME status
# (ME/EPP under LC 123/2006) firms claimed at the moment of bidding. It
# is the classification the procurement rule ACTUALLY applies.
#
# Strategy for building a bidder-level canonical SME flag:
#   1. Extract per-CNPJ modal me_epp from the raw CSV (at POI-winner level;
#      firms frequently appear as winners, revealing their SME status).
#      Done by helper script _extract_cnpj_me_epp.py → /tmp/p2_cnpj_me_epp.parquet.
#   2. Merge with bid-level Convite G65 using códigofornecedor.
#   3. For CNPJs that never won (so never appeared in the POI-level winner
#      records), fall back to the firm-registry proxy.
#
# This yields `sme_canonical` per bidder-auction, which is the RIGHT-sided
# version of sme_proxy for structural estimation.
#
# Then re-run the core structural pipeline (CPV → stability → decomposition
# → DWL) and report how the headline numbers shift under the canonical
# classification.
#
# Outputs:
#   data/processed/bid_level_convite_canonical.parquet
#   output/tables/tab_v2_canonical_comparison.csv  — side-by-side
#   logs/40_canonical_sme.log
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
log_msg("=== 40_canonical_sme.R — canonical me_epp classification ===")
log_mem("startup")

# ============================================================================
# 1. LOAD CANONICAL me_epp PER CNPJ
# ============================================================================
me_epp_path <- "/tmp/p2_cnpj_me_epp.parquet"
if (!file.exists(me_epp_path)) {
  log_msg("Building canonical me_epp table via Python helper...")
  system2("python3", file.path(.script_dir, "_extract_cnpj_me_epp.py"),
          stdout = "", stderr = "")
}
canon <- as.data.table(read_parquet(me_epp_path))
setnames(canon, "cnpj", "codigofornecedor")
log_msg(sprintf("  canonical table: %s CNPJs (%.1f%% majority SME)",
                format(nrow(canon), big.mark = ","),
                100 * mean(canon$sme_canonical)))

# ============================================================================
# 2. MERGE WITH BID-LEVEL CONVITE G65 AND COMPARE PROXIES
# ============================================================================
log_msg("Loading bid-level Convite G65...")
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
bl <- bl[g65 == 1L]

# Merge canonical
bl <- merge(bl, canon[, .(codigofornecedor, sme_canonical,
                          n_wins_observed, pct_sme_declared)],
            by = "codigofornecedor", all.x = TRUE)

# Diagnostic: match rate
n_matched <- sum(!is.na(bl$sme_canonical))
log_msg(sprintf("  matched to canonical: %s / %s (%.1f%%)",
                format(n_matched, big.mark = ","),
                format(nrow(bl), big.mark = ","),
                100 * n_matched / nrow(bl)))

# Fallback for unmatched: use firm-registry proxy
bl[is.na(sme_canonical), sme_canonical := sme_proxy]
log_msg(sprintf("  after fallback: %.1f%% still NA",
                100 * mean(is.na(bl$sme_canonical))))

# Comparison: proxy vs canonical
xtab <- bl[, .N, by = .(sme_proxy, sme_canonical)][order(sme_proxy, sme_canonical)]
log_msg("Cross-tab of sme_proxy vs sme_canonical:")
print(xtab)
agreement <- bl[, mean(sme_proxy == sme_canonical, na.rm = TRUE)]
log_msg(sprintf("  Agreement rate: %.1f%%", 100 * agreement))

# Save
write_parquet(bl, file.path(V2_DATA, "bid_level_convite_canonical.parquet"))
log_msg("Saved bid_level_convite_canonical.parquet")

# ============================================================================
# 3. HELPER: run the CPV estimation with a given SME flag column
# ============================================================================
run_cpv_pipeline <- function(bl_input, sme_col = "sme_canonical", label = "canonical") {
  log_msg(sprintf("  [CPV pipeline — %s]", label))
  # firm-auction collapse
  fa <- bl_input[, .(
      bid = min(bid_price, na.rm = TRUE),
      won = max(won, na.rm = TRUE),
      sme = max(get(sme_col), na.rm = TRUE),
      ref = mean(ref_price, na.rm = TRUE)
    ), by = .(numerodaoc, codigoitem, codigofornecedor, Pre, pharma)]
  au <- fa[, .(N = .N,
               n_A = sum(sme == 1L),
               n_B = sum(sme == 0L),
               ref = mean(ref, na.rm = TRUE)),
           by = .(numerodaoc, codigoitem, Pre)]
  fa <- merge(fa, au[, .(numerodaoc, codigoitem, N, n_A, n_B)],
              by = c("numerodaoc", "codigoitem"))
  fa[, b_norm := bid / ref]
  fa <- fa[N >= 2L & is.finite(bid) & bid > 0 & is.finite(ref) & ref > 0 &
           b_norm > 0.005 & b_norm < 2]
  fa[, period_lbl := fifelse(Pre == 1L, "Pre", "Post")]
  fa[, sme_lbl    := fifelse(sme  == 1L, "SME", "NonSME")]
  fa[, N_bin := fifelse(N == 2L, "N=2",
                fifelse(N == 3L, "N=3",
                 fifelse(N == 4L, "N=4", "N>=5")))]

  fa_cpv <- data.table()
  for (per in c("Pre", "Post")) {
    for (Nb in c("N=2", "N=3", "N=4", "N>=5")) {
      sub <- fa[period_lbl == per & N_bin == Nb]
      if (nrow(sub) < 200) next
      b_A <- sub[sme == 1L, b_norm]; b_B <- sub[sme == 0L, b_norm]
      if (length(b_A) < 50 || length(b_B) < 50) next
      hA <- 1.06 * sd(b_A) * length(b_A)^(-1/5)
      hB <- 1.06 * sd(b_B) * length(b_B)^(-1/5)
      if (!is.finite(hA) || hA <= 0) hA <- 0.01
      if (!is.finite(hB) || hB <= 0) hB <- 0.01
      dA <- density(b_A, bw = hA, n = 256,
                    from = min(b_A), to = max(b_A), kernel = "gaussian")
      dB <- density(b_B, bw = hB, n = 256,
                    from = min(b_B), to = max(b_B), kernel = "gaussian")
      ecA <- ecdf(b_A); ecB <- ecdf(b_B)
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
  clean <- fa_cpv[is.finite(c_norm) & c_norm > 0.001 & c_norm < 1.5]
  cs <- clean[, .(mean_c = mean(c_norm), n = .N),
              by = .(period_lbl, sme_lbl)]
  list(clean = clean, fa = fa, cs = cs, n_obs = nrow(clean))
}

# ============================================================================
# 4. RUN WITH BOTH FLAGS AND COMPARE
# ============================================================================
log_msg("")
log_msg("=== Running pipeline with PROXY (firm-registry) ===")
res_proxy <- run_cpv_pipeline(bl, sme_col = "sme_proxy", label = "proxy")
print(res_proxy$cs)

log_msg("")
log_msg("=== Running pipeline with CANONICAL (me_epp) ===")
res_canon <- run_cpv_pipeline(bl, sme_col = "sme_canonical", label = "canonical")
print(res_canon$cs)

# Comparison table
comp <- merge(
  res_proxy$cs[, .(period_lbl, sme_lbl, mean_c_proxy = mean_c, n_proxy = n)],
  res_canon$cs[, .(period_lbl, sme_lbl, mean_c_canon = mean_c, n_canon = n)],
  by = c("period_lbl", "sme_lbl"), all = TRUE
)
comp[, delta := mean_c_canon - mean_c_proxy]
comp[, delta_pct := round(100 * delta / mean_c_proxy, 2)]

# Stability shifts: SME Post - SME Pre, NonSME Post - NonSME Pre, for each
shift_proxy_nonsme <- with(res_proxy$cs,
  mean_c[period_lbl == "Post" & sme_lbl == "NonSME"] -
  mean_c[period_lbl == "Pre"  & sme_lbl == "NonSME"])
shift_proxy_sme <- with(res_proxy$cs,
  mean_c[period_lbl == "Post" & sme_lbl == "SME"] -
  mean_c[period_lbl == "Pre"  & sme_lbl == "SME"])
shift_canon_nonsme <- with(res_canon$cs,
  mean_c[period_lbl == "Post" & sme_lbl == "NonSME"] -
  mean_c[period_lbl == "Pre"  & sme_lbl == "NonSME"])
shift_canon_sme <- with(res_canon$cs,
  mean_c[period_lbl == "Post" & sme_lbl == "SME"] -
  mean_c[period_lbl == "Pre"  & sme_lbl == "SME"])

shift_tab <- data.table(
  quantity = c("Primitive-invariance shift NonSME",
               "Entry shift SME"),
  proxy     = round(c(shift_proxy_nonsme, shift_proxy_sme), 4),
  canonical = round(c(shift_canon_nonsme, shift_canon_sme), 4)
)
shift_tab[, delta := round(canonical - proxy, 4)]

log_msg("")
log_msg("=== COMPARISON: mean c/ref by period × type ===")
print(comp)
log_msg("")
log_msg("=== KEY STABILITY SHIFTS ===")
print(shift_tab)

fwrite(comp,      file.path(V2_TABLES, "tab_v2_canonical_comparison.csv"))
fwrite(shift_tab, file.path(V2_TABLES, "tab_v2_canonical_shifts.csv"))

# KS test on canonical
ks_nonsme <- ks.test(
  res_canon$clean[period_lbl == "Pre"  & sme_lbl == "NonSME", c_norm],
  res_canon$clean[period_lbl == "Post" & sme_lbl == "NonSME", c_norm]
)
ks_sme <- ks.test(
  res_canon$clean[period_lbl == "Pre"  & sme_lbl == "SME", c_norm],
  res_canon$clean[period_lbl == "Post" & sme_lbl == "SME", c_norm]
)
log_msg(sprintf("KS (canonical, NonSME): D=%.3f, p=%.3g",
                ks_nonsme$statistic, ks_nonsme$p.value))
log_msg(sprintf("KS (canonical, SME):    D=%.3f, p=%.3g",
                ks_sme$statistic, ks_sme$p.value))

log_mem("final")
log_msg("=== 40_canonical_sme.R: DONE ===")
