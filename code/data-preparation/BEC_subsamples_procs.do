*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* BEC_generating_variables.do
* 12/21/2018, version 1
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 
* This program organizes BEC Database: Generating Subsamples.
*
* database used: BEC_generating_variables.dta 
*
* output: BEC_convite.dta; BEC_pregao.dta; BEC_dispensa.dta 
*	
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
															

log using BEC_subsamples_procs.log, replace      													// Open log file
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Generating variables
*----------------------------------------------------------------------------------------------------------------------------------------------------------

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
