#!/bin/bash

declare -r -i SPACE=0
declare -r -i WALL1=1 # dark blue wall, 2 little stones at top-right corner
declare -r -i WALL2=2 # dark blue wall, 1 big stone at top-right corner
declare -r -i WALL3=3 # dark blue wall, fenced door
declare -r -i WALL4=4 # dark blue wall, fenced door with skeleton

declare -r -i MAPW=14
declare -r -i MAPH=15

declare -r -ai MAP=(
	$WALL1 $WALL1 $WALL2 $WALL1 $WALL2 $WALL1 $WALL2 $WALL1 $WALL1 $WALL2 $WALL1 $WALL1 $WALL2 $WALL1 
	$WALL3 $SPACE $SPACE $SPACE $WALL2 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL2 $SPACE $SPACE $SPACE $WALL2 $SPACE $SPACE $SPACE $WALL2 $SPACE $SPACE $SPACE $SPACE $WALL2
	$WALL1 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL3 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $SPACE $WALL2
	$WALL1 $SPACE $SPACE $SPACE $WALL2 $WALL1 $SPACE $WALL1 $WALL2 $WALL2 $WALL1 $SPACE $WALL1 $WALL1
	$WALL2 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL4 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL4
	$WALL1 $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL2 $SPACE $SPACE $SPACE $WALL2 $WALL1 $SPACE $WALL1 $WALL1 $WALL2 $WALL1 $SPACE $WALL1 $WALL1
	$WALL3 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL2 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL1 $SPACE $SPACE $SPACE $WALL2 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $SPACE $WALL1
	$WALL3 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $WALL1 $SPACE $SPACE $SPACE $SPACE $WALL2
	$WALL2 $WALL1 $WALL1 $WALL1 $WALL2 $WALL1 $WALL2 $WALL1 $WALL1 $WALL2 $WALL2 $WALL2 $WALL2 $WALL2
)

declare BCMAP=$(
for (( i = 0; i < MAPH; i++ )); do
	for (( j = 0; j < MAPW; j++ )); do
		echo "m[$i*$MAPW+$j]=${MAP[i*MAPW+MAPW-j-1]};"
	done
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
	echo $BCMAP
fi

