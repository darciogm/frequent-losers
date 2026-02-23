********************************************************************************
* Aggregate Fiscal Cost of Health Litigation
* Paper: Bitter Pills to Swallow
* Referee Suggestion 7: Back-of-the-envelope fiscal cost calculation
*
* Approach: use estimated price premiums to compute counterfactual prices
* for urgent purchases, then aggregate excess costs.
*   counterfactual price = observed price × exp(-β)
*   excess cost per transaction = price × qty × (1 - exp(-β))
********************************************************************************

clear all
set more off
set max_memory 14g

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

* --------------------------------------------------------------------------
* 1. Setup: same sample and variables as regression analysis
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

encode item, gen(item_id2)
encode pbu_code, gen(pbu_id)
rename m_y ym
capture destring year, gen(year_num) force
if _rc != 0 {
    gen year_num = real(year)
}

* Total spending per transaction (for winners only)
gen total_spend = bid_price * bid_qty if po_firm_winner == 1

di ""
di "=================================================================="
di "  AGGREGATE FISCAL COST OF HEALTH LITIGATION"
di "=================================================================="

* --------------------------------------------------------------------------
* 2. Descriptive overview of spending
* --------------------------------------------------------------------------
di ""
di "--- Overview of procurement spending (winners only) ---"

* Total spending
quietly summarize total_spend if po_firm_winner == 1
local total_all = r(sum)
di "Total spending (all purchases):        R$ " %20.2fc `total_all'

quietly summarize total_spend if po_firm_winner == 1 & urgent == 0
local total_ordinary = r(sum)
local n_ordinary = r(N)
di "  Ordinary purchases:                  R$ " %20.2fc `total_ordinary' "  (N = " `n_ordinary' ")"

quietly summarize total_spend if po_firm_winner == 1 & urgent == 1
local total_urgent = r(sum)
local n_urgent = r(N)
di "  Urgent purchases (admin+litigated):  R$ " %20.2fc `total_urgent' "  (N = " `n_urgent' ")"

quietly summarize total_spend if po_firm_winner == 1 & purchase_type == 1
local total_admin = r(sum)
local n_admin = r(N)
di "    Administrative:                    R$ " %20.2fc `total_admin' "  (N = " `n_admin' ")"

quietly summarize total_spend if po_firm_winner == 1 & purchase_type == 2
local total_litigated = r(sum)
local n_litigated = r(N)
di "    Litigated:                         R$ " %20.2fc `total_litigated' "  (N = " `n_litigated' ")"

di ""
di "Share of urgent in total spending: " %6.2f (`total_urgent'/`total_all'*100) "%"
di "Share of litigated in total spending: " %6.2f (`total_litigated'/`total_all'*100) "%"

* Years covered
quietly summarize year_num if po_firm_winner == 1
local year_min = r(min)
local year_max = r(max)
local n_years = `year_max' - `year_min' + 1
di "Period: `year_min' - `year_max' (`n_years' years)"

* --------------------------------------------------------------------------
* 3. Fiscal cost using TOTAL EFFECT (no quantity control)
*    This captures the full price impact of urgency, including via quantity
* --------------------------------------------------------------------------
di ""
di "=================================================================="
di "  A. FISCAL COST — TOTAL EFFECT (urgency premium on prices)"
di "=================================================================="

* Estimate preferred specifications and compute costs
foreach fe_label in "Item+Year" "Item+Year+PBU" "Item+YM+PBU" {

    if "`fe_label'" == "Item+Year" {
        quietly reghdfe bid_price_log urgent if po_firm_winner==1, ///
            absorb(item_id2 year) vce(cluster pbu_id)
    }
    else if "`fe_label'" == "Item+Year+PBU" {
        quietly reghdfe bid_price_log urgent if po_firm_winner==1, ///
            absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    }
    else {
        quietly reghdfe bid_price_log urgent if po_firm_winner==1, ///
            absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
    }

    local beta = _b[urgent]
    local se = _se[urgent]
    local pct_premium = (exp(`beta') - 1) * 100
    local pct_low = (exp(`beta' - 1.96*`se') - 1) * 100
    local pct_high = (exp(`beta' + 1.96*`se') - 1) * 100

    * Excess cost = sum over urgent purchases of: price × qty × (1 - exp(-β))
    local excess_factor = 1 - exp(-`beta')
    local excess_factor_low = 1 - exp(-(`beta' - 1.96*`se'))
    local excess_factor_high = 1 - exp(-(`beta' + 1.96*`se'))

    * Compute transaction-level excess costs
    quietly gen excess_cost = total_spend * `excess_factor' if po_firm_winner == 1 & urgent == 1
    quietly summarize excess_cost
    local total_excess = r(sum)
    local annual_excess = `total_excess' / `n_years'

    * 95% CI bounds
    quietly replace excess_cost = total_spend * `excess_factor_low' if po_firm_winner == 1 & urgent == 1
    quietly summarize excess_cost
    local total_excess_low = r(sum)

    quietly replace excess_cost = total_spend * `excess_factor_high' if po_firm_winner == 1 & urgent == 1
    quietly summarize excess_cost
    local total_excess_high = r(sum)

    drop excess_cost

    di ""
    di "--- `fe_label' FE ---"
    di "  β (urgent) = " %7.4f `beta' "  (SE = " %7.4f `se' ")"
    di "  Price premium: " %6.1f `pct_premium' "% [95% CI: " %6.1f `pct_low' "% to " %6.1f `pct_high' "%]"
    di "  Total excess cost:      R$ " %20.2fc `total_excess'
    di "  95% CI:                 R$ " %20.2fc `total_excess_low' " to R$ " %20.2fc `total_excess_high'
    di "  Annual average:         R$ " %20.2fc `annual_excess'
    di "  As % of total spending: " %6.2f (`total_excess'/`total_all'*100) "%"
}


* --------------------------------------------------------------------------
* 4. Fiscal cost using DIRECT EFFECT (controlling for quantity)
*    This isolates the per-unit price premium, holding quantity fixed
* --------------------------------------------------------------------------
di ""
di "=================================================================="
di "  B. FISCAL COST — DIRECT EFFECT (per-unit price premium)"
di "=================================================================="

foreach fe_label in "Item+Year" "Item+Year+PBU" "Item+YM+PBU" {

    if "`fe_label'" == "Item+Year" {
        quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
            absorb(item_id2 year) vce(cluster pbu_id)
    }
    else if "`fe_label'" == "Item+Year+PBU" {
        quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
            absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    }
    else {
        quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
            absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
    }

    local beta = _b[urgent]
    local se = _se[urgent]
    local pct_premium = (exp(`beta') - 1) * 100
    local pct_low = (exp(`beta' - 1.96*`se') - 1) * 100
    local pct_high = (exp(`beta' + 1.96*`se') - 1) * 100

    local excess_factor = 1 - exp(-`beta')

    quietly gen excess_cost = total_spend * `excess_factor' if po_firm_winner == 1 & urgent == 1
    quietly summarize excess_cost
    local total_excess = r(sum)
    local annual_excess = `total_excess' / `n_years'

    drop excess_cost

    di ""
    di "--- `fe_label' FE (qty controlled) ---"
    di "  β (urgent) = " %7.4f `beta' "  (SE = " %7.4f `se' ")"
    di "  Per-unit price premium: " %6.1f `pct_premium' "%"
    di "  Total excess cost:      R$ " %20.2fc `total_excess'
    di "  Annual average:         R$ " %20.2fc `annual_excess'
    di "  As % of total spending: " %6.2f (`total_excess'/`total_all'*100) "%"
}


* --------------------------------------------------------------------------
* 5. "Under the gun" fiscal cost: judicial vs administrative
*    How much of the urgent premium is due to the sanction channel?
* --------------------------------------------------------------------------
di ""
di "=================================================================="
di "  C. FISCAL COST — 'UNDER THE GUN' (sanction channel)"
di "  Excess cost of litigated vs. administrative purchases"
di "=================================================================="

preserve
keep if purchase_type == 1 | purchase_type == 2

gen is_admin = (purchase_type == 1)

bysort item: egen has_admin = max(is_admin == 1)
bysort item: egen has_lit = max(is_admin == 0)
keep if has_admin == 1 & has_lit == 1

di ""
di "Under the Gun sample: " _N " transactions"

quietly summarize total_spend if po_firm_winner == 1
local total_utg = r(sum)

quietly summarize total_spend if po_firm_winner == 1 & is_admin == 0
local total_lit_utg = r(sum)
local n_lit_utg = r(N)
di "  Litigated spending in this sample: R$ " %20.2fc `total_lit_utg' "  (N = " `n_lit_utg' ")"

foreach fe_label in "Item+Year" "Item+Year+PBU" "Item+YM+PBU" {

    if "`fe_label'" == "Item+Year" {
        quietly reghdfe bid_price_log is_admin if po_firm_winner==1, ///
            absorb(item_id2 year) vce(cluster pbu_id)
    }
    else if "`fe_label'" == "Item+Year+PBU" {
        quietly reghdfe bid_price_log is_admin if po_firm_winner==1, ///
            absorb(item_id2 year pbu_id) vce(cluster pbu_id)
    }
    else {
        quietly reghdfe bid_price_log is_admin if po_firm_winner==1, ///
            absorb(item_id2 ym pbu_id) vce(cluster pbu_id)
    }

    * is_admin coefficient: negative means admin is cheaper than litigated
    * The sanction premium on litigated = -β (the penalty for being litigated vs admin)
    local beta_admin = _b[is_admin]
    local se = _se[is_admin]
    local sanction_premium = (exp(-`beta_admin') - 1) * 100

    * Excess cost on litigated purchases due to sanctions
    * counterfactual: if litigated had admin prices → price × exp(β_admin)
    * excess = price × qty × (1 - exp(β_admin))  [note: β_admin < 0 → excess > 0]
    local excess_factor = 1 - exp(`beta_admin')

    quietly gen excess_sanction = total_spend * `excess_factor' if po_firm_winner == 1 & is_admin == 0
    quietly summarize excess_sanction
    local total_sanction = r(sum)
    local annual_sanction = `total_sanction' / `n_years'

    drop excess_sanction

    di ""
    di "--- `fe_label' FE ---"
    di "  β (is_admin) = " %7.4f `beta_admin' "  (SE = " %7.4f `se' ")"
    di "  Sanction premium on litigated: " %6.1f `sanction_premium' "%"
    di "  Total sanction excess cost:    R$ " %20.2fc `total_sanction'
    di "  Annual average:                R$ " %20.2fc `annual_sanction'
}

restore


* --------------------------------------------------------------------------
* 6. Summary table
* --------------------------------------------------------------------------
di ""
di "=================================================================="
di "  SUMMARY"
di "=================================================================="
di ""
di "Period: `year_min'-`year_max' (`n_years' years)"
di "Total procurement spending (sample): R$ " %20.2fc `total_all'
di "  of which urgent:                   R$ " %20.2fc `total_urgent' " (" %4.1f (`total_urgent'/`total_all'*100) "%)"
di "  of which litigated:                R$ " %20.2fc `total_litigated' " (" %4.1f (`total_litigated'/`total_all'*100) "%)"
di ""
di "See sections A, B, C above for excess cost estimates under"
di "different specifications and identification assumptions."
