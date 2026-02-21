clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2009_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_01_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2010_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_02_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2011_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_03_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2012_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_04_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2013_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_05_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2014_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_06_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2015_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_07_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2016_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_08_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2017_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_09_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2018_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_10_bidtime.dta", replace

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_2019_merge.dta", clear
keep po item pbu_code bid_time_date
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_11_bidtime.dta", replace




use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_01_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_02_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_03_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_04_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_05_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_06_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_07_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_08_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_09_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_10_bidtime.dta"
append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_11_bidtime.dta"
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/BEC_DATA_bidtime_final.dta", replace









