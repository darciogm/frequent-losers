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


sort auction_num datetimevar

*** 1. Incumbency

* Distribution of the running varibale 
*hist prop_delta_bid

keep if descriçãoprocedimentocompra=="CONVITE"

* Generate a random number between 0 and 1 for each observation
gen rand = runiform()

* Sort the data by the random number (optional, but useful for random order)
sort rand

* Keep half the dataset
keep if _n <= _N/2

* Drop the random number variable (optional)
drop rand

/* RD regressioon
eststo reg_rd1: rdrobust won_t_minus_1 prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10, covs(gr*) vce(nncluster auction_num)
outreg2 using "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/tables/rd_regression_half.xls", replace excel tex(frag) bdec(4) label ctitle(Incumbency)
*/

* RD plot of the incumbecy variable
rdplot won_t_minus_1 prop_delta_bid if inrange(prop_delta_bid, -0.5, 0.5) & cumsum_part>10, graph_options(legend(off) ms(oh) msize(vsmall))

* Save Plot
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/rd_plot_incumbency_half.pdf", replace
