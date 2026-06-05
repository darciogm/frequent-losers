#!/usr/bin/env Rscript
# =============================================================================
# 02_opportunity_adjusted_validation.R  --  JLEO R&R (v22)
#
# THE make-or-break test: does the frequent-loser ranking carry signal BEYOND
# mechanical opportunity exposure to CADE-defendant procurement environments?
#
# Generalizes the VALIDATED reference scripts/76_exposure_adjusted_audit.R
# (within-opportunity-decile AUC 0.7715; +0.0415 over exposure-only,
# DeLong p=2.08e-06; exposure-only ALONE 0.946) across opportunity-cell
# granularities, with control-function / permutation / matched designs and the
# full triage metric suite. Honest framing locked: exposure alone reproduces the
# label very well (0.946); the score adds a SMALL but SIGNIFICANT residual
# (+0.04, within-stratum 0.77). Report attenuation honestly; do NOT overclaim.
#
# Steps (A-J per Subprompt brief):
#   A  candidate set (always-losers, cobidder_i = canonical broad AL cobidder label, 651, reproducible, FL never used)
#   B  observed defendant contact O_i (DuckDB self-join)
#   C  opportunity cells (COARSE / MEDIUM / STRICT)  -> Table D-construction
#   D  expected contact E_i, excess X_i, standardized Z_i
#   E  common support (3 rules)
#   F  control-function validation -> Table C (9 designs) + full appendix
#   G  observed-vs-expected by score bins -> table + figures
#   H  cell-preserving permutation -> Table D-perm (Approaches B + C)
#   I  matched/stratified -> Table D-matched
#   J  case/buyer/item-group contribution
#
# Run:
#   cd <repo>; Rscript work/v22-editor/scripts/analysis/02_opportunity_adjusted_validation.R \
#     2>&1 | tee work/v22-editor/outputs/logs/opportunity_validation.log
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow)
  library(pROC); library(MatchIt); library(splines); library(ggplot2)
})

# ---- locate repo + dirs -----------------------------------------------------
if (!exists(".script_dir")) {
  fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
  .script_dir <- if (length(fa)) dirname(normalizePath(fa[1L])) else getwd()
}
# repo root: .../paper3-frequent-losers (script lives at work/v22-editor/scripts/analysis/)
REPO <- normalizePath(file.path(.script_dir, "..", "..", "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(REPO, "data", "processed")))
  REPO <- normalizePath("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
V22  <- file.path(REPO, "work", "v22-editor")
UTIL <- file.path(V22, "scripts", "utils")

# --- SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05) -------------------------
# Parse --source= (default "bec") and pull ALL data paths, key lambdas, output
# dirs and spill dir from get_source_config(). BEC fields equal the prior
# literals byte-for-byte (DATA=data/processed, OUT=outputs, /tmp/duckdb_spill).
.args <- commandArgs(trailingOnly = TRUE)
.src  <- sub("^--source=", "", .args[grep("^--source=", .args)])
SRC   <- if (length(.src)) .src[1L] else "bec"
source(file.path(UTIL, "source_config.R"))
cfg  <- get_source_config(SRC)
cfg$ensure_dirs()
DATA <- cfg$data_dir
OUT  <- cfg$out_root

source(file.path(UTIL, "metrics_triage.R"))
source(file.path(UTIL, "exposure_validation.R"))

dir_main_t <- cfg$dirs$tables_main
dir_app_t  <- cfg$dirs$tables_app
dir_main_f <- cfg$dirs$figures_main
dir_app_f  <- cfg$dirs$figures_app
dir_diag   <- cfg$dirs$diagnostics
dir_cache  <- cfg$dirs$cache
dir_log    <- cfg$dirs$logs
SPILL      <- cfg$temp_directory
for (d in c(dir_main_t,dir_app_t,dir_main_f,dir_app_f,dir_diag,dir_cache,dir_log))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
dir.create(SPILL, recursive = TRUE, showWarnings = FALSE)

# --- SOURCE-CONFIG ADAPTATION (Phase 1): SQL key-expression helpers ----------
# buyer / year / item-group as DuckDB SQL fragments over a numerodaoc/codigoitem
# alias. BEC: buyer & year are substrings of numerodaoc (cfg$*_from_key). FED:
# numerodaoc carries neither -> buyer comes from a panel join (cfg$buyer_col,
# resolved per-query) and year from cfg$get_year_map(); the substring lambdas
# are NULL federally and MUST NOT be called.
sql_buyer_key <- function(noc_alias) {
  if (!is.null(cfg$buyer_from_key)) cfg$buyer_from_key(noc_alias)
  else stop("buyer is not a substring for source ", SRC, " -- join the item panel on (numerodaoc,codigoitem) for cfg$buyer_col.")
}
sql_year_key <- function(noc_alias) {
  if (!is.null(cfg$year_from_key)) cfg$year_from_key(noc_alias)
  else stop("year must come from cfg$get_year_map() for source ", SRC, " -- never string-extract.")
}
# SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): item-group observability.
# BEC: SUBSTR(codigoitem,1,2) IS a genuine product-group prefix (cfg$has_item_group
# TRUE; 91 distinct groups; cfg$ig_from_key supplies the SUBSTR). FED: the 2-digit
# prefix of the 22-char composite codigoitem == SUBSTR(codigo_ug,1,2) on the diagonal
# (buyer-collinear), so item-group is NOT_OBSERVED (cfg$has_item_group FALSE;
# cfg$ig_from_key NULL). LEAD DECISION: when item-group is not observed we set ig to a
# CONSTANT sentinel '__NA__'. This makes the ig axis vacuous in cell keys, so COARSE
# (ig,year) collapses to (year) and MEDIUM (ig,year,pbu) collapses to (year,pbu)
# federally -- the cell-definition difference made VISIBLE in output metadata below.
IG_NA_SENTINEL <- "__NA__"
HAS_IG <- isTRUE(cfg$has_item_group)
sql_ig_key <- function(item_alias) {
  if (HAS_IG && !is.null(cfg$ig_from_key)) cfg$ig_from_key(item_alias)
  else sprintf("'%s'", IG_NA_SENTINEL)   # NOT_OBSERVED: constant -> ig axis drops out
}
# Per-granularity ACTUAL cell key (ig collapsed out when not observed), for metadata.
ig_note <- if (HAS_IG) "" else
  "item-group NOT_OBSERVED on this platform (buyer-collinear composite item code)"
cell_keys_effective <- function(keys) {
  if (HAS_IG) keys else setdiff(keys, "ig")   # drop the vacuous ig axis federally
}
IS_BEC <- identical(SRC, "bec")

setDTthreads(12L)
SEED <- 20260603L
set.seed(SEED)

# ---- telemetry --------------------------------------------------------------
LOG <- file.path(dir_diag, "opportunity_validation_audit_log.txt")
.t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern=TRUE))/1024), error=function(e) NA_real_)
stamp <- function(s) say("  [stage %-26s] elapsed=%6.1fs  RSS=%s MB", s, as.numeric(difftime(Sys.time(),.t0,units="secs")), rss_mb())
`%||%` <- function(x,y) if (is.null(x)||length(x)==0||is.na(x)) y else x

say("=== 02_opportunity_adjusted_validation.R ===")
say("host=%s  nproc=%s  seed=%d  date=%s  RAM_free=%s",
    Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern=TRUE), error=function(e)"?"), SEED, format(Sys.time()),
    tryCatch(system("free -h | awk 'NR==2{print $7}'", intern=TRUE), error=function(e)"?"))
say("REPO=%s", REPO)
say("SOURCE=%s  (%s)  DATA=%s  OUT=%s  SPILL=%s", SRC, cfg$label, DATA, OUT, SPILL)  # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05)

norm14 <- function(x) sprintf("%014.0f", as.numeric(x))

# --- SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): keyed-FTM view builder ---
# Emits the SQL for a CTE/view `ftm_keyed(firm_code, oc, item, pbu, year, ig,
# item_code)` from the source firm_tender_map. This is THE single place where
# the G1 buyer/year semantics diverge; every cell/opportunity query below reads
# `ftm_keyed`, so COARSE/MEDIUM/STRICT construction stays construction-identical
# across platforms.
#   BEC : pbu = SUBSTR(numerodaoc,1,11), year = SUBSTR(numerodaoc,12,4)  (literals preserved).
#   FED : numerodaoc carries neither; buyer (codigo_ug) and result-year come from
#         a (numerodaoc,codigoitem) key map registered as DuckDB table `keymap`
#         (built once from cfg$item_panel via cfg$get_year_map + cfg$buyer_col,
#         after cfg$drop_multi_ug_pairs to drop the multi-UASG pairs). LEFT JOIN
#         so FTM rows with no panel match still appear (pbu/year NULL -> '' / '0000').
ftm_path <- cfg$firm_tender_map
.keymap_registered <- FALSE
register_keymap <- function(con) {
  # FED-only: build & register the (numerodaoc, codigoitem) -> (codigo_ug, year)
  # lookup, excluding multi-UASG pairs, exactly once per connection.
  if (IS_BEC) return(invisible(NULL))
  view <- cfg$drop_multi_ug_pairs(con)   # registers panel_single_ug (drops multi-UASG pairs)
  ymap <- cfg$get_year_map(con)          # (numerodaoc, codigoitem, year)
  km <- DBI::dbGetQuery(con, sprintf("
    SELECT CAST(numerodaoc AS VARCHAR) AS numerodaoc,
           CAST(\"códigoitem\" AS VARCHAR) AS \"códigoitem\",
           CAST(MAX(%s) AS VARCHAR) AS buyer
    FROM %s GROUP BY 1,2", cfg$buyer_col, view))
  km <- merge(km, ymap, by = c("numerodaoc", "códigoitem"), all = TRUE)
  DBI::dbWriteTable(con, "keymap", km, overwrite = TRUE)
  .keymap_registered <<- TRUE
  invisible(km)
}
# SQL for the keyed FTM view. `con` must already have keymap registered (FED).
ftm_keyed_sql <- function() {
  if (IS_BEC) {
    sprintf("
      SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
             CAST(\"numerodaoc\" AS VARCHAR) AS oc,
             CAST(\"códigoitem\" AS VARCHAR) AS item,
             %s AS pbu,
             %s AS year,
             %s AS ig,
             CAST(\"códigoitem\" AS VARCHAR) AS item_code
      FROM read_parquet('%s')",
      sql_buyer_key("CAST(\"numerodaoc\" AS VARCHAR)"),
      sql_year_key("CAST(\"numerodaoc\" AS VARCHAR)"),
      sql_ig_key("CAST(\"códigoitem\" AS VARCHAR)"),
      ftm_path)
  } else {
    # FED: join keymap for buyer (codigo_ug) + result year; ig from codigoitem.
    sprintf("
      SELECT f.firm_code, f.oc, f.item,
             COALESCE(k.buyer, '') AS pbu,
             COALESCE(CAST(k.year AS VARCHAR), '0000') AS year,
             %s AS ig,
             f.item AS item_code
      FROM (
        SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
               CAST(\"numerodaoc\" AS VARCHAR) AS oc,
               CAST(\"códigoitem\" AS VARCHAR) AS item
        FROM read_parquet('%s')
      ) f
      LEFT JOIN keymap k ON f.oc = k.numerodaoc AND f.item = k.\"códigoitem\"",
      sql_ig_key("f.item"), ftm_path)
  }
}

# pROC AUC + DeLong wrappers (CI); also use metrics_triage roc_auc for triage grid
auc_ci <- function(label, score, dat) {
  r <- pROC::roc(dat[[label]], dat[[score]], quiet=TRUE, direction="<")
  ci <- pROC::ci.auc(r)
  list(auc=as.numeric(r$auc), lo=ci[1], hi=ci[3], n=nrow(dat), npos=sum(dat[[label]]==1), roc=r)
}
# pooled within-stratum C-statistic (mirror 76 strat_auc)
strat_auc <- function(dat, score, label, stratum) {
  num <- 0; den <- 0
  for (s in unique(dat[[stratum]])) {
    sub <- dat[dat[[stratum]]==s]
    p <- sub[[score]][sub[[label]]==1]; n <- sub[[score]][sub[[label]]==0]
    if (!length(p) || !length(n)) next
    cmp <- outer(p, n, function(a,b) (a>b)+0.5*(a==b))
    num <- num + sum(cmp); den <- den + length(p)*length(n)
  }
  list(auc = if (den>0) num/den else NA_real_, comparable_pairs = den)
}

# =============================================================================
# A. CANDIDATE SET
# =============================================================================
say("\n----- A. candidate set -----")
# POSITIVE LABEL: canonical broad AL cobidder label (651, reproducible, FL never used).
# `códigofornecedor` is the raw BEC firm code (14-char zero-padded), the same join key
# produced by norm14() on FREQ_PARTICIP / firm_loss_stats / firm_tender_map.
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): canonical cobidder rebuild is
# produced by script 00 into the SOURCE cache (BEC outputs/cache ; FED
# outputs/comprasnet/cache). Read it from cfg$dirs$cache so the federal run
# consumes the federal rebuild, never the BEC artifact.
CANON_COB <- file.path(dir_cache, "canonical_cobidders_broad.csv")
cob <- fread(CANON_COB)
cob[, firm_code := norm14(`códigofornecedor`)]
cob_codes <- unique(cob[broad_cobidder == 1L, firm_code])
say("cobidder positives (canonical broad AL label): %d distinct firm_code", length(cob_codes))

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): direct CADE defendants.
# BEC: cade_bec_crossmatch.csv (firm_cnpj, processo, cade_name, is_always_loser,
#   win_rate). FED (cfg$cade_layout=="federal_parquet_v3"): direct_defendants_federal
#   parquet (firm_id=14-char CNPJ, processo, razao_cade, always_loser, win_rate).
#   Harmonize to the same column set the assertion/case-map code below expects:
#   firm_cnpj, processo, cade_name, is_always_loser, win_rate.
if (cfg$cade_layout == "bec_csv") {
  xm <- fread(cfg$cade$crossmatch)
  xm[, firm_code := norm14(firm_cnpj)]
} else {
  dd <- as.data.table(read_parquet(cfg$cade$direct_defendants))
  xm <- dd[, .(firm_cnpj = firm_id, processo,
               cade_name = razao_cade,
               is_always_loser = as.integer(always_loser),
               win_rate = win_rate)]
  xm[, firm_code := norm14(firm_cnpj)]
}
direct_codes_raw <- unique(xm$firm_code)
say("direct CADE defendants (crossmatch, raw): %d distinct firm_code", length(direct_codes_raw))

# ASSERT: direct defendants must NOT be cobidder positives (defendants = winners).
overlap <- intersect(direct_codes_raw, cob_codes)
say("ASSERT no overlap defendants vs cobidders: overlap=%d  {%s}",
    length(overlap), paste(overlap, collapse=","))
if (length(overlap)) {
  ov_rows <- xm[firm_code %in% overlap, .(firm_code, processo, cade_name, is_always_loser, win_rate)]
  for (i in seq_len(nrow(ov_rows)))
    say("  OVERLAP firm %s: case=%s name=%s always_loser=%s win_rate=%s -- always-loser flagged as direct defendant; EXCLUDED from defendant set (cannot be its own defendant-contact)",
        ov_rows$firm_code[i], ov_rows$processo[i], ov_rows$cade_name[i],
        ov_rows$is_always_loser[i], ov_rows$win_rate[i])
}
# Keep defendant set = winners only (drop the always-loser overlap firm). This
# does not change cells materially but makes the assertion clean and prevents
# self-contact. Report both; primary uses cleaned set.
direct_codes <- setdiff(direct_codes_raw, cob_codes)
say("direct defendants used (cleaned, winners only): %d", length(direct_codes))

# case linkage: firm_code -> processo (a defendant may map to >=1 case)
xm_clean <- xm[firm_code %in% direct_codes]
def_case_map <- unique(xm_clean[, .(firm_code, processo)])
say("direct-defendant -> case rows: %d ; distinct cases: %d",
    nrow(def_case_map), uniqueN(def_case_map$processo))

# always-loser panel
fp <- as.data.table(read_parquet(cfg$freq_particip))  # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05)
fp[, firm_code := norm14(`códigofornecedor`)]
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, cobidder := as.integer(firm_code %in% cob_codes)]
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): FL cut from cfg (BEC 14 ; FED 32).
# Variable name `fl14` retained as the deployable-screen identifier used throughout;
# only the threshold is source-driven. cfg$fl_predicate applies FL_CUT + convention.
al[, fl14     := as.integer(cfg$fl_predicate(tenders_count))]
al[, W_i      := 0L]                       # always-loser: zero wins by construction
al[, score_i  := log1p(tenders_count)]     # = log_tc
setnames(al, "tenders_count", "T_i")
# deterministic anonymized firm_id on sorted CNPJ (NEVER export raw CNPJ in per-firm files)
setorder(al, firm_code)
al[, firm_id := .I]
say("always-losers: %d ; cobidders in universe: %d ; FL14: %d",
    nrow(al), al[cobidder==1,.N], al[fl14==1,.N])
.n_cob_not_al <- sum(!cob_codes %in% al$firm_code)
say("ASSERT cobidders in always-loser universe: %d of %d in AL (%d cobidder codes not AL -> excluded from npos)",
    length(cob_codes) - .n_cob_not_al, length(cob_codes), .n_cob_not_al)
stamp("A_candidate_set")

# =============================================================================
# B. OBSERVED DEFENDANT CONTACT O_i  (DuckDB self-join, the 16.8M-row peak)
# =============================================================================
say("\n----- B. observed defendant contact O_i (DuckDB self-join) -----")
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): ftm_path defined above from cfg;
# spill dir from cfg$temp_directory (FED: outputs/comprasnet/cache/duckdb_spill).
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", SPILL))
register_keymap(con)   # FED-only: (numerodaoc,codigoitem)->(codigo_ug,year) lookup; no-op for BEC
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)

# defendant-bearing tender-items (oc|item where any direct defendant appears),
# carrying defendant identity + case via crossmatch for case-contribution later.
dbWriteTable(con, "def_case",
             as.data.frame(def_case_map[, .(firm_code, processo)]), overwrite = TRUE)

# O_i = # distinct tender-items where firm i AND >=1 direct defendant both appear.
# Build defendant tender-items first, then join to all firm participations.
contact <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc,
           CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')
  ),
  def_items AS (                       -- tender-items containing a direct defendant
    SELECT DISTINCT f.oc, f.item, f.firm_code AS def_code
    FROM ftm f JOIN direct d ON f.firm_code = d.firm_code
  ),
  -- firm i contacts: distinct (oc,item) shared with a defendant (i != defendant)
  firm_contact AS (
    SELECT f.firm_code,
           f.oc, f.item,
           di.def_code
    FROM ftm f
    JOIN def_items di ON f.oc = di.oc AND f.item = di.item
    WHERE f.firm_code <> di.def_code
  )
  SELECT firm_code,
         COUNT(DISTINCT (oc || '|' || item))     AS O_i,
         COUNT(DISTINCT def_code)                 AS n_def_firms,
         COUNT(*)                                 AS n_contact_pairs
  FROM firm_contact
  GROUP BY firm_code
", ftm_path)))
say("firms with O_i>0 (any defendant contact): %s", format(nrow(contact), big.mark=","))

# distinct CADE cases encountered per firm (via def_code -> processo)
firm_case <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')
  ),
  def_items AS (
    SELECT DISTINCT f.oc, f.item, f.firm_code AS def_code
    FROM ftm f JOIN direct d ON f.firm_code = d.firm_code
  ),
  firm_contact AS (
    SELECT f.firm_code, f.oc, f.item, di.def_code
    FROM ftm f JOIN def_items di ON f.oc=di.oc AND f.item=di.item
    WHERE f.firm_code <> di.def_code
  ),
  firm_contact_case AS (
    SELECT fc.firm_code, dc.processo, fc.oc, fc.item
    FROM firm_contact fc JOIN def_case dc ON fc.def_code = dc.firm_code
  )
  SELECT firm_code,
         COUNT(DISTINCT processo)                 AS n_cases,
         COUNT(DISTINCT (oc||'|'||item))          AS contact_items_cased
  FROM firm_contact_case
  GROUP BY firm_code
", ftm_path)))

# per-firm total participation (T_i sanity / breadth) from FTM
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): n_buyers/n_years derive from the
# keyed view (BEC substrings ; FED panel-joined codigo_ug + result year), NOT raw
# numerodaoc substrings -- which are INVALID federally (9-char key, year=numbering
# year). n_item_groups = SUBSTR(codigoitem,1,2) ONLY where item-group is observed
# (BEC, 91 groups). Federally ig is the constant sentinel, so n_item_groups is
# OVERWRITTEN to NA below with the NOT_OBSERVED note (buyer-collinear composite code).
firm_breadth <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm_keyed AS (%s)
  SELECT firm_code,
         COUNT(DISTINCT (oc||'|'||item)) AS n_items_total,
         COUNT(DISTINCT pbu)             AS n_buyers,
         COUNT(DISTINCT year)            AS n_years,
         COUNT(DISTINCT ig)              AS n_item_groups
  FROM ftm_keyed
  GROUP BY firm_code
", ftm_keyed_sql())))
if (!HAS_IG) {
  firm_breadth[, n_item_groups := NA_integer_]   # ig-specific column -> NA federally
  say("  n_item_groups := NA  (%s)", ig_note)
}
dbDisconnect(con, shutdown = TRUE); gc()
stamp("B_contact_join")

# merge onto AL panel
dt <- merge(al, contact[, .(firm_code, O_i, n_def_firms, n_contact_pairs)], by="firm_code", all.x=TRUE)
dt <- merge(dt, firm_case[, .(firm_code, n_cases, contact_items_cased)], by="firm_code", all.x=TRUE)
dt <- merge(dt, firm_breadth, by="firm_code", all.x=TRUE)
for (v in c("O_i","n_def_firms","n_contact_pairs","n_cases","contact_items_cased",
            "n_items_total","n_buyers","n_years","n_item_groups"))
  dt[is.na(get(v)), (v) := 0L]
dt[, Y_broad := as.integer(O_i > 0L)]          # broad label = any defendant contact
dt[, contact_intensity := ifelse(T_i>0, O_i/T_i, 0)]

# overlap of the internal Y_broad=1[O_i>0] sensitivity label with the canonical cobidder set
say("\nBroad label Y_i=1[O_i>0]: %d firms ; cobidder(canonical broad AL label): %d", dt[Y_broad==1,.N], dt[cobidder==1,.N])
say("  overlap(Y_broad & cobidder)=%d ; cobidder & !Y_broad=%d ; Y_broad & !cobidder=%d",
    dt[Y_broad==1 & cobidder==1,.N], dt[cobidder==1 & Y_broad==0,.N], dt[Y_broad==1 & cobidder==0,.N])
say("  -> PRIMARY label = cobidder (canonical broad AL cobidder label, reproducible, FL never used); Y_broad=1[O_i>0] reported as robustness")

# observed-contact summary diagnostic
osum <- rbindlist(list(
  data.table(group="all_AL",            n=nrow(dt),               n_pos_cobidder=dt[cobidder==1,.N],
             n_Ybroad=dt[Y_broad==1,.N], mean_O=mean(dt$O_i), med_O=median(dt$O_i), max_O=max(dt$O_i),
             total_O=sum(dt$O_i), mean_intensity=mean(dt$contact_intensity),
             total_def_firms=sum(dt$n_def_firms), total_cases_touched=uniqueN(def_case_map$processo)),
  data.table(group="FL14",   n=dt[fl14==1,.N], n_pos_cobidder=dt[fl14==1 & cobidder==1,.N],
             n_Ybroad=dt[fl14==1 & Y_broad==1,.N], mean_O=dt[fl14==1, mean(O_i)], med_O=dt[fl14==1, median(O_i)],
             max_O=dt[fl14==1, max(O_i)], total_O=dt[fl14==1, sum(O_i)],
             mean_intensity=dt[fl14==1, mean(contact_intensity)], total_def_firms=dt[fl14==1, sum(n_def_firms)],
             total_cases_touched=NA_integer_),
  data.table(group="non_FL14_AL", n=dt[fl14==0,.N], n_pos_cobidder=dt[fl14==0 & cobidder==1,.N],
             n_Ybroad=dt[fl14==0 & Y_broad==1,.N], mean_O=dt[fl14==0, mean(O_i)], med_O=dt[fl14==0, median(O_i)],
             max_O=dt[fl14==0, max(O_i)], total_O=dt[fl14==0, sum(O_i)],
             mean_intensity=dt[fl14==0, mean(contact_intensity)], total_def_firms=dt[fl14==0, sum(n_def_firms)],
             total_cases_touched=NA_integer_)
), fill=TRUE)
fwrite(osum, file.path(dir_diag, "observed_defendant_contact_summary.csv"))
say("wrote observed_defendant_contact_summary.csv")
stamp("B_observed_contact")

# =============================================================================
# C. OPPORTUNITY CELLS  (THREE definitions: COARSE / MEDIUM / STRICT)
# =============================================================================
say("\n----- C. opportunity cells (COARSE/MEDIUM/STRICT) -----")
# We need a firm x cell participation table per cell-definition, plus per-cell
# defendant-contact rates. Build the long participation table once in DuckDB,
# carrying the cell keys + a touches_defendant flag at the tender-item level.
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", SPILL))  # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05)
register_keymap(con)   # FED-only keymap; no-op for BEC
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)
dbWriteTable(con, "al_firms", data.frame(firm_code = al$firm_code), overwrite = TRUE)

# tender-item -> touches_defendant (any direct defendant on that oc|item)
# firm x (oc,item) participation restricted to ALWAYS-LOSER firms (the universe
# whose opportunity we benchmark). Cell keys: pbu, year, ig, item_code.
# touches_defendant for a firm-opportunity row = 1 if that tender-item has a
# defendant AND the firm is not that defendant (always-losers are never the
# defendant after cleaning, so simply: item has a defendant).
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): cell keys pbu/year resolved by
# the keyed view (ftm_keyed_sql): BEC substrings ; FED panel-joined codigo_ug +
# result year. COARSE/MEDIUM/STRICT construction is thus identical across sources.
part <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (%s),
  def_items AS (
    SELECT DISTINCT oc, item FROM ftm WHERE firm_code IN (SELECT firm_code FROM direct)
  ),
  al_part AS (
    SELECT f.firm_code, f.oc, f.item, f.pbu, f.year, f.ig, f.item_code,
           CASE WHEN di.oc IS NOT NULL THEN 1 ELSE 0 END AS touches_defendant
    FROM ftm f
    JOIN al_firms a ON f.firm_code = a.firm_code
    LEFT JOIN def_items di ON f.oc = di.oc AND f.item = di.item
  )
  SELECT firm_code, oc, item, pbu, year, ig, item_code, touches_defendant
  FROM al_part
", ftm_keyed_sql())))
dbDisconnect(con, shutdown = TRUE); gc()
say("always-loser firm-opportunity (tender-item) rows: %s", format(nrow(part), big.mark=","))
# attach firm_id for anon export & merge keys
part <- merge(part, al[, .(firm_code, firm_id, cobidder, fl14)], by="firm_code", all.x=TRUE)
stamp("C_participation_table")

# SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): item-group axis.
# CELL_DEFS_NOMINAL is the BEC-canonical key set (ig present). cell_keys_effective()
# drops the vacuous ig axis federally (item-group NOT_OBSERVED), so the cells that BEC
# builds as (ig,year) / (ig,year,pbu) become (year) / (year,pbu) federally. The
# difference is logged per granularity and exported in the cell_definition metadata
# column so the manuscript comparative table can state it.
CELL_DEFS_NOMINAL <- list(
  COARSE = c("ig","year"),                 # item_group x year  (modality dropped)
  MEDIUM = c("ig","year","pbu"),           # item_group x year x buyer
  STRICT = c("item_code","year","pbu")     # item_code x year x buyer
)
CELL_DEFS <- lapply(CELL_DEFS_NOMINAL, cell_keys_effective)  # ig dropped federally
for (defn in names(CELL_DEFS)) {
  if (!identical(CELL_DEFS[[defn]], CELL_DEFS_NOMINAL[[defn]]))
    say("  cell_definition[%s]: nominal {%s} -> effective {%s}  (%s)",
        defn, paste(CELL_DEFS_NOMINAL[[defn]], collapse=" x "),
        paste(CELL_DEFS[[defn]], collapse=" x "), ig_note)
  else
    say("  cell_definition[%s]: {%s}", defn, paste(CELL_DEFS[[defn]], collapse=" x "))
}
say("modality NOTE: firm_tender_map has no modality; cells drop modality. A modality-augmented")
say("  cell would need a join from item_value_panel by (numerodaoc,codigoitem); documented as")
say("  sensitivity, not blocking (Subprompt clause). Proceeding with 3 award-layer cell defs.")

# build cell tables + per-cell defendant-contact rate (+LOO) for each def
cell_summaries <- list()
firm_cell_frames <- list()   # firm-level expected-contact per def
for (defn in names(CELL_DEFS)) {
  keys <- CELL_DEFS[[defn]]
  pp <- copy(part)
  pp[, cell_id := do.call(paste, c(.SD, sep="|")), .SDcols = keys]
  # per-cell aggregates
  cellagg <- pp[, .(
    n_tender_items   = uniqueN(paste(oc, item)),
    n_participation  = .N,
    n_unique_firms   = uniqueN(firm_code),
    n_AL_firms       = uniqueN(firm_code),                 # all rows are AL by construction
    n_def_items      = uniqueN(paste(oc,item)[touches_defendant==1]),
    n_def_rows       = sum(touches_defendant)
  ), by=cell_id]
  cellagg[, p_g := n_def_rows / n_participation]           # defendant-contact rate (row-level)
  cellagg[, sparse_lt5_items := as.integer(n_tender_items < 5L)]
  cellagg[, singleton_cell   := as.integer(n_participation == 1L)]
  cell_summaries[[defn]] <- cellagg

  # firm expected contact E_i = sum_g n_ig * p_g  ; LOO p_{g,-i}
  pp <- merge(pp, cellagg[, .(cell_id, p_g, n_def_rows, n_participation)], by="cell_id", all.x=TRUE)
  # firm contribution to each cell (n_ig = rows of firm in cell; own positives)
  firm_cell <- pp[, .(n_ig = .N, own_pos = sum(touches_defendant),
                      p_g = p_g[1], cell_def_rows = n_def_rows[1], cell_n = n_participation[1]),
                  by=.(firm_code, firm_id, cell_id)]
  # LOO rate excludes this firm's own rows from the cell
  firm_cell[, loo_rate := ifelse(cell_n - n_ig > 0,
                                 (cell_def_rows - own_pos)/(cell_n - n_ig), NA_real_)]
  firm_cell[is.na(loo_rate), loo_rate := 0]                # firm is the whole cell -> 0 external opportunity
  # firm-level expected contact (plug-in and LOO)
  fe <- firm_cell[, .(
    E_i          = sum(n_ig * p_g, na.rm=TRUE),
    E_i_loo      = sum(n_ig * loo_rate, na.rm=TRUE),
    var_E        = sum(n_ig * p_g * (1 - p_g), na.rm=TRUE),
    n_cells      = uniqueN(cell_id),
    n_def_cells  = uniqueN(cell_id[p_g > 0]),
    max_cell_rate = max(p_g, na.rm=TRUE),
    share_in_def_cells = sum(n_ig[p_g>0]) / sum(n_ig)
  ), by=.(firm_code, firm_id)]
  setnames(fe, c("E_i","E_i_loo","var_E","n_cells","n_def_cells","max_cell_rate","share_in_def_cells"),
           paste0(c("E_i","E_i_loo","var_E","n_cells","n_def_cells","max_cell_rate","share_in_def_cells"),"_",defn))
  firm_cell_frames[[defn]] <- fe
  rm(pp, firm_cell); gc()
  say("  [%s] cells=%s ; firm-cell exp computed ; mean cells/firm=%.1f ; mean E_i=%.3f",
      defn, format(nrow(cellagg), big.mark=","),
      mean(fe[[paste0("n_cells_",defn)]]), mean(fe[[paste0("E_i_",defn)]]))
}
stamp("C_cells_expected")

# Table D - opportunity cell construction (compact, one row per def)
tabD_constr <- rbindlist(lapply(names(CELL_DEFS), function(defn) {
  c <- cell_summaries[[defn]]
  # SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): make the cell-definition
  # difference VISIBLE -- nominal keys, effective keys (ig dropped federally), and note.
  data.table(cell_def = defn,
             keys = paste(CELL_DEFS[[defn]], collapse=" x "),            # EFFECTIVE keys
             keys_nominal = paste(CELL_DEFS_NOMINAL[[defn]], collapse=" x "),
             item_group_observed = HAS_IG,
             cell_definition_note = if (identical(CELL_DEFS[[defn]], CELL_DEFS_NOMINAL[[defn]])) ""
                                    else ig_note,
             n_cells = nrow(c),
             total_tender_items = sum(c$n_tender_items),
             total_participation = sum(c$n_participation),
             median_cell_items = median(c$n_tender_items),
             pct_cells_lt5_items = round(100*mean(c$sparse_lt5_items),1),
             pct_singleton_cells = round(100*mean(c$singleton_cell),1),
             n_cells_with_defendant = sum(c$n_def_items > 0),
             mean_p_g = round(mean(c$p_g),5),
             max_p_g = round(max(c$p_g),5))
}))
fwrite(tabD_constr, file.path(dir_app_t, "table_D_opportunity_cell_construction.csv"))
# sparsity diagnostic (per def x cell-size buckets)
sparsity <- rbindlist(lapply(names(CELL_DEFS), function(defn){
  c <- cell_summaries[[defn]]
  data.table(cell_def=defn,
             n_cells=nrow(c),
             cells_1_item   = sum(c$n_tender_items==1),
             cells_2_4_items= sum(c$n_tender_items>=2 & c$n_tender_items<5),
             cells_5_19     = sum(c$n_tender_items>=5 & c$n_tender_items<20),
             cells_20p      = sum(c$n_tender_items>=20),
             share_part_in_sparse = round(sum(c$n_participation[c$n_tender_items<5])/sum(c$n_participation),3))
}))
fwrite(sparsity, file.path(dir_diag, "opportunity_cell_sparsity.csv"))

# LaTeX for cell construction
tex_constr <- c(
  "\\begin{table}[htbp]\\centering",
  "\\caption{Opportunity-cell construction across granularities}",
  "\\label{tab:opp_cell_construction}",
  "\\begin{tabular}{lrrrrrr}\\hline",
  "Cell def. & Keys & \\#cells & Med. items/cell & \\% singleton & \\#cells w/ def. & mean $p_g$ \\\\\\hline",
  paste0(tabD_constr$cell_def, " & ", gsub("_","\\\\_",tabD_constr$keys), " & ",
         format(tabD_constr$n_cells, big.mark=","), " & ", tabD_constr$median_cell_items, " & ",
         tabD_constr$pct_singleton_cells, " & ", format(tabD_constr$n_cells_with_defendant, big.mark=","),
         " & ", tabD_constr$mean_p_g, " \\\\"),
  "\\hline\\end{tabular}\\end{table}")
writeLines(tex_constr, file.path(dir_app_t, "table_D_opportunity_cell_construction.tex"))
say("wrote table_D_opportunity_cell_construction.{csv,tex} + opportunity_cell_sparsity.csv")

# =============================================================================
# D. ASSEMBLE FIRM OPPORTUNITY-ADJUSTED FRAME  (E_i, X_i, Z_i per def)
# =============================================================================
say("\n----- D. firm opportunity-adjusted frame -----")
ff <- copy(dt)   # firm-level (one row per AL firm) with O_i, breadth, labels
for (defn in names(CELL_DEFS)) {
  ff <- merge(ff, firm_cell_frames[[defn]], by=c("firm_code","firm_id"), all.x=TRUE)
}
# zero-fill expected for firms with no AL participation captured (should be all in part)
for (defn in names(CELL_DEFS)) {
  for (v in paste0(c("E_i","E_i_loo","var_E","n_cells","n_def_cells","max_cell_rate","share_in_def_cells"),"_",defn))
    if (v %in% names(ff)) ff[is.na(get(v)), (v) := 0]
}
# excess + standardized residual per def
for (defn in names(CELL_DEFS)) {
  Ei  <- ff[[paste0("E_i_",defn)]]; Eil <- ff[[paste0("E_i_loo_",defn)]]; vE <- ff[[paste0("var_E_",defn)]]
  ff[, (paste0("X_i_",defn))     := O_i - Ei]
  ff[, (paste0("X_i_loo_",defn)) := O_i - Eil]
  ff[, (paste0("Z_i_",defn))     := ifelse(vE > 0, (O_i - Ei)/sqrt(vE), 0)]
  ff[, (paste0("log_E_",defn))   := log1p(pmax(Ei,0))]
}
# exposure decile on the MEDIUM def E_i (primary) + log_opp proxy from coarse n_def participation
ff[, log_opportunity := log1p(O_i)]   # NB: keep script-76 semantics below separately
# Primary "exposure" axis to reproduce 76: n_opp_items = distinct tender-items the
# firm bid on inside CADE-active (pbu,year,ig) cells, where CADE-active is defined
# over the FULL firm_tender_map (ALL firms, not just always-losers). Our `part`
# table is AL-restricted, so reconstructing active cells from it UNDERCOUNTS them
# (it misses cells where a defendant bid but no AL firm shares that exact item).
# The validated reference script 76 computed n_opp_items over the full FTM and its
# firm_panel.csv (exposed=6,040) backs every locked BEC number.
#
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): firm_panel.csv exposure axis.
#   firm_panel.csv columns CONSUMED here: firm_code, n_opp_items, n_opp_cells, log_opp
#   (log_opp = log1p(n_opp_items); exposed := n_opp_items>0). Producer = script 76:
#   CADE-active cell = (pbu,year,ig) over the FULL FTM (all firms) where any direct
#   defendant bids; n_opp_items = distinct (oc,item) the firm bid on inside an active
#   cell; n_opp_cells = distinct active (pbu,year,ig) cells the firm touched.
#
#   output/exposure_adjusted_audit/firm_panel.csv is a LEGACY BEC-ONLY artifact with
#   BEC substring keys and no federal twin. So:
#     BEC : reuse the validated legacy CSV when present (canonical locked numbers);
#           else recompute via ftm_keyed (BEC substrings -> identical result).
#     FED : ALWAYS recompute over the full FTM via ftm_keyed (codigo_ug buyer +
#           result-year), and CACHE the rebuilt panel to cfg cache as the federal
#           twin (NEVER reads the BEC artifact). Construction is byte-identical
#           logic; only the key SEMANTICS differ per G1.
ref_panel_path <- file.path(REPO, "output", "exposure_adjusted_audit", "firm_panel.csv")
fed_panel_path <- file.path(dir_cache, "firm_panel_exposure_axis.csv")  # FED twin / BEC recompute cache
if (IS_BEC && file.exists(ref_panel_path)) {
  refp <- fread(ref_panel_path, colClasses=list(character="firm_code"))
  refp[, firm_code := norm14(firm_code)]
  ff <- merge(ff, refp[, .(firm_code, n_opp_items, n_opp_cells, log_opp)], by="firm_code", all.x=TRUE)
  for (v in c("n_opp_items","n_opp_cells")) ff[is.na(get(v)), (v) := 0L]
  ff[is.na(log_opp), log_opp := 0]
  ff[, exposed := as.integer(n_opp_items > 0L)]
  say("  exposure axis (n_opp_items) from validated script-76 firm_panel.csv: exposed=%d", ff[exposed==1,.N])
} else {
  # full-FTM recompute via ftm_keyed (mirrors script-76 SQL; keys are cfg-resolved:
  # BEC substrings ; FED codigo_ug buyer + result year). Builds the same frame the
  # legacy firm_panel.csv held, then caches it to cfg cache as the source's twin.
  say("  recomputing n_opp_items over FULL firm_tender_map via ftm_keyed (source=%s, legacy BEC csv %s)",
      SRC, if (IS_BEC) "absent" else "N/A federally")
  con2 <- dbConnect(duckdb()); dbExecute(con2,"PRAGMA threads=12"); dbExecute(con2,"PRAGMA memory_limit='12GB'")
  dbExecute(con2, sprintf("PRAGMA temp_directory='%s'", SPILL))
  register_keymap(con2)   # FED-only keymap; no-op for BEC
  dbWriteTable(con2,"direct",data.frame(firm_code=direct_codes),overwrite=TRUE)
  # SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): the (pbu,year,ig)
  # CADE-active cell is the MEDIUM granularity. Federally ig is the constant sentinel
  # (item-group NOT_OBSERVED), so this cell collapses to (pbu,year) -- consistent with
  # cell_keys_effective() above; no separate federal branch needed.
  opp76 <- as.data.table(dbGetQuery(con2, sprintf("
    WITH ftm AS (%s),
    cade_cells AS (SELECT DISTINCT f.pbu, f.year AS yr, f.ig FROM ftm f JOIN direct d ON f.firm_code=d.firm_code)
    SELECT f.firm_code,
      COUNT(DISTINCT CASE WHEN c.pbu IS NOT NULL THEN (f.oc||'|'||f.item) END) AS n_opp_items,
      COUNT(DISTINCT CASE WHEN c.pbu IS NOT NULL THEN (f.pbu||'|'||f.year||'|'||f.ig) END) AS n_opp_cells
    FROM ftm f LEFT JOIN cade_cells c ON f.pbu=c.pbu AND f.year=c.yr AND f.ig=c.ig
    GROUP BY f.firm_code", ftm_keyed_sql())))
  dbDisconnect(con2,shutdown=TRUE)
  opp76[, log_opp := log1p(n_opp_items)]
  fwrite(opp76, fed_panel_path)   # cache the rebuilt exposure panel to cfg cache
  say("  cached rebuilt exposure panel -> %s (%d firms)", fed_panel_path, nrow(opp76))
  ff <- merge(ff, opp76[, .(firm_code, n_opp_items, n_opp_cells, log_opp)], by="firm_code", all.x=TRUE)
  for (v in c("n_opp_items","n_opp_cells")) ff[is.na(get(v)), (v) := 0L]
  ff[is.na(log_opp), log_opp := 0]
  ff[, exposed := as.integer(n_opp_items > 0L)]
}
gc()

# exposure deciles (among exposed) -- for stratified AUC
ff[, opp_decile := NA_integer_]
exrows <- ff$exposed == 1
brks <- unique(quantile(ff$n_opp_items[exrows], probs=seq(0,1,0.1)))
ff[exrows, opp_decile := cut(n_opp_items, breaks=brks, include.lowest=TRUE, labels=FALSE)]

# export anon firm frame (NO raw CNPJ)
keep_cols <- c("firm_id","T_i","W_i","score_i","fl14","cobidder","Y_broad","O_i","n_opp_items",
               "exposed","log_opp","contact_intensity","n_def_firms","n_cases",
               "n_items_total","n_buyers","n_years","n_item_groups",
               grep("^(E_i_|E_i_loo_|X_i_|X_i_loo_|Z_i_|log_E_|n_cells_|n_def_cells_|max_cell_rate_|share_in_def_cells_)",
                    names(ff), value=TRUE))
fwrite(ff[, ..keep_cols], file.path(dir_cache, "firm_opportunity_adjusted_frame.csv"))
say("wrote firm_opportunity_adjusted_frame.csv (%d firms, %d cols, anon firm_id, NO raw CNPJ)",
    nrow(ff), length(keep_cols))
stamp("D_firm_frame")

# =============================================================================
# E. COMMON SUPPORT (3 rules)
# =============================================================================
say("\n----- E. common support (3 rules) -----")
# Minimal: all firms with computable E_i (all, since E_i defined everywhere here)
# Moderate: firm has >=1 participation in a cell with >=5 tender-items (MEDIUM def)
# Strict: overlapping E_i support between FL14 and non-FL14 + drop sparse cells
#         operationalize via MEDIUM-def E_i support overlap.
cs_rows <- list()
for (defn in names(CELL_DEFS)) {
  Ei <- ff[[paste0("E_i_",defn)]]
  # moderate flag: firm touched >=1 non-singleton cell -> proxy n_cells with cell>=5 items.
  # compute per-firm max cell-item count via cell_summaries
  cs <- cell_summaries[[defn]]
  big_cells <- cs[n_tender_items >= 5L, cell_id]
  # recompute per firm participation in big cells (cheap: from part)
  ppd <- copy(part); ppd[, cell_id := do.call(paste, c(.SD, sep="|")), .SDcols=CELL_DEFS[[defn]]]
  firm_big <- ppd[cell_id %in% big_cells, .(in_big = 1L), by=firm_code]
  ffd <- merge(ff[, .(firm_code, fl14, cobidder, Ei = get(paste0("E_i_",defn)))],
               firm_big, by="firm_code", all.x=TRUE)
  ffd[is.na(in_big), in_big := 0L]
  rm(ppd); gc()

  # strict: E_i overlap region between fl14 groups
  e1 <- ffd[fl14==1, Ei]; e0 <- ffd[fl14==0, Ei]
  lo <- max(min(e1), min(e0)); hi <- min(max(e1), max(e0))
  for (rule in c("minimal","moderate","strict")) {
    keep <- switch(rule,
      minimal  = rep(TRUE, nrow(ffd)),
      moderate = ffd$in_big == 1L,
      strict   = ffd$in_big == 1L & ffd$Ei >= lo & ffd$Ei <= hi)
    sub <- ffd[keep]
    cs_rows[[length(cs_rows)+1]] <- data.table(
      cell_def=defn, rule=rule,
      N_AL = nrow(ffd), N_retained = nrow(sub),
      share_retained = round(nrow(sub)/nrow(ffd),3),
      N_cobidders_total = ffd[cobidder==1,.N], N_cobidders_retained = sub[cobidder==1,.N],
      mean_E_fl14 = round(mean(sub[fl14==1, Ei]),3), mean_E_nonfl14 = round(mean(sub[fl14==0, Ei]),3),
      mean_E_cob = round(mean(sub[cobidder==1, Ei]),3), mean_E_noncob = round(mean(sub[cobidder==0, Ei]),3),
      singleton_firms_dropped = sum(ffd$in_big==0L & if (rule=="minimal") FALSE else TRUE))
  }
}
common_support <- rbindlist(cs_rows)
fwrite(common_support, file.path(dir_diag, "opportunity_common_support.csv"))
say("wrote opportunity_common_support.csv (%d rule x def rows)", nrow(common_support))
say("  support retention (MEDIUM): %s",
    paste(common_support[cell_def=="MEDIUM", sprintf("%s=%.1f%%", rule, 100*share_retained)], collapse="  "))
stamp("E_common_support")

# =============================================================================
# F. CONTROL-FUNCTION VALIDATION -> Table C (9 designs) + full appendix
# =============================================================================
say("\n----- F. control-function validation -----")
# Helper: full triage metrics for a (label, score) on a data.table
triage_row <- function(design, dat, label, score, note="", do_boot=FALSE) {
  y <- as.integer(dat[[label]]); s <- as.numeric(dat[[score]])
  ok <- !is.na(y) & !is.na(s)
  y <- y[ok]; s <- s[ok]
  if (sum(y)==0 || sum(y)==length(y)) return(NULL)
  ac  <- tryCatch(pROC::ci.auc(pROC::roc(y, s, quiet=TRUE, direction="<")), error=function(e) c(NA,NA,NA))
  pra <- average_precision(y, s)
  row <- data.table(
    design=design, label=label, score=score, note=note,
    n=length(y), positives=sum(y),
    roc_auc=as.numeric(ac[2]), roc_lo=as.numeric(ac[1]), roc_hi=as.numeric(ac[3]),
    pr_auc=pra,
    prec_100=precision_at_k(y,s,100), prec_250=precision_at_k(y,s,250),
    prec_500=precision_at_k(y,s,500), prec_1000=precision_at_k(y,s,1000),
    rec_100=recall_at_k(y,s,100), rec_250=recall_at_k(y,s,250),
    rec_500=recall_at_k(y,s,500), rec_1000=recall_at_k(y,s,1000),
    lift_100=lift_at_k(y,s,100), lift_500=lift_at_k(y,s,500), lift_1000=lift_at_k(y,s,1000),
    fp_500=false_positives_at_k(y,s,500), fn_500=false_negatives_at_k(y,s,500))
  if (do_boot) {
    b_pr  <- bootstrap_metric_ci(y, s, average_precision, B=2000L, seed=SEED)
    b_p5  <- bootstrap_metric_ci(y, s, function(l,sc,...) precision_at_k(l,sc,500,...), B=2000L, seed=SEED)
    b_r5  <- bootstrap_metric_ci(y, s, function(l,sc,...) recall_at_k(l,sc,500,...), B=2000L, seed=SEED)
    row[, `:=`(pr_auc_lo=b_pr$ci_lo, pr_auc_hi=b_pr$ci_hi,
               prec500_lo=b_p5$ci_lo, prec500_hi=b_p5$ci_hi,
               rec500_lo=b_r5$ci_lo, rec500_hi=b_r5$ci_hi)]
  }
  row
}
# logit-prediction score builder (returns linear-predictor / fitted prob as score)
logit_score <- function(formula, dat) {
  m <- tryCatch(glm(formula, data=dat, family=binomial()), error=function(e) NULL)
  if (is.null(m)) return(list(score=NULL, m=NULL, sep=TRUE))
  fitp <- predict(m, type="response")
  sep <- any(abs(coef(m)) > 25, na.rm=TRUE) || !m$converged
  list(score=fitp, m=m, sep=sep)
}

full_rows <- list(); sep_flags <- character(0)
addF <- function(...) full_rows[[length(full_rows)+1L]] <<- triage_row(...)

# S0 raw + unconditional exposure-only (the 0.946 mechanical benchmark over ALL AL)
addF("S0_raw_score", ff, "cobidder", "score_i", "raw log_tc", do_boot=TRUE)
addF("S0_raw_fl14",  ff, "cobidder", "fl14",    "raw FL14",   do_boot=TRUE)
addF("S0_exposure_only_uncond", ff, "cobidder", "log_opp",
     "unconditional log-opportunity over ALL 16,843 AL (locked 0.946)")
uncond_exp_auc <- auc_ci("cobidder","log_opp",ff)$auc
say("  unconditional exposure-only AUC (all AL) = %.4f  (locked 0.946)", uncond_exp_auc)

# S1 flexible participation (T_i deciles) -- compare model AUC (score is monotone transform)
ff[, T_dec := cut(T_i, breaks=unique(quantile(T_i, probs=seq(0,1,0.1))), include.lowest=TRUE, labels=FALSE)]
ls1 <- logit_score(cobidder ~ ns(T_i, df=4), ff)
if (!is.null(ls1$score)) { ff$.s1 <- ls1$score; addF("S1_flexible_participation", ff, "cobidder", ".s1", "ns(T_i,4)") }
if (ls1$sep) sep_flags <- c(sep_flags, "S1")

# S2 expected-contact (per cell def) -- THE headline control function
for (defn in names(CELL_DEFS)) {
  f2 <- as.formula(sprintf("cobidder ~ score_i + log_E_%s", defn))
  ls <- logit_score(f2, ff)
  if (!is.null(ls$score)) { ff$.s2 <- ls$score
    addF(paste0("S2_score+logE_",defn), ff, "cobidder", ".s2",
         sprintf("logit score+log(1+E) [%s]", defn), do_boot=(defn=="MEDIUM")) }
  if (ls$sep) sep_flags <- c(sep_flags, paste0("S2_",defn))
  f2b <- as.formula(sprintf("cobidder ~ fl14 + log_E_%s", defn))
  lsb <- logit_score(f2b, ff)
  if (!is.null(lsb$score)) { ff$.s2b <- lsb$score
    addF(paste0("S2_fl14+logE_",defn), ff, "cobidder", ".s2b", sprintf("logit fl14+log(1+E) [%s]", defn)) }
}
# S2 exposure-only (the benchmark the score must beat) -- script-76 axis
ls_exp <- logit_score(cobidder ~ log_opp, ff[exposed==1])
exf <- ff[exposed==1]
if (!is.null(ls_exp$score)) { exf$.exp <- ls_exp$score
  addF("S2_exposure_only_logit", exf, "cobidder", ".exp", "logit log_opp (exposure-only, exposed)") }

# S3 + opportunity breadth
ls3 <- logit_score(cobidder ~ score_i + log_E_MEDIUM + log1p(n_items_total) + log1p(n_buyers) + log1p(n_years) + log1p(n_cells_MEDIUM), ff)
if (!is.null(ls3$score)) { ff$.s3 <- ls3$score
  addF("S3_score+E+breadth", ff, "cobidder", ".s3", "logit score+E+breadth controls") }
if (ls3$sep) sep_flags <- c(sep_flags, "S3")

# S4 exposure-decile FE + participation-bin FE (among exposed)
exf[, opp_decile_f := factor(opp_decile)]
exf[, T_dec_f := factor(T_dec)]
ls4 <- logit_score(cobidder ~ score_i + opp_decile_f + T_dec_f, exf)
if (!is.null(ls4$score)) { exf$.s4 <- ls4$score
  addF("S4_exposureFE+partFE", exf, "cobidder", ".s4", "logit score + opp-decile FE + part-bin FE (exposed)") }
if (ls4$sep) sep_flags <- c(sep_flags, "S4")

# S5 excess-contact target: rank score_i vs 1[X_i>0]; regress Z_i on score/fl14
ff[, Xpos_MEDIUM := as.integer(X_i_MEDIUM > 0)]
addF("S5_score_vs_excessPos", ff, "Xpos_MEDIUM", "score_i", "score ranks 1[X_i>0] (MEDIUM)")
addF("S5_fl14_vs_excessPos",  ff, "Xpos_MEDIUM", "fl14",    "fl14 ranks 1[X_i>0] (MEDIUM)")
zreg <- lm(Z_i_MEDIUM ~ fl14, data=ff); zreg_s <- lm(Z_i_MEDIUM ~ score_i, data=ff)
say("  S5 Z_i ~ fl14: beta=%+.4f (p=%.3g) ; Z_i ~ score_i: beta=%+.4f (p=%.3g)",
    coef(summary(zreg))["fl14","Estimate"], coef(summary(zreg))["fl14","Pr(>|t|)"],
    coef(summary(zreg_s))["score_i","Estimate"], coef(summary(zreg_s))["score_i","Pr(>|t|)"])

# S6 strict common support (MEDIUM): key specs re-run
csm <- cell_summaries[["MEDIUM"]]; big_cells <- csm[n_tender_items>=5L, cell_id]
ppd <- copy(part); ppd[, cell_id := do.call(paste, c(.SD, sep="|")), .SDcols=CELL_DEFS[["MEDIUM"]]]
firm_big <- unique(ppd[cell_id %in% big_cells, .(firm_code)]); rm(ppd); gc()
strict_codes <- firm_big$firm_code
e1 <- ff[fl14==1 & firm_code %in% strict_codes, E_i_MEDIUM]; e0 <- ff[fl14==0 & firm_code %in% strict_codes, E_i_MEDIUM]
lo <- max(min(e1), min(e0)); hi <- min(max(e1), max(e0))
ff_strict <- ff[firm_code %in% strict_codes & E_i_MEDIUM >= lo & E_i_MEDIUM <= hi]
say("  S6 strict-support sample: %d firms (pos=%d)", nrow(ff_strict), ff_strict[cobidder==1,.N])
addF("S6_strict_raw_score", ff_strict, "cobidder", "score_i", "raw score on strict support", do_boot=TRUE)
ls6 <- logit_score(cobidder ~ score_i + log_E_MEDIUM, ff_strict)
if (!is.null(ls6$score)) { ff_strict$.s6 <- ls6$score
  addF("S6_score+E_strict", ff_strict, "cobidder", ".s6", "logit score+E on strict support", do_boot=TRUE) }
if (ls6$sep) sep_flags <- c(sep_flags, "S6")

full_tab <- rbindlist(full_rows, fill=TRUE)
fwrite(full_tab, file.path(dir_app_t, "table_D_control_function_validation_full.csv"))
say("wrote table_D_control_function_validation_full.csv (%d specs)", nrow(full_tab))
say("SEPARATION/non-convergence flags (npos=191 rare-event): %s",
    if (length(sep_flags)) paste(unique(sep_flags), collapse=", ") else "none")

# --- nested-logit increment + DeLong (reproduce script 76: +0.0415, p=2.08e-06) ---
say("\n[F.repro] nested-logit increment over exposure-only (exposed firms, n=%d):", nrow(exf))
m_opp  <- glm(cobidder ~ log_opp, data=exf, family=binomial())
m_full <- glm(cobidder ~ log_opp + score_i, data=exf, family=binomial())
r_opp  <- pROC::roc(exf$cobidder, predict(m_opp,type="response"),  quiet=TRUE, direction="<")
r_full <- pROC::roc(exf$cobidder, predict(m_full,type="response"), quiet=TRUE, direction="<")
dl <- pROC::roc.test(r_opp, r_full, method="delong", paired=TRUE)
incr <- as.numeric(r_full$auc - r_opp$auc)
say("  exposure-only logit AUC=%.4f ; +score AUC=%.4f ; increment=%+.4f ; DeLong Z=%.3f p=%.3g",
    as.numeric(r_opp$auc), as.numeric(r_full$auc), incr, dl$statistic, dl$p.value)

# within-opportunity-stratum AUC (reproduce 0.7715 / 0.7709)
s_log <- strat_auc(exf, "score_i", "cobidder", "opp_decile")
s_fl  <- strat_auc(exf, "fl14",    "cobidder", "opp_decile")
say("  within-opp-stratum AUC: log_tc=%.4f  fl14=%.4f  (76: 0.7715/0.7709)", s_log$auc, s_fl$auc)

# Table C: the 9 headline designs (Step 14)
pick <- function(d) full_tab[design==d]
tabC <- rbindlist(list(
  pick("S0_raw_score"),
  pick("S0_raw_fl14"),
  pick("S2_exposure_only_logit"),
  pick("S2_score+logE_MEDIUM"),
  pick("S2_fl14+logE_MEDIUM"),
  pick("S3_score+E+breadth"),
  pick("S4_exposureFE+partFE"),
  pick("S5_score_vs_excessPos"),
  pick("S6_score+E_strict")
), fill=TRUE)
# attach the nested AUC + within-stratum as annotation rows
annot <- data.table(design=c("NESTED_exposure_only","NESTED_exposure+score","WITHIN_STRATUM_log_tc","WITHIN_STRATUM_fl14"),
                    label="cobidder", score=c("logit log_opp","logit log_opp+score","score_i|opp-decile","fl14|opp-decile"),
                    note=c("script-76 repro","script-76 repro; DeLong p reported","pooled C-stat","pooled C-stat"),
                    n=c(nrow(exf),nrow(exf),nrow(exf),nrow(exf)),
                    positives=rep(exf[cobidder==1,.N],4),
                    roc_auc=c(as.numeric(r_opp$auc), as.numeric(r_full$auc), s_log$auc, s_fl$auc))
tabC <- rbindlist(list(tabC, annot), fill=TRUE)
tabC[, delong_p := NA_real_]; tabC[design=="NESTED_exposure+score", delong_p := dl$p.value]
tabC[, auc_increment := NA_real_]; tabC[design=="NESTED_exposure+score", auc_increment := incr]
fwrite(tabC, file.path(dir_main_t, "table_C_opportunity_adjusted_validation.csv"))

texC <- c(
  "\\begin{table}[htbp]\\centering",
  "\\caption{Opportunity-adjusted validation (control-function designs)}",
  "\\label{tab:opp_adjusted_validation}",
  "\\begin{tabular}{llrrrrr}\\hline",
  "Design & Score & N & Pos. & ROC-AUC & PR-AUC & Prec@500 \\\\\\hline",
  paste0(gsub("_","\\\\_",tabC$design), " & ", gsub("_","\\\\_",substr(tabC$score,1,22)), " & ",
         format(tabC$n, big.mark=","), " & ", tabC$positives, " & ",
         ifelse(is.na(tabC$roc_auc),"--",sprintf("%.4f",tabC$roc_auc)), " & ",
         ifelse(is.na(tabC$pr_auc),"--",sprintf("%.4f",tabC$pr_auc)), " & ",
         ifelse(is.na(tabC$prec_500),"--",sprintf("%.4f",tabC$prec_500)), " \\\\"),
  "\\hline\\end{tabular}",
  sprintf("\\begin{tablenotes}\\footnotesize\\item Nested-logit increment of score over exposure-only = %+.4f (DeLong $p=%.2e$); within-opportunity-decile C-statistic: $\\log T_i$ = %.4f, FL14 = %.4f. Exposure-only AUC = %.4f reproduces the mechanical benchmark.\\end{tablenotes}",
          incr, dl$p.value, s_log$auc, s_fl$auc, as.numeric(r_opp$auc)),
  "\\end{table}")
writeLines(texC, file.path(dir_main_t, "table_C_opportunity_adjusted_validation.tex"))
say("wrote table_C_opportunity_adjusted_validation.{csv,tex}")
stamp("F_control_function")

# =============================================================================
# G. OBSERVED-vs-EXPECTED BY SCORE BINS -> table + figures
# =============================================================================
say("\n----- G. observed vs expected by score bins -----")
mkbin <- function() {
  ff[, bin := NA_character_]
  ff[T_i <= 5,  bin := "T<=5"]
  ff[T_i > 5 & T_i < 14, bin := "6-13"]
  ff[fl14==1 & T_i < 50, bin := "FL14 (14-49)"]
  ff[T_i >= 50, bin := "T>=50"]
  ff
}
ff <- mkbin()
# also score deciles for the figure x-axis
ff[, score_dec := cut(score_i, breaks=unique(quantile(score_i, probs=seq(0,1,0.1))), include.lowest=TRUE, labels=FALSE)]
binsummary <- ff[, .(
  N=.N, N_cob=sum(cobidder), obs_prev=mean(cobidder),
  mean_O=mean(O_i), mean_E=mean(E_i_MEDIUM), mean_excess=mean(X_i_MEDIUM),
  std_excess=mean(Z_i_MEDIUM), mean_fl14=mean(fl14), mean_score=mean(score_i),
  prev_lo = mean(cobidder) - 1.96*sqrt(mean(cobidder)*(1-mean(cobidder))/.N),
  prev_hi = mean(cobidder) + 1.96*sqrt(mean(cobidder)*(1-mean(cobidder))/.N)
), by=score_dec][order(score_dec)]
binsummary_named <- ff[, .(
  N=.N, N_cob=sum(cobidder), obs_prev=mean(cobidder),
  mean_O=mean(O_i), mean_E=mean(E_i_MEDIUM), mean_excess=mean(X_i_MEDIUM),
  std_excess=mean(Z_i_MEDIUM), mean_fl14=mean(fl14), mean_score=mean(score_i)
), by=bin]
fwrite(rbindlist(list(binsummary_named, binsummary), fill=TRUE),
       file.path(dir_app_t, "table_D_observed_expected_by_score_bins.csv"))
texG <- c("\\begin{table}[htbp]\\centering","\\caption{Observed vs expected defendant contact by score decile}",
  "\\label{tab:obs_exp_bins}","\\begin{tabular}{rrrrrr}\\hline",
  "Score decile & N & \\#cob. & Obs. prev. & mean $O_i$ & mean $E_i$ \\\\\\hline",
  paste0(binsummary$score_dec, " & ", format(binsummary$N,big.mark=","), " & ", binsummary$N_cob, " & ",
         sprintf("%.4f",binsummary$obs_prev), " & ", sprintf("%.2f",binsummary$mean_O), " & ",
         sprintf("%.2f",binsummary$mean_E), " \\\\"),
  "\\hline\\end{tabular}\\end{table}")
writeLines(texG, file.path(dir_app_t, "table_D_observed_expected_by_score_bins.tex"))

# figure: observed AND expected contact/prevalence by score decile
pf <- binsummary[!is.na(score_dec)]
gdat <- rbindlist(list(
  data.table(score_dec=pf$score_dec, value=pf$mean_O, lo=NA, hi=NA, series="Observed contact (O_i)"),
  data.table(score_dec=pf$score_dec, value=pf$mean_E, lo=NA, hi=NA, series="Expected contact (E_i)")))
p1 <- ggplot(gdat, aes(score_dec, value, color=series)) +
  geom_line() + geom_point() +
  labs(x="Loss-intensity score decile", y="Mean defendant contact",
       title="Observed vs expected defendant contact by score decile",
       color=NULL) + theme_minimal()
ggsave(file.path(dir_main_f, "fig_observed_vs_expected_contact_bins.pdf"), p1,
       width=7, height=4.5, device=cairo_pdf)
p2 <- ggplot(pf, aes(score_dec, mean_excess)) + geom_col(fill="#9e1b32") +
  labs(x="Loss-intensity score decile", y="Mean excess contact (O_i - E_i)",
       title="Excess defendant contact by score decile (MEDIUM cells)") + theme_minimal()
ggsave(file.path(dir_app_f, "fig_excess_contact_by_score_bins.pdf"), p2,
       width=7, height=4.5, device=cairo_pdf)
say("wrote observed-vs-expected table + 2 figures")
stamp("G_obs_vs_exp")

# =============================================================================
# H. CELL-PRESERVING PERMUTATION  (Approach B firm-exposure sim + Approach C)
# =============================================================================
say("\n----- H. cell-preserving permutation -----")
B_PERM <- 2000L
# observed metrics (primary label = cobidder, score = score_i)
obs_pr   <- average_precision(ff$cobidder, ff$score_i)
obs_auc  <- roc_auc(ff$cobidder, ff$score_i)
obs_p500 <- precision_at_k(ff$cobidder, ff$score_i, 500)
obs_r500 <- recall_at_k(ff$cobidder, ff$score_i, 500)
obs_fl_enr <- ff[fl14==1, mean(cobidder)] / ff[, mean(cobidder)]   # FL14 enrichment

# Approach B: firm exposure simulation. O_i^sim = sum_g Binom(n_ig, p_g).
# Need per-firm cell list with (n_ig, p_g) for MEDIUM def. Y_i^sim = 1[O_i^sim>0].
ppB <- copy(part); ppB[, cell_id := do.call(paste, c(.SD, sep="|")), .SDcols=CELL_DEFS[["MEDIUM"]]]
ppB <- merge(ppB, cell_summaries[["MEDIUM"]][, .(cell_id, p_g)], by="cell_id", all.x=TRUE)
firm_cell_B <- ppB[, .(n_ig=.N, p_g=p_g[1]), by=.(firm_code, cell_id)]
firm_cell_B <- merge(firm_cell_B, al[, .(firm_code, firm_id)], by="firm_code")
rm(ppB); gc()
# precompute index for fast sim
setkey(firm_cell_B, firm_id)
fb_ids   <- firm_cell_B$firm_id
fb_n     <- firm_cell_B$n_ig
fb_p     <- firm_cell_B$p_g
nfirm    <- nrow(ff)
firm_idx <- ff$firm_id
fl14_vec <- ff$fl14
score_vec<- ff$score_i
base_rate<- mean(ff$cobidder)

set.seed(SEED)
permB <- data.table(b=integer(B_PERM), pr_auc=numeric(B_PERM), roc_auc=numeric(B_PERM),
                    prec500=numeric(B_PERM), rec500=numeric(B_PERM), fl_enrich=numeric(B_PERM))
for (b in seq_len(B_PERM)) {
  # simulate contacts per firm-cell row, aggregate to firm
  sim_contacts <- rbinom(length(fb_n), fb_n, pmin(pmax(fb_p,0),1))
  O_sim <- tapply(sim_contacts, fb_ids, sum)
  Ysim <- integer(nfirm)
  pos_ids <- as.integer(names(O_sim))[O_sim > 0]
  Ysim[match(pos_ids, firm_idx)] <- 1L
  if (sum(Ysim)==0) { permB[b, `:=`(b=b, pr_auc=NA, roc_auc=NA, prec500=NA, rec500=NA, fl_enrich=NA)]; next }
  permB[b, `:=`(b=b,
    pr_auc  = suppressWarnings(average_precision(Ysim, score_vec)),
    roc_auc = suppressWarnings(roc_auc(Ysim, score_vec)),
    prec500 = suppressWarnings(precision_at_k(Ysim, score_vec, 500)),
    rec500  = suppressWarnings(recall_at_k(Ysim, score_vec, 500)),
    fl_enrich = { br <- mean(Ysim); if (br>0) mean(Ysim[fl14_vec==1])/br else NA_real_ })]
}
say("  Approach B done (firm-exposure sim, B=%d)", B_PERM)

# Approach C: matched-exposure label permutation (exposure-decile x participation-bin)
set.seed(SEED + 1L)
ff[, perm_stratum := paste(ifelse(is.na(opp_decile), 0L, opp_decile), ifelse(is.na(T_dec),0L,T_dec), sep="_")]
strata_idx <- split(seq_len(nrow(ff)), ff$perm_stratum)
ylab <- ff$cobidder
permC <- data.table(b=integer(B_PERM), pr_auc=numeric(B_PERM), roc_auc=numeric(B_PERM),
                    prec500=numeric(B_PERM), rec500=numeric(B_PERM), fl_enrich=numeric(B_PERM))
for (b in seq_len(B_PERM)) {
  yp <- ylab
  for (ix in strata_idx) if (length(ix) > 1L) yp[ix] <- sample(ylab[ix])
  permC[b, `:=`(b=b,
    pr_auc  = suppressWarnings(average_precision(yp, score_vec)),
    roc_auc = suppressWarnings(roc_auc(yp, score_vec)),
    prec500 = suppressWarnings(precision_at_k(yp, score_vec, 500)),
    rec500  = suppressWarnings(recall_at_k(yp, score_vec, 500)),
    fl_enrich = { br <- mean(yp); if (br>0) mean(yp[fl14_vec==1])/br else NA_real_ })]
}
say("  Approach C done (matched-exposure label perm, B=%d)", B_PERM)

permB[, approach := "B_firm_exposure_sim"]; permC[, approach := "C_matched_label_perm"]
perm_all <- rbindlist(list(permB, permC))
fwrite(perm_all, file.path(dir_cache, "opportunity_permutation_metrics.csv"))

emp_p <- function(null_vec, obs) (1 + sum(null_vec >= obs, na.rm=TRUE)) / (1 + sum(!is.na(null_vec)))
pctile <- function(null_vec, obs) mean(null_vec <= obs, na.rm=TRUE)
perm_summary <- rbindlist(lapply(list(B=permB, C=permC), function(pm) {
  data.table(approach=pm$approach[1],
    obs_pr_auc=obs_pr, null_pr_mean=mean(pm$pr_auc,na.rm=TRUE), null_pr_p95=quantile(pm$pr_auc,0.95,na.rm=TRUE),
    p_pr=emp_p(pm$pr_auc,obs_pr), pctile_pr=pctile(pm$pr_auc,obs_pr),
    obs_roc=obs_auc, null_roc_mean=mean(pm$roc_auc,na.rm=TRUE), p_roc=emp_p(pm$roc_auc,obs_auc),
    obs_prec500=obs_p500, null_prec500_mean=mean(pm$prec500,na.rm=TRUE), p_prec500=emp_p(pm$prec500,obs_p500),
    obs_rec500=obs_r500, null_rec500_mean=mean(pm$rec500,na.rm=TRUE), p_rec500=emp_p(pm$rec500,obs_r500),
    obs_fl_enrich=obs_fl_enr, null_fl_enrich_mean=mean(pm$fl_enrich,na.rm=TRUE), p_fl_enrich=emp_p(pm$fl_enrich,obs_fl_enr))
}))
fwrite(perm_summary, file.path(dir_main_t, "table_D_opportunity_permutation_validation.csv"))
texH <- c("\\begin{table}[htbp]\\centering","\\caption{Cell-preserving permutation validation}",
  "\\label{tab:opp_permutation}","\\begin{tabular}{lrrrr}\\hline",
  "Approach & Obs. PR-AUC & Null mean & Null 95th & emp. $p$ \\\\\\hline",
  paste0(gsub("_","\\\\_",perm_summary$approach), " & ", sprintf("%.4f",perm_summary$obs_pr_auc), " & ",
         sprintf("%.4f",perm_summary$null_pr_mean), " & ", sprintf("%.4f",perm_summary$null_pr_p95), " & ",
         sprintf("%.4f",perm_summary$p_pr), " \\\\"),
  "\\hline\\end{tabular}",
  "\\begin{tablenotes}\\footnotesize\\item Approach B simulates firm-level contacts $O_i^{sim}=\\sum_g \\text{Binom}(n_{ig},p_g)$ preserving exposure; Approach C permutes labels within exposure-decile $\\times$ participation-bin strata. Given exposure-only AUC$=0.946$ the null is mechanically high.\\end{tablenotes}",
  "\\end{table}")
writeLines(texH, file.path(dir_main_t, "table_D_opportunity_permutation_validation.tex"))

# permutation figures
phist <- ggplot(perm_all, aes(pr_auc, fill=approach)) + geom_histogram(bins=40, alpha=0.6, position="identity") +
  geom_vline(xintercept=obs_pr, linetype="dashed", color="#9e1b32") +
  labs(x="PR-AUC under null", y="count", title="Permutation null for PR-AUC vs observed (dashed)") + theme_minimal()
ggsave(file.path(dir_main_f, "fig_opportunity_permutation_pr_auc.pdf"), phist, width=7, height=4.5, device=cairo_pdf)
 phist2 <- ggplot(perm_all, aes(prec500, fill=approach)) + geom_histogram(bins=40, alpha=0.6, position="identity") +
  geom_vline(xintercept=obs_p500, linetype="dashed", color="#9e1b32") +
  labs(x="Precision@500 under null", y="count", title="Permutation null for precision@500 vs observed") + theme_minimal()
ggsave(file.path(dir_app_f, "fig_opportunity_permutation_precision_at_k.pdf"), phist2, width=7, height=4.5, device=cairo_pdf)
say("wrote permutation table + 2 figures + metrics cache")
say("  OBS pr_auc=%.4f roc=%.4f prec500=%.4f rec500=%.4f fl_enrich=%.3f",
    obs_pr, obs_auc, obs_p500, obs_r500, obs_fl_enr)
say("  null(B) pr_auc mean=%.4f p=%.4f ; null(C) pr_auc mean=%.4f p=%.4f",
    perm_summary[approach=="B_firm_exposure_sim", null_pr_mean], perm_summary[approach=="B_firm_exposure_sim", p_pr],
    perm_summary[approach=="C_matched_label_perm", null_pr_mean], perm_summary[approach=="C_matched_label_perm", p_pr])
stamp("H_permutation")

# =============================================================================
# I. MATCHED / STRATIFIED  -> Table D-matched
# =============================================================================
say("\n----- I. matched / stratified validation -----")
mf <- exposure_stratified_matching_frame(as.data.frame(exf), exposure="log_opp", n_strata=10L, label="cobidder")
mf <- as.data.table(mf)
# within-stratum FL14 vs non-FL14 differences
strata_stats <- mf[, .(
  N=.N, n_fl=sum(fl14), n_nonfl=sum(fl14==0),
  dP_cob = if (sum(fl14)>0 && sum(fl14==0)>0) mean(cobidder[fl14==1]) - mean(cobidder[fl14==0]) else NA_real_,
  dO     = if (sum(fl14)>0 && sum(fl14==0)>0) mean(O_i[fl14==1]) - mean(O_i[fl14==0]) else NA_real_,
  dX     = if (sum(fl14)>0 && sum(fl14==0)>0) mean(X_i_MEDIUM[fl14==1]) - mean(X_i_MEDIUM[fl14==0]) else NA_real_
), by=exposure_stratum][order(exposure_stratum)]
rank_corr <- suppressWarnings(cor(mf$score_i, mf$X_i_MEDIUM, method="spearman"))
within_auc <- strat_auc(mf, "score_i", "cobidder", "exposure_stratum")
# CEM on opportunity (mirror 76 step 9)
cutp <- unique(quantile(exf$n_opp_items, probs=seq(0,1,0.1)))
mm <- tryCatch(matchit(cobidder ~ n_opp_items, data=as.data.frame(exf), method="cem",
                       cutpoints=list(n_opp_items=cutp)), error=function(e) NULL)
cem_auc <- NA_real_; cem_n <- NA_integer_
if (!is.null(mm)) {
  md <- as.data.table(match.data(mm))
  cem_auc <- auc_ci("cobidder","score_i", md)$auc; cem_n <- nrow(md)
}
matched_out <- list(
  per_stratum = strata_stats,
  summary = data.table(
    mean_dP_cob = mean(strata_stats$dP_cob, na.rm=TRUE),
    mean_dO     = mean(strata_stats$dO, na.rm=TRUE),
    mean_dX     = mean(strata_stats$dX, na.rm=TRUE),
    spearman_score_excess = rank_corr,
    within_stratum_auc_score = within_auc$auc,
    cem_opp_matched_auc = cem_auc, cem_matched_n = cem_n,
    support_retained_share = nrow(mf)/nrow(exf))
)
fwrite(strata_stats, file.path(dir_app_t, "table_D_matched_opportunity_validation.csv"))
fwrite(matched_out$summary, file.path(dir_app_t, "table_D_matched_opportunity_validation_summary.csv"))
texI <- c("\\begin{table}[htbp]\\centering","\\caption{Matched / stratified opportunity validation}",
  "\\label{tab:opp_matched}","\\begin{tabular}{rrrrr}\\hline",
  "Exposure stratum & N & $\\Delta$P(cob) & $\\Delta O_i$ & $\\Delta X_i$ \\\\\\hline",
  paste0(strata_stats$exposure_stratum, " & ", strata_stats$N, " & ",
         ifelse(is.na(strata_stats$dP_cob),"--",sprintf("%.4f",strata_stats$dP_cob)), " & ",
         ifelse(is.na(strata_stats$dO),"--",sprintf("%.3f",strata_stats$dO)), " & ",
         ifelse(is.na(strata_stats$dX),"--",sprintf("%.3f",strata_stats$dX)), " \\\\"),
  "\\hline\\end{tabular}",
  sprintf("\\begin{tablenotes}\\footnotesize\\item Within-stratum AUC of score = %.4f; CEM-opp-matched AUC = %.4f (n=%s); Spearman(score, excess) = %.3f.\\end{tablenotes}",
          within_auc$auc, cem_auc, format(cem_n, big.mark=","), rank_corr),
  "\\end{table}")
writeLines(texI, file.path(dir_app_t, "table_D_matched_opportunity_validation.tex"))
say("  mean within-stratum dP(cobidder) FL14 vs non = %+.4f ; within-stratum AUC=%.4f ; CEM AUC=%.4f (n=%s) ; support retained=%.1f%%",
    matched_out$summary$mean_dP_cob, within_auc$auc, cem_auc, format(cem_n, big.mark=","), 100*nrow(mf)/nrow(exf))
stamp("I_matched")

# =============================================================================
# J. CASE / BUYER / ITEM-GROUP CONTRIBUTION
# =============================================================================
say("\n----- J. case / buyer / item-group contribution -----")
# For opportunity-adjusted positives (cobidders), decompose O_i, X_i, TP@500 by case/buyer/ig.
# Re-run the contact join carrying case + buyer + ig for AL firms.
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", SPILL))  # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05)
register_keymap(con)   # FED-only keymap; no-op for BEC
dbWriteTable(con, "direct", data.frame(firm_code=direct_codes), overwrite=TRUE)
dbWriteTable(con, "def_case", as.data.frame(def_case_map[, .(firm_code, processo)]), overwrite=TRUE)
dbWriteTable(con, "al_firms", data.frame(firm_code=al$firm_code), overwrite=TRUE)
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): buyer(pbu)/ig via ftm_keyed
# (BEC substrings ; FED codigo_ug + codigoitem prefix), not raw numerodaoc substrings.
contrib <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (%s),
  def_items AS (
    SELECT DISTINCT f.oc, f.item, f.firm_code AS def_code
    FROM ftm f JOIN direct d ON f.firm_code=d.firm_code
  ),
  contact AS (
    SELECT f.firm_code, f.oc, f.item, f.pbu, f.ig, dc.processo
    FROM ftm f
    JOIN al_firms a ON f.firm_code=a.firm_code
    JOIN def_items di ON f.oc=di.oc AND f.item=di.item AND f.firm_code<>di.def_code
    JOIN def_case dc ON di.def_code=dc.firm_code
  )
  SELECT firm_code, processo, pbu, ig, COUNT(DISTINCT (oc||'|'||item)) AS n_contact
  FROM contact GROUP BY firm_code, processo, pbu, ig
", ftm_keyed_sql())))
dbDisconnect(con, shutdown=TRUE); gc()

# positives = cobidders; restrict
cob_set <- al[cobidder==1, firm_code]
ctr_pos <- contrib[firm_code %in% cob_set]
# top-500 by score (TP among cobidders)
setorder(ff, -score_i)
top500 <- ff[1:500, firm_code]
tp500_set <- intersect(top500, cob_set)

share_by <- function(d, keyv) {
  agg <- d[, .(n_contact=sum(n_contact)), by=keyv]
  agg[, share := n_contact/sum(n_contact)]
  setorder(agg, -share); agg
}
by_case  <- share_by(ctr_pos, "processo")
by_buyer <- share_by(ctr_pos, "pbu")
# SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): item-group decomposition.
# Only meaningful where item-group is observed (BEC). Federally ig is the constant
# sentinel, so the by-ig decomposition is a single vacuous group -> emit NA + note.
by_ig    <- if (HAS_IG) { share_by(ctr_pos, "ig")
            } else { data.table(ig = NA_character_, n_contact = NA_integer_, share = NA_real_) }
# TP@500 share by case
tp_contrib <- contrib[firm_code %in% tp500_set]
tp_by_case <- if (nrow(tp_contrib)) share_by(tp_contrib, "processo") else data.table(processo=character(), n_contact=integer(), share=numeric())

contribution <- rbindlist(list(
  cbind(dimension="case",  by_case[,  .(key=processo, n_contact, share)],
        cell_definition_note = ""),
  cbind(dimension="buyer", by_buyer[, .(key=pbu, n_contact, share)],
        cell_definition_note = ""),
  cbind(dimension="item_group", by_ig[, .(key=ig, n_contact, share)],
        cell_definition_note = if (HAS_IG) "" else ig_note)
), fill=TRUE)
fwrite(contribution, file.path(dir_diag, "opportunity_case_buyer_contribution.csv"))

flag_case  <- by_case[1, share]  > 0.5
flag_buyer <- by_buyer[1, share] > 0.5
flag_ig    <- HAS_IG && isTRUE(by_ig[1, share] > 0.5)
say("  top case  %s share of cobidder contacts = %.1f%%  %s", by_case[1,processo], 100*by_case[1,share], ifelse(flag_case," >>>FLAG>50%",""))
say("  top buyer %s share = %.1f%%  %s", by_buyer[1,pbu], 100*by_buyer[1,share], ifelse(flag_buyer," >>>FLAG>50%",""))
if (HAS_IG) { say("  top item-group %s share = %.1f%%  %s", by_ig[1,ig], 100*by_ig[1,share], ifelse(flag_ig," >>>FLAG>50%","")) } else { say("  item-group decomposition: NA  (%s)", ig_note) }
if (nrow(tp_by_case)) say("  TP@500 top case %s share = %.1f%%", tp_by_case[1,processo], 100*tp_by_case[1,share])
stamp("J_contribution")

# =============================================================================
# VERDICT
# =============================================================================
say("\n========== VERDICT ==========")
say("exposure-only AUC: unconditional(all AL)=%.4f (locked 0.946) ; logit-within-exposed=%.4f (locked 0.8467)",
    uncond_exp_auc, as.numeric(r_opp$auc))
say("within-stratum log_tc=%.4f (locked 0.7715) ; nested increment=%+.4f DeLong p=%.3g (locked +0.0415, 2.08e-06) ; exposed n=%d (locked 6040) ; npos=%d (locked 191)",
    s_log$auc, incr, dl$p.value, nrow(exf), exf[cobidder==1,.N])
verdict <- if (s_log$auc >= 0.70 && incr >= 0.02 && dl$p.value < 0.05) {
  if (s_log$auc >= 0.85) "A (survives strong)" else "B (attenuates but significant residual remains)"
} else "C (signal disappears under exposure adjustment)"
say("VERDICT: %s", verdict)
say("\nALL DONE.")
stamp("DONE")
