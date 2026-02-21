*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1" 			// Defining Main Directory

*------------------------------------------------------------------------------------------------------------------------------------------------
**** Preparing final file: lance a lance

forvalues i=1/21 {

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV"
import delimited LANCES_`i'.csv, encoding(UTF-8) stringcols(_all)

drop diamêsencerramento	dataocagendamento	dataoccriacao	dataocencerramento	finalidade	códigocategoria	descunidadefornecimento	v32	quantidadedeoc	quantidadefornecedorparticipante	descriçãostatusfornecedor	datacadastro	descriçãostatusfornecedorbec	v48	descriçãofornecedorstatus	descriçãobairrofornecedor	descriçãoendereçofornecedor	descriçãopaísfornecedor	razãosocial	diamêsagendamento	códigomunicípiodeentrega	códdescmunicípiodeentrega	códigoregiãodeentrega	códdescregiãodeentrega	códigoofertadecomprastatus

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
save LANCES_`i'.dta, replace
clear all
}

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV"
import delimited LANCES_22.csv, encoding(UTF-8) stringcols(_all)

keep mêsanoencerramento	descriçãoprocedimentocompra	numerodaoc	ataregistrodepreço	desccategoriaitem	códigoclasse	descclasseitem	códigogrupo	descgrupoitem	códigoitem	descitem	seloverde	valorunitárioproposta	datahrproposta	valorunitarionegociado	valorunitárioreferência	quantidadenegociada	quantidadefornecedorvencedor	códigofornecedor	descriçãoenquadramento	descriçãofisicajurídica	descriçãomatrizfilial	descriçãonaturezajurídica	descriçãorazãosocial	descriçãotipoempresa	descriçãosimplesnacional	descriçãopropostastatus	descriçãogrupopropostastatus	descriçãofasesoc	códigounidadecompradora	descriçãounidadecompradora	descriçãomunicípiofornecedor	descriçãouffornecedor	descriçãotipoendereçofornecedor	códigocepfornecedor	descriçãomunicípiodeentrega	descriçãoregiãodeentrega	descriçãoofertadecomprastatus

ren quantidadefornecedorvencedor quantidadeitemvencedor

gen flagvencedor=quantidadeitemvencedor
gen valortotalproposta="0"
gen propostavencedorprimeiro="0"
gen valormínimounitárioproposta="0"
gen valormáximounitárioproposta="0"
gen valortotalnegociado="0"

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
save LANCES_22.dta, replace

clear all


cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
use LANCES_1.dta, clear

forvalues i=2/22 {
	append using LANCES_`i'.dta
}


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/LANCES_Final_Semester.dta", replace






**** Simplifying files: grouping variables


egen proc_compra = group(descriçãoprocedimentocompra)
drop descriçãoprocedimentocompra
label variable proc_compra "1=CONVITE;2=DISPENSA;3=PREGÃO"

egen reg_precos = group(ataregistrodepreço)
drop ataregistrodepreço
label variable reg_precos "1=N;2=S"

egen categ_item = group(desccategoriaitem)
drop desccategoriaitem
label variable categ_item "1=MATERIAL;2=SERVIÇO"

egen item_verde = group(seloverde)
drop seloverde
replace item_verde=1 if item_verde==.
label variable item_verde "1=N;2=S"

drop propostavencedorprimeiro

gen ldescriçãoenquadramento=lower(descriçãoenquadramento)
gen lldescriçãoenquadramento = lower(ustrto(ustrnormalize(ldescriçãoenquadramento , "nfd"), "ascii", 2))
egen fornec_enquad = group(lldescriçãoenquadramento)
drop ldescriçãoenquadramento lldescriçãoenquadramento descriçãoenquadramento
label variable fornec_enquad "1=COOP;2=COOP DIR_PREF;3=NCAD;4=EPP;5=ME;6=OUTROS"

egen fornec_pessoa = group(descriçãofisicajurídica)
drop descriçãofisicajurídica
label variable fornec_pessoa "1=FISICA;2=JURIDICA;3=SEM CAD"

egen fornec_mat_filial = group(descriçãomatrizfilial)
drop descriçãomatrizfilial
label variable fornec_mat_filial "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CAD"

drop descriçãotipoempresa descriçãosimplesnacional

egen props_grupo_status = group(descriçãogrupopropostastatus)
drop descriçãogrupopropostastatus
label variable props_grupo_status "1=CLASSIF;2=DESCLASSIF;3=INVALIDO;4=N/A;5=VALIDO"

egen fase_oc = group(descriçãofasesoc)
drop descriçãofasesoc
label variable fase_oc "1=ADESAO MELH OF;2=PROPS;3=LANCES;4=NEG;5=N/A;6=PREF ME/EPP;7=REALINH COOP"


egen fornec_tipo_end = group(descriçãotipoendereçofornecedor)
drop descriçãotipoendereçofornecedor
label variable fornec_tipo_end "1=CORRESPOND;2=FILIAL;3=REPRESENT;4=SEDE;5=SEM GANHADOR"

gen ldescriçãoofertadecomprastatus= descriçãoofertadecomprastatus
replace ldescriçãoofertadecomprastatus="CANCELADA" if descriçãoofertadecomprastatus=="CANCELADA SÓ NA BAIXA"
replace ldescriçãoofertadecomprastatus="ENCERRADO COM VENCEDOR" if descriçãoofertadecomprastatus=="ENCERRADA COM VENCEDOR"
replace ldescriçãoofertadecomprastatus="ENCERRADO SEM VENCEDOR" if descriçãoofertadecomprastatus=="ENCERRADA SEM VENCEDOR"
replace ldescriçãoofertadecomprastatus="CANCELADA" if descriçãoofertadecomprastatus=="OC CANCELADA"
drop descriçãoofertadecomprastatus
ren ldescriçãoofertadecomprastatus oc_status

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/LANCES_Final_Semester_Simpl.dta", replace






**** Separating files into procedures: 1=CONVITE; 2=DISPENSA; 3=PREGAO

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/LANCES_Final_Semester_Simpl.dta", clear

preserve

keep if proc_compra==1
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
save Final_Semester_proc_1.dta, replace

restore 


preserve

keep if proc_compra==2
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
save Final_Semester_proc_2.dta, replace

restore 

keep if proc_compra==3
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
save Final_Semester_proc_3.dta, replace

clear all



****** File 3: PREGAO

clear all
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
use Final_Semester_proc_3.dta, clear

drop if fase_oc==5

gen flag_check=0
replace flag_check=1 if flagvencedor==quantidadeitemvencedor
replace quantidadeitemvencedor="1" if flag_check==0
drop flag_check

gen data = mêsanoencerramento

destring data, replace
gen data1 = monthly(data, "MY")
format data1 %tm

split data, p("/") gen(substr)
drop data
ren substr1 mês
ren substr2 ano
ren data1 data
destring mês, replace
destring ano, replace

gen chave1= numerodaoc+ códigoitem
sort chave1


drop valorunitárioreferência valorunitarionegociado  valormínimounitárioproposta valormáximounitárioproposta

gen qty_oferta=qtdeofertadecompraitemnegociado
destring qty_oferta, replace dpcomma
drop qtdeofertadecompraitemnegociado
replace qty_oferta=0 if qty_oferta==.

merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2_Final_Semester.dta", generate(_merge_chave1)
drop if _merge_chave1==2

gen qty_oferta2=quantidadenegociada
destring qty_oferta2, replace dpcomma
drop quantidadenegociada
replace qty_oferta2=0 if qty_oferta2==.

destring valortotalproposta valorunitárioproposta valortotalnegociado  preco_ref preco_final mêsanoencerramento, replace dpcomma

replace valortotalnegociado=0 if valortotalnegociado==.

preserve

collapse (max) qty_max=qty_oferta qty_max2=qty_oferta2 valor_total_neg_max=valortotalnegociado, by(chave1)
sort chave1
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_pregao.dta", replace

restore

sort chave1
merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_pregao.dta", generate(_merge_pregao_qty)
drop qty_oferta2

gen qty_max3=qty_max
replace qty_max3=qty_max2 if qty_max==0 & qty_max2>0
drop qty_max qty_max2 qty_oferta  _merge_chave1 _merge_pregao_qty
ren qty_max3 qtde


egen me_epp=group(excl_ME_EPP)
label variable me_epp "1=N;2=S"
drop excl_ME_EPP mêsanoencerramento


*** UC Geocoding

gen pbu_year=ano
tostring pbu_year, replace
gen pbu_code_year= códigounidadecompradora+pbu_year
sort pbu_code_year

merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE_cities_Final_Semester.dta", generate(_merge_uc)

keep if _merge_uc==3
drop dupl _merge_uc


*** Firms Geocoding

sort firm_cnpj
merge m:1 firm_cnpj using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Firms_Final_Semester_pregao_simpl_geoc.dta", generate(_merge_geoc)
drop if _merge_geoc==1
drop _merge_geoc 

drop tamanho_cep

geodist pbu_latit pbu_longit fornec_latitude fornec_longitude , generate(dist)
gen dist1=dist
replace dist1=0.05 if dist==0

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_3_final.dta", replace



*** Parei aqui

****** File 1: CONVITE



cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
use Final_Semester_proc_1.dta, clear

replace fase_oc=2

gen flag_check=0
replace flag_check=1 if flagvencedor==quantidadeitemvencedor
replace quantidadeitemvencedor="1" if flag_check==0
drop flag_check

gen data = mêsanoencerramento

destring data, replace
gen data1 = monthly(data, "MY")
format data1 %tm

split data, p("/") gen(substr)
drop data
ren substr1 mês
ren substr2 ano
ren data1 data
destring mês, replace
destring ano, replace

*
gen chave1= numerodaoc+ códigoitem
sort chave1

drop valorunitárioreferência valorunitarionegociado  valormínimounitárioproposta valormáximounitárioproposta

gen qty_oferta=qtdeofertadecompraitemnegociado
destring qty_oferta, replace dpcomma
drop qtdeofertadecompraitemnegociado
replace qty_oferta=0 if qty_oferta==.



merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2_Final_Semester.dta", generate(_merge_chave1)
drop if _merge_chave1==2

gen qty_oferta2=quantidadenegociada
destring qty_oferta2, replace dpcomma
drop quantidadenegociada
replace qty_oferta2=0 if qty_oferta2==.

preserve

collapse (max) qty_max=qty_oferta qty_max2=qty_oferta2, by(chave1)
sort chave1
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_convite.dta", replace

restore

sort chave1
merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_convite.dta", generate(_merge_pregao_qty)


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_1.dta", replace


****** File 2: DISPENSA


cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
use Final_Semester_proc_2.dta, clear

replace fase_oc=3

gen flag_check=0
replace flag_check=1 if flagvencedor==quantidadeitemvencedor
replace quantidadeitemvencedor="1" if flag_check==0
drop flag_check

gen data = mêsanoencerramento

destring data, replace
gen data1 = monthly(data, "MY")
format data1 %tm

split data, p("/") gen(substr)
drop data
ren substr1 mês
ren substr2 ano
ren data1 data
destring mês, replace
destring ano, replace

*
gen chave1= numerodaoc+ códigoitem
sort chave1

drop valorunitárioreferência valorunitarionegociado  valormínimounitárioproposta valormáximounitárioproposta

gen qty_oferta=qtdeofertadecompraitemnegociado
destring qty_oferta, replace dpcomma
drop qtdeofertadecompraitemnegociado
replace qty_oferta=0 if qty_oferta==.


merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2_Final_Semester.dta", generate(_merge_chave1)
drop if _merge_chave1==2

gen qty_oferta2=quantidadenegociada
destring qty_oferta2, replace dpcomma
drop quantidadenegociada
replace qty_oferta2=0 if qty_oferta2==.

preserve

collapse (max) qty_max=qty_oferta qty_max2=qty_oferta2, by(chave1)
sort chave1
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_dispensa.dta", replace

restore

sort chave1
merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_dispensa.dta", generate(_merge_pregao_qty)




save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_2.dta", replace















********* File 4: ITENS (Collapse2_Final_Semester)

keep numerodaoc códigoórgão descriçãoórgão códigouo descriçãouo códigoitem participaçãoexclusivameeppcooper códigofornecedor valorunitáriodereferência valorunitárionegociado
ren valorunitáriodereferência preco_ref
ren valorunitárionegociado preco_final
ren participaçãoexclusivameeppcooper excl_ME_EPP
gen chave1= numerodaoc+ códigoitem