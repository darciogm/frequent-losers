* Winsorization Sensitivity — All Main Tables (4-10)
*
* Runs Tables 4-10 under three outlier treatments:
*   Panel A: No winsorization
*   Panel B: Winsorized at 1%/99%
*   Panel C: Winsorized at 5%/95%
*
* All specifications use clustered SE at PBU level (primary)

clear all
set more off
set max_memory 14g

timer clear
timer on 1

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

* 1. Setup (identical to clustered_regressions.do)
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

encode item, gen(item_id2)
encode pbu_code, gen(pbu_id)
rename m_y ym
capture destring year, gen(year_num) force
if _rc != 0 {
    gen year_num = real(year)
}

local outdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v2/analysis/results"
capture mkdir "`outdir'"

di "Full analysis sample: " _N

* Save base sample (before any winsorization)
tempfile full_sample
save `full_sample'


* 2. PROGRAMS

* Winsorize level variables and regenerate logs
capture program drop do_winsorize
program define do_winsorize
    args plo phi
    foreach v in bid_price bid_price_ref bid_qty n_firms_bids {
        quietly summarize `v', detail
        local lo = r(p`plo')
        local hi = r(p`phi')
        replace `v' = `lo' if `v' < `lo' & `v' != .
        replace `v' = `hi' if `v' > `hi' & `v' != .
    }
    capture drop bid_qty_log bid_price_ref_log bid_price_log ln_n_firms
    gen bid_qty_log = ln(bid_qty)
    gen bid_price_ref_log = ln(bid_price_ref)
    gen bid_price_log = ln(bid_price)
    gen ln_n_firms = ln(n_firms_bids)
end

* 4-column reghdfe (Item, Item+Year, Item+Year+PBU, Item+YM+PBU)
capture program drop run_reghdfe4
program define run_reghdfe4
    args pfx depvar controls

    eststo `pfx'1: reghdfe `depvar' `controls' if po_firm_winner==1, ///
        absorb(item_id2) vce(cluster pbu_id)
    eststo `pfx'2: reghdfe `depvar' `controls' if po_firm_winner==1, ///
        absorb(item_id2 year) vce(cluster pbu_id)
    eststo `pfx'3: reghdfe `depvar' `controls' if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    eststo `pfx'4: reghdfe `depvar' `controls' if po_firm_winner==1, ///
        absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
end

* 3-column logit (Item, Item+Year, Item+Year+PBU)
capture program drop run_logit3
program define run_logit3
    args pfx controls

    eststo `pfx'1: logit po_firm_winner `controls' i.item_id2, ///
        vce(cluster pbu_id) nolog
    eststo `pfx'2: logit po_firm_winner `controls' i.item_id2 i.year_num, ///
        vce(cluster pbu_id) nolog
    eststo `pfx'3: logit po_firm_winner `controls' i.item_id2 i.year_num i.pbu_id, ///
        vce(cluster pbu_id) nolog
end


* 3. RUN ALL REGRESSIONS

* PANEL A: NO WINSORIZATION
di "  PANEL A: NO WINSORIZATION"

use `full_sample', clear

di _n "--- Table 4: Reference Prices ---"
run_reghdfe4 t4a bid_price_ref_log "urgent"

di _n "--- Table 5: Quantities ---"
run_reghdfe4 t5a bid_qty_log "urgent"

di _n "--- Table 6a: Negotiated Prices (total) ---"
run_reghdfe4 t6Aa bid_price_log "urgent"

di _n "--- Table 6b: Negotiated Prices (direct) ---"
run_reghdfe4 t6Ba bid_price_log "urgent bid_qty_log"

di _n "--- Table 7a: Participant Firms (total) ---"
run_reghdfe4 t7Aa ln_n_firms "urgent"

di _n "--- Table 7b: Participant Firms (direct) ---"
run_reghdfe4 t7Ba ln_n_firms "urgent bid_qty_log"

di _n "--- Table 9a: Success Logit (total) ---"
run_logit3 t9Aa "urgent"

di _n "--- Table 9b: Success Logit (direct) ---"
run_logit3 t9Ba "urgent bid_qty_log"

di _n "--- Table 10: Under the Gun ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
gen is_admin = (purchase_type == 1)
bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1
di "UTG sample (Panel A): " _N
run_reghdfe4 t10Aa bid_price_log "is_admin"
run_reghdfe4 t10Ba bid_price_log "is_admin bid_qty_log"
restore


* PANEL B: WINSORIZED 1%/99%
di "  PANEL B: WINSORIZED 1%/99%"

use `full_sample', clear
do_winsorize 1 99

di _n "--- Table 4: Reference Prices ---"
run_reghdfe4 t4b bid_price_ref_log "urgent"

di _n "--- Table 5: Quantities ---"
run_reghdfe4 t5b bid_qty_log "urgent"

di _n "--- Table 6a: Negotiated Prices (total) ---"
run_reghdfe4 t6Ab bid_price_log "urgent"

di _n "--- Table 6b: Negotiated Prices (direct) ---"
run_reghdfe4 t6Bb bid_price_log "urgent bid_qty_log"

di _n "--- Table 7a: Participant Firms (total) ---"
run_reghdfe4 t7Ab ln_n_firms "urgent"

di _n "--- Table 7b: Participant Firms (direct) ---"
run_reghdfe4 t7Bb ln_n_firms "urgent bid_qty_log"

di _n "--- Table 9a: Success Logit (total) ---"
run_logit3 t9Ab "urgent"

di _n "--- Table 9b: Success Logit (direct) ---"
run_logit3 t9Bb "urgent bid_qty_log"

di _n "--- Table 10: Under the Gun ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
gen is_admin = (purchase_type == 1)
bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1
di "UTG sample (Panel B): " _N
run_reghdfe4 t10Ab bid_price_log "is_admin"
run_reghdfe4 t10Bb bid_price_log "is_admin bid_qty_log"
restore


* PANEL C: WINSORIZED 5%/95%
di "  PANEL C: WINSORIZED 5%/95%"

use `full_sample', clear
do_winsorize 5 95

di _n "--- Table 4: Reference Prices ---"
run_reghdfe4 t4c bid_price_ref_log "urgent"

di _n "--- Table 5: Quantities ---"
run_reghdfe4 t5c bid_qty_log "urgent"

di _n "--- Table 6a: Negotiated Prices (total) ---"
run_reghdfe4 t6Ac bid_price_log "urgent"

di _n "--- Table 6b: Negotiated Prices (direct) ---"
run_reghdfe4 t6Bc bid_price_log "urgent bid_qty_log"

di _n "--- Table 7a: Participant Firms (total) ---"
run_reghdfe4 t7Ac ln_n_firms "urgent"

di _n "--- Table 7b: Participant Firms (direct) ---"
run_reghdfe4 t7Bc ln_n_firms "urgent bid_qty_log"

di _n "--- Table 9a: Success Logit (total) ---"
run_logit3 t9Ac "urgent"

di _n "--- Table 9b: Success Logit (direct) ---"
run_logit3 t9Bc "urgent bid_qty_log"

di _n "--- Table 10: Under the Gun ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
gen is_admin = (purchase_type == 1)
bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1
di "UTG sample (Panel C): " _N
run_reghdfe4 t10Ac bid_price_log "is_admin"
run_reghdfe4 t10Bc bid_price_log "is_admin bid_qty_log"
restore


* 4. OUTPUT TABLES
di "  WRITING OUTPUT TABLES"

local fe_titles `" "Item FE" "Item+Year" "Item+Year+PBU" "Item+YM+PBU" "'
local fe_note "SE clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1"

* TABLE 4: REFERENCE PRICES
esttab t4a1 t4a2 t4a3 t4a4 using "`outdir'/table4_ref_prices_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 4: Reference Prices — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t4b1 t4b2 t4b3 t4b4 using "`outdir'/table4_ref_prices_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t4c1 t4c2 t4c3 t4c4 using "`outdir'/table4_ref_prices_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') note("`fe_note'") compress append


* TABLE 5: QUANTITIES
esttab t5a1 t5a2 t5a3 t5a4 using "`outdir'/table5_quantities_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 5: Quantities — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t5b1 t5b2 t5b3 t5b4 using "`outdir'/table5_quantities_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t5c1 t5c2 t5c3 t5c4 using "`outdir'/table5_quantities_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') note("`fe_note'") compress append


* TABLE 6A: NEGOTIATED PRICES — TOTAL EFFECT
esttab t6Aa1 t6Aa2 t6Aa3 t6Aa4 using "`outdir'/table6a_neg_prices_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 6A: Negotiated Prices (Total Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t6Ab1 t6Ab2 t6Ab3 t6Ab4 using "`outdir'/table6a_neg_prices_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t6Ac1 t6Ac2 t6Ac3 t6Ac4 using "`outdir'/table6a_neg_prices_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') note("`fe_note'") compress append


* TABLE 6B: NEGOTIATED PRICES — DIRECT EFFECT
esttab t6Ba1 t6Ba2 t6Ba3 t6Ba4 using "`outdir'/table6b_neg_prices_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 6B: Negotiated Prices (Direct Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t6Bb1 t6Bb2 t6Bb3 t6Bb4 using "`outdir'/table6b_neg_prices_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t6Bc1 t6Bc2 t6Bc3 t6Bc4 using "`outdir'/table6b_neg_prices_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') note("`fe_note'") compress append


* TABLE 7A: PARTICIPANT FIRMS — TOTAL EFFECT
esttab t7Aa1 t7Aa2 t7Aa3 t7Aa4 using "`outdir'/table7a_firms_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 7A: Participant Firms (Total Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t7Ab1 t7Ab2 t7Ab3 t7Ab4 using "`outdir'/table7a_firms_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t7Ac1 t7Ac2 t7Ac3 t7Ac4 using "`outdir'/table7a_firms_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') note("`fe_note'") compress append


* TABLE 7B: PARTICIPANT FIRMS — DIRECT EFFECT
esttab t7Ba1 t7Ba2 t7Ba3 t7Ba4 using "`outdir'/table7b_firms_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 7B: Participant Firms (Direct Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t7Bb1 t7Bb2 t7Bb3 t7Bb4 using "`outdir'/table7b_firms_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t7Bc1 t7Bc2 t7Bc3 t7Bc4 using "`outdir'/table7b_firms_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') note("`fe_note'") compress append


* TABLE 9A: SUCCESS LOGIT — TOTAL EFFECT
local logit_titles `" "Item FE" "Item+Year" "Item+Year+PBU" "'

esttab t9Aa1 t9Aa2 t9Aa3 using "`outdir'/table9a_success_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(urgent) ///
    indicate("Item FE = *.item_id2" "Year FE = *.year_num" "PBU FE = *.pbu_id") ///
    title("Table 9A: Success (Logit, Total Effect) — Panel A (No Winsorization)") ///
    mtitles(`logit_titles') note("") compress replace

esttab t9Ab1 t9Ab2 t9Ab3 using "`outdir'/table9a_success_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(urgent) ///
    indicate("Item FE = *.item_id2" "Year FE = *.year_num" "PBU FE = *.pbu_id") ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`logit_titles') note("") compress append

esttab t9Ac1 t9Ac2 t9Ac3 using "`outdir'/table9a_success_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(urgent) ///
    indicate("Item FE = *.item_id2" "Year FE = *.year_num" "PBU FE = *.pbu_id") ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`logit_titles') ///
    note("SE clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress append


* TABLE 9B: SUCCESS LOGIT — DIRECT EFFECT
esttab t9Ba1 t9Ba2 t9Ba3 using "`outdir'/table9b_success_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(urgent bid_qty_log) ///
    indicate("Item FE = *.item_id2" "Year FE = *.year_num" "PBU FE = *.pbu_id") ///
    title("Table 9B: Success (Logit, Direct Effect) — Panel A (No Winsorization)") ///
    mtitles(`logit_titles') note("") compress replace

esttab t9Bb1 t9Bb2 t9Bb3 using "`outdir'/table9b_success_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(urgent bid_qty_log) ///
    indicate("Item FE = *.item_id2" "Year FE = *.year_num" "PBU FE = *.pbu_id") ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`logit_titles') note("") compress append

esttab t9Bc1 t9Bc2 t9Bc3 using "`outdir'/table9b_success_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(urgent bid_qty_log) ///
    indicate("Item FE = *.item_id2" "Year FE = *.year_num" "PBU FE = *.pbu_id") ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`logit_titles') ///
    note("SE clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress append


* TABLE 10A: UNDER THE GUN — TOTAL EFFECT
esttab t10Aa1 t10Aa2 t10Aa3 t10Aa4 using "`outdir'/table10a_underthegun_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 10A: Under the Gun (Total Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t10Ab1 t10Ab2 t10Ab3 t10Ab4 using "`outdir'/table10a_underthegun_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t10Ac1 t10Ac2 t10Ac3 t10Ac4 using "`outdir'/table10a_underthegun_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') ///
    note("is_admin=1 for administrative, 0 for litigated. `fe_note'") ///
    compress append


* TABLE 10B: UNDER THE GUN — DIRECT EFFECT
esttab t10Ba1 t10Ba2 t10Ba3 t10Ba4 using "`outdir'/table10b_underthegun_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 10B: Under the Gun (Direct Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t10Bb1 t10Bb2 t10Bb3 t10Bb4 using "`outdir'/table10b_underthegun_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t10Bc1 t10Bc2 t10Bc3 t10Bc4 using "`outdir'/table10b_underthegun_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') ///
    note("is_admin=1 for administrative, 0 for litigated. `fe_note'") ///
    compress append


* 5. SUMMARY
di "  ALL TABLES WRITTEN"
di ""
di "Output files (each with 3 panels: No Winsor / 1% / 5%):"
di "  table4_ref_prices_winsor.rtf"
di "  table5_quantities_winsor.rtf"
di "  table6a_neg_prices_total_winsor.rtf"
di "  table6b_neg_prices_direct_winsor.rtf"
di "  table7a_firms_total_winsor.rtf"
di "  table7b_firms_direct_winsor.rtf"
di "  table9a_success_total_winsor.rtf"
di "  table9b_success_direct_winsor.rtf"
di "  table10a_underthegun_total_winsor.rtf"
di "  table10b_underthegun_direct_winsor.rtf"

timer off 1
timer list
