* V3 Robustness: UTG Progressive Controls + All-Table Winsorization Sensitivity
* Source: /tmp/v3_prepared.dta (full BEC_JUD sample, CONVITE + PREGÃO)
*
* PART A: Under the Gun with progressive controls × 3 winsorization panels
* PART B: All main tables (4-10) × 3 winsorization levels

clear all
set more off
set max_memory 14g
capture set processors 16

timer clear
timer on 1

use "/tmp/v3_prepared.dta", clear

* 1. Restrict to analysis sample
keep if has_litigated == 1 & has_ordinary == 1

local outdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v3/results"

di "Full analysis sample: " _N

* Save base sample (before any winsorization)
tempfile full_sample
save `full_sample'


* PROGRAMS

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

* 4-column LPM via reghdfe (same FE structure as other tables)
capture program drop run_lpm4
program define run_lpm4
    args pfx controls

    eststo `pfx'1: reghdfe po_firm_winner `controls', ///
        absorb(item_id2) vce(cluster pbu_id)
    eststo `pfx'2: reghdfe po_firm_winner `controls', ///
        absorb(item_id2 year) vce(cluster pbu_id)
    eststo `pfx'3: reghdfe po_firm_winner `controls', ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    eststo `pfx'4: reghdfe po_firm_winner `controls', ///
        absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
end

* UTG progressive controls (5 columns)
capture program drop run_progressive
program define run_progressive
    args prefix

    * (1) Baseline: is_admin only
    eststo `prefix'1: reghdfe bid_price_log is_admin if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (1) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

    * (2) + Quantity
    eststo `prefix'2: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (2) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

    * (3) + Reference price
    eststo `prefix'3: reghdfe bid_price_log is_admin bid_qty_log bid_price_ref_log if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (3) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

    * (4) + Competition (ln firms)
    eststo `prefix'4: reghdfe bid_price_log is_admin bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (4) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

    * (5) All controls + Year-Month FE
    eststo `prefix'5: reghdfe bid_price_log is_admin bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
        absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (5) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]
end

* UTG time interaction (4 columns)
capture program drop run_interaction
program define run_interaction
    args prefix

    * (1) is_admin x late_period, no controls
    eststo `prefix'1: reghdfe bid_price_log is_admin##late_period if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (1) is_admin = " %9.4f _b[1.is_admin] "  interaction = " %9.4f _b[1.is_admin#1.late_period]

    * (2) + quantity
    eststo `prefix'2: reghdfe bid_price_log is_admin##late_period bid_qty_log if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (2) is_admin = " %9.4f _b[1.is_admin] "  interaction = " %9.4f _b[1.is_admin#1.late_period]

    * (3) + all controls
    eststo `prefix'3: reghdfe bid_price_log is_admin##late_period bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
        absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (3) is_admin = " %9.4f _b[1.is_admin] "  interaction = " %9.4f _b[1.is_admin#1.late_period]

    * (4) + all controls + YM FE
    eststo `prefix'4: reghdfe bid_price_log is_admin##late_period bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
        absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
    di "`prefix' Col (4) is_admin = " %9.4f _b[1.is_admin] "  interaction = " %9.4f _b[1.is_admin#1.late_period]
end


* PART A: UNDER THE GUN ROBUSTNESS — 3 winsorization panels

eststo clear

* Prepare UTG subsample
use `full_sample', clear
keep if purchase_type == 1 | purchase_type == 2
bysort item: egen has_admin2 = max(is_admin == 1)
bysort item: egen has_lit2 = max(is_admin == 0)
keep if has_admin2 == 1 & has_lit2 == 1

di "Under the Gun sample: " _N
tab purchase_type

tempfile utg_sample
save `utg_sample'


* Panel A: No winsorization
di ""
di "  UTG PANEL A: NO WINSORIZATION"
use `utg_sample', clear
run_progressive "a"
run_interaction "ia"

* Panel B: Winsorization at 1%/99%
di ""
di "  UTG PANEL B: WINSORIZATION 1%/99%"
use `utg_sample', clear
do_winsorize 1 99
run_progressive "b"
run_interaction "ib"

* Panel C: Winsorization at 5%/95%
di ""
di "  UTG PANEL C: WINSORIZATION 5%/95%"
use `utg_sample', clear
do_winsorize 5 95
run_progressive "c"
run_interaction "ic"


* Output UTG progressive controls tables
esttab a1 a2 a3 a4 a5 using "`outdir'/underthegun_robustness.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Under the Gun — Progressive Controls: Panel A (No Winsorization)") ///
    mtitles("Baseline" "+Quantity" "+Ref Price" "+Competition" "+YM FE") ///
    order(is_admin bid_qty_log bid_price_ref_log ln_n_firms) ///
    note("") compress replace

esttab b1 b2 b3 b4 b5 using "`outdir'/underthegun_robustness.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles("Baseline" "+Quantity" "+Ref Price" "+Competition" "+YM FE") ///
    order(is_admin bid_qty_log bid_price_ref_log ln_n_firms) ///
    note("") compress append

esttab c1 c2 c3 c4 c5 using "`outdir'/underthegun_robustness.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles("Baseline" "+Quantity" "+Ref Price" "+Competition" "+YM FE") ///
    order(is_admin bid_qty_log bid_price_ref_log ln_n_firms) ///
    note("DV: log negotiated price. is_admin=1 for administrative, 0 for litigated purchases. " ///
         "Cols (1)-(4): Item+Year+PBU FE. Col (5): Item+Year-Month+PBU FE. " ///
         "Standard errors clustered at PBU level in parentheses. " ///
         "*** p<0.01, ** p<0.05, * p<0.1") ///
    compress append


* Output UTG time interaction tables
esttab ia1 ia2 ia3 ia4 using "`outdir'/underthegun_time_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    keep(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    order(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    title("Under the Gun — Time Interaction: Panel A (No Winsorization)") ///
    mtitles("No Controls" "+Quantity" "+All Controls" "+YM FE") ///
    note("") compress replace

esttab ib1 ib2 ib3 ib4 using "`outdir'/underthegun_time_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    keep(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    order(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles("No Controls" "+Quantity" "+All Controls" "+YM FE") ///
    note("") compress append

esttab ic1 ic2 ic3 ic4 using "`outdir'/underthegun_time_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    keep(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    order(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles("No Controls" "+Quantity" "+All Controls" "+YM FE") ///
    note("DV: log negotiated price. is_admin=1 for administrative, 0 for litigated purchases. " ///
         "late_period=1 for 2014-2019 (vs 2009-2013). " ///
         "Cols (1)-(3): Item+Year+PBU FE. Col (4): Item+Year-Month+PBU FE. " ///
         "Standard errors clustered at PBU level in parentheses. " ///
         "*** p<0.01, ** p<0.05, * p<0.1") ///
    compress append


* PART B: ALL-TABLE WINSORIZATION SENSITIVITY

eststo clear

* PANEL A: NO WINSORIZATION
di "  WINSOR PANEL A: NO WINSORIZATION"

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
run_lpm4 t9Aa "urgent"

di _n "--- Table 9b: Success Logit (direct) ---"
run_lpm4 t9Ba "urgent bid_qty_log"

di _n "--- Table 10: Under the Gun ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
bysort item: egen has_admin3 = max(is_admin == 1)
bysort item: egen has_lit3 = max(is_admin == 0)
keep if has_admin3 == 1 & has_lit3 == 1
di "UTG sample (Panel A): " _N
run_reghdfe4 t10Aa bid_price_log "is_admin"
run_reghdfe4 t10Ba bid_price_log "is_admin bid_qty_log"
restore


* PANEL B: WINSORIZED 1%/99%
di "  WINSOR PANEL B: WINSORIZED 1%/99%"

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
run_lpm4 t9Ab "urgent"

di _n "--- Table 9b: Success Logit (direct) ---"
run_lpm4 t9Bb "urgent bid_qty_log"

di _n "--- Table 10: Under the Gun ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
bysort item: egen has_admin3 = max(is_admin == 1)
bysort item: egen has_lit3 = max(is_admin == 0)
keep if has_admin3 == 1 & has_lit3 == 1
di "UTG sample (Panel B): " _N
run_reghdfe4 t10Ab bid_price_log "is_admin"
run_reghdfe4 t10Bb bid_price_log "is_admin bid_qty_log"
restore


* PANEL C: WINSORIZED 5%/95%
di "  WINSOR PANEL C: WINSORIZED 5%/95%"

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
run_lpm4 t9Ac "urgent"

di _n "--- Table 9b: Success Logit (direct) ---"
run_lpm4 t9Bc "urgent bid_qty_log"

di _n "--- Table 10: Under the Gun ---"
preserve
keep if purchase_type == 1 | purchase_type == 2
bysort item: egen has_admin3 = max(is_admin == 1)
bysort item: egen has_lit3 = max(is_admin == 0)
keep if has_admin3 == 1 & has_lit3 == 1
di "UTG sample (Panel C): " _N
run_reghdfe4 t10Ac bid_price_log "is_admin"
run_reghdfe4 t10Bc bid_price_log "is_admin bid_qty_log"
restore


* OUTPUT ALL WINSORIZATION SENSITIVITY TABLES
di "  WRITING WINSORIZATION OUTPUT TABLES"

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


* TABLE 9A: SUCCESS LPM — TOTAL EFFECT
esttab t9Aa1 t9Aa2 t9Aa3 t9Aa4 using "`outdir'/table9a_success_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 9A: Success (LPM, Total Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t9Ab1 t9Ab2 t9Ab3 t9Ab4 using "`outdir'/table9a_success_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t9Ac1 t9Ac2 t9Ac3 t9Ac4 using "`outdir'/table9a_success_total_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') ///
    note("Linear probability model. `fe_note'") ///
    compress append


* TABLE 9B: SUCCESS LPM — DIRECT EFFECT
esttab t9Ba1 t9Ba2 t9Ba3 t9Ba4 using "`outdir'/table9b_success_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Table 9B: Success (LPM, Direct Effect) — Panel A (No Winsorization)") ///
    mtitles(`fe_titles') note("") compress replace

esttab t9Bb1 t9Bb2 t9Bb3 t9Bb4 using "`outdir'/table9b_success_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles(`fe_titles') note("") compress append

esttab t9Bc1 t9Bc2 t9Bc3 t9Bc4 using "`outdir'/table9b_success_direct_winsor.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel C (Winsorized 5%/95%)") ///
    mtitles(`fe_titles') ///
    note("Linear probability model. `fe_note'") ///
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


* SUMMARY
di "  ALL ROBUSTNESS TABLES WRITTEN"
di ""
di "UTG Robustness files:"
di "  underthegun_robustness.rtf (progressive controls, 3 panels)"
di "  underthegun_time_interaction.rtf (time interaction, 3 panels)"
di ""
di "Winsorization sensitivity files (each with 3 panels):"
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
