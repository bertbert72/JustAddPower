#!/bin/bash
## Last Modified 2017-07-27 - Just Add Power
## Generate device info in JSON format and append to systeminfo.json

get_local_diagnostic(){
	##Gets firmware
	cat /www/version.html | grep ^A | awk '{print $1;}'
	##Gets model
	getmodel.sh
	##Tests Video Over IP Status
	if [ $(lmparam g NO_VIDEO | cut -d / -f 1 ) == "y" ];then
		echo "This device has Video Over IP disabled. Please enable this setting via the web interface. "
	fi
	##Tests device Link Mode Status
	if [ $(lmparam g ETH_LINK_MODE | grep -c "1G") == "1" ];then
		echo "This device has one gigabit of bandwidth connectivity. This is the proper setting. "
	else 
		echo "The device does not have one gigabit of bandwidth connectivity. Troubleshoot the network signal path of this device. "
	fi
	##Reports MAC address of device
	MAC=$(lmparam g MY_MAC)
		echo "This device's MAC address is: $MAC "
	##Tests 2G/3G mode of operation
	if [  $(lmparam g SOC_OP_MODE | cut -d / -f 1 ) == "1" ];then
		echo "This device is a 2G device or is in 2G Mode. "
	else
        echo "This device is in 3G Mode. "
	fi
	##Check EDID capture box for correct status
	x=$(cat /sys/devices/platform/videoip/edid_use)
	if [ $x == "primary" ];then
        echo "Copy EDID Box: Checked. Please uncheck this box via the web interface. "
	else
        echo "Copy EDID Box: Unchecked. This is the proper setting. "
	fi
	##Reports Static IP settings or notifies user of non-static IP
	MY_IP=$(astparam g ipaddr);MY_NETMASK=$(astparam g netmask);MY_GATEWAY=$(astparam g gatewayip);
	if [ $(lmparam g IP_MODE | cut -d / -f 1 ) == "static" ];then
		echo "IP Address: $MY_IP" && echo "Subnet Mask: $MY_NETMASK" && echo "Default Gateway: $MY_GATEWAY"
	else
		echo "This device does not have a static IP Address. Assign static IP for layer three functionality. "
	fi
	##Checks current Video Wall Settings
	A=$(astparam g vw_max_row | cut -c 1);B=$(astparam g vw_max_column | cut -c 1);C=$(astparam g vw_row | cut -c 1);D=$(astparam g vw_column | cut -c 1)
	A=$((A+1))
	B=$((B+1))
	C=$((C+1))
	D=$((D+1))
	if [ $(getmodel.sh | grep RX -c ) == "1" ] && [ $(lmparam g EN_VIDEO_WALL | cut -c 1) == "y" ];then
		if [ $A == 1 ] && [ $B == 1 ];then
			echo "This device is in single screen video wall mode. "
		else
			echo "This receiver is part of a $A column by $B row video wall. Its position is row $C column $D. "
		fi
	fi
	if [ $(getmodel.sh | grep RX -c ) == "1" ] && [ $(lmparam g EN_VIDEO_WALL | cut -c 1) == "n" ];then
		echo "This receiver is not part of a video wall. "
	fi
	if [ $(getmodel.sh | grep TX -c ) == "1" ];then
		echo "This device is a transmitter: Please check receiver(s) for video wall settings. "
	fi
	if [ $(lmparam g VW_VAR_STRETCH_TYPE | cut -d / -f 1 ) == "1" ];then
		echo "Video Wall Mode: Stretch Out. This mode should be changed to Fit In via the web interface.  "
	else
        echo "Video Wall Mode: Fit In. This is the proper setting. "
	fi
	##Checks current serial settings
	E=$(lmparam g S0_BAUDRATE | cut -d / -f 1)
	if [ $(lmparam g NO_SOIP | cut -c 1 ) == "n" ];then
		if [ $(lmparam g SOIP_TYPE2 | cut -c 1) == "y" ] && [ $(lmparam g SOIP_GUEST_ON | cut -c 1) == "n" ];then 
			echo "This device is in Serial Mode 1: Dumb Redirection. Its baud settings are $E. " 
		elif [ $(lmparam g SOIP_TYPE2 | cut -c 1) == "y" ] && [ $(lmparam g SOIP_GUEST_ON | cut -c 1) == "y" ];then 
			echo "This device is in Serial Mode 2: Guest Mode. Its Baud settings are $E. " 
		elif [ $(lmparam g SOIP_TYPE2 | cut -c 1) == "n" ] && [ $(lmparam g SOIP_GUEST_ON | cut -c 1) == "y" ];then 
			echo "This device is in Serial Mode 3: CLI Access. Its default baud settings are 9600-8n1."
		else
			echo "Serial Error" 
		fi
	fi
	if [ $(lmparam g NO_SOIP | cut -c 1 ) == "y" ];then
		echo "Serial Over IP Disabled: Please Enable for Serial Functionality. "
	fi
	##Reports current video status
	Y=$(lmparam g STATE | cut -d / -f 1)
	F=$(cat /sys/devices/platform/videoip/State)
	if [ $Y == "s_srv_on" ] && [ $(getmodel.sh | grep TX -c ) == "1" ];then
		echo "This transmitter has detected video from a source and is pushing the video. This is the proper mode of operation. "
	elif [ $Y == "s_attaching" ] && [ $(getmodel.sh | grep TX -c ) == "1" ];then
		echo "This transmitter is not receiving video from a source: Check Source HDMI Signal Path. "
	fi
	if [ $Y == "s_srv_on" ] && [ $(getmodel.sh | grep RX -c ) == "1" ] && [ $F == "OPERATING" ] && [ $(cat /sys/devices/platform/display/monitor_info | grep attached=n -c ) == "0" ];then
		echo "This receiver is getting video over the network, and detects a valid HDMI Connection. This is the proper mode of operation. "
	elif [ $Y == "s_srv_on" ] && [ $(getmodel.sh | grep RX -c ) == "1" ] && [ $F == "OPERATING" ] && [ $(cat /sys/devices/platform/display/monitor_info | grep attached=n -c ) == "1" ];then
		echo "This receiver is getting video over the network, but lacks a valid HDMI Connection. Please check this receiver's HDMI signal path to the display. "
	elif [ $Y == "s_srv_on" ] && [ $(getmodel.sh | grep RX -c ) == "1" ] && [ $F == "WAITING_HOST_MODE" ];then
		echo "This receiver has a network connection to a compatible transmitter, but lacks video over the network: Check Source HDMI Signal Path. "
	elif [ $Y == "s_search" ] && [ $(getmodel.sh | grep RX -c ) == "1" ];then
		echo "This receiver lacks a valid network connection to a compatible transmitter: Check Transmitter Network Signal Path, IP Information, 2G/3G Mode, and Firmware. "
	fi
	if [ $(cat /sys/devices/platform/videoip/timing_info | grep -c "Not Available") == "1" ];then
		echo "This device is not outputting/receiving video. Please engage a live source for resolution information. "
	else
		G=$(cat /sys/devices/platform/videoip/timing_info | grep "Capture Windows:" | sed 's/.................//')
		H=$(cat /sys/devices/platform/videoip/timing_info | grep "Scan Mode:" | sed 's/...........//')
		I=$(cat /sys/devices/platform/videoip/timing_info | grep "Signal Type:" | sed 's/.............//')
		echo "This device's input/output resolution is $G. The scan mode is $H. The signal type is $I. "
	fi
	##Reports Scaler Setting
	if [ $(getmodel.sh | grep -c "3G") == "1" ] && [ $(lmparam g SOC_OP_MODE | grep 3 -c ) == "1" ] && [ $(getmodel.sh | grep RX -c ) == "1" ];then
		if [ $(cat /sys/devices/platform/videoip/output_timing_convert | grep 0x00000000 -c ) == "1" ];then
			echo "This receiver is set to Pass-Through mode. This is the default mode. "
		elif [ $(cat /sys/devices/platform/videoip/output_timing_convert | grep 82000000 -c ) == "1" ];then
			echo "This receiver has an EDID auto-detect scaler setting. " 
		elif [ $(cat /sys/devices/platform/videoip/output_timing_convert | grep 8000005F -c ) == "1" ];then
			echo "This receiver has an active scaler setting of UHD 2160p/30Hz. "
		elif [ $(cat /sys/devices/platform/videoip/output_timing_convert | grep 8000005E -c ) == "1" ];then
			echo "This receiver has an active scaler setting of UHD 2160p/25Hz. "
		elif [ $(cat /sys/devices/platform/videoip/output_timing_convert | grep 80000010 -c ) == "1" ];then
			echo "This receiver has an active scaler setting of Full HD 1080p/60Hz. "
		elif [ $(cat /sys/devices/platform/videoip/output_timing_convert | grep 8000001F -c ) == "1" ];then
			echo "This receiver has an active scaler setting of Full HD 1080p/50Hz. "
		else
			echo "This receiver has a custom scaler setting. If you believe this setting is incorrect, please apply a new scaler setting via the receiver's web interface. "
		fi
	fi
	##Reports Image Pull settings
	J=$(astparam g pull_on_boot | cut -d _ -f 1)
	K=$(($J/16*9))
	L=$(astparam g pull_on_boot | cut -d _ -f 3)
	if [ $(astparam dump | grep pull -c ) == "1" ] && [ $(astparam dump | grep pull_on_boot=n -c ) == "0" ];then
		echo "This device has a permanent Image Pull setting. The Image Pull graphic is $J pixels wide by $K pixels tall and is pulled every $L second(s). "
	else 
		echo "This device does not have a permanent Image Pull Setting. "
	fi
	##Reports current USB Settings
	if [ $(lmparam g NO_USB | cut -c 1 ) == "n" ];then
		if [ $(lmparam g SEAMLESS_SWITCH | cut -c 1) == "y" ] && [ $(lmparam g SHARE_USB | cut -c 1) == "n" ];then
			echo "This Device is in USB Mode 1. "
		elif [ $(lmparam g SEAMLESS_SWITCH | cut -c 1) == "y" ] && [ $(lmparam g SHARE_USB | cut -c 1) == "y" ];then
			echo "This Device is in USB Mode 2. "
		elif [ $(lmparam g SEAMLESS_SWITCH | cut -c 1) == "n" ] && [ $(lmparam g SHARE_USB | cut -c 1) == "n" ];then
			echo "This Device is in USB Mode 3. This mode is not currently supported for 3G systems. "
		elif [ $(lmparam g SEAMLESS_SWITCH | cut -c 1) == "n" ] && [ $(lmparam g SHARE_USB | cut -c 1) == "y" ];then
			echo "This Device is in USB Mode 4. This mode is not currently supported for 3G systems. "
		else
			echo "USB error, please contact support at 727-517-4053 extension 2. "
		fi
	fi
	if [ $(lmparam g NO_USB | cut -c 1 ) == "y" ];then
		echo "This device does not have USB Over IP Enabled. This should be enabled over the Web Interface. "
	fi
	if [ $(lmparam g NO_KMOIP | cut -c 1 ) == "y" ];then
		echo "This device has touchscreen functionality enabled. "
	else
		echo "This device does not have touchscreen functionality enabled. "
	fi
}

get_json_data(){
	# Gather device info
	(
	sleep 1
	printf "########## DEVICE MODEL ########## \n"
	printf "getmodel.sh \n"
	sleep 2
	printf "########## VERSION INFO ########## \n"
	printf "cat /www/version.html \n"
	usleep 50000
	printf "############ UPTIME ############## \n"
	printf "cat /proc/uptime \n"
	usleep 50000
	printf "########## VIDEO STATUS ########## \n"
	printf "cat /var/ast_device_status \n"
	usleep 50000
	printf "cat /sys/devices/platform/videoip/State \n"
	usleep 50000
	printf "####### VIDEO RESOLUTION ######### \n"
	printf "cat /sys/devices/platform/videoip/timing_info \n"
	usleep 50000
	printf "########## LMPARAM DUMP ########## \n"
	printf "lmparam dump \n"
	sleep 1
	printf "######### ASTPARAM DUMP ########## \n"
	printf "astparam dump \n"
	sleep 1
	) | telnet $TARGET_IP 2>/dev/null > $INFOFILE

	# Exit if device could not be reached over the network
	if [ "$(cat $INFOFILE)" == "" ];then
		echo "DEVNFO: Device at $TARGET_IP could not be reached on the network"
		exit
	fi
	
	# Populate Variables
	MODEL=$(cat $INFOFILE | grep -A 1 getmodel.sh | tail -n 1 | tr '\r\n' '\0')
	FW=$(cat $INFOFILE | grep -A 1 -m 1 initrd2m | grep -v initrd2m | tr '\r\n' '\0')	
	MAC=$(cat $INFOFILE | grep MY_MAC | cut -d'=' -f2 | tr '\r\n' '\0')
	MODE_CHECK=$(cat $INFOFILE | grep SOC_OP_MODE | cut -d'=' -f2 | tr '\r\n' '\0')
		if [ "$MODE_CHECK" == "3" ];then 
			MODE=3G
		else
			MODE=2G
		fi
	UPTIME=$(cat $INFOFILE | grep -A 2 UPTIME | tail -n 1 | cut -d' ' -f1 | awk '{printf("%dd %02dh %02dm %02ds",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}')
	SPEED=$(cat $INFOFILE | grep ETH_LINK_MODE | cut -d'=' -f2 | tr '\r\n' '\0')
	STATUS=$(
		Y=$(cat $INFOFILE | grep -m 1 STATE | cut -d'=' -f2 | tr '\r\n' '\0')
		F=$(cat $INFOFILE | grep -A 2 State | grep TING | tr '\r\n' '\0')
		
		if [ "$(echo $MODEL | grep TX -c )" == "1" ];then
			if [ "$Y" == "s_srv_on" ];then
				echo "Operating"
			elif [ "$Y" == "s_attaching" ];then
				echo "Waiting for video source"
			else
				echo "Undefined state"
			fi
		elif [ "$(echo $MODEL | grep RX -c )" == "1" ];then
			if [ "$Y" == "s_srv_on" ] && [ "$F" == "OPERATING" ];then
				echo "Operating"
			elif [ "$Y" == "s_srv_on" ] && [ "$F" == "WAITING_HOST_MODE" ];then
				echo "Connected - Waiting for video source"
			elif [ "$Y" == "s_search" ];then
				echo "Connecting to Transmitter"
			else
				echo "Undefined state"
			fi
		fi
	)		
	RES=$(
		if [ "$STATUS" == "Operating" ];then
			H=$(cat $INFOFILE | grep -m 1 Timing\ Table | cut -d'[' -f3 | cut -d']' -f1)
			V=$(cat $INFOFILE | grep -m 1 Timing\ Table | cut -d'[' -f4 | cut -d']' -f1)
			R=$(cat $INFOFILE | grep -m 1 Timing\ Table | cut -d'[' -f5 | cut -d']' -f1)
			S=$(cat $INFOFILE | grep "Scan Mode:" | sed 's/...........//' | cut -c 1)
			echo $H\x$V$S\@$R\Hz
		else
			echo "Unavailable"
		fi
	)
	SCALER=$(
		if [ "$MODE" == "3G" ] && [ "$(echo $MODEL | grep -c RX)" == "1" ];then
			if [ "$(cat $INFOFILE | grep V_OUTPUT_TIMING_CONVERT | cut -d'=' -f2 | tr '\r\n' '\0')" == "0" ];then
				echo "Pass-Thru"
			elif [ "$(cat $INFOFILE | grep V_OUTPUT_TIMING_CONVERT | cut -d'=' -f2 | tr '\r\n' '\0')" == "82000000" ];then
				echo "Auto-Detect Scaler"
			elif [ "$(cat $INFOFILE | grep V_OUTPUT_TIMING_CONVERT | cut -d'=' -f2 | tr '\r\n' '\0')" == "8000005F" ];then
				echo "UHD 2160p/30Hz"
			elif [ "$(cat $INFOFILE | grep V_OUTPUT_TIMING_CONVERT | cut -d'=' -f2 | tr '\r\n' '\0')" == "8000005E" ];then
				echo "UHD 2160p/25Hz"
			elif [ "$(cat $INFOFILE | grep V_OUTPUT_TIMING_CONVERT | cut -d'=' -f2 | tr '\r\n' '\0')" == "80000010" ];then
				echo "Full HD 1080p/60Hz"
			elif [ "$(cat $INFOFILE | grep V_OUTPUT_TIMING_CONVERT | cut -d'=' -f2 | tr '\r\n' '\0')" == "8000001F" ];then
				echo "Full HD 1080p/50Hz"
			else
				echo "Custom Setting"
			fi
		else
			echo "Unavailable"
		fi
	)
	RS232=$(
		T2=$(cat $INFOFILE | grep SOIP_TYPE2 | cut -d'=' -f2 | tr '\r\n' '\0')
		GO=$(cat $INFOFILE | grep SOIP_GUEST_ON | cut -d'=' -f2 | tr '\r\n' '\0')
		if [ "$(cat $INFOFILE | grep NO_SOIP | cut -d'=' -f2 | tr '\r\n' '\0')" == "n" ];then
			if [ "$T2" == "y" ] && [ "$GO" == "n" ];then 
				echo "Type 1 - Dumb Redirection"
			elif [ "$T2" == "y" ] && [ "$GO" == "y" ];then 
				echo "Type 2 - Guest Mode"
			elif [ "$T2" == "n" ] && [ "$GO" == "y" ];then 
				echo "Type 3 - CLI Access"
			else
				echo "Serial Error" 
			fi
		else
			echo "Disabled"
		fi
	)
	BAUD=$(cat $INFOFILE | grep S0_BAUDRATE | cut -d'=' -f2 | tr '\r\n' '\0')
	USB=$(
		SS=$(cat $INFOFILE | grep SEAMLESS_SWITCH | cut -d'=' -f2 | tr '\r\n' '\0')
		SU=$(cat $INFOFILE | grep -m 1 SHARE_USB | cut -d'=' -f2 | tr '\r\n' '\0')
		
		if [ "$(cat $INFOFILE | grep NO_USB | cut -d'=' -f2 | tr '\r\n' '\0')" == "n" ];then
			if [ "$SS" == "y" ] && [ "$SU" == "n" ];then
				echo "Mode 1"
			elif [ "$SS" == "y" ] && [ "$SU" == "y" ];then
				echo "Mode 2"
			elif [ "$SS" == "n" ] && [ "$SU" == "n" ];then
				echo "Mode 3"
			elif [ "$SS" == "n" ] && [ "$SU" == "y" ];then
				echo "Mode 4"
			else
				echo "ERROR"
			fi
		else
			echo "Disabled"
		fi
	)	
	TOUCHSCREEN=$(
		if [ $(cat $INFOFILE | grep NO_KMOIP | cut -d'=' -f2 | tr '\r\n' '\0') == "y" ];then
			echo "Enabled"
		else
			echo "Disabled"
		fi
	)
	#VIDEOWALL	
		ROW=$(( $(cat $INFOFILE | grep VW_VAR_ROW | cut -d'=' -f2 | tr '\r\n' '\0') + 1 ))
		COLUMN=$(( $(cat $INFOFILE | grep VW_VAR_COL | cut -d'=' -f2 | tr '\r\n' '\0') + 1 ))
		TOTAL_ROWS=$(( $(cat $INFOFILE | grep VW_VAR_MAX_ROW | cut -d'=' -f2 | tr '\r\n' '\0') + 1 ))		
		TOTAL_COLUMNS=$(( $(cat $INFOFILE | grep VW_VAR_MAX_COL | cut -d'=' -f2 | tr '\r\n' '\0') + 1 ))		
		ORIENTATION=$(
			if [ "$MODE" == "3G" ];then
				ROTATE=$(cat $INFOFILE | grep VW_VAR_ROTATE | cut -d'=' -f2 | tr '\r\n' '\0')
				case $ROTATE in
					0) echo 0;;		
					5) echo 90;;
					3) echo 180;;
					6) echo 270;;
					*) echo $ROTATE;;
				esac
			else
				echo "Unavailable"
			fi
		)		
		#BEZEL	
			OW=$(cat $INFOFILE | grep VW_VAR_MONINFO_HT | cut -d'=' -f2 | tr '\r\n' '\0')
			OH=$(cat $INFOFILE | grep VW_VAR_MONINFO_VT | cut -d'=' -f2 | tr '\r\n' '\0')
			VW=$(cat $INFOFILE | grep VW_VAR_MONINFO_HA | cut -d'=' -f2 | tr '\r\n' '\0')
			VH=$(cat $INFOFILE | grep VW_VAR_MONINFO_VA | cut -d'=' -f2 | tr '\r\n' '\0')
		#ADVANCED		
			HSHIFT=$(cat $INFOFILE | grep VW_VAR_H_SHIFT | cut -d'=' -f2 | tr '\r\n' '\0')
			VSHIFT=$(cat $INFOFILE | grep VW_VAR_V_SHIFT | cut -d'=' -f2 | tr '\r\n' '\0')
			HSCALE=$(cat $INFOFILE | grep VW_VAR_H_SCALE | cut -d'=' -f2 | tr '\r\n' '\0')
			VSCALE=$(cat $INFOFILE | grep VW_VAR_V_SCALE | cut -d'=' -f2 | tr '\r\n' '\0')
	
	# Build JSON file
	(
	printf "{ \n"
	printf "\t\"details\":{ \n"
	printf "\t\t\"model\":\"$MODEL\", \n"
	printf "\t\t\"firmware\":\"$FW\", \n"
	printf "\t\t\"mac\":\"$MAC\", \n"
	printf "\t\t\"mode\":\"$MODE\", \n"
	printf "\t\t\"uptime\":\"$UPTIME\", \n"
	printf "\t\t\"speed\":\"$SPEED\", \n"
	printf "\t\t\"status\":\"$STATUS\", \n"
	printf "\t\t\"resolution\":\"$RES\", \n"
	printf "\t\t\"scaler\":\"$SCALER\", \n"
	printf "\t\t\"rs232\":\"$RS232\", \n"
	printf "\t\t\"baud\":\"$BAUD\", \n"
	printf "\t\t\"usb\":\"$USB\", \n"
	printf "\t\t\"videowall\":{ \n"
	printf "\t\t\t\"row\":\"$ROW\", \n"
	printf "\t\t\t\"column\":\"$COLUMN\", \n"
	printf "\t\t\t\"totalrows\":\"$TOTAL_ROWS\", \n"
	printf "\t\t\t\"totalcolumns\":\"$TOTAL_COLUMNS\", \n"
	printf "\t\t\t\"orientation\":\"$ORIENTATION\", \n"
	printf "\t\t\t\"bezel\":{ \n"
	printf "\t\t\t\t\"ow\":\"$OW\", \n"
	printf "\t\t\t\t\"oh\":\"$OH\", \n"
	printf "\t\t\t\t\"vw\":\"$VW\", \n"
	printf "\t\t\t\t\"vh\":\"$VH\" \n"
	printf "\t\t\t}, \n"
	printf "\t\t\t\"shift\":{ \n"
	printf "\t\t\t\t\"horizontal\":\"$HSHIFT\", \n"
	printf "\t\t\t\t\"vertical\":\"$VSHIFT\" \n"
	printf "\t\t\t}, \n"
	printf "\t\t\t\"scale\":{ \n"
	printf "\t\t\t\t\"horizontal\":\"$HSCALE\", \n"
	printf "\t\t\t\t\"vertical\":\"$VSCALE\" \n"
	printf "\t\t\t} \n"
	printf "\t\t} \n"
	printf "\t} \n"
	printf "} \n"
	) > $JSONFILE
}

# Set $TARGET_IP and $INFOFILE
if [ $# -gt 0 ];then
	mkdir /www/switchplease 2> /dev/null
	mkdir /www/switchplease/json 2> /dev/null
	mkdir /usr/local/bin/devices 2> /dev/null
	TARGET_IP="$1"
	# Change TARGET_IP to 127.0.0.1 if self
	if [ "$TARGET_IP" == "$(astparam g ipaddr)" ];then
		TARGET_IP="127.0.0.1"
	fi
	INFOFILE="/usr/local/bin/devices/$2"
	JSONFILE="/www/switchplease/json/$2.json"
	get_json_data
else
	# Tuohy's Local Diagnostic Script
	get_local_diagnostic
fi


