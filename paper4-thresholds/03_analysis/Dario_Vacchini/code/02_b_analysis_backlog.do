**********************************************************************************
**************************** 02_b_analysis_backlog.do ****************************
**********************************************************************************

**********************************************************************************

/* The goal of this do file is to run the main regression and plots of the incumbency
variables */

* 0. Import data
* 1. Incumbency: Won t-1 same buyer
* 2. Incumbency: Won t-1 same market
*** 2.1 Regressions
*** 2.2 RD plot for each significant market
* 3. Incumbency: last bid
*** 3.1 Regression (same market)
*** 3.2 RD plot for each significant market

**********************************************************************************


*** 0. Import data
use "$data/final/df_convite_winner_looser.dta", clear


**********************************************************************************

sort auction_num datetimevar
drop e
drop max_e
drop max_m


**********************************************************************************
************************ 1. 90-Day Share Won same market *************************
**********************************************************************************


*** 1.1 Regressions

* RD regression
eststo reg1: reghdfe share_won90_market_item i.flagvencedor##c.MV if MV<0.01 & MV>-0.01, vce(cluster market_item) abs(year market_item)  
sum share_won90_market_item 
outreg2 using $output/tables/backlog/rd_reg_90_share_won_market.xls, replace excel tex(frag) bdec(4) label ctitle(90-Day Share Won)

* RD regression for each market
levelsof market_item, local(market_items)
foreach market in `market_items' {
    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 20 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe share_won90_market_item i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)
		outreg2 using $output/tables/rd_reg_90_share_won_markets.xls , excel tex(frag) bdec(4) label ctitle(backlog_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}


**********************************************************************************


*** 1.2 RD Plots

* RD plot
rdplot cumprof_won_365_market_item_std MV if MV<0.10 & MV>-0.10, graph_options(ytitle(90-Day Share Won (same market)) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)
graph export "$output/graphs/backlog/rd_plot_share_won90_overall_market.pdf", replace
	
* RD plot for each market
local numbers 20 72 123 170 185 257 270 289 377 468 475 707 754 764 815 855 903 947 1056 1058 1189 1221 1344 1376 1514 1534 1536 1604 1761 1795 1816 2037 2066 2096 2155 2228 2268 2352 2370 2514 2590 2599 2643 2665 2671 2851 3053 3567 3576 3596 3621 3946 4106 5573 5821 6611 8212
foreach num in `numbers' {
    rdplot share_won90_market_item MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") ytitle(90-Day Share Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/backlog/market/rd_plot_share_won90_market_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************
********************** 2. 90-Day Share Won same item class ***********************
**********************************************************************************


*** 2.1 Regressions

* RD regression
eststo reg2: reghdfe share_won90_item_class i.flagvencedor##c.MV if MV<0.01 & MV>-0.01, vce(cluster códigoclasse) abs(year códigoclasse)  
sum share_won90_item_class
outreg2 using $output/tables/backlog/rd_reg_90_share_won_item_class.xls, replace excel tex(frag) bdec(4) label ctitle(90-Day Share Won (same item_class))

* RD regression for each market
levelsof market_item, local(market_items)
foreach market in `market_items' {
    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 20 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe share_won90_market_item i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)
		outreg2 using $output/tables/rd_reg_90_share_won_markets.xls , excel tex(frag) bdec(4) label ctitle(backlog_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}


**********************************************************************************


*** 2.2 RD Plots

* RD plot
rdplot share_won90_item_class MV if MV<0.10 & MV>-0.10, graph_options(ytitle(90-Day Share Won (same item_class)) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)
graph export "$output/graphs/backlog/rd_plot_share_won90_overall_item_class.pdf", replace
	
* RD plot for each market
local numbers 2610 3990 5320 5325 5520 5530 6210 6240 6350 6511 6531 6565 6578 6730 6731 7210 7810 7920 7940 8010 8010 8310 8421 8451 8530 8540 8690 8905 8910 9160
foreach num in `numbers' {
    rdplot share_won90_market_item MV if MV<0.10 & MV>-0.10 & códigoclasse==`num', graph_options(title("Item Class `num'") ytitle(90-Day Share Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/backlog/item_class/rd_plot_share_won90_item_class_`num'.pdf", replace
    di "Processing number: `num'"
}

eststo clear
**********************************************************************************
***************** 3. 90-Day STD Cumulative Profits same market *******************
**********************************************************************************


*** 1.1 Regressions

* RD regression
eststo reg3: reghdfe cumprof_won_90_market_item_std i.flagvencedor##c.MV if MV<0.01 & MV>-0.01, vce(cluster market_item) abs(year market_item)  
sum cumprof_won_90_market_item_std 
outreg2 using $output/tables/backlog/rd_reg_cumprof_won_90_market.xls, replace excel tex(frag) bdec(4) label ctitle(90-Day STD Cumulative Profits same market)

* RD regression for each market
levelsof market_item, local(market_items)
foreach market in `market_items' {
    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 20 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe share_won90_market_item i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)
		outreg2 using $output/tables/rd_reg_90_share_won_markets.xls , excel tex(frag) bdec(4) label ctitle(backlog_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}


**********************************************************************************


*** 1.2 RD Plots

* RD plot
rdplot cumprof_won_90_market_item_std MV if MV<0.10 & MV>-0.10, graph_options(ytitle(90-Day STD Cumulative Profits (same market)) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
graph export "$output/graphs/backlog/rd_plot_cumprof_won_90_std_overall_market.pdf", replace
	
* RD plot for each market
local numbers 20 72 123 170 185 257 270 289 377 468 475 707 754 764 815 855 903 947 1056 1058 1189 1221 1344 1376 1514 1534 1536 1604 1761 1795 1816 2037 2066 2096 2155 2228 2268 2352 2370 2514 2590 2599 2643 2665 2671 2851 3053 3567 3576 3596 3621 3946 4106 5573 5821 6611 8212
foreach num in `numbers' {
    rdplot share_won90_market_item MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") ytitle(90-Day STD Cumulative Profits) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/backlog/market/rd_plot_cumprof_won_90_std_market_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************
*************** 4. 90-Day STD Cumulative Profits same item class *****************
**********************************************************************************


*** 4.1 Regressions

* RD regression
eststo reg4: reghdfe cumprof_won_90_item_class_std i.flagvencedor##c.MV if MV<0.01 & MV>-0.01, vce(cluster códigoclasse) abs(year códigoclasse)  
sum cumprof_won_90_item_class_std
outreg2 using $output/tables/backlog/rd_reg_cumprof_won_90_std_item_class.xls, replace excel tex(frag) bdec(4) label ctitle(90-Day STD Cumulative Profits (same market))

* RD regression for each market
levelsof market_item, local(market_items)
foreach market in `market_items' {
    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 20 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe share_won90_market_item i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)
		outreg2 using $output/tables/rd_reg_90_share_won_markets.xls , excel tex(frag) bdec(4) label ctitle(backlog_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}


**********************************************************************************


*** 4.2 RD Plots

* RD plot
rdplot cumprof_won_90_item_class_std MV if MV<0.10 & MV>-0.10, graph_options(ytitle(90-Day STD Cumulative Profits (same market))) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)
graph export "$output/graphs/backlog/rd_plot_cumprof_won_90_std_overall_item_class.pdf", replace
	
* RD plot for each market
local numbers 2610 3990 5320 5325 5520 5530 6210 6240 6350 6511 6531 6565 6578 6730 6731 7210 7810 7920 7940 8010 8010 8310 8421 8451 8530 8540 8690 8905 8910 9160
foreach num in `numbers' {
    rdplot share_won90_market_item MV if MV<0.10 & MV>-0.10 & códigoclasse==`num', graph_options(title("Item Class `num'") ytitle(90-Day Share Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/backlog/item_class/rd_plot_share_won90_item_class_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************
