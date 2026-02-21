by pbu_code, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals pbus_unique_count

by firm_id, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  firm_unique_count

by po, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  po_unique_count

by item, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  item_unique_count

by class_item, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  class_item_unique_count

by group_item, sort: gen nvals = _n == 1
count if nvals
replace nvals = sum(nvals)
replace nvals = nvals[_N]
rename nvals  group_item_unique_count
