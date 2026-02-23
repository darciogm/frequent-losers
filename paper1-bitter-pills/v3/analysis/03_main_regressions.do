********************************************************************************
* V3 Main Regressions (Tables 4-10)
* Paper: Bitter Pills to Swallow
* Source: /tmp/v3_prepared.dta (full BEC_JUD sample, CONVITE + PREGÃO)
*
* All tables use 4 FE specifications:
*   (1) Item FE
*   (2) Item + Year FE
*   (3) Item + Year + PBU FE
*   (4) Item + Year-Month + PBU FE
*
* Clustering: PBU (primary) + Item + Two-way robustness
********************************************************************************

clear all
set more off
set max_memory 14g
capture set processors 16

timer clear
timer on 1

use "/tmp/v3_prepared.dta", clear

* --------------------------------------------------------------------------
* 1. Restrict to analysis sample: items with both litigated and ordinary
* --------------------------------------------------------------------------
keep if has_litigated == 1 & has_ordinary == 1

di "Analysis sample size: " _N
di "Unique items: "
quietly tab item_id2
di r(r) " unique items"
quietly tab pbu_id
di r(r) " unique PBUs"

* Output directory
local outdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v3/results"


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
* TABLE 6: NEGOTIATED PRICES — Urgent vs. Ordinary
* Panel A: Total effect (without quantity control)
* Panel B: Direct effect (with quantity control)
********************************************************************************
di ""
di "==========================================="
di "  TABLE 6: NEGOTIATED PRICES"
di "==========================================="

* --- Panel A: Total effect ---
eststo clear

eststo: reghdfe bid_price_log urgent if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table6a_neg_prices_total_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 6 Panel A: Negotiated Prices — Total Effect (no quantity control)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. Total effect: quantity not controlled. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* --- Panel B: Direct effect ---
eststo clear

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table6b_neg_prices_direct_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 6 Panel B: Negotiated Prices — Direct Effect (quantity controlled)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. Direct effect: quantity controlled. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 7: PARTICIPANT FIRMS — Urgent vs. Ordinary
* Panel A: Total effect (without quantity control)
* Panel B: Direct effect (with quantity control)
********************************************************************************
di ""
di "==========================================="
di "  TABLE 7: PARTICIPANT FIRMS"
di "==========================================="

* --- Panel A: Total effect ---
eststo clear

eststo: reghdfe ln_n_firms urgent if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table7a_firms_total_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 7 Panel A: Participant Firms — Total Effect (no quantity control)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. Total effect: quantity not controlled. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* --- Panel B: Direct effect ---
eststo clear

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table7b_firms_direct_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 7 Panel B: Participant Firms — Direct Effect (quantity controlled)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. Direct effect: quantity controlled. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 9: SUCCESS/FAILURE — Urgent vs. Ordinary
* Linear Probability Model (LPM) via reghdfe — efficient with multi-way FE
* Panel A: Total effect (without quantity control)
* Panel B: Direct effect (with quantity control)
********************************************************************************
di ""
di "==========================================="
di "  TABLE 9: SUCCESS/FAILURE (LPM)"
di "==========================================="

* --- Panel A: Total effect ---
eststo clear

eststo: reghdfe po_firm_winner urgent, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe po_firm_winner urgent, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe po_firm_winner urgent, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe po_firm_winner urgent, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table9a_success_total_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 9 Panel A: Successful Tenders (LPM) — Total Effect") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Linear probability model. SE clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* --- Panel B: Direct effect ---
eststo clear

eststo: reghdfe po_firm_winner urgent bid_qty_log, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe po_firm_winner urgent bid_qty_log, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe po_firm_winner urgent bid_qty_log, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe po_firm_winner urgent bid_qty_log, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table9b_success_direct_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 9 Panel B: Successful Tenders (LPM) — Direct Effect") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Linear probability model. SE clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1") ///
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

* Need items with at least one admin and one litigated
bysort item: egen has_admin2 = max(is_admin == 1)
bysort item: egen has_lit2 = max(is_admin == 0)
keep if has_admin2 == 1 & has_lit2 == 1

di "Under the Gun sample: " _N

* --- Panel A: Total effect ---
eststo clear

eststo: reghdfe bid_price_log is_admin if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table10a_underthegun_total_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 10 Panel A: Under the Gun — Total Effect (no quantity control)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. Admin=1 if administrative, 0 if litigated. Total effect: quantity not controlled. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* --- Panel B: Direct effect ---
eststo clear

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

eststo: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

esttab using "`outdir'/table10b_underthegun_direct_effect.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 10 Panel B: Under the Gun — Direct Effect (quantity controlled)") ///
    mtitles("Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU") ///
    note("Standard errors clustered at PBU level in parentheses. Admin=1 if administrative, 0 if litigated. Direct effect: quantity controlled. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* Robustness: two-way clustering (with quantity control)
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
di "Total effect (no qty control), Cluster PBU:"
quietly reghdfe bid_price_log urgent if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

di "Direct effect (qty controlled), Cluster PBU:"
quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

di "Direct effect (qty controlled), Two-way (PBU x Item):"
quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id item_id2)
di "  urgent = " %9.4f _b[urgent] "  SE = " %9.4f _se[urgent]

* Table 10: Under the Gun
di ""
di "--- Table 10 (Under the Gun) ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
bysort item: egen has_admin2 = max(is_admin == 1)
bysort item: egen has_lit2 = max(is_admin == 0)
keep if has_admin2 == 1 & has_lit2 == 1

di "Total effect (no qty control), Cluster PBU:"
quietly reghdfe bid_price_log is_admin if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "  admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

di "Direct effect (qty controlled), Cluster PBU:"
quietly reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "  admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

di "Direct effect (qty controlled), Two-way (PBU x Item):"
quietly reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, absorb(item_id2 year pbu_id) vce(cluster pbu_id item_id2)
di "  admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

restore

timer off 1
timer list
di ""
di "All tables saved to: v3/results/"
