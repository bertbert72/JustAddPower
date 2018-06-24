#!/bin/bash
## Last modified 2017-07-06 - Just Add Power
## Generates a list of all Receivers and then Telnets to each to execute a specified command $1
## For commands requiring a space, surround full command with " "

send_telnet_command(){
	(
		sleep 1
		printf "\r$COMMAND\r"
		sleep 1
		printf "exit\r"
	) | telnet $1 &> /dev/null
}
build_rx_list(){
	RX_IP_LIST=($(node_list -t client | grep client | tr '\t ' '-' | cut -d'-' -f1))
	MY_IP=$(lmparam g IPADDR)
}

# Verify data exists and is not 'reset_to_default.sh'
COMMAND=$1
if [ "$COMMAND" == "" ];then
	echo "CALLRX: Please specify a command to send to all Receivers"
elif [ "$COMMAND" == "reset_to_default.sh" ];then
	echo "CALLRX: '$COMMAND' not supported"
else
	# Build a list of Receivers and send the $COMMAND to them
	build_rx_list
	for i in ${!RX_IP_LIST[*]};do
		if [ "${RX_IP_LIST[i]}" != "$MY_IP" ];then
			echo "Sending command to Receiver $(($i + 1)) of ${#RX_IP_LIST[*]}"
			send_telnet_command ${RX_IP_LIST[i]} &
		fi
	done
	$COMMAND
	echo "Done: Command sent to ${#RX_IP_LIST[*]} Receivers"
fi