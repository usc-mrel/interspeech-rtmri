MRD_FILE_PATH = 'h5/';
TRAJ_SEARCH_PATH = 'trajectory';
USC_DYNAMIC_RECON_TOOLBOX_PATH = '/server/home/pkumar/repos/usc_dynamic_reconstruction/';
ISMRMRD_PATH = '/server/home/pkumar/repos/ismrmrd/matlab/';

USE_GPU = 1; % if you don't have a GPU, disable.

addpath(USC_DYNAMIC_RECON_TOOLBOX_PATH)
addpath([USC_DYNAMIC_RECON_TOOLBOX_PATH, 'encoding']);
addpath([USC_DYNAMIC_RECON_TOOLBOX_PATH, 'optim']);
addpath([USC_DYNAMIC_RECON_TOOLBOX_PATH, 'utility']);
addpath(ISMRMRD_PATH);
addpath('thirdparty');

file_paths = dir(fullfile([MRD_FILE_PATH, '*.h5']));
nfile = length(file_paths);

for file_idx = [1:nfile]
     fprintf('File %d of %d\n', file_idx, length(file_paths));
     
     clearvars -except FOV MRD_FILE_PATH TRAJ_SEARCH_PATH file_paths file_idx USE_GPU
     
     %%% Solver Parameters
    weight_tTV = 0.1;                  % will be scaled by the SI

    Nmaxiter    = 150;                    % Max number of iterations
    Nlineiter   = 20;                     % Max number of it for Line Search
    betahow     = 'DY';                   % NCG Update Methods
    linesearch_how  = 'mm';        % Line Search Method

    ismrmrdfile = file_paths(file_idx).name;

    dset = ismrmrd.Dataset([MRD_FILE_PATH,ismrmrdfile]);
    header = ismrmrd.xml.deserialize(dset.readxml());
    raw_data    = dset.readAcquisition;

    disp('\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'); disp(' ');
    disp(['Reconstructing: ' header.measurementInformation.protocolName]); disp(' ');
    disp('\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'); disp(' ');

    fprintf('Retreiving k-space trajectory...');
    traj_path = fullfile(TRAJ_SEARCH_PATH, [header.userParameters.userParameterString(2).value, '.mat']);
    load(traj_path);
    fprintf('Done.\n');

    spatial_res = [param.spatial_resolution, param.spatial_resolution,8];
    matrix_size = param.matrix_size;

    % accumulate data
    for j = 1:length(raw_data.data)
        data(:,:,j) = raw_data.data{j};
    end

    % discard data
    data = data(param.pre_discard+1:end,:, :);
    data = single(data);
    nrep = size(data,3) / size(kx,2);

    % repeat kx, ky, kz as needed.
    kx = repmat(kx, [1, nrep]);
    ky = repmat(ky, [1, nrep]);

    % Trim TRS.
    TRToTrim = 150;
    data = data(:,:,TRToTrim+1:end);
    kx = kx(:,TRToTrim+1:end);
    ky = ky(:,TRToTrim+1:end); 

    % scale kx ky for rthawk
    kmax = max(abs(kx(:) + 1i * ky(:)));
    kx =  0.5 .* (kx / kmax);
    ky = 0.5 .* (ky / kmax);
    
    % construct kx, ky
    n_TRs = size(kx, 2);
    n_arms_per_frame = 2;
    n_read = size(kx, 1);
    
    n_frame = floor(n_TRs / n_arms_per_frame);
    n_coil = size(data, 2);

    kx = reshape(kx, n_read, n_arms_per_frame, n_frame);
    ky = reshape(ky, n_read, n_arms_per_frame, n_frame);
    kspace = reshape(data, n_read, n_coil, n_arms_per_frame, n_frame);
  
    kspace = kspace * 1000;
    kspace = permute(kspace, [1, 3, 4, 2]);
    
    % Encoding operator (using sqrt(w)).
    % TODO: re-do density compensation (it is bad!)
    rootw = sqrt(w');
    kspace = kspace .* rootw;
    kspace = gpuArray(kspace);
    E = Fnufft_2D(kx, ky, n_coil, matrix_size, USE_GPU, rootw, 1.5, [4, 4]);
    x0_ = E' * kspace;
    
    % sensitivity operator.
    sens = get_sens_map(x0_, '2D');
    C = C_2D(size(x0_), sens, USE_GPU);
    
    % --------- adjoint test on the operator C (optional). --------------------
    test_fatrix_adjoint(C);

    %% First Estimate to the solver, gridding + coil combination
    first_estimate = C' * x0_;
    scale = max(abs(first_estimate(:)));

    %% Regularization Operators

    % operators tfd and tv.
    T_tfd = TFD(size(first_estimate));
    T_tv = TV_2D(size(first_estimate));

    % --------- adjoint test on the operator TV (optional). -------------------
    test_fatrix_adjoint(T_tfd);
    test_fatrix_adjoint(T_tv);

    %% Define the L1 Approximation

    % Define potiential function as fair-l1.
    l1_func = potential_fun('fair-l1', 0.01);    % with delta  = 0.01

    %% Solver -> NCG 
    % need to define B, gradF, curvf, x0, niter, ninner, P, betahow, fun

    % -------------------------------------------------------------------------
    % prep for the NCG routine
    % -------------------------------------------------------------------------

    % Scale Regularization parameters
    lambdaTFD = weight_tTV * scale;

    % ----- Data Consistency Term Related -------------------------------------
    gradDC = @(x) x - kspace;
    curvDC = @(x) 1;

    % ------------------ TTV Term Related -------------------------------------
    gradTFD = @(x) lambdaTFD * l1_func.dpot(x);
    curvTFD = @(x) lambdaTFD * l1_func.wpot(x);

    % ------------------ Intermediate Step Cost -------------------------------
    costf = @(x,y) each_iter_fun(E, C, T_tfd, lambdaTFD, ...
                                 l1_func, kspace, x, y);

    % ------------- necessary for NCG routine ---------------------------------
    B = {E*C, T_tfd};
    gradF = {gradDC, gradTFD};
    curvF = {curvDC, curvTFD};

    %% Actual Solver Here
    tic
    %[x, out] = ncg_inv_mm(B, gradF, curvF, first_estimate, 200, 20, eye,'dai-yuan', costf);
    [x, out] = ncg(B, gradF, curvF, first_estimate, Nmaxiter, Nlineiter, eye, betahow, linesearch_how, costf);
    toc

    %% Display the Result
    img_recon = gather(x);
    img_recon = abs(flipud(img_recon));

    out = cell2mat(out);
    Cost = structArrayToStructWithArrays(out);
    
    save(['recon_out/', file_paths(file_idx).name(1:end-3), '.mat'], 'img_recon', 'Cost', 'header');
    
end

%% Helper Functions
% COST
function [struct] = each_iter_fun(F, C, T_tfd, lambdaTFD, l1_func, kspace, x, y)
    % added normalization
    N = numel(x);
    struct.fidelityNorm = (0.5 * (norm(vec(F * C * x - kspace))^2)) / N;
    struct.temporalNorm = sum(vec(lambdaTFD * l1_func.potk(T_tfd * x))) / N;
    struct.totalCost = struct.fidelityNorm + struct.temporalNorm;

end