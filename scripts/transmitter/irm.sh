#!/bin/sh
## IR Manager Control
## Usage:
## Recalls previously learned IR commands from a Just Add Power 2G IR Manager by bank (1-4) and command (1-32)
## irm.sh [IR BANK] [IR COMMAND] [w/x]
## [IR BANK] - Can be any number 1-4 to specify the IR Manager Bank #
## [IR COMMAND] - Can be any number 1-32 to specify the IR Bank's Command #
## [(w)RITE/E(x)ECUTE]
## 		w: Write a new IR value
##		x: Execute the stored IR command
##
## NOTE:
## This JAP device must be set for Type 3 CLI RS232 Communication for these commands to function.
## Apply the following command to enable Type 3 CLI RS232 Access:
## astparam s soip_type2 n;astparam s soip_guest_on y;astparam save;reboot

## Determine RS232 Mode
export MODECHECK=$(astparam g soip_type2)$(astparam g soip_guest_on)
if [ $MODECHECK = "ny" ]; then

## Generate IR Commands
if [ $1 -gt 0 -a $1 -lt 5 ] ; then
	export BANK=$(($1 - 1))
if [ $2 -gt 0 -a $2 -lt 33 ] ; then
	export COMMAND=$(($2 - 1))	
	if [ $COMMAND -lt 16 ] ; then
		export COMMANDHEX=$(echo \\x0)$(printf "%x\n" $COMMAND)
	else
		export COMMANDHEX=$(echo \\x)$(printf "%x\n" $COMMAND)
	fi
	export IRLEARN=$(echo \\x56\\x00\\x0b\\x01\\x0)$(echo $BANK)$(echo $COMMANDHEX)
	export IRFLASH=$(echo \\x56\\x00\\x0b\\x00\\x0)$(echo $BANK)$(echo $COMMANDHEX)
	stty 9600 -F /dev/ttyS0
	
## PLANNED: Check RS232 Mode
	
## Apply Command based on w/x (write=learn, execute=flash) from $3
if [ $3 = "w" ] ; then
	printf "$IRLEARN" > /dev/ttyS0
#	echo LEARN $IRLEARN	## uncomment when checking learn string, comment out when finished
elif [ $3 = "x" ] ; then
	printf "$IRFLASH" > /dev/ttyS0
#	echo FLASH $IRFLASH	## uncomment when checking flash string, comment out when finished
else
	echo "Specify whether to write or execute (w/x) BANK "$(($BANK + 1))"/CMD "$(($COMMAND + 1))
fi

else
	echo 'Error: incorrect syntax. Please use:'
	echo 'irm.sh [BANK#(1-4)] [COMMAND#(1-32)] [wRITE/ExECUTE(w/x)]'
fi
else
	echo 'Error: incorrect syntax. Please use:'
	echo 'irm.sh [BANK#(1-4)] [COMMAND#(1-32)] [wRITE/ExECUTE(w/x)]'
fi

else
	echo 'Error: wrong RS232 mode. Please switch to Type 3 CLI mode. Use:'
	echo 'astparam s soip_type2 n;astparam s soip_guest_on y;astparam save;reboot'
fi