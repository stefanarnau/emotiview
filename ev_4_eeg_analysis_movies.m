% Get rid of stuff
clear all;

% Paths
path_in = '/mnt/data_dump/emotiview/2_cleaned_continuous_eeg/ICA_data/';
path_eeglab = '/home/plkn/eeglab2025.0.0/';
path_csd ='/home/plkn/CSDtoolbox/';

% Init eeglab and add csd toolbox
addpath(genpath(path_csd));
addpath(path_eeglab);
eeglab;

% datasets
subject_list = {'ICA_EV_002.set',...
                'ICA_EV_003.set',...
                'ICA_EV_004.set',...
                'ICA_EV_007.set',...
                'ICA_EV_008.set',...
                };

% Result vars
spectra = [];

% Loop
for s = 1 : length(subject_list)

    % Load
    EEG = pop_loadset('filename', subject_list{s}, 'filepath', path_in, 'loadmode', 'all');

    % Remove ICs
    EEG.nobrainer = find(EEG.etc.ic_classification.ICLabel.classifications(:, 3) > 0.3);
    EEG = pop_subcomp(EEG, EEG.nobrainer, 0);

    % Get movie events for epoch identification
    movies = [];
    counter = 0;

    % Iterate events
    for e = 1 : length(EEG.event)
        
        % If start of negative movie
        if EEG.event(e).code >= 1 & EEG.event(e).code <= 3
            counter = counter + 1;
            movies(counter, 1) = 1;
            movies(counter, 2) = EEG.event(e).latency;
            EEG.event(e).code = 'neg';
        end

        % If start of neutral movie
        if EEG.event(e).code >= 4 & EEG.event(e).code <= 6
            counter = counter + 1;
            movies(counter, 1) = 2;
            movies(counter, 2) = EEG.event(e).latency;
            EEG.event(e).code = 'neu';
        end

        % If start of positive movie
        if EEG.event(e).code >= 7 & EEG.event(e).code <= 9
            counter = counter + 1;
            movies(counter, 1) = 3;
            movies(counter, 2) = EEG.event(e).latency;
            EEG.event(e).code = 'pos';
        end

    end

    % Check events
    EEG = eeg_checkset(EEG);

    % Epoch
    subject = subject_list{s};
    EEG = pop_epoch(EEG, {'movie_start'}, [0, 120], 'newname', [subject '_epoched'], 'epochinfo', 'yes');

    % Frontolateral electrodes
    idx_f3 = find(strcmpi({EEG.chanlocs.labels}, 'F3'));
    idx_f4 = find(strcmpi({EEG.chanlocs.labels}, 'F4'));
    idx_f7 = find(strcmpi({EEG.chanlocs.labels}, 'F7'));
    idx_f8 = find(strcmpi({EEG.chanlocs.labels}, 'F8'));
    idx_fc3 = find(strcmpi({EEG.chanlocs.labels}, 'FC3'));
    idx_fc4 = find(strcmpi({EEG.chanlocs.labels}, 'FC4'));

    channels_for_spectra = {idx_f3, idx_f4, idx_f7, idx_f8, idx_fc3, idx_fc4};

    % Iterate channels
    for ch = 1 : length(channels_for_spectra)

        spectra_epochs = [];

        for e = 1 : EEG.trials
            data = squeeze(EEG.data(ch, :, e));
            nfft = EEG.srate * 4;  % e.g., 4-second window → 1000 points at Fs=250
            noverlap = nfft/2;     % 50% overlap
            
            [spectra_epochs(e, :), freqs] = spectopo(data, 0, EEG.srate, ...
                                         'freqrange', [0, 40], ...
                                         'winsize', nfft, ...
                                         'overlap', noverlap, ...
                                         'plot', 'off');
        end
    
        % Average within condition
        for t = 1 : 3
            type_idx = movies(:, 1) == t;
            spectra(s, ch, t, :) = mean(spectra_epochs(type_idx, :), 1);
        end
    end
end


% Compute lateralization
f43 = squeeze(spectra(:, 2, :, :)) - squeeze(spectra(:, 1, :, :));
f87 = squeeze(spectra(:, 4, :, :)) - squeeze(spectra(:, 3, :, :));
fc43 = squeeze(spectra(:, 6, :, :)) - squeeze(spectra(:, 5, :, :));

faa = (f43 + f87 + fc43) ./ 3;

n_subjects = size(faa, 1);
colors = {'r','g','b'};
figure()
for subj = 1 : n_subjects
    
    subplot(2, 3, subj)
    hold on;
    
    idx_plot = freqs <= 25;

    for cond = 1 : 3
        pd = squeeze(faa(subj, cond, idx_plot));
        plot(freqs(idx_plot), pd, 'Color', colors{cond}, 'LineWidth', 2);
    end
    
    xlabel('Frequency (Hz)');
    ylabel('Power (\muV^2/Hz)');
    title(['Subject ' num2str(subj)]);
    legend('neg','neu','pos');
    grid on;
    hold off;

end