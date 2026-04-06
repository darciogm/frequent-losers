**********************************************************************************
*************************** 02_b_analysis_backlog.do *****************************
**********************************************************************************

**********************************************************************************

/* The goal of this do file is to run the main regression and plots of the backlog
variables */

* 0. Import data
* 1. 120-Day Standardized Backlog (actual amount won)
*** 1.1 Regressions
*** 1.2 RD Plots
* 2. 120-Day Standardized Backlog (potential amount won) - same buyer
* 3. 120-Day Standardized Backlog (potential amount won) - same market
*** 3.1 Regressions
*** 3.2 RD Plots
* 4. 90-Day Share Won same buyer
* 5. 90-Day Share Won same market
*** 5.1 Regressions
*** 5.2 RD Plots

**********************************************************************************


*** 0. Import data
use "$data/final/df_convite_winner_looser.dta", clear

sort auction_num datetimevar


**********************************************************************************
************** 1. 120-Day Standardized Backlog (actual amount won) ***************
**********************************************************************************


*** 1.1 Regressions

* RD regression
eststo reg1: reghdfe cumprof_won_120_market_std i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)  
sum cumprof_won_120_market_std 
outreg2 using $output/tables/backlog/rd_reg_120_backlog_market.xls, replace excel tex(frag) bdec(4) label ctitle(120-Day Standardized Backlog)

* RD regression for each market
levelsof market_item, local(market_items)
foreach market in `market_items' {
    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 20 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe cumprof_won_120_market_std i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)
		outreg2 using $output/tables/backlog/rd_reg_120_backlog_markets.xls , excel tex(frag) bdec(4) label ctitle(backlog_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}


**********************************************************************************


*** 1.2 RD Plots

* RD plot
rdplot cumprof_won_120_market_std MV if MV<0.10 & MV>-0.10, graph_options(ytitle(120-Day Standardized Backlog (same market)) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)

* RD plot for each market
local numbers 505 1427 1604 1795 2058 2378 2639 2643 3196 3256 3410 7592 9738 9783 10381
foreach num in `numbers' {
    rdplot cumprof_won_120_market_std MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") ytitle(120-Day Standardized Backlog) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/backlog/rd_plot_120_backlog_market_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************
****** 2. 120-Day Standardized Backlog (potential amount won) - same buyer *******
**********************************************************************************


* RD regression
eststo reg2: reghdfe pot_cumprof_won_120_compr_std i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(year códigogrupo códigounidadecompradora)  
sum cumprof_won_120_compr_std 
outreg2 using $output/tables/backlog/rd_reg_pot_120_backlog_compr.xls, replace excel tex(frag) bdec(4) label ctitle(120-Day Standardized Backlog (same buyer))

* RD plot
rdplot pot_cumprof_won_120_compr_std MV if MV<0.10 & MV>-0.10, graph_options(ytitle(120-Day Standardized Backlog) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)


**********************************************************************************
****** 3. 120-Day Standardized Backlog (potential amount won) - same market ******
**********************************************************************************


*** 3.1 Regressions

* RD regression
eststo reg3: reghdfe pot_cumprof_won_120_market_std i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)  
sum pot_cumprof_won_120_market_std 
outreg2 using $output/tables/rd_reg_pot_120_backlog_market.xls, replace excel tex(frag) bdec(4) label ctitle(120-Day Standardized Backlog)

* RD regression for each market
levelsof market_item, local(market_items)
foreach market in `market_items' {
    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 20 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe pot_cumprof_won_120_market_std i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)
		outreg2 using $output/tables/rd_reg_pot_120_backlog_markets.xls , excel tex(frag) bdec(4) label ctitle(backlog_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}


**********************************************************************************


*** 3.2 RD Plots

* RD plot
rdplot pot_cumprof_won_120_market_std MV if MV<0.10 & MV>-0.10, graph_options(ytitle(120-Day Standardized Backlog (same market)) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)

* RD plot for each market
local numbers 1427 1604 1795 2058 2378 2639 2643 3196 3256 3410 7592 9738 9783 10381
foreach num in `numbers' {
    rdplot pot_cumprof_won_120_market_std MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") ytitle(120-Day Standardized Backlog) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/backlog/rd_plot_pot_120_backlog_market_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************
************************* 4. 90-Day Share Won same buyer *************************
**********************************************************************************


* RD regression
eststo reg2: reghdfe share_won90_compr i.flagvencedor##c.MV  if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(year códigogrupo códigounidadecompradora)  
sum share_won90_compr if MV<0.01 & MV>-0.01
outreg2 using $output/tables/backlog/rd_reg_90_share_won_compr.xls, replace excel tex(frag) bdec(4) label ctitle(90-Day Share Won (same buyer))

* RD plot
rdplot share_won90_compr MV if MV<0.10 & MV>-0.10, graph_options(ytitle(90-Day Share Won) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)


**********************************************************************************
************************ 5. 90-Day Share Won same market *************************
**********************************************************************************


*** 5.1 Regressions

* RD regression
eststo reg4: reghdfe share_won90_market_item i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)  
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


*** 5.2 RD Plots

* RD plot
rdplot share_won90_market_item MV if MV<0.10 & MV>-0.10, graph_options(ytitle(120-Day Standardized Backlog (same market)) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)

* RD plot for each market
local numbers 378 579 712 1604 1697 2066 2378 2643 3256 3410 3596 3844 4455 6288 7592 8158 9738 10381
foreach num in `numbers' {
    rdplot share_won90_market_item MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") ytitle(90-Day Share Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/backlog/rd_plot_90_share_won_market_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************




