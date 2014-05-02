function T = oPeriod2(h,R,GM)
	if nargin < 2				% this looks like a default to Kerbin if only 1 argument is passed. eww!
		R = 6e5;
		GM = 3531600000000;
	end
	T = 2*pi*((R+h).^3./GM).^(0.5);
%	T = 2*pi*(R+h).*((R+h)./(1.63*R^2)).^(0.5);
	return
end
