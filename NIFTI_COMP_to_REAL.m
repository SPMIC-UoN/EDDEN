function  NIFTI_COMP_to_REAL(fn_magn_in,fn_phase_in,fn_out,ARG)
% fMRI
%  fn_magn_in='name.nii.gz';
%  fn_phase_in='name2.nii.gz';
%  fn_out=['REAL_' fn_magn_in(1:end-7)];
%  ARG.temporal_phase=1;
%  ARG.phase_filter_width=3;
%  NIFTI_NORDIC(fn_magn_in,fn_phase_in,fn_out,ARG)
%
%  The input structure is similar to NIFTI_NORDIC
%  (https://github.com/SteenMoeller/NORDIC_Raw/NIFTI_NORDIC.m) 
%  but no denoising is applied
%
%   The phase is adjusted to be close to flat. There will be signal in both
%   the imaginary and real channel, but the majority of the signal is
%   expected to be real valued
%
%  file_input assumes 4D data
%
%OPTIONS
%   ARG.DIROUT    VAL=      string        Default is empty
%   ARG.noise_volume_last   VAL  = num  specifiec volume from the end of the series
%                                          0 default
%
%   ARG.factor_error        val  = num    >1 use higher noisefloor <1 use lower noisefloor 
%                                          1 default 
%
%   ARG.full_dynamic_range  val = [ 0 1]   0 keep the input scale, output maximizes range. 
%                                            Default 0
%   ARG.temporal_phase      val = [1 2 3]  1 was default, 3 now in dMRI due tophase errors in some data
%   ARG.NORDIC              val = [0 1]    1 Default
%   ARG.MP                  val = [0 1 2]  1 NORDIC gfactor with MP estimation. 
%                                          2 MP without gfactor correction
%                                          0 default
%   ARG.kernel_size_gfactor val = [val1 val2 val], defautl is [14 14 1]
%   ARG.kernel_size_PCA     val = [val1 val2 val], default is val1=val2=val3; 
%                                                  ratio of 11:1 between spatial and temproal voxels
%   ARG.magnitude_only      val =[] or 1.  Using complex or magntiude only. Default is []
%                                          Function still needs two inputs but will ignore the second
%
%   ARG.save_add_info       val =[0 1];  If it is 1, then an additonal matlab file is being saved with degress removed etc.
%                                         default is 0
%   ARG.make_complex_nii    if the field exist, then the phase is being saved in a similar format as the input phase
%
%   ARG.phase_slice_average_for_kspace_centering     val = [0 1]   
%                                         if val =0, not used, if val=1 the series average pr slice is first removed
%                                         default is now 0
%   ARG.phase_filter_width  val = [1... 10]  Specifiec the width of the smoothing filter for the phase
%                                         default is now 3
%   
%   ARG.save_gfactor_map   val = [1 2].  1, saves the RELATIVE gfactor, 2 saves the
%                                            gfactor and does not complete the NORDIC processing


%  
%  VERSION 10/24/2023
%  Steen Moeller
%  moell018@umn.edu




if ~exist('ARG')  % initialize ARG structure
    ARG.DIROUT=[pwd '/'];
elseif ~isfield(ARG,'DIROUT') % Specify where to save data
    ARG.DIROUT=[pwd '/'];
end

if ~isfield(ARG,'noise_volume_last')
    ARG.noise_volume_last=0;  % there is no noise volume   {0 1 2 ...}
end

if ~isfield(ARG,'factor_error')
    ARG.factor_error=1.0;  % error in gfactor estimatetion. >1 use higher noisefloor <1 use lower noisefloor
end

if ~isfield(ARG,'full_dynamic_range')
    ARG.full_dynamic_range=0;  % Format o
end

if ~isfield(ARG,'temporal_phase')
    ARG.temporal_phase=1;  % Correction for slice and time-specific phase
end

if ~isfield(ARG,'NORDIC') & ~isfield(ARG,'MP')
    ARG.NORDIC=1;  %  threshold based on Noise
    ARG.MP=0;  % threshold based on Marchencko-Pastur
elseif ~isfield(ARG,'NORDIC') %  MP selected
    if ARG.MP==1
        ARG.NORDIC=0;
    else
        ARG.NORDIC=1;
    end
    
elseif  ~isfield(ARG,'MP')   %  NORDIC selected
    if ARG.NORDIC==1
        ARG.MP=0;
    else
        ARG.MP=1;
    end
end

if ~isfield(ARG,'phase_filter_width')
    ARG.phase_filter_width=3;  %  default is [14 14 90]
end


if ~isfield(ARG,'NORDIC_patch_overlap')
    ARG.NORDIC_patch_overlap=2;  %  default is [14 14 90]
end

if ~isfield(ARG,'gfactor_patch_overlap')
    ARG.gfactor_patch_overlap=2;  %  default is [14 14 90]
end


if ~isfield(ARG,'kernel_size_gfactor')
    ARG.kernel_size_gfactor=[];  %  default is [14 14 90]
end

if ~isfield(ARG,'kernel_size_PCA')
    ARG.kernel_size_PCA=[]; % default is 11:1 ratio
end

if ~isfield(ARG,'phase_slice_average_for_kspace_centering');
ARG.phase_slice_average_for_kspace_centering=0;
end

if ~isfield(ARG,'magnitude_only') % if legacy data
    ARG.magnitude_only=0; %
end

if isfield(ARG,'save_add_info'); end   %  additional information is saved in matlab file
if isfield(ARG,'make_complex_nii'); end   %  two output NII files are saved

if ~isfield(ARG,'save_gfactor_map') % save out a map of a relative gfactor
    ARG.save_gfactor_map=[]; %
end


if isfield(ARG,'use_generic_NII_read') % save out a map of a relative gfactor
    if ARG.use_generic_NII_read==1
    path(path,'/home/range6-raid1/moeller/matlab/ADD/NIFTI/');
    end
else
    ARG.use_generic_NII_read=0;
end

if ~isfield(ARG,'data_has_zero_elements') %
    ARG.data_has_zero_elements=0; %  % If there are pixels that are constant zero
end


if ~isfield(ARG,'linear_drift') %
    ARG.linear_drift=0; %  % If there are pixels that are constant zero
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  Let us load the NIFTI data into matlab
if ARG.magnitude_only~=1

    try
    info_phase=niftiinfo(fn_phase_in);
    info=niftiinfo(fn_magn_in);
    catch;  disp('The niftiinfo fails at reading the header')  ;end
    
    
    if ARG.use_generic_NII_read~=1
        I_M=abs(single(niftiread(fn_magn_in)));
        I_P=single(niftiread(fn_phase_in));
    else
        try
        tmp=load_nii(fn_magn_in);
        I_M=abs(single(tmp.img));
        tmp=load_nii(fn_phase_in);
        I_P=single(tmp.img);
        catch
           disp('Missing nfiti tool. Serach mathworks for load_nii  fileexchange 8797') 
        end
        
    end
    
    phase_range=single(max(I_P(:)));
    phase_range_min=single(min(I_P(:)));
if ~exist('info_phase')    
    info_phase.Datatype=class(I_P);
    info.Datatype=class(I_M);
end


I_P = single(I_P);
            range_norm=phase_range-phase_range_min;
            range_center=(phase_range+phase_range_min)/range_norm*1/2;
            I_P = (single(I_P)./range_norm -range_center)*2*pi;
            II=single(I_M)  .* exp(1i*I_P);       

		% Here, we combine magnitude and phase data into complex form 
        fprintf('Phase should be -pi to pi...\n')
 
        fprintf('Phase data range is %.2f to %.2f\n', min(I_P(:)), max(I_P(:)))
else
    
     try
     info=niftiinfo(fn_magn_in);
    catch;  disp('The niftiinfo fails at reading the header')  ;end
 
    
    if ARG.use_generic_NII_read~=1
        I_M=abs(single(niftiread(fn_magn_in)));
    else
        tmp=load_nii(fn_magn_in);
        I_M=abs(single(tmp.img));
    end
    
    
if ~exist('info_phase')    
     info.Datatype=class(I_M);
end

end 



if ~isempty(ARG.magnitude_only)
    if ARG.magnitude_only==1
        II=single(I_M);
        ARG.temporal_phase=0;
    end
end

%%%%%%  FINISHED loading the data and organizing them as eitehr real or
%%%%%%  complex valued signals

TEMPVOL=abs(II(:,:,:,1));
ARG.ABSOLUTE_SCALE=min(TEMPVOL(TEMPVOL~=0));
II=II./ARG.ABSOLUTE_SCALE;


if size(II,4)<6
    disp('Too few volumes')
    % return
end

KSP2=II;
matdim=size(KSP2);

tt=mean(reshape(abs(KSP2),[],size(KSP2,4)));
[idx]=find(tt>0.95*max(tt));

%%%  estimate of unfiltered "static" phase

meanphase=mean(KSP2(:,:,:,idx(1)),4);


%%% REMOVE estimate of unfiltered "static" phase

for slice=matdim(3):-1:1
    for n=1:size(KSP2,4); % include the noise
        KSP2(:,:,slice,n)=KSP2(:,:,slice,n).*exp(-i*angle(meanphase(:,:,slice)));
    end
end
DD_phase=0*KSP2;
%%% estimate of "dynamic" residual filtered phase

if           ARG.temporal_phase>0; % Standard low-pass filtered map
    for slice=matdim(3):-1:1
        for n=1:size(KSP2,4);
            tmp=KSP2(:,:,slice,n);
            for ndim=[1:2]; tmp=ifftshift(ifft(ifftshift( tmp ,ndim),[],ndim),ndim+0); end
            [nx, ny, nc, nb] = size(tmp(:,:,:,:,1,1));
            tmp = bsxfun(@times,tmp,reshape(tukeywin(ny,1).^ARG.phase_filter_width,[1 ny]));
            tmp = bsxfun(@times,tmp,reshape(tukeywin(nx,1).^ARG.phase_filter_width,[nx 1]));
            for ndim=[1:2]; tmp=fftshift(fft(fftshift( tmp ,ndim),[],ndim),ndim+0); end
            DD_phase(:,:,slice,n)=tmp;
        end
    end
end

%%% REMOVE estimate of "dynamic" residual filtered phase

for slice=matdim(3):-1:1
    for n=1:size(KSP2,4);
        KSP2(:,:,slice,n)= KSP2(:,:,slice,n).*exp(-i*angle( DD_phase(:,:,slice,n)   ));
    end
end


%%%  SAVE the data as new nifti files

IMG2=KSP2;

IMG2=IMG2.*ARG.ABSOLUTE_SCALE;
info.Datatype='single';
IMG2(isnan(IMG2))=0;
if 1  %pick the real part
    IMG2=real(IMG2(:,:,:,1:end)); % remove g-factor and noise for DUAL 1
    IMG2(isnan(IMG2))=0;
    tmp=sort(abs(IMG2(:)));  sn_scale=2*tmp(round(0.99*end));%sn_scale=max();
    gain_level=floor(log2(32000/sn_scale));
    
    if  ARG.full_dynamic_range==0; gain_level=0;end
    
    IMG2= single((IMG2)*2^gain_level);

    if ARG.use_generic_NII_read==0;
    niftiwrite((IMG2),[ARG.DIROUT fn_out(1:end) '.nii'],info)
    else
     nii=make_nii(IMG2);   
     save_nii(nii, [ARG.DIROUT fn_out(1:end) '.nii'])
    end
end




return





