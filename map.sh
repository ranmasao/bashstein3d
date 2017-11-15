#!/bin/bash

if [[ "$(basename -- "$0")" == "map.sh" ]]; then
	declare -r -i SPACE=0
	declare -r -i WALL1=1
	declare -r -i WALL2=2
	declare -r -i WALL3=3
	declare -r -i WALL4=4
fi

declare -r -i MAPW=8
declare -r -i MAPH=8

declare -r -ai MAP=(
	$WALL1 $WALL2 $WALL3 $WALL4 $WALL1 $WALL2 $WALL3 $WALL4 
	$WALL4 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL3 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL2
	$WALL2 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL3
	$WALL1 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL4
	$WALL4 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL3 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL2
	$WALL2 $WALL1 $WALL4 $WALL3 $WALL2 $WALL1 $WALL4 $WALL3
)

declare BCMAP=$(
for (( i = 0; i < MAPW * MAPH; i++ )); do
	echo "m[$i]=${MAP[i]};"
done
)

function testmap() {
#cat << EOI
bc -q << EOI
scale = 0;
$BCMAP
for (i = 0; i < $MAPH; i++) {
	for (j = 0; j < $MAPW; j++) {
		if (m[i*$MAPW+j] == 0) print " " else print "#";
	}
	print "\n";
}
test = 1;
for (i = 0; i < $MAPH; i++) {
	if (m[i*$MAPW] == 0 || m[i*$MAPW+$MAPH-1] == 0) {
		test = 0;
		break;
	}
}
for (j = 0; j < $MAPW; j++) {
	if (m[j] == 0 || m[($MAPH-1)*$MAPW+j] == 0) {
		test = 0;
		break;
	}
}
if (test == 0) print "Check map boundaries! Leak found!\n" else print "Map seems OK.\n";

EOI

}

if [[ "$(basename -- "$0")" == "map.sh" ]]; then
	testmap
fi
#echo $BCMAP
