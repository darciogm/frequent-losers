clear all
set more off

use "/home/darciogm1/projetos/bitter-pills/paper1-bitter-pills/datasets/3_BEC_PAPER_1_JUD_FINAL.dta", clear

describe, short

di "=== KEY VARIABLES ==="
describe bid_price_ref bid_price bid_qty po_firm_winner jud adm jud_adm pregao po_proc_code

di "=== TAB JUD ==="
tab jud

di "=== TAB ADM ==="
tab adm

di "=== TAB JUD_ADM ==="
tab jud_adm

di "=== TAB PO_PROC_CODE ==="
tab po_proc_code

di "=== CROSS TAB JUD x ADM ==="
tab jud adm

di "=== SUMMARY STATS ==="
summarize bid_price_ref bid_price bid_qty po_firm_winner pregao
