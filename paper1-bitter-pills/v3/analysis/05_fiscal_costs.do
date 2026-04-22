* V3 Aggregate Fiscal Cost of Health Litigation
* Source: /tmp/v3_prepared.dta (full BEC_JUD sample, CONVITE + PREGÃO)
*
* Three channels:
*   A. Total effect (price impact including via quantity)
*   B. Direct effect (per-unit price premium, holding quantity fixed)
*   C. Under the Gun (sanction channel: litigated vs administrative)

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

* Total spending per transaction (for winners only)
gen total_spend = bid_price * bid_qty if po_firm_winner == 1

di ""
di "  AGGREGATE FISCAL COST OF HEALTH LITIGATION"

* 2. Descriptive overview of spending
di ""
di "--- Overview of procurement spending (winners only) ---"

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

* 3. Fiscal cost using TOTAL EFFECT (no quantity control)
di ""
di "  A. FISCAL COST — TOTAL EFFECT (urgency premium on prices)"

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


* 4. Fiscal cost using DIRECT EFFECT (controlling for quantity)
di ""
di "  B. FISCAL COST — DIRECT EFFECT (per-unit price premium)"

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


* 5. "Under the gun" fiscal cost: judicial vs administrative
di ""
di "  C. FISCAL COST — 'UNDER THE GUN' (sanction channel)"
di "  Excess cost of litigated vs. administrative purchases"

preserve
keep if purchase_type == 1 | purchase_type == 2

bysort item: egen has_admin2 = max(is_admin == 1)
bysort item: egen has_lit2 = max(is_admin == 0)
keep if has_admin2 == 1 & has_lit2 == 1

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
    local beta_admin = _b[is_admin]
    local se = _se[is_admin]
    local sanction_premium = (exp(-`beta_admin') - 1) * 100

    * Excess cost on litigated purchases due to sanctions
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


* 6. Summary
di ""
di "  SUMMARY"
di ""
di "Period: `year_min'-`year_max' (`n_years' years)"
di "Total procurement spending (sample): R$ " %20.2fc `total_all'
di "  of which urgent:                   R$ " %20.2fc `total_urgent' " (" %4.1f (`total_urgent'/`total_all'*100) "%)"
di "  of which litigated:                R$ " %20.2fc `total_litigated' " (" %4.1f (`total_litigated'/`total_all'*100) "%)"
di ""
di "See sections A, B, C above for excess cost estimates under"
di "different specifications and identification assumptions."

timer off 1
timer list
