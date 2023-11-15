#!/bin/bash

# Author: J.P. Manzano Patron
# Last update: 2023-11-15
# Description: Pipeline for the evaluation of denoising methods - Wrapper script to run different denoising methods.
# Publication: https://www.biorxiv.org/content/10.1101/2023.07.24.550348v2
# Dataset: Available after paper publication

#########################################################################################
### TO-DO: Include automatic conversion between Re+Imag <---> magnitude and phase 
### Check if phase data must be in radians?
### SHALL I MERGE AP_PA in A and B before denoising?
#########################################################################################

# Define usage function to display how to use the script
usage() {
  echo "Usage: $0 -meth METH -domain DOMAIN -magn MAGN -phase PHASE -name NAME [-oPath OPATH] [-aux AUX]"
  echo " "
  echo "Wrapper function to run different denoising methods. This script takes the following mandatory and optional arguments:"
  echo "-meth METH     : Denoising method. Options: {NLM, MPPCA, NORDIC, P2S}"
  echo "-domain DOMAIN : Domain where denoised is applied. Options: {mag, complex} "
  echo "-magn MAGN     : Full path the magnitude datae.g. ~/data/mag.nii.gz"
  echo "-phase PHASE   : Full path the phase data, e.g. ~/data/phase.nii.gz. Phase data must be in radians. If you only have magnitude data, just pass anything here, it will be ignored"
  echo "-name NAME     : Output filename (do not include path or .nii.gz extension), e.g. 'mydata_MPPCA'"
  echo "[-oPath OPATH] : Output path, e.g. ~/data/subj1/denoised. Avoid last '/'. If empty, output directory will be MAGN directory"
  echo "[-aux AUX]     : (Optional) Auxiliar variable - For NLM, MPPCA and NORDIC, it defines the isotropic patch size (use an odd number). For P2S, it defines the full path to the MANDATORY bvals file"
  echo " "
  echo "If you have real and imaginary data instead of magnitude and phase ======>>>"
  echo "For further tuning of hyperparameters, create your modified version of the denoising scripts."
  exit 0
}

# Parse command line options
while [ "$#" -gt 0 ]; do
  case "$1" in
    -meth)
      meth="$2"
      shift 2
      ;;
    -domain)
      domain="$2"
      shift 2
      ;;
    -magn)
      magn="$2"
      shift 2
      ;;
    -phase)
      phase="$2"
      shift 2
      ;;
    -name)
      name="$2"
      shift 2
      ;;
    -oPath)
      oPath="$2"
      shift 2
      ;;
    -aux)
      aux="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Check if mandatory arguments are provided
if [ -z "$meth" ] || [ -z "$domain" ] || [ -z "$magn" ] || [ -z "$phase" ] || [ -z "$name" ]; then
  echo "ERROR: Mandatory arguments are missing."
  usage
fi


CODEDIR=/home/data/Denoising/code/denoise 


# Set the output directory
if [ -z "${oPath}" ]; then
    oPath="$(dirname "${magn}")"
fi


# Set the input data for denoising depending on what domain it is denoised in
if [[ ${domain} == "mag" ]]; then
    inputData=${magn}
fi


# Prepare the complex data projecting into the real axis
if [ "$meth" != "NORDIC" ] && [ "$domain" == "complex" ]; then
	echo "Projecting complex data ${magn} & ${phase} into the real axis...."
	matlab -nodisplay -nojvm -nosplash -nodesktop -r "try run_NIFTI_COMP_to_REAL('${magn}','${phase}','${oPath}/','${name}_real'); catch; end; quit;" | tail -n +11 >> ${oPath}/log_COMP_2_real_${name}.out
	fslcpgeom ${magn} ${oPath}/${name}_real.nii
	gzip -f ${oPath}/${name}_real.nii 
	echo "Task completed. New file generated: ${oPath}/${name}_real.nii.gz"
	inputData=${oPath}/${name}_real.nii.gz
fi


#### DENOISING

######################################################
######################   NORDIC   ####################
######################################################
if [ ${meth} == "NORDIC" ]; then
	if [ -z "${aux}" ]; then	
    	aux=""			# If no patch selected, just pass an empty variable
	fi
	echo "Running NORDIC ...."
	matlab -nodisplay -nojvm -nosplash -nodesktop -r "try run_NORDIC('${magn}','${phase}','${oPath}/','${name}','${domain}','${aux}'); catch; end; quit;" | tail -n +11 >> ${oPath}/log_NORDIC_${name}.out
	fslcpgeom ${magn} ${oPath}/${name}.nii
	gzip -f ${oPath}/${name}.nii


######################################################
######################   MPPCA    ####################
######################################################
elif [[ ${meth} == "MPPCA" ]]; then
	if [ -n "${aux}" ]; then				# If aux is not empty
		if [ $((aux % 2)) -eq 1 ]; then		# Check aux is and odd number
			echo "Running MPPCA in ${inputData}...."
	    	mrtrix dwidenoise ${inputData} ${oPath}/${name}.nii.gz \
	            -noise ${oPath}/${name}_noisemap.nii.gz \
	            -extent ${aux},${aux},${aux} -force
	    else
	    	echo "Please, select an odd number for the (isotropic) patch size."
	    fi	            
	else
		echo "Running MPPCA in ${inputData}...."
		mrtrix dwidenoise ${inputData} ${oPath}/${name}.nii.gz \
	            -noise ${oPath}/${name}_noisemap.nii.gz -force
	fi

######################################################
######################     NLM    ####################
######################################################
elif [[ ${meth} == "NLM" ]]; then
	if [ -n "${aux}" ]; then
		echo "aux is not empty"
		if [ $((aux % 2)) -eq 1 ]; then		# Check aux is and odd number
			radius=`echo $(((${aux}-1)/2))`
			block_radius=`echo $((5*radius))`
			echo "Running NLM in ${inputData}...."
	    	dipy_denoise_nlmeans ${inputData} \
	            --out_dir ${oPath}/ \
	            --out_denoised ${name}.nii.gz \
	            --patch_radius ${radius} \
	            --block_radius ${block_radius} \
	            --force 
	    else
	    	echo "Please, select an odd number for the (isotropic) patch size."
	    fi
	else
		echo "Running NLM in ${inputData}...."
		dipy_denoise_nlmeans ${inputData} \
            --out_dir ${oPath}/ \
            --out_denoised ${name}.nii.gz \
            --force
	fi

######################################################
#####################  PATCH2SELF   ##################
######################################################
elif [[ ${meth} == "P2S" ]]; then
	echo "P2S"
	if [ -n "$aux" ] && [ -f "$aux" ]; then
		echo "Running P2S in ${inputData}...."
		dipy_denoise_patch2self ${inputData} ${aux} --out_dir ${oPath}/ --out_denoised ${name}.nii.gz --model 'ols' --log_file ${oPath}/${name}_log --verbose --force
	else
		echo "bvals are mandatory in P2S. Please, use the -aux argument to indicate the bvals file."	
    	exit 1	
    fi
fi

echo "Denoising finished. You can find the output in ${oPath}/${name}.nii.gz"

