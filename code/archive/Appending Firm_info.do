clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2019_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2019.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2018_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2018.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2017_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2017.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2016_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2016.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2015_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2015.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2014_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2014.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2013_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2013.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2012_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2012.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2011_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2011.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2010_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2010.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2009_merge.dta", clear
keep  po firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_2009.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_MERGE.dta", clear
gen po_firm_id = po + firm_id
duplicates drop firm_id_zipcode, force
sort firm_zipcode

merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Geocoding_firm_zipcode.dta"
ren _merge _merge_firm_geoc_final
drop if _merge_firm_geoc==2
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Firm_info_MERGE.dta.dta", replace


