use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Papers/BEC_FINAL_DUMMIES_SOURCE.dta" , clear

gen bid_price_log=ln(bid_price)
gen bid_price_ref_log=ln(bid_price_ref)
gen bid_qty_log=ln(bid_qty)

keep if bid_total_ref>=8000 & bid_total_ref<=17600 | bid_total_ref>=80000 & bid_total_ref<=176000
keep if year=="2017" | year=="2018" | year=="2019"


sort m_y
format %9.0g m_y
gen rd_change=1
replace rd_change=0 if m_y>=695 & m_y<=702
tab po_proc_code rd_change
drop if m_y<695

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_THRESHOLDS_2018_2019.dta", replace
