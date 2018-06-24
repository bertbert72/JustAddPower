#!/bin/bash
## Last Modified 2017-06-21 - Just Add Power
## As long as a J+P device has a static IP and gateway, logs into the switch to get details about switch configuration
## NOTE: Supported switches have a maximum telnet session limit
## Added support for TX and RX queries to roll into "Switch Please"

get_device_info(){
# Check to see if the device is set to have static IP address
	export IPMODE=$(astparam g ip_mode)
	# If there is a static IP address, gather required parameters
	if [ "$IPMODE" == "static" ] ; then
		# Receiver MAC address will be used to check against switch mac-address table for port location
		export MAC=$(ifconfig | grep eth0:stat | cut -d' ' -f6)	
		# Gateway is the IP address of the J+P PVID on the switch
		export GW=$(astparam g gatewayip)
	else
		echo "SWINFO: This device is not in Static IP Mode"
		exit
	fi
}
get_switch_status(){
	# Check to see if Gateway is alive
	echo "SWINFO: Checking network connection to $GW"
	SLEEPCOUNTER=6
	while [ $SLEEPCOUNTER -gt 0 ] ; do
		if [ $(ping $GW | grep -c !) == 1 ] ; then
			echo "SWINFO: Found switch at $GW"
			SLEEPCOUNTER=0
		else
			SLEEPCOUNTER=$(($SLEEPCOUNTER-1))
			if [ $SLEEPCOUNTER -eq 0 ];then
				echo "SWINFO: ERROR! Failed to find switch at $GW"
				exit
			else
				echo "SWINFO: Unable to ping $GW. Checking again in 5 seconds..."
				sleep 5
			fi
		fi
	done
}
get_switch_family(){
# Determine the model of the connected switch by parsing the login prompt
	# Open telnet connection to switch and place switch response into a file SWITCH_PROMPT
	echo "SWINFO: Connecting to switch at $GW"
	(
		sleep 1
		printf "\r\r"
		break 2> /dev/null
	) | telnet $GW > SWITCH_PROMPT &
	sleep 1
	# Look for the login prompt in SWITCH_PROMPT
	export PROMPT=$(cat SWITCH_PROMPT | grep ser | cut -d':' -f1)
	# Check login prompt syntax to determine switch family
	if [ "$PROMPT" == "User Name" ] ; then
		export SWITCH=Cisco
	elif [ "$PROMPT" == "Username" ] ; then
		export SWITCH=Luxul
	else
		# If not able to determine switch family, error out
		echo "SWINFO: ERROR - Failed to determine switch family. All available TTY lines may be in use." 
		exit
	fi
	# Send message to dmesg about switch family and set 'astparam s switch'
		astparam s switch $SWITCH
		echo "SWINFO: Setting switch to $SWITCH"
	# Clean up by removing SWITCH_PROMPT
	rm -f SWITCH_PROMPT
}

get_my_port_cisco(){
# Determing which port the Receiver is connected on the switch
	# Log into switch using default credentials and check the mac-address table
	(
		sleep 1
		printf "cisco\r"
		printf "cisco\r"
		printf "show mac add add $MAC\r"
		sleep 1
		break 2> /dev/null
	) | telnet $GW > SHOW_MAC &
	sleep 2
	# Parse telnet respsone from switch to determine PORT
	export PORT=$(cat SHOW_MAC | grep -m 1 dynamic | tr -s ' ' | cut -d' ' -f4)
	# Set the port number (astparam s switchport)
		echo "SWINFO: Setting switchport to $PORT"
		astparam s switchport $PORT
	# Clean up by removing SHOW_MAC
	rm -f SHOW_MAC
}
get_my_port_luxul(){
# Determing which port the Receiver is connected on the switch
	# Log into switch using default credentials and check the mac-address table
	(
		sleep 1
		printf "admin\r"
		printf "admin\r"
		sleep 1
		printf "terminal length 0\r"
		printf "show mac add add $MAC\r"
		sleep 1
		break 2> /dev/null
	) | telnet $GW > SHOW_MAC &
	sleep 3
	# Parse telnet respsone from switch to determine PORT
	export PORT=$(cat SHOW_MAC | grep -m 1 Dynamic | tr -s ' ' | tr '\r' ' ' | cut -d' ' -f4-5)
	# Set the port number (astparam s switchport)
		echo "SWINFO: Setting switchport to $PORT"
		astparam s switchport $PORT
	# Clean up by removing SHOW_MAC
	rm -f SHOW_MAC
}
get_my_current_vlan_cisco(){
# Read 'show vlan' for this Receiver's port to determine the current Transmitter assignment
	(
		sleep 1
		printf "cisco\r"
		printf "cisco\r"
		printf "terminal datadump\r"
		printf "show run int $PORT\r"
		sleep 2
		break 2> /dev/null
	) | telnet $GW > CURRENT_VLAN_DATA &
	sleep 3
	export CURRENT_VLAN=$(cat CURRENT_VLAN_DATA	| grep allowed | tr '-' ',' | cut -d',' -f2 | cut -d' ' -f1)
#	export NATIVE_VLAN=$(cat CURRENT_VLAN_DATA | grep pvid | )
	## Set the Current VLAN (astparam s currentvlan)
	echo "SWINFO: Setting currentvlan to $CURRENT_VLAN"
	astparam s currentvlan $CURRENT_VLAN
	# Clean up by removing CURRENT_VLAN_DATA
	rm -f CURRENT_VLAN_DATA
}
get_my_current_vlan_luxul(){
# Read 'show vlan' for this Receiver's port to determine the current Transmitter assignment
	(
	sleep 1
	printf "admin\r"
	printf "admin\r"
	sleep 1
	printf "terminal length 0\r"
	printf "show run int $PORT\r"
	sleep 2
	break 2> /dev/null
	) | telnet $GW > CURRENT_VLAN_DATA &
	sleep 4
	export CURRENT_VLAN=$(cat CURRENT_VLAN_DATA	| grep allowed | tr '-' ',' | cut -d',' -f2 | cut -d' ' -f1)
	export PVID=$(cat CURRENT_VLAN_DATA | grep native | cut -d' ' -f5)
	## Set the Current VLAN (astparam s currentvlan)
	echo "SWINFO: Setting currentvlan to $CURRENT_VLAN"
	astparam s currentvlan $CURRENT_VLAN
	# Clean up by removing CURRENT_VLAN_DATA
	rm -f CURRENT_VLAN_DATA
}

generate_rx_ip_list(){
	local RX_PORT_LIST=($(lmparam g RX_PORT_LIST))
	# Generate Receiver IP list
	local RX_VLAN_IP=$(cat running-config | grep -m 1 -A 2 interface\ vlan\ 10 | grep address | cut -d' ' -f4)
	local RX_IP_PREFIX=$(echo $RX_VLAN_IP | cut -d'.' -f1-3)
	local RX_IP_BASE=$(echo $RX_VLAN_IP | cut -d'.' -f4)
	for i in ${!RX_PORT_LIST[*]};do
		if [ $i -eq 0 ];then
			RX_IP_LIST="$RX_IP_PREFIX.$(( $RX_IP_BASE + 1 + $i ))" 
		else
			RX_IP_LIST="$RX_IP_LIST $RX_IP_PREFIX.$(( $RX_IP_BASE + 1 + $i ))" 
		fi
	done
	lmparam s RX_IP_LIST $RX_IP_LIST
}

get_running_config_cisco(){
	echo "SWINFO: Obtaining switch running-config"
	(
		sleep 1
		printf "cisco\r"
		printf "cisco\r"
		sleep 1
		printf "terminal datadump\r"
		printf "sh run\r"
		sleep 15 
		break 2> /dev/null
		
	)| telnet $GW > running-config # log into switch, issue sh run command, and capture the output to a file

	export SWITCH_IP=$(cat running-config | grep -m 1 -A 2 interface\ vlan\ 2 | grep address | cut -d' ' -f4)
	
	export TOTAL_SOURCES=$(cat running-config | grep JAP | cut -d _ -f 2 | cut -d x -f 1)
	echo "SWINFO: Setting totalsources to $TOTAL_SOURCES"
	astparam s totalsources $TOTAL_SOURCES # set as an astparam value for use by other scripts
	
	cat running-config | grep -B 3 pvid\ 10 | grep giga | cut -d " " -f 2 | sed 's/^gigabitethernet//g' > rx_port_list # parse file to get list of receiver ports
	echo "SWINFO: Generating list of Receiver ports"
	lmparam s RX_PORT_LIST $(cat rx_port_list | tr '\r\n' ' \0')	# set as a temporary lmparam value for use by other scripts

	cat running-config | grep -B 1 pvid\ 10 | grep allowed | tr '-' ',' | cut -d',' -f2 | cut -d'u' -f1 > rx_vlan_list # parse file to get list of current Receiver TX VLANs
	echo "SWINFO: Extracting current Receiver VLAN data"
	lmparam s RX_VLAN_LIST $(cat rx_vlan_list | tr '\r\n' ' \0')	# set as a temporary lmparam value for use by other scripts
	
	echo "SWINFO: Generating Receiver IP Address data"
	generate_rx_ip_list
}
get_running_config_luxul(){
	echo "SWINFO: Obtaining switch running-config"
	(
		sleep 1
		printf "admin\r"
		printf "admin\r"
		sleep 1
		printf "terminal length 0\r"
		printf "sh run\r"
		sleep 8
		break 2> /dev/null
	)| telnet $GW > running-config # log into switch, issue sh run command, and capture the output to a file
	
	export SWITCH_IP=$(cat running-config | grep -m 1 -A 1 interface\ vlan\ 1 | grep address | cut -d' ' -f4)
	
	export TOTAL_SOURCES=$(cat running-config | grep JAP | awk '{print $2}' | cut -d _ -f 2 | cut -d x -f 1) # parse file to get number of transmitters in the system
	echo "SWINFO: Setting totalsources to $TOTAL_SOURCES"
	astparam s totalsources $TOTAL_SOURCES # set as an astparam value for use by other scripts
	
	cat running-config | grep -B 2 native\ vlan\ 10 | grep Giga | cut -d " " -f 3 > rx_port_list # parse file to get list of receiver ports
	echo "SWINFO: Generating list of Receiver ports"
	lmparam s RX_PORT_LIST $(cat rx_port_list | tr '\r\n' ' \0')	# set as a temporary lmparam value for use by other scripts
	
	cat running-config | grep -A 1 native\ vlan\ 10 | grep allowed | cut -d "," -f2 > rx_vlan_list # parse file to get list of current Receiver TX VLANs
	echo "SWINFO: Extracting current Receiver VLAN data"
	lmparam s RX_VLAN_LIST $(cat rx_vlan_list | tr '\r\n' ' \0')	# set as a temporary lmparam value for use by other scripts
	
	echo "SWINFO: Generating Receiver IP Address data"
	generate_rx_ip_list
}

query_cisco(){
	get_my_port_cisco
	get_my_current_vlan_cisco
	get_running_config_cisco
}
query_luxul(){
	get_my_port_luxul
	get_my_current_vlan_luxul
	get_running_config_luxul
}

get_cisco_tx_ports(){
	for i in ${!TX_VLAN_LIST[*]};do
		if [ $i -eq 0 ];then
			TX_PORT_LIST="$(cat running-config | grep -B 3 pvid\ ${TX_VLAN_LIST[i]} | grep giga | cut -d " " -f 2 | sed 's/^gigabitethernet//g' | tr '\r\n' ' \0')"
		else
			TX_PORT_LIST="$TX_PORT_LIST $(cat running-config | grep -B 3 pvid\ ${TX_VLAN_LIST[i]} | grep giga | cut -d " " -f 2 | sed 's/^gigabitethernet//g' | tr '\r\n' ' \0')"
		fi
	done
}
get_luxul_tx_ports(){
	for i in ${!TX_VLAN_LIST[*]};do
		if [ $i -eq 0 ];then
			TX_PORT_LIST="$(cat running-config | grep -B 2 native\ vlan\ ${TX_VLAN_LIST[i]} | grep Giga | cut -d " " -f 3 | tr '\r\n' ' \0')"
		else
			TX_PORT_LIST="$TX_PORT_LIST $(cat running-config | grep -B 2 native\ vlan\ ${TX_VLAN_LIST[i]} | grep Giga | cut -d " " -f 3 | tr '\r\n' ' \0')"
		fi
	done
}

whoami(){
	#Get information from current array data to determine this devices PORT and PVID
	MYIP=$(astparam g ipaddr)
	for i in ${!TX_IP_LIST[*]};do
		if [ "${TX_IP_LIST[i]}" == "$MYIP" ];then
			PORT=${TX_PORT_LIST[i]}
			PVID=${TX_VLAN_LIST[i]}
			VLAN=$PVID
		fi
	done
	for i in ${!RX_IP_LIST[*]};do
		if [ "${RX_IP_LIST[i]}" == "$MYIP" ];then
			PORT=${RX_PORT_LIST[i]}
			PVID=10
			VLAN=${RX_VLAN_LIST[i]}
		fi
	done
}

save_names(){
	echo "SWINFO: Saving current name settings from systeminfo.json"
	cat /www/switchplease/json/systeminfo.json | grep -B 1 name > temp_namefile
}

restore_names(){
	echo "SWINFO: Restoring saved names into updated systeminfo.json"
	IP_ARRAY=($(cat temp_namefile | grep ip | cut -d'"' -f4))
	NAME_ARRAY=($(cat temp_namefile | grep name | cut -d'"' -f4 | tr ' ' '_'))
	for i in ${!IP_ARRAY[*]};do
		NAME=$(echo ${NAME_ARRAY[i]} | tr '_' ' ')
		update_json.sh ${IP_ARRAY[i]} -n "$NAME"
	done
	rm -f temp_namefile
}

generate_json_basic(){
	case $SWITCH in
		Cisco) get_running_config_cisco;;
		Luxul) get_running_config_luxul;;
		*) echo "SWINFO: ERROR - Switch Model Undefined";;
	esac
	
	# Generate needed variables
	RX_PORT_LIST=($(lmparam g RX_PORT_LIST))
	RX_VLAN_LIST=($(lmparam g RX_VLAN_LIST))
	RX_IP_LIST=($(lmparam g RX_IP_LIST))
	
	# Generate Transmitter VLAN and port list
	TX_VLAN_LIST=11
	TX_VLAN_COUNT=1
	while [ $TX_VLAN_COUNT -lt $TOTAL_SOURCES ];do
		TX_VLAN_COUNT=$(($TX_VLAN_COUNT + 1))
		TX_VLAN_LIST="$TX_VLAN_LIST $((TX_VLAN_COUNT + 10))"
	done
	TX_VLAN_LIST=($TX_VLAN_LIST)
	case $SWITCH in
		Cisco) get_cisco_tx_ports;;
		Luxul) get_luxul_tx_ports;;
		*) echo "SWINFO: ERROR - Switch Model Undefined";;
	esac
	TX_PORT_LIST=($TX_PORT_LIST)
	# Generate Transmitter IP list
		TX_VLAN_IP=$(cat running-config | grep -m 1 -A 2 interface\ vlan\ 11 | grep address | cut -d' ' -f4)
		TX_IP_PREFIX=$(echo $TX_VLAN_IP | cut -d'.' -f1-3)
		for i in ${!TX_PORT_LIST[*]};do
			if [ $i -eq 0 ];then
				TX_IP_LIST="$TX_IP_PREFIX.$(( ($i+1) * 4 - 2 ))" 
			else
				TX_IP_LIST="$TX_IP_LIST $TX_IP_PREFIX.$(( ($i+1) * 4 - 2 ))" 
			fi
		done
	TX_IP_LIST=($TX_IP_LIST)
	SYSTEM_SIZE=$TOTAL_SOURCES\x${#RX_PORT_LIST[*]}
	
	mkdir /www/switchplease 2> /dev/null
	mkdir /www/switchplease/json 2> /dev/null
	
	# Check to see if Custom Names have been applied and save those names to a temporary file
	if [ -e /www/switchplease/json/systeminfo.json ] && [ $(cat /www/switchplease/json/systeminfo.json | grep -c name) -gt 0 ] 2> /dev/null;then
			save_names
	fi
	
	# Add this device MAC addres to systeminfo.json for unique system ID process
	MYMAC=$(lmparam g MY_MAC)
	
	# Generate the JSON file to /www/switchplease/json/systeminfo.json
	echo "SWINFO: Populating systeminfo.json with basic system information"
	(
	printf "{ \n"
	printf "\t\"system\":{ \n"
	printf "\t\t\"controlunit\":\"$MYMAC\", \n"	
	printf "\t\t\"size\":\"$SYSTEM_SIZE\", \n"	# Fill in $SYSTEM_SIZE"
	printf "\t\t\"switch\":{ \n"
	printf "\t\t\t\"ip\":\"$SWITCH_IP\", \n"	# Fill in $SWITCH_IP"
	printf "\t\t\t\"brand\":\"$SWITCH\" \n"		# Fill in $SWITCH
	printf "\t\t}, \n"
	printf "\t\t\"devices\":{ \n"
	printf "\t\t\t\"tx\":[ \n"
	for i in ${!TX_PORT_LIST[*]};do
		printf "\t\t\t\t{ \n"
		printf "\t\t\t\t\t\"id\":\"tx$(($i + 1))\", \n"
		printf "\t\t\t\t\t\"port\":\"${TX_PORT_LIST[i]}\", \n"	# Fill in for all indexes in $TX_PORT_LIST
		printf "\t\t\t\t\t\"ip\":\"${TX_IP_LIST[i]}\", \n"		# Fill in for all indexes in $TX_IP_LIST
		printf "\t\t\t\t\t\"vlan\":\"${TX_VLAN_LIST[i]}\", \n"	# Fill in for all indexes in $TX_VLAN_LIST
		printf "\t\t\t\t\t\"name\":\"Source $(($i + 1))\" \n" 	# Fill in default names
		if [ $i -lt $(( ${#TX_PORT_LIST[*]}-1 )) ] ; then
			printf "\t\t\t\t}, \n"
		else
			printf "\t\t\t\t} \n"
		fi
	done
	printf "\t\t\t], \n"
	printf "\t\t\t\"rx\":[ \n"
	for i in ${!RX_PORT_LIST[*]};do
		printf "\t\t\t\t{ \n"
		printf "\t\t\t\t\t\"id\":\"rx$(($i + 1))\", \n"
		printf "\t\t\t\t\t\"port\":\"${RX_PORT_LIST[i]}\", \n"	# Fill in for all indexes in $RX_PORT_LIST
		printf "\t\t\t\t\t\"ip\":\"${RX_IP_LIST[i]}\", \n"		# Fill in for all indexes in $RX_IP_LIST
		printf "\t\t\t\t\t\"vlan\":\"${RX_VLAN_LIST[i]}\", \n"	# Fill in for all indexes in $RX_VLAN_LIST
		printf "\t\t\t\t\t\"name\":\"Display $(($i + 1))\" \n"	# Fll in default names
		if [ $i -lt $(( ${#RX_PORT_LIST[*]}-1 )) ] ; then
			printf "\t\t\t\t}, \n"
		else
			printf "\t\t\t\t} \n"
		fi
	done
	printf "\t\t\t] \n"
	printf "\t\t} \n"
	printf "\t} \n"
	printf "} \n"
	) > /www/switchplease/json/systeminfo.json
	
	# Restore saved names into systeminfo.json
	if [ -e temp_namefile ];then
		restore_names
	fi
}
generate_json_advanced(){
	generate_json_basic
	echo "SWINFO: Adding Advanced System Details to systeminfo.json"
	rm -rf devices
	mkdir devices
	echo "SWINFO: Gathering detailed information on Transmitters"
##### Switch to DEBUG SCREEN to increase CPU/RAM and Inform GUI with Progress (62 character limit for GUI info)
	e e_stop_link
	{ printf "%s" "Gathering System Data - Please wait..." ; } > /var/info_local &
	whoami
	# Move this device between all Transmitter VLANs to gather data
	for i in ${!TX_IP_LIST[*]};do
		{ printf "%s" "Gathering System Data - Please wait... (TX $((i+1)) of ${#TX_IP_LIST[*]})" ; } > /var/info_local &
		switch port:$PORT vlan:${TX_VLAN_LIST[i]} pvid:10
		sleep 3
		getdeviceinfo.sh ${TX_IP_LIST[i]} tx$(( $i + 1 ))
	done
	# Move this device back to its original configuration
	switch port:$PORT vlan:$VLAN pvid:$PVID
	echo "SWINFO: Gathering detailed information on Receivers"
	for i in ${!RX_IP_LIST[*]};do
		{ printf "%s" "Gathering System Data - Please wait... (RX $((i+1)) of ${#RX_IP_LIST[*]})" ; } > /var/info_local &
		getdeviceinfo.sh ${RX_IP_LIST[i]} rx$(( $i + 1 )) &
	done
	COUNT=10
	while [ $COUNT -gt 0 ];do
		{ printf "%s" "Parsing System Data - Please wait... $COUNT seconds remaining" ; } > /var/info_local &
		sleep 1
		COUNT=$(($COUNT-1))
	done
	e e_reconnect
}

get_device_info
get_switch_status
get_switch_family

if [ "$1" == "vlans" ] ; then
	case $SWITCH in
		Cisco) get_running_config_cisco;;
		Luxul) get_running_config_luxul;;
		*) echo "SWINFO: ERROR - Switch Model Undefined";;
	esac
	exit
elif [ "$1" == "json" ] ; then
	if [ "$2" == "advanced" ] ; then
		generate_json_advanced
	else
		generate_json_basic
	fi
	exit
fi

# Evaluate $SWITCH to determine login credentials and syntax
case $SWITCH in
	Cisco) query_cisco;;
	Luxul) query_luxul;;
	*) echo "SWINFO: ERROR - Switch Model Undefined";;
esac
