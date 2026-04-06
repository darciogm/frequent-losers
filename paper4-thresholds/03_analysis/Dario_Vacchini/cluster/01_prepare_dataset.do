**********************************************************************************
**************************** 01_prepare_dataset.do *******************************
**********************************************************************************

**********************************************************************************

* This do file generates the varibales and clean the dataset to be processed for the analysis

* 1. Generate Variables
* 2. Label Variables

**********************************************************************************

set processors 24

*** 0. Import data

use "/cluster/work/lawecon/Projects/procurement_brazil/LANCES_Final_Semester.dta", clear

keep if descriçãoprocedimentocompra=="CONVITE"

* Save dataset
save "/cluster/work/lawecon/Projects/procurement_brazil/dario_vacchini/data/final/df_inter_convite.dta", replace






