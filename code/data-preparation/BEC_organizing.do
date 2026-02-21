*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* BEC_organizing.do
* 12/19/2018, version 1
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* This program organizes BEC Database: Cleaning some variables
*
* database used: BEC_2009_2018_Final.dta (Level 0 Database)
*
* output: BEC_organizing.dta (Level 1 Database)
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
															

log using BEC_organizing.log, replace      																// Open log file
*----------------------------------------------------------------------------------------------------------------------------------------------------------


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Generating Level 1 Database: Cleaning Unnecessary Fields
*----------------------------------------------------------------------------------------------------------------------------------------------------------

use BEC_2009_2018_Final.dta, clear 																			// Database used
																			
drop desccategoriaitem descclasseitem descgrupoitem descitem razãosocialfornecedor /// 
descriçãoenquadramento2 descriçãotipoendereçofornecedor descriçãoendereçofornecedor ///
descriçãobairrofornecedor descriçãopaísfornecedor descriçãounidadecompradora /// 
statusunidadecompradora descrórgãounidadecompradora endereçounidadecompradora y							// Deleting unnecessary fields

save BEC_organizing.dta, replace																		// Saving new dta
clear all               																				// Cleaning memory
