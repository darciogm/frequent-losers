* Heterogeneity Analyses — Referee Suggestion 6
* Explores how the urgency price premium varies across subgroups:
*   1. SUS component type (Basic vs Specialized)
*   2. Time period (Early 2009-2013 vs Late 2014-2019)
*   3. Market concentration (high vs low competition)
*   4. PBU size (large vs small purchasing units)
*
* Base specification: Table 6 total effect (Item+Year+PBU FE, cluster PBU)
*   reghdfe bid_price_log urgent if po_firm_winner==1,
*       absorb(item_id2 year pbu_id) vce(cluster pbu_id)

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

* Output directory
local outdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v2/analysis/results"
capture mkdir "`outdir'"

di "Analysis sample size: " _N

* 2. Construct heterogeneity dimensions

* 2a. SUS component type
* padronizadosus classifies drugs into SUS components
* "Componente Básico" = basic/standard drugs (~89%)
* Others = specialized, strategic, hospital use, pharma inputs (~11%)
gen sus_basic = (padronizadosus == "Componente Básico")
label var sus_basic "1 = Basic SUS component, 0 = Specialized/Strategic/Other"
tab sus_basic

* 2b. Time period
gen late_period = (year_num >= 2014)
label var late_period "1 = Late period (2014-2019), 0 = Early (2009-2013)"
tab late_period

* 2c. Market concentration
* Compute item-level median number of bidding firms
bysort item: egen item_med_firms = median(n_firms_bids)
* Overall median of the item-level medians
quietly summarize item_med_firms, detail
local overall_med_firms = r(p50)
gen high_competition = (item_med_firms > `overall_med_firms')
label var high_competition "1 = Above-median item-level competition"
di "Median of item-level median firms: `overall_med_firms'"
tab high_competition

* 2d. PBU size
* Total transactions per PBU
bysort pbu_code: egen pbu_size = count(pbu_code)
quietly summarize pbu_size, detail
local med_pbu_size = r(p50)
gen large_pbu = (pbu_size > `med_pbu_size')
label var large_pbu "1 = Above-median PBU size (by transaction count)"
di "Median PBU size (transactions): `med_pbu_size'"
tab large_pbu


* 3. HETEROGENEITY 1: SUS COMPONENT TYPE (Basic vs Specialized)
di ""
di "  HETEROGENEITY 1: SUS COMPONENT TYPE"

* 3a. Split-sample regressions
eststo clear

* Basic SUS component
eststo basic: reghdfe bid_price_log urgent if po_firm_winner==1 & sus_basic==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_basic = _b[urgent]
local se_basic = _se[urgent]
local n_basic = e(N)

* Non-basic (Specialized/Strategic/Other)
eststo special: reghdfe bid_price_log urgent if po_firm_winner==1 & sus_basic==0, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_special = _b[urgent]
local se_special = _se[urgent]
local n_special = e(N)

esttab basic special using "`outdir'/heterogeneity_sus_split.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: SUS Component — Split Sample") ///
    mtitles("Basic Component" "Specialized/Other") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU.") ///
    compress replace

* 3b. Pooled interaction model
eststo clear
eststo interaction: reghdfe bid_price_log urgent##sus_basic if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

esttab interaction using "`outdir'/heterogeneity_sus_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: SUS Component — Interaction Model") ///
    mtitles("Negotiated Price (log)") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU. sus_basic=1 for Basic Component items.") ///
    compress replace

di ""
di "SUS Component split:"
di "  Basic:       coef = " %9.4f `b_basic' "  SE = " %9.4f `se_basic' "  N = " `n_basic'
di "  Specialized: coef = " %9.4f `b_special' "  SE = " %9.4f `se_special' "  N = " `n_special'
di "  Interaction p-value: " %9.4f (2*ttail(e(df_r), abs(_b[1.urgent#1.sus_basic]/_se[1.urgent#1.sus_basic])))


* 4. HETEROGENEITY 2: TIME PERIOD (Early vs Late)
di ""
di "  HETEROGENEITY 2: TIME PERIOD"

* 4a. Split-sample regressions
eststo clear

* Early period (2009-2013)
eststo early: reghdfe bid_price_log urgent if po_firm_winner==1 & late_period==0, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_early = _b[urgent]
local se_early = _se[urgent]
local n_early = e(N)

* Late period (2014-2019)
eststo late: reghdfe bid_price_log urgent if po_firm_winner==1 & late_period==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_late = _b[urgent]
local se_late = _se[urgent]
local n_late = e(N)

esttab early late using "`outdir'/heterogeneity_period_split.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: Time Period — Split Sample") ///
    mtitles("Early (2009-2013)" "Late (2014-2019)") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU.") ///
    compress replace

* 4b. Pooled interaction model
eststo clear
eststo interaction: reghdfe bid_price_log urgent##late_period if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

esttab interaction using "`outdir'/heterogeneity_period_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: Time Period — Interaction Model") ///
    mtitles("Negotiated Price (log)") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU. late_period=1 for 2014-2019.") ///
    compress replace

di ""
di "Time period split:"
di "  Early (2009-2013): coef = " %9.4f `b_early' "  SE = " %9.4f `se_early' "  N = " `n_early'
di "  Late  (2014-2019): coef = " %9.4f `b_late' "  SE = " %9.4f `se_late' "  N = " `n_late'
di "  Interaction p-value: " %9.4f (2*ttail(e(df_r), abs(_b[1.urgent#1.late_period]/_se[1.urgent#1.late_period])))


* 5. HETEROGENEITY 3: MARKET CONCENTRATION (High vs Low Competition)
di ""
di "  HETEROGENEITY 3: MARKET CONCENTRATION"

* 5a. Split-sample regressions
eststo clear

* Low competition (below-median firms)
eststo low_comp: reghdfe bid_price_log urgent if po_firm_winner==1 & high_competition==0, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_low = _b[urgent]
local se_low = _se[urgent]
local n_low = e(N)

* High competition (above-median firms)
eststo high_comp: reghdfe bid_price_log urgent if po_firm_winner==1 & high_competition==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_high = _b[urgent]
local se_high = _se[urgent]
local n_high = e(N)

esttab low_comp high_comp using "`outdir'/heterogeneity_competition_split.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: Market Concentration — Split Sample") ///
    mtitles("Low Competition" "High Competition") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU. Split at median of item-level median bidders.") ///
    compress replace

* 5b. Pooled interaction model
eststo clear
eststo interaction: reghdfe bid_price_log urgent##high_competition if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

esttab interaction using "`outdir'/heterogeneity_competition_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: Market Concentration — Interaction Model") ///
    mtitles("Negotiated Price (log)") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU. high_competition=1 for above-median item competition.") ///
    compress replace

di ""
di "Market concentration split:"
di "  Low competition:  coef = " %9.4f `b_low' "  SE = " %9.4f `se_low' "  N = " `n_low'
di "  High competition: coef = " %9.4f `b_high' "  SE = " %9.4f `se_high' "  N = " `n_high'
di "  Interaction p-value: " %9.4f (2*ttail(e(df_r), abs(_b[1.urgent#1.high_competition]/_se[1.urgent#1.high_competition])))


* 6. HETEROGENEITY 4: PBU SIZE (Large vs Small)
di ""
di "  HETEROGENEITY 4: PBU SIZE"

* 6a. Split-sample regressions
eststo clear

* Small PBUs (below-median transactions)
eststo small_pbu: reghdfe bid_price_log urgent if po_firm_winner==1 & large_pbu==0, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_small = _b[urgent]
local se_small = _se[urgent]
local n_small = e(N)

* Large PBUs (above-median transactions)
eststo large_pbu: reghdfe bid_price_log urgent if po_firm_winner==1 & large_pbu==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)
local b_large = _b[urgent]
local se_large = _se[urgent]
local n_large = e(N)

esttab small_pbu large_pbu using "`outdir'/heterogeneity_pbu_size_split.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: PBU Size — Split Sample") ///
    mtitles("Small PBU" "Large PBU") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU. Split at median PBU transaction count.") ///
    compress replace

* 6b. Pooled interaction model
eststo clear
eststo interaction: reghdfe bid_price_log urgent##large_pbu if po_firm_winner==1, ///
    absorb(item_id2 year pbu_id) vce(cluster pbu_id)

esttab interaction using "`outdir'/heterogeneity_pbu_size_interaction.rtf", ///
    b(%9.4f) se(%9.4f) ar2 ///
    title("Heterogeneity: PBU Size — Interaction Model") ///
    mtitles("Negotiated Price (log)") ///
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU. large_pbu=1 for above-median PBU transaction count.") ///
    compress replace

di ""
di "PBU size split:"
di "  Small PBU: coef = " %9.4f `b_small' "  SE = " %9.4f `se_small' "  N = " `n_small'
di "  Large PBU: coef = " %9.4f `b_large' "  SE = " %9.4f `se_large' "  N = " `n_large'
di "  Interaction p-value: " %9.4f (2*ttail(e(df_r), abs(_b[1.urgent#1.large_pbu]/_se[1.urgent#1.large_pbu])))


* 7. Summary table
di ""
di "  HETEROGENEITY SUMMARY"
di ""
di "Dimension                  | Group 1 (coef)  | Group 2 (coef)  | Interaction p"
di "---------------------------+-----------------+-----------------+---------------"
di "1. SUS Component           | Basic: " %7.4f `b_basic' "   | Special: " %7.4f `b_special' " |"
di "2. Time Period             | Early: " %7.4f `b_early' "   | Late:    " %7.4f `b_late' "  |"
di "3. Market Concentration    | Low:   " %7.4f `b_low' "   | High:    " %7.4f `b_high' "  |"
di "4. PBU Size                | Small: " %7.4f `b_small' "   | Large:   " %7.4f `b_large' "  |"
di ""
di "Note: All regressions use Item+Year+PBU FE, clustered SE at PBU level."
di "Positive coefficient = urgent purchases pay more than ordinary."


timer off 1
timer list
di ""
di "All heterogeneity tables saved to: v2/analysis/results/"
