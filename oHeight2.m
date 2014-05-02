function h = oHeight2(T,R,GM)
	if nargin < 2				% this looks like a default to Kerbin if only 1 argument is passed.
		R = 6e5;
		GM = 3531600000000;
	end
	h = (T.^2*GM/(4*pi^2)).^(1/3)-R;
	return
end
