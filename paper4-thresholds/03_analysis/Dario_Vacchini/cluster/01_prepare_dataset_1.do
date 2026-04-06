**********************************************************************************
**************************** 01_prepare_dataset.do *******************************
**********************************************************************************

**********************************************************************************

* This do file generates the varibales and clean the dataset to be processed for the analysis

* 1. Generate Variables
* 2. Label Variables

**********************************************************************************

set processor 64

*** 0. Import data
use if descriçãoprocedimentocompra=="CONVITE" using "/cluster/work/lawecon/Projects/procurement_brazil/LANCES_Final_Semester.dta", clear

**********************************************************************************


*** 1. Generate and preprocess general variables

* Firm ID
egen long firm = group(descriçãorazãosocial)

* Time of the offer
gen datetimevar = clock(datahrproposta , "YMD hms")
format datetimevar %tcDDmonCCYY_HH:MM:SS

* Auction item
gen auction_item =  numerodaoc + "_" + códigoitem

* Item ID
egen long auction_num = group(auction_item)

* Date
gen datevar = date(mêsanoencerramento , "MY") 
format datevar %td

* Type of item
destring códigogrupo, replace force

* Dummy for each item type
tabulate códigogrupo, generate(gr)

* Year
gen year=year(datevar)

* Replace "," with "." and convert to numeric
foreach var in valorunitárioproposta valorunitarionegociado	valortotalproposta	valorunitárioreferência	propostavencedorprimeiro valormínimounitárioproposta	valormáximounitárioproposta valortotalnegociado {
  * Replace comma with period for each variable in the list
  replace `var' = subinstr(`var', ",", ".", .)
  * Convert the string variables to numeric variables
  destring `var', replace
}

* limited company indicator
gen limited_firm=descriçãonaturezajurídica=="SOCIEDADE EMPRESÁRIA LIMITADA"

* Location advantage - indicator for company being from the same municipality as buyer
gen equal_mun=descriçãomunicípiofornecedor==descriçãomunicípiodeentrega


**********************************************************************************


*** 2. Generate time window variables

* Ensure data is sorted
sort firm datetimevar

* Create a time window variable (30 days in milliseconds)
gen window_start_2 = datetimevar - 2*24*60*60*1000
gen window_start_30 = datetimevar - 30*24*60*60*1000
gen window_start_60 = datetimevar - 60*24*60*60*1000
gen window_start_90 = datetimevar - 90*24*60*60*1000
gen window_start_120 = datetimevar - 120*24*60*60*1000
gen window_start_365 = datetimevar - 365*24*60*60*1000

**********************************************************************************


*** 3. Generate Market variable

egen auction_id = group(numerodaoc)

* Sort the data to prepare for pair creation
sort auction_id firm

* Initialize market ID with firm_id values
gen market_item = firm

* Recursive merging: Iteratively update market ID based on shared auctions
local changes = 1

while `changes' > 0 {
    * Sort data by auction_id_group, códigogrupo, and market_group before each iteration
    sort auction_id códigoclasse market

    * Store the previous market values to check for changes
    gen old_market = market_item

    * Update market ID to propagate minimum ID across firms in the same auction, but only for related goods
    by auction_id códigoclasse: replace market_item = market_item[_n-1] if market_item[_n-1] < market_item
    by auction_id códigoclasse: replace market_item = market_item[_n+1] if market_item[_n+1] < market_item

    * Count real changes by comparing old and new market values
    quietly count if market_item != old_market
    local changes = r(N)

    * Clean up the temporary variable
    drop old_market
}

* Sort the data to prepare for pair creation
sort auction_id firm

* Initialize market ID with firm_id values
gen market = firm

* Recursive merging: Iteratively update market ID based on shared auctions
local changes = 1

while `changes' > 0 {
    * Sort data by auction_id and market before each iteration
    sort auction_id market

    * Store the previous market values to check for changes
    gen old_market = market

    * Update market ID to propagate minimum ID across firms in the same auction
    by auction_id: replace market = market[_n-1] if market[_n-1] < market
    by auction_id: replace market = market[_n+1] if market[_n+1] < market

    * Count real changes by comparing old and new market values
    quietly count if market != old_market
    local changes = r(N)

    * Clean up the temporary variable
    drop old_market
}


**********************************************************************************


*** 4. Generate Incumbency variables

* Dummy: 1 if win the item at time t
destring flagvencedor, force replace
destring códigoclasse, force replace

* Keep only smallest bid per auction of each firm
bysort auction_num firm (valorunitárioproposta): gen tag = _n == 1
keep if tag==1

* Numbering of bids by auction in ascending order of bid amount
bys auction_num (valorunitárioproposta): gen m = _n

* Dummy: 1 if firm win the auction at time t
bys firm numerodaoc: egen flagvencedor_whole_auction=max(flagvencedor)

* Dummy: 1 if firm won an auction at t-1
bys firm  (datetimevar numerodaoc): gen won_t_minus_1 = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1] 
forvalues i=2/30{
bys firm  (datetimevar numerodaoc ): replace won_t_minus_1 = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1==.
}

* Dummy: 1 if firm won an auction at t-1 from same buyer
bys firm códigounidadecompradora (datetimevar numerodaoc): gen won_t_minus_1_compr = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm códigounidadecompradora (datetimevar numerodaoc): replace won_t_minus_1_compr = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_compr==.
}

* Dummy: 1 if firm won an auction at t-1 from same market (accounting for item type)
bys firm market_item (datetimevar numerodaoc): gen won_t_minus_1_market = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm market_item (datetimevar numerodaoc): replace won_t_minus_1_market = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_market==.
}

* Dummy: 1 if firm won an auction at t-1 from same item_class
bys firm códigoclasse (datetimevar numerodaoc): gen won_t_minus_1_item_class = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm códigoclasse (datetimevar numerodaoc): replace won_t_minus_1_item_class = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_item_class==.
}

* Dummy: 1 if firm won an auction at t-1 from same item_class
bys firm códigogrupo (datetimevar numerodaoc): gen won_t_minus_1_item_group = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm códigogrupo (datetimevar numerodaoc): replace won_t_minus_1_item_group = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_item_group==.
}

/* Dummy: 1 if firm won an auction at t-1 from same market
bys firm market (datetimevar numerodaoc): gen won_t_minus_1_market = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm market (datetimevar numerodaoc): replace won_t_minus_1_market = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_market==.
}
*/

* Dummy: 1 if firm is second lowest bid by item
gen sec_low_bid = 1 if m == 2
replace sec_low_bid = 0 if sec_low_bid == .

* Dummy: 1 if firm is second in the auction at time t
bys firm numerodaoc: egen second_whole_auction=max(sec_low_bid) if flagvencedor_whole_auction!=1
replace second_whole_auction = 0 if second_whole_auction==.

* Dummy: 1 if firm was second in the auction at t-1
bys firm  (datetimevar numerodaoc): gen second_t_minus_1 = second_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1] 
forvalues i=2/30{
bys firm  (datetimevar numerodaoc ): replace second_t_minus_1 = second_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & second_t_minus_1==.
}

* Dummy: 1 if firm was second in the auction at t-1 from same buyer
bys firm códigounidadecompradora (datetimevar numerodaoc): gen second_t_minus_1_compr = second_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm códigounidadecompradora (datetimevar numerodaoc): replace second_t_minus_1_compr = second_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & second_t_minus_1_compr==.
}

* Dummy: 1 if firm was second in the auction at t-1 from same market
bys firm market_item (datetimevar numerodaoc): gen second_t_minus_1_market = second_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm market_item (datetimevar numerodaoc): replace second_t_minus_1_market = second_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & second_t_minus_1_market==.
}

 

**********************************************************************************

*** 5. Generate Backlog variables

* Potential amount won by unit (reserve price) from a given buyer in the previous X days
bys auction_item: egen reserve_price=max(valorunitárioreferência)
gen amount_won=flagvencedor*reserve_price

* Backlog: Cumulative sum of amount won 
sort firm datetimevar
foreach i in 30 60 90 120 365 {
    // Cumulative sum by firm over the specified time window
    rangestat (sum) cumprof_won_`i' = amount_won, interval(datetimevar window_start_`i' window_start_2) by(firm)

    // Cumulative sum from same buyer by firm over the specified time window
    rangestat (sum) cumprof_won_`i'_compr = amount_won, interval(datetimevar window_start_`i' window_start_2) by(firm códigounidadecompradora)

    // Cumulative sum from same market by firm over the specified time window
    rangestat (sum) cumprof_won_`i'_market = amount_won, interval(datetimevar window_start_`i' window_start_2) by(firm market_item)
	
	// Cumulative sum from same market by firm over the specified time window
    rangestat (sum) cumprof_won_`i'_item_class = amount_won, interval(datetimevar window_start_`i' window_start_2) by(firm códigoclasse)
	
	// Cumulative sum from same market by firm over the specified time window
    rangestat (sum) cumprof_won_`i'_item_group = amount_won, interval(datetimevar window_start_`i' window_start_2) by(firm códigogrupo)

    // Standard deviation of the cumulative sum over the specified time window
    egen cumprof_won_`i'_std = std(cumprof_won_`i')
    egen cumprof_won_`i'_compr_std_ = std(cumprof_won_`i'_compr)
    egen cumprof_won_`i'_market_item_std = std(cumprof_won_`i'_market)
	egen cumprof_won_`i'_item_class_std = std(cumprof_won_`i'_item_class)
	egen cumprof_won_`i'_item_group_std = std(cumprof_won_`i'_item_group)

    // Ln of the cumulative sum over the specified time window
    gen lcumprof_won_`i' = ln(cumprof_won_`i')
    gen lcumprof_won_`i'_compr = ln(cumprof_won_`i'_compr)
    gen lcumprof_won_`i'_market = ln(cumprof_won_`i'_market)
	gen lcumprof_won_`i'_item_class = ln(cumprof_won_`i'_item_class)
	gen lcumprof_won_`i'_item_group = ln(cumprof_won_`i'_item_group)
}

* Backlog: Cumulative sum of bid won
foreach i in 30 60 90 120 365{
// Cumulative sum by firm over the specified time window
rangestat (sum) cum_won_`i'=flagvencedor, interval(datetimevar window_start_`i' window_start_2) by(firm)

// Cumulative sum from same buyer by firm over the specified time window
rangestat (sum) cum_won_`i'_compr=flagvencedor, interval(datetimevar window_start_`i' window_start_2) by(firm códigounidadecompradora)

// Cumulative sum from same market by firm over the specified time window
rangestat (sum) cum_won_`i'_market_item=flagvencedor, interval(datetimevar window_start_`i' window_start_2) by(firm market_item)

// Cumulative sum from same market by firm over the specified time window
rangestat (sum) cum_won_`i'_item_class=flagvencedor, interval(datetimevar window_start_`i' window_start_2) by(firm códigoclasse)

// Cumulative sum from same market by firm over the specified time window
rangestat (sum) cum_won_`i'_item_group=flagvencedor, interval(datetimevar window_start_`i' window_start_2) by(firm códigogrupo)

// Cumulative sum of  participation by firm over the specified time window
rangestat (sum) cum_part_`i'=t, interval(datetimevar window_start_`i' window_start_2) by(firm)
rangestat (sum) cum_part_`i'_compr=t, interval(datetimevar window_start_`i' window_start_2) by(firm códigounidadecompradora)
rangestat (sum) cum_part_`i'_market=t, interval(datetimevar window_start_`i' window_start_2) by(firm market_item)
rangestat (sum) cum_part_`i'_item_class=t, interval(datetimevar window_start_`i' window_start_2) by(firm códigoclasse)
rangestat (sum) cum_part_`i'_item_group=t, interval(datetimevar window_start_`i' window_start_2) by(firm códigogrupo)
gen share_won`i'=cum_won_`i'/cum_part_`i'
gen share_won`i'_compr=cum_won_`i'_compr/cum_part_`i'_compr
gen share_won`i'_market_item=cum_won_`i'_market/cum_part_`i'_market
gen share_won`i'_item_class=cum_won_`i'_item_class/cum_part_`i'_item_class
gen share_won`i'_item_group=cum_won_`i'_item_group/cum_part_`i'_item_group
}


**********************************************************************************


*** 6. Generate last bid per auction

bys auction_num: gen diff_time=(datetimevar-datetimevar[_n-1])/1000
bys auction_num: replace diff_time=-diff_time[_n+1] if diff_time==.
gen last=diff_time>0


**********************************************************************************


*** 7. Generate running variable

sort auction_num (valorunitárioproposta)

* Keep only auctions with a winner
bys auction_num: egen check_winner = total(flagvencedor)
keep if check_winner==1

* Generate a variable to store the minimum and maximum bid within each auction
bysort auction_num: egen min_bid = min(valorunitárioproposta)
bysort auction_num: egen max_bid = max(valorunitárioproposta)

* Calculate the difference between each bid and the minimum bid
sort auction_num (valorunitárioproposta)
gen bid_diff = valorunitárioproposta - min_bid
replace bid_diff = round(bid_diff, 0.01)

* Calculate the difference in bids in proportion of the minimum one
bysort auction_num: gen MV = bid_diff/min_bid
bysort auction_num: replace MV = -MV[_n+1] if flagvencedor==1


**********************************************************************************


*** 8 . Generate winning streak

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


**********************************************************************************


*** 9. Merge with firms data

merge m:1 códigofornecedor using "/cluster/work/lawecon/Projects/procurement_brazil/data/Firms_final.dta", keepusing(fornec_latitude fornec_longitude data_inicio_atividade)
gen year_start_activity = substr(data_inicio_atividade, 1, 4)
destring year_start_activity, force replace
gen age=year-year_start_activity


**********************************************************************************


* Save dataset
save "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_convite_inter.dta", replace



