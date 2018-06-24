#!/bin/sh
#fluxhandler.sh
export S2=$(astparam g soip_type2)
export GUEST=$(astparam g soip_guest_on)
if [ "$S2" == "y" ] && [ "$GUEST" == "y" ] ; then
			export TYPE=2
elif [ "$S2" == "n" ] && [ "$GUEST" == "y" ] ; then
			export TYPE=3
else
	export S2=$(astparam r soip_type2)
	export GUEST=$(astparam r soip_guest_on)
	if [ "$S2" == "y" ] && [ "$GUEST" == "y" ] ; then
		export TYPE=2
	elif [ "$S2" == "n" ] && [ "$GUEST" == "y" ] ; then
		export TYPE=3
	fi
fi
while read input; do
    export INPUT="$input"
	export COMMAND=$(echo $INPUT | cut -f1 -d',')
	if [ "$COMMAND" == "sendir" ] ; then
		if [ $TYPE == 2 ] ; then
			printf "\x0d$INPUT\x0d" | nc 127.0.0.1 6752
		elif [ $TYPE == 3 ] ; then
			stty 9600 -F /dev/ttyS0
			printf "\x0d$INPUT\x0d" > /dev/ttyS0
		fi
		printf "completeir,1:1,1\r"
	elif [ "$COMMAND" == "getdevices" ] ; then
		printf "device,0,0 ETHERNET\r"
		printf "device,1,1 IR\r"
		printf "endlistdevices\r"
	elif [ "$COMMAND" == "getversion" ] ; then
		printf "version,1,FluxCapacitor_v1\r"
	elif [ "$COMMAND" == "get_NET" ] ; then
		export IP=$(astparam g ipaddr)
		export NM=$(astparam g netmask)
		export GW=$(astparam g gatewayip)
		printf "NET,0:1,LOCKED,STATIC,$IP,$NM,$GW\r"
	elif [ "$COMMAND" == "get_IR" ] ; then
		printf "IR,1:1,IR\r"
	elif [ "$COMMAND" == "stopir" ] ; then
		printf "stopir,1:1\r"
	else
		if [ $TYPE == 2 ] ; then
			printf "\x0d$INPUT\x0d" | nc 127.0.0.1 6752
		elif [ $TYPE == 3 ] ; then
			stty 9600 -F /dev/ttyS0
			printf "\x0d$INPUT\x0d" > /dev/ttyS0
		fi
	fi
done
