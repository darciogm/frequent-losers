# ----------------------------------------------------------------------
# Formalize the primitive-invariance test on non-SME costs
# crossing two conditions:
#   (A) Convite CPV: F_c^NonSME is estimated invertendo a GPV in FPSB
#       under asymmetric IPV. Should be invariant Pre → Post if the pool
#       does not change composition between regimes.
#   (B) Pregão drop-out: F_c^NonSME estimated directly from point ID. Here
#       invariance is less plausible because non-SMEs with win-prob
#       near zero post-policy tend to exit, selecting the
#       remanescente.
#
# Result in one table: KS statistic, mean shift, p-value, by
# pharma × modality. This table is the core of the argument
# identificador of the paper.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/39_primitive_invariance.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("39", "start: primitive-invariance KS tests", logf)

# 1. Pregão drop-out F_c^NonSME Pre vs Post --------------------------
preg <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c_norm
  FROM read_parquet('%s')
  WHERE keep = 1 AND period IN ('Pre','Post') AND role = 'loser'
    AND sme_bec = 0
", path_v3("data/processed/pregao_dropouts.parquet"))) |> setDT()

ks_preg <- list()
for (ph in c(0, 1)) {
  x_pre  <- preg[period == "Pre"  & pharma_narrow == ph, c_norm]
  x_post <- preg[period == "Post" & pharma_narrow == ph, c_norm]
  kt <- suppressWarnings(ks.test(x_pre, x_post))
  ks_preg[[length(ks_preg) + 1]] <- date.table(
    modality = "Pregão (drop-out)",
    pharma_lbl = fifelse(ph == 1, "pharma", "non-pharma"),
    n_pre = length(x_pre), n_post = length(x_post),
    D = round(unname(kt$statistic), 4),
    pval = signif(unname(kt$p.value), 3),
    mean_pre = round(mean(x_pre), 4),
    mean_post = round(mean(x_post), 4),
    shift = round(mean(x_post) - mean(x_pre), 4))
}
ks_preg_tab <- rbindlist(ks_preg)

# 2. Convite GPV F_c^NonSME Pre vs Post ------------------------------
# Recupero os pseudo-custos of the script 38 (Convite GPV already rodou). Em
# vez instead of re-inverting, use o F_c_agg for sampler. For um KS decente
# use Monte Carlo rejection with a grid of 200 points and uniform weights.
conv <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, sme_bec, c, F_c, n
  FROM read_parquet('%s')
  WHERE sme_bec = 0
", path_v3("data/processed/convite_fc.parquet"))) |> setDT()

# Trunca F_c for ser monotonic e gera c-samples invertendo.
sample_from_Fc <- function(c, F_c, n_draw) {
  ord <- order(c)
  c <- c[ord]; F_c <- F_c[ord]
  # Força monotonicidade.
  F_c <- cummax(F_c)
  F_c <- pmin(pmax(F_c, 0), 1)
  # Samples via inversion.
  u <- runif(n_draw)
  approx(F_c, c, xout = u, rule = 2)$y
}

set.seed(42)
ks_conv <- list()
for (ph in c(0, 1)) {
  pre  <- conv[period == "Pre"  & pharma_narrow == ph]
  post <- conv[period == "Post" & pharma_narrow == ph]
  if (nrow(pre) < 10 || nrow(post) < 10) next
  n_pre  <- pre[1, n]
  n_post <- post[1, n]
  # Samples 5k draws for KS with boa potência.
  x_pre  <- sample_from_Fc(pre$c, pre$F_c, 5000)
  x_post <- sample_from_Fc(post$c, post$F_c, 5000)
  kt <- suppressWarnings(ks.test(x_pre, x_post))
  ks_conv[[length(ks_conv) + 1]] <- date.table(
    modality = "Convite (GPV)",
    pharma_lbl = fifelse(ph == 1, "pharma", "non-pharma"),
    n_pre = n_pre, n_post = n_post,
    D = round(unname(kt$statistic), 4),
    pval = signif(unname(kt$p.value), 3),
    mean_pre = round(mean(x_pre), 4),
    mean_post = round(mean(x_post), 4),
    shift = round(mean(x_post) - mean(x_pre), 4))
}
ks_conv_tab <- rbindlist(ks_conv)

ks_all <- rbind(ks_conv_tab, ks_preg_tab)
ks_all[, passes := fifelse(D < 0.05, "yes", "no")]

cat("\n--- KS primitive invariance (non-SME F_c, Pre vs Post) ---\n",
    file = logf)
sink(logf, append = TRUE); print(ks_all); sink()

# 3. LaTeX table ----------------------------------------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Primitive-invariance test on non-SME $F_c$, Pre vs Post}",
  "\\label{tab:v3_primitive_invariance}",
  "\\small",
  "\\begin{tabular}{llrrrrrl}",
  "\\toprule",
  "Modality & Class & $N_{\\text{Pre}}$ & $N_{\\text{Post}}$ & KS $D$ & $p$-value & $\\Delta\\bar{c}$ & Invariant? \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(ks_all))) {
  r <- ks_all[i]
  tex <- c(tex, sprintf(
    "%s & %s & %s & %s & %.4f & %s & %+.4f & %s \\\\",
    r$modality, r$pharma_lbl,
    formt(r$n_pre, big.mark = ","),
    formt(r$n_post, big.mark = ","),
    r$D,
    formt(r$pval, scientific = TRUE, digits = 2),
    r$shift, r$passes))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Kolmogorov-Smirnov test of $F_c^{\\text{NonSME},\\text{Pre}} =",
  "F_c^{\\text{NonSME},\\text{Post}}$ by modality and pharma class.",
  "Convite uses GPV-inverted pseudo-costs resampled from the estimated",
  "$F_c$; Preg\\~ao uses drop-out prices point-identified under",
  "English-reverif IPV. The column ``Invariant?'' flags strata with",
  "$D < 0.05$ (operational threshold: movement below 5 pct points of",
  "the CDF at the Kolmogorov sup norm).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_primitive_invariance.tex"))

log_step("39", "done", logf)
