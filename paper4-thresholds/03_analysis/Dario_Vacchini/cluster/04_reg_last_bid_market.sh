#!/usr/bin/env bash
#SBATCH -n 4
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=3000
#SBATCH --time=5:00:00
#SBATCH --mail-type=ALL

# run the desired script
stata-mp -b do 04_reg_last_bid_1_750_market.do &
stata-mp -b do 04_reg_last_bid_750_1500_market.do & 
stata-mp -b do 04_reg_last_bid_1500_3500_market.do & 
stata-mp -b do 04_reg_last_bid_3500_7581_market.do & 

wait
