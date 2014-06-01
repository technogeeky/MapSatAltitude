#!/usr/bin/octave -qf
clear all
close all


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
quiet = false;				%% defaults to false
argv_style = "forum";		%% defaults to forum output

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	0. Process command-line arguments
%%%
%%%		This section does a two-stage pass over command line arguments.
%%%		If an argument is found (in short or long form), expect is set to
%%%			*which* argument is expected next.
%%%		Then, the argument is caught with the outer otherwise case and exported
%%%			to a variable like argv_planet, which is existance-checked later
%%%			to override requesting information on STDIN.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


expect = "";
args = argv();
for i = 1:nargin
	%% double arguments
	switch (args{i})
		case {"-p", "--planet"}
			expect = "planet";
		case {"-s", "--scanner"}
			expect = "scanner";
		case "--sidelap-min"
			expect = "sidelap-min";
		case "--sidelap-max"
			expect = "sidelap-max";
		case {"-r","--resolution"}
			expect = "resolution";
		case {"-os","--output-style"}
			expect = "output-style";
		case "--plots"
			expect = "";
			argv_plots = true;
		case {"-q","--quiet"}
			expect = "";
			quiet = true;
		case {"-h","--help"}
			disp("Usage: ./MapSatAltitude <flags>; where flags are:");
			disp("\tShort Form	\tLong Form          	\tFlag Description");
			disp("\t--------------------------------------------------------------------------------------------------");
			disp("\t-p <...>	\t--planet <...>		\tspecify planet");
			disp("\t-s <...>	\t--scanner <...>		\tspecify scanner");
			disp("\t-r <...>	\t--resolution <...>	\tspecify resolution");
			disp("\t        	\t--sidelap-min <...>	\tspecify minimum sidelap (defaults: 1.00 -- none)");
			disp("\t        	\t--sidelap-max <...>	\tspecify maximum sidelap (defaults: 1.25)");
			disp("\t-q      	\t--quiet            	\tonly output the table (not the inputs)");
			disp("\t           	\t--plots            	\tgenerate all plots)");
			disp("\t-os <...>	\t--output-style <...>	\tchange formatting for output (disabled)");
			disp("\t---------------------------------------------------------------------------------------------------");
			disp("Planets and Scanners must be in their respective files.");
			disp("Resolution must be one of: [Ultra, VeryHi, High, Low].");
			disp("Output Style must be one of: [text,forum,csv,markdown].");
			disp("NOTE: In order to have no STDIN input requests, you must specify all of:");
			disp("  planet, scanner, resolution, sidelap-min, sidelap-max");
			quit;
		otherwise
			switch (expect)
				case "planet"
					argv_planet = args{i};
				case "scanner"
					argv_scanner = args{i};
				case "sidelap-min"
					argv_minthresh = args{i};
				case "sidelap-max"
					argv_maxthresh = args{i};
				case "resolution"
					argv_resolution = args{i};
				case "output-style"
					argv_style = args{i};
					switch (argv_style)
						case {"text","csv","markdown","forum"}
							%% this is fine
						otherwise
							printf('\ninvalid output-style: %s is not one of: [text, csv, markdown, forum]\n',argv_style);
							return;
					end
				otherwise
					disp('--help? no help for you!');
			end
	end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	1. What scanner are we discussing?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%		
	

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	1. What scanner are we discussing?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch (exist("argv_scanner"))
	case false
		scanner = input('Scanner name? ', 's');
	case true
		scanner = argv_scanner;
end

scanners = parseScannerInfo();
S = getScanner(scanners,scanner);


if isempty(S)
	printf('\nUnknown scanner: %s\n\n', scanner);
	return
end

ScannerName = S.Name;

if (!quiet) disp(sprintf('[%s] Ideal Altitude Calculator.',S.LongName)); endif;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	2. What planet are we discussing?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch (exist("argv_planet"))
	case false
		planet = input('Planet name? ','s');
	case true
		planet = argv_planet;
end

planets = parsePlanetInfo();
P = getPlanet(planets,planet);
if isempty(P)
	printf('\nInvalid planet: %s\n\n',planet);
	return
end

R 	  = P.Radius;
planetDay = P.Day;
GM 	  = P.GM;
Name	  = P.Name;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	2. a. If we are on a RSS planet, use Earth-scaled surface scales
%%%		(instead of Kerbin-scaled ones)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch (Name)
	case { "Earth", "Moon", "Jupiter", "Deimos", "Phobos" }
		surfscale = max (6371000 / R,1);
		InRSS = true;
	otherwise
		surfscale = max(600000 / R,1);
		InRSS = false;
endswitch
		

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

switch (exist("argv_minthresh"))
	case false
		inp_thresh = input('Minimum Sidelap? (Default is 1.00. Press Enter to skip) : ','s');
	case true
		inp_thresh = argv_minthresh;
end

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

switch (exist("argv_maxthresh"))
	case false
		inp_thresh = input('Maximum Sidelap? (Default is 1.25. Press Enter to skip) : ','s');
	case true
		inp_thresh = argv_maxthresh;
end

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

switch (exist("argv_resolution"))
	case false
		switch (InRSS)
			case false
				inp_res = input('Numerical Resolution? ("Uber","Very",["Hi"], or "Low".) : ','s');
				resDisc = 'High';
				rational_resolution = 1e-4;
			case true
				inp_res = input('Numerical Resolution? ("Uber",["Very"],"Hi", or "Low".) : ','s');
				resDisc = 'VeryHi';
				rational_resolution = 1e-5;
			alt_stepmul = 1/2;
		end
	case true
		inp_res = argv_resolution;
end


if isempty(inp_res)
	%% nothing needed here anymore
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
if (!quiet) disp(sprintf('Rational Number Numerical Resolution: %s (%.2e)\n',resDisc,rational_resolution)); endif;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: Incliation Setting was commented out already.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: Does resonanceLimit actually do anything?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
resonanceLimit = 1*360; %just in case we want 720 degrees or something

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: What units is this in? I suspect degrees.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
max_width = 180; %maximum swath width; if we're getting larger than this then the planetoid is teeny,
				%at which point you don't need this tool anymore


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% We need to pick the correct FOV, and for laziness I have stored a HalfFov too (why does this need half fov?)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hSCAN_FOV = (S.FOV * surfscale) / 2;
hFOV = (hSCAN_FOV/180*pi);

scan_res = 200;  % New lasers have 200 points in a line that spread evenly based on ground distance

if (!quiet) disp(''); endif;
if (!quiet) disp(''); endif;


[dayh daym days] = sec2hms(planetDay);
syncorbit = oHeight2(planetDay,R,GM);

if (!quiet) disp(sprintf('\nPlanet:     %s\nRadius:     %d km',planet,R/1000)); endif;
if (!quiet) disp(sprintf('Sync.Orbit: %.2f km\nSOI:        %.2f km',syncorbit/1000,P.SOI/1000)); endif;
if (!quiet) disp(sprintf('Day Length: %dh %2dm %ds',dayh,daym,days)); endif;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%	FIXME: Is this maxSwathAlt likely to be reached?
%%%		For the Mun and for SAR, this is 1.12e8 meters.

maxSwathAlt  = R*cot(hFOV)-R;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Here we (evidently) pick the minimum altitude by looking at:
%%% 1. [REMOVED] (hardcoded) 10e3
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% This is a table of half FOVs at each altitude.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

i = 1;

for thisAlt = alts
    if (thisAlt < S.AltitudeIdeal)
		hFOV_at_altitude(i) = ((S.FOV * (thisAlt / S.AltitudeIdeal) * sqrt(surfscale)) / 2) / 180 * pi;
    else
		hFOV_at_altitude(i) = ((S.FOV * sqrt(surfscale)) / 2) / 180 * pi;
    endif;
    i++;
endfor;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		Some information about what inputs were chosen.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if (!quiet) disp(sprintf('\nScan line resolution: %d',scan_res)); endif;
if (!quiet) disp(sprintf('Field-of-View range: %3.2f°  - %3.2f°',hFOV_at_altitude(1)*2*180/pi,hFOV_at_altitude(i-1)*2*180/pi)); endif;
if (!quiet) disp(sprintf('Sidelap       range: %4.2f   - %4.2f',minthresh,maxthresh)); endif;
if (!quiet) disp(sprintf('Altitude      Range: %.1f km - %.1f km in %.1f m steps (%i possible zones)\n',minAlt/1000,maxAlt/1000,alt_stepsize,numel(alts))); endif;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		Explain why the minimum altitude was chosen.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
qqq = sprintf('Minimum altitude chosen because:\n\t');
switch minAltReason
	case {1}
		qqq = [qqq sprintf('[%s] has a minimum range of %.1f km',S.LongName,S.AltitudeMin/1000)];
	case {2}
		qqq = [qqq sprintf('[%s] has an atmosphere until %.1f km', P.Name, P.Atmo/1000)];
%	case {3}
%		qqq = [qqq sprintf('because of a hardcoded limit of %.2f m. deal with it. ',10e3)];

end
if (!quiet) disp(qqq); endif;
if (!quiet) disp(''); endif;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		Explain why the maximum altitude was chosen.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
if (!quiet) disp(qqq); endif;
if (!quiet) disp(''); endif;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		Swath projection from FOV.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

orbitalPeriods = oPeriod2(alts,R,GM);

planetRotPerPeriod = (360./planetDay)*orbitalPeriods;	% FIXME: unused


S1 = ((alts+R).*cot(hFOV_at_altitude)+sqrt(R.^2.*cot(hFOV_at_altitude).^2-alts.^2-2.*alts.*R))./(1+cot(hFOV_at_altitude).^2);
S2 = ((alts+R).*cot(hFOV_at_altitude)-sqrt(R.^2.*cot(hFOV_at_altitude).^2-alts.^2-2.*alts.*R))./(1+cot(hFOV_at_altitude).^2);
S  = min([S1;S2]);


swathWidths = (asin(S./R)*2)/pi*180;
swathWidthsCorr = swathWidths;			%% FIXME: presumably this means Corrected, but
										%% 	in that case, swathWidths should *never* be used again
										%% 	(and it is. both are used.)

orbitRats = orbitalPeriods./planetDay;
tgtInclination = acosd(orbitRats);


AorbitRats = (orbitRats+1)/2;
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

orbitRT0 = orbitRatD  < idealThreshold*minthresh; 											%too low! orbit will never be good because it hits a resonant spot!
orbitRT1 = orbitRatD >= idealThreshold*minthresh & orbitRatD < idealThreshold*maxthresh; 	%sweet spot!
orbitRT2 = orbitRatD >= idealThreshold*maxthresh & orbitRatD < idealThreshold*maxthresh*8; 	%takes a long time but might be okay!s
orbitRT4 = orbitRatD >= idealThreshold*maxthresh*8;											%takes toooo long! 
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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		FIXME: some figure that is not used anymore (and doesn't print for me anyway)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


switch (exist("argv_plots"))
	case true
		mainfig = figure;
		mainplot = plot(...
			 altsRT2/1000, valOrbitRT2,'oc','markersize',2 ...
			,altsRT4/1000, valOrbitRT4,'ok','markersize',2 ...
			,altsRT0/1000, valOrbitRT0,'or','markersize',4 ...
			,altsRT1/1000, valOrbitRT1,'ob','markersize',5 ...
		);



		titleString = sprintf('Ideal Altitudes for %s around %s',ScannerName,planet);
		title(titleString);

		xlabel('Altitude (km)');
		ylabel('Orbital Period (h)');

		legend('Suboptimal','Near-Resonant','Resonant','Ideal','location','northwest')
		legend('location','northwest');

		%% gca is 'get current axis'

		%	x axis settings
		set(gca,'xminortick','on');
		set(gca,'xgrid','on');
		set(gca,'xminorgrid','on');

		% y axis settings
		set(gca,'ygrid','on');

		plotName = sprintf('%s s%.3f-%.3f %s.png',planet,minthresh,maxthresh,resDisc);
		%print (plotName); %this fails for me
	case false
		%% nothing
end
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		Start to classify the sweet spots.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

orbitClass = orbitRatD.*orbitRT1;

zoneStart = find(diff(orbitClass) ~= 0 ) + 1;
zoneEnd =   find(diff(orbitClass) ~= 0 );

%remove the zones that are just a stretch of zeros (ie: these aren't the zones we're looking for)

zoneStart(orbitClass(zoneStart)==0) = [];
zoneEnd(orbitClass(zoneEnd)==0) 	= [];

%	1. if we start off with a sweet spot, add an extra zoneStart
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



if (!quiet) disp(sprintf('\n Number of Zones: %d\n',length(zoneStart))); endif;
if (!quiet) disp('---------------------------'); endif;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		HEADER FORMATTING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch (argv_style)
	case "forum"
		disp(sprintf('[size=4][b]%s [%s][/B][/SIZE][spoiler=Show %s Orbits][code]\n', Name, ScannerName, ScannerName));
	otherwise
		%% nothing
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		TABLE HEADER
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch (argv_style)
	case {"forum","text"}
		disp('                    Altitude                Inc.       Orbital   Time to Scan          Eff.  Swath  Resolution');
		disp('  UEQx   EQx Sidelap  Ideal     +/- Error               Period      Total    +/- Error  FOV   Width (deg)   (km)');
		disp('====================================================================================================================');
		%%%%%%    17    29 (1.10)  782.176 km +/- 1.51 km (80.07°)   6h 38.9m    96h 24.4m +/- 13.4m (3.5°)  14 m (0.07°) 0.238 km
		%%%%%%    18    31 (1.09)  739.453 km +/- 1.53 km (80.72°)   6h 13.2m    96h 24.0m +/- 14.1m (3.4°)  13 m (0.06°) 0.221 km
		%%%%%%    19    33 (1.04)  701.102 km +/- 1.56 km (81.29°)   5h 50.5m    96h 23.5m +/- 15.0m (3.2°)  11 m (0.06°) 0.199 km
		%%%%%%    23    40 (1.24)  695.092 km +/- 1.57 km (81.37°)   5h 47.0m   115h 40.0m +/- 18.3m (3.2°)  11 m (0.06°) 0.195 km
		%%%%%%    25    44 (1.16)  639.982 km +/- 1.62 km (82.16°)   5h 15.4m   115h 39.2m +/- 20.1m (3.0°)   9 m (0.05°) 0.165 km
	case "csv"
		disp('UEQx,EQx,Sidelap,Altitude,AltitudeError,Inclination,OrbitalPeriod,ScanTime,ScanTimeError,EffFOV,SwathWidth,ResolutionDeg,ResolutionMeter');
	case "markdown"
		disp('  UEQx | EQx|Sidelap| Altitude |    Error  | Inc.    | O. Period| Scan Time |    Error| FOV  |Swath|Res (°)|Res (m)');
		disp('=======|====|=======|==========|===========|=========|==========|===========|=========|======|=====|=======|========');
		%%%%%%    17    29 (1.10)  782.176 km +/- 1.51 km (80.07°)   6h 38.9m    96h 24.4m +/- 13.4m (3.5°)  14 m (0.07°) 0.238 km
		%%%%%%    18    31 (1.09)  739.453 km +/- 1.53 km (80.72°)   6h 13.2m    96h 24.0m +/- 14.1m (3.4°)  13 m (0.06°) 0.221 km
		%%%%%%    19    33 (1.04)  701.102 km +/- 1.56 km (81.29°)   5h 50.5m    96h 23.5m +/- 15.0m (3.2°)  11 m (0.06°) 0.199 km
		%%%%%%    23    40 (1.24)  695.092 km +/- 1.57 km (81.37°)   5h 47.0m   115h 40.0m +/- 18.3m (3.2°)  11 m (0.06°) 0.195 km
		%%%%%%    25    44 (1.16)  639.982 km +/- 1.62 km (82.16°)   5h 15.4m   115h 39.2m +/- 20.1m (3.0°)   9 m (0.05°) 0.165 km
	otherwise
		printf('\ninvalid output-style: %s is not one of: [text, csv, markdown, forum]\n',argv_style);
		return;
end

switch (exist("argv_plots"))
	case true
		figure
		hold on
	case false
		%% nothing
end

for i = flipdim(1:length(zoneStart),2)

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%		ALL OF THESE VARIABLES CAN BE USED IN TABLE OUTPUT
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
	zi 		= zoneStart(i);
	zk 		= zoneEnd(i);
	altLow 	= alts(zi);
	altHi 	= alts(zk);
	altRa 	= altHi-altLow;

	ap 		= alts(zi:zk);
	st 		= scanTime(zi:zk);
	od 		= orbitRatD(zi:zk);
	
	meantt 			= mean(st); 	% mean time value
	[mintt minti] 	= min(st); 		% min time value and altitude of mintt
	[maxtt maxti] 	= max(st);		% max ...

	[H1 M1] = sec2hm(meantt); 		% FIXME: unused
	[H0 M0] = sec2hm(mintt);
	[H2 M2] = sec2hm(maxtt);		% FIXME: unused (x2)
	[Hd Md] = sec2hm(maxtt-mintt);	% FIXME: unused (x)


	[temp meanti] 	= min(abs(st-meantt));

	meanta 	= ap(meanti); 		% altitude of mean time value
	minta 	= ap(minti); 		% FIXME: unused
	maxta 	= ap(maxti); 		% FIXME: unused

	[temp meanalti] = min(abs(alts-meanti));
	[temp minalti] 	= min(abs(alts-minta));
	[temp altii] 	= min(abs(alts-meanta));

	[OPH0 OPM0] = sec2hm(orbitalPeriods(minalti));

	%% swath width size for this altitude
	sw = swathWidths(altii);

	%% FOV displayed to user
	dispfov = 2 * (hFOV_at_altitude(altii) * 180 / pi);

	ts = swathWidths.*orbitalPeriods/360;
	[sppmin sppI] = min(abs(ts-planetDay));	

	%% SMA (for convenience?)
	sma = meanta + R;

	resd = sw/scan_res;  % Scan lines are spaced evenly along the ground
	resm = resd*R*pi/180;

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%		TABLE ENTRY
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	

	switch (argv_style)
		case {"text","forum"}
			qqq = "";
		   %qqq = [qqq sprintf('%4i',			i)];
			qqq = [qqq sprintf(' %5d',			orbitRatN(minalti))];
			qqq = [qqq sprintf(' %5d',			orbitRatD(minalti))];
			qqq = [qqq sprintf(' (%4.2f)', 		orbitRatD(minalti)./idealThreshold(minalti))];
		   %qqq = [qqq sprintf(' %7.3f km',		sma/1000)];
			qqq = [qqq sprintf(' %8.3f km',		meanta/1000)];
			qqq = [qqq sprintf(' +/- %3.2f km',	altRa/1000)];
			qqq = [qqq sprintf(' (%03.2f°)',	tgtInclination(altii))];
			qqq = [qqq sprintf(' %3dh %04.1fm',	round(OPH0),OPM0)];
			qqq = [qqq sprintf(' %5dh %04.1fm',	round(H0),M0)];
			qqq = [qqq sprintf(' +/- %04.1fm',	Md)];
			qqq = [qqq sprintf(' (%3.1f°)',		dispfov)];
			qqq = [qqq sprintf(' % 3.0f m',		sw)];
			qqq = [qqq sprintf(' (%03.2f°)',	resd)];

			if resm < 100
				qqq = [qqq sprintf(' %#2.2f m', resm)];
			else
				qqq = [qqq sprintf(' %#4.3f km', resm/1000)];
			end
		case {"csv"}
			qqq = "";
		   %qqq = [qqq sprintf('%4i',			i)];
			qqq = [qqq sprintf('%5d',			orbitRatN(minalti))];
			qqq = [qqq sprintf(',%5d',			orbitRatD(minalti))];
			qqq = [qqq sprintf(',(%4.2f)', 		orbitRatD(minalti)./idealThreshold(minalti))];
		   %qqq = [qqq sprintf(',%7.3f km',		sma/1000)];
			qqq = [qqq sprintf(',%8.3f km',		meanta/1000)];
			qqq = [qqq sprintf(',+/- %3.2f km',	altRa/1000)];
			qqq = [qqq sprintf(',(%03.2f°)',	tgtInclination(altii))];
			qqq = [qqq sprintf(',%3dh %04.1fm',	round(OPH0),OPM0)];
			qqq = [qqq sprintf(',%5dh %04.1fm',	round(H0),M0)];
			qqq = [qqq sprintf(',+/- %04.1fm',	Md)];
			qqq = [qqq sprintf(',(%3.1f°)',		dispfov)];
			qqq = [qqq sprintf(',% 3.0f m',		sw)];
			qqq = [qqq sprintf(',(%03.2f°)',	resd)];

			if resm < 100
				qqq = [qqq sprintf(',%#2.2f m', resm)];
			else
				qqq = [qqq sprintf(',%#4.3f km', resm/1000)];
			end
		case "markdown"
			qqq = "";
		   %qqq = [qqq sprintf('%4i',			i)];
			qqq = [qqq sprintf('%5d',			orbitRatN(minalti))];
			qqq = [qqq sprintf('|%5d',			orbitRatD(minalti))];
			qqq = [qqq sprintf('|(%4.2f)', 		orbitRatD(minalti)./idealThreshold(minalti))];
		   %qqq = [qqq sprintf('|%7.3f km',		sma/1000)];
			qqq = [qqq sprintf('|%8.3f km',		meanta/1000)];
			qqq = [qqq sprintf('|+/- %3.2f km',	altRa/1000)];
			qqq = [qqq sprintf('|(%03.2f°)',	tgtInclination(altii))];
			qqq = [qqq sprintf('|%3dh %04.1fm',	round(OPH0),OPM0)];
			qqq = [qqq sprintf('|%5dh %04.1fm',	round(H0),M0)];
			qqq = [qqq sprintf('|+/- %04.1fm',	Md)];
			qqq = [qqq sprintf('|(%3.1f°)',		dispfov)];
			qqq = [qqq sprintf('|% 3.0f m',		sw)];
			qqq = [qqq sprintf('|(%03.2f°)',	resd)];

			if resm < 100
				qqq = [qqq sprintf('|%#2.2f m', resm)];
			else
				qqq = [qqq sprintf('|%#4.3f km', resm/1000)];	
			end			
		otherwise
			disp('Error: An unsupported format has been attempted.');
	end


	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%%		END TABLE ENTRY
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
	
	disp(qqq);

	switch (exist("argv_plots"))
		case true
			plot(ap,st,'.-')%,'.','markersize',3);
		case false
			%% nothing
	end
end

switch (exist("argv_plots"))
	case true
		hold off
	case false
		%% nothing
end

%calculate Single Pass Polar (if it exists)
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%		FOOTER FORMATTING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch (argv_style)
	case "forum"
		disp('[/code][/spoiler]');
		disp('');
	otherwise
		disp('');
end



switch (exist("argv_plots"))
	case true
		figure
		plot(alts,orbitRatD,'b.',alts,orbitRatD,'k.',alts,idealThreshold*minthresh,'r',alts,idealThreshold.*maxthresh);
		pause(360); %% pause so we can see the interactive plots
	case false
		%% nothing
end





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
