% 10Hz periodic taster session, 2 minutes
function periodic_10

    % Define parameters
    T = 120;  % total time (secs)
    osig = 'periodic';  % onset time
    relo = false;  % relative onset time with Gamma jitter?
    ondur = 'hcycle';  % cycle "on" duration
    dsig = 'fixed';  % on-duration
    rmode = 3;  % regularisation mode
    seed = [];  % random seed
    desired_frequency = 10;  % desired effective frequency
    fs     = 2000;  % Hz - this is apparently what the device expects
    dfac = 5; %spectral power display frequency cutoff factor 
    condition = 'periodic10';
        
    %% the usual setup (strobe stuff and trial onset warning)

    %% Preparation
    T = ceil(T*fs)/fs; % Ensure T is an integer number of samples
    totalSamples = T * fs; % Total number of samples
    
    %% Brightness of the light
    centralBrightness = 0;
    ringBrightness = 255;
        
    %% Define the parameters of the participant signaling tone

    % Parameters
    frequency = 440; % Frequency of the tone in Hz
    duration = 2; % Duration of the tone in seconds
    sampleRate = 44100; % Sampling rate (number of samples per second)
    
    % Time vector
    t = linspace(0, duration, duration * sampleRate);
    
    % Generate the tone
    tone = sin(2 * pi * frequency * t);

        
    %% Set up light details
    
    % Create a regular periodic strobe process

    signal_p = gen_strobe_periodic(F,T,ondur);
    
    [samples_p,ts] = sample_strobe(signal_p,fs,T); % sample signal at frequency fs
    
    [spower_p,f] = pspectrum(samples_p,fs,'FrequencyLimits',[0,dfac*F]); % spectral power
    
    % Create an aperiodic strobe process
    
    [signal_a,Fe,sdescrip] = gen_strobe_aperiodic(F,T,osig,relo,ondur,dsig,rmode,seed);
    
    [samples_a,ts] = sample_strobe(signal_a,fs,T); % sample signal at frequency fs
    
    [spower_a,f] = pspectrum(samples_a,fs,'FrequencyLimits',[0,dfac*F]); % spectral power
        
    preparedStrobeData1D = SCCS_strobe_prepare_data(samples_p);
    
    % Saving to .MAT
    save('periodic_10');
    
    %% Device Usage from File
    
        comPort = "COM4"; % You can use serialportlist() to list all available ports
        filename = "Example.txt";
    
    % Before this script is run, the ### sequence should be executed
        if ~exist('preparedStrobeData1D', 'var')
            disp("Cannot find preparedStrobeData1D");
            disp("No strobe data prepared, run a periodic first first");
            return;
        end
    
    % Don't remake the device if the connection already exists
        if ~exist('device', 'var')
            device = StrobeDevice(comPort);
        end
    
    % Wait 1s for serial thread to start up
        pause(1);
    
        if ~device.isConnected()
            disp("Device not connected.");
            device.closePort();
            clear('device') % Clear the device variable so it is recreated next execution
            return;
        end
        disp("Device connected.");
    
    % Check to see if we have a valid connection
        [device, success] = device.tryGetDeviceInfo(2); % Ask the device for its info
    % StrobeDevice(device) here ensures autocompletion in the rest of the script
        if ~success
            disp("Failed to verify device.");
            device.closePort();
            clear('device') % Clear the device variable so it is recreated next execution
            return;
        end
        disp("Device verified.");
    
        pause(1);
    
    % Check if the file already exists before we try to write to it.
        fileList = device.getFileList();
        for i=1:length(fileList)
            if contains(fileList(i), filename)
                disp("File already exists. Deleting first.")
                disp(device.deleteFile(filename));
            end
        end
        pause(1);
    
        disp("Re-reading file list.")
        fileListAfterDelete = device.getFileList();
    
        pause(1);
    
        disp("Writing strobe samples to file...")
        response = device.writeToFile(filename, preparedStrobeData1D); % Filename must be at most 8.3 format
        if ~strcmp(response, "Done")
            disp("File write failed, aborting.")
            disp(response);
            device.closePort();
            clear('device') % Clear the device variable so it is recreated next execution
            return;
        end
        disp("Done.")
        pause(1);
    
        %% Display the chosenHz and condition
    
        disp(F)
        disp(condition)
    
        % Play a tone signaling start of sequence
    
        sound(tone, sampleRate);
        pause(duration);
    
       %% Play the sequence
    
        disp("Re-reading file list.")
        fileListAfterWrite = device.getFileList();
        pause(1);
    
        disp("Playing strobe file...")
        
        disp(device.playStrobeFile(filename, (length(preparedStrobeData1D)/12000) + 5)); % Play the newly written file and wait N+5 seconds for it to confirm that it has finished.
        pause(1)
    
        disp("Getting device temps:")
        % Send trigger for the end of execution
       
        disp(device.getTemperatures()) % Print the device temperatures.
    
        pause(5)
    
    % When finished wrap up and close the port, stopping the serial thread.
        device.closePort();
    
    %% Integer Conversion Function
    function value = binary8ToUint8(bitArray)
        % Each row of bitArray must be a single 8-bit value
        value = sum(bitArray .* [2^7, 2^6, 2^5, 2^4, 2^3, 2^2, 2^1, 2^0], 2);
        return;
    end
     
end 