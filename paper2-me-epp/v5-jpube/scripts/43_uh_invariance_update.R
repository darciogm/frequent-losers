# ----------------------------------------------------------------------
# Re-roda o primitive-invariance test (S2 script 39) usando F_c
# UH-cleaned. Question: does the primitive invariance of non-SME hold
# more robust after that tiramos a UH auction-level?
#
# Skip the Kotlarski non-parametric to S5 — a version BLP here is the
# semi-parametric, e already shows that UH is substantial.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/43_uh_invariance_update.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("43", "start: primitive invariance on UH-cleaned F_c", logf)

# 1. Pregão: KS in c_norm_clean of losers non-SME ----------------
preg <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'pregao' AND role = 'loser' AND sme_bec = 0
    AND period IN ('Pre','Post')
    AND c_norm_clean > 0 AND c_norm_clean <= 3
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

ks_preg_list <- list()
for (ph in c(0, 1)) {
  x_pre  <- preg[period == "Pre"  & pharma_narrow == ph, c]
  x_post <- preg[period == "Post" & pharma_narrow == ph, c]
  kt <- suppressWarnings(ks.test(x_pre, x_post))
  ks_preg_list[[length(ks_preg_list) + 1]] <- data.table(
    modality = "Pregão (drop-out, UH-clean)",
    pharma_lbl = fifelse(ph == 1, "pharma", "non-pharma"),
    n_pre = length(x_pre), n_post = length(x_post),
    D = round(unname(kt$statistic), 4),
    pval = signif(unname(kt$p.value), 3),
    mean_pre = round(mean(x_pre), 4),
    mean_post = round(mean(x_post), 4),
    shift = round(mean(x_post) - mean(x_pre), 4))
}

# 2. Convite: KS on c_norm_clean (as if it were a GPV input) ----------
# Nota: o c_norm_clean of the Convite still representa o log-bid cleaned,
# not the cost; the KS test on cleaned bids tests whether the *bid primitive* is
# invariant. Since GPV is monotonic, the test on bids implies o
# test in costs (in grandes samples).

conv <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, c_norm_clean AS c
  FROM read_parquet('%s')
  WHERE mod = 'convite' AND sme_bec = 0
    AND period IN ('Pre','Post')
    AND c_norm_clean > 0 AND c_norm_clean <= 3
", path_v3("data/processed/bids_uh_cleaned.parquet"))) |> setDT()

ks_conv_list <- list()
for (ph in c(0, 1)) {
  x_pre  <- conv[period == "Pre"  & pharma_narrow == ph, c]
  x_post <- conv[period == "Post" & pharma_narrow == ph, c]
  if (length(x_pre) < 100 || length(x_post) < 100) next
  kt <- suppressWarnings(ks.test(x_pre, x_post))
  ks_conv_list[[length(ks_conv_list) + 1]] <- data.table(
    modality = "Convite (GPV input, UH-clean)",
    pharma_lbl = fifelse(ph == 1, "pharma", "non-pharma"),
    n_pre = length(x_pre), n_post = length(x_post),
    D = round(unname(kt$statistic), 4),
    pval = signif(unname(kt$p.value), 3),
    mean_pre = round(mean(x_pre), 4),
    mean_post = round(mean(x_post), 4),
    shift = round(mean(x_post) - mean(x_pre), 4))
}

ks_uh <- rbind(rbindlist(ks_conv_list), rbindlist(ks_preg_list))
ks_uh[, passes := fifelse(D < 0.05, "yes", "no")]

# 3. Load raw KS (from S2 / script 39) to compare side by side ----
# Redo rapidamente instead of touching in the file from S2.
preg_raw <- dbGetQuery(con, sprintf("
  SELECT period, pharma_narrow, c_norm AS c
  FROM read_parquet('%s')
  WHERE keep = 1 AND role = 'loser' AND sme_bec = 0
    AND period IN ('Pre','Post')
", path_v3("data/processed/pregao_dropouts.parquet"))) |> setDT()

ks_raw_list <- list()
for (ph in c(0, 1)) {
  x_pre  <- preg_raw[period == "Pre"  & pharma_narrow == ph, c]
  x_post <- preg_raw[period == "Post" & pharma_narrow == ph, c]
  kt <- suppressWarnings(ks.test(x_pre, x_post))
  ks_raw_list[[length(ks_raw_list) + 1]] <- data.table(
    modality = "Pregão (drop-out, RAW)",
    pharma_lbl = fifelse(ph == 1, "pharma", "non-pharma"),
    D_raw = round(unname(kt$statistic), 4),
    shift_raw = round(mean(x_post) - mean(x_pre), 4))
}
ks_raw <- rbindlist(ks_raw_list)

# Compare
ks_preg_clean <- ks_uh[grepl("Pregão", modality)]
cmp <- merge(
  ks_preg_clean[, .(pharma_lbl, D_clean = D, shift_clean = shift)],
  ks_raw,
  by = "pharma_lbl")
cmp[, D_delta := round(D_clean - D_raw, 4)]
cmp[, shift_delta := round(shift_clean - shift_raw, 4)]

cat("\n--- invariance: raw vs UH-clean (Pregão non-SME) ---\n",
    file = logf)
sink(logf, append = TRUE)
print(cmp[, .(pharma_lbl, D_raw, D_clean, D_delta,
              shift_raw, shift_clean, shift_delta)])
sink()

cat("\n--- invariance UH-cleaned (todos os strata) ---\n", file = logf)
sink(logf, append = TRUE)
print(ks_uh[, .(modality, pharma_lbl, n_pre, n_post, D, pval,
                mean_pre, mean_post, shift, passes)])
sink()

# 4. Final LaTeX table (raw + UH side by side) ----------------------
tex <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Primitive invariance of non-SME $F_c$ (raw vs UH-corrected)}",
  "\\label{tab:v3_uh_invariance}",
  "\\small",
  "\\begin{tabular}{llrrrrr}",
  "\\toprule",
  "Modality & Class & KS $D^{\\text{raw}}$ & KS $D^{\\text{clean}}$ & $\\Delta\\bar{c}^{\\text{raw}}$ & $\\Delta\\bar{c}^{\\text{clean}}$ & Invariant? \\\\",
  "\\midrule"
)
for (i in seq_len(nrow(cmp))) {
  r <- cmp[i]
  inv_flag <- fifelse(r$D_clean < 0.05, "yes", "no")
  tex <- c(tex, sprintf(
    "Preg\\~ao & %s & %.4f & %.4f & %+.4f & %+.4f & %s \\\\",
    r$pharma_lbl, r$D_raw, r$D_clean,
    r$shift_raw, r$shift_clean, inv_flag))
}
# Acrescenta Convite UH-clean (without table raw in the same formto —
# report only o UH-clean pro Convite).
for (i in seq_len(nrow(ks_uh[grepl("Convite", modality)]))) {
  r <- ks_uh[grepl("Convite", modality)][i]
  tex <- c(tex, sprintf(
    "Convite & %s & --- & %.4f & --- & %+.4f & %s \\\\",
    r$pharma_lbl, r$D, r$shift, r$passes))
}
tex <- c(tex,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Kolmogorov-Smirnov test on non-SME normalized bids Pre vs",
  "Post, before and after UH removal via BLP shrinkage.",
  "``Invariant?'' flags $D<0.05$. UH correction is expected to lower",
  "$D$ if the pre/post difference reflected auction-level composition",
  "(more variance in items mix) rather than a genuine shift in the",
  "firm-level cost primitive.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_uh_invariance.tex"))

log_step("43", "done", logf)
