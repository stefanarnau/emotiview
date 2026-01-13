% Get rid of stuff
clear all;

% Paths
path_in = '/mnt/data_dump/emotiview/2_cleaned_continuous_eeg/ICA_data/';

% datasets
subject_list = {'ICA_EV_002.set',...
                'ICA_EV_002.set',...
                'ICA_EV_002.set',...
                'ICA_EV_002.set',...
                'ICA_EV_002.set',...
                };

% Loop
for s = 1 : length(subject_list)

    % Load
    EEG = pop_loadset('filename', subject_list{s}, 'filepath', path_in, 'loadmode', 'all');

    % Remove ICs
    EEG.nobrainer = find(EEG.etc.ic_classification.ICLabel.classifications(:, 3) > 0.3);
    EEG = pop_subcomp(EEG, EEG.nobrainer, 0);

    aa=bb

    % Epoch
    %EEG = pop_epoch(EEG, {'movie_start'}, [120, ], 'newname', [subject '_epoched'], 'epochinfo', 'yes');





end