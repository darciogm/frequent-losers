#!/usr/bin/env bash
#SBATCH -n 1
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=3000
#SBATCH --time=2:00:00
#SBATCH --mail-type=ALL

# run the desired script
stata-mp -b do 05_reg_last_bid_by_item_class.do