#!/usr/bin/env sh

./MapSatAltitude.m -p Mun -s SAR   --sidelap-min 1.00 --sidelap-max 1.25 -r Hi -q -os csv
./MapSatAltitude.m -p Mun -s RADAR --sidelap-min 1.00 --sidelap-max 1.25 -r Hi -q -os csv
./MapSatAltitude.m -p Mun -s Multi --sidelap-min 1.00 --sidelap-max 1.25 -r Hi -q -os csv
