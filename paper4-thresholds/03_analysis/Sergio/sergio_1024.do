use if descriçãoprocedimentocompra=="CONVITE" using "D:\Brazil_ML\LANCES_Final_Semester.dta", clear

gen double datetimevar = clock(datahrproposta, "YMDhms")
format datetimevar %tc
egen long firm = group(descriçãorazãosocial)

gen datevar = date( mêsanoencerramento , "MY") 
format datevar %td
gen yr = year(datevar)

gen t=1

*create an index for each auction by item
gen auction_item =  numerodaoc + "_" + códigoitem
egen long auction_num = group(auction_item)

*extract bids info
foreach var in valorunitárioproposta valorunitarionegociado	valortotalproposta	valorunitárioreferência	propostavencedorprimeiro valormínimounitárioproposta	valormáximounitárioproposta valortotalnegociado {
  * Replace comma with period for each variable in the list
  replace `var' = subinstr(`var', ",", ".", .)
  * Convert the string variables to numeric variables
  destring `var', replace
}


destring flagvencedor, force replace /*Winning the auction*/

*Check that we have only one bid per firm and one winner
bys auction_num firm (valorunitárioproposta): gen tag = _n == 1
keep if tag==1

bys auction_num (valorunitárioproposta): gen m=_n 

sort auction_num m
keep if m<3

bys auction_num: egen max_m=max(m) 
keep if max_m==2

bys auction_num: egen check_winner = total(flagvencedor)
keep if check_winner==1




/*Generate outcomes*/

/*incombancy - win in the previous auction (not auction_item) from a give buyer */
bys firm numerodaoc: egen flagvencedor_whole_auction=max(flagvencedor) 
bys firm códigounidadecompradora (datetimevar numerodaoc): gen won_t_minus_1_compr = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1] 
forvalues i=2/30{
bys firm códigounidadecompradora (datetimevar numerodaoc ): replace won_t_minus_1_compr = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1_compr==.
}

/*from all buyers*/
bys firm  (datetimevar numerodaoc): gen won_t_minus_1 = flagvencedor_whole_auction[_n-1] if numerodaoc!=numerodaoc[_n-1] 
forvalues i=2/30{
bys firm  (datetimevar numerodaoc ): replace won_t_minus_1 = flagvencedor_whole_auction[_n-`i'] if numerodaoc!=numerodaoc[_n-`i'] & won_t_minus_1==.
}

/*backlog - potential amount won (reserve price) from a given buyer in the previous X days */
bys auction_item: egen reserve_price=max(valorunitárioreferência)
gen amount_won=flagvencedor*reserve_price

sort firm datetimevar

gen window_start_2 = datetimevar - 2*24*60*60*1000
gen window_start_30 = datetimevar - 30*24*60*60*1000
gen window_start_60 = datetimevar - 60*24*60*60*1000
gen window_start_90 = datetimevar - 90*24*60*60*1000
gen window_start_120 = datetimevar - 120*24*60*60*1000
gen window_start_365 = datetimevar - 365*24*60*60*1000

sort firm datetimevar
foreach i in 30 60 90 120 365{
rangestat (sum) cumprof_won_`i'=amount_won, interval(datetimevar window_start_`i' window_start_2) by(firm)
rangestat (sum) cumprof_won_`i'_compr=amount_won, interval(datetimevar window_start_`i' window_start_2) by(firm códigounidadecompradora)
bysort firm: egen cumprof_won_`i'_std = std(cumprof_won_`i')
bysort firm: egen cumprof_won_`i'_compr_std_ = std(cumprof_won_`i'_compr)
gen lcumprof_won_`i'=ln(cumprof_won_`i')
gen lcumprof_won_`i'_compr=ln(cumprof_won_`i'_compr)
}

/*usual winner - win in the previous auction (not auction_item) from a give buyer */
foreach i in 30 60 90 120 365{
rangestat (sum) cum_won_`i'=flagvencedor, interval(datetimevar window_start_`i' window_start_2) by(firm)
rangestat (sum) cum_won_`i'_compr=flagvencedor, interval(datetimevar window_start_`i' window_start_2) by(firm códigounidadecompradora)
rangestat (sum) cum_part_`i'=t, interval(datetimevar window_start_`i' window_start_2) by(firm)
rangestat (sum) cum_part_`i'_compr=t, interval(datetimevar window_start_`i' window_start_2) by(firm códigounidadecompradora)
gen share_won`i'=cum_won_`i'/cum_part_`i'
gen share_won`i'_compr=cum_won_`i'_compr/cum_part_`i'_compr
}


/*last bid - indicator for last bid*/
bys auction_num: gen diff_time=(datetimevar-datetimevar[_n-1])/1000
bys auction_num: replace diff_time=-diff_time[_n+1] if diff_time==.
gen last=diff_time>0

/*company structure - indicator for limited company*/
gen limited_firm=descriçãonaturezajurídica=="SOCIEDADE EMPRESÁRIA LIMITADA"


/*location advantage - indicator for company being from the same municipality as buyer*/
gen equal_mun=descriçãomunicípiofornecedor==descriçãomunicípiodeentrega

merge m:1 códigofornecedor using "C:\Users\sergioga\Sergio DB Dropbox\Sergio Galletta\Projects - Brazilian data\Data\Firms_final.dta", keepusing(fornec_latitude fornec_longitude data_inicio_atividade)
gen year_start_activity = substr(data_inicio_atividade, 1, 4)
destring year_start_activity, force replace
gen age=yr-year_start_activity


/*Generate Running Variable*/
/*created as difference in the % difference from reference price*/
bys auction_num: egen max_prop=max(valorunitárioproposta)
bys auction_num: egen min_prop=min(valorunitárioproposta)

gen MV2t=min_prop/reserve_price
gen MV2t2=max_prop/reserve_price

gen MV2=MV2t2-MV2t if flagvencedor==0
replace MV2=MV2t-MV2t2 if flagvencedor==1

gen MV=(max_prop-min_prop)/min_prop
replace MV=-MV if flagvencedor==1

* Destring códigogrupo and generate indicator variables
destring códigogrupo, replace force
tabulate códigogrupo, generate(gr)





/**********/
/*Analysis*/
/**********/


/*Figure RDD*/

rdplot won_t_minus_1_compr MV if MV<0.10 & MV>-0.10, graph_options(ytitle(Previous Auction Won) xtitle(Difference in bids) xlabel(-.10(0.02)0.10) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)

rdplot share_won90_compr MV if MV<0.10 & MV>-0.10, graph_options(ytitle(90-Day Share Won) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)

rdplot cumprof_won_120_compr_std_ MV if MV<0.10 & MV>-0.10, graph_options(ytitle(120-Day Standardized Backlog) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(25) p(2)

rdplot age MV if MV<0.10 & MV>-0.10, graph_options(ytitle(Firm Age) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9) ) nbins(50) p(2)

rdplot limited_firm MV if MV<0.10 & MV>-0.10, graph_options(ytitle(Limited Liability Firm) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9)) nbins(50) p(2)

rdplot last MV2 if MV2<0.05 & MV2>-0.05, graph_options(ytitle(Limited Liability Firm) xtitle(Difference in bids) xlabel(-0.10 (0.02)0.10 ) legend(off) ysize(5) xsize(9)) nbins(50) p(2)

/*Regressions*/

rdbwselect won_t_minus_1_compr MV  if MV<0.10 & MV>-0.10

reghdfe won_t_minus_1_compr i.flagvencedor##c.MV  if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(yr códigogrupo códigounidadecompradora )  
sum won_t_minus_1_compr if MV<0.01 & MV>-0.01

reghdfe share_won90_compr i.flagvencedor##c.MV  if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(yr códigogrupo códigounidadecompradora )  
sum share_won90_compr if MV<0.01 & MV>-0.01

reghdfe cumprof_won_120_compr_std i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(yr códigogrupo códigounidadecompradora )  
sum cumprof_won_120_compr_std 

reghdfe age i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(yr códigogrupo códigounidadecompradora )  
sum age 

reghdfe limited_firm i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(yr códigogrupo códigounidadecompradora )  
sum limited_firm 

reghdfe last i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(yr códigogrupo códigounidadecompradora )  
sum last 

reghdfe equal_mun i.flagvencedor##c.MV if MV<0.01 & MV>-0.01,  vce(cluster códigounidadecompradora) abs(yr códigogrupo códigounidadecompradora )  
sum equal_mun 

equal_mun

reghdfe last i.flagvencedor##c.MV2  if MV2<0.014 & MV2>-0.014,  vce(cluster códigounidadecompradora) abs(códigogrupo códigounidadecompradora yr)  


/*Regressions by buyer*/
reghdfe won_t_minus_1_compr i.flagvencedor##c.MV2  if MV2<0.014 & MV2>-0.014 & descriçãounidadecompradora=="REGIMENTO DE POLICIA MONTADA 9 DE JULHO",   abs(yr)  
