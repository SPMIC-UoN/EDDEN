import numpy as np
import nibabel as nb
from pathlib import Path
import sys
import os

# mask=/home/data/Denoising/data/${dataset}/aux/nodif_brain_mask_ero.nii.gz
# python ${CODEDIR}/wild_bootstrapping_residuals.py ${dPath}/data.dti/dti_pred.nii.gz ${dPath}/data.dti/dti_residuals.nii.gz ${dPath}/data.dti/data_b1k.bval ${dPath}/data.dti/data_b1k.bvec ${dPath}/data.dti_wild_bootstrap/ $mask 1 250

def export_nifti(data, orig_data, output_path, name):
    # Copy the header of the original image
    aff_mat = orig_data.affine
    nb.save(nb.Nifti2Image(data, affine=aff_mat), os.path.join(output_path, name))

def tensor_fit(bvals, bvecs):
    # Fits the diffusion tensor model using the Data vector and the bvals, bvecs matrices. The output returns
    # the estimated 3x3 diffusion tensor and the estimated S0 (i.e. b=0) intensity
    # Adapted by JP Manzano from Saad Jbabdi
    import numpy as np
    NbD = bvecs.shape[1]  # Number of diffusion gradients
    M = np.zeros((NbD,7))
    for i in range(0,NbD):
        b = bvals[i]
        g = bvecs[:,i]
        M[i, 0] = -b * g[0] ** 2
        M[i, 1] = -b * 2 * g[0] * g[1]
        M[i, 2] = -b * 2 * g[0] * g[2]
        M[i, 3] = -b * g[1] ** 2
        M[i, 4] = -b * 2 * g[1] * g[2]
        M[i, 5] = -b * g[2] ** 2
    M[:,6] = 1
    aMat = np.linalg.pinv(M)
    #Dvec = np.matmul(np.linalg.pinv(M), y) # Moore-pseudo inverse(M)*y  (eigendecomp for non-singular matrix only)
    #D_est = np.matrix([[Dvec[0], Dvec[1], Dvec[2]],
    #                  [Dvec[1], Dvec[3], Dvec[4]],
    #                  [Dvec[2], Dvec[4], Dvec[5]]])
    #s0_est = np.exp(Dvec[6])

    return M, aMat  # Returns the design matrix M and its pseudoinverse


data_hdr = nb.load(Path(sys.argv[1]))
pred = data_hdr.get_fdata()
residuals = nb.load(sys.argv[2]).get_fdata()
bvals = np.loadtxt(sys.argv[3])
bvecs = np.loadtxt(sys.argv[4])
dPath = sys.argv[5]
mask = nb.load(sys.argv[6]).get_fdata()
initial = int(sys.argv[7])
n_iter = int(sys.argv[8])


Y, PInv_Y = tensor_fit(bvals, bvecs)
H = np.dot(Y,PInv_Y)[0,:]
norm_ = np.sqrt(1-H)
residuals_norm = residuals / norm_[np.newaxis, np.newaxis, np.newaxis, :]

random_flips = np.random.choice([-1, 1], size=residuals.shape)
residuals_flipped = random_flips*residuals_norm
new_data = pred + residuals_flipped

for i in range(initial, n_iter+1):
    newPath = f'{dPath}/{i}'
    Path(newPath).mkdir(parents=True, exist_ok=True)

    random_flips = np.random.choice([-1, 1], size=residuals.shape)
    residuals_flipped = random_flips*residuals_norm
    new_data = pred + residuals_flipped

    export_nifti(new_data, data_hdr, newPath, 'data_b1k.nii.gz')


