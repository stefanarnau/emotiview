clear all;

% Path vars
path_emads_functions = '/home/plkn/repos/emotiview/functions_emad/';
path_eeg_in = '/mnt/data_dump/emotiview/1_markers_added_eeg/';
path_eeglab = '/home/plkn/eeglab2025.0.0/';
path_eeg_cleaned_continuous = '/mnt/data_dump/emotiview/2_cleaned_continuous_eeg/';

% Add to path
addpath(genpath(path_emads_functions));

% Create subpaths
PATH_ICA  = fullfile(path_eeg_cleaned_continuous, 'ICA_data');
PATH_PLOT = fullfile(path_eeg_cleaned_continuous, 'plots');
PATH_STAT = fullfile(path_eeg_cleaned_continuous, 'stats');

if ~exist(PATH_ICA,  'dir'); mkdir(PATH_ICA);  end
if ~exist(PATH_PLOT, 'dir'); mkdir(PATH_PLOT); end
if ~exist(PATH_STAT, 'dir'); mkdir(PATH_STAT); end

% Standard resources
chanLookupFile = fullfile(path_eeglab, 'plugins', 'dipfit', 'standard_BESA', 'standard-10-5-cap385.elp');
dipfitModel_PATH = fullfile(path_eeglab, 'plugins', 'dipfit', 'standard_BEM', 'standard_vol.mat');

% Output subfolders
PLOT_line     = fullfile(PATH_PLOT, 'line');
PLOT_analysis = fullfile(PATH_PLOT, 'analysis');
PLOT_amica    = fullfile(PATH_PLOT, 'amica');
STAT_analysis = fullfile(PATH_STAT, 'analysis');

% Create output folders if missing
cellfun(@(p) (exist(p,'dir') || mkdir(p)), ...
    {PATH_ICA, PATH_PLOT, PATH_STAT, PLOT_line, PLOT_analysis, PLOT_amica, STAT_analysis});

% Get file list
filePattern = fullfile(path_eeg_in, '*_markers_added.set');
files = dir(filePattern);

% Init eeglab
addpath(path_eeglab);
eeglab;

% Check if needed
eeglabroot = fileparts(which('eeglab'));
dipfitBEM  = fullfile(eeglabroot,'plugins','dipfit','standard_BEM');
addpath(dipfitBEM);rehash;

% Bad-channel detection parameters
chancorr_crit                   = 0.8;
chan_max_broken_time            = 0.3;
chan_detect_num_iter            = 10;
chan_detected_fraction_threshold= 0.5;
flatline_crit                   = 'off';
line_noise_crit                 = 'off';

% AMICA filter parameters
filter_lowCutoffFreqAMICA   = 1.5;
filter_AMICA_highPassOrder  = 1650;
filter_highCutoffFreqAMICA  = [];
filter_AMICA_lowPassOrder   = [];

% AMICA parameters
amica                       = true;
numb_models                 = 1;
AMICA_autoreject            = 1;
AMICA_n_rej                 = 10;
AMICA_reject_sigma_threshold= 3;
AMICA_max_iter              = 2000;
max_threads                 = 4;

% Iterate subjects
for iSub = 1 : numel(files)

    setName = files(iSub).name;
    UserNameSave = regexprep(setName, '_markers_added\.set$', '');

    % Load data
    EEG = pop_loadset( 'filename', setName, 'filepath', path_eeg_in);
    EEG.data = double(EEG.data);


    % Filter data
    EEG = pop_eegfiltnew(EEG, 'locutoff', 0.1, 'plotfreqz', 0);

    % Resample data
    EEG = pop_resample(EEG, 250);

    % Zapline
    EEG_clean = clean_data_with_zapline_plus_eeglab_wrapper(EEG);

    % Save zapline figure
    if ~isempty(get(groot,'CurrentFigure'))
        exportgraphics(gcf, fullfile(PLOT_line, [UserNameSave '.png']), 'Resolution', 300);
    end
    close all;

    %Bad channels: detect + save diagnostics
    chans_to_interp = bemobil_detect_bad_channels( ...
        EEG_clean, ALLEEG, CURRENTSET, ...
        chancorr_crit, chan_max_broken_time, chan_detect_num_iter, ...
        chan_detected_fraction_threshold, flatline_crit, line_noise_crit);

    save(fullfile(STAT_analysis, [UserNameSave '_chans2interp.mat']), 'chans_to_interp');

    if ~isempty(get(groot,'CurrentFigure'))
        exportgraphics(gcf, fullfile(PLOT_analysis, [UserNameSave '.png']), 'Resolution', 300);
    end
    close all;

    %Interpolate + average reference
    [ALLEEG, EEG_preprocessed, CURRENTSET] = bemobil_interp_avref(EEG_clean, ALLEEG, CURRENTSET, chans_to_interp);

    % Filter for AMICA
    out_filename = [];
    out_filepath = [];
    [ALLEEG, EEG_filtered, CURRENTSET] = bemobil_filter( ...
        ALLEEG, EEG_preprocessed, CURRENTSET, ...
        filter_lowCutoffFreqAMICA, filter_highCutoffFreqAMICA, ...
        out_filename, out_filepath, ...
        filter_AMICA_highPassOrder, filter_AMICA_lowPassOrder);

    % AMICA decomposition
    data_rank = EEG_filtered.nbchan - numel(EEG_filtered.etc.interpolated_channels);

    other_algorithm = [];
    out_filename = [];
    out_filepath = [];

    [ALLEEG, EEG_amica, CURRENTSET] = bemobil_signal_decomposition( ...
        ALLEEG, EEG_filtered, CURRENTSET, ...
        amica, numb_models, max_threads, data_rank, ...
        other_algorithm, out_filename, out_filepath, ...
        AMICA_autoreject, AMICA_n_rej, AMICA_reject_sigma_threshold, AMICA_max_iter);

    % Plot AMICA results

    % IC topographies
    nIC = size(EEG_amica.icawinv, 2);
    if nIC > 0
        pop_topoplot(EEG_amica, 0, 1:nIC, 'final_processed', [7 7], 0, 'electrodes', 'off');
        close all;
    end

    % Autorejection plot
    data2plot = EEG_amica.data(1:round(EEG_amica.nbchan/10):EEG_amica.nbchan, :)';
    figure('Color','w','Position', get(0,'screensize'));
    plot(data2plot, 'g'); hold on;
    data2plot(~EEG_amica.etc.bad_samples, :) = NaN;
    plot(data2plot, 'r');
    xlim([-10000 EEG_amica.pnts+10000]);
    ylim([-1000 1000]);
    title(sprintf('AMICA autorejection, removed %.2f%% of samples', EEG_amica.etc.bad_samples_percent));
    xlabel('Samples'); ylabel('\muV');

    exportgraphics(gcf, fullfile(PLOT_amica, ['amica' UserNameSave '.png']), 'Resolution', 300);
    close all;

    % DIPFIT
    RV_threshold       = 100;    % keep all ICs
    remove_outside_head= 'off';  % keep all ICs
    number_of_dipoles  = 1;

    [ALLEEG, EEG_dipfit, CURRENTSET] = bemobil_dipfit( ...
        EEG_amica, ALLEEG, CURRENTSET, [], ...
        RV_threshold, remove_outside_head, number_of_dipoles);

    % Copy filters back to preprocessed dataset
    fprintf('Copying spatial filter to full-length dataset...\n');
    [ALLEEG, EEG_AMICA_copied, CURRENTSET] = bemobil_copy_spatial_filter( ...
        EEG_preprocessed, ALLEEG, CURRENTSET, EEG_dipfit);

    % ICLabel + save
    EEG_AMICA_ICLabel = iclabel(EEG_AMICA_copied, 'default');

    EEG_AMICA_ICLabel = pop_saveset( ...
        EEG_AMICA_ICLabel, ...
        'filename', ['ICA_' UserNameSave '.set'], ...
        'filepath', PATH_ICA);

    close all;

end
