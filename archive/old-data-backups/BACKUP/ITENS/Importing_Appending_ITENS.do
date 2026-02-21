*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/ITENS" 													// Defining Main Directory 

import delimited ITENS_11.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_11.dta, replace
clear all

import delimited ITENS_10.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_10.dta, replace
clear all

import delimited ITENS_9.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_9.dta, replace
clear all

import delimited ITENS_8.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_8.dta, replace
clear all

import delimited ITENS_7.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_7.dta, replace
clear all

import delimited ITENS_6.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_6.dta, replace
clear all

import delimited ITENS_5.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_5.dta, replace
clear all

import delimited ITENS_4.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_4.dta, replace
clear all

import delimited ITENS_3.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_3.dta, replace
clear all

import delimited ITENS_2.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_2.dta, replace
clear all

import delimited ITENS_1.csv, encoding(utf8) stringcols(3 1) numericcols(4)
save ITENS_1.dta, replace
clear all



use ITENS_11.dta, clear

append using ITENS_10.dta
append using ITENS_9.dta
append using ITENS_8.dta
append using ITENS_7.dta
append using ITENS_6.dta
append using ITENS_5.dta
append using ITENS_4.dta
append using ITENS_3.dta
append using ITENS_2.dta
append using ITENS_1.dta

save BEC_ITENS_FINAL.dta, replace
clear all
