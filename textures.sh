#!/bin/bash

declare -ir TEXH=24
declare -ir TEXW=24

declare -iar texlist=( 
	"wall1_light.sh" "wall1_dark.sh" "wall2_light.sh" "wall2_dark.sh"
	"wall3_light.sh" "wall3_dark.sh" "wall4_light.sh" "wall4_dark.sh"
)

declare -ia texbuf	#all textures are in one buffer
declare -ia texoffsets	#offsets to textures: 1st light, 1st dark, 2nd light, 2nd dark,...

for ((i = 0; i < ${#texlist[@]}; i++)); do
	source "./textures/${texlist[i]}"
	texbuf+=(${texture[@]})
	texoffsets+=( $(($i*$TEXH*$TEXW)) )
done

if [[ "$(basename -- "$0")" == "textures.sh" ]]; then
	printf "%s " ${texbuf[@]}
	echo
	printf "%s " ${texoffset[@]}
	echo
fi
