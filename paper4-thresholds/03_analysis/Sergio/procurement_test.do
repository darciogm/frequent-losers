use "D:\Brazil_ML\LANCES_Final_Semester.dta", clear


foreach var in "ADAMANTINA"	"ADOLFO"{	/*"AGUAI"	"AGUAS DA PRATA"	"AGUAS DE LINDOIA"	"AGUAS DE SANTA BARBARA"	"AGUDOS"	"ALAMBARI"	"ALFREDO MARCONDES"	"ALTAIR"	"ALTINOPOLIS"	"ALTO ALEGRE"	"ALVARES MACHADO"	"ALVARO DE CARVALHO"	"ALVINLANDIA"	"AMERICANA"	"AMERICO BRASILIENSE"	"AMERICO DE CAMPOS"	"AMPARO"	"ANALANDIA"	"ANDRADINA"	"ANGATUBA"	"ANHEMBI"	"ANHUMAS"	"APARECIDA"	"APARECIDA D'OESTE"	"APIAI"	"ARACATUBA"	"ARACOIABA DA SERRA"	"ARANDU"	"ARAPEI"	"ARARAQUARA"	"ARARAS"	"AREALVA"	"AREIAS"	"AREIOPOLIS"	"ARIRANHA"	"ARUJA"	"ASSIS"	"ATIBAIA"	"AURIFLAMA"	"AVAI"	"AVANHANDAVA"	"AVARE"	"BADY BASSITT"	"BALBINOS"	"BALSAMO"	"BANANAL"	"BARAO DE ANTONINA"	"BARBOSA"	"BARIRI"	"BARRA BONITA"	"BARRA DO CHAPEU"	"BARRA DO TURVO"	"BARRETOS"	"BARRINHA"	"BARUERI"	"BASTOS"	"BATATAIS"	"BAURU"	"BEBEDOURO"	"BENTO DE ABREU"	"BERNARDINO DE CAMPOS"	"BERTIOGA"	"BILAC"	"BIRIGUI"	"BIRITIBA-MIRIM"	"BOCAINA"	"BOFETE"	"BOITUVA"	"BOM JESUS DOS PERDOES"	"BORA"	"BORACEIA"	"BORBOREMA"	"BOREBI"	"BOTUCATU"	"BRAGANCA PAULISTA"	"BRAUNA"	"BREJO ALEGRE"	"BRODOSQUI"	"BROTAS"	"BURI"	"BURITAMA"	"BURITIZAL"	"CABRALIA PAULISTA"	"CABREUVA"	"CACAPAVA"	"CACHOEIRA PAULISTA"	"CACONDE"	"CAFELANDIA"	"CAIABU"	"CAIEIRAS"	"CAIUA"	"CAJAMAR"	"CAJATI"	"CAJOBI"	"CAJURU"	"CAMPINA DO MONTE ALEGRE"	"CAMPINAS"	"CAMPO LIMPO PAULISTA"	"CAMPOS DO JORDAO"	"CAMPOS NOVOS PAULISTA"	"CANANEIA"	"CANDIDO MOTA"	"CANITAR"	"CAPAO BONITO"	"CAPELA DO ALTO"	"CAPIVARI"	"CARAGUATATUBA"	"CARAPICUIBA"	"CARDOSO"	"CASA BRANCA"	"CASSIA DOS COQUEIROS"	"CASTILHO"	"CATANDUVA"	"CATIGUA"	"CEDRAL"	"CERQUEIRA CESAR"	"CERQUILHO"	"CESARIO LANGE"	"CHARQUEADA"	"CHAVANTES"	"CLEMENTINA"	"COLINA"	"COLOMBIA"	"CONCHAL"	"CONCHAS"	"CORDEIROPOLIS"	"COSMORAMA"	"COTIA"	"CRAVINHOS"	"CRISTAIS PAULISTA"	"CRUZEIRO"	"CUBATAO"	"CUNHA"	"DESCALVADO"	"DIADEMA"	"DIRCE REIS"	"DIVERSOS"	"DOIS CORREGOS"	"DOLCINOPOLIS"	"DOURADO"	"DRACENA"	"DUARTINA"	"DUMONT"	"ELDORADO"	"ELIAS FAUSTO"	"ELISIARIO"	"EMBU DAS ARTES"	"EMBU GUACU"	"EMILIANOPOLIS"	"ESTIVA GERBI"	"ESTRELA D'OESTE"	"ESTRELA DO NORTE"	"EUCLIDES DA CUNHA PAULISTA"	"FARTURA"	"FERNANDOPOLIS"	"FERNAO"	"FERRAZ DE VASCONCELOS"	"FLORA RICA"	"FLOREAL"	"FLORIDA PAULISTA"	"FLORINEA"	"FRANCA"	"FRANCISCO MORATO"	"FRANCO DA ROCHA"	"GALIA"	"GARCA"	"GASTAO VIDIGAL"	"GENERAL SALGADO"	"GETULINA"	"GLICERIO"	"GUAICARA"	"GUAIMBE"	"GUAIRA"	"GUAPIACU"	"GUAPIARA"	"GUARA"	"GUARACAI"	"GUARACI"	"GUARANI D'OESTE"	"GUARANTA"	"GUARARAPES"	"GUARAREMA"	"GUARATINGUETA"	"GUAREI"	"GUARIBA"	"GUARUJA"	"GUARULHOS"	"GUATAPARA"	"HERCULANDIA"	"HOLAMBRA"	"HORTOLANDIA"	"IACANGA"	"IACRI"	"IARAS"	"IBATE"	"IBIRA"	"IBIRAREMA"	"IBITINGA"	"ICEM"	"IEPE"	"IGARACU DO TIETE"	"IGARAPAVA"	"IGARATA"	"IGUAPE"	"ILHA COMPRIDA"	"ILHA SOLTEIRA"	"ILHABELA"	"INDAIATUBA"	"INDIANA"	"INDIAPORA"	"IPAUSSU"	"IPERO"	"IPEUNA"	"IPIGUA"	"IPORANGA"	"IPUA"	"IRACEMAPOLIS"	"IRAPUA"	"IRAPURU"	"ITABERA"	"ITAI"	"ITAJOBI"	"ITAJU"	"ITANHAEM"	"ITAPECERICA DA SERRA"	"ITAPETININGA"	"ITAPEVA"	"ITAPEVI"	"ITAPIRA"	"ITAPOLIS"	"ITAPORANGA"	"ITAPUI"	"ITAPURA"	"ITAQUAQUECETUBA"	"ITARARE"	"ITARIRI"	"ITATIBA"	"ITATINGA"	"ITIRAPINA"	"ITIRAPUA"	"ITOBI"	"ITU"	"ITUPEVA"	"ITUVERAVA"	"JABOTICABAL"	"JACAREI"	"JACI"	"JACUPIRANGA"	"JAGUARIUNA"	"JALES"	"JAMBEIRO"	"JANDIRA"	"JARDINOPOLIS"	"JARINU"	"JAU"	"JOANOPOLIS"	"JOAO RAMALHO"	"JOSE BONIFACIO"	"JULIO MESQUITA"	"JUNDIAI"	"JUNQUEIROPOLIS"	"JUQUIA"	"JUQUITIBA"	"LAGOINHA"	"LARANJAL PAULISTA"	"LAVINIA"	"LAVRINHAS"	"LEME"	"LENCOIS PAULISTA"	"LIMEIRA"	"LINDOIA"	"LINS"	"LORENA"	"LOURDES"	"LOUVEIRA"	"LUCELIA"	"LUCIANOPOLIS"	"LUIS ANTONIO"	"LUIZIANIA"	"MACATUBA"	"MACAUBAL"	"MACEDONIA"	"MAGDA"	"MAIRINQUE"	"MAIRIPORA"	"MANDURI"	"MARABA PAULISTA"	"MARACAI"	"MARIAPOLIS"	"MARILIA"	"MARINOPOLIS"	"MARTINOPOLIS"	"MATAO"	"MAUA"	"MENDONCA"	"MERIDIANO"	"MIGUELOPOLIS"	"MINEIROS DO TIETE"	"MIRA ESTRELA"	"MIRACATU"	"MIRANDOPOLIS"	"MIRANTE DO PARANAPANEMA"	"MIRASSOL"	"MIRASSOLANDIA"	"MOCOCA"	"MOGI DAS CRUZES"	"MOGI GUACU"	"MOGI MIRIM"	"MONCOES"	"MONGAGUA"	"MONTE ALEGRE DO SUL"	"MONTE ALTO"	"MONTE APRAZIVEL"	"MONTE AZUL PAULISTA"	"MONTE CASTELO"	"MONTE MOR"	"MORRO AGUDO"	"MORUNGABA"	"MUNICIPIO BRASILIA"	"NATIVIDADE DA SERRA"	"NAZARE PAULISTA"	"NEVES PAULISTA"	"NHANDEARA"	"NIPOA"	"NOVA ALIANCA"	"NOVA CANAA PAULISTA"	"NOVA CASTILHO"	"NOVA EUROPA"	"NOVA GRANADA"	"NOVA GUATAPORANGA"	"NOVA INDEPENDENCIA"	"NOVA LUSITANIA"	"NOVA ODESSA"	"NOVAIS"	"NOVO HORIZONTE"	"NÃO SE APLICA"	"OCAUCU"	"OLEO"	"OLIMPIA"	"ONDA VERDE"	"ORIENTE"	"ORINDIUVA"	"ORLANDIA"	"OSASCO"	"OSCAR BRESSANE"	"OSVALDO CRUZ"	"OURINHOS"	"OURO VERDE"	"OUROESTE"	"PACAEMBU"	"PALESTINA"	"PALMARES PAULISTA"	"PALMEIRA D_OESTE"	"PALMITAL"	"PANORAMA"	"PARAGUACU PAULISTA"	"PARAIBUNA"	"PARAISO"	"PARANAPANEMA"	"PARANAPUA"	"PARAPUA"	"PARDINHO"	"PARIQUERA-ACU"	"PARISI"	"PATROCINIO PAULISTA"	"PAULICEIA"	"PAULINIA"	"PAULISTANIA"	"PAULO DE FARIA"	"PEDERNEIRAS"	"PEDRA BELA"	"PEDRANOPOLIS"	"PEDREGULHO"	"PEDREIRA"	"PEDRO DE TOLEDO"	"PENAPOLIS"	"PEREIRA BARRETO"	"PEREIRAS"	"PERUIBE"	"PIACATU"	"PIEDADE"	"PINDAMONHANGABA"	"PINDORAMA"	"PINHALZINHO"	"PIQUEROBI"	"PIQUETE"	"PIRACAIA"	"PIRACICABA"	"PIRAJU"	"PIRAJUI"	"PIRANGI"	"PIRAPORA DO BOM JESUS"	"PIRAPOZINHO"	"PIRASSUNUNGA"	"PIRATININGA"	"PITANGUEIRAS"	"PLANALTO"	"PLATINA"	"POA"	"POLONI"	"POMPEIA"	"PONGAI"	"PONTAL"	"PONTALINDA"	"PONTES GESTAL"	"POPULINA"	"PORANGABA"	"PORTO FELIZ"	"PORTO FERREIRA"	"POTIM"	"POTIRENDABA"	"PRACINHA"	"PRADOPOLIS"	"PRAIA GRANDE"	"PRATANIA"	"PRESIDENTE ALVES"	"PRESIDENTE BERNARDES"	"PRESIDENTE EPITACIO"	"PRESIDENTE PRUDENTE"	"PRESIDENTE VENCESLAU"	"PROMISSAO"	"QUADRA"	"QUATA"	"QUEIROZ"	"QUELUZ"	"RANCHARIA"	"REDENCAO DA SERRA"	"REGENTE FEIJO"	"REGINOPOLIS"	"REGISTRO"	"RESTINGA"	"RIBEIRA"	"RIBEIRAO BONITO"	"RIBEIRAO BRANCO"	"RIBEIRAO CORRENTE"	"RIBEIRAO DO SUL"	"RIBEIRAO DOS INDIOS"	"RIBEIRAO GRANDE"	"RIBEIRAO PIRES"	"RIBEIRAO PRETO"	"RIFAINA"	"RINCAO"	"RINOPOLIS"	"RIO CLARO"	"RIO DAS PEDRAS"	"RIOLANDIA"	"RIVERSUL"	"ROSANA"	"RUBIACEA"	"RUBINEIA"	"SABINO"	"SAGRES"	"SALES OLIVEIRA"	"SALESOPOLIS"	"SALMORAO"	"SALTO"	"SALTO DE PIRAPORA"	"SANDOVALINA"	"SANTA ADELIA"	"SANTA ALBERTINA"	"SANTA BARBARA D'OESTE"	"SANTA BRANCA"	"SANTA CLARA D'OESTE"	"SANTA CRUZ DA CONCEICAO"	"SANTA CRUZ DA ESPERANCA"	"SANTA CRUZ DAS PALMEIRAS"	"SANTA CRUZ DO RIO PARDO"	"SANTA ERNESTINA"	"SANTA FE DO SUL"	"SANTA LUCIA"	"SANTA RITA D'OESTE"	"SANTA RITA DO PASSA QUATRO"	"SANTA ROSA DE VITERBO"	"SANTANA DE PARNAIBA"	"SANTO ANASTACIO"	"SANTO ANDRE"	"SANTO ANTONIO DA ALEGRIA"	"SANTO ANTONIO DE POSSE"	"SANTO ANTONIO DO ARACANGUA"	"SANTO ANTONIO DO PINHAL"	"SANTO EXPEDITO"	"SANTOPOLIS DO AGUAPEI"	"SANTOS"	"SAO BENTO DO SAPUCAI"	"SAO BERNARDO DO CAMPO"	"SAO CAETANO DO SUL"	"SAO CARLOS"	"SAO JOAO DA BOA VISTA"	"SAO JOAO DAS DUAS PONTES"	"SAO JOAO DE IRACEMA"	"SAO JOAO DO PAU D'ALHO"	"SAO JOAQUIM DA BARRA"	"SAO JOSE DA BELA VISTA"	"SAO JOSE DO BARREIRO"	"SAO JOSE DO RIO PARDO"	"SAO JOSE DO RIO PRETO"	"SAO JOSE DOS CAMPOS"	"SAO LOURENCO DA SERRA"	"SAO LUIZ DO PARAITINGA"	"SAO MANUEL"	"SAO MIGUEL ARCANJO"	"SAO PAULO"	"SAO PEDRO"	"SAO PEDRO DO TURVO"	"SAO ROQUE"	"SAO SEBASTIAO"	"SAO SEBASTIAO DA GRAMA"	"SAO SIMAO"	"SAO VICENTE"	"SARAPUI"	"SARUTAIA"	"SEBASTIANOPOLIS DO SUL"	"SERRA AZUL"	"SERRA NEGRA"	"SERRANA"	"SERTAOZINHO"	"SETE BARRAS"	"SEVERINEA"	"SILVEIRAS"	"SOCORRO"	"SOROCABA"	"SUD MENUCCI"	"SUMARE"	"SUZANO"	"TABAPUA"	"TABATINGA"	"TABOAO DA SERRA"	"TACIBA"	"TAIACU"	"TAIUVA"	"TAMBAU"	"TANABI"	"TAPIRAI"	"TAPIRATIBA"	"TAQUARITINGA"	"TAQUARITUBA"	"TARABAI"	"TARUMA"	"TATUI"	"TAUBATE"	"TEJUPA"	"TEODORO SAMPAIO"	"TERRA ROXA"	"TIETE"	"TIMBURI"	"TORRE DE PEDRA"	"TORRINHA"	"TREMEMBE"	"TRES FRONTEIRAS"	"TUIUTI"	"TUPA"	"TUPI PAULISTA"	"TURIUBA"	"TURMALINA"	"UBARANA"	"UBATUBA"	"UBIRAJARA"	"UCHOA"	"UNIAO PAULISTA"	"URANIA"	"URU"	"URUPES"	"VALENTIM GENTIL"	"VALINHOS"	"VALPARAISO"	"VARGEM"	"VARGEM GRANDE DO SUL"	"VARGEM GRANDE PAULISTA"	"VARZEA PAULISTA"	"VERA CRUZ"	"VINHEDO"	"VIRADOURO"	"VOTORANTIM"	"VOTUPORANGA"	"ZACARIAS"*/
preserve
keep if descriçãomunicípiodeentrega=="`var'"
save "D:\Brazil_ML\LANCES_Final_Semester_`var'.dta", replace
restore
}


preserve
keep if descriçãomunicípiodeentrega=="ADAMANTINA"
save "D:\Brazil_ML\LANCES_Final_Semester_ADAMANTINA.dta", clear
restore



use "C:\Users\sergioga\Downloads\LANCES_Final_Semester_AMERICANA.dta", clear

encode descriçãorazãosocial, gen(firm)
gen datetimevar = clock( datahrproposta , "YMD hms") /*time of the offer*/
format datetimevar %tcDDmonCCYY_HH:MM:SS

gen auction_item =  numerodaoc + "_" + códigoitem
encode auction_item, gen(auction_num) /*Auction - Item identifier*/

gen datevar = date( mêsanoencerramento , "MY") 
format datevar %td

gen t=1

foreach var in valorunitárioproposta valorunitarionegociado	valortotalproposta	valorunitárioreferência	propostavencedorprimeiro	valormínimounitárioproposta	valormáximounitárioproposta valortotalnegociado {
  * Replace comma with period for each variable in the list
  replace `var' = subinstr(`var', ",", ".", .)
  * Convert the string variables to numeric variables
  destring `var', replace
}


destring flagvencedor, force replace /*Winning the auction*/

bys firm: egen count_auction=count(t) /*Total number of auctions in which a firm partecipated in the whole period*/ 

bys firm: egen tot_sum_win=total(flagvencedor) /*Total number of auctions in which a firm whole in the whole period*/ 

bys firm: egen tot_prof_win=total(valortotalnegociado) /*Total amount won by a firm whole in the whole period*/ 



sort firm datetimevar

bys firm (datetimevar): gen cumsum_win = sum(flagvencedor) /*Total number of auctions a firm won up until that point*/
bys firm (datetimevar): gen cumsum_part = sum(t) /*Total number of auctions in which a firm 
partecipated up until that point*/

bys firm (datetimevar): gen cumprof_part = sum(valortotalnegociado) /*Total number of auctions in which a firm partecipated up until that point*/





sort firm datetimevar

bys firm (datetimevar): gen cumsum_win_t_minus_1 = cumsum_win[_n-1] /*Total number of auctions a firm won up until that point t-1*/
bys firm (datetimevar): gen cumsum_part_t_minus_1 =cumsum_part[_n-1] /*Total number of auctions in which a firm partecipated up until that point t-1*/
gen ratio_won=cumsum_win/cumsum_part
gen ratio_won_t_minus_1=cumsum_win_t_minus_1/cumsum_part_t_minus_1

sort firm datetimevar

bys firm (datetimevar): gen cumpro_win_t_minus_1 = cumsum_win[_n-1] /*Total number of auctions a firm won up until that point t-1*/



destring códigogrupo, replace force
tabulate códigogrupo, generate(gr)

drop yr
gen yr=year(datevar)

gen MV_1= valorunitárioproposta- propostavencedorprimeiro/*variabile differenza tra propria offerta e la vincitrice e la second, magari in %?*/

bys auction_num: egen min_MV_1=min(MV_1) if MV_1!=0 /*second closer offer*/


gen MV_2=MV_1-min_MV_1


bys auction_num: egen min_MV_2=min(MV_2) if MV_2!=0 /*second closer offer*/


bys auction_num: egen max=min(valorunitárioreferência) 

gen perc_bid=min_MV_2/min_MV_1
gen ratio_won=cumsum_win/cumsum_part


preserve

gen flag=(MV_2==0 | MV_2==min_MV_2)

keep if perc_bid<0.5

bys auction_num: egen MV=mean(perc_bid) 
replace MV=-MV if MV_2==0 

hist MV if MV<0.5 & MV>-0.5

rdplot cumsum_win MV
01feb2009
restore

keep if MV_1=0 | /*keep the min absolute value of MV which is not 0 */

keep if MV==

rdrobust ratio_won MV, covs(gr2 gr3 gr4 gr5 gr6 gr7 gr8 gr9 gr10 gr11 gr12 gr13 gr14 gr15 gr16 gr17 gr18 gr19 gr20 gr21 gr22 gr23 gr24 gr25 gr26 gr27 gr28 gr29 gr30 gr31 gr32 gr33 gr34 gr35 gr36 gr37 gr38 gr39 gr40 gr41 gr42 gr43 gr44 gr45 gr46 gr47 gr48 gr49 gr50 gr51 gr52 gr53 gr54 gr55 gr56 gr57 gr58 gr59 gr60 gr61 ), if flag==1 & MV<0.5 & MV>-0.5 & cumsum_part>10 


rdplot ratio_won_t_minus_1 MV, covs(gr2 gr3 gr4 gr5 gr6 gr7 gr8 gr9 gr10 gr11 gr12 gr13 gr14 gr15 gr16 gr17 gr18 gr19 gr20 gr21 gr22 gr23 gr24 gr25 gr26 gr27 gr28 gr29 gr30 gr31 gr32 gr33 gr34 gr35 gr36 gr37 gr38 gr39 gr40 gr41 gr42 gr43 gr44 gr45 gr46 gr47 gr48 gr49 gr50 gr51 gr52 gr53 gr54 gr55 gr56 gr57 gr58 gr59 gr60 gr61), if flag==1 & MV<0.5 & MV>-0.5 & cumsum_part>10 & desccategoriaitem=="MATERIAL" & descriçãoprocedimentocompra!="CONVITE"

rddensity MV if descriçãoprocedimentocompra!="CONVITE" & MV<0.5 & MV>-0.5 

CONVITE |     28,556       34.35       34.35
  DISPENSA DE LICITAÇÃO |     20,525       24.69       59.04
      PREGÃO ELETRÔNICO |     34,048       40.96      100.00



rdplot ratio_won_t_minus_1 MV, covs(gr2 gr3 gr4 gr5 gr6 gr7 gr8 gr9 gr10 gr11 gr12 gr13 gr14 gr15 gr16 gr17 gr18 gr19 gr20 gr21 gr22 gr23 gr24 gr25 gr26 gr27 gr28 gr29 gr30 gr31 gr32 gr33 gr34 gr35 gr36 gr37 gr38 gr39 gr40 gr41 gr42 gr43 gr44 gr45 gr46 gr47 gr48 gr49 gr50 gr51 gr52 gr53 gr54 gr55 gr56 gr57 gr58 gr59 gr60 gr61), if flag==1 & MV<0.5 & MV>-0.5 & cumsum_part>10 & desccategoriaitem=="MATERIAL"


sum count_auction, detail, if datetimevar<2012



& (mêsanoencerramento=="01/2016" | mêsanoencerramento=="02/2016" | mêsanoencerramento=="03/2016" | mêsanoencerramento=="04/2016" | mêsanoencerramento=="05/2016" | mêsanoencerramento=="06/2016" | mêsanoencerramento=="07/2016" | mêsanoencerramento=="08/2016" | mêsanoencerramento=="09/2016" | mêsanoencerramento=="10/2016" | mêsanoencerramento=="11/2016" | mêsanoencerramento=="12/2016")


gen ratio_won=cumsum_win/cumsum_part


rdplot cumsum_win MV if flag==1 & MV<0.5 & MV>-0.5

gen cum_win=0




format yr %ty

datevar


rddensity MV, plot plot_range(-50 50) hist_range(-50 50) genvars(temp), if flag==1