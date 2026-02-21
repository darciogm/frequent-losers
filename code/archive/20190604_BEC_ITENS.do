*----------------------------------------------------------------------------------------------------------------------------------------------------------
* PhD Thesis - Organizing the Database Master
* 05/14/2019, version 2
* Darcio Genicolo Martins, Insper
*----------------------------------------------------------------------------------------------------------------------------------------------------------
* This program organizes BEC-SP Database (ITEMS)
* ----------------------------------------------------------------------------------------------------------------------------------------------------------


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



* 1. ITEMS: item sequence number (Collapse_2)


clear all
*import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/ITENS/ITEM 22.04.2019.csv", encoding(utf8) stringcols(6 8 10 13 12 15 17)
*gen po_item_number_firm = numerodaoc + códigoitem + númerosequênciaitem + códigofornecedor
*gen key1_merge = numerodaoc + códigoitem
*sort key1_merge
*save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Collapse_2.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Collapse_2.dta", clear

merge m:1 key1_merge using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Collapse_ALL.dta"
ren _merge _merge_collapse


gen winner = 1
replace winner = 0 if códigofornecedor == "Sem Vencedor"
label variable winner "1=if there is a winner firm;0=otherwise"
gen check_po_status = 1
replace check_po_status = 0 if descriçãoofertadecomprastatus== po_status
drop descriçãoofertadecomprastatus códigogrupo descgrupoitem códigoclasse descclasseitem códigoitem descitem item_unit _merge_collapse

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_ALL.dta", replace



* UCs info


sort pbu_code_year
merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE.dta"
ren _merge _merge_ucs

replace year="2018" if _merge_ucs==1
replace pbu_code_year= pbu_code + year
sort pbu_code_year
drop _merge_ucs

sort pbu_code_year
merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE.dta"
ren _merge _merge_ucs

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_ALL_UCs.dta", replace



* Firm Info

gen códigofornecedor_length = length( códigofornecedor)
replace códigofornecedor = "00" + códigofornecedor if códigofornecedor_length==12
gen firm_id = códigofornecedor
sort firm_id
merge m:1 firm_id using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_MERGE.dta"
ren _merge _merge_firms

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_ALL_UCs_FIRMS.dta", replace

* Organizing

ren anoencerramento po_year
ren numerodaoc po_aux
ren finalidade po_subject
ren descriçãoprocedimentocompra po_proc_descr
ren códigoórgão bureau_code_aux
ren descriçãoórgão bureau_descr_aux
ren códigouo uo_code_aux
ren descriçãouo uo_descr_aux
ren códigounidadecompradora pbu_code_aux
ren descriçãounidadecompradora pbu_descr_aux
ren númerosequênciaitem po_item_seq
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
ren pbu_latit pbu_latit
ren pbu_longit pbu_longit
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
label variable po_proc_descr "PO Procedure description"
label variable bureau_code_aux "Bureau code"
label variable bureau_descr_aux "Bureau description"
label variable uo_code_aux "UO code"
label variable uo_descr_aux "UO description"
label variable pbu_code_aux "PBU code aux"
label variable pbu_descr_aux "PBU description aux"
label variable po_item_seq "PO item sequence"
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



global	po_info_group	po	po_subject	po_status_code	po_status_descr	po_proc_code	po_year	po_aux	m_y	year	po_proc_descr	po_item_seq	categ_item	group_item	group_item_descr	item	item_descr	item_unit	bid_price_reg	bid_green_item	bid_item_type																																																					
global	pbu_info_group	pbu_bureau_code	pbu_bureau_descr	bureau_code_aux	bureau_descr_aux	pbu_uo_code	pbu_uo_descr	uo_code_aux	uo_descr_aux	pbu_code	pbu_cnpj	pbu_descr	pbu_code_aux	pbu_descr_aux	pbu_power	pbu_type_mgmt_descr	pbu_zipcode	pbu_latit	pbu_longit	pbu_ibge_cod_uf	 pbu_city_area	pbu_fedentity_code	pbu_fedentity_descr	pbu_region_code	pbu_region_descr	pbu_city_code	pbu_city_descr	pbu_year																																																							
global	firm_info_group	firm_id	firm_code_aux	firm_descr	firm_zipcode	firm_type_code	firm_person_code	firm_headqtr_branch_code	firm_legal_nature_code	firm_simples_code	firm_latit	firm_longit	firm_city	firm_state	firm_ibge_cod_uf	firm_ibge_cod_city	firm_city_area																																																																			
global	fig firm_info_group	bid_qty	bid_price_ref	bid_price	n_firms_prop	n_firms_bids	n_firms_negot	n_firms_pref	n_bids_prop	n_bids_bids	n_bids_negot	n_bids_pref	po_winner_sum_prop	po_winner_sum_bids	po_winner_sum_negot	po_winner_sum_pref	dist_min_prop	dist_min_bids	dist_min_negot	dist_min_pref	dist_max_prop	dist_max_bids	dist_max_negot	dist_max_pref	po_winner_max_prop	po_winner_max_bids	po_winner_max_negot	po_winner_max_pref	dist_mean_prop	dist_mean_bids	dist_mean_negot	dist_mean_pref	dist_median_prop	dist_median_bids	dist_median_negot	dist_median_pref	dist_sd_prop	dist_sd_bids	dist_sd_negot	dist_sd_pref	dist_semean_prop	dist_semean_bids	dist_semean_negot	dist_semean_pref	proc_length_sec_prop	proc_length_sec_bids	proc_length_sec_negot	proc_length_sec_pref	proc_length_minutes_prop	proc_length_minutes_bids	proc_length_minutes_negot	proc_length_minutes_pref	proc_length_hours_prop	proc_length_hours_bids	proc_length_hours_negot	proc_length_hours_pref	proc_length_days_prop	proc_length_days_bids	proc_length_days_negot	proc_length_days_pref	bid_price_prop_min	bid_price_bids_min	bid_price_negot_min	bid_price_pref_min	bid_price_prop_max	bid_price_bids_max	bid_price_negot_max	bid_price_pref_max	bid_price_prop_mean	bid_price_bids_mean	bid_price_negot_mean	bid_price_pref_mean	bid_price_prop_median	bid_price_bids_median	bid_price_negot_median	bid_price_pref_median	bid_price_prop_sd	bid_price_bids_sd	bid_price_negot_sd	bid_price_pref_sd	bid_price_prop_semean	bid_price_bids_semean	bid_price_negot_semean	bid_price_pref_semean

order $po_info_group $pbu_info_group $firm_info_group $fig_info_group

destring bid_qty bid_price_ref bid_price, replace dpcomma

gen bid_total_ref = bid_qty*bid_price_ref

drop if po==""
duplicates drop po item, force
drop po_aux po_year  po_proc_descr address_firm ddd_firm códigofornecedor_length firm_id_length


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_FINAL_SOURCE_ALL.dta", replace







*** JUDICIALIZATION

keep if pbu_bureau_code == "09000"
sort item
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/JUD_S-CODES_working.dta", generate(_merge_codes)
keep if _merge_codes==3


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_S-CODES_SUBSAMPLE_FINAL_1.dta", replace

gen jud = 0
replace jud = 1 if strpos(po_subject, "JUDIC") | strpos(po_subject, "LIMINAR") | strpos(po_subject, "MANDADO") | strpos(po_subject, "MAN-DADO") | strpos(po_subject, " AJ") | strpos(po_subject, "(AJ") | strpos(po_subject, "ADMINISTRATIV")

gen adm = 0
replace adm =2 if strpos(po_subject, "ADMINISTRATIV")

gen price_reg = 0
replace price_reg =1 if strpos(po_subject, "REGISTRO DE PRECOS")

gen po_firm_winner = 1
replace po_firm_winner = 0 if firm_code_aux == "Sem Vencedor"

keep if po_firm_winner==1

tab jud
tab adm
tab price_reg

destring bid_qty bid_price_ref bid_price, replace dpcomma

gen bid_qty_log=ln(bid_qty)
gen bid_price_ref_log=ln(bid_price_ref)
gen bid_price_log=ln(bid_price)

tabstat bid_qty bid_price_ref bid_price n_firms_prop n_firms_bids n_firms_negot n_firms_pref n_bids_prop n_bids_bids n_bids_negot n_bids_pref , by(jud) statistics(mean semean) save
matrix nT1 = r(Stat1)'
matrix T1 = r(Stat2)'
matrix diff1 = [r(Stat2)-r(Stat1)]'
matrix ptcovstat1 = nT1,T1,diff1
matrix list ptcovstat1
esttab matrix(ptcovstat1) using ptcovstatmatrix1.htm, title("Pre-Treatment Covariates Mean and SEmean") replace


*tw Kdensity _pscore if _treated==1 [aw=_weight], lc(blue) || ///
*Kdensity _pscore if _treated==0 [aw=_weight], lc(red)


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD.dta", replace

export delimited using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Variables_subsample_jud_adm.csv", delimiter(";") replace

clear all
import excel "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/SUBSAMPLE_14052019.xlsx", sheet("Final") firstrow allstring
sort item
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD_SUBSAMPLE_SELECTION.dta", replace

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD.dta", clear

sort item
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD_SUBSAMPLE_SELECTION.dta"
ren _merge _merge_subsample
keep if _merge_subsample == 3

destring bid_qty bid_price_ref bid_price, replace dpcomma


tab jud
tab adm
tab price_reg
tab jud po_firm_winner
tab po_proc_code jud
tab pbu_descr jud
tab class_item_descr jud if group_item == "65" | group_item == "85"
tab group_item jud


scatter bid_price bid_qty, by(jud)

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

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD_SUBSAMPLE.dta", replace



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







*** JUDICIALIZATION 2

keep if pbu_bureau_code == "09000"
sort item
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/JUD_S-CODES_working.dta", generate(_merge_codes)
keep if _merge_codes==3


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_S-CODES_SUBSAMPLE_FINAL_2.dta", replace

drop group_item1 group_item2 group_item3 group_item4 group_item5 group_item6 group_item7 group_item8 group_item9 group_item10 group_item11 group_item12 group_item13 group_item14 group_item15 group_item16 group_item17 group_item18 group_item19 group_item20 group_item21 group_item22 group_item23 group_item24 group_item25 group_item26 group_item27 group_item28 group_item29 group_item30 group_item31 group_item32 group_item33 group_item34 group_item35 group_item36 group_item37 group_item38 group_item39 group_item40 group_item41 group_item42 group_item43 group_item44 group_item45 group_item46 group_item47 group_item48 group_item49 group_item50 group_item51 group_item52 group_item53 group_item54 group_item55 group_item56 group_item57 group_item58 group_item59 group_item60 group_item61 group_item62 group_item63 group_item64 group_item65 group_item66 group_item67 group_item68 group_item69 group_item70 group_item71 group_item72 group_item73 group_item74 group_item75 group_item76 group_item77 group_item78 class_item1 class_item2 class_item3 class_item4 class_item5 class_item6 class_item7 class_item8 class_item9 class_item10 class_item11 class_item12 class_item13 class_item14 class_item15 class_item16 class_item17 class_item18 class_item19 class_item20 class_item21 class_item22 class_item23 class_item24 class_item25 class_item26 class_item27 class_item28 class_item29 class_item30 class_item31 class_item32 class_item33 class_item34 class_item35 class_item36 class_item37 class_item38 class_item39 class_item40 class_item41 class_item42 class_item43 class_item44 class_item45 class_item46 class_item47 class_item48 class_item49 class_item50 class_item51 class_item52 class_item53 class_item54 class_item55 class_item56 class_item57 class_item58 class_item59 class_item60 class_item61 class_item62 class_item63 class_item64 class_item65 class_item66 class_item67 class_item68 class_item69 class_item70 class_item71 class_item72 class_item73 class_item74 class_item75 class_item76 class_item77 class_item78 class_item79 class_item80 class_item81 class_item82 class_item83 class_item84 class_item85 class_item86 class_item87 class_item88 class_item89 class_item90 class_item91 class_item92 class_item93 class_item94 class_item95 class_item96 class_item97 class_item98 class_item99 class_item100 class_item101 class_item102 class_item103 class_item104 class_item105 class_item106 class_item107 class_item108 class_item109 class_item110 class_item111 class_item112 class_item113 class_item114 class_item115 class_item116 class_item117 class_item118 class_item119 class_item120 class_item121 class_item122 class_item123 class_item124 class_item125 class_item126 class_item127 class_item128 class_item129 class_item130 class_item131 class_item132 class_item133 class_item134 class_item135 class_item136 class_item137 class_item138 class_item139 class_item140 class_item141 class_item142 class_item143 class_item144 class_item145 class_item146 class_item147 class_item148 class_item149 class_item150 class_item151 class_item152 class_item153 class_item154 class_item155 class_item156 class_item157 class_item158 class_item159 class_item160 class_item161 class_item162 class_item163 class_item164 class_item165 class_item166 class_item167 class_item168 class_item169 class_item170 class_item171 class_item172 class_item173 class_item174 class_item175 class_item176 class_item177 class_item178 class_item179 class_item180 class_item181 class_item182 class_item183 class_item184 class_item185 class_item186 class_item187 class_item188 class_item189 class_item190 class_item191 class_item192 class_item193 class_item194 class_item195 class_item196 class_item197 class_item198 class_item199 class_item200 class_item201 class_item202 class_item203 class_item204 class_item205 class_item206 class_item207 class_item208 class_item209 class_item210 class_item211 class_item212 class_item213 class_item214 class_item215 class_item216 class_item217 class_item218 class_item219 class_item220 class_item221 class_item222 class_item223 class_item224 class_item225 class_item226 class_item227 class_item228 class_item229 class_item230 class_item231 class_item232 class_item233 class_item234 class_item235 class_item236 class_item237 class_item238 class_item239 class_item240 class_item241 class_item242 class_item243 class_item244 class_item245 class_item246 class_item247 class_item248 class_item249 class_item250 class_item251 class_item252 class_item253 class_item254 class_item255 class_item256 class_item257 class_item258 class_item259 class_item260 class_item261 class_item262 class_item263 class_item264 class_item265 class_item266 class_item267 class_item268 class_item269 class_item270 class_item271 class_item272 class_item273 class_item274 class_item275 class_item276 class_item277 class_item278 class_item279 class_item280 class_item281 class_item282 class_item283 class_item284 class_item285 class_item286 class_item287 class_item288 class_item289 class_item290 class_item291 class_item292 class_item293 class_item294 class_item295 class_item296 class_item297 class_item298 class_item299 class_item300 class_item301 class_item302 class_item303 class_item304 class_item305 class_item306 class_item307 class_item308 class_item309 class_item310 class_item311 class_item312 class_item313 class_item314 class_item315 class_item316 class_item317 class_item318 class_item319 class_item320 class_item321 class_item322 class_item323 class_item324 class_item325 class_item326 class_item327 class_item328 class_item329 class_item330 class_item331 class_item332 class_item333 class_item334 class_item335 class_item336 class_item337 class_item338 class_item339 class_item340 class_item341 class_item342 class_item343 class_item344 class_item345 class_item346 class_item347 class_item348 class_item349 class_item350 class_item351 class_item352 class_item353 class_item354 class_item355 class_item356 class_item357 class_item358 class_item359 class_item360 class_item361 class_item362 class_item363 class_item364 class_item365 class_item366 class_item367 class_item368 class_item369 class_item370 class_item371 class_item372 class_item373 class_item374 class_item375 class_item376 class_item377 class_item378 class_item379 class_item380 class_item381 class_item382 class_item383 class_item384 class_item385 class_item386 class_item387 class_item388 class_item389 class_item390 class_item391 class_item392 class_item393 class_item394 class_item395 class_item396 class_item397 class_item398 class_item399 class_item400 class_item401 class_item402 class_item403 class_item404 class_item405 class_item406 class_item407 class_item408 class_item409 class_item410 class_item411 class_item412 class_item413 class_item414 class_item415 class_item416 class_item417 class_item418 class_item419 class_item420 class_item421 class_item422 class_item423 class_item424 class_item425 class_item426 class_item427 class_item428 class_item429 class_item430 class_item431 class_item432 class_item433 class_item434 class_item435 class_item436 class_item437 class_item438 class_item439 class_item440 class_item441 class_item442 class_item443 class_item444 class_item445 class_item446 class_item447 class_item448 class_item449 class_item450 class_item451 class_item452 class_item453 class_item454 class_item455 class_item456 class_item457 class_item458 class_item459 class_item460 class_item461 class_item462 class_item463 class_item464 class_item465 class_item466 class_item467 class_item468 class_item469 class_item470 class_item471 class_item472 class_item473 class_item474 class_item475 class_item476 class_item477 class_item478 class_item479 class_item480 class_item481 class_item482 class_item483 class_item484 class_item485 class_item486 class_item487 class_item488 class_item489 class_item490 class_item491 class_item492 class_item493 class_item494 class_item495 class_item496 class_item497 class_item498 class_item499 class_item500 class_item501 class_item502 class_item503 class_item504 class_item505 class_item506 class_item507 class_item508 class_item509 class_item510 class_item511 class_item512 class_item513 class_item514 class_item515 class_item516 class_item517 class_item518 class_item519 class_item520 class_item521 class_item522 class_item523 class_item524 class_item525 class_item526 class_item527 class_item528 class_item529 class_item530 class_item531 class_item532 class_item533 class_item534 class_item535 class_item536 class_item537 class_item538 class_item539 class_item540 class_item541 class_item542 class_item543 class_item544 class_item545 class_item546 class_item547 class_item548 class_item549 class_item550 class_item551 class_item552 class_item553 class_item554 class_item555 class_item556 class_item557 class_item558 class_item559 class_item560 class_item561 class_item562 class_item563 class_item564 class_item565 class_item566 class_item567 class_item568 class_item569 class_item570 class_item571 class_item572 class_item573 class_item574 class_item575 class_item576 class_item577 class_item578 class_item579 class_item580 class_item581 class_item582 class_item583 class_item584 class_item585 class_item586 class_item587 class_item588 class_item589 class_item590 class_item591 class_item592 class_item593 class_item594 class_item595 class_item596 class_item597 class_item598 class_item599 class_item600 class_item601 class_item602 class_item603 class_item604 class_item605 class_item606 class_item607 class_item608 class_item609 class_item610 class_item611 class_item612 class_item613 class_item614 class_item615 class_item616 class_item617 class_item618 class_item619 class_item620 class_item621 class_item622 class_item623 class_item624 class_item625 class_item626 class_item627 class_item628 class_item629 class_item630 class_item631 class_item632 class_item633 class_item634 class_item635 class_item636 class_item637 class_item638 class_item639 class_item640 class_item641 class_item642 class_item643 class_item644 class_item645 class_item646 class_item647 class_item648 class_item649 class_item650 class_item651 class_item652 class_item653 class_item654 class_item655 class_item656 class_item657 class_item658 class_item659 class_item660 class_item661 class_item662 class_item663 class_item664 class_item665 class_item666 class_item667 class_item668 class_item669 class_item670 class_item671 class_item672 class_item673 class_item674 class_item675 class_item676 class_item677 class_item678 class_item679 pbu_bureau_code1 pbu_bureau_code2 pbu_bureau_code3 pbu_bureau_code4 pbu_bureau_code5 pbu_bureau_code6 pbu_bureau_code7 pbu_bureau_code8 pbu_bureau_code9 pbu_bureau_code10 pbu_bureau_code11 pbu_bureau_code12 pbu_bureau_code13 pbu_bureau_code14 pbu_bureau_code15 pbu_bureau_code16 pbu_bureau_code17 pbu_bureau_code18 pbu_bureau_code19 pbu_bureau_code20 pbu_bureau_code21 pbu_bureau_code22 pbu_bureau_code23 pbu_bureau_code24 pbu_bureau_code25 pbu_bureau_code26 pbu_bureau_code27 pbu_bureau_code28 pbu_bureau_code29 pbu_bureau_code30 pbu_bureau_code31 pbu_bureau_code32 pbu_bureau_code33 pbu_bureau_code34 pbu_bureau_code35 pbu_bureau_code36 pbu_bureau_code37 pbu_bureau_code38 pbu_bureau_code39 pbu_bureau_code40 pbu_bureau_code41 pbu_bureau_code42 pbu_bureau_code43 pbu_bureau_code44 pbu_bureau_code45 pbu_uo_code1 pbu_uo_code2 pbu_uo_code3 pbu_uo_code4 pbu_uo_code5 pbu_uo_code6 pbu_uo_code7 pbu_uo_code8 pbu_uo_code9 pbu_uo_code10 pbu_uo_code11 pbu_uo_code12 pbu_uo_code13 pbu_uo_code14 pbu_uo_code15 pbu_uo_code16 pbu_uo_code17 pbu_uo_code18 pbu_uo_code19 pbu_uo_code20 pbu_uo_code21 pbu_uo_code22 pbu_uo_code23 pbu_uo_code24 pbu_uo_code25 pbu_uo_code26 pbu_uo_code27 pbu_uo_code28 pbu_uo_code29 pbu_uo_code30 pbu_uo_code31 pbu_uo_code32 pbu_uo_code33 pbu_uo_code34 pbu_uo_code35 pbu_uo_code36 pbu_uo_code37 pbu_uo_code38 pbu_uo_code39 pbu_uo_code40 pbu_uo_code41 pbu_uo_code42 pbu_uo_code43 pbu_uo_code44 pbu_uo_code45 pbu_uo_code46 pbu_uo_code47 pbu_uo_code48 pbu_uo_code49 pbu_uo_code50 pbu_uo_code51 pbu_uo_code52 pbu_uo_code53 pbu_uo_code54 pbu_uo_code55 pbu_uo_code56 pbu_uo_code57 pbu_uo_code58 pbu_uo_code59 pbu_uo_code60 pbu_uo_code61 pbu_uo_code62 pbu_uo_code63 pbu_uo_code64 pbu_uo_code65 pbu_uo_code66 pbu_uo_code67 pbu_uo_code68 pbu_uo_code69 pbu_uo_code70 pbu_uo_code71 pbu_uo_code72 pbu_uo_code73 pbu_uo_code74 pbu_uo_code75 pbu_uo_code76 pbu_uo_code77 pbu_uo_code78 pbu_uo_code79 pbu_uo_code80 pbu_uo_code81 pbu_uo_code82 pbu_uo_code83 pbu_uo_code84 pbu_uo_code85 pbu_uo_code86 pbu_uo_code87 pbu_uo_code88 pbu_uo_code89 pbu_uo_code90 pbu_uo_code91 pbu_uo_code92 pbu_uo_code93 pbu_uo_code94 pbu_uo_code95 pbu_uo_code96 pbu_uo_code97 pbu_uo_code98 pbu_uo_code99 pbu_uo_code100 pbu_uo_code101 pbu_uo_code102 pbu_uo_code103 pbu_uo_code104 pbu_uo_code105 pbu_uo_code106 pbu_uo_code107 pbu_uo_code108 pbu_uo_code109 pbu_uo_code110 pbu_uo_code111 pbu_uo_code112 pbu_uo_code113 pbu_uo_code114 pbu_uo_code115 pbu_uo_code116 pbu_uo_code117 pbu_uo_code118 pbu_uo_code119 pbu_uo_code120 pbu_uo_code121 pbu_uo_code122 pbu_uo_code123 pbu_uo_code124 pbu_uo_code125 pbu_uo_code126 pbu_uo_code127 pbu_uo_code128 pbu_uo_code129 pbu_uo_code130 pbu_uo_code131 pbu_uo_code132 pbu_uo_code133 pbu_uo_code134 pbu_uo_code135 pbu_uo_code136 pbu_uo_code137 pbu_uo_code138 pbu_uo_code139 pbu_uo_code140 pbu_uo_code141 pbu_uo_code142 pbu_uo_code143 pbu_uo_code144 pbu_uo_code145 pbu_uo_code146 pbu_uo_code147 pbu_uo_code148 pbu_uo_code149 pbu_uo_code150 pbu_uo_code151 pbu_uo_code152 pbu_uo_code153 pbu_uo_code154 pbu_uo_code155 pbu_uo_code156 pbu_uo_code157 pbu_uo_code158 pbu_uo_code159 pbu_uo_code160 pbu_uo_code161 pbu_uo_code162 pbu_uo_code163 pbu_uo_code164 pbu_uo_code165 pbu_uo_code166 pbu_uo_code167 pbu_uo_code168 pbu_uo_code169 pbu_uo_code170 pbu_uo_code171 pbu_uo_code172 pbu_uo_code173 pbu_uo_code174 pbu_uo_code175 pbu_uo_code176 pbu_uo_code177 pbu_uo_code178 pbu_uo_code179 pbu_uo_code180 pbu_uo_code181 pbu_uo_code182 pbu_uo_code183 pbu_uo_code184 pbu_uo_code185 pbu_uo_code186 pbu_uo_code187 pbu_uo_code188 pbu_uo_code189 pbu_uo_code190 pbu_uo_code191 pbu_uo_code192 pbu_uo_code193 pbu_uo_code194 pbu_uo_code195 pbu_uo_code196 pbu_uo_code197 pbu_code1 pbu_code2 pbu_code3 pbu_code4 pbu_code5 pbu_code6 pbu_code7 pbu_code8 pbu_code9 pbu_code10 pbu_code11 pbu_code12 pbu_code13 pbu_code14 pbu_code15 pbu_code16 pbu_code17 pbu_code18 pbu_code19 pbu_code20 pbu_code21 pbu_code22 pbu_code23 pbu_code24 pbu_code25 pbu_code26 pbu_code27 pbu_code28 pbu_code29 pbu_code30 pbu_code31 pbu_code32 pbu_code33 pbu_code34 pbu_code35 pbu_code36 pbu_code37 pbu_code38 pbu_code39 pbu_code40 pbu_code41 pbu_code42 pbu_code43 pbu_code44 pbu_code45 pbu_code46 pbu_code47 pbu_code48 pbu_code49 pbu_code50 pbu_code51 pbu_code52 pbu_code53 pbu_code54 pbu_code55 pbu_code56 pbu_code57 pbu_code58 pbu_code59 pbu_code60 pbu_code61 pbu_code62 pbu_code63 pbu_code64 pbu_code65 pbu_code66 pbu_code67 pbu_code68 pbu_code69 pbu_code70 pbu_code71 pbu_code72 pbu_code73 pbu_code74 pbu_code75 pbu_code76 pbu_code77 pbu_code78 pbu_code79 pbu_code80 pbu_code81 pbu_code82 pbu_code83 pbu_code84 pbu_code85 pbu_code86 pbu_code87 pbu_code88 pbu_code89 pbu_code90 pbu_code91 pbu_code92 pbu_code93 pbu_code94 pbu_code95 pbu_code96 pbu_code97 pbu_code98 pbu_code99 pbu_code100 pbu_code101 pbu_code102 pbu_code103 pbu_code104 pbu_code105 pbu_code106 pbu_code107 pbu_code108 pbu_code109 pbu_code110 pbu_code111 pbu_code112 pbu_code113 pbu_code114 pbu_code115 pbu_code116 pbu_code117 pbu_code118 pbu_code119 pbu_code120 pbu_code121 pbu_code122 pbu_code123 pbu_code124 pbu_code125 pbu_code126 pbu_code127 pbu_code128 pbu_code129 pbu_code130 pbu_code131 pbu_code132 pbu_code133 pbu_code134 pbu_code135 pbu_code136 pbu_code137 pbu_code138 pbu_code139 pbu_code140 pbu_code141 pbu_code142 pbu_code143 pbu_code144 pbu_code145 pbu_code146 pbu_code147 pbu_code148 pbu_code149 pbu_code150 pbu_code151 pbu_code152 pbu_code153 pbu_code154 pbu_code155 pbu_code156 pbu_code157 pbu_code158 pbu_code159 pbu_code160 pbu_code161 pbu_code162 pbu_code163 pbu_code164 pbu_code165 pbu_code166 pbu_code167 pbu_code168 pbu_code169 pbu_code170 pbu_code171 pbu_code172 pbu_code173 pbu_code174 pbu_code175 pbu_code176 pbu_code177 pbu_code178 pbu_code179 pbu_code180 pbu_code181 pbu_code182 pbu_code183 pbu_code184 pbu_code185 pbu_code186 pbu_code187 pbu_code188 pbu_code189 pbu_code190 pbu_code191 pbu_code192 pbu_code193 pbu_code194 pbu_code195 pbu_code196 pbu_code197 pbu_code198 pbu_code199 pbu_code200 pbu_code201 pbu_code202 pbu_code203 pbu_code204 pbu_code205 pbu_code206 pbu_code207 pbu_code208 pbu_code209 pbu_code210 pbu_code211 pbu_code212 pbu_code213 pbu_code214 pbu_code215 pbu_code216 pbu_code217 pbu_code218 pbu_code219 pbu_code220 pbu_code221 pbu_code222 pbu_code223 pbu_code224 pbu_code225 pbu_code226 pbu_code227 pbu_code228 pbu_code229 pbu_code230 pbu_code231 pbu_code232 pbu_code233 pbu_code234 pbu_code235 pbu_code236 pbu_code237 pbu_code238 pbu_code239 pbu_code240 pbu_code241 pbu_code242 pbu_code243 pbu_code244 pbu_code245 pbu_code246 pbu_code247 pbu_code248 pbu_code249 pbu_code250 pbu_code251 pbu_code252 pbu_code253 pbu_code254 pbu_code255 pbu_code256 pbu_code257 pbu_code258 pbu_code259 pbu_code260 pbu_code261 pbu_code262 pbu_code263 pbu_code264 pbu_code265 pbu_code266 pbu_code267 pbu_code268 pbu_code269 pbu_code270 pbu_code271 pbu_code272 pbu_code273 pbu_code274 pbu_code275 pbu_code276 pbu_code277 pbu_code278 pbu_code279 pbu_code280 pbu_code281 pbu_code282 pbu_code283 pbu_code284 pbu_code285 pbu_code286 pbu_code287 pbu_code288 pbu_code289 pbu_code290 pbu_code291 pbu_code292 pbu_code293 pbu_code294 pbu_code295 pbu_code296 pbu_code297 pbu_code298 pbu_code299 pbu_code300 pbu_code301 pbu_code302 pbu_code303 pbu_code304 pbu_code305 pbu_code306 pbu_code307 pbu_code308 pbu_code309 pbu_code310 pbu_code311 pbu_code312 pbu_code313 pbu_code314 pbu_code315 pbu_code316 pbu_code317 pbu_code318 pbu_code319 pbu_code320 pbu_code321 pbu_code322 pbu_code323 pbu_code324 pbu_code325 pbu_code326 pbu_code327 pbu_code328 pbu_code329 pbu_code330 pbu_code331 pbu_code332 pbu_code333 pbu_code334 pbu_code335 pbu_code336 pbu_code337 pbu_code338 pbu_code339 pbu_code340 pbu_code341 pbu_code342 pbu_code343 pbu_code344 pbu_code345 pbu_code346 pbu_code347 pbu_code348 pbu_code349 pbu_code350 pbu_code351 pbu_code352 pbu_code353 pbu_code354 pbu_code355 pbu_code356 pbu_code357 pbu_code358 pbu_code359 pbu_code360 pbu_code361 pbu_code362 pbu_code363 pbu_code364 pbu_code365 pbu_code366 pbu_code367 pbu_code368 pbu_code369 pbu_code370 pbu_code371 pbu_code372 pbu_code373 pbu_code374 pbu_code375 pbu_code376 pbu_code377 pbu_code378 pbu_code379 pbu_code380 pbu_code381 pbu_code382 pbu_code383 pbu_code384 pbu_code385 pbu_code386 pbu_code387 pbu_code388 pbu_code389 pbu_code390 pbu_code391 pbu_code392 pbu_code393 pbu_code394 pbu_code395 pbu_code396 pbu_code397 pbu_code398 pbu_code399 pbu_code400 pbu_code401 pbu_code402 pbu_code403 pbu_code404 pbu_code405 pbu_code406 pbu_code407 pbu_code408 pbu_code409 pbu_code410 pbu_code411 pbu_code412 pbu_code413 pbu_code414 pbu_code415 pbu_code416 pbu_code417 pbu_code418 pbu_code419 pbu_code420 pbu_code421 pbu_code422 pbu_code423 pbu_code424 pbu_code425 pbu_code426 pbu_code427 pbu_code428 pbu_code429 pbu_code430 pbu_code431 pbu_code432 pbu_code433 pbu_code434 pbu_code435 pbu_code436 pbu_code437 pbu_code438 pbu_code439 pbu_code440 pbu_code441 pbu_code442 pbu_code443 pbu_code444 pbu_code445 pbu_code446 pbu_code447 pbu_code448 pbu_code449 pbu_code450 pbu_code451 pbu_code452 pbu_code453 pbu_code454 pbu_code455 pbu_code456 pbu_code457 pbu_code458 pbu_code459 pbu_code460 pbu_code461 pbu_code462 pbu_code463 pbu_code464 pbu_code465 pbu_code466 pbu_code467 pbu_code468 pbu_code469 pbu_code470 pbu_code471 pbu_code472 pbu_code473 pbu_code474 pbu_code475 pbu_code476 pbu_code477 pbu_code478 pbu_code479 pbu_code480 pbu_code481 pbu_code482 pbu_code483 pbu_code484 pbu_code485 pbu_code486 pbu_code487 pbu_code488 pbu_code489 pbu_code490 pbu_code491 pbu_code492 pbu_code493 pbu_code494 pbu_code495 pbu_code496 pbu_code497 pbu_code498 pbu_code499 pbu_code500 pbu_code501 pbu_code502 pbu_code503 pbu_code504 pbu_code505 pbu_code506 pbu_code507 pbu_code508 pbu_code509 pbu_code510 pbu_code511 pbu_code512 pbu_code513 pbu_code514 pbu_code515 pbu_code516 pbu_code517 pbu_code518 pbu_code519 pbu_code520 pbu_code521 pbu_code522 pbu_code523 pbu_code524 pbu_code525 pbu_code526 pbu_code527 pbu_code528 pbu_code529 pbu_code530 pbu_code531 pbu_code532 pbu_code533 pbu_code534 pbu_code535 pbu_code536 pbu_code537 pbu_code538 pbu_code539 pbu_code540 pbu_code541 pbu_code542 pbu_code543 pbu_code544 pbu_code545 pbu_code546 pbu_code547 pbu_code548 pbu_code549 pbu_code550 pbu_code551 pbu_code552 pbu_code553 pbu_code554 pbu_code555 pbu_code556 pbu_code557 pbu_code558 pbu_code559 pbu_code560 pbu_code561 pbu_code562 pbu_code563 pbu_code564 pbu_code565 pbu_code566 pbu_code567 pbu_code568 pbu_code569 pbu_code570 pbu_code571 pbu_code572 pbu_code573 pbu_code574 pbu_code575 pbu_code576 pbu_code577 pbu_code578 pbu_code579 pbu_code580 pbu_code581 pbu_code582 pbu_code583 pbu_code584 pbu_code585 pbu_code586 pbu_code587 pbu_code588 pbu_code589 pbu_code590 pbu_code591 pbu_code592 pbu_code593 pbu_code594 pbu_code595 pbu_code596 pbu_code597 pbu_code598 pbu_code599 pbu_code600 pbu_code601 pbu_code602 pbu_code603 pbu_code604 pbu_code605 pbu_code606 pbu_code607 pbu_code608 pbu_code609 pbu_code610 pbu_code611 pbu_code612 pbu_code613 pbu_code614 pbu_code615 pbu_code616 pbu_code617 pbu_code618 pbu_code619 pbu_code620 pbu_code621 pbu_code622 pbu_code623 pbu_code624 pbu_code625 pbu_code626 pbu_code627 pbu_code628 pbu_code629 pbu_code630 pbu_code631 pbu_code632 pbu_code633 pbu_code634 pbu_code635 pbu_code636 pbu_code637 pbu_code638 pbu_code639 pbu_code640 pbu_code641 pbu_code642 pbu_code643 pbu_code644 pbu_code645 pbu_code646 pbu_code647 pbu_code648 pbu_code649 pbu_code650 pbu_code651 pbu_code652 pbu_code653 pbu_code654 pbu_code655 pbu_code656 pbu_code657 pbu_code658 pbu_code659 pbu_code660 pbu_code661 pbu_code662 pbu_code663 pbu_code664 pbu_code665 pbu_code666 pbu_code667 pbu_code668 pbu_code669 pbu_code670 pbu_code671 pbu_code672 pbu_code673 pbu_code674 pbu_code675 pbu_code676 pbu_code677 pbu_code678 pbu_code679 pbu_code680 pbu_code681 pbu_code682 pbu_code683 pbu_code684 pbu_code685 pbu_code686 pbu_code687 pbu_code688 pbu_code689 pbu_code690 pbu_code691 pbu_code692 pbu_code693 pbu_code694 pbu_code695 pbu_code696 pbu_code697 pbu_code698 pbu_code699 pbu_code700 pbu_code701 pbu_code702 pbu_code703 pbu_code704 pbu_code705 pbu_code706 pbu_code707 pbu_code708 pbu_code709 pbu_code710 pbu_code711 pbu_code712 pbu_code713 pbu_code714 pbu_code715 pbu_code716 pbu_code717 pbu_code718 pbu_code719 pbu_code720 pbu_code721 pbu_code722 pbu_code723 pbu_code724 pbu_code725 pbu_code726 pbu_code727 pbu_code728 pbu_code729 pbu_code730 pbu_code731 pbu_code732 pbu_code733 pbu_code734 pbu_code735 pbu_code736 pbu_code737 pbu_code738 pbu_code739 pbu_code740 pbu_code741 pbu_code742 pbu_code743 pbu_code744 pbu_code745 pbu_code746 pbu_code747 pbu_code748 pbu_code749 pbu_code750 pbu_code751 pbu_code752 pbu_code753 pbu_code754 pbu_code755 pbu_code756 pbu_code757 pbu_code758 pbu_code759 pbu_code760 pbu_code761 pbu_code762 pbu_code763 pbu_code764 pbu_code765 pbu_code766 pbu_code767 pbu_code768 pbu_code769 pbu_code770 pbu_code771 pbu_code772 pbu_code773 pbu_code774 pbu_code775 pbu_code776 pbu_code777 pbu_code778 pbu_code779 pbu_code780 pbu_code781 pbu_code782 pbu_code783 pbu_code784 pbu_code785 pbu_code786 pbu_code787 pbu_code788 pbu_code789 pbu_code790 pbu_code791 pbu_code792 pbu_code793 pbu_code794 pbu_code795 pbu_code796 pbu_code797 pbu_code798 pbu_code799 pbu_code800 pbu_code801 pbu_code802 pbu_code803 pbu_code804 pbu_code805 pbu_code806 pbu_code807 pbu_code808 pbu_code809 pbu_code810 pbu_code811 pbu_code812 pbu_code813 pbu_code814 pbu_code815 pbu_code816 pbu_code817 pbu_code818 pbu_code819 pbu_code820 pbu_code821 pbu_code822 pbu_code823 pbu_code824 pbu_code825 pbu_code826 pbu_code827 pbu_code828 pbu_code829 pbu_code830 pbu_code831 pbu_code832 pbu_code833 pbu_code834 pbu_code835 pbu_code836 pbu_code837 pbu_code838 pbu_code839 pbu_code840 pbu_code841 pbu_code842 pbu_code843 pbu_code844 pbu_code845 pbu_code846 pbu_code847 pbu_code848 pbu_code849 pbu_code850 pbu_code851 pbu_code852 pbu_code853 pbu_code854 pbu_code855 pbu_code856 pbu_code857 pbu_code858 pbu_code859 pbu_code860 pbu_code861 pbu_code862 pbu_code863 pbu_code864 pbu_code865 pbu_code866 pbu_code867 pbu_code868 pbu_code869 pbu_code870 pbu_code871 pbu_code872 pbu_code873 pbu_code874 pbu_code875 pbu_code876 pbu_code877 pbu_code878 pbu_code879 pbu_code880 pbu_code881 pbu_code882 pbu_code883 pbu_code884 pbu_code885 pbu_code886 pbu_code887 pbu_code888 pbu_code889 pbu_code890 pbu_code891 pbu_code892 pbu_code893 pbu_code894 pbu_code895 pbu_code896 pbu_code897 pbu_code898 pbu_code899 pbu_code900 pbu_code901 pbu_code902 pbu_code903 pbu_code904 pbu_code905 pbu_code906 pbu_code907 pbu_code908 pbu_code909 pbu_code910 pbu_code911 pbu_code912 pbu_code913 pbu_code914 pbu_code915 pbu_code916 pbu_code917 pbu_code918 pbu_code919 pbu_code920 pbu_code921 pbu_code922 pbu_code923 pbu_code924 pbu_code925 pbu_code926 pbu_code927 pbu_code928 pbu_code929 pbu_code930 pbu_code931 pbu_code932 pbu_code933 pbu_code934 pbu_code935 pbu_code936 pbu_code937 pbu_code938 pbu_code939 pbu_code940 pbu_code941 pbu_code942 pbu_code943 pbu_code944 pbu_code945 pbu_code946 pbu_code947 pbu_code948 pbu_code949 pbu_code950 pbu_code951 pbu_code952 pbu_code953 pbu_code954 pbu_code955 pbu_code956 pbu_code957 pbu_code958 pbu_code959 pbu_code960 pbu_code961 pbu_code962 pbu_code963 pbu_code964 pbu_code965 pbu_code966 pbu_code967 pbu_code968 pbu_code969 pbu_code970 pbu_code971 pbu_code972 pbu_code973 pbu_code974 pbu_code975 pbu_code976 pbu_code977 pbu_code978 pbu_code979 pbu_code980 pbu_code981 pbu_code982 pbu_code983 pbu_code984 pbu_code985 pbu_code986 pbu_code987 pbu_code988 pbu_code989 pbu_code990 pbu_code991 pbu_code992 pbu_code993 pbu_code994 pbu_code995 pbu_code996 pbu_code997 pbu_code998 pbu_code999 pbu_code1000 pbu_code1001 pbu_code1002 pbu_code1003 pbu_code1004 pbu_code1005 pbu_code1006 pbu_code1007 pbu_code1008 pbu_code1009 pbu_code1010 pbu_code1011 pbu_code1012 pbu_code1013 pbu_code1014 pbu_code1015 pbu_code1016 pbu_code1017 pbu_code1018 pbu_code1019 pbu_code1020 pbu_code1021 pbu_code1022 pbu_code1023 pbu_code1024 pbu_code1025 pbu_code1026 pbu_code1027 pbu_code1028 pbu_code1029 pbu_code1030 pbu_code1031 pbu_code1032 pbu_code1033 pbu_code1034 pbu_code1035 pbu_code1036 pbu_code1037 pbu_code1038 pbu_code1039 pbu_code1040 pbu_code1041 pbu_code1042 pbu_code1043 pbu_code1044 pbu_code1045 pbu_code1046 pbu_code1047 pbu_code1048 pbu_code1049 pbu_code1050 pbu_code1051 pbu_code1052 pbu_code1053 pbu_code1054 pbu_code1055 pbu_code1056 pbu_code1057 pbu_code1058 pbu_code1059 pbu_code1060 pbu_code1061 pbu_code1062 pbu_code1063 pbu_code1064 pbu_code1065 pbu_code1066 pbu_code1067 pbu_code1068 pbu_code1069 pbu_code1070 pbu_code1071 pbu_code1072 pbu_code1073 pbu_code1074 pbu_code1075 pbu_code1076 pbu_code1077 pbu_code1078 pbu_code1079 pbu_code1080 pbu_code1081 pbu_code1082 pbu_code1083 pbu_code1084 pbu_code1085 pbu_code1086 pbu_code1087 pbu_code1088 pbu_code1089 pbu_code1090 pbu_code1091 pbu_code1092 pbu_code1093 pbu_code1094 pbu_code1095 pbu_code1096 pbu_code1097 pbu_code1098 pbu_code1099 pbu_code1100 pbu_code1101 pbu_code1102 pbu_code1103 pbu_code1104 pbu_code1105 pbu_code1106 pbu_code1107 pbu_code1108 pbu_code1109 pbu_code1110 pbu_code1111 pbu_code1112 pbu_code1113 pbu_code1114 pbu_code1115 pbu_code1116 pbu_code1117 pbu_code1118 pbu_code1119 pbu_code1120 pbu_code1121 pbu_code1122 pbu_code1123 pbu_code1124 pbu_code1125 pbu_code1126 pbu_code1127 pbu_code1128 pbu_code1129 pbu_code1130 pbu_code1131 pbu_code1132 pbu_code1133 pbu_code1134 pbu_code1135 pbu_code1136 pbu_code1137 pbu_code1138 pbu_code1139 pbu_code1140 pbu_code1141 pbu_code1142 pbu_code1143 pbu_code1144 pbu_code1145 pbu_code1146 pbu_code1147 pbu_code1148 pbu_code1149 pbu_code1150 pbu_code1151 pbu_code1152 pbu_code1153 pbu_code1154 pbu_code1155 pbu_code1156 pbu_code1157 pbu_code1158 pbu_code1159 pbu_code1160 pbu_code1161 pbu_code1162 pbu_code1163 pbu_code1164 pbu_code1165 pbu_code1166 pbu_code1167 pbu_code1168 pbu_code1169 pbu_code1170 pbu_code1171 pbu_code1172 pbu_code1173 pbu_code1174 pbu_code1175 pbu_code1176 pbu_code1177 pbu_code1178 pbu_code1179 pbu_code1180 pbu_code1181 pbu_code1182 pbu_code1183 pbu_code1184 pbu_code1185 pbu_code1186 pbu_code1187 pbu_code1188 pbu_code1189 pbu_code1190 pbu_code1191 pbu_code1192 pbu_code1193 pbu_code1194 pbu_code1195 pbu_code1196 pbu_code1197 pbu_code1198 pbu_code1199 pbu_code1200 pbu_code1201 pbu_code1202 pbu_code1203 pbu_code1204 pbu_code1205 pbu_code1206 pbu_code1207 pbu_code1208 pbu_code1209 pbu_code1210 pbu_code1211 pbu_code1212 pbu_code1213 pbu_code1214 pbu_code1215 pbu_code1216 pbu_code1217 pbu_code1218 pbu_code1219 pbu_code1220 pbu_code1221 pbu_code1222 pbu_code1223 pbu_code1224 pbu_code1225 pbu_code1226 pbu_code1227 pbu_code1228 pbu_code1229 pbu_code1230 pbu_code1231 pbu_code1232 pbu_code1233 pbu_code1234 pbu_code1235 pbu_code1236 pbu_code1237 pbu_code1238 pbu_code1239 pbu_code1240 pbu_code1241 pbu_code1242 pbu_code1243 pbu_code1244 pbu_code1245 pbu_code1246 pbu_code1247 pbu_code1248 pbu_code1249 pbu_code1250 pbu_code1251 pbu_code1252 pbu_code1253 pbu_code1254 pbu_code1255 pbu_code1256 pbu_code1257 pbu_code1258 pbu_code1259 pbu_code1260 pbu_code1261 pbu_code1262 pbu_code1263 pbu_code1264 pbu_code1265 pbu_code1266 pbu_code1267 pbu_code1268 pbu_code1269 pbu_code1270 pbu_code1271 pbu_code1272 pbu_code1273 pbu_code1274 pbu_code1275 pbu_code1276 pbu_code1277 pbu_code1278 pbu_code1279 pbu_code1280 pbu_code1281 pbu_code1282 pbu_code1283 pbu_code1284 pbu_code1285 pbu_code1286 pbu_code1287 pbu_code1288 pbu_code1289 pbu_code1290 pbu_code1291 pbu_code1292 pbu_code1293 pbu_code1294 pbu_code1295 pbu_code1296 pbu_code1297 pbu_code1298 pbu_code1299 pbu_code1300 pbu_code1301 pbu_code1302 pbu_code1303 pbu_code1304 pbu_code1305 pbu_code1306 pbu_code1307 pbu_code1308 pbu_code1309 pbu_code1310 pbu_code1311 pbu_code1312 pbu_code1313 pbu_code1314 pbu_code1315 pbu_code1316 pbu_code1317 pbu_code1318 pbu_code1319 pbu_code1320 pbu_code1321 pbu_code1322 pbu_code1323 pbu_code1324 pbu_code1325 pbu_code1326 pbu_code1327 pbu_code1328 pbu_code1329 pbu_code1330 pbu_code1331 pbu_code1332 pbu_code1333 pbu_code1334 pbu_code1335 pbu_code1336 pbu_code1337 pbu_code1338 pbu_code1339 pbu_code1340 pbu_code1341 pbu_code1342 pbu_code1343 pbu_code1344 pbu_code1345 pbu_code1346
tab group_item, generate(dgroup_item)
tab class_item, generate(dclass_item)
tab item, generate(ditem)
tab pbu_uo_code, generate(dpbu_uo_code)
tab pbu_code, generate(dpbu_code)
tab pbu_bureau_code, generate(dpbu_bureau_code)

gen jud = 0
replace jud = 1 if strpos(po_subject, "JUDIC") | strpos(po_subject, "LIMINAR") | strpos(po_subject, "MANDADO") | strpos(po_subject, "MAN-DADO") | strpos(po_subject, " AJ")

gen adm = 0
replace adm =2 if strpos(po_subject, "ADMINISTRATIV")

gen price_reg = 0
replace price_reg =1 if strpos(po_subject, "REGISTRO DE PRECOS")

gen po_firm_winner = 1
replace po_firm_winner = 0 if firm_id == "00Sem Vencedor"

tab jud
tab adm
tab price_reg

destring bid_qty bid_price_ref bid_price, replace dpcomma

gen bid_qty_log=ln(bid_qty)
gen bid_price_ref_log=ln(bid_price_ref)
gen bid_price_log=ln(bid_price)

tabstat bid_qty bid_price_ref bid_price n_firms_prop n_firms_bids n_firms_negot n_firms_pref n_bids_prop n_bids_bids n_bids_negot n_bids_pref , by(jud) statistics(mean semean) save
matrix nT1 = r(Stat1)'
matrix T1 = r(Stat2)'
matrix diff1 = [r(Stat2)-r(Stat1)]'
matrix ptcovstat1 = nT1,T1,diff1
matrix list ptcovstat1
esttab matrix(ptcovstat1) using ptcovstatmatrix1.htm, title("Pre-Treatment Covariates Mean and SEmean") replace


tw Kdensity _pscore if _treated==1 [aw=_weight], lc(blue) || Kdensity _pscore if _treated==0 [aw=_weight], lc(red)


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD.dta", replace

export delimited using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Variables_subsample_jud_adm.csv", delimiter(";") replace

clear all
import excel "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/SUBSAMPLE_14052019.xlsx", sheet("Final") firstrow allstring
sort item
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD_SUBSAMPLE_SELECTION.dta", replace

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD.dta", clear

sort item
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD_SUBSAMPLE_SELECTION.dta"
ren _merge _merge_subsample
keep if _merge_subsample == 3

destring bid_qty bid_price_ref bid_price, replace dpcomma


tab jud
tab adm
tab price_reg
tab jud po_firm_winner
tab po_proc_code jud
tab pbu_descr jud
tab class_item_descr jud if group_item == "65" | group_item == "85"
tab group_item jud


scatter bid_price bid_qty, by(jud)

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

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_JUD_SUBSAMPLE.dta", replace



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



use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Papers/BEC_PAPER_1_JUD.dta" 
drop group_item1-pbu_code1346
tab padronizadosus
drop if padronizadosus=="Não"
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Papers/BEC_PAPER_1_JUD_SUS_all.dta"
tabulate item, generate(ditem)
tabulate pbu_code, generate(dpbu_code)
psmatch2 jud bid_qty_log ditem* dpbu_code* m_y, outcome(bid_price_log) n(5)
psmatch2 jud bid_qty_log ditem* m_y, outcome(bid_price_log) n(5)
psmatch2 jud bid_qty_log ditem*, outcome(bid_price_log) n(5)
keep if nowinner==0
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Papers/BEC_PAPER_1_JUD_SUS_all_winners_only.dta"
psmatch2 jud bid_qty_log ditem*, outcome(bid_price_log) n(5)
psmatch2 jud bid_qty_log ditem*, outcome(bid_price_log) common n(5)
psmatch2 jud bid_qty_log ditem*, outcome(bid_price_log) common n(30)
psmatch2 jud bid_qty_log ditem*, outcome(bid_price_log) common n(1)
psmatch2 jud bid_qty_log ditem* m_y, outcome(bid_price_log) common n(1)
hist _pscore
tw Kdensity _pscore if _treated==1 [aw=_weight], lc(blue) || Kdensity _pscore if _treated==0 [aw=_weight], lc(red)
psmatch2 jud bid_qty_log ditem* m_y, outcome(bid_price_log) common n(2)
psmatch2 jud bid_qty_log ditem* m_y, outcome(bid_price_log) common n(20)
tw Kdensity _pscore if _treated==1 [aw=_weight], lc(blue) || Kdensity _pscore if _treated==0 [aw=_weight], lc(red)
twoway (kdensity _pscore if _treated==1 [aw=_weight], lc(blue)) (kdensity _pscore if _treated==0 [aw=_weight], lpattern(dash) lc(red)), legend( label(1 "treated") label( 2 "control")) xtitle("propensity score")
keep if bid_item_type==1
tab categ_item
tab pbu_fedentity_code
tab pbu_fedentity_descr
tab pbu_region_descr
tab pbu_region_descr jud
tab pbu_city_descr jud

