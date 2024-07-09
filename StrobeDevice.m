classdef StrobeDevice
	% StrobeDevice This class provides a MATLAB interface for communicating with
	% the strobe experience device. Once connected to the correct COM port,
	% functions can be used to deliver stimuli, request feedback, etc.
    %
    %   Uses serialport functions introduced in R2019b, parfeval
    %   threading functions introduced in R2021b and thread-based
    %   file functions introduced in R2022b.

	properties(Access = public)
		deviceName = ""; % Device name, populated by tryGetDeviceInfo. 
		softwareVersion = ""; % Device software version, populated by tryGetDeviceInfo. 
		serialNo = ""; % Device serial number, populated by tryGetDeviceInfo. 

		shouldWriteToLog = true; % Whether the device should write all communicated messages to the 'DeviceLog.txt' file
	end

	properties(Access = public)
		SerialThread; % The thread object that is created when the serial port is connected to
        Command_List = []; % A list of all the command characters
	end

	methods(Static)
		function FoundStrobeDevice = SearchComPortsForDevice()
            % SearchComPortsForDevice Scans available COM ports for a StrobeDevice
            %   Connects to each port and attempts to get valid device information.
            %   If a valid response is received, the connection is maintained and the device is returned.
            %   Returns [] if no device is found.

			availablePorts = serialportlist("available");
			for index = 1 : length(availablePorts)
				testDevice = StrobeDevice(availablePorts(index));
				[testDevice, validResponse] = testArc.tryGetDeviceInfo(1);
				if validResponse
					FoundStrobeDevice = testDevice;
					return;
                else
                    testDevice.closePort();
				end
			end
			FoundStrobeDevice = [];
		end
	end

	methods
		function obj = StrobeDevice(portName)
			% StrobeDevice Connects to the specified serial COM port and provides an interface for device control.
            %
			%   This contstructor creates an empty StrobeDevice folder in the current working directory and then starts the serial port background thread.
            %   The thread manages all incoming and outgoing messages, see StrobeDevice.serialThreadFunction.

            if ~isfolder(fullfile(cd, "StrobeDevice"))
                disp("Making serial buffer directory");
                mkdir(fullfile(cd, "StrobeDevice"));
            end

            disp("Deleting files from buffer directory");
            existingFiles = dir(fullfile(cd, "StrobeDevice\"));
            for i=1:length(existingFiles)
                if ~strcmp(existingFiles(i).name, ".") && ~strcmp(existingFiles(i).name, "..")
                    delete(fullfile(cd, "StrobeDevice", existingFiles(i).name));
                end
            end

            obj.Command_List = [
                obj.Command_Help, ...
                obj.Command_Error, ...
                obj.Command_CancelStrobe, ...
    		    obj.Command_DeviceInfo, ...
    		    obj.Command_GetDeviceState, ...
                obj.Command_SetLEDState, ...
    		    obj.Command_SetChannelOutput, ...
    		    obj.Command_SetOutputState, ...
                obj.Command_PlayStrobe, ...
                obj.Command_PlayStrobeFile, ...
                obj.Command_FixedRateStrobe, ...
        	    obj.Command_GetFileList, ...
                obj.Command_WriteFile, ...
        	    obj.Command_ReadFile, ...
                obj.Command_DeleteFile, ...
        	    obj.Command_DeleteAllFiles, ...
                obj.Command_SetMaxBrightness, ...
                obj.Command_GetMaxBrightness, ...
                obj.Command_GetLUXState, ...
                obj.Command_GetTemperatures, ...
                obj.Command_GetFanSpeeds, ...
                obj.Command_SetFanSpeeds
            ];
           
            obj.SerialThread = parfeval(backgroundPool, @StrobeDevice.serialThreadFunction, 1, portName, obj.Command_List, true, cd);
            disp("Thread started: " + obj.SerialThread.State)
            pause(1)
            disp("Thread status: " + obj.SerialThread.State)
        end

        function status = isConnected(obj)
            % isConnected If the SerialThread is running, returns 1. If the thread has aborted returns -1, otherwise returns 0.
            if strcmp(obj.SerialThread.State, "Running") 
                status = 1;
            else
                if isfile(fullfile(cd, "StrobeDevice", "ThreadIsRunning.txt"))
                    status = -1;
                else
                    status = 0;
                end
            end
            return;
		end

		function delete(obj)
			% delete When this object is deleted, clean up and close the serial port if required.
			obj.closePort();
		end

		function closePort(obj)
            % closePort If the SerialThread is running, this function triggers it to stop and waits for completion.
            %
            %   If the thread is running, this function creates the 'ThreadShouldStop.txt' file to indicate that the thread should self terminate and waits for the 'ThreadIsRunning.txt' file to be deleted.
            %   Otherwise this thread just removes the 'ThreadIsRunning.txt' file if possible.

            if isfile(fullfile(cd, "StrobeDevice", "ThreadIsRunning.txt"))
                if strcmp(obj.SerialThread.State, "Running") 
                    disp("Creating thread shouldStop file");
                    try
				        fid = fopen(fullfile(cd, "StrobeDevice", "ThreadShouldStop.txt"), 'at' );
				        fclose(fid);
			        catch err
				        disp("Error when creating log file for '" + obj.Command_List(i) + "'");
				        disp(err);
                    end
    
                    while isfile(fullfile(cd, "StrobeDevice", "ThreadIsRunning.txt"))
                        pause(1);
                        disp("Waiting for read thread to terminate");
                    end
                end

                delete(fullfile(cd, "StrobeDevice", "ThreadIsRunning.txt"));
                disp("Done");
            end
		end

        function success = clearCommandLog(obj, commandChar)
            % clearCommandLog Helper function. Clears the buffered received data for a given command character.
            try
                fid = fopen(fullfile(cd, "StrobeDevice", "Command_" + commandChar + ".txt"), 'w' );
			    fclose(fid);
            catch err
				disp("Error when clearing file for 'Command_" + commandChar + "'");
				disp(err);
            end
        end

        function success = sendToDevice(obj, commandString)
            % sendToDevice Adds the given string to the transmit buffer file for the serial communication thread to send.
            %
            %   This function writes the given string to the transmit buffer.
            %   If the write does not succeed, this thread will repeatedly try without timeout and may hang.
            success = false;
            while ~success
                try
                    fid = fopen(fullfile(cd, "StrobeDevice", "TransmitBuffer.txt"), 'a' );
                    if fid < 0 
                        disp("Transmit Buffer Not Found. (fid = " + fid + ")");
                    elseif fid == 0
                        disp("Transmit Buffer Busy.");
                    else
                        % disp("File opened, trying to write");
                        fwrite(fid, commandString);
                        % disp("Writing done, trying to close");
			            fclose(fid);
                        % disp("File closed.");
                        success = true;
                    end
                    pause(0.01);
                catch err
				    disp("Error when adding transmit command to buffer. (fid = " + fid + ")");
				    % disp(err);
                end
            end
            return;
        end

        function [matchingChar, matchingLine, allLines] = readUntilLine(obj, commandCharList, desiredLines, timeoutS)
            % readUntilLine Reads the device output for specific commands until any line matches one of the desired lines. Aborts after timeoutS seconds.
            %
            %   Device output is read from the command response files specified in the commandCharList until it finds any of the matching lines described in the desiredLinesParameter or until timeoutS has passed.
            %   commandCharList - should be a 1D array of N chars.
            %   desiredLines - should be a cell array containing strings to match against for each of the N chars. Empty string can be used to match against any line.

            matchingChar = [];
            matchingLine = [];
            allLines = [];

            if isempty(commandCharList)
                disp("Not enough command chars!");
                return;
            end
            if length(desiredLines) ~= length(commandCharList)
                disp("Incompatible lengths for desired lines and command char list!");
                return;
            end

            t = tic();
            lineFound = false;
            while ~lineFound
                % Allow for looking at multiple command characters
                for charIndex = 1:length(commandCharList)
                    thisChar = commandCharList(charIndex);
                    thisDesiredLines = desiredLines{charIndex};
                    fid = fopen(fullfile(cd, "StrobeDevice", "Command_" + thisChar + ".txt"), 'rt' );
                    if fid < 0 
                        disp("Command Buffer '" + thisChar + "' Not Found. (fid = " + fid + ")");
                    elseif fid == 0
                        disp("Command Buffer '" + thisChar + "' Busy.");
                    else
                        receivedLines = fread(fid);
                        fclose(fid);
                        if ~isempty(receivedLines) && ~strcmp(receivedLines, "")
                            obj.clearCommandLog(thisChar);
                            receivedLines = splitlines(convertCharsToStrings(char(receivedLines)));
                            for lineNum = 1:length(receivedLines)
                                thisLine = receivedLines(lineNum);
                                if(~strcmp(thisLine, ""))
                                    % Allow for looking at multiple desired lines
                                    % per command character
                                    for desiredLineIndex = 1:length(thisDesiredLines)
                                        thisDesiredLine = thisDesiredLines(desiredLineIndex);
                                        if strcmp(thisDesiredLine, "") || strcmp(thisLine(1:length(thisDesiredLine)), thisDesiredLine)
                                            lineFound = true;
                                            matchingChar = thisChar;
                                            matchingLine = thisLine;
                                        end
                                    end
                                    if lineFound
                                        for remainingLineNum = lineNum+1:length(receivedLines)
                                            thisRemainingLine = receivedLines(remainingLineNum);
                                            if(~strcmp(thisRemainingLine, ""))
                                                allLines = [allLines, thisRemainingLine];
                                            end
                                        end
                                        return;
                                    else
                                        allLines = [allLines, thisLine];
                                    end
                                end
                            end
                        end
                    end
                    if toc(t) > timeoutS
				        return;
                    end
                    pause(0.01);
                end
            end
        end

        function [obj, validResponse] = tryGetDeviceInfo(obj, timeout)
			% tryGetDeviceInfo Request for the device to send its configuration message. Populates device name, software version and serial No fields if correct response received.
            %
            % Returns - the updated object and whether the response was parsed as valid.
            validResponse = false;
            obj.clearCommandLog(obj.Command_DeviceInfo)
			obj.sendToDevice("" + obj.Command_DeviceInfo + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_DeviceInfo, obj.Command_Error], {[""], [""]}, timeout);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running tryGetDeviceInfo command.");
                disp(allLines);
                return;
            end

			response = strtrim(foundLine);
			% disp("Response: " + response);
			validResponse = true;
			try
				responseValues = response.split("_");
				if length(responseValues) ~= 3
					validResponse = false;
					return;
				end

				obj.deviceName = responseValues(1);
				obj.softwareVersion = responseValues(2);
				obj.serialNo = responseValues(3);

                if ~strcmp(obj.softwareVersion, obj.Interface_Version)
                    disp("WARNING! Missmatched Matlab and Device Serial Interface. WARNING!")
                end

			catch err
				disp("Error when parsing response: " + response)
				disp(err);
				validResponse = false;
            end
            return;
        end

		function commandList = getCommandList(obj)
            % getCommandList Requests the help information of the device's serial interface. This returns a list of lines where each line describes a serial function and it's parameters.
            commandList = [];
            obj.clearCommandLog(obj.Command_Help)
			obj.sendToDevice("" + obj.Command_Help + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_Help, obj.Command_Error], {["Done"], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running getCommandList command.");
                disp(allLines);
                return;
            end
			commandList = allLines(2:length(allLines)); % Remove "Start" line
            return;
        end

		function response = getDeviceState(obj)
            % getDeviceState Used to check whether the device is in IDLE or STROBE mode.
            response = [];
            obj.clearCommandLog(obj.Command_GetDeviceState)
			obj.sendToDevice("" + obj.Command_GetDeviceState + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_GetDeviceState, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running getDeviceState command.");
                disp(allLines);
                return;
            end
			response = foundLine;
            return;
		end

		function response = setLEDState(obj, ledNum, turnOn)
            % setLEDState Used to set the on/off state of a single LED. LED will output light if both A) the State is set to on and B) the Channel is outputting a signal.
            %
            %   ledNum should be between 0 (central LED) and 8 inclusive. The mapping between LED and index follows a clockwise outer, inner arrangement from 'north' (see User Guide).
            %   turnOn should be 1 or 0
            response = [];
            obj.clearCommandLog(obj.Command_SetLEDState)
			obj.sendToDevice("" + obj.Command_SetLEDState + obj.Param_Delimiter + ledNum + obj.Param_Delimiter + turnOn + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_SetLEDState, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running setLEDState command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = setChannelOutput(obj, channelNum, outputValue)
            % setChannelOutput Used to configure the output level of each of the device's DACs, and thus the brightness of their associated LEDs.
            %
            %   channelNum - should be between 0 (central LED) and 4 inclusive. The mapping between output channels and LEDs follows a clockwise arrangement in pairs from 'north' (see User Guide).
            %   outputValue - should be between 0 and max (see getMaxIntensity command, system defaults are: central LED = 3000, ring LEDs = 1860)
            response = [];
            obj.clearCommandLog(obj.Command_SetChannelOutput)
			obj.sendToDevice("" + obj.Command_SetChannelOutput + obj.Param_Delimiter + channelNum + obj.Param_Delimiter + outputValue + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_SetChannelOutput, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running setChannelOutput command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = setOutputState(obj, ledStateBitmap, centralBrightness, northBrightness, eastBrightness, southBrightness, westBrightness)
            % setOutputState Used to set all the LED on/off states and DAC channel values in a single command. Channel outputs values are between 0-255 and mapped across to the system's max brigtness.
            %
            %   ledStateBitmap - should be between 0 and 255 where each bit represents the ON/OFF state for each of the ring LEDs.
            %   Each of the brightness values - should be between 0 and 255, and is mapped to the maximum configured brightness (255 = max).
            response = [];
            obj.clearCommandLog(obj.Command_SetOutputState)
			obj.sendToDevice("" + obj.Command_SetOutputState + obj.Param_Delimiter + ledStateBitmap + obj.Param_Delimiter + centralBrightness + obj.Param_Delimiter + northBrightness + obj.Param_Delimiter + eastBrightness + obj.Param_Delimiter + southBrightness + obj.Param_Delimiter + westBrightness + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_SetOutputState, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running setOutputState command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = playStrobeSequence(obj, sampleData, waitForFinishSeconds)
            % playStrobeSequence Used to send the device a short strobe sequence of up to 10s which it displays immediately. Can block execution until the sequence has finished if desired.
            %
            % sampleData is a sequence of bytes for which each set of 6 bytes represents the following information:
            %   <LED State Bitmap> <centralBrightness> <northBrightness> <eastBrightness> <southBrightness> <westBrightness>
            %   Samples are played back at 2ksps and there can be no more than 10 seconds of samples per transmission (or 120 kbytes).
            %   if waitForFinishSeconds is greater than 0, this command will wait that long to detect if playback has ended.
            response = [];
            if mod(length(sampleData), 6) ~= 0
				disp("Incorrect size of sample data! Must contain 6 bytes per sample.")
				return 
            end

            obj.clearCommandLog(obj.Command_PlayStrobe)
			obj.sendToDevice("" + obj.Command_PlayStrobe + obj.Param_Delimiter + (length(sampleData)/6) + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_PlayStrobe, obj.Command_Error], {["Data transmission approved."], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running playStrobeSequence command.");
                disp(allLines);
                return;
            end
            response = foundLine;

            % batchSize = 2000;
            % for i = 0:(ceil(length(sampleData)/batchSize)-1)
            %     % disp(1+(i*batchSize) + " -> " + 1+min(((i+1)*batchSize-1), length(sampleData)))
            %     obj.sendToDevice(char(sampleData(1+(i*batchSize):1+min(((i+1)*batchSize-1), length(sampleData)-1))));
            %     % disp(".")
            % end

            obj.sendToDevice(uint8(sampleData));

            if waitForFinishSeconds
                [foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_PlayStrobe, obj.Command_Error], {["Done."], [""]}, waitForFinishSeconds);
                if isempty(foundChar) || foundChar == obj.Command_Error
                    disp("Playback end not detected.");
                    disp(allLines);
                    return;
                end
			    response = foundLine;
            end
        end

        function response = playStrobeFile(obj, fileName, waitForFinishSeconds)
            % playStrobeFile This function streams strobe sample data from a file on the internal SD card similar to playStrobeSequence.
            %
            %   fileName - should be a file on the system's internal storage
            %   if waitForFinishSeconds is not zero, this function waits that many seconds for the file playback to end.
            response = [];
            obj.clearCommandLog(obj.Command_PlayStrobeFile)
			obj.sendToDevice("" + obj.Command_PlayStrobeFile + obj.Param_Delimiter + fileName + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_PlayStrobeFile, obj.Command_Error], {["Opening File"], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running playStrobeFile command.");
                disp(allLines);
                return;
            end
			response = foundLine;

            if waitForFinishSeconds
                [foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_PlayStrobeFile, obj.Command_Error], {["Done"], [""]}, waitForFinishSeconds);
                if isempty(foundChar) || foundChar == obj.Command_Error
                    disp("Playback end not detected.");
                    disp(allLines);
                    return;
                end
			    response = foundLine;
            end
        end


        function response = fixedRateStrobe(obj, centralLEDBrightness, ledStateBitmap, ringLEDBrightness, strobeRateHz)
            % fixedRateStrobe This function is used to set the device strobing at a fixed rate with the specified brightness levels. This function uses an internal timer and so strobe frequency can be specified very precisely.
            %
            %   centralLEDBrightness - should be between 0-255
            %   ledStateBitmap - should be 0-255
            %   ringLEDBrightness - should be 0-255
            %   strobeRateHz - can be a floating point number
            response = [];
            obj.clearCommandLog(obj.Command_FixedRateStrobe)
			obj.sendToDevice("" + obj.Command_FixedRateStrobe + obj.Param_Delimiter + centralLEDBrightness + obj.Param_Delimiter + ledStateBitmap + obj.Param_Delimiter + ringLEDBrightness + obj.Param_Delimiter + strobeRateHz + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_FixedRateStrobe, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running fixedRateStrobe command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = cancelStrobe(obj)
            % cancelStrobe Used to cancel a strobe sequence if it is happening. Can also be used to reset LED states to all off.
            response = [];
            obj.clearCommandLog(obj.Command_CancelStrobe)
			obj.sendToDevice("" + obj.Command_CancelStrobe + obj.Command_Delimiter);
        end








        function fileList = getFileList(obj)
            % getFileList This function returns a string list for each of the file names on the internal SD card and their sizes.
            fileList = [];
            obj.clearCommandLog(obj.Command_GetFileList)
			obj.sendToDevice("" + obj.Command_GetFileList + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_GetFileList, obj.Command_Error], {["End"], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running getFileList command.");
                disp(allLines);
                return;
            end
			fileList = allLines(2:length(allLines)); % Remove "Start" line;
            return;
        end

        function response = writeToFile(obj, filename, sampleData)
            % writeToFile This function can be used to write data to the internal SD card for later playback using the playStrobeFile function. Samples should be saved as described in the playStrobeSequence function.
            %
            %   filename - the file name to write the data to
            %   sampleData - a sequence of bytes for which each set of 6 bytes represents the following information:
            %   <LED State Bitmap> <centralBrightness> <northBrightness> <eastBrightness> <southBrightness> <westBrightness>
            response = [];
            if mod(length(sampleData), 6) ~= 0
				disp("Incorrect size of sample data! Must contain 6 bytes per sample.")
				return 
            end

            obj.clearCommandLog(obj.Command_WriteFile)
			obj.sendToDevice("" + obj.Command_WriteFile + obj.Param_Delimiter + filename + obj.Param_Delimiter + length(sampleData) + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_WriteFile, obj.Command_Error], {["Data transmission approved."], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running writeToFile command.");
                disp(allLines);
                response = allLines;
                return;
            end

            % batchSize = 2000;
            % for i = 0:(ceil(length(sampleData)/batchSize)-1)
            %     % disp(1+(i*batchSize) + " -> " + 1+min(((i+1)*batchSize-1), length(sampleData)))
            %     obj.sendToDevice(char(sampleData(1+(i*batchSize):1+min(((i+1)*batchSize-1), length(sampleData)-1))));
            %     % disp(".")
            % end

            obj.sendToDevice(uint8(sampleData));

            [foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_WriteFile, obj.Command_Error], {["Done"], [""]}, (length(sampleData)/120000) * 20); % wait 20s per 120kb
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("File write not successful.");
                disp(allLines);
                response = allLines;
                return;
            end
		    response = foundLine;
        end

        % function response = readFile(obj, filename)
        %     % filename of the file to be read
        %     response = [];
        %     obj.clearCommandLog(obj.Command_ReadFile)
		% 	obj.sendCommand("" + obj.Command_ReadFile + obj.Param_Delimiter + confirmation + obj.Command_Delimiter);
		% 	[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_ReadFile, obj.Command_Error], {["Finished"], [""]}, 10);
        %     if isempty(foundChar) || foundChar == obj.Command_Error
        %         disp("Error when running readFile command.");
        %         disp(allLines);
        %         return;
        %     end
		% 	response = foundLine;
        % end

        function response = deleteFile(obj, filename)
            % deleteFile Used to delete a file from internal storage.
            %
            %   filename - the file to be deleted
            response = [];
            obj.clearCommandLog(obj.Command_DeleteFile)
			obj.sendToDevice("" + obj.Command_DeleteFile + obj.Param_Delimiter + filename + obj.Param_Delimiter + filename + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_DeleteFile, obj.Command_Error], {["Finished"], [""]}, 10);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running deleteFile command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = deleteAllFiles(obj, confirmation)
            % deleteAllFiles Used to delete all files from internal storage
            %
            %   confirmation parameter should contain the string "confirmation"
            response = [];
            obj.clearCommandLog(obj.Command_DeleteAllFiles)
			obj.sendToDevice("" + obj.Command_DeleteAllFiles + obj.Param_Delimiter + confirmation + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_DeleteAllFiles, obj.Command_Error], {["Finished"], [""]}, 15);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running deleteAllFiles command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        






        function response = getMaxBrightness(obj)
            % getMaxBrightness Used to read the maximum brightness levels of the central or ring output channels.
            response = [];
            obj.clearCommandLog(obj.Command_GetMaxBrightness)
			obj.sendToDevice("" + obj.Command_GetMaxBrightness + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_GetMaxBrightness, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running getMaxBrightness command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = setMaxBrightness(obj, setRingValue, newMaxValue, password)
            % setMaxBrightness Used to set the maximum brightness level of either the central or ring LEDs.
            %
            %   setRingValue should be 1 to set the max brightness of the ring LEDs or 0 to set the max brightness of the central LED
            %   newMaxValue is the value to use for max brightness
            %   password is the value to limit access to this command
            response = [];
            obj.clearCommandLog(obj.Command_SetMaxBrightness)
			obj.sendToDevice("" + obj.Command_SetMaxBrightness + obj.Param_Delimiter + setRingValue + obj.Param_Delimiter + newMaxValue + obj.Param_Delimiter + password + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_SetMaxBrightness, obj.Command_Error], {[""], [""]}, 5);
            if foundChar == obj.Command_Error
                disp("Error when running setMaxBrightness command.");
                disp(allLines);
                return;
            end
			response = 1;
        end

        function response = getLuxState(obj)
            % getLuxState Used to read the state of the intensity control switch on the back of the device.
            response = [];
            obj.clearCommandLog(obj.Command_GetLUXState)
			obj.sendToDevice("" + obj.Command_GetLUXState + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_GetLUXState, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running getLuxState command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end





        function response = getTemperatures(obj)
            % getTemperatures Used to read the temperatures of the 3 sensors within the device. Max value for each sensor is 53 degrees.
            response = [];
            obj.clearCommandLog(obj.Command_GetTemperatures)
			obj.sendToDevice("" + obj.Command_GetTemperatures + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_GetTemperatures, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running getTemperatures command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = getFanSpeeds(obj)
            % getFanSpeeds Reads the current RPM of the fans.
            response = [];
            obj.clearCommandLog(obj.Command_GetFanSpeeds)
			obj.sendToDevice("" + obj.Command_GetFanSpeeds + obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_GetFanSpeeds, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running getFanSpeeds command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end

        function response = setFanSpeed(obj, fanNum, speedPercent)
            % setFanSpeed Used to manually control the fan speed. Fans can be controlled independently and set to a percentage between 0 (not actually off) and 100. Setting a value above 100 returns the fans to auto mode.
            %
            %   fanNum - 1 or 2 to set the value for each fan
            %   speedPercent - the percentage of max fan speed from 0-100
            response = [];
            obj.clearCommandLog(obj.Command_SetFanSpeeds)
			obj.sendToDevice("" + obj.Command_SetFanSpeeds + obj.Param_Delimiter + fanNum + obj.Param_Delimiter + speedPercent +  obj.Command_Delimiter);
			[foundChar, foundLine, allLines] = obj.readUntilLine([obj.Command_SetFanSpeeds, obj.Command_Error], {[""], [""]}, 5);
            if isempty(foundChar) || foundChar == obj.Command_Error
                disp("Error when running setFanSpeed command.");
                disp(allLines);
                return;
            end
			response = foundLine;
        end
	end

	methods(Static)

        function returnCode = serialThreadFunction(portName, Command_List, shouldWriteToLog, workingDir)
            % serialThreadFunction This function is used for the thread that manages the serial port in the background. It connects to the specified port, initiates the file-based buffers, and then both sends to the device anything in the transmit buffer and sorts received messages by their command identifier (first character of the line).
            %
            %   portName - The serial port name to connect to
            %   Command_List - a list of command identifiers to make buffer files for
            %   shouldWriteToLog - Whether the thread should log all incoming and outgoing messages to the 'DeviceLog.txt' file.
            %   workingDir - The directory in which the StrobeDevice folder has been created in which the buffer files can be contained.
            %
            % This thread begins by making the 'ThreadIsRunning.txt' file and this file is deleted whenever the thread terminates safely.
            % If the connection to the provided serial port name fails, this thread aborts.
            % The thread then creates a transfer buffer and buffer file for each of the chars in the command list and aborts if it cannot.
            % If there is data in the transfer file, this thread reads it and sends it over serial to the device.
            % The thread then attempts to read serial data from the device, if this succeeds:
            %   Each line of the serial data is sorted according to the first character of that line as device messages follow the form of:
            %   e.g. "E: Error"
            %   The sorted lines are added to their respective buffer files according to this command character.
            %
            % MATLAB functions in the main thread then look for command responses in these buffer files.

            returnCode = -1;
            % try
                disp("Creating thread isRunning file");
                try
				    fid = fopen(fullfile(cd, "StrobeDevice", "ThreadIsRunning.txt"), 'at' );
				    fclose(fid);
			    catch err
				    disp("Error when creating log file for 'ThreadIsRunning'");
				    disp(err);
                end

                disp("Starting Serial Thread");
    
                % Try to connect to serial port using specified parameters
                if ~ismember(serialportlist('available'), portName)
                    delete(fullfile(workingDir, "StrobeDevice", "ThreadIsRunning.txt"));
                end
    
                deviceSerialPort = serialport(portName, 250000, 'Timeout', 0.1);
    
                if isempty(deviceSerialPort)
                    % If we failed to connect, terminate this thread and show
                    % that we have terminated
                    delete(fullfile(workingDir, "StrobeDevice", "ThreadIsRunning.txt"));
                    return;
                end
               
                lastwarn('');
			    warning("off", "serialport:serialport:ReadlineWarning")
    % 			response = readline(deviceSerialPort);
    % 			disp("Response: " + response);
    % 			warning("on", "serialport:serialport:ReadlineWarning")
			    deviceSerialPort.Timeout = 1;
    
                % Connection successful, create communication files
                disp("Creating command files in buffer directory");
                for i=1:length(Command_List)
                    try
					    fid = fopen(fullfile(workingDir, "StrobeDevice", "Command_" + Command_List(i) + ".txt"), 'at' );
					    fclose(fid);
				    catch err
					    disp("Error when creating log file for '" + Command_List(i) + "'");
					    disp(err);
                    end
                end
    
                disp("Creating transmit bufferfile");
                try
				    fid = fopen(fullfile(workingDir, "StrobeDevice", "TransmitBuffer.txt"), 'at' );
				    fclose(fid);
			    catch err
				    disp("Error when creating log file for 'TransmitBuffer.txt'");
				    disp(err);
                end
    
                disp("Creating device communication log file");
			    if ~isfile(fullfile(workingDir, "DeviceLog.txt"))
				    try
					    fid = fopen(fullfile(workingDir, "DeviceLog.txt"), 'at' );
                        if shouldWriteToLog
					        fprintf(fid, "RX (" + datestr(datetime('now'), 'mm/dd/yy HH:MM:SS.FFF') + "): " + "Connected to device on Port " + portName + "\n");
                        end
					    fclose(fid);
				    catch err
					    disp("Error when creating log file");
					    disp(err);
				    end
                end
    
			    while ~isfile(fullfile(workingDir, "StrobeDevice", "ThreadShouldStop.txt")) && isfile(fullfile(workingDir, "StrobeDevice", "ThreadIsRunning.txt"))
    
                    % Read transmit buffer and transmit contents in batches
                    transmitData = [];
                    % try
                        txBufSize = dir(fullfile(workingDir, "StrobeDevice", "TransmitBuffer.txt")).bytes;
                        if txBufSize > 0
                            fid = fopen(fullfile(workingDir, "StrobeDevice", "TransmitBuffer.txt"), 'r' );
                            if fid < 0 
                                disp("Transmit Buffer Not Found. (fid = " + fid + ")");
                            elseif fid == 0
                                disp("Transmit Buffer Busy.");
                            else
                                transmitData = fread(fid);
                                fclose(fid);
                                if ~isempty(transmitData) && ~strcmp(transmitData, "")
                                    fid = fopen(fullfile(workingDir, "StrobeDevice", "TransmitBuffer.txt"), 'wt' );
                                    fclose(fid);
                                end
                            end
                        end
                    % catch 
				    % end
                    
                    if ~isempty(transmitData) && ~strcmp(transmitData, "")
                        if shouldWriteToLog
			                try
				                fid = fopen(fullfile(workingDir, "DeviceLog.txt"), 'a' );
                                if length(transmitData) < 2000
				                    fprintf(fid, "TX (" + datestr(datetime('now'), 'mm/dd/yy HH:MM:SS.FFF') + "): " + convertCharsToStrings(char(transmitData)) + "\n");
                                else
                                    fprintf(fid, "TX (" + datestr(datetime('now'), 'mm/dd/yy HH:MM:SS.FFF') + "): " + length(transmitData) + " bytes start\n");
                                end
				                fclose(fid);
			                catch err
				                disp("Error when creating log file")
				                disp(err);
			                end
                        end
                        batchSize = 12000; % Send only 2kbytes at a time
                        for i = 0:(ceil(length(transmitData)/batchSize)-1)
                            try
				                fid = fopen(fullfile(workingDir, "DeviceLog.txt"), 'at' );
                                fprintf(fid, "TX (" + datestr(datetime('now'), 'mm/dd/yy HH:MM:SS.FFF') + "): Sending " + (1+(i*batchSize)) + " -> " + (1+min(((i+1)*batchSize-1), length(transmitData)-1)) + " bytes\n");
				                fclose(fid);
			                catch err
				                disp("Error when creating log file")
				                disp(err);
 			                end
                            if i > 0
                                deviceSerialPort.flush("output");
                                pause(0.1);
                            end
                            disp((1+(i*batchSize)) + " -> " + (1+min(((i+1)*batchSize-1), length(transmitData)-1)))
                            write(deviceSerialPort, transmitData((1+(i*batchSize)):(1+min(((i+1)*batchSize-1), length(transmitData)-1))), "uint8");
                            disp(".")
                        end
                        if length(transmitData) < 2000
                             try
				                fid = fopen(fullfile(workingDir, "DeviceLog.txt"), 'at' );
                                fprintf(fid, "TX (" + datestr(datetime('now'), 'mm/dd/yy HH:MM:SS.FFF') + "): " + length(transmitData) + " bytes done\n");
				                fclose(fid);
			                catch err
				                disp("Error when creating log file")
				                disp(err);
 			                end
                        end
                    end
    
                    % Read serial port and route to appropriate command files
                    strings = [];
				    strings = readline(deviceSerialPort);
				    if ~isempty(strings)
					    stringLine = convertStringsToChars(strings);
					    if shouldWriteToLog
						    try
							    fid = fopen(fullfile(workingDir, "DeviceLog.txt"), 'at' );
							    fprintf(fid, "RX (" + datestr(datetime('now'), 'mm/dd/yy HH:MM:SS.FFF') + "): " + stringLine);
							    fclose(fid);
						    catch err
							    disp("Error when creating log file")
							    disp(err);
						    end
                        end
					    if ~isempty(stringLine)
                            lineContents = strtrim(stringLine(3:length(stringLine)));
                            try
						        if ismember(stringLine(1), Command_List)
					                fid = fopen(fullfile(workingDir, "StrobeDevice", "Command_" + stringLine(1) + ".txt"), 'at' );
                                else
                                    fid = fopen(fullfile(workingDir, "StrobeDevice", "Command_Unknown.txt"), 'at' );
                                end
                                fprintf(fid, lineContents + "\n");
				                fclose(fid);
			                catch err
				                disp("Error when creating log file for '" + stringLine(1) + "'");
				                disp(err);
						    end
					    end
                    end
                    pause(0.01);
                end
            % catch err
            %     disp(err)
            % end
            try
                disp("Terminating Serial Thread");
                deviceSerialPort.delete;
			    deviceSerialPort = [];
                delete(fullfile(workingDir, "StrobeDevice", "ThreadIsRunning.txt"));
            catch err
                disp(err)
            end
            returnCode = 0; % Terminated properly
            return;
        end
    end

    properties(Constant, Access = private)
        Interface_Version = "v1.1" % The software version of the device that matches this MATLAB interface.

        Param_Delimiter = ',' % The character used to separate values in command parameters.
        Command_; % These constants store the characters used for each of the device's serial command interface.
		Command_Delimiter = ';'
        Command_Error = 'E'

		Command_Help = 'H'
        Command_CancelStrobe = 'C'
		Command_DeviceInfo = '0'
		Command_GetDeviceState = 'S'

		Command_SetLEDState = '1'
		Command_SetChannelOutput = '2'
		Command_SetOutputState = '3'
		Command_PlayStrobe = '4'
		Command_PlayStrobeFile = '5'
        Command_FixedRateStrobe = '6'

		Command_GetFileList = 'Q'
		Command_WriteFile = 'W'
		Command_ReadFile = 'R'
		Command_DeleteFile = 'T'
		Command_DeleteAllFiles = 'Y'

		Command_SetMaxBrightness = 'O'
		Command_GetMaxBrightness = 'P'
		Command_GetLUXState = 'L'

		Command_GetTemperatures = 'A'
		Command_GetFanSpeeds = 'F'
		Command_SetFanSpeeds = 'G'
    end
end


