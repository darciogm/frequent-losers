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

* Final product: Collapse_1_Final.dta

* 1- Appending Files (Yearly)

use Collapse_1_2018.dta, clear
append using Collapse_1_2017.dta
append using Collapse_1_2016.dta
append using Collapse_1_2015.dta
append using Collapse_1_2014.dta
append using Collapse_1_2013.dta
append using Collapse_1_2012.dta
append using Collapse_1_2011.dta
append using Collapse_1_2010.dta
append using Collapse_1_2009.dta



append using Collapse_1_2019.dta																	// Update

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Collapse_1_Final.dta", replace
