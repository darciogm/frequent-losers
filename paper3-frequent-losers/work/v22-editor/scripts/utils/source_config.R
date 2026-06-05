# =============================================================================
# source_config.R  --  Single source-abstraction layer for the two-platform
#                      (BEC Sao Paulo state  +  ComprasNet federal) extension of
#                      the frequent-losers cartel-screening paper (Paper 3, v22).
# -----------------------------------------------------------------------------
# ARCHITECTURE RULE (locked, JLEO R&R v22 ComprasNet extension execution plan):
#   ONE config, ZERO forked logic. Every audit script in scripts/analysis/ must
#   take ALL of its data paths, constants, key-extraction lambdas, output dirs,
#   cache dirs and modality definitions FROM THIS FILE via get_source_config().
#   Any hardcoded data path, FL cut, year/buyer substring, or /tmp cache that
#   survives in an adapted script IS A BUG. Scripts gain a `--source=` flag
#   (default "bec") and call get_source_config(source) once, near the top.
#
# WHY: BEC and ComprasNet share the same column NAMES (codigofornecedor,
#   numerodaoc, codigoitem, won, ...) but NOT the same key SEMANTICS. Forking
#   the logic per platform would silently desync the two pipelines. A single
#   config that returns paths + constants + lambdas keeps behaviour byte-
#   identical for BEC while letting the federal pipeline differ only where the
#   data genuinely differ.
#
# -----------------------------------------------------------------------------
# PHASE-0 PROVENANCE (verified facts; DO NOT re-derive in adapted scripts):
#
#   Gate G1 (key conventions) -- federal numbering vs result year:
#     * BEC  numerodaoc is a 22-char composite key:
#         chars  1-11  = buyer  (codigounidadecompradora / PBU code)
#         chars 12-15  = year   (4 digits)
#         chars 16-17  = "OC" literal ; 18-22 = OC sequence number.
#       => BEC buyer = substr(numerodaoc, 1, 11); year = substr(numerodaoc,12,4).
#         These substrings are STABLE for BEC and are kept unchanged.
#     * FEDERAL numerodaoc is a 9-char "NNNNNYYYY" string. The trailing 4 digits
#       are the NUMBERING year, which differs from the RESULT (award) year for
#       22.8% of rows. THEREFORE the federal year MUST NOT be string-extracted.
#       Federal year comes from item_level_panel.parquet via get_year_map(con),
#       a (numerodaoc, codigoitem) -> year lookup.
#     * FEDERAL buyer is a SEPARATE column, NOT a substring. On disk it lives in
#       item_level_panel.parquet as `codigo_ug` (6-digit UASG; conceptually the
#       federal analogue of BEC `codigounidadecompradora`). firm_tender_map.parquet
#       does NOT carry the buyer, so buyer-level federal ops must join the panel.
#     * 271 (on-disk 265 as of 2026-05-23 build) (numerodaoc, codigoitem) pairs
#       cross multiple UASGs. They are flagged (multi_ug_pairs_excluded = TRUE)
#       and dropped by drop_multi_ug_pairs(con) before buyer-level aggregation.
#
#   Gate G2 (FL cut + convention):
#     * BEC     : FL_CUT = 14, convention ">=" => 2735 FL firms (canonical).
#     * FEDERAL : FL_CUT = 32, convention ">=" => 6491 FL firms (canonical).
#         The earlier-logged 6303 used a buggy ">" comparison; 6491 is correct.
#
#   Gate G5 (modality / window):
#     * FEDERAL is PURE PREGAO: po_phase_code 5 = Pregao, 9999 = Pregao SRP.
#       There is NO convite at the federal level.
#     * BEC modality column codes 1 = Convite, 3 = Pregao (recoded `modality`
#       column in item_value_panel; distinct from raw po_phase_code 2/3).
#     * Window: BEC 2009-2019 ; FEDERAL 2013-2019 (source starts 2013-01).
#
# Output isolation: federal outputs go under work/v22-editor/outputs/comprasnet/
#   {targets,tables,diagnostics,cache,logs}; BEC outputs unchanged (current
#   paths). Federal cache is NEVER under /tmp shared with BEC (no collisions).
#
# =============================================================================

suppressWarnings(suppressMessages({
  if (!requireNamespace("DBI", quietly = TRUE))     stop("source_config.R needs DBI")
  if (!requireNamespace("duckdb", quietly = TRUE))  stop("source_config.R needs duckdb")
}))

# -----------------------------------------------------------------------------
# .resolve_repo() -- locate paper3-frequent-losers repo root robustly, matching
# the idiom used across the analysis scripts (works whether sourced via
# Rscript --file=, via .script_dir, or interactively).
# -----------------------------------------------------------------------------
.resolve_repo <- function() {
  cand <- character(0)
  if (exists(".script_dir", inherits = TRUE)) {
    cand <- c(cand, normalizePath(file.path(get(".script_dir", inherits = TRUE),
                                            "..", "..", "..", ".."), mustWork = FALSE))
  }
  fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
  if (length(fa)) {
    sd <- dirname(normalizePath(fa[1L], mustWork = FALSE))
    # this file lives at work/v22-editor/scripts/utils/  -> repo is 4 levels up
    cand <- c(cand, normalizePath(file.path(sd, "..", "..", "..", ".."), mustWork = FALSE))
  }
  cand <- c(cand, "/home/darciogm1/projetos/bitter-pills/paper3-frequent-losers")
  for (r in cand) if (dir.exists(file.path(r, "data", "processed"))) return(r)
  # last resort: return the hardcoded canonical even if check fails (let caller error)
  cand[length(cand)]
}

# -----------------------------------------------------------------------------
# get_source_config(source)
# -----------------------------------------------------------------------------
#' Source-abstraction config for the BEC / ComprasNet two-platform pipeline.
#'
#' @param source One of "bec" (default) or "comprasnet".
#' @return A named list. Every field an adapted analysis script may need:
#'
#'   $source            : "bec" | "comprasnet"
#'   $label             : human-readable platform label
#'   $repo              : repo root (paper3-frequent-losers)
#'   $data_dir          : directory holding the BEC-mirror parquet filenames
#'
#'   --- core input parquets (BEC-mirror filenames in both sources) ----------
#'   $firm_tender_map   : firm x (oc,item) participation + won flag
#'   $firm_loss_stats   : per-firm win_rate / always_loser
#'   $freq_particip     : always-losers with tenders_count (FL universe input)
#'   $losers            : FL counts per (oc,item)
#'   $bid_level         : raw bid-level parquet
#'   $item_panel        : item-level value/modality/year panel
#'                        (BEC: item_value_panel ; FED: item_level_panel)
#'
#'   --- CADE / linkage inputs ------------------------------------------------
#'   $cade              : list of CADE/crossmatch/defendant linkage paths.
#'                        BEC : $crossmatch, $carteis, $cobidders (csv files)
#'                        FED : $direct_defendants, $cobidders, $anchored_tenders
#'                              (cade_link_v3 parquets)
#'   $cade_layout       : "bec_csv" | "federal_parquet_v3" (which branch to use)
#'
#'   --- FL screen constants --------------------------------------------------
#'   $FL_CUT            : tenders_count cut (BEC 14 ; FED 32)
#'   $FL_CONVENTION     : ">=" (both)
#'   $fl_predicate(tc)  : vectorised logical helper applying FL_CUT + convention
#'
#'   --- window / modality ----------------------------------------------------
#'   $year_min,$year_max: inclusive analysis window
#'   $modalities        : named list of modality CODE(s) per label, e.g.
#'                        BEC list(convite=1L, pregao=3L)
#'                        FED list(pregao=5L, pregao_srp=9999L)
#'   $has_convite       : logical (TRUE only for BEC)
#'   $modality_col      : column carrying the (recoded) modality in $item_panel
#'   $phase_codes       : raw po_phase_code value(s) that define each modality
#'                        in the item panel (FED: 5,9999 ; BEC: 2,3 raw)
#'
#'   --- key extraction (THE crux of G1) -------------------------------------
#'   $key_is_composite  : TRUE if numerodaoc encodes buyer+year (BEC only)
#'   $buyer_from_key    : lambda(varchar_sql) -> SQL expr for buyer, or NULL
#'   $year_from_key     : lambda(varchar_sql) -> SQL expr for year,  or NULL
#'                        (NULL for federal -- year MUST come from get_year_map)
#'   $buyer_col         : name of the buyer column when NOT a substring
#'                        (FED "codigo_ug" ; BEC NA -- substring instead)
#'   $year_lookup_path  : path to the parquet backing get_year_map (FED only)
#'   $get_year_map(con) : DuckDB helper -> data.frame (numerodaoc,codigoitem,year)
#'   $multi_ug_pairs_excluded : logical flag (FED TRUE)
#'   $drop_multi_ug_pairs(con): registers/returns a cleaned panel view dropping
#'                              (numerodaoc,codigoitem) pairs that span >1 UASG.
#'                              No-op (returns NULL) for BEC.
#'
#'   --- clustering / timing --------------------------------------------------
#'   $cluster_keys      : c("oc","item") tender-item clustering identity
#'   $tender_key        : c(buyer, "numerodaoc") for buyer-level ops
#'   $CONS_DATE         : conservative-case cutoff Date (the latest case-judgment
#'                        date used as the conservative observability bound).
#'   $holdout_train     : integer vector of TRAIN years for the strict timing
#'                        holdout (script 03). BEC 2009:2016 ; FED 2013:2016.
#'   $holdout_test      : integer vector of TEST years for the strict timing
#'                        holdout. SAME test window 2017:2019 for both sources
#'                        (comparability; PROVISIONAL pending lead review).
#'   $freeze_year       : label-frozen timing cutoff (BOTH = 2016L). BEC preserves
#'                        the hard-pinned 2016 in script 12; comprasnet uses an
#'                        in-window freeze (window 2013-2019) aligned with
#'                        holdout_train max. LEAD DECISION 2026-06-05. Distinct from
#'                        CONS_DATE (which serves judgment-date provenance, not freeze).
#'   $item_panel_item_col : name of the item-code column INSIDE $item_panel
#'                        (BEC "codigoitem" no accent ; FED "códigoitem" accent).
#'                        firm_tender_map always uses "códigoitem" (accent) in
#'                        both sources; only the item PANEL column name differs.
#'
#'   --- output isolation -----------------------------------------------------
#'   $out_root          : root outputs dir for this source
#'   $dirs              : list(targets,tables_main,tables_app,figures_main,
#'                             figures_app,diagnostics,cache,logs)
#'   $temp_directory    : duckdb spill dir (FED: own dir, never /tmp shared)
#'   $ensure_dirs()     : create all output + cache + spill dirs
#'
#' RULE: scripts must take ALL paths/constants/lambdas from this config.
#'       Any hardcoded path in an adapted script is a bug.
get_source_config <- function(source = c("bec", "comprasnet")) {
  source <- match.arg(source)
  repo   <- .resolve_repo()
  v22    <- file.path(repo, "work", "v22-editor")

  if (source == "bec") {
    data_dir <- file.path(repo, "data", "processed")
    out_root <- file.path(v22, "outputs")               # BEC: current paths, unchanged
    dirs <- list(
      targets      = file.path(out_root, "targets"),
      tables_main  = file.path(out_root, "tables", "main"),
      tables_app   = file.path(out_root, "tables", "appendix"),
      figures_main = file.path(out_root, "figures", "main"),
      figures_app  = file.path(out_root, "figures", "appendix"),
      diagnostics  = file.path(out_root, "diagnostics"),
      cache        = file.path(out_root, "cache"),
      logs         = file.path(out_root, "logs")
    )
    temp_dir <- "/tmp/duckdb_spill"                     # BEC keeps its current spill dir

    cfg <- list(
      source = "bec",
      label  = "BEC (Sao Paulo state, 2009-2019)",
      repo   = repo,
      data_dir = data_dir,

      firm_tender_map = file.path(data_dir, "firm_tender_map.parquet"),
      firm_loss_stats = file.path(data_dir, "firm_loss_stats.parquet"),
      freq_particip   = file.path(data_dir, "FREQ_PARTICIP_rebuilt.parquet"),
      losers          = file.path(data_dir, "LOSERS_rebuilt.parquet"),
      bid_level       = file.path(data_dir, "bid_level_full.parquet"),
      item_panel      = file.path(data_dir, "item_value_panel.parquet"),

      cade_layout = "bec_csv",
      cade = list(
        crossmatch = file.path(data_dir, "cade_bec_crossmatch.csv"),
        carteis    = file.path(data_dir, "cade_carteis_licitacoes_2009_2019.csv"),
        cobidders  = file.path(data_dir, "cade_fl_cobidders.csv")  # internal comparison ONLY
      ),

      FL_CUT        = 14L,
      FL_CONVENTION = ">=",
      fl_predicate  = function(tc) tc >= 14L,

      year_min = 2009L, year_max = 2019L,
      modalities   = list(convite = 1L, pregao = 3L),  # recoded `modality` column
      has_convite  = TRUE,
      modality_col = "modality",
      phase_codes  = list(convite = 2L, pregao = 3L),  # raw po_phase_code

      # --- key extraction: BEC numerodaoc IS the composite key (chars 1-11 buyer,
      #     12-15 year). substr is stable; kept unchanged.
      key_is_composite = TRUE,
      buyer_from_key = function(varchar_sql) sprintf("SUBSTR(%s,1,11)",  varchar_sql),
      year_from_key  = function(varchar_sql) sprintf("SUBSTR(%s,12,4)",  varchar_sql),
      buyer_col = NA_character_,
      year_lookup_path = NA_character_,
      get_year_map = function(con) {
        stop("get_year_map() is federal-only; BEC year = year_from_key(numerodaoc).")
      },
      multi_ug_pairs_excluded = FALSE,
      drop_multi_ug_pairs = function(con) invisible(NULL),  # no-op for BEC

      cluster_keys = c("oc", "item"),
      tender_key   = c("buyer_substr", "numerodaoc"),  # buyer is substr of the key
      CONS_DATE    = as.Date("2020-12-31"),

      # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): strict-timing holdout split
      # (script 03). BEC unchanged: train 2009-2016, test 2017-2019 (preserves the
      # hardcoded build_holdout(2009:2016, 2017:2019) behaviour byte-for-byte).
      holdout_train = 2009:2016,
      holdout_test  = 2017:2019,
      # SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): label-frozen timing
      # cutoff. BEC: preserves the hard-pinned 2016 in script 12; comprasnet: in-window
      # freeze (window 2013-2019) aligned with holdout_train max -- LEAD DECISION
      # 2026-06-05. (Distinct from CONS_DATE, which serves judgment-date provenance.)
      freeze_year = 2016L,
      # BEC item_value_panel item column is "codigoitem" (NO accent); firm_tender_map
      # uses "códigoitem" (accent). Only the panel column name differs across sources.
      item_panel_item_col = "codigoitem",

      # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): item-group + panel cols.
      # BEC códigoitem is a SHORT bare item code (mostly 5-7 chars; verified
      # 91 distinct SUBSTR(1,2) groups) -> SUBSTR(1,2) is a genuine product-group
      # prefix. ig_from_key takes the firm_tender_map códigoitem (accented) SQL expr.
      has_item_group = TRUE,
      ig_from_key    = function(varchar_sql) sprintf("SUBSTR(%s,1,2)", varchar_sql),
      # item_value_panel value / bidder-count column names (BEC recoded panel).
      item_value_col = "item_value",
      n_firms_col    = "n_firms",

      out_root = out_root,
      dirs     = dirs,
      temp_directory = temp_dir
    )

  } else { # comprasnet
    data_dir  <- file.path(repo, "data", "processed_comprasnet")
    link_dir  <- file.path(data_dir, "cade_link_v3")
    out_root  <- file.path(v22, "outputs", "comprasnet")   # ISOLATED federal outputs
    dirs <- list(
      targets      = file.path(out_root, "targets"),
      tables_main  = file.path(out_root, "tables"),
      tables_app   = file.path(out_root, "tables"),
      figures_main = file.path(out_root, "figures"),
      figures_app  = file.path(out_root, "figures"),
      diagnostics  = file.path(out_root, "diagnostics"),
      cache        = file.path(out_root, "cache"),
      logs         = file.path(out_root, "logs")
    )
    temp_dir  <- file.path(out_root, "cache", "duckdb_spill")  # NEVER /tmp shared with BEC

    year_lookup <- file.path(data_dir, "item_level_panel.parquet")

    cfg <- list(
      source = "comprasnet",
      label  = "ComprasNet (federal, 2013-2019, pure Pregao)",
      repo   = repo,
      data_dir = data_dir,

      firm_tender_map = file.path(data_dir, "firm_tender_map.parquet"),
      firm_loss_stats = file.path(data_dir, "firm_loss_stats.parquet"),
      freq_particip   = file.path(data_dir, "FREQ_PARTICIP_rebuilt.parquet"),
      losers          = file.path(data_dir, "LOSERS_rebuilt.parquet"),
      bid_level       = file.path(data_dir, "bid_level_full.parquet"),
      item_panel      = year_lookup,   # item_level_panel.parquet

      cade_layout = "federal_parquet_v3",
      cade = list(
        # canonical federal CADE linkage (cade_link_v3). cobidders_federal is
        # SET-COMPARISON ONLY -- canonical cobidder rebuild comes later (Phase 1
        # task #2), do NOT treat it as the validation target yet.
        direct_defendants = file.path(link_dir, "direct_defendants_federal.parquet"), # 27 estabs, 19 raizes
        cobidders         = file.path(link_dir, "cobidders_federal.parquet"),         # set-comparison only
        anchored_tenders  = file.path(link_dir, "anchored_tenders_federal.parquet"),  # 32,148 pairs
        cnpjs_enriched    = file.path(link_dir, "cnpjs_enriched.csv")
      ),

      FL_CUT        = 32L,
      FL_CONVENTION = ">=",
      fl_predicate  = function(tc) tc >= 32L,           # canonical federal FL = 6491

      year_min = 2013L, year_max = 2019L,
      modalities   = list(pregao = 5L, pregao_srp = 9999L),  # pure Pregao; NO convite
      has_convite  = FALSE,
      modality_col = "po_phase_code",  # federal panel carries raw po_phase_code (5 / 9999)
      phase_codes  = list(pregao = 5L, pregao_srp = 9999L),

      # --- key extraction (G1): federal numerodaoc is 9-char NNNNNYYYY. The
      #     trailing year is the NUMBERING year (differs from result year for
      #     22.8% of rows) so it MUST NOT be string-extracted. Buyer is a
      #     SEPARATE column (codigo_ug in item_level_panel), not a substring.
      key_is_composite = FALSE,
      buyer_from_key = NULL,   # buyer is NOT in the key -> use $buyer_col + panel join
      year_from_key  = NULL,   # year MUST come from get_year_map(), never substr
      buyer_col = "codigo_ug", # 6-digit UASG; federal analogue of codigounidadecompradora
      year_lookup_path = year_lookup,

      # get_year_map(con): (numerodaoc, codigoitem) -> result year via DuckDB.
      get_year_map = function(con) {
        DBI::dbGetQuery(con, sprintf("
          SELECT CAST(numerodaoc AS VARCHAR) AS numerodaoc,
                 CAST(\"códigoitem\" AS VARCHAR) AS \"códigoitem\",
                 MAX(CAST(year AS INTEGER)) AS year
          FROM read_parquet('%s')
          GROUP BY 1, 2", year_lookup))
      },

      multi_ug_pairs_excluded = TRUE,
      # drop_multi_ug_pairs(con): registers a view `panel_single_ug` (and returns
      # its name) excluding the (numerodaoc, codigoitem) pairs that span >1 UASG
      # (271 expected; 265 on the 2026-05-23 build). Call before buyer-level ops.
      drop_multi_ug_pairs = function(con) {
        DBI::dbExecute(con, sprintf("
          CREATE OR REPLACE TEMP VIEW panel_single_ug AS
          WITH multi AS (
            SELECT numerodaoc, \"códigoitem\"
            FROM read_parquet('%s')
            GROUP BY numerodaoc, \"códigoitem\"
            HAVING COUNT(DISTINCT codigo_ug) > 1
          )
          SELECT p.*
          FROM read_parquet('%s') p
          ANTI JOIN multi m
            ON p.numerodaoc = m.numerodaoc AND p.\"códigoitem\" = m.\"códigoitem\"",
          year_lookup, year_lookup))
        invisible("panel_single_ug")
      },

      cluster_keys = c("oc", "item"),
      tender_key   = c("codigo_ug", "numerodaoc"),  # buyer-level ops use UASG + OC number

      # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): federal CONS_DATE wired.
      # Gate G3: the 7 NUMBERED federal CADE cases are the SAME processo numbers as
      # BEC, so federal per-case judgment dates come from the SAME provenance the BEC
      # pipeline uses -- data/processed/cade_carteis_licitacoes_2009_2019.csv
      # (numero_processo / data_julgamento), mirrored in output/label_funnel/
      # case_timing.csv (proc / jdate) and data/processed_comprasnet/cade_link_v3/
      # cnpjs_enriched.csv (numero_processo / data_julgamento). Per-case dates of the
      # 7 federal numbered processos (5 dated, 2 national-medicamentos cases undated):
      #   08700.004617/2013-41 -> 2019-07-08   (trens_metros)
      #   08012.010022/2008-16 -> 2021-04-14   (merenda_escolar)
      #   08700.005789/2015-02 -> 2023-09-13   (sacos_de_lixo)
      #   08012.002222/2011-09 -> 2024-12-11   (medicamentos)
      #   08700.005876/2019-85 -> 2025-02-26   (transporte_escolar)
      #   08012.005928/2003-12 -> (no judgment date in CADE source)
      #   08012.008821/2008-22 -> (no judgment date in CADE source)
      # The 8th federal defendant group (setor=tecnologia_informacao, uf=DF) has an
      # EMPTY processo and is EXCLUDED from any case-anchored analysis (gate G3).
      # CONS_DATE is the conservative single-scalar observability bound = the LATEST
      # judgment date among the federal numbered cases (so all anchored conduct is
      # legally observable by then), the federal analogue of BEC's 2020-12-31.
      # PROVISIONAL pending lead review (the per-case dates above are the precise
      # objects; scripts that need per-case cutoffs should read them from the CADE
      # CSV by processo rather than this scalar).
      CONS_DATE = as.Date("2025-02-26"),

      # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): strict-timing holdout split.
      # FED window starts 2013 so train = 2013:2016; test = 2017:2019 KEPT IDENTICAL
      # to BEC so the two strict-timing holdouts are directly comparable.
      # PROVISIONAL pending lead review.
      holdout_train = 2013:2016,
      holdout_test  = 2017:2019,
      # SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): label-frozen timing
      # cutoff. comprasnet: in-window freeze (window 2013-2019) aligned with
      # holdout_train max -- LEAD DECISION 2026-06-05. BEC pins the same 2016 in
      # script 12. (Distinct from CONS_DATE, which serves judgment-date provenance.)
      freeze_year = 2016L,
      # FED item_level_panel item column is "códigoitem" (WITH accent), unlike BEC.
      item_panel_item_col = "códigoitem",

      # SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): item-group + panel cols.
      # G1 cardinality verification (2026-06-05): federal códigoitem is a 22-char
      # COMPOSITE key whose first 6 chars ARE codigo_ug (UASG buyer). Confirmed in
      # item_level_panel: SUBSTR(códigoitem,1,2) == SUBSTR(codigo_ug,1,2) on the
      # diagonal for EVERY group (15->15, 16->16, 12->12, ...). So the 2-char prefix
      # is a BUYER-REGION proxy, NOT a product taxonomy; reusing it would make
      # item-group HHI mechanically collinear with buyer HHI and corrupt the §5
      # breadth/specialization panels. The federally-meaningful product label is the
      # free-text descricao_item, not a cheap fixed taxonomy -> item-group is marked
      # NOT_OBSERVED federally (ig_from_key = NULL; has_item_group = FALSE).
      has_item_group = FALSE,
      ig_from_key    = NULL,
      # FED item_level_panel value / bidder-count columns (NO recoded item_value).
      item_value_col = "valor_item",
      n_firms_col    = "n_firms",

      out_root = out_root,
      dirs     = dirs,
      temp_directory = temp_dir
    )
  }

  # ensure_dirs(): create every output dir + cache + spill dir for this source.
  cfg$ensure_dirs <- function() {
    for (d in cfg$dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)
    dir.create(cfg$temp_directory, recursive = TRUE, showWarnings = FALSE)
    invisible(cfg$dirs)
  }

  # ---------------------------------------------------------------------------
  # SOURCE-CONFIG ADAPTATION (Phase 1 estrang-fix, 2026-06-05)
  # 14-char firm-code normalizers, source-gated for BEC byte-identity (gate R1).
  #
  # PROBLEM: the federal firm_tender_map carries 119/92,600 distinct non-numeric
  #   supplier codes -- 117 'ESTRANG*' foreign-supplier codes plus 2 already-14-char
  #   '000...-NN' codes. printf('%014.0f', CAST(x AS DOUBLE)) CRASHES on these
  #   ("Could not convert string 'ESTRANG0014259' to DOUBLE"). They are REAL foreign
  #   firms: they legitimately never match a CADE CNPJ; they must pass through RAW,
  #   never be dropped or NA-collapsed.
  #
  # SAFE NORMALIZATION (locked design): a numeric-pattern code is zero-padded to 14;
  #   a non-numeric code passes through RAW (.character / its own VARCHAR).
  #
  # BEC BYTE-IDENTITY PROOF (2026-06-05, this machine):
  #   * SQL: over DISTINCT BEC firm_tender_map códigofornecedor (41,444 distinct),
  #     printf('%014d', BIGINT) == printf('%014.0f', DOUBLE) for ALL 41,443 NUMERIC
  #     codes (0 mismatch; max BIGINT 9.867e13 < 2^53). The ONE divergence is the
  #     sentinel '-1' (regex [0-9]+ rejects the sign): literal renders '-0000000000001',
  #     safe renders '-1'. '-1' is NOT in the always-loser universe (FREQ_PARTICIP),
  #     but R1 is strict -> the safe SQL is GATED FEDERAL-ONLY and BEC keeps the literal.
  #   * R: over the vectors norm14 is actually applied to (FREQ_PARTICIP 16,843;
  #     crossmatch firm_cnpj 47; canonical_cobidders_broad 16,877) there are ZERO
  #     non-numeric BEC codes and ZERO norm14/norm14_safe mismatches. BEC is still
  #     gated to the literal for defensive R1 identity on any future BEC vector.
  #
  # => BOTH helpers reproduce the EXACT legacy literal for source=="bec"; the safe
  #    numeric-or-raw branch fires ONLY for federal.
  # ---------------------------------------------------------------------------

  # norm14_sql_expr(col_sql): returns a SQL scalar expression that normalizes the
  #   given (already SQL-quoted) column reference to a 14-char firm code. BEC: exact
  #   legacy literal. Federal: numeric -> printf('%014d', BIGINT); else RAW VARCHAR.
  cfg$norm14_sql_expr <- if (identical(cfg$source, "bec")) {
    function(col_sql) sprintf("printf('%%014.0f', CAST(%s AS DOUBLE))", col_sql)
  } else {
    function(col_sql) sprintf(paste0(
      "CASE WHEN regexp_full_match(CAST(%1$s AS VARCHAR), '[0-9]+') ",
      "THEN printf('%%014d', CAST(%1$s AS BIGINT)) ELSE CAST(%1$s AS VARCHAR) END"),
      col_sql)
  }

  # norm14_safe(x): R-side vector normalizer. BEC: exact legacy sprintf("%014.0f",
  #   as.numeric(x)). Federal: numeric-pattern element -> pad14; else as.character raw.
  cfg$norm14_safe <- if (identical(cfg$source, "bec")) {
    function(x) sprintf("%014.0f", as.numeric(x))
  } else {
    function(x) {
      x   <- as.character(x)
      num <- grepl("^[0-9]+$", x)
      out <- x
      out[num] <- sprintf("%014.0f", as.numeric(x[num]))
      out
    }
  }

  class(cfg) <- c("source_config", "list")
  cfg
}

# Convenience printer
print.source_config <- function(x, ...) {
  cat(sprintf("<source_config: %s>\n", x$label))
  cat(sprintf("  data_dir   : %s\n", x$data_dir))
  cat(sprintf("  FL_CUT     : %d (%s)  window %d-%d\n",
              x$FL_CUT, x$FL_CONVENTION, x$year_min, x$year_max))
  cat(sprintf("  modalities : %s  (convite=%s)\n",
              paste(names(x$modalities), unlist(x$modalities), sep = "=", collapse = ", "),
              x$has_convite))
  cat(sprintf("  key        : composite=%s buyer_col=%s multi_ug_excluded=%s\n",
              x$key_is_composite, x$buyer_col, x$multi_ug_pairs_excluded))
  cat(sprintf("  out_root   : %s\n", x$out_root))
  invisible(x)
}
