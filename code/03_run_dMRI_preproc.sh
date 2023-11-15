#!/bin/bash


# Author: J.P. Manzano Patron
# Last update: 2023-11-15
# Description: Pipeline for the evaluation of denoising methods - Run the diffusion MRI pipeline used in the BRC pipeline (Check https://github.com/SPMIC-UoN/BRC_Pipeline)
# Publication: https://www.biorxiv.org/content/10.1101/2023.07.24.550348v2
# Dataset: Available after paper publication


# Define usage function to display how to use the script
usage() {
  echo "Usage: $0 -dPath dPath"
  echo " "
  echo " Run the BRC pre-processing pipeline for diffusion MRI data (dMRI_preproc.sh, Check https://github.com/SPMIC-UoN/BRC_Pipeline). This script takes the following mandatory argument:"
  echo " -dPath dPath     : E.g. ~/data/Dataset_B/rep1/NORDIC"
  echo " "
  echo " The script assumes the following directory structure (similar to BRC pipeline):"
  echo "    ~/data/{dataset}/{rep}/{meth}/raw, e.g. ~/data/Dataset_B/rep1/NORDIC/raw"
  echo "    ~/data/{dataset}/{rep}/{meth}/analysis, e.g. ~/data/Dataset_B/rep1/NORDIC/analysis"
  echo "    ~/data/{dataset}/{rep}/{meth}/[subanalysis], e.g. ~/data/Dataset_B/rep1/NORDIC/patchsize/5/raw/..."

  echo " Input data is already denoised (if needed). The data is under {dPath}/raw/ and contains the following files:"
  echo "		- {meth}_AP.nii.gz"
  echo "		- {meth}_AP.bval"
  echo "		- {meth}_AP.bvec"
  echo "		- {meth}_PA.nii.gz"
  echo "		- {meth}_PA.bval"
  echo "		- {meth}_PA.bvec"
  echo " If bvals and bvecs are not found, they will be copied from ~/data/{dataset}/aux/."
  echo " As in the BRC pipeline, the structural T1-MPRage is expected to be pre-processed and available under ~/data/{dataset}/T1. See ~/code/denoising_pipeline/01_run_structural_preproc.sh"
  echo " If input data is denoised data, ensures that RAW data has been pre-processed already (topup from RAW will be used)."
  echo " When denoising has been applied using Matlab scripts, check the geometry and header of the outputs are correct. Use 'fslcpgeom original denoised' otherwise."
  echo " For the averages, a different pre-processing is required. Check ~/code/denoising_pipeline/04_get_averages.sh."
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


# Define paths
basePath=${dPath%data/*}data	# Extract the base path up to the last occurrence of '/data', i.e. ~/data
trimmedPath=${dPath##*data/}	# The '##*' trims everything from the start of the string up to and including the last occurrence of 'data/'

IFS='/' read -ra ADDR <<< "$trimmedPath"	# Split the trimmed path into an array based on '/'
dataset=${ADDR[0]}
rep=${ADDR[1]}
meth=${ADDR[2]}
subanalysis=${ADDR[3]}	# can be subsamples or patchsize
sub_value=${ADDR[4]}	# it depends on whether it is subsamples (it will vary depending on the subset) or patchsizes (3,5,7,9...,21)

sessionPath="${basePath}/${dataset}"
auxPath="${sessionPath}/aux"
T1="${sessionPath}/T1"
rawPath="${sessionPath}/${rep}/RAW"
preprocData=${dPath}/analysis/dMRI/processed/data


# Check bvals and bvecs exist. No need to check if the len of them agree with the nvols of data, this will be checked in the dMRI_preproc.sh
file_types=("AP.bval" "AP.bvec" "PA.bval" "PA.bvec")
for file_type in "${file_types[@]}"; do
	if [ ! -f "${dPath}/raw/${meth}_${file_type}" ]; then
		if [[ "$subanalysis" == "subsamples" ]]: then
    	echo "${dPath}/raw/ does not contain bvals and bvecs and these are mandatory."
    	exit 1
  	else 
    	echo "${dPath}/raw/${meth}_${file_type} not found. Copying from ${auxPath}/${file_type}..."
    	cp "${auxPath}/${file_type}" "${dPath}/raw/${meth}_${file_type}"
  	fi
  fi
done


#########################################
##					PRE-PROCESSING  					 ##
#########################################
# Run dMRI_preproch.sh from the BRC_pipeline. Check https://github.com/SPMIC-UoN/BRC_Pipeline for installation.
# The --hires option in dMRI_preproc requires high computational resources. Check before running.
mkdir -p ${dPath}/raw
mkdir -p ${dPath}/analysis
ln -sf ${T1}/raw/anatMRI ${dPath}/raw/
ln -sf ${T1}/analysis/anatMRI ${dPath}/analysis/

cd ${dPath}
path_aux=`dirname ${dPath}`
subject_aux=`basename ${dPath}`

if [[ "$meth" == "RAW" ]] && [[ "$rep" == "rep1" ]]; then
	echo "dMRI_preproc.sh --input ${dPath}/raw/${meth}_AP.nii.gz \
	--input_2 --input ${dPath}/raw/${meth}_PA.nii.gz \
	--path ${path_aux} --subject ${subject_aux} --pe_dir 2 --echospacing 0.0007 --qc --hires --reg"
else
	if [ -d ${sessionPath}/rep1/RAW/analysis/dMRI/preproc/topup ]; then
		echo "dMRI_preproc.sh --input ${dPath}/raw/${meth}_AP.nii.gz \
		--input_2 --input ${dPath}/raw/${meth}_PA.nii.gz \
		--path ${path_aux} --subject ${subject_aux} --pe_dir 2 --echospacing 0.0007 --qc --hires --reg \
		--use_topup ${sessionPath}/rep1/RAW/analysis/dMRI/preproc/topup"	# To make comparisons more homogenous, we used the same topup from the raw data for every method
	else 
		echo "${sessionPath}/rep1/RAW/analysis/dMRI/preproc/topup directory not found. Pre-process RAW data from rep1 first."
		exit 1
	fi
fi
