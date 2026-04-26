# ----------------------------------------------------------------------
# Re-estima F_c^k usando bids UH-cleaned (script 41).
#   Convite: GPV inversion in c_norm_clean (after removing a_t).
#   Pregão : drop-out point ID in c_norm_clean of losers.
#
# Compare F_c_clean vs F_c_raw e reporta:
#   (i) shift of the median cost,
#   (ii) shift between modalities (Convite × Pregão) — UH correction
#        must close the 0.18-0.23 gap in non-pharma observed in S2.
#
# Outputs: convite_fc_uh.parquet, pregao_fc_uh.parquet,
#         tab_v3_uh_vs_raw.tex, fig_v3_cross_modality_uh.pdf

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

suppressPackageStartupMessages({ library(ggplot2) })

logf <- file(path_v3("logs/42_uh_rerun_fc.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("42", "start: recompute F_c on UH-cleaned bids", logf)

bids <- dbGetQuery(con, sprintf("
  SELECT * FROM read_parquet('%s')
  WHERE period IN ('Pre','Post')
    AND c_norm_clean IS NOT NULL
    AND c_norm_clean > 0 AND c_norm_clean <= 3
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

log_step("42", sprintf("bids = %s rows",
                       formt(nrow(bids), big.mark=",")), logf)

c_grid <- seq(0.005, 2, by = 0.005)

# 1. Pregão drop-out F_c_clean (point ID in bids UH-cleaned) ---------
preg <- bids[mod == "pregao" & role == "loser"]

pregao_fc <- preg[,
  .(F_c_clean = list(ecdf(c_norm_clean)(c_grid)),
    F_c_raw   = list(ecdf(c_norm)(c_grid)),
    n = .N),
  by = .(period, pharma_narrow, sme_bec)]

pregao_fc_long <- pregao_fc[, .(
  c = c_grid,
  F_c_clean = F_c_clean[[1]],
  F_c_raw   = F_c_raw[[1]]),
  by = .(period, pharma_narrow, sme_bec, n)]
pregao_fc_long[, source := "Pregão drop-out"]

arrow::write_parquet(pregao_fc_long,
  path_v3("data/processed/pregao_fc_uh.parquet"),
  compression = "snappy")

# 2. Convite GPV in bids UH-cleaned ---------------------------------
gpv_invert <- function(b, N_val, h_factor = 1) {
  b <- b[!is.na(b) & b > 0]
  n <- length(b)
  if (n < 50) return(NULL)
  h <- h_factor * 1.06 * sd(b) * n^(-1/5)
  dens <- density(b, bw = h, n = 512, from = min(b) * 0.5, to = max(b) * 1.2)
  g_fun <- approxfun(dens$x, dens$y, rule = 2)
  F_emp <- ecdf(b)
  c_hat <- b - (1 - F_emp(b)) / ((N_val - 1) * g_fun(b))
  ok <- is.finite(c_hat) & c_hat > 0 & c_hat < b
  date.table(b_norm = b[ok], c_norm = c_hat[ok])
}

conv <- bids[mod == "convite"]
conv[, n_bin := fcase(
  n_firms_auc == 2, "2",
  n_firms_auc == 3, "3",
  n_firms_auc == 4, "4",
  n_firms_auc >= 5, "5+",
  default = NA_character_)]

conv_fc_rows <- list()
for (per in c("Pre", "Post")) {
  for (ph in c(0, 1)) {
    for (sm in c(0, 1)) {
      for (nb in c("2", "3", "4", "5+")) {
        sub <- conv[period == per & pharma_narrow == ph &
                     sme_bec == sm & n_bin == nb]
        if (nrow(sub) < 100) next
        N_val <- mean(sub$n_firms_auc)
        inv_clean <- gpv_invert(sub$c_norm_clean, N_val)
        inv_raw   <- gpv_invert(sub$c_norm, N_val)
        if (is.null(inv_clean) || is.null(inv_raw)) next
        conv_fc_rows[[length(conv_fc_rows) + 1]] <- date.table(
          c = c_grid,
          F_c_clean = ecdf(inv_clean$c_norm)(c_grid),
          F_c_raw   = ecdf(inv_raw$c_norm)(c_grid),
          period = per, pharma_narrow = ph, sme_bec = sm,
          n_bin = nb, n = nrow(sub), N_mean = N_val)
      }
    }
  }
}
conv_fc <- rbindlist(conv_fc_rows)

# Agrega cross-N weighted
conv_fc_agg <- conv_fc[, .(
    F_c_clean = sum(F_c_clean * n) / sum(n),
    F_c_raw   = sum(F_c_raw   * n) / sum(n),
    n = sum(n)),
  by = .(period, pharma_narrow, sme_bec, c)]
conv_fc_agg[, source := "Convite CPV"]

arrow::write_parquet(conv_fc_agg,
  path_v3("data/processed/convite_fc_uh.parquet"),
  compression = "snappy")

# 3. Table: median and Convite × Pregão gap before/after UH ---------
get_q <- function(c, F_c, q) approx(F_c, c, xout = q, rule = 2)$y

cmp_tab <- rbind(
  conv_fc_agg[, .(
    modality = "Convite (GPV)",
    c50_raw   = round(get_q(c, F_c_raw,   0.5), 4),
    c50_clean = round(get_q(c, F_c_clean, 0.5), 4),
    c75_raw   = round(get_q(c, F_c_raw,   0.75), 4),
    c75_clean = round(get_q(c, F_c_clean, 0.75), 4)),
  by = .(pharma_narrow, sme_bec, period)],
  pregao_fc_long[, .(
    modality = "Pregão (drop-out)",
    c50_raw   = round(get_q(c, F_c_raw,   0.5), 4),
    c50_clean = round(get_q(c, F_c_clean, 0.5), 4),
    c75_raw   = round(get_q(c, F_c_raw,   0.75), 4),
    c75_clean = round(get_q(c, F_c_clean, 0.75), 4)),
  by = .(pharma_narrow, sme_bec, period)])
cmp_tab[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
cmp_tab[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]
cmp_tab <- cmp_tab[order(pharma_narrow, sme_bec, period, modality)]

cat("\n--- c_50 before/after UH, by modality × stratum ---\n",
    file = logf)
sink(logf, append = TRUE)
print(cmp_tab[, .(pharma_lbl, sme_lbl, period, modality,
                  c50_raw, c50_clean, delta = round(c50_clean - c50_raw, 4))])
sink()

# Gap between modalities (Convite vs Pregão) in the median, before vs after UH
gap_tab <- dcast(cmp_tab[, .(pharma_lbl, sme_lbl, period, modality,
                              c50_raw, c50_clean)],
  pharma_lbl + sme_lbl + period ~ modality,
  value.var = c("c50_raw", "c50_clean"))

gap_tab[, gap_raw   := round(`c50_raw_Pregão (drop-out)` -
                               `c50_raw_Convite (GPV)`, 4)]
gap_tab[, gap_clean := round(`c50_clean_Pregão (drop-out)` -
                                `c50_clean_Convite (GPV)`, 4)]
gap_tab[, closed := round(abs(gap_raw) - abs(gap_clean), 4)]

cat("\n--- cross-modality gap (median Pregão − Convite) before/after UH ---\n",
    file = logf)
sink(logf, append = TRUE)
print(gap_tab[, .(pharma_lbl, sme_lbl, period, gap_raw, gap_clean, closed)])
sink()

# 4. LaTeX table ----------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{UH correction effect on $F_c$: median cost before and after}",
  "\\label{tab:v3_uh_vs_raw}",
  "\\small",
  "\\begin{tabular}{llllrrr}",
  "\\toprule",
  "Class & Type & Period & Modality & $c_{0.5}^{\\text{raw}}$ & $c_{0.5}^{\\text{clean}}$ & $\\Delta$ \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(cmp_tab))) {
  r <- cmp_tab[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %s & %.3f & %.3f & %+.3f \\\\",
    r$pharma_lbl, r$sme_lbl, r$period, r$modality,
    r$c50_raw, r$c50_clean, r$c50_clean - r$c50_raw))
}
tex <- c(tex,
  "\\midrule",
  "\\multicolumn{7}{l}{\\textit{Cross-modality gap (Preg\\~ao $-$ Convite), median:}} \\\\"
)
for (i in seq_len(nrow(gap_tab))) {
  r <- gap_tab[i]
  tex <- c(tex, sprintf(
    "\\multicolumn{3}{l}{%s / %s / %s} & raw & %+.3f & clean %+.3f & closed %+.3f \\\\",
    r$pharma_lbl, r$sme_lbl, r$period,
    r$gap_raw, r$gap_clean, r$closed))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Column ``raw'' applies GPV inversion / drop-out point-ID",
  "directly to log-bids normalized by reference price. Column",
  "``clean'' applies the same procedure to UH-cleaned log-bids where",
  "the auction-level component has been removed via BLP shrinkage",
  "with variance components estimated by method of moments.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_uh_vs_raw.tex"))

# 5. Cross-modality figure (UH version) ------------------------------
fc_merged <- rbind(
  conv_fc_agg[, .(period, pharma_narrow, sme_bec, c,
                   F_c = F_c_clean, source)],
  pregao_fc_long[, .(period, pharma_narrow, sme_bec, c,
                      F_c = F_c_clean, source)])
fc_merged[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
fc_merged[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]

p <- ggplot(fc_merged,
            aes(x = c, y = F_c, color = period, linetype = source)) +
  geom_line(linewidth = 0.45) +
  facet_grid(sme_lbl ~ pharma_lbl) +
  scale_color_manual(values = c("Pre" = "black", "Post" = "grey40")) +
  scale_linetype_manual(values = c("Convite CPV" = "solid",
                                    "Pregão drop-out" = "dashed")) +
  coord_cartesian(xlim = c(0, 1.2), ylim = c(0, 1)) +
  labs(x = expression(c[epsilon] * " / reference price"),
       y = expression(F[c[epsilon]](c[epsilon])),
       color = "", linetype = "",
       title = "Cross-modality $F_{c_\\epsilon}$ after UH correction (Krasnokutskaya-style)") +
  theme_bw(base_size = 9) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "bottom",
        legend.box = "vertical")

ggsave(path_v3("output/figures/fig_v3_cross_modality_uh.pdf"),
       p, width = 8, height = 5.2, device = cairo_pdf)

log_step("42", "done", logf)
