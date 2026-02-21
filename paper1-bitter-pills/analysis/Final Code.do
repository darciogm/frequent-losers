** Generating Database

sort item
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/JUD_S-CODES_working.dta", generate(_merge_codes)
keep if _merge_codes==3

save "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/BEC_S-CODES_SUBSAMPLE_FINAL_2.dta", replace

gen jud = 0
replace jud = 1 if strpos(po_subject, "JUDIC") | strpos(po_subject, "LIMINAR") | strpos(po_subject, "MANDADO") | strpos(po_subject, "MAN-DADO") | strpos(po_subject, " AJ")

gen adm = 0
replace adm =2 if strpos(po_subject, "ADMINISTRATIV")

gen jud_adm = 0
replace jud_adm = 1 if strpos(po_subject, "JUDIC") | strpos(po_subject, "LIMINAR") | strpos(po_subject, "MANDADO") | strpos(po_subject, "MAN-DADO") | strpos(po_subject, " AJ") | strpos(po_subject, "ADMINISTRATIV")

gen price_reg = 0
replace price_reg =1 if strpos(po_subject, "REGISTRO DE PRECOS")

gen po_firm_winner = 1
replace po_firm_winner = 0 if firm_id == "00Sem Vencedor"

destring bid_qty bid_price_ref bid_price, replace dpcomma

gen bid_qty_log=ln(bid_qty)
gen bid_price_ref_log=ln(bid_price_ref)
gen bid_price_log=ln(bid_price)

save "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/BEC_JUD.dta", replace

export delimited using "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/Variables_subsample_jud_adm.csv", delimiter(";") replace

clear all
import excel "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/SUBSAMPLE_14052019.xlsx", sheet("Final") firstrow allstring
sort item
save "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/BEC_JUD_SUBSAMPLE_SELECTION.dta", replace

clear all
use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/BEC_JUD.dta", clear

sort item
drop _merge
merge m:1 item using "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/BEC_JUD_SUBSAMPLE_SELECTION.dta"
ren _merge _merge_subsample
keep if _merge_subsample == 3

destring bid_qty bid_price_ref bid_price, replace dpcomma
drop if padronizadosus=="Não"

save "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/2_BEC_JUD_SUBSAMPLE.dta", replace

quietly tab item, generate(ditem)
quietly tab pbu_code, generate(dpbu_code)
quietly tab year, generate(dyear)
quietly tab m_y, gen(dm_y)

** Generating variable month

gen dm=m_y
format dm %10.0g
di (53 - 60)*12
gen date_dm = dofm(dm)
format date %d
gen month=month(date_dm)
quietly tab month, generate(dmonth)



drop ditem1 dpbu_code1 dyear1 dmonth1 dm_y1

gen sp_city=0
replace sp_city=1 if pbu_city_descr=="SAO PAULO"

gen pregao=0
replace pregao=1 if po_proc_code==3

drop if po_proc_code==2

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Papers/Paper 1 - JUD/3_BEC_PAPER_1_JUD_FINAL.dta", replace


** Estimation


* 1) TOTAL EFFECT (ALL DATA)

*** Success / Failure

*** Plain Model

eststo clear
eststo: quietly logit po_firm_winner jud ditem* 
eststo: quietly logit po_firm_winner jud ditem* dpbu* 
eststo: quietly logit po_firm_winner jud ditem* dpbu* pregao
eststo: quietly logit po_firm_winner jud ditem* dpbu* dyear* dmonth* pregao 
esttab using success_fail_raw.rtf, b(%9.4f) se(%9.4f) drop(ditem* dpbu* dyear* dmonth* _cons) label title(Successful/Fail Bids (Dep. Var: Successful Bid or Not)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace

*** Marginal Effects

eststo clear
quietly logit po_firm_winner jud ditem*
eststo: margins, dydx(*) 
quietly logit po_firm_winner jud ditem* dpbu*
eststo: margins, dydx(*) 
quietly logit po_firm_winner jud ditem* dpbu* pregao
eststo: margins, dydx(*) 
quietly logit po_firm_winner jud ditem* dpbu* dyear* dmonth* pregao
eststo: margins, dydx(*) 
esttab using success_fail_margins.rtf, b(%9.4f) se(%9.4f) drop(ditem* dpbu* dyear* dmonth* _cons) label title(Standard vs. Litigated Purchases (Dep. Var: Successful Bid or Not)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace


*** Reserve Prices (w/o controlling for quantity)

eststo clear
eststo: quietly reg bid_price_ref_log jud ditem* if po_firm_winner==1
eststo: quietly reg bid_price_ref_log jud ditem* dpbu* if po_firm_winner==1
eststo: quietly reg bid_price_ref_log jud ditem* dpbu* pregao if po_firm_winner==1
eststo: quietly reg bid_price_ref_log jud ditem* dpbu* dyear* dmonth* pregao if po_firm_winner==1
esttab using res_prices_no_quantity.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* dmonth* _cons) label title(Effect of Litigation on Reserve Prices (Dep. Var.: Log Reserve Prices)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace

*** Reserve Prices (controlling for quantity)

eststo clear
eststo: quietly reg bid_price_ref_log jud bid_qty_log ditem* if po_firm_winner==1
eststo: quietly reg bid_price_ref_log jud bid_qty_log ditem* dpbu* if po_firm_winner==1
eststo: quietly reg bid_price_ref_log jud bid_qty_log ditem* dpbu* pregao if po_firm_winner==1
eststo: quietly reg bid_price_ref_log jud bid_qty_log ditem* dpbu* dyear* dmonth* pregao if po_firm_winner==1
esttab using res_prices_quantity_contr.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* dmonth* _cons) label title(Effect of Litigation on Reserve Prices (Dep. Var.: Log Reserve Prices)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace


*** Prices (w/o controlling for quantity)

eststo clear
eststo: quietly reg bid_price_log jud ditem* if po_firm_winner==1
eststo: quietly reg bid_price_log jud ditem* dpbu* if po_firm_winner==1
eststo: quietly reg bid_price_log jud ditem* dpbu* pregao if po_firm_winner==1
eststo: quietly reg bid_price_log jud ditem* dpbu* dyear* dmonth* pregao if po_firm_winner==1
esttab using prices_no_quantity.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* dmonth* _cons) label title(Effect of Litigation on Prices (Dep. Var.: Log Prices)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace

*** Prices (controlling for quantity)

eststo clear
eststo: quietly reg bid_price_log jud bid_qty_log ditem* if po_firm_winner==1
eststo: quietly reg bid_price_log jud bid_qty_log ditem* dpbu* if po_firm_winner==1
eststo: quietly reg bid_price_log jud bid_qty_log ditem* dpbu* pregao if po_firm_winner==1
eststo: quietly reg bid_price_log jud bid_qty_log ditem* dpbu* dyear* dmonth* pregao if po_firm_winner==1
esttab using prices_quantity_contr.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* dmonth* _cons) label title(Effect of Litigation on Prices (Dep. Var.: Log Prices)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace


*** Quantities

eststo clear
eststo: quietly reg bid_qty_log jud ditem* if po_firm_winner==1
eststo: quietly reg bid_qty_log jud ditem* dpbu* if po_firm_winner==1
eststo: quietly reg bid_qty_log jud ditem* dpbu* pregao if po_firm_winner==1
eststo: quietly reg bid_qty_log jud ditem* dpbu* dyear* dmonth* pregao if po_firm_winner==1
esttab using quantity.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* dmonth* _cons) label title(Effect of Litigation on Quantity (Dep. Var.: Log Quantity)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace




* 2) DECOMPOSING EFFECTS: INVERSE BULK AND STRICT LIABILITY EFFECTS


* Isolating STRICT LIABILITY EFFECT (SAME QUANTITY, DIFFERENCE WILL BE STE)


** Inputing Data: using standard puchases behavior to make out-of-sample inference about quantity and reserve prices


*** Quantities

drop fitted_bid_qty_log fitted_bid_qty_log_2 fitted_bid_qty_log_3 fitted_bid_qty_log_4 fitted_bid_qty_log_5 fitted_bid_qty_log_6
eststo clear
eststo: reg bid_qty_log  ditem* dpbu* dyear* pregao sp_city if po_firm_winner==1 & jud==0
esttab using quantity_fitted.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* _cons) label title(Fitting Quantities for Litigated Bids) indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2") compress  replace
predict fitted_bid_qty_log
replace fitted_bid_qty_log=bid_qty_log if jud==0
gen fitted_bid_qty_log_2=fitted_bid_qty_log^2
gen fitted_bid_qty_log_3=fitted_bid_qty_log^3
gen fitted_bid_qty_log_4=fitted_bid_qty_log^4
gen fitted_bid_qty_log_5=fitted_bid_qty_log^5
gen fitted_bid_qty_log_6=fitted_bid_qty_log^6

*** Reserve Prices

drop fitted_bid_price_ref_log
eststo clear
eststo: reg bid_price_ref_log  fitted_bid_qty_log fitted_bid_qty_log_2 fitted_bid_qty_log_3 fitted_bid_qty_log_4 fitted_bid_qty_log_5 fitted_bid_qty_log_6 ditem* dpbu* dyear* pregao sp_city if po_firm_winner==1 & jud==0
esttab using quantity_fitted.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* _cons) label title(Fitting Quantities for Litigated Bids) indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2") compress  replace
predict fitted_bid_price_ref_log
replace fitted_bid_price_ref_log=bid_price_ref_log if jud==0


********* Estimating Strict Liabilities Effect

eststo clear
eststo: quietly reg fitted_bid_price_ref_log jud ditem* if po_firm_winner==1
eststo: quietly reg fitted_bid_price_ref_log jud ditem* dpbu* if po_firm_winner==1
eststo: quietly reg fitted_bid_price_ref_log jud ditem* dpbu* dyear* if po_firm_winner==1
eststo: quietly reg fitted_bid_price_ref_log jud ditem* dpbu* dyear* sp_city if po_firm_winner==1
eststo: quietly reg fitted_bid_price_ref_log jud ditem* dpbu* dyear* pregao if po_firm_winner==1
eststo: quietly reg fitted_bid_price_ref_log jud ditem* dpbu* dyear* pregao sp_city if po_firm_winner==1
esttab using strict_liability.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* _cons) label title(Strict Liability Effect (Dep. Variable: Log Fitted Reserve Price)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2") compress  replace








special_strategic hospitals



* 1) TOTAL EFFECT (ONLY PREGAO)

preserve

global controls1 ditem* special_strategic
global controls2 ditem* dpbu_code* 
global controls3 ditem* dpbu_code* special_strategic dyear* dmonth*

global controls4 dpbu_code* dm_y* 
global controls5 dpbu_code* dm_y* special_strategic

global show jud_adm

*** Success / Failure

*** Plain Model

eststo clear

eststo: quietly logit po_firm_winner jud_adm $controls2  if po_proc_code==3
eststo: quietly logit po_firm_winner jud_adm $controls2  dyear* dmonth* if po_proc_code==3
*eststo: quietly logit po_firm_winner jud_adm $controls2  bid_price_ref_log if po_proc_code==3
*eststo: quietly logit po_firm_winner jud_adm $controls2  bid_price_ref_log dyear* dmonth* if po_proc_code==3
esttab using success_fail_raw.rtf, b(%9.4f) se(%9.4f) keep($show) title(Successful/Fail Bids (Dep. Var: Successful Bid or Not)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2") compress  replace

// *** Marginal Effects
//
// eststo clear
// quietly logit po_firm_winner jud_adm ditem* if po_proc_code==3
// eststo: margins, dydx(*) 
// quietly logit po_firm_winner jud_adm ditem* dpbu* if po_proc_code==3
// eststo: margins, dydx(*) 
// quietly logit po_firm_winner jud_adm ditem* dpbu* dyear* dmonth* if po_proc_code==3
// eststo: margins, dydx(*) 
// esttab using success_fail_margins.rtf, b(%9.4f) se(%9.4f) drop(ditem* dpbu* dyear* dmonth* _cons) label title(Standard vs. Litigated Purchases (Dep. Var: Successful Bid or Not)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace


*** Reserve Prices (w/o controlling for quantity)
eststo clear
eststo: quietly reg bid_price_ref_log jud_adm $controls1 if po_firm_winner==1 & po_proc_code==3
eststo: quietly reg bid_price_ref_log jud_adm $controls2 if po_firm_winner==1 & po_proc_code==3
eststo: quietly reg bid_price_ref_log jud_adm $controls3 if po_firm_winner==1 & po_proc_code==3
iis item_id
eststo: quietly xtreg bid_price_ref_log jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3, fe
*eststo: quietly xtreg bid_price_ref_log jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3, fe vce(robust)
esttab using res_prices_no_quantity.rtf, b(%9.4f) se(%9.4f) ar2 keep($show) title(Effect of Litigation on Reserve Prices (Dep. Var.: Log Reserve Prices)) mtitles("OLS" "OLS" "OLS" "Fixed Effects") indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2" "Time Trend = dm_y*") compress  replace


*** Prices (w/o controlling for quantity)

eststo clear
eststo: quietly reg bid_price_log jud_adm $controls1 if po_firm_winner==1 & po_proc_code==3
eststo: quietly reg bid_price_log jud_adm $controls2 if po_firm_winner==1 & po_proc_code==3
eststo: quietly reg bid_price_log jud_adm $controls3 if po_firm_winner==1 & po_proc_code==3
iis item_id
eststo: quietly xtreg bid_price_log jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3, fe
esttab using prices_no_quantity.rtf, b(%9.4f) se(%9.4f) ar2 keep($show) title(Effect of Litigation on Prices (Dep. Var.: Log Prices)) mtitles("OLS" "OLS" "OLS" "Fixed Effects") indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2" "Time Trend = dm_y2") compress  replace


*** Quantities

eststo clear
eststo: quietly reg bid_qty_log jud_adm $controls1 if po_firm_winner==1 & po_proc_code==3
eststo: quietly reg bid_qty_log jud_adm $controls2 if po_firm_winner==1 & po_proc_code==3
eststo: quietly reg bid_qty_log jud_adm $controls3 if po_firm_winner==1 & po_proc_code==3
iis item_id
eststo: quietly xtreg bid_qty_log jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3, fe
esttab using quantity.rtf, b(%9.4f) se(%9.4f) ar2 keep($show) title(Effect of Litigation on Quantity (Dep. Var.: Log Quantity)) mtitles("OLS" "OLS" "OLS" "Fixed Effects") indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2" "Time Trend = dm_y2") compress  replace




* 2) DECOMPOSING EFFECTS: INVERSE BULK AND STRICT LIABILITY EFFECTS


* Isolating STRICT LIABILITY EFFECT (SAME QUANTITY, DIFFERENCE WILL BE STE)


** Inputing Data: using standard puchases behavior to make out-of-sample inference about quantity and reserve prices


*** Quantities (Panel)

drop fitted_bid_qty_log_panel fitted_bid_qty_log_2_panel fitted_bid_qty_log_3_panel fitted_bid_qty_log_4_panel fitted_bid_qty_log_5_panel fitted_bid_qty_log_6_panel
eststo clear
iis item_id
eststo: quietly xtreg bid_qty_log $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
esttab using quantity_fitted_panel.rtf, b(%9.4f) se(%9.4f) ar2  title(Fitting Quantities for Litigated Bids) indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace
predict fitted_bid_qty_log_panel
replace fitted_bid_qty_log_panel=bid_qty_log if jud_adm==0
gen fitted_bid_qty_log_2_panel=fitted_bid_qty_log_panel^2
gen fitted_bid_qty_log_3_panel=fitted_bid_qty_log_panel^3
gen fitted_bid_qty_log_4_panel=fitted_bid_qty_log_panel^4
gen fitted_bid_qty_log_5_panel=fitted_bid_qty_log_panel^5
gen fitted_bid_qty_log_6_panel=fitted_bid_qty_log_panel^6

global fitted_qty fitted_bid_qty_log_panel fitted_bid_qty_log_2_panel fitted_bid_qty_log_3_panel fitted_bid_qty_log_4_panel fitted_bid_qty_log_5_panel fitted_bid_qty_log_6_panel


*** Reserve Prices (Panel)

drop  fitted_bid_price_ref_order_6 fitted_bid_price_ref_order_5 fitted_bid_price_ref_order_4 fitted_bid_price_ref_order_3 fitted_bid_price_ref_order_2
eststo clear
iis item_id

eststo: quietly xtreg bid_price_ref_log fitted_bid_qty_log_panel fitted_bid_qty_log_2_panel $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
predict fitted_bid_price_ref_order_2

eststo: quietly xtreg bid_price_ref_log fitted_bid_qty_log_panel fitted_bid_qty_log_2_panel fitted_bid_qty_log_3_panel $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
predict fitted_bid_price_ref_order_3

eststo: quietly xtreg bid_price_ref_log fitted_bid_qty_log_panel fitted_bid_qty_log_2_panel fitted_bid_qty_log_3_panel fitted_bid_qty_log_4_panel $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
predict fitted_bid_price_ref_order_4

eststo: quietly xtreg bid_price_ref_log fitted_bid_qty_log_panel fitted_bid_qty_log_2_panel fitted_bid_qty_log_3_panel fitted_bid_qty_log_4_panel fitted_bid_qty_log_5_panel $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
predict fitted_bid_price_ref_order_5

eststo: quietly xtreg bid_price_ref_log $fitted_qty $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
predict fitted_bid_price_ref_order_6

esttab using res_prices_fitted_panel.rtf, b(%9.4f) se(%9.4f) ar2 title(Fitting Quantities for Litigated Bids) indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace




********* Estimating Strict Liabilities Effect (Panel)

eststo clear
iis item_id
eststo: quietly xtreg fitted_bid_price_ref_order_2 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fitted_bid_price_ref_order_3 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fitted_bid_price_ref_order_4 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fitted_bid_price_ref_order_5 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fitted_bid_price_ref_order_6 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3


esttab using strict_liability_panel.rtf, b(%9.4f) se(%9.4f) keep($show) title(Strict Liability Effect (Dep. Variable: Log Fitted Reserve Price)) mtitles("Order 2" "Order 3" "Order 4" "Order 5" "Order 6") indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace



eststo clear

quietly: xtreg bid_price_ref_log jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3, fe
est sto FE

quietly: xtreg bid_price_ref_log jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
est sto RE

*hausman FE RE, sigmamore //ordem importa; primeiro o q achamos eficiente

hausman FE RE, sigmaless




twoway__histogram_gen bid_price_ref_log if jud_adm ==1, frequency gen(h0 x0)

twoway__histogram_gen fitted_bid_price_ref_log if jud_adm ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Observed" 2 "Fitted") col(1) pos(1) ring(0))




*** Decomposing effects (2nd choice)
gen qty_2=bid_qty_log^2
gen qty_3=bid_qty_log^3
gen qty_4=bid_qty_log^4
gen qty_5=bid_qty_log^5
gen qty_6=bid_qty_log^6

drop reserve_price_hat
eststo clear
xtset item_id

eststo: quietly xtreg bid_price_ref_log bid_qty_log qty_2 qty_3 qty_4 qty_5 qty_6 $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
esttab using quantity_price_ref_fitted.rtf, b(%9.4f) se(%9.4f) ar2  title(Fitting Quantities for Litigated Bids) indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace

eststo clear
predict reserve_price_hat
eststo: quietly xtreg reserve_price_hat jud_adm if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg reserve_price_hat jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3

replace reserve_price_hat=bid_price_ref_log if jud_adm==0
eststo: quietly xtreg reserve_price_hat jud_adm if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg reserve_price_hat jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
esttab using watchdog_effect.rtf, b(%9.4f) se(%9.4f) ar2  title(Watchdog Effect) indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace





*** Decomposing effects (3rd choice)

* 2) DECOMPOSING EFFECTS: INVERSE BULK AND STRICT LIABILITY EFFECTS - ALTERNATIVE


* Isolating STRICT LIABILITY EFFECT (SAME QUANTITY, DIFFERENCE WILL BE STE)


** Inputing Data: using standard puchases behavior to make out-of-sample inference about quantity and reserve prices


*** Quantities (Panel) - Inference from Standard to Litigated (on average, how it would have been purchased in a Litigated purchase if it was a Standard Purchase)

gen bid_qty_log2=bid_qty_log^2
gen bid_qty_log3=bid_qty_log^3
gen bid_qty_log4=bid_qty_log^4
gen bid_qty_log5=bid_qty_log^5
gen bid_qty_log6=bid_qty_log^6



drop fit_qty_watch* aux_bid_qty_log*



gen aux_bid_qty_log=bid_qty_log
gen aux_bid_qty_log2=bid_qty_log2
gen aux_bid_qty_log3=bid_qty_log3
gen aux_bid_qty_log4=bid_qty_log4
gen aux_bid_qty_log5=bid_qty_log5
gen aux_bid_qty_log6=bid_qty_log6

global qty6 aux_bid_qty_log aux_bid_qty_log2 aux_bid_qty_log3 aux_bid_qty_log4 aux_bid_qty_log5 aux_bid_qty_log6
global qty5 aux_bid_qty_log aux_bid_qty_log2 aux_bid_qty_log3 aux_bid_qty_log4 aux_bid_qty_log5
global qty4 aux_bid_qty_log aux_bid_qty_log2 aux_bid_qty_log3 aux_bid_qty_log4
global qty3 aux_bid_qty_log aux_bid_qty_log2 aux_bid_qty_log3
global qty2 aux_bid_qty_log aux_bid_qty_log2
global qty1 aux_bid_qty_log

eststo clear
xtset item_id
eststo: quietly xtreg bid_qty_log $controls4 if po_firm_winner==1 & jud_adm==0 & po_proc_code==3
esttab using quantity_fitted_for_jud_1.rtf, b(%9.4f) se(%9.4f) ar2  title(Fitting Quantities for Litigated Bids) indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace
predict fit_qty_watch
replace fit_qty_watch=bid_qty_log if jud_adm==0
gen fit_qty_watch2=fit_qty_watch^2
gen fit_qty_watch3=fit_qty_watch^3
gen fit_qty_watch4=fit_qty_watch^4
gen fit_qty_watch5=fit_qty_watch^5
gen fit_qty_watch6=fit_qty_watch^6

global fqty6 fit_qty_watch fit_qty_watch2 fit_qty_watch3 fit_qty_watch4 fit_qty_watch5 fit_qty_watch6
global fqty5 fit_qty_watch fit_qty_watch2 fit_qty_watch3 fit_qty_watch4 fit_qty_watch5
global fqty4 fit_qty_watch fit_qty_watch2 fit_qty_watch3 fit_qty_watch4
global fqty3 fit_qty_watch fit_qty_watch2 fit_qty_watch3
global fqty2 fit_qty_watch fit_qty_watch2
global fqty1 fit_qty_watch  


*** Reserve Prices (Panel) - Using price-quantity relation when jud_adm=1 using fitted_qty if it would be jud_adm=0

eststo clear
xtset item_id

drop fit_price_ref*

eststo: quietly xtreg bid_price_ref_log $qty2 $controls4 if po_firm_winner==1 & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch if jud_adm==1
replace aux_bid_qty_log2=fit_qty_watch2 if jud_adm==1
replace aux_bid_qty_log3=fit_qty_watch3 if jud_adm==1
replace aux_bid_qty_log4=fit_qty_watch4 if jud_adm==1
replace aux_bid_qty_log5=fit_qty_watch5 if jud_adm==1
replace aux_bid_qty_log6=fit_qty_watch6 if jud_adm==1

predict fit_price_ref2

*replace fit_price_ref2=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log if jud_adm==1
replace aux_bid_qty_log2=bid_qty_log2 if jud_adm==1
replace aux_bid_qty_log3=bid_qty_log3 if jud_adm==1
replace aux_bid_qty_log4=bid_qty_log4 if jud_adm==1
replace aux_bid_qty_log5=bid_qty_log5 if jud_adm==1
replace aux_bid_qty_log6=bid_qty_log6 if jud_adm==1


eststo: quietly xtreg bid_price_ref_log $qty3 $controls4 if po_firm_winner==1 & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch if jud_adm==1
replace aux_bid_qty_log2=fit_qty_watch2 if jud_adm==1
replace aux_bid_qty_log3=fit_qty_watch3 if jud_adm==1
replace aux_bid_qty_log4=fit_qty_watch4 if jud_adm==1
replace aux_bid_qty_log5=fit_qty_watch5 if jud_adm==1
replace aux_bid_qty_log6=fit_qty_watch6 if jud_adm==1

predict fit_price_ref3

*replace fit_price_ref3=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log if jud_adm==1
replace aux_bid_qty_log2=bid_qty_log2 if jud_adm==1
replace aux_bid_qty_log3=bid_qty_log3 if jud_adm==1
replace aux_bid_qty_log4=bid_qty_log4 if jud_adm==1
replace aux_bid_qty_log5=bid_qty_log5 if jud_adm==1
replace aux_bid_qty_log6=bid_qty_log6 if jud_adm==1


eststo: quietly xtreg bid_price_ref_log $qty4 $controls4 if po_firm_winner==1  & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch if jud_adm==1
replace aux_bid_qty_log2=fit_qty_watch2 if jud_adm==1
replace aux_bid_qty_log3=fit_qty_watch3 if jud_adm==1
replace aux_bid_qty_log4=fit_qty_watch4 if jud_adm==1
replace aux_bid_qty_log5=fit_qty_watch5 if jud_adm==1
replace aux_bid_qty_log6=fit_qty_watch6 if jud_adm==1

predict fit_price_ref4

*replace fit_price_ref4=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log if jud_adm==1
replace aux_bid_qty_log2=bid_qty_log2 if jud_adm==1
replace aux_bid_qty_log3=bid_qty_log3 if jud_adm==1
replace aux_bid_qty_log4=bid_qty_log4 if jud_adm==1
replace aux_bid_qty_log5=bid_qty_log5 if jud_adm==1
replace aux_bid_qty_log6=bid_qty_log6 if jud_adm==1


eststo: quietly xtreg bid_price_ref_log $qty5 $controls4 if po_firm_winner==1  & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch if jud_adm==1
replace aux_bid_qty_log2=fit_qty_watch2 if jud_adm==1
replace aux_bid_qty_log3=fit_qty_watch3 if jud_adm==1
replace aux_bid_qty_log4=fit_qty_watch4 if jud_adm==1
replace aux_bid_qty_log5=fit_qty_watch5 if jud_adm==1
replace aux_bid_qty_log6=fit_qty_watch6 if jud_adm==1

predict fit_price_ref5

*replace fit_price_ref5=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log if jud_adm==1
replace aux_bid_qty_log2=bid_qty_log2 if jud_adm==1
replace aux_bid_qty_log3=bid_qty_log3 if jud_adm==1
replace aux_bid_qty_log4=bid_qty_log4 if jud_adm==1
replace aux_bid_qty_log5=bid_qty_log5 if jud_adm==1
replace aux_bid_qty_log6=bid_qty_log6 if jud_adm==1


eststo: quietly xtreg bid_price_ref_log $qty6 $controls4 if po_firm_winner==1  & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch if jud_adm==1
replace aux_bid_qty_log2=fit_qty_watch2 if jud_adm==1
replace aux_bid_qty_log3=fit_qty_watch3 if jud_adm==1
replace aux_bid_qty_log4=fit_qty_watch4 if jud_adm==1
replace aux_bid_qty_log5=fit_qty_watch5 if jud_adm==1
replace aux_bid_qty_log6=fit_qty_watch6 if jud_adm==1

predict fit_price_ref6

*replace fit_price_ref6=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log if jud_adm==1
replace aux_bid_qty_log2=bid_qty_log2 if jud_adm==1
replace aux_bid_qty_log3=bid_qty_log3 if jud_adm==1
replace aux_bid_qty_log4=bid_qty_log4 if jud_adm==1
replace aux_bid_qty_log5=bid_qty_log5 if jud_adm==1
replace aux_bid_qty_log6=bid_qty_log6 if jud_adm==1

esttab using price_ALT_FITTED.rtf, b(%9.4f) se(%9.4f) ar2 keep($qty6) title(Fitting Prices for Litigated Bids) indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace



********* Estimating Strict Liabilities Effect (Panel)

eststo clear
xtset item_id
// eststo: quietly xtreg fit_price_ref2 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
// eststo: quietly xtreg fit_price_ref3 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
// eststo: quietly xtreg fit_price_ref4 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
// eststo: quietly xtreg fit_price_ref5 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3
// eststo: quietly xtreg fit_price_ref6 jud_adm $controls4 if po_firm_winner==1 & po_proc_code==3

eststo: quietly xtreg fit_price_ref2 jud_adm dm_y* dpbu_code* if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fit_price_ref3 jud_adm dm_y* dpbu_code* if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fit_price_ref4 jud_adm dm_y* dpbu_code* if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fit_price_ref5 jud_adm dm_y* dpbu_code* if po_firm_winner==1 & po_proc_code==3
eststo: quietly xtreg fit_price_ref6 jud_adm dm_y* dpbu_code* if po_firm_winner==1 & po_proc_code==3


*esttab using watchdog_effect_FINAL.rtf, b(%9.4f) se(%9.4f) keep(jud_adm) title(Strict Liability Effect (Dep. Variable: Log Fitted Reserve Price)) mtitles("Order 2" "Order 3" "Order 4" "Order 5" "Order 6") indicate("PBU = dpbu_code2" "Time Trend = dm_y2") compress  replace
esttab using watchdog_effect_FINAL.rtf, b(%9.4f) se(%9.4f) keep(jud_adm) title(Strict Liability Effect (Dep. Variable: Log Fitted Reserve Price)) mtitles("Order 2" "Order 3" "Order 4" "Order 5" "Order 6")  compress  replace

