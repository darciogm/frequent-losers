# ----------------------------------------------------------------------
# Build the SME flag per bid. The v2 problem was relying only on
# Firms_final (snapshot 2026), which may diverge from the firm classification at auction time
# firm at the time of the auction. Here I (i) construct three variants of the
# flag starting from registry, (ii) cross-check against the historical counts of
# Paper2 (numfornecs_type_me/epp/oth_ph*), (iii) report disagreement rate by
# disagreement by time window.
#
# Prerequisite: rodar scripts/_extract_g65_keys.py before (gera o
# parquet data/processed/g65_keys.parquet, streaming of the raw CSV).
#
# Outputs:
#   data/processed/bid_level_sme_g65.parquet  — bid-level enriched
#   data/processed/g65_proxy_audit.parquet    — detalhe of the disagreement
#   logs/32_historical_sme.log                — summary textual
#   output/tables/tab_v3_sme_proxy_audit.tex  — table for appendix

source("/home/darciogm1/projetos/bitter-pills/paper2-me-epp/v3-structural/scripts/utils_v3.R")

logf <- file(path_v3("logs/32_historical_sme.log"), open = "wt")
on.exit(close(logf), add = TRUE)

con <- con_duck()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

log_step("32", "start: historical SME flag build + proxy audit", logf)

# 1. Firm registry -----------------------------------------------
# Receita Federal: porte_firm 01=ME, 03=EPP, 05=demais.
# fornec_enquad is the BEC self-classification; 1..5 SME variants, 6 non-SME.

firms_path <- file.path(p3_date, "Firms_final.parquet")
log_step("32", sprintf("lendo %s", firms_path), logf)

firms <- dbGetQuery(con, sprintf("
  SELECT
    códigofornecedor AS cod_forn,
    porte_firm,
    fornec_enquad,
    CAST(porte_firm IN ('01','03')   AS INTEGER) AS sme_porte,
    CAST(fornec_enquad IN (1,2,3,4,5)    AS INTEGER) AS sme_bec
  FROM read_parquet('%s')
", firms_path)) |> setDT()

firms[, sme_either := as.integer(sme_porte == 1 | sme_bec == 1)]
firms[, sme_both   := as.integer(sme_porte == 1 & sme_bec == 1)]

cat("\n--- distribution of the proxies (registry) ---\n", file = logf)
sink(logf, append = TRUE)
print(firms[, .(
  n           = .N,
  pct_porte   = round(mean(sme_porte)   * 100, 2),
  pct_bec     = round(mean(sme_bec)     * 100, 2),
  pct_either  = round(mean(sme_either)  * 100, 2),
  pct_both    = round(mean(sme_both)    * 100, 2)
)])
sink()

# Agreement porte × bec.
pA <- firms[, mean(sme_porte)]
pB <- firms[, mean(sme_bec)]
po <- firms[, mean(sme_porte == sme_bec)]
pe <- pA * pB + (1 - pA) * (1 - pB)
concordancia <- data.table(
  agreement = round(po * 100, 2),
  kappa     = round((po - pe) / (1 - pe), 3)
)
cat("\n--- agreement porte × bec ---\n", file = logf)
sink(logf, append = TRUE); print(concordancia); sink()

# 2. Cruzamento bid-level × chaves G65 × registry --------------------
bids_path <- file.path(p3_date, "bid_level_full.parquet")
keys_path <- path_v3("data/processed/g65_keys.parquet")

log_step("32", "join bid_level × g65_keys × firms_mini (DuckDB)", logf)

duckdb_register(con, "firms_mini", firms)

bids_g65 <- dbGetQuery(con, sprintf("
  SELECT
    b.numerodaoc,
    b.códigoitems                            AS codigoitem,
    b.códigofornecedor                      AS cod_forn,
    b.flagwinner                          AS won_raw,
    b.mêsanoencerramento                    AS ym_enc,
    b.descriçãoprocedimentocomto           AS proc_name,
    k.codigoclasse,
    k.preco_ref,
    k.date_oc_numb,
    f.sme_porte,
    f.sme_bec,
    f.sme_either,
    f.sme_both
  FROM read_parquet('%s') b
  INNER JOIN read_parquet('%s') k
    ON k.numerodaoc = b.numerodaoc
   AND k.codigoitems = b.códigoitem
  LEFT JOIN firms_mini f
    ON f.cod_forn = b.códigofornecedor
", bids_path, keys_path)) |> setDT()

log_step("32", sprintf("bids_g65 = %s rows",
                       formt(nrow(bids_g65), big.mark = ",")), logf)

# Normaliza won, modality e missing of the registry.
bids_g65[, won := fifelse(won_raw %in% c("1", "TRUE", "S", "Sim"), 1L, 0L)]
bids_g65[, mod := fcase(
  grepl("CONVITE",  proc_name, ignore.caif = TRUE), "convite",
  grepl("PREGÃO",   proc_name, ignore.caif = TRUE), "pregao",
  grepl("DISPENSA", proc_name, ignore.caif = TRUE), "dispensa",
  default = "outro"
)]
bids_g65[, missing_reg := as.integer(is.na(sme_porte))]

cat("\n--- coverage of the registry (missing rate by modality) ---\n", file = logf)
sink(logf, append = TRUE)
print(bids_g65[, .(bids = .N,
                   miss_pct = round(mean(missing_reg) * 100, 2)),
               by = mod])
sink()

# 3. Cross-check against counts historical -----------------------------
log_step("32", "agregando counts proxy e comparendo with historical", logf)

hist <- dbGetQuery(con, sprintf("
  SELECT
    numerodaoc,
    codigoitem,
    date_oc_numb,
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

# Treatment window: pre vs post March/2018.
cmp[, period := fcase(
  date_oc_numb < cutoff_m & date_oc_numb >= win_18m[1], "Pre",
  date_oc_numb >= cutoff_m & date_oc_numb <= win_18m[2], "Post",
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

cat("\n--- proxy vs historical (by modality) ---\n", file = logf)
sink(logf, append = TRUE); print(err_by_mod); sink()

cat("\n--- proxy vs historical (by modality × period) ---\n", file = logf)
sink(logf, append = TRUE); print(err_by_period); sink()

# 4. Outputs ----------------------------------------------------------
# Default: sme_bec (self-declaration BEC). Same source of the counts
# historical of the Paper2; so the audit against the historical matches better
# (exact 54%, bias smaller than the porte RF, which overestimates SME in
# 1.4–3.2 firms by auction). Troca revisitada in S5 como robustness.
bids_g65[, sme_flag := sme_bec]

out_cols <- c("numerodaoc", "codigoitem", "cod_forn",
              "mod", "won", "ym_enc",
              "codigoclasse", "preco_ref", "date_oc_numb",
              "sme_porte", "sme_bec", "sme_either", "sme_both",
              "sme_flag", "missing_reg")

arrow::write_parquet(bids_g65[, ..out_cols],
                     path_v3("data/processed/bid_level_sme_g65.parquet"),
                     compression = "snappy")

arrow::write_parquet(cmp,
                     path_v3("data/processed/g65_proxy_audit.parquet"),
                     compression = "snappy")

# Compact LaTeX table with the modality audit (for appendix).
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
    r$mod, formt(r$n_pairs, big.mark = ","),
    r$mae_porte, r$mae_bec, r$mae_either,
    r$exact_either_pct, r$bias_either))
}
tex_lines <- c(tex_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize",
  "\\items Auction-item-level comparison between three registry-based SME proxies",
  "(Receita porte, BEC enquadramento, and their union) and the historical SME-",
  "bidder counts reported in the raw Paper-2 CSV (last non-empty phase).",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")

writeLines(tex_lines, path_v3("output/tables/tab_v3_sme_proxy_audit.tex"))

log_step("32", "outputs writesdos", logf)

cat("\n--- summary final ---\n", file = logf)
sink(logf, append = TRUE)
print(bids_g65[, .(
  bids_total       = .N,
  bids_com_reg     = sum(missing_reg == 0),
  pct_sme_flag     = round(mean(sme_flag, na.rm = TRUE) * 100, 2)
), by = mod])
sink()

log_step("32", "done", logf)
