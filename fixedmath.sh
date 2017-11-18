#!/bin/bash

unzip -oqq ./funcdiffs.zip
source ./.sinediff.sh
source ./.sqrtdiff.sh
#rm -f ./.sqrtdiff.sh
#rm -f ./.sinediff.sh

declare -ia sinTable=( 0 )
declare -ia sqrtTable=( 0 )

for i in {1..16383}; do
	sinTable[i]=$((sinTable[i-1]+sineDiff[i]))
	sqrtTable[i]=$((sqrtTable[i-1]+sqrtDiff[i]))
done

unset sinediff
unset sqrtDiff

function sqrtf() {
	local -i q=1
	local -i x=$1
	if (( x < 0 )); then echo "0"; fi
	while (( x > 16383 )); do
		x=$(( x >> 2 ))
		q=$(( q << 1 ))
	done
	echo $(( sqrtTable[x] * q ))
}

function sinf() {
	local -i t=$((${1} % 65536))
	if (( t < 0 )); then t=$((65536-t)); fi
	if (( t < 16384 )); then 
		echo ${sinTable[t]}
		return
	fi
	if (( t < 32768 )); then
		echo ${sinTable[32767-t]}
		return
	fi
	if (( t < 49152 )); then
		echo -${sinTable[t-32767]}
		return
	fi
	echo -${sinTable[65535-t]}
}

function cosf() {
	local -i t=$((${1} % 65536))
	if (( t < 0 )); then t=$((65536-t)); fi
	if (( t < 16384 )); then 
		echo ${sinTable[16383-t]}
		return
	fi
	if (( t < 32768 )); then
		echo -${sinTable[t-16383]}
		return
	fi
	if (( t < 49152 )); then
		echo -${sinTable[49151-t]}
		return
	fi
	echo ${sinTable[t-49151]}
}

