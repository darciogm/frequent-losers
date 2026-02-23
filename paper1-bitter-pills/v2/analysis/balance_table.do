********************************************************************************
* Balance Table: Administrative vs Litigated Purchases
* Paper: Bitter Pills to Swallow
* Suggestion 2: Compare observable characteristics between admin and litigated
* to validate the "under the gun" identification
********************************************************************************

clear all
set more off
set max_memory 14g

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

* --------------------------------------------------------------------------
* 1. Create purchase type and restrict sample
* --------------------------------------------------------------------------
gen purchase_type = 0
replace purchase_type = 1 if adm == 2
replace purchase_type = 2 if jud == 1

* Pregão only
keep if po_proc_code == 3

* Items with at least one ordinary and one litigated purchase
bysort item: egen has_litigated = max(purchase_type == 2)
bysort item: egen has_ordinary = max(purchase_type == 0)
keep if has_litigated == 1 & has_ordinary == 1

* For the balance table: keep only urgent purchases (admin + litigated)
keep if purchase_type == 1 | purchase_type == 2

* Indicator: 1 = Administrative, 0 = Litigated
gen is_admin = (purchase_type == 1)

di "Sample: Administrative = "
count if is_admin == 1
di "Sample: Litigated = "
count if is_admin == 0

* --------------------------------------------------------------------------
* 2. Winsorize continuous variables at 1%/99%
* --------------------------------------------------------------------------
foreach v in bid_price_ref bid_price bid_qty n_firms_bids n_bids_bids {
    quietly summarize `v', detail
    local p1 = r(p1)
    local p99 = r(p99)
    replace `v' = `p1' if `v' < `p1' & `v' != .
    replace `v' = `p99' if `v' > `p99' & `v' != .
}

* --------------------------------------------------------------------------
* 3. Generate variables
* --------------------------------------------------------------------------
capture drop bid_qty_log bid_price_ref_log bid_price_log
gen bid_qty_log = ln(bid_qty)
gen bid_price_ref_log = ln(bid_price_ref)
gen bid_price_log = ln(bid_price)
gen ln_n_firms = ln(n_firms_bids)
gen ln_n_bids = ln(n_bids_bids)

* SUS list indicator (if available)
capture gen sus_list = (padronizadosus == "Sim") if padronizadosus != ""

* São Paulo capital
capture gen sp_city = 0
capture replace sp_city = 1 if pbu_city_descr == "SAO PAULO"

* Year variable for distribution
capture destring year, replace

* Number of items per PO
bysort po: gen n_items_po = _N

* --------------------------------------------------------------------------
* 4. Generate LaTeX balance table
* --------------------------------------------------------------------------
capture file close tex
file open tex using "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/v2/manuscript/table_balance.tex", write replace

file write tex "\begin{table}[ht]" _n
file write tex "  \centering" _n
file write tex "  \caption{Balance Table: Administrative vs. Litigated Purchases}" _n
file write tex "  \label{tab:balance}" _n
file write tex "  \small" _n
file write tex "  \begin{threeparttable}" _n
file write tex "  \begin{tabular}{lccccc}" _n
file write tex "    \hline\hline" _n
file write tex "    & (1) & (2) & (3) & (4) & (5) \\" _n
file write tex "    & Administrative & Litigated & Difference & \textit{t}-stat & \textit{p}-value \\" _n
file write tex "    \hline" _n

* --------------------------------------------------------------------------
* 5. Helper program
* --------------------------------------------------------------------------
capture program drop write_balance_row
program define write_balance_row
    args varname label fhandle fmt

    quietly summarize `varname' if is_admin == 1
    local m1 : di `fmt' r(mean)
    local sd1 : di `fmt' r(sd)
    local n1 = r(N)

    quietly summarize `varname' if is_admin == 0
    local m0 : di `fmt' r(mean)
    local sd0 : di `fmt' r(sd)
    local n0 = r(N)

    * T-test
    capture ttest `varname', by(is_admin)
    local diff : di `fmt' (r(mu_2) - r(mu_1))
    local tstat : di %6.2f r(t)
    local pval : di %5.3f r(p)

    local stars ""
    if r(p) < 0.01 local stars "***"
    else if r(p) < 0.05 local stars "**"
    else if r(p) < 0.1 local stars "*"

    local m1 = strtrim("`m1'")
    local m0 = strtrim("`m0'")
    local sd1 = strtrim("`sd1'")
    local sd0 = strtrim("`sd0'")
    local diff = strtrim("`diff'")
    local tstat = strtrim("`tstat'")
    local pval = strtrim("`pval'")

    file write `fhandle' "    `label' & `m1' & `m0' & `diff'`stars' & `tstat' & `pval' \\" _n
    file write `fhandle' "    & (`sd1') & (`sd0') & & & \\[3pt]" _n
end

* --------------------------------------------------------------------------
* 6. Panel A: Procurement Outcomes
* --------------------------------------------------------------------------
file write tex "    \multicolumn{6}{l}{\textit{Panel A: Procurement Outcomes}} \\[3pt]" _n
write_balance_row bid_price_ref "Reference~Price" tex %12.2f
write_balance_row bid_price "Negotiated~Price" tex %12.2f
write_balance_row bid_qty "Quantity" tex %12.0f
write_balance_row bid_price_ref_log "Log~Reference~Price" tex %12.3f
write_balance_row bid_price_log "Log~Negotiated~Price" tex %12.3f
write_balance_row bid_qty_log "Log~Quantity" tex %12.3f

* --------------------------------------------------------------------------
* 7. Panel B: Market Structure
* --------------------------------------------------------------------------
file write tex "    \hline" _n
file write tex "    \multicolumn{6}{l}{\textit{Panel B: Market Structure}} \\[3pt]" _n
write_balance_row n_firms_bids "No.~Participant~Firms" tex %12.2f
write_balance_row n_bids_bids "No.~Bids" tex %12.2f
write_balance_row ln_n_firms "Log~No.~Firms" tex %12.3f
write_balance_row ln_n_bids "Log~No.~Bids" tex %12.3f
write_balance_row po_firm_winner "Successful~Tender~(\%)" tex %12.3f

* --------------------------------------------------------------------------
* 8. Panel C: Purchase Characteristics
* --------------------------------------------------------------------------
file write tex "    \hline" _n
file write tex "    \multicolumn{6}{l}{\textit{Panel C: Purchase Characteristics}} \\[3pt]" _n
write_balance_row sp_city "S\~ao~Paulo~Capital~(\%)" tex %12.3f
write_balance_row n_items_po "Items~per~Purchase~Order" tex %12.2f

* --------------------------------------------------------------------------
* 9. Observations and footer
* --------------------------------------------------------------------------
quietly count if is_admin == 1
local n1 : di %12.0gc r(N)
local n1 = strtrim("`n1'")
quietly count if is_admin == 0
local n0 : di %12.0gc r(N)
local n0 = strtrim("`n0'")

quietly tab item
local n_items : di %12.0gc r(r)
local n_items = strtrim("`n_items'")

file write tex "    \hline" _n
file write tex "    Observations & `n1' & `n0' & & & \\" _n
file write tex "    Unique items & \multicolumn{2}{c}{`n_items'} & & & \\" _n
file write tex "    \hline\hline" _n
file write tex "  \end{tabular}" _n
file write tex "  \begin{tablenotes}" _n
file write tex "    \small" _n
file write tex `"    \item \textit{Notes:} Sample restricted to urgent purchases (administrative and litigated) in preg\~ao auctions for items with at least one ordinary and one litigated purchase. Continuous variables winsorized at the 1st and 99th percentiles. Standard deviations in parentheses. Column (3) reports the difference in means (Administrative minus Litigated). Column (4) reports the \textit{t}-statistic and column (5) the \textit{p}-value from a two-sided \textit{t}-test for equality of means."' _n
file write tex "    *** \textit{p}$<$0.01, ** \textit{p}$<$0.05, * \textit{p}$<$0.1." _n
file write tex "  \end{tablenotes}" _n
file write tex "  \end{threeparttable}" _n
file write tex "\end{table}" _n

file close tex

* --------------------------------------------------------------------------
* 10. Console summary
* --------------------------------------------------------------------------
di ""
di "=============================================="
di "  BALANCE TABLE: ADMIN vs LITIGATED"
di "=============================================="
di "  Administrative: `n1'"
di "  Litigated: `n0'"
di "  Unique items: `n_items'"
di "=============================================="
di ""

foreach v in bid_price_ref bid_price bid_qty bid_price_ref_log bid_price_log bid_qty_log n_firms_bids n_bids_bids ln_n_firms ln_n_bids po_firm_winner sp_city n_items_po {
    di "`v':"
    quietly ttest `v', by(is_admin)
    di "  Admin = " %9.3f r(mu_2) "  Litigated = " %9.3f r(mu_1) "  Diff = " %9.3f (r(mu_2)-r(mu_1)) "  p = " %6.4f r(p)
}

di ""
di "  LaTeX table saved to: v2/manuscript/table_balance.tex"
