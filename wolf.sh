#!/bin/bash

declare -r -i CEILING=237
declare -r -i FLOOR=243

source ./textures.sh
source ./map.sh

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
	printf "${COF}"
	stty -echo
	resize -s $SCRL $SCRW > /dev/null
	clear
}

function deinitapp() {
	printf "${DEF}${CON}\n"
	stty echo
	exit 0
}

function movebuffer() {
	local -i i
	local -i j
	local -i bcol
	local -i fcol
	for (( i = 0; i < SCRL; i++ )); do
		for (( j = 0; j < SCRW; j++ )) do
			bcol=${pixbuf[i*SCRW*2+j]}
			fcol=${pixbuf[i*SCRW*2+j+SCRW]}
			if (( bcol == fcol )); then
				scrbuf[80 * i + j]="\e[48;5;${bcol}m "
			else
				scrbuf[80 * i + j]="\e[38;5;${fcol}m\e[48;5;${bcol}m▄"
			fi
		done
	done
}

function draw() {
#	local -i i
#	local -i s=0
#	for (( i = 0; i < SCRL; i++ )); do
#		printf '%b' "${scrbuf[@]:s:SCRW}"
#		((s+=SCRW))
#	done
	printf '%b' "${scrbuf[@]}"
#	printf '%02d ' "${pixbuf[@]}"
}


function vertline() { #(x, start, end, color)
	local -i i
	for (( i = 0; i < $2; i++ )); do pixbuf[i*SCRW+$1]=CEILING; done
	for (( i = $2; i < $3; i++ )); do pixbuf[i*SCRW+$1]=$4; done
	for (( i = $3; i < SCRH; i++ )); do pixbuf[i*SCRW+$1]=FLOOR; done
}

function verttexline() { #(x, start, end, wallID, side, U)
	local -i i
	local -i v
	local -i texid=$(( ($4-1)*2 + $5 ))
	local -i texoff=${texoffsets[texid]}
	local -i top
	local -i bottom
	if (( $2 < 0 )); then top=0; else top=$2; fi
	if (( $3 >= SCRH )); then bottom=$(( SCRH-1 )); else bottom=$3; fi
	#printf "texture offset for texID %s: %s \n" $4 $texoff
	for (( i = 0; i < top; i++ )) do pixbuf[i*SCRW+$1]=CEILING; done
	for (( i = top; i < bottom; i++ )); do 
		v=$(( $TEXH*(i-($2))/($3-($2)) ))
		pixbuf[i*SCRW+$1]=${texbuf[texoff+v*TEXW+$6]}
	done
	for (( i = bottom; i < SCRH; i++ )); do pixbuf[i*SCRW+$1]=FLOOR; done
}

declare posX="7.5"
declare posY="2"
declare dirX=-1
declare dirY=0
declare planeX=0
declare planeY="0.66"
declare angle="91" # degrees
declare movedelta=0
declare -r -i angleDelta=10
declare -r posDelta="0.3"
declare -a pos=($posX $posY)
declare -a dirPlane=($dirX $dirY $planeX $planeY)

function rotate() { #(absoluteAngle)
printf "%s " $( bc -lq << EOI
scale = 8;
angle = $1 * 0.017453293;
dirx = -c(angle);
diry = s(angle);
planex = 0.66 * diry;
planey = -0.66 * dirx;
print dirx, " ", diry, " ", planex, " ", planey;
EOI
)
}

function move() { #(-1 for backward or +1 for forward)
printf "%s " $( bc -lq << EOI
scale = 8;
$BCMAP
mapw = $MAPW;
maph = $MAPH;
oldx = ${pos[0]};
oldy = ${pos[1]};
delta = $posDelta * $1;
newx = oldx + ${dirPlane[0]} * delta;
newy = oldy + ${dirPlane[1]} * delta;
scale = 0;
newx0 = newx / 1;
newy0 = newy / 1;
oldx0 = oldx / 1;
oldy0 = oldy / 1;
scale = 8;
if (m[mapw*oldy0+newx0] == 0) print newx, " " else print ${pos[0]}, " ";
if (m[mapw*newy0+oldx0] == 0) print newy, " " else print ${pos[1]}, " ";
EOI
)
}

function DDA() { # Wolfenstein's raycasting magic!
printf "%s " $( bc -l << EOI2
#cat << EOI2
scale = 8;
dirx = ${dirPlane[0]};
diry = ${dirPlane[1]};
planex = ${dirPlane[2]};
planey = ${dirPlane[3]};
$BCMAP
mapw=$MAPW;
maph=$MAPH;
w=$SCRW;
h=$SCRH;
invww=2.0 / w;
for (x=0; x<w; x++) {
	scale=8;
	camerax = x * invww - 1;
	rayposx=${pos[0]};
	rayposy=${pos[1]};
	raydirx=dirx + planex * camerax;
	raydiry=diry + planey * camerax;
	scale = 0;
	mapx = rayposx / 1;
	mapy = rayposy / 1;
	scale = 8;
	dirh = 0;
	dirv = 0;
	if (raydirx != 0) {
		deltadistx=sqrt(1 + ((raydiry * raydiry) / (raydirx * raydirx)));
		dirh = 1;
	}
	if (raydiry != 0) {
		deltadisty=sqrt(1 + ((raydirx * raydirx) / (raydiry * raydiry)));
		dirv = 1;
	} 
	if (dirh == 1) {
		if (raydirx < 0) {
			stepx = -1;
			sidedistx = (rayposx - mapx) * deltadistx;
		} else {
			stepx = 1;
			sidedistx = (mapx + 1 - rayposx) * deltadistx;
		}
	} else {
		stepx = 0;
		sidedistx = 0;
	}
		
	if (dirv == 1) {
		if (raydiry < 0) {
			stepy = -1;
			sidedisty = (rayposy - mapy) * deltadisty;
		} else {
			stepy = 1;
			sidedisty = (mapy + 1 - rayposy) * deltadisty;
		}
	} else {
		stepy = 0;
		sidedisty = 0;
	}

	hit = 0
	if (dirh == 1 && dirv == 1) {
		while (hit == 0) {
			if (sidedistx < sidedisty) {
				sidedistx += deltadistx;
				mapx += stepx;
				side = 0;
			} else {
				sidedisty += deltadisty;
				mapy += stepy;
				side = 1;
			}
			hit = ( m[mapw*mapy+mapx] != 0 );
		}
	} else {
		if (dirh == 1) {
			side = 0;
			while (hit == 0) {
				sidedistx += deltadistx;
				mapx += stepx;
				hit = (m[mapw*mapy+mapx] != 0 );
			}
		} else  {
			side = 1;
			while (hit == 0) {
				sidedisty += deltadisty;
				mapy += stepy;
				hit = (m[mapw*mapy+mapx] != 0 );
			}
		}
	}

	if (side == 0) {
		perpwalldist = (mapx - rayposx + 0.5 - stepx * 0.5) / raydirx;
		wallx = rayposy + perpwalldist * raydiry;
	} else {
		perpwalldist = (mapy - rayposy + 0.5 - stepy * 0.5) / raydiry;
		wallx = rayposx + perpwalldist * raydirx;
	}
	lineheight = h / perpwalldist;
	#print "wallx=", wallx, "; ";
	scale=0;
	wallxfloor = wallx / 1;
	#print "wallxfloor=", wallxfloor, "; ";
	scale=8;
	wallx-=wallxfloor;
	#print "wallx=", wallx, "; ";
	scale=0;
	texx=wallx * $TEXW / 1;
	#print "texx=", texx, "; ";
	if ((side == 0 && raydirx > 0) || (side == 1 && raydiry < 0)) {
		texx = $TEXW - texx - 1;
	}
	#print "texx=", texx, ";\n";
	drawstart = (h - lineheight) * 0.5;
	drawend = (h + lineheight) * 0.5;
	#print mapx, " ", mapy, "\n";
	
	print (drawstart+0.5)/1, " ", (drawend+0.5)/1, " ", m[mapw*mapy+mapx], " ", side, " ", texx, " \n";	

} 
EOI2
)
#exit
#print drawstart, " ", drawend, " ", m[mapw*mapy+mapx], " ", side, "\n";
}

function frame() {
	#printf "frame: \n"
	local -i i
	local -i drawStart
	local -i drawEnd
	local -i wallType
	local -i color
	local -i side
	for (( i = 0; i < SCRW; i++ )); do
		drawStart=${walls[i*5]}
		drawEnd=${walls[i*5+1]}
		wallType=${walls[i*5+2]}
		side=${walls[i*5+3]}
		u=${walls[i*5+4]}
		#vertline $i $drawStart $drawEnd $color
		verttexline $i $drawStart $drawEnd $wallType $side $u
	done
	#deinitapp
#	printf "%s " "${dist[@]}"
	#printf "frame;\n"
}

function main(){
initapp
initdata

trap deinitapp INT
declare -l input

while true; do
	movedelta=0
	read -s -t0.01 -n1 input
	read -s -t0.005 -n1000 discard
	printf "\e[1;1H"
	draw
	case $input in
		"w")	((movedelta=1));;
		"s")	((movedelta=-1));;
		"a")	((angle-=angleDelta));;
		"d")	((angle+=angleDelta));;
		*) 	: ;;
	esac
	if (( movedelta != 0 )); then
		pos=(`move $movedelta`)
	fi;
	dirPlane=(`rotate $angle`)
	walls=(`DDA`)
	#DDA
	#printf "%s| " `DDA`
	#printf "%s " "${walls[@]}"
	#
	movebuffer
	frame
	#exit
done

deinitapp
}

main

