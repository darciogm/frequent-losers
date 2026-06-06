#!/usr/bin/env Rscript
# =============================================================================
# 04_case_holdout_dominance.R  --  JLEO R&R (v22) -- CASE-DOMINANCE TEST
#
# Question: is the frequent-loser screen's CADE validation driven by ONE case /
# buyer / item-group, or is it BROAD? This is the case-dominance credibility
# test. Be exact, never invent, never hide case dominance.
#
# Candidate set = always-losers (16,843). Score_i = log1p(tenders_count)
# (CADE-label-INDEPENDENT -> no leakage). Positives = the canonical broad AL
# cobidder label (651, reproducible, FL never used) that are in the always-loser
# universe and are NOT direct defendants. Direct CADE
# defendants (crossmatch, 47) are EXCLUDED from the candidate set entirely
# (NEW HOPE 09474700000192 is miscoded as both -> treated as defendant only,
# excluded from positives).
#
# Steps:
#   A  Leave-one-case-out (LOCO)             -> table_G + fig_loco_distribution
#   B  Case-dominance / leave-largest / cov  -> table_H + case_dominance_summary
#                                                + fig_case_positive_concentration
#   C  Environment dominance (buyer/item/...) -> table_D_environment_dominance
#   D  Leave-one-defendant-group-out          -> table_D_leave_one_defendant_group_out
#   E  Clustered randomization inference       -> table_D_clustered_randomization_inference
#
# Run:
#   cd <repo>; Rscript work/v22-editor/scripts/analysis/04_case_holdout_dominance.R \
#     2>&1 | tee work/v22-editor/outputs/logs/case_holdout_dominance.log
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow); library(ggplot2)
})

# ---- locate repo + dirs -----------------------------------------------------
if (!exists(".script_dir")) {
  fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
  .script_dir <- if (length(fa)) dirname(normalizePath(fa[1L])) else getwd()
}
REPO <- normalizePath(file.path(.script_dir, "..", "..", "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(REPO, "data", "processed")))
  REPO <- normalizePath("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
V22  <- file.path(REPO, "work", "v22-editor")
UTIL <- file.path(V22, "scripts", "utils")
DOCS <- file.path(V22, "docs", "jleo_rr_revision")

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): one config, zero forked logic.
# --source= flag (default "bec"); ALL paths/constants/lambdas from get_source_config().
.src_arg <- sub("^--source=", "",
                commandArgs(TRUE)[grep("^--source=", commandArgs(TRUE))])
SRC <- if (length(.src_arg)) .src_arg[1L] else "bec"
source(file.path(UTIL, "source_config.R"))
cfg <- get_source_config(SRC)
cfg$ensure_dirs()

DATA <- cfg$data_dir
OUT  <- cfg$out_root

source(file.path(UTIL, "metrics_triage.R"))

dir_main_t <- cfg$dirs$tables_main
dir_app_t  <- cfg$dirs$tables_app
dir_main_f <- cfg$dirs$figures_main
dir_app_f  <- cfg$dirs$figures_app
dir_diag   <- cfg$dirs$diagnostics
dir_cache  <- cfg$dirs$cache
dir_logs   <- cfg$dirs$logs
for (d in c(dir_main_t, dir_app_t, dir_main_f, dir_app_f, dir_diag, dir_cache, dir_logs, DOCS))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$temp_directory, recursive = TRUE, showWarnings = FALSE)

setDTthreads(12L)
SEED <- 20260603L
set.seed(SEED)

# ---- telemetry --------------------------------------------------------------
LOG <- file.path(dir_diag, "case_holdout_dominance_audit_log.txt")
.t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern=TRUE))/1024), error=function(e) NA_real_)
stamp <- function(s) say("  [stage %-26s] elapsed=%6.1fs  RSS=%s MB", s, as.numeric(difftime(Sys.time(),.t0,units="secs")), rss_mb())

say("=== 04_case_holdout_dominance.R ===")
say("host=%s  nproc=%s  seed=%d  date=%s  RAM_free=%s",
    Sys.info()[["nodename"]],
    tryCatch(system("nproc", intern=TRUE), error=function(e)"?"), SEED, format(Sys.time()),
    tryCatch(system("free -h | awk 'NR==2{print $7}'", intern=TRUE), error=function(e)"?"))
say("REPO=%s", REPO)

# SOURCE-CONFIG ADAPTATION (Phase 1 estrang-fix, 2026-06-05): source-gated 14-char
# normalizer. BEC -> exact legacy literal sprintf("%014.0f", as.numeric(x)) (byte-
# identity, gate R1, incl. the '-1' sentinel). Federal -> numeric pad14 / non-numeric
# (ESTRANG* foreign suppliers, 14-char junk) RAW passthrough -- they legitimately
# never match a CADE CNPJ; never NA-collapse them. Proven equivalent on BEC vectors.
norm14 <- cfg$norm14_safe

# safe metric wrappers (return NA / count on degenerate input, never error out)
safe <- function(expr) tryCatch(suppressWarnings(expr), error = function(e) NA_real_)
m_rocauc <- function(y, s) if (sum(y==1)<1 || sum(y==0)<1) NA_real_ else safe(roc_auc(y, s))
m_prauc  <- function(y, s) if (sum(y==1)<1) NA_real_ else safe(average_precision(y, s))
m_prec   <- function(y, s, k) safe(precision_at_k(y, s, k))
m_rec    <- function(y, s, k) if (sum(y==1)<1) NA_real_ else safe(recall_at_k(y, s, k))
m_lift   <- function(y, s, k) if (sum(y==1)<1) NA_real_ else safe(lift_at_k(y, s, k))
m_fp     <- function(y, s, k) safe(false_positives_at_k(y, s, k))

# =============================================================================
# A. CANDIDATE SET + LABELS + CASE LINKAGE
# =============================================================================
say("\n========== A. CANDIDATE SET ==========")

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): canonical broad AL cobidder label
# (BEC: 651, reproducible, FL never used). positives = rows with broad_cobidder==1.
# Cache lives in this source's cache dir (cfg$dirs$cache).
canon_cobid_path <- file.path(cfg$dirs$cache, "canonical_cobidders_broad.csv")
if (!file.exists(canon_cobid_path)) {
  stop(sprintf(paste0(
    "BLOCKER (source=%s): canonical broad-cobidder label not found at %s.\n",
    "  For BEC this ships in outputs/cache/. For ComprasNet it is produced by the\n",
    "  Phase-1 canonical federal cobidder rebuild (NOT YET RUN as of 2026-06-05);\n",
    "  cobidders_federal.parquet is SET-COMPARISON ONLY, not a substitute."),
    SRC, canon_cobid_path))
}
cob <- fread(canon_cobid_path)
cob <- cob[broad_cobidder == 1L]
cob[, firm_code := norm14(`códigofornecedor`)]
cob_codes <- unique(cob$firm_code)
say("cobidder positives (canonical broad): %d rows, %d distinct firm_code", nrow(cob), length(cob_codes))

# Direct CADE defendants. BEC: cade_bec_crossmatch.csv (firm_cnpj). FEDERAL:
# direct_defendants_federal.parquet (firm_id = 14-digit estab CNPJ), with a
# firm->processo map; the unnumbered TI/DF case (empty processo) is EXCLUDED from
# any case-anchored use (gate G3: no CADE process number = unverifiable anchor).
if (cfg$cade_layout == "bec_csv") {
  xm <- fread(cfg$cade$crossmatch)
  xm[, firm_code := norm14(firm_cnpj)]
  direct_codes_raw <- unique(xm$firm_code)
  def_proc_map <- unique(xm[, .(firm_code, proc = processo)])
} else {
  dd <- as.data.table(read_parquet(cfg$cade$direct_defendants))
  dd[, firm_code := norm14(firm_id)]
  n_unnum <- dd[is.na(processo) | trimws(processo) == "", uniqueN(firm_code)]
  dd_num  <- dd[!is.na(processo) & trimws(processo) != ""]   # drop TI/DF (unnumbered)
  say("FEDERAL defendants: %d numbered cases; dropped %d estab(s) of the unnumbered TI/DF case (gate G3)",
      uniqueN(dd_num$processo), n_unnum)
  # ALL defendant estabs (numbered + unnumbered) are excluded from the candidate
  # set; but only NUMBERED-case defendants drive case-anchored linkage.
  direct_codes_raw <- unique(dd$firm_code)
  def_proc_map <- unique(dd_num[, .(firm_code, proc = processo)])
}
say("direct CADE defendants (raw, all): %d distinct firm_code", length(direct_codes_raw))

# NEW HOPE-style overlap: a firm both cobidder-positive AND direct-defendant ->
# treat as DEFENDANT only (exclude from positives AND from candidate set).
overlap <- intersect(direct_codes_raw, cob_codes)
say("overlap cobidder/defendant (excluded from positives, kept as defendant): %d {%s}",
    length(overlap), paste(overlap, collapse=","))

# always-loser candidate universe
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): FREQ_PARTICIP path + FL cut from cfg.
fp <- as.data.table(read_parquet(cfg$freq_particip))
fp[, firm_code := norm14(`códigofornecedor`)]
al <- fp[always_loser == 1L, .(firm_code, T_i = tenders_count)]
# EXCLUDE direct defendants from the candidate set
al <- al[!firm_code %in% direct_codes_raw]
setorder(al, firm_code)
al[, firm_id := .I]                                   # anonymized deterministic id
al[, score_i  := log1p(T_i)]
al[, fl14      := as.integer(cfg$fl_predicate(T_i))]  # BEC >=14 ; FED >=32
# positive label = cobidder & in candidate universe & not a defendant
pos_codes <- setdiff(cob_codes, direct_codes_raw)
al[, cobidder := as.integer(firm_code %in% pos_codes)]
say("candidate set (always-losers minus %d direct defendants): %d firms",
    length(intersect(direct_codes_raw, fp[always_loser==1L]$firm_code)), nrow(al))
say("positives (cobidder, in candidate set): %d", al[cobidder==1L, .N])
.cob_not_al <- sum(!pos_codes %in% al$firm_code)
say("positive codes not in candidate universe (excluded from npos): %d", .cob_not_al)

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): case linkage source per cfg.
# BEC: cobidder->case map in output/label_funnel/case_cobidder_map.csv (is_AL flag).
# FEDERAL: there is no federal cobidder->case map yet (Phase-1 canonical cobidder
# rebuild produces it). Until then the federal LOCO cannot run -> clear blocker.
if (cfg$cade_layout == "bec_csv") {
  ccm <- fread(file.path(REPO, "output", "label_funnel", "case_cobidder_map.csv"),
               colClasses = list(character = c("cnpj","proc")))
  ccm[, firm_code := norm14(cnpj)]
  # AL cobidder -> case links, restricted to firms in our positive candidate set
  case_links <- unique(ccm[is_AL == 1L & firm_code %in% al[cobidder==1L]$firm_code,
                           .(firm_code, proc)])
} else {
  fed_ccm <- file.path(cfg$dirs$cache, "case_cobidder_map_federal.csv")
  if (!file.exists(fed_ccm)) {
    stop(sprintf(paste0(
      "BLOCKER (source=%s): federal cobidder->case map not found at %s.\n",
      "  LOCO requires AL-cobidder -> processo links restricted to the 7 NUMBERED\n",
      "  federal cases (TI/DF excluded, gate G3). This map is produced by the Phase-1\n",
      "  canonical federal cobidder rebuild (NOT YET RUN as of 2026-06-05). Build it,\n",
      "  then re-run. The numbered-case anchor (def_proc_map) is already wired."), SRC, fed_ccm))
  }
  ccm <- fread(fed_ccm, colClasses = list(character = c("cnpj","proc")))
  ccm[, firm_code := norm14(cnpj)]
  # restrict to NUMBERED cases only (gate G3) and to positive candidates
  numbered_procs <- unique(def_proc_map$proc)
  case_links <- unique(ccm[firm_code %in% al[cobidder==1L]$firm_code &
                           proc %in% numbered_procs, .(firm_code, proc)])
}
say("AL-cobidder -> case link rows: %d ; distinct firms linked: %d ; distinct cases: %d",
    nrow(case_links), uniqueN(case_links$firm_code), uniqueN(case_links$proc))
n_pos      <- al[cobidder==1L, .N]
n_linked   <- uniqueN(case_links$firm_code)
n_unlinked <- n_pos - n_linked
say("positives linked to >=1 CADE case: %d ; UNLINKED positives (no case in map): %d",
    n_linked, n_unlinked)
say("NOTE: %d unlinked positives stay in the FULL validation but cannot be assigned to a LOCO case.", n_unlinked)

# per-case positive counts
case_pos <- case_links[, .(n_pos_case = uniqueN(firm_code)), by = proc][order(-n_pos_case)]
say("--- positive cobidders per case (linked) ---")
for (i in seq_len(nrow(case_pos))) say("  %-22s : %d", case_pos$proc[i], case_pos$n_pos_case[i])
largest_case <- case_pos$proc[1]
say("LARGEST case = %s (%d positives, %.1f%% of linked, %.1f%% of all positives)",
    largest_case, case_pos$n_pos_case[1],
    100*case_pos$n_pos_case[1]/n_linked, 100*case_pos$n_pos_case[1]/n_pos)

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): case metadata (sector / defendant
# count) for labelling. BEC: output/label_funnel/case_timing.csv. FEDERAL: derived
# from direct_defendants_federal.parquet (numbered cases only; setor + estab count).
if (cfg$cade_layout == "bec_csv") {
  ctime <- fread(file.path(REPO, "output", "label_funnel", "case_timing.csv"),
                 colClasses = list(character = "proc"))
  case_meta <- merge(case_pos, ctime[, .(proc, setor, n_bec_defendants)], by="proc", all.x=TRUE)
} else {
  ctime <- unique(dd_num[, .(proc = processo, setor)])[
    , .(setor = setor[1], n_bec_defendants = .N), by = proc]
  case_meta <- merge(case_pos, ctime, by="proc", all.x=TRUE)
}
stamp("A_candidate_set")

# =============================================================================
# B0. OBSERVED DEFENDANT CONTACT O_i + per-case contact (DuckDB self-join)
#     Also: environment attributes of each positive (buyer/item_group/modality/year).
# =============================================================================
say("\n========== B0. defendant contact O_i + environment (DuckDB) ==========")
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): paths + spill dir + item-panel
# item-column name from cfg. BEC item panel uses `codigoitem` (no accent); federal
# `item_level_panel` uses `códigoitem` (accent). The buyer/year derivation also
# differs (see below).
ftm_path <- cfg$firm_tender_map
ivp_path <- cfg$item_panel
IVP_ITEM_COL <- cfg$item_panel_item_col       # "codigoitem" (BEC) | "códigoitem" (FED)
# SOURCE-CONFIG ADAPTATION (Phase 1 estrang-fix, 2026-06-05): in-SQL firm-code
# normalizer expr. BEC -> exact legacy printf('%014.0f', CAST(... AS DOUBLE)) (byte-
# identity). Federal -> numeric pad14 / non-numeric (ESTRANG*, 14-char junk) RAW
# (CAST AS DOUBLE would crash on 'ESTRANG...'). Proven 0-mismatch on BEC distinct codes.
FC_SQL <- cfg$norm14_sql_expr("\"códigofornecedor\"")
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=12"); dbExecute(con, "PRAGMA memory_limit='12GB'")
dbExecute(con, sprintf("PRAGMA temp_directory='%s'", cfg$temp_directory))

direct_codes <- setdiff(direct_codes_raw, pos_codes)   # winners-only defendant set
dbWriteTable(con, "direct", data.frame(firm_code = direct_codes), overwrite = TRUE)
# defendant -> case map (a defendant may map to >=1 case). cfg-driven: BEC uses the
# crossmatch processo; FEDERAL uses def_proc_map (numbered cases only, TI/DF dropped).
def_case <- unique(def_proc_map[firm_code %in% direct_codes, .(firm_code, proc)])
dbWriteTable(con, "def_case", as.data.frame(def_case), overwrite = TRUE)

# O_i = # distinct (oc,item) where firm i AND >=1 direct defendant co-appear.
contact <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT %s AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc,
           CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')),
  def_items AS (
    SELECT DISTINCT f.oc, f.item
    FROM ftm f JOIN direct d ON f.firm_code = d.firm_code),
  firm_contact AS (
    SELECT DISTINCT f.firm_code, f.oc, f.item
    FROM ftm f JOIN def_items di ON f.oc=di.oc AND f.item=di.item)
  SELECT firm_code, COUNT(*) AS O_i
  FROM firm_contact
  GROUP BY firm_code", FC_SQL, ftm_path)))
say("firms with O_i>0 (any defendant contact): %s", format(nrow(contact), big.mark=","))

# per-firm contact BY CASE (which case's defendants did firm i touch)
contact_case <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT %s AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')),
  def_items AS (
    SELECT DISTINCT f.firm_code AS def_code, f.oc, f.item
    FROM ftm f JOIN direct d ON f.firm_code = d.firm_code),
  fc AS (
    SELECT DISTINCT f.firm_code, di.def_code, f.oc, f.item
    FROM ftm f JOIN def_items di ON f.oc=di.oc AND f.item=di.item),
  fcc AS (
    SELECT DISTINCT fc.firm_code, dc.proc, fc.oc, fc.item
    FROM fc JOIN def_case dc ON fc.def_code = dc.firm_code)
  SELECT firm_code, proc, COUNT(*) AS contact_items
  FROM fcc GROUP BY firm_code, proc", FC_SQL, ftm_path)))
say("firm x case contact rows: %s", format(nrow(contact_case), big.mark=","))

# Environment attributes of each POSITIVE firm: where do its participations live?
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): buyer / year / modality derivation
# differs by source (gate G1/G5).
#   BEC : buyer = SUBSTR(oc,1,11); year = SUBSTR(oc,12,4); modality = panel `modality`
#         (1/3); item panel item column = `codigoitem` (no accent).
#   FED : buyer = panel `codigo_ug` (NOT a substring); year = panel `year` (result
#         year, NOT the numbering year in oc); modality = panel `po_phase_code`
#         (5/9999); item panel item column = `códigoitem` (accent).
#   item_group = SUBSTR(item,1,2) in both (item-code prefix is source-agnostic).
pos_tab <- data.frame(firm_code = al[cobidder==1L]$firm_code)
dbWriteTable(con, "pos", pos_tab, overwrite = TRUE)
if (cfg$key_is_composite) {
  pos_env <- as.data.table(dbGetQuery(con, sprintf("
    WITH ftm AS (
      SELECT %s AS firm_code,
             CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
      FROM read_parquet('%s')),
    ivp AS (
      SELECT CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"%s\" AS VARCHAR) AS item,
             CAST(%s AS VARCHAR) AS modality
      FROM read_parquet('%s'))
    SELECT f.firm_code, f.oc, f.item,
           %s AS buyer,
           SUBSTR(f.item,1,2) AS item_group,
           %s AS year,
           v.modality AS modality
    FROM ftm f JOIN pos p ON f.firm_code = p.firm_code
    LEFT JOIN ivp v ON f.oc = v.oc AND f.item = v.item",
    FC_SQL, ftm_path, IVP_ITEM_COL, cfg$modality_col, ivp_path,
    cfg$buyer_from_key("f.oc"), cfg$year_from_key("f.oc"))))
} else {
  # FEDERAL: buyer (codigo_ug), result year, modality (po_phase_code) ALL from panel.
  pos_env <- as.data.table(dbGetQuery(con, sprintf("
    WITH ftm AS (
      SELECT %s AS firm_code,
             CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
      FROM read_parquet('%s')),
    ivp AS (
      SELECT CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"%s\" AS VARCHAR) AS item,
             CAST(\"%s\" AS VARCHAR) AS buyer,
             CAST(year AS VARCHAR) AS year,
             CAST(%s AS VARCHAR) AS modality
      FROM read_parquet('%s'))
    SELECT f.firm_code, f.oc, f.item,
           v.buyer AS buyer,
           SUBSTR(f.item,1,2) AS item_group,
           v.year AS year,
           v.modality AS modality
    FROM ftm f JOIN pos p ON f.firm_code = p.firm_code
    LEFT JOIN ivp v ON f.oc = v.oc AND f.item = v.item",
    FC_SQL, ftm_path, IVP_ITEM_COL, cfg$buyer_col, cfg$modality_col, ivp_path)))
}
say("positive-firm participation rows (with env): %s", format(nrow(pos_env), big.mark=","))
say("positive participations with modality matched: %.1f%%",
    100*mean(!is.na(pos_env$modality)))
dbDisconnect(con, shutdown = TRUE)
stamp("B0_contact_env")

# merge O_i into al
al <- merge(al, contact[, .(firm_code, O_i)], by="firm_code", all.x=TRUE)
al[is.na(O_i), O_i := 0L]
total_O_pos <- al[cobidder==1L, sum(O_i)]

# =============================================================================
# A2. LEAVE-ONE-CASE-OUT (LOCO)  -- Step 9
# For each case c: held-out positives = AL cobidders linked to c.
# Evaluate on candidate set (always-losers minus defendants); positives = ONLY
# this case's cobidders; all OTHER positives EXCLUDED from the evaluation set
# (LOCO convention: do not let other cases' positives pollute negatives).
# Score = raw award-layer score_i = log1p(T_i) (CADE-label-independent -> no leakage).
# =============================================================================
say("\n========== A. LEAVE-ONE-CASE-OUT (LOCO) ==========")
all_cases <- case_pos$proc
TOO_SPARSE_MIN <- 5L   # < 5 positives -> AUC unstable, mark too_sparse

loco_rows <- list()
for (c in all_cases) {
  held <- case_links[proc == c, firm_code]                 # this case's positives
  other_pos <- setdiff(al[cobidder==1L]$firm_code, held)   # all other positives
  # evaluation frame: exclude other-case positives entirely
  ev <- al[!firm_code %in% other_pos]
  ev[, y := as.integer(firm_code %in% held)]
  npos <- sum(ev$y)
  ncand <- nrow(ev)
  # environment concentration in held-out positives
  env_h <- pos_env[firm_code %in% held]
  lg_buyer <- if (nrow(env_h)) {
    t <- env_h[, .(n=uniqueN(firm_code)), by=buyer]; max(t$n)/uniqueN(env_h$firm_code)
  } else NA_real_
  lg_item  <- if (nrow(env_h)) {
    t <- env_h[, .(n=uniqueN(firm_code)), by=item_group]; max(t$n)/uniqueN(env_h$firm_code)
  } else NA_real_
  meta <- case_meta[proc==c]
  loco_rows[[c]] <- data.table(
    case = c,
    setor = if (nrow(meta)) meta$setor else NA_character_,
    n_defendants = if (nrow(meta)) meta$n_bec_defendants else NA_integer_,
    n_candidates = ncand,
    positives = npos,
    prevalence = npos/ncand,
    too_sparse = npos < TOO_SPARSE_MIN,
    roc_auc = m_rocauc(ev$y, ev$score_i),
    pr_auc  = m_prauc(ev$y, ev$score_i),
    prec_100 = m_prec(ev$y, ev$score_i, 100),
    prec_250 = m_prec(ev$y, ev$score_i, 250),
    prec_500 = m_prec(ev$y, ev$score_i, 500),
    rec_100  = m_rec(ev$y, ev$score_i, 100),
    rec_250  = m_rec(ev$y, ev$score_i, 250),
    rec_500  = m_rec(ev$y, ev$score_i, 500),
    lift_500 = m_lift(ev$y, ev$score_i, 500),
    fp_500   = m_fp(ev$y, ev$score_i, 500),
    largest_buyer_share = lg_buyer,
    largest_item_group_share = lg_item)
}
loco <- rbindlist(loco_rows)[order(-positives)]
say("--- LOCO per-case (sorted by positives) ---")
print(loco[, .(case, positives, too_sparse, roc_auc=round(roc_auc,3),
               pr_auc=round(pr_auc,3), rec_500=round(rec_500,3),
               prec_500=round(prec_500,4))])
n_ts <- sum(loco$too_sparse)
say("cases too_sparse (<%d pos): %d of %d", TOO_SPARSE_MIN, n_ts, nrow(loco))
say("LOCO PR-AUC : mean=%.3f min=%.3f max=%.3f (over %d evaluable)",
    mean(loco$pr_auc, na.rm=TRUE), min(loco$pr_auc, na.rm=TRUE), max(loco$pr_auc, na.rm=TRUE),
    sum(!is.na(loco$pr_auc)))
say("LOCO recall@500 : mean=%.3f min=%.3f max=%.3f",
    mean(loco$rec_500, na.rm=TRUE), min(loco$rec_500, na.rm=TRUE), max(loco$rec_500, na.rm=TRUE))
say("LOCO ROC-AUC : mean=%.3f min=%.3f max=%.3f (non-too-sparse: mean=%.3f)",
    mean(loco$roc_auc, na.rm=TRUE), min(loco$roc_auc, na.rm=TRUE), max(loco$roc_auc, na.rm=TRUE),
    mean(loco[too_sparse==FALSE]$roc_auc, na.rm=TRUE))

fwrite(loco, file.path(dir_main_t, "table_G_leave_one_case_out_validation.csv"))

# LaTeX for table G
fmt <- function(x, d=3) ifelse(is.na(x), "--", formatC(x, format="f", digits=d))
texG <- c(
  "% table_G_leave_one_case_out_validation.tex  (auto: 04_case_holdout_dominance.R)",
  "\\begin{tabular}{lrrccccc}",
  "\\toprule",
  "Case (sector) & $N_{cand}$ & Pos & Prev & ROC-AUC & PR-AUC & Rec@500 & Prec@500 \\\\",
  "\\midrule",
  vapply(seq_len(nrow(loco)), function(i) sprintf("%s & %s & %s & %s & %s & %s & %s & %s \\\\",
    gsub("_","\\\\_", paste0(substr(loco$case[i],7,18)," (",loco$setor[i],")")),
    format(loco$n_candidates[i], big.mark=","),
    loco$positives[i],
    fmt(loco$prevalence[i],4),
    if (isTRUE(loco$too_sparse[i])) "\\emph{sparse}" else fmt(loco$roc_auc[i]),
    fmt(loco$pr_auc[i]),
    fmt(loco$rec_500[i]),
    fmt(loco$prec_500[i],4)), character(1)),
  "\\bottomrule", "\\end{tabular}")
writeLines(texG, file.path(dir_main_t, "table_G_leave_one_case_out_validation.tex"))
stamp("A_loco")

# LOCO distribution figure
loco_long <- rbindlist(list(
  data.table(metric="PR-AUC", value=loco$pr_auc, case=loco$case),
  data.table(metric="Recall@500", value=loco$rec_500, case=loco$case),
  data.table(metric="Precision@500", value=loco$prec_500, case=loco$case)))
pG <- ggplot(loco_long[!is.na(value)], aes(x=metric, y=value)) +
  geom_boxplot(outlier.shape=NA, fill="grey90", width=0.5) +
  geom_jitter(width=0.12, height=0, size=2, alpha=0.8, colour="#9B1B30") +
  labs(title="Leave-one-case-out: metric distribution across CADE cases",
       subtitle=sprintf("%d cases; score = log1p(tenders_count), CADE-label-independent", nrow(loco)),
       x=NULL, y="Value") + theme_minimal(base_size=11)
ggsave(file.path(dir_main_f, "fig_leave_one_case_out_distribution.pdf"), pG,
       width=7, height=4.5, device=cairo_pdf)
say("wrote fig_leave_one_case_out_distribution.pdf")

# =============================================================================
# B. CASE-DOMINANCE SUMMARY + LEAVE-LARGEST/TOP-TWO + COVERAGE  -- Step 10
# =============================================================================
say("\n========== B. CASE-DOMINANCE SUMMARY ==========")

# rank ALL candidates by score; identify TP@k (positives landing in top-k)
setorder(al, -score_i, firm_id)            # deterministic tie-break by firm_id
al[, rank := .I]
ks <- c(100, 250, 500, 1000)
pos_all <- al[cobidder==1L]

# per-case: share of positive cobidders, share of FL cobidders, share of TP@k,
# share of O_i contact (= contact_items to that case / total positive contact)
fl_pos_codes <- pos_all[fl14==1L]$firm_code
case_contact <- contact_case[firm_code %in% pos_all$firm_code, .(contact_items=sum(contact_items)), by=proc]
total_pos_contact_cased <- sum(case_contact$contact_items)

cds_rows <- list()
for (c in all_cases) {
  held <- case_links[proc==c, firm_code]
  share_pos <- length(held)/n_pos
  share_fl  <- if (length(fl_pos_codes)) sum(held %in% fl_pos_codes)/length(fl_pos_codes) else NA_real_
  tpk <- sapply(ks, function(k) {
    tp_codes <- al[rank<=k & cobidder==1L]$firm_code
    if (length(tp_codes)) sum(held %in% tp_codes)/length(tp_codes) else NA_real_
  })
  cc <- case_contact[proc==c, contact_items]
  share_contact <- if (length(cc) && total_pos_contact_cased>0) cc/total_pos_contact_cased else 0
  cds_rows[[c]] <- data.table(case=c,
    n_pos=length(held), share_pos=share_pos, share_fl=share_fl,
    share_tp_100=tpk[1], share_tp_250=tpk[2], share_tp_500=tpk[3], share_tp_1000=tpk[4],
    share_O_contact=share_contact)
}
cds <- rbindlist(cds_rows)[order(-n_pos)]
say("--- case_dominance_summary ---")
print(cds[, .(case, n_pos, share_pos=round(share_pos,3), share_tp_500=round(share_tp_500,3),
              share_O_contact=round(share_O_contact,3))])
fwrite(cds, file.path(dir_diag, "case_dominance_summary.csv"))
say("CONFIRM: largest case %s share of TP@500 = %.1f%% (Sub5 reported ~47%%)",
    largest_case, 100*cds[case==largest_case]$share_tp_500)

# ---- (A) LEAVE-LARGEST-CASE-OUT : THE DECISIVE TEST -------------------------
say("\n----- DECISIVE: leave-largest-case-out -----")
# Full validation: all positives in candidate set.
full <- copy(al); full[, y := cobidder]
metric_block <- function(y, s) c(
  roc_auc = m_rocauc(y, s), pr_auc = m_prauc(y, s),
  prec_500 = m_prec(y, s, 500), rec_500 = m_rec(y, s, 500),
  lift_500 = m_lift(y, s, 500), n_pos = sum(y==1))
mb_full <- metric_block(full$y, full$score_i)

drop1 <- largest_case
drop2 <- case_pos$proc[1:2]
codes_drop1 <- case_links[proc==drop1, firm_code]
codes_drop2 <- case_links[proc %in% drop2, firm_code]

f1 <- copy(al); f1[, y := as.integer(cobidder==1L & !firm_code %in% codes_drop1)]
f1 <- f1[!firm_code %in% codes_drop1]          # remove dropped positives from frame
mb_drop1 <- metric_block(f1$y, f1$score_i)

f2 <- copy(al); f2[, y := as.integer(cobidder==1L & !firm_code %in% codes_drop2)]
f2 <- f2[!firm_code %in% codes_drop2]
mb_drop2 <- metric_block(f2$y, f2$score_i)

say("FULL          : ROC=%.3f PR=%.3f prec@500=%.4f rec@500=%.3f (npos=%d)",
    mb_full["roc_auc"], mb_full["pr_auc"], mb_full["prec_500"], mb_full["rec_500"], mb_full["n_pos"])
say("DROP-LARGEST  : ROC=%.3f PR=%.3f prec@500=%.4f rec@500=%.3f (npos=%d)  [drop %s]",
    mb_drop1["roc_auc"], mb_drop1["pr_auc"], mb_drop1["prec_500"], mb_drop1["rec_500"], mb_drop1["n_pos"], drop1)
say("DROP-TOP-TWO  : ROC=%.3f PR=%.3f prec@500=%.4f rec@500=%.3f (npos=%d)",
    mb_drop2["roc_auc"], mb_drop2["pr_auc"], mb_drop2["prec_500"], mb_drop2["rec_500"], mb_drop2["n_pos"])

# ---- (C) case-balanced vs firm-weighted ------------------------------------
say("\n----- case-balanced vs firm-weighted -----")
# firm-weighted = pooled metric over all positives (mb_full); case-balanced =
# mean over per-case LOCO metrics (equal weight per case).
cb_rec  <- mean(loco$rec_500, na.rm=TRUE)
cb_prec <- mean(loco$prec_500, na.rm=TRUE)
fw_rec  <- mb_full["rec_500"]; fw_prec <- mb_full["prec_500"]
say("recall@500   : firm-weighted=%.3f   case-balanced(mean over cases)=%.3f", fw_rec, cb_rec)
say("precision@500: firm-weighted=%.4f   case-balanced(mean over cases)=%.4f", fw_prec, cb_prec)

# ---- (D) top-k case coverage -----------------------------------------------
say("\n----- top-k case coverage (# distinct cases among TP) -----")
cov_rows <- list()
for (k in ks) {
  tp_codes <- al[rank<=k & cobidder==1L]$firm_code
  cases_rep <- unique(case_links[firm_code %in% tp_codes]$proc)
  tp_linked <- sum(tp_codes %in% case_links$firm_code)
  cov_rows[[as.character(k)]] <- data.table(
    k=k, n_tp=length(tp_codes), n_tp_linked=tp_linked,
    n_cases_in_tp=length(cases_rep),
    largest_case_share_of_tp=cds[case==largest_case][[paste0("share_tp_",k)]])
}
coverage <- rbindlist(cov_rows)
print(coverage)

# Table H assembly
tableH <- data.table(
  scenario = c("full","drop_largest_case","drop_top_two_cases",
               "case_balanced(mean over cases)","firm_weighted(pooled)"),
  dropped_cases = c("", drop1, paste(drop2, collapse="; "), "", ""),
  n_pos = c(mb_full["n_pos"], mb_drop1["n_pos"], mb_drop2["n_pos"], NA, mb_full["n_pos"]),
  roc_auc = c(mb_full["roc_auc"], mb_drop1["roc_auc"], mb_drop2["roc_auc"], NA, mb_full["roc_auc"]),
  pr_auc = c(mb_full["pr_auc"], mb_drop1["pr_auc"], mb_drop2["pr_auc"], NA, mb_full["pr_auc"]),
  precision_500 = c(mb_full["prec_500"], mb_drop1["prec_500"], mb_drop2["prec_500"], cb_prec, fw_prec),
  recall_500 = c(mb_full["rec_500"], mb_drop1["rec_500"], mb_drop2["rec_500"], cb_rec, fw_rec))
fwrite(tableH, file.path(dir_main_t, "table_H_case_dominance_validation.csv"))
# also append coverage as a second block in a companion diagnostic
fwrite(coverage, file.path(dir_diag, "case_topk_coverage.csv"))

texH <- c(
  "% table_H_case_dominance_validation.tex (auto: 04_case_holdout_dominance.R)",
  "\\begin{tabular}{llrcccc}", "\\toprule",
  "Scenario & Dropped & Pos & ROC-AUC & PR-AUC & Prec@500 & Rec@500 \\\\", "\\midrule",
  vapply(seq_len(nrow(tableH)), function(i) sprintf("%s & %s & %s & %s & %s & %s & %s \\\\",
    gsub("_","\\\\_", tableH$scenario[i]),
    gsub("_","\\\\_", substr(tableH$dropped_cases[i],1,28)),
    if (is.na(tableH$n_pos[i])) "--" else as.character(tableH$n_pos[i]),
    fmt(tableH$roc_auc[i]), fmt(tableH$pr_auc[i]),
    fmt(tableH$precision_500[i],4), fmt(tableH$recall_500[i])), character(1)),
  "\\bottomrule", "\\end{tabular}")
writeLines(texH, file.path(dir_main_t, "table_H_case_dominance_validation.tex"))

# case-positive concentration figure (appendix)
cds_plot <- cds[order(-n_pos)]
cds_plot[, case_lab := paste0(substr(case,7,18))]
cds_plot[, case_lab := factor(case_lab, levels=case_lab)]
pCC <- ggplot(cds_plot, aes(x=case_lab, y=share_pos)) +
  geom_col(fill="#9B1B30") +
  geom_text(aes(label=sprintf("%.0f%%",100*share_pos)), vjust=-0.4, size=3) +
  labs(title="Concentration of positive cobidders across CADE cases",
       subtitle="Share of all positive (always-loser) cobidders linked to each case",
       x="CADE case", y="Share of positives") +
  theme_minimal(base_size=11) + theme(axis.text.x=element_text(angle=35, hjust=1))
ggsave(file.path(dir_app_f, "fig_case_positive_concentration.pdf"), pCC,
       width=7, height=4.5, device=cairo_pdf)
say("wrote fig_case_positive_concentration.pdf")
stamp("B_case_dominance")

# =============================================================================
# C. ENVIRONMENT DOMINANCE  -- Step 12
# Concentration of positive labels by buyer / item_group / item_code / modality /
# year. HHI, largest-group share, top-5 share. Robustness: recompute MAIN metrics
# excluding the largest buyer / item_group / buyer x item_group / Pregao-only /
# Convite-only / top-positive years.
# =============================================================================
say("\n========== C. ENVIRONMENT DOMINANCE ==========")

# assign each POSITIVE a primary environment (modal of its participations) to
# concentrate positive labels by environment. Use the MODE per firm.
prim_mode <- function(dt, col) {
  dt[, .(v = names(sort(table(get(col)), decreasing=TRUE))[1]), by=firm_code]
}
pe <- copy(pos_env)
pe[, buyer_item := paste0(buyer,"|",item_group)]
pmaps <- list(
  buyer      = prim_mode(pe, "buyer"),
  item_group = prim_mode(pe, "item_group"),
  item_code  = prim_mode(pe, "item"),
  modality   = prim_mode(pe[!is.na(modality)], "modality"),
  year       = prim_mode(pe, "year"),
  buyer_item = prim_mode(pe, "buyer_item"))

hhi <- function(x) { p <- prop.table(table(x)); sum(p^2) }
env_summary <- rbindlist(lapply(names(pmaps), function(nm) {
  v <- pmaps[[nm]]$v
  tb <- sort(table(v), decreasing=TRUE)
  data.table(dimension=nm, n_groups=length(tb),
             n_positives_assigned=length(v),
             hhi=hhi(v),
             largest_share=as.numeric(tb[1])/length(v),
             largest_group=names(tb)[1],
             top5_share=sum(head(as.numeric(tb),5))/length(v))
}))
say("--- environment_dominance_summary ---")
print(env_summary[, .(dimension, n_groups, hhi=round(hhi,3),
                      largest_share=round(largest_share,3), top5_share=round(top5_share,3))])
fwrite(env_summary, file.path(dir_diag, "environment_dominance_summary.csv"))

# robustness: recompute MAIN metrics dropping largest environment(s)
largest_buyer      <- env_summary[dimension=="buyer"]$largest_group
largest_item_group <- env_summary[dimension=="item_group"]$largest_group
largest_buyer_item <- env_summary[dimension=="buyer_item"]$largest_group

# helper: positives whose PRIMARY env == a value
prim_codes <- function(nm, val) pmaps[[nm]][v==val, firm_code]

env_robust <- function(label, drop_codes) {
  fr <- copy(al)
  fr[, y := as.integer(cobidder==1L & !firm_code %in% drop_codes)]
  fr <- fr[!firm_code %in% drop_codes]
  mb <- metric_block(fr$y, fr$score_i)
  data.table(scenario=label, n_pos=mb["n_pos"], roc_auc=mb["roc_auc"],
             pr_auc=mb["pr_auc"], precision_500=mb["prec_500"], recall_500=mb["rec_500"])
}

# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): modality codes from cfg.
# Pregao-only / Convite-only: restrict positives to those whose modal modality is the
# pregao / convite code. BEC modality column codes pregao=3, convite=1. FEDERAL is
# PURE PREGAO (po_phase_code 5 / 9999, cfg$has_convite==FALSE): the pregao set is
# all positives and the convite branch is SKIPPED with a logged note.
mod_map <- pmaps$modality
.pregao_vals <- as.character(unlist(cfg$modalities[grepl("pregao", names(cfg$modalities))]))
pregao_codes  <- mod_map[v %in% .pregao_vals, firm_code]
if (isTRUE(cfg$has_convite)) {
  .convite_vals <- as.character(unlist(cfg$modalities[grepl("convite", names(cfg$modalities))]))
  convite_codes <- mod_map[v %in% .convite_vals, firm_code]
} else {
  convite_codes <- character(0)
  say("modality robustness: convite branch SKIPPED (source=%s has no convite; gate G5 pure pregao)", SRC)
}
# years with most positives
yr_counts <- pmaps$year[, .N, by=v][order(-N)]
top_years <- yr_counts$v[1:2]
top_year_codes <- pmaps$year[v %in% top_years, firm_code]

rob_list <- list(
  env_robust("full", character(0)),
  env_robust(sprintf("drop_largest_buyer=%s", largest_buyer), prim_codes("buyer", largest_buyer)),
  env_robust(sprintf("drop_largest_item_group=%s", largest_item_group), prim_codes("item_group", largest_item_group)),
  env_robust(sprintf("drop_largest_buyer_x_item_group=%s", largest_buyer_item), prim_codes("buyer_item", largest_buyer_item))
)
# modality-restricted: keep ONLY positives of that modality as positives
mod_robust <- function(label, keep_codes) {
  fr <- copy(al)
  fr[, y := as.integer(cobidder==1L & firm_code %in% keep_codes)]
  drop <- al[cobidder==1L & !firm_code %in% keep_codes]$firm_code   # other-modality positives excluded
  fr <- fr[!firm_code %in% drop]
  mb <- metric_block(fr$y, fr$score_i)
  data.table(scenario=label, n_pos=mb["n_pos"], roc_auc=mb["roc_auc"],
             pr_auc=mb["pr_auc"], precision_500=mb["prec_500"], recall_500=mb["rec_500"])
}
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): labels keep BEC byte-identical
# ("modality=3"/"modality=1"); federal labels its pregao codes generically.
.pregao_lab <- if (cfg$cade_layout == "bec_csv") {
  "pregao_only(modal modality=3)"
} else {
  sprintf("pregao_only(modal modality in {%s})", paste(.pregao_vals, collapse=","))
}
if (length(pregao_codes)  >= 5) rob_list <- c(rob_list, list(mod_robust(.pregao_lab, pregao_codes)))
if (length(convite_codes) >= 5) rob_list <- c(rob_list, list(mod_robust("convite_only(modal modality=1)", convite_codes)))
rob_list <- c(rob_list, list(env_robust(sprintf("drop_top_positive_years=%s", paste(top_years, collapse=",")), top_year_codes)))

env_robust_tab <- rbindlist(rob_list)
say("--- environment robustness (MAIN metrics) ---")
print(env_robust_tab[, .(scenario=substr(scenario,1,40), n_pos,
                         roc_auc=round(roc_auc,3), pr_auc=round(pr_auc,3),
                         rec_500=round(recall_500,3))])
fwrite(env_robust_tab, file.path(dir_app_t, "table_D_environment_dominance.csv"))
stamp("C_environment")

# =============================================================================
# D. LEAVE-ONE-DEFENDANT-GROUP-OUT  -- Step 11
# Group = direct defendant firm. Remove the COBIDDER positives whose defendant
# contact comes from that defendant's tender-items, then evaluate ranking of the
# remaining positives. Feasible only where a defendant maps to >=TOO_SPARSE_MIN
# distinct positives via shared tender-items; else document.
# =============================================================================
say("\n========== D. LEAVE-ONE-DEFENDANT-GROUP-OUT ==========")
# contact_case gives firm x case; we need firm x DEFENDANT. Rebuild quickly from
# the case map is too coarse (case-level). Use defendant-level: a positive is in
# defendant d's group if it shares a tender-item with d. Reuse contact_case at
# CASE granularity as the feasible grouping, plus per-defendant where stable.
# We already have case-level holdout (LOCO). For defendant granularity:
con2 <- dbConnect(duckdb())
dbExecute(con2, "PRAGMA threads=12"); dbExecute(con2, "PRAGMA memory_limit='12GB'")
dbExecute(con2, sprintf("PRAGMA temp_directory='%s'", cfg$temp_directory))  # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05)
dbWriteTable(con2, "direct", data.frame(firm_code = direct_codes), overwrite=TRUE)
dbWriteTable(con2, "pos", data.frame(firm_code = pos_all$firm_code), overwrite=TRUE)
pos_def <- as.data.table(dbGetQuery(con2, sprintf("
  WITH ftm AS (
    SELECT %s AS firm_code,
           CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')),
  def_items AS (
    SELECT DISTINCT f.firm_code AS def_code, f.oc, f.item
    FROM ftm f JOIN direct d ON f.firm_code=d.firm_code)
  SELECT DISTINCT p.firm_code, di.def_code
  FROM ftm f JOIN pos p ON f.firm_code=p.firm_code
  JOIN def_items di ON f.oc=di.oc AND f.item=di.item
  WHERE p.firm_code <> di.def_code", FC_SQL, ftm_path)))
dbDisconnect(con2, shutdown=TRUE)
say("positive x defendant contact rows: %d ; distinct defendants touching a positive: %d",
    nrow(pos_def), uniqueN(pos_def$def_code))
def_grp <- pos_def[, .(n_pos=uniqueN(firm_code)), by=def_code][order(-n_pos)]
n_feasible_def <- sum(def_grp$n_pos >= TOO_SPARSE_MIN)
say("defendants linked to >=%d distinct positives (feasible LODGO groups): %d of %d",
    TOO_SPARSE_MIN, n_feasible_def, nrow(def_grp))

lodgo_rows <- list()
for (d in def_grp$def_code) {
  held <- pos_def[def_code==d, firm_code]
  other_pos <- setdiff(pos_all$firm_code, held)
  ev <- al[!firm_code %in% other_pos]; ev[, y := as.integer(firm_code %in% held)]
  lodgo_rows[[d]] <- data.table(defendant=d, n_positives=length(held),
    too_sparse=length(held) < TOO_SPARSE_MIN,
    n_candidates=nrow(ev),
    roc_auc=m_rocauc(ev$y, ev$score_i), pr_auc=m_prauc(ev$y, ev$score_i),
    rec_500=m_rec(ev$y, ev$score_i, 500), prec_500=m_prec(ev$y, ev$score_i, 500))
}
# DETERMINISTIC ROW ORDER (R1-extended adjudication, 2026-06-06): order(-n_positives)
# alone leaves ties resolved by upstream DuckDB SELECT DISTINCT emission order, which
# the norm14_safe normalizer change perturbed (values proven byte-identical; only row
# order drifted). Add `defendant` as a stable secondary key so the CSV reproduces
# byte-for-byte across runs and across the BEC/federal normalizer branches.
lodgo <- rbindlist(lodgo_rows)[order(-n_positives, defendant)]
say("--- leave-one-defendant-group-out (top groups) ---")
print(head(lodgo[, .(defendant, n_positives, too_sparse, roc_auc=round(roc_auc,3),
                     rec_500=round(rec_500,3))], 12))
say("LODGO non-sparse: %d groups; mean ROC-AUC=%.3f (non-sparse), mean rec@500=%.3f",
    sum(!lodgo$too_sparse),
    mean(lodgo[too_sparse==FALSE]$roc_auc, na.rm=TRUE),
    mean(lodgo[too_sparse==FALSE]$rec_500, na.rm=TRUE))
fwrite(lodgo, file.path(dir_app_t, "table_D_leave_one_defendant_group_out.csv"))
stamp("D_lodgo")

# =============================================================================
# E. CLUSTERED RANDOMIZATION INFERENCE  -- Step 13
# Shuffle the positive labels across firms WITHIN buyer x item_group x year cells,
# preserving the number of positives per cell. If too sparse, fall back to
# coarser strata (exposure x participation). B=1000, seed 20260603.
# =============================================================================
say("\n========== E. CLUSTERED RANDOMIZATION INFERENCE ==========")
# assign each candidate firm a primary cell. For positives we have pos_env; for
# negatives we need cells too -> pull primary buyer/item_group/year for ALL
# candidate firms. Build cell map via DuckDB (mode per firm).
con3 <- dbConnect(duckdb())
dbExecute(con3, "PRAGMA threads=12"); dbExecute(con3, "PRAGMA memory_limit='12GB'")
dbExecute(con3, sprintf("PRAGMA temp_directory='%s'", cfg$temp_directory))  # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05)
dbWriteTable(con3, "cand", data.frame(firm_code = al$firm_code), overwrite=TRUE)
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): per-firm (buyer,item_group,year)
# cell map. BEC derives buyer + year from the composite numerodaoc (substr). FEDERAL
# joins item_level_panel for buyer (codigo_ug) and RESULT year (gate G1: never substr
# the federal numbering year). item_group = item-code prefix in both.
if (cfg$key_is_composite) {
  cell_map <- as.data.table(dbGetQuery(con3, sprintf("
    WITH ftm AS (
      SELECT %s AS firm_code,
             %s AS buyer,
             SUBSTR(CAST(\"códigoitem\" AS VARCHAR),1,2) AS item_group,
             %s AS year
      FROM read_parquet('%s')),
    j AS (SELECT f.* FROM ftm f JOIN cand c ON f.firm_code=c.firm_code),
    cnt AS (
      SELECT firm_code, buyer, item_group, year, COUNT(*) n,
             ROW_NUMBER() OVER (PARTITION BY firm_code ORDER BY COUNT(*) DESC, buyer, item_group, year) rn
      FROM j GROUP BY firm_code, buyer, item_group, year)
    SELECT firm_code, buyer, item_group, year FROM cnt WHERE rn=1",
    FC_SQL,
    cfg$buyer_from_key("CAST(\"numerodaoc\" AS VARCHAR)"),
    cfg$year_from_key("CAST(\"numerodaoc\" AS VARCHAR)"), ftm_path)))
} else {
  # FEDERAL: buyer + result year come from the panel join on (numerodaoc, codigoitem).
  cell_map <- as.data.table(dbGetQuery(con3, sprintf("
    WITH panel AS (
      SELECT CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"%s\" AS VARCHAR) AS item,
             CAST(\"%s\" AS VARCHAR) AS buyer, CAST(year AS VARCHAR) AS year
      FROM read_parquet('%s')),
    ftm AS (
      SELECT %s AS firm_code,
             CAST(\"numerodaoc\" AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item,
             SUBSTR(CAST(\"códigoitem\" AS VARCHAR),1,2) AS item_group
      FROM read_parquet('%s')),
    fp AS (
      SELECT f.firm_code, p.buyer, f.item_group, p.year
      FROM ftm f JOIN panel p ON f.oc=p.oc AND f.item=p.item),
    j AS (SELECT fp.* FROM fp JOIN cand c ON fp.firm_code=c.firm_code),
    cnt AS (
      SELECT firm_code, buyer, item_group, year, COUNT(*) n,
             ROW_NUMBER() OVER (PARTITION BY firm_code ORDER BY COUNT(*) DESC, buyer, item_group, year) rn
      FROM j GROUP BY firm_code, buyer, item_group, year)
    SELECT firm_code, buyer, item_group, year FROM cnt WHERE rn=1",
    IVP_ITEM_COL, cfg$buyer_col, ivp_path, FC_SQL, ftm_path)))
}
dbDisconnect(con3, shutdown=TRUE)
al2 <- merge(al, cell_map, by="firm_code", all.x=TRUE)
al2[, y := cobidder]

ri_done <- FALSE
ri_blocker <- NULL
make_strata <- function(dt, cols) { dt[, paste(do.call(paste, c(.SD, sep="_")), sep=""), .SDcols=cols][[1]] }
# tightest: buyer x item_group x year
run_ri <- function(strata_label, strata_vec) {
  dt <- copy(al2); dt[, cell := strata_vec]
  pos_per_cell <- dt[, .(npos=sum(y), n=.N), by=cell]
  cells_with_pos <- pos_per_cell[npos>0]
  # feasibility: each positive-bearing cell must have >=2 firms to permit a shuffle
  shufflable <- cells_with_pos[n>=2]
  frac_pos_shufflable <- dt[cell %in% shufflable$cell & y==1, .N] / dt[y==1, .N]
  list(label=strata_label, dt=dt, pos_per_cell=pos_per_cell,
       n_cells_with_pos=nrow(cells_with_pos), frac_pos_shufflable=frac_pos_shufflable)
}
strat_tight <- run_ri("buyer_x_item_group_x_year",
                      al2[, paste(buyer, item_group, year, sep="|")])
say("RI tight (buyer x item_group x year): %d positive-bearing cells; frac positives in shufflable(>=2 firm) cells = %.3f",
    strat_tight$n_cells_with_pos, strat_tight$frac_pos_shufflable)

chosen <- NULL
if (strat_tight$frac_pos_shufflable >= 0.5) {
  chosen <- strat_tight
} else {
  strat_coarse <- run_ri("item_group_x_year",
                         al2[, paste(item_group, year, sep="|")])
  say("RI fallback (item_group x year): %d positive-bearing cells; frac shufflable = %.3f",
      strat_coarse$n_cells_with_pos, strat_coarse$frac_pos_shufflable)
  if (strat_coarse$frac_pos_shufflable >= 0.5) {
    chosen <- strat_coarse
  } else {
    # coarsest: exposure(O_i>0) x participation-decile strata
    al2[, exp_strat := as.integer(O_i>0)]
    al2[, part_dec := cut(score_i, breaks=quantile(score_i, probs=seq(0,1,0.1)),
                          include.lowest=TRUE, labels=FALSE)]
    strat_exp <- run_ri("exposure_x_participation_decile",
                        al2[, paste(exp_strat, part_dec, sep="|")])
    say("RI coarsest (exposure x participation decile): %d positive-bearing cells; frac shufflable = %.3f",
        strat_exp$n_cells_with_pos, strat_exp$frac_pos_shufflable)
    chosen <- strat_exp
  }
}

if (is.null(chosen) || chosen$frac_pos_shufflable < 0.5) {
  ri_blocker <- sprintf(paste0(
    "Clustered RI infeasible: even at the coarsest stratification (%s) only %.1f%% of ",
    "the %d positives fall in cells with >=2 candidate firms, so within-cell label ",
    "shuffling cannot preserve per-cell positive counts for most positives. ",
    "Positives are too concentrated in singleton cells."),
    chosen$label, 100*chosen$frac_pos_shufflable, n_pos)
} else {
  say("RI chosen stratification: %s (%.1f%% positives shufflable)", chosen$label, 100*chosen$frac_pos_shufflable)
  dt <- chosen$dt
  # observed metrics
  obs <- c(roc_auc=m_rocauc(dt$y, dt$score_i), pr_auc=m_prauc(dt$y, dt$score_i),
           prec_500=m_prec(dt$y, dt$score_i, 500), rec_500=m_rec(dt$y, dt$score_i, 500))
  # observed top-500 case coverage
  setorder(dt, -score_i, firm_id)
  obs_cov <- length(unique(case_links[firm_code %in% dt[1:500][cobidder==1L]$firm_code]$proc))

  B <- 1000L
  set.seed(SEED)
  null_mat <- matrix(NA_real_, nrow=B, ncol=5,
                     dimnames=list(NULL, c("roc_auc","pr_auc","prec_500","rec_500","cov_500")))
  # precompute cell index list
  cell_idx <- split(seq_len(nrow(dt)), dt$cell)
  pos_in_cell <- lapply(cell_idx, function(ix) sum(dt$y[ix]))
  for (b in seq_len(B)) {
    ynew <- integer(nrow(dt))
    for (cn in names(cell_idx)) {
      ix <- cell_idx[[cn]]; np <- pos_in_cell[[cn]]
      if (np>0) ynew[sample(ix, np)] <- 1L
    }
    null_mat[b,"roc_auc"] <- m_rocauc(ynew, dt$score_i)
    null_mat[b,"pr_auc"]  <- m_prauc(ynew, dt$score_i)
    null_mat[b,"prec_500"]<- m_prec(ynew, dt$score_i, 500)
    null_mat[b,"rec_500"] <- m_rec(ynew, dt$score_i, 500)
    ord <- order(-dt$score_i, dt$firm_id)[1:500]
    null_mat[b,"cov_500"] <- length(unique(case_links[firm_code %in% dt$firm_code[ord][ynew[ord]==1L]]$proc))
  }
  fwrite(as.data.table(null_mat), file.path(dir_cache, "clustered_ri_metrics.csv"))
  emp_p <- function(o, nullv) (1 + sum(nullv >= o, na.rm=TRUE)) / (1 + sum(!is.na(nullv)))
  ri_tab <- data.table(
    metric=c("roc_auc","pr_auc","precision_500","recall_500","topk500_case_coverage"),
    observed=c(obs["roc_auc"], obs["pr_auc"], obs["prec_500"], obs["rec_500"], obs_cov),
    null_mean=c(mean(null_mat[,"roc_auc"],na.rm=TRUE), mean(null_mat[,"pr_auc"],na.rm=TRUE),
                mean(null_mat[,"prec_500"],na.rm=TRUE), mean(null_mat[,"rec_500"],na.rm=TRUE),
                mean(null_mat[,"cov_500"],na.rm=TRUE)),
    null_q95=c(quantile(null_mat[,"roc_auc"],0.95,na.rm=TRUE), quantile(null_mat[,"pr_auc"],0.95,na.rm=TRUE),
               quantile(null_mat[,"prec_500"],0.95,na.rm=TRUE), quantile(null_mat[,"rec_500"],0.95,na.rm=TRUE),
               quantile(null_mat[,"cov_500"],0.95,na.rm=TRUE)),
    emp_p=c(emp_p(obs["roc_auc"], null_mat[,"roc_auc"]), emp_p(obs["pr_auc"], null_mat[,"pr_auc"]),
            emp_p(obs["prec_500"], null_mat[,"prec_500"]), emp_p(obs["rec_500"], null_mat[,"rec_500"]),
            emp_p(obs_cov, null_mat[,"cov_500"])),
    stratification=chosen$label, B=B, seed=SEED)
  say("--- clustered RI: observed vs null ---")
  print(ri_tab[, .(metric, observed=round(observed,4), null_mean=round(null_mean,4),
                   emp_p=round(emp_p,4))])
  fwrite(ri_tab, file.path(dir_app_t, "table_D_clustered_randomization_inference.csv"))
  # figure
  ri_long <- rbindlist(lapply(c("roc_auc","pr_auc"), function(mm)
    data.table(metric=mm, value=null_mat[,mm], observed=obs[mm])))
  pRI <- ggplot(ri_long, aes(x=value)) +
    geom_histogram(bins=40, fill="grey80", colour="white") +
    geom_vline(aes(xintercept=observed), colour="#9B1B30", linewidth=1) +
    facet_wrap(~metric, scales="free") +
    labs(title="Clustered randomization inference: observed vs within-cell null",
         subtitle=sprintf("B=%d, stratification=%s", B, chosen$label),
         x="Metric value (null distribution)", y="Count") +
    theme_minimal(base_size=11)
  ggsave(file.path(dir_app_f, "fig_clustered_randomization_inference.pdf"), pRI,
         width=8, height=4, device=cairo_pdf)
  say("wrote fig_clustered_randomization_inference.pdf + clustered_ri_metrics.csv")
  ri_done <- TRUE
}

if (!is.null(ri_blocker)) {
  writeLines(c("# Clustered randomization inference -- BLOCKER",
               "", paste("Generated:", format(Sys.time())), "",
               ri_blocker, "",
               "Decision: report case-dominance via LOCO + leave-largest + coverage instead;",
               "clustered RI cannot be run at any feasible stratification."),
             file.path(DOCS, "clustered_randomization_inference_blocker.md"))
  say("WROTE BLOCKER: clustered_randomization_inference_blocker.md")
  say("BLOCKER: %s", ri_blocker)
}
stamp("E_clustered_ri")

# =============================================================================
# F. VERDICT SUMMARY (printed, for the report)
# =============================================================================
say("\n========== VERDICT INPUTS ==========")
say("largest case = %s : %.1f%% of positives, %.1f%% of TP@500",
    largest_case, 100*cds[case==largest_case]$share_pos, 100*cds[case==largest_case]$share_tp_500)
say("FULL  ROC=%.3f PR=%.3f | DROP-LARGEST ROC=%.3f PR=%.3f (prec@500 %.4f->%.4f; rec@500 %.3f->%.3f)",
    mb_full["roc_auc"], mb_full["pr_auc"], mb_drop1["roc_auc"], mb_drop1["pr_auc"],
    mb_full["prec_500"], mb_drop1["prec_500"], mb_full["rec_500"], mb_drop1["rec_500"])
say("TP@500 case coverage = %d distinct cases", coverage[k==500]$n_cases_in_tp)
say("item_group HHI=%.3f largest=%.3f ; buyer HHI=%.3f largest=%.3f",
    env_summary[dimension=="item_group"]$hhi, env_summary[dimension=="item_group"]$largest_share,
    env_summary[dimension=="buyer"]$hhi, env_summary[dimension=="buyer"]$largest_share)

say("\n=== DONE === elapsed=%.1fs", as.numeric(difftime(Sys.time(),.t0,units="secs")))
