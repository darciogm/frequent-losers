**********************************************************************************
******************************** 02_analysis.do **********************************
**********************************************************************************

**********************************************************************************

* This do file does the main analysis and plots of the study

* 1. Preprocess Anaylsis
* 2. Incumbency
* 3. Backlog

**********************************************************************************

set processor 24

*** 0. Import data
use "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_final.dta", clear


**********************************************************************************


sort auction_num datetimevar

*** 1. Incumbency

* Distribution of the running varibale 
hist prop_delta_bid

* RD regressioon
eststo reg_rd1: rdrobust won_t_minus_1 prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE", covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_main.xls", replace excel tex(frag) bdec(4) label ctitle(Incumbency)

* RD plot of the incumbecy variable
rdplot won_t_minus_1 prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE" , graph_options(legend(off))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_incumbency.png", replace

**********************************************************************************


*** 2. Backlog 30 days

* RD regression
eststo reg_rd2: rdrobust cumprof_won_30_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE",  covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_main.xls", excel tex(frag) bdec(4) label ctitle(Backlog 90 days)

* RD plot of backlog 90 days
rdplot cumprof_won_30_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE",  covs(gr*) graph_options(legend(off))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_backlog_30_days.png", replace


**********************************************************************************


*** 3. Backlog 90 days

* RD regression
eststo reg_rd2: rdrobust cumprof_won_90_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE", covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_main.xls", excel tex(frag) bdec(4) label ctitle(Backlog 30 days)

* RD plot of backlog 90 days
rdplot cumprof_won_90_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE",  covs(gr*) graph_options(legend(off))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_backlog_90_days.png", replace


**********************************************************************************


*** 3. Backlog 120 days

* RD regression
eststo reg_rd2: rdrobust cumprof_won_120_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE",  covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_main.xls", excel tex(frag) bdec(4) label ctitle(Backlog 120 days)

* RD plot of backlog 90 days
rdplot cumprof_won_120_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10 & descriçãoprocedimentocompra=="CONVITE",  covs(gr*) graph_options(legend(off))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_backlog_120_days.png", replace




