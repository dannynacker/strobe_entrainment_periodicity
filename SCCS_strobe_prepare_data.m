function preparedStrobeData1D = SCCS_strobe_prepare_data(sampled_strobe_sequence)

%% Brightness of the light
centralBrightness = 0;
ringBrightness = 255;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function converts a sampled strobe sequence (as returned by sample_strobe.m)
% to a format suitable for the Sussex CCS strobe device. See load_SCCS_device.m.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

nsamples = length(sampled_strobe_sequence);

% Repeat sampled values for all 8 LEDs:

ledONOFFsamples = repmat(sampled_strobe_sequence, 1, 8);

% Next we need to convert this array of 8 bits (1's or 0's) for each sample
% into a single 8-bit unsigned integer using this small helper function:

ledONOFFBitmap = binary8ToUint8(ledONOFFsamples); % Use the strobe signal to turn on and off the ring LED states

% (this function is defined at the end of this file)
%
% Since we are controlling all the leds with the same input signal the ledONBitmap
% should be a single column now contain the following:
%
% [ 255;
%
% ...;
%
% 0;
%
% ...;
%
% 255;
%
% ...] and so on.
%
% We need to append to the right of each of these values the brightness values
% for each channel, these values are all the same so we generate a single row
% with the following command:

dacChannelValues = [centralBrightness, ringBrightness, ringBrightness, ringBrightness, ringBrightness];

% And then repeat that row for every single sample:

dacChannelValuesPerSample = repmat(dacChannelValues, [nsamples, 1]);

% and append them to the ledONOFFBitmap values:

preparedStrobeData2D = [ledONOFFBitmap, dacChannelValuesPerSample];

% This should be a 2D matrix where each row contains a single data packet and
% there is a row for each displayed sample.
%
% In order to transmit this data we need to append the rows into a single 1D
% sequence using the following command:

preparedStrobeData1D = reshape(preparedStrobeData2D', [size(preparedStrobeData2D, 1) * size(preparedStrobeData2D, 2), 1])';

% This data can now be loaded on to the device: see load_SCCS_device.m

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function value = binary8ToUint8(bitArray)
    value = sum([2^7 2^6, 2^5, 2^4, 2^3, 2^2, 2^1, 2^0] .* bitArray, 2);
end
