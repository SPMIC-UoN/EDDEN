#!/bin/bash

# Author: J.P. Manzano Patron
# Last update: 2023-11-15
# Description: Pipeline for the evaluation of denoising methods - Run the preprocessing of the structural T1 using the BRC pipeline (https://github.com/SPMIC-UoN/BRC_Pipeline).
# Publication: https://www.biorxiv.org/content/10.1101/2023.07.24.550348v2
# Dataset: Available after paper publication


# Define usage function to display how to use the script
usage() {
  echo "Usage: $0 -dPath dPath"
  echo " "
  echo " Run the preprocessing of the structural T1 using the BRC pipeline (https://github.com/SPMIC-UoN/BRC_Pipeline)"
  echo " -dPath dPath     : E.g. ~/data/Dataset_B/rep1/RAW"
  echo " "
  echo " The script assumes the same structure than in ~/code/denoising_pipeline/03_run_dMRI_preproc.sh."
  echo " After finishing, you can repeat the pipeline in the different subsets, i.e. run ~/code/denoising_pipeline/02_run_denoise.sh in each subset, then ~/code/denoising_pipeline/03_run_dMRI_preproc.sh, then ~/code/denoising_pipeline/06_get_derivatives.sh, etc."
  exit 0
}

# Parse command line options
while [ "$#" -gt 0 ]; do
  case "$1" in
    -dPath)
      dPath="$2"    #~/Dataset_A/rep1/RAW
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Check if mandatory arguments are provided
if [ -z "$dPath" ]; then
  echo "ERROR: Mandatory argument is missing."
  usage
fi


struc_preproc.sh --input ~/data/{dataset}/20220217-ST001-Essa_Test/T1w_MPR/T1w_MPR_T1w_MPR_20220217090820_8.nii --path ~/data/{dataset} --subject T1w_MPR --freesurfer --qc"
  