********************************************************************************
* Under the Gun Robustness: Additional Controls
* Paper: Bitter Pills to Swallow
* Progressively adds controls to the litigated vs administrative comparison
* to check whether the null result in Table 10 is robust.
*
* Columns:
*   (1) Baseline: is_admin only
*   (2) + Quantity
*   (3) + Reference price
*   (4) + Competition (ln firms)
*   (5) All controls + Year-Month FE (replacing Year FE)
*
* Also: time-period interaction (is_admin##late_period)
*
* Base spec: Item+Year+PBU FE, cluster PBU (preferred from Table 10)
********************************************************************************

clear all
set more off
set max_memory 14g

timer clear
timer on 1

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

* --------------------------------------------------------------------------
* 1. Setup: variables and sample (mirrors clustered_regressions.do)
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

* --------------------------------------------------------------------------
* 2. Restrict to Under the Gun sample: litigated vs administrative only
* --------------------------------------------------------------------------
keep if purchase_type == 1 | purchase_type == 2

gen is_admin = (purchase_type == 1)
label var is_admin "1 = Administrative, 0 = Litigated"

* Need items with at least one admin and one litigated
bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1

di "Under the Gun sample: " _N
tab purchase_type


********************************************************************************
* TABLE: UNDER THE GUN — Progressive Controls
* All use Item+Year+PBU FE, cluster PBU (preferred spec from Table 10 col 3)
********************************************************************************
di ""
di "==========================================="
di "  UNDER THE GUN: PROGRESSIVE CONTROLS"
di "==========================================="

eststo clear

* (1) Baseline: is_admin only
eststo m1: reghdfe bid_price_log is_admin if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "Col (1) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

* (2) + Quantity
eststo m2: reghdfe bid_price_log is_admin bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "Col (2) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

* (3) + Reference price
eststo m3: reghdfe bid_price_log is_admin bid_qty_log bid_price_ref_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "Col (3) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

* (4) + Competition (ln firms)
eststo m4: reghdfe bid_price_log is_admin bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
di "Col (4) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

* (5) All controls + Year-Month FE (replacing Year FE)
eststo m5: reghdfe bid_price_log is_admin bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
di "Col (5) is_admin = " %9.4f _b[is_admin] "  SE = " %9.4f _se[is_admin]

esttab m1 m2 m3 m4 m5 using "`outdir'/underthegun_robustness.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Under the Gun — Litigated vs Administrative: Progressive Controls") ///
    mtitles("Baseline" "+Quantity" "+Ref Price" "+Competition" "+YM FE") ///
    order(is_admin bid_qty_log bid_price_ref_log ln_n_firms) ///
    note("DV: log negotiated price. is_admin=1 for administrative, 0 for litigated purchases. " ///
         "Cols (1)-(4): Item+Year+PBU FE. Col (5): Item+Year-Month+PBU FE. " ///
         "Standard errors clustered at PBU level in parentheses. " ///
         "*** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE: UNDER THE GUN — Time-Period Interaction
* Motivated by heterogeneity finding that urgency premium grew over time
********************************************************************************
di ""
di "==========================================="
di "  UNDER THE GUN: TIME-PERIOD INTERACTION"
di "==========================================="

eststo clear

* (1) is_admin x late_period, no additional controls
eststo t1: reghdfe bid_price_log is_admin##late_period if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

di "Col (1) interaction:"
di "  is_admin        = " %9.4f _b[1.is_admin] "  SE = " %9.4f _se[1.is_admin]
di "  late_period     = " %9.4f _b[1.late_period] "  SE = " %9.4f _se[1.late_period]
di "  is_admin#late   = " %9.4f _b[1.is_admin#1.late_period] "  SE = " %9.4f _se[1.is_admin#1.late_period]

* (2) is_admin x late_period + quantity
eststo t2: reghdfe bid_price_log is_admin##late_period bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

di "Col (2) interaction + qty:"
di "  is_admin        = " %9.4f _b[1.is_admin] "  SE = " %9.4f _se[1.is_admin]
di "  is_admin#late   = " %9.4f _b[1.is_admin#1.late_period] "  SE = " %9.4f _se[1.is_admin#1.late_period]

* (3) is_admin x late_period + all controls
eststo t3: reghdfe bid_price_log is_admin##late_period bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

di "Col (3) interaction + all controls:"
di "  is_admin        = " %9.4f _b[1.is_admin] "  SE = " %9.4f _se[1.is_admin]
di "  is_admin#late   = " %9.4f _b[1.is_admin#1.late_period] "  SE = " %9.4f _se[1.is_admin#1.late_period]

* (4) is_admin x late_period + all controls + YM FE
eststo t4: reghdfe bid_price_log is_admin##late_period bid_qty_log bid_price_ref_log ln_n_firms if po_firm_winner==1, ///
    absorb(item_id2 ym pbu_id) vce(cluster pbu_id)

di "Col (4) interaction + all controls + YM FE:"
di "  is_admin        = " %9.4f _b[1.is_admin] "  SE = " %9.4f _se[1.is_admin]
di "  is_admin#late   = " %9.4f _b[1.is_admin#1.late_period] "  SE = " %9.4f _se[1.is_admin#1.late_period]

esttab t1 t2 t3 t4 using "`outdir'/underthegun_time_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    keep(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    order(1.is_admin 1.late_period 1.is_admin#1.late_period bid_qty_log bid_price_ref_log ln_n_firms) ///
    title("Under the Gun — Time-Period Interaction (Litigated vs Administrative)") ///
    mtitles("No Controls" "+Quantity" "+All Controls" "+YM FE") ///
    note("DV: log negotiated price. is_admin=1 for administrative, 0 for litigated purchases. " ///
         "late_period=1 for 2014-2019 (vs 2009-2013). " ///
         "Cols (1)-(3): Item+Year+PBU FE. Col (4): Item+Year-Month+PBU FE. " ///
         "Standard errors clustered at PBU level in parentheses. " ///
         "*** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* Summary
********************************************************************************
di ""
di "==========================================="
di "  SUMMARY"
di "==========================================="
di ""
di "Progressive controls table saved to:"
di "  `outdir'/underthegun_robustness.rtf"
di ""
di "Time-period interaction table saved to:"
di "  `outdir'/underthegun_time_interaction.rtf"

timer off 1
timer list
