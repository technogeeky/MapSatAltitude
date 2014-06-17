function Planets = parsePlanetInfo(filename)
	
	if nargin < 1
		fid = fopen('planetInfos.txt');
	else
		fid = fopen(filename);
	end
	
	headerline = fgetl(fid);
	C = textscan(fid, '%s %f %f %f %f %f','Delimiter','\b\r\n\t','MultipleDelimsAsOne',1,'CommentStyle','%');
	h = strread(headerline,'%s');								% ^^^ this lets us put comments in the files
									% ^^ this combines all tabs into one delimiter, 
									%	so the data file can look nice
						% ^ this removes ' ' from being a valid delimiter
						% 	so that strings with spaces can be sucked up by %s
	fclose(fid);

	for i = 1:length(C{1})
		for j = 1:length(h)
			field = h{j};
				if iscell(C{j})
					fieldVal = C{j}{i};
				else
					fieldVal = C{j}(i);
				end
			P.(field)=fieldVal;
		end
		Planets(i)=P;
	end
end
