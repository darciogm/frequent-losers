# ============================================================================
# 42_ipv_cv_test.R — Sprint 11: IPV vs Common Values diagnostic
# ============================================================================
# The CPV asymmetric GPV estimator (scripts 35) maintains the Independent
# Private Values (IPV) assumption: each bidder's cost is drawn i.i.d. from
# F_c^type, independent of others' signals. A referee will predictably ask
# whether our recovered primitives are an artifact of mis-specification if
# the true model involves Common Values (CV) — e.g., input-cost shocks
# that affect all bidders simultaneously (currency, supply chain,
# regulatory changes).
#
# A full-blown CV vs IPV structural test (Athey-Haile 2007, Aryal-Gabrielli-
# Vuong 2015) is technically involved. For this paper the relevant
# diagnostic is simpler and defensible:
#
#   Under IPV with bidder types, the pseudo-cost c_norm = c/P_ref should
#   be i.i.d. across auctions *conditional on bidder type*. The
#   reference price P_ref is an auction-level scale factor that the
#   normalization absorbs; once normalized, no residual auction-level
#   signal should systematically move c_norm beyond type and auction-
#   size effects.
#
# Implementation:
#   Regression  c_norm = α + β_1 · log(N) + β_2 · log(P_ref) + γ · type
#                         + δ · pharma + controls + ε
#   under IPV null: β_2 = 0 (normalized costs invariant to
#     auction-level common signals beyond type and size).
#   Under CV: β_2 \ne 0 (affiliated signals leak through to estimated c).
#
# We also run three auxiliary checks:
#   (i) Type-specific F_c invariance across N-bins: if CV contamination,
#       estimated F_c shifts systematically with N.
#  (ii) Markup-by-N scaling vs IPV prediction (markup ∝ 1/(N-1)).
# (iii) Joint F-test of auction-level signals being irrelevant.
#
# Outputs:
#   output/tables/tab_v2_ipv_test.tex       — main regression + joint F
#   output/tables/tab_v2_markup_scaling.csv — markup by N vs IPV prediction
#   output/figures/fig_v2_ipv_cv_diag.pdf   — F_c by N (stability across N)
#   logs/42_ipv_cv_test.log
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
  library(fixest)
  library(ggplot2)
  library(scales)
})

setDTthreads(12)
log_msg("=== 42_ipv_cv_test.R — IPV vs CV diagnostic ===")
log_mem("startup")

theme_pub <- function() {
  theme_bw(base_size = 9) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
          strip.background = element_rect(fill = "grey95", color = "black",
                                          linewidth = 0.3),
          legend.position = "bottom", legend.title = element_blank(),
          plot.title = element_text(size = 10, face = "bold"))
}
save_pub <- function(p, fn, w = 7.0, h = 4.0) {
  ggsave(file.path(V2_FIGS, fn), p, width = w, height = h, device = cairo_pdf)
  log_msg("  saved ", fn)
}

# ============================================================================
# 1. LOAD CPV PSEUDO-COSTS
# ============================================================================
log_msg("Loading CPV pseudo-costs (Convite G65)...")
cpv <- as.data.table(read_parquet(file.path(V2_DATA, "convite_cpv_costs.parquet")))
clean <- cpv[is.finite(c_norm) & c_norm > 0.001 & c_norm < 1.5]

# Need auction-level N and ref
# Pull from bid-level for robustness
bl <- as.data.table(read_parquet(file.path(V2_DATA, "bid_level_convite.parquet")))
bl <- bl[g65 == 1L]
au <- bl[, .(N   = uniqueN(codigofornecedor),
             ref = mean(ref_price, na.rm = TRUE)),
         by = .(numerodaoc, codigoitem)]
clean <- merge(clean,
               au[, .(numerodaoc, codigoitem, N_obs = N, ref_obs = ref)],
               by = c("numerodaoc", "codigoitem"))
clean[, log_N   := log(N_obs)]
clean[, log_ref := log(ref_obs)]
clean[, auction_id := paste0(numerodaoc, "/", codigoitem)]

log_msg(sprintf("  clean cpv rows: %s | auctions: %s",
                format(nrow(clean), big.mark = ","),
                format(uniqueN(clean$auction_id), big.mark = ",")))

# ============================================================================
# 2. IPV MAIN TEST: regress c_norm on auction-level signals
# ============================================================================
# Under IPV, after conditioning on bidder type and auction size, residual
# dependence of c_norm on log(P_ref) should vanish. A non-zero coefficient
# on log(P_ref) is evidence of CV contamination (auction-level common
# value leaking through).

log_msg("")
log_msg("IPV main test — does c_norm depend on log(ref) beyond type + N?")

# Model 1: proxy SME, Pre period only
pre <- clean[period_lbl == "Pre"]
m1 <- feols(c_norm ~ log_N + log_ref + sme_lbl + pharma | auction_id,
            data = pre, cluster = ~auction_id, lean = TRUE)
print(summary(m1))

# Model 2: without auction FE (so log_ref is identified)
m2 <- feols(c_norm ~ log_N + log_ref + sme_lbl + pharma,
            data = pre, cluster = ~auction_id, lean = TRUE)
print(summary(m2))

# Joint F-test: H0: coef(log_N) = coef(log_ref) = 0 (IPV null: only type
# matters after normalization; auction-level signals irrelevant)
coefs_to_test <- c("log_N", "log_ref")
F_test <- tryCatch(
  wald(m2, keep = c("log_N", "log_ref")),
  error = function(e) {
    log_msg(sprintf("  wald error: %s", e$message))
    NULL
  })
if (!is.null(F_test)) {
  log_msg("Joint F-test of (log_N, log_ref) = 0 (IPV null):")
  print(F_test)
}

# Also test: does coef(log_ref) differ from 0 after controlling for log_N?
log_msg("")
log_msg("Individual coefficient test (log_ref given log_N):")
log_msg(sprintf("  β(log_ref) = %.4f (SE %.4f, t = %.2f, p = %.3g)",
                coef(m2)["log_ref"], se(m2)["log_ref"],
                coef(m2)["log_ref"] / se(m2)["log_ref"],
                2 * pnorm(-abs(coef(m2)["log_ref"] / se(m2)["log_ref"]))))

# ============================================================================
# 3. MARKUP-BY-N SCALING vs IPV PREDICTION
# ============================================================================
# Under symmetric IPV with N bidders, equilibrium markup scales as 1/(N-1)
# (at fixed cost c). If data follows this scaling, consistent with IPV.
# Deviations suggest CV or asymmetry.

log_msg("")
log_msg("Markup-by-N scaling:")
clean[, markup_pct := 100 * (b_norm - c_norm) / b_norm]
mkp_tab <- clean[period_lbl == "Pre", .(
    n               = .N,
    median_N        = round(median(N_obs)),
    mean_markup_pct = round(mean(markup_pct), 2),
    median_mkp      = round(median(markup_pct), 2)
  ), by = N_bin][order(median_N)]

# IPV prediction: markup ratio N=2:N=3 = 2/1; N=3:N=4 = 2/1.5 = 1.33; etc.
# Normalize to N=2 baseline
baseline_mkp <- mkp_tab[N_bin == "N=2", median_mkp]
mkp_tab[, IPV_predicted_ratio := round(1 / (median_N - 1) / (1 / (2 - 1)), 2)]
mkp_tab[, observed_ratio      := round(median_mkp / baseline_mkp, 2)]
mkp_tab[, deviation_pct       := round(100 * (observed_ratio - IPV_predicted_ratio) / IPV_predicted_ratio, 1)]
print(mkp_tab)
fwrite(mkp_tab, file.path(V2_TABLES, "tab_v2_markup_scaling.csv"))

# ============================================================================
# 4. F_c INVARIANCE ACROSS N-BINS (auxiliary CV check)
# ============================================================================
# If costs are primitive (IPV), F_c should not shift with N. CV would
# predict systematic shifts (bidders in larger N shade more due to
# inference about rivals' signals).

log_msg("")
log_msg("F_c invariance across N-bins (by type, Pre period):")
inv_ks <- data.table()
for (typ in c("SME", "NonSME")) {
  sub <- clean[period_lbl == "Pre" & sme_lbl == typ]
  c2   <- sub[N_bin == "N=2",    c_norm]
  c3   <- sub[N_bin == "N=3",    c_norm]
  c4   <- sub[N_bin == "N=4",    c_norm]
  c5p  <- sub[N_bin == "N>=5",   c_norm]

  for (pair in list(c("N=2", "N=3"), c("N=2", "N>=5"), c("N=3", "N>=5"))) {
    v1 <- sub[N_bin == pair[1], c_norm]
    v2 <- sub[N_bin == pair[2], c_norm]
    if (length(v1) < 50 || length(v2) < 50) next
    ks <- suppressWarnings(ks.test(v1, v2))
    inv_ks <- rbind(inv_ks, data.table(
      type       = typ,
      comparison = sprintf("%s vs %s", pair[1], pair[2]),
      n1 = length(v1), n2 = length(v2),
      mean1 = round(mean(v1), 3),
      mean2 = round(mean(v2), 3),
      shift = round(mean(v2) - mean(v1), 3),
      KS_D  = round(unname(ks$statistic), 3),
      KS_p  = signif(unname(ks$p.value), 3)
    ))
  }
}
print(inv_ks)
fwrite(inv_ks, file.path(V2_TABLES, "tab_v2_ipv_Fc_invariance.csv"))

# ============================================================================
# 5. FIGURE: F_c(c) overlayed by N-bin (stability diagnostic)
# ============================================================================
fig_inv <- ggplot(clean[period_lbl == "Pre"],
                  aes(x = c_norm, color = N_bin, linetype = N_bin)) +
  stat_ecdf(linewidth = 0.55) +
  facet_wrap(~ sme_lbl) +
  scale_color_grey(start = 0.05, end = 0.75) +
  scale_linetype_manual(values = c("N=2" = "solid",
                                    "N=3" = "dashed",
                                    "N=4" = "dotted",
                                    "N>=5" = "twodash")) +
  scale_x_continuous(labels = percent_format(),
                     limits = c(0, quantile(clean$c_norm, 0.98, na.rm = TRUE))) +
  labs(x = "Pseudo-cost  c / ref price",
       y = "F(c)",
       title = "F_c(c) by N-bin under IPV — should overlay (Pre period)",
       subtitle = "Substantial divergence across N would suggest common-values contamination") +
  theme_pub()
save_pub(fig_inv, "fig_v2_ipv_Fc_by_N.pdf", w = 7.5, h = 4.0)

# ============================================================================
# 6. SUMMARY TABLE FOR THE MANUSCRIPT
# ============================================================================
summary_tab <- data.table(
  test = c(
    "Individual: coef(log ref) = 0 (IPV null)",
    "Individual: coef(log N) vs 1/(N-1)-IPV",
    "Joint: (log N, log ref) both zero",
    "F_c invariance: NonSME N=2 vs N>=5 (KS)",
    "F_c invariance: SME N=2 vs N>=5 (KS)",
    "Markup scaling: observed vs IPV-predicted (N=2 → N=3)",
    "Markup scaling: observed vs IPV-predicted (N=4 → N>=5)"
  ),
  result = c(
    sprintf("β = %.4f, p = %.3g",
            coef(m2)["log_ref"],
            2 * pnorm(-abs(coef(m2)["log_ref"] / se(m2)["log_ref"]))),
    sprintf("β = %.4f, p = %.3g",
            coef(m2)["log_N"],
            2 * pnorm(-abs(coef(m2)["log_N"] / se(m2)["log_N"]))),
    "see wald above",
    sprintf("%s",
            if (nrow(inv_ks[type == "NonSME" &
                            comparison == "N=2 vs N>=5"]) > 0) {
              row <- inv_ks[type == "NonSME" & comparison == "N=2 vs N>=5"]
              sprintf("D = %.3f, p = %.3g", row$KS_D, row$KS_p)
            } else "—"),
    sprintf("%s",
            if (nrow(inv_ks[type == "SME" &
                            comparison == "N=2 vs N>=5"]) > 0) {
              row <- inv_ks[type == "SME" & comparison == "N=2 vs N>=5"]
              sprintf("D = %.3f, p = %.3g", row$KS_D, row$KS_p)
            } else "—"),
    sprintf("obs %.2f vs IPV %.2f (%.0f%% deviation)",
            mkp_tab[N_bin == "N=3", observed_ratio],
            mkp_tab[N_bin == "N=3", IPV_predicted_ratio],
            mkp_tab[N_bin == "N=3", deviation_pct]),
    sprintf("obs %.2f vs IPV %.2f (%.0f%% deviation)",
            mkp_tab[N_bin == "N>=5", observed_ratio],
            mkp_tab[N_bin == "N>=5", IPV_predicted_ratio],
            mkp_tab[N_bin == "N>=5", deviation_pct])
  )
)
log_msg("")
log_msg("IPV DIAGNOSTIC SUMMARY:")
print(summary_tab)
fwrite(summary_tab, file.path(V2_TABLES, "tab_v2_ipv_test.csv"))

sink(file.path(V2_TABLES, "tab_v2_ipv_test.tex"))
cat("% Auto-generated by 42_ipv_cv_test.R\n")
cat("\\begin{tabular}{p{0.55\\linewidth}p{0.35\\linewidth}}\n\\toprule\n")
cat("\\textbf{Test} & \\textbf{Result} \\\\\n\\midrule\n")
for (i in seq_len(nrow(summary_tab))) {
  with(summary_tab[i], cat(
    test, "&", result, "\\\\\n"))
}
cat("\\bottomrule\n\\end{tabular}\n")
sink()

log_mem("final")
log_msg("=== 42_ipv_cv_test.R: DONE ===")
