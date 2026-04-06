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

*** 0. Import data
use "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_final.dta", clear

**********************************************************************************


*** 3. Backlog 90 days

keep if descriçãoprocedimentocompra=="CONVITE"

* Generate a random number between 0 and 1 for each observation
gen rand = runiform()

* Sort the data by the random number (optional, but useful for random order)
sort rand

* Keep half the dataset
keep if _n <= _N/2

* Drop the random number variable (optional)
drop rand

/* RD regression
eststo reg_rd2: rdrobust cumprof_won_90_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10, covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_half.xls", excel tex(frag) bdec(4) label ctitle(Backlog 30 days)
*/

* RD plot of backlog 90 days
rdplot cumprof_won_90_std prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10, graph_options(legend(off))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_backlog_90_days_half.pdf", replace
