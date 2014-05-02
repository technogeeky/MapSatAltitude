function P = getPlanet(planets_struct,planetName)
	if nargin < 2
		sprintf('\nUsage: \n\tplanets_struct = struct array from parsePlanetInfo.m');
		sprintf('\n\tplanetName = name of planet to return\n');
		return
	end
	planets = planets_struct;
	n = {planets.Name};
	i = find(strcmp(n,planetName));
	if i
		P = planets(i);
	end
	return
end