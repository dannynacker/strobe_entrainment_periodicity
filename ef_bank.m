% Define parameters
T = 300;  % total time (secs)
osig = 'Poisson';  % onset time
relo = false;  % relative onset time with Gamma jitter?
ondur = 'hcycle';  % cycle "on" duration
dsig = 'fixed';  % on-duration
rmode = 3;  % regularisation mode
fs = 2000;  % Hz - this is apparently what the device expects
dfac = 5; %spectral power display frequency cutoff factor 
condition = 'Poisson';

% Define desired frequencies
desired_frequencies = [8:0.1:12.0, 14]; % Range from 8.0 to 12.0 with a step of 0.1, plus 14

% Initialize a cell array to store results
results = {};

for i = 1:length(desired_frequencies)
    target_Fe = desired_frequencies(i);
    F = target_Fe; % Start with the target effective frequency as initial frequency
    
    % Initialize variables
    tolerance = 0.01; % Tolerance for effective frequency match
    max_iterations = 10000; % Maximum number of iterations to find the matching Fe
    iteration = 0;
    best_signal = [];
    best_Fe = 0;
    best_F = F;
    
    while iteration < max_iterations
        [samples, ~, signal] = gen_strobe_aperiodic(F, T, osig, relo, ondur, dsig, rmode);
        Fe = calculate_effective_frequency(F, T, osig, relo, ondur, dsig, rmode);
        
        if abs(Fe - target_Fe) <= tolerance
            best_signal = signal;
            best_Fe = Fe;
            best_F = F;
            break;
        end
        
        % Adjust the frequency based on the effective frequency
        if Fe < target_Fe
            F = F + 0.1;
        else
            F = F - 0.1;
        end
        
        iteration = iteration + 1;
    end
    
    % Process the signal to generate samples
    [samples, ts] = sample_strobe(best_signal, fs, T);
    
    % Save the signal with Fe in the filename
    formatted_F = sprintf('%.1f', best_Fe); % Format the frequency to one decimal place
    signal_filename = sprintf('aperiodic_%s.mat', formatted_F);
    save(signal_filename, 'signal', 'F', 'Fe', 'samples', 'ts');
    
    % Store results in the cell array
    results = [results; {best_F, best_Fe, signal_filename}];
end

% Convert cell array to table and write to Excel
results_table = cell2table(results, 'VariableNames', {'F', 'Fe', 'Signal_Filename'});
writetable(results_table, 'simulation_results.xlsx');

fprintf('Simulations completed and results saved.\n');

function Fe = calculate_effective_frequency(F, T, osig, relo, ondur, dsig, rmode)
    % Generate the aperiodic strobe signal
    [~, Fe, ~] = gen_strobe_aperiodic(F, T, osig, relo, ondur, dsig, rmode);
end

function [samples,ts] = sample_strobe(signal,fs,T)
    % Sample the signal at frequency fs, over a time segment of length T
    ndt = T * fs; % number of samples - must be an integer
    assert(ceil(ndt) == ndt, 'Number of samples must be an integer (check total time and sampling frequency)');
    ndt1 = ndt + 1;

    assert(all(signal(:,1) >= 0), 'On times must be nonnegative');
    assert(all(signal(:,2) >  0), 'Durations must be positive');

    ts = (0:ndt)' / fs;        % sample time stamps
    samples = zeros(ndt1, 1); % time series (binary)

    % Quantise to sample frequency
    son = round(signal(:,1) * fs) + 1; % on sample numbers
    sdur = ceil(signal(:,2) * fs);    % numbers of on samples (duration)
    soff = son + sdur - 1;              % off sample numbers

    for e = 1:length(son)
        if son(e) > ndt1, continue; end % on time out of range - ignore
        if soff(e) > ndt1, soff(e) = ndt1; end % ensure on till end of time series
        samples(son(e):soff(e)) = 1;           % turn on for duration
    end
end
