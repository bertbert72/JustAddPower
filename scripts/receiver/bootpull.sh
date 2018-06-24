#!/bin/bash
## Last Modified 2016-12-09 - Just Add Power
## ImagePull(TM) Copyright 2013 Just Add Power - All Rights Reserved
get_params(){
	if [ $(astparam g pull_on_boot | grep -c pull) == 1 ] ; then
		astparam s pull_on_boot n
	fi
	export WIDTH=$(astparam g pull_on_boot | cut -d_ -f1)
	export PRIOR=$(astparam g pull_on_boot | cut -d_ -f2)
	export FREQ=$(astparam g pull_on_boot | cut -d_ -f3)
}
check_params(){
	# Exit bootpull.sh process if pull_on_boot is set to 'n'
	if [ "$WIDTH" == "n" ]; then
		echo "ImagePull(TM) set to 'n' on boot."
		exit
	fi
	# Ensure valid width parameter between 64 and 640
	if [ $WIDTH -lt 64 ];then export WIDTH=64;fi
	if [ $WIDTH -gt 640 ];then export WIDTH=640;fi
	# Ensure valid priority setting
	if [ $PRIOR -ne 0 ] && [ $PRIOR -ne 1 ];then export PRIOR=1;fi
	# Prevent maximum pull at high priority
	if [ $PRIOR -eq 0 ] && [ $FREQ -eq 0 ];then export PRIOR=1;fi
}
pull(){
	# Prevent ImagePull from starting with no video source connected
	VID=0
	while [ $VID -eq 0 ] ; do
		if [ "$(cat /var/ast_device_status)" == "s_srv_on" ] ; then
			VID=1
			start_image_pull $WIDTH $PRIOR $FREQ
		else 
			echo "ImagePull(TM) delayed until source is connected. Rechecking in 20 seconds."
			sleep 20
		fi
	done
}
sleep 15
get_params
check_params
pull
