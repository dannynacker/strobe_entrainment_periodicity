comPort = "COM18"; % You can use serialportlist() to list all available ports
filename = "Example.txt";

% Before this script is run, one of the StrobeGen scripts should be executed
if ~exist('preparedStrobeData1D', 'var')
    disp("Cannot find preparedStrobeData1D");
    disp("No strobe data prepared, run StrobeGenN.m first");
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

disp("Re-reading file list.")
fileListAfterWrite = device.getFileList();
pause(1);

disp("Playing strobe file...")
disp(device.playStrobeFile(filename, (length(preparedStrobeData1D)/12000) + 5)); % Play the newly written file and wait N+5 seconds for it to confirm that it has finished.
pause(1)

disp("Getting device temps:")
disp(device.getTemperatures()) % Print the device temperatures.

pause(5)
% When finished wrap up and close the port, stopping the serial thread.
device.closePort();
clear('device') % Clear the device variable so it is recreated next execution