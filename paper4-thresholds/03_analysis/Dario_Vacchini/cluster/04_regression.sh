#!/usr/bin/env bash
#SBATCH -n 5
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=3000
#SBATCH --time=24:00:00
#SBATCH --mail-type=ALL

# run the desired script
stata-mp -b do 04_regression_1.do & 
stata-mp -b do 04_regression_2.do & 
stata-mp -b do 04_regression_3.do & 
stata-mp -b do 04_regression_4.do & 
stata-mp -b do 04_regression_5.do & 

wait
