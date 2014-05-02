function S = getScanner(scanners_struct,scannerName)
	if nargin < 2
		sprintf('\nUsage: \n\tscanner_struct = struct array from parseScannerInfo.m');
		sprintf('\n\tscannerName = name of scanner to consider\n');
		return
	end
	scanners = scanners_struct;
	n = {scanners.Name};
	i = find(strcmp(n,scannerName));
	if i
		S = scanners(i);
	end
	return
end
