#!/bin/sh
## Commands syntax: 
## slideshow.sh {seconds per slide} {number of slides}
## {seconds per slide} must be included, and must be > 0
## {number of slides} must be included ,and must be > 0
##
## Use slideshow.sh command to cycle through jpgs in the /share directory
## Copy jpgs from a tftp server using the following syntax:
## cd /share
## tftp -v <SERVER IP> -c get <IMAGE NAME.jpg>
if [ $1 -gt 0 -a $2 -gt 0 ] ; then
ls /share | grep .jpg > /share/jpglist
export LINES=$(grep -c .jpg /share/jpglist)
export LINE=1
export LOOP=1
e e_stop_link
while [ $LINE -lt $(($LINES + 1)) ]
do
if [ $2 -lt $LOOP ] ; then
	break
fi
	export JPG=$(sed -n "$LINE"p /share/jpglist)
	e e_gui_show_picture::$JPG::n
	sleep $1
	export LINE=$(($LINE + 1))
	if [ $LINE -gt $LINES ]
	then
	export LINE=1
	fi
	export LOOP=$(($LOOP + 1))
done
e e_gui_show_picture::default.jpg::y
e e_reconnect
else
echo Error: incorrect syntax or missing parameter. Please use the following syntax:
echo slideshow.sh \[seconds_per_slide\] \[number_of_slides\]
fi
