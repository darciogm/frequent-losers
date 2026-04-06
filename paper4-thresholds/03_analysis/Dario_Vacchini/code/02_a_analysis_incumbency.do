**********************************************************************************
************************** 02_a_analysis_incumbency.do ***************************
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
*********************** 1. Incumbency: Won t-1 same buyer ************************
**********************************************************************************


* RD regression
eststo reg1: reghdfe won_t_minus_1_compr i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(year códigogrupo códigounidadecompradora)
outreg2 using $output/tables/incumbency/rd_reg_won_t_minus_1_compr.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Won (t-1) - same buyer)
sum won_t_minus_1_compr if MV<0.01 & MV>-0.01

* RD plot
rdplot won_t_minus_1_compr MV if MV<0.10 & MV>-0.10, graph_options(ytitle(Previous Auction Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(4)


**********************************************************************************
******************** 2. Incumbency: Won t-1 same market **************************
**********************************************************************************


*** 2.1 Regressions

* RD regression
eststo reg1: reghdfe won_t_minus_1_market i.flagvencedor##c.MV if MV<0.02 & MV>-0.02, vce(cluster market_item) noabs
eststo reg2: reghdfe won_t_minus_1_market i.flagvencedor##c.MV if MV<0.02 & MV>-0.02, vce(cluster market_item) absorb(year market_item)
eststo reg3: reghdfe last i.flagvencedor##c.MV if MV<0.011 & MV>-0.011, vce(cluster market_item) noabs
eststo reg4: reghdfe last i.flagvencedor##c.MV if MV<0.011 & MV>-0.011, vce(cluster market_item) absorb(year market_item)

esttab reg1 reg2 reg3 reg4, r2 ar2 se star(* .1 ** .05 *** .01)

eststo clear
outreg2 using $output/tables/incumbency/rd_reg_won_t_minus_1_market.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Won (t-1) - same market)
sum won_t_minus_1_market_item if MV<0.01 & MV>-0.01

xi: rdrobust won_t_minus_1_market MV if MV<0.1 & MV>-0.1, covs(i.year) c(0) vce(cluster market_item)
xi: rdrobust last MV if MV<0.1 & MV>-0.1, covs(i.year) c(0) vce(cluster market_item)
outreg2 using $output/tables/incumbency/rd_reg_won_t_minus_1_market.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Won (t-1) - same market)



gen interaction = flagvencedor * MV
areg won_t_minus_1_market i.year i.market_item, absorb(year market_item)
predict y_resid, resid
rdrobust y_resid MV if MV < 0.01 & MV > -0.01, ///
    covs(flagvencedor_dummy interaction) ///
    vce(cluster market_item)



* RD regression for each market
* Open a CSV file to store results
file open myfile_1 using "$data/raw/reg_won_t_minus_1_market.csv", write replace
file write myfile_1 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe won_t_minus_1_market_item i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_1 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "$output/tables/reg_won_t_minus_1_1_750_market.xls" , excel tex(frag) bdec(4) label ctitle(won_t_minus_1_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_1


**********************************************************************************


*** 2.2 RD Plots

* RD plot
rdplot won_t_minus_1_market MV if MV<0.10 & MV>-0.10, graph_options(title(Incumbency: Won auction t-1 same market) ytitle(Previous Auction Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)
graph export "$output/graphs/incumbency/rd_plot_won_t_minus_1_overall_market.pdf", replace

* RD plot for each market (significance: 0.05)
local numbers 20 86 389 435 505 815 866 903 946 1058 1079 1116 1171 1189 1288 1376 1569 1623 1740 1761 1794 1816 2052 2155 2370 2590 2639 2778 2816 2998 3307 3309 3385 3399 3593 3596 3612 4079 4106 4462 4609 6611 6736 8779 10497
foreach num in `numbers' {
    rdplot won_t_minus_1_market MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") subtitle(Significance level: 0.05) ytitle(Previous Auction Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/market/rd_plot_won_t_minus_1_market_`num'.pdf", replace
    di "Processing number: `num'"
}

**********************************************************************************
******************** 3. Incumbency: Won t-1 same item class **********************
**********************************************************************************


*** 3.1 Regressions

* RD regression
eststo reg2: reghdfe won_t_minus_1_item_class i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigoclasse) abs(year códigoclasse)
outreg2 using $output/tables/incumbency/rd_reg_won_t_minus_1_item_class.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Won (t-1) - same item class)

* RD regression for each market
* Open a CSV file to store results
file open myfile_1 using "$data/raw/reg_won_t_minus_1_item_class.csv", write replace
file write myfile_1 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe won_t_minus_1_item_class i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_1 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "$output/tables/reg_won_t_minus_1_1_750_item_class.xls" , excel tex(frag) bdec(4) label ctitle(won_t_minus_1_market_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_1


**********************************************************************************


*** 2.2 RD Plots

* RD plot
rdplot won_t_minus_1_item_class MV if MV<0.10 & MV>-0.10, graph_options(title(Incumbency: Won auction t-1 same item class) ytitle(Previous Auction Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)
graph export "$output/graphs/incumbency/rd_plot_won_t_minus_1_overall_item_class.pdf", replace

* RD plot for each item_class (significance: 0.01)
local numbers 2760 5520 6565 8421 8695
foreach num in `numbers' {
    rdplot won_t_minus_1_item_class MV if MV<0.10 & MV>-0.10 & códigoclasse==`num', graph_options(title("Item Class `num'") subtitle(Significance level: 0.01) ytitle(Previous Auction Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/item_class/rd_plot_won_t_minus_1_item_class_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************
******************** 4. Incumbency: last bid same market *************************
**********************************************************************************


*** 4.1 Regression (same market)


* RD regression
eststo reg3: reghdfe last i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)
outreg2 using $output/tables/incumbency/rd_reg_last_bid_market.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Last Bid)

* RD regression for each market
* Open a CSV file to store results
file open myfile_2 using "$data/raw/reg_last_bid_market.csv", write replace
file write myfile_2 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe last i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_2 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "$output/tables/reg_last_bid_1_750_market.xls" , excel tex(frag) bdec(4) label ctitle(last_bid_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_2


**********************************************************************************


*** 4.2 RD plots

* RD plot
rdplot last MV if MV<0.10 & MV>-0.10, graph_options(title(Incumbency: Last Bid) ytitle(Last Bid) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(4)
graph export "$output/graphs/incumbency/rd_plot_last_bid_overall_market.pdf", replace

* RD plot for each market (significance: 0.05)
local numbers 4 20 93 95 194 288 292 329 363 378 468 477 708 1007 1028 1058 1082 1102 1226 1327 1376 1536 1583 1609 1636 1728 1816 2037 2088 2134 2206 2228 2378 2401 2412 2498 2599 2778 2789 2895 2973 3054 3124 3309 3314 3407 3462 3555 3568 3592 3593 3597 3687 3728 3844 4204 4455 4597 4612 4647 4694 4848 5443 6029 6288 7370 7592 10497
foreach num in `numbers' {
    rdplot last MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") subtitle(Significance level: 0.05) ytitle(Last Bid) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/market/rd_plot_last_bid_market_`num'.pdf", replace
    di "Processing number: `num'"
}

**********************************************************************************
****************** 5. Incumbency: last bid same item class ***********************
**********************************************************************************


*** 4.1 Regression (same item_class)


* RD regression
eststo reg3: reghdfe last i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigoclasse) abs(year códigoclasse)
outreg2 using $output/tables/incumbency/rd_reg_last_bid_item_class.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Last Bid)

* RD regression for each market
* Open a CSV file to store results
file open myfile_2 using "$data/raw/reg_last_bid_market.csv", write replace
file write myfile_2 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe last i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_2 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "$output/tables/reg_last_bid_1_750_market.xls" , excel tex(frag) bdec(4) label ctitle(last_bid_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_2


**********************************************************************************


*** 4.2 RD plots

* RD plot
rdplot last MV if MV<0.10 & MV>-0.10, graph_options(title(Incumbency: Last Bid) ytitle(Last Bid) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(4)
graph export "$output/graphs/incumbency/rd_plot_last_bid_overall_item_class.pdf", replace

* RD plot for each item_class (significance: 0.01)
local numbers 3295 4695 6730 7210 7220 7840 7920 7930 8421 8431 8451 8530 8695 8970
foreach num in `numbers' {
    rdplot last MV if MV<0.10 & MV>-0.10 & códigoclasse==`num', graph_options(title("Item Class `num'") subtitle(Significance level: 0.01) ytitle(Last Bid) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/item_class/rd_plot_last_bid_item_class_`num'.pdf", replace
    di "Processing number: `num'"
}

**********************************************************************************
****************** 5. Incumbency: last bid same group class **********************
**********************************************************************************


*** 4.1 Regression (same item_class)


* RD regression
eststo reg3: reghdfe last i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigogrupo) abs(year códigogrupo)
outreg2 using $output/tables/incumbency/rd_reg_last_bid_item_group.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Last Bid)

* RD regression for each market
* Open a CSV file to store results
file open myfile_2 using "$data/raw/reg_last_bid_market.csv", write replace
file write myfile_2 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe last i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_2 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "$output/tables/reg_last_bid_1_750_market.xls" , excel tex(frag) bdec(4) label ctitle(last_bid_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_2


**********************************************************************************


*** 4.2 RD plots

* RD plot
rdplot last MV if MV<0.10 & MV>-0.10, graph_options(title(Incumbency: Last Bid) ytitle(Last Bid) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(4)
graph export "$output/graphs/incumbency/rd_plot_last_bid_overall_item_class.pdf", replace

* RD plot for each item_class (significance: 0.01)
local numbers 3295 4695 6730 7210 7220 7840 7920 7930 8421 8431 8451 8530 8695 8970
foreach num in `numbers' {
    rdplot last MV if MV<0.10 & MV>-0.10 & códigoclasse==`num', graph_options(title("Item Class `num'") subtitle(Significance level: 0.01) ytitle(Last Bid) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/item_class/rd_plot_last_bid_item_class_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************
************** 5. Incumbency: Second lowest bid (same market) ********************
**********************************************************************************


*** 5.1 Regression (same market)


* RD regression
eststo reg4: reghdfe second_t_minus_1_market i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)
outreg2 using $output/tables/incumbency/rd_reg_sec_low_bid_t_minus_1_market.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Second Lowest Bid)

* RD regression for each market
* Open a CSV file to store results
file open myfile_4 using "$data/raw/reg_sec_lowest_bid_market.csv", write replace
file write myfile_4 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe second_t_minus_1_market i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_4 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "$output/tables/reg_sec_lowest_bid_market.xls" , excel tex(frag) bdec(4) label ctitle(last_bid_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_4


**********************************************************************************


*** 4.2 RD plots

* RD plot
rdplot second_t_minus_1_market MV if MV<0.10 & MV>-0.10, graph_options(title(Incumbency: Second Lowest bid) ytitle(Previous marginal looser) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(4)
graph export "$output/graphs/incumbency/rd_plot_sec_lowest_bid_overall_market.pdf", replace

* RD plot for each market (significance: 0.01)
local numbers 77 422 561 608 627 731 1528 1575 1893 2028 3485 3559 4328 4660 6012 6410 12272
foreach num in `numbers' {
    rdplot second_t_minus_1_market MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") subtitle(Significance level: 0.01) ytitle(Second previous auction) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/market/rd_plot_second_t_minus_1_market_`num'.pdf", replace
    di "Processing number: `num'"
}



**********************************************************************************
************** 4. Incumbency: Second lowest bid (same market) ********************
**********************************************************************************


*** 4.1 Regression (same market)


* RD regression
eststo reg4: reghdfe second_t_minus_1_market i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster market_item) abs(year market_item)
outreg2 using $output/tables/incumbency/rd_reg_sec_low_bid_t_minus_1_market.xls , replace excel tex(frag) bdec(4) label ctitle(Inc: Second Lowest Bid)

* RD regression for each market
* Open a CSV file to store results
file open myfile_4 using "$data/raw/reg_sec_lowest_bid_market.csv", write replace
file write myfile_4 "Variable, Coefficient, Std. Error, Market Item, Sig_1pct, Sig_5pct, Sig_10pct" _n

* RD regression for each market
levelsof market_item, local(market_items)

* Initialize a counter
local count = 0

foreach market in `market_items' {
    * Increment the counter
    local count = `count' + 1

    // Count the number of observations for each market_item
    count if market_item == `market' & MV < 0.01 & MV > -0.01
    local n = r(N) // Store the count in a local macro

    // Run the regression only if there are more than 10 observations
    if `n' >= 30 {
        di "Running regression for market_item = `market' with `n' observations"
        
        reghdfe second_t_minus_1_market i.flagvencedor##c.MV if market_item == `market' & MV < 0.01 & MV > -0.01, abs(year)

        // Get coefficients and standard errors
        matrix b = e(b)
        matrix V = e(V)
        local varnames: colnames b  // Get variable names from the matrix b

        // Loop over each variable name to find the one related to flagvencedor
        foreach var of local varnames {
            if strpos("`var'", "1.flagvencedor") {  // Check if the variable name contains "1.flagvencedor"
                local coef = b[1, "`var'"]
                local stderr = sqrt(V["`var'", "`var'"])

                // Calculate z-score for significance testing
                local z = abs(`coef' / `stderr')

                // Determine significance at 1%, 5%, and 10% levels
                local sig_1pct = cond(`z' > 2.576, 1, 0)  // 2.576 for 1% significance level (two-tailed test)
                local sig_5pct = cond(`z' > 1.96, 1, 0)   // 1.96 for 5% significance level
                local sig_10pct = cond(`z' > 1.645, 1, 0) // 1.645 for 10% significance level

                // Write to CSV file with significance levels
                file write myfile_4 "`var', `coef', `stderr', `market', `sig_1pct', `sig_5pct', `sig_10pct'" _n
            }
        }

        * Optionally, save regression results in Excel as before
        outreg2 using "$output/tables/reg_sec_lowest_bid_market.xls" , excel tex(frag) bdec(4) label ctitle(last_bid_`market') addtext(Year FE, YES)
    }
    else {
        di "Skipping market_item = `market' due to insufficient observations (`n')"
    }
}

* Close the CSV file
file close myfile_4


**********************************************************************************


*** 4.2 RD plots

* RD plot
rdplot second_t_minus_1_market MV if MV<0.10 & MV>-0.10, graph_options(title(Incumbency: Second Lowest bid) ytitle(Previous marginal looser) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(4)
graph export "$output/graphs/incumbency/rd_plot_sec_lowest_bid_overall_market.pdf", replace

* RD plot for each market (significance: 0.01)
local numbers 77 422 561 608 627 731 1528 1575 1893 2028 3485 3559 4328 4660 6012 6410 12272
foreach num in `numbers' {
    rdplot second_t_minus_1_market MV if MV<0.10 & MV>-0.10 & market_item==`num', graph_options(title("Market `num'") subtitle(Significance level: 0.01) ytitle(Second previous auction) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9)) nbins(25) p(2)
	graph export "$output/graphs/incumbency/market/rd_plot_second_t_minus_1_market_`num'.pdf", replace
    di "Processing number: `num'"
}


**********************************************************************************


