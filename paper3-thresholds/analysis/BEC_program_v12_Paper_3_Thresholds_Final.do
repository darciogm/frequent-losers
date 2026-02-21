*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* 03/05/2019, version 12
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* This program organizes BEC-SP Database
*
* Database used: BEC_2009_2018_Final.dta (Level 0 Database)
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
* 1. General Database Actions: Cleaning and Renaming Variables
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.1 Cleaning and Renaming Names
*----------------------------------------------------------------------------------------------------------------------------------------------------------

log using BEC_organizing.log, replace      																// Open log file

use BEC_2009_2018_Final.dta, clear 																			// Database used
															
drop desccategoriaitem descclasseitem descgrupoitem descitem razãosocialfornecedor /// 
descriçãoenquadramento2 descriçãotipoendereçofornecedor descriçãoendereçofornecedor ///
descriçãobairrofornecedor descriçãopaísfornecedor descriçãounidadecompradora /// 
statusunidadecompradora descrórgãounidadecompradora endereçounidadecompradora 						// Deleting unnecessary fields																

ren date1 m_y
label variable m_y "Month and Year"

egen t = group(m_y)
label variable t "Month and Year from 1 to 120"

ren descriçãoprocedimentocompra descrproc
egen proc = group(descrproc)
label variable proc "1 = CONVITE; 2 = DISPENSA DE LICITAÇÃO; 3 = PREGÃO ELETRÔNICO"

egen price_reg = group(ataregistrodepreço)
replace price_reg = price_reg - 1
label variable price_reg "Price Registration? 0 = No; 1 = Yes"

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

ren descriçãofasesoc po_phase
label variable po_phase "Purchase Order Phase"

gen bid_id = _n
label variable bid_id "Bid ID (Primary Key)"

ren numerodaoc po
label variable po "Purchase Order Number"
																	
gen same_city_pbu_firm = 0
replace same_city_pbu_firm = 1 if firm_city == pbu_city
label variable same_city_pbu_firm "Pbu and Firm in the same city? 0 = No; 1 = Yes"

gen firm_state_sp = 0
replace firm_state_sp = 1 if firm_state == "SÃO PAULO"
label variable firm_state_sp "Firm in São Paulo State? 0 = No; 1 = Yes"

drop firm_state firm_status pbu_type_mgmt_descr pbu_mgmt_respons seloverde ataregistrodepreço descrproc descunidadefornecimento firm_city pbu_city

tostring item, replace

gen po_item_id = po + item + po_phase
gen bid_count = 1

gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time

gen date = dofm(m_y)
gen year = year(date)

drop date

sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1

rename nvals unique_firm

save BEC_2009_2018_Final_Consolidado.dta, replace


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.2. Collapsing bid prices, #firms, #bids, bid winner, bid time 
*----------------------------------------------------------------------------------------------------------------------------------------------------------

collapse (sum) n_firms=unique_firm n_bids=bid_count po_winner_sum=bid_winner /// 
(min) bid_price_min=bid_unit_price bid_time_min=bid_time_date bid_unit_price_negot_min=bid_unit_price_negot bid_ref_price_min=bid_ref_price /// 
(max) bid_price_max=bid_unit_price po_winner_max=bid_winner bid_time_max=bid_time_date bid_unit_price_negot_max=bid_unit_price_negot bid_ref_price_max=bid_ref_price /// 
(mean) bid_price_mean=bid_unit_price /// 
(median) bid_price_median=bid_unit_price /// 
(sd) bid_price_sd=bid_unit_price /// 
(semean) bid_price_semean=bid_unit_price, by(po_item_id)

save BEC_collapse_1.dta, replace																		// Saving new dta
clear all

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.3. Appending Collapse 1
*----------------------------------------------------------------------------------------------------------------------------------------------------------

use BEC_collapse_1.dta, clear 																			// Database used
sort po_item_id
save BEC_collapse_1.dta, replace

use BEC_2009_2018_Final_Consolidado.dta, clear 																			// Database used
sort po_item_id

merge m:1 po_item_id using BEC_collapse_1.dta
drop _merge

gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save BEC_2009_2018_Final_Consolidado.dta, replace																		// Saving new dta
       

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4. Geocoding PBU and firm addresses: DADOS CEP DATABASE (https://www.base-dados-cep.com/)
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4.1. PBU Geocoding
*----------------------------------------------------------------------------------------------------------------------------------------------------------

clear all
use Geocoding_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_pbu_zipcode.dta, replace

use BEC_2009_2018_Final_Consolidado.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_pbu_zipcode.dta
drop _merge
drop if po == ""

save BEC_2009_2018_Final_Consolidado.dta, replace

clear all

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4.2. Firm Geocoding
*----------------------------------------------------------------------------------------------------------------------------------------------------------

use Geocoding_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_firm_zipcode.dta, replace

use BEC_2009_2018_Final_Consolidado.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_firm_zipcode.dta
drop _merge
drop if po == ""

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.5. Calculating Distance between Firm and PBUs
*----------------------------------------------------------------------------------------------------------------------------------------------------------

geodist latit_pbu longit_pbu latit_firm longit_firm, generate(dist)

save BEC_2009_2018_Final_Consolidado.dta, replace

clear all
capture log close

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2. Paper 3: Threshold, Dispensa, Convite e Pregao
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2.1. Extracting subsample: threshold around july 2018 and values to compare (counterfactual)
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
																			
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using Paper_3.log, replace


cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL"
use BEC_2009_2018_Final_Consolidado.dta, clear
keep if bid_winner == 1
sort m_y po item po_phase bid_time
drop if bid_status_group == "INVÁLIDO"
gen po_and_item = po + item
sort po_and_item

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/Paper_3"
save BEC_2009_2018_Final_Consolidado_Paper_3.dta, replace

collapse (min) bid_unit_price_final_min= bid_unit_price , by(po_and_item)
sort po_and_item
save Collapse_2.dta, replace

use BEC_2009_2018_Final_Consolidado_Paper_3.dta, clear
merge m:1 po_and_item using Collapse_2.dta
drop _merge
keep if bid_unit_price_final_min==bid_unit_price
duplicates drop po_and_item, force

save BEC_2009_2018_Final_Consolidado_Paper_3.dta, replace

clear all
capture log close
