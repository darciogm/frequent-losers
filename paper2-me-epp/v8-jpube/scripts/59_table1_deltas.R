# 59_table1_deltas.R ---------------------------------------------------
# Fecha o gap M1a da auditoria forense: os 4 deltas "change in bidders"
# da Tabela 1 (bneNsmeDelta*, bneNnsDelta*) eram literais hand-entered no
# bloco "manual additions" do values.tex. Valores estavam corretos, mas
# sem script produtor. Aqui eles sao derivados das primitivas e o script
# para se nao baterem com os literais canonicos.
#
# Delta = count_post(exibido) - count_pre(exibido), arredondados a 2
# casas ANTES de subtrair, para garantir consistencia interna com as
# linhas Pre/Post da propria Tabela 1.
#
# Fontes:
#   n_sme_pre, n_ns_pre, n_sme_post : bne_decomp.parquet (1st-stage BNE)
#   nao-SME Post observado          : entry_rates.parquet (Pregao, Post)
# ----------------------------------------------------------------------

suppressMessages({library(duckdb); library(DBI); library(data.table)})

ROOT     <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
P_BNE    <- file.path(ROOT, "v7-jpube-tight/data/processed/bne_decomp.parquet")
P_ENTRY  <- file.path(ROOT, "v7-jpube-tight/data/processed/entry_rates.parquet")
OUT_FRAG <- file.path(ROOT, "v8-jpube/output/values_table1_deltas.tex")
LOG      <- file.path(ROOT, "v8-jpube/output/59_table1_deltas.log")

con <- dbConnect(duckdb()); on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
dbExecute(con, "PRAGMA threads=12")
logcon <- file(LOG, open = "wt"); on.exit(close(logcon), add = TRUE)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); writeLines(m, logcon) }
say("[59] Table-1 deltas from primitives | %s", Sys.time())

# 1. contagens-fonte ---------------------------------------------------
bne <- dbGetQuery(con, sprintf("
  SELECT pharma_narrow, n_sme_pre, n_ns_pre, n_sme_post
  FROM read_parquet('%s')", P_BNE)) |> setDT()
nns_post <- dbGetQuery(con, sprintf("
  SELECT pharma_narrow, AVG(n_nonsme_bid) AS nns_post
  FROM read_parquet('%s') WHERE mod='pregao' AND period='Post'
  GROUP BY 1", P_ENTRY)) |> setDT()
d <- merge(bne, nns_post, by = "pharma_narrow")

# 2. arredonda para o exibido e computa deltas -------------------------
r2 <- function(x) round(x, 2)
d[, `:=`(sme_pre = r2(n_sme_pre), nns_pre = r2(n_ns_pre),
         sme_post = r2(n_sme_post), nns_post = r2(nns_post))]
d[, `:=`(sme_delta = sme_post - sme_pre, nns_delta = nns_post - nns_pre)]
NP <- d[pharma_narrow == 0]; PH <- d[pharma_narrow == 1]
say("NP: SME %.2f->%.2f (delta %+.2f) | nonSME %.2f->%.2f (delta %+.2f)",
    NP$sme_pre, NP$sme_post, NP$sme_delta, NP$nns_pre, NP$nns_post, NP$nns_delta)
say("PH: SME %.2f->%.2f (delta %+.2f) | nonSME %.2f->%.2f (delta %+.2f)",
    PH$sme_pre, PH$sme_post, PH$sme_delta, PH$nns_pre, PH$nns_post, PH$nns_delta)

# 3. guarda contra divergencia com os literais canonicos ---------------
chk <- function(label, got, want) {
  ok <- isTRUE(all.equal(got, want, tolerance = 1e-9))
  say("  check %-16s computed=%+.2f canonical=%+.2f  %s", label, got, want,
      if (ok) "OK" else "*** MISMATCH ***")
  if (!ok) stop(sprintf("M1a guard failed: %s (%.2f != %.2f)", label, got, want))
}
say("--- verificacao contra values.tex ---")
chk("bneNsmeDeltaNp", NP$sme_delta, +0.93)
chk("bneNsmeDeltaPh", PH$sme_delta, +0.67)
chk("bneNnsDeltaNp",  NP$nns_delta, -1.18)
chk("bneNnsDeltaPh",  PH$nns_delta, -0.95)

# 4. fragmento de macros (proveniencia) --------------------------------
sgn <- function(x) sprintf("%+.2f", x)
f <- function(n, v, c="") sprintf("\\providecommand{\\%s}{}\\renewcommand{\\%s}{%s}%s",
                                  n, n, v, if (nzchar(c)) paste0(" % ", c) else "")
frag <- c(
  "% AUTO-GERADO por scripts/59_table1_deltas.R - fecha M1a.",
  "% ARTEFATO DE PROVENIENCIA: NAO \\input junto com values.tex.",
  "% Deltas = count_post(exibido) - count_pre(exibido), Tabela 1.",
  f("bneNsmeDeltaNp", sgn(NP$sme_delta), "= bneNsmePostNp - bneNsmePreNp"),
  f("bneNsmeDeltaPh", sgn(PH$sme_delta), "= bneNsmePostPh - bneNsmePrePh"),
  f("bneNnsDeltaNp",  sgn(NP$nns_delta), "= nonSmePostNp - bneNnsPreNp"),
  f("bneNnsDeltaPh",  sgn(PH$nns_delta), "= nonSmePostPh - bneNnsPrePh"))
writeLines(frag, OUT_FRAG)
say("fragmento escrito: %s", OUT_FRAG)
say("[59] done. M1a fechado.")
