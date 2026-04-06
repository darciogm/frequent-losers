**********************************************************************************
******************************** 02_analysis.do **********************************
**********************************************************************************

**********************************************************************************

* This do file does the main analysis and plots of the study

* 1. Incumbency
* 2. Backlog 30 days
* 3. Backlog 90 days
* 4. Backlog 120 days

**********************************************************************************

set processor 12
set maxvar 10000

*** 0. Import data
use "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_final.dta", clear

**********************************************************************************

*** 2. Backlog 30 days

keep if descriçãoprocedimentocompra=="CONVITE"

/* RD regression
eststo reg_rd2: rdrobust cumprof_won_30_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10,  covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_main.xls", excel tex(frag) bdec(4) label ctitle(Backlog 90 days)
*/

* Calculate percentiles
centile cumprof_won_30_std, centile(0.001 99.999)

* Remove outliers below the 1st percentile and above the 99th percentile
keep if cumprof_won_30_std >= r(c_1) & cumprof_won_30_std <= r(c_2)

* RD plot of backlog 90 days
rdplot cumprof_won_30_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10, vce(nncluster auction_num) graph_options(legend(off) xtitle(Deviation in bids) ytitle(30-Day Standardized Backlog) graphregion(color(white)) ylabel(-1.5(0.5)2.5, angle(0)))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_backlog_30_days.pdf", replace
