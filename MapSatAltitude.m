clear all
close all


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	1. What scanner are we discussing?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

scanner = input('Scanner name? ', 's');
scanners = parseScannerInfo();
S = getScanner(scanners,scanner);


if isempty(S)
	printf('\nUnknown scanner: %s\n\n', scanner);
	return
end

disp(sprintf('[%s] Ideal Altitude Calculator.',S.LongName));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	2. What planet are we discussing?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


planet = input('Planet name? ','s');

planets = parsePlanetInfo();
P = getPlanet(planets,planet);
if isempty(P)
	printf('\nInvalid planet: %s\n\n',planet);
	return
end

R 	  = P.Radius;
planetDay = P.Day;
GM 	  = P.GM;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	3-4. How much sidelap (min, max) do we want?
%%%		This is a setting which may vary. I suspect, for scanners with
%%%		a small FOV (ie, the SAR), you may have to accept larger sidelap
%%%		and thus longer scanning times. (I guess: larger sidelap implies
%%%		longer scanning times.) If this tool was perfectly accurate, that
%%%		should be taken into account. But it's not perfect yet.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	1. Get minimum sidelap from user; and,
%%%	2. Default to (1.00) otherwise.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
inp_thresh = ...
	input('Minimum Sidelap? (Default is 1.00. Press Enter to skip) : ','s');
inp_thres2 = sscanf(inp_thresh,'%f');

if isempty(inp_thres2) || inp_thres2 < 0
	minthresh = 1.00; %1.25;
else
	minthresh = inp_thres2;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	1. Get maximum sidelap from user; and,
%%%	2. Default to (1.25) otherwise.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
inp_thresh = ...
	input('Maximum Sidelap? (Default is 1.25. Press Enter to skip) : ','s');
inp_thres2 = sscanf(inp_thresh,'%f');

if isempty(inp_thres2) || inp_thres2 < 0
	maxthresh = 1.25; %1.25;
else
	maxthresh = inp_thres2;
end
if maxthresh < minthresh
	disp('Maximum threshold cannot be lower than minimum threshold!');
	return;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: Altitude Step Multiplier?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
alt_stepmul = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	5. Numerical Resolution
%%%		This setting seems to relate to how many results will be returned.
%%%		(ie, higher resolution, more results)
%%%		
%%%		Also, for Earth (RSS) and The Moon (RSS), a very- or ultra-high
%%%		resolution was required to get any results!
%%%		
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
inp_res = ...
	input('Numerical Resolution? ("Uber","Very",["Hi"], or "Low".) : ','s');
resDisc = 'High';

if isempty(inp_res)
	rational_resolution = 1e-4;
	resDisc = 'High';
else
	if 	strcmpi(inp_res(1),'h')
		rational_resolution = 1e-4;
		resDisc = 'High';
	elseif strcmpi(inp_res(1),'l')
		rational_resolution = 1e-3;
		resDisc = 'Low';
	elseif strcmpi(inp_res(1),'v')
		rational_resolution = 1e-5;
		alt_stepmul = 1/2;
		resDisc = 'VeryHi';
	elseif strcmpi(inp_res(1),'u')
		rational_resolution = 1e-6;
		alt_stepmul = 1/4;
		resDisc = 'UltraHi';
	else
		rational_resolution = 1e-4;
	end
end
disp(sprintf('Rational Number Numerical Resolution: %s (%.2e)\n',resDisc,rational_resolution));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: Incliation Setting was commented out already.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% inp_incl = input('Inclination? (Default is 90. Press Enter to skip) : ','s');
% inp_incl = sscanf(inp_incl,'%f');
% if isempty(inp_incl) || inp_incl < 0
	% inclination = 90; %1.25;
% else
	% inclination = inp_incl;
% end
%inclination = 90;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: Does resonanceLimit actually do anything?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
resonanceLimit = 1*360; %just in case we want 720 degrees or something

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: What units is this in? I suspect degrees.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
max_width = 180; %maximum swath width; if we're getting larger than this then the planetoid is teeny,
				%at which point you don't need this tool anymore


%swath_poly = [19.0124437348151     0.304525138734149]; %experimentally-derived polynomial for swath width

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% We need to pick the correct FOV, and for laziness I have stored a HalfFov too (why does this need half fov?)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%surfscale = max(600000 / R,1);		% this, as noted below, gives a boost to
					% fov for bodies smaller than Kerbin
surfscale = 1;
hSCAN_FOV = (S.FOV * sqrt(surfscale)) / 2;

hFOV = (hSCAN_FOV/180*pi); % New lasers can spread up to 8 degrees on either side

scan_res = 200;  % New lasers have 200 points in a line that spread evenly based on ground distance

disp('');
disp('');


[dayh daym days] = sec2hms(planetDay);
syncorbit = oHeight2(planetDay,R,GM);

disp(sprintf('\nPlanet:     %s\nRadius:     %d km',planet,R/1000));
disp(sprintf('Sync.Orbit: %.2f km\nSOI:        %.2f km',syncorbit/1000,P.SOI/1000));
disp(sprintf('Day Length: %dh %2dm %ds',dayh,daym,days));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: Is this maxSwathAlt likely to be reached?
%%%		For the Mun and for SAR, this is 1.12e8 meters.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	NOTE:
%%%	Internally to SCANsat, the calculation for FOV would look like this:
%%%	2 * (749999 meters / 750000 meters) * sqrt(600000 meters/200000 meters)
%%%	^    ^^^^^^^^^^^^^   ^^^^^^^^^^^^^         ^^^^^^^^^^^^^ ^^^^^^^^^^^^^
%%%	fov   	altitude	"best"		1 Kerbin radius	  parentBody radius
%%%	    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^	^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
%%%		^ this part penalizes you		^ this part gives you a boost
%%%		  for being between minimum		scanning a smaller body than
%%%		  and best altitude			Kerbin, and cuts off when = 1
%%%		  and cuts when = 1			* also, this will probably need
%%%							  to be changed to support (RSS)
%%%
%%%	See SCANcontroller.cs for details.
%%%

maxSwathAlt  = R*cot(hFOV)-R;
%maxSwathAlt = R*(max_width-swath_poly(2))/swath_poly(1); %maximum swath width altitude

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Here we (evidently) pick the minimum altitude by looking at:
%%% 1. (hardcoded) 10e3
%%% 2. P.Atmo - The atmospheric height of the planet.
%%% 3. S.AltitudeMin - The minimum altitude the scanner will work at.
%%%
%%% And then, of course, we pick the maximum.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%minAlt = max(10e3,P.Atmo);
%minAlt = max(minAlt,S.AltitudeMin);

[minAlt minAltReason] = max([S.AltitudeMin,P.Atmo]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Here we pick the maximum altitude by looking at:
%%% 1. S.MaxAlt 	- The maximum altitude the scanner will function at.
%%% 2. P.SOI		- The height of the sphere of influence around the selected planet.
%%% 3. 4*syncorbit	- FIXME: Four, times the syncorbit.
%%% 4. maxSwathAlt	- FIXME: The maximum altiude our swathwidth works out?
%%%
%%% And then, of course, we pick the minimum.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[maxAlt maxAltReason] = min([S.AltitudeMax, P.SOI, 4*syncorbit, maxSwathAlt]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% FIXME: The following may need to be changed to accomidate the higher-altitude support.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

alt_stepsize = max(min((maxAlt-minAlt)/50000,25),0.5)*alt_stepmul;

if maxAlt > 1000e3
    alts = [minAlt:alt_stepsize/2:(500e3-alt_stepsize) 500e3:alt_stepsize*1:maxAlt];
else
    alts = minAlt:alt_stepsize:maxAlt;
end


disp(sprintf('\nScan line resolution: %d',scan_res));
disp(sprintf('Field of view: %f deg',hFOV*2*180/pi));
disp(sprintf('Sidelap range: %f - %f',minthresh,maxthresh));
disp(sprintf('Altitude Range: %.1f km - %.1f km in %.1f m steps (%i possible zones)',minAlt/1000,maxAlt/1000,alt_stepsize,numel(alts)));

qqq = sprintf('Minimum altitude chosen because:\n\t');
switch minAltReason
	case {1}
		qqq = [qqq sprintf('[%s] has a minimum range of %.1f km',S.LongName,S.AltitudeMin/1000)];
	case {2}
		qqq = [qqq sprintf('[%s] has an atmosphere until %.1f km', P.Name, P.Atmo/1000)];
%	case {3}
%		qqq = [qqq sprintf('because of a hardcoded limit of %.2f m. deal with it. ',10e3)];

end
disp(qqq);
disp('');


qqq = sprintf('Maximum Altitude chosen because:\n\t');
switch maxAltReason
	case {1}
		qqq = [qqq sprintf('[%s] has a maximum range of %.2f km',S.LongName,maxAlt/1000)];
	case {2}
		qqq = [qqq sprintf('[%s] sphere of influence ends at %.2f km', P.Name, P.SOI/1000)];
	case {3}
		qqq = [qqq sprintf('[%s] has a synchronous orbit at %.2f km', P.Name, syncorbit/1000)];
	case {4}
		qqq = [qqq sprintf('maximum swath width of %d degrees at %.2f km', max_width, maxSwathAlt/1000)];
end
disp(qqq);
disp('');

orbitalPeriods = oPeriod2(alts,R,GM);

% disp(sprintf('\norbital period: %.3f s',orbitalPeriods));

planetRotPerPeriod = (360./planetDay)*orbitalPeriods;	% FIXME: unused

														%swathWidths = 15*alts/R;
														%experimentally-defined swath widths
														%swathWidths = polyval([19.0124437348151     0.304525138734149],alts/R);

S1 = ((alts+R).*cot(hFOV)+sqrt(R.^2.*cot(hFOV).^2-alts.^2-2.*alts.*R))./(1+cot(hFOV).^2);
S2 = ((alts+R).*cot(hFOV)-sqrt(R.^2.*cot(hFOV).^2-alts.^2-2.*alts.*R))./(1+cot(hFOV).^2);
S  = min([S1;S2]);


swathWidths = (asin(S./R)*2)/pi*180;
swathWidthsCorr = swathWidths;			%% FIXME: presumably this means Corrected, but
						%% 	in that case, swathWidths should *never* be used again
						%% 	(and it is. both are used.)


														%swathWidthsCorrParameters = [2.5032e-011  1.5976e-005      2.2617]; %kerbin-specific tested ones
														%swathWidthsCorr = polyval(swathWidthsCorrParameters,alts);
														%swathWidthsC1 = swathWidths.*orbitalPeriods./planetDay; %this corrects for 'planet smear'
														%swathWidthsC2 = swathWidths*cosd(inclination); %this corrects for inclination skew
														%swathWidthsC3 = abs(swathWidths./sind(inclination).*(cosd(inclination)-orbitalPeriods./planetDay)); %3rd attempt at modelling skew&smear
														%swathWidthsCorr = swathWidths+swathWidthsC1+swathWidthsC2+swathWidthsC3;
														%swathWidthsCorr = swathWidths+swathWidthsC3;


tgtInclination = acosd(orbitalPeriods./planetDay);
orbitRats = orbitalPeriods./planetDay;

AorbitRats = (orbitRats+1)/2;
%mop = mod(orbitalPeriods,planetDay);			% FIXME: unused

[orbitRatN orbitRatD] = rat(AorbitRats,rational_resolution);




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 	DOCUMENTATION: rat() function
%%%
%%%	[n d] = rat (x, tol)
%%%
%%%    Find a rational approximation to x
%%%		within the tolerance defined by tol 
%%%	using a continued fraction expansion. 
%%%
%%%	EXAMPLE:
%%%
%%%    rat (pi) = 3 + 1/(7 + 1/16) = 355/113
%%%    rat (e) = 3 + 1/(-4 + 1/(2 + 1/(5 + 1/(-2 + 1/(-7)))))
%%%            = 1457/536
%%%
%%%    Called with two arguments returns the 
%%%	 (N) numerator and (D) denominator separately as two matrices. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
											%[testORN testORD] = rat(orbitRats,1e-3);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	NOTE:
%%%		.* is the pointwise product
%%%		./ is the pointwise division
%%%
%%%	EXAMPLE:
%%%		x = [1 2 3];
%%%		y = [5 6 2];
%%%
%%%		x +  y	-> [6 8  5]
%%%		x .* y 	-> [5 12 6]
%%%		x .^ y	-> [1 4	 9]
%%%		x ./ y	-> [5.00 3.00 0.667]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%find swath width as proportion of 360degrees

idealThreshold = 360./swathWidthsCorr;
%idealThreshFrac = mod(idealThreshold,1);		% FIXME: unused

orbitRT0 = orbitRatD < idealThreshold *minthresh; 	%too low! orbit will never be good because it hits a resonant spot!

orbitRT1 = orbitRatD >= idealThreshold*minthresh ... 
	 & orbitRatD < idealThreshold*maxthresh; 	%sweet spot!

orbitRT2 = orbitRatD >= idealThreshold*maxthresh ...
	 & orbitRatD < idealThreshold*maxthresh*8; 	%takes a long time but might be okay!s

orbitRT4 = orbitRatD >= idealThreshold*maxthresh*8;	%takes toooo long! 
							% (or might be a sweet spot if rational number significance is too high!)

valOrbitRT0 = orbitalPeriods.*orbitRT0/3600;
valOrbitRT1 = orbitalPeriods.*orbitRT1/3600;
valOrbitRT2 = orbitalPeriods.*orbitRT2/3600;
valOrbitRT4 = orbitalPeriods.*orbitRT4/3600;

altsRT0 = alts.*orbitRT0;
altsRT1 = alts.*orbitRT1;
altsRT2 = alts.*orbitRT2;
altsRT4 = alts.*orbitRT4;

%remove the zeros
valOrbitRT0(orbitRT0==0)=[];
valOrbitRT1(orbitRT1==0)=[];
valOrbitRT2(orbitRT2==0)=[];
valOrbitRT4(orbitRT4==0)=[];

altsRT0(orbitRT0==0)=[];
altsRT1(orbitRT1==0)=[];
altsRT2(orbitRT2==0)=[];
altsRT4(orbitRT4==0)=[];

mainfig = figure;
														% mainplot = plot(...
															% altsRT2, valOrbitRT2,'.c;Suboptimal;','markersize',2 ...
															% ,altsRT4, valOrbitRT4,'.k;Near-Resonant;','markersize',2 ...
															% ,altsRT0, valOrbitRT0,'.r;Resonant;','markersize',4 ...
															% ,altsRT1, valOrbitRT1,'.b;Ideal;','markersize',5 ...
															% );
mainplot = plot(...
	 altsRT2/1000, valOrbitRT2,'-c' ...
	,altsRT4/1000, valOrbitRT4,'-k' ...
	,altsRT0/1000, valOrbitRT0,'.r' ...
	,altsRT1/1000, valOrbitRT1,'.b' ...
);

titleString = sprintf('Ideal altitudes for an ISA MapSat Module around %s', planet);
title(titleString);
xlabel('Altitude (km)');
ylabel('Orbital Period (h)');
														%legend('Suboptimal','Near-Resonant','Resonant','Ideal','location','northwest')
														%legend('location','northwest');
set(gca,'xminortick','on');
set(gca,'xgrid','on');
set(gca,'xminorgrid','on');
set(gca,'ygrid','on');
plotName = sprintf('%s s%.3f-%.3f %s.png',planet,minthresh,maxthresh,resDisc);
														%print('planet.png');
														%print(plotName);
														%printing disabled because it takes forever


%start to classify the sweet spots

orbitClass = orbitRatD.*orbitRT1;
zoneStart = find(diff(orbitClass) ~= 0 ) + 1;
zoneEnd =   find(diff(orbitClass) ~= 0 );

%remove the zones that are just a stretch of zeros (ie: these aren't the zones we're looking for)
zoneStart(orbitClass(zoneStart)==0) = [];
zoneEnd(orbitClass(zoneEnd)==0) = [];

%if we start off with a sweet spot, add an extra zoneStart
if(orbitRT1(1))
	zoneStart = [1 zoneStart];
end

%similarly, if it ends on a sweet spot, add an extra zoneEnd
if(orbitRT1(end))
	zoneEnd = [zoneEnd length(orbitRT1)];
end

if length(zoneStart) ~= length(zoneEnd)
	disp('*Sweet spot classification error! Check that no blue zones are touching either end!*');
	return;
end

if isempty(zoneStart)
	disp(sprintf('\nNo sweet spots found! Try increasing the threshold.\n\n'))
end

scanTime = orbitalPeriods.*orbitRatD/2; % divided by 2 because there's two sides to the globe!
					%	(I checked in-game and it took half as long to scan as I was expecting :P)



disp(sprintf('\n Number of Zones: %d\n',length(zoneStart)));
disp('---------------------------');
disp(sprintf('%s, Sidelap %.4g - %.4g:',planet, minthresh, maxthresh));
disp('                      SMA         Altitude         Inclination Orbital   Time to Scan       Swath    Resolution');
disp('Zone  Res  Sidelap             Ideal      +/- Range    (deg)   Period   Ideal       diff     Width   (deg)   (km) ');
disp('========================================================================================================');
disp('');

%figure
%hold on
for i = 1:length(zoneStart)
	%disp(sprintf('\n\nZone %d\t',i);
	qqq = sprintf('%3i ',i);
	
	zi 	= zoneStart(i);
	zk 	= zoneEnd(i);
	altLow 	= alts(zi);
	altHi 	= alts(zk);
	altRa 	= altHi-altLow;

	ap 	= alts(zi:zk);
	st 	= scanTime(zi:zk);
	od 	= orbitRatD(zi:zk);
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	NOTE:
%%%		[x  y] = function(...);	% is the same as
%%%		[x, y] = function(...); % which is usually really
%%%		[x,ix] = function(...); % where x is the selected value
%%%					% and	ix is the (first) index for that value
%%%	EXAMPLE:
%%%		[x ix] = max([1,3,5,2,5])
%%%		 x => 5 % the maximum
%%%		ix => 3 % at position 3 (presumably octave numbers indexes from one)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	NOTE:
%%%		This code has a convention that variables ending in i are indexes.
%%%
%%%	EXAMPLE:
%%%			minti is the index of the minimum (scan) time.
%%%			minalti is the index of the minimum altitude (minalt index)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	
	meantt = mean(st); 			% mean time value
	[mintt minti] = min(st); 		% min time value and altitude of mintt
	[maxtt maxti] = max(st);		% max ...

	[temp meanti] = min(abs(st-meantt)); 	% ^ index of
	[H1 M1] = sec2hm(meantt); 		% FIXME: unused
	meanta = ap(meanti); 			% altitude of mean time value
	[temp meanalti] = min(abs(alts-meanti));% ^ index of

	

	minta = ap(minti); 			% FIXME: unused
	[temp minalti] = min(abs(alts-minta));
	[H0 M0] = sec2hm(mintt);
	

	maxta = ap(maxti); 			% FIXME: unused
	[H2 M2] = sec2hm(maxtt);		% FIXME: unused (x2)
	[Hd Md] = sec2hm(maxtt-mintt);		% FIXME: unused (x)
	
	[temp, altii] = min(abs(alts-meanta));
	
	[OPH0 OPM0] = sec2hm(orbitalPeriods(minalti));
	sw = swathWidths(altii);

	sma = meanta + R;

	resd = sw/scan_res;  % Scan lines are spaced evenly along the ground
	resm = resd*R*pi/180;
	
	%print min-mean-max altitude  min-mean-max time
	qqq = [qqq sprintf('%4d/%-4d (%4.2f)  ', orbitRatN(minalti), orbitRatD(minalti), orbitRatD(minalti)./idealThreshold(minalti))];
	qqq = [qqq sprintf('%7.3f km  ',sma/1000)];
	qqq = [qqq sprintf('%7.3f ',meanta/1000)];
	qqq = [qqq sprintf(' +/- %5.2f km  ',altRa/1000)];
	qqq = [qqq sprintf('%05.2f ', tgtInclination(altii))];
	qqq = [qqq sprintf('%3dh %04.1fm ',round(OPH0),OPM0)];
	qqq = [qqq sprintf('%5dh %04.1fm ',round(H0),M0)];
	qqq = [qqq sprintf('+%04.1fm  ',Md)];
	qqq = [qqq sprintf('%5.1f ',sw)];
	qqq = [qqq sprintf(' %4.4f ',resd)];
	if resm < 100
		qqq = [qqq sprintf(' %#2.2f m', resm)];
	else
		qqq = [qqq sprintf(' %#4.3f km', resm/1000)];
    end
	
	%disp(sprintf('   %i',altii);
	disp(qqq);
	
	%plot(ap,st,'.-')%,'.','markersize',3);
end
%hold off

%calculate Single Pass Polar (if it exists)
ts = swathWidths.*orbitalPeriods/360;
[sppmin sppI] = min(abs(ts-planetDay));
if sppmin < 25; %gives us a 25 second window to look
    disp('');
	disp('A single-pass polar orbit exists! Orbit at exactly 90 degrees inclination.');
	disp('Sidelap    Altitude   Time to Scan  Swath   Resolution');
	disp('------------------------------------------------------');
	for sppSideLap = [1, 1.05, 1.1, 1.3, 1.5]
		[temp sppI] = min(abs(ts/sppSideLap-planetDay));
		sppA = alts(sppI);
		sppT = orbitalPeriods(sppI);
		sw = swathWidths(sppI);
		resd = sw/scan_res;
		resm = resd*R*pi/180;
		[Hs Ms] = sec2hm(sppT);
		
		qqq = sprintf(' %2d%%     %7.3f km  ',sppSideLap*100-100, sppA/1000);
		qqq = [qqq sprintf('%4ih %04.1fm',Hs,Ms)];
		qqq = [qqq sprintf('    %05.1f',sw)];
		qqq = [qqq sprintf(' %4.1fd',resd)];
		if resm < 100
			qqq = [qqq sprintf(' %4d m', resm)];
		else
			qqq = [qqq sprintf(' %#4.3f km', resm/1000)];
		end

		disp(qqq);
	end
	disp('');
end


disp('');

%figure
%plot(alts,orbitRatD,'b.',alts,orbitRatD,'k.',alts,idealThreshold*minthresh,'r',alts,idealThreshold.*maxthresh);

