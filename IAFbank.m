% Poisson distribution at given Hz
function IAFbank

    % Define parameters
    T = 300;  % total time (secs)
    osig = 'Poisson';  % onset time
    relo = false;  % relative onset time with Gamma jitter?
    ondur = 'hcycle';  % cycle "on" duration
    dsig = 'fixed';  % on-duration
    rmode = 3;  % regularisation mode
    fs = 2000;  % Hz - this is apparently what the device expects
    dfac = 5; %spectral power display frequency cutoff factor 
    condition = 'Poisson10hz';

    % Define desired frequencies
    desired_frequencies = [8, 10, 14, 8:0.1:12];
    
    % Initialize array to store F values
    F_values = zeros(size(desired_frequencies));
    
    % Tolerance for effective frequency match
    tolerance = 0.0001;
    
    % Maximum number of iterations
    max_iterations = 10000;
    
    % Function handle for calculating effective frequency (seed removed)
    calc_eff_freq = @(F) calculate_effective_frequency(F, T, osig, relo, ondur, dsig, rmode);

    for idx = 1:length(desired_frequencies)
        desired_frequency = desired_frequencies(idx);
        
        % Initial guess for F
        F = 10;
        
        % Iteratively adjust F to match the desired effective frequency
        for i = 1:max_iterations
            Fe = calc_eff_freq(F);
            error = Fe - desired_frequency;
            
            if abs(error) <= tolerance
                fprintf('Desired effective frequency achieved: %f Hz with F = %f\n', Fe, F);
                F_values(idx) = F;
                break;
            end
            
            % Adjust F based on the error
            F = F - error * 0.1; % Adjust step size (0.1 can be tuned)
            
            % Print iteration details
            fprintf('Iteration %d: F = %f, Fe = %f, error = %f\n', i, F, Fe, error);
        end
        
        if abs(error) > tolerance
            fprintf('Failed to achieve desired effective frequency within %d iterations.\n', max_iterations);
            F_values(idx) = NaN; % Indicate failure to find F
        end
    end
    
    % Display the results
    disp('Desired Frequencies:');
    disp(desired_frequencies);
    disp('Corresponding F values:');
    disp(F_values);
    
    % Save results to an Excel file
    result_table = table(desired_frequencies', F_values', 'VariableNames', {'Desired_Frequency', 'F_Value'});
    writetable(result_table, 'IAFbank_results.xlsx');
    
    % Create a pop-up sheet graph for visualization
    figure;
    plot(desired_frequencies, F_values, '-o');
    xlabel('Desired Frequency (Hz)');
    ylabel('F Value');
    title('F Values for Desired Effective Frequencies');
    grid on;
