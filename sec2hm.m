function [H M] = sec2hm(seconds,decimals)
	if nargin == 1
		decimals = 1;
	end
	prec = 10^(decimals);
	seconds = round((seconds*prec)/60)*60/prec;
	M = mod(seconds/60,60);
	H = (seconds-M*60)/3600;
	return
end