********************************************************************************
* Descriptive Statistics Table
* Paper: Bitter Pills to Swallow
* Generates Table 1: Descriptive Statistics by Purchase Type
********************************************************************************

clear all
set more off

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

* --------------------------------------------------------------------------
* 1. Create purchase type categories
* --------------------------------------------------------------------------
gen purchase_type = 0
replace purchase_type = 1 if adm == 2
replace purchase_type = 2 if jud == 1

label define ptype 0 "Ordinary" 1 "Administrative" 2 "Litigated"
label values purchase_type ptype

* Urgent indicator (admin + litigated)
gen urgent = (purchase_type > 0)

* --------------------------------------------------------------------------
* 2. Ensure log variables exist
* --------------------------------------------------------------------------
capture drop bid_qty_log
capture drop bid_price_ref_log
capture drop bid_price_log
gen bid_qty_log = ln(bid_qty)
gen bid_price_ref_log = ln(bid_price_ref)
gen bid_price_log = ln(bid_price)

* Log of number of firms and bids
gen ln_n_firms = ln(n_firms_bids)
gen ln_n_bids = ln(n_bids_bids)

* --------------------------------------------------------------------------
* 3. Generate LaTeX table
* --------------------------------------------------------------------------
capture file close tex
file open tex using "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/manuscript/table_desc_stats.tex", write replace

* Header
file write tex "\begin{table}[ht]" _n
file write tex "  \centering" _n
file write tex "  \caption{Descriptive Statistics by Purchase Type}" _n
file write tex "  \label{tab:desc_stats}" _n
file write tex "  \small" _n
file write tex "  \begin{tabular}{lcccccc}" _n
file write tex "    \hline\hline" _n
file write tex "    & \multicolumn{3}{c}{Purchase Type} & \multicolumn{2}{c}{Difference in Means} \\" _n
file write tex "    \cmidrule(lr){2-4} \cmidrule(lr){5-6}" _n
file write tex "    & (1) Ordinary & (2) Administrative & (3) Litigated & (1)--(3) & (2)--(3) \\" _n
file write tex "    \hline" _n
file write tex "    \multicolumn{6}{l}{\textit{Panel A: Levels}} \\" _n
file write tex "    [3pt]" _n

* --------------------------------------------------------------------------
* 4. Helper program to write one row
* --------------------------------------------------------------------------
capture program drop write_row
program define write_row
    args varname label fhandle fmt

    * Stats for Ordinary (purchase_type == 0)
    quietly summarize `varname' if purchase_type == 0
    local m0 : di `fmt' r(mean)
    local sd0 : di `fmt' r(sd)
    local n0 = r(N)

    * Stats for Administrative (purchase_type == 1)
    quietly summarize `varname' if purchase_type == 1
    local m1 : di `fmt' r(mean)
    local sd1 : di `fmt' r(sd)
    local n1 = r(N)

    * Stats for Litigated (purchase_type == 2)
    quietly summarize `varname' if purchase_type == 2
    local m2 : di `fmt' r(mean)
    local sd2 : di `fmt' r(sd)
    local n2 = r(N)

    * T-test: Ordinary vs Litigated
    quietly ttest `varname' if purchase_type == 0 | purchase_type == 2, by(purchase_type)
    local diff_ol : di `fmt' (r(mu_1) - r(mu_2))
    local p_ol = r(p)
    local stars_ol ""
    if `p_ol' < 0.01 local stars_ol "***"
    else if `p_ol' < 0.05 local stars_ol "**"
    else if `p_ol' < 0.1 local stars_ol "*"

    * T-test: Administrative vs Litigated
    quietly ttest `varname' if purchase_type == 1 | purchase_type == 2, by(purchase_type)
    local diff_al : di `fmt' (r(mu_1) - r(mu_2))
    local p_al = r(p)
    local stars_al ""
    if `p_al' < 0.01 local stars_al "***"
    else if `p_al' < 0.05 local stars_al "**"
    else if `p_al' < 0.1 local stars_al "*"

    * Write mean row
    local m0 = strtrim("`m0'")
    local m1 = strtrim("`m1'")
    local m2 = strtrim("`m2'")
    local diff_ol = strtrim("`diff_ol'")
    local diff_al = strtrim("`diff_al'")

    file write `fhandle' "    `label' & `m0' & `m1' & `m2' & `diff_ol'`stars_ol' & `diff_al'`stars_al' \\" _n

    * Write SD row
    local sd0 = strtrim("`sd0'")
    local sd1 = strtrim("`sd1'")
    local sd2 = strtrim("`sd2'")

    local p_ol_fmt : di %5.3f `p_ol'
    local p_al_fmt : di %5.3f `p_al'
    local p_ol_fmt = strtrim("`p_ol_fmt'")
    local p_al_fmt = strtrim("`p_al_fmt'")

    file write `fhandle' "    & (`sd0') & (`sd1') & (`sd2') & [`p_ol_fmt'] & [`p_al_fmt'] \\" _n
    file write `fhandle' "    [3pt]" _n
end

* --------------------------------------------------------------------------
* 5. Write Panel A: Levels
* --------------------------------------------------------------------------
write_row bid_price_ref "Reference Price" tex %12.2f
write_row bid_price "Negotiated Price" tex %12.2f
write_row bid_qty "Quantity" tex %12.0f
write_row n_firms_bids "No. Participant Firms" tex %12.2f
write_row n_bids_bids "No. Bids" tex %12.2f

* Separator
file write tex "    [3pt]" _n
file write tex "    \hline" _n
file write tex "    \multicolumn{6}{l}{\textit{Panel B: Log Transformations (used in regressions)}} \\" _n
file write tex "    [3pt]" _n

* --------------------------------------------------------------------------
* 6. Write Panel B: Log Transformations
* --------------------------------------------------------------------------
write_row bid_price_ref_log "Log Reference Price" tex %12.4f
write_row bid_price_log "Log Negotiated Price" tex %12.4f
write_row bid_qty_log "Log Quantity" tex %12.4f
write_row ln_n_firms "Log No. Firms" tex %12.4f
write_row ln_n_bids "Log No. Bids" tex %12.4f

* Separator
file write tex "    [3pt]" _n
file write tex "    \hline" _n
file write tex "    \multicolumn{6}{l}{\textit{Panel C: Tender Characteristics}} \\" _n
file write tex "    [3pt]" _n

* --------------------------------------------------------------------------
* 7. Write Panel C: Tender Characteristics
* --------------------------------------------------------------------------
write_row po_firm_winner "Successful Tender (\%)" tex %12.4f
write_row pregao "Preg\~ao Auction (\%)" tex %12.4f

* --------------------------------------------------------------------------
* 8. Observations row and footer
* --------------------------------------------------------------------------
* Get Ns
quietly count if purchase_type == 0
local n0 : di %12.0gc r(N)
local n0 = strtrim("`n0'")
quietly count if purchase_type == 1
local n1 : di %12.0gc r(N)
local n1 = strtrim("`n1'")
quietly count if purchase_type == 2
local n2 : di %12.0gc r(N)
local n2 = strtrim("`n2'")

file write tex "    [3pt]" _n
file write tex "    \hline" _n
file write tex "    Observations & `n0' & `n1' & `n2' & & \\" _n
file write tex "    \hline\hline" _n

* Notes
file write tex "  \end{tabular}" _n
file write tex "  \begin{tablenotes}" _n
file write tex "    \small" _n
file write tex "    \item \textit{Notes:} Standard deviations in parentheses. $p$-values of two-sided $t$-tests for equality of means in brackets." _n
file write tex "    *** $p<0.01$, ** $p<0.05$, * $p<0.1$." _n
file write tex "    Columns (1)--(3) report means with standard deviations below." _n
file write tex "    Column (4) reports the difference between Ordinary and Litigated purchases." _n
file write tex "    Column (5) reports the difference between Administrative and Litigated purchases." _n
file write tex "  \end{tablenotes}" _n
file write tex "\end{table}" _n

file close tex

* --------------------------------------------------------------------------
* 9. Also generate an RTF version for easy viewing
* --------------------------------------------------------------------------
di ""
di "=============================================="
di "  DESCRIPTIVE STATISTICS BY PURCHASE TYPE"
di "=============================================="
di ""

di "--- Panel A: Levels ---"
di ""
tabstat bid_price_ref bid_price bid_qty n_firms_bids n_bids_bids, by(purchase_type) statistics(mean sd N) format(%12.2f) columns(statistics)

di ""
di "--- Panel B: Log Transformations ---"
di ""
tabstat bid_price_ref_log bid_price_log bid_qty_log ln_n_firms ln_n_bids, by(purchase_type) statistics(mean sd N) format(%12.4f) columns(statistics)

di ""
di "--- Panel C: Tender Characteristics ---"
di ""
tabstat po_firm_winner pregao, by(purchase_type) statistics(mean sd N) format(%12.4f) columns(statistics)

di ""
di "--- T-tests: Ordinary vs Litigated ---"
di ""
foreach v in bid_price_ref bid_price bid_qty n_firms_bids n_bids_bids bid_price_ref_log bid_price_log bid_qty_log ln_n_firms ln_n_bids po_firm_winner pregao {
    di "`v':"
    quietly ttest `v' if purchase_type == 0 | purchase_type == 2, by(purchase_type)
    di "  Diff = " %9.4f (r(mu_1) - r(mu_2)) "  p-value = " %6.4f r(p)
}

di ""
di "--- T-tests: Administrative vs Litigated ---"
di ""
foreach v in bid_price_ref bid_price bid_qty n_firms_bids n_bids_bids bid_price_ref_log bid_price_log bid_qty_log ln_n_firms ln_n_bids po_firm_winner pregao {
    di "`v':"
    quietly ttest `v' if purchase_type == 1 | purchase_type == 2, by(purchase_type)
    di "  Diff = " %9.4f (r(mu_1) - r(mu_2)) "  p-value = " %6.4f r(p)
}

di ""
di "=============================================="
di "  LaTeX table saved to: manuscript/table_desc_stats.tex"
di "=============================================="
