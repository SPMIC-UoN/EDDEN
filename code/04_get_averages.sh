#!/bin/bash


# Author: J.P. Manzano Patron
# Last update: 2023-11-15
# Description: Pipeline for the evaluation of denoising RAWods - Script to pre-process and generate the multiple-repeats averages of RAW data
# Publication: https://www.biorxiv.org/content/10.1101/2023.07.24.550348v2
# Dataset: Available after paper publication


# Define usage function to display how to use the script
usage() {
  echo "Usage: $0 -dPath dPath -avg avg"
  echo " "
  echo "Wrapper script to get different derivatives used in the analysis (~/Figures_paper.ipnyb). This script takes the following mandatory argument:"
  echo "-basePath basePath     : E.g. ~/data/Dataset_B"
  echo "-avg: avg			   : {magnitude, complex}"
  echo " "
  echo "And assumes a directory structure such as e.g. ~/data/Dataset_B/rep1/NORDIC"
  echo "This directory must contain:"
  echo "	- The non-preprocessed data in ~/data/{dataset}/{rep}/{RAW}/raw/"
  echo "	- The pre-processed data, as outputs from the dMRI_preproch.sh pipeline, is in ~/data/{dataset}/{rep}/{RAW}/analysis/"
  echo "	- Masks are available under ~/data/{dataset}/aux. See ~/code/masks_generation.sh"
  echo " "
  exit 0
}

# Parse command line options
while [ "$#" -gt 0 ]; do
  case "$1" in
    -basePath)
      basePath="$2"	#~/Dataset_A
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Check if mandatory arguments are provided
if [ -z "$basePath" ] || [ -z "$avg" ]; then
  echo "ERROR: Mandatory argument is missing."
  usage
fi

# Depending on the type of average, set the input and output files
case "${avg}" in
    "magnitude")
        AVG='AVG_complex'
        RAW='RAW_real'
        ;;
    "complex")
        AVG='AVG_complex'
        RAW='RAW_real'
        ;;
esac

# Define number of repetitions
case "${dataset}" in
    "Dataset_A")
        nreps=6  
        ;;
    "Dataset_B")
        nreps=5  
        ;;
    "Dataset_C")
        nreps=4  
        ;;
esac

# For simplicity in the analysis, we save the averages files in under ~/data/${dataset}/rep1.
mkdir -p {basePath}/rep1/${AVG}/raw/

# Concatenate repeats as they are (i.e. we don't copy the first b0 from rep1 in the rest of repetitions)
if [ "$nreps" -gt 1 ]; then
    # Initialize the concatenated files with the first repetition
    cp "${basePath}/rep1/RAW/raw/${RAW}_AP.nii.gz" "${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_AP.nii.gz"
    cp "${basePath}/rep1/RAW/raw/${RAW}_PA.nii.gz" "${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_PA.nii.gz"

    # Concatenate the rest of the repetitions
    for i in $(seq 2 "$nreps"); do
        fslmerge -t "${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_AP.nii.gz" "${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_AP.nii.gz" "${basePath}/rep${i}/${RAW}/raw/${RAW}_AP.nii.gz"
        fslmerge -t "${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_PA.nii.gz" "${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_PA.nii.gz" "${basePath}/rep${i}/${RAW}/raw/${RAW}_PA.nii.gz"
    done
else
    echo "ERROR: Number of repeats should be higher than 1."
    exit 1
fi


#### RUN THE dMRI_preproc pipeline
if [ "$avg" == "magnitude" ]; then
	dMRI_preproc.sh --input ${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_AP.nii.gz \
	--input_2 --input ${basePath}/rep1/${AVG}/raw/${RAW}_concatenated_PA.nii.gz \
	--path ${basePath}/rep1 --subject ${AVG} --pe_dir 2 --echospacing 0.0007 --qc --hires --reg
else
	dMRI_preproc.sh --input ${basePath}/raw/${RAW}_concatenated_AP.nii.gz \
	--input_2 --input ${basePath}/raw/${RAW}_concatenated_PA.nii.gz \
	--path ${basePath}/rep1 --subject ${AVG} --pe_dir 2 --echospacing 0.0007 --qc --hires --reg \
	--use_topup ${basePath}/rep1/AVG_mag/analysis/dMRI/preproc/topup	
fi


# SPLIT PROCESSED DATA INTO THE RESPECTIVE REPEATS AGAIN AND CALCULATE THE AVERAGE
nvols=`fslnvols ${basePath}/rep1/RAW/raw/RAW_AP.nii.gz`
startvol=0
for i in $(seq 1 $nreps); do
	fslroi ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/data.nii.gz ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/data${i}.nii.gz ${startvol} ${nvols} # You can copy this data directly into ~/rep${i}/RAW/analysis/dMRI/processed/data if want to have them registered into the same space (e.g. to analyse IDPs)
  if [[ "$i" == "1" ]]; then
    cp ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/data${i}.nii.gz ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/sumdata.nii.gz 
  else
    fslmaths ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/sumdata.nii.gz -add ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/data${i}.nii.gz ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/sumdata.nii.gz
  fi
	startvol=$((i*nvols))
done

mv ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/data.nii.gz ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/data_concatenated.nii.gz
fslmaths ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/sumdata.nii.gz -div ${nreps} ${basePath}/rep1/${AVG}/analysis/dMRI/processed/data/data.nii.gz # This is already the AVG data without PA volumes









###########################################################
## RUN EDDY ON PEPPER
# AVG mag
#refDir=${dPath}/AVG_mag/analysis/dMRI/preproc
#ref_eddyDir=${refDir}/eddy
#ref_topupDir=${refDir}/topup
#inputData=${dPath}/AVG_complex/raw
#eddyDir=${dPath}/AVG_complex/analysis/dMRI/preproc/eddy
#mkdir -p ${eddyDir}
#rm -r ${eddyDir}/*
#/usr/local/fsl-6.0.5/bin/eddy_cuda --imain=${inputData}/RAW_complex_AP_PA_concatenated.nii.gz \
#--mask=${ref_eddyDir}/nodif_brain_mask \
#--index=${ref_eddyDir}/index.txt \
#--acqp=${ref_eddyDir}/acqparams.txt \
#--bvecs=${ref_eddyDir}/Pos_Neg.bvecs \
#--bvals=${ref_eddyDir}/Pos_Neg.bvals \
#--out=${eddyDir}/eddy_unwarped_images \
#--fwhm=0 --flm=quadratic --cnr_maps --repol \
#--s2v_niter=0 -v --data_is_shelled \
#--topup=${ref_topupDir}/topup_Pos_Neg_b0 \
#--niter=0 --init=${ref_eddyDir}/eddy_unwarped_images.eddy_parameters > eddy_log &









