#!/bin/bash

dPath=$1
dataset=$2
mask=$3


# DTI
#rm -r ${dPath}/data.dti
mkdir -p ${dPath}/data.dti
select_dwi_vols ${dPath}/data.nii.gz ${dPath}/bvals ${dPath}/data.dti/data_b1k 0 -b 1000 -obv ${dPath}/bvecs
dtifit -k ${dPath}/data.dti/data_b1k.nii.gz -o ${dPath}/data.dti/dti -m ${mask} -r ${dPath}/data.dti/data_b1k.bvec -b ${dPath}/data.dti/data_b1k.bval --save_tensor 
dtigen -t ${dPath}/data.dti/dti_tensor.nii.gz -o ${dPath}/data.dti/dti_pred -b ${dPath}/data.dti/data_b1k.bval -r ${dPath}/data.dti/data_b1k.bvec -m ${mask} --s0=${dPath}/data.dti/dti_S0.nii.gz
fslcpgeom ${dPath}/data.dti/data_b1k.nii.gz ${dPath}/data.dti/dti_pred.nii.gz
fslmaths ${dPath}/data.dti/data_b1k.nii.gz -sub ${dPath}/data.dti/dti_pred.nii.gz -mas ${mask} ${dPath}/data.dti/dti_residuals.nii.gz
smoothest -d 7 -r ${dPath}/data.dti/dti_residuals.nii.gz -m ${mask} > ${dPath}/data.dti/smoothest_res.txt

# DKI
if [ "$dataset" == "Dataset_B" ]; then
    # If dataset B, we remove volumes from bshell=3k to make it more comparable to the rest of datasets
    rm -r ${dPath}/data.dki
    mkdir -p ${dPath}/data.dki
    select_dwi_vols ${dPath}/data.nii.gz ${dPath}/bvals ${dPath}/data.dki/data_nob3k 0 -b 1000 -b 2000 -obv ${dPath}/bvecs
    dtifit -k ${dPath}/data.dki/data_nob3k -o ${dPath}/data.dki/dki_nob3k -m ${mask} -b ${dPath}/data.dki/data_nob3k.bval -r ${dPath}/data.dki/data_nob3k.bvec --kurt --save_tensor 
    dtigen -t ${dPath}/data.dki/dki_nob3k_tensor.nii.gz -o ${dPath}/data.dki/dki_nob3k_pred -b ${dPath}/data.dki/data_nob3k.bval -r ${dPath}/data.dki/data_nob3k.bvec -m ${mask} --s0=${dPath}/data.dki/dki_nob3k_S0.nii.gz --kurt=${dPath}/data.dki/dki_nob3k_kurt
    fslcpgeom ${dPath}/data.dki/data_nob3k ${dPath}/data.dki/dki_nob3k_pred.nii.gz
    fslmaths ${dPath}/data.dki/data_nob3k -sub ${dPath}/data.dki/dki_nob3k_pred.nii.gz -mas ${mask} ${dPath}/data.dki/dki_nob3k_residuals.nii.gz
    smoothest -d 8 -r ${dPath}/data.dki/dki_nob3k_residuals.nii.gz -m ${mask} > ${dPath}/data.dki/smoothest_res.txt
else 
    rm -r ${dPath}/data.dki
    mkdir -p ${dPath}/data.dki
    dtifit -k ${dPath}/data.nii.gz -o ${dPath}/data.dki/dki -m ${mask} -r ${dPath}/bvecs -b ${dPath}/bvals --kurt --save_tensor 
    dtigen -t ${dPath}/data.dki/dki_tensor.nii.gz -o ${dPath}/data.dki/dki_pred -b ${dPath}/bvals -r ${dPath}/bvecs -m ${mask} --s0=${dPath}/data.dki/dki_S0.nii.gz --kurt=${dPath}/data.dki/dki_kurt
    fslcpgeom ${dPath}/data.nii.gz ${dPath}/data.dki/dki_pred.nii.gz
    fslmaths ${dPath}/data.nii.gz -sub ${dPath}/data.dki/dki_pred.nii.gz -mas ${mask} ${dPath}/data.dki/dki_residuals.nii.gz
    smoothest -d 8 -r ${dPath}/data.dki/dki_residuals.nii.gz -m ${mask} > ${dPath}/data.dki/smoothest_res.txt
fi


mask=/home/data/Denoising/data/Dataset_B/aux/nodif_brain_mask_ero.nii.gz
for rep in rep1 rep2 rep4 rep5; do
dPath=${rep}/NLM/analysis/dMRI/processed/data_30dirs
dtifit -k ${dPath}/data.dti/data_b1k.nii.gz -o ${dPath}/data.dti/dti -m ${mask} -r ${dPath}/data.dti/data_b1k.bvec -b ${dPath}/data.dti/data_b1k.bval --save_tensor 
done

ds=Dataset_B
for rep in rep1 rep2 rep4 rep5; do 
mkdir -p ${rep}/NLM/analysis/dMRI/processed/data_30dirs/data.dti
fslroi ${rep}/NLM/analysis/dMRI/processed/data/data.dti/data_b1k.nii.gz ${rep}/NLM/analysis/dMRI/processed/data_30dirs/data.dti/data_b1k.nii.gz 22 35 & 
done