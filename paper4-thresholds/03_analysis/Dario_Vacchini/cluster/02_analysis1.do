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


sort auction_num datetimevar

*** 1. Incumbency

* Distribution of the running varibale 
*hist prop_delta_bid

keep if descriçãoprocedimentocompra=="CONVITE"

/* RD regressioon
eststo reg_rd1: rdrobust won_t_minus_1 prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10, covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_main.xls", replace excel tex(frag) bdec(4) label ctitle(Incumbency)
*/

* RD plot of the incumbecy variable
rdplot won_t_minus_1 prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10, vce(nncluster auction_num) graph_options(legend(off) xtitle(Deviation in bids) ytitle(Incumbent) graphregion(color(white)) ylabel(, angle(0)))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_incumbency.pdf", replace
