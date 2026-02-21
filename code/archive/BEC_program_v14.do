*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* 04/04/2019, version 13
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* This program organizes BEC-SP Database
*
* Database used: BEC_LANCES_FINAL_CLEANED.dta (Level 0 Database)
*----------------------------------------------------------------------------------------------------------------------------------------------------------


* Importing and Appending Files

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES" 													// Defining Main Directory 

import delimited LANCES_21.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_21.dta, replace
clear all

import delimited LANCES_20.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_20.dta, replace
clear all

import delimited LANCES_19.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_19.dta, replace
clear all

import delimited LANCES_18.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_18.dta, replace
clear all

import delimited LANCES_17.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_17.dta, replace
clear all

import delimited LANCES_16.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_16.dta, replace
clear all

import delimited LANCES_15.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_15.dta, replace
clear all

import delimited LANCES_14.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_14.dta, replace
clear all

import delimited LANCES_13.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_13.dta, replace
clear all

import delimited LANCES_12.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_12.dta, replace
clear all

import delimited LANCES_11.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_11.dta, replace
clear all

import delimited LANCES_10.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_10.dta, replace
clear all

import delimited LANCES_9.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_9.dta, replace
clear all

import delimited LANCES_8.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_8.dta, replace
clear all

import delimited LANCES_7.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_7.dta, replace
clear all

import delimited LANCES_6.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_6.dta, replace
clear all

import delimited LANCES_5.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_5.dta, replace
clear all

import delimited LANCES_4.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_4.dta, replace
clear all

import delimited LANCES_3.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_3.dta, replace
clear all

import delimited LANCES_2.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_2.dta, replace
clear all

import delimited LANCES_1.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_1.dta, replace
clear all




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES" 													// Defining Main Directory 


use LANCES_21.dta, clear
append using LANCES_20.dta
append using LANCES_19.dta
append using LANCES_18.dta
append using LANCES_17.dta
append using LANCES_16.dta
append using LANCES_15.dta
save BEC_LANCES_FINAL_A.dta, replace
clear all

use LANCES_14.dta, clear
append using LANCES_13.dta
append using LANCES_12.dta
append using LANCES_11.dta
append using LANCES_10.dta
append using LANCES_9.dta
append using LANCES_8.dta
save BEC_LANCES_FINAL_B.dta, replace
clear all

use LANCES_7.dta, clear
append using LANCES_6.dta
append using LANCES_5.dta
append using LANCES_4.dta
append using LANCES_3.dta
append using LANCES_2.dta
append using LANCES_1.dta
save BEC_LANCES_FINAL_C.dta, replace
clear all


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES" 													// Defining Main Directory 


use BEC_LANCES_FINAL_A.dta, clear
drop dataocagendamento dataoccriacao dataocencerramento finalidade datacadastro
gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento
save BEC_LANCES_FINAL_A.dta, replace
clear all

use BEC_LANCES_FINAL_B.dta, clear
drop dataocagendamento dataoccriacao dataocencerramento finalidade datacadastro
gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento
save BEC_LANCES_FINAL_B.dta, replace
clear all

use BEC_LANCES_FINAL_C.dta, clear
drop dataocagendamento dataoccriacao dataocencerramento finalidade datacadastro
gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento
save BEC_LANCES_FINAL_C.dta, replace
clear all

use BEC_LANCES_FINAL_A.dta, clear
append using BEC_LANCES_FINAL_B.dta
tostring qtdeofertadecompraitemnegociado, replace
append using BEC_LANCES_FINAL_C.dta
save BEC_LANCES_FINAL.dta, replace
clear all




*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES" 													// Defining Main Directory 
												
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1. General Database Actions: Cleaning and Renaming Variables
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.1 Cleaning and Renaming Names
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* 1st file: BEC CLEANED

log using BEC_organizing.log, replace      																// Open log file

use BEC_LANCES_FINAL.dta, clear 																			// Database used			

 


ren date1 m_y
label variable m_y "Month and Year"

egen t = group(m_y)
label variable t "Month and Year from 1 to 120"

ren descriçãoprocedimentocompra descrproc
egen proc = group(descrproc)
label variable proc "1 = CONVITE; 2 = DISPENSA DE LICITAÇÃO; 3 = PREGÃO ELETRÔNICO"

ren numerodaoc po
label variable po "Purchase Order Number"

egen price_reg = group(ataregistrodepreço)
replace price_reg = price_reg - 1
label variable price_reg "Price Registration? 0 = No; 1 = Yes"

destring códigocategoria, replace
replace códigocategoria = 0 if códigocategoria == 2
ren códigocategoria categ_item
label variable categ_item "0 = Service; 1 = Good"

ren códigoclasse class_item
label variable class_item "Class of Item Code" 

ren códigogrupo group_item
label variable group_item "Group of Item Code"

ren códigoitem item
label variable item "Item Code"

ren descunidadefornecimento item_unit
label variable item_unit "Item unit"

gen green_item = 0
replace green_item = 1 if seloverde == "S"
label variable green_item "Green Item? 0 = No; 1 = Yes"

ren valorunitárioproposta bid_unit_price
label variable bid_unit_price "Bid unit price with no negotiation"

ren flagvencedor bid_winner
label variable bid_winner "Bid made by the winner firm? 0 = No; 1 = Yes (not necessarily the winner bid)"

ren datahrproposta bid_time
label variable bid_time "Day and time of the bid"

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

ren qtdeofertadecompraitemnegociado bid_item_qty_perbid
label variable bid_item_qty_perbid "Bid item quantity per bid"

ren quantidadeitemvencedor bid_item_qty_perbid_winner
label variable bid_item_qty_perbid_winner "Bid item quantity per bid winner"

ren valortotalnegociado bid_total_price_negot
label variable bid_total_price_negot "Bid total price after negotiation"

ren códigofornecedor firm_id
label variable firm_id "CNPJ or CPF"

ren descriçãoenquadramento firm_type
label variable firm_type "Firm type: Cooperativa, Cooperativa Direito de Pref., EPP, Enquadramento não cadastrado no CAUFESP, ME, Outros"

ren descriçãofisicajurídica firm_person
label variable firm_person "Pessoa Física ou Jurídica"

ren descriçãomatrizfilial firm_headqtr_branch
label variable firm_headqtr_branch "Headquarter or Branch"

ren descriçãonaturezajurídica firm_legal_nature
label variable firm_legal_nature "Firm legal nature"	

ren descriçãosimplesnacional firm_simples
label variable firm_simples "Simples Nacional"

ren descriçãopropostastatus bid_status
label variable bid_status "Bid status specific level"

ren descriçãogrupopropostastatus bid_status_group
label variable bid_status_group "Bid status general level"

ren descriçãofasesoc po_phase
label variable po_phase "Purchase Order Phase"

ren códigounidadecompradora pbu_code
label variable pbu_code "Public Buyer Unit code in the BEC Catalog"

ren descriçãomunicípiofornecedor firm_city
label variable firm_city "Firm city"

ren descriçãouffornecedor firm_state
label variable firm_state "Firm state"

ren códigocepfornecedor firm_zipcode
label variable firm_zipcode "Firm zipcode"

ren códigomunicípiodeentrega pbu_city_delivery_code
label variable pbu_city_delivery_code "City code of delivery"

ren descriçãomunicípiodeentrega pbu_city_delivery
label variable pbu_city_delivery "City of delivery"

ren códigoregiãodeentrega pbu_region_delivery_code
label variable pbu_region_delivery_code "Region code of delivery"

ren descriçãoregiãodeentrega pbu_region_delivery
label variable pbu_region_delivery "Region of delivery"

ren descriçãoofertadecomprastatus po_status
label variable po_status "PO status"

ren códigoofertadecomprastatus po_status_code
label variable po_status_code "PO status code"

ren desccategoriaitem categ_item_descr
label variable categ_item_descr "Item category description"

ren descclasseitem class_item_descr
label variable class_item_descr "Item class description"

ren descgrupoitem group_item_descr
label variable group_item_descr "Item group description"

ren descitem item_descr
label variable item_descr "Item description"

gen date = m_y

destring date, replace
gen date1 = monthly(date, "MY")
format date1 %tm

split date, p("/") gen(substr)

drop substr1 m_y propostavencedorprimeiro ataregistrodepreço seloverde descriçãounidadecompradora descrproc
drop if po == ""

ren date1 m_y

ren substr2 year

gen pbu_code_year = pbu_code + year

label variable date "Date destring"

label variable m_y "Date in date format"

label variable year "Year"

label variable pbu_code_year "Key variable for UCs merge"

egen item_type = group(categ_item_descr)
label variable item_type "1=MATERIAL;2=SERVIÇO"
drop categ_item_descr

egen firm_type_code = group(firm_type)
label variable firm_type_code "1=COOPERATIVA;2=COOPERATIVA DIR PREF;3=EPP;4=NÃO CADAST CAUFESP;5=ME;6=OUTROS"
drop firm_type

egen firm_person_code = group(firm_person)
label variable firm_person_code "1=FISICA;2=JURIDICA;3=SEM CADASTRO"
drop firm_person

egen firm_headqtr_branch_code = group(firm_headqtr_branch)
label variable firm_headqtr_branch_code "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CADASTRO"
drop firm_headqtr_branch

egen  firm_legal_nature_code = group(firm_legal_nature)
label variable firm_legal_nature_code "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CADASTRO"
drop firm_legal_nature

egen firm_simples_code = group(firm_simples)
label variable firm_simples_code "1=N/A;2=NÃO;3=SIM"
drop firm_simples

egen bid_status_code = group(bid_status)
drop bid_status
gen bid_status = bid_status_code
replace bid_status = 0 if bid_status_code >= 3 & bid_status_code <= 14
drop bid_status_code
label variable bid_status "0=INVALIDO;1=CLASSIF;2=DESCLASSIF;15=N/A;16=VÁLIDO;17=VÁLIDO E CONFIRMADO"

egen bid_status_group_code = group(bid_status_group)
label variable bid_status_group_code "1=CLASSIF;2=DESCLASSIF;3=INVÁLIDO;4=N/A;5=VÁLIDO"
drop bid_status_group

egen po_phase_code = group(po_phase)
label variable po_phase_code "1=AD MELH OFERTA;2=PROPS;3=LANCES;4=NEGOC;5=N/A;6=ME-EPP;7=REALINH PREÇO COOPERAT"
drop po_phase

drop razãosocial

destring bid_unit_price bid_unit_price_negot bid_total_value bid_ref_price bid_min_price bid_max_price bid_item_qty_perbid bid_item_qty_perbid_winner bid_total_price_negot, replace dpcomma

save BEC_0.dta, replace


* 2nd file: UCs

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UCs/UCs_CLEAN_code.dta", clear

ren códigoórgão pubag_code
label variable pubag_code "Public agency Code (Órgão)"

ren descriçãoórgão pubag_descr
label variable pubag_descr "Public agency Description (Órgão)"

ren códigouo pubbudget_code
label variable pubbudget_code "Public budget operator code (Unidade orçamentária)"

ren descriçãouo pubbudget_descr
label variable pubbudget_descr "Public budget operator description (Unidade orçamentária)"

ren descriçãounidadecompradora pbu_descr
label variable pbu_descr "Public buyer unit description"

ren códigoentefederativo pbu_fedentity_code
label variable pbu_fedentity "PBU Federative Entity Code"

ren descriçãoentefederativo pbu_fedentity_descr
label variable pbu_fedentity_descr "PBU Federative Entity Description"

ren códigoregiãounidadecompradora pbu_region_code
label variable pbu_region_code "PBU region code"

ren descriçãoregiãounidadecompradora pbu_region_descr
label variable pbu_region_descr "PBU region description"

ren códigomunicípiounidadecompradora pbu_city_code
label variable pbu_city_code "PBU city code"

ren descriçãomunicípiounidadecomprad pbu_city_descr
label variable pbu_city_descr "Public Buyer Unit city"

ren descrpoder pbu_power
label variable pbu_power "Type of Government Power"

ren descrtipoadm pbu_type_mgmt_descr
label variable pbu_type_mgmt_descr "Description Public Buyer Unit Management type"

ren cnpjuc pbu_cnpj
label variable pbu_cnpj "Public Buyer Unit CNPJ"

label variable pbu_code_year "Key variable for UCs merge"

label variable pbu_power "1=CONVENIADAS;2=MIN PUB;3=EXECUTIVO;4=JUDICIARIO;5=LEGISLATIVO"

label variable pbu_type_mgmt_descr "1=ADM DIR;2=AUTARQ;3=ECON MISTA DEP;4=ECON MISTA IND;5=CONVENIADAS;6=FUNDACAO"


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UCs/UCs_CLEAN_code.dta", replace




* Merge BEC_0 and UCs_CLEAN_code 


clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UCs/UCs_CLEAN_code.dta", clear
sort pbu_code_year
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UCs/UCs_CLEAN_code.dta", replace

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES" 
use BEC_0.dta, clear 																			// Database used
sort pbu_code_year

merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UCs/UCs_CLEAN_code.dta"
ren _merge _merge_pbu
drop if po == ""

save BEC_1.dta, replace



*save NOT_MATCHED.dta, replace

*clear all

*** RODAR ATÉ AQUI *** 

* Do PROCV Excel and save NOT_MATCHED.dta, replace


* Append NOT_MATCHED to BEC_1

clear all

use BEC_1.dta, clear
keep if _merge_pbu == 3
append using NOT_MATCHED.dta, force
save BEC_2.dta, replace




* Working in the FULL file

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES"

use BEC_2.dta, clear

gen bid_id = _n
label variable bid_id "Bid ID (Primary Key)"
																	
gen same_city_pbu_firm = 0
replace same_city_pbu_firm = 1 if firm_city == pbu_city_descr
label variable same_city_pbu_firm "Pbu and Firm in the same city? 0 = No; 1 = Yes"

gen firm_state_sp = 0
replace firm_state_sp = 1 if firm_state == "SÃO PAULO"
label variable firm_state_sp "Firm in São Paulo State? 0 = No; 1 = Yes"

tostring item, replace
tostring po_phase_code, replace

gen po_item_id = po + item + po_phase_code
gen po_item_key = po + item
gen bid_count = 1

gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time


sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1

rename nvals unique_firm

save BEC_3.dta, replace

drop pbu_city_delivery_code pbu_city_delivery pbu_region_delivery_code pbu_region_delivery pubag_code pubag_descr pubbudget_code pubbudget_descr pbu_descr ///
pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_cnpj pbu_power pbu_type_mgmt_descr _merge_pbu

ren descriçãorazãosocial firm_descr
label variable firm_descr "Firm Description"

gen po_item_merge_key = po + item + po_phase_code + item_unit

replace bid_unit_price = . if bid_unit_price == 0
replace bid_unit_price_negot = . if bid_unit_price_negot == 0
replace bid_total_value = . if bid_total_value == 0
replace bid_ref_price = . if bid_ref_price == 0
replace bid_min_price = . if bid_min_price == 0
replace bid_max_price = . if bid_max_price == 0
replace bid_item_qty_perbid = . if bid_item_qty_perbid == 0
replace bid_item_qty_perbid_winner = . if bid_item_qty_perbid_winner == 0
replace bid_total_price_negot = . if bid_total_price_negot == 0

save BEC_4.dta, replace

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

use BEC_4.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_pbu_zipcode.dta
ren _merge _merge_pbu_geocod
drop if po == ""

drop id_pbu uf_pbu city_pbu address_pbu ddd_pbu

save BEC_5.dta, replace

clear all

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4.2. Firm Geocoding
*----------------------------------------------------------------------------------------------------------------------------------------------------------

use Geocoding_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_firm_zipcode.dta, replace

use BEC_5.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_firm_zipcode.dta
ren _merge _merge_firm_geocod
drop if po == ""

drop  id_firm uf_firm city_firm address_firm ddd_firm

*----------------------------------------------------------------------------------------------------------------------------------------------------------
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.5. Calculating Distance between Firm and PBUs
*----------------------------------------------------------------------------------------------------------------------------------------------------------

geodist latit_pbu longit_pbu latit_firm longit_firm, generate(dist)

save BEC_5.dta, replace

clear all


** Merge with itens_new: getting reference prices etc. (Apr, 15)













*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.2. Collapsing bid prices, #firms, #bids, bid winner, bid time 
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Option 1: cw

clear all

use BEC_5.dta, clear

collapse (sum) n_firms=unique_firm n_bids=bid_count po_winner_sum=bid_winner /// 
(min) dist_min=dist bid_price_min=bid_unit_price bid_time_min=bid_time_date bid_unit_price_negot_min=bid_unit_price_negot bid_ref_price_min=bid_ref_price /// 
(max) dist_max=dist bid_price_max=bid_unit_price po_winner_max=bid_winner bid_time_max=bid_time_date bid_unit_price_negot_max=bid_unit_price_negot bid_ref_price_max=bid_ref_price /// 
(mean) dist_mean=dist bid_price_mean=bid_unit_price /// 
(median) dist_median=dist bid_price_median=bid_unit_price /// 
(sd) dist_sd=dist bid_price_sd=bid_unit_price /// 
(semean) dist_semean=dist bid_price_semean=bid_unit_price, by(po_item_merge_key po_phase_code) cw

gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save BEC_collapse_final_cw.dta, replace
clear all


* Option 2: no cw

use BEC_5.dta, clear

collapse (sum) n_firms=unique_firm n_bids=bid_count po_winner_sum=bid_winner /// 
(min) dist_min=dist bid_price_min=bid_unit_price bid_time_min=bid_time_date bid_unit_price_negot_min=bid_unit_price_negot bid_ref_price_min=bid_ref_price /// 
(max) dist_max=dist bid_price_max=bid_unit_price po_winner_max=bid_winner bid_time_max=bid_time_date bid_unit_price_negot_max=bid_unit_price_negot bid_ref_price_max=bid_ref_price /// 
(mean) dist_mean=dist bid_price_mean=bid_unit_price /// 
(median) dist_median=dist bid_price_median=bid_unit_price /// 
(sd) dist_sd=dist bid_price_sd=bid_unit_price /// 
(semean) dist_semean=dist bid_price_semean=bid_unit_price, by(po_item_merge_key po_phase_code)

gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save BEC_collapse_final_nocw.dta, replace
clear all










capture log close



use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/ITENS/BEC_ITENS_FINAL.dta"

ren códigoitem item_code
tostring item_code, replace

ren numerodaoc po
tostring po, replace 

ren participaçãoexclusivameeppcooper po_preference

ren qtdeofertadecompraitemnegociado bid_item_qty_negot

ren quantidadefornecedorparticipante po_number_firms

drop anoencerramento 

gen po_item_key = po + item_code

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES"

save ITENS_MERGE.dta, replace

clear all


* MERGE BEC_4 and ITENS_MERGE

clear all

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/LANCES"

use ITENS_MERGE.dta, clear
sort po_item_key
save ITENS_MERGE.dta, replace

use BEC_4.dta, clear 																			// Database used
sort po_item_key

merge m:1 po_item_key using ITENS_MERGE.dta
ren _merge _merge_itens
drop if po == ""

save BEC_10.dta, replace



































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
