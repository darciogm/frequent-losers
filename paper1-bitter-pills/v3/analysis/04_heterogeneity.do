* V3 Heterogeneity Analyses
* Source: /tmp/v3_prepared.dta (full BEC_JUD sample, CONVITE + PREGÃO)
*
* 4 dimensions:
*   1. SUS component type (Basic vs Specialized) — only matched items
*   2. Time period (Early 2009-2013 vs Late 2014+)
*   3. Market concentration (Low vs High competition)
*   4. PBU size (Small vs Large)
*
* Base spec: Table 6 total effect (Item+Year+PBU FE, cluster PBU)

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

di "Analysis sample size: " _N


* 2. HETEROGENEITY 1: SUS COMPONENT TYPE (Basic vs Specialized)
di ""
di "  HETEROGENEITY 1: SUS COMPONENT TYPE"

tab sus_basic, missing

* Split-sample regressions
eststo clear

* Basic SUS component (only for items matched to subsample)
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
    note("Standard errors clustered at PBU level. *** p<0.01, ** p<0.05, * p<0.1. FE: Item, Year, PBU. Only items matched to SUS subsample.") ///
    compress replace

* Pooled interaction model
eststo clear
eststo interaction: reghdfe bid_price_log urgent##sus_basic if po_firm_winner==1 & sus_basic != ., ///
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
capture di "  Interaction p-value: " %9.4f (2*ttail(e(df_r), abs(_b[1.urgent#1.sus_basic]/_se[1.urgent#1.sus_basic])))


* 3. HETEROGENEITY 2: TIME PERIOD (Early vs Late)
di ""
di "  HETEROGENEITY 2: TIME PERIOD"

tab late_period

* Split-sample regressions
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

* Pooled interaction model
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


* 4. HETEROGENEITY 3: MARKET CONCENTRATION (High vs Low Competition)
di ""
di "  HETEROGENEITY 3: MARKET CONCENTRATION"

tab high_competition

* Split-sample regressions
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

* Pooled interaction model
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


* 5. HETEROGENEITY 4: PBU SIZE (Large vs Small)
di ""
di "  HETEROGENEITY 4: PBU SIZE"

tab large_pbu

* Split-sample regressions
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

* Pooled interaction model
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


* 6. Summary table
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
di "All heterogeneity tables saved to: v3/results/"
