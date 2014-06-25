#!/bin/bash
export MSAINARG=$@
if hash octave 2>/dev/null; then
	octave --silent --eval "inputArg = getenv( 'MSAINARG' ); MapSatAltitude( inputArg );"
elif hash matlab 2>/dev/null; then
	matlab -nodesktop -nosplash -r "inputArg = getenv( 'MSAINARG' ); MapSatAltitude( inputArg ); exit;"
fi
