* Under the Gun Robustness: Additional Controls + Winsorization Sensitivity
*
* Progressively adds controls to the litigated vs administrative comparison
* to check whether the null result in Table 10 is robust.
*
* Columns (per panel):
*   (1) Baseline: is_admin only
*   (2) + Quantity
*   (3) + Reference price
*   (4) + Competition (ln firms)
*   (5) All controls + Year-Month FE (replacing Year FE)
*
* Panels: A = No winsorization, B = 1%/99%, C = 5%/95%
*
* Also: time-period interaction (is_admin##late_period) with same panels
*
* Base spec: Item+Year+PBU FE, cluster PBU (preferred from Table 10)

clear all
set more off
set max_memory 14g

timer clear
timer on 1

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

* 1. Setup: variables and sample (mirrors clustered_regressions.do)
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

* Create numeric identifiers for reghdfe
encode item, gen(item_id2)
encode pbu_code, gen(pbu_id)
rename m_y ym
capture destring year, gen(year_num) force
if _rc != 0 {
    gen year_num = real(year)
}

* Time period indicator (mirrors heterogeneity.do)
gen late_period = (year_num >= 2014)
label var late_period "1 = Late period (2014-2019), 0 = Early (2009-2013)"

* Output directory
local outdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v2/analysis/results"
capture mkdir "`outdir'"

* 2. Restrict to Under the Gun sample: litigated vs administrative only
keep if purchase_type == 1 | purchase_type == 2

gen is_admin = (purchase_type == 1)
label var is_admin "1 = Administrative, 0 = Litigated"

* Need items with at least one admin and one litigated
bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1

di "Under the Gun sample: " _N
tab purchase_type


* PROGRAM: Winsorize variables and regenerate logs
* Arguments: lower percentile, upper percentile (e.g., 1 99 or 5 95)
capture program drop winsorize_and_regen
program define winsorize_and_regen
    args plo phi
    foreach v in bid_price bid_price_ref bid_qty n_firms_bids {
        quietly summarize `v', detail
        local lo = r(p`plo')
        local hi = r(p`phi')
        replace `v' = `lo' if `v' < `lo' & `v' != .
        replace `v' = `hi' if `v' > `hi' & `v' != .
    }
    * Regenerate log variables
    capture drop bid_qty_log bid_price_ref_log bid_price_log ln_n_firms
    gen bid_qty_log = ln(bid_qty)
    gen bid_price_ref_log = ln(bid_price_ref)
    gen bid_price_log = ln(bid_price)
    gen ln_n_firms = ln(n_firms_bids)
end


* PROGRAM: Run 5 progressive-control regressions and store estimates
* Arguments: prefix for eststo names (e.g., "raw" "w1" "w5")
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


* PROGRAM: Run 4 time-interaction regressions and store estimates
* Arguments: prefix for eststo names
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


* 3. RUN ALL PANELS

eststo clear

* Panel A: No winsorization
di ""
di "  PANEL A: NO WINSORIZATION"
preserve
run_progressive "a"
run_interaction "ia"
restore

* Panel B: Winsorization at 1%/99%
di ""
di "  PANEL B: WINSORIZATION 1%/99%"
preserve
winsorize_and_regen 1 99
run_progressive "b"
run_interaction "ib"
restore

* Panel C: Winsorization at 5%/95%
di ""
di "  PANEL C: WINSORIZATION 5%/95%"
preserve
winsorize_and_regen 5 95
run_progressive "c"
run_interaction "ic"
restore


* 4. OUTPUT TABLES

* Progressive controls: Panel A (no winsor)
esttab a1 a2 a3 a4 a5 using "`outdir'/underthegun_robustness.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Under the Gun — Progressive Controls: Panel A (No Winsorization)") ///
    mtitles("Baseline" "+Quantity" "+Ref Price" "+Competition" "+YM FE") ///
    order(is_admin bid_qty_log bid_price_ref_log ln_n_firms) ///
    note("") compress replace

* Progressive controls: Panel B (1%/99%)
esttab b1 b2 b3 b4 b5 using "`outdir'/underthegun_robustness.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles("Baseline" "+Quantity" "+Ref Price" "+Competition" "+YM FE") ///
    order(is_admin bid_qty_log bid_price_ref_log ln_n_firms) ///
    note("") compress append

* Progressive controls: Panel C (5%/95%)
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


* Time interaction: Panel A (no winsor)
esttab ia1 ia2 ia3 ia4 using "`outdir'/underthegun_time_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    keep(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    order(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    title("Under the Gun — Time Interaction: Panel A (No Winsorization)") ///
    mtitles("No Controls" "+Quantity" "+All Controls" "+YM FE") ///
    note("") compress replace

* Time interaction: Panel B (1%/99%)
esttab ib1 ib2 ib3 ib4 using "`outdir'/underthegun_time_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    keep(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    order(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    title("Panel B (Winsorized 1%/99%)") ///
    mtitles("No Controls" "+Quantity" "+All Controls" "+YM FE") ///
    note("") compress append

* Time interaction: Panel C (5%/95%)
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


* Summary
di ""
di "  SUMMARY"
di ""
di "Progressive controls table (3 panels) saved to:"
di "  `outdir'/underthegun_robustness.rtf"
di ""
di "Time-period interaction table (3 panels) saved to:"
di "  `outdir'/underthegun_time_interaction.rtf"

timer off 1
timer list
