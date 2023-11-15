#!/bin/bash

## USAGE AND HELP




# NLM --> We finally used the gaussian version --> Gaussian NLM also in the new version
# NLM --> In the patchsizes, we increase the blocksize to keep the original proportion block:patch = 5:1. T
# Complex data --> we finally used tp1 for all (RAW*, MPPCA*, NORDIC and AVG*), although NORDIC had tp3 by default. tp3 seems to provide cleaner images, but higher noise-floor, it's like it blurres a bit everything or add a smooth layer of noise on top of the images so they look smoother
# In the data of the paper:
# - All data is denoised in (AP+PA) together, we then split, fslcpgeom, and preprocess --> Denoise only AP in the new version of the paper
# - In Dataset_A and Dataset_B, every method is preprocessed independently, while in Dataset_C we used topup from rep1/RAW --> Use rep1/RAW topup in A and B in the new version of the paper...or concatenate them and apply the topup from AVG_mag
# - Dataset_A denoising and preprocessing includes the dwi volumes in PA --> This has to be removed in the new version (won't affect denoising as in the new version we don't denoise PA, but may affect preprocessing maybe) --> Do we have to do the Averages as well? (especially if we use its topup)

## --> Wait because maybe we have to use rep1 from preprocessing all the reps concatenated! They are not the same, so we should choose the one that reduces the differences between reps, so the coef of variation in the IDPs is minimally driven by this.
##		--> If so, will the masks (brain, WM, GM, ventricles...) change?


#Session 20Dec:
#res08_ipat2
#35 DWI volumes in AP.nii.gz --
#35 DWI volumes in PA.nii.gz
#6 b0s, 64 b1k volumes


########## ########## ########## ########## ########## 
#################### BIDS DATASET #################### 
########## ########## ########## ########## ########## 
#TO DO:
#- what files from T1/analysis?
#- Fieldmaps?
#- patches/subsamples?
#- If we want to put the different APs, it would be with _acq-98dir_, etc
#- Add dataset description


#CODE
########## DATASET A ###########
## RAW FOLDER
#sub-01_ses-2mm_dir-AP_run-01_part-mag_dwi.nii.gz


ds=Dataset_A
ses=ses-2mm
rm -r EDDEN/sub-01/${ses}/dwi/*
rm -r EDDEN/sub-01/${ses}/anat/*
cp ${ds}/T1w_MPR/analysis/anatMRI/T1/processed/data/T1_brain.nii.gz EDDEN/sub-01/${ses}/anat/sub-01_${ses}_T1w.nii.gz	 # T1 brain
cp ${ds}/rep1/RAW/raw/RAW_AP.bval EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_dwi.bval	#bvals and bvecs are the same for all runs
cp ${ds}/rep1/RAW/raw/RAW_AP.bvec EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_dwi.bvec

for run in 1 2 3 4 5 6; do
cp ${ds}/rep${run}/RAW/raw/RAW_AP.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_run-0${run}_part-mag_dwi.nii.gz
cp ${ds}/rep${run}/RAW/raw/RAW_AP_ph.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_run-0${run}_part-phase_dwi.nii.gz
done

run=1
cp ${ds}/rep1/RAW/raw/RAW_PA.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_run-0${run}_part-mag_dwi.nii.gz	# There is only 1 PA in Dataset_A
cp ${ds}/rep1/RAW/raw/RAW_PA_ph.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_run-0${run}_part-phase_dwi.nii.gz
cp ${ds}/rep1/RAW/raw/RAW_PA.bval EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_dwi.bval
cp ${ds}/rep1/RAW/raw/RAW_PA.bvec EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_dwi.bvec

### DERIVATIVES
# MASKS
cp ${ds}/aux/nodif_brain_mask_ero.nii.gz EDDEN/derivatives/${ses}/masks/nodif_brain_mask.nii.gz
cp ${ds}/aux/GM_mask.nii.gz EDDEN/derivatives/${ses}/masks/GM_mask.nii.gz
cp ${ds}/aux/WM_mask.nii.gz EDDEN/derivatives/${ses}/masks/WM_mask.nii.gz
cp ${ds}/aux/ventricles_mask.nii.gz EDDEN/derivatives/${ses}/masks/ventricles_mask.nii.gz
cp ${ds}/aux/CC_mask.nii.gz EDDEN/derivatives/${ses}/masks/CC_mask.nii.gz
cp ${ds}/aux/CR_mask.nii.gz EDDEN/derivatives/${ses}/masks/CR_mask.nii.gz

# DENOISING
run=1
for meth in NLM MPPCA MPPCA_complex NORDIC; do
rm -r EDDEN/derivatives/${ses}/dwi/${meth}
mkdir -p EDDEN/derivatives/${ses}/dwi/${meth}
cp ${ds}/rep${run}_backup/${meth}/raw/${meth}_AP.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-FA.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_MD.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-MD.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_V1.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-V1.nii.gz
done

run=1
for meth in RAW AVG_mag AVG_complex; do
rm -r EDDEN/derivatives/${ses}/dwi/${meth}
mkdir -p EDDEN/derivatives/${ses}/dwi/${meth}
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-FA.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_MD.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-MD.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_V1.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-V1.nii.gz
done




########## DATASET B ###########
## RAW FOLDER
ds=Dataset_B
ses=ses-1p5mm
rm -r EDDEN/sub-01/${ses}/dwi/*
rm -r EDDEN/sub-01/${ses}/anat/*
mkdir -p EDDEN/sub-01/${ses}/anat
mkdir -p EDDEN/sub-01/${ses}/dwi

cp ${ds}/T1w_MPR/analysis/anatMRI/T1/processed/data/T1_brain.nii.gz EDDEN/sub-01/${ses}/anat/sub-01_${ses}_T1w.nii.gz	 # T1 brain
cp ${ds}/rep1/RAW/raw/RAW_AP.bval EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_dwi.bval	#bvals and bvecs are the same for all runs
cp ${ds}/rep1/RAW/raw/RAW_AP.bvec EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_dwi.bvec
cp ${ds}/rep1/RAW/raw/RAW_PA.bval EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_dwi.bval
cp ${ds}/rep1/RAW/raw/RAW_PA.bvec EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_dwi.bvec

for run in 1 2 3 4 5; do
cp ${ds}/rep${run}/RAW/raw/RAW_AP.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_run-0${run}_part-mag_dwi.nii.gz
cp ${ds}/rep${run}/RAW/raw/RAW_AP_ph.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_run-0${run}_part-phase_dwi.nii.gz
cp ${ds}/rep${run}/RAW/raw/RAW_PA.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_run-0${run}_part-mag_dwi.nii.gz
cp ${ds}/rep${run}/RAW/raw/RAW_PA_ph.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_run-0${run}_part-phase_dwi.nii.gz
done


### DERIVATIVES
# MASKS
mkdir -p EDDEN/derivatives/${ses}/masks/
cp ${ds}/aux/nodif_brain_mask_ero.nii.gz EDDEN/derivatives/${ses}/masks/nodif_brain_mask.nii.gz
cp ${ds}/aux/GM_mask.nii.gz EDDEN/derivatives/${ses}/masks/GM_mask.nii.gz
cp ${ds}/aux/WM_mask.nii.gz EDDEN/derivatives/${ses}/masks/WM_mask.nii.gz
cp ${ds}/aux/ventricles_mask.nii.gz EDDEN/derivatives/${ses}/masks/ventricles_mask.nii.gz
cp ${ds}/aux/CC_mask.nii.gz EDDEN/derivatives/${ses}/masks/CC_mask.nii.gz
cp ${ds}/aux/CR_mask.nii.gz EDDEN/derivatives/${ses}/masks/CR_mask.nii.gz

# DENOISING
run=1
for meth in NLM MPPCA MPPCA_complex NORDIC; do
rm -r EDDEN/derivatives/${ses}/dwi/${meth}
mkdir -p EDDEN/derivatives/${ses}/dwi/${meth}
cp ${ds}/rep${run}_backup/${meth}/raw/${meth}_AP.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-FA.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_MD.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-MD.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_V1.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-V1.nii.gz
done

run=1
for meth in RAW AVG_mag AVG_complex; do
rm -r EDDEN/derivatives/${ses}/dwi/${meth}
mkdir -p EDDEN/derivatives/${ses}/dwi/${meth}
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-FA.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_MD.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-MD.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_V1.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-V1.nii.gz
done



########## DATASET C ###########
## RAW FOLDER
ds=Dataset_C
ses=ses-0p9mm
rm -r EDDEN/sub-01/${ses}/dwi/*
rm -r EDDEN/sub-01/${ses}/anat/*
mkdir -p EDDEN/sub-01/${ses}/anat
mkdir -p EDDEN/sub-01/${ses}/dwi

cp ${ds}/T1w_MPR/analysis/anatMRI/T1/processed/data/T1_brain.nii.gz EDDEN/sub-01/${ses}/anat/sub-01_${ses}_T1w.nii.gz	 # T1 brain
cp ${ds}/rep1/RAW/raw/RAW_AP.bval EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_dwi.bval	#bvals and bvecs are the same for all runs
cp ${ds}/rep1/RAW/raw/RAW_AP.bvec EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_dwi.bvec
cp ${ds}/rep1/RAW/raw/RAW_PA.bval EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_dwi.bval
cp ${ds}/rep1/RAW/raw/RAW_PA.bvec EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_dwi.bvec

for run in 1 2 3 4; do
cp ${ds}/rep${run}/RAW/raw/RAW_AP.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_run-0${run}_part-mag_dwi.nii.gz
cp ${ds}/rep${run}/RAW/raw/RAW_AP_ph.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-AP_run-0${run}_part-phase_dwi.nii.gz
cp ${ds}/rep${run}/RAW/raw/RAW_PA.nii.gz EDDEN/sub-01/${ses}/dwi/sub-01_${ses}_dir-PA_run-0${run}_part-mag_dwi.nii.gz
done


### DERIVATIVES
# MASKS
mkdir -p EDDEN/derivatives/${ses}/masks/
cp ${ds}/aux/nodif_brain_mask_ero.nii.gz EDDEN/derivatives/${ses}/masks/nodif_brain_mask.nii.gz
cp ${ds}/aux/GM_mask.nii.gz EDDEN/derivatives/${ses}/masks/GM_mask.nii.gz
cp ${ds}/aux/WM_mask.nii.gz EDDEN/derivatives/${ses}/masks/WM_mask.nii.gz
cp ${ds}/aux/ventricles_mask.nii.gz EDDEN/derivatives/${ses}/masks/ventricles_mask.nii.gz
cp ${ds}/aux/CC_mask.nii.gz EDDEN/derivatives/${ses}/masks/CC_mask.nii.gz
cp ${ds}/aux/CR_mask.nii.gz EDDEN/derivatives/${ses}/masks/CR_mask.nii.gz

# DENOISING
run=1
for meth in NLM MPPCA MPPCA_complex NORDIC; do
rm -r EDDEN/derivatives/${ses}/dwi/${meth}
mkdir -p EDDEN/derivatives/${ses}/dwi/${meth}
cp ${ds}/rep${run}_backup/${meth}/raw/${meth}_AP.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-FA.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_MD.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-MD.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_V1.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-V1.nii.gz
done

run=1
for meth in RAW AVG_mag AVG_complex; do
rm -r EDDEN/derivatives/${ses}/dwi/${meth}
mkdir -p EDDEN/derivatives/${ses}/dwi/${meth}
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_FA.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-FA.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_MD.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-MD.nii.gz
cp ${ds}/rep${run}_backup/${meth}/analysis/dMRI/processed/data/data.dti/dti_V1.nii.gz EDDEN/derivatives/${ses}/dwi/${meth}/sub-01_${ses}_dir-AP_run-0${run}_${meth}_dwi_processed_dti-V1.nii.gz
done





##########################################################
######## DATA CLEANING AFTER PREPROCESSING ###############
##########################################################
#	--> Add the separation of the PA after preprocessing
for ds in Dataset_A Dataset_B Dataset_C; do
for meth in RAW NLM NLM_nonrician MPPCA MPPCA_complex NORDIC NORDIC_tp3 P2S RAW_complex; do
rm -r ${ds}/rep1_backup/${meth}/raw/dMRI
rm ${ds}/rep1_backup/${meth}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.eddy_outlier_free_data.nii.gz
rm ${ds}/rep1_backup/${meth}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.nii.gz
rm ${ds}/rep1_backup/${meth}/analysis/dMRI/preproc/eddy/Pos_Neg.nii.gz
rm ${ds}/rep1_backup/${meth}/analysis/dMRI/processed/data/data_AP_PA.nii.gz
done
done

# Patchsizes
for ds in Dataset_A Dataset_B Dataset_C; do
for meth in RAW NLM NLM_nonrician MPPCA MPPCA_complex NORDIC NORDIC_tp3 P2S RAW_complex; do
for patch in 3 5 7 9 11 13 15 17 19 21; do
rm -r ${ds}/rep1_backup/${meth}/patchsize/${patch}/raw/dMRI
rm ${ds}/rep1_backup/${meth}/patchsize/${patch}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.eddy_outlier_free_data.nii.gz
rm ${ds}/rep1_backup/${meth}/patchsize/${patch}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.nii.gz
rm ${ds}/rep1_backup/${meth}/patchsize/${patch}/analysis/dMRI/preproc/eddy/Pos_Neg.nii.gz
rm ${ds}/rep1_backup/${meth}/patchsize/${patch}/analysis/dMRI/processed/data/data_AP_PA.nii.gz
done
done
done

# Subsamples
ds=Dataset_B
for meth in RAW NLM NLM_nonrician MPPCA MPPCA_complex NORDIC NORDIC_tp3 P2S RAW_complex; do
for nvols in 50 101 151 201 251; do
rm -r ${ds}/rep1_backup/${meth}/subsamples/${nvols}/raw/dMRI
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.eddy_outlier_free_data.nii.gz
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.nii.gz
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/preproc/eddy/Pos_Neg.nii.gz
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/processed/data/data_AP_PA.nii.gz
done
done

ds=Dataset_C
for meth in RAW NLM NLM_nonrician MPPCA MPPCA_complex NORDIC NORDIC_tp3 P2S RAW_complex; do
for nvols in 35 68 101 134 167; do
rm -r ${ds}/rep1_backup/${meth}/subsamples/${nvols}/raw/dMRI
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.eddy_outlier_free_data.nii.gz
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/preproc/eddy/eddy_unwarped_images.nii.gz
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/preproc/eddy/Pos_Neg.nii.gz
rm ${ds}/rep1_backup/${meth}/subsamples/${nvols}/analysis/dMRI/processed/data/data_AP_PA.nii.gz
done
done


