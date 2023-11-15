#!/bin/bash

# Define usage function to display how to use the script
usage() {
  echo "Usage: $0 -basePath basePath"
  echo " "
  echo "Wrapper script to get different derivatives used in the analysis (~/Figures_paper.ipnyb). This script takes the following mandatory argument:"
  echo "-dPath dPath     : E.g. ~/data/Dataset_B/rep1/NORDIC"
  echo " "
  echo "And assumes a directory structure such as e.g. ~/data/Dataset_B/rep1/NORDIC"
  echo "This directory must contain:"
  echo "	- The non-preprocessed data in ~/data/{dataset}/{rep}/{meth}/raw/"
  echo "	- The pre-processed data, as outputs from the dMRI_preproch.sh pipeline, is in ~/data/{dataset}/{rep}/{meth}/analysis/"
  echo "	- Masks are available under ~/data/{dataset}/aux. See ~/code/masks_generation.sh"
  echo " "
  echo "For the averages, a different pre-processing is required. Check ~/code/get_averages.sh"
  echo "If you have real and imaginary data instead of magnitude and phase, convert them using ~/code/utils/imag2phase.sh"
  echo "For further tuning of hyperparameters, create your modified version the scripts."
  exit 0
}

# Parse command line options
while [ "$#" -gt 0 ]; do
  case "$1" in
    -basePath)
      basePath="$2"	#~/Dataset_A/rep1/RAW
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

# Get the WM and GM masks registered to the complex average
T1_processed=${basePath}/T1w_MPR/analysis/anatMRI/T1/processed

WM_T1=${T1_processed}/seg/tissue/sing_chan/T1_WM_mask.nii.gz
GM_T1=${T1_processed}/seg/tissue/sing_chan/T1_GM_mask.nii.gz
auxDir=${basePath}/aux
nodif=${basePath}/aux/b0_AP_rep1

#fslroi ${dPath}/avg/COMPLEX/AVG_COMPLEX.nii.gz ${nodif} 0 1
fslroi ${dPath}/rep1/RAW/analysis/dMRI/processed/data/data.nii.gz ${nodif} 0 1

epi_reg --epi=${nodif} --t1=${T1_processed}/data/T1.nii.gz --t1brain=${T1_processed}/data/T1_brain.nii.gz --wmseg=${WM_T1} --out=${basePath}/aux/diff_2_T1
convert_xfm -omat ${basePath}/aux/T1_2_diff.mat -inverse ${basePath}/aux/diff_2_T1.mat
flirt -in ${WM_T1} -interp nearestneighbour -ref ${nodif} -applyxfm -init ${basePath}/aux/T1_2_diff.mat -out ${basePath}/aux/WM_mask
flirt -in ${GM_T1} -interp nearestneighbour -ref ${nodif} -applyxfm -init ${basePath}/aux/T1_2_diff.mat -out ${basePath}/aux/GM_mask

--in=WM_mask_thresh0.9





### T1 2 diff (mat)
WM_T1=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/T1w_MPR/analysis/anatMRI/T1/processed/seg/tissue/sing_chan/T1_WM_mask.nii.gz
ref=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/rep1/MPPCA/raw/MPPCA_AP.nii.gz
WM_diff=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/aux/WM_diff.nii.gz
T1_2_diff_warp=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/rep1/MPPCA/analysis/dMRI/preproc/reg/T1_2_diff.mat
applywarp -i $WM_T1 -r $ref -o $WM_diff --premat=$T1_2_diff_warp --rel
applywarp -i $WM_T1 -r $ref -o $WM_diff --premat=$T1_2_diff_warp

###diff 2 std
WM_std=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/aux/WM_std_fromDiff.nii.gz
diff_2_std_warp=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/rep1/MPPCA/analysis/dMRI/preproc/reg/diff_2_std.mat
ref=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/rep1/MPPCA/analysis/dMRI/processed/data/nodif_brain_mask.nii.gz
applywarp -i $WM_diff -r $ref -o $WM_std --premat=$diff_2_std_warp --rel
applywarp -i $WM_diff -r $ref -o $WM_std --premat=$diff_2_std_warp

### T1 2 std (warps)
WM_T1=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/T1w_MPR/analysis/anatMRI/T1/processed/seg/tissue/sing_chan/T1_WM_mask.nii.gz
ref=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/rep1/MPPCA/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz
T1_2_std_warp=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/T1w_MPR/analysis/anatMRI/T1/preproc/reg/T1_2_std_warp_coeff.nii.gz
WM_std=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/aux/WM_std_II.nii.gz
applywarp -i $WM_T1 -r $ref -o $WM_std -w $T1_2_std_warp --rel

### diff 2 std (warps)
WM_diff=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/aux/WM_orig.nii.gz
ref=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/rep1/MPPCA/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz
diff_2_std_warp=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/rep1/MPPCA/analysis/dMRI/preproc/reg/diff_2_std_warp_coeff.nii.gz
WM_std=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/Dataset_B/aux/WM_std_III.nii.gz
applywarp -i $WM_diff -r $ref -o $WM_std -w $diff_2_std_warp



# WM mask in standard space
dataPath=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/${dataset}
mkdir -p ${dataPath}/aux
T1_WM_mask=${dataPath}/T1w_MPR/analysis/anatMRI/T1/processed/seg/tissue/sing_chan/T1_WM_mask.nii.gz
warp=${dataPath}/T1w_MPR/analysis/anatMRI/T1/preproc/reg/T1_2_std_warp_coeff.nii.gz
ref=${dataPath}/rep1/RAW/analysis/dMRI/processed/data/nodif_brain_mask.nii.gz
WM_std=${dataPath}/aux/WM_std.nii.gz
applywarp -i $T1_WM_mask -o $WM_std -r $ref -w $warp

#WM mask in original diffusion space
dataset=Dataset_C
dataPath=/gpfs01/share/HCP/CMRR_denoise/Session3_June21/data/${dataset}
mkdir -p ${dataPath}/aux
WM_std=${dataPath}/aux/WM_std.nii.gz
WM_orig=${dataPath}/aux/WM_orig.nii.gz
ref=${dataPath}/rep1/RAW/raw/RAW_AP.nii.gz
warp=${dataPath}/rep1/RAW/analysis/dMRI/preproc/reg/std_2_diff_warp_coeff.nii.gz
applywarp -i $WM_std -r $ref -o $WM_orig -w $warp
