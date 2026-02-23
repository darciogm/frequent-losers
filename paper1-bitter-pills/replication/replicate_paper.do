********************************************************************************
* replicate_paper.do
*
* Replication of Published Manuscript Table Specifications
* Paper: "Bitter Pills to Swallow: The Enforcement Costs of Health Litigation"
*
* Applies the EXACT specifications from the published manuscript to the
* available dataset. Methodology:
*   - OLS with explicit dummies (col 1) + xtreg, fe (cols 2-4)
*   - Treatment variable: jud_adm (= "urgent" in manuscript)
*   - Controls: type_mgmt, pregao (sealed-bid), bid_qty_log where applicable
*   - Sample: All auction types (CONVITE + PREGAO; no restriction to pregao)
*   - Standard errors: default (no clustering, matching original manuscript)
*   - No winsorization of outcome variables
*
* Note on N discrepancy:
*   Manuscript reports N = 59,708 winners for Tables 4-5.
*   Our available dataset has ~41,421 total obs (~35,377 winners).
*   The original larger dataset is unavailable (corrupted archive).
*   Any remaining coefficient differences are attributable to the dataset.
*
* Reference files:
*   - Manuscript tables: manuscript/EmpiricalStrategy.tex
*   - Original code: analysis/Final Code.do
*   - v2 analysis: v2/analysis/clustered_regressions.do
********************************************************************************

clear all
set more off
set max_memory 14g
set matsize 11000

timer clear
timer on 1


* ==========================================================================
* 1. LOAD DATA
* ==========================================================================

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

di ""
di "==========================================="
di "  DATA LOADED"
di "==========================================="
di "Total observations: " _N


* ==========================================================================
* 2. VARIABLE CREATION & VERIFICATION
* ==========================================================================

* --- Recreate log variables (ensure consistency) ---
capture drop bid_qty_log bid_price_ref_log bid_price_log
gen bid_qty_log = ln(bid_qty)
gen bid_price_ref_log = ln(bid_price_ref)
gen bid_price_log = ln(bid_price)
label var bid_qty_log "lquantity"
label var bid_price_ref_log "log reference price"
label var bid_price_log "log negotiated price"

* --- type_mgmt: dummy for non-direct-administration entities ---
* pbu_type_mgmt_code == "1" means Direct Administration
capture drop type_mgmt
capture confirm string variable pbu_type_mgmt_code
if _rc == 0 {
    gen type_mgmt = (pbu_type_mgmt_code != "1")
}
else {
    gen type_mgmt = (pbu_type_mgmt_code != 1)
}
label var type_mgmt "type\_mgmt"

* --- pregao: sealed-bid (electronic auction) dummy ---
capture drop pregao
gen pregao = (po_proc_code == 3)
label var pregao "sealed-bid"

* --- ln_n_firms: log number of participant firms ---
capture drop ln_n_firms
gen ln_n_firms = ln(n_firms_bids)
label var ln_n_firms "ln(firms)"

* --- is_admin: for Table 10 (admin=1 within urgent purchases) ---
* adm coding: 0 = ordinary/judicial, 2 = administrative
capture drop is_admin
gen is_admin = (adm == 2)
label var is_admin "administrative"

* --- Label treatment variable to match manuscript ---
label var jud_adm "urgent"

* --- month: derived from m_y (Stata monthly date format) ---
capture drop month
gen dm_temp = m_y
format dm_temp %10.0g
gen date_dm_temp = dofm(dm_temp)
format date_dm_temp %d
gen month = month(date_dm_temp)
drop dm_temp date_dm_temp
label var month "Calendar month"


* ==========================================================================
* 3. RECREATE DUMMY VARIABLES (fresh from current data)
* ==========================================================================

* Drop any existing dummies
foreach prefix in ditem dpbu_code dyear dm_y dmonth {
    capture drop `prefix'*
}

* Create dummies from tab
quietly tab item, gen(ditem)
quietly tab pbu_code, gen(dpbu_code)
quietly tab year, gen(dyear)
quietly tab m_y, gen(dm_y)
quietly tab month, gen(dmonth)

* Drop first dummy of each group (reference category)
drop ditem1 dpbu_code1 dyear1 dm_y1 dmonth1

* --- Encode item for xtreg panel ---
capture drop item_id
encode item, gen(item_id)
xtset item_id
label var item_id "Item panel ID"


* ==========================================================================
* 4. DIAGNOSTIC SUMMARY
* ==========================================================================

di ""
di "==========================================="
di "  SAMPLE DIAGNOSTICS"
di "==========================================="

di "Total observations: " _N
quietly count if po_firm_winner == 1
di "Winners (po_firm_winner==1): " r(N)
quietly count if po_firm_winner == 0
di "Non-winners (po_firm_winner==0): " r(N)
di ""
quietly count if jud_adm == 1
di "Urgent purchases (jud_adm==1): " r(N)
quietly count if jud_adm == 0
di "Ordinary purchases (jud_adm==0): " r(N)
di ""
quietly count if jud == 1
di "  Litigated (jud==1): " r(N)
quietly count if adm == 2
di "  Administrative (adm==2): " r(N)
di ""
di "Auction types:"
tab po_proc_code, missing
di ""
di "Management type:"
tab type_mgmt
di ""
di "Unique items:"
quietly tab item
di "  " r(r) " unique items"
di "Unique PBUs:"
quietly tab pbu_code
di "  " r(r) " unique PBUs"


* ==========================================================================
* 5. OUTPUT DIRECTORY
* ==========================================================================

local outdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/replication/results"
capture mkdir "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/replication"
capture mkdir "`outdir'"


********************************************************************************
********************************************************************************
*                          TABLE REPLICATIONS
********************************************************************************
********************************************************************************


********************************************************************************
* TABLE 4: REFERENCE PRICES — Urgent vs. Ordinary
* DV: bid_price_ref_log | Treatment: jud_adm | Sample: winners only
* Manuscript: beta(urgent) = 0.4988, 0.5243, 0.4967, 0.4725; N = 59,708
********************************************************************************
di ""
di "==========================================="
di "  TABLE 4: REFERENCE PRICES"
di "==========================================="

eststo clear

* Col 1 (OLS): Item dummies + PBU dummies + type_mgmt
eststo t4c1: quietly reg bid_price_ref_log jud_adm type_mgmt ditem* dpbu_code* ///
    if po_firm_winner==1
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2)
di "  Col 1 (OLS): jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 2 (FE): Item FE (via xtreg) + Year-Month dummies
eststo t4c2: quietly xtreg bid_price_ref_log jud_adm dm_y* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "NO"
estadd scalar myR2 = e(r2_w)
di "  Col 2 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 3 (FE): Item FE + Year-Month + PBU + type_mgmt
eststo t4c3: quietly xtreg bid_price_ref_log jud_adm type_mgmt dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 3 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 4 (FE): Item FE + Year-Month + PBU + type_mgmt + pregao
eststo t4c4: quietly xtreg bid_price_ref_log jud_adm type_mgmt pregao dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 4 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

esttab t4c1 t4c2 t4c3 t4c4 using "`outdir'/table4_ref_prices.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(jud_adm type_mgmt pregao _cons) ///
    order(jud_adm type_mgmt pregao _cons) ///
    stats(item_fe year_fe pbu_fe N myR2, ///
        labels("Item dummies" "Year dummies" "PBU dummies" "Observations" "R-squared") ///
        fmt(0 0 0 0 4)) ///
    title("Table 4: Reference Prices — Urgent vs. Ordinary Purchases") ///
    mtitles("OLS" "FE" "FE" "FE") ///
    note("Standard errors in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 5: QUANTITIES — Urgent vs. Ordinary
* DV: bid_qty_log | Treatment: jud_adm | Sample: winners only
* Manuscript: beta(urgent) = -0.8128, -0.8811, -0.8272, -0.9402; N = 59,708
********************************************************************************
di ""
di "==========================================="
di "  TABLE 5: QUANTITIES"
di "==========================================="

* Col 1 (OLS)
eststo t5c1: quietly reg bid_qty_log jud_adm type_mgmt ditem* dpbu_code* ///
    if po_firm_winner==1
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2)
di "  Col 1 (OLS): jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 2 (FE)
eststo t5c2: quietly xtreg bid_qty_log jud_adm dm_y* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "NO"
estadd scalar myR2 = e(r2_w)
di "  Col 2 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 3 (FE)
eststo t5c3: quietly xtreg bid_qty_log jud_adm type_mgmt dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 3 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 4 (FE)
eststo t5c4: quietly xtreg bid_qty_log jud_adm type_mgmt pregao dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 4 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

esttab t5c1 t5c2 t5c3 t5c4 using "`outdir'/table5_quantities.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(jud_adm type_mgmt pregao _cons) ///
    order(jud_adm type_mgmt pregao _cons) ///
    stats(item_fe year_fe pbu_fe N myR2, ///
        labels("Item dummies" "Year dummies" "PBU dummies" "Observations" "R-squared") ///
        fmt(0 0 0 0 4)) ///
    title("Table 5: Quantities — Urgent vs. Ordinary Purchases") ///
    mtitles("OLS" "FE" "FE" "FE") ///
    note("Standard errors in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 6: NEGOTIATED PRICES — Urgent vs. Ordinary
* DV: bid_price_log | Treatment: jud_adm | Sample: winners only
* Additional control: bid_qty_log (lquantity)
* Manuscript: beta(urgent) = 0.3672, 0.3526, 0.3568, 0.2680; N = 38,440
********************************************************************************
di ""
di "==========================================="
di "  TABLE 6: NEGOTIATED PRICES"
di "==========================================="

* Col 1 (OLS)
eststo t6c1: quietly reg bid_price_log jud_adm bid_qty_log type_mgmt ditem* dpbu_code* ///
    if po_firm_winner==1
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2)
di "  Col 1 (OLS): jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 2 (FE)
eststo t6c2: quietly xtreg bid_price_log jud_adm bid_qty_log dm_y* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "NO"
estadd scalar myR2 = e(r2_w)
di "  Col 2 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 3 (FE)
eststo t6c3: quietly xtreg bid_price_log jud_adm bid_qty_log type_mgmt dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 3 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 4 (FE)
eststo t6c4: quietly xtreg bid_price_log jud_adm bid_qty_log type_mgmt pregao dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 4 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

esttab t6c1 t6c2 t6c3 t6c4 using "`outdir'/table6_neg_prices.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(jud_adm bid_qty_log type_mgmt pregao _cons) ///
    order(jud_adm bid_qty_log type_mgmt pregao _cons) ///
    stats(item_fe year_fe pbu_fe N myR2, ///
        labels("Item dummies" "Year dummies" "PBU dummies" "Observations" "R-squared") ///
        fmt(0 0 0 0 4)) ///
    title("Table 6: Negotiated Prices — Urgent vs. Ordinary Purchases") ///
    mtitles("OLS" "FE" "FE" "FE") ///
    note("Standard errors in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 7: PARTICIPANT FIRMS — Urgent vs. Ordinary
* DV: ln_n_firms | Treatment: jud_adm | Sample: winners only
* Additional control: bid_qty_log (lquantity)
* Manuscript: beta(urgent) = -0.3887, -0.3831, -0.3811, -0.3373; N = 38,430
********************************************************************************
di ""
di "==========================================="
di "  TABLE 7: PARTICIPANT FIRMS"
di "==========================================="

* Col 1 (OLS)
eststo t7c1: quietly reg ln_n_firms jud_adm bid_qty_log type_mgmt ditem* dpbu_code* ///
    if po_firm_winner==1
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2)
di "  Col 1 (OLS): jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 2 (FE)
eststo t7c2: quietly xtreg ln_n_firms jud_adm bid_qty_log dm_y* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "NO"
estadd scalar myR2 = e(r2_w)
di "  Col 2 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 3 (FE)
eststo t7c3: quietly xtreg ln_n_firms jud_adm bid_qty_log type_mgmt dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 3 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 4 (FE)
eststo t7c4: quietly xtreg ln_n_firms jud_adm bid_qty_log type_mgmt pregao dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 4 (FE):  jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

esttab t7c1 t7c2 t7c3 t7c4 using "`outdir'/table7_firms.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(jud_adm bid_qty_log type_mgmt pregao _cons) ///
    order(jud_adm bid_qty_log type_mgmt pregao _cons) ///
    stats(item_fe year_fe pbu_fe N myR2, ///
        labels("Item dummies" "Year dummies" "PBU dummies" "Observations" "R-squared") ///
        fmt(0 0 0 0 4)) ///
    title("Table 7: Participant Firms — Urgent vs. Ordinary Purchases") ///
    mtitles("OLS" "FE" "FE" "FE") ///
    note("Standard errors in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 9: SUCCESSFUL TENDERS — Urgent vs. Ordinary (Logit)
* DV: po_firm_winner | Treatment: jud_adm | Sample: ALL bids (no winner restriction)
* Additional control: bid_qty_log (lquantity)
* Manuscript: beta(urgent) = -0.4871, -0.4871, -0.6667, -0.5471; N = 59,672
*
* Note: Cols 1 and 2 are identical in the manuscript (same spec, same N).
* Col 4 uses year + month dummies (not year-month) for logit tractability.
********************************************************************************
di ""
di "==========================================="
di "  TABLE 9: SUCCESSFUL TENDERS (Logit)"
di "==========================================="

* Col 1 (LOGIT): Item dummies only + lquantity
di "  Running Col 1 (logit with item dummies)..."
eststo t9c1: logit po_firm_winner jud_adm bid_qty_log ditem*, nolog
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "NO"
estadd scalar myR2 = e(r2_p)
di "  Col 1: jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 2 (LOGIT): Same as col 1 (manuscript reports identical results)
di "  Running Col 2 (same as col 1)..."
eststo t9c2: logit po_firm_winner jud_adm bid_qty_log ditem*, nolog
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "NO"
estadd scalar myR2 = e(r2_p)
di "  Col 2: jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 3 (LOGIT): Item + PBU dummies + type_mgmt + lquantity
di "  Running Col 3 (logit with item + PBU dummies)..."
eststo t9c3: logit po_firm_winner jud_adm bid_qty_log type_mgmt ditem* dpbu_code*, nolog
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_p)
di "  Col 3: jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

* Col 4 (LOGIT): Item + PBU + Year + Month dummies + type_mgmt + pregao + lquantity
di "  Running Col 4 (logit with all dummies, may be slow)..."
eststo t9c4: logit po_firm_winner jud_adm bid_qty_log type_mgmt pregao ditem* dpbu_code* dyear* dmonth*, nolog
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_p)
di "  Col 4: jud_adm = " %9.4f _b[jud_adm] " (SE=" %7.4f _se[jud_adm] ") N=" e(N)

esttab t9c1 t9c2 t9c3 t9c4 using "`outdir'/table9_success.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(jud_adm bid_qty_log type_mgmt pregao _cons) ///
    order(jud_adm bid_qty_log type_mgmt pregao _cons) ///
    stats(item_fe year_fe pbu_fe N r2, ///
        labels("Item dummies" "Year dummies" "PBU dummies" "Observations" "R-squared") ///
        fmt(0 0 0 0 4)) ///
    title("Table 9: Successful Tenders — Urgent vs. Ordinary Purchases (Logit)") ///
    mtitles("LOGIT" "LOGIT" "LOGIT" "LOGIT") ///
    note("Standard errors in parentheses. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace


********************************************************************************
* TABLE 10: UNDER THE GUN — Litigated vs. Administrative
* DV: bid_price_log | Treatment: is_admin | Sample: jud_adm==1 & winners
* Additional control: bid_qty_log (lquantity)
* Manuscript: beta(admin) = -0.095, -0.0859, -0.0859, -0.0846; N = 51,013
*
* Note: Manuscript uses "all public bid data, including SUS-list and non-SUS-list
* medicines" for Table 10. Our data only contains SUS-list. We replicate the
* specification on the available data and document the N discrepancy.
********************************************************************************
di ""
di "==========================================="
di "  TABLE 10: UNDER THE GUN"
di "==========================================="

* Use preserve/restore to handle subsample cleanly
preserve

* Restrict to urgent purchases only (jud_adm == 1)
keep if jud_adm == 1

* Further restrict to items with at least one litigated AND one administrative
* (mirrors manuscript: "items with at least one litigated and one administrative")
bysort item: egen has_admin_item = max(is_admin == 1)
bysort item: egen has_lit_item = max(is_admin == 0)
keep if has_admin_item == 1 & has_lit_item == 1
drop has_admin_item has_lit_item

di "Under the Gun sample (urgent only, items with both types): " _N
quietly count if po_firm_winner == 1
di "  Winners: " r(N)
quietly count if is_admin == 1
di "  Administrative: " r(N)
quietly count if is_admin == 0
di "  Litigated: " r(N)

* Re-encode item_id for clean panel on this subsample
drop item_id
encode item, gen(item_id)
xtset item_id

* Col 1 (OLS): Item + PBU dummies + type_mgmt + lquantity
eststo t10c1: quietly reg bid_price_log is_admin bid_qty_log type_mgmt ditem* dpbu_code* ///
    if po_firm_winner==1
estadd local item_fe "YES"
estadd local year_fe "NO"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2)
di "  Col 1 (OLS): is_admin = " %9.4f _b[is_admin] " (SE=" %7.4f _se[is_admin] ") N=" e(N)

* Col 2 (FE): Item FE + Year-Month dummies + lquantity
eststo t10c2: quietly xtreg bid_price_log is_admin bid_qty_log dm_y* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "NO"
estadd scalar myR2 = e(r2_w)
di "  Col 2 (FE):  is_admin = " %9.4f _b[is_admin] " (SE=" %7.4f _se[is_admin] ") N=" e(N)

* Col 3 (FE): Item FE + Year-Month + PBU + type_mgmt + lquantity
eststo t10c3: quietly xtreg bid_price_log is_admin bid_qty_log type_mgmt dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 3 (FE):  is_admin = " %9.4f _b[is_admin] " (SE=" %7.4f _se[is_admin] ") N=" e(N)

* Col 4 (FE): Item FE + Year-Month + PBU + type_mgmt + pregao + lquantity
eststo t10c4: quietly xtreg bid_price_log is_admin bid_qty_log type_mgmt pregao dm_y* dpbu_code* ///
    if po_firm_winner==1, fe
estadd local item_fe "YES"
estadd local year_fe "YES"
estadd local pbu_fe "YES"
estadd scalar myR2 = e(r2_w)
di "  Col 4 (FE):  is_admin = " %9.4f _b[is_admin] " (SE=" %7.4f _se[is_admin] ") N=" e(N)

esttab t10c1 t10c2 t10c3 t10c4 using "`outdir'/table10_under_the_gun.rtf", ///
    b(%9.4f) se(%9.4f) ///
    keep(is_admin bid_qty_log type_mgmt pregao _cons) ///
    order(is_admin bid_qty_log type_mgmt pregao _cons) ///
    stats(item_fe year_fe pbu_fe N myR2, ///
        labels("Item dummies" "Year dummies" "PBU dummies" "Observations" "R-squared") ///
        fmt(0 0 0 0 4)) ///
    title("Table 10: Under the Gun — Litigated vs. Administrative Purchases") ///
    mtitles("OLS" "FE" "FE" "FE") ///
    note("Standard errors in parentheses. is_admin=1 for administrative, 0 for litigated. *** p<0.01, ** p<0.05, * p<0.1") ///
    compress replace

* Store Table 10 coefficients before restore
local t10_c1 = _b[is_admin]
local t10_c1_se = _se[is_admin]
local t10_c1_N = e(N)

estimates restore t10c1
local t10_c1 = _b[is_admin]
estimates restore t10c2
local t10_c2 = _b[is_admin]
estimates restore t10c3
local t10_c3 = _b[is_admin]
estimates restore t10c4
local t10_c4 = _b[is_admin]

restore


********************************************************************************
********************************************************************************
*              COEFFICIENT COMPARISON: Replication vs. Manuscript
********************************************************************************
********************************************************************************

di ""
di "==========================================="
di "==========================================="
di "  COEFFICIENT COMPARISON"
di "  Replication vs. Published Manuscript"
di "==========================================="
di "==========================================="

di ""
di "NOTE: N discrepancies are expected. Our dataset has ~35K winners"
di "      vs. manuscript's ~60K. Coefficient direction and significance"
di "      should match; magnitudes may differ due to smaller sample."
di ""

* --- Table 4: Reference Prices ---
di "==========================================="
di "  TABLE 4: Reference Prices"
di "  DV: log(reference price)"
di "==========================================="
di "  Col | Replication | Manuscript | Sign Match"
di "  ----|-------------|------------|----------"
estimates restore t4c1
di "  1   | " %10.4f _b[jud_adm] " |    0.4988  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
estimates restore t4c2
di "  2   | " %10.4f _b[jud_adm] " |    0.5243  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
estimates restore t4c3
di "  3   | " %10.4f _b[jud_adm] " |    0.4967  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
estimates restore t4c4
di "  4   | " %10.4f _b[jud_adm] " |    0.4725  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
di "  N   | " %10.0f e(N) "  |   59708    |"

* --- Table 5: Quantities ---
di ""
di "==========================================="
di "  TABLE 5: Quantities"
di "  DV: log(quantity)"
di "==========================================="
di "  Col | Replication | Manuscript | Sign Match"
di "  ----|-------------|------------|----------"
estimates restore t5c1
di "  1   | " %10.4f _b[jud_adm] " |   -0.8128  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t5c2
di "  2   | " %10.4f _b[jud_adm] " |   -0.8811  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t5c3
di "  3   | " %10.4f _b[jud_adm] " |   -0.8272  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t5c4
di "  4   | " %10.4f _b[jud_adm] " |   -0.9402  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
di "  N   | " %10.0f e(N) "  |   59708    |"

* --- Table 6: Negotiated Prices ---
di ""
di "==========================================="
di "  TABLE 6: Negotiated Prices"
di "  DV: log(negotiated price)"
di "==========================================="
di "  Col | Replication | Manuscript | Sign Match"
di "  ----|-------------|------------|----------"
estimates restore t6c1
di "  1   | " %10.4f _b[jud_adm] " |    0.3672  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
estimates restore t6c2
di "  2   | " %10.4f _b[jud_adm] " |    0.3526  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
estimates restore t6c3
di "  3   | " %10.4f _b[jud_adm] " |    0.3568  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
estimates restore t6c4
di "  4   | " %10.4f _b[jud_adm] " |    0.2680  | " cond(_b[jud_adm] > 0, "YES (+)", "NO")
di "  N   | " %10.0f e(N) "  |   38440    |"

* --- Table 7: Participant Firms ---
di ""
di "==========================================="
di "  TABLE 7: Participant Firms"
di "  DV: log(number of firms)"
di "==========================================="
di "  Col | Replication | Manuscript | Sign Match"
di "  ----|-------------|------------|----------"
estimates restore t7c1
di "  1   | " %10.4f _b[jud_adm] " |   -0.3887  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t7c2
di "  2   | " %10.4f _b[jud_adm] " |   -0.3831  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t7c3
di "  3   | " %10.4f _b[jud_adm] " |   -0.3811  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t7c4
di "  4   | " %10.4f _b[jud_adm] " |   -0.3373  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
di "  N   | " %10.0f e(N) "  |   38430    |"

* --- Table 9: Successful Tenders ---
di ""
di "==========================================="
di "  TABLE 9: Successful Tenders (Logit)"
di "  DV: po_firm_winner (0/1)"
di "==========================================="
di "  Col | Replication | Manuscript | Sign Match"
di "  ----|-------------|------------|----------"
estimates restore t9c1
di "  1   | " %10.4f _b[jud_adm] " |   -0.4871  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t9c2
di "  2   | " %10.4f _b[jud_adm] " |   -0.4871  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t9c3
di "  3   | " %10.4f _b[jud_adm] " |   -0.6667  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
estimates restore t9c4
di "  4   | " %10.4f _b[jud_adm] " |   -0.5471  | " cond(_b[jud_adm] < 0, "YES (-)", "NO")
di "  N   | " %10.0f e(N) "  |   59672    |"

* --- Table 10: Under the Gun ---
di ""
di "==========================================="
di "  TABLE 10: Under the Gun"
di "  DV: log(negotiated price)"
di "  Treatment: is_admin (1=admin, 0=litigated)"
di "==========================================="
di "  Col | Replication | Manuscript | Sign Match"
di "  ----|-------------|------------|----------"
di "  1   | " %10.4f `t10_c1' " |   -0.0950  | " cond(`t10_c1' < 0, "YES (-)", "NO")
di "  2   | " %10.4f `t10_c2' " |   -0.0859  | " cond(`t10_c2' < 0, "YES (-)", "NO")
di "  3   | " %10.4f `t10_c3' " |   -0.0859  | " cond(`t10_c3' < 0, "YES (-)", "NO")
di "  4   | " %10.4f `t10_c4' " |   -0.0846  | " cond(`t10_c4' < 0, "YES (-)", "NO")


********************************************************************************
* SUMMARY
********************************************************************************
di ""
di "==========================================="
di "  REPLICATION COMPLETE"
di "==========================================="
di ""
di "Output tables saved to:"
di "  replication/results/table4_ref_prices.rtf"
di "  replication/results/table5_quantities.rtf"
di "  replication/results/table6_neg_prices.rtf"
di "  replication/results/table7_firms.rtf"
di "  replication/results/table9_success.rtf"
di "  replication/results/table10_under_the_gun.rtf"
di ""
di "Check the coefficient comparison above for sign/significance verification."
di "N discrepancies are expected (our data ~60% of manuscript sample)."

timer off 1
timer list
