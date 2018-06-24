#!/bin/bash
if [ $(astparam g vw_stretch_type) -eq 2 ];then
	sleep 10
	echo 2 > /sys/devices/platform/display/vw_stretch_type
fi
