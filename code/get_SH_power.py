import numpy as np
from pathlib import Path
from dipy.reconst.shm import sf_to_sh, sph_harm_lookup, smooth_pinv
import nibabel as nb
from dipy.core.sphere import disperse_charges, Sphere, HemiSphere
from shutil import copyfile
from tqdm import tqdm
from joblib import Parallel, delayed
import os

# jobsub -q cpu -p 16 -s SH_power -t 15:00:00 -m 32 -c "python /home/data/Denoising/code/new_code/get_SH_power.py"


def get_data(file, mmap=True):
    img = nb.load(file, mmap=mmap)
    img_voxels = img.get_fdata()
    return img_voxels

def run_power_SH(SH, S, coords, signal, bvals, bvecs, list_bvalues, sh_order):
    SH[tuple(coords)], S[tuple(coords)] = calculate_power_SH(signal, bvals, bvecs, list_bvalues, sh_order)

def calculate_power_SH(signal, bvals, bvecs, list_bvalues, sh_order=8, sh_basis='descoteaux07', smooth=0.006, tol=100):
    # SH are calculated per shell, so specify 'multishel=True' and e.g., 'list_bvalues=[0, 1000,2000,3000]' (tolerance +-100) if needed.
    
    ###
    # This is just a dirt workaround to fix the problem of having repeated locations in the sphere, that produces error in np.dot(signal[idx_bshells[i]], invB.T)
    #unique_val, unique_idx = np.unique(bvecs[idx_bshells[i],0], return_index=True)
    # In dataset A, because of the UKB acquisition scheme, the PA acquires 2 volumes as the beginning of the AP. So it is enough by removing the last 2 volumes of each shell
    idx_bshells = []
    # Get the position associated with each b-shell
    idx_bshells.append( np.argwhere(bvals<list_bvalues[1]-tol).ravel() )
    for i in range(1, len(list_bvalues)):
        idx_bvals = np.argwhere((bvals>list_bvalues[i]-tol) & (bvals<list_bvalues[i]+tol)).ravel()
        len_unique = len(np.unique(np.round(bvecs[idx_bvals,0],4)))
        if len(idx_bvals)<len_unique:
            max_idx = len(idx_bvals)
        else:
            max_idx = len_unique    
        idx_bshells.append( idx_bvals[:max_idx] )
    ###

    # Harmonic coefficient's positions up to sh_order(l) 
    l_idx = []
    n_coeff=0
    for i in range(0, sh_order+1, 2):   # odd coefficients discarded as the dMRI signal is symmetric in the sphere
        n_coeff_new = 1+4*(i/2)         # Each even harmonic l has 4 coefficients more than the previous one
        l_idx.append( np.arange(n_coeff, n_coeff+n_coeff_new) )
        n_coeff += n_coeff_new
    n_coeff = int(n_coeff)

    # Take the 1st b0 if pre-eddy correction, not the average because of the distortion correction
    avg_b0 = np.sum(signal[idx_bshells[0]])/len(signal[idx_bshells[0]])

    # Calculate the SH coefficients per shell
    sh_coeffs = np.zeros([len(list_bvalues)-1, int(n_coeff)])
    S = np.zeros([len(list_bvalues)-1, 1+int(sh_order/2)])
    for i in range(1,len(list_bvalues)):
        pts = bvecs[idx_bshells[i],:]
        signal_native_pts = HemiSphere(xyz = pts)
        
        if len(bvecs[idx_bshells[i],:]) > len(signal_native_pts.x):
            idx_bshells[i] = idx_bshells[i][:len(signal_native_pts.x)]

        # Option 1:
        #sph_harm_basis = sph_harm_lookup.get(sh_basis)
        #Ba, m, n = sph_harm_basis(sh_order, signal_native_pts.theta, signal_native_pts.phi, full_basis=True)
        #L = -n * (n + 1)
        #invB = smooth_pinv(Ba, np.sqrt(smooth) * L)
        #data_sh = np.dot(signal[idx_bshells[i]], invB.T)
                
        # Option 2:
        sh_coeffs[i-1] = sf_to_sh(signal[idx_bshells[i]]/avg_b0, signal_native_pts, sh_order, sh_basis) # it is similar to data_sh
        #Power of coefficients by frequency bands (harmonics)
        for j in range(0, 1+int(sh_order/2)):
            S[i-1,j] = np.sum(sh_coeffs[i-1, [*map(int, l_idx[j])]] **2)
            
    
    return sh_coeffs, S#, l_idx, idx_bshells



######################################
######################################

# Define paths
basePath = '/home/data/Denoising'
CODEDIR = Path(f'{basePath}/code')
dataPath = Path(f'{basePath}/data')

# List of datasets
dataset='Dataset_C' 

rep='rep1'
list_methods = ['RAW', 'NLM', 'MPPCA', 'MPPCA_complex', 'NORDIC', 'AVG_mag', 'AVG_complex']
bvecs = np.loadtxt(f'{dataPath}/{dataset}/aux/AP.bvecs').T
bvals = np.loadtxt(f'{dataPath}/{dataset}/aux/AP.bvals')
mask = get_data(f'{dataPath}/{dataset}/aux/nodif_brain_mask.nii.gz')

if dataset=='PRISMA':
    list_bvalues = [0,1000,2000]
elif dataset=='Dataset_A':
    list_bvalues = [0,1000,2000]
elif dataset=='Dataset_B':
    list_bvalues = [0,1000,2000, 3000]
elif dataset=='Dataset_C':
    list_bvalues = [0,1000,2000]

njobs = 6
sh_order = 8
n_coeff = 0
for i in range(0, sh_order+1, 2):
    n_coeff += 1+4*(i/2)
n_coeff = int(n_coeff)
n_bands = int(sh_order/2)+1

coords = np.argwhere(mask != 0)

for meth in list_methods:
    img = get_data(f'{dataPath}/{dataset}/{rep}/{meth}/analysis/dMRI/processed/data/data.nii.gz')
    outDir = Path(f'{dataPath}/{dataset}/{rep}/{meth}/analysis/dMRI/processed/data/data.SH')
    Path(outDir).mkdir(parents=True, exist_ok=True)
    S = np.memmap(filename=f'{outDir}/S_memmap.npy', shape=(img.shape[0], img.shape[1], img.shape[2],len(list_bvalues)-1, n_bands), dtype='float32', mode='w+')
    SH_signal = np.memmap(filename=f'{outDir}/SH_signal_memmap.npy', shape=(img.shape[0], img.shape[1], img.shape[2],len(list_bvalues)-1, n_coeff), dtype='float32', mode='w+')
        
    if mask is None:
        TypeError
    else:
        Parallel(n_jobs=njobs, prefer="processes", verbose=6)(
            delayed(run_power_SH)(SH_signal, S, coords[i], img[tuple(coords[i])], bvals, bvecs, list_bvalues, sh_order)
            for i in tqdm(range(0, len(coords)))
            )
            
        #np.save(f'{outDir}/SH_signal.npy', SH_signal)
        #np.save(f'{outDir}/power_SH.npy', S)

        orig_data = nb.load(f'{dataPath}/{dataset}/{rep}/{meth}/analysis/dMRI/processed/data/data.nii.gz')
        aff_mat = orig_data.affine
        nb.save(nb.Nifti2Image(SH_signal, affine=aff_mat), os.path.join(f'{dataPath}/{dataset}/{rep}/{meth}/analysis/dMRI/processed/data/data.SH/', 'SH_signal.nii.gz'))
        nb.save(nb.Nifti2Image(S, affine=aff_mat), os.path.join(f'{dataPath}/{dataset}/{rep}/{meth}/analysis/dMRI/processed/data/data.SH/', 'power_SH.nii.gz'))
        #Path.unlink(f'{outDir}/S_memmap.npy') 
        #Path.unlink(f'{outDir}/SH_signal_memmap.npy') 
