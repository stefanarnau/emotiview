clear all;

% Path vars
path_in = '/mnt/data_dump/emotiview/1_markers_added/';
path_eeglab = '/home/plkn/eeglab2025.0.0/';

% Create subject list
subject_list = {'EV_002',...
                'EV_003',...
                'EV_004',...
                'EV_007',...
                'EV_008',...
                };

% Init eeglab
addpath(path_eeglab);
eeglab;

data_stats = table();
eeg_channels = table();

% Iterate subjects
for s = 1 : length(subject_list)

    % Current subject
    subject = subject_list{s};
    data_stats.id{s} = subject;

    % Save eeg dataset
    pop_loadset('filename', [subject, '_markers_added.set'], 'filepath', path_in);

    % prepro needed...

end