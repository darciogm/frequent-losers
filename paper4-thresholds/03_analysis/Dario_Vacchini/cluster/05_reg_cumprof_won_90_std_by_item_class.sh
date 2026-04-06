#!/usr/bin/env bash
#SBATCH -n 2
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=3000
#SBATCH --time=3:00:00
#SBATCH --mail-type=ALL

# run the desired script
stata-mp -b do 05_reg_cumprof_won_90_std_by_item_class_1.do &
stata-mp -b do 05_reg_cumprof_won_90_std_by_item_class_2.do &

wait