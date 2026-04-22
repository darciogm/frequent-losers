* V3 Visualizations
* Source: /tmp/v3_prepared.dta (full BEC_JUD sample, CONVITE + PREGÃO)
*
* 8 figures:
*   1. Kernel density: log reference price by type
*   2. Kernel density: log negotiated price by type
*   3. Kernel density: log quantity by type
*   4. Kernel density: log(firms) by type
*   5. Kernel density: log negotiated price, admin vs litigated (urgent only)
*   6. Bar chart: mean success rate by purchase type
*   7. Line plot: mean log negotiated price by year-month
*   8. Coefficient plot: treatment effects from Tables 4-7

clear all
set more off
set max_memory 14g
capture set processors 16

timer clear
timer on 1

use "/tmp/v3_prepared.dta", clear

* 1. Restrict to analysis sample
keep if has_litigated == 1 & has_ordinary == 1

local graphdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v3/graphs"

set scheme s2color

di "Analysis sample: " _N


* 2. Figure 1: Kernel density — Log Reference Price
di "Creating fig_price_density..."
twoway ///
    (kdensity bid_price_ref_log if purchase_type == 0 & po_firm_winner == 1, ///
        lcolor(navy) lwidth(medthick) lpattern(solid)) ///
    (kdensity bid_price_ref_log if purchase_type == 1 & po_firm_winner == 1, ///
        lcolor(cranberry) lwidth(medthick) lpattern(dash)) ///
    (kdensity bid_price_ref_log if purchase_type == 2 & po_firm_winner == 1, ///
        lcolor(forest_green) lwidth(medthick) lpattern(longdash)), ///
    title("Distribution of Log Reference Prices by Purchase Type") ///
    xtitle("Log Reference Price") ytitle("Density") ///
    legend(order(1 "Ordinary" 2 "Administrative" 3 "Litigated") ///
        rows(1) position(6)) ///
    note("Sample: winners only, items with both ordinary and litigated purchases")
graph export "`graphdir'/fig_price_density.pdf", replace


* 3. Figure 2: Kernel density — Log Negotiated Price
di "Creating fig_negprice_density..."
twoway ///
    (kdensity bid_price_log if purchase_type == 0 & po_firm_winner == 1, ///
        lcolor(navy) lwidth(medthick) lpattern(solid)) ///
    (kdensity bid_price_log if purchase_type == 1 & po_firm_winner == 1, ///
        lcolor(cranberry) lwidth(medthick) lpattern(dash)) ///
    (kdensity bid_price_log if purchase_type == 2 & po_firm_winner == 1, ///
        lcolor(forest_green) lwidth(medthick) lpattern(longdash)), ///
    title("Distribution of Log Negotiated Prices by Purchase Type") ///
    xtitle("Log Negotiated Price") ytitle("Density") ///
    legend(order(1 "Ordinary" 2 "Administrative" 3 "Litigated") ///
        rows(1) position(6)) ///
    note("Sample: winners only, items with both ordinary and litigated purchases")
graph export "`graphdir'/fig_negprice_density.pdf", replace


* 4. Figure 3: Kernel density — Log Quantity
di "Creating fig_qty_density..."
twoway ///
    (kdensity bid_qty_log if purchase_type == 0 & po_firm_winner == 1, ///
        lcolor(navy) lwidth(medthick) lpattern(solid)) ///
    (kdensity bid_qty_log if purchase_type == 1 & po_firm_winner == 1, ///
        lcolor(cranberry) lwidth(medthick) lpattern(dash)) ///
    (kdensity bid_qty_log if purchase_type == 2 & po_firm_winner == 1, ///
        lcolor(forest_green) lwidth(medthick) lpattern(longdash)), ///
    title("Distribution of Log Quantities by Purchase Type") ///
    xtitle("Log Quantity") ytitle("Density") ///
    legend(order(1 "Ordinary" 2 "Administrative" 3 "Litigated") ///
        rows(1) position(6)) ///
    note("Sample: winners only, items with both ordinary and litigated purchases")
graph export "`graphdir'/fig_qty_density.pdf", replace


* 5. Figure 4: Kernel density — Log Number of Firms
di "Creating fig_firms_density..."
twoway ///
    (kdensity ln_n_firms if purchase_type == 0 & po_firm_winner == 1, ///
        lcolor(navy) lwidth(medthick) lpattern(solid)) ///
    (kdensity ln_n_firms if purchase_type == 1 & po_firm_winner == 1, ///
        lcolor(cranberry) lwidth(medthick) lpattern(dash)) ///
    (kdensity ln_n_firms if purchase_type == 2 & po_firm_winner == 1, ///
        lcolor(forest_green) lwidth(medthick) lpattern(longdash)), ///
    title("Distribution of Log Number of Bidding Firms by Purchase Type") ///
    xtitle("Log Number of Firms") ytitle("Density") ///
    legend(order(1 "Ordinary" 2 "Administrative" 3 "Litigated") ///
        rows(1) position(6)) ///
    note("Sample: winners only, items with both ordinary and litigated purchases")
graph export "`graphdir'/fig_firms_density.pdf", replace


* 6. Figure 5: Kernel density — Admin vs Litigated (urgent only)
di "Creating fig_utg_density..."
twoway ///
    (kdensity bid_price_log if purchase_type == 1 & po_firm_winner == 1, ///
        lcolor(cranberry) lwidth(medthick) lpattern(solid)) ///
    (kdensity bid_price_log if purchase_type == 2 & po_firm_winner == 1, ///
        lcolor(forest_green) lwidth(medthick) lpattern(dash)), ///
    title("Distribution of Log Negotiated Prices: Admin vs. Litigated") ///
    subtitle("(Urgent purchases only)") ///
    xtitle("Log Negotiated Price") ytitle("Density") ///
    legend(order(1 "Administrative" 2 "Litigated") ///
        rows(1) position(6)) ///
    note("Sample: winners only, urgent purchases, items with both ordinary and litigated")
graph export "`graphdir'/fig_utg_density.pdf", replace


* 7. Figure 6: Bar chart — Mean success rate by purchase type
di "Creating fig_success_bar..."
preserve
collapse (mean) success_rate = po_firm_winner (count) n = po_firm_winner, by(purchase_type)

graph bar success_rate, over(purchase_type, relabel(1 "Ordinary" 2 "Administrative" 3 "Litigated")) ///
    title("Mean Tender Success Rate by Purchase Type") ///
    ytitle("Success Rate") ///
    bar(1, color(navy)) ///
    blabel(bar, format(%4.3f)) ///
    note("Sample: all bids, items with both ordinary and litigated purchases")
graph export "`graphdir'/fig_success_bar.pdf", replace
restore


* 8. Figure 7: Time trends — Mean log negotiated price by year-month
di "Creating fig_time_trends..."
preserve
gen urgent_label = cond(urgent == 1, "Urgent", "Ordinary")
collapse (mean) mean_price = bid_price_log (count) n = bid_price_log ///
    if po_firm_winner == 1, by(ym urgent)

twoway ///
    (line mean_price ym if urgent == 0, lcolor(navy) lwidth(medthick) sort) ///
    (line mean_price ym if urgent == 1, lcolor(cranberry) lwidth(medthick) lpattern(dash) sort), ///
    title("Mean Log Negotiated Price Over Time") ///
    xtitle("Year-Month") ytitle("Mean Log Negotiated Price") ///
    legend(order(1 "Ordinary" 2 "Urgent (Admin+Litigated)") ///
        rows(1) position(6)) ///
    note("Sample: winners only, items with both ordinary and litigated purchases")
graph export "`graphdir'/fig_time_trends.pdf", replace
restore


* 9. Figure 8: Coefficient plot — Treatment effects from Tables 4-7
di "Creating fig_coefplot..."

* Run preferred specification (Item+Year+PBU FE) for each table
* Table 4: Reference prices
quietly reghdfe bid_price_ref_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
estimates store t4

* Table 5: Quantities
quietly reghdfe bid_qty_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
estimates store t5

* Table 6A: Negotiated prices (total)
quietly reghdfe bid_price_log urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
estimates store t6a

* Table 6B: Negotiated prices (direct)
quietly reghdfe bid_price_log urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
estimates store t6b

* Table 7A: Firms (total)
quietly reghdfe ln_n_firms urgent if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
estimates store t7a

* Table 7B: Firms (direct)
quietly reghdfe ln_n_firms urgent bid_qty_log if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
estimates store t7b

capture which coefplot
if _rc == 0 {
    coefplot ///
        (t4, label("Ref Price (T4)")) ///
        (t5, label("Quantity (T5)")) ///
        (t6a, label("Neg Price Total (T6A)")) ///
        (t6b, label("Neg Price Direct (T6B)")) ///
        (t7a, label("Firms Total (T7A)")) ///
        (t7b, label("Firms Direct (T7B)")), ///
        keep(urgent) ///
        xline(0, lcolor(gs10) lpattern(dash)) ///
        title("Treatment Effects of Urgency: Preferred Specification") ///
        subtitle("Item + Year + PBU FE, SE clustered at PBU level") ///
        note("Coefficient on 'urgent' (=1 for admin/litigated). 95% confidence intervals.") ///
        ciopts(recast(rcap)) ///
        mlabel format(%5.3f) mlabposition(12) mlabsize(small)
    graph export "`graphdir'/fig_coefplot.pdf", replace
}
else {
    di "WARNING: coefplot not installed. Skipping coefficient plot."
    di "Install with: ssc install coefplot"
}


* Summary
di ""
di "  ALL GRAPHS CREATED"
di ""
di "Output files in v3/graphs/:"
di "  fig_price_density.pdf"
di "  fig_negprice_density.pdf"
di "  fig_qty_density.pdf"
di "  fig_firms_density.pdf"
di "  fig_utg_density.pdf"
di "  fig_success_bar.pdf"
di "  fig_time_trends.pdf"
di "  fig_coefplot.pdf (requires coefplot package)"

timer off 1
timer list
