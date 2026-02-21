drop h0 x0 h1 x1

twoway__histogram_gen bid_qty_log if jud ==0, frequency gen(h0 x0)

twoway__histogram_gen bid_qty_log if jud ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Njud" 2 "jud") col(1) pos(1) ring(0))



drop h0 x0 h1 x1

twoway__histogram_gen bid_price_ref_log if jud ==0, frequency gen(h0 x0)

twoway__histogram_gen bid_price_ref_log if jud ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Njud" 2 "jud") col(1) pos(1) ring(0))



drop h0 x0 h1 x1

twoway__histogram_gen bid_price_log if jud ==0, frequency gen(h0 x0)

twoway__histogram_gen bid_price_log if jud ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Njud" 2 "jud") col(1) pos(1) ring(0))



drop h0 x0 h1 x1

twoway__histogram_gen n_firms_bids if jud ==0, frequency gen(h0 x0)

twoway__histogram_gen n_firms_bids if jud ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Njud" 2 "jud") col(1) pos(1) ring(0))



drop h0 x0 h1 x1

twoway__histogram_gen n_bids_bids if jud ==0, frequency gen(h0 x0)

twoway__histogram_gen n_bids_bids if jud ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Njud" 2 "jud") col(1) pos(1) ring(0))



drop h0 x0 h1 x1

twoway__histogram_gen fit_qty_log if jud ==0, frequency gen(h0 x0)

twoway__histogram_gen fit_qty_log if jud ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Njud" 2 "jud") col(1) pos(1) ring(0))


drop h0 x0 h1 x1

twoway__histogram_gen fit_ref_price_log if jud ==0, frequency gen(h0 x0)

twoway__histogram_gen fit_ref_price_log if jud ==1, frequency gen(h1 x1)

twoway(bar h0 x0, barw(1)) (bar h1 x1, barw(1)), legend(order(1 "Njud" 2 "jud") col(1) pos(1) ring(0))



twoway (histogram bid_qty_log if jud==1, color(red%30) disc freq)(histogram bid_qty_log if jud==0, color(green%30) disc freq),legend(order(1 "jud" 2 "Njud"))



use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Papers/Paper 1 - JUD/BEC_PAPER_1_JUD_FINAL_2_SUBSAMPLE.dta" 
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
hist n_bids_bids if po_proc_code==1
hist n_bids_bids if po_proc_code==2
hist n_bids_bids if po_proc_code==3
replace n_bids_bids=n_bids_prop if po_proc_code==1
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
total bid_total_value
drop bid_total_value
gen bid_total_value=bid_price*bid_qty
total bid_total_value
bysort jud_alt: total bid_total_value
total bid_total_value if jud_alt==1
total bid_total_value if jud_alt==0
tab pbu_descr jud_alt
tab pbu_descr if jud_alt==1
tab item_descr if pbu_descr=="DEPTO.REG.SAUDE - DRS-V BARRETOS"
tab item_descr padronizadosus if pbu_descr=="DEPTO.REG.SAUDE - DRS-V BARRETOS"
tab po padronizadosus if pbu_descr=="DEPTO.REG.SAUDE - DRS-V BARRETOS"
set linesize 200
tab po padronizadosus if pbu_descr=="DEPTO.REG.SAUDE - DRS-V BARRETOS"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
reg bid_price_log jud_alt bid_qty year_ref price_reg
tab group_item
tab group_item_descr
tab class_item_descr
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables osample()
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables osample(deff)
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables, osample(deff)
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables, osample(deff)
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables, o(deff)
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables osample(deff)
tab deff
sort deff
sort deff item
teffects nnmatch (bid_price_log) (jud) if deff==0, biasadj(bid_qty) ematch(item_ref) dmvariables
drop deff
teffects nnmatch (bid_price_log) (jud_alt), biasadj(bid_qty) ematch(item_ref) dmvariables osample(deff)
teffects nnmatch (bid_price_log) (jud_alt) if deff==0, biasadj(bid_qty) ematch(item_ref) dmvariables osample(deff2)
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) vce(iid) dmvariables
reg bid_price_log jud_alt item_ref, rob
reg bid_price_log jud_alt, rob
teffects psmatch (bid_price_log) (jud item_ref year_ref)
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) vce(iid) dmvariables
teffects psmatch (bid_price_log) (jud item_ref)
by item_ref, sort : teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) dmvariables
by item_ref, sort : teffects nnmatch (bid_price) (jud), biasadj(bid_qty) ematch(item_ref) vce(iid) dmvariables
export delimited using "C:/Users/pesquisa/Desktop/Calculating.csv", delimiter(";") replace
teffects nnmatch (bid_price_log) (jud), biasadj(bid_qty) ematch(item_ref) vce(iid) dmvariables
tab item, generate(item)
reg bid_price_log  item2 item3 item4 item5 item6 item7 item8 item9 item10 item11 item12 item13 item14 item15 item16 item17 item18 item19 item20 item21 item22 item23 item24 item25 item26 item27 item28 item29 item30 item31 item32 item33 item34 item35 item36 item37 item38 item39 item40 item41 item42 item43 item44 item45 item46 item47 item48 item49 item50 item51 item52 item53 item54 item55 item56 item57 item58 item59 item60 item61 item62 item63 item64 item65 item66 item67 item68 item69 item70 item71 item72 item73 item74 item75 item76 item77 item78 item79 item80 item81 item82 item83 item84 item85 item86 item87 item88 item89 item90 item91 item92 item93 item94 item95 item96 item97 item98 item99 item100 item101 item102 item103 item104 item105 item106 item107 item108 item109 item110 item111 item112 item113 item114 item115 item116 item117 item118 item119 item120 item121 item122 item123 item124 item125 item126 item127 item128 item129 item130 item131 item132 item133 item134 item135 item136 item137 item138 item139 item140 item141 item142 item143 item144 item145 item146 item147 item148 item149 item150 item151 item152 item153 item154 item155 item156 item157 item158 item159 item160 item161 item162 item163 item164 item165 item166 item167 item168 item169 item170 item171 item172 item173 item174 item175 item176 item177 item178 item179 item180 item181 item182 item183 item184 item185 item186 item187 item188 item189 item190 item191 item192 item193 item194 item195 item196 item197 item198 item199 item200 item201 item202 item203 item204 item205 item206 item207 item208 item209 item210 item211 item212 item213 item214 item215 item216 item217 item218 item219 item220 item221 item222 item223 item224 item225 item226 item227 item228 item229 item230 item231 item232 item233 item234 item235 item236 item237 item238 item239 item240 item241 item242 item243 item244 item245 item246 item247 item248 item249 item250 item251 item252 item253 item254 item255 item256 item257 item258 item259 item260 item261 item262 item263 item264 item265 item266 item267 item268 item269 item270 item271 item272 item273 item274 item275 item276 item277 item278 item279 item280 item281 item282 item283 item284 item285 item286 item287 item288 item289 item290 item291 item292 item293 item294 item295 item296 item297 item298 item299 item300 item301 item302 item303 item304 item305 item306 item307 item308 item309 item310 item311 item312 item313 item314 item315 item316 item317 item318 item319 item320 item321 item322 item323 item324 item325 item326 item327 item328 item329 item330 item331 item332 item333 item334 item335 item336 item337 item338 item339 item340 item341 item342 item343 item344 item345 item346 item347 item348 item349 item350 item351 item352 item353 item354 item355 item356 item357 item358 item359 item360 item361 item362 item363 item364 item365 item366 item367 item368 item369 item370 item371 item372 item373 item374 item375 item376 item377 item378 item379 item380 item381 item382 item383 item384 item385 item386 item387 item388 item389 item390 item391 item392 item393 item394 item395 item396, rob
reg bid_price_log jud item2~item396, rob
reg bid_price_log jud item2 item3 item4 item5 item6 item7 item8 item9 item10 item11 item12 item13 item14 item15 item16 item17 item18 item19 item20 item21 item22 item23 item24 item25 item26 item27 item28 item29 item30 item31 item32 item33 item34 item35 item36 item37 item38 item39 item40 item41 item42 item43 item44 item45 item46 item47 item48 item49 item50 item51 item52 item53 item54 item55 item56 item57 item58 item59 item60 item61 item62 item63 item64 item65 item66 item67 item68 item69 item70 item71 item72 item73 item74 item75 item76 item77 item78 item79 item80 item81 item82 item83 item84 item85 item86 item87 item88 item89 item90 item91 item92 item93 item94 item95 item96 item97 item98 item99 item100 item101 item102 item103 item104 item105 item106 item107 item108 item109 item110 item111 item112 item113 item114 item115 item116 item117 item118 item119 item120 item121 item122 item123 item124 item125 item126 item127 item128 item129 item130 item131 item132 item133 item134 item135 item136 item137 item138 item139 item140 item141 item142 item143 item144 item145 item146 item147 item148 item149 item150 item151 item152 item153 item154 item155 item156 item157 item158 item159 item160 item161 item162 item163 item164 item165 item166 item167 item168 item169 item170 item171 item172 item173 item174 item175 item176 item177 item178 item179 item180 item181 item182 item183 item184 item185 item186 item187 item188 item189 item190 item191 item192 item193 item194 item195 item196 item197 item198 item199 item200 item201 item202 item203 item204 item205 item206 item207 item208 item209 item210 item211 item212 item213 item214 item215 item216 item217 item218 item219 item220 item221 item222 item223 item224 item225 item226 item227 item228 item229 item230 item231 item232 item233 item234 item235 item236 item237 item238 item239 item240 item241 item242 item243 item244 item245 item246 item247 item248 item249 item250 item251 item252 item253 item254 item255 item256 item257 item258 item259 item260 item261 item262 item263 item264 item265 item266 item267 item268 item269 item270 item271 item272 item273 item274 item275 item276 item277 item278 item279 item280 item281 item282 item283 item284 item285 item286 item287 item288 item289 item290 item291 item292 item293 item294 item295 item296 item297 item298 item299 item300 item301 item302 item303 item304 item305 item306 item307 item308 item309 item310 item311 item312 item313 item314 item315 item316 item317 item318 item319 item320 item321 item322 item323 item324 item325 item326 item327 item328 item329 item330 item331 item332 item333 item334 item335 item336 item337 item338 item339 item340 item341 item342 item343 item344 item345 item346 item347 item348 item349 item350 item351 item352 item353 item354 item355 item356 item357 item358 item359 item360 item361 item362 item363 item364 item365 item366 item367 item368 item369 item370 item371 item372 item373 item374 item375 item376 item377 item378 item379 item380 item381 item382 item383 item384 item385 item386 item387 item388 item389 item390 item391 item392 item393 item394 item395 item396, rob
reg bid_price_log jud year_ref item2 item3 item4 item5 item6 item7 item8 item9 item10 item11 item12 item13 item14 item15 item16 item17 item18 item19 item20 item21 item22 item23 item24 item25 item26 item27 item28 item29 item30 item31 item32 item33 item34 item35 item36 item37 item38 item39 item40 item41 item42 item43 item44 item45 item46 item47 item48 item49 item50 item51 item52 item53 item54 item55 item56 item57 item58 item59 item60 item61 item62 item63 item64 item65 item66 item67 item68 item69 item70 item71 item72 item73 item74 item75 item76 item77 item78 item79 item80 item81 item82 item83 item84 item85 item86 item87 item88 item89 item90 item91 item92 item93 item94 item95 item96 item97 item98 item99 item100 item101 item102 item103 item104 item105 item106 item107 item108 item109 item110 item111 item112 item113 item114 item115 item116 item117 item118 item119 item120 item121 item122 item123 item124 item125 item126 item127 item128 item129 item130 item131 item132 item133 item134 item135 item136 item137 item138 item139 item140 item141 item142 item143 item144 item145 item146 item147 item148 item149 item150 item151 item152 item153 item154 item155 item156 item157 item158 item159 item160 item161 item162 item163 item164 item165 item166 item167 item168 item169 item170 item171 item172 item173 item174 item175 item176 item177 item178 item179 item180 item181 item182 item183 item184 item185 item186 item187 item188 item189 item190 item191 item192 item193 item194 item195 item196 item197 item198 item199 item200 item201 item202 item203 item204 item205 item206 item207 item208 item209 item210 item211 item212 item213 item214 item215 item216 item217 item218 item219 item220 item221 item222 item223 item224 item225 item226 item227 item228 item229 item230 item231 item232 item233 item234 item235 item236 item237 item238 item239 item240 item241 item242 item243 item244 item245 item246 item247 item248 item249 item250 item251 item252 item253 item254 item255 item256 item257 item258 item259 item260 item261 item262 item263 item264 item265 item266 item267 item268 item269 item270 item271 item272 item273 item274 item275 item276 item277 item278 item279 item280 item281 item282 item283 item284 item285 item286 item287 item288 item289 item290 item291 item292 item293 item294 item295 item296 item297 item298 item299 item300 item301 item302 item303 item304 item305 item306 item307 item308 item309 item310 item311 item312 item313 item314 item315 item316 item317 item318 item319 item320 item321 item322 item323 item324 item325 item326 item327 item328 item329 item330 item331 item332 item333 item334 item335 item336 item337 item338 item339 item340 item341 item342 item343 item344 item345 item346 item347 item348 item349 item350 item351 item352 item353 item354 item355 item356 item357 item358 item359 item360 item361 item362 item363 item364 item365 item366 item367 item368 item369 item370 item371 item372 item373 item374 item375 item376 item377 item378 item379 item380 item381 item382 item383 item384 item385 item386 item387 item388 item389 item390 item391 item392 item393 item394 item395 item396, rob
tab pbu_code, generate(pbu)
global item_list  item2 item3 item4 item5 item6 item7 item8 item9 item10 item11 item12 item13 item14 item15 item16 item17 item18 item19 item20 item21 item22 item23 item24 item25 item26 item27 item28 item29 item30 item31 item32 item33 item34 item35 item36 item37 item38 item39 item40 item41 item42 item43 item44 item45 item46 item47 item48 item49 item50 item51 item52 item53 item54 item55 item56 item57 item58 item59 item60 item61 item62 item63 item64 item65 item66 item67 item68 item69 item70 item71 item72 item73 item74 item75 item76 item77 item78 item79 item80 item81 item82 item83 item84 item85 item86 item87 item88 item89 item90 item91 item92 item93 item94 item95 item96 item97 item98 item99 item100 item101 item102 item103 item104 item105 item106 item107 item108 item109 item110 item111 item112 item113 item114 item115 item116 item117 item118 item119 item120 item121 item122 item123 item124 item125 item126 item127 item128 item129 item130 item131 item132 item133 item134 item135 item136 item137 item138 item139 item140 item141 item142 item143 item144 item145 item146 item147 item148 item149 item150 item151 item152 item153 item154 item155 item156 item157 item158 item159 item160 item161 item162 item163 item164 item165 item166 item167 item168 item169 item170 item171 item172 item173 item174 item175 item176 item177 item178 item179 item180 item181 item182 item183 item184 item185 item186 item187 item188 item189 item190 item191 item192 item193 item194 item195 item196 item197 item198 item199 item200 item201 item202 item203 item204 item205 item206 item207 item208 item209 item210 item211 item212 item213 item214 item215 item216 item217 item218 item219 item220 item221 item222 item223 item224 item225 item226 item227 item228 item229 item230 item231 item232 item233 item234 item235 item236 item237 item238 item239 item240 item241 item242 item243 item244 item245 item246 item247 item248 item249 item250 item251 item252 item253 item254 item255 item256 item257 item258 item259 item260 item261 item262 item263 item264 item265 item266 item267 item268 item269 item270 item271 item272 item273 item274 item275 item276 item277 item278 item279 item280 item281 item282 item283 item284 item285 item286 item287 item288 item289 item290 item291 item292 item293 item294 item295 item296 item297 item298 item299 item300 item301 item302 item303 item304 item305 item306 item307 item308 item309 item310 item311 item312 item313 item314 item315 item316 item317 item318 item319 item320 item321 item322 item323 item324 item325 item326 item327 item328 item329 item330 item331 item332 item333 item334 item335 item336 item337 item338 item339 item340 item341 item342 item343 item344 item345 item346 item347 item348 item349 item350 item351 item352 item353 item354 item355 item356 item357 item358 item359 item360 item361 item362 item363 item364 item365 item366 item367 item368 item369 item370 item371 item372 item373 item374 item375 item376 item377 item378 item379 item380 item381 item382 item383 item384 item385 item386 item387 item388 item389 item390 item391 item392 item393 item394 item395 item396
global pbu_list  pbu2 pbu3 pbu4 pbu5 pbu6 pbu7 pbu8 pbu9 pbu10 pbu11 pbu12 pbu13 pbu14 pbu15 pbu16 pbu17 pbu18 pbu19 pbu20 pbu21 pbu22 pbu23 pbu24 pbu25 pbu26 pbu27 pbu28 pbu29 pbu30 pbu31 pbu32 pbu33 pbu34 pbu35 pbu36 pbu37 pbu38 pbu39 pbu40 pbu41 pbu42 pbu43 pbu44 pbu45 pbu46 pbu47 pbu48 pbu49 pbu50 pbu51 pbu52 pbu53 pbu54 pbu55 pbu56 pbu57 pbu58 pbu59 pbu60 pbu61 pbu62 pbu63 pbu64 pbu65 pbu66 pbu67 pbu68 pbu69 pbu70 pbu71 pbu72 pbu73 pbu74 pbu75 pbu76 pbu77 pbu78 pbu79 pbu80 pbu81
reg bid_price_log $item_list $pbu_list, rob
reg bid_price_log jud $item_list $pbu_list, rob
 tab pbu_city_descr
gen pbu_city_sp=0
replace pbu_city_sp=1 if pbu_city_descr=="SAO PAULO"
reg bid_price_log jud $item_list $pbu_list pbu_city_sp, rob
reg bid_price_log jud $item_list $pbu_list pbu_city_sp
tab po_proc_code
gen pregao=0
replace pregao=1 if po_proc_code==3
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao
tab year
tab year, generate (year)
global year_list year2 year3 year4 year5 year6 year7 year8 year9 year10 year11
reg bid_price_log jud $item_list $pbu_list $year_list pbu_city_sp pregao
reg bid_price_log jud $item_list pbu_city_sp pregao
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao
tab po_status_descr
drop if po_status_descr=="ENCERRADO SEM VENCEDOR" & po_proc_code=="DISPENSA DE LICITAÇÃO"
drop if po_status_descr=="ENCERRADO SEM VENCEDOR" & po_proc_code==2
TAB categ_item
tab categ_item
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao bid_qty_log
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao bid_qty
by item_ref, sort : teffects nnmatch (bid_price) (jud), biasadj(bid_qty) ematch(item_ref pbu_code  pregao pbu_city_sp) vce(iid) dmvariables
teffects nnmatch (bid_price) (jud), biasadj(bid_qty) ematch($item_list $pbu_list  pregao pbu_city_sp) vce(iid) dmvariables
reg bid_qty_log jud $item_list $pbu_list pbu_city_sp pregao
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao bid_qty_log
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao
reg bid_price_ref_log jud $item_list $pbu_list pbu_city_sp pregao
hist n_firms_bids
hist n_bids_bids
tab n_bids_bids
tab n_firms_bids
reg n_firms_bids jud $item_list $pbu_list pbu_city_sp pregao
reg n_bids_bids jud $item_list $pbu_list pbu_city_sp pregao
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao bid_qty_log
reg bid_qty_log jud $item_list $pbu_list pbu_city_sp pregao
predict qty_log_hat
hist qty_log_hat
reg bid_price_log qty_log_hat
gen qty_log_hat_sq=qty_log_hat^2
reg bid_price_log qty_log_hat qty_log_hat_sq
reg bid_price_log jud qty_log_hat qty_log_hat_sq
sum qty_log_hat
by jud: sum qty_log_hat
bysort jud: sum qty_log_hat
tab class_item_descr
reg bid_price_log jud qty_log_hat
reg bid_price_log qty_log_hat
reg bid_price_log qty_log_hat qty_log_hat_sq
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao bid_qty_log
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao bid_qty_log jud*bid_qty_log
reg bid_price_log $item_list $pbu_list pbu_city_sp pregao bid_qty_log i.jud##bid_qty_log
reg bid_price_log $item_list $pbu_list pbu_city_sp pregao bid_qty_log i.jud##c.bid_qty_log
reg bid_price_log $item_list $pbu_list pbu_city_sp pregao i.jud##c.bid_qty_log
tab item_descr
tab item_descr item_unit
tab item_unit, generate(item_unit)
global item_unit_list  item_unit2 item_unit3 item_unit4 item_unit5 item_unit6 item_unit7 item_unit8 item_unit9 item_unit10 item_unit11 item_unit12 item_unit13 item_unit14 item_unit15 item_unit16 item_unit17 item_unit18 item_unit19 item_unit20 item_unit21 item_unit22 item_unit23 item_unit24 item_unit25 item_unit26 item_unit27 item_unit28 item_unit29 item_unit30 item_unit31 item_unit32 item_unit33 item_unit34 item_unit35 item_unit36 item_unit37 item_unit38 item_unit39 item_unit40 item_unit41 item_unit42 item_unit43 item_unit44 item_unit45 item_unit46 item_unit47 item_unit48 item_unit49 item_unit50 item_unit51 item_unit52
reg bid_qty_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list
reg bid_qty_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list  year2 year3 year4 year5 year6 year7 year8 year9 year10 year11
reg bid_qty_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list  $year_list
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list  $year_list bid_qty_log
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list  $year_list
reg bid_qty_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list
global control_qty_log $item_list $pbu_list pbu_city_sp pregao $item_unit_list
reg bid_qty_log jud $control_qty_log
tab bid_price_reg
tab bid_green_item
tab bid_item_type
histogram bid_qty_log, kdensity by(jud)
histogram bid_qty_log, kdensity by(jud, total)
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
sort jud
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
graph save Graph "C:/Users/pesquisa/Desktop/Graphs/Graph - Qty.gph"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
graph save Graph "C:/Users/pesquisa/Desktop/Graphs/Graph - Ref Price.gph"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
drop h0
drop x0
drop h1
drop x1
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
graph save Graph "C:/Users/pesquisa/Desktop/Graphs/Graph - Price.gph"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
graph save Graph "C:/Users/pesquisa/Desktop/Graphs/Graph - Firms.gph"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
gen ref_great_price=0
replace ref_great_price=1 if bid_price > bid_price_ref
tab ref_great_price
tab ref_great_price po_status_descr
tab po_status_descr
tab po_status_descr po_proc_code
tab check_po_status
tab po_item_winner
tab ref_great_price po_proc_code
sort ref_great_price
tab ref_great_price jud
sort ref_great_price
gen prop_price_ref_price=bid_price/bid_price_ref
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
hist prop_price_ref_price
sum prop_price_ref_price
bysort jud: sum prop_price_ref_price
hist prop_price_ref_price if prop_price_ref_price>0 & prop_price_ref_price<1
bysort jud: hist prop_price_ref_price if prop_price_ref_price>0 & prop_price_ref_price<1
hist prop_price_ref_price if prop_price_ref_price>0 & prop_price_ref_price<1, by(jud)
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list $year_list
reg bid_price_log jud $item_list $pbu_list pbu_city_sp pregao $item_unit_list
reg bid_qty_log $item_list $pbu_list pbu_city_sp pregao $item_unit_list $year_list
reg bid_qty_log $item_list $pbu_list pbu_city_sp pregao $item_unit_list $year_list if jud==0
predict fit_qty_log
sort jud
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
reg bid_price_ref_log fit_qty_log $item_list $pbu_list pbu_city_sp pregao $item_unit_list $year_list
predict fit_ref_price_log
do "C:/Users/pesquisa/AppData/Local/Temp/2/STD2158_000000.tmp"
bysort jud: sum fit_qty_log
bysort jud: sum fit_ref_price_log
fit_qty_log jud
reg fit_qty_log jud
reg fit_ref_price_log jud
reg bid_price_log fit_qty_log fit_ref_price_log $item_list $pbu_list pbu_city_sp pregao $item_unit_list $year_list
predict fit_price_log
reg fit_qty_log jud
reg fit_ref_price_log jud
reg fit_price_log jud
reg fit_ref_price_log $item_list $pbu_list pbu_city_sp pregao $item_unit_list $year_list jud
reg fit_ref_price_log  jud
tab group_item_descr
tab class_item_descr
tab jud
help logit
logit po_firm_winner jud
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/Papers/Paper 1 - JUD/BEC_PAPER_1_JUD_FINAL_2_SUBSAMPLE.dta", replace
