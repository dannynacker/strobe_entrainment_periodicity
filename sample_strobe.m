function [samples,ts] = sample_strobe(signal,fs,T)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function samples the signal at frequency fs, over a time segment of length T.
% The sample time series and a vector ts of time stamps are returned.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ndt = T*fs; % number of samples - must be an integer
assert(ceil(ndt) == ndt,'Number of samples must be an integer (check total time and sampling frequency)');
ndt1 = ndt+1;

assert(all(signal(:,1) >= 0),'On times must be nonnegative');
assert(all(signal(:,2) >  0),'Durations must be positive'  );

ts = (0:ndt)'/fs;        % sample time stamps
samples = zeros(ndt1,1); % time series (binary)

% Quantise to sample frequency

son  = round(signal(:,1)*fs)+1; % on sample numbers
sdur = ceil(signal(:,2)*fs);    % numbers of on samples (duration)
soff = son+sdur-1;              % off sample numbers

for e = 1:length(son)
	if son(e)  > ndt1, continue;       end % on time out of range - ignore
	if soff(e) > ndt1, soff(e) = ndt1; end % ensure on till end of time series
	samples(son(e):soff(e)) = 1;           % turn on for duration
end

