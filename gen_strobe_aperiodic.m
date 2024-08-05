function [signal,Fe,descrip] = gen_strobe_aperiodic(F,T,osig,relo,ondur,dsig,rmode,mifd,seed)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function generates a strobe sequence ("signal") with average frequency F over
% a time segment of length T, where the phase (cycle onset time) and cycle "on"
% duration can be fixed or variable. A signal is a 2-column matrix. The first column
% contains flash onset time stamps (these should be sorted-ascending), the second
% column flash durations.
%
% The parameters osig and relo specify the onset time of the next cycle. This may be
% periodic with frequency F, a Poisson process with mean equal to one cycle (cycle
% length is 1/F), or jittered. In the jittered case, the parameter relo specifies
% whether the onset time is Gamma-distributed relative to the onset time of the
% previous cycle, with mean 1/F and standard deviation osig; otherwise (default)
% onset time is periodic with Gaussian jitter of standard deviation osig.
%
% The parameter ondur sets the cycle "on" duration; by default, ondur is set to half
% a cycle. The parameter dsig specifies whether the "on" duration is fixed, or Gamma-
% distributed with mean ondur and standard deviation dsig.
%
% The parameter rmode specifies how to regularise the signal (deal with overlaps).
% rmode == 3 (default) means later overlapping flashes are ignored. See
% regularise_strobe.m for details.
%
% The parameter seed sets the pseudorandom number generation seed; empty for no
% seeding (default);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% F        strobe frequency (Hz)
% T        total sequence time (secs)
% osig     onset time: 'periodic' (default), 'Poisson', or jitter std. dev (ms)
% relo     relative onset time with Gamma jitter? Else (default) periodic onset time with Gaussian jitter
% ondur    mean cycle "on" duration: 'hcycle' (default = half-cycle), or length (ms)
% dsig     "on" duration: 'fixed' (default), or jitter std. dev (ms)
% rmode    regularisation mode (deal with overlapping flashes): 1 - 4 (default is 3 = ignore later overlapping flashes)
% mifd     minimum inter-flash duration in seconds; set to something like 10/fs
% seed     PRNG seed; empty for no seeding (default)
%
% signal   the signal, a 2-column matrix, where the first column contains time stamps
%          for the cycle onset, and the second column "on time" durations.
%
% Fe       the "effective frequency" (number of cycles divided by total time T)
% descrip  a string containing a description of the signal
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3 || isempty(osig),  osig  = 'periodic'; end
if nargin < 4 || isempty(relo),  relo  =  false;     end
if nargin < 5 || isempty(ondur), ondur = 'hcycle';   end
if nargin < 6 || isempty(dsig),  dsig  = 'fixed';    end
if nargin < 7 || isempty(rmode), rmode =  3;         end % 3 = ignore later overlapping flashes (recommended)
if nargin < 8  mifd = []; end % to use regularise_strobe() default
if nargin < 9, seed = []; end

mu = 1/F;  % mean onset time
Te = T-mu; % latest possible cycle onset time

if strcmpi(ondur,'hcycle')
	ondur = 1/(2*F);
	shcycle = 'half-cycle, ';
elseif isnumeric(ondur) && isscalar(ondur) && ondur > eps
	ondur = ondur/1000; % convert from ms to secs
	shcycle = '';
else
	error('Bad mean on-duration specification');
end

% Simulation cycle onset modes

if     strcmpi(osig,'periodic')
	omode = 1;
	sosig = sprintf('periodic (\\mu = %g ms)',1000*mu);
elseif strcmpi(osig,'Poisson')
	omode = 2;
	sosig = sprintf('Poisson (\\mu = %g ms)',1000*mu);
elseif isnumeric(osig) && isscalar(osig)
	if isinf(osig)
		omode = 2;
		sosig = sprintf('Poisson (\\mu = %g ms)',1000*mu);
	elseif osig > eps
		omode  = 3; % Gamma/Gaussian jitter
		osig = osig/1000; % convert from ms to secs
		if relo
			sosig  = sprintf('relative, \\Gamma(\\mu = %g ms, \\sigma = %g ms)',1000*mu,1000*osig);
			ovar   = osig^2;
			oalpha = (mu^2)/ovar;
			obeta  = ovar/mu;
		else
			sosig  = sprintf('periodic, N(\\mu = %g ms, \\sigma = %g ms)',1000*mu,1000*osig);
		end
	else
		omode = 1;
		sosig = sprintf('periodic (\\mu = %g ms)',1000*mu);
	end
else
	error('Bad onset time specification');
end

% Simulation "on" duration modes

if     strcmpi(dsig,'fixed')
	dmode = 1;
	sdsig = sprintf('%sfixed (\\mu = %g)',shcycle,1000*ondur);
elseif isnumeric(dsig) && isscalar(dsig)
	if dsig > eps
		dmode  = 2; % Gamma jitter
		dsig = dsig/1000; % convert from ms to secs
		sdsig  = sprintf('%s\\Gamma(\\mu = %g ms, \\sigma = %g ms)',shcycle,1000*ondur,1000*dsig);
		dvar   = dsig^2;
		dalpha = (ondur^2)/dvar;
		dbeta  = dvar/ondur;
	else
		dmode = 1;
		sdsig = sprintf('%sfixed (\\mu = %g)',shcycle,1000*ondur);
	end
else
	error('Bad duration specification');
end

nev = ceil(1.5*T*F); % number of events (bigger than necessary)

signal = zeros(nev,2); % column 1 is time stamp, column 2 is duration

if ~isempty(seed)
	rngstate = rng(seed);
end

e = 0;
t = 0;

switch omode

case 1 % fixed onset time

	switch dmode

	case 1 % fixed duration

		while true
			if t > Te, break; end
			e = e+1;
			signal(e,:) = [t ondur];
			t = t+mu; % time of next event
		end

	case 2 % Gamma-jittered duration

		while true
			if t > Te, break; end
			tdur = gamrnd(dalpha,dbeta); % Gamma duration jitter
			if tdur < eps, continue; end % negligible duration
			e = e+1;
			signal(e,:) = [t tdur];
			t = t+mu; % time of next event
		end

	end % switch dmode

case 2 % Poisson onset time

	switch dmode

	case 1 % fixed duration

		while true
			if t > Te, break; end
			e = e+1;
			signal(e,:) = [t ondur];
			t = t+exprnd(mu); % time of next event
		end

	case 2 % Gamma-jittered duration

		while true
			if t > Te, break; end
			tdur = gamrnd(dalpha,dbeta); % Gamma duration jitter
			if tdur < eps, continue; end % negligible duration
			e = e+1;
			signal(e,:) = [t tdur];
			t = t+exprnd(mu); % time of next event
		end

	end % switch dmode

case 3 % Jittered onset time

	if relo

		switch dmode

		case 1 % fixed duration

			while true
				if t > Te, break; end
				e = e+1;
				signal(e,:) = [t ondur];
				t = t+gamrnd(oalpha,obeta); % time of next event
			end

		case 2 % Gamma-jittered duration

			while true
				if t > Te, break; end
				tdur = gamrnd(dalpha,dbeta); % Gamma duration jitter
				if tdur < eps, continue; end % negligible duration
				e = e+1;
				signal(e,:) = [t tdur];
				t = t+gamrnd(oalpha,obeta); % time of next event
			end

		end % switch dmode

	else % not relo

		switch dmode

		case 1 % fixed duration

			while true
				if t > Te, break; end
				ton = t+osig*randn;          % Gaussian onset jitter
				if ton < 0, continue; end    % unlikely, but could potentially be negative
				e = e+1;
				signal(e,:) = [ton ondur];
				t = t+mu; % mean time of next event
			end

		case 2 % Gamma-jittered duration

			while true
				if t > Te, break; end
				ton = t+osig*randn;          % Gaussian onset jitter
				if ton < 0, continue; end    % unlikely, but could potentially be negative
				tdur = gamrnd(dalpha,dbeta); % Gamma duration jitter
				if tdur < eps, continue; end % negligible duration
				e = e+1;
				signal(e,:) = [ton tdur];
				t = t+mu; % mean time of next event
			end

		end % switch dmode

	end % relo

end % switch omode

if ~isempty(seed)
	rng(rngstate);
end

% Truncate signal to actual number of events

signal = signal(1:e,:);

% Sort events by time stamp (in case necessary)

signal = sortrows(signal);

% Regularise signal (deal with flash overlaps)

signal = regularise_strobe(signal,rmode,mifd);

% Effective frequency (flashes per total time duration)

Fe = size(signal,1)/T;

if nargout > 2
	descrip = sprintf('mean strobe frequency = %g Hz (effective frequency = %g Hz)\n\ncycle onset: %s,  cycle "on" duration: %s',F,Fe,sosig,sdsig);
end
