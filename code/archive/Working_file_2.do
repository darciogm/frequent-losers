* Working file

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2 Pregao subsample: ANÁLISE DE PROPOSTAS
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL" 													// Defining Main Directory 
												
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2.1. Subsample Extraction
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_pregao_subsamples.log, replace      																// Open log file

use BEC_pregao.dta, clear 																// Database used
keep if po_phase == "ANÁLISE DE PROPOSTAS"
save BEC_pregao_propostas.dta, replace																	// Saving new dta
clear all

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2.2. Preliminary actions
*----------------------------------------------------------------------------------------------------------------------------------------------------------
use BEC_pregao_propostas.dta, clear 																			// Database used

tostring item, replace

gen po_item_id = po + item
gen bid_count = 1

sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1
replace bid_count = 1
*drop unique_firm
rename nvals unique_firm
save BEC_pregao_propostas.dta, replace



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2.3. Collapsing bid_price 
*----------------------------------------------------------------------------------------------------------------------------------------------------------
collapse (sum) n_firms=unique_firm n_bids=bid_count (min) min_bid_price=bid_unit_price (max) max_bid_price=bid_unit_price (mean) mean_bid_price=bid_unit_price (median) median_bid_price=bid_unit_price (sd) sd_bid_price=bid_unit_price (semean) semean_bid_price=bid_unit_price, by(po_item_id)
save BEC_pregao_propostas_collapse_1.dta, replace																		// Saving new dta
clear all
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2.4. Appending BEC_pregao_propostas and Collapsed dta
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Appending Collapse_1: bid_unit_price --> info about po
log using BEC_pregao_propostas_collapse_1.log, replace      																// Open log file

use BEC_pregao_propostas_collapse_1.dta, clear 																			// Database used
sort po_item_id
save BEC_pregao_propostas_collapse_1.dta, replace

use BEC_pregao_propostas.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_pregao_propostas_collapse_1.dta
drop bid_count unique_firm
drop _merge
save BEC_pregao_propostas_final_1.dta, replace																		// Saving new dta
clear all
capture log close       


* Appending Collapse_2: bid_winner --> po (Successful or not?)
log using BEC_pregao_propostas_collapse_2.log, replace      																// Open log file

use BEC_pregao_propostas_final_1.dta, clear 																			// Database used
sort po_item_id
collapse (sum) sum_po_winner=bid_winner (max) po_winner=bid_winner, by(po_item_id)
save BEC_pregao_propostas_collapse_2.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_pregao_propostas_collapse_2.dta, clear 																			// Database used
sort po_item_id
save BEC_pregao_propostas_collapse_2.dta, replace

use BEC_pregao_propostas_final_1.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_pregao_propostas_collapse_2.dta
drop _merge
save BEC_pregao_propostas_final_2.dta, replace																		// Saving new dta
clear all
capture log close    


* Appending Collapse_3: bid_time --> procedure time
clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_propostas_collapse_3.log, replace      																// Open log file

use BEC_pregao_propostas_final_2.dta, clear 																			// Database used
sort po_item_id
generate double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time
collapse (min) bid_time_min=bid_time_date (max) bid_time_max=bid_time_date, by(po_item_id)
save BEC_pregao_propostas_collapse_3.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_pregao_propostas_collapse_3.dta, clear 																			// Database used
sort po_item_id
save BEC_pregao_propostas_collapse_3.dta, replace

use BEC_pregao_propostas_final_2.dta, clear 																			// Database used
sort po_item_id


merge m:1 po_item_id using BEC_pregao_propostas_collapse_3.dta
drop _merge
gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save BEC_pregao_propostas_final_3.dta, replace																		// Saving new dta
clear all
capture log close    

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2.5. Geocoding PBU and firm addresses
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2.5.1. Geocoding using Base 1: https://www.base-dados-cep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_propostas_collapse_4.log, replace      																// Open log file


use Geocoding_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_pbu_zipcode.dta, replace

use BEC_pregao_propostas_final_3.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_pbu_zipcode.dta
*ren _merge _merge_1
drop _merge
drop if po == ""


save BEC_pregao_propostas_final_4.dta, replace

*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close


*Firm Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_propostas_collapse_5.log, replace      																// Open log file


use Geocoding_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_firm_zipcode.dta, replace

use BEC_pregao_propostas_final_4.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_firm_zipcode.dta
*ren _merge _merge_2
drop _merge

order m_y po_item_id, first
order latit_pbu longit_pbu latit_firm longit_firm, last

save BEC_pregao_propostas_final_5.dta, replace

*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.2.5.2. Geocoding using Base 2: http://www.qualocep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_propostas_collapse_6.log, replace      																// Open log file


use Geocoding_qualcep_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_qualcep_pbu_zipcode.dta, replace

use BEC_pregao_propostas_final_5.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_qualcep_pbu_zipcode.dta
*ren _merge _merge_10
drop _merge
drop if po == ""

gen latit_pbu_qualcep_numeric = real(latit_pbu_qualcep)
drop latit_pbu_qualcep
ren latit_pbu_qualcep_numeric latit_pbu_qualcep

gen longit_pbu_qualcep_numeric = real(longit_pbu_qualcep)
drop longit_pbu_qualcep
ren longit_pbu_qualcep_numeric longit_pbu_qualcep



save BEC_pregao_propostas_final_6.dta, replace

*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close


*Firm Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_propostas_collapse_7.log, replace      																// Open log file


use Geocoding_qualcep_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_qualcep_firm_zipcode.dta, replace

use BEC_pregao_propostas_final_6.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_qualcep_firm_zipcode.dta
*ren _merge _merge_20
drop _merge
drop if po == ""

gen latit_firm_qualcep_numeric = real(latit_firm_qualcep)
drop latit_firm_qualcep
ren latit_firm_qualcep_numeric latit_firm_qualcep

gen longit_firm_qualcep_numeric = real(longit_firm_qualcep)
drop longit_firm_qualcep
ren longit_firm_qualcep_numeric longit_firm_qualcep

replace latit_pbu_qualcep = latit_pbu if latit_pbu_qualcep == .
replace longit_pbu_qualcep = latit_pbu if longit_pbu_qualcep == .
replace latit_firm_qualcep = latit_firm if latit_firm_qualcep == .
replace longit_firm_qualcep = longit_firm if longit_firm_qualcep == .

drop latit_pbu longit_pbu latit_firm longit_firm area_cidade_km2_pbu area_cidade_km2_firm id_pbu id_firm

ren latit_pbu_qualcep latit_pbu
ren longit_pbu_qualcep longit_pbu
ren latit_firm_qualcep latit_firm
ren longit_firm_qualcep longit_firm

sort m_y po_item_id bid_time

gen bids_phase = 0
label variable bids_phase "Bids phase? 1 = Bids; 0 = Pre-Bids"

save BEC_pregao_propostas_final_append.dta, replace

*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close


*----------------------------------------------------------------------------------------------------------------------------------------------------------
*--------------------------------------------------------------------------------------------------------------------------------------------------
