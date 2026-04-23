# S1 / task 32 -------------------------------------------------------
# Monta o flag SME por lance. O problema de v2 era depender só de
# Firms_final (snapshot 2026), que pode divergir da classificação da
# firma no momento do leilão. Aqui eu (i) construo três variantes do
# flag a partir do registro, (ii) cruzo contra os counts históricos do
# Paper2 (numfornecs_type_me/epp/oth_ph*), (iii) reporto taxa de
# discordância por janela de tempo.
#
# Pré-requisito: rodar scripts/_extract_g65_keys.py antes (gera o
# parquet data/processed/g65_keys.parquet, streaming do CSV cru).
#
# Saídas:
#   data/processed/bid_level_sme_g65.parquet  — bid-level enriquecido
#   data/processed/g65_proxy_audit.parquet    — detalhe da discordância
#   logs/32_historical_sme.log                — sumário textual
#   output/tables/tab_v3_sme_proxy_audit.tex  — tabela para appendix

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/32_historical_sme.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("32", "start: historical SME flag build + proxy audit", logf)

# 1. Registro de firmas -----------------------------------------------
# Receita Federal: porte_empresa 01=ME, 03=EPP, 05=demais.
# fornec_enquad é a autoclassificação BEC; 1..5 variantes de SME, 6 não-SME.

firms_path <- file.path(p3_data, "Firms_final.parquet")
log_step("32", sprintf("lendo %s", firms_path), logf)

firms <- dbGetQuery(con, sprintf("
  SELECT
    códigofornecedor AS cod_forn,
    porte_empresa,
    fornec_enquad,
    CAST(porte_empresa IN ('01','03')   AS INTEGER) AS sme_porte,
    CAST(fornec_enquad IN (1,2,3,4,5)    AS INTEGER) AS sme_bec
  FROM read_parquet('%s')
", firms_path)) |> setDT()

firms[, sme_either := as.integer(sme_porte == 1 | sme_bec == 1)]
firms[, sme_both   := as.integer(sme_porte == 1 & sme_bec == 1)]

cat("\n--- distribuição das proxies (cadastro) ---\n", file = logf)
sink(logf, append = TRUE)
print(firms[, .(
  n           = .N,
  pct_porte   = round(mean(sme_porte)   * 100, 2),
  pct_bec     = round(mean(sme_bec)     * 100, 2),
  pct_either  = round(mean(sme_either)  * 100, 2),
  pct_both    = round(mean(sme_both)    * 100, 2)
)])
sink()

# Concordância porte × bec.
pA <- firms[, mean(sme_porte)]
pB <- firms[, mean(sme_bec)]
po <- firms[, mean(sme_porte == sme_bec)]
pe <- pA * pB + (1 - pA) * (1 - pB)
concordancia <- data.table(
  agreement = round(po * 100, 2),
  kappa     = round((po - pe) / (1 - pe), 3)
)
cat("\n--- concordância porte × bec ---\n", file = logf)
sink(logf, append = TRUE); print(concordancia); sink()

# 2. Cruzamento bid-level × chaves G65 × registro --------------------
bids_path <- file.path(p3_data, "bid_level_full.parquet")
keys_path <- path_v3("data/processed/g65_keys.parquet")

log_step("32", "join bid_level × g65_keys × firms_mini (DuckDB)", logf)

duckdb_register(con, "firms_mini", firms)

bids_g65 <- dbGetQuery(con, sprintf("
  SELECT
    b.numerodaoc,
    b.códigoitem                            AS codigoitem,
    b.códigofornecedor                      AS cod_forn,
    b.flagvencedor                          AS won_raw,
    b.mêsanoencerramento                    AS ym_enc,
    b.descriçãoprocedimentocompra           AS proc_name,
    k.codigoclasse,
    k.preco_ref,
    k.data_oc_numb,
    f.sme_porte,
    f.sme_bec,
    f.sme_either,
    f.sme_both
  FROM read_parquet('%s') b
  INNER JOIN read_parquet('%s') k
    ON k.numerodaoc = b.numerodaoc
   AND k.codigoitem = b.códigoitem
  LEFT JOIN firms_mini f
    ON f.cod_forn = b.códigofornecedor
", bids_path, keys_path)) |> setDT()

log_step("32", sprintf("bids_g65 = %s linhas",
                       format(nrow(bids_g65), big.mark = ",")), logf)

# Normaliza won, modality e missing do registro.
bids_g65[, won := fifelse(won_raw %in% c("1", "TRUE", "S", "Sim"), 1L, 0L)]
bids_g65[, mod := fcase(
  grepl("CONVITE",  proc_name, ignore.case = TRUE), "convite",
  grepl("PREGÃO",   proc_name, ignore.case = TRUE), "pregao",
  grepl("DISPENSA", proc_name, ignore.case = TRUE), "dispensa",
  default = "outro"
)]
bids_g65[, missing_reg := as.integer(is.na(sme_porte))]

cat("\n--- cobertura do registro (missing rate por modalidade) ---\n", file = logf)
sink(logf, append = TRUE)
print(bids_g65[, .(bids = .N,
                   miss_pct = round(mean(missing_reg) * 100, 2)),
               by = mod])
sink()

# 3. Cross-check contra counts históricos -----------------------------
log_step("32", "agregando counts proxy e comparando com histórico", logf)

hist <- dbGetQuery(con, sprintf("
  SELECT
    numerodaoc,
    codigoitem,
    data_oc_numb,
    GREATEST(n_me_ph1,  n_me_ph3,  n_me_ph4,  n_me_ph6,  n_me_ph7)  AS n_me_hist,
    GREATEST(n_epp_ph1, n_epp_ph3, n_epp_ph4, n_epp_ph6, n_epp_ph7) AS n_epp_hist,
    GREATEST(n_oth_ph1, n_oth_ph3, n_oth_ph4, n_oth_ph6, n_oth_ph7) AS n_oth_hist,
    GREATEST(n_all_ph1, n_all_ph3, n_all_ph4, n_all_ph6, n_all_ph7) AS n_all_hist
  FROM read_parquet('%s')
", keys_path)) |> setDT()

hist[, n_sme_hist := pmax(n_me_hist, 0, na.rm = TRUE) +
                      pmax(n_epp_hist, 0, na.rm = TRUE)]

agg_bids <- bids_g65[!is.na(sme_porte) & mod %in% c("convite", "pregao"),
  .(n_sme_porte  = sum(sme_porte),
    n_sme_bec    = sum(sme_bec),
    n_sme_either = sum(sme_either),
    n_bidders    = .N),
  by = .(numerodaoc, codigoitem, mod)]

cmp <- merge(agg_bids, hist,
             by = c("numerodaoc", "codigoitem"),
             all.x = TRUE)

# Janela de tratamento: pré vs pós março/2018.
cmp[, period := fcase(
  data_oc_numb < cutoff_m & data_oc_numb >= win_18m[1], "Pre",
  data_oc_numb >= cutoff_m & data_oc_numb <= win_18m[2], "Post",
  default = "fora")]

err_by_mod <- cmp[!is.na(n_sme_hist),
  .(n_pairs          = .N,
    mae_porte        = round(mean(abs(n_sme_porte  - n_sme_hist)), 3),
    mae_bec          = round(mean(abs(n_sme_bec    - n_sme_hist)), 3),
    mae_either       = round(mean(abs(n_sme_either - n_sme_hist)), 3),
    bias_porte       = round(mean(n_sme_porte  - n_sme_hist), 3),
    bias_bec         = round(mean(n_sme_bec    - n_sme_hist), 3),
    bias_either      = round(mean(n_sme_either - n_sme_hist), 3),
    exact_porte_pct  = round(mean(n_sme_porte  == n_sme_hist) * 100, 2),
    exact_bec_pct    = round(mean(n_sme_bec    == n_sme_hist) * 100, 2),
    exact_either_pct = round(mean(n_sme_either == n_sme_hist) * 100, 2)),
  by = mod]

err_by_period <- cmp[!is.na(n_sme_hist) & period %in% c("Pre", "Post"),
  .(n_pairs    = .N,
    mae_either = round(mean(abs(n_sme_either - n_sme_hist)), 3),
    bias_either = round(mean(n_sme_either - n_sme_hist), 3),
    exact_pct   = round(mean(n_sme_either == n_sme_hist) * 100, 2)),
  by = .(mod, period)]

cat("\n--- proxy vs histórico (por modalidade) ---\n", file = logf)
sink(logf, append = TRUE); print(err_by_mod); sink()

cat("\n--- proxy vs histórico (por modalidade × período) ---\n", file = logf)
sink(logf, append = TRUE); print(err_by_period); sink()

# 4. Outputs ----------------------------------------------------------
# Default: sme_bec (autodeclaração BEC). Mesma fonte dos counts
# históricos do Paper2, logo o audit contra o histórico bate melhor
# (exact 54%, bias menor que o porte RF, que superestima SME em
# 1.4–3.2 firmas por leilão). Troca revisitada em S5 como robustez.
bids_g65[, sme_flag := sme_bec]

out_cols <- c("numerodaoc", "codigoitem", "cod_forn",
              "mod", "won", "ym_enc",
              "codigoclasse", "preco_ref", "data_oc_numb",
              "sme_porte", "sme_bec", "sme_either", "sme_both",
              "sme_flag", "missing_reg")

arrow::write_parquet(bids_g65[, ..out_cols],
                     path_v3("data/processed/bid_level_sme_g65.parquet"),
                     compression = "snappy")

arrow::write_parquet(cmp,
                     path_v3("data/processed/g65_proxy_audit.parquet"),
                     compression = "snappy")

# Tabela LaTeX compacta com o audit por modalidade (vai para appendix).
tex_lines <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{SME proxy validation: registry vs historical bidder counts}",
  "\\label{tab:v3_sme_proxy_audit}",
  "\\begin{tabular}{lrrrrrr}",
  "\\toprule",
  " & N pairs & MAE porte & MAE BEC & MAE union & Exact union (\\%) & Bias union \\\\",
  "\\midrule"
)
for (row_i in seq_len(nrow(err_by_mod))) {
  r <- err_by_mod[row_i]
  tex_lines <- c(tex_lines, sprintf(
    "%s & %s & %.3f & %.3f & %.3f & %.2f & %.3f \\\\",
    r$mod, format(r$n_pairs, big.mark = ","),
    r$mae_porte, r$mae_bec, r$mae_either,
    r$exact_either_pct, r$bias_either))
}
tex_lines <- c(tex_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\item Auction-item-level comparison between three registry-based SME proxies",
  "(Receita porte, BEC enquadramento, and their union) and the historical SME-",
  "bidder counts reported in the raw Paper-2 CSV (last non-empty phase).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")

writeLines(tex_lines, path_v3("output/tables/tab_v3_sme_proxy_audit.tex"))

log_step("32", "outputs gravados", logf)

cat("\n--- summary final ---\n", file = logf)
sink(logf, append = TRUE)
print(bids_g65[, .(
  bids_total       = .N,
  bids_com_reg     = sum(missing_reg == 0),
  pct_sme_flag     = round(mean(sme_flag, na.rm = TRUE) * 100, 2)
), by = mod])
sink()

log_step("32", "done", logf)
