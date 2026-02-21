clear
set more 1
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2009_2018.dta", clear

append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2009_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2010_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2010_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2011_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2011_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2012_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2012_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2013_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2013_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2014_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2014_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2015_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2015_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2016_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2016_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2017_1.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2017_2.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2018_Ago.dta"


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/BEC_2009_2018.dta", replace
