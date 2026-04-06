#!/usr/bin/env bash
#SBATCH -n 4
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=3000
#SBATCH --time=1:00:00
#SBATCH --mail-type=ALL

# run the desired script
stata-mp -b do 02_analysis1.do & 
stata-mp -b do 02_analysis2.do & 
stata-mp -b do 02_analysis3.do & 
stata-mp -b do 02_analysis4.do & 

wait
