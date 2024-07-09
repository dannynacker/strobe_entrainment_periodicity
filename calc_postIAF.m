%% This script:
% 1. epochs pre-stimulation data for calculating post-exp IAF 
% 2. performs an FFT on this data 

%% Initialization 

addpath("E:\final_experiment\eeglab2024.0")
addpath("E:\final_experiment\erplab10.1")

% Load EEGLab
eeglab;

% Load CNT data (individual for now, loop over multiple files later)
filename = '.cnt';
EEG = pop_loadeep_v4("E:\" + filename);

%% Epoch based off of trial/condition

% Map start codes to trial names
% Add all trials/conditions once better piloting allows
start_code_map = containers.Map({'0101'}, ...
                                {'preIAF'});

% Epoching
start_codes = keys(start_code_map);
end_code = '0127'; % Ensure this is a string or else EEG.comment freaks out

% Debugging: Print out all event types and latencies
for i = 1:length(EEG.event)
    fprintf('Event %d: Type = %s, Latency = %d\n', i, EEG.event(i).type, EEG.event(i).latency);
end

% Initialize an empty array to store epochs and start codes
epoch_events = [];
epoch_boundaries = [];
epoch_start_codes = {}; % Cell array to store start codes for each epoch

% Loop through the events to find start and end code pairs
for i = 1:length(EEG.event)
    if ismember(EEG.event(i).type, start_codes)
        for j = i+1:length(EEG.event)
            if strcmp(EEG.event(j).type, end_code)
                epoch_events = [epoch_events; EEG.event(i).type];
                epoch_boundaries = [epoch_boundaries; [EEG.event(i).latency, EEG.event(j).latency]];
                epoch_start_codes{end+1} = start_code_map(EEG.event(i).type); % Store the trial name
                break;
            end
        end
    end
end

% Debugging: Print identified epoch boundaries in case EEG.comments keeps
% freaking out
fprintf('Identified %d epochs\n', size(epoch_boundaries, 1));
for i = 1:size(epoch_boundaries, 1)
    fprintf('Epoch %d: Start = %d, End = %d, Start Code = %s\n', i, epoch_boundaries(i, 1), epoch_boundaries(i, 2), epoch_start_codes{i});
end

% Create epochs based on the identified start and end pairs
num_epochs = size(epoch_boundaries, 1);
epoch_data = cell(1, num_epochs);

for i = 1:num_epochs
    start_sample = round(epoch_boundaries(i, 1));
    end_sample = round(epoch_boundaries(i, 2));
    epoch_data{i} = EEG.data(:, start_sample:end_sample);
end

% Combine all epochs into a 3D matrix
max_epoch_length = max(cellfun(@(x) size(x, 2), epoch_data));
epoch_matrix = zeros(size(EEG.data, 1), max_epoch_length, num_epochs);

for i = 1:num_epochs
    epoch_length = size(epoch_data{i}, 2);
    epoch_matrix(:, 1:epoch_length, i) = epoch_data{i};
end

% Create a new EEG structure with the epoched data
EEG_epoch = EEG;
EEG_epoch.data = epoch_matrix;
EEG_epoch.pnts = max_epoch_length;
EEG_epoch.trials = num_epochs;
EEG_epoch.event = []; % Clear events
EEG_epoch.epoch = []; % Clear epochs
EEG_epoch.urevent = []; % Clear urevents
EEG_epoch.xmin = 0;
EEG_epoch.xmax = (max_epoch_length - 1) / EEG.srate;

% Ensure times field is set correctly
if num_epochs > 0
    EEG_epoch.times = linspace(EEG_epoch.xmin, EEG_epoch.xmax, EEG_epoch.pnts);
else
    EEG_epoch.times = [];
end

% Save the new epoched dataset
EEG_epoch = eeg_checkset(EEG_epoch);
pop_saveset(EEG_epoch, 'filename', 'epoched_data.set');

%% Perform FFT on the epoched data

% FFT parameters
channels_to_analyze = 'Oz'; % Channels to analyze
start_freq = 5; % Start frequency in Hz
end_freq = 30; % End frequency in Hz

% Perform FFT
pop_fourieeg(EEG_epoch, channels_to_analyze, [], 'StartFrequency', start_freq, 'EndFrequency', end_freq);

% Get the FFT plot data
c = get(gca, 'Children');
XData = get(c, 'XData');
YData = get(c, 'YData');
hz = XData(YData==max(YData(:)));

% Print the peak frequency
fprintf('Peak frequency: %.2f Hz\n', hz);

%% ++++++++++++++++++++++++++++++++++++++ %%


