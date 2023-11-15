#!/bin/bash



# Author: J.P. Manzano Patron
# Last update: 2023-11-15
# Description: Pipeline for the evaluation of denoising methods - Wrapper script to produce derivative files (model fits, etc.) used for the analysis (see ~/code/Figures_paper.ipynb)
# Publication: https://www.biorxiv.org/content/10.1101/2023.07.24.550348v2
# Dataset: Available after paper publication


# Define usage function to display how to use the script
usage() {
  echo "Usage: $0 -dPath dPath"
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
  echo "For the averages, a different pre-processing is required. Check ~/code/averages_pipeline.sh"
  echo "If you have real and imaginary data instead of magnitude and phase, convert them using ~/code/utils/imag2phase.sh"
  echo "For further tuning of hyperparameters, create your modified version the scripts."
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


cwd=`pwd`
meth=`basename ${dPath}` 		# e.g. RAW
sessionPath=`dirname ${dPath)}`	# Multiple sessions, i.e. multiple repeated scans. E.g. ~/Dataset_A/rep1
basePath=`dirname ${sessionPath}`	# E.g. ~/Dataset_A
dataset=`basename ${basePath}`		# E.g. Dataset_A
auxDir=${basePath}/aux
T1=${basePath}/T1
rawDir=${sessionPath}/RAW
preprocData=${dPath}/analysis/dMRI/processed/data
CODEDIR=

echo "*** Getting derivatives from ${dPath} ***"
current_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "Current date and time: $current_time"

#############################################################
###############			DIFFERENCE MAPS		#################
#############################################################
if [ "$meth" != "RAW" ]; then
	echo "$(date +"%Y-%m-%d %H:%M:%S") - ${meth} Denoised data provided, so getting the difference maps with respect to non-denoised data...."
	nohup fslmaths ${dPath}/raw/${meth}_AP.nii.gz -sub ${rawDir}/raw/RAW_AP.nii.gz ${dPath}/raw/differences.nii.gz &
	echo "$(date +"%Y-%m-%d %H:%M:%S") - Difference maps calculated. Check results in ${dPath}/raw/differences.nii.gz"
fi


#############################################################
####  Discard PA volumes from the pre-processed data	 ####
#############################################################
echo "$(date +"%Y-%m-%d %H:%M:%S") - Discarding PA volumes from pre-processed data...."
AP_nvols=`fslnvols ${dPath}/raw/${meth}_AP.nii.gz
cp ${preprocData}/data.nii.gz ${preprocData}/data_AP_PA.nii.gz
cp ${preprocData}/bvals ${preprocData}/bvals_AP_PA
cp ${preprocData}/bvecs ${preprocData}/bvecs_AP_PA

fslroi ${preprocData}/data_AP_PA.nii.gz ${preprocData}/data.nii.gz 0 $AP_nvols
cp ${auxDir}/AP.bval ${dPath}/bvals
cp ${auxDir}/AP.bvec ${dPath}/bvecs

#bvals
#awk -F' '  '{ for(i=1; i<=99; i++) {print $i} }' ${dPath}/data/bvals > ${dPath}/data_AP/bvals_temp
#tr -s '\n'  ' '< ${dPath}/data_AP/bvals_temp > ${dPath}/data_AP/bvals
#rm ${dPath}/data_AP/bvals_temp	
#bvecs
#cut -d$' ' -f -198 < ${dPath}/data/bvecs > ${dPath}/data_AP-PA/bvecs
echo "$(date +"%Y-%m-%d %H:%M:%S") - PA volumes discarded."


#############################################################
##########		SPHERICAL HARMONICS POWER MAPS		#########	##### pass inputs to this script
#############################################################
echo "$(date +"%Y-%m-%d %H:%M:%S") - Extracting 'timeseries' from ventricles (noise distribution)...."
cd ${preprocData}
nohup python ${CODEDIR}/get_SH_power &
echo "$(date +"%Y-%m-%d %H:%M:%S") - Calculation of spherical Harmonics power finished. Check outputs in ${preprocData}/data.SH/"


#############################################################
########	TIMESERIES FOR NOISE DISTRIBUTION		#########
#############################################################
echo "$(date +"%Y-%m-%d %H:%M:%S") - Extracting 'timeseries' from ventricles (noise distribution)...."
fslmeants -i {preprocData}/data.nii.gz \
          -o {preprocData}/ts_CSF.txt \
          -m {auxDir}/ventricles_mask.nii.gz --showall
echo "$(date +"%Y-%m-%d %H:%M:%S") - Timeseries from the ventricles extracted. Check outputs in ${preprocData}/ts_CSF.txt"


#############################################################
###########   	     RESELS ESTIMATION	    	#############
#############################################################
echo "$(date +"%Y-%m-%d %H:%M:%S") - Fitting DTI and DKI models and using their residuals to estimate the effective voxel resolution (resels)...."
nohup bash ${CODEDIR}/get_Resels.sh ${preprocData} ${dataset} ${auxDir}/nodif_brain_mask_ero.nii.gz &
echo "$(date +"%Y-%m-%d %H:%M:%S") - DTI and DKI models fitted under ${preprocData}/data.DTI (or data.DKI). Resels estimation is contained in the smoothest_res.txt file under these directories."


#############################################################
###########     	     BOOTSTRAPPING 	    	#############
#############################################################
echo "$(date +"%Y-%m-%d %H:%M:%S") - Running wild bootstrapping on DTI fits..."
mask=${auxDir}/nodif_brain_mask_ero.nii.gz
nsamples=250
run_dtifit=True
preserve_files=False
nohup python ${CODEDIR}/wild_bootstrapping_residuals.py \
			${preprocData}/data.dti/dti_pred.nii.gz \
			${preprocData}/data.dti/dti_residuals.nii.gz \
			${preprocData}/data.dti/data_b1k.bval \
			${preprocData}/data.dti/data_b1k.bvec \
			${preprocData}/data.dti_wild_bootstrap/ \
			${mask} 1 ${nsamples} ${run_dtifit} ${preserve_files} &
echo "$(date +"%Y-%m-%d %H:%M:%S") - Wild bootstrapping completed. Check results in ${preprocData}/data.dti/bootstrap (Files preserved? ${preserve_files} )."
echo "Remember, this only produced the new data with flipped residuals. DTIFIT needs to be run for each bootstrap sample generated."
#mask=${auxDir}/nodif_brain_mask_ero.nii.gz
#bootstrapDir=${preprocData}/data.dti/bootstrap/
#for i in $(seq 1 250); do
#    dtifit -k ${bootstrapDir}/${i}/data_b1k.nii.gz -o ${bootstrapDir}/${i}/dti -r ${bootstrapDir}
#    rm ${bootstrapDir}/${i}/dti_L1.nii.gz ${bootstrapDir}/${i}/dti_L2.nii.gz ${bootstrapDir}/${i}/dti_L3.nii.gz ${bootstrapDir}/${i}/dti_V2.nii.gz ${bootstrapDir}/${i}/dti_V3.nii.gz ${bootstrapDir}/${i}/dti_MO.nii.gz ${bootstrapDir}/${i}/dti_S0.nii.gz
#done

bash run_wild_bootstrapping.sh ${preprocData} ${i} ${mask} ${nsamples}
###### SUM AND GET AVG/STD MAPS AND DELETE THE REST???




#############################################################
#########       OTHER MICROSTRUCTURAL MODELS 	  ###########
#############################################################
${CUDIMOT}/bin/Pipeline_NODDI_Watson.sh ${preprocData} & 	# NODDI
bedpostx_gpu ${preprocData} -model 2 -b 3000			 	# BPX for crossings, without term for noise floor nor rician model.


#############################################################
###########       ACCURACY-PRECISION 	   	#############		#### REALLY NEEDED? OR WE DO IT WITH PYTHON ALREADY? -- SAME FOR TRACT CORRELATION
#############################################################
for mask in WM GM ventricles; do
for map in FA MD; do 
mkdir -p CONCATENATED/ref_corr
corrPath=ref_corr
for rep in rep1 rep2 rep3 rep4 rep5 rep6; do
fslcc -m aux/${mask}_mask.nii.gz CONCATENATED/${rep}/${meth}/analysis/dMRI/processed/data/data.dti/dti_${map}.nii.gz ${rep}/AVG_complex/analysis/dMRI/processed/data/data.dti/dti_${map}.nii.gz >> ${corrPath}/${meth}_${map}_${mask}.txt 
done
# To remove first columns and whitespaces (ie only correlation values remain) from the text generated by fslroi
mv CONCATENATED/${corrPath}/${meth}_${map}_${mask}.txt ${corrPath}/${meth}_${map}_${mask}_temp.txt
awk '{$1=""; $2=""; gsub(/^[ \t]+|[ \t]+$/, ""); print}' ${corrPath}/${meth}_${map}_${mask}_temp.txt > ${corrPath}/${meth}_${map}_${mask}.txt
rm ${corrPath}/${meth}_${map}_${mask}_temp.txt
done


#############################################################
##########       PROBABILISTIC TRACTOGRAPHY 	 ############
#############################################################
aux=`dirname ${sessionPath)}`
xtract -bpx ${aux}/data.bedpostX \
	   -out ${aux} \
	   -species HUMAN \
	   -stdwarp ${dPath}/analysis/dMRI/preproc/reg/std_2_diff_warp_coeff.nii.gz ${dPath}/analysis/dMRI/preproc/reg/diff_2_std_warp_coeff.nii.gz \
	   -gpu



