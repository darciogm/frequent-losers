#!/usr/bin/env Rscript
# =============================================================================
# 00_build_canonical_validation_targets.R -- JLEO final optimization (v22)
#
# PURPOSE
#   Build ALL validation targets from raw/intermediate reproducible data so the
#   main validation target is (i) reproducible from current scripts, (ii)
#   non-circular (frequent-loser status NEVER used to define positivity), and
#   (iii) cleanly documented. Replaces the static archived cade_fl_cobidders.csv
#   (193 rows, FL-only, builder absent) as the source of any submitted label.
#
# TARGETS (docs/jleo_rr_revision/88_CANONICAL_TARGET_DEFINITIONS.md)
#   A  direct CADE defendants (legal anchors; BEC-active = in firm_tender_map)
#   B  broad always-loser cobidder target (MAIN): W_i = 0 firm sharing >=1 BEC
#      tender-item with >=1 BEC-active direct defendant; defendants excluded
#   C  narrow cartel-tender target: NOT REPRODUCIBLE (archived builder); the
#      static file is loaded ONLY for internal set comparison (target_source_flag)
#   D  conservative pre-2020 benchmark: Target B with cases judged <= 2020-12-31
#   E  timing fields: first/last cobid year, first participation year,
#      rankable-incumbent flag (pre-2017 history)
#   F  bid-feature common-support flag (complete Imhof moments)
#
# OUTPUTS
#   outputs/targets/canonical_firm_labels.csv          (hashed firm ids)
#   outputs/targets/canonical_case_labels.csv
#   outputs/targets/canonical_target_counts.csv
#   outputs/cache/canonical_cobidders_broad.csv        (raw keys, downstream joins)
#   outputs/diagnostics/target_construction_assertions.csv
#   outputs/diagnostics/target_set_comparisons.csv
#
# DISCIPLINE: DuckDB threads=12 mem=14GB /tmp spill; seed 20260604; telemetry.
#   Reuses the S1-S3 join logic of 01_label_funnel_reconciliation.R verbatim.
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table)
})
set.seed(20260604L)

t0   <- Sys.time()
host <- Sys.info()[["nodename"]]
rss_mb <- function() {
  v <- tryCatch(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern = TRUE)),
                error = function(e) NA_real_)
  round(v / 1024, 1)
}
say <- function(...) cat(paste0(..., "\n"))

# ---- paths ------------------------------------------------------------------
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05)
# Source-abstraction layer: --source=bec (default) | comprasnet. All paths,
# constants, key-extraction lambdas, output dirs and CADE layout come from cfg.
# BEC behaviour is byte-identical (cfg$* bec values equal the prior literals).
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
OUT    <- cfg$out_root
D_TGT  <- cfg$dirs$targets
D_DIAG <- cfg$dirs$diagnostics
D_CACH <- cfg$dirs$cache

say("================ 00_build_canonical_validation_targets.R (JLEO v22 final) ================")
say("source=", cfg$source, " (", cfg$label, ")")
say("host=", host, "  start=", format(t0), "  RSS=", rss_mb(), "MB")

# ---- inputs -----------------------------------------------------------------
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): core parquets from cfg.
f_ftm   <- cfg$firm_tender_map
f_loss  <- cfg$firm_loss_stats
f_freq  <- cfg$freq_particip
f_imh   <- file.path(cfg$dirs$cache, "imhof_firm_features.parquet")  # bid-feature support
stopifnot(all(file.exists(f_ftm, f_loss, f_freq)))

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): FL cut + conservative cutoff
# from cfg (bec 14 / fed 32, both ">="; CONS_DATE bec=2020-12-31, fed=2025-02-26
# latest federal numbered-case judgment date). HAVE_CONS guards a graceful skip if
# a source ever has CONS_DATE=NA (no judgment dates wired in); both current sources
# DO have it, so the conservative benchmark runs for both.
FL_CUT    <- cfg$FL_CUT
CONS_DATE <- cfg$CONS_DATE
HAVE_CONS <- !is.na(CONS_DATE)
RANK_CUT  <- 2016L   # rankable incumbent = first participation year <= 2016

pad14 <- function(x){ x <- gsub("[^0-9]", "", as.character(x)); ifelse(x == "", NA_character_, formatC(x, width = 14, flag = "0")) }

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): CADE input-normalization branch
# keyed on cfg$cade_layout. Both layouts are mapped into the SAME internal frames
# the rest of the script consumes:
#   cross : data.table(cnpj, proc)  -- defendant CNPJ x case (estab-level, 14-digit)
#   cart  : data.table(proc, jdate, setor) -- case roster with judgment dates
#   cobS  : data.table(cnpj)        -- archived/static set for INTERNAL comparison only
# D-i finding (verified): BEC anchors defendants at the FULL 14-digit ESTAB CNPJ
#   (`defend` table = pad14(fornecedor); joins on f."códigofornecedor" = d.cnpj,
#    which is 14-digit estab in firm_tender_map). The federal rebuild MIRRORS this
#   exactly: anchor on direct_defendants_federal$firm_id (14-digit estab), NOT on
#   cnpj_raiz. (See the rebuild + set-comparison block below.)
if (cfg$cade_layout == "bec_csv") {
  f_cross <- cfg$cade$crossmatch
  f_cart  <- cfg$cade$carteis
  f_cob   <- cfg$cade$cobidders                      # internal comparison ONLY
  stopifnot(all(file.exists(f_cross, f_cart, f_cob)))

  cross <- fread(f_cross, colClasses = "character")
  cart  <- fread(f_cart,  colClasses = "character")
  cobS  <- fread(f_cob,   colClasses = "character")  # static archived (comparison only)

  cross[, cnpj := pad14(fornecedor)]
  cross[, proc := processo]
  n_cross_raw <- nrow(cross)
  cross <- cross[!is.na(cnpj) & toupper(fornecedor) != "IT_DF" & nchar(cnpj) == 14]
  n_cross_dropped <- n_cross_raw - nrow(cross)
  cross <- cross[, .(cnpj, proc)]
  cart[, proc := numero_processo]
  cart <- cart[!is.na(proc) & trimws(proc) != "" & toupper(proc) != "IT_DF"]
  cart[, jdate := as.Date(data_julgamento)]
  cart <- cart[, .(proc, jdate, setor)]
  cobS[, cnpj := pad14(`códigofornecedor`)]

} else if (cfg$cade_layout == "federal_parquet_v3") {
  # Federal layout: direct defendants + anchored tenders + cobidders as parquets.
  f_dd   <- cfg$cade$direct_defendants   # firm_id (14-digit estab), cnpj_raiz, processo, setor
  f_cobF <- cfg$cade$cobidders           # v3 raiz/estab-anchored set -> SET-COMPARISON ONLY
  stopifnot(all(file.exists(f_dd, f_cobF)))
  if (!requireNamespace("arrow", quietly = TRUE))
    stop("federal CADE parquets require the 'arrow' package")

  dd <- as.data.table(arrow::read_parquet(f_dd))
  # cross = defendant estab CNPJ x case (mirror BEC's 14-digit estab anchoring)
  cross <- unique(dd[, .(cnpj = pad14(firm_id), proc = as.character(processo))])
  cross <- cross[!is.na(proc) & trimws(proc) != ""]   # drop empty-processo group (gate G3)
  n_cross_raw <- nrow(cross)
  cross <- cross[!is.na(cnpj) & nchar(cnpj) == 14]
  n_cross_dropped <- n_cross_raw - nrow(cross)
  # cart = case roster. Federal per-case judgment dates come from the SAME provenance
  # the BEC pipeline uses, exposed via cfg$cade$cnpjs_enriched (numero_processo /
  # data_julgamento). Join them in by processo so the conservative benchmark works
  # under the (now real) cfg$CONS_DATE. Undated cases keep jdate = NA.
  cart <- unique(dd[, .(proc = as.character(processo), setor = as.character(setor))])
  cart <- cart[!is.na(proc) & trimws(proc) != ""]
  jd <- fread(cfg$cade$cnpjs_enriched, colClasses = "character")
  jd <- unique(jd[trimws(numero_processo) != "" & trimws(data_julgamento) != "",
                  .(proc = numero_processo, jdate = as.Date(data_julgamento))])
  cart <- merge(cart, jd, by = "proc", all.x = TRUE)
  if (!"jdate" %in% names(cart)) cart[, jdate := as.Date(NA)]
  # cobS = archived/static comparison set. Federal has no narrow FL-only archive;
  # we use the v3 cobidders parquet purely for the internal set comparison.
  cobS <- as.data.table(arrow::read_parquet(f_cobF))
  cobS[, cnpj := pad14(firm_id)]
  cobS <- cobS[, .(cnpj)]

} else stop("Unknown cfg$cade_layout: ", cfg$cade_layout)

say("[in] defendant rows kept=", nrow(cross), " dropped(missing/junk CNPJ)=", n_cross_dropped,
    " distinct CNPJ=", uniqueN(cross$cnpj))
say("[in] cade cases distinct=", uniqueN(cart$proc),
    " ; static/archived comparison rows=", nrow(cobS), " (comparison only)")

# ---- DuckDB session ---------------------------------------------------------
con <- dbConnect(duckdb())
invisible(dbExecute(con, "PRAGMA threads=12"))
invisible(dbExecute(con, "PRAGMA memory_limit='14GB'"))
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): spill dir from cfg (BEC keeps
# /tmp/duckdb_spill; federal uses its own isolated dir under outputs/comprasnet).
invisible(dbExecute(con, sprintf("PRAGMA temp_directory='%s'", cfg$temp_directory)))

dbWriteTable(con, "defend", unique(cross[, .(cnpj, proc)]), overwrite = TRUE)
invisible(dbExecute(con, sprintf("CREATE VIEW ftm  AS SELECT * FROM read_parquet('%s')", f_ftm)))
invisible(dbExecute(con, sprintf("CREATE VIEW loss AS SELECT * FROM read_parquet('%s')", f_loss)))
invisible(dbExecute(con, sprintf("CREATE VIEW freq AS SELECT * FROM read_parquet('%s')", f_freq)))

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): year extraction.
# CONTRACT: never substr numerodaoc federally (numbering year != result year).
#   BEC      -> cfg$year_from_key("numerodaoc") gives a stable SUBSTR(...,12,4)
#               expr; we materialise a (numerodaoc, year) map = ymap.
#   FEDERAL  -> cfg$get_year_map(con) returns (numerodaoc, codigoitem, year);
#               we materialise it as ymap keyed on (numerodaoc, codigoitem).
# Downstream year aggregations JOIN ymap instead of calling substr.
if (!is.null(cfg$year_from_key)) {
  # BEC: composite-key year. Map is (numerodaoc -> year); codigoitem column added
  # as NULL so the join shape is identical across sources (join on numerodaoc).
  invisible(dbExecute(con, sprintf("
    CREATE TEMP TABLE ymap AS
    SELECT DISTINCT numerodaoc,
           CAST(%s AS INTEGER) AS year
    FROM ftm WHERE numerodaoc IS NOT NULL", cfg$year_from_key("numerodaoc"))))
  YEAR_JOIN <- "JOIN ymap y ON f.numerodaoc = y.numerodaoc"      # BEC: by tender
} else {
  ym <- cfg$get_year_map(con)            # data.frame(numerodaoc, códigoitem, year)
  setnames(ym, c("numerodaoc", "códigoitem", "year"))
  dbWriteTable(con, "ymap", ym, overwrite = TRUE)
  YEAR_JOIN <- "JOIN ymap y ON f.numerodaoc = y.numerodaoc AND f.\"códigoitem\" = y.\"códigoitem\""  # FED: by tender-item
}

# ---- Target A: BEC-active direct defendants (verbatim S1 of 01_...R) --------
defend_active <- dbGetQuery(con, "
  SELECT DISTINCT d.cnpj FROM defend d
  WHERE d.cnpj IN (SELECT DISTINCT \"códigofornecedor\" FROM ftm)")
n_def_ftm   <- nrow(defend_active)
n_def_cross <- uniqueN(cross$cnpj)
say("[A] BEC-active direct defendants (ftm) = ", n_def_ftm,
    " ; crossmatch distinct CNPJ = ", n_def_cross)

# ---- defendant tender-items (verbatim S2) ------------------------------------
invisible(dbExecute(con, "
  CREATE TEMP TABLE def_items AS
  SELECT DISTINCT f.numerodaoc, f.\"códigoitem\", d.proc
  FROM ftm f JOIN defend d ON f.\"códigofornecedor\" = d.cnpj"))
n_def_item_ti <- dbGetQuery(con, "
  SELECT COUNT(DISTINCT (numerodaoc||'|'||\"códigoitem\")) ni FROM def_items")$ni
miss_ti <- dbGetQuery(con, "SELECT COUNT(*) n FROM def_items WHERE numerodaoc IS NULL OR \"códigoitem\" IS NULL")$n
say("[items] distinct defendant tender-items = ", n_def_item_ti, " (missing keys=", miss_ti, ")")

# ---- cobidders of defendants (verbatim S3): NO FL ANYWHERE -------------------
invisible(dbExecute(con, "
  CREATE TEMP TABLE cobidder_case AS
  SELECT DISTINCT f.\"códigofornecedor\" AS cnpj, di.proc
  FROM ftm f JOIN def_items di
    ON f.numerodaoc = di.numerodaoc AND f.\"códigoitem\" = di.\"códigoitem\"
  WHERE f.\"códigofornecedor\" <> '-1'
    AND f.\"códigofornecedor\" NOT IN (SELECT cnpj FROM defend)"))

# per-cobidder contact intensity + years of contact (Target E ingredients)
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): year via ymap join, not substr.
cob_contact <- setDT(dbGetQuery(con, sprintf("
  SELECT f.\"códigofornecedor\" AS cnpj,
         COUNT(DISTINCT (f.numerodaoc||'|'||f.\"códigoitem\")) AS n_cobid_tender_items,
         MIN(y.year) AS first_cobid_year,
         MAX(y.year) AS last_cobid_year
  FROM ftm f JOIN def_items di
    ON f.numerodaoc = di.numerodaoc AND f.\"códigoitem\" = di.\"códigoitem\"
  %s
  WHERE f.\"códigofornecedor\" <> '-1'
    AND f.\"códigofornecedor\" NOT IN (SELECT cnpj FROM defend)
  GROUP BY f.\"códigofornecedor\"", YEAR_JOIN)))
cases_per_cob <- setDT(dbGetQuery(con,
  "SELECT cnpj, COUNT(DISTINCT proc) n_cases,
          STRING_AGG(DISTINCT proc, ';') case_ids_broad
   FROM cobidder_case GROUP BY cnpj"))

# ---- firm-level frame: ALWAYS-LOSER candidate universe + defendants ----------
# Candidate universe for Target B: W_i = 0 firms (always-losers).
al_univ <- setDT(dbGetQuery(con, "
  SELECT l.\"códigofornecedor\" AS cnpj,
         l.total_participations AS T_i, l.total_wins AS W_i,
         l.win_rate, l.always_loser,
         fr.tenders_count
  FROM loss l LEFT JOIN freq fr ON fr.\"códigofornecedor\" = l.\"códigofornecedor\"
  WHERE l.always_loser = 1 AND l.\"códigofornecedor\" <> '-1'"))
n_AL_univ <- nrow(al_univ)
say("[universe] always-losers (W_i=0) = ", n_AL_univ, "  [manuscript 16,843]")

# first participation year per firm (rankable-incumbent flag, Target E)
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): year via ymap join, not substr.
first_year <- setDT(dbGetQuery(con, sprintf("
  SELECT f.\"códigofornecedor\" AS cnpj,
         MIN(y.year) AS first_participation_year
  FROM ftm f %s
  WHERE f.\"códigofornecedor\" <> '-1'
  GROUP BY f.\"códigofornecedor\"", YEAR_JOIN)))

# ---- assemble labels ---------------------------------------------------------
lab <- copy(al_univ)
lab[, FL14 := as.integer(!is.na(tenders_count) & tenders_count >= FL_CUT)]  # SCORE column, never a label input
lab[, direct_cade_defendant := 0L]                                          # defendants excluded from AL universe below
lab <- merge(lab, cob_contact, by = "cnpj", all.x = TRUE)
lab <- merge(lab, cases_per_cob, by = "cnpj", all.x = TRUE)
lab <- merge(lab, first_year, by = "cnpj", all.x = TRUE)
lab[, broad_cobidder := as.integer(!is.na(n_cobid_tender_items) & n_cobid_tender_items > 0)]
lab[, observed_defendant_contact := fifelse(is.na(n_cobid_tender_items), 0L, as.integer(n_cobid_tender_items))]

# Target C: narrow — NOT reproducible. NA columns + flag.
lab[, narrow_cobidder := NA_integer_]
lab[, conservative_narrow_cobidder := NA_integer_]

# Target D: conservative (same broad definition; cases judged <= 2020-12-31)
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): CONS_DATE-dependent step degrades
# gracefully when cfg$CONS_DATE is NA (federal: judgment dates not yet wired in).
# In that case there is no conservative subset: the flag is NA and counts are NA.
if (HAVE_CONS) {
  proc_dates <- unique(cart[!is.na(jdate), .(proc, jdate)])
  cons_procs <- proc_dates[jdate <= CONS_DATE, unique(proc)]
  cons_cob <- setDT(dbGetQuery(con, sprintf(
    "SELECT DISTINCT cnpj FROM cobidder_case WHERE proc IN (%s)",
    paste(sprintf("'%s'", cons_procs), collapse = ","))))
  lab[, conservative_broad_cobidder := as.integer(cnpj %in% cons_cob$cnpj & broad_cobidder == 1L)]
  cons_def_ftm <- dbGetQuery(con, sprintf(
    "SELECT DISTINCT cnpj FROM defend WHERE proc IN (%s) AND cnpj IN (SELECT DISTINCT \"códigofornecedor\" FROM ftm)",
    paste(sprintf("'%s'", cons_procs), collapse = ",")))
  cons_def_cross <- dbGetQuery(con, sprintf(
    "SELECT DISTINCT cnpj FROM defend WHERE proc IN (%s)",
    paste(sprintf("'%s'", cons_procs), collapse = ",")))
  n_cons_def      <- nrow(cons_def_cross)  # crossmatch level (pairs with 48; manuscript 19)
  n_cons_def_ftm  <- nrow(cons_def_ftm)    # BEC-active level (pairs with 41)
} else {
  say("[D] NOTE conservative benchmark SKIPPED: cfg$CONS_DATE is NA (",
      cfg$source, " has no wired-in judgment dates). conservative_* columns set NA.")
  cons_procs     <- character(0)
  lab[, conservative_broad_cobidder := NA_integer_]
  n_cons_def     <- NA_integer_
  n_cons_def_ftm <- NA_integer_
}

# Target E: timing fields
lab[, rankable_incumbent := as.integer(!is.na(first_participation_year) & first_participation_year <= RANK_CUT)]
lab[, timing_cobidder := as.integer(broad_cobidder == 1L & rankable_incumbent == 1L)]
# NOTE: labels are retrospective adjudication anchors; no claim of real-time legal knowledge.

# Target F: bid-feature common support (complete Imhof moments)
if (file.exists(f_imh)) {
  imh <- setDT(dbGetQuery(con, sprintf("
    SELECT firm_code AS cnpj FROM read_parquet('%s')
    WHERE imhof_cv_mean IS NOT NULL AND imhof_skew_mean IS NOT NULL
      AND imhof_kurt_mean IS NOT NULL AND imhof_spread_mean IS NOT NULL
      AND imhof_minmax_mean IS NOT NULL AND imhof_second_low_mean IS NOT NULL", f_imh)))
  lab[, bid_feature_support := as.integer(cnpj %in% imh$cnpj)]
  say("[F] bid-feature support joined from imhof_firm_features.parquet (", nrow(imh), " firms complete)")
} else {
  lab[, bid_feature_support := NA_integer_]
  say("[F] WARNING imhof_firm_features.parquet not found; bid_feature_support = NA")
}
# gatekeeping support: same-sample pool from scripts 63/64 (not derivable here)
lab[, gatekeeping_support := NA_integer_]

# static archived membership (internal comparison ONLY — never defines labels)
lab[, in_static_archived_193 := as.integer(cnpj %in% cobS$cnpj)]
lab[, target_source_flag := fifelse(broad_cobidder == 1L & in_static_archived_193 == 1L, "scripted_current+static_overlap",
                            fifelse(broad_cobidder == 1L, "scripted_current",
                            fifelse(in_static_archived_193 == 1L, "static_archived_only", "negative")))]
lab[, notes := fifelse(target_source_flag == "static_archived_only",
                       "in archived narrow file but NOT broad cobidder (narrow def not reproducible)", "")]

# defendant rows appended for completeness (flagged; excluded from candidate labels)
def_rows <- setDT(dbGetQuery(con, "
  SELECT l.\"códigofornecedor\" AS cnpj,
         l.total_participations AS T_i, l.total_wins AS W_i, l.win_rate, l.always_loser,
         fr.tenders_count
  FROM loss l LEFT JOIN freq fr ON fr.\"códigofornecedor\" = l.\"códigofornecedor\"
  WHERE l.\"códigofornecedor\" IN (SELECT cnpj FROM defend)"))
if (nrow(def_rows)) {
  def_rows[, FL14 := as.integer(!is.na(tenders_count) & tenders_count >= FL_CUT)]
  def_rows[, `:=`(direct_cade_defendant = 1L, broad_cobidder = 0L, narrow_cobidder = NA_integer_,
                  conservative_broad_cobidder = 0L, conservative_narrow_cobidder = NA_integer_,
                  timing_cobidder = 0L, bid_feature_support = NA_integer_, gatekeeping_support = NA_integer_,
                  n_cobid_tender_items = NA_integer_, first_cobid_year = NA_integer_, last_cobid_year = NA_integer_,
                  n_cases = NA_integer_, case_ids_broad = NA_character_,
                  first_participation_year = NA_integer_, rankable_incumbent = NA_integer_,
                  observed_defendant_contact = NA_integer_, in_static_archived_193 = 0L,
                  target_source_flag = "direct_defendant", notes = "Target A legal anchor; excluded from cobidder labels")]
  def_rows <- merge(def_rows, first_year, by = "cnpj", all.x = TRUE, suffixes = c("_drop", ""))
  if ("first_participation_year_drop" %in% names(def_rows)) def_rows[, first_participation_year_drop := NULL]
  lab_all <- rbindlist(list(lab, def_rows), use.names = TRUE, fill = TRUE)
} else lab_all <- lab

# ---- counts ------------------------------------------------------------------
n_B      <- lab[broad_cobidder == 1L, .N]
n_B_FL   <- lab[broad_cobidder == 1L & FL14 == 1L, .N]
n_B_nFL  <- lab[broad_cobidder == 1L & FL14 == 0L, .N]
n_D      <- lab[conservative_broad_cobidder == 1L, .N]
n_E      <- lab[timing_cobidder == 1L, .N]
n_E_unrk <- lab[broad_cobidder == 1L & rankable_incumbent == 0L, .N]
n_F      <- lab[broad_cobidder == 1L & bid_feature_support == 1L, .N]
n_FL_univ<- lab[FL14 == 1L, .N]
say("[B] broad AL cobidders (MAIN) = ", n_B, "  (FL=", n_B_FL, " non-FL=", n_B_nFL, ")")
say("[D] conservative broad AL cobidders = ", n_D, " ; conservative BEC-active defendants = ", n_cons_def)
say("[E] timing (rankable-incumbent) cobidders = ", n_E, " ; unrankable-entrant positives = ", n_E_unrk)
say("[F] bid-feature-support cobidders = ", n_F)

cnt <- rbindlist(list(
  list("A_direct_defendants_bec_active", n_def_ftm, "unique firms", "legal anchors; excluded from cobidder labels"),
  list("A_direct_defendants_crossmatch", n_def_cross, "unique firms", "all crossmatch CNPJ (incl. non-ftm-active)"),
  list("B_broad_AL_cobidders_MAIN", n_B, "unique firms", "MAIN validation target; FL never used"),
  list("B_composition_FL", n_B_FL, "unique firms", "descriptive composition of positives"),
  list("B_composition_nonFL", n_B_nFL, "unique firms", "descriptive composition of positives"),
  list("C_narrow_cobidders", NA_integer_, "unique firms", "NOT REPRODUCIBLE (archived builder); cannot be a target"),
  list("D_conservative_broad_AL_cobidders", n_D, "unique firms", "same broad def, cases judged <= 2020-12-31"),
  list("D_conservative_defendants_crossmatch", n_cons_def, "unique firms", "crossmatch defendants in conservative cases (pairs with 48)"),
  list("D_conservative_defendants_bec_active", n_cons_def_ftm, "unique firms", "BEC-active defendants in conservative cases (pairs with 41)"),
  list("E_timing_rankable_cobidders", n_E, "unique firms", "broad cobidder & first participation <= 2016"),
  list("E_unrankable_entrant_positives", n_E_unrk, "unique firms", "broad cobidder, no pre-2017 history"),
  list("F_bid_feature_support_cobidders", n_F, "unique firms", "broad cobidder & complete Imhof moments"),
  list("universe_always_losers", n_AL_univ, "unique firms", "candidate pool (W_i = 0)"),
  list("universe_FL14", n_FL_univ, "unique firms", "score stratum (NOT a label)"),
  list("defendant_tender_items", n_def_item_ti, "tender-items", "exposure anchor set"),
  list("static_archived_file_rows", nrow(cobS), "rows", "internal comparison only; never defines labels"),
  list("conservative_cases", length(cons_procs), "cases", "judged <= 2020-12-31"),
  list("cade_cases", uniqueN(cart$proc), "cases", "full portfolio")
))
setnames(cnt, c("target", "count", "unit", "note"))
fwrite(cnt, file.path(D_TGT, "canonical_target_counts.csv"))
say("[write] canonical_target_counts.csv")

# ---- case-level labels --------------------------------------------------------
def_per_case <- setDT(dbGetQuery(con, "
  SELECT proc, COUNT(DISTINCT cnpj) n_def
  FROM defend WHERE cnpj IN (SELECT DISTINCT \"códigofornecedor\" FROM ftm) GROUP BY proc"))
items_per_case <- setDT(dbGetQuery(con, "
  SELECT proc, COUNT(DISTINCT (numerodaoc||'|'||\"códigoitem\")) n_items FROM def_items GROUP BY proc"))
cob_case <- merge(setDT(dbGetQuery(con, "SELECT cnpj, proc FROM cobidder_case")),
                  lab[, .(cnpj, broad_cobidder, FL14)], by = "cnpj", all.x = TRUE)
cob_case_agg <- cob_case[broad_cobidder == 1L,
  .(n_AL_cobidders = uniqueN(cnpj), n_FL_among = uniqueN(cnpj[FL14 == 1L])), by = proc]
case_lab <- merge(unique(cart[, .(proc, setor, jdate)]), def_per_case, by = "proc", all.x = TRUE)
case_lab <- merge(case_lab, items_per_case, by = "proc", all.x = TRUE)
case_lab <- merge(case_lab, cob_case_agg, by = "proc", all.x = TRUE)
for (cc in c("n_def","n_items","n_AL_cobidders","n_FL_among")) case_lab[is.na(get(cc)), (cc) := 0L]
case_lab[, conservative := as.integer(proc %in% cons_procs)]
setorder(case_lab, jdate, na.last = TRUE)
case_lab[, case_id := paste0("Case ", LETTERS[seq_len(.N)])]
fwrite(case_lab[, .(case_id, sector = setor, process_number = proc,
                    judgment_date = as.character(jdate), conservative,
                    n_bec_active_defendants = n_def, n_defendant_tender_items = n_items,
                    n_AL_cobidders, n_FL_among)],
       file.path(D_TGT, "canonical_case_labels.csv"))
say("[write] canonical_case_labels.csv (", nrow(case_lab), " cases)")

# ---- firm labels CSV (hashed) + raw-key cache for downstream scripts ----------
have_digest <- requireNamespace("digest", quietly = TRUE)
if (have_digest) {
  lab_all[, firm_id := vapply(cnpj, function(x) substr(digest::digest(x, algo = "sha1"), 1, 10), character(1))]
} else {
  setorder(lab_all, cnpj)
  lab_all[, firm_id := sprintf("id%06d", .I)]
}
pub_cols <- c("firm_id","T_i","W_i","always_loser","FL14","direct_cade_defendant",
              "broad_cobidder","narrow_cobidder","conservative_broad_cobidder",
              "conservative_narrow_cobidder","timing_cobidder","rankable_incumbent",
              "bid_feature_support","gatekeeping_support","case_ids_broad",
              "first_cobid_year","last_cobid_year","first_participation_year",
              "observed_defendant_contact","in_static_archived_193","target_source_flag","notes")
pub <- lab_all[, ..pub_cols]
setnames(pub, "firm_id", "canonical_cnpj_or_hashed_id")
pub[, firm_id := canonical_cnpj_or_hashed_id]
setcolorder(pub, c("firm_id","canonical_cnpj_or_hashed_id"))
fwrite(pub, file.path(D_TGT, "canonical_firm_labels.csv"))
say("[write] canonical_firm_labels.csv (", nrow(pub), " rows, hashed ids)")

# raw-key cache for downstream scripts (NOT for the public replication package)
fwrite(lab_all[, .(`códigofornecedor` = cnpj, broad_cobidder, conservative_broad_cobidder,
                   timing_cobidder, rankable_incumbent, bid_feature_support,
                   direct_cade_defendant, FL14_score = FL14, T_i, W_i,
                   first_cobid_year, last_cobid_year, first_participation_year)],
       file.path(D_CACH, "canonical_cobidders_broad.csv"))
say("[write] outputs/cache/canonical_cobidders_broad.csv (raw keys, downstream joins)")

# ---- set comparisons (internal; archived file ONLY here) -----------------------
set_static <- unique(cobS$cnpj)
set_B      <- lab[broad_cobidder == 1L, cnpj]
set_D      <- lab[conservative_broad_cobidder == 1L, cnpj]
mk <- function(nmA, nmB, a, b, code, note)
  list(pair = paste0(nmA, "_vs_", nmB), set_A = nmA, set_B = nmB,
       size_A = length(a), size_B = length(b),
       intersection = length(intersect(a, b)),
       A_minus_B = length(setdiff(a, b)), B_minus_A = length(setdiff(b, a)),
       explanation_code = code, note = note)
cmp <- rbindlist(list(
  mk("broad_AL_main", "static_archived_193", set_B, set_static,
     "ARCHIVED_INTERNAL_COMPARISON",
     "Archived narrow FL-only file vs reproducible broad AL main target; archived file never defines submitted labels."),
  mk("conservative_broad_AL", "broad_AL_main", set_D, set_B,
     "SUBSET_SAME_DEF",
     "Conservative benchmark uses the SAME broad AL definition; strict subset expected."),
  mk("timing_rankable", "broad_AL_main", lab[timing_cobidder == 1L, cnpj], set_B,
     "SUBSET_SAME_DEF",
     "Timing target = main target restricted to rankable incumbents (pre-2017 history).")
))
fwrite(cmp, file.path(D_DIAG, "target_set_comparisons.csv"))
say("[write] target_set_comparisons.csv")

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): DECISION D-i federal rebuild check.
# This script REBUILDS the federal cobidder set with its OWN canonical co-participation
# logic (defendants anchored at 14-digit ESTAB CNPJ = direct_defendants_federal$firm_id,
# MIRRORING the BEC convention exactly: BEC `defend` = pad14(fornecedor), joined on
# f."códigofornecedor" = d.cnpj which is 14-digit estab in firm_tender_map).
# We do NOT silently adopt the pre-existing cobidders_federal.parquet (v3) definition;
# instead we emit a counts-only set-comparison of OUR rebuild (set_B broad-AL + all
# broad cobidders) vs the v3 file, logged to diagnostics.
# VERIFIED DELTA (2026-06-05): v3 = 4,164 all / 222 AL was built over ALL 27 defendant
# estabs, INCLUDING the 2 estabs whose processo is empty (the tecnologia_informacao/DF
# group that gate G3 excludes from case-anchored analysis). Our rebuild drops that
# empty-processo group (see cross filter above) -> 3,851 all / 196 broad-AL. The
# difference is exactly those 2 defendants' co-participations, NOT an anchoring-grain
# (estab vs raiz) difference: both v3 and the rebuild anchor at 14-digit estab.
if (cfg$cade_layout == "federal_parquet_v3") {
  v3 <- as.data.table(arrow::read_parquet(cfg$cade$cobidders))
  v3[, cnpj := pad14(firm_id)]
  set_v3_all <- unique(v3$cnpj)                                  # full v3 cobidder set
  set_v3_al  <- if ("always_loser" %in% names(v3))
                  unique(v3[always_loser == 1L, cnpj]) else character(0)  # v3 AL subset
  # our rebuild: all broad cobidders (any AL/non-AL sharing a tender-item) and the
  # broad-AL main target (set_B). Recompute the "all cobidders" set independently.
  set_rebuild_all <- dbGetQuery(con, "SELECT DISTINCT cnpj FROM cobidder_case")$cnpj
  set_rebuild_al  <- set_B
  di <- rbindlist(list(
    mk("rebuild_all_cobidders_estab", "v3_cobidders_federal_all",
       set_rebuild_all, set_v3_all, "D_I_REBUILD_VS_V3",
       "Estab-anchored rebuild (this script) vs existing cobidders_federal.parquet (all rows)."),
    mk("rebuild_broad_AL_main_estab", "v3_cobidders_federal_AL",
       set_rebuild_al, set_v3_al, "D_I_REBUILD_VS_V3",
       "Estab-anchored broad-AL main target (this script) vs v3 always_loser==1 subset.")
  ))
  fwrite(di, file.path(D_DIAG, "federal_cobidder_rebuild_vs_v3.csv"))
  say("[D-i] rebuild(all)=", length(set_rebuild_all), " v3(all)=", length(set_v3_all),
      " INT=", length(intersect(set_rebuild_all, set_v3_all)),
      " | rebuild(AL)=", length(set_rebuild_al), " v3(AL)=", length(set_v3_al),
      " INT=", length(intersect(set_rebuild_al, set_v3_al)))
  say("[write] federal_cobidder_rebuild_vs_v3.csv")
}

# ---- assertions (prompt spec 1-10) --------------------------------------------
asrt <- list()
add <- function(id, desc, res, obs, exp, act)
  asrt[[length(asrt) + 1]] <<- list(check_id = id, check_description = desc, result = res,
    observed = as.character(obs), expected = as.character(exp), action = act)

def_in_B <- length(intersect(unique(cross$cnpj), set_B))
add("T1", "Direct CADE defendants excluded from cobidder candidate labels",
    ifelse(def_in_B == 0, "pass", "fail"), def_in_B, 0, ifelse(def_in_B == 0, "none", "exclude"))
bad_W <- lab[broad_cobidder == 1L & (W_i != 0 | always_loser != 1), .N]
add("T2", "All cobidders satisfy W_i = 0 (always-loser)",
    ifelse(bad_W == 0, "pass", "fail"), bad_W, 0, ifelse(bad_W == 0, "none", "fix universe"))
add("T3", "FL14 not used in positive-label construction (structural: label = ftm join only)",
    "pass", "label built from tender-item joins; FL14 only a column", "structural",
    "verified by construction: broad_cobidder derives only from def_items x ftm")
add("T4", "Positives include both FL and non-FL firms (else CIRCULARITY_RISK)",
    ifelse(n_B_FL > 0 & n_B_nFL > 0, "pass", "CIRCULARITY_RISK"),
    sprintf("FL=%d nonFL=%d", n_B_FL, n_B_nFL), "both > 0",
    ifelse(n_B_FL > 0 & n_B_nFL > 0, "none", "investigate label"))
n_pairs <- nrow(unique(cob_case[, .(cnpj, proc)]))
add("T5", "Unique-firm counts separated from firm-case / firm-tender counts",
    "pass", sprintf("firms=%d firm-case pairs=%d tender-items=%d", n_B, n_pairs, n_def_item_ti),
    "distinct units stated", "always state counting unit")
add("T6", "Conservative compared only under same definition as main",
    ifelse(n_D <= n_B, "pass", "fail"), sprintf("%d <= %d", n_D, n_B), "subset",
    ifelse(n_D <= n_B, "none", "investigate"))
add("T7", "Static archived file NOT used to define final main labels",
    "pass", "archived file read only into in_static_archived_193 / set comparisons", "structural",
    "verified by construction")
add("T8", "Old archived target counts used only for internal comparison",
    "pass", sprintf("archived rows=%d; appears only in diagnostics", nrow(cobS)), "internal only", "none")
miss_cnpj <- lab[is.na(cnpj) | cnpj == "", .N]
add("T9", "Missing CNPJ / tender-item IDs reported",
    ifelse(miss_cnpj == 0 & miss_ti == 0, "pass", "warning"),
    sprintf("missing CNPJ=%d missing tender-item keys=%d crossmatch dropped=%d", miss_cnpj, miss_ti, n_cross_dropped),
    "0 (drops disclosed)", "disclosed")
# determinism: recompute broad set via independent second query path and compare
set_B2 <- setDT(dbGetQuery(con, "
  SELECT DISTINCT c.cnpj FROM cobidder_case c
  JOIN loss l ON l.\"códigofornecedor\" = c.cnpj
  WHERE l.always_loser = 1"))$cnpj
det_ok <- identical(sort(set_B), sort(set_B2))
add("T10", "Target counts deterministic (two independent construction paths agree)",
    ifelse(det_ok, "pass", "fail"), sprintf("path1=%d path2=%d identical=%s", length(set_B), length(set_B2), det_ok),
    "identical sets", ifelse(det_ok, "none", "investigate non-determinism"))

asrtDT <- rbindlist(asrt)
fwrite(asrtDT, file.path(D_DIAG, "target_construction_assertions.csv"))
say("[write] target_construction_assertions.csv")
say("[assert] ", paste(sprintf("%s=%s", asrtDT$check_id, asrtDT$result), collapse = " "))

# ---- macro snippet -------------------------------------------------------------
mac <- c(
  "% Auto-generated by work/v22-editor/scripts/analysis/00_build_canonical_validation_targets.R",
  "% Canonical reproducible target macros (JLEO final optimization). Bind in values.tex.",
  sprintf("\\newcommand{\\valMainCobidders}{%d}        %% src: canonical_target_counts.csv B_broad_AL_cobidders_MAIN", n_B),
  sprintf("\\newcommand{\\valMainCobFL}{%d}            %% src: composition FL among positives (descriptive)", n_B_FL),
  sprintf("\\newcommand{\\valMainCobNonFL}{%d}         %% src: composition non-FL among positives (descriptive)", n_B_nFL),
  sprintf("\\newcommand{\\valMainConsCobidders}{%d}    %% src: conservative broad AL cobidders (same def)", n_D),
  sprintf("\\newcommand{\\valMainConsFD}{%d}           %% src: conservative BEC-active defendants", n_cons_def),
  sprintf("\\newcommand{\\valMainTimingCobidders}{%d}  %% src: rankable-incumbent cobidders", n_E),
  sprintf("\\newcommand{\\valMainEntrantPositives}{%d} %% src: unrankable entrant positives", n_E_unrk),
  sprintf("\\newcommand{\\valMainBidSupportCob}{%d}    %% src: bid-feature-support cobidders", n_F))
writeLines(mac, file.path(D_DIAG, "canonical_target_macros.tex"))
say("[write] canonical_target_macros.tex")

dbDisconnect(con, shutdown = TRUE)
say("[done] elapsed=", round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
    "s  RSS=", rss_mb(), "MB")
cat("\nDONE. Canonical targets under", D_TGT, "\n")
