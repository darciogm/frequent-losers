********************************************************************************
* V3 Data Preparation
* Paper: Bitter Pills to Swallow
* Source: BEC_JUD.dta (193K obs — full sample, all auction types)
* Drops DISPENSA (po_proc_code==2), keeps CONVITE + PREGÃO
* Creates all analysis variables, merges subsample info, saves to /tmp
********************************************************************************

clear all
set more off
set max_memory 14g
capture set processors 16

timer clear
timer on 1

* --------------------------------------------------------------------------
* 1. Load full dataset
* --------------------------------------------------------------------------
use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/BEC_JUD.dta", clear

di "Raw dataset loaded: " _N " observations"
tab po_proc_code

* --------------------------------------------------------------------------
* 2. Sample restriction: drop DISPENSA (po_proc_code == 2)
* --------------------------------------------------------------------------
drop if po_proc_code == 2
di "After dropping DISPENSA: " _N " observations"

* --------------------------------------------------------------------------
* 3. Create purchase type categories
* --------------------------------------------------------------------------
gen purchase_type = 0
replace purchase_type = 1 if adm == 2
replace purchase_type = 2 if jud == 1

label define ptype 0 "Ordinary" 1 "Administrative" 2 "Litigated"
label values purchase_type ptype

tab purchase_type

* --------------------------------------------------------------------------
* 4. Create treatment variables
* --------------------------------------------------------------------------
gen urgent = (purchase_type > 0)
label var urgent "1 = Administrative or Litigated"

gen is_admin = (purchase_type == 1)
label var is_admin "1 = Administrative, 0 otherwise"

* --------------------------------------------------------------------------
* 5. Auction type indicator
* --------------------------------------------------------------------------
gen pregao = (po_proc_code == 3)
label var pregao "1 = Pregão (electronic auction)"

* --------------------------------------------------------------------------
* 6. PBU management type
* --------------------------------------------------------------------------
capture confirm variable pbu_type_mgmt_code
if _rc == 0 {
    capture gen type_mgmt = (pbu_type_mgmt_code != "1") if pbu_type_mgmt_code != ""
    if _rc != 0 {
        capture gen type_mgmt = (pbu_type_mgmt_code != 1) if pbu_type_mgmt_code != .
    }
    label var type_mgmt "1 = Non-direct administration"
}

* --------------------------------------------------------------------------
* 7. Create log variables
* --------------------------------------------------------------------------
capture drop bid_qty_log bid_price_ref_log bid_price_log
gen bid_qty_log = ln(bid_qty)
gen bid_price_ref_log = ln(bid_price_ref)
gen bid_price_log = ln(bid_price)
gen ln_n_firms = ln(n_firms_bids)

label var bid_qty_log "Log quantity"
label var bid_price_ref_log "Log reference price"
label var bid_price_log "Log negotiated price"
label var ln_n_firms "Log number of bidding firms"

* --------------------------------------------------------------------------
* 8. Time variables
* --------------------------------------------------------------------------
capture destring year, gen(year_num) force
if _rc != 0 {
    gen year_num = real(year)
}
label var year_num "Numeric year"

* Month from m_y (year-month identifier)
capture gen month = mod(m_y - 1, 12) + 1 if m_y != .
label var month "Calendar month (1-12)"

gen late_period = (year_num >= 2014)
label var late_period "1 = Late period (2014-2019), 0 = Early (2009-2013)"

* --------------------------------------------------------------------------
* 9. Geographic variable
* --------------------------------------------------------------------------
capture gen sp_city = 0
capture replace sp_city = 1 if pbu_city_descr == "SAO PAULO"
label var sp_city "1 = São Paulo capital"

* --------------------------------------------------------------------------
* 10. Create numeric identifiers for reghdfe
* --------------------------------------------------------------------------
encode item, gen(item_id2)
encode pbu_code, gen(pbu_id)
rename m_y ym

* --------------------------------------------------------------------------
* 11. Item-level flags
* --------------------------------------------------------------------------
bysort item: egen has_litigated = max(purchase_type == 2)
bysort item: egen has_ordinary = max(purchase_type == 0)
bysort item: egen has_admin = max(purchase_type == 1)
bysort item: egen has_lit = max(purchase_type == 2)

label var has_litigated "Item has at least one litigated purchase"
label var has_ordinary "Item has at least one ordinary purchase"
label var has_admin "Item has at least one administrative purchase"
label var has_lit "Item has at least one litigated purchase (alias)"

* --------------------------------------------------------------------------
* 12. SUS classification (padronizadosus is already in BEC_JUD.dta)
* --------------------------------------------------------------------------
capture confirm variable padronizadosus
if _rc == 0 {
    gen sus_basic = .
    replace sus_basic = 1 if strpos(padronizadosus, "sico") > 0
    replace sus_basic = 0 if padronizadosus != "" & sus_basic == .
    label var sus_basic "1 = Basic SUS component (only for items with SUS classification)"

    di "SUS component classification:"
    tab sus_basic, missing
    tab padronizadosus if sus_basic != ., missing
}
else {
    gen sus_basic = .
    label var sus_basic "SUS component type (not available)"
    di "WARNING: padronizadosus variable not found in dataset"
}

* --------------------------------------------------------------------------
* 13. Heterogeneity variables
* --------------------------------------------------------------------------

* Competition: item-level median number of bidding firms
bysort item: egen item_med_firms = median(n_firms_bids)
quietly summarize item_med_firms, detail
local overall_med_firms = r(p50)
gen high_competition = (item_med_firms > `overall_med_firms')
label var high_competition "1 = Above-median item-level competition"
di "Median of item-level median firms: `overall_med_firms'"

* PBU size: total transactions per PBU
bysort pbu_code: egen pbu_size = count(pbu_code)
quietly summarize pbu_size, detail
local med_pbu_size = r(p50)
gen large_pbu = (pbu_size > `med_pbu_size')
label var large_pbu "1 = Above-median PBU size (by transaction count)"
di "Median PBU size (transactions): `med_pbu_size'"

* --------------------------------------------------------------------------
* 14. Summary
* --------------------------------------------------------------------------
di ""
di "=================================================================="
di "  V3 DATA PREPARATION COMPLETE"
di "=================================================================="
di "  Total observations: " _N
di "  Unique items: "
quietly tab item_id2
di "    " r(r) " unique items"
quietly tab pbu_id
di "    " r(r) " unique PBUs"
di ""
di "  By purchase type:"
tab purchase_type
di ""
di "  Winners:"
count if po_firm_winner == 1
di "  Items with both litigated and ordinary:"
count if has_litigated == 1 & has_ordinary == 1
di "  Items with both admin and litigated:"
count if has_admin == 1 & has_lit == 1
di ""
tab pregao

* --------------------------------------------------------------------------
* 15. Save prepared dataset
* --------------------------------------------------------------------------
compress
save "/tmp/v3_prepared.dta", replace

timer off 1
timer list
di ""
di "Prepared data saved to: /tmp/v3_prepared.dta"
