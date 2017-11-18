#!/bin/bash

declare -r -i CEILING=237
declare -r -i FLOOR=243

source ./textures.sh
source ./map.sh
source ./fixedmath.sh

declare -a scrbuf	#actual symbols
declare -ai pixbuf	#"pixels"
declare -ai walls	# (drawStart, drawEnd, wallN, side)...

declare DEF='\e[0m'
declare COF='\e[?25l'
declare CON='\e[?25h'

declare -r -i SCRW=80
declare -r -i SCRL=25 #lines
declare -r -i SCRH=50 #"pixels"

function initdata() {
	local -i i
	for (( i=0; i < SCRW*SCRL; i++ )); do scrbuf[i]="${DEF} "; done
	for (( i=0; i < SCRW*SCRH; i++ )); do pixbuf[i]=0; done
}

function initapp() {
	reset
	printf "${COF}"
	stty -echo
	resize -s $SCRL $SCRW > /dev/null
}

function deinitapp() {
	stty echo
	printf "${DEF}${CON}\n"
	clear
	exit 0
}

function moveBuffer() {
	local -i i
	local -i j
	local -i bcol
	local -i fcol
	for (( i = 0; i < SCRL; i++ )); do
		for (( j = 0; j < SCRW; j++ )) do
			bcol=${pixbuf[i*SCRW*2+j]}
			fcol=${pixbuf[i*SCRW*2+j+SCRW]}
			if (( bcol == fcol )); then
				scrbuf[SCRW * i + j]="\e[48;5;${bcol}m "
			else
				scrbuf[SCRW * i + j]="\e[38;5;${fcol}m\e[48;5;${bcol}m\xe2\x96\x84" #▄"
			fi
		done
	done
}

function drawFrame() {
#	local -i i
#	local -i s=0
#	for (( i = 0; i < SCRL; i++ )); do
#		printf '%b' "${scrbuf[@]:s:SCRW}"
#		((s+=SCRW))
#	done
	printf '%b' "${scrbuf[@]}"
#	printf '%02d ' "${pixbuf[@]}"
}


#------------------
# fixed-point format: N.16, multiplier is 65536
#------------------

declare -i posX=163840		# 2.5
declare -i posY=425984		# 6.5

declare -i dirX=65536		# 1
declare -i dirY=-19		# ~0
declare -i planeX=-12		# ~0
declare -i planeY=43253		# 0.66
declare -i angle=32770		# 180.011 degrees, actual value is part of full circle
declare -i angleDelta=2048	# 11.25 degrees
declare -i posDelta=19661	# 0.3

function rotate() {
	if (( $1 == 0 )); then return; fi
	if (( $1 > 0 )); then
		(( angle += angleDelta ))
	else
		(( angle -= angleDelta ))
	fi
	if (( angle > 65535 )); then (( angle-=65536 )); fi
	if (( angle < 0 )); then (( angle+=65536 )); fi
	dirX=$(( $(cosf angle) ))
	dirY=$(( $(sinf angle) ))
	planeX=$(( ( dirY << 16 ) / 99297 ))
	planeY=$(( ( dirX << 16 ) / 99297 ))
	dirX=$(( -dirX ))
	#echo $dirX $dirY $planeX $planeY
}

function move() { #( +1 or -1 for direction )
	if (( $1 == 0 )); then return; fi
	local -i oldX=$posX
	local -i oldY=$posY
	local -i delta=$posDelta
	if (( $1 ==-1 )); then ((delta= -delta)); fi
	local -i newX=$(( oldX + ( ( dirX * delta ) >> 16 ) ))
	local -i newY=$(( oldY + ( ( dirY * delta ) >> 16 ) ))
	#printf " param1: %s totaldelta: %s, posDelta: %s " $1 $delta $posDelta
	#posX=$newX
	#posY=$newY
	#return

	local -i newX0=$(( newX >> 16 << 16 ))
	local -i newY0=$(( newY >> 16 << 16 ))
	local -i oldX0=$(( oldX >> 16 ))
	local -i oldY0=$(( oldY >> 16 ))
	if (( MAP[(MAPW * oldY0) + (newX0 >> 16)] == SPACE )); then posX=$newX; fi
	if (( MAP[(MAPW * newY0) + (oldX0 >> 16)] == SPACE )); then posY=$newY; fi
}

function calcFrame() { #Wolfenstein's raycasting magic!
	local -i invWW x cameraX rayPosX rayPosY rayDirX rayDirY mapX mapY dirH dirV tmp hit side wallType wallX stepX stepY texX
	invWW=$(( 131072 / ( SCRW - 1 ) ))
	for ((x = 0; x < SCRW; x++)); do
		cameraX=$(( x * invWW - 65536 ))
		rayPosX=$posX
		rayPosY=$posY
		rayDirX=$(( dirX + ( (planeX * cameraX) >> 16) ))
		rayDirY=$(( dirY + ( (planeY * cameraX) >> 16) ))
		mapX=$(( rayPosX >> 16 )) # map coords should be common integers
		mapY=$(( rayPosY >> 16 ))
		dirH=0
		dirV=0

		if (( rayDirX != 0 )); then
			tmp=$(( 65536 + ( rayDirY * rayDirY * 65536 / ( rayDirX * rayDirX ) ) ))
			deltaDistX=$( sqrtf $tmp )
			dirH=1
		fi
		if (( rayDirY != 0 )); then
			tmp=$(( 65536 + ( rayDirX * rayDirX * 65536 / ( rayDirY * rayDirY ) ) ))
			deltaDistY=$( sqrtf $tmp )
			dirV=1
		fi

		if (( dirH == 1 )); then
			if (( rayDirX < 0 )); then
				stepX=-1
				sideDistX=$(( ( ( rayPosX - ( mapX << 16 ) ) * deltaDistX ) >> 16 ))
			else
				stepX=1
				sideDistX=$(( ( ( ( mapX << 16 ) + 65536 - rayPosX ) * deltaDistX ) >> 16 ))
			fi
		else
			stepX=0
			sideDistX=0
		fi

		if (( dirV == 1 )); then
			if (( rayDirY < 0 )); then
				stepY=-1
				sideDistY=$(( ( ( rayPosY - ( mapY << 16 ) ) * deltaDistY ) >> 16 ))
			else
				stepY=1
				sideDistY=$(( ( ( ( mapY << 16 ) + 65536 - rayPosY ) * deltaDistY ) >> 16 ))
			fi
		else
			stepY=0
			sideDistY=0
		fi

		hit=0
		if (( dirH == 1 && dirV == 1 )); then
			while (( hit == 0 )); do
				if (( sideDistX < sideDistY )); then
					(( sideDistX+=deltaDistX ))
					(( mapX+=stepX ))
					side=0
				else
					(( sideDistY+=deltaDistY ))
					(( mapY+=stepY ))
					side=1
				fi
				wallType=$(( MAP[MAPW*mapY+mapX] ))
				hit=$(( wallType != SPACE ))
			done
		else
			if (( dirH == 1 )); then
				side=0
				while (( hit == 0 )); do
					(( sideDistX+=deltaDistX ))
					(( mapX+=stepX ))
					wallType=$(( MAP[MAPW*mapY+mapX] ))
					hit=$(( wallType != SPACE ))
				done
			else
				side=1
				while (( hit == 0 )); do
					(( sideDistY+=deltaDistY ))
					(( mapY+=stepY ))
					wallType=$(( MAP[MAPW*mapY+mapX] ))
					hit=$(( wallType != SPACE ))
				done
			fi
		fi

		if (( side == 0 )); then
			perpWallDist=$(( ( ( ( mapX << 16 ) - rayPosX + ( ( 1 - stepX ) << 15 ) ) << 16 ) / rayDirX ))
			wallX=$(( rayPosY + ( ( perpWallDist * rayDirY ) >> 16 ) ))
		else
			perpWallDist=$(( ( ( ( mapY << 16 ) - rayPosY + ( ( 1 - stepY ) << 15 ) ) << 16 ) / rayDirY ))
			wallX=$(( rayPosX + ( ( perpWallDist * rayDirX ) >> 16 ) ))
		fi
		
		lineHeight=$(( ( SCRH << 16 ) / perpWallDist )) # lineheight is common integer
		drawStart=$(( ( SCRH - lineHeight ) >> 1 ))
		drawEnd=$(( ( SCRH + lineHeight ) >> 1 ))

		((wallX-=( wallX >> 16 << 16) ))
		texX=$(( ( wallX * TEXW ) >> 16 ))	#texX is common integer, column number in texture
		if (( ( side == 0 && rayDirX > 0 ) || ( side == 1 && rayDirY < 0 ) )); then
			texX=$(( TEXW - texX - 1 ))
		fi

		local -i i v top bottom
		local -i texid=$(( ( ( wallType - 1 ) << 1 ) + side ))
		local -i texoff=${texoffsets[texid]}
		if (( $drawStart < 0 )); then top=0; else top=$drawStart; fi
		if (( $drawEnd > SCRH )); then bottom=$SCRH; else bottom=$drawEnd; fi
		for (( i = 0; i < top; i++ )) do pixbuf[i*SCRW+x]=CEILING; done
		for (( i = top; i < bottom; i++ )); do 
			v=$(( ( TEXH * ( i - ( drawStart ) ) ) / ( drawEnd - drawStart )  ))
			pixbuf[i*SCRW+x]=${texbuf[texoff+v*TEXW+texX]}
		done
		for (( i = bottom; i < SCRH; i++ )); do pixbuf[i*SCRW+x]=FLOOR; done
	done
}

function main() {
	initapp
	initdata

	trap deinitapp INT
	declare -l input discard
	
	while true; do
		movedelta=0
		rotatedelta=0
		read -s -t0.01 -n1 input
		read -s -t0.001 -n1000 discard
		case $input in
			"w")	((movedelta=1));;
			"s")	((movedelta=-1));;
			"a")	((rotatedelta=-1));;
			"d")	((rotatedelta=1));;
			*)	: ;;
		esac
		move $movedelta
		rotate $rotatedelta
		calcFrame
		moveBuffer
		printf "\e[1;1H"
		drawFrame
		#printf "\e[1;1H\e[0m%s %s %s %s %s %s %s" $posX $posY $angle $dirX $dirY $planeX $planeY
		#deinitapp
	done
}

main
