function signal = gen_strobe_periodic(F,T,ondur)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function generates a periodic strobe sequence ("signal") with frequency F over
% a time segment of length T. The parameter ondur sets the cycle "on" duration; by
% default, ondur is set to half a cycle (cycle length is 1/F). A signal is a 2-column
% matrix. The first column contains flash onset time stamps (these should be sorted-
% ascending), the second column flash durations.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% F        strobe frequency (Hz)
% T        total sequence time (secs)
% ondur    cycle "on" duration: 'hcycle' (default = half-cycle), or length (ms)
%
% signal   the signal, a 2-column matrix, where the first column contains time stamps
%          for the cycle onset, and the second column cycle "on" durations.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3 || isempty(ondur), ondur = 'hcycle'; end

if strcmpi(ondur,'hcycle')
	ondur = 1/(2*F);
elseif isnumeric(ondur) && isscalar(ondur) && ondur > eps
	ondur = ondur/1000; % convert from ms to secs
else
	error('Bad mean on-duration specification');
end

mu = 1/F;  % onset time
Te = T-mu; % latest possible cycle onset time

nev = ceil(1.5*T*F); % number of events (bigger than necessary)

signal = zeros(nev,2); % column 1 is time stamp, column 2 is duration

e = 0; % number of events
t = 0; % current time

while true
	ton = t;
	if ton > Te, break; end
	e = e+1;
	signal(e,:) = [ton ondur];
	t = t+mu;
end

% Truncate signal to actual number of events

signal = signal(1:e,:);

% Effective frequency (flashes per total time duration)

Fe = e/T;
