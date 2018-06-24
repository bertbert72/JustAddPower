#!/bin/sh
export RES=$(cat /sys/devices/platform/display/timing_info | grep Hz | cut -d' ' -f2-4)
export IPAD=$(astparam g ipaddr)
export TXIP=$(node_list | grep ast3-gateway | cut -f1)
export FWVER=$(cat /www/version.html | sed -e '6!d')
export VW=$(astparam g en_video_wall | tr yn YN)
# DETERMINE RS232 MODE
export GUEST=$(astparam g soip_guest_on)
export TYPE2=$(astparam g soip_type2)
if [ "$GUEST" == "n" ] && [ "$TYPE2" == "y" ] ; then
	export SERIAL="1"
elif [ "$GUEST" == "y" ] && [ "$TYPE2" == "y" ] ; then
	export SERIAL="2"
elif [ "$GUEST" == "y" ] && [ "$TYPE2" == "n" ] ; then
	export SERIAL="3"
fi
# DETERMINE USB MODE
export SHARE=$(astparam g share_usb)
export SEAMLESS=$(astparam g seamless_switch)
export NOKMOIP=$(astparam g no_kmoip)
if [ "$NOKMOIP" == "y" ] ; then
	export KMOIP=N
else
	export KMOIP=Y
fi
if [ "$SHARE" == "y" ] && [ "$SEAMLESS" == "y" ] ; then
	export USB=1
elif [ "$SHARE" == "n" ] && [ "$SEAMLESS" == "y" ] ; then
	export USB=2
elif [ "$SHARE" == "n" ] && [ "$SEAMLESS" == "n" ] ; then
	export USB=3
elif [ "$SHARE" == "y" ] && [ "$SEAMLESS" == "n" ] ; then
	export USB=4
fi
# SHOW DEBUG INFO ON SCREEN
export OSD_STR="\x0a\x20Resolution:$RES\x0a\x20Rx:$IPAD\x20\x20Tx:$TXIP\x0a\x20FW:$FWVER\x0a\x20VW:$VW\x20\x20RS232:$SERIAL\x20\x20USB:$USB\x20\x20KMOIP:$KMOIP"
export OSD_FONT_SIZE=30
export OSD_FONT_COLOR=0x0000FF00
export OSD_TRANSPARENT=15
osd_on.sh
osd_off.sh 60&
