def get_data(file, mmap=True):
    """
    Load NIfTI image data from a file.

    Parameters:
        file (str): The path to the NIfTI file.
        mmap (bool, optional): Whether to use memory-mapped file access. Default is True.

    Returns:
        numpy.ndarray: The voxel data from the NIfTI file.
    """
    import nibabel as nb
    img = nb.load(file, mmap=mmap)
    img_voxels = img.get_fdata()
    return img_voxels


def export_nifti(data, orig_data, output_path, name):
    """
    Export data as a NIfTI file with the header of the original image.

    Parameters:
        data (numpy.ndarray): The data to be saved in the NIfTI file.
        orig_data (nibabel.Nifti1Image): The original NIfTI image whose header is to be copied.
        output_path (str): The directory where the NIfTI file will be saved.
        name (str): The name of the output NIfTI file.

    Returns:
        None
    """
    import nibabel as nb
    import os
    # Copy the header of the original image
    aff_mat = orig_data.affine
    nb.save(nb.Nifti2Image(data, affine=aff_mat), os.path.join(output_path, name))


def read_residuals(filePath):
    """
    Read residuals and volume resels from a text file.

    Parameters:
        filePath (str): The path to the text file.

    Returns:
        tuple: A tuple containing two values: 
            - res (list of float): List of residuals (FWHMmm).
            - volResel (float): Volume resels (RESELS).
    """
    with open(filePath, 'r') as file:
        for line in file:
            if line.startswith('FWHMmm'):
                res = [float(num) for num in line.strip().split()[1:4]]
            if line.startswith('RESELS'):
                volResel = float(line.strip().split()[1:][0])
            
    return res, volResel


def make_plotgrid(colnames, ylabels, list_colors, suptitle=None, no_ticks=True, equal_aspect=True):
    """
    Creates a grid of subplots with the specified column names and y-axis labels.

    Parameters:
    colnames (list): List of strings containing the column names for each subplot
    ylabels (list): List of strings containing the y-axis labels for each subplot
    suptitle (str): Title for the entire figure
    no_ticks (bool): True if ticks should be removed from all subplots
    equal_aspect (bool): True if all subplots should have equal aspect ratio

    Returns:
    fig (Figure): The generated figure
    axes (ndarray): Array of axes objects for each subplot
    """

    import matplotlib.pyplot as plt
    
    #if colnames is not None:
    ncols = len(colnames)
    nrows = len(ylabels)
    fig, axes = plt.subplots(nrows=nrows, ncols=ncols, figsize=(7*ncols, 7*nrows))
    
    for i, title in enumerate(colnames):
        axes[0,i].set_title(title, fontweight='bold', size=fig.dpi*0.5, color=list_colors[i])    # Size of titles in function of the figsize
    
    for i, ylabel in enumerate(ylabels):
        #axes[i,0].set_ylabel(f'b={ylabel}($s^2$/mm)', fontweight='bold', size=fig.dpi*0.3)
        axes[i,0].set_ylabel(f'{ylabel}', fontweight='bold', size=fig.dpi*0.3)
        
    axes_list = axes.flatten()
    if equal_aspect:
        for i, ax in enumerate(axes_list):
            ax.set_aspect('equal')

    if no_ticks:
        plt.setp(plt.gcf().get_axes(), xticks=[], yticks=[])    # Remove ticks on all axis in all subplots

    if suptitle:    
        plt.suptitle(suptitle, fontweight='bold', size=fig.dpi*0.4)
    
    
    #plt.subplots_adjust(wspace=0, hspace=0)#, left=0.05, right=1, bottom=0, top=1)  
    #fig.subplots_adjust(wspace=0, hspace=0, top=0.8, bottom=0.2, left=0.2, right=0.8)
    
    # Calculate necessary spacing
    left = 0.1 + 0.1 * (ylabels is not None)
    top = 0.8 - 0.1 * (colnames is not None)
    right = 0.8 - 0.1 * (colnames is not None)
    bottom = 0.2 + 0.1 * (ylabels is not None)
    # Adjust spacing to make room for titles and labels
    fig.subplots_adjust(left=left, bottom=bottom, right=right, top=top)

    fig.tight_layout()

    return fig, axes


def set_axis_style(ax, labels, fontsize=10):
    """
    Set the style of the axis ticks and labels.

    Parameters:
        ax (matplotlib.axes.Axes): The axis for which to set the style.
        labels (list of str): Labels to be shown on the x-axis.
        fontsize (int, optional): Font size for the tick labels. Default is 10.

    Returns:
        None
    """
    import numpy as np
    ax.get_xaxis().set_tick_params(direction='out')
    ax.xaxis.set_ticks_position('bottom')
    ax.set_xticks(np.arange(1, len(labels) + 1))
    ax.set_xticklabels(labels, fontsize=fontsize, fontweight='bold')
    ax.set_xlim(0.25, len(labels) + 0.75)


def rearrange_signal(signal, v1, bvecs, bvals):
    """
    Re-arranging - rearranging of datapoints based on the DTI v1 in each voxel so that you can get the plots with the rectified signal . 
    If used to compared across images, it asssumes that all voxels are aligned (i.e. voxel A is the same across all of them)
    Keep in mind that b=0 volumes can have a non-zero bvec entry, so when rearranging put all b=0s in the beginning (proper scaling needed for comparisons) or remove them.
    If they appear a bit flat it may be reflecting borderline voxels here with a lot of CSF partial volume —> you can choose voxel not based on orientation, but based on high FA values (e.g. in the CC).

    Inputs:
    raw data
    bvecs
    a vector image file that shows what is the main fibre orientation in each voxel (e.g. DTI v1)
    a mask (either a brain mask for whole brain or a mask choosing specific few voxels e.g., in the CC)

    Output:
    a data file (same dimensions as the input), but the volumes in every voxel (contained the mask) rearranged not according to acquisition bevcs, but according to the dot ptoduct between bvecs ad v1 in that voxel

    """
    import numpy as np

    b0_idx = np.argwhere(bvals<200)
    data_aux = np.delete(signal, b0_idx)
    bvecs_aux = np.delete(bvecs, b0_idx, axis=1)
    dotprod = np.abs(bvecs_aux.T @ v1)
    idx = np.argsort(dotprod)[::-1]# np.concatenate([np.array(b0_idx), np.argsort(dotprod)[::-1]]) # Sort them in descending order, keeping the b0 vols first
    s_rearranged = signal[b0_idx].ravel()
    s_rearranged = np.concatenate((s_rearranged, data_aux[idx]))
    return s_rearranged#, np.concatenate((b0_idx.ravel(),idx.ravel()))

def smooth(a,WSZ):
    """
    Smooth a 1-D array using a moving average.

    Parameters:
        a (numpy.ndarray): 1-D array containing the data to be smoothed.
        WSZ (int): Smoothing window size, must be an odd number.

    Returns:
        numpy.ndarray: Smoothed array.
    """
    # a: NumPy 1-D array containing the data to be smoothed
    # WSZ: smoothing window size needs, which must be odd number,
    # as in the original MATLAB implementation
    import numpy as np
    out0 = np.convolve(a,np.ones(WSZ,dtype=int),'valid')/WSZ    
    r = np.arange(1,WSZ-1,2)
    start = np.cumsum(a[:WSZ-1])[::2]/r
    stop = (np.cumsum(a[:-WSZ:-1])[::2]/r)[::-1]
    return np.concatenate((  start , out0, stop  ))

def localize_highFA(FA_map, mask, nvoxels):
    """
    Localize the highest FA values within a masked FA map.

    Parameters:
        FA_map (numpy.ndarray): Fractional Anisotropy (FA) map.
        mask (numpy.ndarray): Mask to apply to the FA map.
        nvoxels (int): Number of highest FA values to localize.

    Returns:
        numpy.ndarray: Coordinates of the nvoxels highest FA values.
    """
    import numpy as np
    FA_masked = np.multiply(FA_map, mask)
    FA_masked1d = FA_masked.flatten()
    idx_1d = FA_masked1d.argsort()[-nvoxels:] # Take the nvoxels highest FA values
    coords = np.array(np.unravel_index(idx_1d, FA_masked.shape))
    return coords


def get_tractCorr(tract1, tract2, mask='and', thr = 0.05):
    """
    Calculate the correlation between two tracts.

    Parameters:
        tract1 (numpy.ndarray): First tract data.
        tract2 (numpy.ndarray): Second tract data.
        mask (str, optional): Masking strategy ('thr', 'and', 'tract1'). Default is 'and'.
        thr (float, optional): Threshold value for masking. Default is 0.05.

    Returns:
        float: Pearson correlation coefficient between the two tracts.
    """
    import numpy as np
    from scipy import stats
    if mask=='thr':
        tract1 = tract1[tract1 > thr]
        tract2 = tract2[tract2 > thr]
    elif mask=='and':
        mask = np.logical_and(tract1 > thr, tract2 > thr) #Union mask
        tract1 = tract1[mask > thr]
        tract2 = tract2[mask > thr]
    elif mask=='tract1':
        mask = tract1 > thr
        tract1 = np.where(mask, tract1, 0)
        tract2 = np.where(mask, tract2, 0)   

    r, p = stats.pearsonr(tract1.ravel(), tract2.ravel())
    if p<0.001:
        corr = r
    else:
        corr = 0
    return corr

def get_missingTracts(dPath, list_tracts=None):
    """
    Get information about missing or reconstructed tracts.

    Parameters:
        dPath (str): Path to the xtract folder.
        list_tracts (list of str, optional): List of tract names. Default is None.

    Returns:
        list: A list containing information about each tract's reconstruction status.
    """
    '''
    dPath = xtract folder
    list_tracts = list with all the tract names, as in the folder containing the tract following the BIDS convention
    '''
    import numpy as np
    from pathlib import Path

    thr = 0.005
    if thr==0.005:
        atlasPath = f'{CODEDIR}/Atlases/HCP_tracts_5'
        atlasPath = '/home/data/Denoising/data/Dataset_B/rep1/AVG_complex/analysis/dMRI/processed/xtract/tracts'
    else:
        atlasPath = f'{CODEDIR}/Atlases/HCP_tracts_1'
    if list_tracts is None:
        list_tracts = []
        with open(f'{CODEDIR}/list_tracts.txt', 'r') as fileobj:
            [ list_tracts.append(row.rstrip('\n')) for row in fileobj ]

    #combinations = [np.array([len(list_methods) * [i] for i in list_res]).ravel().tolist(), len(list_res) * list_methods]
    #missing_tracts = pd.DataFrame(np.zeros((len(list_tracts), len(combinations[0]))), index=list_tracts, columns=combinations)
    recon_tract = []
    tractsCorr = []
    for t in list_tracts:
        tract_file = f'{dPath}/xtract/tracts/{t}/densityNorm.nii.gz'
        if Path(tract_file).exists():
            tract_aux = get_data(tract_file)
            if np.sum(tract_aux.ravel()) > 0:
                recon_tract.append(1)
                #atlasTract = get_data(f'{atlasPath}/{t}.nii.gz')
                atlasTract = get_data(f'{atlasPath}/{t}/densityNorm.nii.gz')
                tractsCorr.append( get_tractCorr(atlasTract, tract_aux, mask='tract1', thr = thr) )
            else:
                recon_tract.append(0)  # file exists but tract is not reconstructed
                tractsCorr.append(0)
        else:
            recon_tract.append(-1)  #missing file
            tractsCorr.append(0)
        
    return recon_tract, tractsCorr