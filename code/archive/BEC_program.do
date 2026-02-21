*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* BEC_organizing.do
* 12/19/2018, version 1
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
* 1. Cleaning Unnecessary Fields
*----------------------------------------------------------------------------------------------------------------------------------------------------------
log using BEC_organizing.log, replace      																// Open log file


use BEC_2009_2018_Final.dta, clear 																			// Database used
																			
drop desccategoriaitem descclasseitem descgrupoitem descitem razãosocialfornecedor /// 
descriçãoenquadramento2 descriçãotipoendereçofornecedor descriçãoendereçofornecedor ///
descriçãobairrofornecedor descriçãopaísfornecedor descriçãounidadecompradora /// 
statusunidadecompradora descrórgãounidadecompradora endereçounidadecompradora y							// Deleting unnecessary fields


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.1. Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
save BEC_organizing.dta, replace																		// Saving new dta
clear all               																				// Cleaning memory
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 2. Cleaning and Renaming variables
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
* 2.1. Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
save BEC_organizing_fields.dta, replace																	// Saving new dta
clear all               																				// Cleaning memory
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 3. Generating variables
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
* 3.1. Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
save BEC_generating_variables.dta, replace																	// Saving new dta
clear all               																				// Cleaning memory
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 4. Generating subsamples: by procedure (Convite, Dispensa, Pregao)
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
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
