#!/bin/bash
## Checks to see if SwitchPlease is enabled and extracts files to /www/switchplease if so

extract_switchplease(){
	if [ ! -e /www/switchplease ];then
		mkdir /www/switchplease
	fi
	if [ -e /www/switchplease/index.html ];then
		echo "SWIPLZ: SwitchPlease is already running"
	else
		echo "SWIPLZ: Launching SwitchPlease..."
		tar zxf /share/switchplease.tar.gz -C /www/switchplease 2> /dev/null
		if [ ! -e /www/switchplease/json/systeminfo.json ] || [ $(ls -l /www/switchplease/json/systeminfo.json | awk '{print $5}') -lt 64 ] 2> /dev/null;then
			getswitchinfo.sh json
		fi
	fi
}
patch_myip(){
	MYIP=$(astparam g ipaddr)
	MYMAC=$(lmparam g MY_MAC)
	sed -i "s/SLOTH_NIPPLES/$MYIP/g" /www/switchplease/assets/js/handlejson.js
	sed -i "s/SLOTH_NIPPLES/$MYIP/g" /www/switchplease/assets/js/jadmodal.js
	sed -i "s/SLOTH_NIPPLES/$MYIP/g" /www/switchplease/assets/js/options.js
	sed -i "s/user_options/user_options_$MYMAC/g" /www/switchplease/assets/js/handlejson.js
	sed -i "s/user_options/user_options_$MYMAC/g" /www/switchplease/assets/js/jadmodal.js
	sed -i "s/user_options/user_options_$MYMAC/g" /www/switchplease/assets/js/options.js
}

if [ "$(astparam g switchplease)" == "y" ];then
	extract_switchplease
	patch_myip
else
	echo "SWIPLZ: SwitchPlease is not enabled on this device"
fi
