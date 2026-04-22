* V3 Descriptive Statistics Table
* Source: /tmp/v3_prepared.dta (full BEC_JUD sample, CONVITE + PREGÃO)
* Sample: Items with at least one ordinary AND one litigated purchase

clear all
set more off
set max_memory 14g
capture set processors 16

timer clear
timer on 1

use "/tmp/v3_prepared.dta", clear

* 1. Restrict sample: items with both ordinary and litigated
keep if has_litigated == 1 & has_ordinary == 1
di "After keeping items with both ordinary and litigated: " _N

* 2. Winsorize continuous variables at 1%/99%
foreach v in bid_price_ref bid_price bid_qty n_firms_bids n_bids_bids {
    capture confirm variable `v'
    if _rc == 0 {
        quietly summarize `v', detail
        local p1 = r(p1)
        local p99 = r(p99)
        replace `v' = `p1' if `v' < `p1' & `v' != .
        replace `v' = `p99' if `v' > `p99' & `v' != .
    }
}

* 3. Regenerate log variables after winsorization
capture drop bid_qty_log bid_price_ref_log bid_price_log ln_n_firms
gen bid_qty_log = ln(bid_qty)
gen bid_price_ref_log = ln(bid_price_ref)
gen bid_price_log = ln(bid_price)
gen ln_n_firms = ln(n_firms_bids)

capture confirm variable n_bids_bids
if _rc == 0 {
    gen ln_n_bids = ln(n_bids_bids)
}

* 4. Output directories
local texdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v3/manuscript"
local rtfdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v3/results"

* 5. Generate LaTeX table
capture file close tex
file open tex using "`texdir'/table_desc_stats.tex", write replace

file write tex "\begin{table}[ht]" _n
file write tex "  \centering" _n
file write tex "  \caption{Descriptive Statistics by Purchase Type}" _n
file write tex "  \label{tab:desc_stats}" _n
file write tex "  \small" _n
file write tex "  \begin{threeparttable}" _n
file write tex "  \begin{tabular}{lccccc}" _n
file write tex "    \hline\hline" _n
file write tex "    & \multicolumn{3}{c}{Purchase Type} & \multicolumn{2}{c}{Difference in Means} \\" _n
file write tex "    \cmidrule(lr){2-4} \cmidrule(lr){5-6}" _n
file write tex "    & (1) Ordinary & (2) Administrative & (3) Litigated & (1)--(3) & (2)--(3) \\" _n
file write tex "    \hline" _n

* 6. Helper program
capture program drop write_row
program define write_row
    args varname label fhandle fmt

    quietly summarize `varname' if purchase_type == 0
    local m0 : di `fmt' r(mean)
    local sd0 : di `fmt' r(sd)

    quietly summarize `varname' if purchase_type == 1
    local m1 : di `fmt' r(mean)
    local sd1 : di `fmt' r(sd)

    quietly summarize `varname' if purchase_type == 2
    local m2 : di `fmt' r(mean)
    local sd2 : di `fmt' r(sd)

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

    local m0 = strtrim("`m0'")
    local m1 = strtrim("`m1'")
    local m2 = strtrim("`m2'")
    local sd0 = strtrim("`sd0'")
    local sd1 = strtrim("`sd1'")
    local sd2 = strtrim("`sd2'")
    local diff_ol = strtrim("`diff_ol'")
    local diff_al = strtrim("`diff_al'")
    local p_ol_fmt : di %5.3f `p_ol'
    local p_al_fmt : di %5.3f `p_al'
    local p_ol_fmt = strtrim("`p_ol_fmt'")
    local p_al_fmt = strtrim("`p_al_fmt'")

    file write `fhandle' "    `label' & `m0' & `m1' & `m2' & `diff_ol'`stars_ol' & `diff_al'`stars_al' \\" _n
    file write `fhandle' "    & (`sd0') & (`sd1') & (`sd2') & [`p_ol_fmt'] & [`p_al_fmt'] \\[3pt]" _n
end

* 7. Panel A: Levels
file write tex "    \multicolumn{6}{l}{\textit{Panel A: Levels}} \\[3pt]" _n
write_row bid_price_ref "Reference~Price" tex %12.2f
write_row bid_price "Negotiated~Price" tex %12.2f
write_row bid_qty "Quantity" tex %12.0f
write_row n_firms_bids "No.~Participant~Firms" tex %12.2f

capture confirm variable n_bids_bids
if _rc == 0 {
    write_row n_bids_bids "No.~Bids" tex %12.2f
}

* 8. Panel B: Log Transformations
file write tex "    \hline" _n
file write tex "    \multicolumn{6}{l}{\textit{Panel B: Log Transformations (used in regressions)}} \\[3pt]" _n
write_row bid_price_ref_log "Log~Reference~Price" tex %12.3f
write_row bid_price_log "Log~Negotiated~Price" tex %12.3f
write_row bid_qty_log "Log~Quantity" tex %12.3f
write_row ln_n_firms "Log~No.~Firms" tex %12.3f

capture confirm variable ln_n_bids
if _rc == 0 {
    write_row ln_n_bids "Log~No.~Bids" tex %12.3f
}

* 9. Panel C: Tender Characteristics
file write tex "    \hline" _n
file write tex "    \multicolumn{6}{l}{\textit{Panel C: Tender Characteristics}} \\[3pt]" _n
write_row po_firm_winner "Successful~Tender~(\%)" tex %12.3f

* 10. Observations and footer
quietly count if purchase_type == 0
local n0 : di %12.0gc r(N)
local n0 = strtrim("`n0'")
quietly count if purchase_type == 1
local n1 : di %12.0gc r(N)
local n1 = strtrim("`n1'")
quietly count if purchase_type == 2
local n2 : di %12.0gc r(N)
local n2 = strtrim("`n2'")

quietly tab item
local n_items : di %12.0gc r(r)
local n_items = strtrim("`n_items'")

file write tex "    \hline" _n
file write tex "    Observations & `n0' & `n1' & `n2' & & \\" _n

file write tex "    \hline\hline" _n
file write tex "  \end{tabular}" _n
file write tex "  \begin{tablenotes}" _n
file write tex "    \small" _n
file write tex `"    \item \textit{Notes:} Sample restricted to items with at least one ordinary and one litigated purchase (`n_items' unique items). Includes CONVITE and PREG\~AO auction types. Continuous variables winsorized at the 1st and 99th percentiles. Standard deviations in parentheses."' _n
file write tex `"    \textit{p}-values of two-sided \textit{t}-tests for equality of means in brackets."' _n
file write tex "    *** \textit{p}$<$0.01, ** \textit{p}$<$0.05, * \textit{p}$<$0.1." _n
file write tex "    Column (4) reports the difference between Ordinary and Litigated purchases." _n
file write tex "    Column (5) reports the difference between Administrative and Litigated purchases." _n
file write tex "  \end{tablenotes}" _n
file write tex "  \end{threeparttable}" _n
file write tex "\end{table}" _n

file close tex

* 11. RTF output via esttab
* Create a summary stats RTF using tabstat output
quietly {
    estpost tabstat bid_price_ref bid_price bid_qty n_firms_bids ///
        bid_price_ref_log bid_price_log bid_qty_log ln_n_firms po_firm_winner ///
        if purchase_type == 0, statistics(mean sd N) columns(statistics)
}
esttab using "`rtfdir'/desc_stats.rtf", ///
    cells("mean(fmt(%12.3f)) sd(fmt(%12.3f)) count(fmt(%12.0f))") ///
    title("Descriptive Statistics — Ordinary Purchases") ///
    noobs compress replace

quietly {
    estpost tabstat bid_price_ref bid_price bid_qty n_firms_bids ///
        bid_price_ref_log bid_price_log bid_qty_log ln_n_firms po_firm_winner ///
        if purchase_type == 1, statistics(mean sd N) columns(statistics)
}
esttab using "`rtfdir'/desc_stats.rtf", ///
    cells("mean(fmt(%12.3f)) sd(fmt(%12.3f)) count(fmt(%12.0f))") ///
    title("Descriptive Statistics — Administrative Purchases") ///
    noobs compress append

quietly {
    estpost tabstat bid_price_ref bid_price bid_qty n_firms_bids ///
        bid_price_ref_log bid_price_log bid_qty_log ln_n_firms po_firm_winner ///
        if purchase_type == 2, statistics(mean sd N) columns(statistics)
}
esttab using "`rtfdir'/desc_stats.rtf", ///
    cells("mean(fmt(%12.3f)) sd(fmt(%12.3f)) count(fmt(%12.0f))") ///
    title("Descriptive Statistics — Litigated Purchases") ///
    noobs compress append

* 12. Console summary
di ""
di "  SAMPLE SUMMARY"
di "  Items with >= 1 ordinary and >= 1 litigated purchase"
di "  Total observations: " _N
di "  Ordinary: `n0'"
di "  Administrative: `n1'"
di "  Litigated: `n2'"
di "  Unique items: `n_items'"
di ""

tabstat bid_price_ref bid_price bid_qty n_firms_bids, ///
    by(purchase_type) statistics(mean sd N) format(%12.2f) columns(statistics)
di ""
tabstat bid_price_ref_log bid_price_log bid_qty_log ln_n_firms po_firm_winner, ///
    by(purchase_type) statistics(mean sd N) format(%12.3f) columns(statistics)

di ""
di "  LaTeX table saved to: v3/manuscript/table_desc_stats.tex"
di "  RTF saved to: v3/results/desc_stats.rtf"

timer off 1
timer list
