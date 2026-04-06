**********************************************************************************
**************************** 03_summary_statistics.do ****************************
**********************************************************************************

**********************************************************************************

* This do file does the main analysis and plots of the study

* 1. Number of aution per year
* 2. Backlog 30 days
* 3. Average amount of bidders per year

**********************************************************************************

set processor 24

*** 0. Import Data

use "/cluster/work/lawecon/Projects/procurement_brazil/LANCES_Final_Semester.dta", clear


**********************************************************************************


*** 1. Generate and preprocess general variables

* Firm ID
egen long firm = group(descriçãorazãosocial)

* Time of the offer
gen datetimevar = clock(datahrproposta , "YMD hms")
format datetimevar %tcDDmonCCYY_HH:MM:SS

* Auction item
gen auction_item =  numerodaoc + "_" + códigoitem

* Item ID
egen long auction_num = group(auction_item)

* Date
gen datevar = date(mêsanoencerramento , "MY") 
format datevar %td

* Type of item
destring códigogrupo, replace force

* Dummy for each item type
tabulate códigogrupo, generate(gr)

* Year
gen year=year(datevar)

* Replace "," with "." and convert to numeric
foreach var in valorunitárioproposta valorunitarionegociado	valortotalproposta	valorunitárioreferência	propostavencedorprimeiro valormínimounitárioproposta	valormáximounitárioproposta valortotalnegociado {
  * Replace comma with period for each variable in the list
  replace `var' = subinstr(`var', ",", ".", .)
  * Convert the string variables to numeric variables
  destring `var', replace
}


**********************************************************************************

*** 2. Number of aution per year


preserve 
collapse (count) bidders = firm, by(year)
gen bidders_million = bidders/1000000
twoway (bar bidders_million year, barwidth(0.8) color(navy)), xlabel(2009(1)2019) ylabel(0(1)4.5, angle(0)) ytitle("Number of Bidders (in Millions)") xtitle("Year") graphregion(color(white))
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/bidder_per_year.pdf", replace
restore


**********************************************************************************

/*
*** 3. Average participation by firm per year

preserve 
collapse (mean) cumsum_part_mean = cumsum_part, by(year)
twoway (bar cumsum_part_mean year, barwidth(0.8) color(navy)), xlabel(2009(1)2019) ytitle("Average participation by firm") xtitle("Year")
graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/avg_participation_by_firm_per_year.pdf", replace
restore

*/
**********************************************************************************

*** 3. Total amount awarded in BRL per year

preserve
keep if valortotalnegociado !=.
collapse (sum) total_value = valortotalnegociado, by(year)
gen total_value_million = total_value/1000000000
twoway (bar total_value_million year, barwidth(0.8) color(navy)), xlabel(2009(1)2019) ylabel(0(50)200, angle(0)) ytitle("Total amount awarded (in Billions BRL)") xtitle("Year") graphregion(color(white))

graph export "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/output/graphs/total_amount_awarded_per_year.pdf", replace
restore




