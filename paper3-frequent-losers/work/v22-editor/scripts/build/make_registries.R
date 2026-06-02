#!/usr/bin/env Rscript
# make_registries.R -- deterministically (re)generate the machine-readable
# output + dataset registries for the JLEO R&R (v22). No manual spreadsheet.
# Writes: outputs/output_registry.csv, outputs/dataset_registry.csv
# Run: Rscript scripts/build/make_registries.R   (or `make audit`)

.dir <- function() { a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", grep("^--file=", a, value = TRUE))
  if (length(f)) dirname(normalizePath(f)) else getwd() }
ROOT  <- normalizePath(file.path(.dir(), "..", ".."))         # work/v22-editor
OUTd  <- file.path(ROOT, "outputs"); dir.create(OUTd, showWarnings = FALSE, recursive = TRUE)
PAPER <- normalizePath(file.path(ROOT, "..", ".."))           # paper3-frequent-losers
ANALOUT <- function(...) file.path(PAPER, "output", ...)      # shared analysis outputs

exists_path <- function(p) if (file.exists(p)) "existing_current" else "planned"
last_gen <- function(p) if (file.exists(p))
  format(file.info(p)$mtime, "%Y-%m-%d") else NA_character_

# ---- OUTPUT REGISTRY --------------------------------------------------------
# columns: output_id,output_name,output_type,manuscript_destination,current_path,
#          revised_path,generating_script,data_inputs,data_level,primary_metrics,
#          status,last_generated,notes
o <- function(id,name,type,dest,cur,rev,gen,inp,lvl,met,notes) {
  if (nargs() != 11L) stop(sprintf("output row '%s' has %d args, need 11", id, nargs()))
  data.frame(
  output_id=id, output_name=name, output_type=type, manuscript_destination=dest,
  current_path=cur, revised_path=rev, generating_script=gen, data_inputs=inp,
  data_level=lvl, primary_metrics=met,
  status=exists_path(file.path(PAPER, cur)), last_generated=last_gen(file.path(PAPER, cur)),
  notes=notes, stringsAsFactors=FALSE) }

outreg <- rbind(
 o("MAIN_LABEL_FUNNEL","Label funnel & sample reconciliation","table","sec04 Table A",
   "output/label_funnel/funnel.csv","outputs/tables/main/tab_label_funnel.tex",
   "scripts/79_label_funnel.R","cade_carteis;crossmatch;firm_tender_map;FREQ_PARTICIP",
   "case/firm","counts","RUN: cons 208/107 reproduce; main 193->341 (U2 disclose+robustness)"),
 o("MAIN_OPPORTUNITY_ADJUSTED_VALIDATION","Opportunity-adjusted validation","table","sec04 Table B",
   "output/exposure_adjusted_audit/auc_summary.csv","outputs/tables/main/tab_exposure_adjusted.tex",
   "scripts/76_exposure_adjusted_audit.R","cade_fl_cobidders;crossmatch;FREQ_PARTICIP;firm_tender_map",
   "firm","AUC;DeLong","RUN PASS: within-opp 0.7715; +0.0415 p=2.08e-6; exp-only alone 0.946"),
 o("MAIN_TIMING_CASE_HOLDOUT","Timing & case-holdout validation","table","sec04 Table C",
   "output/strict_train_threshold/strict_train_threshold.csv","outputs/tables/main/tab_timing_loco.tex",
   "scripts/53_strict_train_period_threshold.R;scripts/77_reverse_causality_timing.R;NEW scripts/80_leave_one_case_out.R",
   "firm_tender_map;cobidders;case_cobidder_map","firm;firm-year;case","AUC;HHI;recall",
   "53/77 RUN; 77 FAIL (obs-equiv); LOCO pending script 80"),
 o("MAIN_COST_RECALL_FRONTIER","Cost-recall frontier","table","sec06 Table D",
   "output/regulatory_frontier/","outputs/tables/main/tab_cost_recall_frontier.tex",
   "scripts/56_regulatory_cost_frontier.R;scripts/63_architecture_gatekeeper.R",
   "bid_level;cobidders;firm_panel","firm;cell;bid","recall;precision;cost",
   "BLOCKED: output/regulatory_frontier/ EMPTY (run 56)"),
 o("MAIN_BID_BENCHMARK_AUDIT","Bid-layer benchmark audit","table","sec06 Table E",
   "output/imhof_incremental/","outputs/tables/main/tab_bid_benchmark.tex",
   "scripts/31_imhof_full_pipeline.R;scripts/49_imhof_incremental_value.R",
   "bid_level;cobidders","bid;item","AUC;features","needs feature/CV/missingness documentation"),
 o("MAIN_UNIT_OF_ANALYSIS","Unit-of-analysis table","table","sec02 Table F",
   "outputs/tables/main/tab_unit_of_analysis.tex","outputs/tables/main/tab_unit_of_analysis.tex",
   "docs+01_clean.R","data dictionary","meta","level;N;key","documentation table; to build"),
 o("MAIN_CADE_CASE_TIMING","CADE case timing","table","sec02 Table G",
   "output/label_funnel/case_timing.csv","outputs/tables/main/tab_cade_case_timing.tex",
   "scripts/79_label_funnel.R","cade_carteis","case","dates;n_def","RUN: 12 cases, 9 dated, 3 NaT"),
 o("APP_PARTICIPATION_BINS","Participation-bin monotonicity","table","App D",
   "output/auc_by_subsample/auc_subsample.csv","outputs/tables/appendix/tab_participation_bins.tex",
   "scripts/26_auc_by_subsample.R;scripts/54_threshold_table_q3iqr.R","firm_tender_map;cobidders",
   "firm","AUC","add observed-vs-expected by bin"),
 o("APP_EXPOSURE_CELL_CONSTRUCTION","Exposure-cell construction","table","App C/D",
   "output/exposure_adjusted_audit/firm_panel.csv","outputs/tables/appendix/tab_exposure_cells.tex",
   "scripts/76_exposure_adjusted_audit.R","firm_tender_map","firm","cell defn","RUN"),
 o("APP_EXPOSURE_PERMUTATION","Exposure-adjusted permutation","table","App D.1",
   "output/sham_fl/sham_auc_distribution.csv","outputs/tables/appendix/tab_exposure_permutation.tex",
   "scripts/25_sham_fl_permutation.R","cobidders;firm_tender_map","firm","perm AUC","seed 20260430"),
 o("APP_STRICT_TIMING_ROBUSTNESS","Strict-timing robustness","table","App D",
   "output/strict_train_threshold/strict_train_threshold.csv","outputs/tables/appendix/tab_strict_timing.tex",
   "scripts/53_strict_train_period_threshold.R","firm_tender_map;cobidders","firm/item","AUC","RUN: binary>cont flip"),
 o("APP_LEAVE_LARGEST_CASE_OUT","Leave-largest-case-out","table","App D",
   "output/loco/","outputs/tables/appendix/tab_loco.tex",
   "NEW scripts/80_leave_one_case_out.R","case_cobidder_map","case","AUC","BLOCKED: needs script 80 (linkage ready)"),
 o("APP_PRICE_SCOPE","Price scope","table","App E",
   "output/selection_mechanism/","outputs/tables/appendix/tab_price_scope.tex",
   "scripts/59_sign_reversal_decomp.R;scripts/78_bidder_count_decomposition.R","p3_prepared","item/segment",
   "coef","78 RUN: theater NOT identified (l_gen=-0.137, l_fl ns)"),
 o("APP_SURVIVAL_HAZARD","Survival/hazard","table","App B",
   "output/survival/","outputs/tables/appendix/tab_survival.tex",
   "NEW scripts/81_survival_hazard.R","firm-year","firm-year","hazard","BLOCKED: exit censored at 2019"),
 o("APP_BID_FEATURE_MISSINGNESS","Bid-feature missingness","table","App G",
   "output/imhof_incremental/","outputs/tables/appendix/tab_bid_missingness.tex",
   "scripts/49_imhof_incremental_value.R","bid_level","bid","missingness","new missingness table"),
 o("APP_GATEKEEPING_PARAMETERS","Gatekeeping parameters","table","App G",
   "output/architecture_gatekeeper/precision_at_k.csv","outputs/tables/appendix/tab_gatekeeping_params.tex",
   "scripts/63_architecture_gatekeeper.R","bid_level;cobidders","firm","K1;K2;cost","seed 20260502"),
 o("FIG_OBSERVED_EXPECTED_CONTACT","Observed vs expected contact by bin","figure","sec04",
   "outputs/figures/main/fig_obs_vs_expected_bin.pdf","outputs/figures/main/fig_obs_vs_expected_bin.pdf",
   "NEW (from script 76 firm_panel)","exposure_adjusted_audit/firm_panel.csv","firm","obs/exp","to build"),
 o("FIG_PR_LIFT_CURVES","PR / lift curves","figure","sec06",
   "output/figures/fig_pr_curve.pdf","outputs/figures/main/fig_pr_lift.pdf",
   "scripts/42_operational_metrics.R","cobidders;firm_loss_stats","firm","PR;lift","replace ROC headline"),
 o("FIG_ROLLING_ORIGIN_VALIDATION","Rolling-origin validation","figure","sec04",
   "submission_clean/output/figures/fig_temporal_holdout_roc.pdf","outputs/figures/main/fig_rolling_origin.pdf",
   "scripts/17_temporal_holdout_roc.R;make_submission_figures.R","firm_tender_map;cobidders","firm","ROC",
   "EXISTING (values hardcoded in make script)"),
 o("FIG_CASE_HOLDOUT_DISTRIBUTION","Leave-one-case-out distribution","figure","sec04",
   "outputs/figures/main/fig_loco_dist.pdf","outputs/figures/main/fig_loco_dist.pdf",
   "NEW scripts/80_leave_one_case_out.R","case_cobidder_map","case","AUC dist","BLOCKED: needs 80"),
 o("FIG_COST_RECALL_FRONTIER","Cost-recall frontier","figure","sec06",
   "output/figures/fig_regulatory_frontier.pdf","outputs/figures/main/fig_cost_recall_frontier.pdf",
   "scripts/56_regulatory_cost_frontier.R","bid_level;cobidders","cell","recall/cost","MISSING: 56 not run"),
 o("FIG_COBIDDER_PREVALENCE_BINS","Cobidder prevalence by participation bin","figure","App C/D",
   "output/figures/fig_threshold_heatmap_2d.pdf","outputs/figures/appendix/fig_cobidder_prevalence.pdf",
   "scripts/18_threshold_heatmap_2d.R","firm_tender_map","firm","prevalence","reuse/extend"),
 o("FIG_SURVIVAL_KM","Survival / Kaplan-Meier","figure","App B",
   "outputs/figures/appendix/fig_survival_km.pdf","outputs/figures/appendix/fig_survival_km.pdf",
   "NEW scripts/81_survival_hazard.R","firm-year","firm-year","KM","BLOCKED: censored"),
 o("FIG_PRICE_SCOPE_SEGMENTS","Price scope segments","figure","App E",
   "output/figures/fig_segment_betas.pdf","outputs/figures/appendix/fig_price_scope_segments.pdf",
   "scripts/61_sign_reversal_segment_decomp.R","p3_prepared;cobidders","segment","coef","EXISTING"))

utils::write.csv(outreg, file.path(OUTd, "output_registry.csv"), row.names = FALSE)

# ---- DATASET REGISTRY -------------------------------------------------------
# row/col counts: lightweight for CSVs; large parquets -> not_checked_large_file
d <- function(id,name,relpath,fmt,lvl,keys,drange,reqfor,src,rows,cols,notes) {
  p <- file.path(PAPER, relpath); st <- if (file.exists(p)) "confirmed" else "missing_or_external"
  data.frame(dataset_id=id, dataset_name=name, path=relpath, format=fmt, level=lvl,
    key_identifiers=keys, date_range=drange, required_for=reqfor, source_script=src,
    row_count_if_lightweight=rows, column_count_if_lightweight=cols,
    status=st, notes=notes, stringsAsFactors=FALSE) }

dsreg <- rbind(
 d("BEC_ALL_FIRMS","All BEC firms (firm registry)","data/processed/Firms_final.parquet","parquet","firm",
   "CNPJ","2009-2019","characterization","00_build_bidlevel.py","39600","~12","not_checked_large_file ok (small)"),
 d("ALWAYS_LOSERS","Always-loser firm-level","data/processed/FREQ_PARTICIP_rebuilt.parquet","parquet","firm",
   "códigofornecedor","2009-2019","label funnel;FL14","00_build_bidlevel.py","16843","3","RUN-confirmed count"),
 d("FIRM_LOSS_STATS","Per-firm win/loss stats","data/processed/firm_loss_stats.parquet","parquet","firm",
   "códigofornecedor","2009-2019","always_loser;win_rate","00_build_bidlevel.py","41444","6","-1 sentinel present"),
 d("AWARD_ITEM_PANEL","Tender-item award layer","data/processed/item_value_panel.parquet","parquet","tender-item",
   "numerodaoc;codigoitem","2009-2019","RDD;exposure cells","12_build_item_value.R","3990000","~10","not_checked_large_file"),
 d("FIRM_ITEM_MAP","Firm-item participation","data/processed/firm_tender_map.parquet","parquet","firm-item",
   "códigofornecedor;numerodaoc;códigoitem","2009-2019","cobidder graph;exposure","00_build_bidlevel.py","16866542","5","co-bid join key"),
 d("CADE_DEFENDANTS","CADE direct defendants x BEC","data/processed/cade_bec_crossmatch.csv","csv","defendant-case",
   "firm_cnpj;processo","conduct pre-2019","label funnel;LOCO","STATIC (no builder)","49","14","8 procs incl IT_DF junk"),
 d("CADE_CASES","CADE case metadata","data/processed/cade_carteis_licitacoes_2009_2019.csv","csv","case",
   "numero_processo","julg 2015-2025","case timing;LOCO","STATIC","65","10","12 procs; data_julgamento 9/12"),
 d("COBIDDER_LABELS","Cobidder labels (primary target)","data/processed/cade_fl_cobidders.csv","csv","firm",
   "códigofornecedor","2009-2019","validation target","STATIC (NO builder; B3)","193","12","all is_FL&always_loser; builder absent"),
 d("BID_LEVEL_LANCES","Bid-layer LANCES","data/processed/bid_level_full_v14.parquet","parquet","bid",
   "numerodaoc;códigoitem;fornecedor","2009-2019","bid benchmark;cost denom","00_build_bidlevel.py","39960000","84","not_checked_large_file (1.45GB)"),
 d("BID_FEATURE_FIRM","Bid-feature firm-level (Imhof)","output/imhof_incremental/","dir","firm/bid",
   "firm","2009-2019","bid benchmark","49_imhof_incremental_value.R","NA","NA","derived; check contents"),
 d("PRICE_ANALYSIS","Price analysis frame","/tmp/p3_prepared.rds","rds","tender-item",
   "item_f;year_f","2009-2019","price scope;decomp","01_clean.R","1673837","many","cache; rebuild via 01_clean"),
 d("FIRM_YEAR_PANEL","Firm-year panel (timing/survival)","output/reverse_causality_timing/firm_year_panel.csv","csv","firm-year",
   "firm;year","2009-2019","timing;survival","77_reverse_causality_timing.R","NA","NA","RUN; reuse for survival 81"),
 d("CASE_COBIDDER_MAP","Cobidder x case linkage","output/label_funnel/case_cobidder_map.csv","csv","firm-case",
   "cnpj;proc","julg dates","leave-one-case-out","79_label_funnel.R","5121","5","NEW; unblocks LOCO"))

utils::write.csv(dsreg, file.path(OUTd, "dataset_registry.csv"), row.names = FALSE)

cat(sprintf("make_registries: output_registry.csv (%d rows), dataset_registry.csv (%d rows) -> %s\n",
            nrow(outreg), nrow(dsreg), OUTd))
cat("  output statuses: ", paste(names(table(outreg$status)), table(outreg$status), sep="=", collapse="  "), "\n")
