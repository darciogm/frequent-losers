clear all
set more off

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

di "=== VARIABLES WITH 'firm' IN NAME ==="
ds *firm*

di "=== VARIABLES WITH 'bid' IN NAME ==="
ds *bid*

di "=== VARIABLES WITH 'part' IN NAME ==="
ds *part*

di "=== VARIABLES WITH 'num' IN NAME ==="
ds *num*

di "=== VARIABLES WITH 'po_' PREFIX ==="
ds po_*

di "=== SUMMARY OF FIRM/BID VARS ==="
capture summarize po_firm_count po_bids_count po_num_firms
capture summarize po_firm_qty po_bid_num
capture ds po_firm*
