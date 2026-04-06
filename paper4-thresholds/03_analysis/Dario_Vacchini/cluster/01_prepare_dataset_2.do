
* Import intermediate
use "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_convite_inter.dta", clear

**********************************************************************************


*** 8. Keep only first and second bids (winner and looser)

* Keep only winner and first looser
sort auction_num   m
keep if m<3
bys auction_num: egen max_m=max(m) 
keep if max_m==2

**********************************************************************************


*** 9. Drop problematic auctions and bids

drop if MV ==.
drop if MV == 0
bysort auction_num: gen e =_n
bysort auction_num: egen max_e = max(e)
drop if max_e == 1

// Problematic: lowest bid of the auction = 0, not lowest bid that wins the auction, two firms make the same bid


**********************************************************************************
* Save
save "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_convite_winner_looser.dta", replace
