#!/bin/bash
## Last modified 2016-12-09 - Just Add Power
## Outputs useful diagnostic information to the OSD of the Receiver
export RES=$(cat /sys/devices/platform/display/timing_info | grep Hz | cut -d' ' -f2-4 | cut -d',' -f1)
export IPAD=$(lmparam g IPADDR)
export TXIP=$(node_list | grep gateway | cut -f1)
export FWVER=$(cat /www/version.html | sed -e '6!d')
export HPIX=$(echo $RES | cut -d'x' -f1 )
#DETERMINE ROW/COLUMNN POSITION OF XxY VIDEO WALL
get_video_wall(){
export MAX_ROW=$(astparam g vw_max_row)
export MAX_COL=$(astparam g vw_max_column)
export ROW=$(astparam g vw_row)
export COL=$(astparam g vw_column)
export VW_TEST=$(echo $MAX_ROW | grep -c not)
if [ "$VW_TEST" != "1" ] ; then
	if [ $MAX_ROW -gt 0 ] || [ $MAX_COL -gt 0 ] ; then
		export VW="R$(($ROW + 1))C$(($COL + 1))/$(($MAX_ROW + 1))x$(($MAX_COL + 1))"
	else
		export VW="Single"
	fi
else
	export VW="Single"
fi
}
# DETERMINE RS232 MODE
get_rs232_mode(){
export TYPE2=$(lmparam g SOIP_TYPE2)
export GUEST=$(lmparam g SOIP_GUEST_ON)
if [ "$TYPE2" == "y" ] && [ "$GUEST" == "n" ] ; then
		export SERIAL="1"
elif [ "$TYPE2" == "y" ] && [ "$GUEST" == "y" ] ; then
		export SERIAL="2"
elif [ "$TYPE2" == "n" ] && [ "$GUEST" == "y" ] ; then
		export SERIAL="3"
fi
}
# DETERMINE USB MODE
get_usb_mode(){
export NOKMOIP=$(lmparam g NO_KMOIP)
export KMOIP=$(echo $NOKMOIP | tr 'yn' 'NY')
export SHARE=$(lmparam g SHARE_USB)
export SEAMLESS=$(lmparam g SEAMLESS_SWITCH)
if [ "$SHARE" == "n" ] && [ "$SEAMLESS" == "y" ] ; then
	export USB=1
elif [ "$SHARE" == "y" ] && [ "$SEAMLESS" == "y" ] ; then
	export USB=2
elif [ "$SHARE" == "n" ] && [ "$SEAMLESS" == "n" ] ; then
	export USB=3
elif [ "$SHARE" == "y" ] && [ "$SEAMLESS" == "n" ] ; then
	export USB=4
fi
}

get_video_wall
get_rs232_mode
get_usb_mode
# SHOW DEBUG INFO ON SCREEN
export OSD_STR="\x0a\x20Resolution\x3a$RES\x0a\x20Rx\x3a$IPAD\x20\x20Tx\x3a$TXIP\x0a\x20FW\x3a$FWVER\x0a\x20VW\x3a$VW\x20\x20RS232\x3a$SERIAL\x20\x20USB\x3a$USB\x20\x20KM\x3a$KMOIP"
if [ "$VW_TEST" != "1" ] ; then
	if [ $MAX_COL -gt 0 ] ; then
		export OSD_FONT_SIZE=$(($HPIX/64/($MAX_COL+1)*3/2))
	else
		export OSD_FONT_SIZE=$(($HPIX/64-1))
	fi
else
	export OSD_FONT_SIZE=$(($HPIX/64-1))
fi
export OSD_FONT_COLOR=0x00FFFF00
export OSD_TRANSPARENT=31
osd_on.sh
osd_off.sh 60&
