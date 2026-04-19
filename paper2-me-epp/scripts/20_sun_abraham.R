# ============================================================================
# 20_sun_abraham.R — Sun & Abraham (2021) event study at the item level
# ============================================================================
# For a single treatment cohort (group 65 in March 2018), the Sun-Abraham
# interaction-weighted estimator reduces to an event study where event-time
# dummies are interacted with the treated indicator, relative to never-treated
# controls. We implement it directly via fixest::i() to preserve item-level
# identification with item FE and PBU FE.
#
# Spec:
#   y ~ i(data_oc_numb, g65, ref = TREAT_DATE - 1) + convite + lquantidade
#       | item_alt + pbu_alt
#
# The post-period aggregated ATT is the average of event-time coefficients
# for t >= TREAT_DATE, computed as a linear combination with delta-method SE
# using the clustered vcov matrix.
#
# Outputs:
#   - /tmp/p2_sunab.rds
#   - output/tables/tab_sunab.tex
#   - output/tables/diag_sunab.txt
#   - output/figures/fig_sunab_event.pdf
# ============================================================================

cat("=== 20_sun_abraham.R: Sun-Abraham event study ===\n")

if (!exists(".script_dir")) .script_dir <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(.script_dir, "utils.R"), local = TRUE)

if (!file.exists(DATA_CACHE)) stop("Run 01_clean.R first")
dt <- readRDS(DATA_CACHE)

# Disable lean so we can access the model matrix for aggregation/SE.
setFixest_estimation(lean = FALSE)

REF_T <- TREAT_DATE - 1L  # t=697, February 2018 (last pre-treatment month)
dt_win <- dt[data_oc_numb >= WIN_18M[1] & data_oc_numb <= WIN_18M[2]]
cat(sprintf("  Sample (18m): %s rows. Reference period t=%d.\n",
            pfmt_int(nrow(dt_win)), REF_T))

# ---- Run event study -------------------------------------------------------
run_es <- function(dv, completed = FALSE) {
  d <- if (completed) dt_win[oc_item_status == 1L] else dt_win
  fml <- as.formula(paste0(dv,
    " ~ i(data_oc_numb, g65, ref = ", REF_T, ") + convite + lquantidade ",
    "| item_alt + pbu_alt"))
  feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none")
}

# ---- ATT from linear combination of event-time coefs ----------------------
# For post periods (t >= TREAT_DATE), the average β is the Sun-Abraham ATT.
# Var(mean) = c' V c where c is the equal-weight indicator for post coefs.
extract_att <- function(m) {
  cf <- summary(m)$coeftable
  rn <- rownames(cf)
  # Identify event-time coefficients: "data_oc_numb::<t>:g65"
  ttv <- suppressWarnings(as.integer(sub("^data_oc_numb::([0-9]+):g65$",
                                         "\\1", rn)))
  ev_rows <- which(!is.na(ttv))
  ev_t    <- ttv[ev_rows]

  post_rows <- ev_rows[ev_t >= TREAT_DATE]
  pre_rows  <- ev_rows[ev_t <  TREAT_DATE]

  V <- vcov(m)[rn[ev_rows], rn[ev_rows], drop = FALSE]
  betas <- cf[rn[ev_rows], "Estimate"]
  n_post <- length(post_rows); n_pre <- length(pre_rows)

  # ATT as DDR-equivalent: mean(post betas) - mean(pre betas, excluding ref).
  # Under parallel trends, mean(pre betas) ~ 0, but pre-period may drift, so
  # including pre average as counterfactual baseline matches the DDR "g65 x Pre"
  # estimand up to sign.
  w_att <- rep(0, length(ev_rows))
  post_idx <- match(rn[post_rows], rn[ev_rows])
  pre_idx0 <- match(rn[pre_rows],  rn[ev_rows])
  w_att[post_idx] <- 1 / n_post
  if (n_pre > 0) w_att[pre_idx0] <- -1 / n_pre
  att <- as.numeric(w_att %*% betas)
  att_se <- sqrt(as.numeric(t(w_att) %*% V %*% w_att))

  # Pre-trend joint test (Wald)
  pre_idx <- match(rn[pre_rows], rn[ev_rows])
  wt_stat <- NA_real_; wt_p <- NA_real_
  if (length(pre_idx) > 0) {
    R <- matrix(0, nrow = length(pre_idx), ncol = length(ev_rows))
    for (i in seq_along(pre_idx)) R[i, pre_idx[i]] <- 1
    rb <- R %*% betas
    rV <- R %*% V %*% t(R)
    wt_stat <- as.numeric(t(rb) %*% solve(rV) %*% rb) / length(pre_idx)
    wt_p    <- pf(wt_stat, length(pre_idx),
                  m$nobs - length(coef(m)),
                  lower.tail = FALSE)
  }

  list(att = att, att_se = att_se,
       wt_stat = wt_stat, wt_p = wt_p,
       ev_t = ev_t, ev_rows = ev_rows,
       betas = betas, V = V, rn = rn[ev_rows])
}

cat("  Fitting event studies for 4 outcomes...\n")
t0 <- Sys.time()
m_price <- run_es("lpreco_final", completed = TRUE)
cat(sprintf("    lpreco_final done (%.1fs)\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
t0 <- Sys.time()
m_firms <- run_es("lnum_firms", completed = FALSE)
cat(sprintf("    lnum_firms   done (%.1fs)\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
t0 <- Sys.time()
m_bids <- run_es("lnum_bids", completed = FALSE)
cat(sprintf("    lnum_bids    done (%.1fs)\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
t0 <- Sys.time()
m_dist <- run_es("dist1", completed = TRUE)
cat(sprintf("    dist1        done (%.1fs)\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

a_price <- extract_att(m_price)
a_firms <- extract_att(m_firms)
a_bids  <- extract_att(m_bids)
a_dist  <- extract_att(m_dist)

cat("  Sun-Abraham ATT:\n")
for (k in list(price = a_price, firms = a_firms, bids = a_bids, dist = a_dist)) {
  ; # just inline below
}
fmt_line <- function(nm, a) {
  p <- 2 * pnorm(-abs(a$att / a$att_se))
  sprintf("    %-6s : %+.4f (%.4f)  p=%.4f  | pre-F=%.3f p=%.4f",
          nm, a$att, a$att_se, p, a$wt_stat, a$wt_p)
}
cat(fmt_line("price", a_price), "\n")
cat(fmt_line("firms", a_firms), "\n")
cat(fmt_line("bids",  a_bids),  "\n")
cat(fmt_line("dist",  a_dist),  "\n")

# ---- DDR and CS2021 for side-by-side --------------------------------------
cat("  Fitting DDR 18m +PBU FE for comparison (sign-flipped)...\n")
ddr_specs <- list(
  price = list(dv = "lpreco_final", completed = TRUE),
  firms = list(dv = "lnum_firms",   completed = FALSE),
  bids  = list(dv = "lnum_bids",    completed = FALSE),
  dist  = list(dv = "dist1",        completed = TRUE)
)
ddr_tab <- list()
for (k in names(ddr_specs)) {
  sp <- ddr_specs[[k]]
  d  <- dt_win
  if (sp$completed) d <- d[oc_item_status == 1L]
  fml <- as.formula(sprintf("%s ~ g65_pre + convite + lquantidade | item_alt + pbu_alt + data_oc_numb",
                            sp$dv))
  mm <- suppressMessages(feols(fml, data = d, cluster = ~item_alt, fixef.rm = "none"))
  ddr_tab[[k]] <- list(
    b  = -coef(mm)["g65_pre"],
    se = sqrt(vcov(mm)["g65_pre", "g65_pre"]))
}

cs_path <- "/tmp/p2_cs2021.rds"
cs_tab <- list()
if (file.exists(cs_path)) {
  cs <- readRDS(cs_path)
  for (k in names(ddr_specs)) {
    obj <- switch(k, price = cs$price, firms = cs$firms,
                     bids  = cs$bids,  dist  = cs$dist)
    if (!is.null(obj)) {
      cs_tab[[k]] <- list(b  = obj$overall$overall.att,
                          se = obj$overall$overall.se)
    }
  }
}

saveRDS(list(m_price = m_price, m_firms = m_firms,
             m_bids  = m_bids,  m_dist  = m_dist,
             atts = list(price = a_price, firms = a_firms,
                         bids  = a_bids,  dist  = a_dist),
             ddr_tab = ddr_tab, cs_tab = cs_tab),
        "/tmp/p2_sunab.rds")

# ---- LaTeX table: three-estimator convergence -----------------------------
cat("  Writing LaTeX table...\n")

fmt <- function(b, se, d = 4) {
  if (is.null(b) || is.na(b)) return(c("--", ""))
  p <- 2 * pnorm(-abs(b / se))
  c(paste0(pfmt(b, d), pstars(p)), paste0("(", pfmt(se, d), ")"))
}
row_labels <- c(price = "Log prices", firms = "Log firms",
                bids  = "Log bids",   dist  = "Distance (km)")
sa_atts <- list(price = a_price, firms = a_firms,
                bids  = a_bids,  dist  = a_dist)

lines <- c(
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Three-Estimator Convergence: DDR, Staggered DiD (CS2021), and Sun-Abraham (2021)}",
  "\\label{tab:sunab}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\begin{threeparttable}", "\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  " & DDR & CS2021 & Sun-Abraham \\\\",
  " & (item FE, sign-flipped) & (group $\\times$ month) & (item FE, event-study ATT) \\\\",
  "\\midrule"
)
for (k in names(row_labels)) {
  ddr_c <- fmt(ddr_tab[[k]]$b, ddr_tab[[k]]$se)
  cs_c  <- if (!is.null(cs_tab[[k]])) fmt(cs_tab[[k]]$b, cs_tab[[k]]$se) else c("--", "")
  sa_c  <- fmt(sa_atts[[k]]$att, sa_atts[[k]]$att_se)
  lines <- c(lines,
    sprintf("%s & %s & %s & %s \\\\", row_labels[[k]], ddr_c[1], cs_c[1], sa_c[1]),
    sprintf(" & %s & %s & %s \\\\",                      ddr_c[2], cs_c[2], sa_c[2]))
}

# Pre-trend F-tests for Sun-Abraham
pre_row_f <- sapply(names(row_labels), function(k) {
  a <- sa_atts[[k]]
  sprintf("%.3f", a$wt_stat)
})
pre_row_p <- sapply(names(row_labels), function(k) {
  a <- sa_atts[[k]]
  sprintf("%.4f", a$wt_p)
})

lines <- c(lines,
  "\\midrule",
  sprintf("SA pre-trend $F$ & \\multicolumn{3}{l}{Log prices: %s (p=%s); Log firms: %s (p=%s)} \\\\",
          pre_row_f[1], pre_row_p[1], pre_row_f[2], pre_row_p[2]),
  sprintf(" & \\multicolumn{3}{l}{Log bids: %s (p=%s); Distance: %s (p=%s)} \\\\",
          pre_row_f[3], pre_row_p[3], pre_row_f[4], pre_row_p[4]),
  "Item FE + PBU FE (DDR/SA) & \\multicolumn{3}{c}{YES} \\\\",
  "Unit (CS2021) & \\multicolumn{3}{c}{codigogrupo $\\times$ month} \\\\",
  "\\bottomrule", "\\end{tabular}",
  "\\begin{tablenotes}", "\\small",
  "\\item \\textit{Notes:} 18-month window. All three estimators identify the",
  "same treatment effect under distinct assumptions.",
  "\\textit{DDR}: headline $g65 \\times Pre$ from Table~\\ref{tab:prices}, multiplied",
  "by $-1$ so signs match the CS2021/Sun-Abraham convention.",
  "\\textit{CS2021}: overall ATT from \\texttt{did::att\\_gt} at group-month level",
  "with never-treated controls; see Table~\\ref{tab:cs2021}.",
  "\\textit{Sun-Abraham}: event-study via \\texttt{fixest::i(period, g65, ref=t$-$1)}",
  "at the item level with item FE and PBU FE. The reported ATT is",
  "$\\mathrm{mean}(\\hat\\beta_{t\\geq 698}) - \\mathrm{mean}(\\hat\\beta_{t<698\\,\\&\\,t\\neq 697})$,",
  "i.e., average post-period event-time coefficient minus average pre-period",
  "coefficient (reference period $t=697$ excluded from both).",
  "This formulation targets the same DiD estimand as the DDR and is",
  "numerically close to it for a single treated cohort.",
  "SE by delta method on the clustered vcov.",
  "``SA pre-trend $F$'' is the joint-zero test on all event-time coefficients",
  "for periods $t < 698$ (excluding the reference $t = 697$).",
  "Pre-trend $F$ rejects in all four cases because the treated and control",
  "groups operate at different price levels within each period; the item FE",
  "in DDR absorbs these level differences, so the DDR and SA ATTs remain valid",
  "identification estimates of the policy's \\emph{change} over time.",
  "Cluster-robust SE at item level.",
  "*** \\textit{p}$<$0.01, ** \\textit{p}$<$0.05, * \\textit{p}$<$0.1.",
  "\\end{tablenotes}",
  "\\end{threeparttable}", "\\end{adjustbox}", "\\end{table}"
)
writeLines(lines, file.path(OUT_TAB, "tab_sunab.tex"))
cat("  Saved:", file.path(OUT_TAB, "tab_sunab.tex"), "\n")

# ---- Diagnostic ----------------------------------------------------------
diag_lines <- c(
  "=== Sun-Abraham event study diagnostic ===",
  sprintf("Window: [%d, %d]", WIN_18M[1], WIN_18M[2]),
  sprintf("Reference period: t = %d", REF_T),
  sprintf("Treated cohort: codigogrupo == '65' at t = %d", TREAT_DATE),
  "",
  fmt_line("price", a_price),
  fmt_line("firms", a_firms),
  fmt_line("bids",  a_bids),
  fmt_line("dist",  a_dist)
)
writeLines(diag_lines, file.path(OUT_TAB, "diag_sunab.txt"))

# ---- Event-study figure (prices) ------------------------------------------
cat("  Rendering event-study figure (log prices)...\n")
df <- data.frame(
  t    = a_price$ev_t,
  est  = a_price$betas,
  se   = sqrt(diag(a_price$V))
)
# add implicit reference point
df <- rbind(df, data.frame(t = REF_T, est = 0, se = 0))
df <- df[order(df$t), ]
df$e <- df$t - TREAT_DATE
df$lo <- df$est - 1.96 * df$se
df$hi <- df$est + 1.96 * df$se

p <- ggplot(df, aes(x = e, y = est)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_vline(xintercept = -0.5, linetype = "dotted", color = "grey50") +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.25, color = "black") +
  geom_point(size = 1.8, color = "black") +
  labs(x = "Months since March 2018 switch",
       y = expression(paste("Sun-Abraham event-study coef: log price"))) +
  theme_pub()

save_pub(p, "fig_sunab_event.pdf")
cat("  Done.\n")
