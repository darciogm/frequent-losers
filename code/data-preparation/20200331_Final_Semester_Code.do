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






********************* File 1: PREGAO

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



geodist pbu_latit pbu_longit fornec_latitude fornec_longitude , generate(dist)
gen dist1=dist
replace dist1=0.05 if dist==0

gen bid_status=0
replace bid_status=1 if descriçãopropostastatus=="CLASSIFICADA" | descriçãopropostastatus=="VÁLIDO E CONFIRMADO"



save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_3_final.dta", replace




*** Auctions Info

* By OC + Item + OC_Phase

*** Ranking bids
keep if bid_status==1
bysort numerodaoc códigoitem fase_oc (valorunitárioproposta) : gen rank = _n
by numerodaoc códigoitem fase_oc: egen bids_sum = max(rank)

*** Identifying distinct participant firms
by numerodaoc códigoitem fase_oc códigofornecedor, sort: gen particip_firm = _n == 1


*** Counting participant firms
by numerodaoc códigoitem fase_oc: egen particip_firm_sum = total(particip_firm)


*** Counting distinct firms by porte de empresa
bysort numerodaoc códigoitem fase_oc: egen n_firms_me_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="01"
bysort numerodaoc códigoitem fase_oc: egen n_firms_epp_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="03"
bysort numerodaoc códigoitem fase_oc: egen n_firms_outros_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="05"

replace n_firms_me_aux=0 if n_firms_me_aux==.
replace n_firms_epp_aux=0 if n_firms_epp_aux==.
replace n_firms_outros_aux=0 if n_firms_outros_aux==.

bysort numerodaoc códigoitem fase_oc: egen n_firms_me = max(n_firms_me_aux)
bysort numerodaoc códigoitem fase_oc: egen n_firms_epp = max(n_firms_epp_aux)
bysort numerodaoc códigoitem fase_oc: egen n_firms_outros = max(n_firms_outros_aux)


*** Adjusting Cities and States para fornecedores
merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Cep/qualcep/tabela_integrada_final.dta", generate(_merge_cep_fornec)
drop if _merge_cep_fornec==2
replace descriçãouffornecedor=estado_final if descriçãouffornecedor=="SEM GANHADOR"
replace descriçãomunicípiofornecedor = cidade_final if descriçãomunicípiofornecedor =="SEM GANHADOR"
replace descriçãouffornecedor="SÃO PAULO" if descriçãouffornecedor=="SAO PAULO"
drop  cidade cod_cidade uf estado cod_estado cidade_final estado_final _merge_cep_fornec


*** Same municipality: PBU and Fornecedor

gen same_municip=0
replace same_municip=1 if pbu_city_descr==descriçãomunicípiofornecedor

bysort numerodaoc códigoitem fase_oc: egen n_same_municip_aux = total(particip_firm) if particip_firm==1 & same_municip==1
replace n_same_municip_aux=0 if n_same_municip_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_same_municip = max(n_same_municip_aux)

*** Fornecedor at Estado de SP?

gen fornec_estado_SP=0
replace fornec_estado_SP=1 if  descriçãouffornecedor=="SÃO PAULO"

bysort numerodaoc códigoitem fase_oc: egen n_fornec_estado_SP_aux = total(particip_firm) if particip_firm==1 & fornec_estado_SP==1
replace n_fornec_estado_SP_aux=0 if n_fornec_estado_SP_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_estado_SP = max(n_fornec_estado_SP_aux)

*** Fornecedor at Sao Paulo City

gen fornec_city_SP=0
replace fornec_city_SP=1 if  descriçãomunicípiofornecedor=="SAO PAULO"

bysort numerodaoc códigoitem fase_oc: egen n_fornec_city_SP_aux = total(particip_firm) if particip_firm==1 & fornec_city_SP==1
replace n_fornec_city_SP_aux=0 if n_fornec_city_SP_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_city_SP = max(n_fornec_city_SP_aux)



*** Info about bids
by numerodaoc códigoitem fase_oc: egen min_bid = min(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen max_bid = max(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen mean_bid = mean(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen median_bid = median(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen sd_bid = sd(valorunitárioproposta)

by numerodaoc códigoitem fase_oc: egen p10_bid_phase = pctile(valorunitárioproposta), p(10)
by numerodaoc códigoitem fase_oc: egen p20_bid_phase = pctile(valorunitárioproposta), p(20)
by numerodaoc códigoitem fase_oc: egen p30_bid_phase = pctile(valorunitárioproposta), p(30)
by numerodaoc códigoitem fase_oc: egen p40_bid_phase = pctile(valorunitárioproposta), p(40)
by numerodaoc códigoitem fase_oc: egen p60_bid_phase = pctile(valorunitárioproposta), p(60)
by numerodaoc códigoitem fase_oc: egen p70_bid_phase = pctile(valorunitárioproposta), p(70)
by numerodaoc códigoitem fase_oc: egen p80_bid_phase = pctile(valorunitárioproposta), p(80)
by numerodaoc códigoitem fase_oc: egen p90_bid_phase = pctile(valorunitárioproposta), p(90)


*** Info about distance
by numerodaoc códigoitem fase_oc: egen min_dist = min(dist1)
by numerodaoc códigoitem fase_oc: egen max_dist = max(dist1)

bysort numerodaoc códigoitem fase_oc: egen mean_dist_certo = mean(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen mean_dist_certo1=max(mean_dist_certo)
ren mean_dist_certo1 mean_dist
drop mean_dist_certo

bysort numerodaoc códigoitem fase_oc: egen median_dist_certo = median(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen median_dist_certo1=max(median_dist_certo)
ren median_dist_certo1 median_dist
drop median_dist_certo

bysort numerodaoc códigoitem fase_oc: egen sd_dist_certo = sd(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen sd_dist_certo1=max(sd_dist_certo)
ren sd_dist_certo1 sd_dist
drop sd_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p10_dist_certo = pctile(dist1) if particip_firm==1, p(10)
bysort numerodaoc códigoitem fase_oc: egen p10_dist_phase=max(p10_dist_certo)
drop p10_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p20_dist_certo = pctile(dist1) if particip_firm==1, p(20)
bysort numerodaoc códigoitem fase_oc: egen p20_dist_phase=max(p20_dist_certo)
drop p20_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p30_dist_certo = pctile(dist1) if particip_firm==1, p(30)
bysort numerodaoc códigoitem fase_oc: egen p30_dist_phase=max(p30_dist_certo)
drop p30_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p40_dist_certo = pctile(dist1) if particip_firm==1, p(40)
bysort numerodaoc códigoitem fase_oc: egen p40_dist_phase=max(p40_dist_certo)
drop p40_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p60_dist_certo = pctile(dist1) if particip_firm==1, p(60)
bysort numerodaoc códigoitem fase_oc: egen p60_dist_phase=max(p60_dist_certo)
drop p60_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p70_dist_certo = pctile(dist1) if particip_firm==1, p(70)
bysort numerodaoc códigoitem fase_oc: egen p70_dist_phase=max(p70_dist_certo)
drop p70_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p80_dist_certo = pctile(dist1) if particip_firm==1, p(80)
bysort numerodaoc códigoitem fase_oc: egen p80_dist_phase=max(p80_dist_certo)
drop p80_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p90_dist_certo = pctile(dist1) if particip_firm==1, p(90)
bysort numerodaoc códigoitem fase_oc: egen p90_dist_phase=max(p90_dist_certo)
drop p90_dist_certo


*** Info about firm age (months)
by numerodaoc códigoitem fase_oc: egen min_firm_age_phase = min(firm_age)
by numerodaoc códigoitem fase_oc: egen max_firm_age_phase = max(firm_age)

bysort numerodaoc códigoitem fase_oc: egen mean_firm_age_phase_certo = mean(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen mean_firm_age_phase_certo1=max(mean_firm_age_phase_certo)
ren mean_firm_age_phase_certo1 mean_firm_age_phase
drop mean_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen median_firm_age_phase_certo = median(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen median_firm_age_phase_certo1=max(median_firm_age_phase_certo)
ren median_firm_age_phase_certo1 median_firm_age_phase
drop median_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen sd_firm_age_phase_certo = sd(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen sd_firm_age_phase_certo1=max(sd_firm_age_phase_certo)
ren sd_firm_age_phase_certo1 sd_firm_age_phase
drop sd_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p10_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(10)
bysort numerodaoc códigoitem fase_oc: egen p10_firm_age_phase_phase=max(p10_firm_age_phase_certo)
drop p10_firm_age_phase_certo


bysort numerodaoc códigoitem fase_oc: egen p20_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(20)
bysort numerodaoc códigoitem fase_oc: egen p20_firm_age_phase_phase=max(p20_firm_age_phase_certo)
drop p20_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p30_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(30)
bysort numerodaoc códigoitem fase_oc: egen p30_firm_age_phase_phase=max(p30_firm_age_phase_certo)
drop p30_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p40_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(40)
bysort numerodaoc códigoitem fase_oc: egen p40_firm_age_phase_phase=max(p40_firm_age_phase_certo)
drop p40_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p60_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(60)
bysort numerodaoc códigoitem fase_oc: egen p60_firm_age_phase_phase=max(p60_firm_age_phase_certo)
drop p60_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p70_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(70)
bysort numerodaoc códigoitem fase_oc: egen p70_firm_age_phase_phase=max(p70_firm_age_phase_certo)
drop p70_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p80_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(80)
bysort numerodaoc códigoitem fase_oc: egen p80_firm_age_phase_phase=max(p80_firm_age_phase_certo)
drop p80_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p90_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(90)
bysort numerodaoc códigoitem fase_oc: egen p90_firm_age_phase_phase=max(p90_firm_age_phase_certo)
drop p90_firm_age_phase_certo


ren p10_firm_age_phase_phase p10_firm_age_phase
ren p20_firm_age_phase_phase p20_firm_age_phase
ren p30_firm_age_phase_phase p30_firm_age_phase
ren p40_firm_age_phase_phase p40_firm_age_phase
ren p60_firm_age_phase_phase p60_firm_age_phase
ren p70_firm_age_phase_phase p70_firm_age_phase
ren p80_firm_age_phase_phase p80_firm_age_phase
ren p90_firm_age_phase_phase p90_firm_age_phase


*** Info about firm age (years)
gen min_firm_age_y_phase=min_firm_age_phase/12 
gen max_firm_age_y_phase=max_firm_age_phase/12  
gen mean_firm_age_y_phase=mean_firm_age_phase/12  
gen median_firm_age_y_phase=median_firm_age_phase/12  
gen sd_firm_age_y_phase=sd_firm_age_phase/12  
gen p10_firm_age_y_phase=p10_firm_age_phase/12  
gen p20_firm_age_y_phase=p20_firm_age_phase/12  
gen p30_firm_age_y_phase=p30_firm_age_phase/12  
gen p40_firm_age_y_phase=p40_firm_age_phase/12  
gen p60_firm_age_y_phase=p60_firm_age_phase/12  
gen p70_firm_age_y_phase=p70_firm_age_phase/12  
gen p80_firm_age_y_phase=p80_firm_age_phase/12  
gen p90_firm_age_y_phase=p90_firm_age_phase/12 




*** Second Highest Value
by numerodaoc códigoitem fase_oc: egen second_bid = total(valorunitárioproposta / (rank == 2))


*** Difference between min bid and second lowest value
gen diff_first_second=(second_bid-min_bid)/min_bid


*** Elapsed Time
gen bid_time= datahrproposta
gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
by numerodaoc códigoitem fase_oc: egen min_bid_time_phase = min(bid_time_date)
by numerodaoc códigoitem fase_oc: egen max_bid_time_phase = max(bid_time_date)
gen oc_item_elapsed_time=max_bid_time_phase-min_bid_time_phase
gen oc_item_elapsed_time_hours=oc_item_elapsed_time/3600000
gen oc_item_elapsed_time_minutes=oc_item_elapsed_time_hours*60

format min_bid_time_phase %tc
format max_bid_time_phase %tc
format oc_item_elapsed_time %9.2f
format oc_item_elapsed_time_hours %9.2f
format oc_item_elapsed_time_minutes %9.2f

drop  datahrproposta



*** CNAE

gen cnae_fiscal_length=length(cnae_fiscal)
tab cnae_fiscal_length
replace cnae_fiscal = "0" + cnae_fiscal if cnae_fiscal_length==6
sort cnae_fiscal
drop  cnae_fiscal_length
drop if numerodaoc==""

merge m:1 cnae_fiscal using "/home/darciogm1/projetos/bitter-pills/data/raw/cnae/cnae_21.dta", generate(_merge_cnae)

drop if _merge_cnae==2
drop _merge_cnae

egen cnae_resum_code=group(cnae_resumido)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_agro_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==1
replace n_fornec_agro_aux=0 if n_fornec_agro_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_agro = max(n_fornec_agro_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_comercio_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==2
replace n_fornec_comercio_aux=0 if n_fornec_comercio_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_comercio = max(n_fornec_comercio_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_ind_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==3
replace n_fornec_ind_aux=0 if n_fornec_ind_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_ind = max(n_fornec_ind_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_meioamb_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==4
replace n_fornec_meioamb_aux=0 if n_fornec_meioamb_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_meioamb = max(n_fornec_meioamb_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_serv_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==5
replace n_fornec_serv_aux=0 if n_fornec_serv_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_serv = max(n_fornec_serv_aux)


*** By OC + Item

*** Separating Successful / Failure of OC + Item
by numerodaoc códigoitem : egen winner_bid = min(valorunitárioproposta) if flagvencedor=="1"
by numerodaoc códigoitem : egen winner_bid2 = max(winner_bid)
gen oc_item_success=1
replace oc_item_success=0 if winner_bid2==.
drop winner_bid
ren winner_bid2 winner_bid

*** By OC

*** Identifying distinct items, classes and groups by OC
by numerodaoc códigoitem, sort: gen item_oc_distinct = _n == 1
by numerodaoc códigoclasse, sort: gen classe_oc_distinct = _n == 1
by numerodaoc códigogrupo, sort: gen grupo_oc_distinct = _n == 1


*** Counting distinct items, classes and groups by OC
by numerodaoc : egen item_oc_count = total(item_oc_distinct)
by numerodaoc : egen classe_oc_count = total(classe_oc_distinct)
by numerodaoc : egen grupo_oc_count = total(grupo_oc_distinct)




*** Identifying ocurrence of OC Phases

gen fase_oc1_check=0
gen fase_oc2_check=0
gen fase_oc3_check=0
gen fase_oc4_check=0
gen fase_oc6_check=0
gen fase_oc7_check=0

replace fase_oc1_check=1 if fase_oc==1
replace fase_oc2_check=1 if fase_oc==2
replace fase_oc3_check=1 if fase_oc==3
replace fase_oc4_check=1 if fase_oc==4
replace fase_oc6_check=1 if fase_oc==6
replace fase_oc7_check=1 if fase_oc==7

bysort numerodaoc códigoitem: egen fase_oc1=max(fase_oc1_check)
bysort numerodaoc códigoitem: egen fase_oc2=max(fase_oc2_check)
bysort numerodaoc códigoitem: egen fase_oc3=max(fase_oc3_check)
bysort numerodaoc códigoitem: egen fase_oc4=max(fase_oc4_check)
bysort numerodaoc códigoitem: egen fase_oc6=max(fase_oc6_check)
bysort numerodaoc códigoitem: egen fase_oc7=max(fase_oc7_check)


*** Investigating ocurrence of phases

gen phases_234=0
replace phases_234=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1

gen phases_23=0
replace phases_23=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==0

gen phases_24=0
replace phases_24=1 if fase_oc2==1 & fase_oc4==1 & fase_oc3==0

gen phases_12=0
replace phases_12=1 if fase_oc1==1 & fase_oc2==1

gen phases_26=0
replace phases_26=1 if fase_oc2==1 & fase_oc6==1

gen phases_2346=0
replace phases_2346=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1

gen phases_123467=0
replace phases_123467=1 if fase_oc1==1 & fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1 & fase_oc7==1

gen phases_23467=0
replace phases_23467=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1 & fase_oc7==1

*** Calculating firm age at the moment of the tender

gen ddate = daily( data_inicio_atividade , "YMD")
gen mdate = mofd(ddate)
format mdate %tm
gen firm_age=data-mdate
gen firm_age_years=firm_age/12
rename ddate data_inicio_ativid_aux
label variable data_inicio_ativid_aux "Data início atividade fornecedor convertido auxiliar"
drop data_inicio_atividade
ren mdate data_inicio_ativid
label variable data_inicio_ativid "Data início atividade do fornecedor"
label variable firm_age "Idade fornecedor no momento da licitação em meses"
label variable firm_age_years "Idade fornecedor no momento da licitação em anos"


*** Coding OC status

egen oc_status_code=group(oc_status)
label variable oc_status_code "1=ANUL;2=CANCEL;3=C/ VENC;4=S/ VENC;5=FRACASS;6=REVOG"
drop oc_status



*** Judicialized OCs

merge m:1 numerodaoc using "C:/Users/pesquisa/Documents/Papers/Word/OneDrive/Paper 1 - Judicialization/Datasets/2-JUD_REGEX_EDITAIS.dta", generate(_merge_JUD)

replace jud_regex=0 if _merge_JUD==1

gen jud_adm2=jud_adm
replace jud_adm2=0 if strpos(po_subject, "MATERIAL ADMINISTRATIVO") | strpos(po_subject, "MATERIAIS ADMINISTRATIVOS")

replace jud_adm2=0 if jud_adm2==.
gen sum_jud=jud_regex+jud_adm2

gen jud=0
replace jud=1 if sum_jud>0



*** Important variables of dates

rename data data_oc
label variable data_oc "Mês e ano da OC"
rename mês mês_oc
label variable mês_oc "Mês da OC"
rename ano ano_oc
label variable ano_oc "Ano da OC"


*** Droping key
drop chave1


*** Labeling variables

label variable qtde "Quantidade do Item"
replace me_epp=me_epp-1
label variable me_epp "0=N;1=S"
label variable pbu_year "Ano da UC"
label variable pbu_code_year "Código UC + Ano UC"
label variable pbu_ibge_cod_uf "Código UF IBGE da UC"
label variable ibge_cod_cidade_pbu "Código município IBGE da UC"
label variable pbu_city_area "Área km2 município da UC"
label variable pbu_latit "Latitude da UC"
label variable pbu_longit "Longitude da UC"
label variable firm_cnpj "CNPJ Fornecedor"
label variable data_inicio_atividade "Data inicio atividade do fornecedor"
label variable cnae_fiscal "CNAE fornecedor"
label variable porte_empresa "01=ME;03=EPP;05=OUTROS"
label variable firm_zipcode "CEP fornecedor"
label variable fornec_latitude "Latitude fornecedor"
label variable fornec_longitude "Longitude fornecedor"
label variable bid_status "1=Válido ou Classificado"
rename rank rank_fornec_oc
label variable rank_fornec_oc "Rank do fornecedor na OC+Item"
label variable particip_firm "Identificador de firma distinta"
label variable particip_firm_sum "Contagem de firmas distintas por OC+Item"
label variable particip_firm "Identificador de firma distinta"
rename min_bid min_bid_phase
label variable min_bid_phase "Valor mínimo por fase"
label variable max_bid "Valor máximo por fase"
rename max_bid max_bid_phase
rename mean_bid mean_bid_phase
label variable mean_bid_phase "Valor médio por fase"
rename median_bid median_bid_phase
label variable median_bid_phase "Mediana por fase"
rename sd_bid sd_bid_phase
label variable sd_bid_phase "Desvio-padrão por fase"
rename min_dist min_dist_phase
label variable min_dist_phase "Mínima distância por fase"
rename max_dist max_dist_phase
label variable max_dist_phase "Máxima distância por fase"
rename bids_sum bids_sum_phase
label variable bids_sum_phase "Número de bids por fase"
rename second_bid second_bid_phase
label variable second_bid_phase "Bid segundo colocado por fase"
label variable diff_first_second "Diferença em porcentagem entre 1o e 2o bid"
label variable winner_bid "Bid vencedor"
rename winner_bid winner_bid_oc
label variable oc_item_success "0=FRACASSO;1=SUCESSO"
rename mean_dist mean_dist_phase
label variable mean_dist_phase "Média distância por fase"
rename median_dist median_dist_phase
label variable median_dist_phase "Mediana distância por fase"
rename sd_dist sd_dist_phase
label variable sd_dist_phase "Desvio-padrão distância por fase"
label variable fase_oc1_check "0=N houve esta fase; 1=Houve"
label variable fase_oc2_check "0=N houve esta fase; 1=Houve"
label variable fase_oc3_check "0=N houve esta fase; 1=Houve"
label variable fase_oc4_check "0=N houve esta fase; 1=Houve"
label variable fase_oc6_check "0=N houve esta fase; 1=Houve"
label variable fase_oc7_check "0=N houve esta fase; 1=Houve"
label variable fase_oc1 "Por OC: 0=N houve;1=Houve"
label variable fase_oc2 "Por OC: 0=N houve;1=Houve"
label variable fase_oc3 "Por OC: 0=N houve;1=Houve"
label variable fase_oc4 "Por OC: 0=N houve;1=Houve"
label variable fase_oc6 "Por OC: 0=N houve;1=Houve"
label variable fase_oc7 "Por OC: 0=N houve;1=Houve"
label variable phases_234 "0=N houve fases;1=Houve fases"
label variable phases_23 "0=N houve fases;1=Houve fases"
label variable phases_24 "0=N houve fases;1=Houve fases"
label variable phases_12 "0=N houve fases;1=Houve fases"
label variable phases_26 "0=N houve fases;1=Houve fases"
label variable phases_2346 "0=N houve fases;1=Houve fases"
label variable phases_123467 "OC com fases 1,2,3,4,6 e 7"
label variable phases_23467 "OC com fases 2,3,4,6 e 7"
label variable p10_bid_phase "Percentile 10th bid price per phase"
label variable p20_bid_phase "Percentile 20th bid price per phase"
label variable p30_bid_phase "Percentile 30th bid price per phase"
label variable p40_bid_phase "Percentile 40th bid price per phase"
label variable p60_bid_phase "Percentile 60th bid price per phase"
label variable p70_bid_phase "Percentile 70th bid price per phase"
label variable p80_bid_phase "Percentile 80th bid price per phase"
label variable p90_bid_phase "Percentile 90th bid price per phase"
label variable p10_dist_phase "Percentile 10th distance per phase"
label variable p20_dist_phase "Percentile 20th distance per phase"
label variable p30_dist_phase "Percentile 30th distance per phase"
label variable p40_dist_phase "Percentile 40th distance per phase"
label variable p60_dist_phase "Percentile 60th distance per phase"
label variable p70_dist_phase "Percentile 10th distance per phase"
label variable p70_dist_phase "Percentile 70th distance per phase"
label variable p80_dist_phase "Percentile 80th distance per phase"
label variable p90_dist_phase "Percentile 90th distance per phase"
label variable min_firm_age_phase "Min firm age per phase"
label variable max_firm_age_phase "Max firm age per phase"
label variable mean_firm_age_phase "Mean firm age per phase"
label variable median_firm_age_phase "Median firm age per phase"
label variable sd_firm_age_phase "SD firm age per phase"
label variable p10_firm_age_phase "Percentile 10th firm age per phase"
label variable p20_firm_age_phase "Percentile 20th firm age per phase"
label variable p30_firm_age_phase "Percentile 30th firm age per phase"
label variable p40_firm_age_phase "Percentile 40th firm age per phase"
label variable p60_firm_age_phase "Percentile 60th firm age per phase"
label variable p70_firm_age_phase "Percentile 70th firm age per phase"
label variable p80_firm_age_phase "Percentile 80th firm age per phase"
label variable p90_firm_age_phase "Percentile 90th firm age per phase"
label variable min_firm_age_y_phase "Min firm age per phase in years"
label variable max_firm_age_y_phase "Max firm age per phase in years"
label variable mean_firm_age_y_phase "Mean firm age per phase in years"
label variable median_firm_age_y_phase "Median firm age per phase in years"
label variable sd_firm_age_y_phase "SD firm age per phase in years"
label variable p10_firm_age_y_phase "Percentile 10th firm age per phase in years"
label variable p20_firm_age_y_phase "Percentile 20th firm age per phase in years"
label variable p30_firm_age_y_phase "Percentile 30th firm age per phase in years"
label variable p40_firm_age_y_phase "Percentile 40th firm age per phase in years"
label variable p60_firm_age_y_phase "Percentile 60th firm age per phase in years"
label variable p70_firm_age_y_phase "Percentile 70th firm age per phase in years"
label variable p80_firm_age_y_phase "Percentile 80th firm age per phase in years"
label variable p90_firm_age_y_phase "Percentile 90th firm age per phase in years"
label variable bid_time "Data e hora do bid price"
label variable bid_time "Data e hora do bid price string"
label variable bid_time_date "Data e hora do bid price double"
label variable min_bid_time_phase "Min bid time per phase"
label variable max_bid_time_phase "Max bid time per phase"
label variable oc_item_elapsed_time "Elapsed time per phase in miliseconds"
label variable oc_item_elapsed_time_hours "Elapsed time per phase in hours"
label variable oc_item_elapsed_time_minutes "Elapsed time per phase in minutes"
label variable item_oc_distinct "Number of distinct items per OC"
label variable classe_oc_distinct "Number of distinct items classes per OC"
label variable grupo_oc_distinct "Number of distinct items groups per OC"
label variable item_oc_distinct ""
label variable item_oc_count "Number of distinct items per OC"
label variable classe_oc_distinct ""
label variable classe_oc_count "Number of distinct items classes per OC"
label variable grupo_oc_distinct ""
label variable grupo_oc_count "Number of distinct items groups per OC"
label variable item_oc_distinct "Identifying distinct items per OC"
label variable classe_oc_distinct "Identifying distinct items classes per OC"
label variable grupo_oc_distinct "Identifying distinct items groups per OC"
label variable n_firms_me_aux "Number of distinct ME firms"
label variable n_firms_epp_aux "Number of distinct EPP firms"
label variable n_firms_me_aux ""
label variable n_firms_me "Number of distinct ME firms"
label variable n_firms_epp_aux ""
label variable n_firms_epp "Number of distinct EPP firms per phase"
label variable n_firms_me "Number of distinct ME firms per phase"
label variable n_firms_outros "Number of distinct OTHER firms per phase"
label variable n_firms_me_aux "Identifying distinct ME firms per phase"
label variable n_firms_epp_aux "Identifying distinct EPP firms per phase"
label variable n_firms_outros_aux "Identifying distinct OTHER firms per phase"
label variable same_municip "1=UC e Fornec mesmo municipio"
label variable fornec_estado_SP "1=Fornec do Estado de SP"
label variable fornec_city_SP "1=Fornec da cidade de SP"


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_3_final_validbids.dta", replace

************ Preparing Collapse_ ITEMS

drop pbu_year pbu_code_year _merge_JUD valorunitárioproposta flagvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 data_inicio_ativid_aux data_inicio_ativid firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code n_firms_me_aux n_firms_epp_aux n_firms_outros_aux n_same_municip_aux n_fornec_estado_SP_aux n_fornec_city_SP_aux n_fornec_agro_aux n_fornec_comercio_aux n_fornec_ind_aux n_fornec_meioamb_aux n_fornec_serv_aux bid_time bid_time_date min_bid_time_phase max_bid_time_phase item_oc_distinct classe_oc_distinct grupo_oc_distinct valor_total_neg_max rank_fornec_oc particip_firm props_grupo_status descriçãopropostastatus bid_status fase_oc1_check fase_oc2_check fase_oc3_check fase_oc4_check fase_oc6_check fase_oc7_check pubag_descr phases_234 phases_23 phases_24 phases_12 phases_26 phases_2346 phases_123467 phases_23467 p10_bid_phase p20_bid_phase p30_bid_phase p40_bid_phase p60_bid_phase p70_bid_phase p80_bid_phase p90_bid_phase p10_dist_phase p20_dist_phase p30_dist_phase p40_dist_phase p60_dist_phase p70_dist_phase p80_dist_phase p90_dist_phase p10_firm_age_phase p20_firm_age_phase p30_firm_age_phase p40_firm_age_phase p60_firm_age_phase p70_firm_age_phase p80_firm_age_phase p90_firm_age_phase p10_firm_age_y_phase p20_firm_age_y_phase p30_firm_age_y_phase p40_firm_age_y_phase p60_firm_age_y_phase p70_firm_age_y_phase p80_firm_age_y_phase p90_firm_age_y_phase min_firm_age_y_phase max_firm_age_y_phase mean_firm_age_y_phase median_firm_age_y_phase sd_firm_age_y_phase oc_item_elapsed_time oc_item_elapsed_time_hours


order data_oc mês_oc ano_oc numerodaoc oc_status_code códigoitem descitem códigoclasse descclasseitem códigogrupo descgrupoitem proc_compra reg_precos categ_item item_verde preco_ref qtde me_epp oc_item_success sum_jud jud_regex códigounidadecompradora descriçãounidadecompradora pbu_code pbu_cnpj códigouo descriçãouo códigoórgão descriçãoórgão pbu_power pbu_type_mgmt_code pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_ibge_cod_uf ibge_cod_cidade_pbu pbu_city_area pbu_latit pbu_longit descriçãomunicípiodeentrega descriçãoregiãodeentrega fase_oc item_oc_count classe_oc_count grupo_oc_count fase_oc1 fase_oc2 fase_oc3 fase_oc4 fase_oc6 fase_oc7  preco_final min_bid_phase max_bid_phase mean_bid_phase median_bid_phase sd_bid_phase  min_dist_phase max_dist_phase mean_dist_phase median_dist_phase sd_dist_phase  min_firm_age_phase max_firm_age_phase mean_firm_age_phase median_firm_age_phase sd_firm_age_phase    bids_sum_phase particip_firm_sum n_fornec_agro n_fornec_comercio n_fornec_ind n_fornec_meioamb n_fornec_serv n_firms_me n_firms_epp n_firms_outros n_same_municip n_fornec_estado_SP n_fornec_city_SP  oc_item_elapsed_time_minutes second_bid_phase diff_first_second winner_bid_oc 


***** Bid Value for each phase

** Min

gen min_bid_phase1=0
gen min_bid_phase2=0
gen min_bid_phase3=0
gen min_bid_phase4=0
gen min_bid_phase6=0
gen min_bid_phase7=0

replace min_bid_phase1=min_bid_phase if fase_oc==1
replace min_bid_phase2=min_bid_phase if fase_oc==2
replace min_bid_phase3=min_bid_phase if fase_oc==3
replace min_bid_phase4=min_bid_phase if fase_oc==4
replace min_bid_phase6=min_bid_phase if fase_oc==6
replace min_bid_phase7=min_bid_phase if fase_oc==7

drop min_bid_phase



** Max

gen max_bid_phase1=0
gen max_bid_phase2=0
gen max_bid_phase3=0
gen max_bid_phase4=0
gen max_bid_phase6=0
gen max_bid_phase7=0

replace max_bid_phase1=max_bid_phase if fase_oc==1
replace max_bid_phase2=max_bid_phase if fase_oc==2
replace max_bid_phase3=max_bid_phase if fase_oc==3
replace max_bid_phase4=max_bid_phase if fase_oc==4
replace max_bid_phase6=max_bid_phase if fase_oc==6
replace max_bid_phase7=max_bid_phase if fase_oc==7

drop max_bid_phase


** Mean

gen mean_bid_phase1=0
gen mean_bid_phase2=0
gen mean_bid_phase3=0
gen mean_bid_phase4=0
gen mean_bid_phase6=0
gen mean_bid_phase7=0

replace mean_bid_phase1=mean_bid_phase if fase_oc==1
replace mean_bid_phase2=mean_bid_phase if fase_oc==2
replace mean_bid_phase3=mean_bid_phase if fase_oc==3
replace mean_bid_phase4=mean_bid_phase if fase_oc==4
replace mean_bid_phase6=mean_bid_phase if fase_oc==6
replace mean_bid_phase7=mean_bid_phase if fase_oc==7

drop mean_bid_phase


** Median

gen median_bid_phase1=0
gen median_bid_phase2=0
gen median_bid_phase3=0
gen median_bid_phase4=0
gen median_bid_phase6=0
gen median_bid_phase7=0

replace median_bid_phase1=median_bid_phase if fase_oc==1
replace median_bid_phase2=median_bid_phase if fase_oc==2
replace median_bid_phase3=median_bid_phase if fase_oc==3
replace median_bid_phase4=median_bid_phase if fase_oc==4
replace median_bid_phase6=median_bid_phase if fase_oc==6
replace median_bid_phase7=median_bid_phase if fase_oc==7

drop median_bid_phase


** Standard Deviation

gen sd_bid_phase1=0
gen sd_bid_phase2=0
gen sd_bid_phase3=0
gen sd_bid_phase4=0
gen sd_bid_phase6=0
gen sd_bid_phase7=0

replace sd_bid_phase1=sd_bid_phase if fase_oc==1
replace sd_bid_phase2=sd_bid_phase if fase_oc==2
replace sd_bid_phase3=sd_bid_phase if fase_oc==3
replace sd_bid_phase4=sd_bid_phase if fase_oc==4
replace sd_bid_phase6=sd_bid_phase if fase_oc==6
replace sd_bid_phase7=sd_bid_phase if fase_oc==7

drop sd_bid_phase





***** Distance

** Min

gen min_dist_phase1=0
gen min_dist_phase2=0
gen min_dist_phase3=0
gen min_dist_phase4=0
gen min_dist_phase6=0
gen min_dist_phase7=0

replace min_dist_phase1=min_dist_phase if fase_oc==1
replace min_dist_phase2=min_dist_phase if fase_oc==2
replace min_dist_phase3=min_dist_phase if fase_oc==3
replace min_dist_phase4=min_dist_phase if fase_oc==4
replace min_dist_phase6=min_dist_phase if fase_oc==6
replace min_dist_phase7=min_dist_phase if fase_oc==7

drop min_dist_phase



** Max

gen max_dist_phase1=0
gen max_dist_phase2=0
gen max_dist_phase3=0
gen max_dist_phase4=0
gen max_dist_phase6=0
gen max_dist_phase7=0

replace max_dist_phase1=max_dist_phase if fase_oc==1
replace max_dist_phase2=max_dist_phase if fase_oc==2
replace max_dist_phase3=max_dist_phase if fase_oc==3
replace max_dist_phase4=max_dist_phase if fase_oc==4
replace max_dist_phase6=max_dist_phase if fase_oc==6
replace max_dist_phase7=max_dist_phase if fase_oc==7

drop max_dist_phase


** Mean

gen mean_dist_phase1=0
gen mean_dist_phase2=0
gen mean_dist_phase3=0
gen mean_dist_phase4=0
gen mean_dist_phase6=0
gen mean_dist_phase7=0

replace mean_dist_phase1=mean_dist_phase if fase_oc==1
replace mean_dist_phase2=mean_dist_phase if fase_oc==2
replace mean_dist_phase3=mean_dist_phase if fase_oc==3
replace mean_dist_phase4=mean_dist_phase if fase_oc==4
replace mean_dist_phase6=mean_dist_phase if fase_oc==6
replace mean_dist_phase7=mean_dist_phase if fase_oc==7

drop mean_dist_phase


** Median

gen median_dist_phase1=0
gen median_dist_phase2=0
gen median_dist_phase3=0
gen median_dist_phase4=0
gen median_dist_phase6=0
gen median_dist_phase7=0

replace median_dist_phase1=median_dist_phase if fase_oc==1
replace median_dist_phase2=median_dist_phase if fase_oc==2
replace median_dist_phase3=median_dist_phase if fase_oc==3
replace median_dist_phase4=median_dist_phase if fase_oc==4
replace median_dist_phase6=median_dist_phase if fase_oc==6
replace median_dist_phase7=median_dist_phase if fase_oc==7

drop median_dist_phase


** Standard Deviation

gen sd_dist_phase1=0
gen sd_dist_phase2=0
gen sd_dist_phase3=0
gen sd_dist_phase4=0
gen sd_dist_phase6=0
gen sd_dist_phase7=0

replace sd_dist_phase1=sd_dist_phase if fase_oc==1
replace sd_dist_phase2=sd_dist_phase if fase_oc==2
replace sd_dist_phase3=sd_dist_phase if fase_oc==3
replace sd_dist_phase4=sd_dist_phase if fase_oc==4
replace sd_dist_phase6=sd_dist_phase if fase_oc==6
replace sd_dist_phase7=sd_dist_phase if fase_oc==7

drop sd_dist_phase



***** Firm Age (in months)

** Min

gen min_firm_age_phase1=0
gen min_firm_age_phase2=0
gen min_firm_age_phase3=0
gen min_firm_age_phase4=0
gen min_firm_age_phase6=0
gen min_firm_age_phase7=0

replace min_firm_age_phase1=min_firm_age_phase if fase_oc==1
replace min_firm_age_phase2=min_firm_age_phase if fase_oc==2
replace min_firm_age_phase3=min_firm_age_phase if fase_oc==3
replace min_firm_age_phase4=min_firm_age_phase if fase_oc==4
replace min_firm_age_phase6=min_firm_age_phase if fase_oc==6
replace min_firm_age_phase7=min_firm_age_phase if fase_oc==7

drop min_firm_age_phase



** Max

gen max_firm_age_phase1=0
gen max_firm_age_phase2=0
gen max_firm_age_phase3=0
gen max_firm_age_phase4=0
gen max_firm_age_phase6=0
gen max_firm_age_phase7=0

replace max_firm_age_phase1=max_firm_age_phase if fase_oc==1
replace max_firm_age_phase2=max_firm_age_phase if fase_oc==2
replace max_firm_age_phase3=max_firm_age_phase if fase_oc==3
replace max_firm_age_phase4=max_firm_age_phase if fase_oc==4
replace max_firm_age_phase6=max_firm_age_phase if fase_oc==6
replace max_firm_age_phase7=max_firm_age_phase if fase_oc==7

drop max_firm_age_phase


** Mean

gen mean_firm_age_phase1=0
gen mean_firm_age_phase2=0
gen mean_firm_age_phase3=0
gen mean_firm_age_phase4=0
gen mean_firm_age_phase6=0
gen mean_firm_age_phase7=0

replace mean_firm_age_phase1=mean_firm_age_phase if fase_oc==1
replace mean_firm_age_phase2=mean_firm_age_phase if fase_oc==2
replace mean_firm_age_phase3=mean_firm_age_phase if fase_oc==3
replace mean_firm_age_phase4=mean_firm_age_phase if fase_oc==4
replace mean_firm_age_phase6=mean_firm_age_phase if fase_oc==6
replace mean_firm_age_phase7=mean_firm_age_phase if fase_oc==7

drop mean_firm_age_phase


** Median

gen median_firm_age_phase1=0
gen median_firm_age_phase2=0
gen median_firm_age_phase3=0
gen median_firm_age_phase4=0
gen median_firm_age_phase6=0
gen median_firm_age_phase7=0

replace median_firm_age_phase1=median_firm_age_phase if fase_oc==1
replace median_firm_age_phase2=median_firm_age_phase if fase_oc==2
replace median_firm_age_phase3=median_firm_age_phase if fase_oc==3
replace median_firm_age_phase4=median_firm_age_phase if fase_oc==4
replace median_firm_age_phase6=median_firm_age_phase if fase_oc==6
replace median_firm_age_phase7=median_firm_age_phase if fase_oc==7

drop median_firm_age_phase


** Standard Deviation

gen sd_firm_age_phase1=0
gen sd_firm_age_phase2=0
gen sd_firm_age_phase3=0
gen sd_firm_age_phase4=0
gen sd_firm_age_phase6=0
gen sd_firm_age_phase7=0

replace sd_firm_age_phase1=sd_firm_age_phase if fase_oc==1
replace sd_firm_age_phase2=sd_firm_age_phase if fase_oc==2
replace sd_firm_age_phase3=sd_firm_age_phase if fase_oc==3
replace sd_firm_age_phase4=sd_firm_age_phase if fase_oc==4
replace sd_firm_age_phase6=sd_firm_age_phase if fase_oc==6
replace sd_firm_age_phase7=sd_firm_age_phase if fase_oc==7

drop sd_firm_age_phase



***** Counting Fornecs

** # bids

gen numbids_phase1=0
gen numbids_phase2=0
gen numbids_phase3=0
gen numbids_phase4=0
gen numbids_phase6=0
gen numbids_phase7=0

replace numbids_phase1=bids_sum_phase if fase_oc==1
replace numbids_phase2=bids_sum_phase if fase_oc==2
replace numbids_phase3=bids_sum_phase if fase_oc==3
replace numbids_phase4=bids_sum_phase if fase_oc==4
replace numbids_phase6=bids_sum_phase if fase_oc==6
replace numbids_phase7=bids_sum_phase if fase_oc==7

drop bids_sum_phase


** # participant firms

gen numfornecs_phase1=0
gen numfornecs_phase2=0
gen numfornecs_phase3=0
gen numfornecs_phase4=0
gen numfornecs_phase6=0
gen numfornecs_phase7=0

replace numfornecs_phase1=particip_firm_sum if fase_oc==1
replace numfornecs_phase2=particip_firm_sum if fase_oc==2
replace numfornecs_phase3=particip_firm_sum if fase_oc==3
replace numfornecs_phase4=particip_firm_sum if fase_oc==4
replace numfornecs_phase6=particip_firm_sum if fase_oc==6
replace numfornecs_phase7=particip_firm_sum if fase_oc==7

drop particip_firm_sum


** # fornecs Agro e Pesca

gen numfornecs_agro_phase1=0
gen numfornecs_agro_phase2=0
gen numfornecs_agro_phase3=0
gen numfornecs_agro_phase4=0
gen numfornecs_agro_phase6=0
gen numfornecs_agro_phase7=0

replace numfornecs_agro_phase1=n_fornec_agro if fase_oc==1
replace numfornecs_agro_phase2=n_fornec_agro if fase_oc==2
replace numfornecs_agro_phase3=n_fornec_agro if fase_oc==3
replace numfornecs_agro_phase4=n_fornec_agro if fase_oc==4
replace numfornecs_agro_phase6=n_fornec_agro if fase_oc==6
replace numfornecs_agro_phase7=n_fornec_agro if fase_oc==7

drop n_fornec_agro


** # fornecs Comércio

gen numfornecs_comercio_phase1=0
gen numfornecs_comercio_phase2=0
gen numfornecs_comercio_phase3=0
gen numfornecs_comercio_phase4=0
gen numfornecs_comercio_phase6=0
gen numfornecs_comercio_phase7=0

replace numfornecs_comercio_phase1=n_fornec_comercio if fase_oc==1
replace numfornecs_comercio_phase2=n_fornec_comercio if fase_oc==2
replace numfornecs_comercio_phase3=n_fornec_comercio if fase_oc==3
replace numfornecs_comercio_phase4=n_fornec_comercio if fase_oc==4
replace numfornecs_comercio_phase6=n_fornec_comercio if fase_oc==6
replace numfornecs_comercio_phase7=n_fornec_comercio if fase_oc==7

drop n_fornec_comercio


** # fornecs Indústria

gen numfornecs_ind_phase1=0
gen numfornecs_ind_phase2=0
gen numfornecs_ind_phase3=0
gen numfornecs_ind_phase4=0
gen numfornecs_ind_phase6=0
gen numfornecs_ind_phase7=0

replace numfornecs_ind_phase1=n_fornec_ind if fase_oc==1
replace numfornecs_ind_phase2=n_fornec_ind if fase_oc==2
replace numfornecs_ind_phase3=n_fornec_ind if fase_oc==3
replace numfornecs_ind_phase4=n_fornec_ind if fase_oc==4
replace numfornecs_ind_phase6=n_fornec_ind if fase_oc==6
replace numfornecs_ind_phase7=n_fornec_ind if fase_oc==7

drop n_fornec_ind


** # fornecs Meio Ambiente

gen numfornecs_meioamb_phase1=0
gen numfornecs_meioamb_phase2=0
gen numfornecs_meioamb_phase3=0
gen numfornecs_meioamb_phase4=0
gen numfornecs_meioamb_phase6=0
gen numfornecs_meioamb_phase7=0

replace numfornecs_meioamb_phase1=n_fornec_meioamb if fase_oc==1
replace numfornecs_meioamb_phase2=n_fornec_meioamb if fase_oc==2
replace numfornecs_meioamb_phase3=n_fornec_meioamb if fase_oc==3
replace numfornecs_meioamb_phase4=n_fornec_meioamb if fase_oc==4
replace numfornecs_meioamb_phase6=n_fornec_meioamb if fase_oc==6
replace numfornecs_meioamb_phase7=n_fornec_meioamb if fase_oc==7

drop n_fornec_meioamb



** # fornecs Serviços

gen numfornecs_serv_phase1=0
gen numfornecs_serv_phase2=0
gen numfornecs_serv_phase3=0
gen numfornecs_serv_phase4=0
gen numfornecs_serv_phase6=0
gen numfornecs_serv_phase7=0

replace numfornecs_serv_phase1=n_fornec_serv if fase_oc==1
replace numfornecs_serv_phase2=n_fornec_serv if fase_oc==2
replace numfornecs_serv_phase3=n_fornec_serv if fase_oc==3
replace numfornecs_serv_phase4=n_fornec_serv if fase_oc==4
replace numfornecs_serv_phase6=n_fornec_serv if fase_oc==6
replace numfornecs_serv_phase7=n_fornec_serv if fase_oc==7

drop n_fornec_serv


** # fornecs type ME

gen numfornecs_type_me_phase1=0
gen numfornecs_type_me_phase2=0
gen numfornecs_type_me_phase3=0
gen numfornecs_type_me_phase4=0
gen numfornecs_type_me_phase6=0
gen numfornecs_type_me_phase7=0

replace numfornecs_type_me_phase1=n_firms_me if fase_oc==1
replace numfornecs_type_me_phase2=n_firms_me if fase_oc==2
replace numfornecs_type_me_phase3=n_firms_me if fase_oc==3
replace numfornecs_type_me_phase4=n_firms_me if fase_oc==4
replace numfornecs_type_me_phase6=n_firms_me if fase_oc==6
replace numfornecs_type_me_phase7=n_firms_me if fase_oc==7

drop  n_firms_me


** # fornecs type EPP

gen numfornecs_type_epp_phase1=0
gen numfornecs_type_epp_phase2=0
gen numfornecs_type_epp_phase3=0
gen numfornecs_type_epp_phase4=0
gen numfornecs_type_epp_phase6=0
gen numfornecs_type_epp_phase7=0

replace numfornecs_type_epp_phase1=n_firms_epp if fase_oc==1
replace numfornecs_type_epp_phase2=n_firms_epp if fase_oc==2
replace numfornecs_type_epp_phase3=n_firms_epp if fase_oc==3
replace numfornecs_type_epp_phase4=n_firms_epp if fase_oc==4
replace numfornecs_type_epp_phase6=n_firms_epp if fase_oc==6
replace numfornecs_type_epp_phase7=n_firms_epp if fase_oc==7

drop  n_firms_epp


** # fornecs type OTHER

gen numfornecs_type_oth_phase1=0
gen numfornecs_type_oth_phase2=0
gen numfornecs_type_oth_phase3=0
gen numfornecs_type_oth_phase4=0
gen numfornecs_type_oth_phase6=0
gen numfornecs_type_oth_phase7=0

replace numfornecs_type_oth_phase1=n_firms_outros if fase_oc==1
replace numfornecs_type_oth_phase2=n_firms_outros if fase_oc==2
replace numfornecs_type_oth_phase3=n_firms_outros if fase_oc==3
replace numfornecs_type_oth_phase4=n_firms_outros if fase_oc==4
replace numfornecs_type_oth_phase6=n_firms_outros if fase_oc==6
replace numfornecs_type_oth_phase7=n_firms_outros if fase_oc==7

drop  n_firms_outros


** # fornecs same municip (UC and fornec)

gen numfornecs_same_munic_phase1=0
gen numfornecs_same_munic_phase2=0
gen numfornecs_same_munic_phase3=0
gen numfornecs_same_munic_phase4=0
gen numfornecs_same_munic_phase6=0
gen numfornecs_same_munic_phase7=0

replace numfornecs_same_munic_phase1=n_same_municip if fase_oc==1
replace numfornecs_same_munic_phase2=n_same_municip if fase_oc==2
replace numfornecs_same_munic_phase3=n_same_municip if fase_oc==3
replace numfornecs_same_munic_phase4=n_same_municip if fase_oc==4
replace numfornecs_same_munic_phase6=n_same_municip if fase_oc==6
replace numfornecs_same_munic_phase7=n_same_municip if fase_oc==7

drop n_same_municip


** # fornecs estado SP

gen numfornecs_est_SP_phase1=0
gen numfornecs_est_SP_phase2=0
gen numfornecs_est_SP_phase3=0
gen numfornecs_est_SP_phase4=0
gen numfornecs_est_SP_phase6=0
gen numfornecs_est_SP_phase7=0

replace numfornecs_est_SP_phase1=n_fornec_estado_SP if fase_oc==1
replace numfornecs_est_SP_phase2=n_fornec_estado_SP if fase_oc==2
replace numfornecs_est_SP_phase3=n_fornec_estado_SP if fase_oc==3
replace numfornecs_est_SP_phase4=n_fornec_estado_SP if fase_oc==4
replace numfornecs_est_SP_phase6=n_fornec_estado_SP if fase_oc==6
replace numfornecs_est_SP_phase7=n_fornec_estado_SP if fase_oc==7

drop n_fornec_estado_SP 


** # fornecs estado SP

gen numfornecs_city_SP_phase1=0
gen numfornecs_city_SP_phase2=0
gen numfornecs_city_SP_phase3=0
gen numfornecs_city_SP_phase4=0
gen numfornecs_city_SP_phase6=0
gen numfornecs_city_SP_phase7=0

replace numfornecs_city_SP_phase1=n_fornec_city_SP if fase_oc==1
replace numfornecs_city_SP_phase2=n_fornec_city_SP if fase_oc==2
replace numfornecs_city_SP_phase3=n_fornec_city_SP if fase_oc==3
replace numfornecs_city_SP_phase4=n_fornec_city_SP if fase_oc==4
replace numfornecs_city_SP_phase6=n_fornec_city_SP if fase_oc==6
replace numfornecs_city_SP_phase7=n_fornec_city_SP if fase_oc==7

drop n_fornec_city_SP



***** Elapsed Time

gen elapsed_time_phase1=0
gen elapsed_time_phase2=0
gen elapsed_time_phase3=0
gen elapsed_time_phase4=0
gen elapsed_time_phase6=0
gen elapsed_time_phase7=0

replace elapsed_time_phase1=oc_item_elapsed_time_minutes if fase_oc==1
replace elapsed_time_phase2=oc_item_elapsed_time_minutes if fase_oc==2
replace elapsed_time_phase3=oc_item_elapsed_time_minutes if fase_oc==3
replace elapsed_time_phase4=oc_item_elapsed_time_minutes if fase_oc==4
replace elapsed_time_phase6=oc_item_elapsed_time_minutes if fase_oc==6
replace elapsed_time_phase7=oc_item_elapsed_time_minutes if fase_oc==7

drop oc_item_elapsed_time_minutes 



***** Second Bid

gen second_bid_phase1=0
gen second_bid_phase2=0
gen second_bid_phase3=0
gen second_bid_phase4=0
gen second_bid_phase6=0
gen second_bid_phase7=0

replace second_bid_phase1=second_bid_phase if fase_oc==1
replace second_bid_phase2=second_bid_phase if fase_oc==2
replace second_bid_phase3=second_bid_phase if fase_oc==3
replace second_bid_phase4=second_bid_phase if fase_oc==4
replace second_bid_phase6=second_bid_phase if fase_oc==6
replace second_bid_phase7=second_bid_phase if fase_oc==7


drop second_bid_phase 


***** Difference between first and second bids

gen diff_first_sec_phase1=0
gen diff_first_sec_phase2=0
gen diff_first_sec_phase3=0
gen diff_first_sec_phase4=0
gen diff_first_sec_phase6=0
gen diff_first_sec_phase7=0

replace diff_first_sec_phase1=diff_first_second if fase_oc==1
replace diff_first_sec_phase2=diff_first_second if fase_oc==2
replace diff_first_sec_phase3=diff_first_second if fase_oc==3
replace diff_first_sec_phase4=diff_first_second if fase_oc==4
replace diff_first_sec_phase6=diff_first_second if fase_oc==6
replace diff_first_sec_phase7=diff_first_second if fase_oc==7



drop diff_first_second

drop fase_oc

*** Filling Missing Data


duplicates drop


bysort numerodaoc códigoitem: egen  min_bid_ph1 =max(min_bid_phase1)
bysort numerodaoc códigoitem: egen  min_bid_ph2 =max(min_bid_phase2)
bysort numerodaoc códigoitem: egen  min_bid_ph3 =max(min_bid_phase3)
bysort numerodaoc códigoitem: egen  min_bid_ph4 =max(min_bid_phase4)
bysort numerodaoc códigoitem: egen  min_bid_ph6 =max(min_bid_phase6)
bysort numerodaoc códigoitem: egen  min_bid_ph7 =max(min_bid_phase7)
bysort numerodaoc códigoitem: egen  max_bid_ph1 =max(max_bid_phase1)
bysort numerodaoc códigoitem: egen  max_bid_ph2 =max(max_bid_phase2)
bysort numerodaoc códigoitem: egen  max_bid_ph3 =max(max_bid_phase3)
bysort numerodaoc códigoitem: egen  max_bid_ph4 =max(max_bid_phase4)
bysort numerodaoc códigoitem: egen  max_bid_ph6 =max(max_bid_phase6)
bysort numerodaoc códigoitem: egen  max_bid_ph7 =max(max_bid_phase7)
bysort numerodaoc códigoitem: egen  mean_bid_ph1 =max(mean_bid_phase1)
bysort numerodaoc códigoitem: egen  mean_bid_ph2 =max(mean_bid_phase2)
bysort numerodaoc códigoitem: egen  mean_bid_ph3 =max(mean_bid_phase3)
bysort numerodaoc códigoitem: egen  mean_bid_ph4 =max(mean_bid_phase4)
bysort numerodaoc códigoitem: egen  mean_bid_ph6 =max(mean_bid_phase6)
bysort numerodaoc códigoitem: egen  mean_bid_ph7 =max(mean_bid_phase7)
bysort numerodaoc códigoitem: egen  median_bid_ph1 =max(median_bid_phase1)
bysort numerodaoc códigoitem: egen  median_bid_ph2 =max(median_bid_phase2)
bysort numerodaoc códigoitem: egen  median_bid_ph3 =max(median_bid_phase3)
bysort numerodaoc códigoitem: egen  median_bid_ph4 =max(median_bid_phase4)
bysort numerodaoc códigoitem: egen  median_bid_ph6 =max(median_bid_phase6)
bysort numerodaoc códigoitem: egen  median_bid_ph7 =max(median_bid_phase7)
bysort numerodaoc códigoitem: egen  sd_bid_ph1 =max(sd_bid_phase1)
bysort numerodaoc códigoitem: egen  sd_bid_ph2 =max(sd_bid_phase2)
bysort numerodaoc códigoitem: egen  sd_bid_ph3 =max(sd_bid_phase3)
bysort numerodaoc códigoitem: egen  sd_bid_ph4 =max(sd_bid_phase4)
bysort numerodaoc códigoitem: egen  sd_bid_ph6 =max(sd_bid_phase6)
bysort numerodaoc códigoitem: egen  sd_bid_ph7 =max(sd_bid_phase7)
bysort numerodaoc códigoitem: egen  min_dist_ph1 =max(min_dist_phase1)
bysort numerodaoc códigoitem: egen  min_dist_ph2 =max(min_dist_phase2)
bysort numerodaoc códigoitem: egen  min_dist_ph3 =max(min_dist_phase3)
bysort numerodaoc códigoitem: egen  min_dist_ph4 =max(min_dist_phase4)
bysort numerodaoc códigoitem: egen  min_dist_ph6 =max(min_dist_phase6)
bysort numerodaoc códigoitem: egen  min_dist_ph7 =max(min_dist_phase7)
bysort numerodaoc códigoitem: egen  max_dist_ph1 =max(max_dist_phase1)
bysort numerodaoc códigoitem: egen  max_dist_ph2 =max(max_dist_phase2)
bysort numerodaoc códigoitem: egen  max_dist_ph3 =max(max_dist_phase3)
bysort numerodaoc códigoitem: egen  max_dist_ph4 =max(max_dist_phase4)
bysort numerodaoc códigoitem: egen  max_dist_ph6 =max(max_dist_phase6)
bysort numerodaoc códigoitem: egen  max_dist_ph7 =max(max_dist_phase7)
bysort numerodaoc códigoitem: egen  mean_dist_ph1 =max(mean_dist_phase1)
bysort numerodaoc códigoitem: egen  mean_dist_ph2 =max(mean_dist_phase2)
bysort numerodaoc códigoitem: egen  mean_dist_ph3 =max(mean_dist_phase3)
bysort numerodaoc códigoitem: egen  mean_dist_ph4 =max(mean_dist_phase4)
bysort numerodaoc códigoitem: egen  mean_dist_ph6 =max(mean_dist_phase6)
bysort numerodaoc códigoitem: egen  mean_dist_ph7 =max(mean_dist_phase7)
bysort numerodaoc códigoitem: egen  median_dist_ph1 =max(median_dist_phase1)
bysort numerodaoc códigoitem: egen  median_dist_ph2 =max(median_dist_phase2)
bysort numerodaoc códigoitem: egen  median_dist_ph3 =max(median_dist_phase3)
bysort numerodaoc códigoitem: egen  median_dist_ph4 =max(median_dist_phase4)
bysort numerodaoc códigoitem: egen  median_dist_ph6 =max(median_dist_phase6)
bysort numerodaoc códigoitem: egen  median_dist_ph7 =max(median_dist_phase7)
bysort numerodaoc códigoitem: egen  sd_dist_ph1 =max(sd_dist_phase1)
bysort numerodaoc códigoitem: egen  sd_dist_ph2 =max(sd_dist_phase2)
bysort numerodaoc códigoitem: egen  sd_dist_ph3 =max(sd_dist_phase3)
bysort numerodaoc códigoitem: egen  sd_dist_ph4 =max(sd_dist_phase4)
bysort numerodaoc códigoitem: egen  sd_dist_ph6 =max(sd_dist_phase6)
bysort numerodaoc códigoitem: egen  sd_dist_ph7 =max(sd_dist_phase7)
bysort numerodaoc códigoitem: egen  min_firm_age_ph1 =max(min_firm_age_phase1)
bysort numerodaoc códigoitem: egen  min_firm_age_ph2 =max(min_firm_age_phase2)
bysort numerodaoc códigoitem: egen  min_firm_age_ph3 =max(min_firm_age_phase3)
bysort numerodaoc códigoitem: egen  min_firm_age_ph4 =max(min_firm_age_phase4)
bysort numerodaoc códigoitem: egen  min_firm_age_ph6 =max(min_firm_age_phase6)
bysort numerodaoc códigoitem: egen  min_firm_age_ph7 =max(min_firm_age_phase7)
bysort numerodaoc códigoitem: egen  max_firm_age_ph1 =max(max_firm_age_phase1)
bysort numerodaoc códigoitem: egen  max_firm_age_ph2 =max(max_firm_age_phase2)
bysort numerodaoc códigoitem: egen  max_firm_age_ph3 =max(max_firm_age_phase3)
bysort numerodaoc códigoitem: egen  max_firm_age_ph4 =max(max_firm_age_phase4)
bysort numerodaoc códigoitem: egen  max_firm_age_ph6 =max(max_firm_age_phase6)
bysort numerodaoc códigoitem: egen  max_firm_age_ph7 =max(max_firm_age_phase7)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph1 =max(mean_firm_age_phase1)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph2 =max(mean_firm_age_phase2)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph3 =max(mean_firm_age_phase3)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph4 =max(mean_firm_age_phase4)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph6 =max(mean_firm_age_phase6)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph7 =max(mean_firm_age_phase7)
bysort numerodaoc códigoitem: egen  median_firm_age_ph1 =max(median_firm_age_phase1)
bysort numerodaoc códigoitem: egen  median_firm_age_ph2 =max(median_firm_age_phase2)
bysort numerodaoc códigoitem: egen  median_firm_age_ph3 =max(median_firm_age_phase3)
bysort numerodaoc códigoitem: egen  median_firm_age_ph4 =max(median_firm_age_phase4)
bysort numerodaoc códigoitem: egen  median_firm_age_ph6 =max(median_firm_age_phase6)
bysort numerodaoc códigoitem: egen  median_firm_age_ph7 =max(median_firm_age_phase7)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph1 =max(sd_firm_age_phase1)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph2 =max(sd_firm_age_phase2)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph3 =max(sd_firm_age_phase3)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph4 =max(sd_firm_age_phase4)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph6 =max(sd_firm_age_phase6)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph7 =max(sd_firm_age_phase7)
bysort numerodaoc códigoitem: egen  numbids_ph1 =max(numbids_phase1)
bysort numerodaoc códigoitem: egen  numbids_ph2 =max(numbids_phase2)
bysort numerodaoc códigoitem: egen  numbids_ph3 =max(numbids_phase3)
bysort numerodaoc códigoitem: egen  numbids_ph4 =max(numbids_phase4)
bysort numerodaoc códigoitem: egen  numbids_ph6 =max(numbids_phase6)
bysort numerodaoc códigoitem: egen  numbids_ph7 =max(numbids_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_ph1 =max(numfornecs_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_ph2 =max(numfornecs_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_ph3 =max(numfornecs_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_ph4 =max(numfornecs_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_ph6 =max(numfornecs_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_ph7 =max(numfornecs_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph1 =max(numfornecs_agro_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph2 =max(numfornecs_agro_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph3 =max(numfornecs_agro_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph4 =max(numfornecs_agro_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph6 =max(numfornecs_agro_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph7 =max(numfornecs_agro_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph1 =max(numfornecs_comercio_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph2 =max(numfornecs_comercio_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph3 =max(numfornecs_comercio_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph4 =max(numfornecs_comercio_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph6 =max(numfornecs_comercio_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph7 =max(numfornecs_comercio_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph1 =max(numfornecs_ind_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph2 =max(numfornecs_ind_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph3 =max(numfornecs_ind_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph4 =max(numfornecs_ind_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph6 =max(numfornecs_ind_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph7 =max(numfornecs_ind_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph1 =max(numfornecs_meioamb_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph2 =max(numfornecs_meioamb_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph3 =max(numfornecs_meioamb_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph4 =max(numfornecs_meioamb_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph6 =max(numfornecs_meioamb_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph7 =max(numfornecs_meioamb_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph1 =max(numfornecs_serv_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph2 =max(numfornecs_serv_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph3 =max(numfornecs_serv_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph4 =max(numfornecs_serv_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph6 =max(numfornecs_serv_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph7 =max(numfornecs_serv_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph1 =max(numfornecs_type_me_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph2 =max(numfornecs_type_me_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph3 =max(numfornecs_type_me_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph4 =max(numfornecs_type_me_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph6 =max(numfornecs_type_me_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph7 =max(numfornecs_type_me_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph1 =max(numfornecs_type_epp_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph2 =max(numfornecs_type_epp_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph3 =max(numfornecs_type_epp_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph4 =max(numfornecs_type_epp_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph6 =max(numfornecs_type_epp_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph7 =max(numfornecs_type_epp_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph1 =max(numfornecs_type_oth_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph2 =max(numfornecs_type_oth_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph3 =max(numfornecs_type_oth_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph4 =max(numfornecs_type_oth_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph6 =max(numfornecs_type_oth_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph7 =max(numfornecs_type_oth_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph1 =max(numfornecs_same_munic_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph2 =max(numfornecs_same_munic_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph3 =max(numfornecs_same_munic_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph4 =max(numfornecs_same_munic_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph6 =max(numfornecs_same_munic_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph7 =max(numfornecs_same_munic_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph1 =max(numfornecs_est_SP_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph2 =max(numfornecs_est_SP_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph3 =max(numfornecs_est_SP_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph4 =max(numfornecs_est_SP_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph6 =max(numfornecs_est_SP_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph7 =max(numfornecs_est_SP_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph1 =max(numfornecs_city_SP_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph2 =max(numfornecs_city_SP_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph3 =max(numfornecs_city_SP_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph4 =max(numfornecs_city_SP_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph6 =max(numfornecs_city_SP_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph7 =max(numfornecs_city_SP_phase7)
bysort numerodaoc códigoitem: egen  elapsed_time_ph1 =max(elapsed_time_phase1)
bysort numerodaoc códigoitem: egen  elapsed_time_ph2 =max(elapsed_time_phase2)
bysort numerodaoc códigoitem: egen  elapsed_time_ph3 =max(elapsed_time_phase3)
bysort numerodaoc códigoitem: egen  elapsed_time_ph4 =max(elapsed_time_phase4)
bysort numerodaoc códigoitem: egen  elapsed_time_ph6 =max(elapsed_time_phase6)
bysort numerodaoc códigoitem: egen  elapsed_time_ph7 =max(elapsed_time_phase7)
bysort numerodaoc códigoitem: egen  second_bid_ph1 =max(second_bid_phase1)
bysort numerodaoc códigoitem: egen  second_bid_ph2 =max(second_bid_phase2)
bysort numerodaoc códigoitem: egen  second_bid_ph3 =max(second_bid_phase3)
bysort numerodaoc códigoitem: egen  second_bid_ph4 =max(second_bid_phase4)
bysort numerodaoc códigoitem: egen  second_bid_ph6 =max(second_bid_phase6)
bysort numerodaoc códigoitem: egen  second_bid_ph7 =max(second_bid_phase7)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph1 =max(diff_first_sec_phase1)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph2 =max(diff_first_sec_phase2)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph3 =max(diff_first_sec_phase3)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph4 =max(diff_first_sec_phase4)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph6 =max(diff_first_sec_phase6)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph7 =max(diff_first_sec_phase7)
drop min_bid_phase1
drop min_bid_phase2
drop min_bid_phase3
drop min_bid_phase4
drop min_bid_phase6
drop min_bid_phase7
drop max_bid_phase1
drop max_bid_phase2
drop max_bid_phase3
drop max_bid_phase4
drop max_bid_phase6
drop max_bid_phase7
drop mean_bid_phase1
drop mean_bid_phase2
drop mean_bid_phase3
drop mean_bid_phase4
drop mean_bid_phase6
drop mean_bid_phase7
drop median_bid_phase1
drop median_bid_phase2
drop median_bid_phase3
drop median_bid_phase4
drop median_bid_phase6
drop median_bid_phase7
drop sd_bid_phase1
drop sd_bid_phase2
drop sd_bid_phase3
drop sd_bid_phase4
drop sd_bid_phase6
drop sd_bid_phase7
drop min_dist_phase1
drop min_dist_phase2
drop min_dist_phase3
drop min_dist_phase4
drop min_dist_phase6
drop min_dist_phase7
drop max_dist_phase1
drop max_dist_phase2
drop max_dist_phase3
drop max_dist_phase4
drop max_dist_phase6
drop max_dist_phase7
drop mean_dist_phase1
drop mean_dist_phase2
drop mean_dist_phase3
drop mean_dist_phase4
drop mean_dist_phase6
drop mean_dist_phase7
drop median_dist_phase1
drop median_dist_phase2
drop median_dist_phase3
drop median_dist_phase4
drop median_dist_phase6
drop median_dist_phase7
drop sd_dist_phase1
drop sd_dist_phase2
drop sd_dist_phase3
drop sd_dist_phase4
drop sd_dist_phase6
drop sd_dist_phase7
drop min_firm_age_phase1
drop min_firm_age_phase2
drop min_firm_age_phase3
drop min_firm_age_phase4
drop min_firm_age_phase6
drop min_firm_age_phase7
drop max_firm_age_phase1
drop max_firm_age_phase2
drop max_firm_age_phase3
drop max_firm_age_phase4
drop max_firm_age_phase6
drop max_firm_age_phase7
drop mean_firm_age_phase1
drop mean_firm_age_phase2
drop mean_firm_age_phase3
drop mean_firm_age_phase4
drop mean_firm_age_phase6
drop mean_firm_age_phase7
drop median_firm_age_phase1
drop median_firm_age_phase2
drop median_firm_age_phase3
drop median_firm_age_phase4
drop median_firm_age_phase6
drop median_firm_age_phase7
drop sd_firm_age_phase1
drop sd_firm_age_phase2
drop sd_firm_age_phase3
drop sd_firm_age_phase4
drop sd_firm_age_phase6
drop sd_firm_age_phase7
drop numbids_phase1
drop numbids_phase2
drop numbids_phase3
drop numbids_phase4
drop numbids_phase6
drop numbids_phase7
drop numfornecs_phase1
drop numfornecs_phase2
drop numfornecs_phase3
drop numfornecs_phase4
drop numfornecs_phase6
drop numfornecs_phase7
drop numfornecs_agro_phase1
drop numfornecs_agro_phase2
drop numfornecs_agro_phase3
drop numfornecs_agro_phase4
drop numfornecs_agro_phase6
drop numfornecs_agro_phase7
drop numfornecs_comercio_phase1
drop numfornecs_comercio_phase2
drop numfornecs_comercio_phase3
drop numfornecs_comercio_phase4
drop numfornecs_comercio_phase6
drop numfornecs_comercio_phase7
drop numfornecs_ind_phase1
drop numfornecs_ind_phase2
drop numfornecs_ind_phase3
drop numfornecs_ind_phase4
drop numfornecs_ind_phase6
drop numfornecs_ind_phase7
drop numfornecs_meioamb_phase1
drop numfornecs_meioamb_phase2
drop numfornecs_meioamb_phase3
drop numfornecs_meioamb_phase4
drop numfornecs_meioamb_phase6
drop numfornecs_meioamb_phase7
drop numfornecs_serv_phase1
drop numfornecs_serv_phase2
drop numfornecs_serv_phase3
drop numfornecs_serv_phase4
drop numfornecs_serv_phase6
drop numfornecs_serv_phase7
drop numfornecs_type_me_phase1
drop numfornecs_type_me_phase2
drop numfornecs_type_me_phase3
drop numfornecs_type_me_phase4
drop numfornecs_type_me_phase6
drop numfornecs_type_me_phase7
drop numfornecs_type_epp_phase1
drop numfornecs_type_epp_phase2
drop numfornecs_type_epp_phase3
drop numfornecs_type_epp_phase4
drop numfornecs_type_epp_phase6
drop numfornecs_type_epp_phase7
drop numfornecs_type_oth_phase1
drop numfornecs_type_oth_phase2
drop numfornecs_type_oth_phase3
drop numfornecs_type_oth_phase4
drop numfornecs_type_oth_phase6
drop numfornecs_type_oth_phase7
drop numfornecs_same_munic_phase1
drop numfornecs_same_munic_phase2
drop numfornecs_same_munic_phase3
drop numfornecs_same_munic_phase4
drop numfornecs_same_munic_phase6
drop numfornecs_same_munic_phase7
drop numfornecs_est_SP_phase1
drop numfornecs_est_SP_phase2
drop numfornecs_est_SP_phase3
drop numfornecs_est_SP_phase4
drop numfornecs_est_SP_phase6
drop numfornecs_est_SP_phase7
drop numfornecs_city_SP_phase1
drop numfornecs_city_SP_phase2
drop numfornecs_city_SP_phase3
drop numfornecs_city_SP_phase4
drop numfornecs_city_SP_phase6
drop numfornecs_city_SP_phase7
drop elapsed_time_phase1
drop elapsed_time_phase2
drop elapsed_time_phase3
drop elapsed_time_phase4
drop elapsed_time_phase6
drop elapsed_time_phase7
drop second_bid_phase1
drop second_bid_phase2
drop second_bid_phase3
drop second_bid_phase4
drop second_bid_phase6
drop second_bid_phase7
drop diff_first_sec_phase1
drop diff_first_sec_phase2
drop diff_first_sec_phase3
drop diff_first_sec_phase4
drop diff_first_sec_phase6
drop diff_first_sec_phase7



duplicates drop



save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_Items_Pregao.dta", replace











********************* File 2: Dispensa

clear all
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
use Final_Semester_proc_2.dta, clear

drop  data mês ano
drop if fase_oc==5

gen flag_check=0
replace flag_check=1 if flagvencedor==quantidadeitemvencedor
replace quantidadeitemvencedor="1" if flag_check==0
drop flag_check

gen data=mêsanoencerramento
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
drop if _merge_chave1==1

gen qty_oferta2=quantidadenegociada
destring qty_oferta2, replace dpcomma
drop quantidadenegociada
replace qty_oferta2=0 if qty_oferta2==.

destring valortotalproposta valorunitárioproposta valortotalnegociado  preco_ref preco_final mêsanoencerramento, replace dpcomma

replace valortotalnegociado=0 if valortotalnegociado==.

preserve

collapse (max) qty_max=qty_oferta qty_max2=qty_oferta2 valor_total_neg_max=valortotalnegociado, by(chave1)
sort chave1
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_dispensa.dta", replace

restore

sort chave1
merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_dispensa.dta", generate(_merge_pregao_qty)
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

ren códigofornecedor firm_cnpj

sort firm_cnpj
merge m:1 firm_cnpj using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/CNPJ Geoc/Fornecs_geoc_convite.dta", generate(_merge_geoc)
drop if _merge_geoc==2
drop if firm_cnpj=="-1"
drop if _merge_geoc==1

gen bid_status=0
replace bid_status=1 if descriçãopropostastatus=="VÁLIDO" | descriçãopropostastatus=="VÁLIDO E CONFIRMADO"


drop _merge_geoc _merge

sort firm_cnpj
merge m:1 firm_cnpj using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/CNPJ Geoc/Fornecs_geoc_convite2.dta", generate(_merge_geoc2)
drop _merge_geoc2

gen byte notnumeric = real( fornec_latitude )==.
replace fornec_latitude="0" if notnumeric==1
replace fornec_longitude ="0" if notnumeric==1
destring fornec_latitude fornec_longitude, replace
replace fornec_latitude2=0 if fornec_latitude2==.
replace fornec_longitude1 =0 if fornec_longitude1 ==.
gen check=0
replace check=1 if fornec_latitude2== fornec_latitude
replace fornec_latitude= fornec_latitude2 if fornec_latitude==0 & fornec_latitude2!=0
replace fornec_longitude = fornec_longitude1 if fornec_longitude ==0 & fornec_longitude1 !=0
drop  fornec_latitude2 fornec_longitude1 notnumeric check
drop if numerodaoc==""

merge m:1 descriçãomunicípiofornecedor using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/CNPJ Geoc/Municipios restantes.dta", generate(_merge_municip)

replace fornec_latitude= fornec_latitude3 if fornec_latitude==0
replace fornec_longitude = fornec_longitude3 if fornec_longitude ==0
drop _merge_geoc2 fornec_latitude3 fornec_longitude3 _merge_municip

geodist pbu_latit pbu_longit fornec_latitude fornec_longitude , generate(dist)
gen dist1=dist
replace dist1=0.05 if dist==0





save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_2_final.dta", replace




*** Auctions Info

* By OC + Item + OC_Phase

*** Ranking bids
keep if bid_status==1
bysort numerodaoc códigoitem fase_oc (valorunitárioproposta) : gen rank = _n
by numerodaoc códigoitem fase_oc: egen bids_sum = max(rank)

*** Identifying distinct participant firms
gen códigofornecedor= firm_cnpj
by numerodaoc códigoitem fase_oc códigofornecedor, sort: gen particip_firm = _n == 1


*** Counting participant firms
by numerodaoc códigoitem fase_oc: egen particip_firm_sum = total(particip_firm)


*** Counting distinct firms by porte de empresa
bysort numerodaoc códigoitem fase_oc: egen n_firms_me_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="01"
bysort numerodaoc códigoitem fase_oc: egen n_firms_epp_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="03"
bysort numerodaoc códigoitem fase_oc: egen n_firms_outros_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="05"

replace n_firms_me_aux=0 if n_firms_me_aux==.
replace n_firms_epp_aux=0 if n_firms_epp_aux==.
replace n_firms_outros_aux=0 if n_firms_outros_aux==.

bysort numerodaoc códigoitem fase_oc: egen n_firms_me = max(n_firms_me_aux)
bysort numerodaoc códigoitem fase_oc: egen n_firms_epp = max(n_firms_epp_aux)
bysort numerodaoc códigoitem fase_oc: egen n_firms_outros = max(n_firms_outros_aux)


*** Adjusting Cities and States para fornecedores
merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Cep/qualcep/tabela_integrada_final.dta", generate(_merge_cep_fornec)
drop if _merge_cep_fornec==2
replace descriçãouffornecedor=estado_final if descriçãouffornecedor=="SEM GANHADOR"
replace descriçãomunicípiofornecedor = cidade_final if descriçãomunicípiofornecedor =="SEM GANHADOR"
replace descriçãouffornecedor="SÃO PAULO" if descriçãouffornecedor=="SAO PAULO"
drop  cidade cod_cidade uf estado cod_estado cidade_final estado_final _merge_cep_fornec

replace  códigocepfornecedor=firm_zipcode if  códigocepfornecedor==""

*** Same municipality: PBU and Fornecedor

gen same_municip=0
replace same_municip=1 if pbu_city_descr==descriçãomunicípiofornecedor

bysort numerodaoc códigoitem fase_oc: egen n_same_municip_aux = total(particip_firm) if particip_firm==1 & same_municip==1
replace n_same_municip_aux=0 if n_same_municip_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_same_municip = max(n_same_municip_aux)

*** Fornecedor at Estado de SP?

gen fornec_estado_SP=0
replace fornec_estado_SP=1 if  descriçãouffornecedor=="SÃO PAULO"

bysort numerodaoc códigoitem fase_oc: egen n_fornec_estado_SP_aux = total(particip_firm) if particip_firm==1 & fornec_estado_SP==1
replace n_fornec_estado_SP_aux=0 if n_fornec_estado_SP_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_estado_SP = max(n_fornec_estado_SP_aux)

*** Fornecedor at Sao Paulo City

gen fornec_city_SP=0
replace fornec_city_SP=1 if  descriçãomunicípiofornecedor=="SAO PAULO"

bysort numerodaoc códigoitem fase_oc: egen n_fornec_city_SP_aux = total(particip_firm) if particip_firm==1 & fornec_city_SP==1
replace n_fornec_city_SP_aux=0 if n_fornec_city_SP_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_city_SP = max(n_fornec_city_SP_aux)



*** Info about bids
by numerodaoc códigoitem fase_oc: egen min_bid = min(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen max_bid = max(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen mean_bid = mean(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen median_bid = median(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen sd_bid = sd(valorunitárioproposta)

by numerodaoc códigoitem fase_oc: egen p10_bid_phase = pctile(valorunitárioproposta), p(10)
by numerodaoc códigoitem fase_oc: egen p20_bid_phase = pctile(valorunitárioproposta), p(20)
by numerodaoc códigoitem fase_oc: egen p30_bid_phase = pctile(valorunitárioproposta), p(30)
by numerodaoc códigoitem fase_oc: egen p40_bid_phase = pctile(valorunitárioproposta), p(40)
by numerodaoc códigoitem fase_oc: egen p60_bid_phase = pctile(valorunitárioproposta), p(60)
by numerodaoc códigoitem fase_oc: egen p70_bid_phase = pctile(valorunitárioproposta), p(70)
by numerodaoc códigoitem fase_oc: egen p80_bid_phase = pctile(valorunitárioproposta), p(80)
by numerodaoc códigoitem fase_oc: egen p90_bid_phase = pctile(valorunitárioproposta), p(90)


*** Info about distance
by numerodaoc códigoitem fase_oc: egen min_dist = min(dist1)
by numerodaoc códigoitem fase_oc: egen max_dist = max(dist1)

bysort numerodaoc códigoitem fase_oc: egen mean_dist_certo = mean(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen mean_dist_certo1=max(mean_dist_certo)
ren mean_dist_certo1 mean_dist
drop mean_dist_certo

bysort numerodaoc códigoitem fase_oc: egen median_dist_certo = median(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen median_dist_certo1=max(median_dist_certo)
ren median_dist_certo1 median_dist
drop median_dist_certo

bysort numerodaoc códigoitem fase_oc: egen sd_dist_certo = sd(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen sd_dist_certo1=max(sd_dist_certo)
ren sd_dist_certo1 sd_dist
drop sd_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p10_dist_certo = pctile(dist1) if particip_firm==1, p(10)
bysort numerodaoc códigoitem fase_oc: egen p10_dist_phase=max(p10_dist_certo)
drop p10_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p20_dist_certo = pctile(dist1) if particip_firm==1, p(20)
bysort numerodaoc códigoitem fase_oc: egen p20_dist_phase=max(p20_dist_certo)
drop p20_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p30_dist_certo = pctile(dist1) if particip_firm==1, p(30)
bysort numerodaoc códigoitem fase_oc: egen p30_dist_phase=max(p30_dist_certo)
drop p30_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p40_dist_certo = pctile(dist1) if particip_firm==1, p(40)
bysort numerodaoc códigoitem fase_oc: egen p40_dist_phase=max(p40_dist_certo)
drop p40_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p60_dist_certo = pctile(dist1) if particip_firm==1, p(60)
bysort numerodaoc códigoitem fase_oc: egen p60_dist_phase=max(p60_dist_certo)
drop p60_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p70_dist_certo = pctile(dist1) if particip_firm==1, p(70)
bysort numerodaoc códigoitem fase_oc: egen p70_dist_phase=max(p70_dist_certo)
drop p70_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p80_dist_certo = pctile(dist1) if particip_firm==1, p(80)
bysort numerodaoc códigoitem fase_oc: egen p80_dist_phase=max(p80_dist_certo)
drop p80_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p90_dist_certo = pctile(dist1) if particip_firm==1, p(90)
bysort numerodaoc códigoitem fase_oc: egen p90_dist_phase=max(p90_dist_certo)
drop p90_dist_certo


*Parei aqui

*** Calculating firm age at the moment of the tender

gen ddate = daily( data_inicio_atividade , "YMD")
gen mdate = mofd(ddate)
format mdate %tm
gen firm_age=data-mdate
gen firm_age_years=firm_age/12
rename ddate data_inicio_ativid_aux
label variable data_inicio_ativid_aux "Data início atividade fornecedor convertido auxiliar"
drop data_inicio_atividade
ren mdate data_inicio_ativid
label variable data_inicio_ativid "Data início atividade do fornecedor"
label variable firm_age "Idade fornecedor no momento da licitação em meses"
label variable firm_age_years "Idade fornecedor no momento da licitação em anos"


*** Info about firm age (months)

by numerodaoc códigoitem fase_oc: egen min_firm_age_phase = min(firm_age)
by numerodaoc códigoitem fase_oc: egen max_firm_age_phase = max(firm_age)

bysort numerodaoc códigoitem fase_oc: egen mean_firm_age_phase_certo = mean(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen mean_firm_age_phase_certo1=max(mean_firm_age_phase_certo)
ren mean_firm_age_phase_certo1 mean_firm_age_phase
drop mean_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen median_firm_age_phase_certo = median(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen median_firm_age_phase_certo1=max(median_firm_age_phase_certo)
ren median_firm_age_phase_certo1 median_firm_age_phase
drop median_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen sd_firm_age_phase_certo = sd(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen sd_firm_age_phase_certo1=max(sd_firm_age_phase_certo)
ren sd_firm_age_phase_certo1 sd_firm_age_phase
drop sd_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p10_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(10)
bysort numerodaoc códigoitem fase_oc: egen p10_firm_age_phase_phase=max(p10_firm_age_phase_certo)
drop p10_firm_age_phase_certo


bysort numerodaoc códigoitem fase_oc: egen p20_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(20)
bysort numerodaoc códigoitem fase_oc: egen p20_firm_age_phase_phase=max(p20_firm_age_phase_certo)
drop p20_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p30_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(30)
bysort numerodaoc códigoitem fase_oc: egen p30_firm_age_phase_phase=max(p30_firm_age_phase_certo)
drop p30_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p40_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(40)
bysort numerodaoc códigoitem fase_oc: egen p40_firm_age_phase_phase=max(p40_firm_age_phase_certo)
drop p40_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p60_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(60)
bysort numerodaoc códigoitem fase_oc: egen p60_firm_age_phase_phase=max(p60_firm_age_phase_certo)
drop p60_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p70_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(70)
bysort numerodaoc códigoitem fase_oc: egen p70_firm_age_phase_phase=max(p70_firm_age_phase_certo)
drop p70_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p80_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(80)
bysort numerodaoc códigoitem fase_oc: egen p80_firm_age_phase_phase=max(p80_firm_age_phase_certo)
drop p80_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p90_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(90)
bysort numerodaoc códigoitem fase_oc: egen p90_firm_age_phase_phase=max(p90_firm_age_phase_certo)
drop p90_firm_age_phase_certo


ren p10_firm_age_phase_phase p10_firm_age_phase
ren p20_firm_age_phase_phase p20_firm_age_phase
ren p30_firm_age_phase_phase p30_firm_age_phase
ren p40_firm_age_phase_phase p40_firm_age_phase
ren p60_firm_age_phase_phase p60_firm_age_phase
ren p70_firm_age_phase_phase p70_firm_age_phase
ren p80_firm_age_phase_phase p80_firm_age_phase
ren p90_firm_age_phase_phase p90_firm_age_phase


*** Info about firm age (years)
gen min_firm_age_y_phase=min_firm_age_phase/12 
gen max_firm_age_y_phase=max_firm_age_phase/12  
gen mean_firm_age_y_phase=mean_firm_age_phase/12  
gen median_firm_age_y_phase=median_firm_age_phase/12  
gen sd_firm_age_y_phase=sd_firm_age_phase/12  
gen p10_firm_age_y_phase=p10_firm_age_phase/12  
gen p20_firm_age_y_phase=p20_firm_age_phase/12  
gen p30_firm_age_y_phase=p30_firm_age_phase/12  
gen p40_firm_age_y_phase=p40_firm_age_phase/12  
gen p60_firm_age_y_phase=p60_firm_age_phase/12  
gen p70_firm_age_y_phase=p70_firm_age_phase/12  
gen p80_firm_age_y_phase=p80_firm_age_phase/12  
gen p90_firm_age_y_phase=p90_firm_age_phase/12 




*** Second Highest Value
by numerodaoc códigoitem fase_oc: egen second_bid = total(valorunitárioproposta / (rank == 2))


*** Difference between min bid and second lowest value
gen diff_first_second=(second_bid-min_bid)/min_bid


*** Elapsed Time
gen bid_time= datahrproposta
gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
by numerodaoc códigoitem fase_oc: egen min_bid_time_phase = min(bid_time_date)
by numerodaoc códigoitem fase_oc: egen max_bid_time_phase = max(bid_time_date)
gen oc_item_elapsed_time=max_bid_time_phase-min_bid_time_phase
gen oc_item_elapsed_time_hours=oc_item_elapsed_time/3600000
gen oc_item_elapsed_time_minutes=oc_item_elapsed_time_hours*60

format min_bid_time_phase %tc
format max_bid_time_phase %tc
format oc_item_elapsed_time %9.2f
format oc_item_elapsed_time_hours %9.2f
format oc_item_elapsed_time_minutes %9.2f

drop  datahrproposta



*** CNAE

gen cnae_fiscal_length=length(cnae_fiscal)
tab cnae_fiscal_length
replace cnae_fiscal = "0" + cnae_fiscal if cnae_fiscal_length==6
sort cnae_fiscal
drop  cnae_fiscal_length
drop if numerodaoc==""

merge m:1 cnae_fiscal using "/home/darciogm1/projetos/bitter-pills/data/raw/cnae/cnae_21.dta", generate(_merge_cnae)

drop if _merge_cnae==2
drop _merge_cnae

egen cnae_resum_code=group(cnae_resumido)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_agro_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==1
replace n_fornec_agro_aux=0 if n_fornec_agro_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_agro = max(n_fornec_agro_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_comercio_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==2
replace n_fornec_comercio_aux=0 if n_fornec_comercio_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_comercio = max(n_fornec_comercio_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_ind_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==3
replace n_fornec_ind_aux=0 if n_fornec_ind_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_ind = max(n_fornec_ind_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_meioamb_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==4
replace n_fornec_meioamb_aux=0 if n_fornec_meioamb_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_meioamb = max(n_fornec_meioamb_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_serv_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==5
replace n_fornec_serv_aux=0 if n_fornec_serv_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_serv = max(n_fornec_serv_aux)


*** By OC + Item

*** Separating Successful / Failure of OC + Item
by numerodaoc códigoitem : egen winner_bid = min(valorunitárioproposta) if flagvencedor=="1"
by numerodaoc códigoitem : egen winner_bid2 = max(winner_bid)
gen oc_item_success=1
replace oc_item_success=0 if winner_bid2==.
drop winner_bid
ren winner_bid2 winner_bid

*** By OC

*** Identifying distinct items, classes and groups by OC
by numerodaoc códigoitem, sort: gen item_oc_distinct = _n == 1
by numerodaoc códigoclasse, sort: gen classe_oc_distinct = _n == 1
by numerodaoc códigogrupo, sort: gen grupo_oc_distinct = _n == 1


*** Counting distinct items, classes and groups by OC
by numerodaoc : egen item_oc_count = total(item_oc_distinct)
by numerodaoc : egen classe_oc_count = total(classe_oc_distinct)
by numerodaoc : egen grupo_oc_count = total(grupo_oc_distinct)




*** Identifying ocurrence of OC Phases

gen fase_oc1_check=0
gen fase_oc2_check=0
gen fase_oc3_check=0
gen fase_oc4_check=0
gen fase_oc6_check=0
gen fase_oc7_check=0

replace fase_oc1_check=1 if fase_oc==1
replace fase_oc2_check=1 if fase_oc==2
replace fase_oc3_check=1 if fase_oc==3
replace fase_oc4_check=1 if fase_oc==4
replace fase_oc6_check=1 if fase_oc==6
replace fase_oc7_check=1 if fase_oc==7

bysort numerodaoc códigoitem: egen fase_oc1=max(fase_oc1_check)
bysort numerodaoc códigoitem: egen fase_oc2=max(fase_oc2_check)
bysort numerodaoc códigoitem: egen fase_oc3=max(fase_oc3_check)
bysort numerodaoc códigoitem: egen fase_oc4=max(fase_oc4_check)
bysort numerodaoc códigoitem: egen fase_oc6=max(fase_oc6_check)
bysort numerodaoc códigoitem: egen fase_oc7=max(fase_oc7_check)


*** Investigating ocurrence of phases

gen phases_234=0
replace phases_234=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1

gen phases_23=0
replace phases_23=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==0

gen phases_24=0
replace phases_24=1 if fase_oc2==1 & fase_oc4==1 & fase_oc3==0

gen phases_12=0
replace phases_12=1 if fase_oc1==1 & fase_oc2==1

gen phases_26=0
replace phases_26=1 if fase_oc2==1 & fase_oc6==1

gen phases_2346=0
replace phases_2346=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1

gen phases_123467=0
replace phases_123467=1 if fase_oc1==1 & fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1 & fase_oc7==1

gen phases_23467=0
replace phases_23467=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1 & fase_oc7==1




*** Coding OC status

egen oc_status_code=group(oc_status)
label variable oc_status_code "1=ANUL;2=CANCEL;3=C/ VENC;4=S/ VENC;5=FRACASS;6=REVOG"
drop oc_status



*** Judicialized OCs

merge m:1 numerodaoc using "C:/Users/pesquisa/Documents/Papers/Word/OneDrive/Paper 1 - Judicialization/Datasets/2-JUD_REGEX_EDITAIS.dta", generate(_merge_JUD)

replace jud_regex=0 if _merge_JUD==1

gen jud_adm2=jud_adm
replace jud_adm2=0 if strpos(po_subject, "MATERIAL ADMINISTRATIVO") | strpos(po_subject, "MATERIAIS ADMINISTRATIVOS")

replace jud_adm2=0 if jud_adm2==.
gen sum_jud=jud_regex+jud_adm2

gen jud=0
replace jud=1 if sum_jud>0



*** Important variables of dates

rename data data_oc
label variable data_oc "Mês e ano da OC"
rename mês mês_oc
label variable mês_oc "Mês da OC"
rename ano ano_oc
label variable ano_oc "Ano da OC"


*** Droping key
drop chave1


*** Labeling variables

label variable qtde "Quantidade do Item"
replace me_epp=me_epp-1
label variable me_epp "0=N;1=S"
label variable pbu_year "Ano da UC"
label variable pbu_code_year "Código UC + Ano UC"
label variable pbu_ibge_cod_uf "Código UF IBGE da UC"
label variable ibge_cod_cidade_pbu "Código município IBGE da UC"
label variable pbu_city_area "Área km2 município da UC"
label variable pbu_latit "Latitude da UC"
label variable pbu_longit "Longitude da UC"
label variable firm_cnpj "CNPJ Fornecedor"
label variable data_inicio_ativid "Data inicio atividade do fornecedor"
label variable cnae_fiscal "CNAE fornecedor"
label variable porte_empresa "01=ME;03=EPP;05=OUTROS"
label variable firm_zipcode "CEP fornecedor"
label variable fornec_latitude "Latitude fornecedor"
label variable fornec_longitude "Longitude fornecedor"
label variable bid_status "1=Válido ou Classificado"
rename rank rank_fornec_oc
label variable rank_fornec_oc "Rank do fornecedor na OC+Item"
label variable particip_firm "Identificador de firma distinta"
label variable particip_firm_sum "Contagem de firmas distintas por OC+Item"
label variable particip_firm "Identificador de firma distinta"
rename min_bid min_bid_phase
label variable min_bid_phase "Valor mínimo por fase"
label variable max_bid "Valor máximo por fase"
rename max_bid max_bid_phase
rename mean_bid mean_bid_phase
label variable mean_bid_phase "Valor médio por fase"
rename median_bid median_bid_phase
label variable median_bid_phase "Mediana por fase"
rename sd_bid sd_bid_phase
label variable sd_bid_phase "Desvio-padrão por fase"
rename min_dist min_dist_phase
label variable min_dist_phase "Mínima distância por fase"
rename max_dist max_dist_phase
label variable max_dist_phase "Máxima distância por fase"
rename bids_sum bids_sum_phase
label variable bids_sum_phase "Número de bids por fase"
rename second_bid second_bid_phase
label variable second_bid_phase "Bid segundo colocado por fase"
label variable diff_first_second "Diferença em porcentagem entre 1o e 2o bid"
label variable winner_bid "Bid vencedor"
rename winner_bid winner_bid_oc
label variable oc_item_success "0=FRACASSO;1=SUCESSO"
rename mean_dist mean_dist_phase
label variable mean_dist_phase "Média distância por fase"
rename median_dist median_dist_phase
label variable median_dist_phase "Mediana distância por fase"
rename sd_dist sd_dist_phase
label variable sd_dist_phase "Desvio-padrão distância por fase"
label variable fase_oc1_check "0=N houve esta fase; 1=Houve"
label variable fase_oc2_check "0=N houve esta fase; 1=Houve"
label variable fase_oc3_check "0=N houve esta fase; 1=Houve"
label variable fase_oc4_check "0=N houve esta fase; 1=Houve"
label variable fase_oc6_check "0=N houve esta fase; 1=Houve"
label variable fase_oc7_check "0=N houve esta fase; 1=Houve"
label variable fase_oc1 "Por OC: 0=N houve;1=Houve"
label variable fase_oc2 "Por OC: 0=N houve;1=Houve"
label variable fase_oc3 "Por OC: 0=N houve;1=Houve"
label variable fase_oc4 "Por OC: 0=N houve;1=Houve"
label variable fase_oc6 "Por OC: 0=N houve;1=Houve"
label variable fase_oc7 "Por OC: 0=N houve;1=Houve"
label variable phases_234 "0=N houve fases;1=Houve fases"
label variable phases_23 "0=N houve fases;1=Houve fases"
label variable phases_24 "0=N houve fases;1=Houve fases"
label variable phases_12 "0=N houve fases;1=Houve fases"
label variable phases_26 "0=N houve fases;1=Houve fases"
label variable phases_2346 "0=N houve fases;1=Houve fases"
label variable phases_123467 "OC com fases 1,2,3,4,6 e 7"
label variable phases_23467 "OC com fases 2,3,4,6 e 7"
label variable p10_bid_phase "Percentile 10th bid price per phase"
label variable p20_bid_phase "Percentile 20th bid price per phase"
label variable p30_bid_phase "Percentile 30th bid price per phase"
label variable p40_bid_phase "Percentile 40th bid price per phase"
label variable p60_bid_phase "Percentile 60th bid price per phase"
label variable p70_bid_phase "Percentile 70th bid price per phase"
label variable p80_bid_phase "Percentile 80th bid price per phase"
label variable p90_bid_phase "Percentile 90th bid price per phase"
label variable p10_dist_phase "Percentile 10th distance per phase"
label variable p20_dist_phase "Percentile 20th distance per phase"
label variable p30_dist_phase "Percentile 30th distance per phase"
label variable p40_dist_phase "Percentile 40th distance per phase"
label variable p60_dist_phase "Percentile 60th distance per phase"
label variable p70_dist_phase "Percentile 10th distance per phase"
label variable p70_dist_phase "Percentile 70th distance per phase"
label variable p80_dist_phase "Percentile 80th distance per phase"
label variable p90_dist_phase "Percentile 90th distance per phase"
label variable min_firm_age_phase "Min firm age per phase"
label variable max_firm_age_phase "Max firm age per phase"
label variable mean_firm_age_phase "Mean firm age per phase"
label variable median_firm_age_phase "Median firm age per phase"
label variable sd_firm_age_phase "SD firm age per phase"
label variable p10_firm_age_phase "Percentile 10th firm age per phase"
label variable p20_firm_age_phase "Percentile 20th firm age per phase"
label variable p30_firm_age_phase "Percentile 30th firm age per phase"
label variable p40_firm_age_phase "Percentile 40th firm age per phase"
label variable p60_firm_age_phase "Percentile 60th firm age per phase"
label variable p70_firm_age_phase "Percentile 70th firm age per phase"
label variable p80_firm_age_phase "Percentile 80th firm age per phase"
label variable p90_firm_age_phase "Percentile 90th firm age per phase"
label variable min_firm_age_y_phase "Min firm age per phase in years"
label variable max_firm_age_y_phase "Max firm age per phase in years"
label variable mean_firm_age_y_phase "Mean firm age per phase in years"
label variable median_firm_age_y_phase "Median firm age per phase in years"
label variable sd_firm_age_y_phase "SD firm age per phase in years"
label variable p10_firm_age_y_phase "Percentile 10th firm age per phase in years"
label variable p20_firm_age_y_phase "Percentile 20th firm age per phase in years"
label variable p30_firm_age_y_phase "Percentile 30th firm age per phase in years"
label variable p40_firm_age_y_phase "Percentile 40th firm age per phase in years"
label variable p60_firm_age_y_phase "Percentile 60th firm age per phase in years"
label variable p70_firm_age_y_phase "Percentile 70th firm age per phase in years"
label variable p80_firm_age_y_phase "Percentile 80th firm age per phase in years"
label variable p90_firm_age_y_phase "Percentile 90th firm age per phase in years"
label variable bid_time "Data e hora do bid price"
label variable bid_time "Data e hora do bid price string"
label variable bid_time_date "Data e hora do bid price double"
label variable min_bid_time_phase "Min bid time per phase"
label variable max_bid_time_phase "Max bid time per phase"
label variable oc_item_elapsed_time "Elapsed time per phase in miliseconds"
label variable oc_item_elapsed_time_hours "Elapsed time per phase in hours"
label variable oc_item_elapsed_time_minutes "Elapsed time per phase in minutes"
label variable item_oc_distinct "Number of distinct items per OC"
label variable classe_oc_distinct "Number of distinct items classes per OC"
label variable grupo_oc_distinct "Number of distinct items groups per OC"
label variable item_oc_distinct ""
label variable item_oc_count "Number of distinct items per OC"
label variable classe_oc_distinct ""
label variable classe_oc_count "Number of distinct items classes per OC"
label variable grupo_oc_distinct ""
label variable grupo_oc_count "Number of distinct items groups per OC"
label variable item_oc_distinct "Identifying distinct items per OC"
label variable classe_oc_distinct "Identifying distinct items classes per OC"
label variable grupo_oc_distinct "Identifying distinct items groups per OC"
label variable n_firms_me_aux "Number of distinct ME firms"
label variable n_firms_epp_aux "Number of distinct EPP firms"
label variable n_firms_me_aux ""
label variable n_firms_me "Number of distinct ME firms"
label variable n_firms_epp_aux ""
label variable n_firms_epp "Number of distinct EPP firms per phase"
label variable n_firms_me "Number of distinct ME firms per phase"
label variable n_firms_outros "Number of distinct OTHER firms per phase"
label variable n_firms_me_aux "Identifying distinct ME firms per phase"
label variable n_firms_epp_aux "Identifying distinct EPP firms per phase"
label variable n_firms_outros_aux "Identifying distinct OTHER firms per phase"
label variable same_municip "1=UC e Fornec mesmo municipio"
label variable fornec_estado_SP "1=Fornec do Estado de SP"
label variable fornec_city_SP "1=Fornec da cidade de SP"


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_2_final_validbids.dta", replace


************ Preparing Collapse_ ITEMS

drop pbu_year pbu_code_year _merge_JUD valorunitárioproposta flagvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 data_inicio_ativid_aux data_inicio_ativid firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code n_firms_me_aux n_firms_epp_aux n_firms_outros_aux n_same_municip_aux n_fornec_estado_SP_aux n_fornec_city_SP_aux n_fornec_agro_aux n_fornec_comercio_aux n_fornec_ind_aux n_fornec_meioamb_aux n_fornec_serv_aux bid_time bid_time_date min_bid_time_phase max_bid_time_phase item_oc_distinct classe_oc_distinct grupo_oc_distinct valor_total_neg_max rank_fornec_oc particip_firm props_grupo_status descriçãopropostastatus bid_status fase_oc1_check fase_oc2_check fase_oc3_check fase_oc4_check fase_oc6_check fase_oc7_check pubag_descr phases_234 phases_23 phases_24 phases_12 phases_26 phases_2346 phases_123467 phases_23467 p10_bid_phase p20_bid_phase p30_bid_phase p40_bid_phase p60_bid_phase p70_bid_phase p80_bid_phase p90_bid_phase p10_dist_phase p20_dist_phase p30_dist_phase p40_dist_phase p60_dist_phase p70_dist_phase p80_dist_phase p90_dist_phase p10_firm_age_phase p20_firm_age_phase p30_firm_age_phase p40_firm_age_phase p60_firm_age_phase p70_firm_age_phase p80_firm_age_phase p90_firm_age_phase p10_firm_age_y_phase p20_firm_age_y_phase p30_firm_age_y_phase p40_firm_age_y_phase p60_firm_age_y_phase p70_firm_age_y_phase p80_firm_age_y_phase p90_firm_age_y_phase min_firm_age_y_phase max_firm_age_y_phase mean_firm_age_y_phase median_firm_age_y_phase sd_firm_age_y_phase oc_item_elapsed_time oc_item_elapsed_time_hours


order data_oc mês_oc ano_oc numerodaoc oc_status_code códigoitem descitem códigoclasse descclasseitem códigogrupo descgrupoitem proc_compra reg_precos categ_item item_verde preco_ref qtde me_epp oc_item_success sum_jud jud_regex códigounidadecompradora descriçãounidadecompradora pbu_code pbu_cnpj códigouo descriçãouo códigoórgão descriçãoórgão pbu_power pbu_type_mgmt_code pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_ibge_cod_uf ibge_cod_cidade_pbu pbu_city_area pbu_latit pbu_longit descriçãomunicípiodeentrega descriçãoregiãodeentrega fase_oc item_oc_count classe_oc_count grupo_oc_count fase_oc1 fase_oc2 fase_oc3 fase_oc4 fase_oc6 fase_oc7  preco_final min_bid_phase max_bid_phase mean_bid_phase median_bid_phase sd_bid_phase  min_dist_phase max_dist_phase mean_dist_phase median_dist_phase sd_dist_phase  min_firm_age_phase max_firm_age_phase mean_firm_age_phase median_firm_age_phase sd_firm_age_phase    bids_sum_phase particip_firm_sum n_fornec_agro n_fornec_comercio n_fornec_ind n_fornec_meioamb n_fornec_serv n_firms_me n_firms_epp n_firms_outros n_same_municip n_fornec_estado_SP n_fornec_city_SP  oc_item_elapsed_time_minutes second_bid_phase diff_first_second winner_bid_oc 


***** Bid Value for each phase

** Min

gen min_bid_phase1=0
gen min_bid_phase2=0
gen min_bid_phase3=0
gen min_bid_phase4=0
gen min_bid_phase6=0
gen min_bid_phase7=0

replace min_bid_phase1=min_bid_phase if fase_oc==1
replace min_bid_phase2=min_bid_phase if fase_oc==2
replace min_bid_phase3=min_bid_phase if fase_oc==3
replace min_bid_phase4=min_bid_phase if fase_oc==4
replace min_bid_phase6=min_bid_phase if fase_oc==6
replace min_bid_phase7=min_bid_phase if fase_oc==7

drop min_bid_phase



** Max

gen max_bid_phase1=0
gen max_bid_phase2=0
gen max_bid_phase3=0
gen max_bid_phase4=0
gen max_bid_phase6=0
gen max_bid_phase7=0

replace max_bid_phase1=max_bid_phase if fase_oc==1
replace max_bid_phase2=max_bid_phase if fase_oc==2
replace max_bid_phase3=max_bid_phase if fase_oc==3
replace max_bid_phase4=max_bid_phase if fase_oc==4
replace max_bid_phase6=max_bid_phase if fase_oc==6
replace max_bid_phase7=max_bid_phase if fase_oc==7

drop max_bid_phase


** Mean

gen mean_bid_phase1=0
gen mean_bid_phase2=0
gen mean_bid_phase3=0
gen mean_bid_phase4=0
gen mean_bid_phase6=0
gen mean_bid_phase7=0

replace mean_bid_phase1=mean_bid_phase if fase_oc==1
replace mean_bid_phase2=mean_bid_phase if fase_oc==2
replace mean_bid_phase3=mean_bid_phase if fase_oc==3
replace mean_bid_phase4=mean_bid_phase if fase_oc==4
replace mean_bid_phase6=mean_bid_phase if fase_oc==6
replace mean_bid_phase7=mean_bid_phase if fase_oc==7

drop mean_bid_phase


** Median

gen median_bid_phase1=0
gen median_bid_phase2=0
gen median_bid_phase3=0
gen median_bid_phase4=0
gen median_bid_phase6=0
gen median_bid_phase7=0

replace median_bid_phase1=median_bid_phase if fase_oc==1
replace median_bid_phase2=median_bid_phase if fase_oc==2
replace median_bid_phase3=median_bid_phase if fase_oc==3
replace median_bid_phase4=median_bid_phase if fase_oc==4
replace median_bid_phase6=median_bid_phase if fase_oc==6
replace median_bid_phase7=median_bid_phase if fase_oc==7

drop median_bid_phase


** Standard Deviation

gen sd_bid_phase1=0
gen sd_bid_phase2=0
gen sd_bid_phase3=0
gen sd_bid_phase4=0
gen sd_bid_phase6=0
gen sd_bid_phase7=0

replace sd_bid_phase1=sd_bid_phase if fase_oc==1
replace sd_bid_phase2=sd_bid_phase if fase_oc==2
replace sd_bid_phase3=sd_bid_phase if fase_oc==3
replace sd_bid_phase4=sd_bid_phase if fase_oc==4
replace sd_bid_phase6=sd_bid_phase if fase_oc==6
replace sd_bid_phase7=sd_bid_phase if fase_oc==7

drop sd_bid_phase





***** Distance

** Min

gen min_dist_phase1=0
gen min_dist_phase2=0
gen min_dist_phase3=0
gen min_dist_phase4=0
gen min_dist_phase6=0
gen min_dist_phase7=0

replace min_dist_phase1=min_dist_phase if fase_oc==1
replace min_dist_phase2=min_dist_phase if fase_oc==2
replace min_dist_phase3=min_dist_phase if fase_oc==3
replace min_dist_phase4=min_dist_phase if fase_oc==4
replace min_dist_phase6=min_dist_phase if fase_oc==6
replace min_dist_phase7=min_dist_phase if fase_oc==7

drop min_dist_phase



** Max

gen max_dist_phase1=0
gen max_dist_phase2=0
gen max_dist_phase3=0
gen max_dist_phase4=0
gen max_dist_phase6=0
gen max_dist_phase7=0

replace max_dist_phase1=max_dist_phase if fase_oc==1
replace max_dist_phase2=max_dist_phase if fase_oc==2
replace max_dist_phase3=max_dist_phase if fase_oc==3
replace max_dist_phase4=max_dist_phase if fase_oc==4
replace max_dist_phase6=max_dist_phase if fase_oc==6
replace max_dist_phase7=max_dist_phase if fase_oc==7

drop max_dist_phase


** Mean

gen mean_dist_phase1=0
gen mean_dist_phase2=0
gen mean_dist_phase3=0
gen mean_dist_phase4=0
gen mean_dist_phase6=0
gen mean_dist_phase7=0

replace mean_dist_phase1=mean_dist_phase if fase_oc==1
replace mean_dist_phase2=mean_dist_phase if fase_oc==2
replace mean_dist_phase3=mean_dist_phase if fase_oc==3
replace mean_dist_phase4=mean_dist_phase if fase_oc==4
replace mean_dist_phase6=mean_dist_phase if fase_oc==6
replace mean_dist_phase7=mean_dist_phase if fase_oc==7

drop mean_dist_phase


** Median

gen median_dist_phase1=0
gen median_dist_phase2=0
gen median_dist_phase3=0
gen median_dist_phase4=0
gen median_dist_phase6=0
gen median_dist_phase7=0

replace median_dist_phase1=median_dist_phase if fase_oc==1
replace median_dist_phase2=median_dist_phase if fase_oc==2
replace median_dist_phase3=median_dist_phase if fase_oc==3
replace median_dist_phase4=median_dist_phase if fase_oc==4
replace median_dist_phase6=median_dist_phase if fase_oc==6
replace median_dist_phase7=median_dist_phase if fase_oc==7

drop median_dist_phase


** Standard Deviation

gen sd_dist_phase1=0
gen sd_dist_phase2=0
gen sd_dist_phase3=0
gen sd_dist_phase4=0
gen sd_dist_phase6=0
gen sd_dist_phase7=0

replace sd_dist_phase1=sd_dist_phase if fase_oc==1
replace sd_dist_phase2=sd_dist_phase if fase_oc==2
replace sd_dist_phase3=sd_dist_phase if fase_oc==3
replace sd_dist_phase4=sd_dist_phase if fase_oc==4
replace sd_dist_phase6=sd_dist_phase if fase_oc==6
replace sd_dist_phase7=sd_dist_phase if fase_oc==7

drop sd_dist_phase



***** Firm Age (in months)

** Min

gen min_firm_age_phase1=0
gen min_firm_age_phase2=0
gen min_firm_age_phase3=0
gen min_firm_age_phase4=0
gen min_firm_age_phase6=0
gen min_firm_age_phase7=0

replace min_firm_age_phase1=min_firm_age_phase if fase_oc==1
replace min_firm_age_phase2=min_firm_age_phase if fase_oc==2
replace min_firm_age_phase3=min_firm_age_phase if fase_oc==3
replace min_firm_age_phase4=min_firm_age_phase if fase_oc==4
replace min_firm_age_phase6=min_firm_age_phase if fase_oc==6
replace min_firm_age_phase7=min_firm_age_phase if fase_oc==7

drop min_firm_age_phase



** Max

gen max_firm_age_phase1=0
gen max_firm_age_phase2=0
gen max_firm_age_phase3=0
gen max_firm_age_phase4=0
gen max_firm_age_phase6=0
gen max_firm_age_phase7=0

replace max_firm_age_phase1=max_firm_age_phase if fase_oc==1
replace max_firm_age_phase2=max_firm_age_phase if fase_oc==2
replace max_firm_age_phase3=max_firm_age_phase if fase_oc==3
replace max_firm_age_phase4=max_firm_age_phase if fase_oc==4
replace max_firm_age_phase6=max_firm_age_phase if fase_oc==6
replace max_firm_age_phase7=max_firm_age_phase if fase_oc==7

drop max_firm_age_phase


** Mean

gen mean_firm_age_phase1=0
gen mean_firm_age_phase2=0
gen mean_firm_age_phase3=0
gen mean_firm_age_phase4=0
gen mean_firm_age_phase6=0
gen mean_firm_age_phase7=0

replace mean_firm_age_phase1=mean_firm_age_phase if fase_oc==1
replace mean_firm_age_phase2=mean_firm_age_phase if fase_oc==2
replace mean_firm_age_phase3=mean_firm_age_phase if fase_oc==3
replace mean_firm_age_phase4=mean_firm_age_phase if fase_oc==4
replace mean_firm_age_phase6=mean_firm_age_phase if fase_oc==6
replace mean_firm_age_phase7=mean_firm_age_phase if fase_oc==7

drop mean_firm_age_phase


** Median

gen median_firm_age_phase1=0
gen median_firm_age_phase2=0
gen median_firm_age_phase3=0
gen median_firm_age_phase4=0
gen median_firm_age_phase6=0
gen median_firm_age_phase7=0

replace median_firm_age_phase1=median_firm_age_phase if fase_oc==1
replace median_firm_age_phase2=median_firm_age_phase if fase_oc==2
replace median_firm_age_phase3=median_firm_age_phase if fase_oc==3
replace median_firm_age_phase4=median_firm_age_phase if fase_oc==4
replace median_firm_age_phase6=median_firm_age_phase if fase_oc==6
replace median_firm_age_phase7=median_firm_age_phase if fase_oc==7

drop median_firm_age_phase


** Standard Deviation

gen sd_firm_age_phase1=0
gen sd_firm_age_phase2=0
gen sd_firm_age_phase3=0
gen sd_firm_age_phase4=0
gen sd_firm_age_phase6=0
gen sd_firm_age_phase7=0

replace sd_firm_age_phase1=sd_firm_age_phase if fase_oc==1
replace sd_firm_age_phase2=sd_firm_age_phase if fase_oc==2
replace sd_firm_age_phase3=sd_firm_age_phase if fase_oc==3
replace sd_firm_age_phase4=sd_firm_age_phase if fase_oc==4
replace sd_firm_age_phase6=sd_firm_age_phase if fase_oc==6
replace sd_firm_age_phase7=sd_firm_age_phase if fase_oc==7

drop sd_firm_age_phase



***** Counting Fornecs

** # bids

gen numbids_phase1=0
gen numbids_phase2=0
gen numbids_phase3=0
gen numbids_phase4=0
gen numbids_phase6=0
gen numbids_phase7=0

replace numbids_phase1=bids_sum_phase if fase_oc==1
replace numbids_phase2=bids_sum_phase if fase_oc==2
replace numbids_phase3=bids_sum_phase if fase_oc==3
replace numbids_phase4=bids_sum_phase if fase_oc==4
replace numbids_phase6=bids_sum_phase if fase_oc==6
replace numbids_phase7=bids_sum_phase if fase_oc==7

drop bids_sum_phase


** # participant firms

gen numfornecs_phase1=0
gen numfornecs_phase2=0
gen numfornecs_phase3=0
gen numfornecs_phase4=0
gen numfornecs_phase6=0
gen numfornecs_phase7=0

replace numfornecs_phase1=particip_firm_sum if fase_oc==1
replace numfornecs_phase2=particip_firm_sum if fase_oc==2
replace numfornecs_phase3=particip_firm_sum if fase_oc==3
replace numfornecs_phase4=particip_firm_sum if fase_oc==4
replace numfornecs_phase6=particip_firm_sum if fase_oc==6
replace numfornecs_phase7=particip_firm_sum if fase_oc==7

drop particip_firm_sum


** # fornecs Agro e Pesca

gen numfornecs_agro_phase1=0
gen numfornecs_agro_phase2=0
gen numfornecs_agro_phase3=0
gen numfornecs_agro_phase4=0
gen numfornecs_agro_phase6=0
gen numfornecs_agro_phase7=0

replace numfornecs_agro_phase1=n_fornec_agro if fase_oc==1
replace numfornecs_agro_phase2=n_fornec_agro if fase_oc==2
replace numfornecs_agro_phase3=n_fornec_agro if fase_oc==3
replace numfornecs_agro_phase4=n_fornec_agro if fase_oc==4
replace numfornecs_agro_phase6=n_fornec_agro if fase_oc==6
replace numfornecs_agro_phase7=n_fornec_agro if fase_oc==7

drop n_fornec_agro


** # fornecs Comércio

gen numfornecs_comercio_phase1=0
gen numfornecs_comercio_phase2=0
gen numfornecs_comercio_phase3=0
gen numfornecs_comercio_phase4=0
gen numfornecs_comercio_phase6=0
gen numfornecs_comercio_phase7=0

replace numfornecs_comercio_phase1=n_fornec_comercio if fase_oc==1
replace numfornecs_comercio_phase2=n_fornec_comercio if fase_oc==2
replace numfornecs_comercio_phase3=n_fornec_comercio if fase_oc==3
replace numfornecs_comercio_phase4=n_fornec_comercio if fase_oc==4
replace numfornecs_comercio_phase6=n_fornec_comercio if fase_oc==6
replace numfornecs_comercio_phase7=n_fornec_comercio if fase_oc==7

drop n_fornec_comercio


** # fornecs Indústria

gen numfornecs_ind_phase1=0
gen numfornecs_ind_phase2=0
gen numfornecs_ind_phase3=0
gen numfornecs_ind_phase4=0
gen numfornecs_ind_phase6=0
gen numfornecs_ind_phase7=0

replace numfornecs_ind_phase1=n_fornec_ind if fase_oc==1
replace numfornecs_ind_phase2=n_fornec_ind if fase_oc==2
replace numfornecs_ind_phase3=n_fornec_ind if fase_oc==3
replace numfornecs_ind_phase4=n_fornec_ind if fase_oc==4
replace numfornecs_ind_phase6=n_fornec_ind if fase_oc==6
replace numfornecs_ind_phase7=n_fornec_ind if fase_oc==7

drop n_fornec_ind


** # fornecs Meio Ambiente

gen numfornecs_meioamb_phase1=0
gen numfornecs_meioamb_phase2=0
gen numfornecs_meioamb_phase3=0
gen numfornecs_meioamb_phase4=0
gen numfornecs_meioamb_phase6=0
gen numfornecs_meioamb_phase7=0

replace numfornecs_meioamb_phase1=n_fornec_meioamb if fase_oc==1
replace numfornecs_meioamb_phase2=n_fornec_meioamb if fase_oc==2
replace numfornecs_meioamb_phase3=n_fornec_meioamb if fase_oc==3
replace numfornecs_meioamb_phase4=n_fornec_meioamb if fase_oc==4
replace numfornecs_meioamb_phase6=n_fornec_meioamb if fase_oc==6
replace numfornecs_meioamb_phase7=n_fornec_meioamb if fase_oc==7

drop n_fornec_meioamb



** # fornecs Serviços

gen numfornecs_serv_phase1=0
gen numfornecs_serv_phase2=0
gen numfornecs_serv_phase3=0
gen numfornecs_serv_phase4=0
gen numfornecs_serv_phase6=0
gen numfornecs_serv_phase7=0

replace numfornecs_serv_phase1=n_fornec_serv if fase_oc==1
replace numfornecs_serv_phase2=n_fornec_serv if fase_oc==2
replace numfornecs_serv_phase3=n_fornec_serv if fase_oc==3
replace numfornecs_serv_phase4=n_fornec_serv if fase_oc==4
replace numfornecs_serv_phase6=n_fornec_serv if fase_oc==6
replace numfornecs_serv_phase7=n_fornec_serv if fase_oc==7

drop n_fornec_serv


** # fornecs type ME

gen numfornecs_type_me_phase1=0
gen numfornecs_type_me_phase2=0
gen numfornecs_type_me_phase3=0
gen numfornecs_type_me_phase4=0
gen numfornecs_type_me_phase6=0
gen numfornecs_type_me_phase7=0

replace numfornecs_type_me_phase1=n_firms_me if fase_oc==1
replace numfornecs_type_me_phase2=n_firms_me if fase_oc==2
replace numfornecs_type_me_phase3=n_firms_me if fase_oc==3
replace numfornecs_type_me_phase4=n_firms_me if fase_oc==4
replace numfornecs_type_me_phase6=n_firms_me if fase_oc==6
replace numfornecs_type_me_phase7=n_firms_me if fase_oc==7

drop  n_firms_me


** # fornecs type EPP

gen numfornecs_type_epp_phase1=0
gen numfornecs_type_epp_phase2=0
gen numfornecs_type_epp_phase3=0
gen numfornecs_type_epp_phase4=0
gen numfornecs_type_epp_phase6=0
gen numfornecs_type_epp_phase7=0

replace numfornecs_type_epp_phase1=n_firms_epp if fase_oc==1
replace numfornecs_type_epp_phase2=n_firms_epp if fase_oc==2
replace numfornecs_type_epp_phase3=n_firms_epp if fase_oc==3
replace numfornecs_type_epp_phase4=n_firms_epp if fase_oc==4
replace numfornecs_type_epp_phase6=n_firms_epp if fase_oc==6
replace numfornecs_type_epp_phase7=n_firms_epp if fase_oc==7

drop  n_firms_epp


** # fornecs type OTHER

gen numfornecs_type_oth_phase1=0
gen numfornecs_type_oth_phase2=0
gen numfornecs_type_oth_phase3=0
gen numfornecs_type_oth_phase4=0
gen numfornecs_type_oth_phase6=0
gen numfornecs_type_oth_phase7=0

replace numfornecs_type_oth_phase1=n_firms_outros if fase_oc==1
replace numfornecs_type_oth_phase2=n_firms_outros if fase_oc==2
replace numfornecs_type_oth_phase3=n_firms_outros if fase_oc==3
replace numfornecs_type_oth_phase4=n_firms_outros if fase_oc==4
replace numfornecs_type_oth_phase6=n_firms_outros if fase_oc==6
replace numfornecs_type_oth_phase7=n_firms_outros if fase_oc==7

drop  n_firms_outros


** # fornecs same municip (UC and fornec)

gen numfornecs_same_munic_phase1=0
gen numfornecs_same_munic_phase2=0
gen numfornecs_same_munic_phase3=0
gen numfornecs_same_munic_phase4=0
gen numfornecs_same_munic_phase6=0
gen numfornecs_same_munic_phase7=0

replace numfornecs_same_munic_phase1=n_same_municip if fase_oc==1
replace numfornecs_same_munic_phase2=n_same_municip if fase_oc==2
replace numfornecs_same_munic_phase3=n_same_municip if fase_oc==3
replace numfornecs_same_munic_phase4=n_same_municip if fase_oc==4
replace numfornecs_same_munic_phase6=n_same_municip if fase_oc==6
replace numfornecs_same_munic_phase7=n_same_municip if fase_oc==7

drop n_same_municip


** # fornecs estado SP

gen numfornecs_est_SP_phase1=0
gen numfornecs_est_SP_phase2=0
gen numfornecs_est_SP_phase3=0
gen numfornecs_est_SP_phase4=0
gen numfornecs_est_SP_phase6=0
gen numfornecs_est_SP_phase7=0

replace numfornecs_est_SP_phase1=n_fornec_estado_SP if fase_oc==1
replace numfornecs_est_SP_phase2=n_fornec_estado_SP if fase_oc==2
replace numfornecs_est_SP_phase3=n_fornec_estado_SP if fase_oc==3
replace numfornecs_est_SP_phase4=n_fornec_estado_SP if fase_oc==4
replace numfornecs_est_SP_phase6=n_fornec_estado_SP if fase_oc==6
replace numfornecs_est_SP_phase7=n_fornec_estado_SP if fase_oc==7

drop n_fornec_estado_SP 


** # fornecs estado SP

gen numfornecs_city_SP_phase1=0
gen numfornecs_city_SP_phase2=0
gen numfornecs_city_SP_phase3=0
gen numfornecs_city_SP_phase4=0
gen numfornecs_city_SP_phase6=0
gen numfornecs_city_SP_phase7=0

replace numfornecs_city_SP_phase1=n_fornec_city_SP if fase_oc==1
replace numfornecs_city_SP_phase2=n_fornec_city_SP if fase_oc==2
replace numfornecs_city_SP_phase3=n_fornec_city_SP if fase_oc==3
replace numfornecs_city_SP_phase4=n_fornec_city_SP if fase_oc==4
replace numfornecs_city_SP_phase6=n_fornec_city_SP if fase_oc==6
replace numfornecs_city_SP_phase7=n_fornec_city_SP if fase_oc==7

drop n_fornec_city_SP



***** Elapsed Time

gen elapsed_time_phase1=0
gen elapsed_time_phase2=0
gen elapsed_time_phase3=0
gen elapsed_time_phase4=0
gen elapsed_time_phase6=0
gen elapsed_time_phase7=0

replace elapsed_time_phase1=oc_item_elapsed_time_minutes if fase_oc==1
replace elapsed_time_phase2=oc_item_elapsed_time_minutes if fase_oc==2
replace elapsed_time_phase3=oc_item_elapsed_time_minutes if fase_oc==3
replace elapsed_time_phase4=oc_item_elapsed_time_minutes if fase_oc==4
replace elapsed_time_phase6=oc_item_elapsed_time_minutes if fase_oc==6
replace elapsed_time_phase7=oc_item_elapsed_time_minutes if fase_oc==7

drop oc_item_elapsed_time_minutes 



***** Second Bid

gen second_bid_phase1=0
gen second_bid_phase2=0
gen second_bid_phase3=0
gen second_bid_phase4=0
gen second_bid_phase6=0
gen second_bid_phase7=0

replace second_bid_phase1=second_bid_phase if fase_oc==1
replace second_bid_phase2=second_bid_phase if fase_oc==2
replace second_bid_phase3=second_bid_phase if fase_oc==3
replace second_bid_phase4=second_bid_phase if fase_oc==4
replace second_bid_phase6=second_bid_phase if fase_oc==6
replace second_bid_phase7=second_bid_phase if fase_oc==7


drop second_bid_phase 


***** Difference between first and second bids

gen diff_first_sec_phase1=0
gen diff_first_sec_phase2=0
gen diff_first_sec_phase3=0
gen diff_first_sec_phase4=0
gen diff_first_sec_phase6=0
gen diff_first_sec_phase7=0

replace diff_first_sec_phase1=diff_first_second if fase_oc==1
replace diff_first_sec_phase2=diff_first_second if fase_oc==2
replace diff_first_sec_phase3=diff_first_second if fase_oc==3
replace diff_first_sec_phase4=diff_first_second if fase_oc==4
replace diff_first_sec_phase6=diff_first_second if fase_oc==6
replace diff_first_sec_phase7=diff_first_second if fase_oc==7



drop diff_first_second

drop fase_oc

*** Filling Missing Data


duplicates drop


bysort numerodaoc códigoitem: egen  min_bid_ph1 =max(min_bid_phase1)
bysort numerodaoc códigoitem: egen  min_bid_ph2 =max(min_bid_phase2)
bysort numerodaoc códigoitem: egen  min_bid_ph3 =max(min_bid_phase3)
bysort numerodaoc códigoitem: egen  min_bid_ph4 =max(min_bid_phase4)
bysort numerodaoc códigoitem: egen  min_bid_ph6 =max(min_bid_phase6)
bysort numerodaoc códigoitem: egen  min_bid_ph7 =max(min_bid_phase7)
bysort numerodaoc códigoitem: egen  max_bid_ph1 =max(max_bid_phase1)
bysort numerodaoc códigoitem: egen  max_bid_ph2 =max(max_bid_phase2)
bysort numerodaoc códigoitem: egen  max_bid_ph3 =max(max_bid_phase3)
bysort numerodaoc códigoitem: egen  max_bid_ph4 =max(max_bid_phase4)
bysort numerodaoc códigoitem: egen  max_bid_ph6 =max(max_bid_phase6)
bysort numerodaoc códigoitem: egen  max_bid_ph7 =max(max_bid_phase7)
bysort numerodaoc códigoitem: egen  mean_bid_ph1 =max(mean_bid_phase1)
bysort numerodaoc códigoitem: egen  mean_bid_ph2 =max(mean_bid_phase2)
bysort numerodaoc códigoitem: egen  mean_bid_ph3 =max(mean_bid_phase3)
bysort numerodaoc códigoitem: egen  mean_bid_ph4 =max(mean_bid_phase4)
bysort numerodaoc códigoitem: egen  mean_bid_ph6 =max(mean_bid_phase6)
bysort numerodaoc códigoitem: egen  mean_bid_ph7 =max(mean_bid_phase7)
bysort numerodaoc códigoitem: egen  median_bid_ph1 =max(median_bid_phase1)
bysort numerodaoc códigoitem: egen  median_bid_ph2 =max(median_bid_phase2)
bysort numerodaoc códigoitem: egen  median_bid_ph3 =max(median_bid_phase3)
bysort numerodaoc códigoitem: egen  median_bid_ph4 =max(median_bid_phase4)
bysort numerodaoc códigoitem: egen  median_bid_ph6 =max(median_bid_phase6)
bysort numerodaoc códigoitem: egen  median_bid_ph7 =max(median_bid_phase7)
bysort numerodaoc códigoitem: egen  sd_bid_ph1 =max(sd_bid_phase1)
bysort numerodaoc códigoitem: egen  sd_bid_ph2 =max(sd_bid_phase2)
bysort numerodaoc códigoitem: egen  sd_bid_ph3 =max(sd_bid_phase3)
bysort numerodaoc códigoitem: egen  sd_bid_ph4 =max(sd_bid_phase4)
bysort numerodaoc códigoitem: egen  sd_bid_ph6 =max(sd_bid_phase6)
bysort numerodaoc códigoitem: egen  sd_bid_ph7 =max(sd_bid_phase7)
bysort numerodaoc códigoitem: egen  min_dist_ph1 =max(min_dist_phase1)
bysort numerodaoc códigoitem: egen  min_dist_ph2 =max(min_dist_phase2)
bysort numerodaoc códigoitem: egen  min_dist_ph3 =max(min_dist_phase3)
bysort numerodaoc códigoitem: egen  min_dist_ph4 =max(min_dist_phase4)
bysort numerodaoc códigoitem: egen  min_dist_ph6 =max(min_dist_phase6)
bysort numerodaoc códigoitem: egen  min_dist_ph7 =max(min_dist_phase7)
bysort numerodaoc códigoitem: egen  max_dist_ph1 =max(max_dist_phase1)
bysort numerodaoc códigoitem: egen  max_dist_ph2 =max(max_dist_phase2)
bysort numerodaoc códigoitem: egen  max_dist_ph3 =max(max_dist_phase3)
bysort numerodaoc códigoitem: egen  max_dist_ph4 =max(max_dist_phase4)
bysort numerodaoc códigoitem: egen  max_dist_ph6 =max(max_dist_phase6)
bysort numerodaoc códigoitem: egen  max_dist_ph7 =max(max_dist_phase7)
bysort numerodaoc códigoitem: egen  mean_dist_ph1 =max(mean_dist_phase1)
bysort numerodaoc códigoitem: egen  mean_dist_ph2 =max(mean_dist_phase2)
bysort numerodaoc códigoitem: egen  mean_dist_ph3 =max(mean_dist_phase3)
bysort numerodaoc códigoitem: egen  mean_dist_ph4 =max(mean_dist_phase4)
bysort numerodaoc códigoitem: egen  mean_dist_ph6 =max(mean_dist_phase6)
bysort numerodaoc códigoitem: egen  mean_dist_ph7 =max(mean_dist_phase7)
bysort numerodaoc códigoitem: egen  median_dist_ph1 =max(median_dist_phase1)
bysort numerodaoc códigoitem: egen  median_dist_ph2 =max(median_dist_phase2)
bysort numerodaoc códigoitem: egen  median_dist_ph3 =max(median_dist_phase3)
bysort numerodaoc códigoitem: egen  median_dist_ph4 =max(median_dist_phase4)
bysort numerodaoc códigoitem: egen  median_dist_ph6 =max(median_dist_phase6)
bysort numerodaoc códigoitem: egen  median_dist_ph7 =max(median_dist_phase7)
bysort numerodaoc códigoitem: egen  sd_dist_ph1 =max(sd_dist_phase1)
bysort numerodaoc códigoitem: egen  sd_dist_ph2 =max(sd_dist_phase2)
bysort numerodaoc códigoitem: egen  sd_dist_ph3 =max(sd_dist_phase3)
bysort numerodaoc códigoitem: egen  sd_dist_ph4 =max(sd_dist_phase4)
bysort numerodaoc códigoitem: egen  sd_dist_ph6 =max(sd_dist_phase6)
bysort numerodaoc códigoitem: egen  sd_dist_ph7 =max(sd_dist_phase7)
bysort numerodaoc códigoitem: egen  min_firm_age_ph1 =max(min_firm_age_phase1)
bysort numerodaoc códigoitem: egen  min_firm_age_ph2 =max(min_firm_age_phase2)
bysort numerodaoc códigoitem: egen  min_firm_age_ph3 =max(min_firm_age_phase3)
bysort numerodaoc códigoitem: egen  min_firm_age_ph4 =max(min_firm_age_phase4)
bysort numerodaoc códigoitem: egen  min_firm_age_ph6 =max(min_firm_age_phase6)
bysort numerodaoc códigoitem: egen  min_firm_age_ph7 =max(min_firm_age_phase7)
bysort numerodaoc códigoitem: egen  max_firm_age_ph1 =max(max_firm_age_phase1)
bysort numerodaoc códigoitem: egen  max_firm_age_ph2 =max(max_firm_age_phase2)
bysort numerodaoc códigoitem: egen  max_firm_age_ph3 =max(max_firm_age_phase3)
bysort numerodaoc códigoitem: egen  max_firm_age_ph4 =max(max_firm_age_phase4)
bysort numerodaoc códigoitem: egen  max_firm_age_ph6 =max(max_firm_age_phase6)
bysort numerodaoc códigoitem: egen  max_firm_age_ph7 =max(max_firm_age_phase7)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph1 =max(mean_firm_age_phase1)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph2 =max(mean_firm_age_phase2)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph3 =max(mean_firm_age_phase3)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph4 =max(mean_firm_age_phase4)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph6 =max(mean_firm_age_phase6)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph7 =max(mean_firm_age_phase7)
bysort numerodaoc códigoitem: egen  median_firm_age_ph1 =max(median_firm_age_phase1)
bysort numerodaoc códigoitem: egen  median_firm_age_ph2 =max(median_firm_age_phase2)
bysort numerodaoc códigoitem: egen  median_firm_age_ph3 =max(median_firm_age_phase3)
bysort numerodaoc códigoitem: egen  median_firm_age_ph4 =max(median_firm_age_phase4)
bysort numerodaoc códigoitem: egen  median_firm_age_ph6 =max(median_firm_age_phase6)
bysort numerodaoc códigoitem: egen  median_firm_age_ph7 =max(median_firm_age_phase7)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph1 =max(sd_firm_age_phase1)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph2 =max(sd_firm_age_phase2)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph3 =max(sd_firm_age_phase3)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph4 =max(sd_firm_age_phase4)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph6 =max(sd_firm_age_phase6)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph7 =max(sd_firm_age_phase7)
bysort numerodaoc códigoitem: egen  numbids_ph1 =max(numbids_phase1)
bysort numerodaoc códigoitem: egen  numbids_ph2 =max(numbids_phase2)
bysort numerodaoc códigoitem: egen  numbids_ph3 =max(numbids_phase3)
bysort numerodaoc códigoitem: egen  numbids_ph4 =max(numbids_phase4)
bysort numerodaoc códigoitem: egen  numbids_ph6 =max(numbids_phase6)
bysort numerodaoc códigoitem: egen  numbids_ph7 =max(numbids_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_ph1 =max(numfornecs_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_ph2 =max(numfornecs_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_ph3 =max(numfornecs_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_ph4 =max(numfornecs_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_ph6 =max(numfornecs_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_ph7 =max(numfornecs_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph1 =max(numfornecs_agro_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph2 =max(numfornecs_agro_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph3 =max(numfornecs_agro_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph4 =max(numfornecs_agro_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph6 =max(numfornecs_agro_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph7 =max(numfornecs_agro_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph1 =max(numfornecs_comercio_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph2 =max(numfornecs_comercio_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph3 =max(numfornecs_comercio_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph4 =max(numfornecs_comercio_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph6 =max(numfornecs_comercio_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph7 =max(numfornecs_comercio_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph1 =max(numfornecs_ind_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph2 =max(numfornecs_ind_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph3 =max(numfornecs_ind_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph4 =max(numfornecs_ind_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph6 =max(numfornecs_ind_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph7 =max(numfornecs_ind_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph1 =max(numfornecs_meioamb_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph2 =max(numfornecs_meioamb_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph3 =max(numfornecs_meioamb_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph4 =max(numfornecs_meioamb_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph6 =max(numfornecs_meioamb_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph7 =max(numfornecs_meioamb_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph1 =max(numfornecs_serv_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph2 =max(numfornecs_serv_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph3 =max(numfornecs_serv_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph4 =max(numfornecs_serv_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph6 =max(numfornecs_serv_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph7 =max(numfornecs_serv_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph1 =max(numfornecs_type_me_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph2 =max(numfornecs_type_me_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph3 =max(numfornecs_type_me_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph4 =max(numfornecs_type_me_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph6 =max(numfornecs_type_me_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph7 =max(numfornecs_type_me_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph1 =max(numfornecs_type_epp_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph2 =max(numfornecs_type_epp_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph3 =max(numfornecs_type_epp_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph4 =max(numfornecs_type_epp_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph6 =max(numfornecs_type_epp_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph7 =max(numfornecs_type_epp_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph1 =max(numfornecs_type_oth_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph2 =max(numfornecs_type_oth_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph3 =max(numfornecs_type_oth_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph4 =max(numfornecs_type_oth_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph6 =max(numfornecs_type_oth_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph7 =max(numfornecs_type_oth_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph1 =max(numfornecs_same_munic_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph2 =max(numfornecs_same_munic_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph3 =max(numfornecs_same_munic_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph4 =max(numfornecs_same_munic_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph6 =max(numfornecs_same_munic_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph7 =max(numfornecs_same_munic_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph1 =max(numfornecs_est_SP_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph2 =max(numfornecs_est_SP_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph3 =max(numfornecs_est_SP_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph4 =max(numfornecs_est_SP_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph6 =max(numfornecs_est_SP_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph7 =max(numfornecs_est_SP_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph1 =max(numfornecs_city_SP_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph2 =max(numfornecs_city_SP_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph3 =max(numfornecs_city_SP_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph4 =max(numfornecs_city_SP_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph6 =max(numfornecs_city_SP_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph7 =max(numfornecs_city_SP_phase7)
bysort numerodaoc códigoitem: egen  elapsed_time_ph1 =max(elapsed_time_phase1)
bysort numerodaoc códigoitem: egen  elapsed_time_ph2 =max(elapsed_time_phase2)
bysort numerodaoc códigoitem: egen  elapsed_time_ph3 =max(elapsed_time_phase3)
bysort numerodaoc códigoitem: egen  elapsed_time_ph4 =max(elapsed_time_phase4)
bysort numerodaoc códigoitem: egen  elapsed_time_ph6 =max(elapsed_time_phase6)
bysort numerodaoc códigoitem: egen  elapsed_time_ph7 =max(elapsed_time_phase7)
bysort numerodaoc códigoitem: egen  second_bid_ph1 =max(second_bid_phase1)
bysort numerodaoc códigoitem: egen  second_bid_ph2 =max(second_bid_phase2)
bysort numerodaoc códigoitem: egen  second_bid_ph3 =max(second_bid_phase3)
bysort numerodaoc códigoitem: egen  second_bid_ph4 =max(second_bid_phase4)
bysort numerodaoc códigoitem: egen  second_bid_ph6 =max(second_bid_phase6)
bysort numerodaoc códigoitem: egen  second_bid_ph7 =max(second_bid_phase7)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph1 =max(diff_first_sec_phase1)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph2 =max(diff_first_sec_phase2)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph3 =max(diff_first_sec_phase3)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph4 =max(diff_first_sec_phase4)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph6 =max(diff_first_sec_phase6)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph7 =max(diff_first_sec_phase7)
drop min_bid_phase1
drop min_bid_phase2
drop min_bid_phase3
drop min_bid_phase4
drop min_bid_phase6
drop min_bid_phase7
drop max_bid_phase1
drop max_bid_phase2
drop max_bid_phase3
drop max_bid_phase4
drop max_bid_phase6
drop max_bid_phase7
drop mean_bid_phase1
drop mean_bid_phase2
drop mean_bid_phase3
drop mean_bid_phase4
drop mean_bid_phase6
drop mean_bid_phase7
drop median_bid_phase1
drop median_bid_phase2
drop median_bid_phase3
drop median_bid_phase4
drop median_bid_phase6
drop median_bid_phase7
drop sd_bid_phase1
drop sd_bid_phase2
drop sd_bid_phase3
drop sd_bid_phase4
drop sd_bid_phase6
drop sd_bid_phase7
drop min_dist_phase1
drop min_dist_phase2
drop min_dist_phase3
drop min_dist_phase4
drop min_dist_phase6
drop min_dist_phase7
drop max_dist_phase1
drop max_dist_phase2
drop max_dist_phase3
drop max_dist_phase4
drop max_dist_phase6
drop max_dist_phase7
drop mean_dist_phase1
drop mean_dist_phase2
drop mean_dist_phase3
drop mean_dist_phase4
drop mean_dist_phase6
drop mean_dist_phase7
drop median_dist_phase1
drop median_dist_phase2
drop median_dist_phase3
drop median_dist_phase4
drop median_dist_phase6
drop median_dist_phase7
drop sd_dist_phase1
drop sd_dist_phase2
drop sd_dist_phase3
drop sd_dist_phase4
drop sd_dist_phase6
drop sd_dist_phase7
drop min_firm_age_phase1
drop min_firm_age_phase2
drop min_firm_age_phase3
drop min_firm_age_phase4
drop min_firm_age_phase6
drop min_firm_age_phase7
drop max_firm_age_phase1
drop max_firm_age_phase2
drop max_firm_age_phase3
drop max_firm_age_phase4
drop max_firm_age_phase6
drop max_firm_age_phase7
drop mean_firm_age_phase1
drop mean_firm_age_phase2
drop mean_firm_age_phase3
drop mean_firm_age_phase4
drop mean_firm_age_phase6
drop mean_firm_age_phase7
drop median_firm_age_phase1
drop median_firm_age_phase2
drop median_firm_age_phase3
drop median_firm_age_phase4
drop median_firm_age_phase6
drop median_firm_age_phase7
drop sd_firm_age_phase1
drop sd_firm_age_phase2
drop sd_firm_age_phase3
drop sd_firm_age_phase4
drop sd_firm_age_phase6
drop sd_firm_age_phase7
drop numbids_phase1
drop numbids_phase2
drop numbids_phase3
drop numbids_phase4
drop numbids_phase6
drop numbids_phase7
drop numfornecs_phase1
drop numfornecs_phase2
drop numfornecs_phase3
drop numfornecs_phase4
drop numfornecs_phase6
drop numfornecs_phase7
drop numfornecs_agro_phase1
drop numfornecs_agro_phase2
drop numfornecs_agro_phase3
drop numfornecs_agro_phase4
drop numfornecs_agro_phase6
drop numfornecs_agro_phase7
drop numfornecs_comercio_phase1
drop numfornecs_comercio_phase2
drop numfornecs_comercio_phase3
drop numfornecs_comercio_phase4
drop numfornecs_comercio_phase6
drop numfornecs_comercio_phase7
drop numfornecs_ind_phase1
drop numfornecs_ind_phase2
drop numfornecs_ind_phase3
drop numfornecs_ind_phase4
drop numfornecs_ind_phase6
drop numfornecs_ind_phase7
drop numfornecs_meioamb_phase1
drop numfornecs_meioamb_phase2
drop numfornecs_meioamb_phase3
drop numfornecs_meioamb_phase4
drop numfornecs_meioamb_phase6
drop numfornecs_meioamb_phase7
drop numfornecs_serv_phase1
drop numfornecs_serv_phase2
drop numfornecs_serv_phase3
drop numfornecs_serv_phase4
drop numfornecs_serv_phase6
drop numfornecs_serv_phase7
drop numfornecs_type_me_phase1
drop numfornecs_type_me_phase2
drop numfornecs_type_me_phase3
drop numfornecs_type_me_phase4
drop numfornecs_type_me_phase6
drop numfornecs_type_me_phase7
drop numfornecs_type_epp_phase1
drop numfornecs_type_epp_phase2
drop numfornecs_type_epp_phase3
drop numfornecs_type_epp_phase4
drop numfornecs_type_epp_phase6
drop numfornecs_type_epp_phase7
drop numfornecs_type_oth_phase1
drop numfornecs_type_oth_phase2
drop numfornecs_type_oth_phase3
drop numfornecs_type_oth_phase4
drop numfornecs_type_oth_phase6
drop numfornecs_type_oth_phase7
drop numfornecs_same_munic_phase1
drop numfornecs_same_munic_phase2
drop numfornecs_same_munic_phase3
drop numfornecs_same_munic_phase4
drop numfornecs_same_munic_phase6
drop numfornecs_same_munic_phase7
drop numfornecs_est_SP_phase1
drop numfornecs_est_SP_phase2
drop numfornecs_est_SP_phase3
drop numfornecs_est_SP_phase4
drop numfornecs_est_SP_phase6
drop numfornecs_est_SP_phase7
drop numfornecs_city_SP_phase1
drop numfornecs_city_SP_phase2
drop numfornecs_city_SP_phase3
drop numfornecs_city_SP_phase4
drop numfornecs_city_SP_phase6
drop numfornecs_city_SP_phase7
drop elapsed_time_phase1
drop elapsed_time_phase2
drop elapsed_time_phase3
drop elapsed_time_phase4
drop elapsed_time_phase6
drop elapsed_time_phase7
drop second_bid_phase1
drop second_bid_phase2
drop second_bid_phase3
drop second_bid_phase4
drop second_bid_phase6
drop second_bid_phase7
drop diff_first_sec_phase1
drop diff_first_sec_phase2
drop diff_first_sec_phase3
drop diff_first_sec_phase4
drop diff_first_sec_phase6
drop diff_first_sec_phase7



duplicates drop



save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_Items_Dispensa.dta", replace





















********************* File 3: Convite

clear all
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020"
use Final_Semester_proc_1.dta, clear

drop  data mês ano
drop if fase_oc==5

gen flag_check=0
replace flag_check=1 if flagvencedor==quantidadeitemvencedor
replace quantidadeitemvencedor="1" if flag_check==0
drop flag_check

gen data=mêsanoencerramento
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
drop if _merge_chave1==1

gen qty_oferta2=quantidadenegociada
destring qty_oferta2, replace dpcomma
drop quantidadenegociada
replace qty_oferta2=0 if qty_oferta2==.

destring valortotalproposta valorunitárioproposta valortotalnegociado  preco_ref preco_final mêsanoencerramento, replace dpcomma

replace valortotalnegociado=0 if valortotalnegociado==.

preserve

collapse (max) qty_max=qty_oferta qty_max2=qty_oferta2 valor_total_neg_max=valortotalnegociado, by(chave1)
sort chave1
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_convite.dta", replace

restore

sort chave1
merge m:1 chave1 using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Collapse_qty_convite.dta", generate(_merge_pregao_qty)
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

ren códigofornecedor firm_cnpj

sort firm_cnpj
merge m:1 firm_cnpj using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/CNPJ Geoc/CNPJ Resumido com geoc.dta", generate (_merge_geoc)
drop if _merge_geoc==2
drop if firm_cnpj=="-1"
drop if _merge_geoc==1

gen bid_status=0
replace bid_status=1 if descriçãopropostastatus=="VÁLIDO" | descriçãopropostastatus=="VÁLIDO E CONFIRMADO"


drop _merge_geoc _merge


gen byte notnumeric = real( fornec_latitude )==.
replace fornec_latitude="0" if notnumeric==1
replace fornec_longitude ="0" if notnumeric==1
destring fornec_latitude fornec_longitude, replace

drop  notnumeric
drop if numerodaoc==""



merge m:1 descriçãomunicípiofornecedor using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/CNPJ Geoc/Municipios restantes convite.dta", generate(_merge_municip)

replace fornec_latitude= fornec_latitude2 if fornec_latitude==0 | fornec_latitude==.
replace fornec_longitude = fornec_longitude2 if fornec_longitude ==0 | fornec_longitude==.
drop fornec_latitude2 fornec_longitude2 _merge_municip

geodist pbu_latit pbu_longit fornec_latitude fornec_longitude , generate(dist)
gen dist1=dist
replace dist1=0.05 if dist==0

drop if dist==.




save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_1_final.dta", replace




*** Auctions Info

* By OC + Item + OC_Phase

*** Ranking bids
keep if bid_status==1
bysort numerodaoc códigoitem fase_oc (valorunitárioproposta) : gen rank = _n
by numerodaoc códigoitem fase_oc: egen bids_sum = max(rank)

*** Identifying distinct participant firms
gen códigofornecedor= firm_cnpj
by numerodaoc códigoitem fase_oc códigofornecedor, sort: gen particip_firm = _n == 1


*** Counting participant firms
by numerodaoc códigoitem fase_oc: egen particip_firm_sum = total(particip_firm)


*** Counting distinct firms by porte de empresa
bysort numerodaoc códigoitem fase_oc: egen n_firms_me_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="01"
bysort numerodaoc códigoitem fase_oc: egen n_firms_epp_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="03"
bysort numerodaoc códigoitem fase_oc: egen n_firms_outros_aux = total(particip_firm) if particip_firm==1 & porte_empresa=="05"

replace n_firms_me_aux=0 if n_firms_me_aux==.
replace n_firms_epp_aux=0 if n_firms_epp_aux==.
replace n_firms_outros_aux=0 if n_firms_outros_aux==.

bysort numerodaoc códigoitem fase_oc: egen n_firms_me = max(n_firms_me_aux)
bysort numerodaoc códigoitem fase_oc: egen n_firms_epp = max(n_firms_epp_aux)
bysort numerodaoc códigoitem fase_oc: egen n_firms_outros = max(n_firms_outros_aux)


*** Adjusting Cities and States para fornecedores
merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Cep/qualcep/tabela_integrada_final.dta", generate(_merge_cep_fornec)
drop if _merge_cep_fornec==2
replace descriçãouffornecedor=estado_final if descriçãouffornecedor=="SEM GANHADOR"
replace descriçãomunicípiofornecedor = cidade_final if descriçãomunicípiofornecedor =="SEM GANHADOR"
replace descriçãouffornecedor="SÃO PAULO" if descriçãouffornecedor=="SAO PAULO"
drop  cidade cod_cidade uf estado cod_estado cidade_final estado_final _merge_cep_fornec

replace  códigocepfornecedor=firm_zipcode if  códigocepfornecedor==""

*** Same municipality: PBU and Fornecedor

gen same_municip=0
replace same_municip=1 if pbu_city_descr==descriçãomunicípiofornecedor

bysort numerodaoc códigoitem fase_oc: egen n_same_municip_aux = total(particip_firm) if particip_firm==1 & same_municip==1
replace n_same_municip_aux=0 if n_same_municip_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_same_municip = max(n_same_municip_aux)

*** Fornecedor at Estado de SP?

gen fornec_estado_SP=0
replace fornec_estado_SP=1 if  descriçãouffornecedor=="SÃO PAULO"

bysort numerodaoc códigoitem fase_oc: egen n_fornec_estado_SP_aux = total(particip_firm) if particip_firm==1 & fornec_estado_SP==1
replace n_fornec_estado_SP_aux=0 if n_fornec_estado_SP_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_estado_SP = max(n_fornec_estado_SP_aux)

*** Fornecedor at Sao Paulo City

gen fornec_city_SP=0
replace fornec_city_SP=1 if  descriçãomunicípiofornecedor=="SAO PAULO"

bysort numerodaoc códigoitem fase_oc: egen n_fornec_city_SP_aux = total(particip_firm) if particip_firm==1 & fornec_city_SP==1
replace n_fornec_city_SP_aux=0 if n_fornec_city_SP_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_city_SP = max(n_fornec_city_SP_aux)



*** Info about bids
by numerodaoc códigoitem fase_oc: egen min_bid = min(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen max_bid = max(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen mean_bid = mean(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen median_bid = median(valorunitárioproposta)
by numerodaoc códigoitem fase_oc: egen sd_bid = sd(valorunitárioproposta)

by numerodaoc códigoitem fase_oc: egen p10_bid_phase = pctile(valorunitárioproposta), p(10)
by numerodaoc códigoitem fase_oc: egen p20_bid_phase = pctile(valorunitárioproposta), p(20)
by numerodaoc códigoitem fase_oc: egen p30_bid_phase = pctile(valorunitárioproposta), p(30)
by numerodaoc códigoitem fase_oc: egen p40_bid_phase = pctile(valorunitárioproposta), p(40)
by numerodaoc códigoitem fase_oc: egen p60_bid_phase = pctile(valorunitárioproposta), p(60)
by numerodaoc códigoitem fase_oc: egen p70_bid_phase = pctile(valorunitárioproposta), p(70)
by numerodaoc códigoitem fase_oc: egen p80_bid_phase = pctile(valorunitárioproposta), p(80)
by numerodaoc códigoitem fase_oc: egen p90_bid_phase = pctile(valorunitárioproposta), p(90)


*** Info about distance
by numerodaoc códigoitem fase_oc: egen min_dist = min(dist1)
by numerodaoc códigoitem fase_oc: egen max_dist = max(dist1)

bysort numerodaoc códigoitem fase_oc: egen mean_dist_certo = mean(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen mean_dist_certo1=max(mean_dist_certo)
ren mean_dist_certo1 mean_dist
drop mean_dist_certo

bysort numerodaoc códigoitem fase_oc: egen median_dist_certo = median(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen median_dist_certo1=max(median_dist_certo)
ren median_dist_certo1 median_dist
drop median_dist_certo

bysort numerodaoc códigoitem fase_oc: egen sd_dist_certo = sd(dist1) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen sd_dist_certo1=max(sd_dist_certo)
ren sd_dist_certo1 sd_dist
drop sd_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p10_dist_certo = pctile(dist1) if particip_firm==1, p(10)
bysort numerodaoc códigoitem fase_oc: egen p10_dist_phase=max(p10_dist_certo)
drop p10_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p20_dist_certo = pctile(dist1) if particip_firm==1, p(20)
bysort numerodaoc códigoitem fase_oc: egen p20_dist_phase=max(p20_dist_certo)
drop p20_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p30_dist_certo = pctile(dist1) if particip_firm==1, p(30)
bysort numerodaoc códigoitem fase_oc: egen p30_dist_phase=max(p30_dist_certo)
drop p30_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p40_dist_certo = pctile(dist1) if particip_firm==1, p(40)
bysort numerodaoc códigoitem fase_oc: egen p40_dist_phase=max(p40_dist_certo)
drop p40_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p60_dist_certo = pctile(dist1) if particip_firm==1, p(60)
bysort numerodaoc códigoitem fase_oc: egen p60_dist_phase=max(p60_dist_certo)
drop p60_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p70_dist_certo = pctile(dist1) if particip_firm==1, p(70)
bysort numerodaoc códigoitem fase_oc: egen p70_dist_phase=max(p70_dist_certo)
drop p70_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p80_dist_certo = pctile(dist1) if particip_firm==1, p(80)
bysort numerodaoc códigoitem fase_oc: egen p80_dist_phase=max(p80_dist_certo)
drop p80_dist_certo

bysort numerodaoc códigoitem fase_oc: egen p90_dist_certo = pctile(dist1) if particip_firm==1, p(90)
bysort numerodaoc códigoitem fase_oc: egen p90_dist_phase=max(p90_dist_certo)
drop p90_dist_certo


*Parei aqui

*** Calculating firm age at the moment of the tender

gen ddate = daily( data_inicio_atividade , "YMD")
gen mdate = mofd(ddate)
format mdate %tm
gen firm_age=data-mdate
gen firm_age_years=firm_age/12
rename ddate data_inicio_ativid_aux
label variable data_inicio_ativid_aux "Data início atividade fornecedor convertido auxiliar"
drop data_inicio_atividade
ren mdate data_inicio_ativid
label variable data_inicio_ativid "Data início atividade do fornecedor"
label variable firm_age "Idade fornecedor no momento da licitação em meses"
label variable firm_age_years "Idade fornecedor no momento da licitação em anos"


*** Info about firm age (months)

by numerodaoc códigoitem fase_oc: egen min_firm_age_phase = min(firm_age)
by numerodaoc códigoitem fase_oc: egen max_firm_age_phase = max(firm_age)

bysort numerodaoc códigoitem fase_oc: egen mean_firm_age_phase_certo = mean(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen mean_firm_age_phase_certo1=max(mean_firm_age_phase_certo)
ren mean_firm_age_phase_certo1 mean_firm_age_phase
drop mean_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen median_firm_age_phase_certo = median(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen median_firm_age_phase_certo1=max(median_firm_age_phase_certo)
ren median_firm_age_phase_certo1 median_firm_age_phase
drop median_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen sd_firm_age_phase_certo = sd(firm_age) if particip_firm==1
bysort numerodaoc códigoitem fase_oc: egen sd_firm_age_phase_certo1=max(sd_firm_age_phase_certo)
ren sd_firm_age_phase_certo1 sd_firm_age_phase
drop sd_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p10_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(10)
bysort numerodaoc códigoitem fase_oc: egen p10_firm_age_phase_phase=max(p10_firm_age_phase_certo)
drop p10_firm_age_phase_certo


bysort numerodaoc códigoitem fase_oc: egen p20_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(20)
bysort numerodaoc códigoitem fase_oc: egen p20_firm_age_phase_phase=max(p20_firm_age_phase_certo)
drop p20_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p30_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(30)
bysort numerodaoc códigoitem fase_oc: egen p30_firm_age_phase_phase=max(p30_firm_age_phase_certo)
drop p30_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p40_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(40)
bysort numerodaoc códigoitem fase_oc: egen p40_firm_age_phase_phase=max(p40_firm_age_phase_certo)
drop p40_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p60_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(60)
bysort numerodaoc códigoitem fase_oc: egen p60_firm_age_phase_phase=max(p60_firm_age_phase_certo)
drop p60_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p70_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(70)
bysort numerodaoc códigoitem fase_oc: egen p70_firm_age_phase_phase=max(p70_firm_age_phase_certo)
drop p70_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p80_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(80)
bysort numerodaoc códigoitem fase_oc: egen p80_firm_age_phase_phase=max(p80_firm_age_phase_certo)
drop p80_firm_age_phase_certo

bysort numerodaoc códigoitem fase_oc: egen p90_firm_age_phase_certo = pctile(firm_age) if particip_firm==1, p(90)
bysort numerodaoc códigoitem fase_oc: egen p90_firm_age_phase_phase=max(p90_firm_age_phase_certo)
drop p90_firm_age_phase_certo


ren p10_firm_age_phase_phase p10_firm_age_phase
ren p20_firm_age_phase_phase p20_firm_age_phase
ren p30_firm_age_phase_phase p30_firm_age_phase
ren p40_firm_age_phase_phase p40_firm_age_phase
ren p60_firm_age_phase_phase p60_firm_age_phase
ren p70_firm_age_phase_phase p70_firm_age_phase
ren p80_firm_age_phase_phase p80_firm_age_phase
ren p90_firm_age_phase_phase p90_firm_age_phase


*** Info about firm age (years)
gen min_firm_age_y_phase=min_firm_age_phase/12 
gen max_firm_age_y_phase=max_firm_age_phase/12  
gen mean_firm_age_y_phase=mean_firm_age_phase/12  
gen median_firm_age_y_phase=median_firm_age_phase/12  
gen sd_firm_age_y_phase=sd_firm_age_phase/12  
gen p10_firm_age_y_phase=p10_firm_age_phase/12  
gen p20_firm_age_y_phase=p20_firm_age_phase/12  
gen p30_firm_age_y_phase=p30_firm_age_phase/12  
gen p40_firm_age_y_phase=p40_firm_age_phase/12  
gen p60_firm_age_y_phase=p60_firm_age_phase/12  
gen p70_firm_age_y_phase=p70_firm_age_phase/12  
gen p80_firm_age_y_phase=p80_firm_age_phase/12  
gen p90_firm_age_y_phase=p90_firm_age_phase/12 




*** Second Highest Value
by numerodaoc códigoitem fase_oc: egen second_bid = total(valorunitárioproposta / (rank == 2))


*** Difference between min bid and second lowest value
gen diff_first_second=(second_bid-min_bid)/min_bid


*** Elapsed Time
gen bid_time= datahrproposta
gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
by numerodaoc códigoitem fase_oc: egen min_bid_time_phase = min(bid_time_date)
by numerodaoc códigoitem fase_oc: egen max_bid_time_phase = max(bid_time_date)
gen oc_item_elapsed_time=max_bid_time_phase-min_bid_time_phase
gen oc_item_elapsed_time_hours=oc_item_elapsed_time/3600000
gen oc_item_elapsed_time_minutes=oc_item_elapsed_time_hours*60

format min_bid_time_phase %tc
format max_bid_time_phase %tc
format oc_item_elapsed_time %9.2f
format oc_item_elapsed_time_hours %9.2f
format oc_item_elapsed_time_minutes %9.2f

drop  datahrproposta



*** CNAE

gen cnae_fiscal_length=length(cnae_fiscal)
tab cnae_fiscal_length
replace cnae_fiscal = "0" + cnae_fiscal if cnae_fiscal_length==6
sort cnae_fiscal
drop  cnae_fiscal_length
drop if numerodaoc==""

merge m:1 cnae_fiscal using "/home/darciogm1/projetos/bitter-pills/data/raw/cnae/cnae_21.dta", generate(_merge_cnae)

drop if _merge_cnae==2
drop _merge_cnae

egen cnae_resum_code=group(cnae_resumido)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_agro_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==1
replace n_fornec_agro_aux=0 if n_fornec_agro_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_agro = max(n_fornec_agro_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_comercio_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==2
replace n_fornec_comercio_aux=0 if n_fornec_comercio_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_comercio = max(n_fornec_comercio_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_ind_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==3
replace n_fornec_ind_aux=0 if n_fornec_ind_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_ind = max(n_fornec_ind_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_meioamb_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==4
replace n_fornec_meioamb_aux=0 if n_fornec_meioamb_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_meioamb = max(n_fornec_meioamb_aux)

bysort numerodaoc códigoitem fase_oc: egen n_fornec_serv_aux = total(particip_firm) if particip_firm==1 & cnae_resum_code==5
replace n_fornec_serv_aux=0 if n_fornec_serv_aux==.
bysort numerodaoc códigoitem fase_oc: egen n_fornec_serv = max(n_fornec_serv_aux)


*** By OC + Item

*** Separating Successful / Failure of OC + Item
by numerodaoc códigoitem : egen winner_bid = min(valorunitárioproposta) if flagvencedor=="1"
by numerodaoc códigoitem : egen winner_bid2 = max(winner_bid)
gen oc_item_success=1
replace oc_item_success=0 if winner_bid2==.
drop winner_bid
ren winner_bid2 winner_bid

*** By OC

*** Identifying distinct items, classes and groups by OC
by numerodaoc códigoitem, sort: gen item_oc_distinct = _n == 1
by numerodaoc códigoclasse, sort: gen classe_oc_distinct = _n == 1
by numerodaoc códigogrupo, sort: gen grupo_oc_distinct = _n == 1


*** Counting distinct items, classes and groups by OC
by numerodaoc : egen item_oc_count = total(item_oc_distinct)
by numerodaoc : egen classe_oc_count = total(classe_oc_distinct)
by numerodaoc : egen grupo_oc_count = total(grupo_oc_distinct)




*** Identifying ocurrence of OC Phases

gen fase_oc1_check=0
gen fase_oc2_check=0
gen fase_oc3_check=0
gen fase_oc4_check=0
gen fase_oc6_check=0
gen fase_oc7_check=0

replace fase_oc1_check=1 if fase_oc==1
replace fase_oc2_check=1 if fase_oc==2
replace fase_oc3_check=1 if fase_oc==3
replace fase_oc4_check=1 if fase_oc==4
replace fase_oc6_check=1 if fase_oc==6
replace fase_oc7_check=1 if fase_oc==7

bysort numerodaoc códigoitem: egen fase_oc1=max(fase_oc1_check)
bysort numerodaoc códigoitem: egen fase_oc2=max(fase_oc2_check)
bysort numerodaoc códigoitem: egen fase_oc3=max(fase_oc3_check)
bysort numerodaoc códigoitem: egen fase_oc4=max(fase_oc4_check)
bysort numerodaoc códigoitem: egen fase_oc6=max(fase_oc6_check)
bysort numerodaoc códigoitem: egen fase_oc7=max(fase_oc7_check)


*** Investigating ocurrence of phases

gen phases_234=0
replace phases_234=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1

gen phases_23=0
replace phases_23=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==0

gen phases_24=0
replace phases_24=1 if fase_oc2==1 & fase_oc4==1 & fase_oc3==0

gen phases_12=0
replace phases_12=1 if fase_oc1==1 & fase_oc2==1

gen phases_26=0
replace phases_26=1 if fase_oc2==1 & fase_oc6==1

gen phases_2346=0
replace phases_2346=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1

gen phases_123467=0
replace phases_123467=1 if fase_oc1==1 & fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1 & fase_oc7==1

gen phases_23467=0
replace phases_23467=1 if fase_oc2==1 & fase_oc3==1 & fase_oc4==1 & fase_oc6==1 & fase_oc7==1




*** Coding OC status

egen oc_status_code=group(oc_status)
label variable oc_status_code "1=ANUL;2=CANCEL;3=C/ VENC;4=S/ VENC;5=FRACASS;6=REVOG"
drop oc_status



*** Judicialized OCs

merge m:1 numerodaoc using "C:/Users/pesquisa/Documents/Papers/Word/OneDrive/Paper 1 - Judicialization/Datasets/2-JUD_REGEX_EDITAIS.dta", generate(_merge_JUD)

replace jud_regex=0 if _merge_JUD==1

gen jud_adm2=jud_adm
replace jud_adm2=0 if strpos(po_subject, "MATERIAL ADMINISTRATIVO") | strpos(po_subject, "MATERIAIS ADMINISTRATIVOS")

replace jud_adm2=0 if jud_adm2==.
gen sum_jud=jud_regex+jud_adm2

gen jud=0
replace jud=1 if sum_jud>0



*** Important variables of dates

rename data data_oc
label variable data_oc "Mês e ano da OC"
rename mês mês_oc
label variable mês_oc "Mês da OC"
rename ano ano_oc
label variable ano_oc "Ano da OC"


*** Droping key
drop chave1


*** Labeling variables

label variable qtde "Quantidade do Item"
replace me_epp=me_epp-1
label variable me_epp "0=N;1=S"
label variable pbu_year "Ano da UC"
label variable pbu_code_year "Código UC + Ano UC"
label variable pbu_ibge_cod_uf "Código UF IBGE da UC"
label variable ibge_cod_cidade_pbu "Código município IBGE da UC"
label variable pbu_city_area "Área km2 município da UC"
label variable pbu_latit "Latitude da UC"
label variable pbu_longit "Longitude da UC"
label variable firm_cnpj "CNPJ Fornecedor"
label variable data_inicio_ativid "Data inicio atividade do fornecedor"
label variable cnae_fiscal "CNAE fornecedor"
label variable porte_empresa "01=ME;03=EPP;05=OUTROS"
label variable firm_zipcode "CEP fornecedor"
label variable fornec_latitude "Latitude fornecedor"
label variable fornec_longitude "Longitude fornecedor"
label variable bid_status "1=Válido ou Classificado"
rename rank rank_fornec_oc
label variable rank_fornec_oc "Rank do fornecedor na OC+Item"
label variable particip_firm "Identificador de firma distinta"
label variable particip_firm_sum "Contagem de firmas distintas por OC+Item"
label variable particip_firm "Identificador de firma distinta"
rename min_bid min_bid_phase
label variable min_bid_phase "Valor mínimo por fase"
label variable max_bid "Valor máximo por fase"
rename max_bid max_bid_phase
rename mean_bid mean_bid_phase
label variable mean_bid_phase "Valor médio por fase"
rename median_bid median_bid_phase
label variable median_bid_phase "Mediana por fase"
rename sd_bid sd_bid_phase
label variable sd_bid_phase "Desvio-padrão por fase"
rename min_dist min_dist_phase
label variable min_dist_phase "Mínima distância por fase"
rename max_dist max_dist_phase
label variable max_dist_phase "Máxima distância por fase"
rename bids_sum bids_sum_phase
label variable bids_sum_phase "Número de bids por fase"
rename second_bid second_bid_phase
label variable second_bid_phase "Bid segundo colocado por fase"
label variable diff_first_second "Diferença em porcentagem entre 1o e 2o bid"
label variable winner_bid "Bid vencedor"
rename winner_bid winner_bid_oc
label variable oc_item_success "0=FRACASSO;1=SUCESSO"
rename mean_dist mean_dist_phase
label variable mean_dist_phase "Média distância por fase"
rename median_dist median_dist_phase
label variable median_dist_phase "Mediana distância por fase"
rename sd_dist sd_dist_phase
label variable sd_dist_phase "Desvio-padrão distância por fase"
label variable fase_oc1_check "0=N houve esta fase; 1=Houve"
label variable fase_oc2_check "0=N houve esta fase; 1=Houve"
label variable fase_oc3_check "0=N houve esta fase; 1=Houve"
label variable fase_oc4_check "0=N houve esta fase; 1=Houve"
label variable fase_oc6_check "0=N houve esta fase; 1=Houve"
label variable fase_oc7_check "0=N houve esta fase; 1=Houve"
label variable fase_oc1 "Por OC: 0=N houve;1=Houve"
label variable fase_oc2 "Por OC: 0=N houve;1=Houve"
label variable fase_oc3 "Por OC: 0=N houve;1=Houve"
label variable fase_oc4 "Por OC: 0=N houve;1=Houve"
label variable fase_oc6 "Por OC: 0=N houve;1=Houve"
label variable fase_oc7 "Por OC: 0=N houve;1=Houve"
label variable phases_234 "0=N houve fases;1=Houve fases"
label variable phases_23 "0=N houve fases;1=Houve fases"
label variable phases_24 "0=N houve fases;1=Houve fases"
label variable phases_12 "0=N houve fases;1=Houve fases"
label variable phases_26 "0=N houve fases;1=Houve fases"
label variable phases_2346 "0=N houve fases;1=Houve fases"
label variable phases_123467 "OC com fases 1,2,3,4,6 e 7"
label variable phases_23467 "OC com fases 2,3,4,6 e 7"
label variable p10_bid_phase "Percentile 10th bid price per phase"
label variable p20_bid_phase "Percentile 20th bid price per phase"
label variable p30_bid_phase "Percentile 30th bid price per phase"
label variable p40_bid_phase "Percentile 40th bid price per phase"
label variable p60_bid_phase "Percentile 60th bid price per phase"
label variable p70_bid_phase "Percentile 70th bid price per phase"
label variable p80_bid_phase "Percentile 80th bid price per phase"
label variable p90_bid_phase "Percentile 90th bid price per phase"
label variable p10_dist_phase "Percentile 10th distance per phase"
label variable p20_dist_phase "Percentile 20th distance per phase"
label variable p30_dist_phase "Percentile 30th distance per phase"
label variable p40_dist_phase "Percentile 40th distance per phase"
label variable p60_dist_phase "Percentile 60th distance per phase"
label variable p70_dist_phase "Percentile 10th distance per phase"
label variable p70_dist_phase "Percentile 70th distance per phase"
label variable p80_dist_phase "Percentile 80th distance per phase"
label variable p90_dist_phase "Percentile 90th distance per phase"
label variable min_firm_age_phase "Min firm age per phase"
label variable max_firm_age_phase "Max firm age per phase"
label variable mean_firm_age_phase "Mean firm age per phase"
label variable median_firm_age_phase "Median firm age per phase"
label variable sd_firm_age_phase "SD firm age per phase"
label variable p10_firm_age_phase "Percentile 10th firm age per phase"
label variable p20_firm_age_phase "Percentile 20th firm age per phase"
label variable p30_firm_age_phase "Percentile 30th firm age per phase"
label variable p40_firm_age_phase "Percentile 40th firm age per phase"
label variable p60_firm_age_phase "Percentile 60th firm age per phase"
label variable p70_firm_age_phase "Percentile 70th firm age per phase"
label variable p80_firm_age_phase "Percentile 80th firm age per phase"
label variable p90_firm_age_phase "Percentile 90th firm age per phase"
label variable min_firm_age_y_phase "Min firm age per phase in years"
label variable max_firm_age_y_phase "Max firm age per phase in years"
label variable mean_firm_age_y_phase "Mean firm age per phase in years"
label variable median_firm_age_y_phase "Median firm age per phase in years"
label variable sd_firm_age_y_phase "SD firm age per phase in years"
label variable p10_firm_age_y_phase "Percentile 10th firm age per phase in years"
label variable p20_firm_age_y_phase "Percentile 20th firm age per phase in years"
label variable p30_firm_age_y_phase "Percentile 30th firm age per phase in years"
label variable p40_firm_age_y_phase "Percentile 40th firm age per phase in years"
label variable p60_firm_age_y_phase "Percentile 60th firm age per phase in years"
label variable p70_firm_age_y_phase "Percentile 70th firm age per phase in years"
label variable p80_firm_age_y_phase "Percentile 80th firm age per phase in years"
label variable p90_firm_age_y_phase "Percentile 90th firm age per phase in years"
label variable bid_time "Data e hora do bid price"
label variable bid_time "Data e hora do bid price string"
label variable bid_time_date "Data e hora do bid price double"
label variable min_bid_time_phase "Min bid time per phase"
label variable max_bid_time_phase "Max bid time per phase"
label variable oc_item_elapsed_time "Elapsed time per phase in miliseconds"
label variable oc_item_elapsed_time_hours "Elapsed time per phase in hours"
label variable oc_item_elapsed_time_minutes "Elapsed time per phase in minutes"
label variable item_oc_distinct "Number of distinct items per OC"
label variable classe_oc_distinct "Number of distinct items classes per OC"
label variable grupo_oc_distinct "Number of distinct items groups per OC"
label variable item_oc_distinct ""
label variable item_oc_count "Number of distinct items per OC"
label variable classe_oc_distinct ""
label variable classe_oc_count "Number of distinct items classes per OC"
label variable grupo_oc_distinct ""
label variable grupo_oc_count "Number of distinct items groups per OC"
label variable item_oc_distinct "Identifying distinct items per OC"
label variable classe_oc_distinct "Identifying distinct items classes per OC"
label variable grupo_oc_distinct "Identifying distinct items groups per OC"
label variable n_firms_me_aux "Number of distinct ME firms"
label variable n_firms_epp_aux "Number of distinct EPP firms"
label variable n_firms_me_aux ""
label variable n_firms_me "Number of distinct ME firms"
label variable n_firms_epp_aux ""
label variable n_firms_epp "Number of distinct EPP firms per phase"
label variable n_firms_me "Number of distinct ME firms per phase"
label variable n_firms_outros "Number of distinct OTHER firms per phase"
label variable n_firms_me_aux "Identifying distinct ME firms per phase"
label variable n_firms_epp_aux "Identifying distinct EPP firms per phase"
label variable n_firms_outros_aux "Identifying distinct OTHER firms per phase"
label variable same_municip "1=UC e Fornec mesmo municipio"
label variable fornec_estado_SP "1=Fornec do Estado de SP"
label variable fornec_city_SP "1=Fornec da cidade de SP"


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_1_final_validbids.dta", replace


************ Preparing Collapse_ ITEMS

drop pbu_year pbu_code_year _merge_JUD valorunitárioproposta flagvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 data_inicio_ativid_aux data_inicio_ativid firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code n_firms_me_aux n_firms_epp_aux n_firms_outros_aux n_same_municip_aux n_fornec_estado_SP_aux n_fornec_city_SP_aux n_fornec_agro_aux n_fornec_comercio_aux n_fornec_ind_aux n_fornec_meioamb_aux n_fornec_serv_aux bid_time bid_time_date min_bid_time_phase max_bid_time_phase item_oc_distinct classe_oc_distinct grupo_oc_distinct valor_total_neg_max rank_fornec_oc particip_firm props_grupo_status descriçãopropostastatus bid_status fase_oc1_check fase_oc2_check fase_oc3_check fase_oc4_check fase_oc6_check fase_oc7_check pubag_descr phases_234 phases_23 phases_24 phases_12 phases_26 phases_2346 phases_123467 phases_23467 p10_bid_phase p20_bid_phase p30_bid_phase p40_bid_phase p60_bid_phase p70_bid_phase p80_bid_phase p90_bid_phase p10_dist_phase p20_dist_phase p30_dist_phase p40_dist_phase p60_dist_phase p70_dist_phase p80_dist_phase p90_dist_phase p10_firm_age_phase p20_firm_age_phase p30_firm_age_phase p40_firm_age_phase p60_firm_age_phase p70_firm_age_phase p80_firm_age_phase p90_firm_age_phase p10_firm_age_y_phase p20_firm_age_y_phase p30_firm_age_y_phase p40_firm_age_y_phase p60_firm_age_y_phase p70_firm_age_y_phase p80_firm_age_y_phase p90_firm_age_y_phase min_firm_age_y_phase max_firm_age_y_phase mean_firm_age_y_phase median_firm_age_y_phase sd_firm_age_y_phase oc_item_elapsed_time oc_item_elapsed_time_hours


order data_oc mês_oc ano_oc numerodaoc oc_status_code códigoitem descitem códigoclasse descclasseitem códigogrupo descgrupoitem proc_compra reg_precos categ_item item_verde preco_ref qtde me_epp oc_item_success sum_jud jud_regex códigounidadecompradora descriçãounidadecompradora pbu_code pbu_cnpj códigouo descriçãouo códigoórgão descriçãoórgão pbu_power pbu_type_mgmt_code pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_ibge_cod_uf ibge_cod_cidade_pbu pbu_city_area pbu_latit pbu_longit descriçãomunicípiodeentrega descriçãoregiãodeentrega fase_oc item_oc_count classe_oc_count grupo_oc_count fase_oc1 fase_oc2 fase_oc3 fase_oc4 fase_oc6 fase_oc7  preco_final min_bid_phase max_bid_phase mean_bid_phase median_bid_phase sd_bid_phase  min_dist_phase max_dist_phase mean_dist_phase median_dist_phase sd_dist_phase  min_firm_age_phase max_firm_age_phase mean_firm_age_phase median_firm_age_phase sd_firm_age_phase    bids_sum_phase particip_firm_sum n_fornec_agro n_fornec_comercio n_fornec_ind n_fornec_meioamb n_fornec_serv n_firms_me n_firms_epp n_firms_outros n_same_municip n_fornec_estado_SP n_fornec_city_SP  oc_item_elapsed_time_minutes second_bid_phase diff_first_second winner_bid_oc 


***** Bid Value for each phase

** Min

gen min_bid_phase1=0
gen min_bid_phase2=0
gen min_bid_phase3=0
gen min_bid_phase4=0
gen min_bid_phase6=0
gen min_bid_phase7=0

replace min_bid_phase1=min_bid_phase if fase_oc==1
replace min_bid_phase2=min_bid_phase if fase_oc==2
replace min_bid_phase3=min_bid_phase if fase_oc==3
replace min_bid_phase4=min_bid_phase if fase_oc==4
replace min_bid_phase6=min_bid_phase if fase_oc==6
replace min_bid_phase7=min_bid_phase if fase_oc==7

drop min_bid_phase



** Max

gen max_bid_phase1=0
gen max_bid_phase2=0
gen max_bid_phase3=0
gen max_bid_phase4=0
gen max_bid_phase6=0
gen max_bid_phase7=0

replace max_bid_phase1=max_bid_phase if fase_oc==1
replace max_bid_phase2=max_bid_phase if fase_oc==2
replace max_bid_phase3=max_bid_phase if fase_oc==3
replace max_bid_phase4=max_bid_phase if fase_oc==4
replace max_bid_phase6=max_bid_phase if fase_oc==6
replace max_bid_phase7=max_bid_phase if fase_oc==7

drop max_bid_phase


** Mean

gen mean_bid_phase1=0
gen mean_bid_phase2=0
gen mean_bid_phase3=0
gen mean_bid_phase4=0
gen mean_bid_phase6=0
gen mean_bid_phase7=0

replace mean_bid_phase1=mean_bid_phase if fase_oc==1
replace mean_bid_phase2=mean_bid_phase if fase_oc==2
replace mean_bid_phase3=mean_bid_phase if fase_oc==3
replace mean_bid_phase4=mean_bid_phase if fase_oc==4
replace mean_bid_phase6=mean_bid_phase if fase_oc==6
replace mean_bid_phase7=mean_bid_phase if fase_oc==7

drop mean_bid_phase


** Median

gen median_bid_phase1=0
gen median_bid_phase2=0
gen median_bid_phase3=0
gen median_bid_phase4=0
gen median_bid_phase6=0
gen median_bid_phase7=0

replace median_bid_phase1=median_bid_phase if fase_oc==1
replace median_bid_phase2=median_bid_phase if fase_oc==2
replace median_bid_phase3=median_bid_phase if fase_oc==3
replace median_bid_phase4=median_bid_phase if fase_oc==4
replace median_bid_phase6=median_bid_phase if fase_oc==6
replace median_bid_phase7=median_bid_phase if fase_oc==7

drop median_bid_phase


** Standard Deviation

gen sd_bid_phase1=0
gen sd_bid_phase2=0
gen sd_bid_phase3=0
gen sd_bid_phase4=0
gen sd_bid_phase6=0
gen sd_bid_phase7=0

replace sd_bid_phase1=sd_bid_phase if fase_oc==1
replace sd_bid_phase2=sd_bid_phase if fase_oc==2
replace sd_bid_phase3=sd_bid_phase if fase_oc==3
replace sd_bid_phase4=sd_bid_phase if fase_oc==4
replace sd_bid_phase6=sd_bid_phase if fase_oc==6
replace sd_bid_phase7=sd_bid_phase if fase_oc==7

drop sd_bid_phase





***** Distance

** Min

gen min_dist_phase1=0
gen min_dist_phase2=0
gen min_dist_phase3=0
gen min_dist_phase4=0
gen min_dist_phase6=0
gen min_dist_phase7=0

replace min_dist_phase1=min_dist_phase if fase_oc==1
replace min_dist_phase2=min_dist_phase if fase_oc==2
replace min_dist_phase3=min_dist_phase if fase_oc==3
replace min_dist_phase4=min_dist_phase if fase_oc==4
replace min_dist_phase6=min_dist_phase if fase_oc==6
replace min_dist_phase7=min_dist_phase if fase_oc==7

drop min_dist_phase



** Max

gen max_dist_phase1=0
gen max_dist_phase2=0
gen max_dist_phase3=0
gen max_dist_phase4=0
gen max_dist_phase6=0
gen max_dist_phase7=0

replace max_dist_phase1=max_dist_phase if fase_oc==1
replace max_dist_phase2=max_dist_phase if fase_oc==2
replace max_dist_phase3=max_dist_phase if fase_oc==3
replace max_dist_phase4=max_dist_phase if fase_oc==4
replace max_dist_phase6=max_dist_phase if fase_oc==6
replace max_dist_phase7=max_dist_phase if fase_oc==7

drop max_dist_phase


** Mean

gen mean_dist_phase1=0
gen mean_dist_phase2=0
gen mean_dist_phase3=0
gen mean_dist_phase4=0
gen mean_dist_phase6=0
gen mean_dist_phase7=0

replace mean_dist_phase1=mean_dist_phase if fase_oc==1
replace mean_dist_phase2=mean_dist_phase if fase_oc==2
replace mean_dist_phase3=mean_dist_phase if fase_oc==3
replace mean_dist_phase4=mean_dist_phase if fase_oc==4
replace mean_dist_phase6=mean_dist_phase if fase_oc==6
replace mean_dist_phase7=mean_dist_phase if fase_oc==7

drop mean_dist_phase


** Median

gen median_dist_phase1=0
gen median_dist_phase2=0
gen median_dist_phase3=0
gen median_dist_phase4=0
gen median_dist_phase6=0
gen median_dist_phase7=0

replace median_dist_phase1=median_dist_phase if fase_oc==1
replace median_dist_phase2=median_dist_phase if fase_oc==2
replace median_dist_phase3=median_dist_phase if fase_oc==3
replace median_dist_phase4=median_dist_phase if fase_oc==4
replace median_dist_phase6=median_dist_phase if fase_oc==6
replace median_dist_phase7=median_dist_phase if fase_oc==7

drop median_dist_phase


** Standard Deviation

gen sd_dist_phase1=0
gen sd_dist_phase2=0
gen sd_dist_phase3=0
gen sd_dist_phase4=0
gen sd_dist_phase6=0
gen sd_dist_phase7=0

replace sd_dist_phase1=sd_dist_phase if fase_oc==1
replace sd_dist_phase2=sd_dist_phase if fase_oc==2
replace sd_dist_phase3=sd_dist_phase if fase_oc==3
replace sd_dist_phase4=sd_dist_phase if fase_oc==4
replace sd_dist_phase6=sd_dist_phase if fase_oc==6
replace sd_dist_phase7=sd_dist_phase if fase_oc==7

drop sd_dist_phase



***** Firm Age (in months)

** Min

gen min_firm_age_phase1=0
gen min_firm_age_phase2=0
gen min_firm_age_phase3=0
gen min_firm_age_phase4=0
gen min_firm_age_phase6=0
gen min_firm_age_phase7=0

replace min_firm_age_phase1=min_firm_age_phase if fase_oc==1
replace min_firm_age_phase2=min_firm_age_phase if fase_oc==2
replace min_firm_age_phase3=min_firm_age_phase if fase_oc==3
replace min_firm_age_phase4=min_firm_age_phase if fase_oc==4
replace min_firm_age_phase6=min_firm_age_phase if fase_oc==6
replace min_firm_age_phase7=min_firm_age_phase if fase_oc==7

drop min_firm_age_phase



** Max

gen max_firm_age_phase1=0
gen max_firm_age_phase2=0
gen max_firm_age_phase3=0
gen max_firm_age_phase4=0
gen max_firm_age_phase6=0
gen max_firm_age_phase7=0

replace max_firm_age_phase1=max_firm_age_phase if fase_oc==1
replace max_firm_age_phase2=max_firm_age_phase if fase_oc==2
replace max_firm_age_phase3=max_firm_age_phase if fase_oc==3
replace max_firm_age_phase4=max_firm_age_phase if fase_oc==4
replace max_firm_age_phase6=max_firm_age_phase if fase_oc==6
replace max_firm_age_phase7=max_firm_age_phase if fase_oc==7

drop max_firm_age_phase


** Mean

gen mean_firm_age_phase1=0
gen mean_firm_age_phase2=0
gen mean_firm_age_phase3=0
gen mean_firm_age_phase4=0
gen mean_firm_age_phase6=0
gen mean_firm_age_phase7=0

replace mean_firm_age_phase1=mean_firm_age_phase if fase_oc==1
replace mean_firm_age_phase2=mean_firm_age_phase if fase_oc==2
replace mean_firm_age_phase3=mean_firm_age_phase if fase_oc==3
replace mean_firm_age_phase4=mean_firm_age_phase if fase_oc==4
replace mean_firm_age_phase6=mean_firm_age_phase if fase_oc==6
replace mean_firm_age_phase7=mean_firm_age_phase if fase_oc==7

drop mean_firm_age_phase


** Median

gen median_firm_age_phase1=0
gen median_firm_age_phase2=0
gen median_firm_age_phase3=0
gen median_firm_age_phase4=0
gen median_firm_age_phase6=0
gen median_firm_age_phase7=0

replace median_firm_age_phase1=median_firm_age_phase if fase_oc==1
replace median_firm_age_phase2=median_firm_age_phase if fase_oc==2
replace median_firm_age_phase3=median_firm_age_phase if fase_oc==3
replace median_firm_age_phase4=median_firm_age_phase if fase_oc==4
replace median_firm_age_phase6=median_firm_age_phase if fase_oc==6
replace median_firm_age_phase7=median_firm_age_phase if fase_oc==7

drop median_firm_age_phase


** Standard Deviation

gen sd_firm_age_phase1=0
gen sd_firm_age_phase2=0
gen sd_firm_age_phase3=0
gen sd_firm_age_phase4=0
gen sd_firm_age_phase6=0
gen sd_firm_age_phase7=0

replace sd_firm_age_phase1=sd_firm_age_phase if fase_oc==1
replace sd_firm_age_phase2=sd_firm_age_phase if fase_oc==2
replace sd_firm_age_phase3=sd_firm_age_phase if fase_oc==3
replace sd_firm_age_phase4=sd_firm_age_phase if fase_oc==4
replace sd_firm_age_phase6=sd_firm_age_phase if fase_oc==6
replace sd_firm_age_phase7=sd_firm_age_phase if fase_oc==7

drop sd_firm_age_phase



***** Counting Fornecs

** # bids

gen numbids_phase1=0
gen numbids_phase2=0
gen numbids_phase3=0
gen numbids_phase4=0
gen numbids_phase6=0
gen numbids_phase7=0

replace numbids_phase1=bids_sum_phase if fase_oc==1
replace numbids_phase2=bids_sum_phase if fase_oc==2
replace numbids_phase3=bids_sum_phase if fase_oc==3
replace numbids_phase4=bids_sum_phase if fase_oc==4
replace numbids_phase6=bids_sum_phase if fase_oc==6
replace numbids_phase7=bids_sum_phase if fase_oc==7

drop bids_sum_phase


** # participant firms

gen numfornecs_phase1=0
gen numfornecs_phase2=0
gen numfornecs_phase3=0
gen numfornecs_phase4=0
gen numfornecs_phase6=0
gen numfornecs_phase7=0

replace numfornecs_phase1=particip_firm_sum if fase_oc==1
replace numfornecs_phase2=particip_firm_sum if fase_oc==2
replace numfornecs_phase3=particip_firm_sum if fase_oc==3
replace numfornecs_phase4=particip_firm_sum if fase_oc==4
replace numfornecs_phase6=particip_firm_sum if fase_oc==6
replace numfornecs_phase7=particip_firm_sum if fase_oc==7

drop particip_firm_sum


** # fornecs Agro e Pesca

gen numfornecs_agro_phase1=0
gen numfornecs_agro_phase2=0
gen numfornecs_agro_phase3=0
gen numfornecs_agro_phase4=0
gen numfornecs_agro_phase6=0
gen numfornecs_agro_phase7=0

replace numfornecs_agro_phase1=n_fornec_agro if fase_oc==1
replace numfornecs_agro_phase2=n_fornec_agro if fase_oc==2
replace numfornecs_agro_phase3=n_fornec_agro if fase_oc==3
replace numfornecs_agro_phase4=n_fornec_agro if fase_oc==4
replace numfornecs_agro_phase6=n_fornec_agro if fase_oc==6
replace numfornecs_agro_phase7=n_fornec_agro if fase_oc==7

drop n_fornec_agro


** # fornecs Comércio

gen numfornecs_comercio_phase1=0
gen numfornecs_comercio_phase2=0
gen numfornecs_comercio_phase3=0
gen numfornecs_comercio_phase4=0
gen numfornecs_comercio_phase6=0
gen numfornecs_comercio_phase7=0

replace numfornecs_comercio_phase1=n_fornec_comercio if fase_oc==1
replace numfornecs_comercio_phase2=n_fornec_comercio if fase_oc==2
replace numfornecs_comercio_phase3=n_fornec_comercio if fase_oc==3
replace numfornecs_comercio_phase4=n_fornec_comercio if fase_oc==4
replace numfornecs_comercio_phase6=n_fornec_comercio if fase_oc==6
replace numfornecs_comercio_phase7=n_fornec_comercio if fase_oc==7

drop n_fornec_comercio


** # fornecs Indústria

gen numfornecs_ind_phase1=0
gen numfornecs_ind_phase2=0
gen numfornecs_ind_phase3=0
gen numfornecs_ind_phase4=0
gen numfornecs_ind_phase6=0
gen numfornecs_ind_phase7=0

replace numfornecs_ind_phase1=n_fornec_ind if fase_oc==1
replace numfornecs_ind_phase2=n_fornec_ind if fase_oc==2
replace numfornecs_ind_phase3=n_fornec_ind if fase_oc==3
replace numfornecs_ind_phase4=n_fornec_ind if fase_oc==4
replace numfornecs_ind_phase6=n_fornec_ind if fase_oc==6
replace numfornecs_ind_phase7=n_fornec_ind if fase_oc==7

drop n_fornec_ind


** # fornecs Meio Ambiente

gen numfornecs_meioamb_phase1=0
gen numfornecs_meioamb_phase2=0
gen numfornecs_meioamb_phase3=0
gen numfornecs_meioamb_phase4=0
gen numfornecs_meioamb_phase6=0
gen numfornecs_meioamb_phase7=0

replace numfornecs_meioamb_phase1=n_fornec_meioamb if fase_oc==1
replace numfornecs_meioamb_phase2=n_fornec_meioamb if fase_oc==2
replace numfornecs_meioamb_phase3=n_fornec_meioamb if fase_oc==3
replace numfornecs_meioamb_phase4=n_fornec_meioamb if fase_oc==4
replace numfornecs_meioamb_phase6=n_fornec_meioamb if fase_oc==6
replace numfornecs_meioamb_phase7=n_fornec_meioamb if fase_oc==7

drop n_fornec_meioamb



** # fornecs Serviços

gen numfornecs_serv_phase1=0
gen numfornecs_serv_phase2=0
gen numfornecs_serv_phase3=0
gen numfornecs_serv_phase4=0
gen numfornecs_serv_phase6=0
gen numfornecs_serv_phase7=0

replace numfornecs_serv_phase1=n_fornec_serv if fase_oc==1
replace numfornecs_serv_phase2=n_fornec_serv if fase_oc==2
replace numfornecs_serv_phase3=n_fornec_serv if fase_oc==3
replace numfornecs_serv_phase4=n_fornec_serv if fase_oc==4
replace numfornecs_serv_phase6=n_fornec_serv if fase_oc==6
replace numfornecs_serv_phase7=n_fornec_serv if fase_oc==7

drop n_fornec_serv


** # fornecs type ME

gen numfornecs_type_me_phase1=0
gen numfornecs_type_me_phase2=0
gen numfornecs_type_me_phase3=0
gen numfornecs_type_me_phase4=0
gen numfornecs_type_me_phase6=0
gen numfornecs_type_me_phase7=0

replace numfornecs_type_me_phase1=n_firms_me if fase_oc==1
replace numfornecs_type_me_phase2=n_firms_me if fase_oc==2
replace numfornecs_type_me_phase3=n_firms_me if fase_oc==3
replace numfornecs_type_me_phase4=n_firms_me if fase_oc==4
replace numfornecs_type_me_phase6=n_firms_me if fase_oc==6
replace numfornecs_type_me_phase7=n_firms_me if fase_oc==7

drop  n_firms_me


** # fornecs type EPP

gen numfornecs_type_epp_phase1=0
gen numfornecs_type_epp_phase2=0
gen numfornecs_type_epp_phase3=0
gen numfornecs_type_epp_phase4=0
gen numfornecs_type_epp_phase6=0
gen numfornecs_type_epp_phase7=0

replace numfornecs_type_epp_phase1=n_firms_epp if fase_oc==1
replace numfornecs_type_epp_phase2=n_firms_epp if fase_oc==2
replace numfornecs_type_epp_phase3=n_firms_epp if fase_oc==3
replace numfornecs_type_epp_phase4=n_firms_epp if fase_oc==4
replace numfornecs_type_epp_phase6=n_firms_epp if fase_oc==6
replace numfornecs_type_epp_phase7=n_firms_epp if fase_oc==7

drop  n_firms_epp


** # fornecs type OTHER

gen numfornecs_type_oth_phase1=0
gen numfornecs_type_oth_phase2=0
gen numfornecs_type_oth_phase3=0
gen numfornecs_type_oth_phase4=0
gen numfornecs_type_oth_phase6=0
gen numfornecs_type_oth_phase7=0

replace numfornecs_type_oth_phase1=n_firms_outros if fase_oc==1
replace numfornecs_type_oth_phase2=n_firms_outros if fase_oc==2
replace numfornecs_type_oth_phase3=n_firms_outros if fase_oc==3
replace numfornecs_type_oth_phase4=n_firms_outros if fase_oc==4
replace numfornecs_type_oth_phase6=n_firms_outros if fase_oc==6
replace numfornecs_type_oth_phase7=n_firms_outros if fase_oc==7

drop  n_firms_outros


** # fornecs same municip (UC and fornec)

gen numfornecs_same_munic_phase1=0
gen numfornecs_same_munic_phase2=0
gen numfornecs_same_munic_phase3=0
gen numfornecs_same_munic_phase4=0
gen numfornecs_same_munic_phase6=0
gen numfornecs_same_munic_phase7=0

replace numfornecs_same_munic_phase1=n_same_municip if fase_oc==1
replace numfornecs_same_munic_phase2=n_same_municip if fase_oc==2
replace numfornecs_same_munic_phase3=n_same_municip if fase_oc==3
replace numfornecs_same_munic_phase4=n_same_municip if fase_oc==4
replace numfornecs_same_munic_phase6=n_same_municip if fase_oc==6
replace numfornecs_same_munic_phase7=n_same_municip if fase_oc==7

drop n_same_municip


** # fornecs estado SP

gen numfornecs_est_SP_phase1=0
gen numfornecs_est_SP_phase2=0
gen numfornecs_est_SP_phase3=0
gen numfornecs_est_SP_phase4=0
gen numfornecs_est_SP_phase6=0
gen numfornecs_est_SP_phase7=0

replace numfornecs_est_SP_phase1=n_fornec_estado_SP if fase_oc==1
replace numfornecs_est_SP_phase2=n_fornec_estado_SP if fase_oc==2
replace numfornecs_est_SP_phase3=n_fornec_estado_SP if fase_oc==3
replace numfornecs_est_SP_phase4=n_fornec_estado_SP if fase_oc==4
replace numfornecs_est_SP_phase6=n_fornec_estado_SP if fase_oc==6
replace numfornecs_est_SP_phase7=n_fornec_estado_SP if fase_oc==7

drop n_fornec_estado_SP 


** # fornecs estado SP

gen numfornecs_city_SP_phase1=0
gen numfornecs_city_SP_phase2=0
gen numfornecs_city_SP_phase3=0
gen numfornecs_city_SP_phase4=0
gen numfornecs_city_SP_phase6=0
gen numfornecs_city_SP_phase7=0

replace numfornecs_city_SP_phase1=n_fornec_city_SP if fase_oc==1
replace numfornecs_city_SP_phase2=n_fornec_city_SP if fase_oc==2
replace numfornecs_city_SP_phase3=n_fornec_city_SP if fase_oc==3
replace numfornecs_city_SP_phase4=n_fornec_city_SP if fase_oc==4
replace numfornecs_city_SP_phase6=n_fornec_city_SP if fase_oc==6
replace numfornecs_city_SP_phase7=n_fornec_city_SP if fase_oc==7

drop n_fornec_city_SP



***** Elapsed Time

gen elapsed_time_phase1=0
gen elapsed_time_phase2=0
gen elapsed_time_phase3=0
gen elapsed_time_phase4=0
gen elapsed_time_phase6=0
gen elapsed_time_phase7=0

replace elapsed_time_phase1=oc_item_elapsed_time_minutes if fase_oc==1
replace elapsed_time_phase2=oc_item_elapsed_time_minutes if fase_oc==2
replace elapsed_time_phase3=oc_item_elapsed_time_minutes if fase_oc==3
replace elapsed_time_phase4=oc_item_elapsed_time_minutes if fase_oc==4
replace elapsed_time_phase6=oc_item_elapsed_time_minutes if fase_oc==6
replace elapsed_time_phase7=oc_item_elapsed_time_minutes if fase_oc==7

drop oc_item_elapsed_time_minutes 



***** Second Bid

gen second_bid_phase1=0
gen second_bid_phase2=0
gen second_bid_phase3=0
gen second_bid_phase4=0
gen second_bid_phase6=0
gen second_bid_phase7=0

replace second_bid_phase1=second_bid_phase if fase_oc==1
replace second_bid_phase2=second_bid_phase if fase_oc==2
replace second_bid_phase3=second_bid_phase if fase_oc==3
replace second_bid_phase4=second_bid_phase if fase_oc==4
replace second_bid_phase6=second_bid_phase if fase_oc==6
replace second_bid_phase7=second_bid_phase if fase_oc==7


drop second_bid_phase 


***** Difference between first and second bids

gen diff_first_sec_phase1=0
gen diff_first_sec_phase2=0
gen diff_first_sec_phase3=0
gen diff_first_sec_phase4=0
gen diff_first_sec_phase6=0
gen diff_first_sec_phase7=0

replace diff_first_sec_phase1=diff_first_second if fase_oc==1
replace diff_first_sec_phase2=diff_first_second if fase_oc==2
replace diff_first_sec_phase3=diff_first_second if fase_oc==3
replace diff_first_sec_phase4=diff_first_second if fase_oc==4
replace diff_first_sec_phase6=diff_first_second if fase_oc==6
replace diff_first_sec_phase7=diff_first_second if fase_oc==7



drop diff_first_second

drop fase_oc

*** Filling Missing Data


duplicates drop


bysort numerodaoc códigoitem: egen  min_bid_ph1 =max(min_bid_phase1)
bysort numerodaoc códigoitem: egen  min_bid_ph2 =max(min_bid_phase2)
bysort numerodaoc códigoitem: egen  min_bid_ph3 =max(min_bid_phase3)
bysort numerodaoc códigoitem: egen  min_bid_ph4 =max(min_bid_phase4)
bysort numerodaoc códigoitem: egen  min_bid_ph6 =max(min_bid_phase6)
bysort numerodaoc códigoitem: egen  min_bid_ph7 =max(min_bid_phase7)
bysort numerodaoc códigoitem: egen  max_bid_ph1 =max(max_bid_phase1)
bysort numerodaoc códigoitem: egen  max_bid_ph2 =max(max_bid_phase2)
bysort numerodaoc códigoitem: egen  max_bid_ph3 =max(max_bid_phase3)
bysort numerodaoc códigoitem: egen  max_bid_ph4 =max(max_bid_phase4)
bysort numerodaoc códigoitem: egen  max_bid_ph6 =max(max_bid_phase6)
bysort numerodaoc códigoitem: egen  max_bid_ph7 =max(max_bid_phase7)
bysort numerodaoc códigoitem: egen  mean_bid_ph1 =max(mean_bid_phase1)
bysort numerodaoc códigoitem: egen  mean_bid_ph2 =max(mean_bid_phase2)
bysort numerodaoc códigoitem: egen  mean_bid_ph3 =max(mean_bid_phase3)
bysort numerodaoc códigoitem: egen  mean_bid_ph4 =max(mean_bid_phase4)
bysort numerodaoc códigoitem: egen  mean_bid_ph6 =max(mean_bid_phase6)
bysort numerodaoc códigoitem: egen  mean_bid_ph7 =max(mean_bid_phase7)
bysort numerodaoc códigoitem: egen  median_bid_ph1 =max(median_bid_phase1)
bysort numerodaoc códigoitem: egen  median_bid_ph2 =max(median_bid_phase2)
bysort numerodaoc códigoitem: egen  median_bid_ph3 =max(median_bid_phase3)
bysort numerodaoc códigoitem: egen  median_bid_ph4 =max(median_bid_phase4)
bysort numerodaoc códigoitem: egen  median_bid_ph6 =max(median_bid_phase6)
bysort numerodaoc códigoitem: egen  median_bid_ph7 =max(median_bid_phase7)
bysort numerodaoc códigoitem: egen  sd_bid_ph1 =max(sd_bid_phase1)
bysort numerodaoc códigoitem: egen  sd_bid_ph2 =max(sd_bid_phase2)
bysort numerodaoc códigoitem: egen  sd_bid_ph3 =max(sd_bid_phase3)
bysort numerodaoc códigoitem: egen  sd_bid_ph4 =max(sd_bid_phase4)
bysort numerodaoc códigoitem: egen  sd_bid_ph6 =max(sd_bid_phase6)
bysort numerodaoc códigoitem: egen  sd_bid_ph7 =max(sd_bid_phase7)
bysort numerodaoc códigoitem: egen  min_dist_ph1 =max(min_dist_phase1)
bysort numerodaoc códigoitem: egen  min_dist_ph2 =max(min_dist_phase2)
bysort numerodaoc códigoitem: egen  min_dist_ph3 =max(min_dist_phase3)
bysort numerodaoc códigoitem: egen  min_dist_ph4 =max(min_dist_phase4)
bysort numerodaoc códigoitem: egen  min_dist_ph6 =max(min_dist_phase6)
bysort numerodaoc códigoitem: egen  min_dist_ph7 =max(min_dist_phase7)
bysort numerodaoc códigoitem: egen  max_dist_ph1 =max(max_dist_phase1)
bysort numerodaoc códigoitem: egen  max_dist_ph2 =max(max_dist_phase2)
bysort numerodaoc códigoitem: egen  max_dist_ph3 =max(max_dist_phase3)
bysort numerodaoc códigoitem: egen  max_dist_ph4 =max(max_dist_phase4)
bysort numerodaoc códigoitem: egen  max_dist_ph6 =max(max_dist_phase6)
bysort numerodaoc códigoitem: egen  max_dist_ph7 =max(max_dist_phase7)
bysort numerodaoc códigoitem: egen  mean_dist_ph1 =max(mean_dist_phase1)
bysort numerodaoc códigoitem: egen  mean_dist_ph2 =max(mean_dist_phase2)
bysort numerodaoc códigoitem: egen  mean_dist_ph3 =max(mean_dist_phase3)
bysort numerodaoc códigoitem: egen  mean_dist_ph4 =max(mean_dist_phase4)
bysort numerodaoc códigoitem: egen  mean_dist_ph6 =max(mean_dist_phase6)
bysort numerodaoc códigoitem: egen  mean_dist_ph7 =max(mean_dist_phase7)
bysort numerodaoc códigoitem: egen  median_dist_ph1 =max(median_dist_phase1)
bysort numerodaoc códigoitem: egen  median_dist_ph2 =max(median_dist_phase2)
bysort numerodaoc códigoitem: egen  median_dist_ph3 =max(median_dist_phase3)
bysort numerodaoc códigoitem: egen  median_dist_ph4 =max(median_dist_phase4)
bysort numerodaoc códigoitem: egen  median_dist_ph6 =max(median_dist_phase6)
bysort numerodaoc códigoitem: egen  median_dist_ph7 =max(median_dist_phase7)
bysort numerodaoc códigoitem: egen  sd_dist_ph1 =max(sd_dist_phase1)
bysort numerodaoc códigoitem: egen  sd_dist_ph2 =max(sd_dist_phase2)
bysort numerodaoc códigoitem: egen  sd_dist_ph3 =max(sd_dist_phase3)
bysort numerodaoc códigoitem: egen  sd_dist_ph4 =max(sd_dist_phase4)
bysort numerodaoc códigoitem: egen  sd_dist_ph6 =max(sd_dist_phase6)
bysort numerodaoc códigoitem: egen  sd_dist_ph7 =max(sd_dist_phase7)
bysort numerodaoc códigoitem: egen  min_firm_age_ph1 =max(min_firm_age_phase1)
bysort numerodaoc códigoitem: egen  min_firm_age_ph2 =max(min_firm_age_phase2)
bysort numerodaoc códigoitem: egen  min_firm_age_ph3 =max(min_firm_age_phase3)
bysort numerodaoc códigoitem: egen  min_firm_age_ph4 =max(min_firm_age_phase4)
bysort numerodaoc códigoitem: egen  min_firm_age_ph6 =max(min_firm_age_phase6)
bysort numerodaoc códigoitem: egen  min_firm_age_ph7 =max(min_firm_age_phase7)
bysort numerodaoc códigoitem: egen  max_firm_age_ph1 =max(max_firm_age_phase1)
bysort numerodaoc códigoitem: egen  max_firm_age_ph2 =max(max_firm_age_phase2)
bysort numerodaoc códigoitem: egen  max_firm_age_ph3 =max(max_firm_age_phase3)
bysort numerodaoc códigoitem: egen  max_firm_age_ph4 =max(max_firm_age_phase4)
bysort numerodaoc códigoitem: egen  max_firm_age_ph6 =max(max_firm_age_phase6)
bysort numerodaoc códigoitem: egen  max_firm_age_ph7 =max(max_firm_age_phase7)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph1 =max(mean_firm_age_phase1)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph2 =max(mean_firm_age_phase2)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph3 =max(mean_firm_age_phase3)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph4 =max(mean_firm_age_phase4)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph6 =max(mean_firm_age_phase6)
bysort numerodaoc códigoitem: egen  mean_firm_age_ph7 =max(mean_firm_age_phase7)
bysort numerodaoc códigoitem: egen  median_firm_age_ph1 =max(median_firm_age_phase1)
bysort numerodaoc códigoitem: egen  median_firm_age_ph2 =max(median_firm_age_phase2)
bysort numerodaoc códigoitem: egen  median_firm_age_ph3 =max(median_firm_age_phase3)
bysort numerodaoc códigoitem: egen  median_firm_age_ph4 =max(median_firm_age_phase4)
bysort numerodaoc códigoitem: egen  median_firm_age_ph6 =max(median_firm_age_phase6)
bysort numerodaoc códigoitem: egen  median_firm_age_ph7 =max(median_firm_age_phase7)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph1 =max(sd_firm_age_phase1)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph2 =max(sd_firm_age_phase2)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph3 =max(sd_firm_age_phase3)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph4 =max(sd_firm_age_phase4)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph6 =max(sd_firm_age_phase6)
bysort numerodaoc códigoitem: egen  sd_firm_age_ph7 =max(sd_firm_age_phase7)
bysort numerodaoc códigoitem: egen  numbids_ph1 =max(numbids_phase1)
bysort numerodaoc códigoitem: egen  numbids_ph2 =max(numbids_phase2)
bysort numerodaoc códigoitem: egen  numbids_ph3 =max(numbids_phase3)
bysort numerodaoc códigoitem: egen  numbids_ph4 =max(numbids_phase4)
bysort numerodaoc códigoitem: egen  numbids_ph6 =max(numbids_phase6)
bysort numerodaoc códigoitem: egen  numbids_ph7 =max(numbids_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_ph1 =max(numfornecs_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_ph2 =max(numfornecs_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_ph3 =max(numfornecs_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_ph4 =max(numfornecs_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_ph6 =max(numfornecs_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_ph7 =max(numfornecs_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph1 =max(numfornecs_agro_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph2 =max(numfornecs_agro_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph3 =max(numfornecs_agro_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph4 =max(numfornecs_agro_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph6 =max(numfornecs_agro_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_agro_ph7 =max(numfornecs_agro_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph1 =max(numfornecs_comercio_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph2 =max(numfornecs_comercio_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph3 =max(numfornecs_comercio_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph4 =max(numfornecs_comercio_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph6 =max(numfornecs_comercio_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_comercio_ph7 =max(numfornecs_comercio_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph1 =max(numfornecs_ind_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph2 =max(numfornecs_ind_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph3 =max(numfornecs_ind_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph4 =max(numfornecs_ind_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph6 =max(numfornecs_ind_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_ind_ph7 =max(numfornecs_ind_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph1 =max(numfornecs_meioamb_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph2 =max(numfornecs_meioamb_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph3 =max(numfornecs_meioamb_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph4 =max(numfornecs_meioamb_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph6 =max(numfornecs_meioamb_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_meioamb_ph7 =max(numfornecs_meioamb_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph1 =max(numfornecs_serv_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph2 =max(numfornecs_serv_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph3 =max(numfornecs_serv_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph4 =max(numfornecs_serv_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph6 =max(numfornecs_serv_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_serv_ph7 =max(numfornecs_serv_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph1 =max(numfornecs_type_me_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph2 =max(numfornecs_type_me_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph3 =max(numfornecs_type_me_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph4 =max(numfornecs_type_me_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph6 =max(numfornecs_type_me_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_me_ph7 =max(numfornecs_type_me_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph1 =max(numfornecs_type_epp_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph2 =max(numfornecs_type_epp_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph3 =max(numfornecs_type_epp_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph4 =max(numfornecs_type_epp_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph6 =max(numfornecs_type_epp_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_epp_ph7 =max(numfornecs_type_epp_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph1 =max(numfornecs_type_oth_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph2 =max(numfornecs_type_oth_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph3 =max(numfornecs_type_oth_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph4 =max(numfornecs_type_oth_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph6 =max(numfornecs_type_oth_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_type_oth_ph7 =max(numfornecs_type_oth_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph1 =max(numfornecs_same_munic_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph2 =max(numfornecs_same_munic_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph3 =max(numfornecs_same_munic_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph4 =max(numfornecs_same_munic_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph6 =max(numfornecs_same_munic_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_same_munic_ph7 =max(numfornecs_same_munic_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph1 =max(numfornecs_est_SP_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph2 =max(numfornecs_est_SP_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph3 =max(numfornecs_est_SP_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph4 =max(numfornecs_est_SP_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph6 =max(numfornecs_est_SP_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_est_SP_ph7 =max(numfornecs_est_SP_phase7)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph1 =max(numfornecs_city_SP_phase1)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph2 =max(numfornecs_city_SP_phase2)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph3 =max(numfornecs_city_SP_phase3)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph4 =max(numfornecs_city_SP_phase4)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph6 =max(numfornecs_city_SP_phase6)
bysort numerodaoc códigoitem: egen  numfornecs_city_SP_ph7 =max(numfornecs_city_SP_phase7)
bysort numerodaoc códigoitem: egen  elapsed_time_ph1 =max(elapsed_time_phase1)
bysort numerodaoc códigoitem: egen  elapsed_time_ph2 =max(elapsed_time_phase2)
bysort numerodaoc códigoitem: egen  elapsed_time_ph3 =max(elapsed_time_phase3)
bysort numerodaoc códigoitem: egen  elapsed_time_ph4 =max(elapsed_time_phase4)
bysort numerodaoc códigoitem: egen  elapsed_time_ph6 =max(elapsed_time_phase6)
bysort numerodaoc códigoitem: egen  elapsed_time_ph7 =max(elapsed_time_phase7)
bysort numerodaoc códigoitem: egen  second_bid_ph1 =max(second_bid_phase1)
bysort numerodaoc códigoitem: egen  second_bid_ph2 =max(second_bid_phase2)
bysort numerodaoc códigoitem: egen  second_bid_ph3 =max(second_bid_phase3)
bysort numerodaoc códigoitem: egen  second_bid_ph4 =max(second_bid_phase4)
bysort numerodaoc códigoitem: egen  second_bid_ph6 =max(second_bid_phase6)
bysort numerodaoc códigoitem: egen  second_bid_ph7 =max(second_bid_phase7)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph1 =max(diff_first_sec_phase1)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph2 =max(diff_first_sec_phase2)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph3 =max(diff_first_sec_phase3)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph4 =max(diff_first_sec_phase4)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph6 =max(diff_first_sec_phase6)
bysort numerodaoc códigoitem: egen  diff_first_sec_ph7 =max(diff_first_sec_phase7)
drop min_bid_phase1
drop min_bid_phase2
drop min_bid_phase3
drop min_bid_phase4
drop min_bid_phase6
drop min_bid_phase7
drop max_bid_phase1
drop max_bid_phase2
drop max_bid_phase3
drop max_bid_phase4
drop max_bid_phase6
drop max_bid_phase7
drop mean_bid_phase1
drop mean_bid_phase2
drop mean_bid_phase3
drop mean_bid_phase4
drop mean_bid_phase6
drop mean_bid_phase7
drop median_bid_phase1
drop median_bid_phase2
drop median_bid_phase3
drop median_bid_phase4
drop median_bid_phase6
drop median_bid_phase7
drop sd_bid_phase1
drop sd_bid_phase2
drop sd_bid_phase3
drop sd_bid_phase4
drop sd_bid_phase6
drop sd_bid_phase7
drop min_dist_phase1
drop min_dist_phase2
drop min_dist_phase3
drop min_dist_phase4
drop min_dist_phase6
drop min_dist_phase7
drop max_dist_phase1
drop max_dist_phase2
drop max_dist_phase3
drop max_dist_phase4
drop max_dist_phase6
drop max_dist_phase7
drop mean_dist_phase1
drop mean_dist_phase2
drop mean_dist_phase3
drop mean_dist_phase4
drop mean_dist_phase6
drop mean_dist_phase7
drop median_dist_phase1
drop median_dist_phase2
drop median_dist_phase3
drop median_dist_phase4
drop median_dist_phase6
drop median_dist_phase7
drop sd_dist_phase1
drop sd_dist_phase2
drop sd_dist_phase3
drop sd_dist_phase4
drop sd_dist_phase6
drop sd_dist_phase7
drop min_firm_age_phase1
drop min_firm_age_phase2
drop min_firm_age_phase3
drop min_firm_age_phase4
drop min_firm_age_phase6
drop min_firm_age_phase7
drop max_firm_age_phase1
drop max_firm_age_phase2
drop max_firm_age_phase3
drop max_firm_age_phase4
drop max_firm_age_phase6
drop max_firm_age_phase7
drop mean_firm_age_phase1
drop mean_firm_age_phase2
drop mean_firm_age_phase3
drop mean_firm_age_phase4
drop mean_firm_age_phase6
drop mean_firm_age_phase7
drop median_firm_age_phase1
drop median_firm_age_phase2
drop median_firm_age_phase3
drop median_firm_age_phase4
drop median_firm_age_phase6
drop median_firm_age_phase7
drop sd_firm_age_phase1
drop sd_firm_age_phase2
drop sd_firm_age_phase3
drop sd_firm_age_phase4
drop sd_firm_age_phase6
drop sd_firm_age_phase7
drop numbids_phase1
drop numbids_phase2
drop numbids_phase3
drop numbids_phase4
drop numbids_phase6
drop numbids_phase7
drop numfornecs_phase1
drop numfornecs_phase2
drop numfornecs_phase3
drop numfornecs_phase4
drop numfornecs_phase6
drop numfornecs_phase7
drop numfornecs_agro_phase1
drop numfornecs_agro_phase2
drop numfornecs_agro_phase3
drop numfornecs_agro_phase4
drop numfornecs_agro_phase6
drop numfornecs_agro_phase7
drop numfornecs_comercio_phase1
drop numfornecs_comercio_phase2
drop numfornecs_comercio_phase3
drop numfornecs_comercio_phase4
drop numfornecs_comercio_phase6
drop numfornecs_comercio_phase7
drop numfornecs_ind_phase1
drop numfornecs_ind_phase2
drop numfornecs_ind_phase3
drop numfornecs_ind_phase4
drop numfornecs_ind_phase6
drop numfornecs_ind_phase7
drop numfornecs_meioamb_phase1
drop numfornecs_meioamb_phase2
drop numfornecs_meioamb_phase3
drop numfornecs_meioamb_phase4
drop numfornecs_meioamb_phase6
drop numfornecs_meioamb_phase7
drop numfornecs_serv_phase1
drop numfornecs_serv_phase2
drop numfornecs_serv_phase3
drop numfornecs_serv_phase4
drop numfornecs_serv_phase6
drop numfornecs_serv_phase7
drop numfornecs_type_me_phase1
drop numfornecs_type_me_phase2
drop numfornecs_type_me_phase3
drop numfornecs_type_me_phase4
drop numfornecs_type_me_phase6
drop numfornecs_type_me_phase7
drop numfornecs_type_epp_phase1
drop numfornecs_type_epp_phase2
drop numfornecs_type_epp_phase3
drop numfornecs_type_epp_phase4
drop numfornecs_type_epp_phase6
drop numfornecs_type_epp_phase7
drop numfornecs_type_oth_phase1
drop numfornecs_type_oth_phase2
drop numfornecs_type_oth_phase3
drop numfornecs_type_oth_phase4
drop numfornecs_type_oth_phase6
drop numfornecs_type_oth_phase7
drop numfornecs_same_munic_phase1
drop numfornecs_same_munic_phase2
drop numfornecs_same_munic_phase3
drop numfornecs_same_munic_phase4
drop numfornecs_same_munic_phase6
drop numfornecs_same_munic_phase7
drop numfornecs_est_SP_phase1
drop numfornecs_est_SP_phase2
drop numfornecs_est_SP_phase3
drop numfornecs_est_SP_phase4
drop numfornecs_est_SP_phase6
drop numfornecs_est_SP_phase7
drop numfornecs_city_SP_phase1
drop numfornecs_city_SP_phase2
drop numfornecs_city_SP_phase3
drop numfornecs_city_SP_phase4
drop numfornecs_city_SP_phase6
drop numfornecs_city_SP_phase7
drop elapsed_time_phase1
drop elapsed_time_phase2
drop elapsed_time_phase3
drop elapsed_time_phase4
drop elapsed_time_phase6
drop elapsed_time_phase7
drop second_bid_phase1
drop second_bid_phase2
drop second_bid_phase3
drop second_bid_phase4
drop second_bid_phase6
drop second_bid_phase7
drop diff_first_sec_phase1
drop diff_first_sec_phase2
drop diff_first_sec_phase3
drop diff_first_sec_phase4
drop diff_first_sec_phase6
drop diff_first_sec_phase7



duplicates drop



save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_Items_Convite.dta", replace


clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_Items_Pregao.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_Items_Convite.dta" "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_Items_Dispensa.dta"

drop if data_oc==.

gen chave_status_oc= numerodaoc+ códigoitem
sort chave_status_oc

duplicates drop chave_status_oc, force

sort chave_status_oc

merge 1:1 chave_status_oc using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2_Final_Semester_status.dta", generate(_merge_xxx)


bysort códigounidadecompradora (pbu_cnpj): replace pbu_cnpj=pbu_cnpj[_N] if missing(pbu_cnpj)
bysort  descriçãounidadecompradora (pbu_cnpj): replace pbu_cnpj=pbu_cnpj[_N] if missing(pbu_cnpj)

bysort códigounidadecompradora (pbu_power): replace pbu_power=pbu_power[_N] if missing(pbu_power)
bysort descriçãounidadecompradora (pbu_power): replace pbu_power=pbu_power[_N] if missing(pbu_power)

bysort códigounidadecompradora (pbu_type_mgmt_code): replace pbu_type_mgmt_code=pbu_type_mgmt_code[_N] if missing(pbu_type_mgmt_code)
bysort descriçãounidadecompradora (pbu_type_mgmt_code): replace pbu_type_mgmt_code=pbu_type_mgmt_code[_N] if missing(pbu_type_mgmt_code)
 
bysort códigounidadecompradora (pbu_fedentity_code): replace pbu_fedentity_code=pbu_fedentity_code[_N] if missing(pbu_fedentity_code)
bysort descriçãounidadecompradora (pbu_fedentity_code): replace pbu_fedentity_code=pbu_fedentity_code[_N] if missing(pbu_fedentity_code)

bysort códigounidadecompradora (pbu_fedentity_descr): replace pbu_fedentity_descr=pbu_fedentity_descr[_N] if missing(pbu_fedentity_descr)
bysort descriçãounidadecompradora (pbu_fedentity_descr): replace pbu_fedentity_descr=pbu_fedentity_descr[_N] if missing(pbu_fedentity_descr) 
 
bysort códigounidadecompradora (pbu_region_code): replace pbu_region_code=pbu_region_code[_N] if missing(pbu_region_code)
bysort descriçãounidadecompradora (pbu_region_code): replace pbu_region_code=pbu_region_code[_N] if missing(pbu_region_code)
 
bysort códigounidadecompradora (pbu_region_descr): replace pbu_region_descr=pbu_region_descr[_N] if missing(pbu_region_descr)
bysort descriçãounidadecompradora (pbu_region_descr): replace pbu_region_descr=pbu_region_descr[_N] if missing(pbu_region_descr) 
 
bysort códigounidadecompradora (pbu_city_code): replace pbu_city_code=pbu_city_code[_N] if missing(pbu_city_code)
bysort descriçãounidadecompradora (pbu_city_code): replace pbu_city_code=pbu_city_code[_N] if missing(pbu_city_code)

bysort códigounidadecompradora (pbu_city_descr): replace pbu_city_descr=pbu_city_descr[_N] if missing(pbu_city_descr)
bysort descriçãounidadecompradora (pbu_city_descr): replace pbu_city_descr=pbu_city_descr[_N] if missing(pbu_city_descr)
 
bysort códigounidadecompradora (pbu_ibge_cod_uf): replace pbu_ibge_cod_uf=pbu_ibge_cod_uf[_N] if missing(pbu_ibge_cod_uf)
bysort descriçãounidadecompradora (pbu_ibge_cod_uf): replace pbu_ibge_cod_uf=pbu_ibge_cod_uf[_N] if missing(pbu_ibge_cod_uf) 

bysort códigounidadecompradora (pbu_city_area): replace pbu_city_area=pbu_city_area[_N] if missing(pbu_city_area)
bysort descriçãounidadecompradora (pbu_city_area): replace pbu_city_area=pbu_city_area[_N] if missing(pbu_city_area)

bysort códigounidadecompradora: egen pbu_latit2=min(pbu_latit)
drop pbu_latit
ren pbu_latit2 pbu_latit

bysort códigounidadecompradora: egen pbu_longit2=min(pbu_longit)
drop pbu_longit
ren pbu_longit2 pbu_longit

bysort códigounidadecompradora: egen pbu_ibge_cod_uf2=max(pbu_ibge_cod_uf)
drop pbu_ibge_cod_uf
ren pbu_ibge_cod_uf2 pbu_ibge_cod_uf

bysort códigounidadecompradora: egen ibge_cod_cidade_pbu2=max(ibge_cod_cidade_pbu)
drop ibge_cod_cidade_pbu
ren ibge_cod_cidade_pbu2 ibge_cod_cidade_pbu
 
drop if pbu_latit==.

bysort códigoitem: egen categ_item2=max(categ_item)
drop categ_item
ren categ_item2 categ_item


bysort códigoitem: egen item_verde2=max(item_verde)
drop item_verde
ren item_verde2 item_verde

gen winner_bid_exist=1
replace winner_bid_exist=0 if valorunitárionegociado_xxx=="0"
merge 1:1 numerodaoc códigoitem using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Item Ref/Itens_ref_antiga.dta", keepusing(categ_item2 green_item2) generate(_merge_t1)
drop if _merge_t1==2


*** Categoria Item

replace categ_item=0 if categ_item==2
label variable categ_item "0=Serv;1=Mat"
replace categ_item2=categ_item if categ_item2==.
drop categ_item
ren categ_item2 categ_item

bysort códigoitem: egen categ_item2=max(categ_item)
drop categ_item
ren categ_item2 categ_item

bysort  códigoclasse: egen categ_item2=max(categ_item)
drop categ_item
ren categ_item2 categ_item


*** Item Verde

replace item_verde=0 if item_verde==2
label variable item_verde "0=Não;1=Sim"
replace green_item2=item_verde if green_item2==.
drop item_verde
ren green_item2 item_verde

bysort códigoitem: egen item_verde2=max(item_verde)
drop item_verde
ren item_verde2 item_verde

bysort códigoclasse: egen item_verde2=max(item_verde)
drop item_verde
ren item_verde2 item_verde

*** Price Registration

sort numerodaoc
merge m:1 numerodaoc using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Item Ref/Price_reg_by_oc.dta", generate(_merge_price_reg)
drop if _merge_price_reg==2


replace  price_reg2=reg_precos if  price_reg2==.
replace price_reg2=0 if proc==1 | proc==2
replace price_reg2=0 if proc==3 &  _merge_price_reg==1
ren price_reg2 price_reg
drop  reg_precos



*** Quantidade

merge 1:1 numerodaoc códigoitem using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Item Ref/Itens_ref_antiga.dta", keepusing(bid_qty_item) generate(_merge_price_qty)
drop if _merge_price_qty==2

replace  bid_qty_item=qtde if  bid_qty_item==.

drop qtde
ren bid_qty_item qtde


*** Counting Items

*** Identifying distinct items, classes and groups by OC
by numerodaoc códigoitem, sort: gen item_oc_distinct = _n == 1
by numerodaoc códigoclasse, sort: gen classe_oc_distinct = _n == 1
by numerodaoc códigogrupo, sort: gen grupo_oc_distinct = _n == 1


*** Counting distinct items, classes and groups by OC
by numerodaoc : egen item_oc_count2 = total(item_oc_distinct)
by numerodaoc : egen classe_oc_count2 = total(classe_oc_distinct)
by numerodaoc : egen grupo_oc_count2 = total(grupo_oc_distinct)



drop descriçãomunicípiodeentrega descriçãoregiãodeentrega



drop  _merge_xxx _merge_t1 _merge_price_reg _merge_price_qty

drop  item_oc_count classe_oc_count grupo_oc_count
ren item_oc_count2 item_oc_count
ren classe_oc_count2 classe_oc_count
ren grupo_oc_count2 grupo_oc_count

drop preco_final
ren valorunitárionegociado_xxx preco_final


drop  item_oc_distinct classe_oc_distinct grupo_oc_distinct


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200330_Final_Semester_Items.dta", replace





clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_3_final_validbids.dta", clear

keep numerodaoc códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido flagvencedor valortotalproposta valortotalnegociado dist dist1 firm_age same_municip

duplicates drop numerodaoc firm_cnpj, force

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Pregao_firmas_por_oc.dta", replace


clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_2_final_validbids.dta", clear

keep numerodaoc códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido flagvencedor valortotalproposta valortotalnegociado dist dist1 firm_age same_municip

duplicates drop numerodaoc firm_cnpj, force


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Dispensa_firmas_por_oc.dta", replace


clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_1_final_validbids.dta", clear

keep numerodaoc códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido flagvencedor valortotalproposta valortotalnegociado dist dist1 firm_age same_municip

duplicates drop numerodaoc firm_cnpj, force


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Convite_firmas_por_oc.dta", replace

append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Dispensa_firmas_por_oc.dta" "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Pregao_firmas_por_oc.dta"

sort numerodaoc firm_cnpj

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Alimentar items_firmas_por_oc.dta", replace














*********New Collapse


*** Pregao

************ Preparing Collapse_ ITEMS
clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_3_final_validbids.dta", clear

drop pbu_year pbu_code_year _merge_JUD valorunitárioproposta  valortotalproposta quantidadeitemvencedor valortotalnegociado  data_inicio_ativid_aux data_inicio_ativid  n_firms_me_aux n_firms_epp_aux n_firms_outros_aux n_same_municip_aux n_fornec_estado_SP_aux n_fornec_city_SP_aux n_fornec_agro_aux n_fornec_comercio_aux n_fornec_ind_aux n_fornec_meioamb_aux n_fornec_serv_aux bid_time bid_time_date min_bid_time_phase max_bid_time_phase item_oc_distinct classe_oc_distinct grupo_oc_distinct valor_total_neg_max rank_fornec_oc particip_firm props_grupo_status descriçãopropostastatus bid_status fase_oc1_check fase_oc2_check fase_oc3_check fase_oc4_check fase_oc6_check fase_oc7_check pubag_descr phases_234 phases_23 phases_24 phases_12 phases_26 phases_2346 phases_123467 phases_23467 p10_bid_phase p20_bid_phase p30_bid_phase p40_bid_phase p60_bid_phase p70_bid_phase p80_bid_phase p90_bid_phase p10_dist_phase p20_dist_phase p30_dist_phase p40_dist_phase p60_dist_phase p70_dist_phase p80_dist_phase p90_dist_phase p10_firm_age_phase p20_firm_age_phase p30_firm_age_phase p40_firm_age_phase p60_firm_age_phase p70_firm_age_phase p80_firm_age_phase p90_firm_age_phase p10_firm_age_y_phase p20_firm_age_y_phase p30_firm_age_y_phase p40_firm_age_y_phase p60_firm_age_y_phase p70_firm_age_y_phase p80_firm_age_y_phase p90_firm_age_y_phase min_firm_age_y_phase max_firm_age_y_phase mean_firm_age_y_phase median_firm_age_y_phase sd_firm_age_y_phase oc_item_elapsed_time oc_item_elapsed_time_hours


order data_oc mês_oc ano_oc numerodaoc oc_status_code códigoitem descitem códigoclasse descclasseitem códigogrupo descgrupoitem proc_compra reg_precos categ_item item_verde preco_ref qtde me_epp oc_item_success sum_jud jud_regex códigounidadecompradora descriçãounidadecompradora pbu_code pbu_cnpj códigouo descriçãouo códigoórgão descriçãoórgão pbu_power pbu_type_mgmt_code pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_ibge_cod_uf ibge_cod_cidade_pbu pbu_city_area pbu_latit pbu_longit descriçãomunicípiodeentrega descriçãoregiãodeentrega fase_oc item_oc_count classe_oc_count grupo_oc_count fase_oc1 fase_oc2 fase_oc3 fase_oc4 fase_oc6 fase_oc7  preco_final min_bid_phase max_bid_phase mean_bid_phase median_bid_phase sd_bid_phase  min_dist_phase max_dist_phase mean_dist_phase median_dist_phase sd_dist_phase  min_firm_age_phase max_firm_age_phase mean_firm_age_phase median_firm_age_phase sd_firm_age_phase    bids_sum_phase particip_firm_sum n_fornec_agro n_fornec_comercio n_fornec_ind n_fornec_meioamb n_fornec_serv n_firms_me n_firms_epp n_firms_outros n_same_municip n_fornec_estado_SP n_fornec_city_SP  oc_item_elapsed_time_minutes second_bid_phase diff_first_second winner_bid_oc flagvencedor códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code

keep numerodaoc flagvencedor códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code códigoitem oc_item_success

duplicates drop

keep if flagvencedor=="1"

duplicates drop


drop flagvencedor

sort numerodaoc códigoitem códigofornecedor

duplicates drop numerodaoc códigoitem códigofornecedor, force

save "C:/Users/pesquisa/Desktop/Fornecs_1.dta", replace

clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200330_Final_Semester_Items_Pregao.dta", clear

sort numerodaoc códigoitem códigofornecedor

merge 1:1 numerodaoc códigoitem códigofornecedor using "C:/Users/pesquisa/Desktop/Fornecs_1.dta", generate(_merge_fornec_x)
drop if _merge_fornec_x==2




save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Pregao_Teste.dta", replace










*** Dispensa

************ Preparing Collapse_ ITEMS
clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_2_final_validbids.dta", clear

drop pbu_year pbu_code_year _merge_JUD valorunitárioproposta  valortotalproposta quantidadeitemvencedor valortotalnegociado  data_inicio_ativid_aux data_inicio_ativid  n_firms_me_aux n_firms_epp_aux n_firms_outros_aux n_same_municip_aux n_fornec_estado_SP_aux n_fornec_city_SP_aux n_fornec_agro_aux n_fornec_comercio_aux n_fornec_ind_aux n_fornec_meioamb_aux n_fornec_serv_aux bid_time bid_time_date min_bid_time_phase max_bid_time_phase item_oc_distinct classe_oc_distinct grupo_oc_distinct valor_total_neg_max rank_fornec_oc particip_firm props_grupo_status descriçãopropostastatus bid_status fase_oc1_check fase_oc2_check fase_oc3_check fase_oc4_check fase_oc6_check fase_oc7_check pubag_descr phases_234 phases_23 phases_24 phases_12 phases_26 phases_2346 phases_123467 phases_23467 p10_bid_phase p20_bid_phase p30_bid_phase p40_bid_phase p60_bid_phase p70_bid_phase p80_bid_phase p90_bid_phase p10_dist_phase p20_dist_phase p30_dist_phase p40_dist_phase p60_dist_phase p70_dist_phase p80_dist_phase p90_dist_phase p10_firm_age_phase p20_firm_age_phase p30_firm_age_phase p40_firm_age_phase p60_firm_age_phase p70_firm_age_phase p80_firm_age_phase p90_firm_age_phase p10_firm_age_y_phase p20_firm_age_y_phase p30_firm_age_y_phase p40_firm_age_y_phase p60_firm_age_y_phase p70_firm_age_y_phase p80_firm_age_y_phase p90_firm_age_y_phase min_firm_age_y_phase max_firm_age_y_phase mean_firm_age_y_phase median_firm_age_y_phase sd_firm_age_y_phase oc_item_elapsed_time oc_item_elapsed_time_hours


order data_oc mês_oc ano_oc numerodaoc oc_status_code códigoitem descitem códigoclasse descclasseitem códigogrupo descgrupoitem proc_compra reg_precos categ_item item_verde preco_ref qtde me_epp oc_item_success sum_jud jud_regex códigounidadecompradora descriçãounidadecompradora pbu_code pbu_cnpj códigouo descriçãouo códigoórgão descriçãoórgão pbu_power pbu_type_mgmt_code pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_ibge_cod_uf ibge_cod_cidade_pbu pbu_city_area pbu_latit pbu_longit descriçãomunicípiodeentrega descriçãoregiãodeentrega fase_oc item_oc_count classe_oc_count grupo_oc_count fase_oc1 fase_oc2 fase_oc3 fase_oc4 fase_oc6 fase_oc7  preco_final min_bid_phase max_bid_phase mean_bid_phase median_bid_phase sd_bid_phase  min_dist_phase max_dist_phase mean_dist_phase median_dist_phase sd_dist_phase  min_firm_age_phase max_firm_age_phase mean_firm_age_phase median_firm_age_phase sd_firm_age_phase    bids_sum_phase particip_firm_sum n_fornec_agro n_fornec_comercio n_fornec_ind n_fornec_meioamb n_fornec_serv n_firms_me n_firms_epp n_firms_outros n_same_municip n_fornec_estado_SP n_fornec_city_SP  oc_item_elapsed_time_minutes second_bid_phase diff_first_second winner_bid_oc flagvencedor códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code

keep numerodaoc flagvencedor códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code códigoitem oc_item_success

duplicates drop

keep if flagvencedor=="1"

duplicates drop


drop flagvencedor

sort numerodaoc códigoitem códigofornecedor

duplicates drop numerodaoc códigoitem códigofornecedor, force

save "C:/Users/pesquisa/Desktop/Fornecs_2.dta", replace

clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200330_Final_Semester_Items_Dispensa.dta", clear

sort numerodaoc códigoitem códigofornecedor

merge 1:1 numerodaoc códigoitem códigofornecedor using "C:/Users/pesquisa/Desktop/Fornecs_2.dta", generate(_merge_fornec_x)
drop if _merge_fornec_x==2




save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Dispensa_Teste.dta", replace
















*** Convite

************ Preparing Collapse_ ITEMS
clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Semester_proc_1_final_validbids.dta", clear

drop pbu_year pbu_code_year _merge_JUD valorunitárioproposta  valortotalproposta quantidadeitemvencedor valortotalnegociado  data_inicio_ativid_aux data_inicio_ativid  n_firms_me_aux n_firms_epp_aux n_firms_outros_aux n_same_municip_aux n_fornec_estado_SP_aux n_fornec_city_SP_aux n_fornec_agro_aux n_fornec_comercio_aux n_fornec_ind_aux n_fornec_meioamb_aux n_fornec_serv_aux bid_time bid_time_date min_bid_time_phase max_bid_time_phase item_oc_distinct classe_oc_distinct grupo_oc_distinct valor_total_neg_max rank_fornec_oc particip_firm props_grupo_status descriçãopropostastatus bid_status fase_oc1_check fase_oc2_check fase_oc3_check fase_oc4_check fase_oc6_check fase_oc7_check pubag_descr phases_234 phases_23 phases_24 phases_12 phases_26 phases_2346 phases_123467 phases_23467 p10_bid_phase p20_bid_phase p30_bid_phase p40_bid_phase p60_bid_phase p70_bid_phase p80_bid_phase p90_bid_phase p10_dist_phase p20_dist_phase p30_dist_phase p40_dist_phase p60_dist_phase p70_dist_phase p80_dist_phase p90_dist_phase p10_firm_age_phase p20_firm_age_phase p30_firm_age_phase p40_firm_age_phase p60_firm_age_phase p70_firm_age_phase p80_firm_age_phase p90_firm_age_phase p10_firm_age_y_phase p20_firm_age_y_phase p30_firm_age_y_phase p40_firm_age_y_phase p60_firm_age_y_phase p70_firm_age_y_phase p80_firm_age_y_phase p90_firm_age_y_phase min_firm_age_y_phase max_firm_age_y_phase mean_firm_age_y_phase median_firm_age_y_phase sd_firm_age_y_phase oc_item_elapsed_time oc_item_elapsed_time_hours


order data_oc mês_oc ano_oc numerodaoc oc_status_code códigoitem descitem códigoclasse descclasseitem códigogrupo descgrupoitem proc_compra reg_precos categ_item item_verde preco_ref qtde me_epp oc_item_success sum_jud jud_regex códigounidadecompradora descriçãounidadecompradora pbu_code pbu_cnpj códigouo descriçãouo códigoórgão descriçãoórgão pbu_power pbu_type_mgmt_code pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_ibge_cod_uf ibge_cod_cidade_pbu pbu_city_area pbu_latit pbu_longit descriçãomunicípiodeentrega descriçãoregiãodeentrega fase_oc item_oc_count classe_oc_count grupo_oc_count fase_oc1 fase_oc2 fase_oc3 fase_oc4 fase_oc6 fase_oc7  preco_final min_bid_phase max_bid_phase mean_bid_phase median_bid_phase sd_bid_phase  min_dist_phase max_dist_phase mean_dist_phase median_dist_phase sd_dist_phase  min_firm_age_phase max_firm_age_phase mean_firm_age_phase median_firm_age_phase sd_firm_age_phase    bids_sum_phase particip_firm_sum n_fornec_agro n_fornec_comercio n_fornec_ind n_fornec_meioamb n_fornec_serv n_firms_me n_firms_epp n_firms_outros n_same_municip n_fornec_estado_SP n_fornec_city_SP  oc_item_elapsed_time_minutes second_bid_phase diff_first_second winner_bid_oc flagvencedor códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code

keep numerodaoc flagvencedor códigofornecedor descriçãonaturezajurídica descriçãorazãosocial descriçãomunicípiofornecedor descriçãouffornecedor códigocepfornecedor fornec_enquad fornec_pessoa fornec_mat_filial fornec_tipo_end firm_cnpj cnae_fiscal porte_empresa firm_zipcode fornec_latitude fornec_longitude dist dist1 firm_age firm_age_years same_municip fornec_estado_SP fornec_city_SP secao_cnae cnae_descr cnae_resumido cnae_resum_code códigoitem oc_item_success

duplicates drop

keep if flagvencedor=="1"

duplicates drop


drop flagvencedor

sort numerodaoc códigoitem códigofornecedor

duplicates drop numerodaoc códigoitem códigofornecedor, force

save "C:/Users/pesquisa/Desktop/Fornecs_3.dta", replace

clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200330_Final_Semester_Items_Convite.dta", clear

sort numerodaoc códigoitem códigofornecedor

merge 1:1 numerodaoc códigoitem códigofornecedor using "C:/Users/pesquisa/Desktop/Fornecs_3.dta", generate(_merge_fornec_x)
drop if _merge_fornec_x==2




save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Convite_Teste.dta", replace




clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Convite_Teste.dta", clear

append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Dispensa_Teste.dta" "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Final_Pregao_Teste.dta"









***************ITENS


drop  _merge_fornec_x

drop if data_oc==.

drop  chave_status_oc

gen chave_status_oc= numerodaoc+ códigoitem
sort chave_status_oc

duplicates drop chave_status_oc, force

sort chave_status_oc

merge 1:1 chave_status_oc using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2_Final_Semester_status.dta", generate(_merge_xxx)


bysort códigounidadecompradora (pbu_cnpj): replace pbu_cnpj=pbu_cnpj[_N] if missing(pbu_cnpj)
bysort  descriçãounidadecompradora (pbu_cnpj): replace pbu_cnpj=pbu_cnpj[_N] if missing(pbu_cnpj)

bysort códigounidadecompradora (pbu_power): replace pbu_power=pbu_power[_N] if missing(pbu_power)
bysort descriçãounidadecompradora (pbu_power): replace pbu_power=pbu_power[_N] if missing(pbu_power)

bysort códigounidadecompradora (pbu_type_mgmt_code): replace pbu_type_mgmt_code=pbu_type_mgmt_code[_N] if missing(pbu_type_mgmt_code)
bysort descriçãounidadecompradora (pbu_type_mgmt_code): replace pbu_type_mgmt_code=pbu_type_mgmt_code[_N] if missing(pbu_type_mgmt_code)
 
bysort códigounidadecompradora (pbu_fedentity_code): replace pbu_fedentity_code=pbu_fedentity_code[_N] if missing(pbu_fedentity_code)
bysort descriçãounidadecompradora (pbu_fedentity_code): replace pbu_fedentity_code=pbu_fedentity_code[_N] if missing(pbu_fedentity_code)

bysort códigounidadecompradora (pbu_fedentity_descr): replace pbu_fedentity_descr=pbu_fedentity_descr[_N] if missing(pbu_fedentity_descr)
bysort descriçãounidadecompradora (pbu_fedentity_descr): replace pbu_fedentity_descr=pbu_fedentity_descr[_N] if missing(pbu_fedentity_descr) 
 
bysort códigounidadecompradora (pbu_region_code): replace pbu_region_code=pbu_region_code[_N] if missing(pbu_region_code)
bysort descriçãounidadecompradora (pbu_region_code): replace pbu_region_code=pbu_region_code[_N] if missing(pbu_region_code)
 
bysort códigounidadecompradora (pbu_region_descr): replace pbu_region_descr=pbu_region_descr[_N] if missing(pbu_region_descr)
bysort descriçãounidadecompradora (pbu_region_descr): replace pbu_region_descr=pbu_region_descr[_N] if missing(pbu_region_descr) 
 
bysort códigounidadecompradora (pbu_city_code): replace pbu_city_code=pbu_city_code[_N] if missing(pbu_city_code)
bysort descriçãounidadecompradora (pbu_city_code): replace pbu_city_code=pbu_city_code[_N] if missing(pbu_city_code)

bysort códigounidadecompradora (pbu_city_descr): replace pbu_city_descr=pbu_city_descr[_N] if missing(pbu_city_descr)
bysort descriçãounidadecompradora (pbu_city_descr): replace pbu_city_descr=pbu_city_descr[_N] if missing(pbu_city_descr)
 
bysort códigounidadecompradora (pbu_ibge_cod_uf): replace pbu_ibge_cod_uf=pbu_ibge_cod_uf[_N] if missing(pbu_ibge_cod_uf)
bysort descriçãounidadecompradora (pbu_ibge_cod_uf): replace pbu_ibge_cod_uf=pbu_ibge_cod_uf[_N] if missing(pbu_ibge_cod_uf) 

bysort códigounidadecompradora (pbu_city_area): replace pbu_city_area=pbu_city_area[_N] if missing(pbu_city_area)
bysort descriçãounidadecompradora (pbu_city_area): replace pbu_city_area=pbu_city_area[_N] if missing(pbu_city_area)

bysort códigounidadecompradora: egen pbu_latit2=min(pbu_latit)
drop pbu_latit
ren pbu_latit2 pbu_latit

bysort códigounidadecompradora: egen pbu_longit2=min(pbu_longit)
drop pbu_longit
ren pbu_longit2 pbu_longit

bysort códigounidadecompradora: egen pbu_ibge_cod_uf2=max(pbu_ibge_cod_uf)
drop pbu_ibge_cod_uf
ren pbu_ibge_cod_uf2 pbu_ibge_cod_uf

bysort códigounidadecompradora: egen ibge_cod_cidade_pbu2=max(ibge_cod_cidade_pbu)
drop ibge_cod_cidade_pbu
ren ibge_cod_cidade_pbu2 ibge_cod_cidade_pbu
 
drop if pbu_latit==.

bysort códigoitem: egen categ_item2=max(categ_item)
drop categ_item
ren categ_item2 categ_item


bysort códigoitem: egen item_verde2=max(item_verde)
drop item_verde
ren item_verde2 item_verde

drop winner_bid_exist
gen winner_bid_exist=1
replace winner_bid_exist=0 if valorunitárionegociado_xxx=="0"

merge 1:1 numerodaoc códigoitem using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Item Ref/Itens_ref_antiga.dta", keepusing(categ_item2 green_item2) generate(_merge_t1)
drop if _merge_t1==2


*** Categoria Item

replace categ_item=0 if categ_item==2
label variable categ_item "0=Serv;1=Mat"
replace categ_item2=categ_item if categ_item2==.
drop categ_item
ren categ_item2 categ_item

bysort códigoitem: egen categ_item2=max(categ_item)
drop categ_item
ren categ_item2 categ_item

bysort  códigoclasse: egen categ_item2=max(categ_item)
drop categ_item
ren categ_item2 categ_item


*** Item Verde

replace item_verde=0 if item_verde==2
label variable item_verde "0=Não;1=Sim"
replace green_item2=item_verde if green_item2==.
drop item_verde
ren green_item2 item_verde

bysort códigoitem: egen item_verde2=max(item_verde)
drop item_verde
ren item_verde2 item_verde

bysort códigoclasse: egen item_verde2=max(item_verde)
drop item_verde
ren item_verde2 item_verde

*** Price Registration

sort numerodaoc
merge m:1 numerodaoc using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Item Ref/Price_reg_by_oc.dta", generate(_merge_price_reg)
drop if _merge_price_reg==2


replace  price_reg2=price_reg if  price_reg2==.
replace price_reg2=0 if proc==1 | proc==2
replace price_reg2=0 if proc==3 &  _merge_price_reg==1
drop price_reg
ren price_reg2 price_reg




*** Quantidade

merge 1:1 numerodaoc códigoitem using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/Item Ref/Itens_ref_antiga.dta", keepusing(bid_qty_item) generate(_merge_price_qty)
drop if _merge_price_qty==2

replace  bid_qty_item=qtde if  bid_qty_item==.

drop qtde
ren bid_qty_item qtde


*** Counting Items

drop  item_oc_distinct classe_oc_distinct grupo_oc_distinct

*** Identifying distinct items, classes and groups by OC
by numerodaoc códigoitem, sort: gen item_oc_distinct = _n == 1
by numerodaoc códigoclasse, sort: gen classe_oc_distinct = _n == 1
by numerodaoc códigogrupo, sort: gen grupo_oc_distinct = _n == 1

drop  item_oc_count2 classe_oc_count2 grupo_oc_count2

*** Counting distinct items, classes and groups by OC
by numerodaoc : egen item_oc_count2 = total(item_oc_distinct)
by numerodaoc : egen classe_oc_count2 = total(classe_oc_distinct)
by numerodaoc : egen grupo_oc_count2 = total(grupo_oc_distinct)






drop  _merge_xxx _merge_t1 _merge_price_reg _merge_price_qty

drop  item_oc_count classe_oc_count grupo_oc_count
ren item_oc_count2 item_oc_count
ren classe_oc_count2 classe_oc_count
ren grupo_oc_count2 grupo_oc_count

drop preco_final
ren valorunitárionegociado_xxx preco_final


drop  item_oc_distinct classe_oc_distinct grupo_oc_distinct
drop ano_oc
rename ano_oc_xxx ano_oc
drop  data_oc mês_oc
rename data_oc_xxx data_oc
rename mês_oc_xxx mês_oc
drop numerodaoc_xxx
drop descrofertacomprastatus_xxx
drop proc__xxx
drop códigoórgão_xxx descriçãoórgão_xxx códigouo_xxx descriçãouo_xxx
drop  códigounidadecompradora_xxx descriçãounidadecompradora_xxx
drop  códigogrupo_xxx descgrupoitem_xxx códigoclasse_xxx descclasseitem_xxx códigoitem_xxx descitem_xxx
drop descunidadefornecimento_xxx
drop códigofornecedor_xxx
drop qtdeofertacompraitem_xxx
drop preco_ref_xxx
drop partexclmeeppcooper_xxx
drop oc_item_status_xxx
drop jud_regex_xxx
drop jud_regex2_xxx
drop jud_xxx
drop chave_status_oc
drop firm_cnpj
drop oc_item_status
gen oc_item_status2=1
replace oc_item_status2=0 if códigofornecedor=="Sem Vencedor"
ren oc_item_status2 oc_item_status
drop oc_item_success



bysort códigofornecedor(descriçãonaturezajurídica): replace descriçãonaturezajurídica=descriçãonaturezajurídica[_N] if missing(descriçãonaturezajurídica)

bysort códigofornecedor(descriçãorazãosocial): replace descriçãorazãosocial=descriçãorazãosocial[_N] if missing(descriçãorazãosocial)

bysort códigofornecedor(descriçãomunicípiofornecedor): replace descriçãomunicípiofornecedor=descriçãomunicípiofornecedor[_N] if missing(descriçãomunicípiofornecedor)

bysort códigofornecedor(descriçãouffornecedor): replace descriçãouffornecedor=descriçãouffornecedor[_N] if missing(descriçãouffornecedor)
   
bysort códigofornecedor(códigocepfornecedor): replace códigocepfornecedor=códigocepfornecedor[_N] if missing(códigocepfornecedor)   
   
bysort códigofornecedor(cnae_fiscal): replace cnae_fiscal=cnae_fiscal[_N] if missing(cnae_fiscal)        

bysort códigofornecedor(porte_empresa): replace porte_empresa=porte_empresa[_N] if missing(porte_empresa)
        	 
bysort códigofornecedor(firm_zipcode): replace firm_zipcode=firm_zipcode[_N] if missing(firm_zipcode)

drop firm_zipcode
			 
bysort códigofornecedor(secao_cnae): replace secao_cnae=secao_cnae[_N] if missing(secao_cnae)

bysort códigofornecedor(cnae_descr): replace cnae_descr=cnae_descr[_N] if missing(cnae_descr)

bysort códigofornecedor(cnae_resumido): replace cnae_resumido=cnae_resumido[_N] if missing(cnae_resumido)
			  
drop firm_age_years

bysort códigofornecedor: egen fornec_latit2=min(fornec_latitude)
drop fornec_latitude
ren fornec_latit2 fornec_latitude

bysort códigofornecedor: egen fornec_longit2=min(fornec_longitude)
drop fornec_longitude
ren fornec_longit2 fornec_longitude

bysort códigofornecedor: egen fornec_enquad2=max(fornec_enquad)
drop fornec_enquad
ren fornec_enquad2 fornec_enquad 
 
bysort códigofornecedor: egen fornec_estado_SP2=max(fornec_estado_SP)
drop fornec_estado_SP
ren fornec_estado_SP2 fornec_estado_SP  

bysort códigofornecedor: egen fornec_city_SP2=max(fornec_city_SP)
drop fornec_city_SP
ren fornec_city_SP2 fornec_city_SP 

bysort códigofornecedor: egen cnae_resum_code2=max(cnae_resum_code)
drop cnae_resum_code
ren cnae_resum_code2 cnae_resum_code 
 
drop  fornec_pessoa
drop fornec_tipo_end fornec_mat_filial


geodist pbu_latit pbu_longit fornec_latitude fornec_longitude , generate(dist2)
gen dist3=dist2
replace dist3=0.05 if dist2==0

merge m:1 códigofornecedor using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/CNPJ Geoc/Cnpj_data_inicio_atividade_menor.dta", generate(_merge8)
drop _merge8

  

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200331_Items_BEC.dta", replace



preserve

keep if proc==1

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200330_Final_Semester_Items_Convite.dta", replace

restore


preserve

keep if proc==2

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200330_Final_Semester_Items_Dispensa.dta", replace

restore


preserve

keep if proc==3

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Final_Semester_2020/20200330_Final_Semester_Items_Pregao.dta", replace

restore































