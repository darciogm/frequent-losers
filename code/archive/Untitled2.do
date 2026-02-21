scatter bid_price po_date_min_YMD if po_date_min_YMD>=21288 & po_date_min_YMD<=21488 & bid_total_ref>=8000 & bid_total_ref<=17600
scatter bid_price po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600
scatter bid_price po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0
scatter bid_price po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==1
scatter bid_price po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==1 & bid_price_ref<=100
scatter bid_price po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==2 & bid_price_ref<=100
scatter bid_price po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==3 & bid_price_ref<=100
scatter bid_total_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0
scatter bid_qty po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & group_item=="65" & bid_qty<=100
scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==3
scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==1
scatter po_date_min_YMD bid_price_ref  if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==1

graph twoway (scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==1) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==2) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==3)

graph twoway (scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==1) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==2) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==3)

graph twoway (scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==1 & group_item=="65") ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==2 & group_item=="65")

graph twoway (scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==1) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==2)




graph twoway (scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==1) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==2) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==3), legend(label(1 "Convite") label(2 "Dispensa") label(3 "Pregão"))

graph twoway (scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==1) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=8000 & bid_total_ref<=17600 & nowinner==0 & po_proc_code==2), legend(label(1 "Convite") label(2 "Dispensa"))



graph twoway (scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==1) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==2) ///
(scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==3), legend(label(1 "Convite") label(2 "Dispensa") label(3 "Pregão"))

scatter bid_price_ref po_date_min_YMD if po_date_min_YMD>=21338 & po_date_min_YMD<=21438 & bid_total_ref>=80000 & bid_total_ref<=176000 & nowinner==0 & po_proc_code==1
