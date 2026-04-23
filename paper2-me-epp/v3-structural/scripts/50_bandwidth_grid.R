# S5 / task 50 -------------------------------------------------------
# Robustez da GPV inversion em Convite ao kernel bandwidth. O 42 roda
# com Silverman default (h_factor=1); aqui varremos h_factor ∈
# {0.5, 0.75, 1.0, 1.5, 2.0} para confirmar que c_0.5 e c_0.75 não
# dependem materialmente da bandwidth escolhida.
#
# Output: tab_v3_bandwidth_grid.tex (quantiles por h_factor × estrato).

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/50_bandwidth_grid.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("50", "start: GPV bandwidth grid", logf)

bids <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, n_firms_auc, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'convite'
    AND c_norm_clean > 0 AND c_norm_clean <= 3
    AND period IN ('Pre','Post')
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

bids[, n_bin := fcase(
  n_firms_auc == 2, "2",
  n_firms_auc == 3, "3",
  n_firms_auc == 4, "4",
  n_firms_auc >= 5, "5+",
  default = NA_character_)]

log_step("50", sprintf("convite bids = %s rows",
                       format(nrow(bids), big.mark = ",")), logf)

gpv_invert <- function(b, N_val, h_factor = 1) {
  b <- b[!is.na(b) & b > 0]
  n <- length(b)
  if (n < 50) return(NULL)
  h <- h_factor * 1.06 * sd(b) * n^(-1/5)
  dens <- density(b, bw = h, n = 512,
                  from = min(b) * 0.5, to = max(b) * 1.2)
  g_fun <- approxfun(dens$x, dens$y, rule = 2)
  F_emp <- ecdf(b)
  c_hat <- b - (1 - F_emp(b)) / ((N_val - 1) * g_fun(b))
  ok <- is.finite(c_hat) & c_hat > 0 & c_hat < b
  c_hat[ok]
}

h_grid <- c(0.5, 0.75, 1.0, 1.5, 2.0)
c_grid <- seq(0.005, 2, by = 0.005)
get_q <- function(c, F_c, q) approx(F_c, c, xout = q, rule = 2)$y

rows <- list()
for (h in h_grid) {
  for (per in c("Pre", "Post")) {
    for (ph in c(0, 1)) {
      for (sm in c(0, 1)) {
        c_bucket <- list()
        n_bucket <- c()
        for (nb in c("2", "3", "4", "5+")) {
          sub <- bids[period == per & pharma_narrow == ph &
                       sme_bec == sm & n_bin == nb]
          if (nrow(sub) < 100) next
          N_val <- mean(sub$n_firms_auc)
          c_hat <- gpv_invert(sub$c, N_val, h_factor = h)
          if (is.null(c_hat) || length(c_hat) < 50) next
          c_bucket[[length(c_bucket) + 1]] <- c_hat
          n_bucket <- c(n_bucket, length(c_hat))
        }
        if (length(c_bucket) == 0) next
        # Aggrega across n_bins ponderando por nrow.
        c_pooled <- unlist(c_bucket)
        F_c <- ecdf(c_pooled)(c_grid)
        rows[[length(rows) + 1]] <- data.table(
          h_factor = h, period = per,
          pharma_narrow = ph, sme_bec = sm,
          n_obs = length(c_pooled),
          c50 = round(get_q(c_grid, F_c, 0.50), 4),
          c75 = round(get_q(c_grid, F_c, 0.75), 4))
      }
    }
  }
}
res <- rbindlist(rows)
res[, pharma_lbl := fifelse(pharma_narrow == 1, "pharma", "non-pharma")]
res[, sme_lbl    := fifelse(sme_bec == 1, "SME", "non-SME")]
setorder(res, pharma_narrow, sme_bec, period, h_factor)

cat("\n--- quantiles c_0.5 e c_0.75 por bandwidth h_factor ---\n",
    file = logf)
sink(logf, append = TRUE)
print(res[, .(pharma_lbl, sme_lbl, period, h_factor, n_obs, c50, c75)])
sink()

# Range: max − min em c50 e c75 por estrato (qualitative robustness).
range_tab <- res[, .(
  n_h = .N,
  c50_min  = min(c50), c50_max = max(c50), c50_range = max(c50) - min(c50),
  c50_base = c50[h_factor == 1.0],
  c75_min  = min(c75), c75_max = max(c75), c75_range = max(c75) - min(c75),
  c75_base = c75[h_factor == 1.0]),
  by = .(pharma_lbl, sme_lbl, period)]
range_tab[, c50_range_pct := round(c50_range / c50_base * 100, 2)]
range_tab[, c75_range_pct := round(c75_range / c75_base * 100, 2)]

cat("\n--- robustness: range / baseline (h=1.0) como % ---\n",
    file = logf)
sink(logf, append = TRUE)
print(range_tab[, .(pharma_lbl, sme_lbl, period,
                    c50_base, c50_range, c50_range_pct,
                    c75_base, c75_range, c75_range_pct)])
sink()

# LaTeX --------------------------------------------------------------
res_wide <- dcast(res,
  pharma_lbl + sme_lbl + period ~ h_factor,
  value.var = "c50")
setnames(res_wide,
  c("0.5", "0.75", "1", "1.5", "2"),
  c("c50_h05", "c50_h075", "c50_h10", "c50_h15", "c50_h20"))

tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{GPV bandwidth robustness: median cost $c_{0.5}$ by $h$ factor}",
  "\\label{tab:v3_bandwidth_grid}",
  "\\small",
  "\\begin{tabular}{lllrrrrrr}",
  "\\toprule",
  " & & & \\multicolumn{5}{c}{$h / h_{\\text{Silverman}}$} & \\\\",
  "\\cmidrule(lr){4-8}",
  "Class & Type & Period & 0.5 & 0.75 & 1.0 & 1.5 & 2.0 & range \\\\",
  "\\midrule")
for (i in seq_len(nrow(res_wide))) {
  r <- res_wide[i]
  rng <- max(r$c50_h05, r$c50_h075, r$c50_h10,
             r$c50_h15, r$c50_h20) -
         min(r$c50_h05, r$c50_h075, r$c50_h10,
             r$c50_h15, r$c50_h20)
  tex <- c(tex, sprintf(
    "%s & %s & %s & %.3f & %.3f & %.3f & %.3f & %.3f & %.3f \\\\",
    r$pharma_lbl, r$sme_lbl, r$period,
    r$c50_h05, r$c50_h075, r$c50_h10,
    r$c50_h15, r$c50_h20, rng))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Each column reports $c_{0.5}$ of the GPV-inverted $F_c$ in",
  "Convite under bandwidth $h = h_{\\text{factor}} \\cdot",
  "1.06 \\cdot \\sigma_b \\cdot n^{-1/5}$ (Silverman's rule).",
  "Final column is max $-$ min across the 5 $h$ values. Robustness",
  "means range $\\ll c_{0.5}$ itself (typically <5\\% of baseline).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_bandwidth_grid.tex"))

log_step("50", "done", logf)
