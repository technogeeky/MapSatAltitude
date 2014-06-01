#!/usr/bin/env sh

for p in "Eve" "Gilly"
do
	rm -rf ./$p
	./MapSatAltitude.m -p $p -s RADAR -r Hi -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s Multi -r Hi -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s SAR   -r Hi -pp -q -os forum >> $p.txt
	mkdir $p
	mv $p_*.png $p
	mv $p.txt $p
done
