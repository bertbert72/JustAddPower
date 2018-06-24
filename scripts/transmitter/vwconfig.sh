#!/bin/bash
## Last modified 2017-06-06 - Just Add Power
## Has a TX or RX configure each RX in a video wall with its wall position and bezel gap measurements.
## Run the command on a RX for best results; on a TX it will only be able to configure the devices currently watching that TX
## vw_config.sh [&RX1-&RX2-&RX3-&RX4] [&ROWx&COL] [&STORE/RECALL] [&ORIENTATION] [&OW-&OH-&VW-&VH]
## &RX1, &RX2, etc are the Receiver numbers of the screens. RX1 is the Receiver in the top-left corner of the wall (row 1, column 1) and numbering continues left-to-right until all RX in that row have been assigned, then moves onto the next row until all RX are assigned.
## (optional) &ROW is the number of rows in the wall. &COL is the number of columns in the wall.
## (optional) &STORE/RECALL either stores the current VW positioning for the displays, or recalls a previously-stored VW positioning
## (optional) $ORIENTATION sets the rotate value for the screens. Options are 0, 90, 180, 270, i (0 is default, i is for inverted top-row only)
## (optional) &OW, &OH, &VW, &VH are the bezel gap values
## Example: vw_config.sh 1-2-3-4 2x2 0 160-90-155-85
## Configures a 2x2 wall with bezel measurements of OW=160, OH=90, VW=155, VH=85. RX1 is the top-left, RX2 is the top-right, RX3 is the bottom-left, and RX4 is the bottom-right.

## Future additions:
	## Capture current video wall status before making changes. Save as lmparam as array in the format RX.TR_TC_RP_CP (example: 1.1_1_0_0 for Receiver 1 as r1c1 of 2x2 wall)

: ' Pseudocode
 Define script structure
 Create inputs for row, column, Receiver list, bezel gap measurements, (inversion/orientation?)
 Check validity of input variables and split into useable format
 Get IP parameter commands from the device and extrapolate RX IPs from that
 Telnet to each Receiver and send configuration commands
	bezel gap
	row, position settings
	astparam settings for overall position
 Send message to user that script succeeded
'


## ***Begin Help functions***
## Overall Help
function fullhelp () {
	echo ' Command:'
	echo '	vw_config.sh [RX List] [store/recall] [ROWxCOL] [Orientation] [Bezel]'
	echo ' Mandatory Parameters:'
	echo '	RX list	A hyphen-separated, ordered list of the Receivers in the wall.'
	echo '		List Receivers in order starting in the top-left corner and going across.'
	echo '		No duplicates allowed.'
	echo ' Optional Parameters: at least one required'
	echo '	ROWxCOL'
	echo '		ROW	Number of rows in the wall (1-16)'
	echo '		COL	Number of columns in the wall (1-16)'
	echo '	Orientation	The alignment of the video wall screens (portrait, flipped top row, etc)'
	echo '		0 = standard orientation (default)'
	echo '		90 = 90-degree clockwise video rotation'
	echo '		180 = 180-degree clockwise video rotation (upside-down)'
	echo '		270 = 270-degree clockwise video rotation'
	echo '		i = top row of a 2-row video wall has inverted displays'
	echo '	Bezel	A hyphen-separated list of Bezel Gap measurements in the format OW-OH-VW-VH.'
	echo '		All values should be between 1-65000. Any unit of measurement. No decimals.'
	echo '		OW = Outside width of the display'
	echo '		OH = Outside height of the display'
	echo '		VW = Video width of the display'
	echo '		VH = Video height of the display'
	echo '	store/recall'
	echo '		store = stores the video wall configuration of the Receivers in the list'
	echo '		recall = recalls the previously-stored video wall configuration of the Receivers in the list'
	echo ' Examples:'
	echo '	vw_config.sh 1,2,3,4 2x2 160-90-155-85'
	echo '		Sets up a 2x2 wall with Receivers 1-4 at standard orientation and bezels of OW=160,OH=90,VW=155,VH=85'
	echo '	vw_config.sh 6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21 4x4'
	echo '		Sets up a 4x4 wall with Receivers 6-21 at standard orientation (no change to bezel settings)'
	echo '	vw_config.sh 1,2,3 3x1 90'
	echo '		Sets up a 4x4 wall with Receivers 1-3 at 90-degree rotation and bezels of OW=1,OH=1,VW=1,VH=1'
	echo '	vw_config.sh 1,2,3,4 store'
	echo '		Store the video wall settings for Receivers 1-4'
	echo '	vw_config.sh 1,2,3,4 recall'
	echo '		Recall and apply previously-stored video wall settings for Receivers 1-4'
	echo '	vw_config.sh 1,2,3,4 store 2x2'
	echo '		Store the current video wall positioning for Receivers 1-4 then switch them to a 2x2 wall at standard orientation'
	echo ''
}

##Recall/store help only
function recallstorehelp () {
	echo ' Command:'
	echo '	vw_config.sh [RX List] [store/recall]'
	echo ' Mandatory Parameters:'
	echo '	RX list	A hyphen-separated, ordered list of the Receivers in the wall.'
	echo '		List Receivers in order starting in the top-left corner and going across.'
	echo '		No duplicates allowed.'
	echo '	store/recall'
	echo '		store = stores the video wall configuration of the Receivers in the list'
	echo '		recall = recalls the previously-stored video wall configuration of the Receivers in the list'
	echo '	vw_config.sh 1,2,3,4 store'
	echo '		Store the video wall settings for Receivers 1-4'
	echo '	vw_config.sh 1,2,3,4 recall'
	echo '		Recall and apply previously-stored video wall settings for Receivers 1-4'
	echo ''
}

##Config help only
function confighelp () {
	echo ' Command:'
	echo '	vw_config.sh [RX List] [ROWxCOL] [Orientation] [Bezel]'
	echo ' Mandatory Parameters:'
	echo '	RX list	A comma-separated, ordered list of the Receivers in the wall.'
	echo '		List Receivers in order starting in the top-left corner and going across.'
	echo '		No duplicates allowed.'
	echo '	ROWxCOL'
	echo '		ROW	Number of rows in the wall (1-16)'
	echo '		COL	Number of columns in the wall (1-16)'
	echo ' Optional Parameters:'
	echo '	Orientation	The alignment of the video wall screens (portrait, flipped top row, etc)'
	echo '		0 = standard orientation (default)'
	echo '		90 = 90-degree clockwise video rotation'
	echo '		180 = 180-degree clockwise video rotation (upside-down)'
	echo '		270 = 270-degree clockwise video rotation'
	#echo '		i = top row of a 2-row video wall has inverted displays'
	echo '	Bezel	A hyphen-separated list of Bezel Gap measurements in the format OW-OH-VW-VH.'
	echo '		All values should be between 1-65000. Any unit of measurement. No decimals.'
	echo '		OW = Outside width of the display'
	echo '		OH = Outside height of the display'
	echo '		VW = Video width of the display'
	echo '		VH = Video height of the display'
	echo ' Examples:'
	echo '	vw_config.sh 1,2,3,4 2x2 0 160-90-155-85'
	echo '		Sets up a 2x2 wall with Receivers 1-4 at standard orientation and bezels of OW=160,OH=90,VW=155,VH=85'
	echo '	vw_config.sh 6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21 4x4'
	echo '		Sets up a 4x4 wall with Receivers 6-21 at standard orientation (no change to bezel settings)'
	echo '	vw_config.sh 1,2,3 3x1 90'
	echo '		Sets up a 3x1 portrait wall with Receivers 1-3 at 90-degree video rotation and bezels of OW=1,OH=1,VW=1,VH=1'
	#echo '	vw_config.sh 1,2,3,4 2x2 i 160-90-155-85'
	#echo '		Sets up a 2x2 wall with Receivers 1-4 where Receiver 1 & 2 are the top row and are upside-down and bezels of OW=160,OH=90,VW=155,VH=85'
	echo ''
}

##
## ***End Help functions***



## ***Begin Additional functions***

## Decimal-to-binary calculator. Only works on numbers 0-255
#function d2b () {
#local TEST=$1
#local ANSWER=""
#	for i in 7 6 5 4 3 2 1 0
#		do
#			local POWER=$((2 ** $i))
#			if [ $(($TEST - $POWER)) -ge 0 ] ; then
#				ANSWER="${ANSWER}1"
#				TEST=$(($TEST - $POWER))
#			else
#				ANSWER="${ANSWER}0"
#			fi
#		done
#echo "$ANSWER"
#}

## Function that holds commands to send to the Receiver once telnet connection established
function rxconfig () {
	(
	sleep 1
	if [ $VWRX -ne 0 ]; then
		echo "e e_vw_enable_${ROW}_${COL}_${CURROW}_${CURCOL}"
		#echo "astparam s vw_pos_idx r${CURROW}c${CURCOL}"
		#echo "astparam save"
	fi
	if [ "$BEZEL" != "0" ]; then
		echo "e e_vw_moninfo_${BEZELARRAY[2]}_${BEZELARRAY[0]}_${BEZELARRAY[3]}_${BEZELARRAY[1]}"
	fi
	echo "e e_vw_rotate_${ROTATE}"
	sleep 1
	##echo "exit"
	) | telnet $1 1>/dev/null 2>> vw_error_log &
}

## Function to increment the column and row value for the video wall position assignment
function nextrx () {
	if [ $CURCOL -eq $COL ] ; then
		CURCOL=0
		CURROW=$((CURROW+1))
	else
		CURCOL=$((CURCOL+1))
	fi
}
## Function to calculate the IP of the Receiver that will be telnetted to. Input is a single integer variable: the Receiver number
function calcrx () {
	local TEMP=$((${RXGWARRAY[3]}+$1))
	local TEMPNEWIP="${RXGWARRAY[0]}.${RXGWARRAY[1]}.${RXGWARRAY[2]}.$TEMP"
	echo "$TEMPNEWIP"
}

## ***End Additional Functions***

## Begin script
echo > vw_error_log

## ***Begin Check & Assign Variables***

	## Check proper number of variables in the command
	if [ $# -lt 2 ]; then
		echo -e "ERROR! More than one variable is needed. Separate each variable with a space."
		confighelp
		exit
	elif [ $# -gt 5 ]; then
		echo -e "ERROR! Too many variables. Separate each variable with a space."
		confighelp
		exit
	fi

	
	## List default values for all variables
	export STORE=0
	export RECALL=0
	export BEZEL=0
	export VWRX=0
	export ROTATE=0
	export ORIENTATION=0
	export RXLIST=0
	export ROW=0
	export COL=0
	## Loop through variables to check what they are and format them appropriately
	while [ $# -gt 0 ]; do
		i=$(echo $1 | awk '{print tolower($0)}')
		case $i in
		## If variable is 'store'
			store)
				STORE=1
				RECALL=0
				echo 'Store function not yet implemented'
				;;
				
		## If variable is 'recall'
			recall)
				STORE=0
				RECALL=1
				echo 'Recall function not yet implemented'
				;;
				
		## If variable is a bezel gap value
			*-*)
				if [ $(echo $i | awk -F'-' '{print NF}') -ne 4 ]; then
					echo -e "The Bezel input of $i is incorrectly formatted.\nCorrect bezel gap formatting is OW-OH-VW-VH."
					exit
				fi
				## Split the Bezel Gap into an array
				BEZELARRAY=(${i//-/ })
				## Check that each BEZELARRAY item is a positive integer between 1 and 65000
				for j in "${BEZELARRAY[@]}"
					do
						if [ "$j" -eq "$j" ] 2>/dev/null ; then
							if [ $j -gt 65000 ] || [ $j -lt 1 ] ; then
								echo -e "ERROR!\nBezel value $j is invalid. Please enter an integer between 1 and 65000.\n"
								confighelp
								exit
							fi
						else
							echo "ERROR!\nBezel value $j is invalid. Please enter an integer between 1 and 65000.\n"
							confighelp
							exit
						fi
					done
				## Check that the VW/VH values are lower than the OW/OH values
				if [ ${BEZELARRAY[0]} -lt ${BEZELARRAY[2]} ] ; then
					echo -e "ERROR!\nOW cannot be smaller than VW.\nPlease correct and re-enter bezel values.\n"
					confighelp
					exit
				elif [ ${BEZELARRAY[1]} -lt ${BEZELARRAY[3]} ] ; then
					echo -e "ERROR!\nOH cannot be smaller than VH.\nPlease correct and re-enter bezel values.\n"
					confighelp
					exit
				else
					BEZEL=$i
				fi
				;;
				
		## If variable is a video wall size
			*x*)
				if [ $(echo $i | awk -F'x' '{print NF}') -ne 2 ]; then
					echo -e "The video wall size of $i is incorrectly formatted.\nCorrect video wall formatting is ROWxCOL."
					exit
				elif [ $(echo $i | cut -d'x' -f1) -gt 16 ] || [ $(echo $i | cut -d'x' -f2) -gt 16 ]; then
					echo -e "The maximum video wall size is 16x16.\nPlease set the row and column to less than 16."
					exit
				else
					ROW=$(echo $i | cut -d'x' -f1)
					COL=$(echo $i | cut -d'x' -f2)
					VWRX=$(($ROW * $COL))
					ROW=$((ROW-1))
					COL=$((COL-1))
				fi
				;;
				
		## If variable is orientation
			0|90|180|270|i)
				ORIENTATION=$i
				if [ $i = 90 ]; then
					ROTATE=5
				elif [ $i = 180 ]; then
					ROTATE=3
				elif [ $i = 270 ]; then
					ROTATE=6
				else
					ROTATE=0
				fi
				;;
				
		## If variable is the RX List
			*,*|[1-9][0-9]*)
				RXLIST=$i
				## Count the number of RX in the list. 
				export COUNTRX=$(echo $RXLIST | awk -F',' '{print NF}')
				## Split the Receiver member list into an array
				RXARRAY=(${RXLIST//,/ })
				## Check for duplicate Receivers in the list (no duplicates allowed)
				export DUPLICATE=$(printf '%s\n' "${RXARRAY[@]}"|awk '!($0 in seen){seen[$0];c++} END {print c}')
				if [ $DUPLICATE != ${#RXARRAY[@]} ] ; then
					DUPLICATENUM=$((${#RXARRAY[@]} - $DUPLICATE))
					echo -e "$DUPLICATENUM duplicate Receiver(s) found. Please remove all duplicates.\n"
					confighelp
					exit
				fi
				## Check if each RXARRAY item is a positive integer
				for i in "${RXARRAY[@]}"
					do
						if  [ "$i" -eq "$i" ] 2>/dev/null ; then
							echo -e "Receiver $i identified as a video wall Receiver."
						else
							echo -e "ERROR!\nReceiver $i in list is invalid. Please enter a valid Receiver number.\n"
							confighelp
							exit
						fi
					done
				;;
				
		## If variable is unidentified
			*)
				confighelp
				exit
				;;
				
		esac
		shift 1
	done
	
	##Check that values agree with each other after all values have been assigned
	if [ $RXLIST = 0 ]; then
		echo -e "ERROR!\nAt least one Receiver must be selected. Separate multiple Receivers with commas."
		exit
	elif [ $VWRX -ne 0 ] && [ $COUNTRX -ne $VWRX ]; then
		echo -e "ERROR!\n$VWRX Receivers expected but only $COUNTRX are listed." 
		exit
	else
		echo -e "All variables pass!"
	fi
## ***End Check & Assign Variables***


## ***Begin IP Calculations***
	export BASEIP=$(astparam g ipaddr)
	export BASENET=$(astparam g netmask)
	export BASEGW=$(astparam g gatewayip)
	##Split all IPs into arrays
	NETARRAY=(${BASENET//./ })
	IPARRAY=(${BASEIP//./ })
	GWARRAY=(${BASEGW//./ })
	##Identify octet of first 0 in subnet mask
	NETZERO=0
	for i in "${NETARRAY[@]}"
		do
			if [ $i -eq 255 ] ; then
				NETZERO=$((NETZERO+1))
			elif [ $i -ne 0 ] ; then
				echo -e "Video wall script does not support $i in the subnet mask. Only Class A, B, and C ranges are supported.\nVideo wall setup must be done through web interface.\n"
				exit
			fi
		done
	## Use octet position of first 0 to identify first RX value
	case "$NETZERO" in
		0)
			echo -e "ERROR!\nCan't be 0.\n"
			instructions
			exit
			;;
		1)
			export RXGW="${IPARRAY[0]}.128.${IPARRAY[2]}.1"
			;;
		2)
			export RXGW="${IPARRAY[0]}.${IPARRAY[1]}.128.1"
			;;
		3)
			export RXGW="${IPARRAY[0]}.${IPARRAY[1]}.${IPARRAY[2]}.129"
			;;
		*)
			echo -e "ERROR!\nCan't be higher than 3.\n"
			instructions
			exit
			;;
	esac
	RXGWARRAY=(${RXGW//./ })
## ***End IP Calculations***

## ***Begin construct and send commands over telnet***
	## Set current row and current column to 0
	CURROW=0
	CURCOL=0
	## Loop through all Receivers to calculate the IP, telnet to the device, and send the appropriate commands. Then, increment the row/column value for the next RX.
	for i in "${RXARRAY[@]}"
		do
			export TEMPRXIP=$(calcrx $i)
			echo -e "Configuring $TEMPRXIP with:\n Row Position:		$CURROW\n Column Position:	$CURCOL\n Orientation:		$ORIENTATION"
			if [ "$BEZEL" != "0" ]; then
				echo -e " OW:			${BEZELARRAY[0]}\n OH:			${BEZELARRAY[1]}\n VW:			${BEZELARRAY[2]}\n VH:			${BEZELARRAY[3]}\n"
			fi
			rxconfig $TEMPRXIP
			nextrx
		done
	sleep 3
## ***End construct and send commands over telnet***
	
## ***Begin print error report for unreachable Receivers***
	export UNREACH=$(cat vw_error_log | grep -c "cannot")
	if [ $UNREACH -ne 0 ] ; then
		echo "Only $((TOTALRX - UNREACH)) of $TOTALRX Receivers were properly configured."
		echo "The following device(s) were unreachable:"
		cat vw_error_log | cut -d'(' -f2 | cut -d')' -f1
	else
		echo "All Receivers were properly configured."
	fi
	rm -f vw_error_log
## ***End print error report for unreachable Receivers***