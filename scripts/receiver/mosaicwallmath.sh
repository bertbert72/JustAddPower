#!/bin/bash -x
#mosaicwallmath.sh

## Inputs are: OW, OH, VW, VH, overall width (WTOTAL), overall height (HTOTAL), distance from left edge (WOFF), distance from top edge (HOFF), rotation
## Any unit of measurement can be used as long as it is the same unit for all measurements and there are no decimals (convert by multiplying by factor of 10)
## This can be done with fewer variables, but it must be possible for an installer to do with on-site tools, aka measuring tape. This math makes that possible.

## Horizontal overall size and vertical overall size must be in the ratio 16:9. The average installer will not be able to measure out a 16:9 ratio box, so there is correction for that.
## An HTOTAL or VTOTAL value can be found by adding together the OW/VW values based on the configuration of the screens. This way, we only need one TOTAL value and the other can be calculated. If both are given and are not in the correct aspect ratio, the larger value can be kept and the smaller value can be modified to fit the 16:9 ratio.
## This causes the problem of offset from center if the box is wider than it is tall (or vice versa).  In this case, do we provide a value for offset, or simply center it? Currently it locks the picture to the top left corner. No accomodation for offset is here yet, as the allowable maximum offset is based off of the values for all of the mosaic displays.
##Displays in the mosaic wall can be different sizes and different bezel measurements and this will still work.

##OW is always the left-right frame length. OH is always the top-bottom frame length. This means that in the case of a portrait rotation, the OH will be larger than the OW. For a typical landscape orientation, the OH is smaller than the OW.

## Calculations must be done to turn these values into (x1,y1) & (x2,y2)

##command format: mosaicwallmath.sh OW OH VW VH WTOTAL HTOTAL WOFF HOFF ROTATION

export OW=$1
export OH=$2
export VW=$3
export VH=$4
export WTOTAL=$5
export HTOTAL=$6
export WOFF=$7
export HOFF=$8
export ROTATION=$9
export SCALE=10000
export WBEZEL=$((($OW-$VW)/2))
export HBEZEL=$((($OH-$VH)/2))
echo "$HBEZEL"
echo "$VBEZEL"

echo "WTOTAL before is $WTOTAL"
echo "HTOTAL before is $HTOTAL"
if [ $(($WTOTAL*9)) -le $(($HTOTAL*16)) ]; then
	WTOTAL=$(($HTOTAL*16/9))
else
	HTOTAL=$(($WTOTAL*9/16))
fi
echo "WTOTAL after is $WTOTAL"
echo "HTOTAL after is $HTOTAL"

case $ROTATION in
	0)
		ORIENTATION=0
		;;
	90)
		ORIENTATION=5
		;;
	180)
		ORIENTATION=3
		;;
	270)
		ORIENTATION=6
		;;
esac

X1=$((($WOFF+$WBEZEL)*$SCALE/$WTOTAL))
Y1=$((($HOFF+$HBEZEL)*$SCALE/$HTOTAL))
X2=$((($WOFF+$OW-$WBEZEL)*$SCALE/$WTOTAL))
Y2=$((($HOFF+$OH-$HBEZEL)*$SCALE/$HTOTAL))

e e_vw_enable_${X1}_${Y1}_${X2}_${Y2}_2
e e_vw_rotate_${ORIENTATION}
