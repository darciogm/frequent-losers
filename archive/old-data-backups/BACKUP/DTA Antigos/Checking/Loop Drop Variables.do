clear

cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement"

local mylist BEC_2015_1 BEC_2015_2 BEC_2016_1 BEC_2016_2 BEC_2017_1 BEC_2017_2 BEC_2018_Ago
 
foreach filename of local mylist {

use `"`filename'.dta"', replace

drop diamêsencerramento dataocagendamento quantidadedeitem propostavencedorprimeiro quantidadeitemvencedor quantidadedeitenssequência quantidadedefornecedorparticipan diamêsagendamento

save `"`filename'.dta"', replace

clear
}


