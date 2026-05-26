# 58_welfare_annual.R --------------------------------------------------
# Rebuild da escala monetaria anual do custo de welfare do set-aside SME
# (Grupo 65) a partir de primitivas v8. Fecha o gap M2 da auditoria
# forense: ate aqui os ancoras R$55M (NP) / R$73M (PH) a 100% de
# aderencia eram literais transcritos de uma tabela de manuscrito antiga
# (06_welfare.tex), sem derivacao reproduzivel. Aqui cada fator e
# computado e logado.
#
# Cadeia:
#   perda_anual(aderencia) = loss_fraction x outlay_realizado x aderencia
#   outlay_realizado       = outlay_referencia x ratio_realizado/ref
#   outlay_referencia      = SUM(valor_total_ref) | G65, Post, completed
#   loss_fraction          = total_loss (de p^ref), lambda=0.30
#
# Os dois "fatores embutidos" que a auditoria nao localizava sao:
#   (i)  o filtro de itens concluidos (oc_item_status==1) -> completion;
#   (ii) o ratio realizado/referencia (preco_final/preco_ref ~ 0.69).
#
# Base maintained = REALIZADO (conservadora, casa com o paper). A base
# de REFERENCIA e reportada como sensibilidade superior.
# ----------------------------------------------------------------------

suppressMessages({library(duckdb); library(DBI); library(data.table)})

ROOT     <- "/home/darciogm1/projetos/bitter-pills/paper2-me-epp"
P_MAIN   <- file.path(ROOT, "data/processed/paper2_me_epp.parquet")
P_DECOMP <- file.path(ROOT, "v7-jpube-tight/data/processed/welfare_decomp.parquet")
OUT_FRAG <- file.path(ROOT, "v8-jpube/output/values_welfare_annual.tex")
LOG      <- file.path(ROOT, "v8-jpube/output/58_welfare_annual.log")

# parametros do desenho (mesmos do paper)
LAMBDA      <- 0.30
POST_LO     <- 698L; POST_HI <- 715L      # janela Post, Stata m (18 meses)
ANNUALIZE   <- 12 / 18                     # 18m -> 12m
FX          <- 3.50                        # R$/US$ fim de 2018
PH_CLASSES  <- "(6531,6532,6536,6581)"     # classes pharma_narrow=1 (CMED etc.)
ADHERENCE   <- c(0.30, 0.43, 0.55, 0.70, 0.85, 1.00)
RATIO_CAP   <- 1.5                          # corta outliers de preco_final/preco_ref

con <- dbConnect(duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
dbExecute(con, "PRAGMA threads=12")
dbExecute(con, "PRAGMA memory_limit='14GB'")

logcon <- file(LOG, open = "wt"); on.exit(close(logcon), add = TRUE)
say <- function(...) { msg <- sprintf(...); cat(msg, "\n"); writeLines(msg, logcon) }
say("[58] rebuild welfare anual | host=%s | %s", Sys.info()[["nodename"]], Sys.time())

# 1. loss fractions estruturais (de p^ref), lambda=0.30 ----------------
decomp <- dbGetQuery(con, sprintf("
  SELECT pharma_narrow, total_loss, loss_pct_S1, mean_p_S1
  FROM read_parquet('%s') WHERE \"lambda\" = %f", P_DECOMP, LAMBDA)) |> setDT()
loss_np <- decomp[pharma_narrow == 0, total_loss]
loss_ph <- decomp[pharma_narrow == 1, total_loss]
say("loss_fraction (de p^ref) NP=%.4f (%.2f%% de p_S1) | PH=%.4f (%.2f%%)",
    loss_np, decomp[pharma_narrow==0, loss_pct_S1],
    loss_ph, decomp[pharma_narrow==1, loss_pct_S1])

# 2. outlay referencia + ratio realizado, G65 Post completed -----------
agg <- dbGetQuery(con, sprintf("
  WITH g AS (
    SELECT CASE WHEN class_alt IN %s THEN 1 ELSE 0 END AS pharma,
           valor_total_ref AS vtr,
           preco_final / NULLIF(preco_ref, 0) AS unit_ratio
    FROM read_parquet('%s')
    WHERE codigogrupo = 65
      AND data_oc_numb BETWEEN %d AND %d
      AND oc_item_status = 1
  )
  SELECT pharma,
         COUNT(*)                                    AS n_items,
         SUM(vtr)/1e6 * %f                           AS ref_outlay_yr,
         MEDIAN(CASE WHEN unit_ratio BETWEEN 0 AND %f THEN unit_ratio END) AS ratio_real
  FROM g GROUP BY pharma ORDER BY pharma",
  PH_CLASSES, P_MAIN, POST_LO, POST_HI, ANNUALIZE, RATIO_CAP)) |> setDT()

ref_np <- agg[pharma==0, ref_outlay_yr]; ratio_np <- agg[pharma==0, ratio_real]
ref_ph <- agg[pharma==1, ref_outlay_yr]; ratio_ph <- agg[pharma==1, ratio_real]
real_np <- ref_np * ratio_np
real_ph <- ref_ph * ratio_ph
say("outlay REFERENCIA  NP=R$%.0fM (n=%d) | PH=R$%.0fM (n=%d)",
    ref_np, agg[pharma==0,n_items], ref_ph, agg[pharma==1,n_items])
say("ratio realizado/ref NP=%.3f | PH=%.3f", ratio_np, ratio_ph)
say("outlay REALIZADO   NP=R$%.0fM | PH=R$%.0fM", real_np, real_ph)

# 3. perda anual por aderencia (base realizado = maintained) -----------
loss100_real <- loss_np * real_np + loss_ph * real_ph
loss100_ref  <- loss_np * ref_np  + loss_ph * ref_ph
say("--- perda anual = loss x outlay x aderencia ---")
say("100%% aderencia: REALIZADO R$%.0fM (NP %.0f + PH %.0f) | REFERENCIA R$%.0fM",
    loss100_real, loss_np*real_np, loss_ph*real_ph, loss100_ref)
for (a in ADHERENCE)
  say("  %3.0f%%: realizado R$%4.0fM (US$%2.0fM) | referencia R$%4.0fM",
      a*100, loss100_real*a, loss100_real*a/FX, loss100_ref*a)

rng_lo <- round(loss100_real * 0.30); rng_hi <- round(loss100_real * 0.70)
base43 <- round(loss100_real * 0.43)
say("RANGE 30-70%% (realizado): R$%d-%dM (US$%d-%dM) | baseline 43%%: R$%dM",
    rng_lo, rng_hi, round(rng_lo/FX), round(rng_hi/FX), base43)

# 4. emite fragmento de macros (para inspecao / reconciliacao) ---------
f <- function(name, val, cmt="") sprintf(
  "\\providecommand{\\%s}{}\\renewcommand{\\%s}{%s}%s", name, name, val,
  if (nzchar(cmt)) paste0(" % ", cmt) else "")
frag <- c(
  "% AUTO-GERADO por scripts/58_welfare_annual.R - rebuild M2 de primitivas v8.",
  "% ARTEFATO DE AUDITORIA: NAO \\input junto com values.tex (clobbaria os",
  "% literais publicados). values.tex e canonico: paper mantem R$38-89M; este",
  "% rebuild da R$39-91M (igual dentro do arredondamento do ratio realizado).",
  sprintf("%% lambda=%.2f, janela Post m[%d,%d], anualizado 18->12m, FX=%.2f.", LAMBDA, POST_LO, POST_HI, FX),
  f("welfRefOutlayNpYr",     sprintf("%.0f", ref_np),  "SUM(valor_total_ref) G65 NP Post completed, anual"),
  f("welfRefOutlayPharmaYr", sprintf("%.0f", ref_ph),  "idem PH"),
  f("welfRealizedRatioNp",   sprintf("%.2f", ratio_np),"mediana preco_final/preco_ref, NP completed"),
  f("welfRealizedRatioPh",   sprintf("%.2f", ratio_ph),"idem PH"),
  f("welfRealizedOutlayNpYr",sprintf("%.0f", real_np), "= ref x ratio"),
  f("welfRealizedOutlayPhYr",sprintf("%.0f", real_ph), "idem PH"),
  f("welfRangeLoBRL",        sprintf("%d", rng_lo),    "perda anual 30% aderencia (base realizado)"),
  f("welfRangeHiBRL",        sprintf("%d", rng_hi),    "perda anual 70% aderencia"),
  f("welfRangeLoUSD",        sprintf("%d", round(rng_lo/FX)), ""),
  f("welfRangeHiUSD",        sprintf("%d", round(rng_hi/FX)), ""),
  f("welfAnnualBaseline",    sprintf("%d", base43),    "perda anual baseline 43% aderencia"),
  f("welfRefBaseRangeLoBRL", sprintf("%d", round(loss100_ref*0.30)), "sensibilidade base-referencia 30%"),
  f("welfRefBaseRangeHiBRL", sprintf("%d", round(loss100_ref*0.70)), "sensibilidade base-referencia 70%")
)
writeLines(frag, OUT_FRAG)
say("fragmento escrito: %s", OUT_FRAG)
say("[58] done.")
