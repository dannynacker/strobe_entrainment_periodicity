function osignal = regularise_strobe(signal,rmode)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function regularises the strobe sequence 'signal' by dealing with overlaps.
%
% NOTE: 'signal' events must be sorted!
%
% Overlapping flashes are dealt with sequentially as follows:
%
% rmode == 1 : merge/subsume
% rmode == 2 : always truncate
% rmode == 3 : ignore later flash
% rmode == 4 : ignore earlier flash.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

assert(ismatrix(signal) && size(signal,2) == 2,'Bad signal - must be a 2-column matrix');
assert(isscalar(rmode) && isnumeric(rmode) && any(rmode == 1:4),'Regularisation mode must be an integer in range 1 - 4');

nevents = size(signal,1);

osignal = zeros(nevents,2);

e = 1;
o = 0;

if rmode == 1 % merge/subsume

	while e < nevents
		o = o+1;
		osignal(o,:) = signal(e,:); % copy event
		if signal(e+1,1) <= signal(e,1)+signal(e,2) % clash
			if signal(e+1,1) + signal(e+1,2) <= signal(e,1)+signal(e,2) % contained
				% do nothing (just ignore event e+1)
			else                                                        % overlap
				osignal(o,2) = signal(e+1,1) - signal(e,1) + signal(e+1,2);
			end
			e = e+2; % skip past event e+1
		else % no clash
			e = e+1;
		end
	end

elseif rmode == 2 % always truncate

	while e < nevents
		o = o+1;
		osignal(o,:) = signal(e,:); % copy event
		if signal(e+1,1) <= signal(e,1)+signal(e,2) % clash
			if signal(e+1,1) + signal(e+1,2) <= signal(e,1)+signal(e,2) % contained
				osignal(o,2) = signal(e+1,1) - signal(e,1) + signal(e+1,2);
			else                                                        % overlap
				% do nothing (just ignore event e+1)
			end
			e = e+2; % skip past event e+1
		else % no clash
			e = e+1;
		end
	end

elseif rmode == 3 % later event ignored

	while e < nevents
		o = o+1;
		osignal(o,:) = signal(e,:); % copy event
		if signal(e+1,1) <= signal(e,1)+signal(e,2) % clash
			% do nothing (just ignore event e+1)
			e = e+2; % skip past event e+1
		else % no clash
			e = e+1;
		end
	end

elseif rmode == 4 % earlier event ignored

	while e < nevents
		o = o+1;
		if signal(e+1,1) <= signal(e,1)+signal(e,2) % clash
			osignal(o,:) = signal(e+1,:); % copy later event
			e = e+2; % skip past event e+1
		else % no clash
			osignal(o,:) = signal(e,:); % copy event
			e = e+1;
		end
	end

end

% last event

if e == nevents % in case last event was ignored!
	o = o+1;
	osignal(o,:) = signal(nevents,:); % copy event
end

% truncate signal

osignal = osignal(1:o,:);
