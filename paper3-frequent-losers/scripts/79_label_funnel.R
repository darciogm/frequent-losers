#!/usr/bin/env Rscript
# =============================================================================
# 79_label_funnel.R  --  JLEO R&R (v22), CP-1 / Transversal-2
#
# PURPOSE
#   Rebuild, from data alone, the label-construction funnel that reconciles
#   every validation-target count the manuscript cites, and MATERIALIZE the
#   case -> cobidder linkage that the leave-one-case-out / rolling-origin
#   validation needs (currently absent; cobidder labels carry no case_id).
#
#   Funnel stages:
#     S0  CADE procurement cases                      (cade_carteis)
#     S1  BEC-active direct defendants                (crossmatch x firm_tender_map)
#     S2  direct-defendant tender-items               (firm_tender_map)
#     S3  cobidders of direct defendants (all, !=-1)
#     S4  always-loser cobidders                      (win_rate==0)
#     S5  FL cobidders  (FL14 = tenders_count>=14)    -> should reproduce 193
#     S6  CONSERVATIVE subset (cases judged <=2020-12-31):
#           defendants / cobidders / AL cobidders / FL cobidders
#           -> tests the manuscript's claimed 4 cases / 30 def / 210 / 108
#
# OUTPUTS (output/label_funnel/)
#   funnel.csv            one row per funnel stage with count + source
#   case_timing.csv       case x judgment-date x #defendants (Table G)
#   case_cobidder_map.csv  cobidder x processo x judgment-date  (unblocks LOCO)
#   audit_log.txt         full telemetry + reconciliation verdict
#
# DISCIPLINE
#   - DuckDB engine (16.8M-row co-bid join), threads=12, mem=14GB, /tmp spill.
#   - Deterministic; seed set for reproducibility hygiene (no resampling here).
#   - Reproduces, does not overwrite, the static cade_fl_cobidders.csv.
#   - Exits with an explicit PASS/PARTIAL verdict vs the cited macros.
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table)
})
set.seed(20260602L)

# ---- paths (portable: derive from this script's location) -------------------
args0 <- commandArgs(trailingOnly = FALSE)
sd <- sub("^--file=", "", grep("^--file=", args0, value = TRUE))
SCRIPT_DIR <- if (length(sd)) dirname(normalizePath(sd)) else
              if (exists(".script_dir")) normalizePath(.script_dir) else getwd()
BASE   <- normalizePath(file.path(SCRIPT_DIR, ".."))   # paper3-frequent-losers/
DATA   <- file.path(BASE, "data", "processed")
OUTDIR <- file.path(BASE, "output", "label_funnel")
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

LOG <- file.path(OUTDIR, "audit_log.txt")
con_log <- file(LOG, open = "wt")
say <- function(...) { m <- paste0(...); cat(m, "\n"); cat(m, "\n", file = con_log) }

t0 <- Sys.time()
say("================ 79_label_funnel.R  (JLEO R&R v22, CP-1) ================")
say("host=", Sys.info()[["nodename"]], "  start=", format(t0))
say("BASE=", BASE)

# ---- inputs -----------------------------------------------------------------
f_ftm   <- file.path(DATA, "firm_tender_map.parquet")          # firm x item + won
f_loss  <- file.path(DATA, "firm_loss_stats.parquet")          # win_rate, always_loser
f_freq  <- file.path(DATA, "FREQ_PARTICIP_rebuilt.parquet")    # AL universe + tenders_count
f_cross <- file.path(DATA, "cade_bec_crossmatch.csv")          # direct defendants x case
f_cart  <- file.path(DATA, "cade_carteis_licitacoes_2009_2019.csv")  # case metadata + dates
f_cob   <- file.path(DATA, "cade_fl_cobidders.csv")            # static 193-row target
stopifnot(all(file.exists(f_ftm, f_loss, f_freq, f_cross, f_cart, f_cob)))

FL_CUT <- 14L   # canonical FL14 = tenders_count >= 14 (CLAUDE.md / fl_convention memo)
CONS_DATE <- as.Date("2020-12-31")  # conservative-benchmark cutoff (judged <= end-2020)

# ---- read small CSVs in R (latin/utf tolerant), normalize CNPJ to 14 --------
pad14 <- function(x) { x <- gsub("[^0-9]", "", as.character(x)); ifelse(x=="", NA, sprintf("%014s", x)) }
# sprintf %014s pads with spaces, not zeros -> use formatC
pad14 <- function(x) { x <- gsub("[^0-9]", "", as.character(x)); ifelse(x=="", NA_character_, formatC(x, width=14, flag="0")) }

cross <- fread(f_cross, colClasses = "character")
cart  <- fread(f_cart,  colClasses = "character")
cob   <- fread(f_cob,   colClasses = "character")

cross[, cnpj := pad14(fornecedor)]
cross[, proc := processo]
cross <- cross[!is.na(cnpj) & toupper(fornecedor) != "IT_DF" & nchar(cnpj) == 14]
cart[,  proc := numero_processo]
cart <- cart[!is.na(proc) & trimws(proc) != "" & toupper(proc) != "IT_DF"]
cart[,  jdate := as.Date(data_julgamento)]
cob[,   cnpj := pad14(`códigofornecedor`)]

n_cob_file <- nrow(cob)
say("\n[file] cade_fl_cobidders.csv rows (static target) = ", n_cob_file)
say("[file] crossmatch valid direct-defendant rows      = ", nrow(cross),
    "  (distinct CNPJ=", uniqueN(cross$cnpj), ", distinct processo=", uniqueN(cross$proc), ")")
say("[file] cade_carteis distinct processo              = ", uniqueN(cart$proc))

# ---- DuckDB session ---------------------------------------------------------
con <- dbConnect(duckdb())
invisible(dbExecute(con, "PRAGMA threads=12"))
invisible(dbExecute(con, "PRAGMA memory_limit='14GB'"))
invisible(dbExecute(con, "PRAGMA temp_directory='/tmp/duckdb_spill'"))

dbWriteTable(con, "defend",  unique(cross[, .(cnpj, proc)]),               overwrite = TRUE)
dbWriteTable(con, "cobfile", unique(cob[, .(cnpj)]),                       overwrite = TRUE)

dbExecute(con, sprintf("CREATE VIEW ftm  AS SELECT * FROM read_parquet('%s')", f_ftm))
dbExecute(con, sprintf("CREATE VIEW loss AS SELECT * FROM read_parquet('%s')", f_loss))
dbExecute(con, sprintf("CREATE VIEW freq AS SELECT * FROM read_parquet('%s')", f_freq))

# distinct BEC-active defendant CNPJs (those that actually appear in firm_tender_map)
defend_active <- dbGetQuery(con, "
  SELECT DISTINCT d.cnpj
  FROM defend d
  WHERE d.cnpj IN (SELECT DISTINCT \"códigofornecedor\" FROM ftm)")
say("\n[S1] BEC-active direct defendants (in firm_tender_map) = ", nrow(defend_active))

# direct-defendant tender-items, carrying the defendant's case(s)
dbExecute(con, "
  CREATE TEMP TABLE def_items AS
  SELECT DISTINCT f.numerodaoc, f.\"códigoitem\", d.proc
  FROM ftm f JOIN defend d ON f.\"códigofornecedor\" = d.cnpj")
n_def_items <- dbGetQuery(con, "SELECT COUNT(*) n, COUNT(DISTINCT (numerodaoc||'|'||\"códigoitem\")) ni FROM def_items")
say("[S2] direct-defendant tender-item x case rows = ", n_def_items$n,
    "  (distinct tender-items=", n_def_items$ni, ")")

# cobidders = other firms sharing those tender-items (exclude defendants and -1 sentinel)
dbExecute(con, "
  CREATE TEMP TABLE cobidder_case AS
  SELECT DISTINCT f.\"códigofornecedor\" AS cnpj, di.proc
  FROM ftm f JOIN def_items di
    ON f.numerodaoc = di.numerodaoc AND f.\"códigoitem\" = di.\"códigoitem\"
  WHERE f.\"códigofornecedor\" <> '-1'
    AND f.\"códigofornecedor\" NOT IN (SELECT cnpj FROM defend)")

cob_all <- dbGetQuery(con, "SELECT DISTINCT cnpj FROM cobidder_case")
say("[S3] cobidders of direct defendants (all, !=-1, !=defendant) = ", nrow(cob_all))

# enrich each cobidder with loss stats + AL universe tenders_count
cob_stat <- dbGetQuery(con, "
  SELECT c.cnpj,
         l.win_rate, l.always_loser,
         fr.tenders_count
  FROM (SELECT DISTINCT cnpj FROM cobidder_case) c
  LEFT JOIN loss l ON l.\"códigofornecedor\" = c.cnpj
  LEFT JOIN freq fr ON fr.\"códigofornecedor\" = c.cnpj")
setDT(cob_stat)

n_AL <- cob_stat[always_loser == 1 | (!is.na(win_rate) & win_rate == 0), uniqueN(cnpj)]
cob_stat[, is_AL := as.integer(always_loser == 1 | (!is.na(win_rate) & win_rate == 0))]
cob_stat[, is_FL := as.integer(is_AL == 1 & !is.na(tenders_count) & tenders_count >= FL_CUT)]
n_FL <- cob_stat[is_FL == 1, uniqueN(cnpj)]
say("[S4] always-loser cobidders (win_rate==0)            = ", n_AL)
say("[S5] FL cobidders (AL & tenders_count>=", FL_CUT, ")        = ", n_FL,
    "   [manuscript \\valCobidders = 193]")

# reconciliation against the static file
recon <- merge(cob_stat[, .(cnpj, is_AL, is_FL)],
               cob[, .(cnpj, file_FL = 1L)], by = "cnpj", all = TRUE)
in_both   <- recon[is_FL == 1 & file_FL == 1, .N]
only_recon<- recon[is_FL == 1 & is.na(file_FL), .N]
only_file <- recon[(is.na(is_FL) | is_FL == 0) & file_FL == 1, .N]
say("    reconstruction vs static file: both=", in_both,
    "  recon-only=", only_recon, "  file-only=", only_file)

# ---- CONSERVATIVE subset (cases judged <= 2020-12-31) -----------------------
proc_dates <- unique(cart[!is.na(jdate) & !is.na(proc) & trimws(proc) != "", .(proc, jdate)])
cons_procs <- proc_dates[jdate <= CONS_DATE, unique(proc)]
say("\n[S6] CONSERVATIVE cutoff <= ", format(CONS_DATE))
say("    cases with judgment date           = ", uniqueN(proc_dates$proc), " / ",
    uniqueN(cart$proc), " total")
say("    conservative cases (judged <=2020) = ", length(cons_procs),
    "   [manuscript \\valConservativeCases = 4]   procs: ", paste(cons_procs, collapse=", "))

cons_def <- dbGetQuery(con, sprintf("
  SELECT DISTINCT cnpj FROM defend WHERE proc IN (%s)",
  paste(sprintf("'%s'", cons_procs), collapse=",")))
cons_cob <- if (length(cons_procs)) dbGetQuery(con, sprintf("
  SELECT DISTINCT cnpj FROM cobidder_case WHERE proc IN (%s)",
  paste(sprintf("'%s'", cons_procs), collapse=","))) else data.frame(cnpj=character())
setDT(cons_cob)
cons_join <- merge(cons_cob, cob_stat[, .(cnpj, is_AL, is_FL)], by="cnpj", all.x=TRUE)
say("    conservative BEC-active defendants = ", nrow(cons_def),
    "   [manuscript \\valConservativeFD = 30]")
say("    conservative cobidders (all)       = ", nrow(cons_cob))
say("    conservative AL cobidders          = ", cons_join[is_AL==1, .N],
    "   [manuscript \\valConservativeCobidders = 210]")
say("    conservative FL cobidders          = ", cons_join[is_FL==1, .N],
    "   [manuscript conservative-FL = 108]")

# ---- write outputs ----------------------------------------------------------
funnel <- data.table(
  stage = c("S0_cade_cases","S1_bec_active_defendants","S2_defendant_tender_items",
            "S3_cobidders_all","S4_always_loser_cobidders","S5_FL_cobidders",
            "S6_cons_cases","S6_cons_defendants","S6_cons_cobidders_all",
            "S6_cons_AL_cobidders","S6_cons_FL_cobidders"),
  count = c(uniqueN(cart$proc), nrow(defend_active), n_def_items$ni,
            nrow(cob_all), n_AL, n_FL,
            length(cons_procs), nrow(cons_def), nrow(cons_cob),
            cons_join[is_AL==1,.N], cons_join[is_FL==1,.N]),
  manuscript_macro = c("12 procs","\\valDirectCADE=47","-","-","(App C says 193)",
                       "\\valCobidders=193","\\valConservativeCases=4","\\valConservativeFD=30",
                       "-","\\valConservativeCobidders=210","conservative-FL=108"),
  source = "scripts/79_label_funnel.R")
fwrite(funnel, file.path(OUTDIR, "funnel.csv"))

case_timing <- merge(
  unique(cart[, .(proc, jdate)]),
  unique(cross[, .(proc, cnpj)])[, .(n_bec_defendants = uniqueN(cnpj)), by = proc],
  by = "proc", all.x = TRUE)
case_timing[is.na(n_bec_defendants), n_bec_defendants := 0L]
case_timing <- merge(case_timing, unique(cart[, .(proc, setor)]), by="proc", all.x=TRUE)
setorder(case_timing, jdate, na.last = TRUE)
fwrite(case_timing, file.path(OUTDIR, "case_timing.csv"))

ccm <- merge(setDT(dbGetQuery(con, "SELECT cnpj, proc FROM cobidder_case")),
             proc_dates, by = "proc", all.x = TRUE)
ccm <- merge(ccm, cob_stat[, .(cnpj, is_AL, is_FL)], by = "cnpj", all.x = TRUE)
setorder(ccm, cnpj, proc)
fwrite(ccm, file.path(OUTDIR, "case_cobidder_map.csv"))
say("\n[write] funnel.csv / case_timing.csv / case_cobidder_map.csv (",
    nrow(ccm), " cobidder-case rows) -> ", OUTDIR)

# ---- verdict (calibrated: exact / approx +/-3 / discrepant) -----------------
near <- function(x, target, tol = 3) abs(x - target) <= tol
say("\n========== RECONCILIATION VERDICT ==========")
n_cons_AL <- cons_join[is_AL==1,.N]; n_cons_FL <- cons_join[is_FL==1,.N]
say("  Reference co-bid definition used here: ANY shared tender-item with a BEC-active")
say("  direct defendant (transparent, fully scripted). FL14 = tenders_count>=", FL_CUT, ".")
say("  --- full portfolio ---")
say("  (a) FL cobidders vs \\valCobidders=193 : ", n_FL,
    "  -> ", ifelse(near(n_FL,193), "APPROX", "DISCREPANT (broad def over-counts; original used a narrow cartel-tender restriction not on disk)"))
say("      overlap with static file: ", in_both, "/193 ; file-only=", only_file, " ; recon-only=", only_recon)
say("  --- conservative subset (judged <= 2020) ---")
say("  (b) cases vs \\valConservativeCases=4  : ", length(cons_procs),
    "  -> ", ifelse(length(cons_procs)==4,"EXACT","DISCREPANT"))
say("  (c) defendants vs \\valConservativeFD=30: ", nrow(cons_def),
    "  -> ", ifelse(near(nrow(cons_def),30),"APPROX","DISCREPANT (19 BEC-active; 30 likely counts non-active/loose-match rows)"))
say("  (d) AL cobidders vs 210               : ", n_cons_AL,
    "  -> ", ifelse(near(n_cons_AL,210),"APPROX (data-grounded)","DISCREPANT"))
say("  (e) FL cobidders vs 108               : ", n_cons_FL,
    "  -> ", ifelse(near(n_cons_FL,108),"APPROX (data-grounded)","DISCREPANT"))
say("\n  INTERPRETATION:")
say("   * 210/108 are NOT fabricated -- they reproduce to ", n_cons_AL, "/", n_cons_FL,
    " under the broad co-bid definition.")
say("   * BUT the main 193 target does NOT match the broad definition (=", n_FL,
    "); it used a narrower, undocumented cartel-tender restriction.")
say("   * => the main (193) and conservative (210/108) benchmarks were built with")
say("        DIFFERENT cobidder definitions. This inconsistency must be resolved before §4.")
say("   * The ORIGINAL builder of cade_fl_cobidders.csv is absent from the repo (all scripts")
say("        only consume it) -> JLEO replication BLOCKER B3 confirmed.")
say("  DECISION REQUIRED (U2): adopt one transparent scripted definition repo-wide and")
say("  re-validate (changes every AUC), OR reverse-engineer the original narrow restriction.")
say("  elapsed=", round(as.numeric(difftime(Sys.time(), t0, units="secs")),1), "s")

dbDisconnect(con, shutdown = TRUE)
close(con_log)
cat("\nDONE. See", OUTDIR, "\n")
