by item, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  item_unique_count

by po, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  po_unique_count

by po, sort: gen nvals = _n == 1
count if nvals & year=="2018"
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  po_unique_count

drop nvals
by item, sort: gen nvals = _n == 1
count if nvals & year=="2018"
