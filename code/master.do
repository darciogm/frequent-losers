*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* Master.do
* 12/19/2018, version 1
* Darcio Genicolo Martins, Insper
*
* This program is responsible for centralizing the 
* execution of all do-files to organize the Database Master.
*
* database used: 
*
* output: Master.dta
*
* key variables: 	- id (Primary Key)
*					- po (Purchase Order: OC)
*					- pb_cnpj (Public Buyer CNPJ)
*					- fr_cnpj (Firm CNPJ)						
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              												// Set Version number for backward compatibility
set more off            												// Disable partitioned output
clear all               												// Start with a clean slate
set linesize 80         												// Line size limit to make output more readable
macro drop _all         												// clear all macros
capture log close       												// Close existing log files
log using Master.txt, text replace      								// Open log file
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Order

* 1-	BEC_organizing.do 												// Cleaning variables
* 2-	BEC_organizing_fields.do 										// Cleaning and Renaming variables
* 3-	BEC_generating_variables.do										// Generating variables
