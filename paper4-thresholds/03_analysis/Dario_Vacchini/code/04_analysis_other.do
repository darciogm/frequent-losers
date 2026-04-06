**********************************************************************************
**************************** 03_c_analysis_other.do ******************************
**********************************************************************************

**********************************************************************************

*** 0. Import data
use "$data/final/df_convite_winner_looser.dta", clear

sort auction_num datetimevar


**********************************************************************************


*** 1. Number of firms by market having a significant positive coefficient

* Tag distinct firms by market
egen tag1 = tag(market_item firm)
bysort market_item: egen distinct_firm_count = total(tag1)

* Tag distinct items by market
egen tag2 = tag(market_item códigoitem)
bysort market_item: egen distinct_item_count = total(tag2)

* Keep only positive significant at 95% coefficients
keep if inlist(market_item, 232, 378, 503, 505, 579, 712, 1219, 1427, 1604, 1697, 1795, 1805, 2058, 2066, 2378, 2639, 2643, 3196, 3256, 3309, 3410, 3576, 3596, 3597, 3649, 3844, 3866, 4079, 4455, 4597, 4955, 5148, 6288, 7592, 8158, 9607, 9738, 9783, 10381, 10497, 11565, 12955, 14286, 14850, 16590)

* Keep only one observation by market
bysort market_item: gen select = _n
keep if select == 1

* Bar plot
graph bar distinct_firm_count, over(market_item) blabel(bar) ///
title("Number of Firms by Market") ///
ylabel(, angle(0)) ///
ytitle("Number of Firms") ///
xsize(25) ///
legend(off) ///
bar(1, color(navy))
graph export "$output/graphs/hist_number_firms_significant_markets.pdf", replace


**********************************************************************************


*** 2. Firm Age

* RD regression
eststo reg4: reghdfe age i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(year códigogrupo códigounidadecompradora )  
sum age 
outreg2 using $output/tables/rd_regression_preliminaries.xls, replace excel tex(frag) bdec(4) label ctitle(Firm Age)

* RD plot
rdplot age MV if MV<0.10 & MV>-0.10, graph_options(ytitle(Firm Age) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(50) p(2)


**********************************************************************************


*** 3. Limited Liability Firm

* RD regression
eststo reg5: reghdfe limited_firm i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(year códigogrupo códigounidadecompradora )  
sum limited_firm 
outreg2 using $output/tables/rd_regression_preliminaries.xls, replace excel tex(frag) bdec(4) label ctitle(Limited Liability Firm)

* RD plot
rdplot limited_firm MV if MV<0.10 & MV>-0.10, graph_options(ytitle(Limited Liability Firm) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9)) nbins(50) p(2)

**********************************************************************************


*** 4. Cumulative sum of auction won by firm from the same buyer

* Cumulative sum of auction won by firm from the same buyer
bysort firm códigounidadecompradora (datetimevar numerodaoc): egen cum_won_whole_compr = sum(flagvencedor_whole_auction) if numerodaoc != numerodaoc[_n-1]
preserve
collapse (max) cum_won_whole_compr, by(firm)
hist cum_won_whole_compr if cum_won_whole_compr>50, frequency
restore

bysort firm códigounidadecompradora year (datetimevar numerodaoc): egen cum_won_whole_compr_year = sum(flagvencedor_whole_auction) if numerodaoc != numerodaoc[_n-1]

**********************************************************************************


*** 5. Auction Winning streak by firm from the same buyer

* Dummy: 1 if won the previous auction of the same buyer
bysort firm códigounidadecompradora (datetimevar numerodaoc): gen won_previous_compr = flagvencedor_whole_auction[_n-1] if firm == firm[_n-1] & códigounidadecompradora == códigounidadecompradora[_n-1] & numerodaoc != numerodaoc[_n-1]

* Initialize the streak counter
gen streak_counter = 0

* Count consecutive wins
bysort firm códigounidadecompradora (datetimevar numerodaoc): replace streak_counter = 0 if won_previous_compr == 0
replace streak_counter = (won_previous_compr == 1) + streak_counter[_n-1] if _n > 1 & firm == firm[_n-1] & códigounidadecompradora == códigounidadecompradora[_n-1] & datetimevar > datetimevar[_n-1] & numerodaoc != numerodaoc[_n-1] & won_previous_compr == 1

* Identify winning streaks
gen winning_streak = 0
bysort firm códigounidadecompradora (datetimevar numerodaoc): replace winning_streak = streak_counter if won_previous_compr == 1 & won_previous_compr == won_previous_compr[_n-1]
preserve
collapse (max) winning_streak, by(firm códigounidadecompradora)
hist winning_streak if winning_streak>10, frequency by(códigounidadecompradora)
restore


**********************************************************************************


*** 6. Cumulative sum of auction won by firm from the same market

* Cumulative sum of auction won by firm from the same buyer
bysort firm market_item (datetimevar numerodaoc): egen cum_won_whole_market = sum(flagvencedor_whole_auction) if numerodaoc != numerodaoc[_n-1]
preserve
collapse (max) cum_won_whole_market, by(firm)
hist cum_won_whole_market if cum_won_whole_market>50, frequency
restore


**********************************************************************************

*** 7. Auction Winning streak by firm from the same market

* Dummy: 1 if won the previous auction of the same market
bysort firm market_item (datetimevar numerodaoc): gen won_previous_market = flagvencedor_whole_auction[_n-1] if firm == firm[_n-1] & market_item == market_item[_n-1] & numerodaoc != numerodaoc[_n-1]

* Initialize the streak counter
gen streak_counter_market = 0

* Count consecutive wins
bysort firm market_item (datetimevar numerodaoc): replace streak_counter = 0 if won_previous_market == 0
replace streak_counter_market = (won_previous_market == 1) + streak_counter_market[_n-1] if _n > 1 & firm == firm[_n-1] & market_item == market_item[_n-1] & datetimevar > datetimevar[_n-1] & numerodaoc != numerodaoc[_n-1] & won_previous_market == 1

* Identify winning streaks
gen winning_streak_market = 0
bysort firm market_item (datetimevar numerodaoc): replace winning_streak_market = streak_counter_market if won_previous_market == 1 & won_previous_market == won_previous_market[_n-1]
preserve
collapse (max) winning_streak_market, by(market_item)
hist winning_streak_market if winning_streak_market>10, frequency
restore








