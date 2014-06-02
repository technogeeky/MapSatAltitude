#!/usr/bin/env sh

# small bodies get special treatment

#rm -rf planets
#mkdir planets

for p in "Gilly" "Minmus"
do
	echo "on $p"
	./MapSatAltitude.m -p $p -s RADAR -r Low -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s Multi -r Low -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s SAR   -r Low -pp -q -os forum >> $p.txt
	mv $p_*.png planets
	mv $p.txt planets
done

# big bodies get special treatment (Kerbol is incompat. with SCANsat)

for p in "Jool"
do
	echo "on $p"
	./MapSatAltitude.m -p $p -s RADAR -r Very -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s Multi -r Very -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s SAR   -r Very -pp -q -os forum >> $p.txt
	mv $p_*.png planets
	mv $p.txt planets
done


# all the normies go here
for p in "Moho" "Eve" "Kerbin" "Mun" "Duna" "Ike" "Dres" "Laythe" "Vall" "Tylo" "Bop"
do
	echo "on $p"
	./MapSatAltitude.m -p $p -s RADAR -r Hi -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s Multi -r Hi -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s SAR   -r Hi -pp -q -os forum >> $p.txt
	mv $p_*.png planets
	mv $p.txt planets
done


# Pol is super-special; if you don't allow it to consider huge
#	sidelap then it won't find anything

for p in "Pol"
do
	echo "on $p"
	./MapSatAltitude.m -p $p -s RADAR -r Very -pp -smin 1.00 -smax 3.00 -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s Multi -r Very -pp -smin 1.00 -smax 3.00 -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s SAR   -r Very -pp -smin 1.00 -smax 3.00 -os forum >> $p.txt
	mv $p_*.png planets
	mv $p.txt planets
done

# RSS Bodies Go Here (-q overrides the VeryHi default setting)
for p in "Earth" "Moon"
do
	echo "on $p"
	./MapSatAltitude.m -p $p -s RADAR -r Very -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s Multi -r Very -pp -q -os forum >> $p.txt
	./MapSatAltitude.m -p $p -s SAR   -r Very -pp -q -os forum >> $p.txt
	mv $p_*.png planets
	mv $p.txt planets
done


