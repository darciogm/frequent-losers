
use "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_convite_inter.dta", clear

*** 6. Generate Market variable

drop auction_id market 

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
sort auction_id códigoclasse firm

* Initialize market ID with firm_id values
gen market_item_2 = firm

* Recursive merging: Iteratively update market ID based on shared auctions and item types
local changes = 1

while `changes' > 0 {
    * Sort data by auction_id, item_type, and market before each iteration
    sort auction_id códigoclasse market_item_2

    * Store the previous market values to check for changes
    gen old_market = market_item_2

    * Update market ID to propagate minimum ID across firms in the same auction and item type
    by auction_id códigoclasse: replace market_item_2 = min(market_item_2[_n-1], market_item_2[_n+1], market_item_2) if _n > 1 | _n < _N

    * Count real changes by comparing old and new market values
    quietly count if market_item_2 != old_market
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

* Dummy: 1 if firm won an auction at t-1 from same buyer
bys firm market_item (datetimevar numerodaoc): gen won_t_minus_1_market_item = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm market_item (datetimevar numerodaoc): replace won_t_minus_1_market_item = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_market_item==.
}

* Dummy: 1 if firm won an auction at t-1 from same buyer
bys firm market_item_2 (datetimevar numerodaoc): gen won_t_minus_1_market_item_2 = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm market_item_2 (datetimevar numerodaoc): replace won_t_minus_1_market_item_2 = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_market_item_2==.
}

* Dummy: 1 if firm won an auction at t-1 from same buyer
bys firm market (datetimevar numerodaoc): gen won_t_minus_1_market = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1]
forvalues i=2/30{
bys firm market (datetimevar numerodaoc): replace won_t_minus_1_market = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_market==.
}

save "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_convite_inter.dta", replace
