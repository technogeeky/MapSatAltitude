#!/bin/bash
if hash matlab 2>/dev/null; then
	export MLINARG=$@
	matlab -nodesktop -nosplash -r "inputArg = getenv( 'MLINARG' ); MapSatAltitude( inputArg ); exit;"
elif hash octave 2>/dev/null; then
	octave --silent --eval "MapSatAltitude('$@')"
fi