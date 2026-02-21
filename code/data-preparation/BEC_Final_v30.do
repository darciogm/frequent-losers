*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* 05/06/2019, version 30
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* This program organizes BEC-SP Database
* ----------------------------------------------------------------------------------------------------------------------------------------------------------


* I. LANCES: Original Files and setting up BEC Database


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
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_21.dta, replace
clear all

import delimited LANCES_20.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_20.dta, replace
clear all

import delimited LANCES_19.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_19.dta, replace
clear all

import delimited LANCES_18.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_18.dta, replace
clear all

import delimited LANCES_17.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_17.dta, replace
clear all

import delimited LANCES_16.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_16.dta, replace
clear all

import delimited LANCES_15.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_15.dta, replace
clear all

import delimited LANCES_14.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_14.dta, replace
clear all

import delimited LANCES_13.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_13.dta, replace
clear all

import delimited LANCES_12.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_12.dta, replace
clear all

import delimited LANCES_11.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_11.dta, replace
clear all

import delimited LANCES_10.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_10.dta, replace
clear all

import delimited LANCES_9.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_9.dta, replace
clear all

import delimited LANCES_8.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_8.dta, replace
clear all

import delimited LANCES_7.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_7.dta, replace
clear all

import delimited LANCES_6.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_6.dta, replace
clear all

import delimited LANCES_5.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_5.dta, replace
clear all

import delimited LANCES_4.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_4.dta, replace
clear all

import delimited LANCES_3.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_3.dta, replace
clear all

import delimited LANCES_2.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
save LANCES_2.dta, replace
clear all

import delimited LANCES_1.csv, encoding(utf8) stringcols(12 14 16 35 51 59 62 65 69)
drop finalidade diamêsencerramento v32 quantidadedeoc quantidadefornecedorparticipante descriçãostatusfornecedor descriçãotipoempresa descriçãostatusfornecedorbec v48 descriçãofornecedorstatus descriçãobairrofornecedor descriçãoendereçofornecedor descriçãopaísfornecedor descriçãotipoendereçofornecedor diamêsagendamento códdescmunicípiodeentrega códdescregiãodeentrega
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
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW" 													// Defining Main Directory 


use LANCES_21.dta, clear
append using LANCES_20.dta
append using LANCES_19.dta
append using LANCES_18.dta
append using LANCES_15.dta
append using LANCES_13.dta
append using LANCES_12.dta
drop finalidade
gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento
save BEC_LANCES_FINAL_A.dta, replace
clear all


use LANCES_11.dta, clear
append using LANCES_10.dta
append using LANCES_9.dta
append using LANCES_8.dta
append using LANCES_7.dta
append using LANCES_5.dta
append using LANCES_4.dta
append using LANCES_3.dta
append using LANCES_2.dta
append using LANCES_1.dta
drop finalidade
gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento
save BEC_LANCES_FINAL_B.dta, replace
clear all



*SUBSTITUIR E COMEÇAR DAQUI
use LANCES_17.dta, clear
append using LANCES_16.dta
append using LANCES_14.dta
append using LANCES_6.dta
drop finalidade
gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento
save BEC_LANCES_FINAL_C.dta, replace
clear all


use BEC_LANCES_FINAL_A.dta, clear
append using BEC_LANCES_FINAL_B.dta
tostring qtdeofertadecompraitemnegociado, replace
append using BEC_LANCES_FINAL_C.dta



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


* Limpar BEC_O, eliminar duplicados (firm_id + firm_zipcode); salvar arquivo para cruzar com georreferenciamento



// * 2nd file: UCs

// clear all
// use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UCs/UCs_CLEAN_code.dta", clear

// ren códigoórgão pubag_code
// label variable pubag_code "Public agency Code (Órgão)"

// ren descriçãoórgão pubag_descr
// label variable pubag_descr "Public agency Description (Órgão)"

// ren códigouo pubbudget_code
// label variable pubbudget_code "Public budget operator code (Unidade orçamentária)"

// ren descriçãouo pubbudget_descr
// label variable pubbudget_descr "Public budget operator description (Unidade orçamentária)"

// ren descriçãounidadecompradora pbu_descr
// label variable pbu_descr "Public buyer unit description"

// ren códigoentefederativo pbu_fedentity_code
// label variable pbu_fedentity "PBU Federative Entity Code"

// ren descriçãoentefederativo pbu_fedentity_descr
// label variable pbu_fedentity_descr "PBU Federative Entity Description"

// ren códigoregiãounidadecompradora pbu_region_code
// label variable pbu_region_code "PBU region code"

// ren descriçãoregiãounidadecompradora pbu_region_descr
// label variable pbu_region_descr "PBU region description"

// ren códigomunicípiounidadecompradora pbu_city_code
// label variable pbu_city_code "PBU city code"

// ren anoencerramento pbu_year
// ren códigounidadecompradora pbu_code

// ren descriçãomunicípiounidadecomprad pbu_city_descr
// label variable pbu_city_descr "Public Buyer Unit city"

// ren descrpoder pbu_power
// label variable pbu_power "Type of Government Power"

// ren descrtipoadm pbu_type_mgmt_descr
// label variable pbu_type_mgmt_descr "Description Public Buyer Unit Management type"

// ren cnpjuc pbu_cnpj
// label variable pbu_cnpj "Public Buyer Unit CNPJ"

// label variable pbu_code_year "Key variable for UCs merge"

// label variable pbu_power "1=CONVENIADAS;2=MIN PUB;3=EXECUTIVO;4=JUDICIARIO;5=LEGISLATIVO"

// label variable pbu_type_mgmt_descr "1=ADM DIR;2=AUTARQ;3=ECON MISTA DEP;4=ECON MISTA IND;5=CONVENIADAS;6=FUNDACAO"

// ren códigopoder pbu_power_code

// sort pbu_code_year

// save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UCs/UCs_CLEAN_code.dta", replace





* Merge BEC_0 and UCs_CLEAN_code (UCs Info)



cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW" 
use BEC_0.dta, clear
sort pbu_code_year


merge m:1 pbu_code_year using UCs_info_MERGE.dta
ren _merge _merge_pbu_final
drop if po == ""

// keep if _merge_pbu == 3
// append using NOT_MATCHED.dta, force
save BEC_1.dta, replace





* Working in FULL File
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

save BEC_2.dta, replace

drop pbu_city_delivery_code pbu_city_delivery pbu_region_delivery_code pbu_region_delivery pubag_code pubag_descr pubbudget_code pubbudget_descr pbu_descr ///
pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_cnpj pbu_power pbu_type_mgmt_descr _merge_pbu

ren descriçãorazãosocial firm_descr
label variable firm_descr "Firm Description"

replace bid_unit_price = . if bid_unit_price == 0
replace bid_unit_price_negot = . if bid_unit_price_negot == 0
replace bid_total_value = . if bid_total_value == 0
replace bid_ref_price = . if bid_ref_price == 0
replace bid_min_price = . if bid_min_price == 0
replace bid_max_price = . if bid_max_price == 0
replace bid_item_qty_perbid = . if bid_item_qty_perbid == 0
replace bid_item_qty_perbid_winner = . if bid_item_qty_perbid_winner == 0
replace bid_total_price_negot = . if bid_total_price_negot == 0

save BEC_3.dta, replace





*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4. Geocoding PBU and firm addresses: DADOS CEP DATABASE (https://www.base-dados-cep.com/)
*----------------------------------------------------------------------------------------------------------------------------------------------------------

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4.1. PBU Geocoding
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Option 1: Darcio

clear all
use Geocoding_pbu_zipcode.dta, clear
sort pbu_zipcode
save Geocoding_pbu_zipcode.dta, replace

use BEC_3.dta, clear 																			// Database used
sort pbu_zipcode

merge m:1 pbu_zipcode using Geocoding_pbu_zipcode.dta
ren _merge _merge_pbu_geocod
drop if po == ""

drop id_pbu uf_pbu city_pbu address_pbu ddd_pbu

save BEC_4.dta, replace

clear all


// * Option 2: Danilo

// clear all
// use Geocoding_pbu_zipcode1.dta, clear
// sort pbu_zipcode
// save Geocoding_pbu_zipcode1.dta, replace

// use BEC_3.dta, clear 																			// Database used
// sort pbu_zipcode

// merge m:1 pbu_zipcode using Geocoding_pbu_zipcode1.dta
// ren _merge _merge_pbu_geocod
// drop if po == ""

// drop id_pbu uf_pbu city_pbu address_pbu ddd_pbu

// save BEC_4_alternative.dta, replace

// clear all



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.4.2. Firm Geocoding
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* Option 1: Darcio

use Geocoding_firm_zipcode.dta, clear
sort firm_zipcode
save Geocoding_firm_zipcode.dta, replace

use BEC_4.dta, clear 																			// Database used
sort firm_zipcode

merge m:1 firm_zipcode using Geocoding_firm_zipcode.dta
ren _merge _merge_firm_geocod
drop if po == ""

drop  id_firm uf_firm city_firm address_firm ddd_firm


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.5. Calculating Distance between Firm and PBUs
*----------------------------------------------------------------------------------------------------------------------------------------------------------

geodist latit_pbu longit_pbu latit_firm longit_firm, generate(dist)


save BEC_5.dta, replace

clear all



// * Option 2: Danilo

// use Geocoding_firm_zipcode1.dta, clear
// sort firm_zipcode
// save Geocoding_firm_zipcode1.dta, replace

// use BEC_4_alternative.dta, clear 																			// Database used
// sort firm_zipcode

// merge m:1 firm_zipcode using Geocoding_firm_zipcode1.dta
// ren _merge _merge_firm_geocod
// drop if po == ""

// drop  id_firm uf_firm city_firm address_firm ddd_firm

// *----------------------------------------------------------------------------------------------------------------------------------------------------------
// *----------------------------------------------------------------------------------------------------------------------------------------------------------

// *----------------------------------------------------------------------------------------------------------------------------------------------------------
// * 1.5. Calculating Distance between Firm and PBUs
// *----------------------------------------------------------------------------------------------------------------------------------------------------------

// geodist latit_pbu longit_pbu latit_firm longit_firm, generate(dist)


// save BEC_5.dta, replace

// clear all




* II. LANCES: Collapse_1

*----------------------------------------------------------------------------------------------------------------------------------------------------------
* 1.2. Collapsing bid prices, #firms, #bids, bid winner, bid time (from BEC_LANCES.dta)
*----------------------------------------------------------------------------------------------------------------------------------------------------------

* A. Collapse_1.dta: Main File

clear all

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW"
use BEC_5.dta, clear

global po_info m_y date year proc po_phase_code po po_status_code po_status categ_item group_item group_item_descr class_item class_item_descr item item_descr item_unit price_reg green_item item_type po_item_id po_item_key po_item_merge_key

global pbu_info pbu_code_year pbu_code pbu_year pbu_zipcode latit_pbu longit_pbu ibge_cod_uf_pbu ibge_cod_cidade_pbu area_cidade_km2_pbu													

global firm_info firm_id firm_descr firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code firm_state_sp firm_zipcode latit_firm longit_firm firm_city firm_state ibge_cod_uf_firm ibge_cod_cidade_firm area_cidade_km2_firm						

global fig_info	bid_winner bid_ref_price bid_unit_price bid_unit_price_negot bid_total_value bid_min_price bid_max_price bid_item_qty_perbid bid_item_qty_perbid_winner bid_total_price_negot bid_status bid_status_group_code same_city_pbu_firm	bid_count bid_time_date	unique_firm

global merge_info _merge_pbu_final	_merge_pbu_geocod _merge_firm_geocod																	


order $po_info $pbu_info $firm_info $fig_info $merge_info		


drop po_item_id po_item_key
drop if po_phase_code == "5"
replace po_phase_code = "3" if proc == 2 &  po_phase_code == "2"
replace bid_status_group_code = 1 if bid_status_group_code == 4
gen bid_status_code = 0
replace bid_status_code = 1 if bid_status_group_code == 1 | bid_status_group_code == 5
gen bid_acession = 0
replace bid_acession = 1 if po_phase_code == "1"
replace po_phase_code = "3" if po_phase_code == "1"
replace po_phase_code = "4" if po_phase_code == "7"

gen po_item_merge_key = po + item + po_phase_code + item_unit
bysort po_item_merge_key (bid_unit_price): gen bid_rank = sum(bid_unit_price != bid_unit_price[_n-1])

gen bid_price_prop = bid_unit_price if po_phase_code == "2"
gen bid_price_bids = bid_unit_price if po_phase_code == "3"
gen bid_price_negot = bid_unit_price if po_phase_code == "4"
gen bid_price_pref = bid_unit_price if po_phase_code == "6"

collapse (sum) n_firms=unique_firm n_bids=bid_count po_winner_sum=bid_winner /// 
(min) dist_min=dist bid_price_min=bid_unit_price bid_time_min=bid_time_date bid_unit_price_negot_min=bid_unit_price_negot bid_ref_price_min=bid_ref_price bid_price_prop_min=bid_price_prop bid_price_bids_min=bid_price_bids bid_price_negot_min=bid_price_negot bid_price_pref_min=bid_price_pref /// 
(max) dist_max=dist bid_price_max=bid_unit_price po_winner_max=bid_winner bid_time_max=bid_time_date bid_unit_price_negot_max=bid_unit_price_negot bid_ref_price_max=bid_ref_price bid_price_prop_max=bid_price_prop bid_price_bids_max=bid_price_bids bid_price_negot_max=bid_price_negot bid_price_pref_max=bid_price_pref /// 
(mean) dist_mean=dist bid_price_mean=bid_unit_price bid_price_prop_mean=bid_price_prop bid_price_bids_mean=bid_price_bids bid_price_negot_mean=bid_price_negot bid_price_pref_mean=bid_price_pref /// 
(median) dist_median=dist bid_price_median=bid_unit_price bid_price_prop_median=bid_price_prop bid_price_bids_median=bid_price_bids bid_price_negot_median=bid_price_negot bid_price_pref_median=bid_price_pref/// 
(sd) dist_sd=dist bid_price_sd=bid_unit_price bid_price_prop_sd=bid_price_prop bid_price_bids_sd=bid_price_bids bid_price_negot_sd=bid_price_negot bid_price_pref_sd=bid_price_pref/// 
(semean) dist_semean=dist bid_price_semean=bid_unit_price bid_price_prop_semean=bid_price_prop bid_price_bids_semean=bid_price_bids bid_price_negot_semean=bid_price_negot bid_price_pref_semean=bid_price_pref, by(po_item_merge_key po_phase_code po categ_item class_item class_item_descr group_item group_item_descr item ///
item_descr item_unit pbu_code pbu_code_year proc price_reg green_item po_status po_status_code m_y year item_type pbu_year latit_pbu longit_pbu /// 
ibge_cod_uf_pbu ibge_cod_cidade_pbu area_cidade_km2_pbu _merge_pbu_geocod)

gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

gen n_firms_prop=n_firms if po_phase_code=="2"
gen n_firms_bids=n_firms if po_phase_code=="3"
gen n_firms_negot=n_firms if po_phase_code=="4"
gen n_firms_pref=n_firms if po_phase_code=="6"
gen n_bids_prop=n_bids if po_phase_code=="2"
gen n_bids_bids=n_bids if po_phase_code=="3"
gen n_bids_negot=n_bids if po_phase_code=="4"
gen n_bids_pref=n_bids if po_phase_code=="6"
gen po_winner_sum_prop=po_winner_sum if po_phase_code=="2"
gen po_winner_sum_bids=po_winner_sum if po_phase_code=="3"
gen po_winner_sum_negot=po_winner_sum if po_phase_code=="4"
gen po_winner_sum_pref=po_winner_sum if po_phase_code=="6"
gen dist_min_prop=dist_min if po_phase_code=="2"
gen dist_min_bids=dist_min if po_phase_code=="3"
gen dist_min_negot=dist_min if po_phase_code=="4"
gen dist_min_pref=dist_min if po_phase_code=="6"
gen dist_max_prop=dist_max if po_phase_code=="2"
gen dist_max_bids=dist_max if po_phase_code=="3"
gen dist_max_negot=dist_max if po_phase_code=="4"
gen dist_max_pref=dist_max if po_phase_code=="6"
gen po_winner_max_prop=po_winner_max if po_phase_code=="2"
gen po_winner_max_bids=po_winner_max if po_phase_code=="3"
gen po_winner_max_negot=po_winner_max if po_phase_code=="4"
gen po_winner_max_pref=po_winner_max if po_phase_code=="6"
gen dist_mean_prop=dist_mean if po_phase_code=="2"
gen dist_mean_bids=dist_mean if po_phase_code=="3"
gen dist_mean_negot=dist_mean if po_phase_code=="4"
gen dist_mean_pref=dist_mean if po_phase_code=="6"
gen dist_median_prop=dist_median if po_phase_code=="2"
gen dist_median_bids=dist_median if po_phase_code=="3"
gen dist_median_negot=dist_median if po_phase_code=="4"
gen dist_median_pref=dist_median if po_phase_code=="6"
gen dist_sd_prop=dist_sd if po_phase_code=="2"
gen dist_sd_bids=dist_sd if po_phase_code=="3"
gen dist_sd_negot=dist_sd if po_phase_code=="4"
gen dist_sd_pref=dist_sd if po_phase_code=="6"
gen dist_semean_prop=dist_semean if po_phase_code=="2"
gen dist_semean_bids=dist_semean if po_phase_code=="3"
gen dist_semean_negot=dist_semean if po_phase_code=="4"
gen dist_semean_pref=dist_semean if po_phase_code=="6"
gen proc_length_sec_prop=proc_length_seconds if po_phase_code=="2"
gen proc_length_sec_bids=proc_length_seconds if po_phase_code=="3"
gen proc_length_sec_negot=proc_length_seconds if po_phase_code=="4"
gen proc_length_sec_pref=proc_length_seconds if po_phase_code=="6"
gen proc_length_minutes_prop=proc_length_minutes if po_phase_code=="2"
gen proc_length_minutes_bids=proc_length_minutes if po_phase_code=="3"
gen proc_length_minutes_negot=proc_length_minutes if po_phase_code=="4"
gen proc_length_minutes_pref=proc_length_minutes if po_phase_code=="6"
gen proc_length_hours_prop=proc_length_hours if po_phase_code=="2"
gen proc_length_hours_bids=proc_length_hours if po_phase_code=="3"
gen proc_length_hours_negot=proc_length_hours if po_phase_code=="4"
gen proc_length_hours_pref=proc_length_hours if po_phase_code=="6"
gen proc_length_days_prop=proc_length_days if po_phase_code=="2"
gen proc_length_days_bids=proc_length_days if po_phase_code=="3"
gen proc_length_days_negot=proc_length_days if po_phase_code=="4"
gen proc_length_days_pref=proc_length_days if po_phase_code=="6"
gen po_item_unit = po + item + item_unit

save Collapse_1.dta, replace
clear all

use Collapse_1.dta, clear

collapse (max) n_firms_prop_new=n_firms_prop	n_firms_bids_new=n_firms_bids	n_firms_negot_new=n_firms_negot	n_firms_pref_new=n_firms_pref ///
n_bids_prop_new=n_bids_prop	n_bids_bids_new=n_bids_bids	n_bids_negot_new=n_bids_negot	n_bids_pref_new=n_bids_pref	po_winner_sum_prop_new=po_winner_sum_prop ///
po_winner_sum_bids_new=po_winner_sum_bids	po_winner_sum_negot_new=po_winner_sum_negot	po_winner_sum_pref_new=po_winner_sum_pref /// 
dist_min_prop_new=dist_min_prop	dist_min_bids_new=dist_min_bids	dist_min_negot_new=dist_min_negot	dist_min_pref_new=dist_min_pref	dist_max_prop_new=dist_max_prop /// 
dist_max_bids_new=dist_max_bids	dist_max_negot_new=dist_max_negot	dist_max_pref_new=dist_max_pref	po_winner_max_prop_new=po_winner_max_prop	po_winner_max_bids_new=po_winner_max_bids ///
po_winner_max_negot_new=po_winner_max_negot	po_winner_max_pref_new=po_winner_max_pref	dist_mean_prop_new=dist_mean_prop	dist_mean_bids_new=dist_mean_bids ///
dist_mean_negot_new=dist_mean_negot	dist_mean_pref_new=dist_mean_pref	dist_median_prop_new=dist_median_prop	dist_median_bids_new=dist_median_bids ///
dist_median_negot_new=dist_median_negot	dist_median_pref_new=dist_median_pref	dist_sd_prop_new=dist_sd_prop	dist_sd_bids_new=dist_sd_bids ///
dist_sd_negot_new=dist_sd_negot	dist_sd_pref_new=dist_sd_pref	dist_semean_prop_new=dist_semean_prop	dist_semean_bids_new=dist_semean_bids ///
dist_semean_negot_new=dist_semean_negot	dist_semean_pref_new=dist_semean_pref	proc_length_sec_prop_new=proc_length_sec_prop	proc_length_sec_bids_new=proc_length_sec_bids ///
proc_length_sec_negot_new=proc_length_sec_negot	proc_length_sec_pref_new=proc_length_sec_pref	proc_length_minutes_prop_new=proc_length_minutes_prop ///
proc_length_minutes_bids_new=proc_length_minutes_bids	proc_length_minutes_negot_new=proc_length_minutes_negot	proc_length_minutes_pref_new=proc_length_minutes_pref ///
proc_length_hours_prop_new=proc_length_hours_prop	proc_length_hours_bids_new=proc_length_hours_bids	proc_length_hours_negot_new=proc_length_hours_negot	/// 
proc_length_hours_pref_new=proc_length_hours_pref	proc_length_days_prop_new=proc_length_days_prop	proc_length_days_bids_new=proc_length_days_bids	proc_length_days_negot_new=proc_length_days_negot ///
proc_length_days_pref_new=proc_length_days_pref bid_price_prop_min_new=bid_price_prop_min	bid_price_bids_min_new=bid_price_bids_min	bid_price_negot_min_new=bid_price_negot_min ///
bid_price_pref_min_new=bid_price_pref_min	bid_price_prop_max_new=bid_price_prop_max	bid_price_bids_max_new=bid_price_bids_max /// 
bid_price_negot_max_new=bid_price_negot_max	bid_price_pref_max_new=bid_price_pref_max	bid_price_prop_mean_new=bid_price_prop_mean	/// 
bid_price_bids_mean_new=bid_price_bids_mean	bid_price_negot_mean_new=bid_price_negot_mean	bid_price_pref_mean_new=bid_price_pref_mean	/// 
bid_price_prop_median_new=bid_price_prop_median	bid_price_bids_median_new=bid_price_bids_median	bid_price_negot_median_new=bid_price_negot_median /// 
bid_price_pref_median_new=bid_price_pref_median	bid_price_prop_sd_new=bid_price_prop_sd	bid_price_bids_sd_new=bid_price_bids_sd	/// 
bid_price_negot_sd_new=bid_price_negot_sd	bid_price_pref_sd_new=bid_price_pref_sd	bid_price_prop_semean_new=bid_price_prop_semean ///
bid_price_bids_semean_new=bid_price_bids_semean	bid_price_negot_semean_new=bid_price_negot_semean /// 
bid_price_pref_semean_new=bid_price_pref_semean, by(po_item_unit m_y year proc	po	po_status_code	po_status	categ_item	group_item	group_item_descr	class_item	class_item_descr	item	item_descr	item_unit	price_reg	green_item	item_type	pbu_code_year	pbu_code	pbu_year	latit_pbu	longit_pbu	ibge_cod_uf_pbu	ibge_cod_cidade_pbu	area_cidade_km2_pbu)


gen key1_merge = po + item
sort key1_merge
duplicates drop key1_merge, force
save Collapse_1_Final.dta, replace
clear all



* V. ITEMS: item sequence number (Collapse_2)


clear all
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/ITEM 22.04.2019.csv", encoding(utf8) stringcols(6 8 10 13 12 15 17)
gen po_item_number_firm = numerodaoc + códigoitem + númerosequênciaitem + códigofornecedor
gen key1_merge = po + item
sort key1_merge
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/Collapse_2.dta", replace
clear all



use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/Collapse_2.dta", clear
merge m:1 key1_merge using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/Collapse_1_Final.dta"
ren _merge _merge_collapse
drop if po == ""

gen winner = 1
replace winner = 0 if códigofornecedor == "Sem Vencedor"
label variable winner "1=if there is a winner firm;0=otherwise"
gen check_po_status = 1
replace check_po_status = 0 if descriçãoofertadecomprastatus== po_status
drop descriçãoofertadecomprastatus códigogrupo descgrupoitem códigoclasse descclasseitem códigoitem descitem item_unit _merge_collapse

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC.dta", replace

clear all



* UCs info
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC.dta", clear
sort pbu_code_year
merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/UCs_CLEAN_code.dta"
ren _merge _merge_ucs
drop if po == ""

drop if _merge_ucs == 1

append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/Not Matched_UCs_FINAL.dta"
drop _merge_ucs
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_UCs.dta", replace



* Firm Info

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_5.dta", clear 
keep  po firm_id firm_descr firm_city firm_state firm_zipcode firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code latit_firm longit_firm ibge_cod_uf_firm ibge_cod_cidade_firm area_cidade_km2_firm
gen po_firm_id = po + firm_id
sort po_firm_id
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/FIRM_info.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_UCs.dta" 
gen po_firm_id = numerodaoc + códigofornecedor
sort po_firm_id
merge m:1 po_firm_id using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/FIRMS_info.dta"
ren _merge _merge_firms
drop if anoencerramento == .
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_UCs_FIRMS.dta", replace

* Organizing

ren anoencerramento po_year
ren numerodaoc po_aux
ren finalidade po_subject
ren descriçãoofertadecomprastatus po_status_descr_aux
ren descriçãoprocedimentocompra po_proc_descr
ren códigoórgão bureau_code_aux
ren descriçãoórgão bureau_descr_aux
ren códigouo uo_code_aux
ren descriçãouo uo_descr_aux
ren códigounidadecompradora pbu_code_aux
ren descriçãounidadecompradora pbu_descr_aux
ren númerosequênciaitem po_item_seq
ren códigogrupo group_item_aux
ren descgrupoitem group_item_descr_aux
ren códigoclasse class_item_aux
ren descclasseitem class_item_descr_aux
ren códigoitem item_aux
ren descitem item_descr_aux
ren descunidadefornecimento item_unit_aux
ren códigofornecedor firm_code_aux
ren qtdeofertadecompraitemnegociado bid_qty
ren valorunitáriodereferência bid_price_ref
ren valorunitárionegociado bid_price
ren po_item_number_firm po_item_number_firm
ren key1_merge key1_merge
ren m_y m_y
ren year year
ren proc po_proc_code
ren po po
ren po_status_code po_status_code
ren po_status po_status_descr
ren categ_item categ_item
ren group_item group_item
ren group_item_descr group_item_descr
ren class_item class_item
ren class_item_descr class_item_descr
ren item item
ren item_descr item_descr
ren item_unit item_unit
ren price_reg bid_price_reg
ren green_item bid_green_item
ren item_type bid_item_type
ren pbu_code_year pbu_code_year
ren pbu_code pbu_code
ren pbu_year pbu_year
ren latit_pbu pbu_latit
ren longit_pbu pbu_longit
ren ibge_cod_uf_pbu pbu_ibge_cod_uf
ren ibge_cod_cidade_pbu pbu_ibge_cod_city
ren area_cidade_km2_pbu pbu_city_area
ren po_item_unit po_item_unit
ren n_firms_prop_new n_firms_prop
ren n_firms_bids_new n_firms_bids
ren n_firms_negot_new n_firms_negot
ren n_firms_pref_new n_firms_pref
ren n_bids_prop_new n_bids_prop
ren n_bids_bids_new n_bids_bids
ren n_bids_negot_new n_bids_negot
ren n_bids_pref_new n_bids_pref
ren po_winner_sum_prop_new po_winner_sum_prop
ren po_winner_sum_bids_new po_winner_sum_bids
ren po_winner_sum_negot_new po_winner_sum_negot
ren po_winner_sum_pref_new po_winner_sum_pref
ren dist_min_prop_new dist_min_prop
ren dist_min_bids_new dist_min_bids
ren dist_min_negot_new dist_min_negot
ren dist_min_pref_new dist_min_pref
ren dist_max_prop_new dist_max_prop
ren dist_max_bids_new dist_max_bids
ren dist_max_negot_new dist_max_negot
ren dist_max_pref_new dist_max_pref
ren po_winner_max_prop_new po_winner_max_prop
ren po_winner_max_bids_new po_winner_max_bids
ren po_winner_max_negot_new po_winner_max_negot
ren po_winner_max_pref_new po_winner_max_pref
ren dist_mean_prop_new dist_mean_prop
ren dist_mean_bids_new dist_mean_bids
ren dist_mean_negot_new dist_mean_negot
ren dist_mean_pref_new dist_mean_pref
ren dist_median_prop_new dist_median_prop
ren dist_median_bids_new dist_median_bids
ren dist_median_negot_new dist_median_negot
ren dist_median_pref_new dist_median_pref
ren dist_sd_prop_new dist_sd_prop
ren dist_sd_bids_new dist_sd_bids
ren dist_sd_negot_new dist_sd_negot
ren dist_sd_pref_new dist_sd_pref
ren dist_semean_prop_new dist_semean_prop
ren dist_semean_bids_new dist_semean_bids
ren dist_semean_negot_new dist_semean_negot
ren dist_semean_pref_new dist_semean_pref
ren proc_length_sec_prop_new proc_length_sec_prop
ren proc_length_sec_bids_new proc_length_sec_bids
ren proc_length_sec_negot_new proc_length_sec_negot
ren proc_length_sec_pref_new proc_length_sec_pref
ren proc_length_minutes_prop_new proc_length_minutes_prop
ren proc_length_minutes_bids_new proc_length_minutes_bids
ren proc_length_minutes_negot_new proc_length_minutes_negot
ren proc_length_minutes_pref_new proc_length_minutes_pref
ren proc_length_hours_prop_new proc_length_hours_prop
ren proc_length_hours_bids_new proc_length_hours_bids
ren proc_length_hours_negot_new proc_length_hours_negot
ren proc_length_hours_pref_new proc_length_hours_pref
ren proc_length_days_prop_new proc_length_days_prop
ren proc_length_days_bids_new proc_length_days_bids
ren proc_length_days_negot_new proc_length_days_negot
ren proc_length_days_pref_new proc_length_days_pref
ren bid_price_prop_min_new bid_price_prop_min
ren bid_price_bids_min_new bid_price_bids_min
ren bid_price_negot_min_new bid_price_negot_min
ren bid_price_pref_min_new bid_price_pref_min
ren bid_price_prop_max_new bid_price_prop_max
ren bid_price_bids_max_new bid_price_bids_max
ren bid_price_negot_max_new bid_price_negot_max
ren bid_price_pref_max_new bid_price_pref_max
ren bid_price_prop_mean_new bid_price_prop_mean
ren bid_price_bids_mean_new bid_price_bids_mean
ren bid_price_negot_mean_new bid_price_negot_mean
ren bid_price_pref_mean_new bid_price_pref_mean
ren bid_price_prop_median_new bid_price_prop_median
ren bid_price_bids_median_new bid_price_bids_median
ren bid_price_negot_median_new bid_price_negot_median
ren bid_price_pref_median_new bid_price_pref_median
ren bid_price_prop_sd_new bid_price_prop_sd
ren bid_price_bids_sd_new bid_price_bids_sd
ren bid_price_negot_sd_new bid_price_negot_sd
ren bid_price_pref_sd_new bid_price_pref_sd
ren bid_price_prop_semean_new bid_price_prop_semean
ren bid_price_bids_semean_new bid_price_bids_semean
ren bid_price_negot_semean_new bid_price_negot_semean
ren bid_price_pref_semean_new bid_price_pref_semean
ren _merge_collapse bid_merge_collapse
ren pubag_code pbu_bureau_code
ren pubag_descr pbu_bureau_descr
ren pubbudget_code pbu_uo_code
ren pubbudget_descr pbu_uo_descr
ren pbu_descr pbu_descr
ren pbu_fedentity_code pbu_fedentity_code
ren pbu_fedentity_descr pbu_fedentity_descr
ren pbu_region_code pbu_region_code
ren pbu_region_descr pbu_region_descr
ren pbu_city_code pbu_city_code
ren pbu_city_descr pbu_city_descr
ren pbu_zipcode pbu_zipcode
ren pbu_cnpj pbu_cnpj
ren pbu_power pbu_power
ren pbu_type_mgmt_descr pbu_type_mgmt_descr
ren _merge_ucs _merge_ucs
ren winner po_item_winner
ren po_firm_id po_firm_id
ren firm_id firm_id
ren firm_descr firm_descr
ren firm_city firm_city
ren firm_state firm_state
ren firm_zipcode firm_zipcode
ren firm_type_code firm_type_code
ren firm_person_code firm_person_code
ren firm_headqtr_branch_code firm_headqtr_branch_code
ren firm_legal_nature_code firm_legal_nature_code
ren firm_simples_code firm_simples_code
ren latit_firm firm_latit
ren longit_firm firm_longit
ren ibge_cod_uf_firm firm_ibge_cod_uf
ren ibge_cod_cidade_firm firm_ibge_cod_city
ren area_cidade_km2_firm firm_city_area
ren _merge_firms _merge_firms
label variable po_year "PO year"
label variable po_aux "PO code aux"
label variable po_subject "PO subject"
label variable po_status_descr_aux "PO Status description aux"
label variable po_proc_descr "PO Procedure description"
label variable bureau_code_aux "Bureau code"
label variable bureau_descr_aux "Bureau description"
label variable uo_code_aux "UO code"
label variable uo_descr_aux "UO description"
label variable pbu_code_aux "PBU code aux"
label variable pbu_descr_aux "PBU description aux"
label variable po_item_seq "PO item sequence"
label variable group_item_aux "Group of Item Code aux"
label variable group_item_descr_aux "Group of Item description aux"
label variable class_item_aux "Class of Item Code aux"
label variable class_item_descr_aux "Class of Item description aux"
label variable item_aux "Item code aux"
label variable item_descr_aux "Item description aux"
label variable item_unit_aux "Item unit description aux"
label variable firm_code_aux "Firm code aux"
label variable bid_qty "Quantity negotiated"
label variable bid_price_ref "PO item reference price"
label variable bid_price "PO item price"
label variable po_item_number_firm "Key Firm info"
label variable key1_merge "Merge status"
label variable m_y "Date in date format"
label variable year "Year"
label variable po_proc_code "1 = CONVITE; 2 = DISPENSA DE LICITAÇÃO; 3 = PREGÃO ELETRÔNICO"
label variable po "Purchase Order Number"
label variable po_status_code "PO status code"
label variable po_status_descr "PO status"
label variable categ_item "0 = Service; 1 = Good"
label variable group_item "Group of Item Code"
label variable group_item_descr "Item group description"
label variable class_item "Class of Item Code"
label variable class_item_descr "Item class description"
label variable item "Item Code"
label variable item_descr "Item description"
label variable item_unit "Item unit"
label variable bid_price_reg "Price Registration? 0 = No; 1 = Yes"
label variable bid_green_item "Green Item? 0 = No; 1 = Yes"
label variable bid_item_type "1=MATERIAL;2=SERVIÇO"
label variable pbu_code_year "Key variable for UCs merge"
label variable pbu_code "Public Buyer Unit code in the BEC Catalog"
label variable pbu_year "PBU year"
label variable pbu_latit "PBU latitude"
label variable pbu_longit "PBU longitude"
label variable pbu_ibge_cod_uf "PBU UF IBGE code"
label variable pbu_ibge_cod_city "PBU city IBGE code"
label variable pbu_city_area "PBU city area"
label variable po_item_unit "Key variable"
label variable n_firms_prop "Number of firms Proposals"
label variable n_firms_bids "Number of firms Bids"
label variable n_firms_negot "Number of firms Negotiation"
label variable n_firms_pref "Number of firms Preference"
label variable n_bids_prop "Number of bids Proposals"
label variable n_bids_bids "Number of bids Bids"
label variable n_bids_negot "Number of bids Negotiation"
label variable n_bids_pref "Number of bids Preference"
label variable po_winner_sum_prop "PO winner sum Proposals"
label variable po_winner_sum_bids "PO winner sum Bids"
label variable po_winner_sum_negot "PO winner sum Negotiation"
label variable po_winner_sum_pref "PO winner sum Preference"
label variable dist_min_prop "PO minimum distance Proposals"
label variable dist_min_bids "PO minimum distance Bids"
label variable dist_min_negot "PO minimum distance Negotiation"
label variable dist_min_pref "PO minimum distance Preference"
label variable dist_max_prop "PO maximum distance Proposals"
label variable dist_max_bids "PO maximum distance Bids"
label variable dist_max_negot "PO maximum distance Negotiation"
label variable dist_max_pref "PO maximum distance Preference"
label variable po_winner_max_prop "PO winner maximum Proposals"
label variable po_winner_max_bids "PO winner maximum Bids"
label variable po_winner_max_negot "PO winner maximum Negotiation"
label variable po_winner_max_pref "PO winner maximum Preference"
label variable dist_mean_prop "PO mean distance Proposals"
label variable dist_mean_bids "PO mean distance Bids"
label variable dist_mean_negot "PO mean distance Negotiation"
label variable dist_mean_pref "PO mean distance Preference"
label variable dist_median_prop "PO median distance Proposals"
label variable dist_median_bids "PO median distance Bids"
label variable dist_median_negot "PO median distance Negotiation"
label variable dist_median_pref "PO median distance Preference"
label variable dist_sd_prop "PO standard deviation distance Proposals"
label variable dist_sd_bids "PO standard deviation distance Bids"
label variable dist_sd_negot "PO standard deviation distance Negotiation"
label variable dist_sd_pref "PO standard deviation distance Preference"
label variable dist_semean_prop "PO standard error mean distance Proposals"
label variable dist_semean_bids "PO standard error mean distance Bids"
label variable dist_semean_negot "PO standard error mean distance Negotiation"
label variable dist_semean_pref "PO standard error mean distance Preference"
label variable proc_length_sec_prop "PO procedure length in seconds Proposals"
label variable proc_length_sec_bids "PO procedure length in seconds Bids"
label variable proc_length_sec_negot "PO procedure length in seconds Negotiation"
label variable proc_length_sec_pref "PO procedure length in seconds Preference"
label variable proc_length_minutes_prop "PO procedure length in minutes Proposals"
label variable proc_length_minutes_bids "PO procedure length in minutes Bids"
label variable proc_length_minutes_negot "PO procedure length in minutes Negotiation"
label variable proc_length_minutes_pref "PO procedure length in minutes Preference"
label variable proc_length_hours_prop "PO procedure length in hours Proposals"
label variable proc_length_hours_bids "PO procedure length in hours Bids"
label variable proc_length_hours_negot "PO procedure length in hours Negotiation"
label variable proc_length_hours_pref "PO procedure length in hours Preference"
label variable proc_length_days_prop "PO procedure length in days Proposals"
label variable proc_length_days_bids "PO procedure length in days Bids"
label variable proc_length_days_negot "PO procedure length in days Negotiation"
label variable proc_length_days_pref "PO procedure length in days Preference"
label variable bid_price_prop_min "PO bid price min Proposals"
label variable bid_price_bids_min "PO bid price min Bids"
label variable bid_price_negot_min "PO bid price min Negotiation"
label variable bid_price_pref_min "PO bid price min Preference"
label variable bid_price_prop_max "PO bid price max Proposals"
label variable bid_price_bids_max "PO bid price max Bids"
label variable bid_price_negot_max "PO bid price max Negotiation"
label variable bid_price_pref_max "PO bid price max Preference"
label variable bid_price_prop_mean "PO bid price mean Proposals"
label variable bid_price_bids_mean "PO bid price mean Bids"
label variable bid_price_negot_mean "PO bid price mean Negotiation"
label variable bid_price_pref_mean "PO bid price mean Preference"
label variable bid_price_prop_median "PO bid price median Proposals"
label variable bid_price_bids_median "PO bid price median Bids"
label variable bid_price_negot_median "PO bid price median Negotiation"
label variable bid_price_pref_median "PO bid price median Preference"
label variable bid_price_prop_sd "PO bid price standard deviation Proposals"
label variable bid_price_bids_sd "PO bid price standard deviation Bids"
label variable bid_price_negot_sd "PO bid price standard deviation Negotiation"
label variable bid_price_pref_sd "PO bid price standard deviation Preference"
label variable bid_price_prop_semean "PO bid price standard error mean Proposals"
label variable bid_price_bids_semean "PO bid price standard error mean Bids"
label variable bid_price_negot_semean "PO bid price standard error mean Negotiation"
label variable bid_price_pref_semean "PO bid price standard error mean Preference"
label variable bid_merge_collapse "Merge status"
label variable pbu_bureau_code "Public agency Code (Órgão)"
label variable pbu_bureau_descr "Public agency Description (Órgão)"
label variable pbu_uo_code "Public budget operator code (Unidade orçamentária)"
label variable pbu_uo_descr "Public budget operator description (Unidade orçamentária)"
label variable pbu_descr "Public buyer unit description"
label variable pbu_fedentity_code "PBU Federative Entity Code"
label variable pbu_fedentity_descr "PBU Federative Entity Description"
label variable pbu_region_code "PBU region code"
label variable pbu_region_descr "PBU region description"
label variable pbu_city_code "PBU city code"
label variable pbu_city_descr "Public Buyer Unit city"
label variable pbu_zipcode "PBU zipcode"
label variable pbu_cnpj "Public Buyer Unit CNPJ"
label variable pbu_power "1=CONVENIADAS;2=MIN PUB;3=EXECUTIVO;4=JUDICIARIO;5=LEGISLATIVO"
label variable pbu_type_mgmt_descr "1=ADM DIR;2=AUTARQ;3=ECON MISTA DEP;4=ECON MISTA IND;5=CONVENIADAS;6=FUNDACAO"
label variable _merge_ucs "Merge status"
label variable po_item_winner "Is there a firm winner?"
label variable po_firm_id "Key"
label variable firm_id "CNPJ or CPF"
label variable firm_descr "Firm Description"
label variable firm_city "Firm city"
label variable firm_state "Firm state"
label variable firm_zipcode "Firm zipcode"
label variable firm_type_code "1=COOPERATIVA;2=COOPERATIVA DIR PREF;3=EPP;4=NÃO CADAST CAUFESP;5=ME;6=OUTROS"
label variable firm_person_code "1=FISICA;2=JURIDICA;3=SEM CADASTRO"
label variable firm_headqtr_branch_code "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CADASTRO"
label variable firm_legal_nature_code "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CADASTRO"
label variable firm_simples_code "1=N/A;2=NÃO;3=SIM"
label variable firm_latit "Firm latitude"
label variable firm_longit "Firm longitude"
label variable firm_ibge_cod_uf "Firm UF IBGE code"
label variable firm_ibge_cod_city "Firm city IBGE code"
label variable firm_city_area "Firm city area"
label variable _merge_firms "Merge status"


global	po_info_group	po	po_subject	po_status_code	po_status_descr	po_proc_code	po_year	po_aux	m_y	year	po_status_descr_aux	po_proc_descr	po_item_seq	categ_item	group_item	group_item_descr	group_item_aux	group_item_descr_aux	class_item	class_item_descr	class_item_aux	class_item_descr_aux	item	item_descr	item_aux	item_descr_aux	item_unit	item_unit_aux	bid_price_reg	bid_green_item	bid_item_type																																																					
global	pbu_info_group	pbu_bureau_code	pbu_bureau_descr	bureau_code_aux	bureau_descr_aux	pbu_uo_code	pbu_uo_descr	uo_code_aux	uo_descr_aux	pbu_code	pbu_cnpj	pbu_descr	pbu_code_aux	pbu_descr_aux	pbu_power	pbu_type_mgmt_descr	pbu_zipcode	pbu_latit	pbu_longit	pbu_ibge_cod_uf	pbu_ibge_cod_city	pbu_city_area	pbu_fedentity_code	pbu_fedentity_descr	pbu_region_code	pbu_region_descr	pbu_city_code	pbu_city_descr	pbu_year																																																							
global	firm_info_group	firm_id	firm_code_aux	firm_descr	firm_zipcode	firm_type_code	firm_person_code	firm_headqtr_branch_code	firm_legal_nature_code	firm_simples_code	firm_latit	firm_longit	firm_city	firm_state	firm_ibge_cod_uf	firm_ibge_cod_city	firm_city_area																																																																			
global	fig firm_info_group	bid_qty	bid_price_ref	bid_price	n_firms_prop	n_firms_bids	n_firms_negot	n_firms_pref	n_bids_prop	n_bids_bids	n_bids_negot	n_bids_pref	po_winner_sum_prop	po_winner_sum_bids	po_winner_sum_negot	po_winner_sum_pref	dist_min_prop	dist_min_bids	dist_min_negot	dist_min_pref	dist_max_prop	dist_max_bids	dist_max_negot	dist_max_pref	po_winner_max_prop	po_winner_max_bids	po_winner_max_negot	po_winner_max_pref	dist_mean_prop	dist_mean_bids	dist_mean_negot	dist_mean_pref	dist_median_prop	dist_median_bids	dist_median_negot	dist_median_pref	dist_sd_prop	dist_sd_bids	dist_sd_negot	dist_sd_pref	dist_semean_prop	dist_semean_bids	dist_semean_negot	dist_semean_pref	proc_length_sec_prop	proc_length_sec_bids	proc_length_sec_negot	proc_length_sec_pref	proc_length_minutes_prop	proc_length_minutes_bids	proc_length_minutes_negot	proc_length_minutes_pref	proc_length_hours_prop	proc_length_hours_bids	proc_length_hours_negot	proc_length_hours_pref	proc_length_days_prop	proc_length_days_bids	proc_length_days_negot	proc_length_days_pref	bid_price_prop_min	bid_price_bids_min	bid_price_negot_min	bid_price_pref_min	bid_price_prop_max	bid_price_bids_max	bid_price_negot_max	bid_price_pref_max	bid_price_prop_mean	bid_price_bids_mean	bid_price_negot_mean	bid_price_pref_mean	bid_price_prop_median	bid_price_bids_median	bid_price_negot_median	bid_price_pref_median	bid_price_prop_sd	bid_price_bids_sd	bid_price_negot_sd	bid_price_pref_sd	bid_price_prop_semean	bid_price_bids_semean	bid_price_negot_semean	bid_price_pref_semean
drop	po_item_number_firm	key1_merge	po_item_unit	po_item_winner	po_firm_id	bid_merge_collapse	_merge_ucs	_merge_firms pbu_code_year																																																																												

order $po_info_group $pbu_info_group $firm_info_group $fig_info_group

destring bid_qty bid_price_ref bid_price, replace dpcomma

gen bid_total_ref = bid_qty*bid_price_ref

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_FINAL_SOURCE.dta", replace


*** JUDICIALIZATION
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_FINAL_SOURCE.dta", clear

keep if pbu_bureau_code == "09000"
gen jud = 0
replace jud = 1 if strpos(po_subject, "JUDIC") | strpos(po_subject, "LIMINAR") | strpos(po_subject, "MANDADO") | strpos(po_subject, "MAN-DADO") 

gen adm = 0
replace adm =2 if strpos(po_subject, "ADMINISTRATIV")

gen price_reg = 0
replace price_reg =1 if strpos(po_subject, "REGISTRO DE PRECOS")

gen po_firm_winner = 1
replace po_firm_winner = 0 if firm_code_aux == "Sem Vencedor"

tab jud
tab adm
tab price_reg

gen jud_adm = jud + adm
tab jud_adm


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_JUD.dta", replace

export delimited using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/Variables_subsample_jud_adm.csv", delimiter(";") replace

clear all
import excel "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/SUBSAMPLE_03052019.xlsx", sheet("Final") firstrow allstring
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_JUD_SUBSAMPLE_SELECTION.dta", replace

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_JUD.dta", clear

sort item
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_JUD_SUBSAMPLE_SELECTION.dta"
ren _merge _merge_subsample
keep if _merge_subsample == 3

destring bid_qty bid_price_ref bid_price, replace dpcomma


tab jud
tab adm
tab jud_adm
tab price_reg
tab jud po_firm_winner
tab po_proc_code jud
tab pbu_descr jud
tab class_item_descr jud if group_item == "65" | group_item == "85"
tab group_item jud


tabstat bid_qty bid_price_ref bid_price n_firms_prop n_firms_bids n_firms_negot n_firms_pref n_bids_prop n_bids_bids n_bids_negot n_bids_pref , by(jud) statistics(mean semean) save
matrix nT1 = r(Stat1)'
matrix T1 = r(Stat2)'
matrix diff1 = [r(Stat2)-r(Stat1)]'
matrix ptcovstat1 = nT1,T1,diff1
matrix list ptcovstat1
esttab matrix(ptcovstat1) using ptcovstatmatrix1.htm, title("Pre-Treatment Covariates Mean and SEmean") replace


gen t=1
replace t=0 if jud_adm==0
sort item t
tab t

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/BEC_JUD_SUBSAMPLE.dta", replace



collapse (mean)  jud_bid_qty=bid_qty jud_bid_price_ref=bid_price_ref jud_bid_price=bid_price , by(t categ_item item po_firm_winner)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/COLLAPSED_TREAT.dta", replace


keep if categ_item == 1
sort item t
ttest jud_bid_qty, by(t)
ttest jud_bid_price_ref , by(t)
ttest jud_bid_price , by(t)
ttest jud_bid_qty if po_firm_winner==1, by(t)
ttest jud_bid_price_ref if po_firm_winner==1 , by(t)
ttest jud_bid_price if po_firm_winner==1 , by(t)
ttest jud_bid_qty if po_firm_winner==0, by(t)
ttest jud_bid_price_ref if po_firm_winner==0 , by(t)
ttest jud_bid_price if po_firm_winner==0 , by(t)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL_NEW/COLLAPSED_TREAT1.dta", replace




*** THRESHOLDS
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_FINAL_SOURCE.dta", clear
keep if bid_total_ref>=8000 & bid_total_ref<=17600 | bid_total_ref>=80000 & bid_total_ref<=176000
keep if year=="2017" | year=="2018" | year=="2019"
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_THRESHOLDS.dta", replace

keep if year=="2018" | year=="2019"
sort m_y
format %9.0g m_y
gen rd_change=1
replace rd_change=0 if m_y>=696 & m_y<=702
tab po_proc_code rd_change

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_THRESHOLDS_2018_2019.dta", replace
