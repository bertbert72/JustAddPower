#!/bin/bash
## save_json.sh
## Last modified 2017-08-14 - Just Add Power
## saves /www/switchplease/json/systeminfo.json to NVRAM

# Check to see if systeminfo.json exists to be saved, alert and exit if it does not
if [ ! -e /www/switchplease/json/systeminfo.json ];then
	echo "SVJSON: Failed to save systeminfo.json. File does not exist."
	exit
fi
# Stop VideoIP link to speed process and 
#e e_stop_link
# Report status to user on debug screen
echo "SVJSON: Saving systeminfo.json to NVRAM"
#(
#	OSDMSG=1
#	while [ $OSDMSG -eq 1 ];do
#		{ printf "%s" "Please Wait - Saving SwitchPlease data to startup memory..." ; } > /var/info_local &
#		sleep 1
#	done
#) &
# CLear any previous patch files and prepare /tmp/patch
rm -rf /tmp/patch 2> /dev/null
mkdir /tmp/patch 2> /dev/null
# Extract current rootfsp to /tmp/patch and make switchplease directories
tar zxf /dev/mtdblkrootfsp -C /tmp/patch
mkdir /tmp/patch/www 2> /dev/null
mkdir /tmp/patch/www/switchplease 2> /dev/null
mkdir /tmp/patch/www/switchplease/json 2> /dev/null
# Move systeminfo.json into switchplease json directory
cp /www/switchplease/json/systeminfo.json /tmp/patch/www/switchplease/json
# Recompress the patch file
cd /tmp/patch
tar -c -f root_patch.tar *
gzip root_patch.tar
# Copy the patch to NVRAM
dd if=root_patch.tar.gz of=/dev/mtdblkrootfsp bs=64k &> /dev/null
# Restart the VideoIP service
#export OSDMSG=0
echo "SVJSON: Save Complete"
#e e_reconnect