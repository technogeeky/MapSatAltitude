function [H M S] = sec2hms(seconds)
	S = mod(seconds,60);
	M = mod( (seconds-S)/60,60);
	H = (((seconds-S)/60)-M)/60;
	return
end