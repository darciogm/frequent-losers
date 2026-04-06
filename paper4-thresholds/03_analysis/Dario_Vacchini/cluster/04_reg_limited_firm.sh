#!/usr/bin/env bash
#SBATCH -n 2
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=3000
#SBATCH --time=5:00:00
#SBATCH --mail-type=ALL

# run the desired script
stata-mp -b do 04_reg_limited_firm_1_750_market.do &
stata-mp -b do 04_reg_limited_firm_3500_7851_market.do &

wait
