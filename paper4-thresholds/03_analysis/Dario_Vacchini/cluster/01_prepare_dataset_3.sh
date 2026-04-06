#!/usr/bin/env bash
#SBATCH -n 1
#SBATCH --cpus-per-task=64
#SBATCH --mem-per-cpu=3000
#SBATCH --time=1:00:00
#SBATCH --mail-type=ALL

# run the desired script
stata-mp -b do 01_prepare_dataset_3.do