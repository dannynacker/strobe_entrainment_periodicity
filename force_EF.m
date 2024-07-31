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
    max_iterations = 100; % Maximum number of iterations to find the matching Fe
    iteration = 0;
    best_samples = [];
    best_signal = [];
    best_Fe = 0;
    best_F = F;
    
    while iteration < max_iterations
        [samples, ~, signal] = gen_strobe_aperiodic(F, T, osig, relo, ondur, dsig, rmode);
        Fe = calculate_effective_frequency(F, T, osig, relo, ondur, dsig, rmode);
        
        if abs(Fe - target_Fe) <= tolerance
            best_samples = samples;
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
    
    % Save the samples with Fe in the filename
    samples_filename = sprintf('samples_F_%d_Fe_%.1f.mat', best_F, best_Fe);
    save(samples_filename, 'samples', 'F', 'Fe');
    
    % Save the signal with Fe in the filename
    signal_filename = sprintf('signal_F_%d_Fe_%.1f.mat', best_F, best_Fe);
    save(signal_filename, 'signal', 'F', 'Fe');
    
    % Store results in the cell array
    results = [results; {best_F, best_Fe, samples_filename, signal_filename}];
end

% Convert cell array to table and write to Excel
results_table = cell2table(results, 'VariableNames', {'F', 'Fe', 'Samples_Filename', 'Signal_Filename'});
writetable(results_table, 'simulation_results.xlsx');

fprintf('Simulations completed and results saved.\n');

function Fe = calculate_effective_frequency(F, T, osig, relo, ondur, dsig, rmode)
    % Generate the aperiodic strobe signal
    [~, Fe, ~] = gen_strobe_aperiodic(F, T, osig, relo, ondur, dsig, rmode);
end
