********************************************************************************
* Regressions with Clustered Standard Errors
* Paper: Bitter Pills to Swallow
* Suggestion 3: Cluster SE at PBU level + robustness at item level
* Uses reghdfe for efficient multi-way FE estimation
********************************************************************************

clear all
set more off
set max_memory 14g

timer clear
timer on 1

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

* --------------------------------------------------------------------------
* 1. Setup: variables and sample
* --------------------------------------------------------------------------
gen purchase_type = 0
replace purchase_type = 1 if adm == 2
replace purchase_type = 2 if jud == 1

keep if po_proc_code == 3

bysort item: egen has_litigated = max(purchase_type == 2)
bysort item: egen has_ordinary = max(purchase_type == 0)
keep if has_litigated == 1 & has_ordinary == 1

gen urgent = (purchase_type > 0)

capture drop bid_qty_log bid_price_ref_log bid_price_log
gen bid_qty_log = ln(bid_qty)
gen bid_price_ref_log = ln(bid_price_ref)
gen bid_price_log = ln(bid_price)
gen ln_n_firms = ln(n_firms_bids)

capture gen sp_city = 0
capture replace sp_city = 1 if pbu_city_descr == "SAO PAULO"

capture drop pregao
gen pregao = 1

* Create numeric identifiers for reghdfe
encode item, gen(item_id2)
encode pbu_code, gen(pbu_id)
* Use m_y directly as year-month identifier
rename m_y ym

di "Sample size: " _N
di "Unique items: "
tab item_id2 if _n == 1, nofreq
quietly tab item_id2
di r(r) " unique items"
quietly tab pbu_id
di r(r) " unique PBUs"

* Output directory
local outdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v2/analysis/results"
capture mkdir "`outdir'"

********************************************************************************
* TABLE 4: REFERENCE PRICES — Urgent vs. Ordinary
********************************************************************************
di ""
di "==========================================="
di "  TABLE 4: REFERENCE PRICES"
di "==========================================="

eststo clear

* (1) Item FE, cluster PBU
eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

* (2) Item + Year FE, cluster PBU
eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

* (3) Item + Year + PBU FE, cluster PBU
eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

* (4) Item + Year-Month + PBU FE, cluster PBU
eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table4_ref_prices_cluster_pbu.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 4: Reference Prices — Clustered SE at PBU Level") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* Robustness: cluster at item level
eststo clear

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster item_id2)

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster item_id2)

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster item_id2)

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster item_id2)

esttab using "`outdir'/table4_ref_prices_cluster_item.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 4: Reference Prices — Clustered SE at Item Level") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at item level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* Two-way clustering: PBU and item
eststo clear

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id item_id2)

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id item_id2)

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id item_id2)

eststo: reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id item_id2)

esttab using "`outdir'/table4_ref_prices_cluster_twoway.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 4: Reference Prices — Two-way Clustered SE (PBU x Item)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors two-way clustered at PBU and item level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 5: QUANTITIES — Urgent vs. Ordinary
********************************************************************************
di ""
di "==========================================="
di "  TABLE 5: QUANTITIES"
di "==========================================="

eststo clear

eststo: reghdfe bid_qty_log urgent if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe bid_qty_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe bid_qty_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe bid_qty_log urgent if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table5_quantities_cluster_pbu.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 5: Quantities — Clustered SE at PBU Level") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 6: NEGOTIATED PRICES — Urgent vs. Ordinary (with quantity control)
********************************************************************************
di ""
di "==========================================="
di "  TABLE 6: NEGOTIATED PRICES"
di "==========================================="

eststo clear

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table6_neg_prices_cluster_pbu.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 6: Negotiated Prices — Clustered SE at PBU Level") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 7: PARTICIPANT FIRMS — Urgent vs. Ordinary
********************************************************************************
di ""
di "==========================================="
di "  TABLE 7: PARTICIPANT FIRMS"
di "==========================================="

eststo clear

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table7_firms_cluster_pbu.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 7: Participant Firms — Clustered SE at PBU Level") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 9: SUCCESS/FAILURE — Urgent vs. Ordinary (Logit)
********************************************************************************
di ""
di "==========================================="
di "  TABLE 9: SUCCESS/FAILURE (Logit)"
di "==========================================="

eststo clear

eststo: logit po_firm_winner urgent bid_qty_log i.item_id2, ///
    vce(cluster pbu_id) nolog

eststo: logit po_firm_winner urgent bid_qty_log i.item_id2 i.year, ///
    vce(cluster pbu_id) nolog

eststo: logit po_firm_winner urgent bid_qty_log i.item_id2 i.year i.pbu_id, ///
    vce(cluster pbu_id) nolog

esttab using "`outdir'/table9_success_cluster_pbu.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(urgent bid_qty_log) ///
    title("Table 9: Successful Tenders (Logit) — Clustered SE at PBU Level") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU") ///
    indicate("Item FE = *.item_id2" "Year FE = *.year" "PBU FE = *.pbu_id") ///
    note("Standard errors clustered at PBU level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 10: "UNDER THE GUN" — Litigated vs. Administrative
********************************************************************************
di ""
di "==========================================="
di "  TABLE 10: UNDER THE GUN EFFECT"
di "==========================================="

* Restrict to urgent purchases only
preserve
keep if purchase_type == 1 | purchase_type == 2

* Admin dummy: 1 = admin, 0 = litigated
gen is_admin = (purchase_type == 1)

* Need items with at least one admin and one litigated
bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1

di "Under the Gun sample: " _N

eststo clear

* Cluster PBU
eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table10_underthegun_cluster_pbu.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 10: Under the Gun Effect — Clustered SE at PBU Level") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. Admin=1 if administrative, 0 if litigated. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* Robustness: two-way clustering
eststo clear

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id item_id2)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id item_id2)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id item_id2)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id item_id2)

esttab using "`outdir'/table10_underthegun_cluster_twoway.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 10: Under the Gun — Two-way Clustered SE (PBU x Item)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors two-way clustered at PBU and item level in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

restore


********************************************************************************
* COMPARISON TABLE: Original SE vs Clustered SE for key coefficients
********************************************************************************
di ""
di "==========================================="
di "  COMPARISON: Original vs Clustered SE"
di "==========================================="

* Table 4 spec (3): Reference prices, Item+Year+PBU FE
di "--- Table 4 (Reference Prices) ---"
di "Original (no cluster):"
quietly reghdfe bid_price_ref_log urgent if po_firm_winner==1, absorb(item_id2 year pbu_id)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

di "Cluster PBU:"
quietly reghdfe bid_price_ref_log urgent if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

di "Cluster Item:"
quietly reghdfe bid_price_ref_log urgent if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster item_id2)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

di "Two-way (PBU x Item):"
quietly reghdfe bid_price_ref_log urgent if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id item_id2)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

* Table 6 spec (3): Negotiated prices, Item+Year+PBU FE
di ""
di "--- Table 6 (Negotiated Prices) ---"
di "Original (no cluster):"
quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

di "Cluster PBU:"
quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

di "Two-way (PBU x Item):"
quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id item_id2)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

* Table 10: Under the Gun
di ""
di "--- Table 10 (Under the Gun) ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
gen is_admin = (purchase_type == 1)
bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1

di "Original (no cluster):"
quietly reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id)
di "  admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

di "Cluster PBU:"
quietly reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "  admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

di "Two-way (PBU x Item):"
quietly reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id item_id2)
di "  admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

restore

timer off 1
timer list
di ""
di "All tables saved to: v2/analysis/results/"
