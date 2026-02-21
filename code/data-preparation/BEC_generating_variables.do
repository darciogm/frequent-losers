*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* BEC_generating_variables.do
* 12/21/2018, version 1
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 
* This program organizes BEC Database: Generating Variables.
*
* database used: BEC_organizing_fields.dta (Level 2 Database)
*
* output: BEC_generating_variables.dta (Level 3 Database)
*
* key variables: 	- id (Primary Key)
*					- po (Purchase Order: OC)
*					- pbu_cnpj (Public Buyer Unit CNPJ)
*					- firm_cnpj (Firm CNPJ)						
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
															

log using BEC_generating_variables.log, replace      													// Open log file
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Generating variables
*----------------------------------------------------------------------------------------------------------------------------------------------------------

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
* Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
save BEC_generating_variables.dta, replace																	// Saving new dta
clear all               																				// Cleaning memory
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
