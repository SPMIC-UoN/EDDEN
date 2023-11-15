#!/bin/bash


# Define usage function to display how to use the script
usage() {
  echo "Usage: $0 -dPath dPath"
  echo " "
  echo " It create the subsets of RAW data used in the paper. This script takes the following mandatory argument:"
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
      dPath="$2"	#~/Dataset_A/rep1/RAW
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


# Define subsets
case "${dataset}" in
    "Dataset_A")
        list_nvols=("21" "42" "63" "84")  # 5 subsets of 21 volumes, with 10 b1k volumes in each
        ;;
    "Dataset_B")
        list_nvols=("50" "101" "151" "201" "251")  # 6 subsets of 50-51 volumes, with 15 b1k volumes in each
        ;;
    "Dataset_C")
        list_nvols=("35" "68" "101" "134" "167")  # 6 subsets of 35-33 volumes, with 15 b1k volumes in each
        ;;
esac

for nvols in "${list_nvols[@]}"; do
	mkdir -p ${dPath}/subsamples/${nvols}/raw
	mkdir -p ${dPath}/subsamples/${nvols}/analysis
	cp ${dPath}/raw/RAW_PA.nii.gz ${dPath}/subsamples/${nvols}/raw/RAW_PA.nii.gz
	cp ${dPath}/raw/RAW_PA_ph.nii.gz ${dPath}/subsamples/${nvols}/raw/RAW_PA_ph.nii.gz
	cp ${aux}/PA.bval ${dPath}/subsamples/${nvols}/raw/RAW_PA.bval
	cp ${aux}/PA.bvec ${dPath}/subsamples/${nvols}/raw/RAW_PA.bvec
	cut -d " " -f1-${nvols} ${dPath}/raw/RAW_AP.bval > ${dPath}/subsamples/${nvols}/raw/RAW_AP.bval
	cut -d " " -f1-${nvols} ${dPath}/raw/RAW_AP.bvec > ${dPath}/subsamples/${nvols}/raw/RAW_AP.bvec
	fslroi ${dPath}/raw/RAW_AP.nii.gz ${dPath}/subsamples/${nvols}/raw/RAW_AP.nii.gz 0 ${nvols} &
	fslroi ${dPath}/raw/RAW_AP_ph.nii.gz ${dPath}/subsamples/${nvols}/raw/RAW_AP_ph.nii.gz 0 ${nvols} &
done



# TO-DO: Explore optimal subselection of volumes with http://web4.cs.ucl.ac.uk/research/medic/camino/pmwiki/pmwiki.php?n=Man.Subsetpoints E.g.
#subsetpoints ~/data/AP_b1k.txt -singlesubset 10 -savestate ~/data/AP_b1k_DatasetA_10state > AP_b1k_DatasetA_10.txt"

