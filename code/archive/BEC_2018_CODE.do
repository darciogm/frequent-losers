*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement" 													// Defining Main Directory 

* Final product: Collapse_1_2018.dta

* 1- Appending Files (Yearly)

use LANCES_20.dta, clear
append using LANCES_19.dta
drop finalidade
gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2018.dta", replace




* 2- Preparing variables

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

sort pbu_code_year



* 3- Geocoding UCs

merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE.dta"
ren _merge _merge_pbu_final
drop if po == ""


* 4- Working in full file

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


* 5- Saving Baseline and Separating Firm info

gen firm_zipcode_length=length(firm_zipcode)
tab firm_zipcode_length
replace firm_zipcode = "0" + firm_zipcode if firm_zipcode_length==7
gen firm_id_zipcode = firm_id + firm_zipcode
sort firm_id_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2018_merge.dta", replace

keep  firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2018.dta", replace


* 6- Geocoding Firms

merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Geocoding_firm_zipcode.dta"
ren _merge _merge_firm_geoc
drop if _merge_firm_geoc==2
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2018_merge.dta", replace
clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2018_merge.dta", clear
sort firm_id_zipcode
merge m:1 firm_id_zipcode using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2018_merge.dta"
ren _merge _merge_firm_geoc_final
drop if po == ""
drop  id_firm uf_firm city_firm address_firm ddd_firm
ren latit_firm firm_latit
ren longit_firm firm_longit

geodist pbu_latit pbu_longit firm_latit firm_longit , generate(dist)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2018_merge.dta", replace



* 7- Collapsing 1: Info about each po + item


global po_info m_y date year proc po_phase_code po po_status_code po_status categ_item group_item group_item_descr class_item class_item_descr item item_descr item_unit price_reg green_item item_type po_item_id po_item_key

global pbu_info pbu_code_year pbu_code pbu_year pbu_zipcode pbu_latit pbu_longit pbu_ibge_cod_uf pbu_ibge_cod_cidade  pbu_power_code pbu_type_mgmt_code pbu_uf pbu_city_area													

global firm_info firm_id firm_descr firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code firm_state_sp firm_zipcode firm_latit firm_longit firm_city firm_state ibge_cod_uf_firm ibge_cod_cidade_firm area_cidade_km2_firm	 firm_zipcode_length firm_id_zipcode					

global fig_info	bid_winner bid_ref_price bid_unit_price bid_unit_price_negot bid_total_value bid_min_price bid_max_price bid_item_qty_perbid bid_item_qty_perbid_winner bid_total_price_negot bid_status bid_status_group_code same_city_pbu_firm	bid_count bid_time_date	unique_firm  bid_id dist

global merge_info _merge_firm_geoc _merge_firm_geoc_final																	


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
(median) dist_median=dist bid_price_median=bid_unit_price bid_price_prop_median=bid_price_prop bid_price_bids_median=bid_price_bids bid_price_negot_median=bid_price_negot bid_price_pref_median=bid_price_pref /// 
(sd) dist_sd=dist bid_price_sd=bid_unit_price bid_price_prop_sd=bid_price_prop bid_price_bids_sd=bid_price_bids bid_price_negot_sd=bid_price_negot bid_price_pref_sd=bid_price_pref /// 
(semean) dist_semean=dist bid_price_semean=bid_unit_price bid_price_prop_semean=bid_price_prop bid_price_bids_semean=bid_price_bids bid_price_negot_semean=bid_price_negot bid_price_pref_semean=bid_price_pref, by(po_item_merge_key po_phase_code po categ_item class_item class_item_descr group_item group_item_descr item ///
item_descr item_unit pbu_code pbu_code_year proc price_reg green_item po_status po_status_code m_y year item_type pbu_year pbu_latit pbu_longit /// 
pbu_ibge_cod_uf pbu_ibge_cod_cidade pbu_city_area)

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
bid_price_pref_semean_new=bid_price_pref_semean, by(po_item_unit m_y year proc	po	po_status_code	po_status	categ_item	group_item	group_item_descr	class_item	class_item_descr	item	item_descr	item_unit	price_reg	green_item	item_type	pbu_code_year	pbu_code	pbu_year	pbu_latit	pbu_longit	pbu_ibge_cod_uf	pbu_ibge_cod_cidade	pbu_city_area)


gen key1_merge = po + item
sort key1_merge
duplicates drop key1_merge, force
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Collapse_1_2018.dta", replace
clear all
