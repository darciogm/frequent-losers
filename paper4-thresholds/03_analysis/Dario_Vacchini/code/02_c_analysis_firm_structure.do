**********************************************************************************
************************ 02_c_analysis_firm_sturcture.do *************************
**********************************************************************************

**********************************************************************************

/* The goal of this do file is to run the main regression and plots of some firm structure
variables */

* 0. Import data
* 1. Firm age
*** 1.1 Regressions
*** 1.2 RD plot for each significant market
* 2. Limited Liability
*** 2.1 Regression
*** 2.2 RD plot for each significant market

**********************************************************************************


*** 0. Import data
use "$data/final/df_convite_winner_looser.dta", clear


**********************************************************************************

sort auction_num datetimevar
drop e
drop max_e
drop max_m

**********************************************************************************
********************************** 1. Firm age ***********************************
**********************************************************************************

*** 1.1 Regressions

* RD regression
eststo reg1: reghdfe age i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)
outreg2 using $output/tables/firm_structure/rd_reg_age.xls , replace excel tex(frag) bdec(4) label ctitle(Firm age)

* RD regression market with jump in won_t_minus_1 or last
eststo reg2: reghdfe age i.flagvencedor##c.MV if MV<0.01 & MV>-0.01 & inlist(market_item, 7592, 378, 708, 3309, 1794, 4106, 3612), vce(cluster market_item) abs(year market_item)
outreg2 using $output/tables/firm_structure/rd_reg_age_inc_jump_market.xls , replace excel tex(frag) bdec(4) label ctitle(Firm age)

* RD regression item_class with jump in won_t_minus_1 or last
eststo reg2: reghdfe age i.flagvencedor##c.MV if MV<0.01 & MV>-0.01 & inlist(códigoclasse, 6565, 7920, 4695), vce(cluster códigoclasse) abs(year códigoclasse)
outreg2 using $output/tables/firm_structure/rd_reg_age_inc_jump_item_class.xls , replace excel tex(frag) bdec(4) label ctitle(Firm age)

* RD regression item_group with jump in won_t_minus_1 or last
eststo reg2: reghdfe age i.flagvencedor##c.MV if MV<0.01 & MV>-0.01 & inlist(códigogrupo, 85, 79), vce(cluster códigogrupo) abs(year códigogrupo)
outreg2 using $output/tables/firm_structure/rd_reg_age_inc_jump_item_group.xls , replace excel tex(frag) bdec(4) label ctitle(Firm age)

**********************************************************************************


*** 1.2 RD Plots

* RD plot
rdplot age MV if MV<0.10 & MV>-0.10, graph_options(title(Firm Age) ytitle(Age) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_age_overall_market.pdf", replace

* RD plot market with jump in won_t_minus_1 or last
rdplot age MV if MV<0.10 & MV>-0.10 & inlist(market_item, 7592, 378, 708, 3309, 1794, 4106, 3612), graph_options(title(Firm Age) ytitle(Age) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_age_inc_jump_market.pdf", replace

* RD plot item_class with jump in won_t_minus_1 or last
rdplot age MV if MV<0.10 & MV>-0.10 & inlist(códigoclasse, 6565, 7920, 4695), graph_options(title(Firm Age) ytitle(Age) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_age_inc_jump_item_class.pdf", replace

* RD plot item_group with jump in won_t_minus_1 or last
rdplot age MV if MV<0.10 & MV>-0.10 & inlist(códigogrupo, 85, 79), graph_options(title(Firm Age) ytitle(Age) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_age_inc_jump_item_group.pdf", replace

* RD plot for each market (significance: 0.01)
local numbers 101 185 232 270 277 378 708 1007 1079 1126 1169 1171 1219 1327 1442 1623 1697 1794 1966 2105 2174 2296 2378 2378 2470 2639 2655 2712 2951 3211 3309 3568 3612 3679 4106 4656 4775 4878 5821 6692 7592 8212 8375 8505 11673 12693
foreach num in `numbers' {
    rdplot age MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") subtitle(Significance level: 0.01) ytitle(Age (in years)) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/firm_structure/market/rd_plot_age_market_`num'.pdf", replace
    di "Processing number: `num'"
}

* RD plot for each item_class (significance: 0.01)
local numbers 4695 5935 6145 6240 6250 6565 6920 7505 7530 7920 8250 8510 8690 8905 9160 9310
foreach num in `numbers' {
    rdplot age MV if MV<0.10 & MV>-0.10 & códigoclasse==`num', graph_options(title("Item Class `num'") subtitle(Significance level: 0.01) ytitle(Age (in years)) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/firm_structure/item_class/rd_plot_age_item_class_`num'.pdf", replace
    di "Processing number: `num'"
}

* RD plot for each item_group (significance: 0.01)
local numbers 46 61 62 75 79 85 93
foreach num in `numbers' {
    rdplot age MV if MV<0.10 & MV>-0.10 & códigogrupo==`num', graph_options(title("Item Group `num'") subtitle(Significance level: 0.01) ytitle(Age (in years)) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/firm_structure/item_group/rd_plot_age_item_group_`num'.pdf", replace
    di "Processing number: `num'"
}

**********************************************************************************
***************************** 2. Limited Liability *******************************
**********************************************************************************

*** 2.1 Regressions

* RD regression
eststo reg3: reghdfe limited_firm i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)
outreg2 using $output/tables/firm_structure/rd_reg_limited_firm.xls , replace excel tex(frag) bdec(4) label ctitle(Firm Limited)

* RD regression market with jump in won_t_minus_1 or last
eststo reg4: reghdfe limited_firm i.flagvencedor##c.MV if MV<0.01 & MV>-0.01 & inlist(market_item, 378, 3844, 3597, 505, 1189), vce(cluster market_item) abs(year market_item)
outreg2 using $output/tables/firm_structure/rd_reg_limited_firm_inc_jump_market.xls , replace excel tex(frag) bdec(4) label ctitle(Firm Limited)

* RD regression item_class with jump in won_t_minus_1 or last
eststo reg4: reghdfe limited_firm i.flagvencedor##c.MV if MV<0.01 & MV>-0.01 & inlist(códigoclasse, 7920, 4695), vce(cluster códigoclasse) abs(year códigoclasse)
outreg2 using $output/tables/firm_structure/rd_reg_limited_firm_inc_jump_item_class.xls , replace excel tex(frag) bdec(4) label ctitle(Firm Limited)

* RD regression item_group with jump in won_t_minus_1 or last
eststo reg4: reghdfe limited_firm i.flagvencedor##c.MV if MV<0.01 & MV>-0.01 & inlist(códigogrupo, 85, 79), vce(cluster códigogrupo) abs(year códigogrupo)
outreg2 using $output/tables/firm_structure/rd_reg_limited_firm_inc_jump_item_group.xls , replace excel tex(frag) bdec(4) label ctitle(Firm Limited)

**********************************************************************************


*** 2.2 RD Plots

* RD plot overall market
rdplot limited_firm MV if MV<0.10 & MV>-0.10, graph_options(title(Limited Firm) ytitle(Limited Firm) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_limited_firm_overall_market.pdf", replace

* RD plot market with jump in won_t_minus_1 or last
rdplot limited_firm MV if MV<0.10 & MV>-0.10 & inlist(market_item, 378, 3844, 3597, 505, 1189), graph_options(title(Limited Firm) ytitle(Limited Frim) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_limited_firm_inc_jump_market.pdf", replace

* RD plot item_class with jump in won_t_minus_1 or last
rdplot limited_firm MV if MV<0.10 & MV>-0.10 & inlist(códigoclasse, 7920, 4695), graph_options(title(Limited Firm) ytitle(Limited Frim) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_limited_firm_inc_jump_item_class.pdf", replace

* RD plot item_group with jump in won_t_minus_1 or last
rdplot limited_firm MV if MV<0.10 & MV>-0.10 & inlist(códigogrupo, 85, 79), graph_options(title(Limited Firm) ytitle(Limited Frim) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)
graph export "$output/graphs/firm_structure/rd_plot_limited_firm_inc_jump_item_group.pdf", replace

* RD plot for each market (significance: 0.01)
local numbers 89 161 185 228 282 378 505 579 701 722 906 1007 1116 1189 1218 1312 1327 1738 1805 1966 1973 2110 2155 2257 2378 2470 2498 2655 2671 3095 3111 3485 3597 3768 3844 3946 4455 4612 4848 4878 6041 6116 6692 7543 8505
foreach num in `numbers' {
    rdplot limited_firm MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") subtitle(Significance level: 0.01) ytitle(Limited Firm) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/rd_plot_limited_firm_market_`num'.pdf", replace
    di "Processing number: `num'"
}

* RD plot for each item_class (significance: 0.01)
local numbers 4110 4120 4695 5610 5890 6310 7310 7505 7610 7920 7940 8105 8115 8250 8310 8905 8935 8965
foreach num in `numbers' {
    rdplot limited_firm MV if MV<0.10 & MV>-0.10 & códigoclasse==`num', graph_options(title("Item Class `num'") subtitle(Significance level: 0.01) ytitle(Limited Firm) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/firm_structure/item_class/rd_plot_limited_firm_item_class_`num'.pdf", replace
    di "Processing number: `num'"
}

* RD plot for each item_group (significance: 0.01)
local numbers 41 46 56 63 76 79 81 83 89
foreach num in `numbers' {
    rdplot limited_firm MV if MV<0.10 & MV>-0.10 & códigogrupo==`num', graph_options(title("Item Group `num'") subtitle(Significance level: 0.01) ytitle(Limited Firm) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/firm_structure/item_group/rd_plot_limited_firm_item_group_`num'.pdf", replace
    di "Processing number: `num'"
}


