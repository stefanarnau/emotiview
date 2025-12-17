clear all;

% Path vars
path_in = '/mnt/data_dump/emotiview/0_raw/';
path_out = '/mnt/data_dump/emotiview/1_markers_added/';
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
event_counts = zeros(256, length(subject_list));

% Iterate subjects
for s = 1 : length(subject_list)

    % Current subject
    subject = subject_list{s};
    data_stats.id{s} = subject;

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

    % Count events
    for e = 1 : length(marker_stream.time_series)
        enum = str2double(marker_stream.time_series{e});
        if enum == 0
            enum = 256;
        end
        event_counts(enum, s) = event_counts(enum, s) + 1;
    end
    


end