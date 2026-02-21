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
															

log using BEC_collapse.log, replace      													// Open log file
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Generating variables
*----------------------------------------------------------------------------------------------------------------------------------------------------------

use BEC_generating_variables.dta, clear 																// Database used

egen po_phase_code = group (po_phase)

tostring po po_phase_code item, replace

gen po_by_phase_code = po  + po_phase_code +  item

gen double bid_time_format = clock(bid_time,"YMDhms")													// Converting bid_time to date in miliseconds

format bid_time_format %tcCCYY.NN.DD_HH:MM:SS

sort m_y po item po_phase_code bid_time_format

gen bid_time_delta = bid_time_format - bid_time_format[_n-1]

gen bid_time_delta_min = seconds(bid_time_delta)

sort m_y po item po_phase_code bid_time_format

*bysort po_by_phase_code: gen bid_id_phase = _n

*sort m_y po item po_phase_code bid_time_format

*sort m_y po_by_phase_code bid_time_format

*by po_by_phase_code: gen bid_time_delta = bid_time_format - bid_time_format[_n-1]



* collapse (count) firm_id, by (po_by_bid_status_code) 

*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Saving Database and Closing All
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* save BEC_collapse.dta, replace																	// Saving new dta
* clear all               																				// Cleaning memory
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
