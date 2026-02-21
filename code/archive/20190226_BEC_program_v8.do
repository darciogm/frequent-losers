*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* 20190226_BEC_program_v6.do
* 02/26/2019, version 8
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* This program organizes BEC-SP Database
*
* database used: BEC_2009_2018_Final.dta (Level 0 Database)
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
* 1. General Database Actions
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.1 Cleaning Unnecessary Fields
*----------------------------------------------------------------------------------------------------------------------------------------------------------


log using BEC_organizing.log, replace      																// Open log file


use BEC_2009_2018_Final.dta, clear 																			// Database used
																			
drop desccategoriaitem descclasseitem descgrupoitem descitem razãosocialfornecedor /// 
descriçãoenquadramento2 descriçãotipoendereçofornecedor descriçãoendereçofornecedor ///
descriçãobairrofornecedor descriçãopaísfornecedor descriçãounidadecompradora /// 
statusunidadecompradora descrórgãounidadecompradora endereçounidadecompradora y							// Deleting unnecessary fields


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.2. Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
save BEC_organizing.dta, replace																		// Saving new dta
clear all
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.3. Cleaning and Renaming variables
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_organizing_fields.log, replace      														// Open log file


use BEC_organizing.dta, clear 																			// Database used
																			
sort mêsanoencerramento descriçãoprocedimentocompra numerodaoc códigoitem descriçãofasesoc /// 			// Sort to prepare variables
datahrproposta

ren mêsanoencerramento m_y
label variable m_y "Month and Year"

egen t = group(m_y)
label variable t "Month and Year from 1 to 120"

ren descriçãoprocedimentocompra descrproc
egen proc = group(descrproc)
label variable proc "1 = CONVITE; 2 = DISPENSA DE LICITAÇÃO; 3 = PREGÃO ELETRÔNICO"
drop descrproc

egen price_reg = group(ataregistrodepreço)
replace price_reg = price_reg - 1
label variable price_reg "Price Registration? 0 = No; 1 = Yes"
drop ataregistrodepreço

replace códigocategoria = 0 if códigocategoria == 2
ren códigocategoria categ_item
label variable categ_item "0 = Service; 1 = Good"

ren códigoclasse class_item
label variable class_item "Class of Item Code" 

ren códigogrupo group_item
label variable group_item "Group of Item Code"

ren códigoitem item
label variable item "Item Code"

gen green_item = 0
replace green_item = 1 if seloverde == "S"
label variable green_item "Green Item? 0 = No; 1 = Yes"
drop seloverde

drop descunidadefornecimento

ren datahrproposta bid_time
label variable bid_time "Day and time of the bid"

ren descriçãogrupopropostastatus bid_status_group
label variable bid_status_group "Bid status general level"

ren descriçãopropostastatus bid_status
label variable bid_status "Bid status specific level"

ren flagvencedor bid_winner
label variable bid_winner "Bid made by the winner firm? 0 = No; 1 = Yes (not necessarily the winner bid)"

ren valorunitárioproposta bid_unit_price
label variable bid_unit_price "Bid unit price with no negotiation"

ren valorunitarionegociado bid_unit_price_negot
label variable bid_unit_price_negot "Bid unit price after negotiation"

ren valortotalproposta bid_total_value 
label variable bid_total_value "Total value bid"

ren valorunitárioreferência bid_ref_price
label variable bid_ref_price "Reference Price"

ren valormínimounitárioproposta bid_min_price
label variable bid_min_price "Minimum bid in a PO before negotiation"

ren valormáximounitárioproposta bid_max_price
label variable bid_max_price "Maximum bid in a PO before negotiation"

ren códigofornecedor firm_id
label variable firm_id "CNPJ or CPF"

ren descriçãofornecedorstatus firm_status
label variable firm_status "Firm Status in the BEC Catalog"

ren descriçãoenquadramento firm_type
label variable firm_type "Firm type: Cooperativa, Cooperativa Direito de Pref., EPP, Enquadramento não cadastrado no CAUFESP, ME, Outros"

ren códigocepfornecedor firm_zipcode
label variable firm_zipcode "Firm zipcode"

ren descriçãomunicípiofornecedor firm_city
label variable firm_city "Firm city"

ren descriçãouffornecedor firm_state
label variable firm_state "Firm state"

ren códigounidadecompradora pbu_code
label variable pbu_code "Public Buyer Unit code in the BEC Catalog"

ren cnpjunidadecompradora pbu_cnpj
label variable pbu_cnpj "Public Buyer Unit CNPJ"

ren descriçãotipounidadecompradora pbu_type_mgmt_descr
label variable pbu_type_mgmt_descr "Description Public Buyer Unit Management type"

ren descrgestãounidadecompradora pbu_mgmt_respons
label variable pbu_mgmt_respons "Responsible for the Public Buyer Unit Management"

ren descradmunidadecompradora pbu_type_mgmt
label variable pbu_type_mgmt "Public Buyer Unit Management type"

ren cepunidadecompradora pbu_zipcode
label variable pbu_zipcode "Public Buyer Unit zipcode"

ren descrmunicunidadecompradora pbu_city
label variable pbu_city "Public Buyer Unit city"


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4. Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
save BEC_organizing_fields.dta, replace																	// Saving new dta
clear all               																				// Cleaning memory
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.5. Generating variables
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_generating_variables.log, replace      													// Open log file


use BEC_organizing_fields.dta, clear 																// Database used

ren descriçãofasesoc po_phase
label variable po_phase "Purchase Order Phase"
drop if po_phase == "NÃO SE APLICA"

gen bid_id = _n
label variable bid_id "Bid ID (Primary Key)"

ren numerodaoc po
label variable po "Purchase Order Number"
																	
gen same_city_pbu_firm = 0
replace same_city_pbu_firm = 1 if firm_city == pbu_city
label variable same_city_pbu_firm "Pbu and Firm in the same city? 0 = No; 1 = Yes"
drop firm_city pbu_city

gen firm_state_sp = 0
replace firm_state_sp = 1 if firm_state == "SÃO PAULO"
label variable firm_state_sp "Firm in São Paulo State? 0 = No; 1 = Yes"
drop firm_state

drop firm_status
drop pbu_type_mgmt_descr
drop pbu_mgmt_respons


*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.6. Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
save BEC_generating_variables.dta, replace																	// Saving new dta
clear all               																				// Cleaning memory
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.7. Generating subsamples: by procedure (Convite, Dispensa, Pregao)
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_subsamples_procs.log, replace      													// Open log file


use BEC_generating_variables.dta, clear 																// Database used
keep if proc == 1
save BEC_convite.dta, replace																	// Saving new dta
clear all


use BEC_generating_variables.dta, clear 																// Database used
keep if proc == 2
save BEC_dispensa.dta, replace																	// Saving new dta
clear all


use BEC_generating_variables.dta, clear 																// Database used
keep if proc == 3
save BEC_pregao.dta, replace																	// Saving new dta
clear all

capture log close       																				// Close existing log files

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2. Preparing Database Convite
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
* 2.1. Preliminary Actions
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_convite.log, replace      																// Open log file
use BEC_convite.dta, clear 																			// Database used

tostring item, replace

gen po_item_id = po + item
gen bid_count = 1

sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1
replace bid_count = 1
*drop unique_firm
rename nvals unique_firm
save BEC_convite.dta, replace



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2.2. Collapsing bid_price 
*----------------------------------------------------------------------------------------------------------------------------------------------------------
collapse (sum) n_firms_props=unique_firm n_bids_props=bid_count (min) min_bid_price_props=bid_unit_price (max) max_bid_price_props=bid_unit_price (mean) mean_bid_price_props=bid_unit_price (median) median_bid_price_props=bid_unit_price (sd) sd_bid_price_props=bid_unit_price (semean) semean_bid_price_props=bid_unit_price, by(po_item_id)

gen n_firms_bids=n_firms_props
gen n_bids_bids=n_bids_props
gen min_bid_price_bids=min_bid_price_props
gen max_bid_price_bids=max_bid_price_props
gen mean_bid_price_bids=mean_bid_price_props
gen median_bid_price_bids=median_bid_price_props
gen sd_bid_price_bids=sd_bid_price_props
gen semean_bid_price_bids=semean_bid_price_props


save BEC_convite_collapse_1.dta, replace																		// Saving new dta
clear all
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2.3. Appending BEC_convite and Collapsed dta
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

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2.4. Geocoding PBU and firm addresses
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2.4.1. Geocoding using Base 1: https://www.base-dados-cep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_convite_collapse_4.log, replace      																// Open log file


use Geocoding_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_pbu_zipcode.dta, replace

use BEC_convite_final_3.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_pbu_zipcode.dta
*ren _merge _merge_1
drop _merge
drop if po == ""


save BEC_convite_final_4.dta, replace

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
log using BEC_convite_collapse_5.log, replace      																// Open log file


use Geocoding_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_firm_zipcode.dta, replace

use BEC_convite_final_4.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_firm_zipcode.dta
*ren _merge _merge_2
drop _merge

order m_y po_item_id, first
order latit_pbu longit_pbu latit_firm longit_firm, last

save BEC_convite_final_5.dta, replace

*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2.4.2. Geocoding using Base 2: http://www.qualocep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_convite_collapse_6.log, replace      																// Open log file


use Geocoding_qualcep_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_qualcep_pbu_zipcode.dta, replace

use BEC_convite_final_5.dta, clear 																			// Database used
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



save BEC_convite_final_6.dta, replace

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
log using BEC_convite_collapse_7.log, replace      																// Open log file


use Geocoding_qualcep_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_qualcep_firm_zipcode.dta, replace

use BEC_convite_final_6.dta, clear 																			// Database used
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

save BEC_convite_final_append.dta, replace


clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"


use BEC_convite_final_append.dta, clear
collapse (min) bid_unit_price_negot_min_props=bid_unit_price_negot bid_ref_price_min_props=bid_ref_price (max) bid_unit_price_negot_max_props=bid_unit_price_negot bid_ref_price_max_props=bid_ref_price, by(po_item_id)

gen bid_unit_price_negot_min_bids=bid_unit_price_negot_min_props
gen bid_ref_price_min_bids=bid_ref_price_min_props
gen bid_unit_price_negot_max_bids=bid_unit_price_negot_max_props
gen bid_ref_price_max_bids=bid_ref_price_max_props


save BEC_convite_collapsed_ref_price.dta, replace
sort po_item_id

use BEC_convite_final_append.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_convite_collapsed_ref_price.dta
*ren _merge _merge_20
drop _merge
save BEC_convite_final_append.dta, replace



*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close


*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 3. Preparing Database dispensa
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
* 3.1. Preliminary Actions
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_dispensa.log, replace      																// Open log file
use BEC_dispensa.dta, clear 																			// Database used

tostring item, replace

gen po_item_id = po + item
gen bid_count = 1

sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1
replace bid_count = 1
*drop unique_firm
rename nvals unique_firm
save BEC_dispensa.dta, replace



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 3.2. Collapsing bid_price 
*----------------------------------------------------------------------------------------------------------------------------------------------------------
collapse (sum) n_firms_bids=unique_firm n_bids_bids=bid_count (min) min_bid_price_bids=bid_unit_price (max) max_bid_price_bids=bid_unit_price (mean) mean_bid_price_bids=bid_unit_price (median) median_bid_price_bids=bid_unit_price (sd) sd_bid_price_bids=bid_unit_price (semean) semean_bid_price_bids=bid_unit_price, by(po_item_id)

gen n_firms_props=n_firms_bids
gen n_bids_props=n_bids_bids
gen min_bid_price_props=min_bid_price_bids
gen max_bid_price_props=max_bid_price_bids
gen mean_bid_price_props=mean_bid_price_bids
gen median_bid_price_props=median_bid_price_bids
gen sd_bid_price_props=sd_bid_price_bids
gen semean_bid_price_props=semean_bid_price_bids


save BEC_dispensa_collapse_1.dta, replace																		// Saving new dta
clear all
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 3.3. Appending BEC_dispensa and Collapsed dta
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Appending Collapse_1: bid_unit_price --> info about po
log using BEC_dispensa_collapse_1.log, replace      																// Open log file

use BEC_dispensa_collapse_1.dta, clear 																			// Database used
sort po_item_id
save BEC_dispensa_collapse_1.dta, replace

use BEC_dispensa.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_dispensa_collapse_1.dta
drop bid_count unique_firm
drop _merge
save BEC_dispensa_final_1.dta, replace																		// Saving new dta
clear all
capture log close       


* Appending Collapse_2: bid_winner --> po (Successful or not?)
log using BEC_dispensa_collapse_2.log, replace      																// Open log file

use BEC_dispensa_final_1.dta, clear 																			// Database used
sort po_item_id
collapse (sum) sum_po_winner=bid_winner (max) po_winner=bid_winner, by(po_item_id)
save BEC_dispensa_collapse_2.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_dispensa_collapse_2.dta, clear 																			// Database used
sort po_item_id
save BEC_dispensa_collapse_2.dta, replace

use BEC_dispensa_final_1.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_dispensa_collapse_2.dta
drop _merge
save BEC_dispensa_final_2.dta, replace																		// Saving new dta
clear all
capture log close    


* Appending Collapse_3: bid_time --> procedure time
clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_dispensa_collapse_3.log, replace      																// Open log file

use BEC_dispensa_final_2.dta, clear 																			// Database used
sort po_item_id
generate double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time
collapse (min) bid_time_min=bid_time_date (max) bid_time_max=bid_time_date, by(po_item_id)
save BEC_dispensa_collapse_3.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_dispensa_collapse_3.dta, clear 																			// Database used
sort po_item_id
save BEC_dispensa_collapse_3.dta, replace

use BEC_dispensa_final_2.dta, clear 																			// Database used
sort po_item_id


merge m:1 po_item_id using BEC_dispensa_collapse_3.dta
drop _merge
gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save BEC_dispensa_final_3.dta, replace																		// Saving new dta
clear all
capture log close    

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 3.4. Geocoding PBU and firm addresses
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 3.4.1. Geocoding using Base 1: https://www.base-dados-cep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_dispensa_collapse_4.log, replace      																// Open log file


use Geocoding_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_pbu_zipcode.dta, replace

use BEC_dispensa_final_3.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_pbu_zipcode.dta
*ren _merge _merge_1
drop _merge
drop if po == ""


save BEC_dispensa_final_4.dta, replace

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
log using BEC_dispensa_collapse_5.log, replace      																// Open log file


use Geocoding_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_firm_zipcode.dta, replace

use BEC_dispensa_final_4.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_firm_zipcode.dta
*ren _merge _merge_2
drop _merge

order m_y po_item_id, first
order latit_pbu longit_pbu latit_firm longit_firm, last

save BEC_dispensa_final_5.dta, replace

*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 3.4.2. Geocoding using Base 2: http://www.qualocep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_dispensa_collapse_6.log, replace      																// Open log file


use Geocoding_qualcep_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_qualcep_pbu_zipcode.dta, replace

use BEC_dispensa_final_5.dta, clear 																			// Database used
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



save BEC_dispensa_final_6.dta, replace

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
log using BEC_dispensa_collapse_7.log, replace      																// Open log file


use Geocoding_qualcep_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_qualcep_firm_zipcode.dta, replace

use BEC_dispensa_final_6.dta, clear 																			// Database used
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

save BEC_dispensa_final_append.dta, replace


clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"


use BEC_dispensa_final_append.dta, clear
collapse (min) bid_unit_price_negot_min_bids=bid_unit_price_negot bid_ref_price_min_bids=bid_ref_price (max) bid_unit_price_negot_max_bids=bid_unit_price_negot bid_ref_price_max_bids=bid_ref_price, by(po_item_id)

gen bid_unit_price_negot_min_props=bid_unit_price_negot_min_bids
gen bid_ref_price_min_props=bid_ref_price_min_bids
gen bid_unit_price_negot_max_props=bid_unit_price_negot_max_bids
gen =bid_ref_price_max_props=bid_ref_price_max_bids



save BEC_dispensa_collapsed_ref_price.dta, replace
sort po_item_id

use BEC_dispensa_final_append.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_dispensa_collapsed_ref_price.dta
*ren _merge _merge_20
drop _merge
save BEC_dispensa_final_append.dta, replace

*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close


*----------------------------------------------------------------------------------------------------------------------------------------------------------
*--------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4. Preparing Database Pregao
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.1. Pregao subsample: LANCES
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
* 4.1.1. Subsample Extraction
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_pregao_subsamples.log, replace      																// Open log file

use BEC_pregao.dta, clear 																// Database used
keep if po_phase == "LANCES"
save BEC_pregao_lances.dta, replace																	// Saving new dta
clear all


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.1.2. Preliminary actions
*----------------------------------------------------------------------------------------------------------------------------------------------------------
use BEC_pregao_lances.dta, clear 																			// Database used

tostring item, replace

gen po_item_id = po + item
gen bid_count = 1

sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1
replace bid_count = 1
*drop unique_firm
rename nvals unique_firm
save BEC_pregao_lances.dta, replace



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.1.3. Collapsing bid_price 
*----------------------------------------------------------------------------------------------------------------------------------------------------------

collapse (sum) n_firms_bids=unique_firm n_bids_bids=bid_count (min) min_bid_price_bids=bid_unit_price (max) max_bid_price_bids=bid_unit_price (mean) mean_bid_price_bids=bid_unit_price (median) median_bid_price_bids=bid_unit_price (sd) sd_bid_price_bids=bid_unit_price (semean) semean_bid_price_bids=bid_unit_price, by(po_item_id)

gen n_firms_props=n_firms_bids
gen n_bids_props=n_bids_bids
gen min_bid_price_props=min_bid_price_bids
gen max_bid_price_props=max_bid_price_bids
gen mean_bid_price_props=mean_bid_price_bids
gen median_bid_price_props=median_bid_price_bids
gen sd_bid_price_props=sd_bid_price_bids
gen semean_bid_price_props=semean_bid_price_bids

save BEC_pregao_lances_collapse_1.dta, replace																		// Saving new dta
clear all
capture log close       																				// Close existing log files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.1.4. Appending BEC_pregao_lances and Collapsed dta
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Appending Collapse_1: bid_unit_price --> info about po
log using BEC_pregao_lances_collapse_1.log, replace      																// Open log file

use BEC_pregao_lances_collapse_1.dta, clear 																			// Database used
sort po_item_id
save BEC_pregao_lances_collapse_1.dta, replace

use BEC_pregao_lances.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_pregao_lances_collapse_1.dta
drop bid_count unique_firm
drop _merge
save BEC_pregao_lances_final_1.dta, replace																		// Saving new dta
clear all
capture log close       


* Appending Collapse_2: bid_winner --> po (Successful or not?)
log using BEC_pregao_lances_collapse_2.log, replace      																// Open log file

use BEC_pregao_lances_final_1.dta, clear 																			// Database used
sort po_item_id
collapse (sum) sum_po_winner=bid_winner (max) po_winner=bid_winner, by(po_item_id)
save BEC_pregao_lances_collapse_2.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_pregao_lances_collapse_2.dta, clear 																			// Database used
sort po_item_id
save BEC_pregao_lances_collapse_2.dta, replace

use BEC_pregao_lances_final_1.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_pregao_lances_collapse_2.dta
drop _merge
save BEC_pregao_lances_final_2.dta, replace																		// Saving new dta
clear all
capture log close    


* Appending Collapse_3: bid_time --> procedure time
clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_lances_collapse_3.log, replace      																// Open log file

use BEC_pregao_lances_final_2.dta, clear 																			// Database used
sort po_item_id
generate double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time
collapse (min) bid_time_min=bid_time_date (max) bid_time_max=bid_time_date, by(po_item_id)
save BEC_pregao_lances_collapse_3.dta, replace																		// Saving new dta
clear all
capture log close


use BEC_pregao_lances_collapse_3.dta, clear 																			// Database used
sort po_item_id
save BEC_pregao_lances_collapse_3.dta, replace

use BEC_pregao_lances_final_2.dta, clear 																			// Database used
sort po_item_id


merge m:1 po_item_id using BEC_pregao_lances_collapse_3.dta
drop _merge
gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save BEC_pregao_lances_final_3.dta, replace																		// Saving new dta
clear all
capture log close    

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.1.5. Geocoding PBU and firm addresses
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.1.5.1. Geocoding using Base 1: https://www.base-dados-cep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_lances_collapse_4.log, replace      																// Open log file


use Geocoding_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_pbu_zipcode.dta, replace

use BEC_pregao_lances_final_3.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_pbu_zipcode.dta
*ren _merge _merge_1
drop _merge
drop if po == ""


save BEC_pregao_lances_final_4.dta, replace

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
log using BEC_pregao_lances_collapse_5.log, replace      																// Open log file


use Geocoding_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_firm_zipcode.dta, replace

use BEC_pregao_lances_final_4.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_firm_zipcode.dta
*ren _merge _merge_2
drop _merge

order m_y po_item_id, first
order latit_pbu longit_pbu latit_firm longit_firm, last

save BEC_pregao_lances_final_5.dta, replace



*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4.1.5.2. Geocoding using Base 2: http://www.qualocep.com/
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*PBU Geocoding

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
log using BEC_pregao_lances_collapse_6.log, replace      																// Open log file


use Geocoding_qualcep_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_qualcep_pbu_zipcode.dta, replace

use BEC_pregao_lances_final_5.dta, clear 																			// Database used
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



save BEC_pregao_lances_final_6.dta, replace

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
log using BEC_pregao_lances_collapse_7.log, replace      																// Open log file


use Geocoding_qualcep_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_qualcep_firm_zipcode.dta, replace

use BEC_pregao_lances_final_6.dta, clear 																			// Database used
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

save BEC_pregao_lances_final_append.dta, replace


clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"


use BEC_pregao_lances_final_append.dta, clear

collapse (min) bid_unit_price_negot_min_bids=bid_unit_price_negot bid_ref_price_min_bids=bid_ref_price (max) bid_unit_price_negot_max_bids=bid_unit_price_negot bid_ref_price_max_bids=bid_ref_price, by(po_item_id)

gen bid_unit_price_negot_min_props=bid_unit_price_negot_min_bids
gen bid_ref_price_min_props=bid_ref_price_min_bids
gen bid_unit_price_negot_max_props=bid_unit_price_negot_max_bids
gen =bid_ref_price_max_props=bid_ref_price_max_bids

save BEC_pregao_lances_collapsed_ref_price.dta, replace
sort po_item_id

use BEC_pregao_lances_final_append.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_pregao_lances_collapsed_ref_price.dta
*ren _merge _merge_20
drop _merge
save BEC_pregao_lances_final_append.dta, replace


*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close


*----------------------------------------------------------------------------------------------------------------------------------------------------------
*--------------------------------------------------------------------------------------------------------------------------------------------------


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

collapse (sum) n_firms_props=unique_firm n_bids_props=bid_count (min) min_bid_price_props=bid_unit_price (max) max_bid_price_props=bid_unit_price (mean) mean_bid_price_props=bid_unit_price (median) median_bid_price_props=bid_unit_price (sd) sd_bid_price_props=bid_unit_price (semean) semean_bid_price_props=bid_unit_price, by(po_item_id)

gen n_firms_bids=n_firms_props
gen n_bids_bids=n_bids_props
gen min_bid_price_bids=min_bid_price_props
gen max_bid_price_bids=max_bid_price_props
gen mean_bid_price_bids=mean_bid_price_props
gen median_bid_price_bids=median_bid_price_props
gen sd_bid_price_bids=sd_bid_price_props
gen semean_bid_price_bids=semean_bid_price_props


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

save BEC_pregao_propostas_final_append.dta, replace

clear all
capture log close
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"


use BEC_pregao_propostas_final_append.dta, clear

collapse (min) bid_unit_price_negot_min_props=bid_unit_price_negot bid_ref_price_min_props=bid_ref_price (max) bid_unit_price_negot_max_props=bid_unit_price_negot bid_ref_price_max_props=bid_ref_price, by(po_item_id)

gen bid_unit_price_negot_min_bids=bid_unit_price_negot_min_props
gen bid_ref_price_min_bids=bid_ref_price_min_props
gen bid_unit_price_negot_max_bids=bid_unit_price_negot_max_props
gen bid_ref_price_max_bids=bid_ref_price_max_props

save BEC_pregao_propostas_collapsed_ref_price.dta, replace
sort po_item_id

use BEC_pregao_propostas_final_append.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_pregao_propostas_collapsed_ref_price.dta
*ren _merge _merge_20
drop _merge
save BEC_pregao_propostas_final_append.dta, replace


*ssc install vincenty
*ssc install geonear
*ssc install geodist
*ssc install georoute

clear all
capture log close


*----------------------------------------------------------------------------------------------------------------------------------------------------------
*--------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 5. Final File: Appending Files
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 5.1. Introduction: preparing files
*----------------------------------------------------------------------------------------------------------------------------------------------------------

version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
												
*----------------------------------------------------------------------------------------------------------------------------------------------------------

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL" 													// Defining Main Directory 
use BEC_convite_final_append.dta, clear
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/Appending Files" 													// Defining Main Directory 
save File1.dta, replace

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL" 													// Defining Main Directory 
use BEC_dispensa_final_append.dta, clear
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/Appending Files" 													// Defining Main Directory 
save File2.dta, replace

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL" 													// Defining Main Directory 
use BEC_pregao_lances_final_append.dta, clear
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/Appending Files" 													// Defining Main Directory 
save File3.dta, replace

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL" 													// Defining Main Directory 
use BEC_pregao_propostas_final_append.dta, clear
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/Appending Files" 													// Defining Main Directory 
save File4.dta, replace

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 5.2. Appending Files
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/Appending Files" 													// Defining Main Directory
										
*----------------------------------------------------------------------------------------------------------------------------------------------------------

use File1.dta, clear
append using File2.dta
append using File3.dta
append using File4.dta
save Final_Database_Thesis.dta, replace

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
