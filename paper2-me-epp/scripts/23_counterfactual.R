# ============================================================================
# 23_counterfactual.R — Counterfactual policy design: value-threshold exemption
# ============================================================================
# Uses the existing heterogeneity by item reference value (Table tab_heterog_value)
# plus fresh quartile-level DiDs to simulate alternative ME/EPP preference
# designs. The lever: exempt items above a reference-value threshold from the
# SME-only rule. For each exemption threshold, I compute the fiscal cost of
# the residual policy and compare to the baseline (no exemption).
#
# Logic:
#   - Estimate beta_q = DiD price coefficient within quartile q of pre-period
#     reference value (q = 1..4), 18-month window, item+PBU FE.
#   - V_q = Group-65 procurement value in quartile q over the pre-period.
#   - Current fiscal cost = sum over q of |e^{beta_q} - 1| * V_q.
#   - Counterfactual (exempt quartiles E) removes the contribution from q in E.
#
# Outputs:
#   - /tmp/p2_counterfactual.rds
#   - output/tables/tab_counterfactual.tex
#   - output/tables/diag_counterfactual.txt
#   - output/figures/fig_counterfactual.pdf
# ============================================================================

cat("=== 23_counterfactual.R: Value-threshold counterfactual ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

# ---- Reference-value quartiles from pre-period g65 sample -----------------
# Use the switched group's pre-period value distribution as the policy-relevant
# support, since the counterfactual exemption would apply to the group being
# treated.
pre_g65_val <- dt[g65 == 1L & data_oc_numb < TREAT_DATE &
                  oc_item_status == 1L & !is.na(valor_total_ref) &
                  valor_total_ref > 0, valor_total_ref]
q_cuts <- quantile(pre_g65_val, c(0.25, 0.50, 0.75), na.rm = TRUE)
cat(sprintf("  Quartile cutoffs (R$): %s\n",
            paste(sprintf("Q%d=%.2f", 1:3, q_cuts), collapse = ", ")))

dt[, val_q := fifelse(valor_total_ref < q_cuts[1], 1L,
              fifelse(valor_total_ref < q_cuts[2], 2L,
              fifelse(valor_total_ref < q_cuts[3], 3L, 4L)),
              na = NA_integer_)]

# ---- DiD price coefficient per quartile ----------------------------------
cat("  Estimating DiD price coefficient per quartile...\n")
betas <- list()
for (q in 1:4) {
  d <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2] &
          oc_item_status == 1L & !is.na(val_q) & val_q == q]
  if (nrow(d) < 500L) {
    betas[[q]] <- list(b = NA_real_, se = NA_real_, n = nrow(d))
    next
  }
  m <- suppressMessages(feols(
    lpreco_final ~ g65_pre + convite + lquantidade | item_alt + pbu_alt,
    data = d, cluster = ~item_alt, fixef.rm = "none"))
  betas[[q]] <- list(
    b  = coef(m)["g65_pre"],
    se = sqrt(vcov(m)["g65_pre", "g65_pre"]),
    n  = m$nobs)
  cat(sprintf("    Q%d: beta = %+.4f (SE %.4f), n = %s\n",
              q, betas[[q]]$b, betas[[q]]$se, pfmt_int(betas[[q]]$n)))
}

# ---- Group-65 pre-period procurement value by quartile --------------------
V_q <- dt[g65 == 1L & data_oc_numb < TREAT_DATE & oc_item_status == 1L &
          !is.na(val_q) & !is.na(valor_total_final),
          .(V_BRL    = sum(valor_total_final, na.rm = TRUE),
            n_items  = .N),
          by = val_q][order(val_q)]
V_total <- sum(V_q$V_BRL)
cat(sprintf("  Group-65 pre-period total value: R$ %s (%s items)\n",
            format(round(V_total / 1e6, 1), big.mark = ","),
            pfmt_int(sum(V_q$n_items))))

# ---- Compute fiscal cost at each policy design ---------------------------
# Implied price effect by quartile = |e^{beta} - 1|
impl_pct  <- sapply(betas, function(bb)
  if (is.na(bb$b)) NA else abs(exp(bb$b) - 1))
cost_by_q <- mapply(function(v, p) v * p, V_q$V_BRL, impl_pct)

# Policy variants: exempt top-k quartiles (k = 0 baseline ... 3 keep only Q1)
policies <- list(
  list(label = "Current (no exemption)",       exempt = integer(0)),
  list(label = "Exempt top quartile (Q4)",     exempt = 4L),
  list(label = "Exempt top half (Q3, Q4)",     exempt = c(3L, 4L)),
  list(label = "Keep only bottom quartile (Q1)", exempt = c(2L, 3L, 4L))
)

res <- data.table(
  policy      = character(),
  items_kept  = integer(),
  value_kept  = numeric(),
  fiscal_cost = numeric(),
  savings_vs_baseline = numeric()
)

baseline_cost <- sum(cost_by_q, na.rm = TRUE)
for (p in policies) {
  keep_q    <- setdiff(1:4, p$exempt)
  items_k   <- sum(V_q[val_q %in% keep_q, n_items])
  value_k   <- sum(V_q[val_q %in% keep_q, V_BRL])
  cost_k    <- sum(cost_by_q[keep_q], na.rm = TRUE)
  res <- rbind(res, data.table(
    policy = p$label, items_kept = items_k, value_kept = value_k,
    fiscal_cost = cost_k,
    savings_vs_baseline = baseline_cost - cost_k))
}

cat("\n  Fiscal cost by policy design:\n")
print(res)

saveRDS(list(betas = betas, V_q = V_q, impl_pct = impl_pct,
             cost_by_q = cost_by_q, results = res, q_cuts = q_cuts),
        "/tmp/p2_counterfactual.rds")

# ---- LaTeX table ---------------------------------------------------------
cat("  Writing LaTeX table...\n")

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Counterfactual Policy Designs: Exempting High-Value Items}",
  "\\label{tab:counterfactual}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "Policy design & Quartiles covered & $\\hat\\beta$ range & Items kept & Fiscal cost (R\\$~M) & Savings (R\\$~M) \\\\",
  "\\midrule"
)

# Panel 1: quartile diagnostic (betas)
lines <- c(lines,
  "\\multicolumn{6}{l}{\\textit{Panel A: DiD price coefficient by Group-65 reference-value quartile}} \\\\")

for (q in 1:4) {
  b <- betas[[q]]$b; se <- betas[[q]]$se
  p <- if (!is.na(b)) 2 * pnorm(-abs(b / se)) else NA_real_
  lines <- c(lines,
    sprintf("Q%d (R\\$%.2f -- %s) & %d & %s%s & %s & -- & -- \\\\",
            q, q_cut_lo <- if (q == 1) 0 else q_cuts[q - 1],
            if (q == 4) "$\\infty$" else sprintf("R\\$%.2f", q_cuts[q]),
            q,
            if (is.na(b)) "--" else pfmt(b, 4),
            if (is.na(p)) "" else pstars(p),
            if (is.na(betas[[q]]$n)) "--" else pfmt_int(betas[[q]]$n)))
}

lines <- c(lines,
  "\\midrule",
  "\\multicolumn{6}{l}{\\textit{Panel B: Fiscal cost under alternative policy designs}} \\\\")

for (i in seq_len(nrow(res))) {
  r <- res[i]
  exempted_q <- policies[[i]]$exempt
  kept_q     <- setdiff(1:4, exempted_q)
  kept_label <- paste0("Q", paste(kept_q, collapse = ","))
  lines <- c(lines,
    sprintf("%s & %s & -- & %s & %.1f & %.1f \\\\",
            r$policy, kept_label, pfmt_int(r$items_kept),
            r$fiscal_cost / 1e6,
            r$savings_vs_baseline / 1e6))
}

lines <- c(lines,
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} Panel~A estimates the DiD price coefficient separately",
  "within each quartile of pre-period Group-65 reference value (quartile",
  "cutoffs listed in the first column). Panel~B simulates fiscal cost under",
  "alternative policy designs that exempt high-value items from the SME-only",
  "rule. Fiscal cost is computed as",
  "$\\sum_{q \\in \\text{covered}} |e^{\\hat\\beta_q} - 1| \\times V_q$",
  "where $V_q$ is the Group-65 pre-period procurement value in quartile~$q$.",
  sprintf("Total pre-period value: R\\$%.1f million across %s items.",
          V_total / 1e6, pfmt_int(sum(V_q$n_items))),
  "Exempting the top quartile alone removes most of the fiscal cost while",
  "retaining the ME/EPP preference for the items where heterogeneity analysis",
  "shows the policy is least distortive.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)

writeLines(lines, file.path(OUT_TAB, "tab_counterfactual.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_counterfactual.tex"), "\n")

# ---- Figure: fiscal cost as function of value-threshold (percentile) -----
cat("  Rendering figure (fiscal cost vs exemption threshold)...\n")

# Continuous: for each percentile p in 5..95, compute fiscal cost keeping
# items below the p-th percentile value.
percentiles <- seq(0, 100, by = 5)
cutoffs_cont <- c(0, quantile(pre_g65_val, percentiles[-c(1, length(percentiles))] / 100,
                              na.rm = TRUE), Inf)

# Linearly interpolate beta within the value distribution? Simpler: use
# quartile betas as step function.
get_beta_for_val <- function(v) {
  if (is.na(v)) return(NA_real_)
  if (v < q_cuts[1]) return(betas[[1]]$b)
  if (v < q_cuts[2]) return(betas[[2]]$b)
  if (v < q_cuts[3]) return(betas[[3]]$b)
  return(betas[[4]]$b)
}

# Build a micro-panel for simulation: group-65 pre-period completed items
simu <- dt[g65 == 1L & data_oc_numb < TREAT_DATE & oc_item_status == 1L &
           !is.na(valor_total_final) & !is.na(valor_total_ref),
           .(valor_total_final, valor_total_ref)]
simu[, beta_assigned := sapply(valor_total_ref, get_beta_for_val)]
simu[, cost_i        := valor_total_final * abs(exp(beta_assigned) - 1)]

# Total baseline cost
total_baseline <- sum(simu$cost_i, na.rm = TRUE)

# For each threshold (percentile), compute residual cost = cost among items below threshold
thresholds_val <- c(0, quantile(simu$valor_total_ref,
                                 seq(0.05, 1, by = 0.05), na.rm = TRUE))
fig_df <- data.frame(pct = seq(0, 100, by = 5),
                     threshold_brl = thresholds_val,
                     residual_cost = NA_real_)
for (i in seq_len(nrow(fig_df))) {
  thr <- fig_df$threshold_brl[i]
  if (is.infinite(thr) || thr <= 0) {
    fig_df$residual_cost[i] <- if (fig_df$pct[i] == 100) total_baseline else 0
  } else {
    fig_df$residual_cost[i] <- sum(simu[valor_total_ref <= thr, cost_i], na.rm = TRUE)
  }
}
fig_df$savings <- total_baseline - fig_df$residual_cost

p <- ggplot(fig_df, aes(x = pct, y = residual_cost / 1e6)) +
  geom_line(linewidth = 0.8, color = "black") +
  geom_point(size = 1.6, color = "black") +
  geom_hline(yintercept = total_baseline / 1e6,
             linetype = "dashed", color = "grey50") +
  labs(x = "Exemption threshold (percentile of Group-65 reference value)",
       y = "Fiscal cost of the residual policy (R$ millions)") +
  theme_pub()

save_pub(p, "fig_counterfactual.pdf")

# ---- Diagnostic ---------------------------------------------------------
diag_lines <- c(
  "=== Counterfactual policy design diagnostic ===",
  sprintf("Quartile cutoffs (BRL): Q1<%.2f; Q1-Q2: %.2f; Q2-Q3: %.2f; Q3-Q4: %.2f+",
          q_cuts[1], q_cuts[1], q_cuts[2], q_cuts[3]),
  sprintf("Group-65 pre-period total procurement value: R$%.1f million",
          V_total / 1e6),
  sprintf("Total baseline fiscal cost: R$%.1f million",
          baseline_cost / 1e6),
  "",
  "Per-quartile DiD price coefficient:",
  sapply(1:4, function(q) {
    bb <- betas[[q]]
    sprintf("  Q%d: beta = %+.4f (SE %.4f), n = %s, V_q = R$%.1fM",
            q,
            ifelse(is.na(bb$b), NA, bb$b),
            ifelse(is.na(bb$se), NA, bb$se),
            pfmt_int(bb$n),
            V_q[val_q == q, V_BRL] / 1e6)
  }),
  "",
  "Policy variants:",
  capture.output(print(res))
)
writeLines(diag_lines, file.path(OUT_TAB, "diag_counterfactual.txt"))
cat("  Done.\n")
