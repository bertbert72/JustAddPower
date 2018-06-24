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
pkill -9 xyzzy.sh
xyzzy.sh $1 $2& 2> error.log
else 
echo Error: incorrect syntax or missing parameter. Please use the following syntax:
echo slideshow.sh \[seconds_per_slide\] \[number_of_slides\]
fi