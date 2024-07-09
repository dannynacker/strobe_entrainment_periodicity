%% This script processes the pilot data in line with the analysis pipeline outlined in our pre-registration. It:

% 1. loads the CNT file
% 2. downsamples to 250Hz
% 3. high-pass cut off of 1Hz
% 4. low-pass cut off of 30Hz
% 5. applies standard channel locations
% 6. CleanLine plugin for baseline drift
% 7. removes bad channels with clean_rawdata
% 8. Interpolates bad channels
% 9. removes artefacts with ICLabel and MARA
% 10. maps conditions onto trigger start codes
% 11. epochs data into conditions via trigger codes

%% *** This will need to average and loop over multiple .cnt files in the future. *** %%

%% Start 

% Load EEGLab
eeglab;

% Load the .cnt file
EEG = pop_loadeep_v4("E:\");

%% Epochs per Condition

% Map start codes to trial names
start_code_map = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8'}, ...
                                {'8Hz Periodic', '10Hz Periodic', '14Hz Periodic', 'IAFHz Periodic', '8Hz Aperiodic', '10Hz Aperiodic', '14Hz Aperiodic', 'IAFHz Aperiodic'});

% Debugging: Print out all event types and latencies
for i = 1:length(EEG.event)
    fprintf('Event %d: Type = %s, Latency = %d\n', i, EEG.event(i).type, EEG.event(i).latency);
end

% Initialize empty arrays to store epochs and start codes
epoch_events = [];
epoch_boundaries = [];
epoch_start_codes = {}; % Cell array to store start codes for each epoch

% Loop through the events to find start and end code pairs
for i = 1:length(EEG.event)
    if ismember(num2str(EEG.event(i).type), keys(start_code_map)) % Convert event type to string for comparison
        for j = i+1:length(EEG.event)
            if strcmp(num2str(EEG.event(j).type), '127') % Convert event type to string for comparison
                epoch_events = [epoch_events; {EEG.event(i).type}]; % Store event type as cell to maintain consistency
                epoch_boundaries = [epoch_boundaries; [EEG.event(i).latency, EEG.event(j).latency]]; % Concatenate correctly
                epoch_start_codes{end+1} = start_code_map(num2str(EEG.event(i).type)); % Store the trial name
                break;
            end
        end
    end
end

% Debugging: Print out the results
for i = 1:length(epoch_events)
    fprintf('Epoch %d: Start Code = %s, Latency = [%d, %d]\n', i, epoch_start_codes{i}, epoch_boundaries(i, 1), epoch_boundaries(i, 2));
end

% Debugging: Print identified epoch boundaries in case EEG.comments keeps freaking out
fprintf('Identified %d epochs\n', size(epoch_boundaries, 1));
for i = 1:size(epoch_boundaries, 1)
    fprintf('Epoch %d: Start = %d, End = %d, Start Code = %s\n', i, epoch_boundaries(i, 1), epoch_boundaries(i, 2), epoch_start_codes{i});
end

% Check if any epochs were identified
if isempty(epoch_boundaries)
    error('No epochs found. Check the event codes and latency values.');
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

% Visualize the new epoched data
if num_epochs > 0
    pop_eegplot(EEG_epoch, 1, 1, 1);
else
    disp('No epochs found. Check the event codes and latency values.');
end

%% Analysis Pipeline per Epoch 

% Remove the PD channel
EEG_epoch = pop_select(EEG_epoch, 'nochannel', {'PD'});

% Downsample to 250Hz
EEG_epoch = pop_resample(EEG_epoch, 250);

% Butterworth filter: high-pass cut off of 1Hz and low-pass cut off of 30Hz
EEG_epoch = pop_eegfiltnew(EEG_epoch, 1, 30);

% Channel locations & head reference
EEG_epoch = pop_chanedit(EEG_epoch, 'lookup', fullfile('C:\Users\errat\Desktop\STROBE\Preprocessing\ant_waveguard_64_channel_location\standard-10-5-cap385.elp'));
EEG_epoch = pop_chanedit(EEG_epoch, 'eval', 'chans = pop_chancenter(chans, [], []);');

% Use CleanLine plugin to remove baseline drift
EEG_epoch = pop_cleanline(EEG_epoch, 'Bandwidth', 2, 'ChanCompIndices', 1:EEG_epoch.nbchan, ...
                    'SignalType', 'Channels', 'ComputeSpectralPower', 0, ...
                    'LineFrequencies', [50 100 150 200 250], 'NormalizeSpectrum', 0, ...
                    'LineAlpha', 0.01, 'PaddingFactor', 2, 'PlotFigures', 0, ...
                    'ScanForLines', 1, 'SmoothingFactor', 100, 'VerbosityLevel', 1);

% Use clean_rawdata plugin to remove bad channels
EEG_epoch = clean_rawdata(EEG_epoch, 5, -1, 0.8, -1, 4, 0.25);

% Interpolate bad channels
EEG_epoch = pop_interp(EEG_epoch, EEG_epoch.chanlocs, 'spherical');

% Run ICA
EEG_epoch = pop_runica(EEG_epoch, 'extended', 1);

% Artifact removal using ICLabel and MARA
EEG_epoch = pop_iclabel(EEG_epoch, 'default');
EEG_epoch = pop_icflag(EEG_epoch, [NaN NaN; 0.9 1; NaN NaN; 0.9 1; NaN NaN; NaN NaN; NaN NaN]);
EEG_epoch = pop_subcomp(EEG_epoch, find(EEG_epoch.reject.gcompreject), 0);

%% Power Spectra using pwelch

% Parameters for pwelch
window = 500; % Length of each segment for Welch's method
noverlap = 250; % Number of overlapping samples
nfft = 1024; % Number of FFT points

% Initialize cell arrays to store power spectra for each condition
power_spectra = cell(1, num_epochs);
frequencies = cell(1, num_epochs);

% Compute power spectra for each epoch
for i = 1:num_epochs
    epoch_data = EEG_epoch.data(:, :, i);
    % Compute pwelch for each channel in the epoch
    for ch = 1:size(epoch_data, 1)
        [Pxx, F] = pwelch(epoch_data(ch, :), window, noverlap, nfft, EEG_epoch.srate);
        power_spectra{i}{ch} = Pxx;
        frequencies{i}{ch} = F;
    end
end

% Calculate the y-axis limits based on the range of power spectra values
all_power_values = [];
for i = 1:num_epochs
    for ch = 1:size(epoch_data, 1)
        all_power_values = [all_power_values; power_spectra{i}{ch}];
    end
end
y_min = min(all_power_values);
y_max = max(all_power_values);

% Specify the x-values where vertical lines should be added for each epoch
% for visualization purposes
% Effective frequencies per condition in order of stimulation
entrainment_flags = [10, 8, 14, 9.63, 9.983, 9.967, 10, 10.03, 10.0167, 9.967, 9.85, 10, 9.883, 9.583]; 

% Plot each epoch's power spectrum in subplots
figure;
num_rows = ceil(sqrt(num_epochs));
num_cols = ceil(num_epochs / num_rows);

for i = 1:num_epochs
    subplot(num_rows, num_cols, i);
    avg_Pxx = zeros(size(power_spectra{i}{1}));
    for ch = 1:size(epoch_data, 1)
        avg_Pxx = avg_Pxx + power_spectra{i}{ch};
    end
    avg_Pxx = avg_Pxx / size(epoch_data, 1); % Average across channels
    plot(frequencies{i}{1}, avg_Pxx); % Plot the average power spectrum
    set(gca, 'XScale', 'log', 'YScale', 'log'); % Set log-log scale
    xlim([5 30]); % Set x-axis limits to 5-30 Hz
    ylim([0.05 30]); % Set y-axis limits 
    xlabel('Frequency (Hz)');
    ylabel('Power');
    title(['Epoch ', num2str(i), ': ', epoch_start_codes{i}]);
    grid on;

    % Add vertical line at effective frequency for visualization
    xline(entrainment_flags(i), '--r', 'LineWidth', 1.5);
end

% Specify the desired epochs in the order you want
desired_epochs = [1, 2, 3, 4, 5, 6, 7, 8];
desired_labels = {'8Hz Periodic', '10Hz Periodic', '14Hz Periodic', 'IAFHz Periodic', '8Hz Aperiodic Poisson Relative Onset Jitter', '10Hz Aperiodic Poisson Relative Onset Jitter', '14Hz Aperiodic Possion Relative Onset Jitter', 'IAFHz Aperiodic Poisson Relative Onset Jitter'};

% Colors for different conditions
color_periodic = [0 0 1]; % Blue for periodic conditions
color_poisson = [0 1 0]; % Green for Poisson Relative Onset Jitter conditions

% Plot the specified epochs
figure;
hold on;
for i = 1:length(desired_epochs)
    epoch_idx = desired_epochs(i);
    avg_Pxx = zeros(size(power_spectra{epoch_idx}{1}));
    for ch = 1:size(epoch_data, 1)
        avg_Pxx = avg_Pxx + power_spectra{epoch_idx}{ch};
    end
    avg_Pxx = avg_Pxx / size(epoch_data, 1); % Average across channels
    
    % Determine color based on type
    if epoch_idx <= 4
        plot_color = color_periodic;
    else
        plot_color = color_poisson;
    end
    
    % Plot the average power spectrum
    plot(frequencies{epoch_idx}{1}, avg_Pxx, 'Color', plot_color, 'DisplayName', desired_labels{i});
    set(gca, 'XScale', 'log', 'YScale', 'log'); % Set log-log scale
    xlim([5 30]); % Set x-axis limits to 5-30 Hz
    ylim([0.05 22]); % Set y-axis limits
end

legend show; % Show legend
hold off;

% Add labels and title
xlabel('Frequency (Hz)');
ylabel('Power');
title('Overlay of Power Spectra for Different Epochs');
legend('show'); % Show the legend with labels
grid on;
hold off;

