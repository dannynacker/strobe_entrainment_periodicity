%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%
%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%
%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%

%% +++++++++++++++++++++++++++ %%
%% Tuesday, July the 9th, 2024 %%
%% +++++++++++++++++++++++++++ %%

%% ++++++++++++ %%
%% This script: %%
%% ++++++++++++ %%

%% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ %%
% 1. Prompts the user to enter participant ID, age, sex, handedness, and IAF value    %%
% 2. Simulates and sends over 5 minutes (300 seconds) of strobe at specified          %%
% frequencies and conditions (periodic vs. aperiodic Poisson relative onset jitter)   %%
% for a total of 8 trials; These conditions are periodic and aperiodic at frequencies %% 
% 8, 10, 14, and IAF Hz                                                               %%
% 3. Randomizes the order of condition selection                                      %%
% 4. Forces aperiodic effective frequencies utilizing frequencies selected            %%
% from a predetermined bank of values found to create these EFs over a                %%
% number of iterations, IAFbank.m                                                     %%
% 5. Sends these sequences over to the SCCS strobe light and prompts the              %%
% user to press any key to begin the next trial                                       %%
% 6. Requires a series of addition scripts and files.                                 %%
% 7. Requires the Signal Processing Toolbox (I think)                                 %%
% 8. Is a joint effort among Dr. David Schwartzman, Dr. Lionel Barnett, and           %%
% University of Sussex MSc student Danny Nacker (under the supervision of Dr. David   %%
% Schwartzman, Dr. Lionel Barnett, and Dr. Anil Seth, and is a modification of strobe %%
% device interfacing originally made by doctoral student Romy Beauté.                 %%
%% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ %%

%% ++++++++++++ %%
%% Files Needed %%
%% ++++++++++++ %%

%% +++++++++++++++ %%
%% For the Trigger %%
%% +++++++++++++++ %%

% config_io.m 
% inp.m
% inputoutx64.dll
% io64.m
% IOPort.m 
% outp.m

%% ++++++++++++++ %%
%% For the Strobe %%
%% ++++++++++++++ %%

% calculate_effective_frequency.m (I think)
% gen_strobe_aperiodic for simulating the aperiodic sequence
% gen_strobe_periodic for stimulating the periodic sequence
% regularise_strobe.m
% sample_strobe.m
% SCCS_strobe_prepare_data.m
% StrobeDevice.m 
% DeviceUsageFromFileExample.m (I think)
% the StrobeDevice folder
 
%% ++++++++++++++++++++++++++ %%
%% Initial Simulation Details %%
%% ++++++++++++++++++++++++++ %%

%% ++++++++++++++++ %%
%% Specify Our Path %%
%% ++++++++++++++++ %%

addpath("E:\final_experiment")

%% +++++++++++++++++++ %%
%% Participant Details %%
%% +++++++++++++++++++ %%

% Participant ID
ID = input('Please enter the participant ID: '); % numeric

% Participant Age
age = input('Please enter the participant age: '); % numeric

% Participant Sex
while true
    sex = input('Please enter the participant sex (M/F): ', 's');
    if ismember(sex, {'M', 'F'})
        break;
    else
        disp('Invalid input. Please enter M or F.');
    end
end

% Participant Handedness
while true
    handedness = input('Please enter the participant handedness (R/L): ', 's');
    if ismember(handedness, {'R', 'L'})
        break;
    else
        disp('Invalid input. Please enter R or L.');
    end
end

% Participant IAF
IAF = input('Please enter the IAF value: '); % Value from 8 to 12, 0.1-stepwise

%% +++++++++++++++++ %%
%% Strobe Parameters %%
%% +++++++++++++++++ %%

% Define parameters (Thanks, Lionel!) 
T = 300;  % total time (secs)
relo = true;  % relative onset time with Gamma jitter? (set to true for phase drift)
ondur = 'hcycle';  % cycle "on" duration
dsig = 'fixed';  % on-duration
rmode = 3;  % regularisation mode
fs = 2000;  % Hz - this is apparently what the device expects
dfac = 5; % spectral power display frequency cutoff factor 

%% +++++++++++ %%
%% Value Banks %%
%% +++++++++++ %%

F_values_Poisson = [11.06433333, 13.90266667, 19.50766667, 11.09566667, 11.24133333, 11.43466667, 11.50833333, 11.70666667, 11.796, 12.011, 12.109, 12.298, 12.36166667, 12.18433333, 12.68833333, 12.788, 12.95066667, 13.06, 13.09833333, 13.358, 13.51366667, 13.481, 13.81333333, 13.83033333, 14.02966667, 14.22666667, 14.35366667, 14.479, 14.678, 14.75766667, 14.868, 14.72466667, 15.21133333, 15.32066667, 15.43866667, 15.558, 15.77166667, 15.89666667, 16.063, 16.099, 16.38433333, 16.328, 16.56866667, 16.693];
EF_values_Poisson = [8, 10, 14, 8, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 9, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 11, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 12];

F_values_periodic = [8, 10, 14, 8, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 9, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 11, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 12];
EF_values_periodic = [8, 10, 14, 8, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 9, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 10, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 11, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 12];

%% +++++++++++++++++++++ %%
%% Selecting A Condition %%
%% +++++++++++++++++++++ %%

% Define conditions and associated parameters using F and EF values
% iterated over from IAFbank.m, forcing a value of EF based on a Poisson or
% periodic simulation sequence 

conditions = {'8p', '10p', '14p', 'IAFp', '8a', '10a', '14a', 'IAFa'};

% Randomize conditions
randomized_conditions = conditions(randperm(length(conditions)));

% Initialize cell array to store trial information
trial_info = cell(length(randomized_conditions) + 1, 10); % Adding 1 for the header row
trial_info(1, :) = {'Trial', 'Condition', 'osig', 'F', 'EF', 'ParticipantID', 'Age', 'Sex', 'Handedness', 'IAF'}; % Assign headers to the first row

% Initialize device connection before the loop
comPort = "COM4";

% Loop through randomized conditions
for i = 1:length(randomized_conditions)
    success = false; % Initialize success flag
    while ~success
        try
            condition = randomized_conditions{i};
            
            % Assign osig value based on the condition type
            if endsWith(condition, 'a')
                osig = 'Poisson';
            else
                osig = 'periodic';
            end

            % Initialize F and EF
            F = NaN;
            EF = NaN;

            % Select appropriate F and EF values based on osig and condition
            switch osig
                case 'Poisson'
                    if strcmp(condition, 'IAFa')
                        index = find(abs(EF_values_Poisson - IAF) < 0.0001, 1);
                        if ~isempty(index)
                            F = F_values_Poisson(index);
                            EF = EF_values_Poisson(index);
                        else
                            error('IAF value not found in EF_values_Poisson');
                        end
                    else
                        switch condition
                            case '8a'
                                F = F_values_Poisson(1);
                                EF = EF_values_Poisson(1);
                            case '10a'
                                F = F_values_Poisson(2);
                                EF = EF_values_Poisson(2);
                            case '14a'
                                F = F_values_Poisson(3);
                                EF = EF_values_Poisson(3);
                        end
                    end
                case 'periodic'
                    if strcmp(condition, 'IAFp')
                        index = find(abs(EF_values_periodic - IAF) < 0.0001, 1);
                        if ~isempty(index)
                            F = F_values_periodic(index);
                            EF = EF_values_periodic(index);
                        else
                            error('IAF value not found in EF_values_periodic');
                        end
                    else
                        switch condition
                            case '8p'
                                F = F_values_periodic(1);
                                EF = EF_values_periodic(1);
                            case '10p'
                                F = F_values_periodic(2);
                                EF = EF_values_periodic(2);
                            case '14p'
                                F = F_values_periodic(3);
                                EF = EF_values_periodic(3);
                        end
                    end
            end
            
            if isnan(F) || isnan(EF)
                error('F or EF not set for condition: %s with osig: %s', condition, osig);
            end
            
            % Display selected parameters for current condition
            fprintf('Condition: %s\n', condition);
            fprintf('osig: %s\n', osig);
            fprintf('F: %f\n', F);
            fprintf('EF: %f\n', EF);
            fprintf('IAF: %f\n', IAF);
            
            % Store trial information
            trial_info{i+1, 1} = i; % Trial number
            trial_info{i+1, 2} = condition; % Condition
            trial_info{i+1, 3} = osig; % osig
            trial_info{i+1, 4} = F; % F
            trial_info{i+1, 5} = EF; % EF
            trial_info{i+1, 6} = ID; % Participant ID
            trial_info{i+1, 7} = age; % Age
            trial_info{i+1, 8} = sex; % Sex
            trial_info{i+1, 9} = handedness; % Handedness
            trial_info{i+1, 10} = IAF; % IAF

            % Initialize the device for each trial
            device = StrobeDevice(comPort);

            pause(1);

            if ~device.isConnected()
                disp("Device not connected.");
                device.closePort();
                clear('device');
                error('Failed to connect to the device.');
            end
            disp("Device connected.");

            % Run the strobe sequence
            success = runStrobeSequence(condition, F, EF, osig, T, fs, ondur, dfac, relo, dsig, rmode, device);
            
            if ~success
                disp('Error occurred. Please press any key to repeat the trial.');
                pause;
            else
                % Successfully completed trial, prompt for next trial
                disp('Trial completed successfully. Press any key to proceed to the next trial.');
                pause;
            end

            % Close the device connection
            device.closePort();
            clear('device');
        catch ME
            disp(['Error in trial ' num2str(i) ': ' ME.message']);
            disp('Please press any key to repeat the trial.');
            pause;
        end
    end
end

%% ++++++++++++++++++++++ %%
%% Save Trial Information %%
%% ++++++++++++++++++++++ %%

% Convert the cell array to a table
trial_table = cell2table(trial_info(2:end, :), 'VariableNames', trial_info(1, :));

% Save the table as an Excel file
filename = sprintf('Participant_%d_Trial_Info.xlsx', ID);

if isfile(filename)
    % Load existing data
    existing_data = readtable(filename);
    % Append new data
    trial_table = [existing_data; trial_table];
end

writetable(trial_table, filename);

%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%
%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%
%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%

%% +++++++++++++++++ %%
%% Support Functions %%
%% +++++++++++++++++ %%

%% +++++++++++++++++++++++++++++++++++++++++++++++++ %%
%% Integer Conversion Function Required By The Light %%
%% +++++++++++++++++++++++++++++++++++++++++++++++++ %%

function value = binary8ToUint8(bitArray)
    % Each row of bitArray must be a single 8-bit value
    value = sum(bitArray .* [2^7, 2^6, 2^5, 2^4, 2^3, 2^2, 2^1, 2^0], 2);
    return;
end

%% ++++++++++++++++++++++++++++++++++++++++++++ %%
%% Strobe Sequence Function with Error Handling %%
%% ++++++++++++++++++++++++++++++++++++++++++++ %%

function success = runStrobeSequence(condition, F, EF, osig, T, fs, ondur, dfac, relo, dsig, rmode, device)
    try
        % Create the appropriate strobe signal
        if endsWith(condition, 'a')
            [signal, Fe, sdescrip] = gen_strobe_aperiodic(F, T, osig, relo, ondur, dsig, rmode);
            fprintf('\nEffective frequency = %g Hz\n\n', Fe);
        else
            signal = gen_strobe_periodic(F, T, ondur);
        end

        [samples, ts] = sample_strobe(signal, fs, T);
        [spower, f] = pspectrum(samples, fs, 'FrequencyLimits', [0, dfac*F]);

        preparedStrobeData1D = SCCS_strobe_prepare_data(samples);
        save('strobe_sequence', 'preparedStrobeData1D');

        filename = "Example.txt";

        pause(1);

        if ~device.isConnected()
            disp("Device not connected.");
            device.closePort();
            clear('device');
            success = false;
            return;
        end
        disp("Device connected.");

        [device, valid] = device.tryGetDeviceInfo(2);
        if ~valid
            disp("Failed to verify device.");
            device.closePort();
            clear('device');
            success = false;
            return;
        end
        disp("Device verified.");

        pause(1);

        fileList = device.getFileList();
        if any(contains(fileList, filename))
            disp("File already exists. Deleting first.");
            disp(device.deleteFile(filename));
        end

        pause(1);

        disp("Writing strobe samples to file...");
        response = device.writeToFile(filename, preparedStrobeData1D);
        if ~strcmp(response, "Done")
            disp("File write failed, aborting.");
            disp(response);
            device.closePort();
            clear('device');
            success = false;
            return;
        end
        disp("Done.");
        pause(1);

        soundTone(440, 2, 44100);

        % Send start trigger
        startTriggerValue = getStartTriggerValue(condition);
        sendTrigger(startTriggerValue);

        disp("Playing strobe file...");
        disp(device.playStrobeFile(filename, (length(preparedStrobeData1D)/12000) + 5));
        pause(1);

        % Send end trigger
        sendTrigger(127);

        disp("Getting device temps:");
        disp(device.getTemperatures());
        
        pause(5);

        device.closePort();
        success = true;
    catch ME
        disp(['Error: ' ME.message]);
        success = false;
    end
end

%% ++++++++++++++++++++++++ %%
%% Tone Generation Function %%
%% ++++++++++++++++++++++++ %%

function soundTone(frequency, duration, sampleRate)
    t = linspace(0, duration, duration * sampleRate);
    tone = sin(2 * pi * frequency * t);
    sound(tone, sampleRate);
    pause(duration);
end

%% ++++++++++++++++++++++++ %%
%% Trigger Sending Function %%
%% ++++++++++++++++++++++++ %%

function sendTrigger(triggerValue)
    ioObj = io64;
    status = io64(ioObj);
    address = hex2dec('CFF8'); % Standard LPT1 output port address
    io64(ioObj, address, triggerValue); % Send trigger 
    pause(0.05); % Small pause to ensure the trigger is registered
    io64(ioObj, address, 0); % Reset the port to 0
    pause(0.05); % Small pause to ensure the reset is registered
end

%% +++++++++++++++++++++++++++++++++++++++++++++ %%
%% Get Start Trigger Value Based on Condition %%
%% +++++++++++++++++++++++++++++++++++++++++++++ %%

function triggerValue = getStartTriggerValue(condition)
    switch condition
        case '8p'
            triggerValue = 1;
        case '10p'
            triggerValue = 2;
        case '14p'
            triggerValue = 3;
        case 'IAFp'
            triggerValue = 4;
        case '8a'
            triggerValue = 5;
        case '10a'
            triggerValue = 6;
        case '14a'
            triggerValue = 7;
        case 'IAFa'
            triggerValue = 8;
        otherwise
            error('Unknown condition: %s', condition);
    end
end

%% +++ %%
%% Fin %%
%% +++ %%

%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%
%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%
%% ++++++++++++++++++++++++++++++++++++++++++++++++ %%
