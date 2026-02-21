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
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/ITENS/ITEM 22.04.2019.csv", encoding(utf8) stringcols(6 8 10 13 12 15 17)
gen po_item_number_firm = numerodaoc + códigoitem + númerosequênciaitem + códigofornecedor
gen key1_merge = numerodaoc + códigoitem
sort key1_merge
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Collapse_2.dta", replace


merge m:1 key1_merge using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Collapse_1_Final.dta"
ren _merge _merge_collapse


gen winner = 1
replace winner = 0 if códigofornecedor == "Sem Vencedor"
label variable winner "1=if there is a winner firm;0=otherwise"
gen check_po_status = 1
replace check_po_status = 0 if descriçãoofertadecomprastatus== po_status
drop descriçãoofertadecomprastatus códigogrupo descgrupoitem códigoclasse descclasseitem códigoitem descitem item_unit _merge_collapse

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC.dta", replace



* UCs info


sort pbu_code_year
merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE.dta"
ren _merge _merge_ucs


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_UCs.dta", replace



* Firm Info

gen códigofornecedor_length = length( códigofornecedor)
replace códigofornecedor = "00" + códigofornecedor if códigofornecedor_length==12
gen firm_id = códigofornecedor
sort firm_id
merge m:1 firm_id using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_MERGE.dta"
ren _merge _merge_firms

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_UCs_FIRMS.dta", replace

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

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_FINAL_SOURCE.dta", replace

drop if po==""
duplicates drop po item, force
drop po_aux po_year  po_proc_descr address_firm ddd_firm códigofornecedor_length firm_id_length
drop in 3349339/3362983
drop in 1/303

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_FINAL_SOURCE_1.dta", replace




*** JUDICIALIZATION

keep if pbu_bureau_code == "09000"
sort item
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BACKUP/FINAL/S-CODES_SUBSAMPLE.dta", generate(_merge_codes)
keep if _merge_codes==3


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_S-CODES_SUBSAMPLE_FINAL.dta", replace

gen jud = 0
replace jud = 1 if strpos(po_subject, "JUDIC") | strpos(po_subject, "LIMINAR") | strpos(po_subject, "MANDADO") | strpos(po_subject, "MAN-DADO") 

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


scatter bid_price_log bid_qty_log, by(jud)

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
