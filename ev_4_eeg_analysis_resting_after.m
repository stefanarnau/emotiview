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
            new_idx = length(EEG.event) + 1;
            EEG.event(new_idx).type = 'mid_resting';
            EEG.event(new_idx).code = 'neg';
            EEG.event(new_idx).latency = EEG.event(e).latency + 180 * EEG.srate;
        end

        % If start of neutral movie
        if EEG.event(e).code >= 4 & EEG.event(e).code <= 6
            counter = counter + 1;
            movies(counter, 1) = 2;
            movies(counter, 2) = EEG.event(e).latency;
            new_idx = length(EEG.event) + 1;
            EEG.event(new_idx).type = 'mid_resting';
            EEG.event(new_idx).code = 'neu';
            EEG.event(new_idx).latency = EEG.event(e).latency + 180 * EEG.srate;
        end

        % If start of positive movie
        if EEG.event(e).code >= 7 & EEG.event(e).code <= 9
            counter = counter + 1;
            movies(counter, 1) = 3;
            movies(counter, 2) = EEG.event(e).latency;
            new_idx = length(EEG.event) + 1;
            EEG.event(new_idx).type = 'mid_resting';
            EEG.event(new_idx).code = 'pos';
            EEG.event(new_idx).latency = EEG.event(e).latency + 180 * EEG.srate;
        end

    end

    % Check events
    EEG = eeg_checkset(EEG);

    % Epoch
    subject = subject_list{s};
    EEG = pop_epoch(EEG, {'mid_resting'}, [-45, 45], 'newname', [subject '_epoched'], 'epochinfo', 'yes');

    % Define channels of interest
    channel_labels = {'POz', 'F3', 'F4', 'Fz'};

    % Iterate channels
    for ch = 1 : length(channel_labels)

        % Do spectopo
        idx_chan = find(strcmpi({EEG.chanlocs.labels}, channel_labels{ch}));     
        freq_range = [1, 40];
        spectra_epochs = [];
        for e = 1 : EEG.trials
    
            data = squeeze(EEG.data(idx_chan, :, e));
    
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
            spectra(ch, s, t, :) = mean(spectra_epochs(type_idx, :), 1);
        end

    end

end

% Iterate channels for plotting
for ch = 1 : length(channel_labels) + 1



    if ch == length(channel_labels) + 1
        idx_f3 = find(strcmpi(channel_labels, 'F3'));
        idx_f4 = find(strcmpi(channel_labels, 'F4'));
        chanlab = 'FAA';

        spectra_chan = squeeze(spectra(idx_f4, :, :, :)) - squeeze(spectra(idx_f3, :, :, :));
    else
        chanlab = channel_labels{ch};
        spectra_chan = squeeze(spectra(ch, :, :, :));
    end

    n_subjects = size(spectra_chan, 1);
    colors = {'r','g','b'};
    figure()
    for subj = 1 : n_subjects
        
        subplot(2, 3, subj)
        hold on;
        
        idx_plot = freqs <= 25;
    
        for cond = 1 : 3
            pd = squeeze(spectra_chan(subj, cond, idx_plot));
            plot(freqs(idx_plot), pd, 'Color', colors{cond}, 'LineWidth', 2);
        end
        
        xlabel('Frequency (Hz)');
        ylabel('Power (\muV^2/Hz)');
        title([chanlab, ' - Subject ' num2str(subj)]);
        legend('neg','neu','pos');
        grid on;
        hold off;

    end
    
    subplot(2, 3, 6)
    hold on;
    
    idx_plot = freqs <= 25;
    
    for cond = 1 : 3
        pd = squeeze(mean(spectra_chan(:, cond, idx_plot), 1));
        plot(freqs(idx_plot), pd, 'Color', colors{cond}, 'LineWidth', 2);
    end
    
    xlabel('Frequency (Hz)');
    ylabel('Power (\muV^2/Hz)');
    title('Average ');
    legend('neg','neu','pos');
    grid on;
    hold off;

end