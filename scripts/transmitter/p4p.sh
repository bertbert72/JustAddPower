#!/bin/sh
#p4p [channel] [OPTION] [OPTION] [...]
# 
#OPTIONS
# [layer:ABCD] (Required for ANY instance of region overlap) Sets the layering selection for overlapping regions, where the options are 1 - 4 (CH#) with A as the top layer, and D as the bottom layer
# [ch1|ch2|ch3|ch4] Select +4+ channel for proceeding commands (Where CH1 is the Primary Video Selection rather than the Receiver input)
# [getres] Returns the current resolution of the selected +4+ channel
# [hpos:HORIZONTAL_POSITION] Set the Horizontal start position for the +4+ channel, where HORIZONTAL_POSITION is from 0 - 1920, and 0 is the left side of the screen
# [vpos:VERTICAL_POSITION] Set the Vertical start position for the +4+ channel, where VERTICAL_POSITION is from 0 - 1080, and 0 is the top of the screen
# [width:IMAGE_WIDTH] Set the Width of the +4+ channel active image, where IMAGE_WIDTH is from 64 - 1920 pixels wide, to the right from [hpos:HORIZONTAL_POSITION]
# [height:IMAGE_HEIGHT] Set the Height of the +4+ channel active image, where IMAGE_HEIGHT is from 36 - 1080 pixels high, down from the [vpos:VERTICAL_POSITION]
#Under Development (probably wont look too cool or work right)
# [fade:AB] Initiates a fade from +4+ channel A to channel B, where A and B are the CH#, and all 4 channels are set to overlap entirely (same hpos, vpos, width and height)

source GW_IIC_FUNC
if [ $# -eq 0 ]; then
 return;
fi
error(){
	printf "ERROR! Invalid Parameter [$1]\nPlease check the value and try again\n"
}
send_command(){
	wr_reg.sh $1 $2 $3
}
pixel_handler(){
export hex=$(ten_2_hex $1)
if [ $1 -gt 255 ] &&  [ $1 -le 2112 ] ; then
	echo 0"$hex"
elif [ $1 -lt 255 ] &&  [ $1 -ge 0 ] ; then
	echo 00"$hex"
else
	echo "FAIL!"
	break
fi
}
layer_handler(){
  echo 3 60 > $IO_SELECT
  echo $FUNC_TYPE_OFFSET $_4SCR_LAYER > $IO_VALUE
	
	echo $SET_ARGS_OFFSET 4 > $IO_VALUE                # data length
	echo $SET_ARGS_OFFSET $(echo $1 | cut -c1) > $IO_VALUE                
	echo $SET_ARGS_OFFSET $(echo $1 | cut -c2) > $IO_VALUE                
	echo $SET_ARGS_OFFSET $(echo $1 | cut -c3) > $IO_VALUE                
	echo $SET_ARGS_OFFSET $(echo $1 | cut -c4) > $IO_VALUE                
	echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE	 
}

fade_handler(){
  if [ $# -lt 3 ] ; then
  		return
	fi
  
  echo 3 60 > $IO_SELECT
  echo $FUNC_TYPE_OFFSET $_4SCR_CUSTM_LAYOUT > $IO_VALUE
  
  echo $SET_ARGS_OFFSET 4 >  $IO_VALUE          # data length
  echo $SET_ARGS_OFFSET $FADE > $IO_VALUE       # type
  echo $SET_ARGS_OFFSET $1 > $IO_VALUE          # ch 1
  echo $SET_ARGS_OFFSET $2 > $IO_VALUE          # ch 2
  echo $SET_ARGS_OFFSET $3 > $IO_VALUE          # duty
  
  echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE	
}
get_resolution(){
	export BANK=$(($1*2+11))
	export RES_HEX="$(rd_reg.sh $BANK 1e)""$(rd_reg.sh $BANK 1d)"
	export RES=$(hex_2_ten $RES_HEX)
	case $RES in
		479|480) export RES=480;;
		720|721) export RES=720;;
		1080|1081) export RES=1080;;
	esac
	echo $RES
}
hscale(){
	#RESOLUTION is $1 / WIDTH is $2 / CHANNEL is $3
	export HRES1=$1
	export HRES2=$2					#SET NEW TARGET HORIZONTAL RESOLUTION
	case $1 in						#CONVERT INITIAL HORIZONTAL RESOLTION 
		480) export HRES1=640;;
		720) export HRES1=1280;;
		1080) export HRES1=1920;;
	esac
	#DEFINE BANKS
	export ZO_BANK=$(($3*3-1))		#BANK FOR ZOOM AND OACT (2/5/8/11)
	export SI_BANK=$(($3*2+11))		#BANK FOR SHRINK AND IACT (13/15/17/19)
	if [ $HRES2 -lt $HRES1 ] ; then		#SHRINK
		#STEP1 - DISABLE HORIZONTAL ZOOM
			send_command $ZO_BANK 46 00
		#STEP2 - SET HORIZONTAL SHRINK RATIO (HSSCL)
			export HSSCL=$(ten_2_hex $(awk "BEGIN {print ($HRES2-1)/($HRES1-1)*65536}"))	#CALCULATE HSSCL
			send_command $SI_BANK 47 $HSSCL
		#STEP3 - SELECT SHRINK SET FROM LUTROM
			send_command 0 4A 14
		#STEP4 - LOAD SELECTED SHRINK SET INTO H SHRINK CIRCUIT 
			export SELLUT=$(ten_2_hex $(($3*4-1+128)))		#DETERMINE SELLUT FOR H SHRINK CIRCUIT (3/7/11/15 + 128[GO])
			send_command 0 4B $SELLUT
		#STEP5 - SET H SIZE TO NEW WIDTH (HRES2)
			export HRES_HEX=$(pixel_handler $HRES2)
			send_command $SI_BANK 19 $HRES_HEX		#SET IACTHW TO NEW HORIZONTAL RESOLUTION
			send_command $ZO_BANK 0A $HRES_HEX		#SET OACTHW TO NEW HORIZONTAL RESOLUTION
		#STEP6 - ENABLE HORIZONTAL SHINK
			send_command $SI_BANK 44 47
	elif [ $HRES2 -gt $HRES1 ] ; then		#ZOOM
		#STEP1 - DISABLE HORIZONTAL SHRINK
			send_command $SI_BANK 44 00
		#STEP2 - SET HORIZONTAL ZOOM RATIO (HZSCL)
			export HZSCL=$(ten_2_hex $(awk "BEGIN {print ($HRES1-1)/($HRES2-1)*65536}"))	#CALCULATE HZSCL
			send_command $ZO_BANK 49 $HZSCL
		#STEP3 - SELECT ZOOM SET FROM LUTROM
			send_command 0 4A 2E
		#STEP4 - LOAD SELECTED ZOOM SET INTO H ZOOM CIRCUIT
			export SELLUT=$(ten_2_hex $(($3*4-3+128)))		#DETERMINE SELLUT FOR H ZOOM CIRCUIT (1/5/9/13 + 128[GO])
			send_command 0 4B $SELLUT
		#STEP5 - SET H SIZE TO INITIAL WIDTH (HRES1)
			export HRES_HEX=$(pixel_handler $HRES1)
			send_command $SI_BANK 19 $HRES_HEX		#SET IACTHW TO INITIAL HORIZONTAL RESOLUTION
			send_command $ZO_BANK 0A $HRES_HEX		#SET OACTHW TO INITIAL HORIZONTAL RESOLUTION
		#STEP6 - ENABLE HORIZONTAL ZOOM
			send_command $ZO_BANK 46 47
	else
		#NO ZOOM OR SHRINK - CLEAR HZOOMCT AND HSHRNKCT
			export HRES_HEX=$(pixel_handler $HRES2)
			send_command $SI_BANK 19 $HRES_HEX		#SET IACTHW TO INITIAL HORIZONTAL RESOLUTION
			send_command $ZO_BANK 0A $HRES_HEX		#SET OACTHW TO INITIAL HORIZONTAL RESOLUTION
			send_command $ZO_BANK 46 00
			send_command $SI_BANK 44 00
	fi
}
vscale(){
	#resolution is $1 / height is $2 / channel is $3
	export VRES1=$1
	export VRES2=$2
	#DEFINE BANKS
	export ZO_BANK=$(($3*3-1))		#BANK FOR ZOOM AND OACT (2/5/8/11)
	export SI_BANK=$(($3*2+11))		#BANK FOR SHRINK AND IACT (13/15/17/19)
	if [ $VRES2 -lt $VRES1 ] ; then		#SHRINK
		#STEP1 - DISABLE VERTICAL ZOOM
			send_command $ZO_BANK 4B 00
		#STEP2 - SET HORIZONTAL SHRINK RATIO (VSSCL)
			export VSSCL=$(ten_2_hex $(awk "BEGIN {print ($VRES2 - 1)/($VRES1 - 1)*65536}"))
			send_command $SI_BANK 4C $VSSCL
		#STEP3 - SELECT SHRINK SET FROM LUTROM
			send_command 0 4A 14
		#STEP4 - LOAD SELECTED SHRINK SET INTO V SHRINK CIRCUIT 
			export SELLUT=$(ten_2_hex $(($3*4-2+128)))		#DETERMINE SELLUT FOR V SHRINK CIRCUIT (2/6/10/14 + 128[GO])
			send_command 0 4B $SELLUT
		#STEP5 - SET V SIZE: IACTVW (VRES1) **DO NOT SET** / OACTVW (VRES2 + 1)
			export VRES2_HEX=$(pixel_handler $(($VRES2 - 3)))
			send_command $ZO_BANK 0E $VRES2_HEX
		#STEP6 - ENABLE VERTICAL SHINK
			send_command $SI_BANK 49 47
	elif [ $VRES2 -gt $VRES1 ] ; then	#ZOOM
		#STEP1 - DISABLE VERTICAL SHRINK
			send_command $SI_BANK 49 00
		#STEP2 - SET VERTICAL ZOOM RATIO (VZSCL)
			export VZSCL=$(ten_2_hex $(awk "BEGIN {print ($VRES1-1)/($VRES2-1)*65536}"))
			send_command $ZO_BANK 4E $VZSCL
		#STEP3 - SELECT ZOOM SET FROM LUTROM
			send_command 0 4A 2E
		#STEP4 - LOAD SELECTED ZOOM SET INTO V ZOOM CIRCUIT
			export SELLUT=$(ten_2_hex $(($3*4-4+128)))		#DETERMINE SELLUT FOR V ZOOM CIRCUIT (0/4/8/12 + 128[GO])
			send_command 0 4B $SELLUT
		#STEP5 - SET V SIZE: IACTVW (VRES1) **DO NOT SET** / OACTVW (VRES2 + 1)
			export VRES2_HEX=$(pixel_handler $(($VRES2 - 3)))
			send_command $ZO_BANK 0E $VRES2_HEX
		#STEP6 - ENABLE VERTICAL ZOOM
			send_command $ZO_BANK 4B 47
	else
		#NO ZOOM OR SHRINK - CLEAR VZOOMCT AND VSHRNKCT
			export VRES2_HEX=$(pixel_handler $(($VRES2 - 3)))
			send_command $ZO_BANK 0E $VRES2_HEX
			send_command $ZO_BANK 4B 00
			send_command $SI_BANK 49 00
	fi
}

custom_layout()
{
  setconsole /dev/ttyS1 && dmesg -n 1
 
  echo 3 60 > $IO_SELECT
  echo $FUNC_TYPE_OFFSET $_4SCR_CUSTM_LAYOUT > $IO_VALUE
  
  if [ $# -gt 1 ]
	then
		  data=$(echo $3 | awk '{printf "%04x",$1}')
			digit=$((${#data}/2))
			totalsize=$(($digit+2))
		  echo $SET_ARGS_OFFSET $totalsize > $IO_VALUE  # data length
		  echo $SET_ARGS_OFFSET $1 > $IO_VALUE          # type
		  echo $SET_ARGS_OFFSET $2 > $IO_VALUE          #  ch
		  
		  export i=$digit
			while [ $i -gt 0 ]
			do
			  export F1=$(($i*2-1))
			  export F2=$(($i*2))
			  export itemp=$(echo $data | cut -c$F1-$F2)
			  echo $SET_ARGS_OFFSET $itemp > $IO_VALUE
				i=$(expr $i - 1)
			done
  else
      echo $SET_ARGS_OFFSET 1 > $IO_VALUE   # data length
		  echo $SET_ARGS_OFFSET $1 > $IO_VALUE  # type
  fi
  echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE
  
  setconsole -r && dmesg -n 8
}


export CHANNEL=1
while [ $# -ne 0 ] ; do
  export ARG=$1
case "$ARG" in
  ch1|CH1) export CHANNEL=1;;
  ch2|CH2) export CHANNEL=2;;
  ch3|CH3) export CHANNEL=3;;
  ch4|CH4) export CHANNEL=4;;
  getres) get_resolution $CHANNEL;;                       # RETURNS CURRENT RESOLUTION OF CHANNEL
  hpos*)                                                    
    export h_start=$(echo $ARG | cut -d':' -f2)           # GET USER PARAMETER
    if [ $h_start -ge 0 ] && [ $h_start -le 1920 ] ; then # CHECK VALID BOUNDS
      custom_layout $HSTART $CHANNEL $h_start         		# MAKE IT SO
    else
      error $ARG
    fi
    ;;
  vpos*)
    export v_start=$(echo $ARG | cut -d':' -f2)           # GET USER PARAMETER
    if [ $v_start -ge 0 ] && [ $v_start -le 1080 ] ; then # CHECK VALID BOUNDS
      custom_layout $VSTART $CHANNEL $v_start             # MAKE IT SO
    else
      error $ARG
    fi
    ;;
  layer*)
    export LAYER=$(echo $ARG | cut -d':' -f2)
    layer_handler $LAYER $CHANNEL
    ;;
  fade*)
    export FADES=$(echo $ARG | cut -d':' -f2)
    export FD1=$(echo $FADES | cut -c1)
    export FD2=$(echo $FADES | cut -c2)     
    export DUTY=$(echo $ARG | cut -d'#' -f2)
    fade_handler $FD1 $FD2 $DUTY
    exit
    ;;
  width*)
    export WIDTH=$(echo $ARG | cut -d':' -f2)         # GET USER PARAMETER
    custom_layout $HWIDTH $CHANNEL $WIDTH             # HANDLE HORIZONTAL SCALING AND MAKE IT SO
  ;;
  height*)
    export HEIGHT=$(echo $ARG | cut -d':' -f2)        # GET USER PARAMETER
    custom_layout $VHEIGHT $CHANNEL $HEIGHT          # HANDLE VERTICAL SCALING AND MAKE IT SO
  ;;
esac
  shift
done             
  custom_layout $DONE

