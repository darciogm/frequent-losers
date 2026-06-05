#!/usr/bin/env Rscript
# =============================================================================
# 13_srp_stratified_validation.R  --  JLEO R&R (v22)  --  FEDERAL-ONLY LEG
#
# OPTIONAL SRP-stratification robustness leg (R4 hostile-read protocol attack A7).
#
# THE REFEREE QUESTION (A7): "85% of federal volume is SRP (price registration) --
#   a DIFFERENT economic object from regular pregao. Does pooling the two pregao
#   variants HIDE heterogeneity in the loser-side concentration signal?"
#
# THE ONE QUESTION THIS LEG ANSWERS: does the loser-side concentration signal
#   behave CONSISTENTLY across the two federal pregao variants (regular pregao
#   po_phase_code=5 vs SRP po_phase_code=9999)? Deliverable = per-stratum RAW
#   discrimination + WITHIN-STRATUM opportunity-adjusted discrimination of the
#   broad-AL target, mirroring the canonical script 02 methodology.
#
# -----------------------------------------------------------------------------
# LOCKED DESIGN DECISIONS (these go in front of a referee -- be precise):
#
#  WHAT IS STRATIFIED  (varies across strata):
#    * the EVALUATION SAMPLE -- which firms are scored/labelled in a stratum is
#      "always-loser firms ACTIVE in that stratum" (>=1 participation row in
#      tender-items of that modality).
#    * the OPPORTUNITY CELLS -- the within-stratum (year x buyer) cells used for
#      the exposure-adjusted residual are rebuilt USING ONLY that stratum's
#      participation rows.
#
#  WHAT STAYS POOLED  (identical across strata -- NEVER re-derived per stratum):
#    * the SCORE.  score_i = log1p(tenders_count) is the CANONICAL POOLED
#      loss-intensity score (FREQ_PARTICIP tenders_count over the WHOLE federal
#      window, all modalities). We do NOT recompute within-stratum participation
#      counts -- that would measure a different construct.
#    * the FL32 binary cut (cfg$fl_predicate, tenders_count >= 32 pooled). We do
#      NOT re-derive a per-stratum IQR threshold. The feasibility scan shows the
#      per-variant median+1.5*IQR thresholds DIVERGE materially (33.5 vs 64.5);
#      using them would make the two strata measure DIFFERENT objects, defeating
#      the comparison. The canonical pooled FL32 is held fixed in BOTH strata.
#    * the POSITIVE LABEL.  broad_cobidder from the CLEAN canonical targets
#      (canonical_cobidders_broad.csv, 195 broad-AL positives, sentinel removed).
#      Consumed as-is; targets are NEVER rebuilt here.
#
#  In one sentence for the referee: "Stratifying the EVALUATION (sample + cells),
#  not the CONSTRUCT (score + cut + label), isolates whether the SAME signal
#  discriminates the SAME positives equally well in each pregao variant."
#
# -----------------------------------------------------------------------------
# OUTPUTS (cfg$dirs federal paths, outputs/comprasnet/...):
#   tables/table_SRP_stratified.csv + .tex
#     rows: stratum, N firms, N+, raw AUC [CI], PR-AUC, within-stratum AUC,
#           expected-by-exposure (exposure-only AUC benchmark)
#   tables/table_SRP_stratified_macros.csv     (\valFedAudSRPreg* / \valFedAudSRPsrp*)
#   diagnostics/srp_stratified_audit_log.txt
#
# POWER GUARD: if either stratum's effective N+ < 50 -> emit UNDERPOWERED note
#   instead of a number (honesty-first).
#
# Run (FULL):
#   cd <repo>; Rscript work/v22-editor/scripts/analysis/13_srp_stratified_validation.R \
#     --source=comprasnet \
#     2>&1 | tee work/v22-editor/outputs/comprasnet/logs/srp_stratified_validation.log
#
# Run (SMOKE, parse + sample blocks only, 2 threads/2GB):
#   Rscript work/v22-editor/scripts/analysis/13_srp_stratified_validation.R \
#     --source=comprasnet --smoke
# =============================================================================

suppressPackageStartupMessages({
  library(DBI); library(duckdb); library(data.table); library(arrow); library(pROC)
})

# ---- locate repo + dirs (mirror script 02) ---------------------------------
if (!exists(".script_dir")) {
  fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
  .script_dir <- if (length(fa)) dirname(normalizePath(fa[1L])) else getwd()
}
REPO <- normalizePath(file.path(.script_dir, "..", "..", "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(REPO, "data", "processed")))
  REPO <- normalizePath("/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
V22  <- file.path(REPO, "work", "v22-editor")
UTIL <- file.path(V22, "scripts", "utils")

# ---- args: --source= (federal-only) + --smoke -------------------------------
.args  <- commandArgs(trailingOnly = TRUE)
.src   <- sub("^--source=", "", .args[grep("^--source=", .args)])
SRC    <- if (length(.src)) .src[1L] else "comprasnet"   # default federal (this leg is federal-only)
SMOKE  <- any(.args == "--smoke")

# GUARD: SRP stratification is a federal-only leg. Stop hard if source=bec.
if (identical(SRC, "bec"))
  stop("SRP stratification is a federal-only leg: BEC has no SRP/pregao split (po_phase_code 5/9999 are federal only). Re-run with --source=comprasnet.")

source(file.path(UTIL, "source_config.R"))
cfg <- get_source_config(SRC)
cfg$ensure_dirs()
source(file.path(UTIL, "metrics_triage.R"))

DATA      <- cfg$data_dir
dir_tab   <- cfg$dirs$tables_main      # FED: outputs/comprasnet/tables
dir_diag  <- cfg$dirs$diagnostics
dir_cache <- cfg$dirs$cache
dir_log   <- cfg$dirs$logs
# SMOKE owns a tiny machine: 2 threads / 2GB / dedicated spill so it never
# collides with the concurrent heavy chain. FULL run uses the standard budget.
SPILL <- if (SMOKE) "/tmp/duckdb_spill_srp13" else cfg$temp_directory
DUCK_THREADS <- if (SMOKE) 2L  else 12L
DUCK_MEM     <- if (SMOKE) "2GB" else "12GB"
for (d in c(dir_tab, dir_diag, dir_cache, dir_log, SPILL))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

setDTthreads(if (SMOKE) 2L else 12L)
SEED <- 20260605L
set.seed(SEED)

# ---- the two federal pregao strata (from cfg) -------------------------------
# cfg$phase_codes = list(pregao = 5L, pregao_srp = 9999L). Stable across the run.
STRATA <- list(
  pregao_5  = list(label = "pregao_regular", phase = cfg$phase_codes$pregao,     macro = "reg",
                   feas_cob = 3546L, feas_def = 21L),
  SRP_9999  = list(label = "pregao_srp",     phase = cfg$phase_codes$pregao_srp, macro = "srp",
                   feas_cob = 4069L, feas_def = 23L)
)
POWER_MIN_NPOS <- 50L   # honesty-first power guard

# ---- telemetry --------------------------------------------------------------
LOG <- file.path(dir_diag, "srp_stratified_audit_log.txt")
.t0 <- Sys.time(); cat("", file = LOG)
say <- function(...) { m <- sprintf(...); cat(m, "\n"); cat(m, "\n", file = LOG, append = TRUE) }
rss_mb <- function() tryCatch(round(as.numeric(system(sprintf("ps -o rss= -p %d", Sys.getpid()), intern=TRUE))/1024), error=function(e) NA_real_)
stamp  <- function(s) say("  [stage %-26s] elapsed=%6.1fs  RSS=%s MB", s, as.numeric(difftime(Sys.time(),.t0,units="secs")), rss_mb())

say("=== 13_srp_stratified_validation.R  (%s) ===", if (SMOKE) "SMOKE" else "FULL")
say("host=%s  nproc=%s  seed=%d  date=%s",
    Sys.info()[["nodename"]], tryCatch(system("nproc", intern=TRUE), error=function(e)"?"), SEED, format(Sys.time()))
say("SOURCE=%s  (%s)", SRC, cfg$label)
say("DATA=%s", DATA)
say("SPILL=%s  DUCK_THREADS=%d  DUCK_MEM=%s", SPILL, DUCK_THREADS, DUCK_MEM)
say("DESIGN: stratify EVALUATION (sample active in stratum + within-stratum year x buyer cells);")
say("        keep POOLED score=log1p(tenders_count), FL32 cut (>=32), label=broad_cobidder.")
say("        FL32 NEVER re-derived per stratum (per-variant IQR thresholds 33.5 vs 64.5 -> different constructs).")

# SOURCE-CONFIG ADAPTATION (Phase 1 estrang-fix, 2026-06-05): source-gated 14-char
# firm-code normalizer (cfg$norm14_safe), replacing the suppressWarnings/NA-collapse
# band-aid. BEC -> exact legacy sprintf("%014.0f", as.numeric(x)) (byte-identity, gate
# R1). Federal -> numeric pad14; non-numeric (ESTRANG* foreign suppliers + 14-char
# sentinels like '000000000000-2') pass through RAW instead of coercing to NA -- they
# legitimately never match a CADE CNPJ, so RAW vs NA is label-equivalent but RAW no
# longer needs the warning suppression and keeps the codes inspectable.
norm14 <- cfg$norm14_safe

# pROC AUC + CI wrapper (mirror script 02 auc_ci)
auc_ci <- function(label, score, dat) {
  if (sum(dat[[label]] == 1L) == 0L || sum(dat[[label]] == 0L) == 0L)
    return(list(auc=NA_real_, lo=NA_real_, hi=NA_real_, n=nrow(dat), npos=sum(dat[[label]]==1L)))
  r  <- pROC::roc(dat[[label]], dat[[score]], quiet=TRUE, direction="<")
  ci <- pROC::ci.auc(r)
  list(auc=as.numeric(r$auc), lo=ci[1], hi=ci[3], n=nrow(dat), npos=sum(dat[[label]]==1L))
}
# pooled within-stratum (year x buyer cell) C-statistic -- mirror script 02 strat_auc
cell_strat_auc <- function(dat, score, label, cell) {
  num <- 0; den <- 0
  for (s in unique(dat[[cell]])) {
    sub <- dat[get(cell) == s]
    p <- sub[[score]][sub[[label]]==1L]; n <- sub[[score]][sub[[label]]==0L]
    if (!length(p) || !length(n)) next
    cmp <- outer(p, n, function(a,b) (a>b)+0.5*(a==b))
    num <- num + sum(cmp); den <- den + length(p)*length(n)
  }
  list(auc = if (den>0) num/den else NA_real_, comparable_pairs = den)
}

# =============================================================================
# A. CANONICAL POOLED CONSTRUCT  (score + cut + label -- pooled, NEVER stratified)
# =============================================================================
say("\n----- A. canonical pooled construct (score/cut/label, NOT stratified) -----")
# POSITIVE LABEL: CLEAN canonical targets (195 broad-AL positives, sentinel removed). Consume; never rebuild.
CANON_COB <- file.path(dir_cache, "canonical_cobidders_broad.csv")
if (!file.exists(CANON_COB)) stop("missing clean canonical targets: ", CANON_COB)
cob <- fread(CANON_COB)
cob[, firm_code := norm14(`códigofornecedor`)]
cob_codes <- unique(cob[broad_cobidder == 1L, firm_code])
say("broad-AL positives (clean canonical, sentinel removed): %d firm_code", length(cob_codes))

# always-loser panel -> POOLED score + POOLED FL32 cut (cfg). The construct.
fp <- as.data.table(read_parquet(cfg$freq_particip))
fp[, firm_code := norm14(`códigofornecedor`)]
al <- fp[always_loser == 1L, .(firm_code, tenders_count)]
al[, cobidder := as.integer(firm_code %in% cob_codes)]
al[, fl32     := as.integer(cfg$fl_predicate(tenders_count))]   # POOLED cut (>=32); never per-stratum
al[, score_i  := log1p(tenders_count)]                          # POOLED log_tc; never per-stratum
say("always-losers (pooled universe): %d ; cobidders in universe: %d ; FL32: %d",
    nrow(al), al[cobidder==1L,.N], al[fl32==1L,.N])
.cob_not_al <- sum(!cob_codes %in% al$firm_code)
say("ASSERT broad cobidders in AL universe: %d of %d (%d not AL -> excluded from npos)",
    length(cob_codes) - .cob_not_al, length(cob_codes), .cob_not_al)

# direct CADE defendants (for the per-stratum exposure / expected-contact cells)
dd <- as.data.table(read_parquet(cfg$cade$direct_defendants))
xm <- dd[, .(firm_cnpj = firm_id, processo)]
xm[, firm_code := norm14(firm_cnpj)]
direct_codes_raw <- unique(xm$firm_code)
direct_codes <- setdiff(direct_codes_raw, cob_codes)   # defendants = winners only; drop AL-overlap (mirror 02)
say("direct CADE defendants raw=%d ; cleaned (winners only)=%d", length(direct_codes_raw), length(direct_codes))
stamp("A_pooled_construct")

# =============================================================================
# B. STRATUM ASSIGNMENT  (item -> modality at (numerodaoc,codigoitem) grain)
# =============================================================================
say("\n----- B. stratum assignment (item-modality map) -----")
# po_phase_code lives in bid_level_full at the (numerodaoc, codigoitem) grain.
# HOSTILE-REVIEW FIX (2026-06-05): doc figures now match the code. Items are
# MODALITY-UNIQUE (verified: 7,413,963 single-phase vs 205 two-phase = 0.003%);
# we ASSERT this on a <=2M-row sample (fail only if multi-phase share > 1%, see
# line below) and MAX() over the 0.003% ambiguous items so the map is a clean
# 1:1 (numerodaoc,codigoitem) -> phase.
con <- dbConnect(duckdb())
invisible(dbExecute(con, sprintf("PRAGMA threads=%d", DUCK_THREADS)))
invisible(dbExecute(con, sprintf("PRAGMA memory_limit='%s'", DUCK_MEM)))
invisible(dbExecute(con, sprintf("PRAGMA temp_directory='%s'", SPILL)))
bid_path <- cfg$bid_level
ftm_path <- cfg$firm_tender_map

# ASSERT (on a LIMIT sample): items are modality-unique. Tolerate the known
# 0.003% multi-phase items; fail only if the sample shows pervasive ambiguity.
assert_sql <- sprintf("
  WITH s AS (SELECT numerodaoc, \"códigoitem\", po_phase_code
             FROM read_parquet('%s') LIMIT 2000000),
       g AS (SELECT numerodaoc, \"códigoitem\", COUNT(DISTINCT po_phase_code) np
             FROM s GROUP BY 1,2)
  SELECT SUM(CASE WHEN np>1 THEN 1 ELSE 0 END) AS multi, COUNT(*) AS tot FROM g", bid_path)
asr <- dbGetQuery(con, assert_sql)
multi_share <- if (asr$tot > 0) asr$multi / asr$tot else NA_real_
say("ASSERT item modality-uniqueness (sample of <=2M rows): multi-phase items=%d / %d (%.4f%%)",
    asr$multi, asr$tot, 100*multi_share)
if (!is.na(multi_share) && multi_share > 0.01)
  stop(sprintf("item-modality NOT unique (%.2f%% multi-phase > 1%% tolerance) -- stratum grain invalid.", 100*multi_share))

# item -> phase map (MAX collapses the 0.003% ambiguous items deterministically)
# In SMOKE we LIMIT the scan; in FULL we build the whole map.
limit_clause <- if (SMOKE) "LIMIT 8000000" else ""
say("building item->modality map (%s) ...", if (SMOKE) "SMOKE: LIMIT 8M bid rows" else "FULL")
itemmap_sql <- sprintf("
  SELECT CAST(numerodaoc AS VARCHAR) AS oc,
         CAST(\"códigoitem\" AS VARCHAR) AS item,
         MAX(CAST(po_phase_code AS INTEGER)) AS phase
  FROM (SELECT numerodaoc, \"códigoitem\", po_phase_code FROM read_parquet('%s') %s)
  GROUP BY 1,2", bid_path, limit_clause)
invisible(dbExecute(con, sprintf("CREATE OR REPLACE TEMP VIEW itemmap AS %s", itemmap_sql)))
phase_counts <- dbGetQuery(con, "SELECT phase, COUNT(*) n_items FROM itemmap GROUP BY 1 ORDER BY 2 DESC")
say("item->modality map phase counts:")
for (i in seq_len(nrow(phase_counts)))
  say("    phase=%-5s : %s items", phase_counts$phase[i], format(phase_counts$n_items[i], big.mark=","))

# firm x stratum participation = firm_tender_map JOIN itemmap on (oc,item).
# A firm is ACTIVE in a stratum if it has >=1 participation row in that modality.
# Per-stratum active-firm + active-cobidder + active-defendant counts (vs feasibility scan).
dbWriteTable(con, "cob_pos",   data.frame(firm_code = cob_codes),    overwrite = TRUE)
dbWriteTable(con, "direct_t",  data.frame(firm_code = direct_codes), overwrite = TRUE)
dbWriteTable(con, "al_firms",  data.frame(firm_code = al$firm_code), overwrite = TRUE)

strat_counts <- dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')
  ),
  fs AS (   -- firm x stratum participation (modality from itemmap)
    SELECT DISTINCT f.firm_code, m.phase
    FROM ftm f JOIN itemmap m ON f.oc = m.oc AND f.item = m.item
  )
  SELECT phase,
         COUNT(DISTINCT firm_code)                                                   AS n_firms_active,
         COUNT(DISTINCT CASE WHEN firm_code IN (SELECT firm_code FROM al_firms)  THEN firm_code END) AS n_AL_active,
         COUNT(DISTINCT CASE WHEN firm_code IN (SELECT firm_code FROM cob_pos)   THEN firm_code END) AS n_cob_active,
         COUNT(DISTINCT CASE WHEN firm_code IN (SELECT firm_code FROM direct_t)  THEN firm_code END) AS n_def_active
  FROM fs GROUP BY phase ORDER BY phase", ftm_path))
say("\nstratum-active firm counts (firm_tender_map JOIN itemmap):")
print(strat_counts)
sink(LOG, append=TRUE); print(strat_counts); sink()
stamp("B_stratum_assignment")

# Persist the firm x stratum membership (firm_code, phase, is_AL, is_cob) for the
# FULL evaluation step. In SMOKE we stop after this (chain owns the machine).
fs_membership <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')
  )
  SELECT DISTINCT f.firm_code, m.phase
  FROM ftm f JOIN itemmap m ON f.oc=m.oc AND f.item=m.item
  WHERE f.firm_code IN (SELECT firm_code FROM al_firms)", ftm_path)))
say("AL firm x stratum membership rows: %s", format(nrow(fs_membership), big.mark=","))

# --- SMOKE EXIT: validate stratum counts vs feasibility, then STOP ----------
if (SMOKE) {
  say("\n----- SMOKE verification: stratum counts vs feasibility scan -----")
  for (nm in names(STRATA)) {
    st <- STRATA[[nm]]
    row <- strat_counts[strat_counts$phase == st$phase, ]
    if (!nrow(row)) { say("  [%s] phase=%d NOT FOUND in sampled map (SMOKE LIMIT may undersample; FULL run uses all rows)", nm, st$phase); next }
    say("  [%s] phase=%d : active_firms=%s  AL_active=%s  cobidders_active=%s (feas~%d)  defendants_active=%s (feas~%d)",
        nm, st$phase, format(row$n_firms_active, big.mark=","), format(row$n_AL_active, big.mark=","),
        format(row$n_cob_active, big.mark=","), st$feas_cob,
        format(row$n_def_active, big.mark=","), st$feas_def)
  }
  say("\n  NOTE: SMOKE scans a LIMIT-%s bid sample, so cobidder/defendant counts will be", if (nchar(limit_clause)) "8M" else "full")
  say("  BELOW the feasibility figures (those are full-window). Rough proportionality + correct")
  say("  phase codes (5 / 9999) + clean modality-uniqueness assert are the smoke pass criteria.")
  dbDisconnect(con, shutdown = TRUE); gc()
  stamp("SMOKE_DONE")
  say("\nSMOKE DONE -- full AUC/permutation NOT run (concurrent chain owns the machine).")
  quit(save = "no", status = 0)
}

# =============================================================================
# C. WITHIN-STRATUM OPPORTUNITY CELLS + per-stratum AL participation (FULL only)
# =============================================================================
say("\n----- C. within-stratum (year x buyer) cells + AL participation -----")
# Build, PER STRATUM, the AL firm-opportunity rows carrying:
#   - cell key (year x buyer) -- year from cfg$get_year_map (NEVER substr federally),
#     buyer = codigo_ug from the panel (cfg$buyer_col), both restricted to the
#     stratum's tender-items. touches_defendant = item has a direct defendant.
# This mirrors script 02's MEDIUM cell logic (ig NOT_OBSERVED federally -> cell =
# (year,pbu)), but the participation rows + cells are SUBSET to the stratum.
register_keymap_local <- function(con) {
  # (numerodaoc,codigoitem) -> (codigo_ug buyer, result year), multi-UASG dropped.
  # HOSTILE-REVIEW FIX (2026-06-05): buyer comes from panel_single_ug (multi-UASG
  # pairs dropped), but cfg$get_year_map() reads the FULL panel. The old
  # merge(all=TRUE) re-introduced the ~265 dropped pairs with buyer NA, producing
  # degenerate "year|" cells. Build the year map from the SAME single-UG view and
  # INNER-join, so the dropped pairs are excluded consistently from buyer+year+cells.
  view <- cfg$drop_multi_ug_pairs(con)   # registers TEMP VIEW panel_single_ug
  km <- DBI::dbGetQuery(con, sprintf("
    SELECT CAST(numerodaoc AS VARCHAR) AS numerodaoc,
           CAST(\"códigoitem\" AS VARCHAR) AS \"códigoitem\",
           CAST(MAX(%s) AS VARCHAR)             AS buyer,
           CAST(MAX(CAST(year AS INTEGER)) AS INTEGER) AS year
    FROM %s GROUP BY 1,2", cfg$buyer_col, view))
  DBI::dbWriteTable(con, "keymap", km, overwrite = TRUE)
  invisible(km)
}
register_keymap_local(con)

# AL firm-opportunity rows, carrying stratum (phase), year, buyer, touches_def.
al_opp <- as.data.table(dbGetQuery(con, sprintf("
  WITH ftm AS (
    SELECT LPAD(CAST(\"códigofornecedor\" AS VARCHAR),14,'0') AS firm_code,
           CAST(numerodaoc AS VARCHAR) AS oc, CAST(\"códigoitem\" AS VARCHAR) AS item
    FROM read_parquet('%s')
  ),
  def_items AS (   -- tender-items containing a direct defendant
    SELECT DISTINCT oc, item FROM ftm WHERE firm_code IN (SELECT firm_code FROM direct_t)
  ),
  al_part AS (
    SELECT f.firm_code, f.oc, f.item, m.phase,
           COALESCE(k.buyer,'')             AS pbu,
           COALESCE(CAST(k.year AS VARCHAR),'0000') AS yr,
           CASE WHEN di.oc IS NOT NULL THEN 1 ELSE 0 END AS touches_def
    FROM ftm f
    JOIN al_firms a   ON f.firm_code = a.firm_code
    JOIN itemmap m    ON f.oc = m.oc AND f.item = m.item
    LEFT JOIN keymap k ON f.oc = k.numerodaoc AND f.item = k.\"códigoitem\"
    LEFT JOIN def_items di ON f.oc = di.oc AND f.item = di.item
  )
  SELECT firm_code, oc, item, phase, pbu, yr, touches_def FROM al_part", ftm_path)))
dbDisconnect(con, shutdown = TRUE); gc()
say("AL firm-opportunity rows (all strata): %s", format(nrow(al_opp), big.mark=","))
al_opp[, cell_id := paste(yr, pbu, sep="|")]   # within-stratum (year x buyer); ig NOT_OBSERVED federally
stamp("C_within_stratum_cells")

# =============================================================================
# D. PER-STRATUM EVALUATION  (raw AUC/PR-AUC + within-stratum + exposure-only)
# =============================================================================
say("\n----- D. per-stratum evaluation -----")
eval_one_stratum <- function(nm) {
  st    <- STRATA[[nm]]
  phase <- st$phase
  opp   <- al_opp[phase == st$phase]
  active_firms <- unique(opp$firm_code)
  # evaluation sample = AL firms ACTIVE in this stratum, with the POOLED construct.
  dat <- al[firm_code %in% active_firms]
  npos <- dat[cobidder==1L, .N]
  say("\n  [%s] phase=%d  N_active_AL=%s  N+(broad cobidder)=%d",
      nm, phase, format(nrow(dat), big.mark=","), npos)

  # POWER GUARD (honesty-first): under-powered strata emit a note, not a number.
  underpowered <- npos < POWER_MIN_NPOS
  if (underpowered)
    say("    *** UNDERPOWERED: N+ = %d < %d -> discrimination numbers SUPPRESSED (note emitted).", npos, POWER_MIN_NPOS)

  # within-stratum cells: per-cell defendant-contact rate p_g; firm expected contact
  # E_i = sum_g n_ig * p_g ; exposure proxy log_E = log1p(E_i). Mirrors script 02.
  cellagg <- opp[, .(n_part = .N, n_def_rows = sum(touches_def)), by=cell_id]
  cellagg[, p_g := n_def_rows / n_part]
  opp2 <- merge(opp, cellagg[, .(cell_id, p_g)], by="cell_id", all.x=TRUE)
  firm_O <- opp2[, .(O_i = sum(touches_def), E_i = sum(p_g, na.rm=TRUE)), by=firm_code]
  dat <- merge(dat, firm_O, by="firm_code", all.x=TRUE)
  dat[is.na(O_i), O_i := 0]; dat[is.na(E_i), E_i := 0]
  dat[, log_E := log1p(pmax(E_i, 0))]

  # within-stratum cell key for the C-statistic (year x buyer the firm most participates in)
  # HOSTILE-REVIEW FIX (2026-06-05): explicit stable tiebreak on cell_id so the
  # modal-cell pick is deterministic when two cells tie on participation count
  # (was an implicit order-dependent tie-break).
  firm_cell <- opp2[, .N, by=.(firm_code, cell_id)][order(-N, cell_id)][, .SD[1], by=firm_code][, .(firm_code, cell_id)]
  dat <- merge(dat, firm_cell, by="firm_code", all.x=TRUE)
  dat[is.na(cell_id), cell_id := "__none__"]

  if (underpowered) {
    return(data.table(
      stratum=nm, label=st$label, phase=phase,
      n_firms=nrow(dat), n_pos=npos,
      raw_auc=NA_real_, raw_auc_lo=NA_real_, raw_auc_hi=NA_real_, pr_auc=NA_real_,
      within_stratum_auc=NA_real_, exposure_only_auc=NA_real_,
      fl32_auc=NA_real_, underpowered=TRUE,
      note=sprintf("UNDERPOWERED (N+=%d<%d): discrimination suppressed", npos, POWER_MIN_NPOS)))
  }

  # raw discrimination of the POOLED score against broad-AL positives, in-stratum sample
  ar <- auc_ci("cobidder", "score_i", dat)
  pra <- average_precision(dat$cobidder, dat$score_i, na_action="drop")
  # within-stratum (year x buyer cell) C-statistic of the pooled score
  ws <- cell_strat_auc(dat, "score_i", "cobidder", "cell_id")
  # exposure-only benchmark: log_E (expected defendant contact by within-stratum cells)
  eo <- auc_ci("cobidder", "log_E", dat)
  # FL32 binary (pooled cut) raw AUC for reference
  fa <- auc_ci("cobidder", "fl32", dat)
  say("    raw AUC=%.4f [%.4f, %.4f]  PR-AUC=%.4f  within-stratum AUC=%.4f  exposure-only(E) AUC=%.4f  FL32 AUC=%.4f",
      ar$auc, ar$lo, ar$hi, pra, ws$auc, eo$auc, fa$auc)

  data.table(
    stratum=nm, label=st$label, phase=phase,
    n_firms=nrow(dat), n_pos=npos,
    raw_auc=ar$auc, raw_auc_lo=ar$lo, raw_auc_hi=ar$hi, pr_auc=pra,
    within_stratum_auc=ws$auc, exposure_only_auc=eo$auc,
    fl32_auc=fa$auc, underpowered=FALSE, note="")
}
res <- rbindlist(lapply(names(STRATA), eval_one_stratum), fill=TRUE)
stamp("D_per_stratum_eval")

# =============================================================================
# E. OUTPUTS  (csv + tex + macros)
# =============================================================================
say("\n----- E. outputs -----")
fwrite(res, file.path(dir_tab, "table_SRP_stratified.csv"))
say("wrote table_SRP_stratified.csv (%d strata rows)", nrow(res))

fmt <- function(x, d=3) ifelse(is.na(x), "--", sprintf(paste0("%.",d,"f"), x))
fmtci <- function(a,lo,hi) ifelse(is.na(a),"--",sprintf("%.3f [%.3f, %.3f]", a, lo, hi))
texrows <- paste0(
  gsub("_","\\\\_", res$stratum), " & ",
  format(res$n_firms, big.mark=","), " & ", res$n_pos, " & ",
  ifelse(res$underpowered, "\\textit{underpowered}", fmtci(res$raw_auc, res$raw_auc_lo, res$raw_auc_hi)), " & ",
  fmt(res$pr_auc), " & ", fmt(res$within_stratum_auc), " & ", fmt(res$exposure_only_auc), " \\\\")
texS <- c(
  "\\begin{table}[htbp]\\centering",
  "\\caption{Loser-side concentration signal across federal pregao variants (SRP stratification)}",
  "\\label{tab:srp_stratified}",
  "\\begin{tabular}{lrrlrrr}\\hline",
  "Stratum & N firms & N$^+$ & Raw AUC [CI] & PR-AUC & Within-stratum AUC & Exposure-only AUC \\\\\\hline",
  texrows,
  "\\hline\\end{tabular}",
  paste0("\\begin{tablenotes}\\footnotesize\\item Pooled construct held FIXED across strata: score $=\\log(1+\\text{tenders\\_count})$, FL32 cut ($\\geq 32$), and the broad-AL cobidder label. Only the EVALUATION sample (always-losers active in the stratum) and the within-stratum (year $\\times$ buyer) opportunity cells vary. Item-group NOT\\_OBSERVED federally. Strata with N$^+<",
         POWER_MIN_NPOS, "$ are reported as underpowered.\\end{tablenotes}"),
  "\\end{table}")
writeLines(texS, file.path(dir_tab, "table_SRP_stratified.tex"))
say("wrote table_SRP_stratified.tex")

# macros: \valFedAudSRPreg* / \valFedAudSRPsrp* (mirror script-12 newcommand style)
macro_lines <- character(0); macro_csv <- list()
emit <- function(name, value, note="") {
  macro_lines <<- c(macro_lines, sprintf("\\newcommand{\\%s}{%s} %% src: table_SRP_stratified.csv %s", name, value, note))
  macro_csv[[length(macro_csv)+1L]] <<- data.table(macro=name, value=value, note=note)
}
for (nm in names(STRATA)) {
  st <- STRATA[[nm]]; r <- res[stratum == nm]
  pref <- paste0("valFedAudSRP", st$macro)
  emit(paste0(pref, "N"),     format(r$n_firms, big.mark=","))
  emit(paste0(pref, "Npos"),  as.character(r$n_pos))
  if (isTRUE(r$underpowered)) {
    emit(paste0(pref, "RawAUC"),   "underpowered", paste0("N+=", r$n_pos, "<", POWER_MIN_NPOS))
    emit(paste0(pref, "PRAUC"),    "underpowered")
    emit(paste0(pref, "WithinAUC"),"underpowered")
    emit(paste0(pref, "ExpAUC"),   "underpowered")
  } else {
    emit(paste0(pref, "RawAUC"),    sprintf("%.3f", r$raw_auc))
    emit(paste0(pref, "RawAUCCI"),  sprintf("[%.3f, %.3f]", r$raw_auc_lo, r$raw_auc_hi))
    emit(paste0(pref, "PRAUC"),     sprintf("%.3f", r$pr_auc))
    emit(paste0(pref, "WithinAUC"), sprintf("%.3f", r$within_stratum_auc))
    emit(paste0(pref, "ExpAUC"),    sprintf("%.3f", r$exposure_only_auc))
  }
}
# consistency gap (only when both strata powered): |raw AUC reg - raw AUC srp|
rr <- res[stratum=="pregao_5"]; rs <- res[stratum=="SRP_9999"]
if (!isTRUE(rr$underpowered) && !isTRUE(rs$underpowered)) {
  gap <- abs(rr$raw_auc - rs$raw_auc)
  emit("valFedAudSRPgap", sprintf("%.3f", gap), "abs raw-AUC difference across strata")
  say("  cross-stratum raw-AUC consistency gap = %.4f", gap)
}
writeLines(macro_lines, file.path(dir_tab, "table_SRP_stratified_macros.tex"))
fwrite(rbindlist(macro_csv), file.path(dir_tab, "table_SRP_stratified_macros.csv"))
say("wrote table_SRP_stratified_macros.{tex,csv} (%d macros)", length(macro_lines))

# =============================================================================
# VERDICT
# =============================================================================
say("\n========== VERDICT ==========")
if (!isTRUE(rr$underpowered) && !isTRUE(rs$underpowered)) {
  gap <- abs(rr$raw_auc - rs$raw_auc)
  say("regular pregao raw AUC=%.4f  vs  SRP raw AUC=%.4f  (gap=%.4f)", rr$raw_auc, rs$raw_auc, gap)
  verdict <- if (gap < 0.05) "CONSISTENT (signal behaves equivalently across pregao variants)"
             else "HETEROGENEOUS (gap >= 0.05; pooling masks a difference -- report per-stratum)"
  say("VERDICT: %s", verdict)
} else {
  say("VERDICT: at least one stratum UNDERPOWERED (N+ < %d) -- per-stratum numbers suppressed.", POWER_MIN_NPOS)
}
say("\nALL DONE.")
stamp("DONE")
