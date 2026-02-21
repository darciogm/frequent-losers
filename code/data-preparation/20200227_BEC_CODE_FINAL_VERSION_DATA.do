
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************

* PART ONE


***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1" 			// Defining Main Directory 

* Final product: Collapse_1A.dta

* 1- Appending Files (Yearly)

/*
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_1.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante  quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_1.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_2.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_2.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_3.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_3.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_4.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_4.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_5.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_5.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_6.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_6.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_7.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_7.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_8.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_8.dta", replace
clear all
*/

/*
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_9.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_9.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_10.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_10.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_11.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_11.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_12.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_12.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_13.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_13.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_14.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_14.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_15.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_15.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_16.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_16.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_17.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_17.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_18.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_18.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_19.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_19.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_20.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_20.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_21.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_21.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_22.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_22.dta", replace
clear all
*/


use LANCES_8.dta, clear
append using LANCES_7.dta
append using LANCES_6.dta
append using LANCES_5.dta
append using LANCES_4.dta
append using LANCES_3.dta
append using LANCES_2.dta
append using LANCES_1.dta


/*
use LANCES_22.dta, clear
append using LANCES_21.dta
append using LANCES_20.dta
append using LANCES_19.dta
append using LANCES_18.dta
append using LANCES_17.dta
append using LANCES_16.dta
append using LANCES_15.dta
append using LANCES_14.dta
append using LANCES_13.dta
append using LANCES_12.dta
append using LANCES_11.dta
append using LANCES_10.dta
append using LANCES_9.dta
append using LANCES_8.dta
append using LANCES_7.dta
append using LANCES_6.dta
append using LANCES_5.dta
append using LANCES_4.dta
append using LANCES_3.dta
append using LANCES_2.dta
append using LANCES_1.dta
*/


gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/BEC_GROUP1.dta", replace



* 2- Preparing variables (Renaming variables in English)

ren date1 m_y
label variable m_y "Month and Year"

egen t = group(m_y)
label variable t "Month and Year from 1 to 120"

ren descriçãoprocedimentocompra descrproc
egen proc = group(descrproc)
label variable proc "1 = CONVITE; 2 = DISPENSA DE LICITAÇÃO; 3 = PREGÃO ELETRÔNICO"

ren numerodaoc po
label variable po "Purchase Order Number"

egen price_reg = group(ataregistrodepreço)
replace price_reg = price_reg - 1
label variable price_reg "Price Registration? 0 = No; 1 = Yes"

destring códigocategoria, replace
replace códigocategoria = 0 if códigocategoria == 2
ren códigocategoria categ_item
label variable categ_item "0 = Service; 1 = Good"

ren códigoclasse class_item
label variable class_item "Class of Item Code" 

ren códigogrupo group_item
label variable group_item "Group of Item Code"

ren códigoitem item
label variable item "Item Code"

ren descunidadefornecimento item_unit
label variable item_unit "Item unit"

gen green_item = 0
replace green_item = 1 if seloverde == "S"
label variable green_item "Green Item? 0 = No; 1 = Yes"

ren valorunitárioproposta bid_unit_price
label variable bid_unit_price "Bid unit price with no negotiation"

ren flagvencedor bid_winner
label variable bid_winner "Bid made by the winner firm? 0 = No; 1 = Yes (not necessarily the winner bid)"

ren datahrproposta bid_time
label variable bid_time "Day and time of the bid"

ren valorunitarionegociado bid_unit_price_negot
label variable bid_unit_price_negot "Bid unit price after negotiation"

ren valorunitárioreferência bid_ref_price
label variable bid_ref_price "Reference Price"

ren qtdeofertadecompraitemnegociado bid_item_qty_perbid
label variable bid_item_qty_perbid "Bid item quantity per bid"

ren códigofornecedor firm_id
label variable firm_id "CNPJ or CPF"

ren descriçãoenquadramento firm_type
label variable firm_type "Firm type: Cooperativa, Cooperativa Direito de Pref., EPP, Enquadramento não cadastrado no CAUFESP, ME, Outros"

ren descriçãofisicajurídica firm_person
label variable firm_person "Pessoa Física ou Jurídica"

ren descriçãomatrizfilial firm_headqtr_branch
label variable firm_headqtr_branch "Headquarter or Branch"

ren descriçãonaturezajurídica firm_legal_nature
label variable firm_legal_nature "Firm legal nature"	

ren descriçãosimplesnacional firm_simples
label variable firm_simples "Simples Nacional"

ren descriçãopropostastatus bid_status
label variable bid_status "Bid status specific level"

ren descriçãogrupopropostastatus bid_status_group
label variable bid_status_group "Bid status general level"

ren descriçãofasesoc po_phase
label variable po_phase "Purchase Order Phase"

ren códigounidadecompradora pbu_code
label variable pbu_code "Public Buyer Unit code in the BEC Catalog"

ren descriçãomunicípiofornecedor firm_city
label variable firm_city "Firm city"

ren descriçãouffornecedor firm_state
label variable firm_state "Firm state"

ren códigocepfornecedor firm_zipcode
label variable firm_zipcode "Firm zipcode"

ren códigomunicípiodeentrega pbu_city_delivery_code
label variable pbu_city_delivery_code "City code of delivery"

ren descriçãomunicípiodeentrega pbu_city_delivery
label variable pbu_city_delivery "City of delivery"

ren códigoregiãodeentrega pbu_region_delivery_code
label variable pbu_region_delivery_code "Region code of delivery"

ren descriçãoregiãodeentrega pbu_region_delivery
label variable pbu_region_delivery "Region of delivery"

ren descriçãoofertadecomprastatus po_status
label variable po_status "PO status"

ren códigoofertadecomprastatus po_status_code
label variable po_status_code "PO status code"

ren desccategoriaitem categ_item_descr
label variable categ_item_descr "Item category description"

ren descclasseitem class_item_descr
label variable class_item_descr "Item class description"

ren descgrupoitem group_item_descr
label variable group_item_descr "Item group description"

ren descitem item_descr
label variable item_descr "Item description"

ren descriçãorazãosocial firm_descr
label variable firm_descr "Firm Description"

gen date = m_y

destring date, replace
gen date1 = monthly(date, "MY")
format date1 %tm

split date, p("/") gen(substr)

drop substr1 m_y  ataregistrodepreço seloverde descriçãounidadecompradora descrproc
drop if po == ""

ren date1 m_y

ren substr2 year

gen pbu_code_year = pbu_code + year

label variable date "Date destring"

label variable m_y "Date in date format"

label variable year "Year"

label variable pbu_code_year "Key variable for UCs merge"

egen item_type = group(categ_item_descr)
label variable item_type "1=MATERIAL;2=SERVIÇO"
drop categ_item_descr

egen firm_type_code = group(firm_type)
label variable firm_type_code "1=COOPERATIVA;2=COOPERATIVA DIR PREF;3=EPP;4=NÃO CADAST CAUFESP;5=ME;6=OUTROS"
drop firm_type

egen firm_person_code = group(firm_person)
label variable firm_person_code "1=FISICA;2=JURIDICA;3=SEM CADASTRO"
drop firm_person

egen firm_headqtr_branch_code = group(firm_headqtr_branch)
label variable firm_headqtr_branch_code "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CADASTRO"
drop firm_headqtr_branch

egen  firm_legal_nature_code = group(firm_legal_nature)
label variable firm_legal_nature_code "Type of Firm"


egen firm_simples_code = group(firm_simples)
label variable firm_simples_code "1=N/A;2=NÃO;3=SIM"
drop firm_simples

egen bid_status_code = group(bid_status)
drop bid_status
gen bid_status = bid_status_code
replace bid_status = 0 if bid_status_code >= 2 & bid_status_code <= 15
replace bid_status = 1 if bid_status_code==1 | bid_status_code==16 | bid_status_code==17
drop bid_status_code
label variable bid_status "0=INVALIDO;1=VALIDO"

egen bid_status_group_code = group(bid_status_group)
label variable bid_status_group_code "1=CLASSIF;2=DESCLASSIF;3=INVÁLIDO;4=N/A;5=VÁLIDO"
drop bid_status_group

egen po_phase_code = group(po_phase)
label variable po_phase_code "1=AD MELH OFERTA;2=PROPS;3=LANCES;4=NEGOC;5=N/A;6=ME-EPP;7=REALINH PREÇO COOPERAT"
drop po_phase

drop razãosocial

destring bid_unit_price bid_unit_price_negot bid_ref_price bid_item_qty_perbid, replace dpcomma

sort pbu_code_year

gen pot_epp_me = 0
replace pot_epp_me=1 if firm_legal_nature=="ASSOCIAÇÃO PRIVADA" | firm_legal_nature=="COOPERATIVA" | firm_legal_nature=="EMP. INDIV. RESPONS. LIMITADA-EIRELI (EMPRESÁRIA)" | firm_legal_nature=="EMP. INDIV. RESPONS. LIMITADA-EIRELI (SIMPLES)" | ///
firm_legal_nature=="EMPRESÁRIO (INDIVIDUAL)" | firm_legal_nature=="EMPRESÁRIO (INDIVIDUAL) - MEI" | firm_legal_nature=="SOCIEDADE CIVIL" | firm_legal_nature=="SOCIEDADE EMPRESÁRIA LIMITADA" | firm_legal_nature=="SOCIEDADE SIMPLES" | ///
firm_legal_nature=="SOCIEDADE SIMPLES LIMITADA" | firm_legal_nature=="SOCIEDADE SIMPLES PURA"

// drop if po_phase_code == 5
// replace po_phase_code = 5 if po_phase_code == 6
// replace po_phase_code = 6 if po_phase_code == 7
// label variable po_phase_code "1=AD MELH OFERTA;2=PROPS;3=LANCES;4=NEGOC;5=ME-EPP;6=REALINH PREÇO COOPERAT"


gen po_phase_code_str=po_phase_code
tostring po_phase_code_str, replace
gen po_item_merge_key = po + item + po_phase_code_str + item_unit
bysort po_item_merge_key (bid_unit_price): gen bid_rank = sum(bid_unit_price != bid_unit_price[_n-1])

gen bid_price_acession = bid_unit_price if po_phase_code == 1
gen bid_price_prop = bid_unit_price if po_phase_code == 2
gen bid_price_bids = bid_unit_price if po_phase_code == 3
gen bid_price_negot = bid_unit_price if po_phase_code == 4
gen bid_price_n_a = bid_unit_price if po_phase_code == 5
gen bid_price_pref = bid_unit_price if po_phase_code == 6
gen bid_price_realinh = bid_unit_price if po_phase_code == 7


// drop if bid_status==0




* 3- Geocoding UCs (Original Latit/Longit if available; otherwise, city latit/longit) 


merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE_cities.dta", gen(flag)
drop if po == ""



* 4- Working in full file (Creating extra variables)

gen bid_id = _n
label variable bid_id "Bid ID (Primary Key)"
																	
gen same_city_pbu_firm = 0
replace same_city_pbu_firm = 1 if firm_city == pbu_city_descr
label variable same_city_pbu_firm "Pbu and Firm in the same city? 0 = No; 1 = Yes"

gen firm_state_sp = 0
replace firm_state_sp = 1 if firm_state == "SÃO PAULO"
label variable firm_state_sp "Firm in São Paulo State? 0 = No; 1 = Yes"


destring po_phase_code, replace

gen same_city_pbu_firm_acession=same_city_pbu_firm if po_phase_code==1
gen same_city_pbu_firm_prop=same_city_pbu_firm if po_phase_code==2
gen same_city_pbu_firm_bids=same_city_pbu_firm if po_phase_code==3
gen same_city_pbu_firm_negot=same_city_pbu_firm if po_phase_code==4
gen same_city_pbu_firm_n_a=same_city_pbu_firm if po_phase_code==5
gen same_city_pbu_firm_pref=same_city_pbu_firm if po_phase_code==6
gen same_city_pbu_firm_realinh=same_city_pbu_firm if po_phase_code==7

gen firm_state_sp_acession=firm_state_sp if po_phase_code==1
gen firm_state_sp_prop=firm_state_sp if po_phase_code==2
gen firm_state_sp_bids=firm_state_sp if po_phase_code==3
gen firm_state_sp_negot=firm_state_sp if po_phase_code==4
gen firm_state_sp_n_a=firm_state_sp if po_phase_code==5
gen firm_state_sp_pref=firm_state_sp if po_phase_code==6
gen firm_state_sp_realinh=firm_state_sp if po_phase_code==7

tostring item, replace
tostring po_phase_code, replace

gen po_item_id = po + item + po_phase_code
gen po_item_key = po + item
gen bid_count = 1

gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time


sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1

rename nvals unique_firm

drop pbu_city_delivery_code pbu_city_delivery pbu_region_delivery_code pbu_region_delivery pubag_code pubag_descr pubbudget_code pubbudget_descr pbu_descr ///
pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_cnpj pbu_power pbu_type_mgmt_descr

drop flag 



/*
replace bid_unit_price = . if bid_unit_price == 0
replace bid_unit_price_negot = . if bid_unit_price_negot == 0
replace bid_ref_price = . if bid_ref_price == 0
replace bid_item_qty_perbid = . if bid_item_qty_perbid == 0
*/



* 5- Saving Baseline and Separating Firm info (Preparing for geocoding firms)

gen firm_zipcode_length=length(firm_zipcode)
tab firm_zipcode_length
replace firm_zipcode = "0" + firm_zipcode if firm_zipcode_length==7
gen firm_id_zipcode = firm_id + firm_zipcode
sort firm_id_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP2/BEC_GROUP1_merge.dta", replace

keep  firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state ///
firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP3/Firm_info_GROUP1.dta", replace


* 6- Geocoding Firms (Creating source file and geocoding firms)

* Excluir esta parte

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP3/Firm_info_GROUP1.dta", clear


merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Geocoding_firm_zipcode_cities.dta"
ren _merge _merge_firm_geoc
drop if _merge_firm_geoc==1
drop if _merge_firm_geoc==2
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP4/Firm_info_GROUP1_merge.dta", replace
clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP2/BEC_GROUP1_merge.dta", clear
sort firm_id_zipcode
merge m:1 firm_id_zipcode using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP4/Firm_info_GROUP1_merge.dta", generate(flag)
ren _merge _merge_firm_geoc_final
drop if po == ""
drop  id_firm uf_firm city_firm address_firm ddd_firm
ren latit_firm firm_latit_1
ren longit_firm firm_longit_1

gen firm_latit=firm_latit_1
replace firm_latit=latitude if firm_latit_1==.

gen firm_longit=firm_longit_1
replace firm_longit=longitude if firm_longit_1==.

drop if firm_latit==.


geodist pbu_latit pbu_longit firm_latit firm_longit , generate(dist)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP5/BEC_GROUP1_merge_DIST.dta", replace



* 7- By PO (#different items, #different groups, #different classes)



preserve

gen item_count=1
keep po item item_count
duplicates drop
collapse (count) n_items_po=item_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOitems_GROUP1_merge.dta", replace

restore 


preserve

gen group_count=1
keep po group_item group_count
duplicates drop
collapse (count) n_groups_po=group_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOgroups_GROUP1_merge.dta", replace

restore 


preserve

gen class_count=1
keep po class_item class_count
duplicates drop
collapse (count) n_classes_po=class_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOclasses_GROUP1_merge.dta", replace

restore 

sort po
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOitems_GROUP1_merge.dta", generate(flag_items)
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOgroups_GROUP1_merge.dta", generate(flag_groups)
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOclasses_GROUP1_merge.dta", generate(flag_classes)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP7/BEC_GROUP1_merge_BYPO.dta", replace



* 8- By OC + ITEM + Firm CNPJ: Info about each po + item

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP7/BEC_GROUP1_merge_BYPO.dta", clear



tabulate firm_type_code, generate (n_firm_type)



label variable n_firm_type1 "COOPERATIVA"

label variable n_firm_type2 "COOPERATIVA ATIVA DIR PREF"

label variable n_firm_type3 "EPP"

label variable n_firm_type4 "NÃO CADASTRADO CAUFESP"

label variable n_firm_type5 "ME"

label variable n_firm_type6 "OUTROS"

gen firm_type_key = po + item
sort firm_type_key firm_id


preserve


keep firm_type_key firm_id n_firm_type1 n_firm_type2 n_firm_type3 n_firm_type4 n_firm_type5 n_firm_type6
sort firm_type_key
duplicates drop
collapse (sum) tot_firm_type1=n_firm_type1 tot_firm_type2=n_firm_type2 tot_firm_type3=n_firm_type3 tot_firm_type4=n_firm_type4 tot_firm_type5=n_firm_type5 tot_firm_type6=n_firm_type6 , /// 
by(firm_type_key)
sort firm_type_key
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOITEM_firm_type_GROUP1_merge.dta", replace

restore 

sort firm_type_key
merge m:1 firm_type_key using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOITEM_firm_type_GROUP1_merge.dta", generate(flag_firms)



* 9- By OC + ITEM + PO_PHASE : Info about each po + item + po_phase



preserve


keep po item firm_id pot_epp_me
duplicates drop
collapse (count) tot_pot_epp_me=pot_epp_me, /// 
by(po item)
gen key_epp = po + item
sort key_epp
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemEPP_GROUP1_merge.dta", replace

restore 

gen key_epp = po + item
sort key_epp
merge m:1 key_epp using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemEPP_GROUP1_merge.dta", generate(flag_EPP)


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/Before_collapse_GROUP1.dta", replace



destring po_phase_code, replace

tostring item, replace
tostring po_phase_code, replace

preserve

/*
drop if bid_status==0
*/
gen key_po_phase_code = po+item+po_phase_code
destring bid_winner, replace

keep po item po_phase_code unique_firm bid_count bid_winner dist bid_unit_price bid_time_date bid_unit_price_negot /// 
bid_ref_price bid_price_acession bid_price_prop bid_price_bids bid_price_negot bid_price_pref ///
bid_price_realinh key_po_phase_code same_city_pbu_firm firm_state_sp same_city_pbu_firm_acession ///
same_city_pbu_firm_prop same_city_pbu_firm_bids same_city_pbu_firm_negot same_city_pbu_firm_pref ///
same_city_pbu_firm_realinh firm_state_sp_acession firm_state_sp_prop firm_state_sp_bids firm_state_sp_negot ///
firm_state_sp_pref firm_state_sp_realinh bid_price_n_a same_city_pbu_firm_n_a firm_state_sp_n_a

duplicates drop
collapse (sum) n_firms=unique_firm n_bids=bid_count po_winner_sum=bid_winner same_city_pbu_firm_sum=same_city_pbu_firm firm_state_sp_sum=firm_state_sp same_city_pbu_firm_acession_sum=same_city_pbu_firm_acession same_city_pbu_firm_prop_sum=same_city_pbu_firm_prop 	same_city_pbu_firm_bids_sum=same_city_pbu_firm_bids ///
same_city_pbu_firm_negot_sum=same_city_pbu_firm_negot  	same_city_pbu_firm_pref_sum=same_city_pbu_firm_pref 	same_city_pbu_firm_realinh_sum=same_city_pbu_firm_realinh 	 firm_state_sp_acession_sum= firm_state_sp_acession 	 firm_state_sp_prop_sum= firm_state_sp_prop 	 firm_state_sp_bids_sum= firm_state_sp_bids ///
firm_state_sp_negot_sum= firm_state_sp_negot 	 firm_state_sp_pref_sum= firm_state_sp_pref 	 firm_state_sp_realinh_sum= firm_state_sp_realinh bid_price_n_a_sum=bid_price_n_a same_city_pbu_firm_n_a_sum=same_city_pbu_firm_n_a firm_state_sp_n_a_sum=firm_state_sp_n_a /// 
(min) dist_min=dist bid_price_min=bid_unit_price bid_time_min=bid_time_date bid_unit_price_negot_min=bid_unit_price_negot bid_ref_price_min=bid_ref_price bid_price_acession_min=bid_price_acession bid_price_prop_min=bid_price_prop bid_price_bids_min=bid_price_bids bid_price_negot_min=bid_price_negot bid_price_pref_min=bid_price_pref bid_price_realinh_min=bid_price_realinh bid_price_n_a_min=bid_price_n_a same_city_pbu_firm_n_a_min=same_city_pbu_firm_n_a firm_state_sp_n_a_min=firm_state_sp_n_a /// 
(max) dist_max=dist bid_price_max=bid_unit_price po_winner_max=bid_winner bid_time_max=bid_time_date bid_unit_price_negot_max=bid_unit_price_negot bid_ref_price_max=bid_ref_price bid_price_acession_max=bid_price_acession bid_price_prop_max=bid_price_prop bid_price_bids_max=bid_price_bids bid_price_negot_max=bid_price_negot bid_price_pref_max=bid_price_pref bid_price_realinh_max=bid_price_realinh bid_price_n_a_max=bid_price_n_a same_city_pbu_firm_n_a_max=same_city_pbu_firm_n_a firm_state_sp_n_a_max=firm_state_sp_n_a /// 
(mean) dist_mean=dist bid_price_mean=bid_unit_price bid_price_acession_mean=bid_price_acession bid_price_prop_mean=bid_price_prop bid_price_bids_mean=bid_price_bids bid_price_negot_mean=bid_price_negot bid_price_pref_mean=bid_price_pref bid_price_realinh_mean=bid_price_realinh bid_price_n_a_mean=bid_price_n_a same_city_pbu_firm_n_a_mean=same_city_pbu_firm_n_a firm_state_sp_n_a_mean=firm_state_sp_n_a /// 
(median) dist_median=dist bid_price_median=bid_unit_price bid_price_acession_median=bid_price_acession bid_price_prop_median=bid_price_prop bid_price_bids_median=bid_price_bids bid_price_negot_median=bid_price_negot bid_price_pref_median=bid_price_pref bid_price_realinh_median=bid_price_realinh bid_price_n_a_median=bid_price_n_a same_city_pbu_firm_n_a_median=same_city_pbu_firm_n_a firm_state_sp_n_a_median=firm_state_sp_n_a /// 
(sd) dist_sd=dist bid_price_sd=bid_unit_price bid_price_acession_sd=bid_price_acession bid_price_prop_sd=bid_price_prop bid_price_bids_sd=bid_price_bids bid_price_negot_sd=bid_price_negot bid_price_pref_sd=bid_price_pref bid_price_realinh_sd=bid_price_realinh bid_price_n_a_sd=bid_price_n_a same_city_pbu_firm_n_a_sd=same_city_pbu_firm_n_a firm_state_sp_n_a_sd=firm_state_sp_n_a /// 
(semean) dist_semean=dist bid_price_semean=bid_unit_price bid_price_acession_semean=bid_price_acession bid_price_prop_semean=bid_price_prop bid_price_bids_semean=bid_price_bids bid_price_negot_semean=bid_price_negot bid_price_pref_semean=bid_price_pref bid_price_realinh_semean=bid_price_realinh bid_price_n_a_semean=bid_price_n_a same_city_pbu_firm_n_a_semean=same_city_pbu_firm_n_a firm_state_sp_n_a_semean=firm_state_sp_n_a, by(key_po_phase_code)

sort key_po_phase_code
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemPHASE_GROUP1_merge.dta", replace



restore 

tostring po_phase_code, replace
gen key_po_phase_code = po+item+po_phase_code
sort key_po_phase_code

merge m:1 key_po_phase_code using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemPHASE_GROUP1_merge.dta", generate(flag_Phase)


preserve

gen key_qty = po + item
keep key_qty bid_item_qty_perbid
duplicates drop
collapse (max) bid_qty_item=bid_item_qty_perbid, by(key_qty)

sort key_qty
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemQTY_GROUP1_merge.dta", replace

restore

gen key_qty = po + item
sort key_qty

merge m:1 key_qty using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemQTY_GROUP1_merge.dta", generate(flag_qty)


gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BEC_FINAL_GROUP1_LANCE_LANCE.dta", replace


drop diamêsencerramento firm_id firm_legal_nature firm_descr descriçãotipoempresa descriçãoenquadramento_caufesp ///
descriçãofornecedorstatus firm_city firm_state descriçãopaísfornecedor descriçãotipoendereçofornecedor firm_zipcode diamêsagendamento ///
firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code bid_status bid_status_group_code ///
po_phase_code pot_epp_me po_phase_code_str pbu_year pbu_power_code pbu_type_mgmt_code pbu_uf pbu_ibge_cod_uf ibge_cod_cidade_firm pbu_city_area /// 
pbu_zipcode pbu_latit_1 pbu_longit_1  nome latitude longitude capital codigo_uf _merge_firm_geoc_final pbu_latit pbu_longit bid_id bid_count ///
bid_time_date firm_latit_1 firm_longit_1 ibge_cod_uf_firm area_cidade_km2_firm _merge_cities dupl _merge_firm_geoc flag firm_latit firm_longit /// 
flag_items flag_groups flag_classes flag_firms key_epp flag_EPP flag_qty códdescmunicípiodeentrega códdescregiãodeentrega pbu_code_year ///
po_item_merge_key bid_rank po_item_id po_item_key unique_firm firm_zipcode_length firm_id_zipcode firm_type_key key_po_phase_code flag_Phase key_qty ///
bid_unit_price bid_winner bid_unit_price_negot bid_ref_price same_city_pbu_firm firm_state_sp ///
bid_price_acession bid_price_prop bid_price_bids bid_price_negot bid_price_pref bid_price_realinh ///
same_city_pbu_firm_acession same_city_pbu_firm_prop same_city_pbu_firm_bids same_city_pbu_firm_negot ///
same_city_pbu_firm_pref same_city_pbu_firm_realinh firm_state_sp_acession firm_state_sp_prop firm_state_sp_bids ///
firm_state_sp_negot firm_state_sp_pref firm_state_sp_realinh dist bid_item_qty_perbid n_firm_type1 n_firm_type2 n_firm_type3 ///
n_firm_type4 n_firm_type5 n_firm_type6 date    m_y     year bid_price_n_a same_city_pbu_firm_n_a firm_state_sp_n_a t



save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BEC_FINAL_GROUP1_PREPARING_COLLAPSE1.dta", replace



collapse (max) bid_price_acession_max1=bid_price_acession_max	bid_price_acession_mean1=bid_price_acession_mean ///
bid_price_acession_median1=bid_price_acession_median	bid_price_acession_min1=bid_price_acession_min	bid_price_acession_sd1=bid_price_acession_sd ///
bid_price_acession_semean1=bid_price_acession_semean	bid_price_bids_max1=bid_price_bids_max	bid_price_bids_mean1=bid_price_bids_mean ///
bid_price_bids_median1=bid_price_bids_median	bid_price_bids_min1=bid_price_bids_min	bid_price_bids_sd1=bid_price_bids_sd ///
bid_price_bids_semean1=bid_price_bids_semean	bid_price_max1=bid_price_max	bid_price_mean1=bid_price_mean	bid_price_median1=bid_price_median ///
bid_price_min1=bid_price_min	bid_price_negot_max1=bid_price_negot_max	bid_price_negot_mean1=bid_price_negot_mean ///
bid_price_negot_median1=bid_price_negot_median	bid_price_negot_min1=bid_price_negot_min	bid_price_negot_sd1=bid_price_negot_sd ///
bid_price_negot_semean1=bid_price_negot_semean	bid_price_pref_max1=bid_price_pref_max	bid_price_pref_mean1=bid_price_pref_mean ///
bid_price_pref_median1=bid_price_pref_median	bid_price_pref_min1=bid_price_pref_min	bid_price_pref_sd1=bid_price_pref_sd ///
bid_price_pref_semean1=bid_price_pref_semean	bid_price_prop_max1=bid_price_prop_max	bid_price_prop_mean1=bid_price_prop_mean ///
bid_price_prop_median1=bid_price_prop_median	bid_price_prop_min1=bid_price_prop_min	bid_price_prop_sd1=bid_price_prop_sd ///
bid_price_prop_semean1=bid_price_prop_semean	bid_price_realinh_max1=bid_price_realinh_max	bid_price_realinh_mean1=bid_price_realinh_mean ///
bid_price_realinh_median1=bid_price_realinh_median	bid_price_realinh_min1=bid_price_realinh_min	bid_price_realinh_sd1=bid_price_realinh_sd ///
bid_price_realinh_semean1=bid_price_realinh_semean	bid_price_sd1=bid_price_sd	bid_price_semean1=bid_price_semean	bid_qty_item1=bid_qty_item ///
bid_ref_price_max1=bid_ref_price_max	bid_ref_price_min1=bid_ref_price_min	bid_time_max1=bid_time_max	bid_time_min1=bid_time_min ///
bid_unit_price_negot_max1=bid_unit_price_negot_max	bid_unit_price_negot_min1=bid_unit_price_negot_min	dist_max1=dist_max	dist_mean1=dist_mean ///
dist_median1=dist_median	dist_min1=dist_min	dist_sd1=dist_sd	dist_semean1=dist_semean	firm_state_sp_acession_sum1=firm_state_sp_acession_sum ///
firm_state_sp_bids_sum1=firm_state_sp_bids_sum	firm_state_sp_negot_sum1=firm_state_sp_negot_sum	firm_state_sp_pref_sum1=firm_state_sp_pref_sum ///
firm_state_sp_prop_sum1=firm_state_sp_prop_sum	firm_state_sp_realinh_sum1=firm_state_sp_realinh_sum	firm_state_sp_sum1=firm_state_sp_sum ///
n_bids1=n_bids	n_classes_po1=n_classes_po	n_firms1=n_firms	n_groups_po1=n_groups_po	n_items_po1=n_items_po	po_winner_max1=po_winner_max ///
po_winner_sum1=po_winner_sum	proc_length_days1=proc_length_days	proc_length_hours1=proc_length_hours	proc_length_minutes1=proc_length_minutes ///
proc_length_seconds1=proc_length_seconds	same_city_pbu_firm_acession_sum1=same_city_pbu_firm_acession_sum ///
same_city_pbu_firm_bids_sum1=same_city_pbu_firm_bids_sum	same_city_pbu_firm_negot_sum1=same_city_pbu_firm_negot_sum	///
same_city_pbu_firm_pref_sum1=same_city_pbu_firm_pref_sum	same_city_pbu_firm_prop_sum1=same_city_pbu_firm_prop_sum ///
same_city_pbu_firm_realinh_sum1=same_city_pbu_firm_realinh_sum	same_city_pbu_firm_sum1=same_city_pbu_firm_sum	tot_firm_type11=tot_firm_type1 ///
tot_firm_type21=tot_firm_type2	tot_firm_type31=tot_firm_type3	tot_firm_type41=tot_firm_type4	tot_firm_type51=tot_firm_type5 ///
bid_price_n_a_sum1=bid_price_n_a_sum same_city_pbu_firm_n_a_sum1=same_city_pbu_firm_n_a_sum firm_state_sp_n_a_sum1=firm_state_sp_n_a_sum ///
bid_price_n_a_min1=bid_price_n_a_min same_city_pbu_firm_n_a_min1=same_city_pbu_firm_n_a_min firm_state_sp_n_a_min1=firm_state_sp_n_a_min ///
bid_price_n_a_max1=bid_price_n_a_max same_city_pbu_firm_n_a_max1=same_city_pbu_firm_n_a_max firm_state_sp_n_a_max1=firm_state_sp_n_a_max ///
bid_price_n_a_mean1=bid_price_n_a_mean same_city_pbu_firm_n_a_mean1=same_city_pbu_firm_n_a_mean firm_state_sp_n_a_mean1=firm_state_sp_n_a_mean ///
bid_price_n_a_median1=bid_price_n_a_median same_city_pbu_firm_n_a_median1=same_city_pbu_firm_n_a_median firm_state_sp_n_a_median1=firm_state_sp_n_a_median ///
bid_price_n_a_sd1=bid_price_n_a_sd same_city_pbu_firm_n_a_sd1=same_city_pbu_firm_n_a_sd firm_state_sp_n_a_sd1=firm_state_sp_n_a_sd ///
bid_price_n_a_semean1=bid_price_n_a_semean same_city_pbu_firm_n_a_semean1=same_city_pbu_firm_n_a_semean firm_state_sp_n_a_semean1=firm_state_sp_n_a_semean ///
tot_firm_type61=tot_firm_type6	tot_pot_epp_me1=tot_pot_epp_me, by(po	categ_item	class_item	class_item_descr	group_item	group_item_descr ///
item	item_descr	item_unit	pbu_code	po_status	po_status_code	proc	price_reg	green_item	item_type)


save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/Collapse_1_GROUP1_PRE.dta", replace

duplicates drop po item, force
gen key1_merge=po + item
sort key1_merge


save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/Collapse_1_GROUP1.dta", replace




merge 1:1 key1_merge using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2.dta", generate(flag_collapse)
drop if flag_collapse==2

  
save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BEC_COLLAPSE_GROUP1.dta", replace


clear all






***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************

* PART TWO


***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************



*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1" 			// Defining Main Directory 

* Final product: Collapse_1A.dta

* 1- Appending Files (Yearly)

/*
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_1.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante  quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_1.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_2.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_2.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_3.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_3.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_4.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_4.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_5.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_5.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_6.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_6.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_7.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_7.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_8.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_8.dta", replace
clear all
*/

/*
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_9.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_9.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_10.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_10.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_11.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_11.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_12.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_12.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_13.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_13.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_14.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_14.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_15.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_15.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_16.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_16.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_17.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_17.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_18.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_18.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_19.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_19.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_20.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_20.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_21.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_21.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_22.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_22.dta", replace
clear all
*/


use LANCES_16.dta, clear
append using LANCES_15.dta
append using LANCES_14.dta
append using LANCES_13.dta
append using LANCES_12.dta
append using LANCES_11.dta
append using LANCES_10.dta
append using LANCES_9.dta


/*
use LANCES_22.dta, clear
append using LANCES_21.dta
append using LANCES_20.dta
append using LANCES_19.dta
append using LANCES_18.dta
append using LANCES_17.dta
append using LANCES_16.dta
append using LANCES_15.dta
append using LANCES_14.dta
append using LANCES_13.dta
append using LANCES_12.dta
append using LANCES_11.dta
append using LANCES_10.dta
append using LANCES_9.dta
append using LANCES_8.dta
append using LANCES_7.dta
append using LANCES_6.dta
append using LANCES_5.dta
append using LANCES_4.dta
append using LANCES_3.dta
append using LANCES_2.dta
append using LANCES_1.dta
*/


gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/BEC_GROUP2.dta", replace



* 2- Preparing variables (Renaming variables in English)

ren date1 m_y
label variable m_y "Month and Year"

egen t = group(m_y)
label variable t "Month and Year from 1 to 120"

ren descriçãoprocedimentocompra descrproc
egen proc = group(descrproc)
label variable proc "1 = CONVITE; 2 = DISPENSA DE LICITAÇÃO; 3 = PREGÃO ELETRÔNICO"

ren numerodaoc po
label variable po "Purchase Order Number"

egen price_reg = group(ataregistrodepreço)
replace price_reg = price_reg - 1
label variable price_reg "Price Registration? 0 = No; 1 = Yes"

destring códigocategoria, replace
replace códigocategoria = 0 if códigocategoria == 2
ren códigocategoria categ_item
label variable categ_item "0 = Service; 1 = Good"

ren códigoclasse class_item
label variable class_item "Class of Item Code" 

ren códigogrupo group_item
label variable group_item "Group of Item Code"

ren códigoitem item
label variable item "Item Code"

ren descunidadefornecimento item_unit
label variable item_unit "Item unit"

gen green_item = 0
replace green_item = 1 if seloverde == "S"
label variable green_item "Green Item? 0 = No; 1 = Yes"

ren valorunitárioproposta bid_unit_price
label variable bid_unit_price "Bid unit price with no negotiation"

ren flagvencedor bid_winner
label variable bid_winner "Bid made by the winner firm? 0 = No; 1 = Yes (not necessarily the winner bid)"

ren datahrproposta bid_time
label variable bid_time "Day and time of the bid"

ren valorunitarionegociado bid_unit_price_negot
label variable bid_unit_price_negot "Bid unit price after negotiation"

ren valorunitárioreferência bid_ref_price
label variable bid_ref_price "Reference Price"

ren qtdeofertadecompraitemnegociado bid_item_qty_perbid
label variable bid_item_qty_perbid "Bid item quantity per bid"

ren códigofornecedor firm_id
label variable firm_id "CNPJ or CPF"

ren descriçãoenquadramento firm_type
label variable firm_type "Firm type: Cooperativa, Cooperativa Direito de Pref., EPP, Enquadramento não cadastrado no CAUFESP, ME, Outros"

ren descriçãofisicajurídica firm_person
label variable firm_person "Pessoa Física ou Jurídica"

ren descriçãomatrizfilial firm_headqtr_branch
label variable firm_headqtr_branch "Headquarter or Branch"

ren descriçãonaturezajurídica firm_legal_nature
label variable firm_legal_nature "Firm legal nature"	

ren descriçãosimplesnacional firm_simples
label variable firm_simples "Simples Nacional"

ren descriçãopropostastatus bid_status
label variable bid_status "Bid status specific level"

ren descriçãogrupopropostastatus bid_status_group
label variable bid_status_group "Bid status general level"

ren descriçãofasesoc po_phase
label variable po_phase "Purchase Order Phase"

ren códigounidadecompradora pbu_code
label variable pbu_code "Public Buyer Unit code in the BEC Catalog"

ren descriçãomunicípiofornecedor firm_city
label variable firm_city "Firm city"

ren descriçãouffornecedor firm_state
label variable firm_state "Firm state"

ren códigocepfornecedor firm_zipcode
label variable firm_zipcode "Firm zipcode"

ren códigomunicípiodeentrega pbu_city_delivery_code
label variable pbu_city_delivery_code "City code of delivery"

ren descriçãomunicípiodeentrega pbu_city_delivery
label variable pbu_city_delivery "City of delivery"

ren códigoregiãodeentrega pbu_region_delivery_code
label variable pbu_region_delivery_code "Region code of delivery"

ren descriçãoregiãodeentrega pbu_region_delivery
label variable pbu_region_delivery "Region of delivery"

ren descriçãoofertadecomprastatus po_status
label variable po_status "PO status"

ren códigoofertadecomprastatus po_status_code
label variable po_status_code "PO status code"

ren desccategoriaitem categ_item_descr
label variable categ_item_descr "Item category description"

ren descclasseitem class_item_descr
label variable class_item_descr "Item class description"

ren descgrupoitem group_item_descr
label variable group_item_descr "Item group description"

ren descitem item_descr
label variable item_descr "Item description"

ren descriçãorazãosocial firm_descr
label variable firm_descr "Firm Description"

gen date = m_y

destring date, replace
gen date1 = monthly(date, "MY")
format date1 %tm

split date, p("/") gen(substr)

drop substr1 m_y  ataregistrodepreço seloverde descriçãounidadecompradora descrproc
drop if po == ""

ren date1 m_y

ren substr2 year

gen pbu_code_year = pbu_code + year

label variable date "Date destring"

label variable m_y "Date in date format"

label variable year "Year"

label variable pbu_code_year "Key variable for UCs merge"

egen item_type = group(categ_item_descr)
label variable item_type "1=MATERIAL;2=SERVIÇO"
drop categ_item_descr

egen firm_type_code = group(firm_type)
label variable firm_type_code "1=COOPERATIVA;2=COOPERATIVA DIR PREF;3=EPP;4=NÃO CADAST CAUFESP;5=ME;6=OUTROS"
drop firm_type

egen firm_person_code = group(firm_person)
label variable firm_person_code "1=FISICA;2=JURIDICA;3=SEM CADASTRO"
drop firm_person

egen firm_headqtr_branch_code = group(firm_headqtr_branch)
label variable firm_headqtr_branch_code "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CADASTRO"
drop firm_headqtr_branch

egen  firm_legal_nature_code = group(firm_legal_nature)
label variable firm_legal_nature_code "Type of Firm"


egen firm_simples_code = group(firm_simples)
label variable firm_simples_code "1=N/A;2=NÃO;3=SIM"
drop firm_simples

egen bid_status_code = group(bid_status)
drop bid_status
gen bid_status = bid_status_code
replace bid_status = 0 if bid_status_code >= 2 & bid_status_code <= 15
replace bid_status = 1 if bid_status_code==1 | bid_status_code==16 | bid_status_code==17
drop bid_status_code
label variable bid_status "0=INVALIDO;1=VALIDO"

egen bid_status_group_code = group(bid_status_group)
label variable bid_status_group_code "1=CLASSIF;2=DESCLASSIF;3=INVÁLIDO;4=N/A;5=VÁLIDO"
drop bid_status_group

egen po_phase_code = group(po_phase)
label variable po_phase_code "1=AD MELH OFERTA;2=PROPS;3=LANCES;4=NEGOC;5=N/A;6=ME-EPP;7=REALINH PREÇO COOPERAT"
drop po_phase

drop razãosocial

destring bid_unit_price bid_unit_price_negot bid_ref_price bid_item_qty_perbid, replace dpcomma

sort pbu_code_year

gen pot_epp_me = 0
replace pot_epp_me=1 if firm_legal_nature=="ASSOCIAÇÃO PRIVADA" | firm_legal_nature=="COOPERATIVA" | firm_legal_nature=="EMP. INDIV. RESPONS. LIMITADA-EIRELI (EMPRESÁRIA)" | firm_legal_nature=="EMP. INDIV. RESPONS. LIMITADA-EIRELI (SIMPLES)" | ///
firm_legal_nature=="EMPRESÁRIO (INDIVIDUAL)" | firm_legal_nature=="EMPRESÁRIO (INDIVIDUAL) - MEI" | firm_legal_nature=="SOCIEDADE CIVIL" | firm_legal_nature=="SOCIEDADE EMPRESÁRIA LIMITADA" | firm_legal_nature=="SOCIEDADE SIMPLES" | ///
firm_legal_nature=="SOCIEDADE SIMPLES LIMITADA" | firm_legal_nature=="SOCIEDADE SIMPLES PURA"

// drop if po_phase_code == 5
// replace po_phase_code = 5 if po_phase_code == 6
// replace po_phase_code = 6 if po_phase_code == 7
// label variable po_phase_code "1=AD MELH OFERTA;2=PROPS;3=LANCES;4=NEGOC;5=ME-EPP;6=REALINH PREÇO COOPERAT"


gen po_phase_code_str=po_phase_code
tostring po_phase_code_str, replace
gen po_item_merge_key = po + item + po_phase_code_str + item_unit
bysort po_item_merge_key (bid_unit_price): gen bid_rank = sum(bid_unit_price != bid_unit_price[_n-1])

gen bid_price_acession = bid_unit_price if po_phase_code == 1
gen bid_price_prop = bid_unit_price if po_phase_code == 2
gen bid_price_bids = bid_unit_price if po_phase_code == 3
gen bid_price_negot = bid_unit_price if po_phase_code == 4
gen bid_price_n_a = bid_unit_price if po_phase_code == 5
gen bid_price_pref = bid_unit_price if po_phase_code == 6
gen bid_price_realinh = bid_unit_price if po_phase_code == 7


// drop if bid_status==0




* 3- Geocoding UCs (Original Latit/Longit if available; otherwise, city latit/longit) 


merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE_cities.dta", gen(flag)
drop if po == ""



* 4- Working in full file (Creating extra variables)

gen bid_id = _n
label variable bid_id "Bid ID (Primary Key)"
																	
gen same_city_pbu_firm = 0
replace same_city_pbu_firm = 1 if firm_city == pbu_city_descr
label variable same_city_pbu_firm "Pbu and Firm in the same city? 0 = No; 1 = Yes"

gen firm_state_sp = 0
replace firm_state_sp = 1 if firm_state == "SÃO PAULO"
label variable firm_state_sp "Firm in São Paulo State? 0 = No; 1 = Yes"


destring po_phase_code, replace

gen same_city_pbu_firm_acession=same_city_pbu_firm if po_phase_code==1
gen same_city_pbu_firm_prop=same_city_pbu_firm if po_phase_code==2
gen same_city_pbu_firm_bids=same_city_pbu_firm if po_phase_code==3
gen same_city_pbu_firm_negot=same_city_pbu_firm if po_phase_code==4
gen same_city_pbu_firm_n_a=same_city_pbu_firm if po_phase_code==5
gen same_city_pbu_firm_pref=same_city_pbu_firm if po_phase_code==6
gen same_city_pbu_firm_realinh=same_city_pbu_firm if po_phase_code==7

gen firm_state_sp_acession=firm_state_sp if po_phase_code==1
gen firm_state_sp_prop=firm_state_sp if po_phase_code==2
gen firm_state_sp_bids=firm_state_sp if po_phase_code==3
gen firm_state_sp_negot=firm_state_sp if po_phase_code==4
gen firm_state_sp_n_a=firm_state_sp if po_phase_code==5
gen firm_state_sp_pref=firm_state_sp if po_phase_code==6
gen firm_state_sp_realinh=firm_state_sp if po_phase_code==7

tostring item, replace
tostring po_phase_code, replace

gen po_item_id = po + item + po_phase_code
gen po_item_key = po + item
gen bid_count = 1

gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time


sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1

rename nvals unique_firm

drop pbu_city_delivery_code pbu_city_delivery pbu_region_delivery_code pbu_region_delivery pubag_code pubag_descr pubbudget_code pubbudget_descr pbu_descr ///
pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_cnpj pbu_power pbu_type_mgmt_descr

drop flag 



/*
replace bid_unit_price = . if bid_unit_price == 0
replace bid_unit_price_negot = . if bid_unit_price_negot == 0
replace bid_ref_price = . if bid_ref_price == 0
replace bid_item_qty_perbid = . if bid_item_qty_perbid == 0
*/



* 5- Saving Baseline and Separating Firm info (Preparing for geocoding firms)

gen firm_zipcode_length=length(firm_zipcode)
tab firm_zipcode_length
replace firm_zipcode = "0" + firm_zipcode if firm_zipcode_length==7
gen firm_id_zipcode = firm_id + firm_zipcode
sort firm_id_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP2/BEC_GROUP2_merge.dta", replace

keep  firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state ///
firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP3/Firm_info_GROUP2.dta", replace


* 6- Geocoding Firms (Creating source file and geocoding firms)

* Excluir esta parte

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP3/Firm_info_GROUP2.dta", clear


merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Geocoding_firm_zipcode_cities.dta"
ren _merge _merge_firm_geoc
drop if _merge_firm_geoc==1
drop if _merge_firm_geoc==2
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP4/Firm_info_GROUP2_merge.dta", replace
clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP2/BEC_GROUP2_merge.dta", clear
sort firm_id_zipcode
merge m:1 firm_id_zipcode using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP4/Firm_info_GROUP2_merge.dta", generate(flag)
ren _merge _merge_firm_geoc_final
drop if po == ""
drop  id_firm uf_firm city_firm address_firm ddd_firm
ren latit_firm firm_latit_1
ren longit_firm firm_longit_1

gen firm_latit=firm_latit_1
replace firm_latit=latitude if firm_latit_1==.

gen firm_longit=firm_longit_1
replace firm_longit=longitude if firm_longit_1==.

drop if firm_latit==.


geodist pbu_latit pbu_longit firm_latit firm_longit , generate(dist)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP5/BEC_GROUP2_merge_DIST.dta", replace



* 7- By PO (#different items, #different groups, #different classes)



preserve

gen item_count=1
keep po item item_count
duplicates drop
collapse (count) n_items_po=item_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOitems_GROUP2_merge.dta", replace

restore 


preserve

gen group_count=1
keep po group_item group_count
duplicates drop
collapse (count) n_groups_po=group_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOgroups_GROUP2_merge.dta", replace

restore 


preserve

gen class_count=1
keep po class_item class_count
duplicates drop
collapse (count) n_classes_po=class_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOclasses_GROUP2_merge.dta", replace

restore 

sort po
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOitems_GROUP2_merge.dta", generate(flag_items)
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOgroups_GROUP2_merge.dta", generate(flag_groups)
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOclasses_GROUP2_merge.dta", generate(flag_classes)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP7/BEC_GROUP2_merge_BYPO.dta", replace



* 8- By OC + ITEM + Firm CNPJ: Info about each po + item

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP7/BEC_GROUP2_merge_BYPO.dta", clear



tabulate firm_type_code, generate (n_firm_type)


***************
gen n_firm_type6=n_firm_type5
replace n_firm_type5=n_firm_type4
replace n_firm_type4=n_firm_type3
replace n_firm_type3=n_firm_type2
replace n_firm_type2=0

*****************

label variable n_firm_type1 "COOPERATIVA"

label variable n_firm_type2 "COOPERATIVA ATIVA DIR PREF"

label variable n_firm_type3 "EPP"

label variable n_firm_type4 "NÃO CADASTRADO CAUFESP"

label variable n_firm_type5 "ME"

label variable n_firm_type6 "OUTROS"

gen firm_type_key = po + item
sort firm_type_key firm_id


preserve


keep firm_type_key firm_id n_firm_type1 n_firm_type2 n_firm_type3 n_firm_type4 n_firm_type5 n_firm_type6
sort firm_type_key
duplicates drop
collapse (sum) tot_firm_type1=n_firm_type1 tot_firm_type2=n_firm_type2 tot_firm_type3=n_firm_type3 tot_firm_type4=n_firm_type4 tot_firm_type5=n_firm_type5 tot_firm_type6=n_firm_type6 , /// 
by(firm_type_key)
sort firm_type_key
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOITEM_firm_type_GROUP2_merge.dta", replace

restore 

sort firm_type_key
merge m:1 firm_type_key using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOITEM_firm_type_GROUP2_merge.dta", generate(flag_firms)



* 9- By OC + ITEM + PO_PHASE : Info about each po + item + po_phase



preserve


keep po item firm_id pot_epp_me
duplicates drop
collapse (count) tot_pot_epp_me=pot_epp_me, /// 
by(po item)
gen key_epp = po + item
sort key_epp
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemEPP_GROUP2_merge.dta", replace

restore 

gen key_epp = po + item
sort key_epp
merge m:1 key_epp using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemEPP_GROUP2_merge.dta", generate(flag_EPP)


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/Before_collapse_GROUP2.dta", replace



destring po_phase_code, replace

tostring item, replace
tostring po_phase_code, replace

preserve

/*
drop if bid_status==0
*/
gen key_po_phase_code = po+item+po_phase_code
destring bid_winner, replace

keep po item po_phase_code unique_firm bid_count bid_winner dist bid_unit_price bid_time_date bid_unit_price_negot /// 
bid_ref_price bid_price_acession bid_price_prop bid_price_bids bid_price_negot bid_price_pref ///
bid_price_realinh key_po_phase_code same_city_pbu_firm firm_state_sp same_city_pbu_firm_acession ///
same_city_pbu_firm_prop same_city_pbu_firm_bids same_city_pbu_firm_negot same_city_pbu_firm_pref ///
same_city_pbu_firm_realinh firm_state_sp_acession firm_state_sp_prop firm_state_sp_bids firm_state_sp_negot ///
firm_state_sp_pref firm_state_sp_realinh bid_price_n_a same_city_pbu_firm_n_a firm_state_sp_n_a

duplicates drop
collapse (sum) n_firms=unique_firm n_bids=bid_count po_winner_sum=bid_winner same_city_pbu_firm_sum=same_city_pbu_firm firm_state_sp_sum=firm_state_sp same_city_pbu_firm_acession_sum=same_city_pbu_firm_acession same_city_pbu_firm_prop_sum=same_city_pbu_firm_prop 	same_city_pbu_firm_bids_sum=same_city_pbu_firm_bids ///
same_city_pbu_firm_negot_sum=same_city_pbu_firm_negot  	same_city_pbu_firm_pref_sum=same_city_pbu_firm_pref 	same_city_pbu_firm_realinh_sum=same_city_pbu_firm_realinh 	 firm_state_sp_acession_sum= firm_state_sp_acession 	 firm_state_sp_prop_sum= firm_state_sp_prop 	 firm_state_sp_bids_sum= firm_state_sp_bids ///
firm_state_sp_negot_sum= firm_state_sp_negot 	 firm_state_sp_pref_sum= firm_state_sp_pref 	 firm_state_sp_realinh_sum= firm_state_sp_realinh bid_price_n_a_sum=bid_price_n_a same_city_pbu_firm_n_a_sum=same_city_pbu_firm_n_a firm_state_sp_n_a_sum=firm_state_sp_n_a /// 
(min) dist_min=dist bid_price_min=bid_unit_price bid_time_min=bid_time_date bid_unit_price_negot_min=bid_unit_price_negot bid_ref_price_min=bid_ref_price bid_price_acession_min=bid_price_acession bid_price_prop_min=bid_price_prop bid_price_bids_min=bid_price_bids bid_price_negot_min=bid_price_negot bid_price_pref_min=bid_price_pref bid_price_realinh_min=bid_price_realinh bid_price_n_a_min=bid_price_n_a same_city_pbu_firm_n_a_min=same_city_pbu_firm_n_a firm_state_sp_n_a_min=firm_state_sp_n_a /// 
(max) dist_max=dist bid_price_max=bid_unit_price po_winner_max=bid_winner bid_time_max=bid_time_date bid_unit_price_negot_max=bid_unit_price_negot bid_ref_price_max=bid_ref_price bid_price_acession_max=bid_price_acession bid_price_prop_max=bid_price_prop bid_price_bids_max=bid_price_bids bid_price_negot_max=bid_price_negot bid_price_pref_max=bid_price_pref bid_price_realinh_max=bid_price_realinh bid_price_n_a_max=bid_price_n_a same_city_pbu_firm_n_a_max=same_city_pbu_firm_n_a firm_state_sp_n_a_max=firm_state_sp_n_a /// 
(mean) dist_mean=dist bid_price_mean=bid_unit_price bid_price_acession_mean=bid_price_acession bid_price_prop_mean=bid_price_prop bid_price_bids_mean=bid_price_bids bid_price_negot_mean=bid_price_negot bid_price_pref_mean=bid_price_pref bid_price_realinh_mean=bid_price_realinh bid_price_n_a_mean=bid_price_n_a same_city_pbu_firm_n_a_mean=same_city_pbu_firm_n_a firm_state_sp_n_a_mean=firm_state_sp_n_a /// 
(median) dist_median=dist bid_price_median=bid_unit_price bid_price_acession_median=bid_price_acession bid_price_prop_median=bid_price_prop bid_price_bids_median=bid_price_bids bid_price_negot_median=bid_price_negot bid_price_pref_median=bid_price_pref bid_price_realinh_median=bid_price_realinh bid_price_n_a_median=bid_price_n_a same_city_pbu_firm_n_a_median=same_city_pbu_firm_n_a firm_state_sp_n_a_median=firm_state_sp_n_a /// 
(sd) dist_sd=dist bid_price_sd=bid_unit_price bid_price_acession_sd=bid_price_acession bid_price_prop_sd=bid_price_prop bid_price_bids_sd=bid_price_bids bid_price_negot_sd=bid_price_negot bid_price_pref_sd=bid_price_pref bid_price_realinh_sd=bid_price_realinh bid_price_n_a_sd=bid_price_n_a same_city_pbu_firm_n_a_sd=same_city_pbu_firm_n_a firm_state_sp_n_a_sd=firm_state_sp_n_a /// 
(semean) dist_semean=dist bid_price_semean=bid_unit_price bid_price_acession_semean=bid_price_acession bid_price_prop_semean=bid_price_prop bid_price_bids_semean=bid_price_bids bid_price_negot_semean=bid_price_negot bid_price_pref_semean=bid_price_pref bid_price_realinh_semean=bid_price_realinh bid_price_n_a_semean=bid_price_n_a same_city_pbu_firm_n_a_semean=same_city_pbu_firm_n_a firm_state_sp_n_a_semean=firm_state_sp_n_a, by(key_po_phase_code)

sort key_po_phase_code
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemPHASE_GROUP2_merge.dta", replace



restore 

tostring po_phase_code, replace
gen key_po_phase_code = po+item+po_phase_code
sort key_po_phase_code

merge m:1 key_po_phase_code using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemPHASE_GROUP2_merge.dta", generate(flag_Phase)


preserve

gen key_qty = po + item
keep key_qty bid_item_qty_perbid
duplicates drop
collapse (max) bid_qty_item=bid_item_qty_perbid, by(key_qty)

sort key_qty
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemQTY_GROUP2_merge.dta", replace

restore

gen key_qty = po + item
sort key_qty

merge m:1 key_qty using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemQTY_GROUP2_merge.dta", generate(flag_qty)


gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BEC_FINAL_GROUP2_LANCE_LANCE.dta", replace


drop diamêsencerramento firm_id firm_legal_nature firm_descr descriçãotipoempresa descriçãoenquadramento_caufesp ///
descriçãofornecedorstatus firm_city firm_state descriçãopaísfornecedor descriçãotipoendereçofornecedor firm_zipcode diamêsagendamento ///
firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code bid_status bid_status_group_code ///
po_phase_code pot_epp_me po_phase_code_str pbu_year pbu_power_code pbu_type_mgmt_code pbu_uf pbu_ibge_cod_uf ibge_cod_cidade_firm pbu_city_area /// 
pbu_zipcode pbu_latit_1 pbu_longit_1  nome latitude longitude capital codigo_uf _merge_firm_geoc_final pbu_latit pbu_longit bid_id bid_count ///
bid_time_date firm_latit_1 firm_longit_1 ibge_cod_uf_firm area_cidade_km2_firm _merge_cities dupl _merge_firm_geoc flag firm_latit firm_longit /// 
flag_items flag_groups flag_classes flag_firms key_epp flag_EPP flag_qty códdescmunicípiodeentrega códdescregiãodeentrega pbu_code_year ///
po_item_merge_key bid_rank po_item_id po_item_key unique_firm firm_zipcode_length firm_id_zipcode firm_type_key key_po_phase_code flag_Phase key_qty ///
bid_unit_price bid_winner bid_unit_price_negot bid_ref_price same_city_pbu_firm firm_state_sp ///
bid_price_acession bid_price_prop bid_price_bids bid_price_negot bid_price_pref bid_price_realinh ///
same_city_pbu_firm_acession same_city_pbu_firm_prop same_city_pbu_firm_bids same_city_pbu_firm_negot ///
same_city_pbu_firm_pref same_city_pbu_firm_realinh firm_state_sp_acession firm_state_sp_prop firm_state_sp_bids ///
firm_state_sp_negot firm_state_sp_pref firm_state_sp_realinh dist bid_item_qty_perbid n_firm_type1 n_firm_type2 n_firm_type3 ///
n_firm_type4 n_firm_type5 n_firm_type6 date    m_y     year bid_price_n_a same_city_pbu_firm_n_a firm_state_sp_n_a t



save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BEC_FINAL_GROUP2_PREPARING_COLLAPSE1.dta", replace



collapse (max) bid_price_acession_max1=bid_price_acession_max	bid_price_acession_mean1=bid_price_acession_mean ///
bid_price_acession_median1=bid_price_acession_median	bid_price_acession_min1=bid_price_acession_min	bid_price_acession_sd1=bid_price_acession_sd ///
bid_price_acession_semean1=bid_price_acession_semean	bid_price_bids_max1=bid_price_bids_max	bid_price_bids_mean1=bid_price_bids_mean ///
bid_price_bids_median1=bid_price_bids_median	bid_price_bids_min1=bid_price_bids_min	bid_price_bids_sd1=bid_price_bids_sd ///
bid_price_bids_semean1=bid_price_bids_semean	bid_price_max1=bid_price_max	bid_price_mean1=bid_price_mean	bid_price_median1=bid_price_median ///
bid_price_min1=bid_price_min	bid_price_negot_max1=bid_price_negot_max	bid_price_negot_mean1=bid_price_negot_mean ///
bid_price_negot_median1=bid_price_negot_median	bid_price_negot_min1=bid_price_negot_min	bid_price_negot_sd1=bid_price_negot_sd ///
bid_price_negot_semean1=bid_price_negot_semean	bid_price_pref_max1=bid_price_pref_max	bid_price_pref_mean1=bid_price_pref_mean ///
bid_price_pref_median1=bid_price_pref_median	bid_price_pref_min1=bid_price_pref_min	bid_price_pref_sd1=bid_price_pref_sd ///
bid_price_pref_semean1=bid_price_pref_semean	bid_price_prop_max1=bid_price_prop_max	bid_price_prop_mean1=bid_price_prop_mean ///
bid_price_prop_median1=bid_price_prop_median	bid_price_prop_min1=bid_price_prop_min	bid_price_prop_sd1=bid_price_prop_sd ///
bid_price_prop_semean1=bid_price_prop_semean	bid_price_realinh_max1=bid_price_realinh_max	bid_price_realinh_mean1=bid_price_realinh_mean ///
bid_price_realinh_median1=bid_price_realinh_median	bid_price_realinh_min1=bid_price_realinh_min	bid_price_realinh_sd1=bid_price_realinh_sd ///
bid_price_realinh_semean1=bid_price_realinh_semean	bid_price_sd1=bid_price_sd	bid_price_semean1=bid_price_semean	bid_qty_item1=bid_qty_item ///
bid_ref_price_max1=bid_ref_price_max	bid_ref_price_min1=bid_ref_price_min	bid_time_max1=bid_time_max	bid_time_min1=bid_time_min ///
bid_unit_price_negot_max1=bid_unit_price_negot_max	bid_unit_price_negot_min1=bid_unit_price_negot_min	dist_max1=dist_max	dist_mean1=dist_mean ///
dist_median1=dist_median	dist_min1=dist_min	dist_sd1=dist_sd	dist_semean1=dist_semean	firm_state_sp_acession_sum1=firm_state_sp_acession_sum ///
firm_state_sp_bids_sum1=firm_state_sp_bids_sum	firm_state_sp_negot_sum1=firm_state_sp_negot_sum	firm_state_sp_pref_sum1=firm_state_sp_pref_sum ///
firm_state_sp_prop_sum1=firm_state_sp_prop_sum	firm_state_sp_realinh_sum1=firm_state_sp_realinh_sum	firm_state_sp_sum1=firm_state_sp_sum ///
n_bids1=n_bids	n_classes_po1=n_classes_po	n_firms1=n_firms	n_groups_po1=n_groups_po	n_items_po1=n_items_po	po_winner_max1=po_winner_max ///
po_winner_sum1=po_winner_sum	proc_length_days1=proc_length_days	proc_length_hours1=proc_length_hours	proc_length_minutes1=proc_length_minutes ///
proc_length_seconds1=proc_length_seconds	same_city_pbu_firm_acession_sum1=same_city_pbu_firm_acession_sum ///
same_city_pbu_firm_bids_sum1=same_city_pbu_firm_bids_sum	same_city_pbu_firm_negot_sum1=same_city_pbu_firm_negot_sum	///
same_city_pbu_firm_pref_sum1=same_city_pbu_firm_pref_sum	same_city_pbu_firm_prop_sum1=same_city_pbu_firm_prop_sum ///
same_city_pbu_firm_realinh_sum1=same_city_pbu_firm_realinh_sum	same_city_pbu_firm_sum1=same_city_pbu_firm_sum	tot_firm_type11=tot_firm_type1 ///
tot_firm_type21=tot_firm_type2	tot_firm_type31=tot_firm_type3	tot_firm_type41=tot_firm_type4	tot_firm_type51=tot_firm_type5 ///
bid_price_n_a_sum1=bid_price_n_a_sum same_city_pbu_firm_n_a_sum1=same_city_pbu_firm_n_a_sum firm_state_sp_n_a_sum1=firm_state_sp_n_a_sum ///
bid_price_n_a_min1=bid_price_n_a_min same_city_pbu_firm_n_a_min1=same_city_pbu_firm_n_a_min firm_state_sp_n_a_min1=firm_state_sp_n_a_min ///
bid_price_n_a_max1=bid_price_n_a_max same_city_pbu_firm_n_a_max1=same_city_pbu_firm_n_a_max firm_state_sp_n_a_max1=firm_state_sp_n_a_max ///
bid_price_n_a_mean1=bid_price_n_a_mean same_city_pbu_firm_n_a_mean1=same_city_pbu_firm_n_a_mean firm_state_sp_n_a_mean1=firm_state_sp_n_a_mean ///
bid_price_n_a_median1=bid_price_n_a_median same_city_pbu_firm_n_a_median1=same_city_pbu_firm_n_a_median firm_state_sp_n_a_median1=firm_state_sp_n_a_median ///
bid_price_n_a_sd1=bid_price_n_a_sd same_city_pbu_firm_n_a_sd1=same_city_pbu_firm_n_a_sd firm_state_sp_n_a_sd1=firm_state_sp_n_a_sd ///
bid_price_n_a_semean1=bid_price_n_a_semean same_city_pbu_firm_n_a_semean1=same_city_pbu_firm_n_a_semean firm_state_sp_n_a_semean1=firm_state_sp_n_a_semean ///
tot_firm_type61=tot_firm_type6	tot_pot_epp_me1=tot_pot_epp_me, by(po	categ_item	class_item	class_item_descr	group_item	group_item_descr ///
item	item_descr	item_unit	pbu_code	po_status	po_status_code	proc	price_reg	green_item	item_type)


save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/Collapse_1_GROUP2_PRE.dta", replace

duplicates drop po item, force
gen key1_merge=po + item
sort key1_merge


save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/Collapse_1_GROUP2.dta", replace



merge 1:1 key1_merge using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2.dta", generate(flag_collapse)
drop if flag_collapse==2

  
save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BEC_COLLAPSE_GROUP2.dta", replace



clear all







***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************

* PART THREE


***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************
***********************************************************************************************************************************************************


*----------------------------------------------------------------------------------------------------------------------------------------------------------
* Program Setup
*----------------------------------------------------------------------------------------------------------------------------------------------------------
version 13              																				// Set Version number for backward compatibility
set more off            																				// Disable partitioned output
clear all               																				// Start with a clean slate
set linesize 80         																				// Line size limit to make output more readable
macro drop _all         																				// Clear all macros
capture log close       																				// Close existing log files
cd "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1" 			// Defining Main Directory 

* Final product: Collapse_1A.dta

* 1- Appending Files (Yearly)

/*
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_1.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante  quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_1.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_2.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_2.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_3.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_3.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_4.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_4.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_5.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_5.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_6.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_6.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_7.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_7.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_8.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_8.dta", replace
clear all
*/

/*
import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_9.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_9.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_10.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_10.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_11.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_11.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_12.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_12.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_13.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_13.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_14.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_14.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_15.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_15.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_16.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_16.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_17.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_17.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_18.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_18.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_19.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_19.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_20.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_20.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_21.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_21.dta", replace
clear all

import delimited "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/CSV/LANCES_22.csv", encoding(utf8) ///
stringcols(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 /// 
37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69)
ren v32 quantidadeitemnegociado
ren v48 descriçãoenquadramento_caufesp
drop  dataocagendamento dataoccriacao dataocencerramento finalidade  valormínimounitárioproposta valormáximounitárioproposta ///
quantidadeitemvencedor valortotalproposta quantidadeitemvencedor valortotalnegociado datacadastro propostavencedorprimeiro descriçãostatusfornecedorbec descriçãostatusfornecedor ///
quantidadedeoc quantidadefornecedorparticipante quantidadeitemnegociado quantidadeitemnegociado descriçãoendereçofornecedor descriçãobairrofornecedor 
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/LANCES_22.dta", replace
clear all
*/


use LANCES_22.dta, clear
append using LANCES_21.dta
append using LANCES_20.dta
append using LANCES_19.dta
append using LANCES_18.dta
append using LANCES_17.dta


/*
use LANCES_22.dta, clear
append using LANCES_21.dta
append using LANCES_20.dta
append using LANCES_19.dta
append using LANCES_18.dta
append using LANCES_17.dta
append using LANCES_16.dta
append using LANCES_15.dta
append using LANCES_14.dta
append using LANCES_13.dta
append using LANCES_12.dta
append using LANCES_11.dta
append using LANCES_10.dta
append using LANCES_9.dta
append using LANCES_8.dta
append using LANCES_7.dta
append using LANCES_6.dta
append using LANCES_5.dta
append using LANCES_4.dta
append using LANCES_3.dta
append using LANCES_2.dta
append using LANCES_1.dta
*/


gen str date1 = substr(mêsanoencerramento,1,7)
drop mêsanoencerramento

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP1/BEC_GROUP3.dta", replace



* 2- Preparing variables (Renaming variables in English)

ren date1 m_y
label variable m_y "Month and Year"

egen t = group(m_y)
label variable t "Month and Year from 1 to 120"

ren descriçãoprocedimentocompra descrproc
egen proc = group(descrproc)
label variable proc "1 = CONVITE; 2 = DISPENSA DE LICITAÇÃO; 3 = PREGÃO ELETRÔNICO"

ren numerodaoc po
label variable po "Purchase Order Number"

egen price_reg = group(ataregistrodepreço)
replace price_reg = price_reg - 1
label variable price_reg "Price Registration? 0 = No; 1 = Yes"

destring códigocategoria, replace
replace códigocategoria = 0 if códigocategoria == 2
ren códigocategoria categ_item
label variable categ_item "0 = Service; 1 = Good"

ren códigoclasse class_item
label variable class_item "Class of Item Code" 

ren códigogrupo group_item
label variable group_item "Group of Item Code"

ren códigoitem item
label variable item "Item Code"

ren descunidadefornecimento item_unit
label variable item_unit "Item unit"

gen green_item = 0
replace green_item = 1 if seloverde == "S"
label variable green_item "Green Item? 0 = No; 1 = Yes"

ren valorunitárioproposta bid_unit_price
label variable bid_unit_price "Bid unit price with no negotiation"

ren flagvencedor bid_winner
label variable bid_winner "Bid made by the winner firm? 0 = No; 1 = Yes (not necessarily the winner bid)"

ren datahrproposta bid_time
label variable bid_time "Day and time of the bid"

ren valorunitarionegociado bid_unit_price_negot
label variable bid_unit_price_negot "Bid unit price after negotiation"

ren valorunitárioreferência bid_ref_price
label variable bid_ref_price "Reference Price"

ren qtdeofertadecompraitemnegociado bid_item_qty_perbid
label variable bid_item_qty_perbid "Bid item quantity per bid"

ren códigofornecedor firm_id
label variable firm_id "CNPJ or CPF"

ren descriçãoenquadramento firm_type
label variable firm_type "Firm type: Cooperativa, Cooperativa Direito de Pref., EPP, Enquadramento não cadastrado no CAUFESP, ME, Outros"

ren descriçãofisicajurídica firm_person
label variable firm_person "Pessoa Física ou Jurídica"

ren descriçãomatrizfilial firm_headqtr_branch
label variable firm_headqtr_branch "Headquarter or Branch"

ren descriçãonaturezajurídica firm_legal_nature
label variable firm_legal_nature "Firm legal nature"	

ren descriçãosimplesnacional firm_simples
label variable firm_simples "Simples Nacional"

ren descriçãopropostastatus bid_status
label variable bid_status "Bid status specific level"

ren descriçãogrupopropostastatus bid_status_group
label variable bid_status_group "Bid status general level"

ren descriçãofasesoc po_phase
label variable po_phase "Purchase Order Phase"

ren códigounidadecompradora pbu_code
label variable pbu_code "Public Buyer Unit code in the BEC Catalog"

ren descriçãomunicípiofornecedor firm_city
label variable firm_city "Firm city"

ren descriçãouffornecedor firm_state
label variable firm_state "Firm state"

ren códigocepfornecedor firm_zipcode
label variable firm_zipcode "Firm zipcode"

ren códigomunicípiodeentrega pbu_city_delivery_code
label variable pbu_city_delivery_code "City code of delivery"

ren descriçãomunicípiodeentrega pbu_city_delivery
label variable pbu_city_delivery "City of delivery"

ren códigoregiãodeentrega pbu_region_delivery_code
label variable pbu_region_delivery_code "Region code of delivery"

ren descriçãoregiãodeentrega pbu_region_delivery
label variable pbu_region_delivery "Region of delivery"

ren descriçãoofertadecomprastatus po_status
label variable po_status "PO status"

ren códigoofertadecomprastatus po_status_code
label variable po_status_code "PO status code"

ren desccategoriaitem categ_item_descr
label variable categ_item_descr "Item category description"

ren descclasseitem class_item_descr
label variable class_item_descr "Item class description"

ren descgrupoitem group_item_descr
label variable group_item_descr "Item group description"

ren descitem item_descr
label variable item_descr "Item description"

ren descriçãorazãosocial firm_descr
label variable firm_descr "Firm Description"

gen date = m_y

destring date, replace
gen date1 = monthly(date, "MY")
format date1 %tm

split date, p("/") gen(substr)

drop substr1 m_y  ataregistrodepreço seloverde descriçãounidadecompradora descrproc
drop if po == ""

ren date1 m_y

ren substr2 year

gen pbu_code_year = pbu_code + year

label variable date "Date destring"

label variable m_y "Date in date format"

label variable year "Year"

label variable pbu_code_year "Key variable for UCs merge"

egen item_type = group(categ_item_descr)
label variable item_type "1=MATERIAL;2=SERVIÇO"
drop categ_item_descr

egen firm_type_code = group(firm_type)
label variable firm_type_code "1=COOPERATIVA;2=COOPERATIVA DIR PREF;3=EPP;4=NÃO CADAST CAUFESP;5=ME;6=OUTROS"
drop firm_type

egen firm_person_code = group(firm_person)
label variable firm_person_code "1=FISICA;2=JURIDICA;3=SEM CADASTRO"
drop firm_person

egen firm_headqtr_branch_code = group(firm_headqtr_branch)
label variable firm_headqtr_branch_code "1=FILIAL;2=MATRIZ;3=N/C;4=SEM CADASTRO"
drop firm_headqtr_branch

egen  firm_legal_nature_code = group(firm_legal_nature)
label variable firm_legal_nature_code "Type of Firm"


egen firm_simples_code = group(firm_simples)
label variable firm_simples_code "1=N/A;2=NÃO;3=SIM"
drop firm_simples

egen bid_status_code = group(bid_status)
drop bid_status
gen bid_status = bid_status_code
replace bid_status = 0 if bid_status_code >= 2 & bid_status_code <= 15
replace bid_status = 1 if bid_status_code==1 | bid_status_code==16 | bid_status_code==17
drop bid_status_code
label variable bid_status "0=INVALIDO;1=VALIDO"

egen bid_status_group_code = group(bid_status_group)
label variable bid_status_group_code "1=CLASSIF;2=DESCLASSIF;3=INVÁLIDO;4=N/A;5=VÁLIDO"
drop bid_status_group

egen po_phase_code = group(po_phase)
label variable po_phase_code "1=AD MELH OFERTA;2=PROPS;3=LANCES;4=NEGOC;5=N/A;6=ME-EPP;7=REALINH PREÇO COOPERAT"
drop po_phase

drop razãosocial

destring bid_unit_price bid_unit_price_negot bid_ref_price bid_item_qty_perbid, replace dpcomma

sort pbu_code_year

gen pot_epp_me = 0
replace pot_epp_me=1 if firm_legal_nature=="ASSOCIAÇÃO PRIVADA" | firm_legal_nature=="COOPERATIVA" | firm_legal_nature=="EMP. INDIV. RESPONS. LIMITADA-EIRELI (EMPRESÁRIA)" | firm_legal_nature=="EMP. INDIV. RESPONS. LIMITADA-EIRELI (SIMPLES)" | ///
firm_legal_nature=="EMPRESÁRIO (INDIVIDUAL)" | firm_legal_nature=="EMPRESÁRIO (INDIVIDUAL) - MEI" | firm_legal_nature=="SOCIEDADE CIVIL" | firm_legal_nature=="SOCIEDADE EMPRESÁRIA LIMITADA" | firm_legal_nature=="SOCIEDADE SIMPLES" | ///
firm_legal_nature=="SOCIEDADE SIMPLES LIMITADA" | firm_legal_nature=="SOCIEDADE SIMPLES PURA"

// drop if po_phase_code == 5
// replace po_phase_code = 5 if po_phase_code == 6
// replace po_phase_code = 6 if po_phase_code == 7
// label variable po_phase_code "1=AD MELH OFERTA;2=PROPS;3=LANCES;4=NEGOC;5=ME-EPP;6=REALINH PREÇO COOPERAT"


gen po_phase_code_str=po_phase_code
tostring po_phase_code_str, replace
gen po_item_merge_key = po + item + po_phase_code_str + item_unit
bysort po_item_merge_key (bid_unit_price): gen bid_rank = sum(bid_unit_price != bid_unit_price[_n-1])

gen bid_price_acession = bid_unit_price if po_phase_code == 1
gen bid_price_prop = bid_unit_price if po_phase_code == 2
gen bid_price_bids = bid_unit_price if po_phase_code == 3
gen bid_price_negot = bid_unit_price if po_phase_code == 4
gen bid_price_n_a = bid_unit_price if po_phase_code == 5
gen bid_price_pref = bid_unit_price if po_phase_code == 6
gen bid_price_realinh = bid_unit_price if po_phase_code == 7


// drop if bid_status==0




* 3- Geocoding UCs (Original Latit/Longit if available; otherwise, city latit/longit) 


merge m:1 pbu_code_year using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/UC/UCs_info_MERGE_cities.dta", gen(flag)
drop if po == ""



* 4- Working in full file (Creating extra variables)

gen bid_id = _n
label variable bid_id "Bid ID (Primary Key)"
																	
gen same_city_pbu_firm = 0
replace same_city_pbu_firm = 1 if firm_city == pbu_city_descr
label variable same_city_pbu_firm "Pbu and Firm in the same city? 0 = No; 1 = Yes"

gen firm_state_sp = 0
replace firm_state_sp = 1 if firm_state == "SÃO PAULO"
label variable firm_state_sp "Firm in São Paulo State? 0 = No; 1 = Yes"


destring po_phase_code, replace

gen same_city_pbu_firm_acession=same_city_pbu_firm if po_phase_code==1
gen same_city_pbu_firm_prop=same_city_pbu_firm if po_phase_code==2
gen same_city_pbu_firm_bids=same_city_pbu_firm if po_phase_code==3
gen same_city_pbu_firm_negot=same_city_pbu_firm if po_phase_code==4
gen same_city_pbu_firm_n_a=same_city_pbu_firm if po_phase_code==5
gen same_city_pbu_firm_pref=same_city_pbu_firm if po_phase_code==6
gen same_city_pbu_firm_realinh=same_city_pbu_firm if po_phase_code==7

gen firm_state_sp_acession=firm_state_sp if po_phase_code==1
gen firm_state_sp_prop=firm_state_sp if po_phase_code==2
gen firm_state_sp_bids=firm_state_sp if po_phase_code==3
gen firm_state_sp_negot=firm_state_sp if po_phase_code==4
gen firm_state_sp_n_a=firm_state_sp if po_phase_code==5
gen firm_state_sp_pref=firm_state_sp if po_phase_code==6
gen firm_state_sp_realinh=firm_state_sp if po_phase_code==7

tostring item, replace
tostring po_phase_code, replace

gen po_item_id = po + item + po_phase_code
gen po_item_key = po + item
gen bid_count = 1

gen double bid_time_date = clock(bid_time, "YMDhms")
format bid_time_date %tc
drop bid_time


sort m_y po_item_id bid_time

by po_item_id firm_id, sort: gen nvals = _n == 1

rename nvals unique_firm

drop pbu_city_delivery_code pbu_city_delivery pbu_region_delivery_code pbu_region_delivery pubag_code pubag_descr pubbudget_code pubbudget_descr pbu_descr ///
pbu_fedentity_code pbu_fedentity_descr pbu_region_code pbu_region_descr pbu_city_code pbu_city_descr pbu_cnpj pbu_power pbu_type_mgmt_descr

drop flag 



/*
replace bid_unit_price = . if bid_unit_price == 0
replace bid_unit_price_negot = . if bid_unit_price_negot == 0
replace bid_ref_price = . if bid_ref_price == 0
replace bid_item_qty_perbid = . if bid_item_qty_perbid == 0
*/



* 5- Saving Baseline and Separating Firm info (Preparing for geocoding firms)

gen firm_zipcode_length=length(firm_zipcode)
tab firm_zipcode_length
replace firm_zipcode = "0" + firm_zipcode if firm_zipcode_length==7
gen firm_id_zipcode = firm_id + firm_zipcode
sort firm_id_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP2/BEC_GROUP3_merge.dta", replace

keep  firm_city firm_descr firm_headqtr_branch_code firm_id firm_legal_nature_code firm_person_code firm_simples_code firm_state ///
firm_state_sp firm_type_code firm_zipcode firm_id_zipcode
sort firm_id_zipcode
duplicates drop firm_id_zipcode, force
sort firm_zipcode
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP3/Firm_info_GROUP3.dta", replace


* 6- Geocoding Firms (Creating source file and geocoding firms)

* Excluir esta parte

clear all
use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP3/Firm_info_GROUP3.dta", clear


merge m:1 firm_zipcode using "/home/darciogm1/projetos/bitter-pills/data/geocoding/geocoded-datasets/Geocoding_firm_zipcode_cities.dta"
ren _merge _merge_firm_geoc
drop if _merge_firm_geoc==1
drop if _merge_firm_geoc==2
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP4/Firm_info_GROUP3_merge.dta", replace
clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP2/BEC_GROUP3_merge.dta", clear
sort firm_id_zipcode
merge m:1 firm_id_zipcode using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP4/Firm_info_GROUP3_merge.dta", generate(flag)
ren _merge _merge_firm_geoc_final
drop if po == ""
drop  id_firm uf_firm city_firm address_firm ddd_firm
ren latit_firm firm_latit_1
ren longit_firm firm_longit_1

gen firm_latit=firm_latit_1
replace firm_latit=latitude if firm_latit_1==.

gen firm_longit=firm_longit_1
replace firm_longit=longitude if firm_longit_1==.

drop if firm_latit==.


geodist pbu_latit pbu_longit firm_latit firm_longit , generate(dist)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP5/BEC_GROUP3_merge_DIST.dta", replace



* 7- By PO (#different items, #different groups, #different classes)



preserve

gen item_count=1
keep po item item_count
duplicates drop
collapse (count) n_items_po=item_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOitems_GROUP3_merge.dta", replace

restore 


preserve

gen group_count=1
keep po group_item group_count
duplicates drop
collapse (count) n_groups_po=group_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOgroups_GROUP3_merge.dta", replace

restore 


preserve

gen class_count=1
keep po class_item class_count
duplicates drop
collapse (count) n_classes_po=class_count, /// 
by(po)
sort po
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOclasses_GROUP3_merge.dta", replace

restore 

sort po
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOitems_GROUP3_merge.dta", generate(flag_items)
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOgroups_GROUP3_merge.dta", generate(flag_groups)
merge m:1 po using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BYPOclasses_GROUP3_merge.dta", generate(flag_classes)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP7/BEC_GROUP3_merge_BYPO.dta", replace



* 8- By OC + ITEM + Firm CNPJ: Info about each po + item





tabulate firm_type_code, generate (n_firm_type)


***************
/*
gen n_firm_type6=n_firm_type5
replace n_firm_type5=n_firm_type4
replace n_firm_type4=n_firm_type3
replace n_firm_type3=n_firm_type2
replace n_firm_type2=0
*/

*****************

label variable n_firm_type1 "COOPERATIVA"

label variable n_firm_type2 "COOPERATIVA ATIVA DIR PREF"

label variable n_firm_type3 "EPP"

label variable n_firm_type4 "NÃO CADASTRADO CAUFESP"

label variable n_firm_type5 "ME"

label variable n_firm_type6 "OUTROS"

gen firm_type_key = po + item
sort firm_type_key firm_id


preserve


keep firm_type_key firm_id n_firm_type1 n_firm_type2 n_firm_type3 n_firm_type4 n_firm_type5 n_firm_type6
sort firm_type_key
duplicates drop
collapse (sum) tot_firm_type1=n_firm_type1 tot_firm_type2=n_firm_type2 tot_firm_type3=n_firm_type3 tot_firm_type4=n_firm_type4 tot_firm_type5=n_firm_type5 tot_firm_type6=n_firm_type6 , /// 
by(firm_type_key)
sort firm_type_key
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOITEM_firm_type_GROUP3_merge.dta", replace

restore 

sort firm_type_key
merge m:1 firm_type_key using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOITEM_firm_type_GROUP3_merge.dta", generate(flag_firms)



* 9- By OC + ITEM + PO_PHASE : Info about each po + item + po_phase



preserve


keep po item firm_id pot_epp_me
duplicates drop
collapse (count) tot_pot_epp_me=pot_epp_me, /// 
by(po item)
gen key_epp = po + item
sort key_epp
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemEPP_GROUP3_merge.dta", replace

restore 

gen key_epp = po + item
sort key_epp
merge m:1 key_epp using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemEPP_GROUP3_merge.dta", generate(flag_EPP)


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/Before_collapse_GROUP3.dta", replace



destring po_phase_code, replace

tostring item, replace
tostring po_phase_code, replace

preserve

/*
drop if bid_status==0
*/
gen key_po_phase_code = po+item+po_phase_code
destring bid_winner, replace

keep po item po_phase_code unique_firm bid_count bid_winner dist bid_unit_price bid_time_date bid_unit_price_negot /// 
bid_ref_price bid_price_acession bid_price_prop bid_price_bids bid_price_negot bid_price_pref ///
bid_price_realinh key_po_phase_code same_city_pbu_firm firm_state_sp same_city_pbu_firm_acession ///
same_city_pbu_firm_prop same_city_pbu_firm_bids same_city_pbu_firm_negot same_city_pbu_firm_pref ///
same_city_pbu_firm_realinh firm_state_sp_acession firm_state_sp_prop firm_state_sp_bids firm_state_sp_negot ///
firm_state_sp_pref firm_state_sp_realinh bid_price_n_a same_city_pbu_firm_n_a firm_state_sp_n_a

duplicates drop
collapse (sum) n_firms=unique_firm n_bids=bid_count po_winner_sum=bid_winner same_city_pbu_firm_sum=same_city_pbu_firm firm_state_sp_sum=firm_state_sp same_city_pbu_firm_acession_sum=same_city_pbu_firm_acession same_city_pbu_firm_prop_sum=same_city_pbu_firm_prop 	same_city_pbu_firm_bids_sum=same_city_pbu_firm_bids ///
same_city_pbu_firm_negot_sum=same_city_pbu_firm_negot  	same_city_pbu_firm_pref_sum=same_city_pbu_firm_pref 	same_city_pbu_firm_realinh_sum=same_city_pbu_firm_realinh 	 firm_state_sp_acession_sum= firm_state_sp_acession 	 firm_state_sp_prop_sum= firm_state_sp_prop 	 firm_state_sp_bids_sum= firm_state_sp_bids ///
firm_state_sp_negot_sum= firm_state_sp_negot 	 firm_state_sp_pref_sum= firm_state_sp_pref 	 firm_state_sp_realinh_sum= firm_state_sp_realinh bid_price_n_a_sum=bid_price_n_a same_city_pbu_firm_n_a_sum=same_city_pbu_firm_n_a firm_state_sp_n_a_sum=firm_state_sp_n_a /// 
(min) dist_min=dist bid_price_min=bid_unit_price bid_time_min=bid_time_date bid_unit_price_negot_min=bid_unit_price_negot bid_ref_price_min=bid_ref_price bid_price_acession_min=bid_price_acession bid_price_prop_min=bid_price_prop bid_price_bids_min=bid_price_bids bid_price_negot_min=bid_price_negot bid_price_pref_min=bid_price_pref bid_price_realinh_min=bid_price_realinh bid_price_n_a_min=bid_price_n_a same_city_pbu_firm_n_a_min=same_city_pbu_firm_n_a firm_state_sp_n_a_min=firm_state_sp_n_a /// 
(max) dist_max=dist bid_price_max=bid_unit_price po_winner_max=bid_winner bid_time_max=bid_time_date bid_unit_price_negot_max=bid_unit_price_negot bid_ref_price_max=bid_ref_price bid_price_acession_max=bid_price_acession bid_price_prop_max=bid_price_prop bid_price_bids_max=bid_price_bids bid_price_negot_max=bid_price_negot bid_price_pref_max=bid_price_pref bid_price_realinh_max=bid_price_realinh bid_price_n_a_max=bid_price_n_a same_city_pbu_firm_n_a_max=same_city_pbu_firm_n_a firm_state_sp_n_a_max=firm_state_sp_n_a /// 
(mean) dist_mean=dist bid_price_mean=bid_unit_price bid_price_acession_mean=bid_price_acession bid_price_prop_mean=bid_price_prop bid_price_bids_mean=bid_price_bids bid_price_negot_mean=bid_price_negot bid_price_pref_mean=bid_price_pref bid_price_realinh_mean=bid_price_realinh bid_price_n_a_mean=bid_price_n_a same_city_pbu_firm_n_a_mean=same_city_pbu_firm_n_a firm_state_sp_n_a_mean=firm_state_sp_n_a /// 
(median) dist_median=dist bid_price_median=bid_unit_price bid_price_acession_median=bid_price_acession bid_price_prop_median=bid_price_prop bid_price_bids_median=bid_price_bids bid_price_negot_median=bid_price_negot bid_price_pref_median=bid_price_pref bid_price_realinh_median=bid_price_realinh bid_price_n_a_median=bid_price_n_a same_city_pbu_firm_n_a_median=same_city_pbu_firm_n_a firm_state_sp_n_a_median=firm_state_sp_n_a /// 
(sd) dist_sd=dist bid_price_sd=bid_unit_price bid_price_acession_sd=bid_price_acession bid_price_prop_sd=bid_price_prop bid_price_bids_sd=bid_price_bids bid_price_negot_sd=bid_price_negot bid_price_pref_sd=bid_price_pref bid_price_realinh_sd=bid_price_realinh bid_price_n_a_sd=bid_price_n_a same_city_pbu_firm_n_a_sd=same_city_pbu_firm_n_a firm_state_sp_n_a_sd=firm_state_sp_n_a /// 
(semean) dist_semean=dist bid_price_semean=bid_unit_price bid_price_acession_semean=bid_price_acession bid_price_prop_semean=bid_price_prop bid_price_bids_semean=bid_price_bids bid_price_negot_semean=bid_price_negot bid_price_pref_semean=bid_price_pref bid_price_realinh_semean=bid_price_realinh bid_price_n_a_semean=bid_price_n_a same_city_pbu_firm_n_a_semean=same_city_pbu_firm_n_a firm_state_sp_n_a_semean=firm_state_sp_n_a, by(key_po_phase_code)

sort key_po_phase_code
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemPHASE_GROUP3_merge.dta", replace



restore 

tostring po_phase_code, replace
gen key_po_phase_code = po+item+po_phase_code
sort key_po_phase_code

merge m:1 key_po_phase_code using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemPHASE_GROUP3_merge.dta", generate(flag_Phase)


preserve

gen key_qty = po + item
keep key_qty bid_item_qty_perbid
duplicates drop
collapse (max) bid_qty_item=bid_item_qty_perbid, by(key_qty)

sort key_qty
save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemQTY_GROUP3_merge.dta", replace

restore

gen key_qty = po + item
sort key_qty

merge m:1 key_qty using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BYPOitemQTY_GROUP3_merge.dta", generate(flag_qty)


gen proc_length_seconds = (bid_time_max - bid_time_min)/1000
gen proc_length_minutes = (bid_time_max - bid_time_min)/60000
gen proc_length_hours = (bid_time_max - bid_time_min)/3600000
gen proc_length_days = (bid_time_max - bid_time_min)/(3600000*24)

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BEC_FINAL_GROUP3_LANCE_LANCE.dta", replace


drop diamêsencerramento firm_id firm_legal_nature firm_descr descriçãotipoempresa descriçãoenquadramento_caufesp ///
descriçãofornecedorstatus firm_city firm_state descriçãopaísfornecedor descriçãotipoendereçofornecedor firm_zipcode diamêsagendamento ///
firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code bid_status bid_status_group_code ///
po_phase_code pot_epp_me po_phase_code_str pbu_year pbu_power_code pbu_type_mgmt_code pbu_uf pbu_ibge_cod_uf ibge_cod_cidade_firm pbu_city_area /// 
pbu_zipcode pbu_latit_1 pbu_longit_1  nome latitude longitude capital codigo_uf _merge_firm_geoc_final pbu_latit pbu_longit bid_id bid_count ///
bid_time_date firm_latit_1 firm_longit_1 ibge_cod_uf_firm area_cidade_km2_firm _merge_cities dupl _merge_firm_geoc flag firm_latit firm_longit /// 
flag_items flag_groups flag_classes flag_firms key_epp flag_EPP flag_qty códdescmunicípiodeentrega códdescregiãodeentrega pbu_code_year ///
po_item_merge_key bid_rank po_item_id po_item_key unique_firm firm_zipcode_length firm_id_zipcode firm_type_key key_po_phase_code flag_Phase key_qty ///
bid_unit_price bid_winner bid_unit_price_negot bid_ref_price same_city_pbu_firm firm_state_sp ///
bid_price_acession bid_price_prop bid_price_bids bid_price_negot bid_price_pref bid_price_realinh ///
same_city_pbu_firm_acession same_city_pbu_firm_prop same_city_pbu_firm_bids same_city_pbu_firm_negot ///
same_city_pbu_firm_pref same_city_pbu_firm_realinh firm_state_sp_acession firm_state_sp_prop firm_state_sp_bids ///
firm_state_sp_negot firm_state_sp_pref firm_state_sp_realinh dist bid_item_qty_perbid n_firm_type1 n_firm_type2 n_firm_type3 ///
n_firm_type4 n_firm_type5 n_firm_type6 date    m_y     year bid_price_n_a same_city_pbu_firm_n_a firm_state_sp_n_a t



save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/STEP6/BEC_FINAL_GROUP3_PREPARING_COLLAPSE1.dta", replace



collapse (max) bid_price_acession_max1=bid_price_acession_max	bid_price_acession_mean1=bid_price_acession_mean ///
bid_price_acession_median1=bid_price_acession_median	bid_price_acession_min1=bid_price_acession_min	bid_price_acession_sd1=bid_price_acession_sd ///
bid_price_acession_semean1=bid_price_acession_semean	bid_price_bids_max1=bid_price_bids_max	bid_price_bids_mean1=bid_price_bids_mean ///
bid_price_bids_median1=bid_price_bids_median	bid_price_bids_min1=bid_price_bids_min	bid_price_bids_sd1=bid_price_bids_sd ///
bid_price_bids_semean1=bid_price_bids_semean	bid_price_max1=bid_price_max	bid_price_mean1=bid_price_mean	bid_price_median1=bid_price_median ///
bid_price_min1=bid_price_min	bid_price_negot_max1=bid_price_negot_max	bid_price_negot_mean1=bid_price_negot_mean ///
bid_price_negot_median1=bid_price_negot_median	bid_price_negot_min1=bid_price_negot_min	bid_price_negot_sd1=bid_price_negot_sd ///
bid_price_negot_semean1=bid_price_negot_semean	bid_price_pref_max1=bid_price_pref_max	bid_price_pref_mean1=bid_price_pref_mean ///
bid_price_pref_median1=bid_price_pref_median	bid_price_pref_min1=bid_price_pref_min	bid_price_pref_sd1=bid_price_pref_sd ///
bid_price_pref_semean1=bid_price_pref_semean	bid_price_prop_max1=bid_price_prop_max	bid_price_prop_mean1=bid_price_prop_mean ///
bid_price_prop_median1=bid_price_prop_median	bid_price_prop_min1=bid_price_prop_min	bid_price_prop_sd1=bid_price_prop_sd ///
bid_price_prop_semean1=bid_price_prop_semean	bid_price_realinh_max1=bid_price_realinh_max	bid_price_realinh_mean1=bid_price_realinh_mean ///
bid_price_realinh_median1=bid_price_realinh_median	bid_price_realinh_min1=bid_price_realinh_min	bid_price_realinh_sd1=bid_price_realinh_sd ///
bid_price_realinh_semean1=bid_price_realinh_semean	bid_price_sd1=bid_price_sd	bid_price_semean1=bid_price_semean	bid_qty_item1=bid_qty_item ///
bid_ref_price_max1=bid_ref_price_max	bid_ref_price_min1=bid_ref_price_min	bid_time_max1=bid_time_max	bid_time_min1=bid_time_min ///
bid_unit_price_negot_max1=bid_unit_price_negot_max	bid_unit_price_negot_min1=bid_unit_price_negot_min	dist_max1=dist_max	dist_mean1=dist_mean ///
dist_median1=dist_median	dist_min1=dist_min	dist_sd1=dist_sd	dist_semean1=dist_semean	firm_state_sp_acession_sum1=firm_state_sp_acession_sum ///
firm_state_sp_bids_sum1=firm_state_sp_bids_sum	firm_state_sp_negot_sum1=firm_state_sp_negot_sum	firm_state_sp_pref_sum1=firm_state_sp_pref_sum ///
firm_state_sp_prop_sum1=firm_state_sp_prop_sum	firm_state_sp_realinh_sum1=firm_state_sp_realinh_sum	firm_state_sp_sum1=firm_state_sp_sum ///
n_bids1=n_bids	n_classes_po1=n_classes_po	n_firms1=n_firms	n_groups_po1=n_groups_po	n_items_po1=n_items_po	po_winner_max1=po_winner_max ///
po_winner_sum1=po_winner_sum	proc_length_days1=proc_length_days	proc_length_hours1=proc_length_hours	proc_length_minutes1=proc_length_minutes ///
proc_length_seconds1=proc_length_seconds	same_city_pbu_firm_acession_sum1=same_city_pbu_firm_acession_sum ///
same_city_pbu_firm_bids_sum1=same_city_pbu_firm_bids_sum	same_city_pbu_firm_negot_sum1=same_city_pbu_firm_negot_sum	///
same_city_pbu_firm_pref_sum1=same_city_pbu_firm_pref_sum	same_city_pbu_firm_prop_sum1=same_city_pbu_firm_prop_sum ///
same_city_pbu_firm_realinh_sum1=same_city_pbu_firm_realinh_sum	same_city_pbu_firm_sum1=same_city_pbu_firm_sum	tot_firm_type11=tot_firm_type1 ///
tot_firm_type21=tot_firm_type2	tot_firm_type31=tot_firm_type3	tot_firm_type41=tot_firm_type4	tot_firm_type51=tot_firm_type5 ///
bid_price_n_a_sum1=bid_price_n_a_sum same_city_pbu_firm_n_a_sum1=same_city_pbu_firm_n_a_sum firm_state_sp_n_a_sum1=firm_state_sp_n_a_sum ///
bid_price_n_a_min1=bid_price_n_a_min same_city_pbu_firm_n_a_min1=same_city_pbu_firm_n_a_min firm_state_sp_n_a_min1=firm_state_sp_n_a_min ///
bid_price_n_a_max1=bid_price_n_a_max same_city_pbu_firm_n_a_max1=same_city_pbu_firm_n_a_max firm_state_sp_n_a_max1=firm_state_sp_n_a_max ///
bid_price_n_a_mean1=bid_price_n_a_mean same_city_pbu_firm_n_a_mean1=same_city_pbu_firm_n_a_mean firm_state_sp_n_a_mean1=firm_state_sp_n_a_mean ///
bid_price_n_a_median1=bid_price_n_a_median same_city_pbu_firm_n_a_median1=same_city_pbu_firm_n_a_median firm_state_sp_n_a_median1=firm_state_sp_n_a_median ///
bid_price_n_a_sd1=bid_price_n_a_sd same_city_pbu_firm_n_a_sd1=same_city_pbu_firm_n_a_sd firm_state_sp_n_a_sd1=firm_state_sp_n_a_sd ///
bid_price_n_a_semean1=bid_price_n_a_semean same_city_pbu_firm_n_a_semean1=same_city_pbu_firm_n_a_semean firm_state_sp_n_a_semean1=firm_state_sp_n_a_semean ///
tot_firm_type61=tot_firm_type6	tot_pot_epp_me1=tot_pot_epp_me, by(po	categ_item	class_item	class_item_descr	group_item	group_item_descr ///
item	item_descr	item_unit	pbu_code	po_status	po_status_code	proc	price_reg	green_item	item_type)


save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/Collapse_1_GROUP3_PRE.dta", replace

duplicates drop po item, force
gen key1_merge=po + item
sort key1_merge


save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/Collapse_1_GROUP3.dta", replace



**********************************************************************************************************************************************************

* MERGING COLLAPSE 1 (BID BY BID) WITH COLLAPSE 2 (ITEMS LEVEL)

**********************************************************************************************************************************************************

merge 1:1 key1_merge using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/Collapse_2.dta", generate(flag_collapse)
drop if flag_collapse==2

  
save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BEC_COLLAPSE_GROUP3.dta", replace



**********************************************************************************************************************************************************

* APPENDING FILES (ITEMS LEVEL)

**********************************************************************************************************************************************************

append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BEC_COLLAPSE_GROUP2.dta"

append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/BEC_COLLAPSE_GROUP1.dta"


gen date1 = monthly(mêsanoencerramento , "MY")
format date1 %tm
sort date1

drop if date1==.

ren date1 date

/*
gen testegrupo=0
replace testegrupo=1 if códigogrupo== group_item

gen testegrupodescr=0
replace testegrupodescr=1 if descgrupoitem== group_item_descr 

gen testeclasse=0
replace testeclasse=1 if  códigoclasse==class_item

gen testeclassedescr=0
replace testeclassedescr=1 if descclasseitem==class_item_descr

gen testeitem=0
replace testeitem=1 if códigoitem== item

gen testeitemdescr=0
replace testeitemdescr=1 if descitem==item_descr
*/

gen teste=0
replace teste=1 if po_status== descriçãoofertadecomprastatus
sort teste
replace po_status=descriçãoofertadecomprastatus if teste==0

drop key1_merge mêsanoencerramento numerodaoc  descriçãoofertadecomprastatus códigogrupo descgrupoitem códigoclasse descclasseitem códigoitem descitem ///
qtdeofertadecompraitem teste flag_collapse

ren  descunidadefornecimento  item_unit2

ren finalidade subject

ren descriçãoprocedimentocompra proc_descr

ren códigoórgão orgao_cod 

ren descriçãoórgão orgao_descr

ren códigouo uo_cod

ren descriçãouo uo_descr

ren códigounidadecompradora uc_cod

ren descriçãounidadecompradora uc_descr 

ren númerosequênciaitem  item_seq

ren códigofornecedor fornec_code 

ren participaçãoexclusivameeppcooper excl_part

destring valorunitáriodereferência, generate(bid_price_ref) dpcomma

destring valorunitárionegociado, generate(bid_price_winner) dpcomma

drop  valorunitáriodereferência valorunitárionegociado

sort date po item

gen ref_winprice_perc= bid_price_winner/ bid_price_ref

gen po_success=1
replace po_success=0 if fornec_code=="Sem Vencedor"

gen prop=1
replace prop=0 if bid_price_prop_min1==.

gen bids=1
replace bids=0 if bid_price_bids_min1==.

gen pref=1
replace pref=0 if bid_price_pref_min1==.

gen negot=1
replace negot=0 if bid_price_negot_min1==.

gen realinh=1
replace realinh=0 if bid_price_realinh_min1==.

gen acession=1
replace acession=0 if bid_price_acession_min1==.

gen n_a_phase=1
replace n_a_phase=0 if bid_price_n_a_min1==.

ren bid_price_acession_max1 bid_price_acession_max
ren bid_price_acession_mean1 bid_price_acession_mean
ren bid_price_acession_median1 bid_price_acession_median
ren bid_price_acession_min1 bid_price_acession_min
ren bid_price_acession_sd1 bid_price_acession_sd
ren bid_price_acession_semean1 bid_price_acession_semean
ren bid_price_bids_max1 bid_price_bids_max
ren bid_price_bids_mean1 bid_price_bids_mean
ren bid_price_bids_median1 bid_price_bids_median
ren bid_price_bids_min1 bid_price_bids_min
ren bid_price_bids_sd1 bid_price_bids_sd
ren bid_price_bids_semean1 bid_price_bids_semean
ren bid_price_max1 bid_price_max
ren bid_price_mean1 bid_price_mean
ren bid_price_median1 bid_price_median
ren bid_price_min1 bid_price_min
ren bid_price_negot_max1 bid_price_negot_max
ren bid_price_negot_mean1 bid_price_negot_mean
ren bid_price_negot_median1 bid_price_negot_median
ren bid_price_negot_min1 bid_price_negot_min
ren bid_price_negot_sd1 bid_price_negot_sd
ren bid_price_negot_semean1 bid_price_negot_semean
ren bid_price_pref_max1 bid_price_pref_max
ren bid_price_pref_mean1 bid_price_pref_mean
ren bid_price_pref_median1 bid_price_pref_median
ren bid_price_pref_min1 bid_price_pref_min
ren bid_price_pref_sd1 bid_price_pref_sd
ren bid_price_pref_semean1 bid_price_pref_semean
ren bid_price_prop_max1 bid_price_prop_max
ren bid_price_prop_mean1 bid_price_prop_mean
ren bid_price_prop_median1 bid_price_prop_median
ren bid_price_prop_min1 bid_price_prop_min
ren bid_price_prop_sd1 bid_price_prop_sd
ren bid_price_prop_semean1 bid_price_prop_semean
ren bid_price_realinh_max1 bid_price_realinh_max
ren bid_price_realinh_mean1 bid_price_realinh_mean
ren bid_price_realinh_median1 bid_price_realinh_median
ren bid_price_realinh_min1 bid_price_realinh_min
ren bid_price_realinh_sd1 bid_price_realinh_sd
ren bid_price_realinh_semean1 bid_price_realinh_semean
ren bid_price_sd1 bid_price_sd
ren bid_price_semean1 bid_price_semean
ren bid_qty_item1 bid_qty_item
ren bid_ref_price_max1 bid_ref_price_max
ren bid_ref_price_min1 bid_ref_price_min
ren bid_time_max1 bid_time_max
ren bid_time_min1 bid_time_min
ren bid_unit_price_negot_max1 bid_unit_price_negot_max
ren bid_unit_price_negot_min1 bid_unit_price_negot_min
ren dist_max1 dist_max
ren dist_mean1 dist_mean
ren dist_median1 dist_median
ren dist_min1 dist_min
ren dist_sd1 dist_sd
ren dist_semean1 dist_semean
ren firm_state_sp_acession_sum1 firm_state_sp_acession_sum
ren firm_state_sp_bids_sum1 firm_state_sp_bids_sum
ren firm_state_sp_negot_sum1 firm_state_sp_negot_sum
ren firm_state_sp_pref_sum1 firm_state_sp_pref_sum
ren firm_state_sp_prop_sum1 firm_state_sp_prop_sum
ren firm_state_sp_realinh_sum1 firm_state_sp_realinh_sum
ren firm_state_sp_sum1 firm_state_sp_sum
ren n_bids1 n_bids
ren n_classes_po1 n_classes_po
ren n_firms1 n_firms
ren n_groups_po1 n_groups_po
ren n_items_po1 n_items_po
ren po_winner_max1 po_winner_max
ren po_winner_sum1 po_winner_sum
ren proc_length_days1 proc_length_days
ren proc_length_hours1 proc_length_hours
ren proc_length_minutes1 proc_length_minutes
ren proc_length_seconds1 proc_length_seconds
ren same_city_pbu_firm_acession_sum1 same_city_pbu_firm_acession_sum
ren same_city_pbu_firm_bids_sum1 same_city_pbu_firm_bids_sum
ren same_city_pbu_firm_negot_sum1 same_city_pbu_firm_negot_sum
ren same_city_pbu_firm_pref_sum1 same_city_pbu_firm_pref_sum
ren same_city_pbu_firm_prop_sum1 same_city_pbu_firm_prop_sum
ren same_city_pbu_firm_realinh_sum1 same_city_pbu_firm_realinh_sum
ren same_city_pbu_firm_sum1 same_city_pbu_firm_sum
ren tot_firm_type11 tot_firm_type1
ren tot_firm_type21 tot_firm_type2
ren tot_firm_type31 tot_firm_type3
ren tot_firm_type41 tot_firm_type4
ren tot_firm_type51 tot_firm_type5
ren bid_price_n_a_sum1 bid_price_n_a_sum
ren same_city_pbu_firm_n_a_sum1 same_city_pbu_firm_n_a_sum
ren firm_state_sp_n_a_sum1 firm_state_sp_n_a_sum
ren bid_price_n_a_min1 bid_price_n_a_min
ren same_city_pbu_firm_n_a_min1 same_city_pbu_firm_n_a_min
ren firm_state_sp_n_a_min1 firm_state_sp_n_a_min
ren bid_price_n_a_max1 bid_price_n_a_max
ren same_city_pbu_firm_n_a_max1 same_city_pbu_firm_n_a_max
ren firm_state_sp_n_a_max1 firm_state_sp_n_a_max
ren bid_price_n_a_mean1 bid_price_n_a_mean
ren same_city_pbu_firm_n_a_mean1 same_city_pbu_firm_n_a_mean
ren firm_state_sp_n_a_mean1 firm_state_sp_n_a_mean
ren bid_price_n_a_median1 bid_price_n_a_median
ren same_city_pbu_firm_n_a_median1 same_city_pbu_firm_n_a_median
ren firm_state_sp_n_a_median1 firm_state_sp_n_a_median
ren bid_price_n_a_sd1 bid_price_n_a_sd
ren same_city_pbu_firm_n_a_sd1 same_city_pbu_firm_n_a_sd
ren firm_state_sp_n_a_sd1 firm_state_sp_n_a_sd
ren bid_price_n_a_semean1 bid_price_n_a_semean
ren same_city_pbu_firm_n_a_semean1 same_city_pbu_firm_n_a_semean
ren firm_state_sp_n_a_semean1 firm_state_sp_n_a_semean
ren tot_firm_type61 tot_firm_type6
ren tot_pot_epp_me1 tot_pot_epp_me

gen po_success=1
replace po_success=0 if fornec_code=="Sem Vencedor"

gen price_greater_ref=0
replace price_greater_ref=1 if ref_winprice_perc > 1

gen negot=1
replace negot=0 if bid_price_negot_min==.

gen tot_value = bid_price_ref* bid_qty_item
gen group65=0
replace group65=1 if group_item=="65"

gen convite_mandatory=0
replace convite_mandatory=1 if date>=tm(2015m8)

gen pregao_mandatory=0
replace pregao_mandatory=1 if date>=tm(2017m7)

gen group65_mandatory=0
replace group65_mandatory=1 if date>=tm(2018m3)


gen tot_firm= tot_firm_type1+ tot_firm_type2+ tot_firm_type3+ tot_firm_type4+ tot_firm_type5+ tot_firm_type6

gen epp_firms_perc= tot_pot_epp_me / tot_firm

gen ln_bid_price_ref=ln(bid_price_ref)
gen ln_bid_price_winner=ln(bid_price_winner)
gen ln_bid_qty_item=ln(bid_qty_item)

gen po_subject=subject
drop subject

gen jud_adm = 0
replace jud_adm = 1 if strpos(po_subject, "JUDIC") | strpos(po_subject, "LIMINAR") | strpos(po_subject, "MANDADO") | strpos(po_subject, "MAN-DADO") | strpos(po_subject, " AJ") | strpos(po_subject, "ADMINISTRATIV")


* Extracting year from date
extrdate year ydate=date
 
save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/20200128_BEC_FINAL_ITEMS.dta", replace


*---------------------------------------------------------------------------------------------------------------------------

* PAPER 1 - JUDICIAL DECISIONS *

*---------------------------------------------------------------------------------------------------------------------------

clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/20200128_BEC_FINAL_ITEMS.dta", clear

keep if orgao_cod=="09000"

sort po


merge m:1 po using "C:/Users/pesquisa/Documents/Papers/Word/OneDrive/Paper 1 - Judicialization/Datasets/2-JUD_REGEX_EDITAIS.dta", generate(_merge_JUD)

drop dummy*

replace jud_regex=0 if _merge_JUD==1

gen jud_adm2=jud_adm
replace jud_adm2=0 if strpos(po_subject, "MATERIAL ADMINISTRATIVO") | strpos(po_subject, "MATERIAIS ADMINISTRATIVOS")

replace jud_adm2=0 if jud_adm2==.
gen sum_jud=jud_regex+jud_adm2

gen jud=0
replace jud=1 if sum_jud>0

**** CREATE BIGTAB AND SELECT JUD ITEMS ****

merge m:1 item using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/0 -SELECTED_ITEMS_JUD_AUX.dta", generate(_merge_ITEM_JUD)

keep if _merge_ITEM_JUD==3

keep if group_item=="65"

quietly tab item, generate(ditem)
quietly tab pbu_code, generate(dpbu_code)
*quietly tab year, generate(dyear)
*quietly tab m_y, gen(dm_y)

** Generating variable month

// gen dm=m_y
// format dm %10.0g
// di (53 - 60)*12
// gen date_dm = dofm(dm)
// format date %d
// gen month=month(date_dm)
// quietly tab month, generate(dmonth)



drop ditem1 dpbu_code1

*** Quantities

eststo clear
eststo: quietly reg ln_bid_qty_item jud ditem* if po_success==1
eststo: quietly reg ln_bid_qty_item jud ditem* dpbu* if po_success==1
eststo: quietly reg ln_bid_qty_item jud ditem* dpbu* pregao if po_success==1
eststo: quietly reg ln_bid_qty_item jud ditem* dpbu* dyear* dmonth* pregao if po_success==1
esttab using quantity.rtf, b(%9.4f) se(%9.4f) ar2 drop(ditem* dpbu* dyear* dmonth* _cons) label title(Effect of Litigation on Quantity (Dep. Var.: Log Quantity)) nomtitles indicate("Item Codes = ditem2" "PBU = dpbu_code2" "Year = dyear2" "Month = dmonth2") compress  replace

save  "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PAPER1-JUD.dta", replace





**** PREGAO

keep if proc==3
sort m_y po item po_phase_code bid_unit_price

drop item_unit descriçãotipoempresa descriçãoenquadramento_caufesp descriçãofornecedorstatus descriçãopaísfornecedor po_status_code t po_item_merge_key codigo_uf po_item_merge_key _merge_firm_geoc_final _merge_cities _merge_firm_geoc bid_id same_city_pbu_firm_acession same_city_pbu_firm_prop same_city_pbu_firm_bids same_city_pbu_firm_negot same_city_pbu_firm_n_a same_city_pbu_firm_pref same_city_pbu_firm_realinh firm_state_sp_acession firm_state_sp_prop firm_state_sp_bids firm_state_sp_negot firm_state_sp_n_a firm_state_sp_pref firm_state_sp_realinh po_item_id po_item_key bid_count firm_zipcode_length firm_id_zipcode flag flag_items flag_groups flag_classes flag_firms flag_EPP flag_Phase flag_qty firm_type_key key_epp key_po_phase_code po_winner_sum same_city_pbu_firm_sum firm_state_sp_sum same_city_pbu_firm_acession_sum same_city_pbu_firm_prop_sum same_city_pbu_firm_bids_sum same_city_pbu_firm_negot_sum same_city_pbu_firm_pref_sum same_city_pbu_firm_realinh_sum firm_state_sp_acession_sum firm_state_sp_prop_sum firm_state_sp_bids_sum firm_state_sp_negot_sum firm_state_sp_pref_sum firm_state_sp_realinh_sum bid_price_n_a_sum same_city_pbu_firm_n_a_sum firm_state_sp_n_a_sum dist_min bid_price_min bid_time_min bid_unit_price_negot_min bid_ref_price_min bid_price_acession_min bid_price_prop_min bid_price_bids_min bid_price_negot_min bid_price_pref_min bid_price_realinh_min bid_price_n_a_min same_city_pbu_firm_n_a_min firm_state_sp_n_a_min proc_length_minutes dist_max bid_price_max po_winner_max bid_time_max bid_unit_price_negot_max bid_ref_price_max bid_price_acession_max bid_price_prop_max bid_price_bids_max bid_price_negot_max bid_price_pref_max bid_price_realinh_max bid_price_n_a_max same_city_pbu_firm_n_a_max firm_state_sp_n_a_max dist_mean bid_price_mean bid_price_acession_mean bid_price_prop_mean bid_price_bids_mean bid_price_negot_mean bid_price_pref_mean bid_price_realinh_mean bid_price_n_a_mean same_city_pbu_firm_n_a_mean firm_state_sp_n_a_mean dist_median bid_price_median bid_price_acession_median bid_price_prop_median bid_price_bids_median bid_price_negot_median bid_price_pref_median bid_price_realinh_median bid_price_n_a_median same_city_pbu_firm_n_a_median firm_state_sp_n_a_median dist_sd bid_price_sd bid_price_acession_sd bid_price_prop_sd bid_price_bids_sd bid_price_negot_sd bid_price_pref_sd bid_price_realinh_sd bid_price_n_a_sd same_city_pbu_firm_n_a_sd firm_state_sp_n_a_sd dist_semean bid_price_semean bid_price_acession_semean bid_price_prop_semean bid_price_bids_semean bid_price_negot_semean bid_price_pref_semean bid_price_realinh_semean bid_price_n_a_semean same_city_pbu_firm_n_a_semean firm_state_sp_n_a_semean key_qty proc_length_seconds proc_length_minutes proc_length_hours proc_length_days



* SIMPLIFIED


clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/PREGAO1.dta", clear

keep po item item_descr categ_item class_item class_item_descr group_item group_item_descr green_item item_type po_phase_code pbu_code pbu_code_year pbu_power_code pbu_type_mgmt_code pbu_city_area pbu_zipcode  same_city_pbu_firm firm_id firm_legal_nature firm_descr firm_city firm_state firm_zipcode firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code ibge_cod_cidade_firm firm_state_sp ibge_cod_uf_firm bid_ref_price bid_unit_price bid_unit_price_negot bid_item_qty_perbid bid_qty_item bid_status bid_status_group_code po_status bid_winner dist m_y year diamêsencerramento bid_rank bid_time_date

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/Simplified/PREGAO1_SIMPL.dta", replace


clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/PREGAO2.dta", clear

keep po item item_descr categ_item class_item class_item_descr group_item group_item_descr green_item item_type po_phase_code pbu_code pbu_code_year pbu_power_code pbu_type_mgmt_code pbu_city_area pbu_zipcode  same_city_pbu_firm firm_id firm_legal_nature firm_descr firm_city firm_state firm_zipcode firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code ibge_cod_cidade_firm firm_state_sp ibge_cod_uf_firm bid_ref_price bid_unit_price bid_unit_price_negot bid_item_qty_perbid bid_qty_item bid_status bid_status_group_code po_status bid_winner dist m_y year diamêsencerramento bid_rank bid_time_date

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/Simplified/PREGAO2_SIMPL.dta", replace


clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/PREGAO3.dta", clear

keep po item item_descr categ_item class_item class_item_descr group_item group_item_descr green_item item_type po_phase_code pbu_code pbu_code_year pbu_power_code pbu_type_mgmt_code pbu_city_area pbu_zipcode  same_city_pbu_firm firm_id firm_legal_nature firm_descr firm_city firm_state firm_zipcode firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code firm_simples_code ibge_cod_cidade_firm firm_state_sp ibge_cod_uf_firm bid_ref_price bid_unit_price bid_unit_price_negot bid_item_qty_perbid bid_qty_item bid_status bid_status_group_code po_status bid_winner dist m_y year diamêsencerramento bid_rank bid_time_date

save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/Simplified/PREGAO3_SIMPL.dta", replace


clear all

use "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/Simplified/PREGAO1_SIMPL.dta", clear

append using "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/Simplified/PREGAO2_SIMPL.dta" "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/Simplified/PREGAO3_SIMPL.dta"


gen bid_unit_pr=bid_unit_price/bid_qty_item

ren bid_unit_price bid_unit_value

ren bid_unit_pr bid_unit_price

order m_y pbu_code  pbu_power_code pbu_type_mgmt_code po item po_phase bid_time_date firm_id firm_descr firm_type_code firm_person_code firm_headqtr_branch_code firm_legal_nature_code same_city_pbu_firm bid_time_date bid_ref_price bid_unit_price_negot bid_unit_price bid_item_qty_perbid bid_unit_value bid_qty_item bid_status bid_status_group_code po_status bid_winner dist

sort m_y po item po_phase_code bid_time_date


save "/home/darciogm1/projetos/bitter-pills/data/raw/bec-procurement/FINAL/UPDATED/BASELINE/PREGAO/Version 1/Simplified/PREGAO_SIMPL.dta", replace
