# S3 / task 43 -------------------------------------------------------
# Re-roda o teste de primitive invariance (S2 script 39) usando F_c
# UH-cleaned. Pergunta: a invariância do primitivo de non-SME fica
# mais robusta depois que tiramos a UH auction-level?
#
# Pulo do Kotlarski non-paramétrico pra S5 — a versão BLP aqui é o
# semi-paramétrico, e já mostra que UH é substancial.

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/43_uh_invariance_update.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("43", "start: primitive invariance on UH-cleaned F_c", logf)

# 1. Pregão: KS em c_norm_clean dos perdedores non-SME ----------------
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

# 2. Convite: KS em c_norm_clean (como se fosse GPV input) ----------
# Nota: o c_norm_clean do Convite ainda representa o log-bid cleaned,
# não o custo; o KS em bids cleaned testa se o *bid primitive* é
# invariante. Como o GPV é monotônico, o teste em bids implica o
# teste em custos (em grandes amostras).

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

# 3. Carrega KS raw (do S2 / script 39) pra comparar lado a lado ----
# Refaço rapidamente em vez de mexer no arquivo do S2.
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

# Compara
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

cat("\n--- invariance UH-cleaned (todos os estratos) ---\n", file = logf)
sink(logf, append = TRUE)
print(ks_uh[, .(modality, pharma_lbl, n_pre, n_post, D, pval,
                mean_pre, mean_post, shift, passes)])
sink()

# 4. Tabela LaTeX final (raw + UH lado a lado) ----------------------
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
# Acrescenta Convite UH-clean (sem tabela raw no mesmo formato —
# reporto só o UH-clean pro Convite).
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
  "\\item Kolmogorov-Smirnov test on non-SME normalized bids Pre vs",
  "Post, before and after UH removal via BLP shrinkage.",
  "``Invariant?'' flags $D<0.05$. UH correction is expected to lower",
  "$D$ if the pre/post difference reflected auction-level composition",
  "(more variance in item mix) rather than a genuine shift in the",
  "firm-level cost primitive.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(tex, path_v3("output/tables/tab_v3_uh_invariance.tex"))

log_step("43", "done", logf)
