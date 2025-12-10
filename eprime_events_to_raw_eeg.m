clear all;

% Path vars
path_in = '/mnt/data_dump/emotiview/0_raw/';
path_out = '/mnt/data_dump/emotiview/1_markers_added/';
path_eeglab = '/home/plkn/eeglab2025.0.0/';

% Create subject list
subject_list = {'EV_001',...
                'EV_002',...
                'EV_003',...
                'EV_004',...
                'EV_007',...
                };

% Init eeglab
addpath(path_eeglab);
eeglab;

% Iterate subjects
for s = 1 : length(subject_list)

    % Current subject
    subject = subject_list{s};

    % Load events from eprime as table
    event_table = readtable([path_in, 'eprime_events_subject_', subject, '.csv']);

    % Load eeg data
    EEG = pop_loadxdf([path_in, subject, '.xdf']);

    % Use bisbas items as sync triggers
    sync_triggers = event_table.trigger_number(1 : 24);

    % Scan for first match
    for st_idx = 1 : length(sync_triggers)
        
        % Get bisbas triggernum
        sync_trigger = sync_triggers(st_idx);

        % Set flag
        match_found = 0;

        % Loop events
        e = 1;
        while str2num(EEG.event(e).type) ~= sync_trigger
            e = e + 1;
            if e == length(EEG.event)
                break;
            end
        end

        % Check if match obtained
        if str2num(EEG.event(e).type) == sync_trigger
             match_found = 1;
             break;
        end
    end

    % If no match found, abort.
    if match_found == 0
        error("no trigger for sync found :(");
    else

        % Save sync trigger
        EEG.sync_trigger = sync_trigger;

        % Get latencies
        eprime_latency = event_table.event_latency(st_idx);
        eeg_latency = EEG.event(e).latency;
    
        % Calculate offset
        eprime_offset = eeg_latency - eprime_latency;
    
        % Remove offset
        event_table.event_latency = event_table.event_latency + eprime_offset;
    
        % Create new events and replace
        new_events = struct();
        for e = 1 : size(event_table, 1)
            new_events(e).type = char(event_table.event_type(e));
            new_events(e).latency = event_table.event_latency(e);
            new_events(e).duration = 1;
        end
        EEG.event_original = EEG.event;
        EEG.event = new_events;
    
        % Save
        pop_saveset(EEG, 'filename', [subject, '_markers_added.set'], 'filepath', path_out);

    end
end