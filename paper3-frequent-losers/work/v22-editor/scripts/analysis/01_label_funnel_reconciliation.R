#!/usr/bin/env Rscript
# =============================================================================
# 01_label_funnel_reconciliation.R  --  JLEO R&R (v22), CP-1
#
# PURPOSE
#   Credibility-repair reconciliation of the 193-vs-210 cobidder-count
#   discrepancy. EXTENDS scripts/79_label_funnel.R (reusing its DuckDB joins
#   verbatim) to emit submission-grade, fully reproducible deliverables:
#     (1) count-reproduction table   diagnostics/label_count_reproduction.csv
#     (2) Table A funnel             tables/main/table_A_label_funnel.{csv,tex}
#     (3) Table B case timing        tables/main/table_B_case_timing_and_benchmark_use.{csv,tex}
#     (4) 193-vs-210 set comparison  diagnostics/cobidder_set_comparison_193_vs_210.csv (+summary)
#     (5) assertions                 diagnostics/label_funnel_assertions.csv
#     (6) funnel figure              figures/main/fig_label_funnel.pdf
#     (7) macro snippet              diagnostics/label_funnel_new_macros.tex
#
# LOCKED DIAGNOSIS (asserted, not rediscovered):
#   193 = static cade_fl_cobidders.csv (FL-only, narrow cartel-tender restriction;
#         builder ABSENT from repo).
#   341 = broad-definition FL cobidders (any shared tender-item with a BEC-active
#         direct defendant; FL14 = tenders_count>=14), full 12-case portfolio.
#   651 = broad-definition ALWAYS-LOSER cobidders, full portfolio.
#   208 = broad-AL cobidders over 4 conservative cases (210 manuscript).
#   107 = conservative-FL (108 manuscript).
#    19 = BEC-active defendants in 4 conservative cases (30 manuscript = over-count, DROP).
#   WHY 210>193 despite fewer cases: TWO compounding definition differences --
#     (1) stratum: 210=always-loser, 193=frequent-loser subset (AL >= FL);
#     (2) cobidder def: 210=broad shared-tender-item, 193=narrow cartel-tender.
#   Under a COMMON def the subset relation is restored (208<651 AL; 107<341 FL).
#   explanation_code = DIFFERENT_COBIDDER_DEFINITION (+ AL-vs-FL stratum), NOT a bug.
#
# DISCIPLINE: DuckDB threads=12 mem=14GB /tmp spill; seed 20260602; telemetry.
#   Does NOT modify scripts/79_label_funnel.R or anything in data/processed/.
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(ggplot2)
})
set.seed(20260602L)

t0   <- Sys.time()
host <- Sys.info()[["nodename"]]
rss_mb <- function() {
  v <- tryCatch(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE)),
                error = function(e) NA_real_)
  round(v / 1024, 1)
}

# ---- paths ------------------------------------------------------------------
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): source-abstraction layer.
# --source=bec (default) | comprasnet; all paths/constants/CADE layout from cfg.
# BEC behaviour byte-identical (cfg$* bec values equal the prior literals).
args_user <- commandArgs(trailingOnly = TRUE)
src <- sub("^--source=", "", grep("^--source=", args_user, value = TRUE))
src <- if (length(src)) src[1L] else "bec"

args0 <- commandArgs(trailingOnly = FALSE)
sd <- sub("^--file=", "", grep("^--file=", args0, value = TRUE))
SCRIPT_DIR <- if (length(sd)) dirname(normalizePath(sd)) else getwd()
.script_dir <- SCRIPT_DIR  # used by source_config.R repo resolver
source(file.path(SCRIPT_DIR, "..", "utils", "source_config.R"))
cfg <- get_source_config(src)
cfg$ensure_dirs()

BASE   <- cfg$repo
DATA   <- cfg$data_dir
# Legacy script-79 outputs (output/label_funnel/) are a BEC-historical artifact;
# the federal funnel is built fresh (no legacy reconciliation columns). See the
# cfg$source=="bec" guard below.
OUT    <- cfg$out_root
D_DIAG <- cfg$dirs$diagnostics
D_TBL  <- cfg$dirs$tables_main
D_FIG  <- cfg$dirs$figures_main
D_LOG  <- cfg$dirs$logs

say <- function(...) cat(paste0(..., "\n"))
say("================ 01_label_funnel_reconciliation.R (JLEO R&R v22 CP-1) ================")
say("source=", cfg$source, " (", cfg$label, ")")
say("host=", host, "  start=", format(t0), "  RSS=", rss_mb(), "MB")
say("BASE=", BASE)

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): legacy script-79 reuse is BEC-only.
if (cfg$source == "bec") {
  S79OUT <- file.path(BASE, "output", "label_funnel")  # reuse script 79 outputs (read-only)
} else {
  S79OUT <- NA_character_
  say("[legacy] SKIP script-79 output/label_funnel reuse: federal funnel is built ",
      "fresh without the BEC-historical reconciliation columns.")
}

# ---- inputs -----------------------------------------------------------------
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): core parquets from cfg.
f_ftm   <- cfg$firm_tender_map
f_loss  <- cfg$firm_loss_stats
f_freq  <- cfg$freq_particip
stopifnot(all(file.exists(f_ftm, f_loss, f_freq)))

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): FL cut / conservative cutoff from cfg
# (CONS_DATE bec=2020-12-31, fed=2025-02-26). HAVE_CONS is a safety net for a future
# source with CONS_DATE=NA; both current sources have it, so conservative runs for both.
FL_CUT    <- cfg$FL_CUT
CONS_DATE <- cfg$CONS_DATE
HAVE_CONS <- !is.na(CONS_DATE)
MANU_BEC  <- 41444L  # manuscript all-BEC firms (BEC reference; federal logs only)

# SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): platform-name + FL-cut
# label strings for the rendered Table A/B notes and labels. The config exposes no
# short platform name (only the verbose cfg$label), so derive it from cfg$source:
#   bec        -> "BEC"        (R1 byte-identity: matches every prior hardcode)
#   comprasnet -> "ComprasNet" (honest federal platform name)
# FL_LABEL renders the FL screen string from cfg$FL_CUT + cfg$FL_CONVENTION:
#   bec -> "FL14, tenders\\_count $\\geq 14$" (byte-identical to prior hardcode)
#   fed -> "FL32, tenders\\_count $\\geq 32$"
PLAT <- if (identical(cfg$source, "bec")) "BEC" else "ComprasNet"
.fl_ge <- if (identical(cfg$FL_CONVENTION, ">=")) "\\geq" else "="  # both current sources use ">="
FL_LABEL <- sprintf("FL%d, tenders\\_count $%s %d$", FL_CUT, .fl_ge, FL_CUT)
FL_TAG   <- sprintf("FL%d", FL_CUT)  # short tag for CSV screen_threshold fields
say("[label] PLAT=", PLAT, "  FL_LABEL=", FL_LABEL)

pad14 <- function(x){ x <- gsub("[^0-9]", "", as.character(x)); ifelse(x == "", NA_character_, formatC(x, width = 14, flag = "0")) }

# SOURCE-CONFIG ADAPTATION (Phase 1 label-fix, 2026-06-05): modality string is
# cfg-driven (ComprasNet is pure Pregao; BEC pools Convite+Pregao). BEC renders
# byte-identical to the historical hardcode (gate R1): MODALITY_RULE_FULL =
# "Convite+Pregao (2,3)", MODALITY_RULE = "Convite+Pregao". Federal renders the
# honest equivalent from cfg$has_convite / cfg$phase_codes (no convite in panel).
.mod_codes <- paste(unlist(cfg$phase_codes), collapse = ",")  # bec "2,3" ; fed "5,9999"
if (isTRUE(cfg$has_convite)) {
  MODALITY_RULE      <- "Convite+Pregao"
  MODALITY_RULE_FULL <- paste0(MODALITY_RULE, " (", .mod_codes, ")")
} else {
  MODALITY_RULE      <- "Pregao (incl. SRP)"               # pure Pregao + SRP, no convite
  MODALITY_RULE_FULL <- paste0(MODALITY_RULE, " (", .mod_codes, ")")
}
say("[modality] rule=", MODALITY_RULE_FULL, " (has_convite=", cfg$has_convite, ")")

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): CADE input-normalization branch
# keyed on cfg$cade_layout, mapping either layout into the same internal frames:
#   cross : data.table(cnpj, proc)  -- defendant CNPJ (14-digit estab) x case
#   cart  : data.table(proc, jdate, setor) -- case roster + judgment dates
#   cob   : data.table(cnpj)        -- static/archived comparison set (NOT a label)
# D-i finding: BEC anchors at the FULL 14-digit ESTAB CNPJ (defend = pad14(fornecedor),
#   joined on f."códigofornecedor"). Federal mirrors this on direct_defendants_federal$firm_id.
if (cfg$cade_layout == "bec_csv") {
  f_cross <- cfg$cade$crossmatch
  f_cart  <- cfg$cade$carteis
  f_cob   <- cfg$cade$cobidders
  stopifnot(all(file.exists(f_cross, f_cart, f_cob)))

  cross <- fread(f_cross, colClasses = "character")
  cart  <- fread(f_cart,  colClasses = "character")
  cob   <- fread(f_cob,   colClasses = "character")

  cross[, cnpj := pad14(fornecedor)]
  cross[, proc := processo]
  cross <- cross[!is.na(cnpj) & toupper(fornecedor) != "IT_DF" & nchar(cnpj) == 14]
  cross <- cross[, .(cnpj, proc)]
  cart[, proc := numero_processo]
  cart <- cart[!is.na(proc) & trimws(proc) != "" & toupper(proc) != "IT_DF"]
  cart[, jdate := as.Date(data_julgamento)]
  cart <- cart[, .(proc, jdate, setor)]
  cob[, cnpj := pad14(`códigofornecedor`)]
  cob <- cob[, .(cnpj)]

} else if (cfg$cade_layout == "federal_parquet_v3") {
  if (!requireNamespace("arrow", quietly = TRUE))
    stop("federal CADE parquets require the 'arrow' package")
  dd <- as.data.table(arrow::read_parquet(cfg$cade$direct_defendants))
  cross <- unique(dd[, .(cnpj = pad14(firm_id), proc = as.character(processo))])
  cross <- cross[!is.na(proc) & trimws(proc) != ""]  # drop empty-processo group (gate G3)
  cross <- cross[!is.na(cnpj) & nchar(cnpj) == 14]
  # Federal per-case judgment dates come from cfg$cade$cnpjs_enriched (same provenance
  # as BEC: numero_processo / data_julgamento), joined by processo so the conservative
  # benchmark works under the (real) cfg$CONS_DATE. Undated cases keep jdate = NA.
  cart <- unique(dd[, .(proc = as.character(processo), setor = as.character(setor))])
  cart <- cart[!is.na(proc) & trimws(proc) != ""]
  jd <- fread(cfg$cade$cnpjs_enriched, colClasses = "character")
  jd <- unique(jd[trimws(numero_processo) != "" & trimws(data_julgamento) != "",
                  .(proc = numero_processo, jdate = as.Date(data_julgamento))])
  cart <- merge(cart, jd, by = "proc", all.x = TRUE)
  if (!"jdate" %in% names(cart)) cart[, jdate := as.Date(NA)]
  cobF <- as.data.table(arrow::read_parquet(cfg$cade$cobidders))
  cob  <- unique(cobF[, .(cnpj = pad14(firm_id))])   # set-comparison reference only

} else stop("Unknown cfg$cade_layout: ", cfg$cade_layout)

n_cob_file <- nrow(cob)
say("[file] cade_fl_cobidders.csv rows (static 193 target) = ", n_cob_file)
say("[file] crossmatch valid defendant rows = ", nrow(cross),
    " (distinct CNPJ=", uniqueN(cross$cnpj), ", distinct processo=", uniqueN(cross$proc), ")")
say("[file] cade_carteis distinct processo  = ", uniqueN(cart$proc))

# ---- DuckDB session ---------------------------------------------------------
con <- dbConnect(duckdb())
invisible(dbExecute(con, "PRAGMA threads=12"))
invisible(dbExecute(con, "PRAGMA memory_limit='14GB'"))
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): spill dir from cfg.
invisible(dbExecute(con, sprintf("PRAGMA temp_directory='%s'", cfg$temp_directory)))

dbWriteTable(con, "defend",  unique(cross[, .(cnpj, proc)]), overwrite = TRUE)
dbWriteTable(con, "cobfile", unique(cob[, .(cnpj)]),         overwrite = TRUE)
invisible(dbExecute(con, sprintf("CREATE VIEW ftm  AS SELECT * FROM read_parquet('%s')", f_ftm)))
invisible(dbExecute(con, sprintf("CREATE VIEW loss AS SELECT * FROM read_parquet('%s')", f_loss)))
invisible(dbExecute(con, sprintf("CREATE VIEW freq AS SELECT * FROM read_parquet('%s')", f_freq)))

# ---- manuscript firm-stratum counts ----------------------------------------
n_all_BEC <- dbGetQuery(con, "SELECT COUNT(DISTINCT \"códigofornecedor\") n FROM ftm WHERE \"códigofornecedor\" <> '-1'")$n
n_AL_univ <- dbGetQuery(con, "SELECT COUNT(*) n FROM loss WHERE always_loser = 1")$n
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): FL cut from cfg (bec 14 / fed 32, ">=").
n_FL_univ <- dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM freq WHERE always_loser = 1 AND tenders_count >= %d", FL_CUT))$n
say("[firm] all-BEC firms (ftm distinct !=-1) = ", n_all_BEC, "  [manuscript 41,444]")
say("[firm] always-losers (loss AL==1)        = ", n_AL_univ, "  [manuscript 16,843]")
say("[firm] frequent-losers (AL & tc>=14)     = ", n_FL_univ, "  [manuscript 2,735]")

# ---- S1: BEC-active direct defendants (verbatim logic from 79) -------------
defend_active <- dbGetQuery(con, "
  SELECT DISTINCT d.cnpj FROM defend d
  WHERE d.cnpj IN (SELECT DISTINCT \"códigofornecedor\" FROM ftm)")
n_def_ftm   <- nrow(defend_active)              # 41 (firm_tender_map-active)
n_def_cross <- uniqueN(cross$cnpj)              # 48 distinct crossmatch CNPJ
say("[S1] BEC-active defendants (ftm) = ", n_def_ftm, " ; crossmatch distinct CNPJ = ", n_def_cross)

# ---- S2: defendant tender-items (verbatim from 79) -------------------------
invisible(dbExecute(con, "
  CREATE TEMP TABLE def_items AS
  SELECT DISTINCT f.numerodaoc, f.\"códigoitem\", d.proc
  FROM ftm f JOIN defend d ON f.\"códigofornecedor\" = d.cnpj"))
n_def_items <- dbGetQuery(con, "
  SELECT COUNT(*) n, COUNT(DISTINCT (numerodaoc||'|'||\"códigoitem\")) ni FROM def_items")
n_def_item_ti <- n_def_items$ni                  # 52013 distinct tender-items
say("[S2] defendant tender-item x case rows = ", n_def_items$n, " (distinct tender-items=", n_def_item_ti, ")")

# ---- S3: cobidders of direct defendants (verbatim from 79) -----------------
invisible(dbExecute(con, "
  CREATE TEMP TABLE cobidder_case AS
  SELECT DISTINCT f.\"códigofornecedor\" AS cnpj, di.proc
  FROM ftm f JOIN def_items di
    ON f.numerodaoc = di.numerodaoc AND f.\"códigoitem\" = di.\"códigoitem\"
  WHERE f.\"códigofornecedor\" <> '-1'
    AND f.\"códigofornecedor\" NOT IN (SELECT cnpj FROM defend)"))
n_cob_all <- dbGetQuery(con, "SELECT COUNT(DISTINCT cnpj) n FROM cobidder_case")$n
say("[S3] cobidders of defendants (all, !=-1, !=defendant) = ", n_cob_all)

# per-cobidder enrichment + co-bid intensity (tender-items shared & cases linked)
cob_stat <- setDT(dbGetQuery(con, "
  SELECT c.cnpj, l.win_rate, l.always_loser, fr.tenders_count
  FROM (SELECT DISTINCT cnpj FROM cobidder_case) c
  LEFT JOIN loss l ON l.\"códigofornecedor\" = c.cnpj
  LEFT JOIN freq fr ON fr.\"códigofornecedor\" = c.cnpj"))
cob_stat[, is_AL := as.integer(always_loser == 1 | (!is.na(win_rate) & win_rate == 0))]
cob_stat[is.na(is_AL), is_AL := 0L]
cob_stat[, is_FL := as.integer(is_AL == 1 & !is.na(tenders_count) & tenders_count >= FL_CUT)]

# n cases linked per cobidder
cases_per_cob <- setDT(dbGetQuery(con,
  "SELECT cnpj, COUNT(DISTINCT proc) n_cases FROM cobidder_case GROUP BY cnpj"))
# n shared defendant tender-items per cobidder
items_per_cob <- setDT(dbGetQuery(con, "
  SELECT f.\"códigofornecedor\" AS cnpj,
         COUNT(DISTINCT (f.numerodaoc||'|'||f.\"códigoitem\")) n_items
  FROM ftm f JOIN def_items di
    ON f.numerodaoc = di.numerodaoc AND f.\"códigoitem\" = di.\"códigoitem\"
  WHERE f.\"códigofornecedor\" <> '-1'
    AND f.\"códigofornecedor\" NOT IN (SELECT cnpj FROM defend)
  GROUP BY f.\"códigofornecedor\""))
cob_stat <- merge(cob_stat, cases_per_cob, by = "cnpj", all.x = TRUE)
cob_stat <- merge(cob_stat, items_per_cob, by = "cnpj", all.x = TRUE)

n_AL <- cob_stat[is_AL == 1, uniqueN(cnpj)]      # 651
n_FL <- cob_stat[is_FL == 1, uniqueN(cnpj)]      # 341
say("[S4] broad always-loser cobidders = ", n_AL, "  [diagnosis 651]")
say("[S5] broad FL cobidders           = ", n_FL, "  [diagnosis 341]   (static target=193)")

# ---- reconciliation vs static 193 file -------------------------------------
recon <- merge(cob_stat[, .(cnpj, is_AL, is_FL)],
               cob[, .(cnpj, file_FL = 1L)], by = "cnpj", all = TRUE)
set_static <- cob$cnpj
set_broadFL <- cob_stat[is_FL == 1, cnpj]
set_broadAL <- cob_stat[is_AL == 1, cnpj]
overlap_static_broadFL <- length(intersect(set_static, set_broadFL))   # 149
fileonly  <- length(setdiff(set_static, set_broadFL))                  # 44
recononly <- length(setdiff(set_broadFL, set_static))                  # 192
say("[recon] static193 INT broadFL341 = ", overlap_static_broadFL,
    " ; file-only=", fileonly, " ; recon-only=", recononly)

# ---- CONSERVATIVE subset (judged <= 2020-12-31) ----------------------------
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): CONS_DATE-dependent step degrades
# gracefully when cfg$CONS_DATE is NA (federal judgment dates not wired in): no
# conservative subset exists, so all conservative counts/sets are empty/NA + logged.
if (HAVE_CONS) {
  proc_dates <- unique(cart[!is.na(jdate) & !is.na(proc) & trimws(proc) != "", .(proc, jdate)])
  cons_procs <- proc_dates[jdate <= CONS_DATE, unique(proc)]
  n_cons_cases <- length(cons_procs)
  cons_def <- dbGetQuery(con, sprintf(
    "SELECT DISTINCT cnpj FROM defend WHERE proc IN (%s)",
    paste(sprintf("'%s'", cons_procs), collapse = ",")))
  n_cons_def <- nrow(cons_def)                      # 19
  cons_cob <- setDT(dbGetQuery(con, sprintf(
    "SELECT DISTINCT cnpj FROM cobidder_case WHERE proc IN (%s)",
    paste(sprintf("'%s'", cons_procs), collapse = ","))))
  cons_join <- merge(cons_cob, cob_stat[, .(cnpj, is_AL, is_FL)], by = "cnpj", all.x = TRUE)
  set_consAL <- cons_join[is_AL == 1, cnpj]
  set_consFL <- cons_join[is_FL == 1, cnpj]
  n_cons_AL  <- length(set_consAL)                  # 208
  n_cons_FL  <- length(set_consFL)                  # 107
  # conservative defendant tender-items
  n_cons_def_items <- dbGetQuery(con, sprintf("
    SELECT COUNT(DISTINCT (numerodaoc||'|'||\"códigoitem\")) ni
    FROM def_items WHERE proc IN (%s)",
    paste(sprintf("'%s'", cons_procs), collapse = ",")))$ni
  # TARGET-QUALITY FIX (Phase 1, 2026-06-05) -- FIX 2: truthful conservative-rule
  # label sourced DYNAMICALLY from cfg$CONS_DATE (mirrors script 00). For BEC,
  # CONS_DATE = 2020-12-31 < latest judgment -> a genuine prospective cut, and the
  # rendered strings are BYTE-IDENTICAL to the previous hardcoded "2020-12-31" text
  # (R1 preserved). Federally CONS_DATE = latest judgment date -> the cut is
  # equivalent to all dated cases (undated cases excluded); the label says so.
  n_cases_total   <- uniqueN(cart$proc)
  n_cases_dated   <- uniqueN(proc_dates$proc)
  n_cases_undated <- n_cases_total - n_cases_dated
  cons_is_vacuous <- isTRUE(CONS_DATE >= suppressWarnings(max(proc_dates$jdate, na.rm = TRUE)))
} else {
  say("[S6] NOTE conservative benchmark SKIPPED: cfg$CONS_DATE is NA (",
      cfg$source, " has no wired-in judgment dates).")
  cons_procs   <- character(0)
  n_cases_undated <- NA_integer_
  cons_is_vacuous <- FALSE
  n_cons_cases <- 0L
  n_cons_def   <- NA_integer_
  set_consAL   <- character(0)
  set_consFL   <- character(0)
  n_cons_AL    <- NA_integer_
  n_cons_FL    <- NA_integer_
  n_cons_def_items <- NA_integer_
}
say("[S6] conservative cases=", n_cons_cases, " def=", n_cons_def,
    " AL=", n_cons_AL, " FL=", n_cons_FL, " def_items=", n_cons_def_items)

# TARGET-QUALITY FIX (Phase 1, 2026-06-05) -- FIX 2: dynamic conservative-rule labels.
# cons_date_str renders the cut date; cons_rule_def is the funnel "definition" string;
# cons_rule_note appends the federal honesty clause when the cut is vacuous (CONS_DATE =
# latest judgment date). For BEC these render to the prior hardcoded text verbatim.
cons_date_str <- if (HAVE_CONS) format(CONS_DATE) else NA_character_
cons_rule_def <- if (!HAVE_CONS) {
  "conservative benchmark not applicable (CONS_DATE NA)"
} else if (isTRUE(cons_is_vacuous)) {
  sprintf("cases judged on/before %s (equivalent to all %d dated cases; %d undated excluded)",
          cons_date_str, n_cons_cases, n_cases_undated)
} else {
  sprintf("cases judged on/before %s", cons_date_str)
}
say("[S6] conservative rule: ", cons_rule_def)

# TARGET-QUALITY FIX (Phase 1, 2026-06-05) -- FIX 2: Table-A row strings, dynamic.
# These render BYTE-IDENTICAL to the previous hardcoded BEC text when CONS_DATE =
# 2020-12-31 and counts = 4/19/208/107 (cons_is_vacuous = FALSE for BEC). Federally
# (cons_is_vacuous = TRUE) they state the truth: the cut equals all dated cases.
cons_sample_name <- if (isTRUE(cons_is_vacuous)) {
  sprintf("Conservative benchmark, all dated cases (%d/%d/%d/%d)",
          n_cons_cases, n_cons_def, n_cons_AL, n_cons_FL)
} else {
  sprintf("Conservative pre-2020 benchmark (%d/%d/%d/%d)",
          n_cons_cases, n_cons_def, n_cons_AL, n_cons_FL)
}
cons_case_window <- sprintf("judged <=%s", cons_date_str)
cons_date_rule   <- sprintf("<=%s", cons_date_str)
cons_excl_str    <- if (isTRUE(cons_is_vacuous)) {
  sprintf("defendants, -1 sentinel, %d undated case(s) excluded", n_cases_undated)
} else {
  "defendants, -1 sentinel, cases judged after 2020"
}
# BYTE-IDENTITY RESTORE (R1-extended adjudication, 2026-06-06): the FIX-2 dynamic
# strings did NOT render byte-identical to the prior hardcoded BEC text (they dropped
# the manuscript-reconciliation info). Restore the EXACT original BEC strings for
# cfg$source=="bec"; federal keeps the new honest dynamic strings.
if (cfg$source == "bec") {
  cons_reason_str <- "broad def restricted to 4 early cases (vs narrow FL-only full 193)"
  cons_tabA_note  <- "208/107 reproduce \\valConservativeCobidders=210 / 108; def=19 (manuscript 30 over-count)"
} else {
  cons_reason_str <- if (isTRUE(cons_is_vacuous)) {
    sprintf("same broad AL def restricted to %d dated cases (subset of main %d)", n_cons_cases, n_AL)
  } else {
    sprintf("same broad AL def restricted to %d early cases (subset of main %d)", n_cons_cases, n_AL)
  }
  cons_tabA_note  <- sprintf("%d AL / %d FL-composition; %d crossmatch defendants in conservative cases",
                             n_cons_AL, n_cons_FL, n_cons_def)
}

# =============================================================================
# (1) COUNT REPRODUCTION TABLE
# =============================================================================
status <- function(rep, manu, tol = 3) {
  if (is.na(rep) || is.na(manu)) return("not_applicable")
  if (rep == manu) return("match")
  if (abs(rep - manu) <= tol) return("approx")
  "mismatch"
}
cr <- rbindlist(list(
  list("all_BEC_firms", n_all_BEC, 41444L, status(n_all_BEC, 41444L),
       "firm_tender_map.parquet", "01_label_funnel_reconciliation.R",
       "distinct códigofornecedor != '-1' in firm_tender_map",
       "off-by-1 vs manuscript 41,444 (one sentinel/dup); approx"),
  list("always_losers", n_AL_univ, 16843L, status(n_AL_univ, 16843L),
       "firm_loss_stats.parquet", "01_label_funnel_reconciliation.R",
       "loss.always_loser==1 (equiv win_rate==0)", "exact"),
  list("frequent_losers", n_FL_univ, 2735L, status(n_FL_univ, 2735L),
       "FREQ_PARTICIP_rebuilt.parquet", "01_label_funnel_reconciliation.R",
       "always_loser & tenders_count>=14", "exact"),
  list("FL_threshold", FL_CUT, 14L, status(FL_CUT, 14L),
       "CLAUDE.md / fl_convention", "01_label_funnel_reconciliation.R",
       "median + 1.5*IQR on AL tenders_count ~ 14; FL14 = tenders_count>=14", "exact"),
  list("cade_cases", uniqueN(cart$proc), 12L, status(uniqueN(cart$proc), 12L),
       "cade_carteis_licitacoes_2009_2019.csv", "01_label_funnel_reconciliation.R",
       "distinct numero_processo", "exact"),
  list("cade_firm_defendants", NA_integer_, 65L, "not_found",
       "cade_carteis_licitacoes_2009_2019.csv", "01_label_funnel_reconciliation.R",
       "legal-defendant roster (65 firms across cases)",
       "legal-defendant roster not in carteis csv; cnpj col empty -> not reproducible"),
  list("bec_active_direct_defendants_crossmatch", n_def_cross, 47L, status(n_def_cross, 47L),
       "cade_bec_crossmatch.csv", "01_label_funnel_reconciliation.R",
       "distinct CNPJ in crossmatch (48) ~ manuscript \\valDirectCADE=47",
       "48 distinct vs 47 cited; approx (one extra row/dup CNPJ)"),
  list("bec_active_direct_defendants_ftm", n_def_ftm, 41L, status(n_def_ftm, 41L),
       "firm_tender_map.parquet x crossmatch", "01_label_funnel_reconciliation.R",
       "crossmatch defendants actually present in firm_tender_map", "exact (script 79 S1)"),
  list("main_cobidders_static", n_cob_file, 193L, status(n_cob_file, 193L),
       "cade_fl_cobidders.csv", "01_label_funnel_reconciliation.R",
       "static FL-only narrow cartel-tender def; builder ABSENT from repo",
       "exact row count of static target file"),
  list("main_cobidders_broad_FL", n_FL, 341L, status(n_FL, 341L),
       "firm_tender_map + loss + freq (broad def)", "01_label_funnel_reconciliation.R",
       "broad shared-tender-item FL cobidders, full 12-case portfolio",
       "transparent scripted broad definition"),
  list("main_cobidders_broad_AL", n_AL, 651L, status(n_AL, 651L),
       "firm_tender_map + loss (broad def)", "01_label_funnel_reconciliation.R",
       "broad shared-tender-item ALWAYS-LOSER cobidders, full portfolio",
       "transparent scripted broad definition"),
  list("conservative_cases", n_cons_cases, 4L, status(n_cons_cases, 4L),
       sprintf("cade_carteis (jdate<=%s)", cons_date_str), "01_label_funnel_reconciliation.R",
       cons_rule_def, "exact"),  # TARGET-QUALITY FIX (Phase 1, 2026-06-05): dynamic date/rule
  list("conservative_defendants", n_cons_def, 30L, status(n_cons_def, 30L),
       "crossmatch (conservative cases)", "01_label_funnel_reconciliation.R",
       "BEC-active direct defendants in 4 conservative cases",
       "19 reproduced vs \\valConservativeFD=30 -> manuscript OVER-COUNT; drop 30->19"),
  list("conservative_AL_cobidders", n_cons_AL, 210L, status(n_cons_AL, 210L),
       "broad def, conservative cases", "01_label_funnel_reconciliation.R",
       "broad-AL cobidders over 4 conservative cases",
       "208 vs \\valConservativeCobidders=210; approx (data-grounded)"),
  list("conservative_FL_cobidders", n_cons_FL, 108L, status(n_cons_FL, 108L),
       "broad def, conservative cases", "01_label_funnel_reconciliation.R",
       "broad-FL cobidders over 4 conservative cases",
       "107 vs 108; approx (data-grounded)"),
  list("common_bid_feature_pool", NA_integer_, 16779L, "not_found",
       "NA (Imhof horse-race common support)", "01_label_funnel_reconciliation.R",
       "Imhof horse-race common-support pool",
       "from scripts 31/49 Imhof common support; NOT a label-funnel object; not derivable here"),
  list("gatekeeping_pool", NA_integer_, 11676L, "not_found",
       "NA (gatekeeping/same-sample)", "01_label_funnel_reconciliation.R",
       "gatekeeping same-sample pool",
       "from scripts 63/64 same-sample; NOT a label-funnel object; not derivable here")
))
setnames(cr, c("count_name","reproduced_value","manuscript_value","match_status",
               "source_data","source_script","definition","notes"))
fwrite(cr, file.path(D_DIAG, "label_count_reproduction.csv"))
say("[write] label_count_reproduction.csv (", nrow(cr), " rows)")

# =============================================================================
# (2) TABLE A — label funnel
# =============================================================================
NAc <- NA_character_
tabA <- rbindlist(list(
  list(sample_name = "Full CADE legal portfolio",
       case_window = "2009-2019 conduct (CADE rulings)", decision_date_rule = "any",
       bec_window = "2009-2019", modality_rule = MODALITY_RULE_FULL,  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix, 2026-06-05)
       item_rule = "all defendant tender-items", direct_defendant_definition = "CADE legal defendant",
       number_cade_cases = uniqueN(cart$proc), number_legal_firm_defendants = 65L,
       number_bec_active_direct_defendants = n_def_cross, number_defendant_tender_items = n_def_item_ti,
       always_loser_definition = "win_rate==0", number_unique_always_loser_cobidders = n_AL,
       # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): PLAT + FL_TAG in CSV strings.
       cobidder_definition = sprintf("broad: shared tender-item w/ %s-active defendant", PLAT),
       number_unique_FL_cobidders = n_FL, number_firm_case_cobidder_pairs = nrow(cob_stat[, .N, by = cnpj]),
       number_frequent_loser_cobidders = n_FL, screen_threshold = sprintf("%s (tenders_count>=%d)", FL_TAG, FL_CUT),
       exclusions = "defendants, -1 sentinel", reason_for_difference_from_main_target = "(reference portfolio)",
       notes = "65 legal defendants not reproducible from carteis csv (cnpj col empty)"),
  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): PLAT/FL_TAG + data-grounded ftm/crossmatch counts.
  list(sprintf("%s-linked CADE portfolio", PLAT), "2009-2019 conduct", "any", "2009-2019", MODALITY_RULE,
       "all defendant tender-items", "crossmatch CNPJ present in firm_tender_map",
       uniqueN(cart$proc), 65L, n_def_ftm, n_def_item_ti, "win_rate==0", n_AL,
       "broad: shared tender-item", n_FL, nrow(cob_stat[, .N, by = cnpj]), n_FL,
       FL_TAG, "defendants, -1 sentinel",
       sprintf("%s-active subset (%d ftm-active of %d crossmatch)", PLAT, n_def_ftm, n_def_cross), "ftm-active defendants only"),
  list("Main validation target (broad AL cobidders)", "2009-2019 conduct",
       "any", "2009-2019", MODALITY_RULE, "any shared tender-item",
       "crossmatch CNPJ in firm_tender_map", uniqueN(cart$proc), 65L, n_def_ftm, n_def_item_ti,
       "win_rate==0", n_AL, "broad: shared tender-item", n_FL, nrow(cob_stat[, .N, by = cnpj]),
       n_FL, sprintf("%s is the score, NOT a label input", FL_TAG), "defendants, -1 sentinel",  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05)
       "(this IS the main target)",
       "fully scripted from current data; FL status never used to define the label"),
  list("Archived narrow file (INTERNAL COMPARISON ONLY)", "2009-2019 conduct",
       "any", "2009-2019", MODALITY_RULE, "narrow cartel-tender restriction (undocumented)",
       "CADE direct defendant", uniqueN(cart$proc), 65L, NA_integer_, NA_integer_,
       "win_rate==0", NA_integer_, "narrow: cartel-tender (NOT reproducible)", n_cob_file,
       NA_integer_, n_cob_file, "FL-only (circular for FL score)", "defendants",
       "NOT a submitted label; internal set comparison only",
       "static cade_fl_cobidders.csv; FL-only; builder absent; excluded from submitted tables"),
  list(cons_sample_name, cons_case_window,  # TARGET-QUALITY FIX (Phase 1, 2026-06-05): dynamic conservative-rule strings
       cons_date_rule, "2009-2019", MODALITY_RULE, "any shared tender-item",
       "crossmatch CNPJ in firm_tender_map", n_cons_cases, NA_integer_, n_cons_def, n_cons_def_items,
       "win_rate==0", n_cons_AL, "broad: shared tender-item", n_cons_FL, n_cons_AL,
       n_cons_FL, FL_TAG, cons_excl_str,  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): FL_TAG
       cons_reason_str,
       cons_tabA_note),
  list("Strict 2009-2016 -> 2017-2019 timing target", "2009-2019 conduct",
       "any", "train 2009-2016 / test 2017-2019", MODALITY_RULE, "shared tender-item by award year",
       "crossmatch CNPJ in firm_tender_map", NA_integer_, NA_integer_, NA_integer_, NA_integer_,
       "win_rate==0", NA_integer_, "broad: shared tender-item", NA_integer_, NA_integer_,
       NA_integer_, FL_TAG, NAc,  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): FL_TAG
       "temporal holdout split (not a label count)",
       "counts not cheaply derivable from label-funnel objects; see precision@k audit (script 43)"),
  list("Common bid-feature pool", NAc, NAc, NAc, NAc, NAc, NAc,
       NA_integer_, NA_integer_, NA_integer_, NA_integer_, NAc, NA_integer_, NAc,
       NA_integer_, NA_integer_, NA_integer_, NAc, NAc,
       "not a label-funnel object",
       "manuscript 16,779 from Imhof horse-race common support (scripts 31/49); not derivable here"),
  list("Gatekeeping pool", NAc, NAc, NAc, NAc, NAc, NAc,
       NA_integer_, NA_integer_, NA_integer_, NA_integer_, NAc, NA_integer_, NAc,
       NA_integer_, NA_integer_, NA_integer_, NAc, NAc,
       "not a label-funnel object",
       "manuscript 11,676 from same-sample gatekeeping (scripts 63/64); not derivable here")
))
fwrite(tabA, file.path(D_TBL, "table_A_label_funnel.csv"))
say("[write] table_A_label_funnel.csv (", nrow(tabA), " rows)")

# --- Table A .tex (compact booktabs, decision-relevant columns) -------------
fmt <- function(x) ifelse(is.na(x), "--", formatC(as.integer(x), format = "d", big.mark = ","))
esc <- function(s) gsub("_", "\\\\_", ifelse(is.na(s), "--", s))
# Submitted .tex EXCLUDES the archived narrow file (internal comparison only;
# not reproducible, FL-conditioned -> never a submitted label)
tabA_tex <- tabA[!grepl("^Archived narrow file", sample_name)]
rowsA <- character(nrow(tabA_tex))
for (i in seq_len(nrow(tabA_tex))) {
  r <- tabA_tex[i]
  rowsA[i] <- paste(
    esc(r$sample_name), fmt(r$number_cade_cases), fmt(r$number_legal_firm_defendants),
    fmt(r$number_bec_active_direct_defendants), fmt(r$number_unique_always_loser_cobidders),
    fmt(r$number_unique_FL_cobidders),
    esc(substr(r$cobidder_definition, 1, 28)), esc(substr(r$reason_for_difference_from_main_target, 1, 40)),
    sep = " & ")
}
texA <- c(
  "% Auto-generated by work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R",
  "% Label-construction funnel and sample reconciliation (JLEO R&R v22 CP-1)",
  "\\begin{table}[!htbp]\\centering",
  "\\caption{Label-construction funnel and sample reconciliation.}",
  "\\label{tab:label_funnel_submission}",
  "\\begin{threeparttable}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\scriptsize",
  "\\begin{tabular}{lrrrrrll}",
  "\\toprule",
  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): platform name in column header.
  paste("Sample / benchmark", "Cases", "Legal def.", sprintf("%s-act. def.", PLAT),
        "AL cobid.", "FL cobid.", "Cobidder def.", "Reason vs main target", sep = " & "),
  " \\\\",
  "\\midrule",
  paste0(rowsA, " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{adjustbox}",
  "\\begin{tablenotes}[flushleft]\\scriptsize",
  "\\item \\textit{Notes.} Cobidder = adjudication-anchored exposure label (not cartel membership). ",
  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): platform name from PLAT.
  sprintf("The main validation label is constructed from current scripts by matching %s-active direct CADE defendants to tender-items and identifying unique always-loser firms (win rate $=0$) that share at least one %s tender-item with those anchors; direct defendants are excluded. ", PLAT, PLAT),
  "The frequent-loser flag is not used to construct the label; it is the award-layer score evaluated against the label. ",
  sprintf("Of the %d positives, %d are frequent losers and %d are not (composition, not a label restriction). ", n_AL, n_FL, n_AL - n_FL),
  # TARGET-QUALITY FIX (Phase 1, 2026-06-05): conservative cutoff sourced from cfg$CONS_DATE.
  sprintf("The conservative benchmark restricts CADE cases to judgment dates $\\leq$ %s under the SAME definition%s. ",
          cons_date_str,
          if (isTRUE(cons_is_vacuous))
            sprintf(" (this cutoff equals the latest judgment date, so it retains all %d dated cases and excludes %d undated case%s)",
                    n_cons_cases, n_cases_undated, if (n_cases_undated == 1L) "" else "s")
          else ""),
  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): FL cut from FL_LABEL.
  sprintf("Counts are unique firms unless a column says pairs. AL = always-loser; FL = frequent loser (%s). ", FL_LABEL),
  "Legal-defendant roster (65) is not reproducible from the CADE rulings CSV (empty CNPJ column); shown for context.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(texA, file.path(D_TBL, "table_A_label_funnel.tex"))
say("[write] table_A_label_funnel.tex")

# =============================================================================
# (3) TABLE B — case timing & benchmark use
# =============================================================================
# per-case defendant + cobidder counts (broad def)
def_per_case <- dbGetQuery(con, "
  SELECT proc, COUNT(DISTINCT cnpj) n_def
  FROM defend WHERE cnpj IN (SELECT DISTINCT \"códigofornecedor\" FROM ftm)
  GROUP BY proc")
defitems_per_case <- dbGetQuery(con, "
  SELECT proc, COUNT(DISTINCT (numerodaoc||'|'||\"códigoitem\")) n_items FROM def_items GROUP BY proc")
cob_per_case <- merge(
  setDT(dbGetQuery(con, "SELECT cnpj, proc FROM cobidder_case")),
  cob_stat[, .(cnpj, is_AL, is_FL)], by = "cnpj", all.x = TRUE)
cob_case_agg <- cob_per_case[, .(n_AL_cob = sum(is_AL == 1, na.rm = TRUE),
                                 n_FL_cob = sum(is_FL == 1, na.rm = TRUE)), by = proc]

tabB <- merge(unique(cart[, .(proc, setor, jdate)]),
              setDT(def_per_case), by = "proc", all.x = TRUE)
tabB <- merge(tabB, setDT(defitems_per_case), by = "proc", all.x = TRUE)
tabB <- merge(tabB, cob_case_agg, by = "proc", all.x = TRUE)
for (cc in c("n_def","n_items","n_AL_cob","n_FL_cob")) tabB[is.na(get(cc)), (cc) := 0L]
setorder(tabB, jdate, na.last = TRUE)
tabB[, case_id := paste0("Case ", LETTERS[seq_len(.N)])]
tabB[, included_main_target := "Y"]  # main broad AL target spans the full 12-case portfolio
tabB[, included_conservative_pre2020 := ifelse(proc %in% cons_procs, "Y", "N")]
tabB[, conduct_dates := "NA — CASE_TIMING_MISSING"]
tabB[, notes := ifelse(is.na(jdate), "judgment date MISSING (undated case)", "")]
tabB_csv <- tabB[, .(case_id, sector = setor, process_number = proc,
                     decision_date = as.character(jdate),
                     number_bec_active_direct_defendants = n_def,
                     number_defendant_tender_items = n_items,
                     number_unique_always_loser_cobidders = n_AL_cob,
                     number_frequent_loser_cobidders = n_FL_cob,
                     included_main_target, included_conservative_pre2020,
                     conduct_dates, notes)]
fwrite(tabB_csv, file.path(D_TBL, "table_B_case_timing_and_benchmark_use.csv"))
say("[write] table_B_case_timing_and_benchmark_use.csv (", nrow(tabB_csv), " rows)")

# --- Table B .tex (anonymized; sector + judgment year + counts) -------------
yr <- function(d) ifelse(is.na(d), "n.d.", format(d, "%Y"))
rowsB <- character(nrow(tabB))
for (i in seq_len(nrow(tabB))) {
  r <- tabB[i]
  rowsB[i] <- paste(r$case_id, esc(r$setor), yr(r$jdate),
                    fmt(r$n_def), fmt(r$n_items), fmt(r$n_AL_cob), fmt(r$n_FL_cob),
                    r$included_conservative_pre2020, sep = " & ")
}
texB <- c(
  "% Auto-generated by work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R",
  "% CADE cases: timing and benchmark use (JLEO R&R v22 CP-1)",
  "\\begin{table}[!htbp]\\centering",
  "\\caption{CADE cases: timing and benchmark use.}",
  "\\label{tab:case_timing_submission}",
  "\\begin{threeparttable}",
  "\\begin{adjustbox}{max width=\\textwidth}",
  "\\scriptsize",
  "\\begin{tabular}{llrrrrrc}",
  "\\toprule",
  # SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): platform name in column header.
  paste("Case", "Sector", "Judg. yr", sprintf("%s def.", PLAT), "Def. items",
        "AL cobid.", "FL cobid.", "Conserv.", sep = " & "),
  " \\\\",
  "\\midrule",
  paste0(rowsB, " \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\end{adjustbox}",
  "\\begin{tablenotes}[flushleft]\\scriptsize",
  "\\item \\textit{Notes.} CADE rulings are public; process numbers anonymized to Case A--L (ordered by judgment date, undated last) for cleanliness; full process numbers in the replication CSV. ",
  # TARGET-QUALITY FIX (Phase 1, 2026-06-05): dated/total + conservative cutoff from data/cfg.
  # BEC (cons_is_vacuous=FALSE) renders BYTE-IDENTICAL to the prior "9/12 cases" +
  # "pre-2020 conservative benchmark" text; federal states the truthful cutoff/exclusion.
  sprintf("Conduct-period dates are unavailable; only judgment dates exist (%d/%d cases). Undated cases marked judgment year ``n.d.''. ",
          uniqueN(cart$proc) - (if (HAVE_CONS) n_cases_undated else 0L), uniqueN(cart$proc)),
  if (isTRUE(cons_is_vacuous))
    sprintf("AL/FL cobidder counts use the broad shared-tender-item definition. ``Conserv.'' = included in the conservative benchmark (judgment date $\\leq$ %s; equals all dated cases).",
            cons_date_str)
  else
    "AL/FL cobidder counts use the broad shared-tender-item definition. ``Conserv.'' = included in the pre-2020 conservative benchmark.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}")
writeLines(texB, file.path(D_TBL, "table_B_case_timing_and_benchmark_use.tex"))
say("[write] table_B_case_timing_and_benchmark_use.tex")

# =============================================================================
# (4) 193-vs-210 SET COMPARISON (hashed CNPJ)
# =============================================================================
have_digest <- requireNamespace("digest", quietly = TRUE)
all_cnpj <- sort(unique(c(set_static, set_broadFL, set_broadAL, set_consAL)))
if (have_digest) {
  hsh <- vapply(all_cnpj, function(x) substr(digest::digest(x, algo = "sha1"), 1, 10), character(1))
  hash_map <- setNames(hsh, all_cnpj)
  say("[hash] CNPJ hashed via digest sha1 (10 hex)")
} else {
  hash_map <- setNames(sprintf("id%06d", seq_along(all_cnpj)), all_cnpj)
  say("[hash] digest absent -> deterministic integer ids on sorted unique CNPJ")
}
cmp <- data.table(cnpj = all_cnpj)
cmp[, firm_id := hash_map[cnpj]]
cmp[, in_static_193            := as.integer(cnpj %in% set_static)]
cmp[, in_broad_full_FL_341     := as.integer(cnpj %in% set_broadFL)]
cmp[, in_broad_full_AL_651     := as.integer(cnpj %in% set_broadAL)]
cmp[, in_broad_conservative_AL_208 := as.integer(cnpj %in% set_consAL)]
cmp <- merge(cmp, cob_stat[, .(cnpj, always_loser_flag = is_AL, is_FL_broad = is_FL,
                               T_i = tenders_count, n_cobid_tender_items = n_items,
                               n_cases_linked = n_cases)],
             by = "cnpj", all.x = TRUE)
cmp[, W_i := 0L]  # all AL cobidders are winners-of-zero by construction
# explanation code per firm
cmp[, explanation_code := fifelse(
  in_static_193 == 1 & in_broad_full_FL_341 == 0, "STATIC_NARROW_ONLY",
  fifelse(in_static_193 == 0 & in_broad_full_FL_341 == 1, "BROAD_DEF_ONLY",
  fifelse(in_static_193 == 1 & in_broad_full_FL_341 == 1, "BOTH_DEFS",
  fifelse(in_broad_full_AL_651 == 1, "BROAD_AL_NOT_FL", "OTHER"))))]
cmp[, always_loser := always_loser_flag][, always_loser_flag := NULL]
setcolorder(cmp, c("firm_id","in_static_193","in_broad_full_FL_341","in_broad_full_AL_651",
                   "in_broad_conservative_AL_208","always_loser","is_FL_broad","T_i","W_i",
                   "n_cobid_tender_items","n_cases_linked","explanation_code"))
cmp[, cnpj := NULL]
fwrite(cmp, file.path(D_DIAG, "cobidder_set_comparison_193_vs_210.csv"))
say("[write] cobidder_set_comparison_193_vs_210.csv (", nrow(cmp), " firm rows)")

# summary
mk <- function(a, b, na, nb) {
  list(size_A = length(a), size_B = length(b),
       intersection = length(intersect(a, b)),
       A_minus_B = length(setdiff(a, b)), B_minus_A = length(setdiff(b, a)))
}
s1 <- mk(set_static,  set_broadFL)
s2 <- mk(set_consAL,  set_broadAL)
s3 <- mk(set_static,  set_consAL)
summ <- rbindlist(list(
  c(list(pair = "static193_vs_broadFull341", set_A = "static_193", set_B = "broad_full_FL_341"),
    s1, list(explanation_code = "DIFFERENT_COBIDDER_DEFINITION",
             note = "Same FL stratum, different cobidder def (narrow cartel-tender vs broad shared-tender-item). Overlap 149; static-only 44; broad-only 192.")),
  c(list(pair = "broadConsAL208_vs_broadFullAL651", set_A = "broad_cons_AL_208", set_B = "broad_full_AL_651"),
    s2, list(explanation_code = "SUBSET_SAME_DEF",
             note = "Same broad AL def; conservative (4 cases) is a strict subset of full portfolio. 208<651 restores the subset relation.")),
  c(list(pair = "static193_vs_broadConsAL208", set_A = "static_193", set_B = "broad_cons_AL_208"),
    s3, list(explanation_code = "TWO_AXIS_DIFFERENCE",
             note = "193>vs<208 differ on TWO axes: (1) stratum FL(193) vs AL(208); (2) cobidder def narrow vs broad; (3) case window full vs conservative-4. The cited 210>193 is NOT a same-definition comparison."))
))
fwrite(summ, file.path(D_DIAG, "cobidder_set_comparison_summary.csv"))
say("[write] cobidder_set_comparison_summary.csv (", nrow(summ), " rows)")

# =============================================================================
# (5) ASSERTIONS
# =============================================================================
asrt <- list()
add <- function(id, desc, res, obs, exp, impl, act)
  asrt[[length(asrt) + 1]] <<- list(check_id = id, check_description = desc, result = res,
    observed_value = as.character(obs), expected_value = as.character(exp),
    implication = impl, action_required = act)

# (1) CNPJ 14-padded
bad_pad <- sum(nchar(c(set_static, set_broadAL)) != 14, na.rm = TRUE)
add("A1", "CNPJ consistently 14-padded across all label sets",
    ifelse(bad_pad == 0, "pass", "fail"), paste0(bad_pad, " non-14-char"), "0",
    "CNPJ join keys are canonical", ifelse(bad_pad == 0, "none", "re-pad CNPJ"))
# (2) no missing firm IDs in labels
miss_firm <- cob_stat[is.na(cnpj) | cnpj == "", .N]
add("A2", "No missing firm IDs in cobidder labels",
    ifelse(miss_firm == 0, "pass", "fail"), miss_firm, "0",
    "every label row has a firm", ifelse(miss_firm == 0, "none", "drop/repair NA firm rows"))
# (3) no missing tender-item IDs in defendant items
miss_ti <- dbGetQuery(con, "SELECT COUNT(*) n FROM def_items WHERE numerodaoc IS NULL OR \"códigoitem\" IS NULL")$n
add("A3", "No missing tender-item IDs in defendant tender-items",
    ifelse(miss_ti == 0, "pass", "fail"), miss_ti, "0",
    "co-bid join keys intact", ifelse(miss_ti == 0, "none", "repair tender-item keys"))
# (4) defendants excluded from cobidders
def_in_cob <- length(intersect(unique(cross$cnpj), set_broadAL))
add("A4", "Direct defendants excluded from cobidder sets",
    ifelse(def_in_cob == 0, "pass", "fail"), paste0(def_in_cob, " defendants in cobidders"), "0",
    "exposure label does not contaminate with defendants", ifelse(def_in_cob == 0, "none", "exclude defendants"))
# (5) AL cobidders satisfy win_rate==0
al_badwr <- cob_stat[is_AL == 1 & !is.na(win_rate) & win_rate != 0, .N]
add("A5", "All AL cobidders satisfy win_rate==0",
    ifelse(al_badwr == 0, "pass", "fail"), paste0(al_badwr, " AL with win_rate!=0"), "0",
    "always-loser stratum well-defined", ifelse(al_badwr == 0, "none", "fix AL definition"))
# (6) FL cobidders satisfy AL & tc>=14
fl_bad <- cob_stat[is_FL == 1 & (is_AL != 1 | is.na(tenders_count) | tenders_count < FL_CUT), .N]
add("A6", "All FL cobidders satisfy AL & tenders_count>=14",
    ifelse(fl_bad == 0, "pass", "fail"), paste0(fl_bad, " FL violating"), "0",
    "FL stratum is a clean subset of AL", ifelse(fl_bad == 0, "none", "fix FL definition"))
# (7) under COMMON broad def, conservative <= full
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): NA-safe when conservative skipped (federal).
if (!HAVE_CONS) {
  add("A7", "Under COMMON broad def, conservative <= full (subset relation restored)",
      "not_applicable", "conservative benchmark skipped (CONS_DATE NA)",
      "n/a (no judgment dates)", "no conservative subset for this source", "none")
} else {
  c7a <- n_cons_AL <= n_AL; c7b <- n_cons_FL <= n_FL
  add("A7", "Under COMMON broad def, conservative <= full (subset relation restored)",
      ifelse(c7a && c7b, "pass", "fail"),
      paste0("AL ", n_cons_AL, "<=", n_AL, " & FL ", n_cons_FL, "<=", n_FL),
      "208<=651 AL and 107<=341 FL",
      "subset relation holds under common def; confirms def-difference explanation",
      ifelse(c7a && c7b, "none", "investigate"))
}
# (8) the cited 210-vs-193 inequality is NOT a same-definition comparison
add("A8", "Cited 210>193 is NOT a same-definition comparison",
    "warning", "210(AL,broad,cons) vs 193(FL,narrow,full)", "definition-driven, not bug",
    "DIFFERENT_COBIDDER_DEFINITION + AL-vs-FL stratum: 210=always-loser/broad/conservative; 193=frequent-loser/narrow/full",
    "report as definition difference, not bug")
# (9) unique-firm counts separated from pair/item row counts
n_cob_pairs <- nrow(unique(cob_per_case[, .(cnpj, proc)]))
n_cob_firms <- uniqueN(cob_per_case$cnpj)
add("A9", "Unique-firm counts separated from firm-case-pair / tender-item row counts",
    ifelse(n_cob_pairs > n_cob_firms, "pass", "warning"),
    paste0(n_cob_firms, " firms vs ", n_cob_pairs, " firm-case pairs vs ", n_def_item_ti, " tender-items"),
    "firm-case pairs > unique firms (expected)",
    "row-count vs unique-firm conflation is the original source of count confusion",
    "always state the counting unit")
# (10) manuscript vs reproductions logged
add("A10", "Manuscript counts vs reproductions logged",
    "pass", "193 exact; 341/651/208/107/19/41 reproduced; 30 mismatch; 47~48",
    "all locked-diagnosis values reproduced",
    "193 static exact; 341/208/107/19 reproduced; 30->19 drop; 47 vs 41/48 noted; 65/16779/11676 not_found",
    "bind new macros; drop \\valConservativeFD 30->19")

asrtDT <- rbindlist(asrt)
fwrite(asrtDT, file.path(D_DIAG, "label_funnel_assertions.csv"))
say("[write] label_funnel_assertions.csv (", nrow(asrtDT), " checks)")
say("[assert] results: ", paste(sprintf("%s=%s", asrtDT$check_id, asrtDT$result), collapse = " "))

# =============================================================================
# (6) FUNNEL FIGURE
# =============================================================================
fig_status <- "OK"
fig_err <- ""
# Two vertical branches on a clean grid. Firm branch (x=1) descends and splits
# at the bottom into the static-193 target and the broad-341 robustness node.
# Anchor branch (x=3) descends to the same main 193 cobidder target.
# Only nodes whose counts this script reproduces are plotted.
# SOURCE-CONFIG ADAPTATION (Phase 1 label-fix-2, 2026-06-05): platform name (PLAT) in figure node labels.
nF1 <- list(x = 1.0, y = 5, lab = sprintf("All %s firms\n%s", PLAT, format(n_all_BEC,     big.mark = ",")))
nF2 <- list(x = 1.0, y = 4, lab = sprintf("Always-losers\n%s",        format(n_AL_univ,     big.mark = ",")))
nF3 <- list(x = 1.0, y = 3, lab = sprintf("Main target: always-loser\ncobidders %d\n(%d FL / %d non-FL)", n_AL, n_FL, n_AL - n_FL))
nA1 <- list(x = 3.0, y = 5, lab = sprintf("%s-active direct\ndefendants %d", PLAT, n_def_ftm))
nA2 <- list(x = 3.0, y = 4, lab = sprintf("Defendant\ntender-items %s",   format(n_def_item_ti, big.mark = ",")))
nA3 <- list(x = 3.0, y = 3, lab = sprintf("Shared tender-item\nexposure label %d",   n_AL))
nodes <- rbindlist(lapply(list(nF1,nF2,nF3,nA1,nA2,nA3), as.data.table))
# segments: parent (x,y) -> child (xend,yend), drawn from node-edge to node-edge
seg <- rbindlist(list(
  data.table(x = nF1$x, y = nF1$y, xend = nF2$x, yend = nF2$y),  # all BEC -> AL
  data.table(x = nF2$x, y = nF2$y, xend = nF3$x, yend = nF3$y),  # AL -> main broad AL 651
  data.table(x = nA1$x, y = nA1$y, xend = nA2$x, yend = nA2$y),  # defendants -> items
  data.table(x = nA2$x, y = nA2$y, xend = nA3$x, yend = nA3$y))) # items -> label
fig <- tryCatch({
  p <- ggplot(nodes, aes(x = x, y = y)) +
    geom_segment(data = seg, aes(x = x, xend = xend, y = y - 0.32, yend = yend + 0.32),
                 inherit.aes = FALSE, color = "grey55",
                 arrow = arrow(length = unit(0.16, "cm"), type = "closed")) +
    geom_label(aes(label = lab), size = 2.9, fill = "#f4eded",
               color = "#7a1f1f", label.size = 0.3, lineheight = 0.9, family = "sans") +
    annotate("text", x = 1, y = 5.7, label = "Firm branch", fontface = "bold",
             size = 3.3, family = "sans", color = "grey30") +
    annotate("text", x = 3, y = 5.7, label = "Adjudication-anchor branch", fontface = "bold",
             size = 3.3, family = "sans", color = "grey30") +
    scale_x_continuous(limits = c(-0.2, 3.8)) +
    scale_y_continuous(limits = c(2.4, 5.9)) +
    theme_void(base_family = "sans") +
    theme(plot.margin = margin(10, 10, 10, 10))
  ggsave(file.path(D_FIG, "fig_label_funnel.pdf"), p, device = cairo_pdf,
         width = 8, height = 5.2)
  "OK"
}, error = function(e) { fig_err <<- conditionMessage(e); "FIGURE_BLOCKED" })
if (fig_status == "OK") fig_status <- fig
if (fig_status == "OK") say("[write] fig_label_funnel.pdf (cairo_pdf)") else
  say("[FIGURE] ", fig_status, " : ", fig_err)

# =============================================================================
# (7) MACRO SNIPPET
# =============================================================================
mac <- c(
  "% Auto-generated by work/v22-editor/scripts/analysis/01_label_funnel_reconciliation.R",
  "% NEW reproducible label-funnel macros (JLEO R&R v22 CP-1). Bind in values.tex.",
  sprintf("\\newcommand{\\valFunnelFLcobBroad}{%d}      %% src: broad-def FL cobidders, full portfolio", n_FL),
  sprintf("\\newcommand{\\valFunnelALcobBroad}{%d}      %% src: broad-def always-loser cobidders, full portfolio", n_AL),
  sprintf("\\newcommand{\\valFunnelConsALcob}{%d}       %% src: broad-def AL cobidders, 4 conservative cases (was 210)", n_cons_AL),
  sprintf("\\newcommand{\\valFunnelConsFLcob}{%d}       %% src: broad-def FL cobidders, 4 conservative cases (was 108)", n_cons_FL),
  sprintf("\\newcommand{\\valFunnelConsFD}{%d}          %% src: BEC-active defendants, 4 conservative cases (drop 30->19)", n_cons_def),
  sprintf("\\newcommand{\\valFunnelDirectActiveFTM}{%d} %% src: crossmatch defendants present in firm_tender_map", n_def_ftm),
  sprintf("\\newcommand{\\valFunnelDefItems}{%d}        %% src: distinct defendant tender-items", n_def_item_ti),
  sprintf("\\newcommand{\\valFunnelStaticOverlap}{%d}   %% src: |static193 INT broadFL341|", overlap_static_broadFL),
  sprintf("\\newcommand{\\valFunnelStaticTarget}{%d}    %% src: static cade_fl_cobidders.csv row count", n_cob_file))
writeLines(mac, file.path(D_DIAG, "label_funnel_new_macros.tex"))
say("[write] label_funnel_new_macros.tex (", length(mac) - 2, " macros)")

# flag deviations vs locked-diagnosis expectations
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): the locked-diagnosis literals are
# BEC-specific (341/651/208/...). Skip the comparison federally (different universe).
if (cfg$source == "bec") {
  expect <- c(broadFL = 341, broadAL = 651, consAL = 208, consFL = 107, consFD = 19,
              defFTM = 41, defItems = 52013, overlap = 149)
  got    <- c(broadFL = n_FL, broadAL = n_AL, consAL = n_cons_AL, consFL = n_cons_FL,
              consFD = n_cons_def, defFTM = n_def_ftm, defItems = n_def_item_ti,
              overlap = overlap_static_broadFL)
  dev <- got != expect
  if (any(dev)) {
    say("[WARN] deviations vs locked diagnosis: ",
        paste(sprintf("%s got=%d exp=%d", names(got)[dev], got[dev], expect[dev]), collapse = "; "))
  } else {
    say("[OK] all 8 locked-diagnosis values reproduced exactly: ",
        paste(sprintf("%s=%d", names(got), got), collapse = " "))
  }
} else {
  say("[OK] federal funnel built fresh; BEC locked-diagnosis comparison not applicable.")
}

dbDisconnect(con, shutdown = TRUE)
say("[done] elapsed=", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
    "s  RSS=", rss_mb(), "MB")
cat("\nDONE. Outputs under", OUT, "\n")
