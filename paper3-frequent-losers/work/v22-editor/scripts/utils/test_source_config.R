# =============================================================================
# test_source_config.R  --  self-test for source_config.R
#   * loads BOTH configs (bec, comprasnet)
#   * asserts every referenced INPUT file exists on disk
#   * asserts FL cut / convention / window / modality facts
#   * runs get_year_map() on a 1000-row sample (federal) with PRAGMA threads=4,
#     memory_limit='4GB'
#   * prints PASS/FAIL per assertion; exits non-zero if any FAIL.
# =============================================================================
suppressWarnings(suppressMessages({library(DBI); library(duckdb)}))

.script_dir <- {
  fa <- sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))])
  if (length(fa)) dirname(normalizePath(fa[1L])) else getwd()
}
source(file.path(.script_dir, "source_config.R"))

.n_pass <- 0L; .n_fail <- 0L
ok <- function(desc, cond) {
  cond <- isTRUE(cond)
  if (cond) { .n_pass <<- .n_pass + 1L; cat(sprintf("  PASS  %s\n", desc)) }
  else      { .n_fail <<- .n_fail + 1L; cat(sprintf("  FAIL  %s\n", desc)) }
  invisible(cond)
}

cat("=== source_config.R self-test ===\n\n")

bec <- get_source_config("bec")
fed <- get_source_config("comprasnet")
print(bec); print(fed); cat("\n")

# ---- input-file existence ---------------------------------------------------
cat("[1] input file existence\n")
bec_inputs <- c(bec$firm_tender_map, bec$firm_loss_stats, bec$freq_particip,
                bec$losers, bec$bid_level, bec$item_panel,
                bec$cade$crossmatch, bec$cade$carteis, bec$cade$cobidders)
for (p in bec_inputs) ok(sprintf("BEC exists: %s", basename(p)), file.exists(p))

fed_inputs <- c(fed$firm_tender_map, fed$firm_loss_stats, fed$freq_particip,
                fed$losers, fed$bid_level, fed$item_panel,
                fed$cade$direct_defendants, fed$cade$cobidders,
                fed$cade$anchored_tenders, fed$year_lookup_path)
for (p in fed_inputs) ok(sprintf("FED exists: %s", basename(p)), file.exists(p))

# ---- FL cut / convention / window / modality --------------------------------
cat("\n[2] constants\n")
ok("BEC FL_CUT==14 & convention >=", bec$FL_CUT == 14L && bec$FL_CONVENTION == ">=")
ok("FED FL_CUT==32 & convention >=", fed$FL_CUT == 32L && fed$FL_CONVENTION == ">=")
ok("BEC fl_predicate(14)==TRUE, (13)==FALSE", bec$fl_predicate(14L) && !bec$fl_predicate(13L))
ok("FED fl_predicate(32)==TRUE, (31)==FALSE", fed$fl_predicate(32L) && !fed$fl_predicate(31L))
ok("BEC window 2009-2019", bec$year_min == 2009L && bec$year_max == 2019L)
ok("FED window 2013-2019", fed$year_min == 2013L && fed$year_max == 2019L)
ok("BEC has_convite TRUE & modalities convite=1,pregao=3",
   bec$has_convite && identical(bec$modalities, list(convite = 1L, pregao = 3L)))
ok("FED has_convite FALSE & modalities pregao=5,pregao_srp=9999",
   !fed$has_convite && identical(fed$modalities, list(pregao = 5L, pregao_srp = 9999L)))

# ---- key-extraction semantics ----------------------------------------------
cat("\n[3] key extraction semantics (G1)\n")
ok("BEC key composite; year_from_key gives SUBSTR(...,12,4)",
   bec$key_is_composite &&
   grepl("SUBSTR\\(x,12,4\\)", gsub("\\s","", bec$year_from_key("x"))))
ok("BEC buyer_from_key gives SUBSTR(...,1,11)",
   grepl("SUBSTR\\(x,1,11\\)", gsub("\\s","", bec$buyer_from_key("x"))))
ok("FED key NOT composite; buyer_from_key & year_from_key are NULL",
   !fed$key_is_composite && is.null(fed$buyer_from_key) && is.null(fed$year_from_key))
ok("FED buyer_col == codigo_ug", identical(fed$buyer_col, "codigo_ug"))
ok("FED multi_ug_pairs_excluded TRUE; BEC FALSE",
   fed$multi_ug_pairs_excluded && !bec$multi_ug_pairs_excluded)
# SOURCE-CONFIG ADAPTATION (Phase 1, 2026-06-05): federal CONS_DATE is now wired to
# the conservative federal case-judgment bound (latest numbered-case judgment date),
# replacing the earlier NA placeholder (per Phase-1 script-03 adaptation, gate G3).
ok("FED & BEC CONS_DATE are both real Dates (FED wired from federal case judgments)",
   inherits(fed$CONS_DATE, "Date") && !is.na(fed$CONS_DATE) &&
   inherits(bec$CONS_DATE, "Date") && !is.na(bec$CONS_DATE))
ok("holdout split present; BEC test==FED test (comparable); FED train starts 2013",
   identical(as.integer(range(bec$holdout_test)), as.integer(range(fed$holdout_test))) &&
   min(bec$holdout_train) == 2009L && min(fed$holdout_train) == 2013L)
# SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): freeze_year locked to 2016
# in BOTH sources (lead decision). Distinct from CONS_DATE.
ok("freeze_year == 2016L in BOTH sources (lead decision)",
   identical(bec$freeze_year, 2016L) && identical(fed$freeze_year, 2016L))
ok("freeze_year is distinct from CONS_DATE (freeze is a year int, CONS_DATE a Date)",
   is.integer(bec$freeze_year) && is.integer(fed$freeze_year) &&
   inherits(bec$CONS_DATE, "Date") && inherits(fed$CONS_DATE, "Date"))
# SOURCE-CONFIG ADAPTATION (Phase 1 reconcile, 2026-06-05): item-group observability.
# BEC has a genuine 2-char product-group prefix (91 groups); federal códigoitem is a
# buyer-collinear composite -> item-group NOT_OBSERVED federally.
ok("BEC has_item_group TRUE & ig_from_key gives SUBSTR(...,1,2)",
   isTRUE(bec$has_item_group) && is.function(bec$ig_from_key) &&
   grepl("SUBSTR\\(x,1,2\\)", gsub("\\s","", bec$ig_from_key("x"))))
ok("FED has_item_group FALSE & ig_from_key is NULL (buyer-collinear composite)",
   identical(fed$has_item_group, FALSE) && is.null(fed$ig_from_key))

# ---- output isolation -------------------------------------------------------
cat("\n[4] output isolation\n")
ok("FED out_root under outputs/comprasnet/", grepl("outputs/comprasnet$", fed$out_root))
ok("FED temp_directory NOT under /tmp", !grepl("^/tmp", fed$temp_directory))
ok("BEC out_root unchanged (outputs, not comprasnet)",
   grepl("/outputs$", bec$out_root) && !grepl("comprasnet", bec$out_root))

# ---- get_year_map on a 1000-row federal sample ------------------------------
cat("\n[5] federal get_year_map() on 1000-row sample\n")
con <- dbConnect(duckdb())
dbExecute(con, "PRAGMA threads=4")
dbExecute(con, "PRAGMA memory_limit='4GB'")
dbExecute(con, sprintf("PRAGMA temp_directory='%s'",
                       file.path(fed$temp_directory)))
dir.create(fed$temp_directory, recursive = TRUE, showWarnings = FALSE)

# full helper produces a valid map (numerodaoc, codigoitem, year)
ym <- tryCatch(fed$get_year_map(con), error = function(e) {cat("   ERR:", conditionMessage(e),"\n"); NULL})
ok("get_year_map returns >0 rows", !is.null(ym) && nrow(ym) > 0L)
ok("get_year_map cols = numerodaoc, códigoitem, year",
   !is.null(ym) && all(c("numerodaoc","códigoitem","year") %in% names(ym)))
ok("get_year_map years within 2013-2019",
   !is.null(ym) && all(ym$year >= 2013L & ym$year <= 2019L, na.rm = TRUE))

# 1000-row-sample version of the same lookup (explicit, as required)
samp <- dbGetQuery(con, sprintf("
  SELECT CAST(numerodaoc AS VARCHAR) AS numerodaoc,
         CAST(\"códigoitem\" AS VARCHAR) AS \"códigoitem\",
         MAX(CAST(year AS INTEGER)) AS year
  FROM (SELECT * FROM read_parquet('%s') LIMIT 1000)
  GROUP BY 1,2", fed$year_lookup_path))
ok("1000-row sample year_map non-empty & years in-window",
   nrow(samp) > 0L && all(samp$year >= 2013L & samp$year <= 2019L, na.rm = TRUE))

# drop_multi_ug_pairs registers a usable view
nm <- tryCatch(fed$drop_multi_ug_pairs(con), error = function(e) {cat("   ERR:",conditionMessage(e),"\n"); NULL})
ok("drop_multi_ug_pairs registers panel_single_ug view",
   !is.null(nm) && identical(nm, "panel_single_ug") &&
   dbGetQuery(con, "SELECT COUNT(*) n FROM panel_single_ug")$n > 0L)

dbDisconnect(con, shutdown = TRUE)

# ---- ensure_dirs ------------------------------------------------------------
cat("\n[6] ensure_dirs() side-effect\n")
fed$ensure_dirs()
ok("FED ensure_dirs created diagnostics dir", dir.exists(fed$dirs$diagnostics))
ok("FED ensure_dirs created cache dir", dir.exists(fed$dirs$cache))
ok("FED ensure_dirs created spill dir", dir.exists(fed$temp_directory))

# ---- verdict ----------------------------------------------------------------
cat(sprintf("\n=== RESULT: %d PASS / %d FAIL ===\n", .n_pass, .n_fail))
if (.n_fail > 0L) quit(status = 1L, save = "no") else cat("ALL ASSERTIONS PASS\n")
