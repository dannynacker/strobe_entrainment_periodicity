function osignal = regularise_strobe(signal,rmode,mifd)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function regularises the strobe sequence 'signal' by dealing with overlaps.
%
% NOTE: 'signal' events must be sorted!
%
% Overlapping flashes are dealt with sequentially as follows:
%
% rmode == 1 : merge
% rmode == 2 : truncate
% rmode == 3 : ignore later flash (recommended)
% rmode == 4 : ignore earlier flash.
%
% mifd is the minimum inter-flash duration in seconds; set to something like 10/fs,
% where fs is sampling frequency in Hz.
%
% Flashes are processed sequentially in time. Note that modes 3 and 4 preserve flash
% "on" durations; modes 1 and 2 may not.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

assert(ismatrix(signal) && size(signal,2) == 2,'Bad signal - must be a 2-column matrix');
assert(isscalar(rmode) && isnumeric(rmode) && any(rmode == 1:4),'Regularisation mode must be an integer in range 1 - 4');

if nargin < 3 || isempty(mifd), mifd = 0.005; end % set to something like 10/fs

nevents = size(signal,1);

osignal = zeros(nevents,2);

e = 1;
o = 0;

switch rmode

	case 1 % merge/subsume overlapping events

		while e < nevents
			to = signal(e,1)+signal(e,2) + mifd; % off time + minimum inter-flash gap
			o = o+1;
			osignal(o,1) = signal(e,1); % copy event start time
			% skip subsequent overlapping events and save latest off time
			e = e+1;
			while e <= nevents && signal(e,1) <= to % overlap
				to1 = signal(e,1)+signal(e,2); % off time
				if to1 > to, to = to1; end     % update off time
				e = e+1; % next event
			end
			osignal(o,2) = to-osignal(o,1); % new duration
		end
		if e == nevents % in case last event was ignored!
			o = o+1;
			osignal(o,:) = signal(nevents,:); % copy event
		end

	case 2 % truncate overlapping events

		while e < nevents
			to = signal(e,1)+signal(e,2); % off time
			o = o+1;
			osignal(o,1) = signal(e,1); % copy event start time
			% skip subsequent overlapping events and save earliest off time
			e = e+1;
			while e <= nevents && signal(e,1) <= to % overlap
				to1 = signal(e,1)+signal(e,2); % off time
				if to1 < to, to = to1; end     % update off time
				e = e+1; % next event
			end
			osignal(o,2) = to-osignal(o,1); % new duration
		end
		if e == nevents % in case last event was ignored!
			o = o+1;
			osignal(o,:) = signal(nevents,:); % copy event
		end

	case 3 % later overlapping events ignored

		while e < nevents
			to = signal(e,1)+signal(e,2) + mifd; % off time + minimum inter-flash gap
			o = o+1;
			osignal(o,:) = signal(e,:);   % copy event
			% skip subsequent overlapping events
			e = e+1;
			while e <= nevents && signal(e,1) <= to % overlap
				e = e+1; % skip event
			end
		end
		if e == nevents % in case last event was ignored!
			o = o+1;
			osignal(o,:) = signal(e,:); % copy event
		end

	case 4 % earlier overlapping events ignored

		to = signal(e,1)+signal(e,2) + mifd; % off time + minimum inter-flash gap
		while e < nevents && signal(e,1) <= to % overlap
			e = e+1; % skip event
		end
		o = o+1;
		osignal(o,:) = signal(e,:);  % copy event
		while e < nevents
			to = signal(e,1)+signal(e,2) + mifd; % off time + minimum inter-flash gap
			% skip to last overlapping event
			e = e+1;
			while e < nevents && signal(e,1) <= to % overlap
				e = e+1; % skip event
			end
			o = o+1;
			osignal(o,:) = signal(e,:);  % copy event
		end

end % switch

% truncate signal as appropriate

osignal = osignal(1:o,:);
