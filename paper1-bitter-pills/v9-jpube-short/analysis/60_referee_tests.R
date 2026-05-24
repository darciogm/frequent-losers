# 60_referee_tests.R --- additional referee-requested tests.
# Reuses the v9 sample construction from 48_mechanism_evidence.R (triple sample,
# winner-switch pairs) and the Lee trimming from 40_utg_lee_bounds.R.
#
# H3: equivalence test (TOST) + MDE/power for the within firm-buyer-item null.
# H4: Holm + Romano-Wolf multiple-testing on the heterogeneity cuts, plus a
#     continuous admin x market-depth interaction (vs arbitrary median splits).
# H6: winner-switching baseline (within-regime split-half churn) vs the
#     cross-regime reallocation, so 70.2% is benchmarked against normal churn.
# H2: sensitivity of the Lee interval to monotonicity violations (extra trim).
#
# Emits macros under the AUTO block "60_referee_tests". No estimate in the
# paper is overwritten; these are new objects.

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

.this_dir <- (function() {
  for (i in seq_len(sys.nframe())) {
    f <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(f)) return(normalizePath(dirname(f)))
  }
  args <- commandArgs(trailingOnly = FALSE)
  fa <- grep("^--file=", args, value = TRUE)
  if (length(fa)) return(normalizePath(dirname(sub("^--file=", "", fa[1]))))
  getwd()
})()
source(file.path(.this_dir, "_macros.R"))
bp_set_threads(12L)
set.seed(20260524)

OUT  <- file.path(.this_dir, "..", "output")
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)

dt <- bp_load_cache()

# ---------------------------------------------------------------------------
# Shared urgent sample (mirror 48_mechanism_evidence.R)
# ---------------------------------------------------------------------------
d <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 & !is.na(bid_price_log)]
d[, admin := as.integer(purchase_type == 1)]
firm_col <- intersect(c("firm_id", "po_firm_winner_id", "cnpj_winner",
                        "cnpj_raiz_winner"), names(d))[1]
d[, firm := as.factor(get(firm_col))]
d[, ib  := paste(pbu_id, item_id, sep = "_")]
d[, fbi := paste(firm, pbu_id, item_id, sep = "_")]
qty_col <- intersect(c("bid_qty", "po_qty", "qty", "quantity"), names(d))[1]
if ("bid_qty_log" %in% names(d) && qty_col == "bid_qty") {
  d[, lqty := bid_qty_log]
} else {
  d[, lqty := log(pmax(get(qty_col), 1))]
}

# Triple sample: FBI observed under both regimes
n_per_fbi <- d[, .N, by = .(fbi, admin)]
fbi_both  <- unique(merge(n_per_fbi[admin == 0L][, .(fbi)],
                          n_per_fbi[admin == 1L][, .(fbi)], by = "fbi")$fbi)
d_triple  <- d[fbi %in% fbi_both]

macros <- list()
sec <- function(x) cat("\n============================================================\n", x,
                       "\n============================================================\n")

# ===========================================================================
# H3 --- Equivalence (TOST) + MDE / power for the within-FBI null
# ===========================================================================
sec("H3: within-firm null --- equivalence (TOST) + MDE / power")
m0 <- feols(bid_price_log ~ admin | fbi + year_n, data = d_triple, cluster = ~pbu_id)
b  <- unname(coef(m0)["admin"])
se <- unname(sqrt(diag(vcov(m0, cluster = ~pbu_id)))["admin"])
cat(sprintf("Within-FBI baseline: b=%.4f  SE=%.4f  N=%d\n", b, se, nobs(m0)))

tost_p <- function(Delta) {       # equivalence at +/- Delta (log scale)
  p_u <- pnorm((b - Delta) / se)        # H0: b >= +Delta  (reject if small)
  p_l <- 1 - pnorm((b + Delta) / se)    # H0: b <= -Delta
  max(p_u, p_l)
}
D05 <- log(1.05); D10 <- log(1.10)      # 5% and 10% same-firm markups
p_tost05 <- tost_p(D05); p_tost10 <- tost_p(D10)
ub95_coef <- b + qnorm(0.95) * se       # one-sided upper 95% bound on the coef
ub95_pct  <- (exp(ub95_coef) - 1) * 100
mde_coef  <- (qnorm(0.975) + qnorm(0.80)) * se   # 80% power, 5% two-sided
mde_pct   <- (exp(mde_coef) - 1) * 100
pow10     <- pnorm(D10 / se - qnorm(0.975)) + pnorm(-D10 / se - qnorm(0.975))

cat(sprintf("TOST p (+/-5%%, Delta=%.4f):  %.4f  -> %s\n", D05, p_tost05,
            if (p_tost05 < 0.05) "equivalence at 5%% established" else "not equivalent at 5%%"))
cat(sprintf("TOST p (+/-10%%, Delta=%.4f): %.4f  -> %s\n", D10, p_tost10,
            if (p_tost10 < 0.05) "equivalence at 10%% established" else "not equivalent at 10%%"))
cat(sprintf("One-sided 95%% upper bound on coef: %.4f  (markup ruled out above %.1f%%)\n",
            ub95_coef, ub95_pct))
cat(sprintf("MDE (80%% power, 5%%): coef %.4f = %.1f%%\n", mde_coef, mde_pct))
cat(sprintf("Power to detect a 10%% markup: %.3f\n", pow10))

macros <- c(macros, list(
  h3WithinCoef   = sprintf("%+.3f", b),
  h3WithinSE     = sprintf("%.3f", se),
  h3TostMarginPct = "10\\%",
  h3TostP10      = sprintf("%.3f", p_tost10),
  h3TostP05      = sprintf("%.3f", p_tost05),
  h3RuleOutPct   = bp_fmt_pct(ub95_pct),
  h3MdePct       = bp_fmt_pct(mde_pct),
  h3Power10      = sprintf("%.2f", pow10)
))

# ===========================================================================
# H4 --- Multiple-testing (Holm + Romano-Wolf) + continuous interaction
# ===========================================================================
sec("H4: heterogeneity --- Holm/Romano-Wolf MHT + continuous depth interaction")
med_qty  <- median(d_triple$lqty, na.rm = TRUE)
med_year <- median(d_triple$year_n, na.rm = TRUE)
sus_col  <- intersect(c("sus_formulary", "is_formulary", "formulary",
                        "sus_basic", "in_remume", "in_rename"), names(d_triple))[1]

# define the cuts (same splits the paper reports)
cuts <- list(
  "Above-median quantity" = quote(lqty >= med_qty),
  "Below-median quantity" = quote(lqty <  med_qty),
  "Earlier period"        = quote(year_n <= med_year),
  "Later period"          = quote(year_n >  med_year)
)
if (!is.na(sus_col)) {
  d_triple[, sus_flag := as.integer(get(sus_col) > 0)]
  cuts[["SUS-formulary items"]] <- quote(sus_flag == 1L)
  cuts[["Non-formulary items"]] <- quote(sus_flag == 0L)
}

fit_coef_se <- function(sub) {
  if (nrow(sub) < 100L) return(c(NA, NA, NA))
  m <- tryCatch(feols(bid_price_log ~ admin | fbi + year_n, data = sub,
                      cluster = ~pbu_id, notes = FALSE, warn = FALSE),
                error = function(e) NULL)
  if (is.null(m) || !("admin" %in% names(coef(m)))) return(c(NA, NA, NA))
  c(unname(coef(m)["admin"]),
    unname(sqrt(diag(vcov(m, cluster = ~pbu_id)))["admin"]),
    nobs(m))
}

het <- rbindlist(lapply(names(cuts), function(nm) {
  cs <- fit_coef_se(d_triple[eval(cuts[[nm]])])
  data.table(label = nm, coef = cs[1], se = cs[2], n = cs[3])
}))
het[, t := coef / se]
het[, p := 2 * (1 - pnorm(abs(t)))]
het[, p_holm := p.adjust(p, method = "holm")]
het[, p_bonf := p.adjust(p, method = "bonferroni")]

# Romano-Wolf free step-down via PBU cluster bootstrap (studentized, recentered)
rw_pvalues <- function(dat, cut_list, b_obs, t_obs, B = 999L) {
  pbus <- unique(dat$pbu_id)
  k <- length(cut_list)
  boot_t <- matrix(NA_real_, B, k)
  for (bI in seq_len(B)) {
    samp_pbu <- sample(pbus, length(pbus), replace = TRUE)
    db <- dat[.(samp_pbu), on = "pbu_id", allow.cartesian = TRUE]
    for (j in seq_len(k)) {
      cs <- fit_coef_se(db[eval(cut_list[[j]])])
      if (!is.na(cs[1]) && !is.na(cs[2]) && cs[2] > 0) {
        boot_t[bI, j] <- (cs[1] - b_obs[j]) / cs[2]   # recentered studentized
      }
    }
  }
  ord <- order(abs(t_obs), decreasing = TRUE)
  p_rw <- numeric(k); running_max <- 0
  for (i in seq_along(ord)) {
    j <- ord[i]
    remaining <- ord[i:length(ord)]
    maxnull <- apply(abs(boot_t[, remaining, drop = FALSE]), 1, max, na.rm = TRUE)
    p_step <- mean(maxnull >= abs(t_obs[j]), na.rm = TRUE)
    running_max <- max(running_max, p_step)   # enforce monotonicity
    p_rw[j] <- running_max
  }
  p_rw
}
het[, p_rw := tryCatch(rw_pvalues(d_triple, cuts, het$coef, het$t, B = 999L),
                       error = function(e) { cat("[RW failed]", conditionMessage(e), "\n"); rep(NA_real_, .N) })]
print(het[, .(label, coef = round(coef,3), se = round(se,3), p = round(p,3),
              p_holm = round(p_holm,3), p_rw = round(p_rw,3), n)])

# Continuous interaction: admin x centered log-quantity (depth proxy)
d_triple[, lqty_c := lqty - mean(lqty, na.rm = TRUE)]
m_int <- feols(bid_price_log ~ admin * lqty_c | fbi + year_n,
               data = d_triple, cluster = ~pbu_id)
ic <- unname(coef(m_int)["admin:lqty_c"]); ise <- unname(sqrt(diag(vcov(m_int, cluster = ~pbu_id)))["admin:lqty_c"])
ip <- 2 * (1 - pnorm(abs(ic / ise)))
cat(sprintf("\nContinuous interaction admin x lqty_c: %.4f (SE %.4f, p=%.3f)\n", ic, ise, ip))
cat("  Negative = the within-firm admin effect falls as order size (depth) rises.\n")

below <- het[label == "Below-median quantity"]
early <- het[label == "Earlier period"]
macros <- c(macros, list(
  h4BelowQtyPHolm = sprintf("%.3f", below$p_holm),
  h4BelowQtyPrw   = if (is.na(below$p_rw)) "n/a" else sprintf("%.3f", below$p_rw),
  h4EarlyPHolm    = sprintf("%.3f", early$p_holm),
  h4EarlyPrw      = if (is.na(early$p_rw)) "n/a" else sprintf("%.3f", early$p_rw),
  h4IntCoef       = sprintf("%+.4f", ic),
  h4IntSE         = sprintf("%.4f", ise),
  h4IntP          = sprintf("%.3f", ip)
))

# ===========================================================================
# H6 --- winner-switching baseline (within-regime split-half churn)
# ===========================================================================
sec("H6: winner-switching --- within-regime baseline churn vs cross-regime")
ibsum <- d[, .(na = sum(admin == 1L), nl = sum(admin == 0L)), by = ib]
both_ibs <- ibsum[na > 0 & nl > 0, ib]
d_both <- d[ib %in% both_ibs]

jac <- function(a, b) { u <- length(union(a, b)); if (u == 0) NA_real_ else length(intersect(a, b)) / u }

# cross-regime Jaccard (reproduce 0.268)
cross <- d_both[, {
  a <- unique(as.character(firm[admin == 1L])); l <- unique(as.character(firm[admin == 0L]))
  .(j = jac(a, l))
}, by = ib]
cross_jac <- mean(cross$j, na.rm = TRUE)

# within-regime baseline: for the regime with >=2 winning rows, random split-half
split_jac_one <- function(firms) {
  if (length(firms) < 2L) return(NA_real_)
  idx <- sample(length(firms)); h <- ceiling(length(firms) / 2)
  jac(unique(firms[idx[1:h]]), unique(firms[idx[(h + 1):length(firms)]]))
}
base_within <- d_both[, {
  fl <- as.character(firm[admin == 0L]); fa <- as.character(firm[admin == 1L])
  j_l <- if (length(fl) >= 2L) split_jac_one(fl) else NA_real_
  j_a <- if (length(fa) >= 2L) split_jac_one(fa) else NA_real_
  .(j = mean(c(j_l, j_a), na.rm = TRUE))
}, by = ib]
# average over many random splits for stability
R <- 200L
base_vals <- numeric(R)
for (r in seq_len(R)) {
  bw <- d_both[, {
    fl <- as.character(firm[admin == 0L]); fa <- as.character(firm[admin == 1L])
    j_l <- if (length(fl) >= 2L) split_jac_one(fl) else NA_real_
    j_a <- if (length(fa) >= 2L) split_jac_one(fa) else NA_real_
    .(j = mean(c(j_l, j_a), na.rm = TRUE))
  }, by = ib]
  base_vals[r] <- mean(bw$j, na.rm = TRUE)
}
base_jac <- mean(base_vals, na.rm = TRUE)
n_base_ib <- sum(is.finite(base_within$j))
cat(sprintf("Cross-regime mean Jaccard:        %.3f\n", cross_jac))
cat(sprintf("Within-regime baseline Jaccard:   %.3f  (avg of %d random split-halves, %d pairs)\n",
            base_jac, R, n_base_ib))
cat(sprintf("Cross-regime switching exceeds baseline churn by: %.3f Jaccard points\n",
            base_jac - cross_jac))
macros <- c(macros, list(
  h6CrossJaccard = sprintf("%.3f", cross_jac),
  h6BaselineJaccard = sprintf("%.3f", base_jac),
  h6JaccardGap = sprintf("%.3f", base_jac - cross_jac)
))

# ===========================================================================
# H2 --- Lee interval sensitivity to monotonicity violations
# ===========================================================================
sec("H2: Lee bounds --- sensitivity to monotonicity violations (extra trim delta)")
du <- dt[purchase_type %in% c(1, 2) & po_firm_winner == 1 & !is.na(bid_price_log) &
         !is.na(item_id) & !is.na(year_n) & !is.na(pbu_id)]
du[, admin := as.integer(purchase_type == 1)]
strata_n <- du[, .(n_admin = sum(admin == 1L), n_lit = sum(admin == 0L)),
               by = .(item_id, year_n, pbu_id)]
strata_n[, p_trim := pmin(1, pmax(0, (n_admin - n_lit) / pmax(n_admin, 1)))]
du <- merge(du, strata_n[, .(item_id, year_n, pbu_id, p_trim)],
            by = c("item_id", "year_n", "pbu_id"), all.x = TRUE)
du[is.na(p_trim), p_trim := 0]

lee_bound_delta <- function(dat, side, delta) {     # delta = extra trim for monotonicity slack
  d_lit <- dat[admin == 0L]; d_adm <- dat[admin == 1L]
  d_adm[, rank_w := frank(if (side == "lower") -bid_price_log else bid_price_log,
                          ties.method = "first") / .N, by = .(item_id, year_n, pbu_id)]
  d_adm_t <- d_adm[rank_w > pmin(1, p_trim + delta)]
  d_use <- rbindlist(list(d_lit, d_adm_t[, !"rank_w"]), use.names = TRUE, fill = TRUE)
  m <- feols(bid_price_log ~ admin | item_id + year_n + pbu_id, data = d_use, cluster = ~pbu_id)
  unname(coef(m)["admin"])
}
deltas <- c(0, 0.05, 0.10, 0.20)
sens <- rbindlist(lapply(deltas, function(dl) {
  lo <- lee_bound_delta(du, "lower", dl); up <- lee_bound_delta(du, "upper", dl)
  data.table(delta = dl,
             gap_low = (exp(-up) - 1) * 100,   # litigated-over-admin, low end
             gap_high = (exp(-lo) - 1) * 100)  # high end
}))
print(sens)
# breakdown delta: smallest extra trim where the low end of the gap reaches 0
brk <- NA_real_
for (dl in seq(0, 0.6, by = 0.01)) {
  up <- lee_bound_delta(du, "upper", dl)
  if ((exp(-up) - 1) * 100 <= 0) { brk <- dl; break }
}
cat(sprintf("Breakdown extra-trim delta (low-end gap hits 0): %s\n",
            if (is.na(brk)) ">0.60 (interval stays positive)" else sprintf("%.2f", brk)))
g10 <- sens[delta == 0.10]
macros <- c(macros, list(
  h2GapDelta10Low  = bp_fmt_pct(g10$gap_low),
  h2GapDelta10High = bp_fmt_pct(g10$gap_high),
  h2BreakdownDelta = if (is.na(brk)) "$>$0.60" else sprintf("%.2f", brk)
))

# ---------------------------------------------------------------------------
# Site-only diagnostics: emit to a separate file NOT \input by the paper.
# (Keys carry hypothesis IDs like h3/h4, which are illegal in LaTeX control
# sequences; keeping them out of values.tex avoids breaking the paper build.)
bp_macros_emit("60_referee_tests", macros, file = file.path(.this_dir, "referee_macros.tex"))
cat("\n[60_referee_tests] done. Macros emitted:\n"); print(names(macros))
