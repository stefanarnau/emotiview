clear all;

% Path vars
path_in = '/mnt/data_dump/emotiview/0_raw/';
path_eeg_out = '/mnt/data_dump/emotiview/1_markers_added/';
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

    % Load events from eprime as table
    events_eprime = readtable([path_in, 'eprime_events_subject_', subject, '.csv']);

    % Load (LSL) streams
    lsl_streams = load_xdf([path_in, subject, '.xdf']);

    % Search marker stream
    strm = 1;
    while isempty(lsl_streams{strm}.time_series) | ~strcmp(lsl_streams{strm}.info.name, 'BrainAmpSeries-1-Markers')
        strm = strm + 1;
    end
    marker_stream = lsl_streams{strm};

    data_stats.marker_stream_nr(s) = strm;
    data_stats.number_of_markers(s) = length(marker_stream.time_series);

    % Search EEG stream
    strm = 1;
    while isempty(lsl_streams{strm}.time_series) | ~strcmp(lsl_streams{strm}.info.name, 'BrainAmpSeries-1')
        strm = strm + 1;
    end
    eeg_stream = lsl_streams{strm};

    data_stats.eeg_stream_nr(s) = strm;
    data_stats.nchan_eeg_stream(s) = size(eeg_stream.time_series, 1);

    % Search NIRS stream
    strm = 1;
    while isempty(lsl_streams{strm}.time_series) | ~strcmp(lsl_streams{strm}.info.name, 'NIRStar')
        strm = strm + 1;
    end
    nirs_stream = lsl_streams{strm};

    data_stats.nirs_stream_nr(s) = strm;
    data_stats.nchan_nirs_stream(s) = size(nirs_stream.time_series, 1);

    % Get EEG channels
    for ch = 1 : numel(eeg_stream.info.desc.channels.channel)
        tmp = eeg_stream.info.desc.channels.channel(ch);
        eeg_channels.(subject){ch} = tmp{1}.label;
    end

    % Get list of events in lsl
    events_lsl = table();
    ecount = 0;
    for e = 1 : length(marker_stream.time_series)
        
        % Event number
        enum = str2double(marker_stream.time_series{e});

        % Skip zeros
        if enum == 0
            continue;
        end

        % label event
        ecount = ecount + 1;
        etype = '---';
        if enum >= 121 & enum <= 144
            etype = 'bisbas';
        end
        if enum >= 151 & enum <= 170
            etype = 'panas';
        end
        if enum == 171 & enum <= 172
            etype = 'sam';
        end
        if enum >= 181 & enum <= 191
            etype = 'ea11';
        end
        if enum >= 200 & enum <= 206
            etype = 'ea7';
        end
        if enum >= 1 & enum <= 9
            etype = 'movie';
        end
        if enum == 40
            etype = 'rest1';
        end
        if enum == 50
            etype = 'rest2';
        end
        if enum == 254
            etype = 'exstart';
        end
        if enum == 255
            etype = 'exend';
        end

        % Fill table
        events_lsl.enum(ecount) = enum;
        events_lsl.etype{ecount} = etype;
        events_lsl.latency(ecount) = marker_stream.time_stamps(e);

    end



    % Scan for match using bisbas items as sync triggers
    for sync_trigger = 121 : 144
    
        % Set flag
        match_found = 0;

        % Loop events
        e = 1;
        while events_lsl.enum(e) ~= sync_trigger
            e = e + 1;
            if e == height(events_lsl)
                break;
            end
        end

        % Check if match obtained
        if events_lsl.enum(e) == sync_trigger
             match_found = 1;
             sync_latency_lsl = events_lsl.latency(e);
             break;
        end
    end
    
    % If no match found, abort.
    if match_found == 0
        error("no trigger for sync found :(");
    else

        % Get sync trigger latency for eprime
        sync_latency_eprime = events_eprime.event_latency(find(events_eprime.trigger_number == sync_trigger));

        % Calculate offset
        sync_offset = sync_latency_lsl - sync_latency_eprime;
    
        % Remove offset
        events_eprime.event_latency = events_eprime.event_latency + sync_offset;

        % Collect EEG channels
        non_eeg = {'PB1', 'PB2', 'PB3', 'PB4', 'PB5', 'PPG', 'EDA', 'EKG', 'triggerStream'};
        channel_labels = {};
        idx_eeg = [];
        for ch = 1 : numel(eeg_stream.info.desc.channels.channel)

            % Get channel label
            tmp = eeg_stream.info.desc.channels.channel(ch);
            chanlabel = tmp{1}.label;

            % If non-eeg
            if ismember(chanlabel, non_eeg)

                if strcmp(chanlabel, 'PPG')
                    idx_ppg = [];
                elseif strcmp(chanlabel, 'EDA')
                    idx_eda = [];
                elseif strcmp(chanlabel, 'EKG')
                    idx_ecg = [];
                end

            % If eeg
            else
                channel_labels{end + 1} = chanlabel;
                idx_eeg(end + 1) = ch;
            end
        end

        % Get eegdata
        eeg_data = double(eeg_stream.time_series(idx_eeg, :));

        % Create EEGlab struct
        EEG = eeg_emptyset;
        EEG.data    = eeg_data;                
        EEG.nbchan  = size(eeg_data,1);
        EEG.pnts    = size(eeg_data,2);
        EEG.trials  = 1;                     
        EEG.srate   = 1000;                   
        EEG.xmin    = 0;
        EEG.xmax    = (EEG.pnts - 1) / EEG.srate;
        EEG.setname = 'emotoview_eeg';
        EEG.chanlocs = struct('labels', channel_labels);
        EEG.event = struct([]);
        EEG.trialinfo = events_eprime;
        EEG.saved = 'no';

        % Collect events
        for e = 1 : height(events_eprime)
            EEG.event(e).type    = events_eprime.event_type{e}; 
            EEG.event(e).latency = events_eprime.event_latency(e);
            EEG.event(e).code = events_eprime.trigger_number(e);
        end

        % Check integrity
        EEG = eeg_checkset(EEG, 'eventconsistency');

        % Add channel locations
        EEG = pop_chanedit(EEG, 'lookup', 'standard-10-5-cap385.elp');

        % Save eeg dataset
        pop_saveset(EEG, 'filename', [subject, '_markers_added.set'], 'filepath', path_eeg_out);

    end
end