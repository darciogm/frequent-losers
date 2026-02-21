*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* BEC_convite.do
* 02/21/2019, version 1
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* This program organizes BEC-SP Database: subsample BEC_convite
*
* database used: BEC_convite.dta (Level 0 Database)
*
* key variables: 	- id (Primary Key)
*					- po (Purchase Order: OC)
*					- pb_cnpj (Public Buyer CNPJ)
*					- fr_cnpj (Firm CNPJ)						
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
* Preparing Database Convite
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_convite.log, replace      																// Open log file
use BEC_convite.dta, clear 																			// Database used

tostring item, replace
replace po_item_id = po + item
sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1
replace bid_count = 1
drop unique_firm
rename nvals unique_firm
save BEC_convite.dta, replace



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
collapse (sum) n_firms=unique_firm n_bids=bid_count (min) min_bid_price=bid_unit_price (max) max_bid_price=bid_unit_price (mean) mean_bid_price=bid_unit_price (median) median_bid_price=bid_unit_price (sd) sd_bid_price=bid_unit_price (semean) semean_bid_price=bid_unit_price, by(po_item_id)
save BEC_convite_collapse_1.dta, replace																		// Saving new dta
clear all
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Appending BEC_convite and Collapsed dta
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Appending Collapse_1: bid_unit_price --> info about po
log using BEC_convite_collapse_1.log, replace      																// Open log file

use BEC_convite_collapse_1.dta, clear 																			// Database used
sort po_item_id
save BEC_convite_collapse_1.dta, replace

use BEC_convite.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_convite_collapse_1.dta
drop bid_count unique_firm
drop _merge
save BEC_convite_final_1.dta, replace																		// Saving new dta
clear all
capture log close       


* Appending Collapse_2: bid_winner --> po (Successful or not?)
log using BEC_convite_collapse_2.log, replace      																// Open log file

use BEC_convite_final_1.dta, clear 																			// Database used
sort po_item_id
collapse (sum) sum_po_winner=bid_winner (max) po_winner=bid_winner, by(po_item_id)
save BEC_convite_collapse_2.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_convite_collapse_2.dta, clear 																			// Database used
sort po_item_id
save BEC_convite_collapse_2.dta, replace

use BEC_convite_final_1.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_convite_collapse_2.dta
drop _merge
save BEC_convite_final_2.dta, replace																		// Saving new dta
clear all
capture log close    


* Appending Collapse_3: bid_time --> procedure time
clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_convite_collapse_3.log, replace      																// Open log file

use BEC_convite_final_2.dta, clear 																			// Database used
sort po_item_id
generate double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time
collapse (min) bid_time_min=bid_time_date (max) bid_time_max=bid_time_date, by(po_item_id)
save BEC_convite_collapse_3.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_convite_collapse_3.dta, clear 																			// Database used
sort po_item_id
save BEC_convite_collapse_3.dta, replace

use BEC_convite_final_2.dta, clear 																			// Database used
sort po_item_id


merge m:1 po_item_id using BEC_convite_collapse_3.dta
drop _merge
gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save BEC_convite_final_3.dta, replace																		// Saving new dta
clear all
capture log close    
