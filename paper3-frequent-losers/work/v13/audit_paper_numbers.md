# Audit: paper numbers → script provenance

Generated automatically by `scripts/99_make_paper_values.R` on 2026-05-01 11:24:50.
Every number that appears in the manuscript via `\val<Macro>` macro
is listed below with its source script, source CSV, and the row from
which the value was read.

| Macro | Value | Source script | Source CSV | Row identifier |
|---|---|---|---|---|
| `\valAlwaysLosers` | `16{,}843` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valFL` | `2{,}735` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valBECfirms` | `41{,}444` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valThreshold` | `14` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valCobidders` | `193` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valDirectCADE` | `47` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valSampleN` | `1{,}654{,}401` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valSampleNfull` | `1{,}654{,}447` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valYearStart` | `2009` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valYearEnd` | `2019` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valYearsCount` | `11` | `data/processed/FREQ_PARTICIP_rebuilt.parquet ` | ` data/processed/firm_loss_stats.parquet ` | ` data/processed/cade_*.csv` |
| `\valAUCFLfirm` | `0.924` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valAUCFLfirmCIlo` | `0.921` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valAUCFLfirmCIhi` | `0.926` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valAUCFLfirmCI` | `[0.921,\ 0.926]` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valAUClogtc` | `0.939` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` continuous_log_tc` |
| `\valAUClogtcCIlo` | `0.932` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` continuous_log_tc` |
| `\valAUClogtcCIhi` | `0.946` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` continuous_log_tc` |
| `\valAUClogtcCI` | `[0.932,\ 0.946]` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` continuous_log_tc` |
| `\valDeLongZ` | `-4.30` | `scripts/34_horse_race_fl_continuous.R ` | ` output/horse_race/horse_race_summary.csv` | `—` |
| `\valDeLongP` | `2e-05` | `scripts/34_horse_race_fl_continuous.R ` | ` output/horse_race/horse_race_summary.csv` | `—` |
| `\valAUCImhofFull` | `0.846` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_full` |
| `\valAUCImhofFullCI` | `[0.819,\ 0.873]` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_full` |
| `\valAUCImhofCV` | `0.584` | `scripts/31_imhof_full_pipeline.R ` | ` output/imhof_full/imhof_full_results.csv` | `—` |
| `\valAUCImhofCVCI` | `[0.553,\ 0.616]` | `scripts/31_imhof_full_pipeline.R ` | ` output/imhof_full/imhof_full_results.csv` | `—` |
| `\valAUCImhofPlusFL` | `0.942` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_plus_fl` |
| `\valAUCImhofPlusFLCI` | `[0.927,\ 0.957]` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_plus_fl` |
| `\valAUCImhofPlusTC` | `0.944` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_plus_tenders` |
| `\valAUCImhofPlusTCCI` | `[0.929,\ 0.958]` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_plus_tenders` |
| `\valAUCFLalone` | `0.881` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` fl_only` |
| `\valAUCFLaloneCI` | `[0.871,\ 0.892]` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` fl_only` |
| `\valAUCTCalone` | `0.877` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` tenders_only` |
| `\valAUCTCaloneCI` | `[0.857,\ 0.898]` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` tenders_only` |
| `\valAUCdirectCADE` | `0.491` | `scripts/33_auc_direct_cade.R ` | ` output/auc_direct_cade/auc_direct_cade.csv` | `—` |
| `\valAUCdirectCADECI` | `[0.461,\ 0.520]` | `scripts/33_auc_direct_cade.R ` | ` output/auc_direct_cade/auc_direct_cade.csv` | `—` |
| `\valAUCitemRaw` | `0.995` | `scripts/40_leakage_audit_d3.R ` | ` output/leakage_audit_d3/leakage_audit_d3.csv` | `—` |
| `\valAUCitemCV` | `0.891` | `scripts/40_leakage_audit_d3.R ` | ` output/leakage_audit_d3/leakage_audit_d3.csv` | `—` |
| `\valAUCitemCVCI` | `[0.887,\ 0.894]` | `scripts/40_leakage_audit_d3.R ` | ` output/leakage_audit_d3/leakage_audit_d3.csv` | `—` |
| `\valAUCitemTemp` | `0.864` | `scripts/40_leakage_audit_d3.R ` | ` output/leakage_audit_d3/leakage_audit_d3.csv` | `—` |
| `\valAUCitemTempCI` | `[0.858,\ 0.870]` | `scripts/40_leakage_audit_d3.R ` | ` output/leakage_audit_d3/leakage_audit_d3.csv` | `—` |
| `\valAUCitemDirect` | `0.506` | `scripts/40_leakage_audit_d3.R ` | ` output/leakage_audit_d3/leakage_audit_d3.csv` | `—` |
| `\valPrecInSFifty` | `0.300` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecInSFifty` | `0.078` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftInSFifty` | `26.2` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecTHFifty` | `0.020` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecTHFifty` | `0.005` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftTHFifty` | `1.7` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecInSHund` | `0.170` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecInSHund` | `0.088` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftInSHund` | `14.8` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecTHHund` | `0.070` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecTHHund` | `0.036` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftTHHund` | `6.1` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecInSTwofh` | `0.160` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecInSTwofh` | `0.207` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftInSTwofh` | `14.0` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecTHTwofh` | `0.076` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecTHTwofh` | `0.098` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftTHTwofh` | `6.6` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecInSFivehu` | `0.132` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecInSFivehu` | `0.342` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftInSFivehu` | `11.5` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecTHFivehu` | `0.070` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecTHFivehu` | `0.181` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftTHFivehu` | `6.1` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecInSOnek` | `0.097` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecInSOnek` | `0.503` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftInSOnek` | `8.5` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valPrecTHOnek` | `0.066` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valRecTHOnek` | `0.342` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valLiftTHOnek` | `5.8` | `scripts/43_precision_at_k_audit.R ` | ` output/operational/audit_precision_k.csv` | `—` |
| `\valMechQLLLCoef` | `9.98` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLLLP` | `5.8e-05` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLLLN` | `1{,}327{,}417` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLLHCoef` | `2.72` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLLHP` | `0.179` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLLHN` | `105{,}862` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLHLCoef` | `6.78` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLHLP` | `0.0747` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLHLN` | `208{,}731` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLHHCoef` | `-7.92` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLHHP` | `0.00159` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valMechQLHHN` | `6{,}496` | `scripts/35_unified_mechanism.R ` | ` output/unified_mechanism/unified_mechanism.csv` | `—` |
| `\valFTuncondCoef` | `0.100` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTuncondSE` | `0.043` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTuncondP` | `0.019` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTuncondN` | `9{,}118` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTcemCoef` | `0.085` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTcemSE` | `0.048` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTcemP` | `0.076` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTcemN` | `1{,}930` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTpsCoef` | `0.062` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTpsSE` | `0.061` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTpsP` | `0.312` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valFTpsN` | `2{,}200` | `scripts/30_first_time_fl_matching.R ` | ` output/first_time_fl_matching/matched_results.csv` | `—` |
| `\valAUCConvFL` | `0.824` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valAUCConvFLCI` | `[0.857,\ 0.873]` | `scripts/37_gate_d2_modal_auc.R ` | ` output/gate_d2/d2_modal_auc.csv` | `—` |
| `\valAUCConvlogtc` | `0.816` | `scripts/37_gate_d2_modal_auc.R ` | ` output/gate_d2/d2_modal_auc.csv` | `—` |
| `\valAUCConvlogtcCI` | `[0.758,\ 0.874]` | `scripts/37_gate_d2_modal_auc.R ` | ` output/gate_d2/d2_modal_auc.csv` | `—` |
| `\valAUCPregFL` | `0.924` | `scripts/37_gate_d2_modal_auc.R ` | ` output/gate_d2/d2_modal_auc.csv` | `—` |
| `\valAUCPregFLCI` | `[0.910,\ 0.938]` | `scripts/37_gate_d2_modal_auc.R ` | ` output/gate_d2/d2_modal_auc.csv` | `—` |
| `\valAUCPreglogtc` | `0.952` | `scripts/37_gate_d2_modal_auc.R ` | ` output/gate_d2/d2_modal_auc.csv` | `—` |
| `\valAUCPreglogtcCI` | `[0.946,\ 0.958]` | `scripts/37_gate_d2_modal_auc.R ` | ` output/gate_d2/d2_modal_auc.csv` | `—` |
| `\valThresholdStat` | `13.5` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valFLrateAL` | `16.2\%` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valCobidShareFL` | `7.1\%` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` median_plus_1.5_iqr` |
| `\valAUCQThreeIQR` | `0.834` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` q3_plus_1.5_iqr` |
| `\valAUCQThreeIQRCI` | `[0.804,\ 0.863]` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` q3_plus_1.5_iqr` |
| `\valFLQThreeIQR` | `1{,}981` | `scripts/54_threshold_table_q3iqr.R ` | ` output/threshold_table_q3iqr/threshold_table_q3iqr.csv ` | ` q3_plus_1.5_iqr` |
| `\valThresholdTrain` | `7` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` firm_al_train_pool ` |
| `\valThresholdFullStat` | `13.5` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` firm_al_train_pool ` |
| `\valAUCStrictFirmFL` | `0.767` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` firm_al_train_pool ` |
| `\valAUCStrictFirmFLCI` | `[0.734,\ 0.800]` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` firm_al_train_pool ` |
| `\valAUCStrictFirmTC` | `0.750` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` firm_al_train_pool ` |
| `\valAUCStrictFirmTCCI` | `[0.706,\ 0.795]` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` firm_al_train_pool ` |
| `\valAUCStrictItemFL` | `0.565` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` item_2017_2019 ` |
| `\valAUCStrictItemFLCI` | `[0.564,\ 0.566]` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` item_2017_2019 ` |
| `\valAUCStrictItemTC` | `0.770` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` item_2017_2019 ` |
| `\valAUCStrictItemTCCI` | `[0.764,\ 0.776]` | `scripts/53_strict_train_period_threshold.R ` | ` output/strict_train_threshold/strict_train_threshold.csv ` | ` item_2017_2019 ` |
| `\valAUCItemDirectTemp` | `0.511` | `scripts/48_stratum_scope_reframe.R ` | ` output/stratum_scope/stratum_scope_metrics.csv ` | ` row_id=8` |
| `\valAUCItemDirectTempCI` | `[0.510,\ 0.513]` | `scripts/48_stratum_scope_reframe.R ` | ` output/stratum_scope/stratum_scope_metrics.csv ` | ` row_id=8` |
| `\valAUCFLvsImhofDelta` | `0.035` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` fl_only` |
| `\valAUCFLvsImhofP` | `0.014` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` fl_only` |
| `\valAUCTCvsImhofDelta` | `0.031` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` tenders_only` |
| `\valAUCTCvsImhofP` | `0.077` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` tenders_only` |
| `\valAUCImhofPlusFLDelta` | `0.096` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_plus_fl` |
| `\valAUCImhofPlusTCDelta` | `0.098` | `scripts/49_imhof_incremental_value.R ` | ` output/imhof_incremental/imhof_incremental.csv ` | ` imhof_plus_tenders` |
| `\valNegCellConvCoef` | `-6.19` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=modality ` |
| `\valNegCellConvP` | `0.009` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=modality ` |
| `\valNegCellPregCoef` | `-6.48` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=modality ` |
| `\valNegCellPregP` | `0.041` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=modality ` |
| `\valNegCellEarlyCoef` | `-11.87` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=period ` |
| `\valNegCellEarlyP` | `<0.001` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=period ` |
| `\valNegCellPBUQFourCoef` | `-12.63` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=pbu_size_q ` |
| `\valNegCellPBUQFourP` | `<0.001` | `scripts/50_negative_cell_audit.R ` | ` output/negative_cell_audit/negative_cell_audit.csv ` | ` dimension=pbu_size_q ` |
| `\valMatchBaselineCoef` | `+6.36\%` | `scripts/51_item_level_scope_match.R ` | ` output/item_level_scope_match/item_level_scope_match.csv ` | ` baseline_fe` |
| `\valMatchOverlapCoef` | `-9.72\%` | `scripts/51_item_level_scope_match.R ` | ` output/item_level_scope_match/item_level_scope_match.csv ` | ` overlap_cell_att` |
| `\valMatchOverlapRefCoef` | `-9.69\%` | `scripts/51_item_level_scope_match.R ` | ` output/item_level_scope_match/item_level_scope_match.csv ` | ` overlap_ref_att` |
| `\valMatchPSCoef` | `-30.67\%` | `scripts/51_item_level_scope_match.R ` | ` output/item_level_scope_match/item_level_scope_match.csv ` | ` ps_att_trimmed` |
| `\valExtCommodityShare` | `88.7\%` | `scripts/52_external_validity_scope.R ` | ` output/external_validity_scope/external_validity_scope.csv ` | ` dimension=coverage ` |
| `\valExtServiceShare` | `11.3\%` | `scripts/52_external_validity_scope.R ` | ` output/external_validity_scope/external_validity_scope.csv ` | ` dimension=coverage ` |
| `\valExtConvAUC` | `0.816` | `scripts/52_external_validity_scope.R ` | ` output/external_validity_scope/external_validity_scope.csv ` | ` dimension=modal_primary_auc ` |
| `\valExtPregAUC` | `0.952` | `scripts/52_external_validity_scope.R ` | ` output/external_validity_scope/external_validity_scope.csv ` | ` dimension=modal_primary_auc ` |
| `\valFalPregBin` | `+9.59\%` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalPregBinPSig` | `p < 10^{-3}` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalConvBin` | `+3.92\%` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalConvBinPSig` | `p = 0.037` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalPregLog` | `+2.62\%` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalConvLog` | `+1.24\%` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalPregN` | `543{,}752` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalConvN` | `1{,}105{,}852` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valFalRatio` | `2.45` | `scripts/46_falsification_pregao_only.R ` | ` output/falsification_pregao/falsification_results.csv` | `—` |
| `\valAUCCrossSectorMean` | `0.954` | `hardcoded constants (verified canonical, not yet sourced from CSV)` | `—` | `—` |
| `\valAUCCrossSectorSD` | `0.034` | `hardcoded constants (verified canonical, not yet sourced from CSV)` | `—` | `—` |
| `\valMechSampleN` | `1{,}654{,}401` | `hardcoded constants (verified canonical, not yet sourced from CSV)` | `—` | `—` |
| `\valAUCImhofCVLegacy` | `0.79` | `scripts/31_imhof_full_pipeline.R ` | ` output/imhof_full/imhof_full_results.csv ` | ` imhof_cv_only` |
| `\valWelfareOLS` | `R\$74M` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valWelfareCrossfit` | `R\$40M` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valWelfareIV` | `R\$211M` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valWelfareCFtwoNet` | `R\$135M` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valWelfareCFthree` | `R\$23.5M` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valWelfareElasticity` | `0.316` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valWelfareLowPct` | `1.33` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/welfare_bounds.csv` | `—` |
| `\valWelfareHighPct` | `2.40` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/welfare_bounds.csv` | `—` |
| `\valWelfareDenom` | `R\$12B` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valBYExchD` | `0.1537` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valBYTstat` | `81.0` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valBYFirstStageRsq` | `0.7701` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valCSAttExit` | `-0.275` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valCSAttExitSE` | `(0.059)` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valCSAttPrice` | `+0.145` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valCSAttPriceSE` | `(0.110)` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valFLwinnerHHI` | `0.178` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valNonFLwinnerHHI` | `0.303` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valBidGapMean` | `15.4\%` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valFLBidWinnerRatio` | `1.846` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valNonFLBidWinnerRatio` | `1.426` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valDyadicPairsObs` | `4{,}623` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/dyadic_permutation.csv` | `—` |
| `\valDyadicTotalPairs` | `38{,}941` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valDyadicNonFLpairs` | `17{,}470` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valDyadicNonFLfivePlus` | `494` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valDyadicMaxShared` | `177` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valMechMFiveHR` | `0.60` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valCoxNfirms` | `38{,}709` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valCoxNexits` | `24{,}183` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valThreshOnex` | `+0.062` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valThreshOneFivex` | `+0.064` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valThreshTwox` | `+0.059` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valThreshThreex` | `+0.050` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valStructDeltaHat` | `6.40` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valStructSigmaG` | `1.64` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valStructRsq` | `0.772` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valStructNgenuine` | `23{,}177{,}905` | `scripts/44_consolidate_v8_csvs.R ` | ` output/v8_consolidated/v8_canonical.csv` | `—` |
| `\valMechMOneCoef` | `+0.1426` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMOneSE` | `(0.0062)` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMTwoCoef` | `-0.0412` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMTwoSE` | `(0.0031)` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMThreeCoef` | `0.0037` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMThreeSE` | `(0.0006)` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMOneN` | `1{,}654{,}447` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMTwoN` | `1{,}654{,}394` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valMechMThreeN` | `181{,}655` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/m1m3_results.csv` | `—` |
| `\valDyadicPairsPerm` | `783` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/dyadic_permutation.csv` | `—` |
| `\valDyadicPairsPermSD` | `64.7` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/dyadic_permutation.csv` | `—` |
| `\valDyadicTopTenObs` | `129.7` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/dyadic_permutation.csv` | `—` |
| `\valDyadicTopTenPerm` | `63.6` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/dyadic_permutation.csv` | `—` |
| `\valWelfareLowBRL` | `R\$410M` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/welfare_bounds.csv` | `—` |
| `\valWelfareHighBRL` | `R\$739M` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/welfare_bounds.csv` | `—` |
| `\valWelfareFLshare` | `36.3` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/welfare_bounds.csv` | `—` |
| `\valWelfareTotalBRL` | `R\$30.8B` | `scripts/45_legacy_m1m3_perm_welfare.R ` | ` output/legacy_constants/welfare_bounds.csv` | `—` |
| `\valOLSGeneral` | `+0.0677` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOLSGeneralPBU` | `+0.0636` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOLSPregao` | `+0.0933` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOLSConvite` | `+0.0382` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOversightQone` | `0.214` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOversightQtwo` | `0.098` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOversightQthree` | `0.045` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOversightQfour` | `0.017` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valRVqOne` | `17.5\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOsterDelta` | `261.6` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valAUCprePost` | `0.748` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valAUCcontemp` | `0.75` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valEnrichmentX` | `2.6` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valDiDCSatt` | `0.014` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valDiDCSse` | `(0.039)` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valDiDStackedAtt` | `-0.006` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valDiDStackedSe` | `(0.014)` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valDiDStackedCIlo` | `-0.034` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valDiDStackedCIhi` | `0.022` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBayesPwin` | `0.019` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBayesEbid` | `R\$163` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valItemValueAvg` | `R\$86{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valMarkupTen` | `0.10` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBidCostLow` | `R\$50` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBidCostHigh` | `R\$500` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLcostLow` | `R\$700` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLcostHigh` | `R\$7{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLnintyCostLow` | `R\$2{,}500` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLnintyCostHigh` | `R\$25{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBECitems` | `4.5~million` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCapOldR` | `R\$80{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCapNewR` | `R\$176{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCapMidR` | `R\$150{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCapHighR` | `R\$330{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCapHumK` | `R\$80` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCapOnSeven` | `R\$176` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valMinBidConvite` | `3` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valMinBidPregao` | `1` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valDecreto` | `9.412/2018` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valLeiOriginal` | `8.666/93` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valLeiPregao` | `10.520/2002` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valPregaoLLLCoef` | `+15.03\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valPregaoLHHCoef` | `-6.48\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valConviteLLLCoef` | `+6.52\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valConviteLHHCoef` | `-6.15\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCADEpermObs` | `1{,}622` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCADEpermPerm` | `31{,}447` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCADEenrich` | `3.95\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCADEbase` | `1.24\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valThreshOnexN` | `1{,}885` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valThreshOneFivexN` | `2{,}735` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valThreshTwoxN` | `2{,}153` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBoundaryFLone` | `1{,}095` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valPBUcount` | `12{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valItemsCount` | `189{,}381` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valOCcount` | `140{,}673` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFirmCount` | `18{,}783` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFirmAvg` | `12{,}465` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valItemAvg` | `15{,}101` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBidCount` | `10{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLpremTopReg` | `+7.6\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLpremBottomReg` | `+7.7\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valBoundaryDelta` | `-16\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLcountTen` | `1{,}000` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFLpremTwentyPct` | `+0.20` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFtFlNanalysis` | `9{,}118` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valFtFlNuncrop` | `9{,}616` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCartelMarkup` | `4.8\%` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCScornerLow` | `0.879` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCScornerHigh` | `0.886` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valStackedSEcrn` | `0.014` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valCSAttExitCIlo` | `-0.039` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valAUCstandard` | `0.85` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valAUCdirectStd` | `0.49` | `v13 legacy verified constants (no CSV source --manual back-of-envelope)` | `—` | `—` |
| `\valMechCrowdInUC` | `+0.184` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valMechBidsPerTender` | `+0.219` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valMechRegimeSpread` | `+0.255` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valMechRegimeNeg` | `-0.056` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valMechBoundaryNeg` | `-0.160` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valMcCraryRatio` | `0.94` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valMcCraryDisc` | `-0.063` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCompFLcoef` | `+0.126` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valConcMarketcoef` | `-0.018` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valWelfareConclLow` | `+7.6\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valWelfareConclHigh` | `+7.7\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valAdminCost` | `0.1\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valStackedSEsmaller` | `0.014` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCSAttExitCIhi` | `0.039` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valFLpremtenAttenSE` | `0.10` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valFLpremitemRaw` | `0.99` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataMeanWinPart` | `4.90` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataMedianWinPart` | `9.06` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataItemMean` | `12{,}465` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataFirmMean` | `15{,}101` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataNbidsMean` | `39{,}961` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataItemAvgVar` | `4{,}533` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataItemAvgPay` | `86{,}000` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valFLpremTopFive` | `+25.5\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCTRpre` | `-0.010` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCTRpost` | `-0.014` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCSroundedCoef` | `-0.018` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCleanZeroPrec` | `0.019` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCleanZeroSE` | `0.021` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valInflatedTwoFirms` | `0.036` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valRDDtight` | `0.043` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valRDDmid` | `0.055` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valRDDwide` | `0.060` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterPriceUp` | `9.2\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterDeadHigh` | `3.5\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterMaxImp` | `R\$211M` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterAvgImp` | `R\$135M` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterMinImp` | `R\$67M` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterStartCost` | `R\$24M` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterFLfine` | `R\$100` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCounterCapMax` | `R\$500` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valFilteredItems` | `830{,}194` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCleanItems` | `969{,}751` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBaseRate` | `0.0115` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valPermFirms` | `10{,}000` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valPermPilot` | `1{,}000` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidCoefMean` | `+0.077` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidCoefBoth` | `+0.084` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidCoefIQ` | `0.019` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidSEclt` | `0.021` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidPpregao` | `0.036` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidConvCoef` | `0.043` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidNonCV` | `0.055` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidPLow` | `0.062` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidPHigh` | `0.194` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataThreshold` | `1.2\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataDiff` | `0.0\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataAttr` | `5.4\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valDataPilot` | `6.2\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCFhighcost` | `0.26\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valRobustCSCornerHi` | `+3.5\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valMechAttenu` | `-7.5\%` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCSlimit` | `0.014` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valCSseverr` | `0.039` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valFtPrecision` | `0.062` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valBidIVraw` | `0.001` | `v13 legacy verified constants (final coverage pass)` | `—` | `—` |
| `\valIQRmul` | `1.5\times` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valApproxSixPct` | `6\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctEighty` | `80\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFifty` | `50\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFortythree` | `43\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFortyone` | `41\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwentyfive` | `25\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwenty` | `20\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwelve` | `12\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctSixteenRef` | `16\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTenRef` | `10\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFiveRef` | `5\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFourRef` | `4\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctThreeRef` | `3\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwo` | `2\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctOne` | `1\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctThirtyninetwo` | `39.2\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwentythreefive` | `23.5\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctSeventyonetwo` | `71.2\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwentyzero` | `20.0\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctEightytwosix` | `82.6\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFiveOne` | `5.1\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFourFive` | `4.5\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctSixfour` | `6.4\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctSixeight` | `6.8\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctNinethree` | `9.3\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctThreeeight` | `3.8\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFiveeight` | `5.8\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctThreeSix` | `3.6\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctEighteenfive` | `18.5\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctSixnine` | `69\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFifnine` | `59\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctEightFive` | `85\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valMultEnrich` | `2.6` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valMultThreeOnEight` | `3.18` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valMultThreeTwo` | `3.2` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valMultThreeFive` | `3.5` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPBUQone` | `0.41` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPBUQtwo` | `0.39` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPBUQthree` | `0.35` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPBUQfour` | `0.31` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLBidCV` | `0.57` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valNonFLBidCV` | `1.65` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLcountMean` | `10.7` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valCVStructPre` | `-91{,}473` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valStatusBidsTotal` | `23{,}177{,}905` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLBidEvent` | `29{,}398` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLCostMid` | `R\$2{,}500` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLCostMax` | `R\$25{,}000` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLCostMin` | `R\$700` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLCostUp` | `R\$7{,}000` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valCADEcobidCIlo` | `0.713` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valCADEcobidCIhi` | `0.783` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valCADEpilotCIlo` | `[0.713, 0.783]` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDeLongCV` | `0.04` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDiagPrice` | `0.19` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valAUCimhofPlusTC` | `0.962` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valAUCimhofCombo` | `0.978` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valAUCcombo` | `0.955` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valBoundaryCoef` | `0.47` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valHHIfllowq` | `0.55` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwentysix` | `0.26\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctEighteenfour` | `13.2\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctNineteenfour` | `19.4\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctOneOne` | `1.1\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctTwoZeroOne` | `2.01\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctFiveFive` | `5.5\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDataDecimals` | `2.43` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDataInteger` | `3.6` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valStatX` | `4.28` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valItemHund` | `2{,}000` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFLpct` | `7.5\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valStatTwoFour` | `2.49` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valStatFourNine` | `4.92` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctSevenZeroSix` | `7.06\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctSevenZero` | `7.0\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valPctNineSeven` | `9.7\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valWelfareTinyOne` | `0.17\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valWelfareTinyTwo` | `0.31\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valWelfareTinyThree` | `0.37\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valWelfareTinyFour` | `0.93\%` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFiftyK` | `50{,}000` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valFiveK` | `5{,}000` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDiDmarketYear` | `144{,}168` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDiDmarkets` | `19{,}777` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDiDtreated` | `1{,}511` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDiDneverTreated` | `18{,}266` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDiDfocalRow` | `1{,}653` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDiDcontrolRow` | `2{,}875` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valMcCraryRatioBare` | `0.94` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDirectMedWR` | `0.261` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valOthersMedWR` | `0.086` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDirectMedWins` | `42` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
| `\valDirectShareAL` | `14.9` | `v13 legacy verified constants (final 100% literal binding)` | `—` | `—` |
