*** Decomposing effects (4th choice)

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

replace aux_bid_qty_log=fit_qty_watch 
replace aux_bid_qty_log2=fit_qty_watch2 
replace aux_bid_qty_log3=fit_qty_watch3 
replace aux_bid_qty_log4=fit_qty_watch4 
replace aux_bid_qty_log5=fit_qty_watch5 
replace aux_bid_qty_log6=fit_qty_watch6 

predict fit_price_ref2

*replace fit_price_ref2=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log 
replace aux_bid_qty_log2=bid_qty_log2 
replace aux_bid_qty_log3=bid_qty_log3 
replace aux_bid_qty_log4=bid_qty_log4 
replace aux_bid_qty_log5=bid_qty_log5 
replace aux_bid_qty_log6=bid_qty_log6 


eststo: quietly xtreg bid_price_ref_log $qty3 $controls4 if po_firm_winner==1 & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch 
replace aux_bid_qty_log2=fit_qty_watch2 
replace aux_bid_qty_log3=fit_qty_watch3 
replace aux_bid_qty_log4=fit_qty_watch4 
replace aux_bid_qty_log5=fit_qty_watch5 
replace aux_bid_qty_log6=fit_qty_watch6 

predict fit_price_ref3

*replace fit_price_ref3=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log 
replace aux_bid_qty_log2=bid_qty_log2 
replace aux_bid_qty_log3=bid_qty_log3 
replace aux_bid_qty_log4=bid_qty_log4 
replace aux_bid_qty_log5=bid_qty_log5 
replace aux_bid_qty_log6=bid_qty_log6 


eststo: quietly xtreg bid_price_ref_log $qty4 $controls4 if po_firm_winner==1  & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch 
replace aux_bid_qty_log2=fit_qty_watch2 
replace aux_bid_qty_log3=fit_qty_watch3 
replace aux_bid_qty_log4=fit_qty_watch4 
replace aux_bid_qty_log5=fit_qty_watch5 
replace aux_bid_qty_log6=fit_qty_watch6 

predict fit_price_ref4

*replace fit_price_ref4=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log 
replace aux_bid_qty_log2=bid_qty_log2 
replace aux_bid_qty_log3=bid_qty_log3 
replace aux_bid_qty_log4=bid_qty_log4 
replace aux_bid_qty_log5=bid_qty_log5 
replace aux_bid_qty_log6=bid_qty_log6 


eststo: quietly xtreg bid_price_ref_log $qty5 $controls4 if po_firm_winner==1  & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch 
replace aux_bid_qty_log2=fit_qty_watch2 
replace aux_bid_qty_log3=fit_qty_watch3 
replace aux_bid_qty_log4=fit_qty_watch4 
replace aux_bid_qty_log5=fit_qty_watch5 
replace aux_bid_qty_log6=fit_qty_watch6 

predict fit_price_ref5

*replace fit_price_ref5=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log 
replace aux_bid_qty_log2=bid_qty_log2 
replace aux_bid_qty_log3=bid_qty_log3 
replace aux_bid_qty_log4=bid_qty_log4 
replace aux_bid_qty_log5=bid_qty_log5 
replace aux_bid_qty_log6=bid_qty_log6 


eststo: quietly xtreg bid_price_ref_log $qty6 $controls4 if po_firm_winner==1  & po_proc_code==3 & jud_adm==0

replace aux_bid_qty_log=fit_qty_watch 
replace aux_bid_qty_log2=fit_qty_watch2 
replace aux_bid_qty_log3=fit_qty_watch3 
replace aux_bid_qty_log4=fit_qty_watch4 
replace aux_bid_qty_log5=fit_qty_watch5 
replace aux_bid_qty_log6=fit_qty_watch6 

predict fit_price_ref6

*replace fit_price_ref6=bid_price_ref_log if jud_adm==0

replace aux_bid_qty_log=bid_qty_log 
replace aux_bid_qty_log2=bid_qty_log2 
replace aux_bid_qty_log3=bid_qty_log3 
replace aux_bid_qty_log4=bid_qty_log4 
replace aux_bid_qty_log5=bid_qty_log5 
replace aux_bid_qty_log6=bid_qty_log6 

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

